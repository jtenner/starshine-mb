///|
fn dae_dropped_result_cleanup_reference(
  instrs : Array[@lib.Instruction],
  callee_abs : Int,
  stop_at_unreachable_root : Bool,
  preserve_uninhabitable_control? : Bool = false,
) -> (Array[@lib.Instruction], Int) {
  let out : Array[@lib.Instruction] = []
  let mut rewrites = 0
  let mut idx = 0
  while idx < instrs.length() {
    if stop_at_unreachable_root && dae_instr_is_unreachable_root(instrs[idx]) {
      out.push(@lib.Instruction::unreachable_())
      break
    }
    if idx + 1 < instrs.length() {
      match (instrs[idx], instrs[idx + 1]) {
        (@lib.Call(func_idx), @lib.Drop) if dae_func_idx_slot(func_idx) ==
          callee_abs => {
          out.push(instrs[idx])
          if preserve_uninhabitable_control {
            out.push(@lib.Instruction::unreachable_())
          }
          rewrites += 1
          idx += 2
          if preserve_uninhabitable_control {
            return (out, rewrites)
          }
          continue
        }
        _ => ()
      }
    }
    match instrs[idx] {
      @lib.Block(block_type, @lib.Expr(body)) => {
        let (rewritten, nested) = dae_dropped_result_cleanup_reference(
          body,
          callee_abs,
          stop_at_unreachable_root,
          preserve_uninhabitable_control~,
        )
        out.push(@lib.Instruction::block(block_type, @lib.Expr::new(rewritten)))
        rewrites += nested
      }
      @lib.Loop(block_type, @lib.Expr(body)) => {
        let (rewritten, nested) = dae_dropped_result_cleanup_reference(
          body,
          callee_abs,
          stop_at_unreachable_root,
          preserve_uninhabitable_control~,
        )
        out.push(@lib.Instruction::loop_(block_type, @lib.Expr::new(rewritten)))
        rewrites += nested
      }
      @lib.TryTable(block_type, catches, @lib.Expr(body)) => {
        let (rewritten, nested) = dae_dropped_result_cleanup_reference(
          body,
          callee_abs,
          stop_at_unreachable_root,
          preserve_uninhabitable_control~,
        )
        out.push(
          @lib.Instruction::try_table(
            block_type,
            catches,
            @lib.Expr::new(rewritten),
          ),
        )
        rewrites += nested
      }
      @lib.If(block_type, then_body, else_body) => {
        let (then_rewritten, then_nested) = dae_dropped_result_cleanup_reference(
          then_body,
          callee_abs,
          stop_at_unreachable_root,
          preserve_uninhabitable_control~,
        )
        rewrites += then_nested
        let rewritten_else = match else_body {
          Some(body) => {
            let (else_rewritten, else_nested) = dae_dropped_result_cleanup_reference(
              body,
              callee_abs,
              stop_at_unreachable_root,
              preserve_uninhabitable_control~,
            )
            rewrites += else_nested
            Some(else_rewritten)
          }
          None => None
        }
        out.push(
          @lib.Instruction::if_(block_type, then_rewritten, rewritten_else),
        )
      }
      _ => out.push(instrs[idx])
    }
    idx += 1
  }
  (out, rewrites)
}
