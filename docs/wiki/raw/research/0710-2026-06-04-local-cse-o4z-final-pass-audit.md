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

## Follow-up `struct.new` generative-root negative coverage on 2026-06-04

A later focused LCSE hardening slice added a durable direct test for the source-backed GC generativity rule. The new `local-cse does not reuse repeated struct-new roots` fixture proves two identical-looking `struct.new` allocations remain separate and are not replaced by a temp-local reuse. The test passed without implementation changes, matching the Binaryen spot check for the same WAT shape. Agent classification: missing coverage only, not a functional gap.

Validation for this `struct.new` generative-root slice:

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
  --out-dir .tmp/pass-fuzz-local-cse-struct-new-generative-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: `moon fmt` passed, focused LCSE tests passed (`14/14`), `src/passes` passed (`1560/1560`), full `moon test` passed (`4745/4745`), native build was already up to date, and direct compare reached `6769` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification for those command failures: Binaryen/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index). `moon info` was retried and still hit the known Moon internal panic (`index out of bounds: the len is 36 but the index is 8329485`).

## Named-block spot-check caveat on 2026-06-04

While probing the remaining hard-boundary candidates, a simple straight-line named block did **not** behave as a hard-boundary negative in Binaryen. For this shape, Binaryen materialized the expression before the block with `local.tee` and reused it inside the block body, while Starshine kept both trees:

```wat
(module
  (func (param i32 i32)
    (drop (i32.add (local.get 0) (local.get 1)))
    (block $named
      (drop (i32.add (local.get 0) (local.get 1))))))
```

Agent classification: semantic-safe missed optimization / follow-up candidate, not a semantic mismatch and not a hard-boundary negative. This should be triaged separately from branchy block exits and from the already covered `br_table`, `return`, and `unreachable` negatives.

## Follow-up named-block positive fix on 2026-06-04

A later focused LCSE hardening slice converted the named-block caveat into a test-first implementation fix. The new `local-cse reuses before-block expression in straight-line block` fixture initially failed because Starshine left both `i32.add` trees in place. The raw/module path now records eligible outer whole-tree repeats for a plain block body and rewrites the nested repeat to `local.get` after materializing the outer original with `local.tee`. The fix is intentionally narrow: it shares into the block body, not into loops or through hard terminators.

Validation for this named-block positive slice:

```sh
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass local-cse \
  --out-dir .tmp/pass-fuzz-local-cse-named-block-positive-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the focused LCSE test first failed (`14/15` before the implementation), then passed after the implementation (`15/15`); `moon fmt` passed; `src/passes` passed (`1561/1561`); full `moon test` passed (`4746/4746`); native build succeeded; and direct compare reached `6771` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification for those command failures: Binaryen/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index). `moon info` was retried and still hit the known Moon internal panic (`index out of bounds: the len is 36 but the index is 8329485`).

Agent classification: semantic-safe missed optimization parity fix, not a semantic mismatch.

## Follow-up `struct.new_default` generative-root coverage on 2026-06-04

A later focused LCSE hardening slice added another supported GC generativity fixture. A first attempted direct WAT fixture for `array.new` confirmed the Binaryen expected shape but failed in the local direct-pass WAT test path, matching the existing WAST/core split that ordinary `array.*` text is not exposed there. The slice therefore used the supported `struct.new_default` text family. The new `local-cse does not reuse repeated struct-new-default roots` fixture proves two default-constructed structs remain separate and are not replaced by a temp-local reuse. The test passed without implementation changes, matching the Binaryen spot check for the same WAT shape. Agent classification: missing coverage only, not a functional gap.

Validation for this `struct.new_default` generative-root slice:

```sh
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass local-cse \
  --out-dir .tmp/pass-fuzz-local-cse-struct-new-default-generative-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: `moon fmt` passed, focused LCSE tests passed (`16/16`), `src/passes` passed (`1562/1562`), full `moon test` passed (`4747/4747`), native build was already up to date, and direct compare reached `6764` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification for those command failures: Binaryen/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index). `moon info` was retried and still hit the known Moon internal panic (`index out of bounds: the len is 36 but the index is 8329485`).

## Follow-up idempotent direct-call positive fix on 2026-06-04

A later focused LCSE hardening slice inspected the local annotation plumbing before touching call CSE. Starshine already parses and lowers `(@binaryen.idempotent)` function annotations into `FuncAnnotationSec`, but `local-cse` was not consulting callee annotations or function signatures. A Binaryen text-input spot check showed the source-backed positive: Binaryen materialized a repeated single-result direct call to an annotated idempotent callee with `local.tee` and reused it with `local.get`. The same WAT fixture first failed in Starshine (`16/17`) because both calls remained separate. The raw/module path now builds a function-index call-info table from imports, `func_sec`, the type section, and `FuncAnnotationSec`; it only treats direct `call` roots as candidates when the target has an exact `binaryen.idempotent` annotation and exactly one result. Ordinary non-annotated calls, `call_indirect`, and `call_ref` still clear the reuse window.

Validation for this idempotent-call slice:

```sh
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass local-cse \
  --out-dir .tmp/pass-fuzz-local-cse-idempotent-call-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: focused LCSE test first failed (`16/17` before the implementation), then passed after the implementation and paired ordinary-call negative (`18/18`); `moon fmt` passed; `src/passes` passed (`1564/1564`); full `moon test` passed (`4749/4749`); native build succeeded; and direct compare reached `6770` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification for those command failures: Binaryen/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index). `moon info` was retried and still hit the known Moon internal panic (`index out of bounds: the len is 36 but the index is 8329485`).

Agent classification: semantic-safe missed optimization parity fix, not arbitrary call CSE; the paired ordinary direct-call negative keeps non-annotated calls as barriers.

## Follow-up `call_indirect` root negative coverage on 2026-06-04

A later focused LCSE hardening slice added a durable direct test for the indirect-call half of the call-barrier surface. Binaryen spot-checking a repeated `call_indirect` root kept both calls and emitted no `local.tee`, unlike the annotated idempotent direct-call positive. The new `local-cse does not reuse call-indirect roots` fixture passes without implementation changes: Starshine keeps the repeated indirect calls separate and appends no temp local. Agent classification: missing coverage only, not a functional gap.

Validation for this `call_indirect` root slice:

```sh
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass local-cse \
  --out-dir .tmp/pass-fuzz-local-cse-call-indirect-root-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: `moon info` still hit the known Moon internal panic (`index out of bounds: the len is 36 but the index is 8329485`); `moon fmt` passed; focused LCSE tests passed (`19/19`); `src/passes` passed (`1565/1565`); full `moon test` passed (`4750/4750`); native build was already up to date; and direct compare reached `6768` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification for those command failures: Binaryen/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up core `array.new` generative-root coverage on 2026-06-04

A later focused LCSE hardening slice converted the earlier `array.new` deferral into a core-built fixture instead of widening WAT syntax. The Binaryen spot check for ordinary text kept both `array.new` roots and emitted no `local.tee`; the local test constructs the same shape through `@lib.Module`, `@lib.CompType::array`, and `@lib.Instruction::array_new(...)`, then runs `local_cse_run_module_pass(...)`. The new `local-cse does not reuse repeated array-new roots` fixture passes without implementation changes: Starshine keeps both `array.new` instructions and appends no temp local. Agent classification: missing coverage only, not a functional gap.

Validation for this `array.new` generative-root slice:

```sh
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass local-cse \
  --out-dir .tmp/pass-fuzz-local-cse-array-new-generative-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: `moon info` still hit the known Moon internal panic (`index out of bounds: the len is 36 but the index is 8329485`); `moon fmt` passed; focused LCSE tests passed (`20/20`); `src/passes` passed (`1566/1566`); full `moon test` passed (`4751/4751`); native build was already up to date; and direct compare reached `6770` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification for those command failures: Binaryen/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up `try_table` body positive fix on 2026-06-04

A later focused LCSE hardening slice checked the proposed EH hard-boundary candidate and found the opposite shape in Binaryen: a repeated expression computed before a `try_table` can be materialized and reused inside the try body, even with a catch target. The new `local-cse reuses before-try-table expression in try body` fixture first failed (`20/21`) because Starshine left both trees in place. The raw/module path now treats `try_table` bodies like the already-supported straight-line block body for eligible outer whole-tree repeats, while clearing nested reuse across hard terminators inside nested bodies so the bridge does not become CFG-wide CSE.

Validation for this `try_table` body slice:

```sh
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass local-cse \
  --out-dir .tmp/pass-fuzz-local-cse-try-table-body-positive-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: `moon info` still hit the known Moon internal panic (`index out of bounds: the len is 36 but the index is 8329485`); `moon fmt` passed; focused LCSE tests passed (`21/21` after the implementation); `src/passes` passed (`1567/1567`); full `moon test` passed (`4752/4752`); native build was already up to date with existing unused-function warnings in `src/passes/pass_manager.mbt`; and direct compare reached `6767` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification for those command failures: Binaryen/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

Agent classification: Binaryen-positive missed optimization parity fix, not a hard-boundary negative; the fix is intentionally limited to nested straight-line body reuse.

## Recommendation

The audited before-`if`/then-arm, simple before-block/straight-line-block, before-`try_table`/try-body, and annotated idempotent direct-call Binaryen-positive gaps are now covered and fixed, the tiny-root repeated-`global.get` no-op is explicitly covered, repeated `struct.new`, `struct.new_default`, and core `array.new` generative roots are covered, repeated `call_indirect` roots are covered, and before-loop into loop-body, `br_table`, `return`, and `unreachable` negatives are covered. Keep `[O4Z-AUDIT-LCSE]` active only for the remaining broader shape hardening that was not implemented here: hard control-boundary negatives beyond the added after-`if`, else-arm, loop-body, `br_table`, return, and `unreachable` tests; any additional GC/generative-root variants where local syntax supports them; and `call_ref` barrier negatives paired with the newly covered idempotent-call exception plus ordinary direct-call and `call_indirect` root negatives.

## Follow-up call_ref root negative coverage on 2026-06-04

A later focused LCSE hardening slice added durable direct coverage for repeated `call_ref` roots. Binaryen kept both `call_ref` roots in the WAT spot check and introduced no `local.tee`; the first attempted Starshine WAT fixture exposed local WAT-path awkwardness, so the landed regression is a core-built module fixture using `ref.func` plus `Instruction::call_ref`. The fixture passed without implementation changes. Agent classification: missing coverage only, not a functional gap.

Validation for this `call_ref` slice:

