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
pub fn decode_module(bytes : Bytes) -> Result[@lib.Module, DecodeError] {
  match decode_module_with_detail(bytes, 0) {
    Ok((mod, idx)) =>
      if idx == bytes.length() {
        Ok(mod)
      } else {
        Err(DecodeError::TrailingBytes(idx, bytes.length() - idx))
      }
    Err(detail) =>
      match detail.trailing_offset {
        Some(offset) if detail.err == BinaryDecodeError::InvalidModule &&
          offset < bytes.length() =>
          Err(DecodeError::TrailingBytes(offset, bytes.length() - offset))
        _ =>
          match (detail.section_offset, detail.section_len) {
            (Some(offset), Some(len)) =>
              Err(DecodeError::DecodeAt(detail.err, offset, len))
            _ => Err(DecodeError::Decode(detail.err))
          }
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
