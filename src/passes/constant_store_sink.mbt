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
// Track all pending constant assignments in one forward scan. First reads
// consume their pending entry; writes and potentially trapping/throwing/control
// instructions invalidate it. Retain the assignment as a tee for every later
// read, including enclosing catches and structured releases. No repeated
// per-store suffix search or candidate-size threshold is needed.
fn sl_sink_constant_stores_flat(
  instrs : Array[@lib.Instruction],
  scan_visits? : Array[Int]? = None,
) -> (Array[@lib.Instruction], Int) {
  let mut pending : Map[Int, Int]? = None
  let mut sinks : Array[SlConstantStoreSink]? = None
  let mut last_barrier = -1
  for idx in 0..<instrs.length() {
    match scan_visits {
      Some(visits) => visits[0] += 1
      None => ()
    }
    match instrs[idx] {
      @lib.LocalGet(@lib.LocalIdx(raw)) =>
        if pending is Some(entries) {
          let local = raw.reinterpret_as_int()
          if entries.get(local) is Some(store) && store > last_barrier {
            let records = match sinks {
              Some(records) => records
              None => {
                let records : Array[SlConstantStoreSink] = []
                sinks = Some(records)
                records
              }
            }
            records.push(SlConstantStoreSink::new(store, idx))
            entries[local] = -1
          }
        }
      @lib.LocalSet(@lib.LocalIdx(raw)) => {
        let local = raw.reinterpret_as_int()
        if pending is Some(entries) && entries.get(local) is Some(_) {
          entries[local] = -1
        }
        if idx > 0 && sl_sinkable_numeric_constant(instrs[idx - 1]) {
          let entries = match pending {
            Some(entries) => entries
            None => {
              let entries : Map[Int, Int] = Map([])
              pending = Some(entries)
              entries
            }
          }
          entries[local] = idx
        }
      }
      @lib.LocalTee(@lib.LocalIdx(raw)) =>
        if pending is Some(entries) &&
          entries.get(raw.reinterpret_as_int()) is Some(_) {
          entries[raw.reinterpret_as_int()] = -1
        }
      instr =>
        if !sl_constant_store_prefix_is_nontrapping(instr) {
          // Store positions are epochs. Invalidating a whole prefix is O(1),
          // even after a wide row followed by many calls or other barriers.
          last_barrier = idx
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
