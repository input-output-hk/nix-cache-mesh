{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    nix-serve-ng.url = "github:aristanetworks/nix-serve-ng";
    nix-serve-ng.inputs.nixpkgs.follows = "nixpkgs";
    inclusive.url = "github:input-output-hk/nix-inclusive";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin"];

      imports = [
        inputs.flake-parts.flakeModules.easyOverlay
        inputs.treefmt-nix.flakeModule
      ];

      flake.nixosModules.nix-cache-mesh = {
        config,
        pkgs,
        lib,
        ...
      }: let
        cfg = config.services.nix-cache-mesh;
      in {
        options.services.nix-cache-mesh = {
          enable = lib.mkEnableOption "nix-cache-mesh";

          package = lib.mkOption {
            type = lib.types.package;
            default = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.nix-cache-mesh;
            description = "Package to use";
          };

          port = lib.mkOption {
            type = lib.types.port;
            default = 6567;
            description = "Port to listen on";
          };

          host = lib.mkOption {
            type = lib.types.str;
            default = "localhost";
            description = "Host to listen on";
          };

          nixServeHost = lib.mkOption {
            type = lib.types.str;
            default = "localhost";
            description = "Host to connect to nix-serve on";
          };

          nixServePort = lib.mkOption {
            type = lib.types.port;
            default = config.services.nix-serve.port;
            description = "Port to connect to nix-serve on";
          };

          multicast = {
            address = lib.mkOption {
              type = lib.types.str;
              default = "0.0.0.0";
              description = "Address to listen on for multicast";
            };

            port = lib.mkOption {
              type = lib.types.port;
              default = 45892;
              description = "Port to listen on for multicast";
            };

            interface = lib.mkOption {
              type = lib.types.str;
              default = "127.0.0.1";
              description = "Interface to listen on for multicast";
            };

            secretFile = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
              description = "Path to secret key file to encrypt gossip traffic";
            };
          };

          dist = {
            cookieFile = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
              description = "Path to file containing the Erlang cookie";
            };

            address = lib.mkOption {
              type = lib.types.str;
              default = "0.0.0.0";
              description = "Address to listen on for Erlang distribution";
            };

            port = lib.mkOption {
              type = lib.types.port;
              default = 4369;
              description = "Port to listen on for Erlang distribution";
            };

            portMin = lib.mkOption {
              type = lib.types.port;
              default = 49152;
              description = "Minimum port to listen on for Erlang distribution";
            };

            portMax = lib.mkOption {
              type = lib.types.port;
              default = 65535;
              description = "Maximum port to listen on for Erlang distribution";
            };
          };
        };

        config = lib.mkIf cfg.enable {
          services.nix-serve.enable = lib.mkDefault true;

          environment.systemPackages = [
            cfg.package
          ];

          users.users.nix-cache-mesh = {
            isSystemUser = true;
            group = "nix-cache-mesh";
            home = "/var/lib/nix-cache-mesh";
            createHome = true;
          };

          users.groups.nix-cache-mesh = {
            members = ["nix-cache-mesh"];
          };

          systemd.services.nix-cache-mesh = {
            description = "nix-cache-mesh";
            wantedBy = ["multi-user.target"];
            after = ["network.target" "nix-serve.service"];

            environment = {
              PORT = "${toString cfg.port}";
              HOST = cfg.host;
              NIX_SERVE_HOST = cfg.nixServeHost;
              NIX_SERVE_PORT = toString cfg.nixServePort;
              ERL_EPMD_PORT = toString cfg.dist.port;
              ERL_FLAGS = "-kernel inet_dist_listen_min ${toString cfg.dist.portMin} inet_dist_listen_max ${toString cfg.dist.portMax}";
              MULTICAST_PORT = toString cfg.multicast.port;
              MULTICAST_ADDRESS = cfg.multicast.address;
              MULTICAST_INTERFACE = cfg.multicast.interface;
              RELEASE_DISTRIBUTION = "name";
              HOME = "/var/lib/nix-cache-mesh";
            };

            serviceConfig = let
              execStart = pkgs.writeShellApplication {
                name = "nix-cache-mesh";
                runtimeInputs = [cfg.package pkgs.strace pkgs.iproute2 pkgs.jq];
                text = ''
                  export RELEASE_NAME="nix-cache-mesh@${cfg.multicast.interface}"

                  RELEASE_COOKIE="${
                    if (cfg.dist.cookieFile == null)
                    then "nix-cache-mesh"
                    else "$(< \"$CREDENTIALS_DIRECTORY/cookie\")"
                  }"
                  export RELEASE_COOKIE

                  ${lib.optionalString (cfg.multicast.secretFile != null) ''
                    export MULTICAST_SECRET_FILE="$CREDENTIALS_DIRECTORY/secret"
                  ''}

                  exec ${cfg.package}/bin/nix_cache_mesh start
                '';
              };
            in {
              Type = "simple";
              ExecStart = "${execStart}/bin/nix-cache-mesh";
              Restart = "always";
              RestartSec = "30";
              User = "nix-cache-mesh";
              Group = "nix-cache-mesh";
              DynamicUser = true;
              LoadCredential =
                (lib.optional (cfg.multicast.secretFile != null)
                  "secret:${cfg.multicast.secretFile}")
                ++ (lib.optional (cfg.dist.cookieFile != null) "cookie:${cfg.dist.cookieFile}");
            };
          };
        };
      };

      perSystem = {
        pkgs,
        final,
        config,
        inputs',
        system,
        self',
        ...
      }: {
        overlayAttrs = {
          inherit (self'.packages) nix-cache-mesh;
        };

        packages.default = self'.packages.nix-cache-mesh;

        packages.nix-cache-mesh = let
          beam = pkgs.beam_nox;
          packages = beam.packagesWith beam.interpreters.erlang;
        in
          packages.mixRelease {
            pname = "nix-cache-mesh";
            version = "0.1.0";
            src = inputs.inclusive.lib.inclusive ./. [
              ./mix.exs
              ./config
              ./lib
              ./test
            ];

            mixNixDeps = import ./mix.nix {
              inherit (pkgs) beamPackages lib;
            };
          };

        packages.ncm = pkgs.writeShellApplication {
          name = "ncm";
          runtimeInputs = [pkgs.jq pkgs.iproute2];
          text = ''
            MULTICAST_INTERFACE="$(ip -j addr show eth1 | jq -r '.[0].addr_info[0].local')"
            export MULTICAST_INTERFACE
            export RELEASE_DISTRIBUTION="name"
            export RELEASE_NAME="nix-cache-mesh@$MULTICAST_INTERFACE"
            export RELEASE_COOKIE="''${RELEASE_COOKIE:-"nix-cache-mesh"}"

            exec ${self'.packages.nix-cache-mesh}/bin/nix_cache_mesh "$@"
          '';
        };

        packages.module-doc =
          (pkgs.nixosOptionsDoc {
            options =
              (inputs.nixpkgs.lib.nixosSystem {
                inherit system;
                modules = [inputs.self.nixosModules.nix-cache-mesh];
              })
              .options
              .services
              .nix-cache-mesh;
          })
          .optionsCommonMark;

        packages.test = ((import (inputs.nixpkgs + "/nixos/tests/make-test-python.nix")) {
          name = "nix-cache-mesh";

          nodes = let
            common = {
              pkgs,
              lib,
              config,
              ...
            }: {
              imports = [inputs.self.nixosModules.nix-cache-mesh];

              environment.systemPackages = [self'.packages.ncm pkgs.iproute2 pkgs.jq pkgs.strace pkgs.lsof pkgs.tcpdump pkgs.curl];
              users.users.root.hashedPassword = "";
              services.getty.autologinUser = "root";
              services.nix-serve.secretKeyFile = builtins.toFile "secret" (lib.fileContents ./test/fixtures/secret.key);

              nix.settings = {
                experimental-features = "nix-command flakes";
                substituters = lib.mkForce ["http://127.0.0.1:${toString config.services.nix-cache-mesh.port}"];
                trusted-public-keys = [(lib.fileContents ./test/fixtures/public.key)];
              };

              services.nix-cache-mesh = {
                enable = true;
                dist.cookieFile = builtins.toFile "cookie" "nix-cache-mesh";
                multicast.secretFile = builtins.toFile "secret" "some-secret";
              };

              networking.firewall = {
                enable = lib.mkDefault true;
                logRefusedPackets = true;

                allowedTCPPorts = lib.mkDefault [
                  config.services.nix-serve.port
                  config.services.nix-cache-mesh.dist.port
                  config.services.nix-cache-mesh.port
                ];

                interfaces.eth1 = {
                  allowedUDPPorts = lib.mkDefault [
                    config.services.nix-cache-mesh.dist.port
                    config.services.nix-cache-mesh.multicast.port
                  ];

                  allowedTCPPorts = lib.mkDefault [
                    config.services.nix-serve.port
                    config.services.nix-cache-mesh.dist.port
                    config.services.nix-cache-mesh.port
                  ];

                  allowedTCPPortRanges = lib.mkDefault [
                    {
                      from = config.services.nix-cache-mesh.dist.portMin;
                      to = config.services.nix-cache-mesh.dist.portMax;
                    }
                  ];
                };
              };
            };
          in {
            machine1 = {
              imports = [common];
              services.nix-cache-mesh.multicast.interface = "192.168.1.1";
              environment.systemPackages = [pkgs.hello];
            };

            machine2 = {
              imports = [common];
              services.nix-cache-mesh.multicast.interface = "192.168.1.2";
            };
          };

          testScript = ''
            machine1.wait_for_unit("nix-serve.service")
            machine2.wait_for_unit("nix-serve.service")

            machine1.wait_for_unit("nix-cache-mesh.service")
            machine2.wait_for_unit("nix-cache-mesh.service")

            machine1.wait_until_succeeds("ncm rpc '1 = length(Node.list())'")
            machine2.succeed("ncm rpc '1 = length(Node.list())'")

            machine2.succeed(
              "nix build ${pkgs.hello.outPath}",
              "test -L result"
            )
          '';
        }) {inherit pkgs system;};

        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with final; [
            # formatting
            config.treefmt.package

            # lint
            statix
            shellcheck

            # Erlang
            elixir
            mix2nix

            # dev
            elixir-ls
            watchexec
            nodejs_latest
            inputs'.nix-serve-ng.packages.default
          ];

          shellHook = ''
            ln -sf ${config.treefmt.build.configFile} treefmt.toml
          '';
        };

        formatter = pkgs.writeShellApplication {
          name = "treefmt";
          runtimeInputs = [config.treefmt.package];
          text = ''
            exec treefmt
          '';
        };

        treefmt = {
          programs.alejandra.enable = true;
          projectRootFile = "flake.nix";
        };
      };
    };
}
