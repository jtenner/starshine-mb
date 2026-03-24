///|
fn bitset_test_collect(bitset : Bitset) -> Array[Int] {
  let out : Array[Int] = []
  bitset_for_each_set_bit(bitset, fn(idx) { out.push(idx) })
  out
}

///|
test "bitset set clear and contains handle edge-aligned sizes" {
  let empty = bitset_new(0)
  let one = bitset_new(1)
  let sixty_three = bitset_new(63)
  let sixty_four = bitset_new(64)
  let sixty_five = bitset_new(65)

  assert_eq(bitset_test_collect(empty), [])

  assert_true(bitset_set(one, 0))
  assert_true(bitset_contains(one, 0))
  assert_false(bitset_set(one, 0))
  assert_true(bitset_clear(one, 0))
  assert_false(bitset_contains(one, 0))

  ignore(bitset_set(sixty_three, 62))
  ignore(bitset_set(sixty_four, 63))
  ignore(bitset_set(sixty_five, 64))
  assert_eq(bitset_test_collect(sixty_three), [62])
  assert_eq(bitset_test_collect(sixty_four), [63])
  assert_eq(bitset_test_collect(sixty_five), [64])
}

///|
test "bitset union intersection and difference stay masked and report changes" {
  let lhs = bitset_new(65)
  let rhs = bitset_new(65)
  ignore(bitset_set(lhs, 1))
  ignore(bitset_set(lhs, 64))
  ignore(bitset_set(rhs, 1))
  ignore(bitset_set(rhs, 63))

  assert_true(bitset_union_into(lhs, rhs))
  assert_eq(bitset_test_collect(lhs), [1, 63, 64])
  assert_false(bitset_union_into(lhs, rhs))

  let intersection = bitset_new(65)
  ignore(bitset_set(intersection, 1))
  ignore(bitset_set(intersection, 64))
  assert_true(bitset_intersect_into(intersection, rhs))
  assert_eq(bitset_test_collect(intersection), [1])

  assert_true(bitset_difference_into(lhs, rhs))
  assert_eq(bitset_test_collect(lhs), [64])
  assert_false(bitset_difference_into(lhs, rhs))
}

///|
test "bitset equality and iteration order stay deterministic" {
  let a = bitset_new(70)
  let b = bitset_new(70)
  for idx in [65, 1, 63, 64, 0] {
    ignore(bitset_set(a, idx))
    ignore(bitset_set(b, idx))
  }

  assert_true(bitset_equals(a, b))
  ignore(bitset_clear(b, 63))
  assert_false(bitset_equals(a, b))
  assert_eq(bitset_test_collect(a), [0, 1, 63, 64, 65])
}
