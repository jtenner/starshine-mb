// Licensing scope: see ../../LICENSE and this directory's LICENSE and NOTICE.
// Original Starshine contributions use the scoped MIT grant in ../../LICENSE.

///|
priv struct CLCopyForwardScopedTarget {
  target : Int32
  instrs : Array[@lib.Instruction]
}

///|
priv struct CLCopyForwardFacts {
  valid : Array[Bool]
  targets : Array[Array[Int32]]
  scoped_targets : Array[Array[CLCopyForwardScopedTarget]]
  forbidden : Array[@bitset.BitSet?]
  memo_stamps : Array[Int32]
  memo_values : Array[Bool]
  mut epoch : Int32
}

///|
fn cl_copy_forward_pending_remove(
  pending : Array[Int32],
  positions : Array[Int32],
  local : Int32,
) -> Unit {
  let pos = positions[local]
  if pos < 0 {
    return
  }
  let last = pending.pop().unwrap()
  if last != local {
    pending[pos] = last
    positions[last] = pos
  }
  positions[local] = -1
}

///|
fn CLCopyForwardFacts::invalidate(
  self : CLCopyForwardFacts,
  pending : Array[Int32],
  positions : Array[Int32],
  local : Int32,
) -> Unit {
  self.valid[local] = false
  self.targets[local].clear()
  self.scoped_targets[local].clear()
  self.forbidden[local] = None
  cl_copy_forward_pending_remove(pending, positions, local)
}

///|
fn CLCopyForwardFacts::finish_region(
  self : CLCopyForwardFacts,
  pending : Array[Int32],
  positions : Array[Int32],
) -> Unit {
  while pending.length() > 0 {
    self.invalidate(pending, positions, pending[pending.length() - 1])
  }
}

///|
fn CLCopyForwardFacts::scan(
  self : CLCopyForwardFacts,
  instrs : Array[@lib.Instruction],
  pending : Array[Int32],
  positions : Array[Int32],
  scoped~ : Bool = false,
) -> Unit {
  let total = self.valid.length()
  for idx in 0..<instrs.length() {
    let instr = instrs[idx]
    match instr {
      @lib.Block(_, @lib.Expr(body)) => {
        self.finish_region(pending, positions)
        self.scan(body, pending, positions, scoped=true)
      }
      @lib.If(_, then_body, else_body) => {
        self.finish_region(pending, positions)
        self.scan(then_body, pending, positions, scoped=true)
        if else_body is Some(body) {
          self.scan(body, pending, positions, scoped=true)
        }
      }
      @lib.LocalGet(local_idx)
      | @lib.LocalSet(local_idx)
      | @lib.LocalTee(local_idx) => {
        let local = cl_local_idx_raw(local_idx)
        if local < 0 || local >= total {
          continue
        }
        // Only live pending writes need a destination hazard. Invalid sources
        // release their rows immediately; rows are allocated only on demand.
        for source in pending {
          if source == local {
            continue
          }
          let row = match self.forbidden[source] {
            Some(row) => row
            None => {
              let row = @bitset.BitSet::new(total)
              self.forbidden[source] = Some(row)
              row
            }
          }
          row[local] = true
        }
        if !self.valid[local] {
          continue
        }
        match instr {
          @lib.LocalGet(_) => {
            let target = if idx + 1 < instrs.length() {
              match instrs[idx + 1] {
                @lib.LocalSet(target) | @lib.LocalTee(target) =>
                  cl_local_idx_raw(target)
                _ => -1
              }
            } else {
              -1
            }
            if positions[local] < 0 ||
              target < 0 ||
              target >= total ||
              target == local {
              self.invalidate(pending, positions, local)
            } else {
              cl_copy_forward_pending_remove(pending, positions, local)
              if scoped {
                self.scoped_targets[local].push({ target, instrs, })
              } else {
                self.targets[local].push(target)
              }
            }
          }
          _ =>
            if positions[local] >= 0 {
              self.invalidate(pending, positions, local)
            } else {
              positions[local] = pending.length()
              pending.push(local)
            }
        }
      }
      // The caller proves the same global barrier exclusion as the original
      // pair scanner. Other instruction kinds do not affect its local state.
      _ => ()
    }
  }
  self.finish_region(pending, positions)
}

///|
fn cl_copy_forward_write_balances(
  instrs : Array[@lib.Instruction],
  balances : Array[Int32],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.LocalGet(local_idx) => {
        let local = cl_local_idx_raw(local_idx)
        if local >= 0 && local < balances.length() {
          balances[local] -= 1
        }
      }
      @lib.LocalSet(local_idx) | @lib.LocalTee(local_idx) => {
        let local = cl_local_idx_raw(local_idx)
        if local >= 0 && local < balances.length() {
          balances[local] += 1
        }
      }
      @lib.Block(_, @lib.Expr(body)) =>
        cl_copy_forward_write_balances(body, balances)
      @lib.If(_, then_body, else_body) => {
        cl_copy_forward_write_balances(then_body, balances)
        if else_body is Some(body) {
          cl_copy_forward_write_balances(body, balances)
        }
      }
      // Match the original pair scanner's exact instruction scope.
      _ => ()
    }
  }
}

