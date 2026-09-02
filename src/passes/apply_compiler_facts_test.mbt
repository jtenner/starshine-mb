///|
fn compiler_fact_test_imported_func_count(module_ : @lib.Module) -> Int {
  let mut count = 0
  match module_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
fn compiler_fact_test_call_site(
  module_ : @lib.Module,
  function : UInt,
) -> @representation.CodeSite {
  let imported = compiler_fact_test_imported_func_count(module_)
  let defined = function.reinterpret_as_int() - imported
  let sites = @binary.compiler_fact_module_opcode_sites(module_).unwrap()[defined]
  for site in sites {
    match site.1 {
      @lib.CallRef(_) | @lib.ReturnCallRef(_) =>
        return @representation.CodeSite::new(function, site.0)
      _ => ()
    }
  }
  abort("expected call_ref site")
}

///|
fn compiler_fact_test_attach_exact_target(
  module_ : @lib.Module,
  function : UInt,
  target : UInt,
  producer? : @representation.ProducerInfo? = None,
) -> @lib.Module {
  let site = compiler_fact_test_call_site(module_, function)
  module_.with_compiler_fact_custom_section(
    @representation.CompilerFactCustomSection::new(
      @representation.OptimizationFactsSec::new(producer~, bodies=[
        @representation.FunctionBodyFacts::new(function, calls=[
          @representation.CallSiteFacts::new(site, direct_target=Some(target)),
        ]),
      ]),
    ),
  )
}

///|
fn compiler_fact_test_simple_call_ref(tail? : Bool = false) -> @lib.Module {
  let callee_type_idx = @lib.TypeIdx::new(0U)
  let caller_type_idx = @lib.TypeIdx::new(1U)
  let callee_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let caller_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([callee_type, caller_type]))
  .with_func_sec(@lib.FuncSec::new([callee_type_idx, caller_type_idx]))
  .with_elem_sec(
    @lib.ElemSec::new([
      @lib.Elem::new(
        @lib.ElemMode::declarative(),
        @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
      ),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(0U))]),
      ),
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(10)),
          @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
          if tail {
            @lib.Instruction::return_call_ref(callee_type_idx)
          } else {
            @lib.Instruction::call_ref(callee_type_idx)
          },
        ]),
      ),
    ]),
  )
}

///|
fn compiler_fact_test_effectful_target() -> @lib.Module {
  let callee_type_idx = @lib.TypeIdx::new(0U)
  let getter_type_idx = @lib.TypeIdx::new(1U)
  let caller_type_idx = @lib.TypeIdx::new(2U)
  let callee_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let getter_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([], [
        @lib.ValType::ref_type(
          @lib.RefType::new(true, @lib.HeapType::new(callee_type_idx)),
        ),
      ]),
    ),
  )
  let caller_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([callee_type, getter_type, caller_type]))
  .with_import_sec(
    @lib.ImportSec::new([
      @lib.Import::new(
        @lib.Name::new("env"),
        @lib.Name::new("get_target"),
        @lib.ExternType::func(getter_type_idx),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([callee_type_idx, caller_type_idx]))
  .with_elem_sec(
    @lib.ElemSec::new([
      @lib.Elem::new(
        @lib.ElemMode::declarative(),
        @lib.ElemKind::funcs([@lib.FuncIdx::new(1U)]),
      ),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(0U))]),
      ),
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(10)),
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          @lib.Instruction::call_ref(callee_type_idx),
        ]),
      ),
    ]),
  )
}

///|
test "compiler facts absent fast path leaves the module untouched" {
  let module_ = compiler_fact_test_simple_call_ref()
  let result = apply_compiler_facts(
    module_,
    CompilerFactUsePolicy::trust_assertions(),
  ).unwrap()
  @debug.assert_eq(result.stats.fact_sections_seen, 0)
  @debug.assert_eq(result.module_.code_sec, module_.code_sec)
}

///|
test "compiler fact use policy defaults do not trust assertions" {
  assert_false(
    CompilerFactUsePolicy::ignore() == CompilerFactUsePolicy::hints_only(),
  )
  assert_false(
    CompilerFactUsePolicy::hints_only() ==
    CompilerFactUsePolicy::trust_assertions(),
  )
  let module_ = compiler_fact_test_attach_exact_target(
    compiler_fact_test_simple_call_ref(),
    1U,
    0U,
    producer=Some(@representation.ProducerInfo::new("dewdrop", "forged")),
  )
  for
    policy in [
      CompilerFactUsePolicy::ignore(),
      CompilerFactUsePolicy::hints_only(),
    ] {
    let result = apply_compiler_facts(module_, policy).unwrap()
    let pretty = result.module_.pretty_print_func(@lib.FuncIdx::new(1U))
    assert_true(pretty.contains("call_ref"), msg=pretty)
    assert_false(pretty.contains("drop"), msg=pretty)
    @debug.assert_eq(result.stats.call_ref_converted, 0)
    @debug.assert_eq(result.stats.ignored_untrusted_assertions, 1)
  }
}

