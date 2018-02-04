defmodule App2Test do
  use ExUnit.Case
  doctest App2

  test "greets the world" do
    assert App2.hello() == :world
  end
end
