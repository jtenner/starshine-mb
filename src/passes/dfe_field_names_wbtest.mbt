///|
test "DFE type compaction remaps struct field name owners without changing fields" {
  let input = pass_test_module_from_wat(
    "(module (type (func)) (type (func)) (type (struct (field i32) (field i64))) (func (type 0)))",
  ).with_name_sec(
    @lib.NameSec::new(
      field_names=Some(
        @lib.IndirectNameMap::new([
          @lib.IndirectNameAssoc::new(
            2U,
            @lib.NameMap::new([
              @lib.NameAssoc::new(0U, @lib.Name::from_string("first")),
              @lib.NameAssoc::new(1U, @lib.Name::from_string("second")),
            ]),
          ),
        ]),
      ),
    ),
  )
  @validate.validate_module(input).unwrap()
  let output = dfe_canonicalize_duplicate_simple_type_indices(input)
  @debug.assert_eq(output.type_sec.unwrap().0.length(), 2)
  let @lib.IndirectNameMap(entries) = output.name_sec.unwrap().field_names.unwrap()
  @debug.assert_eq(entries.length(), 1)
  let @lib.IndirectNameAssoc(owner, fields) = entries[0]
  @debug.assert_eq(owner, 1U)
  @debug.assert_eq(fields, input.name_sec.unwrap().field_names.unwrap().0[0].1)
  @validate.validate_module(output).unwrap()
}

///|
test "DFE type name remap removes field names of deleted types" {
  let fields = @lib.NameMap::new([
    @lib.NameAssoc::new(0U, @lib.Name::from_string("field")),
  ])
  let input = @lib.NameSec::new(
    field_names=Some(
      @lib.IndirectNameMap::new([
        @lib.IndirectNameAssoc::new(0U, fields),
        @lib.IndirectNameAssoc::new(2U, fields),
      ]),
    ),
  )
  let output = dfe_rewrite_type_name_sec(input, Map([(2U, 0U)]))
  @debug.assert_eq(
    output.field_names,
    Some(@lib.IndirectNameMap::new([@lib.IndirectNameAssoc::new(0U, fields)])),
  )
}

///|
test "DFE duplicate struct types retain only their canonical field names" {
  let first = @lib.NameMap::new([
    @lib.NameAssoc::new(0U, @lib.Name::from_string("canonical")),
  ])
  let second = @lib.NameMap::new([
    @lib.NameAssoc::new(0U, @lib.Name::from_string("duplicate")),
  ])
  let input = pass_test_module_from_wat(
    "(module (type (struct (field i32))) (type (struct (field i32))))",
  ).with_name_sec(
    @lib.NameSec::new(
      field_names=Some(
        @lib.IndirectNameMap::new([
          @lib.IndirectNameAssoc::new(0U, first),
          @lib.IndirectNameAssoc::new(1U, second),
        ]),
      ),
    ),
  )
  let output = dfe_canonicalize_duplicate_simple_type_indices(input)
  @debug.assert_eq(output.type_sec.unwrap().0.length(), 1)
  @debug.assert_eq(
    output.name_sec.unwrap().field_names,
    Some(@lib.IndirectNameMap::new([@lib.IndirectNameAssoc::new(0U, first)])),
  )
  @validate.validate_module(output).unwrap()
}
