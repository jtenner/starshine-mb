///|
test "optimize-instructions folds i32.eqz on constant zero" {
  let optimized = match
    pass_test_run_pipeline("(module (func (result i32) i32.const 0 i32.eqz))", [
      "optimize-instructions",
    ]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected optimize-instructions success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(1)"))
  assert_false(pretty.contains("I32Eqz"))
}

///|
fn optimize_instructions_test_run_hot(text : String) -> @ir.HotFunc {
  let func = pass_test_lift_first_func(text)
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(ctx, func) {
    Ok(_) => func
    Err(err) =>
      abort("expected optimize-instructions hot pass success, got \{err}")
  }
}

///|
fn optimize_instructions_shared_dag_fixture(depth : Int) -> @ir.HotFunc {
  let func = @ir.HotFunc::new()
  let mut value = @ir.hot_build_const_i32(func, @lib.I32(0))
  for i = 0; i < depth; i = i + 1 {
    let _ = i
    let lhs = @ir.hot_build_binary(
      func,
      @lib.ValType::i32(),
      value,
      @ir.hot_build_const_i32(func, @lib.I32(1)),
    )
    @ir.hot_node_exact_instr_set(func, lhs, @lib.Instruction::i32_add())
    let rhs = @ir.hot_build_binary(
      func,
      @lib.ValType::i32(),
      value,
      @ir.hot_build_const_i32(func, @lib.I32(2)),
    )
    @ir.hot_node_exact_instr_set(func, rhs, @lib.Instruction::i32_add())
    value = @ir.hot_build_binary(func, @lib.ValType::i32(), lhs, rhs)
    @ir.hot_node_exact_instr_set(func, value, @lib.Instruction::i32_add())
  }
  @ir.hot_root_append(func, @ir.hot_build_drop(func, value))
  func
}

///|
test "optimize-instructions keeps shared children live when folding eqz" {
  let func = pass_test_lift_first_func(
    "(module (func (result i32) i32.const 0 i32.eqz))",
  )
  let eqz = @ir.hot_root_get(func, 0)
  let shared = @ir.hot_child_get(func, eqz, 0)
  let drop_ = @ir.hot_build_drop(func, shared)
  @ir.hot_root_append(func, drop_)
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected optimize-instructions shared-child success, got \{err}")
  }

  let folded = @ir.hot_root_get(func, 0)
  let folded_node = @ir.hot_node_get(func, folded)
  match folded_node.op {
    @ir.HotOp::Const => ()
    _ => fail("expected folded root to become a const node")
  }
  assert_eq(
    @ir.hot_const_get(func, folded_node.imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(1)),
  )
  assert_true(@ir.hot_node_is_live(func, shared))
  assert_eq(@ir.hot_child_get(func, drop_, 0), shared)
}

///|
test "optimize-instructions folds i64.eqz on non-zero constants" {
  let optimized = match
    pass_test_run_pipeline("(module (func (result i32) i64.const 9 i64.eqz))", [
      "optimize-instructions",
    ]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected optimize-instructions success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(0)"))
  assert_false(pretty.contains("I64Eqz"))
}

///|
test "optimize-instructions rewrites eqz on sub into eq" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32) (result i32) local.get 0 local.get 1 i32.sub i32.eqz))",
  )
  let root = @ir.hot_root_get(func, 0)
  assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_eq()),
  )
  let lhs = @ir.hot_child_get(func, root, 0)
  let rhs = @ir.hot_child_get(func, root, 1)
  match @ir.hot_node_get(func, lhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected lhs of eqz(sub) rewrite to remain the original lhs")
  }
  match @ir.hot_node_get(func, rhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected rhs of eqz(sub) rewrite to remain the original rhs")
  }
}

///|
test "optimize-instructions rewrites eqz on add const into eq negated const" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 5 i32.add i32.eqz))",
  )
  let root = @ir.hot_root_get(func, 0)
  assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_eq()),
  )
  let rhs = @ir.hot_child_get(func, root, 1)
  assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, rhs).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(-5)),
  )
}

///|
test "optimize-instructions canonicalizes i32.eq zero into eqz" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 0 i32.eq))",
  )
  let root = @ir.hot_root_get(func, 0)
  assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_eqz()),
  )
  assert_eq(@ir.hot_child_count(func, root), 1)
}

///|
test "optimize-instructions canonicalizes i64.eq zero into eqz" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i64) (result i32) local.get 0 i64.const 0 i64.eq))",
  )
  let root = @ir.hot_root_get(func, 0)
  assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i64_eqz()),
  )
  assert_eq(@ir.hot_child_count(func, root), 1)
}

///|
test "optimize-instructions keeps i32.rem zero compares in eq form" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 64 i32.rem_s i32.const 0 i32.eq))",
  )
  let root = @ir.hot_root_get(func, 0)
  assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_eq()),
  )
  assert_eq(@ir.hot_child_count(func, root), 2)
}

///|
test "optimize-instructions rewrites add with a negative constant into sub" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const -5 i32.add))",
  )
  let root = @ir.hot_root_get(func, 0)
  assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_sub()),
  )
  let rhs = @ir.hot_child_get(func, root, 1)
  assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, rhs).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(5)),
  )
}

///|
test "optimize-instructions preserves signed-leb-friendly negative adds" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const -64 i32.add))",
  )
  let root = @ir.hot_root_get(func, 0)
  assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_add()),
  )
  let rhs = @ir.hot_child_get(func, root, 1)
  assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, rhs).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(-64)),
  )
}

///|
test "optimize-instructions preserves positive add immediates for parity" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 64 i32.add))",
  )
  let root = @ir.hot_root_get(func, 0)
  assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_add()),
  )
  let rhs = @ir.hot_child_get(func, root, 1)
  assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, rhs).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(64)),
  )
}

///|
test "optimize-instructions keeps canonicalized positive adds in add form" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) i32.const 64 local.get 0 i32.add))",
  )
  let root = @ir.hot_root_get(func, 0)
  assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_add()),
  )
  let lhs = @ir.hot_child_get(func, root, 0)
  let rhs = @ir.hot_child_get(func, root, 1)
  match @ir.hot_node_get(func, lhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected chained rewrite to leave the non-constant on the lhs")
  }
  assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, rhs).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(64)),
  )
}

///|
test "optimize-instructions rewrites add with trailing zero-sub into sub" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32) (result i32) local.get 0 i32.const 0 local.get 1 i32.sub i32.add))",
  )
  let root = @ir.hot_root_get(func, 0)
  assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_sub()),
  )
  let lhs = @ir.hot_child_get(func, root, 0)
  let rhs = @ir.hot_child_get(func, root, 1)
  match @ir.hot_node_get(func, lhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected x + (0 - y) rewrite to preserve the lhs local")
  }
  match @ir.hot_node_get(func, rhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected x + (0 - y) rewrite to expose the rhs local")
  }
}

///|
test "optimize-instructions rewrites leading zero-sub add into sub" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32) (result i32) i32.const 0 local.get 0 i32.sub local.get 1 i32.add))",
  )
  let root = @ir.hot_root_get(func, 0)
  assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_sub()),
  )
  let lhs = @ir.hot_child_get(func, root, 0)
  let rhs = @ir.hot_child_get(func, root, 1)
  match @ir.hot_node_get(func, lhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected (0 - x) + y rewrite to expose the new lhs local")
  }
  match @ir.hot_node_get(func, rhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected (0 - x) + y rewrite to expose the rhs local")
  }
}

