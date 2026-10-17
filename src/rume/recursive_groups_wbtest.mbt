///|
fn rume_group_test_struct(target : @lib.TypeIdx?) -> @lib.SubType {
  @lib.SubType::comp_type(
    @lib.CompType::struct_(
      match target {
        Some(type_idx) =>
          [
            @lib.FieldType::new(
              @lib.StorageType::val_type(
                @lib.ValType::ref_type(
                  @lib.RefType::new(true, @lib.HeapType::new(type_idx)),
                ),
              ),
              @lib.Mut::const_(),
            ),
          ]
        None => []
      },
    ),
  )
}

///|
test "RUME repeated group member roots scan each retained subtype once" {
  let rec_types = [
    @lib.RecType::new(rume_group_test_struct(None)),
    @lib.RecType::new(rume_group_test_struct(None)),
    @lib.RecType::group([
      rume_group_test_struct(None),
      rume_group_test_struct(None),
      rume_group_test_struct(Some(@lib.TypeIdx::new(1U))),
      rume_group_test_struct(None),
    ]),
  ]
  let flags = @bitset.BitSet::new(6)
  flags[2] = true
  flags[3] = true
  flags[5] = true
  let visits = [0]
  rume_close_type_dependencies(
    flags,
    rec_types,
    dependency_type_visits=Some(visits),
  )
  @debug.assert_eq(visits[0], 5)
  assert_false(flags[0])
  for idx in 1..<6 {
    assert_true(flags[idx])
  }
  let compacted = rume_compact_type_sec(
    @lib.Module::new().with_type_sec(@lib.TypeSec::new(rec_types)),
    precomputed_used_types=Some(flags),
  )
  @debug.assert_eq(compacted.type_sec.unwrap().0.length(), 2)
  assert_true(@validate.validate_module(compacted) is Ok(_))
}

///|
test "RUME whole group movement preserves group-local RecIdx operands" {
  // RecIdx is an IR-only group-local operand. It must remain local when the
  // group's absolute start moves; the binary encoder does not admit this form.
  let group = @lib.RecType::group([
    rume_group_test_struct(Some(@lib.TypeIdx::rec(1U))),
    rume_group_test_struct(Some(@lib.TypeIdx::rec(0U))),
  ])
  let rec_types = [@lib.RecType::new(rume_group_test_struct(None)), group]
  let flags = @bitset.BitSet::new(3)
  flags[2] = true
  rume_close_type_dependencies(flags, rec_types)
  let compacted = rume_compact_type_sec(
    @lib.Module::new().with_type_sec(@lib.TypeSec::new(rec_types)),
    precomputed_used_types=Some(flags),
  )
  @debug.assert_eq(compacted.type_sec, Some(@lib.TypeSec::new([group])))
}

///|
test "RUME recursive group compaction remaps last-member type and field names" {
  let dead_group = @lib.RecType::group([
    rume_group_test_struct(None),
    rume_group_test_struct(None),
  ])
  let live_group = @lib.RecType::group([
    rume_group_test_struct(Some(@lib.TypeIdx::new(3U))),
    rume_group_test_struct(Some(@lib.TypeIdx::new(2U))),
  ])
  let fields = @lib.NameMap::new([
    @lib.NameAssoc::new(0U, @lib.Name::from_string("next")),
  ])
  let module_ = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([dead_group, live_group]))
    .with_name_sec(
      @lib.NameSec::new(
        type_names=Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(1U, @lib.Name::from_string("dead")),
            @lib.NameAssoc::new(3U, @lib.Name::from_string("tail")),
          ]),
        ),
        field_names=Some(
          @lib.IndirectNameMap::new([
            @lib.IndirectNameAssoc::new(1U, fields),
            @lib.IndirectNameAssoc::new(3U, fields),
          ]),
        ),
      ),
    )
  let flags = @bitset.BitSet::new(4)
  flags[3] = true
  rume_close_type_dependencies(flags, module_.type_sec.unwrap().0)
  let compacted = rume_compact_type_sec(
    module_,
    precomputed_used_types=Some(flags),
  )
  let names = compacted.name_sec.unwrap()
  @debug.assert_eq(
    names.type_names,
    Some(
      @lib.NameMap::new([
        @lib.NameAssoc::new(1U, @lib.Name::from_string("tail")),
      ]),
    ),
  )
  @debug.assert_eq(
    names.field_names,
    Some(@lib.IndirectNameMap::new([@lib.IndirectNameAssoc::new(1U, fields)])),
  )
  assert_true(@validate.validate_module(compacted) is Ok(_))
  @debug.assert_eq(
    module_.type_sec,
    Some(@lib.TypeSec::new([dead_group, live_group])),
  )
}
