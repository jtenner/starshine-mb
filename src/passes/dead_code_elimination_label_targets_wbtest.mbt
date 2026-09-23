///|
fn dead_code_elimination_label_targets_test_ctx() -> HotPassContext {
  HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
}

///|
test "dead-code-elimination keeps block targeted only by try_table catch" {
  let source =
    #|(module
    #|  (import "env" "side" (func $side))
    #|  (tag $e)
    #|  (func
    #|    block $handler
    #|      call $side
    #|      try_table (catch_all $handler)
    #|        call $side
    #|      end
    #|      call $side
    #|    end))
  let fixture = @ir.ir_test_build_hot_from_wat(source)
  let func = fixture.hot_func
  let block_id = @ir.hot_root_get(func, 0)
  assert_true(@ir.hot_node_get(func, block_id).op is @ir.HotOp::Block)

  ignore(
    dead_code_elimination_run(
      dead_code_elimination_label_targets_test_ctx(),
      func,
    ),
  )

  assert_true(
    @ir.hot_node_is_live(func, block_id),
    msg="try_table catch target owner must remain live",
  )
  assert_eq(@ir.hot_root_count(func), 1)
  assert_eq(@ir.hot_root_get(func, 0), block_id)
  let optimized = @ir.ir_test_assert_verify_and_lower(fixture)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("block"), msg=pretty)
  assert_true(pretty.contains("try_table"), msg=pretty)
  assert_true(pretty.contains("catch_all"), msg=pretty)
}
