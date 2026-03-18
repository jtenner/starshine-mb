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
type LocalMap = Map[LocalIdx, LocalIdx]

///|
const CL_MAX_EXACT_LOCALS : Int = 4096

///|
enum ConstKey {
  I32Key(Int)
  I64Key(Int64)
  F32Key(Float)
  F64Key(Double)
} derive(Eq, Hash)

///|
priv struct Block {
  id : Int
  instrs : Array[TInstr]
  preds : Array[Int]
  succs : Array[Int]
}

///|
struct BlockLiveness {
  live_in : Set[LocalIdx]
  live_out : Set[LocalIdx]
} derive(Show)

///|
type ValueId = Int

///|
type ValueEnv = Map[LocalIdx, ValueId]

///|
type ConstTable = Map[ConstKey, ValueId]

///|
fn value_of_expr(
  expr : TInstr,
  env : ValueEnv,
  counter : Ref[Int],
  consts : ConstTable,
) -> ValueId? {
  match expr.kind {
    // Constant literals: each literal gets its own value ID
    TInstrKind::TI32Const(I32(n)) =>
      // Use consts table to get consistent ID for same constant
      match consts.get(ConstKey::I32Key(n)) {
        Some(id) => Some(id)
        None => {
          let id = counter.val
          counter.val += 1
          consts[ConstKey::I32Key(n)] = id
          Some(id)
        }
      }
    TInstrKind::TI64Const(I64(n)) =>
      // Use consts table to get consistent ID for same constant
      match consts.get(ConstKey::I64Key(n)) {
        Some(id) => Some(id)
        None => {
          let id = counter.val
          counter.val += 1
          consts[ConstKey::I64Key(n)] = id
          Some(id)
        }
      }
    TInstrKind::TF32Const(F32(f)) =>
      // Use consts table to get consistent ID for same constant
      match consts.get(ConstKey::F32Key(f)) {
        Some(id) => Some(id)
        None => {
          let id = counter.val
          counter.val += 1
          consts[ConstKey::F32Key(f)] = id
          Some(id)
        }
      }
    TInstrKind::TF64Const(F64(f)) =>
      // Use consts table to get consistent ID for same constant
      match consts.get(ConstKey::F64Key(f)) {
        Some(id) => Some(id)
        None => {
          let id = counter.val
          counter.val += 1
          consts[ConstKey::F64Key(f)] = id
          Some(id)
        }
      }

    // Copy: produces fresh value
    TInstrKind::TLocalGet(idx) => env.get(idx)

    // Anything else: fresh value
    _ => None
  }
}

///|
fn find_copies(instrs : Array[TInstr]) -> Set[(LocalIdx, LocalIdx)] {
  let copies = Set::new()
  for instr in instrs {
    match instr.kind {
      TInstrKind::TLocalSet(dst, { kind: TInstrKind::TLocalGet(src), .. }) if dst !=
        src => copies.add(ordered_pair(src, dst))
      _ => ()
    }
  }
  copies
}

///|
fn copy_frequency(copies : Set[(LocalIdx, LocalIdx)]) -> Map[LocalIdx, Int] {
  let freq = Map::new()
  for c in copies.iter() {
    let (a, b) = c
    freq[a] = freq.get(a).unwrap_or(0) + 1
    freq[b] = freq.get(b).unwrap_or(0) + 1
  }
  freq
}

///|
fn has_future_simultaneous_use(
  instrs : Array[TInstr],
  start : Int,
  a : LocalIdx,
  b : LocalIdx,
) -> Bool {
  for j in start..<instrs.length() {
    let s = simultaneous_uses(instrs[j])
    if s.contains(a) && s.contains(b) {
      return true
    }
  }
  false
}

///|
fn add_block_interference_with_values(
  block : Block,
  inter : Set[(LocalIdx, LocalIdx)],
  liveness : Map[Int, BlockLiveness],
  in_env : ValueEnv,
  counter : Ref[Int],
  consts : ConstTable,
) -> Unit {
  let live = liveness[block.id].live_out.copy()

  // 1. Forward value environments
  let envs = [in_env.copy()]
  let curr = in_env.copy()
  for instr in block.instrs {
    match instr.kind {
      TInstrKind::TLocalSet(idx, value) =>
        match value_of_expr(value, curr, counter, consts) {
          Some(v) => curr[idx] = v
          None => curr.remove(idx)
        }
      _ => ()
    }
    envs.push(curr.copy())
  }

  // 2. Backward interference
  for i in block.instrs.iter2().to_array().rev() {
    let (i, instr) = i
    let d = defs_shallow(instr)
    let u = uses_shallow(instr)
    let env_after = envs[i + 1]
    for x in d {
      for y in live {
        if x == y {
          continue
        }

        // Value numbering: if both have known values that are equal,
        // they can be coalesced ONLY if they have a future simultaneous use
        let vx = env_after.get(x)
        let vy = env_after.get(y)
        match (vx, vy) {
          (Some(vx_val), Some(vy_val)) =>
            if vx_val == vy_val {
              // Same value - check if they have a future simultaneous use
              if has_future_simultaneous_use(block.instrs, i + 1, x, y) {
                // They will be used simultaneously, so no interference
                continue
              }
            }
          _ => () // Unknown values - must add interference
        }

        // Otherwise, they interfere
        inter.add(ordered_pair(x, y))
      }
    }
    for x in d {
      live.remove(x)
    }
    for x in u {
      live.add(x)
    }
  }
}

///|
fn simultaneous_uses(instr : TInstr) -> Set[LocalIdx] {
  match instr.kind {
    TInstrKind::TBinary(_, lhs, rhs) => {
      let s = Set::new()
      for x in uses(lhs) {
        s.add(x)
      }
      for x in uses(rhs) {
        s.add(x)
      }
      s
    }
    _ => Set::new()
  }
}

///|
fn compute_coalesce_order(
  locals : Locals,
  freq : Map[LocalIdx, Int],
) -> Array[LocalIdx] {
  let order = Array::new()
  for i in 0..<locals.length() {
    order.push(LocalIdx::new(i.reinterpret_as_uint()))
  }
  order.sort_by(fn(a, b) {
    let l = freq.get(b).unwrap_or(0)
    let r = freq.get(a).unwrap_or(0)
    if l == r {
      0
    } else if l > r {
      1
    } else {
      -1
    }
  })
  order
}

///|
fn uses_shallow(instr : TInstr) -> Set[LocalIdx] {
  let result = Set::new()
  match instr.kind {
    TInstrKind::TLocalGet(idx) => result.add(idx)
    TInstrKind::TLocalSet(_, value) =>
      // value is evaluated in this block
      for x in uses(value) {
        result.add(x)
      }
    TInstrKind::TIf(_, cond, _, _) =>
      // only condition belongs to this block
      for x in uses(cond) {
        result.add(x)
      }
    TInstrKind::TLoop(_, body) =>
      for b in body.instrs {
        for x in uses(b) {
          result.add(x)
        }
      }
    _ =>
      for x in uses(instr) {
        result.add(x)
      }
  }
  result
}

