---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - raw/wasm/2026-06-05-js-string-builtins-boundary-refresh.md
  - raw/wasm/2026-06-05-component-model-boundary-refresh.md
  - raw/wasm/2026-06-05-custom-page-sizes-boundary-refresh.md
  - raw/wasm/2026-06-05-memory-control-boundary-refresh.md
  - raw/wasm/2026-06-05-webassembly-feature-dashboard-routing.md
  - raw/wasm/2026-06-05-wat-numeric-data-segments-routing.md
  - raw/wasm/2026-06-05-code-metadata-branch-hint-current-refresh.md
  - raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md
  - raw/wasm/2026-06-04-webassembly-proposal-status-current-recheck.md
  - raw/wasm/2026-06-04-webassembly-proposal-status-refresh.md
  - raw/wasm/2026-06-04-relaxed-simd-status-refresh.md
  - raw/wasm/2026-06-04-stringref-proposal-current-refresh.md
  - raw/wasm/2026-06-04-linear-atomics-fence-unshared-reconciliation.md
  - raw/wasm/2026-06-04-linear-memory-threads-shared-memory-refresh.md
  - raw/wasm/2026-06-04-gc-type-subtyping-current-refresh.md
  - raw/wasm/2026-06-04-struct-atomic-get-sources.md
  - raw/wasm/2026-06-05-custom-descriptor-instruction-surface-refresh.md
  - raw/wasm/2026-06-04-custom-descriptor-current-recheck.md
  - raw/wasm/2026-05-20-custom-descriptor-refgetdesc-exactness-refresh.md
  - ../../src/validate/gen_valid.mbt
related:
  - wasm-js-string-builtins-boundary.md
  - wasm-component-model-boundary.md
  - wasm-custom-page-sizes-boundary.md
  - wasm-memory-control-boundary.md
  - tooling/external-validator-adapters.md
  - fuzzing/generator-coverage-ledger.md
  - wast/string-instruction-authoring.md
  - wast/atomic-memory-instruction-authoring.md
  - wast/data-segment-authoring.md
  - custom-descriptors/descriptor-instruction-surface.md
  - custom-descriptors/static-fixtures.md
  - wast/code-metadata-and-function-annotations.md
  - validate/module-validation-phases.md
---

# WebAssembly Feature Status And Proposal Boundaries

## Overview

Use this page when a wiki claim needs to say whether a WebAssembly feature is stable Core WebAssembly, a finished proposal, an active proposal, a Binaryen oracle behavior, or a Starshine-local surface. Those are related but different facts.

For a beginner: WebAssembly evolves by proposals. Some proposals become part of the core specification; others remain drafts for a long time; tools may implement draft pieces before they are stable; and Starshine may support one layer of a feature, such as binary decode, before another layer, such as WAST text parsing. This page gives maintainers the vocabulary for that split.

The current primary-source bridge for active-proposal routing is [`raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md`](raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md). It supplements the earlier relaxed-atomics-focused recheck [`raw/wasm/2026-06-04-webassembly-proposal-status-current-recheck.md`](raw/wasm/2026-06-04-webassembly-proposal-status-current-recheck.md) and broad bridge [`raw/wasm/2026-06-04-webassembly-proposal-status-refresh.md`](raw/wasm/2026-06-04-webassembly-proposal-status-refresh.md). Together they rechecked the official WebAssembly Core 3.0 spec site, the official WebAssembly proposals repository, the finished-proposals table, the CG process phases document, focused Relaxed Atomics and Custom Descriptors proposal repositories, and Starshine's local `GenValidProposalFeature` gate vocabulary. The active-proposal routing update is broader than one feature now: Phase 4 rows are still active until they are finished/Core, Custom Descriptors remains Phase 3 and struct-oriented, `Relaxed Atomics` and `Numeric Values in WAT Data Segments` are active Phase-2 proposals, and Phase-1 Reference-Typed Strings must stay separate from Starshine's narrow local string subset.

The 2026-06-05 JS String Builtins bridge, [`raw/wasm/2026-06-05-js-string-builtins-boundary-refresh.md`](raw/wasm/2026-06-05-js-string-builtins-boundary-refresh.md), adds one easy-to-misroute split: **JS String Builtins** is a finished/Core-3.0 + JavaScript API feature, while **Reference-Typed Strings / `stringref`** remains active Phase 1 and **JS Primitive Builtins** / **JS Text Encoding Builtins** remain separate active proposal rows. The focused page [`wasm-js-string-builtins-boundary.md`](wasm-js-string-builtins-boundary.md) owns the routing between `builtins: ["js-string"]`, `wasm:js-string` imports, `importedStringConstants`, Starshine's local `StringRefsSec`, and the Binaryen string-lowering/lifting dossiers.

