---
kind: concept
status: supported
last_reviewed: 2026-04-27
sources:
  - ../../../raw/binaryen/2026-04-27-type-un-finalizing-port-readiness-primary-sources.md
  - ../../../raw/research/0427-2026-04-27-type-un-finalizing-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-type-un-finalizing-primary-sources.md
  - ../../../raw/research/0314-2026-04-24-type-un-finalizing-primary-sources-and-starshine-followup.md
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
  - ./private-boundaries-sibling-split-and-no-leaf-rule.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../type-finalizing/starshine-port-readiness-and-validation.md
  - ../remove-unused-types/index.md
  - ../type-merging/index.md
  - ../unsubtyping/index.md
---

# Starshine `type-un-finalizing` port readiness and validation

## Why this bridge exists

The existing `type-un-finalizing` dossier explains the upstream pass and the current Starshine status. This page fills the remaining implementation-readiness gap: what exact local surfaces and validation lanes should a future Starshine port use?

Current answer: treat `type-un-finalizing` as a **future module/type-section pass**, not a HOT expression pass.

## Current local status to preserve

Today Starshine must keep doing all of the following:

- list `type-un-finalizing` only in `src/passes/optimize.mbt`, `pass_registry_boundary_only_names()`;
- reject direct `--pass type-un-finalizing` requests through the boundary-only error path;
- omit `type-un-finalizing` from `optimize_preset_passes(...)` and `shrink_preset_passes(...)`;
- keep the naming split explicit: Starshine currently spells it `type-un-finalizing`, while Binaryen spells it `type-unfinalizing`;
- avoid implying that any current `src/passes/*.mbt` owner file implements type finality or private-type reopening.

## Upstream behavior the port must match

Binaryen current-main still matches the `version_129` dossier contract:

1. Return immediately when GC is disabled.
2. Collect private heap types.
3. In unfinalizing mode, skip the immediate-subtype / leaf-only proof that `type-finalizing` uses.
4. Reopen every selected private heap type by toggling the type-builder entry with `setOpen(true)`.
5. Run a global type rewrite so all dependent declarations and references remain coherent.

That means the hard part of a Starshine port is not the boolean final/open bit. The hard parts are proving the selected heap types are private, applying the type-section change coherently, and validating every dependent reference afterward.

## Local implementation surfaces

| Surface | Location | Future-port use |
| --- | --- | --- |
| Registry and request status | `src/passes/optimize.mbt`, `pass_registry_boundary_only_names()` and `run_hot_pipeline_expand_passes(...)` | Move from boundary-only to module-pass only when a real implementation and tests exist. |
| Preset omission | `src/passes/optimize.mbt`, `optimize_preset_passes(...)` and `shrink_preset_passes(...)` | Keep the pass explicit-only unless a separate preset policy change is justified. |
| Type declaration model | `src/lib/types.mbt`, `TypeIdx`, `TypeMetadata`, `SubType(Bool, Array[TypeIdx], TypeMetadata, CompType)` | Source of final/open state and subtype edges. |
| Function and instruction type references | `src/lib/types.mbt`, function section, block type, call/call_ref, struct/array opcodes | Rewrite or revalidate all references after type-section changes. |
| Text parser | `src/wast/parser.mbt`, `(sub final ...)` handling | Positive and negative WAT fixtures should use existing final-subtype syntax. |
| Text lowering | `src/wast/lower_to_lib.mbt`, `SubType::new(td.final_, ...)` and descriptor final-subtype tests | Confirms finality can already enter the library model from WAT. |
| Text printer | `src/wast/module_wast.mbt`, `td.final_` printing | Golden WAT tests can assert visible final/open changes. |
| Validator | `src/validate/env.mbt`, `src/validate/typecheck.mbt` | Mandatory post-rewrite gate. |
| Binary roundtrip | `src/binary/encode.mbt`, `src/binary/decode.mbt` | Finality changes must survive binary encode/decode. |

## First safe slices

A future implementation should move in this order:

