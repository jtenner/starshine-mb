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
const MONO_MAX_PARAMS : Int = 20

///|

///|
priv struct MonoEffects {
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
fn MonoEffects::new() -> MonoEffects {
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
fn MonoEffects::merge(self : MonoEffects, other : MonoEffects) -> Unit {
  for local_idx in other.locals_read {
    self.locals_read.add(local_idx)
  }
  for local_idx in other.locals_written {
    self.locals_written.add(local_idx)
  }
  self.reads_memory = self.reads_memory || other.reads_memory
  self.writes_memory = self.writes_memory || other.writes_memory
  self.reads_globals = self.reads_globals || other.reads_globals
  self.writes_globals = self.writes_globals || other.writes_globals
  self.calls = self.calls || other.calls
  self.branches = self.branches || other.branches
  self.traps = self.traps || other.traps
  self.throws = self.throws || other.throws
}

///|
fn MonoEffects::transfers_control_flow(self : MonoEffects) -> Bool {
  self.branches || self.throws
}

///|
fn MonoEffects::has_unremovable_side_effects(self : MonoEffects) -> Bool {
  self.writes_memory ||
  self.writes_globals ||
  self.calls ||
  self.branches ||
  self.throws ||
  self.traps ||
  self.locals_written.length() > 0
}

///|
fn MonoEffects::invalidates(self : MonoEffects, other : MonoEffects) -> Bool {
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
fn mn_collect_shallow_effects_into(
  instr : TInstr,
  effects : MonoEffects,
) -> Unit {
  match instr {
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
}

///|
fn mn_collect_shallow_effects(instr : TInstr) -> MonoEffects {
  let effects = MonoEffects::new()
  mn_collect_shallow_effects_into(instr, effects)
  effects
}

///|
fn mn_collect_effects(instr : TInstr) -> MonoEffects {
  let effects = MonoEffects::new()
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    mn_collect_shallow_effects_into(curr, effects)
    self.walk_tinstruction_default((), curr)
  })
  ignore(walker.walk_tinstruction((), instr))
  effects
}

///|
priv struct MonoCallInfo {
  call_id : Int
  target : FuncIdx
  args : Array[TInstr]
  dropped : Bool
}

///|
priv struct MonoCallContext {
  operands : Array[TInstr]
  dropped : Bool
} derive(Eq, Hash)

///|
priv struct MonoContextBuild {
  context : MonoCallContext
  new_operands : Array[TInstr]
  new_operand_types : Array[ValType]
}

///|
priv struct MonoMemoKey {
  target : FuncIdx
  context : MonoCallContext
} derive(Eq, Hash)

///|
priv struct MonoNodeInfo {
  instr : TInstr
  shallow : MonoEffects
  full : MonoEffects
  can_move : Bool
}

///|
priv struct MonoCollectState {
  env : Env
  mut next_id : Int
  node_infos : Map[Int, MonoNodeInfo]
  post_order : Array[Int]
}

///|
fn MonoCollectState::new(env : Env) -> MonoCollectState {
  { env, next_id: 0, node_infos: Map::new(), post_order: [] }
}

///|
priv struct MonoCopyState {
  env : Env
  immovable : Set[Int]
  mut next_id : Int
  new_operands : Array[TInstr]
  new_operand_types : Array[ValType]
  mut type_failed : Bool
}

///|
fn MonoCopyState::new(env : Env, immovable : Set[Int]) -> MonoCopyState {
  {
    env,
    immovable,
    next_id: 0,
    new_operands: [],
    new_operand_types: [],
    type_failed: false,
  }
}

///|
priv struct MonoRewriteAction {
  new_target : FuncIdx
  new_operands : Array[TInstr]
  dropped : Bool
}

///|
priv struct MonoRewriteState {
  actions : Map[Int, MonoRewriteAction]
  mut next_call_id : Int
}

///|
fn MonoRewriteState::new(
  actions : Map[Int, MonoRewriteAction],
) -> MonoRewriteState {
  { actions, next_call_id: 0 }
}

///|
fn mn_make_func_type(
  params : Array[ValType],
  results : Array[ValType],
) -> RecType {
  single_rec_type(comp_type_sub_type(func_comp_type(params, results)))
}

///|
fn mn_flattened_type_count(rec_types : Array[RecType]) -> Int {
  let mut n = 0
  for rec_type in rec_types {
    match rec_type {
      SingleRecType(_) => n += 1
      GroupRecType(sub_types) => n += sub_types.length()
    }
  }
  n
}

///|
fn mn_count_imported_funcs(mod : Module) -> Int {
  let mut n = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        let Import(_, _, ex) = import_
        match ex {
          FuncExternType(_) => n += 1
          _ => ()
        }
      }
    None => ()
  }
  n
}

///|
fn mn_get_func(mod : Module, abs_idx : Int) -> Func? {
  let imported = mn_count_imported_funcs(mod)
  let def_idx = abs_idx - imported
  if def_idx < 0 {
    return None
  }
  match mod.code_sec {
    Some(CodeSec(funcs)) if def_idx < funcs.length() => Some(funcs[def_idx])
    _ => None
  }
}

///|
fn mn_set_defined_func(mod : Module, def_idx : Int, func : Func) -> Module {
  let mut out_mod = mod
  match out_mod.code_sec {
    Some(CodeSec(funcs)) if def_idx >= 0 && def_idx < funcs.length() => {
      let next_funcs = funcs.copy()
      next_funcs[def_idx] = func
      out_mod = out_mod.with_code_sec(CodeSec::new(next_funcs))
      out_mod
    }
    _ => out_mod
  }
}

///|
fn mn_has_unreachable_operand(args : Array[TInstr]) -> Bool {
  for arg in args {
    if is_unreachable_instr(arg) {
      return true
    }
  }
  false
}

///|
fn mn_call_result_unreachable(target : FuncIdx, env : Env) -> Bool {
  match env.get_functype_by_funcidx(target) {
    Some(FuncType(_, [BotValType])) => true
    _ => false
  }
}

