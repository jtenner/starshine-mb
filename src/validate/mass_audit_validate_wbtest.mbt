///|
fn mass_audit_validate_type_module(types : Array[RecType]) -> Module {
  Module::new().with_type_sec(TypeSec::new(types))
}

///|
fn mass_audit_validate_function_module(
  types : Array[RecType],
  params : Array[ValType],
  results : Array[ValType],
  locals : Locals,
  body : Array[Instruction],
) -> Module {
  let all_types = types.copy()
  let signature = TypeIdx::new(all_types.length().reinterpret_as_uint())
  all_types.push(
    RecType::new(SubType::comp_type(CompType::func(params, results))),
  )
  Module::new()
  .with_type_sec(TypeSec::new(all_types))
  .with_func_sec(FuncSec::new([signature]))
  .with_code_sec(CodeSec::new([Func::new(locals, Expr::new(body))]))
}

///|
fn mass_audit_validate_ref(idx : UInt, nullable? : Bool = true) -> ValType {
  ValType::ref_type(RefType::new(nullable, HeapType::new(TypeIdx::new(idx))))
}

///|
fn mass_audit_validate_field(
  vt : ValType,
  mutable_? : Bool = false,
) -> FieldType {
  FieldType::new(
    StorageType::val_type(vt),
    if mutable_ {
      Mut::var_()
    } else {
      Mut::const_()
    },
  )
}

///|
fn mass_audit_validate_assert_valid(module_ : Module) -> Unit raise {
  match validate_module(module_) {
    Ok(_) => ()
    Err(error) => fail(validation_error_message(error))
  }
}

///|
test "mass audit intentionally rejects missing types inside explicit subtype composites" {
  let missing = mass_audit_validate_ref(7U)
  for
    ct in [
      CompType::struct_([mass_audit_validate_field(missing)]),
      CompType::array(mass_audit_validate_field(missing)),
      CompType::func([missing], []),
      CompType::func([], [missing]),
      CompType::cont(TypeIdx::new(7U)),
    ] {
    let module_ = mass_audit_validate_type_module([
      RecType::new(SubType::new(false, [], ct)),
    ])
    assert_true(validate_module(module_).is_err())
  }
}

///|
test "mass audit intentionally rejects forward declared supertypes in a recursive group" {
  let module_ = mass_audit_validate_type_module([
    RecType::group([
      SubType::new(false, [TypeIdx::new(1U)], CompType::struct_([])),
      SubType::new(false, [], CompType::struct_([])),
    ]),
  ])
  assert_true(validate_module(module_).is_err())
}

///|
test "mass audit intentionally rejects two declared supertypes" {
  let module_ = mass_audit_validate_type_module([
    RecType::new(SubType::new(false, [], CompType::struct_([]))),
    RecType::new(SubType::new(false, [], CompType::struct_([]))),
    RecType::new(
      SubType::new(
        false,
        [TypeIdx::new(0U), TypeIdx::new(1U)],
        CompType::struct_([]),
      ),
    ),
  ])
  assert_true(validate_module(module_).is_err())
}

///|
test "mass audit intentionally rejects an unshared field in a shared composite" {
  let module_ = mass_audit_validate_type_module([
    RecType::new(
      SubType::comp_type(
        CompType::struct_([mass_audit_validate_field(ValType::anyref())]),
        metadata=TypeMetadata::new(shared=true),
      ),
    ),
  ])
  assert_true(validate_module(module_).is_err())
}

///|
test "mass audit intentionally rejects a shared subtype of an unshared parent" {
  let module_ = mass_audit_validate_type_module([
    RecType::new(SubType::new(false, [], CompType::struct_([]))),
    RecType::new(
      SubType::new(
        false,
        [TypeIdx::new(0U)],
        CompType::struct_([]),
        metadata=TypeMetadata::new(shared=true),
      ),
    ),
  ])
  assert_true(validate_module(module_).is_err())
}

///|
test "mass audit intentionally rejects a defined function reference as anyref" {
  let module_ = mass_audit_validate_function_module(
    [RecType::new(SubType::comp_type(CompType::func([], [])))],
    [mass_audit_validate_ref(0U)],
    [ValType::anyref()],
    Locals::empty(),
    [Instruction::local_get(LocalIdx::new(0U))],
  )
  assert_true(validate_module(module_).is_err())
}

