///|
pub fn global_struct_inference_summary() -> String {
  "Fold immutable struct field reads from closed-world global instances when their values are globally fixed."
}

///|
fn gsi_type_slot(type_idx : @lib.TypeIdx, type_count : Int) -> Int {
  match type_idx {
    @lib.TypeIdx(idx) => {
      let slot = idx.reinterpret_as_int()
      if slot < 0 || slot >= type_count {
        -1
      } else {
        slot
      }
    }
    @lib.RecIdx(_) => -1
  }
}

///|
fn gsi_default_expr_for_valtype(vt : @lib.ValType) -> @lib.Expr? {
  match vt {
    @lib.NumTypeValType(@lib.I32NumType) =>
      Some(@lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(0))]))
    @lib.NumTypeValType(@lib.I64NumType) =>
      Some(@lib.Expr::new([@lib.Instruction::i64_const(@lib.I64::new(0L))]))
    @lib.NumTypeValType(@lib.F32NumType) =>
      Some(@lib.Expr::new([@lib.Instruction::f32_const(@lib.F32::new(0.0))]))
    @lib.NumTypeValType(@lib.F64NumType) =>
      Some(@lib.Expr::new([@lib.Instruction::f64_const(@lib.F64::new(0.0))]))
    @lib.VecTypeValType =>
      Some(
        @lib.Expr::new([
          @lib.Instruction::v128_const(
            b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
            b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
          ),
        ]),
      )
    @lib.RefTypeValType(ref_type) =>
      if ref_type.is_nullable() {
        Some(@lib.Expr::new([@lib.Instruction::ref_null_type(ref_type)]))
      } else {
        None
      }
    @lib.BotValType => None
  }
}

///|
fn gsi_simple_instr_result_type(
  env : @validate.Env,
  instr : @lib.Instruction,
) -> @lib.ValType? {
  match instr {
    @lib.I32Const(_) => Some(@lib.ValType::i32())
    @lib.I64Const(_) => Some(@lib.ValType::i64())
    @lib.F32Const(_) => Some(@lib.ValType::f32())
    @lib.F64Const(_) => Some(@lib.ValType::f64())
    @lib.V128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
      Some(@lib.ValType::v128())
    @lib.RefNull(ref_type) => Some(@lib.ValType::ref_null_type(ref_type))
    @lib.RefFunc(func_idx) =>
      match env.get_functypeidx_by_funcidx(func_idx) {
        Some(type_idx) =>
          Some(
            @lib.ValType::ref_type(
              @lib.RefType::new(false, @lib.HeapType::new(type_idx)),
            ),
          )
        None => None
      }
    @lib.GlobalGet(global_idx) =>
      match env.get_global_type(global_idx) {
        Some(@lib.GlobalType(value_type, _)) => Some(value_type)
        None => None
      }
    @lib.StringConst(_) => Some(@lib.ValType::stringref())
    _ => None
  }
}

///|
fn gsi_const_expr_for_field(
  env : @validate.Env,
  field_type : @lib.FieldType,
  instr : @lib.Instruction,
) -> @lib.Expr? {
  match field_type.get_storage_type() {
    @lib.PackTypeStorageType(_) =>
      match instr {
        @lib.I32Const(_) => Some(@lib.Expr::new([instr]))
        _ => None
      }
    @lib.ValTypeStorageType(value_type) =>
      match gsi_simple_instr_result_type(env, instr) {
        Some(instr_type) =>
          if @validate.Match::matches(instr_type, value_type, env) {
            Some(@lib.Expr::new([instr]))
          } else {
            None
          }
        None => None
      }
  }
}

///|
fn gsi_candidate_field_values(
  env : @validate.Env,
  instrs : Array[@lib.Instruction],
  type_idx : @lib.TypeIdx,
  desc_operands : Int,
  defaults_only : Bool,
) -> Array[@lib.Expr?]? {
  let fields = match env.resolve_struct_fields(type_idx) {
    Ok(fields) => fields
    Err(_) => return None
  }
  let values : Array[@lib.Expr?] = Array::make(fields.length(), None)
  if defaults_only {
    if instrs.length() != desc_operands + 1 {
      return Some(values)
    }
    for idx = 0; idx < fields.length(); idx = idx + 1 {
      if fields[idx].is_mutable() {
        continue
      }
      values[idx] = gsi_default_expr_for_valtype(fields[idx].unpack())
    }
    return Some(values)
  }
  if instrs.length() != desc_operands + fields.length() + 1 {
    return Some(values)
  }
  for idx = 0; idx < fields.length(); idx = idx + 1 {
    if fields[idx].is_mutable() {
      continue
    }
    values[idx] = gsi_const_expr_for_field(
      env,
      fields[idx],
      instrs[desc_operands + idx],
    )
  }
  Some(values)
}