```sh
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass local-cse \
  --out-dir .tmp/pass-fuzz-local-cse-call-ref-root-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the initial WAT-form test failed in local parsing/modeling, then the core-built fixture passed. `moon info` hit the known Moon internal panic (`index out of bounds: the len is 36 but the index is 8329485`); `moon fmt` passed; focused LCSE tests passed (`22/22`); `moon test src/passes` passed (`1568/1568`); full `moon test` passed (`4753/4753`); native build was already up to date; direct compare reached `6768` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification for those command failures: Binaryen/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up array.new_default generative-root coverage on 2026-06-04

A later focused LCSE hardening slice added durable direct coverage for repeated `array.new_default` roots. Binaryen kept both `array.new_default` roots in the WAT spot check and introduced no `local.tee`; the first attempted Starshine WAT fixture exposed the same local WAT-path awkwardness as ordinary `array.new`, so the landed regression is a core-built module fixture. The fixture passed without implementation changes. Agent classification: missing coverage only, not a functional gap.

Validation for this `array.new_default` slice:

```sh
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass local-cse \
  --out-dir .tmp/pass-fuzz-local-cse-array-new-default-generative-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the initial WAT-form test failed in local parsing/modeling, then the core-built fixture passed. `moon info` hit the known Moon internal panic (`index out of bounds: the len is 36 but the index is 8329485`); `moon fmt` passed; focused LCSE tests passed (`23/23`); `moon test src/passes` passed (`1569/1569`); full `moon test` passed (`4754/4754`); native build was already up to date; direct compare reached `6768` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification for those command failures: Binaryen/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up try_table body unreachable-boundary coverage on 2026-06-04

A later focused LCSE hardening slice added durable direct coverage for the paired hard-terminator side of the `try_table` body bridge. Binaryen keeps a repeated expression before `try_table` separate from the same expression after an `unreachable` inside the try body, and introduces no `local.tee`. The Starshine fixture passed without implementation changes because the nested repeat scan already clears the borrowed outer window at hard terminators. Agent classification: missing coverage only, not a functional gap.

Validation for this `try_table` body unreachable-boundary slice:

```sh
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass local-cse \
  --out-dir .tmp/pass-fuzz-local-cse-try-table-unreachable-boundary-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: focused LCSE tests passed (`24/24`); `moon info` hit the known Moon internal panic (`index out of bounds: the len is 36 but the index is 8329485`); `moon fmt` passed; `moon test src/passes` passed (`1570/1570`); full `moon test` passed (`4755/4755`); native build was already up to date; direct compare reached `6769` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification for those command failures: Binaryen/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up array.new_fixed generative-root coverage on 2026-06-04

A later focused LCSE hardening slice added durable direct coverage for repeated `array.new_fixed` roots. Binaryen kept both `array.new_fixed` roots in the WAT spot check and introduced no `local.tee`; the landed Starshine regression is a core-built module fixture. The fixture passed without implementation changes. Agent classification: missing coverage only, not a functional gap.

Validation for this `array.new_fixed` slice:

```sh
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass local-cse \
  --out-dir .tmp/pass-fuzz-local-cse-array-new-fixed-generative-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: focused LCSE tests passed (`25/25`); `moon info` hit the known Moon internal panic (`index out of bounds: the len is 36 but the index is 8329485`); `moon fmt` passed; `moon test src/passes` passed (`1571/1571`); full `moon test` passed (`4756/4756`); native build was already up to date; direct compare reached `6771` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification for those command failures: Binaryen/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up throw-boundary negative coverage on 2026-06-04

A later focused LCSE hardening slice added durable direct coverage for a `throw` hard-control boundary. Binaryen keeps a repeated expression before `throw` separate from the same expression in the unreachable continuation, and introduces no `local.tee`. The Starshine fixture passed without implementation changes. Agent classification: missing coverage only, not a functional gap.

Validation for this throw-boundary slice:

```sh
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass local-cse \
  --out-dir .tmp/pass-fuzz-local-cse-throw-boundary-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: focused LCSE tests passed (`26/26`); `moon info` hit the known Moon internal panic (`index out of bounds: the len is 36 but the index is 8329485`); `moon fmt` passed; `moon test src/passes` passed (`1572/1572`); full `moon test` passed (`4757/4757`); native build was already up to date; direct compare reached `6769` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification for those command failures: Binaryen/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up br-boundary negative coverage on 2026-06-04

A later focused LCSE hardening slice added durable direct coverage for a plain `br` hard-control boundary. Binaryen keeps a repeated expression before `br` separate from the same expression in the unreachable continuation, and introduces no `local.tee`. The Starshine fixture passed without implementation changes. Agent classification: missing coverage only, not a functional gap.

During slice selection, side probes for `return_call_indirect` and `throw_ref` showed Binaryen-positive unreachable-continuation reuse shapes: Binaryen materialized the pre-terminator expression and reused it after those operand-taking terminators. Those are not classified as hard-boundary negatives and remain separate implementation follow-ups rather than being forced into this `br` coverage slice.

Validation for this `br`-boundary slice:

```sh
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass local-cse \
  --out-dir .tmp/pass-fuzz-local-cse-br-boundary-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: focused LCSE tests passed (`27/27`); `moon info` hit the known Moon internal panic (`index out of bounds: the len is 36 but the index is 8329485`); `moon fmt` passed; `moon test src/passes` passed (`1573/1573`); full `moon test` passed (`4758/4758`); native build was already up to date; direct compare reached `6770` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification for those command failures: Binaryen/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up `return_call_indirect` continuation positive fix on 2026-06-04

A later focused LCSE hardening slice converted the side-probed `return_call_indirect` shape from an open risk into a test-first parity fix. Binaryen's spot check for the handoff WAT materialized the pre-tail-call `i32.add` with `local.tee` and reused it in the unreachable continuation after `return_call_indirect`. The new `local-cse reuses expression across return-call-indirect continuation` fixture first failed (`27/28`) because Starshine treated the tail call as an unknown hard boundary and left the repeated arithmetic trees separate. The raw/module path now carries module subtype information into operand counting and models `return_call_indirect` as consuming the callee parameters plus table index without producing a reusable root. This preserves the active expression window for Binaryen's unreachable-continuation reuse while still leaving repeated `call_indirect` roots unmaterialized.

Validation for this `return_call_indirect` continuation slice:

```sh
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass local-cse \
  --out-dir .tmp/pass-fuzz-local-cse-return-call-indirect-continuation-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: focused LCSE test first failed (`27/28` before the implementation), then passed after the implementation (`28/28`); `moon info` still hit the known Moon internal panic (`index out of bounds: the len is 36 but the index is 8329485`); `moon fmt` passed; `moon test src/passes` passed (`1574/1574`); full `moon test` passed (`4759/4759`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; direct compare reached `6765` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification for those command failures: Binaryen/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index`).

Agent classification: Binaryen-positive missed optimization parity fix, not arbitrary indirect-call CSE; the paired repeated-`call_indirect` root negative remains in place.

## Follow-up `throw_ref` continuation positive fix on 2026-06-04

A later focused LCSE hardening slice converted the side-probed `throw_ref` shape from an open risk into a test-first parity fix. Binaryen's spot check for the handoff WAT materialized the pre-`throw_ref` `i32.add` with `local.tee` and reused it in the unreachable continuation after `throw_ref`. The new `local-cse reuses expression across throw-ref continuation` fixture first failed (`28/29`) because Starshine treated `throw_ref` as an unknown hard boundary and left the repeated arithmetic trees separate. The raw/module path now models `throw_ref` as a one-operand terminator with no result. This preserves the active expression window for Binaryen's unreachable-continuation reuse while keeping plain `throw` and throwing/generative roots conservative.

Validation for this `throw_ref` continuation slice:

```sh
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass local-cse \
  --out-dir .tmp/pass-fuzz-local-cse-throw-ref-continuation-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: focused LCSE test first failed (`28/29` before the implementation), then passed after the implementation (`29/29`); `moon info` still hit the known Moon internal panic (`index out of bounds: the len is 36 but the index is 8329485`); `moon fmt` passed; `moon test src/passes` passed (`1575/1575`); full `moon test` passed (`4760/4760`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; direct compare reached `6768` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification for those command failures: Binaryen/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index`).

Agent classification: Binaryen-positive missed optimization parity fix, not arbitrary EH/throwing-root CSE; the paired plain-`throw` boundary negative remains in place.

## Follow-up `return_call_ref` continuation positive fix on 2026-06-04

A later focused LCSE hardening slice spot-checked `return_call_ref` as the paired reference-tail-call variant after the `return_call_indirect` and `throw_ref` positives. Binaryen's WAT spot check materialized the pre-`return_call_ref` `i32.add` with `local.tee` and reused it in the unreachable continuation after `return_call_ref`. An initial Starshine WAT-form fixture failed in the local WAT path, so the landed regression is a core-built module fixture using `ref.func` plus `Instruction::return_call_ref`. That fixture first failed (`29/30`) because Starshine treated `return_call_ref` as an unknown hard boundary and did not model `ref.func` as a stack value. The raw/module path now models `return_call_ref` operands from module subtypes and gives `ref.func` its `funcref` result type. This preserves Binaryen's unreachable-continuation reuse while keeping repeated `call_ref` roots unmaterialized.

Validation for this `return_call_ref` continuation slice:

```sh
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass local-cse \
  --out-dir .tmp/pass-fuzz-local-cse-return-call-ref-continuation-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the initial WAT-form fixture failed in local parsing/modeling; the core-built fixture then failed (`29/30` before the implementation) and passed after the implementation (`30/30`). `moon info` still hit the known Moon internal panic (`index out of bounds: the len is 36 but the index is 8329485`); `moon fmt` passed; `moon test src/passes` passed (`1576/1576`); full `moon test` passed (`4761/4761`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; direct compare reached `6771` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification for those command failures: Binaryen/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index`).

Agent classification: Binaryen-positive missed optimization parity fix, not arbitrary reference-call CSE; the paired repeated-`call_ref` root negative remains in place.

## Follow-up `array.new_data` generative-root coverage on 2026-06-04

A later focused LCSE hardening slice spot-checked repeated `array.new_data` roots with Binaryen and confirmed the allocation roots remain separate: Binaryen keeps both `array.new_data` instructions and does not introduce a `local.tee`. Starshine added a core-built direct regression, `local-cse does not reuse repeated array-new-data roots`, with a passive data segment and a packed `i8` array type. The test passed without implementation changes, so this was missing coverage only rather than a functional gap.

Validation evidence for this slice:

```sh
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-array-new-data-generative-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed (`31/31`); `moon test src/passes` passed (`1577/1577`); full `moon test` passed (`4762/4762`); native build reported no work; compare reached `6767` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures.

## Follow-up `array.new_elem` generative-root coverage on 2026-06-04

A later focused LCSE hardening slice spot-checked repeated `array.new_elem` roots with Binaryen and confirmed the allocation roots remain separate: Binaryen keeps both `array.new_elem` instructions and does not introduce a `local.tee`. Starshine added a core-built direct regression, `local-cse does not reuse repeated array-new-elem roots`, with a passive funcref element segment and a funcref array type. The test passed without implementation changes, so this was missing coverage only rather than a functional gap.

Validation evidence for this slice:

```sh
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-array-new-elem-generative-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed (`32/32`); `moon test src/passes` passed (`1578/1578`); full `moon test` passed (`4763/4763`); native build reported no work; compare reached `6763` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures.

## Follow-up `return_call` unreachable-continuation fix on 2026-06-04

