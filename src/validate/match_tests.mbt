///|
test "descriptor compatibility is symmetric for abstract refs" {
  let env = empty_env()
  let funcref = RefType::abs(AbsHeapType::func())
  let nofuncref = RefType::abs(AbsHeapType::no_func())
  @debug.assert_eq(
    descriptor_compatible(funcref, nofuncref, env),
    descriptor_compatible(nofuncref, funcref, env),
  )
}

///|
test "descriptor compatibility accepts equal exact struct shape" {
  let st0 = SubType::comp_type(CompType::struct_([]))
  let st1 = SubType::comp_type(CompType::struct_([]))
  let env = Env::{ ..empty_env(), global_types: [st0, st1] }
  let exact0 = RefType::new(true, HeapType::new(TypeIdx::new(0U)), exact=true)
  let exact1 = RefType::new(true, HeapType::new(TypeIdx::new(1U)), exact=true)
  assert_true(descriptor_compatible(exact0, exact1, env))
}

///|
test "descriptor compatibility rejects unequal exact struct shape" {
  let empty_struct = SubType::comp_type(CompType::struct_([]))
  let valued_struct = SubType::comp_type(
    CompType::struct_([
      FieldType::new(StorageType::val_type(ValType::i32()), Mut::const_()),
    ]),
  )
  let env = Env::{ ..empty_env(), global_types: [empty_struct, valued_struct] }
  let exact0 = RefType::new(true, HeapType::new(TypeIdx::new(0U)), exact=true)
  let exact1 = RefType::new(true, HeapType::new(TypeIdx::new(1U)), exact=true)
  assert_false(descriptor_compatible(exact0, exact1, env))
}
