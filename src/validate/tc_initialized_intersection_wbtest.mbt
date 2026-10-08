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
test "if exit restores entry initialization and later writes isolate all masks" {
  let nonnull = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::func())),
  )
  let env = empty_env().with_locals(
    Locals::from_types([ValType::i32(), nonnull, nonnull]),
  )
  let entry = TcState::{
    ..make_state(env, []),
    initialized_locals: [true, false, false],
  }
  let yes = tc_state_clone(entry).mark_local_initialized(LocalIdx::new(1U))
  let no = tc_state_clone(entry).mark_local_initialized(LocalIdx::new(1U))
  let merged = tc_state_finish_if(entry, entry, yes, no, []).unwrap()
  // Each arm writes local 1, but its initialization scope ends with the if.
  assert_true(yes.initialized_locals[1])
  assert_true(no.initialized_locals[1])
  assert_eq(merged.initialized_locals, [true, false, false])
  assert_true(
    physical_equal(merged.initialized_locals, entry.initialized_locals),
  )
  let later = merged.mark_local_initialized(LocalIdx::new(2U))
  assert_eq(later.initialized_locals, [true, false, true])
  assert_false(yes.initialized_locals[2])
  assert_false(no.initialized_locals[2])
  assert_eq(merged.initialized_locals, [true, false, false])
  assert_eq(entry.initialized_locals, [true, false, false])
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
