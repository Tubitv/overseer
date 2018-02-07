defmodule Overseer.Adapters.EC2 do
  @moduledoc """
  Adapter for EC2. Handles normal instance and spot instance.
  """
  @behaviour Overseer.Adapter

  alias Overseer.{Labor}

  def validate(args) do
    {:ok, args}
  end

  def spawn(_spec) do
    {:ok, %Labor{}}
  end

  def terminate(labor) do
    {:ok, labor}
  end
end
