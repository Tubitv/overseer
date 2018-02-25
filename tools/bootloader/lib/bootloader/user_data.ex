defmodule Bootloader.Metadata do
  @moduledoc """
  HTTP client to retrieve user-data from http://169.254.169.254/latest/user-data
  """
  use Tesla

  plug Tesla.Middleware.BaseUrl, "http://169.254.169.254/latest"
  plug Tesla.Middleware.FollowRedirects

  def get_user_data do
    res = get("/user-data")
    res.body
    |> Base.decode64()
    |> Jason.decode!()
  end
end
