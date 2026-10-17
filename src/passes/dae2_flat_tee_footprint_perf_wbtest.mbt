///|
// Frozen pre-fix planner, kept only for manual native cost comparisons. Its
// Tee value-consumer write facts are the known RED, not an accepted contract.
// Original owner SHA256: beaaf49bf314e4b20a10e7462d656beada94bd681867b4d57c59076f5094b113

///|
fn dae2_flat_tee_reference_plan(
  graph : Dae2Graph,
  infos : Array[Dae2Function],
  index : Int32,
  type_infos : Array[Int32],
  body : @lib.Func,
  intrinsic_imports : Array[Bool]?,
  module_context~ : @ir.HotModuleContext? = None,
  conditionals~ : Bool = true,
) -> Dae2RawPlan? {
  let @lib.Func(locals, @lib.Expr(original_instructions)) = body
  let instructions = match
    dae2_raw_qualified_instructions(original_instructions, module_context) {
    Some(instructions) => instructions
    None => {
      if !conditionals {
        return None
      }
      return dae2_raw_conditional_dependency_plan(
        graph, infos, index, type_infos, body, intrinsic_imports, module_context,
      )
    }
  }
  let info = infos[index]
  let plan = Dae2RawPlan::new(graph.used.length())
  let stack : Array[Int32] = []
  let values = Array::make(info.params.length() + locals.length(), -1)
  for param in 0..<info.params.length() {
    values[param] = info.param_locations[param]
  }
  for instr in instructions {
    let arity = dae2_raw_pure_arity(instr)
    if arity >= 0 {
      if stack.length() < arity {
        return None
      }
      if arity == 0 {
        let symbol = match instr {
          @lib.LocalGet(@lib.LocalIdx(raw)) => {
            let local = raw.reinterpret_as_int()
            if local < 0 || local >= info.params.length() + locals.length() {
              return None
            }
            values[local]
          }
          _ => -1
        }
        stack.push(symbol)
      } else if arity > 1 {
        let start = stack.length() - arity
        let mut symbol = stack[start]
        for slot in (start + 1)..<stack.length() {
          symbol = plan.join(symbol, stack[slot])
        }
        stack.truncate(start)
        stack.push(symbol)
      }
      continue
    }
    let observed = dae2_raw_observer_arity(instr)
    if observed >= 0 {
      if stack.length() < observed {
        return None
      }
      let start = stack.length() - observed
      for slot in start..<stack.length() {
        plan.observations.push(stack[slot])
      }
      stack.truncate(start)
      continue
    }
    let producer = dae2_raw_observed_producer_arity(instr, module_context)
    if producer >= 0 {
      if stack.length() < producer {
        return None
      }
      let start = stack.length() - producer
      for slot in start..<stack.length() {
        plan.observations.push(stack[slot])
      }
      stack.truncate(start)
      stack.push(-1)
      continue
    }
    match instr {
      @lib.Nop => ()
      @lib.Drop => {
        if stack.is_empty() {
          return None
        }
        ignore(stack.pop())
      }
      @lib.LocalSet(@lib.LocalIdx(raw)) | @lib.LocalTee(@lib.LocalIdx(raw)) => {
        let local = raw.reinterpret_as_int()
        if local < 0 || local >= values.length() || stack.is_empty() {
          return None
        }
        // Keep exact lexical write demand for direct replay, including bodies
        // whose branchless blocks were flattened during qualification.
        values[local] = plan.write(local, stack[stack.length() - 1])
        if instr is @lib.LocalSet(_) {
          ignore(stack.pop())
        }
      }
      @lib.Call(_) | @lib.CallIndirect(_, _) | @lib.CallRef(_) => {
        let (callee_index, indirect) = match instr {
          @lib.Call(@lib.FuncIdx(raw)) => (raw.reinterpret_as_int(), false)
          @lib.CallIndirect(type_idx, _) | @lib.CallRef(type_idx) => {
            let slot = dae2_type_slot(type_idx, 0)
            if slot < 0 || slot >= type_infos.length() {
              return None
            }
            (type_infos[slot], true)
          }
          _ => abort("DAE2 raw call classifier is incomplete")
        }
        if callee_index < 0 || callee_index >= infos.length() {
          return None
        }
        match intrinsic_imports {
          Some(mask) if callee_index < mask.length() && mask[callee_index] =>
            return None
          _ => ()
        }
        let callee = infos[callee_index]
        let consumed = callee.params.length() + (if indirect { 1 } else { 0 })
        if stack.length() < consumed {
          return None
        }
        let start = stack.length() - consumed
        for arg in 0..<callee.params.length() {
          plan.edge(callee.param_locations[arg], stack[start + arg])
        }
        if indirect {
          plan.observations.push(stack[stack.length() - 1])
        }
        stack.truncate(start)
        for _ in callee.results {
          stack.push(callee.result_location)
        }
      }
      @lib.Return => {
        if stack.length() != info.results.length() {
          return None
        }
        let start = stack.length() - info.results.length()
        for slot in start..<stack.length() {
          plan.edge(info.result_location, stack[slot])
        }
        return Some(plan)
      }
      _ => return None
    }
  }
  if stack.length() != info.results.length() {
    return None
  }
  for source in stack {
    plan.edge(info.result_location, source)
  }
  Some(plan)
}

