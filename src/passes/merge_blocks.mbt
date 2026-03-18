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
priv struct BranchCacheQueryKey {
  instr_id : Int
  depth : Int
  generation : Int
} derive(Eq, Hash)

///|
priv struct BranchCacheInstrIdEntry {
  instr_id : Int
  instr : TInstr
}

///|
priv struct BranchCache {
  query_entries : Map[BranchCacheQueryKey, Bool]
  instr_id_entries : Array[BranchCacheInstrIdEntry]
  mut next_instr_id : Int
  mut generation : Int
  mut query_hits : Int
  mut query_misses : Int
  mut instr_id_hits : Int
  mut instr_id_misses : Int
  mut invalidations : Int
}

///|
fn BranchCache::new() -> BranchCache {
  {
    query_entries: Map::new(),
    instr_id_entries: [],
    next_instr_id: 0,
    generation: 0,
    query_hits: 0,
    query_misses: 0,
    instr_id_hits: 0,
    instr_id_misses: 0,
    invalidations: 0,
  }
}

///|
fn mb_branch_cache_instr_id(cache : BranchCache, instr : TInstr) -> Int {
  for entry in cache.instr_id_entries {
    if physical_equal(entry.instr, instr) {
      cache.instr_id_hits += 1
      return entry.instr_id
    }
  }
  let instr_id = cache.next_instr_id
  cache.next_instr_id += 1
  cache.instr_id_misses += 1
  cache.instr_id_entries.push({ instr_id, instr })
  instr_id
}

///|
fn mb_branch_cache_invalidate(cache : BranchCache) -> Unit {
  cache.generation += 1
  cache.invalidations += 1
}

///|
fn mb_branch_cache_hit_rate_bp(cache : BranchCache) -> UInt64 {
  let total_queries = cache.query_hits + cache.query_misses
  if total_queries <= 0 {
    0UL
  } else {
    cache.query_hits.to_uint64() * 10000UL / total_queries.to_uint64()
  }
}

///|
fn mb_branch_cache_stress_hit_rate_bp(repetitions : Int) -> UInt64 {
  let cache = BranchCache::new()
  let probes : Array[TInstr] = [
    TInstr::br(LabelIdx::new(0), []),
    TInstr::br_if(LabelIdx::new(0), TInstr::i32_const(I32(0)), []),
    TInstr::block(
      BlockType::void_(),
      TExpr::new([TInstr::br(LabelIdx::new(0), [])]),
    ),
    TInstr::if_(
      BlockType::void_(),
      TInstr::i32_const(I32(1)),
      TExpr::new([TInstr::br(LabelIdx::new(0), [])]),
      Some(TExpr::new([TInstr::nop()])),
    ),
  ]
  for _ in 0..<repetitions {
    for probe in probes {
      ignore(mb_has_branch_to_depth(probe, 0, cache))
      ignore(mb_has_branch_to_depth(probe, 1, cache))
    }
  }
  mb_branch_cache_hit_rate_bp(cache)
}

///|
priv struct MBStableInstrKey {
  instr : TInstr
} derive(Eq, Hash)

///|
fn mb_stable_instr_key(instr : TInstr) -> MBStableInstrKey {
  MBStableInstrKey::{ instr, }
}

