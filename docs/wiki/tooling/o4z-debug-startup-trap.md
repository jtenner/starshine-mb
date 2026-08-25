---
kind: concept
status: supported
last_reviewed: 2026-08-24
sources:
  - ../binaryen/passes/late-pipeline-dispatch.md
  - ../../../scripts/lib/build-self-optimized.mjs
  - ../../../scripts/lib/self-optimized-artifacts.mjs
  - ../../../scripts/lib/o4z-debug-startup-map.test.ts
  - ../../../tests/repros/o4z-debug-startup-map-init-repro.wasm
  - ./cli-startup-path.md
related:
  - ./wasi-runner-and-preview-boundary.md
  - ./cli-command-and-dispatcher.md
  - ./cli-startup-path.md
  - ./validation-gates.md
  - ../validate/runtime-trap-semantics.md
  - ../binaryen/no-dwarf-default-optimize-path.md
---

# O4z Debug Startup Trap

## Overview

This page records `o4z` startup-trap investigations and the permanent guards that keep debug and self-optimized WASI artifacts honest. The fast-path and path-normalization work still belong in [`cli-startup-path.md`](./cli-startup-path.md); this page covers optimizer-induced startup corruption and the separate stale-debug-artifact regression sentinel.

The historical host-visible symptom was `RuntimeError: unreachable`; the August 23, 2026 current-source self-optimization regression trapped as `RuntimeError: memory access out of bounds`. Those messages are trap-classification hints, not proof of structural invalidity: the failing self-optimized artifact passed `wasm-tools validate --features all`. The replay host is the Node-hosted WASI Preview 1 runner documented in [`wasi-runner-and-preview-boundary.md`](wasi-runner-and-preview-boundary.md). The debug-artifact regression is repaired; current-source self-optimization remains under active repair.

## Current understanding

- The stale committed debug-WASI artifact path is repaired. The reduced `malloc` shape now carries the TLSF root/control pointer into `tlsf/removeBlock` instead of leaving a literal zero on the stack.
- One current-source owner is repaired: raw SimplifyLocals effectful-suffix sinking moved a stack-carried producer containing `local.set` or `local.tee` writes behind instructions that read those locals. The rewrite now tracks producer-written locals and treats conflicting reads and writes as movement barriers.
- The apparent `dae-optimizing` failure was reduced to its typed-loop-safe nested `coalesce-locals` stage. The DAE boundary batch and nested SimplifyLocals output both remained runtime-safe; function-body hybridization isolated the first bad coalesced body to absolute function 8017.
- Dense-tee interval marking incorrectly treated a block as never falling through when its textual tail returned, even though an earlier nested branch targeted that block's continuation. The marker stopped scanning, classified continuation locals as unused, and merged simultaneously live values into one slot. Structured escape classification now checks for branches to the instruction's own continuation before declaring its tail terminal.
- The unmodified 69-pass main O4z sequence is runtime-safe. The apparent final-`precompute` failure was reduced to function 7851: deleting a valid dead constant forced Hot-IR lowering, which emitted a later void call before an earlier stack-carried call result consumed by control. Lowering now schedules only effectful value producers that predate and cross a void call-like root, preserving call order without changing Hot-IR root structure.
- The subsequent final-candidate canonicalization trap was isolated across 4,548 changed bodies to allocator function 29. Nested dead-tee cleanup inspected only an `if` arm suffix and removed local writes read after the `if`. Dead-tee recursion now carries enclosing continuations through blocks, loops, if arms, and try tables; the rebuilt artifact passes startup/help.
- The scalar-selected follow-up first exposed another main-pipeline ordering defect at prefix 17, `simplify-locals-nostructure`. Hybridization across 702 changed bodies isolated function 8102: root traversal visited a later void release call before an earlier stack-carried multivalue call dependency, so a pending initialization was sunk to the later read. SimplifyLocals now pre-scans earlier effectful call dependencies of future roots before intervening void calls.
- Prefix 35 `precompute-propagate` was then reduced across 28 changed bodies to function 8889. A local written by a result-producing `if` through `local.tee` was resolved from a stale entry-default SSA origin and folded to zero. Such result-if-derived writes are now unsafe unless SSA reports a real phi.
- The remaining scalar cleanup failure appeared in its first `remove-unused-brs` pass. Hybridization across 466 changed bodies isolated function 8788: a future stack-carried load containing `local.tee 8` was emitted after a current root that read local 8. Hot lowering now schedules the complete earlier effectful producer when its local writes conflict with the current root's reads, in addition to the existing call-order rule.
- `scripts/lib/build-self-optimized.mjs` describes the build/copy flow that produces the debug artifact used by later self-optimize runs.
- `scripts/lib/self-optimized-artifacts.mjs` names the debug artifact path that the build pipeline copies into the node-dist layout.
- The runtime-trap semantics remain source-backed in [`../validate/runtime-trap-semantics.md`](../validate/runtime-trap-semantics.md); use that guide to remember that `RuntimeError: unreachable` is a wasm trap surface, not a Node-specific exception class.
- The detailed owner evidence and the repaired pass-owner follow-up live in the archived research note [research note 0693](../binaryen/passes/late-pipeline-dispatch.md).
- The Node-hosted WASI runner boundary lives in [`wasi-runner-and-preview-boundary.md`](wasi-runner-and-preview-boundary.md); this page uses that runner as replay evidence but does not make WASI 0.2/0.3, Component Model, JSPI, or sandboxing claims.

