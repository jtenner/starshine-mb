///|
fn dfe_remap_before_instruction(
  instr : @lib.Instruction,
  remap : Array[UInt],
) -> @lib.Instruction {
  match instr {
    @lib.Block(block_type, expr) =>
      @lib.Instruction::block(block_type, dfe_remap_before_expr(expr, remap))
    @lib.Loop(block_type, expr) =>
      @lib.Instruction::loop_(block_type, dfe_remap_before_expr(expr, remap))
    @lib.If(block_type, then_body, else_body) => {
      let rewritten_then : Array[@lib.Instruction] = Array::new(
        capacity=then_body.length(),
      )
      for nested in then_body {
        rewritten_then.push(dfe_remap_before_instruction(nested, remap))
      }
      let rewritten_else = match else_body {
        Some(body) => {
          let rewritten : Array[@lib.Instruction] = Array::new(
            capacity=body.length(),
          )
          for nested in body {
            rewritten.push(dfe_remap_before_instruction(nested, remap))
          }
          Some(rewritten)
        }
        None => None
      }
      @lib.Instruction::if_(block_type, rewritten_then, rewritten_else)
    }
    @lib.Call(func_idx) =>
      @lib.Instruction::call(dfe_rewrite_func_idx(func_idx, remap))
    @lib.ReturnCall(func_idx) =>
      @lib.Instruction::return_call(dfe_rewrite_func_idx(func_idx, remap))
    @lib.TryTable(block_type, catches, body) =>
      @lib.Instruction::try_table(
        block_type,
        catches,
        dfe_remap_before_expr(body, remap),
      )
    @lib.RefFunc(func_idx) =>
      @lib.Instruction::ref_func(dfe_rewrite_func_idx(func_idx, remap))
    _ => instr
  }
}

///|
fn dfe_remap_before_expr(expr : @lib.Expr, remap : Array[UInt]) -> @lib.Expr {
  let @lib.Expr(instrs) = expr
  let rewritten : Array[@lib.Instruction] = Array::new(capacity=instrs.length())
  for instr in instrs {
    rewritten.push(dfe_remap_before_instruction(instr, remap))
  }
  @lib.Expr::new(rewritten)
}

///|
fn dfe_remap_before_func(func : @lib.Func, remap : Array[UInt]) -> @lib.Func {
  let @lib.Func(locals, body) = func
  @lib.Func::new(locals, dfe_remap_before_expr(body, remap))
}
