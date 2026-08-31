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
    SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
    SubType::comp_type(CompType::struct_([])),
  ])
  .with_funcs([
    FuncType::new([ValType::i32()], [ValType::i32()]),
    FuncType::new([ValType::i32()], [ValType::i32()]),
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
fn compiler_facts_test_populated() -> @representation.CompilerFactCustomSection {
  let value = @representation.ValueFacts::new(
    non_null=true,
    exact_heap_type=Some(1U),
    exact_call_target=Some(1U),
    signed_range=Some(@representation.SignedRange::new(-1L, 2L)),
    unsigned_range=Some(@representation.UnsignedRange::new(3UL, 4UL)),
    does_not_escape=true,
    identity_not_observed=true,
  )
  let effects = @representation.EffectFacts::new(
    @representation.EffectMask::control()
    .union(@representation.EffectMask::call())
    .union(@representation.EffectMask::global_state())
    .union(@representation.EffectMask::memory_read())
    .union(@representation.EffectMask::memory_write())
    .union(@representation.EffectMask::table_read())
    .union(@representation.EffectMask::table_write())
    .union(@representation.EffectMask::heap_read())
    .union(@representation.EffectMask::heap_write()),
    read_globals=Some(@representation.ClosedGlobalSet::new([0U])),
    written_globals=Some(@representation.ClosedGlobalSet::new([0U])),
    read_memories=Some(@representation.ClosedMemorySet::new([0U])),
    written_memories=Some(@representation.ClosedMemorySet::new([0U])),
    read_tables=Some(@representation.ClosedTableSet::new([0U])),
    written_tables=Some(@representation.ClosedTableSet::new([0U])),
    read_heap_types=Some(@representation.ClosedTypeViewSet::new([1U])),
    written_heap_types=Some(@representation.ClosedTypeViewSet::new([1U])),
    direct_callees=Some(@representation.ClosedFunctionSet::new([1U])),
  )
  let function = @representation.FunctionFacts::new(
    0U,
    effects=Some(effects),
    parameters=[
      @representation.ParameterFacts::new(
        0U,
        value=Some(value),
        uses=Some(@representation.ParameterUseMask::call_argument()),
        escape_sinks=Some(@representation.EscapeSinkMask::call()),
      ),
    ],
    results=[
      @representation.ResultFacts::new(
        0U,
        value=Some(value),
        identity=Some(
          @representation.ResultIdentityFacts::same_as_parameter(0U),
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
  let left = @representation.FactSiteRef::new(0U, 1U)
  let right = @representation.FactSiteRef::new(1U, 2U)
  let body = @representation.FunctionBodyFacts::new(
    0U,
    sites=[
      @representation.ExpressionFact::new(0U, 1U, [
        @representation.Fact::non_null(),
        @representation.Fact::exact_heap_type(1U),
        @representation.Fact::exact_call_target(1U),
        @representation.Fact::signed_range(-1L, 1L),
        @representation.Fact::unsigned_range(0UL, 2UL),
        @representation.Fact::does_not_escape(),
        @representation.Fact::identity_not_observed(),
      ]),
    ],
    relations=[
      @representation.FactRelation::same_value(left, right),
      @representation.FactRelation::same_identity(left, right),
      @representation.FactRelation::derived_from(left, right),
    ],
    calls=[
      @representation.CallSiteFacts::new(
        0U,
        3U,
        direct_target=Some(1U),
        profile=Some(
          @representation.CallProfile::new(
            count=Some(5UL),
            temperature=Some(@representation.TemperatureHint::normal()),
          ),
        ),
        inline_policy=Some(@representation.InlinePolicy::always()),
      ),
    ],
    branches=[
      @representation.BranchFacts::new(
        0U,
        4U,
        profile=Some(@representation.BranchProfile::new(4UL, 1UL)),
        temperature=Some(@representation.TemperatureHint::hot()),
      ),
    ],
    loops=[
      @representation.LoopFacts::new(
        0U,
        5U,
        profile=Some(
          @representation.LoopProfile::new(
            backedge_count=Some(9UL),
            estimated_trip_count=Some(3UL),
          ),
        ),
        temperature=Some(@representation.TemperatureHint::cold()),
      ),
    ],
    allocations=[
      @representation.AllocationSiteFacts::new(
        0U,
        6U,
        heap_type=Some(1U),
        does_not_escape=true,
        identity_not_observed=true,
      ),
    ],
  )
  @representation.CompilerFactCustomSection::new(
    @representation.OptimizationFactsSec::new(functions=[function], bodies=[
      body,
    ]),
    module_fingerprint=Some(b"opaque"),
  )
}

///|
test "Validate covers every compiler facts representation type directly" {
  let env = compiler_facts_test_env()
  let section = compiler_facts_test_populated()
  let function = section.facts.functions[0]
  let body = section.facts.bodies[0]
  compiler_facts_assert_valid(section, env)
  compiler_facts_assert_valid(section.facts, env)
  compiler_facts_assert_valid(function, env)
  compiler_facts_assert_valid(function.effects.unwrap(), env)
  compiler_facts_assert_valid(function.effects.unwrap().may, env)
  compiler_facts_assert_valid(@representation.ClosedGlobalSet::new([0U]), env)
  compiler_facts_assert_valid(@representation.ClosedMemorySet::new([0U]), env)
  compiler_facts_assert_valid(@representation.ClosedTableSet::new([0U]), env)
  compiler_facts_assert_valid(@representation.ClosedTypeViewSet::new([1U]), env)
  compiler_facts_assert_valid(@representation.ClosedFunctionSet::new([1U]), env)
  compiler_facts_assert_valid(function.parameters[0], env)
  compiler_facts_assert_valid(function.parameters[0].uses.unwrap(), env)
  compiler_facts_assert_valid(function.parameters[0].escape_sinks.unwrap(), env)
  compiler_facts_assert_valid(function.results[0], env)
  compiler_facts_assert_valid(function.results[0].identity.unwrap(), env)
  compiler_facts_assert_valid(function.parameters[0].value.unwrap(), env)
  compiler_facts_assert_valid(@representation.SignedRange::new(-1L, 1L), env)
  compiler_facts_assert_valid(@representation.UnsignedRange::new(0UL, 1UL), env)
  compiler_facts_assert_valid(function.boundary.unwrap(), env)
  compiler_facts_assert_valid(function.profile.unwrap(), env)
  compiler_facts_assert_valid(@representation.CallProfile::new(), env)
  compiler_facts_assert_valid(@representation.BranchProfile::new(0UL, 0UL), env)
  compiler_facts_assert_valid(@representation.LoopProfile::new(), env)
  compiler_facts_assert_valid(@representation.TemperatureHint::normal(), env)
  compiler_facts_assert_valid(@representation.InlinePolicy::default_(), env)
  compiler_facts_assert_valid(body, env)
  compiler_facts_assert_valid(body.sites[0], env)
  for fact in body.sites[0].facts {
    compiler_facts_assert_valid(fact, env)
  }
  compiler_facts_assert_valid(@representation.FactSiteRef::new(0U, 0U), env)
  for relation in body.relations {
    compiler_facts_assert_valid(relation, env)
  }
  compiler_facts_assert_valid(body.calls[0], env)
  compiler_facts_assert_valid(body.branches[0], env)
  compiler_facts_assert_valid(body.loops[0], env)
  compiler_facts_assert_valid(body.allocations[0], env)
}

///|
test "compiler facts validation rejects ranges and unknown mask bits" {
  let env = compiler_facts_test_env()
  compiler_facts_assert_invalid(
    @representation.SignedRange::new(2L, 1L),
    env,
    "signed range",
  )
  compiler_facts_assert_invalid(
    @representation.UnsignedRange::new(2UL, 1UL),
    env,
    "unsigned range",
  )
  compiler_facts_assert_invalid(
    @representation.EffectMask::from_bits(1UL << 20),
    env,
    "effect mask",
  )
  compiler_facts_assert_invalid(
    @representation.ParameterUseMask::from_bits(1UL << 20),
    env,
    "parameter use mask",
  )
  compiler_facts_assert_invalid(
    @representation.EscapeSinkMask::from_bits(1UL << 20),
    env,
    "escape sink mask",
  )
}

///|
test "compiler facts validation rejects invalid indices in every index space" {
  let env = compiler_facts_test_env()
  compiler_facts_assert_invalid(
    @representation.FunctionFacts::new(2U),
    env,
    "function index",
  )
  compiler_facts_assert_invalid(
    @representation.ValueFacts::new(exact_heap_type=Some(2U)),
    env,
    "type index",
  )
  compiler_facts_assert_invalid(
    @representation.ValueFacts::new(exact_call_target=Some(2U)),
    env,
    "function index",
  )
  compiler_facts_assert_invalid(
    @representation.EffectFacts::new(
      @representation.EffectMask::empty(),
      read_globals=Some(@representation.ClosedGlobalSet::new([1U])),
    ),
    env,
    "global index",
  )
  compiler_facts_assert_invalid(
    @representation.EffectFacts::new(
      @representation.EffectMask::empty(),
      read_memories=Some(@representation.ClosedMemorySet::new([1U])),
    ),
    env,
    "memory index",
  )
  compiler_facts_assert_invalid(
    @representation.EffectFacts::new(
      @representation.EffectMask::empty(),
      read_tables=Some(@representation.ClosedTableSet::new([1U])),
    ),
    env,
    "table index",
  )
  compiler_facts_assert_invalid(
    @representation.EffectFacts::new(
      @representation.EffectMask::empty(),
      read_heap_types=Some(@representation.ClosedTypeViewSet::new([2U])),
    ),
    env,
    "type index",
  )
  compiler_facts_assert_invalid(
    @representation.EffectFacts::new(
      @representation.EffectMask::empty(),
      direct_callees=Some(@representation.ClosedFunctionSet::new([2U])),
    ),
    env,
    "function index",
  )
  compiler_facts_assert_invalid(
    @representation.CallSiteFacts::new(0U, 0U, direct_target=Some(2U)),
    env,
    "function index",
  )
  compiler_facts_assert_invalid(
    @representation.AllocationSiteFacts::new(0U, 0U, heap_type=Some(2U)),
    env,
    "type index",
  )
  compiler_facts_assert_invalid(
    @representation.FactSiteRef::new(2U, 0U),
    env,
    "function index",
  )
}

///|
test "function facts validation checks parameter result and identity indices" {
  let env = compiler_facts_test_env()
  compiler_facts_assert_invalid(
    @representation.FunctionFacts::new(0U, parameters=[
      @representation.ParameterFacts::new(1U),
    ]),
    env,
    "parameter index",
  )
  compiler_facts_assert_invalid(
    @representation.FunctionFacts::new(0U, results=[
      @representation.ResultFacts::new(1U),
    ]),
    env,
    "result index",
  )
  compiler_facts_assert_invalid(
    @representation.FunctionFacts::new(0U, results=[
      @representation.ResultFacts::new(
        0U,
        identity=Some(
          @representation.ResultIdentityFacts::same_as_parameter(1U),
        ),
      ),
    ]),
    env,
    "identity parameter index",
  )
}

///|
test "optimization facts validation rejects duplicate function and body records" {
  let env = compiler_facts_test_env()
  compiler_facts_assert_invalid(
    @representation.OptimizationFactsSec::new(functions=[
      @representation.FunctionFacts::new(0U),
      @representation.FunctionFacts::new(0U),
    ]),
    env,
    "duplicate function facts",
  )
  compiler_facts_assert_invalid(
    @representation.OptimizationFactsSec::new(bodies=[
      @representation.FunctionBodyFacts::new(0U),
      @representation.FunctionBodyFacts::new(0U),
    ]),
    env,
    "duplicate function body facts",
  )
}

///|
test "compiler facts validation rejects unsupported versions" {
  compiler_facts_assert_invalid(
    @representation.CompilerFactCustomSection::new(
      @representation.OptimizationFactsSec::new(),
      version=2U,
    ),
    compiler_facts_test_env(),
    "version",
  )
}

///|
fn compiler_facts_test_module() -> Module {
  let type_sec = TypeSec::new([
    RecType::new(
      SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
    ),
    RecType::new(SubType::comp_type(CompType::struct_([]))),
  ])
  let table_type = TableType::new(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
    Limits::i32(1U, None),
  )
  let body = fn() {
    Func::new(
      Locals::empty(),
      Expr::new([
        Instruction::nop(),
        Instruction::nop(),
        Instruction::nop(),
        Instruction::nop(),
        Instruction::nop(),
        Instruction::nop(),
        Instruction::nop(),
        Instruction::local_get(LocalIdx::new(0U)),
      ]),
    )
  }
  Module::new()
  .with_type_sec(type_sec)
  .with_import_sec(
    ImportSec::new([
      Import::new(
        Name::new("m"),
        Name::new("g"),
        ExternType::global(GlobalType::new(ValType::i32(), false)),
      ),
      Import::new(
        Name::new("m"),
        Name::new("mem"),
        ExternType::mem(MemType::new(Limits::i32(1U, None))),
      ),
      Import::new(
        Name::new("m"),
        Name::new("table"),
        ExternType::table(table_type),
      ),
    ]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(0U), TypeIdx::new(0U)]))
  .with_code_sec(CodeSec::new([body(), body()]))
}

///|
fn compiler_facts_body_site_test_module(
  body : @representation.FunctionBodyFacts,
) -> Module {
  Module::new()
  .with_type_sec(
    TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
  .with_code_sec(
    CodeSec::new([Func::new(Locals::empty(), Expr::new([Instruction::nop()]))]),
  )
  .with_compiler_fact_custom_section(
    @representation.CompilerFactCustomSection::new(
      @representation.OptimizationFactsSec::new(bodies=[body]),
    ),
  )
}

///|
fn compiler_facts_site_test_module(offset : UInt) -> Module {
  compiler_facts_body_site_test_module(
    @representation.FunctionBodyFacts::new(0U, sites=[
      @representation.ExpressionFact::new(0U, offset, [
        @representation.Fact::non_null(),
      ]),
    ]),
  )
}

///|
test "compiler facts validation requires offsets to name instruction opcodes" {
  match validate_module(compiler_facts_site_test_module(0U)) {
    Ok(_) => ()
    Err(err) => fail("opcode offset zero unexpectedly failed: \{err}")
  }
  match validate_module(compiler_facts_site_test_module(1U)) {
    Ok(_) => fail("expected expression terminator offset to be rejected")
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
test "compiler facts site validation uses synthesized stringref encoding" {
  let with_offset = fn(offset : UInt) {
    Module::new()
    .with_type_sec(
      TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::empty(),
          Expr::new([Instruction::string_const(b"site"), Instruction::drop()]),
        ),
      ]),
    )
    .with_compiler_fact_custom_section(
      @representation.CompilerFactCustomSection::new(
        @representation.OptimizationFactsSec::new(bodies=[
          @representation.FunctionBodyFacts::new(0U, sites=[
            @representation.ExpressionFact::new(0U, offset, [
              @representation.Fact::non_null(),
            ]),
          ]),
        ]),
      ),
    )
  }
  match validate_module(with_offset(4U)) {
    Ok(_) => ()
    Err(err) => fail("canonical string.const successor site failed: \{err}")
  }
  match validate_module(with_offset(3U)) {
    Ok(_) => fail("expected string.const immediate offset to be rejected")
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
test "compiler facts validation checks every site-bearing record" {
  let existing = @representation.FactSiteRef::new(0U, 0U)
  let missing = @representation.FactSiteRef::new(0U, 1U)
  let cases : Array[(@representation.FunctionBodyFacts, String)] = [
    (
      @representation.FunctionBodyFacts::new(0U, relations=[
        @representation.FactRelation::same_value(missing, existing),
      ]),
      "relation-left",
    ),
    (
      @representation.FunctionBodyFacts::new(0U, relations=[
        @representation.FactRelation::same_value(existing, missing),
      ]),
      "relation-right",
    ),
    (
      @representation.FunctionBodyFacts::new(0U, calls=[
        @representation.CallSiteFacts::new(0U, 1U),
      ]),
      "kind=call",
    ),
    (
      @representation.FunctionBodyFacts::new(0U, branches=[
        @representation.BranchFacts::new(0U, 1U),
      ]),
      "kind=branch",
    ),
    (
      @representation.FunctionBodyFacts::new(0U, loops=[
        @representation.LoopFacts::new(0U, 1U),
      ]),
      "kind=loop",
    ),
    (
      @representation.FunctionBodyFacts::new(0U, allocations=[
        @representation.AllocationSiteFacts::new(0U, 1U),
      ]),
      "kind=allocation",
    ),
  ]
  for case in cases {
    let (body, expected) = case
    match validate_module(compiler_facts_body_site_test_module(body)) {
      Ok(_) => fail("expected missing compiler facts site: \{expected}")
      Err(err) => {
        let message = validation_error_message(err)
        assert_true(message.contains(expected), msg=message)
      }
    }
  }
}

///|
test "compiler facts body records require defined function bodies" {
  let module_ = Module::new()
    .with_type_sec(
      TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
    )
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("m"),
          Name::new("f"),
          ExternType::func(TypeIdx::new(0U)),
        ),
      ]),
    )
    .with_compiler_fact_custom_section(
      @representation.CompilerFactCustomSection::new(
        @representation.OptimizationFactsSec::new(bodies=[
          @representation.FunctionBodyFacts::new(0U),
        ]),
      ),
    )
  match validate_module(module_) {
    Ok(_) => fail("expected imported function body facts to be rejected")
    Err(err) =>
      assert_true(
        validation_error_message(err).contains("no defined function body"),
        msg=validation_error_message(err),
      )
  }
}

///|
test "validate_module integrates explicit compiler facts and leaves ordinary modules unchanged" {
  let base = compiler_facts_test_module()
  match validate_module(base) {
    Ok(_) => ()
    Err(err) => fail("ordinary module unexpectedly failed: \{err}")
  }
  let with_facts = base.with_compiler_fact_custom_section(
    compiler_facts_test_populated(),
  )
  match validate_module(with_facts) {
    Ok(_) => ()
    Err(err) => fail("valid compiler facts unexpectedly failed: \{err}")
  }
  let invalid = base.with_compiler_fact_custom_section(
    @representation.CompilerFactCustomSection::new(
      @representation.OptimizationFactsSec::new(functions=[
        @representation.FunctionFacts::new(2U),
      ]),
    ),
  )
  match validate_module(invalid) {
    Ok(_) => fail("expected module compiler facts validation failure")
    Err(err) => {
      let diagnostic = validation_error_diagnostic(err)
      match diagnostic.issue {
        ValidationIssue::CompilerFactsSection(message) =>
          assert_true(message.contains("function index"), msg=message)
        _ => fail("expected compiler facts validation diagnostic")
      }
    }
  }
}
