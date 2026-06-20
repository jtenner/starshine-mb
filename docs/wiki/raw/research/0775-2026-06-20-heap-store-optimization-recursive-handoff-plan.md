---
kind: research
status: current
last_reviewed: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/binaryen-strategy.md
  - ../../binaryen/passes/heap-store-optimization/starshine-hot-ir-strategy.md
  - ../../binaryen/passes/heap-store-optimization/wat-shapes.md
  - ../../binaryen/passes/heap-store-optimization/swap-safety-and-control-flow.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
  - ../../../../agent-todo.md
  - ../../../../src/passes/heap_store_optimization.mbt
  - ../../../../src/passes/heap_store_optimization_test.mbt
related:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ./0530-2026-05-06-heap-store-optimization-direct-revalidation.md
---

# `heap-store-optimization` recursive parity handoff plan

## User goal

Implement `heap-store-optimization` completely by identifying all Binaryen behavior gaps and implementing them in Starshine. The target is **Binaryen behavior parity, not output parity**. Output differences should be fixed unless they are explicitly proven Starshine wins compared to Binaryen.

## Completion criteria inferred for the recursive handoff chain

The HSO chain is complete only when all of these are true:

1. The current Binaryen release-oracle behavior for `heap-store-optimization` has been refreshed or explicitly justified from the existing no-drift dossier.
2. Starshine implements every source-backed Binaryen HSO behavior family that can affect observable pass behavior, or records a narrow user-approved non-goal with reopening criteria.
3. Direct pass output differences are fixed unless inspected and documented as semantic-safe Starshine wins such as smaller canonical output without semantic or validation risk.
4. Focused tests cover positive and negative behavior families: tee folds, subsequent local-set folds, chains, default/descriptor constructors, old-field side-effect preservation, target-local hazards, later-field and descriptor effect barriers, constructor shallow-effect barriers, control-flow skip hazards, safe function-external exits, in-function branch/catch negatives, swap legality, unreachable no-fold boundaries, and explicit non-goals.
5. Direct compare evidence is refreshed with the required pass workflow: ordinary implementation slices use at least a 10000-case compare when behavior changes; final closeout uses a 100000-case direct lane plus focused/full Moon validation and native `src/cmd` build.
6. O4z slot/neighborhood evidence for the early and late HSO slots is refreshed and classified separately from direct-pass evidence.
7. Docs and backlog no longer describe broad HSO gaps; any residual differences are narrow, evidence-backed, and have reopening criteria.

## Current starting state

Useful starting facts from the existing docs and source map:

- `heap-store-optimization` is active as a Starshine hot pass.
- Binaryen's pass is narrow despite the name: it folds `struct.set` into nearby fresh `struct.new` forms; generic heap dead-store elimination and load forwarding remain upstream TODOs, not current parity requirements.
- Existing Starshine tests already cover many reduced positive and negative families in `src/passes/heap_store_optimization_test.mbt`.
- The last direct revalidation is stale for the current release-gating standard: `0530` recorded a 2026-05-06 `--count 10000` compare with `6759` normalized matches and `0` mismatches, but it predates the current O4z audit standard and did not close ordered-slot evidence.
- Existing O4z slot evidence reported exact equality for slots `17` and `45`, but both were `starshinePassSkippedRaw = true`; that is regression evidence, not complete behavior proof.
- `agent-todo.md` had only a compact HSO entry before this plan; it now needs a behavior-slice chain like recent OI work.

## Proposed slice order

### `[O4Z-AUDIT-HSO-A]` Source and behavior inventory refresh

Refresh the current local Binaryen oracle and local code map before implementing behavior. Use existing pages as the base, but re-check whether `version_130` or current local `wasm-opt --version` changes any HSO contract since the May `version_129` / current-main no-drift dossier. Produce an inventory table with Binaryen visitor/helper/lit families mapped to Starshine tests, implementation helpers, explicit boundaries, and unknowns.

Suggested outputs:

- update this research chain or create the next numbered HSO inventory note;
- update `docs/wiki/binaryen/passes/heap-store-optimization/index.md` freshness if the oracle shifts;
- update `agent-todo.md` sub-slice statuses.

### `[O4Z-AUDIT-HSO-B]` Baseline direct pass and saved O4z slots

