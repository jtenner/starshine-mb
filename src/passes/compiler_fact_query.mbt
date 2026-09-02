///|
priv enum CompilerFactTruth {
  FactProvenTrue
  FactProvenFalse
  FactUnknown
} derive(Eq)

///|
priv struct CompilerFactIntegerDomain {
  width : @representation.IntWidth
  exact_bits : UInt64?
  unsigned_min : UInt64?
  unsigned_max : UInt64?
  signed_min : Int64?
  signed_max : Int64?
  nonzero : Bool
}

///|
fn compiler_fact_query_expected_integer_width(
  expected : @lib.ValType,
) -> @representation.IntWidth? {
  if expected == @lib.ValType::i32() {
    Some(@representation.IntWidth::i32())
  } else if expected == @lib.ValType::i64() {
    Some(@representation.IntWidth::i64())
  } else {
    None
  }
}

///|
fn compiler_fact_query_unsigned_width_max(
  width : @representation.IntWidth,
) -> UInt64 {
  match width {
    @representation.Int8 => 0xFFUL
    @representation.Int16 => 0xFFFFUL
    @representation.Int32 => 0xFFFF_FFFFUL
    @representation.Int64 => UInt64::lnot(0UL)
  }
}

///|
fn compiler_fact_query_signed_width_bounds(
  width : @representation.IntWidth,
) -> (Int64, Int64) {
  match width {
    @representation.Int8 => (-128L, 127L)
    @representation.Int16 => (-32768L, 32767L)
    @representation.Int32 => (-2147483648L, 2147483647L)
    @representation.Int64 => (-9223372036854775807L - 1L, 9223372036854775807L)
  }
}

///|
fn compiler_fact_query_signed_bits(
  width : @representation.IntWidth,
  bits : UInt64,
) -> Int64 {
  match width {
    @representation.Int32 => bits.to_uint().reinterpret_as_int().to_int64()
    @representation.Int64 => bits.reinterpret_as_int64()
    @representation.Int8 | @representation.Int16 => bits.to_int64()
  }
}

///|
fn compiler_fact_integer_domain_exact(
  width : @representation.IntWidth,
  bits : UInt64,
) -> CompilerFactIntegerDomain {
  let signed = compiler_fact_query_signed_bits(width, bits)
  {
    width,
    exact_bits: Some(bits),
    unsigned_min: Some(bits),
    unsigned_max: Some(bits),
    signed_min: Some(signed),
    signed_max: Some(signed),
    nonzero: bits != 0UL,
  }
}

///|
fn compiler_fact_integer_domain_from_const(
  instruction : @lib.Instruction,
) -> CompilerFactIntegerDomain? {
  match instruction {
    @lib.I32Const(@lib.I32(value)) =>
      Some(
        compiler_fact_integer_domain_exact(
          @representation.IntWidth::i32(),
          value.reinterpret_as_uint().to_uint64(),
        ),
      )
    @lib.I64Const(@lib.I64(value)) =>
      Some(
        compiler_fact_integer_domain_exact(
          @representation.IntWidth::i64(),
          value.reinterpret_as_uint64(),
        ),
      )
    _ => None
  }
}

///|
fn compiler_fact_query_fact_heap_type_indices_valid(
  heap : @representation.FactHeapType,
  env : @validate.Env,
) -> Bool {
  match heap {
    @representation.TypeIndex(index) =>
      index < env.global_types.length().reinterpret_as_uint()
    _ => true
  }
}

