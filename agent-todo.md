# Agent Tasks

## Scope And Rules

- Keep only active unreleased work or explicitly deferred future work. Durable closeout evidence belongs in the pass dossiers and `docs/wiki/log.md`, not here.
- Binaryen `version_131` O4z means `wasm-opt --all-features -O4 --shrink-level 4` and retains the 56-slot / 38-owner top-level scheduler audited in `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`.
- Bare `wasm-opt` currently resolves to TinyGo's Binaryen `version_116`. Every v131 compare or self-opt command must pass an official verified v131 binary with `--wasm-opt-bin` and record `wasm-opt version 131 (version_131)`.
- Direct pass behavior comes before ordered-neighborhood proof; preset scheduling comes last.
- Behavior parity is the target. Every remaining difference must be source-backed, measured, classified, and covered by reopening criteria.
- A pass closes only after source/test breadth, pass-specific generation, validity, performance, and the required four-lane matrix are complete.
- Build the native CLI before compare lanes and use `_build/native/release/build/cmd/cmd.exe`; treat `target/native/...` as stale unless explicitly proven fresh.
- Moon commands must run serially.

## v0.1.1 Execution Order

1. Complete `[O4Z-PRESET]001`, then `[O4Z-NESTED]001`.
2. Run artifact, runtime, size, strip-debug, and wall-time signoff.

## Active O4z Pass Queue

The full 56-slot roster and closed-pass evidence live in `docs/wiki/binaryen/passes/late-pipeline-dispatch.md` and the pass dossiers. This table lists only owners with active v0.1.1 work.

| Pass | Active work | Owner |
| --- | --- | --- |
| `merge-blocks` / branch cleanup | Direct represented-surface behavior is closed; reconcile size-losing post-`code-folding` ordered shapes. | `[O4Z-PRESET]001` |

## v0.1.1 Primary O4z Work

### [O4Z-PRESET]001 - Reconcile the exact 56-slot public preset

- **Status:** all direct pass owners are closed; exact scheduler and ordered-neighborhood reconciliation are active.
- **Goal:** make Starshine's `shrink`/O4z expansion intentionally match the unchanged Binaryen-v131 56-slot top-level order, with documented Starshine-only extensions.
- **Current differences:**
  - [x] Add the second early `remove-unused-module-elements` slot after `global-struct-inference`; optimize/shrink registry tests now assert all three RUME positions (2026-07-27).
  - [x] Remove the redundant adjacent early `remove-unused-brs` slot. Optimize/shrink now match Binaryen v131's 56-slot roster with RUB at indices `13`, `24`, and `39`; final `strip-debug` remains the documented Starshine-only 57th slot (2026-07-30).
  - [ ] Land the resolved `local-subtyping -> coalesce-locals -> local-cse` suffix; direct owner evidence is closed and no longer blocks preset work.
  - [ ] Reconcile post-`code-folding` ordered cleanup shapes: return/tail-call and movement fixtures are measured smaller Starshine `br_if` forms, while block-exit and EH fixtures remain size-losing neighboring cleanup gaps.
  - [ ] Triage the full-preset validity blocker exposed by the expanded RUB corpus: the first `1000` inputs produce `837` valid `-O4z` outputs and `163` Starshine command failures. Tracing the first failure shows `flatten` creates the stack-underflow state before RUB; isolated direct RUB at O4z levels `4/4` is valid and no-larger for all `10000` cases.
  - [ ] Keep final `strip-debug` explicitly documented as a Starshine extension outside Binaryen's 56 slots.
  - [ ] Preserve feature gates, no-DWARF policy, repeated cleanup slots, canonical aliases, and exact-order tests.
- **Already landed and removed from this active list:** the second early RUME slot, the aggressive flatten/SLNNS/local-CSE prelude, both `precompute-propagate` substitutions, `merge-locals` after `heap2local`, `code-folding` before late `merge-blocks`, removal of the noncanonical early `vacuum`, and the late `heap-store-optimization -> redundant-set-elimination -> vacuum` sequence.
- **Exit criteria:** exact expansion tests, independently signed direct owners, and an ordered generated-artifact/runtime/size comparison with no unclassified regression.

### [O4Z-NESTED]001 - Reconcile optimizing nested reruns

- **Status:** DAE and inlining share the current helper; neutral ownership, SGO routing, and final proof remain open.
- **Goal:** use one truthful, touched-function-filtered representation of the final O4z function pipeline for DAE, inlining, and SGO nested cleanup.
- **Deliverables:**
  - [ ] Promote the existing inlining-named helper into a neutral tested function-pipeline expansion API parameterized by O4z levels, feature gates, and whether `precompute-propagate` is prepended.
  - [ ] Preserve current DAE/inlining behavior while routing SGO through the same API without semantic forks.
  - [ ] Preserve touched-function filtering; do not mutate unrelated functions.
  - [ ] Replace broad large-module or tail-call bypasses only with focused safe guards or repaired owners.
  - [ ] Add exact nested-order tests and pass-specific runtime/artifact evidence.
- **Dependencies:** `[O4Z-PRESET]001`.
- **Exit criteria:** DAE, inlining, and SGO nested traces match the intended roster and remain valid, runtime-green, and within accepted pass-local performance bounds.

## v0.1.1 O4z Supporting Work

### [O4Z-STARTUP]001 - Preserve the startup-map regression guard

- Keep `tests/repros/o4z-debug-startup-map-init-repro.wasm` until a smaller generated-artifact fixture replaces it.
- Recover precision one owner at a time only with focused tests and runtime evidence: nested SSA liveness, safe commutative ordering, tee-aware local sinking, path-sensitive local coalescing, and branchy vacuum cleanup.
- Source: `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`.

### [JSON-AS]001 - Repeatable artifact correctness and size signoff

