///|
fn[T : Validate] compiler_facts_assert_valid(
  value : T,
  env : Env,
) -> Unit raise {
  match Validate::validate(value, env) {
    Ok(_) => ()
    Err(err) => fail("expected compiler facts validation success: \{err}")
  }
}

///|
fn[T : Validate] compiler_facts_assert_invalid(
  value : T,
  env : Env,
  expected : String,
) -> Unit raise {
  match Validate::validate(value, env) {
    Ok(_) =>
      fail("expected compiler facts validation failure containing \{expected}")
    Err(err) => assert_true(err.contains(expected), msg=err)
  }
}

///|
fn compiler_facts_test_env() -> Env {
  empty_env()
  .with_types([
    SubType::comp_type(
      CompType::func([ValType::i32()], [ValType::i32(), ValType::i64()]),
    ),
    SubType::comp_type(
      CompType::struct_([
        FieldType::new(StorageType::val_type(ValType::i32()), Mut::var_()),
      ]),
    ),
    SubType::comp_type(
      CompType::array(
        FieldType::new(StorageType::val_type(ValType::i32()), Mut::var_()),
      ),
    ),
  ])
  .with_funcs([
    FuncType::new([ValType::i32()], [ValType::i32(), ValType::i64()]),
  ])
  .with_globals([GlobalType::new(ValType::i32(), false)])
  .with_mems([MemType::new(Limits::i32(1U, None))])
  .with_tables([
    TableType::new(
      RefType::new(true, HeapType::abs(AbsHeapType::func())),
      Limits::i32(1U, None),
    ),
  ])
}

///|
test "Validate covers final compiler facts scalar domains directly" {
  let env = compiler_facts_test_env()
  compiler_facts_assert_valid(
    @representation.IntConstant::new(@representation.IntWidth::i8(), 255UL),
    env,
  )
  compiler_facts_assert_invalid(
    @representation.IntConstant::new(@representation.IntWidth::i8(), 256UL),
    env,
    "outside width",
  )
  compiler_facts_assert_invalid(
    @representation.KnownBits::new(1UL, 1UL),
    env,
    "same bit",
  )
  compiler_facts_assert_invalid(
    @representation.IntegerFacts::new(
      @representation.IntWidth::i8(),
      unsigned_range=Some(@representation.UnsignedRange::new(0UL, 256UL)),
    ),
    env,
    "exceeds integer width",
  )
  compiler_facts_assert_invalid(
    @representation.FloatClassMask::from_bits(1U << 20),
    env,
    "float class mask",
  )
  compiler_facts_assert_invalid(
    @representation.EffectMask::from_bits(1UL << 30),
    env,
    "effect mask",
  )
  compiler_facts_assert_invalid(
    @representation.ValueFacts::new(
      possible_values=Some(
        @representation.ClosedValueSet::new([
          @representation.FactValue::integer(
            @representation.IntConstant::new(
              @representation.IntWidth::i32(),
              0UL,
            ),
          ),
        ]),
      ),
      integer=Some(
        @representation.IntegerFacts::new(
          @representation.IntWidth::i32(),
          nonzero=true,
        ),
      ),
    ),
    env,
    "contradicts nonzero",
  )
}

///|
test "Validate covers final compiler facts references aliases and top-level duplicates" {
  let env = compiler_facts_test_env()
  compiler_facts_assert_invalid(
    @representation.FactValue::ref_func(1U),
    env,
    "function index",
  )
  compiler_facts_assert_invalid(
    @representation.FactHeapType::type_index(3U),
    env,
    "type index",
  )
  compiler_facts_assert_invalid(
    @representation.ParameterRef::new(0U, 1U),
    env,
    "parameter reference",
  )
  compiler_facts_assert_invalid(
    @representation.FunctionResultRef::new(0U, 2U),
    env,
    "result reference",
  )
  compiler_facts_assert_invalid(
    @representation.OptimizationFactsSec::new(functions=[
      @representation.FunctionFacts::new(0U),
      @representation.FunctionFacts::new(0U),
    ]),
    env,
    "duplicate function facts",
  )
  compiler_facts_assert_invalid(
    @representation.OptimizationFactsSec::new(signatures=[
      @representation.SignatureFacts::new(0U),
      @representation.SignatureFacts::new(0U),
    ]),
    env,
    "duplicate signature facts",
  )
  compiler_facts_assert_invalid(
    @representation.OptimizationHint::likely_call_target(
      @representation.CodeSite::new(0U, 0U),
      0U,
      65536U,
    ),
    env,
    "confidence",
  )
}

