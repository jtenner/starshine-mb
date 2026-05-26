# DAE004 selected dropped-result fallback gap classification

Date: 2026-05-26

## Scope

Recovery continuation for open `[DAE]004` selected result-removal broadening. This slice closes `[DAE004-B]` by classifying why the current fact-driven dropped-result scheduler did not cover each still-productive handpicked selected fallback entry on the latest debug artifact.

No pass behavior changed. This is an evidence and backlog-sync slice before designing or implementing a runtime-neutral large-module batching/worklist replacement.

## Evidence

Trace command:

```sh
target/native/release/build/cmd/cmd.exe \
  --dead-argument-elimination-optimizing \
  --tracing pass \
  --out .tmp/dae004b-trace.wasm \
  tests/node/dist/starshine-debug-wasi.wasm \
  > .tmp/dae004b-trace.stdout \
  2> .tmp/dae004b-trace.stderr
```

The fact-driven large-artifact lane reported exactly eight productive descending candidates before the handpicked fallback:

- `4651`, `4650`, `4649`, `4648`, `4647`, `4646`, `4645`, `4644`.

The selected dropped-result fallback then still reported these productive entries:

- `298`, `299`, `427`, `445`, `459`, `472`, `476`, `3566`, `3732`, `3814`, `3834`, `4106`, `4229`, `4232`, `503`, `4240`, `4241`, `4242`, `4249`.

As in note `0628`, `3799` did not report a selected dropped-result fallback change in this latest trace. It did report later in a separate exact-literal lane, so this note does not retire it from the source fallback list.

## Classification

For every still-productive selected dropped-result fallback entry in this trace, the immediate uncovered reason is **ordering plus iteration cap**:

| Fallback entry | Latest selected fallback status | Why fact-driven scheduler did not cover it |
| --- | --- | --- |
| `298` | productive | Descending large-module fact lane spent its eight productive attempts on `4651..4644` before reaching lower-index candidates. |
| `299` | productive | Same ordering/cap blocker. |
| `427` | productive | Same ordering/cap blocker. |
| `445` | productive | Same ordering/cap blocker. |
| `459` | productive | Same ordering/cap blocker. |
| `472` | productive | Same ordering/cap blocker. |
| `476` | productive | Same ordering/cap blocker. |
| `503` | productive | Same ordering/cap blocker; source order runs this entry after `4232` even though its index is low. |
| `3566` | productive | Same ordering/cap blocker. |
| `3732` | productive | Same ordering/cap blocker. |
| `3814` | productive | Same ordering/cap blocker. |
| `3834` | productive | Same ordering/cap blocker. |
| `4106` | productive | Same ordering/cap blocker. |
| `4229` | productive | Same ordering/cap blocker. |
| `4232` | productive | Same ordering/cap blocker. |
| `4240` | productive | Same ordering/cap blocker. |
| `4241` | productive | Same ordering/cap blocker. |
| `4242` | productive | Same ordering/cap blocker. |
| `4249` | productive | Same ordering/cap blocker. |

This classification is deliberately narrow: it explains why the **current bounded fact-driven pass** did not reach these still-productive fallback entries on the debug artifact. It does not prove that simply raising the broad cap is safe. Research note `0607` already rejected naive `defined <= 8192` ascending widening, and notes `0608` through `0626` keep larger artifact modules capped at eight productive descending candidates to preserve the DAE011 pass-local runtime target.

No trace evidence in this slice points to stale facts, mixed dropped/undropped calls, dead-suffix repair, signature repair, or type-liveness as the first blocker for the still-productive fallback set. Those categories remain important guardrails for future behavior-changing slices, especially when a worklist starts revisiting facts after rewrites.

## Next work

`[DAE004-C]` should design a runtime-neutral batching/worklist approach for large modules before raising broad artifact caps. A safe design should avoid repeating the `0607` failure mode by:

- preserving the high-candidate reach proved by the descending lane;
- making progress on lower still-productive fallback families without unbounded whole-module helper calls;
- refreshing call facts or proving they remain valid after each result-removal rewrite;
- keeping caller-filtered rewriting and pass-local timing inside the `Starshine <= 2x Binaryen` target;
- validating the debug artifact with `wasm-opt --all-features` and rerunning direct compare evidence for behavior-changing slices.

## Validation

This slice changed only docs/backlog state. The trace command completed and produced `.tmp/dae004b-trace.wasm`; no optimizer code changed and no fuzz/compare refresh was run. The active full direct-fuzz classification remains the accepted DAE010/DAE011 family until a future behavior-changing DAE004 slice reruns compare-pass evidence.
