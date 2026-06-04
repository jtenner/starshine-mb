---
kind: concept
status: supported
last_reviewed: 2026-06-04
sources:
  - ../raw/fuzzing/2026-06-04-fuzz-recipe-schema-source-refresh.md
  - ../../../src/fuzz/main.mbt
  - ../../../src/fuzz/main_wbtest.mbt
  - ../../../scripts/lib/fuzz-task.ts
  - ../../../scripts/lib/fuzz-task.test.ts
  - ../../../scripts/test/task-family-commands.ts
related:
  - ../tooling/fuzz-runner.md
  - ../tooling/validation-gates.md
  - ../tooling/pass-fuzz-compare.md
  - ../tooling/external-validator-adapters.md
  - golden-seed-catalog.md
  - reduction-backends.md
  - ../validate/fuzz-hardening.md
  - ../validate/diagnostics-and-invalid-repro.md
---

# Fuzz Recipe Schema

## Overview

Fuzz recipes are Starshine's small checked-in `key=value` schema for **repeatable fuzz-run defaults**. A recipe names a suite, profile, seed, sweep size, shard count, and output mode so developers can say “run the standard CI fuzz shape” or “start from the pass-signoff shape” without copying a long command from a chat log.

The current schema id is `starshine.fuzz.recipe.v1`. The executable source of truth lives in [`src/fuzz/main.mbt`](../../../src/fuzz/main.mbt) as `FuzzRecipe`, `fuzz_recipe_schema_version()`, `parse_fuzz_recipe_text(...)`, `fuzz_standard_recipe_text_by_name(...)`, `fuzz_standard_recipe_names()`, `fuzz_standard_recipe_by_name(...)`, `parse_fuzz_cli_args(...)`, and `parse_fuzz_cli_args_with_recipe(...)`. The 2026-06-04 source bridge is [`../raw/fuzzing/2026-06-04-fuzz-recipe-schema-source-refresh.md`](../raw/fuzzing/2026-06-04-fuzz-recipe-schema-source-refresh.md).

A recipe is **not** a new runner or a replacement for suite-specific profile parsing. It is a named default bundle. The normal MoonBit fuzz runner and Bun wrapper still own command execution, output files, replay manifests, external validators, and pass-comparison lanes; route those details through [`../tooling/fuzz-runner.md`](../tooling/fuzz-runner.md), [`../tooling/validation-gates.md`](../tooling/validation-gates.md), and [`../tooling/pass-fuzz-compare.md`](../tooling/pass-fuzz-compare.md).

## Beginner Mental Model

Think of a recipe like a saved command prefix:

```text
recipe default-ci
  => suite=all
  => profile=ci
  => seed=0x5eed
  => seed-count=4
  => shard-count=1
  => output=jsonl
```

Then the user can still override the parts they want for one run:

```text
moon run src/fuzz -- --recipe default-ci --seed 0x1234 --seed-count 8
```

That command keeps `default-ci`'s suite/profile/output defaults, but uses a different seed and sweep length. The important invariant is: **parser defaults < recipe defaults < explicit CLI values**.

## Core Schema

The parser accepts one field per line. Blank lines and `#` comments are ignored. Unknown keys, malformed non-`key=value` lines, missing required fields, and unsupported schema versions are rejected so checked-in recipes fail fast.

| Key | Required? | Default | Semantics |
| --- | --- | --- | --- |
| `schema` | Yes | none | Must be exactly `starshine.fuzz.recipe.v1`. |
| `name` | Yes | none | Stable recipe id used by `--recipe <name>` and `--list-recipes`. |
| `suite` | Yes | none | Fuzz suite id, lowercased by the parser; `all` is allowed for all-suite sweeps. |
| `profile` | No | `smoke` | Suite profile string, lowercased by the parser. It may contain `=` for modifiers such as `ci+gen-valid=binaryen-oracle-portable+passes=each-pass`. |
| `seed` | No | `0` | Decimal or `0x...` signed seed used as the deterministic root when the recipe is loaded. |
| `seed-count` | No | `1` | Positive sweep length. The runner derives deterministic seed ordinals from this value. |
| `shard-count` | No | `1` | Positive number of deterministic shard work items for queue/resume tooling. |
| `output` | No | `text` | `text` or `jsonl`. |

Example custom recipe text accepted by `parse_fuzz_recipe_text(...)`:

```text
schema=starshine.fuzz.recipe.v1
name=local-pass-smoke
suite=cmd-harness
profile=ci+gen-valid=binaryen-oracle-portable+passes=each-pass+check-idempotence
seed=0x5eed
seed-count=8
shard-count=4
output=jsonl
```

## CLI Override Precedence

