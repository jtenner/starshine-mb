///|
test "Binaryen 133 keeps both generative atomic RMW results in a select" {
  let output = match
    pass_test_run_pipeline(
      "(module (memory 1 1 shared) (func (export \"run\") (result i32) (select (i32.atomic.rmw.add (i32.const 0) (i32.const 1)) (i32.atomic.rmw.add (i32.const 0) (i32.const 1)) (i32.const 1))))",
      ["optimize-instructions"],
    ) {
    Ok(output) => output
    Err(err) => fail("Binaryen 133 atomic RMW select failed: \{err}")
  }
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  let mut rmw_count = 0
  for instr in body {
    if instr is @lib.AtomicRmw(_, _, _) {
      rmw_count += 1
    }
  }
  assert_eq(rmw_count, 2)
}

///|
test "Binaryen 133 constraints prove the unsigned loop exit predicate false in the body" {
  let output = ca_test_run(
    "(module (func (export \"run\") (param i32) (local i32) (block $out (loop $loop (if (i32.ge_u (local.get 1) (local.get 0)) (then (br $out))) (drop (i32.lt_u (local.get 1) (local.get 0))) (local.set 1 (i32.add (local.get 1) (i32.const 1))) (br $loop)))))",
  )
  assert_eq(ca_test_opcode_count(output, @lib.Instruction::i32_lt_u()), 0)
}
