///|
test "proposal type diagnostics distinguish packed storage and field mutability" {
  let byte_field = FieldType::new(
    StorageType::pack_type(PackType::i8()),
    Mut::const_(),
  )
  let word_field = FieldType::new(
    StorageType::pack_type(PackType::i16()),
    Mut::var_(),
  )
  let vector_field = FieldType::new(
    StorageType::val_type(ValType::v128()),
    Mut::var_(),
  )
  inspect(byte_field, content="(Field Const (I8))")
  inspect(word_field, content="(Field Mut (I16))")
  inspect(vector_field, content="(Field Mut (V128))")
  inspect(CompType::array(byte_field), content="(Array (Field Const (I8)))")
  inspect(
    CompType::struct_([byte_field, word_field, vector_field]),
    content="(Struct (Field Const (I8)) (Field Mut (I16)) (Field Mut (V128)) )",
  )
  inspect(CompType::struct_([]), content="(Struct )")
}

///|
test "proposal type diagnostics retain continuation and exact reference identities" {
  inspect(CompType::cont(TypeIdx::new(7U)), content="(Cont (Type 7))")
  inspect(CompType::cont(TypeIdx::rec(2U)), content="(Cont (Rec 2))")
  let exact = RefType::new(false, HeapType::new(TypeIdx::new(7U)), exact=true)
  inspect(exact, content="(RefType Not Null Exact (HeapType Idx 7))")
  inspect(
    exact.make_nullable(),
    content="(RefType Null Exact (HeapType Idx 7))",
  )
  assert_true(exact.is_exact())
  assert_true(exact.make_nullable().is_exact())
  assert_true(exact.is_non_nullable())
  assert_true(exact.make_nullable().is_defaultable())
  inspect(
    RefType::new(true, HeapType::shared_abs(AbsHeapType::struct_())),
    content="(RefType Null (HeapType Shared (AbsHeapType Struct)))",
  )
  inspect(HeapType::bottom(), content="(HeapType (AbsHeapType None))")
  inspect(S33::new(0x1fffffffU), content="S33(536870911)")
}

///|
test "proposal subtype diagnostics retain descriptor metadata on both subtype forms" {
  let metadata = TypeMetadata::new(
    describes=Some(TypeIdx::rec(1U)),
    descriptor=Some(TypeIdx::new(5U)),
  )
  let aggregate = CompType::array(
    FieldType::new(StorageType::pack_type(PackType::i8()), Mut::var_()),
  )
  let open_type = SubType::new(false, [TypeIdx::new(9U)], aggregate, metadata~)
  inspect(
    open_type,
    content="(Sub (describes (Rec 1)) (descriptor (Type 5)) (Type 9) (Array (Field Mut (I8))))",
  )
  inspect(
    SubType::new(true, [], aggregate, metadata~),
    content="(Sub Final (describes (Rec 1)) (descriptor (Type 5)) (Array (Field Mut (I8))))",
  )
  let final_type = SubType::comp_type(aggregate, metadata~)
  inspect(
    final_type,
    content="(Sub Final (describes (Rec 1)) (descriptor (Type 5)) (Array (Field Mut (I8))))",
  )
  assert_eq(open_type.super_types(), [TypeIdx::new(9U)])
  assert_eq(final_type.super_types(), [])
  assert_eq(open_type.describes_type(), Some(TypeIdx::rec(1U)))
  assert_eq(final_type.descriptor_type(), Some(TypeIdx::new(5U)))
  assert_eq(open_type.get_comptype(), aggregate)
  assert_eq(final_type.get_comptype(), aggregate)
}

///|
test "proposal recursive diagnostics retain group order and definition identity" {
  let structure = SubType::comp_type(CompType::struct_([]))
  let continuation = SubType::comp_type(CompType::cont(TypeIdx::rec(0U)))
  let group = RecType::group([structure, continuation])
  inspect(
    group,
    content="(Rec (Sub Final (Struct )) (Sub Final (Cont (Rec 0))) )",
  )
  let definition = DefType::new(RecType::new(structure), 0U)
  inspect(definition, content="(DefType (Rec (Sub Final (Struct ))) 0)")
  inspect(
    HeapType::def_type(definition),
    content="(HeapType (DefType (Rec (Sub Final (Struct ))) 0))",
  )
  assert_eq(group.get_subtype(0U), Some(structure))
  assert_eq(group.get_subtype(1U), Some(continuation))
  assert_eq(group.get_subtype(2U), None)
  assert_eq(DefType::new(group, 1U).project(), Some(continuation))
}

