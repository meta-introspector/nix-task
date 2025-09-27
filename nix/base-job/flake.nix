{
  description = "Base flake for common job definitions and utilities";

  inputs = {
    nixpkgs.url = "github:meta-introspector/nixpkgs/nixos-23.11";
    utils.url = "github:meta-introspector/flake-utils";
  };

  outputs = { self, nixpkgs, utils }:
    let
      nixpkgsLib = nixpkgs.lib;
    in
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        lib = {
          # A placeholder function for creating a base job
          mkBaseJob = { name, runScript, ... }@args:
            pkgs.runCommand name {
              inherit runScript;
              buildInputs = [ pkgs.bash ]; # Common dependency
            } ''
              echo "Running base job: ${name}"
              ${runScript}
              echo "Base job ${name} finished."
            '';
        };
      }
    );
}
