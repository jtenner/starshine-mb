///|
test "fourth audit command simplify-globals-optimizing f32 signed zero 0 to -0" {
  let output = cmd_deep_audit_run(
    "(module (global $g (mut f32) (f32.const 0)) (func (export \"f\") (result i32) f32.const -0 global.set $g global.get $g i32.reinterpret_f32))",
    "simplify-globals-optimizing",
  )
  @debug.assert_eq(
    cmd_deep_audit_count(cmd_deep_audit_body(output), fn(i) {
      match i {
        @lib.F32Const(@lib.F32(v)) => v.reinterpret_as_uint() == 0x80000000U
        _ => false
      }
    }),
    1,
  )
}

///|
test "fourth audit command simplify-globals-optimizing f32 signed zero -0 to 0" {
  let output = cmd_deep_audit_run(
    "(module (global $g (mut f32) (f32.const -0)) (func (export \"f\") (result i32) f32.const 0 global.set $g global.get $g i32.reinterpret_f32))",
    "simplify-globals-optimizing",
  )
  @debug.assert_eq(
    cmd_deep_audit_count(cmd_deep_audit_body(output), fn(i) {
      match i {
        @lib.F32Const(@lib.F32(v)) => v.reinterpret_as_uint() == 0U
        _ => false
      }
    }),
    1,
  )
}

///|
test "fourth audit command simplify-globals-optimizing f64 signed zero 0 to -0" {
  let output = cmd_deep_audit_run(
    "(module (global $g (mut f64) (f64.const 0)) (func (export \"f\") (result i64) f64.const -0 global.set $g global.get $g i64.reinterpret_f64))",
    "simplify-globals-optimizing",
  )
  @debug.assert_eq(
    cmd_deep_audit_count(cmd_deep_audit_body(output), fn(i) {
      match i {
        @lib.F64Const(@lib.F64(v)) =>
          v.reinterpret_as_uint64() == 0x8000000000000000UL
        _ => false
      }
    }),
    1,
  )
}

///|
test "fourth audit command simplify-globals-optimizing f64 signed zero -0 to 0" {
  let output = cmd_deep_audit_run(
    "(module (global $g (mut f64) (f64.const -0)) (func (export \"f\") (result i64) f64.const 0 global.set $g global.get $g i64.reinterpret_f64))",
    "simplify-globals-optimizing",
  )
  @debug.assert_eq(
    cmd_deep_audit_count(cmd_deep_audit_body(output), fn(i) {
      match i {
        @lib.F64Const(@lib.F64(v)) => v.reinterpret_as_uint64() == 0UL
        _ => false
      }
    }),
    1,
  )
}
