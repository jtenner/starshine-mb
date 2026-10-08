///|
fn cfg_catch_edges_bench(it : @bench.T, count : Int, reference : Bool) -> Unit {
  let builder = cfg_builder_new(HotFunc::new(), false, false)
  let handler = cfg_builder_add_block(builder, [], true)
  for _ in 0..<count {
    let source = cfg_builder_add_block(builder, [], true)
    cfg_builder_add_edge(builder, source, handler, CfgEdgeKind::ExceptionalEdge)
  }
  cfg_membership_reference(builder.cfg)
  cfg_verify(builder.cfg)
  it.bench(fn() {
    if reference {
      cfg_membership_reference(builder.cfg)
    } else {
      cfg_verify(builder.cfg)
    }
    it.keep(builder.cfg)
  })
}

///|
#skip
test "bench CFG catch hub calls=4 reference" (it : @bench.T) {
  cfg_catch_edges_bench(it, 4, true)
}

///|
#skip
test "bench CFG catch hub calls=4 indexed" (it : @bench.T) {
  cfg_catch_edges_bench(it, 4, false)
}

///|
#skip
test "bench CFG catch hub calls=1024 reference" (it : @bench.T) {
  cfg_catch_edges_bench(it, 1024, true)
}

///|
#skip
test "bench CFG catch hub calls=1024 indexed" (it : @bench.T) {
  cfg_catch_edges_bench(it, 1024, false)
}
