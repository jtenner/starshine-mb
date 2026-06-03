///|
pub fn global_struct_inference_summary() -> String {
  "Fold immutable struct field reads from direct immutable global instances when their values are globally fixed."
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
priv struct GsiClosedWorldFacts {
  poisoned_type_slots : Array[Bool]
  candidate_globals_by_type_slot : Array[Array[@lib.GlobalIdx]]
}

///|
fn gsi_closed_world_facts_has_candidates(facts : GsiClosedWorldFacts) -> Bool {
  for slot = 0
      slot < facts.candidate_globals_by_type_slot.length()
      slot = slot + 1 {
    if !facts.poisoned_type_slots[slot] &&
      facts.candidate_globals_by_type_slot[slot].length() > 0 {
      return true
    }
  }
  false
}

///|
fn gsi_struct_new_type(instr : @lib.Instruction) -> @lib.TypeIdx? {
  match instr {
    @lib.StructNew(type_idx)
    | @lib.StructNewDefault(type_idx)
    | @lib.StructNewDesc(type_idx)
    | @lib.StructNewDefaultDesc(type_idx) => Some(type_idx)
    _ => None
  }
}

///|
fn gsi_mark_poisoned_type(
  poisoned_type_slots : Array[Bool],
  type_idx : @lib.TypeIdx,
) -> Unit {
  let slot = gsi_type_slot(type_idx, poisoned_type_slots.length())
  if slot >= 0 {
    poisoned_type_slots[slot] = true
  }
}

///|
fn gsi_mark_all_struct_allocs(
  instrs : Array[@lib.Instruction],
  poisoned_type_slots : Array[Bool],
) -> Unit {
  for instr in instrs {
    match gsi_struct_new_type(instr) {
      Some(type_idx) => gsi_mark_poisoned_type(poisoned_type_slots, type_idx)
      None => ()
    }
    match instr {
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        gsi_mark_all_struct_allocs(body, poisoned_type_slots)
      @lib.If(_, then_body, else_body) => {
        gsi_mark_all_struct_allocs(then_body, poisoned_type_slots)
        match else_body {
          Some(else_body) =>
            gsi_mark_all_struct_allocs(else_body, poisoned_type_slots)
          None => ()
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        gsi_mark_all_struct_allocs(body, poisoned_type_slots)
      _ => ()
    }
  }
}

///|
fn gsi_mark_nested_global_struct_allocs(
  instrs : Array[@lib.Instruction],
  poisoned_type_slots : Array[Bool],
) -> Unit {
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    let instr = instrs[idx]
    match gsi_struct_new_type(instr) {
      Some(type_idx) =>
        if idx + 1 != instrs.length() {
          gsi_mark_poisoned_type(poisoned_type_slots, type_idx)
        }
      None => ()
    }
    match instr {
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        gsi_mark_all_struct_allocs(body, poisoned_type_slots)
      @lib.If(_, then_body, else_body) => {
        gsi_mark_all_struct_allocs(then_body, poisoned_type_slots)
        match else_body {
          Some(else_body) =>
            gsi_mark_all_struct_allocs(else_body, poisoned_type_slots)
          None => ()
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        gsi_mark_all_struct_allocs(body, poisoned_type_slots)
      _ => ()
    }
  }
}

///|
fn gsi_global_idx_order(global_idx : @lib.GlobalIdx) -> Int {
  let @lib.GlobalIdx(raw) = global_idx
  raw.reinterpret_as_int()
}

///|
fn gsi_candidate_list_contains(
  candidates : Array[@lib.GlobalIdx],
  candidate : @lib.GlobalIdx,
) -> Bool {
  for existing in candidates {
    if existing == candidate {
      return true
    }
  }
  false
}

///|
fn gsi_push_candidate_unique(
  candidates : Array[@lib.GlobalIdx],
  candidate : @lib.GlobalIdx,
) -> Bool {
  if gsi_candidate_list_contains(candidates, candidate) {
    false
  } else {
    candidates.push(candidate)
    true
  }
}

///|
fn gsi_sort_candidate_globals(candidates : Array[@lib.GlobalIdx]) -> Unit {
  candidates.sort_by(fn(lhs, rhs) {
    gsi_global_idx_order(lhs) - gsi_global_idx_order(rhs)
  })
}

///|
fn gsi_propagate_closed_world_subtype_facts(
  env : @validate.Env,
  poisoned_type_slots : Array[Bool],
  candidate_globals_by_type_slot : Array[Array[@lib.GlobalIdx]],
) -> Unit {
  let type_count = poisoned_type_slots.length()
  let mut changed = true
  while changed {
    changed = false
    for child_slot = 0; child_slot < type_count; child_slot = child_slot + 1 {
      let supers = env.global_types[child_slot].super_types()
      for super_type in supers {
        let parent_slot = gsi_type_slot(super_type, type_count)
        if parent_slot < 0 {
          continue
        }
        if poisoned_type_slots[child_slot] && !poisoned_type_slots[parent_slot] {
          poisoned_type_slots[parent_slot] = true
          changed = true
        }
        for candidate in candidate_globals_by_type_slot[child_slot] {
          if gsi_push_candidate_unique(
              candidate_globals_by_type_slot[parent_slot],
              candidate,
            ) {
            changed = true
          }
        }
      }
    }
  }
  for slot = 0; slot < type_count; slot = slot + 1 {
    if poisoned_type_slots[slot] {
      candidate_globals_by_type_slot[slot] = []
    } else {
      gsi_sort_candidate_globals(candidate_globals_by_type_slot[slot])
    }
  }
}

///|
fn gsi_global_decl_is_eq_comparable(
  env : @validate.Env,
  global_type : @lib.GlobalType,
) -> Bool {
  match global_type {
    @lib.GlobalType(value_type, _) =>
      @validate.Match::matches(value_type, @lib.ValType::eqref_null(), env)
  }
}

///|
fn gsi_ref_type_matches_exact_type(
  ref_type : @lib.RefType,
  type_idx : @lib.TypeIdx,
) -> Bool {
  match ref_type.get_heap_type() {
    @lib.HeapType(inner_type_idx) => inner_type_idx == type_idx
    _ => false
  }
}

///|
fn gsi_val_type_ref_matches_exact_type(
  value_type : @lib.ValType,
  type_idx : @lib.TypeIdx,
) -> @lib.RefType? {
  match value_type {
    @lib.RefTypeValType(ref_type) =>
      if gsi_ref_type_matches_exact_type(ref_type, type_idx) {
        Some(ref_type)
      } else {
        None
      }
    _ => None
  }
}

///|
fn gsi_global_value_type_for_exact_struct(
  env : @validate.Env,
  global_idx : @lib.GlobalIdx,
  type_idx : @lib.TypeIdx,
) -> @lib.ValType? {
  match env.get_global_type(global_idx) {
    Some(@lib.GlobalType(value_type, _)) =>
      match gsi_val_type_ref_matches_exact_type(value_type, type_idx) {
        Some(_) => Some(value_type)
        None => None
      }
    None => None
  }
}

///|
fn gsi_struct_field_is_immutable(
  env : @validate.Env,
  type_idx : @lib.TypeIdx,
  field_idx : @lib.U32,
) -> Bool {
  let fields = match env.resolve_struct_fields(type_idx) {
    Ok(fields) => fields
    Err(_) => return false
  }
  let @lib.U32(raw_idx) = field_idx
  let idx = raw_idx.reinterpret_as_int()
  idx >= 0 && idx < fields.length() && !fields[idx].is_mutable()
}

///|
fn gsi_exact_single_candidate_globals(
  env : @validate.Env,
  mod_ : @lib.Module,
  facts : GsiClosedWorldFacts,
) -> Array[@lib.GlobalIdx?] {
  let type_count = facts.poisoned_type_slots.length()
  let first_candidate_by_type_slot : Array[@lib.GlobalIdx?] = Array::make(
    type_count,
    None,
  )
  let candidate_count_by_type_slot : Array[Int] = Array::make(type_count, 0)
  let globals = match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) => globals
    None => return first_candidate_by_type_slot
  }
  let total_globals = env.globals.length()
  let imported_global_count = total_globals - globals.length()
  for defined_idx = 0
      defined_idx < globals.length()
      defined_idx = defined_idx + 1 {
    let global_ = globals[defined_idx]
    let @lib.Global(global_type, init) = global_
    match global_type {
      @lib.GlobalType(_, true) => continue
      _ => ()
    }
    if !gsi_global_decl_is_eq_comparable(env, global_type) {
      continue
    }
    match gsi_candidate_global_values(env, init) {
      Some((type_idx, _)) => {
        let slot = gsi_type_slot(type_idx, type_count)
        if slot < 0 || facts.poisoned_type_slots[slot] {
          continue
        }
        let candidate = @lib.GlobalIdx::new(
          (imported_global_count + defined_idx).reinterpret_as_uint(),
        )
        if gsi_global_value_type_for_exact_struct(env, candidate, type_idx)
          is None {
          continue
        }
        if candidate_count_by_type_slot[slot] == 0 {
          first_candidate_by_type_slot[slot] = Some(candidate)
        }
        candidate_count_by_type_slot[slot] += 1
      }
      None => ()
    }
  }
  for slot = 0; slot < type_count; slot = slot + 1 {
    if candidate_count_by_type_slot[slot] != 1 {
      first_candidate_by_type_slot[slot] = None
      continue
    }
    let propagated_candidates = facts.candidate_globals_by_type_slot[slot]
    if propagated_candidates.length() != 1 ||
      first_candidate_by_type_slot[slot] != Some(propagated_candidates[0]) {
      first_candidate_by_type_slot[slot] = None
    }
  }
  first_candidate_by_type_slot
}

///|
fn gsi_build_closed_world_facts(
  env : @validate.Env,
  mod_ : @lib.Module,
) -> GsiClosedWorldFacts {
  let type_count = env.global_types.length()
  let poisoned_type_slots : Array[Bool] = Array::make(type_count, false)
  let candidate_globals_by_type_slot : Array[Array[@lib.GlobalIdx]] = []
  for slot = 0; slot < type_count; slot = slot + 1 {
    ignore(slot)
    candidate_globals_by_type_slot.push([])
  }

  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(_, @lib.Expr(instrs)) = func
        gsi_mark_all_struct_allocs(instrs, poisoned_type_slots)
      }
    None => ()
  }

  let globals = match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) => globals
    None => {
      gsi_propagate_closed_world_subtype_facts(
        env, poisoned_type_slots, candidate_globals_by_type_slot,
      )
      return { poisoned_type_slots, candidate_globals_by_type_slot }
    }
  }
  let total_globals = env.globals.length()
  let imported_global_count = total_globals - globals.length()
  for defined_idx = 0
      defined_idx < globals.length()
      defined_idx = defined_idx + 1 {
    let global_ = globals[defined_idx]
    let @lib.Global(global_type, init) = global_
    let @lib.Expr(init_instrs) = init
    gsi_mark_nested_global_struct_allocs(init_instrs, poisoned_type_slots)
    match global_type {
      @lib.GlobalType(_, true) => continue
      _ => ()
    }
    if !gsi_global_decl_is_eq_comparable(env, global_type) {
      continue
    }
    match gsi_candidate_global_values(env, init) {
      Some((type_idx, _)) => {
        let slot = gsi_type_slot(type_idx, type_count)
        if slot >= 0 && !poisoned_type_slots[slot] {
          candidate_globals_by_type_slot[slot].push(
            @lib.GlobalIdx::new(
              (imported_global_count + defined_idx).reinterpret_as_uint(),
            ),
          )
        }
      }
      None => ()
    }
  }
  gsi_propagate_closed_world_subtype_facts(
    env, poisoned_type_slots, candidate_globals_by_type_slot,
  )
  { poisoned_type_slots, candidate_globals_by_type_slot }
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
  field_operand_start : Int,
  expected_extra_operands : Int,
  defaults_only : Bool,
) -> Array[@lib.Expr?]? {
  let fields = match env.resolve_struct_fields(type_idx) {
    Ok(fields) => fields
    Err(_) => return None
  }
  let values : Array[@lib.Expr?] = Array::make(fields.length(), None)
  if defaults_only {
    if instrs.length() != expected_extra_operands + 1 {
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
  if instrs.length() != expected_extra_operands + fields.length() + 1 {
    return Some(values)
  }
  for idx = 0; idx < fields.length(); idx = idx + 1 {
    if fields[idx].is_mutable() {
      continue
    }
    values[idx] = gsi_const_expr_for_field(
      env,
      fields[idx],
      instrs[field_operand_start + idx],
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
      gsi_candidate_field_values(env, instrs, type_idx, 0, 0, false).map(fn(
        values,
      ) {
        (type_idx, values)
      })
    @lib.StructNewDefault(type_idx) =>
      gsi_candidate_field_values(env, instrs, type_idx, 0, 0, true).map(fn(
        values,
      ) {
        (type_idx, values)
      })
    @lib.StructNewDesc(type_idx) =>
      gsi_candidate_field_values(env, instrs, type_idx, 0, 1, false).map(fn(
        values,
      ) {
        (type_idx, values)
      })
    @lib.StructNewDefaultDesc(type_idx) =>
      gsi_candidate_field_values(env, instrs, type_idx, 0, 1, true).map(fn(
        values,
      ) {
        (type_idx, values)
      })
    _ => None
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
fn gsi_exact_single_candidate_for_type(
  exact_single_candidate_by_type_slot : Array[@lib.GlobalIdx?],
  type_idx : @lib.TypeIdx,
) -> @lib.GlobalIdx? {
  let slot = gsi_type_slot(
    type_idx,
    exact_single_candidate_by_type_slot.length(),
  )
  if slot < 0 {
    None
  } else {
    exact_single_candidate_by_type_slot[slot]
  }
}

///|
fn gsi_local_get_ref_type_for_exact_struct(
  local_env : @validate.Env,
  local_idx : @lib.LocalIdx,
  type_idx : @lib.TypeIdx,
) -> @lib.RefType? {
  match local_env.get_local_type(local_idx) {
    Some(value_type) =>
      gsi_val_type_ref_matches_exact_type(value_type, type_idx)
    None => None
  }
}

///|
fn gsi_single_candidate_local_origin_block(
  env : @validate.Env,
  local_env : @validate.Env,
  exact_single_candidate_by_type_slot : Array[@lib.GlobalIdx?],
  local_idx : @lib.LocalIdx,
  type_idx : @lib.TypeIdx,
  field_idx : @lib.U32,
) -> @lib.Instruction? {
  if !gsi_struct_field_is_immutable(env, type_idx, field_idx) {
    return None
  }
  let local_ref_type = match
    gsi_local_get_ref_type_for_exact_struct(local_env, local_idx, type_idx) {
    Some(ref_type) => ref_type
    None => return None
  }
  let candidate_global_idx = match
    gsi_exact_single_candidate_for_type(
      exact_single_candidate_by_type_slot, type_idx,
    ) {
    Some(candidate) => candidate
    None => return None
  }
  let candidate_value_type = match
    gsi_global_value_type_for_exact_struct(env, candidate_global_idx, type_idx) {
    Some(value_type) => value_type
    None => return None
  }
  let block_body : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(local_idx),
  ]
  if local_ref_type.is_nullable() {
    block_body.push(@lib.Instruction::ref_as_non_null())
  }
  block_body.push(@lib.Instruction::drop())
  block_body.push(@lib.Instruction::global_get(candidate_global_idx))
  Some(
    @lib.Instruction::block(
      @lib.BlockType::val_type(candidate_value_type),
      @lib.Expr::new(block_body),
    ),
  )
}

///|
fn gsi_function_local_env(
  env : @validate.Env,
  imported_func_count : Int,
  defined_idx : Int,
  locals : @lib.Locals,
) -> @validate.Env? {
  let func_idx = @lib.FuncIdx::new(
    (imported_func_count + defined_idx).reinterpret_as_uint(),
  )
  match env.get_functype_by_funcidx(func_idx) {
    Some(@lib.FuncType(params, _)) => {
      let all_locals = @lib.Locals::from_types(params)
      all_locals.append(locals)
      Some(env.with_locals(all_locals))
    }
    None => None
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
  local_env : @validate.Env,
  fields_by_type : Array[Array[@lib.FieldType]?],
  global_values_by_abs_idx : Array[Array[@lib.Expr?]?],
  global_type_slots : Array[Int],
  exact_single_candidate_by_type_slot : Array[@lib.GlobalIdx?],
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
                body, env, local_env, fields_by_type, global_values_by_abs_idx, global_type_slots,
                exact_single_candidate_by_type_slot,
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
                body, env, local_env, fields_by_type, global_values_by_abs_idx, global_type_slots,
                exact_single_candidate_by_type_slot,
              ),
            ),
          ),
        )
      @lib.If(block_type, then_body, else_body) =>
        out.push(
          @lib.Instruction::if_(
            block_type,
            gsi_rewrite_instrs(
              then_body, env, local_env, fields_by_type, global_values_by_abs_idx,
              global_type_slots, exact_single_candidate_by_type_slot,
            ),
            else_body.map(fn(body) {
              gsi_rewrite_instrs(
                body, env, local_env, fields_by_type, global_values_by_abs_idx, global_type_slots,
                exact_single_candidate_by_type_slot,
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
                body, env, local_env, fields_by_type, global_values_by_abs_idx, global_type_slots,
                exact_single_candidate_by_type_slot,
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
      @lib.LocalGet(local_idx) =>
        if idx + 1 < instrs.length() {
          let rewritten = match instrs[idx + 1] {
            @lib.StructGet(type_idx, field_idx)
            | @lib.StructGetS(type_idx, field_idx)
            | @lib.StructGetU(type_idx, field_idx) =>
              gsi_single_candidate_local_origin_block(
                env, local_env, exact_single_candidate_by_type_slot, local_idx, type_idx,
                field_idx,
              )
            _ => None
          }
          match rewritten {
            Some(block) => out.push(block)
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
  local_env : @validate.Env,
  fields_by_type : Array[Array[@lib.FieldType]?],
  global_values_by_abs_idx : Array[Array[@lib.Expr?]?],
  global_type_slots : Array[Int],
  exact_single_candidate_by_type_slot : Array[@lib.GlobalIdx?],
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
      @lib.LocalGet(local_idx) =>
        if idx + 1 < instrs.length() {
          match instrs[idx + 1] {
            @lib.StructGet(type_idx, field_idx)
            | @lib.StructGetS(type_idx, field_idx)
            | @lib.StructGetU(type_idx, field_idx) =>
              if gsi_single_candidate_local_origin_block(
                  env, local_env, exact_single_candidate_by_type_slot, local_idx,
                  type_idx, field_idx,
                )
                is Some(_) {
                return true
              }
            _ => ()
          }
        }
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        if gsi_instrs_may_rewrite(
            body, env, local_env, fields_by_type, global_values_by_abs_idx, global_type_slots,
            exact_single_candidate_by_type_slot,
          ) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if gsi_instrs_may_rewrite(
            then_body, env, local_env, fields_by_type, global_values_by_abs_idx,
            global_type_slots, exact_single_candidate_by_type_slot,
          ) {
          return true
        }
        match else_body {
          Some(else_body) =>
            if gsi_instrs_may_rewrite(
                else_body, env, local_env, fields_by_type, global_values_by_abs_idx,
                global_type_slots, exact_single_candidate_by_type_slot,
              ) {
              return true
            }
          None => ()
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        if gsi_instrs_may_rewrite(
            body, env, local_env, fields_by_type, global_values_by_abs_idx, global_type_slots,
            exact_single_candidate_by_type_slot,
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
  let env = @validate.Env::new().with_module(mod_)
  let type_count = env.global_types.length()
  let exact_single_candidate_by_type_slot : Array[@lib.GlobalIdx?] = if closed_world {
    let facts = gsi_build_closed_world_facts(env, mod_)
    ignore(gsi_closed_world_facts_has_candidates(facts))
    gsi_exact_single_candidate_globals(env, mod_, facts)
  } else {
    Array::make(type_count, None)
  }
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
  let imported_func_count = env.funcs.length() - funcs.length()
  let next_funcs = funcs.copy()
  let mut changed = false
  for defined_idx = 0
      defined_idx < funcs.length()
      defined_idx = defined_idx + 1 {
    let @lib.Func(locals, @lib.Expr(instrs)) = funcs[defined_idx]
    let local_env = match
      gsi_function_local_env(env, imported_func_count, defined_idx, locals) {
      Some(local_env) => local_env
      None => continue
    }
    if !gsi_instrs_may_rewrite(
        instrs, env, local_env, fields_by_type, global_values_by_abs_idx, global_type_slots,
        exact_single_candidate_by_type_slot,
      ) {
      continue
    }
    let next_instrs = gsi_rewrite_instrs(
      instrs, env, local_env, fields_by_type, global_values_by_abs_idx, global_type_slots,
      exact_single_candidate_by_type_slot,
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
