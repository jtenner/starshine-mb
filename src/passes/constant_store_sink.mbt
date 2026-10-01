///|
#valtype
priv struct SlConstantStoreSink {
  store : Int
  read : Int
}

///|
fn SlConstantStoreSink::new(store : Int, read : Int) -> SlConstantStoreSink {
  { store, read, }
}

///|
fn sl_sinkable_numeric_constant(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.I32Const(_) | @lib.I64Const(_) | @lib.F32Const(_) | @lib.F64Const(_) =>
      true
    _ => false
  }
}

///|
fn sl_constant_store_prefix_is_nontrapping(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.Nop | @lib.Drop => true
    _ =>
      if sl_sinkable_numeric_constant(instr) {
        true
      } else {
        // Reuse the existing nontrapping operand classifier. Exclude other
        // zero-input leaves; this lane only crosses arithmetic/selection here.
        match run_hot_pipeline_raw_vacuum_pure_instr_operand_count(instr) {
          Some(inputs) => inputs > 0
          None => false
        }
      }
  }
}

///|
fn sl_constant_pending_get(
  dense : Array[Int]?,
  sparse : Map[Int, Int]?,
  local : Int,
) -> Int {
  match dense {
    Some(row) =>
      if local >= 0 && local < row.length() {
        row[local]
      } else {
        -1
      }
    None => sparse.unwrap().get(local).unwrap_or(-1)
  }
}

///|
fn sl_constant_pending_set(
  dense : Array[Int]?,
  sparse : Map[Int, Int]?,
  local : Int,
  store : Int,
) -> Unit {
  match dense {
    Some(row) => row[local] = store
    None => sparse.unwrap()[local] = store
  }
}

///|
// Track all pending constant assignments in one forward scan after a cheap
// candidate-only census. Dense storage is capped at 4096 Int slots and at eight
// slots per candidate; sparse/high-index bodies retain the map. The choice never
// limits rewrites. First reads consume entries; writes and trapping/throwing/
// control instructions invalidate them. Retain each assignment as a tee for
// later reads, including enclosing catches and structured releases.
fn sl_sink_constant_stores_flat(
  instrs : Array[@lib.Instruction],
  scan_visits? : Array[Int]? = None,
) -> (Array[@lib.Instruction], Int) {
  let mut candidates = 0
  let mut max_local = -1
  let mut nonnegative = true
  for idx in 0..<instrs.length() {
    match scan_visits {
      Some(visits) => visits[0] += 1
      None => ()
    }
    if instrs[idx] is @lib.LocalSet(@lib.LocalIdx(raw)) &&
      idx > 0 &&
      sl_sinkable_numeric_constant(instrs[idx - 1]) {
      candidates += 1
      let local = raw.reinterpret_as_int()
      nonnegative = nonnegative && local >= 0
      max_local = Int::max(max_local, local)
    }
  }
  if candidates == 0 {
    return (instrs, 0)
  }
  let use_dense = nonnegative &&
    max_local < 4096 &&
    (max_local + 8) / 8 <= candidates
  let dense = if use_dense {
    Some(Array::make(max_local + 1, -1))
  } else {
    None
  }
  let sparse : Map[Int, Int]? = if use_dense { None } else { Some(Map([])) }
  let mut sinks : Array[SlConstantStoreSink]? = None
  let mut last_barrier = -1
  let mut active = 0
  for idx in 0..<instrs.length() {
    match scan_visits {
      Some(visits) => visits[0] += 1
      None => ()
    }
    match instrs[idx] {
      @lib.LocalGet(@lib.LocalIdx(raw)) => {
        if active == 0 {
          continue
        }
        let local = raw.reinterpret_as_int()
        let store = sl_constant_pending_get(dense, sparse, local)
        if store > last_barrier {
          let records = match sinks {
            Some(records) => records
            None => {
              let records : Array[SlConstantStoreSink] = []
              sinks = Some(records)
              records
            }
          }
          records.push(SlConstantStoreSink::new(store, idx))
          sl_constant_pending_set(dense, sparse, local, -1)
          active -= 1
        }
      }
      @lib.LocalSet(@lib.LocalIdx(raw)) => {
        let local = raw.reinterpret_as_int()
        if active > 0 &&
          sl_constant_pending_get(dense, sparse, local) > last_barrier {
          sl_constant_pending_set(dense, sparse, local, -1)
          active -= 1
        }
        if idx > 0 && sl_sinkable_numeric_constant(instrs[idx - 1]) {
          sl_constant_pending_set(dense, sparse, local, idx)
          active += 1
        }
      }
      @lib.LocalTee(@lib.LocalIdx(raw)) => {
        if active == 0 {
          continue
        }
        let local = raw.reinterpret_as_int()
        if sl_constant_pending_get(dense, sparse, local) > last_barrier {
          sl_constant_pending_set(dense, sparse, local, -1)
          active -= 1
        }
      }
      instr =>
        if active > 0 && !sl_constant_store_prefix_is_nontrapping(instr) {
          // Store positions are epochs: invalidate the whole prefix in O(1).
          last_barrier = idx
          active = 0
        }
    }
  }
  let sinks = match sinks {
    Some(records) => records
    None => return (instrs, 0)
  }
  // One compact splice row: -1 keeps the original instruction, -2 deletes a
  // producer/store, and a nonnegative value selects the moved constant.
  let changes = Array::make(instrs.length(), -1)
  for sink in sinks {
    changes[sink.store - 1] = -2
    changes[sink.store] = -2
    changes[sink.read] = sink.store - 1
  }
  let rewritten : Array[@lib.Instruction] = Array(
    capacity=instrs.length() - sinks.length(),
  )
  for idx in 0..<instrs.length() {
    match scan_visits {
      Some(visits) => visits[0] += 1
      None => ()
    }
    if changes[idx] >= 0 {
      rewritten.push(instrs[changes[idx]])
      let local = match instrs[idx] {
        @lib.LocalGet(local) => local
        _ => abort("constant sink requires a first local read")
      }
      rewritten.push(@lib.Instruction::local_tee(local))
    } else if changes[idx] != -2 {
      rewritten.push(instrs[idx])
    }
  }
  (rewritten, sinks.length())
}

