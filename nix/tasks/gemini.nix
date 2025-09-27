
{ lib, pkgs, gemini-cli }:

pkgs.callPackage ../lib/mkTask.nix {
  stableId = "gemini-cli-interactive";
  run = ''
    ${pkgs.nix}/bin/nix run ${gemini-cli}#gemini
  '';
  path = [ pkgs.nix ];
  impureEnvPassthrough = [ "HOME" "TERM" ]; # Pass through necessary environment variables
}
