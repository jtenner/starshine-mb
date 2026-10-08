///|
test "command coalesce-locals retains the protected-body write before a caught call" {
  let output = cmd_deep_audit_run(
    "(module (tag $t) (func $thr (throw $t)) (func (export \"f\") (result i32) (local $unused i32) (local $x i32) (loop nop) (local.set $x (i32.const 77)) (block $h (try_table (catch_all $h) (local.set $x (i32.const 55)) (call $thr) (local.set $x (i32.const 0)))) (local.get $x)))",
    "coalesce-locals",
  )
  @validate.validate_module(output).unwrap()
  let body = cmd_deep_audit_body(output, index=1)
  let mut after_55 = false
  let mut retained_write = false
  ignore(
    cmd_deep_audit_count(body, fn(instr) {
      if after_55 {
        retained_write = instr is @lib.LocalSet(_) || instr is @lib.LocalTee(_)
      }
      after_55 = instr is @lib.I32Const(@lib.I32(55))
      false
    }),
  )
  assert_true(retained_write)
}

///|
test "command DCE retains continuation after a catch-all exit" {
  let output = cmd_deep_audit_run(
    "(module (tag $t) (func $thr (param i32) (if (local.get 0) (then (throw $t)))) (func (export \"f\") (result i32) (local $x i32) (local.set $x (block $h (result i32) (try_table (block $h2 (try_table (catch_all $h2) (call $thr (i32.const 1)) (return (i32.const 5))))) (i32.const 9))) (i32.add (local.get $x) (i32.const 100))))",
    "dead-code-elimination",
  )
  @validate.validate_module(output).unwrap()
  let body = cmd_deep_audit_body(output, index=1)
  assert_eq(
    cmd_deep_audit_count(body, fn(instr) { instr is @lib.I32Const(@lib.I32(9)) }),
    1,
  )
  assert_eq(
    cmd_deep_audit_count(body, fn(instr) {
      instr is @lib.I32Const(@lib.I32(100))
    }),
    1,
  )
}

///|
test "command coalesce-locals retains a write read after catch-all" {
  let output = cmd_deep_audit_run(
    "(module (tag $t) (func $thr (param i32) (if (local.get 0) (then (throw $t)))) (func (export \"f\") (result i32) (local $unused i32) (local $x i32) (loop $L (if (i32.const 0) (then) (else (local.set $x (i32.const 77))))) (block $h (try_table (catch_all $h) (call $thr (if (result i32) (i32.const 0) (then (i32.const 0)) (else (i32.const 3)))) (local.set $x (i32.const 0)))) (local.get $x)))",
    "coalesce-locals",
  )
  @validate.validate_module(output).unwrap()
  assert_eq(
    cmd_deep_audit_count(cmd_deep_audit_body(output, index=1), fn(instr) {
      instr is @lib.LocalSet(_) || instr is @lib.LocalTee(_)
    }),
    2,
  )
}

///|
test "command flatten writes the rich br-if carrier before its first read" {
  let output = cmd_deep_audit_run(
    "(module (memory 1) (func (export \"f\") (result i32) (local $x i32) (local $q i64) (i64.store (i32.const 0) (i64.const -1)) (local.set $x (block $v (result i32) (local.set $q (i64.load8_s (i32.const 0))) (br_if $v (i32.wrap_i64 (local.get $q)) (i32.const 0)))) (local.get $x)))",
    "flatten",
  )
  @validate.validate_module(output).unwrap()
  let mut first : @lib.Instruction? = None
  ignore(
    cmd_deep_audit_count(cmd_deep_audit_body(output), fn(instr) {
      if first is None {
        match instr {
          @lib.LocalGet(@lib.LocalIdx(raw))
          | @lib.LocalSet(@lib.LocalIdx(raw))
          | @lib.LocalTee(@lib.LocalIdx(raw)) =>
            if raw >= 2U {
              first = Some(instr)
            }
          _ => ()
        }
      }
      false
    }),
  )
  assert_true(
    first is Some(@lib.LocalSet(_)) || first is Some(@lib.LocalTee(_)),
  )
}
