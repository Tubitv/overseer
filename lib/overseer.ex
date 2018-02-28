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
  * disconnected: if a node is DOWN, overseer will generate disconnected event. After a timeout that node didn't connect to overseer, overseer will bring up a new node with same ARA.
  * loaded: if a node finished loading the release, overseer will generate loaded event.
  * paired: if a node finished pairing with overseer, overseer will generate paired event.
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

        # One shall provide initial labor_state and global_state
        # later on only global_state are provided for handle_call / cast / info.
        # labor_state will be provided for labor event: handle_connected / disconnected / telemetry / etc.
        def init(state) do
          {:ok, labor_state, global_state}
        end

        def handle_connected(node, state) do

        end

        def handle_disconnected(node, state) do

        end

        def handle_telemetry(telemetry, state) do

        end

        def handle_telemetry(telemetry, state) do

        end

        def handle_terminated(node, state) do

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

  require Logger
  alias Overseer.{Labor, Pair, State, Timer}
  alias GenExecutor.{Telemetry}

  # @doc """
  # Invoked when the adapter is called to start the node
  #
  # `start_link/3` will block until this callback returns. init is conflict with GenServer benavior
  # """
  # @callback init(args :: term) :: {:ok, term} | {:error, term}

  @doc """
  Invoked when a remote node connected
  """
  @callback handle_connected(from :: node, state :: term) :: {:ok, term} | {:error, term}

  @doc """
  Invoked when a remote node disconnected
  """
  @callback handle_disconnected(from :: node, state :: term) :: {:ok, term} | {:error, term}

  @doc """
  Invoked when a remote node loaded the release
  """
  @callback handle_loaded(from :: node, state :: term) :: {:ok, term} | {:error, term}

  @doc """
  Invoked when a remote node paired with overseer
  """
  @callback handle_paired(from :: node, state :: term) :: {:ok, term} | {:error, term}

  @doc """
  Invoked when a remote node sends telemetry report
  """
  @callback handle_telemetry(telemetry :: Telemetry, state :: term) ::
              {:ok, term} | {:error, term}

  @doc """
  Invoked when a remote node is terminated
  """
  @callback handle_terminated(from :: node, state :: term) :: {:ok, term} | {:error, term}

  @optional_callbacks handle_connected: 2,
                      handle_disconnected: 2,
                      handle_loaded: 2,
                      handle_paired: 2,
                      handle_terminated: 2

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

      def terminate_child(name), do: Overseer.terminate_child(__MODULE__, name)
      def terminate_child(pid, name), do: Overseer.terminate_child(pid, name)

      def count_children, do: Overseer.count_children(__MODULE__)
      def count_children(pid), do: Overseer.count_children(pid)
    end
  end

  @doc """
  Start overseer.

  Example:

      iex> adapter = {EC2,
            %{
              region: "us-west-1",
              zone: "us-west-1c",
              key_name: "adRise AWS",
              price: 0.15,
              image: "ami-eb19128b",
              instance_type: "c5.large",
              iam_role: "arn:aws:iam::370025973162:instance-profile/uapi",
              subnet: "subnet-81e344e4",
              security_groups: ["sg-f2432e94", "sg-780be81c"],
            }}

      iex> release = {:release, "a.tar.gz", {Module, :pair}}

      iex> opts = [
        strategy: :simple_one_for_one,
        max_nodes: 10
      ]
      iex> Overseer.start_link({adapter, release, opts}, name: MyOverseer)
  """
  def start_link(spec, options) when is_tuple(spec) and is_list(options) do
    start_link(Overseer.Default, spec, options)
  end

  def start_link(mod, spec, options) when is_atom(mod) and is_tuple(spec) and is_list(options) do
    GenServer.start_link(__MODULE__, {mod, spec}, options)
  end

  def start_child(pid), do: GenServer.call(pid, :"$start_child")
  def terminate_child(pid, node_name), do: GenServer.call(pid, {:"$terminate_child", node_name})
  def count_children(pid), do: GenServer.call(pid, :"$count_children")

  # callbacks
  def init({mod, data}) when is_atom(mod) do
    with {:ok, labor_state, global_state} <- mod.init(data),
         {:ok, result} <- init_state(mod, data, {labor_state, global_state}) do
      {:ok, result}
    else
      err -> err
    end
  end

  def handle_call(
        :"$start_child",
        _from,
        %{spec: spec, labors: labors, labor_state: labor_state} = data
      ) do
    with true <- count_labors(labors) < spec.max_nodes,
         {:ok, labor} <- spec.adapter.spawn(spec, labor_state) do
      labor = Timer.setup(labor, spec.conn_timeout, :conn)
      {:reply, labor, %{data | labors: update_labors(labors, labor)}}
    else
      err ->
        Logger.info("Failed to create the child. Reason: #{inspect(err)}")
        {:reply, nil, data}
    end
  end

  def handle_call({:"$terminate_child", node_name}, _from, %{spec: spec, labors: labors} = data) do
    with {:ok, labor} <- Map.fetch(labors, node_name),
         {:ok, new_labor} <- spec.adapter.terminate(labor) do
      {:reply, new_labor, %{data | labors: update_labors(labors, new_labor)}}
    else
      err -> {:reply, err, data}
    end
  end

  def handle_call(:"$count_children", _from, %{labors: labors} = data) do
    {:reply, count_labors(labors), data}
  end

  def handle_call({:"$pair", name, pid}, _from, %{mod: mod, labors: labors} = data) do
    with {:ok, labor} <- Pair.finish(labors, name, pid),
         {:ok, new_state} <- handle_mod_callback(mod, :paired, name, labor.state) do
      {:reply, :ok, %{data | labors: update_labors(labors, labor, new_state)}}
    else
      error -> {:reply, error, data}
    end
  end

  def handle_call(:"$debug", _from, data) do
    {:reply, data, data}
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

  def handle_info({:nodeup, node_name, _}, %{mod: mod, labors: labors} = data) do
    with {:ok, labor} <- Map.fetch(labors, node_name),
         {:ok, new_state} <- handle_mod_callback(mod, :connected, node_name, labor.state) do
      Logger.info("#{node_name} is up. Update its #{inspect(labor)} and cancelled the timer.")

      new_labor =
        labor
        |> Timer.cancel(:conn)
        |> Labor.connected()
        |> trigger_loader

      {:noreply, %{data | labors: update_labors(labors, new_labor, new_state)}}
    else
      _err ->
        Logger.warn("#{node_name} is up. But it doesn't belong to any labors: #{inspect(labors)}")
        {:noreply, data}
    end
  end

  def handle_info({:nodedown, node_name, _}, %{mod: mod, labors: labors, spec: spec} = data) do
    with {:ok, labor} <- Map.fetch(labors, node_name),
         {:ok, new_state} <- handle_mod_down(mod, labor) do
      Logger.info("#{node_name} is down. Update its #{inspect(labor)}")

      new_labors =
        case Labor.is_terminated(labor) do
          true ->
            delete_labor(labors, node_name)

          _ ->
            new_labor =
              labor
              |> Timer.setup(spec.conn_timeout, :conn)
              |> Labor.disconnected()

            Map.put(labors, node_name, new_labor)
            update_labors(labors, new_labor, new_state)
        end

      {:noreply, %{data | labors: new_labors}}
    else
      _err ->
        Logger.warn(
          "#{node_name} is down. But it doesn't belong to any labors: #{inspect(labors)}"
        )

        {:noreply, data}
    end
  end

  def handle_info({:EXIT, pid, reason}, %{spec: spec, labors: labors} = data) do
    Logger.warn(
      "Process #{inspect(pid)} down. Reason: #{inspect(reason)}. Trying to bring it up again."
    )

    node_name = node(pid)

    with {:ok, labor} <- Map.fetch(labors, node_name),
         {:ok, new_labor} <- Pair.initiate(spec, labor) do
      {:noreply, %{data | labors: update_labors(labors, new_labor)}}
    else
      _err ->
        Logger.warn("Cannot bring up the dead process for #{node_name}")
        {:noreply, data}
    end
  end

  def handle_info({:"$conn_timeout", node_name}, %{labors: labors} = data) do
    Logger.info("Conn timer triggered: #{inspect(node_name)}")

    with {:ok, labor} <- Map.fetch(labors, node_name) do
      case Labor.is_disconnected(labor) do
        true -> {:noreply, %{data | labors: delete_labor(labors, node_name)}}
        _ -> {:noreply, data}
      end
    else
      _ -> {:noreply, data}
    end
  end

  def handle_info({:"$pair_timeout", node_name}, %{spec: spec, labors: labors} = data) do
    Logger.info("Pairing timer triggered: #{inspect(node_name)}")

    with {:ok, labor} <- Map.fetch(labors, node_name),
         {:ok, new_labor} <- Pair.initiate(spec, labor) do
      {:noreply, %{data | labors: update_labors(labors, new_labor)}}
    else
      _ ->
        Logger.warn("Failed to pair with #{node_name}.")
        {:noreply, data}
    end
  end

  def handle_info({:"$load_release", labor}, %{mod: mod, spec: spec, labors: labors} = data) do
    Logger.info("Loading the release for #{inspect(labor.name)}")

    with {:ok, labor} <- Pair.load_and_pair(spec, labor),
         {:ok, new_state} <- handle_mod_callback(mod, :loaded, labor.name, labor.state) do
      {:noreply, %{data | labors: update_labors(labors, labor, new_state)}}
    else
      _ ->
        Logger.warn("Failed to load the release with #{labor.name}")
        {:noreply, data}
    end
  end

  def handle_info({:"$telemetry", telemetry}, %{mod: mod, labors: labors} = data) do
    with {:ok, labor} <- Map.fetch(labors, telemetry.name) do
      Logger.info("Receiving telemetry data from #{telemetry.name}. Labor: #{inspect(labor)}")

      case handle_mod_callback(mod, :telemetry, telemetry, labor.state) do
        {:ok, new_state} ->
          {:noreply, %{data | labors: update_labors(labors, labor, new_state)}}

        {:error, error} ->
          Logger.info(
            "Failed to process: #{inspect(telemetry)}. Labor: #{inspect(labor)}. Error: #{
              inspect(error)
            }"
          )

          {:noreply, data}
      end
    else
      _ ->
        Logger.warn(
          "Receiving unknown telemetry data #{inspect(telemetry)}. Labors: #{inspect(labors)}"
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

  defp handle_mod_down(mod, labor) do
    case Labor.is_terminated(labor) do
      true -> handle_mod_callback(mod, :terminated, labor.name, labor.state)
      _ -> handle_mod_callback(mod, :disconnected, labor.name, labor.state)
    end
  end

  defp count_labors(labors) do
    labors
    |> Enum.filter(fn {_, labor} -> not Labor.is_terminated(labor) end)
    |> Enum.count()
  end

  defp delete_labor(labors, name) do
    Map.delete(labors, name)
  end

  defp trigger_loader(labor) do
    send(self(), {:"$load_release", labor})
    labor
  end

  defp handle_mod_callback(mod, type, data, state) do
    fn_name = :"handle_#{type}"

    case function_exported?(mod, fn_name, 2) do
      true -> apply(mod, fn_name, [data, state])
      _ -> {:ok, state}
    end
  end

  defp update_labors(labors, labor), do: Map.put(labors, labor.name, labor)

  defp update_labors(labors, labor, state) do
    new_labor = Labor.update_state(labor, state)
    update_labors(labors, new_labor)
  end
end
