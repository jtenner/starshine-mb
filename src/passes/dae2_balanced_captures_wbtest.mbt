///|
fn dae2_balanced_capture_fixture(type_ : String, between : String) -> String {
  "(module (import \"env\" \"produce\" (func $produce (result \{type_}))) (import \"env\" \"consume\" (func $consume (param i32))) (memory 1) (func (export \"run\") (result \{type_}) (local \{type_}) call $produce local.set 0 \{between} local.get 0))"
}

///|
test "dae2 final capture cleanup leaves produced values on stack across balanced calls" {
  for type_ in ["i32", "f64", "externref"] {
    let input = pass_test_module_from_wat(
      dae2_balanced_capture_fixture(type_, "i32.const 7 call $consume"),
    )
    let output = dae2_cleanup_captures(input)
    assert_true(@validate.validate_module(output) is Ok(_))
    let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    assert_eq(locals.length(), 0)
    assert_eq(body, [
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::i32_const(@lib.I32(7)),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    ])
  }
}

///|
test "dae2 optimizing dispatch removes balanced captures without moving trapping loads" {
  let source = dae2_balanced_capture_fixture(
    "i32", "i32.const 65536 i32.load drop i32.const 7 call $consume",
  )
  let output = dae2_test_run(source, "dae2-optimizing")
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 0)
  assert_true(body.any(fn(instr) { instr is @lib.I32Load(_) }))
  assert_eq(body.filter(fn(instr) { instr is @lib.Call(_) }).length(), 2)
}

///|
test "balanced capture cleanup intentionally retains capture when a call consumes an earlier stack value" {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"produce\" (func $produce (result i32))) (import \"env\" \"consume\" (func $consume (param i32))) (func (export \"run\") (result i32) (local i32) i32.const 10 call $produce local.set 0 call $consume local.get 0))",
  )
  let output = dae2_cleanup_captures(input)
  assert_true(@validate.validate_module(output) is Ok(_))
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 1)
  assert_true(body.any(fn(instr) { instr is @lib.LocalSet(_) }))
}

///|
test "dae2 balanced captures resolve indirect reference and multivalue call effects" {
  for
    (declarations, between) in [
      (
        "(type $sink (func (param i32))) (table 1 funcref)", "i32.const 7 i32.const 0 call_indirect (type $sink)",
      ),
      (
        "(type $sink (func (param i32))) (elem declare func $consume)", "i32.const 7 ref.func $consume call_ref $sink",
      ),
      (
        "(import \"env\" \"pair\" (func $pair (result i32 i64)))", "call $pair drop drop",
      ),
    ] {
    let input = pass_test_module_from_wat(
      "(module \{declarations} (import \"env\" \"produce\" (func $produce (result i32))) (import \"env\" \"consume\" (func $consume (param i32))) (func (export \"run\") (result i32) (local i32) call $produce local.set 0 \{between} local.get 0))",
    )
    let original = dae2_balanced_capture_reference_cleanup(input)
    let @lib.Func(original_locals, _) = original.code_sec.unwrap().0[0]
    assert_eq(original_locals.length(), 1)
    let output = dae2_cleanup_captures(input)
    assert_true(@validate.validate_module(output) is Ok(_))
    let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    assert_eq(locals.length(), 0)
    assert_false(
      body.any(fn(instr) {
        instr is @lib.LocalSet(_) || instr is @lib.LocalGet(_)
      }),
    )
  }
}

///|
test "balanced capture cleanup intentionally retains branch intervals and repeated reads" {
  for
    body in [
      "block call $produce local.set 0 i32.const 0 br_if 0 end local.get 0", "call $produce local.set 0 local.get 0 local.get 0 i32.add",
    ] {
    let input = pass_test_module_from_wat(
      "(module (import \"env\" \"produce\" (func $produce (result i32))) (func (export \"run\") (result i32) (local i32) \{body}))",
    )
    let output = dae2_cleanup_captures(input)
    assert_true(@validate.validate_module(output) is Ok(_))
    let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
    assert_eq(locals.length(), 1)
  }
}

///|
test "balanced call cleanup preserves smaller existing plans for overlapping captures" {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"produce\" (func $produce (result i32))) (func (export \"run\") (result i32) (local i32 i32 i32) call $produce local.set 0 call $produce local.set 1 local.get 0 local.set 2 local.get 1 local.get 2 i32.add))",
  )
  let original = dae2_balanced_capture_reference_cleanup(input)
  let @lib.Func(original_locals, _) = original.code_sec.unwrap().0[0]
  assert_eq(original_locals.length(), 1)
  let output = dae2_cleanup_captures(input)
  assert_true(@validate.validate_module(output) is Ok(_))
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 1)
  assert_eq(body.filter(fn(instr) { instr is @lib.LocalSet(_) }).length(), 1)
  assert_eq(body.filter(fn(instr) { instr is @lib.LocalGet(_) }).length(), 1)
  assert_eq(body.filter(fn(instr) { instr is @lib.Call(_) }).length(), 2)
}
