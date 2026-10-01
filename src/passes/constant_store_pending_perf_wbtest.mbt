///|
fn sl_constant_pending_bench(
  it : @bench.T,
  width : Int,
  blocked : Bool,
  sparse : Bool,
  reference : Bool,
) -> Unit raise {
  let stride = if sparse { 128 } else { 1 }
  let stores = Array::makei(width, fn(local) {
    "i32.const 5 local.set \{local * stride}"
  }).join(" ")
  let reads = Array::makei(width, fn(local) {
    "local.get \{local * stride} drop"
  }).join(" ")
  let barriers = if blocked {
    Array::make(width * 4, "call $effect").join(" ")
  } else {
    ""
  }
  let locals = Array::make((width - 1) * stride + 1, "i32").join(" ")
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"effect\" (func $effect)) (func (local \{locals}) \{stores} \{barriers} \{reads}))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(local_types, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let expected = sl_constant_sink_map_reference(body)
  let actual = sl_sink_constant_stores_flat(body)
  assert_eq(actual, expected)
  assert_eq(actual.1, if blocked { 0 } else { width })
  @validate.validate_module(
    input.with_code_sec(
      @lib.CodeSec::new([@lib.Func::new(local_types, @lib.Expr::new(actual.0))]),
    ),
  ).unwrap()
  it.bench(fn() {
    it.keep(
      if reference {
        sl_constant_sink_map_reference(body)
      } else {
        sl_sink_constant_stores_flat(body)
      },
    )
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "bench constant pending pending=1 map predecessor" (it : @bench.T) {
  sl_constant_pending_bench(it, 1, false, false, true)
}

///|
test "bench constant pending pending=1 adaptive" (it : @bench.T) {
  sl_constant_pending_bench(it, 1, false, false, false)
}

///|
test "bench constant pending pending=8 map predecessor" (it : @bench.T) {
  sl_constant_pending_bench(it, 8, false, false, true)
}

///|
test "bench constant pending pending=8 adaptive" (it : @bench.T) {
  sl_constant_pending_bench(it, 8, false, false, false)
}

///|
test "bench constant pending pending=32 map predecessor" (it : @bench.T) {
  sl_constant_pending_bench(it, 32, false, false, true)
}

///|
test "bench constant pending pending=32 adaptive" (it : @bench.T) {
  sl_constant_pending_bench(it, 32, false, false, false)
}

///|
test "bench constant pending pending=512 map predecessor" (it : @bench.T) {
  sl_constant_pending_bench(it, 512, false, false, true)
}

///|
test "bench constant pending pending=512 adaptive" (it : @bench.T) {
  sl_constant_pending_bench(it, 512, false, false, false)
}

///|
test "bench constant pending pending=32 barriers map predecessor" (
  it : @bench.T,
) {
  sl_constant_pending_bench(it, 32, true, false, true)
}

///|
test "bench constant pending pending=32 barriers adaptive" (it : @bench.T) {
  sl_constant_pending_bench(it, 32, true, false, false)
}

///|
test "bench constant pending pending=32 sparse map predecessor" (it : @bench.T) {
  sl_constant_pending_bench(it, 32, false, true, true)
}

///|
test "bench constant pending pending=32 sparse adaptive" (it : @bench.T) {
  sl_constant_pending_bench(it, 32, false, true, false)
}

///|
fn sl_constant_pending_no_work_bench(
  it : @bench.T,
  width : Int,
  reference : Bool,
) -> Unit raise {
  let body : Array[@lib.Instruction] = []
  for _ in 0..<width {
    body.push(@lib.Instruction::i32_const(@lib.I32(3)))
    body.push(@lib.Instruction::i32_const(@lib.I32(4)))
    body.push(@lib.Instruction::i32_add())
    body.push(@lib.Instruction::drop())
  }
  let expected = sl_constant_sink_map_reference(body)
  let actual = sl_sink_constant_stores_flat(body)
  assert_eq(actual, expected)
  assert_eq(actual.1, 0)
  assert_true(physical_equal(actual.0, body))
  let env = @validate.Env::new()
  ignore(
    @validate.Typecheck::typecheck(
      @lib.Expr::new(body),
      @validate.make_state(env, []),
    ).unwrap(),
  )
  it.bench(fn() {
    it.keep(
      if reference {
        sl_constant_sink_map_reference(body)
      } else {
        sl_sink_constant_stores_flat(body)
      },
    )
  })
}

///|
test "bench constant pending no-work=8 map predecessor" (it : @bench.T) {
  sl_constant_pending_no_work_bench(it, 8, true)
}

///|
test "bench constant pending no-work=8 adaptive" (it : @bench.T) {
  sl_constant_pending_no_work_bench(it, 8, false)
}

///|
test "bench constant pending no-work=512 map predecessor" (it : @bench.T) {
  sl_constant_pending_no_work_bench(it, 512, true)
}

///|
test "bench constant pending no-work=512 adaptive" (it : @bench.T) {
  sl_constant_pending_no_work_bench(it, 512, false)
}
