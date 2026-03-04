///|
test "pretty print snapshots for core wasm types" {
  let ty = NumType::i32()

  inspect(ty, content="I32")
  inspect_debug(ty, content="I32NumType")
  inspect_pretty_print(ty, content="I32")
}

///|
test "pretty print wraps long lines with configured width" {
  let expr = Expr::new([
    Instruction::i32_const(I32(1)),
    Instruction::i32_const(I32(2)),
    Instruction::i32_const(I32(3)),
    Instruction::i32_add(),
    Instruction::drop(),
  ])
  let ctx = PrettyPrintContext::new(max_line_width=24U)
  inspect_pretty_print(
    expr,
    ctx~,
    content="(i32.const\n  I32(1))(i32.const\n  I32(2))(i32.const\n  I32(3))i32.adddrop(end)",
  )
}

///|
test "show smoke for ref and index types" {
  let type_idx = TypeIdx::new(9U)
  let rec_idx = TypeIdx::rec(2U)
  let ref_ty = RefType::new(true, HeapType::new(rec_idx))

  inspect(type_idx, content="(Type 9)")
  inspect(rec_idx, content="(Rec 2)")
  inspect(ref_ty, content="(RefType Null (HeapType Rec 2))")
}

///|
test "pretty print smoke for show-backed core impls" {
  let heap_ty = HeapType::new(TypeIdx::new(3U))
  let ref_ty = RefType::new(false, heap_ty)

  inspect_pretty_print(heap_ty, content="(Type 3)")
  inspect_pretty_print(ref_ty, content="(Ref (Type 3))")
}

///|
test "pretty print type sections resolve flattened type indexes" {
  let type_sec = TypeSec::new([
    RecType::new(
      SubType::comp_type(CompType::func([ValType::i32()], [ValType::i64()])),
    ),
    RecType::new(
      SubType::comp_type(
        CompType::struct_([
          FieldType::new(StorageType::val_type(ValType::i32()), Mut::const_()),
          FieldType::new(StorageType::val_type(ValType::i64()), Mut::var_()),
        ]),
      ),
    ),
    RecType::new(
      SubType::comp_type(
        CompType::array(
          FieldType::new(StorageType::val_type(ValType::i32()), Mut::const_()),
        ),
      ),
    ),
  ])

  let printed = type_sec.pretty_print(PrettyPrintContext::new())
  assert_true(printed.contains("(Type 0 (Func [I32] -> [I64]))"), msg=printed)
  assert_true(
    printed.contains("(Type 1 (Struct [I32, (Mut I64)]))"),
    msg=printed,
  )
  assert_true(printed.contains("(Type 2 (Array I32))"), msg=printed)
}
