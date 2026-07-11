# Binaryen `precompute` v130/current-main reconciliation

_Capture date:_ 2026-07-11  
_Status:_ immutable primary-source bridge for `docs/wiki/binaryen/passes/precompute/`

## Scope

This capture supersedes the **baseline choice** in the older `precompute` dossier: Binaryen `version_130`, not `version_129`, is the newest public Binaryen release. It does **not** discard the detailed `version_129` investigation; that investigation remains useful historical provenance where its individual claims have not yet been reread line-by-line.

The focused reread covered the release horizon, public pass registration, main pass owner, nested scheduler helper, and representative current tests. It is intentionally not a byte-for-byte diff of every `version_129`, `version_130`, and `main` source file.

Use the living pages for interpretation:

- `docs/wiki/binaryen/release-horizon-and-oracles.md`
- `docs/wiki/binaryen/passes/precompute/index.md`
- `docs/wiki/binaryen/passes/precompute/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/precompute/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/precompute/propagation-partial-precompute-and-gc-identity.md`
- `docs/wiki/binaryen/passes/precompute/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/precompute/starshine-port-readiness-and-validation.md`

## Official sources consulted

### Release horizon

- Binaryen `version_130` release: <https://github.com/WebAssembly/binaryen/releases/tag/version_130>
- Binaryen current changelog: <https://github.com/WebAssembly/binaryen/blob/main/CHANGELOG.md>
- Chromium mirror refs: <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+refs>

These official surfaces are also captured and reconciled by `docs/wiki/raw/binaryen/2026-06-04-binaryen-v130-release-horizon-recheck.md`.

### Pass family, release tag, and current main

- `Precompute.cpp`
  - `version_130`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/Precompute.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Precompute.cpp>
- public registration and default scheduling in `pass.cpp`
  - `version_130`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- nested optimizing cleanup in `opt-utils.h`
  - `version_130`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/opt-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
- representative test surfaces
  - `version_130` plain effects: <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/precompute-effects.wast>
  - `version_130` partial precompute: <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/precompute-partial.wast>
  - `version_130` GC: <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/precompute-gc.wast>
  - `main` plain effects: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/precompute-effects.wast>
  - `main` partial precompute: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/precompute-partial.wast>
  - `main` GC: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/precompute-gc.wast>

### Local status sources consulted

- `src/passes/precompute.mbt` — current narrow HOT descriptor and scalar/global/control rewrite surface.
- `src/passes/precompute_test.mbt` — focused local scalar, trap-preservation, control-cleanup, O4z-gate, and raw-skip coverage.
- `src/passes/optimize.mbt` — active local `precompute` registration and separate removed `precompute-propagate` status.
- `scripts/lib/pass-fuzz-compare-task.ts` — direct `precompute` compare-pass admission.

## Reconciled observations

1. **Stable baseline:** `version_130` is the public Binaryen baseline. A `precompute` page may retain `version_129` terminology when it identifies an older source reading, but it must not call that older tag the current release oracle.
2. **Public split remains visible:** the reviewed v130/main registration continues to expose separate `precompute` and `precompute-propagate` public names. The local Starshine status remains intentionally asymmetric: `precompute` is active while `precompute-propagate` is a removed registry name.
3. **Ownership/scheduling teaching remains valid in the focused read:** `Precompute.cpp` remains the shared family owner; `pass.cpp` remains the public/default-scheduling source; and `opt-utils.h` remains the nested optimizing-rerun source. The plain-versus-propagating distinction should remain explicit in beginner documentation.
4. **No focused behavior-bearing drift found:** this reread did not find a change requiring a new local transform claim or a rewrite of the current WAT-shape catalog. It is a release-baseline and source-freshness correction, not a claim of byte-identical v129/v130/main implementation.
5. **Do not overclaim parity:** existing Starshine evidence still covers only the documented HOT scalar/global/control subset. V130/current-main ownership evidence does not upgrade Starshine to Binaryen's interpreter, `Flow`, child-retention, partial-select, GC-identity, or `LazyLocalGraph` propagation behavior.

## Supersession and uncertainty

- This bridge supersedes the old wording that `version_129` was the current source oracle for `precompute`.
- It does **not** supersede the older raw manifests as historical source captures.
- It does **not** prove every detailed v129 claim is textually unchanged in v130 or current main. Future work that ports a specific nonlocal behavior must reread the relevant owner code and lit fixture at the chosen oracle revision.
- Current main remains a drift watch after `version_130`; a future behavior-bearing main change should receive its own source bridge rather than silently rewriting this one.