///|
test "trusted exact target preserves target evaluation then directizes call_ref" {
  let module_ = compiler_fact_test_attach_exact_target(
    compiler_fact_test_effectful_target(),
    2U,
    1U,
  )
  let result = apply_compiler_facts(
    module_,
    CompilerFactUsePolicy::trust_assertions(),
  ).unwrap()
  match result.module_.code_sec {
    Some(@lib.CodeSec([_, @lib.Func(_, @lib.Expr(body))])) =>
      @debug.assert_eq(body, [
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::drop(),
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
      ])
    other => fail("expected effect-preserving direct call body, got \{other}")
  }
  @debug.assert_eq(result.stats.exact_call_target_facts_accepted, 1)
  @debug.assert_eq(result.stats.call_ref_converted, 1)
  @debug.assert_eq(result.module_.compiler_fact_custom_section, None)
}

///|
test "trusted singleton function-target value fact materializes call_ref" {
  let module_ = compiler_fact_test_simple_call_ref()
  let sites = @binary.compiler_fact_module_opcode_sites(module_).unwrap()[1]
  let mut producer_offset = 0U
  for site in sites {
    if site.1 is @lib.RefFunc(_) {
      producer_offset = site.0
    }
  }
  let module_ = module_.with_compiler_fact_custom_section(
    @representation.CompilerFactCustomSection::new(
      @representation.OptimizationFactsSec::new(bodies=[
        @representation.FunctionBodyFacts::new(1U, sites=[
          @representation.ExpressionFact::new(
            @representation.ValueSite::new(
              @representation.CodeSite::new(1U, producer_offset),
            ),
            @representation.ValueFacts::exact_ref_func(0U),
          ),
        ]),
      ]),
    ),
  )
  let result = apply_compiler_facts(
    module_,
    CompilerFactUsePolicy::trust_assertions(),
  ).unwrap()
  assert_false(
    result.module_.pretty_print_func(@lib.FuncIdx::new(1U)).contains("call_ref"),
  )
  @debug.assert_eq(result.stats.call_ref_converted, 1)
}

///|
test "multi-result producer uses the top result identity for call_ref" {
  let target_type = @lib.TypeIdx::new(0U)
  let pair_type = @lib.TypeIdx::new(1U)
  let caller_type = @lib.TypeIdx::new(2U)
  let module_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::funcref()], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [
              @lib.ValType::funcref(),
              @lib.ValType::funcref(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([target_type, target_type, caller_type]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U), @lib.FuncIdx::new(1U)]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(10))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(20))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::type_idx(pair_type),
              @lib.Expr::new([
                @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
                @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
              ]),
            ),
            @lib.Instruction::call_ref(target_type),
          ]),
        ),
      ]),
    )
  let sites = @binary.compiler_fact_module_opcode_sites(module_).unwrap()[2]
  let mut producer_offset = 0U
  for site in sites {
    if site.1 is @lib.Block(_, _) {
      producer_offset = site.0
    }
  }
  let code_site = @representation.CodeSite::new(2U, producer_offset)
  let module_ = module_.with_compiler_fact_custom_section(
    @representation.CompilerFactCustomSection::new(
      @representation.OptimizationFactsSec::new(bodies=[
        @representation.FunctionBodyFacts::new(2U, sites=[
          @representation.ExpressionFact::new(
            @representation.ValueSite::new(code_site, result=0U),
            @representation.ValueFacts::exact_ref_func(0U),
          ),
          @representation.ExpressionFact::new(
            @representation.ValueSite::new(code_site, result=1U),
            @representation.ValueFacts::exact_ref_func(1U),
          ),
        ]),
      ]),
    ),
  )
  let result = apply_compiler_facts(
    module_,
    CompilerFactUsePolicy::trust_assertions(),
  ).unwrap()
  match result.module_.code_sec {
    Some(@lib.CodeSec([_, _, @lib.Func(_, @lib.Expr(body))])) =>
      @debug.assert_eq(
        body.last(),
        Some(@lib.Instruction::call(@lib.FuncIdx::new(1U))),
      )
    other => fail("expected multi-result exact target rewrite, got \{other}")
  }
}

