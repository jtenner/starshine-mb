///|
test "parity followup RSE remaps legacy try block and catch type indices" {
  let signature = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let old_type = @lib.TypeIdx::new(1U)
  let value = fn(n) {
    @lib.Instruction::block(
      @lib.BlockType::type_idx(old_type),
      @lib.Expr::new([@lib.Instruction::i32_const(n)]),
    )
  }
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([signature, signature]))
    .with_func_sec(@lib.FuncSec::new([old_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::try_(
              @lib.BlockType::type_idx(old_type),
              @lib.Expr::new([value(7)]),
              [@lib.LegacyCatch::all(@lib.Expr::new([value(9)]))],
            ),
          ]),
        ),
      ]),
    )
  assert_true(@validate.validate_module(input) is Ok(_))
  for public_dispatch in [false, true] {
    let output = if public_dispatch {
      run_hot_pipeline(input, HotPipelineOptions::new(), [
        "redundant-set-elimination",
      ]).unwrap()
    } else {
      rse_canonicalize_plain_signatures(input)
    }
    assert_eq(output.type_sec.unwrap().0.length(), 1)
    let @lib.Func(_, @lib.Expr(instrs)) = output.code_sec.unwrap().0[0]
    match instrs[0] {
      @lib.Try(bt, @lib.Expr(body), catches, delegate) => {
        assert_eq(bt, @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)))
        assert_eq(delegate, None)
        match body[0] {
          @lib.Block(bt, _) =>
            assert_eq(bt, @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)))
          _ => fail("expected result block")
        }
        match catches[0] {
          @lib.LegacyCatchAll(@lib.Expr(body)) =>
            match body[0] {
              @lib.Block(bt, _) =>
                assert_eq(bt, @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)))
              _ => fail("expected catch result block")
            }
          _ => fail("expected catch-all")
        }
      }
      _ => fail("expected legacy try")
    }
    assert_true(@validate.validate_module(output) is Ok(_))
  }
}
