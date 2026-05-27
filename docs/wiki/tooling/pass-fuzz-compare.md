---
kind: workflow
status: supported
last_reviewed: 2026-05-20
sources:
  - ../raw/binaryen/2026-05-20-pass-fuzz-compare-tool-sources.md
  - ../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../scripts/lib/fuzz-task.ts
  - ../../../scripts/test/pass-fuzz-compare-command.ts
  - ../../../scripts/test/task-family-commands.ts
  - ../../../src/fuzz/main.mbt
  - ../../../src/validate/gen_valid.mbt
related:
  - ./fuzz-runner.md
  - ./validation-gates.md
  - ../fuzzing/generator-coverage-ledger.md
  - ../validate/fuzz-hardening.md
  - ../validate/diagnostics-and-invalid-repro.md
  - ../binaryen/passes/tracker.md
  - ../binaryen/no-dwarf-default-optimize-path.md
---

# Pass Fuzz Compare Harness

## Overview

`bun fuzz compare-pass` is Starshine's pass-local Binaryen oracle lane. Use it when an optimizer pass changes semantics, scheduler placement, supported syntax, or pass registry wiring. It is deliberately separate from `bun fuzz run`: ordinary fuzz suites prove Starshine's generators and validators keep working, while compare-pass asks whether one or more Starshine pass flags produce the same normalized output as the corresponding Binaryen `wasm-opt` flags on the same input modules.

The 2026-05-20 source bridge is [`../raw/binaryen/2026-05-20-pass-fuzz-compare-tool-sources.md`](../raw/binaryen/2026-05-20-pass-fuzz-compare-tool-sources.md). It rechecked the current Binaryen, `wasm-tools`, `wasm-smith`, WebAssembly validation, and local script/test sources behind this workflow.

Beginner mental model:

1. generate or replay a `.wasm` input;
2. validate the input with `wasm-tools validate`;
3. run Starshine with the requested pass flags;
4. validate Starshine's output;
5. run Binaryen `wasm-opt` with matching pass flags;
6. canonicalize and print both outputs with Binaryen;
7. compare normalized WAT text;
8. persist enough artifacts to replay every non-match or command failure.

This is a **semantic-oracle workflow**, not a byte-for-byte wasm comparison. Raw binary or raw text drift is acceptable when the normalized comparison is green and the pass dossier explains any intentional representation differences.

## Command Shape

Common direct lane:

```text
bun fuzz compare-pass \
  --pass <canonical-pass>|--<pass-flag> [--pass ...] \
  --count 10000 --seed 0x5eed --out-dir .tmp/<run-name> \
  [--generator both|wasm-smith|gen-valid] \
  [--min-compared <n>] \
  [--max-failures 20] \
  [--keep-going-after-command-failures] \
  [--jobs 1|auto] \
  [--starshine-bin <native-cmd>]
```

Discovery and replay helpers:

```text
bun fuzz compare-pass --list-passes
bun fuzz compare-pass --list-failure-classes
bun fuzz compare-pass --pass <name> --replay-failures-from <dir>
bun fuzz compare-pass --pass <name> --replay-failures-from <dir> --failure-class <id>
bun fuzz compare-pass --pass <name> --replay-failures-from <dir> --case-index <n>
```

`bun scripts/pass-fuzz-compare.ts ...` is the same underlying implementation. `bun fuzz compare-pass` reaches it through [`scripts/lib/fuzz-task.ts`](../../../scripts/lib/fuzz-task.ts), which treats compare-pass as a sibling command rather than a `src/fuzz` suite.

## Input Generators

| Generator mode | What it does | Best use | Caveats |
| --- | --- | --- | --- |
| `both` | Alternates `wasm-smith` and Starshine `gen-valid` inputs. | Default broad signoff, especially for mature implemented passes. | Some cases may be tool/oracle failures rather than pass mismatches; classify them instead of hiding them. |
| `wasm-smith` | Calls `wasm-tools smith -o <input>` with deterministic seed bytes. | External generator diversity and Binaryen parser/tool gap discovery. | Still validate every generated input; generator/tool failures are not Starshine semantic mismatches. |
| `gen-valid` | Calls `moon run --target native --release src/fuzz -- --emit-gen-valid-batch ...`. | Starshine coverage-forced portable modules and focused regression lanes after FZG widening. | Uses the batch emitter's Binaryen-oracle-friendly config, not the ordinary natural `validate-valid` fuzz profile. |