Build native `src/cmd`, run a fresh direct compare smoke, and refresh early/late HSO slot evidence. Classify differences as behavior gaps, Starshine wins, representation-only, tool/Binaryen failures, validation failures, or unknown/risky.

Recommended direct lane:

```sh
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-hso-b-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures
```

Scale to `10000` before closing any behavior-changing slice.

### `[O4Z-AUDIT-HSO-C]` Tee and subsequent-chain source parity closeout

Audit and fill gaps for the core rewrite families:

- direct `local.tee(struct.new)` under `struct.set`;
- later `local.set(struct.new)` plus `struct.set(local.get)`;
- repeated later stores where the last value wins;
- wrong-local and wrong-pattern no-change cases;
- same-field and different-field chains;
- removal/nop/debris shape differences, fixing drift unless a Starshine cleanup is explicitly a win.

### `[O4Z-AUDIT-HSO-D]` Constructor operand, default, descriptor, and old-field side-effect parity

Audit and fill gaps around constructor construction and side-effect preservation:

- `struct.new_default` default materialization;
- descriptor constructor forms and descriptor barriers;
- later constructor operands as effect barriers;
- shallow constructor effects / allocation ordering;
- preserving old field side effects with sequence/block wrappers;
- validation/refinalization issues for GC reference fields and default null operands.

### `[O4Z-AUDIT-HSO-E]` Target-local and value-movement hazards

Audit and fill gaps for values that read or write the target local, and for values whose effects conflict with constructor operands or descriptor operands. This is where many output differences should be treated as parity gaps until proven Starshine wins, because Binaryen is intentionally conservative around local observation order.

### `[O4Z-AUDIT-HSO-F]` Control-flow and exception skip-local-set parity

Audit and fill gaps for Binaryen's `LazyLocalGraph`-style safety behavior:

- safe branch/control flow contained inside the moved value;
- unsafe branches to outer in-function labels that can skip the moved `local.set` and expose stale local state;
- safe function-external exits such as `return` / return-call forms;
- unsafe in-function catches through `try` / `try_table` when a call/throw can reach a handler inside the function;
- the "one bad get is okay when it is the disappearing struct.set ref" rule.

### `[O4Z-AUDIT-HSO-G]` Swap legality parity

Audit and fill gaps for `trySwap(...)`-style behavior:

- swapping fresh constructor sets across safe blockers;
- refusing to swap the final element;
- refusing constructor ping-pong across another fresh `local.set(struct.new)`;
- effect invalidation barriers;
- field/descriptor/order constraints after swaps;
- Starshine HOT wrapper peeling/flattening differences that either need parity fixes or documented Starshine-win classification.

### `[O4Z-AUDIT-HSO-H]` Explicit non-goals and boundaries

Lock boundaries for shapes outside Binaryen's current contract:

- `array.set` into fresh arrays;
- ordinary memory stores;
- table stores;
- generic heap DSE and load forwarding;
- unreachable constructor/set pairs left for DCE;
- any local WAT/HOT surface limitations.

These should be fail-closed tests only when the behavior is intentionally unsupported by Binaryen or requires missing local representation support.

### `[O4Z-AUDIT-HSO-I]` Performance and raw fast-skip evidence

Refresh pass-local timings and raw fast-skip behavior. Preserve cheap no-candidate behavior, especially on large artifacts. If Starshine is slower than the repo floor, attribute the pass-local owner instead of hiding it under whole-command `[WALL]001`.

### `[O4Z-AUDIT-HSO-J]` Final closeout

Run final validation and direct compare:

```sh
moon info
moon fmt
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-final-100000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Also refresh HSO early/late O4z slot or neighborhood evidence and update wiki/backlog/log with exact counts, mismatch classes, timing, and remaining accepted boundaries.

## Immediate next recommended slice

Start with `[O4Z-AUDIT-HSO-A]` plus the beginning of `[O4Z-AUDIT-HSO-B]`: refresh the source/behavior inventory and run a small fresh direct baseline. Do not implement behavior until the inventory identifies a concrete gap or mismatch family. If the fresh direct baseline is still green, use the inventory and lit/source gap matrix to pick the first missing focused fixture; likely candidates are descriptor/effect barriers or control-flow skip-local-set parity, because those are the highest-risk semantic surfaces.
