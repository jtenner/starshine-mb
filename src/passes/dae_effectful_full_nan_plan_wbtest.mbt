///|
fn dae_effectful_nan_plan_fixture(position : String) -> @lib.Module {
  let caller = if position == "zero-first" {
    "f32.const 0 drop i32.const 7 call $h"
  } else if position == "first" {
    "f32.const nan:0x400021 drop i32.const 7 call $h"
  } else if position == "last" {
    "i32.const 7 call $h drop f32.const nan:0x400021"
  } else {
    "i32.const 0 f32.const nan:0x400021 drop i32.const 7 call $h i32.add"
  }
  let result = if position == "last" { "f32" } else { "i32" }
  pass_test_module_from_wat(
    "(module (func $h (param i32) (result i32) local.get 0) (func (export \"run\") (result \{result}) \{caller}))",
  )
}

///|
fn dae_effectful_nan_plan_build(
  input : @lib.Module,
  value : @lib.Instruction,
) -> (DaeCurrentBoundaryGraph, DaeRewritePlan) {
  let graph = dae_current_boundary_graph_new(input)
  let params = match graph.snapshot.function_types[0].unwrap() {
    @lib.FuncType(params, _) => params
  }
  let @lib.Func(locals, _) = graph.snapshot.funcs[0]
  let plan = dae_build_scalar_unused_param_rewrite_plan(
    input,
    dae_collect_original_boundary_snapshot(input),
    graph,
    0,
    [true],
    dae_local_use_for_callee(
      graph.snapshot.funcs[0],
      params.length() + locals.length(),
      0,
      params.length(),
    ),
    graph.snapshot.boundary_facts.direct_calls[0],
    graph.snapshot.boundary_facts.direct_callers[0],
    entry_live=Some([true]),
    materialized_params=Some([Some(value)]),
  ).unwrap()
  (graph, plan)
}

///|
fn dae_effectful_nan_plan_preflight(
  input : @lib.Module,
  plan : DaeRewritePlan,
) -> Unit raise {
  @validate.validate_module(input).unwrap()
  @validate.validate_module(plan.candidate).unwrap()
  assert_eq(
    plan.replacement_signature,
    @lib.FuncType::new([], [@lib.ValType::i32()]),
  )
  assert_eq(plan.caller_rewrites.length(), 1)
  assert_eq(plan.expected_direct_call_count, 1)
  let rewrite = plan.caller_rewrites[0]
  assert_eq(rewrite.def_idx, 1)
  assert_true(physical_equal(rewrite.func, plan.rewritten_funcs[1]))
  assert_true(
    dae_snapshot_func_unchanged(rewrite.func, plan.rewritten_funcs[1]),
  )
  let @lib.Func(_, @lib.Expr(callee)) = plan.callee_rewrite
  assert_eq(callee, [@lib.Instruction::i32_const(@lib.I32(7))])
  assert_true(
    @binary.encode_module(input).unwrap() !=
    @binary.encode_module(plan.candidate).unwrap(),
  )
}

///|
test "DAE scalar plan accepts identical caller bits with an interior NaN before any new batching" {
  let input = dae_effectful_nan_plan_fixture("middle")
  let saved = @binary.encode_module(input).unwrap()
  let (_, plan) = dae_effectful_nan_plan_build(
    input,
    @lib.Instruction::i32_const(@lib.I32(7)),
  )
  dae_effectful_nan_plan_preflight(input, plan)
  assert_true(dae_rewrite_plan_candidate_caller_boundaries_match(plan))
  assert_false(plan.caller_rewrites[0].func == plan.rewritten_funcs[1])
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_true(dae_rewrite_plan_is_consistent(plan))
}

///|
test "DAE scalar plan accepts an identical first NaN caller boundary" {
  let input = dae_effectful_nan_plan_fixture("first")
  let saved = @binary.encode_module(input).unwrap()
  let (_, plan) = dae_effectful_nan_plan_build(
    input,
    @lib.Instruction::i32_const(@lib.I32(7)),
  )
  dae_effectful_nan_plan_preflight(input, plan)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_true(dae_rewrite_plan_candidate_caller_boundaries_match(plan))
  assert_true(dae_rewrite_plan_is_consistent(plan))
}

