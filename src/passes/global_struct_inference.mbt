///|
priv enum GSIGetKind {
  NormalGet
  SignedGet
  UnsignedGet
}

///|
priv enum GSIGlobalInit {
  GSIInitNew(Array[TInstr])
  GSIInitDefault
}

///|
priv enum GSIReadValue {
  GSIConstValue(TInstr)
  GSIValueFromGlobal(GlobalIdx)
}

///|
priv struct GSIAnalysis {
  type_globals : Map[TypeIdx, Array[GlobalIdx]]
  global_inits : Map[GlobalIdx, GSIGlobalInit]
}

///|
priv struct GSIRewriteState {
  env : Env
  analysis : GSIAnalysis
}

///|
fn gsi_count_imported_globals(mod : Module) -> UInt {
  let mut n : UInt = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, GlobalExternType(_)) => n += 1
          _ => ()
        }
      }
    None => ()
  }
  n
}

///|
fn gsi_collect_all_type_indices(mod : Module) -> Array[TypeIdx] {
  let out : Array[TypeIdx] = []
  let mut next : UInt = 0
  match mod.type_sec {
    Some(TypeSec(rec_types)) =>
      for rec_type in rec_types {
        match rec_type {
          SingleRecType(_) => {
            out.push(TypeIdx::new(next))
            next += 1
          }
          GroupRecType(sts) =>
            for _ in sts {
              out.push(TypeIdx::new(next))
              next += 1
            }
        }
      }
    None => ()
  }
  out
}

///|
fn gsi_collect_struct_types_in_tinstr(
  instr : TInstr,
  out : Set[TypeIdx],
) -> Unit {
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    match curr {
      TStructNew(type_idx, _) | TStructNewDefault(type_idx) => out.add(type_idx)
      _ => ()
    }
    self.walk_tinstruction_default((), curr)
  })
  ignore(walker.walk_tinstruction((), instr))
}

///|
fn gsi_collect_struct_types_in_texpr(expr : TExpr, out : Set[TypeIdx]) -> Unit {
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    match curr {
      TStructNew(type_idx, _) | TStructNewDefault(type_idx) => out.add(type_idx)
      _ => ()
    }
    self.walk_tinstruction_default((), curr)
  })
  ignore(walker.walk_texpr((), expr))
}

///|
fn gsi_single_root_init(init : Expr, env : Env) -> TInstr? {
  match to_texpr(init, env) {
    Ok(TExpr([root])) => Some(root)
    _ => None
  }
}

///|
fn gsi_global_root_type(root : TInstr) -> TypeIdx? {
  match root {
    TStructNew(type_idx, _) | TStructNewDefault(type_idx) => Some(type_idx)
    _ => None
  }
}

///|
fn gsi_global_root_init_info(root : TInstr) -> GSIGlobalInit? {
  match root {
    TStructNew(_, operands) => Some(GSIInitNew(operands))
    TStructNewDefault(_) => Some(GSIInitDefault)
    _ => None
  }
}

///|
fn gsi_is_eqref_compatible(vt : ValType, env : Env) -> Bool {
  Match::matches(vt, ValType::eqref_null(), env)
}

///|
fn gsi_add_unique_global(globals : Array[GlobalIdx], idx : GlobalIdx) -> Unit {
  for old in globals {
    if old == idx {
      return
    }
  }
  globals.push(idx)
}

///|
fn gsi_add_type_global(
  type_globals : Map[TypeIdx, Array[GlobalIdx]],
  type_idx : TypeIdx,
  global_idx : GlobalIdx,
) -> Unit {
  match type_globals.get(type_idx) {
    Some(globals) => gsi_add_unique_global(globals, global_idx)
    None => type_globals[type_idx] = [global_idx]
  }
}

///|
fn gsi_get_super_types(env : Env, type_idx : TypeIdx) -> Array[TypeIdx] {
  match env.resolve_subtype(type_idx) {
    Some(st) => st.super_types()
    None => []
  }
}

///|
fn gsi_propagate_unoptimizable_to_supers(
  unoptimizable : Set[TypeIdx],
  env : Env,
) -> Unit {
  let queue : Array[TypeIdx] = []
  for type_idx in unoptimizable {
    queue.push(type_idx)
  }
  let mut i = 0
  while i < queue.length() {
    let curr = queue[i]
    i += 1
    for super_type in gsi_get_super_types(env, curr) {
      if !unoptimizable.contains(super_type) {
        unoptimizable.add(super_type)
        queue.push(super_type)
      }
    }
  }
}

///|
fn gsi_propagate_globals_to_supers(
  type_globals : Map[TypeIdx, Array[GlobalIdx]],
  unoptimizable : Set[TypeIdx],
  env : Env,
  all_types : Array[TypeIdx],
) -> Unit {
  let snapshot : Array[(TypeIdx, Array[GlobalIdx])] = []
  for type_idx in all_types {
    match type_globals.get(type_idx) {
      Some(globals) => snapshot.push((type_idx, globals.copy()))
      None => ()
    }
  }
  for item in snapshot {
    let (type_idx, globals) = item
    let queue : Array[TypeIdx] = gsi_get_super_types(env, type_idx).copy()
    let seen : Set[TypeIdx] = Set::new()
    let mut i = 0
    while i < queue.length() {
      let curr = queue[i]
      i += 1
      if seen.contains(curr) {
        continue
      }
      seen.add(curr)
      if !unoptimizable.contains(curr) {
        for global_idx in globals {
          gsi_add_type_global(type_globals, curr, global_idx)
        }
      }
      for super_type in gsi_get_super_types(env, curr) {
        queue.push(super_type)
      }
    }
  }
}