///|
fn cl_copy_forward_facts(
  instrs : Array[@lib.Instruction],
  total : Int32,
) -> CLCopyForwardFacts {
  // Every source write must have exactly one consuming read in its region.
  // Unequal totals are already an impossible proof. Exclude those locals
  // before tracking pending writes, which avoids quadratic destination rows
  // for write-only temporary locals.
  let balances = Array::make(total, 0)
  cl_copy_forward_write_balances(instrs, balances)
  let facts : CLCopyForwardFacts = {
    valid: Array::makei(total, fn(local) { balances[local] == 0 }),
    targets: Array::makei(total, fn(_) { [] }),
    scoped_targets: Array::makei(total, fn(_) { [] }),
    forbidden: Array::make(total, None),
    memo_stamps: Array::make(total * 5, 0),
    memo_values: Array::make(total * 5, false),
    epoch: 0,
  }
  facts.scan(instrs, [], Array::make(total, -1))
  for targets in facts.targets {
    targets.sort()
    let mut unique = 0
    for idx in 0..<targets.length() {
      if unique == 0 || targets[idx] != targets[unique - 1] {
        targets[unique] = targets[idx]
        unique += 1
      }
    }
    while targets.length() > unique {
      ignore(targets.pop())
    }
  }
  facts
}

///|
fn CLCopyForwardFacts::pair_safe(
  self : CLCopyForwardFacts,
  source : Int32,
  dest : Int32,
  depth : Int32,
) -> Bool {
  if source < 0 || source >= self.valid.length() || !self.valid[source] {
    return false
  }
  let key = depth * self.valid.length() + source
  if self.memo_stamps[key] == self.epoch {
    return self.memo_values[key]
  }
  let mut safe = match self.forbidden[source] {
    Some(row) => !row[dest]
    None => true
  }
  if safe {
    for target in self.targets[source] {
      if target != dest &&
        (
          target == source ||
          depth <= 0 ||
          !self.pair_safe(target, dest, depth - 1)
        ) {
        safe = false
        break
      }
    }
  }
  if safe {
    for scoped in self.scoped_targets[source] {
      // The original recursive proof reads the current Block/If arm only.
      // A target can have unrelated writes elsewhere in the function. Keep
      // this uncommon transitive case in its original scope, without a
      // locals-sized facts allocation for every nested control frame.
      if !cl_copy_forward_target_reaches_dest(
          scoped.instrs,
          source,
          scoped.target,
          dest,
          depth,
        ) {
        safe = false
        break
      }
    }
  }
  self.memo_stamps[key] = self.epoch
  self.memo_values[key] = safe
  safe
}

///|
fn cl_remove_safe_copy_forward_interferences_indexed(
  instrs : Array[@lib.Instruction],
  types : Array[@lib.ValType],
  param_count : Int32,
  interferences : CLBitMatrix,
  weights : CLCopyWeights,
) -> Unit {
  if !weights.rows.any(fn(row) { row.length() > 0 }) ||
    cl_pair_forward_scans_have_global_barrier(instrs) {
    return
  }
  let facts = cl_copy_forward_facts(instrs, types.length())
  let marks = Array::make(types.length(), 0)
  let pending : Array[Int32] = []
  let depths : Array[Int32] = []
  // Copy weights are symmetric. Reverse the candidate iteration so every
  // proof for one destination shares a bounded-depth memo table, not a body
  // walk. This preserves the original monotone interference removals.
  for dest in 0..<types.length() {
    if weights.rows[dest].length() == 0 {
      continue
    }
    facts.epoch += 1
    let epoch = dest + 1
    pending.clear()
    depths.clear()
    pending.push(dest)
    depths.push(0)
    marks[dest] = epoch
    let mut cursor = 0
    while cursor < pending.length() {
      let source = pending[cursor]
      let depth = depths[cursor]
      cursor += 1
      if source != dest &&
        source >= param_count &&
        types[source] == types[dest] &&
        facts.pair_safe(source, dest, 4) {
        cl_bit_matrix_set_symmetric(interferences, source, dest, false)
      }
      // A dense component can enqueue every local from its first row. Keep
      // proving queued pairs, but do not rescan edges that cannot add a node.
      if depth >= 4 || pending.length() == types.length() {
        continue
      }
      for edge in weights.rows[source] {
        let (next, _) = edge
        if marks[next] != epoch {
          marks[next] = epoch
          pending.push(next)
          depths.push(depth + 1)
        }
      }
    }
  }
}
