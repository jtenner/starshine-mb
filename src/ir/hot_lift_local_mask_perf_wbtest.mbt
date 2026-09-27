///|
fn hot_lift_local_mask_benchmark(
  it : @bench.T,
  depth : Int,
  cached : Bool,
) -> Unit {
  let (func, value) = hot_lift_local_mask_fixture(depth)
  let masks = HotLiftLocalAccessMasks::new()
  for local in 0..<128 {
    for is_write in [false, true] {
      if hot_lift_impl_value_conflicts_with_local_access(
          func,
          value,
          local,
          is_write,
          masks=Some(masks),
        ) !=
        hot_lift_impl_value_conflicts_with_local_access(
          func, value, local, is_write,
        ) {
        abort("local mask changed dependency proof")
      }
    }
  }
  it.bench(fn() {
    // Include first-use summary construction in every timed batch.
    let masks = if cached { Some(HotLiftLocalAccessMasks::new()) } else { None }
    for query in 0..<128 {
      it.keep(
        hot_lift_impl_value_conflicts_with_local_access(
          func,
          value,
          1 + query % 16,
          true,
          masks~,
        ),
      )
    }
  })
}

///|
test "bench lift dependency walks depth=32 queries=128" (it : @bench.T) {
  hot_lift_local_mask_benchmark(it, 32, false)
}

///|
test "bench lift dependency masks depth=32 queries=128" (it : @bench.T) {
  hot_lift_local_mask_benchmark(it, 32, true)
}

///|
test "bench lift dependency walks depth=128 queries=128" (it : @bench.T) {
  hot_lift_local_mask_benchmark(it, 128, false)
}

///|
test "bench lift dependency masks depth=128 queries=128" (it : @bench.T) {
  hot_lift_local_mask_benchmark(it, 128, true)
}
