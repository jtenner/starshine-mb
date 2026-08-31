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
  let (count, next) = match decode_compiler_fact_uint(bytes, index) {
    Ok(result) => result
    Err(err) => return Err(err)
  }
  let out : Array[UInt] = []
  let mut next = next
  let mut remaining = count
  while remaining > 0U {
    let (value, decoded_next) = match decode_compiler_fact_uint(bytes, next) {
      Ok(result) => result
      Err(err) => return Err(err)
    }
    out.push(value)
    next = decoded_next
    remaining -= 1U
  }
  Ok((out, next))
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
    Ok(result) => result
    Err(err) => return Err(err)
  }
  if version != 1U {
    return Err(BinaryDecodeError::UnsupportedCompilerFactsVersion)
  }
  let (module_fingerprint, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(Bytes?, Int), BinaryDecodeError]) {
    Ok(result) => result
    Err(err) => return Err(err)
  }
  let (facts, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(OptimizationFactsSec, Int), BinaryDecodeError]) {
    Ok(result) => result
    Err(err) => return Err(err)
  }
  Ok(
    (CompilerFactCustomSection::new(facts, version~, module_fingerprint~), next),
  )
}

///|
pub impl Decode for OptimizationFactsSec with fn decode(bytes, index) {
  let (functions, next) = match
    (
      Decode::decode(bytes, index) :
      Result[(Array[FunctionFacts], Int), BinaryDecodeError]) {
    Ok(result) => result
    Err(err) => return Err(err)
  }
  let (bodies, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(Array[FunctionBodyFacts], Int), BinaryDecodeError]) {
    Ok(result) => result
    Err(err) => return Err(err)
  }
  Ok((OptimizationFactsSec::new(functions~, bodies~), next))
}

///|
pub impl Decode for FunctionFacts with fn decode(bytes, index) {
  let (function, next) = match decode_compiler_fact_uint(bytes, index) {
    Ok(result) => result
    Err(err) => return Err(err)
  }
  let (effects, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(EffectFacts?, Int), BinaryDecodeError]) {
    Ok(result) => result
    Err(err) => return Err(err)
  }
  let (parameters, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(Array[ParameterFacts], Int), BinaryDecodeError]) {
    Ok(result) => result
    Err(err) => return Err(err)
  }
  let (results, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(Array[ResultFacts], Int), BinaryDecodeError]) {
    Ok(result) => result
    Err(err) => return Err(err)
  }
  let (boundary, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(FunctionBoundaryFacts?, Int), BinaryDecodeError]) {
    Ok(result) => result
    Err(err) => return Err(err)
  }
  let (profile, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(FunctionProfile?, Int), BinaryDecodeError]) {
    Ok(result) => result
    Err(err) => return Err(err)
  }
  let (inline_policy, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(InlinePolicy?, Int), BinaryDecodeError]) {
    Ok(result) => result
    Err(err) => return Err(err)
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
pub impl Decode for EffectFacts with fn decode(bytes, index) {
  let (may, next) = match
    (Decode::decode(bytes, index) : Result[(EffectMask, Int), BinaryDecodeError]) {
    Ok(result) => result
    Err(err) => return Err(err)
  }
  let (read_globals, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ClosedGlobalSet?, Int), BinaryDecodeError]) {
    Ok(result) => result
    Err(err) => return Err(err)
  }
  let (written_globals, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ClosedGlobalSet?, Int), BinaryDecodeError]) {
    Ok(result) => result
    Err(err) => return Err(err)
  }
  let (read_memories, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ClosedMemorySet?, Int), BinaryDecodeError]) {
    Ok(result) => result
    Err(err) => return Err(err)
  }
  let (written_memories, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ClosedMemorySet?, Int), BinaryDecodeError]) {
    Ok(result) => result
    Err(err) => return Err(err)
  }
  let (read_tables, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ClosedTableSet?, Int), BinaryDecodeError]) {
    Ok(result) => result
    Err(err) => return Err(err)
  }
  let (written_tables, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ClosedTableSet?, Int), BinaryDecodeError]) {
    Ok(result) => result
    Err(err) => return Err(err)
  }
  let (read_heap_types, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ClosedTypeViewSet?, Int), BinaryDecodeError]) {
    Ok(result) => result
    Err(err) => return Err(err)
  }
  let (written_heap_types, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ClosedTypeViewSet?, Int), BinaryDecodeError]) {
    Ok(result) => result
    Err(err) => return Err(err)
  }
  let (direct_callees, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ClosedFunctionSet?, Int), BinaryDecodeError]) {
    Ok(result) => result
    Err(err) => return Err(err)
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
pub impl Decode for EffectMask with fn decode(bytes, index) {
  match decode_compiler_fact_uint64(bytes, index) {
    Ok((bits, next)) => Ok((EffectMask::from_bits(bits), next))
    Err(err) => Err(err)
  }
}

///|
pub impl Decode for ClosedGlobalSet with fn decode(bytes, index) {
  match decode_compiler_fact_uint_array(bytes, index) {
    Ok((values, next)) => Ok((ClosedGlobalSet::new(values), next))
    Err(err) => Err(err)
  }
}

///|
pub impl Decode for ClosedMemorySet with fn decode(bytes, index) {
  match decode_compiler_fact_uint_array(bytes, index) {
    Ok((values, next)) => Ok((ClosedMemorySet::new(values), next))
    Err(err) => Err(err)
  }
}

///|
pub impl Decode for ClosedTableSet with fn decode(bytes, index) {
  match decode_compiler_fact_uint_array(bytes, index) {
    Ok((values, next)) => Ok((ClosedTableSet::new(values), next))
    Err(err) => Err(err)
  }
}

///|
pub impl Decode for ClosedTypeViewSet with fn decode(bytes, index) {
  match decode_compiler_fact_uint_array(bytes, index) {
    Ok((values, next)) => Ok((ClosedTypeViewSet::new(values), next))
    Err(err) => Err(err)
  }
}

///|
pub impl Decode for ClosedFunctionSet with fn decode(bytes, index) {
  match decode_compiler_fact_uint_array(bytes, index) {
    Ok((values, next)) => Ok((ClosedFunctionSet::new(values), next))
    Err(err) => Err(err)
  }
}

///|
pub impl Decode for ParameterFacts with fn decode(bytes, index) {
  let (parameter, next) = match decode_compiler_fact_uint(bytes, index) {
    Ok(result) => result
    Err(err) => return Err(err)
  }
  let (value, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ValueFacts?, Int), BinaryDecodeError]) {
    Ok(result) => result
    Err(err) => return Err(err)
  }
  let (uses, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ParameterUseMask?, Int), BinaryDecodeError]) {
    Ok(result) => result
    Err(err) => return Err(err)
  }
  let (escape_sinks, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(EscapeSinkMask?, Int), BinaryDecodeError]) {
    Ok(result) => result
    Err(err) => return Err(err)
  }
  Ok((ParameterFacts::new(parameter, value~, uses~, escape_sinks~), next))
}