///|
priv struct MBEffects {
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
fn MBEffects::new() -> MBEffects {
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
fn MBEffects::merge(self : MBEffects, other : MBEffects) -> Unit {
  for idx in other.locals_read {
    self.locals_read.add(idx)
  }
  for idx in other.locals_written {
    self.locals_written.add(idx)
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
fn MBEffects::invalidates(self : MBEffects, other : MBEffects) -> Bool {
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
  if self.branches || other.branches || self.throws || other.throws {
    return true
  }
  if self.traps || other.traps {
    if self.has_side_effects() || other.has_side_effects() {
      return true
    }
  }
  false
}

///|
fn MBEffects::has_side_effects(self : MBEffects) -> Bool {
  self.locals_written.length() > 0 ||
  self.writes_memory ||
  self.writes_globals ||
  self.calls ||
  self.branches ||
  self.throws ||
  self.traps
}

///|
priv struct MBStackSig {
  required : Int
  produced : Int
  reachable : Bool
}

///|
fn MBStackSig::new(
  required : Int,
  produced : Int,
  reachable : Bool,
) -> MBStackSig {
  { required, produced, reachable }
}

///|

///|
fn mb_max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn mb_nonneg_int(i : Int) -> Int {
  if i > 0 {
    i
  } else {
    0
  }
}

///|
fn mb_stack_sig_is_consistent(sig : MBStackSig) -> Bool {
  sig.required >= 0 && (!sig.reachable || sig.produced >= 0)
}

///|
fn mb_stack_sig_seq(a : MBStackSig, b : MBStackSig) -> MBStackSig {
  if !a.reachable {
    a
  } else {
    let upstream_slack = mb_nonneg_int(b.required - a.produced)
    let required = a.required + upstream_slack
    if !b.reachable {
      MBStackSig::new(required, 0, false)
    } else {
      MBStackSig::new(
        required,
        mb_nonneg_int(upstream_slack + a.produced - b.required + b.produced),
        true,
      )
    }
  }
}

///|
fn mb_stack_sig_pop_push(
  child_sig : MBStackSig,
  pop_count : Int,
  push_count : Int,
) -> MBStackSig {
  if !child_sig.reachable {
    child_sig
  } else {
    let upstream_slack = mb_nonneg_int(pop_count - child_sig.produced)
    MBStackSig::new(
      child_sig.required + upstream_slack,
      mb_nonneg_int(
        upstream_slack + child_sig.produced - pop_count + push_count,
      ),
      true,
    )
  }
}

///|
fn mb_stack_sig_terminate(
  child_sig : MBStackSig,
  pop_count : Int,
) -> MBStackSig {
  if !child_sig.reachable {
    child_sig
  } else {
    let upstream_slack = mb_nonneg_int(pop_count - child_sig.produced)
    MBStackSig::new(child_sig.required + upstream_slack, 0, false)
  }
}

///|
fn mb_call_args_match_params(
  args : Array[TInstr],
  params : Array[ValType],
  env : Env,
) -> Bool {
  if args.length() != params.length() {
    false
  } else {
    let mut matches = true
    for i = 0; i < params.length(); i = i + 1 {
      match mb_infer_tinstr_type(args[i], env) {
        Some(arg_ty) =>
          if arg_ty != params[i] {
            matches = false
            break
          }
        None => {
          matches = false
          break
        }
      }
    }
    matches
  }
}

///|
fn mb_local_set_arg_matches(
  local_idx : LocalIdx,
  value : TInstr,
  env : Env,
) -> Bool {
  match (env.get_local_type(local_idx), mb_infer_tinstr_type(value, env)) {
    (Some(want), Some(got)) => want == got
    _ => false
  }
}

///|
fn mb_global_set_arg_matches(
  global_idx : GlobalIdx,
  value : TInstr,
  env : Env,
) -> Bool {
  match (env.get_global_type(global_idx), mb_infer_tinstr_type(value, env)) {
    (Some(GlobalType(want, _)), Some(got)) => want == got
    _ => false
  }
}

///|
fn mb_stack_sig_list(items : Array[TInstr], env : Env) -> MBStackSig? {
  let mut acc = MBStackSig::new(0, 0, true)
  for item in items {
    match mb_stack_sig_instr(item, env) {
      Some(sig) => {
        acc = mb_stack_sig_seq(acc, sig)
        if !acc.reachable {
          break
        }
      }
      None => return None
    }
  }
  Some(acc)
}

///|
fn mb_stack_sig_if(
  cond_sig : MBStackSig,
  then_sig : MBStackSig,
  else_sig : MBStackSig,
) -> MBStackSig {
  if !cond_sig.reachable {
    return cond_sig
  }
  let branch_required = mb_max_int(then_sig.required, else_sig.required)
  let branch_reachable = then_sig.reachable || else_sig.reachable
  let then_produced = branch_required - then_sig.required + then_sig.produced
  let else_produced = branch_required - else_sig.required + else_sig.produced
  let branch_produced = if then_sig.reachable && else_sig.reachable {
    if then_produced < else_produced {
      then_produced
    } else {
      else_produced
    }
  } else if then_sig.reachable {
    then_produced
  } else if else_sig.reachable {
    else_produced
  } else {
    0
  }
  let need_after_cond = 1 + branch_required
  let upstream_slack = mb_nonneg_int(need_after_cond - cond_sig.produced)
  MBStackSig::new(
    cond_sig.required + upstream_slack,
    if branch_reachable {
      mb_nonneg_int(
        upstream_slack + cond_sig.produced - need_after_cond + branch_produced,
      )
    } else {
      0
    },
    branch_reachable,
  )
}

///|
fn mb_block_result_count(bt : BlockType, env : Env) -> Int? {
  match env.expand_blocktype(bt) {
    Ok((_, results)) => Some(results.length())
    Err(_) => None
  }
}

///|
fn mb_stack_sig_with_declared_results(
  child_sig : MBStackSig,
  result_count : Int,
) -> MBStackSig {
  if !child_sig.reachable {
    child_sig
  } else {
    let upstream_slack = mb_nonneg_int(result_count - child_sig.produced)
    MBStackSig::new(child_sig.required + upstream_slack, result_count, true)
  }
}

///|
fn mb_stack_sig_instr(instr : TInstr, env : Env) -> MBStackSig? {
  match instr.kind {
    TInstrKind::TNop => Some(MBStackSig::new(0, 0, true))
    TInstrKind::TUnreachable => Some(MBStackSig::new(0, 0, false))
    TInstrKind::TLocalGet(_)
    | TInstrKind::TGlobalGet(_)
    | TInstrKind::TI32Const(_)
    | TInstrKind::TI64Const(_)
    | TInstrKind::TF32Const(_)
    | TInstrKind::TF64Const(_)
    | TInstrKind::TRefNull(_)
    | TInstrKind::TRefFunc(_) => Some(MBStackSig::new(0, 1, true))
    TInstrKind::TDrop(value) =>
      mb_stack_sig_instr(value, env).map(fn(sig) {
        mb_stack_sig_pop_push(sig, 1, 0)
      })
    TInstrKind::TLocalSet(local_idx, value) =>
      if !mb_local_set_arg_matches(local_idx, value, env) {
        None
      } else {
        mb_stack_sig_instr(value, env).map(fn(sig) {
          mb_stack_sig_pop_push(sig, 1, 0)
        })
      }
    TInstrKind::TGlobalSet(global_idx, value) =>
      if !mb_global_set_arg_matches(global_idx, value, env) {
        None
      } else {
        mb_stack_sig_instr(value, env).map(fn(sig) {
          mb_stack_sig_pop_push(sig, 1, 0)
        })
      }
    TInstrKind::TLocalTee(local_idx, value) =>
      if !mb_local_set_arg_matches(local_idx, value, env) {
        None
      } else {
        mb_stack_sig_instr(value, env).map(fn(sig) {
          mb_stack_sig_pop_push(sig, 1, 1)
        })
      }
    TInstrKind::TUnary(_, value)
    | TInstrKind::TLoad(_, _, value)
    | TInstrKind::TRefIsNull(value)
    | TInstrKind::TRefAsNonNull(value)
    | TInstrKind::TAnyConvertExtern(value)
    | TInstrKind::TExternConvertAny(value)
    | TInstrKind::TI31GetS(value)
    | TInstrKind::TI31GetU(value)
    | TInstrKind::TArrayLen(value) =>
      mb_stack_sig_instr(value, env).map(fn(sig) {
        mb_stack_sig_pop_push(sig, 1, 1)
      })
    TInstrKind::TBinary(_, left, right) | TInstrKind::TRefEq(left, right) =>
      mb_stack_sig_list([left, right], env).map(fn(sig) {
        mb_stack_sig_pop_push(sig, 2, 1)
      })
    TInstrKind::TStore(_, _, addr, value) =>
      mb_stack_sig_list([addr, value], env).map(fn(sig) {
        mb_stack_sig_pop_push(sig, 2, 0)
      })
    TInstrKind::TSelect(_, cond, if_true, if_false) =>
      mb_stack_sig_list([if_true, if_false, cond], env).map(fn(sig) {
        mb_stack_sig_pop_push(sig, 3, 1)
      })
    TInstrKind::TBlock(bt, body)
    | TInstrKind::TLoop(bt, body)
    | TInstrKind::TTryTable(bt, _, body) =>
      match
        (mb_stack_sig_list(body.instrs, env), mb_block_result_count(bt, env)) {
        (Some(sig), Some(result_count)) =>
          Some(mb_stack_sig_with_declared_results(sig, result_count))
        _ => None
      }
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      let else_sig = match else_body {
        Some(other) => mb_stack_sig_list(other.instrs, env)
        None => Some(MBStackSig::new(0, 0, true))
      }
      match
        (
          mb_stack_sig_instr(cond, env),
          mb_stack_sig_list(then_body.instrs, env),
          else_sig,
        ) {
        (Some(cond_sig), Some(then_sig), Some(other_sig)) =>
          match instr.kind {
            TInstrKind::TIf(bt, _, _, _) =>
              match mb_block_result_count(bt, env) {
                Some(result_count) =>
                  Some(
                    mb_stack_sig_with_declared_results(
                      mb_stack_sig_if(cond_sig, then_sig, other_sig),
                      result_count,
                    ),
                  )
                None => None
              }
            _ => None
          }
        _ => None
      }
    }
    TInstrKind::TCall(func_idx, args) =>
      match env.get_functype_by_funcidx(func_idx) {
        Some(FuncType(params, results)) =>
          if !mb_call_args_match_params(args, params, env) {
            None
          } else {
            match mb_stack_sig_list(args, env) {
              Some(sig) =>
                Some(
                  mb_stack_sig_pop_push(sig, params.length(), results.length()),
                )
              None => None
            }
          }
        _ => None
      }
    TInstrKind::TCallIndirect(type_idx, _, args, callee)
    | TInstrKind::TCallRef(type_idx, args, callee) =>
      match env.resolve_functype(type_idx) {
        Some(FuncType(params, results)) =>
          if !mb_call_args_match_params(args, params, env) {
            None
          } else {
            match mb_stack_sig_list(args + [callee], env) {
              Some(sig) =>
                Some(
                  mb_stack_sig_pop_push(
                    sig,
                    params.length() + 1,
                    results.length(),
                  ),
                )
              None => None
            }
          }
        _ => None
      }
    TInstrKind::TReturn(values) | TInstrKind::TThrow(_, values) =>
      mb_stack_sig_list(values, env).map(fn(sig) {
        mb_stack_sig_terminate(sig, 0)
      })
    TInstrKind::TThrowRef(value) =>
      mb_stack_sig_instr(value, env).map(fn(sig) {
        mb_stack_sig_terminate(sig, 1)
      })
    TInstrKind::TBr(_, values) =>
      mb_stack_sig_list(values, env).map(fn(sig) {
        mb_stack_sig_terminate(sig, 0)
      })
    TInstrKind::TBrIf(_, cond, values) =>
      mb_stack_sig_list(values + [cond], env).map(fn(sig) {
        mb_stack_sig_pop_push(sig, 1, 0)
      })
    TInstrKind::TBrTable(_, _, index, values) =>
      mb_stack_sig_list(values + [index], env).map(fn(sig) {
        mb_stack_sig_terminate(sig, 1)
      })
    TInstrKind::TReturnCall(func_idx, args) =>
      match env.get_functype_by_funcidx(func_idx) {
        Some(FuncType(params, _)) =>
          if !mb_call_args_match_params(args, params, env) {
            None
          } else {
            match mb_stack_sig_list(args, env) {
              Some(sig) => Some(mb_stack_sig_terminate(sig, params.length()))
              None => None
            }
          }
        _ => None
      }
    TInstrKind::TReturnCallIndirect(type_idx, _, args, callee)
    | TInstrKind::TReturnCallRef(type_idx, args, callee) =>
      match env.resolve_functype(type_idx) {
        Some(FuncType(params, _)) =>
          if !mb_call_args_match_params(args, params, env) {
            None
          } else {
            match mb_stack_sig_list(args + [callee], env) {
              Some(sig) =>
                Some(mb_stack_sig_terminate(sig, params.length() + 1))
              None => None
            }
          }
        _ => None
      }
    _ => None
  }
}

///|
fn mb_rewrite_critical_types_hold_expr(expr : TExpr, env : Env) -> Bool {
  for instr in expr.instrs {
    if !mb_rewrite_critical_types_hold_instr(instr, env) {
      return false
    }
  }
  true
}

///|
fn mb_rewrite_critical_types_hold_instr(instr : TInstr, env : Env) -> Bool {
  match instr.kind {
    TInstrKind::TCall(func_idx, args) =>
      match env.get_functype_by_funcidx(func_idx) {
        Some(FuncType(params, _)) =>
          mb_rewrite_critical_types_hold_expr(TExpr::new(args), env) &&
          mb_call_args_match_params(args, params, env)
        _ => false
      }
    TInstrKind::TCallIndirect(type_idx, _, args, callee) =>
      match env.resolve_functype(type_idx) {
        Some(FuncType(params, _)) =>
          mb_rewrite_critical_types_hold_expr(TExpr::new(args), env) &&
          mb_rewrite_critical_types_hold_instr(callee, env) &&
          mb_call_args_match_params(args, params, env) &&
          mb_infer_tinstr_type(callee, env) == Some(ValType::i32())
        _ => false
      }
    TInstrKind::TCallRef(type_idx, args, callee) =>
      match env.resolve_functype(type_idx) {
        Some(FuncType(params, _)) => {
          let callee_ok = match mb_infer_tinstr_type(callee, env) {
            Some(RefTypeValType(_)) => true
            _ => false
          }
          mb_rewrite_critical_types_hold_expr(TExpr::new(args), env) &&
          mb_rewrite_critical_types_hold_instr(callee, env) &&
          mb_call_args_match_params(args, params, env) &&
          callee_ok
        }
        _ => false
      }
    TInstrKind::TLocalSet(local_idx, value) =>
      mb_rewrite_critical_types_hold_instr(value, env) &&
      mb_local_set_arg_matches(local_idx, value, env)
    TInstrKind::TLocalTee(local_idx, value) =>
      mb_rewrite_critical_types_hold_instr(value, env) &&
      mb_local_set_arg_matches(local_idx, value, env)
    TInstrKind::TGlobalSet(global_idx, value) =>
      mb_rewrite_critical_types_hold_instr(value, env) &&
      mb_global_set_arg_matches(global_idx, value, env)
    TInstrKind::TBlock(_, body) =>
      mb_rewrite_critical_types_hold_expr(body, env)
    TInstrKind::TLoop(_, body) => mb_rewrite_critical_types_hold_expr(body, env)
    TInstrKind::TTryTable(_, _, body) =>
      mb_rewrite_critical_types_hold_expr(body, env)
    TInstrKind::TIf(_, cond, then_, else_) => {
      let else_ok = match else_ {
        Some(other) => mb_rewrite_critical_types_hold_expr(other, env)
        None => true
      }
      mb_rewrite_critical_types_hold_instr(cond, env) &&
      mb_rewrite_critical_types_hold_expr(then_, env) &&
      else_ok
    }
    _ => {
      for child in eval_children(instr) {
        if !mb_rewrite_critical_types_hold_instr(child, env) {
          return false
        }
      }
      true
    }
  }
}

///|
fn mb_rewrite_critical_types_hold_items(
  items : Array[TInstr],
  env : Env,
) -> Bool {
  for item in items {
    if !mb_rewrite_critical_types_hold_instr(item, env) {
      return false
    }
  }
  true
}

///|
fn mb_rewrite_preserves_stack_sig(
  before : TInstr,
  after_items : Array[TInstr],
  env : Env,
) -> Bool {
  if !mb_rewrite_critical_types_hold_items(after_items, env) {
    return false
  }
  match (mb_stack_sig_instr(before, env), mb_stack_sig_list(after_items, env)) {
    (Some(before_sig), Some(after_sig)) =>
      mb_stack_sig_is_consistent(before_sig) &&
      mb_stack_sig_is_consistent(after_sig) &&
      before_sig.reachable == after_sig.reachable &&
      before_sig.required == after_sig.required &&
      before_sig.produced == after_sig.produced
    _ => false
  }
}

///|
fn compute_effects(expr : TInstr) -> MBEffects {
  let effects = MBEffects::new()
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      curr : TInstr,
    ) {
      mb_collect_shallow_effects(curr, effects)
      from_walk(self.walk_tinstruction_default((), curr))
    },
  )
  ignore(walker.walk_tinstruction((), expr))
  effects
}

///|
fn mb_compute_effects_cached(expr : TInstr, ctx : MBContext) -> MBEffects {
  if !ctx.effect_cache_enabled {
    return compute_effects(expr)
  }
  match ctx.effects_cache.get(mb_stable_instr_key(expr)) {
    Some(cached) => {
      ctx.compute_effects_cache_hits += 1
      cached
    }
    None => {
      let computed = compute_effects(expr)
      ctx.compute_effects_cache_misses += 1
      ctx.effects_cache[mb_stable_instr_key(expr)] = computed
      computed
    }
  }
}

///|
fn invalidates(a : MBEffects, b : MBEffects) -> Bool {
  a.invalidates(b)
}

///|
fn mb_collect_shallow_effects(instr : TInstr, effects : MBEffects) -> Unit {
  match instr.kind {
    TInstrKind::TLocalGet(idx) => effects.locals_read.add(idx)
    TInstrKind::TLocalSet(idx, _) => effects.locals_written.add(idx)
    TInstrKind::TLocalTee(idx, _) => {
      effects.locals_read.add(idx)
      effects.locals_written.add(idx)
    }
    TInstrKind::TGlobalGet(_) => effects.reads_globals = true
    TInstrKind::TGlobalSet(_, _) => effects.writes_globals = true
    TInstrKind::TLoad(_, _, _) => {
      effects.reads_memory = true
      effects.traps = true
    }
    TInstrKind::TStore(_, _, _, _) => {
      effects.writes_memory = true
      effects.traps = true
    }
    TInstrKind::TMemoryGrow(_, _) => effects.writes_memory = true
    TInstrKind::TMemorySize(_) => effects.reads_memory = true
    TInstrKind::TMemoryCopy(_, _, _, _, _) => {
      effects.reads_memory = true
      effects.writes_memory = true
      effects.traps = true
    }
    TInstrKind::TMemoryFill(_, _, _, _) => {
      effects.writes_memory = true
      effects.traps = true
    }
    TInstrKind::TMemoryInit(_, _, _, _, _) => {
      effects.reads_memory = true
      effects.writes_memory = true
      effects.traps = true
    }
    TInstrKind::TDataDrop(_) => effects.writes_memory = true
    TInstrKind::TTableSet(_, _, _)
    | TInstrKind::TTableGrow(_, _, _)
    | TInstrKind::TTableFill(_, _, _, _) => effects.writes_memory = true
    TInstrKind::TTableGet(_, _) | TInstrKind::TTableSize(_) =>
      effects.reads_memory = true
    TInstrKind::TTableCopy(_, _, _, _, _)
    | TInstrKind::TTableInit(_, _, _, _, _)
    | TInstrKind::TElemDrop(_) => {
      effects.reads_memory = true
      effects.writes_memory = true
    }
    TInstrKind::TCall(_, _)
    | TInstrKind::TCallIndirect(_, _, _, _)
    | TInstrKind::TCallRef(_, _, _) => effects.calls = true
    TInstrKind::TReturnCall(_, _)
    | TInstrKind::TReturnCallIndirect(_, _, _, _)
    | TInstrKind::TReturnCallRef(_, _, _) => {
      effects.calls = true
      effects.branches = true
    }
    TInstrKind::TBr(_, _)
    | TInstrKind::TBrIf(_, _, _)
    | TInstrKind::TBrTable(_, _, _, _)
    | TInstrKind::TBrOnNull(_, _, _)
    | TInstrKind::TBrOnNonNull(_, _, _)
    | TInstrKind::TBrOnCast(_, _, _, _, _, _)
    | TInstrKind::TBrOnCastFail(_, _, _, _, _, _)
    | TInstrKind::TReturn(_) => effects.branches = true
    TInstrKind::TThrow(_, _) => {
      effects.throws = true
      effects.branches = true
    }
    TInstrKind::TThrowRef(_) => {
      effects.throws = true
      effects.branches = true
    }
    TInstrKind::TUnreachable => effects.traps = true
    TInstrKind::TRefAsNonNull(_)
    | TInstrKind::TRefCast(_, _, _)
    | TInstrKind::TRefCastDescEq(_, _, _) => effects.traps = true
    TInstrKind::TStructGet(_, _, _)
    | TInstrKind::TStructGetS(_, _, _)
    | TInstrKind::TStructGetU(_, _, _) => {
      effects.reads_memory = true
      effects.traps = true
    }
    TInstrKind::TStructSet(_, _, _, _) => {
      effects.writes_memory = true
      effects.traps = true
    }
    TInstrKind::TArrayGet(_, _, _)
    | TInstrKind::TArrayGetS(_, _, _)
    | TInstrKind::TArrayGetU(_, _, _)
    | TInstrKind::TArrayLen(_) => {
      effects.reads_memory = true
      effects.traps = true
    }
    TInstrKind::TArraySet(_, _, _, _) | TInstrKind::TArrayFill(_, _, _, _, _) => {
      effects.reads_memory = true
      effects.writes_memory = true
      effects.traps = true
    }
    TInstrKind::TArrayCopy(_, _, _, _, _, _, _)
    | TInstrKind::TArrayInitData(_, _, _, _, _, _)
    | TInstrKind::TArrayInitElem(_, _, _, _, _, _) => {
      effects.reads_memory = true
      effects.writes_memory = true
      effects.traps = true
    }
    TInstrKind::TArrayNew(_, _, _)
    | TInstrKind::TArrayNewDefault(_, _)
    | TInstrKind::TArrayNewFixed(_, _)
    | TInstrKind::TArrayNewData(_, _, _, _)
    | TInstrKind::TArrayNewElem(_, _, _, _) => {
      effects.writes_memory = true
      effects.traps = true
    }
    TInstrKind::TStructNew(_, _) | TInstrKind::TStructNewDefault(_) =>
      effects.writes_memory = true
    TInstrKind::TAtomicFence
    | TInstrKind::TMemoryAtomicNotify(_, _, _)
    | TInstrKind::TMemoryAtomicWait32(_, _, _, _)
    | TInstrKind::TMemoryAtomicWait64(_, _, _, _)
    | TInstrKind::TAtomicRmw(_, _, _, _)
    | TInstrKind::TAtomicCmpxchg(_, _, _, _, _) => {
      effects.reads_memory = true
      effects.writes_memory = true
    }
    TInstrKind::TBinary(op, _, _) =>
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
    TInstrKind::TUnary(op, _) =>
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
priv struct MBEffectChecklistExpected {
  local_read : LocalIdx?
  local_write : LocalIdx?
  reads_memory : Bool
  writes_memory : Bool
  reads_globals : Bool
  writes_globals : Bool
  calls : Bool
  branches : Bool
  traps : Bool
  throws : Bool
}

///|
fn mb_effect_checklist_expected(
  local_read? : LocalIdx? = None,
  local_write? : LocalIdx? = None,
  reads_memory? : Bool = false,
  writes_memory? : Bool = false,
  reads_globals? : Bool = false,
  writes_globals? : Bool = false,
  calls? : Bool = false,
  branches? : Bool = false,
  traps? : Bool = false,
  throws? : Bool = false,
) -> MBEffectChecklistExpected {
  {
    local_read,
    local_write,
    reads_memory,
    writes_memory,
    reads_globals,
    writes_globals,
    calls,
    branches,
    traps,
    throws,
  }
}

///|
priv struct MBEffectChecklistEntry {
  name : String
  instr : TInstr
  expected : MBEffectChecklistExpected
}

///|
fn MBEffectChecklistEntry::new(
  name : String,
  instr : TInstr,
  expected : MBEffectChecklistExpected,
) -> MBEffectChecklistEntry {
  { name, instr, expected }
}

///|
fn mb_effect_checklist_entries() -> Array[MBEffectChecklistEntry] {
  let i0 = TInstr::i32_const(I32(0))
  let i1 = TInstr::i32_const(I32(1))
  let ref_any = TInstr::ref_null(HeapType::abs(AbsHeapType::any()))
  let ref_func = TInstr::ref_null(HeapType::abs(AbsHeapType::func()))
  let ref_exn = TInstr::ref_null(HeapType::abs(AbsHeapType::exn()))
  [
    MBEffectChecklistEntry::new(
      "local_get",
      TInstr::local_get(LocalIdx::new(2)),
      mb_effect_checklist_expected(local_read=Some(LocalIdx::new(2))),
    ),
    MBEffectChecklistEntry::new(
      "local_set",
      TInstr::local_set(LocalIdx::new(3), i1),
      mb_effect_checklist_expected(local_write=Some(LocalIdx::new(3))),
    ),
    MBEffectChecklistEntry::new(
      "local_tee",
      TInstr::local_tee(LocalIdx::new(4), i1),
      mb_effect_checklist_expected(
        local_read=Some(LocalIdx::new(4)),
        local_write=Some(LocalIdx::new(4)),
      ),
    ),
    MBEffectChecklistEntry::new(
      "global_get",
      TInstr::global_get(GlobalIdx::new(0)),
      mb_effect_checklist_expected(reads_globals=true),
    ),
    MBEffectChecklistEntry::new(
      "global_set",
      TInstr::global_set(GlobalIdx::new(0), i0),
      mb_effect_checklist_expected(writes_globals=true),
    ),
    MBEffectChecklistEntry::new(
      "load",
      TInstr::load(LoadOp::i32_load(), MemArg::new(0, None, 0), i0),
      mb_effect_checklist_expected(reads_memory=true, traps=true),
    ),
    MBEffectChecklistEntry::new(
      "store",
      TInstr::store(StoreOp::i32_store(), MemArg::new(0, None, 0), i0, i1),
      mb_effect_checklist_expected(writes_memory=true, traps=true),
    ),
    MBEffectChecklistEntry::new(
      "memory_grow",
      TInstr::memory_grow(MemIdx::new(0), i1),
      mb_effect_checklist_expected(writes_memory=true),
    ),
    MBEffectChecklistEntry::new(
      "memory_size",
      TInstr::memory_size(MemIdx::new(0)),
      mb_effect_checklist_expected(reads_memory=true),
    ),
    MBEffectChecklistEntry::new(
      "memory_copy",
      TInstr::memory_copy(MemIdx::new(0), MemIdx::new(0), i0, i1, i1),
      mb_effect_checklist_expected(
        reads_memory=true,
        writes_memory=true,
        traps=true,
      ),
    ),
    MBEffectChecklistEntry::new(
      "memory_fill",
      TInstr::memory_fill(MemIdx::new(0), i0, i1, i1),
      mb_effect_checklist_expected(writes_memory=true, traps=true),
    ),
    MBEffectChecklistEntry::new(
      "memory_init",
      TInstr::memory_init(DataIdx::new(0), MemIdx::new(0), i0, i1, i1),
      mb_effect_checklist_expected(
        reads_memory=true,
        writes_memory=true,
        traps=true,
      ),
    ),
    MBEffectChecklistEntry::new(
      "data_drop",
      TInstr::data_drop(DataIdx::new(0)),
      mb_effect_checklist_expected(writes_memory=true),
    ),
    MBEffectChecklistEntry::new(
      "atomic_memory_family",
      TInstr::memory_atomic_wait32(
        MemArg::new(0, None, 0),
        i0,
        i0,
        TInstr::i64_const(I64(0L)),
      ),
      mb_effect_checklist_expected(reads_memory=true, writes_memory=true),
    ),
    MBEffectChecklistEntry::new(
      "table_write_family",
      TInstr::table_set(TableIdx::new(0), i0, ref_func),
      mb_effect_checklist_expected(writes_memory=true),
    ),
    MBEffectChecklistEntry::new(
      "table_read_family",
      TInstr::table_get(TableIdx::new(0), i0),
      mb_effect_checklist_expected(reads_memory=true),
    ),
    MBEffectChecklistEntry::new(
      "table_copy_init_drop_family",
      TInstr::table_copy(TableIdx::new(0), TableIdx::new(0), i0, i1, i1),
      mb_effect_checklist_expected(reads_memory=true, writes_memory=true),
    ),
    MBEffectChecklistEntry::new(
      "call_family",
      TInstr::call(FuncIdx::new(0), []),
      mb_effect_checklist_expected(calls=true),
    ),
    MBEffectChecklistEntry::new(
      "return_call_family",
      TInstr::return_call(FuncIdx::new(0), []),
      mb_effect_checklist_expected(calls=true, branches=true),
    ),
    MBEffectChecklistEntry::new(
      "branch_family",
      TInstr::br_if(LabelIdx::new(0), i1, []),
      mb_effect_checklist_expected(branches=true),
    ),
    MBEffectChecklistEntry::new(
      "throw",
      TInstr::throw_(TagIdx::new(0), []),
      mb_effect_checklist_expected(throws=true, branches=true),
    ),
    MBEffectChecklistEntry::new(
      "throw_ref",
      TInstr::throw_ref(ref_exn),
      mb_effect_checklist_expected(throws=true, branches=true),
    ),
    MBEffectChecklistEntry::new(
      "unreachable",
      TInstr::unreachable_(),
      mb_effect_checklist_expected(traps=true),
    ),
    MBEffectChecklistEntry::new(
      "ref_as_non_null_or_ref_cast",
      TInstr::ref_as_non_null(ref_any),
      mb_effect_checklist_expected(traps=true),
    ),
    MBEffectChecklistEntry::new(
      "ref_cast_desc_eq",
      TInstr::ref_cast_desc_eq(true, HeapType::abs(AbsHeapType::any()), ref_any),
      mb_effect_checklist_expected(traps=true),
    ),
    MBEffectChecklistEntry::new(
      "struct_get_family",
      TInstr::struct_get(TypeIdx::new(0), 0, ref_any),
      mb_effect_checklist_expected(reads_memory=true, traps=true),
    ),
    MBEffectChecklistEntry::new(
      "struct_set",
      TInstr::struct_set(TypeIdx::new(0), 0, ref_any, i1),
      mb_effect_checklist_expected(writes_memory=true, traps=true),
    ),
    MBEffectChecklistEntry::new(
      "array_get_family",
      TInstr::array_get(TypeIdx::new(0), ref_any, i0),
      mb_effect_checklist_expected(reads_memory=true, traps=true),
    ),
    MBEffectChecklistEntry::new(
      "array_len_family",
      TInstr::array_len(ref_any),
      mb_effect_checklist_expected(reads_memory=true, traps=true),
    ),
    MBEffectChecklistEntry::new(
      "array_set_fill_family",
      TInstr::array_set(TypeIdx::new(0), ref_any, i0, i1),
      mb_effect_checklist_expected(
        reads_memory=true,
        writes_memory=true,
        traps=true,
      ),
    ),
    MBEffectChecklistEntry::new(
      "array_copy_init_family",
      TInstr::array_copy(
        TypeIdx::new(0),
        TypeIdx::new(0),
        ref_any,
        i0,
        ref_any,
        i0,
        i1,
      ),
      mb_effect_checklist_expected(
        reads_memory=true,
        writes_memory=true,
        traps=true,
      ),
    ),
    MBEffectChecklistEntry::new(
      "array_new_family",
      TInstr::array_new(TypeIdx::new(0), i1, i1),
      mb_effect_checklist_expected(writes_memory=true, traps=true),
    ),
    MBEffectChecklistEntry::new(
      "struct_new_family",
      TInstr::struct_new(TypeIdx::new(0), []),
      mb_effect_checklist_expected(writes_memory=true),
    ),
    MBEffectChecklistEntry::new(
      "binary_divrem_trap_family",
      TInstr::binary(BinaryOp::i32_div_s(), i1, i0),
      mb_effect_checklist_expected(traps=true),
    ),
    MBEffectChecklistEntry::new(
      "unary_trunc_trap_family",
      TInstr::unary(UnaryOp::i32_trunc_f64s(), TInstr::f64_const(F64(1.5))),
      mb_effect_checklist_expected(traps=true),
    ),
  ]
}

///|
fn mb_effect_checklist_entry_matches(
  entry : MBEffectChecklistEntry,
  effects : MBEffects,
) -> Bool {
  let expected_read_count = match entry.expected.local_read {
    Some(_) => 1
    None => 0
  }
  let expected_write_count = match entry.expected.local_write {
    Some(_) => 1
    None => 0
  }
  let local_read_ok = match entry.expected.local_read {
    Some(idx) => effects.locals_read.contains(idx)
    None => effects.locals_read.length() == 0
  }
  let local_write_ok = match entry.expected.local_write {
    Some(idx) => effects.locals_written.contains(idx)
    None => effects.locals_written.length() == 0
  }
  local_read_ok &&
  local_write_ok &&
  effects.locals_read.length() == expected_read_count &&
  effects.locals_written.length() == expected_write_count &&
  effects.reads_memory == entry.expected.reads_memory &&
  effects.writes_memory == entry.expected.writes_memory &&
  effects.reads_globals == entry.expected.reads_globals &&
  effects.writes_globals == entry.expected.writes_globals &&
  effects.calls == entry.expected.calls &&
  effects.branches == entry.expected.branches &&
  effects.traps == entry.expected.traps &&
  effects.throws == entry.expected.throws
}

///|
priv struct MBContext {
  env : Env
  mut needs_refinalize : Bool
  branch_cache : BranchCache
  round_safety_cap_override : Int
  effect_cache_enabled : Bool
  effects_cache : Map[MBStableInstrKey, MBEffects]
  mut compute_effects_cache_hits : Int
  mut compute_effects_cache_misses : Int
  mut optimize_block_rounds : Int
  mut optimize_block_round_cap_hits : Int
  mut non_control_child_iteration_steps : Int
  non_control_child_array_materializations : Int
  mut optimize_block_round_buffer_swaps : Int
  optimize_block_round_rebuild_copies : Int
}

///|
fn MBContext::new(env : Env) -> MBContext {
  MBContext::new_with_round_safety_cap_and_effect_cache(env, 0, true)
}

///|
fn MBContext::new_with_round_safety_cap(
  env : Env,
  round_safety_cap_override : Int,
) -> MBContext {
  MBContext::new_with_round_safety_cap_and_effect_cache(
    env, round_safety_cap_override, true,
  )
}

///|
fn MBContext::new_with_round_safety_cap_and_effect_cache(
  env : Env,
  round_safety_cap_override : Int,
  effect_cache_enabled : Bool,
) -> MBContext {
  {
    env,
    needs_refinalize: false,
    branch_cache: BranchCache::new(),
    round_safety_cap_override,
    effect_cache_enabled,
    effects_cache: Map::new(),
    compute_effects_cache_hits: 0,
    compute_effects_cache_misses: 0,
    optimize_block_rounds: 0,
    optimize_block_round_cap_hits: 0,
    non_control_child_iteration_steps: 0,
    non_control_child_array_materializations: 0,
    optimize_block_round_buffer_swaps: 0,
    optimize_block_round_rebuild_copies: 0,
  }
}

///|
priv struct MBFunctionRunStats {
  changed : Bool
  needs_refinalize : Bool
  refinalize_invocations : Int
  compute_effects_cache_hits : Int
  compute_effects_cache_misses : Int
  optimize_block_rounds : Int
  optimize_block_round_cap_hits : Int
  non_control_child_iteration_steps : Int
  non_control_child_array_materializations : Int
  optimize_block_round_buffer_swaps : Int
  optimize_block_round_rebuild_copies : Int
}

///|
fn MBFunctionRunStats::new(
  changed : Bool,
  needs_refinalize : Bool,
  refinalize_invocations : Int,
  compute_effects_cache_hits : Int,
  compute_effects_cache_misses : Int,
  optimize_block_rounds : Int,
  optimize_block_round_cap_hits : Int,
  non_control_child_iteration_steps : Int,
  non_control_child_array_materializations : Int,
  optimize_block_round_buffer_swaps : Int,
  optimize_block_round_rebuild_copies : Int,
) -> MBFunctionRunStats {
  {
    changed,
    needs_refinalize,
    refinalize_invocations,
    compute_effects_cache_hits,
    compute_effects_cache_misses,
    optimize_block_rounds,
    optimize_block_round_cap_hits,
    non_control_child_iteration_steps,
    non_control_child_array_materializations,
    optimize_block_round_buffer_swaps,
    optimize_block_round_rebuild_copies,
  }
}

///|
priv enum ProblemResult {
  ProblemOk
  ProblemBlocked
}

///|
priv struct ProblemFinderState {
  mut blocked : String?
  mut non_dropped_br_if_values : Int
  mut dropped_br_if_values : Int
}

///|
fn ProblemFinderState::new() -> ProblemFinderState {
  { blocked: None, non_dropped_br_if_values: 0, dropped_br_if_values: 0 }
}

///|
fn mb_label_to_int(label : LabelIdx) -> Int {
  let LabelIdx(raw) = label
  raw.reinterpret_as_int()
}

///|
fn mb_label_matches_depth(label : LabelIdx, depth : Int) -> Bool {
  mb_label_to_int(label) == depth
}

///|
fn has_branch(expr : TInstr, name : LabelIdx) -> Bool {
  mb_has_branch_to_depth(expr, mb_label_to_int(name), BranchCache::new())
}

///|
fn mb_has_any_branch(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TBr(_, _)
    | TInstrKind::TBrIf(_, _, _)
    | TInstrKind::TBrTable(_, _, _, _)
    | TInstrKind::TBrOnNull(_, _, _)
    | TInstrKind::TBrOnNonNull(_, _, _)
    | TInstrKind::TBrOnCast(_, _, _, _, _, _)
    | TInstrKind::TBrOnCastFail(_, _, _, _, _, _)
    | TInstrKind::TReturn(_) => true
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) => mb_has_any_branch_in_expr(body)
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      if mb_has_any_branch(cond) || mb_has_any_branch_in_expr(then_body) {
        return true
      }
      match else_body {
        Some(else_) => mb_has_any_branch_in_expr(else_)
        None => false
      }
    }
    _ => {
      for child in eval_children(instr) {
        if mb_has_any_branch(child) {
          return true
        }
      }
      false
    }
  }
}

