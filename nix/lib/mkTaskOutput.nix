{ pkgs, lib }:

with builtins;
with lib;

opts@{
  deps ? {},
  getOutput ? null,
}:
{
  __type = "taskOutput";
  inherit deps;
  inherit getOutput;
}
