///|
fn binaryen133_check_sat_lowering(
  source : String,
  opcode : @lib.Instruction,
) -> Unit raise {
  let output = match
    pass_test_run_pipeline(source, ["flatten", "i64-to-i32-lowering"]) {
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
