import Config

# config :libcluster,
#   topologies: [
#     epmd: [
#       strategy: Elixir.Cluster.Strategy.LocalEpmd
#     ],
#     gossip: [
#       strategy: Elixir.Cluster.Strategy.Gossip,
#       config: [
#         port: 45892,
#         if_addr: "0.0.0.0",
#         multicast_addr: "255.255.255.255",
#         broadcast_only: true
#         # multicast_ttl: 1,
#         # multicast_if: "127.0.0.1",
#         # multicast_addr: "224.0.0.1",
#         # # multicast_addr: "228.6.7.8",
#         # # multicast_addr: "233.252.1.32",
#         # secret: "somepassword",
#       ]
#     ]
#   ]

# config :libcluster,
#   topologies: [
#     gossip: [
#       strategy: Elixir.Cluster.Strategy.Gossip,
#       config: [
#         port: 45892,
#         if_addr: "0.0.0.0",
#         multicast_addr: "255.255.255.255",
#         multicast_ttl: 2,
#         broadcast_only: true,
#         # multicast_addr: "255.255.255.255",
#         # multicast_if: "127.0.0.1",
#         # multicast_addr: "224.0.0.1",
#         # # multicast_addr: "228.6.7.8",
#         # # multicast_addr: "233.252.1.32",
#         # secret: "somepassword",
#       ]
#     ]
#   ]
