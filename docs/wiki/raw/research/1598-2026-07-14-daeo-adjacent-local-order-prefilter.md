# DAEO adjacent local-order prefilter

Date: 2026-07-14

## Scope

This output-preserving follow-up narrows note `1597`'s type-stable local-order work to the two definitions already selected by the broad adjacent candidate. It does not change DAEO output, plain DAE behavior, public scheduling, or the remaining parity classification.

## Bounded implementation

The first retained helper accepted a module-sized touched bitmap, built a parameter cache for every defined function, allocated a module-sized local-name remap, and scanned every definition even though the caller already had the exact adjacent pair.

The refined helper now accepts the exact two definition indices. It:

- checks only those two definitions;
- resolves their shared function type directly from the flattened type section and caches it for the second definition;
- allocates a module-sized local-name remap only when a name section actually exists;
- preserves the same type-stable local rewrite and name-section semantics.

The trace contract now records `ordered_defs=2`. This is a bounded-work behavior invariant: the DAEO adjacent lane must not silently return to whole-module local-order candidate scanning.

## Red-first contract

The focused adjacent regression first required the new trace suffix and failed because note `1597` emitted only `local_order=type-stable`. It passes after the exact-definition helper is wired, while retaining the same local compaction, observable `i32.const 77` behavior, validation, and plain-DAE separation.

## Output and performance

All three refined artifact runs emitted the same SHA-256 as note `1597`:

```text
58523a1416ac35b6793ab1831fc8d8c827fa583cc02f4c8d712effe0a9263d02
```

Raw output remains `3197484`; Binaryen-v130 canonical output remains `3274937`. The pair body deltas and the overall `+12481` canonical gap are unchanged.

A controlled triplicate replay compared the parent implementation and the exact-definition refinement on the same machine and input:

| implementation | DAEO runs | median |
|---|---|---:|
| note `1597` module-sized helper | `12692.965ms`, `12751.004ms`, `12702.219ms` | `12702.219ms` |
| exact two-definition helper | `12597.558ms`, `12658.665ms`, `12732.876ms` | `12658.665ms` |

The median improves by `43.554ms` (`0.34%`) without changing output. Against Binaryen's `8083.49ms`, the refined median is about `1.57x`, inside the required `<=2x` target.

Fresh refined native binary before the controlled parent rebuild:

```text
_build/native/release/build/cmd/cmd.exe
SHA-256 53ee114fc82b0a2a375145019cbced44372f5c9bfdd799aff0db00397ed2ec00
```

## Judgment

This is an output-preserving bounded-work and measured pass-local performance refinement. It does not classify any remaining direct difference. The next commit must rebuild the final explicit native binary, refresh all required Binaryen-v130 direct/scheduled/validation evidence, and update the living docs, backlog, and log while keeping the remaining `+12481` canonical bytes open.
