///|
let oac_fatal_message = "OptimizeAddedConstants can only be run when the --low-memory-unused flag is set."

///|
priv struct GetParents {
  parent_map : Map[Int, TInstr]
}

///|
fn GetParents::new(body : TExpr) -> GetParents {
  let parent_map = Map::new()
  let parent_stack : Array[TInstr] = []
  let next_get_id = Ref::new(0)
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    match curr {
      TLocalGet(_) =>
        match parent_stack.last() {
          Some(parent) => {
            parent_map[next_get_id.val] = parent
            next_get_id.update(fn(n) { n + 1 })
          }
          None => abort("GetParents expected local.get to have a parent")
        }
      _ => ()
    }
    parent_stack.push(curr)
    let out = self.walk_tinstruction_default((), curr)
    ignore(parent_stack.pop())
    out
  })
  ignore(walker.walk_texpr((), body))
  GetParents::{ parent_map, }
}

///|
fn GetParents::get_parent(self : GetParents, get_id : Int) -> TInstr {
  match self.parent_map.get(get_id) {
    Some(parent) => parent
    None => abort("GetParents missing parent mapping for local.get")
  }
}

///|
priv struct OACLocalGetInfo {
  get_id : Int
  local_idx : LocalIdx
}

///|
priv struct OACSSAInfo {
  local_get_ids : Map[LocalIdx, Array[Int]]
  set_counts : Map[LocalIdx, Int]
  tee_locals : Set[LocalIdx]
}

///|
priv struct OACSetKey {
  local_idx : LocalIdx
  root : TInstr
} derive(Eq, Hash)

///|
priv struct OACIterationState {
  options : OptimizeOptions
  mod : Module
  local_graph : LocalGraph?
  propagatable : Set[OACSetKey]
  helper_indexes : Map[OACSetKey, LocalIdx]
  ssa_info : OACSSAInfo?
  ssa_cache : Map[LocalIdx, Bool]
  locals : Array[ValType]
  mut propagated : Bool
}

///|
priv struct MemoryAccessOptimizer {
  state : OACIterationState
  ptr_get_id : Int?
  memory64 : Bool
  mut memarg : MemArg
  mut ptr : TInstr
}

///|
fn oac_collect_local_get_infos(body : TExpr) -> Array[OACLocalGetInfo] {
  let infos : Array[OACLocalGetInfo] = []
  let next_get_id = Ref::new(0)
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    match curr {
      TLocalGet(local_idx) => {
        infos.push({ get_id: next_get_id.val, local_idx })
        next_get_id.update(fn(n) { n + 1 })
      }
      _ => ()
    }
    self.walk_tinstruction_default((), curr)
  })
  ignore(walker.walk_texpr((), body))
  infos
}

///|
fn oac_collect_all_sets(body : TExpr) -> Array[OACSetKey] {
  let sets : Array[OACSetKey] = []
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    match curr {
      TLocalSet(local_idx, value) =>
        sets.push({ local_idx, root: TInstr::local_set(local_idx, value) })
      _ => ()
    }
    self.walk_tinstruction_default((), curr)
  })
  ignore(walker.walk_texpr((), body))
  sets
}

///|
fn oac_build_set_influences(
  graph : LocalGraph,
  get_count : Int,
) -> Map[OACSetKey, Array[Int]] {
  let out : Map[OACSetKey, Array[Int]] = Map::new()
  for get_id in 0..<get_count {
    let sets = graph.get_sets(get_id)
    for set_ in sets {
      match set_ {
        LocalSet::Set(local_idx, root) => {
          let key : OACSetKey = { local_idx, root }
          let influences = out.get(key).unwrap_or([])
          influences.push(get_id)
          out[key] = influences
        }
        LocalSet::InitValue => ()
      }
    }
  }
  out
}

///|
fn oac_build_local_get_id_map(
  infos : Array[OACLocalGetInfo],
) -> Map[LocalIdx, Array[Int]] {
  let out = Map::new()
  for info in infos {
    let ids = out.get(info.local_idx).unwrap_or([])
    ids.push(info.get_id)
    out[info.local_idx] = ids
  }
  out
}

///|
fn oac_collect_tee_locals(body : TExpr) -> Set[LocalIdx] {
  let out = Set::new()
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    match curr {
      TLocalTee(local_idx, _) => out.add(local_idx)
      _ => ()
    }
    self.walk_tinstruction_default((), curr)
  })
  ignore(walker.walk_texpr((), body))
  out
}

