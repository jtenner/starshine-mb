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
