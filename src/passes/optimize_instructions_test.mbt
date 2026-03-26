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
test "optimize-instructions prefers signed-leb-friendly add immediates" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 64 i32.add))",
  )
  let root = @ir.hot_root_get(func, 0)
  assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_sub()),
  )
  let rhs = @ir.hot_child_get(func, root, 1)
  assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, rhs).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(-64)),
  )
}

///|
test "optimize-instructions chains const canonicalization into leb rewrite" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) i32.const 64 local.get 0 i32.add))",
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
    _ => fail("expected chained rewrite to leave the non-constant on the lhs")
  }
  assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, rhs).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(-64)),
  )
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
