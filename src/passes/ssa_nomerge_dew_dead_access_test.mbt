///|
test "ssa-nomerge keeps the live source after a polymorphic unreachable write" {
  let input = pass_test_module_from_wat(
    (
      #|(module (func (export "run") (param i32) (result i64) (local i32 i64 i64) block block block block local.get 0 br_table 0 1 2 end i32.const 1 local.set 1 br 2 end unreachable local.set 1 br 1 end unreachable end i64.const 42 local.set 2 i64.const 0 local.set 3 local.get 2))
    ),
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "ssa-nomerge",
  ]).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  match body[body.length() - 1] {
    @lib.LocalGet(result_local) => {
      let mut found = false
      for i = 0; i + 1 < body.length(); i = i + 1 {
        if body[i] == @lib.Instruction::i64_const(@lib.I64(42L)) &&
          body[i + 1] == @lib.Instruction::local_set(result_local) {
          found = true
        }
      }
      assert_true(found, msg=body.to_string())
    }
    _ => fail("the result must read the live write of 42, got \{body}")
  }
  assert_true(output.code_sec != input.code_sec)
  ignore(@validate.validate_module(output).unwrap())
}
