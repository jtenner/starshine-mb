///|
test "campaign precompute descriptor follows constructor fields" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #| (rec (type $box (descriptor $desc) (struct (field (ref (exact $desc)))))
      #|      (type $desc (describes $box) (struct)))
      #| (global $d1 (ref (exact $desc)) (struct.new $desc))
      #| (global $d2 (ref (exact $desc)) (struct.new $desc))
      #| (global $g (ref $box) (struct.new_desc $box (global.get $d1) (global.get $d2))))
    ),
  )
  let ctx = HotPassContext::new(
    precompute_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
    module_ctx=Some(@ir.hot_module_context_from_module(input)),
  )
  assert_true(
    precompute_global_descriptor_identity(
      ctx.module_ctx.unwrap(),
      @lib.GlobalIdx::new(2U),
      0,
    ) ==
    precompute_global_heap_identity(
      ctx.module_ctx.unwrap(),
      @lib.GlobalIdx::new(1U),
      0,
    ),
  )
}

///|
test "campaign HOT precompute descriptor follows constructor fields" {
  let source =
    #|(module
    #| (rec (type $box (descriptor $desc) (struct (field (ref (exact $desc)))))
    #|      (type $desc (describes $box) (struct)))
    #| (global $d1 (ref (exact $desc)) (struct.new $desc))
    #| (global $d2 (ref (exact $desc)) (struct.new $desc))
    #| (func (result (ref $box))
    #|   (struct.new_desc $box (global.get $d1) (global.get $d2))))
  let input = pass_test_module_from_wat(source)
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let ctx = HotPassContext::new(
    precompute_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
    module_ctx=Some(@ir.hot_module_context_from_module(input)),
  )
  let mut found = false
  for node = 0; node < @ir.hot_node_count(func); node = node + 1 {
    if @ir.hot_node_exact_instr(func, node) is Some(@lib.StructNewDesc(_)) {
      found = true
      assert_true(
        precompute_descriptor_identity_for_node(ctx, func, node, 0) ==
        precompute_global_heap_identity(
          ctx.module_ctx.unwrap(),
          @lib.GlobalIdx::new(1U),
          0,
        ),
      )
    }
  }
  assert_true(found)
}
