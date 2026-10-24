///|
fn rule_recipe_activation_generate(
  profile_name : String,
  seed : UInt64,
) -> @lib.Module raise {
  let profile = @validate.gen_valid_profile_by_name(profile_name).unwrap()
  let generated = @validate.gen_valid_module_result_from_seed(
    seed,
    @validate.GenValidConfig::for_profile(profile),
  ).unwrap()
  @validate.validate_module(generated.wasm_module).unwrap()
  let encoded = @binary.encode_module(generated.wasm_module).unwrap()
  let decoded = @binary.decode_module(encoded).unwrap()
  @validate.validate_module(decoded).unwrap()
  decoded
}

///|
fn rule_recipe_body_has_if(body : Array[@lib.Instruction]) -> Bool {
  body.any(fn(instruction) { instruction is @lib.If(_, _, _) })
}

///|
fn rule_recipe_body_if_type(body : Array[@lib.Instruction]) -> @lib.BlockType? {
  for instruction in body {
    match instruction {
      @lib.If(block_type, _, _) => return Some(block_type)
      _ => ()
    }
  }
  None
}

///|
test "OI add-zero recipe removes only the positive target boundary" {
  for seed = 0UL; seed < 32UL; seed = seed + 1UL {
    let positive = rule_recipe_activation_generate(
      "rule-recipe-oi-i32-add-zero-positive", seed,
    )
    let positive_output = run_hot_pipeline(
      positive,
      HotPipelineOptions::new(),
      ["optimize-instructions"],
    ).unwrap()
    @validate.validate_module(positive_output).unwrap()
    let @lib.Func(_, @lib.Expr(positive_body)) = positive_output.code_sec.unwrap().0[0]
    assert_false(positive_body[positive_body.length() - 1] is @lib.I32Add)

    let near_miss = rule_recipe_activation_generate(
      "rule-recipe-oi-i32-add-zero-near-miss", seed,
    )
    let near_miss_output = run_hot_pipeline(
      near_miss,
      HotPipelineOptions::new(),
      ["optimize-instructions"],
    ).unwrap()
    @validate.validate_module(near_miss_output).unwrap()
    let @lib.Func(_, @lib.Expr(near_body)) = near_miss_output.code_sec.unwrap().0[0]
    assert_true(near_body[near_body.length() - 2] is @lib.I32Const(@lib.I32(1)))
    assert_true(near_body[near_body.length() - 1] is @lib.I32Add)
  }
}

///|
test "DAE2 recipe removes an unused parameter and typed-if argument only in the positive" {
  for seed = 0UL; seed < 32UL; seed = seed + 1UL {
    let positive = rule_recipe_activation_generate(
      "rule-recipe-dae2-unused-typed-if-argument-positive", seed,
    )
    let positive_output = run_hot_pipeline(
      positive,
      HotPipelineOptions::new(),
      ["dae2"],
    ).unwrap()
    @validate.validate_module(positive_output).unwrap()
    let positive_types = dae_snapshot_function_types(
      positive_output,
      positive_output.func_sec.unwrap().0,
    )
    let (positive_params, positive_results) = match positive_types[0] {
      Some(@lib.FuncType(params, results)) => (params, results)
      None => fail("missing positive callee signature")
    }
    @debug.assert_eq(positive_params, [])
    @debug.assert_eq(positive_results, [@lib.ValType::i32()])
    let @lib.Func(_, @lib.Expr(positive_callee)) = positive_output.code_sec.unwrap().0[0]
    let @lib.Func(_, @lib.Expr(positive_caller)) = positive_output.code_sec.unwrap().0[1]
    assert_true(positive_callee[0] is @lib.I32Const(_))
    @debug.assert_eq(
      rule_recipe_body_if_type(positive_caller),
      Some(@lib.BlockType::void_()),
    )
    assert_true(
      positive_caller[positive_caller.length() - 1]
      is @lib.Call(@lib.FuncIdx(0U)),
    )

    let near_miss = rule_recipe_activation_generate(
      "rule-recipe-dae2-unused-typed-if-argument-near-miss", seed,
    )
    let near_miss_output = run_hot_pipeline(
      near_miss,
      HotPipelineOptions::new(),
      ["dae2"],
    ).unwrap()
    @validate.validate_module(near_miss_output).unwrap()
    let near_types = dae_snapshot_function_types(
      near_miss_output,
      near_miss_output.func_sec.unwrap().0,
    )
    let (near_params, near_results) = match near_types[0] {
      Some(@lib.FuncType(params, results)) => (params, results)
      None => fail("missing near-miss callee signature")
    }
    @debug.assert_eq(near_params, [@lib.ValType::i32()])
    @debug.assert_eq(near_results, [@lib.ValType::i32()])
    let @lib.Func(_, @lib.Expr(near_callee)) = near_miss_output.code_sec.unwrap().0[0]
    let @lib.Func(_, @lib.Expr(near_caller)) = near_miss_output.code_sec.unwrap().0[1]
    assert_true(near_callee[0] is @lib.LocalGet(@lib.LocalIdx(0U)))
    assert_true(rule_recipe_body_has_if(near_caller))
    @debug.assert_eq(
      rule_recipe_body_if_type(near_caller),
      Some(@lib.BlockType::val_type(@lib.ValType::i32())),
    )
    assert_true(
      near_caller[near_caller.length() - 1] is @lib.Call(@lib.FuncIdx(0U)),
    )
  }
}