///|
fn dae2_flat_tee_footprint_bench(
  it : @bench.T,
  mode : Int32,
  width : Int32,
  reference : Bool,
) -> Unit {
  let input = dae2_flat_tee_footprint_fixture(mode, width)
  dae2_flat_tee_footprint_check(input, width) catch {
    error => abort("Tee benchmark behavior/footprint setup failed: \{error}")
  }
  let saved = @binary.encode_module(input).unwrap()
  let context = @ir.hot_module_context_from_module(input)
  let @lib.FuncType(params, results) = @ir.hot_module_resolve_func_type(
    context,
    @lib.FuncIdx::new(0U),
  ).unwrap()
  let body = input.code_sec.unwrap().0[0]
  let build = fn(old : Bool) {
    let graph = Dae2Graph::new()
    let info = Dae2Function::new(graph, params, results)
    let plan = if old {
      dae2_flat_tee_reference_plan(
        graph,
        [info],
        0,
        [],
        body,
        None,
        module_context=Some(context),
      ).unwrap()
    } else {
      dae2_raw_dependency_plan(
        graph,
        [info],
        0,
        [],
        body,
        None,
        module_context=Some(context),
      ).unwrap()
    }
    plan.commit(graph)
    graph.solve()
    (graph, plan)
  }
  let (before, before_plan) = build(true)
  let (after, after_plan) = build(false)
  for boundary in 0..<3 {
    if before.used[boundary] != after.used[boundary] {
      abort("Tee benchmark changed a function boundary")
    }
  }
  if before_plan.count > after_plan.count ||
    after_plan.count > 2 * width ||
    after_plan.sources.length() > 3 * width {
    abort("Tee benchmark lost its linear metadata bound")
  }
  it.bench(fn() { it.keep(build(reference)) })
  if @binary.encode_module(input).unwrap() != saved {
    abort("Tee benchmark mutated source input")
  }
}

///|
#skip("manual paired native Tee planner work/allocation control; excluded from default tests")
test "bench DAE2 flat Tee direct width=32 reference" (it : @bench.T) {
  dae2_flat_tee_footprint_bench(it, 0, 32, true)
}

///|
#skip("manual paired native Tee planner work/allocation control; excluded from default tests")
test "bench DAE2 flat Tee direct width=32 current" (it : @bench.T) {
  dae2_flat_tee_footprint_bench(it, 0, 32, false)
}