///|
fn oac_collect_set_counts(body : TExpr) -> Map[LocalIdx, Int] {
  let counts : Map[LocalIdx, Int] = Map::new()
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    match curr {
      TLocalSet(local_idx, _) | TLocalTee(local_idx, _) => {
        let current = counts.get(local_idx).unwrap_or(0)
        counts[local_idx] = current + 1
      }
      _ => ()
    }
    self.walk_tinstruction_default((), curr)
  })
  ignore(walker.walk_texpr((), body))
  counts
}

///|
fn oac_make_ssa_info(
  body : TExpr,
  infos : Array[OACLocalGetInfo],
) -> OACSSAInfo {
  {
    local_get_ids: oac_build_local_get_id_map(infos),
    set_counts: oac_collect_set_counts(body),
    tee_locals: oac_collect_tee_locals(body),
  }
}

///|
fn oac_is_load_or_store_parent(parent : TInstr) -> Bool {
  match parent {
    TLoad(_, _, _) | TStore(_, _, _, _) => true
    _ => false
  }
}

///|
fn oac_is_const(instr : TInstr) -> Bool {
  match instr {
    TI32Const(_) | TI64Const(_) => true
    _ => false
  }
}

///|
fn oac_is_add(op : BinaryOp) -> Bool {
  match op {
    I32AddOp | I64AddOp => true
    _ => false
  }
}

///|
fn oac_is_i32_add(op : BinaryOp) -> Bool {
  match op {
    I32AddOp => true
    _ => false
  }
}

///|
fn oac_const_to_u64(instr : TInstr) -> UInt64? {
  match instr {
    TI32Const(I32(v)) => Some(v.reinterpret_as_uint().to_uint64())
    TI64Const(I64(v)) => Some(v.reinterpret_as_uint64())
    _ => None
  }
}

///|
fn oac_memarg_offset(memarg : MemArg) -> UInt64 {
  let MemArg(_, _, U64(offset)) = memarg
  offset
}

///|
fn oac_memarg_with_offset(memarg : MemArg, offset : UInt64) -> MemArg {
  let MemArg(align, mem, _) = memarg
  MemArg::new(align, mem, U64(offset))
}

///|
fn oac_default_memory64(mod : Module) -> Bool {
  match mod.mem_sec {
    Some(MemSec(memories)) =>
      match memories.get(0) {
        Some(MemType(I64Limits(_))) => true
        _ => false
      }
    None => false
  }
}

///|
fn oac_memory_is_64(mod : Module, memarg : MemArg) -> Bool {
  let MemArg(_, mem_idx, _) = memarg
  match mem_idx {
    Some(MemIdx(raw)) =>
      match mod.mem_sec {
        Some(MemSec(memories)) =>
          match memories.get(raw.reinterpret_as_int()) {
            Some(MemType(I64Limits(_))) => true
            _ => false
          }
        None => false
      }
    None => oac_default_memory64(mod)
  }
}

///|
fn oac_find_propagatable(
  body : TExpr,
  graph : LocalGraph,
  infos : Array[OACLocalGetInfo],
) -> Set[OACSetKey] {
  let propagatable : Set[OACSetKey] = Set::new()
  let parents = GetParents::new(body)
  let influences = oac_build_set_influences(graph, infos.length())
  let all_sets = oac_collect_all_sets(body)
  for set_ in all_sets {
    match set_ {
      { root: TLocalSet(_, TBinary(op, left, right)), .. } =>
        if oac_is_i32_add(op) && (oac_is_const(left) || oac_is_const(right)) {
          let mut ok = true
          for get_id in influences.get(set_).unwrap_or([]) {
            let parent = parents.get_parent(get_id)
            if !oac_is_load_or_store_parent(parent) {
              ok = false
              break
            }
          }
          if ok {
            propagatable.add(set_)
          }
        }
      _ => ()
    }
  }
  propagatable
}

///|
fn oac_get_helper_index(
  state : OACIterationState,
  set_ : OACSetKey,
) -> LocalIdx {
  match state.helper_indexes.get(set_) {
    Some(idx) => idx
    None => {
      let next_idx = LocalIdx::new(state.locals.length().reinterpret_as_uint())
      state.locals.push(ValType::i32())
      state.helper_indexes[set_] = next_idx
      next_idx
    }
  }
}

