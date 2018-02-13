defmodule Overseer.Spec do
  @moduledoc """
  Data that holding all the runtime information for the Overseer
  """
  alias Overseer.{Spec, Release, Utils}

  @max_nodes 8
  @conn_timeout 10 * 1000
  @pair_timeout 5 * 1000

  @type strategy :: :simple_one_for_one | :one_for_one

  @type t :: %__MODULE__{
          adapter: module,
          strategy: strategy,
          max_nodes: integer,
          conn_timeout: integer,
          pair_timeout: integer,
          args: term,
          release: Release
        }

  defstruct adapter: Overseer.MissingAdapter,
            strategy: :simple_one_for_one,
            max_nodes: @max_nodes,
            conn_timeout: @conn_timeout,
            pair_timeout: @pair_timeout,
            args: nil,
            release: nil

  def create(adapter, adapter_args, release_args, options \\ []) do
    strategy = Keyword.get(options, :strategy, :simple_one_for_one)

    Utils.assert(
      strategy,
      :simple_one_for_one,
      "Expected :simple_one_for_one  for :strategy option in current version. No other value accepted"
    )

    Utils.assert(
      Code.ensure_loaded?(adapter),
      true,
      "Module #{inspect(adapter)} cannot be loaded"
    )

    release = Release.create(release_args)

    args =
      case adapter.validate(adapter_args) do
        {:ok, result} -> result
        {:error, msg} -> Utils.assert(true, false, msg)
      end

    %Spec{
      adapter: adapter,
      strategy: strategy,
      max_nodes: Keyword.get(options, :max_nodes, @max_nodes),
      conn_timeout: Keyword.get(options, :conn_timeout, @conn_timeout),
      pair_timeout: Keyword.get(options, :pair_timeout, @conn_timeout),
      args: args,
      release: release
    }
  end
end
