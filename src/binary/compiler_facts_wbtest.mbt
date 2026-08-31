///|
fn[T : Encode] compiler_facts_test_encode(value : T) -> Bytes raise {
  let buf = @buffer.new()
  match Encode::encode(value, buf) {
    Ok(_) => buf.to_bytes()
    Err(err) => fail("compiler facts encode failed: \{err}")
  }
}

///|
fn[T : Encode + Decode + Eq + @debug.Debug] compiler_facts_test_roundtrip(
  value : T,
) -> Unit raise {
  let bytes = compiler_facts_test_encode(value)
  let (decoded, next) = match
    (Decode::decode(bytes, 0) : Result[(T, Int), BinaryDecodeError]) {
    Ok(result) => result
    Err(err) => fail("compiler facts decode failed: \{err}")
  }
  @debug.assert_eq(next, bytes.length())
  @debug.assert_eq(decoded, value)
  @debug.assert_eq(compiler_facts_test_encode(decoded), bytes)
}

///|
fn compiler_facts_test_everything_section() -> @representation.CompilerFactCustomSection {
  let code = @representation.CodeSite::new(0U, 0U)
  let value_site = @representation.ValueSite::new(code)
  let provenance = @representation.SourceProvenance::new(
    module_id=Some(1UL),
    body_id=Some(2UL),
    expression_id=Some(3UL),
  )
  let exact = @representation.ValueFacts::exact_ref_func(0U)
  let integer = @representation.ValueFacts::new(
    possible_values=Some(
      @representation.ClosedValueSet::new([
        @representation.FactValue::integer(
          @representation.IntConstant::new(@representation.IntWidth::i32(), 7UL),
        ),
      ]),
    ),
    integer=Some(
      @representation.IntegerFacts::new(
        @representation.IntWidth::i32(),
        unsigned_range=Some(@representation.UnsignedRange::new(7UL, 7UL)),
        signed_range=Some(@representation.SignedRange::new(7L, 7L)),
        known_bits=Some(@representation.KnownBits::new(0UL, 7UL)),
        nonzero=true,
      ),
    ),
  )
  let effects = @representation.EffectFacts::new(
    @representation.EffectMask::may_trap()
    .union(@representation.EffectMask::may_call_host_code())
    .union(@representation.EffectMask::may_read_memory()),
    read_globals=Some(@representation.ClosedGlobalSet::new([0U])),
    written_globals=Some(@representation.ClosedGlobalSet::new([])),
    read_memories=Some(@representation.ClosedMemorySet::new([0U])),
    written_memories=Some(@representation.ClosedMemorySet::new([])),
    read_tables=Some(@representation.ClosedTableSet::new([0U])),
    written_tables=Some(@representation.ClosedTableSet::new([])),
    read_heap_types=Some(@representation.ClosedTypeViewSet::new([1U])),
    written_heap_types=Some(@representation.ClosedTypeViewSet::new([])),
    direct_callees=Some(@representation.ClosedFunctionSet::new([0U])),
  )
  let function = @representation.FunctionFacts::new(
    0U,
    effects=Some(effects),
    parameters=[
      @representation.ParameterFacts::new(
        0U,
        value=Some(integer),
        uses=Some(@representation.ParameterUseMask::call_argument()),
        escape_sinks=Some(@representation.EscapeSinkMask::call()),
      ),
    ],
    results=[
      @representation.ResultFacts::new(
        0U,
        value=Some(integer),
        identity=Some(
          @representation.ResultIdentityFacts::closed_aliases(
            @representation.ClosedAliasSet::new([
              @representation.AliasSource::parameter(0U),
              @representation.AliasSource::global(0U),
              @representation.AliasSource::site(value_site),
            ]),
          ),
        ),
      ),
    ],
    boundary=Some(@representation.FunctionBoundaryFacts::new(true, false, true)),
    profile=Some(
      @representation.FunctionProfile::new(
        entry_count=Some(10UL),
        temperature=Some(@representation.TemperatureHint::hot()),
      ),
    ),
    inline_policy=Some(@representation.InlinePolicy::prefer()),
  )
  let signature = @representation.SignatureFacts::new(
    0U,
    parameters=[@representation.IndexedValueFacts::new(0U, integer)],
    results=[@representation.IndexedValueFacts::new(0U, integer)],
    call_sites_complete=true,
  )
  let field = @representation.FieldFacts::new(
    @representation.TypeView::exact(1U),
    0U,
    stored_contents=Some(integer),
    writes=Some(@representation.WriteFacts::closed([code])),
    usage=Some(@representation.FieldUsageFacts::new(never_read=true)),
  )
  let type_facts = @representation.TypeFacts::new(
    1U,
    population=Some(
      @representation.TypePopulation::closed(
        @representation.ClosedHeapTypeSet::new([
          @representation.FactHeapType::type_index(1U),
        ]),
      ),
    ),
    fields=[field],
  )
  let mutation = @representation.MutationFacts::new(
    @representation.MutationPhase::initialization_only(),
    sites=Some([code]),
  )
  let global = @representation.GlobalFacts::new(
    0U,
    initial_value=Some(integer),
    steady_state_value=Some(integer),
    mutation=Some(mutation),
  )
  let reference = @representation.ReferenceFacts::new(
    nullability=Some(@representation.NullabilityFacts::non_null()),
    heap=Some(
      @representation.HeapDomain::closed_runtime_types(
        @representation.ClosedHeapTypeSet::new([
          @representation.FactHeapType::func(),
        ]),
      ),
    ),
    function_targets=Some(@representation.ClosedFunctionSet::new([0U])),
  )
  let table = @representation.TableFacts::new(
    0U,
    mutation=Some(mutation),
    may_grow=Some(false),
    default_value=Some(reference),
    entries=[@representation.TableEntryFacts::new(0UL, reference)],
    contents_complete=true,
  )
  let allocation = @representation.AllocationSiteFacts::new(
    value_site,
    @representation.AllocationFacts::new(
      @representation.AllocationKind::struct_(1U),
      escape_sinks=Some(@representation.EscapeSinkMask::empty()),
      identity_unobserved=true,
      thread_confined=true,
      fields=[
        @representation.AllocationFieldFacts::new(
          0U,
          no_post_init_writes=true,
          stored_value=Some(integer),
        ),
      ],
    ),
    provenance=Some(provenance),
  )
  let body = @representation.FunctionBodyFacts::new(
    0U,
    sites=[
      @representation.ExpressionFact::new(
        value_site,
        exact,
        provenance=Some(provenance),
      ),
    ],
    relations=[
      @representation.ScopedRelationFacts::new(
        code,
        @representation.FactOperand::value(
          @representation.ValueRef::site(value_site),
        ),
        @representation.RelationKind::equal(),
        @representation.FactOperand::constant(
          @representation.FactValue::ref_func(0U),
        ),
      ),
    ],
    calls=[
      @representation.CallSiteFacts::new(
        code,
        direct_target=Some(0U),
        profile=Some(@representation.CallProfile::new(count=Some(4UL))),
        inline_policy=Some(@representation.InlinePolicy::always()),
        provenance=Some(provenance),
      ),
    ],
    branches=[
      @representation.BranchFacts::new(
        code,
        profile=Some(@representation.BranchProfile::new(3UL, 1UL)),
      ),
    ],
    loops=[
      @representation.LoopFacts::new(
        code,
        profile=Some(
          @representation.LoopProfile::new(estimated_trip_count=Some(2UL)),
        ),
      ),
    ],
    allocations=[allocation],
    accesses=[
      @representation.AccessSiteFacts::new(
        code,
        @representation.AccessFacts::new(
          in_bounds=true,
          alignment_log2=Some(2U),
        ),
      ),
    ],
    numeric_operations=[
      @representation.NumericOperationSiteFacts::new(
        value_site,
        @representation.NumericOperationFacts::new(signed_no_wrap=true),
      ),
    ],
  )
  @representation.CompilerFactCustomSection::new(
    @representation.OptimizationFactsSec::new(
      producer=Some(
        @representation.ProducerInfo::new("dewdrop", "1", build_id=Some("test")),
      ),
      world=Some(@representation.WorldFacts::closed_program()),
      functions=[function],
      signatures=[signature],
      types=[type_facts],
      globals=[global],
      tables=[table],
      bodies=[body],
      hints=[
        @representation.OptimizationHint::hotness(
          @representation.HintTarget::function(0U),
          @representation.TemperatureHint::hot(),
        ),
        @representation.OptimizationHint::likely_call_target(code, 0U, 65535U),
        @representation.OptimizationHint::likely_heap_type(
          value_site,
          @representation.FactHeapType::func(),
          60000U,
        ),
      ],
    ),
    module_fingerprint=Some(b"opaque"),
  )
}

