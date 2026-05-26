# DAE004 selected dropped-result fallback inventory

Date: 2026-05-26

## Scope

Recovery continuation for open `[DAE]004` selected result-removal broadening. This slice closes `[DAE004-A]` by inventorying the current large-artifact handpicked dropped-result fallback list and checking which entries still produce changes on the latest debug artifact.

No pass behavior changed. This is an evidence and backlog-sync slice to keep later fallback-removal work from guessing which selected entries are still live.

## Source fallback list

The current handpicked dropped-result fallback in `src/passes/dead_argument_elimination.mbt` iterates these defined-function indices after the fact-driven dropped-result scheduler:

- `298`, `299`, `427`, `445`, `459`, `472`, `476`, `3566`, `3732`, `3799`, `3814`, `3834`, `4106`, `4229`, `4232`, `503`, `4240`, `4241`, `4242`, `4249`.

The separate selected Func298 loop-carrier cleanup and Func299 inverted-result-if cleanup still run after the dropped-result fallback, so they are not counted as dropped-result fallback entries for this inventory.

## Latest artifact trace

Command:

```sh
target/native/release/build/cmd/cmd.exe \
  --dead-argument-elimination-optimizing \
  --tracing pass \
  --out .tmp/dae004a-trace.wasm \
  tests/node/dist/starshine-debug-wasi.wasm \
  > .tmp/dae004a-trace.stdout \
  2> .tmp/dae004a-trace.stderr
```

The fact-driven large-artifact lane remained capped at eight productive descending candidates and reported:

- `4651`, `4650`, `4649`, `4648`, `4647`, `4646`, `4645`, `4644`.

The selected dropped-result fallback still reported changes for:

- `298`, `299`, `427`, `445`, `459`, `472`, `476`, `3566`, `3732`, `3814`, `3834`, `4106`, `4229`, `4232`, `503`, `4240`, `4241`, `4242`, `4249`.

The only handpicked list entry that did not report a selected dropped-result change on this latest traced artifact was:

- `3799`.

Do not remove `3799` from the fallback list from this trace alone. Retiring stale selected entries still needs a behavior-preserving artifact validation slice, because earlier selected-lane rewrites and iteration ordering may affect whether a later entry becomes productive.

## Timing-only and validation evidence

Timing-only replay command:

```sh
bun scripts/self-optimize-compare.ts \
  tests/node/dist/starshine-debug-wasi.wasm \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --dae-optimizing \
  --timing-only \
  --out-dir .tmp/dae004a-inventory-20260526
```

Result from `.tmp/dae004a-inventory-20260526/result.json`:

- Starshine pass runtime: `1715.796ms`.
- Binaryen pass runtime: `846.821ms`.
- Agent judgment: slightly over the project pass-local floor (`1715.796 > 2 * 846.821` by about `22.154ms`), but this documentation-only slice did not change pass behavior; prior note `0626` remained inside target at `1704.905ms` versus `862.911ms`.

Artifact validation command:

```sh
wasm-opt --all-features .tmp/dae004a-trace.wasm -o /tmp/dae004a-trace-validated.wasm
```

Result: passed with only the existing large-local-count VM warning.

## Classification

No fuzz/compare refresh was run because this slice did not change optimizer behavior. The inventory is an artifact-trace classification, not a semantic mismatch classification. The active full direct-fuzz classification remains the accepted DAE010/DAE011 family until a future behavior-changing DAE004 slice reruns compare-pass evidence.

## Status

`[DAE004-A]` is closed for the current artifact: the live handpicked dropped-result fallback set is inventoried, and `3799` is identified as the only currently unobserved selected dropped-result entry in the latest trace.

`[DAE]004` remains open. Next work is `[DAE004-B]`: for each still-productive fallback entry, classify why the fact-driven scheduler did not cover it (ordering, iteration cap, stale facts, mixed dropped/undropped calls, dead-suffix handling, signature repair, or type-liveness constraints).