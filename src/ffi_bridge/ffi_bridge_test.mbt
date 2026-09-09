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
  assert_true(first.outcome_kind_byte_length() > 0U)
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
test "ffi bridge carries deterministic cross-instance support bytes" {
  let root_seed = 0xC2055UL
  let mut case_index = 0
  for index in 1..<=136 {
    if @validate.gen_valid_profile_name(
        @validate.gen_valid_profile_leaf_for_case(
          @validate.gen_valid_engine_state_profile(),
          root_seed,
          index,
        ),
      ) ==
      "engine-state-cross-instance" {
      case_index = index
      break
    }
  }
  assert_true(case_index > 0)
  let first = generate_engine_state_case(root_seed, case_index)
  let second = generate_engine_state_case(root_seed, case_index)
  assert_true(first.is_ok())
  assert_true(first.support_module_byte_length() > 0U)
  assert_eq(
    first.support_module_byte_length(),
    second.support_module_byte_length(),
  )
  let output = Buffer(
    size_hint=first.support_module_byte_length().reinterpret_as_int(),
  )
  for index in 0..<first.support_module_byte_length().reinterpret_as_int() {
    let offset = index.reinterpret_as_uint()
    assert_eq(
      first.support_module_byte_at(offset),
      second.support_module_byte_at(offset),
    )
    output.write_byte(first.support_module_byte_at(offset))
  }
  match @binary.decode_module(output.to_bytes()) {
    Ok(decoded) => assert_true(@validate.validate_module(decoded) is Ok(_))
    Err(error) => fail("expected support module to decode: \{error}")
  }
}

///|
fn ffi_test_engine_state_case_index(
  root_seed : UInt64,
  profile_name : String,
) -> Int {
  for index in 1..<=136 {
    if @validate.gen_valid_profile_name(
        @validate.gen_valid_profile_leaf_for_case(
          @validate.gen_valid_engine_state_profile(),
          root_seed,
          index,
        ),
      ) ==
      profile_name {
      return index
    }
  }
  0
}

///|
test "ffi bridge carries an ordered deterministic link graph" {
  let root_seed = 0x11A6UL
  let case_index = ffi_test_engine_state_case_index(
    root_seed, "engine-state-link-graph",
  )
  assert_true(case_index > 0)
  let first = generate_engine_state_case(root_seed, case_index)
  let second = generate_engine_state_case(root_seed, case_index)
  assert_true(first.is_ok())
  assert_true(first.support_module_count() >= 1U)
  assert_true(first.support_module_count() <= 3U)
  assert_eq(first.support_module_count(), second.support_module_count())
  assert_eq(
    first.support_module_byte_length(),
    first.support_module_indexed_byte_length(0U),
  )
  for module_index in 0..<first.support_module_count().reinterpret_as_int() {
    let module_offset = module_index.reinterpret_as_uint()
    let length = first.support_module_indexed_byte_length(module_offset)
    assert_true(length > 0U)
    assert_eq(length, second.support_module_indexed_byte_length(module_offset))
    let output = Buffer(size_hint=length.reinterpret_as_int())
    for byte_index in 0..<length.reinterpret_as_int() {
      let byte_offset = byte_index.reinterpret_as_uint()
      assert_eq(
        first.support_module_indexed_byte_at(module_offset, byte_offset),
        second.support_module_indexed_byte_at(module_offset, byte_offset),
      )
      output.write_byte(
        first.support_module_indexed_byte_at(module_offset, byte_offset),
      )
    }
    match @binary.decode_module(output.to_bytes()) {
      Ok(decoded) => assert_true(@validate.validate_module(decoded) is Ok(_))
      Err(error) => fail("expected link support module to decode: \{error}")
    }
  }
}

///|
test "ffi bridge carries a distinct valid metamorphic companion" {
  let root_seed = 0x7A11UL
  let case_index = ffi_test_engine_state_case_index(
    root_seed, "engine-state-metamorphic-twins",
  )
  assert_true(case_index > 0)
  let generated = generate_engine_state_case(root_seed, case_index)
  assert_true(generated.is_ok())
  assert_true(generated.comparison_module_byte_length() > 0U)
  let output = Buffer(
    size_hint=generated.comparison_module_byte_length().reinterpret_as_int(),
  )
  let mut differs = generated.module_byte_length() !=
    generated.comparison_module_byte_length()
  for
    index in 0..<generated.comparison_module_byte_length().reinterpret_as_int() {
    let offset = index.reinterpret_as_uint()
    let byte = generated.comparison_module_byte_at(offset)
    output.write_byte(byte)
    if !differs && byte != generated.module_byte_at(offset) {
      differs = true
    }
  }
  assert_true(differs)
  match @binary.decode_module(output.to_bytes()) {
    Ok(decoded) =>
      match @validate.validate_module(decoded) {
        Ok(_) => ()
        Err(error) =>
          fail(
            "expected decoded metamorphic companion to validate: \{@validate.validation_error_message(error)}",
          )
      }
    Err(error) => fail("expected metamorphic companion to decode: \{error}")
  }
}

///|
test "ffi bridge emits deterministic malformed bytes for invalid profile" {
  let root_seed = 0xBADUL
  let case_index = ffi_test_engine_state_case_index(
    root_seed, "engine-state-invalid-module",
  )
  assert_true(case_index > 0)
  let generated = generate_engine_state_case(root_seed, case_index)
  assert_true(generated.is_ok())
  assert_true(generated.expects_trap())
  let output = Buffer(
    size_hint=generated.module_byte_length().reinterpret_as_int(),
  )
  for index in 0..<generated.module_byte_length().reinterpret_as_int() {
    output.write_byte(generated.module_byte_at(index.reinterpret_as_uint()))
  }
  match @binary.decode_module(output.to_bytes()) {
    Ok(_) => fail("expected invalid engine-state profile bytes to be malformed")
    Err(_) => ()
  }
}

///|
test "ffi bridge rejects non-positive engine-state case indexes" {
  let generated = generate_engine_state_case(0x5eedUL, 0)
  assert_false(generated.is_ok())
  assert_eq(generated.module_byte_length(), 0U)
  assert_true(generated.error_byte_length() > 0U)
}
