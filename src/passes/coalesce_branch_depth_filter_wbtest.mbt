///|
fn cl_branch_depth_merge_reference(
  depths : Array[Int],
  source : Array[Int],
  shift_outward : Bool,
) -> Unit {
  for depth in source {
    let next = if shift_outward { depth - 1 } else { depth }
    if next >= 0 && !depths.contains(next) {
      depths.push(next)
    }
  }
}

///|
test "branch depth merging retains first-occurrence order through mask collisions and shifts" {
  let rows : Array[Array[Int]] = [
    [],
    [0],
    [0, 1, 1, 3],
    [0, 64, 128, 192, 1, 65, 129, 193],
    Array::makei(65, fn(i) { 64 - i }),
    [0x7fffffff, 63, 64, 127, 128, 63, 0, -1, 1024],
  ]
  for initial in rows {
    for source in rows {
      for shift in [false, true] {
        let saved_initial = initial.copy()
        let expected = initial.copy()
        let actual = initial.copy()
        let saved = source.copy()
        cl_branch_depth_merge_reference(expected, source, shift)
        cl_control_merge_branch_depths(actual, source, shift)
        assert_eq(actual, expected)
        assert_eq(source, saved)
        assert_eq(initial, saved_initial)
      }
    }
  }
}
