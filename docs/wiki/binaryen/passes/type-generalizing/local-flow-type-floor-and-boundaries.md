---
kind: concept
status: superseded
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-04-27-type-generalizing-primary-source-correction.md
  - ../../../raw/research/0421-2026-04-27-type-generalizing-source-correction-and-port-readiness.md
  - ../../../raw/binaryen/2026-05-05-type-generalizing-current-main-recheck.md
  - ../../../raw/research/0479-2026-05-05-type-generalizing-current-main-recheck.md
superseded_by:
  - ./type-requirements-cfg-and-unsupported-families.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./type-requirements-cfg-and-unsupported-families.md
---

# Superseded: local-flow type floor and boundaries

This page is retained as a stable link target, but its old 2026-04-24 model is superseded.
The 2026-05-05 current-main recheck kept that supersession unchanged.

The current source-correct focused guide is [`./type-requirements-cfg-and-unsupported-families.md`](./type-requirements-cfg-and-unsupported-families.md).

## What changed

The previous version taught `type-generalizing` as a tiny local-set/local-tee evidence pass with a `local.get` drop-plus-zero fallback and no `ContentOracle`, no `call_ref`, no GC instruction visitors, no nested cleanup, and no refinalization.

The 2026-04-27 primary-source recheck found that official Binaryen `version_129` and current `main` instead implement a hidden not-yet-sound CFG/backward-analysis pass with:

- nested `dce`;
- local and value-stack type requirements;
- `ContentOracle`-assisted call/global/table/ref/GC reasoning;
- explicit `call_ref`, struct, and array transfer rules;
- local declaration generalization;
- `local.get` / `local.tee` result retagging;
- conditional `ReFinalize`;
- many explicit unsupported/TODO families.

Use the replacement page and the refreshed landing/strategy pages for mechanics.

## Current sources

- [`../../../raw/binaryen/2026-04-27-type-generalizing-primary-source-correction.md`](../../../raw/binaryen/2026-04-27-type-generalizing-primary-source-correction.md)
- [`../../../raw/research/0421-2026-04-27-type-generalizing-source-correction-and-port-readiness.md`](../../../raw/research/0421-2026-04-27-type-generalizing-source-correction-and-port-readiness.md)
- [`./type-requirements-cfg-and-unsupported-families.md`](./type-requirements-cfg-and-unsupported-families.md)