## Current-source self-opt evidence

- Exact main-pipeline runtime bisection placed the first failure at prefix 24, where `simplify-locals` followed a runtime-safe prefix ending in `local-cse`.
- Function-body hybridization reduced that failure to defined function 8037 and exposed a `local.get` moved before its corresponding producer write.
- The focused regression is `raw simplify-locals keeps stack-carried producer writes before destination reads`.
- The next apparent failure at `dae-optimizing` was narrowed through stage dumps: boundary batch runtime `0`, nested SimplifyLocals runtime `0`, nested coalescing runtime `1`. Hybridization across 345 changed coalesced functions isolated absolute function 8017.
- The focused coalescer regression is `coalesce-locals dense-tee intervals keep branch-reachable continuation locals distinct`; the repaired artifact-scale DAE replay passes `tests/spec/address.wast`.
- The current explicit 69-pass main artifact validates and passes runtime replay. Function-body hybridization across 676 precompute-changed functions isolated function 7851; the direct Hot lift/lower and pass-level precompute regressions preserve the producer call before the intervening effect.
- With that fix, exact main plus `precompute` and `vacuum` passes runtime. Canonicalized-body hybridization then isolated function 29; the focused regression is `O4z final canonicalizer preserves nested tees read by the continuation`.
- Function 8102 is covered by `simplify-locals-nostructure keeps initialization before stack-carried call read`; function 8889 is covered by the result-if unsafe-write invariant; function 8788 is covered by `hot lower preserves stack-carried local tee before later local read`.
- A stronger direct-use replay then exposed two additional failures on `o4z-debug-startup-map-init-repro.wasm`. Native O4z first diverged at prefix 24 `simplify-locals`, function 3: multi-use sets crossed stack-carried values and intervening local writes. The focused regression `simplify-locals preserves stack-clearing set below a later local result` now keeps both the reduced result tuple and the complete native O4z runtime equal to the original.
- The rebuilt self-optimized CLI still trapped while optimizing that 192,813-byte input. Artifact-prefix bisection placed the first failure at main prefix 39 `dae-optimizing`; staged replay proved the typed-loop DAE batch and nested SimplifyLocals were safe, while nested `coalesce-locals` failed. Hybridization across 346 changed bodies isolated absolute function 7769: a copied allocation pointer remained live through local 21, but straight-line coloring reused its slot for local 45 before the late read. Linear interference construction now makes source-write/destination-read hazards authoritative while retaining the explicit-zero/implicit-default exception.
- The rebuilt 4,837,174-byte self-optimized CLI validates and passes `bun validate self-opt-smoke`. It directly optimizes the startup repro without trapping, emits byte-identical native/self-hosted output of 188,035 bytes with SHA-256 `af12261f248dd97693365a7ea82f03a7c21d6b6c536b90edd9f1502a78758829`, and the original, native output, and self-hosted output all exit zero under `--help`. Artifact SHA-256: `7b0593904275ad51cfe9de9e024fc708fb3bae77168fbd0653a0a61309812ea2`.
- Generated replay and bisection artifacts remain under `.tmp/self-opt-current-prefix-bisect/`, `.tmp/self-opt-address-prefix-bisect/`, `.tmp/self-opt-main-after-coalesce/`, `.tmp/self-optimized-cli-smoke-bisect/`, and `.tmp/direct-binary-smoke/self-optimized-after-coalesce-lifetime/`.

