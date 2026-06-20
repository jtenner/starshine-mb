---
kind: workflow
status: supported
last_reviewed: 2026-06-20
sources:
  - ../raw/binaryen/2026-06-05-binaryen-bron-assertion-oracle-boundary.md
  - ../raw/binaryen/2026-05-20-pass-fuzz-compare-tool-sources.md
  - ../raw/research/0673-2026-05-26-dae-control-debris-normalizer.md
  - ../raw/fuzzing/2026-06-04-reduction-backends-source-refresh.md
  - ../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../scripts/lib/fuzz-task.ts
  - ../../../scripts/test/pass-fuzz-compare-command.ts
  - ../../../scripts/test/pass-fuzz-normalization-fixtures.ts
  - ../../../scripts/test/task-family-commands.ts
  - ../../../src/fuzz/main.mbt
  - ../../../src/validate/gen_valid.mbt
related:
  - ./fuzz-runner.md
  - ./validation-gates.md
  - ./external-validator-adapters.md
  - ../fuzzing/generator-coverage-ledger.md
  - ../fuzzing/reduction-backends.md
  - ../validate/fuzz-hardening.md
  - ../validate/diagnostics-and-invalid-repro.md
  - ../binaryen/passes/tracker.md
  - ../binaryen/no-dwarf-default-optimize-path.md
---

# Pass Fuzz Compare Harness

## Overview

`bun fuzz compare-pass` is Starshine's pass-local Binaryen oracle lane. Use it when an optimizer pass changes semantics, scheduler placement, supported syntax, or pass registry wiring. It is deliberately separate from `bun fuzz run`: ordinary fuzz suites prove Starshine's generators and validators keep working, while compare-pass asks whether one or more Starshine pass flags produce the same normalized output as the corresponding Binaryen `wasm-opt` flags on the same input modules.

The 2026-05-20 source bridge is [`../raw/binaryen/2026-05-20-pass-fuzz-compare-tool-sources.md`](../raw/binaryen/2026-05-20-pass-fuzz-compare-tool-sources.md). It rechecked the current Binaryen, `wasm-tools`, `wasm-smith`, WebAssembly validation, and local script/test sources behind this workflow. The 2026-06-05 Binaryen BrOn assertion bridge [`../raw/binaryen/2026-06-05-binaryen-bron-assertion-oracle-boundary.md`](../raw/binaryen/2026-06-05-binaryen-bron-assertion-oracle-boundary.md) adds a concrete current tool-failure family: older `wasm-opt` builds can assert while parsing malformed `br_on*` / descriptor-branch operands, while the current public `version_130` baseline is after the fix. The 2026-05-26 DAE control-debris research note extends this workflow with the opt-in `--normalize unreachable-control-debris` compare normalizer, which is intentionally separate from `--normalize drop-consts` so exact normalized matches and cleanup-normalized matches stay distinguishable.

Beginner mental model:

1. generate or replay a `.wasm` input;
2. reuse or populate the persistent input/oracle cache when enabled;
3. validate the input with `wasm-tools validate`;
4. run Starshine with the requested pass flags;
5. validate Starshine's output;
6. run or reuse Binaryen `wasm-opt` with matching pass flags;
7. canonicalize and print both outputs with Binaryen;
8. compare normalized WAT text;
9. persist enough artifacts to replay every non-match or command failure.

This is a **semantic-oracle workflow**, not a byte-for-byte wasm comparison. Raw binary or raw text drift is acceptable when the normalized comparison is green and the pass dossier explains any intentional representation differences. The normalization fixture matrix in [`../../../scripts/test/pass-fuzz-normalization-fixtures.ts`](../../../scripts/test/pass-fuzz-normalization-fixtures.ts) locks representative equality/inequality expectations for debug stripping, default locals, NaN payload text, transparent block wrappers, local-name stripping, custom sections, and section-order drift.

## Command Shape

