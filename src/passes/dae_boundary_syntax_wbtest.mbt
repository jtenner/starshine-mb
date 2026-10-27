///|
fn dae_boundary_syntax_fixture(prefix : Int32) -> @lib.Module {
  let wat = StringBuilder()
  wat.write_string(
    "(module (func $a (param i32) (result i32) local.get 0) (func $b (param i64) (result i64) local.get 0) (func (export \"run\") (result i64) ",
  )
  for _ in 0..<prefix {
    wat.write_string("nop ")
  }
  wat.write_string("i32.const 7 call $a drop i64.const 9 call $b))")
  pass_test_module_from_wat(wat.to_string()).with_custom_secs([
    @lib.CustomSec::new(@lib.Name::new("boundary.syntax.keep"), b"untouched"),
  ])
}

///|
fn dae_boundary_syntax_compare_core(
  input : @lib.Module,
  optimize : Bool,
) -> Unit raise {
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let initial = dae_collect_original_boundary_snapshot(input)
  let frozen_initial = dae_boundary_syntax_frozen_collect_original_boundary_snapshot(
    input,
  )
  dae_boundary_syntax_assert_snapshot(initial, frozen_initial)
  let actual_trace : Array[String] = []
  let expected_trace : Array[String] = []
  let actual = dae_run_core(
    input,
    fn(line) { actual_trace.push(line) },
    optimize~,
  )
  let expected = dae_boundary_syntax_frozen_run_core(
    input,
    fn(line) { expected_trace.push(line) },
    optimize~,
  )
  assert_true(actual.changed)
  assert_true(actual.effects.candidates_applied > 0)
  assert_eq(actual.primary_def, expected.primary_def)
  assert_eq(
    actual.single_caller_throttle_consumed,
    expected.single_caller_throttle_consumed,
  )
  assert_eq(actual.touched, expected.touched)
  assert_eq(actual.effects, expected.effects)
  assert_eq(actual_trace, expected_trace)
  assert_eq(
    @binary.encode_module(actual.mod_out).unwrap(),
    @binary.encode_module(expected.mod_out).unwrap(),
  )
  @validate.validate_module(actual.mod_out).unwrap()
  @validate.validate_module(expected.mod_out).unwrap()
  assert_eq(actual.mod_out.custom_secs, input.custom_secs)
  for target in [0, 1] {
    let indices = dae_collect_func_type_indices(actual.mod_out)
    match dae_resolve_func_type(actual.mod_out, indices, target) {
      Some(@lib.FuncType(params, _)) => assert_eq(params.length(), 0)
      None => fail("productive target signature missing")
    }
    assert_true(actual.effects.parameter_changed[target])
  }
  let after = dae_collect_original_boundary_snapshot(actual.mod_out)
  dae_boundary_syntax_assert_snapshot(
    after,
    dae_boundary_syntax_frozen_collect_original_boundary_snapshot(
      actual.mod_out,
    ),
  )
  assert_eq(initial.param_counts[0], 1)
  assert_eq(after.param_counts[0], 0)
  // A retained original snapshot is not a cache for the next source phase.
  dae_boundary_syntax_assert_snapshot(initial, frozen_initial)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE snapshot syntax keeps all fields and productive plain and optimizing core behavior" {
  for optimize in [false, true] {
    dae_boundary_syntax_compare_core(dae_boundary_syntax_fixture(24), optimize)
  }
}

