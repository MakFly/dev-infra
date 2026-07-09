#!/usr/bin/env bats

# Unit tests for data/scripts/project-common.sh helpers.
# Helpers run in a subshell so `set -euo pipefail` from the sourced
# script does not leak into the bats runner.

COMMON="$BATS_TEST_DIRNAME/../data/scripts/project-common.sh"

helper() {
  bash -c "source '$COMMON'; $1"
}

@test "slugify lowercases and replaces separators with dashes" {
  run helper "slugify 'Feat/Payment API'"
  [ "$status" -eq 0 ]
  [ "$output" = "feat-payment-api" ]
}

@test "slugify trims leading and trailing dashes" {
  run helper "slugify '--Feat/X--'"
  [ "$status" -eq 0 ]
  [ "$output" = "feat-x" ]
}

@test "underscore_slug converts to underscores" {
  run helper "underscore_slug 'demo_feat/x'"
  [ "$status" -eq 0 ]
  [ "$output" = "demo_feat_x" ]
}

@test "stack_runtime_kind maps known stacks" {
  run helper "stack_runtime_kind symfony"
  [ "$output" = "php" ]
  run helper "stack_runtime_kind laravel"
  [ "$output" = "php" ]
  run helper "stack_runtime_kind nextjs"
  [ "$output" = "bun" ]
  run helper "stack_runtime_kind fastapi-ddd"
  [ "$output" = "python" ]
}

@test "stack_runtime_kind rejects unknown stack" {
  run helper "stack_runtime_kind rails"
  [ "$status" -ne 0 ]
}

@test "json_str wraps plain strings in quotes" {
  run helper "json_str 'plain-value'"
  [ "$output" = '"plain-value"' ]
}

@test "json_str escapes quotes and backslashes" {
  run helper 'json_str "a\"b\\c"'
  [ "$output" = '"a\"b\\c"' ]
}