Common direct lane. Build the native Starshine CLI once, then pass both the parallel worker flag and the prebuilt binary explicitly:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass \
  --pass <canonical-pass>|--<pass-flag> [--pass ...] \
  --count 10000 --seed 0x5eed --out-dir .tmp/<run-name> \
  --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe \
  [--wasm-smith] [--generator wasm-smith|gen-valid] \
  [--gen-valid-profile <profile>] \
  [--require-feature <feature>] [--exclude-feature <feature>] \
  [--gen-valid-metamorphic-transform <id>] \
  [--external-validator wasm-tools|binaryen|wabt] \
  [--runtime-execution off|node] \
  [--property none|idempotence|composition] \
  [--cache-dir .tmp/pass-fuzz-cache|--no-cache] \
  [--min-compared <n>] \
  [--max-failures 20] \
  [--keep-going-after-command-failures]
```

Discovery and replay helpers:

```text
bun fuzz compare-pass --list-passes
bun fuzz compare-pass --list-failure-classes
bun fuzz compare-pass --pass <name> --replay-failures-from <dir>
bun fuzz compare-pass --pass <name> --replay-failures-from <dir> --failure-status <status>
bun fuzz compare-pass --pass <name> --replay-failures-from <dir> --failure-class <id>
bun fuzz compare-pass --pass <name> --replay-failures-from <dir> --failure-status <status> --case-index <n>
```

`bun scripts/pass-fuzz-compare.ts ...` is the same underlying implementation. `bun fuzz compare-pass` reaches it through [`scripts/lib/fuzz-task.ts`](../../../scripts/lib/fuzz-task.ts), which treats compare-pass as a sibling command rather than a `src/fuzz` suite.

## Input Generators

Compare-pass lanes are intentionally split by generator. The default is a GenValid-only lane; run wasm-smith only by passing `--wasm-smith` for a separate external-generator lane. The legacy `--generator wasm-smith|gen-valid` spelling remains accepted, but the harness no longer has a mixed alternating generator mode.

| Generator mode | How to select it | What it does | Best use | Caveats |
| --- | --- | --- | --- | --- |
| `gen-valid` | Default, or `--generator gen-valid` | Calls `moon run --target native --release src/fuzz -- --emit-gen-valid-batch ... --manifest <out>/inputs/gen-valid/manifest.json`. | Starshine coverage-forced portable modules and focused regression lanes after FZG widening. | Uses the batch emitter's Binaryen-oracle-friendly config by default, not the ordinary natural `validate-valid` fuzz profile. |
| `wasm-smith` | `--wasm-smith`, or legacy `--generator wasm-smith` | Calls `wasm-tools smith -o <input>` with deterministic seed bytes. | External generator diversity and Binaryen parser/tool gap discovery. | Still validate every generated input; generator/tool failures are not Starshine semantic mismatches. |

`--gen-valid-profile <profile>` forwards a named GenValid profile to that batch command and records the requested profile in `result.json` as `genValidProfile`. Profiles may be singleton leaves or deterministic composites. For composite profiles, each selected manifest record keeps `config_label` as the requested composite label and adds `selected_profile` for the sampled singleton leaf; sampling is deterministic from the root seed and selected case index so the manifest row can be replayed exactly. `--require-feature <feature>` and `--exclude-feature <feature>` may repeat; compare-pass forwards them to the batch emitter and records them as `genValidRequiredFeatures` / `genValidExcludedFeatures`. `--gen-valid-metamorphic-transform <id>` may repeat; compare-pass forwards requested transformed-variant ids to the batch emitter and records them in `result.json` as `genValidMetamorphicTransforms`, while the GenValid manifest preserves the per-input `transform_id` for replay triage. Compare-pass also copies that manifest `transform_id` into each GenValid `cases.jsonl` record as `transformId`, counts compared GenValid cases by transform id in `result.json` as `genValidTransformCounts`, copies manifest `selected_profile` into GenValid case records as `genValidSelectedProfile`, counts sampled leaves in `genValidSelectedProfileCounts`, copies manifest `feature_facts` into GenValid case records as `genValidFeatureFacts`, preserves input effect/trap facts on case records where the input was scanned before the outcome, copies the transform id into persisted failure metadata, and includes it in transformed GenValid failure directory names as `case-<index>-gen-valid-transform-<id>` so replay triage can identify the active metamorphic family without reopening the manifest. Omit the profile for the default Binaryen-oracle portable batch config; use named profiles and feature filters when a fuzzer slice needs a specific surface such as `binaryen-oracle-portable`, `binaryen-oracle-relaxed-simd`, `simd-heavy`, `relaxed-simd`, or a pass-targeted recipe. The first pass-targeted recipes are `pass-cleanup` for portable local/control cleanup passes, `pass-dae` for direct-call and parameter-pruning surfaces, `pass-inlining` for dense direct-call and tail-call call graphs, `pass-memory` for memory/SIMD/atomics surfaces, `pass-gc-ref` for GC/reference/subtyping surfaces, and `pass-control` for typed branch-heavy control. Use `binaryen-oracle-relaxed-simd` for relaxed-SIMD input generation that should avoid imports, tables, memories, globals, tags, elems, datas, ref-types, atomics, memory64, and other currently nonportable oracle surfaces while still enabling `v128` and relaxed SIMD. Non-portable profiles may still be blocked by external tool support even when Starshine's own batch validator accepts them.

The `gen-valid` path is why compare-pass depends on [`src/fuzz/main.mbt`](../../../src/fuzz/main.mbt) and [`src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt) even though compare-pass is not itself a MoonBit fuzz suite. Runs that generate Starshine inputs now keep `inputs/gen-valid/manifest.json` beside the saved `.wasm` files; this file records the requested profile, filters, aggregate feature stats, per-input feature facts, and, for composite profiles, the per-input `selected_profile` for replay triage.

