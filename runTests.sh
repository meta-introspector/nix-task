#!/usr/bin/env bash

set -e

# system="$(nix eval --impure --json --expr builtins.currentSystem | jq -r)"

pushd examples/nixMathHomework

# nix-task run -g .#

nix-task run .#

popd

rm -rf .nix-task || true

nix-task run ./examples/nixMathHomework#

nix-task run --only ./examples/nixMathHomework#example.calculate.add_3_and_7
nix-task run --reverse --custom destroy --only-tags test_calculate -g ./examples/nixMathHomework#
nix-task run --reverse --custom destroy --only-tags test_calculate ./examples/nixMathHomework#
nix-task run --only ./examples/nixMathHomework#example.execTest

# clear output directory and try running in reverse again, previous outputs should have "fetchOutput" called
rm -rf .nix-task || true
nix-task run --reverse --custom destroy --only-tags test_calculate ./examples/nixMathHomework#example.calculate

# clear output directory and try filtering by tag where dependency outputs need to be fetched
rm -rf .nix-task || true
nix-task run --only-tags test_result ./examples/nixMathHomework#