A later focused LCSE hardening slice spot-checked the direct tail-call terminator and confirmed it behaves like the previously fixed indirect/reference variants: Binaryen materializes a repeated expression before `return_call` with `local.tee` and reuses it in the unreachable continuation. Starshine added the failing direct regression `local-cse reuses expression across return-call continuation`, then fixed the raw/module path by modeling direct `return_call` as consuming the callee's parameter operands. This stays narrower than arbitrary direct-call CSE: ordinary repeated direct-call roots remain non-reusable unless the callee has the existing explicit idempotent annotation.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-return-call-continuation-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run failed as intended (`32/33` passed) before the implementation change; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`33/33`); `moon test src/passes` passed (`1579/1579`); full `moon test` passed (`4764/4764`); native build succeeded with the existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6766` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures.

## Follow-up `rethrow` hard-boundary deferral on 2026-06-04

A later focused LCSE hardening slice spot-checked Binaryen's legacy `rethrow` continuation behavior. In a reduced catch-body shape, Binaryen treats `rethrow 0` as a hard EH boundary: it keeps the pre-`rethrow` and unreachable-continuation `i32.add` trees separate and emits no `local.tee`.

Starshine cannot add an equivalent direct raw/module LCSE fixture today without broadening scope: the WAST layer parses legacy `rethrow`, but `src/wast/lower_to_lib.mbt` lowers valid legacy `rethrow` to `@lib.Instruction::unreachable_()`, while `src/lib/types.mbt` has no `@lib.Instruction::Rethrow` variant for the raw module pass to model. The existing top-level `unreachable` LCSE boundary test covers the current lowered local behavior, but not Binaryen's distinct legacy EH opcode. Agent classification: documented deferral, not an implementation gap in the available raw/module LCSE surface.

Validation evidence for this documentation-only slice:

```sh
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-rethrow-deferral-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed (`33/33`); `moon test src/passes` passed (`1579/1579`); full `moon test` passed (`4764/4764`); native build reported no work; compare reached `6770` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up `br_on_null` continuation positive fix on 2026-06-04

A later focused LCSE hardening slice spot-checked a `br_on_null` fallthrough-continuation shape. Binaryen materialized the repeated arithmetic expression before `br_on_null` with `local.tee` and reused it after the `br_on_null` fallthrough value was dropped. Starshine added the failing core-built direct regression `local-cse reuses expression across br-on-null continuation`, then fixed the raw/module stack model by treating `br_on_null` as a one-operand passthrough for fallthrough stack continuity rather than as a reusable root or hard boundary.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-br-on-null-continuation-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run failed as intended (`33/34` passed) before the implementation change; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`34/34`); `moon test src/passes` passed (`1580/1580`); full `moon test` passed (`4765/4765`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6764` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up `struct.set` local-only effect slice on 2026-06-04

