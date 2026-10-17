///|
fn dae2_field_query_children_measure(
  func : @ir.HotFunc,
  node : Int32,
  children : Array[Int32],
  reference : Bool,
) -> UInt64 {
  let start = @lib.trace_now_us()
  for _ in 0..<32768 {
    let changed = if reference {
      dae2_field_query_children_reference(func, node, children)
    } else {
      dae2_field_query_children_candidate(func, node, children)
    }
    if changed {
      abort("unchanged DAE2 child benchmark mutated the span")
    }
  }
  @lib.trace_elapsed_us_since(start)
}

///|
fn dae2_field_query_prefix_measure(
  func : @ir.HotFunc,
  nodes : Array[Int32],
  expected : Array[Int32],
  reference : Bool,
) -> UInt64 {
  let start = @lib.trace_now_us()
  for _ in 0..<4096 {
    let kept = if reference {
      dae2_field_query_prefix_reference(func, nodes)
    } else {
      dae2_field_query_prefix_candidate(func, nodes)
    }
    if kept != expected {
      abort("DAE2 prefix benchmark changed retained effect order")
    }
  }
  @lib.trace_elapsed_us_since(start)
}

///|
#skip("manual paired native-release DAE2 checked field query benchmark")
test "DAE2 checked field queries paired native samples" {
  let (func, add, left, right) = dae2_child_fixture()
  let children = [left, right]
  let nop = @ir.hot_build_nop(func)
  for width in [8, 128] {
    let nodes = Array::makei(width, fn(slot) {
      if slot % 2 == 0 {
        nop
      } else {
        add
      }
    })
    let expected = Array::make(width / 2, add)
    let revision = @ir.hot_revision_current(func)
    for query in [0, 1] {
      let measure = fn(reference : Bool) {
        if query == 0 {
          dae2_field_query_children_measure(func, add, children, reference)
        } else {
          dae2_field_query_prefix_measure(func, nodes, expected, reference)
        }
      }
      ignore(measure(true))
      ignore(measure(false))
      let reference_samples : Array[UInt64] = []
      let candidate_samples : Array[UInt64] = []
      for sample in 0..<9 {
        for
          reference in (if sample % 2 == 0 {
            [true, false]
          } else {
            [false, true]
          }) {
          let elapsed = measure(reference)
          if reference {
            reference_samples.push(elapsed)
          } else {
            candidate_samples.push(elapsed)
          }
        }
      }
      println(
        "dae2 checked field query=\{query} width=\{width} children_repetitions=32768 prefix_repetitions=4096 reference_us=\{reference_samples} candidate_us=\{candidate_samples}",
      )
    }
    assert_eq(@ir.hot_revision_current(func), revision)
    assert_eq(@ir.hot_child_span(func, add), children)
    assert_eq(dae2_field_query_prefix_candidate(func, nodes), expected)
  }
  @ir.hot_verify_core(func).unwrap()
}
