///|
test "dae2 rewrites pure dropped argument suffixes inside loops without a second HOT lift" {
  for
    control in [
      "loop local.get 0 i32.const 9 call $sink end", "local.get 0 if local.get 0 i32.const 9 call $sink else i32.const 7 i32.const 9 call $sink end",
      "block loop local.get 0 i32.const 9 call $sink i32.const 0 br_if 0 end end",
    ] {
    let input = pass_test_module_from_wat(
      "(module (global $g (mut i32) (i32.const 0)) (func $sink (param i32 i32) local.get 0 global.set $g) (func (export \"run\") (param i32) \{control}))",
    )
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let rewrite = [0]
    let output = dae2_run_module_pass(input, false, rewrite_lifts=Some(rewrite)).unwrap()
    @validate.validate_module(output).unwrap()
    let context = @ir.hot_module_context_from_module(output)
    assert_eq(
      @ir.hot_module_resolve_func_type(context, @lib.FuncIdx::new(0U)),
      Some(@lib.FuncType::new([@lib.ValType::i32()], [])),
    )
    assert_eq(rewrite[0], 0)
    let reference = dae2_run_module_pass(input, false, raw_rewrite=false).unwrap()
    @validate.validate_module(reference).unwrap()
    assert_true(
      @binary.encode_module(output).unwrap().length() <=
      @binary.encode_module(reference).unwrap().length(),
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "dae2 structured suffix replay preserves cleanup of an overwritten local store" {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"consume\" (func $consume (param i32))) (func $h (param i32 i64) (local i32) i32.const 0 local.set 2 loop local.get 0 local.set 2 end local.get 2 call $consume) (func (export \"run\") (param i32) local.get 0 i64.const 9 call $h))",
  )
  @validate.validate_module(input).unwrap()
  let output = dae2_run_module_pass(input, false).unwrap()
  let reference = dae2_run_module_pass(input, false, raw_rewrite=false).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(reference).unwrap(),
  )
}

///|
test "dae2 structured suffix replay retains HOT normalization of unreachable returns" {
  for
    body in [
      "block local.get 0 global.set $g br 0 return end", "local.get 0 if (result i32) i32.const 7 return else i32.const 8 return end return",
    ] {
    let result = if body.starts_with("block") { "" } else { "(result i32)" }
    let input = pass_test_module_from_wat(
      "(module (global $g (mut i32) (i32.const 0)) (func $h (param i32 i64) \{result} \{body}) (func (export \"run\") (param i32) \{result} local.get 0 i64.const 9 call $h))",
    )
    @validate.validate_module(input).unwrap()
    let output = dae2_run_module_pass(input, false).unwrap()
    let reference = dae2_run_module_pass(input, false, raw_rewrite=false).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
  }
}

///|
test "dae2 streaming suffix rewrite remaps unread parameters and preserves branch depths" {
  let input = pass_test_module_from_wat(
    "(module (func $h (param i32 i64 externref) (result i32) block (result i32) local.get 0 br 0 end) (func (export \"run\") (param i32) (result i32) local.get 0 i64.const 9 ref.null extern call $h))",
  )
  let rewrite = [0]
  let output = dae2_run_module_pass(input, false, rewrite_lifts=Some(rewrite)).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(rewrite[0], 0)
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 0)
  assert_eq(body, [
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::br(@lib.LabelIdx::new(0U)),
      ]),
    ),
  ])
}

///|
test "dae2 suffix replay keeps a trapping discarded producer on its HOT path" {
  let input = pass_test_module_from_wat(
    "(module (global $g (mut i32) (i32.const 0)) (memory 1) (func $sink (param i32 i32) local.get 0 global.set $g) (func (export \"run\") (param i32) loop local.get 0 i32.const 65536 i32.load call $sink end))",
  )
  let rewrite = [0]
  let output = dae2_run_module_pass(input, false, rewrite_lifts=Some(rewrite)).unwrap()
  @validate.validate_module(output).unwrap()
  assert_true(rewrite[0] > 0)
  let reference = dae2_run_module_pass(input, false, raw_rewrite=false).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(reference).unwrap(),
  )
}

