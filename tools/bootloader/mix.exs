defmodule Bootloader.MixProject do
  use Mix.Project

  @version File.cwd!() |> Path.join("version") |> File.read!() |> String.trim()

  def project do
    [
      app: :bootloader,
      version: @version,
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Bootloader.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:distillery, "~> 1.5.2"},
      {:tesla, "~> 0.10.0"},
      {:jason, "~> 1.0"}
    ]
  end
end
