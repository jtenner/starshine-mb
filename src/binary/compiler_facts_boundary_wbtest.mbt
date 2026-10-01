///|
// Every strict prefix is intentionally invalid: the complete value must decode,
// but a missing tag, length, scalar byte, or nested record must never be accepted.
fn[T : Encode + Decode + Eq + @debug.Debug] compiler_facts_test_truncations(
  value : T,
) -> Unit raise {
  compiler_facts_test_roundtrip(value)
  let bytes = compiler_facts_test_encode(value)
  for end in 0..<bytes.length() {
    let result : Result[(T, Int), BinaryDecodeError] = Decode::decode(
      bytes[:end].to_owned(),
      0,
    )
    match result {
      Err(_) => ()
      Ok(_) => fail("accepted truncated compiler facts at byte \{end}")
    }
  }
}

///|
test "compiler facts invalid truncated payloads reject every strict prefix" {
  compiler_facts_test_truncations(compiler_facts_test_everything_section())
  compiler_facts_test_truncations(
    @representation.CompilerFactCustomSection::new(
      @representation.OptimizationFactsSec::new(),
    ),
  )
}

///|
test "compiler facts scalar payloads preserve float bits and heap discriminators" {
  for
    value in [
      @representation.FactValue::f32_bits(0x80000000U),
      @representation.FactValue::f32_bits(0x7FC01234U),
      @representation.FactValue::f64_bits(0x8000000000000000UL),
      @representation.FactValue::f64_bits(0x7FF8000000001234UL),
      @representation.FactValue::v128(
        @representation.V128Bits::new(
          0xFEDCBA9876543210UL, 0x0123456789ABCDEFUL,
        ),
      ),
      @representation.FactValue::immutable_global(300U),
    ] {
    compiler_facts_test_truncations(value)
  }
  let heaps = [
    @representation.FactHeapType::any(),
    @representation.FactHeapType::eq(),
    @representation.FactHeapType::struct_(),
    @representation.FactHeapType::array(),
    @representation.FactHeapType::i31(),
    @representation.FactHeapType::func(),
    @representation.FactHeapType::extern_(),
    @representation.FactHeapType::exn(),
    @representation.FactHeapType::cont(),
    @representation.FactHeapType::string(),
    @representation.FactHeapType::none(),
    @representation.FactHeapType::no_func(),
    @representation.FactHeapType::no_extern(),
    @representation.FactHeapType::no_exn(),
    @representation.FactHeapType::no_cont(),
  ]
  for index, heap in heaps {
    @debug.assert_eq(
      compiler_facts_test_encode(heap),
      Bytes::from_array([(index + 1).to_byte()]),
    )
    compiler_facts_test_truncations(@representation.FactValue::ref_null(heap))
  }
}

///|
test "compiler facts vector and floating facts preserve masks and lane shapes" {
  for
    width in [
      @representation.FloatWidth::f32(),
      @representation.FloatWidth::f64(),
    ] {
    compiler_facts_test_truncations(
      @representation.FloatFacts::new(
        width,
        @representation.FloatClassMask::negative_zero().union(
          @representation.FloatClassMask::nan(),
        ),
      ),
    )
  }
  for
    shape in [
      @representation.VectorLaneShape::i8x16(),
      @representation.VectorLaneShape::i16x8(),
      @representation.VectorLaneShape::i32x4(),
      @representation.VectorLaneShape::i64x2(),
      @representation.VectorLaneShape::f32x4(),
      @representation.VectorLaneShape::f64x2(),
    ] {
    compiler_facts_test_truncations(shape)
  }
  compiler_facts_test_truncations(
    @representation.VectorFacts::new(
      known_bits=Some(
        @representation.KnownV128Bits::new(
          @representation.V128Bits::new(
            0x7FFFFFFF7FFFFFFFUL, 0x7FFFFFFF7FFFFFFFUL,
          ),
          @representation.V128Bits::new(
            0x8000000080000000UL, 0x8000000080000000UL,
          ),
        ),
      ),
      splat=Some(@representation.FactValue::f32_bits(0x80000000U)),
      lane_shape=Some(@representation.VectorLaneShape::f32x4()),
    ),
  )
}
