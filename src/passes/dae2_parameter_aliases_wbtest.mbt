///|
test "dae2 final cleanup replaces dominated immutable parameter aliases with repeated reads" {
  for type_ in ["i32", "f64", "externref"] {
    let input = pass_test_module_from_wat(
      "(module (import \"env\" \"consume\" (func $consume (param \{type_}))) (func (export \"run\") (param \{type_}) (result \{type_}) (local \{type_}) local.get 0 local.set 1 local.get 1 call $consume local.get 1 call $consume local.get 1))",
    )
    let saved = @binary.encode_module(input).unwrap()
    let output = dae2_cleanup_captures(input)
    @validate.validate_module(output).unwrap()
    let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    assert_eq(locals.length(), 0)
    assert_eq(body, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    ])
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "dae2 immutable alias cleanup preserves default reads outside the defining branch" {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"consume\" (func $consume (param i32))) (func (export \"run\") (param i32 i32) (result i32) (local i32) local.get 0 if local.get 1 local.set 2 local.get 2 call $consume local.get 2 call $consume end local.get 2))",
  )
  let output = dae2_cleanup_captures(input)
  @validate.validate_module(output).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 1)
  assert_eq(
    body.last(),
    Some(@lib.Instruction::local_get(@lib.LocalIdx::new(2U))),
  )
  let then_ = match body[1] {
    @lib.If(_, then_, _) => then_
    _ => fail("missing branch")
  }
  assert_eq(
    then_
    .filter(fn(instr) {
      instr == @lib.Instruction::local_get(@lib.LocalIdx::new(2U))
    })
    .length(),
    0,
  )
  assert_eq(
    then_
    .filter(fn(instr) {
      instr == @lib.Instruction::local_get(@lib.LocalIdx::new(1U))
    })
    .length(),
    3,
  )
}

///|
test "dae2 parameter alias cleanup intentionally retains snapshots of written parameters" {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"consume\" (func $consume (param i32))) (func (export \"run\") (param i32) (result i32) (local i32) local.get 0 local.set 1 i32.const 9 local.set 0 local.get 1 call $consume local.get 1))",
  )
  let output = dae2_cleanup_captures(input)
  @validate.validate_module(output).unwrap()
  let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 1)
}

///|
test "dae2 immutable aliases propagate through nested scopes and chains without escaping" {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"consume\" (func $consume (param i32))) (func (export \"run\") (param i32) (result i32) (local i32 i32) local.get 0 local.set 1 loop local.get 1 local.set 2 local.get 2 call $consume local.get 2 call $consume i32.const 0 br_if 0 end local.get 1))",
  )
  let output = dae2_cleanup_captures(input)
  @validate.validate_module(output).unwrap()
  let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 0)
}

///|
test "dae2 immutable alias cleanup forwards refined GC references" {
  let input = pass_test_module_from_wat(
    "(module (type $s (struct (field i32))) (import \"env\" \"consume\" (func $consume (param (ref null $s)))) (func (export \"run\") (param (ref $s)) (result (ref null $s)) (local (ref null $s)) local.get 0 local.set 1 local.get 1 call $consume local.get 1))",
  )
  @validate.validate_module(input).unwrap()
  let output = dae2_cleanup_captures(input)
  @validate.validate_module(output).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 0)
  assert_eq(body, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
}

///|
test "dae2 alias cleanup preserves first-iteration reads and isolates sibling branches" {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"consume\" (func $consume (param i32))) (func (export \"run\") (param i32 i32) (result i32) (local i32) loop local.get 2 call $consume local.get 0 if local.get 1 local.set 2 local.get 2 call $consume local.get 2 call $consume else local.get 2 call $consume end i32.const 0 br_if 0 end local.get 2))",
  )
  let output = dae2_cleanup_captures(input)
  @validate.validate_module(output).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 1)
  let loop_body = match body[0] {
    @lib.Loop(_, @lib.Expr(body)) => body
    _ => fail("missing loop")
  }
  assert_eq(loop_body[0], @lib.Instruction::local_get(@lib.LocalIdx::new(2U)))
  let (yes, no) = match loop_body[3] {
    @lib.If(_, yes, Some(no)) => (yes, no)
    _ => fail("missing branches")
  }
  assert_eq(
    yes.filter(fn(i) { i is @lib.LocalGet(@lib.LocalIdx(2U)) }).length(),
    0,
  )
  assert_eq(no[0], @lib.Instruction::local_get(@lib.LocalIdx::new(2U)))
  assert_eq(
    body.last(),
    Some(@lib.Instruction::local_get(@lib.LocalIdx::new(2U))),
  )
}

