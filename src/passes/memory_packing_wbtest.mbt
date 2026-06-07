///|
test "memory-packing segment-limit guard allows exact wasm maximum only" {
  assert_false(mp_data_segment_limit_exceeded(99999, 1, 0))
  assert_false(mp_data_segment_limit_exceeded(99998, 1, 1))
  assert_true(mp_data_segment_limit_exceeded(99999, 2, 0))
}
