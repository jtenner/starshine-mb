///| 
/// Copyright 2023 WebAssembly Community Group participants
/// 
/// Licensed under the Apache License, Version 2.0 (the "License");
/// you may not use this file except in compliance with the License.
/// You may obtain a copy of the License at
/// 
///     http://www.apache.org/licenses/LICENSE-2.0
/// 
/// Unless required by applicable law or agreed to in writing, software
/// distributed under the License is distributed on an "AS IS" BASIS,
/// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
/// See the License for the specific language governing permissions and
/// limitations under the License.
///

///|
priv struct HSOState {
  env : Env
}

///|
priv struct HSOLocalGetInfo {
  local_idx : LocalIdx
  top_instr_idx : Int
}

///|
priv struct HSOEffects {
  locals_read : Set[LocalIdx]
  locals_written : Set[LocalIdx]
  mut reads_memory : Bool
  mut writes_memory : Bool
  mut reads_globals : Bool
  mut writes_globals : Bool
  mut calls : Bool
  mut branches : Bool
  mut traps : Bool
  mut throws : Bool
}

///|
fn HSOEffects::new() -> HSOEffects {
  {
    locals_read: Set::new(),
    locals_written: Set::new(),
    reads_memory: false,
    writes_memory: false,
    reads_globals: false,
    writes_globals: false,
    calls: false,
    branches: false,
    traps: false,
    throws: false,
  }
}

///|
fn HSOEffects::invalidates(self : HSOEffects, other : HSOEffects) -> Bool {
  for local_idx in self.locals_written {
    if other.locals_read.contains(local_idx) ||
      other.locals_written.contains(local_idx) {
      return true
    }
  }
  for local_idx in self.locals_read {
    if other.locals_written.contains(local_idx) {
      return true
    }
  }
  if (self.reads_memory && other.writes_memory) ||
    (self.writes_memory && other.reads_memory) ||
    (self.writes_memory && other.writes_memory) {
    return true
  }
  if (self.reads_globals && other.writes_globals) ||
    (self.writes_globals && other.reads_globals) ||
    (self.writes_globals && other.writes_globals) {
    return true
  }
  if self.calls || other.calls {
    if self.reads_memory ||
      self.writes_memory ||
      other.reads_memory ||
      other.writes_memory ||
      self.reads_globals ||
      self.writes_globals ||
      other.reads_globals ||
      other.writes_globals {
      return true
    }
  }
  if self.transfers_control_flow() || other.transfers_control_flow() {
    return true
  }
  if (self.traps && other.has_unremovable_side_effects()) ||
    (other.traps && self.has_unremovable_side_effects()) {
    return true
  }
  false
}

///|
fn HSOEffects::transfers_control_flow(self : HSOEffects) -> Bool {
  self.branches || self.throws
}

///|
fn HSOEffects::has_unremovable_side_effects(self : HSOEffects) -> Bool {
  self.writes_memory ||
  self.writes_globals ||
  self.calls ||
  self.branches ||
  self.throws ||
  self.traps ||
  self.reads_memory ||
  self.locals_written.length() > 0
}

///|
fn HSOEffects::has_non_control_side_effects(self : HSOEffects) -> Bool {
  self.writes_memory ||
  self.writes_globals ||
  self.calls ||
  self.traps ||
  self.reads_memory ||
  self.reads_globals ||
  self.locals_written.length() > 0
}

