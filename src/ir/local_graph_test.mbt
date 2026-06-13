///|
fn local_graph_test_has_entry_source(
  sources : Array[HotLocalGraphSource],
  local_id : LocalId,
) -> Bool {
  for source in sources {
    match source {
      HotLocalGraphSource::EntrySource(id) => if id == local_id { return true }
      _ => ()
    }
  }
  false
}

///|
fn local_graph_test_has_set_source(
  sources : Array[HotLocalGraphSource],
  node_id : NodeId,
) -> Bool {
  for source in sources {
    match source {
      HotLocalGraphSource::SetSource(id) => if id == node_id { return true }
      _ => ()
    }
  }
  false
}

///|
fn local_graph_test_has_param_entry_source(
  graph : HotLocalGraph,
  sources : Array[HotLocalGraphSource],
  local_id : LocalId,
) -> Bool {
  for source in sources {
    match source {
      HotLocalGraphSource::EntrySource(id) =>
        if id == local_id && local_graph_source_is_param_entry(graph, source) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn local_graph_test_has_default_entry_source(
  graph : HotLocalGraph,
  sources : Array[HotLocalGraphSource],
  local_id : LocalId,
) -> Bool {
  for source in sources {
    match source {
      HotLocalGraphSource::EntrySource(id) =>
        if id == local_id && local_graph_source_is_default_entry(graph, source) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
test "local graph distinguishes parameter and body default entry sources" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let param_get = hot_build_local_get(func, 0)
  let default_get = hot_build_local_get(func, 1)
  hot_root_append(func, hot_build_drop(func, param_get))
  hot_root_append(func, hot_build_drop(func, default_get))

  let graph = local_graph_build(func, cfg_build(func))
  let param_sources = local_graph_reaching_sources_for_get(graph, param_get)
  let default_sources = local_graph_reaching_sources_for_get(graph, default_get)

  @debug.assert_eq(param_sources.length(), 1)
  @debug.assert_eq(default_sources.length(), 1)
  assert_true(local_graph_test_has_param_entry_source(graph, param_sources, 0))
  assert_false(local_graph_source_is_default_entry(graph, param_sources[0]))
  assert_true(
    local_graph_test_has_default_entry_source(graph, default_sources, 1),
  )
  assert_false(local_graph_source_is_param_entry(graph, default_sources[0]))
}

///|
test "local graph classifies single-source and merge gets" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let set = hot_build_local_set(func, 1, hot_build_const_i32(func, @lib.I32(7)))
  let if_id = hot_build_if(
    func,
    @lib.BlockType::void_(),
    hot_build_local_get(func, 0),
    [set],
    else_body=Some([hot_build_nop(func)]),
  )
  let merge_get = hot_build_local_get(func, 1)
  let single_get = hot_build_local_get(func, 0)
  hot_root_append(func, if_id)
  hot_root_append(func, hot_build_drop(func, merge_get))
  hot_root_append(func, hot_build_drop(func, single_get))

  let graph = local_graph_build(func, cfg_build(func))

  assert_true(local_graph_get_is_merge(graph, merge_get))
  assert_false(local_graph_get_is_single_source(graph, merge_get))
  assert_true(local_graph_get_is_single_source(graph, single_get))
  assert_false(local_graph_get_is_merge(graph, single_get))
}

///|
test "local graph records a simple set reaching a later get" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let set = hot_build_local_set(func, 0, hot_build_const_i32(func, @lib.I32(1)))
  let get = hot_build_local_get(func, 0)
  hot_root_append(func, set)
  hot_root_append(func, hot_build_drop(func, get))

  let cfg = cfg_build(func)
  let graph = local_graph_build(func, cfg)
  let sources = local_graph_reaching_sources_for_get(graph, get)
  let influenced = local_graph_influenced_gets_for_set(graph, set)

  @debug.assert_eq(sources.length(), 1)
  assert_true(local_graph_test_has_set_source(sources, set))
  assert_true(local_graph_node_is_write(graph, set))
  assert_true(local_graph_write_is_set(graph, set))
  assert_false(local_graph_write_is_tee(graph, set))
  @debug.assert_eq(local_graph_write_local_id(graph, set), 0)
  @debug.assert_eq(influenced, [get])
  @debug.assert_eq(local_graph_influenced_gets_for_write(graph, set), [get])
}

///|
test "local graph reports influenced gets in transfer order" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let later_get = hot_build_local_get(func, 0)
  let set = hot_build_local_set(func, 0, hot_build_const_i32(func, @lib.I32(1)))
  let earlier_get = hot_build_local_get(func, 0)
  hot_root_append(func, set)
  hot_root_append(func, hot_build_drop(func, earlier_get))
  hot_root_append(func, hot_build_drop(func, later_get))

  let graph = local_graph_build(func, cfg_build(func))

  @debug.assert_eq(local_graph_influenced_gets_for_write(graph, set), [
    earlier_get, later_get,
  ])
}

///|
test "local graph records entry source for get before first set" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let get = hot_build_local_get(func, 0)
  let set = hot_build_local_set(func, 0, hot_build_const_i32(func, @lib.I32(2)))
  hot_root_append(func, hot_build_drop(func, get))
  hot_root_append(func, set)

  let graph = local_graph_build(func, cfg_build(func))
  let sources = local_graph_reaching_sources_for_get(graph, get)

  @debug.assert_eq(sources.length(), 1)
  assert_true(local_graph_test_has_entry_source(sources, 0))
  @debug.assert_eq(local_graph_influenced_gets_for_set(graph, set), [])
}

///|
test "local graph overwrites prior reaching set with later set in same block" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let first_set = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(1)),
  )
  let second_set = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(2)),
  )
  let get = hot_build_local_get(func, 0)
  hot_root_append(func, first_set)
  hot_root_append(func, second_set)
  hot_root_append(func, hot_build_drop(func, get))

  let graph = local_graph_build(func, cfg_build(func))
  let sources = local_graph_reaching_sources_for_get(graph, get)

  @debug.assert_eq(sources.length(), 1)
  assert_true(local_graph_test_has_set_source(sources, second_set))
  @debug.assert_eq(local_graph_influenced_gets_for_set(graph, first_set), [])
  @debug.assert_eq(local_graph_influenced_gets_for_set(graph, second_set), [get])
}

