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
test "fuzz package can consume function subtype variance invalid AST strategy" {
  let strategy = match
    @validate.validate_invalid_ast_strategy_by_stable_id(
      "invalid-subtype-func-variance",
    ) {
    Some(spec) => spec.id
    None => fail("expected function subtype variance invalid strategy to exist")
  }
  let generated = match
    @validate.gen_invalid_ast_generate(
      @splitmix.new(seed=0x1020a3UL),
      @validate.GenInvalidAstParams::minimal_seed(strategy),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected function subtype variance base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected function subtype variance invalid module to fail")
    Err(_) => ()
  }
}

///|
test "fuzz package can consume descriptor field ref-type invalid AST strategy" {
  let strategy = match
    @validate.validate_invalid_ast_strategy_by_stable_id(
      "invalid-descriptor-field-ref-type",
    ) {
    Some(spec) => spec.id
    None => fail("expected descriptor field ref-type invalid strategy to exist")
  }
  let generated = match
    @validate.gen_invalid_ast_generate(
      @splitmix.new(seed=0x1020a4UL),
      @validate.GenInvalidAstParams::minimal_seed(strategy),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected descriptor field ref-type base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected descriptor field ref-type invalid module to fail")
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

///|
test "fuzz package can consume datacount active/passive mismatch invalid AST strategy" {
  let strategy = match
    @validate.validate_invalid_ast_strategy_by_stable_id(
      "datacount-active-passive-mismatch",
    ) {
    Some(spec) => spec.id
    None =>
      fail(
        "expected datacount active/passive mismatch invalid strategy to exist",
      )
  }
  let generated = match
    @validate.gen_invalid_ast_generate(
      @splitmix.new(seed=0x1020d5UL),
      @validate.GenInvalidAstParams::minimal_seed(strategy),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected datacount active/passive base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected datacount active/passive invalid module to fail")
    Err(_) => ()
  }
}

///|
test "fuzz package can consume call_indirect table element type invalid AST strategy" {
  let strategy = match
    @validate.validate_invalid_ast_strategy_by_stable_id(
      "invalid-function-body-call-indirect-table-element-type",
    ) {
    Some(spec) => spec.id
    None => fail("expected call_indirect table element type strategy to exist")
  }
  let generated = match
    @validate.gen_invalid_ast_generate(
      @splitmix.new(seed=0x1020e2UL),
      @validate.GenInvalidAstParams::minimal_seed(strategy),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected call_indirect table element type base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected call_indirect table element type invalid module to fail")
    Err(_) => ()
  }
}

///|
test "fuzz package can consume GC br_on_non_null invalid AST strategy" {
  let strategy = match
    @validate.validate_invalid_ast_strategy_by_stable_id(
      "invalid-function-body-br-on-non-null-payload-mismatch",
    ) {
    Some(spec) => spec.id
    None => fail("expected br_on_non_null invalid strategy to exist")
  }
  let generated = match
    @validate.gen_invalid_ast_generate(
      @splitmix.new(seed=0x1020c7UL),
      @validate.GenInvalidAstParams::minimal_seed(strategy),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected br_on_non_null base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected br_on_non_null invalid module to fail")
    Err(_) => ()
  }
}