///|
fn gsi_candidate_global_values(
  env : @validate.Env,
  expr : @lib.Expr,
) -> (@lib.TypeIdx, Array[@lib.Expr?])? {
  let @lib.Expr(instrs) = expr
  if instrs.length() == 0 {
    return None
  }
  match instrs[instrs.length() - 1] {
    @lib.StructNew(type_idx) =>
      gsi_candidate_field_values(env, instrs, type_idx, 0, false).map(fn(
        values,
      ) {
        (type_idx, values)
      })
    @lib.StructNewDefault(type_idx) =>
      gsi_candidate_field_values(env, instrs, type_idx, 0, true).map(fn(
        values,
      ) {
        (type_idx, values)
      })
    @lib.StructNewDesc(type_idx) =>
      gsi_candidate_field_values(env, instrs, type_idx, 1, false).map(fn(
        values,
      ) {
        (type_idx, values)
      })
    @lib.StructNewDefaultDesc(type_idx) =>
      gsi_candidate_field_values(env, instrs, type_idx, 1, true).map(fn(
        values,
      ) {
        (type_idx, values)
      })
    _ => None
  }
}

///|
fn gsi_merge_field_values(
  current : Array[@lib.Expr?],
  next : Array[@lib.Expr?],
) -> Unit {
  let limit = if current.length() < next.length() {
    current.length()
  } else {
    next.length()
  }
  for idx = 0; idx < limit; idx = idx + 1 {
    match (current[idx], next[idx]) {
      (Some(left), Some(right)) if left == right => ()
      _ => current[idx] = None
    }
  }
}

///|
fn gsi_mark_type_subtypes(
  env : @validate.Env,
  has_subtypes : Array[Bool],
) -> Unit {
  for subtype_idx = 0
      subtype_idx < env.global_types.length()
      subtype_idx = subtype_idx + 1 {
    for super_type in env.global_types[subtype_idx].super_types() {
      let slot = gsi_type_slot(super_type, has_subtypes.length())
      if slot >= 0 {
        has_subtypes[slot] = true
      }
    }
  }
}