///|
test "local graph records diamond merge sources from set and default entry" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let then_set = hot_build_local_set(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  let if_id = hot_build_if(
    func,
    @lib.BlockType::void_(),
    hot_build_local_get(func, 0),
    [then_set],
    else_body=Some([hot_build_nop(func)]),
  )
  let get = hot_build_local_get(func, 1)
  hot_root_append(func, if_id)
  hot_root_append(func, hot_build_drop(func, get))

  let graph = local_graph_build(func, cfg_build(func))
  let sources = local_graph_reaching_sources_for_get(graph, get)

  @debug.assert_eq(sources.length(), 2)
  assert_true(local_graph_test_has_set_source(sources, then_set))
  assert_true(local_graph_test_has_entry_source(sources, 1))
  @debug.assert_eq(local_graph_influenced_gets_for_set(graph, then_set), [get])
}

///|
test "local graph records diamond merge sources from both arms" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let then_set = hot_build_local_set(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  let else_set = hot_build_local_set(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(9)),
  )
  let if_id = hot_build_if(
    func,
    @lib.BlockType::void_(),
    hot_build_local_get(func, 0),
    [then_set],
    else_body=Some([else_set]),
  )
  let get = hot_build_local_get(func, 1)
  hot_root_append(func, if_id)
  hot_root_append(func, hot_build_drop(func, get))

  let graph = local_graph_build(func, cfg_build(func))
  let sources = local_graph_reaching_sources_for_get(graph, get)

  @debug.assert_eq(sources.length(), 2)
  assert_true(local_graph_test_has_set_source(sources, then_set))
  assert_true(local_graph_test_has_set_source(sources, else_set))
  @debug.assert_eq(local_graph_influenced_gets_for_set(graph, then_set), [get])
  @debug.assert_eq(local_graph_influenced_gets_for_set(graph, else_set), [get])
}

///|
test "local graph records loop-carried reaching sources" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let entry_set = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(1)),
  )
  let loop_get = hot_build_local_get(func, 0)
  let loop_set = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(2)),
  )
  let loop_id = hot_build_loop(func, @lib.BlockType::void_(), [])
  let label = hot_control_node_label(func, loop_id)
  hot_region_replace_body(func, hot_region_body_ref(func, loop_id), [
    hot_build_drop(func, loop_get),
    loop_set,
    hot_build_br_if(func, label, hot_build_const_i32(func, @lib.I32(1))),
  ])
  hot_root_append(func, entry_set)
  hot_root_append(func, loop_id)

  let graph = local_graph_build(func, cfg_build(func))
  let sources = local_graph_reaching_sources_for_get(graph, loop_get)

  @debug.assert_eq(sources.length(), 2)
  assert_true(local_graph_test_has_set_source(sources, entry_set))
  assert_true(local_graph_test_has_set_source(sources, loop_set))
  @debug.assert_eq(local_graph_influenced_gets_for_set(graph, entry_set), [
    loop_get,
  ])
  @debug.assert_eq(local_graph_influenced_gets_for_set(graph, loop_set), [
    loop_get,
  ])
}

