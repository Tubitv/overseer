defmodule MyOverseer do
  use Overseer
  require Logger

  def start_link(spec, options) do
    Overseer.start_link(__MODULE__, spec, options)
  end

  def call(:state) do
    GenServer.call(__MODULE__, :state)
  end

  def debug do
    GenServer.call(__MODULE__, :"$debug")
  end

  def init(_) do
    {:ok, %{}, %{}}
  end

  def handle_call(:state, _from, state), do: {:reply, state, state}

  def handle_connected(labor, state) do
    Logger.info("node #{labor.name} up: labor #{inspect(labor)}, state #{inspect(state)}")
    {:ok, state}
  end

  def handle_disconnected(labor, state) do
    Logger.info("node #{labor.name} down: labor #{inspect(labor)}, state #{inspect(state)}")
    {:ok, state}
  end

  def handle_telemetry(data, state) do
    Logger.info("node #{data.name}: telemetry data: #{inspect(data)}")
    {:ok, state}
  end

  def handle_terminated(labor, state) do
    Logger.info("node #{labor.name} terminated: labor #{inspect(labor)}, state #{inspect(state)}")
    {:ok, state}
  end
end
