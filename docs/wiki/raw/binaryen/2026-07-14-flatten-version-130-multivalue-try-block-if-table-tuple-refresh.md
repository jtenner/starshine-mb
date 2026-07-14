---
kind: source
status: reviewed
last_reviewed: 2026-07-14
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-13-flatten-version-130-multivalue-try-block-if-table-refresh.md
  - ./2026-07-13-flatten-version-130-multivalue-try-if-table-tuple-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` tuple-made legacy-try plus block plus enclosing-if table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's concrete tuple `Switch` route evaluates the carried tuple once, stores it before selector work, and copies that stored value to every unique target temp. Postorder `Try`, `Block`, and `If` handling then erase the three value-carrying controls through distinct tuple locals. This makes the exact direct ancestry composition of one legacy try, one matching enclosing block, and one outer matching value if a consequence of the same owner contract already proven separately for tuple try-plus-if and independently scalar try-plus-block-plus-if lanes.

## Direct v130 probe

The ignored `.tmp/flatten-probes/multivalue-try-block-if-table-tuple-payload.wat` probe uses the exact `(i32, i64)` try-inside-block-inside-if table roster and was run with the explicit Binaryen v130 binary:

```text
/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt
```

The resulting `.out.wat` confirms first-component then second-component evaluation, tuple staging before selector evaluation, distinct try/block/if break temps, catch-to-try routing, try-to-block and block-to-if selected fallthrough copies, independent else-arm writes, payload removal from `br_table`, and outward final flow.

## Local admission

The existing fail-closed repeated-HOT-`TupleMake` fixture was converted red-first into a positive and failed unchanged at `109/110` before the tuple mixed-target policy changed. Starshine now admits only the exact source-backed three-target roster already accepted by the shared ancestry helper: one legacy try directly enclosed by one matching block directly enclosed in one matching outer value if. Complete tuple ownership, result-vector equality, defaultable scalar component types, supported component origins, terminal placement, unique target preflight, and direct ancestry are required before mutation.

The tuple components scalarize once in source order, feed one staging vector, copy into distinct try/block/if vectors before selector work, and delete the detached tuple shell only after successful preflight. Catch writes the try vector; selected fallthrough copies try to block and block to if; the other if arm writes the if vector independently. Table and control arity are cleared and verifier-backed Flat IR checks pass.

This does not admit arbitrary whole-tuple producers, multiple blocks with an if, multiple if targets, reverse if-inside-block order, skipped ancestry, loops, multiple try labels, nonterminal tables, nondefaultable lanes, typed catch payloads, or exceptional-transfer repair.
