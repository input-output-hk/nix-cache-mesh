defmodule NixCacheMesh.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Plug.Cowboy,
       scheme: :http,
       plug: NixCacheMesh.Plug,
       options: [port: Application.get_env(:nix_cache_mesh, :port)]},
      {NixCacheMesh.Peer,
       nix_serve_host: Application.get_env(:nix_cache_mesh, :nix_serve_host),
       nix_serve_port: Application.get_env(:nix_cache_mesh, :nix_serve_port)},
      {Cluster.Supervisor,
       [
         Application.get_env(:libcluster, :topologies),
         [name: NixCacheMesh.ClusterSupervisor]
       ]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: NixCacheMesh.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
