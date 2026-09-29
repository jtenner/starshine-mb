///|
fn local_graph_write_journal_fixture(
  width : Int,
) -> (HotFunc, HotCfg, NodeId, NodeId) {
  let func = HotFunc::new(
    locals=HotLocals::new(locals=Array::make(width, @lib.ValType::i32())),
  )
  let yes_write = hot_build_local_tee(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  let no_write = hot_build_local_tee(
    func,
    2,
    hot_build_const_i32(func, @lib.I32(9)),
  )
  let value = hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    hot_build_local_get(func, 0),
    [yes_write],
    else_body=Some([no_write]),
  )
  let root = hot_build_drop(func, value)
  let cfg = local_graph_transfer_borrow_fixture(func, [root], false)
  (func, cfg, yes_write, no_write)
}

///|
test "wide local-flow joins visit only branch-written locals and retain both paths" {
  let (func, cfg, yes, no) = local_graph_write_journal_fixture(256)
  let incoming = local_graph_entry_state(256)
  let visits = [0]
  let sources = Array::makei(hot_node_count(func), fn(_) { [] })
  let actual = local_graph_transfer_block(
    func,
    cfg,
    cfg.entry_block,
    incoming,
    Some(LocalGraphSourceRecorder::new(sources)),
    None,
    join_visits=Some(visits),
  )
  assert_eq(actual[1], [local_graph_set_source_id(256, yes), 1])
  assert_eq(actual[2], [2, local_graph_set_source_id(256, no)])
  for index in [0, 3, 255] {
    assert_eq(actual[index], [index])
  }
  assert_eq(incoming, local_graph_entry_state(256))
  assert_true(visits[0] <= 2)
}

///|
test "wide write journals retain unknown loop and handler dependencies across nested forks" {
  for handler in [false, true] {
    let width = 256
    let func = HotFunc::new(
      locals=HotLocals::new(locals=Array::make(width, @lib.ValType::i32())),
    )
    let first = hot_build_local_set(
      func,
      3,
      hot_build_const_i32(func, @lib.I32(7)),
    )
    let second = hot_build_local_set(
      func,
      4,
      hot_build_const_i32(func, @lib.I32(9)),
    )
    let control = if handler {
      hot_build_try(
        func,
        @lib.BlockType::void_(),
        [first],
        catch_body=Some([second]),
      )
    } else {
      hot_build_loop(func, @lib.BlockType::void_(), [first, second])
    }
    let nested = hot_build_if(
      func,
      @lib.BlockType::val_type(@lib.ValType::i32()),
      hot_build_local_get(func, 0),
      [control, hot_build_local_get(func, 3)],
      else_body=Some([hot_build_local_get(func, 4)]),
    )
    let outer = hot_build_if(
      func,
      @lib.BlockType::val_type(@lib.ValType::i32()),
      hot_build_local_get(func, 0),
      [nested],
      else_body=Some([hot_build_local_get(func, 3)]),
    )
    let root = hot_build_drop(func, outer)
    let cfg = local_graph_transfer_borrow_fixture(func, [root], false)
    let incoming = local_graph_entry_state(width)
    let actual_sources = Array::makei(hot_node_count(func), fn(_) { [] })
    let expected_sources = Array::makei(hot_node_count(func), fn(_) { [] })
    let actual = local_graph_transfer_block(
      func,
      cfg,
      cfg.entry_block,
      incoming,
      Some(LocalGraphSourceRecorder::new(actual_sources)),
      None,
    )
    let expected = local_graph_tuple_reference_block(
      func,
      cfg,
      cfg.entry_block,
      incoming,
      Some(LocalGraphSourceRecorder::new(expected_sources)),
      None,
    )
    assert_eq(actual, expected)
    assert_eq(actual_sources, expected_sources)
    assert_eq(incoming, local_graph_entry_state(width))
    assert_true(actual[3].contains(local_graph_set_source_id(width, first)))
    assert_true(actual[4].contains(local_graph_set_source_id(width, second)))
  }
}