///|
fn sl_sink_constant_stores(
  instrs : Array[@lib.Instruction],
) -> (Array[@lib.Instruction], Int) {
  let mut normalized = instrs
  let mut nested_count = 0
  for idx in 0..<instrs.length() {
    let (replacement, count) = match instrs[idx] {
      @lib.Block(bt, @lib.Expr(body)) => {
        let (next, count) = sl_sink_constant_stores(body)
        if count == 0 {
          continue
        }
        (@lib.Instruction::block(bt, @lib.Expr::new(next)), count)
      }
      @lib.Loop(bt, @lib.Expr(body)) => {
        let (next, count) = sl_sink_constant_stores(body)
        if count == 0 {
          continue
        }
        (@lib.Instruction::loop_(bt, @lib.Expr::new(next)), count)
      }
      @lib.TryTable(bt, catches, @lib.Expr(body)) => {
        let (next, count) = sl_sink_constant_stores(body)
        if count == 0 {
          continue
        }
        (@lib.Instruction::try_table(bt, catches, @lib.Expr::new(next)), count)
      }
      @lib.If(bt, yes, no) => {
        let (next_yes, yes_count) = sl_sink_constant_stores(yes)
        let (next_no, no_count) = match no {
          Some(body) => {
            let (next, count) = sl_sink_constant_stores(body)
            (Some(next), count)
          }
          None => (None, 0)
        }
        let count = yes_count + no_count
        if count == 0 {
          continue
        }
        (@lib.Instruction::if_(bt, next_yes, next_no), count)
      }
      // Legacy handlers stay opaque here; their read/write facts remain in the
      // surrounding cleanup. Do not move an outer assignment across a try.
      _ => continue
    }
    if count > 0 {
      if nested_count == 0 {
        normalized = instrs.copy()
      }
      normalized[idx] = replacement
      nested_count += count
    }
  }
  let (rewritten, flat_count) = sl_sink_constant_stores_flat(normalized)
  (rewritten, nested_count + flat_count)
}
