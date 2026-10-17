///|
fn raw_nop_rewrite_compare(
  body : String,
  expected_rewrite_lifts~ : Int32 = 0,
) -> Unit raise {
  let input = pass_test_module_from_wat(
    "(module (func $h (param i32 i64) (result i32) \{body}) (func (export \"run\") (param i32) (result i32) local.get 0 i64.const 9 call $h))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  for closed_world in [false, true] {
    let analysis = [0]
    let rewrite = [0]
    let actual = dae2_run_module_pass(
      input,
      closed_world,
      analysis_lifts=Some(analysis),
      rewrite_lifts=Some(rewrite),
      stack_suffix_rewrite=false,
    ).unwrap()
    let expected = dae2_run_module_pass(
      input,
      closed_world,
      raw_analysis=false,
      raw_rewrite=false,
    ).unwrap()
    @validate.validate_module(actual).unwrap()
    assert_eq(actual.type_sec, expected.type_sec)
    assert_eq(actual.func_sec, expected.func_sec)
    assert_eq(actual.code_sec, expected.code_sec)
    assert_eq(
      @binary.encode_module(actual).unwrap(),
      @binary.encode_module(expected).unwrap(),
    )
    let context = @ir.hot_module_context_from_module(actual)
    assert_eq(
      @ir.hot_module_resolve_func_type(context, @lib.FuncIdx::new(0U)),
      Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
    )
    assert_eq(analysis[0], 0)
    assert_eq(rewrite[0], expected_rewrite_lifts)
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 raw flat replay omits Nops while removing a real parameter" {
  raw_nop_rewrite_compare("nop local.get 0 nop")
}

///|
test "DAE2 raw loop replay omits Nops with exact HOT body bytes" {
  raw_nop_rewrite_compare("loop nop end local.get 0")
}

///|
test "DAE2 raw If replay omits Nops without shifting source writes" {
  let body = "(local i32) local.get 0 if nop local.get 0 local.set 2 nop else nop i32.const 7 local.set 2 nop end local.get 2"
  let input = pass_test_module_from_wat(
    "(module (func $h (param i32 i64) (result i32) \{body}) (func (export \"run\") (param i32) (result i32) local.get 0 i64.const 9 call $h))",
  )
  // The existing full journal differential checks lexical write coordinates,
  // including Nops on both sides of each source write.
  for closed_world in [false, true] {
    let raw_writes = []
    let hot_writes = []
    let (actual, count) = raw_conditional_boundary_bits(
      input,
      true,
      closed_world~,
      write_demands=Some(raw_writes),
    )
    let (expected, _) = raw_conditional_boundary_bits(
      input,
      false,
      closed_world~,
      write_demands=Some(hot_writes),
    )
    assert_eq(actual, expected)
    assert_eq(raw_writes, hot_writes)
    assert_eq(count, 2)
  }
  raw_nop_rewrite_compare(body)
}

///|
test "DAE2 raw branch replay omits Nops while preserving dead-tail HOT fallback" {
  raw_nop_rewrite_compare(
    "block $out loop nop end local.get 0 br_if $out nop end local.get 0",
  )
  // Intentionally unsupported by direct replay: preserve the existing HOT
  // replay for a dead Nop after unconditional br. Analysis still stays raw.
  raw_nop_rewrite_compare(
    "block $out loop nop end br $out nop end local.get 0",
    expected_rewrite_lifts=1,
  )
}
