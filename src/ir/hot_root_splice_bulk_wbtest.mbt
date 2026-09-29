///|
test "root splice owns aliased replacements and returns the original removed span" {
  let func = HotFunc::new()
  let first = hot_build_nop(func)
  let second = hot_build_nop(func)
  let third = hot_build_nop(func)
  for root in [first, second, third] {
    hot_root_append(func, root)
  }
  let original = hot_root_span(func)
  let revision = hot_revision_current(func)
  let removed = hot_root_splice(func, 0, 3, func.roots)
  assert_eq(removed, original)
  assert_eq(hot_root_span(func), original)
  assert_eq(hot_revision_current(func), revision + 1)
  hot_verify_all_or_abort(func)
}

///|
test "root splice shifts a tail once while preserving insertion and removal order" {
  let func = HotFunc::new()
  let roots = Array::makei(8, fn(_) { hot_build_nop(func) })
  for root in roots {
    hot_root_append(func, root)
  }
  let removed = hot_root_splice(func, 2, 3, [roots[6], roots[0]])
  assert_eq(removed, [roots[2], roots[3], roots[4]])
  assert_eq(hot_root_span(func), [
    roots[0],
    roots[1],
    roots[6],
    roots[0],
    roots[5],
    roots[6],
    roots[7],
  ])
  let removed = hot_root_splice(func, 2, 2, [
    roots[2],
    roots[3],
    roots[4],
    roots[1],
  ])
  assert_eq(removed, [roots[6], roots[0]])
  assert_eq(hot_root_span(func), [
    roots[0],
    roots[1],
    roots[2],
    roots[3],
    roots[4],
    roots[1],
    roots[5],
    roots[6],
    roots[7],
  ])
  hot_verify_all_or_abort(func)
}
