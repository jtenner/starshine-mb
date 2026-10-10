///|
// Tag 255 is reserved/unsupported by each v1 compiler-facts discriminator.
// A complete valid witness still roundtrips; neither a foreign tag nor a
// missing discriminator may be interpreted as a default fact.
fn[T : Encode + Decode + Eq + @debug.Debug] compiler_facts_test_invalid_discriminator(
  value : T,
) -> Unit raise {
  compiler_facts_test_roundtrip(value)
  let bytes = compiler_facts_test_encode(value).to_array()
  bytes[0] = 255
  let invalid : Result[(T, Int), BinaryDecodeError] = Decode::decode(
    Bytes::from_array(bytes),
    0,
  )
  match invalid {
    Err(error) =>
      assert_eq(error, BinaryDecodeError::InvalidCompilerFactsEnumTag)
    Ok(_) => fail("accepted unsupported compiler-facts discriminator 255")
  }
  let truncated : Result[(T, Int), BinaryDecodeError] = Decode::decode(b"", 0)
  match truncated {
    Err(error) =>
      assert_eq(error, BinaryDecodeError::TruncatedCompilerFactsPayload)
    Ok(_) => fail("accepted missing compiler-facts discriminator")
  }
}

///|
test "compiler facts reject unsupported and missing v1 discriminators without defaults" {
  compiler_facts_test_invalid_discriminator(
    @representation.WorldMode::closed_module(),
  )
  compiler_facts_test_invalid_discriminator(@representation.IntWidth::i32())
  compiler_facts_test_invalid_discriminator(@representation.FactHeapType::any())
  compiler_facts_test_invalid_discriminator(
    @representation.FactValue::f32_bits(0x3f800000U),
  )
  compiler_facts_test_invalid_discriminator(@representation.FloatWidth::f32())
  compiler_facts_test_invalid_discriminator(
    @representation.NullabilityFacts::non_null(),
  )
  compiler_facts_test_invalid_discriminator(
    @representation.HeapDomain::exact_runtime_type(
      @representation.FactHeapType::any(),
    ),
  )
  compiler_facts_test_invalid_discriminator(
    @representation.VectorLaneShape::i8x16(),
  )
  compiler_facts_test_invalid_discriminator(
    @representation.ValueRef::global(0U),
  )
  compiler_facts_test_invalid_discriminator(
    @representation.AliasSource::parameter(0U),
  )
  compiler_facts_test_invalid_discriminator(
    @representation.ResultIdentityFacts::fresh(),
  )
  compiler_facts_test_invalid_discriminator(
    @representation.TemperatureHint::hot(),
  )
  compiler_facts_test_invalid_discriminator(
    @representation.InlinePolicy::never(),
  )
  compiler_facts_test_invalid_discriminator(@representation.TypeView::exact(0U))
  compiler_facts_test_invalid_discriminator(
    @representation.TypePopulation::empty(),
  )
  compiler_facts_test_invalid_discriminator(
    @representation.WriteFacts::no_writes(),
  )
  compiler_facts_test_invalid_discriminator(
    @representation.MutationPhase::runtime(),
  )
  compiler_facts_test_invalid_discriminator(
    @representation.AllocationKind::struct_(0U),
  )
  compiler_facts_test_invalid_discriminator(
    @representation.FactOperand::constant(
      @representation.FactValue::f32_bits(0x3f800000U),
    ),
  )
  compiler_facts_test_invalid_discriminator(
    @representation.RelationKind::equal(),
  )
  compiler_facts_test_invalid_discriminator(
    @representation.OptimizationGoal::balanced(),
  )
  compiler_facts_test_invalid_discriminator(
    @representation.HintTarget::function(0U),
  )
  compiler_facts_test_invalid_discriminator(
    @representation.OptimizationHint::hotness(
      @representation.HintTarget::function(0U),
      @representation.TemperatureHint::hot(),
    ),
  )
}

///|
// These offsets are the v1 presence bytes in the explicit empty witnesses.
// Invalid tags must propagate through their owning record rather than become None.
fn[T : Encode + Decode + Eq + @debug.Debug] compiler_facts_test_invalid_presence(
  value : T,
  offsets : Array[Int],
) -> Unit raise {
  compiler_facts_test_roundtrip(value)
  let encoded = compiler_facts_test_encode(value)
  for offset in offsets {
    assert_eq(encoded[offset], (0).to_byte())
    let bytes = encoded.to_array()
    bytes[offset] = 255
    let result : Result[(T, Int), BinaryDecodeError] = Decode::decode(
      Bytes::from_array(bytes),
      0,
    )
    match result {
      Err(error) =>
        assert_eq(error, BinaryDecodeError::InvalidCompilerFactsOptionTag)
      Ok(_) => fail("accepted invalid presence tag at byte \{offset}")
    }
  }
}

