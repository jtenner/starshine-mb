///|
test "initialization intersection owns an exact-size independent mask" {
  let left = Array::makei(17, fn(i) { i % 2 == 0 })
  let right = Array::makei(19, fn(i) { i % 3 == 0 })
  let out = tc_initialized_intersection(left, right)
  assert_eq(out.length(), 17)
  assert_eq(out.capacity(), 17)
  for i = 0; i < out.length(); i = i + 1 {
    assert_eq(out[i], i % 6 == 0)
  }
  out[1] = true
  assert_false(left[1])
  assert_false(right[1])
  left[6] = false
  right[12] = false
  assert_true(out[6])
  assert_true(out[12])
}

///|
test "initialization intersection preserves empty and asymmetric inputs" {
  assert_eq(tc_initialized_intersection([], [true]), [])
  assert_eq(tc_initialized_intersection([false], []), [])
  assert_eq(tc_initialized_intersection([true, false, true], [false, true]), [
    false, false,
  ])
  assert_eq(tc_initialized_intersection([true, false], [true, true, true]), [
    true, false,
  ])
}

///|
test "if initialization merge isolates both branch states and retains definite writes" {
  let env = empty_env().with_locals(
    @lib.Locals::new([@lib.LocalRun::new(3U, @lib.ValType::i32())]),
  )
  let entry = make_state(env, [])
  let yes = tc_state_clone(entry)
  let no = tc_state_clone(entry)
  yes.initialized_locals[1] = false
  no.initialized_locals[2] = false
  let merged = tc_state_finish_if(entry, entry, yes, no, []).unwrap()
  assert_eq(merged.initialized_locals, [true, false, false])
  let later = merged.mark_local_initialized(@lib.LocalIdx::new(1U))
  assert_true(later.initialized_locals[1])
  assert_false(yes.initialized_locals[1])
  assert_false(no.initialized_locals[2])
  assert_eq(entry.initialized_locals, [true, true, true])
}

///|
test "initial local mask keeps nonnullable parameters initialized and body locals unset" {
  let nonnull = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::func())),
  )
  let decls = Locals::new([
    @lib.LocalRun::new(15U, ValType::i32()),
    @lib.LocalRun::new(1U, nonnull),
  ])
  let mask = validate_initial_local_initialized([nonnull], decls)
  assert_eq(mask.length(), 17)
  assert_eq(mask.capacity(), 17)
  for i = 0; i < 16; i = i + 1 {
    assert_true(mask[i])
  }
  assert_false(mask[16])
  assert_eq(validate_initial_local_initialized([], Locals::empty()), [])
}