///|
test "optimize-instructions removes neutral add and sub zero" {
  let add_func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 8 i32.add i32.const 0 i32.add))",
  )
  let add_root = @ir.hot_root_get(add_func, 0)
  assert_eq(
    @ir.hot_node_exact_instr(add_func, add_root),
    Some(@lib.Instruction::i32_add()),
  )
  let add_lhs = @ir.hot_child_get(add_func, add_root, 0)
  let add_rhs = @ir.hot_child_get(add_func, add_root, 1)
  match @ir.hot_node_get(add_func, add_lhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected neutral i32.add rewrite to expose the original lhs")
  }
  assert_eq(
    @ir.hot_const_get(add_func, @ir.hot_node_get(add_func, add_rhs).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(8)),
  )

  let sub_func = optimize_instructions_test_run_hot(
    "(module (func (param i64) (result i64) local.get 0 i64.const 0 i64.sub))",
  )
  let sub_root = @ir.hot_root_get(sub_func, 0)
  match @ir.hot_node_get(sub_func, sub_root).op {
    @ir.HotOp::LocalGet => ()
    _ =>
      fail("expected neutral i64.sub rewrite to replace the node with its lhs")
  }
}

///|
test "optimize-instructions canonicalizes if eq zero into eqz without else" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (if (i32.eq (local.get 0) (i32.const 0)) (then nop))))",
  )
  let if_ = @ir.hot_root_get(func, 0)
  let cond = @ir.hot_child_get(func, if_, 0)
  assert_eq(
    @ir.hot_node_exact_instr(func, cond),
    Some(@lib.Instruction::i32_eqz()),
  )
  assert_eq(@ir.hot_child_count(func, cond), 1)
  match @ir.hot_node_get(func, @ir.hot_child_get(func, cond, 0)).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected if-condition eqz operand to remain the original value")
  }
}

///|
test "optimize-instructions collapses duplicate branch ifs in then regions" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  let outer_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
  )
  let outer_label = @ir.hot_control_node_label(func, outer_block)
  let inner_compare = @ir.hot_build_compare(
    func,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  )
  @ir.hot_node_exact_instr_set(func, inner_compare, @lib.Instruction::i32_eq())
  let branch_value = @ir.hot_build_local_get(func, 1)
  let inner_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    inner_compare,
    [@ir.hot_build_br(func, outer_label, values=[branch_value])],
    else_body=Some([@ir.hot_build_br(func, outer_label, values=[branch_value])]),
  )
  let outer_if = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    @ir.hot_build_local_get(func, 0),
    [inner_if, @ir.hot_build_unreachable(func)],
    else_body=Some([@ir.hot_build_local_get(func, 1)]),
  )
  @ir.hot_region_replace_body(
    func,
    @ir.hot_region_body_ref(func, outer_block),
    [outer_if],
  )
  @ir.hot_root_append(func, outer_block)
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected optimize-instructions duplicate-branch success, got \{err}",
      )
  }

  let then_region = @ir.hot_region_then_ref(func, outer_if)
  assert_eq(@ir.hot_region_root_count(func, then_region), 1)
  let then_root = @ir.hot_region_get(func, then_region, 0)
  match @ir.hot_node_get(func, then_root).op {
    @ir.HotOp::Br => ()
    _ => fail("expected duplicate then-branch if to collapse into a direct br")
  }
}

///|
test "optimize-instructions collapses duplicate branch ifs in single-root then regions" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  let carrier = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
  )
  let carrier_label = @ir.hot_control_node_label(func, carrier)
  let middle = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let middle_label = @ir.hot_control_node_label(func, middle)
  let inner_compare = @ir.hot_build_compare(
    func,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  )
  @ir.hot_node_exact_instr_set(func, inner_compare, @lib.Instruction::i32_eq())
  let inner_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    inner_compare,
    [@ir.hot_build_br(func, middle_label)],
    else_body=Some([@ir.hot_build_br(func, middle_label)]),
  )
  let outer_if = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    @ir.hot_build_local_get(func, 0),
    [inner_if],
    else_body=Some([@ir.hot_build_local_get(func, 1)]),
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, middle), [
    @ir.hot_build_br(func, carrier_label, values=[outer_if]),
  ])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, carrier), [
    middle,
  ])
  @ir.hot_root_append(func, carrier)
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected optimize-instructions single-root duplicate-branch success, got \{err}",
      )
  }

  let then_region = @ir.hot_region_then_ref(func, outer_if)
  assert_eq(@ir.hot_region_root_count(func, then_region), 1)
  let then_root = @ir.hot_region_get(func, then_region, 0)
  match @ir.hot_node_get(func, then_root).op {
    @ir.HotOp::Br => ()
    _ =>
      fail(
        "expected single-root duplicate then-branch if to collapse into a direct br",
      )
  }
  assert_eq(@ir.hot_node_get(func, then_root).imm0, middle_label)
}

///|
test "optimize-instructions replaces dead block fallthroughs after escaping ifs with unreachable" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let outer_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
  )
  let outer_label = @ir.hot_control_node_label(func, outer_block)
  let escape_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 0),
    [@ir.hot_build_return(func, [@ir.hot_build_const_i32(func, @lib.I32(1))])],
    else_body=Some([
      @ir.hot_build_br(func, outer_label, values=[
        @ir.hot_build_const_i32(func, @lib.I32(2)),
      ]),
    ]),
  )
  @ir.hot_region_replace_body(
    func,
    @ir.hot_region_body_ref(func, outer_block),
    [escape_if, @ir.hot_build_const_i32(func, @lib.I32(0))],
  )
  @ir.hot_root_append(func, outer_block)
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected optimize-instructions dead-fallthrough cleanup success, got \{err}",
      )
  }

  let body = @ir.hot_region_body_ref(func, outer_block)
  assert_eq(@ir.hot_region_root_count(func, body), 2)
  let tail = @ir.hot_region_get(func, body, 1)
  match @ir.hot_node_get(func, tail).op {
    @ir.HotOp::Unreachable => ()
    _ =>
      fail("expected dead block fallthrough to canonicalize into unreachable")
  }
}

///|
test "optimize-instructions replaces dead block fallback branches after escaping ifs with unreachable" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let carrier = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
  )
  let carrier_label = @ir.hot_control_node_label(func, carrier)
  let escape_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 0),
    [@ir.hot_build_return(func, [@ir.hot_build_const_i32(func, @lib.I32(1))])],
    else_body=Some([
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(2)),
      ),
      @ir.hot_build_br(func, carrier_label, values=[
        @ir.hot_build_local_get(func, 1),
      ]),
    ]),
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, carrier), [
    escape_if,
    @ir.hot_build_br(func, carrier_label, values=[
      @ir.hot_build_const_i32(func, @lib.I32(0)),
    ]),
  ])
  @ir.hot_root_append(func, carrier)
  @ir.hot_root_append(func, @ir.hot_build_local_get(func, 1))
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected optimize-instructions dead-fallback-branch cleanup success, got \{err}",
      )
  }

  let body = @ir.hot_region_body_ref(func, carrier)
  assert_eq(@ir.hot_region_root_count(func, body), 2)
  let tail = @ir.hot_region_get(func, body, 1)
  match @ir.hot_node_get(func, tail).op {
    @ir.HotOp::Unreachable => ()
    _ => fail("expected dead fallback branch to canonicalize into unreachable")
  }
}