///|
test "local graph can-move keeps get after set when obstacle is before set" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let before = hot_build_nop(func)
  let set = hot_build_local_set(func, 0, hot_build_const_i32(func, @lib.I32(1)))
  let get = hot_build_local_get(func, 0)
  hot_root_append(func, before)
  hot_root_append(func, set)
  hot_root_append(func, hot_build_drop(func, get))

  let cfg = cfg_build(func)
  let graph = local_graph_build(func, cfg)

  @debug.assert_eq(
    local_graph_can_move_set_past_node(func, cfg, graph, set, before),
    [get],
  )
}

///|
test "local graph can-move blocks get after set when obstacle is between them" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let set = hot_build_local_set(func, 0, hot_build_const_i32(func, @lib.I32(1)))
  let obstacle = hot_build_nop(func)
  let get = hot_build_local_get(func, 0)
  hot_root_append(func, set)
  hot_root_append(func, obstacle)
  hot_root_append(func, hot_build_drop(func, get))

  let cfg = cfg_build(func)
  let graph = local_graph_build(func, cfg)

  @debug.assert_eq(
    local_graph_can_move_set_past_node(func, cfg, graph, set, obstacle),
    [],
  )
}

///|
test "local graph can-move keeps get before later obstacle" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let set = hot_build_local_set(func, 0, hot_build_const_i32(func, @lib.I32(1)))
  let get = hot_build_local_get(func, 0)
  let obstacle = hot_build_nop(func)
  hot_root_append(func, set)
  hot_root_append(func, hot_build_drop(func, get))
  hot_root_append(func, obstacle)

  let cfg = cfg_build(func)
  let graph = local_graph_build(func, cfg)

  @debug.assert_eq(
    local_graph_can_move_set_past_node(func, cfg, graph, set, obstacle),
    [get],
  )
}

///|
test "local graph can-move returns only gets before the obstacle" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let set = hot_build_local_set(func, 0, hot_build_const_i32(func, @lib.I32(1)))
  let first_obstacle = hot_build_nop(func)
  let first_get = hot_build_local_get(func, 0)
  let second_obstacle = hot_build_nop(func)
  let second_get = hot_build_local_get(func, 0)
  let third_obstacle = hot_build_nop(func)
  hot_root_append(func, set)
  hot_root_append(func, first_obstacle)
  hot_root_append(func, hot_build_drop(func, first_get))
  hot_root_append(func, second_obstacle)
  hot_root_append(func, hot_build_drop(func, second_get))
  hot_root_append(func, third_obstacle)

  let cfg = cfg_build(func)
  let graph = local_graph_build(func, cfg)

  @debug.assert_eq(
    local_graph_can_move_set_past_node(func, cfg, graph, set, first_obstacle),
    [],
  )
  @debug.assert_eq(
    local_graph_can_move_set_past_node(func, cfg, graph, set, second_obstacle),
    [first_get],
  )
  @debug.assert_eq(
    local_graph_can_move_set_past_node(func, cfg, graph, set, third_obstacle),
    [first_get, second_get],
  )
}

///|
test "local graph can-move sees alternate branch path around obstacle" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let set = hot_build_local_set(func, 1, hot_build_const_i32(func, @lib.I32(1)))
  let obstacle = hot_build_nop(func)
  let if_id = hot_build_if(
    func,
    @lib.BlockType::void_(),
    hot_build_local_get(func, 0),
    [obstacle],
    else_body=Some([hot_build_nop(func)]),
  )
  let get = hot_build_local_get(func, 1)
  hot_root_append(func, set)
  hot_root_append(func, if_id)
  hot_root_append(func, hot_build_drop(func, get))

  let cfg = cfg_build(func)
  let graph = local_graph_build(func, cfg)

  @debug.assert_eq(
    local_graph_can_move_set_past_node(func, cfg, graph, set, obstacle),
    [get],
  )
}

///|
test "local graph can-move blocks a child set from moving past its parent obstacle" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let tee = hot_build_local_tee(func, 0, hot_build_const_i32(func, @lib.I32(1)))
  let obstacle = hot_build_drop(func, tee)
  let get = hot_build_local_get(func, 0)
  hot_root_append(func, obstacle)
  hot_root_append(func, hot_build_drop(func, get))

  let cfg = cfg_build(func)
  let graph = local_graph_build(func, cfg)

  assert_true(local_graph_node_is_write(graph, tee))
  assert_false(local_graph_write_is_set(graph, tee))
  assert_true(local_graph_write_is_tee(graph, tee))
  @debug.assert_eq(local_graph_write_local_id(graph, tee), 0)
  @debug.assert_eq(local_graph_influenced_gets_for_set(graph, tee), [get])
  @debug.assert_eq(local_graph_influenced_gets_for_write(graph, tee), [get])
  @debug.assert_eq(
    local_graph_can_move_set_past_node(func, cfg, graph, tee, obstacle),
    [],
  )
}