///|
fn defs_shallow(instr : TInstr) -> Set[LocalIdx] {
  let result = Set::new()
  match instr.kind {
    TInstrKind::TLocalSet(idx, _) => result.add(idx)
    _ => ()
  }
  result
}

///|
fn simulate_block_values(
  block : Block,
  in_env : ValueEnv,
  counter : Ref[Int],
  consts : ConstTable,
) -> ValueEnv {
  let env = in_env.copy()
  for instr in block.instrs {
    match instr.kind {
      TInstrKind::TLocalSet(idx, value) =>
        match value_of_expr(value, env, counter, consts) {
          Some(v) => env[idx] = v
          None =>
            // value becomes unknown
            env.remove(idx)
        }
      _ => ()
    }
  }
  env
}

///|
fn compute_cfg_value_envs(
  blocks : Array[Block],
  locals : Locals,
  counter : Ref[Int],
  consts : ConstTable,
) -> (Map[Int, ValueEnv], Map[Int, ValueEnv]) {
  let values_in = Map::new()
  let values_out = Map::new()

  // Initialize
  for b in blocks {
    values_in[b.id] = Map::new()
    values_out[b.id] = Map::new()
  }
  let mut changed = true
  while changed {
    changed = false
    for b in blocks {

      // --- compute values_in ---
      let mut new_in = Map::new()
      if b.preds.length() == 1 {
        new_in = values_out[b.preds[0]]
      } else if b.preds.length() > 1 {
        // must-value intersection
        for i in 0..<locals.length() {
          let idx = LocalIdx::new(i.reinterpret_as_uint())
          let mut first = true
          let mut same : ValueId? = None
          for p in b.preds {
            match values_out[p].get(idx) {
              Some(v) =>
                if first {
                  same = Some(v)
                  first = false
                } else if same is Some(s) && s != v {
                  same = None
                  break
                }
              None => {
                same = None
                break
              }
            }
          }
          if same is Some(v) {
            new_in[idx] = v
          }
        }
      }

      // --- compute values_out ---
      let new_out = simulate_block_values(b, new_in, counter, consts)
      if new_out != values_out[b.id] {
        values_out[b.id] = new_out
        values_in[b.id] = new_in
        changed = true
      }
    }
  }
  (values_in, values_out)
}

///|
fn compute_cfg_liveness(blocks : Array[Block]) -> Map[Int, BlockLiveness] {
  let live_in = Map::new()
  let live_out = Map::new()
  let use_def = Map::new()
  for b in blocks {
    live_in[b.id] = Set::new()
    live_out[b.id] = Set::new()
    use_def[b.id] = compute_block_use_def(b)
  }
  let mut changed = true
  while changed {
    changed = false
    for b in blocks {
      let old_in = live_in[b.id].copy()

      // live_out is the UNION of successors' live_in
      let new_out = Set::new()
      for s in b.succs {
        for x in live_in[s] {
          new_out.add(x)
        }
      }
      live_out[b.id] = new_out
      let (u, d) = use_def[b.id]
      let new_in = Set::new()
      // Standard: live_in = (live_out - def) U use
      for x in live_out[b.id] {
        if !d.contains(x) {
          new_in.add(x)
        }
      }
      for x in u {
        new_in.add(x)
      }
      if old_in != new_in {
        live_in[b.id] = new_in
        changed = true
      }
    }
  }
  let result = Map::new()
  for b in blocks {
    result[b.id] = BlockLiveness::{
      live_in: live_in[b.id],
      live_out: live_out[b.id],
    }
  }
  result
}

///|
fn compute_interferences_cfg(
  blocks : Array[Block],
  locals : Locals,
) -> (
  Set[(LocalIdx, LocalIdx)],
  Map[Int, ValueEnv],
  Map[Int, ValueEnv],
  Map[Int, BlockLiveness],
) {
  let liveness = compute_cfg_liveness(blocks)
  let inter = Set::new()

  // Fresh value numbering state
  let counter = Ref::new(0)
  let consts = Map::new()
  let (values_in, values_out) = compute_cfg_value_envs(
    blocks, locals, counter, consts,
  )

  // --- 1. Intra-block interference ---
  for b in blocks {
    let in_env = values_in[b.id]
    add_block_interference_with_values(
      b, inter, liveness, in_env, counter, consts,
    )
  }

  // --- Merge-point interference ---
  for b in blocks {
    if b.preds.length() <= 1 {
      continue
    }
    let live = liveness[b.id].live_in
    for x in live {
      for y in live {
        if x == y {
          continue
        }

        // If value-numbering proves equality across ALL paths, no interference
        if must_be_same_value(x, y, blocks, values_out, liveness) {
          continue
        }

        // Otherwise, they may differ → interfere
        inter.add(ordered_pair(x, y))
      }
    }
  }
  (inter, values_in, values_out, liveness)
}

///|
fn compute_block_use_def(block : Block) -> (Set[LocalIdx], Set[LocalIdx]) {
  let use_set = Set::new()
  let def = Set::new()
  for instr in block.instrs {
    let d = defs_shallow(instr)
    let u = uses_shallow(instr)

    // uses before defs only
    for x in u {
      if !def.contains(x) {
        use_set.add(x)
      }
    }
    for x in d {
      def.add(x)
    }
  }
  (use_set, def)
}

///|
fn build_cfg(instrs : Array[TInstr]) -> Array[Block] {
  let blocks = Array::new()
  let mut next_id = 0
  fn new_block() -> Block {
    let b = Block::{
      id: next_id,
      instrs: Array::new(),
      preds: Array::new(),
      succs: Array::new(),
    }
    next_id = next_id + 1
    b
  }

  let mut current = new_block()
  blocks.push(current)
  for instr in instrs {
    match instr.kind {

      // if creates two successors + merge
      TInstrKind::TIf(_, _, then_expr, else_expr) => {
        current.instrs.push(instr)
        let then_block = new_block()
        let else_block = new_block()
        let merge_block = new_block()

        // edges
        current.succs.push(then_block.id)
        current.succs.push(else_block.id)
        then_block.preds.push(current.id)
        else_block.preds.push(current.id)
        then_block.succs.push(merge_block.id)
        else_block.succs.push(merge_block.id)
        merge_block.preds.push(then_block.id)
        merge_block.preds.push(else_block.id)

        // fill then / else
        then_block.instrs.append(then_expr.instrs)
        if else_expr is Some(e) {
          else_block.instrs.append(e.instrs)
        }
        blocks.push(then_block)
        blocks.push(else_block)
        blocks.push(merge_block)
        current = merge_block
      }

      // loop introduces backedge
      TInstrKind::TLoop(_, body) => {
        current.instrs.push(instr)
        let loop_body = new_block()
        let after_loop = new_block()
        current.succs.push(loop_body.id)
        loop_body.preds.push(current.id)
        loop_body.instrs.append(body.instrs)

        // backedge
        loop_body.succs.push(loop_body.id)
        loop_body.preds.push(loop_body.id)

        // exit edge
        loop_body.succs.push(after_loop.id)
        after_loop.preds.push(loop_body.id)
        blocks.push(loop_body)
        blocks.push(after_loop)
        current = after_loop
      }

      // default: straight line
      _ => current.instrs.push(instr)
    }
  }
  blocks
}