///|
fn mn_instr_result_arity(instr : TInstr, env : Env) -> Int {
  match instr {
    TCall(target, _) =>
      match env.get_functype_by_funcidx(target) {
        Some(FuncType(_, results)) => results.length()
        None => 0
      }
    TCallIndirect(type_idx, _, _, _) | TCallRef(type_idx, _, _) =>
      match env.resolve_functype(type_idx) {
        Some(FuncType(_, results)) => results.length()
        None => 0
      }
    TBlock(bt, _) | TLoop(bt, _) | TIf(bt, _, _, _) | TTryTable(bt, _, _) =>
      match env.expand_blocktype(bt) {
        Ok((_, results)) => results.length()
        Err(_) => 0
      }
    _ =>
      match lcs_infer_tinstr_type(instr, env) {
        Some(_) => 1
        None => 0
      }
  }
}

///|
fn MonoCallContext::can_be_moved_into_context(
  expr : TInstr,
  shallow_effects : MonoEffects,
  has_tuple_child : Bool,
) -> Bool {
  if has_tuple_child {
    return false
  }
  if shallow_effects.locals_read.length() > 0 ||
    shallow_effects.locals_written.length() > 0 {
    return false
  }
  if shallow_effects.calls ||
    shallow_effects.transfers_control_flow() ||
    shallow_effects.throws {
    return false
  }
  if shallow_effects.reads_memory ||
    shallow_effects.writes_memory ||
    shallow_effects.reads_globals ||
    shallow_effects.writes_globals ||
    shallow_effects.traps {
    return false
  }
  match expr {
    TBlock(_, _) | TLoop(_, _) | TIf(_, _, _, _) | TTryTable(_, _, _) => false
    _ => true
  }
}

///|
fn mn_collect_operand_node(state : MonoCollectState, instr : TInstr) -> Int {
  let id = state.next_id
  state.next_id += 1
  let child_ids : Array[Int] = []
  for child in eval_children(instr) {
    child_ids.push(mn_collect_operand_node(state, child))
  }
  let mut has_tuple_child = false
  for child_id in child_ids {
    match state.node_infos.get(child_id) {
      Some(node) if mn_instr_result_arity(node.instr, state.env) > 1 =>
        has_tuple_child = true
      _ => ()
    }
  }
  let shallow = mn_collect_shallow_effects(instr)
  let full = mn_collect_effects(instr)
  let can_move = MonoCallContext::can_be_moved_into_context(
    instr, shallow, has_tuple_child,
  )
  state.node_infos[id] = { instr, shallow, full, can_move }
  state.post_order.push(id)
  id
}

///|
fn mn_copy_operand_with_context(
  state : MonoCopyState,
  instr : TInstr,
) -> TInstr {
  let id = state.next_id
  state.next_id += 1
  if state.immovable.contains(id) {
    match lcs_infer_tinstr_type(instr, state.env) {
      Some(vt) => {
        let param_idx = state.new_operand_types.length()
        state.new_operands.push(instr)
        state.new_operand_types.push(vt)
        return TInstr::local_get(LocalIdx::new(param_idx.reinterpret_as_uint()))
      }
      None => {
        state.type_failed = true
        return instr
      }
    }
  }
  match instr {
    TBlock(_, _) | TLoop(_, _) | TIf(_, _, _, _) | TTryTable(_, _, _) => instr
    _ => {
      let rewritten_children : Array[TInstr] = []
      for child in eval_children(instr) {
        rewritten_children.push(mn_copy_operand_with_context(state, child))
      }
      lcs_rebuild_non_control(instr, rewritten_children)
    }
  }
}

///|
fn MonoCallContext::build_from_call(
  call_info : MonoCallInfo,
  caller_env : Env,
  allow_dropped : Bool,
) -> MonoContextBuild? {
  let collect_state = MonoCollectState::new(caller_env)
  for arg in call_info.args {
    ignore(mn_collect_operand_node(collect_state, arg))
  }
  let immovable : Set[Int] = Set::new()
  let non_moving_effects = MonoEffects::new()
  for i = collect_state.post_order.length() - 1; i >= 0; i = i - 1 {
    let id = collect_state.post_order[i]
    match collect_state.node_infos.get(id) {
      None => ()
      Some(info) =>
        if !info.can_move {
          immovable.add(id)
          non_moving_effects.merge(info.full)
        } else if info.shallow.invalidates(non_moving_effects) ||
          non_moving_effects.invalidates(info.shallow) {
          immovable.add(id)
          non_moving_effects.merge(info.full)
        }
    }
  }
  let copy_state = MonoCopyState::new(caller_env, immovable)
  let operands : Array[TInstr] = []
  for arg in call_info.args {
    operands.push(mn_copy_operand_with_context(copy_state, arg))
  }
  if copy_state.type_failed {
    return None
  }
  let context = { operands, dropped: call_info.dropped && allow_dropped }
  Some({
    context,
    new_operands: copy_state.new_operands,
    new_operand_types: copy_state.new_operand_types,
  })
}

///|
fn MonoCallContext::is_trivial(
  self : MonoCallContext,
  call_info : MonoCallInfo,
  callee_params : Array[ValType],
  caller_env : Env,
  new_operands : Array[TInstr],
) -> Bool {
  if self.dropped {
    return false
  }
  if self.operands.length() != callee_params.length() {
    return false
  }
  for i = 0; i < self.operands.length(); i = i + 1 {
    match self.operands[i] {
      TLocalGet(LocalIdx(raw)) =>
        if raw.reinterpret_as_int() != i {
          return false
        }
      _ => return false
    }
  }
  if new_operands.length() != callee_params.length() {
    return false
  }
  for i = 0; i < new_operands.length(); i = i + 1 {
    match new_operands[i] {
      TLocalGet(local_idx) =>
        match caller_env.get_local_type(local_idx) {
          Some(vt) if vt == callee_params[i] => ()
          _ => return false
        }
      _ => return false
    }
  }
  call_info.args.length() == callee_params.length()
}

