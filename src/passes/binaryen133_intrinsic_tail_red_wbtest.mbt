///|
test "Binaryen 133 intrinsic lowering preserves a direct return_call" {
  let output = binaryen133_run_new_pass(
    "(module (import \"binaryen-intrinsics\" \"call.without.effects\" (func $cwe (param funcref) (result i32))) (func $target (result i32) (i32.const 7)) (elem declare func $target) (func (export \"run\") (result i32) (return_call $cwe (ref.func $target))))",
    "intrinsic-lowering",
  )
  assert_eq(
    ca_test_opcode_count(
      output,
      @lib.Instruction::return_call(@lib.FuncIdx::new(1U)),
    ),
    1,
  )
}

///|
test "Binaryen 133 intrinsic lowering preserves a dynamic return_call_ref" {
  let output = binaryen133_run_new_pass(
    "(module (type $sig (func)) (import \"binaryen-intrinsics\" \"call.without.effects\" (func $cwe (param funcref))) (func (export \"run\") (param (ref null $sig)) (return_call $cwe (local.get 0))))",
    "intrinsic-lowering",
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_true(body.any(fn(instr) { instr is @lib.ReturnCallRef(_) }))
}
