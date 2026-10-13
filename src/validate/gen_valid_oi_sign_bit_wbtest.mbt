///|
test "OI scalar profile emits sign-bit arithmetic and immediate tee reuse" {
  let body = gen_valid_oi_default_scalar_profile_body(0)
  assert_true(body.contains(Instruction::i32_div_u()))
  assert_true(body.contains(Instruction::i32_mul()))
  assert_true(body.contains(Instruction::i32_rem_u()))
  assert_true(body.contains(Instruction::i32_or()))
  @debug.assert_eq(
    body
    .filter(fn(instr) { instr == Instruction::i32_const(I32(-2147483648)) })
    .length(),
    3,
  )
  @debug.assert_eq(
    [
      body[body.length() - 5],
      body[body.length() - 4],
      body[body.length() - 3],
      body[body.length() - 2],
      body[body.length() - 1],
    ],
    [
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::local_tee(LocalIdx::new(0U)),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_or(),
      Instruction::drop(),
    ],
  )
  let generated = gen_valid_module_result_from_seed(
    0x5eedUL,
    GenValidConfig::for_profile(PassOiDefaultScalarProfile),
  ).unwrap()
  validate_module(generated.wasm_module).unwrap()
}