///|
fn oac_local_is_ssa(state : OACIterationState, local_idx : LocalIdx) -> Bool {
  match state.ssa_cache.get(local_idx) {
    Some(cached) => cached
    None => {
      let computed = match (state.local_graph, state.ssa_info) {
        (Some(graph), Some(info)) =>
          if info.tee_locals.contains(local_idx) {
            false
          } else if info.set_counts.get(local_idx).unwrap_or(0) > 1 {
            false
          } else {
            let get_ids = info.local_get_ids.get(local_idx).unwrap_or([])
            if get_ids.is_empty() {
              false
            } else {
              let seen = Set::new()
              let mut ok = true
              for get_id in get_ids {
                let sets = graph.get_sets(get_id)
                if sets.length() != 1 {
                  ok = false
                  break
                }
                let set_key = sets.to_array()[0]
                match set_key {
                  LocalSet::Set(set_local, _) => {
                    if set_local != local_idx {
                      ok = false
                      break
                    }
                    seen.add(set_key)
                    if seen.length() > 1 {
                      ok = false
                      break
                    }
                  }
                  LocalSet::InitValue => {
                    ok = false
                    break
                  }
                }
              }
              ok
            }
          }
        _ => false
      }
      state.ssa_cache[local_idx] = computed
      computed
    }
  }
}

///|
fn MemoryAccessOptimizer::new(
  state : OACIterationState,
  memarg : MemArg,
  ptr : TInstr,
  ptr_get_id : Int?,
) -> MemoryAccessOptimizer {
  {
    state,
    ptr_get_id,
    memory64: oac_memory_is_64(state.mod, memarg),
    memarg,
    ptr,
  }
}

///|
fn MemoryAccessOptimizer::can_optimize_constant(
  self : MemoryAccessOptimizer,
  value : UInt64,
) -> UInt64? {
  let bound = self.state.options.low_memory_bound
  let current = oac_memarg_offset(self.memarg)
  if value >= bound {
    return None
  }
  let total = current + value
  if total < current {
    return None
  }
  if total >= bound {
    return None
  }
  Some(total)
}

///|
fn MemoryAccessOptimizer::optimize_constant_pointer(
  self : MemoryAccessOptimizer,
) -> Unit {
  let offset = oac_memarg_offset(self.memarg)
  if offset == 0UL {
    return
  }
  if self.memory64 {
    match self.ptr {
      TI64Const(I64(base)) => {
        let base_u = base.reinterpret_as_uint64()
        let total = base_u + offset
        if total >= base_u {
          self.ptr = TInstr::i64_const(I64(total.reinterpret_as_int64()))
          self.memarg = oac_memarg_with_offset(self.memarg, 0UL)
        }
      }
      _ => ()
    }
  } else {
    match self.ptr {
      TI32Const(I32(base)) => {
        if offset > 4294967295UL {
          return
        }
        let base_u = base.reinterpret_as_uint().to_uint64()
        let total = base_u + offset
        if total < 4294967296UL {
          self.ptr = TInstr::i32_const(
            I32(total.to_uint().reinterpret_as_int()),
          )
          self.memarg = oac_memarg_with_offset(self.memarg, 0UL)
        }
      }
      _ => ()
    }
  }
}

///|
fn MemoryAccessOptimizer::try_to_optimize_constant(
  self : MemoryAccessOptimizer,
  one_side : TInstr,
  other_side : TInstr,
) -> Bool {
  match oac_const_to_u64(one_side) {
    Some(value) =>
      match self.can_optimize_constant(value) {
        Some(total) => {
          self.memarg = oac_memarg_with_offset(self.memarg, total)
          self.ptr = other_side
          match self.ptr {
            TI32Const(_) | TI64Const(_) => self.optimize_constant_pointer()
            _ => ()
          }
          true
        }
        None => false
      }
    None => false
  }
}

///|
fn MemoryAccessOptimizer::try_to_optimize_propagated_add(
  self : MemoryAccessOptimizer,
  one_side : TInstr,
  other_side : TInstr,
  ptr_local_idx : LocalIdx,
  set_ : OACSetKey,
) -> Bool {
  if oac_is_const(one_side) && oac_is_const(other_side) {
    return false
  }
  let value = match oac_const_to_u64(one_side) {
    Some(v) => v
    None => return false
  }
  let total = match self.can_optimize_constant(value) {
    Some(v) => v
    None => return false
  }
  let base_local = match other_side {
    TLocalGet(other_idx) =>
      if oac_local_is_ssa(self.state, other_idx) &&
        oac_local_is_ssa(self.state, ptr_local_idx) {
        other_idx
      } else {
        oac_get_helper_index(self.state, set_)
      }
    _ => oac_get_helper_index(self.state, set_)
  }
  self.memarg = oac_memarg_with_offset(self.memarg, total)
  self.ptr = TInstr::local_get(base_local)
  true
}

