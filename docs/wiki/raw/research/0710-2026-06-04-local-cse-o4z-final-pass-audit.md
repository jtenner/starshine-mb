---
kind: research
status: supported
last_reviewed: 2026-06-04
sources:
  - ../binaryen/2026-06-04-local-cse-version-130-current-audit-refresh.md
  - ../../binaryen/passes/local-cse/index.md
  - ../../binaryen/passes/local-cse/basic-block-windows-and-barriers.md
  - ../../binaryen/passes/local-cse/implementation-structure-and-tests.md
  - ../../binaryen/passes/local-cse/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/local_cse.mbt
  - ../../../../src/passes/local_cse_test.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../agent-todo.md
---

# Local-CSE O4z Final-Pass Audit

## Scope

Audited active v0.1.0 slice `[O4Z-AUDIT-LCSE]` for `local-cse` as a focused final-pass audit against Binaryen. The audit looked for direct semantic parity gaps, missed Binaryen-positive shapes, and pass-local runtime ownership.

## Why this pass was chosen

`local-cse` has a localized implementation and wiki dossier, sits in the late `-O4z` local-cleanup neighborhood, and has clear Binaryen source-backed positive and negative shapes. That made it a good fit for a focused audit without expanding to every active O4z pass.

## Direct compare evidence

Built the native CLI once:

```sh
moon build --target native --release src/cmd
```

Result: finished with no work to do.

Ran direct pass compare:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 1000 \
  --seed 0x5eed \
  --pass local-cse \
  --out-dir .tmp/pass-fuzz-local-cse-audit-1000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

- compared cases: `998/1000`
- normalized matches: `998`
- compare-normalized matches: `0`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `2`
- mismatches: `0`

The two command failures were agent-classified as Binaryen/tool parse failures for empty recursion groups, not Starshine semantic failures:

- `.tmp/pass-fuzz-local-cse-audit-1000/failures/case-000029-wasm-smith/`
- `.tmp/pass-fuzz-local-cse-audit-1000/failures/case-000573-wasm-smith/`

Both failure metadata entries show Binaryen `wasm-opt` rejecting `Recursion groups of size zero not supported`.

## Functional findings

### No generated semantic mismatches in the 1000-case lane

The direct generated lane did not expose semantic mismatches. Agent classification: no true semantic mismatch found in this audit lane.

### Missed Binaryen-positive shape: before-`if` into `then` reuse

The focused source/wiki review found a durable missed optimization relative to Binaryen's `LinearExecutionWalker` behavior with `connectAdjacentBlocks = true`: Binaryen can reuse a repeated expression computed before an `if` inside the `then` arm. The follow-up 2026-06-04 `version_130` / current-main source refresh at [`../binaryen/2026-06-04-local-cse-version-130-current-audit-refresh.md`](../binaryen/2026-06-04-local-cse-version-130-current-audit-refresh.md) found no teaching-relevant Binaryen drift on this source-backed window model. Current Starshine raw/module `local-cse` does not carry the outer reuse window into the `then` body, so it leaves both trees in place.

Focused repro written under `.tmp/local-cse-audit-perf/before-if-then.wat` during the audit:

```wat
(module
  (func (param i32 i32 i32)
    (drop (i32.add (local.get 0) (local.get 1)))
    (if (local.get 2)
      (then
        (drop (i32.add (local.get 0) (local.get 1)))))))
```

Commands:

```sh
wasm-tools parse .tmp/local-cse-audit-perf/before-if-then.wat \
  -o .tmp/local-cse-audit-perf/before-if-then.wasm
wasm-opt .tmp/local-cse-audit-perf/before-if-then.wasm \
  --all-features --local-cse -S \
  -o .tmp/local-cse-audit-perf/before-if-then.binaryen.wat
target/native/release/build/cmd/cmd.exe --local-cse \
  -o .tmp/local-cse-audit-perf/before-if-then.starshine.wasm \
  .tmp/local-cse-audit-perf/before-if-then.wasm
wasm-opt .tmp/local-cse-audit-perf/before-if-then.starshine.wasm \
  --all-features -S --strip-debug \
  -o .tmp/local-cse-audit-perf/before-if-then.starshine.wat
```

Observed shape:

- Binaryen inserts a fresh local, wraps the first add with `local.tee`, and uses `local.get` in the `then` arm.
- Starshine keeps both `i32.add` trees.

Agent classification: semantic-safe missed optimization / functional parity gap, not a semantic mismatch. The safe fix is nontrivial because current Starshine's raw module-pass rewrite is region-local and would need cross-region binding materialization that can wrap an outer original while replacing a nested `then` repeat.