1. **Naming and no-op plumbing slice**: decide whether the active pass accepts only local `type-un-finalizing`, upstream `type-unfinalizing`, or both; add owner/dispatcher shape without mutation.
2. **Analyzer-only slice**: compute candidate private heap types, emit no rewrite, and test public, private leaf, private non-leaf, and function-type cases.
3. **Narrow mutation slice**: reopen only candidate private types under the Starshine-defined visibility rule; do not require a leaf-only proof.
4. **Reference repair slice**: centralize the type remapper before broadening coverage; do not duplicate ad hoc rewrites for globals, locals, signatures, call sites, and GC instructions.
5. **Sibling unification slice**: decide whether `type-finalizing` and `type-un-finalizing` share one local owner with a policy flag, matching Binaryen's shared `TypeFinalizing.cpp` engine.

## Shape-to-validation checklist

| Shape | Expected result | Validation lane |
| --- | --- | --- |
| Module without GC type features | No-op, matching Binaryen's early return | Direct oracle test with `--type-unfinalizing`; Starshine should preserve the module. |
| Public/open heap type | Preserved open | WAT golden plus validator. |
| Public/final heap type | Preserved final | WAT golden plus validator. |
| Private final leaf heap type | Becomes open | WAT before/after and binary roundtrip. |
| Private final non-leaf heap type | Becomes open; no leaf proof required | Negative-against-`type-finalizing` sibling fixture plus validator. |
| Private already-open heap type | Remains open | Idempotence fixture. |
| Private function heap type | Participates like other private heap types | Function-type WAT fixture and validator. |
| Descriptor/described type pair | Only mutate when both the visibility and dependency rules remain valid | Descriptor final-subtype fixture through `wast_to_binary_module`. |
| Existing local/global/call/struct references | Still typecheck after global rewrite | Full module validation, not string-only output checks. |

## Binaryen oracle lanes

When implementation begins, compare against official Binaryen with at least:

- `wasm-opt --type-unfinalizing -S` for direct positive/negative WAT fixtures;
- `wasm-opt --type-finalizing --type-unfinalizing -S` and the reverse order for sibling interaction smoke tests;
- `moon build --target native --release src/cmd` followed by `bun fuzz compare-pass --pass type-unfinalizing ... --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` or `--pass type-un-finalizing ...`, depending on the local harness spelling decision;
- a focused binary roundtrip lane for final/open bit persistence.

Do not use no-DWARF `-O` / `-Os` preset parity as the primary acceptance test. This pass is outside Starshine's current open-world no-DWARF preset queue, so explicit-pass tests are the correct starting point.

## Known blockers and design questions

- **Private-type visibility.** Starshine needs a documented equivalent of Binaryen's `ModuleUtils::getPrivateHeapTypes(...)` before mutation. Exported, imported, JS-visible, descriptor-visible, and otherwise externally observable type references should be treated conservatively until proven safe.
- **Global type rewrite helper.** There is no named local equivalent of Binaryen's `GlobalTypeRewriter`; building one likely benefits multiple GC/type passes.
- **Sibling spelling.** The local registry uses `type-un-finalizing`, while Binaryen uses `type-unfinalizing`. Tests and docs should keep this explicit rather than hiding it behind prose.
- **Sibling sharing.** Upstream implements both directions with one owner and one mode flag. Starshine should either mirror that shape or explain why it intentionally split the owner files.
- **Preset policy.** A future explicit pass can exist without adding it to optimize/shrink presets. Preset inclusion needs separate evidence.

## What counts as done for a first Starshine port

A minimal honest implementation would be done when:

- `type-un-finalizing` is categorized as an active module pass, not boundary-only;
- direct requests run the module pass and no longer use the boundary-only rejection;
- public-type preservation fixtures match Binaryen;
- private leaf and private non-leaf reopening fixtures match Binaryen;
- function heap-type fixtures match Binaryen;
- validation runs after the rewrite;
- binary encode/decode preserves the finality change;
- docs update this page, [`./starshine-strategy.md`](./starshine-strategy.md), [`../type-finalizing/starshine-port-readiness-and-validation.md`](../type-finalizing/starshine-port-readiness-and-validation.md), and [`../tracker.md`](../tracker.md) with actual implementation evidence.

Until then, keep the current boundary-only status visible.
