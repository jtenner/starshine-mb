///|
test "deep audit memory packing preserves atomic bounds failure for imported active segment" {
  let input = pass_test_module_from_wat(
    (
      #|(module (import "env" "memory" (memory 1 1))
      #| (data (i32.const 65520) "A\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00"))
    ),
  )
  let output = run_hot_pipeline(
    input,
    HotPipelineOptions::new(zero_filled_memory=true),
    ["memory-packing"],
  ).unwrap()
  // The entire segment is bounds-checked before any byte is written.
  @debug.assert_eq(output.data_sec, input.data_sec)
}
