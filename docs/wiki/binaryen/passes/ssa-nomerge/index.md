---
kind: entity
status: supported
last_reviewed: 2026-05-07
sources:
  - ../../../raw/binaryen/2026-05-01-ssa-nomerge-implementation-primary-sources.md
  - ../../../raw/research/0555-2026-05-07-aud001-backlog-split-after-current-head-rerun.md
  - ../../../raw/research/0431-2026-05-01-ssa-nomerge-implementation-structure.md
  - ../../../raw/research/0240-2026-04-21-ssa-nomerge-starshine-strategy-followup.md
  - ../../../raw/binaryen/2026-04-21-ssa-nomerge-primary-sources.md
  - ../../../raw/research/0141-2026-04-20-ssa-nomerge-binaryen-research.md
  - ../../../../../src/passes/ssa_nomerge.mbt
  - ../../../../../src/passes/ssa_nomerge_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md
  - ../../../../../.artifacts/o4z-wasm-opt-debug.log
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SSAify.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/LocalGraph.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/ReFinalize.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/ssa-nomerge_enable-simd.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/ssa-nomerge_enable-simd.txt
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/ssa.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/SSAify.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/ir/local-graph.h
  - https://github.com/WebAssembly/binaryen/blob/main/src/ir/LocalGraph.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/ir/ReFinalize.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/test/passes/ssa-nomerge_enable-simd.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/passes/ssa-nomerge_enable-simd.txt
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./starshine-hot-ir-strategy.md
  - ./merge-shapes-and-canonical-slots.md
  - ./wat-shapes.md
  - ./parity.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../dead-code-elimination/index.md
  - ../coalesce-locals/index.md
---

# `ssa-nomerge`

## Role

- `ssa-nomerge` is an active implemented **hot pass** in Starshine.
- In upstream Binaryen `version_129`, `pass.cpp` describes it as:
  - ssa-ify variables so that they have a single assignment, ignoring merges

That description is correct, but it hides the most important part.

A better beginner summary is:

- Binaryen builds a whole-function LocalGraph of which local writes can reach which local reads,
- gives fresh local indexes only to writes whose later reads stay single-source,
- rewrites those reads to the fresh locals or explicit default values,
- and deliberately leaves merge points on the canonical original slot instead of inventing phi locals.

So this is **not** full SSA construction, but it is also **not** just straight-line renaming.

## Why this pass matters

- Earlier pass-wiki work had already made `ssa-nomerge` a strong upstream-facing dossier, but this run still needed to close the missing **Starshine strategy/code-map** gap so the folder matched the surrounding implemented-pass schema.
- In the canonical no-DWARF `-O` / `-Os` scheduler it is the first function pass:
  - `... -> global-struct-inference -> ssa-nomerge -> dead-code-elimination -> remove-unused-names -> ...`
- That placement is meaningful.
  - Binaryen wants simpler local traffic before the first cleanup wave.
  - The source comment in `pass.cpp` says untangling to semi-SSA form is helpful, but merges are ignored to avoid introducing new copies.
- In the saved generated-artifact `-O4z` audit, it appears at top-level slot `8` and already has strong semantic parity evidence:
  - exact wasm equal: `no`
  - normalized WAT equal: `yes`
  - Starshine wall/runtime: `10299.164 ms`
  - Binaryen wall/runtime: `496.466 ms`
  - Starshine in-pass time: `1341.831 ms`
  - Binaryen in-pass time: `286.388 ms`
  - input validates: `yes`
  - output validates: `yes`
- The saved `-O4z` debug log also shows repeated nested reruns of `ssa-nomerge`, not just the top-level slot.
- `agent-todo.md` now has a dedicated `[SSA]001` slice for the reopened current-head direct mismatch family.
  - The active remaining work is temp-local declaration count/type/order normalization against Binaryen, not a new semantic rewrite family.

## Most important durable takeaways

- Upstream `ssa-nomerge` is **not** a separate algorithm from `ssa`.
  - both live in `SSAify.cpp`
  - the no-merge behavior is the shared algorithm with `allowMerges = false`
- The pass depends on whole-function LocalGraph CFG reasoning.
  - it is not just looking at adjacent `local.set` / `local.get` pairs
- The crucial no-merge decision is made **per set**, not per original local slot.
  - one original local can have some writes untangled and later merge-feeding writes left canonical
- Reads with no explicit reaching set can be rewritten to explicit default values.
  - that includes scalar zeros, `v128` zero splats, and in shared `SSAify` helper paths also ref/tuple defaults
- Full phi-like merge materialization still exists in the same source file, but that is the `--ssa` path, not the `--ssa-nomerge` path.
- A narrow 2026-04-20 source comparison found **no semantic post-`version_129` drift** in `SSAify.cpp`, `LocalGraph.cpp`, `local-graph.h`, `ReFinalize.cpp`, or the dedicated `ssa-nomerge` golden test file.

## Biggest beginner correction

The easy wrong mental model is:

