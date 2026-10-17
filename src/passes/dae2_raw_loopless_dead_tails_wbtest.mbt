///|
fn raw_loopless_dead_tail_compare(
  body : String,
  conditional_planner~ : Bool = true,
) -> Unit raise {
  for result_used in [false, true] {
    let result = if result_used { "(result i32)" } else { "" }
    let discard = if result_used { "" } else { "drop" }
    let input = pass_test_module_from_wat(
      "(module (func $h (param i32 i32 i32 i64) (result i32) (local i32) \{body}) (func (export \"run\") (param i32 i32 i32) \{result} local.get 0 local.get 1 local.get 2 i64.const 9 call $h \{discard}))",
    )
    let @lib.Func(_, @lib.Expr(instructions)) = input.code_sec.unwrap().0[0]
    // In particular, no one-shot Loop may route these conditional positives
    // around Dae2RawControlState::body and conceal its dead-tail rejection.
    assert_eq(
      dae2_raw_conditional_qualified(
        instructions,
        Some(@ir.hot_module_context_from_module(input)),
      ),
      conditional_planner,
    )
    raw_dead_drop_compare(input)
    for closed_world in [false, true] {
      let output = dae2_run_module_pass(input, closed_world, raw_rewrite=false).unwrap()
      let @lib.FuncType(params, _) = @ir.hot_module_resolve_func_type(
        @ir.hot_module_context_from_module(output),
        @lib.FuncIdx::new(0U),
      ).unwrap()
      assert_true(params.length() < 4)
      assert_true(!params.contains(@lib.ValType::i64()))
    }
  }
}

///|
test "DAE2 loopless conditional Return tails preserve complete source-write demand" {
  raw_loopless_dead_tail_compare(
    "local.get 1 local.set 4 local.get 0 if local.get 2 local.set 4 local.get 1 return drop nop unreachable else local.get 2 local.set 4 end local.get 4",
  )
}

///|
test "DAE2 loopless conditional trap tails preserve surviving writes and result demand" {
  raw_loopless_dead_tail_compare(
    "local.get 1 local.set 4 local.get 0 if unreachable drop nop unreachable else local.get 2 local.set 4 end local.get 4",
  )
}

///|
test "DAE2 loopless dead tails preserve branch labels and nonreturning scalar slots" {
  // Branches select the forward planner without adding a Loop. Its existing
  // narrow guard must keep the same demand and exact HOT replay bytes.
  raw_loopless_dead_tail_compare(
    "block $out local.get 0 if local.get 1 br $out drop nop end local.get 2 local.set 4 end local.get 4",
    conditional_planner=false,
  )
  // This separate loopless shape selects the conditional planner. The scalar
  // Block cannot return, but HOT can still materialize its dropped result slot.
  raw_loopless_dead_tail_compare(
    "local.get 0 if block (result i32) local.get 1 return drop nop end drop nop else local.get 2 return end unreachable",
  )
}

///|
test "DAE2 loopless concrete dead producers intentionally use HOT and still remove parameters" {
  let input = pass_test_module_from_wat(
    "(module (import \"e\" \"observe\" (func $observe (param i32))) (func $h (param i32 i32 i32 i64) (result i32) (local i32) local.get 1 local.set 4 local.get 0 if local.get 1 return local.get 2 call $observe end local.get 4) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(instructions)) = input.code_sec.unwrap().0[0]
  assert_true(
    dae2_raw_conditional_qualified(
      instructions,
      Some(@ir.hot_module_context_from_module(input)),
    ),
  )
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
    assert_eq(count, 1)
    let analysis = [0]
    let output = dae2_run_module_pass(
      input,
      closed_world,
      raw_rewrite=false,
      analysis_lifts=Some(analysis),
    ).unwrap()
    let reference = dae2_run_module_pass(
      input,
      closed_world,
      raw_analysis=false,
      raw_rewrite=false,
    ).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
    assert_eq(analysis[0], 1)
    // The materialized dead call keeps parameter 2 demanded. The unused i64
    // still disappears, so this HOT control must perform a real transform.
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
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
