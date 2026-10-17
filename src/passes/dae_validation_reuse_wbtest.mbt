///|
// Exercise the same local report guard used by the uniform-value scheduler.
// The pre-change baseline adapter ran the full gate for every report.
fn dae_validation_reuse_test_apply(
  input : @lib.Module,
  graph : DaeCurrentBoundaryGraph,
  plan : DaeRewritePlan,
  checked : (@lib.Module, @lib.Module)?,
) -> DaeRewritePlanApplication {
  dae_apply_rewrite_plan(input, graph, plan, checked_candidate=checked)
}

///|
fn dae_validation_reuse_fixture(siblings : Int32) -> @lib.Module {
  let extra = StringBuilder::new()
  for index in 0..<siblings {
    extra.write_string(" (func (result i32) i32.const \{index})")
  }
  pass_test_module_from_wat(
    "(module (func $target (param i32) (result i32) local.get 0 i32.const 1 i32.add) " +
    "(func (export \"run\") (result i32) i32.const 7 call $target)\{extra.to_string()})",
  )
}

///|
fn dae_validation_reuse_round(
  input : @lib.Module,
  reference : Bool,
) -> (DaePassResult, DaeCommitEffects, Int32) {
  let original = dae_collect_original_boundary_snapshot(input)
  let graph = dae_current_boundary_graph_new(input)
  let dependencies = dae_boundary_dependency_graph_new(graph)
  let uniform_values = [Some(@lib.Instruction::i32_const(@lib.I32(7)))]
  let item = {
    ..dae_work_item_new(graph, dependencies, 0, DaeUniformActualWork),
    uniform_values,
  }
  let empty : DaePassResult = {
    mod_out: input,
    touched: [],
    changed: false,
    primary_def: -1,
  }
  if reference {
    // Frozen double-gate sequence. The default producer and apply calls must
    // continue to validate complete modules after the local fast path exists.
    let candidate = dae_try_rewrite_uniform_values_def_with_facts_once(
      input, original, graph, 0, uniform_values,
    )
    if !candidate.changed {
      return (empty, dae_commit_effects_empty(graph.snapshot.defined), 0)
    }
    let effects = dae_work_item_candidate_effects(input, graph, item, candidate)
    let plan = dae_build_signature_rewrite_plan_from_candidate(
      original, input, graph, 0, candidate, effects,
    ).unwrap()
    let applied = dae_apply_rewrite_plan(input, graph, plan)
    return (
      applied.result,
      applied.effects,
      if applied.applied {
        0
      } else {
        1
      },
    )
  }
  let diagnostics = dae_diagnostics_new()
  match
    dae_process_work_item(
      original,
      input,
      [],
      false,
      graph,
      dependencies,
      item,
      diagnostics,
    ) {
    DaeWorkCommitted(application) =>
      (
        {
          mod_out: application.mod_out,
          touched: application.touched,
          changed: application.changed,
          primary_def: application.primary_def,
        },
        application.effects,
        diagnostics.validation_rollbacks,
      )
    _ =>
      (
        empty,
        dae_commit_effects_empty(graph.snapshot.defined),
        diagnostics.validation_rollbacks,
      )
  }
}

///|
test "DAE validation reuse retains scalar output effects and source ownership" {
  let input = dae_validation_reuse_fixture(2)
  let saved = @binary.encode_module(input).unwrap()
  let (expected, expected_effects, expected_rollbacks) = dae_validation_reuse_round(
    input, true,
  )
  let (actual, effects, rollbacks) = dae_validation_reuse_round(input, false)
  assert_true(actual.changed)
  assert_eq(actual.touched, expected.touched)
  assert_eq(actual.primary_def, expected.primary_def)
  assert_eq(effects, expected_effects)
  assert_eq(rollbacks, expected_rollbacks)
  assert_eq(
    @binary.encode_module(actual.mod_out).unwrap(),
    @binary.encode_module(expected.mod_out).unwrap(),
  )
  assert_eq(dae_wb_param_count(actual.mod_out, 0), 0)
  @validate.validate_module(actual.mod_out).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE validation reuse retains invalid input rollback at the producer gate" {
  let valid = dae_validation_reuse_fixture(1)
  let funcs = valid.code_sec.unwrap().0.copy()
  funcs[2] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(99U))]),
  )
  let duplicate_export = valid.export_sec.unwrap().0.copy()
  duplicate_export.push(duplicate_export[0])
  // These inputs are intentionally invalid outside the rewritten target.
  // Neither a valid changed target nor a local validation report can hide them.
  for
    input in [
      valid.with_code_sec(@lib.CodeSec::new(funcs)),
      valid.with_export_sec(@lib.ExportSec::new(duplicate_export)),
      valid.with_start_sec(@lib.StartSec::new(@lib.FuncIdx::new(1U))),
      valid.with_custom_secs([@lib.CustomSec::new(@lib.Name::new("name"), b"")]),
      valid.with_custom_secs([
        @lib.CustomSec::new(@lib.Name::new("compiler.facts"), b""),
      ]),
    ] {
    assert_true(@validate.validate_module(input) is Err(_))
    let (expected, _, expected_rollbacks) = dae_validation_reuse_round(
      input, true,
    )
    let (actual, _, rollbacks) = dae_validation_reuse_round(input, false)
    assert_false(actual.changed)
    assert_false(expected.changed)
    assert_true(physical_equal(actual.mod_out, input))
    assert_eq(rollbacks, expected_rollbacks)
    assert_eq(rollbacks, 0)
  }
}

