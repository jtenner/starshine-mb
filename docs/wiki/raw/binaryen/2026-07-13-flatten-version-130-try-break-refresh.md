---
kind: source
status: reviewed
last_reviewed: 2026-07-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/test/lit/passes/flatten-eh-legacy.wast
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` legacy-try break refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's postorder `Break` handling allocates one temp for a concrete named target, writes the branch payload before the branch, removes the payload, and preserves the branch effect. Legacy `Try` result handling independently writes concrete do/catch fallthrough values to a result temp and makes the try void. When a break targets a value-carrying try, Binaryen's prelude reconstruction can introduce an outer wrapper so the branch skips normal-result copies; the semantic contract is that the carried branch value and each reachable fallthrough arm select the same final result without reevaluation.

The same owner still requires `EHUtils::handleBlockNestedPops(...)` after flattening represented catch payloads. The official legacy-EH lit file demonstrates that inserted catch-local blocks require this repair.

## Direct v130 probe

The ignored `.tmp/flatten-probes/scalar-try-branch-target.wat` probe uses a plain carried `br` to a scalar legacy-try label in the do region and an independently scalar catch fallthrough. Its `.out.wat` output from `wasm-opt version 130 --all-features --flatten -S` confirms payload-before-branch order, payload removal, void try output, and a final local channel shared by branch-selected and fallthrough-selected results.

## Local interpretation

Starshine may use one typed try-label local directly instead of Binaryen's exact wrapper/copy shape when complete preflight proves all uses of that try label are plain scalar `br` exits, every carried value exactly matches the defaultable try result type, and each do/catch region ends in either such a branch or an independently scalar matching fallthrough. Branch payloads are flattened once before the branch, branch arity and try result arity are cleared, and fallthrough arms write the same local.

This does not admit `br_if`, `br_table`, multivalue try-label branches, nondefaultable results, represented typed catch payloads, `rethrow`, `delegate`, or other exceptional transfers.
