///|
pub fn group_relative_absolute_index(
  base : Int,
  group_len : Int,
  rel : Int,
) -> Int? where {
  proof_require: 0 <= group_len,
  proof_ensure:
    result => group_relative_absolute_index_post(base, group_len, rel, result),
} {
  if rel < 0 || rel >= group_len {
    None
  } else {
    Some(base + rel)
  }
}

///|
pub fn group_member_relative_index(
  base : Int,
  group_len : Int,
  abs_idx : Int,
) -> Int? where {
  proof_require: 0 <= group_len,
  proof_ensure:
    result => group_member_relative_index_post(base, group_len, abs_idx, result),
} {
  let rel = abs_idx - base
  if rel < 0 || rel >= group_len {
    None
  } else {
    Some(rel)
  }
}