///|
test "singleton function target set without nonnull remains unconsumed" {
  let module_ = compiler_fact_test_simple_call_ref()
  let sites = @binary.compiler_fact_module_opcode_sites(module_).unwrap()[1]
  let mut producer_offset = 0U
  for site in sites {
    if site.1 is @lib.RefFunc(_) {
      producer_offset = site.0
    }
  }
  let module_ = module_.with_compiler_fact_custom_section(
    @representation.CompilerFactCustomSection::new(
      @representation.OptimizationFactsSec::new(bodies=[
        @representation.FunctionBodyFacts::new(1U, sites=[
          @representation.ExpressionFact::new(
            @representation.ValueSite::new(
              @representation.CodeSite::new(1U, producer_offset),
            ),
            @representation.ValueFacts::new(
              reference=Some(
                @representation.ReferenceFacts::new(
                  function_targets=Some(
                    @representation.ClosedFunctionSet::new([0U]),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ]),
    ),
  )
  let result = apply_compiler_facts(
    module_,
    CompilerFactUsePolicy::trust_assertions(),
  ).unwrap()
  assert_true(
    result.module_.pretty_print_func(@lib.FuncIdx::new(1U)).contains("call_ref"),
  )
}

///|
test "trusted exact target supports imported direct callees" {
  let type_idx = @lib.TypeIdx::new(0U)
  let module_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::new("env"),
          @lib.Name::new("target"),
          @lib.ExternType::func(type_idx),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(10)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
            @lib.Instruction::call_ref(type_idx),
          ]),
        ),
      ]),
    )
  let module_ = compiler_fact_test_attach_exact_target(module_, 1U, 0U)
  let result = apply_compiler_facts(
    module_,
    CompilerFactUsePolicy::trust_assertions(),
  ).unwrap()
  match result.module_.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) =>
      @debug.assert_eq(
        body.last(),
        Some(@lib.Instruction::call(@lib.FuncIdx::new(0U))),
      )
    other => fail("expected imported exact target rewrite, got \{other}")
  }
}

///|
test "trusted exact target materializes return_call_ref as return_call" {
  let module_ = compiler_fact_test_attach_exact_target(
    compiler_fact_test_simple_call_ref(tail=true),
    1U,
    0U,
  )
  let result = apply_compiler_facts(
    module_,
    CompilerFactUsePolicy::trust_assertions(),
  ).unwrap()
  match result.module_.code_sec {
    Some(@lib.CodeSec([_, @lib.Func(_, @lib.Expr(body))])) =>
      @debug.assert_eq(body, [
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
        @lib.Instruction::drop(),
        @lib.Instruction::return_call(@lib.FuncIdx::new(0U)),
      ])
    other => fail("expected direct tail-call body, got \{other}")
  }
  @debug.assert_eq(result.stats.return_call_ref_converted, 1)
}

///|
test "trusted exact target fails closed on an incompatible signature" {
  let base = compiler_fact_test_simple_call_ref()
  let wrong_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let module_ = match base.type_sec {
    Some(@lib.TypeSec(types)) => {
      let next = types.copy()
      next.push(wrong_type)
      base.with_type_sec(@lib.TypeSec::new(next))
    }
    None => fail("expected type section")
  }
  let module_ = match module_.func_sec {
    Some(@lib.FuncSec(types)) => {
      let next = types.copy()
      next.push(@lib.TypeIdx::new(2U))
      module_.with_func_sec(@lib.FuncSec::new(next))
    }
    None => fail("expected function section")
  }
  let module_ = match module_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let next = funcs.copy()
      next.push(@lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])))
      module_.with_code_sec(@lib.CodeSec::new(next))
    }
    None => fail("expected code section")
  }
  let module_ = compiler_fact_test_attach_exact_target(module_, 1U, 2U)
  let result = apply_compiler_facts(
    module_,
    CompilerFactUsePolicy::trust_assertions(),
  ).unwrap()
  assert_true(
    result.module_.pretty_print_func(@lib.FuncIdx::new(1U)).contains("call_ref"),
  )
  @debug.assert_eq(result.stats.structurally_incompatible_rejected, 1)
}