///|
fn gsi_is_global_immutable(env : Env, idx : GlobalIdx) -> Bool {
  match env.get_global_type(idx) {
    Some(GlobalType(_, is_mut)) => !is_mut
    None => false
  }
}

///|
fn gsi_is_literal_const(instr : TInstr) -> Bool {
  match instr {
    TI32Const(_) | TI64Const(_) | TF32Const(_) | TF64Const(_) => true
    TRefNull(_) | TRefFunc(_) => true
    TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) => true
    _ => false
  }
}

///|
fn gsi_default_for_val_type(vt : ValType) -> TInstr? {
  match vt {
    NumTypeValType(I32NumType) => Some(TInstr::i32_const(I32(0)))
    NumTypeValType(I64NumType) => Some(TInstr::i64_const(I64(0L)))
    NumTypeValType(F32NumType) => Some(TInstr::f32_const(F32(0.0)))
    NumTypeValType(F64NumType) => Some(TInstr::f64_const(F64(0.0)))
    RefTypeValType(rt) =>
      if rt.is_nullable() {
        Some(TInstr::ref_null(rt.get_heap_type()))
      } else {
        None
      }
    _ => None
  }
}

///|
fn gsi_default_for_storage_type(st : StorageType) -> TInstr? {
  match st {
    ValTypeStorageType(vt) => gsi_default_for_val_type(vt)
    PackTypeStorageType(_) => Some(TInstr::i32_const(I32(0)))
  }
}

///|
fn gsi_struct_field(
  env : Env,
  type_idx : TypeIdx,
  field_idx : @lib.U32,
) -> FieldType? {
  let @lib.U32(iu) = field_idx
  let i = iu.reinterpret_as_int()
  if i < 0 {
    return None
  }
  match env.resolve_struct_fields(type_idx) {
    Ok(fields) => fields.get(i)
    Err(_) => None
  }
}

///|
fn gsi_result_type_for_get(field : FieldType, kind : GSIGetKind) -> ValType? {
  let FieldType(storage, _) = field
  match kind {
    NormalGet =>
      match storage {
        ValTypeStorageType(vt) => Some(vt)
        PackTypeStorageType(_) => None
      }
    SignedGet | UnsignedGet =>
      match storage {
        PackTypeStorageType(_) => Some(ValType::i32())
        ValTypeStorageType(_) => None
      }
  }
}

///|
fn gsi_apply_packed_get(
  value : TInstr,
  pack : @lib.PackType,
  kind : GSIGetKind,
) -> TInstr {
  let (mask, shift) = match pack {
    I8PackType => (0xFF, 24)
    I16PackType => (0xFFFF, 16)
  }
  match kind {
    UnsignedGet =>
      TInstr::binary(BinaryOp::i32_and(), value, TInstr::i32_const(I32(mask)))
    SignedGet => {
      let shl = TInstr::binary(
        BinaryOp::i32_shl(),
        value,
        TInstr::i32_const(I32(shift)),
      )
      TInstr::binary(BinaryOp::i32_shr_s(), shl, TInstr::i32_const(I32(shift)))
    }
    NormalGet => value
  }
}

///|
fn gsi_emit_global_field_read(
  type_idx : TypeIdx,
  field_idx : @lib.U32,
  kind : GSIGetKind,
  global_idx : GlobalIdx,
) -> TInstr {
  let ref_ = TInstr::global_get(global_idx)
  match kind {
    NormalGet => TInstr::struct_get(type_idx, field_idx, ref_)
    SignedGet => TInstr::struct_get_s(type_idx, field_idx, ref_)
    UnsignedGet => TInstr::struct_get_u(type_idx, field_idx, ref_)
  }
}

///|
fn gsi_normalize_global_field_value(
  raw : TInstr,
  field : FieldType,
  kind : GSIGetKind,
  env : Env,
) -> TInstr? {
  let normalized_raw = match raw {
    TGlobalGet(idx) if gsi_is_global_immutable(env, idx) => Some(raw)
    _ if gsi_is_literal_const(raw) => Some(raw)
    _ => None
  }
  match normalized_raw {
    Some(base) => {
      let FieldType(storage, _) = field
      match (storage, kind) {
        (ValTypeStorageType(_), NormalGet) => Some(base)
        (PackTypeStorageType(pack), SignedGet)
        | (PackTypeStorageType(pack), UnsignedGet) =>
          Some(gsi_apply_packed_get(base, pack, kind))
        _ => None
      }
    }
    None => None
  }
}

///|
fn gsi_read_value_from_global(
  global_idx : GlobalIdx,
  field : FieldType,
  field_idx : @lib.U32,
  kind : GSIGetKind,
  analysis : GSIAnalysis,
  env : Env,
) -> GSIReadValue? {
  let @lib.U32(field_idx_u) = field_idx
  let raw = match analysis.global_inits.get(global_idx) {
    Some(GSIInitNew(operands)) => operands.get(field_idx_u.reinterpret_as_int())
    Some(GSIInitDefault) =>
      match field {
        FieldType(storage, _) => gsi_default_for_storage_type(storage)
      }
    None => None
  }
  match raw {
    Some(v) =>
      match gsi_normalize_global_field_value(v, field, kind, env) {
        Some(normalized) => Some(GSIConstValue(normalized))
        None => Some(GSIValueFromGlobal(global_idx))
      }
    None => None
  }
}

///|
fn gsi_read_const_value_from_global(
  global_idx : GlobalIdx,
  field : FieldType,
  field_idx : @lib.U32,
  kind : GSIGetKind,
  analysis : GSIAnalysis,
  env : Env,
) -> TInstr? {
  match
    gsi_read_value_from_global(
      global_idx, field, field_idx, kind, analysis, env,
    ) {
    Some(GSIConstValue(value)) => Some(value)
    _ => None
  }
}

