---
kind: research
status: working
date: 2026-05-25
sources:
  - ../../binaryen/passes/dae-optimizing/starshine-strategy.md
  - ../../../../agent-todo.md
  - ../../../../.tmp/dae-func504-tail-control-artifact/result.json
  - ../../../../.tmp/dae-func504-tail-control-artifact/func-defined505-abs522.binaryen.wat
  - ../../../../.tmp/dae-func504-tail-control-artifact/func-defined505-abs522.starshine.wat
  - ../../../../.tmp/dae-func505-recovery.stderr
---

# DAE Func505 reduction and attribution

## Question

Advance `[DAE]006` from the previous unknown/risky Func505 classification by reducing the observed body drift to a focused fixture shape and attributing which Starshine DAE lane touched the function.

## Commands and artifacts

- Reused both-canonical artifact: `.tmp/dae-func504-tail-control-artifact`, first diff `defined=505 abs=522`.
- Replayed Starshine with pass tracing and function print:

```sh
target/native/release/build/cmd/cmd.exe \
  --tracing pass \
  --dae-optimizing \
  --print-func 522 \
  --out .tmp/dae-func505-recovery-starshine.wasm \
  tests/node/dist/starshine-debug-wasi.wasm \
  > .tmp/dae-func505-recovery.stdout \
  2> .tmp/dae-func505-recovery.stderr
```

Trace attribution:

- `pass[dae-optimizing]:mid-exact-literal primary_def=505` is the DAE lane that rewrites this function's signature/body boundary.
- `pass[dae-optimizing]:module-raw-cleanup primary_def=215` runs later, but the trace has no Func505-specific selected cleanup marker after the mid-exact-literal rewrite.
- No `pass[dae-optimizing]:nested-pass name=...` lines appeared in this replay, so the observed Func505 body remains attributable to direct DAE rewrite plus broad module raw cleanup rather than a touched nested cleanup replay.

## Reduced fixture shape

The smallest useful reduction is a parser-loop function with:

1. one live input pointer/length handle;
2. two freshly allocated boxes, one accumulating a parsed `i64` and one counting parsed digits;
3. an induction local initialized to zero;
4. a loop that:
   - checks `induction < len(input)`,
   - performs a bounds-check helper call on `(induction, len(input) - 1)`,
   - loads a 16-bit character at `input + (induction << 1) + 8`,
   - skips underscore (`95`) via a branch around the digit logic,
   - errors if the character is below `48` or above `57`,
   - computes `digit = widen(char - 48)`,
   - errors if `current_accumulator > ((u64.max - digit) / 10)`,
   - stores `current_accumulator * 10 + digit`,
   - increments the parsed-digit count,
   - increments induction and repeats;
5. after the loop, frees the count box and returns an error if the count is zero, otherwise frees the accumulator box and returns a boxed `i64` result.

The reduced Starshine-vs-Binaryen body delta is not a boundary signature issue anymore. Both sides have one `i32` parameter and one `i32` result. The remaining shape is:

```wat
;; Binaryen-style compact loop skeleton
(local.set $i (i32.const 0))
(loop $again
  (block $exit
    (local.set $i
      (block $next (result i32)
        (if (i32.gt_s (call $len (local.get $input)) (local.get $i))
          (then
            (call $check (local.get $i) (i32.sub (call $len (local.get $input)) (i32.const 1)))
            (if (i32.eqz (call $is_underscore (local.tee $ch (i32.load16_u ...)) (i32.const 95)))
              (then
                (if (i32.lt_u (local.get $ch) (i32.const 48)) (then (return (call $error ...))))
                (if (i64.lt_u
                      (i64.div_u (i64.sub (i64.const -1) (local.tee $digit (call $widen (i32.sub (local.get $ch) (i32.const 48))))) (i64.const 10))
                      (i64.load (local.get $acc)))
                  (then (return (call $error ...))))
                (i64.store (local.get $acc) (i64.add (i64.mul (i64.load (local.get $acc)) (i64.const 10)) (local.get $digit)))
                (i32.store (local.get $count) (i32.add (i32.load (local.get $count)) (i32.const 1)))))
            (br $next (i32.add (local.get $i) (i32.const 1)))) )
        (br $exit))))
    (br $again)))
```

