///|
test "dae stable paths append deep prefixes persistently" {
  let mut path = DaeStablePath::empty()
  for value in 0..<512 {
    path = path.append(value)
  }
  assert_eq(path.length(), 512)
  assert_eq(path.to_array(), Array::makei(512, fn(index) { index }))
  let sibling = path.append(999)
  assert_eq(path.length(), 512)
  assert_eq(sibling.length(), 513)
  assert_eq(sibling.to_array().last(), Some(999))
}

///|
test "dae stable paths materialize artifact-scale nesting without recursion" {
  let depth = 32768
  let mut path = DaeStablePath::empty()
  for value in 0..<depth {
    path = path.append(value)
  }
  let materialized = path.to_array()
  assert_eq(materialized.length(), depth)
  assert_eq(materialized[0], 0)
  assert_eq(materialized[depth - 1], depth - 1)
}
