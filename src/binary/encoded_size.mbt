///|
priv struct EncodedModuleSizeState {
  funcs : Array[Func]
  sizes : Array[Int]
  reuse : EncodedModuleSizeState?
  mut strings : Array[Bytes]
  mut code_size : Int
}

///|
fn EncodedModuleSizeState::new(
  reuse : EncodedModuleSizeState?,
) -> EncodedModuleSizeState {
  { funcs: [], sizes: [], reuse, strings: [], code_size: 0, }
}

///|
fn measure_module_code(
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
/// Return exact canonical binary sizes without assembling either code section.
/// Shared function bodies are measured once when their stringref pools agree.
/// Reuse is scoped to this call: mutable module data never enters a durable cache.
/// The result includes names, compiler facts, section framing, and body framing.
pub fn encoded_module_sizes(
  before : Module,
  after : Module,
) -> Result[(Int, Int), EncodeError] {
  let first = EncodedModuleSizeState::new(None)
  let first_buffer = @buffer.new()
  match
    encode_module_sections(before, first_buffer, false, size_state=Some(first)) {
    Err(error) => return Err(EncodeError::Encode(error))
    Ok(_) => ()
  }
  let second = EncodedModuleSizeState::new(Some(first))
  let second_buffer = @buffer.new()
  match
    encode_module_sections(after, second_buffer, false, size_state=Some(second)) {
    Err(error) => Err(EncodeError::Encode(error))
    Ok(_) =>
      Ok(
        (
          first_buffer.length() + first.code_size,
          second_buffer.length() + second.code_size,
        ),
      )
  }
}
