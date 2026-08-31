///| Compiler-facts validation is structural only. It validates references,

///| canonical forms, attachment shapes, masks, ranges, and contradictions that

///|
/// are mechanically obvious. It never proves that advisory assertions are true.
fn[T : Validate] validate_compiler_fact_option(
  value : T?,
  env : Env,
) -> Result[Unit, String] {
  match value {
    Some(value) => Validate::validate(value, env)
    None => Ok(())
  }
}

///|
fn validate_compiler_fact_function_index(
  index : UInt,
  env : Env,
) -> Result[Unit, String] {
  if env.has_func(FuncIdx::new(index)) {
    Ok(())
  } else {
    Err(
      "compiler facts function index out of range: function=\{index} total_functions=\{env.funcs.length()}",
    )
  }
}

///|
fn validate_compiler_fact_type_index(
  index : UInt,
  env : Env,
) -> Result[Unit, String] {
  if index < env.global_types.length().reinterpret_as_uint() {
    Ok(())
  } else {
    Err(
      "compiler facts type index out of range: type=\{index} total_types=\{env.global_types.length()}",
    )
  }
}

///|
fn validate_compiler_fact_global_index(
  index : UInt,
  env : Env,
) -> Result[Unit, String] {
  if env.get_global_type(GlobalIdx::new(index)) is Some(_) {
    Ok(())
  } else {
    Err(
      "compiler facts global index out of range: global=\{index} total_globals=\{env.globals.length()}",
    )
  }
}

///|
fn validate_compiler_fact_memory_index(
  index : UInt,
  env : Env,
) -> Result[Unit, String] {
  if env.get_memtype(MemIdx::new(index)) is Some(_) {
    Ok(())
  } else {
    Err(
      "compiler facts memory index out of range: memory=\{index} total_memories=\{env.mems.length()}",
    )
  }
}

///|
fn validate_compiler_fact_table_index(
  index : UInt,
  env : Env,
) -> Result[Unit, String] {
  if env.get_table_type(TableIdx::new(index)) is Some(_) {
    Ok(())
  } else {
    Err(
      "compiler facts table index out of range: table=\{index} total_tables=\{env.tables.length()}",
    )
  }
}

///|
fn validate_compiler_fact_closed_uint_set(
  values : Array[UInt],
  validate_index : (UInt) -> Result[Unit, String],
  label : String,
) -> Result[Unit, String] {
  let mut previous : UInt? = None
  for value in values {
    match previous {
      Some(prev) if value <= prev =>
        return Err("compiler facts \{label} must be sorted and duplicate-free")
      _ => ()
    }
    if validate_index(value) is Err(err) {
      return Err(err)
    }
    previous = Some(value)
  }
  Ok(())
}

///|
fn compiler_fact_unsigned_width_max(width : IntWidth) -> UInt64 {
  match width {
    Int8 => 0xFFUL
    Int16 => 0xFFFFUL
    Int32 => 0xFFFF_FFFFUL
    Int64 => UInt64::lnot(0UL)
  }
}

///|
fn compiler_fact_signed_width_bounds(width : IntWidth) -> (Int64, Int64) {
  match width {
    Int8 => (-128L, 127L)
    Int16 => (-32768L, 32767L)
    Int32 => (-2147483648L, 2147483647L)
    Int64 => (-9223372036854775807L - 1L, 9223372036854775807L)
  }
}

///|
fn compiler_fact_value_is_integer_zero(value : FactValue) -> Bool {
  match value {
    IntegerValue(constant) => constant.bits == 0UL
    _ => false
  }
}

///|
fn compiler_fact_value_family(value : FactValue) -> Int {
  match value {
    IntegerValue(_) => 0
    F32Bits(_) | F64Bits(_) => 1
    V128Value(_) => 2
    RefNullValue(_) | RefFuncValue(_) => 3
    ImmutableGlobalValue(_) => 4
  }
}

///|
fn compiler_fact_value_fits_type(value : FactValue, type_ : ValType) -> Bool {
  match (value, type_) {
    (IntegerValue(c), NumTypeValType(I32NumType)) => c.width != IntWidth::i64()
    (IntegerValue(c), NumTypeValType(I64NumType)) => c.width == IntWidth::i64()
    (F32Bits(_), NumTypeValType(F32NumType)) => true
    (F64Bits(_), NumTypeValType(F64NumType)) => true
    (V128Value(_), VecTypeValType) => true
    (RefNullValue(_), RefTypeValType(_))
    | (RefFuncValue(_), RefTypeValType(_)) => true
    (ImmutableGlobalValue(_), _) => true
    _ => false
  }
}

///|
fn compiler_fact_closed_values_fit_type(
  possible_values : ClosedValueSet?,
  type_ : ValType,
) -> Bool {
  match possible_values {
    Some(@representation.ClosedValueSet(values)) => {
      for value in values {
        if !compiler_fact_value_fits_type(value, type_) {
          return false
        }
      }
      true
    }
    None => true
  }
}

///|
fn compiler_fact_value_facts_fit_type(
  value : ValueFacts,
  type_ : ValType,
) -> Bool {
  let domain_fits = match type_ {
    NumTypeValType(I32NumType) => {
      let integer_fits = match value.integer {
        Some(facts) => facts.width != IntWidth::i64()
        None => true
      }
      value.float_ is None &&
      value.vector is None &&
      value.reference is None &&
      integer_fits
    }
    NumTypeValType(I64NumType) => {
      let integer_fits = match value.integer {
        Some(facts) => facts.width == IntWidth::i64()
        None => true
      }
      value.float_ is None &&
      value.vector is None &&
      value.reference is None &&
      integer_fits
    }
    NumTypeValType(F32NumType) => {
      let float_fits = match value.float_ {
        Some(facts) => facts.width == FloatWidth::f32()
        None => true
      }
      value.integer is None &&
      value.vector is None &&
      value.reference is None &&
      float_fits
    }
    NumTypeValType(F64NumType) => {
      let float_fits = match value.float_ {
        Some(facts) => facts.width == FloatWidth::f64()
        None => true
      }
      value.integer is None &&
      value.vector is None &&
      value.reference is None &&
      float_fits
    }
    VecTypeValType =>
      value.integer is None && value.float_ is None && value.reference is None
    RefTypeValType(_) =>
      value.integer is None && value.float_ is None && value.vector is None
    BotValType => true
  }
  domain_fits &&
  compiler_fact_closed_values_fit_type(value.possible_values, type_)
}

///|
pub impl Validate for CompilerFactCustomSection with fn validate(value, env) {
  if value.version != 1U {
    return Err(
      "unsupported compiler facts version: version=\{value.version} supported=1",
    )
  }
  Validate::validate(value.facts, env)
}

///|
pub impl Validate for ProducerInfo with fn validate(_, _) {
  Ok(())
}

///|
pub impl Validate for WorldMode with fn validate(_, _) {
  Ok(())
}

///|
pub impl Validate for WorldFacts with fn validate(value, env) {
  Validate::validate(value.mode, env)
}

