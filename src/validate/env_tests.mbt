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

///|
fn env_test_func_subtype(
  params : Array[ValType],
  results : Array[ValType],
) -> SubType {
  SubType::comp_type(CompType::func(params, results))
}

///|
test "Env.resolve_subtype and resolve_typeidx_subtype return none for RecIdx without rec stack" {
  let env = Env::new()
  assert_eq(env.resolve_subtype(TypeIdx::rec(0)), None)
  assert_eq(env.resolve_typeidx_subtype(TypeIdx::rec(0)), None)
}

///|
test "Env.with_rectype group supports RecIdx lookups and function resolution" {
  let st_func = env_test_func_subtype([ValType::i32()], [ValType::i64()])
  let st_struct = SubType::comp_type(CompType::struct_([]))
  let env = Env::new().with_rectype(RecType::group([st_func, st_struct]))

  assert_true(env.resolve_subtype(TypeIdx::rec(0)) is Some(_))
  assert_true(env.resolve_subtype(TypeIdx::rec(1)) is Some(_))
  assert_eq(env.resolve_subtype(TypeIdx::rec(2)), None)

  assert_true(env.resolve_functype(TypeIdx::rec(0)) is Some(_))
  assert_eq(env.resolve_functype(TypeIdx::rec(1)), None)
}

///|
test "Env.get_label uses direct indexing while get_label_types uses stack-from-top indexing" {
  let env = Env::new().with_label([ValType::i32()]).with_label([ValType::i64()])
  assert_eq(env.get_label(LabelIdx::new(0)), Some([ValType::i32()]))
  assert_eq(env.get_label(LabelIdx::new(1)), Some([ValType::i64()]))
  assert_eq(env.get_label_types(LabelIdx::new(0)), Some([ValType::i64()]))
  assert_eq(env.get_label_types(LabelIdx::new(1)), Some([ValType::i32()]))
}

///|
test "Env.resolve_tag_functype returns none for missing tag and non-function tag type" {
  let env_missing = Env::new()
  assert_eq(env_missing.resolve_tag_functype(TagIdx::new(0)), None)

  let struct_subtype = SubType::comp_type(CompType::struct_([]))
  let env_non_func = Env::new()
    .with_types([struct_subtype])
    .push_tag(TagType::new(TypeIdx::new(0)))
  assert_eq(env_non_func.resolve_tag_functype(TagIdx::new(0)), None)
}

///|
test "Env.resolve_struct_fields reports unknown and wrong-kind types" {
  let struct_subtype = SubType::comp_type(
    CompType::struct_([
      FieldType::new(StorageType::val_type(ValType::i32()), Var),
    ]),
  )
  let array_subtype = SubType::comp_type(
    CompType::array(FieldType::new(StorageType::val_type(ValType::i32()), Var)),
  )
  let env = Env::new().with_types([struct_subtype, array_subtype])

  match env.resolve_struct_fields(TypeIdx::new(0)) {
    Ok(fields) => assert_eq(fields.length(), 1)
    Err(e) => fail("unexpected struct field resolution error: \{e}")
  }

  match env.resolve_struct_fields(TypeIdx::new(1)) {
    Ok(_) => fail("expected non-struct type to fail")
    Err(e) => assert_eq(e, "type is not a struct")
  }

  match env.resolve_struct_fields(TypeIdx::new(99)) {
    Ok(_) => fail("expected unknown type index to fail")
    Err(e) => assert_eq(e, "unknown type index")
  }
}

///|
test "Env.resolve_array_field reports unknown and wrong-kind types" {
  let struct_subtype = SubType::comp_type(
    CompType::struct_([
      FieldType::new(StorageType::val_type(ValType::i32()), Var),
    ]),
  )
  let array_field = FieldType::new(StorageType::val_type(ValType::i64()), Var)
  let array_subtype = SubType::comp_type(CompType::array(array_field))
  let env = Env::new().with_types([struct_subtype, array_subtype])

  match env.resolve_array_field(TypeIdx::new(1)) {
    Ok(field) => assert_eq(field, array_field)
    Err(e) => fail("unexpected array field resolution error: \{e}")
  }

  match env.resolve_array_field(TypeIdx::new(0)) {
    Ok(_) => fail("expected non-array type to fail")
    Err(e) => assert_eq(e, "type is not an array")
  }

  match env.resolve_array_field(TypeIdx::new(99)) {
    Ok(_) => fail("expected unknown type index to fail")
    Err(e) => assert_eq(e, "unknown type index")
  }
}

