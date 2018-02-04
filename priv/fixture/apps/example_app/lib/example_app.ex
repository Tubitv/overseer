defmodule ExampleApp do
  @moduledoc false
  def hello(msg) do
    ExampleApp.Server.hello(msg)
  end
end
