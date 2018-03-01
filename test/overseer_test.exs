defmodule OverseerTest do
  use ExUnit.Case
  alias Overseer.Labor

  @ec2_adapter {Overseer.Adapters.EC2,
                %{
                  key_name: "test",
                  price: 0.05,
                  image: "ami-31bb8c7f",
                  instance_type: "t2.nano",
                  iam_role: "test-role",
                  subnet: "subnet-11223344",
                  security_groups: ["sg-11223344"],
                  prefix: "test_ec2_"
                }}

  @local_adapter {Overseer.Adapters.Local, %{prefix: "test_local_"}}

  @opts [
    strategy: :simple_one_for_one,
    max_nodes: 10
  ]

  @release {:release, OverseerTest.Utils.get_fixture_path("apps/tarball/example_app.tar.gz")}

  setup_all do
    Node.start(:"test-overseer@127.0.0.1", :longnames)
    :ok
  end

  test "MyOverseer start_link / init work for external module" do
    data = {@ec2_adapter, @release, @opts}
    assert {:ok, pid} = MyOverseer.start_link(data, name: MyOverseer)
    assert MyOverseer.call(:state) == %{}
    Process.exit(pid, :kill)
  end

  test "Myoverseer start_link / init work for direct call" do
    data = {@ec2_adapter, @release, @opts}
    assert {:ok, pid} = Overseer.start_link(data, name: MyOverseer)
    Process.exit(pid, :kill)
  end

  test "Myoverseer start_child with local adapter will create a new node" do
    data = {@local_adapter, @release, @opts}
    assert {:ok, pid} = MyOverseer.start_link(data, name: MyOverseer)

    assert %Labor{name: name} = MyOverseer.start_child(pid)

    data = MyOverseer.debug()
    assert Enum.count(data.labors) == 1
    labor = Map.get(data.labors, name)
    assert Labor.is_disconnected(labor) == false

    assert :ok = :rpc.call(name, :init, :stop, [])
    Process.exit(pid, :kill)
  end

  test "start 2 children and terminate one should leave one" do
    data = {@local_adapter, @release, @opts}
    assert {:ok, pid} = MyOverseer.start_link(data, name: MyOverseer)

    assert %Labor{name: name1} = MyOverseer.start_child(pid)
    assert %Labor{name: name2} = MyOverseer.start_child(pid)

    data = MyOverseer.debug()
    assert Enum.count(data.labors) == 2
    labor2 = Map.get(data.labors, name2)
    assert Labor.is_disconnected(labor2) == false
    MyOverseer.terminate_child(name2)
    data = wait_termination(MyOverseer.debug(), 6)
    assert Enum.count(data.labors) == 1
    assert :ok = :rpc.call(name1, :init, :stop, [])
    Process.exit(pid, :kill)
  end

  test "count_children shall reflect the number of non terminated children" do
    data = {@local_adapter, @release, @opts}
    assert {:ok, pid} = MyOverseer.start_link(data, name: MyOverseer)

    n = 5

    labors =
      1..n
      |> Enum.map(fn _ -> MyOverseer.start_child() end)

    [first_labor | rest] = labors
    MyOverseer.terminate_child(first_labor.name)
    assert n - 1 == MyOverseer.count_children()
    Enum.each(rest, fn labor -> assert :ok = :rpc.call(labor.name, :init, :stop, []) end)
    Process.exit(pid, :kill)
  end

  test "cannot create more child then max_nodes" do
    opts = [strategy: :simple_one_for_one, max_nodes: 1]
    assert {:ok, pid} = MyOverseer.start_link({@local_adapter, @release, opts}, name: MyOverseer)

    assert %Labor{name: name1} = MyOverseer.start_child()
    assert nil == MyOverseer.start_child()

    MyOverseer.terminate_child(name1)
    assert %Labor{name: name2} = MyOverseer.start_child()

    assert :ok = :rpc.call(name2, :init, :stop, [])
    Process.exit(pid, :kill)
  end

  test "disconnected children shall be removed after timeout" do
    timeout = 1000
    mod_file = OverseerTest.Utils.get_fixture_path("modules/beam/Elixir.AutoConn.beam")
    release = {:module, mod_file, {AutoConn, :start_link}}
    opts = [strategy: :simple_one_for_one, conn_timeout: timeout]
    assert {:ok, pid} = MyOverseer.start_link({@local_adapter, release, opts}, name: MyOverseer)

    assert %Labor{name: name} = MyOverseer.start_child()
    :timer.sleep(timeout)

    # AutoConn is loaded and started once connected. make sure remote node destroy itself
    assert :ok = :rpc.call(name, AutoConn, :halt, [2000])
    # force to change the cookie so that the remote node cannot auto reconnect.
    assert true = :rpc.call(name, :erlang, :set_cookie, [name, :badcookie])
    :rpc.call(name, AutoConn, :disconnect, [])

    :timer.sleep(timeout + 100)
    assert MyOverseer.count_children() == 0
    Process.exit(pid, :kill)
  end

  test "terminate all shall kill all children" do
    timeout = 1000
    data = {@local_adapter, @release, @opts}
    assert {:ok, pid} = MyOverseer.start_link(data, name: MyOverseer)

    Enum.each(1..5, fn _ -> MyOverseer.start_child() end)

    :timer.sleep(timeout)
    MyOverseer.terminate_all_children()
    assert 0 == MyOverseer.count_children()
    Process.exit(pid, :kill)
  end

  # private functions
  defp wait_termination(_data, 0), do: MyOverseer.debug()

  defp wait_termination(old_data, n) do
    data = MyOverseer.debug()

    case old_data == data do
      true ->
        :timer.sleep(200)
        wait_termination(data, n - 1)

      false ->
        data
    end
  end
end
