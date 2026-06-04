---
kind: raw-source
status: current
last_reviewed: 2026-06-04
sources:
  - ../../fuzzing/recipe-schema.md
  - ../../tooling/fuzz-runner.md
  - ../../tooling/validation-gates.md
  - ../../fuzzing/golden-seed-catalog.md
  - ../../../../src/fuzz/main.mbt
  - ../../../../src/fuzz/main_wbtest.mbt
  - ../../../../scripts/lib/fuzz-task.ts
  - ../../../../scripts/lib/fuzz-task.test.ts
  - ../../../../scripts/test/task-family-commands.ts
related:
  - ../../fuzzing/recipe-schema.md
  - ../../tooling/fuzz-runner.md
  - ../../tooling/validation-gates.md
  - ../../fuzzing/golden-seed-catalog.md
---

# Fuzz Recipe Schema Source Refresh (2026-06-04)

## Why this note exists

The living recipe page documented the first `starshine.fuzz.recipe.v1` key/value shape, but it was still too terse for developers choosing between default smoke/CI recipes, pass-signoff recipes, sharded runs, golden-seed smoke, and direct CLI overrides. This refresh grounds the durable page in the current MoonBit runner, Bun wrapper, and whitebox tests.

## Starshine local evidence

Checked on 2026-06-04:

- `src/fuzz/main.mbt` defines `FuzzRecipe`, `fuzz_recipe_schema_version()`, `parse_fuzz_recipe_text(...)`, `fuzz_standard_recipe_text_by_name(...)`, `fuzz_standard_recipe_names()`, `fuzz_standard_recipe_by_name(...)`, `parse_fuzz_cli_args(...)`, `parse_fuzz_cli_args_with_recipe(...)`, `build_fuzz_shard_queue(...)`, `build_fuzz_resume_shard_queue(...)`, `merge_fuzz_shard_results(...)`, `run_fuzz_golden_seed_smoke()`, and the `--list-recipes` command branch.
- The checked-in recipe catalog currently contains `smoke`, `default-smoke`, `ci`, `default-ci`, `nightly`, `pass-signoff`, `validator-stress`, `parser-stress`, `binaryen-oracle`, and `text-differential-smoke` in that discovery order.
- `parse_fuzz_recipe_text(...)` accepts only the `starshine.fuzz.recipe.v1` schema, lowercases key names plus suite/profile/output values, keeps `=` inside profile values, rejects unknown keys, requires `schema`, `name`, and `suite`, defaults profile to `smoke`, defaults seed to `0`, defaults `seed-count` and `shard-count` to `1`, and defaults output to `text`.
- `parse_fuzz_cli_args(...)` makes `--recipe <name>` and `--recipe=<name>` load only checked-in standard recipes; duplicate recipe flags abort, and unknown recipe names abort before ordinary suite execution.
- `parse_fuzz_cli_args_with_recipe(...)` deliberately ignores the recipe flag tokens after loading the recipe, then lets explicit positional suite/profile/seed and explicit flags override recipe defaults.
- `scripts/lib/fuzz-task.ts` is a strict wrapper: it parses `--recipe`, preserves whether suite/profile were explicitly supplied, forwards the recipe to `moon run src/fuzz -- --recipe <name>`, and appends explicit suite/profile overrides only when the wrapper saw them.
- `src/fuzz/main_wbtest.mbt` proves schema parsing, missing/unsupported schema errors, required checked-in recipe ids, `default-smoke` and `default-ci` defaults, `pass-signoff` intent, `validator-stress` sharding, `--list-recipes`, standard-recipe parseability, CLI-over-recipe precedence, and the golden-seed smoke coupling to the `smoke` recipe.
- `scripts/lib/fuzz-task.test.ts` proves that the Bun wrapper forwards recipe flags instead of collapsing them to wrapper defaults, and still forwards explicit overrides such as `--seed-count`.

## Durable conclusions

1. A fuzz recipe is a **named default bundle**, not a separate suite language. The schema stores suite/profile/seed/output/shard defaults, and the normal CLI parser still owns execution.
2. The parser is intentionally strict. Unknown keys and unsupported schemas should fail fast so checked-in recipes do not silently drift.
3. CLI values always win over recipe values. This lets recipes provide stable replay baselines while developers narrow or widen one run without editing the catalog.
4. Profiles may contain `=` because suite-specific modifiers such as `ci+gen-valid=binaryen-oracle-portable+passes=each-pass+check-idempotence` live in the profile string.
5. Sharding is part of the recipe contract. `seed-count` and `shard-count` become deterministic shard work items and output subdirectories through `build_fuzz_shard_queue(...)`; resumed queues skip shards only when the completed manifests name the required files.
6. Recipe ids are maintainer-facing public names. Renaming or repurposing one should update the MoonBit catalog, focused tests, living recipe page, runner workflow page, validation guidance when relevant, and the wiki index/log together.
7. No external source is needed for the v1 schema itself. The durable contract is Starshine-local and executable in repository code/tests; external fuzzing or reduction literature is relevant to corpus/reducer policy, not to this small key/value recipe format.