///|
fn compute_block_liveness(instrs : Array[TInstr]) -> Array[Set[LocalIdx]] {
  let live = Set::new()
  let result = Array::new()

  // iterate backwards
  for instr in instrs.rev_iter() {
    result.push(live.copy())
    let d = defs(instr)
    let u = uses(instr)
    for x in d {
      live.remove(x)
    }

    // live = live ∪ uses
    for x in u {
      live.add(x)
    }
  }
  result.rev_iter().to_array()
}

///|
fn ordered_pair(a : LocalIdx, b : LocalIdx) -> (LocalIdx, LocalIdx) {
  if a.0 < b.0 {
    (a, b)
  } else {
    (b, a)
  }
}

///|
fn interferes(
  inter : Set[(LocalIdx, LocalIdx)],
  a : LocalIdx,
  b : LocalIdx,
) -> Bool {
  if a == b {
    false
  } else {
    inter.contains(ordered_pair(a, b))
  }
}

///|

///|
fn must_be_same_value(
  a : LocalIdx,
  b : LocalIdx,
  blocks : Array[Block],
  values_out : Map[Int, ValueEnv],
  liveness : Map[Int, BlockLiveness],
) -> Bool {

  // This function checks if two locals MUST hold the same value
  // at merge points (blocks with multiple predecessors).
  // It's used to allow coalescing even when there's interference,
  // if we can prove the locals always hold the same value.
  //
  // For single-block functions or non-merge points, we return false
  // because the interference graph already handles value numbering
  // for those cases.

  let mut found_merge_point = false
  for bblock in blocks {
    let bid = bblock.id

    // Only check merge points (blocks with multiple predecessors)
    if bblock.preds.length() <= 1 {
      continue
    }
    let live = liveness[bid].live_in

    // If both locals are not live here, skip
    if !live.contains(a) || !live.contains(b) {
      continue
    }
    found_merge_point = true

    // Collect all defined values for a and b across all predecessors
    let mut defined_value : ValueId? = None
    let mut all_compatible = true
    for p in bblock.preds {
      let env = values_out[p]
      let va = env.get(a)
      let vb = env.get(b)

      // Check if either a or b is defined on this path
      match (va, vb) {
        // Both defined: must be equal
        (Some(x), Some(y)) => {
          if x != y {
            all_compatible = false
            break
          }
          // Both defined and equal: check against previously seen value
          match defined_value {
            None => defined_value = Some(x)
            Some(v) =>
              if v != x {
                all_compatible = false
                break
              }
          }
        }

        // Only a is defined
        (Some(x), None) =>
          match defined_value {
            None => defined_value = Some(x)
            Some(v) =>
              if v != x {
                all_compatible = false
                break
              }
          }

        // Only b is defined
        (None, Some(y)) =>
          match defined_value {
            None => defined_value = Some(y)
            Some(v) =>
              if v != y {
                all_compatible = false
                break
              }
          }

        // Neither defined: this path doesn't constrain the value
        (None, None) => ()
      }
    }
    if !all_compatible {
      return false
    }

    // If we found a consistent value across all paths, they can be coalesced
    if defined_value is None {
      return false
    }
  }

  // If we found at least one merge point where both are live,
  // and all checks passed, they must be equal
  found_merge_point
}

///|
fn compute_coalescing(
  locals : Locals,
  inter : Set[(LocalIdx, LocalIdx)],
  order : Array[LocalIdx],
  param_count : Int,
) -> LocalMap {
  let mapping : LocalMap = Map::new()
  let reps : Array[LocalIdx] = Array::new()
  let bounded_param_count = if param_count < locals.length() {
    param_count
  } else {
    locals.length()
  }
  for i in 0..<bounded_param_count {
    let idx = LocalIdx::new(i.reinterpret_as_uint())
    mapping[idx] = idx
    reps.push(idx)
  }
  for li in order {
    if li.0.reinterpret_as_int() < bounded_param_count {
      continue
    }
    let ty_i = locals[li.0.reinterpret_as_int()]
    let mut assigned = false
    for r in reps {
      if ty_i != locals[r.0.reinterpret_as_int()] {
        continue
      }

      // TRUST the interference graph.
      // If they are in the set, they overlap with different values
      // or they are a copy where the source remained live.
      if !interferes(inter, li, r) {
        mapping[li] = r
        assigned = true
        break
      }
    }
    if !assigned {
      mapping[li] = li
      reps.push(li)
    }
  }
  mapping
}

///|
fn compute_interferences(instrs : Array[TInstr]) -> Set[(LocalIdx, LocalIdx)] {
  let interferences = Set::new()

  // Get liveness before each instruction
  let live_sets = compute_block_liveness(instrs)
  for live in live_sets {
    // For every pair of live locals
    for x in live {
      for y in live {
        if x != y {
          interferences.add(ordered_pair(x, y))
        }
      }
    }
  }
  interferences
}

///|
fn cl_collect_param_types(mod : Module) -> Array[Array[ValType]] {
  let out : Array[Array[ValType]] = []
  let env = Env::new().with_module(mod)
  match mod.func_sec {
    Some(FuncSec(type_idxs)) =>
      for tidx in type_idxs {
        match env.resolve_functype(tidx) {
          Some(FuncType(params, _)) => out.push(params)
          None => out.push([])
        }
      }
    None => ()
  }
  out
}

