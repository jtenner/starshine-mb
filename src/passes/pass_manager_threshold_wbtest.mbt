///|
fn threshold_test_rub_shape(
  call_count? : Int = 0,
  local_set_count? : Int = 0,
  local_tee_count? : Int = 0,
  if_count? : Int = 0,
  return_count? : Int = 0,
  select_count? : Int = 0,
  br_if_count? : Int = 0,
  block_count? : Int = 0,
  value_block_count? : Int = 0,
  void_block_count? : Int = 0,
  loop_count? : Int = 0,
  br_count? : Int = 0,
  br_table_count? : Int = 0,
  drop_count? : Int = 0,
) -> RawRemoveUnusedBrsShape {
  RawRemoveUnusedBrsShape::with_counts(
    call_count~,
    local_set_count~,
    local_tee_count~,
    if_count~,
    return_count~,
    select_count~,
    br_if_count~,
    block_count~,
    value_block_count~,
    void_block_count~,
    loop_count~,
    br_count~,
    br_table_count~,
    drop_count~,
  )
}

///|
fn threshold_test_simplify_stats(
  locals_count? : Int = 0,
  instr_count? : Int = 0,
  has_structured_control? : Bool = false,
  if_count? : Int = 0,
  block_count? : Int = 0,
  loop_count? : Int = 0,
  local_set_count? : Int = 0,
  local_get_count? : Int = 0,
  call_count? : Int = 0,
  return_count? : Int = 0,
  exact_tail_count? : Int = 0,
) -> RawSimplifyLocalsGateStats {
  RawSimplifyLocalsGateStats::new(
    locals_count~,
    instr_count~,
    has_structured_control~,
    if_count~,
    block_count~,
    loop_count~,
    local_set_count~,
    local_get_count~,
    call_count~,
    return_count~,
    exact_tail_count~,
  )
}

///|
fn threshold_test_all_guard_class(
  pass_name : String,
  reasons : Array[String],
  expected : String,
) -> Bool {
  reasons.all(fn(reason) {
    run_hot_pipeline_threshold_guard_class(pass_name, reason) == Some(expected)
  })
}

///|
test "threshold guard reasons expose correctness and performance policy" {
  assert_eq(
    run_hot_pipeline_threshold_guard_class(
      "remove-unused-brs", "large-local-dispatch-noop",
    ),
    Some("performance"),
  )
  assert_eq(
    run_hot_pipeline_threshold_guard_class(
      "remove-unused-brs", "unchecked-moderate-call-mesh-noop",
    ),
    Some("correctness"),
  )
  assert_eq(
    run_hot_pipeline_threshold_guard_class(
      "simplify-locals", "giant-validator-structured-call-heavy-noop",
    ),
    Some("performance"),
  )
  assert_eq(
    run_hot_pipeline_threshold_guard_class(
      "simplify-locals", "root-local-set-stack-hazard-noop",
    ),
    Some("correctness"),
  )
  assert_true(
    threshold_test_all_guard_class(
      "remove-unused-brs",
      [
        "large-void-if-return-ladder-noop", "large-result-br-table-dispatch-ladder-noop",
        "large-value-if-branch-ladder-noop", "large-drop-heavy-branch-ladder-noop",
        "moderate-control-ladder-noop", "large-typed-br-table-encoder-ladder-noop",
        "unique-loop-select-return-ladder-noop", "structured-return-ladder-noop",
        "large-local-dispatch-noop", "refcount-payload-parser-noop",
      ],
      "performance",
    ),
  )
  assert_true(
    threshold_test_all_guard_class(
      "simplify-locals",
      [
        "large-module-simplify-locals-noop", "straight-line-builder-churn", "huge-straight-line-call-builder",
        "multivalue-call-heavy-ladder", "giant-validator-structured-call-heavy-noop",
        "branch-dense-structured-call-heavy-noop", "low-local-decision-ladder-noop",
        "low-local-loop-return-call-ladder-noop", "mid-local-structured-call-ladder-noop",
        "low-local-structured-call-heavy-noop", "parser-structured-call-heavy", "decode-structured-call-heavy",
        "encode-structured-call-heavy", "branchy-decode-structured-call-heavy", "transformer-catch-structured-call-heavy",
        "branchy-structured-call-heavy", "dense-structured-call-heavy", "stringview-trim-loop-churn",
        "transformer-structured-call-heavy", "small-loop-call-heavy", "block-rich-structured-call-heavy-noop",
        "call-dense-structured-walker-noop", "medium-structured-call-heavy", "loop-heavy-structured-call-heavy",
        "giant-structured-call-heavy", "giant-structured-local-churn", "giant-local-func-noop",
      ],
      "performance",
    ),
  )
  assert_eq(
    run_hot_pipeline_threshold_guard_class("vacuum", "no-vacuum-candidates"),
    None,
  )
}

