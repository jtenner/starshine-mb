///|
fn decode_compiler_fact_uint(
  bytes : Bytes,
  index : Int,
) -> Result[(UInt, Int), BinaryDecodeError] {
  match
    (Decode::decode(bytes, index) : Result[(@lib.U32, Int), BinaryDecodeError]) {
    Ok((@lib.U32(value), next)) => Ok((value, next))
    Err(err) => Err(err)
  }
}

///|
fn decode_compiler_fact_uint64(
  bytes : Bytes,
  index : Int,
) -> Result[(UInt64, Int), BinaryDecodeError] {
  match
    (Decode::decode(bytes, index) : Result[(@lib.U64, Int), BinaryDecodeError]) {
    Ok((@lib.U64(value), next)) => Ok((value, next))
    Err(err) => Err(err)
  }
}

///|
fn decode_compiler_fact_int64(
  bytes : Bytes,
  index : Int,
) -> Result[(Int64, Int), BinaryDecodeError] {
  match
    (Decode::decode(bytes, index) : Result[(@lib.I64, Int), BinaryDecodeError]) {
    Ok((@lib.I64(value), next)) => Ok((value, next))
    Err(err) => Err(err)
  }
}

///|
fn decode_compiler_fact_string(
  bytes : Bytes,
  index : Int,
) -> Result[(String, Int), BinaryDecodeError] {
  match
    (Decode::decode(bytes, index) : Result[(@lib.Name, Int), BinaryDecodeError]) {
    Ok((@lib.Name(value), next)) => Ok((value.to_owned(), next))
    Err(err) => Err(err)
  }
}

///|
fn[T : Decode] decode_compiler_fact_option(
  bytes : Bytes,
  index : Int,
) -> Result[(T?, Int), BinaryDecodeError] {
  match bytes.get(index) {
    Some(0x00) => Ok((None, index + 1))
    Some(0x01) =>
      match T::decode(bytes, index + 1) {
        Ok((value, next)) => Ok((Some(value), next))
        Err(err) => Err(err)
      }
    Some(_) => Err(BinaryDecodeError::InvalidCompilerFactsOptionTag)
    None => Err(BinaryDecodeError::TruncatedCompilerFactsPayload)
  }
}

///|
fn decode_compiler_fact_uint_option(
  bytes : Bytes,
  index : Int,
) -> Result[(UInt?, Int), BinaryDecodeError] {
  match bytes.get(index) {
    Some(0x00) => Ok((None, index + 1))
    Some(0x01) =>
      match decode_compiler_fact_uint(bytes, index + 1) {
        Ok((value, next)) => Ok((Some(value), next))
        Err(err) => Err(err)
      }
    Some(_) => Err(BinaryDecodeError::InvalidCompilerFactsOptionTag)
    None => Err(BinaryDecodeError::TruncatedCompilerFactsPayload)
  }
}

///|
fn decode_compiler_fact_uint64_option(
  bytes : Bytes,
  index : Int,
) -> Result[(UInt64?, Int), BinaryDecodeError] {
  match bytes.get(index) {
    Some(0x00) => Ok((None, index + 1))
    Some(0x01) =>
      match decode_compiler_fact_uint64(bytes, index + 1) {
        Ok((value, next)) => Ok((Some(value), next))
        Err(err) => Err(err)
      }
    Some(_) => Err(BinaryDecodeError::InvalidCompilerFactsOptionTag)
    None => Err(BinaryDecodeError::TruncatedCompilerFactsPayload)
  }
}

///|
fn decode_compiler_fact_uint_array(
  bytes : Bytes,
  index : Int,
) -> Result[(Array[UInt], Int), BinaryDecodeError] {
  let (count, decoded_start) = match decode_compiler_fact_uint(bytes, index) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let values : Array[UInt] = []
  let mut next = decoded_start
  let mut remaining = count
  while remaining > 0U {
    let (value, decoded_next) = match decode_compiler_fact_uint(bytes, next) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    values.push(value)
    next = decoded_next
    remaining -= 1U
  }
  Ok((values, next))
}

///|
fn compiler_facts_payload_error(err : BinaryDecodeError) -> BinaryDecodeError {
  match err {
    IndexOutOfBounds
    | UnexpectedEofInUnsignedLeb
    | UnexpectedEofInSignedLeb
    | TruncatedCompilerFactsPayload => TruncatedCompilerFactsPayload
    _ => err
  }
}

