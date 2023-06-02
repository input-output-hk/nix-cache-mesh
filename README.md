# nix-cache-mesh

nix-cache-mesh is a router for Nix binary stores.

It creates a mesh cluster, and routes requests to other instances if they can
provide the desired store path.

By default, it starts alongside
[nix-serve](https://github.com/edolstra/nix-serve), but we recommend
[nix-serve-ng](https://github.com/aristanetworks/nix-serve-ng) as a faster
drop-in replacement (we may change this default when it gets added to nixpkgs).

Discovery is done by default using [UDP
Multicast](https://hexdocs.pm/libcluster/Cluster.Strategy.Gossip.html#content)
on port `45892`.
Although other
[strategies](https://hexdocs.pm/libcluster/readme.html#clustering) could be
utilized, this is not configurable right now.

## Features

- Automatic cluster formation/healing
- Robust, safe, and easy to understand
- Written in about 100 Lines of [Elixir](https://elixir-lang.org/).

## Warning

* Communication within the mesh is not encrypted, only membership is restricted
  by the cookie and multicast messages are encrypted when the secret is set.

## Building

    nix build

## Testing

    nix build .#test

## Usage

Add this repo to your flake inputs:

    inputs.nix-cache-mesh.url = "github:input-output-hk/nix-cache-mesh";

The import the module into your configuration and set all required options:

    {
      imports = [
        inputs.nix-cache-mesh.nixosModules.nix-cache-mesh
      ];

      services.nix-cache-mesh = {
        enable = true;
        dist.cookieFile = builtins.toFile "cookie" "nix-cache-mesh";
        multicast.secretFile = builtins.toFile "secret" "some-secret";
      };
    }

For managing the `secretFile` and `tokenFile` we recommend solutions like
[sops-nix](https://github.com/Mic92/sops-nix) or
[agenix](https://github.com/ryantm/agenix), but also take a look at the
[Comparison of secret managing schemes](https://nixos.wiki/wiki/Comparison_of_secret_managing_schemes)
in the NixOS Wiki.

## License

This project is licensed under the Apache License, Version 2.0.
