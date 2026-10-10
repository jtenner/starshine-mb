///|
test "unread tee cleanup retains unchanged nested regions and leaves the source intact" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (local i32) block local.get 0 drop end block i32.const 3 local.tee 1 drop end block local.get 0 drop end))",
  )
  let before = @binary.encode_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let (rewritten, count) = run_hot_pipeline_raw_simplify_locals_remove_unread_local_tees(
    body,
    [2, 0],
  )
  @debug.assert_eq(count, 1)
  assert_true(!physical_equal(body, rewritten))
  assert_true(physical_equal(body[0], rewritten[0]))
  assert_true(physical_equal(body[2], rewritten[2]))
  @debug.assert_eq(@binary.encode_module(input).unwrap(), before)
  let (unchanged, no_changes) = run_hot_pipeline_raw_simplify_locals_remove_unread_local_tees(
    rewritten,
    [2, 0],
  )
  @debug.assert_eq(no_changes, 0)
  assert_true(physical_equal(unchanged, rewritten))
}

///|
test "unread tee cleanup preserves an untouched conditional arm under copy-on-write" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (local i32) local.get 0 if i32.const 3 local.tee 1 drop else local.get 0 drop end))",
  )
  let before = @binary.encode_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let (rewritten, count) = run_hot_pipeline_raw_simplify_locals_remove_unread_local_tees(
    body,
    [2, 0],
  )
  @debug.assert_eq(count, 1)
  match (body[1], rewritten[1]) {
    (@lib.If(_, old_then, Some(old_else)), @lib.If(_, new_then, Some(new_else))) => {
      assert_true(!physical_equal(old_then, new_then))
      assert_true(physical_equal(old_else, new_else))
    }
    _ => fail("expected retained conditional")
  }
  @debug.assert_eq(@binary.encode_module(input).unwrap(), before)
}

///|
#skip
test "unread tee proof intentionally rejects oversized compressed declaration-run lists" {
  // Dedicated resource-boundary control, not an optimizer workload or default stress test.
  let locals = @lib.Locals::from_decl_runs_preserving_groups(
    Array::make(65537, @lib.LocalRun::new(0U, @lib.ValType::i32())),
  )
  @debug.assert_eq(
    run_hot_pipeline_vacuum_unread_tee_local_count(0, locals),
    None,
  )
}

///|
test "unread tee cleanup never mutates a child shared by multiple parents" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (local i32) block local.get 0 drop i32.const 3 local.tee 1 drop end))",
  )
  let @lib.Func(locals, @lib.Expr(old_body)) = input.code_sec.unwrap().0[0]
  let body = [old_body[0], old_body[0]]
  let shared_input = input.with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]),
  )
  let before = @binary.encode_module(shared_input).unwrap()
  let (rewritten, count) = run_hot_pipeline_raw_simplify_locals_remove_unread_local_tees(
    body,
    [2, 0],
  )
  @debug.assert_eq(count, 2)
  match (rewritten[0], rewritten[1]) {
    (@lib.Block(_, @lib.Expr(left)), @lib.Block(_, @lib.Expr(right))) =>
      assert_true(!physical_equal(left, right))
    _ => fail("expected distinct changed control bodies")
  }
  @debug.assert_eq(@binary.encode_module(shared_input).unwrap(), before)
  let candidate = shared_input.with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(rewritten))]),
  )
  let output = run_hot_pipeline(candidate, HotPipelineOptions::new(), [
    "reorder-locals",
  ]).unwrap()
  @validate.validate_module(output).unwrap()
  @debug.assert_eq(@binary.encode_module(shared_input).unwrap(), before)
}
