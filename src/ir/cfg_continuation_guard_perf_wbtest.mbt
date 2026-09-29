///|
fn cfg_continuation_guard_query_bench(
  it : @bench.T,
  count : Int,
  reference : Bool,
) -> Unit {
  let func = HotFunc::new()
  for _ in 0..<count {
    hot_root_append(func, hot_build_nop(func))
  }
  let roots = hot_root_span(func)
  let empty : Array[Array[LabelId]?] = []
  it.bench(fn() {
    it.keep(empty)
    for root in roots {
      it.keep(
        if reference {
          !cfg_expression_continuation_targets(func, root, empty).is_empty()
        } else {
          cfg_expression_has_continuation_targets(func, root, empty)
        },
      )
    }
  })
}

///|
fn cfg_continuation_guard_region_bench(
  it : @bench.T,
  count : Int,
  reference : Bool,
) -> Unit {
  let func = cfg_segment_storage_fixture(count)
  it.bench(fn() {
    let builder = cfg_builder_new(func, true, true)
    it.keep(
      if reference {
        cfg_continuation_guard_reference_segments(
          builder,
          func,
          HotRegionRef::root(),
        ).rows
      } else {
        cfg_builder_region_segments(builder, func, HotRegionRef::root()).rows
      },
    )
    it.keep(builder.cfg)
  })
}

///|
test "bench CFG empty continuation queries=128 list" (it : @bench.T) {
  cfg_continuation_guard_query_bench(it, 128, true)
}

///|
test "bench CFG empty continuation queries=128 bool" (it : @bench.T) {
  cfg_continuation_guard_query_bench(it, 128, false)
}

///|
test "bench CFG empty continuation queries=8192 list" (it : @bench.T) {
  cfg_continuation_guard_query_bench(it, 8192, true)
}

///|
test "bench CFG empty continuation queries=8192 bool" (it : @bench.T) {
  cfg_continuation_guard_query_bench(it, 8192, false)
}

///|
test "bench CFG continuation guard region=64 list" (it : @bench.T) {
  cfg_continuation_guard_region_bench(it, 64, true)
}

///|
test "bench CFG continuation guard region=64 bool" (it : @bench.T) {
  cfg_continuation_guard_region_bench(it, 64, false)
}

///|
test "bench CFG continuation guard region=512 list" (it : @bench.T) {
  cfg_continuation_guard_region_bench(it, 512, true)
}

///|
test "bench CFG continuation guard region=512 bool" (it : @bench.T) {
  cfg_continuation_guard_region_bench(it, 512, false)
}