///|
fn mn_parse_nonneg_int_from(s : String, start : Int) -> Int? {
  if start >= s.length() {
    return None
  }
  let mut value = 0
  for i = start; i < s.length(); i = i + 1 {
    let c = s[i].to_int()
    if c < 0x30 || c > 0x39 {
      return None
    }
    value = value * 10 + (c - 0x30)
  }
  Some(value)
}

///|
fn monomorphize_apply_arguments(
  options : OptimizeOptions,
  args : Array[String],
) -> OptimizeOptions {
  let mut min_benefit = options.monomorphize_min_benefit
  let prefix = "monomorphize-min-benefit@"
  for arg in args {
    if arg.length() < prefix.length() {
      continue
    }
    let mut matched = true
    for i = 0; i < prefix.length(); i = i + 1 {
      if arg[i] != prefix[i] {
        matched = false
        break
      }
    }
    if !matched {
      continue
    }
    match mn_parse_nonneg_int_from(arg, prefix.length()) {
      Some(v) => min_benefit = v
      None => ()
    }
  }
  OptimizeOptions::new(
    optimize_level=options.optimize_level,
    shrink_level=options.shrink_level,
    inlining=options.inlining,
    monomorphize_min_benefit=min_benefit,
  )
}

///|
fn find_return_callers(mod : Module) -> Array[Bool] {
  let env = Env::new().with_module(mod)
  let total = env.funcs.length()
  let return_callers : Array[Bool] = Array::make(total, false)
  let imported = mn_count_imported_funcs(mod)
  match mod.code_sec {
    Some(CodeSec(funcs)) =>
      for i = 0; i < funcs.length(); i = i + 1 {
        let abs_idx = imported + i
        if abs_idx < 0 || abs_idx >= total {
          continue
        }
        match funcs[i] {
          TFunc(_, body) => {
            let mut has_return_call = false
            let walker = ModuleTransformer::new().on_tinstruction_evt(fn(
              self,
              _,
              instr,
            ) {
              match instr {
                TReturnCall(_, _)
                | TReturnCallIndirect(_, _, _, _)
                | TReturnCallRef(_, _, _) => has_return_call = true
                _ => ()
              }
              self.walk_tinstruction_default((), instr)
            })
            ignore(walker.walk_texpr((), body))
            return_callers[abs_idx] = has_return_call
          }
          _ => ()
        }
      }
    None => ()
  }
  return_callers
}

///|
priv struct MonoCallCollector {
  env : Env
  mut next_call_id : Int
  calls : Array[MonoCallInfo]
}

///|
fn MonoCallCollector::new(env : Env) -> MonoCallCollector {
  { env, next_call_id: 0, calls: [] }
}

///|
fn mn_record_call(
  collector : MonoCallCollector,
  target : FuncIdx,
  args : Array[TInstr],
  dropped : Bool,
  reachable : Bool,
) -> Unit {
  let call_id = collector.next_call_id
  collector.next_call_id += 1
  if !reachable || mn_call_result_unreachable(target, collector.env) {
    return
  }
  collector.calls.push({ call_id, target, args, dropped })
}

///|
fn mn_collect_calls_in_instr(
  collector : MonoCallCollector,
  instr : TInstr,
  reachable : Bool,
) -> Unit {
  match instr {
    TDrop(TCall(target, args)) => {
      for arg in args {
        mn_collect_calls_in_instr(collector, arg, reachable)
      }
      mn_record_call(collector, target, args, true, reachable)
    }
    TCall(target, args) => {
      for arg in args {
        mn_collect_calls_in_instr(collector, arg, reachable)
      }
      mn_record_call(collector, target, args, false, reachable)
    }
    TBlock(_, body) | TLoop(_, body) | TTryTable(_, _, body) =>
      mn_collect_calls_in_texpr(collector, body, true)
    TIf(_, cond, then_body, else_body) => {
      mn_collect_calls_in_instr(collector, cond, true)
      mn_collect_calls_in_texpr(collector, then_body, true)
      match else_body {
        Some(other) => mn_collect_calls_in_texpr(collector, other, true)
        None => ()
      }
    }
    _ =>
      for child in eval_children(instr) {
        mn_collect_calls_in_instr(collector, child, reachable)
      }
  }
}

///|
fn mn_collect_calls_in_texpr(
  collector : MonoCallCollector,
  body : TExpr,
  reachable : Bool,
) -> Unit {
  let mut reachable = reachable
  for instr in body.0 {
    if !reachable {
      break
    }
    mn_collect_calls_in_instr(collector, instr, reachable)
    if is_unreachable_instr(instr) {
      reachable = false
    }
  }
}

///|
fn find_calls_and_drops(
  func : Func,
  caller_abs_idx : Int,
  env : Env,
) -> Array[MonoCallInfo] {
  ignore(caller_abs_idx)
  match func {
    TFunc(_, body) => {
      let collector = MonoCallCollector::new(env)
      mn_collect_calls_in_texpr(collector, body, true)
      collector.calls
    }
    _ => []
  }
}

///|
fn mn_shift_local_indices(body : TExpr, shift : Int) -> TExpr {
  if shift == 0 {
    return body
  }
  let walker = ModuleTransformer::new().on_localidx_evt(fn(_, _, idx) {
    let LocalIdx(raw) = idx
    let next_idx = raw.reinterpret_as_int() + shift
    change((), LocalIdx::new(next_idx.reinterpret_as_uint()))
  })
  match walker.walk_texpr((), body) {
    Ok(Some((_, out))) => out
    _ => body
  }
}

