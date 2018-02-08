defmodule AutoConn do
  use GenServer
  @timeout 10000

  def start_link(ocb) do
    GenServer.start_link(__MODULE__, ocb, name: AutoConn)
  end

  def disconnect, do: GenServer.call(__MODULE__, :disconnect)
  def connect, do: GenServer.call(__MODULE__, :connect)
  def halt(timeout \\ @timeout), do: Process.send_after(__MODULE__, :halt, timeout)

  # callbacks
  def init(ocb) do

    {:ok, %{ocb: ocb, progress: 0}}
  end

  def handle_call(:disconnect, _from, %{ocb: ocb} = state), do: {:reply, Node.disconnect(ocb.name), state}
  def handle_call(:connect, _from, %{ocb: ocb} = state), do: {:reply, Node.connect(ocb.name), state}

  def handle_info(:halt, %{ocb: ocb} = state) do
    :init.stop()
    {:noreply, state}
  end

  def handle_info(:progress, %{ocb: ocb, progress: progress} = state) do
    new_progress = progress + 100
    case new_progress >= 1000 do
      true -> nil
      false -> periodic_update()
    end
    {:noreply, %{state | progress: new_progress}}
  end

  defp periodic_update do
    Process.send_after(self(), :progress, 100)
  end
end
