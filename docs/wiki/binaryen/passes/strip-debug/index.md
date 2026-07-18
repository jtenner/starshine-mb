---
kind: entity
status: supported
starshine_status: active
last_reviewed: 2026-07-18
sources:
  - ../../../../../src/passes/strip_debug.mbt
  - ../../../../../src/passes/strip_debug_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/passes/registry_test.mbt
related:
  - ../index.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../strip-toolchain-annotations/index.md
  - ../strip-target-features/index.md
---

# `strip-debug`

## Role

Starshine's active module pass removes debug-name metadata without deleting unrelated custom sections. It is scheduled as the final pass in both public `optimize` and `shrink` presets, after `directize`, so name-sensitive optimization and diagnostic work finishes before names are discarded.

## Exact local contract

`strip_debug_run_module_pass(...)` removes:

- the structured `name_sec` representation;
- any preserved raw name-section payload.

It preserves:

- semantic sections;
- non-name custom sections such as `producers`, profiles, or application-specific metadata;
- custom-section relative placement as represented by Starshine, even when Binaryen re-emits the same section at a different byte position.

Do not teach this pass as “remove every custom section.” Binaryen and Starshine both preserve an unrelated `foo` custom section in the reduced oracle fixture. A raw byte difference caused only by custom-section placement is metadata-layout drift, not a semantic-section mismatch.

## Preset placement

The accepted public tail is:

```text
simplify-globals-optimizing
-> remove-unused-module-elements
-> string-gathering
-> reorder-globals
-> directize
-> strip-debug
```

Late placement is deliberate. `strip-debug` is non-semantic, but earlier passes, extraction tools, diagnostics, and user-directed policy may still consume names. Duplicate-function elimination may incidentally remove names on some artifacts; that is not a reliable substitute for explicit `strip-debug` scheduling.

## Evidence

- Focused tests prove structured/raw names are removed while unrelated custom sections survive.
- Public preset tests prove both `optimize` and `shrink` end in `strip-debug` and preserve non-name custom metadata.
- Registry tests keep the preset expansion on active pass names.
- A 1,000-case direct semantic-section compare completed with `1000/1000` normalized matches and no mismatches or failures.
- The ordinary compare harness strips debug during canonicalization, so it is only a semantic-section smoke; custom/name-section behavior requires focused module tests and explicit custom-section inspection.

## Maintenance boundaries

- Keep custom-section preservation separate from semantic section parity.
- Keep name removal separate from `strip-target-features`, `strip-toolchain-annotations`, and producers/annotation cleanup.
- Recheck artifact-size and metadata policy before moving the pass earlier or removing it from a public preset.
- Reopen if a non-name custom section is deleted, names survive the final public presets, output fails validation, or Binaryen changes the direct pass's metadata contract.