///|
fn MemoryAccessOptimizer::optimize(self : MemoryAccessOptimizer) -> Bool {
  match self.ptr {
    TI32Const(_) | TI64Const(_) => {
      self.optimize_constant_pointer()
      return false
    }
    _ => ()
  }
  match self.ptr {
    TBinary(op, left, right) if oac_is_add(op) =>
      if self.try_to_optimize_constant(right, left) ||
        self.try_to_optimize_constant(left, right) {
        return false
      }
    _ => ()
  }
  match (self.state.local_graph, self.ptr_get_id, self.ptr) {
    (Some(graph), Some(get_id), TLocalGet(ptr_local_idx)) => {
      let sets = graph.get_sets(get_id)
      if sets.length() != 1 {
        return false
      }
      let set_src = sets.to_array()[0]
      match set_src {
        LocalSet::InitValue => false
        LocalSet::Set(set_local_idx, set_root) =>
          match set_root {
            TLocalSet(_, TBinary(op, left, right)) =>
              if !oac_is_i32_add(op) {
                false
              } else {
                let set_key : OACSetKey = {
                  local_idx: set_local_idx,
                  root: set_root,
                }
                if !self.state.propagatable.contains(set_key) {
                  false
                } else if self.try_to_optimize_propagated_add(
                    right, left, ptr_local_idx, set_key,
                  ) ||
                  self.try_to_optimize_propagated_add(
                    left, right, ptr_local_idx, set_key,
                  ) {
                  true
                } else {
                  false
                }
              }
            _ => false
          }
      }
    }
    _ => false
  }
}

///|
fn oac_insert_helper_indexes(
  body : TExpr,
  helper_indexes : Map[OACSetKey, LocalIdx],
) -> TExpr {
  if helper_indexes.is_empty() {
    return body
  }
  let pass = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    match curr {
      TLocalSet(local_idx, TBinary(op, left, right)) if oac_is_i32_add(op) =>
        match
          helper_indexes.get(OACSetKey::{
            local_idx,
            root: TInstr::local_set(local_idx, TInstr::binary(op, left, right)),
          }) {
          Some(helper_idx) => {
            let maybe_target = match (left, right) {
              (a, b) if oac_is_const(a) && !oac_is_const(b) =>
                Some((b, TInstr::binary(op, a, TInstr::local_get(helper_idx))))
              (a, b) if !oac_is_const(a) && oac_is_const(b) =>
                Some((a, TInstr::binary(op, TInstr::local_get(helper_idx), b)))
              _ => None
            }
            match maybe_target {
              Some((target, rewritten_add)) =>
                change(
                  (),
                  TInstr::block(
                    BlockType::void_(),
                    TExpr::new([
                      TInstr::local_set(helper_idx, target),
                      TInstr::local_set(local_idx, rewritten_add),
                    ]),
                  ),
                )
              None => self.walk_tinstruction_default((), curr)
            }
          }
          None => self.walk_tinstruction_default((), curr)
        }
      _ => self.walk_tinstruction_default((), curr)
    }
  })
  match pass.walk_texpr((), body) {
    Ok(Some((_, updated))) => updated
    Ok(None) => body
    Err(_) => body
  }
}

///|
fn oac_binary_traps(op : BinaryOp) -> Bool {
  match op {
    I32DivSOp
    | I32DivUOp
    | I32RemSOp
    | I32RemUOp
    | I64DivSOp
    | I64DivUOp
    | I64RemSOp
    | I64RemUOp => true
    _ => false
  }
}

///|
fn oac_has_side_effects(instr : TInstr) -> Bool {
  match instr {
    TI32Const(_)
    | TI64Const(_)
    | TF32Const(_)
    | TF64Const(_)
    | TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | TRefNull(_)
    | TRefFunc(_)
    | TLocalGet(_)
    | TGlobalGet(_)
    | TMemorySize(_)
    | TTableSize(_) => false
    TBinary(op, left, right) =>
      if oac_binary_traps(op) {
        true
      } else {
        oac_has_side_effects(left) || oac_has_side_effects(right)
      }
    TRefEq(left, right) =>
      oac_has_side_effects(left) || oac_has_side_effects(right)
    _ => true
  }
}

///|
fn oac_collect_used_locals(body : TExpr) -> Set[LocalIdx] {
  let used = Set::new()
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    match curr {
      TLocalGet(local_idx) => used.add(local_idx)
      _ => ()
    }
    self.walk_tinstruction_default((), curr)
  })
  ignore(walker.walk_texpr((), body))
  used
}

