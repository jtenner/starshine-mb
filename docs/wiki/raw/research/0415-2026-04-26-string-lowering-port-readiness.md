---
kind: research
status: supported
last_reviewed: 2026-04-26
sources:
  - ../binaryen/2026-04-26-string-lowering-port-readiness-primary-sources.md
  - ../binaryen/2026-04-24-string-lowering-primary-sources.md
  - ../../binaryen/passes/string-lowering/index.md
  - ../../binaryen/passes/string-lowering/starshine-port-readiness-and-validation.md
---

# `string-lowering` port-readiness follow-up

## Question

The existing `string-lowering` dossier had overview, strategy, shape, source-map, and Starshine-status pages, but it still left a future Starshine implementer to infer the safe first slice and validation ladder.

This follow-up asks: what should the first local `string-lowering` work prove, and where are the exact Starshine surfaces that make or block a faithful port?

## Findings

- Binaryen `StringLowering.cpp` still composes the pass as `StringGathering` prefix, type lowering, defining-global import conversion, helper-import call replacement, refinalization, and Strings feature removal.
- Current Binaryen `main` has no teaching-relevant drift from the checked `version_129` contract for phase order, helper import names, JSON/magic-import behavior, or unsupported op boundaries.
- The helper ABI is not arbitrary: Binaryen uses the `wasm:js-string` namespace that is also described in the JS string builtins proposal.
- Starshine currently treats all three public lowering names as unknown, not boundary-only or removed: `string-lowering`, `string-lowering-magic-imports`, and `string-lowering-magic-imports-assert` are absent from the local pass registry arrays.
- Starshine already parses, lowers, validates, encodes, HOT-lifts, and HOT-lowers `string.const`, and it already has some array new/encode opcodes that Binaryen's `string-lowering` source still marks unsupported.
- Starshine does not yet expose the full Binaryen-lowered source-op surface (`concat`, eq/test/measure/get/slice families), so a future pass cannot be only a module rewrite over a complete local string instruction vocabulary.

## Durable wiki changes made

- Added raw primary-source bridge `docs/wiki/raw/binaryen/2026-04-26-string-lowering-port-readiness-primary-sources.md`.
- Added living bridge `docs/wiki/binaryen/passes/string-lowering/starshine-port-readiness-and-validation.md`.
- Refreshed the `string-lowering` landing page, Binaryen strategy, WAT shapes, Starshine strategy, pass index, tracker, main wiki index, and wiki log so the new bridge is discoverable.

## Recommended future implementation ladder

1. Registry honesty: decide whether the three Binaryen public names should become boundary-only, removed, or active module-pass names.
2. No-op analyzer: detect string-lowering candidates and unsupported surfaces without mutating.
3. Source-op vocabulary: decide whether to add every Binaryen-supported input string op before mutation or to explicitly scope a smaller first slice.
4. Default JSON mode: lower gathered defining string globals to `string.const` imports plus `string.consts` metadata.
5. Type rewrite: lower string refs to extern refs, with explicit tests for nullable/non-nullable and singleton public function types.
6. Helper import rewrites: add `wasm:js-string` helper imports and lower only the source-backed supported opcode families.
7. Magic imports: split valid UTF-8 magic-import behavior from assert-mode fatal behavior.
8. Refinalization and feature cleanup: remove the Strings feature only after validating there are no remaining string-typed uses.

## Remaining uncertainty

- The JS string builtins proposal remains the external ABI context. Before implementing helper-call exactness, recheck the proposal and Binaryen's current owner file.
- If local `string-gathering` lands first, the `string-lowering` first mutating slice should be revised to compose with that implementation instead of reimplementing the inherited Binaryen prefix from scratch.
- The right Starshine local policy for unknown vs boundary-only registry names is a product decision, not answered by Binaryen source alone.
