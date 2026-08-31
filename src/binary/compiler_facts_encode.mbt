///|
fn encode_compiler_fact_uint(
  value : UInt,
  buf : @buffer.Buffer,
) -> Result[Unit, BinaryEncodeError] {
  Encode::encode(@lib.U32(value), buf)
}

///|
fn encode_compiler_fact_uint64(
  value : UInt64,
  buf : @buffer.Buffer,
) -> Result[Unit, BinaryEncodeError] {
  Encode::encode(@lib.U64(value), buf)
}

///|
fn encode_compiler_fact_int64(
  value : Int64,
  buf : @buffer.Buffer,
) -> Result[Unit, BinaryEncodeError] {
  Encode::encode(@lib.I64(value), buf)
}

///|
fn[T : Encode] encode_compiler_fact_option(
  value : T?,
  buf : @buffer.Buffer,
) -> Result[Unit, BinaryEncodeError] {
  match value {
    None => {
      buf.write_byte(0x00)
      Ok(())
    }
    Some(value) => {
      buf.write_byte(0x01)
      Encode::encode(value, buf)
    }
  }
}

///|
fn encode_compiler_fact_uint_option(
  value : UInt?,
  buf : @buffer.Buffer,
) -> Result[Unit, BinaryEncodeError] {
  match value {
    None => {
      buf.write_byte(0x00)
      Ok(())
    }
    Some(value) => {
      buf.write_byte(0x01)
      encode_compiler_fact_uint(value, buf)
    }
  }
}

///|
fn encode_compiler_fact_uint64_option(
  value : UInt64?,
  buf : @buffer.Buffer,
) -> Result[Unit, BinaryEncodeError] {
  match value {
    None => {
      buf.write_byte(0x00)
      Ok(())
    }
    Some(value) => {
      buf.write_byte(0x01)
      encode_compiler_fact_uint64(value, buf)
    }
  }
}

///|
fn encode_compiler_fact_uint_array(
  values : Array[UInt],
  buf : @buffer.Buffer,
) -> Result[Unit, BinaryEncodeError] {
  if encode_compiler_fact_uint(values.length().reinterpret_as_uint(), buf)
    is Err(err) {
    return Err(err)
  }
  for value in values {
    if encode_compiler_fact_uint(value, buf) is Err(err) {
      return Err(err)
    }
  }
  Ok(())
}

///|
pub impl Encode for CompilerFactCustomSection with fn encode(value, buf) {
  if value.version != 1U {
    return Err(BinaryEncodeError::UnsupportedCompilerFactsVersion)
  }
  if encode_compiler_fact_uint(value.version, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.module_fingerprint, buf) is Err(err) {
    return Err(err)
  }
  Encode::encode(value.facts, buf)
}

///|
pub impl Encode for OptimizationFactsSec with fn encode(value, buf) {
  if Encode::encode(value.functions, buf) is Err(err) {
    return Err(err)
  }
  Encode::encode(value.bodies, buf)
}

