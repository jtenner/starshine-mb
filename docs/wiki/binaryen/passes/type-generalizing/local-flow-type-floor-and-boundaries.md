---
kind: concept
status: superseded
last_reviewed: 2026-07-11
sources:
  - ../../../raw/binaryen/2026-07-11-type-generalizing-v130-current-main-recheck.md
  - ../../../raw/research/0421-2026-04-27-type-generalizing-source-correction-and-port-readiness.md
  - ../../../raw/research/0479-2026-05-05-type-generalizing-current-main-recheck.md
  - ../../../raw/research/0497-2026-05-06-type-generalizing-current-main-recheck.md
superseded_by:
  - ./type-requirements-cfg-and-unsupported-families.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./type-requirements-cfg-and-unsupported-families.md
---

# Superseded: local-flow type floor and boundaries

This page is retained as a stable link target, but its old 2026-04-24 model is superseded.
The 2026-07-11 `version_130` / current-main recheck keeps that supersession but corrects the later unsupported `ContentOracle` claim.

The current source-correct focused guide is [`./type-requirements-cfg-and-unsupported-families.md`](./type-requirements-cfg-and-unsupported-families.md).

## What changed

The previous version taught `type-generalizing` as a tiny local-set/local-tee evidence pass with a `local.get` drop-plus-zero fallback and no `ContentOracle`, no `call_ref`, no GC instruction visitors, no nested cleanup, and no refinalization.

The later source corrections and the 2026-07-11 `version_130` / current-main recheck establish that the pass is a hidden not-yet-sound CFG/backward-analysis pass with:

- nested `dce`;
- local and value-stack type requirements;
- typed-IR/declaration-based call/global/table/ref/GC transfer rules, not `ContentOracle`;
- explicit `call_ref`, struct, and array transfer rules;
- local declaration generalization;
- `local.get` / `local.tee` result retagging;
- conditional `ReFinalize`;
- many explicit unsupported/TODO families.

Use the replacement page and the refreshed landing/strategy pages for mechanics.

## Current sources

- [`../../../raw/binaryen/2026-07-11-type-generalizing-v130-current-main-recheck.md`](../../../raw/binaryen/2026-07-11-type-generalizing-v130-current-main-recheck.md)
- [`../../../raw/research/0421-2026-04-27-type-generalizing-source-correction-and-port-readiness.md`](../../../raw/research/0421-2026-04-27-type-generalizing-source-correction-and-port-readiness.md)
- [`./type-requirements-cfg-and-unsupported-families.md`](./type-requirements-cfg-and-unsupported-families.md)
