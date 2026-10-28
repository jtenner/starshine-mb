///|
test "review r1 validation accepts four levels of equivalent struct types" {
  let groups : Array[RecType] = []
  for base in [0U, 4U] {
    groups.push(RecType::new(SubType::comp_type(CompType::struct_([]))))
    for offset in 1..<4 {
      groups.push(
        RecType::new(
          SubType::comp_type(
            CompType::struct_([
              review_r1_20261025_field(base + offset.reinterpret_as_uint() - 1U),
            ]),
          ),
        ),
      )
    }
  }
  let module_ = review_r1_20261025_identity_module(groups, 3U, 7U, 8U)
  match validate_module(module_) {
    Ok(_) => ()
    Err(error) => fail(validation_error_message(error))
  }
}

///|
test "R1-06 chain boundaries match exactly and reject unequal leaves" {
  for depth in [1, 3, 4, 8] {
    for unequal in [false, true] {
      let types : Array[SubType] = []
      for chain in 0..<2 {
        types.push(
          SubType::comp_type(
            CompType::struct_(
              if unequal && chain == 1 {
                [
                  FieldType::new(
                    StorageType::val_type(ValType::i32()),
                    Mut::const_(),
                  ),
                ]
              } else {
                []
              },
            ),
          ),
        )
        for offset in 1..<depth {
          types.push(
            SubType::comp_type(
              CompType::struct_([
                review_r1_20261025_field(
                  (chain * depth + offset - 1).reinterpret_as_uint(),
                ),
              ]),
            ),
          )
        }
      }
      let env = Env::new().with_types(types)
      let a = HeapType::new(TypeIdx::new((depth - 1).reinterpret_as_uint()))
      let b = HeapType::new(TypeIdx::new((depth * 2 - 1).reinterpret_as_uint()))
      assert_eq(Match::matches(a, b, env), !unequal)
      assert_eq(exact_heaptype_matches(a, b, env), !unequal)
      assert_eq(Match::matches(b, a, env), !unequal)
    }
  }
}

///|
test "R1-06 recursive pairs terminate and still inspect fields after backedges" {
  for unequal in [false, true] {
    let types : Array[SubType] = []
    for index in 0..<2 {
      types.push(
        SubType::comp_type(
          CompType::struct_([
            review_r1_20261025_field(index.reinterpret_as_uint()),
            FieldType::new(
              StorageType::val_type(
                if unequal && index == 1 {
                  ValType::i64()
                } else {
                  ValType::i32()
                },
              ),
              Mut::const_(),
            ),
          ]),
        ),
      )
    }
    let env = Env::new().with_types(types)
    let a = HeapType::new(TypeIdx::new(0U))
    let b = HeapType::new(TypeIdx::new(1U))
    assert_eq(exact_heaptype_matches(a, b, env), !unequal)
    assert_eq(Match::matches(a, b, env), !unequal)
  }
}
