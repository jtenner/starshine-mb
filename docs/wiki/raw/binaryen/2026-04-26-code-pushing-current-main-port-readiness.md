---
kind: raw-source
status: supported
last_reviewed: 2026-04-26
source_type: primary-source-manifest
pass: code-pushing
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/CodePushing.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodePushing.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_into_if.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_ignore-implicit-traps.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_tnh.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing-gc.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing-eh.wast
  - ../../../src/passes/code_pushing.mbt
  - ../../../src/passes/code_pushing_test.mbt
  - ../../../src/passes/optimize.mbt
---

# `code-pushing` Current-Main And Port-Readiness Primary Sources

## What was checked

On 2026-04-26, the official Binaryen repository source for `src/passes/CodePushing.cpp` was re-read on both `main` and tagged `version_129`, then compared against the current Starshine `src/passes/code_pushing.mbt` and focused tests.

This manifest supersedes the 2026-04-25 wiki phrasing that said `BranchSeeker`, `Pusher`, segment selection, and local profitability-style selection were stale or absent. That claim was wrong for the official `version_129` and current-main files checked here: the owner file is built around `LocalAnalyzer`, `Pusher`, `isPushable`, `isPushPoint`, `optimizeSegment`, `optimizeIntoIf`, and cached `EffectAnalyzer` state.

## Upstream Binaryen source facts

- `LocalAnalyzer` computes per-local set/get counts and a weak single-first-assignment property. A local must have exactly one `local.set`, no pre-set get in postorder, and not be a parameter to stay SFA.
- `Pusher` scans each block list for a segment from the first pushable `local.set` to a later push point. Push points include `if`, `switch`, and conditional `br`, with `drop` unwrapped first.
- `isPushable` only accepts `local.set` roots whose local is SFA, whose gets seen so far match total gets, and whose value has no unremovable side effects. Removable side effects may be pushed because the pass only moves code to execute on the same or fewer paths.
- `optimizeSegment` pushes one or more eligible `local.set` roots forward past a push point when cumulative effects do not invalidate the pushed value's effects. It preserves order among pushed roots.
- `optimizeIntoIf` tries to push eligible `local.set` roots into a single arm that reads that local, as long as the other arm does not read it and post-if reads are safe. A post-if read can be safe when the other arm is unreachable.
- The changed paths do not immediately recurse inside the newly pushed arm; comments leave deeper recursion to later optimizer cycles.
- `CodePushing` remains function-parallel and block-local: it analyzes one function, walks expression trees, and constructs a `Pusher` for block lists of at least two roots.

## Official proof surface

The tagged lit tests remain the most useful public examples:

- `code-pushing.wast` for baseline segment pushing.
- `code-pushing_into_if.wast` for arm-sinking and post-if read cases.
- `code-pushing_ignore-implicit-traps.wast` and `code-pushing_tnh.wast` for trap-option behavior.
- `code-pushing-gc.wast` for reference/GC-sensitive movement.
- `code-pushing-eh.wast` for exceptional-control boundaries.

## Starshine source facts

Starshine's active direct pass is intentionally narrower than Binaryen:

- `src/passes/optimize.mbt` registers `code-pushing` as a `HotPass`, but the `optimize` and `shrink` preset arrays still omit it.
- `src/passes/code_pushing.mbt` only pushes const-like `local.set` values (`Const`, `RefNull`, `RefFunc`) into the one `if` arm that contains all reads of that local, provided the local has exactly one write and no extra reads outside that arm.
- The same owner file also has a Starshine-local dead-block flattening helper around unreachable contexts. That helper is useful locally but should not be described as upstream Binaryen `CodePushing.cpp` behavior.
- `src/passes/code_pushing_test.mbt` covers then-arm and else-arm positives, both-arm and later-use bailouts, trap guard, nested-later-use guard, and dead-block flattening positives/negatives.

## Contradictions and uncertainty

- The 2026-04-25 correction that removed `Pusher` and segment-selection terminology is superseded by this manifest.
- The older 2026-04-22 dossier was closer on `Pusher` / segment framing but still needs to be read through the exact SFA/effects/post-if-read rules above.
- The web/raw source rendering used during this check compressed C++ into long logical lines, so wiki pages should cite function/class names and official URLs rather than fragile generated line numbers for this particular file.