## Persistent Cache

Compare-pass uses a persistent cache by default at `.tmp/pass-fuzz-cache`; override it with `--cache-dir <dir>` or disable it with `--no-cache`. The cache never stores Starshine outputs because those are the system under test. It only caches deterministic inputs and Binaryen oracle work:

- `wasm-smith` inputs are stored under `wasm-smith/wasm-tools-<tool-hash>/seed-<seed>/wasmsmith-<seed>-<index>.wasm` only for explicit `--wasm-smith` lanes, so rerunning the same seed and case index skips `wasm-tools smith`.
- Binaryen oracle results are stored under `binaryen/schema-v1/wasm-opt-<tool-hash>/passes-<pass-hash>/input-<input-sha>/` with `binaryen.raw.wasm`, canonical `binaryen.wasm`, printed `binaryen.wat`, and a completion marker. The key includes the input bytes, Binaryen tool identity, and normalized Binaryen pass flags.
- Deterministic Binaryen/canonicalization command failures are cached as `failure.json` for the same input/tool/pass tuple, so repeated lanes do not spend time reproducing the same oracle failure before counting it as a command failure.

`result.json` records cache counters under `cache`: `wasmSmithHits`, `wasmSmithMisses`, `binaryenHits`, `binaryenMisses`, `binaryenFailureHits`, and `binaryenFailureMisses`. Cache hits still validate inputs and Starshine outputs and still canonicalize/print the fresh Starshine result before comparison.

## Normalization And Comparison Flow

For each case, [`runPassFuzzCompare(...)`](../../../scripts/lib/pass-fuzz-compare-task.ts) follows this validation and normalization ladder:

1. **Input validation:** `wasm-tools validate --features all input.wasm` must pass before the case can compare.
2. **Starshine run:** Starshine receives the requested pass flags and `--out <starshine.raw.wasm> <input.wasm>`.
3. **Starshine output validation:** `wasm-tools validate --features all starshine.raw.wasm` must pass. A failure here is a Starshine validation failure, not a Binaryen semantic mismatch. Optional `--external-validator` adapters can also run skip-clean output checks with `wasm-tools`, Binaryen, or WABT validators; missing external validator binaries are recorded as skipped in `result.json` instead of failing the run. Keep this pass-fuzz surface distinct from the command-harness binary differential adapter schema in [`external-validator-adapters.md`](external-validator-adapters.md).
4. **Binaryen oracle run or cache lookup:** `wasm-opt input.wasm --all-features <binaryen-pass-flags> -o binaryen.raw.wasm` produces the oracle output on a cache miss. On a cache hit, the harness restores cached Binaryen raw/canonical/text artifacts keyed by input bytes, Binaryen identity, and pass flags.
5. **Canonicalization:** both raw outputs are passed through `wasm-opt --all-features --strip-debug -o <canonical.wasm>` on cache miss; cached Binaryen canonical output is reused on Binaryen cache hit. Starshine canonicalization always reruns.
6. **Text normalization:** both canonical outputs are printed with `wasm-opt --all-features --strip-debug -S -o <wat>` on cache miss; cached Binaryen WAT is reused on Binaryen cache hit. Starshine text printing always reruns.
7. **Optional runtime execution:** `--runtime-execution node` tries a Node WebAssembly adapter with deterministic basic import stubs against both raw Starshine and Binaryen outputs, pairs same-named function exports, and invokes up to eight exported functions with a deterministic simple argument vector: each observed parameter slot receives numeric zero, capped at eight arguments. Equal results and equal traps count as checked runtime evidence; unsupported imports/instantiation are skipped evidence; observed result/trap disagreement increments the runtime failed count. Equal traps are not whole-program equivalence proof: use [`../validate/runtime-trap-semantics.md`](../validate/runtime-trap-semantics.md) for the trap-vocabulary and trap-order caveats. Runtime execution remains opt-in; `result.json` always carries a `runtimeExecutionMatrix` block, with `outcome: "not-run"` when runtime execution is disabled, and runtime-enabled mismatch repro manifests also carry the per-case matrix summary, outcome, and semantic-mismatch samples.
8. **Optional property checks:** `--property idempotence` reruns Starshine on `starshine.raw.wasm`, validates that second output, canonicalizes both Starshine outputs, and compares normalized WAT for `pass(pass(m)) == pass(m)`. `--property composition` requires at least two pass flags, runs those same flags one at a time through sequential Starshine invocations starting from the original input, validates each step, canonicalizes the final sequential output, and compares it with the combined Starshine invocation. Property failures increment `propertyFailureCount` and persist as `property-failure` cases, separate from Binaryen `mismatch` cases.
9. **Compare:** matching WAT increments `normalizedMatchCount`; if one or more explicit compare normalizers are enabled and only the cleaned outputs match, the harness increments `cleanupNormalizedMatchCount` and records a `cleanup-normalized-match` case; otherwise drift records a `mismatch` case.

That order matters. A pass can be locally safe but still differ in raw binary layout, custom-section order, name stripping, or textual representation. The harness intentionally removes those surfaces before comparing.

### Normalization Contract And Risk Boundary

The compare result is only as strong as the normalization layer below. Treat each step as a documented semantic filter, not as proof that every possible raw difference is harmless.

