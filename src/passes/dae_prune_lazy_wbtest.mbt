///|
test "DAE type prune retains unchanged nested bodies and NaN leaf ownership" {
  let input = pass_test_module_from_wat(
    (
      #| (module
      #|   (type (func (result f64)))
      #|   (type (func (param i64)))
      #|   (func (type 0)
      #|     block (result f64)
      #|       loop (result f64) f64.const nan end
      #|     end))
    ),
  )
  let @lib.Func(_, @lib.Expr(before)) = input.code_sec.unwrap().0[0]
  let saved = @binary.encode_module(input).unwrap()
  let output = dae_prune_unused_simple_func_types(input)
  @validate.validate_module(output).unwrap()
  assert_eq(output.type_sec.unwrap().0.length(), 1)
  let @lib.Func(_, @lib.Expr(after)) = output.code_sec.unwrap().0[0]
  assert_true(physical_equal(after, before))
  assert_true(physical_equal(after[0], before[0]))
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE type prune changes indexed blocks while sharing unaffected siblings" {
  let input = pass_test_module_from_wat(
    (
      #| (module
      #|   (type (func (param i64)))
      #|   (type (func (result i32)))
      #|   (import "host" "mark" (func $mark (type 1)))
      #|   (func (type 1)
      #|     block (type 1) call $mark end drop
      #|     block (result i32) i32.const 7 end))
    ),
  )
  let @lib.Func(_, @lib.Expr(before)) = input.code_sec.unwrap().0[0]
  let saved = @binary.encode_module(input).unwrap()
  let output = dae_prune_unused_simple_func_types(input)
  @validate.validate_module(output).unwrap()
  let @lib.Func(_, @lib.Expr(after)) = output.code_sec.unwrap().0[0]
  assert_eq(output.func_sec.unwrap().0, [@lib.TypeIdx::new(0U)])
  match (before[0], after[0]) {
    (
      @lib.Block(_, @lib.Expr(before_body)),
      @lib.Block(@lib.TypeIdxBlockType(@lib.TypeIdx(0U)), @lib.Expr(after_body)),
    ) => {
      assert_true(physical_equal(before_body, after_body))
      assert_eq(after_body, [@lib.Instruction::call(@lib.FuncIdx::new(0U))])
    }
    _ => fail("expected remapped indexed block")
  }
  assert_true(physical_equal(before[2], after[2]))
  after[1] = @lib.Instruction::nop()
  assert_true(before[1] is @lib.Drop)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE type remap keeps exact nested catch labels and reference flags" {
  let old = @lib.TypeIdx::new(2U)
  let next = @lib.TypeIdx::new(1U)
  let old_heap = @lib.HeapType::new(old)
  let next_heap = @lib.HeapType::new(next)
  let old_ref = @lib.RefType::new(true, old_heap, exact=true)
  let next_ref = @lib.RefType::new(true, next_heap, exact=true)
  let tag = @lib.TagIdx::new(3U)
  let label = @lib.LabelIdx::new(4U)
  let catches = [@lib.Catch::new(tag, label)]
  let leaf = [@lib.Instruction::nop()]
  let handler = [@lib.Instruction::ref_null_type(old_ref)]
  let input = [
    @lib.Instruction::try_table(
      @lib.BlockType::type_idx(old),
      catches,
      @lib.Expr::new(leaf),
    ),
    @lib.Instruction::try_(
      @lib.BlockType::void_(),
      @lib.Expr::new(leaf),
      [
        @lib.LegacyCatch::tagged(tag, @lib.Expr::new(handler)),
        @lib.LegacyCatch::all(@lib.Expr::new(leaf)),
      ],
      delegate=Some(label),
    ),
    @lib.Instruction::select(types=Some([@lib.ValType::ref_type(old_ref)])),
    @lib.Instruction::ref_test_type(old_ref),
    @lib.Instruction::ref_cast_type(old_ref),
    @lib.Instruction::br_on_cast(
      label,
      true,
      old_heap,
      false,
      old_heap,
      target_exact=true,
    ),
    @lib.Instruction::br_on_cast_desc_eq(label, old_ref, old_ref),
    @lib.Instruction::call_indirect(old, @lib.TableIdx::new(5U)),
    @lib.Instruction::return_call_ref(old),
  ]
  let expected = [
    @lib.Instruction::try_table(
      @lib.BlockType::type_idx(next),
      catches,
      @lib.Expr::new(leaf),
    ),
    @lib.Instruction::try_(
      @lib.BlockType::void_(),
      @lib.Expr::new(leaf),
      [
        @lib.LegacyCatch::tagged(
          tag,
          @lib.Expr::new([@lib.Instruction::ref_null_type(next_ref)]),
        ),
        @lib.LegacyCatch::all(@lib.Expr::new(leaf)),
      ],
      delegate=Some(label),
    ),
    @lib.Instruction::select(types=Some([@lib.ValType::ref_type(next_ref)])),
    @lib.Instruction::ref_test_type(next_ref),
    @lib.Instruction::ref_cast_type(next_ref),
    @lib.Instruction::br_on_cast(
      label,
      true,
      next_heap,
      false,
      next_heap,
      target_exact=true,
    ),
    @lib.Instruction::br_on_cast_desc_eq(label, next_ref, next_ref),
    @lib.Instruction::call_indirect(next, @lib.TableIdx::new(5U)),
    @lib.Instruction::return_call_ref(next),
  ]
  let output = dae_rewrite_pruned_type_idx_instrs(input, [0, 1, 1])
  assert_eq(output, expected)
  match output[0] {
    @lib.TryTable(_, after_catches, @lib.Expr(after_body)) => {
      assert_true(physical_equal(after_catches, catches))
      assert_eq(after_catches, catches)
      assert_eq(after_body, leaf)
    }
    _ => fail("expected try_table")
  }
  match output[1] {
    @lib.Try(_, @lib.Expr(after_body), after_catches, after_delegate) => {
      assert_eq(after_body, leaf)
      assert_eq(after_delegate, Some(label))
      match after_catches[1] {
        @lib.LegacyCatchAll(@lib.Expr(after_catch)) =>
          assert_eq(after_catch, leaf)
        _ => fail("expected unchanged catch_all")
      }
    }
    _ => fail("expected legacy try")
  }
  assert_true(
    handler[0]
    is @lib.RefNull(
      @lib.HeapTypeRefType(true, true, @lib.HeapType(@lib.TypeIdx(2U)))
    ),
  )
}

