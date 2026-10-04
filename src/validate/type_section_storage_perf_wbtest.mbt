///|
fn typesec_storage_bench(it : @bench.T, count : Int, width : Int) -> Unit {
  let section = Some(typesec_storage_section(count, width))
  let initial = Env::new()
  let actual = validate_typesec(section, initial).unwrap()
  let expected = typesec_storage_reference(section, initial).unwrap()
  if actual.global_types != expected.global_types ||
    actual.rec_stack != expected.rec_stack {
    abort("type section benchmark changed validated types or recursive scopes")
  }
  it.bench(fn() { it.keep(validate_typesec(section, initial)) })
  if !initial.global_types.is_empty() || !initial.rec_stack.is_empty() {
    abort("type section benchmark mutated its input environment")
  }
}

///|
test "bench type prefix groups1 width1" (it : @bench.T) {
  typesec_storage_bench(it, 1, 1)
}

///|
test "bench type prefix groups128 width1" (it : @bench.T) {
  typesec_storage_bench(it, 128, 1)
}

///|
test "bench type prefix groups1024 width1" (it : @bench.T) {
  typesec_storage_bench(it, 1024, 1)
}

///|
test "bench type prefix groups256 width4" (it : @bench.T) {
  typesec_storage_bench(it, 256, 4)
}
