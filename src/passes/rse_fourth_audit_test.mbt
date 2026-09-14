///|
test "fourth audit HOT rse retains reset after caught exit joins explicit branch" {
  let func = rse_test_run_hot(
    "(module (tag $e) (func (param $c i32) (result i32) (local $x i32) (block $out (if (local.get $c) (then (local.set $x (i32.const 1)) (br $out))) (try_table (catch_all $out) (throw $e))) (local.set $x (i32.const 1)) (local.get $x)))",
  )
  let root = @ir.HotRegionRef::root()
  assert_true(
    @ir.hot_node_get(func, @ir.hot_region_get(func, root, 1)).op
    is @ir.HotOp::LocalSet,
  )
}
