# IR2 Architecture Current Refresh

_Status:_ immutable source bridge for [`docs/wiki/ir2/architecture-rules.md`](../../ir2/architecture-rules.md) and the archived architecture note [`docs/wiki/raw/research/0059-2026-03-24-ir2-architecture-rules.md`](../research/0059-2026-03-24-ir2-architecture-rules.md)
_Captured:_ 2026-06-04

## Why this refresh exists

The living IR2 architecture page still preserved only the compact March ADR conclusions. Since then, the `src/ir` package has grown the full HOT body split, analysis cache, local SSA overlay, module-context, side-table, query, walk, region-edit, lift/lower, and verification surfaces described by the newer test-matrix and local-SSA refreshes. This note records the current source evidence behind the durable architecture contract so the living page can teach beginner-to-advanced readers without re-opening the March planning note.

External source check: the current official WebAssembly Core 3.0 page identifies the core spec as Release 3.0 dated 2026-05-14, and the WebAssembly specifications catalog describes Wasm 3.0 as the core language document. The reviewed official pages frame modules as validated collections of type/function/table/memory/global/tag/element/data/code resources, instructions as expression sequences, binary opcodes as serialized instruction forms, and validation as the static rule layer. That supports Starshine's boundary split: parsing, binary/text encoding, and validation remain on raw `@lib.Module` / `@lib.Expr` forms, while HOT IR is an optimizer-internal function-body representation that must lower back to a valid boundary module before signoff. The external WebAssembly sources do not define Starshine's IR2 ownership model; the local repository files below are authoritative for that.

## Primary and repository sources checked

### Official WebAssembly context

- WebAssembly Core 3.0 specification index, Release 3.0 dated 2026-05-14: <https://webassembly.github.io/spec/core/>
- WebAssembly specifications catalog for the current Wasm 3.0 core-language document: <https://webassembly.org/specs/>
- Syntax instructions: <https://webassembly.github.io/spec/core/syntax/instructions.html>
- Binary instructions: <https://webassembly.github.io/spec/core/binary/instructions.html>
- Validation instructions and expressions: <https://webassembly.github.io/spec/core/valid/instructions.html>
- Module validation: <https://webassembly.github.io/spec/core/valid/modules.html>

Durable implication: cite these only for the boundary-language distinction between official WebAssembly modules/instructions/expressions/binary/validation and Starshine's optimizer-local HOT form. Do not cite them as if they prescribe HOT node layout, revision keys, side tables, or pass descriptors.

### Starshine IR2 ownership and metadata

- [`src/ir/README.md`](../../../../src/ir/README.md) states that `HotFunc` is the only owned optimizer body representation and that CFG/dominance/post-dominance/liveness/use-def/effects/loop-info/SSA are revision-keyed overlays.
- [`src/ir/architecture.mbt`](../../../../src/ir/architecture.mbt) defines `HotAnalysis`, `HotPassDescriptor`, `hot_revision_current(...)`, `hot_pass_requires(...)`, and `hot_pass_invalidates(...)`.
- [`src/ir/architecture_test.mbt`](../../../../src/ir/architecture_test.mbt) checks that direct HOT mutations bump revisions and that pass descriptors expose analysis requirements and invalidations.
- [`src/ir/hot_core.mbt`](../../../../src/ir/hot_core.mbt) defines `HotFunc`: dense node/child/root storage, locals, interned types, labels, typed payload side tables, body result type, function type index, tombstone tracking, and `revision`.
- [`src/ir/hot_mutate.mbt`](../../../../src/ir/hot_mutate.mbt) and [`src/ir/hot_region_edit.mbt`](../../../../src/ir/hot_region_edit.mbt) are the mutation surfaces that should own revision bumps and structured region edits.

### Derived overlays and pass-facing cache

- [`src/ir/analysis_cache.mbt`](../../../../src/ir/analysis_cache.mbt) holds revision-keyed cache entries for CFG, traversal orders, dominators, post-dominators, loop info, use-def, liveness, effects, and local SSA.
- [`src/passes/pass_common.mbt`](../../../../src/passes/pass_common.mbt) routes descriptor requirements through `pass_prepare_requirements(...)` and typed `pass_require_*` helpers, wrapping analysis builds with performance counters when present.
- [`src/ir/cfg.mbt`](../../../../src/ir/cfg.mbt), [`dominators.mbt`](../../../../src/ir/dominators.mbt), [`postdominators.mbt`](../../../../src/ir/postdominators.mbt), [`loop_info.mbt`](../../../../src/ir/loop_info.mbt), [`use_def.mbt`](../../../../src/ir/use_def.mbt), [`liveness.mbt`](../../../../src/ir/liveness.mbt), [`effects.mbt`](../../../../src/ir/effects.mbt), and [`ssa_local.mbt`](../../../../src/ir/ssa_local.mbt) are all derived from a `HotFunc`; none replaces it as an owned body.
- [`docs/wiki/ir2/local-ssa-policy.md`](../../ir2/local-ssa-policy.md) plus [`docs/wiki/raw/ir2/2026-05-20-local-ssa-source-bridge.md`](2026-05-20-local-ssa-source-bridge.md) document the SSA overlay and destruction contract in more detail.

### Lift/lower and validation boundary

- [`src/ir/hot_lift.mbt`](../../../../src/ir/hot_lift.mbt) constructs HOT bodies from validated boundary expressions and module context.
- [`src/ir/hot_verify.mbt`](../../../../src/ir/hot_verify.mbt) checks HOT core/control/analysis invariants before and after mutation.
- [`src/ir/hot_lower.mbt`](../../../../src/ir/hot_lower.mbt) lowers a verified HOT body back into boundary `@lib` instructions/function bodies.
- [`src/ir/test_helpers.mbt`](../../../../src/ir/test_helpers.mbt) proves the expected test flow: parse WAT, validate boundary module, lift selected function, verify HOT, mutate/analyze when needed, lower, and validate again.
- [`docs/wiki/ir2/test-matrix.md`](../../ir2/test-matrix.md) and [`docs/wiki/raw/ir2/2026-05-20-ir2-test-matrix-repository-refresh.md`](2026-05-20-ir2-test-matrix-repository-refresh.md) are the current coverage map for the files above.

## Current durable architecture contract

- `HotFunc` is a function-body optimizer form, not a replacement for `@lib.Module` or the Wasm validator.
- One function's HOT body owns node, child, root, local, label, type, side-table, tombstone, and revision state.
- Analysis products are disposable overlays keyed to the current `HotFunc.revision`; after mutation they must be rebuilt or invalidated, not patched by hand.
- Pass descriptors are the public declaration of analysis needs and invalidation intent; shared pass helpers are responsible for building requested overlays.
- The verified boundary loop is still mandatory: `lift -> verify -> analyze -> mutate -> verify -> lower -> validate`.
- The module split is no longer aspirational. The landed files under `src/ir/` should be treated as the ownership map, and `hot.mbt` should stay a compatibility-free facade rather than a place to re-centralize IR ownership.

## Uncertainty and non-goals

- This note did not audit every active optimizer pass for direct storage writes. It records the architecture target and source surfaces that pass work should use.
- The official WebAssembly sources are current context for the boundary forms, not an external endorsement of IR2 internals.
- Broader multi-function/module-level optimizations still own their module-level rewrite policies in pass-specific dossiers; IR2's `HotFunc` rule means a single function body is the only owned HOT optimization body, not that all optimizations must be function-local.