///|
fn hso_collect_effects(instr : TInstr) -> HSOEffects {
  let effects = HSOEffects::new()
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    match curr {
      TLocalGet(idx) => effects.locals_read.add(idx)
      TLocalSet(idx, _) => effects.locals_written.add(idx)
      TLocalTee(idx, _) => {
        effects.locals_read.add(idx)
        effects.locals_written.add(idx)
      }
      TGlobalGet(_) => effects.reads_globals = true
      TGlobalSet(_, _) => effects.writes_globals = true
      TLoad(_, _, _) => {
        effects.reads_memory = true
        effects.traps = true
      }
      TStore(_, _, _, _) => {
        effects.writes_memory = true
        effects.traps = true
      }
      TMemoryGrow(_, _) => effects.writes_memory = true
      TMemorySize(_) => effects.reads_memory = true
      TMemoryCopy(_, _, _, _, _) => {
        effects.reads_memory = true
        effects.writes_memory = true
      }
      TMemoryFill(_, _, _, _) => effects.writes_memory = true
      TMemoryInit(_, _, _, _, _) => {
        effects.reads_memory = true
        effects.writes_memory = true
      }
      TDataDrop(_) => effects.writes_memory = true
      TMemoryAtomicNotify(_, _, _)
      | TMemoryAtomicWait32(_, _, _, _)
      | TMemoryAtomicWait64(_, _, _, _) => {
        effects.reads_memory = true
        effects.traps = true
      }
      TAtomicRmw(_, _, _, _) | TAtomicCmpxchg(_, _, _, _, _) => {
        effects.reads_memory = true
        effects.writes_memory = true
        effects.traps = true
      }
      TAtomicFence =>
        // Keep ordering-sensitive synchronization effects as memory reads.
        effects.reads_memory = true
      TTableSet(_, _, _) | TTableGrow(_, _, _) | TTableFill(_, _, _, _) =>
        effects.writes_memory = true
      TTableGet(_, _) | TTableSize(_) => effects.reads_memory = true
      TTableCopy(_, _, _, _, _) | TTableInit(_, _, _, _, _) | TElemDrop(_) => {
        effects.reads_memory = true
        effects.writes_memory = true
      }
      TCall(_, _) | TCallIndirect(_, _, _, _) | TCallRef(_, _, _) =>
        effects.calls = true
      TReturnCall(_, _)
      | TReturnCallIndirect(_, _, _, _)
      | TReturnCallRef(_, _, _) => {
        effects.calls = true
        effects.branches = true
      }
      TBr(_, _)
      | TBrIf(_, _, _)
      | TBrTable(_, _, _, _)
      | TBrOnNull(_, _, _)
      | TBrOnNonNull(_, _, _)
      | TBrOnCast(_, _, _, _, _, _)
      | TBrOnCastFail(_, _, _, _, _, _)
      | TReturn(_) => effects.branches = true
      TThrow(_, _) => {
        effects.throws = true
        effects.branches = true
      }
      TThrowRef(_) => {
        effects.throws = true
        effects.branches = true
      }
      TUnreachable => effects.traps = true
      TRefAsNonNull(_) | TRefCast(_, _, _) => effects.traps = true
      TStructGet(_, _, _) | TStructGetS(_, _, _) | TStructGetU(_, _, _) => {
        effects.reads_memory = true
        effects.traps = true
      }
      TStructSet(_, _, _, _) => {
        effects.writes_memory = true
        effects.traps = true
      }
      TArrayNew(_, _, _)
      | TArrayNewDefault(_, _)
      | TArrayNewFixed(_, _)
      | TArrayNewData(_, _, _, _)
      | TArrayNewElem(_, _, _, _) => {
        effects.writes_memory = true
        effects.traps = true
      }
      TArrayGet(_, _, _)
      | TArrayGetS(_, _, _)
      | TArrayGetU(_, _, _)
      | TArrayLen(_) => {
        effects.reads_memory = true
        effects.traps = true
      }
      TArraySet(_, _, _, _)
      | TArrayFill(_, _, _, _, _)
      | TArrayCopy(_, _, _, _, _, _, _)
      | TArrayInitData(_, _, _, _, _, _)
      | TArrayInitElem(_, _, _, _, _, _) => {
        effects.reads_memory = true
        effects.writes_memory = true
        effects.traps = true
      }
      TBinary(op, _, _) =>
        match op {
          I32DivSOp
          | I32DivUOp
          | I32RemSOp
          | I32RemUOp
          | I64DivSOp
          | I64DivUOp
          | I64RemSOp
          | I64RemUOp => effects.traps = true
          _ => ()
        }
      TUnary(op, _) =>
        match op {
          I32TruncF32SOp
          | I32TruncF32UOp
          | I32TruncF64SOp
          | I32TruncF64UOp
          | I64TruncF32SOp
          | I64TruncF32UOp
          | I64TruncF64SOp
          | I64TruncF64UOp => effects.traps = true
          _ => ()
        }
      _ => ()
    }
    self.walk_tinstruction_default((), curr)
  })
  ignore(walker.walk_tinstruction((), instr))
  effects
}