///|
test "DAE unchanged reference and unsupported remap indices retain instruction identity" {
  let type_ = @lib.TypeIdx::new(2U)
  let ref_ = @lib.RefType::new(true, @lib.HeapType::new(type_), exact=true)
  let input = [
    @lib.Instruction::ref_null_type(ref_),
    @lib.Instruction::select(types=Some([@lib.ValType::ref_type(ref_)])),
    @lib.Instruction::call_ref(@lib.TypeIdx::rec(0U)),
    @lib.Instruction::return_call_ref(@lib.TypeIdx::new(99U)),
  ]
  // RecIdx, negative remap entries and out-of-range indices stay unchanged.
  assert_true(
    physical_equal(dae_rewrite_pruned_type_idx_instrs(input, [0, 1, -1]), input),
  )
}

///|
test "DAE unchanged typed if and exception children retain body and catch ownership" {
  let leaf = [@lib.Instruction::nop()]
  let catch_rows = [@lib.LegacyCatch::all(@lib.Expr::new(leaf))]
  let input = [
    @lib.Instruction::if_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [
        @lib.Instruction::try_table(
          @lib.BlockType::void_(),
          [],
          @lib.Expr::new(leaf),
        ),
      ],
      Some([
        @lib.Instruction::try_(
          @lib.BlockType::void_(),
          @lib.Expr::new(leaf),
          catch_rows,
        ),
      ]),
    ),
  ]
  let output = dae_rewrite_pruned_type_idx_instrs(input, [0])
  assert_true(physical_equal(output, input))
  match output[0] {
    @lib.If(_, _, Some([@lib.Try(_, _, after_catches, _)])) =>
      assert_true(physical_equal(after_catches, catch_rows))
    _ => fail("expected retained exception arm")
  }
}
