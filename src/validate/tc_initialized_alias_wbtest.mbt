///|
test "initialization intersection copies aliased masks without redundant comparisons" {
  let source = Array::makei(128, fn(i) { i % 3 == 0 })
  let original = source.copy()
  let checks = [0]
  let output = tc_initialized_intersection(
    source,
    source,
    element_checks=Some(checks),
  )
  assert_eq(output, original)
  assert_eq(output.capacity(), source.length())
  output[1] = true
  assert_false(source[1])
  source[3] = false
  assert_true(output[3])
  assert_eq(checks[0], 0)
  let other = Array::makei(129, fn(i) { i % 5 == 0 })
  let distinct = tc_initialized_intersection(original, other)
  for i in 0..<128 {
    assert_eq(distinct[i], i % 15 == 0)
  }
}
