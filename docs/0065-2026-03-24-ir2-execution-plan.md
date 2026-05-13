# 0065 - IR2 Execution Plan

## Scope

- Keep one canonical handoff document for the rebuilt IR2 optimizer leg.
- Point future agents at the architecture, CFG, SSA, pass-porting, registry, and test-matrix docs that govern continued work.
- Record the current live pass surface, preset expansion, and minimum validation expected for future IR2 changes.

## Canonical References

- Architecture rules: [`0059-2026-03-24-ir2-architecture-rules.md`](./0059-2026-03-24-ir2-architecture-rules.md)
- CFG contract ADR: [`0060-2026-03-24-cfg-contract-and-block-boundary-rules.md`](./0060-2026-03-24-cfg-contract-and-block-boundary-rules.md)
- SSA policy ADR: [`0061-2026-03-24-local-ssa-policy.md`](./0061-2026-03-24-local-ssa-policy.md)
- Pass-porting checklist: [`0062-2026-03-24-pass-porting-checklist.md`](./0062-2026-03-24-pass-porting-checklist.md)
- Registry and batch map: [`0063-2026-03-24-pass-port-batches-and-registry-map.md`](./0063-2026-03-24-pass-port-batches-and-registry-map.md)
- Shared IR2 test matrix: [`0064-2026-03-24-ir2-test-matrix.md`](./0064-2026-03-24-ir2-test-matrix.md)

## Current State

- `HotFunc` is the only owned optimizer body representation.
- CFG, traversal orders, dominance, post-dominance, loop info, use-def, liveness, effects, and local SSA exist as revision-keyed overlays.
- The public optimizer runner expands requested hot passes, module passes, and presets, then executes them through the real pipeline:
  `lift -> verify -> analyze -> mutate -> verify -> lower -> validate`.
- Pipeline perf instrumentation exists for opt-in timings, counters, checkpoints, and lightweight dumps.
- Legacy pass names remain categorized as `boundary-only` or `removed` for diagnostics, but they are not accepted as silent no-ops.
- CLI tooling and the fuzz harness use real pass-name arrays; the deleted `ModulePass` compatibility shim is gone.
- `agent-todo.md` is active-only backlog. If future IR2 work resumes, add the next slice id there before landing behavior changes.

## Current Active Surface

### Active hot passes

`ssa-nomerge`, `vacuum`, `dead-code-elimination`, `remove-unused-names`, `remove-unused-brs`, `optimize-instructions`, `heap-store-optimization`, `heap2local`, `optimize-casts`, `pick-load-signs`, `precompute`, `code-pushing`, `code-folding`, `tuple-optimization`, `simplify-locals`, `simplify-locals-nostructure`, `simplify-locals-no-structure`, `simplify-locals-notee-nostructure`, `merge-blocks`, and `redundant-set-elimination`.

### Active module passes

`local-cse`, `merge-locals`, `avoid-reinterprets`, `untee`, `duplicate-function-elimination`, `remove-unused-module-elements`, `remove-unused-nonfunction-module-elements`, `memory-packing`, `once-reduction`, `global-refining`, `global-struct-inference`, `reorder-locals`, `local-subtyping`, `coalesce-locals`, `duplicate-import-elimination`, `dae-optimizing`, `dead-argument-elimination-optimizing`, `string-gathering`, `reorder-globals`, and `directize`.

### Active presets

`optimize` and `shrink` currently expand to the same implemented module + hot sequence:

```text
memory-packing -> once-reduction -> global-refining -> global-struct-inference ->
ssa-nomerge -> dead-code-elimination -> remove-unused-names -> remove-unused-brs ->
remove-unused-names -> vacuum -> remove-unused-brs -> optimize-instructions ->
heap-store-optimization -> pick-load-signs -> precompute -> code-pushing ->
tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals ->
remove-unused-brs -> heap2local -> optimize-casts -> local-subtyping ->
coalesce-locals -> local-cse -> simplify-locals -> merge-blocks ->
remove-unused-brs -> remove-unused-names -> merge-blocks -> precompute ->
optimize-instructions -> heap-store-optimization
```

The sequence is intentionally conservative about incomplete neighborhoods: `simplify-locals-notee-nostructure` is runnable explicitly, but omitted from presets until its exact `flatten -> simplify-locals-notee-nostructure -> local-cse` neighborhood is available.

## Current Migration Gaps

The original March Batch 1/2/3 labels are now partly historical. Use the live registry first, then the original batch map only as context.

- Remaining removed hot/local names: `const-hoisting`, `dataflow-optimization`, `loop-invariant-code-motion`, `flatten`, `re-reloop`, `optimize-added-constants`, `optimize-added-constants-propagate`, `precompute-propagate`, `de-nan`, `simplify-locals-no-tee`, `simplify-locals-no-tee-no-structure`, and `simplify-locals-no-nesting`.
- Boundary-only module/type/ABI names need dedicated module/type rewrite contracts before they can be treated as active pass-port slices.
- The highest-confidence next step before any remaining port is source reconciliation: update the affected pass folder, registry map, active backlog slice, tests, and preset policy together.

## Future Slice Order Guidance

1. If a pass needs a new IR rule or overlay contract, land that contract/ADR update first in `docs/`, then add the slice to `agent-todo.md`.
2. If a removed pass is revived, start with the smallest runnable explicit-pass slice and keep it out of presets until its neighboring Binaryen slot is source-confirmed and fuzz/signoff evidence is recorded.
3. If a boundary-only pass is revived, design the module/type/ABI mutation contract before implementing rewrites; do not force it into a single-function hot-pass shape just to fit the old batch map.
4. Keep one atomic slice per coherent dependency step; do not mix architecture contracts, pass ports, preset scheduling, and follow-up cleanup unless the dependency is inseparable.

## Minimum Validation Per Slice

- Write or adjust the failing test first.
- Run the narrowest relevant package tests while iterating.
- Before commit for behavior or API changes, run:
  - `moon info`
  - `moon fmt`
  - `bun validate readme-api-sync`
  - `moon test`
- Review `pkg.generated.mbti` diffs whenever the public API changes.
- Update `CHANGELOG.md` first for every commit.
- Keep `agent-todo.md` unreleased-only and remove finished slices before commit.

## Handoff Rules

- Add new research/ADR docs with the next zero-padded serial and the commit date in the filename.
- Keep `agent-lost-and-found.md` local-only and uncommitted.
- Keep public docs conservative: help text, README notes, and registry docs must describe only real current behavior.
- Extend the shared fixture/golden layer in [`0064-2026-03-24-ir2-test-matrix.md`](./0064-2026-03-24-ir2-test-matrix.md) instead of inventing ad hoc one-off IR2 test harnesses.

## Open Questions

- When `optimize` and `shrink` should materially diverge.
- Whether module-shaped active passes should become more visible in help output or stay primarily discoverable through registry/fuzz tooling.
- Which remaining removed names are worth reviving versus leaving as explicit diagnostic-only registry entries.