///|
fn oac_cleanup_unneeded_sets(body : TExpr) -> TExpr {
  let mut curr_body = body
  while true {
    let used = oac_collect_used_locals(curr_body)
    let changed = Ref::new(false)
    let remover = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      curr,
    ) {
      match curr {
        TLocalSet(local_idx, value) => {
          let next_value = match self.walk_tinstruction((), value) {
            Ok(Some((_, updated))) => updated
            Ok(None) => value
            Err(_) => value
          }
          if !used.contains(local_idx) {
            changed.update(fn(_) { true })
            if oac_has_side_effects(next_value) {
              change((), TInstr::drop(next_value))
            } else {
              change((), TInstr::nop())
            }
          } else if next_value == value {
            unchanged()
          } else {
            change((), TInstr::local_set(local_idx, next_value))
          }
        }
        _ => self.walk_tinstruction_default((), curr)
      }
    })
    curr_body = match remover.walk_texpr((), curr_body) {
      Ok(Some((_, updated))) => updated
      Ok(None) => curr_body
      Err(_) => curr_body
    }
    if !changed.val {
      break
    }
  }
  curr_body
}

///|
fn oac_rewrite_body(
  body : TExpr,
  state : OACIterationState,
) -> Result[TExpr, String] {
  let next_get_id = Ref::new(0)
  let pass = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    match curr {
      TLocalGet(_) => {
        next_get_id.update(fn(n) { n + 1 })
        unchanged()
      }
      TLoad(_, _, ptr) => {
        let ptr_get_id = match ptr {
          TLocalGet(_) => Some(next_get_id.val)
          _ => None
        }
        let walked = match self.walk_tinstruction_default((), curr) {
          Ok(Some((_, updated))) => updated
          Ok(None) => curr
          Err(e) => return Err(e)
        }
        match walked {
          TLoad(next_op, next_memarg, next_ptr) => {
            let optimizer = MemoryAccessOptimizer::new(
              state, next_memarg, next_ptr, ptr_get_id,
            )
            if optimizer.optimize() {
              state.propagated = true
            }
            change((), TInstr::load(next_op, optimizer.memarg, optimizer.ptr))
          }
          _ => change((), walked)
        }
      }
      TStore(_, _, ptr, _) => {
        let ptr_get_id = match ptr {
          TLocalGet(_) => Some(next_get_id.val)
          _ => None
        }
        let walked = match self.walk_tinstruction_default((), curr) {
          Ok(Some((_, updated))) => updated
          Ok(None) => curr
          Err(e) => return Err(e)
        }
        match walked {
          TStore(next_op, next_memarg, next_ptr, next_value) => {
            let optimizer = MemoryAccessOptimizer::new(
              state, next_memarg, next_ptr, ptr_get_id,
            )
            if optimizer.optimize() {
              state.propagated = true
            }
            change(
              (),
              TInstr::store(
                next_op,
                optimizer.memarg,
                optimizer.ptr,
                next_value,
              ),
            )
          }
          _ => change((), walked)
        }
      }
      _ => self.walk_tinstruction_default((), curr)
    }
  })
  match pass.walk_texpr((), body) {
    Ok(Some((_, updated))) => Ok(updated)
    Ok(None) => Ok(body)
    Err(e) => Err(e)
  }
}

///|
fn optimize_added_constants_on_func(
  func : Func,
  mod : Module,
  options : OptimizeOptions,
  propagate : Bool,
) -> Result[Func, String] {
  if !options.low_memory_unused {
    return Err(oac_fatal_message)
  }
  if mod.mem_sec is None {
    return Ok(func)
  }
  match func {
    Func(_) => Err("Expected TFunc")
    TFunc(initial_locals, initial_body) => {
      let mut locals = initial_locals
      let mut body = initial_body
      while true {
        let infos = if propagate {
          oac_collect_local_get_infos(body)
        } else {
          []
        }
        let local_graph = if propagate {
          Some(LocalGraph::new(body.0))
        } else {
          None
        }
        let propagatable = match local_graph {
          Some(graph) => oac_find_propagatable(body, graph, infos)
          None => Set::new()
        }
        let state : OACIterationState = {
          options,
          mod,
          local_graph,
          propagatable,
          helper_indexes: Map::new(),
          ssa_info: if propagate {
            Some(oac_make_ssa_info(body, infos))
          } else {
            None
          },
          ssa_cache: Map::new(),
          locals,
          propagated: false,
        }
        body = match oac_rewrite_body(body, state) {
          Ok(next_body) => next_body
          Err(e) => return Err(e)
        }
        if !state.helper_indexes.is_empty() {
          body = oac_insert_helper_indexes(body, state.helper_indexes)
        }
        locals = state.locals
        if state.propagated {
          body = oac_cleanup_unneeded_sets(body)
          continue
        }
        break
      }
      Ok(Func::t_func(locals, body))
    }
  }
}

