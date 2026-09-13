///|
test "campaign HOT rse isolates exceptional entry state" {
  let func = rse_test_run_hot(
    (
      #|(module (tag $e) (func (param i32) (result i32) (local i32)
      #| (try (do local.get 0 if throw $e end i32.const 1 local.set 1)
      #|      (catch_all i32.const 1 local.set 1))
      #| local.get 1))
    ),
  )
  let try_id = @ir.hot_region_get(func, @ir.HotRegionRef::root(), 0)
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  let mut has_write = false
  for slot = 0
      slot < @ir.hot_region_root_count(func, catch_ref)
      slot = slot + 1 {
    let node = @ir.hot_node_get(func, @ir.hot_region_get(func, catch_ref, slot))
    if node.op is @ir.HotOp::LocalSet {
      has_write = true
    }
  }
  assert_true(has_write)
}