///|
fn mn_remove_returns_for_dropped(body : TExpr) -> TExpr {
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    let processed = match self.walk_tinstruction_default((), instr) {
      Ok(Some((_, i))) => i
      Ok(None) => instr
      Err(e) => return Err(e)
    }
    match processed {
      TReturn(values) if values.length() > 0 => {
        let seq : Array[TInstr] = []
        for value in values {
          seq.push(TInstr::drop(value))
        }
        seq.push(TInstr::return_([]))
        change((), TInstr::block(BlockType::void_(), TExpr::new(seq)))
      }
      TReturnCall(target, args) =>
        change(
          (),
          TInstr::block(
            BlockType::void_(),
            TExpr::new([
              TInstr::drop(TInstr::call(target, args)),
              TInstr::return_([]),
            ]),
          ),
        )
      TReturnCallIndirect(type_idx, table_idx, args, index) =>
        change(
          (),
          TInstr::block(
            BlockType::void_(),
            TExpr::new([
              TInstr::drop(
                TInstr::call_indirect(type_idx, table_idx, args, index),
              ),
              TInstr::return_([]),
            ]),
          ),
        )
      TReturnCallRef(type_idx, args, ref_) =>
        change(
          (),
          TInstr::block(
            BlockType::void_(),
            TExpr::new([
              TInstr::drop(TInstr::call_ref(type_idx, args, ref_)),
              TInstr::return_([]),
            ]),
          ),
        )
      _ => if processed != instr { change((), processed) } else { unchanged() }
    }
  })
  let rewritten = match walker.walk_texpr((), body) {
    Ok(Some((_, out))) => out
    _ => body
  }
  let out_instrs = rewritten.0.copy()
  out_instrs.push(TInstr::return_([]))
  TExpr::new(out_instrs)
}

///|
fn make_mono_function_with_context(
  func : Func,
  func_type : FuncType,
  context : MonoCallContext,
  new_operand_types : Array[ValType],
) -> Func? {
  match func {
    TFunc(extra_locals, body) => {
      let FuncType(old_params, _) = func_type
      if context.operands.length() != old_params.length() {
        return None
      }
      let new_param_count = new_operand_types.length()
      let shifted_body = mn_shift_local_indices(body, new_param_count)
      let rewritten_body = if context.dropped {
        mn_remove_returns_for_dropped(shifted_body)
      } else {
        shifted_body
      }
      let prologue : Array[TInstr] = []
      for i = 0; i < old_params.length(); i = i + 1 {
        let mapped = new_param_count + i
        prologue.push(
          TInstr::local_set(
            LocalIdx::new(mapped.reinterpret_as_uint()),
            context.operands[i],
          ),
        )
      }
      let combined : Array[TInstr] = []
      for instr in prologue {
        combined.push(instr)
      }
      for instr in rewritten_body.0 {
        combined.push(instr)
      }
      let locals = old_params.copy()
      for local_ in extra_locals {
        locals.push(local_)
      }
      Some(Func::t_func(locals, TExpr::new(combined)))
    }
    _ => None
  }
}

///|
fn mn_append_specialized_function(
  mod : Module,
  params : Array[ValType],
  results : Array[ValType],
  func : Func,
) -> (Module, FuncIdx) {
  let imported = mn_count_imported_funcs(mod)
  let mut out_mod = mod
  let recs = match out_mod.type_sec {
    Some(TypeSec(xs)) => xs.copy()
    None => []
  }
  let type_idx = TypeIdx::new(
    mn_flattened_type_count(recs).reinterpret_as_uint(),
  )
  recs.push(mn_make_func_type(params, results))
  out_mod = out_mod.with_type_sec(TypeSec::new(recs))
  let func_types = match out_mod.func_sec {
    Some(FuncSec(xs)) => xs.copy()
    None => []
  }
  func_types.push(type_idx)
  out_mod = out_mod.with_func_sec(FuncSec::new(func_types))
  let funcs = match out_mod.code_sec {
    Some(CodeSec(xs)) => xs.copy()
    None => []
  }
  let abs_idx = imported + funcs.length()
  funcs.push(func)
  out_mod = out_mod.with_code_sec(CodeSec::new(funcs))
  (out_mod, FuncIdx::new(abs_idx.reinterpret_as_uint()))
}

///|
fn mn_cost_instr(instr : TInstr) -> Int {
  let base = match instr {
    TI32Const(_)
    | TI64Const(_)
    | TF32Const(_)
    | TF64Const(_)
    | TRefNull(_)
    | TRefFunc(_)
    | TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | TLocalGet(_)
    | TGlobalGet(_)
    | TNop => 0
    TCall(_, _) | TCallIndirect(_, _, _, _) | TCallRef(_, _, _) => 4
    TReturnCall(_, _)
    | TReturnCallIndirect(_, _, _, _)
    | TReturnCallRef(_, _, _) => 5
    _ => 1
  }
  let mut total = base
  match instr {
    TBlock(_, body) | TLoop(_, body) | TTryTable(_, _, body) =>
      for item in body.0 {
        total += mn_cost_instr(item)
      }
    TIf(_, cond, then_, else_) => {
      total += mn_cost_instr(cond)
      for item in then_.0 {
        total += mn_cost_instr(item)
      }
      match else_ {
        Some(other) =>
          for item in other.0 {
            total += mn_cost_instr(item)
          }
        None => ()
      }
    }
    _ =>
      for child in eval_children(instr) {
        total += mn_cost_instr(child)
      }
  }
  total
}

///|
fn cost(body : TExpr) -> Int {
  let mut total = 0
  for instr in body.0 {
    total += mn_cost_instr(instr)
  }
  total
}

///|
fn mn_collect_read_locals(body : TExpr) -> Set[LocalIdx] {
  let reads : Set[LocalIdx] = Set::new()
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TLocalGet(idx) => reads.add(idx)
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  reads
}

