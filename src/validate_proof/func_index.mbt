///|
pub fn defined_func_body_index(
  imported_func_count : Int,
  func_idx : Int,
) -> Int? where {
  proof_require: 0 <= imported_func_count,
  proof_ensure: result => {
    defined_func_body_index_post(imported_func_count, func_idx, result)
  },
} {
  if func_idx < imported_func_count {
    None
  } else {
    Some(func_idx - imported_func_count)
  }
}

///|
pub fn defined_func_absolute_index(
  imported_func_count : Int,
  body_idx : Int,
) -> Int where {
  proof_require: 0 <= imported_func_count,
  proof_require: 0 <= body_idx,
  proof_ensure: result => {
    defined_func_absolute_index_post(imported_func_count, body_idx, result)
  },
} {
  imported_func_count + body_idx
}

///|
pub fn defined_body_func_index(
  imported_func_count : Int,
  body_count : Int,
  body_idx : Int,
) -> Int? where {
  proof_require: 0 <= imported_func_count,
  proof_require: 0 <= body_count,
  proof_ensure: result => {
    defined_body_func_index_post(
      imported_func_count, body_count, body_idx, result,
    )
  },
} {
  if body_idx < 0 || body_idx >= body_count {
    None
  } else {
    Some(imported_func_count + body_idx)
  }
}