///|
test "dae2 parameter alias removal preserves parameter names and remaps surviving locals" {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"consume\" (func $consume (param i32))) (func (export \"run\") (param i32) (result i32) (local i32 i32) local.get 0 local.set 1 local.get 1 call $consume local.get 1 call $consume i32.const 7 local.set 2 local.get 2 call $consume local.get 2))",
  )
  let name = fn(index, text) {
    @lib.NameAssoc::new(index, @lib.Name::from_string(text))
  }
  let input = input.with_name_sec(
    @lib.NameSec::new(
      local_names=Some(
        @lib.IndirectNameMap::new([
          @lib.IndirectNameAssoc::new(
            1U,
            @lib.NameMap::new([
              name(0U, "param"),
              name(1U, "alias"),
              name(2U, "retained"),
            ]),
          ),
        ]),
      ),
    ),
  )
  let output = dae2_cleanup_captures(input)
  @validate.validate_module(output).unwrap()
  let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 1)
  assert_eq(
    output.name_sec.unwrap().local_names,
    Some(
      @lib.IndirectNameMap::new([
        @lib.IndirectNameAssoc::new(
          1U,
          @lib.NameMap::new([name(0U, "param"), name(1U, "retained")]),
        ),
      ]),
    ),
  )
}

///|
test "dae2 alias cleanup intentionally retains default reads in handlers and after throws" {
  let input = pass_test_module_from_wat(
    "(module (tag $t) (import \"env\" \"consume\" (func $consume (param i32))) (func (export \"run\") (param i32) (result i32) (local i32) (try (do (throw $t) (local.set 1 (local.get 0)) (call $consume (local.get 1)) (call $consume (local.get 1))) (catch $t (call $consume (local.get 1)))) local.get 1))",
  )
  @validate.validate_module(input).unwrap()
  let output = dae2_cleanup_captures(input)
  @validate.validate_module(output).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 1)
  let caught = match body[0] {
    @lib.Try(_, _, catches, _) =>
      match catches[0] {
        @lib.LegacyCatch(_, @lib.Expr(caught)) => caught
        _ => fail("missing tagged catch")
      }
    _ => fail("missing try")
  }
  assert_eq(caught[0], @lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
  assert_eq(
    body.last(),
    Some(@lib.Instruction::local_get(@lib.LocalIdx::new(1U))),
  )
}

///|
test "dae2 parameter alias cleanup intentionally retains locals with multiple writes" {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"consume\" (func $consume (param i32))) (func (export \"run\") (param i32) (result i32) (local i32) local.get 0 local.set 1 local.get 1 call $consume i32.const 9 local.set 1 local.get 1 call $consume local.get 1))",
  )
  let output = dae2_cleanup_captures(input)
  @validate.validate_module(output).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 1)
  assert_eq(
    body.filter(fn(i) { i is @lib.LocalSet(@lib.LocalIdx(1U)) }).length(),
    2,
  )
  assert_eq(
    body.filter(fn(i) { i is @lib.LocalGet(@lib.LocalIdx(1U)) }).length(),
    3,
  )
}

///|
test "dae2 immutable parameter aliases remove tee writes without removing their consumed value" {
  for type_ in ["i32", "f64", "externref"] {
    let input = pass_test_module_from_wat(
      "(module (import \"env\" \"consume\" (func $consume (param \{type_}))) (func (export \"run\") (param \{type_}) (result \{type_}) (local \{type_}) local.get 0 local.tee 1 call $consume local.get 1 call $consume local.get 1))",
    )
    let output = dae2_cleanup_captures(input)
    @validate.validate_module(output).unwrap()
    let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    assert_eq(locals.length(), 0)
    assert_eq(body, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    ])
  }
}

///|
test "dae2 immutable alias cleanup preserves the smaller existing overlapping stack capture plan" {
  let input = pass_test_module_from_wat(
    "(module (func (export \"run\") (param i32) (result i32) (local i32 i32) local.get 0 local.set 1 i32.const 32 i32.ctz local.set 2 local.get 1 local.get 2 i32.add))",
  )
  let output = dae2_cleanup_captures(input)
  @validate.validate_module(output).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 0)
  assert_eq(body, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(32)),
    @lib.Instruction::i32_ctz(),
    @lib.Instruction::i32_add(),
  ])
}