///|
fn hso_u32_to_int(i : @lib.U32) -> Int {
  let @lib.U32(raw) = i
  raw.reinterpret_as_int()
}

///|
fn hso_struct_field_default(field : FieldType) -> TInstr? {
  match field.get_storage_type() {
    PackTypeStorageType(_) => Some(TInstr::i32_const(I32(0)))
    ValTypeStorageType(vt) =>
      match vt {
        NumTypeValType(nt) =>
          match nt {
            I32NumType => Some(TInstr::i32_const(I32(0)))
            I64NumType => Some(TInstr::i64_const(I64(0L)))
            F32NumType => Some(TInstr::f32_const(F32(0.0)))
            F64NumType => Some(TInstr::f64_const(F64(0.0)))
          }
        VecTypeValType =>
          Some(
            TInstr::v128_const(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
          )
        RefTypeValType(rt) =>
          if rt.is_nullable() {
            Some(TInstr::ref_null(rt.get_heap_type()))
          } else {
            None
          }
        BotValType => None
      }
  }
}

///|
fn hso_is_struct_new_like(instr : TInstr) -> Bool {
  match instr {
    TStructNew(_, _) | TStructNewDefault(_) => true
    _ => false
  }
}

///|
fn hso_flatten_instrs_with_origin(
  instrs : Array[TInstr],
  origin : Int,
  flat : Array[TInstr],
  origins : Array[Int],
) -> Unit {
  for instr in instrs {
    match instr {
      TIf(bt, cond, then_expr, else_expr) => {
        flat.push(TInstr::if_(bt, cond, TExpr::new([]), None))
        origins.push(origin)
        hso_flatten_instrs_with_origin(then_expr.0, origin, flat, origins)
        if else_expr is Some(other) {
          hso_flatten_instrs_with_origin(other.0, origin, flat, origins)
        }
      }
      _ => {
        flat.push(instr)
        origins.push(origin)
      }
    }
  }
}

///|
fn hso_local_get_infos(list : Array[TInstr]) -> Array[HSOLocalGetInfo] {
  let flat : Array[TInstr] = []
  let origins : Array[Int] = []
  for i = 0; i < list.length(); i = i + 1 {
    hso_flatten_instrs_with_origin([list[i]], i, flat, origins)
  }
  let infos : Array[HSOLocalGetInfo] = []
  for i = 0; i < flat.length(); i = i + 1 {
    let origin = origins[i]
    let walker = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      curr,
    ) {
      match curr {
        TLocalGet(local_idx) => infos.push({ local_idx, top_instr_idx: origin })
        _ => ()
      }
      self.walk_tinstruction_default((), curr)
    })
    ignore(walker.walk_texpr((), TExpr::new([flat[i]])))
  }
  infos
}

///|
fn hso_can_skip_local_set(
  list : Array[TInstr],
  local_set_idx : Int,
  struct_set_idx : Int,
  local_idx : LocalIdx,
) -> Bool {
  if local_set_idx < 0 ||
    local_set_idx >= list.length() ||
    struct_set_idx < 0 ||
    struct_set_idx >= list.length() {
    return false
  }
  let local_set_instr = list[local_set_idx]
  let get_infos = hso_local_get_infos(list)
  let graph = LocalGraph::new(list)
  let mut get_id = 0
  for info in get_infos {
    if info.local_idx == local_idx && info.top_instr_idx > struct_set_idx {
      let sets = graph.get_sets(get_id)
      for set_src in sets {
        match set_src {
          LocalSet::Set(set_idx, root) =>
            if set_idx == local_idx && root == local_set_instr {
              return false
            }
          LocalSet::InitValue => ()
        }
      }
    }
    get_id += 1
  }
  true
}

///|
fn hso_compact_nops(list : Array[TInstr]) -> Unit {
  let next : Array[TInstr] = []
  for instr in list {
    match instr {
      TNop => ()
      _ => next.push(instr)
    }
  }
  list.clear()
  for instr in next {
    list.push(instr)
  }
}

