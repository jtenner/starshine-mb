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
