defmodule Overseer.MixProject do
  use Mix.Project

  @version File.cwd!() |> Path.join("version") |> File.read!() |> String.trim()

  def project do
    [
      app: :overseer,
      version: @version,
      elixir: "~> 1.6",
      description: description(),
      package: package(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),

      # exdocs
      # Docs
      name: "Overseer",
      source_url: "https://github.com/tubitv/overseer",
      homepage_url: "https://github.com/tubitv/overseer",
      docs: [
        main: "Overseer",
        extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: elixirc_paths(:test)
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ex_loader, "~> 0.4"},
      {:jason, "~> 1.0"},
      {:nanoid, "~> 1.0"},
      {:vex, "~> 0.6.0"},
      # dev & test
      {:credo, "~> 0.8", only: [:dev, :test]},
      {:ex_doc, "~> 0.18", only: [:dev, :test]},
      {:pre_commit_hook, "~> 1.2", only: [:dev]}
    ]
  end

  defp description do
    """
    Overseer is similar to OTP Supervisor, but it supervise the erlang/elixir nodes.
    """
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*", "LICENSE*", "version"],
      licenses: ["MIT"],
      maintainers: ["tyr.chen@gmail.com"],
      links: %{
        "GitHub" => "https://github.com/tubitv/overseer",
        "Docs" => "https://hexdocs.pm/overseer"
      }
    ]
  end
end
