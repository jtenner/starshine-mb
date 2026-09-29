///|
fn tuple_prepare_opcode_fixture(
  width : Int,
  results : Array[@lib.ValType],
) -> (@ir.HotFunc, Int) {
  let func = @ir.HotFunc::new()
  for index in 0..<width {
    @ir.hot_root_append(
      func,
      @ir.hot_build_drop(func, @ir.hot_build_const_i32(func, @lib.I32(index))),
    )
  }
  let values : Array[Int] = []
  for result in results {
    values.push(
      if result == @lib.ValType::i64() {
        @ir.hot_build_const_i64(func, @lib.I64(9L))
      } else {
        @ir.hot_build_const_i32(func, @lib.I32(7))
      },
    )
  }
  let tuple = @ir.hot_build_tuple_make(func, results, values)
  @ir.hot_root_append(func, tuple)
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_results(func, results))
  (func, tuple)
}

///|
test "tuple preparation preserves scalar nodes and promotes only multivalue tuples" {
  for
    results in [
      [],
      [@lib.ValType::i32()],
      [@lib.ValType::i32(), @lib.ValType::i64()],
    ] {
    let (func, tuple) = tuple_prepare_opcode_fixture(4, results)
    let state : HotPipelineLowerState = {
      next_type_sec: None,
      type_sec_changed: false,
    }
    let before = @ir.hot_node_count(func)
    run_hot_pipeline_prepare_tuple_make_lowering(func, state)
    assert_eq(@ir.hot_node_count(func), before)
    for root in 0..<4 {
      assert_true(
        @ir.hot_node_op(func, @ir.hot_root_get(func, root)) is @ir.Drop,
      )
    }
    if results.length() > 1 {
      assert_true(@ir.hot_node_op(func, tuple) is @ir.Block)
      assert_true(state.type_sec_changed)
    } else {
      assert_true(@ir.hot_node_op(func, tuple) is @ir.TupleMake)
      assert_false(state.type_sec_changed)
    }
    assert_eq(
      @ir.hot_type_results(func, @ir.hot_node_type(func, tuple)),
      results,
    )
    @ir.hot_verify_all(func).unwrap()
  }
}
