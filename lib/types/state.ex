defmodule Overseer.State do
  @moduledoc false
  alias Overseer.{Labor, Spec, State, Utils}

  @type t :: %__MODULE__{
          mod: module,
          spec: Spec,
          labors: %{required(String.t()) => Labor},
          state: any
        }

  defstruct mod: Overseer.MissingModule,
            spec: %Spec{},
            labors: %{},
            state: nil

  def create(mod, adapter, adapter_args, release, state, options) do
    Utils.assert(Code.ensure_loaded?(mod), true, "Module #{inspect(mod)} cannot be loaded")

    spec = Spec.create(adapter, adapter_args, release, options)

    %State{
      mod: mod,
      spec: spec,
      state: state
    }
  end
end
