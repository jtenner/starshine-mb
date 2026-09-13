///|
test "parity followup dae cleanup recognizes unchanged NaN bodies" {
  for
    source in [
      "(module (func (result f32) f32.const nan))", "(module (func (result f64) (loop (result f64) f64.const nan)))",
      "(module (func (result f64) (if (result f64) (i32.const 1) (then f64.const nan) (else f64.const 0))))",
    ] {
    let input = pass_test_module_from_wat(source)
    let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    // Inspect one cleanup step, so the failing test remains bounded instead
    // of invoking the repeated cleanup with a non-reflexive float equality.
    let (_, changed) = dae_cleanup_unread_local_body(body, [])
    assert_false(changed)
    let (_, changed) = dae_cleanup_unread_locals(input.code_sec.unwrap().0[0], [])
    assert_false(changed)
  }
}
