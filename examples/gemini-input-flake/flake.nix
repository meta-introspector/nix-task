{
  description = "A flake that uses the gemini-caller-flake";

  inputs = {
    gemini-caller-flake.url = "path:../gemini-caller-flake"; # Reference the gemini-caller-flake
  };

  outputs = { self, gemini-caller-flake }: {
    # You can define a devShell or a package here that uses gemini-caller-flake's outputs
    devShells.default = gemini-caller-flake.devShells.default;
  };
}