///|
fn optimize_added_constants_ir_pass(
  mod : Module,
  options : OptimizeOptions,
  propagate : Bool,
) -> ModuleTransformer[IRContext] {
  ModuleTransformer::new().on_func_evt(fn(_self, t : IRContext, func) {
    match optimize_added_constants_on_func(func, mod, options, propagate) {
      Ok(next_func) =>
        match (func, next_func) {
          (TFunc(orig_locals, orig_body), TFunc(next_locals, next_body)) => {
            t.set_body(next_body)
            if orig_locals == next_locals && orig_body == next_body {
              unchanged()
            } else {
              change(t, Func::t_func(next_locals, next_body))
            }
          }
          _ => change(t, next_func)
        }
      Err(e) => Err(e)
    }
  })
}

///|
pub fn createOptimizeAddedConstantsPass() -> ModulePass {
  ModulePass::OptimizeAddedConstants
}

///|
pub fn createOptimizeAddedConstantsPropagatePass() -> ModulePass {
  ModulePass::OptimizeAddedConstantsPropagate
}

///|
fn oac_run_func(
  body : Array[TInstr],
  locals? : Array[ValType] = [],
  options? : OptimizeOptions = OptimizeOptions::new(
    low_memory_unused=true,
    low_memory_bound=1024UL,
  ),
  propagate? : Bool = false,
  memory64? : Bool = false,
) -> Result[(Array[ValType], TExpr), String] {
  let memory = if memory64 {
    MemType::new(Limits::i64(1UL, None))
  } else {
    MemType::new(Limits::i32(1, None))
  }
  let mod_ = Module::new()
    .with_mem_sec(MemSec::new([memory]))
    .with_code_sec(CodeSec::new([Func::t_func(locals, TExpr::new(body))]))
  let passes = if propagate {
    [ModulePass::OptimizeAddedConstantsPropagate]
  } else {
    [ModulePass::OptimizeAddedConstants]
  }
  match optimize_module_with_options(mod_, passes, options) {
    Ok(out) =>
      match out.code_sec {
        Some(CodeSec([TFunc(new_locals, new_body)])) =>
          Ok((new_locals, new_body))
        _ => Err("expected one transformed TFunc")
      }
    Err(e) => Err(e)
  }
}

///|
test "optimize added constants folds load add-const into offset" {
  let p = LocalIdx::new(0)
  let body = [
    TInstr::load(
      LoadOp::i32_load(),
      MemArg::new(U32(4), None, U64(0UL)),
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::local_get(p),
        TInstr::i32_const(I32(8)),
      ),
    ),
  ]
  let (_, out_body) = oac_run_func(body, locals=[ValType::i32()]).unwrap()
  match out_body {
    TExpr([instr]) =>
      match instr {
        TLoad(I32LoadOp, MemArg(U32(4), None, U64(8)), TLocalGet(LocalIdx(i))) =>
          assert_eq(i.reinterpret_as_int(), 0)
        _ => fail("expected i32.load offset=8 with local.get base")
      }
    _ => fail("expected one instruction")
  }
}

///|
test "optimize added constants folds store add-const into offset" {
  let p = LocalIdx::new(0)
  let v = LocalIdx::new(1)
  let body = [
    TInstr::store(
      StoreOp::i32_store(),
      MemArg::new(U32(4), None, U64(0UL)),
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::local_get(p),
        TInstr::i32_const(I32(8)),
      ),
      TInstr::local_get(v),
    ),
  ]
  let (_, out_body) = oac_run_func(body, locals=[ValType::i32(), ValType::i32()]).unwrap()
  match out_body {
    TExpr([instr]) =>
      match instr {
        TStore(
          I32StoreOp,
          MemArg(U32(4), None, U64(8)),
          TLocalGet(LocalIdx(i)),
          TLocalGet(LocalIdx(j))
        ) => {
          assert_eq(i.reinterpret_as_int(), 0)
          assert_eq(j.reinterpret_as_int(), 1)
        }
        _ => fail("expected i32.store offset=8 with unchanged value")
      }
    _ => fail("expected one instruction")
  }
}

