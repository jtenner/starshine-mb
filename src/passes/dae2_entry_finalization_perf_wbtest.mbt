///|
fn dae2_entry_finalization_bench(
  it : @bench.T,
  depth : Int,
  two_writes? : Bool = true,
) -> Unit {
  let (func, _) = dae2_entry_finalization_fixture(depth, two_writes~)
  let expected = dae2_entry_finalization_reference(func)
  let revision = @ir.hot_revision_current(func)
  if dae2_entry_read_sources(func) != expected {
    abort("entry finalization changed source rows or admission")
  }
  it.bench(fn() { it.keep(dae2_entry_read_sources(func)) })
  if dae2_entry_read_sources(func) != expected ||
    @ir.hot_revision_current(func) != revision {
    abort("entry finalization benchmark changed its immutable snapshot")
  }
}

///|
test "bench DAE2 entry finalization two writes depth0" (it : @bench.T) {
  dae2_entry_finalization_bench(it, 0)
}

///|
test "bench DAE2 entry finalization two writes depth32" (it : @bench.T) {
  dae2_entry_finalization_bench(it, 32)
}

///|
test "bench DAE2 entry finalization two writes depth128" (it : @bench.T) {
  dae2_entry_finalization_bench(it, 128)
}

///|
test "bench DAE2 entry finalization one write depth32" (it : @bench.T) {
  dae2_entry_finalization_bench(it, 32, two_writes=false)
}