///|
fn mb_has_any_branch_in_expr(expr : TExpr) -> Bool {
  for instr in expr.instrs {
    if mb_has_any_branch(instr) {
      return true
    }
  }
  false
}

///|
fn mb_has_branch_to_depth(
  instr : TInstr,
  depth : Int,
  cache : BranchCache,
) -> Bool {
  let instr_id = mb_branch_cache_instr_id(cache, instr)
  let key = { instr_id, depth, generation: cache.generation }
  match cache.query_entries.get(key) {
    Some(v) => {
      cache.query_hits += 1
      v
    }
    None => {
      cache.query_misses += 1
      let v = mb_has_branch_to_depth_uncached(instr, depth, cache)
      cache.query_entries[key] = v
      v
    }
  }
}

///|
fn mb_has_branch_to_depth_uncached(
  instr : TInstr,
  depth : Int,
  cache : BranchCache,
) -> Bool {
  match instr.kind {
    TInstrKind::TBr(label, _) => mb_label_matches_depth(label, depth)
    TInstrKind::TBrIf(label, _, _) => mb_label_matches_depth(label, depth)
    TInstrKind::TBrTable(labels, default, _, _) => {
      if mb_label_matches_depth(default, depth) {
        return true
      }
      for label in labels {
        if mb_label_matches_depth(label, depth) {
          return true
        }
      }
      false
    }
    TInstrKind::TBrOnNull(label, _, _)
    | TInstrKind::TBrOnNonNull(label, _, _)
    | TInstrKind::TBrOnCast(label, _, _, _, _, _)
    | TInstrKind::TBrOnCastFail(label, _, _, _, _, _) =>
      mb_label_matches_depth(label, depth)
    TInstrKind::TBlock(_, body) | TInstrKind::TLoop(_, body) =>
      mb_has_branch_to_depth_in_expr(body, depth + 1, cache)
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      if mb_has_branch_to_depth(cond, depth, cache) {
        return true
      }
      if mb_has_branch_to_depth_in_expr(then_body, depth + 1, cache) {
        return true
      }
      match else_body {
        Some(other) => mb_has_branch_to_depth_in_expr(other, depth + 1, cache)
        None => false
      }
    }
    TInstrKind::TTryTable(_, catches, body) => {
      for catch_ in catches {
        if mb_catch_targets_depth(catch_, depth + 1) {
          return true
        }
      }
      mb_has_branch_to_depth_in_expr(body, depth + 1, cache)
    }
    _ => {
      for child in eval_children(instr) {
        if mb_has_branch_to_depth(child, depth, cache) {
          return true
        }
      }
      false
    }
  }
}

///|
fn mb_has_branch_to_depth_in_expr(
  expr : TExpr,
  depth : Int,
  cache : BranchCache,
) -> Bool {
  for instr in expr.instrs {
    if mb_has_branch_to_depth(instr, depth, cache) {
      return true
    }
  }
  false
}

///|
fn mb_catch_targets_depth(catch_ : Catch, depth : Int) -> Bool {
  match catch_ {
    Catch(_, label)
    | CatchRef(_, label)
    | CatchAll(label)
    | CatchAllRef(label) => mb_label_matches_depth(label, depth)
  }
}

///|
fn mb_single_result_of_blocktype(bt : BlockType, env : Env) -> ValType? {
  match env.expand_blocktype(bt) {
    Ok((_, [vt])) => Some(vt)
    _ => None
  }
}

///|
fn mb_unary_result_type(op : UnaryOp, operand_ty : ValType?) -> ValType? {
  match op {
    I32EqzOp
    | I32ClzOp
    | I32CtzOp
    | I32PopcntOp
    | I32WrapI64Op
    | I32TruncF32SOp
    | I32TruncF32UOp
    | I32TruncF64SOp
    | I32TruncF64UOp
    | I32ReinterpretF32Op
    | I32Extend8SOp
    | I32Extend16SOp
    | I32TruncSatF32SOp
    | I32TruncSatF32UOp
    | I32TruncSatF64SOp
    | I32TruncSatF64UOp
    | I64EqzOp
    | V128AnyTrueOp
    | I8x16AllTrueOp
    | I8x16BitmaskOp
    | I16x8AllTrueOp
    | I16x8BitmaskOp
    | I32x4AllTrueOp
    | I32x4BitmaskOp
    | I64x2AllTrueOp
    | I64x2BitmaskOp => Some(ValType::i32())
    I64ClzOp
    | I64CtzOp
    | I64PopcntOp
    | I64ExtendI32SOp
    | I64ExtendI32UOp
    | I64TruncF32SOp
    | I64TruncF32UOp
    | I64TruncF64SOp
    | I64TruncF64UOp
    | I64ReinterpretF64Op
    | I64Extend8SOp
    | I64Extend16SOp
    | I64Extend32SOp
    | I64TruncSatF32SOp
    | I64TruncSatF32UOp
    | I64TruncSatF64SOp
    | I64TruncSatF64UOp => Some(ValType::i64())
    F32AbsOp
    | F32NegOp
    | F32CeilOp
    | F32FloorOp
    | F32TruncOp
    | F32NearestOp
    | F32SqrtOp
    | F32ConvertI32SOp
    | F32ConvertI32UOp
    | F32ConvertI64SOp
    | F32ConvertI64UOp
    | F32DemoteF64Op
    | F32ReinterpretI32Op => Some(ValType::f32())
    F64AbsOp
    | F64NegOp
    | F64CeilOp
    | F64FloorOp
    | F64TruncOp
    | F64NearestOp
    | F64SqrtOp
    | F64ConvertI32SOp
    | F64ConvertI32UOp
    | F64ConvertI64SOp
    | F64ConvertI64UOp
    | F64PromoteF32Op
    | F64ReinterpretI64Op => Some(ValType::f64())
    _ => operand_ty
  }
}

///|
fn mb_binary_result_type(op : BinaryOp, lhs_ty : ValType?) -> ValType? {
  match op {
    I32EqOp
    | I32NeOp
    | I32LtSOp
    | I32LtUOp
    | I32GtSOp
    | I32GtUOp
    | I32LeSOp
    | I32LeUOp
    | I32GeSOp
    | I32GeUOp
    | I64EqOp
    | I64NeOp
    | I64LtSOp
    | I64LtUOp
    | I64GtSOp
    | I64GtUOp
    | I64LeSOp
    | I64LeUOp
    | I64GeSOp
    | I64GeUOp
    | F32EqOp
    | F32NeOp
    | F32LtOp
    | F32GtOp
    | F32LeOp
    | F32GeOp
    | F64EqOp
    | F64NeOp
    | F64LtOp
    | F64GtOp
    | F64LeOp
    | F64GeOp => Some(ValType::i32())
    I32AddOp
    | I32SubOp
    | I32MulOp
    | I32DivSOp
    | I32DivUOp
    | I32RemSOp
    | I32RemUOp
    | I32AndOp
    | I32OrOp
    | I32XorOp
    | I32ShlOp
    | I32ShrSOp
    | I32ShrUOp
    | I32RotlOp
    | I32RotrOp => Some(ValType::i32())
    I64AddOp
    | I64SubOp
    | I64MulOp
    | I64DivSOp
    | I64DivUOp
    | I64RemSOp
    | I64RemUOp
    | I64AndOp
    | I64OrOp
    | I64XorOp
    | I64ShlOp
    | I64ShrSOp
    | I64ShrUOp
    | I64RotlOp
    | I64RotrOp => Some(ValType::i64())
    F32AddOp
    | F32SubOp
    | F32MulOp
    | F32DivOp
    | F32MinOp
    | F32MaxOp
    | F32CopysignOp => Some(ValType::f32())
    F64AddOp
    | F64SubOp
    | F64MulOp
    | F64DivOp
    | F64MinOp
    | F64MaxOp
    | F64CopysignOp => Some(ValType::f64())
    _ => lhs_ty
  }
}

///|
fn mb_load_result_type(op : LoadOp) -> ValType {
  match op {
    I32LoadOp | I32Load8SOp | I32Load8UOp | I32Load16SOp | I32Load16UOp =>
      ValType::i32()
    I64LoadOp
    | I64Load8SOp
    | I64Load8UOp
    | I64Load16SOp
    | I64Load16UOp
    | I64Load32SOp
    | I64Load32UOp => ValType::i64()
    F32LoadOp => ValType::f32()
    F64LoadOp => ValType::f64()
    _ => ValType::v128()
  }
}

///|
fn mb_ref_func_type(fi : FuncIdx, env : Env) -> ValType {
  ignore(fi)
  ignore(env)
  ValType::ref_type(RefType::new(false, HeapType::abs(AbsHeapType::func())))
}

///|
fn mb_infer_texpr_type(texpr : TExpr, env : Env) -> ValType? {
  let { instrs, .. } = texpr
  if instrs.is_empty() {
    None
  } else {
    mb_infer_tinstr_type(instrs[instrs.length() - 1], env)
  }
}

///|
fn mb_infer_tinstr_type(instr : TInstr, env : Env) -> ValType? {
  match instr.kind {
    TInstrKind::TI32Const(_) => Some(ValType::i32())
    TInstrKind::TI64Const(_) => Some(ValType::i64())
    TInstrKind::TF32Const(_) => Some(ValType::f32())
    TInstrKind::TF64Const(_) => Some(ValType::f64())
    TInstrKind::TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
      Some(ValType::v128())
    TInstrKind::TRefNull(ht) => Some(ValType::ref_type(RefType::new(true, ht)))
    TInstrKind::TRefFunc(fi) => Some(mb_ref_func_type(fi, env))
    TInstrKind::TLocalGet(idx) => env.get_local_type(idx)
    TInstrKind::TGlobalGet(idx) =>
      match env.get_global_type(idx) {
        Some(GlobalType(vt, _)) => Some(vt)
        None => None
      }
    TInstrKind::TLocalTee(_, value) => mb_infer_tinstr_type(value, env)
    TInstrKind::TUnary(op, value) =>
      mb_unary_result_type(op, mb_infer_tinstr_type(value, env))
    TInstrKind::TBinary(op, lhs, _) =>
      mb_binary_result_type(op, mb_infer_tinstr_type(lhs, env))
    TInstrKind::TRefEq(_, _)
    | TInstrKind::TRefIsNull(_)
    | TInstrKind::TRefTest(_, _, _) => Some(ValType::i32())
    TInstrKind::TLoad(op, _, _) => Some(mb_load_result_type(op))
    TInstrKind::TMemorySize(_) | TInstrKind::TTableSize(_) =>
      Some(ValType::i32())
    TInstrKind::TRefAsNonNull(value) =>
      match mb_infer_tinstr_type(value, env) {
        Some(RefTypeValType(rt)) =>
          Some(ValType::ref_type(RefType::new(false, rt.get_heap_type())))
        _ => None
      }
    TInstrKind::TRefCast(nullable, ht, _) =>
      Some(ValType::ref_type(RefType::new(nullable, ht)))
    TInstrKind::TStructNew(type_idx, _)
    | TInstrKind::TStructNewDefault(type_idx)
    | TInstrKind::TArrayNew(type_idx, _, _)
    | TInstrKind::TArrayNewDefault(type_idx, _)
    | TInstrKind::TArrayNewFixed(type_idx, _)
    | TInstrKind::TArrayNewData(type_idx, _, _, _)
    | TInstrKind::TArrayNewElem(type_idx, _, _, _) =>
      Some(ValType::ref_type(RefType::new(false, HeapType::new(type_idx))))
    TInstrKind::TStructGet(type_idx, field_idx, _)
    | TInstrKind::TStructGetS(type_idx, field_idx, _)
    | TInstrKind::TStructGetU(type_idx, field_idx, _) =>
      match env.resolve_struct_fields(type_idx) {
        Ok(fields) =>
          match field_idx {
            U32(raw_idx) =>
              match fields.get(raw_idx.reinterpret_as_int()) {
                Some(field_ty) => Some(field_ty.unpack())
                None => None
              }
          }
        Err(_) => None
      }
    TInstrKind::TArrayGet(type_idx, _, _)
    | TInstrKind::TArrayGetS(type_idx, _, _)
    | TInstrKind::TArrayGetU(type_idx, _, _) =>
      match env.resolve_array_field(type_idx) {
        Ok(field_ty) => Some(field_ty.unpack())
        Err(_) => None
      }
    TInstrKind::TArrayLen(_) => Some(ValType::i32())
    TInstrKind::TExtractLane(op, _, _) =>
      match op {
        I8x16ExtractLaneSOp
        | I8x16ExtractLaneUOp
        | I16x8ExtractLaneSOp
        | I16x8ExtractLaneUOp
        | I32x4ExtractLaneOp => Some(ValType::i32())
        I64x2ExtractLaneOp => Some(ValType::i64())
        F32x4ExtractLaneOp => Some(ValType::f32())
        F64x2ExtractLaneOp => Some(ValType::f64())
      }
    TInstrKind::TI31GetS(_) | TInstrKind::TI31GetU(_) => Some(ValType::i32())
    TInstrKind::TRefI31(_) =>
      Some(
        ValType::ref_type(
          RefType::new(false, HeapType::abs(AbsHeapType::i31())),
        ),
      )
    TInstrKind::TAnyConvertExtern(_) => Some(ValType::anyref())
    TInstrKind::TExternConvertAny(_) => Some(ValType::externref())
    TInstrKind::TSelect(types, _, if_true, if_false) => {
      let from_decl = match types {
        Some(vts) if vts.length() == 1 => Some(vts[0])
        _ => None
      }
      let from_branches = match
        (
          mb_infer_tinstr_type(if_true, env),
          mb_infer_tinstr_type(if_false, env),
        ) {
        (Some(t), Some(f)) if t == f => Some(t)
        _ => None
      }
      match (from_branches, from_decl) {
        (Some(t), _) => Some(t)
        (_, Some(vt)) => Some(vt)
        _ => None
      }
    }
    TInstrKind::TCall(target, _) =>
      match env.get_functype_by_funcidx(target) {
        Some(FuncType(_, [r])) => Some(r)
        _ => None
      }
    TInstrKind::TCallIndirect(type_idx, _, _, _)
    | TInstrKind::TCallRef(type_idx, _, _) =>
      match env.resolve_functype(type_idx) {
        Some(FuncType(_, [r])) => Some(r)
        _ => None
      }
    TInstrKind::TBlock(bt, body)
    | TInstrKind::TLoop(bt, body)
    | TInstrKind::TTryTable(bt, _, body) =>
      match
        (mb_infer_texpr_type(body, env), mb_single_result_of_blocktype(bt, env)) {
        (Some(t), _) => Some(t)
        (_, Some(vt)) => Some(vt)
        _ => None
      }
    TInstrKind::TIf(bt, _, then_, else_) => {
      let from_bt = mb_single_result_of_blocktype(bt, env)
      let from_branches = match else_ {
        Some(else_expr) =>
          match
            (
              mb_infer_texpr_type(then_, env),
              mb_infer_texpr_type(else_expr, env),
            ) {
            (Some(t), Some(e)) if t == e => Some(t)
            _ => None
          }
        None => None
      }
      match (from_branches, from_bt) {
        (Some(t), _) => Some(t)
        (_, Some(vt)) => Some(vt)
        _ => None
      }
    }
    _ => None
  }
}

///|
fn mb_instr_is_concrete(instr : TInstr, env : Env) -> Bool {
  match mb_infer_tinstr_type(instr, env) {
    Some(_) => true
    None => false
  }
}

///|
fn mb_blocktype_is_concrete(bt : BlockType, env : Env) -> Bool {
  match mb_single_result_of_blocktype(bt, env) {
    Some(_) => true
    None => false
  }
}

///|
fn mb_is_unreachable_instr(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TUnreachable
    | TInstrKind::TBr(_, _)
    | TInstrKind::TBrTable(_, _, _, _)
    | TInstrKind::TReturn(_)
    | TInstrKind::TReturnCall(_, _)
    | TInstrKind::TReturnCallIndirect(_, _, _, _)
    | TInstrKind::TReturnCallRef(_, _, _)
    | TInstrKind::TThrow(_, _)
    | TInstrKind::TThrowRef(_) => true
    TInstrKind::TBlock(_, body) => mb_texpr_is_unreachable(body)
    TInstrKind::TLoop(_, body) => mb_texpr_is_unreachable(body)
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      if mb_is_unreachable_instr(cond) {
        return true
      }
      match else_body {
        Some(else_) =>
          mb_texpr_is_unreachable(then_body) && mb_texpr_is_unreachable(else_)
        None => false
      }
    }
    TInstrKind::TTryTable(_, _, body) => mb_texpr_is_unreachable(body)
    _ => false
  }
}

///|
fn mb_texpr_is_unreachable(expr : TExpr) -> Bool {
  for instr in expr.instrs {
    if mb_is_unreachable_instr(instr) {
      return true
    }
  }
  false
}

///|
fn has_dead_code(block : TInstr) -> Bool {
  match block.kind {
    TInstrKind::TBlock(_, body) | TInstrKind::TLoop(_, body) =>
      mb_has_dead_code_in_expr(body)
    _ => false
  }
}

///|
fn mb_has_dead_code_in_expr(body : TExpr) -> Bool {
  let instrs = body.instrs
  for i = 0; i < instrs.length(); i = i + 1 {
    if mb_is_unreachable_instr(instrs[i]) && i + 1 < instrs.length() {
      return true
    }
  }
  false
}

///|
fn mb_finalize_block(block : TInstr, env : Env) -> TInstr {
  match block.kind {
    TInstrKind::TBlock(bt, body) => {
      let next_bt = mb_finalize_block_type(bt, body, env)
      TInstr::block(next_bt, body)
    }
    TInstrKind::TLoop(bt, body) => {
      let next_bt = mb_finalize_block_type(bt, body, env)
      TInstr::loop_(next_bt, body)
    }
    TInstrKind::TTryTable(bt, catches, body) => {
      let next_bt = mb_finalize_block_type(bt, body, env)
      TInstr::try_table(next_bt, catches, body)
    }
    _ => block
  }
}

///|
fn mb_finalize_block_type(bt : BlockType, body : TExpr, env : Env) -> BlockType {
  match bt {
    VoidBlockType => BlockType::void_()
    ValTypeBlockType(orig_ty) => {
      // Explicit value block signatures are authoritative; inference is advisory only.
      ignore(mb_infer_texpr_type(body, env))
      BlockType::val_type(orig_ty)
    }
    TypeIdxBlockType(_) => bt
  }
}