///|
test "compiler facts final v1 empty golden is stable" {
  let empty = @representation.CompilerFactCustomSection::new(
    @representation.OptimizationFactsSec::new(),
  )
  @debug.assert_eq(
    compiler_facts_test_encode(empty),
    b"\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
  )
  compiler_facts_test_roundtrip(empty)
  @debug.assert_eq(
    encode_module(@lib.Module::new(compiler_fact_custom_section=Some(empty))).unwrap(),
    b"\x00\x61\x73\x6d\x01\x00\x00\x00\x00\x1a\x0ecompiler.facts\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
  )
}

///|
test "compiler facts everything fixture roundtrips canonically" {
  compiler_facts_test_roundtrip(compiler_facts_test_everything_section())
}

///|
test "compiler facts final v1 discriminator table is explicit" {
  @debug.assert_eq(
    compiler_facts_test_encode(@representation.IntWidth::i8()),
    b"\x00",
  )
  @debug.assert_eq(
    compiler_facts_test_encode(@representation.IntWidth::i64()),
    b"\x03",
  )
  @debug.assert_eq(
    compiler_facts_test_encode(@representation.FactHeapType::func()),
    b"\x06",
  )
  @debug.assert_eq(
    compiler_facts_test_encode(@representation.NullabilityFacts::non_null()),
    b"\x01",
  )
  @debug.assert_eq(
    compiler_facts_test_encode(
      @representation.RelationKind::distinct_references(),
    ),
    b"\x07",
  )
  @debug.assert_eq(
    compiler_facts_test_encode(@representation.OptimizationGoal::prefer_size()),
    b"\x02",
  )
  @debug.assert_eq(
    compiler_facts_test_encode(
      @representation.OptimizationHint::likely_call_target(
        @representation.CodeSite::new(0U, 1U),
        2U,
        3U,
      ),
    )[0],
    0x05,
  )
}

