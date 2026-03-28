test "dead-code-elimination keeps unreachable in exact cmd inner carrier shape" {
  let mod_ = pass_test_module_from_wat(
    "(module (func (param i32 i32 i32) (result i32) (local i32 i32 i32 i32 i32) (local.set 3 (block $block2 (result i32) (block $block1 (br $block2 (block (result i32) (block $block (if (i32.eq (local.get 0) (i32.const 1)) (then (local.set 4 (local.tee 5 (local.get 1))) (br $block)) (else (local.set 6 (local.tee 7 (local.get 2))) (br $block1)))) (local.get 4)))))) (local.get 3)))",
  )
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dead-code-elimination live carrier repro success, got \{err}",
      )
  }

  let pretty = mod_
    .with_code_sec(@lib.CodeSec::new([@ir.hot_lower_func(func)]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
}
