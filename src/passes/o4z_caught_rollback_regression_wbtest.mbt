///|
fn o4z_caught_rollback_fixture() -> @lib.Module {
  pass_test_module_from_wat(
    "(module (tag $e) (func $producer (result i32) i32.const 7) (func (export \"run\") (result i32) call $producer i32.const 7 i32.eq) (func (block $handler (try_table (catch_all $handler) (throw $e)))))",
  ).with_name_sec(
    @lib.NameSec::new(
      module_name=Some(@lib.Name::from_string("prepared-input")),
    ),
  )
}

///|
fn o4z_caught_rollback_value_fact(module_ : @lib.Module) -> @lib.Module {
  let sites = @binary.compiler_fact_module_opcode_sites(module_).unwrap()[1]
  let mut call_offset = None
  for site in sites {
    if site.1 is @lib.Call(_) {
      call_offset = Some(site.0)
      break
    }
  }
  module_.with_compiler_fact_custom_section(
    @representation.CompilerFactCustomSection::new(
      @representation.OptimizationFactsSec::new(bodies=[
        @representation.FunctionBodyFacts::new(1U, sites=[
          @representation.ExpressionFact::new(
            @representation.ValueSite::new(
              @representation.CodeSite::new(1U, call_offset.unwrap()),
            ),
            @representation.ValueFacts::exact_value(
              @representation.FactValue::integer(
                @representation.IntConstant::new(
                  @representation.IntWidth::i32(),
                  7UL,
                ),
              ),
            ),
          ),
        ]),
      ]),
    ),
  )
}

///|
test "O4z caught rollback returns prepared module for each pure preset form" {
  let input = o4z_caught_rollback_value_fact(o4z_caught_rollback_fixture())
  let saved = @binary.encode_module(input).unwrap()
  for
    policy in [
      CompilerFactUsePolicy::ignore(),
      CompilerFactUsePolicy::hints_only(),
      CompilerFactUsePolicy::trust_assertions(),
    ] {
    let expected = apply_compiler_facts(input, policy).unwrap().module_
    for requested in [["optimize"], ["shrink"], ["optimize", "shrink"]] {
      let output = run_hot_pipeline(
        input,
        HotPipelineOptions::new(
          optimize_level=4,
          shrink_level=4,
          compiler_fact_policy=policy,
        ),
        requested,
      ).unwrap()
      assert_eq(
        @binary.encode_module(output).unwrap(),
        @binary.encode_module(expected).unwrap(),
      )
      assert_eq(@binary.encode_module(input).unwrap(), saved)
      assert_eq(output.name_sec, input.name_sec)
      if policy == CompilerFactUsePolicy::trust_assertions() {
        assert_true(output.compiler_fact_custom_section is None)
        let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
        assert_false(body.any(instr => instr is @lib.I32Eq))
        assert_true(body.contains(@lib.Instruction::i32_const(@lib.I32(1))))
        assert_true(
          body.contains(@lib.Instruction::call(@lib.FuncIdx::new(0U))),
        )
      } else {
        assert_eq(
          output.compiler_fact_custom_section,
          input.compiler_fact_custom_section,
        )
      }
      assert_true(
        @validate.validate_module(
          @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap(),
        )
        is Ok(_),
      )
    }
  }
}

///|
test "O4z caught rollback applies mixed explicit passes in their original order" {
  let input = pass_test_module_from_wat(
    "(module (tag $e) (func (export \"run\") (result i32) i32.const 3 i32.const 4 i32.add) (func (block $handler (try_table (catch_all $handler) (throw $e)))))",
  ).with_name_sec(
    @lib.NameSec::new(module_name=Some(@lib.Name::from_string("strip-me"))),
  )
  let saved = @binary.encode_module(input).unwrap()
  let options = HotPipelineOptions::new(optimize_level=4, shrink_level=4)
  for
    requested in [
      ["precompute", "optimize", "strip-debug"],
      ["optimize", "precompute", "shrink", "strip-debug"],
      ["strip-debug", "shrink", "precompute"],
    ] {
    let explicit = requested.filter(name => {
      name != "optimize" && name != "shrink"
    })
    let expected = run_hot_pipeline(input, options, explicit).unwrap()
    let output = run_hot_pipeline(input, options, requested).unwrap()
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(expected).unwrap(),
    )
    assert_true(output.name_sec is None)
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    @debug.assert_eq(body, [@lib.Instruction::i32_const(@lib.I32(7))])
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "O4z caught mixed rollback retains trusted facts before explicit cleanup" {
  let input = o4z_caught_rollback_value_fact(o4z_caught_rollback_fixture())
  let original = @binary.encode_module(input).unwrap()
  let options = HotPipelineOptions::new(
    optimize_level=4,
    shrink_level=4,
    compiler_fact_policy=CompilerFactUsePolicy::trust_assertions(),
  )
  let expected = run_hot_pipeline(input, options, ["strip-debug"]).unwrap()
  for requested in [["optimize", "strip-debug"], ["strip-debug", "shrink"]] {
    let output = run_hot_pipeline(input, options, requested).unwrap()
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(expected).unwrap(),
    )
    assert_true(output.compiler_fact_custom_section is None)
    assert_true(output.name_sec is None)
    assert_eq(@binary.encode_module(input).unwrap(), original)
  }
}

