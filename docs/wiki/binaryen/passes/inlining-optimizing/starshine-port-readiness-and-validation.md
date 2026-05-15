---
kind: concept
status: working
last_reviewed: 2026-05-14
sources:
  - ../../../raw/research/0557-2026-05-12-inlining-wiki-overhaul.md
  - ../../../raw/binaryen/2026-04-25-inlining-optimizing-current-main-implementation-test-map.md
  - ../../../../../src/passes/inlining.mbt
  - ../../../../../src/passes/inlining_test.mbt
  - ../../../../../agent-todo.md
  - ../../../../../CHANGELOG.md
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./implementation-structure-and-tests.md
  - ./planning-partial-inlining-and-reruns.md
  - ../inlining/starshine-port-readiness-and-validation.md
---

# Starshine Port Readiness And Validation For `inlining-optimizing`

## Current status in one sentence

Starshine's `inlining-optimizing` is an active partial module pass whose standard seed-`0x5eed` and broadened seed-`0x1eed` direct lanes are green over compared cases; remaining ignored failures are Binaryen/tool parse failures, not Starshine semantic failures.

## Latest evidence

Standard direct lane now green:

```text
Artifact: .tmp/pass-fuzz-inlining-seed-0x5eed-after-four-func-frontier
Pass: inlining-optimizing
Seed: 0x5eed
Compared: 9975 / 10000
Normalized matches: 9975
Normalized mismatches: 0
Validation failures: 0
Generator failures: 0
Ignored Binaryen/tool command failures: 25
```

Seed-`0x5eed` command-failure breakdown:

- `22` `binaryen-rec-group-zero`;
- `1` `binaryen-bad-section-size`;
- `1` `binaryen-table-index-out-of-range`;
- `1` `binaryen-invalid-tag-index`.

Broadened closure lane is green:

```text
Artifact: .tmp/pass-fuzz-inlining-seed-0x1eed-after-four-func-frontier2
Pass: inlining-optimizing
Seed: 0x1eed
Compared: 9978 / 10000
Normalized matches: 9978
Normalized mismatches: 0
Validation failures: 0
Generator failures: 0
Ignored Binaryen/tool command failures: 22
```

Seed-`0x1eed` command-failure breakdown:

- `22` ignored Binaryen/tool `binaryen-rec-group-zero` parse failures;
- `0` Starshine command failures; `case-008100-gen-valid` replays green in `.tmp/pass-fuzz-inlining-seed-0x1eed-replay-case008100-narrow-hotunsafe`.

Classification rule: Binaryen parse/canonicalization failures are ignored oracle/tool failures, not Starshine semantic failures. The former Starshine command failure and broadened normalized mismatch set are fixed.


`[INL]002` nested-scheduler closeout fuzz is green over compared cases:

```text
Artifact: .tmp/pass-fuzz-inlining-optimizing-inl002-closeout-10000-keep
Pass: inlining-optimizing
Compared: 9975 / 10000
Normalized matches: 9975
Normalized mismatches: 0
Validation failures: 0
Ignored Binaryen/tool command failures: 25
```

Debug-artifact direct replay is not green yet: `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --out-dir .tmp/self-opt-inlining-optimizing-inl002-closeout --starshine-bin _build/native/release/build/cmd/cmd.exe --inlining-optimizing` fails because the Starshine command aborts with exit `134` while tracing nested `precompute-propagate-prefix` over the live artifact. A direct repro is `_build/native/release/build/cmd/cmd.exe --inlining-optimizing --out .tmp/inl002-direct-debug-artifact/starshine.raw.wasm tests/node/dist/starshine-debug-wasi.wasm`; the traced repro last reached nested `precompute-propagate-prefix` on `Func 3700` before aborting.

## What is already validated locally

Focused tests validate the current subset:

- registry activation for both public names;
- direct tiny helper inlining/removal;
- parameter remapping;
- exported-helper survival;
- narrow direct `return_call` inlining;
- self-recursion skip;
- iterative wave behavior;
- the accepted `[INL]003` heuristic/action-filtering surface for repeated two-parameter binary, ordered direct-call, three-parameter `select`, parameter-passthrough memory/table/SIMD/GC operation wrappers, the first optimize-level-three/no-shrink flexible no-direct-call/no-loop policy, combined-size filtering, and repeated-work caps;
- unreachable private cycle cleanup/retention families;
- no-inlining unreachable value-block pruning and predicted exact-helper padding;
- narrow hot-unsafe polymorphic self-call suffix detector coverage;
- optimizing nested-cleanup trace marker and explicit first nested-pass trace for `precompute-propagate-prefix`;
- absence of the old post-prefix `pipeline:start requested=29` whole-module cleanup batch in the nested trace;
- traced default-function prelude alignment: the private prefix is followed by `dead-code-elimination` at O0 rather than an extra pre-default `precompute`;
- traced option gating: the default O0 nested lane omits `ssa-nomerge`, `pick-load-signs`, `code-pushing`, `heap2local`, `merge-locals`, `optimize-casts`, `local-subtyping`, `local-cse`, `code-folding`, and `redundant-set-elimination`, while O3 still includes `ssa-nomerge`;
- traced early cleanup order through `dead-code-elimination -> remove-unused-names -> remove-unused-brs -> remove-unused-names -> vacuum`;
- traced O3 nested cleanup order through `heap2local -> merge-locals -> optimize-casts`;
- traced nested local cleanup order through `simplify-locals-nostructure -> vacuum -> reorder-locals -> remove-unused-brs`;
- traced late cleanup order through `simplify-locals -> code-folding -> merge-blocks`;
- traced full late local cleanup cluster through `simplify-locals -> vacuum -> reorder-locals -> coalesce-locals -> reorder-locals -> vacuum -> code-folding`;
- traced O2 final cleanup tail through `heap-store-optimization -> redundant-set-elimination -> vacuum`;
- traced final cleanup tail ending with `heap-store-optimization -> vacuum` when the RSE option gate is inactive;
- touched-caller/default-init local folding through the private prefix while an untouched sibling remains body-shape unchanged.