///|
test "optimize-instructions keeps outer fallthrough when inner branches only exit inner blocks" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let outer_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
  )
  let inner_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
  )
  let inner_label = @ir.hot_control_node_label(func, inner_block)
  let inner_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 0),
    [
      @ir.hot_build_br(func, inner_label, values=[
        @ir.hot_build_const_i32(func, @lib.I32(1)),
      ]),
    ],
    else_body=Some([
      @ir.hot_build_br(func, inner_label, values=[
        @ir.hot_build_const_i32(func, @lib.I32(2)),
      ]),
    ]),
  )
  @ir.hot_region_replace_body(
    func,
    @ir.hot_region_body_ref(func, inner_block),
    [inner_if, @ir.hot_build_const_i32(func, @lib.I32(0))],
  )
  @ir.hot_region_replace_body(
    func,
    @ir.hot_region_body_ref(func, outer_block),
    [inner_block, @ir.hot_build_const_i32(func, @lib.I32(9))],
  )
  @ir.hot_root_append(func, outer_block)
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected optimize-instructions inner-branch fallthrough success, got \{err}",
      )
  }

  let outer_body = @ir.hot_region_body_ref(func, outer_block)
  assert_eq(@ir.hot_region_root_count(func, outer_body), 2)
  let outer_tail = @ir.hot_region_get(func, outer_body, 1)
  match @ir.hot_node_get(func, outer_tail).op {
    @ir.HotOp::Const => ()
    _ =>
      fail(
        "expected outer fallthrough to remain live when inner branches only exit the inner block",
      )
  }
}

///|
test "optimize-instructions preserves mixed-label fallback branches after non-fallthrough ifs" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let carrier = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
  )
  let carrier_label = @ir.hot_control_node_label(func, carrier)
  let middle = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let middle_label = @ir.hot_control_node_label(func, middle)
  let escape_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 0),
    [@ir.hot_build_br(func, middle_label)],
    else_body=Some([
      @ir.hot_build_br(func, carrier_label, values=[
        @ir.hot_build_const_i32(func, @lib.I32(2)),
      ]),
    ]),
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, middle), [
    escape_if,
    @ir.hot_build_br(func, carrier_label, values=[
      @ir.hot_build_const_i32(func, @lib.I32(0)),
    ]),
  ])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, carrier), [
    middle,
    @ir.hot_build_const_i32(func, @lib.I32(9)),
  ])
  @ir.hot_root_append(func, carrier)
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected optimize-instructions mixed-label fallback cleanup success, got \{err}",
      )
  }

  let middle_body = @ir.hot_region_body_ref(func, middle)
  assert_eq(@ir.hot_region_root_count(func, middle_body), 2)
  let middle_tail = @ir.hot_region_get(func, middle_body, 1)
  match @ir.hot_node_get(func, middle_tail).op {
    @ir.HotOp::Br => ()
    _ =>
      fail("expected mixed-label fallback branch to remain a value-carrying br")
  }
  assert_eq(@ir.hot_node_get(func, middle_tail).imm0, carrier_label)
  let middle_tail_value = @ir.hot_child_get(func, middle_tail, 0)
  assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, middle_tail_value).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )
}

///|
test "optimize-instructions preserves outer fallback branches after nested return-or-inner-escape blocks" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let carrier = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
  )
  let carrier_label = @ir.hot_control_node_label(func, carrier)
  let middle = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let middle_label = @ir.hot_control_node_label(func, middle)
  let escape_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 0),
    [@ir.hot_build_return(func, [@ir.hot_build_const_i32(func, @lib.I32(9))])],
    else_body=Some([@ir.hot_build_br(func, middle_label)]),
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, middle), [
    escape_if,
  ])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, carrier), [
    middle,
    @ir.hot_build_br(func, carrier_label, values=[
      @ir.hot_build_const_i32(func, @lib.I32(0)),
    ]),
  ])
  @ir.hot_root_append(func, carrier)
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected optimize-instructions nested-return fallback cleanup success, got \{err}",
      )
  }

  let carrier_body = @ir.hot_region_body_ref(func, carrier)
  assert_eq(@ir.hot_region_root_count(func, carrier_body), 2)
  let carrier_tail = @ir.hot_region_get(func, carrier_body, 1)
  match @ir.hot_node_get(func, carrier_tail).op {
    @ir.HotOp::Br => ()
    _ => fail("expected outer fallback branch to remain a value-carrying br")
  }
  assert_eq(@ir.hot_node_get(func, carrier_tail).imm0, carrier_label)
  let carrier_tail_value = @ir.hot_child_get(func, carrier_tail, 0)
  assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, carrier_tail_value).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )
}

///|
test "optimize-instructions preserves value fallback branches after return-or-inner-label ifs" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let carrier = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
  )
  let carrier_label = @ir.hot_control_node_label(func, carrier)
  let middle = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let middle_label = @ir.hot_control_node_label(func, middle)
  let escape_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 0),
    [@ir.hot_build_return(func, [@ir.hot_build_const_i32(func, @lib.I32(9))])],
    else_body=Some([@ir.hot_build_br(func, middle_label)]),
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, middle), [
    escape_if,
    @ir.hot_build_br(func, carrier_label, values=[
      @ir.hot_build_const_i32(func, @lib.I32(0)),
    ]),
  ])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, carrier), [
    middle,
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  ])
  @ir.hot_root_append(func, carrier)
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected optimize-instructions inner-label fallback cleanup success, got \{err}",
      )
  }

  let middle_body = @ir.hot_region_body_ref(func, middle)
  assert_eq(@ir.hot_region_root_count(func, middle_body), 2)
  let middle_tail = @ir.hot_region_get(func, middle_body, 1)
  match @ir.hot_node_get(func, middle_tail).op {
    @ir.HotOp::Br => ()
    _ =>
      fail("expected inner-label fallback branch to remain a value-carrying br")
  }
  assert_eq(@ir.hot_node_get(func, middle_tail).imm0, carrier_label)
  let middle_tail_value = @ir.hot_child_get(func, middle_tail, 0)
  assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, middle_tail_value).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )
}

///|
test "optimize-instructions preserves zero sentinels under dropped value carriers" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let loop_ = @ir.hot_build_loop(func, @lib.BlockType::void_(), [])
  let loop_label = @ir.hot_control_node_label(func, loop_)
  let inner_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 1),
    [@ir.hot_build_return(func, [@ir.hot_build_const_i32(func, @lib.I32(7))])],
    else_body=Some([@ir.hot_build_br(func, loop_label)]),
  )
  let outer_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 0),
    [@ir.hot_build_return(func, [@ir.hot_build_const_i32(func, @lib.I32(8))])],
    else_body=Some([
      inner_if,
      @ir.hot_build_drop(func, @ir.hot_build_const_i32(func, @lib.I32(0))),
    ]),
  )
  let carrier = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [outer_if, @ir.hot_build_const_i32(func, @lib.I32(0))],
  )
  let dropped = @ir.hot_build_drop(func, carrier)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, loop_), [
    dropped,
    @ir.hot_build_br(func, loop_label),
  ])
  @ir.hot_root_append(func, loop_)
  @ir.hot_root_append(func, @ir.hot_build_unreachable(func))
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected optimize-instructions dropped-carrier sentinel preservation success, got \{err}",
      )
  }

  let outer_else = @ir.hot_region_else_ref(func, outer_if).unwrap()
  assert_eq(@ir.hot_region_root_count(func, outer_else), 2)
  let outer_else_tail = @ir.hot_region_get(func, outer_else, 1)
  match @ir.hot_node_get(func, outer_else_tail).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected dropped carrier else tail to keep explicit drop-zero sentinel",
      )
  }

  let carrier_body = @ir.hot_region_body_ref(func, carrier)
  assert_eq(@ir.hot_region_root_count(func, carrier_body), 2)
  let carrier_tail = @ir.hot_region_get(func, carrier_body, 1)
  match @ir.hot_node_get(func, carrier_tail).op {
    @ir.HotOp::Const => ()
    _ => fail("expected dropped carrier body to keep explicit zero sentinel")
  }
}