///|
test "dae2 structured suffix replay removes a fully dropped result tuple at its call boundary" {
  let input = pass_test_module_from_wat(
    "(module (global $g (mut i32) (i32.const 0)) (func $h (param i32 i64) (result i32 i64) local.get 0 global.set $g i32.const 7 i64.const 8) (func (export \"run\") (param i32) (result i32) loop local.get 0 i64.const 9 call $h drop drop end global.get $g))",
  )
  let lifts = [0]
  let output = dae2_run_module_pass(input, false, rewrite_lifts=Some(lifts)).unwrap()
  @validate.validate_module(output).unwrap()
  // The callee's own removed results keep their HOT rewrite; the structured
  // caller removes literal suffix arguments and exactly two call-result drops.
  assert_eq(lifts[0], 1)
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  assert_eq(
    body[0],
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      ]),
    ),
  )
  let reference = dae2_run_module_pass(input, false, raw_rewrite=false).unwrap()
  assert_true(
    @binary.encode_module(output).unwrap().length() <=
    @binary.encode_module(reference).unwrap().length(),
  )
}

///|
test "dae2 structured suffix replay preserves retained producer and callee effects in order" {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"produce\" (func $produce (result i32))) (import \"env\" \"consume\" (func $consume (param i32))) (func $h (param i32 i64 externref) local.get 0 call $consume) (func (export \"run\") loop call $produce i64.const 9 ref.null extern call $h end))",
  )
  let lifts = [0]
  let output = dae2_run_module_pass(input, false, rewrite_lifts=Some(lifts)).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(lifts[0], 0)
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  assert_eq(body, [
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::call(@lib.FuncIdx::new(2U)),
      ]),
    ),
  ])
}

///|
test "dae2 structured suffix replay intentionally leaves interleaved argument pruning to HOT" {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"consume\" (func $consume (param i32))) (func $h (param i64 i32) local.get 1 call $consume) (func (export \"run\") (param i32) loop i64.const 9 local.get 0 call $h end))",
  )
  let lifts = [0]
  let output = dae2_run_module_pass(input, false, rewrite_lifts=Some(lifts)).unwrap()
  @validate.validate_module(output).unwrap()
  assert_true(lifts[0] > 0)
  let reference = dae2_run_module_pass(input, false, raw_rewrite=false).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(reference).unwrap(),
  )
}

///|
test "dae2 structured suffix replay preserves dead local write cleanup and producer effects" {
  for
    body in [
      "local.get 0 local.tee 2 if local.get 0 global.set $g end", "local.get 0 if call $produce local.set 2 end",
    ] {
    let input = pass_test_module_from_wat(
      "(module (import \"env\" \"produce\" (func $produce (result i32))) (global $g (mut i32) (i32.const 0)) (func $h (param i32 i32) (local i32) \{body}) (func (export \"run\") (param i32) local.get 0 i32.const 9 call $h))",
    )
    let output = dae2_run_module_pass(input, false).unwrap()
    let reference = dae2_run_module_pass(input, false, raw_rewrite=false).unwrap()
    @validate.validate_module(output).unwrap()
    let @lib.Func(_, @lib.Expr(instructions)) = output.code_sec.unwrap().0[0]
    assert_eq(instructions.filter(fn(i) { i is @lib.LocalTee(_) }).length(), 0)
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
  }
}

///|
test "dae2 structured suffix replay discards removed tuples stored in unread locals" {
  let input = pass_test_module_from_wat(
    "(module (global $g (mut i32) (i32.const 0)) (func $h (param i32 i64) (result i32 i64) local.get 0 global.set $g i32.const 7 i64.const 8) (func (export \"run\") (param i32) (result i32) (local i32 i64) loop local.get 0 i64.const 9 call $h local.set 2 local.set 1 end global.get $g))",
  )
  let lifts = [0]
  let output = dae2_run_module_pass(input, false, rewrite_lifts=Some(lifts)).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(lifts[0], 1)
  let reference = dae2_run_module_pass(input, false, raw_rewrite=false).unwrap()
  assert_true(
    @binary.encode_module(output).unwrap().length() <=
    @binary.encode_module(reference).unwrap().length(),
  )
}

///|
test "dae2 structured suffix liveness excludes removed argument reads before clearing earlier stores" {
  let input = pass_test_module_from_wat(
    "(module (global $g (mut i32) (i32.const 0)) (func $h (param i32 i64) local.get 0 global.set $g) (func (export \"run\") (param i32) (local i64) i64.const 9 local.set 1 loop local.get 0 local.get 1 call $h end))",
  )
  let lifts = [0]
  let output = dae2_run_module_pass(input, false, rewrite_lifts=Some(lifts)).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(lifts[0], 0)
  let reference = dae2_run_module_pass(input, false, raw_rewrite=false).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(reference).unwrap(),
  )
}