///|
test "mass audit intentionally rejects unshared bottom references as shared defined references" {
  let shared = TypeMetadata::new(shared=true)
  let types = [
    RecType::new(SubType::comp_type(CompType::struct_([]), metadata=shared)),
    RecType::new(SubType::comp_type(CompType::func([], []), metadata=shared)),
    RecType::new(
      SubType::comp_type(CompType::cont(TypeIdx::new(1U)), metadata=shared),
    ),
  ]
  let env = Env::new().with_types([
    types[0].get_subtype(0U).unwrap(),
    types[1].get_subtype(0U).unwrap(),
    types[2].get_subtype(0U).unwrap(),
  ])
  let bottoms = [
    AbsHeapType::none(),
    AbsHeapType::no_func(),
    AbsHeapType::no_cont(),
  ]
  for i = 0; i < bottoms.length(); i = i + 1 {
    let source = RefType::new(true, HeapType::abs(bottoms[i]))
    for exact in [false, true] {
      let target = RefType::new(
        true,
        HeapType::new(TypeIdx::new(i.reinterpret_as_uint())),
        exact~,
      )
      assert_false(Match::matches(source, target, env))
    }
  }
}

///|
test "mass audit intentionally rejects an implicit final type as an open canonical type" {
  let module_ = mass_audit_validate_function_module(
    [
      RecType::new(SubType::comp_type(CompType::struct_([]))),
      RecType::new(SubType::new(false, [], CompType::struct_([]))),
    ],
    [mass_audit_validate_ref(0U)],
    [mass_audit_validate_ref(1U)],
    Locals::empty(),
    [Instruction::local_get(LocalIdx::new(0U))],
  )
  assert_true(validate_module(module_).is_err())
}

///|
test "mass audit intentionally rejects extending an implicit final parent" {
  let module_ = mass_audit_validate_type_module([
    RecType::new(SubType::comp_type(CompType::struct_([]))),
    RecType::new(SubType::new(false, [TypeIdx::new(0U)], CompType::struct_([]))),
  ])
  assert_true(validate_module(module_).is_err())
}

///|
test "mass audit explicit final and implicit final types have the same canonical shape" {
  let env = Env::new().with_types([
    SubType::comp_type(CompType::struct_([])),
    SubType::new(true, [], CompType::struct_([])),
  ])
  let source = RefType::new(true, HeapType::new(TypeIdx::new(0U)), exact=true)
  let target = RefType::new(true, HeapType::new(TypeIdx::new(1U)), exact=true)
  assert_true(Match::matches(source, target, env))
}

///|
test "mass audit intentionally rejects memory64 limits above two to the forty eighth pages" {
  for
    limits in [
      Limits::i64(281474976710657UL, None),
      Limits::i64(0UL, Some(281474976710657UL)),
    ] {
    let module_ = Module::new().with_mem_sec(
      MemSec::new([MemType::new(limits)]),
    )
    assert_true(validate_module(module_).is_err())
  }
}

///|
test "mass audit table64 accepts a maximum above the table32 range" {
  mass_audit_validate_assert_valid(
    Module::new().with_table_sec(
      TableSec::new([
        Table::new(
          TableType::new(
            RefType::new(true, HeapType::abs(AbsHeapType::func())),
            Limits::i64(0UL, Some(4294967296UL)),
          ),
          None,
        ),
      ]),
    ),
  )
}

///|
test "mass audit reference instructions accept virtual bottom operands after unreachable" {
  for
    instr in [
      Instruction::ref_is_null(),
      Instruction::ref_eq(),
      Instruction::i31_get_s(),
      Instruction::i31_get_u(),
      Instruction::ref_test(false, HeapType::abs(AbsHeapType::any())),
      Instruction::ref_test(true, HeapType::abs(AbsHeapType::any())),
    ] {
    mass_audit_validate_assert_valid(
      mass_audit_validate_function_module(
        [],
        [],
        [ValType::i32()],
        Locals::empty(),
        [Instruction::unreachable_(), instr],
      ),
    )
  }
}

///|
test "mass audit ref.test accepts unrelated function types in the function hierarchy" {
  mass_audit_validate_assert_valid(
    mass_audit_validate_function_module(
      [
        RecType::new(SubType::comp_type(CompType::func([ValType::i32()], []))),
        RecType::new(SubType::comp_type(CompType::func([ValType::i64()], []))),
      ],
      [mass_audit_validate_ref(0U)],
      [ValType::i32()],
      Locals::empty(),
      [
        Instruction::local_get(LocalIdx::new(0U)),
        Instruction::ref_test(false, HeapType::new(TypeIdx::new(1U))),
      ],
    ),
  )
}

///|
test "mass audit ref.test accepts unrelated shared struct types in the shared any hierarchy" {
  let shared = TypeMetadata::new(shared=true)
  mass_audit_validate_assert_valid(
    mass_audit_validate_function_module(
      [
        RecType::new(
          SubType::comp_type(
            CompType::struct_([mass_audit_validate_field(ValType::i32())]),
            metadata=shared,
          ),
        ),
        RecType::new(
          SubType::comp_type(
            CompType::struct_([mass_audit_validate_field(ValType::i64())]),
            metadata=shared,
          ),
        ),
      ],
      [mass_audit_validate_ref(0U)],
      [ValType::i32()],
      Locals::empty(),
      [
        Instruction::local_get(LocalIdx::new(0U)),
        Instruction::ref_test(false, HeapType::new(TypeIdx::new(1U))),
      ],
    ),
  )
}