///|
fn cl_localidx_to_int(idx : LocalIdx) -> Int {
  let LocalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn cl_invalid_local_map_entries(mapping : LocalMap, limit : Int) -> String {
  let mut out = ""
  let mut shown = 0
  for entry in mapping {
    let (old_idx, new_idx) = entry
    let old_raw = cl_localidx_to_int(old_idx)
    let new_raw = cl_localidx_to_int(new_idx)
    if new_raw < limit {
      continue
    }
    shown += 1
    out = out + "\n  \{old_raw} -> \{new_raw}"
    if shown >= 8 {
      break
    }
  }
  if shown == 0 {
    "\n  <none>"
  } else {
    out
  }
}

///|
fn cl_trace_noop(_ : String) -> Unit {
  ()
}

///|
fn cl_trace_should_log_func(ordinal : Int, trace_all_funcs : Bool) -> Bool {
  pass_trace_log_enabled(ordinal, trace_all_funcs)
}

///|
fn cl_trim_trailing_unused_locals(
  locals : Locals,
  param_count : Int,
  max_local_used : Int,
) -> (Locals, Int) {
  let needed_locals = if max_local_used < param_count {
    0
  } else {
    max_local_used - param_count + 1
  }
  let bounded_needed_locals = if needed_locals < 0 {
    0
  } else if needed_locals < locals.length() {
    needed_locals
  } else {
    locals.length()
  }
  if bounded_needed_locals >= locals.length() {
    (locals, 0)
  } else {
    let trimmed = Locals::empty()
    for i in 0..<bounded_needed_locals {
      trimmed.push(locals[i])
    }
    (trimmed, locals.length() - bounded_needed_locals)
  }
}

///|
fn rewrite_body_locals(
  body : TExpr,
  mapping : LocalMap,
) -> Result[(TExpr, Int), String] {
  let max_local_used = Ref::new(-1)
  let rewriter = ModuleTransformer::new().on_localidx_evt(fn(
    _,
    _,
    idx : LocalIdx,
  ) {
    let mapped = mapping.get(idx).unwrap_or(idx)
    let mapped_raw = cl_localidx_to_int(mapped)
    if mapped_raw > max_local_used.val {
      max_local_used.val = mapped_raw
    }
    if mapped == idx {
      unchanged()
    } else {
      change((), mapped)
    }
  })
  match rewriter.walk_texpr((), body) {
    Ok((out, _)) => Ok((out, max_local_used.val))
    Err(e) => Err(e)
  }
}

///|
fn coalesce_locals(
  param_types? : Array[Array[ValType]] = [],
  trace? : (String) -> Unit = cl_trace_noop,
  trace_all_funcs? : Bool = false,
) -> ModuleTransformer[Unit, String] {
  let next_def_idx = Ref::new(0)
  ModuleTransformer::new().on_func_evt(fn(_, _, func : Func) {
    let def_idx = next_def_idx.val
    next_def_idx.update(fn(i) { i + 1 })
    match func {
      Func(_) => unchanged()
      TFunc(func_params, locals, body) => {
        let ordinal = def_idx + 1
        let log_func = cl_trace_should_log_func(ordinal, trace_all_funcs)
        let func_start_ms = if log_func { sl_trace_now_ms() } else { 0UL }
        let fallback_params = param_types.get(def_idx).unwrap_or(func_params)
        let function_locals = match
          FunctionLocals::from_typed_func_for_pass(
            fallback_params, func_params, locals,
          ) {
          Ok(ls) => ls
          Err(e) => abort("coalesce_locals: \{e}")
        }
        let params = function_locals.params()
        let param_count = params.length()
        let all_locals = function_locals.all_locals()
        if log_func {
          trace(
            "func[\{ordinal}] start params=\{param_count} locals=\{locals.length()} all_locals=\{all_locals.length()} top_instrs=\{body.instrs.length()}",
          )
        }
        if all_locals.length() == 0 {
          if log_func {
            trace(
              "func[\{ordinal}] skip no-locals elapsed_ms=\{sl_trace_elapsed_ms(func_start_ms)} top_instrs=\{body.instrs.length()}",
            )
          }
          return unchanged()
        }
        if all_locals.length() > CL_MAX_EXACT_LOCALS {
          let fast_start_ms = if log_func { sl_trace_now_ms() } else { 0UL }
          if log_func {
            trace(
              "func[\{ordinal}] phase=fast_path_large_locals start all_locals=\{all_locals.length()} threshold=\{CL_MAX_EXACT_LOCALS}",
            )
          }
          let max_local_used = cl_max_local_used(body)
          let (trimmed_locals, dropped_trailing) = cl_trim_trailing_unused_locals(
            locals, param_count, max_local_used,
          )
          if log_func {
            trace(
              "func[\{ordinal}] phase=fast_path_large_locals done elapsed_ms=\{sl_trace_elapsed_ms(fast_start_ms)} max_local_used=\{max_local_used} dropped_trailing=\{dropped_trailing} locals=\{locals.length()}->\{trimmed_locals.length()}",
            )
          }
          if dropped_trailing == 0 {
            if log_func {
              trace(
                "func[\{ordinal}] done elapsed_ms=\{sl_trace_elapsed_ms(func_start_ms)} changed=false reason=skip_large_locals all_locals=\{all_locals.length()} threshold=\{CL_MAX_EXACT_LOCALS}",
              )
            }
            return unchanged()
          }
          if log_func {
            trace(
              "func[\{ordinal}] done elapsed_ms=\{sl_trace_elapsed_ms(func_start_ms)} changed=true reason=trim_trailing_unused_for_large_locals locals=\{locals.length()}->\{trimmed_locals.length()} top_instrs=\{body.instrs.length()}->\{body.instrs.length()}",
            )
          }
          return change((), Func::t_func(params, trimmed_locals, body))
        }
        let instrs = body.instrs
        let build_cfg_start_ms = if log_func { sl_trace_now_ms() } else { 0UL }
        if log_func {
          trace(
            "func[\{ordinal}] phase=build_cfg start top_instrs=\{instrs.length()}",
          )
        }
        let blocks = build_cfg(instrs)
        if log_func {
          trace(
            "func[\{ordinal}] phase=build_cfg done elapsed_ms=\{sl_trace_elapsed_ms(build_cfg_start_ms)} blocks=\{blocks.length()}",
          )
        }
        let inter_start_ms = if log_func { sl_trace_now_ms() } else { 0UL }
        if log_func {
          trace(
            "func[\{ordinal}] phase=compute_interferences start blocks=\{blocks.length()} all_locals=\{all_locals.length()}",
          )
        }
        let (inter, _, _, liveness) = compute_interferences_cfg(
          blocks, all_locals,
        )
        if log_func {
          trace(
            "func[\{ordinal}] phase=compute_interferences done elapsed_ms=\{sl_trace_elapsed_ms(inter_start_ms)} interferences=\{inter.length()}",
          )
        }
        if log_func {
          trace(
            "func[\{ordinal}] phase=compute_liveness done elapsed_ms=0 blocks=\{liveness.length()} reused=true",
          )
        }
        let order_start_ms = if log_func { sl_trace_now_ms() } else { 0UL }
        if log_func {
          trace("func[\{ordinal}] phase=compute_order start")
        }
        let copies = find_copies(instrs)
        let freq = copy_frequency(copies)
        let order = compute_coalesce_order(all_locals, freq)
        if log_func {
          trace(
            "func[\{ordinal}] phase=compute_order done elapsed_ms=\{sl_trace_elapsed_ms(order_start_ms)} copies=\{copies.length()} freq_entries=\{freq.length()} order=\{order.length()}",
          )
        }
        let coalesce_start_ms = if log_func { sl_trace_now_ms() } else { 0UL }
        if log_func {
          trace("func[\{ordinal}] phase=compute_mapping start")
        }
        let mapping = compute_coalescing(all_locals, inter, order, param_count)
        if log_func {
          trace(
            "func[\{ordinal}] phase=compute_mapping done elapsed_ms=\{sl_trace_elapsed_ms(coalesce_start_ms)} mapping=\{mapping.length()}",
          )
        }
        let remap_start_ms = if log_func { sl_trace_now_ms() } else { 0UL }
        if log_func {
          trace("func[\{ordinal}] phase=remap_locals start")
        }
        let (new_locals, rep_to_new) = compute_new_locals(
          locals, mapping, param_count,
        )
        let final_map = compose_maps(mapping, rep_to_new)
        if log_func {
          trace(
            "func[\{ordinal}] phase=remap_locals done elapsed_ms=\{sl_trace_elapsed_ms(remap_start_ms)} old_locals=\{locals.length()} new_locals=\{new_locals.length()} final_map=\{final_map.length()}",
          )
        }
        let rewrite_start_ms = if log_func { sl_trace_now_ms() } else { 0UL }
        if log_func {
          trace("func[\{ordinal}] phase=rewrite_body start")
        }
        let (new_body, max_local_used) = match
          rewrite_body_locals(body, final_map) {
          Ok(result) => result
          Err(e) => {
            if log_func {
              trace(
                "func[\{ordinal}] phase=rewrite_body error elapsed_ms=\{sl_trace_elapsed_ms(rewrite_start_ms)} \{e}",
              )
            }
            return error(e)
          }
        }
        if log_func {
          trace(
            "func[\{ordinal}] phase=rewrite_body done elapsed_ms=\{sl_trace_elapsed_ms(rewrite_start_ms)} max_local_used=\{max_local_used} top_instrs=\{body.instrs.length()}->\{new_body.instrs.length()}",
          )
        }
        let local_limit = param_count + new_locals.length()
        if max_local_used >= local_limit {
          let err = "CoalesceLocals produced an invalid local index: def_idx=\{def_idx} param_count=\{param_count} old_locals=\{locals.length()} new_locals=\{new_locals.length()} max_local_used=\{max_local_used} local_limit=\{local_limit} invalid_final_map_entries=\{cl_invalid_local_map_entries(final_map, local_limit)}"
          if log_func {
            trace(
              "func[\{ordinal}] phase=validate error elapsed_ms=\{sl_trace_elapsed_ms(func_start_ms)} \{err}",
            )
          }
          return error(err)
        }
        if log_func {
          let changed = new_locals != locals || new_body != body
          trace(
            "func[\{ordinal}] done elapsed_ms=\{sl_trace_elapsed_ms(func_start_ms)} changed=\{changed} locals=\{locals.length()}->\{new_locals.length()} top_instrs=\{body.instrs.length()}->\{new_body.instrs.length()} interferences=\{inter.length()} copies=\{copies.length()}",
          )
        }
        change((), Func::t_func(params, new_locals, new_body))
      }
    }
  })
}

///|
fn coalesce_locals_ir_pass_with_trace(
  mod : Module,
  trace? : (String) -> Unit = cl_trace_noop,
  trace_all_funcs? : Bool = false,
) -> ModuleTransformer[IRContext, String] {
  wrap_unit_func_pass(
    coalesce_locals(
      param_types=cl_collect_param_types(mod),
      trace~,
      trace_all_funcs~,
    ),
  )
}

///|
fn compute_new_locals(
  locals : Locals,
  mapping : LocalMap,
  param_count : Int,
) -> (Locals, Map[LocalIdx, LocalIdx]) {
  let new_locals = Locals::empty()
  let rep_to_new = Map::new()
  for i in 0..<param_count {
    let idx = LocalIdx::new(i.reinterpret_as_uint())
    rep_to_new[idx] = idx
  }
  for i in 0..<locals.length() {
    let old_idx = LocalIdx::new((param_count + i).reinterpret_as_uint())
    let rep = mapping.get(old_idx).unwrap_or(old_idx)
    if !rep_to_new.contains(rep) {
      let rep_i = rep.0.reinterpret_as_int()
      if rep_i < param_count {
        continue
      }
      let new_idx = LocalIdx::new(new_locals.length().reinterpret_as_uint())
      let abs_idx = LocalIdx::new(
        (param_count + new_idx.0.reinterpret_as_int()).reinterpret_as_uint(),
      )
      rep_to_new[rep] = abs_idx
      let rep_local_i = rep_i - param_count
      if rep_local_i >= 0 && rep_local_i < locals.length() {
        new_locals.push(locals[rep_local_i])
      } else {
        new_locals.push(locals[i])
      }
    }
  }
  (new_locals, rep_to_new)
}

///|
fn compose_maps(
  mapping : LocalMap,
  rep_to_new : Map[LocalIdx, LocalIdx],
) -> LocalMap {
  let fin = Map::new()
  for m in mapping {
    let (old, rep) = m
    fin[old] = rep_to_new.get(rep).unwrap_or(rep)
  }
  fin
}

///|
fn cl_max_local_used(body : TExpr) -> Int {
  let max_local_used = Ref::new(-1)
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_localidx_evt(fn(
      _,
      _,
      idx : LocalIdx,
    ) {
      let raw = cl_localidx_to_int(idx)
      if raw > max_local_used.val {
        max_local_used.val = raw
      }
      unchanged()
    },
  )
  ignore(walker.walk_texpr((), body))
  max_local_used.val
}

///|
test "liveness: simple linear block" {
  let x = LocalIdx::new(0)
  let instrs = [
    TInstr::local_set(x, TInstr::i32_const(I32(1))),
    TInstr::local_get(x),
  ]
  let live = compute_block_liveness(instrs)

  // Before instruction 0, x is live (used later)
  assert_true(live[0].contains(x))

  // Before instruction 1, x is NOT live
  assert_true(!live[1].contains(x))
}

///|
test "liveness: liveness ends after last use" {
  let x = LocalIdx::new(0)
  let instrs = [
    TInstr::local_set(x, TInstr::i32_const(I32(1))),
    TInstr::local_get(x),
    TInstr::i32_const(I32(0)),
  ]
  let live = compute_block_liveness(instrs)

  // Before the set, x is live (used later)
  assert_true(live[0].contains(x))

  // Before the get, x is NOT live
  assert_true(!live[1].contains(x))

  // Before the instruction after the get, x is no longer live
  assert_true(!live[2].contains(x))
}

///|
test "interference: non-overlapping locals" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let instrs = [
    TInstr::local_set(x, TInstr::i32_const(I32(1))),
    TInstr::local_get(x),
    TInstr::local_set(y, TInstr::i32_const(I32(2))),
    TInstr::local_get(y),
  ]
  let interferences = compute_interferences(instrs)
  assert_true(!interferences.contains((x, y)))
}

