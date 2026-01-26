///|
type LocalMap = Map[LocalIdx, LocalIdx]

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
  is_loop_header : Bool
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
  match expr {
    // Constant literals: each literal gets its own value ID
    TI32Const(I32(n)) =>
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
    TI64Const(I64(n)) =>
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
    TF32Const(F32(f)) =>
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
    TF64Const(F64(f)) =>
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
    TInstr::TLocalGet(idx) => env.get(idx)

    // Anything else: fresh value
    _ => None
  }
}

///|
fn find_copies(instrs : Array[TInstr]) -> Set[(LocalIdx, LocalIdx)] {
  let copies = Set::new()
  for instr in instrs {
    match instr {
      TInstr::TLocalSet(dst, TInstr::TLocalGet(src)) if dst != src =>
        copies.add(ordered_pair(src, dst))
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
    match instr {
      TInstr::TLocalSet(idx, value) =>
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
  match instr {
    TBinary(_, lhs, rhs) => {
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
  locals : Array[ValType],
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
  match instr {
    TInstr::TLocalGet(idx) => result.add(idx)
    TInstr::TLocalSet(_, value) =>
      // value is evaluated in this block
      for x in uses(value) {
        result.add(x)
      }
    TInstr::TIf(_, cond, _, _) =>
      // only condition belongs to this block
      for x in uses(cond) {
        result.add(x)
      }
    TInstr::TLoop(_, body) =>
      for b in body.0 {
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
  match instr {
    TInstr::TLocalSet(idx, _) => result.add(idx)
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
    match instr {
      TInstr::TLocalSet(idx, value) =>
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
  locals : Array[ValType],
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
  locals : Array[ValType],
) -> (Set[(LocalIdx, LocalIdx)], Map[Int, ValueEnv], Map[Int, ValueEnv]) {
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
  (inter, values_in, values_out)
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
      is_loop_header: false,
    }
    next_id = next_id + 1
    b
  }

  let mut current = new_block()
  blocks.push(current)
  for instr in instrs {
    match instr {

      // if creates two successors + merge
      TInstr::TIf(_, _, then_expr, else_expr) => {
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
        then_block.instrs.append(then_expr.0)
        if else_expr is Some(e) {
          else_block.instrs.append(e.0)
        }
        blocks.push(then_block)
        blocks.push(else_block)
        blocks.push(merge_block)
        current = merge_block
      }

      // loop introduces backedge
      TInstr::TLoop(_, body) => {
        current.instrs.push(instr)
        let loop_body = Block::{ ..new_block(), is_loop_header: true }
        let after_loop = new_block()
        current.succs.push(loop_body.id)
        loop_body.preds.push(current.id)
        loop_body.instrs.append(body.0)

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
  locals : Array[ValType],
  inter : Set[(LocalIdx, LocalIdx)],
  order : Array[LocalIdx],
  blocks : Array[Block],
  values_out : Map[Int, ValueEnv],
  liveness : Map[Int, BlockLiveness],
) -> LocalMap {
  let mapping : LocalMap = Map::new()
  let reps : Array[LocalIdx] = Array::new()
  for li in order {
    let ty_i = locals[li.0.reinterpret_as_int()]
    let mut assigned = false
    for r in reps {
      if ty_i != locals[r.0.reinterpret_as_int()] {
        continue
      }

      // TRUST the interference graph.
      // If they are in the set, they overlap with different values
      // or they are a copy where the source remained live.
      if !interferes(inter, li, r) ||
        must_be_same_value(li, r, blocks, values_out, liveness) {
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
fn coalesce_locals() -> ModuleTransformer[Unit] {
  ModuleTransformer::new()
    .on_func_evt(fn(_, _, func) {
      match func {
        Func(_) => unchanged()
        TFunc(locals, body) => {
          let instrs = body.0
          let blocks = build_cfg(instrs)
          let (inter, _, values_out) = compute_interferences_cfg(blocks, locals)
          let liveness = compute_cfg_liveness(build_cfg(instrs))
          let copies = find_copies(instrs)
          let freq = copy_frequency(copies)
          let order = compute_coalesce_order(locals, freq)
          let mapping = compute_coalescing(
            locals, inter, order, blocks, values_out, liveness,
          )
          let (new_locals, rep_to_new) = compute_new_locals(locals, mapping)
          let final_map = compose_maps(mapping, rep_to_new)
          let new_body = rewrite_body_locals(body, final_map)
          change((), Func::t_func(new_locals, new_body))
        }
      }
    })
}

///|
fn rewrite_instr_locals(instr : TInstr, mapping : LocalMap) -> TInstr {
  let walker = ModuleTransformer::new()
    .on_tinstruction_evt(fn(_, _, i) {
      match i {
        TInstr::TLocalGet(idx) =>
          change((), TInstr::local_get(mapping.get(idx).unwrap()))
        TInstr::TLocalSet(idx, value) =>
          change((), TInstr::local_set(mapping.get(idx).unwrap(), value))
        TInstr::TLocalTee(idx, value) =>
          change((), TInstr::local_tee(mapping.get(idx).unwrap(), value))
        _ => unchanged()
      }
    })
  let (_, expr) = walker
    .walk_texpr_default((), TExpr::new([instr]))
    .unwrap()
    .unwrap()
  let TExpr(instrs) = expr
  if instrs.length() == 1 {
    instrs[0]
  } else {
    // conservative fallback
    instr
  }
}

///|
fn rewrite_body_locals(body : TExpr, mapping : LocalMap) -> TExpr {
  let TExpr(instrs) = body
  let new_instrs = Array::new()
  for instr in instrs {
    new_instrs.push(rewrite_instr_locals(instr, mapping))
  }
  TExpr::new(new_instrs)
}

///|
fn compute_new_locals(
  locals : Array[ValType],
  mapping : LocalMap,
) -> (Array[ValType], Map[LocalIdx, LocalIdx]) {
  let new_locals = Array::new()
  let rep_to_new = Map::new()
  for i in 0..<locals.length() {
    let old_idx = LocalIdx::new(i.reinterpret_as_uint())
    let rep = mapping.get(old_idx).unwrap()
    if !rep_to_new.contains(rep) {
      let new_idx = LocalIdx::new(new_locals.length().reinterpret_as_uint())
      rep_to_new[rep] = new_idx
      new_locals.push(locals[i])
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
    fin[old] = rep_to_new.get(rep).unwrap()
  }
  fin
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
  locals : Array[ValType],
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
  let locals = [ValType::i32(), ValType::i32()]
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
  let locals = [ValType::i32(), ValType::i32()]
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
  let func = Func::t_func([ValType::i32(), ValType::i32()], TExpr::new(instrs))
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let pass = coalesce_locals()
  let (_, new_module) = pass.walk_module((), mod).unwrap().unwrap()

  // After coalescing, only one local remains
  assert_true(
    new_module.code_sec is Some(CodeSec([new_func])) &&
    new_func is TFunc(locals, _) &&
    locals.length() == 1,
  )
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
  let func = Func::t_func([ValType::i32(), ValType::f32()], TExpr::new(instrs))
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let (_, new_mod) = coalesce_locals().walk_module((), mod).unwrap().unwrap()
  assert_true(
    new_mod.code_sec is Some(CodeSec([TFunc(locals, _)])) &&
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
  let func = Func::t_func([ValType::i32(), ValType::i32()], TExpr::new(instrs))
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let (_, new_mod) = coalesce_locals().walk_module((), mod).unwrap().unwrap()
  assert_true(
    new_mod.code_sec is Some(CodeSec([TFunc(locals, _)])) &&
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
  let locals = [ValType::i32(), ValType::i32()]
  let blocks = build_cfg(instrs)
  let (inter, _, _) = compute_interferences_cfg(blocks, locals)
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
  let locals = [ValType::i32(), ValType::i32()]
  let blocks = build_cfg(instrs)
  let (inter, _, _) = compute_interferences_cfg(blocks, locals)
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
  let locals = [ValType::i32(), ValType::i32()]
  let blocks = build_cfg(instrs)
  let (inter, _, _) = compute_interferences_cfg(blocks, locals)
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
  let func = Func::t_func([ValType::i32(), ValType::i32()], TExpr::new(instrs))
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let (_, new_mod) = coalesce_locals().walk_module((), mod).unwrap().unwrap()
  assert_true(
    new_mod.code_sec is Some(CodeSec([TFunc(locals, _)])) &&
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
  let func = Func::t_func([ValType::i32(), ValType::i32()], TExpr::new(instrs))
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let (_, new_mod) = coalesce_locals().walk_module((), mod).unwrap().unwrap()
  assert_true(
    new_mod.code_sec is Some(CodeSec([TFunc(locals, _)])) &&
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
  let locals = [ValType::i32(), ValType::i32()]
  let blocks = build_cfg(instrs)
  let (inter, _, _) = compute_interferences_cfg(blocks, locals)
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
  let locals = [ValType::i32(), ValType::i32()]
  let blocks = build_cfg(instrs)
  let (inter, _, _) = compute_interferences_cfg(blocks, locals)
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
  let locals = [ValType::i32(), ValType::i32()]
  let blocks = build_cfg(instrs)
  let (inter, _, _) = compute_interferences_cfg(blocks, locals)
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
  let func = Func::t_func([ValType::i32(), ValType::i32()], TExpr::new(instrs))
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let (_, new_mod) = coalesce_locals().walk_module((), mod).unwrap().unwrap()
  assert_true(
    new_mod.code_sec is Some(CodeSec([TFunc(locals, _)])) &&
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
  let func = Func::t_func([ValType::i32(), ValType::i32()], TExpr::new(instrs))
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let (_, new_mod) = coalesce_locals().walk_module((), mod).unwrap().unwrap()
  assert_true(
    new_mod.code_sec is Some(CodeSec([TFunc(locals, _)])) &&
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
  let func = Func::t_func([ValType::i32(), ValType::i32()], TExpr::new(instrs))
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let (_, new_mod) = coalesce_locals().walk_module((), mod).unwrap().unwrap()

  // With value numbering, x and y can be coalesced
  assert_true(
    new_mod.code_sec is Some(CodeSec([TFunc(locals, _)])) &&
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
  let func = Func::t_func([ValType::i32(), ValType::i32()], TExpr::new(instrs))
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let (_, new_mod) = coalesce_locals().walk_module((), mod).unwrap().unwrap()

  // Must not coalesce
  assert_true(
    new_mod.code_sec is Some(CodeSec([TFunc(locals, _)])) &&
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
  let func = Func::t_func([ValType::i32(), ValType::i32()], TExpr::new(instrs))
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let (_, new_mod) = coalesce_locals().walk_module((), mod).unwrap().unwrap()
  // x and y hold same value → coalesce
  assert_true(
    new_mod.code_sec is Some(CodeSec([TFunc(locals, _)])) &&
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
  let func = Func::t_func([ValType::i32(), ValType::i32()], TExpr::new(instrs))
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let (_, new_mod) = coalesce_locals().walk_module((), mod).unwrap().unwrap()

  // x and y no longer equal
  assert_true(
    new_mod.code_sec is Some(CodeSec([TFunc(locals, _)])) &&
    locals.length() == 2,
  )
}

///|
test "Value numbering: equal values across branches coalesce" {
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
  let func = Func::t_func([ValType::i32(), ValType::i32()], TExpr::new(instrs))
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let (_, new_mod) = coalesce_locals().walk_module((), mod).unwrap().unwrap()
  assert_true(
    new_mod.code_sec is Some(CodeSec([TFunc(locals, _)])) &&
    locals.length() == 1,
  )
}
