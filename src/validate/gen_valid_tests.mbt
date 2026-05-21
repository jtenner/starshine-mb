///|
test "gen_valid_module_result reports success diagnostics" {
  let config = GenValidConfig::natural_default()
  let generated = match
    gen_valid_module_result(@splitmix.new(seed=0x5eedUL), config) {
    Ok(v) => v
    Err(failure) =>
      fail(
        "expected gen-valid success, got \{failure.validation_error_message}",
      )
  }
  assert_true(generated.attempts >= 1)
  @debug.assert_eq(generated.config_label, "natural")
  @debug.assert_eq(generated.config, config)
  @debug.assert_eq(generated.facts.mode, Natural)
  match validate_module(generated.wasm_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected generated module to validate, got \{validation_error_message(err)}",
      )
  }
}

///|
test "gen_valid named profiles expose stable labels and compatibility aliases" {
  @debug.assert_eq(
    gen_valid_profile_name(CoverageForcedAllFeaturesProfile),
    "coverage-forced-all-features",
  )
  @debug.assert_eq(
    GenValidConfig::for_profile(NaturalSmallProfile).mode,
    Natural,
  )
  @debug.assert_eq(
    GenValidConfig::for_profile(CoverageForcedPortableProfile),
    GenValidConfig::portable_coverage_forced_default(),
  )
  @debug.assert_eq(
    GenValidConfig::for_profile(BinaryenOraclePortableProfile),
    GenValidConfig::binaryen_oracle_coverage_forced_default(),
  )
  @debug.assert_eq(
    GenValidConfig::for_profile(PassFuzzStressProfile),
    GenValidConfig::binaryen_oracle_coverage_forced_default(),
  )
  @debug.assert_eq(
    gen_valid_config_label(GenValidConfig::for_profile(ValidatorStressProfile)),
    "validator-stress",
  )
  let looked_up = match gen_valid_profile_by_name("Coverage Forced Portable") {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(looked_up, CoverageForcedPortableProfile)
  match GenValidConfig::profile("not-a-profile") {
    Ok(_) => fail("expected unknown gen-valid profile to fail")
    Err(msg) => {
      assert_true(msg.contains("unknown gen-valid profile"))
      assert_true(msg.contains("natural-small"))
      assert_true(msg.contains("binaryen-oracle-portable"))
    }
  }
}

///|
test "gen_valid_module_with_config remains deterministic compatibility wrapper" {
  let config = GenValidConfig::binaryen_oracle_coverage_forced_default()
  let generated = match
    gen_valid_module_result(@splitmix.new(seed=0x51eedUL), config) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  let wrapped = gen_valid_module_with_config(
    @splitmix.new(seed=0x51eedUL),
    config,
  )
  @debug.assert_eq(wrapped, generated.wasm_module)
  @debug.assert_eq(generated.config_label, "binaryen-oracle-coverage-forced")
}

///|
fn gen_valid_test_count_local_set_instrs(instrs : Array[Instruction]) -> Int {
  let mut count = 0
  for instr in instrs {
    count += match instr {
      LocalSet(_) => 1
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        gen_valid_test_count_local_set_instrs(body)
      If(_, then_body, else_body) => {
        let else_count = match else_body {
          Some(body) => gen_valid_test_count_local_set_instrs(body)
          None => 0
        }
        gen_valid_test_count_local_set_instrs(then_body) + else_count
      }
      _ => 0
    }
  }
  count
}

///|
fn gen_valid_test_has_i64_const_local_set(instrs : Array[Instruction]) -> Bool {
  for i = 0; i + 1 < instrs.length(); i = i + 1 {
    match (instrs[i], instrs[i + 1]) {
      (I64Const(_), LocalSet(_)) => return true
      _ => ()
    }
  }
  for instr in instrs {
    match instr {
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_has_i64_const_local_set(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_has_i64_const_local_set(then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_has_i64_const_local_set(body) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_module_local_set_count(mod_ : Module) -> Int {
  match mod_.code_sec {
    Some(CodeSec(funcs)) => {
      let mut count = 0
      for func in funcs {
        let Func(_, Expr(instrs)) = func
        count += gen_valid_test_count_local_set_instrs(instrs)
      }
      count
    }
    None => 0
  }
}

///|
fn gen_valid_test_module_has_i64_const_local_set(mod_ : Module) -> Bool {
  match mod_.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        let Func(_, Expr(instrs)) = func
        if gen_valid_test_has_i64_const_local_set(instrs) {
          return true
        }
      }
    None => ()
  }
  false
}

///|
test "control-heavy profile uses typed GenValid body generator slice" {
  let config = GenValidConfig::for_profile(ControlHeavyProfile)
  assert_true(config.features.allow_typed_body_generator)
  let generated = match
    gen_valid_module_result(@splitmix.new(seed=0x71002UL), config) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  match validate_module(generated.wasm_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected typed-body generated module to validate, got \{validation_error_message(err)}",
      )
  }
  assert_true(generated.facts.has_branch_heavy_control)
  assert_true(generated.facts.has_local_tee)
  assert_true(generated.facts.exact_opcode_counts.local_tee > 0)
  assert_true(
    gen_valid_test_module_local_set_count(generated.wasm_module) > 0,
    msg="typed body generator should emit stack-planned local.set coverage",
  )
  assert_true(
    gen_valid_test_module_has_i64_const_local_set(generated.wasm_module),
    msg="typed body generator should widen beyond the original i32-only local slice",
  )
}
