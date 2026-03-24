///|
fn hot_test_module_context_fixture() -> HotModuleContext {
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i64()]),
      ),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::struct_([
          @lib.FieldType::new(
            @lib.StorageType::val_type(@lib.ValType::i32()),
            @lib.Mut::const_(),
          ),
        ]),
      ),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::array(
          @lib.FieldType::new(
            @lib.StorageType::val_type(@lib.ValType::i64()),
            @lib.Mut::var_(),
          ),
        ),
      ),
    ),
  ])
  let import_sec = @lib.ImportSec::new([
    @lib.Import::new(
      @lib.Name::from_string("env"),
      @lib.Name::from_string("f"),
      @lib.ExternType::func(@lib.TypeIdx::new(0U)),
    ),
    @lib.Import::new(
      @lib.Name::from_string("env"),
      @lib.Name::from_string("table"),
      @lib.ExternType::table(
        @lib.TableType::new(
          @lib.RefType::abs(@lib.AbsHeapType::func()),
          @lib.Limits::i32(1, None),
        ),
      ),
    ),
    @lib.Import::new(
      @lib.Name::from_string("env"),
      @lib.Name::from_string("mem"),
      @lib.ExternType::mem(@lib.MemType::new(@lib.Limits::i32(2, None))),
    ),
    @lib.Import::new(
      @lib.Name::from_string("env"),
      @lib.Name::from_string("global"),
      @lib.ExternType::global(@lib.GlobalType::new(@lib.ValType::i64(), false)),
    ),
    @lib.Import::new(
      @lib.Name::from_string("env"),
      @lib.Name::from_string("tag"),
      @lib.ExternType::tag(@lib.TagType::new(@lib.TypeIdx::new(1U))),
    ),
  ])
  let mod_ = @lib.Module::new()
    .with_type_sec(type_sec)
    .with_import_sec(import_sec)
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
  hot_module_context_from_module(mod_)
}

///|
test "hot module context resolves imported and defined boundary indices" {
  let ctx = hot_test_module_context_fixture()

  assert_eq(
    hot_module_resolve_func_type(ctx, @lib.FuncIdx::new(0U)),
    Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i64()])),
  )
  assert_eq(
    hot_module_resolve_func_type(ctx, @lib.FuncIdx::new(1U)),
    Some(@lib.FuncType::new([], [@lib.ValType::i32()])),
  )
  assert_eq(
    hot_module_resolve_global_type(ctx, @lib.GlobalIdx::new(0U)),
    Some(@lib.GlobalType::new(@lib.ValType::i64(), false)),
  )
  assert_eq(
    hot_module_resolve_mem_index_type(ctx, @lib.MemIdx::new(0U)),
    Some(@lib.ValType::i32()),
  )
  assert_eq(
    hot_module_resolve_table_index_type(ctx, @lib.TableIdx::new(0U)),
    Some(@lib.ValType::i32()),
  )
  assert_eq(
    hot_module_resolve_tag_type(ctx, @lib.TagIdx::new(0U)),
    Some(@lib.TagType::new(@lib.TypeIdx::new(1U))),
  )
}

///|
test "hot module context expands type-index block results and aggregate fields" {
  let ctx = hot_test_module_context_fixture()

  assert_eq(
    hot_module_resolve_block_results(
      ctx,
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
    ),
    Some([@lib.ValType::i32()]),
  )
  assert_eq(
    hot_module_resolve_struct_fields(ctx, @lib.TypeIdx::new(2U)),
    Some([
      @lib.FieldType::new(
        @lib.StorageType::val_type(@lib.ValType::i32()),
        @lib.Mut::const_(),
      ),
    ]),
  )
  assert_eq(
    hot_module_resolve_array_field(ctx, @lib.TypeIdx::new(3U)),
    Some(
      @lib.FieldType::new(
        @lib.StorageType::val_type(@lib.ValType::i64()),
        @lib.Mut::var_(),
      ),
    ),
  )
}

///|
test "hot type resolution can expand type-index block types through module context" {
  let ctx = hot_test_module_context_fixture()
  let func = HotFunc::new()
  let type_id = hot_type_intern_block_result(
    func,
    @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
  )

  assert_eq(
    hot_type_resolve_results(func, ctx, type_id),
    Some([@lib.ValType::i32()]),
  )
}
