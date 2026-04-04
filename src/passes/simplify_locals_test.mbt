///|
test "simplify-locals sinks a single-use local.set into the later get" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 1 local.set 0 local.get 0))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals sink success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set"))
  assert_false(pretty.contains("local.get"))
  assert_true(pretty.contains("I32(1)"))
}

///|
test "simplify-locals sinks a multi-use local through a tee" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 1 local.set 0 local.get 0 local.get 0 i32.add))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals tee success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set"))
  assert_true(pretty.contains("local.tee"))
}

///|
test "simplify-locals keeps multivalue local-set producers out of tee rewrites" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32 i32) (result i32 i32 i32) local.get 0 local.get 1 local.get 2) (func (param i32 i32 i32) (result i32) (local i32 i32 i32) local.get 0 local.get 1 local.get 2 call 0 local.set 5 local.set 4 local.set 3 local.get 3 local.get 3 i32.add))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected multivalue producer simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 3)"), msg=pretty)
  assert_false(pretty.contains("local.tee (Local 3)"), msg=pretty)
}

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
  assert_true(pretty.contains("nop"))
  assert_false(pretty.contains("drop"))
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
  assert_true(pretty.contains("nop"))
  assert_false(pretty.contains("drop"))
  assert_true(pretty.contains("I32(7)"))
}

///|
test "simplify-locals removes overwritten pending local sets" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 1 local.set 0 i32.const 2 local.set 0 local.get 0))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected overwritten-set simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set"))
  assert_false(pretty.contains("local.get"))
  assert_true(pretty.contains("drop"))
  assert_true(pretty.contains("I32(1)"))
  assert_true(pretty.contains("I32(2)"))
}

///|
test "simplify-locals keeps overwritten dead tee values as drops before the final dead write" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) i32.const 34 local.tee 0 drop i32.const 854 local.tee 0 drop))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected dead-tee overwrite simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.tee"), msg=pretty)
  assert_false(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("I32(34)"), msg=pretty)
  assert_false(pretty.contains("I32(854)"), msg=pretty)
}

///|
test "simplify-locals sinks through empty linear block wrappers" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 80 local.set 0 block nop end local.get 0))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected empty-block simplify-locals sink success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set"), msg=pretty)
  assert_false(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("I32(80)"), msg=pretty)
}

///|
test "simplify-locals does not sink value reads across later writes to the source local" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32) (result i32) (local i32) local.get 1 local.set 2 i32.const 9 local.set 1 local.get 2))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected source-local ordering simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
}

///|
test "simplify-locals does not sink captured local values past later writes" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32) (result i32) (local i32) local.get 1 local.set 2 i32.const 7 local.set 1 local.get 2))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected local-conflict simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 2)"), msg=pretty)
}

///|
test "simplify-locals keeps pending sinks across unrelated local traffic" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32 i32) i32.const 5 local.set 2 local.get 0 drop local.get 2))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected unrelated-local simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 2)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
  assert_true(pretty.contains("I32(5)"), msg=pretty)
}

///|
test "simplify-locals canonicalizes equivalent copies across adjacent blocks" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) block local.get 0 local.set 1 end local.get 1 local.get 0 i32.add))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected equivalent-copy simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.add"), msg=pretty)
  assert_false(pretty.contains("local.set"), msg=pretty)
  assert_false(pretty.contains("local.get 1"), msg=pretty)
}

///|
test "simplify-locals collapses drop of a sunk tee back into a set" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 1 local.set 0 local.get 0 drop local.get 0))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected simplify-locals drop-tee collapse success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set"))
  assert_false(pretty.contains("local.tee"))
  assert_true(pretty.contains("I32(1)"))
}

///|
test "simplify-locals removes unreachable dead local defs outside the ssa overlay" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) block unreachable i32.const 1 local.set 0 end i32.const 7))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected unreachable dead-def simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set"))
  assert_true(pretty.contains("I32(7)"))
}

