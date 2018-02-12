defmodule GenExecutor.Ocb do
  @moduledoc """
  Overseer control block for remote node
  """
  alias Overseer.Spec
  alias GenExecutor.Ocb

  @type t :: %__MODULE__{
          name: node,
          pid: pid,
          spec: Spec
        }

  defstruct name: :noname,
            pid: nil,
            spec: nil

  def create(spec) do
    %Ocb{
      name: node(),
      pid: self(),
      spec: spec
    }
  end
end