`parse_fuzz_cli_args(...)` first discovers at most one `--recipe <name>` or `--recipe=<name>`. If present, the name must resolve through the checked-in standard catalog. Duplicate recipe flags and unknown recipe names abort before suite execution.

`parse_fuzz_cli_args_with_recipe(...)` then applies precedence in this order:

1. **Parser defaults:** suite `all`, profile `smoke`, generated time-derived seed when no recipe exists, seed count `1`, shard count `1`, text output.
2. **Recipe defaults:** fields from the checked-in recipe selected by `--recipe`.
3. **Explicit CLI values:** positional suite/profile/seed and flags such as `--suite`, `--profile`, `--seed`, `--seed-count`, `--shard-count`, `--shard-index`, `--output`, `--jsonl`, and `--report-json`.

Common override commands:

```text
moon run src/fuzz -- --recipe smoke --seed 0x1234 --seed-count 8
bun fuzz run --recipe pass-signoff --profile ci+gen-valid=binaryen-oracle-portable+passes=cleanup --seed-count 16
moon run src/fuzz -- validate-valid stress --recipe validator-stress --seed 0x5eed
bun fuzz run --recipe default-ci --jsonl --report-json .tmp/fuzz-default-ci/result.json
moon run src/fuzz -- --list-recipes
```

The Bun wrapper in [`scripts/lib/fuzz-task.ts`](../../../scripts/lib/fuzz-task.ts) preserves this model. It forwards the recipe to `moon run src/fuzz -- --recipe <name>` and appends suite/profile positional overrides only if the wrapper saw an explicit suite/profile value; wrapper defaults must not erase recipe defaults.

## Standard Recipe Catalog

The checked-in catalog is intentionally small and discoverable through `moon run src/fuzz -- --list-recipes`.

| Recipe | Suite | Profile | Seed | Sweep / shards | Output | Intended use |
| --- | --- | --- | --- | --- | --- | --- |
| `smoke` | `validate-valid` | `smoke` | `0x5eed` | `1 / 1` | `text` | Fast valid-module smoke and the first half of `--golden-seed-smoke`. |
| `default-smoke` | `all` | `smoke` | `0x5eed` | `1 / 1` | `text` | One-seed smoke sweep across every active default suite. |
| `ci` | `cmd-harness` | `ci+gen-valid=natural-small+passes=common-clusters` | `0x5eed` | `4 / 1` | `jsonl` | Affordable command-harness CI path with natural-small inputs and common pass clusters. |
| `default-ci` | `all` | `ci` | `0x5eed` | `4 / 1` | `jsonl` | All-suite CI sweep. |
| `nightly` | `validate-valid-metamorphic` | `stress` | `0x1eed` | `32 / 8` | `jsonl` | Broader metamorphic validator stress lane, designed for shard queues. |
| `pass-signoff` | `cmd-harness` | `ci+gen-valid=binaryen-oracle-portable+passes=each-pass+check-idempotence` | `0x5eed` | `8 / 4` | `jsonl` | Pass-oriented command-harness smoke with portable Binaryen-oracle input and idempotence checking. This complements, but does not replace, pass-specific compare-pass signoff. |
| `validator-stress` | `validate-valid` | `stress` | `0x10d69` | `16 / 4` | `jsonl` | Validator stress recipe using the suite's stress generator configuration. |
| `parser-stress` | `wast-roundtrip` | `stress+parser-stress+scripts` | `0x5eed` | `16 / 4` | `jsonl` | WAST parser/script stress lane. |
| `binaryen-oracle` | `gen-valid-wat-validate-roundtrip` | `binaryen-oracle-portable` | `0x5eed` | `8 / 4` | `jsonl` | Portable GenValid WAT validation roundtrip aligned with Binaryen-oracle inputs. |
| `text-differential-smoke` | `text-differential` | `smoke` | `0x1045a7` | `1 / 1` | `jsonl` | Opt-in local WAT parse/print/reparse/lower matrix; unavailable external text adapters are skipped evidence. |

## Shards, Resume, And Output Directories

Recipe `seed-count` and `shard-count` values are not just documentation. `build_fuzz_shard_queue(...)` turns a `FuzzRecipe` into deterministic `FuzzShardWorkItem` rows named:

```text
<recipe>-shard-NNN-of-MMM
```

When an output root is supplied, each shard receives a separate directory:

```text
<out-root>/shard-NNN-of-MMM
```

That keeps parallel workers from writing the same artifact paths. `build_fuzz_resume_shard_queue(...)` applies the same naming contract but skips shards whose completed manifests already name the required result and cases artifacts. `merge_fuzz_shard_results(...)` keeps merged summaries deterministic by seed index, suite, profile, and shard order. Use [`../tooling/fuzz-runner.md`](../tooling/fuzz-runner.md) for the full output-file and replay-manifest contract.