- `ssa-nomerge` converts the whole function into SSA form, just without explicit phi syntax

The safer mental model is:

- Binaryen only untangles local writes whose influenced gets stay single-source,
- refuses to invent merge locals in no-merge mode,
- and keeps merged values on canonical original slots so later passes can benefit without immediate code-size growth.

That is why the pass is narrower than the name sounds, but more source-sensitive than a simple local peephole.

## What the pass sounds like versus what it actually does

What it sounds like:

- make all locals SSA-ish

What it actually is in `version_129`:

- a function-parallel LocalGraph-based pass,
- an already-SSA index detector,
- a per-set fresh-local allocator,
- a get rewriter for single-source and default-value reads,
- a deliberate no-op on merge gets,
- and a narrow refinalization repair step when default ref values sharpen types.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the actual `SSAify.cpp` structure, helper dependencies, scheduler placement, LocalGraph flow model, and the shared-`ssa` versus no-merge split.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Source-owner and proof-surface map for upstream `SSAify.cpp`, `LocalGraph`, `ReFinalize`, pass registration, no-merge golden tests, and the exact current Starshine implementation/test files.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - Exact MoonBit code map for the current local pass, covering the HOT-SSA roundtrip, predecessor-copy destruction path, raw structured and straight-line fallbacks, preset placement, and the main ways current Starshine differs from upstream Binaryen's true no-merge strategy.
- [`./merge-shapes-and-canonical-slots.md`](./merge-shapes-and-canonical-slots.md)
  - Focused guide to the hardest part to misunderstand on the upstream side: why the no-merge policy is per set, how default/param values count as merge inputs, and why some writes to one original local still get fresh locals while others stay canonical.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly shape catalog covering straight-line positives, dead-param and default-zero rewrites, merge bailouts, shared-helper ref/tuple defaults, and the full-`ssa` families that upstream `ssa-nomerge` intentionally declines.
- [`./parity.md`](./parity.md)
  - Current in-tree parity state, the fixed dead-param family, the green WAT/canonical compare evidence, and the honest remaining artifact-level writeback-skip story.

## Freshness note

A narrow 2026-04-20 direct source comparison found **no semantic post-`version_129` drift** in the owning official surfaces used for this dossier.

- `src/passes/SSAify.cpp` is identical on current `main`
- `src/ir/local-graph.h` is identical on current `main`
- `src/ir/LocalGraph.cpp` is identical on current `main`
- `src/ir/ReFinalize.cpp` is identical on current `main`
- `test/passes/ssa-nomerge_enable-simd.wast` and `.txt` are identical on current `main`

So the durable rule is:

- treat Binaryen `version_129` as the reviewed tagged oracle for this dossier's upstream file/test surfaces
- keep the current-main note explicit only to say there is no visible source or dedicated-test semantic drift right now
- do **not** silently upgrade that narrower claim into “latest global Binaryen release,” because the official releases index visible to this run showed a newer-by-date `version_125` page as well; keep that numbering uncertainty explicit instead

## Current maintenance rule

- Treat this folder as the canonical home for future `ssa-nomerge` parity and scheduler research.
- Keep the main beginner correction explicit:
  - upstream `ssa-nomerge` is LocalGraph-based single-source untangling with merges deliberately left canonical, not full phi SSA and not just straight-line renaming
- Keep the per-set no-merge rule, the default-value materialization behavior, the shared `ssa` helper boundary, the new local HOT-SSA-destruction strategy page, and the current artifact-level fail-closed writeback caveat explicit whenever future docs or code changes touch this pass.

## Sources

- [`../../../raw/binaryen/2026-05-01-ssa-nomerge-implementation-primary-sources.md`](../../../raw/binaryen/2026-05-01-ssa-nomerge-implementation-primary-sources.md)
- [`../../../raw/research/0431-2026-05-01-ssa-nomerge-implementation-structure.md`](../../../raw/research/0431-2026-05-01-ssa-nomerge-implementation-structure.md)
- [`../../../raw/research/0141-2026-04-20-ssa-nomerge-binaryen-research.md`](../../../raw/research/0141-2026-04-20-ssa-nomerge-binaryen-research.md)
- [`../../../../../src/passes/ssa_nomerge.mbt`](../../../../../src/passes/ssa_nomerge.mbt)
- [`../../../../../src/passes/ssa_nomerge_test.mbt`](../../../../../src/passes/ssa_nomerge_test.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md)
- [`../../../../../.artifacts/o4z-wasm-opt-debug.log`](../../../../../.artifacts/o4z-wasm-opt-debug.log)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SSAify.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/LocalGraph.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/ReFinalize.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/ssa-nomerge_enable-simd.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/ssa-nomerge_enable-simd.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/ssa.wast>
- Narrow freshness-check surface:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SSAify.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/ir/local-graph.h>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/ir/LocalGraph.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/ir/ReFinalize.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/passes/ssa-nomerge_enable-simd.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/passes/ssa-nomerge_enable-simd.txt>
