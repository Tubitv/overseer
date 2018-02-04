defmodule App1Test do
  use ExUnit.Case
  doctest App1

  test "greets the world" do
    assert App1.hello() == :world
  end
end