- **Goal:** keep a pinned opt-in `json-as` replay that builds debug artifacts, validates Starshine/Binaryen outputs, executes runtime suites, and records section/function/type/code/custom-section deltas.
- **Deliverables:**
  - [ ] Add a documented opt-in clone/build/replay task under existing Bun tooling; do not add shell scripts under `scripts/`.
  - [ ] Re-measure final `strip-debug` custom-section wins.
  - [ ] Measure each newly scheduled O4z pass/neighborhood on medium-naive, medium-simd, and large-swar artifacts.
  - [ ] Keep validation and runtime execution separate; validation alone previously missed corruption.
  - [ ] Prefer `d8` when available; otherwise retain a checked-in-equivalent Node/WASI smoke path.
- **Exit criteria:** the final preset has repeatable validation, runtime, and component-size evidence on all three artifacts.

### [WALL]001 - Cross-pass wall-time attribution

- Separate pass-local time from decode, validation, HOT lift/lower, parse/emit, buffering, caching, and process startup.
- Keep aggregate wall time outside direct pass correctness closeout unless a pass is clearly the owner.
- Current targets are self-optimization command overhead, repeated HOT lifting, validation/encoding, and the widened exact O4z preset.

### [TOOL]001 - Self-opt compare normalization symmetry

- Canonicalize equivalent Binaryen/Starshine artifact paths symmetrically or ignore only proven transparent unused-label void wrappers.
- Preserve raw artifacts; do not hide semantic, size-losing, or validation differences behind normalization.

### [STRIP-DEBUG]001 - Artifact measurement

- Direct pass behavior and final extension placement are complete.
- Re-measure debug-artifact custom-section size, validation, and runtime effects after the final O4z scheduler lands.

## v0.1.1 Optimizer Follow-ups

### [SSA-FULL]001 - Complete public full `ssa`

- **Priority:** not an O4z blocker; O4z uses `ssa-nomerge`.
- **Active work:** simple explicit-write merge locals; parameter/default entry inputs and prepend ordering; loop/branch/EH/typed-control classification; harness admission; dedicated profile; direct closeout.
- **Exit criteria:** the public pass is admitted, source/test-audited, covered by a dedicated profile, and green on the required four-lane matrix.

### [AUDIT]006 - Function `TypeIdx` / `RecIdx` invariant documentation

- Finish wiki, inline, and test documentation that function-section references are global `TypeIdx`, while `RecIdx` is rec-group-local and impossible in validated function-section positions.

### [SGO]003-[SGO]005 - Deferred SGO improvements

- Add optional breadth only after a new semantic or artifact need.
- Run nested-cleanup experiments only with measured ownership.
- Treat default-local compare normalization as tooling/cosmetic work, not a direct SGO correctness blocker.

## v0.2.0 Or Later Work

### [V02-INL]001 - Ship the Binaryen-v131 inlining-family expansion

- **Status:** implementation is retained locally; publication is deferred to v0.2.0 or later.
- **Scope:** plain `inlining`, `inlining-optimizing`, active `inline-main`, `no-inline*` policy, toolchain hints, six configuration controls, represented trivial-instruction policy, Pattern A/B splitting, EH-safe tail handling, roots, metadata repair, and touched nested cleanup.
- **Release gate:** after unrelated work and `[O4Z-NESTED]001` settle, regenerate interfaces, run README/API sync, focused suites, the full repository suite, both explicit-v131 10,000-case lanes, and the repository-wide validation gate.

### Shared-Everything Threads

Keep the dependency order; detailed proposal rules live in the Shared-Everything wiki pages.

1. Model proposal entities, heap/reference types, limits/flags, rec groups, shared descriptors, and annotations.
2. Decode/encode proposal bytes with contextual legality checks and round-trip tests.
3. Validate shared/unshared domains, type graphs, subtyping/LUB/GLB, rec groups, memory/table/global/tag rules, and proposal opcodes.
4. Link/import/export proposal entities and type graphs without index or ownership corruption.
5. Extend optimizer harness protocol, feature flags, semantic hashing, and compare/fuzz normalization.
6. Extend generators and shrinkers with high-yield proposal cases.
7. Preserve proposal structures through HOT lift/lower with provenance and correct failure boundaries.
8. Expose CLI flags, update docs, and run focused plus full proposal signoff.

### [INL]020-[INL]021 - Optional future inlining breadth

- Revisit tiny hot-path struct/array allocation inlining only with measured canonical-size and wall-time wins.
- Keep table/indirect-call callee recovery deferred; v131's direct-call planner and copied-body indirect/ref-call handling are complete.
- Keep expression-level code metadata, branch hints, source maps, and copied-callee debug-name synthesis under shared metadata-substrate work.

### [HOT]001-[HOT]004 - Deferred structural improvements

- Replace exact-expression span identity with stronger source provenance where needed.
- Preserve unknown/custom metadata through HOT round trips.
- Reduce opaque fallback lowering without sacrificing correctness.
- Keep O4z startup-map local/tee/loop repair under `[O4Z-STARTUP]001` rather than opening unrelated HOT rewrites.

### [FUZZ]001 - Continuous parity triage

- Keep no permanent active bug entry while all maintained suites are green.
- On a new mismatch, save the seed/artifacts, minimize it, classify it, add the focused regression first, repair the owning pass/harness/codec, and archive the durable result in the relevant dossier.

## Backlog Hygiene

- Remove a slice when its exit criteria are met; do not retain completed checkbox diaries.
- Move durable closeout evidence to the pass dossier or `docs/wiki/log.md`.
- Add active slices only with a concrete owner, goal, reason, deliverables, dependencies, exit criteria, and suggested tests where implementation is expected.
- Keep release blockers and known failures visible until resolved.