///|
pub impl Validate for OptimizationFactsSec with fn validate(value, env) {
  if validate_compiler_fact_option(value.producer, env) is Err(err) {
    return Err(err)
  }
  if validate_compiler_fact_option(value.world, env) is Err(err) {
    return Err(err)
  }
  let seen_functions = Array::make(env.funcs.length(), false)
  for facts in value.functions {
    let index = facts.function.reinterpret_as_int()
    if index >= 0 && index < seen_functions.length() && seen_functions[index] {
      return Err("duplicate function facts record: function=\{facts.function}")
    }
    if Validate::validate(facts, env) is Err(err) {
      return Err(err)
    }
    if index >= 0 && index < seen_functions.length() {
      seen_functions[index] = true
    }
  }
  let seen_signatures = Array::make(env.global_types.length(), false)
  for facts in value.signatures {
    let index = facts.signature.reinterpret_as_int()
    if index >= 0 && index < seen_signatures.length() && seen_signatures[index] {
      return Err(
        "duplicate signature facts record: signature=\{facts.signature}",
      )
    }
    if Validate::validate(facts, env) is Err(err) {
      return Err(err)
    }
    if index >= 0 && index < seen_signatures.length() {
      seen_signatures[index] = true
    }
  }
  let seen_types = Array::make(env.global_types.length(), false)
  for facts in value.types {
    let index = facts.type_.reinterpret_as_int()
    if index >= 0 && index < seen_types.length() && seen_types[index] {
      return Err("duplicate type facts record: type=\{facts.type_}")
    }
    if Validate::validate(facts, env) is Err(err) {
      return Err(err)
    }
    if index >= 0 && index < seen_types.length() {
      seen_types[index] = true
    }
  }
  let seen_globals = Array::make(env.globals.length(), false)
  for facts in value.globals {
    let index = facts.global.reinterpret_as_int()
    if index >= 0 && index < seen_globals.length() && seen_globals[index] {
      return Err("duplicate global facts record: global=\{facts.global}")
    }
    if Validate::validate(facts, env) is Err(err) {
      return Err(err)
    }
    if index >= 0 && index < seen_globals.length() {
      seen_globals[index] = true
    }
  }
  let seen_tables = Array::make(env.tables.length(), false)
  for facts in value.tables {
    let index = facts.table.reinterpret_as_int()
    if index >= 0 && index < seen_tables.length() && seen_tables[index] {
      return Err("duplicate table facts record: table=\{facts.table}")
    }
    if Validate::validate(facts, env) is Err(err) {
      return Err(err)
    }
    if index >= 0 && index < seen_tables.length() {
      seen_tables[index] = true
    }
  }
  let seen_bodies = Array::make(env.funcs.length(), false)
  for body in value.bodies {
    let index = body.function.reinterpret_as_int()
    if index >= 0 && index < seen_bodies.length() && seen_bodies[index] {
      return Err(
        "duplicate function body facts record: function=\{body.function}",
      )
    }
    if Validate::validate(body, env) is Err(err) {
      return Err(err)
    }
    if index >= 0 && index < seen_bodies.length() {
      seen_bodies[index] = true
    }
  }
  Validate::validate(value.hints, env)
}

///|
pub impl Validate for CodeSite with fn validate(value, env) {
  validate_compiler_fact_function_index(value.function, env)
}

///|
pub impl Validate for ValueSite with fn validate(value, env) {
  Validate::validate(value.site, env)
}

///|
pub impl Validate for SourceProvenance with fn validate(_, _) {
  Ok(())
}

///|
pub impl Validate for IntWidth with fn validate(_, _) {
  Ok(())
}

///|
pub impl Validate for IntConstant with fn validate(value, _) {
  let outside = value.bits &
    UInt64::lnot(compiler_fact_unsigned_width_max(value.width))
  if outside == 0UL {
    Ok(())
  } else {
    Err(
      "compiler facts integer constant has bits outside width: width=\{value.width.bit_count()} bits bits=\{value.bits}",
    )
  }
}

///|
pub impl Validate for V128Bits with fn validate(_, _) {
  Ok(())
}

///|
pub impl Validate for FactHeapType with fn validate(value, env) {
  match value {
    TypeIndex(index) => validate_compiler_fact_type_index(index, env)
    _ => Ok(())
  }
}

///|
pub impl Validate for FactValue with fn validate(value, env) {
  match value {
    IntegerValue(value) => Validate::validate(value, env)
    F32Bits(_) | F64Bits(_) | V128Value(_) => Ok(())
    RefNullValue(heap) => Validate::validate(heap, env)
    RefFuncValue(function) =>
      validate_compiler_fact_function_index(function, env)
    ImmutableGlobalValue(global) =>
      validate_compiler_fact_global_index(global, env)
  }
}

///|
pub impl Validate for ClosedValueSet with fn validate(value, env) {
  let @representation.ClosedValueSet(values) = value
  if ClosedValueSet::new(values) != value {
    return Err(
      "compiler facts closed value set must be sorted and duplicate-free",
    )
  }
  let mut family : Int? = None
  for fact_value in values {
    if Validate::validate(fact_value, env) is Err(err) {
      return Err(err)
    }
    let next_family = compiler_fact_value_family(fact_value)
    match family {
      Some(previous) if previous != next_family =>
        return Err(
          "compiler facts closed value set mixes incompatible value families",
        )
      _ => ()
    }
    family = Some(next_family)
  }
  Ok(())
}

///|
pub impl Validate for SignedRange with fn validate(value, _) {
  if value.min <= value.max {
    Ok(())
  } else {
    Err(
      "compiler facts signed range has min greater than max: min=\{value.min} max=\{value.max}",
    )
  }
}

///|
pub impl Validate for UnsignedRange with fn validate(value, _) {
  if value.min <= value.max {
    Ok(())
  } else {
    Err(
      "compiler facts unsigned range has min greater than max: min=\{value.min} max=\{value.max}",
    )
  }
}

///|
pub impl Validate for KnownBits with fn validate(value, _) {
  if (value.known_zero & value.known_one) == 0UL {
    Ok(())
  } else {
    Err("compiler facts known bits mark the same bit zero and one")
  }
}

///|
pub impl Validate for IntegerFacts with fn validate(value, env) {
  let width_max = compiler_fact_unsigned_width_max(value.width)
  match value.unsigned_range {
    Some(range) => {
      if Validate::validate(range, env) is Err(err) {
        return Err(err)
      }
      if range.max > width_max {
        return Err("compiler facts unsigned range exceeds integer width")
      }
    }
    None => ()
  }
  match value.signed_range {
    Some(range) => {
      if Validate::validate(range, env) is Err(err) {
        return Err(err)
      }
      let (min, max) = compiler_fact_signed_width_bounds(value.width)
      if range.min < min || range.max > max {
        return Err("compiler facts signed range exceeds integer width")
      }
    }
    None => ()
  }
  match value.known_bits {
    Some(bits) => {
      if Validate::validate(bits, env) is Err(err) {
        return Err(err)
      }
      if ((bits.known_zero | bits.known_one) & UInt64::lnot(width_max)) != 0UL {
        return Err("compiler facts known bits exceed integer width")
      }
      match value.unsigned_range {
        Some(range) if bits.known_one > range.max =>
          return Err(
            "compiler facts known-one bits cannot fit the unsigned range",
          )
        _ => ()
      }
    }
    None => ()
  }
  Ok(())
}

///|
pub impl Validate for FloatWidth with fn validate(_, _) {
  Ok(())
}

///|
pub impl Validate for FloatClassMask with fn validate(value, _) {
  let unknown = value.bits() & UInt::lnot(0x1FFU)
  if unknown == 0U {
    Ok(())
  } else {
    Err("compiler facts float class mask contains undefined bits: \{unknown}")
  }
}

///|
pub impl Validate for FloatFacts with fn validate(value, env) {
  Validate::validate(value.possible_classes, env)
}