///|
fn compiler_fact_test_first_plain_call_site(
  module_ : @lib.Module,
  function : UInt,
) -> @representation.CodeSite {
  let imported = compiler_fact_test_imported_func_count(module_)
  let defined = function.reinterpret_as_int() - imported
  let sites = @binary.compiler_fact_module_opcode_sites(module_).unwrap()[defined]
  for site in sites {
    if site.1 is @lib.Call(_) {
      return @representation.CodeSite::new(function, site.0)
    }
  }
  abort("expected direct call site")
}

///|
fn compiler_fact_test_attach_value_fact(
  module_ : @lib.Module,
  function : UInt,
  facts : @representation.ValueFacts,
  version? : UInt = 1U,
  fact_function? : UInt? = None,
  fact_offset? : UInt? = None,
) -> @lib.Module {
  let producer = compiler_fact_test_first_plain_call_site(module_, function)
  let fact_owner = match fact_function {
    Some(value) => value
    None => function
  }
  let offset = match fact_offset {
    Some(value) => value
    None => producer.offset
  }
  module_.with_compiler_fact_custom_section(
    @representation.CompilerFactCustomSection::new(
      @representation.OptimizationFactsSec::new(
        producer=Some(
          @representation.ProducerInfo::new("dewdrop", "representative"),
        ),
        bodies=[
          @representation.FunctionBodyFacts::new(fact_owner, sites=[
            @representation.ExpressionFact::new(
              @representation.ValueSite::new(
                @representation.CodeSite::new(fact_owner, offset),
              ),
              facts,
            ),
          ]),
        ],
      ),
      version~,
    ),
  )
}

///|
fn compiler_fact_test_i32_exact(bits : UInt64) -> @representation.ValueFacts {
  @representation.ValueFacts::exact_value(
    @representation.FactValue::integer(
      @representation.IntConstant::new(@representation.IntWidth::i32(), bits),
    ),
  )
}

///|
fn compiler_fact_test_i32_compare_module(op : @lib.Instruction) -> @lib.Module {
  let type_ = @lib.TypeIdx::new(0U)
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
      ),
    ]),
  )
  .with_import_sec(
    @lib.ImportSec::new([
      @lib.Import::new(
        @lib.Name::new("env"),
        @lib.Name::new("value"),
        @lib.ExternType::func(type_),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([type_]))
  .with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::new("run"),
        @lib.ExternIdx::func(@lib.FuncIdx::new(1U)),
      ),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          @lib.Instruction::i32_const(@lib.I32(7)),
          op,
        ]),
      ),
    ]),
  )
}

///|
fn compiler_fact_test_i64_compare_module(op : @lib.Instruction) -> @lib.Module {
  let type_ = @lib.TypeIdx::new(0U)
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i64()])),
      ),
    ]),
  )
  .with_import_sec(
    @lib.ImportSec::new([
      @lib.Import::new(
        @lib.Name::new("env"),
        @lib.Name::new("value"),
        @lib.ExternType::func(type_),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i64()])),
      ),
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
      ),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          @lib.Instruction::i64_const(@lib.I64(-1L)),
          op,
        ]),
      ),
    ]),
  )
}

///|
fn compiler_fact_test_i32_eqz_module() -> @lib.Module {
  let type_ = @lib.TypeIdx::new(0U)
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
      ),
    ]),
  )
  .with_import_sec(
    @lib.ImportSec::new([
      @lib.Import::new(
        @lib.Name::new("env"),
        @lib.Name::new("value"),
        @lib.ExternType::func(type_),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([type_]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          @lib.Instruction::i32_eqz(),
        ]),
      ),
    ]),
  )
}

///|
test "trusted exact i64 raw bits fold wraparound equality" {
  let module_ = compiler_fact_test_attach_value_fact(
    compiler_fact_test_i64_compare_module(@lib.Instruction::i64_eq()),
    1U,
    @representation.ValueFacts::exact_value(
      @representation.FactValue::integer(
        @representation.IntConstant::new(
          @representation.IntWidth::i64(),
          UInt64::lnot(0UL),
        ),
      ),
    ),
  )
  let result = apply_compiler_facts(
    module_,
    CompilerFactUsePolicy::trust_assertions(),
  ).unwrap()
  let pretty = result.module_.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_false(pretty.contains("i64.eq"), msg=pretty)
}

