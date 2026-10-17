///| Both private result targets keep their dynamic argument and global write.

///|
/// The exported caller supplies a reused (i32)->() type when requested.
fn dae_numeric_result_validation_fixture(
  mixed~ : Bool = false,
  reused~ : Bool = true,
) -> @lib.Module {
  let ending = if reused { "" } else { " i32.const 9" }
  let result = if reused { "" } else { " (result i32)" }
  let extra = if mixed {
    "(func (export \"keep\") (param i32) (result i32) local.get 0 call $b)"
  } else {
    ""
  }
  pass_test_module_from_wat(
    "(module (global $seen (mut i32) (i32.const 0)) " +
    "(func $a (param i32) (result i32) local.get 0 global.set $seen local.get 0) " +
    "(func $b (param i32) (result i32) local.get 0 i32.const 1 i32.add global.set $seen local.get 0) " +
    "(func (export \"run\") (param i32)" +
    result +
    " local.get 0 call $a drop local.get 0 call $b drop" +
    ending +
    ") " +
    "(func (result i32) i32.const 31) " +
    extra +
    ")",
  )
}

///| Compare the actual main core with the unchanged complete-gate route.

///|
/// No resource assertion occurs before all behavior and ownership checks.
fn dae_numeric_result_validation_compare(
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
    numeric_result_validation_work=Some(work),
  )
  assert_eq(actual.changed, expected.changed)
  assert_eq(actual.touched, expected.touched)
  assert_eq(actual.effects, expected.effects)
  assert_eq(
    @binary.encode_module(actual.mod_out).unwrap(),
    @binary.encode_module(expected.mod_out).unwrap(),
  )
  assert_eq(
    @validate.validate_module(actual.mod_out),
    @validate.validate_module(expected.mod_out),
  )
  for target in [0, 1] {
    assert_eq(
      dae_wb_param_count(actual.mod_out, target),
      dae_wb_param_count(input, target),
    )
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  actual
}

///|
fn dae_numeric_result_validation_results(
  module_ : @lib.Module,
  target : Int32,
) -> Int32 {
  let @lib.FuncType(_, results) = dae_resolve_func_type(
    module_,
    dae_collect_func_type_indices(module_),
    target,
  ).unwrap()
  results.length()
}

///|
test "numeric result validation reuses one checked source across two real main core removals" {
  let input = dae_numeric_result_validation_fixture()
  @validate.validate_module(input).unwrap()
  let facts = dae_current_boundary_graph_new(input).snapshot.call_facts
  for target in [0, 1] {
    assert_eq(facts.direct_calls[target], 1)
    assert_eq(facts.dropped_calls[target], 1)
  }
  assert_true(
    dae_find_equivalent_simple_func_type(
      input.type_sec.unwrap(),
      [@lib.ValType::i32()],
      [],
    )
    is Some(_),
  )
  let work = DaeScalarValidationWork::new()
  let actual = dae_numeric_result_validation_compare(
    input,
    HotPipelineOptions::new(),
    work,
  )
  assert_true(actual.changed)
  for target in [0, 1] {
    assert_eq(dae_numeric_result_validation_results(actual.mod_out, target), 0)
    assert_true(actual.effects.result_removed[target])
    assert_true(actual.effects.result_changed[target])
    assert_true(actual.effects.structurally_touched[target])
    let @lib.Func(_, @lib.Expr(body)) = actual.mod_out.code_sec.unwrap().0[target]
    assert_true(
      body.contains(@lib.Instruction::global_set(@lib.GlobalIdx::new(0U))),
    )
  }
  // Core keeps the last committed transaction's touched mask. Cumulative
  // target coverage is in effects, checked above, rather than this mask.
  assert_eq(actual.touched, [false, true, true, false])
  @validate.validate_module(actual.mod_out).unwrap()
  // The baseline must fail here on actual complete body-check work, not on a
  // missing token or a changed output. Expected baseline: 2 full / 8 bodies.
  assert_eq(work.full_gates, 1)
  assert_eq(work.full_bodies, 4)
  assert_eq(work.partial_gates, 1)
  assert_eq(work.partial_bodies, 2)
}

///|
test "numeric result validation intentionally keeps a mixed result target unchanged" {
  let input = dae_numeric_result_validation_fixture(mixed=true)
  let facts = dae_current_boundary_graph_new(input).snapshot.call_facts
  assert_eq(facts.direct_calls[1], 2)
  assert_eq(facts.dropped_calls[1], 1)
  let work = DaeScalarValidationWork::new()
  let actual = dae_numeric_result_validation_compare(
    input,
    HotPipelineOptions::new(),
    work,
  )
  assert_true(actual.changed)
  assert_eq(dae_numeric_result_validation_results(actual.mod_out, 0), 0)
  assert_eq(dae_numeric_result_validation_results(actual.mod_out, 1), 1)
  assert_true(actual.effects.result_removed[0])
  assert_false(actual.effects.result_removed[1])
  assert_eq(actual.mod_out.code_sec.unwrap().0[1], input.code_sec.unwrap().0[1])
  @validate.validate_module(actual.mod_out).unwrap()
  assert_eq(work.full_gates, 1)
  assert_eq(work.partial_gates, 0)
}

