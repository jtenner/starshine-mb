///|
test "deep audit optimize instructions retains copies using distinct shared i32.atomic.load" {
  let load = "i32.atomic.load"
  let input = pass_test_module_from_wat(
    "(module (memory 1 1 shared) (func (param i32 i32) local.get 0 " +
    load +
    " local.get 0 " +
    load +
    " local.get 1 memory.copy))",
  )
  let output = run_hot_pipeline(
    input,
    HotPipelineOptions::new(traps_never_happen=true),
    ["optimize-instructions"],
  ).unwrap()
  // Concurrent stores can change the address between the two reads.
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.MemoryCopy(_, _) }),
    1,
  )
}

///|
test "deep audit optimize instructions retains copies using distinct shared i32.load" {
  let load = "i32.load"
  let input = pass_test_module_from_wat(
    "(module (memory 1 1 shared) (func (param i32 i32) local.get 0 " +
    load +
    " local.get 0 " +
    load +
    " local.get 1 memory.copy))",
  )
  let output = run_hot_pipeline(
    input,
    HotPipelineOptions::new(traps_never_happen=true),
    ["optimize-instructions"],
  ).unwrap()
  // Concurrent stores can change the address between the two reads.
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.MemoryCopy(_, _) }),
    1,
  )
}
