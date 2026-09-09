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

///|
test "ffi bridge rejects the removed compiler-owned Bytes read runtime" {
  // Bytes reads are ordinary Dew functions. This legacy operation is now
  // intentionally unsupported; no compiler-generated replacement may be added.
  let functions = funcs_new()
  let builder = runtime_function_builder_new(0)
  for byte in b"dew_wasi_fd_read" {
    builder.push_name_byte(byte)
  }
  assert_false(funcs_push_runtime(functions, builder))
  assert_eq(functions.length(), 0)
}

///|
test "ffi bridge rejects the removed compiler-owned Bytes write runtime" {
  // Bytes writes are ordinary Dew functions. This legacy operation is
  // intentionally unsupported; callers must use the foreign write declaration.
  let functions = funcs_new()
  let builder = runtime_function_builder_new(0)
  for byte in b"dew_wasi_fd_write" {
    builder.push_name_byte(byte)
  }
  assert_false(funcs_push_runtime(functions, builder))
  assert_eq(functions.length(), 0)
}

///|
test "ffi bridge rejects removed compiler-owned Bytes staging runtimes" {
  // The parity harness now supplies ordinary Dew staging functions. These
  // legacy operation names are intentionally outside the provider contract.
  for name in [b"dew_bench_wasi_stage_write", b"dew_bench_wasi_stage_read"] {
    let functions = funcs_new()
    let builder = runtime_function_builder_new(0)
    for byte in name {
      builder.push_name_byte(byte)
    }
    assert_false(funcs_push_runtime(functions, builder))
    assert_eq(functions.length(), 0)
  }
}

///|
test "ffi bridge rejects removed compiler-owned integer Debug runtimes" {
  // Integer formatting belongs to ordinary Dew functions, so these legacy
  // operations are intentionally unsupported by this object-model bridge.
  for
    name in [
      b"dew_debug_i8", b"dew_debug_i16", b"dew_debug_i32", b"dew_debug_i64", b"dew_debug_u8",
      b"dew_debug_u16", b"dew_debug_u32", b"dew_debug_u64",
    ] {
    let functions = funcs_new()
    let builder = runtime_function_builder_new(0)
    for byte in name {
      builder.push_name_byte(byte)
    }
    assert_false(funcs_push_runtime(functions, builder))
    assert_eq(functions.length(), 0)
  }
}

///|
test "ffi bridge rejects removed compiler-owned float Debug runtimes" {
  // Float bit formatting is an ordinary Dew algorithm. These old runtime
  // operations are intentionally unsupported, not fallback implementations.
  for name in [b"dew_debug_f32", b"dew_debug_f64"] {
    let functions = funcs_new()
    let builder = runtime_function_builder_new(0)
    for byte in name {
      builder.push_name_byte(byte)
    }
    assert_false(funcs_push_runtime(functions, builder))
    assert_eq(functions.length(), 0)
  }
}

///|
test "ffi bridge rejects removed compiler-owned String Debug runtime" {
  // String escaping belongs to Dew. This legacy operation is intentionally
  // outside the provider contract, not a fallback for a missing Dew function.
  let functions = funcs_new()
  let builder = runtime_function_builder_new(0)
  for byte in b"dew_debug_string" {
    builder.push_name_byte(byte)
  }
  assert_false(funcs_push_runtime(functions, builder))
  assert_eq(functions.length(), 0)
}

///|
test "ffi bridge rejects removed compiler-owned Bytes Debug runtime" {
  // Quoting and escaping Bytes belong to Dew. The old operation must not
  // retain an alternate formatter or a hidden host-write dependency.
  let functions = funcs_new()
  let builder = runtime_function_builder_new(0)
  for byte in b"dew_debug_bytes" {
    builder.push_name_byte(byte)
  }
  assert_false(funcs_push_runtime(functions, builder))
  assert_eq(functions.length(), 0)
}

///|
test "ffi bridge rejects removed compiler-owned V128 Debug runtime" {
  // V128 formatting is an ordinary Dew algorithm. The old operation is
  // intentionally unsupported; it must not survive as a fallback builder.
  let functions = funcs_new()
  let builder = runtime_function_builder_new(0)
  for byte in b"dew_debug_v128" {
    builder.push_name_byte(byte)
  }
  assert_false(funcs_push_runtime(functions, builder))
  assert_eq(functions.length(), 0)
}

