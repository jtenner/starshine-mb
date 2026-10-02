///|
fn sl_suffix_storage_bench(
  it : @bench.T,
  width : Int,
  shape : Int,
  effectful : Bool,
  reference : Bool,
) -> Unit raise {
  let producer = if effectful { "call $produce" } else { "i32.const 7" }
  let fragment = match shape {
    0 => "call $produce call $consume nop"
    1 =>
      "block loop i32.const 1 if call $produce call $consume else call $tick end end end"
    _ => "block \{producer} local.set 0 nop local.get 0 call $consume end"
  }
  let (input, env, body) = sl_balanced_range_fixture(
    Array::make(width, fragment).join(" "),
    "i32",
  )
  let (rewrite, original) = if effectful {
    (
      run_hot_pipeline_raw_simplify_locals_rewrite_effectful_suffix_local_gets, sl_suffix_storage_reference_effectful_suffix_local_gets,
    )
  } else {
    (
      run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets, sl_suffix_storage_reference_pure_suffix_local_sets,
    )
  }
  let expected = original(body, env)
  let actual = rewrite(body, env)
  assert_eq(actual, expected)
  if shape < 2 {
    assert_eq(actual.1, 0)
  } else {
    assert_eq(actual.1, width)
  }
  let saved = @binary.encode_module(input).unwrap()
  it.bench(fn() {
    it.keep(if reference { original(body, env) } else { rewrite(body, env) })
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "bench suffix storage pure tiny original" (it : @bench.T) {
  sl_suffix_storage_bench(it, 1, 0, false, true)
}

///|
test "bench suffix storage pure tiny borrowed" (it : @bench.T) {
  sl_suffix_storage_bench(it, 1, 0, false, false)
}

///|
test "bench suffix storage pure wide128 original" (it : @bench.T) {
  sl_suffix_storage_bench(it, 128, 0, false, true)
}

///|
test "bench suffix storage pure wide128 borrowed" (it : @bench.T) {
  sl_suffix_storage_bench(it, 128, 0, false, false)
}

///|
test "bench suffix storage pure nested128 original" (it : @bench.T) {
  sl_suffix_storage_bench(it, 128, 1, false, true)
}

///|
test "bench suffix storage pure nested128 borrowed" (it : @bench.T) {
  sl_suffix_storage_bench(it, 128, 1, false, false)
}

///|
test "bench suffix storage pure active16 original" (it : @bench.T) {
  sl_suffix_storage_bench(it, 16, 2, false, true)
}

///|
test "bench suffix storage pure active16 borrowed" (it : @bench.T) {
  sl_suffix_storage_bench(it, 16, 2, false, false)
}

///|
test "bench suffix storage effectful tiny original" (it : @bench.T) {
  sl_suffix_storage_bench(it, 1, 0, true, true)
}

///|
test "bench suffix storage effectful tiny borrowed" (it : @bench.T) {
  sl_suffix_storage_bench(it, 1, 0, true, false)
}

///|
test "bench suffix storage effectful wide128 original" (it : @bench.T) {
  sl_suffix_storage_bench(it, 128, 0, true, true)
}

///|
test "bench suffix storage effectful wide128 borrowed" (it : @bench.T) {
  sl_suffix_storage_bench(it, 128, 0, true, false)
}

///|
test "bench suffix storage effectful nested128 original" (it : @bench.T) {
  sl_suffix_storage_bench(it, 128, 1, true, true)
}

///|
test "bench suffix storage effectful nested128 borrowed" (it : @bench.T) {
  sl_suffix_storage_bench(it, 128, 1, true, false)
}

///|
test "bench suffix storage effectful active16 original" (it : @bench.T) {
  sl_suffix_storage_bench(it, 16, 2, true, true)
}

///|
test "bench suffix storage effectful active16 borrowed" (it : @bench.T) {
  sl_suffix_storage_bench(it, 16, 2, true, false)
}