///|
pub impl Validate for NullabilityFacts with fn validate(_, _) {
  Ok(())
}

///|
pub impl Validate for ClosedHeapTypeSet with fn validate(value, env) {
  let @representation.ClosedHeapTypeSet(types) = value
  if ClosedHeapTypeSet::new(types) != value {
    return Err(
      "compiler facts closed heap type set must be sorted and duplicate-free",
    )
  }
  Validate::validate(types, env)
}

///|
pub impl Validate for HeapDomain with fn validate(value, env) {
  match value {
    ExactRuntimeType(type_) | SubtypesOf(type_) =>
      Validate::validate(type_, env)
    ClosedRuntimeTypes(types) => Validate::validate(types, env)
  }
}

///|
pub impl Validate for ReferenceFacts with fn validate(value, env) {
  if validate_compiler_fact_option(value.nullability, env) is Err(err) {
    return Err(err)
  }
  if validate_compiler_fact_option(value.heap, env) is Err(err) {
    return Err(err)
  }
  validate_compiler_fact_option(value.function_targets, env)
}

///|
pub impl Validate for VectorLaneShape with fn validate(_, _) {
  Ok(())
}

///|
pub impl Validate for KnownV128Bits with fn validate(value, _) {
  if (
      (value.known_zero.low & value.known_one.low) |
      (value.known_zero.high & value.known_one.high)
    ) ==
    0UL {
    Ok(())
  } else {
    Err("compiler facts v128 known bits mark the same bit zero and one")
  }
}

///|
pub impl Validate for VectorFacts with fn validate(value, env) {
  if validate_compiler_fact_option(value.known_bits, env) is Err(err) {
    return Err(err)
  }
  match value.splat {
    Some(IntegerValue(_)) | Some(F32Bits(_)) | Some(F64Bits(_)) => ()
    Some(_) =>
      return Err(
        "compiler facts vector splat must be a scalar numeric fact value",
      )
    None => ()
  }
  if validate_compiler_fact_option(value.splat, env) is Err(err) {
    return Err(err)
  }
  validate_compiler_fact_option(value.lane_shape, env)
}

///|
pub impl Validate for ValueFacts with fn validate(value, env) {
  if validate_compiler_fact_option(value.possible_values, env) is Err(err) {
    return Err(err)
  }
  if validate_compiler_fact_option(value.integer, env) is Err(err) {
    return Err(err)
  }
  if validate_compiler_fact_option(value.float_, env) is Err(err) {
    return Err(err)
  }
  if validate_compiler_fact_option(value.vector, env) is Err(err) {
    return Err(err)
  }
  if validate_compiler_fact_option(value.reference, env) is Err(err) {
    return Err(err)
  }
  let domain_count = (if value.integer is Some(_) { 1 } else { 0 }) +
    (if value.float_ is Some(_) { 1 } else { 0 }) +
    (if value.vector is Some(_) { 1 } else { 0 }) +
    (if value.reference is Some(_) { 1 } else { 0 })
  if domain_count > 1 {
    return Err("compiler facts value domains are mutually incompatible")
  }
  match (value.possible_values, value.integer) {
    (Some(@representation.ClosedValueSet([only])), Some(integer)) if integer.nonzero &&
      compiler_fact_value_is_integer_zero(only) =>
      Err("compiler facts exact integer zero contradicts nonzero=true")
    _ => Ok(())
  }
}

///|
pub impl Validate for ParameterRef with fn validate(value, env) {
  let FuncType(parameters, _) = match
    env.get_functype_by_funcidx(FuncIdx::new(value.function)) {
    Some(type_) => type_
    None =>
      return Err("compiler facts parameter reference has invalid function")
  }
  if value.parameter < parameters.length().reinterpret_as_uint() {
    Ok(())
  } else {
    Err("compiler facts parameter reference index out of range")
  }
}

///|
pub impl Validate for FunctionResultRef with fn validate(value, env) {
  let FuncType(_, results) = match
    env.get_functype_by_funcidx(FuncIdx::new(value.function)) {
    Some(type_) => type_
    None =>
      return Err(
        "compiler facts function result reference has invalid function",
      )
  }
  if value.result < results.length().reinterpret_as_uint() {
    Ok(())
  } else {
    Err("compiler facts function result reference index out of range")
  }
}

///|
pub impl Validate for ValueRef with fn validate(value, env) {
  match value {
    SiteValue(site) => Validate::validate(site, env)
    ParameterValue(parameter) => Validate::validate(parameter, env)
    FunctionResultValue(result) => Validate::validate(result, env)
    GlobalValue(global) => validate_compiler_fact_global_index(global, env)
  }
}

///|
pub impl Validate for AliasSource with fn validate(value, env) {
  match value {
    ParameterAlias(_) => Ok(())
    GlobalAlias(global) => validate_compiler_fact_global_index(global, env)
    SiteAlias(site) => Validate::validate(site, env)
  }
}

///|
pub impl Validate for ClosedAliasSet with fn validate(value, env) {
  let @representation.ClosedAliasSet(sources) = value
  if ClosedAliasSet::new(sources) != value {
    return Err(
      "compiler facts closed alias set must be sorted and duplicate-free",
    )
  }
  Validate::validate(sources, env)
}

///|
pub impl Validate for ResultIdentityFacts with fn validate(value, env) {
  match value {
    FreshReference => Ok(())
    ClosedAliases(aliases) => Validate::validate(aliases, env)
  }
}

///|
pub impl Validate for ParameterUseMask with fn validate(value, _) {
  let unknown = value.bits() & UInt64::lnot(0x7FUL)
  if unknown == 0UL {
    Ok(())
  } else {
    Err("compiler facts parameter use mask contains undefined bits: \{unknown}")
  }
}

///|
pub impl Validate for EscapeSinkMask with fn validate(value, _) {
  let unknown = value.bits() & UInt64::lnot(0xFFUL)
  if unknown == 0UL {
    Ok(())
  } else {
    Err("compiler facts escape sink mask contains undefined bits: \{unknown}")
  }
}

///|
pub impl Validate for EffectMask with fn validate(value, _) {
  let unknown = value.bits() & UInt64::lnot(0x7F_FFFFUL)
  if unknown == 0UL {
    Ok(())
  } else {
    Err("compiler facts effect mask contains undefined bits: \{unknown}")
  }
}

///|
pub impl Validate for ClosedGlobalSet with fn validate(value, env) {
  let @representation.ClosedGlobalSet(values) = value
  validate_compiler_fact_closed_uint_set(
    values,
    fn(i) { validate_compiler_fact_global_index(i, env) },
    "closed global set",
  )
}

///|
pub impl Validate for ClosedMemorySet with fn validate(value, env) {
  let @representation.ClosedMemorySet(values) = value
  validate_compiler_fact_closed_uint_set(
    values,
    fn(i) { validate_compiler_fact_memory_index(i, env) },
    "closed memory set",
  )
}

///|
pub impl Validate for ClosedTableSet with fn validate(value, env) {
  let @representation.ClosedTableSet(values) = value
  validate_compiler_fact_closed_uint_set(
    values,
    fn(i) { validate_compiler_fact_table_index(i, env) },
    "closed table set",
  )
}

///|
pub impl Validate for ClosedTypeViewSet with fn validate(value, env) {
  let @representation.ClosedTypeViewSet(values) = value
  validate_compiler_fact_closed_uint_set(
    values,
    fn(i) { validate_compiler_fact_type_index(i, env) },
    "closed type view set",
  )
}

