///|
fn local_alias_fixture(
  body : String,
  ty : String,
  params? : String = "",
) -> @lib.Module {
  pass_test_module_from_wat(
    "(module (import \"env\" \"produce\" (func $produce (result \{ty}))) (import \"env\" \"consume\" (func $consume (param \{ty}))) (func (export \"run\") \{params} (local \{ty} \{ty}) \{body}))",
  )
}

///|
test "DAE2 forwards dominated single-write scalar and reference local aliases" {
  for ty in ["i32", "i64", "externref"] {
    for
      body in [
        "call $produce local.set 0 local.get 0 call $consume local.get 0 local.set 1 local.get 1 call $consume local.get 1 call $consume",
        "call $produce local.set 0 local.get 0 call $consume i32.const 1 if local.get 0 local.set 1 local.get 1 call $consume local.get 1 call $consume end",
      ] {
      let input = local_alias_fixture(body, ty)
      @validate.validate_module(input).unwrap()
      let saved = @binary.encode_module(input).unwrap()
      let original = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
      let (out, indices) = pass_lower_compact_captures_with_map(
        input.code_sec.unwrap().0[0],
        original,
        [],
        propagate_parameter_aliases=true,
      )
      let @lib.Func(locals, _) = out
      assert_eq(locals.length(), 1)
      assert_eq(indices, [0, -1])
      @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([out]))).unwrap()
      assert_eq(@binary.encode_module(input).unwrap(), saved)
    }
  }
}

///|
test "DAE2 local aliases preserve the current producer value in each loop iteration" {
  let input = local_alias_fixture(
    "loop call $produce local.set 1 local.get 1 call $consume local.get 1 local.set 2 local.get 2 call $consume local.get 2 call $consume local.get 0 i32.const 1 i32.sub local.tee 0 br_if 0 end",
    "i32",
    params="(param i32)",
  )
  let original = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
  let (out, indices) = pass_lower_compact_captures_with_map(
    input.code_sec.unwrap().0[0],
    original,
    [@lib.ValType::i32()],
    propagate_parameter_aliases=true,
  )
  let @lib.Func(locals, _) = out
  assert_eq(locals.length(), 1)
  assert_eq(indices, [0, 1, -1])
  @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([out]))).unwrap()
}

///|
test "DAE2 local aliases preserve default reads before the alias assignment" {
  let input = local_alias_fixture(
    "call $produce local.set 0 local.get 1 call $consume local.get 0 call $consume local.get 0 local.set 1 local.get 1 call $consume local.get 1 call $consume",
    "i32",
  )
  let original = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
  let (out, indices) = pass_lower_compact_captures_with_map(
    input.code_sec.unwrap().0[0],
    original,
    [],
    propagate_parameter_aliases=true,
  )
  let @lib.Func(locals, @lib.Expr(body)) = out
  assert_eq(locals.length(), 2)
  assert_eq(indices, [0, 1])
  assert_eq(
    body.filter(fn(i) { i is @lib.LocalGet(@lib.LocalIdx(1U)) }).length(),
    1,
  )
  @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([out]))).unwrap()
}

///|
test "DAE2 local aliases intentionally retain snapshots before an unestablished source write" {
  for
    body in [
      "local.get 0 local.set 1 call $produce local.set 0 local.get 0 call $consume local.get 1 call $consume local.get 1 call $consume",
      "local.get 0 local.set 1 loop call $produce local.set 0 local.get 0 call $consume local.get 1 call $consume local.get 1 call $consume end",
    ] {
    let input = local_alias_fixture(body, "i32")
    let func = input.code_sec.unwrap().0[0]
    let original = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
    let (out, indices) = pass_lower_compact_captures_with_map(
      func,
      original,
      [],
      propagate_parameter_aliases=true,
    )
    let @lib.Func(locals, out_body) = out
    let @lib.Func(_, expected_body) = func
    assert_eq(locals.length(), 2)
    assert_eq(indices, [0, 1])
    assert_eq(out_body, expected_body)
  }
}

///|
test "DAE2 local aliases forward unwritten scalar and nullable reference defaults" {
  for ty in ["i32", "i64", "externref"] {
    let input = local_alias_fixture(
      "local.get 0 local.set 1 local.get 1 call $consume local.get 1 call $consume",
      ty,
    )
    let original = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
    let (out, indices) = pass_lower_compact_captures_with_map(
      input.code_sec.unwrap().0[0],
      original,
      [],
      propagate_parameter_aliases=true,
    )
    let @lib.Func(locals, @lib.Expr(body)) = out
    assert_eq(locals.length(), 1)
    assert_eq(indices, [0, -1])
    assert_eq(body, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    ])
    @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([out]))).unwrap()
  }
}