///|
fn hso_try_swap(list : Array[TInstr], i : Int, j : Int) -> Bool {
  if j >= list.length() - 1 {
    return false
  }
  match list[j] {
    TLocalSet(_, value) => if hso_is_struct_new_like(value) { return false }
    _ => ()
  }
  let first_effects = hso_collect_effects(list[i])
  let second_effects = hso_collect_effects(list[j])
  if second_effects.invalidates(first_effects) {
    return false
  }
  let temp = list[i]
  list[i] = list[j]
  list[j] = temp
  true
}

///|
fn hso_collect_shallow_new_effects(instr : TInstr) -> HSOEffects {
  let effects = HSOEffects::new()
  match instr {
    TStructNew(_, _) | TStructNewDefault(_) => {
      effects.writes_memory = true
      effects.traps = true
    }
    _ => ()
  }
  effects
}

///|
fn hso_shallow_new_invalidates_set_value(
  new_effects : HSOEffects,
  set_value_effects : HSOEffects,
) -> Bool {
  if (new_effects.reads_memory && set_value_effects.writes_memory) ||
    (new_effects.writes_memory && set_value_effects.reads_memory) ||
    (new_effects.writes_memory && set_value_effects.writes_memory) {
    return true
  }
  if (new_effects.reads_globals && set_value_effects.writes_globals) ||
    (new_effects.writes_globals && set_value_effects.reads_globals) ||
    (new_effects.writes_globals && set_value_effects.writes_globals) {
    return true
  }
  if set_value_effects.calls &&
    (
      new_effects.reads_memory ||
      new_effects.writes_memory ||
      new_effects.reads_globals ||
      new_effects.writes_globals
    ) {
    return true
  }
  if new_effects.traps && set_value_effects.has_non_control_side_effects() {
    return true
  }
  false
}

///|
fn hso_try_fold_into_new(
  env : Env,
  new_value : TInstr,
  set_type_idx : TypeIdx,
  field_idx : @lib.U32,
  set_value : TInstr,
  ref_local_idx : LocalIdx,
  set_value_effects : HSOEffects,
  can_skip_local_set : Bool,
) -> TInstr? {
  let (new_type_idx, fields, operands) = match new_value {
    TStructNew(type_idx, ops) =>
      match env.resolve_struct_fields(type_idx) {
        Ok(fs) =>
          if fs.length() != ops.length() {
            return None
          } else {
            (type_idx, fs, ops.copy())
          }
        Err(_) => return None
      }
    TStructNewDefault(type_idx) =>
      match env.resolve_struct_fields(type_idx) {
        Ok(fs) => {
          let defaults : Array[TInstr] = []
          for field in fs {
            match hso_struct_field_default(field) {
              Some(value) => defaults.push(value)
              None => return None
            }
          }
          (type_idx, fs, defaults)
        }
        Err(_) => return None
      }
    _ => return None
  }
  if new_type_idx != set_type_idx {
    return None
  }
  let index = hso_u32_to_int(field_idx)
  if index < 0 || index >= operands.length() || index >= fields.length() {
    return None
  }
  if set_value_effects.locals_read.contains(ref_local_idx) ||
    set_value_effects.locals_written.contains(ref_local_idx) {
    return None
  }
  if set_value_effects.transfers_control_flow() && !can_skip_local_set {
    return None
  }
  if hso_shallow_new_invalidates_set_value(
      hso_collect_shallow_new_effects(new_value),
      set_value_effects,
    ) {
    return None
  }
  for i = index + 1; i < operands.length(); i = i + 1 {
    let operand_effects = hso_collect_effects(operands[i])
    if operand_effects.invalidates(set_value_effects) {
      return None
    }
  }
  let old_value_effects = hso_collect_effects(operands[index])
  if old_value_effects.has_unremovable_side_effects() {
    operands[index] = TInstr::block(
      BlockType::val_type(fields[index].unpack()),
      TExpr::new([TInstr::drop(operands[index]), set_value]),
    )
  } else {
    operands[index] = set_value
  }
  Some(TInstr::struct_new(new_type_idx, operands))
}

