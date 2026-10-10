///|
test "npm optimizer bridge forwards passes and preserves a valid encoded module" {
  let input = @lib.Module::new(
    type_sec=Some(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    ),
    func_sec=Some(@lib.FuncSec::new([@lib.TypeIdx::new(0U)])),
    code_sec=Some(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(40)),
            @lib.Instruction::i32_const(@lib.I32::new(2)),
            @lib.Instruction::i32_add(),
          ]),
        ),
      ]),
    ),
  )
  match
    @ffi_bridge.optimize_module(
      input,
      ["precompute", "vacuum"],
      optimize_level=4,
      shrink_level=1,
    ) {
    Ok(output) => {
      match output.code_sec {
        Some(
          @lib.CodeSec(
            [@lib.Func(_, @lib.Expr([@lib.Instruction::I32Const(value)]))]
          )
        ) => assert_eq(value, @lib.I32::new(42))
        _ => fail("expected the forwarded passes to fold the arithmetic")
      }
      assert_true(@validate.validate_module(output) is Ok(_))
      match @binary.encode_module(output) {
        Ok(bytes) =>
          match @binary.decode_module(bytes) {
            Ok(decoded) =>
              assert_true(@validate.validate_module(decoded) is Ok(_))
            Err(error) => fail("bridge output did not roundtrip: \{error}")
          }
        Err(error) => fail("bridge output did not encode: \{error}")
      }
    }
    Err(error) => fail("bridge optimization failed: \{error}")
  }
}

///|
test "npm optimizer bridge returns unknown-pass errors with default options" {
  match @ffi_bridge.optimize_module(@lib.Module::new(), ["not-a-pass"]) {
    Err(error) => assert_eq(error, "unknown pass flag not-a-pass")
    Ok(_) => fail("unknown pass must not silently become a successful no-op")
  }
}

///|
test "npm optimizer bridge forwards preset levels and preserves default options" {
  let input = @lib.Module::new(
    type_sec=Some(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    ),
    func_sec=Some(@lib.FuncSec::new([@lib.TypeIdx::new(0U)])),
    code_sec=Some(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(99)),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(@lib.I32::new(42)),
          ]),
        ),
      ]),
    ),
  )
  let default_output = match @ffi_bridge.optimize_module(input, ["optimize"]) {
    Ok(output) => output
    Err(error) => fail("default preset failed: \{error}")
  }
  // The default fast preset (2/0) does not include vacuum. The discarded
  // constant makes each forwarded option observable independently.
  assert_eq(default_output.code_sec, input.code_sec)
  for (optimize_level, shrink_level) in [(3, 0), (0, 1)] {
    match
      @ffi_bridge.optimize_module(
        input,
        ["optimize"],
        optimize_level~,
        shrink_level~,
      ) {
      Ok(output) => {
        match output.code_sec {
          Some(
            @lib.CodeSec(
              [@lib.Func(_, @lib.Expr([@lib.Instruction::I32Const(value)]))]
            )
          ) => assert_eq(value, @lib.I32::new(42))
          _ => fail("forwarded preset level must remove the discarded constant")
        }
        assert_true(@validate.validate_module(output) is Ok(_))
      }
      Err(error) => fail("configured preset failed: \{error}")
    }
  }
}

///|
test "ffi bridge validation diagnostics identify a failing function and reset after success" {
  let bad_function = @lib.Module::new(
    type_sec=Some(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    ),
    func_sec=Some(@lib.FuncSec::new([@lib.TypeIdx::new(0U)])),
    code_sec=Some(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    ),
  )
  let direct = match @validate.validate_module(bad_function) {
    Err(error) => error
    Ok(_) => fail("missing function result is intentionally invalid")
  }
  assert_false(@ffi_bridge.validate_module(bad_function))
  assert_eq(@ffi_bridge.validation_error_function_index(), 0)
  let message = StringBuilder::new()
  for index in 0U..<@ffi_bridge.validation_error_byte_length() {
    message.write_char(
      @ffi_bridge.validation_error_byte_at(index).to_int().unsafe_to_char(),
    )
  }
  assert_eq(message.to_string(), @validate.validation_error_message(direct))
  assert_true(@ffi_bridge.validate_module(@lib.Module::new()))
  assert_eq(@ffi_bridge.validation_error_byte_length(), 0U)
  assert_eq(@ffi_bridge.validation_error_function_index(), -1)
  let bad_section = @lib.Module::new(
    func_sec=Some(@lib.FuncSec::new([@lib.TypeIdx::new(0U)])),
  )
  assert_false(@ffi_bridge.validate_module(bad_section))
  assert_eq(@ffi_bridge.validation_error_function_index(), -1)
  assert_true(@ffi_bridge.validation_error_byte_length() > 0U)
}

