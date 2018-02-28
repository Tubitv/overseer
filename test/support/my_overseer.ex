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

  def handle_connected(node, state) do
    Logger.info("node #{node} up: state #{inspect(state)}")
    {:ok, state}
  end

  def handle_disconnected(node, state) do
    Logger.info("node #{node} down: state #{inspect(state)}")
    {:ok, state}
  end

  def handle_telemetry(data, state) do
    Logger.info("node #{data.name}: telemetry data: #{inspect(data)}")
    {:ok, state}
  end

  def handle_terminated(_node, state) do
    {:ok, state}
  end

  def handle_event(_event, _node, state) do
    {:ok, state}
  end
end
