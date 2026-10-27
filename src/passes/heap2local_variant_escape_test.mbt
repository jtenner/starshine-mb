///|
test "heap2local preserves result-if escapes inside constructor operands" {
  let input = pass_test_module_from_wat(
    "(module (type $S (struct (field i32) (field i32))) " +
    "(func (export \"run\") (param $select i32) (param $escape i32) (result i32 i32) " +
    "(local $x (ref null $S)) " +
    "(local.set $x (if $choose (result (ref $S)) (local.get $select) " +
    "(then (struct.new $S " +
    "(block (result i32) " +
    "(drop (br_if $choose (struct.new $S (i32.const 99) (i32.const 100)) " +
    "(local.get $escape))) (i32.const 10)) (i32.const 20))) " +
    "(else (struct.new $S (i32.const 11) (i32.const 21))))) " +
    "(struct.get $S 0 (local.get $x)) (struct.get $S 1 (local.get $x))))",
  )
  let output = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["heap2local"]) {
    Ok(output) => output
    Err(error) => fail(error)
  }
  assert_true(@validate.validate_module(output) is Ok(_))
  assert_eq(audit_count(audit_body(output), fn(i) { i is @lib.BrIf(_) }), 1)
  let bytes = @binary.encode_module(output).unwrap()
  let decoded = @binary.decode_module(bytes).unwrap()
  assert_true(@validate.validate_module(decoded) is Ok(_))
}

///|
fn h2l_variant_escape_test_roundtrip(wat : String) -> Unit raise {
  let input = pass_test_module_from_wat(wat)
  assert_true(@validate.validate_module(input) is Ok(_))
  let output = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["heap2local"]) {
    Ok(output) => output
    Err(error) => fail(error)
  }
  assert_true(@validate.validate_module(output) is Ok(_))
  assert_eq(
    audit_count(audit_body(output), fn(i) {
      i is @lib.BrIf(_) || i is @lib.BrTable(_, _)
    }),
    1,
  )
  let decoded = @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap()
  assert_true(@validate.validate_module(decoded) is Ok(_))
}

///|
test "heap2local preserves tee variant result-if escape labels" {
  h2l_variant_escape_test_roundtrip(
    "(module (type $S (struct (field i32) (field i32))) " +
    "(func (export \"run\") (param $select i32) (param $escape i32) (result i32 i32) " +
    "(local $x (ref null $S)) " +
    "(struct.get $S 0 (local.tee $x " +
    "(ref.as_non_null (if $choose (result (ref $S)) (local.get $select) " +
    "(then (struct.new $S (block (result i32) " +
    "(drop (br_if $choose (struct.new $S (i32.const 99) (i32.const 100)) " +
    "(local.get $escape))) (i32.const 10)) (i32.const 20))) " +
    "(else (struct.new $S (i32.const 11) (i32.const 21))))))) " +
    "(struct.get $S 1 (local.get $x))))",
  )
}

///|
test "heap2local preserves typed source block escape labels" {
  // A reference-valued branch to this wrapper has no scalar transfer form.
  h2l_variant_escape_test_roundtrip(
    "(module (type $S (struct (field i32) (field i32))) " +
    "(func (export \"run\") (param $select i32) (param $escape i32) (result i32 i32) " +
    "(local $x (ref null $S)) " +
    "(local.set $x (block $source (result (ref $S)) " +
    "(if (result (ref $S)) (local.get $select) " +
    "(then (struct.new $S (block (result i32) " +
    "(drop (br_if $source (struct.new $S (i32.const 99) (i32.const 100)) " +
    "(local.get $escape))) (i32.const 10)) (i32.const 20))) " +
    "(else (struct.new $S (i32.const 11) (i32.const 21)))))) " +
    "(struct.get $S 0 (local.get $x)) (struct.get $S 1 (local.get $x))))",
  )
}

///|
test "heap2local preserves br-table targets in variant constructor operands" {
  h2l_variant_escape_test_roundtrip(
    "(module (type $S (struct (field i32) (field i32))) " +
    "(func (export \"run\") (param $select i32) (param $escape i32) (result i32 i32) " +
    "(local $x (ref null $S)) " +
    "(local.set $x (if $choose (result (ref $S)) (local.get $select) " +
    "(then (struct.new $S (block (result i32) " +
    "(br_table $choose $choose (struct.new $S (i32.const 99) (i32.const 100)) " +
    "(local.get $escape))) (i32.const 20))) " +
    "(else (struct.new $S (i32.const 11) (i32.const 21))))) " +
    "(struct.get $S 0 (local.get $x)) (struct.get $S 1 (local.get $x))))",
  )
}

///|
test "heap2local scalarizes variants with retained operand-block branch targets" {
  let input = pass_test_module_from_wat(
    "(module (type $S (struct (field i32) (field i32))) " +
    "(func (export \"run\") (param $select i32) (param $escape i32) (result i32 i32) " +
    "(local $x (ref null $S)) " +
    "(local.set $x (if (result (ref $S)) (local.get $select) " +
    "(then (struct.new $S (block $field (result i32) " +
    "(drop (br_if $field (i32.const 99) (local.get $escape))) " +
    "(i32.const 10)) (i32.const 20))) " +
    "(else (struct.new $S (i32.const 11) (i32.const 21))))) " +
    "(struct.get $S 0 (local.get $x)) (struct.get $S 1 (local.get $x))))",
  )
  let output = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["heap2local"]) {
    Ok(output) => output
    Err(error) => fail(error)
  }
  assert_true(@validate.validate_module(output) is Ok(_))
  let decoded = @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap()
  assert_true(@validate.validate_module(decoded) is Ok(_))
  assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.StructNew(_) }),
    0,
  )
  assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.StructGet(_, _) }),
    0,
  )
  assert_eq(audit_count(audit_body(output), fn(i) { i is @lib.BrIf(_) }), 1)
}