///|
pub impl Validate for ClosedFunctionSet with fn validate(value, env) {
  let @representation.ClosedFunctionSet(values) = value
  validate_compiler_fact_closed_uint_set(
    values,
    fn(i) { validate_compiler_fact_function_index(i, env) },
    "closed function set",
  )
}

///|
pub impl Validate for EffectFacts with fn validate(value, env) {
  if Validate::validate(value.may, env) is Err(err) {
    return Err(err)
  }
  if validate_compiler_fact_option(value.read_globals, env) is Err(err) {
    return Err(err)
  }
  if validate_compiler_fact_option(value.written_globals, env) is Err(err) {
    return Err(err)
  }
  if validate_compiler_fact_option(value.read_memories, env) is Err(err) {
    return Err(err)
  }
  if validate_compiler_fact_option(value.written_memories, env) is Err(err) {
    return Err(err)
  }
  if validate_compiler_fact_option(value.read_tables, env) is Err(err) {
    return Err(err)
  }
  if validate_compiler_fact_option(value.written_tables, env) is Err(err) {
    return Err(err)
  }
  if validate_compiler_fact_option(value.read_heap_types, env) is Err(err) {
    return Err(err)
  }
  if validate_compiler_fact_option(value.written_heap_types, env) is Err(err) {
    return Err(err)
  }
  validate_compiler_fact_option(value.direct_callees, env)
}

///|
pub impl Validate for FunctionBoundaryFacts with fn validate(_, _) {
  Ok(())
}

///|
pub impl Validate for FunctionProfile with fn validate(value, env) {
  validate_compiler_fact_option(value.temperature, env)
}

///|
pub impl Validate for CallProfile with fn validate(value, env) {
  validate_compiler_fact_option(value.temperature, env)
}

///|
pub impl Validate for BranchProfile with fn validate(_, _) {
  Ok(())
}

///|
pub impl Validate for LoopProfile with fn validate(_, _) {
  Ok(())
}

///|
pub impl Validate for TemperatureHint with fn validate(_, _) {
  Ok(())
}

///|
pub impl Validate for InlinePolicy with fn validate(_, _) {
  Ok(())
}

///|
pub impl Validate for ParameterFacts with fn validate(value, env) {
  if validate_compiler_fact_option(value.value, env) is Err(err) {
    return Err(err)
  }
  if validate_compiler_fact_option(value.uses, env) is Err(err) {
    return Err(err)
  }
  validate_compiler_fact_option(value.escape_sinks, env)
}

///|
pub impl Validate for ResultFacts with fn validate(value, env) {
  if validate_compiler_fact_option(value.value, env) is Err(err) {
    return Err(err)
  }
  validate_compiler_fact_option(value.identity, env)
}

///|
pub impl Validate for FunctionFacts with fn validate(value, env) {
  if validate_compiler_fact_function_index(value.function, env) is Err(err) {
    return Err(err)
  }
  let FuncType(parameters, results) = match
    env.get_functype_by_funcidx(FuncIdx::new(value.function)) {
    Some(type_) => type_
    None => return Err("compiler facts function index has no function type")
  }
  if validate_compiler_fact_option(value.effects, env) is Err(err) {
    return Err(err)
  }
  let seen_parameters = Array::make(parameters.length(), false)
  for parameter in value.parameters {
    let index = parameter.parameter.reinterpret_as_int()
    if index < 0 || index >= parameters.length() {
      return Err(
        "compiler facts parameter index out of range: function=\{value.function} parameter=\{parameter.parameter}",
      )
    }
    if seen_parameters[index] {
      return Err(
        "duplicate compiler facts parameter record: function=\{value.function} parameter=\{parameter.parameter}",
      )
    }
    if Validate::validate(parameter, env) is Err(err) {
      return Err(err)
    }
    match parameter.value {
      Some(facts) if !compiler_fact_value_facts_fit_type(
          facts,
          parameters[index],
        ) =>
        return Err(
          "compiler facts parameter value domain is incompatible with parameter type",
        )
      _ => ()
    }
    seen_parameters[index] = true
  }
  let seen_results = Array::make(results.length(), false)
  for result in value.results {
    let index = result.result.reinterpret_as_int()
    if index < 0 || index >= results.length() {
      return Err(
        "compiler facts result index out of range: function=\{value.function} result=\{result.result}",
      )
    }
    if seen_results[index] {
      return Err(
        "duplicate compiler facts result record: function=\{value.function} result=\{result.result}",
      )
    }
    if Validate::validate(result, env) is Err(err) {
      return Err(err)
    }
    match result.value {
      Some(facts) if !compiler_fact_value_facts_fit_type(facts, results[index]) =>
        return Err(
          "compiler facts result value domain is incompatible with result type",
        )
      _ => ()
    }
    match result.identity {
      Some(ClosedAliases(@representation.ClosedAliasSet(sources))) =>
        for source in sources {
          match source {
            ParameterAlias(parameter) if parameter >=
              parameters.length().reinterpret_as_uint() =>
              return Err("compiler facts identity parameter index out of range")
            _ => ()
          }
        }
      _ => ()
    }
    seen_results[index] = true
  }
  if validate_compiler_fact_option(value.boundary, env) is Err(err) {
    return Err(err)
  }
  if validate_compiler_fact_option(value.profile, env) is Err(err) {
    return Err(err)
  }
  validate_compiler_fact_option(value.inline_policy, env)
}

///|
pub impl Validate for IndexedValueFacts with fn validate(value, env) {
  Validate::validate(value.value, env)
}

///|
pub impl Validate for SignatureFacts with fn validate(value, env) {
  let FuncType(parameters, results) = match
    env.resolve_functype(TypeIdx::new(value.signature)) {
    Some(type_) => type_
    None =>
      return Err(
        "compiler facts signature index must reference a function type",
      )
  }
  let seen_parameters = Array::make(parameters.length(), false)
  for facts in value.parameters {
    let index = facts.index.reinterpret_as_int()
    if index < 0 || index >= parameters.length() {
      return Err("compiler facts signature parameter index out of range")
    }
    if seen_parameters[index] {
      return Err("duplicate compiler facts signature parameter record")
    }
    if Validate::validate(facts, env) is Err(err) {
      return Err(err)
    }
    if !compiler_fact_value_facts_fit_type(facts.value, parameters[index]) {
      return Err("compiler facts signature parameter domain is incompatible")
    }
    seen_parameters[index] = true
  }
  let seen_results = Array::make(results.length(), false)
  for facts in value.results {
    let index = facts.index.reinterpret_as_int()
    if index < 0 || index >= results.length() {
      return Err("compiler facts signature result index out of range")
    }
    if seen_results[index] {
      return Err("duplicate compiler facts signature result record")
    }
    if Validate::validate(facts, env) is Err(err) {
      return Err(err)
    }
    if !compiler_fact_value_facts_fit_type(facts.value, results[index]) {
      return Err("compiler facts signature result domain is incompatible")
    }
    seen_results[index] = true
  }
  Ok(())
}

///|
pub impl Validate for TypeView with fn validate(value, env) {
  match value {
    ExactTypeView(type_) | SubtypeClosureView(type_) =>
      validate_compiler_fact_type_index(type_, env)
  }
}

///|
pub impl Validate for TypePopulation with fn validate(value, env) {
  match value {
    EmptyTypePopulation => Ok(())
    ClosedTypePopulation(types) => Validate::validate(types, env)
  }
}

