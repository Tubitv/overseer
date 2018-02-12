defmodule Overseer.Adapters.Local do
  @moduledoc """
  Adapter for spawning local nodes.
  """
  @behaviour Overseer.Adapter

  alias Overseer.{Labor}

  def validate(args) do
    {:ok, args}
  end

  def spawn(spec) do
    id = Overseer.Utils.gen_id(5)
    name = get_node_name(spec.args[:prefix], id, node())
    start_node(name)

    # since the node is brought up by us we just connect to it directly
    connect(name)
    {:ok, Labor.create(name)}
  end

  def terminate(labor) do
    :rpc.call(labor.name, :init, :stop, [])
    {:ok, Labor.terminated(labor)}
  end

  # private functions
  defp start_node(name) do
    cmd = "iex --name #{name} --cookie #{:erlang.get_cookie()} --detached --hidden --no-halt"
    :os.cmd(to_charlist(cmd))
  end

  defp connect(name), do: connect(name, 3)

  defp connect(name, 0) do
    raise "Cannot connect to #{name}"
  end

  defp connect(name, n) do
    :timer.sleep(50)

    case Node.connect(name) do
      true -> true
      false -> connect(name, n - 1)
    end
  end

  def get_node_name(prefix, id, parent) do
    name = "#{prefix}#{id}"
    [_, domain] = String.split(to_string(parent), "@", parts: 2)
    :"#{name}@#{domain}"
  end
end
