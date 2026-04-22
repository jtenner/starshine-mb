---
kind: research
status: supported
last_reviewed: 2026-04-22
sources:
  - ../binaryen/2026-04-22-pick-load-signs-primary-sources.md
  - ../../binaryen/passes/pick-load-signs/index.md
  - ../../binaryen/passes/pick-load-signs/binaryen-strategy.md
  - ../../binaryen/passes/pick-load-signs/implementation-structure-and-tests.md
  - ../../binaryen/passes/pick-load-signs/wat-shapes.md
  - ../../../../src/passes/pick_load_signs.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/pick_load_signs_test.mbt
  - ../../../../src/passes/perf_test.mbt
  - ../../../../src/passes/registry_test.mbt
  - ../../../../src/cmd/cmd_wbtest.mbt
---

# `pick-load-signs` primary-source and Starshine code-map follow-up

## Why this follow-up exists

The living `pick-load-signs` dossier was already strong after the 2026-04-21 source-confirmation refresh, but two practical gaps remained:

- the folder still lacked an immutable raw primary-source manifest like the newer implemented-pass dossiers now carry
- the local Starshine strategy page still described the algorithm accurately at a high level, but it did not yet give readers the exact MoonBit registry / dispatcher / raw-skip / rewrite / test map they need for fast code navigation

This follow-up closes that narrower provenance-and-navigation gap without claiming the folder lacked a real dossier.

## Sources re-checked in this run

### Upstream Binaryen primary sources

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-22-pick-load-signs-primary-sources.md`

The key reviewed surfaces were:

- official Binaryen GitHub release pages for `version_129`
- `PickLoadSigns.cpp` on both `version_129` and `main`
- `pass.cpp`, `opt-utils.h`, and `properties.h`
- the dedicated `pick-load-signs_sign-ext.wast` lit file and the neighboring `optimize-instructions-sign_ext.wast` boundary file

### Local Starshine code surfaces re-checked

- `src/passes/pick_load_signs.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/optimize.mbt`
- `src/passes/pick_load_signs_test.mbt`
- `src/passes/perf_test.mbt`
- `src/passes/registry_test.mbt`
- `src/cmd/cmd_wbtest.mbt`

## Durable findings

### 1. The release anchoring is now explicit instead of implied

The earlier dossier already treated `version_129` as the Binaryen oracle, but it did not yet preserve the exact release-page provenance in the raw-source system.
The 2026-04-22 capture now records that the reviewed official release page for `version_129` showed publish date **2026-04-01**, and that the releases index was re-checked on the same day.

That gives the folder a stable provenance anchor instead of relying only on interpreted living pages.

### 2. The main remaining local teaching gap was the exact HOT/code-path map

Re-checking the local MoonBit code confirmed that the cleanest read-along for future maintainers is:

1. registry entry and preset placement in `src/passes/optimize.mbt`
2. raw no-memory and raw-candidate skip gates in `src/passes/pass_manager.mbt`
3. candidate discovery, use classification, and rewrite helpers in `src/passes/pick_load_signs.mbt`
4. focused pass, perf, registry, and CLI replay coverage across the local test files

The older Starshine strategy page was directionally right, but too vague about where each part actually lives.

### 3. Current Starshine is broader than upstream in code, but not yet in dedicated local test isolation

The implementation still clearly supports i64 families in code:

- `pls_load_info(...)`
- `pls_load_with_signedness(...)`
- `pls_extension_from_parent(...)`
- `pls_extension_from_grandparent_zero_ext64(...)`

But a local health check found that the focused `src/passes/pick_load_signs_test.mbt` suite does **not** currently isolate explicit i64 positive rewrite cases.
The earlier strategy page had overclaimed that focused local tests already covered i64 forms directly.

The honest current state is narrower:

- code support is broader than upstream
- focused local tests directly lock i32 and raw-skip behavior
- broader artifact and fuzz evidence still exists, but dedicated local i64 proof cases remain a separate documentation and test gap

That correction is now filed back into the living dossier instead of being left as a quiet mismatch.

### 4. The pass-manager fast-skip story is part of the real local contract

The local pass is best taught as more than just `pick_load_signs_run(...)`.
`src/passes/pass_manager.mbt` materially shapes what readers observe in practice:

- module-wide no-memory skipping
- raw candidate scanning before hot lift
- aggregation of repeated raw-skip trace lines across functions
- the final dispatcher edge into `pick_load_signs_run(...)`

That local infrastructure is not upstream Binaryen semantics, but it is part of Starshine's practical behavior and deserved explicit code-map coverage.

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-22-pick-load-signs-primary-sources.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/pick-load-signs/index.md`
- `docs/wiki/binaryen/passes/pick-load-signs/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/pick-load-signs/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/pick-load-signs/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/pick-load-signs/parity.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Maintenance rule going forward

If future `pick-load-signs` work needs a quick provenance anchor plus a practical Starshine read-along path, start with:

1. `docs/wiki/raw/binaryen/2026-04-22-pick-load-signs-primary-sources.md`
2. `docs/wiki/binaryen/passes/pick-load-signs/index.md`
3. `docs/wiki/binaryen/passes/pick-load-signs/starshine-hot-ir-strategy.md`
4. `docs/wiki/binaryen/passes/pick-load-signs/parity.md`
5. `src/passes/pick_load_signs.mbt`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current MoonBit implementation, its local fast-skip behavior, and the honest boundary between coded i64 support and explicitly isolated local tests.