///|
fn gsi_scan_struct_allocations(
  instrs : Array[@lib.Instruction],
  candidate_types : Array[Bool],
  blocked_types : Array[Bool],
  ignored_top_level_slot? : Int = -1,
) -> Unit {
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    let instr = instrs[idx]
    let type_slot = match instr {
      @lib.StructNew(type_idx)
      | @lib.StructNewDefault(type_idx)
      | @lib.StructNewDesc(type_idx)
      | @lib.StructNewDefaultDesc(type_idx) =>
        gsi_type_slot(type_idx, candidate_types.length())
      _ => -1
    }
    if type_slot >= 0 &&
      candidate_types[type_slot] &&
      !(idx == instrs.length() - 1 && type_slot == ignored_top_level_slot) {
      blocked_types[type_slot] = true
    }
    match instr {
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        gsi_scan_struct_allocations(body, candidate_types, blocked_types)
      @lib.If(_, then_body, else_body) => {
        gsi_scan_struct_allocations(then_body, candidate_types, blocked_types)
        match else_body {
          Some(else_body) =>
            gsi_scan_struct_allocations(
              else_body, candidate_types, blocked_types,
            )
          None => ()
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        gsi_scan_struct_allocations(body, candidate_types, blocked_types)
      _ => ()
    }
  }
}

///|
fn gsi_pack_unsigned(value : Int, bits : Int) -> Int {
  let mask = if bits == 8 { 0xFF } else { 0xFFFF }
  value & mask
}

///|
fn gsi_pack_signed(value : Int, bits : Int) -> Int {
  let masked = gsi_pack_unsigned(value, bits)
  let sign_bit = 1 << (bits - 1)
  if (masked & sign_bit) != 0 {
    masked - (1 << bits)
  } else {
    masked
  }
}

///|
fn gsi_packed_expr(expr : @lib.Expr, bits : Int, signed : Bool) -> @lib.Expr? {
  match expr {
    @lib.Expr([@lib.I32Const(@lib.I32(value))]) =>
      Some(
        @lib.Expr::new([
          @lib.Instruction::i32_const(
            @lib.I32::new(
              if signed {
                gsi_pack_signed(value, bits)
              } else {
                gsi_pack_unsigned(value, bits)
              },
            ),
          ),
        ]),
      )
    _ => None
  }
}

///|
fn gsi_folded_field_expr(
  fields_by_type : Array[Array[@lib.FieldType]?],
  values_by_type : Array[Array[@lib.Expr?]?],
  blocked_types : Array[Bool],
  type_idx : @lib.TypeIdx,
  field_idx : @lib.U32,
  signed : Bool,
  unsigned : Bool,
) -> @lib.Expr? {
  let slot = gsi_type_slot(type_idx, blocked_types.length())
  if slot < 0 || blocked_types[slot] {
    return None
  }
  let fields = match fields_by_type[slot] {
    Some(fields) => fields
    None => return None
  }
  let values = match values_by_type[slot] {
    Some(values) => values
    None => return None
  }
  let @lib.U32(raw_idx) = field_idx
  let idx = raw_idx.reinterpret_as_int()
  if idx < 0 || idx >= fields.length() || idx >= values.length() {
    return None
  }
  let value = match values[idx] {
    Some(value) => value
    None => return None
  }
  match fields[idx].get_storage_type() {
    @lib.ValTypeStorageType(_) => Some(value)
    @lib.PackTypeStorageType(@lib.I8PackType) =>
      if signed {
        gsi_packed_expr(value, 8, true)
      } else if unsigned {
        gsi_packed_expr(value, 8, false)
      } else {
        None
      }
    @lib.PackTypeStorageType(@lib.I16PackType) =>
      if signed {
        gsi_packed_expr(value, 16, true)
      } else if unsigned {
        gsi_packed_expr(value, 16, false)
      } else {
        None
      }
  }
}

///|
fn gsi_folded_field_result_type(
  fields_by_type : Array[Array[@lib.FieldType]?],
  blocked_types : Array[Bool],
  type_idx : @lib.TypeIdx,
  field_idx : @lib.U32,
  signed : Bool,
  unsigned : Bool,
) -> @lib.ValType? {
  let slot = gsi_type_slot(type_idx, blocked_types.length())
  if slot < 0 || blocked_types[slot] {
    return None
  }
  let fields = match fields_by_type[slot] {
    Some(fields) => fields
    None => return None
  }
  let @lib.U32(raw_idx) = field_idx
  let idx = raw_idx.reinterpret_as_int()
  if idx < 0 || idx >= fields.length() {
    return None
  }
  match fields[idx].get_storage_type() {
    @lib.ValTypeStorageType(value_type) => Some(value_type)
    @lib.PackTypeStorageType(_) =>
      if signed || unsigned {
        Some(@lib.ValType::i32())
      } else {
        None
      }
  }
}

///|
fn gsi_append_expr_instrs(
  out : Array[@lib.Instruction],
  expr : @lib.Expr,
) -> Unit {
  let @lib.Expr(instrs) = expr
  for instr in instrs {
    out.push(instr)
  }
}

///|
fn gsi_global_ref_type(
  env : @validate.Env,
  global_idx : @lib.GlobalIdx,
) -> @lib.RefType? {
  match env.get_global_type(global_idx) {
    Some(@lib.GlobalType(@lib.RefTypeValType(ref_type), _)) => Some(ref_type)
    _ => None
  }
}

///|
fn gsi_folded_global_field_expr(
  fields_by_type : Array[Array[@lib.FieldType]?],
  global_values_by_abs_idx : Array[Array[@lib.Expr?]?],
  global_type_slots : Array[Int],
  global_idx : @lib.GlobalIdx,
  type_idx : @lib.TypeIdx,
  field_idx : @lib.U32,
  signed : Bool,
  unsigned : Bool,
) -> @lib.Expr? {
  let @lib.GlobalIdx(abs_idx_u) = global_idx
  let abs_idx = abs_idx_u.reinterpret_as_int()
  if abs_idx < 0 ||
    abs_idx >= global_values_by_abs_idx.length() ||
    abs_idx >= global_type_slots.length() {
    return None
  }
  let type_slot = gsi_type_slot(type_idx, fields_by_type.length())
  if type_slot < 0 || global_type_slots[abs_idx] != type_slot {
    return None
  }
  let fields = match fields_by_type[type_slot] {
    Some(fields) => fields
    None => return None
  }
  let values = match global_values_by_abs_idx[abs_idx] {
    Some(values) => values
    None => return None
  }
  let @lib.U32(raw_idx) = field_idx
  let idx = raw_idx.reinterpret_as_int()
  if idx < 0 || idx >= fields.length() || idx >= values.length() {
    return None
  }
  let value = match values[idx] {
    Some(value) => value
    None => return None
  }
  match fields[idx].get_storage_type() {
    @lib.ValTypeStorageType(_) => Some(value)
    @lib.PackTypeStorageType(@lib.I8PackType) =>
      if signed {
        gsi_packed_expr(value, 8, true)
      } else if unsigned {
        gsi_packed_expr(value, 8, false)
      } else {
        None
      }
    @lib.PackTypeStorageType(@lib.I16PackType) =>
      if signed {
        gsi_packed_expr(value, 16, true)
      } else if unsigned {
        gsi_packed_expr(value, 16, false)
      } else {
        None
      }
  }
}

///|
fn gsi_rewrite_instrs(
  instrs : Array[@lib.Instruction],
  env : @validate.Env,
  fields_by_type : Array[Array[@lib.FieldType]?],
  global_values_by_abs_idx : Array[Array[@lib.Expr?]?],
  global_type_slots : Array[Int],
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  let mut idx = 0
  while idx < instrs.length() {
    let instr = instrs[idx]
    match instr {
      @lib.Block(block_type, @lib.Expr(body)) =>
        out.push(
          @lib.Instruction::block(
            block_type,
            @lib.Expr::new(
              gsi_rewrite_instrs(
                body, env, fields_by_type, global_values_by_abs_idx, global_type_slots,
              ),
            ),
          ),
        )
      @lib.Loop(block_type, @lib.Expr(body)) =>
        out.push(
          @lib.Instruction::loop_(
            block_type,
            @lib.Expr::new(
              gsi_rewrite_instrs(
                body, env, fields_by_type, global_values_by_abs_idx, global_type_slots,
              ),
            ),
          ),
        )
      @lib.If(block_type, then_body, else_body) =>
        out.push(
          @lib.Instruction::if_(
            block_type,
            gsi_rewrite_instrs(
              then_body, env, fields_by_type, global_values_by_abs_idx, global_type_slots,
            ),
            else_body.map(fn(body) {
              gsi_rewrite_instrs(
                body, env, fields_by_type, global_values_by_abs_idx, global_type_slots,
              )
            }),
          ),
        )
      @lib.TryTable(block_type, catches, @lib.Expr(body)) =>
        out.push(
          @lib.Instruction::try_table(
            block_type,
            catches,
            @lib.Expr::new(
              gsi_rewrite_instrs(
                body, env, fields_by_type, global_values_by_abs_idx, global_type_slots,
              ),
            ),
          ),
        )
      @lib.GlobalGet(global_idx) =>
        if idx + 1 < instrs.length() {
          let next_instr = instrs[idx + 1]
          let folded = match next_instr {
            @lib.StructGet(type_idx, field_idx) =>
              gsi_folded_global_field_expr(
                fields_by_type, global_values_by_abs_idx, global_type_slots, global_idx,
                type_idx, field_idx, false, false,
              )
            @lib.StructGetS(type_idx, field_idx) =>
              gsi_folded_global_field_expr(
                fields_by_type, global_values_by_abs_idx, global_type_slots, global_idx,
                type_idx, field_idx, true, false,
              )
            @lib.StructGetU(type_idx, field_idx) =>
              gsi_folded_global_field_expr(
                fields_by_type, global_values_by_abs_idx, global_type_slots, global_idx,
                type_idx, field_idx, false, true,
              )
            _ => None
          }
          match folded {
            Some(value) => {
              out.push(instr)
              match gsi_global_ref_type(env, global_idx) {
                Some(ref_type) =>
                  if ref_type.is_nullable() {
                    out.push(@lib.Instruction::ref_as_non_null())
                  }
                None => ()
              }
              out.push(@lib.Instruction::drop())
              gsi_append_expr_instrs(out, value)
              idx += 2
              continue
            }
            None => out.push(instr)
          }
        } else {
          out.push(instr)
        }
      _ => out.push(instr)
    }
    idx += 1
  }
  out
}

///|
fn gsi_instrs_may_rewrite(
  instrs : Array[@lib.Instruction],
  env : @validate.Env,
  fields_by_type : Array[Array[@lib.FieldType]?],
  global_values_by_abs_idx : Array[Array[@lib.Expr?]?],
  global_type_slots : Array[Int],
) -> Bool {
  let mut idx = 0
  while idx < instrs.length() {
    let instr = instrs[idx]
    match instr {
      @lib.GlobalGet(global_idx) =>
        if idx + 1 < instrs.length() {
          match instrs[idx + 1] {
            @lib.StructGet(type_idx, field_idx) =>
              if gsi_folded_global_field_expr(
                  fields_by_type, global_values_by_abs_idx, global_type_slots, global_idx,
                  type_idx, field_idx, false, false,
                )
                is Some(_) {
                ignore(env)
                return true
              }
            @lib.StructGetS(type_idx, field_idx) =>
              if gsi_folded_global_field_expr(
                  fields_by_type, global_values_by_abs_idx, global_type_slots, global_idx,
                  type_idx, field_idx, true, false,
                )
                is Some(_) {
                return true
              }
            @lib.StructGetU(type_idx, field_idx) =>
              if gsi_folded_global_field_expr(
                  fields_by_type, global_values_by_abs_idx, global_type_slots, global_idx,
                  type_idx, field_idx, false, true,
                )
                is Some(_) {
                return true
              }
            _ => ()
          }
        }
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        if gsi_instrs_may_rewrite(
            body, env, fields_by_type, global_values_by_abs_idx, global_type_slots,
          ) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if gsi_instrs_may_rewrite(
            then_body, env, fields_by_type, global_values_by_abs_idx, global_type_slots,
          ) {
          return true
        }
        match else_body {
          Some(else_body) =>
            if gsi_instrs_may_rewrite(
                else_body, env, fields_by_type, global_values_by_abs_idx, global_type_slots,
              ) {
              return true
            }
          None => ()
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        if gsi_instrs_may_rewrite(
            body, env, fields_by_type, global_values_by_abs_idx, global_type_slots,
          ) {
          return true
        }
      _ => ()
    }
    idx += 1
  }
  false
}

///|
pub fn global_struct_inference_run_module_pass(
  mod_ : @lib.Module,
  closed_world : Bool,
) -> @lib.Module {
  if !closed_world {
    return mod_
  }
  let env = @validate.Env::new().with_module(mod_)
  let type_count = env.global_types.length()
  let globals = match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) => globals
    None => return mod_
  }
  let total_globals = env.globals.length()
  let imported_global_count = total_globals - globals.length()
  let fields_by_type : Array[Array[@lib.FieldType]?] = Array::make(
    type_count,
    None,
  )
  let global_values_by_abs_idx : Array[Array[@lib.Expr?]?] = Array::make(
    total_globals,
    None,
  )
  let global_type_slots = Array::make(total_globals, -1)

  for defined_idx = 0
      defined_idx < globals.length()
      defined_idx = defined_idx + 1 {
    let global_ = globals[defined_idx]
    let @lib.Global(@lib.GlobalType(_, mutable_), init) = global_
    if mutable_ {
      continue
    }
    match gsi_candidate_global_values(env, init) {
      Some((type_idx, next_values)) => {
        let slot = gsi_type_slot(type_idx, type_count)
        if slot < 0 {
          continue
        }
        let abs_idx = imported_global_count + defined_idx
        match fields_by_type[slot] {
          Some(_) => ()
          None =>
            match env.resolve_struct_fields(type_idx) {
              Ok(fields) => fields_by_type[slot] = Some(fields)
              Err(_) => ()
            }
        }
        if abs_idx >= 0 && abs_idx < total_globals {
          global_values_by_abs_idx[abs_idx] = Some(next_values)
          global_type_slots[abs_idx] = slot
        }
      }
      None => ()
    }
  }

  let mut any_candidate = false
  for values in global_values_by_abs_idx {
    if values is Some(_) {
      any_candidate = true
      break
    }
  }
  if !any_candidate {
    return mod_
  }

  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  let next_funcs = funcs.copy()
  let mut changed = false
  for defined_idx = 0
      defined_idx < funcs.length()
      defined_idx = defined_idx + 1 {
    let @lib.Func(locals, @lib.Expr(instrs)) = funcs[defined_idx]
    if !gsi_instrs_may_rewrite(
        instrs, env, fields_by_type, global_values_by_abs_idx, global_type_slots,
      ) {
      continue
    }
    let next_instrs = gsi_rewrite_instrs(
      instrs, env, fields_by_type, global_values_by_abs_idx, global_type_slots,
    )
    if next_instrs == instrs {
      continue
    }
    next_funcs[defined_idx] = @lib.Func::new(
      locals,
      @lib.Expr::new(next_instrs),
    )
    changed = true
  }
  if !changed {
    return mod_
  }
  mod_.with_code_sec(@lib.CodeSec::new(next_funcs))
}
