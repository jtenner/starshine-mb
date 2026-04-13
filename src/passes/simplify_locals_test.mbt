///|
test "simplify-locals rewrites dead local.set roots" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 1 local.set 0 i32.const 7))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set"))
  assert_true(pretty.contains("drop"))
  assert_true(pretty.contains("I32(7)"))
}

///|
test "simplify-locals rewrites dead local.tee roots" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 1 local.tee 0 drop i32.const 7))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.tee"))
  assert_true(pretty.contains("drop"))
  assert_true(pretty.contains("I32(7)"))
}

///|
test "simplify-locals skips unreachable local defs outside the ssa overlay" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) block unreachable i32.const 1 local.set 0 end i32.const 7))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected unreachable simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(7)"))
}

///|
test "simplify-locals keeps shared tee children that remain referenced" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  let shared = @ir.hot_build_const_i32(func, @lib.I32(1))
  let tee = @ir.hot_build_local_tee(func, 0, shared)
  let drop_tee = @ir.hot_build_drop(func, tee)
  let drop_shared = @ir.hot_build_drop(func, shared)
  @ir.hot_root_append(func, drop_tee)
  @ir.hot_root_append(func, drop_shared)
  let ctx = HotPassContext::new(
    simplify_locals_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected simplify-locals shared-child success, got \{err}")
  }

  assert_true(@ir.hot_node_is_live(func, shared))
}

///|
test "simplify-locals rehomes dead tee control labels before cleanup" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  let carried_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
  )
  let carried_label = @ir.hot_control_node_label(func, carried_block)
  let tee = @ir.hot_build_local_tee(func, 0, carried_block)
  let drop_tee = @ir.hot_build_drop(func, tee)
  @ir.hot_root_append(func, drop_tee)
  @ir.hot_root_append(func, @ir.hot_build_const_i32(func, @lib.I32(7)))
  let ctx = HotPassContext::new(
    simplify_locals_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected simplify-locals dead-tee control success, got \{err}")
  }

  match @ir.hot_node_get(func, tee).op {
    @ir.HotOp::Block => ()
    other => fail("expected tee slot to become a block, got \{other}")
  }
  assert_eq(@ir.hot_control_node_label(func, tee), carried_label)
  assert_eq(@ir.hot_label_owner(func, carried_label), tee)
  assert_false(@ir.hot_node_is_live(func, carried_block))
  match @ir.hot_verify_core(func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected simplify-locals dead-tee control verify success, got \{err}",
      )
  }
}
