///|
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

///|
test "dead-code-elimination preserves typed loop-input drops needed for lowering" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 0
    #|    loop $loop (type $loop_t)
    #|      local.tee 1
    #|      local.get 0
    #|      i32.lt_s
    #|      if
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        br $loop
    #|      end
    #|      local.get 1
    #|      drop
    #|    end
    #|    i32.const 1)
    #|)
  let mod_ = pass_test_module_from_wat(source)
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  let mut loop_id = -1
  for idx = 0; idx < @ir.hot_root_count(func); idx = idx + 1 {
    let root_id = @ir.hot_root_get(func, idx)
    match @ir.hot_node_get(func, root_id).op {
      @ir.HotOp::Loop => {
        loop_id = root_id
        break
      }
      _ => ()
    }
  }
  if loop_id < 0 {
    fail("expected lifted fixture to contain a loop root")
  }
  let loop_body = @ir.hot_region_body_ref(func, loop_id)
  let body_drop = @ir.hot_region_get(
    func,
    loop_body,
    @ir.hot_region_root_count(func, loop_body) - 1,
  )
  let loop_input = @ir.hot_child_get(func, loop_id, 0)
  @ir.hot_child_set(func, body_drop, 0, loop_input)
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
        "expected dead-code-elimination typed loop-input drop repro success, got \{err}",
      )
  }

  let out = mod_.with_code_sec(@lib.CodeSec::new([@ir.hot_lower_func(func)]))
  let pretty = out.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("drop"), msg=pretty)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}
