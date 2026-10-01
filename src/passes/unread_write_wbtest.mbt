///|
test "optimizing capture compaction removes unread tees without moving the producer" {
  for scalar in ["i32", "externref"] {
    let input = pass_test_module_from_wat(
      "(module (import \"env\" \"produce\" (func $produce (result \{scalar}))) (func (export \"run\") (result \{scalar}) (local \{scalar}) call $produce local.tee 0))",
    )
    let func = input.code_sec.unwrap().0[0]
    let original_bytes = @binary.encode_module(input).unwrap()
    let (actual, indices) = pass_lower_compact_captures_with_map(
      func,
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      [],
      propagate_parameter_aliases=true,
    )
    let @lib.Func(locals, @lib.Expr(body)) = actual
    assert_eq(locals.length(), 0)
    assert_eq(indices, [-1])
    assert_eq(body, [@lib.Instruction::call(@lib.FuncIdx::new(0U))])
    let output = input.with_code_sec(@lib.CodeSec::new([actual]))
    @validate.validate_module(output).unwrap()
    assert_true(
      @binary.encode_module(output).unwrap().length() < original_bytes.length(),
    )
    assert_eq(@binary.encode_module(input).unwrap(), original_bytes)
  }
}

///|
test "optimizing capture compaction keeps side-effecting multivalue unused-set producers" {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"produce\" (func $produce (result i64 i32))) (func (result i64) (local i32) call $produce local.set 0))",
  )
  let (actual, indices) = pass_lower_compact_captures_with_map(
    input.code_sec.unwrap().0[0],
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
    [],
    propagate_parameter_aliases=true,
  )
  let @lib.Func(locals, @lib.Expr(body)) = actual
  assert_eq(locals.length(), 0)
  assert_eq(indices, [-1])
  assert_eq(body, [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::drop(),
  ])
  @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([actual]))).unwrap()
}

///|
test "optimizing unread write retirement preserves nested loop producers and stack use" {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"produce\" (func $produce (result i32))) (func (local i32) block loop call $produce local.set 0 call $produce local.tee 0 drop end end))",
  )
  let original = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
  let (actual, indices) = pass_lower_compact_captures_with_map(
    input.code_sec.unwrap().0[0],
    original,
    [],
    propagate_parameter_aliases=true,
  )
  assert_eq(indices, [-1])
  let @lib.Func(locals, @lib.Expr(body)) = actual
  assert_eq(locals.length(), 0)
  let expected = pass_test_module_from_wat(
    "(module (import \"env\" \"produce\" (func $produce (result i32))) (func block loop call $produce drop call $produce drop end end))",
  )
  let @lib.Func(_, @lib.Expr(expected_body)) = expected.code_sec.unwrap().0[0]
  assert_eq(body, expected_body)
  @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([actual]))).unwrap()
}

///|
test "optimizing unread write retirement keeps handler and other-arm reads live" {
  for
    code in [
      "call $produce local.set 0 (try (do (nop)) (catch_all (drop (local.get 0)) (drop (local.get 0))))",
      "call $produce local.set 0 i32.const 0 if nop else local.get 0 drop local.get 0 drop end",
    ] {
    let input = pass_test_module_from_wat(
      "(module (import \"env\" \"produce\" (func $produce (result i32))) (func (local i32) \{code}))",
    )
    let original = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
    let (actual, indices) = pass_lower_compact_captures_with_map(
      input.code_sec.unwrap().0[0],
      original,
      [],
      propagate_parameter_aliases=true,
    )
    assert_eq(indices, [0])
    assert_eq(actual, input.code_sec.unwrap().0[0])
    @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([actual]))).unwrap()
  }
}

///|
test "optimizing unread retirement preserves original locals and plain lowering" {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"produce\" (func $produce (result i32))) (func (local i32) call $produce local.tee 0 drop))",
  )
  let func = input.code_sec.unwrap().0[0]
  let empty = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
  assert_eq(
    pass_lower_compact_captures_with_map(
      func,
      func,
      [],
      propagate_parameter_aliases=true,
    ),
    (func, [0]),
  )
  assert_eq(pass_lower_compact_captures_with_map(func, empty, []), (func, [0]))
}

///|
test "optimizing unread retirement cooperates with proved alias replay" {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"produce\" (func $produce (result i32))) (func (param i32) (result i32) (local i32 i32) local.get 0 local.set 1 call $produce local.tee 2 drop block (result i32) local.get 1 end))",
  )
  let original = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
  let (actual, indices) = pass_lower_compact_captures_with_map(
    input.code_sec.unwrap().0[0],
    original,
    [@lib.ValType::i32()],
    propagate_parameter_aliases=true,
  )
  assert_eq(indices, [0, -1, -1])
  let @lib.Func(locals, @lib.Expr(body)) = actual
  assert_eq(locals.length(), 0)
  assert_false(
    body.contains(@lib.Instruction::local_tee(@lib.LocalIdx::new(2U))),
  )
  @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([actual]))).unwrap()
}

///|
test "optimizing unread tees retain a concrete non-null GC producer result" {
  let input = pass_test_module_from_wat(
    "(module (type $box (struct (field i32))) (global $calls (mut i32) (i32.const 0)) (func $produce (result (ref $box)) global.get $calls i32.const 1 i32.add global.set $calls i32.const 9 struct.new $box) (func (export \"run\") (result (ref $box)) (local (ref $box)) call $produce local.tee 0))",
  )
  let original = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
  let (actual, indices) = pass_lower_compact_captures_with_map(
    input.code_sec.unwrap().0[1],
    original,
    [],
    propagate_parameter_aliases=true,
  )
  let @lib.Func(locals, @lib.Expr(body)) = actual
  assert_eq(indices, [-1])
  assert_eq(locals.length(), 0)
  assert_eq(body, [@lib.Instruction::call(@lib.FuncIdx::new(0U))])
  let funcs = input.code_sec.unwrap().0.copy()
  funcs[1] = actual
  let output = input.with_code_sec(@lib.CodeSec::new(funcs))
  @validate.validate_module(output).unwrap()
  assert_true(
    @binary.encode_module(output).unwrap().length() <
    @binary.encode_module(input).unwrap().length(),
  )
}

///|
test "optimizing unread sets keep their producer when alias replay is also active" {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"produce\" (func $produce (result i32))) (func (param i32) (result i32) (local i32 i32) local.get 0 local.set 1 call $produce local.set 2 block (result i32) local.get 1 end))",
  )
  let (actual, indices) = pass_lower_compact_captures_with_map(
    input.code_sec.unwrap().0[0],
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
    [@lib.ValType::i32()],
    propagate_parameter_aliases=true,
  )
  assert_eq(indices, [0, -1, -1])
  let @lib.Func(locals, @lib.Expr(body)) = actual
  assert_eq(locals.length(), 0)
  assert_eq(body[0], @lib.Instruction::call(@lib.FuncIdx::new(0U)))
  assert_eq(body[1], @lib.Instruction::drop())
  @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([actual]))).unwrap()
}
