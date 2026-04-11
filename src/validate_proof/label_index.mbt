///|
pub fn label_stack_storage_index(
  len : Int,
  idx : Int,
) -> Int? where {
  proof_require: 0 <= len,
  proof_ensure: result => label_stack_storage_index_post(len, idx, result),
} {
  if idx < 0 || idx >= len {
    None
  } else {
    Some(len - 1 - idx)
  }
}