```wat
;; Starshine-style reduced residual after the same signature rewrite
(loop $again
  (block $exit
    (local.set $i_hi
      (block $next (result i32)
        (if (i32.lt_s (local.tee $i_tmp (local.get $i_hi)) (call $len (local.get $input)))
          (then
            (block $skip_digit
              (call $check (local.get $i_tmp) (i32.sub (call $len (local.get $input)) (i32.const 1)))
              (if (call $is_underscore (local.tee $ch_hi (i32.load16_u ...)) (i32.const 95))
                (then (br $skip_digit)))
              (drop (i32.const 0))
              (if
                (if (result i32)
                  (i32.lt_s (local.tee $ch_tmp (local.get $ch_hi)) (i32.const 48))
                  (then (i32.const 1))
                  (else (i32.gt_s (local.get $5) (i32.const 57))))
                (then (return (call $error ...))))
              (drop (i32.const 0))
              (local.set $limit_hi
                (i64.div_u (i64.sub (i64.const -1) (local.tee $digit_hi (call $widen (i32.sub (local.get $ch_tmp) (i32.const 48))))) (i64.const 10)))
              (if (i64.gt_u (i64.load (local.get $acc_hi)) (local.get $limit_hi))
                (then (return (call $error ...))))
              (drop (i32.const 0))
              (i64.store (local.get $acc_hi) (i64.add (i64.mul (i64.load (local.get $acc_hi)) (i64.const 10)) (local.get $digit_hi)))
              (drop (i32.const 0))
              (i32.store (local.get $count_hi) (i32.add (i32.load (local.get $count_hi)) (i32.const 1)))
              (drop (i32.const 0))
              (br $skip_digit))
            (br $next (i32.add (local.get $i_tmp) (i32.const 1)))) )
        (drop (i32.const 0))
        (br $exit)))
    (br $again)))
```

This is intentionally a shape fixture, not yet a passing Moon assertion. It preserves the loop carrier, underscore branch, digit guard, overflow guard, accumulator/count stores, high-temp locals, and dropped-zero debris without copying the whole artifact function.

## Attribution and classification

Agent classification remains **unknown/risky DAE output-shape frontier**, but the first reduction step narrows the source:

- not selected result removal: the function signatures already match;
- not a current nested-cleanup ordering failure in this replay: no nested-pass trace lines emitted;
- not safe diagnostic-only normalization yet: the reduced shape still includes live condition inversions, the suspicious high-bound guard using `local.get $5` in the Starshine pretty output, and accumulator overflow logic;
- likely source: the `mid-exact-literal` rewrite for defined Func505 leaves HOT-lowered local carriers and raw debris that Binaryen's DAE/nested cleanup does not leave, and the broad module raw cleanup does not currently clean this parser-loop shape.

## Next subtasks

1. Turn the reduction above into a focused Moon/WAT regression only after deciding the expected behavior: either a narrow pass-side cleanup for this parser-loop carrier or an assertion that a specific guard/local-copy shape remains preserved.
2. Inspect the Starshine pretty/body around the `i32.gt_s (local.get $5) (i32.const 57)` high-bound check before changing logic. If `$5` is not the loaded character carrier after local renumbering, this becomes a correctness regression rather than representation drift.
3. If the guard is semantically equivalent after local mapping, prefer a pass-side cleanup over a canonical normalizer: remove only audited `i32.const 0; drop` debris and local-copy/high-temp carriers in DAE-touched parser loops, preserving all calls, loads, stores, returns, and trapping/effectful operations.
4. Re-run `.tmp/dae-func504-tail-control-artifact` (or a successor both-canonical artifact), validate both outputs with `wasm-opt --all-features`, and record pass-local timing. `[DAE]011` remains open because the latest recorded pass-local timing is still over the 2x target.

## Outcome for this recovery slice

This slice completed the first Func505 reduction/attribution step and left pass behavior unchanged. The fixture is reduced enough to guide a focused test-first implementation, but it is not yet a safe normalizer or a proven semantic-equivalent cleanup target.
