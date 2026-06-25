---
kind: research
status: active
created: 2026-06-25
sources:
  - ./0862-2026-06-20-heap-store-optimization-br-table-local-escape.md
  - ./0863-2026-06-20-heap-store-optimization-loop-backedge-local-read.md
  - ./0867-2026-06-20-heap-store-optimization-generic-dse-boundary.md
  - ./0868-2026-06-20-heap-store-optimization-unreachable-final-boundary.md
  - ./0869-2026-06-20-heap-store-optimization-exact-descriptor-cast-surface.md
  - ./0920-2026-06-21-heap-store-optimization-return-call-ref-set-value.md
  - ./0921-2026-06-21-heap-store-optimization-active-catch-return-call-ref-set-value.md
  - ./1040-2026-06-25-heap-store-optimization-profile-descriptor-br-on-non-null-blocker.md
  - ./1041-2026-06-25-heap-store-optimization-profile-descriptor-br-on-non-null.md
  - ./1048-2026-06-25-heap-store-optimization-exact-ref-cast-recheck.md
  - ./1053-2026-06-25-heap-store-optimization-bottom-tail-oldfield.md
  - ../../binaryen/passes/heap-store-optimization/swap-safety-and-control-flow.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# HSO-F/G/H residual boundary audit

## Question

Which HSO control-flow, `trySwap(...)`, and explicit-boundary backlog claims are stale after the `1041` descriptor `br_on_non_null` fix, and which should remain open?

## Answer

The old `1040` descriptor `br_on_non_null` generated-profile blocker is stale when stated as still blocked. `1041` fixed the HOT branch-payload verifier and exact `ref.null` lowering issues, added focused pass coverage, added the deterministic generated profile root, replayed the former failure, and ran green focused/profile/direct smokes. It is now generated profile coverage, not an accepted deferral.

HSO-F/G/H should still remain open, but for narrower reasons:

- HSO-F remains open for broader in-function branch/catch families beyond the covered caught-call, active-catch throw, escaping branch-valued store, descriptor branch-skip roots, `br_table` escaping-local negative, loop-backedge target-local-read negative, result-wrapper tail-call boundaries, and one-disappearing-bad-get families.
- HSO-G remains open for source-family closeout of broader `trySwap(...)` operands/effects and HOT wrapper peeling/flattening, not because the already covered `try_table`, call/ref-call, growth/store, and descriptor wrapper families are known broken.
- HSO-H remains open for exact descriptor `ref.cast` local/binary surface coverage from `1048` and final non-goal review, not for descriptor `br_on_non_null`.

## Narrow accepted boundaries to keep visible

The following are narrow and evidence-backed, not broad drift approvals:

- `0920` and `0921`: direct-root `return_call_ref` set-value outputs drop a dead `struct.set` because the tail call exits before the store can execute; reopening criteria are any Binaryen/source change showing the store can execute, a Starshine validation/runtime regression, or a broader branch/catch extrapolation.
- `0862`: Starshine's no-later-local-read `br_table` fold extends Binaryen's one-disappearing-bad-get reasoning only when no later local read observes the skipped assignment. The escaping-local `br_table` negative still matches Binaryen.
- `1053`: bottom-typed `return_call_indirect` old fields classify as unreachable-constructor cleanup, with reopening criteria if Binaryen starts preserving the constructor or Starshine regresses validation.

## Explicit non-goals and blockers

Current explicit non-goals remain:

- array stores are outside HSO's source action surface;
- generic non-fresh-reference struct DSE and struct load forwarding are outside HSO's source action surface; and
- unreachable constructor/set-value pairs are left to later DCE when Binaryen preserves HSO roots.

Current local/tooling blocker:

- exact descriptor `ref.cast` is still blocked before HSO by Starshine decode/local surface (`1048`). This is not a semantic HSO non-goal; when decode or a local representation is available, add a focused negative proving Starshine preserves the later `struct.set` like Binaryen for descriptor-cast trap order.

## Status update

This is docs/status cleanup only. No behavior changed and no focused test was needed. The next behavior slice should either add red-first coverage for a specific untested branch/catch or swap-effect family, or run another final-matrix compare lane to strengthen closeout evidence while the remaining source-family audit proceeds.
