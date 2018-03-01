defmodule Overseer.State do
  @moduledoc false
  alias Overseer.{Labor, Spec, State, Utils}

  @type t :: %__MODULE__{
          mod: module,
          spec: Spec,
          labors: %{required(String.t()) => Labor},
          labor_state: any,
          state: any
        }

  defstruct mod: Overseer.MissingModule,
            spec: %Spec{},
            labors: %{},
            labor_state: nil,
            state: nil

  def create(mod, adapter, adapter_args, release, state, options) do
    Utils.assert(Code.ensure_loaded?(mod), true, "Module #{inspect(mod)} cannot be loaded")

    spec = Spec.create(adapter, adapter_args, release, options)
    {labor_state, global_state} = state

    %State{
      mod: mod,
      spec: spec,
      labor_state: labor_state,
      state: global_state
    }
  end
end
