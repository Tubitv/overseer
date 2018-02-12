defmodule App2.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {App2.Server, []},
    ]

    opts = [strategy: :one_for_one, name: App2.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
