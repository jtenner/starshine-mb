///|
test "campaign HOT precompute descriptor branch preserves operand effects" {
  let source =
    #|(module
    #| (rec (type $s (sub (descriptor $d) (struct)))
    #|      (type $d (sub (describes $s) (struct))))
    #| (global $desc (ref (exact $d)) (struct.new $d))
    #| (global $obj (ref $s) (struct.new_default_desc $s (global.get $desc)))
    #| (func (result (ref null $s))
    #|  (block $exit (result (ref null $s))
    #|   (br_on_cast_desc_eq $exit (ref null $s) (ref $s)
    #|    (global.get $obj)
    #|    (block $operand (result (ref (exact $d)))
    #|     (call $effect) (br $operand (global.get $desc))))))
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
  // An effectful descriptor must either remain evaluated or stop the fold.
  assert_false(folded)
}
