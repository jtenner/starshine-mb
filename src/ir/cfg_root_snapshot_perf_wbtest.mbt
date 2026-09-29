///|
fn cfg_root_snapshot_bench(it : @bench.T, width : Int, expanded : Bool) -> Unit {
  let func = cfg_root_snapshot_fixture(width, 16)
  hot_verify_all(func).unwrap()
  let cfg = cfg_build(func, expand_operand_control=expanded)
  if cfg.region_roots.length() != width + 1 {
    abort("CFG changed region-root registration")
  }
  it.bench(fn() { it.keep(cfg_build(func, expand_operand_control=expanded)) })
}

///|
test "bench CFG root mapping roots=8 expanded" (it : @bench.T) {
  cfg_root_snapshot_bench(it, 8, true)
}

///|
test "bench CFG root mapping roots=64 expanded" (it : @bench.T) {
  cfg_root_snapshot_bench(it, 64, true)
}

///|
test "bench CFG root mapping roots=64 root-only" (it : @bench.T) {
  cfg_root_snapshot_bench(it, 64, false)
}