///|
test "O4z caught rollback preserves expansion errors before preparation" {
  let input = o4z_caught_rollback_value_fact(o4z_caught_rollback_fixture())
  let saved = @binary.encode_module(input).unwrap()
  let options = HotPipelineOptions::new(
    optimize_level=4,
    shrink_level=4,
    compiler_fact_policy=CompilerFactUsePolicy::trust_assertions(),
  )
  for requested in [["optimize", "no-such-pass"], ["no-such-pass", "shrink"]] {
    assert_eq(
      run_hot_pipeline(input, options, requested),
      Err("unknown pass flag no-such-pass"),
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
  for name in ["reorder-functions", "no-inline"] {
    let direct = run_hot_pipeline(input, options, [name])
    let mixed = run_hot_pipeline(input, options, ["optimize", name])
    assert_true(direct is Err(_))
    assert_eq(mixed, direct)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "O4z caught rollback keeps the final validation option for intentionally invalid input" {
  let base = o4z_caught_rollback_fixture()
  let original_funcs = base.code_sec.unwrap().0
  let funcs = original_funcs.copy()
  // Keep the invalid body externally reachable so preset DCE cannot remove it
  // before the old hot-pass validation path reports the error.
  funcs[1] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(999U))]),
  )
  let input = base.with_code_sec(@lib.CodeSec::new(funcs))
  assert_true(@validate.validate_module(input) is Err(_))
  let saved = @binary.encode_module(input).unwrap()
  for validate_final_module in [false, true] {
    let result = run_hot_pipeline(
      input,
      HotPipelineOptions::new(
        optimize_level=4,
        shrink_level=4,
        validate_final_module~,
      ),
      ["optimize"],
    )
    if validate_final_module {
      assert_true(result is Err(_))
    } else {
      // Final validation is intentionally disabled. The existing lift-error
      // fallback returns this invalid input unchanged instead of rejecting it.
      let output = result.unwrap()
      assert_eq(@binary.encode_module(output).unwrap(), saved)
    }
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "caught rollback remains limited to O4z presets and caught handlers" {
  let input = pass_test_module_from_wat(
    "(module (tag $e) (func (export \"run\") (result i32) i32.const 3 i32.const 4 i32.add) (func (block $handler (try_table (catch_all $handler) (throw $e)))))",
  ).with_name_sec(
    @lib.NameSec::new(module_name=Some(@lib.Name::from_string("debug-name"))),
  )
  let saved = @binary.encode_module(input).unwrap()
  for levels in [(3, 4), (4, 3)] {
    let (optimize_level, shrink_level) = levels
    let output = run_hot_pipeline(
      input,
      HotPipelineOptions::new(optimize_level~, shrink_level~),
      ["optimize"],
    ).unwrap()
    assert_true(output.name_sec is None)
  }
  let direct = run_hot_pipeline(
    input,
    HotPipelineOptions::new(optimize_level=4, shrink_level=4),
    ["precompute"],
  ).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = direct.code_sec.unwrap().0[0]
  @debug.assert_eq(body, [@lib.Instruction::i32_const(@lib.I32(7))])
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  let uncaught = pass_test_module_from_wat(
    "(module (tag $e) (func (export \"run\") (try_table (throw $e))))",
  ).with_name_sec(
    @lib.NameSec::new(
      module_name=Some(@lib.Name::from_string("uncaught-debug")),
    ),
  )
  assert_false(run_hot_pipeline_module_has_caught_try_table(uncaught))
  let uncaught_out = run_hot_pipeline(
    uncaught,
    HotPipelineOptions::new(optimize_level=4, shrink_level=4),
    ["optimize"],
  ).unwrap()
  assert_true(uncaught_out.name_sec is None)
}
