///|
fn source_order_scratch_bench(it : @bench.T, count : Int) -> Unit {
  let func = HotFunc::new()
  let first = hot_build_call(func, 0, [@lib.ValType::i32()], [])
  let barrier = hot_build_call(func, 1, [], [])
  let consumer = hot_build_drop(func, first)
  for i in 0..<count {
    ignore(hot_build_const_i32(func, @lib.I32(i)))
  }
  let facts = HotSourceOrderFacts::new(func)
  let future = [consumer]
  if hot_source_order_preceding_dependencies(
      func,
      barrier,
      future,
      0,
      None,
      facts,
    ) !=
    [first] {
    abort("source-order benchmark must preserve the carried call")
  }
  it.bench(fn() {
    for _ in 0..<64 {
      it.keep(
        hot_source_order_preceding_dependencies(
          func,
          barrier,
          future,
          0,
          None,
          facts,
        ),
      )
    }
  })
}

///|
test "bench source-order repeated carried query nodes=1024" (it : @bench.T) {
  source_order_scratch_bench(it, 1024)
}

///|
test "bench source-order repeated carried query nodes=4096" (it : @bench.T) {
  source_order_scratch_bench(it, 4096)
}