///|
test "interference: overlapping locals" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let instrs = [
    TInstr::local_set(x, TInstr::i32_const(I32(1))),
    TInstr::local_set(y, TInstr::i32_const(I32(2))),
    TInstr::local_get(x),
    TInstr::local_get(y),
  ]
  let interferences = compute_interferences(instrs)
  assert_true(interferences.contains((x, y)))
}

///|
test "interference: non-overlapping locals do not interfere" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let instrs = [
    TInstr::local_set(x, TInstr::i32_const(I32(1))),
    TInstr::local_get(x),
    TInstr::local_set(y, TInstr::i32_const(I32(2))),
    TInstr::local_get(y),
  ]
  let inter = compute_interferences(instrs)
  assert_true(!inter.contains(ordered_pair(x, y)))
}

///|
test "interference: overlapping locals interfere" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let instrs = [
    TInstr::local_set(x, TInstr::i32_const(I32(1))),
    TInstr::local_set(y, TInstr::i32_const(I32(2))),
    TInstr::local_get(x),
    TInstr::local_get(y),
  ]
  let inter = compute_interferences(instrs)
  assert_true(inter.contains(ordered_pair(x, y)))
}

///|
fn identity_order(n : Int) -> Array[LocalIdx] {
  let order = Array::new()
  for i in 0..<n {
    order.push(LocalIdx::new(i.reinterpret_as_uint()))
  }
  order
}

