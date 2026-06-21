---
kind: raw-source
status: supported
last_reviewed: 2026-06-20
source_type: version-130-source-lit-refresh
pass: code-pushing
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/CodePushing.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/code-pushing-atomics.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/code-pushing-eh-legacy.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/code-pushing-eh.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/code-pushing-gc.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/code-pushing_ignore-implicit-traps.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/code-pushing_into_if.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/code-pushing_tnh.wast
  - ../../../src/passes/code_pushing.mbt
  - ../../../src/passes/code_pushing_test.mbt
  - ../../../src/passes/optimize.mbt
supersedes:
  - ./2026-05-05-code-pushing-current-main-recheck.md
---

# Binaryen `code-pushing` version_130 source and lit refresh

_Capture date:_ 2026-06-20

_Local oracle:_ `wasm-opt version 130 (version_130)`

## Scope

This file records the version-pinned Binaryen source and lit-test refresh for the active `[O4Z-AUDIT-CP]` audit. It supersedes the 2026-05-05 current-main bridge for current v0.1.0 release-gating decisions because the local oracle is now `version_130`.

Use the living dossier pages for explanations:

- `docs/wiki/binaryen/passes/code-pushing/index.md`
- `docs/wiki/binaryen/passes/code-pushing/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/code-pushing/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/code-pushing/segment-selection-and-barriers.md`
- `docs/wiki/binaryen/passes/code-pushing/wat-shapes.md`
- `docs/wiki/binaryen/passes/code-pushing/starshine-strategy.md`
- `docs/wiki/binaryen/passes/code-pushing/starshine-port-readiness-and-validation.md`

## Official sources consulted

### Binaryen `version_130`

- `src/passes/CodePushing.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/CodePushing.cpp>
- `src/passes/pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp>

### `version_130` lit tests

- `test/lit/passes/code-pushing-atomics.wast`: <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/code-pushing-atomics.wast>
- `test/lit/passes/code-pushing-eh-legacy.wast`: <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/code-pushing-eh-legacy.wast>
- `test/lit/passes/code-pushing-eh.wast`: <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/code-pushing-eh.wast>
- `test/lit/passes/code-pushing-gc.wast`: <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/code-pushing-gc.wast>
- `test/lit/passes/code-pushing_ignore-implicit-traps.wast`: <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/code-pushing_ignore-implicit-traps.wast>
- `test/lit/passes/code-pushing_into_if.wast`: <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/code-pushing_into_if.wast>
- `test/lit/passes/code-pushing_tnh.wast`: <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/code-pushing_tnh.wast>

## Reviewed source surfaces

The owner/source shape remains the same as the previous dossier in the important structural sense:

- `LocalAnalyzer` starts at `CodePushing.cpp` line 38.
- `class Pusher` starts at line 81.
- `Pusher::isPushable(...)` starts at line 128.
- `Pusher::isPushPoint(...)` starts at line 161.
- `Pusher::optimizeSegment(...)` starts at line 175.
- `Pusher::optimizeIntoIf(...)` starts at line 268.
- `CodePushing::doWalkFunction(...)` starts at line 467.
- `pass.cpp` still registers `code-pushing` and still schedules it under the no-DWARF optimization path when `optimizeLevel >= 2 || shrinkLevel >= 2`.

## Durable observations

- The core source-backed mental model is unchanged: Binaryen `code-pushing` is still a `LocalAnalyzer` + `Pusher` pass over single-first-assignment local sets, structured block segments, push points, ordered segment movement, and arm-specific `if` sinking.
- `version_130` changes two movement-safety checks in `CodePushing.cpp` relative to `version_129`: `cumulativeEffects.invalidates(effects)` became `effects.orderedBefore(cumulativeEffects)` in both `optimizeSegment(...)` and `optimizeIntoIf(...)`. Treat this as an audit-relevant source drift: future Starshine widening should model ordered-before constraints, not only coarse invalidation.
- The comment typo `rairly rare` was corrected to `fairly rare`; this is not behavior-relevant.
- The `version_130` lit set no longer has a generic `code-pushing.wast` file. The current official proof surface is the named family set listed above.
- `code-pushing-atomics.wast` is new relative to the earlier `version_129` lit set consulted here. It adds GC-read / shared-atomic ordering coverage: pushing a `struct.get` past an atomic load is allowed, while pushing it past an atomic store is not, both for into-`if` and segment movement cases.
- The other consulted `version_130` lit files matched the `version_129` files by content in this refresh.

## Starshine implications

- The existing Starshine pass is still narrower than Binaryen: it does not yet implement general segment movement, `BrOn` / conditional-branch push points, atomics/GC ordering, or broad EH/trap-option behavior.
- The 2026-06-20 post-`if` read slice remains source-backed by the `optimizeIntoIf(...)` comments and lit coverage, but it is not a full replacement for Binaryen's post-if effect and ordered-before proof.
- The next mutating slices should prefer either an analyzer/segment-window inventory or one small source-backed push-point family, with explicit negative coverage for `orderedBefore` / atomic-store boundaries.

## Local reproduction commands

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)

python3 - <<'PY'
import urllib.request, json
url='https://api.github.com/repos/WebAssembly/binaryen/contents/test/lit/passes?ref=version_130'
with urllib.request.urlopen(url, timeout=30) as r:
    data=json.load(r)
for item in data:
    if 'code-pushing' in item['name']:
        print(item['name'])
PY
```

## Consumability rule

For current audit decisions, cite this `version_130` bridge before older current-main or `version_129` captures. Keep older notes as provenance for how the dossier corrected stale `Pusher` / segment-selection claims.
