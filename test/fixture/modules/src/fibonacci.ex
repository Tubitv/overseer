defmodule Example.Fab do
  @moduledoc """
  Calculate fabonacci number and sequence.
  """

  def value(0), do: 0
  def value(1), do: 1
  def value(n), do: value(n - 1) + value(n - 2)

  def sequence(n) do
    2..n-1
    |> Enum.reduce([0, 1], fn _, acc ->
      [n1, n2 | _] = acc
      [n1 + n2 | acc]
    end)
  end
end
