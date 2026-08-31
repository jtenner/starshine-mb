///|
fn[T : Encode] compiler_facts_test_encode(value : T) -> Bytes raise {
  let buf = @buffer.new()
  match Encode::encode(value, buf) {
    Ok(_) => buf.to_bytes()
    Err(err) => fail("compiler facts encode failed: \{err}")
  }
}

///|
fn[T : Encode + Decode + Eq + @debug.Debug] compiler_facts_test_roundtrip(
  value : T,
) -> Unit raise {
  let bytes = compiler_facts_test_encode(value)
  let (decoded, next) = match
    (Decode::decode(bytes, 0) : Result[(T, Int), BinaryDecodeError]) {
    Ok(result) => result
    Err(err) => fail("compiler facts decode failed: \{err}")
  }
  @debug.assert_eq(next, bytes.length())
  @debug.assert_eq(decoded, value)
  @debug.assert_eq(compiler_facts_test_encode(decoded), bytes)
}

///|
fn compiler_facts_test_populated_section() -> @representation.CompilerFactCustomSection {
  let value = @representation.ValueFacts::new(
    non_null=true,
    exact_heap_type=Some(1U),
    exact_call_target=Some(1U),
    signed_range=Some(@representation.SignedRange::new(-9L, 10L)),
    unsigned_range=Some(@representation.UnsignedRange::new(11UL, 12UL)),
    does_not_escape=true,
    identity_not_observed=true,
  )
  let effects = @representation.EffectFacts::new(
    @representation.EffectMask::control()
    .union(@representation.EffectMask::call())
    .union(@representation.EffectMask::throw_())
    .union(@representation.EffectMask::trap())
    .union(@representation.EffectMask::local_state())
    .union(@representation.EffectMask::global_state())
    .union(@representation.EffectMask::memory_read())
    .union(@representation.EffectMask::memory_write())
    .union(@representation.EffectMask::table_read())
    .union(@representation.EffectMask::table_write())
    .union(@representation.EffectMask::heap_read())
    .union(@representation.EffectMask::heap_write())
    .union(@representation.EffectMask::allocation()),
    read_globals=Some(@representation.ClosedGlobalSet::new([0U])),
    written_globals=Some(@representation.ClosedGlobalSet::new([0U])),
    read_memories=Some(@representation.ClosedMemorySet::new([0U])),
    written_memories=Some(@representation.ClosedMemorySet::new([0U])),
    read_tables=Some(@representation.ClosedTableSet::new([0U])),
    written_tables=Some(@representation.ClosedTableSet::new([0U])),
    read_heap_types=Some(@representation.ClosedTypeViewSet::new([0U, 1U])),
    written_heap_types=Some(@representation.ClosedTypeViewSet::new([1U])),
    direct_callees=Some(@representation.ClosedFunctionSet::new([0U, 1U])),
  )
  let function = @representation.FunctionFacts::new(
    0U,
    effects=Some(effects),
    parameters=[
      @representation.ParameterFacts::new(
        0U,
        value=Some(value),
        uses=Some(
          @representation.ParameterUseMask::direct_computation()
          .union(@representation.ParameterUseMask::control())
          .union(@representation.ParameterUseMask::address_index())
          .union(@representation.ParameterUseMask::call_argument())
          .union(@representation.ParameterUseMask::stored_value())
          .union(@representation.ParameterUseMask::return_())
          .union(@representation.ParameterUseMask::identity_observing()),
        ),
        escape_sinks=Some(
          @representation.EscapeSinkMask::return_()
          .union(@representation.EscapeSinkMask::call())
          .union(@representation.EscapeSinkMask::global())
          .union(@representation.EscapeSinkMask::memory())
          .union(@representation.EscapeSinkMask::table())
          .union(@representation.EscapeSinkMask::heap())
          .union(@representation.EscapeSinkMask::throw_())
          .union(@representation.EscapeSinkMask::host_unknown()),
        ),
      ),
    ],
    results=[
      @representation.ResultFacts::new(
        0U,
        value=Some(value),
        identity=Some(@representation.ResultIdentityFacts::fresh()),
      ),
      @representation.ResultFacts::new(
        1U,
        identity=Some(
          @representation.ResultIdentityFacts::same_as_parameter(0U),
        ),
      ),
    ],
    boundary=Some(@representation.FunctionBoundaryFacts::new(true, true, false)),
    profile=Some(
      @representation.FunctionProfile::new(
        entry_count=Some(100UL),
        temperature=Some(@representation.TemperatureHint::hot()),
      ),
    ),
    inline_policy=Some(@representation.InlinePolicy::prefer()),
  )
  let left = @representation.FactSiteRef::new(0U, 1U)
  let right = @representation.FactSiteRef::new(0U, 2U)
  let body = @representation.FunctionBodyFacts::new(
    0U,
    sites=[
      @representation.ExpressionFact::new(0U, 1U, [
        @representation.Fact::non_null(),
        @representation.Fact::exact_heap_type(1U),
        @representation.Fact::exact_call_target(1U),
        @representation.Fact::signed_range(-2L, 2L),
        @representation.Fact::unsigned_range(3UL, 4UL),
        @representation.Fact::does_not_escape(),
        @representation.Fact::identity_not_observed(),
      ]),
    ],
    relations=[
      @representation.FactRelation::same_value(left, right),
      @representation.FactRelation::same_identity(left, right),
      @representation.FactRelation::derived_from(right, left),
    ],
    calls=[
      @representation.CallSiteFacts::new(
        0U,
        3U,
        direct_target=Some(1U),
        profile=Some(
          @representation.CallProfile::new(
            count=Some(75UL),
            temperature=Some(@representation.TemperatureHint::normal()),
          ),
        ),
        inline_policy=Some(@representation.InlinePolicy::always()),
      ),
    ],
    branches=[
      @representation.BranchFacts::new(
        0U,
        4U,
        profile=Some(@representation.BranchProfile::new(9UL, 1UL)),
        temperature=Some(@representation.TemperatureHint::hot()),
      ),
    ],
    loops=[
      @representation.LoopFacts::new(
        0U,
        5U,
        profile=Some(
          @representation.LoopProfile::new(
            backedge_count=Some(30UL),
            estimated_trip_count=Some(3UL),
          ),
        ),
        temperature=Some(@representation.TemperatureHint::cold()),
      ),
    ],
    allocations=[
      @representation.AllocationSiteFacts::new(
        0U,
        6U,
        heap_type=Some(1U),
        does_not_escape=true,
        identity_not_observed=true,
      ),
    ],
  )
  @representation.CompilerFactCustomSection::new(
    @representation.OptimizationFactsSec::new(functions=[function], bodies=[
      body,
    ]),
    module_fingerprint=Some(b"opaque-fingerprint"),
  )
}

