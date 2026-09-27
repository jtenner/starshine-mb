///|
fn cl_copy_remap_instrs(
  instrs : Array[@lib.Instruction],
  old_to_new : Array[Int],
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    out.push(
      match instr {
        @lib.Block(block_type, @lib.Expr(body)) =>
          @lib.Instruction::block(
            block_type,
            @lib.Expr::new(cl_copy_remap_instrs(body, old_to_new)),
          )
        @lib.Loop(block_type, @lib.Expr(body)) =>
          @lib.Instruction::loop_(
            block_type,
            @lib.Expr::new(cl_copy_remap_instrs(body, old_to_new)),
          )
        @lib.If(block_type, then_body, else_body) =>
          @lib.Instruction::if_(
            block_type,
            cl_copy_remap_instrs(then_body, old_to_new),
            match else_body {
              Some(body) => Some(cl_copy_remap_instrs(body, old_to_new))
              None => None
            },
          )
        @lib.TryTable(block_type, catches, @lib.Expr(body)) =>
          @lib.Instruction::try_table(
            block_type,
            catches,
            @lib.Expr::new(cl_copy_remap_instrs(body, old_to_new)),
          )
        @lib.LocalGet(idx) =>
          @lib.Instruction::local_get(cl_rewrite_local_idx(idx, old_to_new))
        @lib.LocalSet(idx) =>
          @lib.Instruction::local_set(cl_rewrite_local_idx(idx, old_to_new))
        @lib.LocalTee(idx) =>
          @lib.Instruction::local_tee(cl_rewrite_local_idx(idx, old_to_new))
        @lib.Try(bt, @lib.Expr(body), catches, delegate) =>
          @lib.Instruction::try_(
            bt,
            @lib.Expr::new(cl_copy_remap_instrs(body, old_to_new)),
            catches.map(fn(catch_) {
              match catch_ {
                @lib.LegacyCatch(tag, @lib.Expr(body)) =>
                  @lib.LegacyCatch::tagged(
                    tag,
                    @lib.Expr::new(cl_copy_remap_instrs(body, old_to_new)),
                  )
                @lib.LegacyCatchAll(@lib.Expr(body)) =>
                  @lib.LegacyCatch::all(
                    @lib.Expr::new(cl_copy_remap_instrs(body, old_to_new)),
                  )
              }
            }),
            delegate~,
          )
        other => other
      },
    )
  }
  out
}
