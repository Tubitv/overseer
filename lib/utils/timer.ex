defmodule Overseer.Timer do
  @moduledoc """
  Functionalities about setup / cancel timer
  """
  require Logger
  alias Overseer.Labor

  def setup(labor, timeout, type) do
    ref = Process.send_after(self(), {:"$#{type}_timeout", labor.name}, timeout)
    # just cancel previous timer
    labor = cancel(labor, type)
    Logger.info("Setup the timer for #{inspect(labor)}")
    timers = Map.put(labor.timers, type, ref)
    new_labor = Map.put(labor, :timers, timers)

    Labor.disconnected(new_labor)
  end

  def cancel(labor, type) do
    timer = Map.get(labor.timers, type)

    case is_reference(timer) do
      false ->
        labor

      _ ->
        Logger.info("Cancel the #{type} timer for #{inspect(labor)}")
        Process.cancel_timer(timer)
        timers = Map.delete(labor.timers, type)
        Map.put(labor, :timers, timers)
    end
  end

  def cancel_all(labor) do
    Enum.each(labor.timers, fn {type, timer} ->
      Logger.info("Cancel the #{type} timer for #{inspect(labor)}")
      is_reference(timer) && Process.cancel_timer(timer)
    end)

    Map.put(labor, :timers, %{})
  end
end
