---
kind: entity
status: supported
last_reviewed: 2026-06-14
sources:
  - ../../../raw/research/0722-2026-06-09-ssa-nomerge-exceptional-edge-audit.md
  - ../../../raw/binaryen/2026-05-01-ssa-nomerge-implementation-primary-sources.md
  - ../../../raw/research/0555-2026-05-07-aud001-backlog-split-after-current-head-rerun.md
  - ../../../raw/research/0431-2026-05-01-ssa-nomerge-implementation-structure.md
  - ../../release-horizon-and-oracles.md
  - ../../../raw/research/0240-2026-04-21-ssa-nomerge-starshine-strategy-followup.md
  - ../../../raw/binaryen/2026-04-21-ssa-nomerge-primary-sources.md
  - ../../../raw/research/0141-2026-04-20-ssa-nomerge-binaryen-research.md
  - ../../../../../src/passes/ssa_nomerge.mbt
  - ../../../../../src/passes/ssa_nomerge_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md
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
  - ../../release-horizon-and-oracles.md
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
- The 2026-06-09 audit found and fixed a true semantic corruption family: HOT `ssa-nomerge` ignored exceptional edges, so a `try_table` body local write followed by `throw` to a catch target could be dropped while a later `local.get` read the default value. Starshine now skips exceptional-flow HOT mutation for this pass until local SSA grows exceptional-edge semantics. `[SSANM-007a1]` / `[SSANM-007a2a]` refreshed that boundary on 2026-06-14: real throwing `try_table` catch and catch-all exits preserve their local writes and `throw` but stay off ordinary structured LocalGraph trace reasons. `[SSANM-007a2b]` / `[SSANM-007a2c]` then locked direct HOT `throw_ref`, legacy catch/rethrow, and delegate terminators as no-mutation boundaries and closed the throwing EH fail-closed subtrack. `[SSANM-007a3]` classifies retained no-throw `try_table` support as normal-flow work only when the body has no throw/call-bearing edge: ordinary local writes use the existing structured raw path, while scalar proxy and store-model rewrites remain typed-control helper ownership rather than real EH SSA support.
- The same audit fixed non-corrupting direct-compare drift in no-write functions: default body-local reads after branchy control now materialize explicit type defaults, and dropped-unreachable debris before a hard `unreachable` is cleaned in the raw path.
- Follow-ups on the debug-artifact direct trace reduced nested structured param/body-local shape drift, removed unneeded branch/label merge copies, removed the one current `Func 4302` false-positive suspicious-carrier skip, and expanded raw structured coverage for moderate large functions. Current SSANM replay anchors track nine remaining `large-structured-local-writes` functions for huge-function classification and replay work.
- `agent-todo.md` has a dedicated `[O4Z-AUDIT-SSA]` / `SSANM-*` backlog for the reopened audit. The direct explicit pass has strong normalized compare evidence; `[SSANM-003a]` / `[SSANM-003b]` now make the raw straight-line `local.set` and `local.tee` subsets consume the LocalGraph rewrite plan; `[SSANM-004a]` uses planned default-entry get materialization for straight-line defaults plus a narrow normal structured-control subset; `[SSANM-004b]` removes the duplicated no-local-write default-only rewriter by routing no-write defaults through the same LocalGraph materializer while preserving no-write unreachable-debris cleanup; `[SSANM-005a]` preserves simple missing-else one-arm body-local/default and parameter-entry merges through a canonical-only LocalGraph plan path; `[SSANM-005b1]` preserves simple both-arm and block/`br_if` multi-source body-local merges without fresh merge locals or predecessor copies; `[SSANM-005b2]` preserves simple void-loop direct `br_if 0` backedge merges through the same canonical-only LocalGraph plan before the legacy loop-carried HOT defer; `[SSANM-005c1]` / `[SSANM-005c2]` classify and implement a narrow mixed fresh/canonical normal `if`/`local.set` path where non-merge writes freshen while merge-feeding writes and merge reads stay canonical; `[SSANM-005c3a]` admits small mixed `local.tee` write sets through the same planned structured rewrite while preserving tee stack results; `[SSANM-005c3b]` / `[SSANM-005c3c]` classify mixed `br_if` early exits plus nested normal `block` / `if` as supported while keeping plain `br`, `br_table`, and loops fail-closed; `[SSANM-005b3]` separately classifies plain `br` / `br_table` multi-source merge regions as fail-closed from the canonical-only LocalGraph path until branch/table helpers are narrowed; and `[SSANM-006a2a]` adds ordinary normal `block` / `if` `local.set` freshening through `structured-localgraph-plan` for single-source no-merge traffic while leaving branches, returns, loops, EH, typed-control, `local.tee`, and trap boundaries on existing owners. `[SSANM-006a2b]` adds explicit merge-adjacent ordinary `local.set` coverage: freshenable writes before/after a canonical merge region use planned fresh locals while merge-feeding writes and merge reads stay on the original local. `[SSANM-006a2c]` narrows the remaining legacy `structured-local-writes` / `structured-local-writes-mutated` summaries to branch/table, typed-control, EH, huge-function, and explicit fail-closed owners. `[SSANM-006a3a]` records branch-exit helper ownership; `[SSANM-006a3b]` locks ordinary plain `br` plus non-mixed/non-backedge `br_if` local-source regions as fail-closed from planned structured LocalGraph paths; `[SSANM-006a3c]` does the same for ordinary no-value `br_table` local-source exits; `[SSANM-006a3d]` closes nested normal branch-target classification by keeping nested outer-target and loop-exit `br_if` shapes off planned LocalGraph reasons unless later branch/loop owners prove a narrower safe subset; `[SSANM-006b2a]` censuses the raw-dispatch paths that can still fall through to HOT SSA destruction, identifying non-simple loop-carried branch shapes and legacy structured-helper rejection paths as the remaining fallback-risk candidates; `[SSANM-006b2b]` adds public-pipeline trace locks proving straight-line, no-write, default-entry, and unreachable-debris families keep using named raw/no-write exits instead of lifted HOT fallback; `[SSANM-006b2d]` classifies branch-alias, `br_table`, typed-control, ref/cast branch, and EH scratch/proxy helpers as explicit boundary owners rather than ordinary predecessor-copy work; `[SSANM-007a2]` locks the real throwing EH category fail-closed through direct/conditional throwing `try_table`, `throw_ref`, legacy catch/rethrow, and delegate evidence; `[SSANM-007a3]` classifies no-throw `try_table` local-write and typed-control helper subsets and adds a call-bearing fail-closed contrast, closing parent `[SSANM-007a]`; and `[SSANM-007b1]` inventories typed-control loop/result, branch-table, ref/null, and cast-branch raw helpers as ABI repair surfaces rather than ordinary LocalGraph local-source mutation. `[SSANM-007b2]` now adds trace/output locks for scalar/reference loop-param proxy helpers, no-copy typed-loop no-mutation boundaries, multi-param/single-result store-model helpers, typed-loop `br_table` helpers, and nested loop-target gates, keeping those scratches/proxies/stores classified as typed-control ABI repair rather than ordinary no-merge predecessor copies. `[SSANM-007b3a]` / `[SSANM-007b3b]` now lock value-carrying `br`, `br_if`, direct `br_table`, and mixed-target `br_table` operands as branch/table ABI boundaries that validate and preserve branch opcodes while staying off ordinary planned structured LocalGraph reasons. `[SSANM-007b3c]` now applies the same trace/validation boundary proof to representative no-copy, copy-needing/prefix, non-null raw-path, and local-tee tested-producer `br_on_null` / `br_on_non_null` exits; `[SSANM-007b3d]` applies it to no-copy, divergent-alias, multi-result, multi-param, no-copy loop-target, and copy-needing loop-target `br_on_cast` / `br_on_cast_fail` exits, closing the typed branch subtrack. Ordinary predecessor-copy rerouting/retirement, huge-function classification, debug-WASI artifact classification, and the currently no-op O4z slot decision remain open.

