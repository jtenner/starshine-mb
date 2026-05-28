///|
test "fuzz package can consume public gen-invalid AST generation API" {
  let strategy = match
    @validate.validate_invalid_ast_strategy_by_stable_id(
      "invalid-start-signature",
    ) {
    Some(spec) => spec.id
    None => fail("expected invalid-start-signature strategy to exist")
  }
  let generated = match
    @validate.gen_invalid_ast_generate(
      @splitmix.new(seed=0x5eedUL),
      @validate.GenInvalidAstParams::new(strategy),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected public gen-invalid base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected public gen-invalid mutated module to fail validation")
    Err(_) => ()
  }
}

///|
test "fuzz package can consume public natural-seed gen-invalid AST API" {
  let strategy = match
    @validate.validate_invalid_ast_strategy_by_stable_id(
      "duplicate-export-name",
    ) {
    Some(spec) => spec.id
    None => fail("expected duplicate-export-name strategy to exist")
  }
  let generated = match
    @validate.gen_invalid_ast_generate(
      @splitmix.new(seed=0x5eedUL),
      @validate.GenInvalidAstParams::natural_seed(strategy),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected public natural-seed base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected natural-seed gen-invalid mutated module to fail")
    Err(_) => ()
  }
}

///|
test "fuzz package can consume GC struct.new_default invalid AST strategy" {
  let strategy = match
    @validate.validate_invalid_ast_strategy_by_stable_id(
      "invalid-function-body-struct-new-default-field-type",
    ) {
    Some(spec) => spec.id
    None => fail("expected struct.new_default invalid strategy to exist")
  }
  let generated = match
    @validate.gen_invalid_ast_generate(
      @splitmix.new(seed=0x1020c1UL),
      @validate.GenInvalidAstParams::minimal_seed(strategy),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected struct.new_default base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected struct.new_default invalid module to fail")
    Err(_) => ()
  }
}
