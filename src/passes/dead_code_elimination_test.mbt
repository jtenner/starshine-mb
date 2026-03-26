///|
test "dead-code-elimination removes pure drop roots" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 1 drop i32.const 7))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected dead-code-elimination success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("drop"))
  assert_true(pretty.contains("I32(7)"))
}

///|
test "dead-code-elimination removes unreachable roots after return" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 5 return i32.const 9 drop))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected dead-code-elimination success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("return"))
  assert_false(pretty.contains("I32(9)"))
}

///|
test "dead-code-elimination voids dead if results and drops pure arm values" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) local.get 0 if (result i32) i32.const 1 else i32.const 2 end drop i32.const 7))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected dead-code-elimination success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(if (Void)"), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("I32(1)"), msg=pretty)
  assert_false(pretty.contains("I32(2)"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "dead-code-elimination preserves imported calls with dead results" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (type (func (result i32))) (import \"env\" \"ping\" (func (type 0))) (func (result i32) call 0 drop i32.const 7))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected dead-code-elimination success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "dead-code-elimination preserves dead type-index block wrappers" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (type (func (result i32))) (func (result i32) block (type 0) i32.const 1 end drop i32.const 7))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected dead-code-elimination type-index block success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(block (Type 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "dead-code-elimination keeps value roots that feed later roots in void regions" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 if block (result i32) i32.const 1 end local.set 1 end i32.const 7))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected dead-code-elimination to preserve live void-region values, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(block I32"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "dead-code-elimination keeps typed branch wrappers with label-targeted payload branches" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) block (result i32) block local.get 0 if i32.const 1 local.set 1 br 1 end i32.const 0 br 1 end end drop local.get 1))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected dead-code-elimination to preserve typed branch wrappers, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(block I32"), msg=pretty)
  assert_true(pretty.contains("I32(0)"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
}

///|
test "dead-code-elimination preserves branch-skipping result block wrappers under drop" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) block block (result i32) local.get 0 if br 2 else br 2 end i32.const 1000 end drop end i32.const 0))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected dead-code-elimination to preserve branch-skipping result block wrappers, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(block I32"), msg=pretty)
  assert_true(pretty.contains("I32(1000)"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
}

///|
test "dead-code-elimination keeps typed if wrappers with hidden region-label payload branches" {
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    else_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let then_region = @ir.hot_region_then_ref(func, if_id)
  let then_label = @ir.hot_control_node_label(func, then_region.holder)
  @ir.hot_region_replace_body(func, then_region, [
    @ir.hot_build_br(func, then_label, values=[
      @ir.hot_build_const_i32(func, @lib.I32(1)),
    ]),
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, if_id))
  @ir.hot_root_append(func, @ir.hot_build_const_i32(func, @lib.I32(7)))
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match @ir.hot_verify_core(func) {
    Ok(_) => ()
    Err(err) => fail("expected test fixture core verification, got \{err}")
  }
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) => fail("expected test fixture control verification, got \{err}")
  }
  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dead-code-elimination hidden-region-branch success, got \{err}",
      )
  }

  assert_eq(@ir.hot_node_result_arity(func, if_id), 1)
  match @ir.hot_verify_core(func) {
    Ok(_) => ()
    Err(err) => fail("expected typed if wrapper to remain valid, got \{err}")
  }
}

///|
test "dead-code-elimination removes nested unreachable roots after return" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func block return i32.const 9 drop end))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected dead-code-elimination success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("return"), msg=pretty)
  assert_false(pretty.contains("I32(9)"), msg=pretty)
}

///|
test "dead-code-elimination keeps detached label owners live after unreachable-tail pruning" {
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let ret = @ir.hot_build_return(func, [
    @ir.hot_build_const_i32(func, @lib.I32(7)),
  ])
  let dead_block = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  ])
  @ir.hot_root_append(func, ret)
  @ir.hot_root_append(func, dead_block)
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
        "expected dead-code-elimination label-owner pruning success, got \{err}",
      )
  }

  assert_eq(@ir.hot_root_count(func), 1)
  assert_eq(@ir.hot_root_get(func, 0), ret)
  assert_true(@ir.hot_node_is_live(func, dead_block))
  match @ir.hot_verify_core(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected detached label owner to remain core-valid, got \{err}")
  }
}

///|
test "dead-code-elimination deletes detached shared subtrees after unreachable tails" {
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let shared = @ir.hot_build_const_i32(func, @lib.I32(1))
  let drop0 = @ir.hot_build_drop(func, shared)
  let drop1 = @ir.hot_build_drop(func, shared)
  let ret = @ir.hot_build_return(func, [
    @ir.hot_build_const_i32(func, @lib.I32(7)),
  ])
  @ir.hot_root_append(func, ret)
  @ir.hot_root_append(func, drop0)
  @ir.hot_root_append(func, drop1)
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
      fail("expected dead-code-elimination shared-subtree success, got \{err}")
  }

  assert_eq(@ir.hot_root_count(func), 1)
  assert_eq(@ir.hot_root_get(func, 0), ret)
  assert_false(@ir.hot_node_is_live(func, shared))
  assert_false(@ir.hot_node_is_live(func, drop0))
  assert_false(@ir.hot_node_is_live(func, drop1))
}

///|
test "dead-code-elimination voidifies typed loop-body wrappers whose results never reach function exit" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (import \"env\" \"array_length\" (func $moonbit.array_length (param i32) (result i32))) (memory 1) (func $moonbit.string_equal (param $stra i32) (param $strb i32) (result i32) (local $counter i32) local.get $stra call $moonbit.array_length local.get $strb call $moonbit.array_length i32.eq if (result i32) loop (result i32) local.get $counter local.get $stra call $moonbit.array_length i32.lt_s if (result i32) local.get $stra local.get $counter i32.const 1 i32.shl i32.add i32.load16_u offset=8 align=1 local.get $strb local.get $counter i32.const 1 i32.shl i32.add i32.load16_u offset=8 align=1 i32.eq if (result i32) local.get $counter i32.const 1 i32.add local.set $counter br 2 else i32.const 0 return end else i32.const 1 return end end else i32.const 0 return end))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected dead-code-elimination to voidify dead loop-body typing wrappers, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("(if (Void)"), msg=pretty)
  assert_true(pretty.contains("(loop (Void)"), msg=pretty)
  assert_false(pretty.contains("unreachable"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
}
