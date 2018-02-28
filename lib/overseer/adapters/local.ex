defmodule Overseer.Adapters.Local do
  @moduledoc """
  Adapter for spawning local nodes.
  """
  @behaviour Overseer.Adapter

  alias Overseer.{Labor}

  def validate(args) when is_map(args) do
    case Map.get(args, :prefix) do
      nil -> {:error, ":prefix must be provided for args of local adapter"}
      s when is_binary(s) -> {:ok, args}
      _ -> {:error, "value for the :prefix must be a string"}
    end
  end

  def validate(_args), do: {:error, "args must be a valid map"}

  def spawn(spec, init_state \\ nil) do
    id = Overseer.Utils.gen_id(5)
    name = get_node_name(spec.args[:prefix], id, node())
    start_node(name)

    # since the node is brought up by us we just connect to it directly
    connect(name)
    {:ok, Labor.create(name, init_state, nil)}
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
      _ -> connect(name, n - 1)
    end
  end

  def get_node_name(prefix, id, parent) do
    name = "#{prefix}#{id}"
    [_, domain] = String.split(to_string(parent), "@", parts: 2)
    :"#{name}@#{domain}"
  end
end
