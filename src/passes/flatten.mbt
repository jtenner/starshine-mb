///|
pub fn flatten_summary() -> String {
  "Flatten structured block wrappers and stack results into Binaryen-style temporaries."
}

///|
fn flatten_instr_targets_current_label(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Instruction::Br(@lib.LabelIdx(raw))
    | @lib.Instruction::BrIf(@lib.LabelIdx(raw))
    | @lib.Instruction::BrOnNull(@lib.LabelIdx(raw))
    | @lib.Instruction::BrOnNonNull(@lib.LabelIdx(raw)) => raw == 0U
    @lib.Instruction::BrTable(labels, @lib.LabelIdx(default_raw)) => {
      if default_raw == 0U {
        return true
      }
      labels.any(fn(label) {
        let @lib.LabelIdx(raw) = label
        raw == 0U
      })
    }
    @lib.Instruction::Block(_, @lib.Expr(body))
    | @lib.Instruction::Loop(_, @lib.Expr(body))
    | @lib.Instruction::TryTable(_, _, @lib.Expr(body)) =>
      body.any(flatten_instr_targets_current_label)
    @lib.Instruction::If(_, then_body, else_body) => {
      if then_body.any(flatten_instr_targets_current_label) {
        return true
      }
      match else_body {
        Some(body) => body.any(flatten_instr_targets_current_label)
        None => false
      }
    }
    _ => false
  }
}

