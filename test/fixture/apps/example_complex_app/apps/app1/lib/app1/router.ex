defmodule App1.Router do
  use Plug.Router
  use Plug.ErrorHandler

  require Logger

  plug Plug.RequestId
  plug Plug.Logger
  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["application/json"],
    json_decoder: Jason

  plug :match
  plug :dispatch

  get "/health" do
    send_json(conn, %{status: :ok})
  end

  get "/hello" do
    msg = Map.get(conn.params, "msg", "tyr")
    send_json(conn, %{result: App1.hello(msg)})
  end

  match _ do
    send_error(conn, "path not found", :not_found)
  end

  defp send_error(conn, msg, status) do
    conn
    |> send_json(%{error: msg}, status)
    |> halt
  end

  defp send_json(conn, data, status \\ :ok) do
    {resp, code} = case Jason.encode(data, maps: :strict) do
      {:ok, encoded} -> {encoded, status}
      {:error, _} ->
        {Jason.encode!(%{error: "data cannot be encoded"}), :unprocessable_entity}
    end

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(code, resp)
  end
end
