{
  description = "Nix Task Runner";

  inputs = {
    nixpkgs.url = "github:meta-introspector/nixpkgs/nixos-23.11";
    utils.url = "github:meta-introspector/flake-utils";
    yarnpnp2nix.url = "github:meta-introspector/yarnpnp2nix";
    yarnpnp2nix.inputs.nixpkgs.follows = "nixpkgs";
    yarnpnp2nix.inputs.utils.follows = "utils";


  };

  outputs = inputs@{ self, nixpkgs, utils, ... }:
    let
      nixpkgsLib = nixpkgs.lib;
    in
    (utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (final: prev: {
              nodejs = prev.nodejs_20;
              yarn = (prev.yarn.override { nodejs = prev.nodejs_20; });
            })
          ];
        };

        mkYarnPackagesFromManifest = inputs.yarnpnp2nix.lib."${system}".mkYarnPackagesFromManifest;
        runnerYarnPackages = mkYarnPackagesFromManifest {
          inherit pkgs;
          yarnManifest = import ./runner/yarn-manifest.nix;
          packageOverrides = {
            "nix-task@workspace:." = {
              build = ''
                export PKG_PATH_BASH="${pkgs.bashInteractive}"
                export PKG_PATH_COREUTILS="${pkgs.coreutils}"
                export PKG_PATH_JQ="${pkgs.jq}"
                export PKG_PATH_NODEJS="${pkgs.nodejs}"
                export PKG_PATH_UTIL_LINUX="${pkgs.util-linux}"
                export CONF_NIX_LIB_PATH="${./nix/lib}"

                node build.js
              '';
              # procps needed by tree-kill package
              binSetup = ''
                export PATH="$PATH:${pkgs.procps}/bin"
              '';
            };
          };
        };
      in
      rec {
        devShells.default = import ./shell.nix {
          inherit pkgs;
        };
        packages = {
          default = runnerYarnPackages."nix-task@workspace:.";
        };

        tasks = {
          gemini = pkgs.callPackage ./nix/tasks/gemini.nix { inherit pkgs; gemini-cli = pkgs.gemini-cli; };
          run-gemini-cli = pkgs.callPackage ./nix/tasks/run-gemini-cli.nix { inherit pkgs; };
          solana-ai-trigger = pkgs.callPackage ./nix/tasks/solana-ai-trigger.nix { inherit pkgs; };
          process-solana-nar = pkgs.callPackage ./nix/tasks/process-solana-nar.nix { inherit pkgs; };
          helius-block-processor = pkgs.callPackage ./nix/tasks/helius-block-processor.nix { inherit pkgs; };
          solana-nix-trigger-interpreter = pkgs.callPackage ./nix/tasks/solana-nix-trigger-interpreter.nix { inherit pkgs; };
        };
      }
    )) // {
      lib = import ./nix/lib { lib = nixpkgsLib; };
    };
}