Suggested next slice: add a failing WAT test for this exact shape, then teach `local-cse` to share eligible outer bindings with the `then` region only, without sharing into the `else` arm or after the `if`. Preserve Binaryen's negative boundaries for after-`if`, else-arm, loops, br_table/switch, returns, throws, unreachable, and try regions.

## Performance findings

The compare harness summary did not report timings for `compare-pass`, so pass-local timing was captured with Starshine tracing and Binaryen debug pass timing on the checked-in debug-WASI artifact.

Starshine command, repeated three times:

```sh
target/native/release/build/cmd/cmd.exe --local-cse --tracing pass \
  -o .tmp/local-cse-audit-perf/starshine-N.wasm \
  tests/node/dist/starshine-debug-wasi.wasm
```

Starshine `perf:timer name=pass:local-cse` results:

- `63,495 us`
- `64,668 us`
- `66,576 us`

Binaryen command, repeated three times:

```sh
wasm-opt tests/node/dist/starshine-debug-wasi.wasm \
  --all-features --local-cse --debug \
  -o .tmp/local-cse-audit-perf/binaryen-debug-N.wasm
```

Binaryen debug pass timing results:

- `0.109826 seconds`
- `0.108852 seconds`
- `0.110042 seconds`

Agent classification: Starshine direct pass-local time is acceptable on this artifact. The observed Starshine pass timer is about `63-67 ms`; Binaryen reports about `109-110 ms` for the pass. This clears the repository target `starshine_time <= 2 * binaryen_time` for this sampled artifact.

Caveat: this is artifact-level pass timing, not a full runtime study. Whole-command wall time, parse/emit, validation, and harness overhead remain `[WALL]001` territory unless future evidence shows `local-cse` itself owns a regression.

## Test and source gap review

Current adjacent tests cover repeated arithmetic roots, parent-over-child preference, load/store barriers, and local-write invalidation. The audit found the following missing source-backed shapes worth adding before closing `[O4Z-AUDIT-LCSE]`:

1. before-`if` into `then` positive (confirmed missed optimization above)
2. after-`if` negative, to prevent accidentally widening reuse past Binaryen's window
3. else-arm negative, paired with the then-arm positive
4. loop/control boundary negatives
5. explicit tiny-root no-op such as repeated `global.get`
6. GC/generative-root negatives such as `struct.new` / `array.new*` where supported by the local fixture stack
7. idempotent direct-call positive only if Starshine has enough annotation plumbing to model the Binaryen exception safely

## Follow-up implementation on 2026-06-04

The before-`if` / then-arm gap was fixed in `src/passes/local_cse.mbt` with focused tests in `src/passes/local_cse_test.mbt`.

Added tests:

- `local-cse reuses before-if expression in then arm`
- `local-cse does not reuse before-if expression after if`
- `local-cse does not reuse before-if expression in else arm`

The implementation keeps the fix narrow: the raw/module path now lets eligible active outer whole-tree bindings feed the `then` body only, while clearing the active window after the `if` so after-`if` code does not reuse the pre-`if` expression. It does not share into the `else` arm and does not turn LCSE into CFG-wide CSE.

Focused test evidence:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
```

Results: local LCSE tests passed (`8/8`), and `src/passes` passed (`1554/1554`).

Refreshed direct compare after the fix:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass local-cse \
  --out-dir .tmp/pass-fuzz-local-cse-then-arm-fix-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

- compared cases: `6768/10000`
- normalized matches: `6768`
- compare-normalized matches: `0`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `20`
- mismatches: `0`

Agent classification for the remaining command failures: Binaryen/tool command failures, not Starshine semantic failures. The harness classified them as `17` Binaryen empty-recursion-group failures, `1` Binaryen bad-section-size failure, `1` Binaryen table-index-out-of-range failure, and `1` Binaryen invalid-tag-index failure.

Refreshed pass-local timing after the fix on `tests/node/dist/starshine-debug-wasi.wasm`:

- Starshine `pass:local-cse`: `70,041-71,766 us`
- Binaryen `wasm-opt --debug --local-cse`: `0.106804-0.108003 seconds`

Agent classification: pass-local runtime remains within the repository 2x Binaryen budget.

## Follow-up tiny-root no-op coverage on 2026-06-04

A later focused LCSE hardening slice added a durable direct test for the source-backed profitability rule that repeated tiny roots such as `global.get` should remain unmaterialized. The new `local-cse leaves repeated tiny global.get roots unmaterialized` fixture in `src/passes/local_cse_test.mbt` passes without implementation changes: Starshine keeps both `global.get` instructions, adds no temp locals, and emits no `local.tee`. Agent classification: missing coverage only, not a functional gap.

## Follow-up loop-boundary negative coverage on 2026-06-04

A later focused LCSE hardening slice added a durable direct test for the source-backed loop-window rule. The new `local-cse does not reuse before-loop expression in loop body` fixture proves an arithmetic expression computed before a `loop` is not materialized and reused inside that loop body. The test passed without implementation changes, matching the Binaryen spot check for the same WAT shape. Agent classification: missing coverage only, not a functional gap.

Validation for this loop-boundary slice:

```sh
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass local-cse \
  --out-dir .tmp/pass-fuzz-local-cse-loop-boundary-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: focused LCSE tests passed (`10/10`), `src/passes` passed (`1556/1556`), full `moon test` passed (`4741/4741`), native build was already up to date, and direct compare reached `6767` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification for those command failures: Binaryen/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index). `moon info` was retried and still hit the known Moon internal panic (`index out of bounds: the len is 36 but the index is 8329485`).

