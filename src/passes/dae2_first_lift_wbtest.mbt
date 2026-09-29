///|
test "DAE2 preserves pinned call-free bodies without lifting them during active pruning" {
  let input = pass_test_module_from_wat(
    "(module (global $g (export \"g\") (mut i32) (i32.const 0)) (func $helper (param i32) (result i32) i32.const 7) (func (export \"run\") (result i32) i32.const 9 call $helper) (func (export \"keep\") (param i32) (result i32) i32.const 13 global.set $g local.get 0))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let lifts = [0]
  let output = dae2_run_module_pass(input, false, analysis_lifts=Some(lifts)).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(lifts[0], 0)
  let @lib.Func(_, @lib.Expr(caller)) = output.code_sec.unwrap().0[1]
  assert_eq(caller, [@lib.Instruction::call(@lib.FuncIdx::new(0U))])
  assert_eq(output.code_sec.unwrap().0[2], input.code_sec.unwrap().0[2])
  assert_eq(
    @ir.hot_module_resolve_func_type(
      @ir.hot_module_context_from_module(output),
      @lib.FuncIdx::new(0U),
    ),
    Some(@lib.FuncType::new([], [@lib.ValType::i32()])),
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 pinned-body admission still rejects an intentionally invalid empty-stack drop" {
  let input = pass_test_module_from_wat("(module (func (export \"run\")))")
  let invalid = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::new([]),
        @lib.Expr::new([@lib.Instruction::drop()]),
      ),
    ]),
  )
  assert_true(dae2_run_module_pass(invalid, false).is_err())
}

///|
test "DAE2 first-lift admission preserves pinned indexed control families without lifting" {
  let input = pass_test_module_from_wat(
    "(module (type $sig (func (param i32) (result i32))) (func $helper (type $sig) i32.const 7) (func (export \"run\") (result i32) block (result i32) i32.const 9 call $helper end) (func (export \"keep\") (result i32) i32.const 3 block (type $sig) drop i32.const 9 br 0 end))",
  )
  let lifts = [0]
  let output = dae2_run_module_pass(input, false, analysis_lifts=Some(lifts)).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(lifts[0], 0)
  let context = @ir.hot_module_context_from_module(output)
  assert_eq(
    @ir.hot_module_resolve_func_type(context, @lib.FuncIdx::new(0U)),
    Some(@lib.FuncType::new([], [@lib.ValType::i32()])),
  )
  let @lib.Func(_, @lib.Expr(keep)) = output.code_sec.unwrap().0[2]
  match keep[1] {
    @lib.Block(@lib.TypeIdxBlockType(index), @lib.Expr(body)) => {
      assert_eq(
        @ir.hot_module_resolve_type_func_type(context, index),
        Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
      )
      assert_eq(body, [
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::br(@lib.LabelIdx::new(0U)),
      ])
    }
    _ => fail("expected the preserved indexed block")
  }
}

///|
test "DAE2 first-lift admission preserves nested calls to pinned imports during active pruning" {
  let input = pass_test_module_from_wat(
    "(module (import \"host\" \"echo\" (func $echo (param i32) (result i32))) (func $helper (param i32) (result i32) i32.const 7) (func (export \"run\") (result i32) i32.const 9 call $helper) (func (export \"keep\") (param i32) (result i32) block (result i32) local.get 0 call $echo br 0 end))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let lifts = [0]
  let output = dae2_run_module_pass(input, false, analysis_lifts=Some(lifts)).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(lifts[0], 0)
  assert_eq(output.code_sec.unwrap().0[2], input.code_sec.unwrap().0[2])
  let @lib.Func(_, @lib.Expr(caller)) = output.code_sec.unwrap().0[1]
  assert_eq(caller, [@lib.Instruction::call(@lib.FuncIdx::new(1U))])
  assert_eq(
    @ir.hot_module_resolve_func_type(
      @ir.hot_module_context_from_module(output),
      @lib.FuncIdx::new(1U),
    ),
    Some(@lib.FuncType::new([], [@lib.ValType::i32()])),
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 first-lift admission preserves pinned indirect calls and indexed controls" {
  let input = pass_test_module_from_wat(
    "(module (type $sig (func (param i32) (result i32))) (table (export \"table\") 1 funcref) (func $helper (param i32) (result i32) i32.const 7) (func (export \"run\") (result i32) i32.const 9 call $helper) (func (export \"keep\") (param i32) (result i32) local.get 0 block (type $sig) i32.const 0 call_indirect (type $sig) br 0 end))",
  )
  let lifts = [0]
  let output = dae2_run_module_pass(input, false, analysis_lifts=Some(lifts)).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(lifts[0], 0)
  assert_eq(output.code_sec.unwrap().0[2], input.code_sec.unwrap().0[2])
  let @lib.Func(_, @lib.Expr(caller)) = output.code_sec.unwrap().0[1]
  assert_eq(caller, [@lib.Instruction::call(@lib.FuncIdx::new(0U))])
}

///|
test "DAE2 first-lift admission analyzes intrinsic target dependencies in closed world" {
  let input = pass_test_module_from_wat(
    "(module (import \"binaryen-intrinsics\" \"call.without.effects\" (func $invoke (param i32 funcref) (result i32))) (func $target (param i32) (result i32) i32.const 11) (elem declare func $target) (func $helper (param i32) (result i32) i32.const 7) (func (export \"run\") (result i32) i32.const 9 call $helper) (func (export \"keep\") (result i32) i32.const 3 ref.func $target call $invoke))",
  )
  let lifts = [0]
  let output = dae2_run_module_pass(input, true, analysis_lifts=Some(lifts)).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(lifts[0], 1)
  let context = @ir.hot_module_context_from_module(output)
  assert_eq(
    @ir.hot_module_resolve_func_type(context, @lib.FuncIdx::new(1U)),
    Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
  )
  assert_eq(
    @ir.hot_module_resolve_func_type(context, @lib.FuncIdx::new(2U)),
    Some(@lib.FuncType::new([], [@lib.ValType::i32()])),
  )
  let @lib.Func(_, @lib.Expr(caller)) = output.code_sec.unwrap().0[2]
  assert_eq(caller, [@lib.Instruction::call(@lib.FuncIdx::new(2U))])
}

///|
test "DAE2 pinned-call admission rejects intentionally invalid missing arguments" {
  let input = pass_test_module_from_wat(
    "(module (import \"host\" \"take\" (func $take (param i32))) (func (export \"keep\") i32.const 9 call $take))",
  )
  let invalid = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::new([]),
        @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(0U))]),
      ),
    ]),
  )
  assert_true(dae2_run_module_pass(invalid, false).is_err())
}