| Step | Current harness action | Intended equalized surface | Semantic risk boundary |
| --- | --- | --- | --- |
| Input validation | `wasm-tools validate --features all input.wasm` before either optimizer runs. | Rejects generator bytes that are not independently valid WebAssembly. | A failing input is a generator/tool issue; do not classify it as pass semantics. `wasm-tools` proposal support can still be narrower or broader than Starshine/Binaryen. |
| Starshine output validation | `wasm-tools validate --features all starshine.raw.wasm`. | Ensures Starshine did not produce invalid wasm before any canonical comparison. | Validation success is necessary but not sufficient for semantic parity; a later mismatch still needs agent classification. Validation failure is a Starshine correctness blocker. |
| Binaryen oracle execution | `wasm-opt input.wasm --all-features <binaryen-pass-flags>`. | Uses Binaryen as the pass-local oracle for the requested canonical pass flags. | Binaryen command/parser failures are tool/oracle failures until replayed and classified. Alias mismatches or unsupported pass surfaces can invalidate the comparison setup. |
| Binary canonicalization | `wasm-opt --all-features --strip-debug -o <canonical.wasm>` on both raw outputs. | Removes debug names/custom debug payloads and rewrites each output through the same Binaryen binary writer. | This intentionally ignores name/debug/custom-section placement and raw encoder layout. Do not use it to prove byte-for-byte, custom-section placement, or debug-info preservation parity. |
| Text printing | `wasm-opt --all-features --strip-debug -S -o <wat>` on both canonical wasm files. | Compares a stable text projection after Binaryen's own canonical binary normalization. | Text equality is the harness green condition. Text drift can still be representation-only, size-only, unknown, or a true semantic mismatch; inspect before labeling it. |
| Compare normalizers | `--normalize drop-consts` and `--normalize unreachable-control-debris` may be applied, in order, to the canonicalized outputs before comparison. | Covers documented DAE-style cleanup noise and other explicitly inspected debris families that should not count as raw mismatches. Equality reached only after these normalizers increments `cleanupNormalizedMatchCount` and records a `cleanup-normalized-match` status. | Keep the normalizers opt-in and pass-specific; do not use them to hide missing side effects, signature differences, trapping behavior, or other unexplained drift. |
| Debug/name stripping | `--strip-debug` is applied during canonicalization and printing. | Function/local/label names, name-section payloads, and debug metadata do not affect compare-pass matches. | Passes that intentionally preserve, delete, or repair names need separate focused tests; compare-pass does not sign off that surface. |
| Default-local and wrapper shape normalization | Binaryen's canonical printer may elide explicit default initializers, simplify harmless wrapper syntax, or choose a different printed expression shape. | Avoids failing on common canonical WAT presentation differences. | This is not a blanket semantic equivalence rule. Local declaration count, block result typing, and wrapper differences that affect validation, control flow, traps, exports, starts, tables, memories, or globals remain real risks; see [`../validate/runtime-trap-semantics.md`](../validate/runtime-trap-semantics.md) before treating equal traps or trap-shaped rewrites as semantic proof. |
| NaN and numeric text formatting | Numeric constants are compared after Binaryen's canonical binary-to-text projection. | Equalizes supported spelling/format choices for printed constants. | Payload-sensitive NaN behavior and trapping numeric operations still require pass-specific reasoning. Do not assume arbitrary floating-point rewrites are safe from normalized text alone. |
| Local/name stripping in reports | Failure artifacts keep raw and printed files, but the primary aggregate counts key off normalized WAT equality rather than raw names. | Keeps fuzz signoff focused on pass semantics rather than incidental local/debug naming. | If a pass promises user-visible name preservation or stable diagnostics, protect that with dedicated tests outside compare-pass. |
| Optional property normalization | Idempotence/composition checks canonicalize their Starshine outputs before comparing WAT. | Separates Starshine self-consistency failures from Binaryen oracle mismatches. | A property failure is evidence about the requested property only; report it separately from Binaryen semantic mismatch counts. |

Reporting rule: a normalized match is good pass-oracle evidence for the compared semantic surface, but it does not sign off raw bytes, debug/name preservation, custom-section placement, diagnostic locations, runtime import behavior, or unexercised proposals. A normalized mismatch is only a symptom; classify it with replay evidence, transform contracts, and pass-specific semantic reasoning.

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

- `result.json` - aggregate counts, pass flags, Binaryen flags, generator mode, compare normalizers, persistent cache directory/counters, requested GenValid profile, feature filters, requested metamorphic transform ids, compared GenValid transform counts, exact `normalizedMatchCount` and `cleanupNormalizedMatchCount` totals, requested external validators plus skip counts, requested runtime execution mode plus checked/unsupported/failed counts and persisted `runtimeExecutionMatrix` summary/outcome/semantic-mismatch samples, requested property mode plus idempotence/composition checked/match counts and property failures, relative GenValid manifest path when present, generator counts, failure class counts, failure dirs, seed, requested count, and effective jobs.
- `summary.json` - compact `starshine.fuzz-summary-report.v1` counters for `bun fuzz coverage-delta`, with suite `compare-pass`, profile `<pass>+<generator>`, required requested/compared case counters, optional generator/GenValid transform/property/input-effect/runtime counters, run-status counters including exact normalized-match versus cleanup-normalized-match separation, failure-class counters, and failure-artifact counts.
- `cases.jsonl` - one case record per attempted case, sorted by case index after the run; GenValid metamorphic cases include `transformId` when their manifest entry has `transform_id` and `genValidFeatureFacts` when their manifest entry has `feature_facts`; records also include input effect/trap facts once the input has been scanned.
- `inputs/` - saved generator inputs for generated lanes.
- `failures/case-<index>-<generator>/` or `failures/case-<index>-gen-valid-transform-<id>/` - copied per-case workdir files for generator failures, validation failures, command failures, and normalized mismatches.

