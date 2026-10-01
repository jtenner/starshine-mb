///|
// Frozen V73 pending-map implementation for equal-feature native controls.
fn sl_constant_sink_map_reference(
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