The 2026-06-05 Memory Control bridge, [`raw/wasm/2026-06-05-memory-control-boundary-refresh.md`](raw/wasm/2026-06-05-memory-control-boundary-refresh.md), adds another proposal boundary: **Memory Control** is still active Phase 1 and covers discard/commit/protection/mapping/BYOB-style memory-management ideas, not current Core `memory.grow`, `memory.fill`, bulk memory, memory64, shared memory, or Custom Page Sizes support. The focused page [`wasm-memory-control-boundary.md`](wasm-memory-control-boundary.md) owns that split.

A separate 2026-06-05 bridge, [`raw/wasm/2026-06-05-webassembly-feature-dashboard-routing.md`](raw/wasm/2026-06-05-webassembly-feature-dashboard-routing.md), keeps implementation-support dashboards in their own evidence tier. Browser/runtime support tables can help choose an engine for runtime smoke tests, but they are not standards authority, Starshine source evidence, or proof of what `wasm-tools`, WABT, or Binaryen accepted under a specific command line. Treat this bridge as the living supersession for older raw manifests that used the `webassembly.org/features/` page as a finished-proposals shorthand: use the GitHub finished-proposals table or Core pages for finished/Core claims, and use the feature dashboard only for engine-support hints.

## Evidence Tiers

| Claim type | Primary source to cite first | What it proves | What it does **not** prove |
| --- | --- | --- | --- |
| Stable Core WebAssembly 3.0 | Official Core spec pages | The current core syntax, binary, validation, and execution model. | That Starshine has every parser, printer, fuzzer, or pass surface implemented. |
| Finished proposal | WebAssembly finished-proposals table plus Core pages where applicable | The feature should no longer be taught as merely experimental proposal work. | That older tools or local WAST paths accept it by default. |
| Active proposal | Proposal repository / proposal draft / proposal tracker | The draft design, phase, and feature-specific rules. | That the feature is stable Core, or that Starshine implements the whole draft. |
| Binaryen oracle behavior | Binaryen release tag, source file, lit test, or release note | What Binaryen does for a pass, parser, or validator surface. | That Starshine should expose identical user-facing CLI/WAST behavior without a local policy decision. |
| Starshine support | Local source, tests, raw notes, and focused wiki pages | The exact implemented layer: core AST, binary, WAST, validator, generator, pass, or command harness. | That the behavior is standardized unless paired with upstream evidence. |
| Implementation support dashboard | Browser/runtime feature-status page, engine release note, or runtime compatibility table | Which engines may support a feature and are worth trying for runtime repros. | That the feature is Core, that Starshine implements it, or that `wasm-tools` / WABT / Binaryen accepted it under this repo's adapter commands. |

## Current High-Value Status Map

This table is intentionally small. It is a routing map, not a replacement for focused pages.

