defmodule Overseer.Labor do
  @moduledoc """
  Struct to track the running labor resources
  """
  require Logger
  alias Overseer.Labor

  # TODO: how can we unify the type def of states and the states here?
  @all_states [:disconnected, :connected, :loaded, :active, :terminated]

  @type state :: :disconnected | :connected | :loaded | :active | :terminated

  @type t :: %__MODULE__{
          name: node,
          pid: pid,
          state: state,
          timer: reference,
          started_at: DateTime.t()
        }

  defstruct name: :noname,
            pid: nil,
            state: :disconnected,
            timer: nil,
            started_at: nil

  def create(name) do
    %Labor{
      name: name,
      started_at: DateTime.utc_now()
    }
  end

  @doc """
  Link the pid from remote node to overseer
  """
  def link(labor, pid) do
    with true <- Process.alive?(pid) do
      case labor.pid do
        nil ->
          Process.link(pid)

        old_pid ->
          case Process.alive?(old_pid) do
            false ->
              Process.link(pid)

            _ ->
              Logger.warn(
                "Trying to link a new pid to #{inspect(labor)}, while old #{pid} is alive"
              )

              Process.unlink(old_pid)
              Process.link(pid)
          end
      end

      %{labor | pid: pid}
    else
      _ ->
        Logger.warn("Trying to link to a dead process #{pid} to #{inspect(labor)}")
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
end
