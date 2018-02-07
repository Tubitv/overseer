defmodule MyOverseer do
  use Overseer

  def start_link(spec, options) do
    Overseer.start_link(__MODULE__, spec, options)
  end

  def call(:state) do
    GenServer.call(__MODULE__, :state)
  end

  def init(_) do
    {:ok, %{}}
  end

  def handle_call(:state, _from, state), do: {:reply, state, state}

  def handle_connected(_data, _node, state) do
    {:noreply, state}
  end

  def handle_disconnected(_data, _node, state) do
    {:noreply, state}
  end

  def handle_telemetry({:progress, _data}, _node, state) do
    {:noreply, state}
  end

  def handle_telemetry(_data, _node, state) do
    {:noreply, state}
  end

  def handle_terminated(_node, state) do
    {:noreply, state}
  end

  def handle_event(_event, _node, state) do
    {:noreply, state}
  end
end
