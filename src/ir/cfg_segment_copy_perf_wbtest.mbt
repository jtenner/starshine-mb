///|
fn cfg_segment_copy_push_reference(
  nodes : Array[NodeId],
  start : Int,
  end : Int,
) -> Array[NodeId] {
  let out : Array[NodeId] = []
  for index = start; index < end; index = index + 1 {
    out.push(nodes[index])
  }
  out
}

///|
fn cfg_segment_copy_bench(it : @bench.T, width : Int, reference : Bool) -> Unit {
  let nodes = Array::makei(width + 2, fn(index) { index })
  let expected = cfg_segment_copy_push_reference(nodes, 1, width + 1)
  if cfg_copy_segment_nodes(nodes, 1, width + 1) != expected {
    abort("exact-sized segment copy changed node order")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        cfg_segment_copy_push_reference(nodes, 1, width + 1)
      } else {
        cfg_copy_segment_nodes(nodes, 1, width + 1)
      },
    )
  })
}

///|
test "bench CFG segment copy width=1 push" (it : @bench.T) {
  cfg_segment_copy_bench(it, 1, true)
}

///|
test "bench CFG segment copy width=1 exact" (it : @bench.T) {
  cfg_segment_copy_bench(it, 1, false)
}

///|
test "bench CFG segment copy width=8 push" (it : @bench.T) {
  cfg_segment_copy_bench(it, 8, true)
}

///|
test "bench CFG segment copy width=8 exact" (it : @bench.T) {
  cfg_segment_copy_bench(it, 8, false)
}

///|
test "bench CFG segment copy width=128 push" (it : @bench.T) {
  cfg_segment_copy_bench(it, 128, true)
}

///|
test "bench CFG segment copy width=128 exact" (it : @bench.T) {
  cfg_segment_copy_bench(it, 128, false)
}

///|
test "bench CFG segment copy width=2048 push" (it : @bench.T) {
  cfg_segment_copy_bench(it, 2048, true)
}

///|
test "bench CFG segment copy width=2048 exact" (it : @bench.T) {
  cfg_segment_copy_bench(it, 2048, false)
}