///|
test "standalone nonzero fact folds i32.eqz false" {
  let module_ = compiler_fact_test_attach_value_fact(
    compiler_fact_test_i32_eqz_module(),
    1U,
    @representation.ValueFacts::new(
      integer=Some(
        @representation.IntegerFacts::new(
          @representation.IntWidth::i32(),
          nonzero=true,
        ),
      ),
    ),
  )
  let result = apply_compiler_facts(
    module_,
    CompilerFactUsePolicy::trust_assertions(),
  ).unwrap()
  match result.module_.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) =>
      @debug.assert_eq(body, [
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
      ])
    other => fail("expected nonzero eqz fold, got \{other}")
  }
  @debug.assert_eq(result.stats.integer_zero_checks_folded, 1)
}

///|
test "trusted exact i32 fact folds equality true and preserves producer evaluation" {
  let module_ = compiler_fact_test_attach_value_fact(
    compiler_fact_test_i32_compare_module(@lib.Instruction::i32_eq()),
    1U,
    compiler_fact_test_i32_exact(7UL),
  )
  let result = apply_compiler_facts(
    module_,
    CompilerFactUsePolicy::trust_assertions(),
  ).unwrap()
  match result.module_.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) =>
      @debug.assert_eq(body, [
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::drop(),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(1)),
      ])
    other => fail("expected exact equality fold, got \{other}")
  }
  @debug.assert_eq(result.stats.integer_comparisons_folded, 1)
}

///|
test "trusted exact i32 fact folds equality false" {
  let module_ = compiler_fact_test_attach_value_fact(
    compiler_fact_test_i32_compare_module(@lib.Instruction::i32_eq()),
    1U,
    compiler_fact_test_i32_exact(8UL),
  )
  let result = apply_compiler_facts(
    module_,
    CompilerFactUsePolicy::trust_assertions(),
  ).unwrap()
  assert_true(
    result.module_.pretty_print_func(@lib.FuncIdx::new(1U)).contains("I32(0)"),
  )
  assert_false(
    result.module_.pretty_print_func(@lib.FuncIdx::new(1U)).contains("i32.eq"),
  )
}

///|
test "trusted signed and unsigned ranges fold the same boundary comparison differently" {
  let facts = @representation.ValueFacts::new(
    integer=Some(
      @representation.IntegerFacts::new(
        @representation.IntWidth::i32(),
        unsigned_range=Some(
          @representation.UnsignedRange::new(0x8000_0000UL, 0xFFFF_FFFFUL),
        ),
        signed_range=Some(@representation.SignedRange::new(-2147483648L, -1L)),
      ),
    ),
  )
  for
    pair in [
      (@lib.Instruction::i32_lt_s(), 1),
      (@lib.Instruction::i32_lt_u(), 0),
    ] {
    let (op, expected) = pair
    let base = compiler_fact_test_i32_compare_module(op)
    let with_zero = match base.code_sec {
      Some(@lib.CodeSec([@lib.Func(locals, @lib.Expr([call, _, compare]))])) =>
        base.with_code_sec(
          @lib.CodeSec::new([
            @lib.Func::new(
              locals,
              @lib.Expr::new([
                call,
                @lib.Instruction::i32_const(@lib.I32(0)),
                compare,
              ]),
            ),
          ]),
        )
      other => fail("expected comparison fixture, got \{other}")
    }
    let module_ = compiler_fact_test_attach_value_fact(with_zero, 1U, facts)
    let result = apply_compiler_facts(
      module_,
      CompilerFactUsePolicy::trust_assertions(),
    ).unwrap()
    let pretty = result.module_.pretty_print_func(@lib.FuncIdx::new(1U))
    assert_true(pretty.contains("I32(\{expected})"), msg=pretty)
    assert_false(pretty.contains("i32.lt"), msg=pretty)
  }
}

///|
test "overlapping integer ranges remain unknown" {
  let facts = @representation.ValueFacts::unsigned_range(
    0UL,
    10UL,
    width=@representation.IntWidth::i32(),
  )
  let module_ = compiler_fact_test_attach_value_fact(
    compiler_fact_test_i32_compare_module(@lib.Instruction::i32_lt_u()),
    1U,
    facts,
  )
  let result = apply_compiler_facts(
    module_,
    CompilerFactUsePolicy::trust_assertions(),
  ).unwrap()
  assert_true(
    result.module_.pretty_print_func(@lib.FuncIdx::new(1U)).contains("i32.lt_u"),
  )
  @debug.assert_eq(result.stats.valid_facts_without_rewrite, 1)
}