///|
fn hso_optimize_block_list(list : Array[TInstr], env : Env) -> Bool {
  let mut changed = false
  for i = 0; i < list.length(); i = i + 1 {
    let (local_idx, local_value) = match list[i] {
      TLocalSet(idx, value) if hso_is_struct_new_like(value) => (idx, value)
      _ => continue
    }
    let mut local_set_index = i
    let mut current_new = local_value
    let mut j = local_set_index + 1
    while j < list.length() {
      let matched = match list[j] {
        TStructSet(set_type_idx, field_idx, TLocalGet(get_idx), set_value) =>
          if get_idx == local_idx {
            Some((set_type_idx, field_idx, set_value))
          } else {
            None
          }
        _ => None
      }
      match matched {
        Some((set_type_idx, field_idx, set_value)) => {
          let set_value_effects = hso_collect_effects(set_value)
          let can_skip_local_set = !set_value_effects.transfers_control_flow() ||
            hso_can_skip_local_set(list, local_set_index, j, local_idx)
          match
            hso_try_fold_into_new(
              env, current_new, set_type_idx, field_idx, set_value, local_idx, set_value_effects,
              can_skip_local_set,
            ) {
            Some(updated_new) => {
              current_new = updated_new
              list[local_set_index] = TInstr::local_set(local_idx, current_new)
              list[j] = TInstr::nop()
              changed = true
              j += 1
            }
            None => break
          }
        }
        None => {
          if hso_try_swap(list, local_set_index, j) {
            local_set_index = j
            changed = true
            j = local_set_index + 1
            continue
          }
          break
        }
      }
    }
  }
  if changed {
    hso_compact_nops(list)
  }
  changed
}

///|
fn hso_rewrite_tinstruction(
  transformer : ModuleTransformer[HSOState],
  state : HSOState,
  instr : TInstr,
) -> TransformerResult[HSOState, TInstr] {
  let (state_after_walk, walked, walk_changed) = match
    transformer.walk_tinstruction_default(state, instr) {
    Ok(Some((next_state, next_instr))) => (next_state, next_instr, true)
    Ok(None) => (state, instr, false)
    Err(e) => return Err(e)
  }
  match walked {
    TStructSet(
      set_type_idx,
      field_idx,
      TLocalTee(local_idx, new_value),
      set_value
    ) => {
      let set_value_effects = hso_collect_effects(set_value)
      let can_skip_local_set = !set_value_effects.transfers_control_flow()
      match
        hso_try_fold_into_new(
          state_after_walk.env,
          new_value,
          set_type_idx,
          field_idx,
          set_value,
          local_idx,
          set_value_effects,
          can_skip_local_set,
        ) {
        Some(updated_new) =>
          change(state_after_walk, TInstr::local_set(local_idx, updated_new))
        None =>
          if walk_changed {
            change(state_after_walk, walked)
          } else {
            unchanged()
          }
      }
    }
    _ =>
      if walk_changed {
        change(state_after_walk, walked)
      } else {
        unchanged()
      }
  }
}

///|
fn hso_rewrite_texpr(
  transformer : ModuleTransformer[HSOState],
  state : HSOState,
  expr : TExpr,
) -> TransformerResult[HSOState, TExpr] {
  let TExpr(instrs) = expr
  let rewritten : Array[TInstr] = []
  let mut changed = false
  let mut curr_state = state
  for instr in instrs {
    match transformer.walk_tinstruction(curr_state, instr) {
      Ok(Some((next_state, next_instr))) => {
        curr_state = next_state
        rewritten.push(next_instr)
        changed = true
      }
      Ok(None) => rewritten.push(instr)
      Err(e) => return Err(e)
    }
  }
  if hso_optimize_block_list(rewritten, curr_state.env) {
    changed = true
  }
  if changed {
    change(curr_state, TExpr::new(rewritten))
  } else {
    unchanged()
  }
}

///|
fn heap_store_optimization_ir_pass(
  mod : Module,
) -> ModuleTransformer[IRContext] {
  let env = Env::new().with_module(mod)
  let pass = ModuleTransformer::new()
    .on_texpr_evt(hso_rewrite_texpr)
    .on_tinstruction_evt(hso_rewrite_tinstruction)
  ModuleTransformer::new().on_func_evt(fn(_, ctx, func) {
    match func {
      TFunc(locals, body) => {
        let state = { env: env.with_locals(locals) }
        match pass.walk_texpr(state, body) {
          Ok(Some((_, new_body))) => change(ctx, Func::t_func(locals, new_body))
          Ok(None) => unchanged()
          Err(e) => Err(e)
        }
      }
      _ => unchanged()
    }
  })
}

