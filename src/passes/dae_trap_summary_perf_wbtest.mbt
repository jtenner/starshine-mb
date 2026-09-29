// V9 call scan retained only for native before/after controls.

///|
fn dae_call_scan_before_trap_fusion(
  instrs : Array[@lib.Instruction],
  caller_def : Int,
  caller_abs : Int,
  path : Array[Int],
  direct_calls : Array[Int],
  tail_calls : Array[Bool],
  direct_callers : Array[Array[Int]],
  dropped_calls : Array[Int],
  escaped : Array[Bool],
  function_infos : Array[DaeFunctionInfo],
  caller_seen_stamps : Array[Int],
  active : Bool,
  topology_out? : DaeCurrentTopologyExtras? = None,
) -> Unit {
  let collect_paths = !function_infos.is_empty()
  let mut idx = 0
  let mut current_active = active
  while idx < instrs.length() {
    if idx + 1 < instrs.length() &&
      caller_abs >= 0 &&
      caller_abs < function_infos.length() {
      match (instrs[idx], instrs[idx + 1]) {
        (@lib.LocalSet(target), @lib.LocalGet(read)) if target == read =>
          function_infos[caller_abs].has_adjacent_local_set_get = true
        _ => ()
      }
    }
    if current_active && dae_instr_is_unreachable_root(instrs[idx]) {
      current_active = false
    }
    match instrs[idx] {
      @lib.Call(func_idx) => {
        let slot = dae_func_idx_slot(func_idx)
        if slot >= 0 && slot < direct_calls.length() {
          let dropped = current_active &&
            idx + 1 < instrs.length() &&
            instrs[idx + 1] == @lib.Instruction::drop()
          if slot < function_infos.length() {
            let callsite = {
              caller_def,
              path: dae_callsite_path(path, idx),
              callee_abs: slot,
              active: current_active,
              dropped,
              tail: false,
            }
            function_infos[slot].calls.push(callsite)
            if dropped {
              function_infos[slot].dropped_calls.push(callsite)
            }
          }
          if current_active {
            direct_calls[slot] = direct_calls[slot] + 1
            if dropped {
              dropped_calls[slot] = dropped_calls[slot] + 1
            }
          }
          if caller_seen_stamps[slot] != caller_def {
            direct_callers[slot].push(caller_def)
            caller_seen_stamps[slot] = caller_def
          }
        }
      }
      @lib.ReturnCall(func_idx) =>
        if current_active {
          let slot = dae_func_idx_slot(func_idx)
          match topology_out {
            Some(topology) => {
              if caller_abs >= 0 &&
                caller_abs < topology.has_outgoing_return_call.length() {
                topology.has_outgoing_return_call[caller_abs] = true
              }
              if slot >= 0 && slot < topology.direct_return_callers.length() {
                dae_topology_add_unique(
                  topology.direct_return_callers[slot],
                  caller_abs,
                )
                if caller_abs >= 0 &&
                  caller_abs < topology.direct_return_callees_by_caller.length() {
                  dae_topology_add_unique(
                    topology.direct_return_callees_by_caller[caller_abs],
                    slot,
                  )
                }
              }
            }
            None => ()
          }
          if slot >= 0 && slot < direct_calls.length() {
            direct_calls[slot] = direct_calls[slot] + 1
            tail_calls[slot] = true
            if slot < function_infos.length() {
              let callsite = {
                caller_def,
                path: dae_callsite_path(path, idx),
                callee_abs: slot,
                active: true,
                dropped: false,
                tail: true,
              }
              function_infos[slot].calls.push(callsite)
            }
            if caller_abs >= 0 && caller_abs < function_infos.length() {
              function_infos[caller_abs].has_tail_calls = true
              dae_function_info_add_tail_callee(
                function_infos[caller_abs],
                slot,
              )
            }
            if caller_seen_stamps[slot] != caller_def {
              direct_callers[slot].push(caller_def)
              caller_seen_stamps[slot] = caller_def
            }
          }
        }
      @lib.ReturnCallIndirect(_, _) => {
        if current_active {
          match topology_out {
            Some(topology) =>
              if caller_abs >= 0 &&
                caller_abs < topology.has_outgoing_return_call_indirect.length() {
                topology.has_outgoing_return_call_indirect[caller_abs] = true
              }
            None => ()
          }
        }

        if current_active &&
          caller_abs >= 0 &&
          caller_abs < function_infos.length() {
          function_infos[caller_abs].has_tail_calls = true
        }
      }
      @lib.ReturnCallRef(_) => {
        if current_active {
          match topology_out {
            Some(topology) =>
              if caller_abs >= 0 &&
                caller_abs < topology.has_outgoing_return_call_ref.length() {
                topology.has_outgoing_return_call_ref[caller_abs] = true
              }
            None => ()
          }
        }

        if current_active &&
          caller_abs >= 0 &&
          caller_abs < function_infos.length() {
          function_infos[caller_abs].has_tail_calls = true
        }
      }
      @lib.CallIndirect(_, _) =>
        if current_active {
          match topology_out {
            Some(topology) =>
              if caller_abs >= 0 &&
                caller_abs < topology.has_outgoing_call_indirect.length() {
                topology.has_outgoing_call_indirect[caller_abs] = true
              }
            None => ()
          }
        }
      @lib.CallRef(_) =>
        if current_active {
          match topology_out {
            Some(topology) =>
              if caller_abs >= 0 &&
                caller_abs < topology.has_outgoing_call_ref.length() {
                topology.has_outgoing_call_ref[caller_abs] = true
              }
            None => ()
          }
        }
      @lib.RefFunc(func_idx) => {
        let slot = dae_func_idx_slot(func_idx)
        if slot >= 0 && slot < escaped.length() {
          escaped[slot] = true
          if slot < function_infos.length() {
            function_infos[slot].has_unseen_calls = true
          }
        }
      }
      @lib.Block(_, @lib.Expr(body)) =>
        dae_call_scan_before_trap_fusion(
          body,
          caller_def,
          caller_abs,
          dae_callsite_child_path_if_needed(path, idx, 0, collect_paths),
          direct_calls,
          tail_calls,
          direct_callers,
          dropped_calls,
          escaped,
          function_infos,
          caller_seen_stamps,
          current_active,
          topology_out~,
        )
      @lib.Loop(block_type, @lib.Expr(body)) => {
        match block_type {
          @lib.TypeIdxBlockType(type_idx) =>
            if caller_abs >= 0 && caller_abs < function_infos.length() {
              dae_function_info_add_loop_type_index(
                function_infos[caller_abs],
                type_idx,
              )
            }
          _ => ()
        }
        dae_call_scan_before_trap_fusion(
          body,
          caller_def,
          caller_abs,
          dae_callsite_child_path_if_needed(path, idx, 1, collect_paths),
          direct_calls,
          tail_calls,
          direct_callers,
          dropped_calls,
          escaped,
          function_infos,
          caller_seen_stamps,
          current_active,
          topology_out~,
        )
      }
      @lib.If(_, then_body, Some(else_body)) => {
        dae_call_scan_before_trap_fusion(
          then_body,
          caller_def,
          caller_abs,
          dae_callsite_child_path_if_needed(path, idx, 2, collect_paths),
          direct_calls,
          tail_calls,
          direct_callers,
          dropped_calls,
          escaped,
          function_infos,
          caller_seen_stamps,
          current_active,
          topology_out~,
        )
        dae_call_scan_before_trap_fusion(
          else_body,
          caller_def,
          caller_abs,
          dae_callsite_child_path_if_needed(path, idx, 3, collect_paths),
          direct_calls,
          tail_calls,
          direct_callers,
          dropped_calls,
          escaped,
          function_infos,
          caller_seen_stamps,
          current_active,
          topology_out~,
        )
      }
      @lib.If(_, then_body, None) =>
        dae_call_scan_before_trap_fusion(
          then_body,
          caller_def,
          caller_abs,
          dae_callsite_child_path_if_needed(path, idx, 2, collect_paths),
          direct_calls,
          tail_calls,
          direct_callers,
          dropped_calls,
          escaped,
          function_infos,
          caller_seen_stamps,
          current_active,
          topology_out~,
        )
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        dae_call_scan_before_trap_fusion(
          body,
          caller_def,
          caller_abs,
          dae_callsite_child_path_if_needed(path, idx, 4, collect_paths),
          direct_calls,
          tail_calls,
          direct_callers,
          dropped_calls,
          escaped,
          function_infos,
          caller_seen_stamps,
          current_active,
          topology_out~,
        )
      @lib.Try(_, @lib.Expr(body), catches, _) => {
        dae_call_scan_before_trap_fusion(
          body,
          caller_def,
          caller_abs,
          dae_callsite_child_path_if_needed(path, idx, 4, collect_paths),
          direct_calls,
          tail_calls,
          direct_callers,
          dropped_calls,
          escaped,
          function_infos,
          caller_seen_stamps,
          current_active,
          topology_out~,
        )
        let mut catch_idx = 0
        while catch_idx < catches.length() {
          match catches[catch_idx] {
            @lib.LegacyCatch(_, @lib.Expr(catch_body))
            | @lib.LegacyCatchAll(@lib.Expr(catch_body)) =>
              dae_call_scan_before_trap_fusion(
                catch_body,
                caller_def,
                caller_abs,
                dae_callsite_child_path_if_needed(
                  path,
                  idx,
                  5 + catch_idx,
                  collect_paths,
                ),
                direct_calls,
                tail_calls,
                direct_callers,
                dropped_calls,
                escaped,
                function_infos,
                caller_seen_stamps,
                current_active,
                topology_out~,
              )
          }
          catch_idx += 1
        }
      }
      _ => ()
    }
    idx += 1
  }
}

