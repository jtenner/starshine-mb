///|
test "DAE2 leaf rewrite keeps live values and removes unused pure values" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()]),
  )
  for
    node in [
      @ir.hot_build_const_i32(func, @lib.I32(40)),
      @ir.hot_build_local_get(func, 0),
    ] {
    let data = @ir.hot_node_get(func, node)
    assert_eq(dae2_rewrite_leaf(func, node, data, true), node)
    let unused = dae2_rewrite_leaf(func, node, data, false)
    assert_true(@ir.hot_node_get(func, unused).op is @ir.Nop)
    assert_eq(@ir.hot_node_get(func, node), data)
  }
}

///|
test "DAE2 leaf rewrite preserves observable leaf instructions and discarded results" {
  let input = pass_test_module_from_wat(
    "(module (memory 1) (func memory.size drop unreachable))",
  )
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let count = @ir.hot_node_count(func)
  let mut checked = 0
  for node in 0..<count {
    let data = @ir.hot_node_get(func, node)
    if data.child_count == 0 && !(data.op is @ir.Nop) {
      let replacement = dae2_rewrite_leaf(func, node, data, false)
      assert_true(replacement >= 0)
      if @ir.hot_node_result_arity(func, node) > 0 {
        assert_true(@ir.hot_node_get(func, replacement).op is @ir.Drop)
        assert_eq(@ir.hot_child_get(func, replacement, 0), node)
      } else {
        assert_eq(replacement, node)
      }
      checked += 1
    }
  }
  assert_eq(checked, 2)
}
