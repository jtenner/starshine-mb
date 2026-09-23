///|
fn i64_lower_sat_float_const(is_f32 : Bool, value : Double) -> @lib.Instruction {
  if is_f32 {
    @lib.Instruction::f32_const(@lib.F32(Float::from_double(value)))
  } else {
    @lib.Instruction::f64_const(@lib.F64(value))
  }
}

///|
fn i64_lower_sat_local_get(local_idx : @lib.LocalIdx) -> @lib.Instruction {
  @lib.Instruction::local_get(local_idx)
}

///|
fn i64_lower_sat_sequence(
  is_f32 : Bool,
  signed : Bool,
  local_idx : @lib.LocalIdx,
) -> Array[@lib.Instruction] {
  let upper = if signed {
    9223372036854775808.0
  } else {
    18446744073709551616.0
  }
  let lower = if signed { -9223372036854775808.0 } else { 0.0 }
  let upper_result = if signed {
    @lib.I64(9223372036854775807L)
  } else {
    @lib.I64(-1L)
  }
  let lower_result = if signed {
    @lib.I64(-9223372036854775808L)
  } else {
    @lib.I64(0L)
  }
  let ne = if is_f32 {
    @lib.Instruction::f32_ne()
  } else {
    @lib.Instruction::f64_ne()
  }
  let ge = if is_f32 {
    @lib.Instruction::f32_ge()
  } else {
    @lib.Instruction::f64_ge()
  }
  let le = if is_f32 {
    @lib.Instruction::f32_le()
  } else {
    @lib.Instruction::f64_le()
  }
  let convert = match (is_f32, signed) {
    (true, true) => @lib.Instruction::i64_trunc_f32s()
    (true, false) => @lib.Instruction::i64_trunc_f32u()
    (false, true) => @lib.Instruction::i64_trunc_f64s()
    (false, false) => @lib.Instruction::i64_trunc_f64u()
  }
  let result_type = @lib.BlockType::val_type(@lib.ValType::i64())
  let lower_check : Array[@lib.Instruction] = [
    i64_lower_sat_local_get(local_idx),
    i64_lower_sat_float_const(is_f32, lower),
    le,
    @lib.Instruction::if_(
      result_type,
      [@lib.Instruction::i64_const(lower_result)],
      Some([i64_lower_sat_local_get(local_idx), convert]),
    ),
  ]
  let upper_check : Array[@lib.Instruction] = [
    i64_lower_sat_local_get(local_idx),
    i64_lower_sat_float_const(is_f32, upper),
    ge,
    @lib.Instruction::if_(
      result_type,
      [@lib.Instruction::i64_const(upper_result)],
      Some(lower_check),
    ),
  ]
  [
    @lib.Instruction::local_set(local_idx),
    i64_lower_sat_local_get(local_idx),
    i64_lower_sat_local_get(local_idx),
    ne,
    @lib.Instruction::if_(
      result_type,
      [@lib.Instruction::i64_const(@lib.I64(0L))],
      Some(upper_check),
    ),
  ]
}

///|
fn i64_lower_sat_rewrite_expr(
  expr : @lib.Expr,
  f32_temp : @lib.LocalIdx,
  f64_temp : @lib.LocalIdx,
  changed : Array[Bool],
) -> @lib.Expr {
  let @lib.Expr(instrs) = expr
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    match instr {
      @lib.I64TruncSatF32S => {
        out.append(i64_lower_sat_sequence(true, true, f32_temp))
        changed[0] = true
      }
      @lib.I64TruncSatF32U => {
        out.append(i64_lower_sat_sequence(true, false, f32_temp))
        changed[0] = true
      }
      @lib.I64TruncSatF64S => {
        out.append(i64_lower_sat_sequence(false, true, f64_temp))
        changed[0] = true
      }
      @lib.I64TruncSatF64U => {
        out.append(i64_lower_sat_sequence(false, false, f64_temp))
        changed[0] = true
      }
      @lib.Block(block_type, nested) =>
        out.push(
          @lib.Instruction::block(
            block_type,
            i64_lower_sat_rewrite_expr(nested, f32_temp, f64_temp, changed),
          ),
        )
      @lib.Loop(block_type, nested) =>
        out.push(
          @lib.Instruction::loop_(
            block_type,
            i64_lower_sat_rewrite_expr(nested, f32_temp, f64_temp, changed),
          ),
        )
      @lib.If(block_type, then_body, else_body) => {
        let @lib.Expr(next_then) = i64_lower_sat_rewrite_expr(
          @lib.Expr::new(then_body),
          f32_temp,
          f64_temp,
          changed,
        )
        let next_else = match else_body {
          Some(body) => {
            let @lib.Expr(next_body) = i64_lower_sat_rewrite_expr(
              @lib.Expr::new(body),
              f32_temp,
              f64_temp,
              changed,
            )
            Some(next_body)
          }
          None => None
        }
        out.push(@lib.Instruction::if_(block_type, next_then, next_else))
      }
      _ => out.push(instr)
    }
  }
  @lib.Expr::new(out)
}

///|
fn i64_to_i32_lowering_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  let type_indices = match mod_.func_sec {
    Some(@lib.FuncSec(type_indices)) => type_indices
    None => return mod_
  }
  if type_indices.length() != funcs.length() {
    return mod_
  }
  let signatures = msf_build_type_signature_cache(mod_)
  let changed = [false]
  let rewritten : Array[@lib.Func] = []
  for index, func in funcs {
    let @lib.Func(locals, body) = func
    let params = match msf_cached_signature(signatures, type_indices[index]) {
      Some(@lib.FuncType(params, _)) => params
      None => return mod_
    }
    let f32_index = params.length() + locals.length()
    let f64_index = f32_index + 1
    let f32_temp = @lib.LocalIdx::new(f32_index.to_uint())
    let f64_temp = @lib.LocalIdx::new(f64_index.to_uint())
    let func_changed = [false]
    let next_body = i64_lower_sat_rewrite_expr(
      body, f32_temp, f64_temp, func_changed,
    )
    if func_changed[0] {
      changed[0] = true
      let next_locals = locals.copy()
      next_locals.push(@lib.ValType::f32())
      next_locals.push(@lib.ValType::f64())
      rewritten.push(@lib.Func::new(next_locals, next_body))
    } else {
      rewritten.push(func)
    }
  }
  if !changed[0] {
    return mod_
  }
  let candidate = mod_.with_code_sec(@lib.CodeSec::new(rewritten))
  if @validate.validate_module(candidate).is_ok() {
    candidate
  } else {
    mod_
  }
}
