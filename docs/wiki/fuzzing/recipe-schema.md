# Fuzz Recipe Schema

Fuzz recipes are a small checked-in `key=value` schema for naming repeatable fuzz runs. The standard catalog lives in `src/fuzz/main.mbt` as `fuzz_standard_recipe_names`, `fuzz_standard_recipe_text_by_name`, and `fuzz_standard_recipe_by_name` so tests and future CLI lookup share one source.

## Core Schema

The parser lives in [`src/fuzz/main.mbt`](../../../src/fuzz/main.mbt) as `parse_fuzz_recipe_text` and currently accepts one field per line:

- `schema=starshine.fuzz.recipe.v1`: required schema version. Unknown or missing schema versions are rejected before recipe defaults are applied.
- `name=<id>`: required recipe id.
- `suite=<suite>`: required fuzz suite, normalized to lowercase.
- `profile=<profile>`: optional profile, default `smoke`, normalized to lowercase. Values may contain `=` characters for suite-specific modifiers such as `passes=each-pass`.
- `seed=<int>`: optional decimal or hex seed, default `0`.
- `seed-count=<n>`: optional positive count, default `1`.
- `shard-count=<n>`: optional positive count, default `1`.
- `output=text|jsonl`: optional output mode, default `text`.

Blank lines and `#` comments are ignored. Unknown keys, unsupported schema versions, missing schema versions, and malformed non-`key=value` lines are rejected so checked-in recipes fail fast.

## CLI Override Precedence

`parse_fuzz_cli_args_with_recipe` applies recipe values as defaults, then lets explicit CLI values win. This means a recipe can define a stable suite/profile/seed/shard/output baseline while callers override profile, seed count, output mode, or other ordinary flags for a run.

The `--recipe <name>` / `--recipe=<name>` flag is recognized by the parser layer. The checked-in catalog currently provides these recipe ids:

- `smoke`: short `validate-valid` smoke run.
- `default-smoke`: one-seed `all`-suite smoke sweep over every active default fuzz suite.
- `ci`: CI-oriented `cmd-harness` run with natural-small GenValid input and common pass clusters.
- `default-ci`: four-seed `all`-suite CI sweep over every active default fuzz suite, emitted as JSONL.
- `nightly`: broader `validate-valid-metamorphic` stress sweep.
- `pass-signoff`: pass-oriented `cmd-harness` run with Binaryen-oracle-portable GenValid input, each-pass coverage, idempotence checking, and shard defaults.
- `validator-stress`: `validate-valid` stress recipe.
- `parser-stress`: `wast-roundtrip` parser-stress/script recipe.
- `binaryen-oracle`: portable GenValid WAT validation roundtrip recipe for Binaryen-oracle-aligned inputs.

## Evidence

- `src/fuzz/main_wbtest.mbt` covers required schema-version parsing, unsupported schema rejection, `=` inside profile values, standard catalog ids including default smoke/CI all-suite recipes, catalog-text parsing, and CLI-over-recipe precedence.
- `moon test src/fuzz` passed for the default smoke/CI recipe slice.
