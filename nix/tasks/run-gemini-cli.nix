{ pkgs, lib, mkTask, gemini-cli }:

mkTask {
  stableId = "run-gemini-cli-interactive";
  impureBuild = true;
  run = ''
    ${pkgs.nix}/bin/nix run ${gemini-cli}#gemini -- --prompt "Test prompt"
  '';
  path = [ pkgs.nix ];
  impureEnvPassthrough = [ "HOME" "TERM" ]; # Pass through necessary environment variables
}