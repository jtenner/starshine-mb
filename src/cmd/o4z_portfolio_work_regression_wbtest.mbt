///|
test "O4z provisional selection reuses worker byte proof while checking a shorter invalid row" {
  let first = encode_module_bytes(
    @passes.pass_test_module_from_wat(
      "(module (func (export \"f\") (result i32) i32.const 1))",
    ),
  )
  let second = encode_module_bytes(
    @passes.pass_test_module_from_wat(
      "(module (func (export \"f\") (result i32) i32.const 2))",
    ),
  )
  assert_eq(first.length(), second.length())
  assert_true(cmd_o4z_prevalidate_encoded_candidate(first) is Some(_))
  let rows = [
    ("invalid-shorter", b"\x00"),
    ("worker-first", first),
    ("worker-second", second),
  ]
  let saved = rows.copy()
  let checked : Array[String] = []
  let selected = cmd_choose_smallest_valid_encoded_candidate(
    rows,
    prevalidated_labels=["worker-first"],
    is_valid=Some(fn(label, bytes) {
      checked.push(label)
      cmd_o4z_prevalidate_encoded_candidate(bytes) is Some(_)
    }),
  )
  assert_eq(selected, ("worker-first", first))
  let output = decode_module_bytes(selected.1)
  ignore(@validate.validate_module(output).unwrap())
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(body, [@lib.Instruction::i32_const(1)])
  assert_eq(rows, saved)
  assert_eq(checked, ["invalid-shorter"])
}

///|
test "O4z provisional selection still validates unproved winners and keeps stable ties" {
  let bytes = encode_module_bytes(
    @passes.pass_test_module_from_wat(
      "(module (func (export \"f\") (result i32) i32.const 7))",
    ),
  )
  let checked : Array[String] = []
  let selected = cmd_choose_smallest_valid_encoded_candidate(
    [("invalid", b"\x00"), ("first", bytes), ("tied", bytes)],
    prevalidated_labels=["unrelated"],
    is_valid=Some(fn(label, value) {
      checked.push(label)
      cmd_o4z_prevalidate_encoded_candidate(value) is Some(_)
    }),
  )
  assert_eq(selected, ("first", bytes))
  assert_eq(checked, ["invalid", "first"])
  ignore(@validate.validate_module(decode_module_bytes(selected.1)).unwrap())
}

///|
test "encoding without terminal returns copies no function rows and preserves actual bytes" {
  for width in [4, 8] {
    let functions = Array::makei(width, fn(index) {
      "(func (export \"f\{index}\") (result i32) i32.const \{index + 7})"
    }).join(" ")
    let input = @passes.pass_test_module_from_wat("(module " + functions + ")")
    let saved = encode_module_bytes(input)
    let copied = [0]
    let output = cmd_strip_terminal_returns_for_encoding(
      input,
      copied_rows=Some(copied),
    )
    assert_eq(encode_module_bytes(output), saved)
    assert_eq(encode_module_bytes(input), saved)
    ignore(@validate.validate_module(output).unwrap())
    assert_eq(copied[0], 0)
  }
}

///|
test "encoding terminal return batch keeps invalid fallthrough and changes only valid rows" {
  let input = @passes.pass_test_module_from_wat(
    (
      #|(module
      #|  (func (result i32) i32.const 3)
      #|  (func (result i32) i32.const 7 return)
      #|  (func (result i32) i32.const 11 i32.const 13 return)
      #|  (func (result i32) i32.const 17))
    ),
  )
  ignore(@validate.validate_module(input).unwrap())
  let saved = encode_module_bytes(input)
  let copied = [0]
  let output = cmd_strip_terminal_returns_for_encoding(
    input,
    copied_rows=Some(copied),
  )
  let original = input.code_sec.unwrap().0
  let funcs = output.code_sec.unwrap().0
  assert_eq(funcs[0], original[0])
  let @lib.Func(_, @lib.Expr(valid)) = funcs[1]
  assert_eq(valid, [@lib.Instruction::i32_const(7)])
  assert_eq(funcs[2], original[2])
  assert_eq(funcs[3], original[3])
  assert_eq(encode_module_bytes(input), saved)
  ignore(@validate.validate_module(output).unwrap())
  ignore(
    @validate.validate_module(decode_module_bytes(encode_module_bytes(output))).unwrap(),
  )
  assert_eq(copied[0], 4)
}
