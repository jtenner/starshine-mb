///|
fn hot_lift_effect_order_bench(
  it : @bench.T,
  regions : Int,
  reference : Bool,
) -> Unit {
  let func = HotFunc::new()
  let roots : Array[NodeId] = []
  for i in 0..<regions {
    for j in 0..<16 {
      ignore(hot_build_const_i32(func, @lib.I32(j)))
    }
    roots.push(hot_build_call(func, i, [], []))
  }
  let expected = hot_lower_impl_build_first_effect_orders(func)
  let checked : Array[Int] = []
  for root in roots {
    if hot_lift_impl_first_effect_order(func, root, checked) != expected[root] {
      abort("effect-order benchmark mismatch")
    }
  }
  // Queries never mutate the function. A fresh per-function cache is timed.
  it.bench(fn() {
    let cache : Array[Int] = []
    let mut checksum = 0
    for root in roots {
      checksum += if reference {
        hot_lower_impl_build_first_effect_orders(func)[root]
      } else {
        hot_lift_impl_first_effect_order(func, root, cache)
      }
    }
    it.keep(checksum)
  })
}

///|
test "bench lift whole-function effect scans regions=64" (it : @bench.T) {
  hot_lift_effect_order_bench(it, 64, true)
}

///|
test "bench lift completed-root effect queries regions=64" (it : @bench.T) {
  hot_lift_effect_order_bench(it, 64, false)
}

///|
test "bench lift whole-function effect scans regions=256" (it : @bench.T) {
  hot_lift_effect_order_bench(it, 256, true)
}

///|
test "bench lift completed-root effect queries regions=256" (it : @bench.T) {
  hot_lift_effect_order_bench(it, 256, false)
}