///|
fn dae_trap_scan_bench_run(
  body : Array[@lib.Instruction],
  fused : Bool,
) -> DaeCurrentCallFacts {
  let direct_calls = [0, 0]
  let tail_calls = [false, false]
  let direct_callers = dae_make_direct_callers(2)
  let dropped_calls = [0, 0]
  let escaped = [false, false]
  if fused {
    ignore(
      dae_scan_current_call_facts_instrs(
        body,
        1,
        1,
        [],
        direct_calls,
        tail_calls,
        direct_callers,
        dropped_calls,
        escaped,
        [],
        [-1, -1],
        true,
      ),
    )
  } else {
    dae_call_scan_before_trap_fusion(
      body,
      1,
      1,
      [],
      direct_calls,
      tail_calls,
      direct_callers,
      dropped_calls,
      escaped,
      [],
      [-1, -1],
      true,
    )
  }
  { direct_calls, tail_calls, direct_callers, dropped_calls, escaped, }
}

///|
fn dae_trap_scan_bench(
  it : @bench.T,
  depth : Int,
  width : Int,
  trap : Bool,
  fused : Bool,
) -> Unit {
  let mut inner : Array[@lib.Instruction] = []
  for _ in 0..<width {
    inner.push(@lib.Instruction::nop())
  }
  if trap {
    inner.push(@lib.Instruction::unreachable_())
  }
  for _ in 0..<depth {
    inner = [
      @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(inner)),
    ]
  }
  let body = [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::drop(),
  ]
  body.append(inner)
  body.push(@lib.Instruction::call(@lib.FuncIdx::new(0U)))
  body.push(@lib.Instruction::drop())
  let before = dae_trap_scan_bench_run(body, false)
  let after = dae_trap_scan_bench_run(body, true)
  if !dae_current_call_facts_equal(before, after) ||
    after.direct_calls != [if trap && width == 0 { 1 } else { 2 }, 0] ||
    after.direct_callers != [[1], []] {
    abort("trap scan changed active calls or caller ordering")
  }
  it.bench(fn() { it.keep(dae_trap_scan_bench_run(body, fused)) })
}