///|
fn gsi_emit_read_value(
  value : GSIReadValue,
  type_idx : TypeIdx,
  field_idx : @lib.U32,
  kind : GSIGetKind,
) -> TInstr {
  match value {
    GSIConstValue(instr) => instr
    GSIValueFromGlobal(global_idx) =>
      gsi_emit_global_field_read(type_idx, field_idx, kind, global_idx)
  }
}

///|
fn gsi_read_values_equal(a : GSIReadValue, b : GSIReadValue) -> Bool {
  match (a, b) {
    (GSIConstValue(v0), GSIConstValue(v1)) => v0 == v1
    (GSIValueFromGlobal(g0), GSIValueFromGlobal(g1)) => g0 == g1
    _ => false
  }
}

///|
fn gsi_collect_values_for_globals(
  globals : Array[GlobalIdx],
  field : FieldType,
  field_idx : @lib.U32,
  kind : GSIGetKind,
  analysis : GSIAnalysis,
  env : Env,
) -> (Array[GSIReadValue], Array[Array[GlobalIdx]])? {
  let values : Array[GSIReadValue] = []
  let groups : Array[Array[GlobalIdx]] = []
  for global_idx in globals {
    let value = match
      gsi_read_value_from_global(
        global_idx, field, field_idx, kind, analysis, env,
      ) {
      Some(v) => v
      None => return None
    }
    let mut grouped = false
    for i = 0; i < values.length(); i = i + 1 {
      if gsi_read_values_equal(values[i], value) {
        groups[i].push(global_idx)
        grouped = true
        break
      }
    }
    if !grouped {
      values.push(value)
      groups.push([global_idx])
      if values.length() > 2 {
        return None
      }
    }
  }
  Some((values, groups))
}

///|
fn gsi_ref_nullability(instr : TInstr, env : Env) -> Bool? {
  match instr {
    TLocalGet(idx) =>
      match env.get_local_type(idx) {
        Some(RefTypeValType(rt)) => Some(rt.is_nullable())
        _ => None
      }
    TGlobalGet(idx) =>
      match env.get_global_type(idx) {
        Some(GlobalType(RefTypeValType(rt), _)) => Some(rt.is_nullable())
        _ => None
      }
    TRefNull(_) => Some(true)
    TRefFunc(_) => Some(false)
    TRefAsNonNull(_) => Some(false)
    TRefCast(nullable, _, _) => Some(nullable)
    TStructNew(_, _) | TStructNewDefault(_) => Some(false)
    TSelect(Some([RefTypeValType(rt)]), _, _, _) => Some(rt.is_nullable())
    TBlock(bt, _) | TLoop(bt, _) | TIf(bt, _, _, _) | TTryTable(bt, _, _) =>
      match env.expand_blocktype(bt) {
        Ok((_, [RefTypeValType(rt)])) => Some(rt.is_nullable())
        _ => None
      }
    TCall(func_idx, _) =>
      match env.get_functype_by_funcidx(func_idx) {
        Some(FuncType(_, [RefTypeValType(rt)])) => Some(rt.is_nullable())
        _ => None
      }
    TCallIndirect(type_idx, _, _, _) | TCallRef(type_idx, _, _) =>
      match env.resolve_functype(type_idx) {
        Some(FuncType(_, [RefTypeValType(rt)])) => Some(rt.is_nullable())
        _ => None
      }
    _ => None
  }
}

///|
fn gsi_ref_with_trap_semantics(ref_ : TInstr, env : Env) -> TInstr? {
  match gsi_ref_nullability(ref_, env) {
    Some(true) => Some(TInstr::ref_as_non_null(ref_))
    Some(false) => Some(ref_)
    None => None
  }
}

///|
fn gsi_select_for_two_values(
  values : Array[TInstr],
  groups : Array[Array[GlobalIdx]],
  result_vt : ValType,
  ref_ : TInstr,
  env : Env,
) -> TInstr? {
  if values.length() != 2 || groups.length() != 2 {
    return None
  }
  let mut single_idx = -1
  if groups[0].length() == 1 {
    single_idx = 0
  } else if groups[1].length() == 1 {
    single_idx = 1
  } else {
    return None
  }
  let other_idx = if single_idx == 0 { 1 } else { 0 }
  let check_global = groups[single_idx][0]
  let checked_ref = match gsi_ref_with_trap_semantics(ref_, env) {
    Some(v) => v
    None => return None
  }
  let cond = TInstr::ref_eq(checked_ref, TInstr::global_get(check_global))
  Some(
    TInstr::select(
      Some([result_vt]),
      cond,
      values[single_idx],
      values[other_idx],
    ),
  )
}

///|
fn gsi_drop_and_value(ref_ : TInstr, value : TInstr, env : Env) -> TInstr? {
  let checked_ref = match gsi_ref_with_trap_semantics(ref_, env) {
    Some(v) => v
    None => return None
  }
  TInstr::block(
    BlockType::void_(),
    TExpr::new([TInstr::drop(checked_ref), value]),
  )
  |> Some
}

