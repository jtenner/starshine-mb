---
kind: research
status: done
last_reviewed: 2026-05-08
sources:
  - ../../../agent-todo.md
  - ../../binaryen/passes/heap2local/parity.md
  - ../../binaryen/passes/heap2local/starshine-hot-ir-strategy.md
  - ../../binaryen/passes/optimize-casts/index.md
  - ../../binaryen/passes/coalesce-locals/index.md
  - ../../../src/passes/optimize_test.mbt
  - ../../../src/passes/heap2local.mbt
  - ../../../src/validate/validate.mbt
related:
  - ../../binaryen/passes/heap2local/index.md
  - ../../binaryen/passes/heap2local/parity.md
  - ../../binaryen/passes/heap2local/starshine-hot-ir-strategy.md
  - ../../binaryen/passes/optimize-casts/index.md
  - ../../binaryen/passes/coalesce-locals/index.md
---

# 2026-05-08 heap2local backlog closure

## Question

Does active backlog slice `[H2L]002` still describe live `heap2local` work, or have its two remaining deliverables already moved elsewhere?

## Findings

1. The ordered no-DWARF neighbor cluster named in `[H2L]002` is no longer missing.
   - `optimize-casts` now sits in the public `heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse` slot.
   - the exact neighborhood is locked by `src/passes/optimize_test.mbt` and by the 2026-05-08 ordered-slot research/docs updates for `optimize-casts` and `coalesce-locals`.
2. The only remaining Binaryen-vs-Starshine delta previously attached to `heap2local` was the nondefaultable-local / refinalization repair story.
3. That delta is **not currently reachable on Starshine's validator-accepted open-world input surface**.
   - During this run, ad hoc `heap2local` fixtures with non-nullable reference locals failed local validation immediately with `func[0]: locals: type has no default value` before the pass could even run.
   - So Binaryen's `TypeUpdating::handleNonDefaultableLocals(...)` follow-up remains a true upstream concept, but it is not an active `heap2local` parity blocker inside today's Starshine surface.
4. The practical consequence is that `[H2L]002` had become a stale mixed-scope item:
   - one half was already closed by neighboring slot work,
   - the other half belongs to a broader future validator / local-type-surface expansion, not to current `heap2local` parity.

## Conclusion

Close `[H2L]002`.

Keep the living `heap2local` pages honest about the upstream Binaryen nondefaultable-local / refinalization contract, but do **not** keep treating it as an active Starshine `heap2local` backlog item until the repo deliberately accepts that local surface.

If future work broadens validator or IR support for nondefaultable locals, reopen a new cross-cutting task at that time instead of reviving `H2L002` as if the neighboring slot proof were still missing.