///|
#skip("manual paired native Tee planner work/allocation control; excluded from default tests")
test "bench DAE2 flat Tee direct width=128 reference" (it : @bench.T) {
  dae2_flat_tee_footprint_bench(it, 0, 128, true)
}

///|
#skip("manual paired native Tee planner work/allocation control; excluded from default tests")
test "bench DAE2 flat Tee direct width=128 current" (it : @bench.T) {
  dae2_flat_tee_footprint_bench(it, 0, 128, false)
}

///|
#skip("manual paired native Tee planner work/allocation control; excluded from default tests")
test "bench DAE2 flat Tee direct width=512 reference" (it : @bench.T) {
  dae2_flat_tee_footprint_bench(it, 0, 512, true)
}

///|
#skip("manual paired native Tee planner work/allocation control; excluded from default tests")
test "bench DAE2 flat Tee direct width=512 current" (it : @bench.T) {
  dae2_flat_tee_footprint_bench(it, 0, 512, false)
}

///|
#skip("manual paired native Tee planner work/allocation control; excluded from default tests")
test "bench DAE2 flat Tee chained width=32 reference" (it : @bench.T) {
  dae2_flat_tee_footprint_bench(it, 1, 32, true)
}

///|
#skip("manual paired native Tee planner work/allocation control; excluded from default tests")
test "bench DAE2 flat Tee chained width=32 current" (it : @bench.T) {
  dae2_flat_tee_footprint_bench(it, 1, 32, false)
}

///|
#skip("manual paired native Tee planner work/allocation control; excluded from default tests")
test "bench DAE2 flat Tee chained width=128 reference" (it : @bench.T) {
  dae2_flat_tee_footprint_bench(it, 1, 128, true)
}

///|
#skip("manual paired native Tee planner work/allocation control; excluded from default tests")
test "bench DAE2 flat Tee chained width=128 current" (it : @bench.T) {
  dae2_flat_tee_footprint_bench(it, 1, 128, false)
}

///|
#skip("manual paired native Tee planner work/allocation control; excluded from default tests")
test "bench DAE2 flat Tee chained width=512 reference" (it : @bench.T) {
  dae2_flat_tee_footprint_bench(it, 1, 512, true)
}

///|
#skip("manual paired native Tee planner work/allocation control; excluded from default tests")
test "bench DAE2 flat Tee chained width=512 current" (it : @bench.T) {
  dae2_flat_tee_footprint_bench(it, 1, 512, false)
}

///|
#skip("manual paired native Tee planner work/allocation control; excluded from default tests")
test "bench DAE2 flat Tee trap-effect width=32 reference" (it : @bench.T) {
  dae2_flat_tee_footprint_bench(it, 2, 32, true)
}

///|
#skip("manual paired native Tee planner work/allocation control; excluded from default tests")
test "bench DAE2 flat Tee trap-effect width=32 current" (it : @bench.T) {
  dae2_flat_tee_footprint_bench(it, 2, 32, false)
}

///|
#skip("manual paired native Tee planner work/allocation control; excluded from default tests")
test "bench DAE2 flat Tee trap-effect width=128 reference" (it : @bench.T) {
  dae2_flat_tee_footprint_bench(it, 2, 128, true)
}

///|
#skip("manual paired native Tee planner work/allocation control; excluded from default tests")
test "bench DAE2 flat Tee trap-effect width=128 current" (it : @bench.T) {
  dae2_flat_tee_footprint_bench(it, 2, 128, false)
}

///|
#skip("manual paired native Tee planner work/allocation control; excluded from default tests")
test "bench DAE2 flat Tee trap-effect width=512 reference" (it : @bench.T) {
  dae2_flat_tee_footprint_bench(it, 2, 512, true)
}

///|
#skip("manual paired native Tee planner work/allocation control; excluded from default tests")
test "bench DAE2 flat Tee trap-effect width=512 current" (it : @bench.T) {
  dae2_flat_tee_footprint_bench(it, 2, 512, false)
}