///|
fn mn_cleanup_body(body : TExpr) -> TExpr {
  let reads = mn_collect_read_locals(body)
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    let processed = match self.walk_tinstruction_default((), instr) {
      Ok(Some((_, i))) => i
      Ok(None) => instr
      Err(e) => return Err(e)
    }
    match processed {
      TDrop(value) => {
        let effects = mn_collect_effects(value)
        if effects.has_unremovable_side_effects() {
          if processed != instr {
            change((), processed)
          } else {
            unchanged()
          }
        } else {
          change((), TInstr::nop())
        }
      }
      TLocalSet(idx, value) if !reads.contains(idx) => {
        let effects = mn_collect_effects(value)
        if effects.has_unremovable_side_effects() {
          change((), TInstr::drop(value))
        } else {
          change((), TInstr::nop())
        }
      }
      TLocalTee(idx, value) if !reads.contains(idx) => {
        let effects = mn_collect_effects(value)
        if effects.has_unremovable_side_effects() {
          change((), value)
        } else {
          change((), TInstr::nop())
        }
      }
      _ => if processed != instr { change((), processed) } else { unchanged() }
    }
  })
  match walker.walk_texpr((), body) {
    Ok(Some((_, out))) => out
    _ => body
  }
}

///|
fn do_opts(func : Func, mod : Module, params? : Array[ValType] = []) -> Func {
  match func {
    TFunc(locals, body) => {
      let all_locals = params + locals
      let ctx = IRContext::new()
      ctx.set_mod(mod)
      ctx.set_locals(all_locals)
      ctx.set_body(body)
      let body = match ctx.optimize_body_with_ssa() {
        Some(out) => out
        None => body
      }
      let folded = match
        code_folding_pass().walk_func(
          CodeFoldingState::new(),
          Func::t_func(locals, body),
        ) {
        Ok(Some((_, out))) => out
        _ => Func::t_func(locals, body)
      }
      match folded {
        TFunc(next_locals, next_body) =>
          Func::t_func(
            next_locals,
            mn_cleanup_body(mn_cleanup_body(run_dce_on_texpr(next_body))),
          )
        _ => folded
      }
    }
    _ => func
  }
}

///|
fn hash_call_context(context : MonoCallContext) -> UInt64 {
  let mut digest = if context.dropped {
    1469598103934665603UL
  } else {
    1099511628211UL
  }
  for operand in context.operands {
    digest = digest ^ lcs_digest(operand, [])
    digest = digest * 1099511628211UL
  }
  digest
}

///|
fn eq_call_context(a : MonoCallContext, b : MonoCallContext) -> Bool {
  a == b
}

///|
fn mn_rewrite_instr(state : MonoRewriteState, instr : TInstr) -> TInstr {
  match instr {
    TDrop(TCall(target, args)) => {
      let rewritten_args : Array[TInstr] = []
      for arg in args {
        rewritten_args.push(mn_rewrite_instr(state, arg))
      }
      let call_id = state.next_call_id
      state.next_call_id += 1
      match state.actions.get(call_id) {
        Some(action) =>
          if action.dropped {
            TInstr::call(action.new_target, action.new_operands)
          } else {
            TInstr::drop(TInstr::call(action.new_target, action.new_operands))
          }
        None => TInstr::drop(TInstr::call(target, rewritten_args))
      }
    }
    TCall(target, args) => {
      let rewritten_args : Array[TInstr] = []
      for arg in args {
        rewritten_args.push(mn_rewrite_instr(state, arg))
      }
      let call_id = state.next_call_id
      state.next_call_id += 1
      match state.actions.get(call_id) {
        Some(action) => TInstr::call(action.new_target, action.new_operands)
        None => TInstr::call(target, rewritten_args)
      }
    }
    TBlock(bt, body) => TInstr::block(bt, mn_rewrite_texpr(state, body))
    TLoop(bt, body) => TInstr::loop_(bt, mn_rewrite_texpr(state, body))
    TTryTable(bt, catches, body) =>
      TInstr::try_table(bt, catches, mn_rewrite_texpr(state, body))
    TIf(bt, cond, then_, else_) =>
      TInstr::if_(
        bt,
        mn_rewrite_instr(state, cond),
        mn_rewrite_texpr(state, then_),
        match else_ {
          Some(other) => Some(mn_rewrite_texpr(state, other))
          None => None
        },
      )
    _ => {
      let rewritten_children : Array[TInstr] = []
      for child in eval_children(instr) {
        rewritten_children.push(mn_rewrite_instr(state, child))
      }
      lcs_rebuild_non_control(instr, rewritten_children)
    }
  }
}

///|
fn mn_rewrite_texpr(state : MonoRewriteState, body : TExpr) -> TExpr {
  let out : Array[TInstr] = []
  for instr in body.0 {
    out.push(mn_rewrite_instr(state, instr))
  }
  TExpr::new(out)
}

///|
fn update_call(func : Func, actions : Map[Int, MonoRewriteAction]) -> Func {
  if actions.is_empty() {
    return func
  }
  match func {
    TFunc(locals, body) => {
      let state = MonoRewriteState::new(actions)
      Func::t_func(locals, mn_rewrite_texpr(state, body))
    }
    _ => func
  }
}

///|
fn mn_build_caller_env(mod : Module, caller_abs_idx : Int) -> Env {
  let base = Env::new().with_module(mod)
  let params = match
    base.get_functype_by_funcidx(
      FuncIdx::new(caller_abs_idx.reinterpret_as_uint()),
    ) {
    Some(FuncType(ps, _)) => ps
    None => []
  }
  let locals = params.copy()
  match mn_get_func(mod, caller_abs_idx) {
    Some(TFunc(extra, _)) =>
      for vt in extra {
        locals.push(vt)
      }
    _ => ()
  }
  base.with_locals(locals)
}

