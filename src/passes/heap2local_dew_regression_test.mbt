///|
test "heap2local preserves reference fields across value-block boundaries" {
  let input = pass_test_module_from_wat(
    (
    #|(module
    #| (type $value (struct (field i32)))
    #| (type $pair (struct (field i32) (field (ref $value))))
    #| (func (param (ref $value)) (result i32) (local (ref null $pair))
    #|   i32.const 7 local.get 0 struct.new $pair local.tee 1
    #|   struct.get $pair 0
    #|   local.get 1 struct.get $pair 1 struct.get $value 0
    #|   i32.add))
    ),
  )
  let output = run_hot_pipeline(
    input, HotPipelineOptions::new(), ["heap2local"],
  ).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_true(output.code_sec != input.code_sec)
  // The scalar reference is set inside the value block and read outside it.
  // Its declaration must have a default value under Wasm local-init rules.
  for type_ in locals.iter() {
    match type_ {
      @lib.RefTypeValType(ref_type) => assert_true(ref_type.is_defaultable())
      _ => ()
    }
  }
  let pair = @lib.TypeIdx::new(1U)
  assert_false(body.contains(@lib.Instruction::struct_new(pair)))
  assert_false(body.contains(@lib.Instruction::struct_get(pair, @lib.U32(0U))))
  assert_false(body.contains(@lib.Instruction::struct_get(pair, @lib.U32(1U))))
  ignore(@validate.validate_module(output).unwrap())
}