///|
pub impl Decode for CompilerFactCustomSection with fn decode(bytes, index) {
  let (version, next) = match decode_compiler_fact_uint(bytes, index) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if version != 1U {
    return Err(BinaryDecodeError::UnsupportedCompilerFactsVersion)
  }
  let (module_fingerprint, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(Bytes?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (facts, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(OptimizationFactsSec, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(
    (CompilerFactCustomSection::new(facts, version~, module_fingerprint~), next),
  )
}

///|
pub impl Decode for ProducerInfo with fn decode(bytes, index) {
  let (name, next) = match decode_compiler_fact_string(bytes, index) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (version, next) = match decode_compiler_fact_string(bytes, next) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (build_id, next) = match bytes.get(next) {
    Some(0x00) => (None, next + 1)
    Some(0x01) =>
      match decode_compiler_fact_string(bytes, next + 1) {
        Ok((v, n)) => (Some(v), n)
        Err(e) => return Err(e)
      }
    Some(_) => return Err(BinaryDecodeError::InvalidCompilerFactsOptionTag)
    None => return Err(BinaryDecodeError::TruncatedCompilerFactsPayload)
  }
  Ok((ProducerInfo::new(name, version, build_id~), next))
}

///|
pub impl Decode for WorldMode with fn decode(bytes, index) {
  match bytes.get(index) {
    Some(0x00) => Ok((WorldMode::open_world(), index + 1))
    Some(0x01) => Ok((WorldMode::closed_module(), index + 1))
    Some(0x02) => Ok((WorldMode::closed_program(), index + 1))
    Some(_) => Err(BinaryDecodeError::InvalidCompilerFactsEnumTag)
    None => Err(BinaryDecodeError::TruncatedCompilerFactsPayload)
  }
}

///|
pub impl Decode for WorldFacts with fn decode(bytes, index) {
  let (mode, next) = match
    (Decode::decode(bytes, index) : Result[(WorldMode, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (host_can_call_exports, next) = match
    (Decode::decode(bytes, next) : Result[(Bool, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (host_can_mutate_exported_state, next) = match
    (Decode::decode(bytes, next) : Result[(Bool, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(
    (
      WorldFacts::new(
        mode, host_can_call_exports, host_can_mutate_exported_state,
      ),
      next,
    ),
  )
}

///|
pub impl Decode for OptimizationFactsSec with fn decode(bytes, index) {
  let (producer, next) = match
    (
      decode_compiler_fact_option(bytes, index) :
      Result[(ProducerInfo?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (world, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(WorldFacts?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (functions, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(Array[FunctionFacts], Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (signatures, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(Array[SignatureFacts], Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (types, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(Array[TypeFacts], Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (globals, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(Array[GlobalFacts], Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (tables, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(Array[TableFacts], Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (bodies, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(Array[FunctionBodyFacts], Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (hints, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(Array[OptimizationHint], Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(
    (
      OptimizationFactsSec::new(
        producer~,
        world~,
        functions~,
        signatures~,
        types~,
        globals~,
        tables~,
        bodies~,
        hints~,
      ),
      next,
    ),
  )
}

///|
pub impl Decode for CodeSite with fn decode(bytes, index) {
  let (function, next) = match decode_compiler_fact_uint(bytes, index) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (offset, next) = match decode_compiler_fact_uint(bytes, next) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((CodeSite::new(function, offset), next))
}

///|
pub impl Decode for ValueSite with fn decode(bytes, index) {
  let (site, next) = match
    (Decode::decode(bytes, index) : Result[(CodeSite, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (result, next) = match decode_compiler_fact_uint(bytes, next) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((ValueSite::new(site, result~), next))
}

///|
pub impl Decode for SourceProvenance with fn decode(bytes, index) {
  let (module_id, next) = match
    decode_compiler_fact_uint64_option(bytes, index) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (declaration_id, next) = match
    decode_compiler_fact_uint64_option(bytes, next) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (body_id, next) = match decode_compiler_fact_uint64_option(bytes, next) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (expression_id, next) = match
    decode_compiler_fact_uint64_option(bytes, next) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (source_offset, next) = match
    decode_compiler_fact_uint64_option(bytes, next) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (specialization_id, next) = match
    decode_compiler_fact_uint64_option(bytes, next) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(
    (
      SourceProvenance::new(
        module_id~,
        declaration_id~,
        body_id~,
        expression_id~,
        source_offset~,
        specialization_id~,
      ),
      next,
    ),
  )
}

///|
pub impl Decode for IntWidth with fn decode(bytes, index) {
  match bytes.get(index) {
    Some(0x00) => Ok((IntWidth::i8(), index + 1))
    Some(0x01) => Ok((IntWidth::i16(), index + 1))
    Some(0x02) => Ok((IntWidth::i32(), index + 1))
    Some(0x03) => Ok((IntWidth::i64(), index + 1))
    Some(_) => Err(BinaryDecodeError::InvalidCompilerFactsEnumTag)
    None => Err(BinaryDecodeError::TruncatedCompilerFactsPayload)
  }
}

///|
pub impl Decode for IntConstant with fn decode(bytes, index) {
  let (width, next) = match
    (Decode::decode(bytes, index) : Result[(IntWidth, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (bits, next) = match decode_compiler_fact_uint64(bytes, next) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((IntConstant::new(width, bits), next))
}

///|
pub impl Decode for V128Bits with fn decode(bytes, index) {
  let (low, next) = match decode_compiler_fact_uint64(bytes, index) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (high, next) = match decode_compiler_fact_uint64(bytes, next) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((V128Bits::new(low, high), next))
}

///|
pub impl Decode for FactHeapType with fn decode(bytes, index) {
  match bytes.get(index) {
    Some(0x00) =>
      match decode_compiler_fact_uint(bytes, index + 1) {
        Ok((v, n)) => Ok((FactHeapType::type_index(v), n))
        Err(e) => Err(e)
      }
    Some(0x01) => Ok((FactHeapType::any(), index + 1))
    Some(0x02) => Ok((FactHeapType::eq(), index + 1))
    Some(0x03) => Ok((FactHeapType::struct_(), index + 1))
    Some(0x04) => Ok((FactHeapType::array(), index + 1))
    Some(0x05) => Ok((FactHeapType::i31(), index + 1))
    Some(0x06) => Ok((FactHeapType::func(), index + 1))
    Some(0x07) => Ok((FactHeapType::extern_(), index + 1))
    Some(0x08) => Ok((FactHeapType::exn(), index + 1))
    Some(0x09) => Ok((FactHeapType::cont(), index + 1))
    Some(0x0A) => Ok((FactHeapType::string(), index + 1))
    Some(0x0B) => Ok((FactHeapType::none(), index + 1))
    Some(0x0C) => Ok((FactHeapType::no_func(), index + 1))
    Some(0x0D) => Ok((FactHeapType::no_extern(), index + 1))
    Some(0x0E) => Ok((FactHeapType::no_exn(), index + 1))
    Some(0x0F) => Ok((FactHeapType::no_cont(), index + 1))
    Some(_) => Err(BinaryDecodeError::InvalidCompilerFactsEnumTag)
    None => Err(BinaryDecodeError::TruncatedCompilerFactsPayload)
  }
}

///|
pub impl Decode for FactValue with fn decode(bytes, index) {
  match bytes.get(index) {
    Some(0x00) =>
      match
        (
          Decode::decode(bytes, index + 1) :
          Result[(IntConstant, Int), BinaryDecodeError]) {
        Ok((v, n)) => Ok((FactValue::integer(v), n))
        Err(e) => Err(e)
      }
    Some(0x01) =>
      match decode_compiler_fact_uint(bytes, index + 1) {
        Ok((v, n)) => Ok((FactValue::f32_bits(v), n))
        Err(e) => Err(e)
      }
    Some(0x02) =>
      match decode_compiler_fact_uint64(bytes, index + 1) {
        Ok((v, n)) => Ok((FactValue::f64_bits(v), n))
        Err(e) => Err(e)
      }
    Some(0x03) =>
      match
        (
          Decode::decode(bytes, index + 1) :
          Result[(V128Bits, Int), BinaryDecodeError]) {
        Ok((v, n)) => Ok((FactValue::v128(v), n))
        Err(e) => Err(e)
      }
    Some(0x04) =>
      match
        (
          Decode::decode(bytes, index + 1) :
          Result[(FactHeapType, Int), BinaryDecodeError]) {
        Ok((v, n)) => Ok((FactValue::ref_null(v), n))
        Err(e) => Err(e)
      }
    Some(0x05) =>
      match decode_compiler_fact_uint(bytes, index + 1) {
        Ok((v, n)) => Ok((FactValue::ref_func(v), n))
        Err(e) => Err(e)
      }
    Some(0x06) =>
      match decode_compiler_fact_uint(bytes, index + 1) {
        Ok((v, n)) => Ok((FactValue::immutable_global(v), n))
        Err(e) => Err(e)
      }
    Some(_) => Err(BinaryDecodeError::InvalidCompilerFactsEnumTag)
    None => Err(BinaryDecodeError::TruncatedCompilerFactsPayload)
  }
}

///|
pub impl Decode for ClosedValueSet with fn decode(bytes, index) {
  match
    (
      Decode::decode(bytes, index) :
      Result[(Array[FactValue], Int), BinaryDecodeError]) {
    Ok((values, next)) => Ok((ClosedValueSet::new(values), next))
    Err(err) => Err(err)
  }
}

///|
pub impl Decode for SignedRange with fn decode(bytes, index) {
  let (min, next) = match decode_compiler_fact_int64(bytes, index) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (max, next) = match decode_compiler_fact_int64(bytes, next) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((SignedRange::new(min, max), next))
}

///|
pub impl Decode for UnsignedRange with fn decode(bytes, index) {
  let (min, next) = match decode_compiler_fact_uint64(bytes, index) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (max, next) = match decode_compiler_fact_uint64(bytes, next) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((UnsignedRange::new(min, max), next))
}

///|
pub impl Decode for KnownBits with fn decode(bytes, index) {
  let (known_zero, next) = match decode_compiler_fact_uint64(bytes, index) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (known_one, next) = match decode_compiler_fact_uint64(bytes, next) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((KnownBits::new(known_zero, known_one), next))
}

///|
pub impl Decode for IntegerFacts with fn decode(bytes, index) {
  let (width, next) = match
    (Decode::decode(bytes, index) : Result[(IntWidth, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (unsigned_range, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(UnsignedRange?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (signed_range, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(SignedRange?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (known_bits, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(KnownBits?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (nonzero, next) = match
    (Decode::decode(bytes, next) : Result[(Bool, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(
    (
      IntegerFacts::new(
        width,
        unsigned_range~,
        signed_range~,
        known_bits~,
        nonzero~,
      ),
      next,
    ),
  )
}

///|
pub impl Decode for FloatWidth with fn decode(bytes, index) {
  match bytes.get(index) {
    Some(0x00) => Ok((FloatWidth::f32(), index + 1))
    Some(0x01) => Ok((FloatWidth::f64(), index + 1))
    Some(_) => Err(BinaryDecodeError::InvalidCompilerFactsEnumTag)
    None => Err(BinaryDecodeError::TruncatedCompilerFactsPayload)
  }
}

///|
pub impl Decode for FloatClassMask with fn decode(bytes, index) {
  match decode_compiler_fact_uint(bytes, index) {
    Ok((bits, next)) => Ok((FloatClassMask::from_bits(bits), next))
    Err(err) => Err(err)
  }
}

///|
pub impl Decode for FloatFacts with fn decode(bytes, index) {
  let (width, next) = match
    (Decode::decode(bytes, index) : Result[(FloatWidth, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (possible_classes, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(FloatClassMask, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((FloatFacts::new(width, possible_classes), next))
}

///|
pub impl Decode for NullabilityFacts with fn decode(bytes, index) {
  match bytes.get(index) {
    Some(0x00) => Ok((NullabilityFacts::null_only(), index + 1))
    Some(0x01) => Ok((NullabilityFacts::non_null(), index + 1))
    Some(_) => Err(BinaryDecodeError::InvalidCompilerFactsEnumTag)
    None => Err(BinaryDecodeError::TruncatedCompilerFactsPayload)
  }
}

///|
pub impl Decode for ClosedHeapTypeSet with fn decode(bytes, index) {
  match
    (
      Decode::decode(bytes, index) :
      Result[(Array[FactHeapType], Int), BinaryDecodeError]) {
    Ok((values, next)) => Ok((ClosedHeapTypeSet::new(values), next))
    Err(err) => Err(err)
  }
}

///|
pub impl Decode for HeapDomain with fn decode(bytes, index) {
  let tag = match bytes.get(index) {
    Some(v) => v
    None => return Err(BinaryDecodeError::TruncatedCompilerFactsPayload)
  }
  match tag {
    0x00 | 0x01 =>
      match
        (
          Decode::decode(bytes, index + 1) :
          Result[(FactHeapType, Int), BinaryDecodeError]) {
        Ok((type_, next)) =>
          Ok(
            (
              if tag == 0x00 {
                HeapDomain::exact_runtime_type(type_)
              } else {
                HeapDomain::subtypes_of(type_)
              },
              next,
            ),
          )
        Err(err) => Err(err)
      }
    0x02 =>
      match
        (
          Decode::decode(bytes, index + 1) :
          Result[(ClosedHeapTypeSet, Int), BinaryDecodeError]) {
        Ok((v, n)) => Ok((HeapDomain::closed_runtime_types(v), n))
        Err(e) => Err(e)
      }
    _ => Err(BinaryDecodeError::InvalidCompilerFactsEnumTag)
  }
}

///|
pub impl Decode for ReferenceFacts with fn decode(bytes, index) {
  let (nullability, next) = match
    (
      decode_compiler_fact_option(bytes, index) :
      Result[(NullabilityFacts?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (heap, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(HeapDomain?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (function_targets, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ClosedFunctionSet?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((ReferenceFacts::new(nullability~, heap~, function_targets~), next))
}

///|
pub impl Decode for VectorLaneShape with fn decode(bytes, index) {
  match bytes.get(index) {
    Some(0x00) => Ok((VectorLaneShape::i8x16(), index + 1))
    Some(0x01) => Ok((VectorLaneShape::i16x8(), index + 1))
    Some(0x02) => Ok((VectorLaneShape::i32x4(), index + 1))
    Some(0x03) => Ok((VectorLaneShape::i64x2(), index + 1))
    Some(0x04) => Ok((VectorLaneShape::f32x4(), index + 1))
    Some(0x05) => Ok((VectorLaneShape::f64x2(), index + 1))
    Some(_) => Err(BinaryDecodeError::InvalidCompilerFactsEnumTag)
    None => Err(BinaryDecodeError::TruncatedCompilerFactsPayload)
  }
}

///|
pub impl Decode for KnownV128Bits with fn decode(bytes, index) {
  let (known_zero, next) = match
    (Decode::decode(bytes, index) : Result[(V128Bits, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (known_one, next) = match
    (Decode::decode(bytes, next) : Result[(V128Bits, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((KnownV128Bits::new(known_zero, known_one), next))
}

///|
pub impl Decode for VectorFacts with fn decode(bytes, index) {
  let (known_bits, next) = match
    (
      decode_compiler_fact_option(bytes, index) :
      Result[(KnownV128Bits?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (splat, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(FactValue?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (lane_shape, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(VectorLaneShape?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((VectorFacts::new(known_bits~, splat~, lane_shape~), next))
}

///|
pub impl Decode for ValueFacts with fn decode(bytes, index) {
  let (possible_values, next) = match
    (
      decode_compiler_fact_option(bytes, index) :
      Result[(ClosedValueSet?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (integer, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(IntegerFacts?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (float_, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(FloatFacts?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (vector, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(VectorFacts?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (reference, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ReferenceFacts?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(
    (
      ValueFacts::new(possible_values~, integer~, float_~, vector~, reference~),
      next,
    ),
  )
}

///|
pub impl Decode for ParameterRef with fn decode(bytes, index) {
  let (function, next) = match decode_compiler_fact_uint(bytes, index) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (parameter, next) = match decode_compiler_fact_uint(bytes, next) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((ParameterRef::new(function, parameter), next))
}

///|
pub impl Decode for FunctionResultRef with fn decode(bytes, index) {
  let (function, next) = match decode_compiler_fact_uint(bytes, index) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (result, next) = match decode_compiler_fact_uint(bytes, next) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((FunctionResultRef::new(function, result), next))
}

///|
pub impl Decode for ValueRef with fn decode(bytes, index) {
  match bytes.get(index) {
    Some(0x00) =>
      match
        (
          Decode::decode(bytes, index + 1) :
          Result[(ValueSite, Int), BinaryDecodeError]) {
        Ok((v, n)) => Ok((ValueRef::site(v), n))
        Err(e) => Err(e)
      }
    Some(0x01) =>
      match
        (
          Decode::decode(bytes, index + 1) :
          Result[(ParameterRef, Int), BinaryDecodeError]) {
        Ok((v, n)) => Ok((ValueRef::parameter(v), n))
        Err(e) => Err(e)
      }
    Some(0x02) =>
      match
        (
          Decode::decode(bytes, index + 1) :
          Result[(FunctionResultRef, Int), BinaryDecodeError]) {
        Ok((v, n)) => Ok((ValueRef::function_result(v), n))
        Err(e) => Err(e)
      }
    Some(0x03) =>
      match decode_compiler_fact_uint(bytes, index + 1) {
        Ok((v, n)) => Ok((ValueRef::global(v), n))
        Err(e) => Err(e)
      }
    Some(_) => Err(BinaryDecodeError::InvalidCompilerFactsEnumTag)
    None => Err(BinaryDecodeError::TruncatedCompilerFactsPayload)
  }
}

///|
pub impl Decode for AliasSource with fn decode(bytes, index) {
  match bytes.get(index) {
    Some(0x00) =>
      match decode_compiler_fact_uint(bytes, index + 1) {
        Ok((v, n)) => Ok((AliasSource::parameter(v), n))
        Err(e) => Err(e)
      }
    Some(0x01) =>
      match decode_compiler_fact_uint(bytes, index + 1) {
        Ok((v, n)) => Ok((AliasSource::global(v), n))
        Err(e) => Err(e)
      }
    Some(0x02) =>
      match
        (
          Decode::decode(bytes, index + 1) :
          Result[(ValueSite, Int), BinaryDecodeError]) {
        Ok((v, n)) => Ok((AliasSource::site(v), n))
        Err(e) => Err(e)
      }
    Some(_) => Err(BinaryDecodeError::InvalidCompilerFactsEnumTag)
    None => Err(BinaryDecodeError::TruncatedCompilerFactsPayload)
  }
}

///|
pub impl Decode for ClosedAliasSet with fn decode(bytes, index) {
  match
    (
      Decode::decode(bytes, index) :
      Result[(Array[AliasSource], Int), BinaryDecodeError]) {
    Ok((values, next)) => Ok((ClosedAliasSet::new(values), next))
    Err(err) => Err(err)
  }
}

///|
pub impl Decode for ResultIdentityFacts with fn decode(bytes, index) {
  match bytes.get(index) {
    Some(0x00) => Ok((ResultIdentityFacts::fresh(), index + 1))
    Some(0x01) =>
      match
        (
          Decode::decode(bytes, index + 1) :
          Result[(ClosedAliasSet, Int), BinaryDecodeError]) {
        Ok((v, n)) => Ok((ResultIdentityFacts::closed_aliases(v), n))
        Err(e) => Err(e)
      }
    Some(_) => Err(BinaryDecodeError::InvalidCompilerFactsEnumTag)
    None => Err(BinaryDecodeError::TruncatedCompilerFactsPayload)
  }
}

///|
pub impl Decode for ParameterFacts with fn decode(bytes, index) {
  let (parameter, next) = match decode_compiler_fact_uint(bytes, index) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (value, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ValueFacts?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (uses, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ParameterUseMask?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (escape_sinks, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(EscapeSinkMask?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((ParameterFacts::new(parameter, value~, uses~, escape_sinks~), next))
}

///|
pub impl Decode for ResultFacts with fn decode(bytes, index) {
  let (result, next) = match decode_compiler_fact_uint(bytes, index) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (value, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ValueFacts?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (identity, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ResultIdentityFacts?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((ResultFacts::new(result, value~, identity~), next))
}

///|
pub impl Decode for ParameterUseMask with fn decode(bytes, index) {
  match decode_compiler_fact_uint64(bytes, index) {
    Ok((v, n)) => Ok((ParameterUseMask::from_bits(v), n))
    Err(e) => Err(e)
  }
}

///|
pub impl Decode for EscapeSinkMask with fn decode(bytes, index) {
  match decode_compiler_fact_uint64(bytes, index) {
    Ok((v, n)) => Ok((EscapeSinkMask::from_bits(v), n))
    Err(e) => Err(e)
  }
}

///|
pub impl Decode for EffectMask with fn decode(bytes, index) {
  match decode_compiler_fact_uint64(bytes, index) {
    Ok((v, n)) => Ok((EffectMask::from_bits(v), n))
    Err(e) => Err(e)
  }
}

///|
pub impl Decode for ClosedGlobalSet with fn decode(bytes, index) {
  match decode_compiler_fact_uint_array(bytes, index) {
    Ok((v, n)) => Ok((ClosedGlobalSet::new(v), n))
    Err(e) => Err(e)
  }
}

///|
pub impl Decode for ClosedMemorySet with fn decode(bytes, index) {
  match decode_compiler_fact_uint_array(bytes, index) {
    Ok((v, n)) => Ok((ClosedMemorySet::new(v), n))
    Err(e) => Err(e)
  }
}

///|
pub impl Decode for ClosedTableSet with fn decode(bytes, index) {
  match decode_compiler_fact_uint_array(bytes, index) {
    Ok((v, n)) => Ok((ClosedTableSet::new(v), n))
    Err(e) => Err(e)
  }
}

///|
pub impl Decode for ClosedTypeViewSet with fn decode(bytes, index) {
  match decode_compiler_fact_uint_array(bytes, index) {
    Ok((v, n)) => Ok((ClosedTypeViewSet::new(v), n))
    Err(e) => Err(e)
  }
}

///|
pub impl Decode for ClosedFunctionSet with fn decode(bytes, index) {
  match decode_compiler_fact_uint_array(bytes, index) {
    Ok((v, n)) => Ok((ClosedFunctionSet::new(v), n))
    Err(e) => Err(e)
  }
}

///|
pub impl Decode for EffectFacts with fn decode(bytes, index) {
  let (may, next) = match
    (Decode::decode(bytes, index) : Result[(EffectMask, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (read_globals, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ClosedGlobalSet?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (written_globals, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ClosedGlobalSet?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (read_memories, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ClosedMemorySet?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (written_memories, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ClosedMemorySet?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (read_tables, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ClosedTableSet?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (written_tables, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ClosedTableSet?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (read_heap_types, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ClosedTypeViewSet?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (written_heap_types, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ClosedTypeViewSet?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (direct_callees, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ClosedFunctionSet?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(
    (
      EffectFacts::new(
        may,
        read_globals~,
        written_globals~,
        read_memories~,
        written_memories~,
        read_tables~,
        written_tables~,
        read_heap_types~,
        written_heap_types~,
        direct_callees~,
      ),
      next,
    ),
  )
}

///|
pub impl Decode for FunctionBoundaryFacts with fn decode(bytes, index) {
  let (all_call_sites_known, next) = match
    (Decode::decode(bytes, index) : Result[(Bool, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (address_taken, next) = match
    (Decode::decode(bytes, next) : Result[(Bool, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (host_callable, next) = match
    (Decode::decode(bytes, next) : Result[(Bool, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(
    (
      FunctionBoundaryFacts::new(
        all_call_sites_known, address_taken, host_callable,
      ),
      next,
    ),
  )
}

///|
pub impl Decode for FunctionProfile with fn decode(bytes, index) {
  let (entry_count, next) = match
    decode_compiler_fact_uint64_option(bytes, index) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (temperature, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(TemperatureHint?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((FunctionProfile::new(entry_count~, temperature~), next))
}

///|
pub impl Decode for CallProfile with fn decode(bytes, index) {
  let (count, next) = match decode_compiler_fact_uint64_option(bytes, index) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (temperature, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(TemperatureHint?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((CallProfile::new(count~, temperature~), next))
}

///|
pub impl Decode for BranchProfile with fn decode(bytes, index) {
  let (taken, next) = match decode_compiler_fact_uint64(bytes, index) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (not_taken, next) = match decode_compiler_fact_uint64(bytes, next) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((BranchProfile::new(taken, not_taken), next))
}

///|
pub impl Decode for LoopProfile with fn decode(bytes, index) {
  let (backedge_count, next) = match
    decode_compiler_fact_uint64_option(bytes, index) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (estimated_trip_count, next) = match
    decode_compiler_fact_uint64_option(bytes, next) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((LoopProfile::new(backedge_count~, estimated_trip_count~), next))
}

///|
pub impl Decode for TemperatureHint with fn decode(bytes, index) {
  match bytes.get(index) {
    Some(0x00) => Ok((TemperatureHint::cold(), index + 1))
    Some(0x01) => Ok((TemperatureHint::normal(), index + 1))
    Some(0x02) => Ok((TemperatureHint::hot(), index + 1))
    Some(_) => Err(BinaryDecodeError::InvalidCompilerFactsEnumTag)
    None => Err(BinaryDecodeError::TruncatedCompilerFactsPayload)
  }
}

///|
pub impl Decode for InlinePolicy with fn decode(bytes, index) {
  match bytes.get(index) {
    Some(0x00) => Ok((InlinePolicy::default_(), index + 1))
    Some(0x01) => Ok((InlinePolicy::never(), index + 1))
    Some(0x02) => Ok((InlinePolicy::prefer(), index + 1))
    Some(0x03) => Ok((InlinePolicy::always(), index + 1))
    Some(_) => Err(BinaryDecodeError::InvalidCompilerFactsEnumTag)
    None => Err(BinaryDecodeError::TruncatedCompilerFactsPayload)
  }
}

///|
pub impl Decode for FunctionFacts with fn decode(bytes, index) {
  let (function, next) = match decode_compiler_fact_uint(bytes, index) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (effects, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(EffectFacts?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (parameters, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(Array[ParameterFacts], Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (results, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(Array[ResultFacts], Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (boundary, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(FunctionBoundaryFacts?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (profile, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(FunctionProfile?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (inline_policy, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(InlinePolicy?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(
    (
      FunctionFacts::new(
        function,
        effects~,
        parameters~,
        results~,
        boundary~,
        profile~,
        inline_policy~,
      ),
      next,
    ),
  )
}

///|
pub impl Decode for IndexedValueFacts with fn decode(bytes, index) {
  let (value_index, next) = match decode_compiler_fact_uint(bytes, index) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (value, next) = match
    (Decode::decode(bytes, next) : Result[(ValueFacts, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((IndexedValueFacts::new(value_index, value), next))
}

///|
pub impl Decode for SignatureFacts with fn decode(bytes, index) {
  let (signature, next) = match decode_compiler_fact_uint(bytes, index) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (parameters, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(Array[IndexedValueFacts], Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (results, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(Array[IndexedValueFacts], Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (complete, next) = match
    (Decode::decode(bytes, next) : Result[(Bool, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(
    (
      SignatureFacts::new(
        signature,
        parameters~,
        results~,
        call_sites_complete=complete,
      ),
      next,
    ),
  )
}

///|
pub impl Decode for TypeView with fn decode(bytes, index) {
  let tag = match bytes.get(index) {
    Some(v) => v
    None => return Err(BinaryDecodeError::TruncatedCompilerFactsPayload)
  }
  if tag > 0x01 {
    return Err(BinaryDecodeError::InvalidCompilerFactsEnumTag)
  }
  match decode_compiler_fact_uint(bytes, index + 1) {
    Ok((type_, next)) =>
      Ok(
        (
          if tag == 0x00 {
            TypeView::exact(type_)
          } else {
            TypeView::subtype_closure(type_)
          },
          next,
        ),
      )
    Err(err) => Err(err)
  }
}

///|
pub impl Decode for TypePopulation with fn decode(bytes, index) {
  match bytes.get(index) {
    Some(0x00) => Ok((TypePopulation::empty(), index + 1))
    Some(0x01) =>
      match
        (
          Decode::decode(bytes, index + 1) :
          Result[(ClosedHeapTypeSet, Int), BinaryDecodeError]) {
        Ok((v, n)) => Ok((TypePopulation::closed(v), n))
        Err(e) => Err(e)
      }
    Some(_) => Err(BinaryDecodeError::InvalidCompilerFactsEnumTag)
    None => Err(BinaryDecodeError::TruncatedCompilerFactsPayload)
  }
}

///|
pub impl Decode for WriteFacts with fn decode(bytes, index) {
  match bytes.get(index) {
    Some(0x00) => Ok((WriteFacts::no_writes(), index + 1))
    Some(0x01) => Ok((WriteFacts::initialization_only(), index + 1))
    Some(0x02) =>
      match
        (
          Decode::decode(bytes, index + 1) :
          Result[(Array[CodeSite], Int), BinaryDecodeError]) {
        Ok((v, n)) => Ok((WriteFacts::closed(v), n))
        Err(e) => Err(e)
      }
    Some(_) => Err(BinaryDecodeError::InvalidCompilerFactsEnumTag)
    None => Err(BinaryDecodeError::TruncatedCompilerFactsPayload)
  }
}

///|
pub impl Decode for FieldUsageFacts with fn decode(bytes, index) {
  let (never_read, next) = match
    (Decode::decode(bytes, index) : Result[(Bool, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (never_written_after_initialization, next) = match
    (Decode::decode(bytes, next) : Result[(Bool, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(
    (
      FieldUsageFacts::new(never_read~, never_written_after_initialization~),
      next,
    ),
  )
}

///|
pub impl Decode for FieldFacts with fn decode(bytes, index) {
  let (view, next) = match
    (Decode::decode(bytes, index) : Result[(TypeView, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (field, next) = match decode_compiler_fact_uint(bytes, next) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (stored_contents, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ValueFacts?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (writes, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(WriteFacts?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (usage, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(FieldUsageFacts?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((FieldFacts::new(view, field, stored_contents~, writes~, usage~), next))
}

///|
pub impl Decode for ArrayElementFacts with fn decode(bytes, index) {
  let (view, next) = match
    (Decode::decode(bytes, index) : Result[(TypeView, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (stored_contents, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ValueFacts?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (writes, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(WriteFacts?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((ArrayElementFacts::new(view, stored_contents~, writes~), next))
}

///|
pub impl Decode for TypeFacts with fn decode(bytes, index) {
  let (type_, next) = match decode_compiler_fact_uint(bytes, index) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (population, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(TypePopulation?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (fields, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(Array[FieldFacts], Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (array_element, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ArrayElementFacts?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((TypeFacts::new(type_, population~, fields~, array_element~), next))
}

///|
pub impl Decode for MutationPhase with fn decode(bytes, index) {
  match bytes.get(index) {
    Some(0x00) => Ok((MutationPhase::never(), index + 1))
    Some(0x01) => Ok((MutationPhase::initialization_only(), index + 1))
    Some(0x02) => Ok((MutationPhase::runtime(), index + 1))
    Some(_) => Err(BinaryDecodeError::InvalidCompilerFactsEnumTag)
    None => Err(BinaryDecodeError::TruncatedCompilerFactsPayload)
  }
}

///|
pub impl Decode for MutationFacts with fn decode(bytes, index) {
  let (latest_phase, next) = match
    (
      Decode::decode(bytes, index) :
      Result[(MutationPhase, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (sites, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(Array[CodeSite]?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((MutationFacts::new(latest_phase, sites~), next))
}

///|
pub impl Decode for GlobalFacts with fn decode(bytes, index) {
  let (global, next) = match decode_compiler_fact_uint(bytes, index) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (initial_value, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ValueFacts?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (steady_state_value, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ValueFacts?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (mutation, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(MutationFacts?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(
    (
      GlobalFacts::new(global, initial_value~, steady_state_value~, mutation~),
      next,
    ),
  )
}

///|
pub impl Decode for TableEntryFacts with fn decode(bytes, index) {
  let (slot, next) = match decode_compiler_fact_uint64(bytes, index) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (value, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(ReferenceFacts, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((TableEntryFacts::new(slot, value), next))
}

///|
pub impl Decode for TableFacts with fn decode(bytes, index) {
  let (table, next) = match decode_compiler_fact_uint(bytes, index) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (mutation, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(MutationFacts?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (may_grow, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(Bool?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (default_value, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ReferenceFacts?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (entries, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(Array[TableEntryFacts], Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (contents_complete, next) = match
    (Decode::decode(bytes, next) : Result[(Bool, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(
    (
      TableFacts::new(
        table,
        mutation~,
        may_grow~,
        default_value~,
        entries~,
        contents_complete~,
      ),
      next,
    ),
  )
}

///|
pub impl Decode for AllocationKind with fn decode(bytes, index) {
  let tag = match bytes.get(index) {
    Some(v) => v
    None => return Err(BinaryDecodeError::TruncatedCompilerFactsPayload)
  }
  if tag > 0x04 {
    return Err(BinaryDecodeError::InvalidCompilerFactsEnumTag)
  }
  match decode_compiler_fact_uint(bytes, index + 1) {
    Ok((type_, next)) =>
      Ok(
        (
          match tag {
            0x00 => AllocationKind::struct_(type_)
            0x01 => AllocationKind::array(type_)
            0x02 => AllocationKind::closure(type_)
            0x03 => AllocationKind::box(type_)
            _ => AllocationKind::other_gc(type_)
          },
          next,
        ),
      )
    Err(err) => Err(err)
  }
}

///|
pub impl Decode for AllocationFieldFacts with fn decode(bytes, index) {
  let (field, next) = match decode_compiler_fact_uint(bytes, index) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (no_post_init_writes, next) = match
    (Decode::decode(bytes, next) : Result[(Bool, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (stored_value, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ValueFacts?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(
    (
      AllocationFieldFacts::new(field, no_post_init_writes~, stored_value~),
      next,
    ),
  )
}

///|
pub impl Decode for AllocationFacts with fn decode(bytes, index) {
  let (kind, next) = match
    (
      Decode::decode(bytes, index) :
      Result[(AllocationKind, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (escape_sinks, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(EscapeSinkMask?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (identity_unobserved, next) = match
    (Decode::decode(bytes, next) : Result[(Bool, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (thread_confined, next) = match
    (Decode::decode(bytes, next) : Result[(Bool, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (length, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(IntegerFacts?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (fields, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(Array[AllocationFieldFacts], Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(
    (
      AllocationFacts::new(
        kind,
        escape_sinks~,
        identity_unobserved~,
        thread_confined~,
        length~,
        fields~,
      ),
      next,
    ),
  )
}

///|
pub impl Decode for AllocationSiteFacts with fn decode(bytes, index) {
  let (site, next) = match
    (Decode::decode(bytes, index) : Result[(ValueSite, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (facts, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(AllocationFacts, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (provenance, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(SourceProvenance?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((AllocationSiteFacts::new(site, facts, provenance~), next))
}

///|
pub impl Decode for AccessFacts with fn decode(bytes, index) {
  let (in_bounds, next) = match
    (Decode::decode(bytes, index) : Result[(Bool, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (alignment_log2, next) = match
    decode_compiler_fact_uint_option(bytes, next) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((AccessFacts::new(in_bounds~, alignment_log2~), next))
}

///|
pub impl Decode for AccessSiteFacts with fn decode(bytes, index) {
  let (site, next) = match
    (Decode::decode(bytes, index) : Result[(CodeSite, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (facts, next) = match
    (Decode::decode(bytes, next) : Result[(AccessFacts, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (provenance, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(SourceProvenance?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((AccessSiteFacts::new(site, facts, provenance~), next))
}

///|
pub impl Decode for NumericOperationFacts with fn decode(bytes, index) {
  let (signed_no_wrap, next) = match
    (Decode::decode(bytes, index) : Result[(Bool, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (unsigned_no_wrap, next) = match
    (Decode::decode(bytes, next) : Result[(Bool, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (exact_division, next) = match
    (Decode::decode(bytes, next) : Result[(Bool, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(
    (
      NumericOperationFacts::new(
        signed_no_wrap~,
        unsigned_no_wrap~,
        exact_division~,
      ),
      next,
    ),
  )
}

///|
pub impl Decode for NumericOperationSiteFacts with fn decode(bytes, index) {
  let (site, next) = match
    (Decode::decode(bytes, index) : Result[(ValueSite, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (facts, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(NumericOperationFacts, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (provenance, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(SourceProvenance?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((NumericOperationSiteFacts::new(site, facts, provenance~), next))
}

///|
pub impl Decode for FactOperand with fn decode(bytes, index) {
  match bytes.get(index) {
    Some(0x00) =>
      match
        (
          Decode::decode(bytes, index + 1) :
          Result[(ValueRef, Int), BinaryDecodeError]) {
        Ok((v, n)) => Ok((FactOperand::value(v), n))
        Err(e) => Err(e)
      }
    Some(0x01) =>
      match
        (
          Decode::decode(bytes, index + 1) :
          Result[(FactValue, Int), BinaryDecodeError]) {
        Ok((v, n)) => Ok((FactOperand::constant(v), n))
        Err(e) => Err(e)
      }
    Some(_) => Err(BinaryDecodeError::InvalidCompilerFactsEnumTag)
    None => Err(BinaryDecodeError::TruncatedCompilerFactsPayload)
  }
}

///|
pub impl Decode for RelationKind with fn decode(bytes, index) {
  match bytes.get(index) {
    Some(0x00) => Ok((RelationKind::equal(), index + 1))
    Some(0x01) => Ok((RelationKind::not_equal(), index + 1))
    Some(0x02) => Ok((RelationKind::signed_less_than(), index + 1))
    Some(0x03) => Ok((RelationKind::signed_less_or_equal(), index + 1))
    Some(0x04) => Ok((RelationKind::unsigned_less_than(), index + 1))
    Some(0x05) => Ok((RelationKind::unsigned_less_or_equal(), index + 1))
    Some(0x06) => Ok((RelationKind::same_reference(), index + 1))
    Some(0x07) => Ok((RelationKind::distinct_references(), index + 1))
    Some(_) => Err(BinaryDecodeError::InvalidCompilerFactsEnumTag)
    None => Err(BinaryDecodeError::TruncatedCompilerFactsPayload)
  }
}

///|
pub impl Decode for ScopedRelationFacts with fn decode(bytes, index) {
  let (at, next) = match
    (Decode::decode(bytes, index) : Result[(CodeSite, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (left, next) = match
    (Decode::decode(bytes, next) : Result[(FactOperand, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (kind, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(RelationKind, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (right, next) = match
    (Decode::decode(bytes, next) : Result[(FactOperand, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((ScopedRelationFacts::new(at, left, kind, right), next))
}

///|
pub impl Decode for ExpressionFact with fn decode(bytes, index) {
  let (value, next) = match
    (Decode::decode(bytes, index) : Result[(ValueSite, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (facts, next) = match
    (Decode::decode(bytes, next) : Result[(ValueFacts, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (provenance, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(SourceProvenance?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((ExpressionFact::new(value, facts, provenance~), next))
}

///|
pub impl Decode for CallSiteFacts with fn decode(bytes, index) {
  let (site, next) = match
    (Decode::decode(bytes, index) : Result[(CodeSite, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (direct_target, next) = match
    decode_compiler_fact_uint_option(bytes, next) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (profile, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(CallProfile?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (inline_policy, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(InlinePolicy?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (provenance, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(SourceProvenance?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(
    (
      CallSiteFacts::new(
        site,
        direct_target~,
        profile~,
        inline_policy~,
        provenance~,
      ),
      next,
    ),
  )
}

///|
pub impl Decode for BranchFacts with fn decode(bytes, index) {
  let (site, next) = match
    (Decode::decode(bytes, index) : Result[(CodeSite, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (profile, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(BranchProfile?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (temperature, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(TemperatureHint?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (provenance, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(SourceProvenance?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((BranchFacts::new(site, profile~, temperature~, provenance~), next))
}

///|
pub impl Decode for LoopFacts with fn decode(bytes, index) {
  let (site, next) = match
    (Decode::decode(bytes, index) : Result[(CodeSite, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (profile, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(LoopProfile?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (temperature, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(TemperatureHint?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (provenance, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(SourceProvenance?, Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok((LoopFacts::new(site, profile~, temperature~, provenance~), next))
}

///|
pub impl Decode for FunctionBodyFacts with fn decode(bytes, index) {
  let (function, next) = match decode_compiler_fact_uint(bytes, index) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (sites, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(Array[ExpressionFact], Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (relations, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(Array[ScopedRelationFacts], Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (calls, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(Array[CallSiteFacts], Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (branches, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(Array[BranchFacts], Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (loops, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(Array[LoopFacts], Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (allocations, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(Array[AllocationSiteFacts], Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (accesses, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(Array[AccessSiteFacts], Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let (numeric_operations, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(Array[NumericOperationSiteFacts], Int), BinaryDecodeError]) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok(
    (
      FunctionBodyFacts::new(
        function,
        sites~,
        relations~,
        calls~,
        branches~,
        loops~,
        allocations~,
        accesses~,
        numeric_operations~,
      ),
      next,
    ),
  )
}

///|
pub impl Decode for OptimizationGoal with fn decode(bytes, index) {
  match bytes.get(index) {
    Some(0x00) => Ok((OptimizationGoal::prefer_speed(), index + 1))
    Some(0x01) => Ok((OptimizationGoal::balanced(), index + 1))
    Some(0x02) => Ok((OptimizationGoal::prefer_size(), index + 1))
    Some(_) => Err(BinaryDecodeError::InvalidCompilerFactsEnumTag)
    None => Err(BinaryDecodeError::TruncatedCompilerFactsPayload)
  }
}

///|
pub impl Decode for HintTarget with fn decode(bytes, index) {
  match bytes.get(index) {
    Some(0x00) =>
      match decode_compiler_fact_uint(bytes, index + 1) {
        Ok((v, n)) => Ok((HintTarget::function(v), n))
        Err(e) => Err(e)
      }
    Some(0x01) =>
      match
        (
          Decode::decode(bytes, index + 1) :
          Result[(CodeSite, Int), BinaryDecodeError]) {
        Ok((v, n)) => Ok((HintTarget::site(v), n))
        Err(e) => Err(e)
      }
    Some(_) => Err(BinaryDecodeError::InvalidCompilerFactsEnumTag)
    None => Err(BinaryDecodeError::TruncatedCompilerFactsPayload)
  }
}

///|
pub impl Decode for OptimizationHint with fn decode(bytes, index) {
  let tag = match bytes.get(index) {
    Some(v) => v
    None => return Err(BinaryDecodeError::TruncatedCompilerFactsPayload)
  }
  match tag {
    0x00 => {
      let (target, next) = match
        (
          Decode::decode(bytes, index + 1) :
          Result[(HintTarget, Int), BinaryDecodeError]) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let (temperature, next) = match
        (
          Decode::decode(bytes, next) :
          Result[(TemperatureHint, Int), BinaryDecodeError]) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok((OptimizationHint::hotness(target, temperature), next))
    }
    0x01 => {
      let (target, next) = match
        (
          Decode::decode(bytes, index + 1) :
          Result[(HintTarget, Int), BinaryDecodeError]) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let (policy, next) = match
        (
          Decode::decode(bytes, next) :
          Result[(InlinePolicy, Int), BinaryDecodeError]) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok((OptimizationHint::inline_(target, policy), next))
    }
    0x02 => {
      let (target, next) = match
        (
          Decode::decode(bytes, index + 1) :
          Result[(HintTarget, Int), BinaryDecodeError]) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let (goal, next) = match
        (
          Decode::decode(bytes, next) :
          Result[(OptimizationGoal, Int), BinaryDecodeError]) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok((OptimizationHint::goal(target, goal), next))
    }
    0x03 => {
      let (site, next) = match
        (
          Decode::decode(bytes, index + 1) :
          Result[(CodeSite, Int), BinaryDecodeError]) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let (probability, next) = match decode_compiler_fact_uint(bytes, next) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok((OptimizationHint::branch_probability(site, probability), next))
    }
    0x04 => {
      let (site, next) = match
        (
          Decode::decode(bytes, index + 1) :
          Result[(CodeSite, Int), BinaryDecodeError]) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let (trips, next) = match decode_compiler_fact_uint64(bytes, next) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok((OptimizationHint::estimated_loop_trips(site, trips), next))
    }
    0x05 => {
      let (site, next) = match
        (
          Decode::decode(bytes, index + 1) :
          Result[(CodeSite, Int), BinaryDecodeError]) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let (function, next) = match decode_compiler_fact_uint(bytes, next) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let (confidence, next) = match decode_compiler_fact_uint(bytes, next) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok(
        (OptimizationHint::likely_call_target(site, function, confidence), next),
      )
    }
    0x06 => {
      let (site, next) = match
        (
          Decode::decode(bytes, index + 1) :
          Result[(ValueSite, Int), BinaryDecodeError]) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let (type_, next) = match
        (
          Decode::decode(bytes, next) :
          Result[(FactHeapType, Int), BinaryDecodeError]) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      let (confidence, next) = match decode_compiler_fact_uint(bytes, next) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      Ok((OptimizationHint::likely_heap_type(site, type_, confidence), next))
    }
    _ => Err(BinaryDecodeError::InvalidCompilerFactsEnumTag)
  }
}
