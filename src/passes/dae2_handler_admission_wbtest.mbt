///|
test "DAE2 throw folding preserves handler-free structured bodies by identity" {
  let input = pass_test_module_from_wat(
    "(module (func (export \"run\") (param i32) (result i32) block (result i32) local.get 0 end))",
  )
  let bytes = @binary.encode_module(input).unwrap()
  let output = dae2_fold_known_local_throws(input)
  assert_true(physical_equal(output, input))
  assert_eq(@binary.encode_module(output).unwrap(), bytes)
  @validate.validate_module(output).unwrap()
}

///|
test "DAE2 active legacy adaptation retains untouched sibling ownership" {
  let input = pass_test_module_from_wat(
    "(module (tag $t) (func (export \"run\") (result i32) (try (result i32) (do (throw $t)) (catch $t (i32.const 9)) (catch_all (i32.const 10)))) (func (export \"keep\") (param i32) (result i32) block (result i32) local.get 0 end))",
  )
  let bytes = @binary.encode_module(input).unwrap()
  let output = dae2_prepare_legacy_handlers(input).unwrap()
  assert_true(
    physical_equal(output.code_sec.unwrap().0[1], input.code_sec.unwrap().0[1]),
  )
  assert_false(
    physical_equal(output.code_sec.unwrap().0[0], input.code_sec.unwrap().0[0]),
  )
  @validate.validate_module(output).unwrap()
  let hot = @ir.hot_lift_func(output, @lib.FuncIdx::new(0U))
  let mut handlers = 0
  for node in 0..<@ir.hot_node_count(hot) {
    if @ir.hot_node_get(hot, node).op is @ir.TryTable {
      handlers += 1
    }
  }
  assert_eq(handlers, 1)
  assert_eq(@binary.encode_module(input).unwrap(), bytes)
}

///|
test "DAE2 active local throw folding preserves untouched sibling ownership" {
  let input = pass_test_module_from_wat(
    "(module (tag $t (param i32)) (func (export \"run\") (result i32) block $out (result i32) try_table (catch $t $out) i32.const 42 throw $t end i32.const 0 end) (func (export \"keep\") (param i32) (result i32) block (result i32) local.get 0 end))",
  )
  let bytes = @binary.encode_module(input).unwrap()
  let output = dae2_fold_known_local_throws(input)
  assert_true(
    physical_equal(output.code_sec.unwrap().0[1], input.code_sec.unwrap().0[1]),
  )
  @validate.validate_module(output).unwrap()
  let hot = @ir.hot_lift_func(output, @lib.FuncIdx::new(0U))
  let mut throws = 0
  for node in 0..<@ir.hot_node_count(hot) {
    if @ir.hot_node_get(hot, node).op is @ir.Throw {
      throws += 1
    }
  }
  assert_eq(throws, 0)
  assert_eq(@binary.encode_module(input).unwrap(), bytes)
  for name in ["dae2", "dae2-optimizing"] {
    @validate.validate_module(
      run_hot_pipeline(input, HotPipelineOptions::new(), [name]).unwrap(),
    ).unwrap()
  }
}

///|
test "DAE2 handler benchmark controls preserve reference bytes and trigger adaptations" {
  for legacy in [true, false] {
    for active in [true, false] {
      let input = dae2_handler_admission_fixture(2, active, legacy)
      @validate.validate_module(input).unwrap()
      let original = @binary.encode_module(input).unwrap()
      let before = if legacy {
        dae2_prepare_legacy_handlers_reference(input).unwrap()
      } else {
        dae2_fold_known_local_throws_reference(input)
      }
      let after = if legacy {
        dae2_prepare_legacy_handlers(input).unwrap()
      } else {
        dae2_fold_known_local_throws(input)
      }
      @validate.validate_module(after).unwrap()
      let bytes = @binary.encode_module(after).unwrap()
      assert_eq(bytes, @binary.encode_module(before).unwrap())
      assert_eq(bytes != original, active)
      assert_eq(@binary.encode_module(input).unwrap(), original)
    }
  }
}

///|
test "DAE2 legacy admission retains canonical declaration bytes for untouched grouped locals" {
  let input = dae2_handler_admission_fixture(1, true, true)
  let funcs = input.code_sec.unwrap().0.copy()
  let @lib.Func(_, original_body) = funcs[0]
  funcs[0] = @lib.Func::new(
    @lib.Locals::from_decl_runs_preserving_groups([
      @lib.LocalRun::new(1U, @lib.ValType::i32()),
      @lib.LocalRun::new(1U, @lib.ValType::i32()),
    ]),
    original_body,
  )
  let input = input.with_code_sec(@lib.CodeSec::new(funcs))
  let original = @binary.encode_module(input).unwrap()
  let expected = dae2_prepare_legacy_handlers_reference(input).unwrap()
  let output = dae2_prepare_legacy_handlers(input).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(expected).unwrap(),
  )
  let @lib.Func(locals, body) = output.code_sec.unwrap().0[0]
  assert_eq(locals.runs(), [@lib.LocalRun::new(2U, @lib.ValType::i32())])
  assert_true(physical_equal(body, original_body))
  @validate.validate_module(output).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), original)
}
