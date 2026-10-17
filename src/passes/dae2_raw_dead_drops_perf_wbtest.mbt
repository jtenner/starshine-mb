///|
fn dae2_artifact_bench_setting(name : String) -> String raise {
  match @env.get_env_var(name) {
    Some(value) if !value.is_empty() => value
    _ => fail("Set \{name} before this manual artifact test")
  }
}

///|
#skip("manual large-artifact solved boundary and source-write demand differential")
test "DAE2 current dead-tail analysis preserves complete large-artifact demand" {
  let input_path = dae2_artifact_bench_setting("STARSHINE_DAE_BENCH_INPUT")
  let bytes = @sfs.read_file_bytes(input_path).unwrap()
  let input = @binary.decode_module(bytes).unwrap()
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  for closed_world in [false, true] {
    let actual_writes = []
    let expected_writes = []
    let (actual, plans) = raw_conditional_boundary_bits(
      input,
      true,
      closed_world~,
      write_demands=Some(actual_writes),
    )
    let (expected, _) = raw_conditional_boundary_bits(
      input,
      false,
      closed_world~,
      write_demands=Some(expected_writes),
    )
    assert_eq(actual.length(), expected.length())
    for index in 0..<actual.length() {
      if actual[index] != expected[index] {
        fail("boundary \{index}: \{actual[index]} != \{expected[index]}")
      }
    }
    assert_eq(actual_writes.length(), expected_writes.length())
    for index in 0..<actual_writes.length() {
      let left = actual_writes[index]
      let right = expected_writes[index]
      if left.length() != right.length() {
        fail(
          "function \{index} write count: \{left.length()} != \{right.length()}",
        )
      }
      for slot in 0..<left.length() {
        if left[slot] != right[slot] {
          fail(
            "function \{index} write \{slot}: \{left[slot]} != \{right[slot]}",
          )
        }
      }
    }
    // This helper tests every current planner under its common exposure seed.
    // Its count is not the production pinned-skip/raw-commit split below.
    println("dae2-current-plan-demand closed=\{closed_world} plans=\{plans}")
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
#skip("manual current-production large-artifact admission replay and encoded-output check")
test "DAE2 current production avoids whole-module HOT retry on the large artifact" {
  let input_path = dae2_artifact_bench_setting("STARSHINE_DAE_BENCH_INPUT")
  let bytes = @sfs.read_file_bytes(input_path).unwrap()
  let input = @binary.decode_module(bytes).unwrap()
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let output_prefix = dae2_artifact_bench_setting(
    "STARSHINE_DAE_BENCH_OUTPUT_PREFIX",
  )
  let defined = input.code_sec.unwrap().0.length()
  for closed_world in [false, true] {
    let analysis = [0]
    let rewrite = [0]
    let actual = dae2_run_module_pass(
      input,
      closed_world,
      analysis_lifts=Some(analysis),
      rewrite_lifts=Some(rewrite),
    ).unwrap()
    let full_hot_analysis = [0]
    let full_hot_rewrite = [0]
    let full_hot = dae2_run_module_pass(
      input,
      closed_world,
      raw_analysis=false,
      analysis_lifts=Some(full_hot_analysis),
      rewrite_lifts=Some(full_hot_rewrite),
    ).unwrap()
    @validate.validate_module(actual).unwrap()
    @validate.validate_module(full_hot).unwrap()
    // A replay mismatch adds a complete HOT-only module analysis to this same
    // counter. The independent run uses exactly that retry configuration.
    assert_true(analysis[0] < full_hot_analysis[0])
    let actual_bytes = @binary.encode_module(actual).unwrap()
    let hot_bytes = @binary.encode_module(full_hot).unwrap()
    let world = if closed_world { "closed" } else { "open" }
    @sfs.write_file_bytes("\{output_prefix}-\{world}.wasm", actual_bytes).unwrap()
    @sfs.write_file_bytes("\{output_prefix}-hot-\{world}.wasm", hot_bytes).unwrap()
    // Zero-HOT includes fully pinned skips. Do not label it raw commits.
    println(
      "dae2-current-main closed=\{closed_world} defined=\{defined} analysis=\{analysis[0]} rewrite=\{rewrite[0]} zero_hot=\{defined - analysis[0]} full_hot_analysis=\{full_hot_analysis[0]} full_hot_rewrite=\{full_hot_rewrite[0]} bytes=\{actual_bytes.length()} full_hot_bytes=\{hot_bytes.length()} output_equal=\{actual_bytes == hot_bytes}",
    )
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
