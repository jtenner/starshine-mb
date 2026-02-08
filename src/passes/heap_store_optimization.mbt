///|
priv struct HSOState {
  env : Env
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
fn hso_tinstr_has_local_get(instr : TInstr, target : LocalIdx) -> Bool {
  let found = Ref::new(false)
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    match curr {
      TLocalGet(idx) if idx == target => found.update(fn(_) { true })
      _ => ()
    }
    self.walk_tinstruction_default((), curr)
  })
  ignore(walker.walk_tinstruction((), instr))
  found.val
}

///|
fn hso_has_local_get_after(
  list : Array[TInstr],
  start : Int,
  target : LocalIdx,
) -> Bool {
  for i = start + 1; i < list.length(); i = i + 1 {
    if hso_tinstr_has_local_get(list[i], target) {
      return true
    }
  }
  false
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
fn hso_try_fold_into_new(
  env : Env,
  new_value : TInstr,
  set_type_idx : TypeIdx,
  field_idx : @lib.U32,
  set_value : TInstr,
  ref_local_idx : LocalIdx,
  has_later_local_get : Bool,
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
  let set_value_effects = hso_collect_effects(set_value)
  if set_value_effects.locals_read.contains(ref_local_idx) ||
    set_value_effects.locals_written.contains(ref_local_idx) {
    return None
  }
  if set_value_effects.transfers_control_flow() && has_later_local_get {
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
          let has_later = hso_has_local_get_after(list, j, local_idx)
          match
            hso_try_fold_into_new(
              env, current_new, set_type_idx, field_idx, set_value, local_idx, has_later,
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
    ) =>
      match
        hso_try_fold_into_new(
          state_after_walk.env,
          new_value,
          set_type_idx,
          field_idx,
          set_value,
          local_idx,
          true,
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
