///|
test "scalar local-flow transfers skip tuple storage and preserve reaching writes" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let write = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  let read = hot_build_local_get(func, 0)
  hot_root_append(func, write)
  hot_root_append(func, hot_build_drop(func, read))
  for expanded in [false, true] {
    let cfg = cfg_build(func, expand_operand_control=expanded)
    let block = cfg.node_to_block[write]
    if expanded {
      assert_eq(cfg.node_to_block[read], block)
    }
    let slots = [0]
    let sources = Array::makei(hot_node_count(func), fn(_) { [] })
    let influences = Array::makei(hot_node_count(func), fn(_) { [] })
    let result = local_graph_transfer_block(
      func,
      cfg,
      block,
      local_graph_entry_state(1),
      Some(LocalGraphSourceRecorder::new(sources)),
      Some(influences),
      tuple_slots=Some(slots),
    )
    assert_eq(result[0], [local_graph_set_source_id(1, write)])
    assert_eq(sources[read], [local_graph_set_source_id(1, write)])
    assert_eq(influences[write], [read])
    assert_eq(slots[0], 0)
  }
}
