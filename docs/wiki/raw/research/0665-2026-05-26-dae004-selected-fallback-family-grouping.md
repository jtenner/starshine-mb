# DAE004 selected fallback family grouping

Date: 2026-05-26

## Scope

Recovery/completion slice for `[DAE004-D2]`: group the remaining productive selected dropped-result fallback entries before choosing a smallest family for replacement.

This is a classification-only slice. It does not change optimizer behavior or remove fallback entries.

## Trace evidence

Generated a fresh pass trace from the debug artifact with the metadata added by note `0664`:

```sh
target/native/release/build/cmd/cmd.exe --tracing pass --dae-optimizing \
  -o .tmp/dae004-d2-cmd-trace/out.wasm \
  tests/node/dist/starshine-debug-wasi.wasm \
  > .tmp/dae004-d2-cmd-trace/stdout.txt \
  2> .tmp/dae004-d2-cmd-trace/stderr.txt

grep 'selected-dropped-result-candidate' \
  .tmp/dae004-d2-cmd-trace/stderr.txt \
  > .tmp/dae004-d2-cmd-trace/selected.txt
```

The trace reported all `19` remaining selected fallback candidates from the post-`3799` list. Every candidate had `direct == dropped` and `live=0`, so this grouping is about scheduler reach/order and family shape, not mixed live callers.

The Starshine output validated:

```sh
wasm-opt --all-features .tmp/dae004-d2-cmd-trace/out.wasm -o /tmp/dae004-d2-validated.wasm
```

`wasm-opt` succeeded with only the existing large-local-count VM warning.

## Family grouping

### Single-caller singleton family

Likely smallest replacement family for `[DAE004-D3]` because each entry has exactly one current caller and no live direct calls:

| callee def | callers | direct/dropped |
| --- | --- | --- |
| `445` | `[444]` | `1/1` |
| `3834` | `[374]` | `1/1` |
| `4106` | `[469]` | `1/1` |
| `4249` | `[4231]` | `1/1` |

These are the best first candidates for a narrow fact/bucket replacement because a focused regression can prove one formerly selected-only callee is reached without increasing the broad large-module productive cap.

### Tiny multi-caller family

Small caller sets with all direct calls dropped:

| callee def | callers | direct/dropped |
| --- | --- | --- |
| `459` | `[448, 458]` | `2/2` |
| `4229` | `[250, 561]` | `2/2` |
| `4232` | `[484, 669, 729]` | `4/4` |
| `4241` | `[500, 1847]` | `2/2` |
| `4242` | `[502, 503]` | `4/4` |

This looks like a second wave after singleton proof because the result-removal preconditions are still simple, but caller-filtered rewriting has to handle more than one caller.

### Mid-prefix dense caller family

Mid-prefix entries with local caller neighborhoods and higher call counts:

| callee def | callers | direct/dropped |
| --- | --- | --- |
| `298` | `[280, 281]` | `7/7` |
| `299` | `[220, 277, 279, 281]` | `10/10` |
| `427` | `[365, 366, 367, 371, 373, 376, 378, 381, 384, 385, 386, 388, 392, 394, 395, 396, 397, 400, 401, 411, 412, 414]` | `37/37` |
| `472` | `[445, 446, 447, 467]` | `5/5` |
| `476` | `[444, 447, 467]` | `11/11` |
| `503` | `[502]` | `5/5` |

These should not be grouped solely by index proximity: `503` is a singleton caller by caller-set size, but has five dropped calls and sits near the current Func509 diagnostic boundary, so it is riskier than the one-call singleton family.

### High-index bridge family

High callee indexes with one or more low/mid callers:

| callee def | callers | direct/dropped |
| --- | --- | --- |
| `3566` | `[253, 1148, 1149, 3556]` | `4/4` |
| `3732` | `[456]` | `546/546` |
| `3814` | `[348, 390, 1966, 1975, 1976, 1993, 1996, 2009, 2026, 2049, 2054, 2103]` | `20/20` |

`3732` has only one caller but very high call multiplicity, so it should not be treated like the one-call singleton family. These entries likely need bucket-neighborhood or refreshed-fact scheduling evidence rather than a simple singleton proof.

### Late cluster family

The late `4240..4249` entries form a visible cluster, but trace metadata splits them by caller shape:

- `4240`: callers `[412, 499, 500]`, `8/8`.
- `4241`: callers `[500, 1847]`, `2/2`.
- `4242`: callers `[502, 503]`, `4/4`.
- `4249`: callers `[4231]`, `1/1`.

Use the caller/fact shape above rather than deleting the whole cluster at once. `4249` is the narrowest first late-cluster candidate.

## Next slice recommendation

For `[DAE004-D3]`, start with one single-caller singleton, preferably `445`, `3834`, `4106`, or `4249`. The focused regression should prove the fact-driven or bucketed path can reach that callee without the handpicked fallback entry and without raising the broad large-module cap. Only after artifact validation, timing, and direct compare evidence should the corresponding fallback entry be gated or deleted.

## Status

`[DAE004-D2]` is complete as a trace-backed classification slice. `[DAE004-D3]` remains open for a test-first replacement of one smallest family.