///|
fn gsi_optimize_struct_get(
  type_idx : TypeIdx,
  field_idx : @lib.U32,
  ref_ : TInstr,
  kind : GSIGetKind,
  state : GSIRewriteState,
) -> TInstr? {
  let field = match gsi_struct_field(state.env, type_idx, field_idx) {
    Some(field) => field
    None => return None
  }
  let FieldType(_, mutability) = field
  if mutability == Var {
    return None
  }
  let result_vt = match gsi_result_type_for_get(field, kind) {
    Some(vt) => vt
    None => return None
  }

  // Trivial direct-global case.
  match ref_ {
    TGlobalGet(global_idx) if gsi_is_global_immutable(state.env, global_idx) =>
      match
        gsi_read_const_value_from_global(
          global_idx,
          field,
          field_idx,
          kind,
          state.analysis,
          state.env,
        ) {
        Some(value) => return Some(value)
        None => ()
      }
    _ => ()
  }
  let globals = match state.analysis.type_globals.get(type_idx) {
    Some(globals) if !globals.is_empty() => globals
    _ => return None
  }
  if globals.length() == 1 {
    let value = match
      gsi_read_value_from_global(
        globals[0],
        field,
        field_idx,
        kind,
        state.analysis,
        state.env,
      ) {
      Some(value) => value
      None => return None
    }
    match ref_ {
      TGlobalGet(ref_global) =>
        match value {
          GSIValueFromGlobal(value_global) =>
            if ref_global == value_global {
              return None
            } else {
              ()
            }
          _ => ()
        }
      _ => ()
    }
    return gsi_drop_and_value(
      ref_,
      gsi_emit_read_value(value, type_idx, field_idx, kind),
      state.env,
    )
  }
  let (values, groups) = match
    gsi_collect_values_for_globals(
      globals,
      field,
      field_idx,
      kind,
      state.analysis,
      state.env,
    ) {
    Some(pair) => pair
    None => return None
  }
  let materialized_values : Array[TInstr] = []
  for value in values {
    materialized_values.push(
      gsi_emit_read_value(value, type_idx, field_idx, kind),
    )
  }
  if materialized_values.length() == 1 {
    return gsi_drop_and_value(ref_, materialized_values[0], state.env)
  }
  gsi_select_for_two_values(
    materialized_values,
    groups,
    result_vt,
    ref_,
    state.env,
  )
}

///|
fn gsi_optimize_tinstruction(instr : TInstr, state : GSIRewriteState) -> TInstr {
  match instr {
    TStructGet(type_idx, field_idx, ref_) =>
      match
        gsi_optimize_struct_get(type_idx, field_idx, ref_, NormalGet, state) {
        Some(new_instr) => new_instr
        None => instr
      }
    TStructGetS(type_idx, field_idx, ref_) =>
      match
        gsi_optimize_struct_get(type_idx, field_idx, ref_, SignedGet, state) {
        Some(new_instr) => new_instr
        None => instr
      }
    TStructGetU(type_idx, field_idx, ref_) =>
      match
        gsi_optimize_struct_get(type_idx, field_idx, ref_, UnsignedGet, state) {
        Some(new_instr) => new_instr
        None => instr
      }
    _ => instr
  }
}

///|
fn gsi_rewrite_func(
  transformer : ModuleTransformer[GSIRewriteState],
  state : GSIRewriteState,
  func : Func,
) -> TransformerResult[GSIRewriteState, Func] {
  match func {
    Func(_, _) => unchanged()
    TFunc(locals, body) => {
      let local_state = GSIRewriteState::{
        ..state,
        env: state.env.with_locals(locals),
      }
      match transformer.walk_texpr(local_state, body) {
        Ok(Some((_, new_body))) =>
          if new_body != body {
            change(state, Func::t_func(locals, new_body))
          } else {
            unchanged()
          }
        Ok(None) => unchanged()
        Err(e) => Err(e)
      }
    }
  }
}

///|
fn gsi_rewrite_tinstruction(
  transformer : ModuleTransformer[GSIRewriteState],
  state : GSIRewriteState,
  instr : TInstr,
) -> TransformerResult[GSIRewriteState, TInstr] {
  let walked = match transformer.walk_tinstruction_default(state, instr) {
    Ok(Some((next_state, next_instr))) => {
      let optimized_instr = gsi_optimize_tinstruction(next_instr, next_state)
      if optimized_instr != instr {
        return change(next_state, optimized_instr)
      }
      return if next_instr != instr {
        change(next_state, next_instr)
      } else {
        unchanged()
      }
    }
    Ok(None) => instr
    Err(e) => return Err(e)
  }
  let optimized_instr = gsi_optimize_tinstruction(walked, state)
  if optimized_instr != instr {
    change(state, optimized_instr)
  } else {
    unchanged()
  }
}

///|
fn analyze_global_struct_inference(mod : Module) -> Result[GSIAnalysis, String] {
  let env = Env::new().with_module(mod)
  let created_in_funcs : Set[TypeIdx] = Set::new()
  match mod.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        match func {
          TFunc(_, body) =>
            gsi_collect_struct_types_in_texpr(body, created_in_funcs)
          Func(_, _) => return Err("global_struct_inference: expected TFunc")
        }
      }
    None => ()
  }
  let unoptimizable : Set[TypeIdx] = created_in_funcs.copy()
  let type_globals : Map[TypeIdx, Array[GlobalIdx]] = Map::new()
  let global_inits : Map[GlobalIdx, GSIGlobalInit] = Map::new()
  let imported_globals = gsi_count_imported_globals(mod)
  match mod.global_sec {
    Some(GlobalSec(globals)) =>
      for i = 0; i < globals.length(); i = i + 1 {
        let global_idx = GlobalIdx::new(
          imported_globals + i.reinterpret_as_uint(),
        )
        let Global(GlobalType(vt, is_mut), init) = globals[i]
        let root = match gsi_single_root_init(init, env) {
          Some(root) => root
          None => continue
        }

        // Nested struct.new/default types in global init are unoptimizable.
        match root {
          TStructNew(_, operands) =>
            for operand in operands {
              gsi_collect_struct_types_in_tinstr(operand, unoptimizable)
            }
          TStructNewDefault(_) => ()
          _ => gsi_collect_struct_types_in_tinstr(root, unoptimizable)
        }
        let root_type = match gsi_global_root_type(root) {
          Some(type_idx) => type_idx
          None => continue
        }
        if !gsi_is_eqref_compatible(vt, env) || is_mut {
          unoptimizable.add(root_type)
          continue
        }
        gsi_add_type_global(type_globals, root_type, global_idx)
        match gsi_global_root_init_info(root) {
          Some(info) => global_inits[global_idx] = info
          None => ()
        }
      }
    None => ()
  }
  gsi_propagate_unoptimizable_to_supers(unoptimizable, env)
  for type_idx in unoptimizable {
    ignore(type_globals.remove(type_idx))
  }
  let all_types = gsi_collect_all_type_indices(mod)
  gsi_propagate_globals_to_supers(type_globals, unoptimizable, env, all_types)
  Ok({ type_globals, global_inits })
}

