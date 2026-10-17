///|
test "inlining body cache refreshes an unmarked replacement at the same index" {
  let before = pass_test_module_from_wat("(module (func call 0))")
  let after = pass_test_module_from_wat("(module (func loop nop end))")
  @validate.validate_module(before).unwrap()
  @validate.validate_module(after).unwrap()
  let @lib.Func(_, @lib.Expr(old_body)) = before.code_sec.unwrap().0[0]
  let @lib.Func(_, @lib.Expr(new_body)) = after.code_sec.unwrap().0[0]
  let cache = InlBodyMeasureCache::new(1)
  let visits = [0]
  let expected_old = inl_measure_body(old_body)
  let expected_new = inl_measure_body(new_body)
  assert_true(expected_old != expected_new)
  assert_eq(cache.measure(0, old_body, visits=Some(visits)), expected_old)
  let old_visits = visits[0]
  assert_eq(cache.measure(0, old_body, visits=Some(visits)), expected_old)
  assert_eq(visits[0], old_visits)
  // Optimizing cleanup can replace a body after the rewrite touched mask
  // was computed. Its calls, loops and size must describe the current body.
  assert_eq(cache.measure(0, new_body, visits=Some(visits)), expected_new)
  let refreshed_visits = visits[0]
  let reference_visits = [0]
  ignore(inl_measure_body(new_body, visits=Some(reference_visits)))
  assert_eq(refreshed_visits, old_visits + reference_visits[0])
  assert_eq(cache.measure(0, new_body, visits=Some(visits)), expected_new)
  assert_eq(visits[0], refreshed_visits)
}

///|
test "inlining body cache checks identity after unmarked optimizing cleanup" {
  let input = pass_test_module_from_wat(
    "(module (func (export \"run\") unreachable drop unreachable))",
  )
  @validate.validate_module(input).unwrap()
  let input_bytes = @binary.encode_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(old_body)) = input.code_sec.unwrap().0[0]
  let cache = InlBodyMeasureCache::new(1)
  let visits = [0]
  assert_eq(
    cache.measure(0, old_body, visits=Some(visits)),
    (false, false, false, false, 3),
  )
  let old_visits = visits[0]
  let cleaned = inl_prune_dead_unreachable_drops(input)
  @validate.validate_module(cleaned).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), input_bytes)
  let @lib.Func(_, @lib.Expr(new_body)) = cleaned.code_sec.unwrap().0[0]
  assert_eq(new_body, [@lib.Instruction::unreachable_()])
  assert_false(physical_equal(old_body, new_body))
  // This cleanup is deliberately not scoped by the call-rewrite touched mask.
  // A retained cache entry must still reject the replacement body's identity.
  cache.remap([false], [0])
  assert_eq(
    cache.measure(0, new_body, visits=Some(visits)),
    (false, false, false, false, 1),
  )
  assert_eq(visits[0], old_visits + 1)
  assert_eq(
    cache.measure(0, new_body, visits=Some(visits)),
    inl_measure_body(new_body),
  )
  assert_eq(visits[0], old_visits + 1)
}

///|
test "optimizing body cache refreshes structured scratch after in-place cleanup" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) loop local.get 0 local.set 0 end))",
  )
  @validate.validate_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(original)) = input.code_sec.unwrap().0[0]
  let scratch = cl_deep_copy_instrs(original)
  let cache = InlBodyMeasureCache::new(1, flat_only=true)
  let visits = [0]
  assert_eq(
    cache.measure(0, scratch, visits=Some(visits)),
    (false, true, false, false, 3),
  )
  assert_true(cl_remove_redundant_copy_pairs(scratch))
  assert_eq(
    cache.measure(0, scratch, visits=Some(visits)),
    (false, true, false, false, 2),
  )
  assert_eq(visits[0], 5)
  assert_eq(inl_measure_body(original), (false, true, false, false, 3))
  let flat = [@lib.Instruction::nop()]
  assert_eq(
    cache.measure(0, flat, visits=Some(visits)),
    (false, false, false, false, 1),
  )
  let first_flat_visits = visits[0]
  assert_eq(
    cache.measure(0, flat, visits=Some(visits)),
    (false, false, false, false, 1),
  )
  assert_eq(visits[0], first_flat_visits)
}
