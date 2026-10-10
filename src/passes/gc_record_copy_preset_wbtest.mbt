///|
test "record-copy cleanup is selective to the exact numeric 4/1 fast preset" {
  let fast = [
    "duplicate-function-elimination", "constraint-analysis", "vacuum", "reorder-locals",
    "strip-debug",
  ]
  for (optimize, shrink) in [(4, 0), (3, 1), (4, 2)] {
    assert_eq(
      optimize_preset_passes(
        HotPipelineOptions::new(optimize_level=optimize, shrink_level=shrink),
      ),
      fast,
    )
  }
  let options = HotPipelineOptions::new(optimize_level=4, shrink_level=1)
  let expected = [
    "duplicate-function-elimination", "constraint-analysis", "vacuum", "reorder-locals",
    "merge-similar-functions", "strip-debug",
  ]
  assert_eq(optimize_preset_passes(options), expected)
  let module_ = gc_copy_test_module(12, 12)
  assert_eq(
    pass_registry_expanded_names_for_module(module_, options, ["optimize"]).unwrap(),
    expected,
  )
  let o4z = HotPipelineOptions::new(optimize_level=4, shrink_level=4)
  assert_eq(
    optimize_preset_passes(o4z),
    hot_pipeline_full_preset_passes_with_features(
      o4z,
      HotPipelineFeatureFacts::all(),
    ),
  )
}
