---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-13-flatten-version-130-try-break-refresh.md
  - ./2026-07-13-flatten-version-130-conditional-branch-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` scalar legacy-try conditional-break refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's postorder `Break` path evaluates a concrete `br_if` payload before its condition, writes the payload through the named-target break temp, removes the payload from the branch, and preserves the not-taken value through a local read. Legacy `Try` result routing separately writes reachable do/catch fallthrough results and makes the try void. Prelude reconstruction may add wrapper/copy locals, but every selected path reaches one final result without reevaluating the payload, condition, or arm tail.

## Direct v130 probe

The ignored `.tmp/flatten-probes/scalar-try-conditional-target.wat` probe carries a rich scalar payload through `br_if` to a legacy-try label, consumes the not-taken value with an immediate `drop`, then produces an independent do fallthrough value; the catch produces another matching value. Its `.out.wat` output from `wasm-opt version 130 --all-features --flatten -S` confirms payload-before-condition order, payload removal, preserved false-path flow, a payload-free conditional branch, void try output, and a shared final result channel.

## Local interpretation

Starshine admits one exact defaultable scalar family: every try-label use must be either an already-routed payload-free `br_if` or a carried `br_if` whose payload exactly matches the try result type, has a supported scalar origin, and has exactly two uses—the branch payload slot and one immediate direct `drop` root in the same try arm. Other arm exits remain independently scalar matching fallthroughs. The payload is evaluated once before condition work into the shared try-label local, the false-path drop reads that local, the branch payload and try result arity are cleared, and do/catch fallthroughs write the same result channel.

This does not admit non-immediate or shared false-path consumers, type mismatch, nondefaultable results, multivalue conditional try exits, table exits, represented typed catch payloads, `rethrow`, `delegate`, or broader exceptional transfer.
