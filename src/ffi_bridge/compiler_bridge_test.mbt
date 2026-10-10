///|
fn compiler_bridge_roundtrip(module_ : @lib.Module) -> @lib.Module raise {
  assert_true(@validate.validate_module(module_) is Ok(_))
  match @binary.encode_module(module_) {
    Ok(bytes) =>
      match @binary.decode_module(bytes) {
        Ok(decoded) => {
          assert_true(@validate.validate_module(decoded) is Ok(_))
          decoded
        }
        Err(error) => fail("compiler bridge decode failed: \{error}")
      }
    Err(error) => fail("compiler bridge encode failed: \{error}")
  }
}

///|
fn compiler_bridge_void_module() -> @lib.Module {
  @lib.Module::new(
    type_sec=Some(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    ),
    func_sec=Some(@lib.FuncSec::new([@lib.TypeIdx::new(0U)])),
    code_sec=Some(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    ),
  )
}

///|
test "compiler bridge facts preserve imported index prefixes and host boundaries" {
  let input = compiler_bridge_void_module()
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("call"),
          @lib.ExternType::func(@lib.TypeIdx::new(0U)),
        ),
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("memory"),
          @lib.ExternType::mem(@lib.MemType::new(@lib.Limits::i32(1U, None))),
        ),
      ]),
    )
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("main"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(1U)),
        ),
        @lib.Export::new(
          @lib.Name::from_string("memory"),
          @lib.ExternIdx::mem(@lib.MemIdx::new(0U)),
        ),
      ]),
    )
  let output = @ffi_bridge.module_with_dewdrop_compiler_facts(input)
  assert_eq(input.compiler_fact_custom_section, None)
  let facts = output.compiler_fact_custom_section.unwrap().facts
  assert_eq(
    facts.producer,
    Some(@representation.ProducerInfo::new("dewdrop", "0.1.0")),
  )
  assert_eq(
    facts.world,
    Some(
      @representation.WorldFacts::closed_module(
        host_can_call_exports=true,
        host_can_mutate_exported_state=true,
      ),
    ),
  )
  assert_eq(facts.functions.length(), 2)
  assert_eq(facts.functions[0].function, 0U)
  assert_eq(facts.functions[1].function, 1U)
  assert_eq(
    facts.functions[0].boundary,
    Some(@representation.FunctionBoundaryFacts::new(false, false, false)),
  )
  assert_eq(
    facts.functions[1].boundary,
    Some(@representation.FunctionBoundaryFacts::new(false, false, true)),
  )
  assert_eq(
    facts.functions[1].effects,
    Some(
      @representation.EffectFacts::new(
        @representation.EffectMask::from_bits(0x7F_FFFFUL),
      ),
    ),
  )
  let decoded = compiler_bridge_roundtrip(output)
  assert_eq(decoded.import_sec, input.import_sec)
  assert_eq(decoded.export_sec, input.export_sec)
  assert_eq(
    decoded.compiler_fact_custom_section,
    output.compiler_fact_custom_section,
  )
  let empty = @ffi_bridge.module_with_dewdrop_compiler_facts(@lib.Module::new())
  assert_eq(empty.compiler_fact_custom_section.unwrap().facts.functions, [])
  assert_eq(
    empty.compiler_fact_custom_section.unwrap().facts.world,
    Some(
      @representation.WorldFacts::closed_module(
        host_can_call_exports=false,
        host_can_mutate_exported_state=false,
      ),
    ),
  )
}

///|
test "compiler bridge declarations retain function identities through binary encoding" {
  let input = compiler_bridge_void_module()
    .with_func_sec(
      @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(0U)]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    )
  let references = @ffi_bridge.function_reference_builder_new()
  assert_eq(
    @ffi_bridge.module_with_declarative_functions(input, references),
    input,
  )
  references.push(1)
  references.push(0)
  references.push(1)
  let output = @ffi_bridge.module_with_declarative_functions(input, references)
  let expected = Some(
    @lib.ElemSec::new([
      @lib.Elem::new(
        @lib.ElemMode::declarative(),
        @lib.ElemKind::funcs([
          @lib.FuncIdx::new(1U),
          @lib.FuncIdx::new(0U),
          @lib.FuncIdx::new(1U),
        ]),
      ),
    ]),
  )
  assert_eq(output.elem_sec, expected)
  assert_eq(compiler_bridge_roundtrip(output).elem_sec, expected)
  assert_eq(input.elem_sec, None)
}

