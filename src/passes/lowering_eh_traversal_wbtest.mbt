///|
fn lowering_eh_count_opcode(expr : @lib.Expr, opcode : @lib.Instruction) -> Int {
  let @lib.Expr(instrs) = expr
  let mut count = 0
  for instr in instrs {
    if instr == opcode {
      count += 1
    }
    match instr {
      @lib.Block(_, body) | @lib.Loop(_, body) | @lib.TryTable(_, _, body) =>
        count += lowering_eh_count_opcode(body, opcode)
      @lib.If(_, then_body, else_body) => {
        count += lowering_eh_count_opcode(@lib.Expr::new(then_body), opcode)
        match else_body {
          Some(body) =>
            count += lowering_eh_count_opcode(@lib.Expr::new(body), opcode)
          None => ()
        }
      }
      @lib.Try(_, body, catches, _) => {
        count += lowering_eh_count_opcode(body, opcode)
        for catch_ in catches {
          let catch_body = match catch_ {
            @lib.LegacyCatch(_, catch_body) | @lib.LegacyCatchAll(catch_body) =>
              catch_body
          }
          count += lowering_eh_count_opcode(catch_body, opcode)
        }
      }
      _ => ()
    }
  }
  count
}

///|
test "I64ToI32Lowering traverses legacy try catches and try_table bodies" {
  let candidate = @lib.Instruction::i64_trunc_sat_f32s()
  let body = @lib.Expr::new([
    @lib.Instruction::try_(
      @lib.BlockType::void_(),
      @lib.Expr::new([candidate]),
      [
        @lib.LegacyCatch::tagged(
          @lib.TagIdx::new(0U),
          @lib.Expr::new([candidate]),
        ),
        @lib.LegacyCatch::all(@lib.Expr::new([candidate])),
      ],
    ),
    @lib.Instruction::try_table(
      @lib.BlockType::void_(),
      [],
      @lib.Expr::new([candidate]),
    ),
  ])
  assert_true(i64_lower_sat_expr_has_candidate(body))
  let changed = [false]
  let rewritten = i64_lower_sat_rewrite_expr(
    body,
    @lib.LocalIdx::new(0U),
    @lib.LocalIdx::new(1U),
    changed,
  )
  assert_true(changed[0])
  assert_eq(lowering_eh_count_opcode(rewritten, candidate), 0)
  assert_eq(
    lowering_eh_count_opcode(
      rewritten,
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    ),
    4,
  )
}

///|
test "IntrinsicLowering traverses legacy try catches and try_table bodies" {
  let target = @lib.FuncIdx::new(0U)
  let call = @lib.Instruction::call(target)
  let wrapped = fn() {
    [@lib.Instruction::ref_func(@lib.FuncIdx::new(1U)), call]
  }
  let body = @lib.Expr::new([
    @lib.Instruction::try_(@lib.BlockType::void_(), @lib.Expr::new(wrapped()), [
      @lib.LegacyCatch::tagged(@lib.TagIdx::new(0U), @lib.Expr::new(wrapped())),
      @lib.LegacyCatch::all(@lib.Expr::new(wrapped())),
    ]),
    @lib.Instruction::try_table(
      @lib.BlockType::void_(),
      [],
      @lib.Expr::new(wrapped()),
    ),
  ])
  let changed = [false]
  let rewritten = il_rewrite_expr(body, [true], [], changed)
  assert_true(changed[0])
  assert_eq(lowering_eh_count_opcode(rewritten, call), 0)
  assert_eq(
    lowering_eh_count_opcode(
      rewritten,
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    ),
    4,
  )
}
