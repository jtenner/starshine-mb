# Fuzz Recipe Schema

Fuzz recipes are a small checked-in `key=value` schema for naming repeatable fuzz runs before the larger recipe catalog lands.

## Core Schema

The parser lives in [`src/fuzz/main.mbt`](../../../src/fuzz/main.mbt) as `parse_fuzz_recipe_text` and currently accepts one field per line:

- `name=<id>`: required recipe id.
- `suite=<suite>`: required fuzz suite, normalized to lowercase.
- `profile=<profile>`: optional profile, default `smoke`, normalized to lowercase.
- `seed=<int>`: optional decimal or hex seed, default `0`.
- `seed-count=<n>`: optional positive count, default `1`.
- `shard-count=<n>`: optional positive count, default `1`.
- `output=text|jsonl`: optional output mode, default `text`.

Blank lines and `#` comments are ignored. Unknown keys and malformed non-`key=value` lines are rejected so checked-in recipes fail fast.

## CLI Override Precedence

`parse_fuzz_cli_args_with_recipe` applies recipe values as defaults, then lets explicit CLI values win. This means a recipe can define a stable suite/profile/seed/shard/output baseline while callers override profile, seed count, output mode, or other ordinary flags for a run.

The `--recipe <name>` / `--recipe=<name>` flag is recognized by the parser layer and reserved for later checked-in recipe lookup. The core slice deliberately does not add the standard recipe catalog; that belongs to `[FUZ]1051B`.

## Evidence

- `src/fuzz/main_wbtest.mbt` covers schema parsing and CLI-over-recipe precedence.
- `moon test src/fuzz` passed for the initial core schema slice.
