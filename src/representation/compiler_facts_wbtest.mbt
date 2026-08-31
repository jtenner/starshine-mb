///|
test "compiler fact constructors cover defaults and populated values" {
  let empty = OptimizationFactsSec::new()
  @debug.assert_eq(empty.functions, [])
  @debug.assert_eq(empty.bodies, [])
  let section = CompilerFactCustomSection::new(empty)
  @debug.assert_eq(section.version, 1U)
  @debug.assert_eq(section.module_fingerprint, None)
  @debug.assert_eq(section.facts, empty)

  let value = ValueFacts::new(
    non_null=true,
    exact_heap_type=Some(2U),
    exact_call_target=Some(3U),
    signed_range=Some(SignedRange::new(-4L, 5L)),
    unsigned_range=Some(UnsignedRange::new(6UL, 7UL)),
    does_not_escape=true,
    identity_not_observed=true,
  )
  let parameter = ParameterFacts::new(
    0U,
    value=Some(value),
    uses=Some(
      ParameterUseMask::direct_computation().union(ParameterUseMask::return_()),
    ),
    escape_sinks=Some(
      EscapeSinkMask::call().union(EscapeSinkMask::host_unknown()),
    ),
  )
  let result = ResultFacts::new(
    0U,
    value=Some(value),
    identity=Some(ResultIdentityFacts::same_as_parameter(0U)),
  )
  let effects = EffectFacts::new(
    EffectMask::control().union(EffectMask::allocation()),
    read_globals=Some(ClosedGlobalSet::new([2U, 1U, 2U])),
    written_globals=Some(ClosedGlobalSet::new([])),
    read_memories=Some(ClosedMemorySet::new([0U])),
    written_memories=Some(ClosedMemorySet::new([1U])),
    read_tables=Some(ClosedTableSet::new([0U])),
    written_tables=Some(ClosedTableSet::new([1U])),
    read_heap_types=Some(ClosedTypeViewSet::new([3U, 2U])),
    written_heap_types=Some(ClosedTypeViewSet::new([4U])),
    direct_callees=Some(ClosedFunctionSet::new([1U, 0U, 1U])),
  )
  @debug.assert_eq(effects.read_globals, Some(ClosedGlobalSet::new([1U, 2U])))
  @debug.assert_eq(
    effects.direct_callees,
    Some(ClosedFunctionSet::new([0U, 1U])),
  )

  let function = FunctionFacts::new(
    0U,
    effects=Some(effects),
    parameters=[parameter],
    results=[result],
    boundary=Some(FunctionBoundaryFacts::new(true, false, true)),
    profile=Some(
      FunctionProfile::new(
        entry_count=Some(9UL),
        temperature=Some(TemperatureHint::hot()),
      ),
    ),
    inline_policy=Some(InlinePolicy::prefer()),
  )
  @debug.assert_eq(function.function, 0U)
  @debug.assert_eq(function.parameters, [parameter])
  @debug.assert_eq(function.results, [result])

  let site0 = FactSiteRef::new(0U, 10U)
  let site1 = FactSiteRef::new(0U, 11U)
  let expression = ExpressionFact::new(0U, 10U, [
    Fact::non_null(),
    Fact::exact_heap_type(2U),
    Fact::exact_call_target(1U),
    Fact::signed_range(-2L, 3L),
    Fact::unsigned_range(4UL, 5UL),
    Fact::does_not_escape(),
    Fact::identity_not_observed(),
  ])
  let body = FunctionBodyFacts::new(
    0U,
    sites=[expression],
    relations=[
      FactRelation::same_value(site0, site1),
      FactRelation::same_identity(site0, site1),
      FactRelation::derived_from(site1, site0),
    ],
    calls=[
      CallSiteFacts::new(
        0U,
        12U,
        direct_target=Some(1U),
        profile=Some(
          CallProfile::new(
            count=Some(7UL),
            temperature=Some(TemperatureHint::normal()),
          ),
        ),
        inline_policy=Some(InlinePolicy::always()),
      ),
    ],
    branches=[
      BranchFacts::new(
        0U,
        13U,
        profile=Some(BranchProfile::new(8UL, 2UL)),
        temperature=Some(TemperatureHint::hot()),
      ),
    ],
    loops=[
      LoopFacts::new(
        0U,
        14U,
        profile=Some(
          LoopProfile::new(
            backedge_count=Some(6UL),
            estimated_trip_count=Some(3UL),
          ),
        ),
        temperature=Some(TemperatureHint::cold()),
      ),
    ],
    allocations=[
      AllocationSiteFacts::new(
        0U,
        15U,
        heap_type=Some(2U),
        does_not_escape=true,
        identity_not_observed=true,
      ),
    ],
  )
  let facts = OptimizationFactsSec::new(functions=[function], bodies=[body])
  let populated = CompilerFactCustomSection::new(
    facts,
    version=1U,
    module_fingerprint=Some(b"opaque"),
  )
  @debug.assert_eq(populated.facts, facts)
  @debug.assert_eq(populated.module_fingerprint, Some(b"opaque"))
}