///|
test "inclusive range endpoint proves less-or-equal but not strict less-than" {
  let facts = @representation.ValueFacts::unsigned_range(
    0UL,
    7UL,
    width=@representation.IntWidth::i32(),
  )
  for
    pair in [
      (@lib.Instruction::i32_le_u(), true),
      (@lib.Instruction::i32_lt_u(), false),
    ] {
    let (op, should_fold) = pair
    let module_ = compiler_fact_test_attach_value_fact(
      compiler_fact_test_i32_compare_module(op),
      1U,
      facts,
    )
    let result = apply_compiler_facts(
      module_,
      CompilerFactUsePolicy::trust_assertions(),
    ).unwrap()
    let pretty = result.module_.pretty_print_func(@lib.FuncIdx::new(1U))
    if should_fold {
      assert_false(pretty.contains("i32.le_u"), msg=pretty)
      assert_true(pretty.contains("I32(1)"), msg=pretty)
    } else {
      assert_true(pretty.contains("i32.lt_u"), msg=pretty)
    }
  }
}

///|
test "full-domain integer range cannot prove an ordered comparison" {
  let module_ = compiler_fact_test_attach_value_fact(
    compiler_fact_test_i32_compare_module(@lib.Instruction::i32_lt_u()),
    1U,
    @representation.ValueFacts::unsigned_range(
      0UL,
      0xFFFF_FFFFUL,
      width=@representation.IntWidth::i32(),
    ),
  )
  let result = apply_compiler_facts(
    module_,
    CompilerFactUsePolicy::trust_assertions(),
  ).unwrap()
  assert_true(
    result.module_.pretty_print_func(@lib.FuncIdx::new(1U)).contains("i32.lt_u"),
  )
}

///|
test "empty and malformed integer domains fail closed" {
  let malformed = @representation.ValueFacts::unsigned_range(
    10UL,
    0UL,
    width=@representation.IntWidth::i32(),
  )
  let overwide_signed = @representation.ValueFacts::signed_range(
    -2147483649L,
    -1L,
    width=@representation.IntWidth::i32(),
  )
  for
    facts in [
      @representation.ValueFacts::impossible(),
      malformed,
      overwide_signed,
    ] {
    let module_ = compiler_fact_test_attach_value_fact(
      compiler_fact_test_i32_compare_module(@lib.Instruction::i32_eq()),
      1U,
      facts,
    )
    let result = apply_compiler_facts(
      module_,
      CompilerFactUsePolicy::trust_assertions(),
    ).unwrap()
    assert_true(
      result.module_.pretty_print_func(@lib.FuncIdx::new(1U)).contains("i32.eq"),
    )
    assert_true(result.stats.malformed_or_impossible_facts > 0)
  }
}

///|
test "stale instruction offset cannot be remapped by instruction order" {
  let base = compiler_fact_test_i32_compare_module(@lib.Instruction::i32_eq())
  let original_site = compiler_fact_test_first_plain_call_site(base, 1U)
  let module_ = compiler_fact_test_attach_value_fact(
    base,
    1U,
    compiler_fact_test_i32_exact(7UL),
    fact_offset=Some(original_site.offset + 1U),
  )
  let result = apply_compiler_facts(
    module_,
    CompilerFactUsePolicy::trust_assertions(),
  ).unwrap()
  assert_true(
    result.module_.pretty_print_func(@lib.FuncIdx::new(1U)).contains("i32.eq"),
  )
  assert_true(result.stats.stale_or_unresolved_sites > 0)
}

///|
test "invalid memory index in effect facts blocks unrelated semantic rewrites" {
  let with_value = compiler_fact_test_attach_value_fact(
    compiler_fact_test_i32_compare_module(@lib.Instruction::i32_eq()),
    1U,
    compiler_fact_test_i32_exact(7UL),
  )
  let section = with_value.compiler_fact_custom_section.unwrap()
  let module_ = with_value.with_compiler_fact_custom_section(
    @representation.CompilerFactCustomSection::new(
      @representation.OptimizationFactsSec::new(
        producer=section.facts.producer,
        functions=[
          @representation.FunctionFacts::new(
            1U,
            effects=Some(
              @representation.EffectFacts::new(
                @representation.EffectMask::empty(),
                read_memories=Some(@representation.ClosedMemorySet::new([0U])),
              ),
            ),
          ),
        ],
        bodies=section.facts.bodies,
      ),
    ),
  )
  let result = apply_compiler_facts(
    module_,
    CompilerFactUsePolicy::trust_assertions(),
  ).unwrap()
  assert_true(
    result.module_.pretty_print_func(@lib.FuncIdx::new(1U)).contains("i32.eq"),
  )
  assert_true(result.stats.invalid_referenced_indices > 0)
  @debug.assert_eq(result.stats.integer_comparisons_folded, 0)
}