///|
test "Env.resolve_descriptor_target_ref_type validates target type indices" {
  let env = Env::new()
  match
    env.resolve_descriptor_target_ref_type(
      false,
      HeapType::new(TypeIdx::new(0)),
    ) {
    Ok(_) => fail("expected invalid descriptor reftype to fail validation")
    Err(e) => assert_true(e.contains("invalid descriptor target reftype"))
  }
}

///|
test "Env.with_module populates imports and sections across index spaces" {
  let func_type = RecType::new(
    env_test_func_subtype([ValType::i32()], [ValType::i64()]),
  )
  let import_table = TableType::new(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
    Limits::i32(1, None),
  )
  let import_mem = MemType::new(Limits::i32(1, None))
  let import_global = GlobalType::new(ValType::i32(), false)
  let import_tag = TagType::new(TypeIdx::new(0))

  let defined_table = Table::new(
    TableType::new(
      RefType::new(true, HeapType::abs(AbsHeapType::func())),
      Limits::i32(2, None),
    ),
    None,
  )
  let defined_global = Global::new(
    GlobalType::new(ValType::i64(), false),
    Expr::new([Instruction::i64_const(I64(0))]),
  )
  let defined_tag = TagType::new(TypeIdx::new(0))
  let elem = Elem::new(ElemMode::passive(), ElemKind::funcs([FuncIdx::new(0)]))
  let data = Data::new(DataMode::passive(), b"abc")

  let mod = Module::new()
    .with_type_sec(TypeSec::new([func_type]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("f"),
          ExternType::func(TypeIdx::new(0)),
        ),
        Import::new(
          Name::new("env"),
          Name::new("tab"),
          ExternType::table(import_table),
        ),
        Import::new(
          Name::new("env"),
          Name::new("mem"),
          ExternType::mem(import_mem),
        ),
        Import::new(
          Name::new("env"),
          Name::new("g"),
          ExternType::global(import_global),
        ),
        Import::new(
          Name::new("env"),
          Name::new("t"),
          ExternType::tag(import_tag),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_table_sec(TableSec::new([defined_table]))
    .with_mem_sec(MemSec::new([MemType::new(Limits::i32(3, None))]))
    .with_global_sec(GlobalSec::new([defined_global]))
    .with_tag_sec(TagSec::new([defined_tag]))
    .with_elem_sec(ElemSec::new([elem]))
    .with_data_sec(DataSec::new([data]))

  let env = Env::new().with_module(mod)
  assert_true(env.has_func(FuncIdx::new(0)))
  assert_true(env.has_func(FuncIdx::new(1)))
  assert_false(env.has_func(FuncIdx::new(2)))

  assert_true(env.get_table_type(TableIdx::new(0)) is Some(_))
  assert_true(env.get_table_type(TableIdx::new(1)) is Some(_))
  assert_true(env.get_memtype(MemIdx::new(0)) is Some(_))
  assert_true(env.get_memtype(MemIdx::new(1)) is Some(_))
  assert_true(env.get_global_type(GlobalIdx::new(0)) is Some(_))
  assert_true(env.get_global_type(GlobalIdx::new(1)) is Some(_))
  assert_true(env.get_tag(TagIdx::new(0)) is Some(_))
  assert_true(env.get_tag(TagIdx::new(1)) is Some(_))
  assert_true(env.get_elem(ElemIdx::new(0)) is Some(_))
  assert_true(env.has_data(DataIdx::new(0)))
}

///|
test "Env.with_module skips imports and funcs whose type indices are not function types" {
  let struct_type = RecType::new(SubType::comp_type(CompType::struct_([])))
  let func_type = RecType::new(env_test_func_subtype([ValType::i64()], []))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_type, func_type]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("bad_import"),
          ExternType::func(TypeIdx::new(0)),
        ),
        Import::new(
          Name::new("env"),
          Name::new("good_import"),
          ExternType::func(TypeIdx::new(1)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))

  let env = Env::new().with_module(mod)
  assert_true(env.has_func(FuncIdx::new(0)))
  assert_true(env.has_func(FuncIdx::new(1)))
  assert_false(env.has_func(FuncIdx::new(2)))

  match env.get_functype_by_funcidx(FuncIdx::new(0)) {
    Some(FuncType(params, _)) => assert_eq(params, [ValType::i64()])
    _ => fail("expected first resolved function type")
  }
  match env.get_functype_by_funcidx(FuncIdx::new(1)) {
    Some(FuncType(params, _)) => assert_eq(params, [ValType::i64()])
    _ => fail("expected second resolved function type")
  }
}

