defmodule Overseer.Release do
  @moduledoc """
  Definition of the release struct
  """
  alias Overseer.{Release, Utils}

  @release_types [:module, :release]

  @type release_type :: :module | :release
  @type entry_point :: {module, atom, list(any)}
  @type t :: %__MODULE__{
          type: release_type,
          url: String.t(),
          entry: entry_point
        }

  defstruct type: :release,
            url: nil,
            entry: nil

  def create({type, url}), do: create({type, url, nil})

  def create({type, url, entry}) do
    Utils.assert(type in @release_types, true, "Unsupported release type #{type}")
    Utils.assert(ExLoader.valid_file?(url), true, "Release file #{url} cannot be loaded")

    mfa =
      case entry do
        nil -> nil
        m when is_atom(m) -> {m, :link}
        {m, f} -> {m, f}
        _ -> raise ArgumentError, "Release entry is not a correct MFA: #{inspect(entry)}"
      end

    %Release{
      type: type,
      url: url,
      entry: mfa
    }
  end
end
