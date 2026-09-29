///|
fn typed_control_operand_fixture(source : String) -> (@ir.HotFunc, Int) raise {
  let module_ = pass_test_module_from_wat(source)
  @validate.validate_module(module_).unwrap()
  let func = @ir.hot_lift_func(module_, @lib.FuncIdx::new(0U))
  for node in 0..<@ir.hot_node_count(func) {
    if @ir.hot_node_get(func, node).op is @ir.HotOp::If {
      // Cleanup may remove unused entry-value roots from trapping arms. The
      // header still evaluates them before the condition, preserving effects.
      @ir.hot_region_replace_body(func, @ir.hot_region_then_ref(func, node), [
        @ir.hot_build_unreachable(func),
      ])
      @ir.hot_region_replace_body(
        func,
        @ir.hot_region_else_ref(func, node).unwrap(),
        [@ir.hot_build_unreachable(func)],
      )
      @ir.hot_verify_core(func).unwrap()
      @ir.hot_verify_control(func).unwrap()
      @validate.validate_module(
        module_.with_code_sec(@lib.CodeSec::new([@ir.hot_lower_func(func)])),
      ).unwrap()
      return (func, node)
    }
  }
  fail("fixture has no conditional")
}

///|
test "pass operand ranges include typed conditional entry operands" {
  let (func, node) = typed_control_operand_fixture(
    "(module (func (param i32 i32) local.get 1 local.get 0 if (param i32) unreachable else unreachable end))",
  )
  assert_eq(pass_value_operand_count(func, node), 2)
  let data = @ir.hot_node_get(func, node)
  assert_eq(pass_value_operand_slot(data, 0), 3)
  assert_eq(pass_value_operand_slot(data, 1), 0)
  assert_false(simplify_locals_is_region_child_slot(func, node, 3))
  assert_true(simplify_locals_is_region_child_slot(func, node, 1))
  assert_true(simplify_locals_is_region_child_slot(func, node, 2))
}

///|
test "local read hazards include typed entries even when both arms discard the stack" {
  let (func, node) = typed_control_operand_fixture(
    "(module (func (param i32 i32) local.get 1 local.get 0 if (param i32) unreachable else unreachable end))",
  )
  assert_true(simplify_locals_node_reads_local(func, node, 1))
  assert_true(hso_subtree_touches_local(func, node, 1))
  assert_false(simplify_locals_node_reads_local(func, node, 2))
}

///|
test "heap store motion sees global writes in typed entries before trapping arms" {
  let (func, node) = typed_control_operand_fixture(
    "(module (global $g (mut i32) (i32.const 0)) (func (param i32) block (result i32) i32.const 7 global.set $g i32.const 9 end local.get 0 if (param i32) unreachable else unreachable end))",
  )
  assert_true(hso_subtree_has_global_write(func, node))
  assert_true(hso_subtree_accesses_global(None, func, node, 0, true))
}

///|
test "demoted typed conditionals retain their entry operand range and hazards" {
  let (func, node) = typed_control_operand_fixture(
    "(module (func (param i32 i32) local.get 1 local.get 0 if (param i32) unreachable else unreachable end))",
  )
  let then_region = @ir.hot_region_then_ref(func, node)
  let roots = Array::makei(@ir.hot_region_root_count(func, then_region), fn(
    index,
  ) {
    @ir.hot_region_get(func, then_region, index)
  })
  @ir.hot_control_demote_if_to_block(func, node, roots)
  assert_eq(pass_value_operand_count(func, node), 1)
  assert_false(simplify_locals_is_region_child_slot(func, node, 0))
  assert_true(simplify_locals_node_reads_local(func, node, 1))
  assert_true(hso_subtree_touches_local(func, node, 1))
}

///|
test "precompute tail trimming keeps a typed entry producer referenced by its header" {
  let module_ = pass_test_module_from_wat(
    "(module (global $g (mut i32) (i32.const 0)) (func (param i32) block (result i32) i32.const 7 global.set $g i32.const 9 end local.get 0 if (param i32) unreachable else unreachable end))",
  )
  let func = @ir.hot_lift_func(module_, @lib.FuncIdx::new(0U))
  let ctx = HotPassContext::new(
    precompute_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
    module_ctx=Some(@ir.hot_module_context_from_module(module_)),
  )
  let mut entry = -1
  let debris = @ir.hot_build_nop(func)
  for node in 0..<@ir.hot_node_count(func) {
    if @ir.hot_node_get(func, node).op is @ir.HotOp::If {
      entry = @ir.hot_child_get(func, node, 3)
      @ir.hot_region_replace_body(func, @ir.hot_region_then_ref(func, node), [
        @ir.hot_build_unreachable(func),
        entry,
        debris,
      ])
      @ir.hot_region_replace_body(
        func,
        @ir.hot_region_else_ref(func, node).unwrap(),
        [@ir.hot_build_unreachable(func)],
      )
    }
  }
  assert_true(entry >= 0)
  assert_true(
    precompute_simplify_region_roots(ctx, func, @ir.HotRegionRef::root()),
  )
  assert_true(@ir.hot_node_is_live(func, entry))
  assert_false(@ir.hot_node_is_live(func, debris))
  assert_true(hso_subtree_has_global_write(func, entry))
  @ir.hot_verify_core(func).unwrap()
  @ir.hot_verify_control(func).unwrap()
  @validate.validate_module(
    module_.with_code_sec(@lib.CodeSec::new([@ir.hot_lower_func(func)])),
  ).unwrap()
}