A later focused LCSE hardening slice spot-checked a GC write between two local-only arithmetic trees. Binaryen materialized the pre-`struct.set` `i32.add` with `local.tee` and reused it after the `struct.set`, showing that a GC field write does not by itself invalidate a whole tree that only reads locals. Starshine added the failing core-built direct regression `local-cse reuses local-only expression across struct-set`, then fixed the raw/module operand model by treating `struct.set` as a two-operand, no-result instruction rather than an unknown hard boundary. This does not make `struct.set` roots reusable and does not implement arbitrary heap/GVN reasoning.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-struct-set-local-only-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run failed as intended (`34/35` passed) before the implementation change; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`35/35`); `moon test src/passes` passed (`1581/1581`); full `moon test` passed (`4766/4766`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6769` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up `br_on_non_null` continuation positive fix on 2026-06-04

A later focused LCSE hardening slice spot-checked a `br_on_non_null` fallthrough-continuation shape. Binaryen materialized the repeated arithmetic expression before `br_on_non_null` with `local.tee` and reused it in the null fallthrough continuation before the block's `ref.null` result. Starshine added the failing core-built direct regression `local-cse reuses expression across br-on-non-null continuation`, then fixed the raw/module stack model by treating `br_on_non_null` as a one-operand, no-result fallthrough operation. This mirrors the `br_on_null` continuation finding without making branch-control roots reusable.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-br-on-non-null-continuation-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first compileable focused run failed as intended (`35/36` passed) before the implementation change; an earlier attempt failed to compile because the fixture used a nonexistent `HeapType::extern_()` helper and was corrected to `HeapType::abs(AbsHeapType::extern_())`; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`36/36`); `moon test src/passes` passed (`1582/1582`); full `moon test` passed (`4767/4767`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6766` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up `array.set` local-only effect slice on 2026-06-04

A later focused LCSE hardening slice spot-checked an `array.set` between two local-only arithmetic trees. Binaryen materialized the pre-`array.set` `i32.add` with `local.tee` and reused it after the `array.set`, matching the earlier `struct.set` effect-invalidation shape for a local-only repeated tree. Starshine added the failing core-built direct regression `local-cse reuses local-only expression across array-set`, then fixed the raw/module operand model by treating `array.set` as a three-operand, no-result instruction rather than an unknown hard boundary. This does not make `array.set` roots reusable and does not implement arbitrary heap/GVN reasoning.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-array-set-local-only-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run failed as intended (`36/37` passed) before the implementation change; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`37/37`); `moon test src/passes` passed (`1583/1583`); full `moon test` passed (`4768/4768`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6768` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up `array.fill` local-only effect slice on 2026-06-04

A later focused LCSE hardening slice spot-checked an `array.fill` between two local-only arithmetic trees. Binaryen materialized the pre-`array.fill` `i32.add` with `local.tee` and reused it after the fill, matching the earlier GC write effect-invalidation shapes for local-only repeated trees. Starshine added the failing core-built direct regression `local-cse reuses local-only expression across array-fill`, then fixed the raw/module operand model by treating `array.fill` as a four-operand, no-result instruction rather than an unknown hard boundary. This does not make `array.fill` roots reusable and does not implement arbitrary heap/GVN reasoning.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-array-fill-local-only-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run failed as intended (`37/38` passed) before the implementation change; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`38/38`); `moon test src/passes` passed (`1584/1584`); full `moon test` passed (`4769/4769`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6770` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up `br_on_cast` continuation positive fix on 2026-06-04

A later focused LCSE hardening slice spot-checked a `br_on_cast` fallthrough-continuation shape. Binaryen materialized the repeated arithmetic expression before `br_on_cast` with `local.tee` and reused it after dropping the cast-fail fallthrough reference. Starshine first tried a WAT-form direct fixture, but the local test parser could not safely represent that syntax; the slice then added the failing core-built direct regression `local-cse reuses expression across br-on-cast continuation` and fixed the raw/module stack model by treating `br_on_cast` as a one-operand reference-control operation whose fallthrough stack value remains available. This does not make branch-control roots reusable and does not implement CFG-wide GVN.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-br-on-cast-continuation-only-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the initial WAT-form focused run failed in local fixture parsing; after switching to a core-built fixture, the first compileable focused run failed as intended (`38/39` passed) before the implementation change. `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`39/39`); `moon test src/passes` passed (`1587/1587`); full `moon test` passed (`4772/4772`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6769` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up `br_on_cast_fail` continuation positive fix on 2026-06-04

A later focused LCSE hardening slice spot-checked a `br_on_cast_fail` fallthrough-continuation shape. Binaryen materialized the repeated arithmetic expression before `br_on_cast_fail` with `local.tee` and reused it after dropping the cast-success fallthrough reference. Starshine added the failing core-built direct regression `local-cse reuses expression across br-on-cast-fail continuation`, then fixed the raw/module stack model by treating `br_on_cast_fail` as a one-operand reference-control operation whose fallthrough stack value remains available. This is separate from the earlier `br_on_cast` slice and still does not make branch-control roots reusable or add CFG-wide GVN.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-br-on-cast-fail-continuation-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run failed as intended (`39/40` passed) before the implementation change; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`40/40`); `moon test src/passes` passed (`1588/1588`); full `moon test` passed (`4773/4773`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6766` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up `array.copy` local-only effect slice on 2026-06-04

A later focused LCSE hardening slice spot-checked an `array.copy` between two local-only arithmetic trees. Binaryen materialized the pre-`array.copy` `i32.add` with `local.tee` and reused it after the copy, matching the earlier GC write effect-invalidation shapes for local-only repeated trees. Starshine added the failing core-built direct regression `local-cse reuses local-only expression across array-copy`, then fixed the raw/module operand model by treating `array.copy` as a five-operand, no-result instruction rather than an unknown hard boundary. This does not make `array.copy` roots reusable and does not implement arbitrary heap/GVN reasoning.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-array-copy-local-only-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run failed as intended (`40/41` passed) before the implementation change; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`41/41`); `moon test src/passes` passed (`1589/1589`); full `moon test` passed (`4774/4774`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6770` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up `array.init_data` local-only effect slice on 2026-06-04

A later focused LCSE hardening slice spot-checked an `array.init_data` between two local-only arithmetic trees. Binaryen materialized the pre-`array.init_data` `i32.add` with `local.tee` and reused it after the GC array/data initialization. Starshine added the failing core-built direct regression `local-cse reuses local-only expression across array-init-data`, then fixed the raw/module operand model by treating `array.init_data` as a four-operand, no-result instruction rather than an unknown hard boundary. This does not make `array.init_data` roots reusable and does not implement arbitrary heap/GVN reasoning.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-array-init-data-local-only-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run failed as intended (`41/42` passed) before the implementation change; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`42/42`); `moon test src/passes` passed (`1590/1590`); full `moon test` passed (`4775/4775`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6769` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up `array.init_elem` local-only effect slice on 2026-06-04

A later focused LCSE hardening slice spot-checked an `array.init_elem` between two local-only arithmetic trees. Binaryen materialized the pre-`array.init_elem` `i32.add` with `local.tee` and reused it after the GC array/element initialization. Starshine added the failing core-built direct regression `local-cse reuses local-only expression across array-init-elem`, then fixed the raw/module operand model by treating `array.init_elem` as a four-operand, no-result instruction rather than an unknown hard boundary. This does not make `array.init_elem` roots reusable and does not implement arbitrary heap/GVN reasoning.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-array-init-elem-local-only-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run failed as intended (`42/43` passed) before the implementation change; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`43/43`); `moon test src/passes` passed (`1591/1591`); full `moon test` passed (`4776/4776`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6769` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up `memory.copy` local-only effect slice on 2026-06-04

A later focused LCSE hardening slice spot-checked a `memory.copy` between two local-only arithmetic trees. Binaryen materialized the pre-`memory.copy` `i32.add` with `local.tee` and reused it after the linear bulk-memory copy. Starshine added the failing WAT-form direct regression `local-cse reuses local-only expression across memory-copy`, then fixed the raw/module operand model by treating `memory.copy` as a three-operand, no-result instruction rather than an unknown hard boundary. This does not make `memory.copy` roots reusable and does not implement arbitrary memory/GVN reasoning.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-memory-copy-local-only-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run failed as intended (`43/44` passed) before the implementation change; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`44/44`); `moon test src/passes` passed (`1592/1592`); full `moon test` passed (`4777/4777`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6762` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up `memory.fill` local-only effect slice on 2026-06-04

A later focused LCSE hardening slice spot-checked a `memory.fill` between two local-only arithmetic trees. Binaryen materialized the pre-`memory.fill` `i32.add` with `local.tee` and reused it after the linear memory fill. Starshine added the failing WAT-form direct regression `local-cse reuses local-only expression across memory-fill`, then fixed the raw/module operand model by treating `memory.fill` as a three-operand, no-result instruction rather than an unknown hard boundary. This does not make `memory.fill` roots reusable and does not implement arbitrary memory/GVN reasoning.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-memory-fill-local-only-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run failed as intended (`44/45` passed) before the implementation change; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`45/45`); `moon test src/passes` passed (`1593/1593`); full `moon test` passed (`4778/4778`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6769` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up `memory.init` local-only effect slice on 2026-06-04

A later focused LCSE hardening slice spot-checked a `memory.init` between two local-only arithmetic trees. Binaryen materialized the pre-`memory.init` `i32.add` with `local.tee` and reused it after the data-to-memory initialization. Starshine added the failing WAT-form direct regression `local-cse reuses local-only expression across memory-init`, then fixed the raw/module operand model by treating `memory.init` as a three-operand, no-result instruction rather than an unknown hard boundary. This does not make `memory.init` roots reusable and does not implement arbitrary memory/GVN reasoning.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-memory-init-local-only-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run failed as intended (`45/46` passed) before the implementation change; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`46/46`); `moon test src/passes` passed (`1594/1594`); full `moon test` passed (`4779/4779`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6769` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up `table.copy` local-only effect slice on 2026-06-04

A later focused LCSE hardening slice spot-checked a `table.copy` between two local-only arithmetic trees. Binaryen materialized the pre-`table.copy` `i32.add` with `local.tee` and reused it after the table bulk copy. Starshine added the failing WAT-form direct regression `local-cse reuses local-only expression across table-copy`, then fixed the raw/module operand model by treating `table.copy` as a three-operand, no-result instruction rather than an unknown hard boundary. This does not make `table.copy` roots reusable and does not implement arbitrary table/GVN reasoning.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-table-copy-local-only-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run failed as intended (`46/47` passed) before the implementation change; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`47/47`); `moon test src/passes` passed (`1595/1595`); full `moon test` passed (`4780/4780`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6771` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up `table.fill` local-only effect slice on 2026-06-04

A later focused LCSE hardening slice spot-checked a `table.fill` between two local-only arithmetic trees. Binaryen materialized the pre-`table.fill` `i32.add` with `local.tee` and reused it after the table fill. Starshine added the failing WAT-form direct regression `local-cse reuses local-only expression across table-fill`, then fixed the raw/module operand model by treating `table.fill` as a three-operand, no-result instruction rather than an unknown hard boundary. This does not make `table.fill` roots reusable and does not implement arbitrary table/GVN reasoning.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-table-fill-local-only-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run failed as intended (`47/48` passed) before the implementation change; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`48/48`); `moon test src/passes` passed (`1596/1596`); full `moon test` passed (`4781/4781`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6766` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up `table.init` local-only effect slice on 2026-06-04

A later focused LCSE hardening slice spot-checked a `table.init` between two local-only arithmetic trees. Binaryen materialized the pre-`table.init` `i32.add` with `local.tee` and reused it after the element-to-table initialization. Starshine added the failing WAT-form direct regression `local-cse reuses local-only expression across table-init`, then fixed the raw/module operand model by treating `table.init` as a three-operand, no-result instruction rather than an unknown hard boundary. This does not make `table.init` roots reusable and does not implement arbitrary table/GVN reasoning.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-table-init-local-only-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run failed as intended (`48/49` passed) before the implementation change; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`49/49`); `moon test src/passes` passed (`1597/1597`); full `moon test` passed (`4782/4782`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6764` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up `data.drop` local-only effect slice on 2026-06-04

A later focused LCSE hardening slice spot-checked a `data.drop` between two local-only arithmetic trees. Binaryen materialized the pre-`data.drop` `i32.add` with `local.tee` and reused it after the data segment drop. Starshine added the failing WAT-form direct regression `local-cse reuses local-only expression across data-drop`, then fixed the raw/module operand model by treating `data.drop` as a zero-operand, no-result side-effecting instruction rather than an unknown hard boundary. This does not make `data.drop` roots reusable and does not implement arbitrary memory, table, or segment GVN reasoning.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-data-drop-local-only-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run failed as intended (`49/50` passed) before the implementation change; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`50/50`); `moon test src/passes` passed (`1598/1598`); full `moon test` passed (`4783/4783`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6768` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up `elem.drop` local-only effect slice on 2026-06-04

A later focused LCSE hardening slice spot-checked an `elem.drop` between two local-only arithmetic trees. Binaryen materialized the pre-`elem.drop` `i32.add` with `local.tee` and reused it after the element segment drop. Starshine added the failing WAT-form direct regression `local-cse reuses local-only expression across elem-drop`, then fixed the raw/module operand model by treating `elem.drop` as a zero-operand, no-result side-effecting instruction rather than an unknown hard boundary. This does not make `elem.drop` roots reusable and does not implement arbitrary table or segment GVN reasoning.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-elem-drop-local-only-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run failed as intended (`50/51` passed) before the implementation change; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`51/51`); `moon test src/passes` passed (`1599/1599`); full `moon test` passed (`4784/4784`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6765` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up `table.set` local-only effect slice on 2026-06-04

A later focused LCSE hardening slice spot-checked a `table.set` between two local-only arithmetic trees. Binaryen materialized the pre-`table.set` `i32.add` with `local.tee` and reused it after the table element write. Starshine added the failing WAT-form direct regression `local-cse reuses local-only expression across table-set`, then fixed the raw/module operand model by treating `table.set` as a two-operand, no-result table write rather than an unknown hard boundary. This does not make `table.set` roots reusable and does not implement arbitrary table GVN reasoning.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-table-set-local-only-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run failed as intended (`51/52` passed) before the implementation change; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`52/52`); `moon test src/passes` passed (`1600/1600`); full `moon test` passed (`4785/4785`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6766` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up `table.grow` local-only effect slice on 2026-06-04

A later focused LCSE hardening slice spot-checked a `table.grow` between two local-only arithmetic trees. Binaryen materialized the pre-`table.grow` `i32.add` with `local.tee` and reused it after the table growth operation. Starshine added the failing WAT-form direct regression `local-cse reuses local-only expression across table-grow`, then fixed the raw/module operand model by treating `table.grow` as a two-operand, `i32`-result side-effecting table operation rather than an unknown hard boundary. The slice also added `local-cse does not reuse repeated table-grow roots` so the new stack-result modeling cannot become arbitrary `table.grow` CSE. This does not implement arbitrary table GVN reasoning.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-table-grow-local-only-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run failed as intended (`52/53` passed) before the implementation change; the later no-reuse root guard is coverage-only and passed after the implementation; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`54/54`); `moon test src/passes` passed (`1602/1602`); full `moon test` passed (`4787/4787`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6767` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up `global.set` local-only effect slice on 2026-06-04

A later focused LCSE hardening slice spot-checked a `global.set` between two local-only arithmetic trees. Binaryen materialized the pre-`global.set` `i32.add` with `local.tee` and reused it after the global write. Starshine already matched this local-only shape through existing `global.set` operand modeling, so the slice was missing-test-only: it added the WAT-form direct regression `local-cse reuses local-only expression across global-set`. The same slice added `local-cse does not reuse global-dependent expression across global-set`, matching Binaryen's no-reuse behavior for expressions that read the mutated global and documenting that this is not arbitrary global GVN.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-global-set-local-only-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run was coverage-only and already passed (`56/56`), so no implementation change was required; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed (`56/56`); `moon test src/passes` passed (`1604/1604`); full `moon test` passed (`4789/4789`); native build was already up to date and succeeded; compare reached `6768` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up `table.size` local-only effect slice on 2026-06-04

A later focused LCSE hardening slice spot-checked a `table.size` between two local-only arithmetic trees. Binaryen materialized the pre-`table.size` `i32.add` with `local.tee` and reused it after the table-size read. Starshine added the failing WAT-form direct regression `local-cse reuses local-only expression across table-size`, then fixed the raw/module operand model by treating `table.size` as a zero-operand `i32` stack-result instruction rather than an unknown hard boundary. The slice also added `local-cse does not reuse repeated table-size roots`; Starshine tracks table-size-dependent trees as non-reusable roots so this hardening does not become arbitrary table GVN.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-table-size-local-only-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run failed as intended (`57/58` passed) before the implementation change; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`58/58`); `moon test src/passes` passed (`1606/1606`); full `moon test` passed (`4791/4791`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6766` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up `memory.grow` local-only effect slice on 2026-06-04

A later focused LCSE hardening slice spot-checked a `memory.grow` between two local-only arithmetic trees. Binaryen materialized the pre-`memory.grow` `i32.add` with `local.tee` and reused it after the memory growth operation. Starshine added the failing WAT-form direct regression `local-cse reuses local-only expression across memory-grow`, then fixed the raw/module operand model by treating `memory.grow` as a one-operand, `i32`-result side-effecting memory operation rather than an unknown hard boundary. The slice also added `local-cse does not reuse memory-size expression across memory-grow`; Starshine filters memory-size-dependent active expressions when modeling `memory.grow` so this hardening does not become arbitrary memory-size GVN across growth.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-memory-grow-local-only-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run failed as intended (`59/60` passed) before the implementation change; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`60/60`); `moon test src/passes` passed (`1608/1608`); full `moon test` passed (`4793/4793`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6766` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up `memory.size` coverage slice on 2026-06-04

A later focused LCSE hardening slice spot-checked `memory.size` in two narrow forms: a local-only arithmetic tree before and after an intervening `memory.size`, and a repeated `memory.size`-dependent arithmetic root with no intervening `memory.grow`. Binaryen materialized both profitable repeated trees with `local.tee` / `local.get`. Starshine already matched both shapes through its existing zero-operand `memory.size` stack-result modeling, so this slice was missing-test-only: it added WAT-form direct regressions for local-only reuse across `memory.size` and repeated `memory.size` root reuse without intervening growth. The existing `memory.grow` negative continues to guard against reusing memory-size-dependent expressions across growth; this does not implement arbitrary memory GVN.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-memory-size-coverage-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run was coverage-only and already passed (`62/62`), so no implementation change was required; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed (`62/62`); `moon test src/passes` passed (`1610/1610`); full `moon test` passed (`4795/4795`); native build was already up to date and succeeded; compare reached `6768` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up `table.get` local-only effect slice on 2026-06-04

A later focused LCSE hardening slice spot-checked a `table.get` between two local-only arithmetic trees. Binaryen materialized the pre-`table.get` `i32.add` with `local.tee` and reused it after the table read. The same spot-check showed Binaryen can materialize repeated `table.get`-dependent roots when no table mutation intervenes, but Starshine intentionally kept this slice narrower: it reuses local-only trees across `table.get` while leaving `table.get`-dependent roots unmaterialized so the change does not become arbitrary table GVN.

Starshine added the failing WAT-form direct regression `local-cse reuses local-only expression across table-get`, then fixed the raw/module operand model by treating `table.get` as a one-operand, stack-result table-state read. The same slice added `local-cse does not reuse table-get-dependent roots`; it also models `ref.is_null` as a one-operand `i32` result so the table-dependent guard is tested in a stable WAT fixture.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-table-get-local-only-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run failed as intended (`62/64` passed) before the implementation change; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`64/64`); `moon test src/passes` passed (`1612/1612`); full `moon test` passed (`4797/4797`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6764` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).


## Follow-up table-state invalidation coverage slice on 2026-06-05

A later focused LCSE hardening slice spot-checked table-state-dependent expressions around table mutations. Binaryen did not reuse `ref.is_null(table.get 0 ...)` across `table.set`, and did not reuse `i32.add(table.size 0, const)` across `table.grow`, while still materializing an unrelated local-only arithmetic tree across those mutations in the spot-check fixtures. Starshine already matched the conservative table-state result locally because `table.get` / `table.size` dependent trees are tracked as table-state reads and are not reusable roots.

The slice added WAT-form direct regressions `local-cse does not reuse table-get-dependent roots across table-set` and `local-cse does not reuse table-size-dependent roots across table-grow`. This was missing-test-only and stays narrower than arbitrary table GVN or table alias analysis; existing local-only `table.set` / `table.grow` tests continue to cover reuse across the side-effecting table operations.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-table-state-invalidation-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run was coverage-only and already passed (`66/66`), so no implementation change was required; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed (`66/66`); `moon test src/passes` passed (`1614/1614`); full `moon test` passed (`4799/4799`); native build was already up to date and succeeded; compare reached `6770` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).


## Follow-up memory-size non-growing-effect precision slice on 2026-06-05

A later focused LCSE hardening slice spot-checked repeated `memory.size`-dependent arithmetic roots across `memory.copy`, `memory.fill`, and `memory.init`. The local Binaryen spot-check did not materialize those roots across the non-growing memory effects, even though it materializes the same repeated `memory.size` root with no intervening memory operation. Starshine already preserved the more precise size-state behavior: it filters memory-size-dependent active expressions across `memory.grow` only, while `memory.copy` / `memory.fill` / `memory.init` do not change memory size.

The slice added WAT-form direct regressions `local-cse reuses memory-size expression across memory-copy`, `local-cse reuses memory-size expression across memory-fill`, and `local-cse reuses memory-size expression across memory-init`. This was coverage-only for Starshine and is classified as semantic-safe size-state precision rather than arbitrary memory GVN: the tests reason only about `memory.size`, not memory contents, loads, aliases, or segment contents.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-memory-size-non-grow-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run was coverage-only and already passed (`69/69`), so no implementation change was required; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed (`69/69`); `moon test src/passes` passed (`1617/1617`); full `moon test` passed (`4802/4802`); native build was already up to date and succeeded; compare reached `6770` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).


## Follow-up `ref.eq` pure-reference operator slice on 2026-06-05

A later focused LCSE hardening slice spot-checked `ref.eq` with stable `(ref.null eq)` operands. Binaryen materialized both a local-only arithmetic tree across the intervening `ref.eq` and a repeated `ref.eq` root with `local.tee` / `local.get`. Starshine initially treated `ref.eq` as an unknown raw instruction, so the TDD focused run failed as intended for both new fixtures (`69/71` passed).

Starshine then modeled `RefEq` as a pure two-operand `i32` result and included it in the small candidate pre-scan. The slice stays limited to this stable pure reference comparison; it does not add allocation, `ref.cast` / trap-sensitive, descriptor, or broad GC reasoning.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-ref-eq-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run failed as intended (`69/71` passed) before the implementation change; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`71/71`); `moon test src/passes` passed (`1619/1619`); full `moon test` passed (`4804/4804`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6769` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).


