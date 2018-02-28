defmodule Overseer.Adapters.EC2.Spot do
  @moduledoc """
  Handle the spot instance processing. Right now it is a naive implementation
  with aws cli. Later on we will move it to use aws sdk.
  """
  require Logger

  alias Overseer.Adapter.EC2.LaunchSpec

  @retries 10
  @retry_interval 500

  @doc """
  Request a spot instance and get the
  """
  @spec request(LaunchSpec) :: map
  def request(spec) do
    launch_spec = get_launch_spec(spec)

    cmd =
      "aws ec2 request-spot-instances --region #{spec.region} --spot-price #{spec.price} --launch-specification '#{
        launch_spec
      }'"

    cmd
    |> run_aws_cli
    |> get_id
  end

  @spec get_request_status(String.t()) :: String.t() | nil
  def get_request_status(req_id), do: get_request_status(req_id, @retries)

  @spec get_instance_info(String.t()) :: map
  def get_instance_info(instance_id) do
    cmd = "aws ec2 describe-instances --instance-ids #{instance_id}"

    cmd
    |> run_aws_cli
    |> Map.get("Reservations")
    |> List.first()
    |> Map.get("Instances")
    |> List.first()
  end

  @spec cancel_request(String.t()) :: :ok | {:error, term}
  def cancel_request(req_id) do
    cmd = "aws ec2 cancel-spot-instance-requests --spot-instance-request-ids #{req_id}"

    try do
      state =
        cmd
        |> run_aws_cli
        |> Map.get("CancelledSpotInstanceRequests")
        |> List.first()
        |> Map.get("State")

      case state do
        "cancelled" -> :ok
        _ -> {:error, "Failed to cancel the request #{req_id}"}
      end
    rescue
      error ->
        {:error, error}
    end
  end

  @spec terminate_instance(String.t()) :: :ok | {:error, term}
  def terminate_instance(instance_id) do
    cmd = "aws ec2 terminate-instances --instance-ids #{instance_id}"

    try do
      code =
        cmd
        |> run_aws_cli
        |> Map.get("TerminatingInstances")
        |> List.first()
        |> Map.get("CurrentState")
        |> Map.get("Code")

      case code do
        16 -> {:error, "Instance #{instance_id} is still running"}
        _ -> :ok
      end
    rescue
      error ->
        {:error, error}
    end
  end

  @spec get_instance_hostname(map, boolean) :: String.t()
  def get_instance_hostname(instance, priv? \\ true) do
    case priv? do
      true -> Map.get(instance, "PrivateDnsName")
      false -> Map.get(instance, "PublicDnsName")
    end
  end

  @spec get_instance_ip(map, boolean) :: String.t()
  def get_instance_ip(instance, priv? \\ true) do
    case priv? do
      true -> Map.get(instance, "PrivateIpAddress")
      false -> Map.get(instance, "PublicIpAddress")
    end
  end

  # private function
  defp get_request_status(req_id, 0) do
    # we treat it as failed so cancel the request
    cmd = "aws ec2 cancel-spot-instance-requests --spot-instance-request-ids #{req_id}"
    run_aws_cli(cmd)
    nil
  end

  defp get_request_status(req_id, n) do
    cmd = "aws ec2 describe-spot-instance-requests --spot-instance-request-id #{req_id}"

    id =
      cmd
      |> run_aws_cli
      |> get_id("InstanceId")

    case id do
      nil ->
        :timer.sleep(@retry_interval)
        get_request_status(req_id, n - 1)

      _ ->
        id
    end
  end

  defp get_id(response, name \\ "SpotInstanceRequestId") do
    response
    |> Map.get("SpotInstanceRequests")
    |> List.first()
    |> Map.get(name)
  end

  defp run_aws_cli(cmd) do
    result =
      cmd
      |> to_charlist
      |> :os.cmd()
      |> to_string
      |> Jason.decode()

    case result do
      {:ok, data} ->
        data

      {:error, err} ->
        Logger.error(
          "Got error #{inspect(err)}. result: #{inspect(result)}. CLI: #{inspect(cmd)}"
        )

        nil
    end
  end

  defp get_launch_spec(args) do
    data = %{
      "KeyName" => args.key_name,
      "ImageId" => args.image,
      "UserData" => get_user_data(args),
      "InstanceType" => args.instance_type,
      "Placement" => %{
        "AvailabilityZone" => args.zone
      },
      "IamInstanceProfile" => %{
        "Arn" => args.iam_role
      },
      "NetworkInterfaces" => [
        %{
          "DeviceIndex" => 0,
          SubnetId: args.subnet,
          Groups: args.security_groups,
          AssociatePublicIpAddress: args.pub_ip?
        }
      ]
    }

    Jason.encode!(data)
  end

  defp get_user_data(_args) do
    %{
      name: node(),
      cookie: :erlang.get_cookie()
    }
    |> Jason.encode!()
    |> Base.encode64()
  end
end