The `gen-valid` path is why compare-pass depends on [`src/fuzz/main.mbt`](../../../src/fuzz/main.mbt) and [`src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt) even though compare-pass is not itself a MoonBit fuzz suite.

## Normalization And Comparison Flow

For each case, [`runPassFuzzCompare(...)`](../../../scripts/lib/pass-fuzz-compare-task.ts) follows this validation and normalization ladder:

1. **Input validation:** `wasm-tools validate input.wasm` must pass before the case can compare.
2. **Starshine run:** Starshine receives the requested pass flags and `--out <starshine.raw.wasm> <input.wasm>`.
3. **Starshine output validation:** `wasm-tools validate starshine.raw.wasm` must pass. A failure here is a Starshine validation failure, not a Binaryen semantic mismatch.
4. **Binaryen oracle run:** `wasm-opt input.wasm --all-features <binaryen-pass-flags> -o binaryen.raw.wasm` produces the oracle output.
5. **Canonicalization:** both raw outputs are passed through `wasm-opt --all-features --strip-debug -o <canonical.wasm>`.
6. **Text normalization:** both canonical outputs are printed with `wasm-opt --all-features --strip-debug -S -o <wat>`.
7. **Compare:** matching WAT increments `normalizedMatchCount`; drift records a `mismatch` case unless an explicit compare normalizer also proves equality.

That order matters. A pass can be locally safe but still differ in raw binary layout, custom-section order, name stripping, or textual representation. The harness intentionally removes those surfaces before comparing.

Optional compare normalizers are enabled with repeatable `--normalize <name>` flags. The first supported normalizer is `--normalize drop-consts`, which removes only conservative dropped constant-expression debris from the printed WAT before the fallback comparison. Exact WAT equality still increments `normalizedMatchCount`; equality reached only after these explicit compare normalizers increments `cleanupNormalizedMatchCount`, leaving remaining drift as `mismatch` cases. Use this for lanes like `dae-optimizing` where one side removes pure generated debris that the other side preserves; do not use it as a substitute for classifying new semantic or validation mismatches.

## Pass Flag Mapping

Passes may be supplied as canonical names (`--pass heap2local`) or direct flags (`--heap2local`). The local Starshine flags are preserved in `result.json` as `passFlags`; Binaryen flags are stored separately as `binaryenPassFlags` after alias normalization.

Current explicit aliases in [`scripts/lib/pass-fuzz-compare-task.ts`](../../../scripts/lib/pass-fuzz-compare-task.ts):

| Starshine-facing flag | Binaryen flag |
| --- | --- |
| `--dead-code-elimination` | `--dce` |
| `--global-struct-inference` | `--gsi` |
| `--redundant-set-elimination` | `--rse` |
| `--simplify-locals-no-structure` | `--simplify-locals-nostructure` |

Use `--list-passes` before starting a long lane; it is the script-owned list, not the docs-owned list.

## Result And Artifact Contract

Every run writes:

- `result.json` - aggregate counts, pass flags, Binaryen flags, generator counts, failure class counts, failure dirs, seed, requested count, and effective jobs.
- `cases.jsonl` - one case record per attempted case, sorted by case index after the run.
- `inputs/` - saved generator inputs for generated lanes.
- `failures/case-<index>-<generator>/` - copied per-case workdir files for generator failures, validation failures, command failures, and normalized mismatches.

Each failure directory includes:

- `failure.txt` - human-readable detail;
- `input.wasm` - replay input;
- `input.print.wat` when `wasm-tools print` succeeds;
- `failure-metadata.json` with `caseIndex`, `generator`, `detail`, copied artifact names, and relative replay input plus pass flags.

The generator ledger records this as `[FZG]029`; see [`../fuzzing/generator-coverage-ledger.md`](../fuzzing/generator-coverage-ledger.md).

## Failure Statuses And How To Report Them

| Status | Meaning | Report as |
| --- | --- | --- |
| `match` | Starshine and Binaryen normalized WAT matched. | Green comparison evidence. |
| `mismatch` | Both outputs were produced and normalized, but WAT differed. | Needs pass-owner classification: semantic-safe representation drift, size-only drift, risky/unknown, or true mismatch. |
| `validation-failure` | Starshine produced invalid wasm. | Correctness blocker for Starshine. |
| `generator-failure` | The input generator failed or produced bytes that failed independent validation. | Tool/generator issue unless inspection says otherwise. |
| `command-failure` | Starshine, Binaryen, or canonicalization command failed. | Classify by `failureClass`; replay before claiming pass semantics. |

Command failures may or may not count toward `--max-failures`. By default they do; `--keep-going-after-command-failures` records them without spending the failure budget. That mode is useful when a known tool class, such as a Binaryen parser gap, would otherwise prevent collecting enough comparable cases.

Known command-failure classes are intentionally concrete and replayable: `starshine-command-failed`, `starshine-invalid-limits`, `starshine-invalid-range-for-limits`, `binaryen-invalid-type-index`, `binaryen-invalid-tag-index`, `binaryen-rec-group-zero`, `binaryen-invalid-wasm-type-neg64`, `binaryen-initializer-expression-not-constant`, `binaryen-table-index-out-of-range`, `binaryen-bad-section-size`, and `binaryen-command-failed`.

## Concurrency Rules

`--jobs auto` uses host parallelism; `--jobs <n>` fixes worker count. Any effective worker count above `1` requires `--starshine-bin`.

Reason: without a prebuilt Starshine binary, the harness invokes Starshine through `moon run --target native --release src/cmd -- ...`. Parallel `moon run` calls can contend on `_build/.moon-lock`, so the harness refuses that shape. Build `src/cmd` once and pass its native binary path for parallel lanes.

## Signoff Guidance

For a direct pass signoff:

1. Run focused MoonBit tests for the pass and dispatcher/registry surface.
2. Run a small `--generator gen-valid --count <small>` smoke lane while iterating.
3. Run the repo-standard direct lane, usually `--count 10000 --seed 0x5eed`, with a stable `--out-dir`.
4. If command failures dominate, rerun with `--keep-going-after-command-failures` and use `--min-compared` so the run still proves enough comparable cases.
5. Classify any mismatch in the pass dossier with evidence. Do not call a mismatch semantically safe merely because both outputs validate.
6. Preserve the run directory locally and cite durable aggregate facts in the affected pass page, tracker, or research note.

For preset or neighborhood work, direct pass green is necessary but not sufficient. Also replay the ordered neighborhood or preset artifacts described by [`../binaryen/no-dwarf-default-optimize-path.md`](../binaryen/no-dwarf-default-optimize-path.md) and the affected pass dossier.

## Sources

- Tool/source bridge: [`../raw/binaryen/2026-05-20-pass-fuzz-compare-tool-sources.md`](../raw/binaryen/2026-05-20-pass-fuzz-compare-tool-sources.md)
- Harness implementation: [`../../../scripts/lib/pass-fuzz-compare-task.ts`](../../../scripts/lib/pass-fuzz-compare-task.ts)
- Wrapper split: [`../../../scripts/lib/fuzz-task.ts`](../../../scripts/lib/fuzz-task.ts)
- Command-shape tests: [`../../../scripts/test/pass-fuzz-compare-command.ts`](../../../scripts/test/pass-fuzz-compare-command.ts), [`../../../scripts/test/task-family-commands.ts`](../../../scripts/test/task-family-commands.ts)
- `gen-valid` batch emitter: [`../../../src/fuzz/main.mbt`](../../../src/fuzz/main.mbt), [`../../../src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt)
- Shared gates: [`validation-gates.md`](validation-gates.md), [`fuzz-runner.md`](fuzz-runner.md)
- Pass queues and oracle context: [`../binaryen/passes/tracker.md`](../binaryen/passes/tracker.md), [`../binaryen/no-dwarf-default-optimize-path.md`](../binaryen/no-dwarf-default-optimize-path.md)
