defmodule App1 do
  @moduledoc false
  def hello(msg) do
    App1.Server.hello(msg)
  end
end
