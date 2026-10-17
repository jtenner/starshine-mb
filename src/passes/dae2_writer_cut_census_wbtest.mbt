///|
#skip("manual complete writer-cut node/writer/boundary census and four matched route outputs")
test "writer cut artifact retains every HOT bit and exact matched default outputs" {
  let bytes = @sfs.read_file_bytes(
    dae2_writer_cut_census_setting("STARSHINE_DAE_BENCH_INPUT"),
  ).unwrap()
  let input = @binary.decode_module(bytes).unwrap()
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let prefix = dae2_writer_cut_census_setting(
    "STARSHINE_DAE_BENCH_OUTPUT_PREFIX",
  )
  for closed_world in [false, true] {
    for raw_analysis in [true, false] {
      let errors = [0, 0, 0, 0]
      let analysis = [0]
      let rewrites = [0]
      let actual_bytes = dae2_writer_cut_census_actual_bytes(
        errors, input, closed_world, raw_analysis, analysis, rewrites,
      )
      let reference_bytes = dae2_writer_cut_census_reference_bytes(
        input, closed_world, raw_analysis,
      )
      let direct_bytes = dae2_writer_cut_census_direct_bytes(
        input, closed_world, raw_analysis,
      )
      let world = if closed_world { "closed" } else { "open" }
      let route = if raw_analysis { "raw" } else { "hot" }
      @sfs.write_file_bytes(
        "\{prefix}-\{route}-\{world}-actual.wasm",
        actual_bytes,
      ).unwrap()
      @sfs.write_file_bytes(
        "\{prefix}-\{route}-\{world}-reference.wasm",
        reference_bytes,
      ).unwrap()
      @sfs.write_file_bytes(
        "\{prefix}-\{route}-\{world}-direct.wasm",
        direct_bytes,
      ).unwrap()
      println(
        "writer-cut-output route=\{route} world=\{world} analysis=\{analysis[0]} rewrite=\{rewrites[0]} actual=\{actual_bytes.length()} reference=\{reference_bytes.length()} node_drift=\{errors[0]} writer_drift=\{errors[1]} boundary_drift=\{errors[2]} metadata_drift=\{errors[3]}",
      )
      dae2_writer_cut_census_bytes_equal(
        actual_bytes, reference_bytes, "matched full-flow reference",
      )
      dae2_writer_cut_census_bytes_equal(
        actual_bytes, direct_bytes, "uninstrumented current route",
      )
      dae2_writer_cut_census_bytes_equal(
        @binary.encode_module(input).unwrap(),
        saved,
        "input ownership",
      )
      assert_eq(errors, [0, 0, 0, 0])
    }
  }
}
