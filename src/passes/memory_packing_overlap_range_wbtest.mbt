///|
test "MemoryPacking computes partial overlap ranges before copying bytes" {
  assert_eq(mp_trampled_overlap_range(10UL, 4, 12UL, 2), Some((2, 4)))
  assert_eq(mp_trampled_overlap_range(10UL, 4, 8UL, 3), Some((0, 1)))
  assert_eq(mp_trampled_overlap_range(10UL, 4, 20UL, 2), None)
}