///|
test "compiler facts empty payload layout is stable" {
  let empty = @representation.CompilerFactCustomSection::new(
    @representation.OptimizationFactsSec::new(),
  )
  @debug.assert_eq(compiler_facts_test_encode(empty), b"\x01\x00\x00\x00")
  compiler_facts_test_roundtrip(empty)
  @debug.assert_eq(
    encode_module(Module::new(compiler_fact_custom_section=Some(empty))).unwrap(),
    b"\x00\x61\x73\x6d\x01\x00\x00\x00\x00\x13\x0ecompiler.facts\x01\x00\x00\x00",
  )
}

///|
test "compiler facts all optional fields encode and decode as none" {
  compiler_facts_test_roundtrip(@representation.FunctionFacts::new(0U))
  compiler_facts_test_roundtrip(
    @representation.EffectFacts::new(@representation.EffectMask::empty()),
  )
  compiler_facts_test_roundtrip(@representation.ParameterFacts::new(0U))
  compiler_facts_test_roundtrip(@representation.ResultFacts::new(0U))
  compiler_facts_test_roundtrip(@representation.ValueFacts::new())
  compiler_facts_test_roundtrip(@representation.FunctionProfile::new())
  compiler_facts_test_roundtrip(@representation.CallProfile::new())
  compiler_facts_test_roundtrip(@representation.LoopProfile::new())
  compiler_facts_test_roundtrip(@representation.FunctionBodyFacts::new(0U))
  compiler_facts_test_roundtrip(@representation.CallSiteFacts::new(0U, 0U))
  compiler_facts_test_roundtrip(@representation.BranchFacts::new(0U, 0U))
  compiler_facts_test_roundtrip(@representation.LoopFacts::new(0U, 0U))
  compiler_facts_test_roundtrip(
    @representation.AllocationSiteFacts::new(0U, 0U),
  )
}