///|
test "compiler facts invalid presence tags propagate through nested record fields" {
  compiler_facts_test_invalid_presence(@representation.ValueFacts::new(), [
    0, 1, 2, 3, 4,
  ])
  compiler_facts_test_invalid_presence(@representation.FunctionFacts::new(0U), [
    1, 4, 5, 6,
  ])
  compiler_facts_test_invalid_presence(@representation.GlobalFacts::new(0U), [
    1, 2, 3,
  ])
  compiler_facts_test_invalid_presence(@representation.TableFacts::new(0U), [
    1, 2, 3,
  ])
  compiler_facts_test_invalid_presence(
    @representation.ProducerInfo::new("", ""),
    [2],
  )
  compiler_facts_test_invalid_presence(
    @representation.OptimizationFactsSec::new(),
    [0, 1],
  )
  compiler_facts_test_invalid_presence(@representation.AccessFacts::new(), [1])
}

///|
fn compiler_facts_test_raw_module(payload : Bytes) -> Bytes {
  // Independent single-section core Wasm framing: header, custom id, length,
  // then the 14-byte compiler.facts name and intentionally malformed payload.
  let bytes = b"\x00asm\x01\x00\x00\x00\x00".to_array()
  bytes.push((15 + payload.length()).to_byte())
  let name = b"\x0ecompiler.facts"
  for i in 0..<name.length() {
    bytes.push(name[i])
  }
  for i in 0..<payload.length() {
    bytes.push(payload[i])
  }
  Bytes::from_array(bytes)
}

///|
test "module decoder reports malformed compiler metadata with exact section boundaries" {
  for
    (payload, expected) in [
      (b"", BinaryDecodeError::TruncatedCompilerFactsPayload),
      (b"\x80", BinaryDecodeError::TruncatedCompilerFactsPayload),
      (b"\x02", BinaryDecodeError::UnsupportedCompilerFactsVersion),
      (b"\x01\xff", BinaryDecodeError::InvalidCompilerFactsOptionTag),
      (b"\x01\x01\x80", BinaryDecodeError::TruncatedCompilerFactsPayload),
      (b"\x01\x00\xff", BinaryDecodeError::InvalidCompilerFactsOptionTag),
      (
        b"\x01\x00\x01\x00\x00\xff",
        BinaryDecodeError::InvalidCompilerFactsOptionTag,
      ),
      (b"\x01\x00\x01\x80", BinaryDecodeError::TruncatedCompilerFactsPayload),
    ] {
    match decode_module(compiler_facts_test_raw_module(payload)) {
      Err(DecodeError::DecodeAt(error, offset, length)) => {
        assert_eq(error, expected)
        assert_eq(offset, 8)
        assert_eq(length, payload.length() + 17)
      }
      other => fail("malformed compiler metadata boundary: \{other}")
    }
  }
  let valid = compiler_facts_test_encode(
    @representation.CompilerFactCustomSection::new(
      @representation.OptimizationFactsSec::new(),
    ),
  )
  let malformed = valid.to_array()
  malformed.push(0)
  match
    decode_module(compiler_facts_test_raw_module(Bytes::from_array(malformed))) {
    Err(DecodeError::DecodeAt(CompilerFactsTrailingBytes, offset, _)) =>
      assert_eq(offset, 8)
    other => fail("accepted trailing compiler metadata: \{other}")
  }
}

///|
fn[T : Encode + Decode + Eq + @debug.Debug] compiler_facts_test_invalid_boolean(
  value : T,
  offsets : Array[Int],
) -> Unit raise {
  compiler_facts_test_roundtrip(value)
  let encoded = compiler_facts_test_encode(value)
  for offset in offsets {
    assert_eq(encoded[offset], (0).to_byte())
    let bytes = encoded.to_array()
    bytes[offset] = 255
    let result : Result[(T, Int), BinaryDecodeError] = Decode::decode(
      Bytes::from_array(bytes),
      0,
    )
    match result {
      Err(error) => assert_eq(error, BinaryDecodeError::InvalidBoolByte)
      Ok(_) => fail("accepted non-boolean compiler fact at byte \{offset}")
    }
  }
}

///|
test "compiler facts reject non-boolean bytes in boundary and completeness claims" {
  compiler_facts_test_invalid_boolean(
    @representation.WorldFacts::closed_module(
      host_can_call_exports=false,
      host_can_mutate_exported_state=false,
    ),
    [1, 2],
  )
  compiler_facts_test_invalid_boolean(
    @representation.FunctionBoundaryFacts::new(false, false, false),
    [0, 1, 2],
  )
  compiler_facts_test_invalid_boolean(@representation.FieldUsageFacts::new(), [
    0, 1,
  ])
  compiler_facts_test_invalid_boolean(@representation.SignatureFacts::new(0U), [
    3,
  ])
  compiler_facts_test_invalid_boolean(@representation.TableFacts::new(0U), [5])
  compiler_facts_test_invalid_boolean(@representation.AccessFacts::new(), [0])
}

