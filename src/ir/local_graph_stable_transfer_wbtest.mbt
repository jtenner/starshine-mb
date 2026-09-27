///|
test "local-flow fixed point reuses transfers with unchanged incoming sources" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let write = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  hot_root_append(func, write)
  hot_root_append(func, hot_build_drop(func, hot_build_local_get(func, 0)))
  for expanded in [true, false] {
    let cfg = cfg_build(func, expand_operand_control=expanded)
    let transfers = [0]
    let states = local_graph_build_in_states(
      func,
      cfg,
      true,
      block_transfers=Some(transfers),
    )
    assert_eq(states[cfg.exit_block][0], [local_graph_set_source_id(1, write)])
    assert_eq(states[cfg.entry_block][0], [local_graph_entry_source_id(0)])
    assert_true(
      transfers[0] <= cfg_block_count(cfg) + 1,
      msg="block transfers: \{transfers[0]}",
    )
  }
}