///|
fn compute_coalescing_simple(
  locals : Locals,
  inter : Set[(LocalIdx, LocalIdx)],
  order : Array[LocalIdx],
) -> LocalMap {
  let mapping : LocalMap = Map::new()
  let reps : Array[LocalIdx] = Array::new()
  for li in order {
    let ty_i = locals[li.0.reinterpret_as_int()]
    let mut assigned = false
    for r in reps {
      let ty_r = locals[r.0.reinterpret_as_int()]
      if ty_i != ty_r {
        continue
      }
      if !interferes(inter, li, r) {
        mapping[li] = r
        assigned = true
        break
      }
    }
    if !assigned {
      mapping[li] = li
      reps.push(li)
    }
  }
  mapping
}

///|
test "CoalesceLocals: trivial coalesce" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let instrs = [
    TInstr::local_set(x, TInstr::i32_const(I32(1))),
    TInstr::local_get(x),
    TInstr::local_set(y, TInstr::i32_const(I32(2))),
    TInstr::local_get(y),
  ]
  let locals = Locals::from_types([ValType::i32(), ValType::i32()])
  let inter = compute_interferences(instrs)
  let order = identity_order(locals.length())
  let map = compute_coalescing_simple(locals, inter, order)
  assert_eq(map[x], x)
  assert_eq(map[y], x) // y coalesced into x
}

///|
test "CoalesceLocals: no coalesce when interfering" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let instrs = [
    TInstr::local_set(x, TInstr::i32_const(I32(1))),
    TInstr::local_set(y, TInstr::i32_const(I32(2))),
    TInstr::local_get(x),
    TInstr::local_get(y),
  ]
  let locals = Locals::from_types([ValType::i32(), ValType::i32()])
  let inter = compute_interferences(instrs)
  let order = identity_order(locals.length())
  let map = compute_coalescing_simple(locals, inter, order)
  assert_eq(map[x], x)
  assert_eq(map[y], y)
}

///|
test "CoalesceLocals: trivial coalescing rewrites locals" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let instrs = [
    TInstr::local_set(x, TInstr::i32_const(I32(1))),
    TInstr::local_get(x),
    TInstr::local_set(y, TInstr::i32_const(I32(2))),
    TInstr::local_get(y),
  ]
  let func = Func::t_func(
    [],
    Locals::from_types([ValType::i32(), ValType::i32()]),
    TExpr::new(instrs),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let pass = coalesce_locals()
  let (new_module, _) = pass.walk_module((), mod).unwrap()

  // After coalescing, only one local remains
  assert_true(
    new_module.code_sec is Some(CodeSec([new_func])) &&
    new_func is TFunc(_, locals, _) &&
    locals.length() == 1,
  )
}

///|
test "CoalesceLocals large-local fast path trims trailing unused locals" {
  let locals : Locals = Locals::empty()
  for _ in 0..<(CL_MAX_EXACT_LOCALS + 8) {
    locals.push(ValType::i32())
  }
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        locals,
        TExpr::new([
          TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(9))),
          TInstr::local_get(LocalIdx::new(0)),
        ]),
      ),
    ]),
  )
  let pass = coalesce_locals()
  let out = match pass.walk_module((), mod) {
    Ok((next_mod, _)) => next_mod
    Err(e) => fail("unexpected coalesce_locals large-local pass error: \{e}")
  }
  match out.code_sec {
    Some(CodeSec([TFunc(_, out_locals, _)])) =>
      assert_eq(out_locals.length(), 1)
    _ => fail("expected one typed function in output module")
  }
}

///|
test "CoalesceLocals: locals of different types do not coalesce" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let instrs = [
    TInstr::local_set(x, TInstr::i32_const(I32(1))),
    TInstr::local_get(x),
    TInstr::local_set(y, TInstr::f32_const(F32(1.0))),
    TInstr::local_get(y),
  ]
  let func = Func::t_func(
    [],
    Locals::from_types([ValType::i32(), ValType::f32()]),
    TExpr::new(instrs),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let (new_mod, _) = coalesce_locals().walk_module((), mod).unwrap()
  assert_true(
    new_mod.code_sec is Some(CodeSec([TFunc(_, locals, _)])) &&
    locals.length() == 2,
  )
}

///|
test "CoalesceLocals: nested expressions still allow coalescing" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let instrs = [
    TInstr::local_set(x, TInstr::i32_const(I32(1))),
    TInstr::binary(
      BinaryOp::i32_add(),
      TInstr::local_get(x),
      TInstr::i32_const(I32(1)),
    ),
    TInstr::local_set(y, TInstr::i32_const(I32(2))),
    TInstr::local_get(y),
  ]
  let func = Func::t_func(
    [],
    Locals::from_types([ValType::i32(), ValType::i32()]),
    TExpr::new(instrs),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let (new_mod, _) = coalesce_locals().walk_module((), mod).unwrap()
  assert_true(
    new_mod.code_sec is Some(CodeSec([TFunc(_, locals, _)])) &&
    locals.length() == 1,
  )
}

///|
test "CFG liveness: merge causes interference" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let instrs = [
    TInstr::if_(
      BlockType::void_(),
      TInstr::i32_const(I32(1)),
      TExpr::new([TInstr::local_set(x, TInstr::i32_const(I32(1)))]),
      Some(TExpr::new([TInstr::local_set(y, TInstr::i32_const(I32(2)))])),
    ),
    TInstr::local_get(x),
    TInstr::local_get(y),
  ]
  let locals = Locals::from_types([ValType::i32(), ValType::i32()])
  let blocks = build_cfg(instrs)
  let (inter, _, _, _) = compute_interferences_cfg(blocks, locals)
  assert_true(inter.contains(ordered_pair(x, y)))
}

///|
test "CFG liveness: diamond merge creates interference" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let instrs = [
    TInstr::if_(
      BlockType::void_(),
      TInstr::i32_const(I32(1)),
      TExpr::new([TInstr::local_set(x, TInstr::i32_const(I32(1)))]),
      Some(TExpr::new([TInstr::local_set(y, TInstr::i32_const(I32(2)))])),
    ),
    TInstr::binary(
      BinaryOp::i32_add(),
      TInstr::local_get(x),
      TInstr::local_get(y),
    ),
  ]
  let locals = Locals::from_types([ValType::i32(), ValType::i32()])
  let blocks = build_cfg(instrs)
  let (inter, _, _, _) = compute_interferences_cfg(blocks, locals)
  assert_true(inter.contains(ordered_pair(x, y)))
}

///|
test "CFG liveness: disjoint branch locals do not interfere" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let instrs = [
    TInstr::if_(
      BlockType::void_(),
      TInstr::i32_const(I32(1)),
      TExpr::new([
        TInstr::local_set(x, TInstr::i32_const(I32(1))),
        TInstr::local_get(x),
      ]),
      Some(
        TExpr::new([
          TInstr::local_set(y, TInstr::i32_const(I32(2))),
          TInstr::local_get(y),
        ]),
      ),
    ),
    TInstr::i32_const(I32(0)),
  ]
  let locals = Locals::from_types([ValType::i32(), ValType::i32()])
  let blocks = build_cfg(instrs)
  let (inter, _, _, _) = compute_interferences_cfg(blocks, locals)
  assert_true(!inter.contains(ordered_pair(x, y)))
}

