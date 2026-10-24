///|
test "DCE branch cache drops detached incoming branches" {
  let input = pass_test_module_from_wat("(module (func (block br 0)))")
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let block = @ir.hot_root_get(func, 0)
  let label = @ir.hot_control_node_label(func, block)
  let body = @ir.hot_region_body_ref(func, block)
  let cache = DeadCodeEliminationBranchUserCache::new()
  assert_true(
    dead_code_elimination_require_has_incoming_branches_by_label(cache, func)[label],
  )
  assert_true(dead_code_elimination_require_has_any_branch(cache, func))
  assert_eq(
    dead_code_elimination_require_branch_users_by_label(cache, func)[label].length(),
    1,
  )
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  let node_uses = DeadCodeEliminationNodeUseCache::new(
    func,
    defer_deletion=true,
  )
  ignore(
    dead_code_elimination_remove_roots(ctx, func, cache, node_uses, body, 0, 1),
  )
  assert_false(
    dead_code_elimination_require_has_incoming_branches_by_label(cache, func)[label],
  )
  assert_false(dead_code_elimination_require_has_any_branch(cache, func))
  assert_eq(
    dead_code_elimination_require_branch_users_by_label(cache, func)[label].length(),
    0,
  )
}

///|
test "DCE branch cache grows with new HOT nodes" {
  let input = pass_test_module_from_wat("(module (func (block)))")
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let block = @ir.hot_root_get(func, 0)
  let label = @ir.hot_control_node_label(func, block)
  let cache = DeadCodeEliminationBranchUserCache::new()
  assert_false(dead_code_elimination_require_has_any_branch(cache, func))
  let branch = @ir.hot_build_br(func, label)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, block), [
    branch,
  ])
  assert_true(dead_code_elimination_require_has_any_branch(cache, func))
}
