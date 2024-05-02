{
  description = "Curriculum Template Project";

  nixConfig = {
    extra-substituters = [
      "https://devenv.cachix.org"
      "https://cachix.cachix.org"
      "https://nix-community.cachix.org"
      "https://dliberalesso.cachix.org"
    ];

    extra-trusted-public-keys = [
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "dliberalesso.cachix.org-1:7qs1S5Qd766dYFU86nVux/wRMZ8UEUbhn3Qxp/TwiOc="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs-lib.url = "github:nixos/nixpkgs/nixpkgs-unstable?dir=lib";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs-lib";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    flake-parts,
    nixpkgs,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        inputs.devenv.flakeModule
        inputs.treefmt-nix.flakeModule
      ];

      systems = nixpkgs.lib.systems.flakeExposed;

      perSystem = {
        config,
        self',
        inputs',
        lib,
        pkgs,
        system,
        ...
      }: {
        # Per-system attributes can be defined here. The self' and inputs'
        # module parameters provide easy access to attributes of the same
        # system.

        treefmt = {
          projectRootFile = "flake.nix";
          programs = {
            alejandra.enable = true;
            mix-format.enable = true;
          };
        };

        devenv.shells.default = {
          dotenv.enable = true;

          languages = {
            elixir.enable = true;
            erlang.enable = true;

            nix.enable = true;
          };

          packages =
            [
              pkgs.git
            ]
            ++ lib.optionals pkgs.stdenv.isLinux [pkgs.inotify-tools];

          pre-commit.hooks = {
            treefmt.enable = true;
            treefmt.package = config.treefmt.build.wrapper;
          };

          processes = {
            # phoenix.exec = "mix phx.server";
            livebook.exec = "livebook server start.livemd";
          };

          services = {
            postgres = {
              enable = true;
              initialScript = ''
                CREATE ROLE postgres WITH LOGIN PASSWORD 'postgres' SUPERUSER;
              '';
            };
          };

          enterShell = ''
            export PRE_COMMIT_HOME=$PWD/.cache/pre-commit
            export MIX_HOME=$PWD/.mix
            export HEX_HOME=$PWD/.hex
            export REBAR_CACHE_DIR=$PWD/.cache/rebar3
            export PATH=$PWD/.mix/escripts:$PATH
            export LIVEBOOK_HOME=$PWD

            mix local.hex --force --if-missing
            mix local.rebar --force --if-missing

            if [ ! "$(find -maxdepth 3 -type d -name "phx_new*")" ]; then
              mix archive.install --force hex phx_new
            fi

            if [ ! -f ".mix/escripts/livebook" ]; then
              mix escript.install --force hex livebook
            fi
          '';
        };
      };
    };
}
