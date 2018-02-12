defmodule App1.MixProject do
  use Mix.Project

  def project do
    [
      app: :app1,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {App1.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:cowboy, "~> 2.2.0"},
      {:gen_state_machine, "~> 2.0"},
      {:jason, "~> 1.0"},
      {:plug, "~> 1.5.0-rc.1"},

      {:app2, in_umbrella: true},

    ]
  end
end
