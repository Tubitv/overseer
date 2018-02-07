defmodule Overseer.Utils do
  @moduledoc """
  Utility functions
  """

  @default_alphabet "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
  def gen_id(size \\ 8) do
    Nanoid.generate(size, @default_alphabet)
  end
end