///|
test "DAE scalar plan accepts an identical last NaN caller boundary" {
  let input = dae_effectful_nan_plan_fixture("last")
  let saved = @binary.encode_module(input).unwrap()
  let (_, plan) = dae_effectful_nan_plan_build(
    input,
    @lib.Instruction::i32_const(@lib.I32(7)),
  )
  dae_effectful_nan_plan_preflight(input, plan)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_true(dae_rewrite_plan_candidate_caller_boundaries_match(plan))
  assert_true(dae_rewrite_plan_is_consistent(plan))
}

///|
test "DAE scalar plan applies a valid integer materialization while retaining unrelated caller NaN bits" {
  let input = dae_effectful_nan_plan_fixture("middle")
  let saved = @binary.encode_module(input).unwrap()
  let (graph, plan) = dae_effectful_nan_plan_build(
    input,
    @lib.Instruction::i32_const(@lib.I32(7)),
  )
  dae_effectful_nan_plan_preflight(input, plan)
  let actual = dae_apply_rewrite_plan(input, graph, plan)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  println("@NAN_PLAN_APPLICATION applied=\{actual.applied}")
  assert_true(actual.applied)
  assert_eq(
    @binary.encode_module(actual.result.mod_out).unwrap(),
    @binary.encode_module(plan.candidate).unwrap(),
  )
  @validate.validate_module(actual.result.mod_out).unwrap()
}

