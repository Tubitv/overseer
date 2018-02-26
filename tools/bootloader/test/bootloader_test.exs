defmodule BootloaderTest do
  use ExUnit.Case
  doctest Bootloader

  test "greets the world" do
    assert Bootloader.hello() == :world
  end
end