///|
test "DAE validation reuse preserves candidate repair of invalid removable names" {
  let input = dae_validation_reuse_fixture(0).with_name_sec(
    @lib.NameSec::new(
      func_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(99U, @lib.Name::new("invalid-index")),
        ]),
      ),
    ),
  )
  assert_true(@validate.validate_module(input) is Err(_))
  let (expected, expected_effects, _) = dae_validation_reuse_round(input, true)
  let (actual, effects, rollbacks) = dae_validation_reuse_round(input, false)
  assert_true(actual.changed && expected.changed)
  assert_eq(effects, expected_effects)
  assert_eq(rollbacks, 0)
  assert_eq(
    @binary.encode_module(actual.mod_out).unwrap(),
    @binary.encode_module(expected.mod_out).unwrap(),
  )
  @validate.validate_module(actual.mod_out).unwrap()
  assert_true(input.name_sec is Some(_))
  assert_true(actual.mod_out.name_sec is None)
}

///|
test "DAE validation reuse false source and different candidate reports retain the full gate" {
  let (input, _, graph, plan) = dae_scalar_rewrite_plan_fixture()
  let checked = dae_apply_rewrite_plan(input, graph, plan)
  assert_true(checked.applied)
  let invalid = dae_rewrite_plan_with_callee(
    plan,
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(99U))]),
    ),
  )
  for
    report in [
      None,
      Some((input, input)),
      Some((input, checked.result.mod_out)),
      Some(
        (
          input.with_start_sec(@lib.StartSec::new(@lib.FuncIdx::new(99U))),
          invalid.candidate,
        ),
      ),
    ] {
    let application = dae_validation_reuse_test_apply(
      input, graph, invalid, report,
    )
    assert_false(application.applied)
    assert_eq(application.reason, DaeValidationRollback)
    assert_true(physical_equal(application.result.mod_out, input))
  }
}

///|
test "DAE validation reuse keeps stale epoch rejection before any certificate" {
  let (input, _, graph, plan) = dae_scalar_rewrite_plan_fixture()
  let checked = dae_apply_rewrite_plan(input, graph, plan)
  assert_true(checked.applied)
  graph.module_epoch += 1
  let application = dae_validation_reuse_test_apply(
    input,
    graph,
    plan,
    Some((input, checked.result.mod_out)),
  )
  assert_false(application.applied)
  assert_eq(application.reason, DaeStaleCandidateFacts)
}

///|
test "DAE validation reuse rechecks reconstructed candidate after owned alias mutation" {
  let (input, _, graph, plan) = dae_scalar_rewrite_plan_fixture()
  let saved = @binary.encode_module(input).unwrap()
  let checked = dae_apply_rewrite_plan(input, graph, plan)
  assert_true(checked.applied)
  // This intentionally simulates an invalid producer-owned inactive cleanup
  // after the original gate. Reconstructed wrappers cannot reuse that gate.
  plan.effects.caller_drop_removed[1] = true
  plan.rewritten_funcs[2] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(99U))]),
  )
  assert_true(physical_equal(plan.candidate, checked.result.mod_out))
  let application = dae_validation_reuse_test_apply(
    input,
    graph,
    plan,
    Some((input, checked.result.mod_out)),
  )
  assert_false(application.applied)
  assert_eq(application.reason, DaeValidationRollback)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