///|
test "to_texpr reports stack underflow for unary operator with empty stack" {
  let env = Env::new()
  let expr = Expr::new([Instruction::i32_eqz()])
  match to_texpr(expr, env) {
    Ok(_) => fail("expected unary conversion underflow")
    Err(e) => assert_eq(e, "Stack underflow during tree conversion")
  }
}

///|
test "to_texpr reports pop_n underflow for call with insufficient arguments" {
  let env = Env::new().with_funcs([
    FuncType::new([ValType::i32(), ValType::i32()], []),
  ])
  let expr = Expr::new([
    Instruction::i32_const(I32(1)),
    Instruction::call(FuncIdx::new(0)),
  ])
  match to_texpr(expr, env) {
    Ok(_) => fail("expected call argument underflow")
    Err(e) =>
      assert_eq(e, "Stack underflow: need 2 values but only 1 available")
  }
}

///|
test "to_texpr uses type-index block inputs including recursive index forms" {
  let func_type = RecType::new(
    env_test_func_subtype([ValType::i32()], [ValType::i32()]),
  )
  let env = Env::new().with_rectype(func_type)
  let expr = Expr::new([
    Instruction::i32_const(I32(7)),
    Instruction::block(
      BlockType::type_idx(TypeIdx::rec(0)),
      Expr::new([Instruction::i32_eqz()]),
    ),
  ])
  match to_texpr(expr, env) {
    Err(e) => fail("unexpected conversion error: \{e}")
    Ok(TExpr(instrs)) => {
      assert_eq(instrs.length(), 1)
      match instrs[0] {
        TBlock(TypeIdxBlockType(_), TExpr(body)) => assert_eq(body.length(), 1)
        _ => fail("expected type-indexed block in converted expression")
      }
    }
  }
}

///|
test "to_texpr throw conversion uses tag payload arity" {
  let tag_sig = env_test_func_subtype([ValType::i32(), ValType::i64()], [])
  let env = Env::new()
    .with_rectype(RecType::new(tag_sig))
    .push_tag(TagType::new(TypeIdx::new(0)))
  let expr = Expr::new([
    Instruction::i32_const(I32(7)),
    Instruction::throw_(TagIdx::new(0)),
  ])
  match to_texpr(expr, env) {
    Ok(_) => fail("expected throw payload underflow")
    Err(e) =>
      assert_eq(e, "Stack underflow: need 2 values but only 1 available")
  }
}

///|
test "to_texpr call conversion uses imported and defined function arities from with_module" {
  let import_type = RecType::new(env_test_func_subtype([ValType::i32()], []))
  let defined_type = RecType::new(
    env_test_func_subtype([ValType::i32(), ValType::i64()], []),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([import_type, defined_type]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("imported"),
          ExternType::func(TypeIdx::new(0)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))

  let env = Env::new().with_module(mod)
  let expr = Expr::new([
    Instruction::i32_const(I32(11)),
    Instruction::call(FuncIdx::new(0)),
    Instruction::i32_const(I32(21)),
    Instruction::i64_const(I64(22)),
    Instruction::call(FuncIdx::new(1)),
  ])
  match to_texpr(expr, env) {
    Err(e) => fail("unexpected call conversion error: \{e}")
    Ok(TExpr(instrs)) => {
      assert_eq(instrs.length(), 2)
      match instrs[0] {
        TCall(FuncIdx(i), args) => {
          assert_eq(i, 0U)
          assert_eq(args.length(), 1)
        }
        _ => fail("expected imported call conversion")
      }
      match instrs[1] {
        TCall(FuncIdx(i), args) => {
          assert_eq(i, 1U)
          assert_eq(args.length(), 2)
        }
        _ => fail("expected defined call conversion")
      }
    }
  }
}

///|
test "to_texpr call_indirect underflow uses type-index parameter arity" {
  let env = Env::new().with_rectype(
    RecType::new(env_test_func_subtype([ValType::i32(), ValType::i64()], [])),
  )
  let expr = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::call_indirect(TypeIdx::new(0), TableIdx::new(0)),
  ])
  match to_texpr(expr, env) {
    Ok(_) => fail("expected call_indirect argument underflow")
    Err(e) =>
      assert_eq(e, "Stack underflow: need 2 values but only 0 available")
  }
}

