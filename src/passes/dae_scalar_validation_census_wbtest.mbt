///|
/// Counts and full reference replay are outside all timing regions.
#skip("manual native frozen-input scalar-certificate eligibility and work census")
test "DAE scalar certificate preserves both frozen inputs with exact core work census" {
  let inputs = match @env.get_env_var("STARSHINE_DAE_SCALAR_CENSUS_INPUT") {
    Some(path) => [(path, "selected")]
    None =>
      [
        (".tmp/dae-speed-20261016/inputs/small.wasm", "small"),
        (".tmp/dae-speed-20261016/inputs/large.wasm", "large"),
      ]
  }
  let output_prefix = @env.get_env_var(
    "STARSHINE_DAE_SCALAR_CENSUS_OUTPUT_PREFIX",
  ).unwrap_or(".tmp/dae-speed-20261016/validation-cost/scalar-census")
  for (path, label) in inputs {
    let bytes = @sfs.read_file_bytes(path).unwrap()
    let input = @binary.decode_module(bytes).unwrap()
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let defined = input.code_sec.unwrap().0.length()
    for optimize in [false, true] {
      let reference_options = HotPipelineOptions::new()
      let expected = dae_run_core(input, reference_options.trace, optimize~)
      let options = HotPipelineOptions::new()
      let work = DaeScalarValidationWork::new()
      let actual = dae_run_core(
        input,
        options.trace,
        optimize~,
        no_callback_trace=hot_pipeline_dae_no_callback_trace(options),
        scalar_validation_work=Some(work),
      )
      assert_eq(actual.changed, expected.changed)
      assert_eq(actual.touched, expected.touched)
      assert_eq(actual.effects, expected.effects)
      let expected_bytes = @binary.encode_module(expected.mod_out).unwrap()
      let actual_bytes = @binary.encode_module(actual.mod_out).unwrap()
      assert_eq(actual_bytes, expected_bytes)
      @validate.validate_module(actual.mod_out).unwrap()
      assert_eq(@binary.encode_module(input).unwrap(), saved)
      assert_eq(work.offered, work.full_gates + work.partial_gates)
      assert_true(work.envelope_matches <= work.matched_sources)
      assert_true(work.partial_gates <= work.envelope_matches)
      let lane = if optimize { "daeo" } else { "dae" }
      @sfs.write_file_bytes(
        "\{output_prefix}-\{label}-\{lane}-full.wasm",
        expected_bytes,
      ).unwrap()
      @sfs.write_file_bytes(
        "\{output_prefix}-\{label}-\{lane}-certificate.wasm",
        actual_bytes,
      ).unwrap()
      println(
        "scalar-census input=\{label} lane=\{lane} defined=\{defined} source_bytes=\{bytes.length()} offered=\{work.offered} matched_sources=\{work.matched_sources} envelope_matches=\{work.envelope_matches} index_builds=\{work.index_builds} full_gates=\{work.full_gates} partial_gates=\{work.partial_gates} full_bodies=\{work.full_bodies} partial_bodies=\{work.partial_bodies} full_errors=\{work.full_errors} output_bytes=\{actual_bytes.length()}",
      )
    }
  }
}