///|
fn compiler_fact_query_invalid_effect_indices(
  effects : @representation.EffectFacts,
  env : @validate.Env,
) -> Int {
  let mut invalid = 0
  let check_globals = fn(set : @representation.ClosedGlobalSet?) -> Unit {
    match set {
      Some(@representation.ClosedGlobalSet(values)) =>
        for value in values {
          if env.get_global_type(@lib.GlobalIdx::new(value)) is None {
            invalid += 1
          }
        }
      None => ()
    }
  }
  let check_memories = fn(set : @representation.ClosedMemorySet?) -> Unit {
    match set {
      Some(@representation.ClosedMemorySet(values)) =>
        for value in values {
          if env.get_memtype(@lib.MemIdx::new(value)) is None {
            invalid += 1
          }
        }
      None => ()
    }
  }
  let check_tables = fn(set : @representation.ClosedTableSet?) -> Unit {
    match set {
      Some(@representation.ClosedTableSet(values)) =>
        for value in values {
          if env.get_table_type(@lib.TableIdx::new(value)) is None {
            invalid += 1
          }
        }
      None => ()
    }
  }
  let check_types = fn(set : @representation.ClosedTypeViewSet?) -> Unit {
    match set {
      Some(@representation.ClosedTypeViewSet(values)) =>
        for value in values {
          if value >= env.global_types.length().reinterpret_as_uint() {
            invalid += 1
          }
        }
      None => ()
    }
  }
  let check_functions = fn(set : @representation.ClosedFunctionSet?) -> Unit {
    match set {
      Some(@representation.ClosedFunctionSet(values)) =>
        for value in values {
          if !env.has_func(@lib.FuncIdx::new(value)) {
            invalid += 1
          }
        }
      None => ()
    }
  }
  check_globals(effects.read_globals)
  check_globals(effects.written_globals)
  check_memories(effects.read_memories)
  check_memories(effects.written_memories)
  check_tables(effects.read_tables)
  check_tables(effects.written_tables)
  check_types(effects.read_heap_types)
  check_types(effects.written_heap_types)
  check_functions(effects.direct_callees)
  invalid
}

///|
fn compiler_fact_query_invalid_resource_indices(
  facts : @representation.OptimizationFactsSec,
  env : @validate.Env,
) -> Int {
  let mut invalid = 0
  for function in facts.functions {
    match function.effects {
      Some(effects) =>
        invalid += compiler_fact_query_invalid_effect_indices(effects, env)
      None => ()
    }
  }
  invalid
}

///|
fn compiler_fact_query_value_indices_valid(
  facts : @representation.ValueFacts,
  env : @validate.Env,
) -> Bool {
  match facts.possible_values {
    Some(@representation.ClosedValueSet(values)) =>
      for value in values {
        match value {
          @representation.RefFuncValue(function) =>
            if !env.has_func(@lib.FuncIdx::new(function)) {
              return false
            }
          @representation.ImmutableGlobalValue(global) =>
            if env.get_global_type(@lib.GlobalIdx::new(global)) is None {
              return false
            }
          @representation.RefNullValue(heap) =>
            if !compiler_fact_query_fact_heap_type_indices_valid(heap, env) {
              return false
            }
          _ => ()
        }
      }
    None => ()
  }
  match facts.reference {
    Some(reference) => {
      match reference.heap {
        Some(@representation.ExactRuntimeType(heap))
        | Some(@representation.SubtypesOf(heap)) =>
          if !compiler_fact_query_fact_heap_type_indices_valid(heap, env) {
            return false
          }
        Some(
          @representation.ClosedRuntimeTypes(
            @representation.ClosedHeapTypeSet(types)
          )
        ) =>
          for heap in types {
            if !compiler_fact_query_fact_heap_type_indices_valid(heap, env) {
              return false
            }
          }
        None => ()
      }
      match reference.function_targets {
        Some(@representation.ClosedFunctionSet(functions)) =>
          for function in functions {
            if !env.has_func(@lib.FuncIdx::new(function)) {
              return false
            }
          }
        None => ()
      }
    }
    None => ()
  }
  true
}

