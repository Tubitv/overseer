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

    assert :ok = :rpc.call(name, :init, :stop, [])
    Process.exit(pid, :kill)
  end
end
