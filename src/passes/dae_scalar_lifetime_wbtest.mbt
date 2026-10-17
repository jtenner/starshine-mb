///| A called private helper keeps the intervening zero-result boundary in

///|
/// the normal core scan, rather than the unrelated zero-call cleanup branch.
fn dae_scalar_lifetime_fixture(with_result : Bool) -> @lib.Module {
  let between = if with_result {
    "(func $between (result i32) i32.const 11)"
  } else {
    "(func $between)"
  }
  let touch = if with_result {
    "(func (export \"touch\") (result i32) call $between)"
  } else {
    "(func (export \"touch\") call $between)"
  }
  pass_test_module_from_wat(
    "(module " +
    "(func $a (param i32) (result i32) local.get 0 i32.const 1 i32.add) " +
    "(func (export \"a\") (result i32) i32.const 7 call $a) " +
    between +
    "(func $b (param i32) (result i32) local.get 0 i32.const 2 i32.add) " +
    "(func (export \"b\") (result i32) i32.const 9 call $b) " +
    touch +
    "(func (result i32) i32.const 13))",
  )
}

///|
fn dae_scalar_lifetime_check_behavior(
  input : @lib.Module,
  options : HotPipelineOptions,
  work : DaeScalarValidationWork,
) -> Unit raise {
  let saved = @binary.encode_module(input).unwrap()
  let reference = HotPipelineOptions::new()
  let expected = dae_run_core(input, reference.trace)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  let actual = dae_run_core(
    input,
    options.trace,
    perf=options.perf,
    no_callback_trace=hot_pipeline_dae_no_callback_trace(options),
    scalar_validation_work=Some(work),
  )
  assert_true(actual.changed)
  assert_eq(actual.changed, expected.changed)
  assert_eq(actual.touched, expected.touched)
  assert_eq(actual.effects, expected.effects)
  assert_eq(
    @binary.encode_module(actual.mod_out).unwrap(),
    @binary.encode_module(expected.mod_out).unwrap(),
  )
  assert_eq(dae_wb_param_count(actual.mod_out, 0), 0)
  assert_eq(dae_wb_param_count(actual.mod_out, 3), 0)
  assert_true(actual.effects.parameter_changed[0])
  assert_true(actual.effects.parameter_changed[3])
  assert_eq(actual.mod_out.code_sec.unwrap().0[2], input.code_sec.unwrap().0[2])
  assert_eq(actual.mod_out.code_sec.unwrap().0[5], input.code_sec.unwrap().0[5])
  @validate.validate_module(actual.mod_out).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "scalar source proof survives a called void boundary with no removable result" {
  let input = dae_scalar_lifetime_fixture(false)
  let work = DaeScalarValidationWork::new()
  dae_scalar_lifetime_check_behavior(input, HotPipelineOptions::new(), work)
  // The intervening helper has zero results. The selected dropped-result
  // producer cannot write a candidate for it and must not end this lifetime.
  assert_eq(work.full_gates, 1)
  assert_eq(work.partial_gates, 1)
  assert_eq(work.full_bodies, 7)
  assert_eq(work.partial_bodies, 2)
}

///|
test "scalar source proof still ends before an unaudited positive result boundary" {
  let input = dae_scalar_lifetime_fixture(true)
  let work = DaeScalarValidationWork::new()
  dae_scalar_lifetime_check_behavior(input, HotPipelineOptions::new(), work)
  // This result-bearing producer remains outside the audited scalar path.
  assert_eq(work.full_gates, 2)
  assert_eq(work.partial_gates, 0)
}

///|
test "scalar void boundary lifetime keeps callback and perf complete gate fallback" {
  let input = dae_scalar_lifetime_fixture(false)
  for
    options in [
      HotPipelineOptions::new(trace=Some(fn(_ : String) { () })),
      HotPipelineOptions::new(perf=Some(HotPerfSession::new())),
    ] {
    let work = DaeScalarValidationWork::new()
    dae_scalar_lifetime_check_behavior(input, options, work)
    assert_eq(work.full_gates, 2)
    assert_eq(work.partial_gates, 0)
  }
}
