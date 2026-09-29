///|
fn hot_intern_before_reuse(func : HotFunc, info : HotTypeInfo) -> TypeId {
  let key = info.to_string()
  match func.type_ids.get(key) {
    Some(id) => id
    None => {
      let id = func.types.length()
      func.types.push(info)
      func.type_ids.set(key, id)
      id
    }
  }
}

///|
fn hot_type_intern_reuse_bench(
  it : @bench.T,
  count : Int,
  resolved : Bool,
  reference : Bool,
) -> Unit {
  let func = HotFunc::new()
  let shapes : Array[HotTypeInfo] = []
  for index = 0; index < count; index = index + 1 {
    let info = if resolved {
      HotTypeInfo::BlockResultResolved(
        @lib.BlockType::type_idx(@lib.TypeIdx::new(index.to_uint())),
        [],
        [@lib.ValType::i32(), @lib.ValType::i64()],
      )
    } else {
      HotTypeInfo::Results(Array::make(index + 1, @lib.ValType::i32()))
    }
    shapes.push(info)
    ignore(hot_intern_type(func, info))
  }
  let last = shapes[count - 1]
  let expected = hot_intern_before_reuse(func, last)
  if hot_intern_type(func, last) != expected {
    abort("type identity changed")
  }
  let before = func.types.length()
  it.bench(fn() {
    it.keep(
      if reference {
        hot_intern_before_reuse(func, last)
      } else {
        hot_intern_type(func, last)
      },
    )
  })
  if func.types.length() != before {
    abort("repeated interning added a type")
  }
}

///|
test "bench HOT type interning count=1 tuple reference" (it : @bench.T) {
  hot_type_intern_reuse_bench(it, 1, false, true)
}

///|
test "bench HOT type interning count=1 tuple reuse" (it : @bench.T) {
  hot_type_intern_reuse_bench(it, 1, false, false)
}

///|
test "bench HOT type interning count=1 resolved reference" (it : @bench.T) {
  hot_type_intern_reuse_bench(it, 1, true, true)
}

///|
test "bench HOT type interning count=1 resolved reuse" (it : @bench.T) {
  hot_type_intern_reuse_bench(it, 1, true, false)
}

///|
test "bench HOT type interning count=4 tuple reference" (it : @bench.T) {
  hot_type_intern_reuse_bench(it, 4, false, true)
}

///|
test "bench HOT type interning count=4 tuple reuse" (it : @bench.T) {
  hot_type_intern_reuse_bench(it, 4, false, false)
}

///|
test "bench HOT type interning count=4 resolved reference" (it : @bench.T) {
  hot_type_intern_reuse_bench(it, 4, true, true)
}

///|
test "bench HOT type interning count=4 resolved reuse" (it : @bench.T) {
  hot_type_intern_reuse_bench(it, 4, true, false)
}

///|
test "bench HOT type interning count=15 tuple reference" (it : @bench.T) {
  hot_type_intern_reuse_bench(it, 15, false, true)
}

///|
test "bench HOT type interning count=15 tuple reuse" (it : @bench.T) {
  hot_type_intern_reuse_bench(it, 15, false, false)
}

///|
test "bench HOT type interning count=15 resolved reference" (it : @bench.T) {
  hot_type_intern_reuse_bench(it, 15, true, true)
}

///|
test "bench HOT type interning count=15 resolved reuse" (it : @bench.T) {
  hot_type_intern_reuse_bench(it, 15, true, false)
}

///|
test "bench HOT type interning count=64 tuple reference" (it : @bench.T) {
  hot_type_intern_reuse_bench(it, 64, false, true)
}

///|
test "bench HOT type interning count=64 tuple reuse" (it : @bench.T) {
  hot_type_intern_reuse_bench(it, 64, false, false)
}

///|
test "bench HOT type interning count=64 resolved reference" (it : @bench.T) {
  hot_type_intern_reuse_bench(it, 64, true, true)
}

///|
test "bench HOT type interning count=64 resolved reuse" (it : @bench.T) {
  hot_type_intern_reuse_bench(it, 64, true, false)
}
