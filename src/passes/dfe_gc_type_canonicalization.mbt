///|
fn dfe_rec_type_member_count(rec_type : @lib.RecType) -> Int {
  match rec_type {
    @lib.SingleRecType(_) => 1
    @lib.GroupRecType(subtypes) => subtypes.length()
  }
}

///|
fn dfe_gc_type_idx_precedes(idx : @lib.TypeIdx, flat_idx : UInt) -> Bool {
  match idx {
    @lib.TypeIdx(raw) => raw < flat_idx
    @lib.RecIdx(_) => false
  }
}

///|
fn dfe_gc_ref_type_precedes(ref_type : @lib.RefType, flat_idx : UInt) -> Bool {
  match ref_type {
    @lib.AbsHeapTypeRefType(_) => true
    @lib.HeapTypeRefType(_, _, heap_type) =>
      match heap_type {
        @lib.AbsHeapTypeHeapType(_) | @lib.SharedAbsHeapTypeHeapType(_) => true
        @lib.HeapType(idx) => dfe_gc_type_idx_precedes(idx, flat_idx)
        @lib.DefTypeHeapType(_) => false
      }
  }
}

///|
fn dfe_gc_val_type_precedes(val_type : @lib.ValType, flat_idx : UInt) -> Bool {
  match val_type {
    @lib.RefTypeValType(ref_type) =>
      dfe_gc_ref_type_precedes(ref_type, flat_idx)
    @lib.BotValType => false
    _ => true
  }
}

///|
fn dfe_gc_field_type_precedes(field : @lib.FieldType, flat_idx : UInt) -> Bool {
  let @lib.FieldType(storage, _) = field
  match storage {
    @lib.ValTypeStorageType(val_type) =>
      dfe_gc_val_type_precedes(val_type, flat_idx)
    @lib.PackTypeStorageType(_) => true
  }
}

///|
fn dfe_gc_subtype_is_backward_singleton(
  subtype : @lib.SubType,
  flat_idx : UInt,
) -> Bool {
  let metadata = subtype.metadata()
  if metadata.shared ||
    metadata.describes is Some(_) ||
    metadata.descriptor is Some(_) {
    return false
  }
  for super_type in subtype.super_types() {
    if !dfe_gc_type_idx_precedes(super_type, flat_idx) {
      return false
    }
  }
  match subtype.get_comptype() {
    @lib.StructCompType(fields) =>
      fields.all(field => dfe_gc_field_type_precedes(field, flat_idx))
    @lib.ArrayCompType(field) => dfe_gc_field_type_precedes(field, flat_idx)
    @lib.FuncCompType(params, results) =>
      params.all(value => dfe_gc_val_type_precedes(value, flat_idx)) &&
      results.all(value => dfe_gc_val_type_precedes(value, flat_idx))
    // Keep continuation definitions distinct in this bounded GC lane.
    @lib.ContCompType(_) => false
  }
}

///|
fn dfe_gc_key_val_type(val_type : @lib.ValType) -> @lib.ValType {
  match val_type {
    @lib.RefTypeValType(@lib.AbsHeapTypeRefType(abs)) =>
      @lib.ValType::ref_type(@lib.RefType::new(true, @lib.HeapType::abs(abs)))
    _ => val_type
  }
}

///|
fn dfe_gc_key_field_type(field : @lib.FieldType) -> @lib.FieldType {
  let @lib.FieldType(storage, mutable_) = field
  match storage {
    @lib.ValTypeStorageType(val_type) =>
      @lib.FieldType::new(
        @lib.StorageType::val_type(dfe_gc_key_val_type(val_type)),
        mutable_,
      )
    _ => field
  }
}

///|
fn dfe_gc_key_comp_type(comp_type : @lib.CompType) -> @lib.CompType {
  match comp_type {
    @lib.StructCompType(fields) =>
      @lib.CompType::struct_(fields.map(dfe_gc_key_field_type))
    @lib.ArrayCompType(field) =>
      @lib.CompType::array(dfe_gc_key_field_type(field))
    @lib.FuncCompType(params, results) =>
      @lib.CompType::func(
        params.map(dfe_gc_key_val_type),
        results.map(dfe_gc_key_val_type),
      )
    _ => comp_type
  }
}

///|
fn dfe_duplicate_backward_singleton_type_map(
  rec_types : Array[@lib.RecType],
) -> Map[UInt, UInt] {
  let aliases : Map[UInt, UInt] = Map([])
  let representatives : @hashmap.HashMap[@lib.SubType, UInt] = @hashmap.new(
    capacity=rec_types.length(),
  )
  let mut flat_idx = 0
  for rec_type in rec_types {
    let raw_idx = flat_idx.reinterpret_as_uint()
    match rec_type {
      @lib.SingleRecType(subtype) if dfe_gc_subtype_is_backward_singleton(
          subtype, raw_idx,
        ) => {
        let normalized = dfe_rewrite_sub_type(subtype, aliases)
        // A bare comptype is a final subtype without supers. Use one key shape
        // while retaining every semantic field, including exact ref flags.
        let key = match normalized {
          @lib.CompTypeSubType(metadata, comp_type) =>
            @lib.SubType::new(
              true,
              [],
              dfe_gc_key_comp_type(comp_type),
              metadata~,
            )
          @lib.SubType(final_, supers, metadata, comp_type) =>
            @lib.SubType::new(
              final_,
              supers,
              dfe_gc_key_comp_type(comp_type),
              metadata~,
            )
        }
        match representatives.get(key) {
          Some(canonical) => aliases[raw_idx] = canonical
          None => representatives.set(key, raw_idx)
        }
      }
      _ => ()
    }
    // Explicit recursive groups stay distinct; none of their members enter
    // the singleton dictionary. Do not unfold recursive graphs or iterate to
    // a fixpoint. One prefix walk closes all admitted backward alias chains.
    flat_idx += dfe_rec_type_member_count(rec_type)
  }
  aliases
}
