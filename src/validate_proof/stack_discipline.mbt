///|
pub fn stack_len_after_push1(
  len : Int,
) -> Int where {
  proof_require: 0 <= len,
  proof_ensure: result => stack_len_after_push1_post(len, result),
} {
  len + 1
}

///|
pub fn stack_len_after_push_types(
  len : Int,
  pushed_len : Int,
) -> Int where {
  proof_require: 0 <= len,
  proof_require: 0 <= pushed_len,
  proof_ensure: result => {
    stack_len_after_push_types_post(len, pushed_len, result)
  },
} {
  len + pushed_len
}

///|
pub fn stack_len_after_pop1(
  len : Int,
) -> Int? where {
  proof_require: 0 <= len,
  proof_ensure: result => stack_len_after_pop1_post(len, result),
} {
  if len == 0 {
    None
  } else {
    Some(len - 1)
  }
}

///|
pub fn stack_len_after_pop_types(
  len : Int,
  popped_len : Int,
) -> Int? where {
  proof_require: 0 <= len,
  proof_require: 0 <= popped_len,
  proof_ensure: result => {
    stack_len_after_pop_types_post(len, popped_len, result)
  },
} {
  if popped_len > len {
    None
  } else {
    Some(len - popped_len)
  }
}

///|
pub fn stack_suffix_start_after_end_check(
  len : Int,
  results_len : Int,
) -> Int? where {
  proof_require: 0 <= len,
  proof_require: 0 <= results_len,
  proof_ensure: result => {
    stack_suffix_start_after_end_check_post(len, results_len, result)
  },
} {
  stack_len_after_pop_types(len, results_len)
}