///|
fn mb_refinalize_instr(instr : TInstr, env : Env) -> TInstr {
  match instr.kind {
    TInstrKind::TBlock(bt, body) => {
      let next_body = mb_refinalize_texpr(body, env)
      mb_finalize_block(TInstr::block(bt, next_body), env)
    }
    TInstrKind::TLoop(bt, body) => {
      let next_body = mb_refinalize_texpr(body, env)
      mb_finalize_block(TInstr::loop_(bt, next_body), env)
    }
    TInstrKind::TTryTable(bt, catches, body) => {
      let next_body = mb_refinalize_texpr(body, env)
      mb_finalize_block(TInstr::try_table(bt, catches, next_body), env)
    }
    TInstrKind::TIf(bt, cond, then_, else_) => {
      let next_cond = mb_refinalize_instr(cond, env)
      let next_then = mb_refinalize_texpr(then_, env)
      let next_else = match else_ {
        Some(e) => Some(mb_refinalize_texpr(e, env))
        None => None
      }
      let inferred_bt = match next_else {
        Some(e) =>
          match
            (mb_infer_texpr_type(next_then, env), mb_infer_texpr_type(e, env)) {
            (Some(t), Some(u)) if t == u => BlockType::val_type(t)
            _ => BlockType::void_()
          }
        None => BlockType::void_()
      }
      let next_bt = match bt {
        TypeIdxBlockType(_) => bt
        VoidBlockType => inferred_bt
        ValTypeBlockType(orig_ty) =>
          match inferred_bt {
            ValTypeBlockType(inferred_ty) =>
              if inferred_ty == orig_ty {
                BlockType::val_type(inferred_ty)
              } else {
                BlockType::val_type(orig_ty)
              }
            _ => BlockType::val_type(orig_ty)
          }
      }
      TInstr::if_(next_bt, next_cond, next_then, next_else)
    }
    _ => {
      let next_children = []
      for child in eval_children(instr) {
        next_children.push(mb_refinalize_instr(child, env))
      }
      if next_children.is_empty() {
        instr
      } else {
        mb_rebuild_non_control(instr, next_children)
      }
    }
  }
}

///|
fn mb_refinalize_texpr(expr : TExpr, env : Env) -> TExpr {
  let out : Array[TInstr] = []
  for instr in expr.instrs {
    out.push(mb_refinalize_instr(instr, env))
  }
  TExpr::new(out)
}

///|
fn mb_sequence(instrs : Array[TInstr]) -> TInstr {
  match instrs {
    [] => TInstr::nop()
    [single] => single
    _ => TInstr::block(BlockType::void_(), TExpr::new(instrs))
  }
}

///|
fn mb_drop_or_value(value : TInstr, env : Env) -> TInstr {
  if mb_instr_is_concrete(value, env) {
    TInstr::drop(value)
  } else {
    value
  }
}

///|
fn mb_can_extract_child_block(
  bt : BlockType,
  body : TExpr,
  env : Env,
  branch_cache : BranchCache,
) -> (Bool, Array[TInstr], TInstr) {
  let items = body.instrs
  if items.length() < 2 {
    return (false, [], TInstr::nop())
  }
  if mb_has_branch_to_depth_in_expr(body, 0, branch_cache) {
    return (false, [], TInstr::nop())
  }
  let back = items[items.length() - 1]
  if mb_is_unreachable_instr(back) {
    return (false, [], TInstr::nop())
  }
  let block_ty = mb_single_result_of_blocktype(bt, env)
  let back_ty = mb_infer_tinstr_type(back, env)
  match bt {
    TypeIdxBlockType(_) => return (false, [], TInstr::nop())
    _ => ()
  }
  if block_ty != back_ty {
    return (false, [], TInstr::nop())
  }
  let prefix = []
  for i = 0; i + 1 < items.length(); i = i + 1 {
    prefix.push(items[i])
  }
  (true, prefix, back)
}

///|
fn optimize_expression_restructure(
  parent_expr : TInstr,
  mod : Module,
  options : OptimizeOptions,
  branch_cache : BranchCache,
  ctx : MBContext,
) -> (TInstr, Bool) {
  match parent_expr.kind {
    TInstrKind::TIf(bt, cond, then_, else_) =>
      match cond.kind {
        TInstrKind::TBlock(cbt, cbody) => {
          let (ok, prefix, back) = mb_can_extract_child_block(
            cbt,
            cbody,
            ctx.env,
            branch_cache,
          )
          if !ok {
            return (parent_expr, false)
          }
          let moved_effects = MBEffects::new()
          for item in prefix {
            moved_effects.merge(mb_compute_effects_cached(item, ctx))
          }
          if moved_effects.has_side_effects() {
            ctx.needs_refinalize = true
          }
          let wrapped = []
          for item in prefix {
            wrapped.push(item)
          }
          wrapped.push(TInstr::if_(bt, back, then_, else_))
          let wrapper_bt = match mb_infer_tinstr_type(parent_expr, ctx.env) {
            Some(vt) => BlockType::val_type(vt)
            None => BlockType::void_()
          }
          return (TInstr::block(wrapper_bt, TExpr::new(wrapped)), true)
        }
        _ => (parent_expr, false)
      }
    TInstrKind::TThrow(_, args) => {
      for arg in args {
        if mb_compute_effects_cached(arg, ctx).has_side_effects() {
          return (parent_expr, false)
        }
      }
      mb_restructure_non_control(parent_expr, mod, options, branch_cache, ctx)
    }
    TInstrKind::TBlock(_, _)
    | TInstrKind::TLoop(_, _)
    | TInstrKind::TTryTable(_, _, _) => (parent_expr, false)
    _ =>
      mb_restructure_non_control(parent_expr, mod, options, branch_cache, ctx)
  }
}

///|
fn mb_restructure_non_control(
  parent_expr : TInstr,
  _mod : Module,
  _options : OptimizeOptions,
  branch_cache : BranchCache,
  ctx : MBContext,
) -> (TInstr, Bool) {
  let pulled : Array[TInstr] = []
  let rebuilt_children : Array[TInstr] = []
  let effects_before = MBEffects::new()
  let mut changed = false
  let mut saw_child = false
  for child in eval_children(parent_expr) {
    saw_child = true
    ctx.non_control_child_iteration_steps += 1
    let mut next_child = child
    match child.kind {
      TInstrKind::TBlock(bt, body) => {
        let (ok, prefix, back) = mb_can_extract_child_block(
          bt,
          body,
          ctx.env,
          branch_cache,
        )
        if ok {
          let moved_effects = MBEffects::new()
          let mut move_ok = true
          for item in prefix {
            moved_effects.merge(mb_compute_effects_cached(item, ctx))
            if mb_has_any_branch(item) {
              move_ok = false
            }
          }
          if move_ok &&
            !invalidates(moved_effects, effects_before) &&
            !invalidates(effects_before, moved_effects) {
            for item in prefix {
              pulled.push(item)
            }
            next_child = back
            changed = true
            ctx.needs_refinalize = true
          }
        }
      }
      _ => ()
    }
    rebuilt_children.push(next_child)
    effects_before.merge(mb_compute_effects_cached(next_child, ctx))
  }
  if !saw_child {
    return (parent_expr, false)
  }
  if !changed {
    return (parent_expr, false)
  }
  let rebuilt_parent = mb_rebuild_non_control(parent_expr, rebuilt_children)
  let wrapper_items = []
  for item in pulled {
    wrapper_items.push(item)
  }
  wrapper_items.push(rebuilt_parent)
  let wrapper_bt = match mb_infer_tinstr_type(rebuilt_parent, ctx.env) {
    Some(vt) => BlockType::val_type(vt)
    None => BlockType::void_()
  }
  (TInstr::block(wrapper_bt, TExpr::new(wrapper_items)), true)
}

///|
fn problem_finder(
  origin : LabelIdx,
  expr : TExpr,
  mod : Module,
  options : OptimizeOptions,
  ctx : MBContext,
) -> ProblemResult {
  ignore(mod)
  ignore(options)
  let st = ProblemFinderState::new()
  mb_problem_finder_walk_expr(origin, expr, 0, st, ctx)
  match st.blocked {
    Some(_) => ProblemBlocked
    None =>
      if st.non_dropped_br_if_values > st.dropped_br_if_values {
        ProblemBlocked
      } else {
        ProblemOk
      }
  }
}

///|
fn mb_problem_finder_walk(
  origin : LabelIdx,
  expr : TInstr,
  depth : Int,
  st : ProblemFinderState,
  ctx : MBContext,
) -> Unit {
  if st.blocked is Some(_) {
    return
  }
  let origin_depth = mb_label_to_int(origin) + depth
  match expr.kind {
    TInstrKind::TDrop(value) =>
      match value.kind {
        TInstrKind::TBrIf(label, _, values) =>
          if mb_label_matches_depth(label, origin_depth) && !values.is_empty() {
            st.dropped_br_if_values += 1
          }
        _ => {
          mb_problem_finder_walk(origin, value, depth, st, ctx)
          if st.blocked is Some(_) {
            return
          }
        }
      }
    TInstrKind::TBr(label, values) =>
      if mb_label_matches_depth(label, origin_depth) && !values.is_empty() {
        for value in values {
          if mb_compute_effects_cached(value, ctx).has_side_effects() {
            st.blocked = Some("side effects in br value")
            return
          }
        }
      }
    TInstrKind::TBrIf(label, cond, values) => {
      mb_problem_finder_walk(origin, cond, depth, st, ctx)
      if st.blocked is Some(_) {
        return
      }
      if mb_label_matches_depth(label, origin_depth) && !values.is_empty() {
        st.non_dropped_br_if_values += 1
        for value in values {
          if mb_compute_effects_cached(value, ctx).has_side_effects() {
            st.blocked = Some("side effects in br_if value")
            return
          }
        }
      }
      for value in values {
        mb_problem_finder_walk(origin, value, depth, st, ctx)
        if st.blocked is Some(_) {
          return
        }
      }
    }
    TInstrKind::TBrTable(labels, default, index, values) => {
      let mut targets_origin = mb_label_matches_depth(default, origin_depth)
      if !targets_origin {
        for label in labels {
          if mb_label_matches_depth(label, origin_depth) {
            targets_origin = true
            break
          }
        }
      }
      if targets_origin {
        st.blocked = Some("unsupported branch op targeting origin")
        return
      }
      mb_problem_finder_walk(origin, index, depth, st, ctx)
      for value in values {
        mb_problem_finder_walk(origin, value, depth, st, ctx)
      }
    }
    TInstrKind::TBrOnNull(label, ref_, values)
    | TInstrKind::TBrOnNonNull(label, ref_, values)
    | TInstrKind::TBrOnCast(label, _, _, _, ref_, values)
    | TInstrKind::TBrOnCastFail(label, _, _, _, ref_, values) => {
      if mb_label_matches_depth(label, origin_depth) {
        st.blocked = Some("unsupported branch op targeting origin")
        return
      }
      mb_problem_finder_walk(origin, ref_, depth, st, ctx)
      for value in values {
        mb_problem_finder_walk(origin, value, depth, st, ctx)
      }
    }
    TInstrKind::TTryTable(_, catches, body) => {
      for catch_ in catches {
        match catch_ {
          Catch(_, label)
          | CatchRef(_, label)
          | CatchAll(label)
          | CatchAllRef(label) =>
            if mb_label_matches_depth(label, origin_depth + 1) {
              match catch_ {
                CatchAllRef(_) => ()
                CatchRef(tag_idx, _) =>
                  match ctx.env.resolve_tag_functype(tag_idx) {
                    Some(FuncType(params, _)) if params.is_empty() => ()
                    _ => {
                      st.blocked = Some(
                        "catch_ref with paramful tag targets origin",
                      )
                      return
                    }
                  }
                _ => {
                  st.blocked = Some("unsupported catch targeting origin")
                  return
                }
              }
            }
        }
      }
      mb_problem_finder_walk_expr(origin, body, depth + 1, st, ctx)
    }
    TInstrKind::TBlock(_, body) | TInstrKind::TLoop(_, body) =>
      mb_problem_finder_walk_expr(origin, body, depth + 1, st, ctx)
    TInstrKind::TIf(_, cond, then_, else_) => {
      mb_problem_finder_walk(origin, cond, depth, st, ctx)
      if st.blocked is Some(_) {
        return
      }
      mb_problem_finder_walk_expr(origin, then_, depth + 1, st, ctx)
      if st.blocked is Some(_) {
        return
      }
      match else_ {
        Some(e) => mb_problem_finder_walk_expr(origin, e, depth + 1, st, ctx)
        None => ()
      }
    }
    _ =>
      for child in eval_children(expr) {
        mb_problem_finder_walk(origin, child, depth, st, ctx)
        if st.blocked is Some(_) {
          return
        }
      }
  }
}

///|
fn mb_problem_finder_walk_expr(
  origin : LabelIdx,
  expr : TExpr,
  depth : Int,
  st : ProblemFinderState,
  ctx : MBContext,
) -> Unit {
  for instr in expr.instrs {
    mb_problem_finder_walk(origin, instr, depth, st, ctx)
    if st.blocked is Some(_) {
      return
    }
  }
}

///|
fn break_value_dropper(
  origin : LabelIdx,
  expr : TInstr,
  mod : Module,
  options : OptimizeOptions,
  branch_cache : BranchCache,
  ctx : MBContext,
) -> TInstr {
  ignore(options)
  mb_break_value_dropper_walk(origin, expr, 0, mod, branch_cache, ctx)
}

///|
fn mb_break_value_dropper_walk(
  origin : LabelIdx,
  expr : TInstr,
  depth : Int,
  mod : Module,
  branch_cache : BranchCache,
  ctx : MBContext,
) -> TInstr {
  let origin_depth = mb_label_to_int(origin) + depth
  match expr.kind {
    TInstrKind::TBr(label, values) =>
      if mb_label_matches_depth(label, origin_depth) && !values.is_empty() {
        let prefix : Array[TInstr] = []
        for value in values {
          if mb_is_unreachable_instr(value) {
            return TInstr::unreachable_()
          }
          prefix.push(mb_drop_or_value(value, ctx.env))
        }
        prefix.push(TInstr::br(label, []))
        mb_sequence(prefix)
      } else {
        expr
      }
    TInstrKind::TBrIf(label, cond, values) => {
      let next_cond = mb_break_value_dropper_walk(
        origin, cond, depth, mod, branch_cache, ctx,
      )
      let next_values : Array[TInstr] = []
      for value in values {
        next_values.push(
          mb_break_value_dropper_walk(
            origin, value, depth, mod, branch_cache, ctx,
          ),
        )
      }
      if mb_label_matches_depth(label, origin_depth) && !next_values.is_empty() {
        let prefix : Array[TInstr] = []
        for value in next_values {
          if mb_is_unreachable_instr(value) {
            return TInstr::unreachable_()
          }
          prefix.push(mb_drop_or_value(value, ctx.env))
        }
        prefix.push(TInstr::br_if(label, next_cond, []))
        mb_sequence(prefix)
      } else {
        TInstr::br_if(label, next_cond, next_values)
      }
    }
    TInstrKind::TTryTable(bt, catches, body) => {
      let next_catches : Array[Catch] = []
      for catch_ in catches {
        let next = match catch_ {
          CatchRef(tag, label) if mb_label_matches_depth(
              label,
              origin_depth + 1,
            ) => Catch::new(tag, label)
          CatchAllRef(label) if mb_label_matches_depth(label, origin_depth + 1) =>
            Catch::all(label)
          _ => catch_
        }
        next_catches.push(next)
      }
      let next_body = mb_break_value_dropper_expr(
        origin,
        body,
        depth + 1,
        mod,
        branch_cache,
        ctx,
      )
      let rewritten = TInstr::try_table(bt, next_catches, next_body)
      let (optimized, _) = optimize_block(
        rewritten,
        mod,
        OptimizeOptions::new(),
        branch_cache,
        ctx,
      )
      optimized
    }
    TInstrKind::TDrop(value) => {
      let next_value = mb_break_value_dropper_walk(
        origin, value, depth, mod, branch_cache, ctx,
      )
      if mb_instr_is_concrete(next_value, ctx.env) {
        TInstr::drop(next_value)
      } else {
        next_value
      }
    }
    TInstrKind::TBlock(bt, body) => {
      let next_body = mb_break_value_dropper_expr(
        origin,
        body,
        depth + 1,
        mod,
        branch_cache,
        ctx,
      )
      let rewritten = TInstr::block(bt, next_body)
      let (optimized, _) = optimize_block(
        rewritten,
        mod,
        OptimizeOptions::new(),
        branch_cache,
        ctx,
      )
      optimized
    }
    TInstrKind::TLoop(bt, body) => {
      let next_body = mb_break_value_dropper_expr(
        origin,
        body,
        depth + 1,
        mod,
        branch_cache,
        ctx,
      )
      let rewritten = TInstr::loop_(bt, next_body)
      let (optimized, _) = optimize_block(
        rewritten,
        mod,
        OptimizeOptions::new(),
        branch_cache,
        ctx,
      )
      optimized
    }
    TInstrKind::TIf(bt, cond, then_, else_) => {
      let next_cond = mb_break_value_dropper_walk(
        origin, cond, depth, mod, branch_cache, ctx,
      )
      let next_then = mb_break_value_dropper_expr(
        origin,
        then_,
        depth + 1,
        mod,
        branch_cache,
        ctx,
      )
      let next_else = match else_ {
        Some(e) =>
          Some(
            mb_break_value_dropper_expr(
              origin,
              e,
              depth + 1,
              mod,
              branch_cache,
              ctx,
            ),
          )
        None => None
      }
      TInstr::if_(bt, next_cond, next_then, next_else)
    }
    _ => {
      let next_children = []
      for child in eval_children(expr) {
        next_children.push(
          mb_break_value_dropper_walk(
            origin, child, depth, mod, branch_cache, ctx,
          ),
        )
      }
      if next_children.is_empty() {
        expr
      } else {
        mb_rebuild_non_control(expr, next_children)
      }
    }
  }
}

///|
fn mb_break_value_dropper_expr(
  origin : LabelIdx,
  expr : TExpr,
  depth : Int,
  mod : Module,
  branch_cache : BranchCache,
  ctx : MBContext,
) -> TExpr {
  let out : Array[TInstr] = []
  for instr in expr.instrs {
    out.push(
      mb_break_value_dropper_walk(origin, instr, depth, mod, branch_cache, ctx),
    )
  }
  TExpr::new(out)
}

///|
fn optimize_dropped_block(
  drop_instr : TInstr,
  block_instr : TInstr,
  mod : Module,
  options : OptimizeOptions,
  branch_cache : BranchCache,
  ctx : MBContext,
) -> (TInstr, Bool) {
  ignore(options)
  match block_instr.kind {
    TInstrKind::TBlock(TypeIdxBlockType(_), _) => return (drop_instr, false)
    _ => ()
  }
  let mut next_body = match drop_instr.kind {
    TInstrKind::TDrop({ kind: TInstrKind::TBlock(_, body), .. }) => body
    _ => return (drop_instr, false)
  }
  match problem_finder(LabelIdx::new(0), next_body, mod, options, ctx) {
    ProblemBlocked => return (drop_instr, false)
    ProblemOk => ()
  }
  {
    let rewritten_items : Array[TInstr] = []
    for instr in next_body.instrs {
      rewritten_items.push(
        break_value_dropper(
          LabelIdx::new(0),
          instr,
          mod,
          options,
          branch_cache,
          ctx,
        ),
      )
    }
    next_body = TExpr::new(rewritten_items)
  }
  let next_items = next_body.instrs.copy()
  if !next_items.is_empty() {
    let last = next_items.pop().unwrap()
    next_items.push(mb_drop_or_value(last, ctx.env))
  }
  let rewritten = mb_finalize_block(
    TInstr::block(BlockType::void_(), TExpr::new(next_items)),
    ctx.env,
  )
  let (optimized, _) = optimize_block(
    rewritten, mod, options, branch_cache, ctx,
  )
  if mb_rewrite_preserves_stack_sig(drop_instr, [optimized], ctx.env) {
    (optimized, true)
  } else if mb_rewrite_preserves_stack_sig(drop_instr, [rewritten], ctx.env) {
    (rewritten, true)
  } else {
    (drop_instr, false)
  }
}

///|
fn mb_prepare_moved_item(item : TInstr, has_after : Bool, env : Env) -> TInstr {
  if has_after && mb_instr_is_concrete(item, env) {
    TInstr::drop(item)
  } else {
    item
  }
}

///|
fn mb_optimize_block_round_safety_cap(item_count : Int, ctx : MBContext) -> Int {
  if ctx.round_safety_cap_override > 0 {
    ctx.round_safety_cap_override
  } else {
    mb_max_int(64, item_count * 8 + 32)
  }
}