///|
test "optimize added constants respects low memory bound checks" {
  let p = LocalIdx::new(0)
  let options = OptimizeOptions::new(
    low_memory_unused=true,
    low_memory_bound=16UL,
  )
  let body = [
    TInstr::load(
      LoadOp::i32_load(),
      MemArg::new(U32(4), None, U64(4UL)),
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::local_get(p),
        TInstr::i32_const(I32(8)),
      ),
    ),
    TInstr::load(
      LoadOp::i32_load(),
      MemArg::new(U32(4), None, U64(12UL)),
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::local_get(p),
        TInstr::i32_const(I32(8)),
      ),
    ),
    TInstr::load(
      LoadOp::i32_load(),
      MemArg::new(U32(4), None, U64(0UL)),
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::local_get(p),
        TInstr::i32_const(I32(16)),
      ),
    ),
  ]
  let (_, TExpr(instrs)) = oac_run_func(body, locals=[ValType::i32()], options~).unwrap()
  match instrs[0] {
    TLoad(_, MemArg(_, _, U64(off)), _) => assert_eq(off, 12UL)
    _ => fail("expected first load to fold")
  }
  match instrs[1] {
    TLoad(_, MemArg(_, _, U64(off)), TBinary(I32AddOp, _, _)) =>
      assert_eq(off, 12UL)
    _ => fail("expected second load to remain unfused")
  }
  match instrs[2] {
    TLoad(_, MemArg(_, _, U64(off)), TBinary(I32AddOp, _, _)) =>
      assert_eq(off, 0UL)
    _ => fail("expected third load to remain unfused")
  }
}

///|
test "optimize added constants normalizes const pointer plus offset for memory32" {
  let body = [
    TInstr::load(
      LoadOp::i32_load(),
      MemArg::new(U32(4), None, U64(4UL)),
      TInstr::i32_const(I32(10)),
    ),
    TInstr::load(
      LoadOp::i32_load(),
      MemArg::new(U32(4), None, U64(1UL)),
      TInstr::i32_const(I32(-1)),
    ),
  ]
  let (_, TExpr(instrs)) = oac_run_func(body).unwrap()
  match instrs[0] {
    TLoad(_, MemArg(_, _, U64(off)), TI32Const(I32(v))) => {
      assert_eq(off, 0UL)
      assert_eq(v, 14)
    }
    _ => fail("expected const pointer normalization on first load")
  }
  match instrs[1] {
    TLoad(_, MemArg(_, _, U64(off)), TI32Const(I32(v))) => {
      assert_eq(off, 1UL)
      assert_eq(v, -1)
    }
    _ => fail("expected memory32 overflow case to keep offset")
  }
}

///|
test "optimize added constants normalizes const pointer plus offset for memory64" {
  let body = [
    TInstr::load(
      LoadOp::i32_load(),
      MemArg::new(U32(4), None, U64(4UL)),
      TInstr::i64_const(I64(10)),
    ),
    TInstr::load(
      LoadOp::i32_load(),
      MemArg::new(U32(4), None, U64(1UL)),
      TInstr::i64_const(I64(-1L)),
    ),
  ]
  let (_, TExpr(instrs)) = oac_run_func(body, memory64=true).unwrap()
  match instrs[0] {
    TLoad(_, MemArg(_, _, U64(off)), TI64Const(I64(v))) => {
      assert_eq(off, 0UL)
      assert_eq(v, 14L)
    }
    _ => fail("expected const pointer normalization on memory64")
  }
  match instrs[1] {
    TLoad(_, MemArg(_, _, U64(off)), TI64Const(I64(v))) => {
      assert_eq(off, 1UL)
      assert_eq(v, -1L)
    }
    _ => fail("expected memory64 overflow case to keep offset")
  }
}

///|
test "optimize added constants propagate mode reuses SSA base local" {
  let y = LocalIdx::new(0)
  let x = LocalIdx::new(1)
  let body = [
    TInstr::local_set(y, TInstr::i32_const(I32(100))),
    TInstr::local_set(
      x,
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::local_get(y),
        TInstr::i32_const(I32(10)),
      ),
    ),
    TInstr::load(
      LoadOp::i32_load(),
      MemArg::new(U32(4), None, U64(0UL)),
      TInstr::local_get(x),
    ),
  ]
  let (locals, TExpr(instrs)) = oac_run_func(
    body,
    locals=[ValType::i32(), ValType::i32()],
    propagate=true,
  ).unwrap()
  assert_eq(locals.length(), 2)
  match instrs.last().unwrap() {
    TLoad(I32LoadOp, MemArg(_, _, U64(off)), TLocalGet(LocalIdx(raw))) => {
      assert_eq(off, 10UL)
      assert_eq(raw.reinterpret_as_int(), 0)
    }
    _ => fail("expected propagated load to use y with offset=10")
  }
}