///|
fn flatten_instr_single_result_type(instr : @lib.Instruction) -> @lib.ValType? {
  match instr {
    @lib.Instruction::LocalGet(_)
    | @lib.Instruction::I32Const(_)
    | @lib.Instruction::I32Eqz
    | @lib.Instruction::I32Eq
    | @lib.Instruction::I32Ne
    | @lib.Instruction::I32LtS
    | @lib.Instruction::I32LtU
    | @lib.Instruction::I32GtS
    | @lib.Instruction::I32GtU
    | @lib.Instruction::I32LeS
    | @lib.Instruction::I32LeU
    | @lib.Instruction::I32GeS
    | @lib.Instruction::I32GeU
    | @lib.Instruction::I64Eqz
    | @lib.Instruction::I64Eq
    | @lib.Instruction::I64Ne
    | @lib.Instruction::I64LtS
    | @lib.Instruction::I64LtU
    | @lib.Instruction::I64GtS
    | @lib.Instruction::I64GtU
    | @lib.Instruction::I64LeS
    | @lib.Instruction::I64LeU
    | @lib.Instruction::I64GeS
    | @lib.Instruction::I64GeU
    | @lib.Instruction::F32Eq
    | @lib.Instruction::F32Ne
    | @lib.Instruction::F32Lt
    | @lib.Instruction::F32Gt
    | @lib.Instruction::F32Le
    | @lib.Instruction::F32Ge
    | @lib.Instruction::F64Eq
    | @lib.Instruction::F64Ne
    | @lib.Instruction::F64Lt
    | @lib.Instruction::F64Gt
    | @lib.Instruction::F64Le
    | @lib.Instruction::F64Ge
    | @lib.Instruction::I32Clz
    | @lib.Instruction::I32Ctz
    | @lib.Instruction::I32Popcnt
    | @lib.Instruction::I32Add
    | @lib.Instruction::I32Sub
    | @lib.Instruction::I32Mul
    | @lib.Instruction::I32DivS
    | @lib.Instruction::I32DivU
    | @lib.Instruction::I32RemS
    | @lib.Instruction::I32RemU
    | @lib.Instruction::I32And
    | @lib.Instruction::I32Or
    | @lib.Instruction::I32Xor
    | @lib.Instruction::I32Shl
    | @lib.Instruction::I32ShrS
    | @lib.Instruction::I32ShrU
    | @lib.Instruction::I32Rotl
    | @lib.Instruction::I32Rotr
    | @lib.Instruction::I32WrapI64
    | @lib.Instruction::I32TruncF32S
    | @lib.Instruction::I32TruncF32U
    | @lib.Instruction::I32TruncF64S
    | @lib.Instruction::I32TruncF64U
    | @lib.Instruction::I32ReinterpretF32
    | @lib.Instruction::I32Extend8S
    | @lib.Instruction::I32Extend16S
    | @lib.Instruction::I32TruncSatF32S
    | @lib.Instruction::I32TruncSatF32U
    | @lib.Instruction::I32TruncSatF64S
    | @lib.Instruction::I32TruncSatF64U
    | @lib.Instruction::RefIsNull
    | @lib.Instruction::RefEq
    | @lib.Instruction::I31GetS
    | @lib.Instruction::I31GetU => Some(@lib.ValType::i32())
    @lib.Instruction::I64Const(_)
    | @lib.Instruction::I64Clz
    | @lib.Instruction::I64Ctz
    | @lib.Instruction::I64Popcnt
    | @lib.Instruction::I64Add
    | @lib.Instruction::I64Sub
    | @lib.Instruction::I64Mul
    | @lib.Instruction::I64DivS
    | @lib.Instruction::I64DivU
    | @lib.Instruction::I64RemS
    | @lib.Instruction::I64RemU
    | @lib.Instruction::I64And
    | @lib.Instruction::I64Or
    | @lib.Instruction::I64Xor
    | @lib.Instruction::I64Shl
    | @lib.Instruction::I64ShrS
    | @lib.Instruction::I64ShrU
    | @lib.Instruction::I64Rotl
    | @lib.Instruction::I64Rotr
    | @lib.Instruction::I64ExtendI32S
    | @lib.Instruction::I64ExtendI32U
    | @lib.Instruction::I64TruncF32S
    | @lib.Instruction::I64TruncF32U
    | @lib.Instruction::I64TruncF64S
    | @lib.Instruction::I64TruncF64U
    | @lib.Instruction::I64ReinterpretF64
    | @lib.Instruction::I64Extend8S
    | @lib.Instruction::I64Extend16S
    | @lib.Instruction::I64Extend32S
    | @lib.Instruction::I64TruncSatF32S
    | @lib.Instruction::I64TruncSatF32U
    | @lib.Instruction::I64TruncSatF64S
    | @lib.Instruction::I64TruncSatF64U => Some(@lib.ValType::i64())
    @lib.Instruction::F32Const(_)
    | @lib.Instruction::F32Abs
    | @lib.Instruction::F32Neg
    | @lib.Instruction::F32Ceil
    | @lib.Instruction::F32Floor
    | @lib.Instruction::F32Trunc
    | @lib.Instruction::F32Nearest
    | @lib.Instruction::F32Sqrt
    | @lib.Instruction::F32Add
    | @lib.Instruction::F32Sub
    | @lib.Instruction::F32Mul
    | @lib.Instruction::F32Div
    | @lib.Instruction::F32Min
    | @lib.Instruction::F32Max
    | @lib.Instruction::F32Copysign
    | @lib.Instruction::F32ConvertI32S
    | @lib.Instruction::F32ConvertI32U
    | @lib.Instruction::F32ConvertI64S
    | @lib.Instruction::F32ConvertI64U
    | @lib.Instruction::F32DemoteF64
    | @lib.Instruction::F32ReinterpretI32 => Some(@lib.ValType::f32())
    @lib.Instruction::F64Const(_)
    | @lib.Instruction::F64Abs
    | @lib.Instruction::F64Neg
    | @lib.Instruction::F64Ceil
    | @lib.Instruction::F64Floor
    | @lib.Instruction::F64Trunc
    | @lib.Instruction::F64Nearest
    | @lib.Instruction::F64Sqrt
    | @lib.Instruction::F64Add
    | @lib.Instruction::F64Sub
    | @lib.Instruction::F64Mul
    | @lib.Instruction::F64Div
    | @lib.Instruction::F64Min
    | @lib.Instruction::F64Max
    | @lib.Instruction::F64Copysign
    | @lib.Instruction::F64ConvertI32S
    | @lib.Instruction::F64ConvertI32U
    | @lib.Instruction::F64ConvertI64S
    | @lib.Instruction::F64ConvertI64U
    | @lib.Instruction::F64PromoteF32
    | @lib.Instruction::F64ReinterpretI64 => Some(@lib.ValType::f64())
    _ => None
  }
}