///|
test "compiler facts all serialized types roundtrip canonically" {
  let section = compiler_facts_test_populated_section()
  compiler_facts_test_roundtrip(section)
  compiler_facts_test_roundtrip(section.facts)
  compiler_facts_test_roundtrip(section.facts.functions[0])
  compiler_facts_test_roundtrip(section.facts.functions[0].effects.unwrap())
  compiler_facts_test_roundtrip(@representation.EffectMask::from_bits(0x1FFFUL))
  compiler_facts_test_roundtrip(@representation.ClosedGlobalSet::new([0U, 2U]))
  compiler_facts_test_roundtrip(@representation.ClosedMemorySet::new([0U, 2U]))
  compiler_facts_test_roundtrip(@representation.ClosedTableSet::new([0U, 2U]))
  compiler_facts_test_roundtrip(
    @representation.ClosedTypeViewSet::new([0U, 2U]),
  )
  compiler_facts_test_roundtrip(
    @representation.ClosedFunctionSet::new([0U, 2U]),
  )
  compiler_facts_test_roundtrip(section.facts.functions[0].parameters[0])
  compiler_facts_test_roundtrip(
    @representation.ParameterUseMask::from_bits(0x7FUL),
  )
  compiler_facts_test_roundtrip(
    @representation.EscapeSinkMask::from_bits(0xFFUL),
  )
  compiler_facts_test_roundtrip(section.facts.functions[0].results[0])
  compiler_facts_test_roundtrip(@representation.ResultIdentityFacts::fresh())
  compiler_facts_test_roundtrip(
    @representation.ResultIdentityFacts::same_as_parameter(0U),
  )
  compiler_facts_test_roundtrip(
    section.facts.functions[0].parameters[0].value.unwrap(),
  )
  compiler_facts_test_roundtrip(
    @representation.SignedRange::new(-1L << 63, (1L << 62) - 1L + (1L << 62)),
  )
  compiler_facts_test_roundtrip(
    @representation.UnsignedRange::new(0UL, UInt64::lnot(0UL)),
  )
  compiler_facts_test_roundtrip(section.facts.functions[0].boundary.unwrap())
  compiler_facts_test_roundtrip(section.facts.functions[0].profile.unwrap())
  compiler_facts_test_roundtrip(@representation.CallProfile::new())
  compiler_facts_test_roundtrip(
    @representation.BranchProfile::new(0UL, UInt64::lnot(0UL)),
  )
  compiler_facts_test_roundtrip(@representation.LoopProfile::new())
  compiler_facts_test_roundtrip(@representation.TemperatureHint::cold())
  compiler_facts_test_roundtrip(@representation.InlinePolicy::default_())
  compiler_facts_test_roundtrip(section.facts.bodies[0])
  compiler_facts_test_roundtrip(section.facts.bodies[0].sites[0])
  for fact in section.facts.bodies[0].sites[0].facts {
    compiler_facts_test_roundtrip(fact)
  }
  compiler_facts_test_roundtrip(@representation.FactSiteRef::new(0U, 1U))
  for relation in section.facts.bodies[0].relations {
    compiler_facts_test_roundtrip(relation)
  }
  compiler_facts_test_roundtrip(section.facts.bodies[0].calls[0])
  compiler_facts_test_roundtrip(section.facts.bodies[0].branches[0])
  compiler_facts_test_roundtrip(section.facts.bodies[0].loops[0])
  compiler_facts_test_roundtrip(section.facts.bodies[0].allocations[0])
}

