# OptimizeInstructions OI-M residual summary tooling

_Date:_ 2026-07-03
_Status:_ ACCEL004 completed; no immediate OI-M acceleration blockers remain.

## Question

Can existing OI-M compare results be summarized in a paste-ready form without manual JSON spelunking, including counts, cache/runtime details, per-label profile counts, and an explicit raw-mismatch caveat?

## Red-first test

`src` behavior did not change, but script behavior did. The focused Bun test was updated first:

- `scripts/lib/oi-parity-sweep.test.ts::summarizes existing result JSON and case-label statuses` now constructs a fixture `result.json` with command failure classes, runtime counts, runtime matrix summary, and cache counters.
- The test expects formatted lines for command classes, Binaryen and wasm-smith cache counts, runtime checked/unsupported/failed counts, runtime matrix outcome/summary, case-label statuses, and a raw mismatch caveat.

Red-first command:

```sh
bun test scripts/lib/oi-parity-sweep.test.ts
```

It failed because `formatOiParitySweepReport` did not yet emit `command classes: binaryen:rec-group-zero=1`, cache counts, runtime counts/matrix, or the raw mismatch caveat.

## Implementation

`scripts/lib/oi-parity-sweep.ts` now extends `--summarize-existing` result summaries with:

- compared / normalized / cleanup-normalized / raw mismatch counts;
- validation / generator / property / command failure counts;
- command failure class counts;
- Binaryen cache hit/miss counts;
- Binaryen failure cache hit/miss counts;
- wasm-smith cache hit/miss counts;
- runtime checked / unsupported / failed counts;
- runtime execution matrix outcome and summary counts;
- selected GenValid profile counts;
- GenValid profile-case counts;
- case-label status counts from `cases.jsonl`;
- failure-dir count;
- explicit caveat: raw mismatches remain agent-classified active parity evidence unless separately measured and accepted.

This extends existing TypeScript tooling. It does not add a shell script and does not auto-classify mismatches as semantically safe.

## Validation

Focused test after implementation:

```sh
bun test scripts/lib/oi-parity-sweep.test.ts
```

Result: passed 8/8 tests with 40 assertions.

Existing OI-M result summary:

```sh
bun scripts/oi-parity-sweep.ts --family OI-M --out-dir .tmp/oi-m-generalized-selected-count108-20260703 --summarize-existing
```

Result summary emitted:

- compared `108`;
- normalized `0`;
- cleanup `0`;
- mismatches `108`;
- validation / generator / property / command failures `0 / 0 / 0 / 0`;
- command classes `<none>`;
- cache `binaryen=108/0 binaryen-failures=0/0 wasm-smith=0/0`;
- runtime `checked=108 unsupported=0 failed=0`;
- runtime matrix `all-equal total=9 equalResults=9 equalTraps=0 unsupportedRuntimes=0 nondeterministicImports=0 semanticMismatches=0`;
- selected profile `pass-oi-tuple=108`;
- all 18 `pass-oi-tuple` profile cases with counts;
- all case labels with mismatch counts;
- failure dirs `108`;
- raw mismatch caveat.

## Backlog effect

`agent-todo.md` removes ACCEL004. The immediate OI-M acceleration-blocker section now states that ACCEL001 through ACCEL004 are complete.

The parity matrix marks `OI-M-SB006-fuzz-runtime-residual-classification` as covered by the summary helper. OI-M remains active/P0 for implementation sub-blockers:

- `OI-M-SB002` multi-result non-selected siblings;
- `OI-M-SB003` multi-use/local-carried tuple producers;
- `OI-M-SB004` control/branch/EH siblings;
- `OI-M-SB005` generalized tuple-scratch reconstruction/localization.

## Reopening criteria

Reopen ACCEL004 / `OI-M-SB006` if summaries omit compared/normalized/cleanup/raw counts, failure classes, Binaryen or wasm-smith cache counts, runtime checked/unsupported/failed counts, runtime matrix outcome/summary, per-label profile/case-label counts, failure-dir counts, or the explicit raw-mismatch caveat.

Also reopen if tooling starts auto-classifying raw mismatches as safe without agent evidence.

## Closure guard

This tooling does not close OI-M. Runtime-green raw mismatch lanes remain supporting evidence only and do not close OI-M or OI-G/OI-I/OI-J/OI-K.