///|
test "CoalesceLocals: merge interference prevents coalescing" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let instrs = [
    TInstr::if_(
      BlockType::void_(),
      TInstr::i32_const(I32(1)),
      TExpr::new([TInstr::local_set(x, TInstr::i32_const(I32(1)))]),
      Some(TExpr::new([TInstr::local_set(y, TInstr::i32_const(I32(2)))])),
    ),
    TInstr::binary(
      BinaryOp::i32_add(),
      TInstr::local_get(x),
      TInstr::local_get(y),
    ),
  ]
  let func = Func::t_func(
    [],
    Locals::from_types([ValType::i32(), ValType::i32()]),
    TExpr::new(instrs),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let (new_mod, _) = coalesce_locals().walk_module((), mod).unwrap()
  assert_true(
    new_mod.code_sec is Some(CodeSec([TFunc(_, locals, _)])) &&
    locals.length() == 2,
  )
}

///|
test "CoalesceLocals: branch-local lifetimes can be coalesced" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let instrs = [
    TInstr::if_(
      BlockType::void_(),
      TInstr::i32_const(I32(1)),
      TExpr::new([
        TInstr::local_set(x, TInstr::i32_const(I32(1))),
        TInstr::local_get(x),
      ]),
      Some(
        TExpr::new([
          TInstr::local_set(y, TInstr::i32_const(I32(2))),
          TInstr::local_get(y),
        ]),
      ),
    ),
    TInstr::i32_const(I32(0)),
  ]
  let func = Func::t_func(
    [],
    Locals::from_types([ValType::i32(), ValType::i32()]),
    TExpr::new(instrs),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let (new_mod, _) = coalesce_locals().walk_module((), mod).unwrap()
  assert_true(
    new_mod.code_sec is Some(CodeSec([TFunc(_, locals, _)])) &&
    locals.length() == 1,
  )
}

///|
test "CFG liveness: nested ifs propagate interference correctly" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let instrs = [
    TInstr::if_(
      BlockType::void_(),
      TInstr::i32_const(I32(1)),
      TExpr::new([
        TInstr::if_(
          BlockType::void_(),
          TInstr::i32_const(I32(1)),
          TExpr::new([TInstr::local_set(x, TInstr::i32_const(I32(1)))]),
          Some(TExpr::new([TInstr::local_set(y, TInstr::i32_const(I32(2)))])),
        ),
      ]),
      None,
    ),
    TInstr::binary(
      BinaryOp::i32_add(),
      TInstr::local_get(x),
      TInstr::local_get(y),
    ),
  ]
  let locals = Locals::from_types([ValType::i32(), ValType::i32()])
  let blocks = build_cfg(instrs)
  let (inter, _, _, _) = compute_interferences_cfg(blocks, locals)
  assert_true(inter.contains(ordered_pair(x, y)))
}

///|
test "CFG liveness: local live across loop interferes" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let instrs = [
    TInstr::local_set(x, TInstr::i32_const(I32(1))),
    TInstr::loop_(
      BlockType::void_(),
      TExpr::new([
        TInstr::local_get(x),
        TInstr::local_set(y, TInstr::i32_const(I32(2))),
        TInstr::br(LabelIdx::new(0), []),
      ]),
    ),
    TInstr::local_get(y),
  ]
  let locals = Locals::from_types([ValType::i32(), ValType::i32()])
  let blocks = build_cfg(instrs)
  let (inter, _, _, _) = compute_interferences_cfg(blocks, locals)
  assert_true(inter.contains(ordered_pair(x, y)))
}

///|
test "CFG liveness: dead locals inside loop do not interfere" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let instrs = [
    TInstr::loop_(
      BlockType::void_(),
      TExpr::new([
        TInstr::local_set(x, TInstr::i32_const(I32(1))),
        TInstr::local_get(x),
      ]),
    ),
    TInstr::local_set(y, TInstr::i32_const(I32(2))),
    TInstr::local_get(y),
  ]
  let locals = Locals::from_types([ValType::i32(), ValType::i32()])
  let blocks = build_cfg(instrs)
  let (inter, _, _, _) = compute_interferences_cfg(blocks, locals)
  assert_true(!inter.contains(ordered_pair(x, y)))
}

///|
test "Copy-based coalescing eliminates local copy" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let instrs = [
    TInstr::local_set(x, TInstr::i32_const(I32(1))),
    TInstr::local_set(y, TInstr::local_get(x)),
    TInstr::local_get(y),
  ]
  let func = Func::t_func(
    [],
    Locals::from_types([ValType::i32(), ValType::i32()]),
    TExpr::new(instrs),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let (new_mod, _) = coalesce_locals().walk_module((), mod).unwrap()
  assert_true(
    new_mod.code_sec is Some(CodeSec([TFunc(_, locals, _)])) &&
    locals.length() == 1,
  )
}

///|
test "Copy-based coalescing respects interference" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let instrs = [
    TInstr::local_set(x, TInstr::i32_const(I32(1))),
    TInstr::local_set(y, TInstr::local_get(x)),
    TInstr::local_get(x),
    TInstr::local_get(y),
  ]
  let func = Func::t_func(
    [],
    Locals::from_types([ValType::i32(), ValType::i32()]),
    TExpr::new(instrs),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let (new_mod, _) = coalesce_locals().walk_module((), mod).unwrap()
  assert_true(
    new_mod.code_sec is Some(CodeSec([TFunc(_, locals, _)])) &&
    locals.length() == 2,
  )
}

///|
test "Value numbering: identical constant assignments coalesce" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let instrs = [
    TInstr::local_set(x, TInstr::i32_const(I32(42))),
    TInstr::local_set(y, TInstr::i32_const(I32(42))),
    TInstr::binary(
      BinaryOp::i32_add(),
      TInstr::local_get(x),
      TInstr::local_get(y),
    ),
  ]
  let func = Func::t_func(
    [],
    Locals::from_types([ValType::i32(), ValType::i32()]),
    TExpr::new(instrs),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let (new_mod, _) = coalesce_locals().walk_module((), mod).unwrap()

  // With value numbering, x and y can be coalesced
  assert_true(
    new_mod.code_sec is Some(CodeSec([TFunc(_, locals, _)])) &&
    locals.length() == 1,
  )
}

///|
test "Value numbering: different constants do not coalesce" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let instrs = [
    TInstr::local_set(x, TInstr::i32_const(I32(1))),
    TInstr::local_set(y, TInstr::i32_const(I32(2))),
    TInstr::binary(
      BinaryOp::i32_add(),
      TInstr::local_get(x),
      TInstr::local_get(y),
    ),
  ]
  let func = Func::t_func(
    [],
    Locals::from_types([ValType::i32(), ValType::i32()]),
    TExpr::new(instrs),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let (new_mod, _) = coalesce_locals().walk_module((), mod).unwrap()

  // Must not coalesce
  assert_true(
    new_mod.code_sec is Some(CodeSec([TFunc(_, locals, _)])) &&
    locals.length() == 2,
  )
}