///|
test "compiler facts enum discriminator table is stable" {
  @debug.assert_eq(
    compiler_facts_test_encode(@representation.TemperatureHint::cold()),
    b"\x00",
  )
  @debug.assert_eq(
    compiler_facts_test_encode(@representation.TemperatureHint::normal()),
    b"\x01",
  )
  @debug.assert_eq(
    compiler_facts_test_encode(@representation.TemperatureHint::hot()),
    b"\x02",
  )
  @debug.assert_eq(
    compiler_facts_test_encode(@representation.InlinePolicy::default_()),
    b"\x00",
  )
  @debug.assert_eq(
    compiler_facts_test_encode(@representation.InlinePolicy::never()),
    b"\x01",
  )
  @debug.assert_eq(
    compiler_facts_test_encode(@representation.InlinePolicy::prefer()),
    b"\x02",
  )
  @debug.assert_eq(
    compiler_facts_test_encode(@representation.InlinePolicy::always()),
    b"\x03",
  )
  compiler_facts_test_roundtrip(@representation.TemperatureHint::cold())
  compiler_facts_test_roundtrip(@representation.TemperatureHint::normal())
  compiler_facts_test_roundtrip(@representation.TemperatureHint::hot())
  compiler_facts_test_roundtrip(@representation.InlinePolicy::default_())
  compiler_facts_test_roundtrip(@representation.InlinePolicy::never())
  compiler_facts_test_roundtrip(@representation.InlinePolicy::prefer())
  compiler_facts_test_roundtrip(@representation.InlinePolicy::always())
  @debug.assert_eq(
    compiler_facts_test_encode(@representation.ResultIdentityFacts::fresh()),
    b"\x00",
  )
  @debug.assert_eq(
    compiler_facts_test_encode(
      @representation.ResultIdentityFacts::same_as_parameter(7U),
    ),
    b"\x01\x07",
  )
  let facts = [
    (@representation.Fact::non_null(), b"\x00"),
    (@representation.Fact::exact_heap_type(7U), b"\x01\x07"),
    (@representation.Fact::exact_call_target(7U), b"\x02\x07"),
    (@representation.Fact::signed_range(-1L, 1L), b"\x03\x7f\x01"),
    (@representation.Fact::unsigned_range(1UL, 2UL), b"\x04\x01\x02"),
    (@representation.Fact::does_not_escape(), b"\x05"),
    (@representation.Fact::identity_not_observed(), b"\x06"),
  ]
  for item in facts {
    @debug.assert_eq(compiler_facts_test_encode(item.0), item.1)
  }
  let a = @representation.FactSiteRef::new(0U, 1U)
  let b = @representation.FactSiteRef::new(0U, 2U)
  @debug.assert_eq(
    compiler_facts_test_encode(@representation.FactRelation::same_value(a, b))[0],
    0x00,
  )
  @debug.assert_eq(
    compiler_facts_test_encode(
      @representation.FactRelation::same_identity(a, b),
    )[0],
    0x01,
  )
  @debug.assert_eq(
    compiler_facts_test_encode(@representation.FactRelation::derived_from(a, b))[0],
    0x02,
  )
}

///|
test "compiler facts opcode index tracks nested canonical instruction starts" {
  let block_offsets = compiler_fact_opcode_offsets(
    Expr::new([
      Instruction::block(
        BlockType::void_(),
        Expr::new([Instruction::i32_const(I32(128)), Instruction::nop()]),
      ),
      Instruction::nop(),
    ]),
  ).unwrap()
  @debug.assert_eq(block_offsets, [0U, 2U, 5U, 7U])

  let if_offsets = compiler_fact_opcode_offsets(
    Expr::new([
      Instruction::if_(
        BlockType::void_(),
        [Instruction::nop()],
        Some([Instruction::nop()]),
      ),
      Instruction::nop(),
    ]),
  ).unwrap()
  @debug.assert_eq(if_offsets, [0U, 2U, 4U, 6U])

  let string_offsets = compiler_fact_opcode_offsets(
    Expr::new([Instruction::string_const(b"site"), Instruction::nop()]),
    stringrefs=Some([b"site"]),
  ).unwrap()
  @debug.assert_eq(string_offsets, [0U, 4U])
}

