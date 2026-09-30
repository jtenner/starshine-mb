///|
fn reverse_alias_compact(input : @lib.Module) -> (@lib.Func, Array[Int]) raise {
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let result = pass_lower_compact_captures_with_map(
    input.code_sec.unwrap().0[0],
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
    [],
    propagate_parameter_aliases=true,
  )
  @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([result.0]))).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  result
}

///|
test "DAE2 reverse short-index aliases remove dominated scalar and reference copies" {
  for ty in ["i32", "i64", "f64", "externref"] {
    let input = local_alias_fixture(
      "call $produce local.set 1 local.get 1 call $consume local.get 1 local.set 0 local.get 0 call $consume local.get 0 call $consume",
      ty,
    )
    let (out, indices) = reverse_alias_compact(input)
    let @lib.Func(locals, @lib.Expr(body)) = out
    assert_eq(locals.length(), 1)
    assert_eq(indices, [-1, 0])
    assert_eq(body, [
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    ])
  }
}

///|
test "DAE2 reverse short-index aliases retain earlier defaults and forward later reads" {
  for ty in ["i32", "i64", "externref"] {
    let input = local_alias_fixture(
      "local.get 0 call $consume call $produce local.set 1 local.get 1 call $consume local.get 1 local.set 0 local.get 0 call $consume local.get 0 call $consume",
      ty,
    )
    let (out, indices) = reverse_alias_compact(input)
    let @lib.Func(locals, @lib.Expr(body)) = out
    assert_eq(locals.length(), 2)
    assert_eq(indices, [0, 1])
    assert_eq(
      body.filter(fn(i) { i is @lib.LocalGet(@lib.LocalIdx(0U)) }).length(),
      1,
    )
    assert_eq(
      body.filter(fn(i) { i is @lib.LocalGet(@lib.LocalIdx(1U)) }).length(),
      4,
    )
  }
}

///|
test "DAE2 reverse short-index defaults and tee chains resolve to nonalias roots" {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"produce\" (func $produce (result i32))) (import \"env\" \"consume\" (func $consume (param i32))) (func (local i32 i32 i32 i32) call $produce local.set 3 local.get 3 call $consume local.get 3 local.tee 1 call $consume local.get 1 local.set 2 local.get 2 local.tee 0 call $consume local.get 0 call $consume local.get 2 call $consume local.get 1 call $consume))",
  )
  let (out, indices) = reverse_alias_compact(input)
  let @lib.Func(locals, @lib.Expr(body)) = out
  assert_eq(locals.length(), 1)
  assert_eq(indices, [-1, -1, -1, 0])
  assert_eq(body.filter(fn(i) { i is @lib.LocalTee(_) }).length(), 0)
  assert_eq(body.filter(fn(i) { i is @lib.Call(@lib.FuncIdx(0U)) }).length(), 1)
  assert_eq(body.filter(fn(i) { i is @lib.Call(@lib.FuncIdx(1U)) }).length(), 6)
  let @lib.Func(_, @lib.Expr(original)) = input.code_sec.unwrap().0[0]
  let reads = Array::make(4, 0)
  let writes = Array::make(4, 0)
  pass_lower_count_locals(original, reads, writes)
  let (_, targets) = dae2_cleanup_parameter_aliases(original, 0, reads, writes)
  let targets = targets.unwrap()
  assert_eq(targets, [7L, 7L, 6L, -1L])
  for target in targets {
    if target >= 0L {
      assert_eq(targets[(target >> 1).to_int()], -1L)
    }
  }
  for ty in ["i32", "externref"] {
    let input = local_alias_fixture(
      "local.get 1 local.set 0 local.get 0 call $consume local.get 0 call $consume",
      ty,
    )
    let (out, indices) = reverse_alias_compact(input)
    let @lib.Func(locals, _) = out
    assert_eq(locals.length(), 1)
    assert_eq(indices, [-1, 0])
  }
}

///|
test "DAE2 reverse short-index aliases preserve GC object identity without reconstruction" {
  let input = pass_test_module_from_wat(
    "(module (type $s (struct (field i32))) (import \"env\" \"consume\" (func $consume (param (ref null $s)))) (func (local (ref null $s) (ref null $s)) i32.const 7 struct.new $s local.set 1 local.get 1 call $consume local.get 1 local.set 0 local.get 0 call $consume local.get 0 call $consume))",
  )
  let (out, indices) = reverse_alias_compact(input)
  let @lib.Func(locals, @lib.Expr(body)) = out
  assert_eq(locals.length(), 1)
  assert_eq(indices, [-1, 0])
  assert_eq(body.filter(fn(i) { i is @lib.StructNew(_) }).length(), 1)
  assert_eq(body.filter(fn(i) { i is @lib.Call(_) }).length(), 3)
}