///|
test "numeric result validation keeps exact user trace and perf on complete gates" {
  let input = dae_numeric_result_validation_fixture()
  let expected_trace : Array[String] = []
  let _ = dae_run_core(input, fn(line) { expected_trace.push(line) })
  assert_false(expected_trace.is_empty())
  let actual_trace : Array[String] = []
  for
    options in [
      HotPipelineOptions::new(
        trace=Some(fn(line : String) { actual_trace.push(line) }),
      ),
      HotPipelineOptions::new(perf=Some(HotPerfSession::new())),
    ] {
    let work = DaeScalarValidationWork::new()
    let actual = dae_numeric_result_validation_compare(input, options, work)
    assert_true(actual.changed)
    assert_true(actual.effects.result_removed[0])
    assert_true(actual.effects.result_removed[1])
    @validate.validate_module(actual.mod_out).unwrap()
    if options.perf is None {
      assert_eq(actual_trace, expected_trace)
    }
    assert_eq(work.full_gates, 2)
    assert_eq(work.partial_gates, 0)
  }
}

///|
test "numeric result validation preserves invalid untouched sibling and section error priority" {
  let base = dae_numeric_result_validation_fixture()
  for earlier_export_error in [false, true] {
    let funcs = base.code_sec.unwrap().0.copy()
    funcs[3] = @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(99U))]),
    )
    let bad_body = base.with_code_sec(@lib.CodeSec::new(funcs))
    let input = if earlier_export_error {
      let exports = base.export_sec.unwrap().0
      bad_body.with_export_sec(@lib.ExportSec::new([exports[0], exports[0]]))
    } else {
      bad_body
    }
    let error = @validate.validate_module(input).unwrap_err()
    let work = DaeScalarValidationWork::new()
    let actual = dae_numeric_result_validation_compare(
      input,
      HotPipelineOptions::new(),
      work,
    )
    assert_false(actual.changed)
    assert_eq(@validate.validate_module(actual.mod_out).unwrap_err(), error)
    if earlier_export_error {
      assert_true(
        @validate.validation_error_message(error).contains(
          "duplicate export name",
        ),
      )
    } else {
      assert_eq(
        @validate.validation_error_func_idx(error),
        Some(@lib.FuncIdx::new(3U)),
      )
    }
    assert_eq(work.partial_gates, 0)
    assert_true(work.full_errors > 0)
  }
}

///|
test "numeric result validation retains invalid removable name repair through a full gate" {
  let input = dae_numeric_result_validation_fixture().with_name_sec(
    @lib.NameSec::new(
      func_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(99U, @lib.Name::new("invalid-index")),
        ]),
      ),
    ),
  )
  let work = DaeScalarValidationWork::new()
  let actual = dae_numeric_result_validation_compare(
    input,
    HotPipelineOptions::new(),
    work,
  )
  assert_true(actual.changed)
  assert_true(actual.effects.result_removed[0])
  assert_true(actual.effects.result_removed[1])
  assert_true(actual.mod_out.name_sec is None)
  assert_true(input.name_sec is Some(_))
  @validate.validate_module(actual.mod_out).unwrap()
  assert_true(work.full_gates >= 1)
}

///|
test "numeric result validation intentionally falls back for an appended void signature" {
  let input = dae_numeric_result_validation_fixture(reused=false)
  assert_true(
    dae_find_equivalent_simple_func_type(
      input.type_sec.unwrap(),
      [@lib.ValType::i32()],
      [],
    )
    is None,
  )
  let work = DaeScalarValidationWork::new()
  let actual = dae_numeric_result_validation_compare(
    input,
    HotPipelineOptions::new(),
    work,
  )
  assert_true(actual.changed)
  assert_true(actual.effects.result_removed[0])
  assert_true(actual.effects.result_removed[1])
  @validate.validate_module(actual.mod_out).unwrap()
  // The first source has no reusable void signature; its unsupported full gate
  // does not mint a source for the following otherwise eligible transaction.
  assert_eq(work.full_gates, 2)
  assert_eq(work.partial_gates, 0)
}

