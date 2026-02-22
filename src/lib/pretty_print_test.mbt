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

  inspect_pretty_print(heap_ty, content="(HeapType Idx 3)")
  inspect_pretty_print(ref_ty, content="(RefType Not Null (HeapType Idx 3))")
}
