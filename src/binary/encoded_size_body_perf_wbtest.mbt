///|
fn measure_module_code_reference(
  funcs : Array[Func],
  strings : Array[Bytes],
  state : EncodedModuleSizeState,
) -> Result[Unit, BinaryEncodeError] {
  state.strings = strings
  let can_reuse = match state.reuse {
    Some(previous) => previous.strings == strings
    None => false
  }
  let mut payload = match size_unsigned(funcs.length().to_uint64(), 32) {
    Ok(size) => size
    Err(error) => return Err(error)
  }
  for index = 0; index < funcs.length(); index = index + 1 {
    let func = funcs[index]
    let cached = match state.reuse {
      Some(previous) if can_reuse &&
        index < previous.funcs.length() &&
        physical_equal(func, previous.funcs[index]) =>
        Some(previous.sizes[index])
      _ => None
    }
    let size = match cached {
      Some(size) => size
      None => {
        let buffer = @buffer.new()
        match Encode::encode(func, buffer) {
          Ok(_) => buffer.length()
          Err(error) => return Err(error)
        }
      }
    }
    state.funcs.push(func)
    state.sizes.push(size)
    payload += size
  }
  let prefix = match size_unsigned(payload.to_uint64(), 32) {
    Ok(size) => size
    Err(error) => return Err(error)
  }
  state.code_size = 1 + prefix + payload
  Ok(())
}

///|
fn encoded_body_measure_bench(
  it : @bench.T,
  count : Int,
  width : Int,
  reference : Bool,
) -> Unit {
  let funcs = Array::make(
    count,
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new(Array::make(width, @lib.Instruction::nop())),
    ),
  )
  let state = EncodedModuleSizeState::new(None)
  measure_module_code(funcs, [], state).unwrap()
  let encoded = @buffer.new()
  Encode::encode(funcs[0], encoded).unwrap()
  if state.sizes[0] != encoded.length() {
    abort("body sizing lost exact framing")
  }
  it.bench(fn() {
    if reference {
      let state = EncodedModuleSizeState::new(None)
      it.keep(measure_module_code_reference(funcs, [], state))
      it.keep(state.sizes)
    } else {
      let state = EncodedModuleSizeState::new(None)
      it.keep(measure_module_code(funcs, [], state))
      it.keep(state.sizes)
    }
  })
}

///|
test "bench exact body sizes functions=1 width=4 reference" (it : @bench.T) {
  encoded_body_measure_bench(it, 1, 4, true)
}

///|
test "bench exact body sizes functions=1 width=4 direct" (it : @bench.T) {
  encoded_body_measure_bench(it, 1, 4, false)
}

///|
test "bench exact body sizes functions=128 width=128 reference" (it : @bench.T) {
  encoded_body_measure_bench(it, 128, 128, true)
}

///|
test "bench exact body sizes functions=128 width=128 direct" (it : @bench.T) {
  encoded_body_measure_bench(it, 128, 128, false)
}

///|
test "bench exact body sizes functions=128 width=4096 reference" (it : @bench.T) {
  encoded_body_measure_bench(it, 128, 4096, true)
}

///|
test "bench exact body sizes functions=128 width=4096 direct" (it : @bench.T) {
  encoded_body_measure_bench(it, 128, 4096, false)
}

///|
test "bench exact body sizes functions=1 width=16381 reference" (it : @bench.T) {
  encoded_body_measure_bench(it, 1, 16381, true)
}

///|
test "bench exact body sizes functions=1 width=16381 direct" (it : @bench.T) {
  encoded_body_measure_bench(it, 1, 16381, false)
}

///|
test "bench exact body sizes functions=1 width=16382 reference" (it : @bench.T) {
  encoded_body_measure_bench(it, 1, 16382, true)
}

///|
test "bench exact body sizes functions=1 width=16382 direct" (it : @bench.T) {
  encoded_body_measure_bench(it, 1, 16382, false)
}
