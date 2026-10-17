///|
test "DAE shared call sink context retains parameter result and target checks" {
  let input = pass_test_module_from_wat(
    (
      #| (module
      #|   (import "host" "sink" (func $sink (param i32)))
      #|   (import "host" "mark" (func $mark (param i32) (result i32)))
      #|   (import "host" "wide" (func $wide (param i64)))
      #|   (func (param i32) local.get 0 call $sink)
      #|   (func (export "public") (param i32) local.get 0 call $sink)
      #|   (func (param i32 i32) local.get 0 call $sink)
      #|   (func (param i32) (result i32) local.get 0 call $mark)
      #|   (func (param i32) (local i32) local.get 0 call $sink)
      #|   (func (param i32) (result i32) local.get 0)
      #|   (func (param i64) local.get 0 call $wide))
    ),
  )
  ignore(@validate.validate_module(input).unwrap())
  let context = dae_exact_literal_candidate_context_new(input).unwrap()
  let expected = [true, true, false, false, false, false, true]
  for index in 0..<expected.length() {
    assert_eq(
      dae_exact_literal_candidate_is_single_param_call_sink(
        input,
        index,
        context=Some(context),
      ),
      expected[index],
    )
    assert_eq(
      dae_exact_literal_candidate_is_single_param_call_sink(input, index),
      expected[index],
    )
  }
  for index in [-1, expected.length()] {
    assert_false(
      dae_exact_literal_candidate_is_single_param_call_sink(
        input,
        index,
        context=Some(context),
      ),
    )
  }
}

///|
test "DAE call sink application compares source and current signature rows" {
  let source = pass_test_module_from_wat(
    (
      #| (module
      #|   (import "host" "sink" (func $sink (param i32)))
      #|   (func (param i32) local.get 0 call $sink)
      #|   (func (export "public") (param i32) local.get 0 call $sink)
      #|   (func (param i64) local.get 0 drop))
    ),
  )
  let current = pass_test_module_from_wat(
    (
      #| (module
      #|   (import "host" "other" (func))
      #|   (import "host" "sink" (func $sink (param i32)))
      #|   (func i32.const 7 call $sink)
      #|   (func (export "public") (param i32) local.get 0 call $sink))
    ),
  )
  ignore(@validate.validate_module(source).unwrap())
  ignore(@validate.validate_module(current).unwrap())
  assert_eq(dae_collect_applied_call_sink_uniform_defs(source, current), [0])
  assert_eq(dae_collect_applied_call_sink_uniform_defs(source, source), [])
  assert_eq(dae_collect_applied_call_sink_uniform_defs(current, source), [])
}

///|
test "DAE uniform call sink flow moves the actual once and preserves public arguments" {
  for public_sink in [false, true] {
    let exported = if public_sink { "(export \"forward\")" } else { "" }
    let input = pass_test_module_from_wat(
      "(module (import \"host\" \"sink\" (func $sink (param i32))) " +
      "(func $forward " +
      exported +
      " (param i32) local.get 0 call $sink) " +
      "(func (export \"run\") i32.const 7 call $forward))",
    )
    let result = dae_run_call_sink_uniform_parameter_flow(
      input,
      input,
      [false, false],
      false,
    )
    ignore(@validate.validate_module(result.mod_out).unwrap())
    let funcs = result.mod_out.code_sec.unwrap().0
    let @lib.Func(_, @lib.Expr(forward)) = funcs[0]
    let @lib.Func(_, @lib.Expr(caller)) = funcs[1]
    if public_sink {
      assert_false(result.changed)
      assert_eq(forward, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      ])
      assert_eq(caller, [
        @lib.Instruction::i32_const(7),
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
      ])
    } else {
      assert_true(result.changed)
      assert_eq(forward, [
        @lib.Instruction::i32_const(7),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      ])
      assert_eq(caller, [@lib.Instruction::call(@lib.FuncIdx::new(1U))])
      assert_eq(
        dae_collect_applied_call_sink_uniform_defs(input, result.mod_out),
        [0],
      )
    }
  }
}

///|
test "DAE empty adjacent roots retain module ownership touched state and trace" {
  let input = pass_test_module_from_wat(
    "(module (func (export \"run\") (param i32) (result i32) local.get 0))",
  )
  let touched = [true]
  let messages : Array[String] = []
  let result = dae_run_broad_exact_param_adjacent_cleanup_root(
    input,
    input,
    [],
    touched,
    true,
    fn(message) { messages.push(message) },
  )
  assert_true(physical_equal(result.mod_out, input))
  assert_true(physical_equal(result.touched, touched))
  assert_true(result.candidate is None)
  assert_eq(messages, [
    "pass[dae-optimizing]:broad-exact-param-adjacent-candidates roots=0 pairs=0",
  ])
  ignore(@validate.validate_module(result.mod_out).unwrap())
  let @lib.Func(_, @lib.Expr(body)) = result.mod_out.code_sec.unwrap().0[0]
  assert_eq(body, [@lib.Instruction::local_get(@lib.LocalIdx::new(0U))])
  assert_eq(result.effects, dae_commit_effects_empty(1))
}

///|
test "DAE empty dropped result worklist preserves prior changes and effects" {
  let input = pass_test_module_from_wat(
    "(module (func (export \"run\") (param i32) (result i32) local.get 0))",
  )
  for changed in [false, true] {
    let touched = [changed]
    let result = dae_run_dropped_result_candidate_worklist_with_facts(
      input,
      touched,
      changed,
      [],
    )
    assert_true(physical_equal(result.mod_out, input))
    assert_true(physical_equal(result.touched, touched))
    assert_eq(result.changed, changed)
    assert_eq(result.productive_defs, [])
    assert_eq(result.effects, dae_commit_effects_empty(1))
    ignore(@validate.validate_module(result.mod_out).unwrap())
    let @lib.Func(_, @lib.Expr(body)) = result.mod_out.code_sec.unwrap().0[0]
    assert_eq(body, [@lib.Instruction::local_get(@lib.LocalIdx::new(0U))])
  }
}

///|
test "DAE nonempty dropped result worklist preserves the host call once" {
  let input = pass_test_module_from_wat(
    (
      #| (module
      #|   (import "host" "mark" (func $mark (param i32) (result i32)))
      #|   (func $inner (result i32) i32.const 7 call $mark)
      #|   (func (export "run") call $inner drop))
    ),
  )
  let result = dae_run_dropped_result_candidate_worklist_with_facts(
    input,
    [false, false],
    false,
    [0],
  )
  assert_true(result.changed)
  ignore(@validate.validate_module(result.mod_out).unwrap())
  let funcs = result.mod_out.code_sec.unwrap().0
  let @lib.Func(_, @lib.Expr(inner)) = funcs[0]
  let @lib.Func(_, @lib.Expr(caller)) = funcs[1]
  assert_eq(inner, [
    @lib.Instruction::i32_const(7),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::drop(),
  ])
  assert_eq(caller, [@lib.Instruction::call(@lib.FuncIdx::new(1U))])
  assert_eq(result.productive_defs, [0])
}

///|
test "DAE call sink discovery rejects intentionally incomplete missing code" {
  let current = pass_test_module_from_wat(
    "(module (func (param i32) local.get 0 drop))",
  )
  // This incomplete IR is invalid. Discovery must reject it without unwrapping
  // a missing source context, as the original per-function predicate did.
  let incomplete = @lib.Module::new(
    type_sec=current.type_sec,
    func_sec=current.func_sec,
  )
  assert_eq(dae_collect_applied_call_sink_uniform_defs(incomplete, current), [])
}
