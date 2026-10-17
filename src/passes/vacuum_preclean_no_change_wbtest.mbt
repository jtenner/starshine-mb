///|
fn vacuum_preclean_no_change_fixture(active : Bool) -> @lib.Module {
  let debris = if active { "nop" } else { "" }
  pass_test_module_from_wat(
    "(module (import \"env\" \"effect\" (func (param i32))) (memory 1) (func (export \"run\") (param i32) (result i32) (local i32) loop local.get 0 i32.load local.set 1 local.get 1 call 0 end loop \{debris} local.get 0 i32.load local.set 1 local.get 1 call 0 end local.get 1))",
  )
}

///|
fn vacuum_preclean_no_change_body(
  mod_ : @lib.Module,
) -> Array[@lib.Instruction] {
  let @lib.Func(_, @lib.Expr(body)) = mod_.code_sec.unwrap().0[0]
  body
}

///|
fn vacuum_preclean_no_change_output(
  input : @lib.Module,
  body : Array[@lib.Instruction],
) -> @lib.Module {
  let @lib.Func(locals, _) = input.code_sec.unwrap().0[0]
  input.with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]),
  )
}

///|
test "vacuum preclean unchanged effectful loops retain their original row" {
  let input = vacuum_preclean_no_change_fixture(false)
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let body = vacuum_preclean_no_change_body(input)
  let (actual, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    body,
    None,
  )
  assert_false(changed)
  assert_eq(actual, body)
  let output = vacuum_preclean_no_change_output(input, actual)
  @validate.validate_module(output).unwrap()
  assert_eq(@binary.encode_module(output).unwrap(), saved)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  // An unchanged result must not build a replacement tree that its caller discards.
  assert_true(physical_equal(actual, body))
}

