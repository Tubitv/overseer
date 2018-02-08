defmodule AutoConn do
  use GenServer
  @timeout 10000

  def start_link do
    GenServer.start_link(__MODULE__, nil, name: AutoConn)
  end

  def disconnect, do: GenServer.call(__MODULE__, :disconnect)
  def connect, do: GenServer.call(__MODULE__, :connect)
  def halt(timeout \\ @timeout), do: Process.send_after(__MODULE__, :halt, timeout)

  # callbacks
  def init(_) do
    node =
      :hidden
      |> Node.list
      |> List.first
    {:ok, node}
  end

  def handle_call(:disconnect, _from, node), do: {:reply, Node.disconnect(node), node}
  def handle_call(:connect, _from, node), do: {:reply, Node.connect(node), node}
  def handle_info(:halt, node) do
    :init.stop()
    {:noreply, node}
  end
end
