///|
test "hunt r1 code pushing keeps global snapshot before escaping branch" {
  let func = pass_test_lift_first_func(
    (
      #|(module
      #|  (global i32 (i32.const 9))
      #|  (func (export "f") (param $c i32) (result i32) (local $x i32)
      #|    (block $out
      #|      (local.set $x (global.get 0))
      #|      (br_if $out (local.get $c))
      #|      (drop (local.get $x)))
      #|    (local.get $x)))
    ),
  )
  let block_id = @ir.hot_root_get(func, 0)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  let original_set = @ir.hot_region_get(func, body_ref, 0)
  assert_true(@ir.hot_node_get(func, original_set).op is @ir.HotOp::LocalSet)
  let ctx = HotPassContext::new(
    code_pushing_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("code-pushing failed: \{err}")
  }
  // f(1) must return 9. Moving the write below br_if makes it return 0.
  assert_true(@ir.hot_node_get(func, original_set).op is @ir.HotOp::LocalSet)
}

///|
test "hunt r1 code pushing dispatcher preserves global snapshot before branch" {
  let input = pass_test_module_from_wat(
    "(module (global i32 (i32.const 9)) (func (export \"f\") (param i32) (result i32) (local i32) (block (local.set 1 (global.get 0)) (br_if 0 (local.get 0)) (drop (local.get 1))) (local.get 1)))",
  )
  assert_true(@validate.validate_module(input) is Ok(_))
  let output = match run_hot_pipeline(input, HotPipelineOptions::new(), [
    "code-pushing",
  ]) {
    Ok(output) => output
    Err(error) => fail("pipeline failed: \{error}")
  }
  assert_true(@validate.validate_module(output) is Ok(_))
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  match body[0] {
    @lib.Block(_, @lib.Expr(nested)) => {
      let mut written = false
      for instr in nested {
        match instr {
          @lib.LocalSet(@lib.LocalIdx(1U)) => written = true
          @lib.BrIf(_) => assert_true(written, msg="branch skips snapshot write")
          _ => ()
        }
      }
    }
    _ => fail("expected outer block")
  }
}