## August 24 WAGO functional closeout

The WAGO execution-manifest lane now covers 48 executable modules and 323 specified calls, including repeated invocations and exported memory/global/table snapshots. Native and rebuilt self-hosted O4z optimize all 48 inputs, all 96 outputs validate independently, native/self-hosted outputs are byte-identical for every module, and all 323 native plus all 323 self-hosted observations match the originals.

The audit exposed and repaired these additional unsafe families:

- `remove-unused-brs` moved effectful conditions and local initializers while flattening result-if ladders. Condition-local write/read ordering is now guarded; the focused condition-operand regression remains in `remove_unused_brs_test.mbt`.
- `optimize-instructions` raw memory-offset folding mistook a shift constant inside a stack-carried store value for the store address. The raw three-instruction fold now requires a self-contained scalar value leaf.
- commutative OptimizeInstructions canonicalization swapped local operands across a preceding sibling write. Root-use analysis now rejects swaps when a source-older local read crosses that write.
- `merge-blocks` flattened a block whose later result consumed a source-older local read across an earlier sibling write. Root flattening now preserves that dependency.
- `merge-locals` retargeted source-older reads and, even after rejecting the rewrite, allowed temporary instrumentation to force unsafe lowering. Source-order admission and a pre-instrumentation stack-carried-copy boundary now preserve the accumulator.
- `ssa-nomerge` exposed several independent artifact-scale families: stacked call results, tee/call loop carriers, default-materialization across tee/load and load/set lifetimes, typed-loop load/set debris, and numeric i64 encoder helpers. The raw planner now fails closed or rolls back only on the corresponding semantic evidence; focused SSA and white-box regressions cover each boundary.
- the post-canonical O4z `remove-unused-brs` cleanup reordered the Fibonacci accumulator copy. The raw six-instruction accumulator proof now keeps that candidate unchanged.

Final evidence is under `.tmp/wago-o4z-functional-20260824/` and `.tmp/self-optimized-cli-smoke-bisect/`. The rebuilt self-optimized artifact is 4,849,752 bytes with SHA-256 `03a541df56b597e074e95bac8095494c832c114521c141b9ce2731f443655d6c`.

## August 25 json-as production semantic closeout

After the liveness and encoded-candidate validation repairs, current-source production O4z optimized and independently validated all 105 pinned `json-as` artifacts but exact no-cache execution initially passed only 9. The first shared out-of-bounds family was reduced on `naive/bool`: the 57-slot main pipeline and original SimplifyLocals fixed point were runtime-safe, while the scalar cleanup's plain `precompute` step failed. Hybridization across 119 changed bodies isolated absolute function 513. An immutable selector fold forced HOT lowering across a stack-carried scratch overwrite/call lifetime, moving an old local read after its overwrite and dropping a continuation-observed tee write. The existing stack-carried-overwritten-local proof now guards plain `precompute` as well as propagating Precompute.

