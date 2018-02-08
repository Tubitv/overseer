defmodule GenExecutor.Telemetry do
  @moduledoc """
  Telemetry data sent from executor node
  """
  alias GenExecutor.Telemetry

  @type telemetry_type :: :progress | :log | :metrics | :general
  @type t :: %__MODULE__{
          name: node,
          id: String.t(),
          type: telemetry_type,
          data: any
        }

  defstruct name: :noname,
            id: nil,
            type: :general,
            data: nil

  def create(name, id, type, data) do
    %Telemetry{
      name: name,
      id: id,
      type: type,
      data: data
    }
  end
end
