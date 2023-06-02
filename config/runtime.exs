import Config

port = fn name, default ->
  System.get_env(name, default) |> String.to_integer()
end

secret = fn name ->
  case System.get_env(name) do
    nil -> nil
    file -> File.read!(file)
  end
end

config :nix_cache_mesh,
  port: port.("PORT", "9898"),
  nix_serve_host: System.get_env("NIX_SERVE_HOST", "localhost"),
  nix_serve_port: port.("NIX_SERVE_PORT", "5000")

config :libcluster,
  topologies: [
    gossip: [
      strategy: Elixir.Cluster.Strategy.Gossip,
      config: [
        port: port.("MULTICAST_PORT", "45892"),
        multicast_if: System.get_env("MULTICAST_INTERFACE", "127.0.0.1"),
        if_addr: System.get_env("MULTICAST_ADDRESS", "0.0.0.0"),
        secret: secret.("MULTICAST_SECRET_FILE")
      ]
    ]
  ]
