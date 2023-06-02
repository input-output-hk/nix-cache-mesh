defmodule NixCacheMesh.Plug do
  use Plug.Router

  if Mix.env() == :dev do
    use Plug.Debugger
  end

  use Plug.ErrorHandler

  plug(:match)
  plug(:dispatch)

  head "/*_any" do
    proxy("HEAD", conn)
  end

  get "/*_any" do
    proxy("GET", conn)
  end

  put "/*_any" do
    send_resp(conn, 405, "Method Not Allowed")
  end

  match _ do
    send_resp(conn, 404, "oops")
  end

  defp proxy(method, conn) do
    {:ok, nodes} = :net_kernel.nodes_info()

    winner = nodes |> responded(conn) |> first_response()

    case winner do
      {node, {200, headers, port}} ->
        case method do
          "GET" ->
            {:net_address, _, ip, _, _} = nodes |> Keyword.get(node) |> Keyword.get(:address)

            conn
            |> put_resp_header("location", "http://#{ip}:#{port}#{conn.request_path}")
            |> send_resp(302, "")

          "HEAD" ->
            conn
            |> merge_resp_headers(headers)
            |> send_resp(200, "")
        end

      _ ->
        conn |> send_resp(404, "Not Found")
    end
  end

  defp responded(nodes, conn) do
    {ok, _} =
      GenServer.multi_call(
        Keyword.keys(nodes) ++ [Node.self()],
        NixCacheMesh.Peer,
        {:head, {conn.request_path, conn.req_headers}},
        500
      )

    ok
  end

  defp first_response(responded) do
    responded
    |> Enum.find(fn {_, val} ->
      case val do
        {200, _, _} -> true
        _ -> false
      end
    end)
  end
end
