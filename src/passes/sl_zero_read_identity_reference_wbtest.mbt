///|
fn sl_zero_read_before_identity(
  body : Array[@lib.Instruction],
  counts : Array[Int],
) -> Array[@lib.Instruction] {
  let rewritten : Array[@lib.Instruction] = []
  for instr in body {
    rewritten.push(
      match instr {
        @lib.LocalSet(@lib.LocalIdx(raw)) => {
          let idx = raw.reinterpret_as_int()
          if idx >= 0 && idx < counts.length() && counts[idx] == 0 {
            @lib.Instruction::drop()
          } else {
            instr
          }
        }
        @lib.Block(block_type, @lib.Expr(nested)) =>
          @lib.Instruction::block(
            block_type,
            @lib.Expr::new(sl_zero_read_before_identity(nested, counts)),
          )
        @lib.Loop(block_type, @lib.Expr(nested)) =>
          @lib.Instruction::loop_(
            block_type,
            @lib.Expr::new(sl_zero_read_before_identity(nested, counts)),
          )
        @lib.If(block_type, then_body, else_body) =>
          @lib.Instruction::if_(
            block_type,
            sl_zero_read_before_identity(then_body, counts),
            match else_body {
              Some(else_body) =>
                Some(sl_zero_read_before_identity(else_body, counts))
              None => None
            },
          )
        @lib.TryTable(block_type, catches, @lib.Expr(nested)) =>
          @lib.Instruction::try_table(
            block_type,
            catches,
            @lib.Expr::new(sl_zero_read_before_identity(nested, counts)),
          )
        _ => instr
      },
    )
  }
  rewritten
}
