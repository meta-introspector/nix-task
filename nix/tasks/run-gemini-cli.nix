
{ lib, pkgs, gemini-cli }:

pkgs.callPackage ../lib/mkTask.nix {
  stableId = "run-gemini-cli-interactive";
  run = ''
    ${pkgs.nix}/bin/nix run ${gemini-cli}#gemini -- --prompt ""
  '';
  path = [ pkgs.nix ];
  impureEnvPassthrough = [ "HOME" "TERM" ]; # Pass through necessary environment variables
}
