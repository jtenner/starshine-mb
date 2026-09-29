///|
test "SL read-count admission keeps exact node and density boundaries" {
  for locals_count in [1, 8, 9] {
    let func = sl_get_count_cache_fixture(15, 1, locals_count~)
    assert_eq(@ir.hot_node_count(func), 31)
    assert_true(simplify_locals_new_get_count_cache(func) is None)
    for count in [32, 33] {
      @ir.hot_root_append(func, @ir.hot_build_nop(func))
      assert_eq(@ir.hot_node_count(func), count)
      let cache = simplify_locals_new_get_count_cache(func)
      assert_eq(cache is Some(_), locals_count <= count / 4)
      assert_eq(
        simplify_locals_counts_for_cycle(func, cache),
        simplify_locals_count_local_gets(func),
      )
      @ir.hot_verify_all(func).unwrap()
    }
  }
}

///|
test "SL value-order admission keeps fifteen sixteen and seventeen-root semantics" {
  for (width, expected) in [(12, false), (13, true), (14, true)] {
    let func = sl_first_use_minimum_fixture(width, true)
    let region = @ir.HotRegionRef::root()
    assert_eq(@ir.hot_region_root_count(func, region), width + 3)
    let sinkables = simplify_locals_new_sinkables(func)
    let minimums = simplify_locals_value_order_minimums_for_region(
      sinkables, func, region,
    )
    assert_eq(minimums is Some(_), expected)
    assert_eq(
      simplify_locals_set_first_use_crosses_intervening_local_write(
        func,
        region,
        0,
        1,
        minimums~,
      ),
      simplify_locals_set_first_use_crosses_intervening_local_write(
        func, region, 0, 1,
      ),
    )
    @ir.hot_verify_all(func).unwrap()
  }
}
