///|
// Keep the previous rendered-key contract. RefType and RecType Eq merge
// some spellings that rendering keeps separate; rendering itself normalizes
// explicit final subtypes and omits embedded subtype shared metadata.
priv enum DaeSignatureKeyPart {
  Values(Int32)
  Leaf(@lib.ValType)
  Reference(Bool, Bool)
  AbstractHeap(@lib.AbsHeapType)
  SharedHeap(@lib.AbsHeapType)
  IndexedHeap(@lib.TypeIdx)
  Definition(UInt32)
  Single
  Group(Int32)
  Subtype(Bool, @lib.TypeIdx?, @lib.TypeIdx?)
  Supertype(@lib.TypeIdx)
  ArrayType
  StructType(Int32)
  FunctionType
  ContinuationType(@lib.TypeIdx)
  Field(@lib.Mut)
  Packed(@lib.PackType)
} derive(Eq, Hash, Debug)

///|
// Parts are owned by the key and are never mutated after construction. Only
// scalar leaves are retained from the source; embedded arrays are traversed.
priv struct DaeSimpleFuncTypeKey(Array[DaeSignatureKeyPart]) derive (
  Eq,
  Hash,
  Debug,
)

///|
fn dae_structural_func_type_key(
  params : Array[@lib.ValType],
  results : Array[@lib.ValType],
) -> DaeSimpleFuncTypeKey {
  let parts = []
  dae_signature_key_values(parts, params)
  dae_signature_key_values(parts, results)
  DaeSimpleFuncTypeKey(parts)
}

///|
fn dae_signature_key_values(
  parts : Array[DaeSignatureKeyPart],
  values : Array[@lib.ValType],
) -> Unit {
  parts.push(Values(values.length()))
  for value in values {
    dae_signature_key_value(parts, value)
  }
}

///|
fn dae_signature_key_value(
  parts : Array[DaeSignatureKeyPart],
  value : @lib.ValType,
) -> Unit {
  match value {
    @lib.RefTypeValType(@lib.HeapTypeRefType(nullable, exact, heap)) => {
      parts.push(Reference(nullable, exact))
      match heap {
        @lib.AbsHeapTypeHeapType(abs) => parts.push(AbstractHeap(abs))
        @lib.SharedAbsHeapTypeHeapType(abs) => parts.push(SharedHeap(abs))
        @lib.HeapType(index) => parts.push(IndexedHeap(index))
        @lib.DefTypeHeapType(@lib.DefType(rec_type, member)) => {
          parts.push(Definition(member))
          match rec_type {
            @lib.SingleRecType(subtype) => {
              parts.push(Single)
              dae_signature_key_subtype(parts, subtype)
            }
            @lib.GroupRecType(group) => {
              parts.push(Group(group.length()))
              for subtype in group {
                dae_signature_key_subtype(parts, subtype)
              }
            }
          }
        }
      }
    }
    // Numeric, vector, bottom and abbreviated abstract-reference leaves have
    // no mutable children. No expanded reference reaches Leaf's derived Eq.
    _ => parts.push(Leaf(value))
  }
}

///|
fn dae_signature_key_subtype(
  parts : Array[DaeSignatureKeyPart],
  subtype : @lib.SubType,
) -> Unit {
  match subtype {
    @lib.SubType(final_, supers, metadata, _) => {
      parts.push(Subtype(final_, metadata.describes, metadata.descriptor))
      parts.push(Values(supers.length()))
      for supertype in supers {
        parts.push(Supertype(supertype))
      }
    }
    @lib.CompTypeSubType(metadata, _) => {
      parts.push(Subtype(true, metadata.describes, metadata.descriptor))
      parts.push(Values(0))
    }
  }
  match subtype.get_comptype() {
    @lib.ArrayCompType(field) => {
      parts.push(ArrayType)
      dae_signature_key_field(parts, field)
    }
    @lib.StructCompType(fields) => {
      parts.push(StructType(fields.length()))
      for field in fields {
        dae_signature_key_field(parts, field)
      }
    }
    @lib.FuncCompType(params, results) => {
      parts.push(FunctionType)
      dae_signature_key_values(parts, params)
      dae_signature_key_values(parts, results)
    }
    @lib.ContCompType(index) => parts.push(ContinuationType(index))
  }
}

///|
fn dae_signature_key_field(
  parts : Array[DaeSignatureKeyPart],
  field : @lib.FieldType,
) -> Unit {
  let @lib.FieldType(storage, mutability) = field
  parts.push(Field(mutability))
  match storage {
    @lib.ValTypeStorageType(value) => dae_signature_key_value(parts, value)
    @lib.PackTypeStorageType(packed) => parts.push(Packed(packed))
  }
}

// The shared-object pass keeps the rendered helper. This index is DAE-only.

///|
fn dae_structural_func_type_lookup(
  type_sec : @lib.TypeSec,
) -> @hashmap.HashMap[DaeSimpleFuncTypeKey, @lib.TypeIdx] {
  let @lib.TypeSec(rec_types) = type_sec
  let lookup : @hashmap.HashMap[DaeSimpleFuncTypeKey, @lib.TypeIdx] = @hashmap.new(
    capacity=dae_type_sec_flattened_length(type_sec) * 2 + 1,
  )
  let mut flat_idx = 0
  for rec_type in rec_types {
    let group = match rec_type {
      @lib.SingleRecType(subtype) => [subtype]
      @lib.GroupRecType(group) => group
    }
    let group_base = flat_idx
    let group_length = group.length()
    for subtype in group {
      match dae_simple_func_subtype_type(subtype) {
        Some(@lib.FuncType(params, results)) => {
          let owner = @lib.TypeIdx::new(flat_idx.reinterpret_as_uint())
          let (params, results) = (
            params.map(fn(value) {
              dae_absolutize_lookup_signature_val_type(
                group_base, group_length, value,
              )
            }),
            results.map(fn(value) {
              dae_absolutize_lookup_signature_val_type(
                group_base, group_length, value,
              )
            }),
          )
          let key = dae_structural_func_type_key(params, results)
          if lookup.get(key) is None {
            lookup.set(key, owner)
          }
        }
        None => ()
      }
      flat_idx += 1
    }
  }
  lookup
}
