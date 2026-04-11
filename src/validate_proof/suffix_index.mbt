///|
pub fn suffix_start_index(total_len : Int, suffix_len : Int) -> Int? where {
  proof_require: 0 <= total_len,
  proof_require: 0 <= suffix_len,
  proof_ensure:
    result => suffix_start_index_post(total_len, suffix_len, result),
} {
  if suffix_len > total_len {
    None
  } else {
    Some(total_len - suffix_len)
  }
}