///|
fn run_heap_store_optimization(mod : Module) -> Module {
  let pass = heap_store_optimization_ir_pass(mod)
  match pass.walk_module(IRContext::new(), mod) {
    Ok(Some((_, out))) => out
    _ => mod
  }
}

///|
fn hso_count_struct_sets(body : TExpr) -> Int {
  let mut count = 0
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TStructSet(_, _, _, _) => count += 1
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  count
}

///|
test "heap store optimization rewrites nested tee+struct.set" {
  let struct_type = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let ref_local = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [ref_local],
    TExpr::new([
      TInstr::struct_set(
        TypeIdx::new(0),
        @lib.U32(0),
        TInstr::local_tee(
          LocalIdx::new(0),
          TInstr::struct_new(TypeIdx::new(0), [
            TInstr::i32_const(I32(1)),
            TInstr::i32_const(I32(2)),
          ]),
        ),
        TInstr::i32_const(I32(9)),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_type]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap_store_optimization(mod)
  match out.code_sec {
    Some(
      CodeSec([TFunc(_, TExpr([TLocalSet(LocalIdx(idx), TStructNew(_, ops))]))])
    ) => {
      assert_eq(idx, 0U)
      match ops[0] {
        TI32Const(I32(v)) => assert_eq(v, 9)
        _ => fail("expected first field to be updated")
      }
      match ops[1] {
        TI32Const(I32(v)) => assert_eq(v, 2)
        _ => fail("expected second field to remain")
      }
    }
    _ => fail("expected nested tee rewrite")
  }
}

///|
test "heap store optimization folds following struct.set in block list" {
  let struct_type = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let ref_local = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [ref_local],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [
          TInstr::i32_const(I32(1)),
          TInstr::i32_const(I32(2)),
        ]),
      ),
      TInstr::struct_set(
        TypeIdx::new(0),
        @lib.U32(1),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(7)),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_type]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap_store_optimization(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TLocalSet(_, TStructNew(_, ops))]))])) =>
      match ops[1] {
        TI32Const(I32(v)) => assert_eq(v, 7)
        _ => fail("expected folded second-field set")
      }
    _ => fail("expected folded block-list struct.set")
  }
}

///|
test "heap store optimization folds multiple struct.sets after local.set" {
  let struct_type = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let ref_local = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [ref_local],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [
          TInstr::i32_const(I32(1)),
          TInstr::i32_const(I32(2)),
          TInstr::i32_const(I32(3)),
        ]),
      ),
      TInstr::struct_set(
        TypeIdx::new(0),
        @lib.U32(2),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(8)),
      ),
      TInstr::struct_set(
        TypeIdx::new(0),
        @lib.U32(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(9)),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_type]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap_store_optimization(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TLocalSet(_, TStructNew(_, ops))]))])) => {
      match ops[0] {
        TI32Const(I32(v)) => assert_eq(v, 9)
        _ => fail("expected first field updated")
      }
      match ops[2] {
        TI32Const(I32(v)) => assert_eq(v, 8)
        _ => fail("expected third field updated")
      }
    }
    _ => fail("expected multiple folds")
  }
}

///|
test "heap store optimization can swap down local.set of struct.new" {
  let struct_type = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let ref_local = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [ref_local],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(1))]),
      ),
      TInstr::drop(TInstr::i32_const(I32(0))),
      TInstr::struct_set(
        TypeIdx::new(0),
        @lib.U32(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(5)),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_type]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap_store_optimization(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_eq(hso_count_struct_sets(body), 0)
    _ => fail("expected swapped+folded list")
  }
}

///|
test "heap store optimization does not swap when effects conflict" {
  let struct_type = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let ref_local = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [ref_local],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(1))]),
      ),
      TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
      TInstr::struct_set(
        TypeIdx::new(0),
        @lib.U32(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(5)),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_type]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap_store_optimization(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_eq(hso_count_struct_sets(body), 1)
    _ => fail("expected no fold when swap cannot happen")
  }
}

