#!/usr/bin/env bash

set -e

# system="$(nix eval --impure --json --expr builtins.currentSystem | jq -r)"

pushd examples/nixMathHomework

# nix-task run -g .#

nix-task run .#

popd

nix-task run ./examples/nixMathHomework#

nix-task run --reverse --custom destroy --only test_calculate -g ./examples/nixMathHomework#
nix-task run --reverse --custom destroy --only test_calculate ./examples/nixMathHomework#
