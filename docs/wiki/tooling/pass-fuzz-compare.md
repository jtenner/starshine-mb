---
kind: workflow
status: supported
last_reviewed: 2026-09-16
sources:
  - ../binaryen/release-horizon-and-oracles.md
  - https://github.com/WebAssembly/binaryen
  - https://github.com/bytecodealliance/wasm-tools
  - https://webassembly.github.io/spec/core/valid/
  - ../binaryen/passes/dae-optimizing/index.md
  - ../fuzzing/reduction-backends.md
  - ../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../scripts/lib/fuzz-task.ts
  - ../../../scripts/test/pass-fuzz-compare-command.ts
  - ../../../scripts/test/pass-fuzz-normalization-fixtures.ts
  - ../../../scripts/test/task-family-commands.ts
  - ../../../src/fuzz/main.mbt
  - ../../../src/validate/gen_valid.mbt
  - ../../../AGENTS.md
  - ../../README.md
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

> **Comparison baseline — September 10, 2026:** new comparisons use [Binaryen 132](../binaryen/release-horizon-and-oracles.md). This supersedes older current/latest-baseline wording below. Recorded v131 sources, commands, artifacts and results retain their historical version and do not establish v132 signoff.

## Overview

`bun fuzz compare-pass` is Starshine's pass-local optimizer correctness and Binaryen oracle lane. Use it when an optimizer pass changes semantics, scheduler placement, supported syntax, or pass registry wiring. It is deliberately separate from `bun fuzz run`: ordinary fuzz suites prove Starshine's generators and validators keep working, while compare-pass can now prove independent Starshine properties before asking whether one or more Starshine pass flags produce the same normalized output as Binaryen.

The oracle ladder is explicit and non-interchangeable: input validation; optional `semantic:self` execution of original input versus Starshine output; Starshine internal/external output validity; codec stability; fresh-run optimizer determinism; optimizer idempotence when requested; then `semantic:binaryen` runtime smoke and normalized Binaryen comparison. A green self-semantic result does not excuse unexplained Binaryen drift, and a normalized Binaryen match does not replace before/after execution.

This workflow is grounded in the Binaryen and `wasm-tools` projects, the WebAssembly validation specification, and the local script/test sources listed below. `wasm-smith` generated inputs remain independently validated before comparison. The Binaryen BrOn oracle boundary in [`../binaryen/release-horizon-and-oracles.md`](../binaryen/release-horizon-and-oracles.md) adds a concrete tool-failure family: older `wasm-opt` builds can assert while parsing malformed `br_on*` / descriptor-branch operands, while both the former `version_131` baseline and current `version_132` target include the fix. On 2026-07-18 bare `wasm-opt` resolved to TinyGo's Binaryen v116, so release-baseline evidence must pass an explicit verified official binary with `--wasm-opt-bin`. The 2026-05-26 DAE control-debris research note extends this workflow with the opt-in `--normalize unreachable-control-debris` compare normalizer, which is intentionally separate from `--normalize drop-consts` so exact normalized matches and cleanup-normalized matches stay distinguishable.

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

This is a **semantic-oracle workflow**, not a byte-for-byte wasm comparison. A normalized match is evidence for the compared surface, not proof of every observable behavior or of raw-byte/custom-section parity. Ordinary passes also exclude name/debug parity; a lane containing `strip-debug` preserves names through the comparison projection so that the pass cannot receive a false match merely because the harness stripped its output again. A normalized mismatch is a harness **status**, not a verdict: a maintainer must classify it using the evidence rules below. The normalization fixture matrix in [`../../../scripts/test/pass-fuzz-normalization-fixtures.ts`](../../../scripts/test/pass-fuzz-normalization-fixtures.ts) locks representative equality/inequality expectations for debug stripping, default locals, NaN payload text, transparent block wrappers, local-name stripping, custom sections, and section-order drift.

## Command Shape

Common direct lane. Build the native Starshine CLI once, then pass both the parallel worker flag and the prebuilt binary explicitly:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass \
  --pass <canonical-pass>|--<pass-flag> [--pass ...] \
  --count 10000 --seed 0x5eed --out-dir .tmp/<run-name> \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --wasm-opt-bin <official-version-132-wasm-opt> --require-binaryen-version 132 \
  [--wasm-smith] [--generator wasm-smith|gen-valid] \
  [--gen-valid-bin _build/native/release/build/fuzz/fuzz.exe] \
  [--gen-valid-profile <profile>] \
  [--require-feature <feature>] [--exclude-feature <feature>] \
  [--gen-valid-metamorphic-transform <id>] [--emit-metamorphic-pairs] \
  [--external-validator wasm-tools|binaryen|wabt] \
  [--require-independent-validator] \
  [--runtime-execution off|node] \
  [--self-semantic] \
  [--semantic-oracle off|node-v2] \
  [--semantic-policy strict|canonical-nan|trap-aware] \
  [--observation-mode independent|stateful] \
  [--observation-memory-cap-bytes 1048576] \
  [--observation-table-entry-cap 1024] [--runtime-timeout-ms 1000] \
  [--subprocess-timeout-ms 300000] \
  [--determinism] [--codec-idempotence] [--debug-serial-passes] \
  [--property idempotence] [--property composition] \
  [--property semantic-idempotence] \
  [--property convergence --convergence-max 8] \
  [--commutator-left <pass> --commutator-right <pass>] \
  [--localize-first-divergence] \
  [--cache-dir .tmp/pass-fuzz-cache|--no-cache] \
  [--semantic-reduction-relax-family] \
  [--resume] \
  [--min-compared <n>] \
  [--max-failures 20] \
  [--max-mismatch-artifacts 20] [--max-subprocesses 8] \
  [--keep-going-after-command-failures] \
  [--no-reduce-mismatches]
