# Binaryen `constant-field-propagation` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/constant-field-propagation/` dossier

## Scope

This file captures the primary online sources consulted for the 2026-04-24 `constant-field-propagation` provenance and Starshine status follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/constant-field-propagation/index.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/copies-subtypes-ref-tests-and-atomics.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/wat-shapes.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/starshine-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - Neighboring 2026-04-24 pass ingests observed the GitHub publish date as **2026-04-01 14:31**; this CFP follow-up reuses `version_129` as the release oracle for the living dossier.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-24 in the pass-ingest campaign.

### Official source files consulted

- `ConstantFieldPropagation.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ConstantFieldPropagation.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/ConstantFieldPropagation.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/ConstantFieldPropagation.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/ConstantFieldPropagation.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `possible-constant.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-constant.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/possible-constant.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/possible-constant.h>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/possible-constant.h>
- `struct-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/struct-utils.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/struct-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/struct-utils.h>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/struct-utils.h>
- `subtypes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/subtypes.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/subtypes.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/subtypes.h>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/subtypes.h>
- `module-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
- `gc-type-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/gc-type-utils.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/gc-type-utils.h>
- `bits.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/bits.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/bits.h>

### Official test files consulted

- `cfp.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/cfp.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/cfp.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/cfp.wast>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/cfp.wast>
- `cfp-reftest.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/cfp-reftest.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/cfp-reftest.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/cfp-reftest.wast>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/cfp-reftest.wast>
- `gto_and_cfp_in_O.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gto_and_cfp_in_O.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto_and_cfp_in_O.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gto_and_cfp_in_O.wast>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gto_and_cfp_in_O.wast>

## Durable observations from the captured sources

- `ConstantFieldPropagation.cpp` is the shared engine for upstream `cfp` and `cfp-reftest`.
- The pass is GC-gated and closed-world-only; standalone open-world execution is a fatal usage error rather than a quiet no-op.
- The shared engine scans struct construction, writes, defaults, copies, and RMW/cmpxchg-style unknowns through Binaryen struct helpers, then solves field facts over exact/inexact type views, subtype hierarchy propagation, and copy edges before rewriting reads.
- The tracked value domain is deliberately small: no value, one literal constant, one immutable global, or unknown. Plain `cfp` does not become general symbolic propagation.
- Rewrites target reads, especially `struct.get` / packed variants and descriptor reads; replacements must preserve reference side effects, null traps, packed-field semantics, subtype validity, and atomic synchronization boundaries.
- `cfp-reftest` is a real public sibling registration and has a dedicated official lit file, `test/lit/passes/cfp-reftest.wast`. This corrects the older parent-CFP implementation page language that said no dedicated `cfp-reftest` file had been reviewed.
- `gto_and_cfp_in_O.wast` is the compact official proof that the pass family matters in the closed-world GC/type optimization neighborhood after type/global cleanup, not in Starshine's current open-world no-DWARF path.
- A narrow 2026-04-24 current-`main` spot check on the owner file, registration surface, and dedicated lit files did not surface teaching-relevant drift from the `version_129` story. This is intentionally a narrow check, not a whole-repo equivalence proof.
- Starshine-specific follow-up in this run did not find a local implementation file. The durable local fact is that `constant-field-propagation` and `constant-field-null-test-folding` are preserved **boundary-only** registry names, not active HOT or module passes.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages and the corrective research note instead of relying only on the older `0158` research note.
