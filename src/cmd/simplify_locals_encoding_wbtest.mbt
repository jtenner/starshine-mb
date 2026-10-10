///|
test "simplify-locals command groups declarations and remaps live numeric locals" {
  let input = @passes.pass_test_module_from_wat(
    "(module (import \"env\" \"tick\" (func (result i32))) (func (export \"run\") (param i32) (result i32) (local i32 f64 i32) call 0 local.set 3 block local.get 0 if local.get 3 i32.const 1 i32.add local.set 3 end end local.get 3 local.get 3 i32.add))",
  )
  let output = optimize_module_with_pass_flags(
    input,
    ["simplify-locals"],
    OptimizeOptions::new(),
  ).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
  assert_eq(locals.runs().length(), 2)
  @debug.assert_eq(locals.get(0), @lib.ValType::i32())
  @debug.assert_eq(locals.get(1), @lib.ValType::i32())
  @debug.assert_eq(locals.get(2), @lib.ValType::f64())
  assert_true(@binary.encode_module(output).unwrap().length() <= 81)
}

///|
test "simplify-locals command removes unused simple types" {
  let input = @passes.pass_test_module_from_wat(
    "(module (type (func (param f64 f64))) (type (func (result i32))) (type (func (param i64))) (func (export \"run\") (type 1) (result i32) (local i32 f64 i32) i32.const 41 local.set 2 local.get 2))",
  )
  let output = optimize_module_with_pass_flags(
    input,
    ["simplify-locals"],
    OptimizeOptions::new(),
  ).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  assert_eq(output.type_sec.unwrap().0.length(), 1)
  @debug.assert_eq(output.func_sec.unwrap().0, [@lib.TypeIdx::new(0U)])
  assert_true(@binary.encode_module(output).unwrap().length() <= 41)
}

///|
test "simplify-locals command flattens transparent unused scalar result blocks" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (export \"run\") (result i32) (local i32) block (result i32) i32.const 63 end local.set 0 local.get 0))",
  )
  let output = optimize_module_with_pass_flags(
    input,
    ["simplify-locals"],
    OptimizeOptions::new(),
  ).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(body, [@lib.Instruction::i32_const(63)])
  assert_true(@binary.encode_module(output).unwrap().length() <= 39)
}