///|
fn compiler_fact_query_result_type(
  instruction : @lib.Instruction,
  result : UInt,
  env : @validate.Env,
) -> @lib.ValType? {
  let result_slot = result.reinterpret_as_int()
  match instruction {
    @lib.Call(function) =>
      match env.get_functype_by_funcidx(function) {
        Some(@lib.FuncType(_, results)) => results.get(result_slot)
        _ => None
      }
    @lib.CallIndirect(type_, _) | @lib.CallRef(type_) =>
      match env.resolve_functype(type_) {
        Some(@lib.FuncType(_, results)) => results.get(result_slot)
        _ => None
      }
    @lib.Block(type_, _)
    | @lib.Loop(type_, _)
    | @lib.If(type_, _, _)
    | @lib.Try(type_, _, _, _)
    | @lib.TryTable(type_, _, _) =>
      match env.expand_blocktype(type_) {
        Ok((_, results)) => results.get(result_slot)
        Err(_) => None
      }
    @lib.I32Const(_) if result == 0U => Some(@lib.ValType::i32())
    @lib.I64Const(_) if result == 0U => Some(@lib.ValType::i64())
    @lib.F32Const(_) if result == 0U => Some(@lib.ValType::f32())
    @lib.F64Const(_) if result == 0U => Some(@lib.ValType::f64())
    @lib.RefNull(type_) if result == 0U => Some(@lib.ValType::ref_type(type_))
    @lib.RefFunc(_) if result == 0U => Some(@lib.ValType::funcref())
    _ => None
  }
}

///|
fn compiler_fact_query_single_result_type(
  instruction : @lib.Instruction,
  env : @validate.Env,
) -> @lib.ValType? {
  match compiler_fact_materializer_result_arity(instruction, env) {
    Some(1U) => compiler_fact_query_result_type(instruction, 0U, env)
    _ => None
  }
}

///|
priv struct CompilerFactQuery {
  version : UInt
  policy : CompilerFactUsePolicy
  index : CompilerFactIndex
  env : @validate.Env
  sites : Array[Array[(UInt, @lib.Instruction)]]
  imported_functions : Int
  stats : CompilerFactMaterializationStats
}

///|
fn CompilerFactQuery::new(
  module_ : @lib.Module,
  version : UInt,
  policy : CompilerFactUsePolicy,
  index : CompilerFactIndex,
  sites : Array[Array[(UInt, @lib.Instruction)]],
  stats : CompilerFactMaterializationStats,
) -> CompilerFactQuery {
  {
    version,
    policy,
    index,
    env: @validate.Env::new().with_module(module_),
    sites,
    imported_functions: directize_imported_func_count(module_),
    stats,
  }
}

///|
fn CompilerFactQuery::site_resolves(
  self : CompilerFactQuery,
  site : @representation.CodeSite,
  instruction : @lib.Instruction,
) -> Bool {
  let defined = site.function.reinterpret_as_int() - self.imported_functions
  if defined < 0 || defined >= self.sites.length() {
    self.stats.stale_or_unresolved_sites += 1
    return false
  }
  for candidate in self.sites[defined] {
    if candidate.0 == site.offset {
      if candidate.1 == instruction {
        return true
      }
      self.stats.stale_or_unresolved_sites += 1
      return false
    }
  }
  self.stats.stale_or_unresolved_sites += 1
  false
}

///|
fn CompilerFactQuery::value_facts(
  self : CompilerFactQuery,
  function : UInt,
  site : @representation.ValueSite,
  instruction : @lib.Instruction,
  expected : @lib.ValType,
) -> @representation.ValueFacts? {
  if self.version != 1U {
    self.stats.unsupported_versions += 1
    return None
  }
  if self.policy != CompilerFactUsePolicy::trust_assertions() {
    self.stats.facts_blocked_by_trust += 1
    return None
  }
  if site.site.function != function ||
    !self.site_resolves(site.site, instruction) {
    return None
  }
  match compiler_fact_query_result_type(instruction, site.result, self.env) {
    Some(actual) if actual == expected => ()
    _ => {
      self.stats.type_mismatches += 1
      return None
    }
  }
  let facts = match self.index.value_facts(site) {
    Some(facts) => facts
    None => {
      self.stats.stale_or_unresolved_sites += 1
      return None
    }
  }
  if !compiler_fact_query_value_indices_valid(facts, self.env) {
    self.stats.invalid_referenced_indices += 1
    return None
  }
  Some(facts)
}