```

Discovery and replay helpers:

```text
bun fuzz compare-pass --list-passes
bun fuzz compare-pass --list-failure-classes
bun fuzz compare-pass --pass <name> --replay-failures-from <dir>
bun fuzz compare-pass --pass <name> --replay-failures-from <dir> --failure-status <status>
bun fuzz compare-pass --pass <name> --replay-failures-from <dir> --failure-class <id>
bun fuzz compare-pass --pass <name> --replay-failures-from <dir> --failure-status <status> --case-index <n>
bun fuzz compare-pass --pass <name> --count <original-count> --out-dir <interrupted-dir> --resume
```

`--resume` is for continuing the original lane in place; `--replay-failures-from` is for starting a separate lane from saved failures. `bun scripts/pass-fuzz-compare.ts ...` is the same underlying implementation. `bun fuzz compare-pass` reaches it through [`scripts/lib/fuzz-task.ts`](../../../scripts/lib/fuzz-task.ts), which treats compare-pass as a sibling command rather than a `src/fuzz` suite.

## Pass Eligibility Preflight

Run a long compare lane only when its pass is executable at **both** sides of the harness:

1. **Harness admission.** `bun fuzz compare-pass --list-passes` reports only names in `SUPPORTED_PASS_FLAGS` in [`scripts/lib/pass-fuzz-compare-task.ts`](../../../scripts/lib/pass-fuzz-compare-task.ts). An absent name is rejected during argument parsing, before input generation or Binaryen execution.
2. **Starshine admission.** The same flag must reach an active Starshine dispatcher. A registry entry in [`src/passes/optimize.mbt`](../../../src/passes/optimize.mbt) can intentionally be `BoundaryOnly`; such a request terminates with a boundary-only error rather than exercising a transform.
3. **Oracle admission.** The local spelling must map to the actual public Binaryen flag, and release signoff must use an explicit verified oracle. For the current baseline, pass the official executable through `--wasm-opt-bin <path> --require-binaryen-version 132`. The harness probes before input generation, rejects unavailable/malformed/wrong-version tools, hashes the resolved executable, writes `toolchain.json`, persists `requiredBinaryenVersion` and `binaryenTool` in `result.json`, stamps each case with `binaryenToolSha256`, and rejects resume under a different hash/version. Use `binaryenPassFlags` to verify aliases. A bare PATH lookup without the required-version guard is exploratory evidence only.
4. **Surface admission.** The selected generator/profile must create modules on which the pass can act, and the run must set a meaningful `--min-compared` threshold. A green process with zero compared cases is not parity signoff.

A pass that fails any of these checks has a **planned fuzzing profile**, not a runnable smoke lane. Its wiki page should document the status test and future command template, but must not label parser rejection, command failure, or zero comparisons as Binaryen-parity evidence. This is especially important for boundary-only registry entries: a Binaryen pass can be real while Starshine deliberately has no active implementation yet.

Binaryen oracle path note: release evidence must state the exact `--wasm-opt-bin`, include `--require-binaryen-version 132`, and retain `toolchain.json`. Bare PATH resolution is acceptable only for exploratory work; it is never locked-v132 signoff without the guard even if an operator checked the version manually. Older v131 commands and results remain historical evidence.

Native binary path note: Starshine's current native-release policy is to pass `_build/native/release/build/cmd/cmd.exe` after `moon build --target native --release src/cmd`. Both `_build/...` and older `target/native/...` artifacts can exist in a worktree; existence alone does not prove freshness. Do not use `target/native/release/build/cmd/cmd.exe` for signoff unless its timestamp or hash proves it is the same freshly built executable. This is local artifact policy, not a generic MoonBit CLI output-path guarantee; see [`../../../AGENTS.md`](../../../AGENTS.md), [`../../README.md`](../../README.md), and the harness implementation.

## Proposal validation oracle

The required validator defaults to `wasm-tools`. `--primary-validator binaryen`
selects the verified `--wasm-opt-bin` for both input and output validation when an
upstream draft is ahead of wasm-tools. This is an explicit comparison-oracle
check, not independent validation. Results and toolchain records preserve the
choice, and resume rejects a changed validator choice. Optional external
validators and runtime execution remain separate checks.

Binaryen 132's Relaxed order byte 2 is one such boundary: installed wasm-tools
1.251 and the inspected 1.258 decoder accept only orders 0/1. The
[release intake](../binaryen/version-132-upgrade.md) records structural checks and
runtime-unverified coverage separately. Default validation rejections remain failure records;
there is no automatic fallback or success-on-unsupported path.

## Input Generators

Compare-pass lanes are intentionally split by generator. The default is a GenValid-only lane; run wasm-smith only by passing `--wasm-smith` for a separate external-generator lane. The legacy `--generator wasm-smith|gen-valid` spelling remains accepted, but the harness no longer has a mixed alternating generator mode.

The `Fuzz Suites` workflow has a separate `external-generator-smoke` job gated to manual `workflow_dispatch`. It pins wasm-tools and Binaryen 132, builds a fresh native optimizer, then compares 16 explicit `--wasm-smith` Vacuum cases with independent validation, determinism, codec stability, and strict failure exit behavior. It is separate from the automatic GenValid profile matrix. This source change defines the lane; no external-generator campaign was run as part of the September 2026 correctness spree.

The `Required CI` workflow's `dae-differential` job now runs both the 10,000-case DAE GenValid comparison and a bounded 16-case `semantic-optimizer-all` comparison. Both use pinned Binaryen 132, independent validation, determinism, codec stability, and fail-on-finding exit behavior. The required workflow self-check asserts that both commands remain inside that job. On 2026-09-22, the repository's master branch-protection required-status list included `dae-differential`; this is a read-only observation of the remote setting, which should be rechecked if branch rules change. The semantic command was not executed locally during this no-fuzz repair spree.

| Generator mode | How to select it | What it does | Best use | Caveats |
| --- | --- | --- | --- | --- |
| `gen-valid` | Default, or `--generator gen-valid` | Runs `--emit-gen-valid-batch ... --manifest <out>/inputs/gen-valid/manifest.json` through `--gen-valid-bin <path>` when supplied, otherwise falls back to `moon run --target native --release src/fuzz --`. | Starshine coverage-forced portable modules and focused regression lanes after FZG widening. | Long/sharded campaigns should build `src/fuzz` once and pass `_build/native/release/build/fuzz/fuzz.exe`; the fallback may pay a cold native-release compile before generation. |
| `wasm-smith` | `--wasm-smith`, or legacy `--generator wasm-smith` | Calls `wasm-tools smith -o <input>` with deterministic seed bytes. | External generator diversity and Binaryen parser/tool gap discovery. | Still validate every generated input; generator/tool failures are not Starshine semantic mismatches. |

`--gen-valid-profile <profile>` forwards a named GenValid profile to that batch command and records the requested profile in `result.json` as `genValidProfile`. Profiles may be singleton leaves or deterministic composites. For composite profiles, each selected manifest record keeps `config_label` as the requested composite label and adds `selected_profile` for the sampled singleton leaf; sampling is deterministic from the root seed and selected case index so the manifest row can be replayed exactly. `--require-feature <feature>` and `--exclude-feature <feature>` may repeat; compare-pass forwards them to the batch emitter and records them as `genValidRequiredFeatures` / `genValidExcludedFeatures`. `--gen-valid-metamorphic-transform <id>` may repeat; compare-pass forwards requested transformed-variant ids to the batch emitter and records them in `result.json` as `genValidMetamorphicTransforms`, while the GenValid manifest preserves the per-input `transform_id` for replay triage. Compare-pass also copies that manifest `transform_id` into each GenValid `cases.jsonl` record as `transformId`, counts compared GenValid cases by transform id in `result.json` as `genValidTransformCounts`, copies manifest `selected_profile` into GenValid case records as `genValidSelectedProfile`, counts sampled leaves in `genValidSelectedProfileCounts`, keeps full `feature_facts` in the GenValid manifest, preserves only the eight bounded effect/trap booleans in case records where the input was scanned before the outcome, copies the transform id into persisted failure metadata, and includes it in transformed GenValid failure directory names as `case-<index>-gen-valid-transform-<id>` so replay triage can identify the active metamorphic family without reopening the manifest. Omit the profile for the default Binaryen-oracle portable batch config; use named profiles and feature filters when a fuzzer slice needs a specific surface such as `binaryen-oracle-portable`, `binaryen-oracle-relaxed-simd`, `simd-heavy`, `relaxed-simd`, or a pass-targeted recipe. The first pass-targeted recipes are `pass-cleanup` for portable local/control cleanup passes, `pass-dae` for direct-call and parameter-pruning surfaces, `pass-inlining` for dense direct-call and tail-call call graphs, `pass-memory` for memory/SIMD/atomics surfaces, `pass-gc-ref` for GC/reference/subtyping surfaces, and `pass-control` for typed branch-heavy control. Use `binaryen-oracle-relaxed-simd` for relaxed-SIMD input generation that should avoid imports, tables, memories, globals, tags, elems, datas, ref-types, atomics, memory64, and other currently nonportable oracle surfaces while still enabling `v128` and relaxed SIMD. Non-portable profiles may still be blocked by external tool support even when Starshine's own batch validator accepts them. The `runtime-callable` alias selects the import-free `inlining-optimizing-all` aggregate: all four leaves export a scalar `run` function and are intended for `--self-semantic` lanes where random portable modules would otherwise be mostly runtime-blocked.

Proposal-targeted GenValid batches may use `--require-feature descriptors`, `continuations`, `waitqueues`, `atomics`, or `array_memory` (and the same labels with `--exclude-feature`). The generated manifest preserves the enum-style `key` in `required_features` for compatibility and adds the exact lowercase `label`, while per-input booleans live in `feature_facts` and aggregate counts live in `feature_stats`. `atomics` includes linear and aggregate struct/array atomics, while `shared_memory_atomics` remains the narrower shared-linear-memory floor.

The `gen-valid` path is why compare-pass depends on [`src/fuzz/main.mbt`](../../../src/fuzz/main.mbt) and [`src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt) even though compare-pass is not itself a MoonBit fuzz suite. Runs that generate Starshine inputs now keep `inputs/gen-valid/manifest.json` beside the saved `.wasm` files; this file records the requested profile, filters, aggregate feature stats, per-input feature facts, and, for composite profiles, the per-input `selected_profile` for replay triage.

