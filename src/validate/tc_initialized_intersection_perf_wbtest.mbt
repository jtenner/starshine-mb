///|
fn tc_intersection_reference(
  left : Array[Bool],
  right : Array[Bool],
) -> Array[Bool] {
  let out : Array[Bool] = []
  let limit = if left.length() < right.length() {
    left.length()
  } else {
    right.length()
  }
  for i = 0; i < limit; i = i + 1 {
    out.push(left[i] && right[i])
  }
  out
}

///|
fn tc_intersection_bench(it : @bench.T, width : Int, reference : Bool) -> Unit {
  let left = Array::makei(width, fn(i) { i % 5 != 0 })
  let right = Array::makei(width, fn(i) { i % 7 != 0 })
  if tc_intersection_reference(left, right) !=
    tc_initialized_intersection(left, right) {
    abort("initialization mask mismatch")
  }
  it.bench(fn() {
    for _i = 0; _i < 128; _i = _i + 1 {
      it.keep(
        if reference {
          tc_intersection_reference(left, right)
        } else {
          tc_initialized_intersection(left, right)
        },
      )
    }
  })
}

///|
test "bench initialization growing intersection width=17" (it : @bench.T) {
  tc_intersection_bench(it, 17, true)
}

///|
test "bench initialization exact intersection width=17" (it : @bench.T) {
  tc_intersection_bench(it, 17, false)
}

///|
test "bench initialization growing intersection width=2049" (it : @bench.T) {
  tc_intersection_bench(it, 2049, true)
}

///|
test "bench initialization exact intersection width=2049" (it : @bench.T) {
  tc_intersection_bench(it, 2049, false)
}

///|
fn tc_initial_mask_reference(
  params : Array[ValType],
  decls : Locals,
) -> Array[Bool] {
  let out : Array[Bool] = []
  for _ in params {
    out.push(true)
  }
  for run in decls.runs() {
    let defaultable = has_default(run.vt)
    for i = 0; i < run.count.reinterpret_as_int(); i = i + 1 {
      out.push(defaultable)
    }
  }
  out
}

///|
fn tc_initial_mask_bench(it : @bench.T, width : Int, reference : Bool) -> Unit {
  let params = [ValType::i32()]
  let decls = Locals::single((width - 1).to_uint(), ValType::i32())
  if tc_initial_mask_reference(params, decls) !=
    validate_initial_local_initialized(params, decls) {
    abort("initial mask mismatch")
  }
  it.bench(fn() {
    for _i = 0; _i < 128; _i = _i + 1 {
      it.keep(
        if reference {
          tc_initial_mask_reference(params, decls)
        } else {
          validate_initial_local_initialized(params, decls)
        },
      )
    }
  })
}

///|
test "bench initial local growing mask width=17" (it : @bench.T) {
  tc_initial_mask_bench(it, 17, true)
}

///|
test "bench initial local exact mask width=17" (it : @bench.T) {
  tc_initial_mask_bench(it, 17, false)
}

///|
test "bench initial local growing mask width=4096" (it : @bench.T) {
  tc_initial_mask_bench(it, 4096, true)
}

///|
test "bench initial local exact mask width=4096" (it : @bench.T) {
  tc_initial_mask_bench(it, 4096, false)
}