///|
fn compiler_fact_query_integer_domain_from_facts(
  facts : @representation.ValueFacts,
  expected : @lib.ValType,
  stats : CompilerFactMaterializationStats,
) -> CompilerFactIntegerDomain? {
  let width = match compiler_fact_query_expected_integer_width(expected) {
    Some(width) => width
    None => {
      stats.type_mismatches += 1
      return None
    }
  }
  let mut exact_bits : UInt64? = None
  let mut nonzero = false
  match facts.possible_values {
    Some(
      @representation.ClosedValueSet([@representation.IntegerValue(constant)])
    ) => {
      if constant.width != width ||
        (
          constant.bits &
          UInt64::lnot(compiler_fact_query_unsigned_width_max(width))
        ) !=
        0UL {
        stats.type_mismatches += 1
        return None
      }
      exact_bits = Some(constant.bits)
      nonzero = constant.bits != 0UL
    }
    Some(@representation.ClosedValueSet([])) => {
      stats.malformed_or_impossible_facts += 1
      return None
    }
    Some(@representation.ClosedValueSet(values)) => {
      if values.any(fn(value) { value is @representation.IntegerValue(_) }) {
        stats.valid_facts_without_rewrite += 1
      } else {
        stats.type_mismatches += 1
      }
      return None
    }
    None => ()
  }
  let mut unsigned_min : UInt64? = None
  let mut unsigned_max : UInt64? = None
  let mut signed_min : Int64? = None
  let mut signed_max : Int64? = None
  match exact_bits {
    Some(bits) => {
      unsigned_min = Some(bits)
      unsigned_max = Some(bits)
      let signed = compiler_fact_query_signed_bits(width, bits)
      signed_min = Some(signed)
      signed_max = Some(signed)
    }
    None => ()
  }
  match facts.integer {
    Some(integer) => {
      if integer.width != width {
        stats.type_mismatches += 1
        return None
      }
      match integer.unsigned_range {
        Some(range) if range.min <= range.max &&
          range.max <= compiler_fact_query_unsigned_width_max(width) => {
          unsigned_min = Some(range.min)
          unsigned_max = Some(range.max)
        }
        Some(_) => {
          stats.malformed_or_impossible_facts += 1
          return None
        }
        None => ()
      }
      match integer.signed_range {
        Some(range) => {
          let (width_min, width_max) = compiler_fact_query_signed_width_bounds(
            width,
          )
          if range.min > range.max ||
            range.min < width_min ||
            range.max > width_max {
            stats.malformed_or_impossible_facts += 1
            return None
          }
          signed_min = Some(range.min)
          signed_max = Some(range.max)
        }
        None => ()
      }
      if integer.nonzero {
        nonzero = true
        match (unsigned_min, unsigned_max) {
          (Some(0UL), Some(0UL)) => {
            stats.malformed_or_impossible_facts += 1
            return None
          }
          _ => ()
        }
      }
    }
    None => ()
  }
  match (unsigned_min, unsigned_max) {
    (Some(min), Some(_)) if min > 0UL => nonzero = true
    _ => ()
  }
  match (signed_min, signed_max) {
    (Some(min), Some(max)) if min > 0L || max < 0L => nonzero = true
    _ => ()
  }
  match exact_bits {
    Some(bits) => {
      match (unsigned_min, unsigned_max) {
        (Some(min), Some(max)) if bits < min || bits > max => {
          stats.malformed_or_impossible_facts += 1
          return None
        }
        _ => ()
      }
      let signed = compiler_fact_query_signed_bits(width, bits)
      match (signed_min, signed_max) {
        (Some(min), Some(max)) if signed < min || signed > max => {
          stats.malformed_or_impossible_facts += 1
          return None
        }
        _ => ()
      }
    }
    None => ()
  }
  if exact_bits is None &&
    unsigned_min is None &&
    signed_min is None &&
    !nonzero {
    return None
  }
  {
    width,
    exact_bits,
    unsigned_min,
    unsigned_max,
    signed_min,
    signed_max,
    nonzero,
  }
  |> Some
}

///|
fn CompilerFactQuery::integer_domain(
  self : CompilerFactQuery,
  function : UInt,
  site : @representation.ValueSite,
  instruction : @lib.Instruction,
  expected : @lib.ValType,
) -> CompilerFactIntegerDomain? {
  match self.value_facts(function, site, instruction, expected) {
    Some(facts) =>
      compiler_fact_query_integer_domain_from_facts(facts, expected, self.stats)
    None => None
  }
}

