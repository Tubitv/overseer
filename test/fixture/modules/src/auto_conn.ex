defmodule AutoConn do
  use GenServer
  @timeout 1000
  @total_task 1000

  def start_link(ocb) do
    GenServer.start_link(__MODULE__, ocb, name: AutoConn)
  end

  def disconnect, do: GenServer.call(__MODULE__, :disconnect)
  def connect, do: GenServer.call(__MODULE__, :connect)
  def kill(timeout \\ @timeout), do: GenServer.cast(__MODULE__, {:kill, timeout})
  def halt(timeout \\ @timeout), do: GenServer.cast(__MODULE__, {:halt, timeout})
  def error(timeout \\ @timeout), do: GenServer.cast(__MODULE__, {:error, timeout})
  def status, do: GenServer.call(__MODULE__, :status)

  # callbacks
  def init(ocb) do
    send(self(), :pair)
    periodic_update()
    {:ok, %{ocb: ocb, progress: 0}}
  end

  def handle_call(:disconnect, _from, %{ocb: ocb} = state), do: {:reply, Node.disconnect(ocb.name), state}
  def handle_call(:connect, _from, %{ocb: ocb} = state), do: {:reply, Node.connect(ocb.name), state}
  def handle_call(:status, _from, state), do: {:reply, state, state}

  def handle_cast({type, timeout}, state) when type in [:kill, :halt, :error] do
     Process.send_after(self(), type, timeout)
     {:noreply, state}
  end

  def handle_info(:pair, %{ocb: ocb} = state) do
    GenServer.call(ocb.pid, {:"$pair", node(), self()})
    {:noreply, state}
  end

  def handle_info(:kill, state)  do
    Process.exit(self(), :kill)
    {:noreply, state}
  end

  def handle_info(:halt, state) do
    :init.stop()
    {:noreply, state}
  end

  def handle_info(:error, state) do
    1/0
    {:noreply, state}
  end

  def handle_info(:progress, %{ocb: ocb, progress: progress} = state) do
    new_progress = progress + 100
    case new_progress >= @total_task do
      true -> nil
      false ->
        telemetry = %{name: node(), id: "task1", type: :progress, data: new_progress / @total_task}
        send(ocb.pid, {:"$telemetry", telemetry})
        periodic_update()
    end
    {:noreply, %{state | progress: new_progress}}
  end

  defp periodic_update do
    Process.send_after(self(), :progress, 100)
  end
end