///|
fn flatten_rewrite_instr(instr : @lib.Instruction) -> (@lib.Instruction, Bool) {
  (instr, false)
}

///|
fn flatten_rewrite_instrs(
  instrs : Array[@lib.Instruction],
  first_temp_idx : Int,
) -> (Array[@lib.Instruction], Array[@lib.ValType], Bool) {
  let out : Array[@lib.Instruction] = []
  let added_locals : Array[@lib.ValType] = []
  let mut changed = false
  for instr in instrs {
    let (current, current_changed) = flatten_rewrite_instr(instr)
    if current_changed {
      changed = true
    }
    match current {
      @lib.Instruction::Block(@lib.VoidBlockType, @lib.Expr(body)) =>
        if flatten_instr_targets_current_label(current) {
          out.push(current)
        } else {
          changed = true
          out.append(body)
        }
      @lib.Instruction::Drop =>
        match out.last() {
          Some(prev) =>
            match flatten_instr_single_result_type(prev) {
              Some(vt) => {
                let temp_idx = first_temp_idx + added_locals.length()
                added_locals.push(vt)
                out.push(
                  @lib.Instruction::local_set(
                    @lib.LocalIdx::new(temp_idx.reinterpret_as_uint()),
                  ),
                )
                out.push(
                  @lib.Instruction::local_get(
                    @lib.LocalIdx::new(temp_idx.reinterpret_as_uint()),
                  ),
                )
                out.push(current)
                changed = true
              }
              None => out.push(current)
            }
          None => out.push(current)
        }
      _ => out.push(current)
    }
  }
  (out, added_locals, changed)
}

///|
fn flatten_module_subtypes(mod_ : @lib.Module) -> Array[@lib.SubType] {
  let subtypes : Array[@lib.SubType] = []
  match mod_.type_sec {
    Some(@lib.TypeSec(rec_types)) =>
      for rec_type in rec_types {
        match rec_type {
          @lib.SingleRecType(subtype) => subtypes.push(subtype)
          @lib.GroupRecType(group) => subtypes.append(group)
        }
      }
    None => ()
  }
  subtypes
}

///|
fn flatten_params_for_type_idx(
  subtypes : Array[@lib.SubType],
  type_idx : @lib.TypeIdx,
) -> Int {
  let subtype = match type_idx {
    @lib.TypeIdx(type_pos) =>
      match subtypes.get(type_pos.reinterpret_as_int()) {
        Some(subtype) => subtype
        None => return 0
      }
    @lib.RecIdx(_) => return 0
  }
  match subtype.get_comptype() {
    @lib.FuncCompType(params, _) => params.length()
    _ => 0
  }
}

///|
pub fn flatten_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  let subtypes = flatten_module_subtypes(mod_)
  let defined_type_idxs = match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) => type_idxs
    None => []
  }
  let rewritten : Array[@lib.Func] = []
  let mut changed = false
  let mut func_pos = 0
  for func in funcs {
    let @lib.Func(locals, @lib.Expr(body)) = func
    let next_locals = locals.copy()
    let param_count = match defined_type_idxs.get(func_pos) {
      Some(type_idx) => flatten_params_for_type_idx(subtypes, type_idx)
      None => 0
    }
    func_pos += 1
    let first_temp_idx = param_count + next_locals.length()
    let (next_body, added_locals, func_changed) = flatten_rewrite_instrs(
      body, first_temp_idx,
    )
    if func_changed {
      changed = true
      next_locals.append_types(added_locals)
      rewritten.push(@lib.Func::new(next_locals, @lib.Expr::new(next_body)))
    } else {
      rewritten.push(func)
    }
  }
  if changed {
    mod_.with_code_sec(@lib.CodeSec::new(rewritten))
  } else {
    mod_
  }
}
