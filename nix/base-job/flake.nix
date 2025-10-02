{
  description = "Base flake for common job definitions and utilities";

  inputs = {
  inputs.nixpkgs.url = "github:meta-introspector/nixpkgs?ref=feature/CRQ-016-nixify";
    utils.url = "github:meta-introspector/flake-utils?ref=feature/CRQ-016-nixify";
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
