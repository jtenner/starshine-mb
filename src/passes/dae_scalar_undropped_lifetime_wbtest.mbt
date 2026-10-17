///| The middle target has a live dynamic argument and writes a global.

///|
/// Its callers distinguish exact all-dropped eligibility from mixed use.
fn dae_scalar_undropped_fixture(dropped : Int32) -> @lib.Module {
  let touch = if dropped < 0 {
    "(func (export \"touch\") (param i32) local.get 0 call $between)"
  } else if dropped == 2 {
    "(func (export \"touch\") (param i32) local.get 0 call $between drop)"
  } else {
    "(func (export \"touch\") (param i32) (result i32) local.get 0 call $between)"
  }
  let second = if dropped > 0 {
    "(func (export \"drop\") (param i32) local.get 0 call $between drop)"
  } else {
    "(func (result i32) i32.const 13)"
  }
  let between = if dropped < 0 {
    "(func $between (param i32) local.get 0 global.set $seen) "
  } else {
    "(func $between (param i32) (result i32) local.get 0 global.set $seen local.get 0) "
  }
  pass_test_module_from_wat(
    "(module (global $seen (mut i32) (i32.const 0)) " +
    "(func $a (param i32) (result i32) local.get 0 i32.const 1 i32.add) " +
    "(func (export \"a\") (result i32) i32.const 7 call $a) " +
    between +
    "(func $b (param i32) (result i32) local.get 0 i32.const 2 i32.add) " +
    "(func (export \"b\") (result i32) i32.const 9 call $b) " +
    touch +
    second +
    ")",
  )
}

///|
fn dae_scalar_undropped_check(
  input : @lib.Module,
  options : HotPipelineOptions,
  work : DaeScalarValidationWork,
) -> DaeCoreRunResult raise {
  let saved = @binary.encode_module(input).unwrap()
  let expected = dae_run_core(input, HotPipelineOptions::new().trace)
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
  assert_eq(dae_wb_param_count(actual.mod_out, 2), 1)
  assert_true(actual.effects.parameter_changed[0])
  assert_true(actual.effects.parameter_changed[3])
  @validate.validate_module(actual.mod_out).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  actual
}

///|
test "scalar proof survives a called dynamic undropped result target" {
  let input = dae_scalar_undropped_fixture(0)
  let facts = dae_current_boundary_graph_new(input).snapshot.call_facts
  assert_eq(facts.direct_calls[2], 1)
  assert_eq(facts.dropped_calls[2], 0)
  let work = DaeScalarValidationWork::new()
  let actual = dae_scalar_undropped_check(
    input,
    HotPipelineOptions::new(),
    work,
  )
  assert_eq(actual.mod_out.code_sec.unwrap().0[2], input.code_sec.unwrap().0[2])
  assert_eq(actual.mod_out.code_sec.unwrap().0[5], input.code_sec.unwrap().0[5])
  assert_false(actual.effects.result_changed[2])
  assert_eq(work.full_gates, 1)
  assert_eq(work.partial_gates, 1)
  assert_eq(work.full_bodies, 7)
  assert_eq(work.partial_bodies, 2)
}

///|
test "scalar proof survives mixed dropped and undropped dynamic calls" {
  let input = dae_scalar_undropped_fixture(1)
  let facts = dae_current_boundary_graph_new(input).snapshot.call_facts
  assert_eq(facts.direct_calls[2], 2)
  assert_eq(facts.dropped_calls[2], 1)
  let work = DaeScalarValidationWork::new()
  let actual = dae_scalar_undropped_check(
    input,
    HotPipelineOptions::new(),
    work,
  )
  assert_eq(actual.mod_out.code_sec.unwrap().0[2], input.code_sec.unwrap().0[2])
  assert_false(actual.effects.result_changed[2])
  assert_eq(work.full_gates, 1)
  assert_eq(work.partial_gates, 1)
}