| Feature family | Current wiki status rule | Starshine routing |
| --- | --- | --- |
| Ordinary Core 3.0 instruction families such as `ref.test`, `ref.cast`, `call_ref`, `br_on_*`, tail calls, exception instructions, SIMD, and memory64/table64 resource types | Treat the official Core 3.0 pages as standards evidence. If Starshine lacks a WAST keyword, parser arm, or complete validator widening, call that a **local layer gap**, not a proposal gap. | See [`wast/reference-instruction-authoring.md`](wast/reference-instruction-authoring.md), [`wast/function-call-and-module-authoring.md`](wast/function-call-and-module-authoring.md), [`wast/tail-call-authoring.md`](wast/tail-call-authoring.md), [`wast/exception-tag-authoring.md`](wast/exception-tag-authoring.md), [`wast/simd-authoring.md`](wast/simd-authoring.md), and [`validate/memory-table-address-widths.md`](validate/memory-table-address-widths.md). |
| Relaxed SIMD | Treat relaxed SIMD as Core 3.0 / finished-proposal instruction syntax, not an active proposal gap, when the claim is about official text, binary, validation, or local parser/typechecker support. Still keep the relaxed-semantics caveat visible: results may be implementation-dependent within the proposal's allowed set, so default-portable generator profiles and Binaryen-oracle lanes keep separate relaxed-SIMD gates. | See [`wast/simd-authoring.md`](wast/simd-authoring.md), [`fuzzing/generator-coverage-ledger.md`](fuzzing/generator-coverage-ledger.md), [`binaryen/passes/remove-relaxed-simd/index.md`](binaryen/passes/remove-relaxed-simd/index.md), and [`raw/wasm/2026-06-04-relaxed-simd-status-refresh.md`](raw/wasm/2026-06-04-relaxed-simd-status-refresh.md). |
| Custom annotation syntax and branch hints | Treat official `@name` / `@custom` text annotation syntax and `metadata.code.branch_hint` as finished/Core-3.0 metadata surfaces, not active proposal gaps. Keep `Compilation Hints` separate as an active Phase-2 proposal, and keep Starshine's current function/import-only `(@...)` lane labeled local. | See [`wast/code-metadata-and-function-annotations.md`](wast/code-metadata-and-function-annotations.md), [`binary/custom-and-name-sections.md`](binary/custom-and-name-sections.md), and [`raw/wasm/2026-06-05-code-metadata-branch-hint-current-refresh.md`](raw/wasm/2026-06-05-code-metadata-branch-hint-current-refresh.md). |
| JS String Builtins / `wasm:js-string` | Treat JS String Builtins as a finished Core-3.0 + JavaScript API feature, not as proof that every `stringref` instruction is stable or locally implemented. It covers host compile options, reserved `wasm:js-string` helper imports, and `importedStringConstants`; keep it separate from Starshine's in-module `StringRefsSec`. | See [`wasm-js-string-builtins-boundary.md`](wasm-js-string-builtins-boundary.md), [`tooling/node-package-surface.md`](tooling/node-package-surface.md), [`binaryen/passes/string-lowering/index.md`](binaryen/passes/string-lowering/index.md), [`binaryen/passes/string-lifting/index.md`](binaryen/passes/string-lifting/index.md), and [`raw/wasm/2026-06-05-js-string-builtins-boundary-refresh.md`](raw/wasm/2026-06-05-js-string-builtins-boundary-refresh.md). |
| Reference-Typed Strings / stringref | Keep the active Phase-1 proposal caveat visible. Starshine supports a narrow proposal/local subset, not the full proposal and not stable Core 3.0. Do not let the finished JS String Builtins row erase this active-proposal status. | See [`wast/string-instruction-authoring.md`](wast/string-instruction-authoring.md), [`strings/string-const-surface.md`](strings/string-const-surface.md), [`wasm-js-string-builtins-boundary.md`](wasm-js-string-builtins-boundary.md), and [`raw/wasm/2026-06-04-stringref-proposal-current-refresh.md`](raw/wasm/2026-06-04-stringref-proposal-current-refresh.md). |
| Numeric Values in WAT Data Segments | Keep this as active Phase-2 proposal text syntax. Starshine WAST data payloads are currently string-token concatenation; core/binary data bytes can model equivalent payloads, but that is not parser/printer support for proposal `(i8 ...)`, `(i32 ...)`, `(f32 ...)`, or `v128` groups. | See [`wast/data-segment-authoring.md`](wast/data-segment-authoring.md), [`wast/text-surface-gap-ledger.md`](wast/text-surface-gap-ledger.md), and [`raw/wasm/2026-06-05-wat-numeric-data-segments-routing.md`](raw/wasm/2026-06-05-wat-numeric-data-segments-routing.md). |
| Linear-memory threads atomics and shared memories | Keep the threads/proposal source boundary visible. Starshine has core/binary/validator/generator support for the current local subset where `MemArg`-based atomics require a shared selected memory, while standalone `atomic.fence` has no memory operand or sharedness check. High-level WAST text for linear-memory atomics is still absent. | See [`wast/atomic-memory-instruction-authoring.md`](wast/atomic-memory-instruction-authoring.md), [`validate/resource-sections-and-limits.md`](validate/resource-sections-and-limits.md), [`raw/wasm/2026-06-04-linear-atomics-fence-unshared-reconciliation.md`](raw/wasm/2026-06-04-linear-atomics-fence-unshared-reconciliation.md), and [`raw/wasm/2026-06-04-linear-memory-threads-shared-memory-refresh.md`](raw/wasm/2026-06-04-linear-memory-threads-shared-memory-refresh.md). |
| Memory Control | Treat Memory Control as active Phase-1 proposal evidence for runtime memory-management capabilities such as `memory.discard`, lazy commit, static protection, mappable memory, virtual mode, and BYOB host memory. Starshine currently has no instruction variant, binary/WAST/validator/generator support, or pass effect model for these surfaces. Keep it separate from `memory.fill`, `data.drop`, memory64, multi-memory, shared memories, and Custom Page Sizes. | See [`wasm-memory-control-boundary.md`](wasm-memory-control-boundary.md), [`wast/memory-instruction-authoring.md`](wast/memory-instruction-authoring.md), [`binary/instruction-and-expression-encoding.md`](binary/instruction-and-expression-encoding.md), and [`raw/wasm/2026-06-05-memory-control-boundary-refresh.md`](raw/wasm/2026-06-05-memory-control-boundary-refresh.md). |
| Custom Page Sizes | Treat custom page sizes as active-proposal memory-type evidence. Starshine currently has no page-size field in `MemType`, no binary custom-page-size flag/immediate handling, no validator or external-type matching dimension, and no WAST declaration syntax. Keep it separate from memory64 address width, shared-memory support, and Memory Control runtime operations. | See [`wasm-custom-page-sizes-boundary.md`](wasm-custom-page-sizes-boundary.md), [`binary/type-table-memory-global-tag-sections.md`](binary/type-table-memory-global-tag-sections.md), [`validate/resource-sections-and-limits.md`](validate/resource-sections-and-limits.md), and [`raw/wasm/2026-06-05-custom-page-sizes-boundary-refresh.md`](raw/wasm/2026-06-05-custom-page-sizes-boundary-refresh.md). |
| Relaxed Atomics | Treat relaxed atomics as a separate active Phase-2 proposal. Do not conflate it with finished/Core relaxed SIMD, and do not treat Starshine's current `AtomicsFeature` generator gate as relaxed-atomics evidence. No Starshine AST, binary, validator, generator, or WAST support is documented until a focused source/implementation slice lands. | See [`raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md`](raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md) plus the focused [`raw/wasm/2026-06-04-webassembly-proposal-status-current-recheck.md`](raw/wasm/2026-06-04-webassembly-proposal-status-current-recheck.md), and keep future fixture claims routed through [`wast/atomic-memory-instruction-authoring.md`](wast/atomic-memory-instruction-authoring.md) only as a current non-support caveat. |
| Shared-GC aggregate atomics | Route through shared-everything / GC aggregate evidence, not through `MemArg`-based linear-memory atomics. Starshine currently documents only `struct.atomic.get*`, not the full aggregate atomic family. | See [`wast/gc-aggregate-instruction-authoring.md`](wast/gc-aggregate-instruction-authoring.md), [`wast/atomic-memory-instruction-authoring.md`](wast/atomic-memory-instruction-authoring.md), and [`raw/wasm/2026-06-04-struct-atomic-get-sources.md`](raw/wasm/2026-06-04-struct-atomic-get-sources.md). |
| Custom descriptors and exact refs | Keep active proposal status visible and distinguish proposal struct metadata from Starshine-local broader type metadata. The 2026-06-05 instruction-surface bridge keeps this at Phase 3 and still struct-oriented, with current Starshine support for descriptor-aware allocation, `ref.get_desc`, and non-branch descriptor predicate/cast forms only. | See [`custom-descriptors/descriptor-instruction-surface.md`](custom-descriptors/descriptor-instruction-surface.md), [`custom-descriptors/static-fixtures.md`](custom-descriptors/static-fixtures.md), [`custom-descriptors/ref-get-desc-fixture-path.md`](custom-descriptors/ref-get-desc-fixture-path.md), [`custom-descriptors/exact-reference-equivalence.md`](custom-descriptors/exact-reference-equivalence.md), [`raw/wasm/2026-06-05-custom-descriptor-instruction-surface-refresh.md`](raw/wasm/2026-06-05-custom-descriptor-instruction-surface-refresh.md), and [`raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md`](raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md). |
| Component Model / WIT / Canonical ABI | Treat Component Model as an active Phase-1 proposal row and a higher-level artifact boundary, not as Core module support. Starshine currently has Core module/WAST/binary/validation/generator surfaces only: no component binary or text parser, no WIT/world model, no Canonical ABI lift/lower representation, and no Node package component API. Embedded core modules can be tested as core modules only after extraction. | See [`wasm-component-model-boundary.md`](wasm-component-model-boundary.md) and [`raw/wasm/2026-06-05-component-model-boundary-refresh.md`](raw/wasm/2026-06-05-component-model-boundary-refresh.md). |
| Other active proposal tracker rows | Treat Phase 4 / 3 / 2 / 1 rows as current standards-process routing, not Starshine implementation evidence. The 2026-06-04 snapshot calls out examples that are easy to overroute locally: JSPI, Threads, Stack Switching, Wide Arithmetic, Compilation Hints, Reference-Typed Strings, Shared-Everything Threads, More Array Constructors, Memory Control, and JS Text Encoding Builtins. The 2026-06-05 numeric data-segment bridge adds `Numeric Values in WAT Data Segments` as a focused Phase-2 WAST text-syntax example, the Component Model bridge now owns that Phase-1 boundary, Custom Page Sizes now owns its memory-type proposal boundary, and Memory Control now owns the discard/commit/protection/mapping runtime-memory boundary. Branch Hinting and Custom Annotation Syntax are no longer routed through this active-row bucket because the current finished-proposals table lists them under Core 3.0. | Use [`raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md`](raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md) as the routing bridge, then require focused code/tests/wiki evidence before claiming local WAST, binary, validator, generator, or pass support. |
| Implementation support dashboards | Treat browser/runtime feature tables as implementation-availability hints only. They are useful for choosing candidate engines for runtime smoke tests, but they are not the standards-status source and not local Starshine or external-validator adapter evidence. | Use [`raw/wasm/2026-06-05-webassembly-feature-dashboard-routing.md`](raw/wasm/2026-06-05-webassembly-feature-dashboard-routing.md) when a feature-status claim risks conflating browser support with Core/proposal status, Starshine support, or `wasm-tools` / WABT / Binaryen command results. |
| External validator disagreements | Do not classify feature-default or proposal-support disagreements as Starshine bugs without source review. | Use [`tooling/external-validator-adapters.md`](tooling/external-validator-adapters.md) and record `proposal-gap`, `unsupported-feature`, or tool failure separately from Starshine decode/validation disagreements. |
| GenValid feature gates | Treat `GenValidProposalFeature` as local fuzzing vocabulary. It groups toggles needed to generate Starshine-valid surfaces; it is not a standards-status authority. | See [`fuzzing/generator-coverage-ledger.md`](fuzzing/generator-coverage-ledger.md) and [`../../src/validate/gen_valid.mbt`](../../src/validate/gen_valid.mbt). |