## Persistent Cache

Compare-pass uses a persistent cache by default at `.tmp/pass-fuzz-cache`; override it with `--cache-dir <dir>` or disable it with `--no-cache`. The cache never stores Starshine outputs because those are the system under test. It only caches deterministic inputs and Binaryen oracle work:

- `wasm-smith` inputs are stored under `wasm-smith/wasm-tools-<tool-hash>/seed-<seed>/wasmsmith-<seed>-<index>.wasm` only for explicit `--wasm-smith` lanes, so rerunning the same seed and case index skips `wasm-tools smith`.
- Binaryen oracle results are stored under `binaryen/schema-v1/wasm-opt-<tool-hash>/passes-<pass-hash>/input-<input-sha>/` with `binaryen.raw.wasm`, canonical `binaryen.wasm`, printed `binaryen.wat`, and a completion marker. The key includes the input bytes, Binaryen tool identity, and normalized Binaryen pass flags.
- Binaryen/canonicalization command failures are recorded in case journals but never cached as oracle results. A later lane retries the command, so a transient tool failure cannot mask a successful result; older `failure.json` cache entries are ignored and removed on the next lookup.

Observation-v2 reports use a separate `semantic-v2` cache keyed by raw original/Starshine/Binaryen bytes, seed, policy, observation mode, timeout, memory/table caps, runtime version, execution-contract revision, and Binaryen diagnostic state. The current invocation contract adds two bounded, seed-derived finite scalar vectors per callable export alongside defaults, boundaries, and pairwise vectors; the revision invalidates older reports that did not execute them. Earlier revisions also corrected the `call.without.effects` import stub and definite partial outcomes. Start a new output directory when changing the execution contract rather than resuming historical case records. `result.json` records `semanticHits` and `semanticMisses` alongside the wasm-smith and Binaryen counters. Cache hits still validate inputs and regenerate Starshine outputs; Starshine outputs themselves are never cached.

## Interrupted-Run Resume

Pass `--resume` with the original `--out-dir` and `--count` to continue a run that was interrupted before `result.json` and `summary.json` were finalized. The harness reads the existing `cases.jsonl`, preserves those records and failure artifacts, and schedules only missing case indices. It does not merely use the line count: parallel workers can finish out of order, so resume computes the exact completed-index set and fills any holes. For GenValid lanes it reuses the already emitted `inputs/gen-valid/` batch and manifest rather than regenerating the batch.

Repeat the original count, seed, generator/profile, feature filters and transforms, pass flags, optimizer flags, compiler-facts policy, normalizers, correctness/property modes, resource budgets, scheduling/failure policy, tool paths, cache selection, Starshine environment/config overlay, and output directory. `--count` remains the total requested run size, not the number of remaining cases. `toolchain.json` records a SHA-256 configuration identity over those normalized options, the names and hashed values of `STARSHINE_*` variables, and the selected Starshine config file content. It also records a source identity over the compare harness, Bun host, wasm-tools, Starshine and GenValid executables, and their resolved paths; node-v2 runs include the Node executable. Moon fallback commands additionally hash the Moon executable and the workspace `moon.mod`, `moon.pkg.json`, and `src/` contents. Binaryen keeps its separate verified version and executable-content check. A missing, obsolete, or changed identity requires a new output directory before any journal row or generated input is reused. A resumed result reconstructs aggregate comparison/failure/effect/profile counters from persisted case records, reports `resumedCaseCount`, and then adds newly completed cases. Case records persist observation-v2 primary/pattern outcomes, semantic property status/classification, localization state, structural idempotence/composition outcomes, Binaryen/semantic cache states, legacy correctness outcomes, and raw/canonical sizes. Full generated facts stay in the manifest and artifact-scale hazard arrays are excluded, keeping long journals bounded. Resume reconstructs semantic-idempotence, convergence, commutator, paired metamorphic, localization, cache, and legacy counters.

