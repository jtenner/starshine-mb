///|
fn rse_test_run_hot(text : String) -> @ir.HotFunc {
  let func = pass_test_lift_first_func(text)
  let ctx = HotPassContext::new(
    rse_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(ctx, func) {
    Ok(_) => func
    Err(err) => abort("expected rse hot pass success, got \{err}")
  }
}

///|
fn rse_expect_op(func : @ir.HotFunc, node_id : Int, expected : String) -> Unit {
  let op = @ir.hot_node_get(func, node_id).op
  match expected {
    "local.set" =>
      match op {
        @ir.HotOp::LocalSet => ()
        other => abort("expected local.set, got \{other}")
      }
    "drop" =>
      match op {
        @ir.HotOp::Drop => ()
        other => abort("expected drop, got \{other}")
      }
    "const" =>
      match op {
        @ir.HotOp::Const => ()
        other => abort("expected const, got \{other}")
      }
    _ => abort("unknown expected op")
  }
}

///|
test "rse replaces same-value local.set shell with drop" {
  let func = rse_test_run_hot(
    "(module (func (local i32) i32.const 1 local.set 0 i32.const 1 local.set 0))",
  )

  @debug.assert_eq(@ir.hot_root_count(func), 2)
  rse_expect_op(func, @ir.hot_root_get(func, 0), "local.set")
  let rewritten = @ir.hot_root_get(func, 1)
  rse_expect_op(func, rewritten, "drop")
  rse_expect_op(func, @ir.hot_child_get(func, rewritten, 0), "const")
}

///|
test "rse replaces same-value local.tee shell with its value" {
  let func = rse_test_run_hot(
    "(module (func (local i32) i32.const 1 local.set 0 i32.const 1 local.tee 0 drop))",
  )

  @debug.assert_eq(@ir.hot_root_count(func), 2)
  rse_expect_op(func, @ir.hot_root_get(func, 0), "local.set")
  let drop = @ir.hot_root_get(func, 1)
  rse_expect_op(func, drop, "drop")
  rse_expect_op(func, @ir.hot_child_get(func, drop, 0), "const")
}

///|
test "rse keeps different overwritten values" {
  let func = rse_test_run_hot(
    "(module (func (local i32) i32.const 1 local.set 0 i32.const 2 local.set 0))",
  )

  @debug.assert_eq(@ir.hot_root_count(func), 2)
  rse_expect_op(func, @ir.hot_root_get(func, 0), "local.set")
  rse_expect_op(func, @ir.hot_root_get(func, 1), "local.set")
}