Each failure directory includes:

- `failure.txt` - human-readable detail;
- `input.wasm` - replay input;
- `input.print.wat` when `wasm-tools print` succeeds;
- `failure-metadata.json` with `caseIndex`, `generator`, failure `status`, `detail`, copied artifact names, relative replay input plus pass flags, the per-input GenValid manifest entry when the failing case came from a manifest-backed `gen-valid` batch, and a `runtimeExecutionMatrix` block for runtime-enabled mismatches after the Node export matrix has run.

For fresh `gen-valid` normalized mismatches, pass-fuzz also attempts a byte-slice reduction after the mismatch has already been classified by the ordinary oracle. Successful reductions add `reduced-input.wasm`, `reduction.txt`, and a `reduction` block in `failure-metadata.json`; the reduction metadata includes original/final sizes, predicate-evaluation count, and `delete-byte-slice` steps. `input.wasm` remains the original replay input, so this artifact path does not change mismatch counting or replay semantics. The reducer contract, log schema, and predicate-preservation caveats are centralized in [`../fuzzing/reduction-backends.md`](../fuzzing/reduction-backends.md).

The generator ledger records this as `[FZG]029`; see [`../fuzzing/generator-coverage-ledger.md`](../fuzzing/generator-coverage-ledger.md).

## Failure Statuses And How To Report Them

| Status | Meaning | Report as |
| --- | --- | --- |
| `match` | Starshine and Binaryen normalized WAT matched. | Green comparison evidence. |
| `mismatch` | Both outputs were produced and normalized, but WAT differed. | Needs pass-owner classification: semantic-safe representation drift, size-only drift, risky/unknown, or true mismatch. |
| `validation-failure` | Starshine produced invalid wasm. | Correctness blocker for Starshine. |
| `generator-failure` | The input generator failed or produced bytes that failed independent validation. | Tool/generator issue unless inspection says otherwise. |
| `command-failure` | Starshine, Binaryen, or canonicalization command failed. | Classify by `failureClass`; replay before claiming pass semantics. |
| `property-failure` | An optional property check failed independently of the Binaryen oracle comparison. Today this means `pass(pass(m))` differed from `pass(m)` or the second Starshine output failed validation/canonicalization under `--property idempotence`, or a combined pass invocation differed from sequential single-pass invocations under `--property composition`. | Report as property-specific evidence, not as a Binaryen semantic mismatch. |

Replay defaults to historical command-failure behavior for backward compatibility. Use `--failure-status mismatch`, `--failure-status validation-failure`, `--failure-status generator-failure`, or `--failure-status property-failure` to replay other persisted failure kinds; combine with `--case-index <n>` to pick one saved case. `--failure-class <id>` is only meaningful for `command-failure` records.

Command failures may or may not count toward `--max-failures`. By default they do; `--keep-going-after-command-failures` records them without spending the failure budget. That mode is useful when a known tool class, such as a Binaryen parser gap, would otherwise prevent collecting enough comparable cases.

Known command-failure classes are intentionally concrete and replayable: `starshine-command-failed`, `starshine-invalid-limits`, `starshine-invalid-range-for-limits`, `binaryen-invalid-type-index`, `binaryen-invalid-tag-index`, `binaryen-rec-group-zero`, `binaryen-invalid-wasm-type-neg64`, `binaryen-initializer-expression-not-constant`, `binaryen-table-index-out-of-range`, `binaryen-bad-section-size`, and `binaryen-command-failed`.