Resume fails closed on a missing `cases.jsonl`, duplicate or out-of-range case indices, an incomplete saved GenValid input batch, or combinations with replay mode. Legacy `--runtime-execution` and optional external-validator aggregates remain rejected because their detailed per-case matrices are not yet persisted.

Example:

```text
bun fuzz compare-pass \
  --pass dead-argument-elimination \
  --count 10000 --seed 0x5eed \
  --gen-valid-profile random-all-profiles \
  --normalize drop-consts --normalize unreachable-control-debris \
  --out-dir .tmp/dae-random-all-10000 \
  --resume --no-reduce-mismatches \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --wasm-opt-bin <official-version-132-wasm-opt> --require-binaryen-version 132 \
  --max-failures 10000 --keep-going-after-command-failures
```

## Normalization And Comparison Flow

For each case, [`runPassFuzzCompare(...)`](../../../scripts/lib/pass-fuzz-compare-task.ts) follows this validation and normalization ladder:

1. **Input validation:** `wasm-tools validate --features all input.wasm` must pass before the case can compare.
2. **Starshine run:** Starshine receives the requested pass flags and `--out <starshine.raw.wasm> <input.wasm>`.
3. **Starshine output validation:** `wasm-tools validate --features all starshine.raw.wasm` must pass. A failure here is a Starshine validation failure, not a Binaryen semantic mismatch. Configured `--external-validator` adapters can also check output with `wasm-tools`, Binaryen, or WABT validators; an unavailable configured binary records a skipped-tool counter and fails validation for that case. Keep this pass-fuzz surface distinct from the command-harness binary differential adapter schema in [`external-validator-adapters.md`](external-validator-adapters.md).
4. **Binaryen oracle run or cache lookup:** `wasm-opt input.wasm --all-features <binaryen-pass-flags> -o binaryen.raw.wasm` produces the oracle output on a cache miss. A success cache entry records SHA-256 hashes for its raw, canonical, and WAT artifacts; all three are verified before reuse. Missing, legacy, or corrupt entries are regenerated. The cache key binds input bytes, Binaryen identity, and pass flags.
5. **Canonicalization:** ordinary lanes pass both raw outputs through `wasm-opt --all-features --strip-debug -o <canonical.wasm>` on cache miss. A pass sequence containing `strip-debug` omits the projection's `--strip-debug`, preserving any name metadata that the requested pass failed to remove. Debug-preserving Binaryen cache entries use a separate schema path, so older stripped cache entries cannot mask the difference. Cached Binaryen canonical output is reused on a valid cache hit; Starshine canonicalization always reruns.
6. **Text normalization:** ordinary lanes print both canonical outputs with `wasm-opt --all-features --strip-debug -S -o <wat>`. A pass sequence containing `strip-debug` again omits `--strip-debug`, making retained printable names visible in WAT. Cached Binaryen WAT is reused on a valid cache hit; Starshine text printing always reruns. `result.json.comparisonDebugPolicy` records `strip` or `preserve`.
7. **Primary self-semantic execution:** legacy `--self-semantic` retains the version 1 plan and observation path. `--semantic-oracle node-v2` is the stronger additive path: production callers invoke Starshine's `--emit-runtime-interface-json` on the original module, so `starshine.optimizer-runtime-interface.v1` comes directly from decoded MoonBit sections rather than reparsed WAT. The legacy wasm-tools text extractor remains only for component callers without a resolved Starshine command. The harness builds one deterministic bounded `starshine.optimizer-invocation-plan.v2`, executes original and Starshine first, and then executes Binaryen when available. The original is always primary; equal Starshine/Binaryen wrong behavior remains a Starshine failure. Binaryen tool failure does not skip original-versus-Starshine. Version 2 observes typed result bits, signed zero, NaN classes/payload policy, deterministic import event arguments/results and committed prefixes, start phase, imported/exported globals, every byte of in-cap memories, and table alias relations. It also executes nullable and bounded non-null `i31ref` function crossings through Node's signed-integer host representation, recording exact 31-bit patterns for exported calls and imported-function events. Over-cap resources, unsupported direct crossings, cross-table identity that Node cannot prove, and worker timeouts are blocked rather than sampled as matches. An aligned scalar return mismatch, return-versus-trap difference, or normalized trap-class difference remains a correctness failure when an unrelated export/resource surface is blocked; the comparison retains `completeness: incomplete` and the blocking diagnostics. Other reference-valued results, relaxed-SIMD values without an allowed-result oracle, unsupported outcomes, timeouts, and unknown incomplete surfaces remain blocked. `independent` reinstantiates for each exported call; `stateful` replays the full sequence on one instance per module. This general node-v2 path remains single-threaded. Reviewed atomic fixtures can separately call [`runNodeAtomicLitmusComparisonV1(...)`](../../../scripts/lib/optimizer-atomic-runtime.ts), which checks two-worker observations against a declarative allowed set rather than comparing one nondeterministic run to another; compare-pass does not infer that oracle for arbitrary generated modules.
8. **Fresh-run determinism and codec stability:** `--determinism` optimizes two independent decodes of the same original bytes. Raw byte equality is the primary result; raw drift with equal canonical output is reported separately as canonical-only stability; canonical drift is `optimizer-nondeterminism`. `--codec-idempotence` performs two Starshine decode/encode cycles on the optimized output, independently validates the result, and requires stable bytes. Starshine outputs are never cached.
9. **Optimizer properties:** `--property` may repeat. Structural `idempotence` and `composition` retain their previous meanings. `semantic-idempotence` compares `M`, `P(M)`, and `P(P(M))` semantically and reports structural drift separately. `convergence` records every canonical generation hash and byte size up to `--convergence-max`, detecting fixed points, cycles, late validation/semantic failures, persistent growth, and bounded nonconvergence. `--commutator-left P --commutator-right Q` validates and compares `M`, `P(M)`, `Q(M)`, `P(Q(M))`, and `Q(P(M))`, distinguishing a pass that fails alone, one failing order, two equal wrong orders, two differently wrong orders, blocked observation, and semantically equal orders with equal or different structure. Both commutator operands are mandatory and use the same strict pass-name registry. Semantic properties require `--semantic-oracle node-v2` and persist common `starshine.optimizer-property-result.v1` records plus generated Wasm artifacts.
10. **Diagnostic serial scheduling:** `--debug-serial-passes` forwards Starshine's existing serial after-each-pass mode while Binaryen still receives only its own optimizer flags. Run both normal stacking and serial mode because scheduler interaction bugs can be mode-specific.
11. **Three-way semantic diagnostics and localization:** after Binaryen is available, node-v2 records original/Starshine, original/Binaryen, and Starshine/Binaryen comparisons in one `starshine.optimizer-three-way-runtime-report.v1`. On a Starshine failure, `--localize-first-divergence` asks native Starshine for the exact module-aware repeated scheduler sequence, evaluates prefix zero and every expanded pass boundary, records later recovery, and reruns the observed boundary pass alone on its predecessor. The report records `passSequenceSource: "moon-expanded-queue"` and says observed boundary plus `reproduced` / `context-dependent` / `blocked`; it does not claim proof of pass guilt. `optimize` and `shrink` are therefore divisible down to their exported scheduler slots, including repetitions.
12. **Secondary Binaryen runtime execution:** `--runtime-execution node` retains the older Starshine-vs-Binaryen export matrix as separate smoke evidence. Runtime-v1 builds the required function-export set from both modules, records a row when either side is missing, and treats that definite interface difference as a semantic mismatch. Scalar parameter vectors are signature-aware (`i64` receives `bigint`, while `i32`/`f32`/`f64` receive numbers); unsupported parameter crossings and exports beyond the invocation cap are recorded as blocked rows. Persisted matrix summaries report `observed` and `blocked` rows separately, and a matrix with no observations is blocked rather than counted as checked.
13. **Compare:** matching WAT increments `normalizedMatchCount`; explicit cleanup normalizers increment `cleanupNormalizedMatchCount`; remaining drift records `mismatch` and still requires maintainer classification.