## Most important durable takeaways

- Upstream `ssa-nomerge` is **not** a separate algorithm from `ssa`.
  - both live in `SSAify.cpp`
  - the no-merge behavior is the shared algorithm with `allowMerges = false`
- The pass depends on whole-function LocalGraph CFG reasoning.
  - it is not just looking at adjacent `local.set` / `local.get` pairs
- The crucial no-merge decision is made **per set**, not per original local slot.
  - one original local can have some writes untangled and later merge-feeding writes left canonical
  - Starshine now consumes that LocalGraph decision table for straight-line raw `local.set` and `local.tee`, for simple missing-else one-arm entry/default merge preservation, for simple both-arm / block-`br_if` multi-source merge preservation, for simple void-loop direct `br_if 0` backedge canonical preservation, for narrow mixed fresh/canonical normal regions with `local.set`, small `local.tee` write sets, `br_if` early exits, and nested normal `block` / `if`, for ordinary normal `block` / `if` single-source `local.set` freshening, and for explicit merge-adjacent ordinary `local.set` coverage; `[SSANM-006a1]` / `[SSANM-006a2c]` / `[SSANM-006a3a]` through `[SSANM-006a3c]` record the normal structured-control and legacy-helper boundary map, keeping plain `br`, ordinary non-mixed/non-backedge `br_if`, ordinary `br_table`, value-carrying branch operands, nested outer-target `br_if`, nested loop-exit `br_if`, EH, and typed-control branch operands fail-closed from ordinary planned LocalGraph mutation until their owning slices narrow the helper behavior; `[SSANM-006b2b]` adds regression locks that keep completed straight-line/default/no-write families away from lifted HOT SSA destruction, `[SSANM-006b2d]` keeps retained branch/table/typed/EH scratch helpers classified as boundary lowerings rather than ordinary no-merge predecessor-copy work, `[SSANM-007a2]` closes the throwing EH fail-closed locks while `[SSANM-007a3]` keeps no-throw `try_table` subsets classified as ordinary normal-flow or typed-control helper work only when call/throw-bearing edges are absent, and `[SSANM-007b1]` maps typed loop/result plus typed branch/cast helpers to `[SSANM-007b2]` / `[SSANM-007b3]` boundary locks instead of counting their scratches as ordinary no-merge predecessor copies; `[SSANM-007b2]` now locks scalar/reference loop-param proxy, no-copy typed-loop, multi-param/single-result store-model, typed-loop `br_table`, and nested loop-target behavior with focused trace/output assertions; `[SSANM-007b3a]` / `[SSANM-007b3b]` lock value `br`, `br_if`, and value `br_table` operands as branch/table ABI boundaries; `[SSANM-007b3c]` locks representative `br_on_null` / `br_on_non_null` no-copy, prefix/copy-needing, raw-path, and tested-producer exits as typed-control ABI boundaries; and `[SSANM-007b3d]` closes the typed branch subtrack by locking representative `br_on_cast` / `br_on_cast_fail` no-copy, divergent-alias, multi-result, multi-param, no-copy loop-target, and copy-needing loop-target exits as cast-branch ABI boundaries
