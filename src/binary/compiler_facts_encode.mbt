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
fn encode_compiler_fact_string(
  value : String,
  buf : @buffer.Buffer,
) -> Result[Unit, BinaryEncodeError] {
  Encode::encode(@lib.Name::from_string(value), buf)
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
pub impl Encode for ProducerInfo with fn encode(value, buf) {
  if encode_compiler_fact_string(value.name, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_string(value.version, buf) is Err(err) {
    return Err(err)
  }
  match value.build_id {
    None => {
      buf.write_byte(0x00)
      Ok(())
    }
    Some(build_id) => {
      buf.write_byte(0x01)
      encode_compiler_fact_string(build_id, buf)
    }
  }
}

///|
pub impl Encode for WorldMode with fn encode(value, buf) {
  buf.write_byte(
    match value {
      OpenWorld => 0x00
      ClosedModule => 0x01
      ClosedProgram => 0x02
    },
  )
  Ok(())
}

///|
pub impl Encode for WorldFacts with fn encode(value, buf) {
  if Encode::encode(value.mode, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.host_can_call_exports, buf) is Err(err) {
    return Err(err)
  }
  Encode::encode(value.host_can_mutate_exported_state, buf)
}

///|
pub impl Encode for OptimizationFactsSec with fn encode(value, buf) {
  if encode_compiler_fact_option(value.producer, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.world, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.functions, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.signatures, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.types, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.globals, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.tables, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.bodies, buf) is Err(err) {
    return Err(err)
  }
  Encode::encode(value.hints, buf)
}

///|
pub impl Encode for CodeSite with fn encode(value, buf) {
  if encode_compiler_fact_uint(value.function, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_uint(value.offset, buf)
}

///|
pub impl Encode for ValueSite with fn encode(value, buf) {
  if Encode::encode(value.site, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_uint(value.result, buf)
}

///|
pub impl Encode for SourceProvenance with fn encode(value, buf) {
  if encode_compiler_fact_uint64_option(value.module_id, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_uint64_option(value.declaration_id, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_uint64_option(value.body_id, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_uint64_option(value.expression_id, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_uint64_option(value.source_offset, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_uint64_option(value.specialization_id, buf)
}

///|
pub impl Encode for IntWidth with fn encode(value, buf) {
  buf.write_byte(
    match value {
      Int8 => 0x00
      Int16 => 0x01
      Int32 => 0x02
      Int64 => 0x03
    },
  )
  Ok(())
}

///|
pub impl Encode for IntConstant with fn encode(value, buf) {
  if Encode::encode(value.width, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_uint64(value.bits, buf)
}

///|
pub impl Encode for V128Bits with fn encode(value, buf) {
  if encode_compiler_fact_uint64(value.low, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_uint64(value.high, buf)
}

///|
pub impl Encode for FactHeapType with fn encode(value, buf) {
  match value {
    TypeIndex(index) => {
      buf.write_byte(0x00)
      encode_compiler_fact_uint(index, buf)
    }
    Any => {
      buf.write_byte(0x01)
      Ok(())
    }
    Eq => {
      buf.write_byte(0x02)
      Ok(())
    }
    Struct => {
      buf.write_byte(0x03)
      Ok(())
    }
    Array => {
      buf.write_byte(0x04)
      Ok(())
    }
    I31 => {
      buf.write_byte(0x05)
      Ok(())
    }
    Func => {
      buf.write_byte(0x06)
      Ok(())
    }
    Extern => {
      buf.write_byte(0x07)
      Ok(())
    }
    Exn => {
      buf.write_byte(0x08)
      Ok(())
    }
    Cont => {
      buf.write_byte(0x09)
      Ok(())
    }
    String => {
      buf.write_byte(0x0A)
      Ok(())
    }
    None => {
      buf.write_byte(0x0B)
      Ok(())
    }
    NoFunc => {
      buf.write_byte(0x0C)
      Ok(())
    }
    NoExtern => {
      buf.write_byte(0x0D)
      Ok(())
    }
    NoExn => {
      buf.write_byte(0x0E)
      Ok(())
    }
    NoCont => {
      buf.write_byte(0x0F)
      Ok(())
    }
  }
}

///|
pub impl Encode for FactValue with fn encode(value, buf) {
  match value {
    IntegerValue(value) => {
      buf.write_byte(0x00)
      Encode::encode(value, buf)
    }
    F32Bits(bits) => {
      buf.write_byte(0x01)
      encode_compiler_fact_uint(bits, buf)
    }
    F64Bits(bits) => {
      buf.write_byte(0x02)
      encode_compiler_fact_uint64(bits, buf)
    }
    V128Value(bits) => {
      buf.write_byte(0x03)
      Encode::encode(bits, buf)
    }
    RefNullValue(heap) => {
      buf.write_byte(0x04)
      Encode::encode(heap, buf)
    }
    RefFuncValue(function) => {
      buf.write_byte(0x05)
      encode_compiler_fact_uint(function, buf)
    }
    ImmutableGlobalValue(global) => {
      buf.write_byte(0x06)
      encode_compiler_fact_uint(global, buf)
    }
  }
}

///|
pub impl Encode for ClosedValueSet with fn encode(value, buf) {
  let @representation.ClosedValueSet(values) = value
  Encode::encode(values, buf)
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
pub impl Encode for KnownBits with fn encode(value, buf) {
  if encode_compiler_fact_uint64(value.known_zero, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_uint64(value.known_one, buf)
}

///|
pub impl Encode for IntegerFacts with fn encode(value, buf) {
  if Encode::encode(value.width, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.unsigned_range, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.signed_range, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.known_bits, buf) is Err(err) {
    return Err(err)
  }
  Encode::encode(value.nonzero, buf)
}

///|
pub impl Encode for FloatWidth with fn encode(value, buf) {
  buf.write_byte(
    match value {
      Float32 => 0x00
      Float64 => 0x01
    },
  )
  Ok(())
}

///|
pub impl Encode for FloatClassMask with fn encode(value, buf) {
  encode_compiler_fact_uint(value.bits(), buf)
}

///|
pub impl Encode for FloatFacts with fn encode(value, buf) {
  if Encode::encode(value.width, buf) is Err(err) {
    return Err(err)
  }
  Encode::encode(value.possible_classes, buf)
}

///|
pub impl Encode for NullabilityFacts with fn encode(value, buf) {
  buf.write_byte(
    match value {
      NullOnly => 0x00
      NonNull => 0x01
    },
  )
  Ok(())
}

///|
pub impl Encode for ClosedHeapTypeSet with fn encode(value, buf) {
  let @representation.ClosedHeapTypeSet(values) = value
  Encode::encode(values, buf)
}

///|
pub impl Encode for HeapDomain with fn encode(value, buf) {
  match value {
    ExactRuntimeType(type_) => {
      buf.write_byte(0x00)
      Encode::encode(type_, buf)
    }
    SubtypesOf(type_) => {
      buf.write_byte(0x01)
      Encode::encode(type_, buf)
    }
    ClosedRuntimeTypes(types) => {
      buf.write_byte(0x02)
      Encode::encode(types, buf)
    }
  }
}

///|
pub impl Encode for ReferenceFacts with fn encode(value, buf) {
  if encode_compiler_fact_option(value.nullability, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.heap, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_option(value.function_targets, buf)
}

///|
pub impl Encode for VectorLaneShape with fn encode(value, buf) {
  buf.write_byte(
    match value {
      I8x16 => 0x00
      I16x8 => 0x01
      I32x4 => 0x02
      I64x2 => 0x03
      F32x4 => 0x04
      F64x2 => 0x05
    },
  )
  Ok(())
}

///|
pub impl Encode for KnownV128Bits with fn encode(value, buf) {
  if Encode::encode(value.known_zero, buf) is Err(err) {
    return Err(err)
  }
  Encode::encode(value.known_one, buf)
}

///|
pub impl Encode for VectorFacts with fn encode(value, buf) {
  if encode_compiler_fact_option(value.known_bits, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.splat, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_option(value.lane_shape, buf)
}

///|
pub impl Encode for ValueFacts with fn encode(value, buf) {
  if encode_compiler_fact_option(value.possible_values, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.integer, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.float_, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.vector, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_option(value.reference, buf)
}

///|
pub impl Encode for ParameterRef with fn encode(value, buf) {
  if encode_compiler_fact_uint(value.function, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_uint(value.parameter, buf)
}

///|
pub impl Encode for FunctionResultRef with fn encode(value, buf) {
  if encode_compiler_fact_uint(value.function, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_uint(value.result, buf)
}

///|
pub impl Encode for ValueRef with fn encode(value, buf) {
  match value {
    SiteValue(site) => {
      buf.write_byte(0x00)
      Encode::encode(site, buf)
    }
    ParameterValue(parameter) => {
      buf.write_byte(0x01)
      Encode::encode(parameter, buf)
    }
    FunctionResultValue(result) => {
      buf.write_byte(0x02)
      Encode::encode(result, buf)
    }
    GlobalValue(global) => {
      buf.write_byte(0x03)
      encode_compiler_fact_uint(global, buf)
    }
  }
}

///|
pub impl Encode for AliasSource with fn encode(value, buf) {
  match value {
    ParameterAlias(parameter) => {
      buf.write_byte(0x00)
      encode_compiler_fact_uint(parameter, buf)
    }
    GlobalAlias(global) => {
      buf.write_byte(0x01)
      encode_compiler_fact_uint(global, buf)
    }
    SiteAlias(site) => {
      buf.write_byte(0x02)
      Encode::encode(site, buf)
    }
  }
}

///|
pub impl Encode for ClosedAliasSet with fn encode(value, buf) {
  let @representation.ClosedAliasSet(values) = value
  Encode::encode(values, buf)
}

///|
pub impl Encode for ResultIdentityFacts with fn encode(value, buf) {
  match value {
    FreshReference => {
      buf.write_byte(0x00)
      Ok(())
    }
    ClosedAliases(aliases) => {
      buf.write_byte(0x01)
      Encode::encode(aliases, buf)
    }
  }
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
pub impl Encode for ParameterUseMask with fn encode(value, buf) {
  encode_compiler_fact_uint64(value.bits(), buf)
}

///|
pub impl Encode for EscapeSinkMask with fn encode(value, buf) {
  encode_compiler_fact_uint64(value.bits(), buf)
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
pub impl Encode for IndexedValueFacts with fn encode(value, buf) {
  if encode_compiler_fact_uint(value.index, buf) is Err(err) {
    return Err(err)
  }
  Encode::encode(value.value, buf)
}

///|
pub impl Encode for SignatureFacts with fn encode(value, buf) {
  if encode_compiler_fact_uint(value.signature, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.parameters, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.results, buf) is Err(err) {
    return Err(err)
  }
  Encode::encode(value.call_sites_complete, buf)
}

///|
pub impl Encode for TypeView with fn encode(value, buf) {
  match value {
    ExactTypeView(type_) => {
      buf.write_byte(0x00)
      encode_compiler_fact_uint(type_, buf)
    }
    SubtypeClosureView(type_) => {
      buf.write_byte(0x01)
      encode_compiler_fact_uint(type_, buf)
    }
  }
}

///|
pub impl Encode for TypePopulation with fn encode(value, buf) {
  match value {
    EmptyTypePopulation => {
      buf.write_byte(0x00)
      Ok(())
    }
    ClosedTypePopulation(types) => {
      buf.write_byte(0x01)
      Encode::encode(types, buf)
    }
  }
}

///|
pub impl Encode for WriteFacts with fn encode(value, buf) {
  match value {
    NoWrites => {
      buf.write_byte(0x00)
      Ok(())
    }
    InitializationOnly => {
      buf.write_byte(0x01)
      Ok(())
    }
    ClosedWrites(sites) => {
      buf.write_byte(0x02)
      Encode::encode(sites, buf)
    }
  }
}

///|
pub impl Encode for FieldUsageFacts with fn encode(value, buf) {
  if Encode::encode(value.never_read, buf) is Err(err) {
    return Err(err)
  }
  Encode::encode(value.never_written_after_initialization, buf)
}

///|
pub impl Encode for FieldFacts with fn encode(value, buf) {
  if Encode::encode(value.view, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_uint(value.field, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.stored_contents, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.writes, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_option(value.usage, buf)
}

///|
pub impl Encode for ArrayElementFacts with fn encode(value, buf) {
  if Encode::encode(value.view, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.stored_contents, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_option(value.writes, buf)
}

///|
pub impl Encode for TypeFacts with fn encode(value, buf) {
  if encode_compiler_fact_uint(value.type_, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.population, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.fields, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_option(value.array_element, buf)
}

///|
pub impl Encode for MutationPhase with fn encode(value, buf) {
  buf.write_byte(
    match value {
      NeverMutated => 0x00
      InitializationOnlyMutation => 0x01
      RuntimeMutation => 0x02
    },
  )
  Ok(())
}

///|
pub impl Encode for MutationFacts with fn encode(value, buf) {
  if Encode::encode(value.latest_phase, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_option(value.sites, buf)
}

///|
pub impl Encode for GlobalFacts with fn encode(value, buf) {
  if encode_compiler_fact_uint(value.global, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.initial_value, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.steady_state_value, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_option(value.mutation, buf)
}

///|
pub impl Encode for TableEntryFacts with fn encode(value, buf) {
  if encode_compiler_fact_uint64(value.index, buf) is Err(err) {
    return Err(err)
  }
  Encode::encode(value.value, buf)
}

///|
pub impl Encode for TableFacts with fn encode(value, buf) {
  if encode_compiler_fact_uint(value.table, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.mutation, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.may_grow, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.default_value, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.entries, buf) is Err(err) {
    return Err(err)
  }
  Encode::encode(value.contents_complete, buf)
}

///|
pub impl Encode for AllocationKind with fn encode(value, buf) {
  let (tag, type_) = match value {
    StructAllocation(type_) => (0x00, type_)
    ArrayAllocation(type_) => (0x01, type_)
    ClosureAllocation(type_) => (0x02, type_)
    BoxAllocation(type_) => (0x03, type_)
    OtherGcAllocation(type_) => (0x04, type_)
  }
  buf.write_byte(tag.to_byte())
  encode_compiler_fact_uint(type_, buf)
}

///|
pub impl Encode for AllocationFieldFacts with fn encode(value, buf) {
  if encode_compiler_fact_uint(value.field, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.no_post_init_writes, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_option(value.stored_value, buf)
}

///|
pub impl Encode for AllocationFacts with fn encode(value, buf) {
  if Encode::encode(value.kind, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.escape_sinks, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.identity_unobserved, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.thread_confined, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.length, buf) is Err(err) {
    return Err(err)
  }
  Encode::encode(value.fields, buf)
}

///|
pub impl Encode for AllocationSiteFacts with fn encode(value, buf) {
  if Encode::encode(value.site, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.facts, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_option(value.provenance, buf)
}

///|
pub impl Encode for AccessFacts with fn encode(value, buf) {
  if Encode::encode(value.in_bounds, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_uint_option(value.alignment_log2, buf)
}

///|
pub impl Encode for AccessSiteFacts with fn encode(value, buf) {
  if Encode::encode(value.site, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.facts, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_option(value.provenance, buf)
}

///|
pub impl Encode for NumericOperationFacts with fn encode(value, buf) {
  if Encode::encode(value.signed_no_wrap, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.unsigned_no_wrap, buf) is Err(err) {
    return Err(err)
  }
  Encode::encode(value.exact_division, buf)
}

///|
pub impl Encode for NumericOperationSiteFacts with fn encode(value, buf) {
  if Encode::encode(value.site, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.facts, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_option(value.provenance, buf)
}

///|
pub impl Encode for FactOperand with fn encode(value, buf) {
  match value {
    ValueOperand(value) => {
      buf.write_byte(0x00)
      Encode::encode(value, buf)
    }
    ConstantOperand(value) => {
      buf.write_byte(0x01)
      Encode::encode(value, buf)
    }
  }
}

///|
pub impl Encode for RelationKind with fn encode(value, buf) {
  buf.write_byte(
    match value {
      Equal => 0x00
      NotEqual => 0x01
      SignedLessThan => 0x02
      SignedLessOrEqual => 0x03
      UnsignedLessThan => 0x04
      UnsignedLessOrEqual => 0x05
      SameReference => 0x06
      DistinctReferences => 0x07
    },
  )
  Ok(())
}

///|
pub impl Encode for ScopedRelationFacts with fn encode(value, buf) {
  if Encode::encode(value.at, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.left, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.kind, buf) is Err(err) {
    return Err(err)
  }
  Encode::encode(value.right, buf)
}

///|
pub impl Encode for ExpressionFact with fn encode(value, buf) {
  if Encode::encode(value.value, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.facts, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_option(value.provenance, buf)
}

///|
pub impl Encode for CallSiteFacts with fn encode(value, buf) {
  if Encode::encode(value.site, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_uint_option(value.direct_target, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.profile, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.inline_policy, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_option(value.provenance, buf)
}

///|
pub impl Encode for BranchFacts with fn encode(value, buf) {
  if Encode::encode(value.site, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.profile, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.temperature, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_option(value.provenance, buf)
}

///|
pub impl Encode for LoopFacts with fn encode(value, buf) {
  if Encode::encode(value.site, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.profile, buf) is Err(err) {
    return Err(err)
  }
  if encode_compiler_fact_option(value.temperature, buf) is Err(err) {
    return Err(err)
  }
  encode_compiler_fact_option(value.provenance, buf)
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
  if Encode::encode(value.allocations, buf) is Err(err) {
    return Err(err)
  }
  if Encode::encode(value.accesses, buf) is Err(err) {
    return Err(err)
  }
  Encode::encode(value.numeric_operations, buf)
}

///|
pub impl Encode for OptimizationGoal with fn encode(value, buf) {
  buf.write_byte(
    match value {
      PreferSpeed => 0x00
      Balanced => 0x01
      PreferSize => 0x02
    },
  )
  Ok(())
}

///|
pub impl Encode for HintTarget with fn encode(value, buf) {
  match value {
    FunctionHintTarget(function) => {
      buf.write_byte(0x00)
      encode_compiler_fact_uint(function, buf)
    }
    SiteHintTarget(site) => {
      buf.write_byte(0x01)
      Encode::encode(site, buf)
    }
  }
}

///|
pub impl Encode for OptimizationHint with fn encode(value, buf) {
  match value {
    HotnessHint(target, temperature) => {
      buf.write_byte(0x00)
      if Encode::encode(target, buf) is Err(err) {
        return Err(err)
      }
      Encode::encode(temperature, buf)
    }
    InlineHint(target, policy) => {
      buf.write_byte(0x01)
      if Encode::encode(target, buf) is Err(err) {
        return Err(err)
      }
      Encode::encode(policy, buf)
    }
    GoalHint(target, goal) => {
      buf.write_byte(0x02)
      if Encode::encode(target, buf) is Err(err) {
        return Err(err)
      }
      Encode::encode(goal, buf)
    }
    BranchProbabilityHint(site, probability) => {
      buf.write_byte(0x03)
      if Encode::encode(site, buf) is Err(err) {
        return Err(err)
      }
      encode_compiler_fact_uint(probability, buf)
    }
    EstimatedLoopTripsHint(site, trips) => {
      buf.write_byte(0x04)
      if Encode::encode(site, buf) is Err(err) {
        return Err(err)
      }
      encode_compiler_fact_uint64(trips, buf)
    }
    LikelyCallTargetHint(site, function, confidence) => {
      buf.write_byte(0x05)
      if Encode::encode(site, buf) is Err(err) {
        return Err(err)
      }
      if encode_compiler_fact_uint(function, buf) is Err(err) {
        return Err(err)
      }
      encode_compiler_fact_uint(confidence, buf)
    }
    LikelyHeapTypeHint(site, type_, confidence) => {
      buf.write_byte(0x06)
      if Encode::encode(site, buf) is Err(err) {
        return Err(err)
      }
      if Encode::encode(type_, buf) is Err(err) {
        return Err(err)
      }
      encode_compiler_fact_uint(confidence, buf)
    }
  }
}

///|
fn encode_compiler_facts_as_custom_section(
  value : CompilerFactCustomSection,
  buf : @buffer.Buffer,
) -> Result[Unit, BinaryEncodeError] {
  write_section(0, buf, fn(payload) {
    if Encode::encode(@lib.Name::new("compiler.facts"), payload) is Err(err) {
      return Err(err)
    }
    Encode::encode(value, payload)
  })
}
