///|
test "fifth audit descriptor identity observes competing block exits" {
  let source =
    #|(module
    #| (rec (type $s (sub (descriptor $d) (struct)))
    #|      (type $d (sub (describes $s) (struct))))
    #| (global $desc (ref (exact $d)) (struct.new $d))
    #| (global $other (ref (exact $d)) (struct.new $d))
    #| (func (param $choose i32) (result (ref null $s))
    #|  (block $exit (result (ref null $s))
    #|   (br_on_cast_desc_eq $exit (ref null $s) (ref $s)
    #|    (struct.new_default_desc $s
    #|      (block $pick (result (ref (exact $d)))
    #|        (br_if $pick (global.get $other) (local.get $choose))
    #|        drop (br $pick (global.get $desc))))
    #|    (global.get $desc))))
    #| (func $effect unreachable))
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
  let mut folded = false
  for node = 0; node < @ir.hot_node_count(func); node = node + 1 {
    if @ir.hot_node_exact_instr(func, node)
      is Some(@lib.BrOnCastDescEq(_, _, _)) {
      folded = precompute_try_fold_descriptor_branch(ctx, func, node)
    }
  }
  // Distinct descriptor allocations remain possible on the competing exits.
  assert_false(folded)
}
