///|
fn legacy_cleanup_read_fixture(catch_read : Bool) -> String {
  let producer = if catch_read { "throw $e" } else { "local.get 0" }
  let handler = if catch_read { "local.get 0" } else { "i32.const 13" }
  "(module (tag $e) (func (export \"run\") (result i32) (local i32) block i32.const 99 local.set 0 local.get 0 drop end (try (result i32) (do \{producer}) (catch $e \{handler}))))"
}

///|
test "adjacent capture cleanup preserves reads in legacy bodies and catches" {
  for catch_read in [false, true] {
    let input = pass_test_module_from_wat(
      legacy_cleanup_read_fixture(catch_read),
    )
    @validate.validate_module(input).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    let saved = sl_leaf_bytes(body)
    let output = run_hot_pipeline_simplify_locals_lowered_drop_dead_adjacent_local_set_get_pairs(
      body,
    )
    assert_eq(output, body)
    assert_eq(sl_leaf_bytes(body), saved)
  }
}

///|
test "exact cleanup counts legacy body and catch reads" {
  for catch_read in [false, true] {
    let input = pass_test_module_from_wat(
      legacy_cleanup_read_fixture(catch_read),
    )
    @validate.validate_module(input).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    let counts = [0]
    run_hot_pipeline_simplify_locals_lowered_count_local_gets_in_body(
      body, counts,
    )
    assert_eq(counts, [2])
  }
}

///|
test "exact cleanup includes legacy-only locals in index bounds" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32 i32 i32 i32 i32 i32 i32) (result i32) (try (result i32) (do local.get 6) (catch_all local.get 5))))",
  )
  @validate.validate_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  assert_eq(
    run_hot_pipeline_simplify_locals_lowered_max_local_idx_in_body(body),
    6,
  )
}

///|
test "raw future access queries include legacy body and catch accesses" {
  let input = pass_test_module_from_wat(
    "(module (tag $e) (func (param i32) (local i32) (try (do i32.const 1 local.set 1 throw $e) (catch $e local.get 1 drop i32.const 2 local.set 1))))",
  )
  @validate.validate_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  assert_true(run_hot_pipeline_raw_instrs_have_later_local_read(body, 0, 1))
  assert_true(run_hot_pipeline_raw_instr_reads_local(body[0], 1))
  assert_true(run_hot_pipeline_raw_instrs_have_later_local_write(body, 0, 1))
}

///|
fn legacy_release_read_fixture() -> String {
  "(module (import \"env\" \"combine\" (func $combine (param i32 i32))) (import \"env\" \"release\" (func $release (param i32))) (memory 1) (func (export \"run\") (param i32 i32 i32) (result i32) (local i32 i32 i32 i32) block i32.const 99 local.set 5 local.get 5 drop end local.get 0 i32.load offset=4 local.set 3 local.get 1 local.get 3 i32.ge_s local.set 4 (try (result i32) (do local.get 5) (catch_all i32.const 13)) local.set 6 local.get 0 local.get 1 call $combine local.get 2 if local.get 0 call $release local.get 1 call $release end local.get 4 local.get 6 i32.add))"
}

///|
test "simplify-locals release cleanup retains the value read only in legacy try" {
  let input = pass_test_module_from_wat(legacy_release_read_fixture())
  @validate.validate_module(input).unwrap()
  let output = pass_test_run_pipeline(legacy_release_read_fixture(), [
    "simplify-locals",
  ]).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  let reads : Array[Int] = []
  run_hot_pipeline_simplify_locals_lowered_collect_local_reads(body, reads)
  assert_true(reads.contains(5))
  assert_true(run_hot_pipeline_raw_instrs_have_later_local_write(body, 0, 5))
}
