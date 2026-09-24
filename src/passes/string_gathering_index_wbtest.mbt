///|
test "string gathering index follows sorted distinct bytes" {
  let set = SgStringSet::new()
  let b = "b".to_bytes()
  let a = "a".to_bytes()
  let aa = "aa".to_bytes()
  assert_eq(sg_intern_string(set, b), 0)
  assert_eq(sg_intern_string(set, a), 1)
  assert_eq(sg_intern_string(set, aa), 2)
  assert_eq(sg_intern_string(set, b), 0)
  sg_sort_strings(set.strings)
  sg_reindex_strings(set)
  assert_eq(sg_string_index(set, a), Some(0))
  assert_eq(sg_string_index(set, aa), Some(1))
  assert_eq(sg_string_index(set, b), Some(2))
}