///|
pub impl Encode for FunctionFacts with fn encode(value, buf) {
  if encode_compiler_fact_uint(value.function, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.effects, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.parameters, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.results, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.boundary, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.profile, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_option(value.inline_policy, buf)
}

///|
pub impl Encode for EffectFacts with fn encode(value, buf) {
  if Encode::encode(value.may, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.read_globals, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.written_globals, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.read_memories, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.written_memories, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.read_tables, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.written_tables, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.read_heap_types, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.written_heap_types, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_option(value.direct_callees, buf)
}

///|
pub impl Encode for EffectMask with fn encode(value, buf) {
  encode_compiler_fact_uint64(value.bits(), buf)
}

///|
pub impl Encode for ClosedGlobalSet with fn encode(value, buf) {
  let @representation.ClosedGlobalSet(values) = value
  encode_compiler_fact_uint_array(values, buf)
}

///|
pub impl Encode for ClosedMemorySet with fn encode(value, buf) {
  let @representation.ClosedMemorySet(values) = value
  encode_compiler_fact_uint_array(values, buf)
}

///|
pub impl Encode for ClosedTableSet with fn encode(value, buf) {
  let @representation.ClosedTableSet(values) = value
  encode_compiler_fact_uint_array(values, buf)
}

///|
pub impl Encode for ClosedTypeViewSet with fn encode(value, buf) {
  let @representation.ClosedTypeViewSet(values) = value
  encode_compiler_fact_uint_array(values, buf)
}

///|
pub impl Encode for ClosedFunctionSet with fn encode(value, buf) {
  let @representation.ClosedFunctionSet(values) = value
  encode_compiler_fact_uint_array(values, buf)
}

///|
pub impl Encode for ParameterFacts with fn encode(value, buf) {
  if encode_compiler_fact_uint(value.parameter, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.value, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.uses, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_option(value.escape_sinks, buf)
}

///|
pub impl Encode for ParameterUseMask with fn encode(value, buf) {
  encode_compiler_fact_uint64(value.bits(), buf)
}

///|
pub impl Encode for EscapeSinkMask with fn encode(value, buf) {
  encode_compiler_fact_uint64(value.bits(), buf)
}

///|
pub impl Encode for ResultFacts with fn encode(value, buf) {
  if encode_compiler_fact_uint(value.result, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.value, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_option(value.identity, buf)
}

///|
pub impl Encode for ResultIdentityFacts with fn encode(value, buf) {
  match value {
    FreshIdentity => {
      buf.write_byte(0x00)
      Ok(())
    }
    SameAsParameter(parameter) => {
      buf.write_byte(0x01)
      encode_compiler_fact_uint(parameter, buf)
    }
  }
}

///|
pub impl Encode for ValueFacts with fn encode(value, buf) {
  if Encode::encode(value.non_null, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_uint_option(value.exact_heap_type, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_uint_option(value.exact_call_target, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.signed_range, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.unsigned_range, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.does_not_escape, buf) is Err(err) {
    return Err(err)
  }
  Encode::encode(value.identity_not_observed, buf)
}

///|
pub impl Encode for SignedRange with fn encode(value, buf) {
  if encode_compiler_fact_int64(value.min, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_int64(value.max, buf)
}

///|
pub impl Encode for UnsignedRange with fn encode(value, buf) {
  if encode_compiler_fact_uint64(value.min, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_uint64(value.max, buf)
}

///|
pub impl Encode for FunctionBoundaryFacts with fn encode(value, buf) {
  if Encode::encode(value.all_call_sites_known, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.address_taken, buf) is Err(err) {
    return Err(err)
  }
  Encode::encode(value.host_callable, buf)
}

///|
pub impl Encode for FunctionProfile with fn encode(value, buf) {
  if encode_compiler_fact_uint64_option(value.entry_count, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_option(value.temperature, buf)
}

///|
pub impl Encode for CallProfile with fn encode(value, buf) {
  if encode_compiler_fact_uint64_option(value.count, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_option(value.temperature, buf)
}

///|
pub impl Encode for BranchProfile with fn encode(value, buf) {
  if encode_compiler_fact_uint64(value.taken, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_uint64(value.not_taken, buf)
}

///|
pub impl Encode for LoopProfile with fn encode(value, buf) {
  if encode_compiler_fact_uint64_option(value.backedge_count, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_uint64_option(value.estimated_trip_count, buf)
}

///|
pub impl Encode for TemperatureHint with fn encode(value, buf) {
  buf.write_byte(
    match value {
      Cold => 0x00
      Normal => 0x01
      Hot => 0x02
    },
  )
  Ok(())
}

///|
pub impl Encode for InlinePolicy with fn encode(value, buf) {
  buf.write_byte(
    match value {
      DefaultInlinePolicy => 0x00
      NeverInline => 0x01
      PreferInline => 0x02
      AlwaysInline => 0x03
    },
  )
  Ok(())
}

///|
pub impl Encode for FunctionBodyFacts with fn encode(value, buf) {
  if encode_compiler_fact_uint(value.function, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.sites, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.relations, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.calls, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.branches, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.loops, buf) is Err(err) {
    return Err(err)
  }
  Encode::encode(value.allocations, buf)
}

///|
pub impl Encode for ExpressionFact with fn encode(value, buf) {
  if encode_compiler_fact_uint(value.function, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_uint(value.offset, buf) is Err(err) {
    return Err(err)
  }
  Encode::encode(value.facts, buf)
}

///|
pub impl Encode for Fact with fn encode(value, buf) {
  match value {
    NonNull => {
      buf.write_byte(0x00)
      Ok(())
    }
    ExactHeapType(heap_type) => {
      buf.write_byte(0x01)
      encode_compiler_fact_uint(heap_type, buf)
    }
    ExactCallTarget(function) => {
      buf.write_byte(0x02)
      encode_compiler_fact_uint(function, buf)
    }
    SignedRangeFact(min, max) => {
      buf.write_byte(0x03)
      if encode_compiler_fact_int64(min, buf) is Err(err) {
        return Err(err)
      }
      encode_compiler_fact_int64(max, buf)
    }
    UnsignedRangeFact(min, max) => {
      buf.write_byte(0x04)
      if encode_compiler_fact_uint64(min, buf) is Err(err) {
        return Err(err)
      }
      encode_compiler_fact_uint64(max, buf)
    }
    DoesNotEscape => {
      buf.write_byte(0x05)
      Ok(())
    }
    IdentityNotObserved => {
      buf.write_byte(0x06)
      Ok(())
    }
  }
}

///|
pub impl Encode for FactSiteRef with fn encode(value, buf) {
  if encode_compiler_fact_uint(value.function, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_uint(value.offset, buf)
}

///|
pub impl Encode for FactRelation with fn encode(value, buf) {
  let (tag, left, right) = match value {
    SameValue(left, right) => (0x00, left, right)
    SameIdentity(left, right) => (0x01, left, right)
    DerivedFrom(left, right) => (0x02, left, right)
  }
  buf.write_byte(tag.to_byte())
  if Encode::encode(left, buf) is Err(err) {
    return Err(err)
  }
  Encode::encode(right, buf)
}

///|
pub impl Encode for CallSiteFacts with fn encode(value, buf) {
  if encode_compiler_fact_uint(value.function, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_uint(value.offset, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_uint_option(value.direct_target, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.profile, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_option(value.inline_policy, buf)
}

///|
pub impl Encode for BranchFacts with fn encode(value, buf) {
  if encode_compiler_fact_uint(value.function, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_uint(value.offset, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.profile, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_option(value.temperature, buf)
}

///|
pub impl Encode for LoopFacts with fn encode(value, buf) {
  if encode_compiler_fact_uint(value.function, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_uint(value.offset, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.profile, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_option(value.temperature, buf)
}

///|
pub impl Encode for AllocationSiteFacts with fn encode(value, buf) {
  if encode_compiler_fact_uint(value.function, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_uint(value.offset, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_uint_option(value.heap_type, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.does_not_escape, buf) is Err(err) {
    return Err(err)
  }
  Encode::encode(value.identity_not_observed, buf)
}

///|
fn encode_compiler_facts_as_custom_section(
  value : CompilerFactCustomSection,
  buf : @buffer.Buffer,
) -> Result[Unit, BinaryEncodeError] {
  write_section(0, buf, fn(payload) {
    if Encode::encode(Name::new("compiler.facts"), payload) is Err(err) {
      return Err(err)
    }
    Encode::encode(value, payload)
  })
}
