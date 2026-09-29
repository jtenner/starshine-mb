///|
test "string constant emission indexes a large pool with bounded lookup work" {
  let strings : Array[Bytes] = []
  for index = 0; index < 128; index = index + 1 {
    strings.push(@utf8.encode("literal-\{index}"))
  }
  let checks = [0]
  let indices = with_binary_encode_stringrefs_context(Some(strings), fn() {
    let values : Array[Result[@lib.U32, BinaryEncodeError]] = []
    for index = 0; index < strings.length(); index = index + 1 {
      values.push(
        encode_string_const_index_impl(
          @utf8.encode("literal-\{index}"),
          Some(checks),
        ),
      )
    }
    Ok(values)
  }).unwrap()
  for index = 0; index < indices.length(); index = index + 1 {
    assert_eq(indices[index], Ok(@lib.U32(index.to_uint())))
  }
  assert_true(checks[0] <= 900)
  assert_eq(strings.length(), 128)
}

///|
test "string index scopes preserve first duplicates and restore after intentional errors" {
  let strings = Array::make(64, b"first")
  strings[63] = b"last"
  let indices : Array[Result[@lib.U32, BinaryEncodeError]] = []
  let nested_error = with_binary_encode_stringrefs_context(Some(strings), fn() {
    indices.push(encode_string_const_index(b"last"))
    indices.push(encode_string_const_index(b"first"))
    let nested : Result[Unit, BinaryEncodeError] = with_binary_encode_stringrefs_context(
      Some([b"last"]),
      fn() {
        indices.push(encode_string_const_index(b"last"))
        // A literal absent from this intentionally incomplete context is invalid.
        match encode_string_const_index(b"first") {
          Err(err) => Err(err)
          Ok(_) => abort("missing literal encoded")
        }
      },
    )
    indices.push(encode_string_const_index(b"last"))
    Ok(nested)
  }).unwrap()
  assert_eq(indices, [
    Ok(@lib.U32(63U)),
    Ok(@lib.U32(0U)),
    Ok(@lib.U32(0U)),
    Ok(@lib.U32(63U)),
  ])
  assert_eq(
    nested_error,
    Err(BinaryEncodeError::StringConstLiteralMissingFromSection),
  )
  // Encoding outside any module context is intentionally unsupported.
  assert_eq(
    encode_string_const_index(b"last"),
    Err(BinaryEncodeError::CannotEncodeStringConstWithoutModuleContext),
  )
  strings[0] = b"last"
  let next = with_binary_encode_stringrefs_context(Some(strings), fn() {
    Ok([encode_string_const_index(b"last"), encode_string_const_index(b"first")])
  }).unwrap()
  assert_eq(next, [Ok(@lib.U32(0U)), Ok(@lib.U32(1U))])
}