///|
test "compiler bridge globals initialize every numeric and nullable reference carrier" {
  let input = compiler_bridge_void_module()
  let globals = @ffi_bridge.global_builder_new()
  assert_eq(@ffi_bridge.module_with_globals(input, globals), input)
  for carrier in [0, 1, 2, 3, 4, 9] {
    globals.push(carrier)
  }
  let output = @ffi_bridge.module_with_compiler_exports(
    @ffi_bridge.module_with_start_function(
      @ffi_bridge.module_with_default_memory(
        @ffi_bridge.module_with_globals(input, globals),
      ),
      0,
    ),
    0,
  )
  let decoded = compiler_bridge_roundtrip(output)
  assert_eq(decoded.global_sec, output.global_sec)
  let entries = decoded.global_sec.unwrap().0
  assert_eq(entries.length(), 6)
  let types = [
    @lib.ValType::i32(),
    @lib.ValType::i64(),
    @lib.ValType::f32(),
    @lib.ValType::f64(),
    @lib.ValType::v128(),
    @lib.ValType::eqref_null(),
  ]
  let initializers = [
    @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(0))]),
    @lib.Expr::new([@lib.Instruction::i64_const(@lib.I64::new(0L))]),
    @lib.Expr::new([@lib.Instruction::f32_const(@lib.F32::new(0.0))]),
    @lib.Expr::new([@lib.Instruction::f64_const(@lib.F64::new(0.0))]),
    @lib.Expr::new([
      @lib.Instruction::v128_const(
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      ),
    ]),
    @lib.Expr::new([
      @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::none())),
    ]),
  ]
  for index in 0..<types.length() {
    assert_eq(entries[index].0, @lib.GlobalType::new(types[index], true))
    assert_eq(entries[index].1, initializers[index])
  }
  assert_eq(decoded.start_sec, Some(@lib.StartSec::new(@lib.FuncIdx::new(0U))))
  assert_eq(
    decoded.export_sec,
    Some(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("main"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
        ),
        @lib.Export::new(
          @lib.Name::from_string("memory"),
          @lib.ExternIdx::mem(@lib.MemIdx::new(0U)),
        ),
      ]),
    ),
  )
  assert_eq(input.global_sec, None)
}

///|
fn compiler_bridge_wasi_schema(
  parameters : Array[@ffi_bridge.WasiMarshalNode],
  depth : Int,
  nodes : Int,
) -> @ffi_bridge.WasiPreview1Schema {
  {
    module_name: "wasi_snapshot_preview1",
    field: "fd_write",
    parameters,
    maximum_depth: depth,
    maximum_nodes: nodes,
  }
}

///|
test "compiler memory builtins retain Wasm opcode widths and natural alignments" {
  // Opcode + memarg + end bytes are from the core/SIMD binary encodings.
  // Validate a correctly typed load/store body independently of the dispatcher.
  let endings = [
    b"\x2c\x00\x00\x0b", b"\x3a\x00\x00\x0b", b"\x2d\x00\x00\x0b", b"\x2e\x01\x00\x0b",
    b"\x3b\x01\x00\x0b", b"\x2f\x01\x00\x0b", b"\x28\x02\x00\x0b", b"\x36\x02\x00\x0b",
    b"\x29\x03\x00\x0b", b"\x37\x03\x00\x0b", b"\x2a\x02\x00\x0b", b"\x38\x02\x00\x0b",
    b"\x2b\x03\x00\x0b", b"\x39\x03\x00\x0b", b"\xfd\x00\x04\x00\x0b", b"\xfd\x0b\x04\x00\x0b",
  ]
  for opcode in 0..<16 {
    let store = opcode == 1 ||
      opcode == 4 ||
      opcode == 7 ||
      opcode == 9 ||
      opcode == 11 ||
      opcode == 13 ||
      opcode == 15
    let value_type = if opcode < 8 {
      @lib.ValType::i32()
    } else if opcode < 10 {
      @lib.ValType::i64()
    } else if opcode < 12 {
      @lib.ValType::f32()
    } else if opcode < 14 {
      @lib.ValType::f64()
    } else {
      @lib.ValType::v128()
    }
    let parameters = [@lib.ValType::i32()]
    let body = [@lib.Instruction::local_get(@lib.LocalIdx::new(0U))]
    if store {
      parameters.push(value_type)
      body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
    }
    body.push(@ffi_bridge.instruction_memory_builtin(opcode))
    let input = @ffi_bridge.module_with_default_memory(
      compiler_bridge_void_module()
      .with_type_sec(
        @lib.TypeSec::new([
          @lib.RecType::new(
            @lib.SubType::comp_type(
              @lib.CompType::func(
                parameters,
                if store {
                  []
                } else {
                  [value_type]
                },
              ),
            ),
          ),
        ]),
      )
      .with_code_sec(
        @lib.CodeSec::new([
          @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
        ]),
      ),
    )
    assert_eq(compiler_bridge_roundtrip(input).code_sec, input.code_sec)
    let bytes = @binary.encode_module(input).unwrap()
    let expected = endings[opcode]
    for offset in 0..<expected.length() {
      assert_eq(
        bytes[bytes.length() - expected.length() + offset],
        expected[offset],
      )
    }
  }
}

