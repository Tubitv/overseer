defmodule Overseer.Pair do
  @moduledoc """
  Functionalities about loading and pairing.
  """

  require Logger
  alias Overseer.{Labor, Timer}
  alias GenExecutor.Ocb

  @doc """
  Load the release from spec and start the pairing process
  """
  def load_and_pair(spec, labor) do
    name = labor.name
    release = spec.release

    case release.type do
      :module -> ExLoader.load_module(release.url, name)
      :release -> ExLoader.load_release(release.url, name)
    end

    {:ok, new_labor} = initiate(spec, labor)
    {:ok, Labor.loaded(new_labor)}
  end

  @doc """
  Initiate the pairing process.
  Let the process in remote node know the info about myself (overseer).
  Here I cannot send a message since I don't know who to send before paring is done.
  """
  def initiate(spec, labor) do
    new_labor = Labor.loaded(labor)

    case initiate_pair(spec, new_labor.name) do
      :error -> {:ok, Timer.setup(new_labor, spec.pair_timeout, :pair)}
      _ -> {:ok, new_labor}
    end
  end

  defp initiate_pair(spec, node_name) do
    case spec.release.do_pair do
      nil ->
        :ok

      {m, f} ->
        ocb = Ocb.create(spec)
        result = :rpc.call(node_name, m, f, [ocb])

        case result do
          {:badrpc, reason} ->
            Logger.warn(
              "Cannot initiate the paring with #{node_name} for #{inspect(spec)}: Reason: #{
                inspect(reason)
              }"
            )

            :error

          _ ->
            :ok
        end
    end
  end

  @doc """
  When remote node got pair request it will send a message to me with :"$pair". Then I know
  how to pair.
  """
  def finish(labors, name, pid) do
    case Map.get(labors, name) do
      nil ->
        Logger.warn("Cannot find the labor #{name} in #{inspect(labors)}")
        {:error, :notfound}

      labor ->
        new_labor = Labor.pair(labor, pid)
        {:ok, Timer.cancel(new_labor, :conn)}
    end
  end
end