///|
test "ffi bridge reports intentionally unencodable modules without stale successful bytes" {
  let previous = @ffi_bridge.encode_module(@lib.Module::new())
  assert_true(previous.is_ok())
  assert_eq(previous.byte_length(), 8U)
  let unsupported = @lib.Module::new(
    type_sec=Some(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::bottom()], []),
          ),
        ),
      ]),
    ),
  )
  assert_true(@binary.encode_module(unsupported) is Err(_))
  let failed = @ffi_bridge.encode_module(unsupported)
  assert_false(failed.is_ok())
  assert_eq(failed.byte_length(), 0U)
  let recovered = @ffi_bridge.encode_module(@lib.Module::new())
  assert_true(recovered.is_ok())
  assert_eq(recovered.byte_length(), 8U)
  assert_eq(recovered.byte_at(0U), b'\x00')
  assert_false(failed.is_ok())
  assert_eq(failed.byte_length(), 0U)
}

///|
test "ffi bridge GC constructors and import bytes survive validated binary roundtrip" {
  let fields = @ffi_bridge.field_types_new()
  @ffi_bridge.field_types_push(
    fields,
    @lib.FieldType::new(
      @lib.StorageType::val_type(@lib.ValType::i32()),
      @lib.Mut::const_(),
    ),
  )
  let rec_types = @ffi_bridge.rec_types_new()
  @ffi_bridge.rec_types_push(
    rec_types,
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_(fields))),
  )
  @ffi_bridge.rec_types_push(
    rec_types,
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@ffi_bridge.nominal_ref_type(0, true)], [
          @lib.ValType::i32(),
        ]),
      ),
    ),
  )
  let imports = @ffi_bridge.imports_new()
  let builder = @ffi_bridge.import_builder_new(1)
  for byte in [b'e', b'n', b'v'] {
    builder.push_module_byte(byte)
  }
  for byte in [b'a', b'"', b'\\', b'b'] {
    builder.push_field_byte(byte)
  }
  @ffi_bridge.imports_push_builder(imports, builder)
  let body = @lib.Expr::new([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @ffi_bridge.instruction_ref_cast_nominal(0),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @ffi_bridge.instruction_ref_test_nominal(0),
    @ffi_bridge.instruction_if(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      [@lib.Instruction::i32_const(@lib.I32::new(42))],
      [@lib.Instruction::i32_const(@lib.I32::new(43))],
    ),
  ])
  let module_ = @ffi_bridge.module_with_default_memory(
    @lib.Module::new(
      type_sec=Some(@lib.TypeSec::new(rec_types)),
      import_sec=Some(@lib.ImportSec::new(imports)),
      func_sec=Some(@lib.FuncSec::new([@lib.TypeIdx::new(1U)])),
      code_sec=Some(
        @lib.CodeSec::new([@lib.Func::new(@lib.Locals::empty(), body)]),
      ),
    ),
  )
  assert_true(@ffi_bridge.validate_module(module_))
  let encoded = @ffi_bridge.encode_module(module_)
  assert_true(encoded.is_ok())
  let bytes : Array[Byte] = []
  for index in 0U..<encoded.byte_length() {
    bytes.push(encoded.byte_at(index))
  }
  match @binary.decode_module(Bytes::from_array(bytes)) {
    Ok(decoded) => {
      assert_true(@validate.validate_module(decoded) is Ok(_))
      assert_eq(
        decoded.import_sec,
        Some(
          @lib.ImportSec::new([
            @lib.Import::new(
              @lib.Name::from_string("env"),
              @lib.Name::from_string("a\"\\b"),
              @lib.ExternType::func(@lib.TypeIdx::new(1U)),
            ),
          ]),
        ),
      )
      assert_eq(
        decoded.mem_sec,
        Some(@lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))])),
      )
      let signature = decoded.type_sec.unwrap().0[1]
        .get_subtype(0U)
        .unwrap()
        .get_comptype()
      assert_eq(
        signature,
        @lib.CompType::func(
          [@lib.ValType::ref_null(@lib.HeapType::new(@lib.TypeIdx::new(0U)))],
          [@lib.ValType::i32()],
        ),
      )
      assert_eq(decoded.type_sec, module_.type_sec)
      assert_eq(decoded.code_sec, module_.code_sec)
    }
    Err(error) => fail("GC bridge module failed roundtrip: \{error}")
  }
}
