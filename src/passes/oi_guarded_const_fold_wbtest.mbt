///|
test "OI global call tee guard retains adjacent constant folds and exact effects" {
  let prefix = "(module (import \"host\" \"f\" (func (param i32) (result i32))) (global (mut i32) (i32.const 0)) (func (param i32) (result i32) (local i32) global.get 0 local.tee 1 drop block local.get 0 call 0 global.set 0 end "
  for
    (tail, expected_tail) in [
      ("i32.const 2 i32.const 3 i32.add", "i32.const 5"),
      (
        "local.get 0 if (result i32) i32.const 2147483647 i32.const 1 i32.add else i32.const 0 i32.eqz i32.eqz end",
        "local.get 0 if (result i32) i32.const -2147483648 else i32.const 0 end",
      ),
      (
        "block (result i32) unreachable i32.const 2 i32.const 3 i32.add end", "block (result i32) unreachable i32.const 5 end",
      ),
    ] {
    let input = @wast.wast_to_binary_module(prefix + tail + "))").unwrap()
    let expected = @wast.wast_to_binary_module(prefix + expected_tail + "))").unwrap()
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let output = run_hot_pipeline_raw_optimize_instructions_skip(
      input,
      @lib.FuncIdx::new(1U),
      HotPipelineModuleState::new(),
      optimize_instructions_descriptor(),
      HotPipelineOptions::new(),
    ).unwrap()
    assert_false(output.unchanged_original)
    assert_true(output.trace_skip_raw)
    @debug.assert_eq(output.func, expected.code_sec.unwrap().0[0])
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
