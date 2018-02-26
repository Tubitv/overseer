defmodule App2.Server do
  @moduledoc false
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def hello(msg) do
    GenServer.call(__MODULE__, {:hello, msg})
  end

  # callbacks
  def init(_) do
    {:ok, nil}
  end

  def handle_call({:hello, msg}, _from, state) do
    {:reply, "hello #{msg}", state}
  end
end
