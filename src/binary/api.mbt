///|
pub suberror DecodeError {
  Decode(BinaryDecodeError)
  DecodeAt(BinaryDecodeError, Int, Int)
  TrailingBytes(Int, Int)
} derive(Eq, Debug)

pub impl Show for DecodeError with output(self, logger) {
  match self {
    DecodeAt(err, a, b) => {
      logger.write_string("DecodeAt(")
      err.output(logger)
      logger.write_string(", ")
      a.output(logger)
      logger.write_string(", ")
      b.output(logger)
      logger.write_char(')')
    }
    Decode(err) => {
      logger.write_string("Decode(")
      err.output(logger)
      logger.write_char(')')
    }
    TrailingBytes(a, b) => {
      logger.write_string("TrailingBytes(")
      a.output(logger)
      logger.write_string(", ")
      b.output(logger)
      logger.write_char(')')
    }
  } 
}

///|
pub suberror EncodeError {
  Encode(BinaryEncodeError)
} derive(Eq, Debug)

pub impl Show for EncodeError with output(self, logger) {
  match self {
    Encode(err) => {
      logger.write_string("Encode(")
      err.output(logger)
      logger.write_char(')')
    }
  }
}

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
