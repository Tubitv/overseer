defmodule Overseer.Spec do
  @moduledoc """
  Data that holding all the runtime information for the Overseer
  """
  alias Overseer.{Labor, Spec}

  @max_nodes 8
  @conn_timeout 10 * 1000

  @type strategy :: :simple_one_for_one | :one_for_one

  @type t :: %__MODULE__{
          adapter: module,
          strategy: strategy,
          max_nodes: integer,
          conn_timeout: integer,
          args: term,
          release: String.t()
        }

  defstruct adapter: Overseer.MissingAdapter,
            strategy: :simple_one_for_one,
            max_nodes: @max_nodes,
            conn_timeout: @conn_timeout,
            args: nil,
            release: nil

  def create(adapter, adapter_args, release, options) do
    strategy = Keyword.get(options, :strategy)

    assert(
      strategy,
      :simple_one_for_one,
      "Expected :simple_one_for_one  for :strategy option in current version. No other value accepted"
    )

    assert(Code.ensure_loaded?(adapter), true, "Module #{inspect(adapter)} cannot be loaded")

    args =
      case adapter.validate(adapter_args) do
        {:ok, result} -> result
        {:error, msg} -> assert(true, false, msg)
      end

    assert(ExLoader.valid_file?(release), true, "Release file #{release} cannot be loaded")

    %Spec{
      adapter: adapter,
      strategy: strategy,
      max_nodes: Keyword.get(options, :max_nodes, @max_nodes),
      conn_timeout: Keyword.get(options, :conn_timeout, @conn_timeout),
      args: args,
      release: release
    }
  end

  defp assert(value, expected, msg) do
    unless expected == value do
      raise ArgumentError, msg
    end
  end
end

defmodule Overseer.Labor do
  @moduledoc false
  alias Overseer.Labor

  # TODO: how can we unify the type def of states and the states here?
  @all_states [:disconnected, :connected, :loaded, :active, :terminated]

  @type state :: :disconnected | :connected | :loaded | :active | :terminated

  @type t :: %__MODULE__{
          name: node,
          state: state,
          overseer: node,
          timer: reference,
          started_at: DateTime.t()
        }

  defstruct name: :noname,
            state: :disconnected,
            overseer: nil,
            timer: nil,
            started_at: nil

  def create(name) do
    %Labor{
      name: name,
      overseer: node(),
      started_at: DateTime.utc_now()
    }
  end

  @all_states
  |> Enum.map(fn state ->
    def unquote(state)(labor), do: set_state(labor, unquote(state))
  end)

  @all_states
  |> Enum.map(fn state ->
    def unquote(:"is_#{state}")(labor), do: is_state(labor, unquote(state))
  end)

  defp set_state(labor, new_state) when is_atom(new_state), do: %{labor | state: new_state}
  defp is_state(labor, state) when is_atom(state), do: labor.state == state
end

defmodule Overseer.State do
  @moduledoc false
  alias Overseer.{Labor, Spec, State}

  @type t :: %__MODULE__{
          mod: module,
          spec: Spec,
          labors: %{required(String.t()) => Labor},
          state: any
        }

  defstruct mod: Overseer.MissingModule,
            spec: %Spec{},
            labors: %{},
            state: nil

  def create(mod, adapter, adapter_args, release, state, options) do
    unless Code.ensure_loaded?(mod) == true do
      raise ArgumentError, "Module #{inspect(mod)} cannot be loaded"
    end

    spec = Spec.create(adapter, adapter_args, release, options)

    %State{
      mod: mod,
      spec: spec,
      state: state
    }
  end
end