///|
test "optimize added constants propagate rejects non-load-store parents" {
  let y = LocalIdx::new(0)
  let x = LocalIdx::new(1)
  let body = [
    TInstr::local_set(y, TInstr::i32_const(I32(100))),
    TInstr::local_set(
      x,
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::local_get(y),
        TInstr::i32_const(I32(10)),
      ),
    ),
    TInstr::drop(TInstr::local_get(x)),
    TInstr::load(
      LoadOp::i32_load(),
      MemArg::new(U32(4), None, U64(0UL)),
      TInstr::local_get(x),
    ),
  ]
  let (_, TExpr(instrs)) = oac_run_func(
    body,
    locals=[ValType::i32(), ValType::i32()],
    propagate=true,
  ).unwrap()
  match instrs.last().unwrap() {
    TLoad(I32LoadOp, MemArg(_, _, U64(off)), TLocalGet(LocalIdx(raw))) => {
      assert_eq(off, 0UL)
      assert_eq(raw.reinterpret_as_int(), 1)
    }
    _ => fail("expected propagation to be rejected")
  }
}

///|
test "optimize added constants propagate inserts helper local when needed" {
  let y = LocalIdx::new(0)
  let x = LocalIdx::new(1)
  let body = [
    TInstr::local_set(y, TInstr::i32_const(I32(1))),
    TInstr::local_set(
      x,
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::local_get(y),
        TInstr::i32_const(I32(10)),
      ),
    ),
    TInstr::local_set(y, TInstr::i32_const(I32(2))),
    TInstr::load(
      LoadOp::i32_load(),
      MemArg::new(U32(4), None, U64(0UL)),
      TInstr::local_get(x),
    ),
  ]
  let (locals, TExpr(instrs)) = oac_run_func(
    body,
    locals=[ValType::i32(), ValType::i32()],
    propagate=true,
  ).unwrap()
  assert_eq(locals.length(), 3)
  let helper_idx = locals.length() - 1
  match instrs.last().unwrap() {
    TLoad(I32LoadOp, MemArg(_, _, U64(off)), TLocalGet(LocalIdx(raw))) => {
      assert_eq(off, 10UL)
      assert_eq(raw.reinterpret_as_int(), helper_idx)
    }
    _ => fail("expected propagated load to use helper local")
  }
}

///|
test "optimize added constants propagate iterates to reach fixpoint" {
  let y = LocalIdx::new(0)
  let x = LocalIdx::new(1)
  let z = LocalIdx::new(2)
  let body = [
    TInstr::local_set(y, TInstr::i32_const(I32(100))),
    TInstr::local_set(
      x,
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::local_get(y),
        TInstr::i32_const(I32(4)),
      ),
    ),
    TInstr::local_set(
      z,
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::local_get(x),
        TInstr::i32_const(I32(8)),
      ),
    ),
    TInstr::load(
      LoadOp::i32_load(),
      MemArg::new(U32(4), None, U64(0UL)),
      TInstr::local_get(z),
    ),
  ]
  let (_, TExpr(instrs)) = oac_run_func(
    body,
    locals=[ValType::i32(), ValType::i32(), ValType::i32()],
    propagate=true,
  ).unwrap()
  match instrs.last().unwrap() {
    TLoad(I32LoadOp, MemArg(_, _, U64(off)), TLocalGet(LocalIdx(raw))) => {
      assert_eq(off, 12UL)
      assert_eq(raw.reinterpret_as_int(), 0)
    }
    _ => fail("expected iterative propagation to reach y + 12")
  }
}

///|
test "optimize added constants requires low-memory-unused option" {
  let body = [
    TInstr::load(
      LoadOp::i32_load(),
      MemArg::new(U32(4), None, U64(0UL)),
      TInstr::i32_const(I32(0)),
    ),
  ]
  let memory = MemType::new(Limits::i32(1, None))
  let mod_ = Module::new()
    .with_mem_sec(MemSec::new([memory]))
    .with_code_sec(CodeSec::new([Func::t_func([], TExpr::new(body))]))
  match optimize_module(mod_, [ModulePass::OptimizeAddedConstants]) {
    Ok(_) => fail("expected optimize added constants to fail without option")
    Err(e) => assert_eq(e, oac_fatal_message)
  }
}
