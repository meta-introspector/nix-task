
{ lib, pkgs }:

pkgs.callPackage ../lib/mkTask.nix {
  stableId = "solana-nix-trigger-interpreter";
  run = ''
    if [ -z "$SOLANA_EVENT_DATA" ]; then
      echo "Error: SOLANA_EVENT_DATA environment variable is not set." >&2
      exit 1
    fi

    echo "Received Solana event data: $SOLANA_EVENT_DATA"

    # Simulate parsing Solana event data to extract a Nix flake signature
    # For demonstration, let's assume SOLANA_EVENT_DATA contains a simple attribute path
    NIX_FLAKE_SIG=$(echo "$SOLANA_EVENT_DATA" | awk '{print $NF}') # Get the last word as the sig

    if [ -z "$NIX_FLAKE_SIG" ]; then
      echo "Error: Could not extract Nix flake signature from SOLANA_EVENT_DATA." >&2
      exit 1
    fi

    echo "Interpreted Nix flake signature: $NIX_FLAKE_SIG"
    echo "Simulating triggering of Nix task: nix run .#tasks.$NIX_FLAKE_SIG"

    # In a real scenario, the off-chain listener would execute:
    # ${pkgs.nix}/bin/nix run .#tasks.$NIX_FLAKE_SIG
    # or pass parameters to a generic task that then calls the specific one.

    echo "Nix task triggered successfully (simulated)."
  '';
  path = [ pkgs.bash pkgs.gnused pkgs.gawk ]; # Ensure bash, sed, and awk are available for parsing
  impureEnvPassthrough = [ "SOLANA_EVENT_DATA" ]; # Pass through the simulated Solana event data
}
