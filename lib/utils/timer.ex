defmodule Overseer.Timer do
  @moduledoc """
  Functionalities about setup / cancel timer
  """
  require Logger

  def setup(labor, timeout, type) do
    ref = Process.send_after(self(), {:"$#{type}_timeout", labor.name}, timeout)
    # just cancel previous timer
    labor = cancel(labor, type)
    Logger.info("Setup the timer for #{inspect(labor)}")
    Map.put(labor, :"#{type}_timer", ref)
  end

  def cancel(labor, type) do
    timer = Map.get(labor, :"#{type}_timer")

    case is_reference(timer) do
      false ->
        labor

      _ ->
        Logger.info("Cancel the timer for #{inspect(labor)}")
        Process.cancel_timer(timer)
        Map.put(labor, :"#{type}_timer", nil)
    end
  end
end
