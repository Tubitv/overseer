defmodule App2 do
  @moduledoc false
  def hello(msg) do
    App2.Server.hello(msg)
  end
end
