///|
fn sl_first_use_minimum_fixture(width : Int, hazard : Bool) -> @ir.HotFunc {
  let wat = ["(module (func (param i32) (result i32) (local i32 i32)"]
  if hazard {
    wat.push("i32.const 9")
  }
  wat.push("local.get 0 local.set 1 local.get 1 local.set 2")
  for _ in 0..<width {
    wat.push("i32.const 7 drop")
  }
  wat.push(if hazard { "local.get 2 i32.add))" } else { "local.get 0))" })
  @ir.hot_lift_func(
    pass_test_module_from_wat(wat.join(" ")),
    @lib.FuncIdx::new(0U),
  )
}

///|
test "SL minimum value-order facts share unchanged queries and invalidate on edits" {
  let func = sl_first_use_minimum_fixture(16, true)
  let cache = SimplifyLocalsValueOrderMinimums::new()
  let root = @ir.hot_root_get(func, @ir.hot_root_count(func) - 1)
  let queries = [0]
  let first = cache.minimum(func, root, full_queries=Some(queries))
  assert_true(first < root)
  assert_eq(cache.minimum(func, root, full_queries=Some(queries)), first)
  assert_eq(queries[0], 1)
  let replacement = @ir.hot_build_const_i32(func, @lib.I32(11))
  @ir.hot_replace_node(func, root, @ir.hot_node_get(func, replacement))
  assert_eq(cache.minimum(func, root, full_queries=Some(queries)), root)
  assert_eq(queries[0], 2)
  @ir.hot_verify_all(func).unwrap()
}

///|
test "SL first-use queries avoid per-later-root visited rows while retaining stack hazards" {
  for hazard in [false, true] {
    let func = sl_first_use_minimum_fixture(16, hazard)
    let rows = [0]
    let actual = simplify_locals_set_first_use_crosses_intervening_local_write(
      func,
      @ir.HotRegionRef::root(),
      0,
      1,
      minimums=Some(SimplifyLocalsValueOrderMinimums::new()),
      later_seen_rows=Some(rows),
    )
    assert_eq(actual, hazard)
    assert_eq(rows[0], 0)
    @ir.hot_verify_all(func).unwrap()
  }
}

///|
test "SL cached minimum predicates match complete structured traversal at every threshold" {
  for
    source in [
      "(module (func (param i32) (result i32) (local i32) local.get 0 if (result i32) i32.const 7 else local.get 0 i32.const 1 i32.add end))",
      "(module (func (param i32) (result i32) (local i32) local.get 0 loop (param i32) (result i32) local.set 1 local.get 1 i32.const 1 i32.sub local.tee 1 local.get 1 br_if 0 end))",
      "(module (func (param i32) (result i32) block (result i32) try_table (result i32) local.get 0 end end))",
    ] {
    let input = pass_test_module_from_wat(source)
    @validate.validate_module(input).unwrap()
    let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
    let cache = SimplifyLocalsValueOrderMinimums::new()
    for node in 0..<@ir.hot_node_count(func) {
      let minimum = cache.minimum(func, node)
      for before in 0..<(@ir.hot_node_count(func) + 1) {
        assert_eq(
          minimum < before,
          simplify_locals_node_contains_value_before(
            func,
            node,
            before,
            Array::make(@ir.hot_node_count(func), false),
          ),
        )
      }
    }
    @ir.hot_verify_all(func).unwrap()
  }
}
