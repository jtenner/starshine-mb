///|
fn dae_signature_plan_metadata_fixture(
  siblings : Int32,
) -> (@lib.Module, @lib.Module) {
  let extra = StringBuilder()
  for index in 0..<siblings {
    extra.write_string(
      " (func $side\{index} (param i32) (result i32) local.get 0",
    )
    if index > 0 {
      extra.write_string(" call $side\{index - 1}")
    }
    extra.write_string(")")
  }
  let suffix = extra.to_string()
  (
    pass_test_module_from_wat(
      "(module (func $target (param i32) (result i32) local.get 0) " +
      "(func (export \"run\") i32.const 7 call $target drop)\{suffix})",
    ),
    pass_test_module_from_wat(
      "(module (func $target (param i32) local.get 0 drop) " +
      "(func (export \"run\") i32.const 7 call $target)\{suffix})",
    ).without_name_sec(),
  )
}

///|
fn dae_signature_plan_metadata_effects(defined : Int32) -> DaeCommitEffects {
  let effects = dae_commit_effects_empty(defined)
  effects.structurally_touched[0] = true
  effects.structurally_touched[1] = true
  effects.result_changed[0] = true
  effects.result_removed[0] = true
  effects.control_refinalization_required[0] = true
  effects.worth_decided[0] = true
  effects.worth_optimizing[0] = true
  effects.worth_decided[1] = true
  effects.worth_optimizing[1] = true
  effects.caller_drop_removed[1] = true
  effects
}

///|
test "DAE signature plan retains exact result rewrite caller evidence and source ownership" {
  let (input, expected) = dae_signature_plan_metadata_fixture(2)
  let saved = @binary.encode_module(input).unwrap()
  let graph = dae_current_boundary_graph_new(input)
  let touched = [true, true, false, false]
  let candidate : DaePassResult = {
    mod_out: expected,
    touched,
    changed: true,
    primary_def: 0,
  }
  let effects = dae_signature_plan_metadata_effects(4)
  let plan = dae_build_signature_rewrite_plan_from_candidate(
    dae_collect_original_boundary_snapshot(input),
    input,
    graph,
    0,
    candidate,
    effects,
  ).unwrap()
  assert_eq(plan.parameter_actions, [DaeKeepParameter])
  assert_eq(plan.result_actions, [DaeRemoveResult])
  assert_eq(plan.expected_direct_call_count, 1)
  assert_eq(plan.expected_return_call_count, 0)
  assert_eq(plan.expected_callers.length(), 1)
  assert_eq(plan.expected_callers[0].def_idx, 1)
  assert_eq(plan.expected_call_identities.length(), 1)
  assert_eq(plan.expected_call_identities[0].path.to_array(), [1])
  assert_true(plan.invalidated_dependencies.contains(0))
  assert_true(dae_rewrite_plan_is_consistent(plan))
  let application = dae_apply_rewrite_plan(input, graph, plan)
  assert_true(application.applied)
  @validate.validate_module(application.result.mod_out).unwrap()
  assert_eq(
    @binary.encode_module(application.result.mod_out).unwrap(),
    @binary.encode_module(expected).unwrap(),
  )
  assert_eq(application.result.touched, [true, true, false, false])
  assert_eq(touched, [true, true, false, false])
  assert_eq(effects.structurally_touched, [true, true, false, false])
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE signature plan still rejects stale module and caller body epochs" {
  let (input, expected) = dae_signature_plan_metadata_fixture(1)
  let saved = @binary.encode_module(input).unwrap()
  for stale_module in [false, true] {
    let graph = dae_current_boundary_graph_new(input)
    let plan = dae_build_signature_rewrite_plan_from_candidate(
      dae_collect_original_boundary_snapshot(input),
      input,
      graph,
      0,
      {
        mod_out: expected,
        touched: [true, true, false],
        changed: true,
        primary_def: 0,
      },
      dae_signature_plan_metadata_effects(3),
    ).unwrap()
    if stale_module {
      graph.module_epoch += 1
    } else {
      graph.function_epochs[1].body_epoch += 1
    }
    let application = dae_apply_rewrite_plan(input, graph, plan)
    assert_false(application.applied)
    assert_eq(application.reason, DaeStaleCandidateFacts)
    assert_true(physical_equal(application.result.mod_out, input))
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "DAE signature plan retains whole candidate validation for invalid result bodies" {
  let (input, expected) = dae_signature_plan_metadata_fixture(0)
  let funcs = expected.code_sec.unwrap().0.copy()
  // This deliberately invalid candidate leaves a value in a void function.
  funcs[0] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([@lib.Instruction::i64_const(@lib.I64(9L))]),
  )
  let graph = dae_current_boundary_graph_new(input)
  let plan = dae_build_signature_rewrite_plan_from_candidate(
    dae_collect_original_boundary_snapshot(input),
    input,
    graph,
    0,
    {
      mod_out: expected.with_code_sec(@lib.CodeSec::new(funcs)),
      touched: [true, true],
      changed: true,
      primary_def: 0,
    },
    dae_signature_plan_metadata_effects(2),
  ).unwrap()
  let application = dae_apply_rewrite_plan(input, graph, plan)
  assert_false(application.applied)
  assert_eq(application.reason, DaeValidationRollback)
  assert_true(physical_equal(application.result.mod_out, input))
}
