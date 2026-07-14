---
kind: source
status: reviewed
last_reviewed: 2026-07-14
sources:
  - https://github.com/WebAssembly/binaryen/blob/5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3/src/passes/Flatten.cpp
  - ./2026-07-13-flatten-version-130-scalar-try-if-table-refresh.md
  - ./2026-07-14-flatten-version-130-scalar-try-two-block-if-table-refresh.md
related:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/wat-shapes.md
---

# Binaryen `version_130` `flatten` scalar legacy-try plus two enclosing-if table refresh

## Immutable upstream point

- Tag: `version_130`
- Commit: `5d704ad52bc77a258e8fa3f9d34fcc5e8799c1c3`
- Owner: `src/passes/Flatten.cpp`

## Source-backed rule

Binaryen's concrete `Switch` route stores the payload once before selector work and copies it into every unique break-target temp. Postorder value-control flattening independently erases each directly enclosing value if and copies the selected inner channel into the next outer channel. The owner has no if-count cap; the relevant safety condition is the exact direct ancestry and target roster.

## Direct v130 probe

The ignored `.tmp/flatten-probes/scalar-try-two-if-table-targets.wat` probe places a scalar legacy try in the then arm of one matching value if, itself in the then arm of a second matching value if. The terminal table targets the try and both if labels, with the try repeated as default. It was run with the explicit `wasm-opt version 130` binary and `--all-features --flatten -S`.

The output confirms:

- payload evaluation before selector evaluation;
- distinct try, inner-if, and outer-if target channels;
- catch writes the try channel;
- selected fallthrough copies try to inner if and inner if to outer if;
- each else arm writes its own if channel independently;
- the table payload and all value-control results are removed.

## Local admission

The verifier-backed scalar two-if fixture failed unchanged at `113/114` behind the previous one-if ancestry restriction. Starshine now accepts a strict direct-enclosure target chain containing zero or more matching blocks followed by one or more matching value ifs. Once an if is reached, a later outer block is rejected, preserving the required all-ifs-outermost order. Every selected target must appear in the direct chain.

The fixture proves one payload evaluation, selector-after-payload order, distinct try/inner-if/outer-if locals, catch routing, both selected outward copies, independent else routing at both levels, cleared table/control arity, Flat IR classification, and verifier success.

A temporary explicit `payload_count > 1` gate keeps the multiple-if vector roster separately red-first. Repeated `TupleMake` multiple-if payloads also remain behind their independent tuple policy. Reverse if-inside-block order, loops, skipped ancestry, unrelated targets, nonterminal tables, nondefaultable payloads, typed catch payloads, and exceptional-transfer repair remain rejected.
