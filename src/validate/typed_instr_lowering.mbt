///|
/// Lower typed bodies back to raw expressions while using the validation
/// environment to hoist type-index control parameters back onto the outer stack.
pub fn typed_instrs_to_expr_with_env(
  body : Array[TypedInstr],
  env : Env,
) -> Expr {
  let instrs : Array[Instruction] = []
  lower_typed_slice_with_env(body, env, instrs)
  Expr::new(instrs)
}

///|
fn lower_typed_slice_with_env(
  body : Array[TypedInstr],
  env : Env,
  out : Array[Instruction],
) -> Unit {
  for instr in body {
    lower_typed_instr_with_env(instr, env, out)
  }
}

///|
fn lower_typed_slice_from(
  body : Array[TypedInstr],
  env : Env,
  start : Int,
) -> Array[Instruction] {
  let out : Array[Instruction] = []
  let begin = if start > body.length() { body.length() } else { start }
  for i in begin..<body.length() {
    lower_typed_instr_with_env(body[i], env, out)
  }
  out
}

///|
fn hoist_control_inputs(
  body : Array[TypedInstr],
  env : Env,
  bt : BlockType,
  out : Array[Instruction],
) -> Int {
  let input_arity = block_type_inputs(bt, env)
  let prefix_len = if input_arity > body.length() {
    body.length()
  } else {
    input_arity
  }
  for i in 0..<prefix_len {
    lower_typed_instr_with_env(body[i], env, out)
  }
  prefix_len
}

///|
fn append_fallback_lowering(
  instr : TypedInstr,
  out : Array[Instruction],
) -> Unit {
  let Expr(raw) = @lib.typed_instrs_to_expr([instr])
  for raw_instr in raw {
    out.push(raw_instr)
  }
}

///|
fn lower_typed_instr_with_env(
  instr : TypedInstr,
  env : Env,
  out : Array[Instruction],
) -> Unit {
  match instr.kind {
    TypedInstrKind::TBlock(bt, body) => {
      let prefix_len = hoist_control_inputs(body, env, bt, out)
      out.push(
        Instruction::block(
          bt,
          Expr::new(lower_typed_slice_from(body, env, prefix_len)),
        ),
      )
    }
    TypedInstrKind::TLoop(bt, body) => {
      let prefix_len = hoist_control_inputs(body, env, bt, out)
      out.push(
        Instruction::loop_(
          bt,
          Expr::new(lower_typed_slice_from(body, env, prefix_len)),
        ),
      )
    }
    TypedInstrKind::TIf(bt, cond, then_branch, else_branch) => {
      let prefix_len = hoist_control_inputs(then_branch, env, bt, out)
      lower_typed_instr_with_env(cond, env, out)
      let lowered_then = lower_typed_slice_from(then_branch, env, prefix_len)
      let lowered_else = match else_branch {
        Some(else_body) =>
          Some(lower_typed_slice_from(else_body, env, prefix_len))
        None => None
      }
      out.push(Instruction::if_(bt, lowered_then, lowered_else))
    }
    TypedInstrKind::TTryTable(bt, catches, body) => {
      let prefix_len = hoist_control_inputs(body, env, bt, out)
      out.push(
        Instruction::try_table(
          bt,
          catches,
          Expr::new(lower_typed_slice_from(body, env, prefix_len)),
        ),
      )
    }
    TypedInstrKind::TDrop(child) => {
      lower_typed_instr_with_env(child, env, out)
      out.push(Instruction::drop())
    }
    TypedInstrKind::TLocalSet(idx, child) => {
      lower_typed_instr_with_env(child, env, out)
      out.push(Instruction::local_set(idx))
    }
    TypedInstrKind::TLocalTee(idx, child) => {
      lower_typed_instr_with_env(child, env, out)
      out.push(Instruction::local_tee(idx))
    }
    TypedInstrKind::TGlobalSet(idx, child) => {
      lower_typed_instr_with_env(child, env, out)
      out.push(Instruction::global_set(idx))
    }
    TypedInstrKind::TCall(func_idx, args) => {
      lower_typed_slice_with_env(args, env, out)
      out.push(Instruction::call(func_idx))
    }
    TypedInstrKind::TReturn(args) => {
      lower_typed_slice_with_env(args, env, out)
      out.push(Instruction::return_())
    }
    TypedInstrKind::TBr(label, values) => {
      lower_typed_slice_with_env(values, env, out)
      out.push(Instruction::br(label))
    }
    TypedInstrKind::TBrIf(label, cond, values) => {
      lower_typed_slice_with_env(values, env, out)
      lower_typed_instr_with_env(cond, env, out)
      out.push(Instruction::br_if(label))
    }
    _ => append_fallback_lowering(instr, out)
  }
}