## How To Phrase Claims

Prefer precise layer claims:

- “Core 3.0 lists this instruction family, but Starshine WAST text does not yet expose it.”
- “Starshine binary decode/encode and validation support this proposal-facing subset.”
- “This is active proposal evidence; do not describe it as stable Core WebAssembly 3.0.”
- “Relaxed SIMD is Core 3.0 instruction syntax, but default-portable generator and Binaryen-oracle lanes intentionally keep it behind a relaxed-SIMD feature/profile gate.”
- “Branch hints are Core-3.0 metadata, but Starshine's current `(@...)` WAST lane is still function/import-only and does not parse expression-level `@metadata.code.branch_hint`.”
- “Relaxed Atomics is an active Phase-2 proposal; Starshine's existing atomics support and `AtomicsFeature` gate are not evidence for that proposal.”
- “Numeric data-segment groups are active Phase-2 WAT proposal syntax; Starshine's current `(data ...)` parser still consumes string payload tokens only.”
- “Custom Page Sizes is active proposal memory-type evidence; current Starshine `MemType` has address width and sharedness but no page-size field.”
- “Memory Control is active Phase-1 runtime memory-management proposal evidence; current Starshine `memory.fill`, `data.drop`, memory64, shared-memory, and Custom Page Sizes support do not implement `memory.discard` or related discard/commit/protection/mapping ideas.”
- “JS String Builtins is finished/Core-3.0 + JS API behavior; Reference-Typed Strings is still active Phase 1, and Starshine's `StringRefsSec` is not the same as the JS API `importedStringConstants` option.”
- “Custom Descriptors is active Phase 3 and struct-oriented; Starshine's broader array metadata parsing/lowering is local compatibility evidence, not proposal-standard evidence.”
- “The Component Model / WIT / Canonical ABI layer is outside Starshine's current Core module pipeline; extracted embedded core modules can be tested as core modules, not as component support.”
- “A proposal tracker row is not a local support claim. Name the Starshine layer—WAST, binary, validator, generator, pass, CLI—or say there is no documented local support yet.”
- “A browser/runtime support dashboard is implementation availability evidence, not a Core/proposal status source and not proof that Starshine or an external validator adapter accepts the feature.”
- “This is Binaryen pass-oracle behavior; local CLI or preset behavior still needs Starshine registry/dispatcher evidence.”
- “This fuzzer profile enables a proposal-shaped surface; it does not prove external tools accept the same module under their default feature flags.”

