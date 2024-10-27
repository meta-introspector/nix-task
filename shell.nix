{ pkgs, inputs, ... }:

with pkgs;

let
  nixTaskDev = writeShellScriptBin "nix-task" ''
    (cd $REPO_ROOT/runner && yarn node build)
    node $REPO_ROOT/runner/nix-task "$@"
  '';
in
mkShell {
  buildInputs = [
    nodejs
    yarn-berry
    nixTaskDev
  ];

  shellHook = ''
    # $PWD in shellHook is always the root of the repo
    export REPO_ROOT=$PWD

    export PKG_PATH_BASH="${pkgs.bashInteractive}"
    export PKG_PATH_COREUTILS="${pkgs.coreutils}"
    export PKG_PATH_JQ="${pkgs.jq}"
    export PKG_PATH_CURL="${pkgs.curl}"
    export PKG_PATH_NIX_LAZY="${inputs.nix-lazy-trees.packages.${system}.nix}"
    export PKG_PATH_NODEJS="${pkgs.nodejs}"
    export PKG_PATH_UTIL_LINUX="${pkgs.util-linux}"
    export CONF_NIX_LIB_PATH="$REPO_ROOT/nix/lib"
  '';
}
