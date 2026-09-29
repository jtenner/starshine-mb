///|
priv struct EncodedModuleSizeState {
  funcs : Array[Func]
  sizes : Array[Int]
  body_sizes : Array[Int]
  local_sizes : Array[Int]
  reuse : EncodedModuleSizeState?
  mut strings : Array[Bytes]
  mut code_size : Int
}

///|
fn EncodedModuleSizeState::new(
  reuse : EncodedModuleSizeState?,
) -> EncodedModuleSizeState {
  {
    funcs: [],
    sizes: [],
    body_sizes: [],
    local_sizes: [],
    reuse,
    strings: [],
    code_size: 0,
  }
}

///|
// Only local indices may change encoded width. All other immediates and control
// framing must match. The explicit worklist preserves the encoder's deep-control
// behavior without introducing recursive calls. String-pool agreement is checked
// by the caller before using a previously measured expression.
fn encoded_local_remap_size_delta(
  before : Array[Instruction],
  after : Array[Instruction],
) -> Int? {
  let work = [(before, after)]
  let mut delta = 0
  while work.pop() is Some((left, right)) {
    if physical_equal(left, right) {
      continue
    }
    if left.length() != right.length() {
      return None
    }
    for index = 0; index < left.length(); index = index + 1 {
      let old = left[index]
      let next = right[index]
      if physical_equal(old, next) {
        continue
      }
      match (old, next) {
        (LocalGet(LocalIdx(a)), LocalGet(LocalIdx(b)))
        | (LocalSet(LocalIdx(a)), LocalSet(LocalIdx(b)))
        | (LocalTee(LocalIdx(a)), LocalTee(LocalIdx(b))) =>
          delta += size_unsigned(b.to_uint64(), 32).unwrap() -
            size_unsigned(a.to_uint64(), 32).unwrap()
        (Block(a, Expr(xs)), Block(b, Expr(ys)))
        | (Loop(a, Expr(xs)), Loop(b, Expr(ys))) if a == b =>
          work.push((xs, ys))
        (TryTable(a, ac, Expr(xs)), TryTable(b, bc, Expr(ys))) if a == b &&
          ac == bc => work.push((xs, ys))
        (If(a, ax, ae), If(b, bx, be)) if a == b => {
          work.push((ax, bx))
          match (ae, be) {
            (None, None) => ()
            (Some(xs), Some(ys)) => work.push((xs, ys))
            _ => return None
          }
        }
        (Block(_, _), _)
        | (Loop(_, _), _)
        | (If(_, _, _), _)
        | (TryTable(_, _, _), _)
        | (Try(_, _, _, _), _) => return None
        _ => if old != next { return None }
      }
    }
  }
  Some(delta)
}

///|
fn measure_module_code(
  funcs : Array[Func],
  strings : Array[Bytes],
  state : EncodedModuleSizeState,
  body_buffers? : Array[Int]? = None,
  expression_encodes? : Array[Int]? = None,
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
    let mut body_size = 0
    let mut local_size = 0
    let cached = match state.reuse {
      Some(previous) if can_reuse &&
        index < previous.funcs.length() &&
        physical_equal(func, previous.funcs[index]) => {
        body_size = previous.body_sizes[index]
        local_size = previous.local_sizes[index]
        Some(previous.sizes[index])
      }
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
        let Expr(instrs) = expr
        if Encode::encode(locals, buffer) is Err(error) {
          return Err(error)
        }
        local_size = buffer.length()
        let reused_body = match state.reuse {
          Some(previous) if can_reuse && index < previous.funcs.length() => {
            let Func(_, Expr(old_instrs)) = previous.funcs[index]
            match encoded_local_remap_size_delta(old_instrs, instrs) {
              Some(delta) =>
                Some(
                  previous.body_sizes[index] -
                  previous.local_sizes[index] +
                  local_size +
                  delta,
                )
              None => None
            }
          }
          _ => None
        }
        body_size = match reused_body {
          Some(size) => size
          None => {
            if expression_encodes is Some(count) {
              count[0] += 1
            }
            if Encode::encode(expr, buffer) is Err(error) {
              return Err(error)
            }
            buffer.length()
          }
        }
        let prefix = match size_unsigned(body_size.to_uint64(), 32) {
          Ok(size) => size
          Err(error) => return Err(error)
        }
        prefix + body_size
      }
    }
    state.funcs.push(func)
    state.sizes.push(size)
    state.body_sizes.push(body_size)
    state.local_sizes.push(local_size)
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
/// Local-index-only rewrites reuse expression lengths with exact LEB deltas;
/// other rewrites retain complete body encoding.
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
