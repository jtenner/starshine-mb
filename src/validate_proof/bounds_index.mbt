///|
pub fn bounded_index(len : Int, idx : Int) -> Int? where {
  proof_require: 0 <= len,
  proof_ensure: result => bounded_index_post(len, idx, result),
} {
  if idx < 0 || idx >= len {
    None
  } else {
    Some(idx)
  }
}