///|
pub impl Validate for WriteFacts with fn validate(value, env) {
  match value {
    NoWrites | InitializationOnly => Ok(())
    ClosedWrites(sites) => {
      if WriteFacts::closed(sites) != value {
        return Err(
          "compiler facts closed write sites must be sorted and duplicate-free",
        )
      }
      Validate::validate(sites, env)
    }
  }
}

///|
pub impl Validate for FieldUsageFacts with fn validate(_, _) {
  Ok(())
}

///|
fn compiler_fact_type_view_index(view : TypeView) -> UInt {
  match view {
    ExactTypeView(type_) | SubtypeClosureView(type_) => type_
  }
}

///|
pub impl Validate for FieldFacts with fn validate(value, env) {
  if Validate::validate(value.view, env) is Err(err) {
    return Err(err)
  }
  let type_ = TypeIdx::new(compiler_fact_type_view_index(value.view))
  let fields = match env.resolve_comptype(type_) {
    Some(StructCompType(fields)) => fields
    Some(_) =>
      return Err("compiler facts field view must reference a struct type")
    None => return Err("compiler facts field view type does not exist")
  }
  let index = value.field.reinterpret_as_int()
  if index < 0 || index >= fields.length() {
    return Err("compiler facts struct field index out of range")
  }
  if validate_compiler_fact_option(value.stored_contents, env) is Err(err) {
    return Err(err)
  }
  match value.stored_contents {
    Some(facts) if !compiler_fact_value_facts_fit_type(
        facts,
        fields[index].unpack(),
      ) =>
      return Err(
        "compiler facts stored field domain is incompatible with storage type",
      )
    _ => ()
  }
  if validate_compiler_fact_option(value.writes, env) is Err(err) {
    return Err(err)
  }
  validate_compiler_fact_option(value.usage, env)
}

///|
pub impl Validate for ArrayElementFacts with fn validate(value, env) {
  if Validate::validate(value.view, env) is Err(err) {
    return Err(err)
  }
  let field = match
    env.resolve_comptype(
      TypeIdx::new(compiler_fact_type_view_index(value.view)),
    ) {
    Some(ArrayCompType(field)) => field
    Some(_) =>
      return Err(
        "compiler facts array element view must reference an array type",
      )
    None => return Err("compiler facts array element view type does not exist")
  }
  if validate_compiler_fact_option(value.stored_contents, env) is Err(err) {
    return Err(err)
  }
  match value.stored_contents {
    Some(facts) if !compiler_fact_value_facts_fit_type(facts, field.unpack()) =>
      return Err(
        "compiler facts array element domain is incompatible with storage type",
      )
    _ => ()
  }
  validate_compiler_fact_option(value.writes, env)
}

///|
pub impl Validate for TypeFacts with fn validate(value, env) {
  if validate_compiler_fact_type_index(value.type_, env) is Err(err) {
    return Err(err)
  }
  if validate_compiler_fact_option(value.population, env) is Err(err) {
    return Err(err)
  }
  for field in value.fields {
    if compiler_fact_type_view_index(field.view) != value.type_ {
      return Err("compiler facts field view does not match containing type")
    }
    if Validate::validate(field, env) is Err(err) {
      return Err(err)
    }
  }
  match value.array_element {
    Some(array) => {
      if compiler_fact_type_view_index(array.view) != value.type_ {
        return Err("compiler facts array view does not match containing type")
      }
      Validate::validate(array, env)
    }
    None => Ok(())
  }
}

///|
pub impl Validate for MutationPhase with fn validate(_, _) {
  Ok(())
}

///|
pub impl Validate for MutationFacts with fn validate(value, env) {
  if Validate::validate(value.latest_phase, env) is Err(err) {
    return Err(err)
  }
  validate_compiler_fact_option(value.sites, env)
}

///|
pub impl Validate for GlobalFacts with fn validate(value, env) {
  if validate_compiler_fact_global_index(value.global, env) is Err(err) {
    return Err(err)
  }
  if validate_compiler_fact_option(value.initial_value, env) is Err(err) {
    return Err(err)
  }
  if validate_compiler_fact_option(value.steady_state_value, env) is Err(err) {
    return Err(err)
  }
  validate_compiler_fact_option(value.mutation, env)
}

///|
pub impl Validate for TableEntryFacts with fn validate(value, env) {
  Validate::validate(value.value, env)
}

///|
pub impl Validate for TableFacts with fn validate(value, env) {
  if validate_compiler_fact_table_index(value.table, env) is Err(err) {
    return Err(err)
  }
  if validate_compiler_fact_option(value.mutation, env) is Err(err) {
    return Err(err)
  }
  if validate_compiler_fact_option(value.default_value, env) is Err(err) {
    return Err(err)
  }
  let mut previous : UInt64? = None
  for entry in value.entries {
    match previous {
      Some(index) if entry.index <= index =>
        return Err(
          "compiler facts table entries must be sorted and duplicate-free",
        )
      _ => ()
    }
    if Validate::validate(entry, env) is Err(err) {
      return Err(err)
    }
    previous = Some(entry.index)
  }
  Ok(())
}

///|
fn compiler_fact_allocation_type(value : AllocationKind) -> UInt {
  match value {
    StructAllocation(type_)
    | ArrayAllocation(type_)
    | ClosureAllocation(type_)
    | BoxAllocation(type_)
    | OtherGcAllocation(type_) => type_
  }
}

///|
pub impl Validate for AllocationKind with fn validate(value, env) {
  let type_ = compiler_fact_allocation_type(value)
  if validate_compiler_fact_type_index(type_, env) is Err(err) {
    return Err(err)
  }
  match (value, env.resolve_comptype(TypeIdx::new(type_))) {
    (StructAllocation(_), Some(StructCompType(_)))
    | (ArrayAllocation(_), Some(ArrayCompType(_))) => Ok(())
    (StructAllocation(_), _) =>
      Err("compiler facts struct allocation kind must reference a struct type")
    (ArrayAllocation(_), _) =>
      Err("compiler facts array allocation kind must reference an array type")
    _ => Ok(())
  }
}

///|
pub impl Validate for AllocationFieldFacts with fn validate(value, env) {
  validate_compiler_fact_option(value.stored_value, env)
}

///|
pub impl Validate for AllocationFacts with fn validate(value, env) {
  if Validate::validate(value.kind, env) is Err(err) {
    return Err(err)
  }
  if validate_compiler_fact_option(value.escape_sinks, env) is Err(err) {
    return Err(err)
  }
  match (value.kind, value.length) {
    (ArrayAllocation(_), _) => ()
    (_, Some(_)) =>
      return Err(
        "compiler facts allocation length is only valid for array allocations",
      )
    _ => ()
  }
  if validate_compiler_fact_option(value.length, env) is Err(err) {
    return Err(err)
  }
  let fields = match
    env.resolve_comptype(
      TypeIdx::new(compiler_fact_allocation_type(value.kind)),
    ) {
    Some(StructCompType(fields)) => Some(fields)
    _ => None
  }
  let seen : Array[Bool] = match fields {
    Some(fields) => Array::make(fields.length(), false)
    None => []
  }
  for field in value.fields {
    if Validate::validate(field, env) is Err(err) {
      return Err(err)
    }
    match fields {
      Some(field_types) => {
        let index = field.field.reinterpret_as_int()
        if index < 0 || index >= field_types.length() {
          return Err("compiler facts allocation field index out of range")
        }
        if seen[index] {
          return Err("duplicate compiler facts allocation field record")
        }
        match field.stored_value {
          Some(facts) if !compiler_fact_value_facts_fit_type(
              facts,
              field_types[index].unpack(),
            ) =>
            return Err("compiler facts allocation field domain is incompatible")
          _ => ()
        }
        seen[index] = true
      }
      None =>
        if !value.fields.is_empty() {
          return Err(
            "compiler facts allocation fields require a struct-like allocation",
          )
        }
    }
  }
  Ok(())
}