///|
test "mass audit intentionally rejects local initialization that escapes its control frame" {
  // Core pop_ctrl resets the initialization entries made inside this frame.
  // Binaryen v133 accepts these raw fixtures; keep that disagreement visible.
  let set = [
    Instruction::struct_new(TypeIdx::new(0U)),
    Instruction::local_set(LocalIdx::new(0U)),
  ]
  for
    control in [
      Instruction::block(BlockType::void_(), Expr::new(set)),
      Instruction::loop_(BlockType::void_(), Expr::new(set)),
      Instruction::try_table(BlockType::void_(), [], Expr::new(set)),
    ] {
    let module_ = mass_audit_validate_function_module(
      [RecType::new(SubType::comp_type(CompType::struct_([])))],
      [],
      [],
      Locals::from_types([mass_audit_validate_ref(0U, nullable=false)]),
      [control, Instruction::local_get(LocalIdx::new(0U)), Instruction::drop()],
    )
    assert_true(validate_module(module_).is_err())
  }
}

///|
test "mass audit intentionally rejects local initialization from both if arms outside the if" {
  let set = [
    Instruction::struct_new(TypeIdx::new(0U)),
    Instruction::local_set(LocalIdx::new(1U)),
  ]
  let module_ = mass_audit_validate_function_module(
    [RecType::new(SubType::comp_type(CompType::struct_([])))],
    [ValType::i32()],
    [],
    Locals::from_types([mass_audit_validate_ref(0U, nullable=false)]),
    [
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::if_(BlockType::void_(), set, Some(set)),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::drop(),
    ],
  )
  assert_true(validate_module(module_).is_err())
}

///|
test "mass audit intentionally rejects unsupported atomic storage types under the proposal rules" {
  // The shared-everything proposal permits only integer or anyref atomic storage.
  // wasm-tools rejects these; Binaryen v133 currently accepts them.
  for vt in [ValType::f32(), ValType::externref()] {
    let struct_type = RecType::new(
      SubType::comp_type(CompType::struct_([mass_audit_validate_field(vt)])),
    )
    let get = mass_audit_validate_function_module(
      [struct_type],
      [mass_audit_validate_ref(0U, nullable=false)],
      [vt],
      Locals::empty(),
      [
        Instruction::local_get(LocalIdx::new(0U)),
        Instruction::struct_atomic_get(
          AtomicOrder::seq_cst(),
          TypeIdx::new(0U),
          U32::new(0U),
        ),
      ],
    )
    assert_true(validate_module(get).is_err())
  }
  let array_get = mass_audit_validate_function_module(
    [
      RecType::new(
        SubType::comp_type(
          CompType::array(mass_audit_validate_field(ValType::f32())),
        ),
      ),
    ],
    [mass_audit_validate_ref(0U, nullable=false)],
    [ValType::f32()],
    Locals::empty(),
    [
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_const(I32(0)),
      Instruction::array_atomic_get(AtomicOrder::seq_cst(), TypeIdx::new(0U)),
    ],
  )
  assert_true(validate_module(array_get).is_err())
}

///|
test "mass audit intentionally rejects floating point atomic set storage under the proposal rules" {
  let module_ = mass_audit_validate_function_module(
    [
      RecType::new(
        SubType::comp_type(
          CompType::struct_([
            mass_audit_validate_field(ValType::f32(), mutable_=true),
          ]),
        ),
      ),
    ],
    [mass_audit_validate_ref(0U, nullable=false)],
    [],
    Locals::empty(),
    [
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::f32_const(F32(0.0)),
      Instruction::struct_atomic_set(
        AtomicOrder::seq_cst(),
        TypeIdx::new(0U),
        U32::new(0U),
      ),
    ],
  )
  assert_true(validate_module(module_).is_err())
}

///|
test "mass audit reference atomic exchange accepts proposal anyref storage" {
  // This is a Binaryen v133 parity gap. wasm-tools currently disagrees for unshared eqref.
  let eqref = ValType::eqref_null()
  mass_audit_validate_assert_valid(
    mass_audit_validate_function_module(
      [
        RecType::new(
          SubType::comp_type(
            CompType::struct_([mass_audit_validate_field(eqref, mutable_=true)]),
          ),
        ),
      ],
      [mass_audit_validate_ref(0U, nullable=false)],
      [eqref],
      Locals::empty(),
      [
        Instruction::local_get(LocalIdx::new(0U)),
        Instruction::ref_null(HeapType::abs(AbsHeapType::eq())),
        Instruction::struct_atomic_rmw(
          @lib.AggregateAtomicRmwOp::xchg(),
          TypeIdx::new(0U),
          U32::new(0U),
        ),
      ],
    ),
  )
}
