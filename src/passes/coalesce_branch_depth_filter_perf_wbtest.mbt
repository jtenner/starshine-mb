///|
fn cl_branch_depth_filter_bench(
  it : @bench.T,
  count : Int,
  collisions : Bool,
  overlap? : Bool = false,
) -> Unit {
  let initial = Array::makei(count, fn(i) {
    i * (if collisions { 64 } else { 1 })
  })
  let source = Array::makei(count, fn(i) {
    (if overlap { i } else { count + i }) * (if collisions { 64 } else { 1 })
  })
  let expected = initial.copy()
  cl_branch_depth_merge_reference(expected, source, false)
  let actual = initial.copy()
  cl_control_merge_branch_depths(actual, source, false)
  if actual != expected {
    abort("branch depth filter changed ordered union")
  }
  it.bench(fn() {
    let depths = initial.copy()
    cl_control_merge_branch_depths(depths, source, false)
    it.keep(depths)
  })
}

///|
test "bench branch depth filter tiny distinct" (it : @bench.T) {
  cl_branch_depth_filter_bench(it, 2, false)
}

///|
test "bench branch depth filter wide distinct" (it : @bench.T) {
  cl_branch_depth_filter_bench(it, 32, false)
}

///|
test "bench branch depth filter tiny collisions" (it : @bench.T) {
  cl_branch_depth_filter_bench(it, 2, true)
}

///|
test "bench branch depth filter wide collisions" (it : @bench.T) {
  cl_branch_depth_filter_bench(it, 32, true)
}

///|
test "bench branch depth filter wide overlap" (it : @bench.T) {
  cl_branch_depth_filter_bench(it, 32, false, overlap=true)
}

///|
test "bench branch depth filter wide colliding overlap" (it : @bench.T) {
  cl_branch_depth_filter_bench(it, 32, true, overlap=true)
}
