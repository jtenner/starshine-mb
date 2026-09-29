///|
fn hot_type_arity_bench(
  it : @bench.T,
  width : Int,
  resolved : Bool,
  reference : Bool,
) -> Unit {
  let func = HotFunc::new()
  let values = Array::make(width, @lib.ValType::i32())
  let ty = if resolved {
    hot_type_intern_resolved_block_result(
      func,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      [],
      values,
    )
  } else if width == 0 {
    hot_type_intern_void(func)
  } else if width == 1 {
    hot_type_intern_value(func, @lib.ValType::i32())
  } else {
    hot_type_intern_results(func, values)
  }
  if hot_type_result_arity(func, ty) != hot_type_results(func, ty).length() {
    abort("result arity changed")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        hot_type_results(func, ty).length()
      } else {
        hot_type_result_arity(func, ty)
      },
    )
  })
  if hot_type_results(func, ty) != values {
    abort("query changed the type")
  }
}

///|
test "bench HOT arity width=0 ordinary reference" (it : @bench.T) {
  hot_type_arity_bench(it, 0, false, true)
}

///|
test "bench HOT arity width=0 ordinary direct" (it : @bench.T) {
  hot_type_arity_bench(it, 0, false, false)
}

///|
test "bench HOT arity width=1 ordinary reference" (it : @bench.T) {
  hot_type_arity_bench(it, 1, false, true)
}

///|
test "bench HOT arity width=1 ordinary direct" (it : @bench.T) {
  hot_type_arity_bench(it, 1, false, false)
}

///|
test "bench HOT arity width=4 ordinary reference" (it : @bench.T) {
  hot_type_arity_bench(it, 4, false, true)
}

///|
test "bench HOT arity width=4 ordinary direct" (it : @bench.T) {
  hot_type_arity_bench(it, 4, false, false)
}

///|
test "bench HOT arity width=64 ordinary reference" (it : @bench.T) {
  hot_type_arity_bench(it, 64, false, true)
}

///|
test "bench HOT arity width=64 ordinary direct" (it : @bench.T) {
  hot_type_arity_bench(it, 64, false, false)
}

///|
test "bench HOT arity width=1024 ordinary reference" (it : @bench.T) {
  hot_type_arity_bench(it, 1024, false, true)
}

///|
test "bench HOT arity width=1024 ordinary direct" (it : @bench.T) {
  hot_type_arity_bench(it, 1024, false, false)
}

///|
test "bench HOT arity width=0 resolved reference" (it : @bench.T) {
  hot_type_arity_bench(it, 0, true, true)
}

///|
test "bench HOT arity width=0 resolved direct" (it : @bench.T) {
  hot_type_arity_bench(it, 0, true, false)
}

///|
test "bench HOT arity width=4 resolved reference" (it : @bench.T) {
  hot_type_arity_bench(it, 4, true, true)
}

///|
test "bench HOT arity width=4 resolved direct" (it : @bench.T) {
  hot_type_arity_bench(it, 4, true, false)
}

///|
test "bench HOT arity width=1024 resolved reference" (it : @bench.T) {
  hot_type_arity_bench(it, 1024, true, true)
}

///|
test "bench HOT arity width=1024 resolved direct" (it : @bench.T) {
  hot_type_arity_bench(it, 1024, true, false)
}