///|
test "compiler fact enum constructors cover every variant" {
  @debug.assert_eq(ResultIdentityFacts::fresh(), FreshIdentity)
  @debug.assert_eq(
    ResultIdentityFacts::same_as_parameter(4U),
    SameAsParameter(4U),
  )
  @debug.assert_eq(TemperatureHint::cold(), Cold)
  @debug.assert_eq(TemperatureHint::normal(), Normal)
  @debug.assert_eq(TemperatureHint::hot(), Hot)
  @debug.assert_eq(InlinePolicy::default_(), DefaultInlinePolicy)
  @debug.assert_eq(InlinePolicy::never(), NeverInline)
  @debug.assert_eq(InlinePolicy::prefer(), PreferInline)
  @debug.assert_eq(InlinePolicy::always(), AlwaysInline)
}

///|
test "compiler fact masks assign distinct stable bits and compose" {
  let effects = [
    EffectMask::control(),
    EffectMask::call(),
    EffectMask::throw_(),
    EffectMask::trap(),
    EffectMask::local_state(),
    EffectMask::global_state(),
    EffectMask::memory_read(),
    EffectMask::memory_write(),
    EffectMask::table_read(),
    EffectMask::table_write(),
    EffectMask::heap_read(),
    EffectMask::heap_write(),
    EffectMask::allocation(),
  ]
  let mut effect_union = EffectMask::empty()
  for mask in effects {
    assert_false(effect_union.contains(mask))
    effect_union = effect_union.union(mask)
    assert_true(effect_union.contains(mask))
  }
  @debug.assert_eq(effect_union.bits(), 0x1FFFUL)

  let uses = [
    ParameterUseMask::direct_computation(),
    ParameterUseMask::control(),
    ParameterUseMask::address_index(),
    ParameterUseMask::call_argument(),
    ParameterUseMask::stored_value(),
    ParameterUseMask::return_(),
    ParameterUseMask::identity_observing(),
  ]
  let mut use_union = ParameterUseMask::empty()
  for mask in uses {
    assert_false(use_union.contains(mask))
    use_union = use_union.union(mask)
  }
  @debug.assert_eq(use_union.bits(), 0x7FUL)

  let sinks = [
    EscapeSinkMask::return_(),
    EscapeSinkMask::call(),
    EscapeSinkMask::global(),
    EscapeSinkMask::memory(),
    EscapeSinkMask::table(),
    EscapeSinkMask::heap(),
    EscapeSinkMask::throw_(),
    EscapeSinkMask::host_unknown(),
  ]
  let mut sink_union = EscapeSinkMask::empty()
  for mask in sinks {
    assert_false(sink_union.contains(mask))
    sink_union = sink_union.union(mask)
  }
  @debug.assert_eq(sink_union.bits(), 0xFFUL)
}

///|
test "closed set constructors sort and remove duplicates" {
  @debug.assert_eq(
    ClosedGlobalSet::new([3U, 1U, 3U, 2U]),
    ClosedGlobalSet([1U, 2U, 3U]),
  )
  @debug.assert_eq(
    ClosedMemorySet::new([2U, 2U, 0U]),
    ClosedMemorySet([0U, 2U]),
  )
  @debug.assert_eq(ClosedTableSet::new([]), ClosedTableSet([]))
  @debug.assert_eq(
    ClosedTypeViewSet::new([9U, 4U, 4U]),
    ClosedTypeViewSet([4U, 9U]),
  )
  @debug.assert_eq(
    ClosedFunctionSet::new([1U, 0U, 1U]),
    ClosedFunctionSet([0U, 1U]),
  )
}

///|
test "optimization facts builder accumulates immutable output" {
  let builder = OptimizationFactsBuilder::new()
  let function = FunctionFacts::new(0U)
  let body = FunctionBodyFacts::new(0U)
  builder.add_function(function)
  builder.add_body(body)
  @debug.assert_eq(
    builder.finish(),
    OptimizationFactsSec::new(functions=[function], bodies=[body]),
  )
}
