///|
test "inlining body facts survive index remapping and invalidate changed bodies" {
  let input = pass_test_module_from_wat(
      (
        #|(module
        #| (func nop)
        #| (func loop nop end)
        #| (func call 0))
      ),
    ).code_sec.unwrap().0
  let cache = InlBodyMeasureCache::new(3)
  let visits = [0]
  for index in 0..<3 {
    let @lib.Func(_, @lib.Expr(body)) = input[index]
    assert_eq(
      cache.measure(index, body, visits=Some(visits)),
      inl_measure_body(body),
    )
  }
  let first_visits = visits[0]
  assert_true(first_visits > 0)
  cache.remap([false, true, false], [2, 1])
  let @lib.Func(_, @lib.Expr(unchanged)) = input[2]
  assert_eq(
    cache.measure(0, unchanged, visits=Some(visits)),
    inl_measure_body(unchanged),
  )
  assert_eq(visits[0], first_visits)
  let changed = [@lib.Instruction::nop()]
  assert_eq(
    cache.measure(1, changed, visits=Some(visits)),
    (false, false, false, false, 1),
  )
  assert_eq(visits[0], first_visits + 1)
}