///|
fn CompilerFactQuery::exact_call_target(
  self : CompilerFactQuery,
  function : UInt,
  call_site : @representation.CodeSite,
  call_instruction : @lib.Instruction,
  target? : (@representation.ValueSite, @lib.Instruction)? = None,
) -> UInt? {
  if self.version != 1U {
    self.stats.unsupported_versions += 1
    return None
  }
  if self.policy != CompilerFactUsePolicy::trust_assertions() {
    self.stats.facts_blocked_by_trust += 1
    return None
  }
  if call_site.function != function ||
    !self.site_resolves(call_site, call_instruction) {
    return None
  }
  let call_target = match self.index.call_facts(call_site) {
    Some(facts) => facts.direct_target
    None => None
  }
  let value_target = match target {
    Some((value_site, producer)) =>
      match self.index.value_facts(value_site) {
        Some(_) =>
          match
            compiler_fact_query_result_type(
              producer,
              value_site.result,
              self.env,
            ) {
            Some(expected) =>
              match self.value_facts(function, value_site, producer, expected) {
                Some(facts) =>
                  compiler_fact_exact_target_from_value_facts(facts)
                None => None
              }
            None => {
              self.stats.type_mismatches += 1
              None
            }
          }
        None => None
      }
    None => None
  }
  let resolved = match (call_target, value_target) {
    (Some(left), Some(right)) if left == right => Some(left)
    (Some(_), Some(_)) => {
      self.stats.malformed_or_impossible_facts += 1
      None
    }
    (Some(value), None) | (None, Some(value)) => Some(value)
    _ => None
  }
  match resolved {
    Some(target) if self.env.has_func(@lib.FuncIdx::new(target)) => Some(target)
    Some(_) => {
      self.stats.invalid_referenced_indices += 1
      None
    }
    None => None
  }
}

///|
fn CompilerFactQuery::null_test(
  self : CompilerFactQuery,
  function : UInt,
  site : @representation.ValueSite,
  instruction : @lib.Instruction,
  expected : @lib.ValType,
) -> CompilerFactTruth {
  match expected {
    @lib.RefTypeValType(_) => ()
    _ => {
      self.stats.type_mismatches += 1
      return FactUnknown
    }
  }
  let facts = match self.value_facts(function, site, instruction, expected) {
    Some(facts) => facts
    None => return FactUnknown
  }
  let from_values = match facts.possible_values {
    Some(@representation.ClosedValueSet([@representation.RefNullValue(_)])) =>
      FactProvenTrue
    Some(@representation.ClosedValueSet([@representation.RefFuncValue(_)])) =>
      FactProvenFalse
    _ => FactUnknown
  }
  let from_reference = match facts.reference {
    Some(reference) =>
      match reference.nullability {
        Some(@representation.NullOnly) => FactProvenTrue
        Some(@representation.NonNull) => FactProvenFalse
        None => FactUnknown
      }
    None => FactUnknown
  }
  match (from_values, from_reference) {
    (FactProvenTrue, FactProvenFalse) | (FactProvenFalse, FactProvenTrue) => {
      self.stats.malformed_or_impossible_facts += 1
      FactUnknown
    }
    (FactProvenTrue, _) | (_, FactProvenTrue) => FactProvenTrue
    (FactProvenFalse, _) | (_, FactProvenFalse) => FactProvenFalse
    _ => FactUnknown
  }
}

///|
fn compiler_fact_relation_equal(
  left : CompilerFactIntegerDomain,
  right : CompilerFactIntegerDomain,
) -> CompilerFactTruth {
  match (left.exact_bits, right.exact_bits) {
    (Some(lhs), Some(rhs)) =>
      if lhs == rhs {
        FactProvenTrue
      } else {
        FactProvenFalse
      }
    (Some(0UL), None) if right.nonzero => FactProvenFalse
    (None, Some(0UL)) if left.nonzero => FactProvenFalse
    _ =>
      match
        (
          left.unsigned_min,
          left.unsigned_max,
          right.unsigned_min,
          right.unsigned_max,
        ) {
        (Some(lmin), Some(lmax), Some(rmin), Some(rmax)) if lmin == lmax &&
          rmin == rmax &&
          lmin == rmin => FactProvenTrue
        (Some(lmin), Some(lmax), Some(rmin), Some(rmax)) if lmax < rmin ||
          rmax < lmin => FactProvenFalse
        _ =>
          match
            (
              left.signed_min,
              left.signed_max,
              right.signed_min,
              right.signed_max,
            ) {
            (Some(lmin), Some(lmax), Some(rmin), Some(rmax)) if lmin == lmax &&
              rmin == rmax &&
              lmin == rmin => FactProvenTrue
            (Some(lmin), Some(lmax), Some(rmin), Some(rmax)) if lmax < rmin ||
              rmax < lmin => FactProvenFalse
            _ => FactUnknown
          }
      }
  }
}

