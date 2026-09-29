///|
fn measure_module_code_before_local_remap(
  funcs : Array[Func],
  strings : Array[Bytes],
  state : EncodedModuleSizeState,
  body_buffers? : Array[Int]? = None,
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
        match body_buffers {
          Some(count) => count[0] += 1
          None => ()
        }
        let buffer = @buffer.new()
        let Func(locals, expr) = func
        if Encode::encode(locals, buffer) is Err(error) {
          return Err(error)
        }
        if Encode::encode(expr, buffer) is Err(error) {
          return Err(error)
        }
        let body_size = buffer.length()
        let prefix = match size_unsigned(body_size.to_uint64(), 32) {
          Ok(size) => size
          Err(error) => return Err(error)
        }
        prefix + body_size
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
