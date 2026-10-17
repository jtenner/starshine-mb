///| The report is built from a real productive scalar transaction, not an

///|
/// issued token. It must still lose its source at the committed-report gate.
test "numeric result report boundary clears a real nonnumeric scalar source" {
  let input = dae_scalar_validation_test_input()
  let saved = @binary.encode_module(input).unwrap()
  let chain = dae_scalar_validation_test_chain()
  let work = DaeScalarValidationWork::new()
  let (graph, plan) = dae_scalar_validation_test_plan(input, 0, 1, 7)
  let expected = dae_apply_rewrite_plan(input, graph, plan)
  let actual = dae_apply_rewrite_plan(
    input,
    graph,
    plan,
    scalar_validation_chain=Some(chain),
    scalar_validation_work=Some(work),
  )
  dae_numeric_result_v2_application_equal(input, expected, actual, saved)
  assert_eq(dae_wb_param_count(actual.result.mod_out, 0), 0)
  assert_eq(dae_numeric_result_validation_results(actual.result.mod_out, 0), 1)
  assert_true(actual.effects.parameter_changed[0])
  assert_true(actual.effects.body_materialized[0])
  assert_true(actual.result.touched[0] && actual.result.touched[1])
  assert_eq(
    dae_work_family_for_commit_effects(actual.effects, 0),
    DaeUniformActualWork,
  )
  let report : DaeCoreResultApplication = {
    mod_out: actual.result.mod_out,
    touched: actual.result.touched,
    changed: actual.result.changed,
    applied: actual.applied,
    primary_def: actual.result.primary_def,
    effects: actual.effects,
  }
  dae_scalar_validation_retain_exact(Some(chain), actual.result.mod_out)
  assert_true(chain.checked_source is Some(_))
  let output_saved = @binary.encode_module(actual.result.mod_out).unwrap()
  dae_numeric_result_validation_retain_report(
    Some(chain),
    actual.result,
    report,
  )
  assert_true(chain.checked_source is None)
  assert_true(chain.syntax_index is None)
  assert_eq(@binary.encode_module(actual.result.mod_out).unwrap(), output_saved)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  @validate.validate_module(actual.result.mod_out).unwrap()
  assert_eq(work.full_gates, 1)
  assert_eq(work.full_bodies, input.code_sec.unwrap().0.length())
  assert_eq(work.partial_gates, 0)
}