///|
test "all dropped dynamic calls retain productive result removal and its barrier" {
  let input = dae_scalar_undropped_fixture(2)
  let facts = dae_current_boundary_graph_new(input).snapshot.call_facts
  assert_eq(facts.direct_calls[2], 2)
  assert_eq(facts.dropped_calls[2], 2)
  let work = DaeScalarValidationWork::new()
  let actual = dae_scalar_undropped_check(
    input,
    HotPipelineOptions::new(),
    work,
  )
  assert_true(actual.effects.result_changed[2])
  assert_true(actual.effects.result_removed[2])
  let @lib.Func(_, @lib.Expr(body)) = actual.mod_out.code_sec.unwrap().0[2]
  assert_true(
    body.contains(@lib.Instruction::global_set(@lib.GlobalIdx::new(0U))),
  )
  let @lib.FuncType(_, results) = dae_resolve_func_type(
    actual.mod_out,
    actual.mod_out.func_sec.unwrap().0,
    2,
  ).unwrap()
  assert_eq(results.length(), 0)
  // A productive non-scalar write still ends the proof before the second scalar.
  assert_eq(work.full_gates, 2)
  assert_eq(work.partial_gates, 0)
}

///|
test "undropped boundary keeps user trace and perf on complete validation" {
  let input = dae_scalar_undropped_fixture(0)
  let expected_lines : Array[String] = []
  let _ = dae_run_core(input, fn(line) { expected_lines.push(line) })
  assert_false(expected_lines.is_empty())
  let actual_lines : Array[String] = []
  for
    options in [
      HotPipelineOptions::new(
        trace=Some(fn(line : String) { actual_lines.push(line) }),
      ),
      HotPipelineOptions::new(perf=Some(HotPerfSession::new())),
    ] {
    let work = DaeScalarValidationWork::new()
    let actual = dae_scalar_undropped_check(input, options, work)
    assert_false(actual.effects.result_changed[2])
    if options.perf is None {
      assert_eq(actual_lines, expected_lines)
    }
    assert_eq(work.full_gates, 2)
    assert_eq(work.partial_gates, 0)
  }
}

///|
test "scalar proof survives a called dynamic void target with no dropped calls" {
  let input = dae_scalar_undropped_fixture(-1)
  let facts = dae_current_boundary_graph_new(input).snapshot.call_facts
  assert_eq(facts.direct_calls[2], 1)
  assert_eq(facts.dropped_calls[2], 0)
  let work = DaeScalarValidationWork::new()
  let actual = dae_scalar_undropped_check(
    input,
    HotPipelineOptions::new(),
    work,
  )
  assert_eq(actual.mod_out.code_sec.unwrap().0[2], input.code_sec.unwrap().0[2])
  assert_false(actual.effects.result_changed[2])
  assert_eq(work.full_gates, 1)
  assert_eq(work.partial_gates, 1)
}

///|
test "undropped boundary preserves invalid sibling and earlier section errors" {
  let base = dae_scalar_undropped_fixture(0)
  for duplicate_export in [false, true] {
    let funcs = base.code_sec.unwrap().0.copy()
    funcs[6] = @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(99U))]),
    )
    let with_invalid_body = base.with_code_sec(@lib.CodeSec::new(funcs))
    let input = if duplicate_export {
      let exports = base.export_sec.unwrap().0
      with_invalid_body.with_export_sec(
        @lib.ExportSec::new([exports[0], exports[0]]),
      )
    } else {
      with_invalid_body
    }
    let saved = @binary.encode_module(input).unwrap()
    let expected_error = @validate.validate_module(input).unwrap_err()
    let expected = dae_run_core(input, HotPipelineOptions::new().trace)
    let options = HotPipelineOptions::new()
    let work = DaeScalarValidationWork::new()
    let actual = dae_run_core(
      input,
      options.trace,
      no_callback_trace=hot_pipeline_dae_no_callback_trace(options),
      scalar_validation_work=Some(work),
    )
    assert_false(actual.changed)
    assert_eq(actual.changed, expected.changed)
    assert_eq(actual.touched, expected.touched)
    assert_eq(actual.effects, expected.effects)
    assert_eq(
      @binary.encode_module(actual.mod_out).unwrap(),
      @binary.encode_module(expected.mod_out).unwrap(),
    )
    assert_eq(
      @validate.validate_module(actual.mod_out).unwrap_err(),
      expected_error,
    )
    if duplicate_export {
      assert_true(
        @validate.validation_error_message(expected_error).contains(
          "duplicate export name",
        ),
      )
    } else {
      assert_eq(
        @validate.validation_error_func_idx(expected_error),
        Some(@lib.FuncIdx::new(6U)),
      )
    }
    assert_eq(@binary.encode_module(input).unwrap(), saved)
    assert_eq(work.partial_gates, 0)
  }
}
