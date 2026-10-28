///|
#cfg(target="native")
test "r1 tooling native C path uses UTF-8" {
  assert_eq(cmd_native_c_string("é.wasm"), b"\xc3\xa9.wasm\x00")
}

///|
#cfg(target="native")
test "r1 native C strings preserve ASCII empty and embedded NUL conventions" {
  assert_eq(cmd_native_c_string(""), b"\x00")
  assert_eq(cmd_native_c_string("rb"), b"rb\x00")
  assert_eq(cmd_native_c_string("a\u{0000}b"), b"a\x00b\x00")
}

///|
#cfg(target="native")
test "r1 native C strings encode scalars above Latin1" {
  assert_eq(
    cmd_native_c_string("Ā漢😀"),
    b"\xc4\x80\xe6\xbc\xa2\xf0\x9f\x98\x80\x00",
  )
}

///|
#cfg(target="native")
test "r1 native file access opens owned UTF-8 filename fixtures" {
  // The independent filesystem writer stages the real UTF-8 name. Capture
  // results and remove each owned fixture before asserting, including on red.
  let observations : Array[(Bool, Result[Bytes, String])] = []
  for suffix in ["-ascii.wasm", "-é.wasm", "-漢.wasm", "-😀.wasm"] {
    let path = cmd_native_tmp_path("r1-11", suffix)
    let payload = b"\x00asm\x01\x00\x00\x00"
    @sfs.write_file_bytes(path, payload).unwrap()
    observations.push(
      (cmd_native_file_exists(path), cmd_native_read_file(path)),
    )
    @sfs.remove_file(path).unwrap()
  }
  assert_eq(
    observations,
    Array::make(4, (true, Ok(b"\x00asm\x01\x00\x00\x00"))),
  )
}