///|
test "compiler facts decoders reject malformed enum and option tags" {
  let enum_result : Result[(@representation.IntWidth, Int), BinaryDecodeError] = Decode::decode(
    b"\xff", 0,
  )
  @debug.assert_eq(
    enum_result,
    Err(BinaryDecodeError::InvalidCompilerFactsEnumTag),
  )
  let option_result : Result[
    (@representation.ValueFacts, Int),
    BinaryDecodeError,
  ] = Decode::decode(b"\xff", 0)
  @debug.assert_eq(
    option_result,
    Err(BinaryDecodeError::InvalidCompilerFactsOptionTag),
  )
}

///|
test "compiler facts opcode sites pair canonical offsets with instructions" {
  let sites = compiler_fact_opcode_sites(
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(128)),
          @lib.Instruction::nop(),
        ]),
      ),
      @lib.Instruction::nop(),
    ]),
  ).unwrap()
  @debug.assert_eq(sites.map(fn(site) { site.0 }), [0U, 2U, 5U, 7U])
  assert_true(sites[0].1 is @lib.Block(_, _))
  assert_true(sites[1].1 is @lib.I32Const(_))
}

///|
test "compiler facts remains an explicit reserved custom section" {
  let section = @representation.CompilerFactCustomSection::new(
    @representation.OptimizationFactsSec::new(),
  )
  let module_ = @lib.Module::new(
    custom_secs=[@lib.CustomSec::new(@lib.Name::new("unrelated"), b"payload")],
    compiler_fact_custom_section=Some(section),
  )
  let decoded = decode_module(encode_module(module_).unwrap()).unwrap()
  @debug.assert_eq(decoded.compiler_fact_custom_section, Some(section))
  @debug.assert_eq(decoded.custom_secs, module_.custom_secs)
  match
    encode_module(
      @lib.Module::new(custom_secs=[
        @lib.CustomSec::new(@lib.Name::new("compiler.facts"), b"bad"),
      ]),
    ) {
    Err(
      EncodeError::Encode(BinaryEncodeError::ReservedCompilerFactsCustomSection)
    ) => ()
    other =>
      fail("expected reserved compiler facts name rejection, got \{other}")
  }
}