///|
test "module codec rejects reserved raw metadata and duplicate compiler facts sections" {
  for
    (name, error) in [
      ("name", BinaryEncodeError::RawNameCustomSectionUnsupported),
      ("compiler.facts", BinaryEncodeError::ReservedCompilerFactsCustomSection),
    ] {
    assert_eq(
      encode_module(
        @lib.Module::new(custom_secs=[
          @lib.CustomSec::new(@lib.Name::new(name), b""),
        ]),
      ),
      Err(EncodeError::Encode(error)),
    )
  }
  let valid = compiler_facts_test_encode(
    @representation.CompilerFactCustomSection::new(
      @representation.OptimizationFactsSec::new(),
    ),
  )
  let first = compiler_facts_test_raw_module(valid)
  let duplicate = first.to_array()
  for i in 8..<first.length() {
    duplicate.push(first[i])
  }
  match decode_module(Bytes::from_array(duplicate)) {
    Err(DecodeError::DecodeAt(DuplicateCompilerFactsSection, offset, length)) => {
      assert_eq(offset, first.length())
      assert_eq(length, first.length() - 8)
    }
    other => fail("duplicate compiler metadata boundary: \{other}")
  }
}

///|
test "compiler facts reference discriminators retain nontrivial indices in canonical bytes" {
  let site = @representation.ValueSite::new(
    @representation.CodeSite::new(7U, 300U),
    result=2U,
  )
  for
    (value, expected) in [
      (@representation.ValueRef::site(site), b"\x00\x07\xac\x02\x02"),
      (
        @representation.ValueRef::parameter(
          @representation.ParameterRef::new(300U, 2U),
        ),
        b"\x01\xac\x02\x02",
      ),
      (
        @representation.ValueRef::function_result(
          @representation.FunctionResultRef::new(300U, 3U),
        ),
        b"\x02\xac\x02\x03",
      ),
      (@representation.ValueRef::global(300U), b"\x03\xac\x02"),
    ] {
    assert_eq(compiler_facts_test_encode(value), expected)
    compiler_facts_test_truncations(value)
  }
  for
    (value, expected) in [
      (@representation.AliasSource::parameter(300U), b"\x00\xac\x02"),
      (@representation.AliasSource::global(301U), b"\x01\xad\x02"),
      (@representation.AliasSource::site(site), b"\x02\x07\xac\x02\x02"),
    ] {
    assert_eq(compiler_facts_test_encode(value), expected)
    compiler_facts_test_truncations(value)
  }
}

///|
test "compiler facts allocation and subtype discriminators preserve their binary identities" {
  for
    (value, expected) in [
      (@representation.AllocationKind::struct_(300U), b"\x00\xac\x02"),
      (@representation.AllocationKind::array(300U), b"\x01\xac\x02"),
      (@representation.AllocationKind::box(300U), b"\x03\xac\x02"),
      (@representation.AllocationKind::closure(300U), b"\x02\xac\x02"),
      (@representation.AllocationKind::other_gc(300U), b"\x04\xac\x02"),
    ] {
    assert_eq(compiler_facts_test_encode(value), expected)
    compiler_facts_test_truncations(value)
  }
  let view = @representation.TypeView::subtype_closure(300U)
  assert_eq(compiler_facts_test_encode(view), b"\x01\xac\x02")
  compiler_facts_test_truncations(view)
  compiler_facts_test_truncations(
    @representation.HeapDomain::subtypes_of(@representation.FactHeapType::any()),
  )
  compiler_facts_test_truncations(@representation.WorldMode::open_world())
  compiler_facts_test_truncations(@representation.IntWidth::i16())
  compiler_facts_test_truncations(@representation.NullabilityFacts::null_only())
}

///|
test "compiler facts optimization hint wire identities preserve site targets and wide loop counts" {
  let site = @representation.CodeSite::new(7U, 300U)
  let site_target = @representation.HintTarget::site(site)
  let function_target = @representation.HintTarget::function(300U)
  for
    (value, expected) in [
      (
        @representation.OptimizationHint::hotness(
          site_target,
          @representation.TemperatureHint::cold(),
        ),
        b"\x00\x01\x07\xac\x02\x00",
      ),
      (
        @representation.OptimizationHint::inline_(
          site_target,
          @representation.InlinePolicy::default_(),
        ),
        b"\x01\x01\x07\xac\x02\x00",
      ),
      (
        @representation.OptimizationHint::goal(
          function_target,
          @representation.OptimizationGoal::prefer_speed(),
        ),
        b"\x02\x00\xac\x02\x00",
      ),
      (
        @representation.OptimizationHint::goal(
          site_target,
          @representation.OptimizationGoal::prefer_size(),
        ),
        b"\x02\x01\x07\xac\x02\x02",
      ),
      (
        @representation.OptimizationHint::branch_probability(site, 300U),
        b"\x03\x07\xac\x02\xac\x02",
      ),
      (
        @representation.OptimizationHint::estimated_loop_trips(
          site, 4294967296UL,
        ),
        b"\x04\x07\xac\x02\x80\x80\x80\x80\x10",
      ),
    ] {
    assert_eq(compiler_facts_test_encode(value), expected)
    compiler_facts_test_truncations(value)
  }
}
