///|
pub suberror DecodeError {
  Decode(BinaryDecodeError)
  DecodeAt(BinaryDecodeError, Int, Int)
  TrailingBytes(Int, Int)
} derive(Eq, Show, Debug)

///|
pub suberror EncodeError {
  Encode(BinaryEncodeError)
} derive(Eq, Show, Debug)

///|
fn first_malformed_section_span(bytes : Bytes) -> (Int, Int)? {
  if bytes.length() <= 8 {
    return None
  }
  let mut i = 8
  while i < bytes.length() {
    let section_start = i
    i += 1
    let (@lib.U32(payload_len_u), payload_start) = match
      Decode::decode(bytes, i) {
      Ok(t) => t
      Err(_) => return Some((section_start, bytes.length() - section_start))
    }
    let payload_len = payload_len_u.reinterpret_as_int()
    let payload_end = payload_start + payload_len
    if payload_end > bytes.length() {
      return Some((section_start, bytes.length() - section_start))
    }
    i = payload_end
  }
  None
}

///|
fn consumed_section_prefix(bytes : Bytes) -> Int {
  if bytes.length() < 8 {
    return 0
  }
  let mut i = 8
  while i < bytes.length() {
    let section_id = bytes[i]
    if section_id != 0 && (section_id < 1 || section_id > 11) {
      break
    }
    let (@lib.U32(payload_len_u), payload_start) = match
      Decode::decode(bytes, i + 1) {
      Ok(t) => t
      Err(_) => break
    }
    let payload_len = payload_len_u.reinterpret_as_int()
    let payload_end = payload_start + payload_len
    if payload_end > bytes.length() {
      break
    }
    i = payload_end
  }
  i
}

///|
pub fn decode_module(bytes : Bytes) -> Result[@lib.Module, DecodeError] {
  match Decode::decode(bytes, 0) {
    Ok((mod, idx)) =>
      if idx == bytes.length() {
        Ok(mod)
      } else {
        Err(DecodeError::TrailingBytes(idx, bytes.length() - idx))
      }
    Err(err) =>
      match err {
        BinaryDecodeError::SectionPayloadLengthOutOfRange
        | BinaryDecodeError::InvalidSectionPayloadTrailingBytes
        | BinaryDecodeError::CustomSectionPayloadLengthOutOfRange =>
          match first_malformed_section_span(bytes) {
            Some((offset, len)) => Err(DecodeError::DecodeAt(err, offset, len))
            None => Err(DecodeError::Decode(err))
          }
        BinaryDecodeError::InvalidModule => {
          let consumed = consumed_section_prefix(bytes)
          if consumed < bytes.length() {
            Err(DecodeError::TrailingBytes(consumed, bytes.length() - consumed))
          } else {
            Err(DecodeError::Decode(err))
          }
        }
        _ => Err(DecodeError::Decode(err))
      }
  }
}

///|
pub fn encode_module(mod : @lib.Module) -> Result[Bytes, EncodeError] {
  let buf = @buffer.new()
  match Encode::encode(mod, buf) {
    Ok(_) => Ok(buf.to_bytes())
    Err(err) => Err(EncodeError::Encode(err))
  }
}
