///|
fn inl_prediction_alive_reference(
  imports : Int32,
  graph : Array[Array[Int32]],
  used : Array[Bool],
  initial_exact : Array[Bool],
) -> Array[Bool] {
  let total = graph.length()
  let alive = Array::make(total, true)
  let exact_inlineable = initial_exact.copy()
  let calls : Array[Array[Int32]] = []
  for edges in graph {
    let copy : Array[Int32] = []
    copy.append(edges)
    calls.push(copy)
  }
  let max_iterations = total + 1
  let mut iteration = 0
  while iteration < max_iterations {
    let refs = Array::make(total, 0)
    let mut idx = 0
    while idx < total {
      if alive[idx] {
        for target in calls[idx] {
          if target >= 0 && target < total && alive[target] {
            refs[target] += 1
          }
        }
      }
      idx += 1
    }
    let inlined_uses = Array::make(total, 0)
    let inlined_into = Array::make(total, false)
    let mut any = false
    idx = 0
    while idx < total {
      if alive[idx] && inlined_uses[idx] == 0 {
        for target in calls[idx] {
          if target >= imports &&
            target < total &&
            alive[target] &&
            target != idx &&
            !inlined_into[target] &&
            (refs[target] == 1 || exact_inlineable[target]) &&
            !(target < used.length() && used[target]) {
            inlined_uses[target] += 1
            inlined_into[idx] = true
            any = true
          }
        }
      }
      idx += 1
    }
    if !any {
      break
    }
    idx = 0
    while idx < total {
      if inlined_into[idx] {
        calls[idx] = []
        if idx >= 0 && idx < exact_inlineable.length() {
          exact_inlineable[idx] = true
        }
      }
      idx += 1
    }
    idx = imports
    while idx < total {
      if alive[idx] &&
        inlined_uses[idx] > 0 &&
        inlined_uses[idx] == refs[idx] &&
        !(idx < used.length() && used[idx]) {
        alive[idx] = false
      }
      idx += 1
    }
    idx = 0
    while idx < total {
      if alive[idx] {
        let filtered : Array[Int32] = []
        for target in calls[idx] {
          if target >= 0 && target < total && alive[target] {
            filtered.push(target)
          }
        }
        calls[idx] = filtered
        exact_inlineable[idx] = true
      }
      idx += 1
    }
    iteration += 1
  }
  alive
}

///|
test "inlining incremental prediction preserves wave ordering and survivor flags" {
  for pattern in 0..<48 {
    let count = 8
    let graph : Array[Array[Int32]] = Array::makei(count, fn(source) {
      let edges : Array[Int32] = []
      for target in 0..<count {
        if (source * 17 + target * 7 + pattern) % 11 < 2 {
          edges.push(target)
          if (source + pattern) % 3 == 0 {
            edges.push(target)
          }
        }
      }
      edges
    })
    graph[0] = []
    let roots = Array::makei(count, fn(i) { (i + pattern) % 3 == 0 })
    let exact = Array::makei(count, fn(i) { (i + pattern) % 4 == 0 })
    assert_eq(
      inl_prediction_alive(1, graph, roots, exact),
      inl_prediction_alive_reference(1, graph, roots, exact),
    )
  }
}

///|
fn inl_prediction_review_bench(
  it : @bench.T,
  count : Int32,
  reference : Bool,
) -> Unit {
  let graph : Array[Array[Int32]] = Array::makei(count, fn(source) {
    if source + 1 < count {
      [source + 1]
    } else {
      []
    }
  })
  let roots = Array::make(count, false)
  roots[0] = true
  let exact = Array::make(count, false)
  if inl_prediction_alive(0, graph, roots, exact) !=
    inl_prediction_alive_reference(0, graph, roots, exact) {
    abort("prediction survivor flags changed")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        inl_prediction_alive_reference(0, graph, roots, exact)
      } else {
        inl_prediction_alive(0, graph, roots, exact)
      },
    )
  })
}

///|
test "bench inlining prediction copied 16" (it : @bench.T) {
  inl_prediction_review_bench(it, 16, true)
}

///|
test "bench inlining prediction incremental 16" (it : @bench.T) {
  inl_prediction_review_bench(it, 16, false)
}

///|
test "bench inlining prediction copied 1024" (it : @bench.T) {
  inl_prediction_review_bench(it, 1024, true)
}

///|
test "bench inlining prediction incremental 1024" (it : @bench.T) {
  inl_prediction_review_bench(it, 1024, false)
}

///|
test "inlining first round reuses original graph facts without changing cleanup" {
  let input = pass_test_module_from_wat(
    "(module (func $helper (result i32) i32.const 7) (func (export \"run\") (result i32) call $helper))",
  )
  let total = inl_defined_func_count(input)
  let hint = inl_original_graph_info_for_mode(input, true, [0])
  let baseline = inl_run_module_pass_once(
    input,
    Array::make(total, false),
    true,
    None,
    "inlining-optimizing",
    0,
    0,
    2,
    -1,
    20,
    400 * 1024,
    false,
    0,
    true,
    [],
    None,
  )
  let cached = inl_run_module_pass_once(
    input,
    Array::make(total, false),
    true,
    None,
    "inlining-optimizing",
    0,
    0,
    2,
    -1,
    20,
    400 * 1024,
    false,
    0,
    true,
    [],
    None,
    original_graph_info_hint=Some(hint),
  )
  assert_true(baseline.1)
  assert_eq(cached.0, baseline.0)
  assert_eq(cached.1, baseline.1)
  assert_eq(cached.2, baseline.2)
  assert_eq(cached.3, baseline.3)
  @validate.validate_module(cached.0).unwrap()
}