## Active blockers

### Deferred direct-inliner breadth after accepted `[INL]001` / `[INL]007`

- `[INL]003` accepted current-supported heuristic/action-filtering surface on 2026-05-14 after the repeated-work cap closeout; reopen only for a new Starshine-supported semantic mismatch in heuristic/action filtering;
- `[INL]004` accepted current `no-inline*` policy surface; initial name-section/WAT-identifier wildcard marking, full-inline suppression, inlining-compaction annotation/function-name remap, stale local-name dropping, and shared clone/copy policy helper are implemented;
- `[INL]005` Pattern A / Pattern B partial splitting;
- `[INL]006` nested tail-call, multi-result, and name/annotation repair.

### `[INL]002` scheduler blockers

- optimizing mode currently approximates nested cleanup;
- the former seed-`0x1eed` `case-008100-gen-valid` command failure is fixed by a narrow hot-unsafe helper guard;
- a private touched-only `precompute-propagate-prefix` now runs before the cleanup lane, but the real public `precompute-propagate` sibling is still unavailable;
- the remaining cleanup lane is touched-filtered and drops the former extra pre-default `precompute`; it includes option gates for `ssa-nomerge`, `pick-load-signs`, `code-pushing`, `heap2local`, `optimize-casts`, `local-subtyping`, `local-cse`, `code-folding`, `merge-locals`, and `redundant-set-elimination`, plus the early second `remove-unused-names`, local `reorder-locals`, late local cleanup cluster, and final `vacuum` after late `heap-store-optimization`, but it is still Starshine's approximation rather than a proven exact Binaryen default pipeline expansion;
- debug-artifact direct replay currently aborts natively during nested `precompute-propagate-prefix` (`exit=134`, last traced `Func 3700`), so `[INL]002` cannot be closed on fuzz evidence alone;
- no artifact proof that only Binaryen's touched functions see exactly the same default-pipeline effects after the prefix;
- no ordered late-tail artifact parity.

## Validation ladder

1. Keep focused Moon tests for each reduced mismatch before implementation changes.
2. Retire or classify the broadened seed-`0x1eed` mismatches in `.tmp/pass-fuzz-inlining-seed-0x1eed-after-four-func-frontier2`, plus any still-useful older saved mismatch dirs.
3. Run direct `--pass inlining-optimizing` 10k compare with zero semantic mismatches on the standard lane and at least one broadened seed lane.
4. Fix the current debug-artifact `--inlining-optimizing` native abort, then rerun `self-optimize-compare` on `tests/node/dist/starshine-debug-wasi.wasm` before claiming `[INL]002` closeout.
5. Keep direct `--pass inlining` evidence separate when future plain work changes; `[INL]007` is accepted for the current surface.
6. Add scheduler tests for touched-only nested cleanup.
7. Replay `dae-optimizing -> inlining-optimizing -> duplicate-function-elimination` neighborhood after direct parity.
8. Only then consider public preset placement.

## Acceptance criteria

Treat `[INL]001` and `[INL]007` as complete only for the currently implemented direct-call surfaces already proven by the green seed lanes. New direct-inliner work should land under `[INL]005` or `[INL]006` unless a new Starshine-supported heuristic/action-filtering semantic mismatch justifies reopening `[INL]003`; do not reopen accepted direct slices without a new semantic mismatch.

Do not mark `[INL]002` complete until:

- the nested cleanup starts with the real `precompute-propagate` equivalent rather than only the current private prefix approximation;
- the default function pipeline expansion matches Binaryen's option-specific order and runs only on Binaryen's touched set;
- untouched functions are proven unchanged by the full nested scheduler, including module-shaped local cleanup adapters;
- focused trace/scheduler tests and direct compare evidence agree.

## Unresolved uncertainty

- The current exact-`unreachable` predictor is artifact-driven and may need refactoring after broader helper deletion and exact scheduler behavior land.
- The current local representation for Binaryen no-inline flags uses internal function annotations and remaps them with function compaction; function names are also remapped for later policy matching, while local/label names are dropped after inlining rewrites until full repair exists. Future clone/copy transforms should call `no_inline_copy_policy_annotations(...)`; partial-inlining-specific official no-inline shapes move with `[INL]005`.
- The best shared scheduler abstraction for DAE/INL/SGO remains open; avoid building three incompatible nested runners.
