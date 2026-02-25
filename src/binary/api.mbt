///|
pub suberror DecodeError {
  Decode(BinaryDecodeError)
  TrailingBytes(Int, Int)
} derive(Eq, Show, Debug)

///|
pub suberror EncodeError {
  Encode(BinaryEncodeError)
} derive(Eq, Show, Debug)

///|
pub fn decode_module(bytes : Bytes) -> Result[@lib.Module, DecodeError] {
  match Decode::decode(bytes, 0) {
    Ok((mod, idx)) =>
      if idx == bytes.length() {
        Ok(mod)
      } else {
        Err(DecodeError::TrailingBytes(idx, bytes.length()))
      }
    Err(err) => Err(DecodeError::Decode(err))
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
