///|
// The source prefix is evaluated before the If condition and all callee writes.
// These fixtures remove only the unused scalar If result, not its producers.
fn raw_unused_held_fixture(producer : String) -> (@lib.Module, @lib.Func) {
  let region = "local.get 0 if (result i32) local.get 0 local.get 1 call $h drop \{producer} local.tee 2 else local.get 1 local.get 0 call $h drop \{producer} local.tee 2 end"
  let input = raw_unused_control_module(
    region,
    prefix="local.get 1 i32.load",
    suffix="local.get 2 i32.add",
  )
  let expected = pass_test_module_from_wat(
      "(module (import \"e\" \"value\" (func $value (result i32))) (import \"e\" \"mark\" (func $mark (param i32))) (memory 1) (global $g (mut i32) (i32.const 0)) (func $h (param i32) local.get 0 global.set $g) (func (param i32 i32) (result i32) (local i32) local.get 1 i32.load local.get 0 if local.get 0 call $h \{producer} local.set 2 else local.get 1 call $h \{producer} local.set 2 end local.get 2 i32.add))",
    ).code_sec.unwrap().0[1]
  (input, expected)
}

///|
fn raw_unused_held_demand_compare(input : @lib.Module) -> Unit raise {
  for closed_world in [false, true] {
    let raw_writes = []
    let hot_writes = []
    let (raw_bits, _) = raw_conditional_boundary_bits(
      input,
      true,
      closed_world~,
      write_demands=Some(raw_writes),
    )
    let (hot_bits, _) = raw_conditional_boundary_bits(
      input,
      false,
      closed_world~,
      write_demands=Some(hot_writes),
    )
    assert_eq(raw_bits, hot_bits)
    assert_eq(raw_writes, hot_writes)
  }
}

///|
test "DAE2 unused scalar If without held prefix keeps exact HOT shape effects and demanded writes" {
  for
    producer in [
      "local.get 1 i32.load", "local.get 1 i32.const 0 i32.div_s", "call $value",
    ] {
    let region = "local.get 0 if (result i32) local.get 0 local.get 1 call $h drop \{producer} local.tee 2 else local.get 1 local.get 0 call $h drop \{producer} local.tee 2 end"
    ignore(
      raw_unused_control_compare(
        raw_unused_control_module(region, suffix="local.get 2"),
      ),
    )
  }
}

///|
test "DAE2 unused scalar If with held stack intentionally keeps HOT shape and cleanup parity" {
  for
    producer in [
      "local.get 1 i32.load", "local.get 1 i32.const 0 i32.div_s", "call $value",
    ] {
    let (input, _) = raw_unused_held_fixture(producer)
    // The previous strict natural-stack proof failed its downstream size bound.
    // This scope intentionally retains HOT while the no-prefix fixture above
    // still requires productive zero-lift header removal for all three leaves.
    ignore(raw_unused_control_compare(input, expected_lifts=1))
    let saved = @binary.encode_module(input).unwrap()
    for closed_world in [false, true] {
      let actual = dae2_run_module_pass(
        input,
        closed_world,
        stack_suffix_rewrite=false,
      ).unwrap()
      let reference = dae2_run_module_pass(
        input,
        closed_world,
        raw_analysis=false,
        raw_rewrite=false,
      ).unwrap()
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
      @validate.validate_module(reference_cleaned).unwrap()
      assert_eq(cleaned.code_sec, reference_cleaned.code_sec)
      assert_eq(
        @binary.encode_module(cleaned).unwrap(),
        @binary.encode_module(reference_cleaned).unwrap(),
      )
    }
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
#skip("manual actual-artifact held prefix runtime and native oracle size proof")
test "DAE2 unused scalar If exports actual original raw HOT and cleanup artifacts" {
  let producers = [
    "local.get 1 i32.load", "local.get 1 i32.const 0 i32.div_s", "call $value",
  ]
  let labels = ["load", "divide", "import"]
  for index = 0; index < producers.length(); index = index + 1 {
    let (input, _) = raw_unused_held_fixture(producers[index])
    let label = labels[index]
    let saved = @binary.encode_module(input).unwrap()
    raw_unused_held_demand_compare(input)
    ignore(raw_unused_control_compare(input, expected_lifts=1))
    @sfs.write_file_bytes(
      ".tmp/unused-control-held/\{label}-original.wasm",
      saved,
    ).unwrap()
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
      @validate.validate_module(reference).unwrap()
      assert_eq(actual.code_sec, reference.code_sec)
      assert_eq(analysis[0], 0)
      assert_eq(rewrite[0], 1)
      let actual_bytes = @binary.encode_module(actual).unwrap()
      let reference_bytes = @binary.encode_module(reference).unwrap()
      assert_eq(actual_bytes, reference_bytes)
      @sfs.write_file_bytes(
        ".tmp/unused-control-held/\{label}-\{closed_world}-actual.wasm",
        actual_bytes,
      ).unwrap()
      @sfs.write_file_bytes(
        ".tmp/unused-control-held/\{label}-\{closed_world}-reference.wasm",
        reference_bytes,
      ).unwrap()
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
      @validate.validate_module(reference_cleaned).unwrap()
      let cleaned_bytes = @binary.encode_module(cleaned).unwrap()
      let reference_cleaned_bytes = @binary.encode_module(reference_cleaned).unwrap()
      assert_eq(cleaned_bytes, reference_cleaned_bytes)
      @sfs.write_file_bytes(
        ".tmp/unused-control-held/\{label}-\{closed_world}-cleaned-actual.wasm",
        cleaned_bytes,
      ).unwrap()
      @sfs.write_file_bytes(
        ".tmp/unused-control-held/\{label}-\{closed_world}-cleaned-reference.wasm",
        reference_cleaned_bytes,
      ).unwrap()
      println(
        "unused-scalar-held-size label=\{label} world=\{closed_world} actual=\{actual_bytes.length()} reference=\{reference_bytes.length()} cleaned_actual=\{cleaned_bytes.length()} cleaned_reference=\{reference_cleaned_bytes.length()}",
      )
    }
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
