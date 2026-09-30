///|
test "dae2 final cleanup exposes captures through nested scalar forwarding blocks" {
  for type_ in ["i32", "f64", "externref"] {
    let input = pass_test_module_from_wat(
      "(module (import \"env\" \"produce\" (func $produce (result \{type_}))) (import \"env\" \"consume\" (func $consume (param i32))) (func (export \"run\") (result \{type_}) (local \{type_}) block (result \{type_}) call $produce end local.set 0 i32.const 7 call $consume block (result \{type_}) block (result \{type_}) local.get 0 end end))",
    )
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let output = dae2_cleanup_captures(input)
    @validate.validate_module(output).unwrap()
    let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    assert_eq(locals.length(), 0)
    assert_eq(body, [
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::i32_const(@lib.I32(7)),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    ])
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "dae2 optimizing cleanup preserves trapping producers while removing scalar wrappers" {
  let output = dae2_test_run(
    "(module (import \"env\" \"consume\" (func $consume (param i32))) (memory 1) (func (export \"run\") (result i32) (local i32) block (result i32) i32.const 65536 i32.load end local.set 0 i32.const 7 call $consume block (result i32) local.get 0 end))",
    "dae2-optimizing",
  )
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 0)
  assert_false(body.any(fn(instr) { instr is @lib.Block(_, _) }))
  assert_eq(body.filter(fn(instr) { instr is @lib.I32Load(_) }).length(), 1)
  assert_eq(body.filter(fn(instr) { instr is @lib.Call(_) }).length(), 1)
}

///|
test "dae2 scalar wrapper cleanup intentionally retains branch targets and block inputs" {
  for
    source in [
      "(module (func (export \"run\") (result i32) block (result i32) i32.const 7 br 0 end))",
      "(module (type $sig (func (param i32) (result i32))) (func (export \"run\") (param i32) (result i32) local.get 0 block (type $sig) i32.const 7 i32.add end))",
    ] {
    let input = pass_test_module_from_wat(source)
    @validate.validate_module(input).unwrap()
    let output = dae2_cleanup_captures(input)
    @validate.validate_module(output).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    assert_true(body.any(fn(instr) { instr is @lib.Block(_, _) }))
  }
}

///|
test "dae2 final cleanup forwards a nonnullable GC result through scalar blocks" {
  let input = pass_test_module_from_wat(
    "(module (type $s (struct (field i32))) (import \"env\" \"produce\" (func $produce (result (ref $s)))) (import \"env\" \"consume\" (func $consume (param i32))) (func (export \"run\") (result (ref $s)) (local (ref $s)) block (result (ref $s)) call $produce end local.set 0 i32.const 7 call $consume block (result (ref $s)) local.get 0 end))",
  )
  @validate.validate_module(input).unwrap()
  let output = dae2_cleanup_captures(input)
  @validate.validate_module(output).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 0)
  assert_eq(body, [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
  ])
}
