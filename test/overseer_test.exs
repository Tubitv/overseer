defmodule OverseerTest do
  use ExUnit.Case
  doctest Overseer

  test "greets the world" do
    assert Overseer.hello() == :world
  end
end
