///|
test "local-subtyping prefilter detects only writes to ref body locals" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let mask = match
    ls_ref_body_local_mask(
      @lib.Locals::from_types([
        @lib.ValType::i32(),
        base_nullable,
        @lib.ValType::i64(),
      ]),
    ) {
    Some(mask) => mask
    None => fail("expected ref body local mask")
  }
  @debug.assert_eq(mask, [false, true, false])
  assert_false(
    ls_expr_writes_ref_body_local(
      @lib.Expr::new([
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::local_set(@lib.LocalIdx::new(2U))]),
        ),
      ]),
      2,
      mask,
    ),
  )
  assert_true(
    ls_expr_writes_ref_body_local(
      @lib.Expr::new([
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [@lib.Instruction::local_set(@lib.LocalIdx::new(3U))],
          Some([
            @lib.Instruction::try_table(
              @lib.BlockType::void_(),
              [],
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
              ]),
            ),
          ]),
        ),
      ]),
      2,
      mask,
    ),
  )
  match ls_ref_body_local_mask(@lib.Locals::from_types([@lib.ValType::i32()])) {
    Some(other) => fail("expected no ref body locals, got \{other}")
    None => ()
  }
}

///|
test "local-subtyping follows the validator abstract heap hierarchy" {
  assert_false(
    ls_abs_heap_is_subtype(@lib.AbsHeapType::func(), @lib.AbsHeapType::any()),
  )
  assert_false(
    ls_abs_heap_is_subtype(@lib.AbsHeapType::extern_(), @lib.AbsHeapType::any()),
  )
  assert_false(
    ls_abs_heap_is_subtype(@lib.AbsHeapType::no_func(), @lib.AbsHeapType::any()),
  )
  assert_true(
    ls_abs_heap_is_subtype(@lib.AbsHeapType::none(), @lib.AbsHeapType::i31()),
  )
  assert_true(
    ls_abs_heap_is_subtype(
      @lib.AbsHeapType::no_cont(),
      @lib.AbsHeapType::cont(),
    ),
  )
  assert_true(
    ls_abs_heap_is_subtype(
      @lib.AbsHeapType::string_(),
      @lib.AbsHeapType::extern_(),
    ),
  )
}
