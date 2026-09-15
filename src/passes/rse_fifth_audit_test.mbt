///|
test "fifth audit HOT RSE nondefaultable initialization stays scoped" {
  let func = rse_test_run_hot(
    "(module (type $s (struct)) (func (param (ref $s)) (local (ref $s)) block local.get 0 local.set 1 end local.get 0 local.tee 1 drop local.get 1 drop))",
  )
  let root = @ir.HotRegionRef::root()
  let mut found = false
  for i in 1..<@ir.hot_region_root_count(func, root) {
    let node = @ir.hot_region_get(func, root, i)
    if @ir.hot_node_get(func, node).op is @ir.HotOp::LocalTee {
      found = true
    }
    for j in 0..<@ir.hot_child_count(func, node) {
      if @ir.hot_node_get(func, @ir.hot_child_get(func, node, j)).op
        is @ir.HotOp::LocalTee {
        found = true
      }
    }
  }
  assert_true(found)
}
