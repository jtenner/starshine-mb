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
fn code_pushing_expect_op(
  func : @ir.HotFunc,
  node_id : Int,
  expected : String,
) -> Unit {
  let op = @ir.hot_node_get(func, node_id).op
  match expected {
    "nop" =>
      match op {
        @ir.HotOp::Nop => ()
        _ => abort("expected nop")
      }
    "if" =>
      match op {
        @ir.HotOp::If => ()
        _ => abort("expected if")
      }
    "local.set" =>
      match op {
        @ir.HotOp::LocalSet => ()
        _ => abort("expected local.set")
      }
    "local.get" =>
      match op {
        @ir.HotOp::LocalGet => ()
        _ => abort("expected local.get")
      }
    "drop" =>
      match op {
        @ir.HotOp::Drop => ()
        _ => abort("expected drop")
      }
    _ => abort("unknown expected hot op")
  }
}

///|
test "code-pushing sinks const local.set into the only using if arm" {
  let func = code_pushing_test_run_hot(
    "(module (func (param i32) (local i32) i32.const 7 local.set 1 local.get 0 if local.get 1 drop end))",
  )

  assert_eq(@ir.hot_root_count(func), 2)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 0), "nop")
  let if_id = @ir.hot_root_get(func, 1)
  code_pushing_expect_op(func, if_id, "if")
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  assert_eq(@ir.hot_region_root_count(func, then_ref), 2)
  let pushed_set = @ir.hot_region_get(func, then_ref, 0)
  code_pushing_expect_op(func, pushed_set, "local.set")
  assert_eq(@ir.hot_node_get(func, pushed_set).imm0, 1)
  let kept_use = @ir.hot_region_get(func, then_ref, 1)
  code_pushing_expect_op(func, kept_use, "drop")
  let kept_get = @ir.hot_child_get(func, kept_use, 0)
  code_pushing_expect_op(func, kept_get, "local.get")
  assert_eq(@ir.hot_node_get(func, kept_get).imm0, 1)
}

///|
test "code-pushing sinks const local.set into the only using else arm" {
  let func = code_pushing_test_run_hot(
    "(module (func (param i32) (local i32) i32.const 7 local.set 1 local.get 0 if nop else local.get 1 drop end))",
  )

  assert_eq(@ir.hot_root_count(func), 2)
  code_pushing_expect_op(func, @ir.hot_root_get(func, 0), "nop")
  let if_id = @ir.hot_root_get(func, 1)
  code_pushing_expect_op(func, if_id, "if")
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  assert_eq(@ir.hot_region_root_count(func, then_ref), 1)
  let else_ref = @ir.hot_region_else_ref(func, if_id).unwrap()
  assert_eq(@ir.hot_region_root_count(func, else_ref), 2)
  let pushed_set = @ir.hot_region_get(func, else_ref, 0)
  code_pushing_expect_op(func, pushed_set, "local.set")
  assert_eq(@ir.hot_node_get(func, pushed_set).imm0, 1)
  let kept_use = @ir.hot_region_get(func, else_ref, 1)
  code_pushing_expect_op(func, kept_use, "drop")
  let kept_get = @ir.hot_child_get(func, kept_use, 0)
  code_pushing_expect_op(func, kept_get, "local.get")
  assert_eq(@ir.hot_node_get(func, kept_get).imm0, 1)
}

///|
test "code-pushing keeps const local.set when both if arms use it" {
  let func = code_pushing_test_run_hot(
    "(module (func (param i32) (local i32) i32.const 7 local.set 1 local.get 0 if local.get 1 drop else local.get 1 drop end))",
  )

  assert_eq(@ir.hot_root_count(func), 2)
  let kept_set = @ir.hot_root_get(func, 0)
  code_pushing_expect_op(func, kept_set, "local.set")
  assert_eq(@ir.hot_node_get(func, kept_set).imm0, 1)
  let if_id = @ir.hot_root_get(func, 1)
  code_pushing_expect_op(func, if_id, "if")
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let else_ref = @ir.hot_region_else_ref(func, if_id).unwrap()
  assert_eq(@ir.hot_region_root_count(func, then_ref), 1)
  assert_eq(@ir.hot_region_root_count(func, else_ref), 1)
  let then_drop = @ir.hot_region_get(func, then_ref, 0)
  let else_drop = @ir.hot_region_get(func, else_ref, 0)
  code_pushing_expect_op(func, then_drop, "drop")
  code_pushing_expect_op(func, else_drop, "drop")
  code_pushing_expect_op(
    func, @ir.hot_child_get(func, then_drop, 0), "local.get",
  )
  code_pushing_expect_op(
    func, @ir.hot_child_get(func, else_drop, 0), "local.get",
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