- Reads with no explicit reaching set can be rewritten to explicit default values.
  - that includes scalar zeros, `v128` zero splats, and in shared `SSAify` helper paths also ref/tuple defaults
  - Starshine now consumes planned default-entry get decisions for straight-line functions, no-local-write functions, and a narrow normal structured-control subset with body-default reads and other writes
- Full phi-like merge materialization still exists in the same source file, but that is the `--ssa` path, not the `--ssa-nomerge` path. `[SSANM-007c]` split the remaining full-`ssa` materialization backlog into sibling `[O4Z-AUDIT-SSA-FULL]` / `[SSA-FULL-*]` tasks so no-merge closeout cannot silently absorb full-SSA work.
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
  - Current in-tree parity state, fixed direct-skip families, compare evidence, and the honest remaining artifact-level exact-parity / huge-function story.

## Freshness note

A 2026-06-13 `[SSANM-001a]` refresh rechecked the owning official source/test surfaces against the local Binaryen oracle, `wasm-opt version 130 (version_130)`.

- `src/passes/SSAify.cpp` is identical between `version_129` and `version_130`.
- `src/ir/local-graph.h` is identical between `version_129` and `version_130`.
- `src/ir/LocalGraph.cpp` is identical between `version_129` and `version_130`.
- `test/passes/ssa-nomerge_enable-simd.wast` and `.txt` are identical between `version_129` and `version_130`.
- `test/lit/passes/ssa.wast` and `test/gtest/local-graph.cpp` are identical between `version_129` and `version_130`.
- `src/ir/ReFinalize.cpp` only adds finalizers for new wide-int expression nodes; this does not change the no-merge default-ref repair contract.
- `src/passes/pass.cpp` and `src/passes/passes.h` only changed in unrelated registration/declaration surfaces plus a GC closed-world option spelling; `ssa-nomerge` registration and early optimizer scheduling are unchanged.

