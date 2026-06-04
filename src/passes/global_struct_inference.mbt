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
priv struct GsiValueGroup {
  value : @lib.Expr
  globals : Array[@lib.GlobalIdx]
}

///|
priv struct GsiSplitOperand {
  start : Int
  end_exclusive : Int
  expr : @lib.Expr
}

///|
priv struct GsiDirectFieldReadRequest {
  global_idx : @lib.GlobalIdx
  type_idx : @lib.TypeIdx
  field_idx : Int
}

///|
priv struct GsiTypedFieldReadRequest {
  type_idx : @lib.TypeIdx
  field_idx : Int
}

///|
priv struct GsiUnnestReadRequests {
  direct_reads : Array[GsiDirectFieldReadRequest]
  typed_reads : Array[GsiTypedFieldReadRequest]
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
fn gsi_candidate_lists_equal(
  lhs : Array[@lib.GlobalIdx],
  rhs : Array[@lib.GlobalIdx],
) -> Bool {
  if lhs.length() != rhs.length() {
    return false
  }
  for idx = 0; idx < lhs.length(); idx = idx + 1 {
    if lhs[idx] != rhs[idx] {
      return false
    }
  }
  true
}

///|
fn gsi_exact_direct_candidate_globals(
  env : @validate.Env,
  mod_ : @lib.Module,
  facts : GsiClosedWorldFacts,
) -> Array[Array[@lib.GlobalIdx]] {
  let type_count = facts.poisoned_type_slots.length()
  let candidates_by_type_slot : Array[Array[@lib.GlobalIdx]] = []
  for slot = 0; slot < type_count; slot = slot + 1 {
    ignore(slot)
    candidates_by_type_slot.push([])
  }
  let globals = match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) => globals
    None => return candidates_by_type_slot
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
        candidates_by_type_slot[slot].push(candidate)
      }
      None => ()
    }
  }
  for slot = 0; slot < type_count; slot = slot + 1 {
    gsi_sort_candidate_globals(candidates_by_type_slot[slot])
    if !gsi_candidate_lists_equal(
        candidates_by_type_slot[slot],
        facts.candidate_globals_by_type_slot[slot],
      ) {
      candidates_by_type_slot[slot] = []
    }
  }
  candidates_by_type_slot
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
  let direct_candidates_by_type_slot = gsi_exact_direct_candidate_globals(
    env, mod_, facts,
  )
  for slot = 0; slot < type_count; slot = slot + 1 {
    for candidate in direct_candidates_by_type_slot[slot] {
      if candidate_count_by_type_slot[slot] == 0 {
        first_candidate_by_type_slot[slot] = Some(candidate)
      }
      candidate_count_by_type_slot[slot] += 1
    }
    if candidate_count_by_type_slot[slot] != 1 {
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
        Some(@lib.GlobalType(value_type, false)) => Some(value_type)
        _ => None
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
      match gsi_simple_instr_result_type(env, instr) {
        Some(instr_type) =>
          if @validate.Match::matches(instr_type, @lib.ValType::i32(), env) {
            Some(@lib.Expr::new([instr]))
          } else {
            None
          }
        None => None
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
fn gsi_instr_slice(
  instrs : Array[@lib.Instruction],
  start : Int,
  end_exclusive : Int,
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  for idx = start; idx < end_exclusive; idx = idx + 1 {
    out.push(instrs[idx])
  }
  out
}

///|
fn gsi_unnestable_stack_operand_count(instr : @lib.Instruction) -> Int? {
  match instr {
    @lib.I32Const(_)
    | @lib.I64Const(_)
    | @lib.F32Const(_)
    | @lib.F64Const(_)
    | @lib.V128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | @lib.RefNull(_)
    | @lib.RefFunc(_)
    | @lib.GlobalGet(_)
    | @lib.StringConst(_) => Some(0)
    @lib.I32Eqz
    | @lib.I64Eqz
    | @lib.I32Clz
    | @lib.I32Ctz
    | @lib.I32Popcnt
    | @lib.I64Clz
    | @lib.I64Ctz
    | @lib.I64Popcnt
    | @lib.I32Extend8S
    | @lib.I32Extend16S
    | @lib.I64Extend8S
    | @lib.I64Extend16S
    | @lib.I64Extend32S
    | @lib.F32Abs
    | @lib.F32Neg
    | @lib.F32Ceil
    | @lib.F32Floor
    | @lib.F32Trunc
    | @lib.F32Nearest
    | @lib.F32Sqrt
    | @lib.F64Abs
    | @lib.F64Neg
    | @lib.F64Ceil
    | @lib.F64Floor
    | @lib.F64Trunc
    | @lib.F64Nearest
    | @lib.F64Sqrt => Some(1)
    @lib.I32Add
    | @lib.I32Sub
    | @lib.I32Mul
    | @lib.I32And
    | @lib.I32Or
    | @lib.I32Xor
    | @lib.I32Shl
    | @lib.I32ShrS
    | @lib.I32ShrU
    | @lib.I32Rotl
    | @lib.I32Rotr
    | @lib.I64Add
    | @lib.I64Sub
    | @lib.I64Mul
    | @lib.I64And
    | @lib.I64Or
    | @lib.I64Xor
    | @lib.I64Shl
    | @lib.I64ShrS
    | @lib.I64ShrU
    | @lib.I64Rotl
    | @lib.I64Rotr
    | @lib.F32Add
    | @lib.F32Sub
    | @lib.F32Mul
    | @lib.F32Div
    | @lib.F32Min
    | @lib.F32Max
    | @lib.F32Copysign
    | @lib.F64Add
    | @lib.F64Sub
    | @lib.F64Mul
    | @lib.F64Div
    | @lib.F64Min
    | @lib.F64Max
    | @lib.F64Copysign => Some(2)
    _ => None
  }
}

///|
fn gsi_unnestable_instr_result_type(
  env : @validate.Env,
  instr : @lib.Instruction,
) -> @lib.ValType? {
  match instr {
    @lib.I32Eqz
    | @lib.I64Eqz
    | @lib.I32Clz
    | @lib.I32Ctz
    | @lib.I32Popcnt
    | @lib.I32Extend8S
    | @lib.I32Extend16S
    | @lib.I32Add
    | @lib.I32Sub
    | @lib.I32Mul
    | @lib.I32And
    | @lib.I32Or
    | @lib.I32Xor
    | @lib.I32Shl
    | @lib.I32ShrS
    | @lib.I32ShrU
    | @lib.I32Rotl
    | @lib.I32Rotr => Some(@lib.ValType::i32())
    @lib.I64Clz
    | @lib.I64Ctz
    | @lib.I64Popcnt
    | @lib.I64Extend8S
    | @lib.I64Extend16S
    | @lib.I64Extend32S
    | @lib.I64Add
    | @lib.I64Sub
    | @lib.I64Mul
    | @lib.I64And
    | @lib.I64Or
    | @lib.I64Xor
    | @lib.I64Shl
    | @lib.I64ShrS
    | @lib.I64ShrU
    | @lib.I64Rotl
    | @lib.I64Rotr => Some(@lib.ValType::i64())
    @lib.F32Abs
    | @lib.F32Neg
    | @lib.F32Ceil
    | @lib.F32Floor
    | @lib.F32Trunc
    | @lib.F32Nearest
    | @lib.F32Sqrt
    | @lib.F32Add
    | @lib.F32Sub
    | @lib.F32Mul
    | @lib.F32Div
    | @lib.F32Min
    | @lib.F32Max
    | @lib.F32Copysign => Some(@lib.ValType::f32())
    @lib.F64Abs
    | @lib.F64Neg
    | @lib.F64Ceil
    | @lib.F64Floor
    | @lib.F64Trunc
    | @lib.F64Nearest
    | @lib.F64Sqrt
    | @lib.F64Add
    | @lib.F64Sub
    | @lib.F64Mul
    | @lib.F64Div
    | @lib.F64Min
    | @lib.F64Max
    | @lib.F64Copysign => Some(@lib.ValType::f64())
    _ => gsi_simple_instr_result_type(env, instr)
  }
}

///|
fn gsi_find_operand_start(
  instrs : Array[@lib.Instruction],
  end_inclusive : Int,
) -> Int {
  let mut needed = 1
  let mut idx = end_inclusive
  while idx >= 0 {
    let operands = match gsi_unnestable_stack_operand_count(instrs[idx]) {
      Some(operands) => operands
      None => return -1
    }
    needed -= 1
    if needed < 0 {
      return -1
    }
    needed += operands
    if needed == 0 {
      return idx
    }
    idx -= 1
  }
  -1
}

///|
fn gsi_split_constructor_operands(
  instrs : Array[@lib.Instruction],
  operand_count : Int,
) -> Array[GsiSplitOperand]? {
  if operand_count < 0 || instrs.length() < operand_count + 1 {
    return None
  }
  let rev : Array[GsiSplitOperand] = []
  let mut end_inclusive = instrs.length() - 2
  for operand = 0; operand < operand_count; operand = operand + 1 {
    ignore(operand)
    let start = gsi_find_operand_start(instrs, end_inclusive)
    if start < 0 {
      return None
    }
    rev.push({
      start,
      end_exclusive: end_inclusive + 1,
      expr: @lib.Expr::new(gsi_instr_slice(instrs, start, end_inclusive + 1)),
    })
    end_inclusive = start - 1
  }
  if end_inclusive != -1 {
    return None
  }
  let out : Array[GsiSplitOperand] = []
  for idx = rev.length() - 1; idx >= 0; idx = idx - 1 {
    out.push(rev[idx])
  }
  Some(out)
}

///|
fn gsi_expr_is_materializable_field_value(
  env : @validate.Env,
  field_type : @lib.FieldType,
  expr : @lib.Expr,
) -> Bool {
  match expr {
    @lib.Expr([instr]) =>
      gsi_const_expr_for_field(env, field_type, instr) is Some(_)
    _ => false
  }
}

///|
fn gsi_expr_is_unnestable_field_value(
  env : @validate.Env,
  field_type : @lib.FieldType,
  expr : @lib.Expr,
) -> Bool {
  if gsi_expr_is_materializable_field_value(env, field_type, expr) {
    return false
  }
  let @lib.Expr(instrs) = expr
  if instrs.length() <= 1 {
    return false
  }
  for instr in instrs {
    if gsi_unnestable_stack_operand_count(instr) is None {
      return false
    }
  }
  match gsi_unnestable_instr_result_type(env, instrs[instrs.length() - 1]) {
    Some(actual_type) =>
      @validate.Match::matches(actual_type, field_type.unpack(), env)
    None => false
  }
}

///|
fn gsi_append_operand_expr(
  out : Array[@lib.Instruction],
  operand : @lib.Expr,
) -> Unit {
  let @lib.Expr(instrs) = operand
  for instr in instrs {
    out.push(instr)
  }
}

///|
fn gsi_instr_field_read_type_and_index(
  instr : @lib.Instruction,
) -> (@lib.TypeIdx, Int)? {
  match instr {
    @lib.StructGet(read_type, @lib.U32(raw_idx))
    | @lib.StructGetS(read_type, @lib.U32(raw_idx))
    | @lib.StructGetU(read_type, @lib.U32(raw_idx))
    | @lib.StructAtomicGet(_, read_type, @lib.U32(raw_idx))
    | @lib.StructAtomicGetS(_, read_type, @lib.U32(raw_idx))
    | @lib.StructAtomicGetU(_, read_type, @lib.U32(raw_idx)) =>
      Some((read_type, raw_idx.reinterpret_as_int()))
    _ => None
  }
}

///|
fn gsi_facts_include_candidate(
  facts : GsiClosedWorldFacts,
  read_type : @lib.TypeIdx,
  candidate : @lib.GlobalIdx,
) -> Bool {
  let slot = gsi_type_slot(
    read_type,
    facts.candidate_globals_by_type_slot.length(),
  )
  if slot < 0 || facts.poisoned_type_slots[slot] {
    return false
  }
  gsi_candidate_list_contains(
    facts.candidate_globals_by_type_slot[slot],
    candidate,
  )
}

///|
fn gsi_collect_unnest_read_requests_instrs(
  instrs : Array[@lib.Instruction],
  closed_world : Bool,
  requests : GsiUnnestReadRequests,
) -> Unit {
  let mut idx = 0
  while idx < instrs.length() {
    let instr = instrs[idx]
    if idx + 1 < instrs.length() {
      match instr {
        @lib.GlobalGet(global_idx) =>
          match gsi_instr_field_read_type_and_index(instrs[idx + 1]) {
            Some((type_idx, field_idx)) =>
              requests.direct_reads.push({ global_idx, type_idx, field_idx })
            None => ()
          }
        @lib.LocalGet(_) =>
          if closed_world {
            match gsi_instr_field_read_type_and_index(instrs[idx + 1]) {
              Some((type_idx, field_idx)) =>
                requests.typed_reads.push({ type_idx, field_idx })
              None => ()
            }
          }
        _ => ()
      }
    }
    match instr {
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        gsi_collect_unnest_read_requests_instrs(body, closed_world, requests)
      @lib.If(_, then_body, else_body) => {
        gsi_collect_unnest_read_requests_instrs(
          then_body, closed_world, requests,
        )
        match else_body {
          Some(else_body) =>
            gsi_collect_unnest_read_requests_instrs(
              else_body, closed_world, requests,
            )
          None => ()
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        gsi_collect_unnest_read_requests_instrs(body, closed_world, requests)
      _ => ()
    }
    idx += 1
  }
}

///|
fn gsi_collect_unnest_read_requests(
  mod_ : @lib.Module,
  closed_world : Bool,
) -> GsiUnnestReadRequests {
  let requests : GsiUnnestReadRequests = { direct_reads: [], typed_reads: [] }
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(_, @lib.Expr(instrs)) = func
        gsi_collect_unnest_read_requests_instrs(instrs, closed_world, requests)
      }
    None => ()
  }
  requests
}

///|
fn gsi_requests_may_need_unnested_candidate_field(
  requests : GsiUnnestReadRequests,
  env : @validate.Env,
  facts : GsiClosedWorldFacts?,
  candidate : @lib.GlobalIdx,
  candidate_type : @lib.TypeIdx,
  field_idx : Int,
) -> Bool {
  for request in requests.direct_reads {
    if request.global_idx == candidate &&
      request.type_idx == candidate_type &&
      request.field_idx == field_idx {
      return true
    }
  }
  match facts {
    Some(facts) =>
      for request in requests.typed_reads {
        if request.field_idx == field_idx &&
          gsi_candidate_type_matches_read_type(
            env,
            candidate_type,
            request.type_idx,
          ) &&
          gsi_facts_include_candidate(facts, request.type_idx, candidate) {
          return true
        }
      }
    None => ()
  }
  false
}

///|
fn gsi_rebuild_struct_new_init(
  operands : Array[GsiSplitOperand],
  fields : Array[@lib.FieldType],
  type_idx : @lib.TypeIdx,
  ctor_instr : @lib.Instruction,
) -> @lib.Expr {
  let out : Array[@lib.Instruction] = []
  for idx = 0; idx < operands.length(); idx = idx + 1 {
    gsi_append_operand_expr(out, operands[idx].expr)
  }
  match ctor_instr {
    @lib.StructNew(_) => out.push(@lib.Instruction::struct_new(type_idx))
    @lib.StructNewDesc(_) =>
      out.push(@lib.Instruction::struct_new_desc(type_idx))
    _ => ignore(fields)
  }
  @lib.Expr::new(out)
}

///|
fn gsi_try_unnest_global_init(
  requests : GsiUnnestReadRequests,
  env : @validate.Env,
  facts : GsiClosedWorldFacts?,
  global_idx : @lib.GlobalIdx,
  global_ : @lib.Global,
  next_fresh_abs_idx : Int,
  fresh_globals : Array[@lib.Global],
) -> @lib.Global? {
  let @lib.Global(global_type, init) = global_
  match global_type {
    @lib.GlobalType(_, true) => return None
    _ => ()
  }
  let @lib.Expr(instrs) = init
  if instrs.length() == 0 {
    return None
  }
  let (type_idx, extra_operands, ctor_instr) = match
    instrs[instrs.length() - 1] {
    @lib.StructNew(type_idx) =>
      (type_idx, 0, @lib.Instruction::struct_new(type_idx))
    @lib.StructNewDesc(type_idx) =>
      (type_idx, 1, @lib.Instruction::struct_new_desc(type_idx))
    _ => return None
  }
  let fields = match env.resolve_struct_fields(type_idx) {
    Ok(fields) => fields
    Err(_) => return None
  }
  let operands = match
    gsi_split_constructor_operands(instrs, fields.length() + extra_operands) {
    Some(operands) => operands
    None => return None
  }
  let mut changed = false
  let next_operands = operands.copy()
  for field_idx = 0; field_idx < fields.length(); field_idx = field_idx + 1 {
    if fields[field_idx].is_mutable() {
      continue
    }
    let operand = operands[field_idx].expr
    if !gsi_expr_is_unnestable_field_value(env, fields[field_idx], operand) {
      continue
    }
    if !gsi_requests_may_need_unnested_candidate_field(
        requests, env, facts, global_idx, type_idx, field_idx,
      ) {
      continue
    }
    let fresh_abs_idx = next_fresh_abs_idx + fresh_globals.length()
    fresh_globals.push(
      @lib.Global::new(
        @lib.GlobalType::new(fields[field_idx].unpack(), false),
        operand,
      ),
    )
    next_operands[field_idx] = {
      start: operands[field_idx].start,
      end_exclusive: operands[field_idx].end_exclusive,
      expr: @lib.Expr::new([
        @lib.Instruction::global_get(
          @lib.GlobalIdx::new(fresh_abs_idx.reinterpret_as_uint()),
        ),
      ]),
    }
    changed = true
  }
  if changed {
    let next_init = gsi_rebuild_struct_new_init(
      next_operands, fields, type_idx, ctor_instr,
    )
    Some(@lib.Global::new(global_type, next_init))
  } else {
    None
  }
}

///|
fn gsi_instrs_have_ref_get_desc(instrs : Array[@lib.Instruction]) -> Bool {
  for instr in instrs {
    match instr {
      @lib.RefGetDesc(_) => return true
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        if gsi_instrs_have_ref_get_desc(body) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if gsi_instrs_have_ref_get_desc(then_body) {
          return true
        }
        match else_body {
          Some(else_body) =>
            if gsi_instrs_have_ref_get_desc(else_body) {
              return true
            }
          None => ()
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        if gsi_instrs_have_ref_get_desc(body) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn gsi_module_has_ref_get_desc(mod_ : @lib.Module) -> Bool {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(_, @lib.Expr(instrs)) = func
        if gsi_instrs_have_ref_get_desc(instrs) {
          return true
        }
      }
    None => ()
  }
  false
}

///|
fn gsi_extra_surfaces_allowed(
  mod_ : @lib.Module,
  globals : Array[@lib.Global],
) -> Bool {
  if globals.length() > 4 {
    return false
  }
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      if funcs.length() > 2 {
        return false
      }
      for func in funcs {
        let @lib.Func(_, @lib.Expr(instrs)) = func
        if instrs.length() > 256 {
          return false
        }
      }
      true
    }
    None => false
  }
}

///|
fn gsi_unnest_global_operands(
  mod_ : @lib.Module,
  closed_world : Bool,
) -> (@lib.Module, Bool) {
  let globals = match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) => globals
    None => return (mod_, false)
  }
  if !gsi_extra_surfaces_allowed(mod_, globals) {
    return (mod_, false)
  }
  let env = @validate.Env::new().with_module(mod_)
  let facts = if closed_world {
    Some(gsi_build_closed_world_facts(env, mod_))
  } else {
    None
  }
  let total_globals = env.globals.length()
  let imported_global_count = total_globals - globals.length()
  let requests = gsi_collect_unnest_read_requests(mod_, closed_world)
  let next_globals = globals.copy()
  let fresh_globals : Array[@lib.Global] = []
  let mut changed = false
  for defined_idx = 0
      defined_idx < globals.length()
      defined_idx = defined_idx + 1 {
    let global_idx = @lib.GlobalIdx::new(
      (imported_global_count + defined_idx).reinterpret_as_uint(),
    )
    match
      gsi_try_unnest_global_init(
        requests,
        env,
        facts,
        global_idx,
        globals[defined_idx],
        total_globals,
        fresh_globals,
      ) {
      Some(next_global) => {
        next_globals[defined_idx] = next_global
        changed = true
      }
      None => ()
    }
  }
  if !changed {
    return (mod_, false)
  }
  for fresh in fresh_globals {
    next_globals.push(fresh)
  }
  (
    reorder_globals_run_module_pass_always(
      mod_.with_global_sec(@lib.GlobalSec::new(next_globals)),
    ),
    true,
  )
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
    @lib.Expr(instrs) => {
      let out = instrs.copy()
      if signed {
        out.push(
          if bits == 8 {
            @lib.Instruction::i32_extend8s()
          } else {
            @lib.Instruction::i32_extend16s()
          },
        )
      } else {
        out.push(
          @lib.Instruction::i32_const(
            @lib.I32::new(if bits == 8 { 0xFF } else { 0xFFFF }),
          ),
        )
        out.push(@lib.Instruction::i32_and())
      }
      Some(@lib.Expr::new(out))
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
fn gsi_single_propagated_candidate_for_type(
  rewrite_candidates_by_type_slot : Array[Array[@lib.GlobalIdx]],
  type_idx : @lib.TypeIdx,
) -> @lib.GlobalIdx? {
  let slot = gsi_type_slot(type_idx, rewrite_candidates_by_type_slot.length())
  if slot < 0 {
    return None
  }
  let candidates = rewrite_candidates_by_type_slot[slot]
  if candidates.length() == 1 {
    Some(candidates[0])
  } else {
    None
  }
}

///|
fn gsi_global_value_type_for_candidate_origin(
  env : @validate.Env,
  global_idx : @lib.GlobalIdx,
  read_type_idx : @lib.TypeIdx,
) -> @lib.ValType? {
  match env.get_global_type(global_idx) {
    Some(@lib.GlobalType(value_type, false)) =>
      match value_type {
        @lib.RefTypeValType(ref_type) =>
          match ref_type.get_heap_type() {
            @lib.HeapType(candidate_type_idx) =>
              if gsi_candidate_type_matches_read_type(
                  env, candidate_type_idx, read_type_idx,
                ) {
                Some(value_type)
              } else {
                None
              }
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn gsi_propagated_single_candidate_local_origin_block(
  env : @validate.Env,
  local_env : @validate.Env,
  rewrite_candidates_by_type_slot : Array[Array[@lib.GlobalIdx]],
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
    gsi_single_propagated_candidate_for_type(
      rewrite_candidates_by_type_slot, type_idx,
    ) {
    Some(candidate) => candidate
    None => return None
  }
  let candidate_value_type = match
    gsi_global_value_type_for_candidate_origin(
      env, candidate_global_idx, type_idx,
    ) {
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
fn gsi_single_instr_expr_result_type(
  env : @validate.Env,
  expr : @lib.Expr,
) -> @lib.ValType? {
  match expr {
    @lib.Expr([instr]) => gsi_simple_instr_result_type(env, instr)
    _ => None
  }
}

///|
fn gsi_one_value_local_fold_block(
  env : @validate.Env,
  local_env : @validate.Env,
  rewrite_candidates_by_type_slot : Array[Array[@lib.GlobalIdx]],
  fields_by_type : Array[Array[@lib.FieldType]?],
  global_values_by_abs_idx : Array[Array[@lib.Expr?]?],
  global_type_slots : Array[Int],
  local_idx : @lib.LocalIdx,
  type_idx : @lib.TypeIdx,
  field_idx : @lib.U32,
  signed : Bool,
  unsigned : Bool,
) -> @lib.Instruction? {
  if !gsi_struct_field_is_immutable(env, type_idx, field_idx) {
    return None
  }
  let local_ref_type = match
    gsi_local_get_ref_type_for_exact_struct(local_env, local_idx, type_idx) {
    Some(ref_type) => ref_type
    None => return None
  }
  let slot = gsi_type_slot(type_idx, rewrite_candidates_by_type_slot.length())
  if slot < 0 {
    return None
  }
  let candidates = rewrite_candidates_by_type_slot[slot]
  if candidates.length() < 1 {
    return None
  }
  let result_type = match
    gsi_field_read_result_type(
      fields_by_type, type_idx, field_idx, signed, unsigned,
    ) {
    Some(result_type) => result_type
    None => return None
  }
  let mut folded_value : @lib.Expr? = None
  for candidate in candidates {
    let value = match
      gsi_folded_candidate_global_field_expr(
        env, fields_by_type, global_values_by_abs_idx, global_type_slots, candidate,
        type_idx, field_idx, signed, unsigned,
      ) {
      Some(value) => value
      None => return None
    }
    if !gsi_expr_matches_result_type(env, value, result_type) {
      return None
    }
    match folded_value {
      None => folded_value = Some(value)
      Some(first_value) => if value != first_value { return None }
    }
  }
  let value = match folded_value {
    Some(value) => value
    None => return None
  }
  let block_body : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(local_idx),
  ]
  if local_ref_type.is_nullable() {
    block_body.push(@lib.Instruction::ref_as_non_null())
  }
  block_body.push(@lib.Instruction::drop())
  gsi_append_expr_instrs(block_body, value)
  Some(
    @lib.Instruction::block(
      @lib.BlockType::val_type(result_type),
      @lib.Expr::new(block_body),
    ),
  )
}

///|
fn gsi_field_read_result_type(
  fields_by_type : Array[Array[@lib.FieldType]?],
  type_idx : @lib.TypeIdx,
  field_idx : @lib.U32,
  signed : Bool,
  unsigned : Bool,
) -> @lib.ValType? {
  let type_slot = gsi_type_slot(type_idx, fields_by_type.length())
  if type_slot < 0 {
    return None
  }
  let fields = match fields_by_type[type_slot] {
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
fn gsi_packed_repair_expr_matches_i32(
  env : @validate.Env,
  expr : @lib.Expr,
) -> Bool {
  match expr {
    @lib.Expr([value, @lib.I32Extend8S])
    | @lib.Expr([value, @lib.I32Extend16S]) =>
      match gsi_simple_instr_result_type(env, value) {
        Some(actual_type) =>
          @validate.Match::matches(actual_type, @lib.ValType::i32(), env)
        None => false
      }
    @lib.Expr([value, @lib.I32Const(_), @lib.I32And]) =>
      match gsi_simple_instr_result_type(env, value) {
        Some(actual_type) =>
          @validate.Match::matches(actual_type, @lib.ValType::i32(), env)
        None => false
      }
    _ => false
  }
}

///|
fn gsi_expr_matches_result_type(
  env : @validate.Env,
  expr : @lib.Expr,
  result_type : @lib.ValType,
) -> Bool {
  match gsi_single_instr_expr_result_type(env, expr) {
    Some(actual_type) => @validate.Match::matches(actual_type, result_type, env)
    None =>
      @validate.Match::matches(@lib.ValType::i32(), result_type, env) &&
      gsi_packed_repair_expr_matches_i32(env, expr)
  }
}

///|
fn gsi_descriptor_read_result_type(
  env : @validate.Env,
  type_idx : @lib.TypeIdx,
  operand_ref_type : @lib.RefType?,
) -> @lib.ValType? {
  match env.descriptor_result_type(type_idx, operand_ref_type) {
    Ok(result_type) => Some(result_type)
    Err(_) => None
  }
}

///|
fn gsi_candidate_global_descriptor_expr(
  env : @validate.Env,
  expr : @lib.Expr,
) -> (@lib.TypeIdx, @lib.Expr)? {
  let @lib.Expr(instrs) = expr
  if instrs.length() == 0 {
    return None
  }
  let (type_idx, operand_count, desc_operand_idx) = match
    instrs[instrs.length() - 1] {
    @lib.StructNewDesc(type_idx) => {
      let fields = match env.resolve_struct_fields(type_idx) {
        Ok(fields) => fields
        Err(_) => return None
      }
      (type_idx, fields.length() + 1, fields.length())
    }
    @lib.StructNewDefaultDesc(type_idx) => (type_idx, 1, 0)
    _ => return None
  }
  let operands = match gsi_split_constructor_operands(instrs, operand_count) {
    Some(operands) => operands
    None => return None
  }
  let desc_expr = operands[desc_operand_idx].expr
  let result_type = match gsi_descriptor_read_result_type(env, type_idx, None) {
    Some(result_type) => result_type
    None => return None
  }
  if gsi_expr_matches_result_type(env, desc_expr, result_type) {
    Some((type_idx, desc_expr))
  } else {
    None
  }
}

///|
fn gsi_type_idx_from_slot(slot : Int) -> @lib.TypeIdx {
  @lib.TypeIdx::new(slot.reinterpret_as_uint())
}

///|
fn gsi_candidate_type_matches_read_type(
  env : @validate.Env,
  candidate_type_idx : @lib.TypeIdx,
  read_type_idx : @lib.TypeIdx,
) -> Bool {
  let candidate_type = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(candidate_type_idx)),
  )
  let read_type = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(read_type_idx)),
  )
  @validate.Match::matches(candidate_type, read_type, env)
}

///|
fn gsi_folded_global_descriptor_expr(
  env : @validate.Env,
  global_descriptor_values_by_abs_idx : Array[@lib.Expr?],
  global_type_slots : Array[Int],
  global_idx : @lib.GlobalIdx,
  type_idx : @lib.TypeIdx,
  operand_ref_type : @lib.RefType?,
) -> @lib.Expr? {
  let @lib.GlobalIdx(abs_idx_u) = global_idx
  let abs_idx = abs_idx_u.reinterpret_as_int()
  if abs_idx < 0 ||
    abs_idx >= global_descriptor_values_by_abs_idx.length() ||
    abs_idx >= global_type_slots.length() {
    return None
  }
  let type_slot = gsi_type_slot(type_idx, global_type_slots.length())
  if type_slot < 0 || global_type_slots[abs_idx] != type_slot {
    return None
  }
  let value = match global_descriptor_values_by_abs_idx[abs_idx] {
    Some(value) => value
    None => return None
  }
  let result_type = match
    gsi_descriptor_read_result_type(env, type_idx, operand_ref_type) {
    Some(result_type) => result_type
    None => return None
  }
  if gsi_expr_matches_result_type(env, value, result_type) {
    Some(value)
  } else {
    None
  }
}

///|
fn gsi_folded_candidate_global_descriptor_expr(
  env : @validate.Env,
  global_descriptor_values_by_abs_idx : Array[@lib.Expr?],
  global_type_slots : Array[Int],
  global_idx : @lib.GlobalIdx,
  read_type_idx : @lib.TypeIdx,
  result_type : @lib.ValType,
) -> @lib.Expr? {
  let @lib.GlobalIdx(abs_idx_u) = global_idx
  let abs_idx = abs_idx_u.reinterpret_as_int()
  if abs_idx < 0 ||
    abs_idx >= global_descriptor_values_by_abs_idx.length() ||
    abs_idx >= global_type_slots.length() {
    return None
  }
  let candidate_slot = global_type_slots[abs_idx]
  if candidate_slot < 0 {
    return None
  }
  let candidate_type_idx = gsi_type_idx_from_slot(candidate_slot)
  if !gsi_candidate_type_matches_read_type(
      env, candidate_type_idx, read_type_idx,
    ) {
    return None
  }
  let value = match global_descriptor_values_by_abs_idx[abs_idx] {
    Some(value) => value
    None => return None
  }
  if gsi_expr_matches_result_type(env, value, result_type) {
    Some(value)
  } else {
    None
  }
}

///|
fn gsi_folded_candidate_global_field_expr(
  env : @validate.Env,
  fields_by_type : Array[Array[@lib.FieldType]?],
  global_values_by_abs_idx : Array[Array[@lib.Expr?]?],
  global_type_slots : Array[Int],
  global_idx : @lib.GlobalIdx,
  read_type_idx : @lib.TypeIdx,
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
  let candidate_slot = global_type_slots[abs_idx]
  if candidate_slot < 0 || candidate_slot >= fields_by_type.length() {
    return None
  }
  let candidate_type_idx = gsi_type_idx_from_slot(candidate_slot)
  if !gsi_candidate_type_matches_read_type(
      env, candidate_type_idx, read_type_idx,
    ) {
    return None
  }
  let fields = match fields_by_type[candidate_slot] {
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
fn gsi_find_value_group(
  groups : Array[GsiValueGroup],
  value : @lib.Expr,
) -> Int {
  for idx = 0; idx < groups.length(); idx = idx + 1 {
    if groups[idx].value == value {
      return idx
    }
  }
  -1
}

///|
fn gsi_one_value_descriptor_local_fold_block(
  env : @validate.Env,
  local_env : @validate.Env,
  rewrite_candidates_by_type_slot : Array[Array[@lib.GlobalIdx]],
  global_descriptor_values_by_abs_idx : Array[@lib.Expr?],
  global_type_slots : Array[Int],
  local_idx : @lib.LocalIdx,
  type_idx : @lib.TypeIdx,
) -> @lib.Instruction? {
  let local_ref_type = match
    gsi_local_get_ref_type_for_exact_struct(local_env, local_idx, type_idx) {
    Some(ref_type) => ref_type
    None => return None
  }
  let slot = gsi_type_slot(type_idx, rewrite_candidates_by_type_slot.length())
  if slot < 0 {
    return None
  }
  let candidates = rewrite_candidates_by_type_slot[slot]
  if candidates.length() < 1 {
    return None
  }
  let result_type = match
    gsi_descriptor_read_result_type(env, type_idx, Some(local_ref_type)) {
    Some(result_type) => result_type
    None => return None
  }
  let mut folded_value : @lib.Expr? = None
  for candidate in candidates {
    let value = match
      gsi_folded_candidate_global_descriptor_expr(
        env, global_descriptor_values_by_abs_idx, global_type_slots, candidate, type_idx,
        result_type,
      ) {
      Some(value) => value
      None => return None
    }
    match folded_value {
      None => folded_value = Some(value)
      Some(first_value) => if value != first_value { return None }
    }
  }
  let value = match folded_value {
    Some(value) => value
    None => return None
  }
  let block_body : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(local_idx),
  ]
  if local_ref_type.is_nullable() {
    block_body.push(@lib.Instruction::ref_as_non_null())
  }
  block_body.push(@lib.Instruction::drop())
  gsi_append_expr_instrs(block_body, value)
  Some(
    @lib.Instruction::block(
      @lib.BlockType::val_type(result_type),
      @lib.Expr::new(block_body),
    ),
  )
}

///|
fn gsi_two_value_descriptor_singleton_select_block(
  env : @validate.Env,
  local_env : @validate.Env,
  rewrite_candidates_by_type_slot : Array[Array[@lib.GlobalIdx]],
  global_descriptor_values_by_abs_idx : Array[@lib.Expr?],
  global_type_slots : Array[Int],
  local_idx : @lib.LocalIdx,
  type_idx : @lib.TypeIdx,
) -> @lib.Instruction? {
  let local_ref_type = match
    gsi_local_get_ref_type_for_exact_struct(local_env, local_idx, type_idx) {
    Some(ref_type) => ref_type
    None => return None
  }
  let slot = gsi_type_slot(type_idx, rewrite_candidates_by_type_slot.length())
  if slot < 0 {
    return None
  }
  let candidates = rewrite_candidates_by_type_slot[slot]
  if candidates.length() <= 1 {
    return None
  }
  let result_type = match
    gsi_descriptor_read_result_type(env, type_idx, Some(local_ref_type)) {
    Some(result_type) => result_type
    None => return None
  }
  let groups : Array[GsiValueGroup] = []
  for candidate in candidates {
    let value = match
      gsi_folded_candidate_global_descriptor_expr(
        env, global_descriptor_values_by_abs_idx, global_type_slots, candidate, type_idx,
        result_type,
      ) {
      Some(value) => value
      None => return None
    }
    let group_idx = gsi_find_value_group(groups, value)
    if group_idx >= 0 {
      groups[group_idx].globals.push(candidate)
    } else {
      if groups.length() >= 2 {
        return None
      }
      groups.push({ value, globals: [candidate] })
    }
  }
  if groups.length() != 2 {
    return None
  }
  let singleton_idx = if groups[0].globals.length() == 1 {
    0
  } else if groups[1].globals.length() == 1 {
    1
  } else {
    return None
  }
  let other_idx = if singleton_idx == 0 { 1 } else { 0 }
  let singleton = groups[singleton_idx]
  let other = groups[other_idx]
  let test_global = singleton.globals[0]
  let block_body : Array[@lib.Instruction] = []
  gsi_append_expr_instrs(block_body, singleton.value)
  gsi_append_expr_instrs(block_body, other.value)
  block_body.push(@lib.Instruction::local_get(local_idx))
  if local_ref_type.is_nullable() {
    block_body.push(@lib.Instruction::ref_as_non_null())
  }
  block_body.push(@lib.Instruction::global_get(test_global))
  block_body.push(@lib.Instruction::ref_eq())
  block_body.push(@lib.Instruction::select(types=Some([result_type])))
  Some(
    @lib.Instruction::block(
      @lib.BlockType::val_type(result_type),
      @lib.Expr::new(block_body),
    ),
  )
}

///|
fn gsi_two_value_singleton_select_block(
  env : @validate.Env,
  local_env : @validate.Env,
  rewrite_candidates_by_type_slot : Array[Array[@lib.GlobalIdx]],
  fields_by_type : Array[Array[@lib.FieldType]?],
  global_values_by_abs_idx : Array[Array[@lib.Expr?]?],
  global_type_slots : Array[Int],
  local_idx : @lib.LocalIdx,
  type_idx : @lib.TypeIdx,
  field_idx : @lib.U32,
  signed : Bool,
  unsigned : Bool,
) -> @lib.Instruction? {
  if !gsi_struct_field_is_immutable(env, type_idx, field_idx) {
    return None
  }
  let local_ref_type = match
    gsi_local_get_ref_type_for_exact_struct(local_env, local_idx, type_idx) {
    Some(ref_type) => ref_type
    None => return None
  }
  let slot = gsi_type_slot(type_idx, rewrite_candidates_by_type_slot.length())
  if slot < 0 {
    return None
  }
  let candidates = rewrite_candidates_by_type_slot[slot]
  if candidates.length() <= 1 {
    return None
  }
  let result_type = match
    gsi_field_read_result_type(
      fields_by_type, type_idx, field_idx, signed, unsigned,
    ) {
    Some(result_type) => result_type
    None => return None
  }
  let groups : Array[GsiValueGroup] = []
  for candidate in candidates {
    let value = match
      gsi_folded_candidate_global_field_expr(
        env, fields_by_type, global_values_by_abs_idx, global_type_slots, candidate,
        type_idx, field_idx, signed, unsigned,
      ) {
      Some(value) => value
      None => return None
    }
    if !gsi_expr_matches_result_type(env, value, result_type) {
      return None
    }
    let group_idx = gsi_find_value_group(groups, value)
    if group_idx >= 0 {
      groups[group_idx].globals.push(candidate)
    } else {
      if groups.length() >= 2 {
        return None
      }
      groups.push({ value, globals: [candidate] })
    }
  }
  if groups.length() != 2 {
    return None
  }
  let singleton_idx = if groups[0].globals.length() == 1 {
    0
  } else if groups[1].globals.length() == 1 {
    1
  } else {
    return None
  }
  let other_idx = if singleton_idx == 0 { 1 } else { 0 }
  let singleton = groups[singleton_idx]
  let other = groups[other_idx]
  let test_global = singleton.globals[0]
  let block_body : Array[@lib.Instruction] = []
  gsi_append_expr_instrs(block_body, singleton.value)
  gsi_append_expr_instrs(block_body, other.value)
  block_body.push(@lib.Instruction::local_get(local_idx))
  if local_ref_type.is_nullable() {
    block_body.push(@lib.Instruction::ref_as_non_null())
  }
  block_body.push(@lib.Instruction::global_get(test_global))
  block_body.push(@lib.Instruction::ref_eq())
  block_body.push(@lib.Instruction::select(types=Some([result_type])))
  Some(
    @lib.Instruction::block(
      @lib.BlockType::val_type(result_type),
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
  env : @validate.Env,
  fields_by_type : Array[Array[@lib.FieldType]?],
  global_values_by_abs_idx : Array[Array[@lib.Expr?]?],
  global_type_slots : Array[Int],
  global_idx : @lib.GlobalIdx,
  type_idx : @lib.TypeIdx,
  field_idx : @lib.U32,
  signed : Bool,
  unsigned : Bool,
) -> @lib.Expr? {
  let result_type = match
    gsi_field_read_result_type(
      fields_by_type, type_idx, field_idx, signed, unsigned,
    ) {
    Some(result_type) => result_type
    None => return None
  }
  let value = match
    gsi_folded_candidate_global_field_expr(
      env, fields_by_type, global_values_by_abs_idx, global_type_slots, global_idx,
      type_idx, field_idx, signed, unsigned,
    ) {
    Some(value) => value
    None => return None
  }
  if gsi_expr_matches_result_type(env, value, result_type) {
    Some(value)
  } else {
    None
  }
}

///|
fn gsi_rewrite_instrs(
  instrs : Array[@lib.Instruction],
  env : @validate.Env,
  local_env : @validate.Env,
  fields_by_type : Array[Array[@lib.FieldType]?],
  global_values_by_abs_idx : Array[Array[@lib.Expr?]?],
  global_descriptor_values_by_abs_idx : Array[@lib.Expr?],
  global_type_slots : Array[Int],
  exact_single_candidate_by_type_slot : Array[@lib.GlobalIdx?],
  rewrite_candidates_by_type_slot : Array[Array[@lib.GlobalIdx]],
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
                body, env, local_env, fields_by_type, global_values_by_abs_idx, global_descriptor_values_by_abs_idx,
                global_type_slots, exact_single_candidate_by_type_slot, rewrite_candidates_by_type_slot,
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
                body, env, local_env, fields_by_type, global_values_by_abs_idx, global_descriptor_values_by_abs_idx,
                global_type_slots, exact_single_candidate_by_type_slot, rewrite_candidates_by_type_slot,
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
              global_descriptor_values_by_abs_idx, global_type_slots, exact_single_candidate_by_type_slot,
              rewrite_candidates_by_type_slot,
            ),
            else_body.map(fn(body) {
              gsi_rewrite_instrs(
                body, env, local_env, fields_by_type, global_values_by_abs_idx, global_descriptor_values_by_abs_idx,
                global_type_slots, exact_single_candidate_by_type_slot, rewrite_candidates_by_type_slot,
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
                body, env, local_env, fields_by_type, global_values_by_abs_idx, global_descriptor_values_by_abs_idx,
                global_type_slots, exact_single_candidate_by_type_slot, rewrite_candidates_by_type_slot,
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
                env, fields_by_type, global_values_by_abs_idx, global_type_slots,
                global_idx, type_idx, field_idx, false, false,
              )
            @lib.StructGetS(type_idx, field_idx) =>
              gsi_folded_global_field_expr(
                env, fields_by_type, global_values_by_abs_idx, global_type_slots,
                global_idx, type_idx, field_idx, true, false,
              )
            @lib.StructGetU(type_idx, field_idx) =>
              gsi_folded_global_field_expr(
                env, fields_by_type, global_values_by_abs_idx, global_type_slots,
                global_idx, type_idx, field_idx, false, true,
              )
            @lib.StructAtomicGet(_, type_idx, field_idx) =>
              gsi_folded_global_field_expr(
                env, fields_by_type, global_values_by_abs_idx, global_type_slots,
                global_idx, type_idx, field_idx, false, false,
              )
            @lib.StructAtomicGetS(_, type_idx, field_idx) =>
              gsi_folded_global_field_expr(
                env, fields_by_type, global_values_by_abs_idx, global_type_slots,
                global_idx, type_idx, field_idx, true, false,
              )
            @lib.StructAtomicGetU(_, type_idx, field_idx) =>
              gsi_folded_global_field_expr(
                env, fields_by_type, global_values_by_abs_idx, global_type_slots,
                global_idx, type_idx, field_idx, false, true,
              )
            @lib.RefGetDesc(type_idx) =>
              gsi_folded_global_descriptor_expr(
                env,
                global_descriptor_values_by_abs_idx,
                global_type_slots,
                global_idx,
                type_idx,
                gsi_global_ref_type(env, global_idx),
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
          let next_instr = instrs[idx + 1]
          let origin_rewrite = match next_instr {
            @lib.StructGet(type_idx, field_idx)
            | @lib.StructGetS(type_idx, field_idx)
            | @lib.StructGetU(type_idx, field_idx)
            | @lib.StructAtomicGet(_, type_idx, field_idx)
            | @lib.StructAtomicGetS(_, type_idx, field_idx)
            | @lib.StructAtomicGetU(_, type_idx, field_idx) => {
              let exact_origin = gsi_single_candidate_local_origin_block(
                env, local_env, exact_single_candidate_by_type_slot, local_idx, type_idx,
                field_idx,
              )
              match exact_origin {
                Some(_) => exact_origin
                None =>
                  gsi_propagated_single_candidate_local_origin_block(
                    env, local_env, rewrite_candidates_by_type_slot, local_idx, type_idx,
                    field_idx,
                  )
              }
            }
            _ => None
          }
          match origin_rewrite {
            Some(block) => out.push(block)
            None => {
              let value_rewrite = match next_instr {
                @lib.StructGet(type_idx, field_idx) =>
                  gsi_one_value_local_fold_block(
                    env, local_env, rewrite_candidates_by_type_slot, fields_by_type,
                    global_values_by_abs_idx, global_type_slots, local_idx, type_idx,
                    field_idx, false, false,
                  )
                @lib.StructGetS(type_idx, field_idx) =>
                  gsi_one_value_local_fold_block(
                    env, local_env, rewrite_candidates_by_type_slot, fields_by_type,
                    global_values_by_abs_idx, global_type_slots, local_idx, type_idx,
                    field_idx, true, false,
                  )
                @lib.StructGetU(type_idx, field_idx) =>
                  gsi_one_value_local_fold_block(
                    env, local_env, rewrite_candidates_by_type_slot, fields_by_type,
                    global_values_by_abs_idx, global_type_slots, local_idx, type_idx,
                    field_idx, false, true,
                  )
                @lib.StructAtomicGet(_, type_idx, field_idx) =>
                  gsi_one_value_local_fold_block(
                    env, local_env, rewrite_candidates_by_type_slot, fields_by_type,
                    global_values_by_abs_idx, global_type_slots, local_idx, type_idx,
                    field_idx, false, false,
                  )
                @lib.StructAtomicGetS(_, type_idx, field_idx) =>
                  gsi_one_value_local_fold_block(
                    env, local_env, rewrite_candidates_by_type_slot, fields_by_type,
                    global_values_by_abs_idx, global_type_slots, local_idx, type_idx,
                    field_idx, true, false,
                  )
                @lib.StructAtomicGetU(_, type_idx, field_idx) =>
                  gsi_one_value_local_fold_block(
                    env, local_env, rewrite_candidates_by_type_slot, fields_by_type,
                    global_values_by_abs_idx, global_type_slots, local_idx, type_idx,
                    field_idx, false, true,
                  )
                @lib.RefGetDesc(type_idx) =>
                  gsi_one_value_descriptor_local_fold_block(
                    env, local_env, rewrite_candidates_by_type_slot, global_descriptor_values_by_abs_idx,
                    global_type_slots, local_idx, type_idx,
                  )
                _ => None
              }
              match value_rewrite {
                Some(block) => {
                  out.push(block)
                  idx += 2
                  continue
                }
                None => {
                  let select_rewrite = match next_instr {
                    @lib.StructGet(type_idx, field_idx) =>
                      gsi_two_value_singleton_select_block(
                        env, local_env, rewrite_candidates_by_type_slot, fields_by_type,
                        global_values_by_abs_idx, global_type_slots, local_idx, type_idx,
                        field_idx, false, false,
                      )
                    @lib.StructGetS(type_idx, field_idx) =>
                      gsi_two_value_singleton_select_block(
                        env, local_env, rewrite_candidates_by_type_slot, fields_by_type,
                        global_values_by_abs_idx, global_type_slots, local_idx, type_idx,
                        field_idx, true, false,
                      )
                    @lib.StructGetU(type_idx, field_idx) =>
                      gsi_two_value_singleton_select_block(
                        env, local_env, rewrite_candidates_by_type_slot, fields_by_type,
                        global_values_by_abs_idx, global_type_slots, local_idx, type_idx,
                        field_idx, false, true,
                      )
                    @lib.StructAtomicGet(_, type_idx, field_idx) =>
                      gsi_two_value_singleton_select_block(
                        env, local_env, rewrite_candidates_by_type_slot, fields_by_type,
                        global_values_by_abs_idx, global_type_slots, local_idx, type_idx,
                        field_idx, false, false,
                      )
                    @lib.StructAtomicGetS(_, type_idx, field_idx) =>
                      gsi_two_value_singleton_select_block(
                        env, local_env, rewrite_candidates_by_type_slot, fields_by_type,
                        global_values_by_abs_idx, global_type_slots, local_idx, type_idx,
                        field_idx, true, false,
                      )
                    @lib.StructAtomicGetU(_, type_idx, field_idx) =>
                      gsi_two_value_singleton_select_block(
                        env, local_env, rewrite_candidates_by_type_slot, fields_by_type,
                        global_values_by_abs_idx, global_type_slots, local_idx, type_idx,
                        field_idx, false, true,
                      )
                    @lib.RefGetDesc(type_idx) =>
                      gsi_two_value_descriptor_singleton_select_block(
                        env, local_env, rewrite_candidates_by_type_slot, global_descriptor_values_by_abs_idx,
                        global_type_slots, local_idx, type_idx,
                      )
                    _ => None
                  }
                  match select_rewrite {
                    Some(block) => {
                      out.push(block)
                      idx += 2
                      continue
                    }
                    None => out.push(instr)
                  }
                }
              }
            }
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
  global_descriptor_values_by_abs_idx : Array[@lib.Expr?],
  global_type_slots : Array[Int],
  exact_single_candidate_by_type_slot : Array[@lib.GlobalIdx?],
  rewrite_candidates_by_type_slot : Array[Array[@lib.GlobalIdx]],
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
                  env, fields_by_type, global_values_by_abs_idx, global_type_slots,
                  global_idx, type_idx, field_idx, false, false,
                )
                is Some(_) {
                return true
              }
            @lib.StructGetS(type_idx, field_idx) =>
              if gsi_folded_global_field_expr(
                  env, fields_by_type, global_values_by_abs_idx, global_type_slots,
                  global_idx, type_idx, field_idx, true, false,
                )
                is Some(_) {
                return true
              }
            @lib.StructGetU(type_idx, field_idx) =>
              if gsi_folded_global_field_expr(
                  env, fields_by_type, global_values_by_abs_idx, global_type_slots,
                  global_idx, type_idx, field_idx, false, true,
                )
                is Some(_) {
                return true
              }
            @lib.StructAtomicGet(_, type_idx, field_idx) =>
              if gsi_folded_global_field_expr(
                  env, fields_by_type, global_values_by_abs_idx, global_type_slots,
                  global_idx, type_idx, field_idx, false, false,
                )
                is Some(_) {
                return true
              }
            @lib.StructAtomicGetS(_, type_idx, field_idx) =>
              if gsi_folded_global_field_expr(
                  env, fields_by_type, global_values_by_abs_idx, global_type_slots,
                  global_idx, type_idx, field_idx, true, false,
                )
                is Some(_) {
                return true
              }
            @lib.StructAtomicGetU(_, type_idx, field_idx) =>
              if gsi_folded_global_field_expr(
                  env, fields_by_type, global_values_by_abs_idx, global_type_slots,
                  global_idx, type_idx, field_idx, false, true,
                )
                is Some(_) {
                return true
              }
            @lib.RefGetDesc(type_idx) =>
              if gsi_folded_global_descriptor_expr(
                  env,
                  global_descriptor_values_by_abs_idx,
                  global_type_slots,
                  global_idx,
                  type_idx,
                  gsi_global_ref_type(env, global_idx),
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
            @lib.StructGet(type_idx, field_idx) => {
              if gsi_single_candidate_local_origin_block(
                  env, local_env, exact_single_candidate_by_type_slot, local_idx,
                  type_idx, field_idx,
                )
                is Some(_) {
                return true
              }
              if gsi_propagated_single_candidate_local_origin_block(
                  env, local_env, rewrite_candidates_by_type_slot, local_idx, type_idx,
                  field_idx,
                )
                is Some(_) {
                return true
              }
              if gsi_one_value_local_fold_block(
                  env, local_env, rewrite_candidates_by_type_slot, fields_by_type,
                  global_values_by_abs_idx, global_type_slots, local_idx, type_idx,
                  field_idx, false, false,
                )
                is Some(_) {
                return true
              }
              if gsi_two_value_singleton_select_block(
                  env, local_env, rewrite_candidates_by_type_slot, fields_by_type,
                  global_values_by_abs_idx, global_type_slots, local_idx, type_idx,
                  field_idx, false, false,
                )
                is Some(_) {
                return true
              }
            }
            @lib.StructGetS(type_idx, field_idx) => {
              if gsi_single_candidate_local_origin_block(
                  env, local_env, exact_single_candidate_by_type_slot, local_idx,
                  type_idx, field_idx,
                )
                is Some(_) {
                return true
              }
              if gsi_propagated_single_candidate_local_origin_block(
                  env, local_env, rewrite_candidates_by_type_slot, local_idx, type_idx,
                  field_idx,
                )
                is Some(_) {
                return true
              }
              if gsi_one_value_local_fold_block(
                  env, local_env, rewrite_candidates_by_type_slot, fields_by_type,
                  global_values_by_abs_idx, global_type_slots, local_idx, type_idx,
                  field_idx, true, false,
                )
                is Some(_) {
                return true
              }
              if gsi_two_value_singleton_select_block(
                  env, local_env, rewrite_candidates_by_type_slot, fields_by_type,
                  global_values_by_abs_idx, global_type_slots, local_idx, type_idx,
                  field_idx, true, false,
                )
                is Some(_) {
                return true
              }
            }
            @lib.StructGetU(type_idx, field_idx) => {
              if gsi_single_candidate_local_origin_block(
                  env, local_env, exact_single_candidate_by_type_slot, local_idx,
                  type_idx, field_idx,
                )
                is Some(_) {
                return true
              }
              if gsi_propagated_single_candidate_local_origin_block(
                  env, local_env, rewrite_candidates_by_type_slot, local_idx, type_idx,
                  field_idx,
                )
                is Some(_) {
                return true
              }
              if gsi_one_value_local_fold_block(
                  env, local_env, rewrite_candidates_by_type_slot, fields_by_type,
                  global_values_by_abs_idx, global_type_slots, local_idx, type_idx,
                  field_idx, false, true,
                )
                is Some(_) {
                return true
              }
              if gsi_two_value_singleton_select_block(
                  env, local_env, rewrite_candidates_by_type_slot, fields_by_type,
                  global_values_by_abs_idx, global_type_slots, local_idx, type_idx,
                  field_idx, false, true,
                )
                is Some(_) {
                return true
              }
            }
            @lib.StructAtomicGet(_, type_idx, field_idx)
            | @lib.StructAtomicGetS(_, type_idx, field_idx)
            | @lib.StructAtomicGetU(_, type_idx, field_idx) => {
              let (signed, unsigned) = match instrs[idx + 1] {
                @lib.StructAtomicGetS(_, _, _) => (true, false)
                @lib.StructAtomicGetU(_, _, _) => (false, true)
                _ => (false, false)
              }
              if gsi_single_candidate_local_origin_block(
                  env, local_env, exact_single_candidate_by_type_slot, local_idx,
                  type_idx, field_idx,
                )
                is Some(_) {
                return true
              }
              if gsi_propagated_single_candidate_local_origin_block(
                  env, local_env, rewrite_candidates_by_type_slot, local_idx, type_idx,
                  field_idx,
                )
                is Some(_) {
                return true
              }
              if gsi_one_value_local_fold_block(
                  env, local_env, rewrite_candidates_by_type_slot, fields_by_type,
                  global_values_by_abs_idx, global_type_slots, local_idx, type_idx,
                  field_idx, signed, unsigned,
                )
                is Some(_) {
                return true
              }
              if gsi_two_value_singleton_select_block(
                  env, local_env, rewrite_candidates_by_type_slot, fields_by_type,
                  global_values_by_abs_idx, global_type_slots, local_idx, type_idx,
                  field_idx, signed, unsigned,
                )
                is Some(_) {
                return true
              }
            }
            @lib.RefGetDesc(type_idx) => {
              if gsi_one_value_descriptor_local_fold_block(
                  env, local_env, rewrite_candidates_by_type_slot, global_descriptor_values_by_abs_idx,
                  global_type_slots, local_idx, type_idx,
                )
                is Some(_) {
                return true
              }
              if gsi_two_value_descriptor_singleton_select_block(
                  env, local_env, rewrite_candidates_by_type_slot, global_descriptor_values_by_abs_idx,
                  global_type_slots, local_idx, type_idx,
                )
                is Some(_) {
                return true
              }
            }
            _ => ()
          }
        }
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        if gsi_instrs_may_rewrite(
            body, env, local_env, fields_by_type, global_values_by_abs_idx, global_descriptor_values_by_abs_idx,
            global_type_slots, exact_single_candidate_by_type_slot, rewrite_candidates_by_type_slot,
          ) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if gsi_instrs_may_rewrite(
            then_body, env, local_env, fields_by_type, global_values_by_abs_idx,
            global_descriptor_values_by_abs_idx, global_type_slots, exact_single_candidate_by_type_slot,
            rewrite_candidates_by_type_slot,
          ) {
          return true
        }
        match else_body {
          Some(else_body) =>
            if gsi_instrs_may_rewrite(
                else_body, env, local_env, fields_by_type, global_values_by_abs_idx,
                global_descriptor_values_by_abs_idx, global_type_slots, exact_single_candidate_by_type_slot,
                rewrite_candidates_by_type_slot,
              ) {
              return true
            }
          None => ()
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        if gsi_instrs_may_rewrite(
            body, env, local_env, fields_by_type, global_values_by_abs_idx, global_descriptor_values_by_abs_idx,
            global_type_slots, exact_single_candidate_by_type_slot, rewrite_candidates_by_type_slot,
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
  let (unnested_mod, did_unnest) = gsi_unnest_global_operands(
    mod_, closed_world,
  )
  if did_unnest {
    return global_struct_inference_run_module_pass(unnested_mod, closed_world)
  }
  let env = @validate.Env::new().with_module(mod_)
  let type_count = env.global_types.length()
  let exact_single_candidate_by_type_slot : Array[@lib.GlobalIdx?] = Array::make(
    type_count,
    None,
  )
  let rewrite_candidates_by_type_slot : Array[Array[@lib.GlobalIdx]] = []
  for slot = 0; slot < type_count; slot = slot + 1 {
    ignore(slot)
    rewrite_candidates_by_type_slot.push([])
  }
  if closed_world {
    let facts = gsi_build_closed_world_facts(env, mod_)
    ignore(gsi_closed_world_facts_has_candidates(facts))
    let exact_single = gsi_exact_single_candidate_globals(env, mod_, facts)
    for slot = 0; slot < type_count; slot = slot + 1 {
      exact_single_candidate_by_type_slot[slot] = exact_single[slot]
      rewrite_candidates_by_type_slot[slot] = facts.candidate_globals_by_type_slot[slot]
    }
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
  let global_descriptor_values_by_abs_idx : Array[@lib.Expr?] = Array::make(
    total_globals,
    None,
  )
  let needs_descriptor_values = gsi_extra_surfaces_allowed(mod_, globals) &&
    gsi_module_has_ref_get_desc(mod_)
  let global_type_slots = Array::make(total_globals, -1)

  for slot = 0; slot < type_count; slot = slot + 1 {
    match env.resolve_struct_fields(gsi_type_idx_from_slot(slot)) {
      Ok(fields) => fields_by_type[slot] = Some(fields)
      Err(_) => ()
    }
  }

  for defined_idx = 0
      defined_idx < globals.length()
      defined_idx = defined_idx + 1 {
    let global_ = globals[defined_idx]
    let @lib.Global(@lib.GlobalType(_, mutable_), init) = global_
    if mutable_ {
      continue
    }
    let abs_idx = imported_global_count + defined_idx
    match gsi_candidate_global_values(env, init) {
      Some((type_idx, next_values)) => {
        let slot = gsi_type_slot(type_idx, type_count)
        if slot < 0 {
          continue
        }
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
    if needs_descriptor_values {
      match gsi_candidate_global_descriptor_expr(env, init) {
        Some((type_idx, desc_value)) => {
          let slot = gsi_type_slot(type_idx, type_count)
          if slot >= 0 && abs_idx >= 0 && abs_idx < total_globals {
            global_descriptor_values_by_abs_idx[abs_idx] = Some(desc_value)
            global_type_slots[abs_idx] = slot
          }
        }
        None => ()
      }
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
    for value in global_descriptor_values_by_abs_idx {
      if value is Some(_) {
        any_candidate = true
        break
      }
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
        instrs, env, local_env, fields_by_type, global_values_by_abs_idx, global_descriptor_values_by_abs_idx,
        global_type_slots, exact_single_candidate_by_type_slot, rewrite_candidates_by_type_slot,
      ) {
      continue
    }
    let next_instrs = gsi_rewrite_instrs(
      instrs, env, local_env, fields_by_type, global_values_by_abs_idx, global_descriptor_values_by_abs_idx,
      global_type_slots, exact_single_candidate_by_type_slot, rewrite_candidates_by_type_slot,
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
