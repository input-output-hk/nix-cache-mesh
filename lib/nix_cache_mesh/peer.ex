defmodule NixCacheMesh.Peer do
  require Logger
  use GenServer

  def start_link(nix_serve_host: host, nix_serve_port: port) do
    GenServer.start_link(__MODULE__, {host, port}, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def handle_call({:head, {path, headers}}, _from, {host, port}) do
    url = "http://#{host}:#{port}#{path}"
    Logger.debug("HEAD #{url}")

    case HTTPoison.head!(url, headers) do
      %HTTPoison.Response{status_code: status, headers: response_headers} ->
        {:reply, {status, response_headers, port}, {host, port}}
    end
  end
end