///|
fn optimize_block(
  block : TInstr,
  mod : Module,
  options : OptimizeOptions,
  branch_cache : BranchCache,
  ctx : MBContext,
) -> (TInstr, Bool) {
  match block.kind {
    TInstrKind::TBlock(bt, body) => {
      let mut curr_items = body.instrs.copy()
      let mut next_items : Array[TInstr] = []
      let mut any_change = false
      let round_safety_cap = mb_optimize_block_round_safety_cap(
        curr_items.length(),
        ctx,
      )
      let mut rounds = 0
      while true {
        rounds += 1
        ctx.optimize_block_rounds += 1
        next_items.clear()
        let mut round_change = false
        let n = curr_items.length()
        for i = 0; i < curr_items.length(); i = i + 1 {
          let item0 = curr_items[i]
          let (item1, nested_changed) = mb_optimize_instr(
            item0, mod, options, branch_cache, ctx,
          )
          if nested_changed {
            round_change = true
          }
          match item1.kind {
            TInstrKind::TDrop({ kind: TInstrKind::TBlock(_, _), .. }) => {
              let (rewritten, changed) = optimize_dropped_block(
                item1,
                match item1.kind {
                  TInstrKind::TDrop(inner) => inner
                  _ => item1
                },
                mod,
                options,
                branch_cache,
                ctx,
              )
              if changed {
                next_items.push(rewritten)
                round_change = true
                continue
              }
            }
            _ => ()
          }
          match item1.kind {
            TInstrKind::TBlock(child_bt, child_body) => {
              if has_dead_code(item1) {
                next_items.push(item1)
                continue
              }
              let child_items = child_body.instrs
              let mut split = child_items.length()
              let mut named = false
              for j = 0; j < child_items.length(); j = j + 1 {
                if has_branch(child_items[j], LabelIdx::new(0)) {
                  split = j
                  named = true
                  break
                }
              }
              if named && mb_blocktype_is_concrete(child_bt, ctx.env) {
                next_items.push(item1)
                continue
              }
              if split == 0 {
                next_items.push(item1)
                continue
              }
              let mut can_move = true
              for j = 0; j < split; j = j + 1 {
                if mb_has_any_branch(child_items[j]) {
                  can_move = false
                  break
                }
              }
              if !can_move {
                next_items.push(item1)
                continue
              }
              let mut split_item_has_parent_branch = false
              for j = split; j < child_items.length(); j = j + 1 {
                if mb_has_branch_to_depth(child_items[j], 1, branch_cache) {
                  split_item_has_parent_branch = true
                  break
                }
              }
              if split_item_has_parent_branch {
                next_items.push(item1)
                continue
              }
              let moved_items_keep : Array[TInstr] = []
              let moved_items_drop : Array[TInstr] = []
              let mut drop_changed = false
              for j = 0; j < split; j = j + 1 {
                let has_after = j + 1 < split ||
                  split < child_items.length() ||
                  i + 1 < n
                let item = child_items[j]
                let kept = item
                let dropped = mb_prepare_moved_item(item, has_after, ctx.env)
                if has_after && mb_instr_is_concrete(item, ctx.env) {
                  drop_changed = true
                }
                moved_items_keep.push(kept)
                moved_items_drop.push(dropped)
              }
              if split < child_items.length() {
                let rest : Array[TInstr] = []
                for j = split; j < child_items.length(); j = j + 1 {
                  rest.push(child_items[j])
                }
                let suffix = mb_finalize_block(
                  TInstr::block(child_bt, TExpr::new(rest)),
                  ctx.env,
                )
                moved_items_keep.push(suffix)
                moved_items_drop.push(suffix)
              }
              let moved_items = if !drop_changed {
                moved_items_keep
              } else if mb_rewrite_preserves_stack_sig(
                  item1,
                  moved_items_drop,
                  ctx.env,
                ) {
                moved_items_drop
              } else if mb_rewrite_preserves_stack_sig(
                  item1,
                  moved_items_keep,
                  ctx.env,
                ) {
                moved_items_keep
              } else {
                []
              }
              if moved_items.is_empty() && drop_changed {
                next_items.push(item1)
                continue
              }
              for moved in moved_items {
                next_items.push(moved)
              }
              round_change = true
              continue
            }
            TInstrKind::TLoop(
              loop_bt,
              {
                instrs: [{ kind: TInstrKind::TBlock(inner_bt, inner_body), .. }],
                ..,
              }
            ) => {
              if mb_has_dead_code_in_expr(inner_body) {
                next_items.push(item1)
                continue
              }
              let inner_items = inner_body.instrs
              if inner_items.is_empty() {
                next_items.push(item1)
                continue
              }
              let mut last_back_branch = -1
              for j = 0; j < inner_items.length(); j = j + 1 {
                if mb_has_branch_to_depth(inner_items[j], 1, branch_cache) {
                  last_back_branch = j
                }
              }
              let split = last_back_branch + 1
              if split >= inner_items.length() {
                next_items.push(item1)
                continue
              }
              if split < inner_items.length() &&
                mb_instr_is_concrete(
                  inner_items[inner_items.length() - 1],
                  ctx.env,
                ) {
                next_items.push(item1)
                continue
              }
              let mut can_move = true
              for j = split; j < inner_items.length(); j = j + 1 {
                if mb_has_branch_to_depth(inner_items[j], 0, branch_cache) ||
                  mb_has_branch_to_depth(inner_items[j], 1, branch_cache) ||
                  mb_has_any_branch(inner_items[j]) {
                  can_move = false
                  break
                }
              }
              if !can_move {
                next_items.push(item1)
                continue
              }
              let keep : Array[TInstr] = []
              for j = 0; j < split; j = j + 1 {
                keep.push(inner_items[j])
              }
              let updated_loop = TInstr::loop_(
                loop_bt,
                TExpr::new([
                  mb_finalize_block(
                    TInstr::block(inner_bt, TExpr::new(keep)),
                    ctx.env,
                  ),
                ]),
              )
              next_items.push(updated_loop)
              for j = split; j < inner_items.length(); j = j + 1 {
                let has_after = j + 1 < inner_items.length() || i + 1 < n
                next_items.push(
                  mb_prepare_moved_item(inner_items[j], has_after, ctx.env),
                )
              }
              round_change = true
              continue
            }
            _ => ()
          }
          let (restructured, restructured_changed) = optimize_expression_restructure(
            item1, mod, options, branch_cache, ctx,
          )
          if restructured_changed {
            next_items.push(restructured)
            round_change = true
          } else {
            next_items.push(item1)
          }
        }
        if !round_change {
          break
        }
        any_change = true
        mb_branch_cache_invalidate(branch_cache)
        let prev_items = curr_items
        curr_items = next_items
        next_items = prev_items
        ctx.optimize_block_round_buffer_swaps += 1
        if rounds >= round_safety_cap {
          ctx.optimize_block_round_cap_hits += 1
          break
        }
      }
      let finalized = mb_finalize_block(
        TInstr::block(bt, TExpr::new(curr_items)),
        ctx.env,
      )
      (finalized, any_change)
    }
    _ => (block, false)
  }
}

///|
fn mb_optimize_instr(
  instr : TInstr,
  mod : Module,
  options : OptimizeOptions,
  branch_cache : BranchCache,
  ctx : MBContext,
) -> (TInstr, Bool) {
  match instr.kind {
    TInstrKind::TBlock(_, _) =>
      optimize_block(instr, mod, options, branch_cache, ctx)
    TInstrKind::TLoop(bt, body) => {
      let (next_body, changed) = mb_optimize_texpr(
        body, mod, options, branch_cache, ctx,
      )
      (mb_finalize_block(TInstr::loop_(bt, next_body), ctx.env), changed)
    }
    TInstrKind::TTryTable(bt, catches, body) => {
      let (next_body, changed) = mb_optimize_texpr(
        body, mod, options, branch_cache, ctx,
      )
      (
        mb_finalize_block(TInstr::try_table(bt, catches, next_body), ctx.env),
        changed,
      )
    }
    TInstrKind::TIf(bt, cond, then_, else_) => {
      let (next_cond, changed_cond) = mb_optimize_instr(
        cond, mod, options, branch_cache, ctx,
      )
      let (next_then, changed_then) = mb_optimize_texpr(
        then_, mod, options, branch_cache, ctx,
      )
      let (next_else, changed_else) = match else_ {
        Some(e) => {
          let (next, changed) = mb_optimize_texpr(
            e, mod, options, branch_cache, ctx,
          )
          (Some(next), changed)
        }
        None => (None, false)
      }
      (
        TInstr::if_(bt, next_cond, next_then, next_else),
        changed_cond || changed_then || changed_else,
      )
    }
    _ => {
      let next_children = []
      let mut changed = false
      for child in eval_children(instr) {
        let (next_child, child_changed) = mb_optimize_instr(
          child, mod, options, branch_cache, ctx,
        )
        if child_changed {
          changed = true
        }
        next_children.push(next_child)
      }
      if next_children.is_empty() {
        (instr, false)
      } else if changed {
        (mb_rebuild_non_control(instr, next_children), true)
      } else {
        (instr, false)
      }
    }
  }
}

///|
fn mb_optimize_texpr(
  expr : TExpr,
  mod : Module,
  options : OptimizeOptions,
  branch_cache : BranchCache,
  ctx : MBContext,
) -> (TExpr, Bool) {
  let out : Array[TInstr] = []
  let mut changed = false
  for instr in expr.instrs {
    let (next, child_changed) = mb_optimize_instr(
      instr, mod, options, branch_cache, ctx,
    )
    if child_changed {
      changed = true
    }
    out.push(next)
  }
  (TExpr::new(out), changed)
}

///|
fn run_on_function(
  func : Func,
  mod : Module,
  options : OptimizeOptions,
) -> (Func, Bool) {
  let (next_func, changed, _) = mb_run_on_function_with_stats(
    func, mod, options,
  )
  (next_func, changed)
}

///|
fn mb_run_on_function_with_stats(
  func : Func,
  mod : Module,
  options : OptimizeOptions,
) -> (Func, Bool, MBFunctionRunStats) {
  mb_run_on_function_with_stats_with_overrides(func, mod, options, 0, true)
}

///|
fn mb_run_on_function_with_stats_with_round_safety_cap(
  func : Func,
  mod : Module,
  options : OptimizeOptions,
  round_safety_cap_override : Int,
) -> (Func, Bool, MBFunctionRunStats) {
  mb_run_on_function_with_stats_with_overrides(
    func, mod, options, round_safety_cap_override, true,
  )
}

///|
fn mb_run_on_function_with_stats_with_effect_cache(
  func : Func,
  mod : Module,
  options : OptimizeOptions,
  effect_cache_enabled : Bool,
) -> (Func, Bool, MBFunctionRunStats) {
  mb_run_on_function_with_stats_with_overrides(
    func, mod, options, 0, effect_cache_enabled,
  )
}

///|
fn mb_run_on_function_with_stats_with_overrides(
  func : Func,
  mod : Module,
  options : OptimizeOptions,
  round_safety_cap_override : Int,
  effect_cache_enabled : Bool,
) -> (Func, Bool, MBFunctionRunStats) {
  match func {
    TFunc(params, locals, body) => {
      let env = Env::new()
        .with_module(mod)
        .with_locals(FunctionLocals::new(params, locals).all_locals())
      let ctx = if effect_cache_enabled && round_safety_cap_override > 0 {
        MBContext::new_with_round_safety_cap(env, round_safety_cap_override)
      } else if effect_cache_enabled {
        MBContext::new(env)
      } else {
        MBContext::new_with_round_safety_cap_and_effect_cache(
          env, round_safety_cap_override, false,
        )
      }
      let mut refinalize_invocations = 0
      let root = TInstr::block(BlockType::void_(), body)
      let (next_root, changed) = optimize_block(
        root,
        mod,
        options,
        ctx.branch_cache,
        ctx,
      )
      let next_body = match next_root.kind {
        TInstrKind::TBlock(_, b) => b
        _ => body
      }
      let mut final_body = next_body
      let should_refinalize = changed || ctx.needs_refinalize
      if should_refinalize {
        refinalize_invocations += 1
        final_body = mb_refinalize_texpr(final_body, env)
      }
      if should_refinalize {
        (
          Func::t_func(params, locals, final_body),
          true,
          MBFunctionRunStats::new(
            changed,
            ctx.needs_refinalize,
            refinalize_invocations,
            ctx.compute_effects_cache_hits,
            ctx.compute_effects_cache_misses,
            ctx.optimize_block_rounds,
            ctx.optimize_block_round_cap_hits,
            ctx.non_control_child_iteration_steps,
            ctx.non_control_child_array_materializations,
            ctx.optimize_block_round_buffer_swaps,
            ctx.optimize_block_round_rebuild_copies,
          ),
        )
      } else {
        (
          func,
          false,
          MBFunctionRunStats::new(
            changed,
            ctx.needs_refinalize,
            refinalize_invocations,
            ctx.compute_effects_cache_hits,
            ctx.compute_effects_cache_misses,
            ctx.optimize_block_rounds,
            ctx.optimize_block_round_cap_hits,
            ctx.non_control_child_iteration_steps,
            ctx.non_control_child_array_materializations,
            ctx.optimize_block_round_buffer_swaps,
            ctx.optimize_block_round_rebuild_copies,
          ),
        )
      }
    }
    _ =>
      (
        func,
        false,
        MBFunctionRunStats::new(false, false, 0, 0, 0, 0, 0, 0, 0, 0, 0),
      )
  }
}

///|
fn mb_runtime_execution_policy_note() -> String {
  "MergeBlocks currently runs sequentially as an intentional divergence: ModuleTransformer::walk_opt_codesec_default uses ModuleTransformer::walk_opt_array, and walk_opt_array threads mutable traversal state across functions. This runner does not yet provide a safe function-parallel dispatch path for this pass."
}

///|
fn merge_blocks_ir_pass(
  mod : Module,
  options? : OptimizeOptions = OptimizeOptions::new(),
) -> ModuleTransformer[IRContext, String] {
  // Execution model note: this pass currently runs sequentially by design.
  // See mb_runtime_execution_policy_note() for the specific runner constraint.
  ModuleTransformer::new().on_func_evt(fn(_, ctx, func : Func) {
    let (next_func, changed) = run_on_function(func, mod, options)
    if changed {
      change(ctx, next_func)
    } else {
      unchanged()
    }
  })
}

///|
fn run_merge_blocks(
  mod : Module,
  options? : OptimizeOptions = OptimizeOptions::new(),
) -> Module {
  let pass = merge_blocks_ir_pass(mod, options~)
  match pass.walk_module(IRContext::new(), mod) {
    Ok((out, _)) => out
    _ => mod
  }
}

