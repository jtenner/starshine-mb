///|
fn dfe_gc_test_field(
  nullable : Bool,
  target : @lib.TypeIdx,
  exact? : Bool = false,
  mutable_? : Bool = false,
) -> @lib.FieldType {
  @lib.FieldType::new(
    @lib.StorageType::val_type(
      @lib.ValType::ref_type(
        @lib.RefType::new(nullable, @lib.HeapType::new(target), exact~),
      ),
    ),
    if mutable_ {
      @lib.Mut::var_()
    } else {
      @lib.Mut::const_()
    },
  )
}

///|
test "DFE singleton interning keeps recursive groups and proposal identity boundaries" {
  let base = @lib.SubType::comp_type(@lib.CompType::struct_([]))
  let base_ref = @lib.TypeIdx::new(0U)
  let numeric_field = @lib.FieldType::new(
    @lib.StorageType::val_type(@lib.ValType::i32()),
    @lib.Mut::const_(),
  )
  let numeric = @lib.CompType::struct_([numeric_field])
  let rec_types = [
    @lib.RecType::new(base), //0
    @lib.RecType::new(base), //1 aliases0
    @lib.RecType::group([base, base]), //2,3 stay distinct
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::array(dfe_gc_test_field(true, base_ref)),
      ),
    ), //4
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::array(dfe_gc_test_field(true, @lib.TypeIdx::new(1U))),
      ),
    ), //5 aliases4 transitively
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::array(dfe_gc_test_field(false, base_ref)),
      ),
    ), //6 nullable differs
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::array(dfe_gc_test_field(true, base_ref, exact=true)),
      ),
    ), //7 exact differs
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::array(dfe_gc_test_field(true, base_ref, mutable_=true)),
      ),
    ), //8 mutable differs
    @lib.RecType::new(@lib.SubType::new(false, [], numeric)), //9 nonfinal
    @lib.RecType::new(@lib.SubType::new(true, [], numeric)), //10 final differs
    @lib.RecType::new(@lib.SubType::new(true, [@lib.TypeIdx::new(9U)], numeric)), //11 super differs
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::struct_([]),
        metadata=@lib.TypeMetadata::new(shared=true),
      ),
    ), //12 shared excluded
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::struct_([]),
        metadata=@lib.TypeMetadata::new(descriptor=Some(base_ref)),
      ),
    ), //13 descriptor excluded
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::array(dfe_gc_test_field(true, @lib.TypeIdx::new(14U))),
      ),
    ), //14 self excluded
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::array(dfe_gc_test_field(true, @lib.TypeIdx::new(16U))),
      ),
    ), //15 forward excluded
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::array(dfe_gc_test_field(true, @lib.TypeIdx::rec(0U))),
      ),
    ), //16 group-local excluded
  ]
  @debug.assert_eq(dfe_duplicate_simple_type_canonical_map(rec_types), {
    1U: 0U,
    5U: 4U,
  })
}

///|
test "DFE mixed GC interning normalizes equivalent abstract reference sugar" {
  let abbrev = @lib.ValType::funcref()
  let expanded = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::func())),
  )
  @debug.assert_eq(abbrev, expanded)
  let types = [abbrev, expanded].map(value => {
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::struct_([
          @lib.FieldType::new(
            @lib.StorageType::val_type(value),
            @lib.Mut::const_(),
          ),
        ]),
      ),
    )
  })
  @debug.assert_eq(dfe_duplicate_simple_type_canonical_map(types), { 1U: 0U })
}

///|
test "DFE GC lane retains unsupported identity forms and normalizes implicit finality" {
  let comp = @lib.CompType::struct_([])
  let bare = @lib.SubType::comp_type(comp)
  @debug.assert_eq(
    dfe_duplicate_simple_type_canonical_map([
      @lib.RecType::new(bare),
      @lib.RecType::new(@lib.SubType::new(true, [], comp)),
    ]),
    { 1U: 0U },
  )
  // These exclusions apply to this bounded canonicalization lane, not to
  // decoding, execution or other optimizer passes supporting the proposals.
  let inline_def = @lib.ValType::ref_type(
    @lib.RefType::new(
      true,
      @lib.HeapType::def_type(@lib.DefType::new(@lib.RecType::new(bare), 0U)),
    ),
  )
  for
    subtype in [
      @lib.SubType::comp_type(
        comp,
        metadata=@lib.TypeMetadata::new(describes=Some(@lib.TypeIdx::new(0U))),
      ),
      @lib.SubType::comp_type(@lib.CompType::func([inline_def], [])),
      @lib.SubType::comp_type(@lib.CompType::cont(@lib.TypeIdx::new(0U))),
    ] {
    assert_false(dfe_gc_subtype_is_backward_singleton(subtype, 5U))
  }
}

///|
test "DFE no-alias mixed GC control preserves canonical bytes" {
  // Distinct singleton types, an explicit group and a protected constant body
  // have no aliases or legacy cleanup triggers. This is a narrow identity
  // control, not a claim that arbitrary DFE modules retain their bytes.
  let input = @binary.decode_module(
    b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x13\x03\x5f\x01\x7f\x00\x4e\x02\x5f\x01\x63\x02\x00\x5e\x7e\x01\x60\x00\x01\x7f\x03\x02\x01\x03\x07\x07\x01\x03\x72\x75\x6e\x00\x00\x0a\x06\x01\x04\x00\x41\x03\x0b",
  ).unwrap()
  assert_true(@validate.validate_module(input) is Ok(_))
  @debug.assert_eq(
    dfe_duplicate_simple_type_canonical_map(input.type_sec.unwrap().0),
    {},
  )
  let before = @binary.encode_module(input).unwrap()
  let output = dfe_run_module_pass(input)
  @debug.assert_eq(@binary.encode_module(output).unwrap(), before)
  assert_true(@validate.validate_module(output) is Ok(_))
}
