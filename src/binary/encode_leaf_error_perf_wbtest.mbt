///|
// Retain one boxed Result per leaf, consumed exactly as in the old cursor.
fn encode_leaf_boxed_sequence(
  body : Array[Instruction],
  buffer : @buffer.Buffer,
) -> Result[Unit, BinaryEncodeError] {
  for instruction in body {
    if encode_leaf_instruction(instruction, buffer) is Err(err) {
      return Err(err)
    }
  }
  Ok(())
}

///|
fn encode_leaf_error_bench(
  it : @bench.T,
  width : Int,
  immediates : Bool,
  reference : Bool,
) -> Unit {
  let body = Array::makei(width, fn(index) {
    if immediates {
      Instruction::i32_const(@lib.I32(index))
    } else {
      Instruction::nop()
    }
  })
  let expected = @buffer.new()
  for instruction in body {
    encode_leaf_instruction(instruction, expected).unwrap()
  }
  let actual = @buffer.new()
  encode_control_work([ControlSequence(body, 0)], actual).unwrap()
  if expected.to_bytes() != actual.to_bytes() {
    abort("error-only leaf encoding changed bytes")
  }
  it.bench(fn() {
    let buffer = @buffer.new()
    it.keep(
      if reference {
        encode_leaf_boxed_sequence(body, buffer)
      } else {
        encode_control_work([ControlSequence(body, 0)], buffer)
      },
    )
    it.keep(buffer.length())
  })
}

///|
test "bench leaf errors width=8 nop boxed" (it : @bench.T) {
  encode_leaf_error_bench(it, 8, false, true)
}

///|
test "bench leaf errors width=8 nop error-only" (it : @bench.T) {
  encode_leaf_error_bench(it, 8, false, false)
}

///|
test "bench leaf errors width=4096 nop boxed" (it : @bench.T) {
  encode_leaf_error_bench(it, 4096, false, true)
}

///|
test "bench leaf errors width=4096 nop error-only" (it : @bench.T) {
  encode_leaf_error_bench(it, 4096, false, false)
}

///|
test "bench leaf errors width=4096 const boxed" (it : @bench.T) {
  encode_leaf_error_bench(it, 4096, true, true)
}

///|
test "bench leaf errors width=4096 const error-only" (it : @bench.T) {
  encode_leaf_error_bench(it, 4096, true, false)
}
