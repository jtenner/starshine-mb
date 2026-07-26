///|
fn remove_unused_brs_wbtest_ctx() -> HotPassContext {
  HotPassContext::new(
    remove_unused_brs_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
}

///|
fn remove_unused_brs_wbtest_dump(func : @ir.HotFunc) -> String {
  let out = StringBuilder::new()
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    out.write_string(
      "\nnode=\{node_id} op=\{node.op} children=\{@ir.hot_child_span(func, node_id)}",
    )
    match @ir.hot_branch_target(func, node_id) {
      Some(target) => out.write_string(" target=\{target}")
      None => ()
    }
    if @ir.hot_is_control_node(func, node_id) {
      out.write_string(" label=\{@ir.hot_control_node_label(func, node_id)}")
    }
  }
  out.to_string()
}

///|
test "remove-unused-brs admits literal multivalue blocks consumed only by drops for lowering" {
  let source =
    #|(module
    #|  (type $pair (func (result i32 i64)))
    #|  (func
    #|    (block (type $pair) (result i32 i64)
    #|      (i32.const 11)
    #|      (i64.const 13))
    #|    drop
    #|    drop))
  let fixture = @ir.ir_test_build_hot_from_wat(source)
  let func = fixture.hot_func
  let ctx = remove_unused_brs_wbtest_ctx()

  assert_true(
    remove_unused_brs_has_literal_multivalue_drop_lowering(ctx, func),
    msg="expected exact dropped literal multivalue shape:\n\{remove_unused_brs_wbtest_dump(func)}",
  )
  let result = remove_unused_brs_run(ctx, func)
  assert_true(result.changed)
  let @lib.Func(_, @lib.Expr(body)) = @ir.hot_lower_func_with_options(
    func,
    @ir.HotLowerOptions::new(flatten_unused_result_blocks=true),
  )
  assert_false(
    body.any(fn(instr) { instr is @lib.Block(_, _) }),
    msg="expected RUB lowering to flatten dropped literal multivalue block: \{body}",
  )
}

///|
test "remove-unused-brs nested cleanup admits outward branch wrappers" {
  let source =
    #|(module
    #|  (func
    #|    (drop
    #|      (block (result i32)
    #|        (block
    #|          (i32.const 19)
    #|          (br 1)
    #|          (unreachable))
    #|        (unreachable)))))
  let fixture = @ir.ir_test_build_hot_from_wat(source)
  let func = fixture.hot_func
  let ctx = remove_unused_brs_wbtest_ctx()
  let cfg = @ir.cfg_build(func)

  assert_true(
    remove_unused_brs_prune_one_nested_dead_suffix(
      ctx,
      func,
      cfg,
      @ir.HotRegionRef::root(),
    ),
    msg="expected exact outward branch plus unreachable wrapper to prune:\n\{@ir.ir_test_dump_cfg(func)}\{remove_unused_brs_wbtest_dump(func)}",
  )
}