///|
fn run_global_struct_inference(
  mod : Module,
  optimize_to_desc_casts : Bool,
) -> Result[Module, String] {
  let analysis = match analyze_global_struct_inference(mod) {
    Ok(analysis) => analysis
    Err(e) => return Err(e)
  }

  // This IR does not expose descriptor-cast instructions. Keep this
  // compatibility flag wired for pipeline parity.
  ignore(optimize_to_desc_casts)
  let state = GSIRewriteState::{ env: Env::new().with_module(mod), analysis }
  let pass = ModuleTransformer::new()
    .on_func_evt(gsi_rewrite_func)
    .on_tinstruction_evt(gsi_rewrite_tinstruction)
  match pass.walk_module(state, mod) {
    Ok(Some((_, new_mod))) => Ok(new_mod)
    Ok(None) => Ok(mod)
    Err(e) => Err(e)
  }
}

///|
test "global struct inference rewrites struct.get from singleton inferred globals" {
  let field = FieldType::new(StorageType::val_type(ValType::i32()), Const)
  let ty = single_rec_type(comp_type_sub_type(struct_comp_type([field])))
  let global_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([ty]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(global_ref, false),
          Expr::new([
            Instruction::i32_const(I32(42)),
            Instruction::struct_new(TypeIdx::new(0)),
          ]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [global_ref],
          TExpr::new([
            TInstr::drop(
              TInstr::struct_get(
                TypeIdx::new(0),
                U32(0),
                TInstr::local_get(LocalIdx::new(0)),
              ),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match run_global_struct_inference(mod, false) {
    Ok(m) => m
    Err(e) => fail("unexpected global_struct_inference error: \{e}")
  }
  match optimized.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            TExpr(
              [
                TDrop(
                  TBlock(_, TExpr([TDrop(TRefAsNonNull(_)), TI32Const(I32(v))]))
                ),
              ]
            )
          ),
        ]
      )
    ) => assert_eq(v, 42)
    _ =>
      fail(
        "expected singleton struct.get rewrite to dropped block with constant",
      )
  }
}

///|
test "global struct inference rewrites two-value struct.get to select with ref.eq" {
  let field = FieldType::new(StorageType::val_type(ValType::i32()), Const)
  let ty = single_rec_type(comp_type_sub_type(struct_comp_type([field])))
  let global_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([ty]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(global_ref, false),
          Expr::new([
            Instruction::i32_const(I32(7)),
            Instruction::struct_new(TypeIdx::new(0)),
          ]),
        ),
        Global::new(
          GlobalType::new(global_ref, false),
          Expr::new([
            Instruction::i32_const(I32(9)),
            Instruction::struct_new(TypeIdx::new(0)),
          ]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [global_ref],
          TExpr::new([
            TInstr::drop(
              TInstr::struct_get(
                TypeIdx::new(0),
                U32(0),
                TInstr::local_get(LocalIdx::new(0)),
              ),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match run_global_struct_inference(mod, false) {
    Ok(m) => m
    Err(e) => fail("unexpected global_struct_inference error: \{e}")
  }
  match optimized.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            TExpr(
              [TDrop(TSelect(_, TRefEq(TRefAsNonNull(_), TGlobalGet(_)), _, _))]
            )
          ),
        ]
      )
    ) => ()
    _ => fail("expected two-value struct.get rewrite to select/ref.eq pattern")
  }
}

