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
test "dead-code-elimination preserves global.get roots with dead results" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (global i32 (i32.const 0)) (func (result i32) global.get 0 drop i32.const 7))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected dead-code-elimination to preserve global.get roots, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
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
test "dead-code-elimination removes branch-skipping result block wrappers under drop" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) block block (result i32) local.get 0 if br 2 else br 2 end i32.const 1000 end drop end i32.const 0))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected dead-code-elimination to remove branch-skipping result block wrappers, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(block I32"), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("I32(1000)"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("I32(0)"), msg=pretty)
}

///|
test "dead-code-elimination removes typed branch-payload forwarders that only feed later block results" {
  let mod_ = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) (local i32) (block $out (result i32) (block $exit (br $out (block $mid (result i32) (block $cont (br $mid (if (result i32) (local.get 0) (then (i32.const 1) (local.set 1) (br $cont)) (else (br $exit))))) (local.get 1)))) (i32.const 9))))",
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
        "expected dead-code-elimination payload-forwarder success, got \{err}",
      )
  }

  let lowered = @ir.hot_lower_func(func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("(if I32"), msg=pretty)
}

///|
test "dead-code-elimination removes typed branch-payload forwarders nested under local.set" {
  let mod_ = pass_test_module_from_wat(
    "(module (func (param i32 i32) (result i32) (local i32) (local i32) (local.set 2 (block $out (result i32) (block $exit (br $out (block $mid (result i32) (block $cont (br $mid (if (result i32) (local.get 0) (then (i32.const 1) (local.set 3) (br $cont)) (else (br $exit))))) (local.get 3)))) (local.get 1))) (local.get 2)))",
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
        "expected dead-code-elimination nested payload-forwarder success, got \{err}",
      )
  }

  let lowered = @ir.hot_lower_func(func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("(if I32"), msg=pretty)
}

///|
test "dead-code-elimination removes dead drop wrappers around non-fallthrough branches" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (block $out (result i32) (drop (br $out (local.get 0))))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected dead-code-elimination to remove dead drop around branch payload, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(br "), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
}

///|
test "dead-code-elimination voidifies dropped nonfallthrough result blocks with inner branch labels" {
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let inner = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let inner_label = @ir.hot_control_node_label(func, inner)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, inner), [
    @ir.hot_build_br(func, inner_label),
  ])
  let wrapped = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [
      inner,
      @ir.hot_build_return(func, [@ir.hot_build_const_i32(func, @lib.I32(1))]),
    ],
  )
  @ir.hot_root_append(func, @ir.hot_build_drop(func, wrapped))
  @ir.hot_root_append(func, @ir.hot_build_const_i32(func, @lib.I32(7)))
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
        "expected dead-code-elimination to voidify dropped nonfallthrough blocks, got \{err}",
      )
  }

  let lowered = @ir.hot_lower_func(func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(block (Void)"), msg=pretty)
  assert_false(pretty.contains("(drop (block I32"), msg=pretty)
  assert_true(pretty.contains("return"), msg=pretty)
}

///|
test "dead-code-elimination removes split drop roots after nonfallthrough result blocks" {
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let inner = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let inner_label = @ir.hot_control_node_label(func, inner)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, inner), [
    @ir.hot_build_br(func, inner_label),
  ])
  let wrapped = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [
      inner,
      @ir.hot_build_return(func, [@ir.hot_build_const_i32(func, @lib.I32(1))]),
    ],
  )
  let dropped = @ir.hot_build_drop(func, wrapped)
  @ir.hot_root_append(func, wrapped)
  @ir.hot_root_append(func, dropped)
  @ir.hot_root_append(func, @ir.hot_build_const_i32(func, @lib.I32(7)))
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
        "expected dead-code-elimination split-drop nonfallthrough success, got \{err}",
      )
  }

  assert_eq(@ir.hot_root_count(func), 2)
  let root0 = @ir.hot_root_get(func, 0)
  assert_eq(root0, wrapped)
  assert_eq(@ir.hot_node_result_arity(func, root0), 0)
  let root1 = @ir.hot_root_get(func, 1)
  match @ir.hot_node_get(func, root1).op {
    @ir.HotOp::Unreachable => ()
    other => fail("expected explicit unreachable tail, got \{other}")
  }
}

///|
test "dead-code-elimination batches consecutive dead drop root splices" {
  let func = pass_test_lift_first_func(
    "(module (func i32.const 1 drop i32.const 2 drop i32.const 3 drop))",
  )
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  let rev0 = @ir.hot_revision_current(func)

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected batched dead-drop dead-code-elimination success, got \{err}",
      )
  }

  assert_eq(@ir.hot_root_count(func), 0)
  let rev_delta = @ir.hot_revision_current(func) - rev0
  assert_true(rev_delta <= 9, msg="\{rev_delta}")
}

