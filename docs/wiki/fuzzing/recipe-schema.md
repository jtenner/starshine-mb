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

Precedence is:

1. Parser defaults: suite `all`, profile `smoke`, generated seed when no recipe is supplied, seed count `1`, shard count `1`, and text output.
2. Checked-in recipe values from `--recipe <name>` or `--recipe=<name>`.
3. Positional suite/profile/seed arguments and explicit flags such as `--suite`, `--profile`, `--seed`, `--seed-count`, `--shard-count`, `--shard-index`, `--output`, `--jsonl`, and `--report-json`.

Examples:

- `moon run src/fuzz -- --recipe smoke --seed 0x1234 --seed-count 8` keeps the `smoke` recipe suite/profile/output defaults but overrides the seed and number of generated cases.
- `bun fuzz run --recipe pass-signoff --profile passes=merge-blocks --seed-count 100` keeps the pass-signoff suite and output mode while narrowing the profile and count for a focused pass lane.
- `moon run src/fuzz -- validate-valid stress --recipe validator-stress --seed 0x5eed` uses the explicit positional suite/profile and seed over the recipe defaults.
- `bun fuzz run --recipe default-ci --jsonl --report-json .tmp/fuzz-default-ci/result.json` keeps the all-suite CI sweep recipe while requesting JSONL/report output explicitly.

The `--recipe <name>` / `--recipe=<name>` flag is recognized by both the MoonBit parser layer and the `bun fuzz run` wrapper. Duplicate recipe flags are rejected, unknown recipe names abort in the MoonBit runner, and recipes still validate their own schema before CLI overrides apply. Use `moon run src/fuzz -- --list-recipes` to list the checked-in recipe ids from the same catalog used by `--recipe`. The checked-in catalog currently provides these recipe ids:

- `smoke`: short `validate-valid` smoke run.
- `default-smoke`: one-seed `all`-suite smoke sweep over every active default fuzz suite.
- `ci`: CI-oriented `cmd-harness` run with natural-small GenValid input and common pass clusters.
- `default-ci`: four-seed `all`-suite CI sweep over every active default fuzz suite, emitted as JSONL.
- `nightly`: broader `validate-valid-metamorphic` stress sweep.
- `pass-signoff`: pass-oriented `cmd-harness` run with Binaryen-oracle-portable GenValid input, each-pass coverage, idempotence checking, and shard defaults.
- `validator-stress`: `validate-valid` stress recipe. The `validate-valid` stress profile maps to the named validator-stress GenValid config in the validator runner.
- `parser-stress`: `wast-roundtrip` parser-stress/script recipe.
- `binaryen-oracle`: portable GenValid WAT validation roundtrip recipe for Binaryen-oracle-aligned inputs.
- `text-differential-smoke`: opt-in one-seed text differential smoke that exercises the local WAT parse/print/reparse/lower matrix and records unavailable external text adapters as skipped evidence.

## Evidence

- `src/fuzz/main_wbtest.mbt` covers required schema-version parsing, unsupported schema rejection, `=` inside profile values, standard catalog ids including default smoke/CI all-suite recipes, pass-signoff and validator-stress recipe intent, catalog-text parsing, CLI-over-recipe precedence, and the `--list-recipes` discovery command.
- `scripts/lib/fuzz-task.test.ts` covers `bun fuzz run --recipe` parsing and pass-through to the Moon fuzz runner.
- `moon test src/fuzz` passed for the recipe slices.
