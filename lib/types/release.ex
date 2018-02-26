defmodule Overseer.Release do
  @moduledoc """
  Definition of the release struct
  """
  alias Overseer.{Release, Utils}
  alias GenExecutor.Ocb

  @release_types [:module, :release]

  @type release_type :: :module | :release
  @type pairing_mfa :: {module, (Ocb -> any)}
  @type t :: %__MODULE__{
          type: release_type,
          url: String.t(),
          do_pair: pairing_mfa
        }

  defstruct type: :release,
            url: nil,
            do_pair: nil

  def create({type, url}), do: create({type, url, nil})

  def create({type, url, do_pair}) do
    Utils.assert(type in @release_types, true, "Unsupported release type #{type}")
    Utils.assert(ExLoader.valid_file?(url), true, "Release file #{url} cannot be loaded")

    mfa =
      case do_pair do
        nil -> nil
        m when is_atom(m) -> {m, :pair}
        {m, f} -> {m, f}
        _ -> raise ArgumentError, "do_pair is not a correct MFA: #{inspect(do_pair)}"
      end

    %Release{
      type: type,
      url: url,
      do_pair: mfa
    }
  end

  def create(args),
    do: raise(ArgumentError, "args passed to Release.create is invalid: #{inspect(args)}")
end
