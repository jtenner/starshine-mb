///|
fn code_pushing_test_run_hot(text : String) -> @ir.HotFunc {
  let func = pass_test_lift_first_func(text)
  let ctx = HotPassContext::new(
    code_pushing_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(ctx, func) {
    Ok(_) => func
    Err(err) => abort("expected code-pushing hot pass success, got \{err}")
  }
}

///|
test "code-pushing sinks const local.set into the only using if arm" {
  let func = code_pushing_test_run_hot(
    "(module (func (param i32) (local i32) i32.const 7 local.set 1 local.get 0 if local.get 1 drop end))",
  )

  assert_eq(@ir.hot_root_count(func), 1)
  let if_id = @ir.hot_root_get(func, 0)
  assert_eq(@ir.hot_node_get(func, if_id).op, @ir.HotOp::If)
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  assert_eq(@ir.hot_region_root_count(func, then_ref), 1)
  let kept_use = @ir.hot_region_get(func, then_ref, 0)
  assert_eq(@ir.hot_node_get(func, kept_use).op, @ir.HotOp::Drop)
  let pushed_value = @ir.hot_child_get(func, kept_use, 0)
  assert_eq(@ir.hot_node_get(func, pushed_value).op, @ir.HotOp::Const)
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if @ir.hot_node_is_live(func, node_id) {
      let node = @ir.hot_node_get(func, node_id)
      match node.op {
        @ir.HotOp::LocalSet if node.imm0 == 1 =>
          fail("expected code-pushing to remove sunk local.set")
        @ir.HotOp::LocalGet if node.imm0 == 1 =>
          fail("expected code-pushing to inline sunk local.get")
        _ => ()
      }
    }
  }
}

///|
test "code-pushing sinks const local.set into the only using else arm" {
  let func = code_pushing_test_run_hot(
    "(module (func (param i32) (local i32) i32.const 7 local.set 1 local.get 0 if nop else local.get 1 drop end))",
  )

  assert_eq(@ir.hot_root_count(func), 1)
  let if_id = @ir.hot_root_get(func, 0)
  assert_eq(@ir.hot_node_get(func, if_id).op, @ir.HotOp::If)
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  assert_eq(@ir.hot_region_root_count(func, then_ref), 1)
  let else_ref = @ir.hot_region_else_ref(func, if_id).unwrap()
  assert_eq(@ir.hot_region_root_count(func, else_ref), 1)
  let kept_use = @ir.hot_region_get(func, else_ref, 0)
  assert_eq(@ir.hot_node_get(func, kept_use).op, @ir.HotOp::Drop)
  let pushed_value = @ir.hot_child_get(func, kept_use, 0)
  assert_eq(@ir.hot_node_get(func, pushed_value).op, @ir.HotOp::Const)
}

///|
test "code-pushing duplicates const local.set value into both if arms" {
  let func = code_pushing_test_run_hot(
    "(module (func (param i32) (local i32) i32.const 7 local.set 1 local.get 0 if local.get 1 drop else local.get 1 drop end))",
  )

  assert_eq(@ir.hot_root_count(func), 1)
  let if_id = @ir.hot_root_get(func, 0)
  assert_eq(@ir.hot_node_get(func, if_id).op, @ir.HotOp::If)
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let else_ref = @ir.hot_region_else_ref(func, if_id).unwrap()
  assert_eq(@ir.hot_region_root_count(func, then_ref), 1)
  assert_eq(@ir.hot_region_root_count(func, else_ref), 1)
  let then_drop = @ir.hot_region_get(func, then_ref, 0)
  let else_drop = @ir.hot_region_get(func, else_ref, 0)
  assert_eq(@ir.hot_node_get(func, then_drop).op, @ir.HotOp::Drop)
  assert_eq(@ir.hot_node_get(func, else_drop).op, @ir.HotOp::Drop)
  assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, then_drop, 0)).op,
    @ir.HotOp::Const,
  )
  assert_eq(
    @ir.hot_node_get(func, @ir.hot_child_get(func, else_drop, 0)).op,
    @ir.HotOp::Const,
  )
}

///|
test "code-pushing keeps local.set before if when the local is used after the if" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) i32.const 7 local.set 1 local.get 0 if local.get 1 drop end local.get 1))",
      ["code-pushing"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected guarded code-pushing success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_false(
    trace.any(fn(line) { line.contains("pass[code-pushing]:mutated") }),
    msg=trace.to_string(),
  )
}

///|
test "code-pushing does not sink trapping computations" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (local i32) i32.const 1 i32.const 0 i32.div_s local.set 1 local.get 0 if local.get 1 drop end))",
      ["code-pushing"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected trapping guard code-pushing success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.div_s"), msg=pretty)
  assert_false(
    trace.any(fn(line) { line.contains("pass[code-pushing]:mutated") }),
    msg=trace.to_string(),
  )
}
