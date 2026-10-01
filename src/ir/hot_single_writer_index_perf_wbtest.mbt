///|
fn single_writer_index_bench(
  it : @bench.T,
  width : Int,
  queries : Int,
  warm : Bool,
  reference : Bool,
) -> Unit {
  let (func, writes, current) = single_writer_index_fixture(width)
  let cached = HotSourceOrderFacts::new(func)
  let control = HotSourceOrderFacts::new(func)
  for write in writes {
    if hot_lower_impl_carried_local_write_conflicts(
        func, write, current, cached,
      ) !=
      source_order_write_scan_reference(func, write, current, control) {
      abort("singleton writer index changed conflict decisions")
    }
  }
  it.bench(fn() {
    let facts = if warm { cached } else { HotSourceOrderFacts::new(func) }
    for query in 0..<queries {
      it.keep(
        if reference {
          source_order_write_scan_reference(
            func,
            writes[query % width],
            current,
            facts,
          )
        } else {
          hot_lower_impl_carried_local_write_conflicts(
            func,
            writes[query % width],
            current,
            facts,
          )
        },
      )
    }
  })
}

///|
test "bench singleton writers width=8 cold reference" (it : @bench.T) {
  single_writer_index_bench(it, 8, 8, false, true)
}

///|
test "bench singleton writers width=8 cold indexed" (it : @bench.T) {
  single_writer_index_bench(it, 8, 8, false, false)
}

///|
test "bench singleton writers width=64 cold reference" (it : @bench.T) {
  single_writer_index_bench(it, 64, 64, false, true)
}

///|
test "bench singleton writers width=64 cold indexed" (it : @bench.T) {
  single_writer_index_bench(it, 64, 64, false, false)
}

///|
test "bench singleton writers width=512 cold reference" (it : @bench.T) {
  single_writer_index_bench(it, 512, 512, false, true)
}

///|
test "bench singleton writers width=512 cold indexed" (it : @bench.T) {
  single_writer_index_bench(it, 512, 512, false, false)
}

///|
test "bench singleton writers width=64 warm reference" (it : @bench.T) {
  single_writer_index_bench(it, 64, 64, true, true)
}

///|
test "bench singleton writers width=64 warm indexed" (it : @bench.T) {
  single_writer_index_bench(it, 64, 64, true, false)
}

///|
test "bench singleton writer width=512 single cold reference" (it : @bench.T) {
  single_writer_index_bench(it, 512, 1, false, true)
}

///|
test "bench singleton writer width=512 single cold indexed" (it : @bench.T) {
  single_writer_index_bench(it, 512, 1, false, false)
}
