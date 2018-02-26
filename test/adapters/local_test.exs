defmodule OverseerTest.Adapters.Local do
  use ExUnit.Case
  alias Overseer.Adapters.Local
  alias OverseerTest.Utils
  alias Overseer.{Spec, Labor}

  setup_all do
    Node.start(:"test-overseer@127.0.0.1", :longnames)
    :ok
  end

  test "local adapter shall validate the args" do
    assert {:error, _} = Local.validate({})
    assert {:error, _} = Local.validate(%{a: 1})
    assert {:error, _} = Local.validate(%{prefix: 1})
    assert {:ok, _} = Local.validate(%{prefix: "hello"})
  end

  test "local adapter shall spawn a new node locally" do
    good_file = Utils.get_fixture_path("modules/beam/Elixir.AutoConn.beam")
    release = {:module, good_file, {AutoConn, :start_link}}
    spec = Spec.create(Local, %{prefix: "abc"}, release)
    assert {:ok, labor} = Local.spawn(spec)
    assert String.starts_with?(to_string(labor.name), "abc")
    assert Labor.is_connected(labor) == false
    assert {:ok, labor1} = Local.terminate(labor)
    assert Labor.is_terminated(labor1) == true
  end
end
