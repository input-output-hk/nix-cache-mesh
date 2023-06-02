defmodule NixCacheMesh.MixProject do
  use Mix.Project

  def project do
    [
      app: :nix_cache_mesh,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {NixCacheMesh.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~> 1.14"},
      {:plug_cowboy, "~> 2.0"},
      {:httpoison, "~> 2.0"},
      {:libcluster, "~> 3.3"},
      {:exsync, "~> 0.2", only: :dev},
      {:file_system, "~> 0.2.10", only: :dev}
    ]
  end
end
