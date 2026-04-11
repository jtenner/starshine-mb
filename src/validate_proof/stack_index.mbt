///|
pub fn latest_stack_index(
  len : Int,
) -> Int? where {
  proof_require: 0 <= len,
  proof_ensure: result => latest_stack_index_post(len, result),
} {
  if len == 0 {
    None
  } else {
    Some(len - 1)
  }
}