///|
pub impl Decode for ParameterUseMask with fn decode(bytes, index) {
  match decode_compiler_fact_uint64(bytes, index) {
    Ok((bits, next)) => Ok((ParameterUseMask::from_bits(bits), next))
    Err(err) => Err(err)
  }
}

///|
pub impl Decode for EscapeSinkMask with fn decode(bytes, index) {
  match decode_compiler_fact_uint64(bytes, index) {
    Ok((bits, next)) => Ok((EscapeSinkMask::from_bits(bits), next))
    Err(err) => Err(err)
  }
}

///|
pub impl Decode for ResultFacts with fn decode(bytes, index) {
  let (result, next) = match decode_compiler_fact_uint(bytes, index) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (value, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ValueFacts?, Int), BinaryDecodeError]) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (identity, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(ResultIdentityFacts?, Int), BinaryDecodeError]) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  Ok((ResultFacts::new(result, value~, identity~), next))
}

///|
pub impl Decode for ResultIdentityFacts with fn decode(bytes, index) {
  match bytes.get(index) {
    Some(0x00) => Ok((ResultIdentityFacts::fresh(), index + 1))
    Some(0x01) =>
      match decode_compiler_fact_uint(bytes, index + 1) {
        Ok((parameter, next)) =>
          Ok((ResultIdentityFacts::same_as_parameter(parameter), next))
        Err(err) => Err(err)
      }
    Some(_) => Err(BinaryDecodeError::InvalidCompilerFactsEnumTag)
    None => Err(BinaryDecodeError::TruncatedCompilerFactsPayload)
  }
}

///|
pub impl Decode for ValueFacts with fn decode(bytes, index) {
  let (non_null, next) = match
    (Decode::decode(bytes, index) : Result[(Bool, Int), BinaryDecodeError]) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (exact_heap_type, next) = match
    decode_compiler_fact_uint_option(bytes, next) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (exact_call_target, next) = match
    decode_compiler_fact_uint_option(bytes, next) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (signed_range, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(SignedRange?, Int), BinaryDecodeError]) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (unsigned_range, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(UnsignedRange?, Int), BinaryDecodeError]) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (does_not_escape, next) = match
    (Decode::decode(bytes, next) : Result[(Bool, Int), BinaryDecodeError]) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (identity_not_observed, next) = match
    (Decode::decode(bytes, next) : Result[(Bool, Int), BinaryDecodeError]) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  Ok(
    (
      ValueFacts::new(
        non_null~,
        exact_heap_type~,
        exact_call_target~,
        signed_range~,
        unsigned_range~,
        does_not_escape~,
        identity_not_observed~,
      ),
      next,
    ),
  )
}

