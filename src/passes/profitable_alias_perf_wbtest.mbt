///|
fn profitable_alias_bench_discover(
  body : Array[@lib.Instruction],
  reads : Array[Int],
  writes : Array[Int],
  reference : Bool,
) -> Dae2ParameterAliases {
  let aliases = Dae2ParameterAliases::new(
    0,
    reads.copy(),
    writes.copy(),
    width_body=Some(body),
  )
  if reference {
    aliases.profitable_reference_discover(body)
  } else {
    aliases.discover(body)
  }
  aliases
}

///|
fn profitable_alias_bench(
  it : @bench.T,
  stable : Int,
  copies : Int,
  tee : Bool,
  multi : Bool,
  reference : Bool,
) -> Unit raise {
  let prefix = Array::makei(stable, fn(i) {
    let slot = copies + i
    "call $produce local.set \{slot} local.get \{slot} call $consume local.get \{slot} call $consume"
  }).join(" ")
  let tail = Array::makei(copies, fn(i) {
    let source = copies + stable + i
    let writer = if tee { "local.tee" } else { "local.set" }
    let immediate = if tee { "call $consume" } else { "" }
    let extra = if multi { "local.get \{i} call $consume" } else { "" }
    "call $produce local.set \{source} local.get \{source} call $consume local.get \{source} \{writer} \{i} \{immediate} block local.get \{i} call $consume \{extra} end"
  }).join(" ")
  let count = stable + copies * 2
  let locals = Array::make(count, "i32").join(" ")
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"produce\" (func $produce (result i32))) (import \"env\" \"consume\" (func $consume (param i32))) (func (local \{locals}) \{prefix} \{tail}))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let reads = Array::make(count, 0)
  let writes = Array::make(count, 0)
  pass_lower_count_locals(body, reads, writes)
  let old = profitable_alias_bench_discover(body, reads, writes, true)
  let new = profitable_alias_bench_discover(body, reads, writes, false)
  for i in 0..<copies {
    assert_eq(old.targets[i] >= 0L, stable < 128)
    assert_eq(new.targets[i] >= 0L, stable < 128 || !multi)
  }
  it.bench(fn() {
    it.keep(profitable_alias_bench_discover(body, reads, writes, reference))
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "bench profitable aliases short reference" (it : @bench.T) {
  profitable_alias_bench(it, 8, 8, false, false, true)
}

///|
test "bench profitable aliases short candidate" (it : @bench.T) {
  profitable_alias_bench(it, 8, 8, false, false, false)
}

///|
test "bench profitable aliases set32 reference" (it : @bench.T) {
  profitable_alias_bench(it, 128, 32, false, false, true)
}

///|
test "bench profitable aliases set32 candidate" (it : @bench.T) {
  profitable_alias_bench(it, 128, 32, false, false, false)
}

///|
test "bench profitable aliases tee32 reference" (it : @bench.T) {
  profitable_alias_bench(it, 128, 32, true, false, true)
}

///|
test "bench profitable aliases tee32 candidate" (it : @bench.T) {
  profitable_alias_bench(it, 128, 32, true, false, false)
}

///|
test "bench profitable aliases multi32 reference" (it : @bench.T) {
  profitable_alias_bench(it, 128, 32, false, true, true)
}

///|
test "bench profitable aliases multi32 candidate" (it : @bench.T) {
  profitable_alias_bench(it, 128, 32, false, true, false)
}

///|
test "bench profitable aliases set64 reference" (it : @bench.T) {
  profitable_alias_bench(it, 128, 64, false, false, true)
}

///|
test "bench profitable aliases set64 candidate" (it : @bench.T) {
  profitable_alias_bench(it, 128, 64, false, false, false)
}

///|
test "bench profitable aliases tee64 reference" (it : @bench.T) {
  profitable_alias_bench(it, 128, 64, true, false, true)
}

///|
test "bench profitable aliases tee64 candidate" (it : @bench.T) {
  profitable_alias_bench(it, 128, 64, true, false, false)
}
