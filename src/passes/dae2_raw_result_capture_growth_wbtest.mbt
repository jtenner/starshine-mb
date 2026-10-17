///|
test "DAE2 recursive replay keeps uniform i32 held results without extra captures or cleanup growth" {
  for value in ["call $value", "local.get 0 i32.load"] {
    let input = pass_test_module_from_wat(
      "(module (import \"e\" \"value\" (func $value (result i32))) (import \"e\" \"effect\" (func $effect (param i32))) (memory 1) (func $h (param i32 i32) (result i32) local.get 0) (func (export \"run\") (param i32) (result i32) (local i32 i32) \{value} local.get 0 if local.get 0 call $effect end local.set 1 local.get 1 local.get 0 i32.const 3 i32.add call $h local.get 0 if local.get 0 call $effect end))",
    )
    let expected = pass_test_module_from_wat(
        "(module (import \"e\" \"value\" (func $value (result i32))) (import \"e\" \"effect\" (func $effect (param i32))) (memory 1) (func $h (param i32) (result i32) local.get 0) (func (param i32) (result i32) (local i32 i32) \{value} local.get 0 if local.get 0 call $effect end local.set 1 local.get 1 call $h local.get 0 if local.get 0 call $effect end))",
      ).code_sec.unwrap().0[1]
    let saved = @binary.encode_module(input).unwrap()
    for closed_world in [false, true] {
      let analysis = [0]
      let rewrite = [0]
      let actual = dae2_run_module_pass(
        input,
        closed_world,
        stack_suffix_rewrite=false,
        analysis_lifts=Some(analysis),
        rewrite_lifts=Some(rewrite),
      ).unwrap()
      let reference = dae2_run_module_pass(
        input,
        closed_world,
        raw_analysis=false,
        raw_rewrite=false,
      ).unwrap()
      @validate.validate_module(actual).unwrap()
      assert_eq(analysis[0], 0)
      assert_eq(rewrite[0], 0)
      // The exact body keeps the held producer before both effectful Ifs and
      // uses its existing stack slot across each control boundary.
      assert_eq(actual.code_sec.unwrap().0[1], expected)
      assert_true(
        @binary.encode_module(actual).unwrap().length() <=
        @binary.encode_module(reference).unwrap().length(),
      )
      let cleaned = dae2_cleanup_captures(
        run_hot_pipeline(actual, HotPipelineOptions::new(), [
          "simplify-locals", "vacuum",
        ]).unwrap(),
      )
      let reference_cleaned = dae2_cleanup_captures(
        run_hot_pipeline(reference, HotPipelineOptions::new(), [
          "simplify-locals", "vacuum",
        ]).unwrap(),
      )
      @validate.validate_module(cleaned).unwrap()
      assert_true(
        @binary.encode_module(cleaned).unwrap().length() <=
        @binary.encode_module(reference_cleaned).unwrap().length(),
      )
    }
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