///|
test "remove-unused-brs large dispatch threshold is strict at locals and instructions" {
  assert_false(
    run_hot_pipeline_raw_remove_unused_brs_large_local_dispatch_stats(
      96, 1001, true,
    ),
  )
  assert_false(
    run_hot_pipeline_raw_remove_unused_brs_large_local_dispatch_stats(
      97, 1000, true,
    ),
  )
  assert_true(
    run_hot_pipeline_raw_remove_unused_brs_large_local_dispatch_stats(
      97, 1001, true,
    ),
  )
  assert_false(
    run_hot_pipeline_raw_remove_unused_brs_large_local_dispatch_stats(
      97, 1001, false,
    ),
  )
}

///|
test "remove-unused-brs O4z parser guard covers every inclusive minimum" {
  let shape = threshold_test_rub_shape(
    call_count=8,
    local_set_count=20,
    if_count=4,
  )
  assert_true(
    run_hot_pipeline_raw_remove_unused_brs_refcount_payload_stats(
      4, 1, 128, shape,
    ),
  )
  assert_false(
    run_hot_pipeline_raw_remove_unused_brs_refcount_payload_stats(
      3, 1, 128, shape,
    ),
  )
  assert_false(
    run_hot_pipeline_raw_remove_unused_brs_refcount_payload_stats(
      4, 0, 128, shape,
    ),
  )
  assert_false(
    run_hot_pipeline_raw_remove_unused_brs_refcount_payload_stats(
      4, 1, 127, shape,
    ),
  )
  shape.call_count = 7
  assert_false(
    run_hot_pipeline_raw_remove_unused_brs_refcount_payload_stats(
      4, 1, 128, shape,
    ),
  )
  shape.call_count = 8
  shape.local_set_count = 19
  assert_false(
    run_hot_pipeline_raw_remove_unused_brs_refcount_payload_stats(
      4, 1, 128, shape,
    ),
  )
  shape.local_set_count = 20
  shape.if_count = 3
  assert_false(
    run_hot_pipeline_raw_remove_unused_brs_refcount_payload_stats(
      4, 1, 128, shape,
    ),
  )
}

///|
test "remove-unused-brs SIMD parser hazard bounds are inclusive" {
  let boundary = threshold_test_rub_shape(
    call_count=100,
    local_set_count=600,
    local_tee_count=500,
    if_count=600,
    return_count=4,
    select_count=40,
    br_if_count=150,
    block_count=100,
    value_block_count=35,
    void_block_count=60,
    loop_count=180,
    br_count=320,
    br_table_count=1,
    drop_count=60,
  )
  assert_true(
    run_hot_pipeline_raw_simd_parser_br_table_stack_hazard_stats(
      20, 8000, boundary,
    ),
  )
  assert_false(
    run_hot_pipeline_raw_simd_parser_br_table_stack_hazard_stats(
      19, 8000, boundary,
    ),
  )
  assert_false(
    run_hot_pipeline_raw_simd_parser_br_table_stack_hazard_stats(
      20, 7999, boundary,
    ),
  )
  boundary.br_table_count = 0
  assert_false(
    run_hot_pipeline_raw_simd_parser_br_table_stack_hazard_stats(
      20, 8000, boundary,
    ),
  )
}

///|
test "remove-unused-brs unchecked mesh bounds are inclusive and hazard sensitive" {
  let shape = threshold_test_rub_shape(
    call_count=96,
    local_set_count=24,
    local_tee_count=8,
    if_count=16,
    block_count=8,
    br_count=8,
    drop_count=16,
  )
  assert_true(
    run_hot_pipeline_raw_remove_unused_brs_unchecked_moderate_call_mesh_stats(
      24, 400, true, true, true, true, shape, false, false,
    ),
  )
  assert_false(
    run_hot_pipeline_raw_remove_unused_brs_unchecked_moderate_call_mesh_stats(
      23, 400, true, true, true, true, shape, false, false,
    ),
  )
  assert_false(
    run_hot_pipeline_raw_remove_unused_brs_unchecked_moderate_call_mesh_stats(
      24, 399, true, true, true, true, shape, false, false,
    ),
  )
  assert_false(
    run_hot_pipeline_raw_remove_unused_brs_unchecked_moderate_call_mesh_stats(
      24, 400, true, true, true, true, shape, true, false,
    ),
  )
  assert_false(
    run_hot_pipeline_raw_remove_unused_brs_unchecked_moderate_call_mesh_stats(
      24, 400, true, true, true, true, shape, false, true,
    ),
  )
}

