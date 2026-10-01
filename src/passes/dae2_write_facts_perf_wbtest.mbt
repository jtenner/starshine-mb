///|
fn dae2_writefacts_bench(
  it : @bench.T,
  width : Int,
  mode : Int,
  reference : Bool,
) -> Unit raise {
  let parts : Array[String] = []
  if mode == 1 {
    parts.push("i32.const 7 local.set 0")
  }
  for local in 0..<width {
    if mode == 2 {
      parts.push("i32.const 7 local.set \{local}")
    }
    parts.push("local.get \{local} drop")
  }
  if mode == 3 {
    parts.push(
      "i32.const 7 local.set 0 try_table (result i32) local.get 0 end drop",
    )
  }
  parts.push("local.get 0")
  let locals = Array::make(width, "i32").join(" ")
  let text = parts.join(" ")
  let input = pass_test_module_from_wat(
    "(module (func (result i32) (local \{locals}) \{text}))",
  )
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let before = @ir.hot_lower_func(func)
  dae2_writefacts_assert_same(
    dae2_writefacts_graph(func, false),
    dae2_writefacts_graph(func, true),
  )
  it.bench(fn() { it.keep(dae2_writefacts_graph(func, reference)) })
  assert_eq(@ir.hot_lower_func(func), before)
}

///|
test "bench DAE2 write facts immutable tiny V78 predecessor" (it : @bench.T) {
  dae2_writefacts_bench(it, 1, 0, true)
}

///|
test "bench DAE2 write facts immutable tiny shared census" (it : @bench.T) {
  dae2_writefacts_bench(it, 1, 0, false)
}

///|
test "bench DAE2 write facts immutable wide V78 predecessor" (it : @bench.T) {
  dae2_writefacts_bench(it, 512, 0, true)
}

///|
test "bench DAE2 write facts immutable wide shared census" (it : @bench.T) {
  dae2_writefacts_bench(it, 512, 0, false)
}

///|
test "bench DAE2 write facts single tiny V78 predecessor" (it : @bench.T) {
  dae2_writefacts_bench(it, 1, 1, true)
}

///|
test "bench DAE2 write facts single tiny shared census" (it : @bench.T) {
  dae2_writefacts_bench(it, 1, 1, false)
}

///|
test "bench DAE2 write facts single wide V78 predecessor" (it : @bench.T) {
  dae2_writefacts_bench(it, 512, 1, true)
}

///|
test "bench DAE2 write facts single wide shared census" (it : @bench.T) {
  dae2_writefacts_bench(it, 512, 1, false)
}

///|
test "bench DAE2 write facts distinct roots V78 predecessor" (it : @bench.T) {
  dae2_writefacts_bench(it, 32, 2, true)
}

///|
test "bench DAE2 write facts distinct roots shared census" (it : @bench.T) {
  dae2_writefacts_bench(it, 32, 2, false)
}

///|
test "bench DAE2 write facts opaque wide V78 predecessor" (it : @bench.T) {
  dae2_writefacts_bench(it, 512, 3, true)
}

///|
test "bench DAE2 write facts opaque wide shared census" (it : @bench.T) {
  dae2_writefacts_bench(it, 512, 3, false)
}
