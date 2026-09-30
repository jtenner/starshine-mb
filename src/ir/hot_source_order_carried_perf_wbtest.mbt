///|
fn carried_vector_bench(
  it : @bench.T,
  width : Int,
  cold : Bool,
  reference : Bool,
) -> Unit {
  let (func, calls, barrier, roots) = carried_vector_fixture(width)
  let selected_facts = HotSourceOrderFacts::new(func)
  let reference_facts = HotSourceOrderFacts::new(func)
  let reference_scratch = SourceOrderCarriedReferenceScratch::new(
    hot_node_count(func),
  )
  if hot_source_order_preceding_dependencies(
      func,
      barrier,
      roots,
      0,
      None,
      selected_facts,
    ) !=
    calls ||
    source_order_carried_reference_query(
      func,
      barrier,
      roots,
      0,
      None,
      reference_facts,
      reference_scratch,
    ) !=
    calls {
    abort("carried-vector benchmark must preserve every older effectful call")
  }
  let revision = hot_revision_current(func)
  it.bench(fn() {
    if cold {
      // Both paths construct facts and the actual original/selected scratch
      // once. The frozen scratch has no unused new field in the reference.
      let facts = HotSourceOrderFacts::new(func)
      if reference {
        let scratch = SourceOrderCarriedReferenceScratch::new(
          hot_node_count(func),
        )
        it.keep(
          source_order_carried_reference_query(
            func,
            barrier,
            roots,
            0,
            None,
            facts,
            scratch,
          ),
        )
      } else {
        it.keep(
          hot_source_order_preceding_dependencies(
            func,
            barrier,
            roots,
            0,
            None,
            facts,
          ),
        )
      }
    } else if reference {
      it.keep(
        source_order_carried_reference_query(
          func,
          barrier,
          roots,
          0,
          None,
          reference_facts,
          reference_scratch,
        ),
      )
    } else {
      it.keep(
        hot_source_order_preceding_dependencies(
          func,
          barrier,
          roots,
          0,
          None,
          selected_facts,
        ),
      )
    }
  })
  if hot_revision_current(func) != revision {
    abort("carried queries changed their immutable arena")
  }
}

///|
test "bench carried vector width=8 warm reference" (it : @bench.T) {
  carried_vector_bench(it, 8, false, true)
}

///|
test "bench carried vector width=8 warm reused" (it : @bench.T) {
  carried_vector_bench(it, 8, false, false)
}

///|
test "bench carried vector width=8 cold reference" (it : @bench.T) {
  carried_vector_bench(it, 8, true, true)
}

///|
test "bench carried vector width=8 cold reused" (it : @bench.T) {
  carried_vector_bench(it, 8, true, false)
}

///|
test "bench carried vector width=128 warm reference" (it : @bench.T) {
  carried_vector_bench(it, 128, false, true)
}

///|
test "bench carried vector width=128 warm reused" (it : @bench.T) {
  carried_vector_bench(it, 128, false, false)
}

///|
test "bench carried vector width=128 cold reference" (it : @bench.T) {
  carried_vector_bench(it, 128, true, true)
}

///|
test "bench carried vector width=128 cold reused" (it : @bench.T) {
  carried_vector_bench(it, 128, true, false)
}

///|
test "bench carried vector width=1024 warm reference" (it : @bench.T) {
  carried_vector_bench(it, 1024, false, true)
}

///|
test "bench carried vector width=1024 warm reused" (it : @bench.T) {
  carried_vector_bench(it, 1024, false, false)
}

///|
test "bench carried vector width=1024 cold reference" (it : @bench.T) {
  carried_vector_bench(it, 1024, true, true)
}

///|
test "bench carried vector width=1024 cold reused" (it : @bench.T) {
  carried_vector_bench(it, 1024, true, false)
}
