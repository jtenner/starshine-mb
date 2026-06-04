---
kind: concept
status: supported
last_reviewed: 2026-06-04
sources:
  - raw/wasm/2026-06-04-webassembly-proposal-status-refresh.md
  - raw/wasm/2026-06-04-stringref-proposal-current-refresh.md
  - raw/wasm/2026-06-04-linear-atomics-fence-unshared-reconciliation.md
  - raw/wasm/2026-06-04-linear-memory-threads-shared-memory-refresh.md
  - raw/wasm/2026-06-04-gc-type-subtyping-current-refresh.md
  - raw/wasm/2026-06-04-struct-atomic-get-sources.md
  - raw/wasm/2026-06-04-custom-descriptor-current-recheck.md
  - raw/wasm/2026-05-20-custom-descriptor-refgetdesc-exactness-refresh.md
  - ../../src/validate/gen_valid.mbt
related:
  - tooling/external-validator-adapters.md
  - fuzzing/generator-coverage-ledger.md
  - wast/string-instruction-authoring.md
  - wast/atomic-memory-instruction-authoring.md
  - custom-descriptors/static-fixtures.md
  - validate/module-validation-phases.md
---

# WebAssembly Feature Status And Proposal Boundaries

## Overview

Use this page when a wiki claim needs to say whether a WebAssembly feature is stable Core WebAssembly, a finished proposal, an active proposal, a Binaryen oracle behavior, or a Starshine-local surface. Those are related but different facts.

For a beginner: WebAssembly evolves by proposals. Some proposals become part of the core specification; others remain drafts for a long time; tools may implement draft pieces before they are stable; and Starshine may support one layer of a feature, such as binary decode, before another layer, such as WAST text parsing. This page gives maintainers the vocabulary for that split.

The current primary-source bridge is [`raw/wasm/2026-06-04-webassembly-proposal-status-refresh.md`](raw/wasm/2026-06-04-webassembly-proposal-status-refresh.md). It rechecked the official WebAssembly Core 3.0 spec site, the official WebAssembly proposals repository, the finished-proposals table, the CG process phases document, and Starshine's local `GenValidProposalFeature` gate vocabulary.

## Evidence Tiers

| Claim type | Primary source to cite first | What it proves | What it does **not** prove |
| --- | --- | --- | --- |
| Stable Core WebAssembly 3.0 | Official Core spec pages | The current core syntax, binary, validation, and execution model. | That Starshine has every parser, printer, fuzzer, or pass surface implemented. |
| Finished proposal | WebAssembly finished-proposals table plus Core pages where applicable | The feature should no longer be taught as merely experimental proposal work. | That older tools or local WAST paths accept it by default. |
| Active proposal | Proposal repository / proposal draft / proposal tracker | The draft design, phase, and feature-specific rules. | That the feature is stable Core, or that Starshine implements the whole draft. |
| Binaryen oracle behavior | Binaryen release tag, source file, lit test, or release note | What Binaryen does for a pass, parser, or validator surface. | That Starshine should expose identical user-facing CLI/WAST behavior without a local policy decision. |
| Starshine support | Local source, tests, raw notes, and focused wiki pages | The exact implemented layer: core AST, binary, WAST, validator, generator, pass, or command harness. | That the behavior is standardized unless paired with upstream evidence. |

## Current High-Value Status Map

This table is intentionally small. It is a routing map, not a replacement for focused pages.

