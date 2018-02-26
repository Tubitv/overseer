defmodule Bootloader.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Bootloader.Initd, []},
    ]

    opts = [strategy: :one_for_one, name: Bootloader.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
