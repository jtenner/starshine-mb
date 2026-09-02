///|
test "ffi bridge constructs and encodes one i32 function module" {
  let parameters = val_types_new()
  let results = val_types_new()
  val_types_push(results, @lib.ValType::i32())
  let rec_types = rec_types_new()
  rec_types_push(
    rec_types,
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func(parameters, results)),
    ),
  )
  let type_indices = type_indices_new()
  type_indices_push(type_indices, @lib.TypeIdx::new(0U))
  let instructions = instructions_new()
  instructions_push(
    instructions,
    @lib.Instruction::i32_const(@lib.I32::new(42)),
  )
  let functions = funcs_new()
  funcs_push(
    functions,
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(instructions)),
  )
  let module_ = module_new()
    .with_type_sec(@lib.TypeSec::new(rec_types))
    .with_func_sec(@lib.FuncSec::new(type_indices))
    .with_code_sec(@lib.CodeSec::new(functions))
  assert_true(validate_module(module_))
  let encoded = encode_module(module_)
  assert_true(encoded.is_ok())
  let output = Buffer(size_hint=encoded.byte_length().reinterpret_as_int())
  for index in 0..<encoded.byte_length().reinterpret_as_int() {
    output.write_byte(encoded.byte_at(index.reinterpret_as_uint()))
  }
  match @binary.decode_module(output.to_bytes()) {
    Ok(decoded) => assert_true(@validate.validate_module(decoded) is Ok(_))
    Err(error) => fail("expected encoded bridge module to decode: \{error}")
  }
}

///|
test "ffi bridge generates deterministic engine-state case bytes" {
  let root_seed = 0x5eedUL
  let case_index = 1
  let first = generate_engine_state_case(root_seed, case_index)
  let second = generate_engine_state_case(root_seed, case_index)
  assert_true(first.is_ok())
  assert_true(second.is_ok())
  assert_eq(first.case_index(), case_index)
  assert_eq(
    first.case_seed(),
    @validate.gen_valid_case_seed(root_seed, case_index),
  )
  assert_eq(first.module_byte_length(), second.module_byte_length())
  assert_true(first.selected_profile_byte_length() > 0U)
  assert_true(first.static_instruction_count() > 0)
  assert_true(first.generator_attempts() > 0)
  for index in 0..<first.module_byte_length().reinterpret_as_int() {
    let offset = index.reinterpret_as_uint()
    assert_eq(first.module_byte_at(offset), second.module_byte_at(offset))
  }
  let leaf = @validate.gen_valid_profile_leaf_for_case(
    @validate.gen_valid_engine_state_profile(),
    root_seed,
    case_index,
  )
  let direct = match
    @validate.gen_valid_module_result_from_seed(
      first.case_seed(),
      @validate.GenValidConfig::for_profile(leaf),
    ) {
    Ok(generated) => encode_module(generated.wasm_module)
    Err(error) =>
      fail(
        "expected direct engine-state generation after \{error.attempts} attempts: \{error.validation_error_message}",
      )
  }
  assert_true(direct.is_ok())
  assert_eq(first.module_byte_length(), direct.byte_length())
  for index in 0..<first.module_byte_length().reinterpret_as_int() {
    let offset = index.reinterpret_as_uint()
    assert_eq(first.module_byte_at(offset), direct.byte_at(offset))
  }
  let output = Buffer(size_hint=first.module_byte_length().reinterpret_as_int())
  for index in 0..<first.module_byte_length().reinterpret_as_int() {
    output.write_byte(first.module_byte_at(index.reinterpret_as_uint()))
  }
  match @binary.decode_module(output.to_bytes()) {
    Ok(decoded) => assert_true(@validate.validate_module(decoded) is Ok(_))
    Err(error) =>
      fail("expected generated engine-state case to decode: \{error}")
  }
}

///|
test "ffi bridge rejects non-positive engine-state case indexes" {
  let generated = generate_engine_state_case(0x5eedUL, 0)
  assert_false(generated.is_ok())
  assert_eq(generated.module_byte_length(), 0U)
  assert_true(generated.error_byte_length() > 0U)
}
