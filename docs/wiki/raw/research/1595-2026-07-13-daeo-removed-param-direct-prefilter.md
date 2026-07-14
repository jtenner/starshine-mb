# DAEO removed-param direct compaction prefilter

Date: 2026-07-13

## Scope

This performance slice refines note `1594` without changing emitted wasm. The first implementation always ran the exact lowered simplify-locals cleanup before checking whether a broad removed-parameter candidate already had enough syntactically unreferenced locals to justify compaction. That exact cleanup can scan large structured bodies even when a direct local-reference count answers the selection question.

## Red-first contract

The existing broad `4097`-definition behavior regression was updated first to require:

```text
pass[dae-optimizing]:broad-removed-param-local-cleanup def=0 removed_locals=96 mode=direct
```

It failed against note `1594` because the selector did not distinguish direct compaction from the exact-cleanup fallback. The trace contract guards the bounded algorithmic choice, not telemetry alone: the fixture's `96` already-unreferenced declarations must be selected without entering the more expensive fallback, while output and plain-DAE separation remain behaviorally asserted.

## Retained refinement

For each already-touched, broad, removed-parameter candidate, DAEO now:

1. counts current local references and attempts direct unused-local compaction;
2. accepts that path when it removes at least `16` locals;
3. runs the prior exact lowered cleanup only when direct compaction is insufficient; and
4. ranks the resulting candidates by removed-local count, then definition index.

The artifact Func `41` still requires `mode=fallback`; the refinement avoids unnecessary exact-cleanup work for other qualifying candidates and keeps the fallback available for the selected family. No artifact index is encoded.

## Fresh output-preserving measurement

Fresh native binary:

```text
_build/native/release/build/cmd/cmd.exe
SHA-256 648217241b157b7144a7e2d1b023688f5a78b52f8d0d7fec5358c28394bc08ac
```

Direct output:

```text
.tmp/daeo-f41-direct-prefilter-20260713/starshine-direct.wasm
SHA-256 b592b4f13de2826798149ddd4e6a9701ddb0af26ee6161d901359d6762de1059
```

That SHA-256 is byte-identical to note `1594`'s output. It validates under `wasm-tools validate --features all`; raw size remains `3197559`, canonical size remains `3275027`, and Func `41` remains `6703` canonical body bytes (`+1286` versus Binaryen).

| measurement | note 1594 | direct prefilter | delta |
|---|---:|---:|---:|
| DAEO pass-local | `13662.779ms` | `12704.043ms` | `-958.736ms` (`-7.0%`) |
| ratio vs Binaryen `8083.49ms` | `1.69x` | `1.57x` | improved |

## Judgment

The refinement is output-preserving and improves the controlled direct replay while remaining inside the required `<=2x` bound. The overall canonical gap remains `+12571`; no additional direct parity difference is classified by this performance-only slice. The final iteration commit must refresh the required four compare lanes, exact-once scheduling, full validation, docs/backlog/log, and continuation target.
