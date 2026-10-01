///|
test "handler-free legacy preparation avoids full environment and rewrite owners" {
  let input = dae2_handler_admission_fixture(2, false, true)
  let bytes = @binary.encode_module(input).unwrap()
  let counts = [0, 0, 0]
  let output = dae2_prepare_legacy_handlers(input, setup_counts=Some(counts)).unwrap()
  assert_true(physical_equal(output, input))
  assert_eq(@binary.encode_module(output).unwrap(), bytes)
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(dae2_legacy_setup_reference(input).unwrap()).unwrap(),
  )
  @validate.validate_module(output).unwrap()
  assert_eq(counts, [0, 0, 0])
}

///|
test "lazy legacy signature census retains ordered imported and grouped function facts" {
  let input = pass_test_module_from_wat(
    "(module (rec (type $box (struct (field i32))) (type $sig (func (param i32) (result i32)))) (import \"env\" \"f\" (func $f (type $sig))) (import \"env\" \"g\" (global i32)) (memory 1) (tag $t (param i32)) (func (param i32) (result i32) local.get 0 call $f) (func (result i32) (try (result i32) (do (throw $t (i32.const 42))) (catch $t) (catch_all (i32.const 0)))))",
  )
  let env = @validate.Env::new().with_module(input)
  assert_eq(
    dae2_legacy_signature_param_counts(input),
    env.funcs.map(fn(ft) { ft.0.length() }),
  )
  let counts = [0, 0, 0]
  let actual = dae2_prepare_legacy_handlers(input, setup_counts=Some(counts)).unwrap()
  let expected = dae2_legacy_setup_reference(input).unwrap()
  assert_eq(
    @binary.encode_module(actual).unwrap(),
    @binary.encode_module(expected).unwrap(),
  )
  @validate.validate_module(actual).unwrap()
  assert_eq(counts, [1, 1, 1])
}

///|
test "lazy legacy preparation retains invalid missing-signature failure" {
  // Intentionally invalid function type indices are omitted by Env::with_module;
  // preserve its existing lookup order and error rather than admitting a no-op.
  let input = dae2_handler_admission_fixture(2, false, true)
  let indices = input.func_sec.unwrap().0.copy()
  indices[0] = @lib.TypeIdx::new(999U)
  let invalid = input.with_func_sec(@lib.FuncSec::new(indices))
  assert_true(dae2_prepare_legacy_handlers(invalid).is_err())
  assert_eq(
    dae2_prepare_legacy_handlers(invalid),
    dae2_legacy_setup_reference(invalid),
  )
  assert_eq(
    dae2_legacy_signature_param_counts(invalid),
    @validate.Env::new().with_module(invalid).funcs.map(fn(ft) { ft.0.length() }),
  )
}

///|
test "lazy legacy signature census preserves last recursive group lookup" {
  // Manual RecIdx function declarations cannot be encoded as wasm; this is the
  // existing environment's private in-memory lookup boundary, not new support.
  let input = dae2_handler_admission_fixture(1, false, true)
  let input = input.with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::rec(0U)]))
  assert_eq(
    dae2_legacy_signature_param_counts(input),
    @validate.Env::new().with_module(input).funcs.map(fn(ft) { ft.0.length() }),
  )
  assert_eq(
    dae2_prepare_legacy_handlers(input),
    dae2_legacy_setup_reference(input),
  )
}

///|
test "lazy legacy setup canonicalizes both untouched grouped siblings" {
  let input = pass_test_module_from_wat(
    "(module (tag $t) (func (result i32) i32.const 1) (func (result i32) (try (result i32) (do (throw $t)) (catch $t (i32.const 9)) (catch_all (i32.const 10)))) (func (result i32) i32.const 2))",
  )
  let funcs = input.code_sec.unwrap().0.copy()
  for index in [0, 2] {
    let @lib.Func(_, body) = funcs[index]
    funcs[index] = @lib.Func::new(
      @lib.Locals::from_decl_runs_preserving_groups([
        @lib.LocalRun::new(0U, @lib.ValType::i64()),
        @lib.LocalRun::new(1U, @lib.ValType::i32()),
        @lib.LocalRun::new(1U, @lib.ValType::i32()),
      ]),
      body,
    )
  }
  let input = input.with_code_sec(@lib.CodeSec::new(funcs))
  let original = @binary.encode_module(input).unwrap()
  let output = dae2_prepare_legacy_handlers(input).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(dae2_legacy_setup_reference(input).unwrap()).unwrap(),
  )
  for index in [0, 2] {
    let @lib.Func(locals, body) = output.code_sec.unwrap().0[index]
    assert_eq(locals.runs(), [@lib.LocalRun::new(2U, @lib.ValType::i32())])
    let @lib.Func(_, original_body) = funcs[index]
    assert_true(physical_equal(body, original_body))
  }
  @validate.validate_module(output).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), original)
}
