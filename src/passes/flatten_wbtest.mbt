///|
test "flatten classifies missing legacy EH repair prerequisites before mutation" {
  let func = @ir.HotFunc::new()
  let empty = flatten_eh_repair_requirement(func)
  assert_true(empty.is_clear())
  @debug.assert_eq(empty.needs_catch_payload_tracking, false)
  @debug.assert_eq(empty.needs_exceptional_transfer_repair, false)
  ignore(@ir.hot_build_node(func, @ir.HotOp::catch_(), @ir.hot_type_void(func)))
  ignore(
    @ir.hot_build_node(func, @ir.HotOp::rethrow(), @ir.hot_type_void(func)),
  )
  let requirement = flatten_eh_repair_requirement(func)
  @debug.assert_eq(requirement.needs_catch_payload_tracking, true)
  @debug.assert_eq(requirement.needs_exceptional_transfer_repair, true)
  assert_false(requirement.is_clear())
  let ctx = HotPassContext::new(
    flatten_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  @debug.assert_eq(flatten_run(ctx, func), HotPassResult::unchanged())
}