## Relationship To Golden Seeds And Corpus Policy

Recipes answer “which run shape should I use?” Golden seeds answer “which small deterministic seed should represent a specific smoke surface?” Corpus entries answer “which generated or reduced artifact should remain replayable over time?”

- Use this page for recipe fields, defaults, and standard ids.
- Use [`golden-seed-catalog.md`](golden-seed-catalog.md) for `starshine.fuzz.golden-seed-catalog.v1` entries and `--golden-seed-smoke` maintenance.
- Use [`../tooling/fuzz-corpus-policy.md`](../tooling/fuzz-corpus-policy.md) for promoted/quarantined artifacts, replay expectations, and corpus-entry metadata.
- Use [`reduction-backends.md`](reduction-backends.md) when a failure should be minimized while preserving an interestingness predicate.

## Maintenance Checklist

When adding, renaming, or materially changing a standard recipe:

1. Update `fuzz_standard_recipe_text_by_name(...)` and `fuzz_standard_recipe_names()` in [`src/fuzz/main.mbt`](../../../src/fuzz/main.mbt).
2. Keep recipe ids stable unless the old purpose is retired; changing an existing id's purpose should be treated like a compatibility-affecting workflow change.
3. Update whitebox coverage in [`src/fuzz/main_wbtest.mbt`](../../../src/fuzz/main_wbtest.mbt) for catalog membership, parseability, suite/profile intent, shard/seed defaults, `--list-recipes`, and CLI-over-recipe precedence.
4. Update Bun wrapper tests in [`scripts/lib/fuzz-task.test.ts`](../../../scripts/lib/fuzz-task.test.ts) if wrapper forwarding changes.
5. Update this page, [`../tooling/fuzz-runner.md`](../tooling/fuzz-runner.md) if command behavior changes, and [`../tooling/validation-gates.md`](../tooling/validation-gates.md) if a recipe becomes part of a release or CI gate.
6. Update [`docs/wiki/index.md`](../index.md) and [`docs/wiki/log.md`](../log.md) for durable documentation changes.

Docs-only recipe-page updates need link/source review and `git diff`; no Moon command is required unless recipe source, tests, wrappers, or executable counters changed.

## Common Mistakes

- **Treating recipes as immutable commands.** They are defaults; explicit CLI values intentionally win.
- **Forgetting `=` inside profiles.** The parser must preserve suite-specific profile modifiers such as `gen-valid=...` and `passes=...`.
- **Using `pass-signoff` as full pass parity evidence.** It is a command-harness recipe. Mutating pass signoff still needs focused pass tests and the Binaryen compare-pass lane described in [`../tooling/pass-fuzz-compare.md`](../tooling/pass-fuzz-compare.md).
- **Adding bulk or one-off bug seeds as recipes.** One-off failures belong in focused tests, raw/research notes, reduced artifacts, or corpus metadata; recipes should stay small, named, and workflow-oriented.
- **Letting wrapper defaults erase recipe defaults.** The wrapper tracks whether suite/profile were explicit so recipe defaults remain meaningful.
- **Changing recipe ids without index/log updates.** Recipe names are discoverable workflow vocabulary and should not drift silently.

## Sources

- Current source bridge: [`../raw/fuzzing/2026-06-04-fuzz-recipe-schema-source-refresh.md`](../raw/fuzzing/2026-06-04-fuzz-recipe-schema-source-refresh.md)
- MoonBit runner and tests: [`../../../src/fuzz/main.mbt`](../../../src/fuzz/main.mbt), [`../../../src/fuzz/main_wbtest.mbt`](../../../src/fuzz/main_wbtest.mbt)
- Bun wrapper and tests: [`../../../scripts/lib/fuzz-task.ts`](../../../scripts/lib/fuzz-task.ts), [`../../../scripts/lib/fuzz-task.test.ts`](../../../scripts/lib/fuzz-task.test.ts), [`../../../scripts/test/task-family-commands.ts`](../../../scripts/test/task-family-commands.ts)
- Related workflow pages: [`../tooling/fuzz-runner.md`](../tooling/fuzz-runner.md), [`../tooling/validation-gates.md`](../tooling/validation-gates.md), [`../tooling/pass-fuzz-compare.md`](../tooling/pass-fuzz-compare.md), [`golden-seed-catalog.md`](golden-seed-catalog.md), [`reduction-backends.md`](reduction-backends.md), [`../tooling/fuzz-corpus-policy.md`](../tooling/fuzz-corpus-policy.md)
