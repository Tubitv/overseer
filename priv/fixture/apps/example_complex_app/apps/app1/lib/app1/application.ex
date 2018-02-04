defmodule App1.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  alias Plug.Adapters.Cowboy2

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      Cowboy2.child_spec(scheme: :http, plug: App1.Router, options: [port: Application.get_env(:app1, :port)]),
      {App1.Server, []}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: App1.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
