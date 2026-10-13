///|
fn binaryen133_check_sat_lowering(
  source : String,
  opcode : @lib.Instruction,
) -> Unit raise {
  let output = match
    pass_test_run_pipeline(source, [
      "flatten", "lower-saturating-i64-truncations",
    ]) {
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

///|
test "whole i64 lowering remains a boundary while saturating conversion lowering is active" {
  @debug.assert_eq(
    pass_registry_category("i64-to-i32-lowering"),
    Some(HotPassRegistryCategory::boundary_only()),
  )
  @debug.assert_eq(
    pass_registry_category("lower-saturating-i64-truncations"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  let source = "(module (func (param i64) (result i64) local.get 0 i64.const 1 i64.add))"
  match pass_test_run_pipeline(source, ["i64-to-i32-lowering"]) {
    Err(message) => assert_true(message.contains("boundary-only"))
    Ok(_) => fail("whole i64 lowering must not silently accept i64 arithmetic")
  }
  let input = pass_test_module_from_wat(source)
  let subset = pass_test_run_pipeline(source, [
    "lower-saturating-i64-truncations",
  ]).unwrap()
  @debug.assert_eq(subset.type_sec, input.type_sec)
  @debug.assert_eq(subset.code_sec, input.code_sec)
}
