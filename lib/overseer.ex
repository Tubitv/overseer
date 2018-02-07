defmodule Overseer do
  @moduledoc ~S"""
  Inspired by Supervisor, Overseer is used to start/monitor/interact/restart/terminate erlang nodes. We know that Supervisor can start workers with predefined MFA (Module, Function, Args). Similarly, Overseer can start nodes with predefined ARO (Adapter, Release and Options):

  * Adapter tells overseer how to spawn the node. It is provided in the term `{adapter, opts}`.
  * Release is a full path of a release tarball. Local file, S3 or https are supported. Overseer will load the release to the remote node once it is started.
  * Options could be: `max_nodes`, default 8, `strategy`, default `:simple_one_for_one`.

  Once a new node is spawned and connected with overseer, overseer will monitor it and handles events posted by the node.

  ## Supported Adapter

  When Overseer is going to spawn a new node, it will call `Adapter.start(opts)`. Client module need to choose the adapter they're going to use and the opts for that adapter. Initially we will support two adapters: `Overseer.Adapter.Local` and `Overseer.Adapter.EC2`.

  ### Overseer.Adapter.Local

  Start new nodes in localhost. Options:

  * prefix: name prefix of the node.

  ### Overseer.Adapter.EC2

  bring up new EC2 instance to start the new nodes. Options:

  * prefix: name prefix of the node.
  * type: type of the instance.
  * spot?: start it as spot instance or not.
  * image: AMI for the instance.

  ## Supported events

  * connected: a node successfully connected to overseer.
  * disconnected: if a node is DOWN, oversee will generate disconnected event. After a timeout that node didn't connect to overseer, overseer will bring up a new node with same ARA.
  * telemetry: telemetry data sent from node to overseer.
  * terminated: once overseer brings down a node, it will emit terminated event.

  ## Supported strategy

  Overseer supports `:one_for_one` and `simple_one_for_one`.

  ## Examples

      defmodule MyOverseer do
        use Overseer

        def start_link(children, opts) do
          Overseer.start_link(children, opts)
        end

        def init(state) do
          {:ok, state}
        end

        def handle_connected(data, node, state) do

        end

        def handle_disconnected(data, node, state) do

        end

        def handle_telemetry({:progress, data}, node, state) do

        end

        def handle_telemetry(data, node, state) do

        end

        def handle_terminated(node, state) do

        end

        def handle_event(event, node, state) do

        end
      end

      defmodule Application1 do
        use Application
        alias Overseer.Adapters.EC2

        def start(_type, _args) do
          children = [
            {Worker1, []),
            {MyOverseer, [node_spec, [name: MyOverseer1]]}
          ]

          opts = [strategy: :one_for_one, name: Application1.Supervisor]
          Supervisor.start_link(children, opts)
        end

        defp node_spec do
          adapter = {Overseer.Adapters.EC2, [
            prefix: "merlin",
            image: "ami-31bb8c7f",
            type: "c5.xlarge",
            spot?: true
          ]}

          opts = [
            strategy: :simple_one_for_one,
            max_nodes: 10
          ]

          {adapter, "merlin.tar.gz", opts}
        end
      end
  """

  # @doc """
  # Invoked when the adapter is called to start the node
  #
  # `start_link/3` will block until this callback returns. init is conflict with GenServer benavior
  # """
  # @callback init(args :: term) :: {:ok, term} | {:error, term}

  @doc """
  Invoked when a remote node connected
  """
  @callback handle_connected(data :: term, from :: node, state :: term) :: {:noreply, term}

  @doc """
  Invoked when a remote node disconnected
  """
  @callback handle_disconnected(data :: term, from :: node, state :: term) :: {:noreply, term}

  @doc """
  Invoked when a remote node sends telemetry report
  """
  @callback handle_telemetry(data :: term, from :: node, state :: term) :: {:noreply, term}

  @doc """
  Invoked when a remote node sends other events
  """
  @callback handle_event(data :: term, from :: node, state :: term) :: {:noreply, term}

  require Logger
  alias Overseer.{Labor, State}

  @doc false
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      use GenServer
      import Overseer
      @behaviour Overseer

      @doc false
      def child_spec(arg) do
        default = %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [arg]}
        }

        Supervisor.child_spec(default, unquote(Macro.escape(opts)))
      end

      def start_child, do: Overseer.start_child(__MODULE__)
      def start_child(pid), do: Overseer.start_child(pid)
    end
  end

  @doc """
  Start overseer.

  Example:

      iex> adapter = {Overseer.Adapters.EC2, [
        prefix: "merlin",
        image: "ami-31bb8c7f",
        type: "c5.xlarge",
        spot?: true
      ]}

      iex> opts = [
        strategy: :simple_one_for_one,
        max_nodes: 10
      ]
      iex> Overseer.start_link({adapter, "a.tar.gz", opts}, name: MyOverseer)
  """
  def start_link(spec, options) when is_tuple(spec) and is_list(options) do
    start_link(Overseer.Default, spec, options)
  end

  def start_link(mod, spec, options) when is_atom(mod) and is_tuple(spec) and is_list(options) do
    GenServer.start_link(__MODULE__, {mod, spec}, options)
  end

  def start_child(name_or_pid) do
    GenServer.call(name_or_pid, :start_child)
  end

  # callbacks
  def init({mod, data}) when is_atom(mod) do
    with {:ok, state} <- mod.init(data),
         {:ok, result} <- init_state(mod, data, state) do
      {:ok, result}
    else
      err -> err
    end
  end

  def handle_call(:start_child, _from, %{spec: spec, labors: labors} = data) do
    with {:ok, labor} <- spec.adapter.spawn(spec) do
      {:reply, labor, %{data | labors: Map.put(labors, labor.name, labor)}}
    else
      err -> {:reply, err, data}
    end
  end

  def handle_call(msg, from, %{mod: mod, state: state} = data) do
    case mod.handle_call(msg, from, state) do
      {:reply, reply, state} ->
        {:reply, reply, %{data | state: state}}

      {:reply, reply, state, :hibernate} ->
        {:reply, reply, %{data | state: state}, :hibernate}

      {:stop, reason, reply, state} ->
        {:stop, reason, reply, %{data | state: state}}

      return ->
        handle_noreply_callback(return, data)
    end
  end

  def handle_cast(msg, %{state: state} = data) do
    noreply_callback(:handle_cast, [msg, state], data)
  end

  def handle_info({:nodeup, node_name, _}, %{labors: labors} = data) do
    with {:ok, labor} <- Map.fetch(labors, node_name) do
      Logger.info("#{node_name} is up. Update its state.")
      {:noreply, %{data | labors: Map.put(labors, node_name, Labor.connected(labor))}}
    else
      _err ->
        Logger.warn("#{node_name} is up. But it doesn't belong to any labors: #{inspect(labors)}")
        {:noreply, data}
    end
  end

  def handle_info({:nodedown, node_name, _}, %{labors: labors} = data) do
    with {:ok, labor} <- Map.fetch(labors, node_name) do
      Logger.info("#{node_name} is down. Update its state.")
      {:noreply, %{data | labors: Map.put(labors, node_name, Labor.disconnected(labor))}}
    else
      _err ->
        Logger.warn(
          "#{node_name} is down. But it doesn't belong to any labors: #{inspect(labors)}"
        )

        {:noreply, data}
    end
  end

  @doc false
  def handle_info(msg, %{state: state} = data) do
    noreply_callback(:handle_info, [msg, state], data)
  end

  @doc false
  def terminate(reason, %{mod: mod, state: state}) do
    if function_exported?(mod, :terminate, 2) do
      mod.terminate(reason, state)
    else
      :ok
    end
  end

  @doc false
  def code_change(old_vsn, %{mod: mod, state: state} = data, extra) do
    if function_exported?(mod, :code_change, 3) do
      case mod.code_change(old_vsn, state, extra) do
        {:ok, state} -> {:ok, %{data | state: state}}
        other -> other
      end
    else
      {:ok, data}
    end
  end

  # private functions
  defp init_state(mod, data, state) do
    Process.flag(:trap_exit, true)
    :net_kernel.monitor_nodes(true, node_type: :hidden)
    default_opts = [overseer: node(), strategy: :simple_one_for_one, max_nodes: 8]
    {{adapter, args}, release, opts} = data

    opts = Keyword.merge(default_opts, opts)
    data = State.create(mod, adapter, args, release, state, opts)

    case data.spec.strategy do
      :simple_one_for_one -> {:ok, init_dynamic(data)}
      _ -> {:stop, {:bad_start_spec, data}}
    end
  end

  defp init_dynamic(data) do
    %{data | labors: %{}}
  end

  defp noreply_callback(callback, args, %{mod: mod} = data) do
    handle_noreply_callback(apply(mod, callback, args), data)
  end

  defp handle_noreply_callback(return, data) do
    case return do
      {:noreply, state} ->
        {:noreply, %{data | state: state}}

      {:noreply, state, :hibernate} ->
        {:noreply, %{data | state: state}, :hibernate}

      {:stop, reason, state} ->
        {:stop, reason, %{data | state: state}}

      other ->
        {:stop, {:bad_return_value, other}, data}
    end
  end
end
