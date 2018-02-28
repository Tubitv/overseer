defmodule Overseer.Adapters.EC2 do
  @moduledoc """
  Adapter for EC2. Handles normal instance and spot instance.
  For initial version, directly call aws-cli to deal with it. Later when I
  have time, I will try to support it with ExAws.
  """
  @behaviour Overseer.Adapter

  alias Overseer.Adapters.EC2.{LaunchSpec, Spot}
  alias Overseer.{Labor}

  def validate(args) do
    {:ok, LaunchSpec.create(args)}
  end

  def spawn(spec, init_state \\ nil) do
    name = "slave-node"

    case start_node(spec.args, name) do
      {:ok, name} -> {:ok, Labor.create(name, init_state)}
      err -> err
    end
  end

  def terminate(labor) do
    {:ok, labor}
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
        {:ok, :"#{name}@#{hostname}"}
    end
  end
end