Avoid vague phrases such as “Wasm supports it” unless the sentence names the source layer. The useful question is usually: **which Wasm source, which Starshine layer, and which validation/signoff path?**

## Maintenance Checklist

When changing a feature-status claim:

1. Check the focused local page first. Prefer updating an existing page over creating another status page.
2. Recheck the official Core page, proposal page, proposals tracker, or Binaryen source that actually owns the claim.
3. Update the raw source bridge when the source status changed or when a new official source is needed.
4. Record any split explicitly: stable-vs-proposal, official-vs-local, binary-vs-WAST, validator-vs-runtime, or Starshine-vs-Binaryen.
5. If an external tool disagrees, classify the case through the adapter ladder before treating it as a bug.
6. Update [`index.md`](index.md) and [`log.md`](log.md) for durable wording changes.

## Sources

- JS String Builtins boundary refresh: [`raw/wasm/2026-06-05-js-string-builtins-boundary-refresh.md`](raw/wasm/2026-06-05-js-string-builtins-boundary-refresh.md), [`wasm-js-string-builtins-boundary.md`](wasm-js-string-builtins-boundary.md)
- Component Model boundary refresh: [`raw/wasm/2026-06-05-component-model-boundary-refresh.md`](raw/wasm/2026-06-05-component-model-boundary-refresh.md), [`wasm-component-model-boundary.md`](wasm-component-model-boundary.md)
- Custom Page Sizes boundary refresh: [`raw/wasm/2026-06-05-custom-page-sizes-boundary-refresh.md`](raw/wasm/2026-06-05-custom-page-sizes-boundary-refresh.md), [`wasm-custom-page-sizes-boundary.md`](wasm-custom-page-sizes-boundary.md)
- Memory Control boundary refresh: [`raw/wasm/2026-06-05-memory-control-boundary-refresh.md`](raw/wasm/2026-06-05-memory-control-boundary-refresh.md), [`wasm-memory-control-boundary.md`](wasm-memory-control-boundary.md)
- Feature-dashboard routing: [`raw/wasm/2026-06-05-webassembly-feature-dashboard-routing.md`](raw/wasm/2026-06-05-webassembly-feature-dashboard-routing.md)
- Numeric WAT data-segment proposal routing: [`raw/wasm/2026-06-05-wat-numeric-data-segments-routing.md`](raw/wasm/2026-06-05-wat-numeric-data-segments-routing.md)
- Code-metadata and branch-hint status refresh: [`raw/wasm/2026-06-05-code-metadata-branch-hint-current-refresh.md`](raw/wasm/2026-06-05-code-metadata-branch-hint-current-refresh.md)
- Active proposal routing refresh: [`raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md`](raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md)
- Relaxed-atomics-focused status recheck: [`raw/wasm/2026-06-04-webassembly-proposal-status-current-recheck.md`](raw/wasm/2026-06-04-webassembly-proposal-status-current-recheck.md)
- Earlier same-day status bridge: [`raw/wasm/2026-06-04-webassembly-proposal-status-refresh.md`](raw/wasm/2026-06-04-webassembly-proposal-status-refresh.md)
- Relaxed SIMD status bridge: [`raw/wasm/2026-06-04-relaxed-simd-status-refresh.md`](raw/wasm/2026-06-04-relaxed-simd-status-refresh.md)
- Local generator gate vocabulary: [`../../src/validate/gen_valid.mbt`](../../src/validate/gen_valid.mbt)
- Custom-descriptor instruction bridge: [`raw/wasm/2026-06-05-custom-descriptor-instruction-surface-refresh.md`](raw/wasm/2026-06-05-custom-descriptor-instruction-surface-refresh.md), [`custom-descriptors/descriptor-instruction-surface.md`](custom-descriptors/descriptor-instruction-surface.md)
- Focused companion pages: [`tooling/external-validator-adapters.md`](tooling/external-validator-adapters.md), [`fuzzing/generator-coverage-ledger.md`](fuzzing/generator-coverage-ledger.md), [`wast/string-instruction-authoring.md`](wast/string-instruction-authoring.md), [`wast/atomic-memory-instruction-authoring.md`](wast/atomic-memory-instruction-authoring.md), [`custom-descriptors/static-fixtures.md`](custom-descriptors/static-fixtures.md), [`validate/module-validation-phases.md`](validate/module-validation-phases.md)