///|
pub impl Decode for SignedRange with fn decode(bytes, index) {
  let (min, next) = match decode_compiler_fact_int64(bytes, index) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (max, next) = match decode_compiler_fact_int64(bytes, next) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  Ok((SignedRange::new(min, max), next))
}

///|
pub impl Decode for UnsignedRange with fn decode(bytes, index) {
  let (min, next) = match decode_compiler_fact_uint64(bytes, index) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (max, next) = match decode_compiler_fact_uint64(bytes, next) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  Ok((UnsignedRange::new(min, max), next))
}

///|
pub impl Decode for FunctionBoundaryFacts with fn decode(bytes, index) {
  let (all_call_sites_known, next) = match
    (Decode::decode(bytes, index) : Result[(Bool, Int), BinaryDecodeError]) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (address_taken, next) = match
    (Decode::decode(bytes, next) : Result[(Bool, Int), BinaryDecodeError]) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (host_callable, next) = match
    (Decode::decode(bytes, next) : Result[(Bool, Int), BinaryDecodeError]) {
    Ok(value) => value
    Err(err) => return Err(err)
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
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (temperature, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(TemperatureHint?, Int), BinaryDecodeError]) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  Ok((FunctionProfile::new(entry_count~, temperature~), next))
}

///|
pub impl Decode for CallProfile with fn decode(bytes, index) {
  let (count, next) = match decode_compiler_fact_uint64_option(bytes, index) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (temperature, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(TemperatureHint?, Int), BinaryDecodeError]) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  Ok((CallProfile::new(count~, temperature~), next))
}

///|
pub impl Decode for BranchProfile with fn decode(bytes, index) {
  let (taken, next) = match decode_compiler_fact_uint64(bytes, index) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (not_taken, next) = match decode_compiler_fact_uint64(bytes, next) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  Ok((BranchProfile::new(taken, not_taken), next))
}

///|
pub impl Decode for LoopProfile with fn decode(bytes, index) {
  let (backedge_count, next) = match
    decode_compiler_fact_uint64_option(bytes, index) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (estimated_trip_count, next) = match
    decode_compiler_fact_uint64_option(bytes, next) {
    Ok(value) => value
    Err(err) => return Err(err)
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
pub impl Decode for FunctionBodyFacts with fn decode(bytes, index) {
  let (function, next) = match decode_compiler_fact_uint(bytes, index) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (sites, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(Array[ExpressionFact], Int), BinaryDecodeError]) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (relations, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(Array[FactRelation], Int), BinaryDecodeError]) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (calls, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(Array[CallSiteFacts], Int), BinaryDecodeError]) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (branches, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(Array[BranchFacts], Int), BinaryDecodeError]) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (loops, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(Array[LoopFacts], Int), BinaryDecodeError]) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (allocations, next) = match
    (
      Decode::decode(bytes, next) :
      Result[(Array[AllocationSiteFacts], Int), BinaryDecodeError]) {
    Ok(value) => value
    Err(err) => return Err(err)
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
      ),
      next,
    ),
  )
}

///|
pub impl Decode for ExpressionFact with fn decode(bytes, index) {
  let (function, next) = match decode_compiler_fact_uint(bytes, index) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (offset, next) = match decode_compiler_fact_uint(bytes, next) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (facts, next) = match
    (Decode::decode(bytes, next) : Result[(Array[Fact], Int), BinaryDecodeError]) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  Ok((ExpressionFact::new(function, offset, facts), next))
}

