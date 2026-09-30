///|
test "capture compaction keeps multi-read producers and active writes intact" {
  for
    body in [
      "call $produce local.set 0 local.get 0 call $consume local.get 0 call $consume",
      "call $produce local.set 0 loop local.get 0 call $consume end local.get 0 call $consume",
      "call $produce local.set 0 call $produce local.set 0 local.get 0 call $consume local.get 0 call $consume",
    ] {
    let input = pass_test_module_from_wat(
      "(module (import \"env\" \"produce\" (func $produce (result i32))) (import \"env\" \"consume\" (func $consume (param i32))) (func (export \"run\") (local i32) \{body}))",
    )
    let func = input.code_sec.unwrap().0[0]
    let original = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
    let (out, indices) = pass_lower_compact_captures_with_map(
      func,
      original,
      [],
      propagate_parameter_aliases=true,
    )
    let @lib.Func(locals, @lib.Expr(instructions)) = out
    let @lib.Func(_, @lib.Expr(expected)) = func
    assert_eq(locals.length(), 1)
    assert_eq(indices, [0])
    assert_eq(instructions, expected)
    @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([out]))).unwrap()
  }
}

///|
test "capture compaction still prunes unused declarations when no pair is eligible" {
  let func = @lib.Func::new(
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i64()]),
    @lib.Expr::new([]),
  )
  let original = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
  let (out, indices) = pass_lower_compact_captures_with_map(func, original, [])
  let @lib.Func(locals, @lib.Expr(body)) = out
  assert_eq(locals.length(), 0)
  assert_eq(indices, [-1, -1])
  assert_eq(body, [])
}

///|
test "capture compaction retains immutable aliases as active work without single-use captures" {
  for
    body in [
      "local.get 0 local.set 1 local.get 1 drop local.get 1 drop", "local.get 0 local.tee 1 drop local.get 1 drop local.get 1 drop",
      "local.get 0 local.set 1",
    ] {
    let input = pass_test_module_from_wat(
      "(module (func (export \"run\") (param i32) (local i32) \{body}))",
    )
    let original = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
    let (out, indices) = pass_lower_compact_captures_with_map(
      input.code_sec.unwrap().0[0],
      original,
      [@lib.ValType::i32()],
      propagate_parameter_aliases=true,
    )
    let @lib.Func(locals, @lib.Expr(body)) = out
    assert_eq(locals.length(), 0)
    assert_eq(indices, [0, -1])
    assert_eq(
      body
      .filter(fn(i) { i is @lib.LocalSet(_) || i is @lib.LocalTee(_) })
      .length(),
      0,
    )
    @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([out]))).unwrap()
  }
}

///|
test "capture compaction preserves normalization of redundant local groups without an eligible pair" {
  let source = pass_test_module_from_wat(
    "(module (func (local i32 i32) i32.const 1 local.set 0 local.get 0 drop local.get 0 drop i32.const 2 local.set 1 local.get 1 drop local.get 1 drop))",
  )
  let @lib.Func(_, body) = source.code_sec.unwrap().0[0]
  let locals = @lib.Locals::from_decl_runs_preserving_groups([
    @lib.LocalRun::new(1U, @lib.ValType::i32()),
    @lib.LocalRun::new(0U, @lib.ValType::i64()),
    @lib.LocalRun::new(1U, @lib.ValType::i32()),
  ])
  let func = @lib.Func::new(locals, body)
  let original = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
  let (out, indices) = pass_lower_compact_captures_with_map(func, original, [])
  let @lib.Func(compact_locals, compact_body) = out
  assert_eq(compact_locals.runs(), [@lib.LocalRun::new(2U, @lib.ValType::i32())])
  assert_eq(compact_body, body)
  assert_eq(indices, [0, 1])
  assert_eq(locals.run_count(), 3)
}
