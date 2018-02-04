defmodule ExampleApp.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {ExampleApp.Server, []},
    ]

    opts = [strategy: :one_for_one, name: ExampleApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
