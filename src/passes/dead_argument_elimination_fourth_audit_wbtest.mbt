///|
test "fourth audit dae nullable cleanup indexes imported functions" {
  let input = pass_test_module_from_wat(
    "(module (import \"m\" \"f\" (func)) (func (param externref) (result i32) local.get 0 ref.is_null) (func (param (ref extern)) (result i32) i32.const 0))",
  )
  let (output, _) = dae_fold_touched_nonnull_ref_is_null(input, [true, false])
  @debug.assert_eq(
    match output.code_sec.unwrap().0[0] {
      @lib.Func(_, @lib.Expr(body)) =>
        body.filter(fn(i) { i is @lib.RefIsNull }).length()
    },
    1,
  )
}