///|
test "vacuum preclean active late child keeps exact load and effect order" {
  let input = vacuum_preclean_no_change_fixture(true)
  let expected = vacuum_preclean_no_change_fixture(false)
  let saved = @binary.encode_module(input).unwrap()
  let body = vacuum_preclean_no_change_body(input)
  let (actual, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    body,
    None,
  )
  assert_true(changed)
  assert_eq(actual, vacuum_preclean_no_change_body(expected))
  let output = vacuum_preclean_no_change_output(input, actual)
  @validate.validate_module(output).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(expected).unwrap(),
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "vacuum preclean changed output owns unchanged sibling control rows" {
  let input = vacuum_preclean_no_change_fixture(true)
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let body = vacuum_preclean_no_change_body(input)
  let (actual, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    body,
    None,
  )
  assert_true(changed)
  let output = vacuum_preclean_no_change_output(input, actual)
  @validate.validate_module(output).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(vacuum_preclean_no_change_fixture(false)).unwrap(),
  )
  assert_false(physical_equal(actual, body))
  match (body[0], actual[0], body[1], actual[1]) {
    (
      @lib.Loop(_, @lib.Expr(source_left)),
      @lib.Loop(_, @lib.Expr(owned_left)),
      @lib.Loop(_, @lib.Expr(source_right)),
      @lib.Loop(_, @lib.Expr(owned_right)),
    ) => {
      assert_false(physical_equal(source_left, owned_left))
      assert_false(physical_equal(source_right, owned_right))
      owned_left.push(@lib.Instruction::nop())
      owned_right.push(@lib.Instruction::nop())
    }
    _ => fail("expected two preserved loop headers")
  }
  @validate.validate_module(vacuum_preclean_no_change_output(input, actual)).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "vacuum preclean retains flat prefix cleanup outside unchanged proof" {
  let cases = [
    (
      "(module (func (param i32) (local i32) local.get 0 local.tee 1 drop))", "(module (func (param i32) (local i32) local.get 0 local.set 1))",
    ),
    (
      "(module (memory 1) (func (param i32) local.get 0 i32.load drop local.get 0 i32.load drop))",
      "(module (memory 1) (func (param i32) local.get 0 i32.load drop))",
    ),
    (
      "(module (func i32.const 7 unreachable nop))", "(module (func unreachable))",
    ),
    (
      "(module (func loop (result i32) i32.const 7 end drop))", "(module (func))",
    ),
    (
      "(module (func (param v128) local.get 0 v128.not drop))", "(module (func (param v128)))",
    ),
    (
      "(module (import \"env\" \"effect\" (func)) (func i32.const 1 if call 0 else call 0 end))",
      "(module (import \"env\" \"effect\" (func)) (func call 0))",
    ),
  ]
  for (source, expected_wat) in cases {
    let input = pass_test_module_from_wat(source)
    let expected = pass_test_module_from_wat(expected_wat)
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let ctx = run_hot_pipeline_require_module_ctx(
      input,
      HotPipelineModuleState::new(),
      HotPipelineOptions::new(),
    )
    let body = vacuum_preclean_no_change_body(input)
    let (actual, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
      body,
      Some(ctx),
    )
    assert_true(changed)
    assert_eq(actual, vacuum_preclean_no_change_body(expected))
    let output = vacuum_preclean_no_change_output(input, actual)
    @validate.validate_module(output).unwrap()
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(expected).unwrap(),
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "vacuum preclean unchanged flat loop keeps stores division calls and backedge" {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"effect\" (func (param i32))) (memory 1) (global (mut i32) (i32.const 0)) (func (export \"run\") (param i32) (result i32) (local i32) local.get 0 i32.const 7 i32.store local.get 0 i32.load local.tee 1 call 0 local.get 1 i32.const 2 i32.div_s i32.const 3 i32.rem_u global.set 0 loop local.get 1 i32.const 1 i32.sub local.tee 1 br_if 0 end local.get 1))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let body = vacuum_preclean_no_change_body(input)
  let (actual, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    body,
    None,
  )
  assert_false(changed)
  assert_eq(actual, body)
  let output = vacuum_preclean_no_change_output(input, actual)
  @validate.validate_module(output).unwrap()
  assert_eq(@binary.encode_module(output).unwrap(), saved)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_true(physical_equal(actual, body))
}

///|
// If headers are intentionally outside the flat/Loop no-change proof. The
// existing owned worker still handles them even when this row stays unchanged.
test "vacuum preclean unsupported If proof keeps owned effectful arms" {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"effect\" (func (param i32) (result i32))) (func (param i32) (result i32) local.get 0 if (result i32) local.get 0 call 0 else local.get 0 call 0 end))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let body = vacuum_preclean_no_change_body(input)
  let (actual, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    body,
    None,
  )
  assert_false(changed)
  assert_eq(actual, body)
  let output = vacuum_preclean_no_change_output(input, actual)
  @validate.validate_module(output).unwrap()
  assert_eq(@binary.encode_module(output).unwrap(), saved)
  assert_false(physical_equal(actual, body))
  match (body[1], actual[1]) {
    (
      @lib.If(_, source_then, Some(source_else)),
      @lib.If(_, owned_then, Some(owned_else)),
    ) => {
      assert_false(physical_equal(source_then, owned_then))
      assert_false(physical_equal(source_else, owned_else))
      owned_then.push(@lib.Instruction::nop())
      owned_else.push(@lib.Instruction::nop())
    }
    _ => fail("expected the original two effectful If arms")
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "vacuum preclean excludes fresh array stores from unchanged proof" {
  // array.set is not accepted by the in-process text parser. Use direct IR
  // for this existing no-Drop rewrite instead of weakening the control.
  let expected = pass_test_module_from_wat(
    "(module (type $a (array (mut i32))) (func))",
  )
  let @lib.Func(locals, _) = expected.code_sec.unwrap().0[0]
  let body = [
    @lib.Instruction::i32_const(2),
    @lib.Instruction::array_new_default(@lib.TypeIdx::new(0U)),
    @lib.Instruction::i32_const(0),
    @lib.Instruction::i32_const(9),
    @lib.Instruction::array_set(@lib.TypeIdx::new(0U)),
  ]
  let input = vacuum_preclean_no_change_output(expected, body)
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let ctx = run_hot_pipeline_require_module_ctx(
    input,
    HotPipelineModuleState::new(),
    HotPipelineOptions::new(),
  )
  let (actual, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    body,
    Some(ctx),
  )
  let (reference, reference_changed) = run_hot_pipeline_raw_vacuum_preclean_instrs_owned(
    body,
    Some(ctx),
  )
  assert_true(changed)
  assert_true(reference_changed)
  assert_eq(actual, reference)
  assert_eq(actual.length(), 0)
  let output = input.with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(actual))]),
  )
  @validate.validate_module(output).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(expected).unwrap(),
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