///|
test "Value numbering: copy propagation enables coalescing" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let instrs = [
    TInstr::local_set(x, TInstr::i32_const(I32(7))),
    TInstr::local_set(y, TInstr::local_get(x)),
    TInstr::binary(
      BinaryOp::i32_add(),
      TInstr::local_get(x),
      TInstr::local_get(y),
    ),
  ]
  let func = Func::t_func(
    [],
    Locals::from_types([ValType::i32(), ValType::i32()]),
    TExpr::new(instrs),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let (new_mod, _) = coalesce_locals().walk_module((), mod).unwrap()
  // x and y hold same value → coalesce
  assert_true(
    new_mod.code_sec is Some(CodeSec([TFunc(_, locals, _)])) &&
    locals.length() == 1,
  )
}

///|
test "Value numbering: reassignment breaks equality" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let instrs = [
    TInstr::local_set(x, TInstr::i32_const(I32(7))),
    TInstr::local_set(y, TInstr::local_get(x)),
    TInstr::local_set(x, TInstr::i32_const(I32(8))),
    TInstr::binary(
      BinaryOp::i32_add(),
      TInstr::local_get(x),
      TInstr::local_get(y),
    ),
  ]
  let func = Func::t_func(
    [],
    Locals::from_types([ValType::i32(), ValType::i32()]),
    TExpr::new(instrs),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let (new_mod, _) = coalesce_locals().walk_module((), mod).unwrap()

  // x and y no longer equal
  assert_true(
    new_mod.code_sec is Some(CodeSec([TFunc(_, locals, _)])) &&
    locals.length() == 2,
  )
}

///|
test "Value numbering: equal values across branches do not coalesce" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let instrs = [
    TInstr::if_(
      BlockType::void_(),
      TInstr::i32_const(I32(1)),
      TExpr::new([TInstr::local_set(x, TInstr::i32_const(I32(1)))]),
      Some(TExpr::new([TInstr::local_set(y, TInstr::i32_const(I32(1)))])),
    ),
    TInstr::binary(
      BinaryOp::i32_add(),
      TInstr::local_get(x),
      TInstr::local_get(y),
    ),
  ]
  let func = Func::t_func(
    [],
    Locals::from_types([ValType::i32(), ValType::i32()]),
    TExpr::new(instrs),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let (new_mod, _) = coalesce_locals().walk_module((), mod).unwrap()
  assert_true(
    new_mod.code_sec is Some(CodeSec([TFunc(_, locals, _)])) &&
    locals.length() == 2,
  )
}

///|
test "CoalesceLocals: nested local use is rewritten when locals coalesce" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let instrs = [
    TInstr::local_set(y, TInstr::i32_const(I32(1))),
    TInstr::local_set(
      x,
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::local_get(y),
        TInstr::i32_const(I32(1)),
      ),
    ),
    TInstr::local_get(x),
  ]
  let func = Func::t_func(
    [],
    Locals::from_types([ValType::i32(), ValType::i32()]),
    TExpr::new(instrs),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let (new_mod, _) = coalesce_locals().walk_module((), mod).unwrap()
  assert_true(
    new_mod.code_sec is Some(CodeSec([TFunc(_, locals, body)])) &&
    locals.length() == 1 &&
    cl_max_local_used(body) == 0,
  )
}

///|
test "CoalesceLocals: imported functions do not shift param boundaries" {
  let imported_type = RecType::new(SubType::comp_type(CompType::func([], [])))
  let defined_type = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [])),
  )
  let p = LocalIdx::new(0)
  let x = LocalIdx::new(1)
  let y = LocalIdx::new(2)
  let body = TExpr::new([
    TInstr::local_set(x, TInstr::i32_const(I32(1))),
    TInstr::local_get(x),
    TInstr::local_set(y, TInstr::i32_const(I32(2))),
    TInstr::local_get(y),
    TInstr::drop(TInstr::local_get(p)),
  ])
  let func = Func::t_func(
    [],
    Locals::from_types([ValType::i32(), ValType::i32()]),
    body,
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([imported_type, defined_type]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("imp"),
          ExternType::func(TypeIdx::new(0)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_code_sec(CodeSec::new([func]))
  let pass = coalesce_locals(param_types=cl_collect_param_types(mod))
  let (new_mod, _) = pass.walk_module((), mod).unwrap()
  assert_true(
    new_mod.code_sec is Some(CodeSec([TFunc(_, locals, new_body)])) &&
    locals.length() == 1 &&
    cl_max_local_used(new_body) == 1,
  )
}

///|
test "CoalesceLocals: plain Func entries do not shift param boundaries" {
  let t0 = RecType::new(SubType::comp_type(CompType::func([], [])))
  let t1 = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0, t1]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::new(Locals::empty(), Expr::new([Instruction::nop()])),
        Func::t_func(
          [],
          Locals::empty(),
          TExpr::new([TInstr::drop(TInstr::local_get(LocalIdx::new(0)))]),
        ),
      ]),
    )
  let pass = coalesce_locals(param_types=cl_collect_param_types(mod))
  let result = pass.walk_module((), mod)
  let (out_mod, _) = match result {
    Ok(changed) => changed
    Err(e) => fail("unexpected coalesce_locals error: \{e}")
  }
  match out_mod.code_sec {
    Some(CodeSec([Func(_, _), TFunc(params, _, _)])) =>
      assert_eq(params, [ValType::i32()])
    _ => fail("expected second function to remain typed")
  }
}

///|
test "CoalesceLocals: mixed Func/TFunc keeps typed params when func_sec is stale" {
  let t0 = RecType::new(SubType::comp_type(CompType::func([], [])))
  let stale_t1 = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32(), ValType::i32()], [])),
  )
  let typed_params = [
    ValType::i32(),
    ValType::i32(),
    ValType::i32(),
    ValType::i32(),
  ]
  let t2 = RecType::new(SubType::comp_type(CompType::func(typed_params, [])))
  let body = TExpr::new([TInstr::drop(TInstr::local_get(LocalIdx::new(6)))])
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0, stale_t1, t2]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::new(Locals::empty(), Expr::new([Instruction::nop()])),
        Func::t_func(
          typed_params,
          Locals::from_types([ValType::i32(), ValType::i32(), ValType::i32()]),
          body,
        ),
      ]),
    )
  let pass = coalesce_locals(param_types=cl_collect_param_types(mod))
  let result = pass.walk_module((), mod)
  let (out_mod, _) = match result {
    Ok(changed) => changed
    Err(e) => fail("unexpected coalesce_locals error: \{e}")
  }
  match out_mod.code_sec {
    Some(CodeSec([Func(_, _), TFunc(params, locals, out_body)])) => {
      assert_eq(params.length(), 4)
      assert_true(
        cl_max_local_used(out_body) < params.length() + locals.length(),
      )
    }
    _ => fail("expected mixed code section with typed second function")
  }
}