///|
fn mb_rebuild_non_control(instr : TInstr, children : Array[TInstr]) -> TInstr {
  match instr.kind {
    // Zero-operand instructions.
    TInstrKind::TI32Const(_)
    | TInstrKind::TI64Const(_)
    | TInstrKind::TF32Const(_)
    | TInstrKind::TF64Const(_)
    | TInstrKind::TRefNull(_)
    | TInstrKind::TRefFunc(_)
    | TInstrKind::TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | TInstrKind::TUnreachable
    | TInstrKind::TNop
    | TInstrKind::TLocalGet(_)
    | TInstrKind::TGlobalGet(_)
    | TInstrKind::TMemorySize(_)
    | TInstrKind::TAtomicFence
    | TInstrKind::TTableSize(_)
    | TInstrKind::TDataDrop(_)
    | TInstrKind::TElemDrop(_)
    | TInstrKind::TStructNewDefault(_) => instr

    // Unary operands.
    TInstrKind::TUnary(op, _) => TInstr::unary(op, children[0])
    TInstrKind::TDrop(_) => TInstr::drop(children[0])
    TInstrKind::TLocalSet(idx, _) => TInstr::local_set(idx, children[0])
    TInstrKind::TLocalTee(idx, _) => TInstr::local_tee(idx, children[0])
    TInstrKind::TGlobalSet(idx, _) => TInstr::global_set(idx, children[0])
    TInstrKind::TRefIsNull(_) => TInstr::ref_is_null(children[0])
    TInstrKind::TRefAsNonNull(_) => TInstr::ref_as_non_null(children[0])
    TInstrKind::TI31GetS(_) => TInstr::i31_get_s(children[0])
    TInstrKind::TI31GetU(_) => TInstr::i31_get_u(children[0])
    TInstrKind::TRefI31(_) => TInstr::ref_i31(children[0])
    TInstrKind::TArrayLen(_) => TInstr::array_len(children[0])
    TInstrKind::TAnyConvertExtern(_) => TInstr::any_convert_extern(children[0])
    TInstrKind::TExternConvertAny(_) => TInstr::extern_convert_any(children[0])
    TInstrKind::TThrowRef(_) => TInstr::throw_ref(children[0])
    TInstrKind::TMemoryGrow(idx, _) => TInstr::memory_grow(idx, children[0])
    TInstrKind::TTableGet(idx, _) => TInstr::table_get(idx, children[0])
    TInstrKind::TLoad(op, memarg, _) => TInstr::load(op, memarg, children[0])
    TInstrKind::TArrayNewDefault(type_idx, _) =>
      TInstr::array_new_default(type_idx, children[0])
    TInstrKind::TStructGet(type_idx, field_idx, _) =>
      TInstr::struct_get(type_idx, field_idx, children[0])
    TInstrKind::TStructGetS(type_idx, field_idx, _) =>
      TInstr::struct_get_s(type_idx, field_idx, children[0])
    TInstrKind::TStructGetU(type_idx, field_idx, _) =>
      TInstr::struct_get_u(type_idx, field_idx, children[0])
    TInstrKind::TI8x16Splat(_) => TInstr::i8x16_splat(children[0])
    TInstrKind::TI16x8Splat(_) => TInstr::i16x8_splat(children[0])
    TInstrKind::TI32x4Splat(_) => TInstr::i32x4_splat(children[0])
    TInstrKind::TI64x2Splat(_) => TInstr::i64x2_splat(children[0])
    TInstrKind::TF32x4Splat(_) => TInstr::f32x4_splat(children[0])
    TInstrKind::TF64x2Splat(_) => TInstr::f64x2_splat(children[0])
    TInstrKind::TExtractLane(op, lane, _) =>
      TInstr::extract_lane(op, lane, children[0])
    TInstrKind::TRefTest(nullable, ht, _) =>
      TInstr::ref_test(nullable, ht, children[0])
    TInstrKind::TRefCast(nullable, ht, _) =>
      TInstr::ref_cast(nullable, ht, children[0])
    TInstrKind::TRefGetDesc(_) => TInstr::ref_get_desc(children[0])
    TInstrKind::TRefTestDesc(nullable, ht, _) =>
      TInstr::ref_test_desc(nullable, ht, children[0])
    TInstrKind::TRefCastDescEq(nullable, ht, _) =>
      TInstr::ref_cast_desc_eq(nullable, ht, children[0])

    // Two operands.
    TInstrKind::TBinary(op, _, _) =>
      TInstr::binary(op, children[0], children[1])
    TInstrKind::TRefEq(_, _) => TInstr::ref_eq(children[0], children[1])
    TInstrKind::TStore(op, memarg, _, _) =>
      TInstr::store(op, memarg, children[0], children[1])
    TInstrKind::TMemoryAtomicNotify(memarg, _, _) =>
      TInstr::memory_atomic_notify(memarg, children[0], children[1])
    TInstrKind::TAtomicRmw(op, memarg, _, _) =>
      TInstr::atomic_rmw(op, memarg, children[0], children[1])
    TInstrKind::TTableSet(table_idx, _, _) =>
      TInstr::table_set(table_idx, children[0], children[1])
    TInstrKind::TTableGrow(table_idx, _, _) =>
      TInstr::table_grow(table_idx, children[0], children[1])
    TInstrKind::TStructSet(type_idx, field_idx, _, _) =>
      TInstr::struct_set(type_idx, field_idx, children[0], children[1])
    TInstrKind::TArrayNew(type_idx, _, _) =>
      TInstr::array_new(type_idx, children[0], children[1])
    TInstrKind::TArrayNewData(type_idx, data_idx, _, _) =>
      TInstr::array_new_data(type_idx, data_idx, children[0], children[1])
    TInstrKind::TArrayNewElem(type_idx, elem_idx, _, _) =>
      TInstr::array_new_elem(type_idx, elem_idx, children[0], children[1])
    TInstrKind::TArrayGet(type_idx, _, _) =>
      TInstr::array_get(type_idx, children[0], children[1])
    TInstrKind::TArrayGetS(type_idx, _, _) =>
      TInstr::array_get_s(type_idx, children[0], children[1])
    TInstrKind::TArrayGetU(type_idx, _, _) =>
      TInstr::array_get_u(type_idx, children[0], children[1])
    TInstrKind::TReplaceLane(op, lane, _, _) =>
      TInstr::replace_lane(op, lane, children[0], children[1])
    TInstrKind::TI8x16Swizzle(_, _) =>
      TInstr::i8x16_swizzle(children[0], children[1])
    TInstrKind::TI8x16RelaxedSwizzle(_, _) =>
      TInstr::i8x16_relaxed_swizzle(children[0], children[1])
    TInstrKind::TV128Shift(op, _, _) =>
      TInstr::v128_shift(op, children[0], children[1])
    TInstrKind::TV128LoadLane(op, memarg, lane, _, _) =>
      TInstr::v128_load_lane(op, memarg, lane, children[0], children[1])
    TInstrKind::TV128StoreLane(op, memarg, lane, _, _) =>
      TInstr::v128_store_lane(op, memarg, lane, children[0], children[1])

    // Three operands.
    TInstrKind::TMemoryFill(mem_idx, _, _, _) =>
      TInstr::memory_fill(mem_idx, children[0], children[1], children[2])
    TInstrKind::TMemoryCopy(dst, src, _, _, _) =>
      TInstr::memory_copy(dst, src, children[0], children[1], children[2])
    TInstrKind::TMemoryInit(data_idx, mem_idx, _, _, _) =>
      TInstr::memory_init(
        data_idx,
        mem_idx,
        children[0],
        children[1],
        children[2],
      )
    TInstrKind::TMemoryAtomicWait32(memarg, _, _, _) =>
      TInstr::memory_atomic_wait32(
        memarg,
        children[0],
        children[1],
        children[2],
      )
    TInstrKind::TMemoryAtomicWait64(memarg, _, _, _) =>
      TInstr::memory_atomic_wait64(
        memarg,
        children[0],
        children[1],
        children[2],
      )
    TInstrKind::TAtomicCmpxchg(op, memarg, _, _, _) =>
      TInstr::atomic_cmpxchg(op, memarg, children[0], children[1], children[2])
    TInstrKind::TTableFill(table_idx, _, _, _) =>
      TInstr::table_fill(table_idx, children[0], children[1], children[2])
    TInstrKind::TTableCopy(dst, src, _, _, _) =>
      TInstr::table_copy(dst, src, children[0], children[1], children[2])
    TInstrKind::TTableInit(elem_idx, table_idx, _, _, _) =>
      TInstr::table_init(
        elem_idx,
        table_idx,
        children[0],
        children[1],
        children[2],
      )
    TInstrKind::TSelect(types, _, _, _) =>
      TInstr::select(types, children[2], children[0], children[1])
    TInstrKind::TV128Ternary(op, _, _, _) =>
      TInstr::v128_ternary(op, children[0], children[1], children[2])

    // Variable-length operands.
    TInstrKind::TCall(func_idx, args) => {
      let rebuilt = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt.push(children[i])
      }
      TInstr::call(func_idx, rebuilt)
    }
    TInstrKind::TReturnCall(func_idx, args) => {
      let rebuilt = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt.push(children[i])
      }
      TInstr::return_call(func_idx, rebuilt)
    }
    TInstrKind::TThrow(tag_idx, args) => {
      let rebuilt = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt.push(children[i])
      }
      TInstr::throw_(tag_idx, rebuilt)
    }
    TInstrKind::TBr(label_idx, args) => {
      let rebuilt = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt.push(children[i])
      }
      TInstr::br(label_idx, rebuilt)
    }
    TInstrKind::TReturn(args) => {
      let rebuilt = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt.push(children[i])
      }
      TInstr::return_(rebuilt)
    }
    TInstrKind::TStructNew(type_idx, args) => {
      let rebuilt = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt.push(children[i])
      }
      TInstr::struct_new(type_idx, rebuilt)
    }
    TInstrKind::TArrayNewFixed(type_idx, args) => {
      let rebuilt = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt.push(children[i])
      }
      TInstr::array_new_fixed(type_idx, rebuilt)
    }
    TInstrKind::TCallIndirect(type_idx, table_idx, args, _) => {
      let rebuilt_args = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt_args.push(children[i])
      }
      TInstr::call_indirect(
        type_idx,
        table_idx,
        rebuilt_args,
        children[args.length()],
      )
    }
    TInstrKind::TReturnCallIndirect(type_idx, table_idx, args, _) => {
      let rebuilt_args = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt_args.push(children[i])
      }
      TInstr::return_call_indirect(
        type_idx,
        table_idx,
        rebuilt_args,
        children[args.length()],
      )
    }
    TInstrKind::TCallRef(type_idx, args, _) => {
      let rebuilt_args = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt_args.push(children[i])
      }
      TInstr::call_ref(type_idx, rebuilt_args, children[args.length()])
    }
    TInstrKind::TReturnCallRef(type_idx, args, _) => {
      let rebuilt_args = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt_args.push(children[i])
      }
      TInstr::return_call_ref(type_idx, rebuilt_args, children[args.length()])
    }
    TInstrKind::TBrIf(label_idx, _, values) => {
      let rebuilt_values = []
      for i = 0; i < values.length(); i = i + 1 {
        rebuilt_values.push(children[i])
      }
      TInstr::br_if(label_idx, children[values.length()], rebuilt_values)
    }
    TInstrKind::TBrTable(labels, default, _, values) => {
      let rebuilt_values = []
      for i = 0; i < values.length(); i = i + 1 {
        rebuilt_values.push(children[i])
      }
      TInstr::br_table(
        labels,
        default,
        children[values.length()],
        rebuilt_values,
      )
    }
    TInstrKind::TBrOnNull(label_idx, _, values) => {
      let rebuilt_values = []
      for i = 0; i < values.length(); i = i + 1 {
        rebuilt_values.push(children[i])
      }
      TInstr::br_on_null(label_idx, children[values.length()], rebuilt_values)
    }
    TInstrKind::TBrOnNonNull(label_idx, _, values) => {
      let rebuilt_values = []
      for i = 0; i < values.length(); i = i + 1 {
        rebuilt_values.push(children[i])
      }
      TInstr::br_on_non_null(
        label_idx,
        children[values.length()],
        rebuilt_values,
      )
    }
    TInstrKind::TBrOnCast(label_idx, castop, ht1, ht2, _, values) => {
      let rebuilt_values = []
      for i = 0; i < values.length(); i = i + 1 {
        rebuilt_values.push(children[i])
      }
      TInstr::br_on_cast(
        label_idx,
        castop.0,
        ht1,
        castop.1,
        ht2,
        children[values.length()],
        rebuilt_values,
      )
    }
    TInstrKind::TBrOnCastFail(label_idx, castop, ht1, ht2, _, values) => {
      let rebuilt_values = []
      for i = 0; i < values.length(); i = i + 1 {
        rebuilt_values.push(children[i])
      }
      TInstr::br_on_cast_fail(
        label_idx,
        castop.0,
        ht1,
        castop.1,
        ht2,
        children[values.length()],
        rebuilt_values,
      )
    }
    TInstrKind::TArraySet(type_idx, _, _, _) =>
      TInstr::array_set(type_idx, children[0], children[1], children[2])
    TInstrKind::TArrayFill(type_idx, _, _, _, _) =>
      TInstr::array_fill(
        type_idx,
        children[0],
        children[1],
        children[2],
        children[3],
      )
    TInstrKind::TArrayCopy(dst_type, src_type, _, _, _, _, _) =>
      TInstr::array_copy(
        dst_type,
        src_type,
        children[0],
        children[1],
        children[2],
        children[3],
        children[4],
      )
    TInstrKind::TArrayInitData(type_idx, data_idx, _, _, _, _) =>
      TInstr::array_init_data(
        type_idx,
        data_idx,
        children[0],
        children[1],
        children[2],
        children[3],
      )
    TInstrKind::TArrayInitElem(type_idx, elem_idx, _, _, _, _) =>
      TInstr::array_init_elem(
        type_idx,
        elem_idx,
        children[0],
        children[1],
        children[2],
        children[3],
      )
    TInstrKind::TI8x16Shuffle(
      l0,
      l1,
      l2,
      l3,
      l4,
      l5,
      l6,
      l7,
      l8,
      l9,
      l10,
      l11,
      l12,
      l13,
      l14,
      l15,
      _,
      _
    ) =>
      TInstr::i8x16_shuffle(
        l0,
        l1,
        l2,
        l3,
        l4,
        l5,
        l6,
        l7,
        l8,
        l9,
        l10,
        l11,
        l12,
        l13,
        l14,
        l15,
        children[0],
        children[1],
      )

    // Control-flow structures are rebuilt in dedicated handlers.
    TInstrKind::TBlock(_, _)
    | TInstrKind::TLoop(_, _)
    | TInstrKind::TIf(_, _, _, _)
    | TInstrKind::TTryTable(_, _, _) => instr
  }
}

///|
fn mb_make_test_module_with_body(
  locals : Locals,
  body : TExpr,
  results? : Array[ValType] = [],
) -> Module {
  Module::new()
  .with_type_sec(
    TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], results)))]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  .with_code_sec(CodeSec::new([Func::t_func([], locals, body)]))
}

///|
fn mb_extract_only_tfunc(mod : Module) -> Func? {
  match mod.code_sec {
    Some(CodeSec([func])) => Some(func)
    _ => None
  }
}

///|
fn mb_run_on_body(body : TExpr, locals? : Array[ValType] = []) -> TExpr {
  let mod = mb_make_test_module_with_body(locals, body)
  let out = run_merge_blocks(mod)
  match mb_extract_only_tfunc(out) {
    Some(TFunc(_, _, new_body)) => new_body
    _ => body
  }
}

///|
fn mb_is_local_set_or_tee_chain(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TLocalSet(_, _) | TInstrKind::TLocalTee(_, _) => true
    _ => false
  }
}

///|
fn mb_local_chain_sig(instr : TInstr, env : Env) -> (Int, Int, ValType)? {
  match instr.kind {
    TInstrKind::TLocalGet(local_idx) =>
      match env.get_local_type(local_idx) {
        Some(local_ty) => Some((0, 1, local_ty))
        None => None
      }
    TInstrKind::TLocalSet(local_idx, value) =>
      match (env.get_local_type(local_idx), mb_local_chain_sig(value, env)) {
        (Some(local_ty), Some((required, produced, value_ty))) =>
          if local_ty == value_ty {
            let upstream_slack = mb_nonneg_int(1 - produced)
            Some(
              (
                required + upstream_slack,
                mb_nonneg_int(upstream_slack + produced - 1),
                local_ty,
              ),
            )
          } else {
            None
          }
        _ => None
      }
    TInstrKind::TLocalTee(local_idx, value) =>
      match (env.get_local_type(local_idx), mb_local_chain_sig(value, env)) {
        (Some(local_ty), Some((required, produced, value_ty))) =>
          if local_ty == value_ty {
            let upstream_slack = mb_nonneg_int(1 - produced)
            Some(
              (
                required + upstream_slack,
                mb_nonneg_int(upstream_slack + produced),
                local_ty,
              ),
            )
          } else {
            None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn mb_has_bad_single_arg_local_chain_call(body : TExpr, env : Env) -> Bool {
  let mut bad = false
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      instr : TInstr,
    ) {
      match instr.kind {
        TInstrKind::TCall(func_idx, [arg]) =>
          match env.get_functype_by_funcidx(func_idx) {
            Some(FuncType([param_ty], _)) =>
              if mb_is_local_set_or_tee_chain(arg) {
                match mb_local_chain_sig(arg, env) {
                  Some((_, produced, got_ty)) =>
                    if produced != 1 || got_ty != param_ty {
                      bad = true
                    }
                  _ => bad = true
                }
              }
            _ => ()
          }
        _ => ()
      }
      from_walk(self.walk_tinstruction_default((), instr))
    },
  )
  ignore(walker.walk_texpr((), body))
  bad
}

///|
fn mb_make_nested_unnamed_block_chain(depth : Int) -> TInstr {
  let mut out = TInstr::nop()
  let mut i = 0
  while i < depth {
    out = TInstr::block(BlockType::void_(), TExpr::new([out]))
    i = i + 1
  }
  out
}

///|
fn mb_count_blocks_in_texpr(expr : TExpr) -> Int {
  let mut count = 0
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      instr : TInstr,
    ) {
      match instr.kind {
        TInstrKind::TBlock(_, _) => count = count + 1
        _ => ()
      }
      from_walk(self.walk_tinstruction_default((), instr))
    },
  )
  ignore(walker.walk_texpr((), expr))
  count
}

///|
fn mb_make_effect_cache_stress_module(
  arg_count : Int,
  nesting_depth : Int,
) -> Module {
  let shared_prefix = mb_make_nested_unnamed_block_chain(nesting_depth)
  let repeated_arg = TInstr::block(
    BlockType::val_type(ValType::i32()),
    TExpr::new([shared_prefix, TInstr::i32_const(I32(1))]),
  )
  let args : Array[TInstr] = []
  let params : Array[ValType] = []
  for _ in 0..<arg_count {
    args.push(repeated_arg)
    params.push(ValType::i32())
  }
  let body = TExpr::new([TInstr::call(FuncIdx::new(1), args)])
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(SubType::comp_type(CompType::func([], []))),
      RecType::new(SubType::comp_type(CompType::func(params, []))),
    ]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
  .with_code_sec(
    CodeSec::new([
      Func::t_func([], Locals::empty(), body),
      Func::t_func(params, Locals::empty(), TExpr::new([])),
    ]),
  )
}

///|
fn mb_effect_cache_stress_elapsed_us(
  iterations : Int,
  effect_cache_enabled : Bool,
) -> UInt64 {
  let mod = mb_make_effect_cache_stress_module(24, 40)
  let func = match mod.code_sec {
    Some(CodeSec([entry, _])) => entry
    _ => abort("expected stress module function pair")
  }
  let start_us = trace_now_us()
  for _ in 0..<iterations {
    let _ = mb_run_on_function_with_stats_with_effect_cache(
      func,
      mod,
      OptimizeOptions::new(),
      effect_cache_enabled,
    )
  }
  trace_elapsed_us_since(start_us)
}

///|
fn mb_make_non_control_child_iteration_stress_module(arg_count : Int) -> Module {
  let args : Array[TInstr] = []
  let params : Array[ValType] = []
  for i = 0; i < arg_count; i = i + 1 {
    args.push(
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::drop(TInstr::i32_const(I32(i))),
          TInstr::i32_const(I32(i + 1)),
        ]),
      ),
    )
    params.push(ValType::i32())
  }
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(SubType::comp_type(CompType::func([], []))),
      RecType::new(SubType::comp_type(CompType::func(params, []))),
    ]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
  .with_code_sec(
    CodeSec::new([
      Func::t_func([], Locals::empty(), TExpr::new([TInstr::call(FuncIdx::new(1), args)])),
      Func::t_func(params, Locals::empty(), TExpr::new([])),
    ]),
  )
}

///|
fn mb_non_control_child_iteration_stress_totals(
  iterations : Int,
  arg_count : Int,
) -> (Int, Int) {
  let mod = mb_make_non_control_child_iteration_stress_module(arg_count)
  let func = match mod.code_sec {
    Some(CodeSec([entry, _])) => entry
    _ =>
      abort("expected non-control child iteration stress module function pair")
  }
  let mut total_steps = 0
  let mut total_materializations = 0
  for _ in 0..<iterations {
    let (_, _, stats) = mb_run_on_function_with_stats(
      func,
      mod,
      OptimizeOptions::new(),
    )
    total_steps += stats.non_control_child_iteration_steps
    total_materializations += stats.non_control_child_array_materializations
  }
  (total_steps, total_materializations)
}

///|
fn mb_optimize_block_buffer_stress_totals(
  iterations : Int,
  arg_count : Int,
) -> (Int, Int) {
  let mod = mb_make_non_control_child_iteration_stress_module(arg_count)
  let func = match mod.code_sec {
    Some(CodeSec([entry, _])) => entry
    _ => abort("expected optimize-block buffer stress module function pair")
  }
  let mut total_swaps = 0
  let mut total_rebuild_copies = 0
  for _ in 0..<iterations {
    let (_, _, stats) = mb_run_on_function_with_stats(
      func,
      mod,
      OptimizeOptions::new(),
    )
    total_swaps += stats.optimize_block_round_buffer_swaps
    total_rebuild_copies += stats.optimize_block_round_rebuild_copies
  }
  (total_swaps, total_rebuild_copies)
}

///|
test "merge blocks: stack sig pop_push carries child required depth" {
  let child = MBStackSig::new(1, 0, true)
  let out = mb_stack_sig_pop_push(child, 1, 1)
  assert_eq(out.required, 2)
  assert_eq(out.produced, 1)
  assert_true(out.reachable)
}

///|
test "merge blocks: stack sig sequence accumulates upstream requirement" {
  let a = MBStackSig::new(2, 1, true)
  let b = MBStackSig::new(2, 0, true)
  let out = mb_stack_sig_seq(a, b)
  assert_eq(out.required, 3)
  assert_eq(out.produced, 0)
  assert_true(out.reachable)
}

///|
test "merge blocks: stack sig never reports negative produced for reachable expression" {
  let child = MBStackSig::new(0, 0, true)
  let out = mb_stack_sig_pop_push(child, 1, 0)
  assert_eq(out.required, 1)
  assert_eq(out.produced, 0)
  assert_true(out.reachable)
}

///|
test "merge blocks: does not produce underflowing call arg local-set chain" {
  let locals = [ValType::i32(), ValType::i64(), ValType::i32(), ValType::i64()]
  let inner_body = TExpr::new([
    TInstr::drop(TInstr::local_get(LocalIdx::new(1))),
    TInstr::local_set(
      LocalIdx::new(3),
      TInstr::unary(
        UnaryOp::i64_extend_i32s(),
        TInstr::local_tee(LocalIdx::new(0), TInstr::local_get(LocalIdx::new(2))),
      ),
    ),
    TInstr::call(FuncIdx::new(1), [TInstr::local_get(LocalIdx::new(0))]),
    TInstr::i32_const(I32(0)),
    TInstr::local_tee(
      LocalIdx::new(0),
      TInstr::if_(
        BlockType::val_type(ValType::i32()),
        TInstr::local_set(LocalIdx::new(0), TInstr::local_get(LocalIdx::new(0))),
        TExpr::new([TInstr::local_get(LocalIdx::new(0))]),
        Some(
          TExpr::new([
            TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
            TInstr::br(LabelIdx::new(1), []),
          ]),
        ),
      ),
    ),
    TInstr::br_if(LabelIdx::new(0), TInstr::i32_const(I32(1)), []),
    TInstr::br(LabelIdx::new(1), []),
  ])
  let ambient_arg = TInstr::local_tee(
    LocalIdx::new(0),
    TInstr::local_set(LocalIdx::new(0), TInstr::local_get(LocalIdx::new(0))),
  )
  let body = TExpr::new([
    TInstr::drop(
      TInstr::block(
        BlockType::type_idx(TypeIdx::new(1)),
        TExpr::new([
          TInstr::block(
            BlockType::void_(),
            TExpr::new([TInstr::block(BlockType::void_(), inner_body)]),
          ),
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::local_get(LocalIdx::new(0)),
        ]),
      ),
    ),
    TInstr::call(FuncIdx::new(1), [ambient_arg]),
    TInstr::call(FuncIdx::new(1), [ambient_arg]),
    TInstr::call(FuncIdx::new(1), [ambient_arg]),
  ])
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([], []))),
        RecType::new(
          SubType::comp_type(
            CompType::func([], [
              ValType::i32(),
              ValType::i32(),
              ValType::i32(),
              ValType::i32(),
            ]),
          ),
        ),
        RecType::new(SubType::comp_type(CompType::func([ValType::i32()], []))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(2)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], locals, body),
        Func::t_func([ValType::i32()], Locals::empty(), TExpr::new([])),
      ]),
    )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_merge_blocks(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected merge_blocks to preserve dropped typed block stack validity: \{e}",
      )
  }
  match out.code_sec {
    Some(CodeSec([TFunc(next_params, next_locals, next_body), _])) => {
      let env = Env::new()
        .with_module(out)
        .with_locals(FunctionLocals::new(next_params, next_locals).all_locals())
      assert_false(mb_has_bad_single_arg_local_chain_call(next_body, env))
    }
    _ => fail("expected transformed regression function")
  }
}

