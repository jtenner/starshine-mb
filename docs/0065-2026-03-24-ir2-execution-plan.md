# 0065 - IR2 Execution Plan

## Scope

- Make one canonical handoff document for the rebuilt IR2 optimizer leg.
- Point future agents at the architecture, CFG, SSA, pass-porting, registry, and test-matrix docs that now govern continued work.
- Record the next slice order and the minimum validation required for every future IR2 change.

## Canonical References

- Architecture rules: [`0059-2026-03-24-ir2-architecture-rules.md`](./0059-2026-03-24-ir2-architecture-rules.md)
- CFG contract ADR: [`0060-2026-03-24-cfg-contract-and-block-boundary-rules.md`](./0060-2026-03-24-cfg-contract-and-block-boundary-rules.md)
- SSA policy ADR: [`0061-2026-03-24-local-ssa-policy.md`](./0061-2026-03-24-local-ssa-policy.md)
- Pass-porting checklist: [`0062-2026-03-24-pass-porting-checklist.md`](./0062-2026-03-24-pass-porting-checklist.md)
- Registry and batch map: [`0063-2026-03-24-pass-port-batches-and-registry-map.md`](./0063-2026-03-24-pass-port-batches-and-registry-map.md)
- Shared IR2 test matrix: [`0064-2026-03-24-ir2-test-matrix.md`](./0064-2026-03-24-ir2-test-matrix.md)

## Current State

- `HotFunc` is the only owned optimizer body representation.
- CFG, dominance, post-dominance, loop info, use-def, liveness, effects, and local SSA exist as revision-keyed overlays.
- The hot pass pipeline is real and public: `lift -> verify -> run passes -> verify -> lower -> validate`.
- Pipeline perf instrumentation now exists for opt-in timings, counters, checkpoints, and lightweight dumps.
- The active registry surface is still intentionally small:
  - module passes: `memory-packing`, `once-reduction`, `global-refining`, `global-struct-inference`, `duplicate-function-elimination`, `remove-unused-module-elements`
- hot passes: `ssa-nomerge`, `dead-code-elimination`, `remove-unused-names`, `remove-unused-brs`, `vacuum`, `optimize-instructions`, `heap-store-optimization`, `pick-load-signs`, `simplify-locals`
  - presets: `optimize`, `shrink`
- `optimize` and `shrink` now expand to the implemented mixed batch-1 module + hot sequence:
  `memory-packing -> once-reduction -> global-refining -> global-struct-inference -> ssa-nomerge -> dead-code-elimination -> remove-unused-names -> remove-unused-brs -> vacuum -> optimize-instructions -> heap-store-optimization -> pick-load-signs -> simplify-locals`.
- Legacy pass names remain categorized as `boundary-only` or `removed` in the registry for diagnostics, but they are not active help-surface entries.
- CLI tooling and the fuzz harness now use real pass-name arrays; the deleted `ModulePass` compatibility shim is gone.
- `agent-todo.md` is now the active-only backlog again. If future IR2 work resumes, add the next slice id there before landing code.

## Next Slice Order

- If pass migration resumes, start from the batch intent in [`0063-2026-03-24-pass-port-batches-and-registry-map.md`](./0063-2026-03-24-pass-port-batches-and-registry-map.md).
- Preferred implementation order from the current state:
  1. Batch 2 control and cleanup passes: `flatten`, `merge-blocks`, `re-reloop`, `tuple-optimization`, `redundant-set-elimination`, `optimize-casts`
  2. Batch 3 dataflow-sensitive passes: `local-subtyping`, `loop-invariant-code-motion`
- If a pass needs a new IR rule or overlay contract before implementation, land the contract/ADR update first in `docs/` and then add the new slice to `agent-todo.md`.
- Keep one atomic slice per coherent dependency step; do not mix architecture contracts, pass ports, and follow-up cleanup in one commit unless the dependency is inseparable.

## Minimum Validation Per Slice

- Write or adjust the failing test first.
- Run the narrowest relevant package tests while iterating.
- Before commit, run:
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

- When more than one real hot pass exists, whether CLI tracing levels should become materially distinct instead of remaining mostly pass-surface aliases.
- Whether future pass ports should stay one-pass-per-slice or whether some tightly-coupled passes should move in paired batches once shared rewrite helpers stabilize.
