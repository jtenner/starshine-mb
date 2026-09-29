///|
// A qualified scalar stack slot has one consumer. Keep original instruction
// order while projecting that stack onto demanded values. Observable producers
// still run; unused retained results are dropped at their production point.
fn dae2_rewrite_raw_function(
  module_graph : Dae2Graph,
  infos : Array[Dae2Function],
  index : Int,
  original : @lib.Func,
  context : @ir.HotModuleContext,
  kept_params : Array[@lib.ValType],
  removed_params : Array[@lib.ValType],
) -> (@lib.Func, Array[Int])? {
  let info = infos[index]
  if !info.raw_analysis || info.results.length() > 1 {
    return None
  }
  let @lib.Func(locals, @lib.Expr(original_instructions)) = original
  let instructions = match
    dae2_raw_branchless_instructions(original_instructions) {
    Some(instructions) => instructions
    None => return None
  }
  // Reject unsupported mutation shapes before allocating expression data.
  for instr in instructions {
    match instr {
      @lib.CallIndirect(_, _) | @lib.CallRef(_) => return None
      @lib.Call(@lib.FuncIdx(raw)) => {
        let callee = raw.reinterpret_as_int()
        if callee < 0 ||
          callee >= infos.length() ||
          infos[callee].results.length() > 1 {
          return None
        }
      }
      _ => ()
    }
  }
  let graph = Dae2Graph::new()
  ignore(graph.locations(instructions.length()))
  let kinds = Array::make(instructions.length(), -1)
  let stack : Array[Int] = []
  let definitions = Array::make(info.params.length() + locals.length(), -1)
  let mut tee_writes : Array[Int]? = None
  for position in 0..<instructions.length() {
    let instr = instructions[position]
    let pure = dae2_raw_pure_arity(instr)
    let observer = dae2_raw_observer_arity(instr)
    let producer = dae2_raw_observed_producer_arity(instr, Some(context))
    let (kind, consumed, produced) = if pure >= 0 {
      (
        if instr is @lib.MemorySize(_) || instr is @lib.TableSize(_) {
          2
        } else {
          0
        },
        pure,
        1,
      )
    } else if observer >= 0 {
      (1, observer, 0)
    } else if producer >= 0 {
      (2, producer, 1)
    } else {
      match instr {
        @lib.LocalSet(_) => (3, 1, 0)
        @lib.LocalTee(_) => (8, 1, 1)
        @lib.Call(@lib.FuncIdx(raw)) => {
          let callee = infos[raw.reinterpret_as_int()]
          (4, callee.params.length(), callee.results.length())
        }
        @lib.Drop => (5, 1, 0)
        @lib.Return if position == instructions.length() - 1 =>
          (6, info.results.length(), 0)
        @lib.Nop => (7, 0, 0)
        _ => return None
      }
    }
    if stack.length() < consumed {
      return None
    }
    let start = stack.length() - consumed
    kinds[position] = kind
    match kind {
      0 | 3 | 8 => {
        for slot in start..<stack.length() {
          graph.edge(position, stack[slot])
        }
        match instr {
          @lib.LocalGet(@lib.LocalIdx(raw)) => {
            let local = raw.reinterpret_as_int()
            if local < 0 || local >= definitions.length() {
              return None
            }
            graph.edge(position, definitions[local])
          }
          @lib.LocalSet(@lib.LocalIdx(raw)) => {
            let local = raw.reinterpret_as_int()
            if local < 0 || local >= definitions.length() {
              return None
            }
            definitions[local] = position
          }
          @lib.LocalTee(@lib.LocalIdx(raw)) => {
            let local = raw.reinterpret_as_int()
            if local < 0 || local >= definitions.length() {
              return None
            }
            // The write can be demanded by a later get even when the tee's
            // original stack value is discarded. Keep those demands separate
            // so each original stack slot is projected exactly once.
            let writes = match tee_writes {
              Some(writes) => writes
              None => {
                let writes = Array::make(instructions.length(), -1)
                tee_writes = Some(writes)
                writes
              }
            }
            let write = graph.location()
            graph.edge(write, stack[start])
            writes[position] = write
            definitions[local] = write
          }
          _ => ()
        }
      }
      1 | 2 =>
        for slot in start..<stack.length() {
          graph.observe(stack[slot])
        }
      4 => {
        let raw = match instr {
          @lib.Call(@lib.FuncIdx(raw)) => raw
          _ => return None
        }
        let callee = infos[raw.reinterpret_as_int()]
        for arg in 0..<callee.params.length() {
          if module_graph.used[callee.param_locations[arg]] {
            graph.observe(stack[start + arg])
          }
        }
      }
      5 => graph.edge(position, stack[start])
      6 => {
        if start != 0 {
          return None
        }
        if module_graph.used[info.result_location] {
          for slot in start..<stack.length() {
            graph.observe(stack[slot])
          }
        }
      }
      _ => ()
    }
    stack.truncate(start)
    if produced == 1 {
      stack.push(position)
    }
  }
  if instructions.last() is Some(@lib.Return) {
    if !stack.is_empty() {
      return None
    }
  } else {
    if stack.length() != info.results.length() {
      return None
    }
    if module_graph.used[info.result_location] {
      for value in stack {
        graph.observe(value)
      }
    }
  }
  graph.solve()
  // HOT lowering removes local.tee writes only when no emitted local.get
  // reads that slot. Reuse the finished definition row for these read facts;
  // a read before an overwrite still keeps the original tee shape.
  if tee_writes is Some(_) {
    for local in 0..<definitions.length() {
      definitions[local] = 0
    }
    for position in 0..<instructions.length() {
      if graph.used[position] {
        match instructions[position] {
          @lib.LocalGet(@lib.LocalIdx(raw)) =>
            definitions[raw.reinterpret_as_int()] = 1
          _ => ()
        }
      }
    }
  }
  let local_map = Array::make(info.params.length() + locals.length(), -1)
  let mut kept = 0
  let mut removed = 0
  for param in 0..<info.params.length() {
    if module_graph.used[info.param_locations[param]] {
      local_map[param] = kept
      kept += 1
    } else {
      if !@lib.has_default(info.params[param]) {
        return None
      }
      local_map[param] = kept_params.length() +
        locals.length() +
        removed_params.length() -
        1 -
        removed
      removed += 1
    }
  }
  for local in 0..<locals.length() {
    local_map[info.params.length() + local] = kept_params.length() + local
  }
  let out : Array[@lib.Instruction] = []
  for position in 0..<instructions.length() {
    let instr = instructions[position]
    let used = graph.used[position]
    match kinds[position] {
      0 | 3 =>
        if used {
          match instr {
            @lib.LocalGet(@lib.LocalIdx(raw)) => {
              let local = raw.reinterpret_as_int()
              if local < info.params.length() &&
                !module_graph.used[info.param_locations[local]] &&
                graph.first_edge[position] < 0 {
                return None
              }
              out.push(
                @lib.Instruction::local_get(
                  @lib.LocalIdx::new(local_map[local].to_uint()),
                ),
              )
            }
            @lib.LocalSet(@lib.LocalIdx(raw)) =>
              out.push(
                @lib.Instruction::local_set(
                  @lib.LocalIdx::new(
                    local_map[raw.reinterpret_as_int()].to_uint(),
                  ),
                ),
              )
            _ => out.push(instr)
          }
        }
      1 | 6 => out.push(instr)
      2 => {
        out.push(instr)
        if !used {
          out.push(@lib.Instruction::drop())
        }
      }
      4 => {
        let raw = match instr {
          @lib.Call(@lib.FuncIdx(raw)) => raw
          _ => return None
        }
        let callee = infos[raw.reinterpret_as_int()]
        let retains_result = !callee.results.is_empty() &&
          module_graph.used[callee.result_location]
        if used && !retains_result {
          return None
        }
        out.push(instr)
        if retains_result && !used {
          out.push(@lib.Instruction::drop())
        }
      }
      5 => {
        let edge = graph.first_edge[position]
        if edge < 0 || graph.used[graph.edges[edge]] {
          return None
        }
      }
      8 => {
        let write = match tee_writes {
          Some(writes) => writes[position]
          None => return None
        }
        let local = match instr {
          @lib.LocalTee(@lib.LocalIdx(raw)) => raw.reinterpret_as_int()
          _ => return None
        }
        // Match hot_lower_impl_prune_dead_local_tees_in_body using emitted
        // reads, independently of whether this particular write reaches one.
        if graph.used[write] || (used && definitions[local] != 0) {
          out.push(
            @lib.Instruction::local_tee(
              @lib.LocalIdx::new(local_map[local].to_uint()),
            ),
          )
          if !used {
            // HOT keeps the demanded write as tee/drop, even when its value
            // disappears. Drop here before any later ordered producer.
            out.push(@lib.Instruction::drop())
          }
        }
      }
      _ => ()
    }
  }
  let new_locals = locals.copy()
  for slot = removed_params.length() - 1; slot >= 0; slot = slot - 1 {
    new_locals.push(removed_params[slot])
  }
  let (rewritten, capture_map) = pass_lower_compact_captures_with_map(
    @lib.Func::new(new_locals, @lib.Expr::new(out)),
    original,
    kept_params,
  )
  Some((rewritten, local_map.map(fn(local) { capture_map[local] })))
}
