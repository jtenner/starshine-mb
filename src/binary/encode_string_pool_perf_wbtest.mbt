///|
fn encode_string_pool_bench(
  it : @bench.T,
  width : Int,
  unique : Bool,
  reference : Bool,
) -> Unit {
  let strings : Array[Bytes] = []
  for index = 0; index < width; index = index + 1 {
    let suffix = if unique { index } else { index % 4 }
    strings.push(@utf8.encode("literal-\{suffix}"))
  }
  let mod_ = Module::new().with_stringrefs_sec(StringRefsSec::new(strings))
  let before = encode_module_stringrefs_before_index(mod_)
  let after = encode_module_stringrefs(mod_)
  if before != after || after.length() != (if unique { width } else { 4 }) {
    abort("string pool membership or declaration order changed")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        encode_module_stringrefs_before_index(mod_)
      } else {
        encode_module_stringrefs(mod_)
      },
    )
  })
  if mod_.stringrefs_sec.unwrap().0 != strings {
    abort("string collection mutated the source declarations")
  }
}

///|
test "bench string pool width=4 repeated reference" (it : @bench.T) {
  encode_string_pool_bench(it, 4, false, true)
}

///|
test "bench string pool width=4 repeated indexed" (it : @bench.T) {
  encode_string_pool_bench(it, 4, false, false)
}

///|
test "bench string pool width=4 unique reference" (it : @bench.T) {
  encode_string_pool_bench(it, 4, true, true)
}

///|
test "bench string pool width=4 unique indexed" (it : @bench.T) {
  encode_string_pool_bench(it, 4, true, false)
}

///|
test "bench string pool width=32 repeated reference" (it : @bench.T) {
  encode_string_pool_bench(it, 32, false, true)
}

///|
test "bench string pool width=32 repeated indexed" (it : @bench.T) {
  encode_string_pool_bench(it, 32, false, false)
}

///|
test "bench string pool width=32 unique reference" (it : @bench.T) {
  encode_string_pool_bench(it, 32, true, true)
}

///|
test "bench string pool width=32 unique indexed" (it : @bench.T) {
  encode_string_pool_bench(it, 32, true, false)
}

///|
test "bench string pool width=128 repeated reference" (it : @bench.T) {
  encode_string_pool_bench(it, 128, false, true)
}

///|
test "bench string pool width=128 repeated indexed" (it : @bench.T) {
  encode_string_pool_bench(it, 128, false, false)
}

///|
test "bench string pool width=128 unique reference" (it : @bench.T) {
  encode_string_pool_bench(it, 128, true, true)
}

///|
test "bench string pool width=128 unique indexed" (it : @bench.T) {
  encode_string_pool_bench(it, 128, true, false)
}

///|
test "bench string pool width=1024 repeated reference" (it : @bench.T) {
  encode_string_pool_bench(it, 1024, false, true)
}

///|
test "bench string pool width=1024 repeated indexed" (it : @bench.T) {
  encode_string_pool_bench(it, 1024, false, false)
}

///|
test "bench string pool width=1024 unique reference" (it : @bench.T) {
  encode_string_pool_bench(it, 1024, true, true)
}

///|
test "bench string pool width=1024 unique indexed" (it : @bench.T) {
  encode_string_pool_bench(it, 1024, true, false)
}

///|
test "bench string pool width=4096 repeated reference" (it : @bench.T) {
  encode_string_pool_bench(it, 4096, false, true)
}

///|
test "bench string pool width=4096 repeated indexed" (it : @bench.T) {
  encode_string_pool_bench(it, 4096, false, false)
}

///|
test "bench string pool width=4096 unique reference" (it : @bench.T) {
  encode_string_pool_bench(it, 4096, true, true)
}

///|
test "bench string pool width=4096 unique indexed" (it : @bench.T) {
  encode_string_pool_bench(it, 4096, true, false)
}