///|
test "Validate checks type field array and allocation shapes" {
  let env = compiler_facts_test_env()
  compiler_facts_assert_valid(
    @representation.FieldFacts::new(
      @representation.TypeView::exact(1U),
      0U,
      stored_contents=Some(
        @representation.ValueFacts::exact_value(
          @representation.FactValue::integer(
            @representation.IntConstant::new(
              @representation.IntWidth::i32(),
              1UL,
            ),
          ),
        ),
      ),
    ),
    env,
  )
  compiler_facts_assert_invalid(
    @representation.FieldFacts::new(@representation.TypeView::exact(2U), 0U),
    env,
    "struct type",
  )
  compiler_facts_assert_valid(
    @representation.ArrayElementFacts::new(@representation.TypeView::exact(2U)),
    env,
  )
  compiler_facts_assert_invalid(
    @representation.AllocationFacts::new(
      @representation.AllocationKind::struct_(1U),
      length=Some(
        @representation.IntegerFacts::new(@representation.IntWidth::i32()),
      ),
    ),
    env,
    "only valid for array",
  )
}

///|
fn compiler_facts_multivalue_module(
  site_result : UInt,
  site_offset? : UInt? = None,
) -> Module {
  let type_ = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32(), ValType::i64()])),
  )
  let base = Module::new()
    .with_type_sec(TypeSec::new([type_]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::empty(),
          Expr::new([
            Instruction::block(
              BlockType::type_idx(TypeIdx::new(0U)),
              Expr::new([
                Instruction::i32_const(I32(1)),
                Instruction::i64_const(I64(2L)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let offset = match site_offset {
    Some(value) => value
    None => @binary.compiler_fact_module_opcode_sites(base).unwrap()[0][0].0
  }
  base.with_compiler_fact_custom_section(
    @representation.CompilerFactCustomSection::new(
      @representation.OptimizationFactsSec::new(bodies=[
        @representation.FunctionBodyFacts::new(0U, sites=[
          @representation.ExpressionFact::new(
            @representation.ValueSite::new(
              @representation.CodeSite::new(0U, offset),
              result=site_result,
            ),
            @representation.ValueFacts::unknown(),
          ),
        ]),
      ]),
    ),
  )
}

///|
test "module compiler facts validation uses instruction result arity" {
  match validate_module(compiler_facts_multivalue_module(1U)) {
    Ok(_) => ()
    Err(err) => fail("expected second block result site to validate: \{err}")
  }
  match validate_module(compiler_facts_multivalue_module(2U)) {
    Ok(_) => fail("expected out-of-range instruction result index")
    Err(err) =>
      assert_true(
        validation_error_message(err).contains("result index out of range"),
        msg=validation_error_message(err),
      )
  }
}

///|
test "module compiler facts validation rejects wrong opcode families and delimiters" {
  let base = compiler_facts_multivalue_module(0U)
  let bad_call = base.with_compiler_fact_custom_section(
    @representation.CompilerFactCustomSection::new(
      @representation.OptimizationFactsSec::new(bodies=[
        @representation.FunctionBodyFacts::new(0U, calls=[
          @representation.CallSiteFacts::new(
            @representation.CodeSite::new(0U, 0U),
            direct_target=Some(0U),
          ),
        ]),
      ]),
    ),
  )
  match validate_module(bad_call) {
    Ok(_) => fail("expected non-call attachment rejection")
    Err(err) =>
      assert_true(
        validation_error_message(err).contains("non-call opcode"),
        msg=validation_error_message(err),
      )
  }
  let delimiter = compiler_facts_multivalue_module(0U, site_offset=Some(5U))
  match validate_module(delimiter) {
    Ok(_) => fail("expected delimiter offset rejection")
    Err(err) =>
      assert_true(
        validation_error_message(err).contains(
          "instruction site does not exist",
        ),
        msg=validation_error_message(err),
      )
  }
}

///|
test "producer identity never changes structural validation" {
  let module_ = compiler_facts_multivalue_module(0U)
  let section = module_.compiler_fact_custom_section.unwrap()
  let forged = module_.with_compiler_fact_custom_section(
    @representation.CompilerFactCustomSection::new(
      @representation.OptimizationFactsSec::new(
        producer=Some(@representation.ProducerInfo::new("dewdrop", "forged")),
        bodies=section.facts.bodies,
      ),
    ),
  )
  match validate_module(forged) {
    Ok(_) => ()
    Err(err) =>
      fail("producer provenance should remain structurally opaque: \{err}")
  }
}