///|
test "optimize-instructions does not add unreachable tails to escaping if arms" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let carrier = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
  )
  let carrier_label = @ir.hot_control_node_label(func, carrier)
  let nested = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 0),
    [
      @ir.hot_build_br(func, carrier_label, values=[
        @ir.hot_build_const_i32(func, @lib.I32(2)),
      ]),
    ],
    else_body=Some([
      @ir.hot_build_return(func, [@ir.hot_build_const_i32(func, @lib.I32(9))]),
    ]),
  )
  let outer_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 0),
    [
      nested,
      @ir.hot_build_drop(func, @ir.hot_build_const_i32(func, @lib.I32(11))),
      @ir.hot_build_drop(func, @ir.hot_build_const_i32(func, @lib.I32(12))),
    ],
    else_body=Some([
      @ir.hot_build_drop(func, @ir.hot_build_const_i32(func, @lib.I32(13))),
      @ir.hot_build_drop(func, @ir.hot_build_const_i32(func, @lib.I32(14))),
    ]),
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, carrier), [
    outer_if,
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  ])
  @ir.hot_root_append(func, carrier)
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected optimize-instructions escaping-if-arm cleanup success, got \{err}",
      )
  }

  let then_region = @ir.hot_region_then_ref(func, outer_if)
  assert_eq(@ir.hot_region_root_count(func, then_region), 1)
  let tail = @ir.hot_region_get(func, then_region, 0)
  match @ir.hot_node_get(func, tail).op {
    @ir.HotOp::If => ()
    _ =>
      fail(
        "expected escaping if arms to drop dead tails without a synthetic unreachable",
      )
  }
}

///|
test "optimize-instructions negates nested boolean if conditions by swapping outer arms" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i64 i32) (result i32) local.get 0 i64.eqz if (result i32) local.get 1 i32.eqz else i32.const 0 end if (result i32) i32.const 1 else local.get 0 i64.const -1 i64.eq if (result i32) local.get 1 else i32.const 0 end end))",
  )
  let outer_if = @ir.hot_root_get(func, 0)
  let outer_cond = @ir.hot_child_get(func, outer_if, 0)
  match @ir.hot_node_get(func, outer_if).op {
    @ir.HotOp::If => ()
    _ => fail("expected root to remain an if")
  }
  match @ir.hot_node_get(func, outer_cond).op {
    @ir.HotOp::If => ()
    _ => fail("expected outer condition to remain a nested if")
  }
  let inner_then = @ir.hot_region_then_ref(func, outer_cond)
  let inner_else = match @ir.hot_region_else_ref(func, outer_cond) {
    Some(region) => region
    None => fail("expected nested if condition to keep an else region")
  }
  let inner_then_root = @ir.hot_region_get(func, inner_then, 0)
  let inner_else_root = @ir.hot_region_get(func, inner_else, 0)
  match @ir.hot_node_get(func, inner_then_root).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected nested if then arm to drop eqz and expose the local")
  }
  assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, inner_else_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(1)),
  )
  let outer_then = @ir.hot_region_then_ref(func, outer_if)
  let outer_else = match @ir.hot_region_else_ref(func, outer_if) {
    Some(region) => region
    None => fail("expected outer if to keep an else region")
  }
  let outer_then_root = @ir.hot_region_get(func, outer_then, 0)
  let outer_else_root = @ir.hot_region_get(func, outer_else, 0)
  match @ir.hot_node_get(func, outer_then_root).op {
    @ir.HotOp::If => ()
    _ => fail("expected outer then arm to become the previous else branch")
  }
  assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, outer_else_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(1)),
  )
}

///|
test "optimize-instructions negates nested boolean if conditions under then-only ifs" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32) (result i32) local.get 0 if (result i32) local.get 1 i32.eqz else i32.const 0 end if local.get 1 drop end i32.const 0))",
  )
  let outer_if = @ir.hot_root_get(func, 0)
  let outer_cond = @ir.hot_child_get(func, outer_if, 0)
  assert_eq(
    @ir.hot_node_exact_instr(func, outer_cond),
    Some(@lib.Instruction::i32_eqz()),
  )
  let nested_if = @ir.hot_child_get(func, outer_cond, 0)
  match @ir.hot_node_get(func, nested_if).op {
    @ir.HotOp::If => ()
    _ => fail("expected then-only outer if condition to remain a nested if")
  }
  let inner_then = @ir.hot_region_then_ref(func, nested_if)
  let inner_else = match @ir.hot_region_else_ref(func, nested_if) {
    Some(region) => region
    None => fail("expected nested if condition to keep an else region")
  }
  let inner_then_root = @ir.hot_region_get(func, inner_then, 0)
  let inner_else_root = @ir.hot_region_get(func, inner_else, 0)
  match @ir.hot_node_get(func, inner_then_root).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected nested if then arm to drop eqz and expose the local")
  }
  assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, inner_else_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(1)),
  )
}

///|
test "optimize-instructions recursively negates nested boolean if conditions under then-only ifs" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32 i32 i32) (result i32) local.get 0 if (result i32) local.get 1 if (result i32) i32.const 0 else local.get 2 if (result i32) i32.const 0 else local.get 3 i32.eqz end end else i32.const 0 end if local.get 1 drop end i32.const 0))",
  )
  let outer_if = @ir.hot_root_get(func, 0)
  let outer_cond = @ir.hot_child_get(func, outer_if, 0)
  assert_eq(
    @ir.hot_node_exact_instr(func, outer_cond),
    Some(@lib.Instruction::i32_eqz()),
  )
  let top_if = @ir.hot_child_get(func, outer_cond, 0)
  let top_then = @ir.hot_region_then_ref(func, top_if)
  let top_else = match @ir.hot_region_else_ref(func, top_if) {
    Some(region) => region
    None => fail("expected top nested if to keep an else region")
  }
  let top_then_root = @ir.hot_region_get(func, top_then, 0)
  let top_else_root = @ir.hot_region_get(func, top_else, 0)
  match @ir.hot_node_get(func, top_then_root).op {
    @ir.HotOp::If => ()
    _ => fail("expected recursive negation to preserve nested boolean if shape")
  }
  assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, top_else_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(1)),
  )
  let inner_if = top_then_root
  let inner_then = @ir.hot_region_then_ref(func, inner_if)
  let inner_else = match @ir.hot_region_else_ref(func, inner_if) {
    Some(region) => region
    None => fail("expected inner nested if to keep an else region")
  }
  assert_eq(
    @ir.hot_const_get(
      func,
      @ir.hot_node_get(func, @ir.hot_region_get(func, inner_then, 0)).imm0,
    ),
    @ir.HotConstPayload::i32_const(@lib.I32(1)),
  )
  let inner_else_root = @ir.hot_region_get(func, inner_else, 0)
  match @ir.hot_node_get(func, inner_else_root).op {
    @ir.HotOp::If => ()
    _ =>
      fail("expected inner else arm to remain the nested recursive boolean if")
  }
}

