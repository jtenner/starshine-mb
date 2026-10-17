///|
fn dae_callsite_value_snapshot_bench(
  it : @bench.T,
  functions : Int32,
  calls : Int32,
  drop_period : Int32,
) -> Unit {
  let source = StringBuilder::new()
  source.write_string(
    "(module (import \"host\" \"mark\" (func $mark (result i32)))",
  )
  let mut dropped = 0
  for _ in 0..<functions {
    source.write_string(" (func (local i32)")
    for index in 0..<calls {
      source.write_string(" call $mark")
      if drop_period > 0 && index % drop_period == 0 {
        source.write_string(" drop")
        dropped += 1
      } else {
        source.write_string(" local.set 0")
      }
    }
    source.write_string(")")
  }
  source.write_string(")")
  let input = pass_test_module_from_wat(source.to_string())
  let snapshot = dae_collect_module_boundary_snapshot(input)
  if snapshot.function_infos[0].calls.length() != functions * calls ||
    snapshot.function_infos[0].dropped_calls.length() != dropped ||
    snapshot.call_facts.direct_calls[0] != functions * calls ||
    snapshot.call_facts.dropped_calls[0] != dropped {
    abort("DAE callsite snapshot fixture has incorrect call facts")
  }
  it.bench(fn() { it.keep(dae_collect_module_boundary_snapshot(input)) })
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench DAE callsite snapshot functions=16 calls=32 dropped=0pct" (
  it : @bench.T,
) {
  dae_callsite_value_snapshot_bench(it, 16, 32, 0)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench DAE callsite snapshot functions=16 calls=32 dropped=25pct" (
  it : @bench.T,
) {
  dae_callsite_value_snapshot_bench(it, 16, 32, 4)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench DAE callsite snapshot functions=16 calls=32 dropped=100pct" (
  it : @bench.T,
) {
  dae_callsite_value_snapshot_bench(it, 16, 32, 1)
}
