defmodule Overseer.Labor do
  @moduledoc """
  Struct to track the running labor resources
  """
  require Logger
  alias Overseer.Labor

  # TODO: how can we unify the type def of states and the states here?
  @all_status [:disconnected, :connected, :loaded, :paired, :terminated]

  @type status :: :disconnected | :connected | :loaded | :paired | :terminated

  @type t :: %__MODULE__{
          name: node,
          pid: pid,
          status: status,
          timers: %{required(atom) => reference},
          started_at: DateTime.t(),
          adapter_data: any,
          state: any
        }

  defstruct name: :noname,
            pid: nil,
            status: :disconnected,
            timers: %{},
            started_at: nil,
            adapter_data: nil,
            state: nil

  def create(name, init_state, adapter_data) do
    %Labor{
      name: name,
      state: init_state,
      adapter_data: adapter_data,
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

  def update_state(labor, state), do: %{labor | state: state}

  @all_status
  |> Enum.map(fn status ->
    def unquote(status)(labor), do: set_status(labor, unquote(status))
  end)

  @all_status
  |> Enum.map(fn status ->
    def unquote(:"is_#{status}")(labor), do: is_status(labor, unquote(status))
  end)

  defp set_status(labor, new_status) when is_atom(new_status), do: %{labor | status: new_status}
  defp is_status(labor, status) when is_atom(status), do: labor.status == status

  defp pair_pid(labor, pid) do
    case labor.pid do
      nil -> Process.link(pid)
      old_pid -> pair_old_new(labor, old_pid, pid)
    end

    new_labor = Labor.paired(labor)
    %{new_labor | pid: pid}
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
