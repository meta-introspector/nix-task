{ pkgs, inputs, ... }:

with pkgs;

let
  nixTaskDev = writeShellScriptBin "nix-task" ''
    (cd $REPO_ROOT/runner && yarn node build)
    node $REPO_ROOT/runner/nix-task "$@"
  '';
  execInTask = writeShellScriptBin "execInTask" ''
    curl -s --unix-socket $NIX_TASK_CONTROL_SOCKET \
      -X POST -H "Content-Type: text/plain" \
      --data "$(printf '%s\n' "$@" | jq -R . | jq -s .)" \
      http:/ctrl/evalInTask
  '';
in
mkShell {
  buildInputs = [
    nodejs
    yarn-berry
    nixTaskDev
    execInTask
  ];

  shellHook = ''
    # $PWD in shellHook is always the root of the repo
    export REPO_ROOT=$PWD

    export PKG_PATH_BASH="${pkgs.bashInteractive}"
    export PKG_PATH_COREUTILS="${pkgs.coreutils}"
    export PKG_PATH_JQ="${pkgs.jq}"
    export PKG_PATH_CURL="${pkgs.curl}"
    export PKG_PATH_NIX_LAZY="${pkgs.nix-lazy-trees}"
    export PKG_PATH_NODEJS="${pkgs.nodejs}"
    export PKG_PATH_UTIL_LINUX="${pkgs.util-linux}"
    export CONF_NIX_LIB_PATH="$REPO_ROOT/nix/lib"
  '';
}
