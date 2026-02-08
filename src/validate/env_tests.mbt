///|
test "Env.get_label_types uses stack-from-top indexing" {
  let env = Env::new().with_label([ValType::i32()]).with_label([ValType::i64()])
  assert_eq(env.get_label_types(LabelIdx::new(0)), Some([ValType::i64()]))
  assert_eq(env.get_label_types(LabelIdx::new(1)), Some([ValType::i32()]))
  assert_eq(env.get_label_types(LabelIdx::new(2)), None)
}

///|
test "Env.expand_blocktype resolves function type indices" {
  let rec_type = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [ValType::i64()])),
  )
  let env = Env::new().with_rectype(rec_type)
  match env.expand_blocktype(BlockType::type_idx(TypeIdx::new(0))) {
    Ok((params, results)) => {
      assert_eq(params, [ValType::i32()])
      assert_eq(results, [ValType::i64()])
    }
    Err(e) => fail("unexpected expand_blocktype error: \{e}")
  }
}

///|
test "Env.expand_blocktype reports missing function type" {
  let env = Env::new()
  match env.expand_blocktype(BlockType::type_idx(TypeIdx::new(0))) {
    Ok(_) => fail("expected error for unknown function type index")
    Err(msg) => assert_eq(msg, "blocktype type index is not a function type")
  }
}

///|
test "Env.resolve_heaptype_subtype handles abstract and indexed heap types" {
  let rec_type = RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
  )
  let env = Env::new().with_rectype(rec_type)
  assert_eq(
    env.resolve_heaptype_subtype(HeapType::abs(AbsHeapType::func())),
    None,
  )
  assert_true(
    env.resolve_heaptype_subtype(HeapType::new(TypeIdx::new(0))) is Some(_),
  )
}
