///|
fn passes_test_module_from_wat(text : String) -> @lib.Module {
  match @wast.wast_to_binary_module(text, filename="passes-test.wat") {
    Ok(mod) => mod
    Err(err) => abort("unexpected test fixture parse failure: \{err}")
  }
}

///|
test "run_hot_pipeline applies optimize preset through the hot pass manager" {
  let input = passes_test_module_from_wat(
    "(module (func (result i32) nop i32.const 7))",
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize"]) {
    Ok(mod) => mod
    Err(err) => fail("expected optimize pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected optimized module to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("nop"))
  assert_true(pretty.contains("i32.const"))
  assert_true(pretty.contains("I32(7)"))
}

///|
test "run_hot_pipeline emits trace markers for hot passes" {
  let input = passes_test_module_from_wat(
    "(module (func (result i32) nop i32.const 9))",
  )
  let trace : Array[String] = []
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["vacuum"],
    ) {
    Ok(mod) => mod
    Err(err) => fail("expected traced hot pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected traced module to validate, got \{err}")
  }
  assert_true(trace.any(fn(line) { line.contains("pass[vacuum]:start") }))
  assert_true(trace.any(fn(line) { line.contains("pass[vacuum]:done") }))
}
