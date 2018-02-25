defmodule Bootloader.Initd do
  @moduledoc """
  Initialize the system and try to connect to overseer
  """

  use GenServer
  require Logger
  alias Bootloader.Metadata

  def start_link do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  # callbacks
  def init(_) do
    Process.send_after(self(), :initialize, 100)
    {:ok, %{}}
  end

  def handle_info(:initialize, state) do

    %{"name" => name, "cookie" => cookie} = Metadata.get_user_data()
    :erlang.set_cookie(cookie)
  end
end
