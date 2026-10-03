///|
fn node0_bench(it : @bench.T, kind : Int, before : Bool) -> Unit raise {
  let (func, op, ty, imm0, imm1) = node0_fixture(kind)
  let expected = hot_build_node(func, op, ty, imm0~, imm1~)
  let actual = hot_build_node0(func, op, ty, imm0~, imm1~)
  assert_eq(
    { ..hot_node_get(func, actual), order: expected, },
    hot_node_get(func, expected),
  )
  // No retained node IDs or roots. Reset logical node lengths while retaining
  // capacity so each timed sample performs identical bounded append work.
  func.nodes.clear()
  func.deleted_nodes.clear()
  it.bench(fn() {
    let node = if before {
      hot_build_node(func, op, ty, imm0~, imm1~)
    } else {
      hot_build_node0(func, op, ty, imm0~, imm1~)
    }
    it.keep(hot_node_get(func, node).imm0)
    func.nodes.clear()
    func.deleted_nodes.clear()
  })
}

///|
test "bench zero-child Nop before" (it : @bench.T) {
  node0_bench(it, 0, true)
}

///|
test "bench zero-child Nop current" (it : @bench.T) {
  node0_bench(it, 0, false)
}

///|
test "bench zero-child Const before" (it : @bench.T) {
  node0_bench(it, 1, true)
}

///|
test "bench zero-child Const current" (it : @bench.T) {
  node0_bench(it, 1, false)
}

///|
test "bench zero-child RefNull before" (it : @bench.T) {
  node0_bench(it, 3, true)
}

///|
test "bench zero-child RefNull current" (it : @bench.T) {
  node0_bench(it, 3, false)
}
