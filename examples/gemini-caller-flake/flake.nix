{
  description = "A flake to call the run-gemini-cli task";

  inputs = {
    nix-task.url = "github:meta-introspector/time-2025/feature/foaf?dir=09/26/jobs/vendor/nix-task";
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