///|
test "invalid index inside a candidate value fact fails closed" {
  let module_ = compiler_fact_test_attach_value_fact(
    compiler_fact_test_i32_compare_module(@lib.Instruction::i32_eq()),
    1U,
    @representation.ValueFacts::exact_value(
      @representation.FactValue::ref_func(999U),
    ),
  )
  let result = apply_compiler_facts(
    module_,
    CompilerFactUsePolicy::trust_assertions(),
  ).unwrap()
  assert_true(
    result.module_.pretty_print_func(@lib.FuncIdx::new(1U)).contains("i32.eq"),
  )
  assert_true(result.stats.invalid_referenced_indices > 0)
}

///|
test "HintsOnly blocks fact-proven semantic comparison folding" {
  let module_ = compiler_fact_test_attach_value_fact(
    compiler_fact_test_i32_compare_module(@lib.Instruction::i32_eq()),
    1U,
    compiler_fact_test_i32_exact(7UL),
  )
  let result = apply_compiler_facts(
    module_,
    CompilerFactUsePolicy::hints_only(),
  ).unwrap()
  assert_true(
    result.module_.pretty_print_func(@lib.FuncIdx::new(1U)).contains("i32.eq"),
  )
  @debug.assert_eq(result.stats.facts_blocked_by_trust, 1)
}

///|
test "wrong-width exact value fact is rejected without folding" {
  let wrong = @representation.ValueFacts::exact_value(
    @representation.FactValue::integer(
      @representation.IntConstant::new(@representation.IntWidth::i64(), 7UL),
    ),
  )
  let module_ = compiler_fact_test_attach_value_fact(
    compiler_fact_test_i32_compare_module(@lib.Instruction::i32_eq()),
    1U,
    wrong,
  )
  let result = apply_compiler_facts(
    module_,
    CompilerFactUsePolicy::trust_assertions(),
  ).unwrap()
  assert_true(
    result.module_.pretty_print_func(@lib.FuncIdx::new(1U)).contains("i32.eq"),
  )
  @debug.assert_eq(result.stats.type_mismatches, 1)
}

///|
test "unsupported fact version fails closed before semantic queries" {
  let module_ = compiler_fact_test_attach_value_fact(
    compiler_fact_test_i32_compare_module(@lib.Instruction::i32_eq()),
    1U,
    compiler_fact_test_i32_exact(7UL),
    version=2U,
  )
  let result = apply_compiler_facts(
    module_,
    CompilerFactUsePolicy::trust_assertions(),
  ).unwrap()
  assert_true(
    result.module_.pretty_print_func(@lib.FuncIdx::new(1U)).contains("i32.eq"),
  )
  @debug.assert_eq(result.stats.unsupported_versions, 1)
}

///|
test "fact attached to a different function body cannot fold a consumer" {
  let module_ = compiler_fact_test_attach_value_fact(
    compiler_fact_test_i32_compare_module(@lib.Instruction::i32_eq()),
    1U,
    compiler_fact_test_i32_exact(7UL),
    fact_function=Some(0U),
  )
  let result = apply_compiler_facts(
    module_,
    CompilerFactUsePolicy::trust_assertions(),
  ).unwrap()
  assert_true(
    result.module_.pretty_print_func(@lib.FuncIdx::new(1U)).contains("i32.eq"),
  )
  assert_true(result.stats.stale_or_unresolved_sites > 0)
}

///|
fn compiler_fact_test_reference_null_module() -> @lib.Module {
  let ref_type = @lib.TypeIdx::new(0U)
  let run_type = @lib.TypeIdx::new(1U)
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func([], [@lib.ValType::externref()]),
        ),
      ),
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
      ),
    ]),
  )
  .with_import_sec(
    @lib.ImportSec::new([
      @lib.Import::new(
        @lib.Name::new("env"),
        @lib.Name::new("ref"),
        @lib.ExternType::func(ref_type),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([run_type]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          @lib.Instruction::ref_is_null(),
        ]),
      ),
    ]),
  )
}

///|
test "trusted nonnull reference fact folds ref.is_null while preserving call" {
  let module_ = compiler_fact_test_attach_value_fact(
    compiler_fact_test_reference_null_module(),
    1U,
    @representation.ValueFacts::nonnull(),
  )
  let result = apply_compiler_facts(
    module_,
    CompilerFactUsePolicy::trust_assertions(),
  ).unwrap()
  match result.module_.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) =>
      @debug.assert_eq(body, [
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(0)),
      ])
    other => fail("expected nonnull ref.is_null fold, got \{other}")
  }
  @debug.assert_eq(result.stats.reference_null_checks_folded, 1)
}