## Follow-up integer comparison pure-operator slice on 2026-06-05

A later focused LCSE hardening slice spot-checked `i32.lt_s` as a representative integer ordering comparison. Binaryen materialized both a local-only arithmetic tree across the intervening comparison and a repeated `i32.lt_s` root with `local.tee` / `local.get`. Starshine initially treated integer ordering comparisons as unknown raw instructions, so the TDD focused run failed as intended for both new fixtures (`71/73` passed).

Starshine then modeled the integer ordering comparisons (`i32.lt_s/u`, `i32.gt_s/u`, `i32.le_s/u`, `i32.ge_s/u`, and the matching `i64.*` forms) as pure two-operand `i32` result operations and candidate roots. Existing `eq` / `ne` handling was unchanged. The slice is limited to core integer comparison operators and does not add CFG-wide GVN or effectful-root reuse.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-int-comparison-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run failed as intended (`71/73` passed) before the implementation change; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`73/73`); `moon test src/passes` passed (`1621/1621`); full `moon test` passed (`4806/4806`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6769` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).


## Follow-up integer bit-operator pure slice on 2026-06-05

A later focused LCSE hardening slice spot-checked `i32.clz` as a representative unary integer bit operation and `i32.and` as a representative binary integer bit operation. Binaryen materialized a local-only arithmetic tree across the intervening `i32.clz` and a repeated `i32.and` root with `local.tee` / `local.get`. Starshine initially treated these bit operations as unknown raw instructions, so the TDD focused run failed as intended for both new fixtures (`73/75` passed).

Starshine then modeled core nontrapping integer unary bit operations (`clz`, `ctz`, `popcnt`) and binary bit/shift/rotate operations (`and`, `or`, `xor`, `shl`, `shr_s/u`, `rotl`, `rotr`) for both `i32` and `i64` as pure stack-result operations and candidate roots. The slice deliberately leaves integer division/remainder and other trap-sensitive numeric conversions out of scope.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-int-bitops-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run failed as intended (`73/75` passed) before the implementation change; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`75/75`); `moon test src/passes` passed (`1623/1623`); full `moon test` passed (`4808/4808`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6770` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).


## Follow-up float pure-operator slice on 2026-06-05

A later focused LCSE hardening slice spot-checked `f32.add` as a representative float arithmetic operation and `f32.lt` as a representative float comparison. Binaryen materialized a local-only arithmetic tree across the intervening `f32.add`, a repeated `f32.add` root, and a repeated `f32.lt` root with `local.tee` / `local.get`. Starshine initially treated those float operations as unknown raw instructions, so the TDD focused run failed as intended for all three new fixtures (`75/78` passed).

