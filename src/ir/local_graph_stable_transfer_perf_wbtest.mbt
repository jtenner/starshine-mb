///|
fn local_graph_build_in_states_reference(
  func : HotFunc,
  cfg : HotCfg,
  include_exceptional : Bool,
) -> Array[Array[Array[Int]]] {
  let local_count = hot_local_count(func)
  let in_states : Array[Array[Array[Int]]] = []
  let out_states : Array[Array[Array[Int]]] = []
  for _ in 0..<cfg_block_count(cfg) {
    in_states.push(local_graph_empty_state(local_count))
    out_states.push(local_graph_empty_state(local_count))
  }
  let entry_state = local_graph_entry_state(local_count)
  in_states[cfg_entry_block(cfg)] = entry_state
  let mut changed = true
  while changed {
    changed = false
    for block_id = 0; block_id < cfg_block_count(cfg); block_id = block_id + 1 {
      let next_in = if block_id == cfg_entry_block(cfg) {
        entry_state
      } else {
        local_graph_merge_predecessors(
          cfg, block_id, local_count, out_states, include_exceptional,
        )
      }
      if !local_graph_state_equal(in_states[block_id], next_in) {
        in_states[block_id] = next_in
        changed = true
      }
      let next_out = local_graph_transfer_block(
        func,
        cfg,
        block_id,
        in_states[block_id],
        None,
        None,
      )
      if !local_graph_state_equal(out_states[block_id], next_out) {
        out_states[block_id] = next_out
        changed = true
      }
    }
  }
  in_states
}

///|
fn local_graph_stable_transfer_bench(
  it : @bench.T,
  count : Int,
  expanded : Bool,
  reference : Bool,
) -> Unit {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let write = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  hot_root_append(func, write)
  for _ in 0..<count {
    let roots : Array[NodeId] = []
    for _ in 0..<64 {
      roots.push(hot_build_drop(func, hot_build_const_i32(func, @lib.I32(3))))
    }
    roots.push(hot_build_drop(func, hot_build_local_get(func, 0)))
    hot_root_append(func, hot_build_block(func, @lib.BlockType::void_(), roots))
  }
  let cfg = cfg_build(func, expand_operand_control=expanded)
  let before = local_graph_build_in_states_reference(func, cfg, true)
  let after = local_graph_build_in_states(func, cfg, true)
  if before != after ||
    after[cfg.exit_block][0] != [local_graph_set_source_id(1, write)] {
    abort("stable-transfer benchmark changed source states")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        local_graph_build_in_states_reference(func, cfg, true)
      } else {
        local_graph_build_in_states(func, cfg, true)
      },
    )
  })
}

///|
test "bench local-flow stable transfer expanded reference blocks=64" (
  it : @bench.T,
) {
  local_graph_stable_transfer_bench(it, 64, true, true)
}

///|
test "bench local-flow stable transfer expanded reused blocks=64" (
  it : @bench.T,
) {
  local_graph_stable_transfer_bench(it, 64, true, false)
}

///|
test "bench local-flow stable transfer expanded reference blocks=256" (
  it : @bench.T,
) {
  local_graph_stable_transfer_bench(it, 256, true, true)
}

///|
test "bench local-flow stable transfer expanded reused blocks=256" (
  it : @bench.T,
) {
  local_graph_stable_transfer_bench(it, 256, true, false)
}

///|
test "bench local-flow stable transfer unexpanded reference blocks=64" (
  it : @bench.T,
) {
  local_graph_stable_transfer_bench(it, 64, false, true)
}

///|
test "bench local-flow stable transfer unexpanded reused blocks=64" (
  it : @bench.T,
) {
  local_graph_stable_transfer_bench(it, 64, false, false)
}
