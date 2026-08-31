///|
test "compiler facts v1 value domains construct and normalize canonically" {
  @debug.assert_eq(IntWidth::i8(), Int8)
  @debug.assert_eq(IntWidth::i16(), Int16)
  @debug.assert_eq(IntWidth::i32(), Int32)
  @debug.assert_eq(IntWidth::i64(), Int64)
  @debug.assert_eq(FloatWidth::f32(), Float32)
  @debug.assert_eq(FloatWidth::f64(), Float64)

  let zero = FactValue::integer(IntConstant::new(IntWidth::i32(), 0UL))
  let one = FactValue::integer(IntConstant::new(IntWidth::i32(), 1UL))
  let function = FactValue::ref_func(7U)
  @debug.assert_eq(
    ClosedValueSet::new([function, one, zero, one]),
    ClosedValueSet([zero, one, function]),
  )
  @debug.assert_eq(
    ClosedHeapTypeSet::new([
      FactHeapType::func(),
      FactHeapType::type_index(2U),
      FactHeapType::func(),
    ]),
    ClosedHeapTypeSet([FactHeapType::type_index(2U), FactHeapType::func()]),
  )
  @debug.assert_eq(
    ClosedAliasSet::new([
      AliasSource::parameter(2U),
      AliasSource::parameter(1U),
      AliasSource::parameter(2U),
    ]),
    ClosedAliasSet([AliasSource::parameter(1U), AliasSource::parameter(2U)]),
  )

  let classes = FloatClassMask::positive_zero()
    .union(FloatClassMask::positive_normal())
    .union(FloatClassMask::nan())
  assert_true(classes.contains(FloatClassMask::nan()))
  let values = ValueFacts::new(
    possible_values=Some(ClosedValueSet::new([one])),
    integer=Some(
      IntegerFacts::new(
        IntWidth::i32(),
        unsigned_range=Some(UnsignedRange::new(1UL, 1UL)),
        known_bits=Some(KnownBits::new(0UL, 1UL)),
        nonzero=true,
      ),
    ),
    float_=Some(FloatFacts::new(FloatWidth::f32(), classes)),
    vector=Some(
      VectorFacts::new(
        known_bits=Some(
          KnownV128Bits::new(V128Bits::new(0UL, 0UL), V128Bits::new(1UL, 0UL)),
        ),
        splat=Some(one),
        lane_shape=Some(VectorLaneShape::i32x4()),
      ),
    ),
    reference=Some(
      ReferenceFacts::new(
        nullability=Some(NullabilityFacts::non_null()),
        heap=Some(HeapDomain::exact_runtime_type(FactHeapType::func())),
        function_targets=Some(ClosedFunctionSet::new([7U])),
      ),
    ),
  )
  @debug.assert_eq(
    ValueFacts::impossible().possible_values,
    Some(ClosedValueSet::new([])),
  )
  @debug.assert_eq(
    ValueFacts::exact_value(one).possible_values,
    Some(ClosedValueSet::new([one])),
  )
  @debug.assert_eq(
    ValueFacts::nonnull().reference.unwrap().nullability,
    Some(NonNull),
  )
  @debug.assert_eq(
    ValueFacts::exact_ref_func(7U).reference.unwrap().function_targets,
    Some(ClosedFunctionSet::new([7U])),
  )
  assert_true(values.integer.unwrap().nonzero)
}

