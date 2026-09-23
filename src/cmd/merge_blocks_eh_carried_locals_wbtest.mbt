///|
fn cmd_merge_blocks_eh_carried_local_fixture(kind : String) -> @lib.Module {
  let protected_body = @lib.Expr::new([
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
  ])
  let eh = match kind {
    "try" =>
      @lib.Instruction::try_(
        @lib.BlockType::void_(),
        @lib.Expr::new([@lib.Instruction::throw_(@lib.TagIdx::new(0U))]),
        [@lib.LegacyCatch::all(protected_body)],
        delegate=None,
      )
    "try-table" =>
      @lib.Instruction::try_table(@lib.BlockType::void_(), [], protected_body)
    _ => abort("unknown command merge-blocks EH fixture kind: \{kind}")
  }
  let carried = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      eh,
      @lib.Instruction::drop(),
    ]),
  )
  @passes.pass_test_module_from_wat("(module (func (local i32)))")
  .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(@lib.TypeIdx::new(0U))]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([@lib.ValType::i32()]),
        @lib.Expr::new([carried]),
      ),
    ]),
  )
}

///|
fn cmd_merge_blocks_assert_eh_carried_local_block(
  output : @lib.Module,
  kind : String,
) -> Unit raise {
  let body = match output.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) => body
    _ => abort("expected one command merge-blocks EH fixture body")
  }
  match (kind, body) {
    (
      "try",
      [
        @lib.Block(
          _,
          @lib.Expr(
            [@lib.LocalGet(@lib.LocalIdx(0U)), @lib.Try(_, _, _, _), @lib.Drop]
          )
        ),
      ],
    ) => ()
    (
      "try-table",
      [
        @lib.Block(
          _,
          @lib.Expr(
            [
              @lib.LocalGet(@lib.LocalIdx(0U)),
              @lib.TryTable(_, [], _),
              @lib.Drop,
            ]
          )
        ),
      ],
    ) => ()
    _ =>
      fail(
        "expected command merge-blocks to preserve the \{kind} carried-local block, got \{body}",
      )
  }
}

///|
test "command merge-blocks preserves try and try-table carried-local blocks" {
  for kind in ["try", "try-table"] {
    let input = cmd_merge_blocks_eh_carried_local_fixture(kind)
    let output = cmd_deep_audit_run_module(input, "merge-blocks")
    match @validate.validate_module(output) {
      Ok(_) => ()
      Err(err) => fail("expected valid command \{kind} output, got \{err}")
    }
    cmd_merge_blocks_assert_eh_carried_local_block(output, kind)
  }
}
