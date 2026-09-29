///|
test "WAT numeric branches resolve the implicit function label" {
  let module_ = wast_to_binary_module(
    "(module (func (result i32) i32.const 7 br 0) (func (result i32) block i32.const 8 br 1 end unreachable))",
  ).unwrap()
  @validate.validate_module(module_).unwrap()
  let @lib.Func(_, @lib.Expr(first)) = module_.code_sec.unwrap().0[0]
  assert_eq(first, [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::br(@lib.LabelIdx::new(0U)),
  ])
  let @lib.Func(_, @lib.Expr(second)) = module_.code_sec.unwrap().0[1]
  assert_true(
    second[0] is @lib.Block(_, @lib.Expr(body)) &&
    body[1] == @lib.Instruction::br(@lib.LabelIdx::new(1U)),
  )
}

///|
test "WAT branches beyond the implicit function label remain invalid" {
  assert_true(wast_to_binary_module("(module (func br 1))") is Err(_))
  assert_true(wast_to_binary_module("(module (func block br 2 end))") is Err(_))
  // A function identifier is not a source-level label name.
  assert_true(wast_to_binary_module("(module (func $f br $f))") is Err(_))
}

///|
test "WAT implicit function branches enforce result payload arity and types" {
  for
    source in [
      "(module (func (result i32) br 0))", "(module (func (result i32) i64.const 7 br 0))",
      "(module (func (result i32 i64) i32.const 7 br 0))", "(module (func (result i32) block i64.const 7 br 1 end unreachable))",
    ] {
    // These depths are valid, but their payloads are intentionally invalid.
    let module_ = wast_to_binary_module(source).unwrap()
    assert_true(@validate.validate_module(module_) is Err(_))
  }
  let module_ = wast_to_binary_module(
    "(module (func (result i32 i64) block i32.const 7 i64.const 8 br 1 end unreachable))",
  ).unwrap()
  @validate.validate_module(module_).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = module_.code_sec.unwrap().0[0]
  assert_true(
    body[0] is @lib.Block(_, @lib.Expr(items)) &&
    items[2] == @lib.Instruction::br(@lib.LabelIdx::new(1U)),
  )
}
