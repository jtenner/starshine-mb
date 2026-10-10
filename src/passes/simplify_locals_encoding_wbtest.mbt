///|
fn simplify_locals_encoding_live_fixture() -> @lib.Module {
  pass_test_module_from_wat(
    "(module (import \"env\" \"tick\" (func (result i32))) (func (export \"run\") (param i32) (result i32) (local i32 f64 i32) call 0 local.set 3 block local.get 0 if local.get 3 i32.const 1 i32.add local.set 3 end end local.get 3 local.get 3 i32.add))",
  )
}

///|
fn simplify_locals_encoding_has_local(
  body : Array[@lib.Instruction],
  index : UInt,
) -> Bool {
  for instr in body {
    match instr {
      @lib.LocalGet(@lib.LocalIdx(raw))
      | @lib.LocalSet(@lib.LocalIdx(raw))
      | @lib.LocalTee(@lib.LocalIdx(raw)) => if raw == index { return true }
      @lib.Block(_, @lib.Expr(nested))
      | @lib.Loop(_, @lib.Expr(nested))
      | @lib.TryTable(_, _, @lib.Expr(nested)) =>
        if simplify_locals_encoding_has_local(nested, index) {
          return true
        }
      @lib.If(_, then_, else_) => {
        if simplify_locals_encoding_has_local(then_, index) {
          return true
        }
        if else_ is Some(nested) &&
          simplify_locals_encoding_has_local(nested, index) {
          return true
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn simplify_locals_encoding_assert_live_grouped(
  output : @lib.Module,
) -> Unit raise {
  assert_true(@validate.validate_module(output).is_ok())
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.runs().length(), 2)
  @debug.assert_eq(locals.get(0), @lib.ValType::i32())
  @debug.assert_eq(locals.get(1), @lib.ValType::i32())
  @debug.assert_eq(locals.get(2), @lib.ValType::f64())
  assert_true(simplify_locals_encoding_has_local(body, 2U))
  assert_false(simplify_locals_encoding_has_local(body, 3U))
  // Verified Binaryen 133 emits 81 bytes for this fixture. The call result
  // remains live through the conditional and is used twice after the join.
  let single = simplify_locals_encoding_live_fixture().with_code_sec(
    @lib.CodeSec::new([output.code_sec.unwrap().0[0]]),
  )
  assert_true(@binary.encode_module(single).unwrap().length() <= 81)
}

///|
test "simplify-locals groups numeric declarations and remaps live nested accesses" {
  let input = simplify_locals_encoding_live_fixture()
  assert_true(@validate.validate_module(input).is_ok())
  let @lib.Func(input_locals, _) = input.code_sec.unwrap().0[0]
  assert_eq(input_locals.runs().length(), 3)
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "simplify-locals",
  ]).unwrap()
  simplify_locals_encoding_assert_live_grouped(output)
}

///|
test "simplify-locals nondeferred writeback groups live numeric declarations" {
  let output = run_hot_pipeline_apply_hot_pass(
    simplify_locals_encoding_live_fixture(),
    pass_registry_lookup_cached("simplify-locals").unwrap(),
    HotPipelineOptions::new(),
    defer_simplify_locals_writeback_guard=false,
  ).unwrap()
  simplify_locals_encoding_assert_live_grouped(output)
}

///|
test "simplify-locals encoding cleanup survives a fused hot pass stack" {
  let output = run_hot_pipeline(
    simplify_locals_encoding_live_fixture(),
    HotPipelineOptions::new(stack_function_passes=true),
    ["simplify-locals", "merge-blocks"],
  ).unwrap()
  simplify_locals_encoding_assert_live_grouped(output)
}

///|
test "selected simplify-locals cleanup keeps unselected local indices" {
  let input = simplify_locals_encoding_live_fixture()
  let original = input.code_sec.unwrap().0[0]
  let signature = input.func_sec.unwrap().0[0]
  let input = input
    .with_code_sec(@lib.CodeSec::new([original, original]))
    .with_func_sec(@lib.FuncSec::new([signature, signature]))
  let descriptor = pass_registry_lookup_cached("simplify-locals").unwrap().descriptor.unwrap()
  let output = run_hot_pipeline_apply_hot_pass_stack_to_touched(
    input,
    [descriptor],
    [true, false],
    HotPipelineOptions::new(),
  ).unwrap()
  simplify_locals_encoding_assert_live_grouped(output)
  @debug.assert_eq(output.code_sec.unwrap().0[1], original)
}

///|
test "simplify-locals removes unused simple types and declaration overhead" {
  let input = pass_test_module_from_wat(
    "(module (type (func (param f64 f64))) (type (func (result i32))) (type (func (param i64))) (func (export \"run\") (type 1) (result i32) (local i32 f64 i32) i32.const 41 local.set 2 local.get 2))",
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "simplify-locals",
  ]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  assert_eq(output.type_sec.unwrap().0.length(), 1)
  @debug.assert_eq(output.func_sec.unwrap().0, [@lib.TypeIdx::new(0U)])
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.runs().length(), 2)
  @debug.assert_eq(body, [@lib.Instruction::i32_const(41)])
  assert_true(@binary.encode_module(output).unwrap().length() <= 41)
}

///|
test "simplify-locals flattens transparent unused scalar result blocks" {
  let input = pass_test_module_from_wat(
    "(module (func (export \"run\") (result i32) (local i32) block (result i32) i32.const 63 end local.set 0 local.get 0))",
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "simplify-locals",
  ]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(body, [@lib.Instruction::i32_const(63)])
  assert_true(@binary.encode_module(output).unwrap().length() <= 39)
}

///|
test "simplify-locals encoding cleanup preserves unsupported offset metadata" {
  let input = pass_test_module_from_wat(
    "(module (type (func (param f64))) (type (func (result i32))) (func (type 1) (result i32) nop i32.const 41))",
  )
  assert_true(simplify_locals_cleanup_module_encoding(input) != input)
  let guarded = direct_metadata_guard_add_offset_metadata(input)
  @debug.assert_eq(simplify_locals_cleanup_module_encoding(guarded), guarded)
}

///|
test "production touched simplify-locals cleanup remaps only selected local accesses" {
  let input = simplify_locals_encoding_live_fixture()
  let original = input.code_sec.unwrap().0[0]
  let signature = input.func_sec.unwrap().0[0]
  let input = input
    .with_code_sec(@lib.CodeSec::new([original, original]))
    .with_func_sec(@lib.FuncSec::new([signature, signature]))
  let descriptor = pass_registry_lookup_cached("simplify-locals").unwrap().descriptor.unwrap()
  let output = run_hot_pipeline_apply_hot_pass_to_touched(
    input,
    descriptor,
    [true, false],
    HotPipelineOptions::new(),
  ).unwrap()
  simplify_locals_encoding_assert_live_grouped(output)
  @debug.assert_eq(output.code_sec.unwrap().0[1], original)
}

///|
test "stacked simplify-locals and optimize-instructions remove replacement nops" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) (local i32) i32.const 41 local.set 0 local.get 0))",
  )
  let output = run_hot_pipeline(
    input,
    HotPipelineOptions::new(stack_function_passes=true),
    ["simplify-locals", "optimize-instructions"],
  ).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(body, [@lib.Instruction::i32_const(41)])
}