When `binaryen-command-failed` contains a BrOn-family assertion such as `Type::getHeapType()` / `isRef()` while parsing `br_on*` or descriptor-branch operands, use the 2026-06-05 Binaryen bridge before assigning blame. On older installed Binaryen builds this is a known upstream tool/oracle failure family fixed by commit `1251efb`; preserve the exact command/build and replay on a fixed build before claiming Starshine semantic mismatch.

## Concurrency Rules

`--jobs auto` uses host parallelism; `--jobs <n>` fixes worker count. Documentation and signoff commands should include `--jobs auto` and `--starshine-bin target/native/release/build/cmd/cmd.exe` together explicitly. Any effective worker count above `1` requires `--starshine-bin`.

Reason: without a prebuilt Starshine binary, the harness invokes Starshine through `moon run --target native --release src/cmd -- ...`. Parallel `moon run` calls can contend on `_build/.moon-lock`, so the harness refuses that shape. Build `src/cmd` once and pass its native binary path for parallel lanes. The implementation also treats omitted `--jobs` with `--starshine-bin` as auto, but documented commands should keep both flags visible so copied signoff lanes are unambiguous.

## Signoff Guidance

For a direct pass signoff:

1. Run focused MoonBit tests for the pass and dispatcher/registry surface.
2. Run a small default GenValid `--count <small>` smoke lane while iterating.
3. Build `src/cmd` once with `moon build --target native --release src/cmd`.
4. Run the repo-standard direct lane, usually `--count 10000 --seed 0x5eed`, with a stable `--out-dir`, explicit `--jobs auto`, and explicit `--starshine-bin target/native/release/build/cmd/cmd.exe`.
5. If command failures dominate, rerun with `--keep-going-after-command-failures` and use `--min-compared` so the run still proves enough comparable cases.
6. Classify any mismatch in the pass dossier with evidence. Do not call a mismatch semantically safe merely because both outputs validate.
7. For DAE / generator-debris lanes, include `--normalize drop-consts --normalize unreachable-control-debris` so cleanup-normalized matches are counted separately from exact normalized matches.
8. Preserve the run directory locally and cite durable aggregate facts in the affected pass page, tracker, or research note.

For preset or neighborhood work, direct pass green is necessary but not sufficient. Also replay the ordered neighborhood or preset artifacts described by [`../binaryen/no-dwarf-default-optimize-path.md`](../binaryen/no-dwarf-default-optimize-path.md) and the affected pass dossier.

## Sources

- Binaryen BrOn assertion / oracle boundary bridge: [`../raw/binaryen/2026-06-05-binaryen-bron-assertion-oracle-boundary.md`](../raw/binaryen/2026-06-05-binaryen-bron-assertion-oracle-boundary.md)
- Tool/source bridge: [`../raw/binaryen/2026-05-20-pass-fuzz-compare-tool-sources.md`](../raw/binaryen/2026-05-20-pass-fuzz-compare-tool-sources.md)
- Harness implementation: [`../../../scripts/lib/pass-fuzz-compare-task.ts`](../../../scripts/lib/pass-fuzz-compare-task.ts)
- Wrapper split: [`../../../scripts/lib/fuzz-task.ts`](../../../scripts/lib/fuzz-task.ts)
- Command-shape tests: [`../../../scripts/test/pass-fuzz-compare-command.ts`](../../../scripts/test/pass-fuzz-compare-command.ts), [`../../../scripts/test/task-family-commands.ts`](../../../scripts/test/task-family-commands.ts)
- `gen-valid` batch emitter: [`../../../src/fuzz/main.mbt`](../../../src/fuzz/main.mbt), [`../../../src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt)
- Shared gates: [`validation-gates.md`](validation-gates.md), [`fuzz-runner.md`](fuzz-runner.md)
- Pass queues and oracle context: [`../binaryen/passes/tracker.md`](../binaryen/passes/tracker.md), [`../binaryen/no-dwarf-default-optimize-path.md`](../binaryen/no-dwarf-default-optimize-path.md)
