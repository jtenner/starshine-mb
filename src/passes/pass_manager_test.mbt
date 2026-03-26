///|
test "hot pipeline debug dump targets stay disabled without trace" {
  let options = HotPipelineOptions::new()

  assert_false(
    run_hot_pipeline_debug_dump_enabled(
      options,
      @lib.FuncIdx::new(2941U),
      "dead-code-elimination",
    ),
  )
  assert_false(
    run_hot_pipeline_debug_dump_enabled(
      options,
      @lib.FuncIdx::new(2944U),
      "vacuum",
    ),
  )
}

///|
test "hot pipeline debug dump targets require traced dce or vacuum on target funcs" {
  let options = HotPipelineOptions::new(trace=Some(fn(_) { () }))

  assert_true(
    run_hot_pipeline_debug_dump_enabled(
      options,
      @lib.FuncIdx::new(2941U),
      "dead-code-elimination",
    ),
  )
  assert_true(
    run_hot_pipeline_debug_dump_enabled(
      options,
      @lib.FuncIdx::new(2944U),
      "vacuum",
    ),
  )
  assert_false(
    run_hot_pipeline_debug_dump_enabled(
      options,
      @lib.FuncIdx::new(2941U),
      "remove-unused-names",
    ),
  )
  assert_false(
    run_hot_pipeline_debug_dump_enabled(
      options,
      @lib.FuncIdx::new(12U),
      "dead-code-elimination",
    ),
  )
}