That order matters. A pass can be locally safe but still differ in raw binary layout, custom-section order, name stripping, or textual representation. Ordinary lanes intentionally remove those surfaces before comparing; `strip-debug` lanes retain the printable name surface because name removal is the pass contract under test.

### Normalization Contract And Risk Boundary

The compare result is only as strong as the normalization layer below. Treat each step as a documented semantic filter, not as proof that every possible raw difference is harmless.

| Step | Current harness action | Intended equalized surface | Semantic risk boundary |
| --- | --- | --- | --- |
| Input validation | `wasm-tools validate --features all input.wasm` before either optimizer runs. | Rejects generator bytes that are not independently valid WebAssembly. | A failing input is a generator/tool issue; do not classify it as pass semantics. `wasm-tools` proposal support can still be narrower or broader than Starshine/Binaryen. |
| Starshine output validation | `wasm-tools validate --features all starshine.raw.wasm`. | Ensures Starshine did not produce invalid wasm before any canonical comparison. | Validation success is necessary but not sufficient for semantic parity; a later mismatch still needs agent classification. Validation failure is a Starshine correctness blocker. |
| Binaryen oracle execution | `wasm-opt input.wasm --all-features <binaryen-pass-flags>`. | Uses Binaryen as the pass-local oracle for the requested canonical pass flags. | Binaryen command/parser failures are tool/oracle failures until replayed and classified. Alias mismatches or unsupported pass surfaces can invalidate the comparison setup. |
| Binary canonicalization | Ordinary lanes run `wasm-opt --all-features --strip-debug -o <canonical.wasm>` on both raw outputs; a pass sequence containing `strip-debug` omits the projection's `--strip-debug`. | Rewrites each output through the same Binaryen binary writer while retaining names when name removal is the requested behavior. | Ordinary lanes intentionally ignore name/debug/custom-section placement and raw encoder layout. The `strip-debug` exception exposes retained name metadata but remains a canonical WAT comparison, not byte-for-byte or arbitrary custom-section parity. |
| Text printing | Ordinary lanes run `wasm-opt --all-features --strip-debug -S -o <wat>`; a pass sequence containing `strip-debug` prints without the extra strip. | Compares a stable text projection and retains printable names for the name-removal pass. | Text equality is the harness green condition. A WAT difference is a symptom, not a classification: use replay evidence to label it as a Starshine win, parity gap, size loss, unknown/risk, tool failure, validation failure, or true semantic mismatch. |
| Compare normalizers | `--normalize drop-consts`, `--normalize unreachable-control-debris`, `--normalize ssa-local-allocation-debris`, and `--normalize local-cleanup-debris` may be applied to the canonicalized outputs before comparison. | Covers documented DAE-style cleanup noise and other explicitly inspected debris families that should not count as raw mismatches, including narrow pure dropped numeric/const debris, unreachable/control debris, local-allocation debris, and unused local/nop/empty-const-if cleanup. Equality reached only after these normalizers increments `cleanupNormalizedMatchCount` and records a `cleanup-normalized-match` status. | Keep the normalizers opt-in and pass-specific; do not use them to hide missing side effects, signature differences, trapping behavior, or other unexplained drift. `drop-consts` retains every non-saturating float-to-integer truncation, including the unsigned forms, because a closed constant expression can still trap on NaN, negative, or out-of-range input. `unreachable-control-debris` treats exports, direct/reference calls, and the start function as roots; start-time prefixes are never classified as unused-function debris. It preserves named type declarations and `(type ...)` uses so parameter, result, recursion, and nominal-identity differences remain visible. |
| Debug/name stripping | `--strip-debug` is applied during canonicalization and printing unless the requested sequence contains `strip-debug`. | Function/local/label names and printable name-section payloads do not affect ordinary pass matches; they remain observable for the name-removal pass. | A `strip-debug` match now covers the printable name surface. It still does not prove byte layout, arbitrary custom-section preservation, or nonprinted DWARF payload parity; retain focused module tests for those contracts. |
| Default-local and wrapper shape normalization | Binaryen's canonical printer may elide explicit default initializers, simplify harmless wrapper syntax, or choose a different printed expression shape. | Avoids failing on common canonical WAT presentation differences. | This is not a blanket semantic equivalence rule. Local declaration count, block result typing, and wrapper differences that affect validation, control flow, traps, exports, starts, tables, memories, or globals remain real risks; see [`../validate/runtime-trap-semantics.md`](../validate/runtime-trap-semantics.md) before treating equal traps or trap-shaped rewrites as semantic proof. |
| NaN and numeric text formatting | Numeric constants are compared after Binaryen's canonical binary-to-text projection. | Equalizes supported spelling/format choices for printed constants. | Payload-sensitive NaN behavior and trapping numeric operations still require pass-specific reasoning. Do not assume arbitrary floating-point rewrites are safe from normalized text alone. |
| Local/name stripping in reports | Failure artifacts keep raw and printed files, while ordinary aggregate counts key off stripped normalized WAT. `strip-debug` aggregates use name-preserving normalized WAT. | Keeps ordinary signoff focused on pass semantics while testing the name-removal pass against its visible contract. | If another pass promises user-visible name preservation or stable diagnostics, protect that with dedicated tests outside compare-pass. |
| Optional property normalization | Idempotence/composition checks canonicalize their Starshine outputs before comparing WAT. | Separates Starshine self-consistency failures from Binaryen oracle mismatches. | A property failure is evidence about the requested property only; report it separately from Binaryen semantic mismatch counts. |