///|
test "optimize-instructions truncates dead suffixes after direct returns" {
  let func = @ir.HotFunc::new()
  let block = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, block), [
    @ir.hot_build_return(func, []),
    @ir.hot_build_const_i32(func, @lib.I32(0)),
  ])
  @ir.hot_root_append(func, block)
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected optimize-instructions direct-return dead-suffix cleanup success, got \{err}",
      )
  }

  let body = @ir.hot_region_body_ref(func, block)
  assert_eq(@ir.hot_region_root_count(func, body), 1)
  match @ir.hot_node_get(func, @ir.hot_region_get(func, body, 0)).op {
    @ir.HotOp::Return => ()
    _ => fail("expected dead roots after return to be truncated")
  }
}

///|
test "optimize-instructions canonicalizes commutative constants onto the rhs" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) i32.const 7 local.get 0 i32.add))",
  )
  let root = @ir.hot_root_get(func, 0)
  let lhs = @ir.hot_child_get(func, root, 0)
  let rhs = @ir.hot_child_get(func, root, 1)
  match @ir.hot_node_get(func, lhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected non-constant commutative operand to move into the lhs")
  }
  let rhs_node = @ir.hot_node_get(func, rhs)
  match rhs_node.op {
    @ir.HotOp::Const => ()
    _ => fail("expected commutative constant to move into the rhs")
  }
  assert_eq(
    @ir.hot_const_get(func, rhs_node.imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(7)),
  )
}

///|
test "optimize-instructions rewrites i32.mul by a power of two into shl" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 8 i32.mul))",
  )
  let root = @ir.hot_root_get(func, 0)
  assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_shl()),
  )
  let rhs = @ir.hot_child_get(func, root, 1)
  assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, rhs).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(3)),
  )
}

///|
test "optimize-instructions chains const canonicalization into i64.mul shl rewrite" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i64) (result i64) i64.const 4 local.get 0 i64.mul))",
  )
  let root = @ir.hot_root_get(func, 0)
  assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i64_shl()),
  )
  let lhs = @ir.hot_child_get(func, root, 0)
  let rhs = @ir.hot_child_get(func, root, 1)
  match @ir.hot_node_get(func, lhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected non-constant operand to stay on the lhs after rewrite")
  }
  assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, rhs).imm0),
    @ir.HotConstPayload::i64_const(@lib.I64(2L)),
  )
}

///|
test "optimize-instructions folds exact i32 const adds" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (result i32) i32.const 249384 i32.const 15 i32.add))",
  )
  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::Const => ()
    _ => fail("expected exact const add to fold into a const node")
  }
  assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(249399)),
  )
}

///|
test "optimize-instructions folds exact i32 const adds under and" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (result i32) i32.const 249384 i32.const 15 i32.add i32.const -16 i32.and))",
  )
  let root = @ir.hot_root_get(func, 0)
  let lhs = @ir.hot_child_get(func, root, 0)
  match @ir.hot_node_get(func, lhs).op {
    @ir.HotOp::Const => ()
    _ => fail("expected const-add child to fold before the enclosing and")
  }
  assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, lhs).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(249399)),
  )
}

///|
test "optimize-instructions keeps tlsf-style local plus shifted-local ordering canonical" {
  let func = optimize_instructions_test_run_hot(
    "(module (memory 1) (func (param i32 i32) (result i32) (local i32 i32 i32 i32) local.get 1 i32.load align=1 i32.const -4 i32.and local.tee 2 i32.const 256 i32.lt_u if (result i32) local.get 2 i32.const 4 i32.shr_u local.set 3 i32.const 0 else i32.const 31 local.get 2 i32.const 1073741820 local.get 2 i32.const 1073741820 i32.ge_u select local.tee 3 i32.clz i32.sub local.set 2 local.get 3 local.get 2 i32.const 4 i32.sub i32.shr_u i32.const 16 i32.xor local.set 3 local.get 2 i32.const 7 i32.sub end local.set 5 local.get 1 local.get 0 local.get 5 i32.const 4 i32.shl local.get 3 i32.add i32.const 2 i32.shl i32.add local.tee 4 i32.load offset=96 align=1 i32.eq))",
  )
  let root = @ir.hot_root_get(func, func.roots.length() - 1)
  let first = @ir.hot_child_get(func, root, 0)
  let second = @ir.hot_child_get(func, root, 1)
  let load = match @ir.hot_node_get(func, first).op {
    @ir.HotOp::Load => first
    _ =>
      match @ir.hot_node_get(func, second).op {
        @ir.HotOp::Load => second
        _ => fail("expected compare root to keep one load child")
      }
  }
  let load_addr = @ir.hot_child_get(func, load, 0)
  let top_add = @ir.hot_child_get(func, load_addr, 0)
  let scaled = @ir.hot_child_get(func, top_add, 0)
  let inner_add = @ir.hot_child_get(func, scaled, 0)
  let inner_lhs = @ir.hot_child_get(func, inner_add, 0)
  let inner_rhs = @ir.hot_child_get(func, inner_add, 1)
  match @ir.hot_node_get(func, inner_lhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected tlsf-style plain local term on the lhs")
  }
  assert_eq(@ir.hot_node_get(func, inner_lhs).imm0, 3)
  assert_eq(
    @ir.hot_node_exact_instr(func, inner_rhs),
    Some(@lib.Instruction::i32_shl()),
  )
}

///|
test "optimize-instructions canonicalizes commutative local gets after independent local state" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32) (result i32) (local i32) local.get 0 local.get 1 local.tee 2 i32.const 1 i32.shl i32.add))",
  )
  let root = @ir.hot_root_get(func, 0)
  assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_add()),
  )
  let lhs = @ir.hot_child_get(func, root, 0)
  let rhs = @ir.hot_child_get(func, root, 1)
  assert_eq(
    @ir.hot_node_exact_instr(func, lhs),
    Some(@lib.Instruction::i32_shl()),
  )
  let rhs_node = @ir.hot_node_get(func, rhs)
  match rhs_node.op {
    @ir.HotOp::LocalGet => ()
    _ =>
      fail("expected independent local.get to move to the canonical rhs slot")
  }
  assert_eq(rhs_node.imm0, 0)
}

///|
test "optimize-instructions canonicalizes commutative rhs local gets by node kind" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32) (result i32) local.get 1 i32.const 1 i32.shl local.get 0 i32.add))",
  )
  let root = @ir.hot_root_get(func, 0)
  let lhs = @ir.hot_child_get(func, root, 0)
  let rhs = @ir.hot_child_get(func, root, 1)
  match @ir.hot_node_get(func, lhs).op {
    @ir.HotOp::LocalGet => ()
    _ =>
      fail("expected rhs local.get to move into the lhs after node-kind sort")
  }
  assert_eq(@ir.hot_node_get(func, lhs).imm0, 0)
  assert_eq(
    @ir.hot_node_exact_instr(func, rhs),
    Some(@lib.Instruction::i32_shl()),
  )
}

