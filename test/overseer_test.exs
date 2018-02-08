defmodule OverseerTest do
  use ExUnit.Case
  alias Overseer.Labor

  @ec2_adapter {Overseer.Adapters.EC2,
                [
                  prefix: "test_ec2_",
                  image: "ami-31bb8c7f",
                  type: "t2.nano",
                  spot?: true
                ]}

  @local_adapter {Overseer.Adapters.Local, [prefix: "test_local_"]}

  @opts [
    strategy: :simple_one_for_one,
    max_nodes: 10
  ]

  @release OverseerTest.Utils.get_path("apps/tarball/example_app.tar.gz")

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

    overseer = node()
    assert %Labor{overseer: ^overseer, name: name} = MyOverseer.start_child(pid)

    data = MyOverseer.debug()
    assert Enum.count(data.labors) == 1
    labor = Map.get(data.labors, name)
    assert Labor.is_connected(labor) == true

    assert :ok = :rpc.call(name, :init, :stop, [])
    Process.exit(pid, :kill)
  end

  test "start 2 children and terminate one should leave one" do
    data = {@local_adapter, @release, @opts}
    assert {:ok, pid} = MyOverseer.start_link(data, name: MyOverseer)

    overseer = node()
    assert %Labor{overseer: ^overseer, name: name1} = MyOverseer.start_child(pid)
    assert %Labor{overseer: ^overseer, name: name2} = MyOverseer.start_child(pid)

    data = MyOverseer.debug()
    assert Enum.count(data.labors) == 2
    labor2 = Map.get(data.labors, name2)
    assert Labor.is_connected(labor2) == true
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

    overseer = node()

    assert %Labor{overseer: ^overseer, name: name1} = MyOverseer.start_child()
    assert nil == MyOverseer.start_child()

    MyOverseer.terminate_child(name1)
    assert %Labor{overseer: ^overseer, name: name2} = MyOverseer.start_child()

    assert :ok = :rpc.call(name2, :init, :stop, [])
    Process.exit(pid, :kill)
  end

  test "disconnected children shall be removed after timeout" do
    timeout = 1000
    mod_file = OverseerTest.Utils.get_path("modules/beam/Elixir.AutoConn.beam")
    opts = [strategy: :simple_one_for_one, conn_timeout: timeout]
    assert {:ok, pid} = MyOverseer.start_link({@local_adapter, @release, opts}, name: MyOverseer)

    overseer = node()

    assert %Labor{overseer: ^overseer, name: name} = MyOverseer.start_child()

    ExLoader.load_module(mod_file, name)
    :rpc.call(name, AutoConn, :start_link, [overseer])
    # make sure remote node destroy itself
    :rpc.call(name, AutoConn, :halt, [5000])
    # force to change the cookie so that the remote node cannot auto reconnect.
    :rpc.call(name, :erlang, :set_cookie, [name, :badcookie])
    :rpc.call(name, AutoConn, :disconnect, [])
    :timer.sleep(timeout)
    assert MyOverseer.count_children() == 0
    Process.exit(pid, :kill)
  end

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