///|
fn compiler_fact_relation_signed_less_than(
  left : CompilerFactIntegerDomain,
  right : CompilerFactIntegerDomain,
) -> CompilerFactTruth {
  match (left.signed_min, left.signed_max, right.signed_min, right.signed_max) {
    (Some(lmin), Some(lmax), Some(rmin), Some(rmax)) =>
      if lmax < rmin {
        FactProvenTrue
      } else if lmin >= rmax {
        FactProvenFalse
      } else {
        FactUnknown
      }
    _ => FactUnknown
  }
}

///|
fn compiler_fact_relation_unsigned_less_than(
  left : CompilerFactIntegerDomain,
  right : CompilerFactIntegerDomain,
) -> CompilerFactTruth {
  match
    (
      left.unsigned_min,
      left.unsigned_max,
      right.unsigned_min,
      right.unsigned_max,
    ) {
    (Some(lmin), Some(lmax), Some(rmin), Some(rmax)) =>
      if lmax < rmin {
        FactProvenTrue
      } else if lmin >= rmax {
        FactProvenFalse
      } else {
        FactUnknown
      }
    _ => FactUnknown
  }
}

///|
fn compiler_fact_truth_not(value : CompilerFactTruth) -> CompilerFactTruth {
  match value {
    FactProvenTrue => FactProvenFalse
    FactProvenFalse => FactProvenTrue
    FactUnknown => FactUnknown
  }
}

///|
fn compiler_fact_relation_signed_less_or_equal(
  left : CompilerFactIntegerDomain,
  right : CompilerFactIntegerDomain,
) -> CompilerFactTruth {
  compiler_fact_truth_not(compiler_fact_relation_signed_less_than(right, left))
}

///|
fn compiler_fact_relation_unsigned_less_or_equal(
  left : CompilerFactIntegerDomain,
  right : CompilerFactIntegerDomain,
) -> CompilerFactTruth {
  compiler_fact_truth_not(
    compiler_fact_relation_unsigned_less_than(right, left),
  )
}

///|
fn compiler_fact_relation_for_instruction(
  instruction : @lib.Instruction,
  left : CompilerFactIntegerDomain,
  right : CompilerFactIntegerDomain,
) -> CompilerFactTruth {
  match instruction {
    @lib.I32Eq | @lib.I64Eq => compiler_fact_relation_equal(left, right)
    @lib.I32Ne | @lib.I64Ne =>
      compiler_fact_truth_not(compiler_fact_relation_equal(left, right))
    @lib.I32LtS | @lib.I64LtS =>
      compiler_fact_relation_signed_less_than(left, right)
    @lib.I32LtU | @lib.I64LtU =>
      compiler_fact_relation_unsigned_less_than(left, right)
    @lib.I32LeS | @lib.I64LeS =>
      compiler_fact_relation_signed_less_or_equal(left, right)
    @lib.I32LeU | @lib.I64LeU =>
      compiler_fact_relation_unsigned_less_or_equal(left, right)
    @lib.I32GtS | @lib.I64GtS =>
      compiler_fact_relation_signed_less_than(right, left)
    @lib.I32GtU | @lib.I64GtU =>
      compiler_fact_relation_unsigned_less_than(right, left)
    @lib.I32GeS | @lib.I64GeS =>
      compiler_fact_relation_signed_less_or_equal(right, left)
    @lib.I32GeU | @lib.I64GeU =>
      compiler_fact_relation_unsigned_less_or_equal(right, left)
    _ => FactUnknown
  }
}