That repair raised exact runtime from 9/105 to 87/105. The remaining failures were exactly `array`, `date`, `fast-path-deserialize`, `map`, `struct`, and `whitespace` in naive, SWAR, and SIMD modes. `naive/array` stayed correct through the scalar cleanup and failed in post-selection `coalesce-locals`; hybridization across 670 changed bodies isolated absolute function 1244. Coalescing a body scratch into parameter 1's slot destroyed a still-live parameter entry value while an older scratch value remained stack-carried into the same later call. Ordinary CoalesceLocals now fails closed on the established stack-carried-overwritten-local/call family.

Final native SHA-256 `797cb22884706dd376ed142eb7620813481e01e9cf5f85c464e5db2210b96e91` produces `105/105` successful O4z outputs, `105/105` independent `wasm-tools validate --features all` results, and `105/105` exact four-worker no-cache `as-test` executions with zero failures or timeouts. Aggregate output is `26,228,860` bytes from `29,604,717` input bytes. Evidence and function-level hybrids remain under `.tmp/json-as-smoke-20260824/corruption-bisect/`, with final summaries in `native-o4z-results.json` and `native-o4z-exact-results.json`.

## August 25 self-optimized OptimizeInstructions closeout

The first current-source self-optimized artifact built after the `json-as` semantic closeout validated and passed `--help`, `--version`, and the bounded spec path, but trapped out of bounds when asked to optimize pinned `naive/bool`. The release-WASI optimizer remained byte-identical to native on the same command, proving self-optimization introduced the capability failure. Native prefix bisection placed the first bad self artifact at main prefix 36 `optimize-instructions` after runtime-capable prefix 35; hybridization across 464 changed bodies isolated absolute function 6695.

Function 6695 carried several loaded values across same-base release calls and later consumed them after intervening control/effects. The raw indexed effect fact did not recognize the flat `local.get base; load; local.get base; call` relation, so a separate valid OI mutation forced HOT lowering. Lowering moved the loads after those effectful calls and also moved five release calls before a call that still consumed the released values. The original-body `run_hot_pipeline_raw_has_load_before_same_local_call` proof now short-circuits OptimizeInstructions before descriptor bridges and HOT lift, retaining the established `stack-carried-effect-optimize-instructions-noop` reason.

Rebuilt debug/release/self-optimized artifacts are `14,554,482`, `5,366,122`, and `4,857,390` bytes. The final self artifact SHA-256 is `1b624ca31e5dcc3f5b9f4ab48be6db89c94f5ae674ec3c63c87c333446c082f7`; it validates, exits zero for `--help`, `--version`, and `spec tests/spec/address.wast`, optimizes pinned `naive/bool`, emits bytes identical to native O4z, and the emitted module passes exact WASI startup. Bisection and direct-binary evidence is under `.tmp/self-optimized-cli-bool-bisect-20260825/` and `.tmp/direct-binary-smoke/current-self-oi-fixed/`.

## Current TDD guard

- [`../../../scripts/lib/o4z-debug-startup-map.test.ts`](../../../scripts/lib/o4z-debug-startup-map.test.ts) is the permanent reduced-fixture guard.
- [`../../../tests/repros/o4z-debug-startup-map-init-repro.wasm`](../../../tests/repros/o4z-debug-startup-map-init-repro.wasm) is the current reproduction.
- The first assertion prints the WAT and rejects the stale allocator-root shape if `malloc` ever reintroduces `i32.const 0` immediately before `global.get 0` at the `removeBlock` call site.
- The second assertion replays the fixture through `runWasmStart(..., args: ["--help"])` and expects a zero exit code.

## August 25 broad WAGO semantic audit method

