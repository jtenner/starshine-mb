///|
test "precompute inlines a typed identity block without deleting its entry producer" {
  let func = pass_test_lift_first_func(
    "(module (type $t (func (param i32) (result i32))) (func (param i32) (result i32) i32.const 1 local.get 0 block (type $t) end i32.add))",
  )
  let parent = @ir.hot_root_get(func, 0)
  assert_true(@ir.hot_node_exact_instr(func, parent) is Some(@lib.I32Add))
  let holder = @ir.hot_child_get(func, parent, 1)
  assert_eq(@ir.hot_node_get(func, holder).imm1, 1)
  let label = @ir.hot_control_node_label(func, holder)
  let value = @ir.hot_region_get(func, @ir.hot_region_body_ref(func, holder), 0)
  assert_eq(@ir.hot_child_get(func, holder, 0), value)
  let ctx = HotPassContext::new(
    precompute_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  assert_true(
    precompute_try_inline_transparent_value_block_child(
      ctx,
      func,
      parent,
      pass_compute_label_used(func),
      @ir.hot_node_use_counts_build(func),
    ),
  )
  assert_eq(@ir.hot_child_get(func, parent, 1), value)
  assert_true(@ir.hot_node_is_live(func, value))
  assert_false(@ir.hot_node_is_live(func, holder))
  assert_false(@ir.hot_label_is_live(func, label))
  @ir.hot_verify_core(func).unwrap()
  @ir.hot_verify_control(func).unwrap()
}

///|
test "precompute removes all transparent operands in one phase and retains call order" {
  let input = pass_test_module_from_wat(
    "(module (import \"h\" \"a\" (func $a (result i32))) (import \"h\" \"b\" (func $b (result i32))) (import \"h\" \"sink\" (func $sink (param i32 i32 i32) (result i32))) (func (result i32) (call $sink (block (result i32) (call $a)) (block (result i32) (call $b)) (block (result i32) (call $a)))))",
  )
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(3U))
  let parent = @ir.hot_root_get(func, 0)
  let cleanup = PrecomputeTransparentBlockCleanup::new()
  let ctx = HotPassContext::new(
    precompute_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  assert_true(
    precompute_try_inline_transparent_value_block_child(
      ctx,
      func,
      parent,
      pass_compute_label_used(func),
      @ir.hot_node_use_counts_build(func),
      cleanup=Some(cleanup),
    ),
  )
  for slot in 0..<3 {
    assert_true(
      @ir.hot_node_get(func, @ir.hot_child_get(func, parent, slot)).op
      is @ir.HotOp::Call,
    )
  }
  precompute_finish_transparent_block_cleanup(func, cleanup)
  @ir.hot_verify_core(func).unwrap()
  @ir.hot_verify_control(func).unwrap()
  let lowered = @ir.hot_lower_func(func)
  @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([lowered]))).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = lowered
  let calls : Array[UInt] = []
  for instr in body {
    match instr {
      @lib.Call(@lib.FuncIdx(index)) => calls.push(index)
      _ => ()
    }
  }
  assert_eq(calls, [0U, 1U, 0U, 2U])
}
