///|
test "OI directization preserves unchanged mixed structured bodies" {
  let bt = @lib.BlockType::void_()
  let leaf = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::drop(),
  ]
  let original = [
    @lib.Instruction::block(bt, @lib.Expr::new(leaf)),
    @lib.Instruction::loop_(bt, @lib.Expr::new(leaf)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::if_(bt, leaf, Some(leaf)),
    @lib.Instruction::try_table(bt, [], @lib.Expr::new(leaf)),
  ]
  let (output, changed) = run_hot_pipeline_raw_optimize_instructions_directize_call_ref_body(
    original,
  )
  assert_false(changed)
  @debug.assert_eq(output, original)
  @debug.assert_eq(leaf, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::drop(),
  ])
}

///|
test "OI late directization keeps prefixes and owns changed output rows" {
  let target = @lib.FuncIdx::new(7U)
  let type_idx = @lib.TypeIdx::new(3U)
  let prefix = [
    @lib.Instruction::i32_const(@lib.I32(11)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
  ]
  let child = [
    @lib.Instruction::ref_func(target),
    @lib.Instruction::call_ref(type_idx),
  ]
  let original = prefix.copy()
  original.push(
    @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(child)),
  )
  original.push(@lib.Instruction::i32_const(@lib.I32(0)))
  original.push(@lib.Instruction::table_get(@lib.TableIdx::new(1U)))
  original.push(@lib.Instruction::return_call_ref(type_idx))
  let expected = prefix.copy()
  expected.push(
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::call(target)]),
    ),
  )
  expected.push(@lib.Instruction::i32_const(@lib.I32(0)))
  expected.push(
    @lib.Instruction::return_call_indirect(type_idx, @lib.TableIdx::new(1U)),
  )
  let saved = original.copy()
  let (output, changed) = run_hot_pipeline_raw_optimize_instructions_directize_call_ref_body(
    original,
  )
  assert_true(changed)
  @debug.assert_eq(output, expected)
  output[0] = @lib.Instruction::nop()
  @debug.assert_eq(original, saved)
  @debug.assert_eq(child, [
    @lib.Instruction::ref_func(target),
    @lib.Instruction::call_ref(type_idx),
  ])
  match output[2] {
    @lib.Instruction::Block(_, @lib.Expr(body)) =>
      body.push(@lib.Instruction::nop())
    _ => fail("expected rewritten child")
  }
  assert_eq(child.length(), 2)
  @debug.assert_eq(original, saved)
}

///|
test "OI late null trap retains preceding effects and discards only dead tail" {
  let prefix = [
    @lib.Instruction::i32_const(@lib.I32(19)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
  ]
  let original = prefix.copy()
  original.push(
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::any())),
  )
  original.push(@lib.Instruction::ref_as_non_null())
  original.push(@lib.Instruction::drop())
  original.push(@lib.Instruction::call(@lib.FuncIdx::new(9U)))
  let saved = original.copy()
  let (output, changed) = run_hot_pipeline_raw_optimize_instructions_directize_call_ref_body(
    original,
  )
  assert_true(changed)
  let expected = prefix.copy()
  expected.push(@lib.Instruction::unreachable_())
  @debug.assert_eq(output, expected)
  @debug.assert_eq(original, saved)
}