///|
fn monomorphize_run(
  mod : Module,
  options : OptimizeOptions,
  always : Bool,
) -> Result[Module, String] {
  let mut mod = mod
  let imported = mn_count_imported_funcs(mod)
  let original_defined_count = match mod.code_sec {
    Some(CodeSec(funcs)) => funcs.length()
    None => 0
  }
  if original_defined_count == 0 {
    return Ok(mod)
  }
  let return_callers = find_return_callers(mod)
  let memo : Map[MonoMemoKey, FuncIdx] = Map::new()
  let optimized_original : Set[Int] = Set::new()
  for def_idx = 0; def_idx < original_defined_count; def_idx = def_idx + 1 {
    let caller_abs_idx = imported + def_idx
    let env = Env::new().with_module(mod)
    let caller_func = match mn_get_func(mod, caller_abs_idx) {
      Some(func) => func
      None => continue
    }
    let calls = find_calls_and_drops(caller_func, caller_abs_idx, env)
    if calls.is_empty() {
      continue
    }
    let caller_env = mn_build_caller_env(mod, caller_abs_idx)
    let actions : Map[Int, MonoRewriteAction] = Map::new()
    for call_info in calls {
      if mn_has_unreachable_operand(call_info.args) {
        continue
      }
      let FuncIdx(raw_target) = call_info.target
      let target_abs_idx = raw_target.reinterpret_as_int()
      if target_abs_idx < imported {
        continue
      }
      if target_abs_idx == caller_abs_idx {
        continue
      }
      let target_def_idx = target_abs_idx - imported
      let callee_func = match mn_get_func(mod, target_abs_idx) {
        Some(func) => func
        None => continue
      }
      let callee_type = match env.get_functype_by_funcidx(call_info.target) {
        Some(ft) => ft
        None => continue
      }
      let FuncType(callee_params, callee_results) = callee_type
      if callee_params.length() != call_info.args.length() {
        continue
      }
      let allow_dropped = call_info.dropped &&
        !(target_abs_idx >= 0 &&
        target_abs_idx < return_callers.length() &&
        return_callers[target_abs_idx])
      let ctx_build = match
        MonoCallContext::build_from_call(call_info, caller_env, allow_dropped) {
        Some(build) => build
        None => continue
      }
      if ctx_build.new_operand_types.length() > MONO_MAX_PARAMS {
        continue
      }
      if ctx_build.context.dropped && callee_results.length() != 1 {
        continue
      }
      let key = { target: call_info.target, context: ctx_build.context }
      let context_hash = hash_call_context(ctx_build.context)
      if context_hash == 0UL &&
        !eq_call_context(ctx_build.context, ctx_build.context) {
        continue
      }
      if MonoCallContext::is_trivial(
          ctx_build.context,
          call_info,
          callee_params,
          caller_env,
          ctx_build.new_operands,
        ) {
        memo[key] = call_info.target
        continue
      }
      match memo.get(key) {
        Some(chosen_target) => {
          if chosen_target != call_info.target {
            actions[call_info.call_id] = {
              new_target: chosen_target,
              new_operands: ctx_build.new_operands,
              dropped: ctx_build.context.dropped,
            }
          }
          continue
        }
        None => ()
      }
      if !always && !optimized_original.contains(target_abs_idx) {
        let optimized = do_opts(callee_func, mod, params=callee_params)
        mod = mn_set_defined_func(mod, target_def_idx, optimized)
        optimized_original.add(target_abs_idx)
      }
      let env_after_opt = Env::new().with_module(mod)
      let callee_after_opt = match mn_get_func(mod, target_abs_idx) {
        Some(func) => func
        None => continue
      }
      let callee_type_after_opt = match
        env_after_opt.get_functype_by_funcidx(call_info.target) {
        Some(ft) => ft
        None => continue
      }
      let mono_func = match
        make_mono_function_with_context(
          callee_after_opt,
          callee_type_after_opt,
          ctx_build.context,
          ctx_build.new_operand_types,
        ) {
        Some(func) => func
        None => {
          memo[key] = call_info.target
          continue
        }
      }
      let optimized_mono = if always {
        mono_func
      } else {
        do_opts(mono_func, mod, params=ctx_build.new_operand_types)
      }
      let should_accept = if always {
        true
      } else {
        let before_body_cost = match
          do_opts(callee_after_opt, mod, params=callee_params) {
          TFunc(_, body) => cost(body)
          _ => 0
        }
        let mut context_cost = 0
        for operand in ctx_build.context.operands {
          context_cost += mn_cost_instr(operand)
        }
        let cost_before = before_body_cost + context_cost
        let cost_after = match optimized_mono {
          TFunc(_, body) => cost(body)
          _ => cost_before
        }
        if cost_before == 0 {
          false
        } else {
          let benefit = 100 - 100 * cost_after / cost_before
          benefit > options.monomorphize_min_benefit
        }
      }
      if !should_accept {
        memo[key] = call_info.target
        continue
      }
      let FuncType(_, callee_results_after_opt) = callee_type_after_opt
      let mono_results = if ctx_build.context.dropped {
        []
      } else {
        callee_results_after_opt
      }
      let (next_mod, mono_target) = mn_append_specialized_function(
        mod,
        ctx_build.new_operand_types,
        mono_results,
        optimized_mono,
      )
      mod = next_mod
      memo[key] = mono_target
      actions[call_info.call_id] = {
        new_target: mono_target,
        new_operands: ctx_build.new_operands,
        dropped: ctx_build.context.dropped,
      }
    }
    if !actions.is_empty() {
      let updated = update_call(caller_func, actions)
      mod = mn_set_defined_func(mod, def_idx, updated)
    }
  }
  Ok(mod)
}

///|
fn monomorphize(
  mod : Module,
  options? : OptimizeOptions = OptimizeOptions::new(),
  always? : Bool = false,
) -> Result[Module, String] {
  monomorphize_run(mod, options, always)
}

///|
fn mono_type(params : Array[ValType], results : Array[ValType]) -> RecType {
  single_rec_type(comp_type_sub_type(func_comp_type(params, results)))
}

///|
fn mono_run_pass(
  mod : Module,
  always : Bool,
  min_benefit : Int,
) -> Module raise {
  let options = OptimizeOptions::new(monomorphize_min_benefit=min_benefit)
  let passes = if always {
    [ModulePass::MonomorphizeAlways]
  } else {
    [ModulePass::Monomorphize]
  }
  match optimize_module_with_options(mod, passes, options) {
    Ok(out) => out
    Err(e) => fail("unexpected monomorphize error: \{e}")
  }
}

