///|
test "fifth audit DAE retains assignment read in legacy body" {
  let get = @lib.Instruction::local_get(@lib.LocalIdx::new(0U))
  let store = @lib.Instruction::global_set(@lib.GlobalIdx::new(0U))
  let legacy = @lib.Instruction::try_(
    @lib.BlockType::void_(),
    @lib.Expr::new([get, store]),
    [@lib.LegacyCatch::all(@lib.Expr::new([]))],
    delegate=None,
  )
  let body = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    get,
    @lib.Instruction::drop(),
    legacy,
  ]
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"f\" (func)) (global (mut i32) (i32.const 0)) (func (local i32)))",
  )
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([@lib.ValType::i32()]),
        @lib.Expr::new(body),
      ),
    ]),
  )
  assert_true(@validate.validate_module(input).is_ok())
  assert_true(dae_try_inline_i32_const_local_set_flat_once(body, 0).is_none())
  assert_true(dae_instr_references_local(legacy, @lib.LocalIdx::new(0U)))
}

///|
test "fifth audit DAE retains assignment read in legacy catch" {
  let get = @lib.Instruction::local_get(@lib.LocalIdx::new(0U))
  let store = @lib.Instruction::global_set(@lib.GlobalIdx::new(0U))
  let legacy = @lib.Instruction::try_(
    @lib.BlockType::void_(),
    @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(0U))]),
    [@lib.LegacyCatch::all(@lib.Expr::new([get, store]))],
    delegate=None,
  )
  let body = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    get,
    @lib.Instruction::drop(),
    legacy,
  ]
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"f\" (func)) (global (mut i32) (i32.const 0)) (func (local i32)))",
  )
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([@lib.ValType::i32()]),
        @lib.Expr::new(body),
      ),
    ]),
  )
  assert_true(@validate.validate_module(input).is_ok())
  assert_true(dae_try_inline_i32_const_local_set_flat_once(body, 0).is_none())
  assert_true(dae_instr_references_local(legacy, @lib.LocalIdx::new(0U)))
}