///|
pub impl Validate for AllocationSiteFacts with fn validate(value, env) {
  if Validate::validate(value.site, env) is Err(err) {
    return Err(err)
  }
  if Validate::validate(value.facts, env) is Err(err) {
    return Err(err)
  }
  validate_compiler_fact_option(value.provenance, env)
}

///|
pub impl Validate for AccessFacts with fn validate(value, _) {
  match value.alignment_log2 {
    Some(alignment) if alignment > 63U =>
      Err("compiler facts access alignment_log2 is out of range")
    _ => Ok(())
  }
}

///|
pub impl Validate for AccessSiteFacts with fn validate(value, env) {
  if Validate::validate(value.site, env) is Err(err) {
    return Err(err)
  }
  if Validate::validate(value.facts, env) is Err(err) {
    return Err(err)
  }
  validate_compiler_fact_option(value.provenance, env)
}

///|
pub impl Validate for NumericOperationFacts with fn validate(_, _) {
  Ok(())
}

///|
pub impl Validate for NumericOperationSiteFacts with fn validate(value, env) {
  if Validate::validate(value.site, env) is Err(err) {
    return Err(err)
  }
  if Validate::validate(value.facts, env) is Err(err) {
    return Err(err)
  }
  validate_compiler_fact_option(value.provenance, env)
}

///|
pub impl Validate for FactOperand with fn validate(value, env) {
  match value {
    ValueOperand(value) => Validate::validate(value, env)
    ConstantOperand(value) => Validate::validate(value, env)
  }
}

///|
pub impl Validate for RelationKind with fn validate(_, _) {
  Ok(())
}

///|
pub impl Validate for ScopedRelationFacts with fn validate(value, env) {
  if Validate::validate(value.at, env) is Err(err) {
    return Err(err)
  }
  if Validate::validate(value.left, env) is Err(err) {
    return Err(err)
  }
  if Validate::validate(value.kind, env) is Err(err) {
    return Err(err)
  }
  Validate::validate(value.right, env)
}

///|
pub impl Validate for ExpressionFact with fn validate(value, env) {
  if Validate::validate(value.value, env) is Err(err) {
    return Err(err)
  }
  if Validate::validate(value.facts, env) is Err(err) {
    return Err(err)
  }
  validate_compiler_fact_option(value.provenance, env)
}

///|
pub impl Validate for CallSiteFacts with fn validate(value, env) {
  if Validate::validate(value.site, env) is Err(err) {
    return Err(err)
  }
  match value.direct_target {
    Some(index) =>
      if validate_compiler_fact_function_index(index, env) is Err(err) {
        return Err(err)
      }
    None => ()
  }
  if validate_compiler_fact_option(value.profile, env) is Err(err) {
    return Err(err)
  }
  if validate_compiler_fact_option(value.inline_policy, env) is Err(err) {
    return Err(err)
  }
  validate_compiler_fact_option(value.provenance, env)
}

///|
pub impl Validate for BranchFacts with fn validate(value, env) {
  if Validate::validate(value.site, env) is Err(err) {
    return Err(err)
  }
  if validate_compiler_fact_option(value.profile, env) is Err(err) {
    return Err(err)
  }
  if validate_compiler_fact_option(value.temperature, env) is Err(err) {
    return Err(err)
  }
  validate_compiler_fact_option(value.provenance, env)
}

///|
pub impl Validate for LoopFacts with fn validate(value, env) {
  if Validate::validate(value.site, env) is Err(err) {
    return Err(err)
  }
  if validate_compiler_fact_option(value.profile, env) is Err(err) {
    return Err(err)
  }
  if validate_compiler_fact_option(value.temperature, env) is Err(err) {
    return Err(err)
  }
  validate_compiler_fact_option(value.provenance, env)
}

///|
pub impl Validate for FunctionBodyFacts with fn validate(value, env) {
  if validate_compiler_fact_function_index(value.function, env) is Err(err) {
    return Err(err)
  }
  let seen_values : Array[ValueSite] = []
  for site in value.sites {
    if site.value.site.function != value.function {
      return Err("compiler facts expression site containing function mismatch")
    }
    if seen_values.any(fn(existing) { existing == site.value }) {
      return Err("duplicate compiler facts value site record")
    }
    if Validate::validate(site, env) is Err(err) {
      return Err(err)
    }
    seen_values.push(site.value)
  }
  for relation in value.relations {
    if relation.at.function != value.function {
      return Err("compiler facts relation containing function mismatch")
    }
    if Validate::validate(relation, env) is Err(err) {
      return Err(err)
    }
  }
  let seen_calls : Array[CodeSite] = []
  for call in value.calls {
    if call.site.function != value.function {
      return Err("compiler facts call site containing function mismatch")
    }
    if seen_calls.any(fn(site) { site == call.site }) {
      return Err("duplicate compiler facts call site record")
    }
    if Validate::validate(call, env) is Err(err) {
      return Err(err)
    }
    seen_calls.push(call.site)
  }
  for branch in value.branches {
    if branch.site.function != value.function {
      return Err("compiler facts branch site containing function mismatch")
    }
    if Validate::validate(branch, env) is Err(err) {
      return Err(err)
    }
  }
  for loop_ in value.loops {
    if loop_.site.function != value.function {
      return Err("compiler facts loop site containing function mismatch")
    }
    if Validate::validate(loop_, env) is Err(err) {
      return Err(err)
    }
  }
  for allocation in value.allocations {
    if allocation.site.site.function != value.function {
      return Err("compiler facts allocation site containing function mismatch")
    }
    if Validate::validate(allocation, env) is Err(err) {
      return Err(err)
    }
  }
  for access in value.accesses {
    if access.site.function != value.function {
      return Err("compiler facts access site containing function mismatch")
    }
    if Validate::validate(access, env) is Err(err) {
      return Err(err)
    }
  }
  for numeric in value.numeric_operations {
    if numeric.site.site.function != value.function {
      return Err("compiler facts numeric site containing function mismatch")
    }
    if Validate::validate(numeric, env) is Err(err) {
      return Err(err)
    }
  }
  Ok(())
}

///|
pub impl Validate for OptimizationGoal with fn validate(_, _) {
  Ok(())
}

///|
pub impl Validate for HintTarget with fn validate(value, env) {
  match value {
    FunctionHintTarget(function) =>
      validate_compiler_fact_function_index(function, env)
    SiteHintTarget(site) => Validate::validate(site, env)
  }
}