///|
test "DAE2 local aliases preserve snapshots of multiply-written sources" {
  let input = local_alias_fixture(
    "call $produce local.set 0 local.get 0 call $consume local.get 0 local.set 1 call $produce local.set 0 local.get 0 call $consume local.get 1 call $consume local.get 1 call $consume",
    "i32",
  )
  let func = input.code_sec.unwrap().0[0]
  let original = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
  let (out, _) = pass_lower_compact_captures_with_map(
    func,
    original,
    [],
    propagate_parameter_aliases=true,
  )
  let @lib.Func(locals, actual) = out
  let @lib.Func(_, expected) = func
  assert_eq(locals.length(), 2)
  assert_eq(actual, expected)
  @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([out]))).unwrap()
}

///|
test "DAE2 local aliases do not escape into sibling or following default reads" {
  let input = local_alias_fixture(
    "call $produce local.set 0 local.get 0 call $consume i32.const 1 if local.get 0 local.set 1 else local.get 1 call $consume local.get 1 call $consume end local.get 1 call $consume",
    "i32",
  )
  let func = input.code_sec.unwrap().0[0]
  let original = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
  let (out, _) = pass_lower_compact_captures_with_map(
    func,
    original,
    [],
    propagate_parameter_aliases=true,
  )
  let @lib.Func(locals, actual) = out
  let @lib.Func(_, expected) = func
  assert_eq(locals.length(), 2)
  assert_eq(actual, expected)
  @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([out]))).unwrap()
}

///|
test "DAE2 local aliases forward tee chains without repeating the producer" {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"produce\" (func $produce (result i32))) (import \"env\" \"consume\" (func $consume (param i32))) (func (local i32 i32 i32) call $produce local.set 0 local.get 0 call $consume local.get 0 local.tee 1 call $consume local.get 1 local.set 2 local.get 1 call $consume local.get 2 call $consume local.get 2 call $consume))",
  )
  let original = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
  let (out, indices) = pass_lower_compact_captures_with_map(
    input.code_sec.unwrap().0[0],
    original,
    [],
    propagate_parameter_aliases=true,
  )
  let @lib.Func(locals, @lib.Expr(body)) = out
  assert_eq(locals.length(), 1)
  assert_eq(indices, [0, -1, -1])
  assert_eq(body.filter(fn(i) { i is @lib.Call(@lib.FuncIdx(0U)) }).length(), 1)
  assert_eq(body.filter(fn(i) { i is @lib.Call(@lib.FuncIdx(1U)) }).length(), 5)
  assert_eq(body.filter(fn(i) { i is @lib.LocalTee(_) }).length(), 0)
  @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([out]))).unwrap()
}

///|
test "DAE2 local aliases can use a parameter after its only write" {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"consume\" (func $consume (param i32))) (func (param i32) (local i32) i32.const 7 local.set 0 local.get 0 local.set 1 local.get 1 call $consume local.get 1 call $consume))",
  )
  let original = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
  let (out, indices) = pass_lower_compact_captures_with_map(
    input.code_sec.unwrap().0[0],
    original,
    [@lib.ValType::i32()],
    propagate_parameter_aliases=true,
  )
  let @lib.Func(locals, _) = out
  assert_eq(locals.length(), 0)
  assert_eq(indices, [0, -1])
  @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([out]))).unwrap()
}

///|
test "DAE2 local aliases forward GC references without recreating the object" {
  let input = pass_test_module_from_wat(
    "(module (type $s (struct (field i32))) (import \"env\" \"consume\" (func $consume (param (ref null $s)))) (func (local (ref null $s) (ref null $s)) i32.const 7 struct.new $s local.set 0 local.get 0 call $consume local.get 0 local.set 1 local.get 1 call $consume local.get 1 call $consume))",
  )
  let original = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
  let (out, indices) = pass_lower_compact_captures_with_map(
    input.code_sec.unwrap().0[0],
    original,
    [],
    propagate_parameter_aliases=true,
  )
  let @lib.Func(locals, @lib.Expr(body)) = out
  assert_eq(locals.length(), 1)
  assert_eq(indices, [0, -1])
  assert_eq(body.filter(fn(i) { i is @lib.StructNew(_) }).length(), 1)
  assert_eq(body.filter(fn(i) { i is @lib.Call(_) }).length(), 3)
  @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([out]))).unwrap()
}
