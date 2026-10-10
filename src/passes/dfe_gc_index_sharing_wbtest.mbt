///|
test "GC compaction shares immutable convergent type indices within one remap" {
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]))
    .with_func_sec(@lib.FuncSec::new([
      @lib.TypeIdx::new(3U), @lib.TypeIdx::new(3U),
    ]))
    .with_code_sec(@lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::void_(),
            @lib.Expr::new([
              @lib.Instruction::ref_null(@lib.HeapType::new(@lib.TypeIdx::new(1U))),
              @lib.Instruction::drop(),
            ]),
          ),
        ]),
      ),
      @lib.Func::new(
        @lib.Locals::new([
          @lib.LocalRun::new(
            1U,
            @lib.ValType::ref_type(@lib.RefType::new(
              true, @lib.HeapType::new(@lib.TypeIdx::new(2U)),
            )),
          ),
        ]),
        @lib.Expr::new([
          @lib.Instruction::ref_null(@lib.HeapType::new(@lib.TypeIdx::new(2U))),
          @lib.Instruction::drop(),
        ]),
      ),
    ]))
  let before = @binary.encode_module(input).unwrap()
  assert_true(@validate.validate_module(input) is Ok(_))
  let after = dfe_canonicalize_duplicate_simple_type_indices(input)
  assert_true(@validate.validate_module(after) is Ok(_))
  let funcs = after.code_sec.unwrap().0
  let @lib.Func(_, @lib.Expr(first_body)) = funcs[0]
  let @lib.Func(second_locals, @lib.Expr(second_body)) = funcs[1]
  let nested = match first_body[0] {
    @lib.Block(_, @lib.Expr([@lib.RefNull(@lib.HeapTypeRefType(true, false, @lib.HeapType(idx))), ..])) => idx
    _ => fail("expected nested concrete ref")
  }
  let body = match second_body[0] {
    @lib.RefNull(@lib.HeapTypeRefType(true, false, @lib.HeapType(idx))) => idx
    _ => fail("expected second concrete ref")
  }
  let local_idx = match second_locals.runs()[0].val_type() {
    @lib.RefTypeValType(@lib.HeapTypeRefType(true, false, @lib.HeapType(idx))) => idx
    _ => fail("expected nullable inexact local")
  }
  assert_eq(nested, @lib.TypeIdx::new(0U))
  assert_eq(body, nested)
  assert_eq(local_idx, nested)
  assert_true(physical_equal(nested, body))
  assert_true(physical_equal(nested, local_idx))
  assert_eq(@binary.encode_module(input).unwrap(), before)
}