///|
test "simplify-locals module skip begins at 2048 functions" {
  assert_false(run_hot_pipeline_simplify_locals_should_skip_module_count(2047))
  assert_true(run_hot_pipeline_simplify_locals_should_skip_module_count(2048))
  assert_true(run_hot_pipeline_simplify_locals_should_skip_module_count(2049))
}

///|
test "simplify-locals giant function guard uses inclusive audited minima" {
  assert_true(
    run_hot_pipeline_raw_simplify_locals_giant_func_stats(
      threshold_test_simplify_stats(
        locals_count=1500,
        instr_count=2000,
        has_structured_control=true,
      ),
    ),
  )
  assert_false(
    run_hot_pipeline_raw_simplify_locals_giant_func_stats(
      threshold_test_simplify_stats(
        locals_count=1499,
        instr_count=2000,
        has_structured_control=true,
      ),
    ),
  )
  assert_false(
    run_hot_pipeline_raw_simplify_locals_giant_func_stats(
      threshold_test_simplify_stats(
        locals_count=1500,
        instr_count=1999,
        has_structured_control=true,
      ),
    ),
  )
  assert_false(
    run_hot_pipeline_raw_simplify_locals_giant_func_stats(
      threshold_test_simplify_stats(
        locals_count=1500,
        instr_count=2000,
        has_structured_control=false,
      ),
    ),
  )
}

///|
test "simplify-locals unchecked mesh has focused plus-minus-one coverage" {
  let boundary = threshold_test_simplify_stats(
    locals_count=8,
    instr_count=192,
    has_structured_control=true,
    if_count=12,
    block_count=4,
    loop_count=2,
    local_set_count=4,
    local_get_count=64,
    call_count=48,
    return_count=4,
    exact_tail_count=0,
  )
  assert_true(
    run_hot_pipeline_raw_simplify_locals_unchecked_small_structured_call_mesh_stats(
      boundary,
    ),
  )
  let too_many_locals = threshold_test_simplify_stats(
    locals_count=9,
    instr_count=192,
    has_structured_control=true,
    if_count=12,
    block_count=4,
    loop_count=2,
    local_set_count=4,
    local_get_count=64,
    call_count=48,
    return_count=4,
    exact_tail_count=0,
  )
  assert_false(
    run_hot_pipeline_raw_simplify_locals_unchecked_small_structured_call_mesh_stats(
      too_many_locals,
    ),
  )
  let too_short = threshold_test_simplify_stats(
    locals_count=8,
    instr_count=191,
    has_structured_control=true,
    if_count=12,
    block_count=4,
    loop_count=2,
    local_set_count=4,
    local_get_count=64,
    call_count=48,
    return_count=4,
    exact_tail_count=0,
  )
  assert_false(
    run_hot_pipeline_raw_simplify_locals_unchecked_small_structured_call_mesh_stats(
      too_short,
    ),
  )
}

///|
test "simplify-locals giant validator guard keeps exact boundary contract" {
  let boundary = threshold_test_simplify_stats(
    locals_count=1024,
    instr_count=8000,
    has_structured_control=true,
    if_count=256,
    block_count=64,
    loop_count=4,
    local_set_count=1024,
    local_get_count=2048,
    call_count=1024,
    return_count=32,
    exact_tail_count=0,
  )
  assert_true(
    run_hot_pipeline_raw_simplify_locals_giant_validator_structured_call_heavy_stats(
      boundary,
    ),
  )
  let below = threshold_test_simplify_stats(
    locals_count=1023,
    instr_count=8000,
    has_structured_control=true,
    if_count=256,
    block_count=64,
    loop_count=4,
    local_set_count=1024,
    local_get_count=2048,
    call_count=1024,
    return_count=32,
    exact_tail_count=0,
  )
  assert_false(
    run_hot_pipeline_raw_simplify_locals_giant_validator_structured_call_heavy_stats(
      below,
    ),
  )
}
