///|
fn dfe_gc_test_field(nullable : Bool, target : @lib.TypeIdx, exact? : Bool = false, mutable_? : Bool = false) -> @lib.FieldType {
  @lib.FieldType::new(
    @lib.StorageType::val_type(@lib.ValType::ref_type(
      @lib.RefType::new(nullable, @lib.HeapType::new(target), exact~),
    )),
    if mutable_ { @lib.Mut::var_() } else { @lib.Mut::const_() },
  )
}

///|
test "DFE singleton interning keeps recursive groups and proposal identity boundaries" {
  let base = @lib.SubType::comp_type(@lib.CompType::struct_([]))
  let base_ref = @lib.TypeIdx::new(0U)
  let numeric_field = @lib.FieldType::new(@lib.StorageType::val_type(@lib.ValType::i32()), @lib.Mut::const_())
  let numeric = @lib.CompType::struct_([numeric_field])
  let rec_types = [
    @lib.RecType::new(base), //0
    @lib.RecType::new(base), //1 aliases0
    @lib.RecType::group([base, base]), //2,3 stay distinct
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::array(dfe_gc_test_field(true, base_ref)))), //4
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::array(dfe_gc_test_field(true, @lib.TypeIdx::new(1U))))), //5 aliases4 transitively
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::array(dfe_gc_test_field(false, base_ref)))), //6 nullable differs
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::array(dfe_gc_test_field(true, base_ref, exact=true)))), //7 exact differs
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::array(dfe_gc_test_field(true, base_ref, mutable_=true)))), //8 mutable differs
    @lib.RecType::new(@lib.SubType::new(false, [], numeric)), //9 nonfinal
    @lib.RecType::new(@lib.SubType::new(true, [], numeric)), //10 final differs
    @lib.RecType::new(@lib.SubType::new(true, [@lib.TypeIdx::new(9U)], numeric)), //11 super differs
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]), metadata=@lib.TypeMetadata::new(shared=true))), //12 shared excluded
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]), metadata=@lib.TypeMetadata::new(descriptor=Some(base_ref)))), //13 descriptor excluded
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::array(dfe_gc_test_field(true, @lib.TypeIdx::new(14U))))), //14 self excluded
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::array(dfe_gc_test_field(true, @lib.TypeIdx::new(16U))))), //15 forward excluded
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::array(dfe_gc_test_field(true, @lib.TypeIdx::rec(0U))))), //16 group-local excluded
  ]
  @debug.assert_eq(dfe_duplicate_simple_type_canonical_map(rec_types), { 1U: 0U, 5U: 4U })
}

///|
test "DFE mixed GC interning normalizes equivalent abstract reference sugar" {
  let abbrev = @lib.ValType::funcref()
  let expanded = @lib.ValType::ref_type(@lib.RefType::new(
    true, @lib.HeapType::abs(@lib.AbsHeapType::func()),
  ))
  @debug.assert_eq(abbrev, expanded)
  let types = [abbrev, expanded].map(value =>
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([
      @lib.FieldType::new(@lib.StorageType::val_type(value), @lib.Mut::const_()),
    ]))),
  )
  @debug.assert_eq(dfe_duplicate_simple_type_canonical_map(types), { 1U: 0U })
}
