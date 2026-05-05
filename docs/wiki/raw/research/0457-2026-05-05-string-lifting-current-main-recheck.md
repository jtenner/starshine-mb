---
kind: research
status: supported
last_reviewed: 2026-05-05
sources:
  - ../binaryen/2026-05-05-string-lifting-current-main-recheck.md
  - ../binaryen/2026-04-26-string-lifting-current-main-port-readiness.md
  - ../binaryen/2026-04-25-string-lifting-signature-fatal-source-correction.md
  - ../binaryen/2026-04-24-string-lifting-primary-sources.md
  - ./0327-2026-04-24-string-lifting-primary-sources-and-starshine-followup.md
  - ./0346-2026-04-25-string-lifting-signature-fatal-source-correction.md
  - ./0385-2026-04-26-string-lifting-port-readiness.md
  - ../../binaryen/passes/string-lifting/index.md
  - ../../binaryen/passes/string-lifting/binaryen-strategy.md
  - ../../binaryen/passes/string-lifting/implementation-structure-and-tests.md
  - ../../binaryen/passes/string-lifting/import-and-call-shapes.md
  - ../../binaryen/passes/string-lifting/starshine-strategy.md
  - ../../binaryen/passes/string-lifting/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/optimize.mbt
related:
  - ../../binaryen/passes/string-gathering/index.md
  - ../../binaryen/passes/string-lowering/index.md
  - ../../strings/string-const-surface.md
---

# `string-lifting` current-main recheck

## Question

The `string-lifting` dossier already had a stable source contract, but the freshness layer needed a current-main recheck so the living pages could stay honest about upstream drift.

## Source review

Reviewed current-main sources:

- `StringLifting.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/StringLifting.cpp>
- `string-lifting.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/string-lifting.wast>
- `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>

The 2026-05-05 recheck reused the same reasoning frame as the 2026-04-26 port-readiness note and the 2026-04-25 signature correction.

## Findings

- Current `main` still exposes `string-lifting` as a public Binaryen pass in the string-family registration cluster.
- The lift contract still matches the living dossier: magic imports, numbered `string.const` imports plus `string.consts`, exact helper signatures, global-get and call rewrites, function refinalization, module-code walking, Strings enablement, and the explicit cast-repair TODO.
- The direct lit file still separates the meaningful positive families from the wrong-module / wrong-name negatives.
- No newer teaching-relevant drift was found.

## Living-page updates

- Refreshed the `string-lifting` overview, Binaryen strategy, implementation/test-map, shape catalog, Starshine status page, and Starshine readiness bridge to cite this 2026-05-05 freshness layer.
- Refreshed the shared indexes and log so the new recheck is discoverable from the catalog layer.

## Conclusion

The best current wiki action is freshness maintenance, not contract revision. `string-lifting` remains upstream-only in Starshine and still needs the same helper/output-surface work before any future port.
