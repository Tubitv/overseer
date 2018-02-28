defmodule Overseer.Adapters.EC2 do
  @moduledoc """
  Adapter for EC2. Handles normal instance and spot instance.
  For initial version, directly call aws-cli to deal with it. Later when I
  have time, I will try to support it with ExAws.
  """
  @behaviour Overseer.Adapter
  require Logger

  alias Overseer.Adapters.EC2.{LaunchSpec, Spot}
  alias Overseer.{Labor}

  def validate(args) do
    {:ok, LaunchSpec.create(args)}
  end

  def spawn(spec, init_state \\ nil) do
    name = "slave-node"

    case start_node(spec.args, name) do
      {:ok, name, adapter_data} -> {:ok, Labor.create(name, init_state, adapter_data)}
      err -> err
    end
  end

  def terminate(%Labor{status: :terminated}, labor), do: {:ok, labor}

  def terminate(labor) do
    with {:ok, data} <- Map.fetch(labor, :adapter_data),
         {:ok, req_id} <- Map.fetch(data, :req_id),
         {:ok, instance_id} <- Map.fetch(data, :instance_id),
         :ok <- Spot.terminate_instance(instance_id),
         :ok <- Spot.cancel_request(req_id) do
      {:ok, Labor.terminated(labor)}
    else
      error ->
        Logger.error(
          "Cannot terminate or cancel spot instance request for %{inspect labor}, please try it manually"
        )

        {:error, error}
    end
  end

  # private functions
  defp start_node(args, name) do
    req_id = Spot.request(args)

    case Spot.get_request_status(req_id) do
      nil ->
        {:error, "Cannot start the instance"}

      instance_id ->
        info = Spot.get_instance_info(instance_id)
        hostname = Spot.get_instance_hostname(info)
        {:ok, :"#{name}@#{hostname}", %{req_id: req_id, instance_id: instance_id}}
    end
  end
end
