///|
fn raw_dead_drop_module(body : String, result_used : Bool) -> @lib.Module {
  let result = if result_used { "(result i32)" } else { "" }
  let discard = if result_used { "" } else { "drop" }
  // A one-shot void loop selects the forward planner, which owns this slice.
  // Keep it in the original body for the complete forced-HOT comparison.
  pass_test_module_from_wat(
    "(module (type $one (func (param i32) (result i32))) (memory 1) (func $h (param i32 i32 i32 i64) (result i32) (local i32) loop nop end \{body}) (func (export \"run\") (param i32 i32 i32) \{result} local.get 0 local.get 1 local.get 2 i64.const 9 call $h \{discard}))",
  )
}

///|
fn raw_dead_drop_compare(input : @lib.Module) -> Unit raise {
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
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
    // Compare every function/type boundary and every lexical source write,
    // including empty journals. Dead Drops must add neither demand nor writes.
    assert_eq(actual, expected)
    assert_eq(raw_writes, hot_writes)
    assert_eq(count, input.code_sec.unwrap().0.length())
    let analysis = [0]
    let rewrites = [0]
    let actual = dae2_run_module_pass(
      input,
      closed_world,
      raw_rewrite=false,
      analysis_lifts=Some(analysis),
      rewrite_lifts=Some(rewrites),
    ).unwrap()
    let expected = dae2_run_module_pass(
      input,
      closed_world,
      raw_analysis=false,
      raw_rewrite=false,
    ).unwrap()
    @validate.validate_module(actual).unwrap()
    assert_eq(
      @binary.encode_module(actual).unwrap(),
      @binary.encode_module(expected).unwrap(),
    )
    // Removed h parameters force HOT replay. A boundary mismatch must not
    // silently restart the whole module through HOT analysis.
    assert_true(rewrites[0] > 0)
    assert_eq(analysis[0], 0)
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 raw dead Drops preserve Return Br and trap prefix demand" {
  for
    body in [
      "local.get 0 if local.get 1 return drop nop unreachable end local.get 2", "local.get 0 if local.get 2 local.get 1 return drop drop nop end local.get 2",
      "local.get 0 if unreachable drop nop drop end local.get 2", "block $out local.get 0 if local.get 1 br $out drop nop end local.get 2 local.set 4 end local.get 4",
      "block $out (result i32) local.get 1 local.get 0 br_table $out $out drop nop end",
    ] {
    for result_used in [false, true] {
      raw_dead_drop_compare(raw_dead_drop_module(body, result_used))
    }
  }
}

///|
test "DAE2 raw dead Drops discard nonreturning scalar control result slots exactly as HOT" {
  for
    body in [
      "local.get 0 if block (result i32) local.get 1 return end drop else local.get 2 return end unreachable",
      "local.get 0 if loop (result i32) local.get 1 return end drop else local.get 2 return end unreachable",
      "local.get 1 local.set 4 block $out local.get 0 if (result i32) local.get 2 local.set 4 br $out else br $out end drop end local.get 4",
    ] {
    for result_used in [false, true] {
      raw_dead_drop_compare(raw_dead_drop_module(body, result_used))
    }
  }
}

///|
test "DAE2 raw dead Drops preserve typed loop entries and conditional backedge payloads" {
  for
    body in [
      "local.get 1 loop (type $one) local.get 0 if local.get 2 return end return end drop unreachable",
      "local.get 1 loop $again (type $one) local.get 0 br_if $again drop local.get 2 return end drop unreachable",
    ] {
    for result_used in [false, true] {
      raw_dead_drop_compare(raw_dead_drop_module(body, result_used))
    }
  }
}

///|
test "DAE2 raw dead Drops intentionally leave concrete trap prefixes and extra br_table values on HOT" {
  for
    body in [
      "local.get 0 if local.get 1 unreachable drop end local.get 2", "block $out (result i32) local.get 2 local.get 1 local.get 0 br_table $out $out drop end",
    ] {
    for result_used in [false, true] {
      let input = raw_dead_drop_module(body, result_used)
      // These preexisting prefix contracts need a separate concrete-stack
      // model. This change must not broaden them while handling dead Drops.
      raw_conditional_compare_boundaries(input, 1)
    }
  }
}

///|
test "DAE2 raw dead Drops intentionally keep materialized dead calls and their parameter demand on HOT" {
  let input = pass_test_module_from_wat(
    "(module (import \"e\" \"observe\" (func $observe (param i32))) (func $h (param i32 i32 i32 i64) (result i32) loop nop end local.get 0 if local.get 1 return local.get 2 call $observe end local.get 1) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
  )
  raw_conditional_compare_boundaries(input, 1)
  for closed_world in [false, true] {
    let output = dae2_run_module_pass(input, closed_world).unwrap()
    assert_eq(
      @ir.hot_module_resolve_func_type(
        @ir.hot_module_context_from_module(output),
        @lib.FuncIdx::new(1U),
      ),
      Some(
        @lib.FuncType::new(
          [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
          [@lib.ValType::i32()],
        ),
      ),
    )
  }
}
