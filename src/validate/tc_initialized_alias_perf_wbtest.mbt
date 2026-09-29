///|
fn tc_alias_intersection_reference(
  left : Array[Bool],
  right : Array[Bool],
) -> Array[Bool] {
  let limit = if left.length() < right.length() {
    left.length()
  } else {
    right.length()
  }
  Array::makei(limit, fn(i) { left[i] && right[i] })
}

///|
fn tc_alias_intersection_bench(
  it : @bench.T,
  width : Int,
  alias : Bool,
  reference : Bool,
) -> Unit {
  let left = Array::makei(width, fn(i) { i % 3 == 0 })
  let right = if alias {
    left
  } else {
    Array::makei(width + 1, fn(i) { i % 5 == 0 })
  }
  let original = left.copy()
  let output = tc_initialized_intersection(left, right)
  if output != tc_alias_intersection_reference(left, right) {
    abort("intersection mismatch")
  }
  output[1] = true
  if left != original {
    abort("intersection mutated its borrowed input")
  }
  it.bench(fn() {
    for _ in 0..<128 {
      it.keep(
        if reference {
          tc_alias_intersection_reference(left, right)
        } else {
          tc_initialized_intersection(left, right)
        },
      )
    }
  })
}

///|
test "bench intersection alias=true width=16 reference" (it : @bench.T) {
  tc_alias_intersection_bench(it, 16, true, true)
}

///|
test "bench intersection alias=true width=16 owned-copy" (it : @bench.T) {
  tc_alias_intersection_bench(it, 16, true, false)
}

///|
test "bench intersection alias=false width=16 reference" (it : @bench.T) {
  tc_alias_intersection_bench(it, 16, false, true)
}

///|
test "bench intersection alias=false width=16 owned-copy" (it : @bench.T) {
  tc_alias_intersection_bench(it, 16, false, false)
}

///|
test "bench intersection alias=true width=128 reference" (it : @bench.T) {
  tc_alias_intersection_bench(it, 128, true, true)
}

///|
test "bench intersection alias=true width=128 owned-copy" (it : @bench.T) {
  tc_alias_intersection_bench(it, 128, true, false)
}

///|
test "bench intersection alias=false width=128 reference" (it : @bench.T) {
  tc_alias_intersection_bench(it, 128, false, true)
}

///|
test "bench intersection alias=false width=128 owned-copy" (it : @bench.T) {
  tc_alias_intersection_bench(it, 128, false, false)
}

///|
test "bench intersection alias=true width=4096 reference" (it : @bench.T) {
  tc_alias_intersection_bench(it, 4096, true, true)
}

///|
test "bench intersection alias=true width=4096 owned-copy" (it : @bench.T) {
  tc_alias_intersection_bench(it, 4096, true, false)
}

///|
test "bench intersection alias=false width=4096 reference" (it : @bench.T) {
  tc_alias_intersection_bench(it, 4096, false, true)
}

///|
test "bench intersection alias=false width=4096 owned-copy" (it : @bench.T) {
  tc_alias_intersection_bench(it, 4096, false, false)
}
