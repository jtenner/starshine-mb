///|
let string_index_before_context : Ref[Array[Bytes]?] = Ref::new(None)

///|
fn string_index_before_lookup(
  bytes : Bytes,
) -> Result[@lib.U32, BinaryEncodeError] {
  match string_index_before_context.val {
    Some(strings) => {
      for index = 0; index < strings.length(); index = index + 1 {
        if strings[index] == bytes {
          return Ok(@lib.U32(index.to_uint()))
        }
      }
      Err(BinaryEncodeError::StringConstLiteralMissingFromSection)
    }
    None => Err(BinaryEncodeError::CannotEncodeStringConstWithoutModuleContext)
  }
}

///|
fn string_index_before_scope(
  strings : Array[Bytes],
  f : () -> Result[Int, BinaryEncodeError],
) -> Result[Int, BinaryEncodeError] {
  let saved = string_index_before_context.val
  string_index_before_context.val = Some(strings)
  let result = f()
  string_index_before_context.val = saved
  result
}

///|
fn string_index_bench(
  it : @bench.T,
  width : Int,
  mode : Int,
  reference : Bool,
) -> Unit {
  let strings : Array[Bytes] = []
  for index = 0; index < width; index = index + 1 {
    strings.push(@utf8.encode("literal-\{index}"))
  }
  let expected = if mode == 0 {
    0
  } else if mode == 1 {
    width * (width - 1)
  } else {
    width * (width - 1) / 2
  }
  fn query() -> Result[Int, BinaryEncodeError] {
    let mut total = 0
    for index = 0; index < width; index = index + 1 {
      let pos = if mode == 0 {
        0
      } else if mode == 1 {
        width - 1
      } else {
        index
      }
      let result = if reference {
        string_index_before_lookup(strings[pos])
      } else {
        encode_string_const_index(strings[pos])
      }
      match result {
        Ok(@lib.U32(value)) => total += value.to_int()
        Err(err) => return Err(err)
      }
    }
    Ok(total)
  }
  fn run() -> Result[Int, BinaryEncodeError] {
    if reference {
      string_index_before_scope(strings, query)
    } else {
      with_binary_encode_stringrefs_context(Some(strings), query)
    }
  }
  if run() != Ok(expected) {
    abort("string index order changed")
  }
  it.bench(fn() { it.keep(run()) })
}

///|
test "bench string index width=4 first reference" (it : @bench.T) {
  string_index_bench(it, 4, 0, true)
}

///|
test "bench string index width=4 first indexed" (it : @bench.T) {
  string_index_bench(it, 4, 0, false)
}

///|
test "bench string index width=4 last reference" (it : @bench.T) {
  string_index_bench(it, 4, 1, true)
}

///|
test "bench string index width=4 last indexed" (it : @bench.T) {
  string_index_bench(it, 4, 1, false)
}

///|
test "bench string index width=4 all reference" (it : @bench.T) {
  string_index_bench(it, 4, 2, true)
}

///|
test "bench string index width=4 all indexed" (it : @bench.T) {
  string_index_bench(it, 4, 2, false)
}

///|
test "bench string index width=128 first reference" (it : @bench.T) {
  string_index_bench(it, 128, 0, true)
}

///|
test "bench string index width=128 first indexed" (it : @bench.T) {
  string_index_bench(it, 128, 0, false)
}

///|
test "bench string index width=128 last reference" (it : @bench.T) {
  string_index_bench(it, 128, 1, true)
}

///|
test "bench string index width=128 last indexed" (it : @bench.T) {
  string_index_bench(it, 128, 1, false)
}

///|
test "bench string index width=128 all reference" (it : @bench.T) {
  string_index_bench(it, 128, 2, true)
}

///|
test "bench string index width=128 all indexed" (it : @bench.T) {
  string_index_bench(it, 128, 2, false)
}

///|
test "bench string index width=4096 first reference" (it : @bench.T) {
  string_index_bench(it, 4096, 0, true)
}

///|
test "bench string index width=4096 first indexed" (it : @bench.T) {
  string_index_bench(it, 4096, 0, false)
}

///|
test "bench string index width=4096 last reference" (it : @bench.T) {
  string_index_bench(it, 4096, 1, true)
}

///|
test "bench string index width=4096 last indexed" (it : @bench.T) {
  string_index_bench(it, 4096, 1, false)
}

///|
test "bench string index width=4096 all reference" (it : @bench.T) {
  string_index_bench(it, 4096, 2, true)
}

///|
test "bench string index width=4096 all indexed" (it : @bench.T) {
  string_index_bench(it, 4096, 2, false)
}

///|
fn string_pool_index_bench(
  it : @bench.T,
  width : Int,
  reference : Bool,
) -> Unit {
  let strings : Array[Bytes] = []
  for index = 0; index < width; index = index + 1 {
    strings.push(@utf8.encode("literal-\{index}"))
  }
  let mod_ = Module::new().with_stringrefs_sec(StringRefsSec::new(strings))
  fn query() -> Result[Int, BinaryEncodeError] {
    let mut total = 0
    for literal in strings {
      let result = if reference {
        string_index_before_lookup(literal)
      } else {
        encode_string_const_index(literal)
      }
      match result {
        Ok(@lib.U32(value)) => total += value.to_int()
        Err(err) => return Err(err)
      }
    }
    Ok(total)
  }
  fn run() -> Result[Int, BinaryEncodeError] {
    if reference {
      string_index_before_scope(
        encode_module_stringrefs_before_index(mod_),
        query,
      )
    } else {
      let pool = encode_module_stringrefs_pool(mod_)
      with_binary_encode_stringrefs_context(
        Some(pool.values),
        query,
        known_index=pool.seen,
      )
    }
  }
  if run() != Ok(width * (width - 1) / 2) {
    abort("pool/index sharing changed literal positions")
  }
  it.bench(fn() { it.keep(run()) })
}

///|
test "bench string pool and index width=128 reference" (it : @bench.T) {
  string_pool_index_bench(it, 128, true)
}

///|
test "bench string pool and index width=128 shared" (it : @bench.T) {
  string_pool_index_bench(it, 128, false)
}

///|
test "bench string pool and index width=4096 reference" (it : @bench.T) {
  string_pool_index_bench(it, 4096, true)
}

///|
test "bench string pool and index width=4096 shared" (it : @bench.T) {
  string_pool_index_bench(it, 4096, false)
}
