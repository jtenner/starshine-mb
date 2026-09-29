///|
fn hot_lower_input_prefix_reference(
  stack : Array[HotLowerStackValue],
  inputs : ArrayView[NodeId],
) -> Int {
  let max_count = if stack.length() < inputs.length() {
    stack.length()
  } else {
    inputs.length()
  }
  let mut best = 0
  for count = 0; count <= max_count; count = count + 1 {
    let start = stack.length() - count
    let mut ok = true
    for i in 0..<count {
      if stack[start + i].node_id != inputs[i] {
        ok = false
        break
      }
    }
    if ok {
      best = count
    }
  }
  best
}

///|
fn hot_lower_input_prefix_bench(
  it : @bench.T,
  width : Int,
  mode : Int,
  reference : Bool,
) -> Unit {
  let nodes = Array::makei(width, fn(i) { if mode == 1 { i } else { 7 } })
  let inputs = nodes.copy()
  if mode == 2 && width > 0 {
    nodes[width - 1] = 8
  }
  let stack : Array[HotLowerStackValue] = nodes.map(fn(node_id) {
    { node_id, val_type: @lib.ValType::i32(), }
  })
  let expected = hot_lower_input_prefix_reference(stack, inputs[:])
  if hot_lower_impl_matching_input_prefix(stack, inputs[:]) != expected {
    abort("lowering prefix changed")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        hot_lower_input_prefix_reference(stack, inputs[:])
      } else {
        hot_lower_impl_matching_input_prefix(stack, inputs[:])
      },
    )
  })
  if stack.map(fn(value) { value.node_id }) != nodes {
    abort("lowering changed stack")
  }
}

///|
test "bench HOT input prefix width=0 tuple reference" (it : @bench.T) {
  hot_lower_input_prefix_bench(it, 0, 0, true)
}

///|
test "bench HOT input prefix width=0 tuple descending" (it : @bench.T) {
  hot_lower_input_prefix_bench(it, 0, 0, false)
}

///|
test "bench HOT input prefix width=0 distinct reference" (it : @bench.T) {
  hot_lower_input_prefix_bench(it, 0, 1, true)
}

///|
test "bench HOT input prefix width=0 distinct descending" (it : @bench.T) {
  hot_lower_input_prefix_bench(it, 0, 1, false)
}

///|
test "bench HOT input prefix width=0 mismatch reference" (it : @bench.T) {
  hot_lower_input_prefix_bench(it, 0, 2, true)
}

///|
test "bench HOT input prefix width=0 mismatch descending" (it : @bench.T) {
  hot_lower_input_prefix_bench(it, 0, 2, false)
}

///|
test "bench HOT input prefix width=1 tuple reference" (it : @bench.T) {
  hot_lower_input_prefix_bench(it, 1, 0, true)
}

///|
test "bench HOT input prefix width=1 tuple descending" (it : @bench.T) {
  hot_lower_input_prefix_bench(it, 1, 0, false)
}

///|
test "bench HOT input prefix width=1 distinct reference" (it : @bench.T) {
  hot_lower_input_prefix_bench(it, 1, 1, true)
}

///|
test "bench HOT input prefix width=1 distinct descending" (it : @bench.T) {
  hot_lower_input_prefix_bench(it, 1, 1, false)
}

///|
test "bench HOT input prefix width=1 mismatch reference" (it : @bench.T) {
  hot_lower_input_prefix_bench(it, 1, 2, true)
}

///|
test "bench HOT input prefix width=1 mismatch descending" (it : @bench.T) {
  hot_lower_input_prefix_bench(it, 1, 2, false)
}

///|
test "bench HOT input prefix width=32 tuple reference" (it : @bench.T) {
  hot_lower_input_prefix_bench(it, 32, 0, true)
}

///|
test "bench HOT input prefix width=32 tuple descending" (it : @bench.T) {
  hot_lower_input_prefix_bench(it, 32, 0, false)
}

///|
test "bench HOT input prefix width=32 distinct reference" (it : @bench.T) {
  hot_lower_input_prefix_bench(it, 32, 1, true)
}

///|
test "bench HOT input prefix width=32 distinct descending" (it : @bench.T) {
  hot_lower_input_prefix_bench(it, 32, 1, false)
}

///|
test "bench HOT input prefix width=32 mismatch reference" (it : @bench.T) {
  hot_lower_input_prefix_bench(it, 32, 2, true)
}

///|
test "bench HOT input prefix width=32 mismatch descending" (it : @bench.T) {
  hot_lower_input_prefix_bench(it, 32, 2, false)
}

///|
test "bench HOT input prefix width=512 tuple reference" (it : @bench.T) {
  hot_lower_input_prefix_bench(it, 512, 0, true)
}

///|
test "bench HOT input prefix width=512 tuple descending" (it : @bench.T) {
  hot_lower_input_prefix_bench(it, 512, 0, false)
}

///|
test "bench HOT input prefix width=512 distinct reference" (it : @bench.T) {
  hot_lower_input_prefix_bench(it, 512, 1, true)
}

///|
test "bench HOT input prefix width=512 distinct descending" (it : @bench.T) {
  hot_lower_input_prefix_bench(it, 512, 1, false)
}

///|
test "bench HOT input prefix width=512 mismatch reference" (it : @bench.T) {
  hot_lower_input_prefix_bench(it, 512, 2, true)
}

///|
test "bench HOT input prefix width=512 mismatch descending" (it : @bench.T) {
  hot_lower_input_prefix_bench(it, 512, 2, false)
}
