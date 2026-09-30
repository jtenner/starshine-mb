///|
test "raw local counting preserves counts across every child region without changing bodies" {
  let input = pass_test_module_from_wat(
    "(module (tag $t) (func (export \"run\") (param i32) (local i32 i32) block local.get 0 local.set 1 end loop local.get 1 local.tee 2 drop i32.const 0 br_if 0 end local.get 0 if local.get 1 drop else local.get 2 drop end (try (do (local.set 1 (local.get 0))) (catch $t (local.get 2) drop))))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let reads = [3, 5, 7]
  let writes = [11, 13, 17]
  let old_reads = reads.copy()
  let old_writes = writes.copy()
  pass_lower_count_locals(body, reads, writes)
  parameter_alias_reference_pass_lower_count_locals(body, old_reads, old_writes)
  assert_eq(reads, old_reads)
  assert_eq(writes, old_writes)
  assert_eq(reads, [6, 7, 9])
  assert_eq(writes, [11, 15, 18])
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "raw local counting includes try-table bodies and empty siblings" {
  let input = pass_test_module_from_wat(
    "(module (func (export \"run\") (param i32) (local i32) block try_table (catch_all 0) local.get 0 local.set 1 end end local.get 0 if else end))",
  )
  @validate.validate_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let reads = [0, 0]
  let writes = [0, 0]
  pass_lower_count_locals(body, reads, writes)
  assert_eq(reads, [2, 0])
  assert_eq(writes, [0, 1])
}
