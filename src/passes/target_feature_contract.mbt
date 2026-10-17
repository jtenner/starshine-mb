///|
fn pass_target_features_disallow(payload : Bytes, feature : String) -> Bool {
  let count_result : Result[(@lib.U32, Int32), @binary.BinaryDecodeError] = @binary.Decode::decode(
    payload, 0,
  )
  let (@lib.U32(raw_count), initial_cursor) = match count_result {
    Ok(value) => value
    Err(_) => return true
  }
  let mut cursor = initial_cursor
  let count = raw_count.reinterpret_as_int()
  if count < 0 {
    return true
  }
  for feature_idx = 0; feature_idx < count; feature_idx = feature_idx + 1 {
    if cursor >= payload.length() {
      return true
    }
    let prefix = payload[cursor]
    cursor += 1
    if prefix != b'\x2b' && prefix != b'\x2d' {
      return true
    }
    let name_result : Result[(@lib.Name, Int32), @binary.BinaryDecodeError] = @binary.Decode::decode(
      payload, cursor,
    )
    let (@lib.Name(name), next) = match name_result {
      Ok(value) => value
      Err(_) => return true
    }
    cursor = next
    if prefix == b'\x2d' && name == feature {
      return true
    }
  }
  cursor != payload.length()
}

///|
// A missing section preserves the established permissive policy. Any matching
// minus entry or malformed section forbids introduction, across all sections.
fn pass_module_allows_feature_introduction(
  mod_ : @lib.Module,
  feature : String,
) -> Bool {
  for custom in mod_.custom_secs {
    let @lib.CustomSec(@lib.Name(name), payload) = custom
    if name == "target_features" &&
      pass_target_features_disallow(payload, feature) {
      return false
    }
  }
  true
}
