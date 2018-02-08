defmodule Overseer.Default do
  @moduledoc false
  use Overseer

  def init(_spec) do
    {:ok, %{}}
  end

  def handle_connected(_node, state) do
    {:ok, state}
  end

  def handle_disconnected(_node, state) do
    {:ok, state}
  end

  def handle_telemetry({:progress, _data}, _node, state) do
    {:ok, state}
  end

  def handle_telemetry(_data, _node, state) do
    {:ok, state}
  end

  def handle_terminated(_node, state) do
    {:ok, state}
  end

  def handle_event(_event, _node, state) do
    {:ok, state}
  end
end