///|
test "merge blocks: stack signature guard rejects call arg type mismatch" {
  let before = TInstr::call(FuncIdx::new(0), [TInstr::i32_const(I32(1))])
  let after_items = [TInstr::call(FuncIdx::new(0), [TInstr::i64_const(I64(2))])]
  let env = Env::new().with_module(
    Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([ValType::i32()], []))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)])),
  )
  assert_false(mb_rewrite_preserves_stack_sig(before, after_items, env))
}

///|
test "merge blocks: finalize preserves explicit value block type on inference conflict" {
  let if_instr = TInstr::if_(
    BlockType::val_type(ValType::i32()),
    TInstr::i32_const(I32(1)),
    TExpr::new([TInstr::i64_const(I64(1))]),
    Some(TExpr::new([TInstr::i64_const(I64(2))])),
  )
  let out = mb_refinalize_instr(if_instr, Env::new())
  match out.kind {
    TInstrKind::TIf(bt, _, _, _) =>
      match bt {
        ValTypeBlockType(out_ty) => assert_eq(out_ty, ValType::i32())
        _ => fail("expected refinalized if block type")
      }
    _ => fail("expected refinalized if instruction")
  }
}

///|
test "merge blocks: nested unnamed block fully merges" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::i32_const(I32(1)),
        TInstr::drop(TInstr::i32_const(I32(2))),
      ]),
    ),
  ])
  let out = mb_run_on_body(body)
  match out.instrs {
    [
      {
        kind: TInstrKind::TDrop({ kind: TInstrKind::TI32Const(I32(1)), .. }),
        ..,
      },
      {
        kind: TInstrKind::TDrop({ kind: TInstrKind::TI32Const(I32(2)), .. }),
        ..,
      },
    ] => ()
    _ => fail("expected child block to merge into parent")
  }
}

///|
test "merge blocks: converges through two-level nesting" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([TInstr::i32_const(I32(3))]),
        ),
      ]),
    ),
  ])
  let out = mb_run_on_body(body)
  match out.instrs {
    [{ kind: TInstrKind::TI32Const(I32(3)), .. }] => ()
    _ => fail("expected full convergence")
  }
}

///|
test "merge blocks: concrete moved to middle gets drop" {
  let body = TExpr::new([
    TInstr::block(BlockType::void_(), TExpr::new([TInstr::i32_const(I32(4))])),
    TInstr::nop(),
  ])
  let out = mb_run_on_body(body)
  match out.instrs {
    [
      {
        kind: TInstrKind::TDrop({ kind: TInstrKind::TI32Const(I32(4)), .. }),
        ..,
      },
      { kind: TInstrKind::TNop, .. },
    ] => ()
    _ => fail("expected concrete merged value to be dropped in middle")
  }
}

///|
test "merge blocks: named child only merges prefix before branch" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::i32_const(I32(7)),
        TInstr::br_if(LabelIdx::new(0), TInstr::i32_const(I32(1)), []),
        TInstr::i32_const(I32(9)),
      ]),
    ),
  ])
  let out = mb_run_on_body(body)
  match out.instrs {
    [
      first,
      {
        kind: TInstrKind::TBlock(
          VoidBlockType,
          {
            instrs: [
              { kind: TInstrKind::TBrIf(LabelIdx(target), _, []), .. },
              { kind: TInstrKind::TI32Const(I32(9)), .. },
            ],
            ..,
          }
        ),
        ..,
      },
    ] => {
      match first.kind {
        TInstrKind::TI32Const(I32(7))
        | TInstrKind::TDrop({ kind: TInstrKind::TI32Const(I32(7)), .. }) => ()
        _ => fail("expected merged prefix value")
      }
      assert_eq(target.reinterpret_as_int(), 0)
    }
    _ => fail("expected partial merge before first self-branch: \{out}")
  }
}

///|
test "merge blocks: named concrete child not merged" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::val_type(ValType::i32()),
      TExpr::new([
        TInstr::br(LabelIdx::new(0), [TInstr::i32_const(I32(1))]),
        TInstr::i32_const(I32(2)),
      ]),
    ),
  ])
  let out = mb_run_on_body(body)
  assert_eq(out, body)
}

///|
test "merge blocks: loop tail merge moves non-branching suffix outward" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::br_if(LabelIdx::new(1), TInstr::i32_const(I32(0)), []),
                TInstr::call(FuncIdx::new(0), []),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  ])
  let mod = mb_make_test_module_with_body([], body)
  let out = run_merge_blocks(mod)
  match mb_extract_only_tfunc(out) {
    Some(
      TFunc(
        [],
        _,
        {
          instrs: [
            {
              kind: TInstrKind::TBlock(
                _,
                {
                  instrs: [
                    {
                      kind: TInstrKind::TLoop(
                        _,
                        {
                          instrs: [
                            {
                              kind: TInstrKind::TBlock(
                                _,
                                {
                                  instrs: [
                                    { kind: TInstrKind::TBrIf(_, _, []), .. },
                                  ],
                                  ..,
                                }
                              ),
                              ..,
                            },
                          ],
                          ..,
                        }
                      ),
                      ..,
                    },
                    { kind: TInstrKind::TCall(_, []), .. },
                  ],
                  ..,
                }
              ),
              ..,
            },
          ],
          ..,
        }
      )
    ) => ()
    _ => fail("expected loop tail instruction moved outward")
  }
}

///|
test "merge blocks: loop tail blocked when last item branches to loop" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::i32_const(I32(1)),
                TInstr::br_if(LabelIdx::new(1), TInstr::i32_const(I32(0)), []),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  ])
  let out = mb_run_on_body(body)
  assert_eq(out, body)
}

///|
test "merge blocks: loop partial merge with concrete loop value is skipped" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::val_type(ValType::i32()),
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::br_if(LabelIdx::new(1), TInstr::i32_const(I32(0)), []),
                TInstr::i32_const(I32(11)),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  ])
  let out = mb_run_on_body(body)
  assert_eq(out, body)
}

///|
test "merge blocks: typed loop concrete tail without back-branch is not extracted" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::val_type(ValType::i32()),
      TExpr::new([
        TInstr::loop_(
          BlockType::val_type(ValType::i32()),
          TExpr::new([
            TInstr::block(
              BlockType::val_type(ValType::i32()),
              TExpr::new([TInstr::i32_const(I32(11))]),
            ),
          ]),
        ),
      ]),
    ),
  ])
  let mod = mb_make_test_module_with_body([], body, results=[ValType::i32()])
  assert_eq(validate_module(mod), Ok(()))
  let out = run_merge_blocks(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected concrete-tail loop gating to preserve validity without extraction: \{e}",
      )
  }
  match mb_extract_only_tfunc(out) {
    Some(
      TFunc(
        _,
        _,
        {
          instrs: [
            {
              kind: TInstrKind::TLoop(
                _,
                {
                  instrs: [
                    {
                      kind: TInstrKind::TBlock(
                        _,
                        {
                          instrs: [{ kind: TInstrKind::TI32Const(I32(11)), .. }],
                          ..,
                        }
                      ),
                      ..,
                    },
                  ],
                  ..,
                }
              ),
              ..,
            },
          ],
          ..,
        }
      )
    ) => ()
    _ => fail("expected transformed module body")
  }
}

///|
test "merge blocks: typed loop non-concrete tail is extracted" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::val_type(ValType::i32()),
      TExpr::new([
        TInstr::loop_(
          BlockType::val_type(ValType::i32()),
          TExpr::new([
            TInstr::block(
              BlockType::val_type(ValType::i32()),
              TExpr::new([
                TInstr::br_if(LabelIdx::new(1), TInstr::i32_const(I32(0)), [
                  TInstr::i32_const(I32(7)),
                ]),
                TInstr::drop(TInstr::i32_const(I32(1))),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  ])
  let mod = mb_make_test_module_with_body([], body, results=[ValType::i32()])
  assert_eq(validate_module(mod), Ok(()))
  let out = run_merge_blocks(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected non-concrete loop tail extraction to preserve typed validity: \{e}",
      )
  }
  match mb_extract_only_tfunc(out) {
    Some(
      TFunc(
        _,
        _,
        {
          instrs: [
            {
              kind: TInstrKind::TBlock(
                _,
                {
                  instrs: [
                    {
                      kind: TInstrKind::TLoop(
                        _,
                        {
                          instrs: [
                            {
                              kind: TInstrKind::TBlock(
                                _,
                                {
                                  instrs: [
                                    {
                                      kind: TInstrKind::TBrIf(
                                        LabelIdx(loop_target),
                                        _,
                                        [
                                          {
                                            kind: TInstrKind::TI32Const(I32(7)),
                                            ..,
                                          },
                                        ]
                                      ),
                                      ..,
                                    },
                                  ],
                                  ..,
                                }
                              ),
                              ..,
                            },
                          ],
                          ..,
                        }
                      ),
                      ..,
                    },
                    {
                      kind: TInstrKind::TDrop(
                        { kind: TInstrKind::TI32Const(I32(1)), .. }
                      ),
                      ..,
                    },
                  ],
                  ..,
                }
              ),
              ..,
            },
          ],
          ..,
        }
      )
    ) => assert_eq(loop_target.reinterpret_as_int(), 1)
    _ => fail("expected typed non-concrete loop tail moved outside loop")
  }
}

///|
test "merge blocks: dropped block pushes drop inward" {
  let body = TExpr::new([
    TInstr::drop(
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::call(FuncIdx::new(0), []),
          TInstr::i32_const(I32(1)),
        ]),
      ),
    ),
  ])
  let mod = mb_make_test_module_with_body([], body)
  let out = run_merge_blocks(mod)
  match mb_extract_only_tfunc(out) {
    Some(
      TFunc(
        [],
        _,
        {
          instrs: [
            { kind: TInstrKind::TCall(_, []), .. },
            {
              kind: TInstrKind::TDrop(
                { kind: TInstrKind::TI32Const(I32(1)), .. }
              ),
              ..,
            },
          ],
          ..,
        }
      )
    ) => ()
    _ => fail("expected drop moved inside block")
  }
}

///|
test "merge blocks: named dropped block removes break values when safe" {
  let body = TExpr::new([
    TInstr::drop(
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::br(LabelIdx::new(0), [TInstr::i32_const(I32(5))]),
          TInstr::i32_const(I32(7)),
        ]),
      ),
    ),
  ])
  let out = mb_run_on_body(body)
  let mut saw_value_br = false
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      instr : TInstr,
    ) {
      match instr.kind {
        TInstrKind::TBr(_, values) if !values.is_empty() => saw_value_br = true
        _ => ()
      }
      from_walk(self.walk_tinstruction_default((), instr))
    },
  )
  ignore(walker.walk_texpr((), out))
  assert_false(saw_value_br)
}

///|
test "merge blocks: problem finder blocks side-effecting br value" {
  let body = TExpr::new([
    TInstr::drop(
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::br(LabelIdx::new(0), [TInstr::call(FuncIdx::new(0), [])]),
          TInstr::i32_const(I32(0)),
        ]),
      ),
    ),
  ])
  let out = mb_run_on_body(body)
  assert_eq(out, body)
}

///|
test "merge blocks: problem finder blocks br_if mismatch" {
  let body = TExpr::new([
    TInstr::drop(
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::br_if(LabelIdx::new(0), TInstr::i32_const(I32(1)), [
            TInstr::i32_const(I32(3)),
          ]),
          TInstr::i32_const(I32(4)),
        ]),
      ),
    ),
  ])
  let out = mb_run_on_body(body)
  assert_eq(out, body)
}

///|
test "merge blocks: problem finder allows globally balanced dropped br_if values" {
  let body = TExpr::new([
    TInstr::drop(
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::drop(
            TInstr::br_if(LabelIdx::new(0), TInstr::i32_const(I32(1)), [
              TInstr::i32_const(I32(3)),
            ]),
          ),
          TInstr::br_if(LabelIdx::new(0), TInstr::i32_const(I32(1)), [
            TInstr::i32_const(I32(4)),
          ]),
          TInstr::i32_const(I32(5)),
        ]),
      ),
    ),
  ])
  let out = mb_run_on_body(body)
  assert_false(out == body)
  let mut saw_value_br_if = false
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      instr : TInstr,
    ) {
      match instr.kind {
        TInstrKind::TBrIf(_, _, values) if !values.is_empty() =>
          saw_value_br_if = true
        _ => ()
      }
      from_walk(self.walk_tinstruction_default((), instr))
    },
  )
  ignore(walker.walk_texpr((), out))
  assert_false(saw_value_br_if)
}

///|
test "merge blocks: nested dropped br_if keeps outer-label value branch" {
  let body = TExpr::new([
    TInstr::drop(
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::drop(
            TInstr::block(
              BlockType::val_type(ValType::i32()),
              TExpr::new([
                TInstr::br_if(LabelIdx::new(1), TInstr::i32_const(I32(1)), [
                  TInstr::i32_const(I32(3)),
                ]),
                TInstr::i32_const(I32(4)),
              ]),
            ),
          ),
          TInstr::i32_const(I32(5)),
        ]),
      ),
    ),
  ])
  let out = mb_run_on_body(body)
  let mut saw_outer_value_br_if = false
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      instr : TInstr,
    ) {
      match instr.kind {
        TInstrKind::TBrIf(label, _, values) =>
          if label == LabelIdx::new(1) && !values.is_empty() {
            saw_outer_value_br_if = true
          }
        _ => ()
      }
      from_walk(self.walk_tinstruction_default((), instr))
    },
  )
  ignore(walker.walk_texpr((), out))
  assert_true(saw_outer_value_br_if)
}

///|
test "merge blocks: problem finder blocks unsupported br_table target" {
  let body = TExpr::new([
    TInstr::drop(
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::br_table(
            [LabelIdx::new(0)],
            LabelIdx::new(0),
            TInstr::i32_const(I32(0)),
            [TInstr::i32_const(I32(1))],
          ),
          TInstr::i32_const(I32(9)),
        ]),
      ),
    ),
  ])
  let out = mb_run_on_body(body)
  assert_eq(out, body)
}

///|
test "merge blocks: try_table catch_all_ref targeting origin is allowed" {
  let body = TExpr::new([
    TInstr::drop(
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::try_table(
            BlockType::void_(),
            [Catch::all_ref(LabelIdx::new(1))],
            TExpr::new([TInstr::nop()]),
          ),
          TInstr::i32_const(I32(10)),
        ]),
      ),
    ),
  ])
  let out = mb_run_on_body(body)
  let mut saw_ref_catch = false
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      instr : TInstr,
    ) {
      match instr.kind {
        TInstrKind::TTryTable(_, catches, _) =>
          for catch_ in catches {
            match catch_ {
              CatchAllRef(_) | CatchRef(_, _) => saw_ref_catch = true
              _ => ()
            }
          }
        _ => ()
      }
      from_walk(self.walk_tinstruction_default((), instr))
    },
  )
  ignore(walker.walk_texpr((), out))
  assert_false(saw_ref_catch)
}

///|
test "merge blocks: try_table catch_ref without params targeting origin is allowed" {
  let tag_type = TagType::new(TypeIdx::new(0))
  let body = TExpr::new([
    TInstr::drop(
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::try_table(
            BlockType::void_(),
            [Catch::ref_(TagIdx::new(0), LabelIdx::new(1))],
            TExpr::new([TInstr::throw_(TagIdx::new(0), [])]),
          ),
          TInstr::i32_const(I32(6)),
        ]),
      ),
    ),
  ])
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([], []))),
        RecType::new(SubType::comp_type(CompType::func([], []))),
      ]),
    )
    .with_tag_sec(TagSec::new([tag_type]))
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_code_sec(CodeSec::new([Func::t_func([], Locals::empty(), body)]))
  let out = run_merge_blocks(mod)
  assert_false(out == mod)
  let mut saw_ref_catch = false
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      instr : TInstr,
    ) {
      match instr.kind {
        TInstrKind::TTryTable(_, catches, _) =>
          for catch_ in catches {
            match catch_ {
              CatchAllRef(_) | CatchRef(_, _) => saw_ref_catch = true
              _ => ()
            }
          }
        _ => ()
      }
      from_walk(self.walk_tinstruction_default((), instr))
    },
  )
  ignore(walker.walk_module((), out))
  assert_false(saw_ref_catch)
}

///|
test "merge blocks: try_table catch targeting origin blocks optimization" {
  let tag_type = TagType::new(TypeIdx::new(0))
  let body = TExpr::new([
    TInstr::drop(
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::try_table(
            BlockType::void_(),
            [Catch::new(TagIdx::new(0), LabelIdx::new(1))],
            TExpr::new([
              TInstr::throw_(TagIdx::new(0), [TInstr::i32_const(I32(8))]),
            ]),
          ),
          TInstr::i32_const(I32(1)),
        ]),
      ),
    ),
  ])
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([ValType::i32()], []))),
        RecType::new(SubType::comp_type(CompType::func([], []))),
      ]),
    )
    .with_tag_sec(TagSec::new([tag_type]))
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_code_sec(CodeSec::new([Func::t_func([], Locals::empty(), body)]))
  let out = run_merge_blocks(mod)
  assert_eq(out, mod)
}

///|
test "merge blocks: try_table catch_all targeting origin blocks optimization" {
  let tag_type = TagType::new(TypeIdx::new(0))
  let body = TExpr::new([
    TInstr::drop(
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::try_table(
            BlockType::void_(),
            [Catch::all(LabelIdx::new(1))],
            TExpr::new([TInstr::throw_(TagIdx::new(0), [])]),
          ),
          TInstr::i32_const(I32(2)),
        ]),
      ),
    ),
  ])
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([], []))),
        RecType::new(SubType::comp_type(CompType::func([], []))),
      ]),
    )
    .with_tag_sec(TagSec::new([tag_type]))
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_code_sec(CodeSec::new([Func::t_func([], Locals::empty(), body)]))
  let out = run_merge_blocks(mod)
  assert_eq(out, mod)
}

///|
test "merge blocks: try_table catch_ref with params blocks optimization" {
  let tag_type = TagType::new(TypeIdx::new(0))
  let body = TExpr::new([
    TInstr::drop(
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::try_table(
            BlockType::void_(),
            [Catch::ref_(TagIdx::new(0), LabelIdx::new(1))],
            TExpr::new([TInstr::nop()]),
          ),
          TInstr::i32_const(I32(1)),
        ]),
      ),
    ),
  ])
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([ValType::i32()], []))),
        RecType::new(SubType::comp_type(CompType::func([], []))),
      ]),
    )
    .with_tag_sec(TagSec::new([tag_type]))
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_code_sec(CodeSec::new([Func::t_func([], Locals::empty(), body)]))
  let out = run_merge_blocks(mod)
  assert_eq(out, mod)
}

///|
test "merge blocks: problem finder blocks nested dropped try_table catch_ref mismatch" {
  let tag_type = TagType::new(TypeIdx::new(0))
  let body = TExpr::new([
    TInstr::drop(
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::drop(
            TInstr::try_table(
              BlockType::void_(),
              [Catch::ref_(TagIdx::new(0), LabelIdx::new(1))],
              TExpr::new([
                TInstr::throw_(TagIdx::new(0), [TInstr::i32_const(I32(5))]),
              ]),
            ),
          ),
          TInstr::i32_const(I32(3)),
        ]),
      ),
    ),
  ])
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([ValType::i32()], []))),
        RecType::new(SubType::comp_type(CompType::func([], []))),
      ]),
    )
    .with_tag_sec(TagSec::new([tag_type]))
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_code_sec(CodeSec::new([Func::t_func([], Locals::empty(), body)]))
  let out = run_merge_blocks(mod)
  assert_eq(out, mod)
}

///|
test "merge blocks: restructure pulls operand block outward with effect checks" {
  let body = TExpr::new([
    TInstr::drop(
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::block(
          BlockType::val_type(ValType::i32()),
          TExpr::new([
            TInstr::drop(TInstr::i32_const(I32(1))),
            TInstr::i32_const(I32(2)),
          ]),
        ),
        TInstr::i32_const(I32(3)),
      ),
    ),
  ])
  let out = mb_run_on_body(body)
  let mut wrapped = false
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      instr : TInstr,
    ) {
      match instr.kind {
        TInstrKind::TBlock(_, { instrs: items, .. }) if items.length() >= 2 =>
          wrapped = true
        _ => ()
      }
      from_walk(self.walk_tinstruction_default((), instr))
    },
  )
  ignore(walker.walk_texpr((), out))
  assert_true(wrapped)
}

