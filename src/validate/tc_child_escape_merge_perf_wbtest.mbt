///|
fn tc_child_escape_merge_bench(
  it : @bench.T,
  width : Int32,
  reference : Bool,
) -> Unit raise {
  let left = Array::makei(width, fn(i) { if i % 3 == 0 { 0 } else { i + 1 } })
  let right = Array::makei(width, fn(i) { if i % 5 == 0 { 0 } else { i + 2 } })
  let expected = tc_escape_depths_merge(
    tc_escape_depths_shift_to_parent(left),
    tc_escape_depths_shift_to_parent(right),
  )
  assert_eq(tc_escape_depths_merge_children(left, right), expected)
  it.bench(fn() {
    for _ in 0..<128 {
      it.keep(
        if reference {
          tc_escape_depths_merge(
            tc_escape_depths_shift_to_parent(left),
            tc_escape_depths_shift_to_parent(right),
          )
        } else {
          tc_escape_depths_merge_children(left, right)
        },
      )
    }
  })
}

///|
#skip("manual native child-escape merge timing and allocation controls")
test "bench child escape merge empty reference" (it : @bench.T) {
  tc_child_escape_merge_bench(it, 0, true)
}

///|
#skip("manual native child-escape merge timing and allocation controls")
test "bench child escape merge empty fused" (it : @bench.T) {
  tc_child_escape_merge_bench(it, 0, false)
}

///|
#skip("manual native child-escape merge timing and allocation controls")
test "bench child escape merge width=4 reference" (it : @bench.T) {
  tc_child_escape_merge_bench(it, 4, true)
}

///|
#skip("manual native child-escape merge timing and allocation controls")
test "bench child escape merge width=4 fused" (it : @bench.T) {
  tc_child_escape_merge_bench(it, 4, false)
}

///|
#skip("manual native child-escape merge timing and allocation controls")
test "bench child escape merge width=128 reference" (it : @bench.T) {
  tc_child_escape_merge_bench(it, 128, true)
}

///|
#skip("manual native child-escape merge timing and allocation controls")
test "bench child escape merge width=128 fused" (it : @bench.T) {
  tc_child_escape_merge_bench(it, 128, false)
}