Validation is now paired with a process-isolated semantic lane over the same 842 externally valid WAGO inputs. For every successful output the audit records independent `wasm-tools validate --features all`, import/export API shape, native/self hashes, and byte identity. For every module V8 can compile, a fresh child process compares original/native/self instantiation and every exported function under five bounded typed argument vectors. Each variant receives deterministic type-compatible imports; each probe records repeated result-or-trap outcomes, import-call traces, exported memory hashes, globals, and table state. Child process groups enforce hard liveness bounds. Baseline timeouts, candidate-only timeouts, unsupported JS signatures, runtime-feature blocks, trap-detail drift, API drift, and core observable mismatches remain separate classes.

The first full native run covered all 842 valid inputs: 810 optimized and independently validated under the 30-second bound, with 2,275 semantic probes and 10,290 invocation vectors. It exposed validating wrong code in Flatten (`1793a`, fixture Fibonacci), feature-floor expansion in LocalSubtyping and GlobalRefining, and trap deletion in SimplifyGlobalsOptimizing (`issue-13034`). Those families now have direct regressions and targeted replay. The completed full rerun used native SHA-256 `6c6da9cc5334ba824e073e18013388670e9eca0ae6bd02cf70b5cc75a3bbe852`. Current native SHA-256 `797cb22884706dd376ed142eb7620813481e01e9cf5f85c464e5db2210b96e91` retains the `json-as` gate at 105/105 optimization, validation, and exact runtime; current self SHA-256 `1b624ca31e5dcc3f5b9f4ab48be6db89c94f5ae674ec3c63c87c333446c082f7` passes the exact 48-module/323-call WAGO manifest lane with 48/48 byte identity. A final full 842-input rerun on the current hashes remains pending; self-hosted optimization of fuzzcases `1793b` and `1793d` still exceeds a killable 120-second bound.

Evidence is preserved under `.tmp/wago-o4z-native-semantic-20260825/`, `.tmp/wago-o4z-native-semantic-core-replay4-20260825/`, `.tmp/wago-o4z-corruption-audit-20260825/`, and `.tmp/wago-o4z-functional-20260825-corruption-repairs/`.

## How to use this page

1. Keep this investigation separate from the path-handling audit in [`cli-startup-path.md`](./cli-startup-path.md).
2. Check the debug-artifact generation path before changing optimizer passes if this guard ever regresses.
3. Use the raw research note for the exact reduced-fixture guard, scratch instrumentation, and historical owner hypothesis.
4. If the guard fails again, repair the artifact/fixture path first, then retry the full self/debug `-O4z` startup path and spec smoke.
5. If the host message still says `RuntimeError: unreachable`, classify it as a wasm trap first and use the trap site plus surrounding execution path to distinguish artifact corruption from a live optimizer regression.

## Sources

- Archived research note: [research note 0693](../binaryen/passes/late-pipeline-dispatch.md)
- Runtime-trap semantics guide: [`../validate/runtime-trap-semantics.md`](../validate/runtime-trap-semantics.md)
- Build pipeline: [`../../../scripts/lib/build-self-optimized.mjs`](../../../scripts/lib/build-self-optimized.mjs)
- Artifact-path helper: [`../../../scripts/lib/self-optimized-artifacts.mjs`](../../../scripts/lib/self-optimized-artifacts.mjs)
- Active reduced guard: [`../../../scripts/lib/o4z-debug-startup-map.test.ts`](../../../scripts/lib/o4z-debug-startup-map.test.ts)
- Reduced repro: [`../../../tests/repros/o4z-debug-startup-map-init-repro.wasm`](../../../tests/repros/o4z-debug-startup-map-init-repro.wasm)
- WASI runner / Preview boundary: [`wasi-runner-and-preview-boundary.md`](wasi-runner-and-preview-boundary.md), [Node `node:wasi` documentation](https://nodejs.org/api/wasi.html)
- Related audit: [`./cli-startup-path.md`](./cli-startup-path.md)