///|
test "module compiler facts custom section roundtrips explicitly with unrelated custom sections" {
  let section = compiler_facts_test_populated_section()
  let module_ = Module::new(
    custom_secs=[CustomSec::new(Name::new("unrelated"), b"payload")],
    compiler_fact_custom_section=Some(section),
  )
  let bytes = encode_module(module_).unwrap()
  let decoded = decode_module(bytes).unwrap()
  @debug.assert_eq(decoded.compiler_fact_custom_section, Some(section))
  @debug.assert_eq(decoded.custom_secs, module_.custom_secs)
  assert_false(
    decoded.custom_secs.any(fn(sec) {
      let CustomSec(name, _) = sec
      name == Name::new("compiler.facts")
    }),
  )
  @debug.assert_eq(encode_module(decoded).unwrap(), bytes)
}

///|
test "module without compiler facts retains existing empty encoding" {
  @debug.assert_eq(
    encode_module(Module::new()).unwrap(),
    b"\x00\x61\x73\x6d\x01\x00\x00\x00",
  )
}

///|
test "compiler facts encoder rejects unsupported versions" {
  let section = @representation.CompilerFactCustomSection::new(
    @representation.OptimizationFactsSec::new(),
    version=2U,
  )
  match Encode::encode(section, @buffer.new()) {
    Err(BinaryEncodeError::UnsupportedCompilerFactsVersion) => ()
    _ => fail("expected unsupported compiler facts encode version")
  }
}

///|
test "generic compiler facts custom section name is reserved" {
  let module_ = Module::new(custom_secs=[
    CustomSec::new(Name::new("compiler.facts"), b"\x01\x00\x00\x00"),
  ])
  match encode_module(module_) {
    Err(
      EncodeError::Encode(BinaryEncodeError::ReservedCompilerFactsCustomSection)
    ) => ()
    other =>
      fail(
        "expected reserved compiler facts custom section error, got \{other}",
      )
  }
}

///|
fn compiler_facts_test_module_bytes(payloads : Array[Bytes]) -> Bytes {
  let wasm = @buffer.new()
  wasm.write_bytes(b"\x00\x61\x73\x6d\x01\x00\x00\x00")
  for fact_payload in payloads {
    let content = @buffer.new()
    Encode::encode(Name::new("compiler.facts"), content).unwrap()
    content.write_bytes(fact_payload)
    wasm.write_byte(0x00)
    Encode::encode(
      @lib.U32(content.to_bytes().length().reinterpret_as_uint()),
      wasm,
    ).unwrap()
    wasm.write_bytes(content.to_bytes())
  }
  wasm.to_bytes()
}

///|
test "compiler facts module decoder rejects duplicate trailing truncated and unsupported payloads" {
  let empty = b"\x01\x00\x00\x00"
  let cases : Array[(Bytes, BinaryDecodeError)] = [
    (
      compiler_facts_test_module_bytes([empty, empty]),
      BinaryDecodeError::DuplicateCompilerFactsSection,
    ),
    (
      compiler_facts_test_module_bytes([empty + b"\x00"]),
      BinaryDecodeError::CompilerFactsTrailingBytes,
    ),
    (
      compiler_facts_test_module_bytes([b"\x01"]),
      BinaryDecodeError::TruncatedCompilerFactsPayload,
    ),
    (
      compiler_facts_test_module_bytes([b"\x02\x00\x00\x00"]),
      BinaryDecodeError::UnsupportedCompilerFactsVersion,
    ),
  ]
  for case in cases {
    match decode_module(case.0) {
      Err(DecodeError::DecodeAt(err, _, _)) => @debug.assert_eq(err, case.1)
      other => fail("expected compiler facts module decode error, got \{other}")
    }
  }
}

///|
test "compiler facts decoders reject malformed enum and option tags" {
  let enum_result : Result[
    (@representation.TemperatureHint, Int),
    BinaryDecodeError,
  ] = Decode::decode(b"\xff", 0)
  match enum_result {
    Err(BinaryDecodeError::InvalidCompilerFactsEnumTag) => ()
    _ => fail("expected invalid compiler facts enum tag")
  }
  let value_result : Result[
    (@representation.ValueFacts, Int),
    BinaryDecodeError,
  ] = Decode::decode(b"\x00\xff", 0)
  match value_result {
    Err(BinaryDecodeError::InvalidCompilerFactsOptionTag) => ()
    _ => fail("expected invalid compiler facts option tag")
  }
}
