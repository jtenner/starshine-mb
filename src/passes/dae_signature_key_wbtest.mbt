///|
fn dae_signature_key_reference_values() -> Array[@lib.ValType] {
  let abs = @lib.AbsHeapType::func()
  let plain = @lib.SubType::comp_type(@lib.CompType::func([], []))
  let nested = @lib.SubType::new(
    false,
    [@lib.TypeIdx::new(0U)],
    @lib.CompType::struct_([
      @lib.FieldType::new(
        @lib.StorageType::val_type(
          @lib.ValType::ref_type(@lib.RefType::abs(abs)),
        ),
        @lib.Mut::Var,
      ),
      @lib.FieldType::new(
        @lib.StorageType::pack_type(@lib.PackType::i8()),
        @lib.Mut::Const,
      ),
    ]),
  )
  let heaps = [
    @lib.HeapType::abs(abs),
    @lib.HeapType::shared_abs(abs),
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
    @lib.HeapType::new(@lib.rec_idx(0U)),
    @lib.HeapType::def_type(@lib.DefType::new(@lib.RecType::new(plain), 0U)),
    @lib.HeapType::def_type(@lib.DefType::new(@lib.RecType::group([plain]), 0U)),
    @lib.HeapType::def_type(
      @lib.DefType::new(@lib.RecType::group([plain, nested]), 1U),
    ),
  ]
  // Include the renderer's shared-metadata omission and final-subtype
  // equivalence: this performance change must not repair legacy collisions.
  let embedded_types = [
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i64()),
          @lib.Mut::Const,
        ),
      ),
    ),
    @lib.SubType::comp_type(@lib.CompType::cont(@lib.rec_idx(0U))),
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::ref_type(@lib.RefType::abs(abs))], []),
    ),
    @lib.SubType::comp_type(
      @lib.CompType::func(
        [
          @lib.ValType::ref_type(
            @lib.RefType::new(true, @lib.HeapType::abs(abs)),
          ),
        ],
        [],
      ),
    ),
    @lib.SubType::comp_type(
      @lib.CompType::func([], []),
      metadata=@lib.TypeMetadata::new(shared=true),
    ),
    @lib.SubType::comp_type(
      @lib.CompType::func([], []),
      metadata=@lib.TypeMetadata::new(describes=Some(@lib.TypeIdx::new(1U))),
    ),
    @lib.SubType::comp_type(
      @lib.CompType::func([], []),
      metadata=@lib.TypeMetadata::new(descriptor=Some(@lib.TypeIdx::new(1U))),
    ),
    @lib.SubType::new(true, [], @lib.CompType::func([], [])),
    @lib.SubType::new(false, [], @lib.CompType::func([], [])),
  ]
  for subtype in embedded_types {
    heaps.push(
      @lib.HeapType::def_type(@lib.DefType::new(@lib.RecType::new(subtype), 0U)),
    )
  }
  let values = [
    @lib.ValType::i32(),
    @lib.ValType::i64(),
    @lib.ValType::f32(),
    @lib.ValType::f64(),
    @lib.ValType::v128(),
    @lib.ValType::bottom(),
    @lib.ValType::ref_type(@lib.RefType::abs(abs)),
  ]
  for heap in heaps {
    for nullable in [false, true] {
      for exact in [false, true] {
        values.push(
          @lib.ValType::ref_type(@lib.RefType::new(nullable, heap, exact~)),
        )
      }
    }
  }
  values
}

///|
test "dae structural signature keys preserve rendered reference distinctions" {
  let values = dae_signature_key_reference_values()
  for left in values {
    for right in values {
      let left_key : DaeSimpleFuncTypeKey = dae_structural_func_type_key(
        [left],
        [],
      )
      let right_key : DaeSimpleFuncTypeKey = dae_structural_func_type_key(
        [right],
        [],
      )
      let same = [left].to_string() + "->[]" == [right].to_string() + "->[]"
      assert_eq(left_key == right_key, same)
      let lookup = @hashmap.new()
      lookup.set(left_key, 17)
      assert_eq(lookup.get(right_key), if same { Some(17) } else { None })
    }
  }
}

