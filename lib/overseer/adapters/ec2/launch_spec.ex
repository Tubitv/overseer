defmodule Overseer.Adapters.EC2.LaunchSpec do
  @moduledoc """
  EC2 spot instance args
  """
  alias Overseer.Adapters.EC2.LaunchSpec

  @default_tag %{
    "Key" => "overseer",
    "Value" => "overseer-executor"
  }

  @default_region "us-east-1"
  # default ubuntu 16.04
  @default_image "ami-07585467"
  @default_instance "t2.nano"
  @default_zone "us-east-1c"
  @default_price 0.01
  @default_pub_ip? false

  @regions [
    "ap-south-1",
    "eu-west-3",
    "eu-west-2",
    "eu-west-1",
    "ap-northeast-2",
    "ap-northeast-1",
    "sa-east-1",
    "ca-central-1",
    "ap-southeast-1",
    "ap-southeast-2",
    "eu-central-1",
    "us-east-1",
    "us-east-2",
    "us-west-1",
    "us-west-2"
  ]

  @instance_type_regex ~r/^[t|c|m|r|x|h|i|d|p|g][1-5]e?\.[nano|micro|small|medium|\d*x*large]/

  @type t :: %__MODULE__{
          key_name: String.t(),
          image: String.t(),
          region: String.t(),
          price: float,
          instance_type: String.t(),
          zone: String.t(),
          iam_role: String.t(),
          subnet: String.t(),
          security_groups: [String.t()],
          pub_ip?: boolean,
          tags: map
        }

  defstruct key_name: nil,
            image: @default_image,
            region: @default_region,
            price: @default_price,
            instance_type: @default_instance,
            zone: @default_zone,
            iam_role: nil,
            subnet: nil,
            security_groups: [],
            pub_ip?: @default_pub_ip?,
            tags: []

  use Vex.Struct

  validates(:key_name, presence: true)
  validates(:image, presence: true, format: ~r/^ami-[0-9a-f]+$/)
  validates(:region, inclusion: @regions)
  validates(:instance_type, presence: true, format: @instance_type_regex)

  def create(args) do
    result = %LaunchSpec{
      key_name: ensure_key(args, :key_name),
      image: ensure_key(args, :image, @default_image),
      region: ensure_key(args, :region, @default_region),
      price: ensure_key(args, :price, @default_price),
      instance_type: ensure_key(args, :instance_type, @default_instance),
      zone: ensure_key(args, :zone, @default_zone),
      iam_role: ensure_key(args, :iam_role),
      subnet: ensure_key(args, :subnet),
      security_groups: ensure_key(args, :security_groups),
      pub_ip?: ensure_key(args, :pub_ip?, @default_pub_ip?),
      tags: [@default_tag | ensure_key(args, :tags, [])]
    }

    unless LaunchSpec.valid?(result) do
      errors = Vex.errors(result)

      raise ArgumentError,
            "args for launching spot instance is not valid: #{inspect(result)}. #{inspect(errors)}"
    end

    result
  end

  defp ensure_key(args, key, default \\ nil) do
    Map.get(args, key) || System.get_env("LAUNCH_SPEC_#{String.upcase(to_string(key))}") ||
      default
  end
end
