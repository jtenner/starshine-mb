///|
test "ReorderGlobals sorts names while retaining duplicate-index order" {
  let first = @lib.NameAssoc::new(2U, @lib.Name::from_string("first"))
  let second = @lib.NameAssoc::new(2U, @lib.Name::from_string("second"))
  let earlier = @lib.NameAssoc::new(1U, @lib.Name::from_string("earlier"))
  let entries = [first, earlier, second]
  rg_sort_name_assocs_stable(entries)
  assert_eq(entries[0], earlier)
  assert_eq(entries[1], first)
  assert_eq(entries[2], second)
}
