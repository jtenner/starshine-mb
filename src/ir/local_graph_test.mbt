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
fn local_graph_test_default_entry_for_type(
  val_type : @lib.ValType,
) -> (HotLocalGraph, HotLocalGraphSource) {
  let func = HotFunc::new(locals=HotLocals::new(locals=[val_type]))
  let get = hot_build_local_get(func, 0)
  hot_root_append(func, hot_build_drop(func, get))
  let graph = local_graph_build(func, cfg_build(func))
  let sources = local_graph_reaching_sources_for_get(graph, get)
  if sources.length() != 1 {
    abort("expected one default entry source")
  }
  (graph, sources[0])
}

///|
test "local graph marks scalar and SIMD body defaults defaultable" {
  let (i32_graph, i32_source) = local_graph_test_default_entry_for_type(
    @lib.ValType::i32(),
  )
  assert_true(local_graph_entry_source_has_legal_default(i32_graph, 0))
  assert_true(local_graph_source_is_defaultable_entry(i32_graph, i32_source))

  let (i64_graph, i64_source) = local_graph_test_default_entry_for_type(
    @lib.ValType::i64(),
  )
  assert_true(local_graph_entry_source_has_legal_default(i64_graph, 0))
  assert_true(local_graph_source_is_defaultable_entry(i64_graph, i64_source))

  let (f32_graph, f32_source) = local_graph_test_default_entry_for_type(
    @lib.ValType::f32(),
  )
  assert_true(local_graph_entry_source_has_legal_default(f32_graph, 0))
  assert_true(local_graph_source_is_defaultable_entry(f32_graph, f32_source))

  let (f64_graph, f64_source) = local_graph_test_default_entry_for_type(
    @lib.ValType::f64(),
  )
  assert_true(local_graph_entry_source_has_legal_default(f64_graph, 0))
  assert_true(local_graph_source_is_defaultable_entry(f64_graph, f64_source))

  let (v128_graph, v128_source) = local_graph_test_default_entry_for_type(
    @lib.ValType::v128(),
  )
  assert_true(local_graph_entry_source_has_legal_default(v128_graph, 0))
  assert_true(local_graph_source_is_defaultable_entry(v128_graph, v128_source))
}

///|
test "local graph marks nullable GC reference body defaults defaultable" {
  let nominal_heap = @lib.HeapType::new(@lib.TypeIdx::new(0U))
  let nullable_struct = @lib.ValType::ref_null(nominal_heap)
  let exact_nullable_struct = @lib.ValType::ref_type(
    @lib.RefType::new(true, nominal_heap, exact=true),
  )

  let (struct_graph, struct_source) = local_graph_test_default_entry_for_type(
    nullable_struct,
  )
  assert_true(local_graph_entry_source_has_legal_default(struct_graph, 0))
  assert_true(
    local_graph_source_is_defaultable_entry(struct_graph, struct_source),
  )

  let (exact_graph, exact_source) = local_graph_test_default_entry_for_type(
    exact_nullable_struct,
  )
  assert_true(local_graph_entry_source_has_legal_default(exact_graph, 0))
  assert_true(
    local_graph_source_is_defaultable_entry(exact_graph, exact_source),
  )
}

///|
test "local graph rejects params sets and non-null refs as default replacements" {
  let param_func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let param_get = hot_build_local_get(param_func, 0)
  let set = hot_build_local_set(
    param_func,
    1,
    hot_build_const_i32(param_func, @lib.I32(1)),
  )
  let set_get = hot_build_local_get(param_func, 1)
  hot_root_append(param_func, hot_build_drop(param_func, param_get))
  hot_root_append(param_func, set)
  hot_root_append(param_func, hot_build_drop(param_func, set_get))

  let param_graph = local_graph_build(param_func, cfg_build(param_func))
  let param_sources = local_graph_reaching_sources_for_get(
    param_graph, param_get,
  )
  let set_sources = local_graph_reaching_sources_for_get(param_graph, set_get)

  assert_false(local_graph_entry_source_has_legal_default(param_graph, 0))
  assert_true(local_graph_entry_source_has_legal_default(param_graph, 1))
  assert_false(
    local_graph_source_is_defaultable_entry(param_graph, param_sources[0]),
  )
  assert_false(
    local_graph_source_is_defaultable_entry(param_graph, set_sources[0]),
  )

  let nonnull_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let (nonnull_graph, nonnull_source) = local_graph_test_default_entry_for_type(
    nonnull_ref,
  )
  assert_false(local_graph_entry_source_has_legal_default(nonnull_graph, 0))
  assert_false(
    local_graph_source_is_defaultable_entry(nonnull_graph, nonnull_source),
  )
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
test "local graph classifies straight-line local as already SSA" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let set = hot_build_local_set(func, 0, hot_build_const_i32(func, @lib.I32(7)))
  let first_get = hot_build_local_get(func, 0)
  let second_get = hot_build_local_get(func, 0)
  hot_root_append(func, set)
  hot_root_append(func, hot_build_drop(func, first_get))
  hot_root_append(func, hot_build_drop(func, second_get))

  let graph = local_graph_build(func, cfg_build(func))

  assert_true(local_graph_local_is_already_ssa(graph, 0))
}

