///|
fn binaryen133_run_publish(source : String) -> @lib.Module raise {
  let input = match @wast.wast_to_binary_module(source) {
    Ok(input) => input
    Err(err) => fail("Binaryen 133 publish input is not represented: \{err}")
  }
  let output = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]) {
    Ok(output) => output
    Err(err) => fail("Binaryen 133 publish optimization failed: \{err}")
  }
  match @validate.validate_module(output) {
    Ok(_) => output
    Err(err) => fail("Binaryen 133 publish output is invalid: \{err}")
  }
}

///|
test "Binaryen 133 removes publish around a fresh shared struct" {
  let output = binaryen133_run_publish(
    "(module (type $s (shared (struct (field (mut i32))))) (func (result (ref $s)) (publish (struct.new $s (i32.const 1)))))",
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(body.length(), 2)
  assert_true(body[1] is @lib.StructNew(_))
}

///|
test "Binaryen 133 removes publish around struct.new_default" {
  let output = binaryen133_run_publish(
    "(module (type $s (shared (struct (field (mut i32))))) (func (result (ref $s)) (publish (struct.new_default $s))))",
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(body.length(), 1)
  assert_true(body[0] is @lib.StructNewDefault(_))
}

///|
test "Binaryen 133 removes publish around array.new" {
  let output = binaryen133_run_publish(
    "(module (type $a (shared (array (mut i32)))) (func (result (ref $a)) (publish (array.new $a (i32.const 1) (i32.const 2)))))",
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_true(body.any(fn(instr) { instr is @lib.ArrayNew(_) }))
  assert_eq(body.length(), 3)
}

///|
test "Binaryen 133 removes publish around array.new_default" {
  let output = binaryen133_run_publish(
    "(module (type $a (shared (array (mut i32)))) (func (result (ref $a)) (publish (array.new_default $a (i32.const 2)))))",
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_true(body.any(fn(instr) { instr is @lib.ArrayNewDefault(_) }))
  assert_eq(body.length(), 2)
}

///|
test "Binaryen 133 removes publish around array.new_fixed" {
  let output = binaryen133_run_publish(
    "(module (type $a (shared (array (mut i32)))) (func (result (ref $a)) (publish (array.new_fixed $a 2 (i32.const 1) (i32.const 2)))))",
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_true(body.any(fn(instr) { instr is @lib.ArrayNewFixed(_, _) }))
  assert_eq(body.length(), 3)
}

///|
test "Binaryen 133 removes publish around array.new_data" {
  let output = binaryen133_run_publish(
    "(module (type $a (shared (array (mut i8)))) (data $d \"hello\") (func (result (ref $a)) (publish (array.new_data $a $d (i32.const 0) (i32.const 1)))))",
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_true(body.any(fn(instr) { instr is @lib.ArrayNewData(_, _) }))
  assert_eq(body.length(), 3)
}

///|
test "Binaryen 133 removes publish around array.new_elem" {
  let output = binaryen133_run_publish(
    "(module (type $a (shared (array (mut (ref null (shared func)))))) (elem $e (ref null (shared func))) (func (result (ref $a)) (publish (array.new_elem $a $e (i32.const 0) (i32.const 1)))))",
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_true(body.any(fn(instr) { instr is @lib.ArrayNewElem(_, _) }))
  assert_eq(body.length(), 3)
}

///|
test "Binaryen 133 removes the outer publish from nested publish" {
  let output = binaryen133_run_publish(
    "(module (type $s (shared (struct (field (mut i32))))) (func (param (ref $s)) (result (ref $s)) (publish (publish (local.get 0)))))",
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(body.length(), 2)
  assert_true(body[0] is @lib.LocalGet(_))
}

///|
test "Binaryen 133 removes publish through a transparent block" {
  let output = binaryen133_run_publish(
    "(module (type $s (shared (struct (field (mut i32))))) (func (result (ref $s)) (publish (block (result (ref $s)) (nop) (struct.new $s (i32.const 1))))))",
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(body.length(), 2)
  assert_true(body[1] is @lib.StructNew(_))
}

///|
test "Binaryen 133 removes publish through ref.as_non_null" {
  let output = binaryen133_run_publish(
    "(module (type $s (shared (struct (field (mut i32))))) (func (result (ref $s)) (publish (ref.as_non_null (struct.new $s (i32.const 1))))))",
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_true(body.any(fn(instr) { instr is @lib.StructNew(_) }))
  assert_eq(body.length(), 2)
}

///|
test "Binaryen 133 removes publish of an unshared struct" {
  let output = binaryen133_run_publish(
    "(module (type $s (struct (field (mut i32)))) (func (param (ref $s)) (result (ref $s)) (publish (local.get 0))))",
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(body.length(), 1)
  assert_true(body[0] is @lib.LocalGet(_))
}

///|
test "Binaryen 133 removes outer publish across a block around inner publish" {
  let output = binaryen133_run_publish(
    "(module (type $s (shared (struct (field (mut i32))))) (func (param (ref $s)) (result (ref $s)) (publish (block (result (ref $s)) (nop) (publish (local.get 0))))))",
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(body.length(), 2)
  assert_true(body[0] is @lib.LocalGet(_))
}