///|
test "compiler facts v1 sites references aliases and provenance are result-aware" {
  let code = CodeSite::new(3U, 11U)
  let value = ValueSite::new(code, result=2U)
  @debug.assert_eq(value.site, code)
  @debug.assert_eq(value.result, 2U)
  @debug.assert_eq(ParameterRef::new(3U, 1U).parameter, 1U)
  @debug.assert_eq(FunctionResultRef::new(3U, 4U).result, 4U)
  @debug.assert_eq(ValueRef::site(value), SiteValue(value))
  @debug.assert_eq(
    ValueRef::parameter(ParameterRef::new(3U, 1U)),
    ParameterValue(ParameterRef::new(3U, 1U)),
  )
  @debug.assert_eq(
    ValueRef::function_result(FunctionResultRef::new(3U, 0U)),
    FunctionResultValue(FunctionResultRef::new(3U, 0U)),
  )
  @debug.assert_eq(ValueRef::global(9U), GlobalValue(9U))

  let provenance = SourceProvenance::new(
    module_id=Some(1UL),
    declaration_id=Some(2UL),
    body_id=Some(3UL),
    expression_id=Some(4UL),
    source_offset=Some(5UL),
    specialization_id=Some(6UL),
  )
  let expression = ExpressionFact::new(
    value,
    ValueFacts::nonnull(),
    provenance=Some(provenance),
  )
  @debug.assert_eq(expression.value, value)
  @debug.assert_eq(expression.provenance, Some(provenance))
  @debug.assert_eq(
    ResultIdentityFacts::closed_aliases(
      ClosedAliasSet::new([AliasSource::site(value), AliasSource::global(1U)]),
    ),
    ClosedAliases(
      ClosedAliasSet::new([AliasSource::global(1U), AliasSource::site(value)]),
    ),
  )
}

///|
test "compiler facts v1 top-level builder covers every collection" {
  let producer = ProducerInfo::new("dewdrop", "test", build_id=Some("build"))
  let world = WorldFacts::closed_program(
    host_can_call_exports=true,
    host_can_mutate_exported_state=false,
  )
  let function = FunctionFacts::new(0U)
  let signature = SignatureFacts::new(0U, call_sites_complete=true)
  let type_ = TypeFacts::new(1U)
  let global = GlobalFacts::new(0U)
  let table = TableFacts::new(0U)
  let body = FunctionBodyFacts::new(0U)
  let hint = OptimizationHint::goal(
    HintTarget::function(0U),
    OptimizationGoal::balanced(),
  )
  let builder = OptimizationFactsBuilder::new()
  builder.set_producer(producer)
  builder.set_world(world)
  builder.add_function(function)
  builder.add_signature(signature)
  builder.add_type(type_)
  builder.add_global(global)
  builder.add_table(table)
  builder.add_body(body)
  builder.add_hint(hint)
  @debug.assert_eq(
    builder.finish(),
    OptimizationFactsSec::new(
      producer=Some(producer),
      world=Some(world),
      functions=[function],
      signatures=[signature],
      types=[type_],
      globals=[global],
      tables=[table],
      bodies=[body],
      hints=[hint],
    ),
  )
}

///|
test "compiler facts v1 masks use distinct frozen bits" {
  let effects = [
    EffectMask::may_trap(),
    EffectMask::may_throw(),
    EffectMask::may_diverge(),
    EffectMask::may_call_unknown_code(),
    EffectMask::may_call_host_code(),
    EffectMask::may_reenter(),
    EffectMask::may_suspend(),
    EffectMask::may_allocate_gc(),
    EffectMask::may_observe_reference_identity(),
    EffectMask::may_produce_nondeterministic_results(),
    EffectMask::may_read_global(),
    EffectMask::may_write_global(),
    EffectMask::may_read_memory(),
    EffectMask::may_write_memory(),
    EffectMask::may_grow_memory(),
    EffectMask::may_read_table(),
    EffectMask::may_write_table(),
    EffectMask::may_grow_table(),
    EffectMask::may_read_gc_heap(),
    EffectMask::may_write_gc_heap(),
    EffectMask::may_synchronize(),
    EffectMask::may_wait_or_notify(),
    EffectMask::local_state(),
  ]
  let mut union = EffectMask::empty()
  for effect in effects {
    assert_false(union.contains(effect))
    union = union.union(effect)
  }
  @debug.assert_eq(union.bits(), 0x7F_FFFFUL)
  @debug.assert_eq(ParameterUseMask::all_known().bits(), 0x7FUL)
  @debug.assert_eq(EscapeSinkMask::all_known().bits(), 0xFFUL)
  @debug.assert_eq(FloatClassMask::all().bits(), 0x1FFU)
}