///|
test "local graph classifies param and body default locals as already SSA" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let param_get = hot_build_local_get(func, 0)
  let body_get = hot_build_local_get(func, 1)
  hot_root_append(func, hot_build_drop(func, param_get))
  hot_root_append(func, hot_build_drop(func, body_get))

  let graph = local_graph_build(func, cfg_build(func))

  assert_true(local_graph_local_is_already_ssa(graph, 0))
  assert_true(local_graph_local_is_already_ssa(graph, 1))
}

///|
test "local graph classifies tee-defined local as already SSA" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let tee = hot_build_local_tee(func, 0, hot_build_const_i32(func, @lib.I32(4)))
  let get = hot_build_local_get(func, 0)
  hot_root_append(func, hot_build_drop(func, tee))
  hot_root_append(func, hot_build_drop(func, get))

  let graph = local_graph_build(func, cfg_build(func))

  assert_true(local_graph_local_is_already_ssa(graph, 0))
}

///|
test "local graph rejects branch merge local as already SSA" {
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
  let get = hot_build_local_get(func, 1)
  hot_root_append(func, if_id)
  hot_root_append(func, hot_build_drop(func, get))

  let graph = local_graph_build(func, cfg_build(func))

  assert_false(local_graph_local_is_already_ssa(graph, 1))
}

///|
test "local graph rejects loop-carried local as already SSA" {
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

  assert_false(local_graph_local_is_already_ssa(graph, 0))
}

///|
test "local graph rejects no-read and dead-write locals as already SSA" {
  let func = HotFunc::new(
    locals=HotLocals::new(locals=[@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  let live_set = hot_build_local_set(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(1)),
  )
  let live_get = hot_build_local_get(func, 1)
  let dead_set = hot_build_local_set(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(2)),
  )
  hot_root_append(func, live_set)
  hot_root_append(func, hot_build_drop(func, live_get))
  hot_root_append(func, dead_set)

  let graph = local_graph_build(func, cfg_build(func))

  assert_false(local_graph_local_is_already_ssa(graph, 0))
  assert_false(local_graph_local_is_already_ssa(graph, 1))
}

///|
test "local graph marks overwrites as no-merge freshenable but skips already SSA locals" {
  let ssa_func = HotFunc::new(
    locals=HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  let ssa_set = hot_build_local_set(
    ssa_func,
    0,
    hot_build_const_i32(ssa_func, @lib.I32(1)),
  )
  let ssa_get = hot_build_local_get(ssa_func, 0)
  hot_root_append(ssa_func, ssa_set)
  hot_root_append(ssa_func, hot_build_drop(ssa_func, ssa_get))

  let ssa_graph = local_graph_build(ssa_func, cfg_build(ssa_func))

  assert_true(local_graph_local_is_already_ssa(ssa_graph, 0))
  assert_false(local_graph_write_has_merge_influences(ssa_graph, ssa_set))
  assert_false(local_graph_write_is_no_merge_freshenable(ssa_graph, ssa_set))

  let split_func = HotFunc::new(
    locals=HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  let first_set = hot_build_local_set(
    split_func,
    0,
    hot_build_const_i32(split_func, @lib.I32(1)),
  )
  let first_get = hot_build_local_get(split_func, 0)
  let second_set = hot_build_local_set(
    split_func,
    0,
    hot_build_const_i32(split_func, @lib.I32(2)),
  )
  let second_get = hot_build_local_get(split_func, 0)
  hot_root_append(split_func, first_set)
  hot_root_append(split_func, hot_build_drop(split_func, first_get))
  hot_root_append(split_func, second_set)
  hot_root_append(split_func, hot_build_drop(split_func, second_get))

  let split_graph = local_graph_build(split_func, cfg_build(split_func))

  assert_false(local_graph_local_is_already_ssa(split_graph, 0))
  assert_false(local_graph_write_has_merge_influences(split_graph, first_set))
  assert_false(local_graph_write_has_merge_influences(split_graph, second_set))
  assert_true(local_graph_write_is_no_merge_freshenable(split_graph, first_set))
  assert_true(
    local_graph_write_is_no_merge_freshenable(split_graph, second_set),
  )
}

///|
test "local graph marks only non-merge-feeding writes freshenable per original local" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let first_set = hot_build_local_set(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(1)),
  )
  let first_get = hot_build_local_get(func, 1)
  let then_set = hot_build_local_set(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(2)),
  )
  let if_id = hot_build_if(
    func,
    @lib.BlockType::void_(),
    hot_build_local_get(func, 0),
    [then_set],
    else_body=Some([hot_build_nop(func)]),
  )
  let merge_get = hot_build_local_get(func, 1)
  let final_set = hot_build_local_set(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(3)),
  )
  let final_get = hot_build_local_get(func, 1)
  hot_root_append(func, first_set)
  hot_root_append(func, hot_build_drop(func, first_get))
  hot_root_append(func, if_id)
  hot_root_append(func, hot_build_drop(func, merge_get))
  hot_root_append(func, final_set)
  hot_root_append(func, hot_build_drop(func, final_get))

  let graph = local_graph_build(func, cfg_build(func))

  assert_false(local_graph_local_is_already_ssa(graph, 1))
  assert_true(local_graph_get_is_merge(graph, merge_get))
  assert_false(local_graph_get_is_merge(graph, final_get))
  assert_true(local_graph_write_has_merge_influences(graph, first_set))
  assert_true(local_graph_write_has_merge_influences(graph, then_set))
  assert_false(local_graph_write_has_merge_influences(graph, final_set))
  assert_false(local_graph_write_is_no_merge_freshenable(graph, first_set))
  assert_false(local_graph_write_is_no_merge_freshenable(graph, then_set))
  assert_true(local_graph_write_is_no_merge_freshenable(graph, final_set))
}

