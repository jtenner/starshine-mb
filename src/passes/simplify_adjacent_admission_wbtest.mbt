///|
fn sl_adjacent_admission_fixture(
  pairs : Int32,
  rewritten : Bool,
) -> @lib.Module {
  let body = Array::makei(pairs, fn(index) {
    if rewritten {
      "i32.const \{index} local.tee 1 nop drop"
    } else {
      "i32.const \{index} local.set 1 nop local.get 1 drop"
    }
  }).join(" ")
  pass_test_module_from_wat(
    "(module (type $entry (func (param i32))) (import \"env\" \"mark\" (func (param i32))) (memory 1) (func (export \"run\") (param i32) (result i32) (local i32) local.get 0 loop (type $entry) local.set 1 local.get 0 call 0 local.get 1 call 0 \{body} end local.get 1))",
  )
}

///|
test "adjacent set get cleanup borrows exact unchanged typed loop rows" {
  let input = sl_adjacent_admission_fixture(0, false)
  @validate.validate_module(input).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let saved = @binary.encode_module(input).unwrap()
  let (actual, count) = run_hot_pipeline_raw_simplify_locals_rewrite_adjacent_set_gets(
    body,
  )
  assert_eq(count, 0)
  assert_eq(actual, body)
  let output = input.with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(actual))]),
  )
  @validate.validate_module(output).unwrap()
  assert_eq(@binary.encode_module(output).unwrap(), saved)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_true(physical_equal(actual, body))
}

///|
test "adjacent set get cleanup keeps all eight active typed loop rewrites" {
  let input = sl_adjacent_admission_fixture(8, false)
  let expected = sl_adjacent_admission_fixture(8, true)
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let (actual, count) = run_hot_pipeline_raw_simplify_locals_rewrite_adjacent_set_gets(
    body,
  )
  assert_eq(count, 8)
  let output = input.with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(actual))]),
  )
  assert_eq(output.code_sec, expected.code_sec)
  @validate.validate_module(output).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(expected).unwrap(),
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_false(physical_equal(actual, body))
  match (body[1], actual[1]) {
    (@lib.Loop(_, @lib.Expr(source)), @lib.Loop(_, @lib.Expr(owned))) => {
      assert_false(physical_equal(source, owned))
      owned.push(@lib.Instruction::nop())
    }
    _ => fail("expected the original indexed loop header")
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "adjacent set get active output owns unchanged sibling and if rows" {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"mark\" (func (param i32))) (func (export \"run\") (param i32) (result i32) (local i32) block local.get 0 call 0 end local.get 0 if local.get 0 local.set 1 nop local.get 1 drop else local.get 0 call 0 end local.get 1))",
  )
  let expected = pass_test_module_from_wat(
    "(module (import \"env\" \"mark\" (func (param i32))) (func (export \"run\") (param i32) (result i32) (local i32) block local.get 0 call 0 end local.get 0 if local.get 0 local.tee 1 nop drop else local.get 0 call 0 end local.get 1))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let (actual, count) = run_hot_pipeline_raw_simplify_locals_rewrite_adjacent_set_gets(
    body,
  )
  assert_eq(count, 1)
  let output = input.with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(actual))]),
  )
  assert_eq(output.code_sec, expected.code_sec)
  @validate.validate_module(output).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(expected).unwrap(),
  )
  match (body[0], actual[0]) {
    (@lib.Block(_, @lib.Expr(source)), @lib.Block(_, @lib.Expr(owned))) => {
      assert_false(physical_equal(source, owned))
      owned.push(@lib.Instruction::nop())
    }
    _ => fail("expected unchanged sibling block")
  }
  match (body[2], actual[2]) {
    (
      @lib.If(_, source_then, Some(source_else)),
      @lib.If(_, owned_then, Some(owned_else)),
    ) => {
      assert_false(physical_equal(source_then, owned_then))
      assert_false(physical_equal(source_else, owned_else))
      owned_then.push(@lib.Instruction::nop())
      owned_else.push(@lib.Instruction::nop())
    }
    _ => fail("expected changed then arm and unchanged else arm")
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "adjacent admission retains zero pair SIMD NaN mesh cleanup" {
  let input = pass_test_module_from_wat(
    "(module (func (param v128) (result v128) local.get 0 f64x2.nearest local.get 0 f64x2.eq local.get 0 local.get 0 v128.bitselect))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let (_, pairs) = run_hot_pipeline_raw_simplify_locals_rewrite_adjacent_set_gets(
    body,
  )
  assert_eq(pairs, 0)
  assert_true(
    run_hot_pipeline_raw_simplify_locals_has_simd_nan_fixup_mesh(body),
  )
  let result = match
    run_hot_pipeline_raw_simplify_locals(
      input,
      @lib.FuncIdx::new(0U),
      HotPipelineModuleState::new(),
      @ir.HotPassDescriptor::new("simplify-locals"),
      HotPipelineOptions::new(),
    ) {
    Some(result) => result
    None => fail("expected the existing zero-pair NaN mesh cleanup")
  }
  assert_eq(result.reason, "adjacent-set-get-tee")
  assert_false(result.unchanged_original)
  let output = input.with_code_sec(@lib.CodeSec::new([result.func]))
  @validate.validate_module(output).unwrap()
  assert_eq(output.code_sec, input.code_sec)
  assert_eq(@binary.encode_module(output).unwrap(), saved)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "adjacent admission rejects scalar call bulk despite eight pairs" {
  let pairs = Array::make(8, "local.get 0 local.set 1 nop local.get 1 call 0").join(
    " ",
  )
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"mark\" (func (param i32))) (func (param i32) (result i32) (local i32) \{pairs} local.get 1))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let (_, count) = run_hot_pipeline_raw_simplify_locals_rewrite_adjacent_set_gets(
    body,
  )
  assert_eq(count, 8)
  assert_true(run_hot_pipeline_raw_simplify_locals_has_any_call(body))
  assert_eq(
    run_hot_pipeline_raw_simplify_locals_simd_pure_op_count_at_most(body, 16),
    0,
  )
  match
    run_hot_pipeline_raw_simplify_locals(
      input,
      @lib.FuncIdx::new(1U),
      HotPipelineModuleState::new(),
      @ir.HotPassDescriptor::new("simplify-locals"),
      HotPipelineOptions::new(),
    ) {
    Some(result) => {
      assert_false(result.reason == "adjacent-set-get-tee")
      let output = input.with_code_sec(@lib.CodeSec::new([result.func]))
      @validate.validate_module(output).unwrap()
      @binary.encode_module(output).unwrap() |> ignore
    }
    None => ()
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