## Follow-up return-boundary negative coverage on 2026-06-04

A later focused LCSE hardening slice added a durable direct test for a return hard-control boundary. The new `local-cse does not reuse expression across return boundary` fixture proves an arithmetic expression computed before `return` is not materialized and reused in the unreachable continuation. The test passed without implementation changes, matching the Binaryen spot check for the same WAT shape. Agent classification: missing coverage only, not a functional gap.

Validation for this return-boundary slice:

```sh
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass local-cse \
  --out-dir .tmp/pass-fuzz-local-cse-return-boundary-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: `moon fmt` passed, focused LCSE tests passed (`11/11`), `src/passes` passed (`1557/1557`), full `moon test` passed (`4742/4742`), native build was already up to date, and direct compare reached `6771` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification for those command failures: Binaryen/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index). `moon info` was retried and still hit the known Moon internal panic (`index out of bounds: the len is 36 but the index is 8329485`).

## Follow-up `br_table` boundary negative coverage on 2026-06-04

A later focused LCSE hardening slice added a durable direct test for a switch-like `br_table` hard-control boundary. The new `local-cse does not reuse expression across br-table boundary` fixture proves an arithmetic expression computed before `br_table` is not materialized and reused in the unreachable continuation. The test passed without implementation changes, matching the Binaryen spot check for the same WAT shape. Agent classification: missing coverage only, not a functional gap.

Validation for this `br_table` boundary slice:

```sh
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass local-cse \
  --out-dir .tmp/pass-fuzz-local-cse-br-table-boundary-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: `moon fmt` passed, focused LCSE tests passed (`12/12`), `src/passes` passed (`1558/1558`), full `moon test` passed (`4743/4743`), native build was already up to date, and direct compare reached `6771` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification for those command failures: Binaryen/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index). `moon info` was retried and still hit the known Moon internal panic (`index out of bounds: the len is 36 but the index is 8329485`).

## Follow-up `unreachable` boundary negative coverage on 2026-06-04

A later focused LCSE hardening slice added a durable direct test for an `unreachable` hard-control boundary. The new `local-cse does not reuse expression across unreachable boundary` fixture proves an arithmetic expression computed before `unreachable` is not materialized and reused in the unreachable continuation. The test passed without implementation changes, matching the Binaryen spot check for the same WAT shape. Agent classification: missing coverage only, not a functional gap.

Validation for this `unreachable` boundary slice:

```sh
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass local-cse \
  --out-dir .tmp/pass-fuzz-local-cse-unreachable-boundary-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: `moon fmt` passed, focused LCSE tests passed (`13/13`), `src/passes` passed (`1559/1559`), full `moon test` passed (`4744/4744`), native build was already up to date, and direct compare reached `6765` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification for those command failures: Binaryen/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index). `moon info` was retried and still hit the known Moon internal panic (`index out of bounds: the len is 36 but the index is 8329485`).

## Recommendation

The audited before-`if`/then-arm Binaryen-positive gap is now covered and fixed, the tiny-root repeated-`global.get` no-op is explicitly covered, and before-loop into loop-body, `br_table`, `return`, and `unreachable` negatives are covered. Keep `[O4Z-AUDIT-LCSE]` active only for the remaining broader shape hardening that was not implemented here: hard control-boundary negatives beyond the added after-`if`, else-arm, loop-body, `br_table`, return, and `unreachable` tests, GC/generative-root negatives, and idempotent-call positives if the local annotation plumbing can model Binaryen safely.