///|
test "simplify-locals lifts matching block exits into a block result" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) block $exit local.get 0 if i32.const 1 local.set 1 br $exit end i32.const 2 local.set 1 end local.get 1))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected block-return simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("block I32"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_true(pretty.contains("I32(2)"), msg=pretty)
}

///|
test "simplify-locals lifts if-else local writes into an if result" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 if i32.const 1 local.set 1 else i32.const 2 local.set 1 end local.get 1))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected if-return simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if I32"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_true(pretty.contains("I32(2)"), msg=pretty)
}

///|
test "simplify-locals keeps later reads alive when lifting if results" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 if i32.const 1 local.set 1 else i32.const 2 local.set 1 end local.get 1 local.get 1 i32.add))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected multi-read if-return simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if I32"), msg=pretty)
  assert_true(pretty.contains("local.tee"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
}

///|
test "simplify-locals lifts reachable if-else arms even when the other arm is unreachable" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 if unreachable else i32.const 9 local.set 1 end local.get 1))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected unreachable-arm simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if I32"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_true(pretty.contains("I32(9)"), msg=pretty)
}

///|
test "simplify-locals lifts one-armed if writes for defaultable locals" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 if i32.const 7 local.set 1 end local.get 1))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected one-armed simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if I32"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "simplify-locals lifts nested one-armed if writes inside consumed result ifs" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32 i32) local.get 0 i32.const 256 i32.lt_u if (result i32) local.get 0 local.set 1 i32.const 0 else local.get 0 i32.const 10 i32.lt_u if local.get 0 i32.const 1 i32.add local.set 1 end nop local.get 1 local.get 0 i32.shr_u local.set 1 local.get 0 end local.tee 2 local.get 0 i32.add))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected nested consumed-result one-armed simplify-locals success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("if (Void)"), msg=pretty)
  assert_true(pretty.contains("local.tee (Local 1)"), msg=pretty)
}

///|
test "simplify-locals skips one-armed if lifting for non-defaultable locals" {
  let non_defaultable = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::func())),
  )
  let nullable = @lib.ValType::funcref()
  let probe = @ir.HotFunc::new()
  let body_result_type = @ir.hot_type_intern_value(probe, non_defaultable)
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[
      @lib.ValType::i32(),
      non_defaultable,
      nullable,
    ]),
    body_result_type~,
  )
  ignore(@ir.hot_type_intern_value(func, non_defaultable))
  let condition = @ir.hot_build_local_get(func, 0)
  let lifted = @ir.hot_build_heap(
    func,
    [non_defaultable],
    @lib.Instruction::ref_as_non_null(),
    [@ir.hot_build_local_get(func, 2)],
  )
  let set = @ir.hot_build_local_set(func, 1, lifted)
  let if_id = @ir.hot_build_if(func, @lib.BlockType::void_(), condition, [set])
  @ir.hot_root_append(func, if_id)
  @ir.hot_root_append(func, @ir.hot_build_local_get(func, 1))
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
      fail(
        "expected non-defaultable one-armed simplify-locals success, got \{err}",
      )
  }

  assert_eq(@ir.hot_root_count(func), 2)
  match @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).op {
    @ir.HotOp::If => ()
    _ => fail("expected non-defaultable if to stay as a plain if root")
  }
  let then_region = @ir.hot_region_then_ref(func, @ir.hot_root_get(func, 0))
  match @ir.hot_node_get(func, @ir.hot_region_get(func, then_region, 0)).op {
    @ir.HotOp::LocalSet => ()
    _ => fail("expected non-defaultable then arm to keep the local.set")
  }
  match @ir.hot_node_get(func, @ir.hot_root_get(func, 1)).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected trailing local.get to remain after the if")
  }
}

///|
test "simplify-locals lifts loop tail writes across the loop fallthrough" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) loop i32.const 9 local.set 0 end local.get 0))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected loop simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("loop"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
  assert_true(pretty.contains("I32(9)"), msg=pretty)
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
