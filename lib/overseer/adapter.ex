defmodule Overseer.Adapter do
  @moduledoc """
  Adapter behavior for spawning / terminating resources
  """
  alias Overseer.{Spec, Labor}

  @doc """
  Verify if the given args are valid not not for the adapter
  """
  @callback validate(term) :: {:ok, term} | {:error, term}

  @doc """
  Spawn a new node based on the Spec.
  """
  @callback spawn(Spec) :: {:ok, Labor} | {:error, term}

  @doc """
  Stop a labor node.
  """
  @callback terminate(Labor) :: {:ok, Labor} | {:error, term}
end
