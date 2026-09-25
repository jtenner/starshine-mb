///|
fn die_name_sort_fixture(count : Int) -> Array[@lib.NameAssoc] {
  let entries : Array[@lib.NameAssoc] = []
  for idx in 0..<count {
    entries.push(
      @lib.NameAssoc::new(
        (count - idx - 1).to_uint(),
        @lib.Name::from_string("n"),
      ),
    )
  }
  entries
}

///|
fn die_indirect_sort_fixture(count : Int) -> Array[@lib.IndirectNameAssoc] {
  let entries : Array[@lib.IndirectNameAssoc] = []
  for idx in 0..<count {
    entries.push(
      @lib.IndirectNameAssoc::new(
        (count - idx - 1).to_uint(),
        @lib.NameMap::new([]),
      ),
    )
  }
  entries
}

///|
fn die_name_sort_bench(it : @bench.T, count : Int) -> Unit {
  let original = die_name_sort_fixture(count)
  it.bench(fn() {
    let entries = original.copy()
    die_sort_name_assocs(entries)
    it.keep(entries)
  })
}

///|
fn die_indirect_sort_bench(it : @bench.T, count : Int) -> Unit {
  let original = die_indirect_sort_fixture(count)
  it.bench(fn() {
    let entries = original.copy()
    die_sort_indirect_name_assocs(entries)
    it.keep(entries)
  })
}

///|
test "DuplicateImportElimination name sorts preserve duplicate index order" {
  let names = [
    @lib.NameAssoc::new(2U, @lib.Name::from_string("two")),
    @lib.NameAssoc::new(1U, @lib.Name::from_string("first")),
    @lib.NameAssoc::new(1U, @lib.Name::from_string("second")),
  ]
  die_sort_name_assocs(names)
  assert_eq(names, [
    @lib.NameAssoc::new(1U, @lib.Name::from_string("first")),
    @lib.NameAssoc::new(1U, @lib.Name::from_string("second")),
    @lib.NameAssoc::new(2U, @lib.Name::from_string("two")),
  ])
  let nested_first = @lib.NameMap::new([
    @lib.NameAssoc::new(0U, @lib.Name::from_string("first")),
  ])
  let nested_second = @lib.NameMap::new([
    @lib.NameAssoc::new(0U, @lib.Name::from_string("second")),
  ])
  let indirect = [
    @lib.IndirectNameAssoc::new(2U, @lib.NameMap::new([])),
    @lib.IndirectNameAssoc::new(1U, nested_first),
    @lib.IndirectNameAssoc::new(1U, nested_second),
  ]
  die_sort_indirect_name_assocs(indirect)
  assert_eq(indirect, [
    @lib.IndirectNameAssoc::new(1U, nested_first),
    @lib.IndirectNameAssoc::new(1U, nested_second),
    @lib.IndirectNameAssoc::new(2U, @lib.NameMap::new([])),
  ])
}

///|
test "bench duplicate-import names count=2048" (it : @bench.T) {
  die_name_sort_bench(it, 2048)
}

///|
test "bench duplicate-import names count=4096" (it : @bench.T) {
  die_name_sort_bench(it, 4096)
}

///|
test "bench duplicate-import indirect names count=2048" (it : @bench.T) {
  die_indirect_sort_bench(it, 2048)
}

///|
test "bench duplicate-import indirect names count=4096" (it : @bench.T) {
  die_indirect_sort_bench(it, 4096)
}