///|
test "merge blocks: function run performs at most one refinalize pass" {
  let body = TExpr::new([
    TInstr::binary(
      BinaryOp::i32_add(),
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::drop(TInstr::i32_const(I32(1))),
          TInstr::i32_const(I32(2)),
        ]),
      ),
      TInstr::i32_const(I32(3)),
    ),
  ])
  let mod = mb_make_test_module_with_body([], body)
  let func = match mb_extract_only_tfunc(mod) {
    Some(value) => value
    None => fail("expected test module to contain one typed function")
  }
  let (_, changed, stats) = mb_run_on_function_with_stats(
    func,
    mod,
    OptimizeOptions::new(),
  )
  assert_true(changed)
  assert_true(stats.changed)
  assert_true(stats.needs_refinalize)
  assert_eq(stats.refinalize_invocations, 1)
}

///|
test "merge blocks: deep nesting converges past legacy round budget without cap hits" {
  let body = TExpr::new([mb_make_nested_unnamed_block_chain(96)])
  let mod = mb_make_test_module_with_body([], body)
  let func = match mb_extract_only_tfunc(mod) {
    Some(value) => value
    None => fail("expected test module to contain one typed function")
  }
  let (next_func, changed, stats) = mb_run_on_function_with_stats(
    func,
    mod,
    OptimizeOptions::new(),
  )
  assert_true(changed)
  assert_true(stats.optimize_block_rounds > 20)
  assert_eq(stats.optimize_block_round_cap_hits, 0)
  match next_func {
    TFunc(_, _, next_body) => assert_eq(mb_count_blocks_in_texpr(next_body), 0)
    _ => fail("expected optimized test function")
  }
}

///|
test "merge blocks: safety-cap instrumentation reports forced cap hit" {
  let body = TExpr::new([mb_make_nested_unnamed_block_chain(96)])
  let mod = mb_make_test_module_with_body([], body)
  let func = match mb_extract_only_tfunc(mod) {
    Some(value) => value
    None => fail("expected test module to contain one typed function")
  }
  let (_, changed, stats) = mb_run_on_function_with_stats_with_round_safety_cap(
    func,
    mod,
    OptimizeOptions::new(),
    1,
  )
  assert_true(changed)
  assert_true(stats.optimize_block_round_cap_hits > 0)
}

///|
test "merge blocks: runtime parallel gap is documented as intentional sequential divergence" {
  let note = mb_runtime_execution_policy_note()
  assert_true(note.contains("intentional divergence"))
  assert_true(note.contains("sequential"))
  assert_true(note.contains("ModuleTransformer::walk_opt_array"))
}

///|
test "merge blocks: effect cache records repeated stable-identity hits per function" {
  let mod = mb_make_effect_cache_stress_module(12, 32)
  let func = match mod.code_sec {
    Some(CodeSec([entry, _])) => entry
    _ => fail("expected stress module function pair")
  }
  let (_, changed_uncached, uncached_stats) = mb_run_on_function_with_stats_with_effect_cache(
    func,
    mod,
    OptimizeOptions::new(),
    false,
  )
  let (_, changed_cached, cached_stats) = mb_run_on_function_with_stats_with_effect_cache(
    func,
    mod,
    OptimizeOptions::new(),
    true,
  )
  assert_true(changed_uncached)
  assert_true(changed_cached)
  assert_eq(uncached_stats.compute_effects_cache_hits, 0)
  assert_eq(uncached_stats.compute_effects_cache_misses, 0)
  assert_true(cached_stats.compute_effects_cache_hits > 0)
  assert_true(cached_stats.compute_effects_cache_misses > 0)
}

///|
test "merge blocks: effect cache stress fixture improves wall time by at least 15 percent" {
  let uncached_us = mb_effect_cache_stress_elapsed_us(64, false)
  let cached_us = mb_effect_cache_stress_elapsed_us(64, true)
  assert_true(uncached_us > 0UL)
  assert_true(cached_us > 0UL)
  let improvement_bp = if uncached_us > cached_us {
    (uncached_us - cached_us) * 10000UL / uncached_us
  } else {
    0UL
  }
  assert_true(
    improvement_bp >= 1500UL,
    msg="expected >=15% wall-time improvement, uncached=\{uncached_us}us cached=\{cached_us}us improvement_bp=\{improvement_bp}",
  )
}

///|
test "merge blocks: non-control child iteration avoids eval-children array materialization" {
  let mod = mb_make_non_control_child_iteration_stress_module(12)
  let func = match mod.code_sec {
    Some(CodeSec([entry, _])) => entry
    _ =>
      fail("expected non-control child iteration stress module function pair")
  }
  let (_, changed, stats) = mb_run_on_function_with_stats(
    func,
    mod,
    OptimizeOptions::new(),
  )
  assert_true(changed)
  assert_true(stats.non_control_child_iteration_steps >= 12)
  assert_eq(stats.non_control_child_array_materializations, 0)
}

///|
test "merge blocks: non-control child iteration stress fixture keeps representative zero-materialization target" {
  let (iteration_steps, materializations) = mb_non_control_child_iteration_stress_totals(
    96, 16,
  )
  assert_true(iteration_steps > 0)
  assert_eq(materializations, 0)
}

///|
test "merge blocks: optimize block staged buffers swap rounds without rebuild-copy replay" {
  let mod = mb_make_non_control_child_iteration_stress_module(12)
  let func = match mod.code_sec {
    Some(CodeSec([entry, _])) => entry
    _ => fail("expected optimize-block buffer stress module function pair")
  }
  let (_, changed, stats) = mb_run_on_function_with_stats(
    func,
    mod,
    OptimizeOptions::new(),
  )
  assert_true(changed)
  assert_true(stats.optimize_block_round_buffer_swaps > 0)
  assert_eq(stats.optimize_block_round_rebuild_copies, 0)
}

///|
test "merge blocks: optimize block staged-buffer stress fixture keeps representative zero-copy target" {
  let (buffer_swaps, rebuild_copies) = mb_optimize_block_buffer_stress_totals(
    96, 16,
  )
  assert_true(buffer_swaps > 0)
  assert_eq(rebuild_copies, 0)
}

///|
test "merge blocks: branch cache uses id-based keys so structural clones do not alias" {
  let cache = BranchCache::new()
  let probe_a = TInstr::br(LabelIdx::new(0), [])
  let probe_b = TInstr::br(LabelIdx::new(0), [])
  ignore(mb_has_branch_to_depth(probe_a, 0, cache))
  ignore(mb_has_branch_to_depth(probe_b, 0, cache))
  assert_eq(cache.instr_id_hits, 0)
  assert_eq(cache.instr_id_misses, 2)
  assert_eq(cache.query_misses, 2)
  assert_eq(cache.query_hits, 0)
}

///|
test "merge blocks: branch cache rewrite invalidation boundary forces next-query miss" {
  let cache = BranchCache::new()
  let probe = TInstr::br(LabelIdx::new(0), [])
  ignore(mb_has_branch_to_depth(probe, 0, cache))
  ignore(mb_has_branch_to_depth(probe, 0, cache))
  assert_true(cache.instr_id_hits > 0)
  let hits_before = cache.query_hits
  mb_branch_cache_invalidate(cache)
  ignore(mb_has_branch_to_depth(probe, 0, cache))
  assert_eq(cache.query_hits, hits_before)
  assert_eq(cache.query_misses, 2)
  assert_true(cache.invalidations > 0)
}

///|
test "merge blocks: branch cache stress fixture meets representative hit-rate target" {
  let hit_rate_bp = mb_branch_cache_stress_hit_rate_bp(128)
  assert_true(
    hit_rate_bp >= 8000UL,
    msg="expected >=80% branch-cache hit rate, got \{hit_rate_bp}bp",
  )
}

///|
test "merge blocks: second operand pull blocked by effect invalidation" {
  let body = TExpr::new([
    TInstr::drop(
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::call(FuncIdx::new(0), []),
        TInstr::block(
          BlockType::val_type(ValType::i32()),
          TExpr::new([
            TInstr::call(FuncIdx::new(0), []),
            TInstr::i32_const(I32(2)),
          ]),
        ),
      ),
    ),
  ])
  let out = mb_run_on_body(body)
  assert_eq(out, body)
}

///|
test "merge blocks: preserves typed if result when branch inference is unknown" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::i32_const(I32(7)),
        TInstr::local_set(
          LocalIdx::new(0),
          TInstr::if_(
            BlockType::val_type(ValType::i32()),
            TInstr::i32_const(I32(1)),
            TExpr::new([TInstr::unreachable_()]),
            Some(TExpr::new([TInstr::i32_const(I32(22))])),
          ),
        ),
      ]),
    ),
  ])
  let mod = mb_make_test_module_with_body([ValType::i32()], body)
  let out = run_merge_blocks(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail("expected typed-if result to stay valid after merge_blocks: \{e}")
  }
}

///|
test "merge blocks: preserves explicit typed block with branch-produced value" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::local_set(
          LocalIdx::new(0),
          TInstr::block(
            BlockType::val_type(ValType::i32()),
            TExpr::new([
              TInstr::block(BlockType::void_(), TExpr::new([TInstr::nop()])),
              TInstr::br(LabelIdx::new(0), [TInstr::i32_const(I32(9))]),
            ]),
          ),
        ),
      ]),
    ),
  ])
  let mod = mb_make_test_module_with_body([ValType::i32()], body)
  assert_eq(validate_module(mod), Ok(()))
  let out = run_merge_blocks(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail("expected typed block result to stay valid after merge_blocks: \{e}")
  }
}

///|
test "merge blocks: typed local.set source keeps explicit block result when inference is unknown" {
  let typed_body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([TInstr::drop(TInstr::i32_const(I32(1))), TInstr::nop()]),
    ),
    TInstr::br(LabelIdx::new(0), [TInstr::i32_const(I32(9))]),
  ])
  assert_eq(mb_infer_texpr_type(typed_body, Env::new()), None)
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::local_set(
          LocalIdx::new(0),
          TInstr::block(BlockType::val_type(ValType::i32()), typed_body),
        ),
      ]),
    ),
  ])
  let mod = mb_make_test_module_with_body([ValType::i32()], body)
  assert_eq(validate_module(mod), Ok(()))
  let out = run_merge_blocks(mod)
  assert_false(out == mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected merge_blocks to keep explicit typed block result for local.set source: \{e}",
      )
  }
}

///|
test "merge blocks: keeps ambient-fed if condition stack valid after split merge" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([
            TInstr::i32_const(I32(0)),
            TInstr::local_tee(
              LocalIdx::new(0),
              TInstr::if_(
                BlockType::val_type(ValType::i32()),
                TInstr::local_set(
                  LocalIdx::new(0),
                  TInstr::local_get(LocalIdx::new(0)),
                ),
                TExpr::new([TInstr::local_get(LocalIdx::new(0))]),
                Some(
                  TExpr::new([
                    TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
                    TInstr::br(LabelIdx::new(1), []),
                  ]),
                ),
              ),
            ),
            TInstr::br(LabelIdx::new(1), []),
          ]),
        ),
      ]),
    ),
  ])
  let mod = mb_make_test_module_with_body([ValType::i32()], body)
  assert_eq(validate_module(mod), Ok(()))
  let out = run_merge_blocks(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail("expected merge_blocks to preserve ambient-fed stack validity: \{e}")
  }
}

///|
test "merge blocks: named split preserves ambient stack for nested local.set chain" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([
            TInstr::local_get(LocalIdx::new(3)),
            TInstr::i32_const(I32(0)),
            TInstr::local_set(
              LocalIdx::new(2),
              TInstr::local_set(
                LocalIdx::new(0),
                TInstr::local_set(
                  LocalIdx::new(0),
                  TInstr::local_get(LocalIdx::new(2)),
                ),
              ),
            ),
            TInstr::br_if(LabelIdx::new(0), TInstr::i32_const(I32(1)), []),
          ]),
        ),
      ]),
    ),
  ])
  let mod = mb_make_test_module_with_body(
    [ValType::i32(), ValType::i32(), ValType::i32(), ValType::i32()],
    body,
  )
  assert_eq(validate_module(mod), Ok(()))
  let out = run_merge_blocks(mod)
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail("expected merge_blocks to preserve ambient stack consumers: \{e}")
  }
}

///|
test "merge blocks: transformed output stays typable and pass is idempotent" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::drop(
          TInstr::block(
            BlockType::val_type(ValType::i32()),
            TExpr::new([TInstr::i32_const(I32(1)), TInstr::i32_const(I32(2))]),
          ),
        ),
      ]),
    ),
  ])
  let mod = mb_make_test_module_with_body([], body)
  let out = run_merge_blocks(mod)
  match mb_extract_only_tfunc(out) {
    Some(TFunc(params, locals, texpr)) => {
      let env = Env::new()
        .with_module(out)
        .with_locals(FunctionLocals::new(params, locals).all_locals())
      let lowered = texpr.to_expr()
      match to_texpr(lowered, env) {
        Ok(_) => ()
        Err(e) => fail("expected typable output, got: \{e}")
      }
    }
    _ => fail("expected tfunc")
  }
  let once = run_merge_blocks(mod)
  let twice = run_merge_blocks(once)
  assert_eq(once, twice)
}

///|
test "merge blocks: refinalization keeps param local index space valid" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::i32_const(I32(1)),
        TInstr::drop(TInstr::i32_const(I32(2))),
      ]),
    ),
    TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
  ])
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([ValType::i32()], []))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([Func::t_func([ValType::i32()], Locals::empty(), body)]))
  let out = run_merge_blocks(mod)
  assert_eq(validate_module(out), Ok(()))
}

///|
test "merge blocks: trap-only effects invalidate movement" {
  let trap_a = compute_effects(TInstr::unreachable_())
  let trap_b = compute_effects(
    TInstr::ref_as_non_null(
      TInstr::ref_null(HeapType::abs(AbsHeapType::func())),
    ),
  )
  assert_true(invalidates(trap_a, trap_b))
  assert_true(invalidates(trap_b, trap_a))
}

///|
test "merge blocks: call effects invalidate memory effects" {
  let call_fx = compute_effects(TInstr::call(FuncIdx::new(0), []))
  let load_fx = compute_effects(
    TInstr::load(
      LoadOp::i32_load(),
      MemArg::new(0, None, 0),
      TInstr::i32_const(I32(0)),
    ),
  )
  assert_true(invalidates(call_fx, load_fx))
  assert_true(invalidates(load_fx, call_fx))
}

///|
test "merge blocks: MBEffects merge unions local sets and side-effect flags" {
  let lhs = MBEffects::new()
  lhs.locals_read.add(LocalIdx::new(0))
  lhs.reads_memory = true

  let rhs = MBEffects::new()
  rhs.locals_written.add(LocalIdx::new(1))
  rhs.writes_globals = true
  rhs.calls = true

  lhs.merge(rhs)
  assert_true(lhs.locals_read.contains(LocalIdx::new(0)))
  assert_true(lhs.locals_written.contains(LocalIdx::new(1)))
  assert_true(lhs.reads_memory)
  assert_true(lhs.writes_globals)
  assert_true(lhs.calls)
}

///|
test "merge blocks: MBEffects invalidates on local read-write hazards only" {
  let reads = MBEffects::new()
  reads.locals_read.add(LocalIdx::new(2))
  let writes = MBEffects::new()
  writes.locals_written.add(LocalIdx::new(2))
  assert_true(invalidates(reads, writes))
  assert_true(invalidates(writes, reads))

  let disjoint = MBEffects::new()
  disjoint.locals_read.add(LocalIdx::new(3))
  assert_false(invalidates(reads, disjoint))
}

///|
test "merge blocks: mb_collect_shallow_effects marks instruction-specific flags" {
  let local_fx = MBEffects::new()
  mb_collect_shallow_effects(
    TInstr::local_tee(LocalIdx::new(0), TInstr::i32_const(I32(1))),
    local_fx,
  )
  assert_true(local_fx.locals_read.contains(LocalIdx::new(0)))
  assert_true(local_fx.locals_written.contains(LocalIdx::new(0)))

  let load_fx = MBEffects::new()
  mb_collect_shallow_effects(
    TInstr::load(
      LoadOp::i32_load(),
      MemArg::new(0, None, 0),
      TInstr::i32_const(I32(0)),
    ),
    load_fx,
  )
  assert_true(load_fx.reads_memory)
  assert_true(load_fx.traps)

  let throw_fx = MBEffects::new()
  mb_collect_shallow_effects(
    TInstr::throw_ref(TInstr::ref_null(HeapType::abs(AbsHeapType::exn()))),
    throw_fx,
  )
  assert_true(throw_fx.throws)
  assert_true(throw_fx.branches)
}

///|
test "merge blocks: effect checklist is explicit and stable" {
  let checklist = mb_effect_checklist_entries()
  assert_eq(checklist.length(), 35)
}

///|
test "merge blocks: effect checklist entries match shallow effect collector" {
  for entry in mb_effect_checklist_entries() {
    let effects = MBEffects::new()
    mb_collect_shallow_effects(entry.instr, effects)
    if !mb_effect_checklist_entry_matches(entry, effects) {
      fail("effect checklist mismatch for opcode entry: \{entry.name}")
    }
  }
}

///|
priv struct MBMovementCase {
  name : String
  left : TInstr
  right : TInstr
  expect_blocked : Bool
}

///|
fn MBMovementCase::new(
  name : String,
  left : TInstr,
  right : TInstr,
  expect_blocked : Bool,
) -> MBMovementCase {
  { name, left, right, expect_blocked }
}

///|
test "merge blocks: movement matrix covers side-effect, trap, branch, and control-transfer families" {
  let i0 = TInstr::i32_const(I32(0))
  let i1 = TInstr::i32_const(I32(1))
  let ref_any = TInstr::ref_null(HeapType::abs(AbsHeapType::any()))
  let ref_exn = TInstr::ref_null(HeapType::abs(AbsHeapType::exn()))
  let load0 = TInstr::load(LoadOp::i32_load(), MemArg::new(0, None, 0), i0)
  let cases : Array[MBMovementCase] = [
    MBMovementCase::new(
      "trap_div_vs_side_effect_local_set",
      TInstr::binary(BinaryOp::i32_div_s(), i1, i0),
      TInstr::local_set(LocalIdx::new(0), i1),
      true,
    ),
    MBMovementCase::new(
      "trap_ref_cast_desc_eq_vs_side_effect_global_set",
      TInstr::ref_cast_desc_eq(true, HeapType::abs(AbsHeapType::any()), ref_any),
      TInstr::global_set(GlobalIdx::new(0), i0),
      true,
    ),
    MBMovementCase::new(
      "atomic_memory_family_vs_memory_read",
      TInstr::memory_atomic_wait32(
        MemArg::new(0, None, 0),
        i0,
        i0,
        TInstr::i64_const(I64(0L)),
      ),
      load0,
      true,
    ),
    MBMovementCase::new(
      "branch_family_blocks",
      TInstr::br_if(LabelIdx::new(0), i1, []),
      i0,
      true,
    ),
    MBMovementCase::new(
      "control_transfer_throw_ref_blocks",
      TInstr::throw_ref(ref_exn),
      i0,
      true,
    ),
    MBMovementCase::new(
      "pure_constants_allowed",
      i0,
      TInstr::i32_const(I32(7)),
      false,
    ),
    MBMovementCase::new(
      "pure_arith_can_reorder",
      TInstr::binary(BinaryOp::i32_mul(), i1, i1),
      TInstr::binary(BinaryOp::i32_add(), i1, TInstr::i32_const(I32(7))),
      false,
    ),
    MBMovementCase::new(
      "disjoint_local_reads_allowed",
      TInstr::local_get(LocalIdx::new(2)),
      TInstr::local_get(LocalIdx::new(3)),
      false,
    ),
  ]
  for case_ in cases {
    let left_fx = compute_effects(case_.left)
    let right_fx = compute_effects(case_.right)
    let lr = invalidates(left_fx, right_fx)
    let rl = invalidates(right_fx, left_fx)
    if lr != case_.expect_blocked {
      fail("left->right mismatch for movement case: \{case_.name}")
    }
    if rl != case_.expect_blocked {
      fail("right->left mismatch for movement case: \{case_.name}")
    }
  }
}

///|
test "merge blocks: infers ref.func as non-null func reference" {
  let inferred = mb_infer_tinstr_type(
    TInstr::ref_func(FuncIdx::new(0)),
    Env::new(),
  )
  assert_eq(
    inferred,
    Some(
      ValType::ref_type(RefType::new(false, HeapType::abs(AbsHeapType::func()))),
    ),
  )
}
