
{ lib, pkgs }:

pkgs.callPackage ../lib/mkTask.nix {
  stableId = "run-gemini-cli-interactive";
  run = ''
    ${pkgs.nix}/bin/nix run path:/data/data/com.termux.nix/files/home/pick-up-nix2/vendor/nix/vendor/external/gemini-cli#gemini
  '';
  path = [ pkgs.nix ];
  impureEnvPassthrough = [ "HOME" "TERM" ]; # Pass through necessary environment variables
}