///|
test "optimize-instructions canonicalizes commutative local gets across shared pure if leaves" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(
      params=[@lib.ValType::i32(), @lib.ValType::i32()],
      locals=[@lib.ValType::i32()],
    ),
  )
  let shared = @ir.hot_build_local_get(func, 1)
  let limit = @ir.hot_build_const_i32(func, @lib.I32(256))
  let cond = @ir.hot_build_compare(func, shared, limit)
  @ir.hot_node_exact_instr_set(func, cond, @lib.Instruction::i32_lt_u())
  let if_ = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    cond,
    [@ir.hot_build_const_i32(func, @lib.I32(0))],
    else_body=Some([shared]),
  )
  let tee = @ir.hot_build_local_tee(func, 2, if_)
  let shift = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    tee,
    @ir.hot_build_const_i32(func, @lib.I32(2)),
  )
  @ir.hot_node_exact_instr_set(func, shift, @lib.Instruction::i32_shl())
  let add = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    @ir.hot_build_local_get(func, 0),
    shift,
  )
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  @ir.hot_root_append(func, add)
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected optimize-instructions shared-if success, got \{err}")
  }

  let lhs = @ir.hot_child_get(func, add, 0)
  let rhs = @ir.hot_child_get(func, add, 1)
  assert_eq(
    @ir.hot_node_exact_instr(func, lhs),
    Some(@lib.Instruction::i32_shl()),
  )
  match @ir.hot_node_get(func, rhs).op {
    @ir.HotOp::LocalGet => ()
    _ =>
      fail(
        "expected shared-if canonicalization to move the plain local.get rhs",
      )
  }
}

///|
test "optimize-instructions canonicalizes commutative rhs local gets ahead of local.tee" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) (local i32 i32) local.get 0 local.tee 1 local.get 2 i32.eq))",
  )
  let root = @ir.hot_root_get(func, 0)
  let lhs = @ir.hot_child_get(func, root, 0)
  let rhs = @ir.hot_child_get(func, root, 1)
  match @ir.hot_node_get(func, lhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected rhs local.get to move ahead of local.tee")
  }
  assert_eq(@ir.hot_node_get(func, lhs).imm0, 2)
  match @ir.hot_node_get(func, rhs).op {
    @ir.HotOp::LocalTee => ()
    _ => fail("expected local.tee subtree to move behind the local.get")
  }
}

///|
test "optimize-instructions canonicalizes commutative local get pairs by index" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32 i32) (result i32) local.get 2 local.get 1 i32.add))",
  )
  let root = @ir.hot_root_get(func, 0)
  let lhs = @ir.hot_child_get(func, root, 0)
  let rhs = @ir.hot_child_get(func, root, 1)
  match @ir.hot_node_get(func, lhs).op {
    @ir.HotOp::LocalGet => ()
    _ =>
      fail("expected lhs to stay a local.get after local-pair canonicalization")
  }
  match @ir.hot_node_get(func, rhs).op {
    @ir.HotOp::LocalGet => ()
    _ =>
      fail("expected rhs to stay a local.get after local-pair canonicalization")
  }
  assert_eq(@ir.hot_node_get(func, lhs).imm0, 1)
  assert_eq(@ir.hot_node_get(func, rhs).imm0, 2)
}

///|
test "optimize-instructions canonicalizes relational local gets against calls" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32 i32) (result i32) local.get 2 local.get 0 local.get 1 local.get 2 call 0 i32.lt_s))",
  )
  let root = @ir.hot_root_get(func, 0)
  assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_gt_s()),
  )
  let lhs = @ir.hot_child_get(func, root, 0)
  let rhs = @ir.hot_child_get(func, root, 1)
  match @ir.hot_node_get(func, lhs).op {
    @ir.HotOp::Call => ()
    _ =>
      fail("expected relational canonicalization to move the call onto the lhs")
  }
  match @ir.hot_node_get(func, rhs).op {
    @ir.HotOp::LocalGet => ()
    _ =>
      fail(
        "expected relational canonicalization to move the local.get onto the rhs",
      )
  }
  assert_eq(@ir.hot_node_get(func, rhs).imm0, 2)
}

///|
test "optimize-instructions simplifies if i32.ne x 0 conditions" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32) (result i32) (if (result i32) (i32.ne (local.get 1) (i32.const 0)) (then (i32.const 1)) (else (i32.const 0)))))",
  )
  let root = @ir.hot_root_get(func, 0)
  let cond = @ir.hot_child_get(func, root, 0)
  match @ir.hot_node_get(func, cond).op {
    @ir.HotOp::LocalGet => ()
    _ =>
      fail(
        "expected boolean if condition to collapse to the underlying local.get",
      )
  }
  assert_eq(@ir.hot_node_get(func, cond).imm0, 1)
}

///|
test "optimize-instructions flips if i32.eqz conditions by swapping arms" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32) (result i32) (if (result i32) (i32.eqz (local.get 0)) (then (local.get 1)) (else (i32.const 7)))))",
  )
  let root = @ir.hot_root_get(func, 0)
  let cond = @ir.hot_child_get(func, root, 0)
  match @ir.hot_node_get(func, cond).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected flipped if to use the raw local.get as its condition")
  }
  assert_eq(@ir.hot_node_get(func, cond).imm0, 0)
  let then_region = @ir.hot_region_then_ref(func, root)
  let else_region = @ir.hot_region_else_ref(func, root).unwrap()
  let then_root = @ir.hot_region_get(func, then_region, 0)
  let else_root = @ir.hot_region_get(func, else_region, 0)
  match @ir.hot_node_get(func, then_root).op {
    @ir.HotOp::Const => ()
    _ => fail("expected flipped then arm to hold the original else payload")
  }
  assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, then_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(7)),
  )
  match @ir.hot_node_get(func, else_root).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected flipped else arm to hold the original then payload")
  }
  assert_eq(@ir.hot_node_get(func, else_root).imm0, 1)
}

///|
test "optimize-instructions wraps boolean value ifs in eqz at unique child uses" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32) (result i32) (local i32) local.get 0 if (result i32) local.get 1 i32.eqz else i32.const 0 end local.set 2 local.get 2))",
  )
  let set_ = @ir.hot_root_get(func, 0)
  let wrapped = @ir.hot_child_get(func, set_, 0)
  assert_eq(
    @ir.hot_node_exact_instr(func, wrapped),
    Some(@lib.Instruction::i32_eqz()),
  )
  let nested_if = @ir.hot_child_get(func, wrapped, 0)
  match @ir.hot_node_get(func, nested_if).op {
    @ir.HotOp::If => ()
    _ => fail("expected wrapped value rewrite to preserve the nested if")
  }
  let then_region = @ir.hot_region_then_ref(func, nested_if)
  let else_region = match @ir.hot_region_else_ref(func, nested_if) {
    Some(region) => region
    None => fail("expected wrapped value if to keep an else region")
  }
  let then_root = @ir.hot_region_get(func, then_region, 0)
  let else_root = @ir.hot_region_get(func, else_region, 0)
  match @ir.hot_node_get(func, then_root).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected wrapped value if then arm to expose the local")
  }
  assert_eq(@ir.hot_node_get(func, then_root).imm0, 1)
  assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, else_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(1)),
  )
}

///|
test "optimize-instructions keeps boolean value ifs unwrapped when they feed if conditions" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32 i32) (result i32) local.get 0 if (result i32) local.get 1 if (result i32) local.get 2 i32.eqz else i32.const 0 end else i32.const 0 end if (result i32) i32.const 7 else i32.const 8 end))",
  )
  let outer_if = @ir.hot_root_get(func, 0)
  let outer_cond = @ir.hot_child_get(func, outer_if, 0)
  match @ir.hot_node_get(func, outer_cond).op {
    @ir.HotOp::If => ()
    _ => fail("expected outer if condition to remain the nested boolean if")
  }
  let outer_then = @ir.hot_region_then_ref(func, outer_if)
  let outer_else = match @ir.hot_region_else_ref(func, outer_if) {
    Some(region) => region
    None => fail("expected outer if to keep an else region")
  }
  let then_root = @ir.hot_region_get(func, outer_then, 0)
  let else_root = @ir.hot_region_get(func, outer_else, 0)
  assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, then_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(7)),
  )
  assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, else_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(8)),
  )
  let cond_then = @ir.hot_region_then_ref(func, outer_cond)
  let cond_then_root = @ir.hot_region_get(func, cond_then, 0)
  match @ir.hot_node_get(func, cond_then_root).op {
    @ir.HotOp::If => ()
    _ => fail("expected nested boolean then arm to stay as the inner if")
  }
}