Starshine then modeled core `f32` / `f64` unary arithmetic (`abs`, `neg`, `ceil`, `floor`, `trunc`, `nearest`, `sqrt`), binary arithmetic (`add`, `sub`, `mul`, `div`, `min`, `max`, `copysign`), and float comparisons as pure stack-result operations and candidate roots. This is still straight-line local CSE for pure numeric operators only; it does not add trap-sensitive conversion reasoning, memory/heap/table GVN, or CFG-wide GVN.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-float-pure-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run failed as intended (`75/78` passed) before the implementation change; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`78/78`); `moon test src/passes` passed (`1626/1626`); full `moon test` passed (`4811/4811`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6772` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up `select` root coverage slice on 2026-06-05

A later focused LCSE hardening slice spot-checked `select` in two narrow forms: a local-only arithmetic tree before and after an intervening `select`, and a repeated `select` root. Binaryen materialized both profitable repeated trees with `local.tee` / `local.get`. Starshine already matched through its existing three-operand `Select(_)` candidate/root modeling, so this slice was missing-test-only coverage.

The slice added WAT-form direct regressions `local-cse reuses local-only expression across select` and `local-cse reuses repeated select roots`. This coverage is limited to `select` as a local pure stack result; it does not add branch/control-root CSE, CFG-wide GVN, memory/table/heap value analysis, or any throwing-root behavior.

Validation evidence for this slice:

```sh
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-select-root-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the focused TDD run passed immediately (`80/80`) because Starshine already matched Binaryen's `select` materialization shape; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed (`80/80`); `moon test src/passes` passed (`1628/1628`); full `moon test` passed (`4813/4813`); native build succeeded with no work to do; compare reached `6768` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up `ref.is_null` pure-root slice on 2026-06-05

A later focused LCSE hardening slice spot-checked repeated `ref.is_null` on a `funcref` local. Binaryen materialized the repeated null-test root with `local.tee` / `local.get`. Starshine already modeled `RefIsNull` as a one-operand `i32` result for stack/effect handling, so local-only arithmetic reuse across an intervening `ref.is_null` was already safe, but the repeated-root-only fixture exposed a fast pre-scan gap: `RefIsNull` was not in `lcse_candidate_op_id`, so the function could be skipped before the raw rewrite saw the repeat.

The slice added WAT-form direct regressions `local-cse reuses local-only expression across ref-is-null` and `local-cse reuses repeated ref-is-null roots`. The first passed under the existing model; the second failed as intended before the implementation change (`81/82` passed). Starshine then added `RefIsNull` as a pure one-operand `i32` candidate root. This remains limited to null-test reuse and does not add `ref.cast`, `ref.test`, descriptor reasoning, throwing/cast roots, GC allocation CSE, or broad heap reasoning.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-ref-is-null-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run failed as intended for repeated `ref.is_null` roots (`81/82` passed) before the implementation change; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`82/82`); `moon test src/passes` passed (`1630/1630`); full `moon test` passed (`4815/4815`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6772` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up nontrapping numeric conversion slice on 2026-06-05

A later focused LCSE hardening slice spot-checked nontrapping numeric conversions: `i32.reinterpret_f32`, `f32.reinterpret_i32`, `i64.reinterpret_f64`, `f64.reinterpret_i64`, `i32.wrap_i64`, `i64.extend_i32_s`, `i64.extend_i32_u`, `f64.promote_f32`, and `f32.demote_f64`. Binaryen materialized repeated roots for these representative operations with `local.tee` / `local.get`.

The slice first added WAT-form direct regressions `local-cse reuses local-only expression across numeric reinterpret`, `local-cse reuses repeated numeric reinterpret roots`, `local-cse reuses repeated integer wrap roots`, and `local-cse reuses repeated float widen roots`. Those four failed as intended before the implementation change (`82/86` passed). Starshine then modeled those operations as pure one-operand stack-result candidate roots with the correct `i32`, `i64`, `f32`, or `f64` result type. After the implementation was green, the slice added matching focused coverage for `i64.extend_i32_s` and `f32.demote_f64` as `local-cse reuses repeated integer widen roots` and `local-cse reuses repeated float narrow roots`.

This slice deliberately stays limited to nontrapping conversions spot-checked against Binaryen. Trap-sensitive `i32.trunc_f32_s/u`, `i32.trunc_f64_s/u`, `i64.trunc_*`, and broader conversion or heap/memory/table GVN remain out of scope; saturating truncs were not added in this slice.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-numeric-conversion-final-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run failed as intended for all four initial new fixtures (`82/86` passed) before the implementation change; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the final coverage additions (`88/88`); `moon test src/passes` passed (`1636/1636`); full `moon test` passed (`4821/4821`); native build succeeded with no work to do. An intermediate compare rerun to `.tmp/pass-fuzz-local-cse-numeric-conversion-10000` failed in the generator step with a harness/tool `moon run --target native --release src/fuzz -- --emit-gen-valid-batch ...` no-return-code error; a clean rerun to `.tmp/pass-fuzz-local-cse-numeric-conversion-final-10000` reached `6764` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up sign-extension pure-root slice on 2026-06-05

A later focused LCSE hardening slice spot-checked nontrapping sign-extension operations: `i32.extend8_s`, `i32.extend16_s`, `i64.extend8_s`, `i64.extend16_s`, and `i64.extend32_s`. Binaryen materialized repeated representative roots with `local.tee` / `local.get`.

The slice added WAT-form direct regressions `local-cse reuses repeated i32 sign-extension roots` and `local-cse reuses repeated i64 sign-extension roots`. Both failed as intended before the implementation change (`88/90` passed). Starshine then modeled the sign-extension operations as pure one-operand candidate roots with `i32` or `i64` result types. This is a narrow nontrapping numeric-root slice; it does not add trap-sensitive trunc conversions, saturating truncs, SIMD conversion reasoning, or broad numeric/heap/memory/table GVN.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-sign-extension-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run failed as intended for both new fixtures (`88/90` passed) before the implementation change; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`90/90`); `moon test src/passes` passed (`1638/1638`); full `moon test` passed (`4823/4823`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6768` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up narrow-load root slice on 2026-06-05

A later focused LCSE hardening slice spot-checked narrow integer loads: representative `i32.load8_u`, `i32.load16_s`, `i64.load8_u`, `i64.load16_s`, and `i64.load32_u` roots. Binaryen materialized repeated representative roots with `local.tee` / `local.get` when no intervening memory write invalidated the loaded memory.

Starshine already treated narrow loads as one-operand memory reads with `i32` / `i64` result types, so store invalidation and stack modeling were in place. The missing piece was the fast candidate pre-scan: only full-width loads were candidates, so functions containing only repeated narrow-load roots could be skipped before the raw rewrite saw them. The slice added WAT-form direct regressions `local-cse reuses repeated i32 narrow load roots` and `local-cse reuses repeated i64 narrow load roots`; both failed as intended before the implementation change (`90/92` passed). Starshine then added the narrow integer load instructions to `lcse_candidate_op_id`.

This remains ordinary local load CSE with existing store barriers. It does not add arbitrary memory alias analysis, heap/table GVN, segment reasoning, or reuse across memory writes.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-narrow-loads-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run failed as intended for both new fixtures (`90/92` passed) before the implementation change; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`92/92`); `moon test src/passes` passed (`1640/1640`); full `moon test` passed (`4825/4825`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6770` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up saturating-trunc pure-root slice on 2026-06-05

A later focused LCSE hardening slice spot-checked nontrapping saturating trunc conversions: representative `i32.trunc_sat_f32_s`, `i32.trunc_sat_f64_u`, `i64.trunc_sat_f32_s`, and `i64.trunc_sat_f64_u` roots. Binaryen materialized repeated representative roots with `local.tee` / `local.get`.

The slice added WAT-form direct regressions `local-cse reuses repeated i32 saturating trunc roots` and `local-cse reuses repeated i64 saturating trunc roots`. Both failed as intended before the implementation change (`92/94` passed). Starshine then modeled all eight `i32.trunc_sat_*` / `i64.trunc_sat_*` operations as pure one-operand candidate roots with `i32` or `i64` result types and widened the LCSE candidate pre-scan bitset to fit the expanded candidate id space.

This slice deliberately covers only saturating trunc conversions, which do not trap. The trap-sensitive `i32.trunc_f32_s/u`, `i32.trunc_f64_s/u`, `i64.trunc_*`, arbitrary conversion reasoning, SIMD conversions, and broad heap/memory/table GVN remain out of scope.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-trunc-sat-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first focused run failed as intended for both new fixtures (`92/94` passed) before the implementation change; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed after the fix (`94/94`); `moon test src/passes` passed (`1642/1642`); full `moon test` passed (`4827/4827`); native build succeeded with existing unused-function warnings in `src/passes/pass_manager.mbt`; compare reached `6769` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).


## Follow-up integer equality and eqz coverage slice on 2026-06-05

A later focused LCSE hardening slice spot-checked repeated integer equality and zero-test roots: representative `i32.eq`, `i64.ne`, and `i64.eqz` roots. Binaryen materialized these repeated roots with `local.tee` / `local.get`.

The slice added WAT-form direct tests `local-cse reuses repeated integer equality roots`, `local-cse reuses local-only expression across integer eqz`, and `local-cse reuses repeated integer eqz roots`. Starshine already matched via existing `I32Eq`, `I32Ne`, `I64Eq`, `I64Ne`, `I32Eqz`, and `I64Eqz` candidate/result modeling, so this was missing-test-only coverage rather than an implementation change. It does not add integer division/remainder CSE, trap-sensitive trunc conversion reasoning, or broad numeric GVN.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-eq-eqz-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the initial focused run with the added coverage passed (`97/97`) because this was missing-test-only; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed (`97/97`); `moon test src/passes` passed (`1645/1645`); full `moon test` passed (`4830/4830`); native build succeeded with no work to do; compare reached `6772` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).


## Follow-up full-width non-i32 load coverage slice on 2026-06-05

A later focused LCSE hardening slice spot-checked repeated full-width non-`i32` load roots: representative `i64.load`, `f32.load`, and `f64.load` roots. Binaryen materialized each repeated root with `local.tee` / `local.get` when no intervening memory write invalidated linear memory.

The slice added WAT-form direct tests `local-cse reuses local-only expression across full-width non-i32 load`, `local-cse reuses repeated i64 full-width load roots`, and `local-cse reuses repeated float full-width load roots`. Starshine already matched via existing full-width load candidate pre-scan entries plus memory-read and result-type modeling, so this was missing-test-only coverage. An initial combined fixture exceeded the raw LCSE 16-instruction window and was replaced with smaller coherent fixtures rather than changing the implementation. This remains local load CSE under existing store barriers; it does not add arbitrary memory alias analysis, segment reasoning, or memory GVN.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-full-width-loads-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the initial focused run with the final split coverage passed (`100/100`) because this was missing-test-only; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed (`100/100`); `moon test src/passes` passed (`1648/1648`); full `moon test` passed (`4833/4833`); native build succeeded with no work to do; compare reached `6770` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).


## Follow-up float equality coverage slice on 2026-06-05

A later focused LCSE hardening slice spot-checked float equality/inequality roots: representative `f32.eq` and `f64.ne` roots. Binaryen materialized repeated roots with `local.tee` / `local.get`.

The slice added WAT-form direct tests `local-cse reuses local-only expression across float equality` and `local-cse reuses repeated float equality roots`. Starshine already matched via existing float-comparison candidate/result modeling, so this was missing-test-only coverage rather than an implementation change. This remains the core nontrapping float comparison surface; it does not add trap-sensitive numeric conversions or broad numeric GVN.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-float-equality-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the initial focused run with the added coverage passed (`102/102`) because this was missing-test-only; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed (`102/102`); `moon test src/passes` passed (`1650/1650`); full `moon test` passed (`4835/4835`); native build succeeded with no work to do; compare reached `6768` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).


## Follow-up integer division/remainder deferral slice on 2026-06-05

A later focused LCSE hardening slice spot-checked trap-sensitive integer division/remainder roots: representative `i32.div_s` and `i64.rem_u` roots. Binaryen materialized repeated roots with `local.tee` / `local.get`.

This slice deliberately did not implement integer division or remainder CSE. Even though repeated adjacent roots can be semantically safe under a carefully specified trap-order argument, the user intent for this audit explicitly kept division/remainder-style trap-sensitive broadening out of scope. The slice added direct boundary tests `local-cse defers repeated integer division roots` and `local-cse defers repeated integer remainder roots`, which document Starshine's current conservative no-CSE behavior. This is a documented deferral, not arbitrary numeric GVN, and it stays paired with the existing trap-sensitive trunc-conversion exclusion.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-div-rem-deferral-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the initial focused run with the deferral tests passed (`104/104`) because Starshine already intentionally leaves these roots unmaterialized; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed (`104/104`); `moon test src/passes` passed (`1652/1652`); full `moon test` passed (`4837/4837`); native build succeeded with no work to do; compare reached `6769` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index). The observed Binaryen materialization for div/rem remains classified as an intentionally deferred optimization opportunity, not a Starshine semantic failure.


## Follow-up ref.test deferral slice on 2026-06-05

A later focused LCSE hardening slice spot-checked repeated standard `ref.test` roots with a local GC reference operand. Binaryen materialized the repeated root with `local.tee` / `local.get`.

This slice deliberately did not implement `ref.test` root CSE. The audit intent kept cast/trap/descriptor reasoning and arbitrary heap reasoning out of scope, and the local WAT parser surface is descriptor-oriented while the standard `ref.test` fixture is safest as a core-built module. The slice added the core-built boundary test `local-cse defers repeated ref-test roots`, documenting Starshine's current conservative no-CSE behavior. This does not add `ref.cast`, descriptor `ref.test_desc` / `ref.cast_desc_eq`, GC allocation CSE, or heap/GVN reasoning.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-ref-test-deferral-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the initial focused run with the deferral test passed (`105/105`) because Starshine already intentionally leaves this root unmaterialized; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed (`105/105`); `moon test src/passes` passed (`1653/1653`); full `moon test` passed (`4838/4838`); native build succeeded with no work to do; compare reached `6768` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index). The observed Binaryen materialization for `ref.test` remains classified as an intentionally deferred optimization opportunity, not a Starshine semantic failure.

## Follow-up trap-sensitive trunc-conversion deferral slice on 2026-06-05

A later focused LCSE hardening slice spot-checked trap-sensitive scalar trunc conversions with representative `i32.trunc_f32_s` and `i64.trunc_f64_u` roots. Binaryen materialized repeated roots with `local.tee` / `local.get` in the spot-check fixture under `.tmp/local-cse-trap-trunc/`.

This slice deliberately did not implement trapping trunc-conversion CSE. It added direct boundary tests `local-cse defers repeated i32 trapping trunc roots` and `local-cse defers repeated i64 trapping trunc roots`, documenting Starshine's conservative no-CSE behavior for roots that can trap on NaN or out-of-range input. The already-covered saturating trunc roots remain reusable; the non-saturating `i32.trunc_*` / `i64.trunc_*` roots remain out of scope alongside integer division/remainder and cast/trap reasoning.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-trapping-trunc-deferral-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the initial focused run with the added deferral coverage passed (`107/107`) because this was documented conservative coverage; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed (`107/107`); `moon test src/passes` passed (`1655/1655`); full `moon test` passed (`4840/4840`); native build succeeded with no work to do; compare reached `6765` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up standard ref.cast deferral slice on 2026-06-05

A later focused LCSE hardening slice spot-checked a standard nullable `ref.cast` root with a representative `(ref.cast (ref null eq) ...)` fixture. Binaryen materialized the repeated root with `local.tee` / `local.get` in the spot-check fixture under `.tmp/local-cse-ref-cast/`.

This slice deliberately did not implement `ref.cast` CSE or heap/cast/trap reasoning. It added the core-built direct boundary test `local-cse defers repeated ref-cast roots`, documenting Starshine's conservative no-CSE behavior for cast roots. The existing `ref.test` deferral remains paired with this cast boundary; `br_on_cast` / `br_on_cast_fail` fallthrough-continuation operand modeling remains separate and does not make cast roots reusable.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-ref-cast-deferral-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the initial focused run with the added deferral coverage passed (`108/108`) because this was documented conservative coverage; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed (`108/108`); `moon test src/passes` passed (`1656/1656`); full `moon test` passed (`4841/4841`); native build succeeded with no work to do; compare reached `6770` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up descriptor test/cast deferral slice on 2026-06-05

A later focused LCSE hardening slice attempted to spot-check descriptor `ref.test_desc` / `ref.cast_desc_eq` roots with a WAT fixture under `.tmp/local-cse-desc/`. Both `wasm-tools parse` and the installed Binaryen `wasm-opt --all-features --local-cse` rejected the descriptor opcodes in that text fixture, so no safe Binaryen materialization claim was made for descriptor roots in this slice.

The slice added the core-built direct boundary test `local-cse defers repeated descriptor test and cast roots`, documenting Starshine's conservative no-CSE behavior for descriptor test/cast roots that the local core can represent. This is a fixture-safety deferral rather than an implementation broadening: descriptor tests/casts, descriptor heap reasoning, and cast/trap reasoning remain out of LCSE scope unless separately evaluated with a reliable oracle fixture.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-descriptor-deferral-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the initial focused run with the added deferral coverage passed (`109/109`) because this was documented conservative coverage; `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed (`109/109`); `moon test src/passes` passed (`1657/1657`); full `moon test` passed (`4842/4842`); native build succeeded with no work to do; compare reached `6769` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up SIMD pure-root deferral slice on 2026-06-05

A later focused LCSE hardening slice spot-checked small SIMD pure roots with representative `v128.not` and `i8x16.eq` roots. Binaryen materialized repeated roots with `local.tee` / `local.get` in the spot-check fixture under `.tmp/local-cse-simd/`.

This slice deliberately did not implement SIMD CSE. It added the core-built direct boundary test `local-cse defers repeated SIMD pure roots`, documenting Starshine's conservative no-CSE behavior for vector roots while the scalar numeric/reference coverage remains unchanged. The initial WAT-form local fixture was rejected by Starshine's test parser, so the landed coverage uses the core instruction surface instead of forcing brittle text support. This avoids adding broad SIMD value numbering, vector temp materialization assumptions, or SIMD load/GVN behavior during the LCSE audit.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-simd-deferral-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first WAT-form focused fixture failed (`109/110`) because Starshine's local test parser rejected the SIMD text shape; the landed core-built fixture then passed (`110/110`). `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed (`110/110`); `moon test src/passes` passed (`1658/1658`); full `moon test` passed (`4843/4843`); native build succeeded with no work to do. The first compare command failed during gen-valid batch emission (`moon run --target native --release src/fuzz ...`, no return code) and was agent-classified as a transient tool/harness command failure, not a Starshine semantic failure. The rerun compare command with out dir `.tmp/pass-fuzz-local-cse-simd-deferral-10000-rerun` reached `6768` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the compare command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up struct atomic-get boundary slice on 2026-06-05

A later focused LCSE hardening slice spot-checked local-only scalar reuse across a shared-GC `struct.atomic.get` root. Binaryen materialized the local-only `i32.add` across the representative atomic root with `local.tee` / `local.get` in the spot-check fixture under `.tmp/local-cse-atomic/`; existing Starshine atomic pass-support tests already cover repeated `struct.atomic.get` roots staying distinct.

This slice deliberately did not model atomic roots as reusable loads or add atomic/memory GVN. It added the direct WAT boundary test `local-cse defers local-only reuse across struct atomic get`, documenting Starshine's current conservative behavior around the shared-GC atomic surface. This is semantically safe but may miss a Binaryen-positive local-only reuse opportunity; recovering it would require a separate, narrow atomic operand/effect model that still keeps repeated atomic roots distinct.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-atomic-boundary-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the initial focused run with the added conservative boundary coverage passed (`111/111`); `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed (`111/111`); `moon test src/passes` passed (`1659/1659`); full `moon test` passed (`4844/4844`); native build succeeded with no work to do; compare reached `6767` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up `ref.as_non_null` deferral slice on 2026-06-05

A later focused LCSE hardening slice spot-checked repeated `ref.as_non_null` roots with an `externref` operand. Binaryen materialized the repeated root with `local.tee` / `local.get` in the spot-check fixture under `.tmp/local-cse-spot/ref_as_non_null.wat`.

This slice deliberately did not implement `ref.as_non_null` CSE or nullability trap reasoning. It added the direct WAT boundary test `local-cse defers repeated ref-as-non-null roots`, documenting Starshine's conservative no-CSE behavior for nullability trap roots. This stays paired with the existing `ref.test`, `ref.cast`, descriptor test/cast, and trap-sensitive numeric deferrals rather than adding broad cast/trap reasoning.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-ref-as-non-null-deferral-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the initial focused run with the added conservative boundary coverage passed (`112/112`); `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed (`112/112`); `moon test src/passes` passed (`1660/1660`); full `moon test` passed (`4845/4845`); native build succeeded with no work to do; compare reached `6768` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up i31 boundary slice on 2026-06-05

A later focused LCSE hardening slice spot-checked repeated `ref.i31`, `i31.get_s`, and `i31.get_u` roots. Binaryen materialized all three representative repeat families with `local.tee` / `local.get` in the spot-check fixture under `.tmp/local-cse-spot/i31.wat`.

The TDD run initially failed for both added positive fixtures (`112/114` passed). During implementation, materializing `ref.i31` with an exact non-null `(ref i31)` temp made final validation reject the optimized module because non-nullable locals have no default value. The landed slice therefore keeps `ref.i31` as a documented conservative deferral, and only models `i31.get_s` / `i31.get_u` as pure one-operand `i32` candidate roots. This is narrow i31 scalar accessor CSE, not heap, cast, allocation, or non-null temp-local reasoning.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-i31-boundary-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the initial focused run failed as intended for missing i31 coverage (`112/114`), then the landed implementation/deferral split passed focused LCSE tests (`114/114`); `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; `moon test src/passes` passed (`1662/1662`); full `moon test` passed (`4847/4847`); native build succeeded with warnings only and exit `0`; compare reached `6771` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up heap-read root deferral slice on 2026-06-05

A later focused LCSE hardening slice spot-checked repeated `struct.get` and `array.get` roots. Binaryen materialized representative repeated heap-read roots with `local.tee` / `local.get` in the spot-check fixture under `.tmp/local-cse-spot/struct_array_get.wat`.

This slice deliberately did not implement heap-read root CSE or heap GVN. The initial WAT-form Starshine fixture was not safely accepted by the local test parser, so the landed coverage uses the core instruction surface. The new `local-cse defers repeated struct and array get roots` test documents Starshine's conservative no-CSE behavior for heap reads; this is semantically safe but may miss a Binaryen-positive local opportunity that would need a separate heap-state model.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-heap-read-deferral-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the initial WAT-form focused fixture failed because the Starshine test parser rejected the text shape; the landed core-built fixture passed (`115/115`). `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed (`115/115`); `moon test src/passes` passed (`1663/1663`); full `moon test` passed (`4848/4848`); native build succeeded with no work to do; compare reached `6769` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up descriptor allocation deferral slice on 2026-06-05

A later focused LCSE hardening slice attempted to spot-check descriptor allocation roots with a descriptor-bearing `struct.new_desc` / `struct.new_default_desc` WAT fixture under `.tmp/local-cse-spot/struct_desc2.wat`. The installed Binaryen oracle asserted on the descriptor text shape (`unexpected canonical described type`), so this slice makes no Binaryen materialization claim for descriptor allocation roots.

The slice added the core-built direct boundary test `local-cse defers repeated descriptor allocation roots`, documenting Starshine's conservative no-CSE behavior for `struct.new_desc` and `struct.new_default_desc` roots. This is a fixture-safety and generative-allocation deferral: descriptor allocation roots remain distinct, and LCSE still does not add descriptor heap reasoning, allocation CSE, or broad heap/GVN.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-desc-alloc-deferral-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the initial focused run with the added conservative core-built coverage passed (`116/116`); `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed (`116/116`); `moon test src/passes` passed (`1664/1664`); full `moon test` passed (`4849/4849`); native build succeeded with no work to do; compare reached `6765` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up linear atomic boundary slice on 2026-06-05

A later focused LCSE hardening slice spot-checked local-only scalar reuse across ordinary linear-memory atomic operations with representative `i32.atomic.load` and `i32.atomic.rmw.add` roots. Binaryen materialized the local-only arithmetic value across the representative atomic operations with `local.tee` / `local.get` in the spot-check fixture under `.tmp/local-cse-spot/linear_atomic.wat`.

This slice deliberately did not model linear atomic operations as reusable loads/effects or add atomic/memory GVN. The initial WAT-form Starshine fixture was not accepted by the local test parser, so the landed coverage uses the core instruction surface. The new `local-cse defers local-only reuse across linear atomic operations` test documents Starshine's conservative no-CSE behavior around linear atomics; recovering this Binaryen-positive local-only opportunity would need a separate atomic effect model and must still keep atomic roots distinct.

Validation evidence for this slice:

```sh
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-linear-atomic-boundary-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the initial WAT-form focused fixture failed because the Starshine test parser rejected the linear atomic text shape; the landed core-built fixture passed (`117/117`). `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed (`117/117`); `moon test src/passes` passed (`1665/1665`); full `moon test` passed (`4850/4850`); native build succeeded with no work to do; compare reached `6766` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up SIMD load root boundary slice on 2026-06-05

A later focused LCSE hardening slice spot-checked repeated `v128.load` roots. Binaryen materialized the representative repeated SIMD load with `local.tee` / `local.get` in the spot-check fixture under `.tmp/lcse-next-spots/simd-load.wat`.

This slice deliberately did not implement SIMD load CSE or SIMD/memory GVN. The landed core-built direct test `local-cse defers repeated SIMD load roots` documents Starshine's conservative no-CSE behavior for `v128.load` roots while keeping this boundary separate from the earlier tiny SIMD pure-root deferral and from scalar load-root CSE. This is semantically safe but may miss a Binaryen-positive local opportunity that would need a separate vector load/memory-state model.

Validation evidence for this slice:

```sh
wasm-tools parse .tmp/lcse-next-spots/simd-load.wat -o .tmp/lcse-next-spots/simd-load.wasm
wasm-opt .tmp/lcse-next-spots/simd-load.wasm --all-features --local-cse -S -o .tmp/lcse-next-spots/simd-load.binaryen.wat
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-simd-load-boundary-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the added conservative core-built coverage passed immediately (`118/118`), so this was missing-test-only coverage for Starshine's existing conservative behavior. `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed (`118/118`); `moon test src/passes` passed (`1666/1666`); full `moon test` passed (`4851/4851`); native build succeeded with no work to do; compare reached `6767` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up SIMD lane-load root boundary slice on 2026-06-05

A later focused LCSE hardening slice spot-checked repeated `v128.load8_lane` roots. Binaryen materialized the representative repeated lane load with `local.tee` / `local.get` in the spot-check fixture under `.tmp/lcse-next-spots/simd-lane-load.wat`.

This slice deliberately did not implement SIMD lane-load CSE or SIMD/memory GVN. The landed core-built direct test `local-cse defers repeated SIMD lane-load roots` documents Starshine's conservative no-CSE behavior for `v128.load8_lane` roots while keeping this boundary separate from scalar load CSE, ordinary `v128.load`, and broad SIMD value numbering. This is semantically safe but may miss a Binaryen-positive local opportunity that would need a vector lane-load/memory-state model.

Validation evidence for this slice:

```sh
wasm-tools parse .tmp/lcse-next-spots/simd-lane-load.wat -o .tmp/lcse-next-spots/simd-lane-load.wasm
wasm-opt .tmp/lcse-next-spots/simd-lane-load.wasm --all-features --local-cse -S -o .tmp/lcse-next-spots/simd-lane-load.binaryen.wat
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-simd-lane-load-boundary-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the added conservative core-built coverage passed immediately (`119/119`), so this was missing-test-only coverage for Starshine's existing conservative behavior. `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed (`119/119`); `moon test src/passes` passed (`1667/1667`); full `moon test` passed (`4852/4852`); native build succeeded with no work to do; compare reached `6765` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up packed heap-read root deferral slice on 2026-06-05

A later focused LCSE hardening slice spot-checked repeated packed `struct.get_s`, `struct.get_u`, `array.get_s`, and `array.get_u` roots. Binaryen materialized each representative repeated packed heap read with `local.tee` / `local.get` in the spot-check fixture under `.tmp/lcse-next-spots/gc-packed-read.wat`.

This slice deliberately did not implement packed heap-read CSE or heap GVN. The landed core-built direct test `local-cse defers repeated packed struct and array get roots` documents Starshine's conservative no-CSE behavior for signed and unsigned packed heap reads while keeping this boundary separate from scalar numeric CSE and the earlier plain `struct.get` / `array.get` deferral. This is semantically safe but may miss a Binaryen-positive local opportunity that would need a heap-state model preserving null, bounds, and packed signedness semantics.

Validation evidence for this slice:

```sh
wasm-tools parse .tmp/lcse-next-spots/gc-packed-read.wat -o .tmp/lcse-next-spots/gc-packed-read.wasm
wasm-opt .tmp/lcse-next-spots/gc-packed-read.wasm --all-features --local-cse -S -o .tmp/lcse-next-spots/gc-packed-read.binaryen.wat
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-packed-heap-read-boundary-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the added conservative core-built coverage passed immediately (`120/120`), so this was missing-test-only coverage for Starshine's existing conservative behavior. `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed (`120/120`); `moon test src/passes` passed (`1669/1669`); full `moon test` passed (`4854/4854`); native build succeeded with no work to do; compare reached `6769` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up reference-conversion root deferral slice on 2026-06-05

A later focused LCSE hardening slice spot-checked repeated `any.convert_extern` and `extern.convert_any` roots. Binaryen materialized both representative repeated reference conversions with `local.tee` / `local.get` in the spot-check fixture under `.tmp/lcse-next-spots/ref-convert.wat`.

This slice deliberately did not implement reference-conversion CSE or broaden LCSE's reference/cast reasoning. The landed core-built direct test `local-cse defers repeated reference conversion roots` documents Starshine's conservative no-CSE behavior for these reference conversions while keeping the boundary separate from `ref.is_null` / `ref.eq` scalar results and from trap/nullability/cast/descriptor reasoning. This is semantically safe but may miss a Binaryen-positive local opportunity that would need a separate safe reference-conversion result-type model.

Validation evidence for this slice:

```sh
wasm-tools parse .tmp/lcse-next-spots/ref-convert.wat -o .tmp/lcse-next-spots/ref-convert.wasm
wasm-opt .tmp/lcse-next-spots/ref-convert.wasm --all-features --local-cse -S -o .tmp/lcse-next-spots/ref-convert.binaryen.wat
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-ref-convert-boundary-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the added conservative core-built coverage passed immediately (`121/121`), so this was missing-test-only coverage for Starshine's existing conservative behavior. `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed (`121/121`). The first broad `moon test src/passes` and `moon test` attempts hit a `remove_unused_brs_test.mbt` assertion while unrelated `src/passes/remove_unused_brs*` worktree edits were present; agent classification: unrelated/transient non-LCSE command failure, because the slice only changed LCSE tests/docs and the focused `remove_unused_brs_test.mbt` rerun then passed (`106/106`). Rerun `moon test src/passes` passed (`1671/1671`) and rerun full `moon test` passed (`4856/4856`); native build succeeded with no work to do; compare reached `6764` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the compare command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up `string.const` root no-op slice on 2026-06-05

A later focused LCSE hardening slice spot-checked repeated `string.const` roots. The installed `wasm-tools parse` did not accept the string proposal text shape, so the external spot-check used `wasm-opt input.wat --all-features --local-cse -S` directly on `.tmp/lcse-next-spots/string-const.wat`; Binaryen kept both representative `string.const` roots unmaterialized in that fixture.

This slice deliberately did not implement string-reference root CSE. The landed core-built direct test `local-cse leaves repeated string const roots unmaterialized` documents Starshine's no-temp behavior for `string.const` roots and matches the direct Binaryen text spot-check instead of forcing a brittle external parser path. This remains a string/reference boundary, not arbitrary string value numbering or non-null reference temp-local reasoning.

Validation evidence for this slice:

```sh
wasm-tools parse .tmp/lcse-next-spots/string-const.wat -o .tmp/lcse-next-spots/string-const.wasm # rejected the string.const text shape
wasm-opt .tmp/lcse-next-spots/string-const.wat --all-features --local-cse -S -o .tmp/lcse-next-spots/string-const.binaryen-text.wat
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-string-const-boundary-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the added conservative core-built coverage passed immediately (`122/122`), so this was missing-test-only coverage for behavior that already matched the Binaryen text spot-check. `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed (`122/122`); `moon test src/passes` passed (`1673/1673`); full `moon test` passed (`4858/4858`); native build succeeded with warnings only and exit `0`; compare reached `6767` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up SIMD load-splat/load-zero root boundary on 2026-06-05

A later focused LCSE hardening slice added core-built coverage for repeated `v128.load8_splat`, `v128.load16_splat`, `v128.load32_splat`, `v128.load64_splat`, `v128.load32_zero`, and `v128.load64_zero` roots. Binaryen spot-checking the representative WAT materialized repeated `v128.load8_splat` and `v128.load32_zero` roots with `local.tee` / `local.get`; Starshine intentionally leaves the full load-splat/load-zero family unmaterialized rather than adding SIMD value numbering or SIMD-aware memory GVN. Agent classification: documented conservative deferral / missing-test-only coverage, not a semantic mismatch.

Validation evidence for this slice:

```sh
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-simd-load-splat-zero-boundary-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed (`123/123`). Broad `moon test src/passes` and full `moon test` failed in the unrelated dirty `remove_unused_brs_test.mbt` guard (`remove-unused-brs skips void-root stack/local-set call hazards`), not in LCSE. Native `moon build --target native --release src/cmd` failed before compare because the same unrelated dirty `src/passes/remove_unused_brs.mbt` change currently does not compile (`Cannot create values of the read-only type: LocalSet`). The compare lane was rerun with the already-present native `target/native/release/build/cmd/cmd.exe` because this slice only added tests/docs; it reached `6765` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification for those command failures: Binaryen/tool oracle failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up SIMD load-extend root boundary on 2026-06-05

A later focused LCSE hardening slice added core-built coverage for repeated `v128.load8x8_s`, `v128.load8x8_u`, `v128.load16x4_s`, `v128.load16x4_u`, `v128.load32x2_s`, and `v128.load32x2_u` roots. Binaryen spot-checking the representative WAT materialized repeated `v128.load8x8_s`, `v128.load16x4_u`, and `v128.load32x2_s` roots with `local.tee` / `local.get`; Starshine intentionally leaves the load-extend family unmaterialized rather than adding SIMD value numbering or SIMD-aware memory GVN. Agent classification: documented conservative deferral / missing-test-only coverage, not a semantic mismatch.

Validation evidence for this slice:

```sh
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-simd-load-extend-boundary-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the added conservative core-built coverage passed immediately (`124/124`), so this was missing-test-only coverage. `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed (`124/124`); `moon test src/passes` passed (`1676/1676`); full `moon test` passed (`4861/4861`); native build reported no work; compare reached `6769` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up SIMD store local-only boundary on 2026-06-05

A later focused LCSE hardening slice added core-built coverage for local-only scalar reuse across representative SIMD store operations: `v128.store` and `v128.store8_lane`. Binaryen spot-checking the representative WAT materialized the local-only scalar expressions across both stores with `local.tee` / `local.get`; Starshine intentionally clears the LCSE window at these SIMD stores rather than adding SIMD store effect modeling or memory-state reasoning in this audit slice. Agent classification: documented conservative deferral / missing-test-only coverage, not a semantic mismatch.

Validation evidence for this slice:

```sh
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-simd-store-local-only-boundary-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the added conservative core-built coverage passed immediately (`125/125`), so this was missing-test-only coverage. `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; focused LCSE tests passed (`125/125`); `moon test src/passes` passed (`1678/1678`); full `moon test` passed (`4863/4863`); native build reported no work; compare reached `6768` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).

## Follow-up packed shared-GC atomic root boundary on 2026-06-05

A later focused LCSE hardening slice added core-built coverage for repeated packed `struct.atomic.get_s` and `struct.atomic.get_u` roots. Binaryen spot-checking the representative text fixture, using Binaryen's order-less custom-descriptor/shared-GC spelling, materialized both representative packed atomic roots with `local.tee` / `local.get`; Starshine intentionally leaves the packed atomic roots unmaterialized rather than adding atomic, heap, or memory GVN. Agent classification: documented conservative deferral / implementation-required only for the test fixture typo found during TDD, not a semantic mismatch.

Validation evidence for this slice:

```sh
moon info
moon fmt
moon test --package jtenner/starshine/passes --file local_cse_test.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-cse --out-dir .tmp/pass-fuzz-local-cse-packed-struct-atomic-boundary-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Results: the first core-built test attempt failed to compile because the test used the nonexistent `Mut::var()` constructor; after correcting the fixture to `Mut::var_()`, focused LCSE tests passed (`126/126`). `moon info` still hit the known Moon panic (`index out of bounds: the len is 36 but the index is 8329485`, exit `101`); `moon fmt` passed; `moon test src/passes` passed (`1680/1680`); full `moon test` passed (`4865/4865`); native build reported no work; compare reached `6768` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures. Agent classification: the command failures are oracle/tool failures, not Starshine semantic failures (`17` empty-recursion-group, `1` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index).
