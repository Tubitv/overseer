defmodule Overseer.Labor do
  @moduledoc """
  Struct to track the running labor resources
  """
  require Logger
  alias Overseer.Labor

  # TODO: how can we unify the type def of states and the states here?
  @all_states [:disconnected, :connected, :loaded, :terminated]

  @type state :: :disconnected | :connected | :loaded | :terminated

  @type t :: %__MODULE__{
          name: node,
          pid: pid,
          state: state,
          conn_timer: reference,
          pair_timer: reference,
          started_at: DateTime.t()
        }

  defstruct name: :noname,
            pid: nil,
            state: :disconnected,
            conn_timer: nil,
            pair_timer: nil,
            started_at: nil

  def create(name) do
    %Labor{
      name: name,
      started_at: DateTime.utc_now()
    }
  end

  @doc """
  Pair(link) the pid from remote node to overseer.
  """
  def pair(labor, pid) do
    case is_alive?(labor.name, pid) do
      true ->
        pair_pid(labor, pid)

      _ ->
        Logger.warn("Trying to pair to a dead process #{inspect(pid)} to #{inspect(labor)}")
        labor
    end
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

  defp pair_pid(labor, pid) do
    case labor.pid do
      nil -> Process.link(pid)
      old_pid -> pair_old_new(labor, old_pid, pid)
    end

    %{labor | pid: pid}
  end

  defp pair_old_new(labor, old_pid, pid) do
    case is_alive?(labor.name, old_pid) do
      false ->
        Process.link(pid)

      _ ->
        Logger.warn("Trying to link a new pid to #{inspect(labor)}, while old #{pid} is alive")

        Process.unlink(old_pid)
        Process.link(pid)
    end
  end

  defp is_alive?(node_name, pid), do: :rpc.call(node_name, Process, :alive?, [pid])
end