///|
test "trusted null-only reference fact folds ref.is_null true" {
  let module_ = compiler_fact_test_attach_value_fact(
    compiler_fact_test_reference_null_module(),
    1U,
    @representation.ValueFacts::new(
      reference=Some(
        @representation.ReferenceFacts::new(
          nullability=Some(@representation.NullabilityFacts::null_only()),
        ),
      ),
    ),
  )
  let result = apply_compiler_facts(
    module_,
    CompilerFactUsePolicy::trust_assertions(),
  ).unwrap()
  let pretty = result.module_.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_false(pretty.contains("ref.is_null"), msg=pretty)
}

///|
test "broad reference heap bound without nullability does not fold ref.is_null" {
  let module_ = compiler_fact_test_attach_value_fact(
    compiler_fact_test_reference_null_module(),
    1U,
    @representation.ValueFacts::new(
      reference=Some(
        @representation.ReferenceFacts::new(
          heap=Some(
            @representation.HeapDomain::subtypes_of(
              @representation.FactHeapType::extern_(),
            ),
          ),
        ),
      ),
    ),
  )
  let result = apply_compiler_facts(
    module_,
    CompilerFactUsePolicy::trust_assertions(),
  ).unwrap()
  match result.module_.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) =>
      @debug.assert_eq(body.last(), Some(@lib.Instruction::ref_is_null()))
    other => fail("expected broad reference bound to remain, got \{other}")
  }
}

///|
test "fact folding preserves an operand producer that always traps" {
  let source =
    #| (module
    #|   (func $trap (result i32) unreachable)
    #|   (func (export "run") (result i32)
    #|     call $trap
    #|     i32.const 7
    #|     i32.eq))
    #|
  let module_ = compiler_fact_test_attach_value_fact(
    pass_test_module_from_wat(source),
    1U,
    compiler_fact_test_i32_exact(7UL),
  )
  let result = apply_compiler_facts(
    module_,
    CompilerFactUsePolicy::trust_assertions(),
  ).unwrap()
  let pretty = result.module_.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_false(pretty.contains("i32.eq"), msg=pretty)
  match @validate.validate_module(result.module_) {
    Ok(_) => ()
    Err(err) => fail("expected trap-preserving output to validate, got \{err}")
  }
}

///|
test "serialized compiler fact drives branch cleanup through the normal pipeline" {
  let source =
    #| (module
    #|   (global $seen (export "seen") (mut i32) (i32.const 0))
    #|   (func $producer (result i32)
    #|     i32.const 1
    #|     global.set $seen
    #|     i32.const 7)
    #|   (func (export "run") (result i32)
    #|     call $producer
    #|     i32.const 7
    #|     i32.eq
    #|     if (result i32)
    #|       i32.const 11
    #|     else
    #|       unreachable
    #|     end))
    #|
  let base = pass_test_module_from_wat(source)
  let with_facts = compiler_fact_test_attach_value_fact(
    base,
    1U,
    compiler_fact_test_i32_exact(7UL),
  )
  match @validate.validate_module(with_facts) {
    Ok(_) => ()
    Err(err) => fail("expected fact fixture validation, got \{err}")
  }
  let encoded = @binary.encode_module(with_facts).unwrap()
  let decoded = @binary.decode_module(encoded).unwrap()
  assert_true(decoded.compiler_fact_custom_section is Some(_))
  let trace : Array[String] = []
  let optimized = run_hot_pipeline(
    decoded,
    HotPipelineOptions::new(
      compiler_fact_policy=CompilerFactUsePolicy::trust_assertions(),
      trace=Some(fn(line) { trace.push(line) }),
    ),
    ["precompute", "dead-code-elimination"],
  ).unwrap()
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[apply-compiler-facts]:summary") &&
      line.contains("categories.value=1") &&
      line.contains("candidates=1") &&
      line.contains("applied.integer_compare=1")
    }),
    msg="\{trace}",
  )
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected optimized fact fixture validation, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("I32(11)"), msg=pretty)
  assert_false(pretty.contains("i32.eq"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("unreachable"), msg=pretty)
  assert_true(optimized.compiler_fact_custom_section is None)
  ignore(
    @binary.decode_module(@binary.encode_module(optimized).unwrap()).unwrap(),
  )
}