///|
test "DAE2 reverse aliases intentionally retain future multiple and sibling source writes" {
  for
    body in [
      "local.get 1 local.set 0 call $produce local.set 1 local.get 1 call $consume local.get 0 call $consume local.get 0 call $consume",
      "call $produce local.set 1 local.get 1 call $consume local.get 1 local.set 0 call $produce local.set 1 local.get 1 call $consume local.get 0 call $consume local.get 0 call $consume",
      "i32.const 1 if call $produce local.set 1 local.get 1 call $consume else local.get 1 local.set 0 local.get 0 call $consume local.get 0 call $consume end",
      "loop local.get 1 local.set 0 call $produce local.set 1 local.get 1 call $consume local.get 0 call $consume local.get 0 call $consume i32.const 0 br_if 0 end",
    ] {
    let input = local_alias_fixture(body, "i32")
    let (out, indices) = reverse_alias_compact(input)
    let @lib.Func(locals, actual) = out
    let @lib.Func(_, expected) = input.code_sec.unwrap().0[0]
    assert_eq(locals.length(), 2)
    assert_eq(indices, [0, 1])
    assert_eq(actual, expected)
  }
}

///|
test "DAE2 reverse aliases preserve defaults in siblings and handlers" {
  for
    body in [
      "call $produce local.set 1 local.get 1 call $consume i32.const 1 if local.get 1 local.set 0 local.get 0 call $consume local.get 0 call $consume else local.get 0 call $consume end local.get 0 call $consume",
      "call $produce local.set 1 local.get 1 call $consume (try (do (local.get 1) (local.set 0) (local.get 0) (call $consume) (local.get 0) (call $consume)) (catch_all (local.get 0) (call $consume))) local.get 0 call $consume",
    ] {
    let input = local_alias_fixture(body, "i32")
    let (out, indices) = reverse_alias_compact(input)
    let @lib.Func(locals, @lib.Expr(actual)) = out
    assert_eq(locals.length(), 2)
    assert_eq(indices, [0, 1])
    assert_eq(
      actual.last(),
      Some(@lib.Instruction::call(@lib.FuncIdx::new(1U))),
    )
    assert_eq(
      actual[actual.length() - 2],
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    )
    let @lib.Func(_, @lib.Expr(original)) = input.code_sec.unwrap().0[0]
    let reads = [0, 0]
    let writes = [0, 0]
    pass_lower_count_locals(original, reads, writes)
    let (forwarded, _) = dae2_cleanup_parameter_aliases(
      original, 0, reads, writes,
    )
    assert_eq(reads[0], 2)
    assert_eq(reads[1], 4)
    assert_eq(forwarded, actual)
  }
}

///|
test "DAE2 reverse aliases preserve one-byte indices at 127 and reject potentially widening 128" {
  for source in [127, 128] {
    let locals = Array::make(source + 1, "i32").join(" ")
    let retained = Array::makei(source + 1, fn(i) {
      "local.get \{i} call $consume"
    }).join(" ")
    let input = pass_test_module_from_wat(
      "(module (import \"env\" \"produce\" (func $produce (result i32))) (import \"env\" \"consume\" (func $consume (param i32))) (func (local \{locals}) \{retained} call $produce local.set \{source} local.get \{source} local.set 0 local.get 0 call $consume local.get 0 call $consume))",
    )
    let (out, indices) = reverse_alias_compact(input)
    let @lib.Func(locals, @lib.Expr(body)) = out
    assert_eq(locals.length(), source + 1)
    assert_eq(indices[0], 0)
    let reads = body
      .filter(fn(i) { i is @lib.LocalGet(@lib.LocalIdx(0U)) })
      .length()
    assert_eq(reads, if source == 127 { 1 } else { 3 })
    assert_eq(
      body
      .filter(fn(i) {
        i == @lib.Instruction::local_get(@lib.LocalIdx::new(source.to_uint()))
      })
      .length(),
      if source == 127 {
        4
      } else {
        2
      },
    )
    let actual = @binary.encode_module(
      input.with_code_sec(@lib.CodeSec::new([out])),
    ).unwrap()
    assert_eq(actual.length(), @binary.encode_module(input).unwrap().length())
  }
  let input = local_alias_fixture(
    "call $produce local.set 1 local.get 1 local.set 1 local.get 1 call $consume local.get 1 call $consume local.get 0 call $consume",
    "i32",
  )
  let (out, _) = reverse_alias_compact(input)
  assert_eq(out, input.code_sec.unwrap().0[0])
}
