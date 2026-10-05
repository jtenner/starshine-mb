///|
test "dae2 legacy label state uses one frame per nested control" {
  let mut labels = Dae2LegacyLabels::root()
  for _ in 0..<512 {
    labels = labels.push(0, 1)
  }
  assert_eq(labels.resolve(0), 0)
  assert_eq(labels.resolve(511), 511)
  assert_eq(labels.frame_count(), 513)
  let body = labels.push(4, 5)
  assert_eq(body.resolve(0), 4)
  assert_eq(body.resolve(1), 5)
  assert_eq(body.resolve(512), 516)
}

///|
#skip("artifact-scale legacy-label depth probe belongs in the dedicated perf lane")
test "dae2 legacy labels resolve artifact-scale outer depths without recursion" {
  let depth = 32768
  let mut labels = Dae2LegacyLabels::root()
  for _ in 0..<depth {
    labels = labels.push(0, 1)
  }
  assert_eq(labels.frame_count(), depth + 1)
  assert_eq(labels.resolve(0), 0)
  assert_eq(labels.resolve(depth), depth)
  let body = labels.push(7, 9)
  assert_eq(body.resolve(depth + 1), depth + 9)
}