///|
pub impl Validate for OptimizationHint with fn validate(value, env) {
  match value {
    HotnessHint(target, temperature) => {
      if Validate::validate(target, env) is Err(err) {
        return Err(err)
      }
      Validate::validate(temperature, env)
    }
    InlineHint(target, policy) => {
      if Validate::validate(target, env) is Err(err) {
        return Err(err)
      }
      Validate::validate(policy, env)
    }
    GoalHint(target, goal) => {
      if Validate::validate(target, env) is Err(err) {
        return Err(err)
      }
      Validate::validate(goal, env)
    }
    BranchProbabilityHint(site, probability) => {
      if probability > 65535U {
        return Err("compiler facts branch probability exceeds 65535")
      }
      Validate::validate(site, env)
    }
    EstimatedLoopTripsHint(site, _) => Validate::validate(site, env)
    LikelyCallTargetHint(site, function, confidence) => {
      if confidence > 65535U {
        return Err("compiler facts call target confidence exceeds 65535")
      }
      if Validate::validate(site, env) is Err(err) {
        return Err(err)
      }
      validate_compiler_fact_function_index(function, env)
    }
    LikelyHeapTypeHint(site, type_, confidence) => {
      if confidence > 65535U {
        return Err("compiler facts heap type confidence exceeds 65535")
      }
      if Validate::validate(site, env) is Err(err) {
        return Err(err)
      }
      Validate::validate(type_, env)
    }
  }
}

///|
fn module_has_compiler_fact_metadata(module_ : Module) -> Bool {
  if module_.compiler_fact_custom_section is Some(_) {
    return true
  }
  module_.custom_secs.any(fn(custom) {
    let CustomSec(name, _) = custom
    name == Name::new("compiler.facts")
  })
}

///|
priv struct CompilerFactOpcodeIndex {
  imported_functions : Int
  defined_sites : Array[Array[(UInt, Instruction)]]
}

///|
fn compiler_fact_opcode_index(
  module_ : Module,
  imported_functions : Int,
) -> Result[CompilerFactOpcodeIndex, String] {
  match @binary.compiler_fact_module_opcode_sites(module_) {
    Ok(defined_sites) => Ok({ imported_functions, defined_sites })
    Err(err) =>
      Err(
        "compiler facts could not index encoded function instructions: \{err}",
      )
  }
}

///|
fn compiler_fact_instruction_at(
  index : CompilerFactOpcodeIndex,
  site : CodeSite,
  kind : String,
) -> Result[Instruction, String] {
  let defined = site.function.reinterpret_as_int() - index.imported_functions
  if defined < 0 || defined >= index.defined_sites.length() {
    return Err(
      "compiler facts instruction site has no defined function body: kind=\{kind} function=\{site.function} offset=\{site.offset}",
    )
  }
  for candidate in index.defined_sites[defined] {
    if candidate.0 == site.offset {
      return Ok(candidate.1)
    }
  }
  Err(
    "compiler facts instruction site does not exist: kind=\{kind} function=\{site.function} offset=\{site.offset}",
  )
}

///|
fn compiler_fact_block_result_arity(block_type : BlockType, env : Env) -> UInt? {
  match env.expand_blocktype(block_type) {
    Ok((_, results)) => Some(results.length().reinterpret_as_uint())
    Err(_) => None
  }
}

///|
fn compiler_fact_instruction_result_arity(
  instr : Instruction,
  env : Env,
) -> UInt? {
  match instr {
    Call(function) =>
      match env.get_functype_by_funcidx(function) {
        Some(FuncType(_, results)) =>
          Some(results.length().reinterpret_as_uint())
        None => None
      }
    CallIndirect(type_, _) | CallRef(type_) =>
      match env.resolve_functype(type_) {
        Some(FuncType(_, results)) =>
          Some(results.length().reinterpret_as_uint())
        None => None
      }
    Block(type_, _)
    | Loop(type_, _)
    | If(type_, _, _)
    | Try(type_, _, _, _)
    | TryTable(type_, _, _) => compiler_fact_block_result_arity(type_, env)
    Unreachable
    | Nop
    | Throw(_)
    | ThrowRef
    | Rethrow(_)
    | Br(_)
    | BrIf(_)
    | BrTable(_, _)
    | Return
    | ReturnCall(_)
    | ReturnCallIndirect(_, _)
    | ReturnCallRef(_)
    | LocalSet(_)
    | GlobalSet(_)
    | TableSet(_)
    | I32Store(_)
    | I64Store(_)
    | F32Store(_)
    | F64Store(_)
    | I32Store8(_)
    | I32Store16(_)
    | I64Store8(_)
    | I64Store16(_)
    | I64Store32(_)
    | AtomicFence(_)
    | I32AtomicStore(_, _)
    | I64AtomicStore(_, _)
    | I32AtomicStore8(_, _)
    | I32AtomicStore16(_, _)
    | I64AtomicStore8(_, _)
    | I64AtomicStore16(_, _)
    | I64AtomicStore32(_, _)
    | StructSet(_, _)
    | ArraySet(_)
    | ArrayStore(_, _)
    | ArrayFill(_)
    | ArrayCopy(_, _)
    | ArrayInitData(_, _)
    | ArrayInitElem(_, _)
    | MemoryInit(_, _)
    | DataDrop(_)
    | MemoryCopy(_, _)
    | MemoryFill(_)
    | TableInit(_, _)
    | ElemDrop(_)
    | TableCopy(_, _)
    | TableFill(_)
    | V128Store(_)
    | V128Store8Lane(_, _)
    | V128Store16Lane(_, _)
    | V128Store32Lane(_, _)
    | V128Store64Lane(_, _)
    | Drop => Some(0U)
    _ => Some(1U)
  }
}

///|
fn compiler_fact_is_call_opcode(instr : Instruction) -> Bool {
  match instr {
    Call(_)
    | CallIndirect(_, _)
    | CallRef(_)
    | ReturnCall(_)
    | ReturnCallIndirect(_, _)
    | ReturnCallRef(_) => true
    _ => false
  }
}

///|
fn compiler_fact_is_allocation_opcode(instr : Instruction) -> Bool {
  match instr {
    StructNew(_)
    | StructNewDefault(_)
    | StructNewDesc(_)
    | StructNewDefaultDesc(_)
    | ArrayNew(_)
    | ArrayNewDefault(_)
    | ArrayNewFixed(_, _)
    | ArrayNewData(_, _)
    | ArrayNewElem(_, _)
    | ContNew(_)
    | RefI31 => true
    _ => false
  }
}

///|
fn compiler_fact_is_access_opcode(instr : Instruction) -> Bool {
  match instr {
    TableGet(_)
    | TableSet(_)
    | I32Load(_)
    | I64Load(_)
    | F32Load(_)
    | F64Load(_)
    | I32Load8S(_)
    | I32Load8U(_)
    | I32Load16S(_)
    | I32Load16U(_)
    | I64Load8S(_)
    | I64Load8U(_)
    | I64Load16S(_)
    | I64Load16U(_)
    | I64Load32S(_)
    | I64Load32U(_)
    | I32Store(_)
    | I64Store(_)
    | F32Store(_)
    | F64Store(_)
    | I32Store8(_)
    | I32Store16(_)
    | I64Store8(_)
    | I64Store16(_)
    | I64Store32(_)
    | StructGet(_, _)
    | StructGetS(_, _)
    | StructGetU(_, _)
    | StructSet(_, _)
    | ArrayGet(_)
    | ArrayGetS(_)
    | ArrayGetU(_)
    | ArraySet(_)
    | ArrayLoad(_, _)
    | ArrayStore(_, _) => true
    _ => false
  }
}

///|
fn compiler_fact_is_numeric_opcode(instr : Instruction) -> Bool {
  match instr {
    I32Add
    | I32Sub
    | I32Mul
    | I32DivS
    | I32DivU
    | I32RemS
    | I32RemU
    | I64Add
    | I64Sub
    | I64Mul
    | I64DivS
    | I64DivU
    | I64RemS
    | I64RemU => true
    _ => false
  }
}