///|
test "optimize-instructions keeps boolean value ifs unwrapped in branch payloads" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) block (result i32) local.get 0 if (result i32) i32.const 1 else i32.const 0 end br 0 end))",
  )
  let block = @ir.hot_root_get(func, 0)
  let body = @ir.hot_region_body_ref(func, block)
  let branch = @ir.hot_region_get(func, body, 0)
  let payload = @ir.hot_child_get(func, branch, 0)
  match @ir.hot_node_get(func, payload).op {
    @ir.HotOp::If => ()
    _ => fail("expected branch payload to stay as the original value if")
  }
}

///|
test "optimize-instructions keeps trivial boolean value ifs unwrapped in local sets" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) (local i32) local.get 0 if (result i32) i32.const 0 else i32.const 1 end local.set 1 local.get 1))",
  )
  let set_ = @ir.hot_root_get(func, 0)
  let payload = @ir.hot_child_get(func, set_, 0)
  match @ir.hot_node_get(func, payload).op {
    @ir.HotOp::If => ()
    _ =>
      fail(
        "expected trivial boolean local-set payload to stay as the original if",
      )
  }
}

///|
test "optimize-instructions keeps constant boolean decision trees unwrapped in local sets" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32) (result i32) (local i32) local.get 0 if (result i32) i32.const 1 else local.get 1 if (result i32) i32.const 1 else i32.const 0 end end local.set 2 local.get 2))",
  )
  let set_ = @ir.hot_root_get(func, 0)
  let payload = @ir.hot_child_get(func, set_, 0)
  match @ir.hot_node_get(func, payload).op {
    @ir.HotOp::If => ()
    _ =>
      fail(
        "expected constant boolean local-set decision tree to stay as the original if",
      )
  }
}

///|
test "optimize-instructions keeps zero sentinels after returning ifs in result blocks" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) (block (result i32) (if (result i32) (local.get 0) (then (block (return (i32.const 1)))) (else (block (return (i32.const 0))))) (i32.const 0))))",
  )
  let block = @ir.hot_root_get(func, 0)
  let body = @ir.hot_region_body_ref(func, block)
  assert_eq(@ir.hot_region_root_count(func, body), 2)
  let tail = @ir.hot_region_get(func, body, 1)
  match @ir.hot_node_get(func, tail).op {
    @ir.HotOp::Const => ()
    _ =>
      fail(
        "expected result-block zero sentinel to stay explicit after a returning if",
      )
  }
}

///|
test "optimize-instructions keeps zero sentinels after wrapped returning ifs in result blocks" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) (block (result i32) (block (result i32) (if (result i32) (local.get 0) (then (block (return (i32.const 1)))) (else (block (return (i32.const 0))))) (i32.const 0)))))",
  )
  let outer = @ir.hot_root_get(func, 0)
  let outer_body = @ir.hot_region_body_ref(func, outer)
  let inner = @ir.hot_region_get(func, outer_body, 0)
  let inner_body = @ir.hot_region_body_ref(func, inner)
  assert_eq(@ir.hot_region_root_count(func, inner_body), 2)
  let tail = @ir.hot_region_get(func, inner_body, 1)
  match @ir.hot_node_get(func, tail).op {
    @ir.HotOp::Const => ()
    _ =>
      fail(
        "expected wrapped result-block zero sentinel to stay explicit after a returning if",
      )
  }
}

///|
test "optimize-instructions keeps zero sentinels after returning ifs with dead arm suffixes" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) (block (result i32) (if (local.get 0) (then (return (i32.const 1)) (i32.const 9)) (else (return (i32.const 0)) (i32.const 8))) (i32.const 0))))",
  )
  let block = @ir.hot_root_get(func, 0)
  let body = @ir.hot_region_body_ref(func, block)
  assert_eq(@ir.hot_region_root_count(func, body), 2)
  let tail = @ir.hot_region_get(func, body, 1)
  match @ir.hot_node_get(func, tail).op {
    @ir.HotOp::Const => ()
    _ =>
      fail(
        "expected result-block zero sentinel to stay explicit when if arms end in dead suffixes",
      )
  }
}

///|
test "optimize-instructions does not reorder across the same local" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 local.get 0 local.tee 0 i32.const 1 i32.shl i32.add))",
  )
  let root = @ir.hot_root_get(func, 0)
  let lhs = @ir.hot_child_get(func, root, 0)
  let lhs_node = @ir.hot_node_get(func, lhs)
  match lhs_node.op {
    @ir.HotOp::LocalGet => ()
    _ =>
      fail(
        "expected same-local read to stay ahead of a conflicting tee subtree",
      )
  }
  assert_eq(lhs_node.imm0, 0)
}

///|
test "optimize-instructions canonicalizes commutative local gets after trapping loads" {
  let func = optimize_instructions_test_run_hot(
    "(module (memory 1) (func (param i32 i32) (result i32) local.get 0 local.get 1 i32.load i32.add))",
  )
  let root = @ir.hot_root_get(func, 0)
  let lhs = @ir.hot_child_get(func, root, 0)
  let rhs = @ir.hot_child_get(func, root, 1)
  match @ir.hot_node_get(func, lhs).op {
    @ir.HotOp::Load => ()
    _ =>
      fail("expected trapping load subtree to move into the canonical lhs slot")
  }
  match @ir.hot_node_get(func, rhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected pure local.get to move behind a trapping load subtree")
  }
  assert_eq(@ir.hot_node_get(func, rhs).imm0, 0)
}

///|
test "optimize-instructions removes redundant shift masks" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32) (result i32) local.get 0 local.get 1 i32.const 31 i32.and i32.shl))",
  )
  let root = @ir.hot_root_get(func, 0)
  assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_shl()),
  )
  let rhs = @ir.hot_child_get(func, root, 1)
  match @ir.hot_node_get(func, rhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected redundant shift mask to collapse to the masked operand")
  }
}

///|
test "optimize-instructions removes effective zero shifts" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 32 i32.shl))",
  )
  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected effective zero shift to become its lhs operand")
  }
}

///|
test "optimize-instructions folds unsigned ge zero on pure values" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 0 i32.ge_u))",
  )
  let root = @ir.hot_root_get(func, 0)
  let root_node = @ir.hot_node_get(func, root)
  match root_node.op {
    @ir.HotOp::Const => ()
    _ => fail("expected unsigned ge zero to fold to a const")
  }
  assert_eq(
    @ir.hot_const_get(func, root_node.imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(1)),
  )
}

///|
test "optimize-instructions canonicalizes relational constants onto the rhs" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) i32.const 9 local.get 0 i32.gt_u))",
  )
  let root = @ir.hot_root_get(func, 0)
  assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_lt_u()),
  )
  let lhs = @ir.hot_child_get(func, root, 0)
  let rhs = @ir.hot_child_get(func, root, 1)
  match @ir.hot_node_get(func, lhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected non-constant compare operand on the lhs")
  }
  assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, rhs).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(9)),
  )
}