///|
fn mono_call_targets_in_body(body : TExpr) -> Array[FuncIdx] {
  let out : Array[FuncIdx] = []
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TCall(target, _) => out.push(target)
      TDrop(TCall(target, _)) => out.push(target)
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  out
}

///|
test "monomorphize always specializes constant argument and reduces params" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        mono_type([], [ValType::i32()]),
        mono_type([ValType::i32()], [ValType::i32()]),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::return_([
              TInstr::call(FuncIdx::new(1), [TInstr::i32_const(I32(7))]),
            ]),
          ]),
        ),
        Func::t_func(
          [],
          TExpr::new([
            TInstr::return_([
              TInstr::binary(
                BinaryOp::i32_add(),
                TInstr::local_get(LocalIdx::new(0)),
                TInstr::i32_const(I32(1)),
              ),
            ]),
          ]),
        ),
      ]),
    )
  let out = mono_run_pass(mod, true, 0)
  match out.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 3)
    _ => fail("expected code section")
  }
  match out.code_sec {
    Some(CodeSec([TFunc(_, caller_body), _, _])) => {
      let targets = mono_call_targets_in_body(caller_body)
      assert_eq(targets.length(), 1)
      assert_true(targets[0] != FuncIdx::new(1))
    }
    _ => fail("expected rewritten caller")
  }
}

///|
test "monomorphize always keeps immovable operand as call argument for partial movability" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        mono_type([ValType::i32()], [ValType::i32()]),
        mono_type([ValType::i32()], [ValType::i32()]),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::return_([
              TInstr::call(FuncIdx::new(1), [
                TInstr::binary(
                  BinaryOp::i32_add(),
                  TInstr::local_get(LocalIdx::new(0)),
                  TInstr::i32_const(I32(1)),
                ),
              ]),
            ]),
          ]),
        ),
        Func::t_func(
          [],
          TExpr::new([TInstr::return_([TInstr::local_get(LocalIdx::new(0))])]),
        ),
      ]),
    )
  let out = mono_run_pass(mod, true, 0)
  match out.code_sec {
    Some(
      CodeSec(
        [TFunc(_, TExpr([TReturn([TCall(_, args)])])), _, TFunc(_, mono_body)]
      )
    ) => {
      assert_eq(args.length(), 1)
      let mut saw_binary_prelude = false
      let walker = ModuleTransformer::new().on_tinstruction_evt(fn(
        self,
        _,
        instr,
      ) {
        match instr {
          TLocalSet(
            _,
            TBinary(BinaryOp::I32AddOp, TLocalGet(_), TI32Const(I32(1)))
          ) => saw_binary_prelude = true
          _ => ()
        }
        self.walk_tinstruction_default((), instr)
      })
      ignore(walker.walk_texpr((), mono_body))
      assert_true(saw_binary_prelude)
    }
    _ => fail("expected call args to keep immovable local.get subtree")
  }
}

///|
test "monomorphize always preserves effect ordering by keeping trapping operand in caller" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        mono_type([], [ValType::i32()]),
        mono_type([ValType::i32()], [ValType::i32()]),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::return_([
              TInstr::call(FuncIdx::new(1), [
                TInstr::binary(
                  BinaryOp::i32_div_s(),
                  TInstr::i32_const(I32(1)),
                  TInstr::i32_const(I32(0)),
                ),
              ]),
            ]),
          ]),
        ),
        Func::t_func(
          [],
          TExpr::new([TInstr::return_([TInstr::local_get(LocalIdx::new(0))])]),
        ),
      ]),
    )
  let out = mono_run_pass(mod, true, 0)
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TReturn([TCall(_, [arg])])])), _, _])) =>
      match arg {
        TBinary(BinaryOp::I32DivSOp, _, _) => ()
        _ => fail("expected trapping division to remain in caller")
      }
    _ => fail("expected rewritten caller")
  }
}

///|
test "monomorphize always handles dropped calls and removes drop wrapper" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        mono_type([], []),
        mono_type([ValType::i32()], [ValType::i32()]),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::drop(
              TInstr::call(FuncIdx::new(1), [TInstr::i32_const(I32(9))]),
            ),
          ]),
        ),
        Func::t_func(
          [],
          TExpr::new([TInstr::return_([TInstr::local_get(LocalIdx::new(0))])]),
        ),
      ]),
    )
  let out = mono_run_pass(mod, true, 0)
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TCall(_, _)])), _, TFunc(_, _)])) => ()
    _ =>
      fail(
        "expected dropped call to become direct call to dropped-result specialization",
      )
  }
  match validate_module(out) {
    Ok(_) => ()
    Err(@validate.ValidationError::Validation(msg)) =>
      fail("expected monomorphized module to validate: \{msg}")
  }
}

///|
test "monomorphize disables dropped context for return-calling callee" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        mono_type([], []),
        mono_type([ValType::i32()], [ValType::i32()]),
        mono_type([ValType::i32()], [ValType::i32()]),
      ]),
    )
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(1), TypeIdx::new(2)]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::drop(
              TInstr::call(FuncIdx::new(1), [TInstr::i32_const(I32(3))]),
            ),
          ]),
        ),
        Func::t_func(
          [],
          TExpr::new([
            TInstr::return_call(FuncIdx::new(2), [
              TInstr::local_get(LocalIdx::new(0)),
            ]),
          ]),
        ),
        Func::t_func(
          [],
          TExpr::new([TInstr::return_([TInstr::local_get(LocalIdx::new(0))])]),
        ),
      ]),
    )
  let out = mono_run_pass(mod, true, 0)
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TDrop(TCall(_, _))])), _, _, _])) => ()
    _ =>
      fail("expected drop wrapper to remain when dropped context is disabled")
  }
}

