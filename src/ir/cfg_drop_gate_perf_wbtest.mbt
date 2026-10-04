///|
fn cfg_drop_gate_bench(it : @bench.T, width : Int, drops : Bool) -> Unit raise {
  let func = HotFunc::new()
  for i in 0..<width {
    hot_root_append(
      func,
      if drops {
        hot_build_drop(func, hot_build_const_i32(func, @lib.I32(i)))
      } else {
        hot_build_nop(func)
      },
    )
  }
  hot_verify_all(func).unwrap()
  it.bench(fn() {
    let builder = cfg_builder_new(func, true, true)
    it.keep(cfg_builder_region_segments(builder, func, HotRegionRef::root()))
    it.keep(builder.cfg)
  })
}

///|
test "bench CFG drop gate tiny plain" (it : @bench.T) {
  cfg_drop_gate_bench(it, 8, false)
}

///|
test "bench CFG drop gate wide plain" (it : @bench.T) {
  cfg_drop_gate_bench(it, 512, false)
}

///|
test "bench CFG drop gate tiny drops" (it : @bench.T) {
  cfg_drop_gate_bench(it, 8, true)
}

///|
test "bench CFG drop gate wide drops" (it : @bench.T) {
  cfg_drop_gate_bench(it, 512, true)
}
