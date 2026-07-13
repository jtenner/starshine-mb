---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/test/lit/passes/flatten_all-features.wast
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` conditional-branch refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`
- Broad fixture: `test/lit/passes/flatten_all-features.wast`

## Source-backed behavior

The v130 owner keeps one `breakTemps` entry per named branch target. For a concrete value-carrying `Break`, it:

1. obtains a temp typed for the target;
2. emits a prelude write of the carried value;
3. for conditional branches, replaces false-path flow with a read from the selected temp;
4. clears the original branch value and finalizes the branch.

The owner is expressed in terms of a concrete Binaryen `Type`, not a scalar-only opcode arm. It also retains the documented second-temp route when the carried value's flowing-out type differs from the target type. The all-features fixture exercises conditional value routing, source-order-sensitive conditions, nested value-carrying `br_if`, and unreachable placeholders.

## Local interpretation

Starshine HOT exposes a multivalue branch as an ordered child vector rather than one tuple-valued child. The conservative v130-compatible correspondence implemented on 2026-07-13 is therefore:

- admit only defaultable block/if targets whose payload vector exactly matches the target result vector;
- require each distinct payload origin to have exactly one non-branch use and require those false-path uses to form one contiguous ordered target-tail span;
- evaluate each payload once in source order into the target's shared typed local vector;
- replace the false-path span with ordered reads from that same vector;
- clear only the payload children and preserve the condition;
- let block/if result erasure reuse the already-routed vector rather than wrap the reads in redundant writes.

This is intentionally narrower than the complete Binaryen owner. Vector type mismatch, ambiguous/shared false-path consumers, multivalue `br_table`, loop-targeted conditional channels outside the existing entry-local families, and broader branch/EH interactions remain open parity work. The public `flatten` registry entry must remain removed until those boundaries and the required validation matrix are closed.
