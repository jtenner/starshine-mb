///|
test "local-subtyping i31 cleanup parity retains i31 control while pruning dead types" {
  let input = pass_test_module_from_wat(
    "(module (type (func)) (rec (type (struct)) (type (struct))) (type (struct (field i32))) (func (type 0) (local anyref) struct.new_default 3 local.set 0 i32.const 1 if (result anyref) i32.const 0 ref.i31 else i32.const 1 ref.i31 end drop local.get 0 drop))",
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "local-subtyping",
  ]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  @debug.assert_eq(output.type_sec.unwrap().0.length(), 2)
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_true(body.any(fn(i) { i is @lib.If(_, _, _) }))
}
