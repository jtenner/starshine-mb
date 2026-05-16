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

Debug-artifact direct replay is now non-aborting and no longer has the previous local-bloat size gap. The first non-aborting replay at `.tmp/inl002-direct-debug-artifact-current-20260515-184415` produced a valid `3.5M` raw wasm, but function-level WAT ranking showed huge local-declaration/coalescing drift in aligned large functions and in the start/export functions. A validation-guarded final raw vacuum preclean plus `coalesce-locals -> reorder-locals` and type-section compaction cleanup for optimizing mode reduces the direct artifact in `.tmp/inl002-final-raw-preclean-20260515-204256` to about `1.7M` raw wasm; follow-up raw preclean support for dropped local/global reads, stacked pure-drop clusters, and direct nonfallthrough dead tails validates at `.tmp/inl002-deadtail-preclean-20260515-220109` and narrows the former `S2356->B2289` aligned WAT delta to about `116K`. A subsequent skipped-raw-`simplify-locals` pure-suffix cleanup replay validates at `.tmp/inl002-puresuffix-only-20260516-002821`, reducing the top aligned Starshine-larger WAT delta to about `25K` and `skip_bytes` to `585064`. `wasm-tools validate` accepts these outputs. Binaryen direct `--inlining-optimizing` remains about `2.2M`.

`[INL]002` is accepted as of 2026-05-16 on correctness grounds rather than exact byte/WAT parity. Canonical wasm/WAT still differ: the latest replay prints about `35M` Starshine WAT vs `134M` Binaryen WAT, Starshine's wasm is about `1.7M` vs Binaryen's about `2.2M`, `wasm-tools objdump` reports Starshine's code section at `1,560,895` bytes vs Binaryen's `2,106,285`, and `wasm-opt --all-features --metrics` reports `762,965` total Starshine nodes vs `977,216` Binaryen nodes. Targeted mismatch triage found no wasm validation error, no exported/start/table/ref.func semantic discrepancy, and no meaning-changing evidence: the top Starshine-larger aligned examples are local/control representation drift, the large Binaryen-larger examples are Binaryen expansion/factoring drift, and the remaining 119 Starshine-only skipped functions are mostly referenced helper factoring with 12 unreferenced cleanup candidates. A 200-case smoke at `.tmp/pass-fuzz-inlining-optimizing-inl002-puresuffix-200` preserved the known local-declaration/frontier mismatch shape with `0` validation failures. Exact Binaryen canonical artifact shape is therefore not a v0.1.0 `[INL]002` blocker. Wall-time remains deferred to `[WALL]001` unless a pass-local correctness issue is identified.

## What is already validated locally

Focused tests validate the current subset:

- registry activation for both public names;
- direct tiny helper inlining/removal;
- parameter remapping;
- exported-helper survival;
- narrow direct `return_call` inlining plus the `[INL]006` nested direct-`return_call` tail-call subset, focused nested `return_call_indirect` and `return_call_ref` tail preservation, direct `return_call` in `try_table`, and a focused non-tail guard;
- typed multi-result helper inlining through type-indexed wrapper blocks, including no-param callees, parameterized callees with a reusable zero-param result type, and otherwise-inlineable parameterized callees that need a synthesized zero-param result type;
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
- touched-caller/default-init local folding through the private prefix while an untouched sibling remains body-shape unchanged;
- final optimizing-mode local cleanup coalesces artifact-like local chains, removes `nop`, const/ref/string/local/global drop debris plus direct raw dead tails, drops unused function types, and validates the candidate before accepting it;
- skipped large raw `simplify-locals` paths still run the proven pure-suffix local-copy cleanup before narrower carrier rewrites.

## Active blockers

### Deferred direct-inliner breadth after accepted `[INL]001` / `[INL]007`

- `[INL]003` accepted current-supported heuristic/action-filtering surface on 2026-05-14 after the repeated-work cap closeout; reopen only for a new Starshine-supported semantic mismatch in heuristic/action filtering;
- `[INL]004` accepted current `no-inline*` policy surface; initial name-section/WAT-identifier wildcard marking, full-inline suppression, inlining-compaction annotation/function-name remap, stale local-name dropping, and shared clone/copy policy helper are implemented;
- `[INL]005` Pattern A / Pattern B partial splitting;
- `[INL]006` residual local/label name repair remains intentionally scoped as unsupported after the narrow direct/indirect/ref tail, multi-result block-typing, function-name, non-function-name, and policy-annotation subsets.

### `[INL]002` accepted representation drift

- `[INL]002` is accepted for v0.1.0 as a correctness-focused nested replay slice. The scheduler remains an approximation of Binaryen's exact private `precompute-propagate` + default-function pipeline, but direct pass fuzz signoff, artifact validation, and targeted mismatch triage found no correctness or validation evidence that justifies chasing exact Binaryen byte/WAT shape.
- Remaining exact artifact differences are classified as representation/factoring drift: Binaryen often expands/inlines into larger bodies, while Starshine retains helper factoring and currently produces smaller wasm/code-section/WAT/static metrics on the debug artifact.
- Future work that has independent correctness or performance evidence should use dedicated slices: `[INL]005` for partial splitting, `[INL]006` for tail-call/multi-result/name repair, and `[WALL]001` for whole-command runtime. Do not reopen `[INL]002` for cosmetic canonical drift alone.

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

`[INL]002` is complete for v0.1.0 under the accepted representation-drift decision above. Reopen it only if new evidence shows a `--inlining-optimizing` nested replay correctness bug, wasm validation failure, exported/start/table/ref.func semantic discrepancy, or a proven pass-local performance/correctness issue in the nested scheduler itself. Do not reopen it solely because canonical wasm/WAT differs from Binaryen when both outputs validate and the difference is classified as representation/factoring drift.

## Unresolved uncertainty

- The current exact-`unreachable` predictor is artifact-driven and may need refactoring if future `[INL]005` or `[INL]006` work broadens helper deletion, multi-result inlining, or exact repair behavior.
- The current local representation for Binaryen no-inline flags uses internal function annotations and remaps them with function compaction; function names are also remapped for later policy matching, while local/label names are dropped after inlining rewrites until full repair exists. Future clone/copy transforms should call `no_inline_copy_policy_annotations(...)`; partial-inlining-specific official no-inline shapes move with `[INL]005`.
- The best shared scheduler abstraction for DAE/INL/SGO remains open; avoid building three incompatible nested runners.
