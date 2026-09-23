///|
test "Binaryen 133 constraints use a span to rule out unsigned maximum" {
  let output = ca_test_run(
    "(module (func (export \"run\") (param i32 i32) (result i32) (if (result i32) (i32.lt_u (local.get 0) (local.get 1)) (then (i32.ne (local.get 0) (i32.const -1))) (else (i32.const 0)))))",
  )
  assert_eq(ca_test_opcode_count(output, @lib.Instruction::i32_ne()), 0)
}

///|
test "Binaryen 133 constraints derive a fact through a comparison tee" {
  let output = ca_test_run(
    "(module (func (export \"run\") (param i32 i32) (result i32) (local i32) (if (result i32) (i32.lt_u (local.tee 2 (local.get 0)) (local.get 1)) (then (i32.ne (local.get 2) (i32.const -1))) (else (i32.const 0)))))",
  )
  assert_eq(ca_test_opcode_count(output, @lib.Instruction::i32_ne()), 0)
}

///|
test "Binaryen 133 O3 preset schedules constraint analysis" {
  let passes = optimize_preset_passes(HotPipelineOptions::new(optimize_level=3))
  assert_true(passes.contains("constraint-analysis"))
}

///|
test "Binaryen 133 Os preset schedules constraint analysis" {
  let passes = shrink_preset_passes(HotPipelineOptions::new(shrink_level=1))
  assert_true(passes.contains("constraint-analysis"))
}

///|
test "Binaryen 133 constraints prove a variable-bound loop index stays nonnegative" {
  let output = ca_test_run(
    "(module (func (export \"run\") (param i32) (local i32) (block $out (loop $loop (if (i32.ge_s (local.get 1) (local.get 0)) (then (br $out))) (drop (i32.ge_s (local.get 1) (i32.const 0))) (local.set 1 (i32.add (local.get 1) (i32.const 1))) (br $loop)))))",
  )
  assert_eq(ca_test_opcode_count(output, @lib.Instruction::i32_ge_s()), 1)
}

///|
test "Binaryen 133 constraints track a local copy through block fallthrough" {
  let output = ca_test_run(
    "(module (func (export \"run\") (result i32) (local i32 i32 i32) (local.set 0 (block (result i32) (local.get 1))) (local.set 1 (i32.const 42)) (local.set 2 (block (result i32) (local.get 1))) (i32.eq (local.get 0) (local.get 2))))",
  )
  assert_eq(ca_test_opcode_count(output, @lib.Instruction::i32_eq()), 0)
}
