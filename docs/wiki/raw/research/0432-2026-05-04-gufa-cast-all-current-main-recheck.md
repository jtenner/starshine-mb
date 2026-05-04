---
kind: research
status: supported
last_reviewed: 2026-05-04
sources:
  - ../../binaryen/2026-05-04-gufa-cast-all-current-main-recheck.md
  - ../../../binaryen/passes/gufa-cast-all/index.md
  - ../../../binaryen/passes/gufa-cast-all/binaryen-strategy.md
  - ../../../binaryen/passes/gufa-cast-all/implementation-structure-and-tests.md
  - ../../../binaryen/passes/gufa-cast-all/starshine-strategy.md
---

# `gufa-cast-all` Current-Main Recheck

## Question

Has the upstream `gufa-cast-all` contract drifted, and what local code/status surfaces should the wiki point at now?

## Finding

No teaching-relevant drift was found on the reviewed surfaces.

The refreshed reading is still:

- the shared `GUFA.cpp` engine handles plain GUFA rewrites first;
- `castAll` then triggers `addNewCasts(func)`;
- `createGUFACastAllPass()` still constructs `GUFAPass(false, true)`;
- `pass.cpp` still exposes `gufa-cast-all` as a real public pass;
- the dedicated lit file still proves explicit cast insertion, exact struct/function-reference cases, and conservative boundaries.

## Durable updates from this recheck

- Added a new raw source manifest: [`../../binaryen/2026-05-04-gufa-cast-all-current-main-recheck.md`](../../binaryen/2026-05-04-gufa-cast-all-current-main-recheck.md).
- Refreshed the `gufa-cast-all` wiki pages to use the 2026-05-04 manifest as the latest source anchor.
- Tightened the Starshine strategy page to point at exact local registry / unknown-pass / boundary-only code locations.

## Why this matters

`gufa-cast-all` was already teachable, but its provenance was still anchored to 2026-04-24. This recheck keeps the dossier honest without implying any contract change.
