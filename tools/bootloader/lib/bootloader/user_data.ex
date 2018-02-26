defmodule Bootloader.Metadata do
  @moduledoc """
  HTTP client to retrieve user-data from http://169.254.169.254/latest/user-data
  """
  use Tesla

  plug Tesla.Middleware.BaseUrl, "http://169.254.169.254/latest"
  plug Tesla.Middleware.FollowRedirects

  def get_user_data do
    res = get("/user-data/")
    res.body
    |> Jason.decode!()
  end

  def get_ip do
    {:ok, addrs} = :inet.getif()
    get_ip(addrs)
  end

  defp get_ip([{addr, _, _} | _rest]) do
    addr
    |> Tuple.to_list
    |> Enum.join(".")
  end
end