///|
fn compiler_fact_provenance_suffix(provenance : SourceProvenance?) -> String {
  match provenance {
    Some(value) =>
      " body_id=\{value.body_id} expression_id=\{value.expression_id}"
    None => ""
  }
}

///|
fn validate_compiler_fact_value_site(
  index : CompilerFactOpcodeIndex,
  value : ValueSite,
  env : Env,
  kind : String,
  provenance : SourceProvenance?,
) -> Result[Instruction, String] {
  let instr = match compiler_fact_instruction_at(index, value.site, kind) {
    Ok(instr) => instr
    Err(err) => return Err(err + compiler_fact_provenance_suffix(provenance))
  }
  let arity = match compiler_fact_instruction_result_arity(instr, env) {
    Some(arity) => arity
    None =>
      return Err(
        "compiler facts could not resolve instruction result arity" +
        compiler_fact_provenance_suffix(provenance),
      )
  }
  if value.result >= arity {
    return Err(
      "compiler facts value result index out of range: function=\{value.site.function} offset=\{value.site.offset} result=\{value.result} result_arity=\{arity}" +
      compiler_fact_provenance_suffix(provenance),
    )
  }
  Ok(instr)
}

///|
fn validate_compiler_fact_operand_sites(
  index : CompilerFactOpcodeIndex,
  operand : FactOperand,
  env : Env,
) -> Result[Unit, String] {
  match operand {
    ValueOperand(SiteValue(site)) =>
      match
        validate_compiler_fact_value_site(
          index,
          site,
          env,
          "relation-value",
          None,
        ) {
        Ok(_) => Ok(())
        Err(err) => Err(err)
      }
    _ => Ok(())
  }
}

///|
fn validate_compiler_fact_body_sites(
  facts : OptimizationFactsSec,
  index : CompilerFactOpcodeIndex,
  env : Env,
) -> Result[Unit, String] {
  for body in facts.bodies {
    let defined = body.function.reinterpret_as_int() - index.imported_functions
    if defined < 0 || defined >= index.defined_sites.length() {
      return Err(
        "compiler facts function body record has no defined function body: function=\{body.function}",
      )
    }
    for site in body.sites {
      if validate_compiler_fact_value_site(
          index,
          site.value,
          env,
          "expression",
          site.provenance,
        )
        is Err(err) {
        return Err(err)
      }
    }
    for relation in body.relations {
      if compiler_fact_instruction_at(index, relation.at, "relation-scope")
        is Err(err) {
        return Err(err)
      }
      if validate_compiler_fact_operand_sites(index, relation.left, env)
        is Err(err) {
        return Err(err)
      }
      if validate_compiler_fact_operand_sites(index, relation.right, env)
        is Err(err) {
        return Err(err)
      }
    }
    for call in body.calls {
      let instr = match compiler_fact_instruction_at(index, call.site, "call") {
        Ok(instr) => instr
        Err(err) =>
          return Err(err + compiler_fact_provenance_suffix(call.provenance))
      }
      if !compiler_fact_is_call_opcode(instr) {
        return Err(
          "compiler facts call fact is attached to a non-call opcode" +
          compiler_fact_provenance_suffix(call.provenance),
        )
      }
      match call.direct_target {
        Some(target) => {
          let target_idx = FuncIdx::new(target)
          match instr {
            CallRef(type_) | ReturnCallRef(type_) => {
              let target_type = match
                env.get_functypeidx_by_funcidx(target_idx) {
                Some(type_) => type_
                None =>
                  return Err(
                    "compiler facts exact-call-target has no target function type" +
                    compiler_fact_provenance_suffix(call.provenance),
                  )
              }
              if !Match::matches(
                  ExternType::func(target_type),
                  ExternType::func(type_),
                  env,
                ) {
                return Err(
                  "compiler facts exact-call-target signature is incompatible: function=\{call.site.function} offset=\{call.site.offset} target=\{target}" +
                  compiler_fact_provenance_suffix(call.provenance),
                )
              }
            }
            Call(actual) | ReturnCall(actual) if actual != target_idx =>
              return Err(
                "compiler facts exact-call-target contradicts direct call target" +
                compiler_fact_provenance_suffix(call.provenance),
              )
            _ => ()
          }
        }
        None => ()
      }
    }
    for branch in body.branches {
      if compiler_fact_instruction_at(index, branch.site, "branch") is Err(err) {
        return Err(err)
      }
    }
    for loop_ in body.loops {
      let instr = match
        compiler_fact_instruction_at(index, loop_.site, "loop") {
        Ok(instr) => instr
        Err(err) => return Err(err)
      }
      if !(instr is Loop(_, _)) {
        return Err("compiler facts loop fact is attached to a non-loop opcode")
      }
    }
    for allocation in body.allocations {
      let instr = match
        validate_compiler_fact_value_site(
          index,
          allocation.site,
          env,
          "allocation",
          allocation.provenance,
        ) {
        Ok(instr) => instr
        Err(err) => return Err(err)
      }
      if !compiler_fact_is_allocation_opcode(instr) {
        return Err(
          "compiler facts allocation fact is attached to a non-allocation opcode" +
          compiler_fact_provenance_suffix(allocation.provenance),
        )
      }
    }
    for access in body.accesses {
      let instr = match
        compiler_fact_instruction_at(index, access.site, "access") {
        Ok(instr) => instr
        Err(err) => return Err(err)
      }
      if !compiler_fact_is_access_opcode(instr) {
        return Err(
          "compiler facts access fact is attached to an incompatible opcode",
        )
      }
    }
    for numeric in body.numeric_operations {
      let instr = match
        validate_compiler_fact_value_site(
          index,
          numeric.site,
          env,
          "numeric-operation",
          numeric.provenance,
        ) {
        Ok(instr) => instr
        Err(err) => return Err(err)
      }
      if !compiler_fact_is_numeric_opcode(instr) {
        return Err(
          "compiler facts numeric operation fact is attached to an incompatible opcode",
        )
      }
    }
  }
  for hint in facts.hints {
    match hint {
      HotnessHint(SiteHintTarget(site), _)
      | InlineHint(SiteHintTarget(site), _)
      | GoalHint(SiteHintTarget(site), _)
      | BranchProbabilityHint(site, _)
      | EstimatedLoopTripsHint(site, _)
      | LikelyCallTargetHint(site, _, _) =>
        if compiler_fact_instruction_at(index, site, "hint") is Err(err) {
          return Err(err)
        }
      LikelyHeapTypeHint(site, _, _) =>
        if validate_compiler_fact_value_site(
            index,
            site,
            env,
            "heap-type-hint",
            None,
          )
          is Err(err) {
          return Err(err)
        }
      _ => ()
    }
  }
  Ok(())
}

///|
fn validate_compiler_fact_module_section(
  module_ : Module,
  env : Env,
  imported_functions : Int,
) -> Result[Unit, String] {
  for custom in module_.custom_secs {
    let CustomSec(name, _) = custom
    if name == Name::new("compiler.facts") {
      return Err(
        "reserved compiler.facts custom section must use Module.compiler_fact_custom_section",
      )
    }
  }
  match module_.compiler_fact_custom_section {
    Some(section) => {
      if Validate::validate(section, env) is Err(err) {
        return Err(err)
      }
      let index = match
        compiler_fact_opcode_index(module_, imported_functions) {
        Ok(index) => index
        Err(err) => return Err(err)
      }
      validate_compiler_fact_body_sites(section.facts, index, env)
    }
    None => Ok(())
  }
}
