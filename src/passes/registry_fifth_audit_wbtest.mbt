///|
test "fifth audit registry help snapshot isolates nested descriptor metadata" {
  let entries = pass_registry_help_entries()
  let mut index = 0
  while entries[index].name != "optimize-instructions" {
    index += 1
  }
  let saved = entries[index].descriptor.unwrap().requires.copy()
  entries[index].descriptor.unwrap().requires.clear()
  let actual = pass_registry_lookup("optimize-instructions").unwrap().descriptor.unwrap().requires.copy()
  entries[index].descriptor.unwrap().requires.append(saved)
  @debug.assert_eq(actual, saved)
}
