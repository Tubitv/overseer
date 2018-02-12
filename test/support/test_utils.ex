defmodule OverseerTest.Utils do
  @moduledoc false
  alias Mix.Project

  def get_fixture_path(p) do
    Project.deps_path() |> Path.join("../test/fixture/#{p}")
  end
end