///|
pub impl Decode for Fact with fn decode(bytes, index) {
  match bytes.get(index) {
    Some(0x00) => Ok((Fact::non_null(), index + 1))
    Some(0x01) =>
      match decode_compiler_fact_uint(bytes, index + 1) {
        Ok((heap_type, next)) => Ok((Fact::exact_heap_type(heap_type), next))
        Err(err) => Err(err)
      }
    Some(0x02) =>
      match decode_compiler_fact_uint(bytes, index + 1) {
        Ok((function, next)) => Ok((Fact::exact_call_target(function), next))
        Err(err) => Err(err)
      }
    Some(0x03) => {
      let (min, next) = match decode_compiler_fact_int64(bytes, index + 1) {
        Ok(value) => value
        Err(err) => return Err(err)
      }
      let (max, next) = match decode_compiler_fact_int64(bytes, next) {
        Ok(value) => value
        Err(err) => return Err(err)
      }
      Ok((Fact::signed_range(min, max), next))
    }
    Some(0x04) => {
      let (min, next) = match decode_compiler_fact_uint64(bytes, index + 1) {
        Ok(value) => value
        Err(err) => return Err(err)
      }
      let (max, next) = match decode_compiler_fact_uint64(bytes, next) {
        Ok(value) => value
        Err(err) => return Err(err)
      }
      Ok((Fact::unsigned_range(min, max), next))
    }
    Some(0x05) => Ok((Fact::does_not_escape(), index + 1))
    Some(0x06) => Ok((Fact::identity_not_observed(), index + 1))
    Some(_) => Err(BinaryDecodeError::InvalidCompilerFactsEnumTag)
    None => Err(BinaryDecodeError::TruncatedCompilerFactsPayload)
  }
}

///|
pub impl Decode for FactSiteRef with fn decode(bytes, index) {
  let (function, next) = match decode_compiler_fact_uint(bytes, index) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (offset, next) = match decode_compiler_fact_uint(bytes, next) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  Ok((FactSiteRef::new(function, offset), next))
}

///|
pub impl Decode for FactRelation with fn decode(bytes, index) {
  let tag = match bytes.get(index) {
    Some(tag) => tag
    None => return Err(BinaryDecodeError::TruncatedCompilerFactsPayload)
  }
  if tag > 0x02 {
    return Err(BinaryDecodeError::InvalidCompilerFactsEnumTag)
  }
  let (left, next) = match
    (
      Decode::decode(bytes, index + 1) :
      Result[(FactSiteRef, Int), BinaryDecodeError]) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (right, next) = match
    (Decode::decode(bytes, next) : Result[(FactSiteRef, Int), BinaryDecodeError]) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  Ok(
    (
      match tag {
        0x00 => FactRelation::same_value(left, right)
        0x01 => FactRelation::same_identity(left, right)
        _ => FactRelation::derived_from(left, right)
      },
      next,
    ),
  )
}

///|
pub impl Decode for CallSiteFacts with fn decode(bytes, index) {
  let (function, next) = match decode_compiler_fact_uint(bytes, index) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (offset, next) = match decode_compiler_fact_uint(bytes, next) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (direct_target, next) = match
    decode_compiler_fact_uint_option(bytes, next) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (profile, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(CallProfile?, Int), BinaryDecodeError]) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (inline_policy, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(InlinePolicy?, Int), BinaryDecodeError]) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  Ok(
    (
      CallSiteFacts::new(
        function,
        offset,
        direct_target~,
        profile~,
        inline_policy~,
      ),
      next,
    ),
  )
}

///|
pub impl Decode for BranchFacts with fn decode(bytes, index) {
  let (function, next) = match decode_compiler_fact_uint(bytes, index) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (offset, next) = match decode_compiler_fact_uint(bytes, next) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (profile, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(BranchProfile?, Int), BinaryDecodeError]) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (temperature, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(TemperatureHint?, Int), BinaryDecodeError]) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  Ok((BranchFacts::new(function, offset, profile~, temperature~), next))
}

///|
pub impl Decode for LoopFacts with fn decode(bytes, index) {
  let (function, next) = match decode_compiler_fact_uint(bytes, index) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (offset, next) = match decode_compiler_fact_uint(bytes, next) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (profile, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(LoopProfile?, Int), BinaryDecodeError]) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (temperature, next) = match
    (
      decode_compiler_fact_option(bytes, next) :
      Result[(TemperatureHint?, Int), BinaryDecodeError]) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  Ok((LoopFacts::new(function, offset, profile~, temperature~), next))
}

///|
pub impl Decode for AllocationSiteFacts with fn decode(bytes, index) {
  let (function, next) = match decode_compiler_fact_uint(bytes, index) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (offset, next) = match decode_compiler_fact_uint(bytes, next) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (heap_type, next) = match decode_compiler_fact_uint_option(bytes, next) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (does_not_escape, next) = match
    (Decode::decode(bytes, next) : Result[(Bool, Int), BinaryDecodeError]) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let (identity_not_observed, next) = match
    (Decode::decode(bytes, next) : Result[(Bool, Int), BinaryDecodeError]) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  Ok(
    (
      AllocationSiteFacts::new(
        function,
        offset,
        heap_type~,
        does_not_escape~,
        identity_not_observed~,
      ),
      next,
    ),
  )
}
