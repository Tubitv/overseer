defmodule Bootloader.Initd do
  @moduledoc """
  Initialize the system and try to connect to overseer
  """

  use GenServer
  require Logger
  alias Bootloader.Metadata

  @max_retries 10
  @retry_timeout 500

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def pair(ocb) do
    GenServer.call(__MODULE__, {:pair, ocb})
  end

  # callbacks
  def init(_) do
    Process.send_after(self(), :initialize, 100)
    {:ok, %{total_init: 0, total_pair: 0, ocb: %{}}}
  end

  def handle_call({:pair, ocb}, _from, state) do
    send(self(), :pair)
    {:reply, :ok, %{state | ocb: ocb}}
  end

  def handle_info(:initialize, state) do
    %{"name" => name, "cookie" => cookie} = Metadata.get_user_data()
    Node.set_cookie(String.to_atom(cookie))
    Node.connect(String.to_atom(name))
    {:noreply, state}
  rescue
    _ ->
      total_init = state.total_init + 1
      if total_init < @max_retries do
        Process.send_after(self(), :initialize, @retry_timeout)
      else
        Logger.error("Cannot initialize the bootloader. Will terminate the server")
      end
      {:noreply, %{state | total_init: total_init}}
  end

  def handle_info(:pair, %{ocb: ocb} = state) do
    GenServer.call(ocb.pid, {:"$pair", node(), self()})
    {:noreply, state}
  rescue
    _ ->
      total_pair = state.total_pair + 1
      if total_pair < @max_retries do
        Process.send_after(self(), :pair, @retry_timeout)
      else
        Logger.error("Cannot pair with #{inspect ocb}")
      end
      {:noreply, %{state | total_pair: total_pair}}
  end
end
