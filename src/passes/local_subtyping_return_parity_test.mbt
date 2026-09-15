///|
test "local-subtyping return parity removes the dead root continuation" {
  let input = pass_test_module_from_wat(
    "(module (type (func)) (type (struct (field i32))) (func (type 0) (local anyref) struct.new_default 1 local.set 0 local.get 0 drop return local.get 0 drop))",
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "local-subtyping",
  ]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(body.last(), Some(@lib.Instruction::return_()))
  @debug.assert_eq(body.filter(fn(i) { i is @lib.LocalGet(_) }).length(), 1)
}

///|
test "local-subtyping return parity preserves prefix effects and result" {
  let input = pass_test_module_from_wat(
    "(module (global (mut i32) (i32.const 0)) (func (result i32) i32.const 7 global.set 0 i32.const 42 return i32.const 99 drop))",
  )
  let output = local_subtyping_run_module_pass(input)
  assert_true(@validate.validate_module(output).is_ok())
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(body.length(), 4)
  @debug.assert_eq(body[0], @lib.Instruction::i32_const(7))
  assert_true(body[1] is @lib.GlobalSet(_))
  @debug.assert_eq(body[2], @lib.Instruction::i32_const(42))
  assert_true(body[3] is @lib.Return)
}

///|
test "local-subtyping return parity preserves conditional fallthrough" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) local.get 0 if i32.const 42 return end i32.const 7))",
  )
  let output = local_subtyping_run_module_pass(input)
  assert_true(@validate.validate_module(output).is_ok())
  @debug.assert_eq(output.code_sec, input.code_sec)
}

///|
test "local-subtyping return parity keeps surviving label names" {
  let kept = @lib.NameAssoc::new(0U, @lib.Name::from_string("kept"))
  let input = pass_test_module_from_wat(
    "(module (func block nop end return block nop end) (func block nop end))",
  ).with_name_sec(
    @lib.NameSec::new(
      label_names=Some(
        @lib.IndirectNameMap::new([
          @lib.IndirectNameAssoc::new(
            0U,
            @lib.NameMap::new([
              kept,
              @lib.NameAssoc::new(1U, @lib.Name::from_string("removed")),
            ]),
          ),
          @lib.IndirectNameAssoc::new(1U, @lib.NameMap::new([kept])),
        ]),
      ),
    ),
  )
  let output = local_subtyping_run_module_pass(input)
  @debug.assert_eq(
    output.name_sec.unwrap().label_names.unwrap().0[0].1,
    @lib.NameMap::new([kept]),
  )
  @debug.assert_eq(
    output.name_sec.unwrap().label_names.unwrap().0[1],
    input.name_sec.unwrap().label_names.unwrap().0[1],
  )
}