///|
test "WASI compiler bridge validates fd schemas and rejects unsafe scratch and traversal bounds" {
  let write = @ffi_bridge.wasi_preview1_fd_write_schema()
  let read = @ffi_bridge.wasi_preview1_fd_read_schema()
  for
    (schema, field, bytes) in [
      (write, "fd_write", @ffi_bridge.WasiInputBytes(65520)),
      (read, "fd_read", @ffi_bridge.WasiOutputBytes(65520)),
    ] {
    assert_eq(schema.module_name, "wasi_snapshot_preview1")
    assert_eq(schema.field, field)
    assert_eq(schema.maximum_depth, 4)
    assert_eq(schema.maximum_nodes, 16)
    assert_eq(schema.parameters, [
      @ffi_bridge.WasiI32,
      @ffi_bridge.WasiList(
        @ffi_bridge.WasiPointer([bytes, @ffi_bridge.WasiI32]),
        1,
      ),
      @ffi_bridge.WasiI32,
      @ffi_bridge.WasiPointer([@ffi_bridge.WasiI32]),
    ])
    assert_eq(@ffi_bridge.validate_wasi_preview1_schema(schema), Ok(()))
  }
  for depth in [0, 17] {
    assert_true(
      @ffi_bridge.validate_wasi_preview1_schema(
        compiler_bridge_wasi_schema([], depth, 16),
      )
      is Err(_),
    )
  }
  for nodes in [0, 1025] {
    assert_true(
      @ffi_bridge.validate_wasi_preview1_schema(
        compiler_bridge_wasi_schema([], 4, nodes),
      )
      is Err(_),
    )
  }
  for bytes in [-1, 65521] {
    for
      node in [
        @ffi_bridge.WasiInputBytes(bytes),
        @ffi_bridge.WasiOutputBytes(bytes),
      ] {
      assert_eq(
        @ffi_bridge.validate_wasi_preview1_schema(
          compiler_bridge_wasi_schema([node], 4, 16),
        ),
        Err("WASI byte range exceeds scratch capacity"),
      )
    }
  }
  for count in [-1, 1025] {
    assert_eq(
      @ffi_bridge.validate_wasi_preview1_schema(
        compiler_bridge_wasi_schema(
          [@ffi_bridge.WasiList(@ffi_bridge.WasiI32, count)],
          4,
          16,
        ),
      ),
      Err("WASI list count is outside its bound"),
    )
  }
  assert_eq(
    @ffi_bridge.validate_wasi_preview1_schema(
      compiler_bridge_wasi_schema(
        [@ffi_bridge.WasiPointer([@ffi_bridge.WasiI32])],
        1,
        16,
      ),
    ),
    Err("WASI marshalling schema exceeds its depth bound"),
  )
  assert_eq(
    @ffi_bridge.validate_wasi_preview1_schema(
      compiler_bridge_wasi_schema(
        [@ffi_bridge.WasiI32, @ffi_bridge.WasiI32],
        4,
        1,
      ),
    ),
    Err("WASI marshalling schema exceeds its node bound"),
  )
  assert_eq(
    @ffi_bridge.validate_wasi_preview1_schema(
      compiler_bridge_wasi_schema(
        [@ffi_bridge.WasiInputBytes(0), @ffi_bridge.WasiOutputBytes(65520)],
        1,
        2,
      ),
    ),
    Ok(()),
  )
}