///|
test "proposal aggregate classification projects definitions rather than abstract names" {
  let structure = SubType::comp_type(CompType::struct_([]))
  let array = SubType::comp_type(
    CompType::array(
      FieldType::new(StorageType::val_type(ValType::i64()), Mut::var_()),
    ),
  )
  let continuation = SubType::comp_type(CompType::cont(TypeIdx::new(0U)))
  let group = RecType::group([structure, array, continuation])
  for
    (index, is_structure, is_array) in [
      (0U, true, false),
      (1U, false, true),
      (2U, false, false),
    ] {
    let heap = HeapType::def_type(DefType::new(group, index))
    assert_eq(heap.is_struct(), is_structure)
    assert_eq(heap.is_array(), is_array)
    assert_eq(heap.is_gc_aggregate(), is_structure || is_array)
  }
  // An invalid projection has no concrete aggregate to classify.
  let absent = HeapType::def_type(DefType::new(group, 3U))
  assert_false(absent.is_struct())
  assert_false(absent.is_array())
  assert_false(absent.is_gc_aggregate())
  for
    heap in [
      HeapType::abs(AbsHeapType::struct_()),
      HeapType::new(TypeIdx::new(0U)),
    ] {
    assert_false(heap.is_struct())
    assert_false(heap.is_array())
    assert_false(heap.is_gc_aggregate())
  }
}

///|
test "proposal memory and table diagnostics retain wide limits and sharedness" {
  let wide = Limits::i64(4294967296UL, Some(8589934592UL))
  inspect(Limits::i32(1U, None), content="(Lim I32 1)")
  inspect(Limits::i32(1U, Some(4U)), content="(Lim I32 1 4)")
  inspect(Limits::i64(4294967296UL, None), content="(Lim I64 4294967296)")
  inspect(wide, content="(Lim I64 4294967296 8589934592)")
  inspect(MemType::new(wide), content="(Lim I64 4294967296 8589934592)")
  inspect(
    MemType::new(wide, shared=true),
    content="(MemType Shared (Lim I64 4294967296 8589934592))",
  )
  inspect(
    TableType::new(RefType::abs(AbsHeapType::func()), wide),
    content="(TableType (RefType Null (AbsHeapType Func)) (Lim I64 4294967296 8589934592))",
  )
  assert_eq(wide.mem_addr_bits(), 64)
  assert_eq(wide.addr_valtype(), ValType::i64())
}

///|
test "proposal external type diagnostics preserve tag global memory and table operands" {
  let tag = TagType::new(TypeIdx::new(13U))
  let constant = GlobalType::new(ValType::i64(), false)
  let variable = GlobalType::new(ValType::v128(), true)
  let memory = MemType::new(Limits::i64(2UL, Some(8UL)), shared=true)
  let table = TableType::new(
    RefType::abs(AbsHeapType::extern_()),
    Limits::i64(3UL, None),
  )
  inspect(ExternType::tag(tag), content="(Type 13)")
  inspect(ExternType::global(constant), content="(GlobalType I64)")
  inspect(ExternType::global(variable), content="(GlobalType Mut (V128))")
  inspect(ExternType::mem(memory), content="(MemType Shared (Lim I64 2 8))")
  inspect(
    ExternType::table(table),
    content="(TableType (RefType Null (AbsHeapType Extern)) (Lim I64 3))",
  )
  inspect(ExternType::func(TypeIdx::new(17U)), content="(Type 17)")
  inspect(ExternIdx::tag(TagIdx::new(13U)), content="(Tag 13)")
  inspect(ExternIdx::global(GlobalIdx::new(5U)), content="(Global 5)")
  inspect(ExternIdx::mem(MemIdx::new(2U)), content="(Mem 2)")
  inspect(ExternIdx::table(TableIdx::new(3U)), content="(Table 3)")
  inspect(ExternIdx::func(FuncIdx::new(17U)), content="(Func 17)")
}

