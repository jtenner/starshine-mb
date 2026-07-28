---
kind: entity
status: supported
last_reviewed: 2026-07-28
sources:
  - ../../../raw/binaryen/2026-07-02-reorder-locals-version-130-source-refresh.md
  - ../../../../../src/passes/reorder_locals.mbt
  - ../../../../../src/passes/reorder_locals_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../agent-todo.md
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/ReorderLocals.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/passes/reorder-locals.wast
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/passes/reorder-locals_print_roundtrip.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderLocals.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/reorder-locals.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/reorder-locals.txt
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/reorder-locals_print_roundtrip.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/reorder-locals_print_roundtrip.txt
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-ir-builder.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-stack.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReorderLocals.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/test/passes/reorder-locals.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/passes/reorder-locals.txt
  - https://github.com/WebAssembly/binaryen/blob/main/test/passes/reorder-locals_print_roundtrip.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/passes/reorder-locals_print_roundtrip.txt
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./names-roundtrip-and-porting.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ./parity.md
  - ./multivalue-call-scope.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../simplify-locals-nostructure/index.md
  - ../coalesce-locals/index.md
---

# `reorder-locals`

## Role

- `reorder-locals` is an active implemented **module pass** in Starshine.
- A 2026-05-06 refreshed direct signoff reached 6759/10000 compared cases with 6759 normalized matches, 0 semantic mismatches, and 20 Binaryen empty-recursion-group command failures; see research note 0540.
- A 2026-05-07 debug-artifact stable-boundary replay kept `Normalized WAT equal: yes` and `Canonical function compare equal: yes` after 5 Binaryen no-pass roundtrips even though Binaryen still did not converge on raw emitted wasm; see research note 0547.
- In upstream Binaryen `version_131`, `pass.cpp` describes it as:
  - sorts locals by access frequency

That short description is accurate, but it is easy to over-read.

A better beginner summary is:

- Binaryen walks one function at a time,
- counts how often each local is used,
- keeps parameters fixed,
- sorts only the body locals by hotness and first-seen order,
- drops body locals that were never touched,
- rewrites local users to the new indices,
- and keeps local-name metadata and printed declaration order in sync.

So this is **not** coalescing, **not** liveness-based dead-store cleanup, and **not** a writer-level multivalue repair pass.

## Why this pass matters

- When this thread started, `docs/wiki/binaryen/passes/tracker.md` named `reorder-locals` as the strongest remaining implemented landing-page target after the new `ssa-nomerge` dossier landed.
- In the canonical no-DWARF `-O` / `-Os` scheduler, upstream Binaryen runs it three times inside the function pipeline:
  1. after `simplify-locals-nostructure` and `vacuum`
  2. after `simplify-locals` and `vacuum`
  3. after the second `coalesce-locals`, just before the final `vacuum`
- That placement is meaningful.
  - Binaryen uses `reorder-locals` as a repeated compactor after cleanup churn, not just as a one-off cosmetic sort.
- In Starshine today, the pass is intentionally available as an explicit module pass **and** public `optimize` / `shrink` now schedule the Binaryen-shaped three-slot public cleanup story the repo has ordered-neighborhood evidence for: the early tuple/no-structure lane `code-pushing -> tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals -> remove-unused-brs`, then the late local-cleanup cluster `... -> simplify-locals -> vacuum -> reorder-locals -> coalesce-locals -> reorder-locals -> vacuum`. The 2026-07-12 scheduling note `1561` supersedes the older one-slot public policy from `0709`.
- The current parity story is also worth teaching clearly:
  - the raw sort rule is already well understood and well tested
  - the persistent multivalue-call instability belongs to Binaryen's tuple packaging and binary writeback layers, not to `ReorderLocals.cpp` itself

## Most important durable takeaways

- Parameters never move.
- Only body locals are reordered or dropped.
- Upstream Binaryen counts:
  - `local.get`
  - `local.set`
  - and, indirectly, `local.tee`, because tee is represented as `LocalSet` in Binaryen IR.
- Accessed body locals sort by descending access count.
- Nonzero-count ties break by first observed access.
- Zero-count ties preserve original order, but the final zero-count body-local suffix is then dropped.
- The pass rewrites local-user indices and function-local name maps.
- Upstream explicitly declares that it does **not** need non-nullable-local fixups.
- The dedicated print-roundtrip tests show that declaration order after reordering must survive binary writing and reading, not just in-memory AST mutation.
- A 2026-07-27 audit found `ReorderLocals.cpp` and the dedicated lit files byte-identical between `version_130` and `version_131`; current evidence uses official `wasm-opt version 131 (version_131)`.

## Biggest beginner correction

The easy wrong mental model is:

- `reorder-locals` packs locals more tightly, kind of like a register allocator or coalescer

The safer mental model is:

- Binaryen counts local traffic, keeps params fixed, stably reorders live body locals by heat and first use, and trims the untouched suffix.

That is smaller than the name sounds, but still important because it repeats at key cleanup boundaries.

## What the pass sounds like versus what it actually does

What it sounds like:

- a broad local-minimization pass

What it actually is in `version_131`:

- a tiny function-parallel usage counter
- a stable declaration-order canonicalizer for body locals
- a zero-access body-local trimmer
- a local-index rewriter
- and a local-name plus print-roundtrip maintenance pass

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the actual `ReorderLocals.cpp` structure, pass registration, scheduler placement, sort comparator, truncation rule, and the important things the pass does **not** depend on.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Compact source-confirmed owner/test map for `reorder-locals`, including the tiny `ReIndexer` + sorter split inside `ReorderLocals.cpp`, the public/scheduler role in `pass.cpp`, and the exact split between semantic-sort tests and print-roundtrip tests.
- [`./names-roundtrip-and-porting.md`](./names-roundtrip-and-porting.md)
  - Focused guide to the most practical half of the contract: function-local names, printed declaration order, why Starshine implements this as a module pass, and why the multivalue-call divergence is a boundary issue rather than a sorter bug.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly shape catalog covering hot locals moving forward, first-use ties, dead tail drops, write-only and tee-only locals, nested local-user rewrites, and the main non-goals.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - Current in-tree Starshine module-pass strategy: why the pass stays module-scoped, the exact MoonBit code map, the grouped-local-run rebuild and name-section-rewrite mechanics, and the main representation differences from upstream Binaryen.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  - Validation bridge separating explicit-pass correctness from current public preset scheduling: maps the local tests, registry/dispatcher/CLI surfaces, the now-public three-slot cleanup story, remaining preset-neighborhood owners, and the multivalue writer-boundary caveat into actionable signoff rules.
- [`./parity.md`](./parity.md)
  - Current in-tree parity state, explicit module-pass status, stable-boundary signoff rule, and the honest remaining compare caveats.
- [`./multivalue-call-scope.md`](./multivalue-call-scope.md)
  - The standing repo decision that non-converging Binaryen multivalue-call writeback stays out of scope for `reorder-locals` parity unless that broader compatibility layer becomes a project goal.

## Freshness note

The current released oracle is official `wasm-opt version 131 (version_131)`. The 2026-07-27 audit compared the v131 owner and dedicated `reorder-locals*` lit files with the retained v130 copies and found them byte-identical. The older v129/v130 notes remain useful algorithm provenance, but current closeout claims use v131.

The 2026-07-27 audit repaired a Starshine copy-on-write bug that could lose pure same-type local-index permutations at the CLI boundary. The 2026-07-28 refresh then split equal-count first-use ordering into its own dedicated leaf, expanded the aggregate to ten leaves, replayed both official v131 fixtures byte-exact with debug names preserved, and reran the full required matrix. See [`./parity.md`](./parity.md) and [`./fuzzing.md`](./fuzzing.md).

## Current maintenance rule

- Treat this folder as the canonical home for future `reorder-locals` parity, scheduler, Binaryen owner/test attribution, Starshine strategy/code-map, and writeback-boundary notes.
- Keep the main beginner correction explicit:
  - upstream `reorder-locals` is a stable frequency sorter plus unused-body-local trimmer, not `coalesce-locals` or dead-store elimination.
- Keep the writer-roundtrip rule explicit whenever future docs or code changes touch this pass.
- Keep the multivalue-call writeback distinction explicit whenever future parity work mentions remaining raw-output drift.
- Keep the preset-state split explicit: three `reorder-locals` public cleanup slots are now scheduled, but that does **not** imply full preset parity for unrelated remaining no-DWARF gaps such as the second pre-pass `remove-unused-module-elements` slot, `code-folding`, `redundant-set-elimination`, or the extra Starshine `remove-unused-brs` slot.
- The explicit Binaryen-v131 renewal was refreshed on 2026-07-28. Regular is `100000/100000`; the ten-leaf dedicated and idempotence lanes are `10000/10000`; the new first-use-tie singleton is `1000/1000`; random-all is `9375` exact plus `625` measured smaller Starshine multivalue-boundary wins; wasm-smith is green for all `9956` comparable cases with one cleanup-normalized residual and `44` Binaryen-only failures. The copy-on-write output-loss bug is guarded by pass, CLI, and permutation-only GenValid coverage, while equal-count ordering now has independent direct and generated proof. Repeated cleanup slots remain outside RL's reopening surface; broader preset differences stay with neighboring owners.

## Sources

- Binaryen-v131 closeout: [`./parity.md`](./parity.md) and [`./fuzzing.md`](./fuzzing.md)
- `version_130` source inventory and unchanged-contract provenance: research note 1400
- Retained v130 primary-source manifest: [`../../../raw/binaryen/2026-07-02-reorder-locals-version-130-source-refresh.md`](../../../raw/binaryen/2026-07-02-reorder-locals-version-130-source-refresh.md)
- Public preset scheduling: research note 1561
- Earlier one-slot reconciliation: research note 0709
- [`../../../raw/binaryen/2026-07-02-reorder-locals-version-130-source-refresh.md`](../../../raw/binaryen/2026-07-02-reorder-locals-version-130-source-refresh.md)
- research note 0430
- research note 0253
- research note 0142
- research note 0073
- research note 0074
- [`../../../../../src/passes/reorder_locals.mbt`](../../../../../src/passes/reorder_locals.mbt)
- [`../../../../../src/passes/reorder_locals_test.mbt`](../../../../../src/passes/reorder_locals_test.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderLocals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/reorder-locals.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/reorder-locals.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/reorder-locals_print_roundtrip.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/reorder-locals_print_roundtrip.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-ir-builder.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-stack.cpp>
- Narrow freshness-check surface:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReorderLocals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/passes/reorder-locals.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/passes/reorder-locals.txt>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/passes/reorder-locals_print_roundtrip.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/passes/reorder-locals_print_roundtrip.txt>