///|
test "local graph no-merge eligibility treats default and param entries as merge sources" {
  let default_func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let default_set = hot_build_local_set(
    default_func,
    1,
    hot_build_const_i32(default_func, @lib.I32(7)),
  )
  let default_if = hot_build_if(
    default_func,
    @lib.BlockType::void_(),
    hot_build_local_get(default_func, 0),
    [default_set],
    else_body=Some([hot_build_nop(default_func)]),
  )
  let default_merge_get = hot_build_local_get(default_func, 1)
  hot_root_append(default_func, default_if)
  hot_root_append(default_func, hot_build_drop(default_func, default_merge_get))

  let default_graph = local_graph_build(default_func, cfg_build(default_func))
  let default_sources = local_graph_reaching_sources_for_get(
    default_graph, default_merge_get,
  )

  @debug.assert_eq(default_sources.length(), 2)
  assert_true(
    local_graph_test_has_default_entry_source(default_graph, default_sources, 1),
  )
  assert_true(
    local_graph_write_has_merge_influences(default_graph, default_set),
  )
  assert_false(
    local_graph_write_is_no_merge_freshenable(default_graph, default_set),
  )

  let param_func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()]),
  )
  let param_set = hot_build_local_set(
    param_func,
    0,
    hot_build_const_i32(param_func, @lib.I32(9)),
  )
  let param_if = hot_build_if(
    param_func,
    @lib.BlockType::void_(),
    hot_build_local_get(param_func, 0),
    [param_set],
    else_body=Some([hot_build_nop(param_func)]),
  )
  let param_merge_get = hot_build_local_get(param_func, 0)
  hot_root_append(param_func, param_if)
  hot_root_append(param_func, hot_build_drop(param_func, param_merge_get))

  let param_graph = local_graph_build(param_func, cfg_build(param_func))
  let param_sources = local_graph_reaching_sources_for_get(
    param_graph, param_merge_get,
  )

  @debug.assert_eq(param_sources.length(), 2)
  assert_true(
    local_graph_test_has_param_entry_source(param_graph, param_sources, 0),
  )
  assert_true(local_graph_write_has_merge_influences(param_graph, param_set))
  assert_false(
    local_graph_write_is_no_merge_freshenable(param_graph, param_set),
  )
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