///|
test "global struct inference groups >2 globals into two values" {
  let field = FieldType::new(StorageType::val_type(ValType::i32()), Const)
  let ty = single_rec_type(comp_type_sub_type(struct_comp_type([field])))
  let global_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([ty]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(global_ref, false),
          Expr::new([
            Instruction::i32_const(I32(42)),
            Instruction::struct_new(TypeIdx::new(0)),
          ]),
        ),
        Global::new(
          GlobalType::new(global_ref, false),
          Expr::new([
            Instruction::i32_const(I32(42)),
            Instruction::struct_new(TypeIdx::new(0)),
          ]),
        ),
        Global::new(
          GlobalType::new(global_ref, false),
          Expr::new([
            Instruction::i32_const(I32(1337)),
            Instruction::struct_new(TypeIdx::new(0)),
          ]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [global_ref],
          TExpr::new([
            TInstr::drop(
              TInstr::struct_get(
                TypeIdx::new(0),
                U32(0),
                TInstr::local_get(LocalIdx::new(0)),
              ),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match run_global_struct_inference(mod, false) {
    Ok(m) => m
    Err(e) => fail("unexpected global_struct_inference error: \{e}")
  }
  match optimized.code_sec {
    Some(
      CodeSec(
        [TFunc(_, TExpr([TDrop(TSelect(_, TRefEq(_, TGlobalGet(_)), _, _))]))]
      )
    ) => ()
    _ => fail("expected grouped two-value select rewrite with >2 globals")
  }
}

///|
test "global struct inference handles non-null struct.get operands without ref.as_non_null" {
  let field = FieldType::new(StorageType::val_type(ValType::i32()), Const)
  let ty = single_rec_type(comp_type_sub_type(struct_comp_type([field])))
  let non_null_ref = ValType::ref_type(
    RefType::new(false, HeapType::new(TypeIdx::new(0))),
  )
  let nullable_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([ty]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(nullable_ref, false),
          Expr::new([
            Instruction::i32_const(I32(11)),
            Instruction::struct_new(TypeIdx::new(0)),
          ]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [non_null_ref],
          TExpr::new([
            TInstr::drop(
              TInstr::struct_get(
                TypeIdx::new(0),
                U32(0),
                TInstr::local_get(LocalIdx::new(0)),
              ),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match run_global_struct_inference(mod, false) {
    Ok(m) => m
    Err(e) => fail("unexpected global_struct_inference error: \{e}")
  }
  match optimized.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            TExpr(
              [
                TDrop(
                  TBlock(_, TExpr([TDrop(TLocalGet(_)), TI32Const(I32(v))]))
                ),
              ]
            )
          ),
        ]
      )
    ) => assert_eq(v, 11)
    _ =>
      fail(
        "expected non-null operand rewrite to use drop(local.get) without ref.as_non_null",
      )
  }
}

///|
test "global struct inference propagates globals through supertypes" {
  let super_field = FieldType::new(StorageType::val_type(ValType::i32()), Const)
  let super_st = SubType::comp_type(struct_comp_type([super_field]))
  let sub_st = SubType::new(
    false,
    [TypeIdx::new(0)],
    struct_comp_type([super_field]),
  )
  let super_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let sub_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(1))),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([RecType::new(super_st), RecType::new(sub_st)]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(sub_ref, false),
          Expr::new([
            Instruction::i32_const(I32(5)),
            Instruction::struct_new(TypeIdx::new(1)),
          ]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [super_ref],
          TExpr::new([
            TInstr::drop(
              TInstr::struct_get(
                TypeIdx::new(0),
                U32(0),
                TInstr::local_get(LocalIdx::new(0)),
              ),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match run_global_struct_inference(mod, false) {
    Ok(m) => m
    Err(e) => fail("unexpected global_struct_inference error: \{e}")
  }
  match optimized.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            TExpr(
              [
                TDrop(
                  TBlock(_, TExpr([TDrop(TRefAsNonNull(_)), TI32Const(I32(v))]))
                ),
              ]
            )
          ),
        ]
      )
    ) => assert_eq(v, 5)
    _ => fail("expected supertype struct.get rewrite from subtype global")
  }
}

///|
test "global struct inference does not optimize mutable struct fields" {
  let field = FieldType::new(StorageType::val_type(ValType::i32()), Var)
  let ty = single_rec_type(comp_type_sub_type(struct_comp_type([field])))
  let global_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let get_instr = TInstr::struct_get(
    TypeIdx::new(0),
    U32(0),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([ty]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(global_ref, false),
          Expr::new([
            Instruction::i32_const(I32(7)),
            Instruction::struct_new(TypeIdx::new(0)),
          ]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([Func::t_func([global_ref], TExpr::new([get_instr]))]),
    )
  let optimized = match run_global_struct_inference(mod, false) {
    Ok(m) => m
    Err(e) => fail("unexpected global_struct_inference error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([instr]))])) => assert_eq(instr, get_instr)
    _ => fail("expected unoptimized mutable-field struct.get")
  }
}

///|
test "global struct inference does not optimize when struct type is created in code" {
  let field = FieldType::new(StorageType::val_type(ValType::i32()), Const)
  let ty = single_rec_type(comp_type_sub_type(struct_comp_type([field])))
  let global_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let get_instr = TInstr::struct_get(
    TypeIdx::new(0),
    U32(0),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([ty]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(global_ref, false),
          Expr::new([
            Instruction::i32_const(I32(3)),
            Instruction::struct_new(TypeIdx::new(0)),
          ]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::drop(
              TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(9))]),
            ),
          ]),
        ),
        Func::t_func([global_ref], TExpr::new([get_instr])),
      ]),
    )
  let optimized = match run_global_struct_inference(mod, false) {
    Ok(m) => m
    Err(e) => fail("unexpected global_struct_inference error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([_, TFunc(_, TExpr([instr]))])) => assert_eq(instr, get_instr)
    _ =>
      fail(
        "expected unoptimized struct.get when matching struct.new exists in code",
      )
  }
}

///|
test "global struct inference does not optimize when source global is mutable" {
  let field = FieldType::new(StorageType::val_type(ValType::i32()), Const)
  let ty = single_rec_type(comp_type_sub_type(struct_comp_type([field])))
  let global_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let get_instr = TInstr::struct_get(
    TypeIdx::new(0),
    U32(0),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([ty]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(global_ref, true),
          Expr::new([
            Instruction::i32_const(I32(7)),
            Instruction::struct_new(TypeIdx::new(0)),
          ]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([Func::t_func([global_ref], TExpr::new([get_instr]))]),
    )
  let optimized = match run_global_struct_inference(mod, false) {
    Ok(m) => m
    Err(e) => fail("unexpected global_struct_inference error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([instr]))])) => assert_eq(instr, get_instr)
    _ => fail("expected unoptimized struct.get for mutable source global")
  }
}

///|
test "global struct inference does not optimize with more than two unique values" {
  let field = FieldType::new(StorageType::val_type(ValType::i32()), Const)
  let ty = single_rec_type(comp_type_sub_type(struct_comp_type([field])))
  let global_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let get_instr = TInstr::struct_get(
    TypeIdx::new(0),
    U32(0),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([ty]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(global_ref, false),
          Expr::new([
            Instruction::i32_const(I32(1)),
            Instruction::struct_new(TypeIdx::new(0)),
          ]),
        ),
        Global::new(
          GlobalType::new(global_ref, false),
          Expr::new([
            Instruction::i32_const(I32(2)),
            Instruction::struct_new(TypeIdx::new(0)),
          ]),
        ),
        Global::new(
          GlobalType::new(global_ref, false),
          Expr::new([
            Instruction::i32_const(I32(3)),
            Instruction::struct_new(TypeIdx::new(0)),
          ]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([Func::t_func([global_ref], TExpr::new([get_instr]))]),
    )
  let optimized = match run_global_struct_inference(mod, false) {
    Ok(m) => m
    Err(e) => fail("unexpected global_struct_inference error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([instr]))])) => assert_eq(instr, get_instr)
    _ => fail("expected unoptimized struct.get with >2 distinct values")
  }
}

///|
test "global struct inference folds direct immutable global struct.get to constant" {
  let field = FieldType::new(StorageType::val_type(ValType::i32()), Const)
  let ty = single_rec_type(comp_type_sub_type(struct_comp_type([field])))
  let global_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([ty]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(global_ref, false),
          Expr::new([
            Instruction::i32_const(I32(99)),
            Instruction::struct_new(TypeIdx::new(0)),
          ]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::struct_get(
              TypeIdx::new(0),
              U32(0),
              TInstr::global_get(GlobalIdx::new(0)),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match run_global_struct_inference(mod, false) {
    Ok(m) => m
    Err(e) => fail("unexpected global_struct_inference error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TI32Const(I32(v))]))])) => assert_eq(v, 99)
    _ => fail("expected direct global struct.get to fold to constant")
  }
}

///|
test "global struct inference rewrites singleton non-constant values via known global read" {
  let outer_field = FieldType::new(
    StorageType::val_type(
      ValType::ref_type(RefType::new(true, HeapType::new(TypeIdx::new(1)))),
    ),
    Const,
  )
  let inner_field = FieldType::new(StorageType::val_type(ValType::i32()), Const)
  let outer_ty = single_rec_type(
    comp_type_sub_type(struct_comp_type([outer_field])),
  )
  let inner_ty = single_rec_type(
    comp_type_sub_type(struct_comp_type([inner_field])),
  )
  let outer_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([outer_ty, inner_ty]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(outer_ref, false),
          Expr::new([
            Instruction::i32_const(I32(9)),
            Instruction::struct_new(TypeIdx::new(1)),
            Instruction::struct_new(TypeIdx::new(0)),
          ]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [outer_ref],
          TExpr::new([
            TInstr::drop(
              TInstr::struct_get(
                TypeIdx::new(0),
                U32(0),
                TInstr::local_get(LocalIdx::new(0)),
              ),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match run_global_struct_inference(mod, false) {
    Ok(m) => m
    Err(e) => fail("unexpected global_struct_inference error: \{e}")
  }
  match optimized.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            TExpr(
              [
                TDrop(
                  TBlock(
                    _,
                    TExpr(
                      [TDrop(TRefAsNonNull(_)), TStructGet(_, _, TGlobalGet(_))]
                    )
                  )
                ),
              ]
            )
          ),
        ]
      )
    ) => ()
    _ =>
      fail(
        "expected singleton non-constant rewrite to read value from inferred global",
      )
  }
}

///|
test "global struct inference rewrites non-constant two-value case to select" {
  let outer_field = FieldType::new(
    StorageType::val_type(
      ValType::ref_type(RefType::new(true, HeapType::new(TypeIdx::new(1)))),
    ),
    Const,
  )
  let inner_field = FieldType::new(StorageType::val_type(ValType::i32()), Const)
  let outer_ty = single_rec_type(
    comp_type_sub_type(struct_comp_type([outer_field])),
  )
  let inner_ty = single_rec_type(
    comp_type_sub_type(struct_comp_type([inner_field])),
  )
  let outer_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([outer_ty, inner_ty]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(outer_ref, false),
          Expr::new([
            Instruction::i32_const(I32(1)),
            Instruction::struct_new(TypeIdx::new(1)),
            Instruction::struct_new(TypeIdx::new(0)),
          ]),
        ),
        Global::new(
          GlobalType::new(outer_ref, false),
          Expr::new([
            Instruction::i32_const(I32(2)),
            Instruction::struct_new(TypeIdx::new(1)),
            Instruction::struct_new(TypeIdx::new(0)),
          ]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [outer_ref],
          TExpr::new([
            TInstr::drop(
              TInstr::struct_get(
                TypeIdx::new(0),
                U32(0),
                TInstr::local_get(LocalIdx::new(0)),
              ),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match run_global_struct_inference(mod, false) {
    Ok(m) => m
    Err(e) => fail("unexpected global_struct_inference error: \{e}")
  }
  match optimized.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            TExpr(
              [
                TDrop(
                  TSelect(
                    _,
                    TRefEq(TRefAsNonNull(_), TGlobalGet(_)),
                    TStructGet(_, _, TGlobalGet(_)),
                    TStructGet(_, _, TGlobalGet(_))
                  )
                ),
              ]
            )
          ),
        ]
      )
    ) => ()
    _ =>
      fail(
        "expected non-constant two-value rewrite to select/ref.eq with global field reads",
      )
  }
}

///|
test "global struct inference avoids direct-global non-constant pessimization" {
  let outer_field = FieldType::new(
    StorageType::val_type(
      ValType::ref_type(RefType::new(true, HeapType::new(TypeIdx::new(1)))),
    ),
    Const,
  )
  let inner_field = FieldType::new(StorageType::val_type(ValType::i32()), Const)
  let outer_ty = single_rec_type(
    comp_type_sub_type(struct_comp_type([outer_field])),
  )
  let inner_ty = single_rec_type(
    comp_type_sub_type(struct_comp_type([inner_field])),
  )
  let outer_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let get_instr = TInstr::struct_get(
    TypeIdx::new(0),
    U32(0),
    TInstr::global_get(GlobalIdx::new(0)),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([outer_ty, inner_ty]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(outer_ref, false),
          Expr::new([
            Instruction::i32_const(I32(9)),
            Instruction::struct_new(TypeIdx::new(1)),
            Instruction::struct_new(TypeIdx::new(0)),
          ]),
        ),
      ]),
    )
    .with_code_sec(CodeSec::new([Func::t_func([], TExpr::new([get_instr]))]))
  let optimized = match run_global_struct_inference(mod, false) {
    Ok(m) => m
    Err(e) => fail("unexpected global_struct_inference error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([instr]))])) => assert_eq(instr, get_instr)
    _ => fail("expected direct-global non-constant read to stay unchanged")
  }
}

///|
test "global struct inference handles struct.get_u defaults for packed fields" {
  let packed_field = FieldType::new(
    StorageType::pack_type(PackType::i8()),
    Const,
  )
  let ty = single_rec_type(comp_type_sub_type(struct_comp_type([packed_field])))
  let global_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([ty]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(global_ref, false),
          Expr::new([Instruction::struct_new_default(TypeIdx::new(0))]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [global_ref],
          TExpr::new([
            TInstr::drop(
              TInstr::struct_get_u(
                TypeIdx::new(0),
                U32(0),
                TInstr::local_get(LocalIdx::new(0)),
              ),
            ),
          ]),
        ),
      ]),
    )
  let original_get = TInstr::struct_get_u(
    TypeIdx::new(0),
    U32(0),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let optimized = match run_global_struct_inference(mod, false) {
    Ok(m) => m
    Err(e) => fail("unexpected global_struct_inference error: \{e}")
  }
  match optimized.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            TExpr(
              [TDrop(TBlock(_, TExpr([TDrop(TRefAsNonNull(_)), read_value])))]
            )
          ),
        ]
      )
    ) => assert_true(read_value != original_get)
    _ => fail("expected packed default get_u rewrite through inferred globals")
  }
}

///|
test "global struct inference does not optimize non-eqref declared globals" {
  let field = FieldType::new(StorageType::val_type(ValType::i32()), Const)
  let ty = single_rec_type(comp_type_sub_type(struct_comp_type([field])))
  let struct_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let get_instr = TInstr::struct_get(
    TypeIdx::new(0),
    U32(0),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([ty]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::anyref(), false),
          Expr::new([
            Instruction::i32_const(I32(7)),
            Instruction::struct_new(TypeIdx::new(0)),
          ]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([Func::t_func([struct_ref], TExpr::new([get_instr]))]),
    )
  let optimized = match run_global_struct_inference(mod, false) {
    Ok(m) => m
    Err(e) => fail("unexpected global_struct_inference error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([instr]))])) => assert_eq(instr, get_instr)
    _ => fail("expected no rewrite for non-eqref declared source global")
  }
}

///|
test "global struct inference propagates unoptimizable subtypes to supertypes" {
  let super_field = FieldType::new(StorageType::val_type(ValType::i32()), Const)
  let super_st = SubType::comp_type(struct_comp_type([super_field]))
  let sub_st = SubType::new(
    false,
    [TypeIdx::new(0)],
    struct_comp_type([super_field]),
  )
  let super_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let sub_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(1))),
  )
  let get_instr = TInstr::struct_get(
    TypeIdx::new(0),
    U32(0),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([RecType::new(super_st), RecType::new(sub_st)]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(sub_ref, false),
          Expr::new([
            Instruction::i32_const(I32(5)),
            Instruction::struct_new(TypeIdx::new(1)),
          ]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::drop(
              TInstr::struct_new(TypeIdx::new(1), [TInstr::i32_const(I32(7))]),
            ),
          ]),
        ),
        Func::t_func([super_ref], TExpr::new([get_instr])),
      ]),
    )
  let optimized = match run_global_struct_inference(mod, false) {
    Ok(m) => m
    Err(e) => fail("unexpected global_struct_inference error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([_, TFunc(_, TExpr([instr]))])) => assert_eq(instr, get_instr)
    _ =>
      fail(
        "expected supertype read to remain when subtype can be created in code",
      )
  }
}

///|
test "global struct inference descriptor mode remains a no-op without desc ops" {
  let field = FieldType::new(StorageType::val_type(ValType::i32()), Const)
  let ty = single_rec_type(comp_type_sub_type(struct_comp_type([field])))
  let cast_instr = TInstr::ref_cast(
    false,
    HeapType::new(TypeIdx::new(0)),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([ty]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::anyref()],
          TExpr::new([TInstr::drop(cast_instr)]),
        ),
      ]),
    )
  let optimized = match run_global_struct_inference(mod, true) {
    Ok(m) => m
    Err(e) => fail("unexpected global_struct_inference error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TDrop(instr)]))])) =>
      assert_eq(instr, cast_instr)
    _ => fail("expected descriptor-mode ref.cast behavior to be unchanged")
  }
}