///|
test "DAE snapshot syntax matches every field for roots nesting calls and literal bits" {
  for
    source in [
      "(module (import \"m\" \"f\" (func $imp (result i32))) (func $self (result i32) unreachable call $self) (func $other (result i32) unreachable call $self drop call $imp) (func (export \"run\") (result i32) call $other))",
      "(module (func $self (param i32) (result i32) unreachable local.get 0 call $self drop i32.const 0) (func $earlier (result i32) unreachable i32.const 7 call $self) (func (export \"run\") (result i32) call $earlier))",
      "(module (func $a (result i32) unreachable call $b) (func $b (result i32) unreachable call $a drop i32.const 0) (func (export \"run\") (result i32) call $a))",
      "(module (func $leaf (result i32) i32.const 7) (func (export \"run\") (result i32) nop block unreachable end block (result i32) call $leaf end drop call $leaf))",
      "(module (func $leaf (result i32) i32.const 7) (func (export \"run\") (result i32) i32.const 1 if (result i32) unreachable call $leaf else loop (result i32) unreachable call $leaf end end))",
      "(module (func $a (param i32) (result i32) local.get 0 return_call $a) (func (export \"run\") (result i32) i32.const 7 return_call $a))",
      "(module (func (export \"run\") (result f64) f64.const -0 drop f64.const nan:0x1234) (func (result f32) f32.const -0 drop f32.const nan:0x4321))",
      "(module (tag $t) (func $a (result i32) unreachable i32.const 7) (func (export \"run\") (result i32) (try (result i32) (do call $a) (catch $t unreachable call $a))))",
      "(module (func (export \"run\") nop unreachable))",
    ] {
    let input = pass_test_module_from_wat(source)
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    dae_boundary_syntax_assert_snapshot(
      dae_collect_original_boundary_snapshot(input),
      dae_boundary_syntax_frozen_collect_original_boundary_snapshot(input),
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "DAE snapshot syntax reconstructs later sources after a hostile trace alias edit" {
  let source = "(module (func $a (param i32) (result i32) local.get 0) (func $b (param i64) (result i64) local.get 0) (func (export \"side\") (result i32) i32.const 5 drop i32.const 11 call $a) (func (export \"run\") (result i64) i32.const 7 call $a drop i64.const 9 call $b))"
  for optimize in [false, true] {
    let actual_input = pass_test_module_from_wat(source)
    let expected_input = pass_test_module_from_wat(source)
    let retained = dae_collect_original_boundary_snapshot(actual_input)
    let retained_reference = dae_boundary_syntax_frozen_collect_original_boundary_snapshot(
      expected_input,
    )
    let @lib.Func(_, @lib.Expr(actual_body)) = actual_input.code_sec.unwrap().0[2]
    let @lib.Func(_, @lib.Expr(expected_body)) = expected_input.code_sec.unwrap().0[2]
    let actual_mutated = [false]
    let expected_mutated = [false]
    let actual_trace : Array[String] = []
    let expected_trace : Array[String] = []
    let actual = dae_run_core(
      actual_input,
      fn(line) {
        actual_trace.push(line)
        if !actual_mutated[0] && line.contains("core-worklist-batch start=0") {
          actual_body[0] = @lib.Instruction::unreachable_()
          actual_mutated[0] = true
        }
      },
      optimize~,
    )
    let expected = dae_boundary_syntax_frozen_run_core(
      expected_input,
      fn(line) {
        expected_trace.push(line)
        if !expected_mutated[0] && line.contains("core-worklist-batch start=0") {
          expected_body[0] = @lib.Instruction::unreachable_()
          expected_mutated[0] = true
        }
      },
      optimize~,
    )
    assert_true(actual_mutated[0])
    assert_true(expected_mutated[0])
    assert_true(actual.changed)
    assert_eq(actual_trace, expected_trace)
    assert_eq(actual.effects, expected.effects)
    assert_eq(actual.touched, expected.touched)
    assert_eq(
      @binary.encode_module(actual.mod_out).unwrap(),
      @binary.encode_module(expected.mod_out).unwrap(),
    )
    @validate.validate_module(actual.mod_out).unwrap()
    @validate.validate_module(expected.mod_out).unwrap()
    let later = dae_collect_original_boundary_snapshot(actual_input)
    dae_boundary_syntax_assert_snapshot(
      later,
      dae_boundary_syntax_frozen_collect_original_boundary_snapshot(
        expected_input,
      ),
    )
    assert_true(
      later.escaped_dead_suffix_call_counts[0] >
      retained.escaped_dead_suffix_call_counts[0],
    )
    dae_boundary_syntax_assert_snapshot(retained, retained_reference)
    // The callback's one explicit mutation is part of this adversarial input.
    // Neither pass may add any other aliased edit to the two source modules.
    assert_eq(
      @binary.encode_module(actual_input).unwrap(),
      @binary.encode_module(expected_input).unwrap(),
    )
  }
}

///|
test "DAE snapshot syntax retains intentionally invalid type-index boundary facts" {
  let input = dae_boundary_syntax_fixture(0).with_func_sec(
    @lib.FuncSec::new([
      @lib.TypeIdx::new(999U),
      @lib.TypeIdx::new(999U),
      @lib.TypeIdx::new(999U),
    ]),
  )
  assert_true(@validate.validate_module(input) is Err(_))
  let saved = @binary.encode_module(input).unwrap()
  dae_boundary_syntax_assert_snapshot(
    dae_collect_original_boundary_snapshot(input),
    dae_boundary_syntax_frozen_collect_original_boundary_snapshot(input),
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
/// Dedicated Callgrind window: no production recorder and no per-node branch.
/// The wrapper must remain a real native symbol; the runner checks this.
fn dae_boundary_syntax_profile_once(
  input : @lib.Module,
  expected : DaeOriginalBoundarySnapshot,
) -> Unit raise {
  let actual = dae_collect_original_boundary_snapshot(input)
  dae_boundary_syntax_assert_snapshot(actual, expected)
}

///|
#skip("dedicated native work RED: run the bounded Callgrind wrapper after behavior checks")
test "profile DAE snapshot syntax required single invocation work" {
  let input = dae_boundary_syntax_fixture(48)
  let saved = @binary.encode_module(input).unwrap()
  // The four bounded tests independently require productive plain/optimizing
  // transforms. Keep this process to one normal snapshot: Callgrind retains
  // earlier helper call counts even while instruction collection is off.
  let expected = dae_boundary_syntax_frozen_collect_original_boundary_snapshot(
    input,
  )
  dae_boundary_syntax_profile_once(input, expected)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  @validate.validate_module(input).unwrap()
}