///|
test "proposal memory section diagnostics preserve declaration order and shared limits" {
  inspect(MemSec::new([]), content="[Memory]")
  inspect(
    MemSec::new([
      MemType::new(Limits::i64(4294967296UL, Some(8589934592UL))),
      MemType::new(Limits::i64(2UL, Some(8UL)), shared=true),
    ]),
    content="[Memory: \n  - (Lim I64 4294967296 8589934592)\n  - (MemType Shared (Lim I64 2 8))\n]",
  )
}

///|
test "proposal tag and function section diagnostics preserve flattened type indices" {
  inspect(TagSec::new([]), content="[Tags]")
  inspect(
    TagSec::new([TagType::new(TypeIdx::new(3U)), TagType::new(TypeIdx::new(9U))]),
    content="[Tags: \n  - (Type 3)\n  - (Type 9)\n]",
  )
  inspect(FuncSec::new([]), content="[Funcs]")
  inspect(
    FuncSec::new([TypeIdx::new(9U), TypeIdx::new(3U), TypeIdx::new(9U)]),
    content="[Funcs: \n  - (Type 9)\n  - (Type 3)\n  - (Type 9)\n]",
  )
  inspect(TypeSec::new([]), content="[Types]")
}

///|
test "proposal table section diagnostics distinguish default and explicit initializers" {
  let table_type = TableType::new(
    RefType::abs(AbsHeapType::extern_()),
    Limits::i64(3UL, Some(12UL)),
  )
  let explicit_null = Expr::new([
    Instruction::ref_null_type(RefType::abs(AbsHeapType::extern_())),
  ])
  inspect(TableSec::new([]), content="[Tables]")
  inspect(
    TableSec::new([
      Table::new(table_type, None),
      Table::new(table_type, Some(explicit_null)),
    ]),
    content="[Tables: \n  - (Table (TableType (RefType Null (AbsHeapType Extern)) (Lim I64 3 12)))\n  - (Table (TableType (RefType Null (AbsHeapType Extern)) (Lim I64 3 12)) (ref.null (RefType Null (AbsHeapType Extern)))(end))\n]",
  )
}

///|
test "proposal global section diagnostics retain mutability and signed i64 initializers" {
  inspect(GlobalSec::new([]), content="[Globals]")
  inspect(
    GlobalSec::new([
      Global::new(
        GlobalType::new(ValType::i64(), false),
        Expr::new([Instruction::i64_const(I64::new(7L))]),
      ),
      Global::new(
        GlobalType::new(ValType::i64(), true),
        Expr::new([Instruction::i64_const(I64::new(-1L))]),
      ),
    ]),
    content="[Globals: \n  - (Global (GlobalType I64) (i64.const I64(7))(end))\n  - (Global (GlobalType Mut I64) (i64.const I64(-1))(end))\n]",
  )
}

///|
test "proposal shared heap accessors retain metadata through nullable references" {
  let metadata = TypeMetadata::new(
    describes=Some(TypeIdx::new(3U)),
    descriptor=Some(TypeIdx::new(5U)),
  )
  let shared = metadata.with_shared(true)
  assert_false(metadata.is_shared())
  assert_true(shared.is_shared())
  let subtype = SubType::comp_type(CompType::struct_([]), metadata=shared)
  assert_eq(subtype.describes_type(), Some(TypeIdx::new(3U)))
  assert_eq(subtype.descriptor_type(), Some(TypeIdx::new(5U)))
  let defined = HeapType::def_type(DefType::new(RecType::new(subtype), 0U))
  assert_true(defined.is_shared())
  assert_true(HeapType::shared_abs(AbsHeapType::struct_()).is_shared())
  let nullable = RefType::new(false, defined, exact=true).make_nullable()
  assert_true(nullable.is_nullable())
  assert_true(nullable.is_exact())
  assert_true(nullable.get_heap_type().is_shared())
}
