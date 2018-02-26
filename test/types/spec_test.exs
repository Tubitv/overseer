defmodule OverseerTest.Spec do
  use ExUnit.Case
  alias Overseer.Spec
  alias Overseer.Adapters.Local
  alias OverseerTest.Utils

  test "create spec with invalid data" do
    good_file = Utils.get_fixture_path("modules/beam/Elixir.AutoConn.beam")
    release = {:module, good_file, {AutoConn, :start_link}}
    assert_raise ArgumentError, fn -> Spec.create(Local, %{prefix: 1}, release) end
    assert_raise ArgumentError, fn -> Spec.create(SomethingWrong, %{prefix: "abc"}, release) end
    assert_raise ArgumentError, fn -> Spec.create(Local, %{prefix: "abc"}, {}) end
    assert_raise ArgumentError, fn -> Spec.create(Local, %{prefix: "abc"}, {:module, "/_not_exist_file"}) end
    assert_raise ArgumentError, fn -> Spec.create(Local, %{prefix: "abc"}, {:abc, good_file}) end
  end

  test "create spec with valid data" do
    good_file = Utils.get_fixture_path("modules/beam/Elixir.AutoConn.beam")
    release = {:module, good_file, {AutoConn, :start_link}}
    spec = Spec.create(Local, %{prefix: "abc"}, release)
    assert spec.adapter == Local
    assert spec.args.prefix == "abc"
    assert spec.release.type == :module
  end
end