///|
test "to_texpr return underflow uses configured return_type arity" {
  let env = Env::new().with_return_type(Some([ValType::i64()]))
  let expr = Expr::new([Instruction::return_()])
  match to_texpr(expr, env) {
    Ok(_) => fail("expected return underflow")
    Err(e) =>
      assert_eq(e, "Stack underflow: need 1 values but only 0 available")
  }
}

///|
test "Env.resolve_heaptype_subtype projects DefType heap types" {
  let st = SubType::comp_type(CompType::struct_([]))
  let dt = DefType::new(RecType::new(st), 0)
  let env = Env::new()
  assert_true(
    env.resolve_heaptype_subtype(HeapType::def_type(dt))
    is Some(CompTypeSubType(StructCompType(_))),
  )
  assert_eq(env.descriptor_result_type(), ValType::i32())
}

///|
test "block_type_inputs handles void, value, and unresolved typeidx forms" {
  let empty_env = Env::new()
  assert_eq(block_type_inputs(BlockType::void_(), empty_env), 0)
  assert_eq(
    block_type_inputs(BlockType::val_type(ValType::i64()), empty_env),
    0,
  )
  assert_eq(
    block_type_inputs(BlockType::type_idx(TypeIdx::new(0)), empty_env),
    0,
  )

  let env = Env::new().with_rectype(
    RecType::new(
      SubType::comp_type(
        CompType::func([ValType::i32(), ValType::i64()], [ValType::i32()]),
      ),
    ),
  )
  assert_eq(block_type_inputs(BlockType::type_idx(TypeIdx::new(0)), env), 2)
}

///|
test "instr_to_tinstr covers additional const nullary and unary branches" {
  let env = Env::new()

  let const_stack : Array[TInstr] = []
  ignore(instr_to_tinstr(Instruction::f32_const(F32(1.5)), const_stack, env))
  ignore(instr_to_tinstr(Instruction::f64_const(F64(2.5)), const_stack, env))
  ignore(
    instr_to_tinstr(
      Instruction::v128_const(
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
      ),
      const_stack,
      env,
    ),
  )
  ignore(instr_to_tinstr(Instruction::unreachable_(), const_stack, env))
  ignore(
    instr_to_tinstr(
      Instruction::global_get(GlobalIdx::new(0)),
      const_stack,
      env,
    ),
  )
  ignore(
    instr_to_tinstr(Instruction::memory_size(MemIdx::new(0)), const_stack, env),
  )
  ignore(
    instr_to_tinstr(Instruction::table_size(TableIdx::new(0)), const_stack, env),
  )
  assert_eq(const_stack.length(), 7)

  let unary_instrs = [
    Instruction::i64_eqz(),
    Instruction::i32_clz(),
    Instruction::i32_ctz(),
    Instruction::i32_popcnt(),
    Instruction::i64_clz(),
    Instruction::i64_ctz(),
    Instruction::i64_popcnt(),
    Instruction::f32_abs(),
    Instruction::f32_neg(),
    Instruction::f32_ceil(),
    Instruction::f32_floor(),
    Instruction::f32_trunc(),
    Instruction::f32_nearest(),
    Instruction::f32_sqrt(),
    Instruction::f64_abs(),
    Instruction::f64_neg(),
    Instruction::f64_ceil(),
    Instruction::f64_floor(),
  ]
  for instr in unary_instrs {
    let stack = [TInstr::i32_const(I32(7))]
    match instr_to_tinstr(instr, stack, env) {
      Ok(_) => assert_eq(stack.length(), 1)
      Err(e) => fail("unexpected unary conversion failure: \{e}")
    }
  }
}