Reporting rule: a normalized match is good pass-oracle evidence for the compared surface. For `strip-debug`, that surface includes printable names; for other passes it does not sign off debug/name preservation. No normalized match signs off raw bytes, custom-section placement, diagnostic locations, runtime import behavior, or unexercised proposals. A normalized mismatch is only a symptom; classify it with replay evidence, transform contracts, and pass-specific semantic reasoning.

### Maintainer Classification (Not Harness Output)

The harness emits technical statuses such as `mismatch`, `validation-failure`, and `command-failure`. It does **not** decide whether a mismatch is acceptable. Record one of these agent judgments in the pass dossier, research note, or promoted corpus metadata:

| Agent judgment | When it is justified | Required evidence / disposition |
| --- | --- | --- |
| **Starshine-win** | The output differs but preserves the relevant semantics and has a documented concrete benefit, such as smaller canonical output, fewer effective operations without an important size regression, stronger validation, or materially better pass-local performance. | Cite the transform contract, inspected/reduced repro, semantic reasoning, and measured delta. Keep the evidence replayable; reopen if the win disappears. |
| **Parity gap** | The output differs and no measured Starshine benefit justifies retaining the drift. This is the default for unexplained or neutral representation differences. | Keep it open for alignment or document it as a release blocker/boundary; do not call it safe merely because both outputs validate. |
| **Size-losing** | Starshine's output is larger or otherwise regresses a relevant measured metric. | Treat as a parity/performance follow-up unless a stronger documented correctness benefit overrides it. |
| **Unknown/risky** | Evidence is incomplete, the transformed behavior is hard to model, or a proposal/runtime/trap boundary remains unresolved. | Quarantine or investigate; do not use it as signoff evidence. |
| **Tool/Binaryen failure** | The input, oracle, canonicalizer, or auxiliary tool failed before a trustworthy pass comparison. | Preserve the tool/version/command/failure class and replay on a fixed or supported tool before assigning Starshine blame. |
| **Validation failure** | Starshine produced invalid output or violated a required validation boundary. | Correctness blocker; do not downgrade it to a representation difference. |
| **True semantic mismatch** | A reduced/inspected case, runtime disagreement, or semantic proof shows different observable behavior. | Correctness blocker; retain a repro and fix or explicitly stop supporting the surface. |

A case may move between categories as evidence improves. In particular, a valid output, a smaller output, a normalizer hit, or equal smoke traps alone is insufficient to establish a Starshine win.

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

- `result.json` - aggregate comparison, size, cache, generator, property, and failure counters. `comparisonDebugPolicy` records whether the canonical WAT projection strips or preserves debug names. Additive semantic fields include the oracle/policy/mode/caps/timeout, v2 checked/match/blocked/mismatch counts, three-way pattern counts, semantic-idempotence, convergence, and commutator operands/counts/classifications, localization counts/recoveries, and the ordered `propertyModes` list. The legacy singular `propertyMode` remains for compatibility.
- `summary.json` - compact `starshine.fuzz-summary-report.v1` counters for `bun fuzz coverage-delta`, with suite `compare-pass`, profile `<pass>+<generator>`, required requested/compared case counters, optional generator/GenValid transform/property/input-effect/runtime counters, run-status counters including exact normalized-match versus cleanup-normalized-match separation, failure-class counters, and failure-artifact counts.
- `cases.jsonl` - one case record per attempted case, sorted by case index after the run; GenValid metamorphic cases include `transformId` when their manifest entry has `transform_id` and `genValidFeatureFacts` when their manifest entry has `feature_facts`; records also include input effect/trap facts, semantic/determinism/codec outcomes when requested, and raw/canonical output sizes for compared cases. Once an input exists, `compilerFactsContext` records whether exact raw `compiler.facts` custom-section bytes were present, their count and combined byte length, a SHA-256 over those encoded sections in module order, scan status, and the effective Starshine policy. The bounded record stores no section payload. Historical rows without this optional object remain resumable and are preserved unchanged.
- `inputs/` - saved generator inputs for generated lanes.
- `semantic-observations/case-XXXXXX.json` - every node-v2 three-way report, including runtime interface, invocation plan, three observations, three comparisons, and classification.
- `property-results/` and `property-artifacts/` - common versioned semantic-idempotence, convergence, commutator, and metamorphic-equivalence results and their generated modules.
- `localizations/` and `localization-artifacts/` - all-prefix localization reports and persisted divergent/predecessor/standalone modules when requested.
- `failures/case-<index>-<generator>/` or `failures/case-<index>-gen-valid-transform-<id>/` - copied per-case workdir files for generator failures, validation failures, command failures, and normalized mismatches.

After writing these artifacts and the aggregate counters, compare-pass exits nonzero by default when it observed any normalized mismatch, validation failure, generator failure, command failure, property failure, legacy runtime semantic mismatch, or `--max-failures` cutoff. This makes the default command suitable for CI and parity signoff while preserving the complete report for diagnosis. Setup and argument errors can still fail before report creation.

`comparedCount` and the per-generator comparison counters require successful Starshine and Binaryen oracle outputs. When Binaryen or its canonicalization command fails, an original-versus-Starshine node-v2 semantic match is retained as diagnostic evidence, but the case remains `command-failure` and does not count as a comparison or match. On resume, older `match` records carrying `diagnosticFailureClass` are reconstructed under this command-failure accounting rule.

Use `--report-only` only for an intentional diagnostic collection where the caller will inspect and classify `result.json` separately. That option keeps exit zero for observed outcomes, but it does not suppress setup errors or an unmet explicit `--min-compared` requirement. `result.json` records the selected `exitPolicy` as `fail-on-observed-failures` or `report-only`.

Each semantic-v2 failure directory additionally includes `semantic-v2.json`, `semantic-fingerprint.json`, `semantic-fingerprint.sha256`, and, when requested, `pass-localization.json`. Fingerprints retain the exact policy, outcomes/traps, first difference, resource/offset or import-event prefix, invocation plan hash, pass sequence, and localized boundary.

Each failure directory includes:

- `failure.txt` - human-readable detail;
- `input.wasm` - replay input;
- `input.print.wat` when `wasm-tools print` succeeds;
- `failure-metadata.json` with `caseIndex`, `generator`, failure `status`, `detail`, copied artifact names, relative replay input plus pass flags, the per-input GenValid manifest entry when the failing case came from a manifest-backed `gen-valid` batch, and a `runtimeExecutionMatrix` block for runtime-enabled mismatches after the Node export matrix has run.

Ordinary mismatch bundles are capped independently from mismatch counting by `--max-mismatch-artifacts <n>`; the default is `20`, and `0` keeps aggregate/case records without copying ordinary mismatch workdirs. Validation, generator, command, and property failures are never suppressed by this cap. `result.json` records `mismatchArtifactsPersistedCount` and `mismatchArtifactsSuppressedCount`. Byte-slice reduction shares this budget: once no ordinary bundle can be persisted, later mismatches are counted but are not reduced pointlessly.