///|
test "bench DAE trap scan reference depth=0 width=8 trap=false" (it : @bench.T) {
  dae_trap_scan_bench(it, 0, 8, false, false)
}

///|
test "bench DAE trap scan fused depth=0 width=8 trap=false" (it : @bench.T) {
  dae_trap_scan_bench(it, 0, 8, false, true)
}

///|
test "bench DAE trap scan reference depth=0 width=128 trap=false" (
  it : @bench.T,
) {
  dae_trap_scan_bench(it, 0, 128, false, false)
}

///|
test "bench DAE trap scan fused depth=0 width=128 trap=false" (it : @bench.T) {
  dae_trap_scan_bench(it, 0, 128, false, true)
}

///|
test "bench DAE trap scan reference depth=0 width=4096 trap=false" (
  it : @bench.T,
) {
  dae_trap_scan_bench(it, 0, 4096, false, false)
}

///|
test "bench DAE trap scan fused depth=0 width=4096 trap=false" (it : @bench.T) {
  dae_trap_scan_bench(it, 0, 4096, false, true)
}

///|
test "bench DAE trap scan reference depth=8 width=0 trap=true" (it : @bench.T) {
  dae_trap_scan_bench(it, 8, 0, true, false)
}

///|
test "bench DAE trap scan fused depth=8 width=0 trap=true" (it : @bench.T) {
  dae_trap_scan_bench(it, 8, 0, true, true)
}

///|
test "bench DAE trap scan reference depth=128 width=0 trap=true" (it : @bench.T) {
  dae_trap_scan_bench(it, 128, 0, true, false)
}

///|
test "bench DAE trap scan fused depth=128 width=0 trap=true" (it : @bench.T) {
  dae_trap_scan_bench(it, 128, 0, true, true)
}

///|
test "bench DAE trap scan reference depth=512 width=0 trap=true" (it : @bench.T) {
  dae_trap_scan_bench(it, 512, 0, true, false)
}

///|
test "bench DAE trap scan fused depth=512 width=0 trap=true" (it : @bench.T) {
  dae_trap_scan_bench(it, 512, 0, true, true)
}

///|
test "bench DAE trap scan reference depth=8 width=8 trap=false" (it : @bench.T) {
  dae_trap_scan_bench(it, 8, 8, false, false)
}

///|
test "bench DAE trap scan fused depth=8 width=8 trap=false" (it : @bench.T) {
  dae_trap_scan_bench(it, 8, 8, false, true)
}

///|
test "bench DAE trap scan reference depth=128 width=8 trap=false" (
  it : @bench.T,
) {
  dae_trap_scan_bench(it, 128, 8, false, false)
}

///|
test "bench DAE trap scan fused depth=128 width=8 trap=false" (it : @bench.T) {
  dae_trap_scan_bench(it, 128, 8, false, true)
}
