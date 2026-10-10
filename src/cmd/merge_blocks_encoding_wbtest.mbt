///|
fn merge_blocks_encoding_effect_fixture() -> @lib.Module {
  @passes.pass_test_module_from_wat(
    "(module (memory 1) (global (mut i32) (i32.const 0)) (func block block i32.const 7 drop end end global.get 0 block (result i32) i32.const 1 global.set 0 i32.const 7 end i32.store))",
  )
}

///|
fn merge_blocks_encoding_eh_fixture() -> @lib.Module {
  @passes.pass_test_module_from_wat(
    "(module (type (func)) (type (func)) (memory 1 1 shared) (tag (type 0)) (func (type 1) block block i32.const 7 drop end end block try_table (catch 0 0) block atomic.fence i32.const 0 i32.atomic.load drop end end end))",
  )
}

///|
test "merge-blocks encoding flattens scalar wrappers without moving global writes" {
  let output = optimize_module_with_pass_flags(
    merge_blocks_encoding_effect_fixture(),
    ["merge-blocks"],
    OptimizeOptions::new(),
  ).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(body, [
    @lib.Instruction::i32_const(7),
    @lib.Instruction::drop(),
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::i32_const(1),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::i32_const(7),
    @lib.Instruction::i32_store(
      @lib.MemArg::new(@lib.U32::new(2U), None, @lib.U64::new(0UL)),
    ),
  ])
  // Verified Binaryen 133 emits 51 bytes, with this exact effect order.
  assert_true(@binary.encode_module(output).unwrap().length() <= 51)
}

///|
test "merge-blocks encoding interns duplicate types used by functions and tags" {
  let input = merge_blocks_encoding_eh_fixture()
  let output = optimize_module_with_pass_flags(
    input,
    ["merge-blocks"],
    OptimizeOptions::new(),
  ).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  assert_eq(output.type_sec.unwrap().0.length(), 1)
  @debug.assert_eq(output.func_sec.unwrap().0, [@lib.TypeIdx::new(0U)])
  assert_eq(output.tag_sec, input.tag_sec)
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_true(body.any(fn(instr) { instr is @lib.Block(_, _) }))
  // Verified Binaryen 133 emits 58 bytes; exception and atomic effects remain.
  assert_true(@binary.encode_module(output).unwrap().length() <= 58)
}