///|
test "DAE scalar materialization retains exact float payloads and signed zero in the callee" {
  for
    (kind, literal) in [
      ("f32", "nan:0x400021"),
      ("f64", "nan:0x8000000000001"),
      ("f64", "-0"),
      ("f64", "0"),
    ] {
    let input = pass_test_module_from_wat(
      "(module (memory 1) (func $h (param \{kind}) (result i32) i32.const 16 local.get 0 \{kind}.store i32.const 1) (func (export \"run\") (result i32) \{kind}.const \{literal} call $h))",
    )
    let saved = @binary.encode_module(input).unwrap()
    let @lib.Func(_, @lib.Expr(caller)) = input.code_sec.unwrap().0[1]
    let (graph, plan) = dae_effectful_nan_plan_build(input, caller[0])
    @validate.validate_module(plan.candidate).unwrap()
    let expected = pass_test_module_from_wat(
      "(module (memory 1) (func (result i32) i32.const 16 \{kind}.const \{literal} \{kind}.store i32.const 1))",
    )
    assert_true(
      dae_snapshot_func_unchanged(
        plan.callee_rewrite,
        expected.code_sec.unwrap().0[0],
      ),
    )
    let actual = dae_apply_rewrite_plan(input, graph, plan)
    assert_true(actual.applied)
    assert_eq(
      @binary.encode_module(actual.result.mod_out).unwrap(),
      @binary.encode_module(plan.candidate).unwrap(),
    )
    @validate.validate_module(actual.result.mod_out).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "DAE scalar plan intentionally rejects changed candidate caller payload bits" {
  let input = dae_effectful_nan_plan_fixture("first")
  let saved = @binary.encode_module(input).unwrap()
  let (graph, plan) = dae_effectful_nan_plan_build(
    input,
    @lib.Instruction::i32_const(@lib.I32(7)),
  )
  dae_effectful_nan_plan_preflight(input, plan)
  let replacement = pass_test_module_from_wat(
    "(module (func (result f32) f32.const nan:0x400022))",
  )
  let @lib.Func(_, @lib.Expr(replacement_body)) = replacement.code_sec.unwrap().0[0]
  let funcs = plan.candidate.code_sec.unwrap().0.copy()
  let @lib.Func(locals, @lib.Expr(body)) = funcs[1]
  let changed = body.copy()
  changed[0] = replacement_body[0]
  funcs[1] = @lib.Func::new(locals, @lib.Expr::new(changed))
  let mismatch = {
    ..plan,
    candidate: plan.candidate.with_code_sec(@lib.CodeSec::new(funcs)),
  }
  assert_false(dae_rewrite_plan_candidate_caller_boundaries_match(mismatch))
  assert_false(dae_rewrite_plan_is_consistent(mismatch))
  assert_false(dae_apply_rewrite_plan(input, graph, mismatch).applied)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE scalar plan accepts rebuilt caller functions with identical NaN payload bits" {
  let input = dae_effectful_nan_plan_fixture("middle")
  let saved = @binary.encode_module(input).unwrap()
  let (_, plan) = dae_effectful_nan_plan_build(
    input,
    @lib.Instruction::i32_const(@lib.I32(7)),
  )
  dae_effectful_nan_plan_preflight(input, plan)
  let rewrites = plan.caller_rewrites.copy()
  let rewrite = rewrites[0]
  let @lib.Func(locals, @lib.Expr(body)) = rewrite.func
  let rebuilt = @lib.Func::new(locals.copy(), @lib.Expr::new(body.copy()))
  rewrites[0] = { ..rewrite, func: rebuilt, }
  let rebuilt_plan = { ..plan, caller_rewrites: rewrites, }
  assert_false(physical_equal(rebuilt, plan.rewritten_funcs[1]))
  assert_true(dae_snapshot_func_unchanged(rebuilt, plan.rewritten_funcs[1]))
  @validate.validate_module(rebuilt_plan.candidate).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_true(dae_rewrite_plan_is_consistent(rebuilt_plan))
}

///|
test "DAE scalar plan intentionally rejects opposite signed zero in a candidate caller boundary" {
  let input = dae_effectful_nan_plan_fixture("zero-first")
  let saved = @binary.encode_module(input).unwrap()
  let (_, plan) = dae_effectful_nan_plan_build(
    input,
    @lib.Instruction::i32_const(@lib.I32(7)),
  )
  dae_effectful_nan_plan_preflight(input, plan)
  assert_true(dae_rewrite_plan_is_consistent(plan))
  let minus_zero = pass_test_module_from_wat(
    "(module (func (result f32) f32.const -0))",
  )
  let @lib.Func(_, @lib.Expr(zero_body)) = minus_zero.code_sec.unwrap().0[0]
  let funcs = plan.candidate.code_sec.unwrap().0.copy()
  let @lib.Func(locals, @lib.Expr(body)) = funcs[1]
  let changed = body.copy()
  changed[0] = zero_body[0]
  funcs[1] = @lib.Func::new(locals, @lib.Expr::new(changed))
  let mismatch = {
    ..plan,
    candidate: plan.candidate.with_code_sec(@lib.CodeSec::new(funcs)),
  }
  assert_false(dae_snapshot_func_unchanged(funcs[1], plan.rewritten_funcs[1]))
  assert_false(dae_rewrite_plan_is_consistent(mismatch))
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_false(dae_rewrite_plan_candidate_caller_boundaries_match(mismatch))
}

///|
test "DAE scalar plan intentionally rejects opposite signed zero in its cached caller rewrite record" {
  let input = dae_effectful_nan_plan_fixture("zero-first")
  let saved = @binary.encode_module(input).unwrap()
  let (_, plan) = dae_effectful_nan_plan_build(
    input,
    @lib.Instruction::i32_const(@lib.I32(7)),
  )
  dae_effectful_nan_plan_preflight(input, plan)
  assert_true(dae_rewrite_plan_is_consistent(plan))
  let minus_zero = pass_test_module_from_wat(
    "(module (func (result f32) f32.const -0))",
  )
  let @lib.Func(_, @lib.Expr(zero_body)) = minus_zero.code_sec.unwrap().0[0]
  let rewrites = plan.caller_rewrites.copy()
  let rewrite = rewrites[0]
  let @lib.Func(locals, @lib.Expr(body)) = rewrite.func
  let changed = body.copy()
  changed[0] = zero_body[0]
  rewrites[0] = {
    ..rewrite,
    func: @lib.Func::new(locals, @lib.Expr::new(changed)),
  }
  let mismatch = { ..plan, caller_rewrites: rewrites, }
  assert_false(
    dae_snapshot_func_unchanged(rewrites[0].func, plan.rewritten_funcs[1]),
  )
  @validate.validate_module(mismatch.candidate).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_false(dae_rewrite_plan_is_consistent(mismatch))
}
