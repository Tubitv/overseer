defmodule Overseer.Utils do
  @moduledoc """
  Utility functions
  """

  @default_alphabet "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

  @doc """
  Generate a random `unique` id. See docs from [Nanoid](https://github.com/railsmechanic/nanoid).
  """
  def gen_id(size \\ 8) do
    Nanoid.generate(size, @default_alphabet)
  end

  @doc """
  Naive assert function than raise ArgumentError
  """
  def assert(value, expected, msg) do
    unless expected == value do
      raise ArgumentError, msg
    end
  end
end
