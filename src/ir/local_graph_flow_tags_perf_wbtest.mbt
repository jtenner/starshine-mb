///|
fn flow_tag_bench_rows(
  func : HotFunc,
  cfg : HotCfg,
  full : Bool,
  reference : Bool,
) -> LocalGraphFlowRows {
  if reference {
    flow_tag_reference_build_reverse_rows(func, cfg, true, full_metadata=full)
  } else {
    local_graph_build_reverse_rows(func, cfg, true, full_metadata=full)
  }
}

///|
fn flow_tag_bench(
  it : @bench.T,
  count : Int,
  immutable : Bool,
  full : Bool,
  reference : Bool,
  extra? : Bool = false,
  cold? : Bool = false,
) -> Unit raise {
  let (func, cfg, _, _) = flow_tag_fixture(count, immutable, extra~)
  flow_tag_assert_rows(func, cfg)
  let revision = hot_revision_current(func)
  let free = func.free_nodes.copy()
  it.bench(fn() {
    if cold {
      let (func, cfg, _, _) = flow_tag_fixture(count, immutable, extra~)
      it.keep(flow_tag_bench_rows(func, cfg, full, reference))
    } else {
      it.keep(flow_tag_bench_rows(func, cfg, full, reference))
    }
  })
  assert_eq(hot_revision_current(func), revision)
  assert_eq(func.free_nodes, free)
}

///|
fn flow_tag_shared_bench(it : @bench.T, reference : Bool) -> Unit raise {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let shared = hot_build_local_get(func, 0)
  let builder = cfg_builder_new(func, true, true)
  let entry = cfg_builder_add_block(builder, [shared], false)
  let exit = cfg_builder_add_block(builder, [shared], false)
  builder.cfg.entry_block = entry
  builder.cfg.exit_block = exit
  cfg_builder_add_edge(builder, entry, exit, CfgEdgeKind::FallthroughEdge)
  cfg_verify(builder.cfg)
  flow_tag_assert_rows(func, builder.cfg)
  it.bench(fn() {
    it.keep(flow_tag_bench_rows(func, builder.cfg, false, reference))
  })
}

///|
test "bench flow admission 8 unused reads reference" (it : @bench.T) {
  flow_tag_bench(it, 8, false, false, true)
}

///|
test "bench flow admission 8 unused reads tags" (it : @bench.T) {
  flow_tag_bench(it, 8, false, false, false)
}

///|
test "bench flow admission 8 unused full reference" (it : @bench.T) {
  flow_tag_bench(it, 8, false, true, true)
}

///|
test "bench flow admission 8 unused full tags" (it : @bench.T) {
  flow_tag_bench(it, 8, false, true, false)
}

///|
test "bench flow admission 8 entry reads reference" (it : @bench.T) {
  flow_tag_bench(it, 8, true, false, true)
}

///|
test "bench flow admission 8 entry reads tags" (it : @bench.T) {
  flow_tag_bench(it, 8, true, false, false)
}

///|
test "bench flow admission 8 entry full reference" (it : @bench.T) {
  flow_tag_bench(it, 8, true, true, true)
}

///|
test "bench flow admission 8 entry full tags" (it : @bench.T) {
  flow_tag_bench(it, 8, true, true, false)
}

///|
test "bench flow admission 64 unused reads reference" (it : @bench.T) {
  flow_tag_bench(it, 64, false, false, true)
}

///|
test "bench flow admission 64 unused reads tags" (it : @bench.T) {
  flow_tag_bench(it, 64, false, false, false)
}

///|
test "bench flow admission 64 unused full reference" (it : @bench.T) {
  flow_tag_bench(it, 64, false, true, true)
}

///|
test "bench flow admission 64 unused full tags" (it : @bench.T) {
  flow_tag_bench(it, 64, false, true, false)
}

///|
test "bench flow admission 64 entry reads reference" (it : @bench.T) {
  flow_tag_bench(it, 64, true, false, true)
}

///|
test "bench flow admission 64 entry reads tags" (it : @bench.T) {
  flow_tag_bench(it, 64, true, false, false)
}

///|
test "bench flow admission 64 entry full reference" (it : @bench.T) {
  flow_tag_bench(it, 64, true, true, true)
}

///|
test "bench flow admission 64 entry full tags" (it : @bench.T) {
  flow_tag_bench(it, 64, true, true, false)
}

///|
test "bench flow admission 256 unused reads reference" (it : @bench.T) {
  flow_tag_bench(it, 256, false, false, true)
}

///|
test "bench flow admission 256 unused reads tags" (it : @bench.T) {
  flow_tag_bench(it, 256, false, false, false)
}

///|
test "bench flow admission 256 entry reads reference" (it : @bench.T) {
  flow_tag_bench(it, 256, true, false, true)
}

///|
test "bench flow admission 256 entry reads tags" (it : @bench.T) {
  flow_tag_bench(it, 256, true, false, false)
}

///|
test "bench flow admission orphans reference" (it : @bench.T) {
  flow_tag_bench(it, 8, false, false, true, extra=true)
}

///|
test "bench flow admission orphans tags" (it : @bench.T) {
  flow_tag_bench(it, 8, false, false, false, extra=true)
}

///|
test "bench flow admission cold reference" (it : @bench.T) {
  flow_tag_bench(it, 8, false, false, true, cold=true)
}

///|
test "bench flow admission cold tags" (it : @bench.T) {
  flow_tag_bench(it, 8, false, false, false, cold=true)
}

///|
test "bench flow admission shared fallback reference" (it : @bench.T) {
  flow_tag_shared_bench(it, true)
}

///|
test "bench flow admission shared fallback tags" (it : @bench.T) {
  flow_tag_shared_bench(it, false)
}