///|
test "monomorphize suppresses trivial pass-through context" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        mono_type([ValType::i32()], [ValType::i32()]),
        mono_type([ValType::i32()], [ValType::i32()]),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::return_([
              TInstr::call(FuncIdx::new(1), [
                TInstr::local_get(LocalIdx::new(0)),
              ]),
            ]),
          ]),
        ),
        Func::t_func(
          [],
          TExpr::new([TInstr::return_([TInstr::local_get(LocalIdx::new(0))])]),
        ),
      ]),
    )
  let out = mono_run_pass(mod, true, 0)
  match out.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 2)
    _ => fail("expected unchanged function count")
  }
}

///|
test "monomorphize reuses memoized specialization across identical callsites" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        mono_type([], []),
        mono_type([ValType::i32()], [ValType::i32()]),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::drop(
              TInstr::call(FuncIdx::new(1), [TInstr::i32_const(I32(5))]),
            ),
            TInstr::drop(
              TInstr::call(FuncIdx::new(1), [TInstr::i32_const(I32(5))]),
            ),
          ]),
        ),
        Func::t_func(
          [],
          TExpr::new([TInstr::return_([TInstr::local_get(LocalIdx::new(0))])]),
        ),
      ]),
    )
  let out = mono_run_pass(mod, true, 0)
  match out.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 3)
    _ => fail("expected one memoized specialization clone")
  }
  match out.code_sec {
    Some(CodeSec([TFunc(_, body), _, _])) => {
      let targets = mono_call_targets_in_body(body)
      assert_eq(targets.length(), 2)
      assert_eq(targets[0], targets[1])
    }
    _ => fail("expected two rewritten calls in caller")
  }
}

///|
test "monomorphize enforces max parameter bound" {
  let many_i32 : Array[ValType] = []
  for i = 0; i < MONO_MAX_PARAMS + 1; i = i + 1 {
    ignore(i)
    many_i32.push(ValType::i32())
  }
  let mut arg = TInstr::local_get(LocalIdx::new(0))
  for i = 1; i < many_i32.length(); i = i + 1 {
    arg = TInstr::binary(
      BinaryOp::i32_add(),
      arg,
      TInstr::local_get(LocalIdx::new(i.reinterpret_as_uint())),
    )
  }
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        mono_type(many_i32, [ValType::i32()]),
        mono_type([ValType::i32()], [ValType::i32()]),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([TInstr::return_([TInstr::call(FuncIdx::new(1), [arg])])]),
        ),
        Func::t_func(
          [],
          TExpr::new([TInstr::return_([TInstr::local_get(LocalIdx::new(0))])]),
        ),
      ]),
    )
  let out = mono_run_pass(mod, true, 0)
  match out.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 2)
    _ => fail("expected specialization rejection when new params exceed bound")
  }
}

///|
test "monomorphize skips imported and direct-recursive targets" {
  let imported_case = Module::new()
    .with_type_sec(
      TypeSec::new([mono_type([ValType::i32()], [ValType::i32()])]),
    )
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("f"),
          ExternType::func(TypeIdx::new(0)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::return_([
              TInstr::call(FuncIdx::new(0), [TInstr::i32_const(I32(1))]),
            ]),
          ]),
        ),
      ]),
    )
  let imported_out = mono_run_pass(imported_case, true, 0)
  match imported_out.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 1)
    _ => fail("expected imported target to be skipped")
  }
  let recursive_case = Module::new()
    .with_type_sec(TypeSec::new([mono_type([], [ValType::i32()])]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([TInstr::return_([TInstr::call(FuncIdx::new(0), [])])]),
        ),
      ]),
    )
  let recursive_out = mono_run_pass(recursive_case, true, 0)
  match recursive_out.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 1)
    _ => fail("expected direct recursion to be skipped")
  }
}

///|
test "monomorphize empirical threshold gating and determinism" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        mono_type([], [ValType::i32()]),
        mono_type([ValType::i32()], [ValType::i32()]),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::return_([
              TInstr::call(FuncIdx::new(1), [TInstr::i32_const(I32(4))]),
            ]),
          ]),
        ),
        Func::t_func(
          [],
          TExpr::new([
            TInstr::return_([
              TInstr::binary(
                BinaryOp::i32_add(),
                TInstr::local_get(LocalIdx::new(0)),
                TInstr::i32_const(I32(1)),
              ),
            ]),
          ]),
        ),
      ]),
    )
  let low = mono_run_pass(mod, false, 0)
  let high = mono_run_pass(mod, false, 100)
  match low.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 3)
    _ => fail("expected code section after low-threshold run")
  }
  match high.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 2)
    _ => fail("expected no specialization at threshold 100")
  }
  let no_improve = Module::new()
    .with_type_sec(
      TypeSec::new([
        mono_type([ValType::i32()], [ValType::i32()]),
        mono_type([ValType::i32()], [ValType::i32()]),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::return_([
              TInstr::call(FuncIdx::new(1), [
                TInstr::binary(
                  BinaryOp::i32_add(),
                  TInstr::local_get(LocalIdx::new(0)),
                  TInstr::i32_const(I32(1)),
                ),
              ]),
            ]),
          ]),
        ),
        Func::t_func(
          [],
          TExpr::new([TInstr::return_([TInstr::local_get(LocalIdx::new(0))])]),
        ),
      ]),
    )
  let high_no_improve = mono_run_pass(no_improve, false, 95)
  match high_no_improve.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 2)
    _ => fail("expected no specialization with high threshold and low benefit")
  }
  let run_a = mono_run_pass(mod, true, 0)
  let run_b = mono_run_pass(mod, true, 0)
  assert_eq(run_a, run_b)
}

///|
test "monomorphize pass arg parser applies monomorphize-min-benefit" {
  let options = OptimizeOptions::new(monomorphize_min_benefit=5)
  let updated = monomorphize_apply_arguments(options, [
    "monomorphize-min-benefit@42",
  ])
  assert_eq(updated.monomorphize_min_benefit, 42)
}
