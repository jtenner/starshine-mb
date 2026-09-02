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
  let env = Env::{ ..empty_env(), global_types: [st0, st1], }
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
  let env = Env::{ ..empty_env(), global_types: [empty_struct, valued_struct], }
  let exact0 = RefType::new(true, HeapType::new(TypeIdx::new(0U)), exact=true)
  let exact1 = RefType::new(true, HeapType::new(TypeIdx::new(1U)), exact=true)
  assert_false(descriptor_compatible(exact0, exact1, env))
}

///|
test "non-exact refs match structurally equivalent array types" {
  let array0 = SubType::comp_type(
    CompType::array(
      FieldType::new(StorageType::val_type(ValType::f64()), Mut::var_()),
    ),
  )
  let array1 = SubType::comp_type(
    CompType::array(
      FieldType::new(StorageType::val_type(ValType::f64()), Mut::var_()),
    ),
  )
  let env = Env::{ ..empty_env(), global_types: [array0, array1], }
  let source = RefType::new(false, HeapType::new(TypeIdx::new(1U)))
  let target = RefType::new(true, HeapType::new(TypeIdx::new(0U)))
  assert_true(Match::matches(source, target, env))
}

///|
test "validate_module accepts array.get through an equivalent array type" {
  let array0 = RecType::new(
    SubType::comp_type(
      CompType::array(
        FieldType::new(StorageType::val_type(ValType::f64()), Mut::var_()),
      ),
    ),
  )
  let array1 = RecType::new(
    SubType::comp_type(
      CompType::array(
        FieldType::new(StorageType::val_type(ValType::f64()), Mut::var_()),
      ),
    ),
  )
  let array1_ref = ValType::ref_type(
    RefType::new(false, HeapType::new(TypeIdx::new(1U))),
  )
  let signature = RecType::new(
    SubType::comp_type(CompType::func([array1_ref], [ValType::f64()])),
  )
  let module_ = Module::new()
    .with_type_sec(TypeSec::new([array0, array1, signature]))
    .with_func_sec(FuncSec::new([TypeIdx::new(2U)]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::empty(),
          Expr::new([
            Instruction::local_get(LocalIdx::new(0U)),
            Instruction::i32_const(I32(0)),
            Instruction::array_get(TypeIdx::new(0U)),
          ]),
        ),
      ]),
    )
  match validate_module(module_) {
    Ok(_) => ()
    Err(error) => fail(validation_error_message(error))
  }
}
