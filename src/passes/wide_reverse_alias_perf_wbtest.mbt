///|
fn wide_reverse_alias_perf_discover(
  body : Array[@lib.Instruction],
  reads : Array[Int],
  writes : Array[Int],
  bounded : Bool,
) -> Dae2ParameterAliases {
  let aliases = Dae2ParameterAliases::new(
    0,
    reads.copy(),
    writes.copy(),
    width_body=if bounded { Some(body) } else { None },
  )
  aliases.discover(body)
  aliases
}

///|
fn wide_reverse_alias_perf_run(
  it : @bench.T,
  stable : Int,
  copies : Int,
  bounded : Bool,
) -> Unit raise {
  let prefix = Array::makei(stable, fn(i) {
    "call $produce local.set \{i} local.get \{i} call $consume local.get \{i} call $consume"
  }).join(" ")
  let pairs = Array::makei(copies, fn(i) {
    let target = stable + i * 2
    let source = target + 1
    "call $produce local.set \{source} local.get \{source} call $consume local.get \{source} local.set \{target} local.get \{target} call $consume local.get \{target} call $consume"
  }).join(" ")
  let count = stable + copies * 2
  let locals = Array::make(count, "i32").join(" ")
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"produce\" (func $produce (result i32))) (import \"env\" \"consume\" (func $consume (param i32))) (func (local \{locals}) \{prefix} \{pairs}))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let reads = Array::make(count, 0)
  let writes = Array::make(count, 0)
  pass_lower_count_locals(body, reads, writes)
  let old = wide_reverse_alias_perf_discover(body, reads, writes, false)
  let new = wide_reverse_alias_perf_discover(body, reads, writes, true)
  for i in 0..<copies {
    let target = stable + i * 2
    assert_eq(old.targets[target] >= 0L, target + 1 < 128)
    assert_true(new.targets[target] >= 0L)
    assert_eq(new.reads[target], 0)
  }
  assert_eq(new.index_bounds is Some(_), stable >= 128)
  let (out, indices) = reverse_alias_compact(input)
  let @lib.Func(retained, _) = out
  assert_eq(retained.length(), stable + copies)
  for i in 0..<copies {
    assert_eq(indices[stable + i * 2], -1)
  }
  it.bench(fn() {
    it.keep(wide_reverse_alias_perf_discover(body, reads, writes, bounded))
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "bench wide aliases short 8 legacy" (it : @bench.T) {
  wide_reverse_alias_perf_run(it, 0, 8, false)
}

///|
test "bench wide aliases short 8 bounded" (it : @bench.T) {
  wide_reverse_alias_perf_run(it, 0, 8, true)
}

///|
test "bench wide aliases two byte 8 legacy" (it : @bench.T) {
  wide_reverse_alias_perf_run(it, 128, 8, false)
}

///|
test "bench wide aliases two byte 8 bounded" (it : @bench.T) {
  wide_reverse_alias_perf_run(it, 128, 8, true)
}

///|
test "bench wide aliases two byte 512 legacy" (it : @bench.T) {
  wide_reverse_alias_perf_run(it, 128, 512, false)
}

///|
test "bench wide aliases two byte 512 bounded" (it : @bench.T) {
  wide_reverse_alias_perf_run(it, 128, 512, true)
}

///|
test "bench wide aliases two byte 4096 legacy" (it : @bench.T) {
  wide_reverse_alias_perf_run(it, 128, 4096, false)
}

///|
test "bench wide aliases two byte 4096 bounded" (it : @bench.T) {
  wide_reverse_alias_perf_run(it, 128, 4096, true)
}

///|
test "bench wide aliases three byte 8 legacy" (it : @bench.T) {
  wide_reverse_alias_perf_run(it, 16384, 8, false)
}

///|
test "bench wide aliases three byte 8 bounded" (it : @bench.T) {
  wide_reverse_alias_perf_run(it, 16384, 8, true)
}