///|
test "dae structural signature keys separate lanes and own nested arrays" {
  let fields = [
    @lib.FieldType::new(
      @lib.StorageType::val_type(@lib.ValType::i32()),
      @lib.Mut::Var,
    ),
  ]
  let group = [@lib.SubType::comp_type(@lib.CompType::struct_(fields))]
  let params = [
    @lib.ValType::ref_type(
      @lib.RefType::new(
        true,
        @lib.HeapType::def_type(
          @lib.DefType::new(@lib.RecType::group(group), 0U),
        ),
      ),
    ),
  ]
  let results = [@lib.ValType::i64()]
  let key : DaeSimpleFuncTypeKey = dae_structural_func_type_key(params, results)
  let lookup = @hashmap.new()
  lookup.set(key, 3)
  assert_true(
    key == dae_structural_func_type_key(params.copy(), results.copy()),
  )
  assert_false(key == dae_structural_func_type_key(results, params))
  assert_false(
    dae_structural_func_type_key([@lib.ValType::i32()], [@lib.ValType::i64()]) ==
    dae_structural_func_type_key([@lib.ValType::i32(), @lib.ValType::i64()], []),
  )
  fields[0] = @lib.FieldType::new(
    @lib.StorageType::val_type(@lib.ValType::f64()),
    @lib.Mut::Const,
  )
  assert_false(key == dae_structural_func_type_key(params, results))
  group.clear()
  params.clear()
  results.clear()
  assert_eq(lookup.get(key), Some(3))
}

///|
test "dae structural signature lookup keeps first indices for wide signatures" {
  for width in [1, 32, 96] {
    let params = Array::make(width, @lib.ValType::i32())
    let different = params.copy()
    different[width - 1] = @lib.ValType::i64()
    let types = @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
      @lib.RecType::group([
        @lib.SubType::comp_type(@lib.CompType::func(params, [])),
        @lib.SubType::comp_type(@lib.CompType::func(different, [])),
        @lib.SubType::comp_type(@lib.CompType::func(params.copy(), [])),
      ]),
    ])
    let lookup = dae_structural_func_type_lookup(types)
    assert_eq(
      lookup.get(dae_structural_func_type_key(params, [])),
      Some(@lib.TypeIdx::new(1U)),
    )
    assert_eq(
      lookup.get(dae_structural_func_type_key(different, [])),
      Some(@lib.TypeIdx::new(2U)),
    )
    assert_eq(lookup.get(dae_structural_func_type_key([], params)), None)
  }
}

///|
test "dae structural signature index reuses appended signatures in a batch" {
  let input = signature_lookup_fixture(4)
  let indices = input.func_sec.unwrap().0.copy()
  let mut types = input.type_sec.unwrap()
  let index = DaeTypeUpdateIndex::new(types)
  let mut first = @lib.TypeIdx::new(0U)
  let mut distinct = first
  for def_idx in 0..<4 {
    let params = Array::make(32, @lib.ValType::i64())
    if def_idx == 2 {
      params[31] = @lib.ValType::f64()
    }
    let (next, chosen) = dae_update_defined_func_type(
      input,
      types,
      indices,
      def_idx,
      params,
      [],
      type_update_index=Some(index),
    )
    types = next
    indices[def_idx] = chosen
    match def_idx {
      0 => first = chosen
      2 => {
        distinct = chosen
        assert_false(distinct == first)
      }
      _ => assert_eq(chosen, first)
    }
  }
  assert_eq(
    index.flat_count,
    dae_type_sec_flattened_length(input.type_sec.unwrap()) + 2,
  )
  assert_eq(dae_type_sec_func_type(types, first).unwrap().0.length(), 32)
  assert_eq(
    dae_type_sec_func_type(types, distinct).unwrap().0[31],
    @lib.ValType::f64(),
  )
  @validate.validate_module(
    input.with_type_sec(types).with_func_sec(@lib.FuncSec::new(indices)),
  ).unwrap()
}
