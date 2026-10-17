///|
fn binaryen133_check_sat_lowering(
  source : String,
  opcode : @lib.Instruction,
) -> Unit raise {
  let output = match
    pass_test_run_pipeline(source, ["flatten", "i64-trunc-sat-float-lowering"]) {
    Ok(output) => output
    Err(err) => fail("Binaryen 133 saturating i64 lowering is missing: \{err}")
  }
  match @validate.validate_module(output) {
    Ok(_) => ()
    Err(err) => fail("Binaryen 133 saturating i64 lowering is invalid: \{err}")
  }
  assert_eq(ca_test_opcode_count(output, opcode), 0)
}

///|
fn binaryen133_check_full_i64_lowering_rejected(source : String) -> Unit raise {
  match pass_test_run_pipeline(source, ["i64-to-i32-lowering"]) {
    Ok(_) =>
      fail(
        "the canonical Binaryen pass name must not accept Starshine's saturating-conversion subset",
      )
    Err(err) => assert_true(err.contains("boundary-only"))
  }
}

///|
test "i64-to-i32-lowering rejects the unsupported function ABI contract" {
  binaryen133_check_full_i64_lowering_rejected(
    "(module (func (param i64) (drop (local.get 0))))",
  )
}

///|
test "i64-to-i32-lowering rejects the unsupported ordinary arithmetic contract" {
  binaryen133_check_full_i64_lowering_rejected(
    "(module (func (param i64 i64) (drop (i64.add (local.get 0) (local.get 1)))))",
  )
}

///|
test "Binaryen 133 lowers i64.trunc_sat_f32_s" {
  binaryen133_check_sat_lowering(
    "(module (func (param f32) (drop (i64.trunc_sat_f32_s (local.get 0)))))",
    @lib.Instruction::i64_trunc_sat_f32s(),
  )
}

///|
test "Binaryen 133 lowers i64.trunc_sat_f32_u" {
  binaryen133_check_sat_lowering(
    "(module (func (param f32) (drop (i64.trunc_sat_f32_u (local.get 0)))))",
    @lib.Instruction::i64_trunc_sat_f32u(),
  )
}

///|
test "Binaryen 133 lowers i64.trunc_sat_f64_s" {
  binaryen133_check_sat_lowering(
    "(module (func (param f64) (drop (i64.trunc_sat_f64_s (local.get 0)))))",
    @lib.Instruction::i64_trunc_sat_f64s(),
  )
}

///|
test "Binaryen 133 lowers i64.trunc_sat_f64_u" {
  binaryen133_check_sat_lowering(
    "(module (func (param f64) (drop (i64.trunc_sat_f64_u (local.get 0)))))",
    @lib.Instruction::i64_trunc_sat_f64u(),
  )
}

///|
test "saturating f32 lowering allocates only one f32 temporary" {
  let output = pass_test_run_pipeline(
    "(module (func (param f32) (drop (i64.trunc_sat_f32_s (local.get 0)))))",
    ["i64-trunc-sat-float-lowering"],
  ).unwrap()
  let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
  assert_eq(locals, @lib.Locals::from_types([@lib.ValType::f32()]))
}

///|
test "saturating f64 lowering allocates only one f64 temporary" {
  let output = pass_test_run_pipeline(
    "(module (func (param f64) (drop (i64.trunc_sat_f64_s (local.get 0)))))",
    ["i64-trunc-sat-float-lowering"],
  ).unwrap()
  let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
  assert_eq(locals, @lib.Locals::from_types([@lib.ValType::f64()]))
}
