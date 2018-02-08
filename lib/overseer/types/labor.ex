defmodule Overseer.Labor do
  @moduledoc """
  Struct to track the running labor resources
  """
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
