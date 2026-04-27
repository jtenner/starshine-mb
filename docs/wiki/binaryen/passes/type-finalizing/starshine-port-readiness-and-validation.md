---
kind: concept
status: supported
last_reviewed: 2026-04-27
sources:
  - ../../../raw/binaryen/2026-04-27-type-finalizing-port-readiness-primary-sources.md
  - ../../../raw/research/0426-2026-04-27-type-finalizing-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-type-finalizing-primary-sources.md
  - ../../../raw/research/0310-2026-04-24-type-finalizing-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/wast/module_wast.mbt
  - ../../../../../src/validate/env.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./leaf-types-public-boundaries-and-sibling-split.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../type-un-finalizing/index.md
  - ../type-merging/index.md
  - ../unsubtyping/index.md
---

# Starshine `type-finalizing` port readiness and validation

## Why this bridge exists

The existing `type-finalizing` dossier explains the upstream pass and the current Starshine status. This page fills the remaining implementation-readiness gap: what exact local surfaces and validation lanes should a future Starshine port use?

Current answer: treat `type-finalizing` as a **future module/type-section pass**, not a HOT expression pass.

## Current local status to preserve

Today Starshine must keep doing all of the following:

- list `type-finalizing` only in `src/passes/optimize.mbt`, `pass_registry_boundary_only_names()`;
- reject direct `--pass type-finalizing` requests through the boundary-only error path;
- omit `type-finalizing` from `optimize_preset_passes(...)` and `shrink_preset_passes(...)`;
- keep `type-un-finalizing` spelling explicit as a local alias/sibling issue, because upstream spells the sibling `type-unfinalizing`;
- avoid implying that any current `src/passes/*.mbt` owner file implements type finality.

## Upstream behavior the port must match

Binaryen current-main still matches the `version_129` dossier contract:

1. Return immediately when GC is disabled.
2. Collect private heap types.
3. In finalizing mode, build an immediate-subtype index and keep only private types with no immediate subtypes.
4. In unfinalizing mode, use the same owner file but skip the leaf-only filter.
5. Toggle the selected type-builder entries with `setOpen(!finalize)`.
6. Run a global type rewrite so all dependent declarations and references remain coherent.

That means the Starshine port is primarily a type-graph rewrite problem. The hard part is not the boolean final/open bit; it is proving the selected heap types are private and then repairing every dependent reference after mutation.

## Local implementation surfaces

| Surface | Location | Future-port use |
| --- | --- | --- |
| Registry and request status | `src/passes/optimize.mbt`, `pass_registry_boundary_only_names()` and `run_hot_pipeline_expand_passes(...)` | Move from boundary-only to module-pass only when a real implementation and tests exist. |
| Type declaration model | `src/lib/types.mbt`, `TypeIdx`, `TypeMetadata`, `SubType(Bool, Array[TypeIdx], TypeMetadata, CompType)` | Source of final/open state and subtype edges. |
| Function and instruction type references | `src/lib/types.mbt`, function section, block type, call/call_ref, struct/array opcodes | Rewrite or revalidate all references after type-section changes. |
| Text parser | `src/wast/parser.mbt`, `(sub final ...)` handling | Positive and negative WAT fixtures should use existing final-subtype syntax. |
| Text lowering | `src/wast/lower_to_lib.mbt`, `SubType::new(td.final_, ...)` and descriptor final-subtype tests | Confirms finality can already enter the library model from WAT. |
| Text printer | `src/wast/module_wast.mbt`, `td.final_` printing | Golden WAT tests can assert visible final/open changes. |
| Validator | `src/validate/env.mbt`, `src/validate/typecheck.mbt` | Mandatory post-rewrite gate. |
| Binary roundtrip | `src/binary/encode.mbt`, `src/binary/decode.mbt` | Finality changes must survive binary encode/decode. |

## First safe slices

A future implementation should move in this order:

1. **No-op plumbing slice**: add the module-pass owner and dispatcher shape, but keep mutation disabled behind tests that prove direct requests are no longer miscategorized only when the pass is real.
2. **Analyzer-only slice**: compute candidate private heap types and immediate-subtype counts, emit no rewrite, and test the classification on public, private leaf, private non-leaf, and function-type cases.
3. **Narrow mutation slice**: finalize only private leaf types that have no public/export-visible exposure under the Starshine-defined visibility rule.
4. **Reference repair slice**: centralize the type remapper before broadening coverage; do not duplicate ad hoc rewrites for globals, locals, signatures, call sites, and GC instructions.
5. **Sibling slice**: decide whether local `type-un-finalizing` stays a separate hyphenated alias, gains upstream `type-unfinalizing`, or shares one local owner with a policy flag.

## Shape-to-validation checklist

| Shape | Expected result | Validation lane |
| --- | --- | --- |
| Module without GC type features | No-op, matching Binaryen's early return | Direct oracle test with `--type-finalizing`; Starshine should preserve the module. |
| Public/open heap type | Preserved open | WAT golden plus validator. |
| Public/final heap type | Preserved final | WAT golden plus validator. |
| Private leaf open heap type | Becomes final after the first mutating slice | WAT before/after and binary roundtrip. |
| Private non-leaf open heap type | Stays open in `type-finalizing` | Negative WAT fixture with child subtype. |
| Private function heap type leaf | Participates like other private leaf heap types | Function-type WAT fixture and validator. |
| Descriptor/described type pair | Only mutate when both the visibility and dependency rules remain valid | Descriptor final-subtype fixture through `wast_to_binary_module`. |
| Existing local/global/call/struct references | Still typecheck after global rewrite | Full module validation, not string-only output checks. |

## Binaryen oracle lanes

When implementation begins, compare against official Binaryen with at least:

- `wasm-opt --type-finalizing -S` for direct positive/negative WAT fixtures;
- `wasm-opt --type-finalizing --type-unfinalizing -S` and the reverse order for sibling interaction smoke tests;
- `bun fuzz compare-pass --pass type-finalizing ...` once the local harness accepts the active pass name;
- a focused binary roundtrip lane for final/open bit persistence.

Do not use no-DWARF `-O` / `-Os` preset parity as the primary acceptance test. This pass is outside Starshine's current open-world no-DWARF preset queue, so explicit-pass tests are the correct starting point.

## Known blockers and design questions

- **Private-type visibility.** Starshine needs a documented equivalent of Binaryen's `ModuleUtils::getPrivateHeapTypes(...)` before mutation. Exported, imported, JS-visible, descriptor-visible, and otherwise externally observable type references should be treated conservatively until proven safe.
- **Global type rewrite helper.** There is no named local equivalent of Binaryen's `GlobalTypeRewriter`; building one likely benefits multiple GC/type passes.
- **Sibling spelling.** The local registry uses `type-un-finalizing`, while Binaryen uses `type-unfinalizing`. Tests and docs should keep this explicit rather than hiding it behind prose.
- **Preset policy.** A future explicit pass can exist without adding it to optimize/shrink presets. Preset inclusion needs separate evidence.

## What counts as done for a first Starshine port

A minimal honest implementation would be done when:

- `type-finalizing` is categorized as an active module pass, not boundary-only;
- direct requests run the module pass and no longer use the boundary-only rejection;
- public and non-leaf negative fixtures match Binaryen;
- private leaf positive fixtures match Binaryen;
- validation runs after the rewrite;
- binary encode/decode preserves the finality change;
- docs update this page, [`./starshine-strategy.md`](./starshine-strategy.md), and [`../tracker.md`](../tracker.md) with actual implementation evidence.

Until then, keep the current boundary-only status visible.