///|
test "heap store optimization rejects set value that reads ref local" {
  let struct_type = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let ref_local = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [ref_local],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(1))]),
      ),
      TInstr::struct_set(
        TypeIdx::new(0),
        @lib.U32(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::local_get(LocalIdx::new(0)),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_type]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap_store_optimization(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_eq(hso_count_struct_sets(body), 1)
    _ => fail("expected no fold when value reads ref local")
  }
}

///|
test "heap store optimization rejects when later new operand invalidates value" {
  let struct_type = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let ref_local = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [ref_local, ValType::i32()],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [
          TInstr::i32_const(I32(1)),
          TInstr::local_set(LocalIdx::new(1), TInstr::i32_const(I32(2))),
        ]),
      ),
      TInstr::struct_set(
        TypeIdx::new(0),
        @lib.U32(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::local_get(LocalIdx::new(1)),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_type]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap_store_optimization(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_eq(hso_count_struct_sets(body), 1)
    _ => fail("expected no fold when later operands conflict")
  }
}

///|
test "heap store optimization keeps old operand effects via drop sequence" {
  let struct_type = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let ref_local = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [ref_local],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [TInstr::call(FuncIdx::new(0), [])]),
      ),
      TInstr::struct_set(
        TypeIdx::new(0),
        @lib.U32(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(7)),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_type]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap_store_optimization(mod)
  match out.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            TExpr([TLocalSet(_, TStructNew(_, [TBlock(_, TExpr(seq))]))])
          ),
        ]
      )
    ) =>
      match seq {
        [TDrop(TCall(_, _)), TI32Const(I32(v))] => assert_eq(v, 7)
        _ => fail("expected old value effect preserved via drop sequence")
      }
    _ => fail("expected call effect preserving rewrite")
  }
}

///|
test "heap store optimization folds into struct.new_default" {
  let struct_type = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let ref_local = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [ref_local],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new_default(TypeIdx::new(0)),
      ),
      TInstr::struct_set(
        TypeIdx::new(0),
        @lib.U32(1),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(6)),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_type]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap_store_optimization(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TLocalSet(_, TStructNew(_, ops))]))])) => {
      match ops[0] {
        TI32Const(I32(v)) => assert_eq(v, 0)
        _ => fail("expected default for first field")
      }
      match ops[1] {
        TI32Const(I32(v)) => assert_eq(v, 6)
        _ => fail("expected folded second field")
      }
    }
    _ => fail("expected fold from struct.new_default")
  }
}

///|
test "heap store optimization avoids branchy set value when local may be read later" {
  let struct_type = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let ref_local = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [ref_local],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(1))]),
      ),
      TInstr::struct_set(
        TypeIdx::new(0),
        @lib.U32(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::return_([]),
      ),
      TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_type]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap_store_optimization(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_eq(hso_count_struct_sets(body), 1)
    _ => fail("expected branchy set to remain")
  }
}

///|
test "heap store optimization can skip local.set when later gets read only overwritten values" {
  let struct_type = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let ref_local = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [ref_local],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(1))]),
      ),
      TInstr::struct_set(
        TypeIdx::new(0),
        @lib.U32(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::return_([]),
      ),
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(2))]),
      ),
      TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_type]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap_store_optimization(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_eq(hso_count_struct_sets(body), 0)
    _ =>
      fail(
        "expected branchy set fold when later gets only observe overwritten local value",
      )
  }
}

///|
test "heap store optimization rejects call set value due struct.new invalidation" {
  let t_i32 = single_rec_type(
    comp_type_sub_type(func_comp_type([], [ValType::i32()])),
  )
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let struct_type = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let ref_local = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(2))),
  )
  let root = Func::t_func(
    [ref_local],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(2), [TInstr::i32_const(I32(1))]),
      ),
      TInstr::struct_set(
        TypeIdx::new(2),
        @lib.U32(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::call(FuncIdx::new(1), []),
      ),
    ]),
  )
  let callee = Func::t_func([], TExpr::new([TInstr::i32_const(I32(7))]))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32, t_void, struct_type]))
    .with_func_sec(FuncSec::new([TypeIdx::new(1), TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([root, callee]))
  let out = run_heap_store_optimization(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body), _])) =>
      assert_eq(hso_count_struct_sets(body), 1)
    _ => fail("expected call-valued set to remain due invalidation")
  }
}