///|
test "optimize-instructions canonicalizes unsigned compare-to-one" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 1 i32.lt_u))",
  )
  let root = @ir.hot_root_get(func, 0)
  assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_eq()),
  )
  let rhs = @ir.hot_child_get(func, root, 1)
  assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, rhs).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )
}

///|
test "optimize-instructions canonicalizes signed compare to zero" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 1 i32.ge_s))",
  )
  let root = @ir.hot_root_get(func, 0)
  assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_gt_s()),
  )
  let rhs = @ir.hot_child_get(func, root, 1)
  assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, rhs).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )
}

///|
test "optimize-instructions does not reorder relational operands across shared tee payloads" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  let shared = @ir.hot_build_local_get(func, 1)
  let tee = @ir.hot_build_local_tee(func, 2, shared)
  let limit = @ir.hot_build_local_get(func, 0)
  let compare = @ir.hot_build_compare(func, tee, limit)
  @ir.hot_node_exact_instr_set(func, compare, @lib.Instruction::i32_lt_s())
  @ir.hot_root_append(func, compare)
  @ir.hot_root_append(func, @ir.hot_build_drop(func, shared))
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected optimize-instructions shared-tee success, got \{err}")
  }

  assert_eq(
    @ir.hot_node_exact_instr(func, compare),
    Some(@lib.Instruction::i32_lt_s()),
  )
  match @ir.hot_node_get(func, @ir.hot_child_get(func, compare, 0)).op {
    @ir.HotOp::LocalTee => ()
    _ => fail("expected shared tee subtree to stay on the lhs")
  }
  let lowered = @ir.hot_lower_func(func)
  let @lib.Func(locals, body) = lowered
  assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  assert_eq(
    body,
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::i32_lt_s(),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::drop(),
    ]),
  )
}

///|
test "optimize-instructions does not allocate scratch locals for shared relational tee payloads in blocks" {
  let fixture = @ir.ir_test_build_hot_from_wat(
    "(module (func (param i32) (result i32) (local i32 i32) i32.const 0 local.set 1 loop $label2 block $block5 block $block4 (result i32) local.get 1 local.tee 2 local.get 0 i32.lt_s if local.get 2 i32.const 1 i32.add br $block4 end br $block5 end local.set 1 end br $label2 end local.get 1))",
  )
  let func = fixture.hot_func
  let loop_id = @ir.hot_root_get(func, 1)
  let block5 = @ir.hot_region_get(
    func,
    @ir.hot_region_body_ref(func, loop_id),
    0,
  )
  let set1 = @ir.hot_region_get(func, @ir.hot_region_body_ref(func, block5), 0)
  let block4 = @ir.hot_child_get(func, set1, 0)
  let block4_body = @ir.hot_region_body_ref(func, block4)
  let if_id = @ir.hot_region_get(func, block4_body, 0)
  let branch = @ir.hot_region_get(func, block4_body, 1)
  let compare = @ir.hot_child_get(func, if_id, 0)
  let tee = @ir.hot_child_get(func, compare, 0)
  let shared = @ir.hot_child_get(func, tee, 0)
  @ir.hot_region_replace_body(func, block4_body, [
    if_id,
    @ir.hot_build_drop(func, shared),
    branch,
  ])
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected optimize-instructions shared-block success, got \{err}")
  }

  let lowered = @ir.hot_lower_func(func)
  let @lib.Func(locals, _) = lowered
  assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
}

///|
test "optimize-instructions does not allocate scratch locals for shared tee payload fallthroughs" {
  let fixture = @ir.ir_test_build_hot_from_wat(
    "(module (func (param i32) (result i32) (local i32 i32) i32.const 0 local.set 1 loop $label block $body (result i32) local.get 1 local.tee 2 local.get 0 i32.lt_s if local.get 2 i32.const 1 i32.add br $body end local.get 1 end local.set 1 br $label end unreachable))",
  )
  let func = fixture.hot_func
  let loop_id = @ir.hot_root_get(func, 1)
  let set1 = @ir.hot_region_get(func, @ir.hot_region_body_ref(func, loop_id), 0)
  let body = @ir.hot_child_get(func, set1, 0)
  let body_region = @ir.hot_region_body_ref(func, body)
  let if_id = @ir.hot_region_get(func, body_region, 0)
  let compare = @ir.hot_child_get(func, if_id, 0)
  let tee = @ir.hot_child_get(func, compare, 0)
  let shared = @ir.hot_child_get(func, tee, 0)
  @ir.hot_region_replace_body(func, body_region, [if_id, shared])
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected optimize-instructions shared-fallthrough success, got \{err}",
      )
  }

  let lowered = @ir.hot_lower_func(func)
  let @lib.Func(locals, _) = lowered
  assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
}

///|
test "optimize-instructions does not reorder relational local gets across control-bearing tee payloads" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  let block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
  )
  let label = @ir.hot_control_node_label(func, block)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, block), [
    @ir.hot_build_br(func, label, values=[
      @ir.hot_build_const_i32(func, @lib.I32(7)),
    ]),
  ])
  let tee = @ir.hot_build_local_tee(func, 2, block)
  let limit = @ir.hot_build_local_get(func, 0)
  let compare = @ir.hot_build_compare(func, tee, limit)
  @ir.hot_node_exact_instr_set(func, compare, @lib.Instruction::i32_lt_s())
  @ir.hot_root_append(func, @ir.hot_build_drop(func, compare))
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected optimize-instructions control-tee success, got \{err}")
  }

  assert_eq(
    @ir.hot_node_exact_instr(func, compare),
    Some(@lib.Instruction::i32_lt_s()),
  )
  match @ir.hot_node_get(func, @ir.hot_child_get(func, compare, 0)).op {
    @ir.HotOp::LocalTee => ()
    _ => fail("expected control-bearing tee subtree to stay on the lhs")
  }
}

///|
test "optimize-instructions does not reorder relational local gets across loop-carried tees" {
  let fixture = @ir.ir_test_build_hot_from_wat(
    "(module (func (param i32) (result i32) (local i32) (block (result i32) (i32.const 0) (loop (param i32) (result i32) (if (result i32) (i32.lt_s (local.tee 1) (local.get 0)) (then (local.get 1) (i32.const 1) (i32.add) (br 1)) (else (local.get 1)))))))",
  )
  let func = fixture.hot_func
  let block_id = @ir.hot_root_get(func, 0)
  let block_body = @ir.hot_region_body_ref(func, block_id)
  let loop_id = @ir.hot_region_get(func, block_body, 0)
  let body_region = @ir.hot_region_body_ref(func, loop_id)
  let if_id = @ir.hot_region_get(func, body_region, 0)
  let compare = @ir.hot_child_get(func, if_id, 0)
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected optimize-instructions loop-carried success, got \{err}")
  }

  assert_eq(
    @ir.hot_node_exact_instr(func, compare),
    Some(@lib.Instruction::i32_lt_s()),
  )
  match @ir.hot_node_get(func, @ir.hot_child_get(func, compare, 0)).op {
    @ir.HotOp::LocalTee => ()
    _ => fail("expected loop-carried tee subtree to stay on the lhs")
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, compare, 1)).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected loop-carried limit local.get to stay on the rhs")
  }
}

///|
test "optimize-instructions visits shared dags once" {
  let func = optimize_instructions_shared_dag_fixture(24)
  let node_count = @ir.hot_node_count(func)
  let perf = HotPerfSession::new()
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
    perf=Some(perf),
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected optimize-instructions shared-dag success, got \{err}")
  }

  let counters = perf_counters(perf)
  assert_eq(counters.traversal_visits, node_count)
}