So the durable rule is:

- the `version_129` behavior dossier remains valid for local Binaryen `version_130` no-merge planning;
- keep the source-refresh note explicit and pass-surface-limited;
- do **not** silently upgrade that narrower claim into “all Binaryen optimizer behavior is unchanged.”

## Current maintenance rule

- Treat this folder as the canonical home for future `ssa-nomerge` parity and scheduler research.
- Keep the main beginner correction explicit:
  - upstream `ssa-nomerge` is LocalGraph-based single-source untangling with merges deliberately left canonical, not full phi SSA and not just straight-line renaming
- Keep the per-set no-merge rule, the default-value materialization behavior, the shared `ssa` helper boundary, the local HOT-SSA-destruction strategy page, the normal-flow-only SSA v1 exceptional-edge exclusion, and the current artifact-level fail-closed writeback caveat explicit whenever future docs or code changes touch this pass.

## Sources

- [`../../../raw/research/0722-2026-06-09-ssa-nomerge-exceptional-edge-audit.md`](../../../raw/research/0722-2026-06-09-ssa-nomerge-exceptional-edge-audit.md)
- [`../../../raw/binaryen/2026-06-13-ssa-nomerge-version-130-source-refresh.md`](../../../raw/binaryen/2026-06-13-ssa-nomerge-version-130-source-refresh.md)
- [`../../../raw/binaryen/2026-05-01-ssa-nomerge-implementation-primary-sources.md`](../../../raw/binaryen/2026-05-01-ssa-nomerge-implementation-primary-sources.md)
- [`../../../raw/research/0431-2026-05-01-ssa-nomerge-implementation-structure.md`](../../../raw/research/0431-2026-05-01-ssa-nomerge-implementation-structure.md)
- [`../../../raw/research/0141-2026-04-20-ssa-nomerge-binaryen-research.md`](../../../raw/research/0141-2026-04-20-ssa-nomerge-binaryen-research.md)
- [`../../../../../src/passes/ssa_nomerge.mbt`](../../../../../src/passes/ssa_nomerge.mbt)
- [`../../../../../src/passes/ssa_nomerge_test.mbt`](../../../../../src/passes/ssa_nomerge_test.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`](../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md) preserves the saved generated-artifact `-O4z` slot, summary, and Binaryen debug-log facts; older `.artifacts` paths are replay identifiers, not durable wiki source links.
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
- Binaryen `version_130` refresh surface:
  - <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/SSAify.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/local-graph.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/LocalGraph.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/ReFinalize.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/passes.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/test/passes/ssa-nomerge_enable-simd.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/test/passes/ssa-nomerge_enable-simd.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/ssa.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/test/gtest/local-graph.cpp>