| Feature family | Current wiki status rule | Starshine routing |
| --- | --- | --- |
| Ordinary Core 3.0 instruction families such as `ref.test`, `ref.cast`, `call_ref`, `br_on_*`, tail calls, exception instructions, SIMD, and memory64/table64 resource types | Treat the official Core 3.0 pages as standards evidence. If Starshine lacks a WAST keyword, parser arm, or complete validator widening, call that a **local layer gap**, not a proposal gap. | See [`wast/reference-instruction-authoring.md`](wast/reference-instruction-authoring.md), [`wast/function-call-and-module-authoring.md`](wast/function-call-and-module-authoring.md), [`wast/tail-call-authoring.md`](wast/tail-call-authoring.md), [`wast/exception-tag-authoring.md`](wast/exception-tag-authoring.md), [`wast/simd-authoring.md`](wast/simd-authoring.md), and [`validate/memory-table-address-widths.md`](validate/memory-table-address-widths.md). |
| Reference-Typed Strings / stringref | Keep the active Phase-1 proposal caveat visible. Starshine supports a narrow proposal/local subset, not the full proposal and not stable Core 3.0. | See [`wast/string-instruction-authoring.md`](wast/string-instruction-authoring.md), [`strings/string-const-surface.md`](strings/string-const-surface.md), and [`raw/wasm/2026-06-04-stringref-proposal-current-refresh.md`](raw/wasm/2026-06-04-stringref-proposal-current-refresh.md). |
| Linear-memory threads atomics and shared memories | Keep the threads/proposal source boundary visible. Starshine has core/binary/validator/generator support for the current local subset where `MemArg`-based atomics require a shared selected memory, while standalone `atomic.fence` has no memory operand or sharedness check. High-level WAST text for linear-memory atomics is still absent. | See [`wast/atomic-memory-instruction-authoring.md`](wast/atomic-memory-instruction-authoring.md), [`validate/resource-sections-and-limits.md`](validate/resource-sections-and-limits.md), [`raw/wasm/2026-06-04-linear-atomics-fence-unshared-reconciliation.md`](raw/wasm/2026-06-04-linear-atomics-fence-unshared-reconciliation.md), and [`raw/wasm/2026-06-04-linear-memory-threads-shared-memory-refresh.md`](raw/wasm/2026-06-04-linear-memory-threads-shared-memory-refresh.md). |
| Shared-GC aggregate atomics | Route through shared-everything / GC aggregate evidence, not through `MemArg`-based linear-memory atomics. Starshine currently documents only `struct.atomic.get*`, not the full aggregate atomic family. | See [`wast/gc-aggregate-instruction-authoring.md`](wast/gc-aggregate-instruction-authoring.md), [`wast/atomic-memory-instruction-authoring.md`](wast/atomic-memory-instruction-authoring.md), and [`raw/wasm/2026-06-04-struct-atomic-get-sources.md`](raw/wasm/2026-06-04-struct-atomic-get-sources.md). |
| Custom descriptors and exact refs | Keep active proposal status visible and distinguish proposal struct metadata from Starshine-local broader type metadata. The 2026-06-04 recheck keeps this at Phase 3 and still struct-oriented. | See [`custom-descriptors/static-fixtures.md`](custom-descriptors/static-fixtures.md), [`custom-descriptors/ref-get-desc-fixture-path.md`](custom-descriptors/ref-get-desc-fixture-path.md), [`custom-descriptors/exact-reference-equivalence.md`](custom-descriptors/exact-reference-equivalence.md), and [`raw/wasm/2026-06-04-custom-descriptor-current-recheck.md`](raw/wasm/2026-06-04-custom-descriptor-current-recheck.md). |
| External validator disagreements | Do not classify feature-default or proposal-support disagreements as Starshine bugs without source review. | Use [`tooling/external-validator-adapters.md`](tooling/external-validator-adapters.md) and record `proposal-gap`, `unsupported-feature`, or tool failure separately from Starshine decode/validation disagreements. |
| GenValid feature gates | Treat `GenValidProposalFeature` as local fuzzing vocabulary. It groups toggles needed to generate Starshine-valid surfaces; it is not a standards-status authority. | See [`fuzzing/generator-coverage-ledger.md`](fuzzing/generator-coverage-ledger.md) and [`../../src/validate/gen_valid.mbt`](../../src/validate/gen_valid.mbt). |

## How To Phrase Claims

Prefer precise layer claims:

- “Core 3.0 lists this instruction family, but Starshine WAST text does not yet expose it.”
- “Starshine binary decode/encode and validation support this proposal-facing subset.”
- “This is active proposal evidence; do not describe it as stable Core WebAssembly 3.0.”
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

- Current status bridge: [`raw/wasm/2026-06-04-webassembly-proposal-status-refresh.md`](raw/wasm/2026-06-04-webassembly-proposal-status-refresh.md)
- Local generator gate vocabulary: [`../../src/validate/gen_valid.mbt`](../../src/validate/gen_valid.mbt)
- Focused companion pages: [`tooling/external-validator-adapters.md`](tooling/external-validator-adapters.md), [`fuzzing/generator-coverage-ledger.md`](fuzzing/generator-coverage-ledger.md), [`wast/string-instruction-authoring.md`](wast/string-instruction-authoring.md), [`wast/atomic-memory-instruction-authoring.md`](wast/atomic-memory-instruction-authoring.md), [`custom-descriptors/static-fixtures.md`](custom-descriptors/static-fixtures.md), [`validate/module-validation-phases.md`](validate/module-validation-phases.md)