For fresh `gen-valid` normalized mismatches that still have an artifact slot, pass-fuzz also attempts a byte-slice reduction after the mismatch has already been classified by the ordinary oracle. Successful reductions add `reduced-input.wasm`, `reduction.txt`, and a `reduction` block in `failure-metadata.json`; the reduction metadata includes original/final sizes, predicate-evaluation count, and `delete-byte-slice` steps. `input.wasm` remains the original replay input, so this artifact path does not change mismatch counting or replay semantics. Use `--no-reduce-mismatches` for broad triage or signoff lanes where already-known mismatch families would otherwise spend the run budget reducing every GenValid case before aggregate counts can complete; the flag preserves the original mismatch artifacts and records `reduceMismatches: false` in `result.json`. The byte-slice predicate launches validation, both optimizers, canonicalization, and print work synchronously for each candidate. A measured `flatten` random-profile example required `42,233` to `69,224` predicate evaluations on 20–31 KiB inputs to remove only 4–32 bytes, while replaying the unreduced case took `0.184 s`; disable aggregate reduction and reduce selected representatives separately when this pattern appears. The reducer contract, log schema, and predicate-preservation caveats are centralized in [`../fuzzing/reduction-backends.md`](../fuzzing/reduction-backends.md).

The generator ledger records this as `[FZG]029`; see [`../fuzzing/generator-coverage-ledger.md`](../fuzzing/generator-coverage-ledger.md).

## Failure Statuses And How To Report Them

| Status | Meaning | Report as |
| --- | --- | --- |
| `match` | Starshine and Binaryen normalized WAT matched after both oracle pipelines succeeded. | Green comparison evidence. |
| `mismatch` | Both outputs were produced and normalized, but WAT differed. | Harness symptom only. The pass owner must make and record an agent judgment from the taxonomy above; absent a proven Starshine win, keep it as a parity gap. |
| `validation-failure` | Starshine produced invalid wasm. | Correctness blocker for Starshine. |
| `generator-failure` | The input generator failed or produced bytes that failed independent validation. | Tool/generator issue unless inspection says otherwise. |
| `command-failure` | Starshine, Binaryen, or canonicalization command failed. | Classify by `failureClass`; replay before claiming pass semantics. |
| `property-failure` | An optional property check failed independently of the Binaryen oracle comparison. Today this means `pass(pass(m))` differed from `pass(m)` or the second Starshine output failed validation/canonicalization under `--property idempotence`, or a combined pass invocation differed from sequential single-pass invocations under `--property composition`. | Report as property-specific evidence, not as a Binaryen semantic mismatch. |

Replay defaults to historical command-failure behavior for backward compatibility. Use `--failure-status mismatch`, `--failure-status validation-failure`, `--failure-status generator-failure`, or `--failure-status property-failure` to replay other persisted failure kinds; combine with `--case-index <n>` to pick one saved case. `--failure-class <id>` is only meaningful for `command-failure` records.

Command failures may or may not count toward `--max-failures`. By default they do; `--keep-going-after-command-failures` records them without spending the failure budget. That mode is useful when a known tool class, such as a Binaryen parser gap, would otherwise prevent collecting enough comparable cases. It does not change the final exit policy: add `--report-only` for diagnostic collection, or expect the recorded command failures to make the command fail.

Known command-failure classes are intentionally concrete and replayable: `starshine-command-failed`, `starshine-invalid-limits`, `starshine-invalid-range-for-limits`, `binaryen-invalid-type-index`, `binaryen-invalid-tag-index`, `binaryen-rec-group-zero`, `binaryen-invalid-wasm-type-neg64`, `binaryen-initializer-expression-not-constant`, `binaryen-table-index-out-of-range`, `binaryen-bad-section-size`, and `binaryen-command-failed`.

When `binaryen-command-failed` contains a BrOn-family assertion such as `Type::getHeapType()` / `isRef()` while parsing `br_on*` or descriptor-branch operands, use the 2026-06-05 Binaryen bridge before assigning blame. On older installed Binaryen builds this is a known upstream tool/oracle failure family fixed by commit `1251efb`; preserve the exact command/build and replay on a fixed build before claiming Starshine semantic mismatch.

## Concurrency Rules

`--jobs auto` requests host parallelism; `--jobs <n>` fixes the requested worker count. The effective worker count is additionally capped by `--max-subprocesses <n>`, default `8`, so process-heavy Starshine/Binaryen/wasm-tools/Node combinations cannot exhaust host process or Rayon thread limits. Documentation and signoff commands should include `--jobs auto`, an explicit subprocess cap when host limits are known, and `--starshine-bin _build/native/release/build/cmd/cmd.exe` together. Any effective worker count above `1` requires `--starshine-bin`.

Optimizer, validator, generator, reduction, and artifact-print subprocesses are bounded. `--subprocess-timeout-ms <positive integer>` sets the main Starshine and Binaryen pass deadline, primary and external validator deadline, both wasm-smith and GenValid generator deadlines, and the Binaryen version-probe deadline separately from the semantic Node worker's `--runtime-timeout-ms`; the version probe retains a 5000 ms maximum. Auxiliary canonicalization/projection, reduction, and artifact-print probes use a fixed 300000 ms deadline, while the wasm-tools identity probe uses a fixed 5000 ms deadline. Values above Node's 2147483647 ms timer limit are rejected. The chosen configurable value is recorded in `result.json` and the resume identity. Synthetic fixtures exercise hangs in Starshine, an external validator, both generator implementations, and the synchronous Binaryen version probe. A timed-out optimizer is a command failure, not a semantic match.

Correctness signoff lanes use `--require-independent-validator`, which requires `wasm-tools` as the primary validator and rejects Binaryen-only validation at option parsing. Binaryen remains an available primary validator for diagnostic proposal lanes without that flag. The signoff choice is recorded in `result.json`, the toolchain record, and the resume identity. Both CI compare-pass commands carry the signoff flag.

Reason: without a prebuilt Starshine binary, the harness invokes Starshine through `moon run --target native --release src/cmd -- ...`. Parallel `moon run` calls can contend on `_build/.moon-lock`, so the harness refuses that shape. Build `src/cmd` once and pass its native binary path for parallel lanes. The implementation also treats omitted `--jobs` with `--starshine-bin` as auto, but documented commands should keep both flags visible so copied signoff lanes are unambiguous. If a local `target/native/...` binary exists, treat it as an old compatibility artifact unless its timestamp/hash proves it matches the current `_build/native/...` output.

## Signoff Guidance

For a direct pass signoff:

1. Run focused MoonBit tests for the pass and dispatcher/registry surface.
2. Run a small default GenValid `--count <small>` smoke lane while iterating.
3. Build `src/cmd` once with `moon build --target native --release src/cmd`.
4. Run the repo-standard direct lane, usually `--count 10000 --seed 0x5eed`, with a stable `--out-dir`, explicit `--jobs auto`, and explicit `--starshine-bin _build/native/release/build/cmd/cmd.exe`.
5. If command failures dominate during diagnostic collection, rerun with `--keep-going-after-command-failures --report-only` and use `--min-compared` so the run still proves enough comparable cases. Record and classify every skipped oracle case; report-only is not signoff by itself.
6. Record the harness status **and** an agent classification for every residual in the pass dossier. A Starshine win needs a transform contract, inspected/reduced repro or equivalent semantic reasoning, and a measured benefit; otherwise keep the drift as a parity gap. Do not use validation success, smaller bytes alone, normalizer use, or equal smoke traps as semantic proof.
7. For DAE / generator-debris lanes, include `--normalize drop-consts --normalize unreachable-control-debris` so cleanup-normalized matches are counted separately from exact normalized matches.
8. Preserve the run directory locally and cite durable aggregate facts in the affected pass page, tracker, or research note.

For preset or neighborhood work, direct pass green is necessary but not sufficient. Also replay the ordered neighborhood or preset artifacts described by [`../binaryen/no-dwarf-default-optimize-path.md`](../binaryen/no-dwarf-default-optimize-path.md) and the affected pass dossier.

## Semantic campaign integration boundary

The version 2 runtime, semantic-idempotence/convergence, commutator, emitted GenValid base/twin records, production metamorphic equivalence, exact fingerprint reduction, Moon-expanded localization, replay, external `wasm-reduce` predicates, and corpus paths are integrated as described above; the complete schema catalog and remaining limitations are in [`../fuzzing/semantic-optimizer-campaigns.md`](../fuzzing/semantic-optimizer-campaigns.md). Dedicated semantic profiles, explicit family relaxation, whole-Wasm neighborhood exploration, semantic resume/cache reconstruction, runtime adapters, and pinned CI are integrated. See the linked campaign page for completed August 29, 2026 evidence, its historical v131 limitations, and the current v132 renewal boundary.

## Sources

- Binaryen BrOn assertion / oracle boundary: [`../binaryen/release-horizon-and-oracles.md`](../binaryen/release-horizon-and-oracles.md)
- Upstream tool and validation references: <https://github.com/WebAssembly/binaryen>, <https://github.com/bytecodealliance/wasm-tools>, <https://docs.rs/wasm-smith/latest/wasm_smith/>, and <https://webassembly.github.io/spec/core/valid/>
- Native artifact-path policy: [`../../../AGENTS.md`](../../../AGENTS.md), [`../../README.md`](../../README.md), and the harness implementation below
- Harness implementation: [`../../../scripts/lib/pass-fuzz-compare-task.ts`](../../../scripts/lib/pass-fuzz-compare-task.ts)
- Wrapper split: [`../../../scripts/lib/fuzz-task.ts`](../../../scripts/lib/fuzz-task.ts)
- Command-shape tests: [`../../../scripts/test/pass-fuzz-compare-command.ts`](../../../scripts/test/pass-fuzz-compare-command.ts), [`../../../scripts/test/task-family-commands.ts`](../../../scripts/test/task-family-commands.ts)
- `gen-valid` batch emitter: [`../../../src/fuzz/main.mbt`](../../../src/fuzz/main.mbt), [`../../../src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt)
- Shared gates: [`validation-gates.md`](validation-gates.md), [`fuzz-runner.md`](fuzz-runner.md)
- Pass queues and oracle context: [`../binaryen/passes/tracker.md`](../binaryen/passes/tracker.md), [`../binaryen/no-dwarf-default-optimize-path.md`](../binaryen/no-dwarf-default-optimize-path.md)

### Explicit Node execution and timeout cleanup

The `node-v2` oracle runs each observation in an explicit `node` child process,
even when the compare CLI runs under Bun. A host `Worker` uses the host engine;
labeling that observation with Bun's emulated Node version does not make it a
Node measurement. The child reports the installed Node version. This entry
point requires Node with native TypeScript stripping (tested with v26.8.1).

A timed-out child receives `SIGKILL`, and the oracle waits for its `close` event
before releasing the case slot. The observed timeout stays incomplete and
blocked. It is never counted as a semantic match. The old host-worker path
could leave nonterminating Wasm alive after `terminate()`: a generated run grew
from 162 to 243 threads and used about 1,500 percent CPU. That run was stopped;
its partial semantic observations are not signoff evidence.

Semantic cache identity includes `node-v2-process-v1` and the installed Node
version. Host-worker observations cannot be reused as Node process results.
Regression tests check the actual Node version, three nonterminating starts,
a successful observation afterward, state and import events, SIMD adapters,
and three-way mismatch classification. The executor and compare task tests
must pass before restarting a generated gate. All 75 executor/compare-task
tests pass in 2.128 seconds. A 128-case real-Node smoke run takes 28.256 seconds:
128 canonical matches, 67 complete three-way semantic matches, 61 blocked
original runs, and zero mismatches or command/validation/property failures.
Blocked originals remain incomplete evidence.

Sources: `scripts/lib/optimizer-runtime-executor.ts`,
`scripts/lib/optimizer-runtime-v2-worker.ts`, and
`scripts/lib/optimizer-runtime-executor.test.ts`.

### Semantic resume identity

`node-v2` cache entries and `toolchain.json` include the intrinsic-call execution
contract, Node process adapter version, and installed Node version. A resumed run
must use the same semantic mode and contract; missing or older node-v2 contracts
require a fresh output directory. This check runs before generation or reuse of
completed journal rows. See
[`optimizer-semantic-cache.ts`](../../../scripts/lib/optimizer-semantic-cache.ts)
and [`the resume regression`](../../../scripts/lib/pass-fuzz-compare-task.test.ts).

The general resume identity applies whether semantic-v2 is enabled or not. It
separately fingerprints normalized run configuration and local source/tool
content, so changing a seed, pass/profile/policy, harness source, candidate
binary, generator binary, wasm-tools binary, or Moon workspace source fails
closed. Historical `toolchain.json` files without
`starshine.optimizer-resume-identity.v1` cannot be resumed under this contract.

Use `--runtime-timeout-ms 10000` for the new DAE2, constraint and proposal
campaigns. Preserve timed-out observations as incomplete evidence. Changing the
budget or passing structural checks never turns a timeout into successful runtime
verification. See the [upgrade ledger](../raw/binaryen/2026-09-10-v132-validation.json).
