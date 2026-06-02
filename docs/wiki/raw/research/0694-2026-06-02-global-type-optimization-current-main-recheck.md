# 0694 — 2026-06-02 global-type-optimization current-main recheck

## Question

Did Binaryen current `main` drift from the existing `version_129` `global-type-optimization` contract in any teaching-relevant way?

## Sources checked

- `docs/wiki/raw/binaryen/2026-04-24-global-type-optimization-primary-sources.md`
- `https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/GlobalTypeOptimization.cpp`
- `https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp`
- `https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gto_and_cfp_in_O.wast`

## Finding

No teaching-relevant drift was found on the reviewed surfaces.

Observed current-main facts:

- the pass still behaves as a closed-world GC/type-cluster module pass
- the short upstream name is still `gto`
- the current scheduler story still matches the earlier `global-refining` -> `gto` -> cleanup / CFP ordering
- the same field-layout, JS-exposure, and rewrite-order story remains intact

## Follow-up

The durable wiki update is a freshness refresh, not a contract correction.
The folder still needs the same honest Starshine boundary-only framing, plus a dedicated port-readiness bridge so the missing local module/type-graph work stays explicit.
