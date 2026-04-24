---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-type-generalizing-primary-sources.md
  - ../../../raw/research/0308-2026-04-24-type-generalizing-source-correction-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/ir/hot_core.mbt
  - ../../../../../src/ir/hot_lift.mbt
  - ../../../../../src/ir/hot_lower.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./local-flow-type-floor-and-boundaries.md
  - ./wat-shapes.md
  - ../simplify-locals/index.md
  - ../type-refining/index.md
  - ../gufa/index.md
---

# Starshine `type-generalizing` strategy

## Current status

Starshine does **not** implement `type-generalizing` today.

The current local truth is:

- `src/passes/optimize.mbt` lists `type-generalizing` in `pass_registry_boundary_only_names()`.
- The registry category is therefore `BoundaryOnly`, not `HotPass` and not `ModulePass`.
- `run_hot_pipeline_expand_passes(...)` rejects boundary-only requests with the standard “boundary-only and is not implemented in the hot pipeline” error.
- `optimize_preset_passes(...)` and `shrink_preset_passes(...)` do not include `type-generalizing`.
- `src/passes/registry_test.mbt` locks the active preset list to implemented pass names; it does not prove a hidden `type-generalizing` implementation.
- There is no `src/passes/type_generalizing.mbt` owner file.
- `agent-todo.md` has no dedicated `type-generalizing` backlog slice.

So the correct Starshine strategy is a **status and future-port map**, not an implementation guide for code that already exists.

## Exact local code locations

| Local surface | Code location | Why it matters |
| --- | --- | --- |
| Boundary-only registry name | `src/passes/optimize.mbt`, `pass_registry_boundary_only_names()` | Preserves the local `type-generalizing` spelling while preventing accidental execution |
| Request rejection | `src/passes/optimize.mbt`, `run_hot_pipeline_expand_passes(...)` | Stops boundary-only names before the hot/module dispatcher |
| Active preset omission | `src/passes/optimize.mbt`, `optimize_preset_passes(...)` and `shrink_preset_passes(...)` | Confirms no hidden default-pipeline role |
| Registry/preset tests | `src/passes/registry_test.mbt` | Tests active category and preset honesty, but does not implement this pass |
| Core type model | `src/lib/types.mbt` | Defines `ValType`, `RefType`, `HeapType`, `SubType`, `CompType`, and instruction constructors a future port would retag |
| HOT opcode model | `src/ir/hot_core.mbt` | Contains local/control/call/ref op names used by function-local HOT passes |
| HOT lift/lower | `src/ir/hot_lift.mbt`, `src/ir/hot_lower.mbt` | Likely landing zone if Starshine ports the corrected function-local algorithm as HOT work |
| WAT lowering | `src/wast/lower_to_lib.mbt` | Converts local and reference/type instructions into `@lib.Instruction` forms |
| Validator | `src/validate/typecheck.mbt` | Owns type-stack rules that a retagging pass must preserve |
| Binary roundtrip | `src/binary/encode.mbt`, `src/binary/decode.mbt` | Keeps any new expression/type shapes serializable |

## How Starshine should map the corrected Binaryen strategy

The corrected Binaryen pass is local-flow/type-retagging work.
A future Starshine port should therefore start near function/HOT infrastructure, not near closed-world module GC infrastructure.

### Likely local landing zone

The likely landing zone is a HOT or function-local pass that can:

- see local.set/local.tee value flow,
- compute compatible types using Starshine's type model,
- retag expression/result metadata safely,
- replace unsafe `local.get` retagging with a drop-plus-zero sequence,
- and validate the final module.

`src/ir/hot_lift.mbt` and `src/ir/hot_lower.mbt` already encode the boundary between `@lib.Instruction` and HOT nodes. That is the natural place to inspect before choosing whether this is easier as a HOT pass or a direct `@lib.Expr` walker.

### What not to build for this pass

Do **not** plan this pass as:

- a `ContentOracle` port,
- a closed-world type-section pass,
- a `struct.get` / `struct.set` rewrite,
- a `call_ref` one-signature optimizer,
- a `ref.cast` tightening or insertion pass.

Those were stale claims in the older dossier, not supported by the reviewed `version_129` source.

## Future implementation checklist

Before promoting `type-generalizing` from boundary-only to implemented, require at least:

1. an owner file, probably `src/passes/type_generalizing.mbt` or a clearly named function-local helper module;
2. registry category change from `BoundaryOnly` to `HotPass` or `ModulePass` in `src/passes/optimize.mbt`;
3. tests that prove registry category and explicit request behavior;
4. positive local-flow retagging tests based on the official `type-generalizing.wast` shapes;
5. a `local.get` drop-plus-zero test;
6. nondefaultable, concrete, and unreachable no-op tests;
7. final validation enabled for rewritten modules;
8. pass-fuzz comparison against Binaryen's `experimental-type-generalizing` if the upstream hidden/test pass remains invocable in local tooling.

## Current validation guidance

Because Starshine has no implementation, the only current validation is documentation/status validation:

- `type-generalizing` must remain rejected as boundary-only when requested directly.
- It must not appear in `optimize` or `shrink` preset expansion.
- Wiki pages must cite the 2026-04-24 source correction instead of the superseded 0191 mechanics.

If a future port lands, use the repo's standard signoff:

- quick: `moon info`, `moon fmt`, `moon test`
- pass parity: `bun fuzz compare-pass --pass type-generalizing ...` or the nearest hidden-pass-compatible harness spelling, if Binaryen exposes it to the comparison tooling

## Relationship to neighboring Starshine code

- `src/passes/simplify_locals.mbt` is a useful neighbor for local-flow cleanup style, but it is not an implementation of this pass.
- `src/passes/heap2local.mbt` has examples of function-local heap/reference rewrites, but its escape/candidate logic is unrelated to the corrected `type-generalizing` contract.
- `src/passes/duplicate_function_elimination.mbt` has robust type-index and heap-type remapping helpers, useful as implementation examples for type-aware rewrites but not as a semantic template.
- `src/passes/type_refining.mbt` does not exist; the existing `type-refining` wiki page is another boundary-only status/port map.

## Uncertainties and caveats

- Binaryen registers this as a hidden/test pass. A future Starshine user-facing port may need a policy decision about whether the local `type-generalizing` alias should remain boundary-only, become an opt-in developer pass, or be dropped from public docs.
- The best Starshine landing zone is not proven. HOT is plausible, but a direct expression walker may be simpler if the needed type metadata is not preserved conveniently through HOT lift/lower.
- The old 0191 note remains in the archive for auditability, but its algorithmic content is superseded by the 2026-04-24 source correction.

## Source chain

For the full source-backed chain, read in this order:

1. [`../../../raw/binaryen/2026-04-24-type-generalizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-type-generalizing-primary-sources.md)
2. [`../../../raw/research/0308-2026-04-24-type-generalizing-source-correction-and-starshine-followup.md`](../../../raw/research/0308-2026-04-24-type-generalizing-source-correction-and-starshine-followup.md)
3. [`./binaryen-strategy.md`](./binaryen-strategy.md)
4. [`./local-flow-type-floor-and-boundaries.md`](./local-flow-type-floor-and-boundaries.md)
5. [`./wat-shapes.md`](./wat-shapes.md)
