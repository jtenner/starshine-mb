///|
pub fn rectype_suffix_member_index(
  total_len : Int,
  suffix_len : Int,
  relative_idx : Int,
) -> Int? where {
  proof_require: 0 <= total_len,
  proof_require: 0 <= suffix_len,
  proof_ensure: result => {
    rectype_suffix_member_index_post(
      total_len, suffix_len, relative_idx, result,
    )
  },
} {
  match suffix_start_index(total_len, suffix_len) {
    None => None
    Some(start) =>
      group_relative_absolute_index(start, suffix_len, relative_idx)
  }
}