///|
test "numeric result validation intentionally falls back for a replaced unique type" {
  let input = pass_test_module_from_wat(
    (
      #|(module (global $seen (mut i32) (i32.const 0))
      #| (func $a (param i32) (result i32)
      #|  local.get 0 global.set $seen local.get 0)
      #| (func $b (param i32 i32) (result i32)
      #|  local.get 0 local.get 1 i32.add global.set $seen local.get 1)
      #| (func (export "run") (param i32 i32) (result i32)
      #|  local.get 0 call $a drop local.get 0 local.get 1 call $b drop i32.const 9)
      #| (func (result i32) i32.const 31))
    ),
  )
  let types = input.func_sec.unwrap().0
  assert_false(types[0] == types[1])
  assert_false(types[0] == types[2])
  assert_false(types[0] == types[3])
  assert_true(
    dae_find_equivalent_simple_func_type(
      input.type_sec.unwrap(),
      [@lib.ValType::i32()],
      [],
    )
    is None,
  )
  let work = DaeScalarValidationWork::new()
  let actual = dae_numeric_result_validation_compare(
    input,
    HotPipelineOptions::new(),
    work,
  )
  assert_true(actual.changed)
  assert_true(actual.effects.result_removed[0])
  assert_true(actual.effects.result_removed[1])
  @validate.validate_module(actual.mod_out).unwrap()
  assert_eq(work.full_gates, 2)
  assert_eq(work.partial_gates, 0)
}

///| This scalar producer has a real inner full gate and a post-trace outer

///| transaction gate. Result producers commit before the batch trace event;

///|
/// that event cannot test rollback of an already committed result removal.
fn dae_numeric_result_validation_hostile_trace(
  input : @lib.Module,
  work : DaeScalarValidationWork?,
) -> (DaeCoreRunResult, Bool) {
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[1]
  let mutated = [false]
  let options = HotPipelineOptions::new(
    trace=Some(fn(line : String) {
      if !mutated[0] && line.contains("core-worklist-batch start=0") {
        body[0] = @lib.Instruction::i64_const(@lib.I64(5L))
        mutated[0] = true
      }
    }),
  )
  let result = dae_run_core(
    input,
    options.trace,
    no_callback_trace=hot_pipeline_dae_no_callback_trace(options),
    numeric_result_validation_work=work,
  )
  (result, mutated[0])
}

///|
test "numeric recorder preserves the scalar post trace outer rollback guard" {
  // A clean run must first demonstrate that this exact constructor transforms.
  let clean_input = dae_core_trace_handoff_fixture()
  let clean_saved = @binary.encode_module(clean_input).unwrap()
  let clean_work = DaeScalarValidationWork::new()
  let clean_options = HotPipelineOptions::new(trace=Some(fn(_ : String) { () }))
  let clean = dae_run_core(
    clean_input,
    clean_options.trace,
    no_callback_trace=hot_pipeline_dae_no_callback_trace(clean_options),
    numeric_result_validation_work=Some(clean_work),
  )
  assert_true(clean.changed)
  assert_eq(dae_wb_param_count(clean.mod_out, 2), 0)
  assert_eq(dae_numeric_result_validation_results(clean.mod_out, 2), 1)
  assert_true(clean.effects.parameter_changed[2])
  @validate.validate_module(clean.mod_out).unwrap()
  assert_eq(@binary.encode_module(clean_input).unwrap(), clean_saved)
  let expected_input = dae_core_trace_handoff_fixture()
  let (expected, expected_mutation) = dae_numeric_result_validation_hostile_trace(
    expected_input,
    None,
  )
  let input = dae_core_trace_handoff_fixture()
  let work = DaeScalarValidationWork::new()
  let (actual, actual_mutation) = dae_numeric_result_validation_hostile_trace(
    input,
    Some(work),
  )
  assert_true(expected_mutation)
  assert_true(actual_mutation)
  assert_false(actual.changed)
  assert_eq(actual.changed, expected.changed)
  assert_eq(actual.effects, expected.effects)
  assert_eq(actual.touched, expected.touched)
  assert_eq(
    @binary.encode_module(actual.mod_out).unwrap(),
    @binary.encode_module(expected.mod_out).unwrap(),
  )
  assert_eq(
    @validate.validate_module(actual.mod_out).unwrap_err(),
    @validate.validate_module(expected.mod_out).unwrap_err(),
  )
  assert_eq(dae_wb_param_count(actual.mod_out, 2), 1)
  assert_eq(dae_numeric_result_validation_results(actual.mod_out, 2), 1)
  assert_eq(actual.mod_out.func_sec, input.func_sec)
  assert_eq(actual.mod_out.code_sec, input.code_sec)
  assert_eq(actual.diagnostics.candidates_applied, 0)
  assert_eq(actual.effects.candidates_applied, 0)
  // This is an outer scalar-gate regression control. Numeric callback/perf
  // offers are exercised separately by the dedicated full-gate test.
  assert_eq(clean_work.offered, 0)
  assert_eq(work.offered, 0)
  assert_eq(work.partial_gates, 0)
}
