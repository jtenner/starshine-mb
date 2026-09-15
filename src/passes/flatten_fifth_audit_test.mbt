///|
test "fifth audit HOT flatten preserves concrete subtype result without module context" {
  let input = pass_test_module_from_wat("(module (type $p (sub (struct))) (type $c (sub $p (struct))) (func (param (ref $c)) (result (ref null $p)) local.get 0))")
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let ctx = HotPassContext::new(flatten_descriptor(), @ir.HotAnalysisCache::new(), HotPipelineVerifyPolicy::after_each_pass(), false, fn(_) { () })
  ignore(hot_pass_run(ctx, func).unwrap())
  let @lib.Func(_, @lib.Expr(body)) = @ir.hot_lower_func(func)
  assert_eq(audit_count(body, fn(i) { i is @lib.Drop }), 0)
}