///|
test "dead-code-elimination folds nonfallthrough prefix blocks into branch payloads" {
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )

  let payload_value = @ir.hot_build_const_i32(func, @lib.I32(7))
  let prefix = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let prefix_label = @ir.hot_control_node_label(func, prefix)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, prefix), [
    @ir.hot_build_br(func, prefix_label),
    @ir.hot_build_unreachable(func),
  ])

  let out = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
  )
  let out_label = @ir.hot_control_node_label(func, out)
  let branch = @ir.hot_build_br(func, out_label, values=[payload_value])
  let mid = @ir.hot_build_block(func, @lib.BlockType::void_(), [prefix, branch])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, out), [
    mid,
    @ir.hot_build_const_i32(func, @lib.I32(9)),
  ])
  @ir.hot_root_append(func, out)

  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match @ir.hot_verify_core(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected prefix-payload fixture core verification, got \{err}")
  }
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected prefix-payload fixture control verification, got \{err}")
  }
  assert_eq(
    @ir.hot_region_root_count(func, @ir.hot_region_body_ref(func, mid)),
    2,
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dead-code-elimination prefix-payload fold success, got \{err}",
      )
  }

  let mid_region = @ir.hot_region_body_ref(func, mid)
  assert_eq(@ir.hot_region_root_count(func, mid_region), 1)
  let folded_branch = @ir.hot_region_get(func, mid_region, 0)
  match @ir.hot_node_get(func, folded_branch).op {
    @ir.HotOp::Br => ()
    other => fail("expected folded root branch, got \{other}")
  }
  let folded_payload = @ir.hot_child_get(func, folded_branch, 0)
  match @ir.hot_node_get(func, folded_payload).op {
    @ir.HotOp::Block => ()
    other => fail("expected folded branch payload block, got \{other}")
  }
  let folded_region = @ir.hot_region_body_ref(func, folded_payload)
  assert_eq(@ir.hot_region_root_count(func, folded_region), 2)
  assert_eq(@ir.hot_region_get(func, folded_region, 0), prefix)
  assert_eq(@ir.hot_region_get(func, folded_region, 1), payload_value)
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
test "dead-code-elimination keeps typed if wrappers with hidden br_table payload branches" {
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
    @ir.hot_build_br_table(
      func,
      [then_label],
      then_label,
      @ir.hot_build_const_i32(func, @lib.I32(0)),
      values=[@ir.hot_build_const_i32(func, @lib.I32(1))],
    ),
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
    Err(err) => fail("expected br_table fixture core verification, got \{err}")
  }
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected br_table fixture control verification, got \{err}")
  }
  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected dead-code-elimination hidden br_table success, got \{err}")
  }

  assert_eq(@ir.hot_node_result_arity(func, if_id), 1)
  match @ir.hot_verify_core(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected typed if br_table wrapper to remain valid, got \{err}")
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
test "dead-code-elimination materializes unreachable tails after voidifying typed loop-body wrappers" {
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
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
}

///|
test "dead-code-elimination leaves explicit unreachable root after final voidified control" {
  let mod_ = pass_test_module_from_wat(
    "(module (import \"env\" \"array_length\" (func $moonbit.array_length (param i32) (result i32))) (memory 1) (func $moonbit.string_equal (param $stra i32) (param $strb i32) (result i32) (local $counter i32) local.get $stra call $moonbit.array_length local.get $strb call $moonbit.array_length i32.eq if (result i32) loop (result i32) local.get $counter local.get $stra call $moonbit.array_length i32.lt_s if (result i32) local.get $stra local.get $counter i32.const 1 i32.shl i32.add i32.load16_u offset=8 align=1 local.get $strb local.get $counter i32.const 1 i32.shl i32.add i32.load16_u offset=8 align=1 i32.eq if (result i32) local.get $counter i32.const 1 i32.add local.set $counter br 2 else i32.const 0 return end else i32.const 1 return end end else i32.const 0 return end))",
  )
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(1U))
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
        "expected dead-code-elimination final control tail success, got \{err}",
      )
  }

  assert_eq(@ir.hot_root_count(func), 2)
  let tail_id = @ir.hot_root_get(func, 1)
  match @ir.hot_node_get(func, tail_id).op {
    @ir.HotOp::Unreachable => ()
    other => fail("expected explicit unreachable tail root, got \{other}")
  }
}
