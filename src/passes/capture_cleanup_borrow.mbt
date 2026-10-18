///|
// Intermediate capture bodies are read-only until the final remapping walk.
fn pass_lower_map_children_borrow_unchanged(
  instr : @lib.Instruction,
  transform : (Array[@lib.Instruction]) -> Array[@lib.Instruction],
) -> @lib.Instruction {
  match instr {
    @lib.Block(bt, @lib.Expr(body)) => {
      let next = transform(body)
      if physical_equal(next, body) {
        instr
      } else {
        @lib.Instruction::block(bt, @lib.Expr::new(next))
      }
    }
    @lib.Loop(bt, @lib.Expr(body)) => {
      let next = transform(body)
      if physical_equal(next, body) {
        instr
      } else {
        @lib.Instruction::loop_(bt, @lib.Expr::new(next))
      }
    }
    @lib.TryTable(bt, catches, @lib.Expr(body)) => {
      let next = transform(body)
      if physical_equal(next, body) {
        instr
      } else {
        @lib.Instruction::try_table(bt, catches, @lib.Expr::new(next))
      }
    }
    @lib.If(bt, yes, no) => {
      let next_yes = transform(yes)
      let next_no = match no {
        Some(body) => {
          let next = transform(body)
          if physical_equal(next, body) {
            no
          } else {
            Some(next)
          }
        }
        None => None
      }
      if physical_equal(next_yes, yes) && physical_equal(next_no, no) {
        instr
      } else {
        @lib.Instruction::if_(bt, next_yes, next_no)
      }
    }
    @lib.Try(bt, @lib.Expr(body), catches, delegate) => {
      let next_body = transform(body)
      let mut next_catches = catches
      for index, catch_ in catches {
        let catch_body = match catch_ {
          @lib.LegacyCatch(_, @lib.Expr(body))
          | @lib.LegacyCatchAll(@lib.Expr(body)) => body
        }
        let next = transform(catch_body)
        if !physical_equal(next, catch_body) {
          if physical_equal(next_catches, catches) {
            next_catches = catches.copy()
          }
          next_catches[index] = match catch_ {
            @lib.LegacyCatch(tag, _) =>
              @lib.LegacyCatch::tagged(tag, @lib.Expr::new(next))
            @lib.LegacyCatchAll(_) =>
              @lib.LegacyCatch::all(@lib.Expr::new(next))
          }
        }
      }
      if physical_equal(next_body, body) &&
        physical_equal(next_catches, catches) {
        instr
      } else {
        @lib.Instruction::try_(
          bt,
          @lib.Expr::new(next_body),
          next_catches,
          delegate~,
        )
      }
    }
    _ => instr
  }
}