///|
test "heap store optimization rejects global side effects in set value due invalidation" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let t_i32 = single_rec_type(
    comp_type_sub_type(func_comp_type([], [ValType::i32()])),
  )
  let struct_type = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let ref_local = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(2))),
  )
  let func = Func::t_func(
    [ref_local],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(2), [TInstr::i32_const(I32(1))]),
      ),
      TInstr::struct_set(
        TypeIdx::new(2),
        @lib.U32(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::block(
          BlockType::val_type(ValType::i32()),
          TExpr::new([
            TInstr::global_set(GlobalIdx::new(0), TInstr::i32_const(I32(9))),
            TInstr::i32_const(I32(3)),
          ]),
        ),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void, t_i32, struct_type]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::i32(), true),
          Expr::new([Instruction::i32_const(I32(0))]),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap_store_optimization(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_eq(hso_count_struct_sets(body), 1)
    _ => fail("expected global-side-effect set to remain due invalidation")
  }
}

///|
test "heap store optimization rejects atomic.rmw set value due invalidation" {
  let struct_type = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let ma = MemArg::new(0, None, 0)
  let ref_local = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [ref_local],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(1))]),
      ),
      TInstr::struct_set(
        TypeIdx::new(0),
        @lib.U32(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::atomic_rmw(
          AtomicRmwOp::i32_add(),
          ma,
          TInstr::i32_const(I32(0)),
          TInstr::i32_const(I32(1)),
        ),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_type]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap_store_optimization(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_eq(hso_count_struct_sets(body), 1)
    _ => fail("expected atomic.rmw set to remain due invalidation")
  }
}

///|
test "heap store optimization rejects atomic.cmpxchg set value due invalidation" {
  let struct_type = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let ma = MemArg::new(0, None, 0)
  let ref_local = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [ref_local],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(1))]),
      ),
      TInstr::struct_set(
        TypeIdx::new(0),
        @lib.U32(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::atomic_cmpxchg(
          AtomicCmpxchgOp::i32(),
          ma,
          TInstr::i32_const(I32(0)),
          TInstr::i32_const(I32(1)),
          TInstr::i32_const(I32(2)),
        ),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_type]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap_store_optimization(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_eq(hso_count_struct_sets(body), 1)
    _ => fail("expected atomic.cmpxchg set to remain due invalidation")
  }
}

///|
test "heap store optimization rejects memory.atomic.wait32 set value due invalidation" {
  let struct_type = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let ma = MemArg::new(0, None, 0)
  let ref_local = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [ref_local],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(1))]),
      ),
      TInstr::struct_set(
        TypeIdx::new(0),
        @lib.U32(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::memory_atomic_wait32(
          ma,
          TInstr::i32_const(I32(0)),
          TInstr::i32_const(I32(1)),
          TInstr::i64_const(I64(2L)),
        ),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_type]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap_store_optimization(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_eq(hso_count_struct_sets(body), 1)
    _ => fail("expected memory.atomic.wait32 set to remain due invalidation")
  }
}

///|
test "heap store optimization rejects fence-valued block due synchronization effects" {
  let struct_type = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let ref_local = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [ref_local],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(1))]),
      ),
      TInstr::struct_set(
        TypeIdx::new(0),
        @lib.U32(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::block(
          BlockType::val_type(ValType::i32()),
          TExpr::new([TInstr::atomic_fence(), TInstr::i32_const(I32(9))]),
        ),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_type]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap_store_optimization(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_eq(hso_count_struct_sets(body), 1)
    _ => fail("expected fence-valued set to remain due synchronization effects")
  }
}

///|
test "heap store optimization does not swap struct.new past atomic notify" {
  let struct_type = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let ma = MemArg::new(0, None, 0)
  let ref_local = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [ref_local],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(1))]),
      ),
      TInstr::drop(
        TInstr::memory_atomic_notify(
          ma,
          TInstr::i32_const(I32(0)),
          TInstr::i32_const(I32(1)),
        ),
      ),
      TInstr::struct_set(
        TypeIdx::new(0),
        @lib.U32(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(5)),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_type]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap_store_optimization(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_eq(hso_count_struct_sets(body), 1)
    _ => fail("expected no swap/fold across atomic notify")
  }
}
