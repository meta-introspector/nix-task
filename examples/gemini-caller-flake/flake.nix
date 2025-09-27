{
  description = "A flake to call the run-gemini-cli task";

  inputs = {
    nix-task.url = "path:../.."; # Reference the parent nix-task flake
  };

  outputs = { self, nix-task }: {
    devShells.default = nix-task.devShells.default.overrideAttrs (oldAttrs: {
      shellHook = oldAttrs.shellHook + ''
        echo "Running gemini-cli task..."
        ${nix-task.tasks.run-gemini-cli.run}
      '';
    });
  };
}