///|
test "ffi bridge rejects removed compiler-owned StringView algorithms" {
  // StringView algorithms belong to Dew. These old runtime operations are
  // intentionally unsupported, including the old wrapper-copy conversion.
  for
    name in [
      b"dew_string_view_byte_length", b"dew_string_view_byte_at", b"dew_string_view_to_string",
      b"dew_string_view_utf16_length", b"dew_string_view_equals", b"dew_string_view_hash",
      b"dew_string_view_find", b"dew_string_view_find_string", b"dew_string_view_starts_with",
      b"dew_string_view_starts_with_string", b"dew_string_view_ends_with", b"dew_string_view_ends_with_string", b"dew_string_view_as_bytes",
    ] {
    let functions = funcs_new()
    let builder = runtime_function_builder_new(0)
    for byte in name {
      builder.push_name_byte(byte)
    }
    assert_false(funcs_push_runtime(functions, builder))
    assert_eq(functions.length(), 0)
  }
}

///|
test "ffi bridge rejects removed compiler-owned String algorithms" {
  // String algorithms use Dew functions and selected trait evidence. These
  // old runtime operations are intentionally unsupported by the provider.
  for
    name in [
      b"dew_string_byte_length", b"dew_string_byte_at", b"dew_string_equals", b"dew_string_utf16_length",
      b"dew_string_hash", b"dew_string_find", b"dew_string_find_view", b"dew_string_starts_with",
      b"dew_string_starts_with_view", b"dew_string_ends_with", b"dew_string_ends_with_view",
      b"dew_string_concat", b"dew_string_concat_view", b"dew_string_load_u8x16", b"dew_string_builder_byte_length", b"dew_string_builder_new", b"dew_string_as_bytes",
      b"dew_string_builder_append", b"dew_string_builder_append_view", b"dew_string_builder_append_ascii",
      b"dew_string_builder_with_capacity", b"dew_string_builder_append_scalar", b"dew_string_builder_finish",
      b"dew_string_view", b"dew_string_view_view",
    ] {
    let functions = funcs_new()
    let builder = runtime_function_builder_new(0)
    for byte in name {
      builder.push_name_byte(byte)
    }
    assert_false(funcs_push_runtime(functions, builder))
    assert_eq(functions.length(), 0)
  }
}

///|
test "ffi bridge rejects removed compiler-owned Bytes algorithms" {
  // Bytes algorithms belong to Dew. These legacy runtime operations are
  // intentionally unsupported, including checked UTF-8 conversion.
  for
    name in [
      b"dew_bytes_is_valid_utf8", b"dew_bytes_to_string", b"dew_bytes_equals", b"dew_bytes_hash",
      b"dew_bytes_find_byte", b"dew_bytes_find", b"dew_bytes_starts_with", b"dew_bytes_ends_with",
      b"dew_bytes_concat", b"dew_bytes_load_u8x16", b"dew_bytes_byte_length", b"dew_bytes_builder_byte_length", b"dew_bytes_builder_new", b"dew_bytes_to_string_unchecked", b"dew_bytes_view", b"dew_bytes_byte_at",
      b"dew_bytes_builder_with_capacity", b"dew_bytes_builder_append",
      b"dew_bytes_builder_append_byte", b"dew_bytes_builder_finish",
    ] {
    let functions = funcs_new()
    let builder = runtime_function_builder_new(0)
    for byte in name {
      builder.push_name_byte(byte)
    }
    assert_false(funcs_push_runtime(functions, builder))
    assert_eq(functions.length(), 0)
  }
}

///|
test "ffi bridge rejects removed compiler-owned Map runtimes" {
  // Map algorithms belong to Dew. The removed names are intentionally
  // unsupported, not fallback implementations for missing selected targets.
  for
    name in [
      b"dew_map_empty", b"dew_map_length", b"dew_map_set", b"dew_map_insert", b"dew_map_get_unchecked",
      b"dew_map_get", b"dew_map_contains_key",
    ] {
    let functions = funcs_new()
    let builder = runtime_function_builder_new(0)
    for byte in name {
      builder.push_name_byte(byte)
    }
    assert_false(funcs_push_runtime(functions, builder))
    assert_eq(functions.length(), 0)
  }
}

///|
test "ffi bridge rejects removed compiler-owned Array runtimes" {
  // Array algorithms now belong to Dew. These old operations, including
  // iterator Option next, are intentionally unsupported by the provider.
  for
    name in [
      b"dew_array_new", b"dew_array_with_capacity", b"dew_array_make", b"dew_array_length",
      b"dew_array_capacity", b"dew_array_backing_length_i32", b"dew_array_backing_length_ref",
      b"dew_array_push", b"dew_array_get", b"dew_array_get_unchecked", b"dew_array_set_unchecked",
      b"dew_array_pop", b"dew_array_iter", b"dew_array_iter_has_next", b"dew_array_iter_next",
      b"dew_array_iter_next_option", b"dew_array_truncate", b"dew_array_clear",
    ] {
    let functions = funcs_new()
    let builder = runtime_function_builder_new(0)
    for byte in name {
      builder.push_name_byte(byte)
    }
    assert_false(funcs_push_runtime(functions, builder))
    assert_eq(functions.length(), 0)
  }
}
