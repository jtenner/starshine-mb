///|
fn rume_test_type_sec() -> @lib.TypeSec {
  @lib.TypeSec::new([
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
  ])
}

///|
fn rume_test_table_type() -> @lib.TableType {
  @lib.TableType::new(
    @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::func())),
    @lib.Limits::i32(1U, None),
  )
}

///|
fn rume_test_mem_type() -> @lib.MemType {
  @lib.MemType::new(@lib.Limits::i32(1U, None))
}

///|
fn rume_test_rewrite_fixture() -> @lib.Module {
  @lib.Module::new()
  .with_type_sec(rume_test_type_sec())
  .with_func_sec(
    @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(0U)]),
  )
  .with_table_sec(
    @lib.TableSec::new([
      @lib.Table::new(rume_test_table_type(), None),
      @lib.Table::new(rume_test_table_type(), None),
    ]),
  )
  .with_mem_sec(@lib.MemSec::new([rume_test_mem_type(), rume_test_mem_type()]))
  .with_global_sec(
    @lib.GlobalSec::new([
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::i32(), false),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(1))]),
      ),
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::i32(), false),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(2))]),
      ),
    ]),
  )
  .with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::from_string("run"),
        @lib.ExternIdx::func(@lib.FuncIdx::new(1U)),
      ),
      @lib.Export::new(
        @lib.Name::from_string("table"),
        @lib.ExternIdx::table(@lib.TableIdx::new(1U)),
      ),
      @lib.Export::new(
        @lib.Name::from_string("mem"),
        @lib.ExternIdx::mem(@lib.MemIdx::new(1U)),
      ),
      @lib.Export::new(
        @lib.Name::from_string("global"),
        @lib.ExternIdx::global(@lib.GlobalIdx::new(1U)),
      ),
    ]),
  )
  .with_start_sec(@lib.StartSec::new(@lib.FuncIdx::new(1U)))
  .with_elem_sec(
    @lib.ElemSec::new([
      @lib.Elem::new(
        @lib.ElemMode::passive(),
        @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
      ),
      @lib.Elem::new(
        @lib.ElemMode::active(
          @lib.TableIdx::new(1U),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
        ),
        @lib.ElemKind::funcs([@lib.FuncIdx::new(1U)]),
      ),
    ]),
  )
  .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32(2U)))
  .with_data_sec(
    @lib.DataSec::new([
      @lib.Data::new(@lib.DataMode::passive(), Bytes::new(1)),
      @lib.Data::new(
        @lib.DataMode::active(
          @lib.MemIdx::new(1U),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
        ),
        Bytes::new(1),
      ),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::nop()]),
      ),
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::global_get(@lib.GlobalIdx::new(1U)),
          @lib.Instruction::drop(),
          @lib.Instruction::memory_size(@lib.MemIdx::new(1U)),
          @lib.Instruction::drop(),
          @lib.Instruction::table_size(@lib.TableIdx::new(1U)),
          @lib.Instruction::drop(),
        ]),
      ),
    ]),
  )
}

///|
fn rume_test_import_root_fixture() -> @lib.Module {
  @lib.Module::new()
  .with_type_sec(rume_test_type_sec())
  .with_import_sec(
    @lib.ImportSec::new([
      @lib.Import::new(
        @lib.Name::from_string("env"),
        @lib.Name::from_string("table"),
        @lib.ExternType::table(rume_test_table_type()),
      ),
      @lib.Import::new(
        @lib.Name::from_string("env"),
        @lib.Name::from_string("mem"),
        @lib.ExternType::mem(rume_test_mem_type()),
      ),
    ]),
  )
  .with_func_sec(
    @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(0U)]),
  )
  .with_elem_sec(
    @lib.ElemSec::new([
      @lib.Elem::new(
        @lib.ElemMode::active(
          @lib.TableIdx::new(0U),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
        ),
        @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
      ),
    ]),
  )
  .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32(1U)))
  .with_data_sec(
    @lib.DataSec::new([
      @lib.Data::new(
        @lib.DataMode::active(
          @lib.MemIdx::new(0U),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
        ),
        Bytes::new(1),
      ),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::nop()]),
      ),
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::nop()]),
      ),
    ]),
  )
}

///|
fn rume_test_memarg_rewrite_fixture() -> @lib.Module {
  @lib.Module::new()
  .with_type_sec(rume_test_type_sec())
  .with_func_sec(
    @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(0U)]),
  )
  .with_mem_sec(@lib.MemSec::new([rume_test_mem_type(), rume_test_mem_type()]))
  .with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::from_string("run"),
        @lib.ExternIdx::func(@lib.FuncIdx::new(1U)),
      ),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::nop()]),
      ),
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::i32_load(
            @lib.MemArg::new(
              @lib.U32(0U),
              Some(@lib.MemIdx::new(1U)),
              @lib.U64(0UL),
            ),
          ),
          @lib.Instruction::drop(),
        ]),
      ),
    ]),
  )
}

///|
fn rume_test_import_remap_fixture() -> @lib.Module {
  @lib.Module::new()
  .with_type_sec(rume_test_type_sec())
  .with_import_sec(
    @lib.ImportSec::new([
      @lib.Import::new(
        @lib.Name::from_string("env"),
        @lib.Name::from_string("dead_table"),
        @lib.ExternType::table(rume_test_table_type()),
      ),
      @lib.Import::new(
        @lib.Name::from_string("env"),
        @lib.Name::from_string("live_table"),
        @lib.ExternType::table(rume_test_table_type()),
      ),
      @lib.Import::new(
        @lib.Name::from_string("env"),
        @lib.Name::from_string("dead_mem"),
        @lib.ExternType::mem(rume_test_mem_type()),
      ),
      @lib.Import::new(
        @lib.Name::from_string("env"),
        @lib.Name::from_string("live_mem"),
        @lib.ExternType::mem(rume_test_mem_type()),
      ),
      @lib.Import::new(
        @lib.Name::from_string("env"),
        @lib.Name::from_string("dead_global"),
        @lib.ExternType::global(
          @lib.GlobalType::new(@lib.ValType::i32(), false),
        ),
      ),
      @lib.Import::new(
        @lib.Name::from_string("env"),
        @lib.Name::from_string("live_global"),
        @lib.ExternType::global(
          @lib.GlobalType::new(@lib.ValType::i32(), false),
        ),
      ),
      @lib.Import::new(
        @lib.Name::from_string("env"),
        @lib.Name::from_string("dead_tag"),
        @lib.ExternType::tag(@lib.TagType::new(@lib.TypeIdx::new(0U))),
      ),
      @lib.Import::new(
        @lib.Name::from_string("env"),
        @lib.Name::from_string("live_tag"),
        @lib.ExternType::tag(@lib.TagType::new(@lib.TypeIdx::new(0U))),
      ),
    ]),
  )
  .with_table_sec(
    @lib.TableSec::new([@lib.Table::new(rume_test_table_type(), None)]),
  )
  .with_mem_sec(@lib.MemSec::new([rume_test_mem_type()]))
  .with_global_sec(
    @lib.GlobalSec::new([
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::i32(), false),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(7))]),
      ),
    ]),
  )
  .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(@lib.TypeIdx::new(0U))]))
  .with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::from_string("table_import"),
        @lib.ExternIdx::table(@lib.TableIdx::new(1U)),
      ),
      @lib.Export::new(
        @lib.Name::from_string("table_defined"),
        @lib.ExternIdx::table(@lib.TableIdx::new(2U)),
      ),
      @lib.Export::new(
        @lib.Name::from_string("mem_import"),
        @lib.ExternIdx::mem(@lib.MemIdx::new(1U)),
      ),
      @lib.Export::new(
        @lib.Name::from_string("mem_defined"),
        @lib.ExternIdx::mem(@lib.MemIdx::new(2U)),
      ),
      @lib.Export::new(
        @lib.Name::from_string("global_import"),
        @lib.ExternIdx::global(@lib.GlobalIdx::new(1U)),
      ),
      @lib.Export::new(
        @lib.Name::from_string("global_defined"),
        @lib.ExternIdx::global(@lib.GlobalIdx::new(2U)),
      ),
      @lib.Export::new(
        @lib.Name::from_string("tag_import"),
        @lib.ExternIdx::tag(@lib.TagIdx::new(1U)),
      ),
      @lib.Export::new(
        @lib.Name::from_string("tag_defined"),
        @lib.ExternIdx::tag(@lib.TagIdx::new(2U)),
      ),
    ]),
  )
  .with_name_sec(
    @lib.NameSec::new(
      table_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(0U, @lib.Name::from_string("dead_table")),
          @lib.NameAssoc::new(1U, @lib.Name::from_string("live_table")),
          @lib.NameAssoc::new(2U, @lib.Name::from_string("defined_table")),
        ]),
      ),
      memory_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(0U, @lib.Name::from_string("dead_mem")),
          @lib.NameAssoc::new(1U, @lib.Name::from_string("live_mem")),
          @lib.NameAssoc::new(2U, @lib.Name::from_string("defined_mem")),
        ]),
      ),
      global_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(0U, @lib.Name::from_string("dead_global")),
          @lib.NameAssoc::new(1U, @lib.Name::from_string("live_global")),
          @lib.NameAssoc::new(2U, @lib.Name::from_string("defined_global")),
        ]),
      ),
      tag_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(0U, @lib.Name::from_string("dead_tag")),
          @lib.NameAssoc::new(1U, @lib.Name::from_string("live_tag")),
          @lib.NameAssoc::new(2U, @lib.Name::from_string("defined_tag")),
        ]),
      ),
    ),
  )
}

///|
fn rume_test_imported_func_remap_fixture() -> @lib.Module {
  let live_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let dead_import_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::f32()], [
        @lib.ValType::i32(),
      ]),
    ),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([live_type, dead_import_type]))
  .with_import_sec(
    @lib.ImportSec::new([
      @lib.Import::new(
        @lib.Name::from_string("env"),
        @lib.Name::from_string("dead_import"),
        @lib.ExternType::func(@lib.TypeIdx::new(1U)),
      ),
    ]),
  )
  .with_func_sec(
    @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(0U)]),
  )
  .with_table_sec(
    @lib.TableSec::new([@lib.Table::new(rume_test_table_type(), None)]),
  )
  .with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::from_string("main"),
        @lib.ExternIdx::func(@lib.FuncIdx::new(1U)),
      ),
      @lib.Export::new(
        @lib.Name::from_string("table0"),
        @lib.ExternIdx::table(@lib.TableIdx::new(0U)),
      ),
    ]),
  )
  .with_start_sec(@lib.StartSec::new(@lib.FuncIdx::new(1U)))
  .with_elem_sec(
    @lib.ElemSec::new([
      @lib.Elem::new(
        @lib.ElemMode::active(
          @lib.TableIdx::new(0U),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
        ),
        @lib.ElemKind::funcs([@lib.FuncIdx::new(1U)]),
      ),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::nop()]),
      ),
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::f32_const(@lib.F32::new(66.0)),
          @lib.Instruction::drop(),
          @lib.Instruction::nop(),
        ]),
      ),
    ]),
  )
  .with_name_sec(
    @lib.NameSec::new(
      func_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(0U, @lib.Name::from_string("dead_import")),
          @lib.NameAssoc::new(1U, @lib.Name::from_string("main_func")),
          @lib.NameAssoc::new(2U, @lib.Name::from_string("dead_defined")),
        ]),
      ),
    ),
  )
}

///|
fn rume_test_empty_active_data_fixture() -> @lib.Module {
  @lib.Module::new()
  .with_type_sec(rume_test_type_sec())
  .with_mem_sec(@lib.MemSec::new([rume_test_mem_type()]))
  .with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::from_string("mem"),
        @lib.ExternIdx::mem(@lib.MemIdx::new(0U)),
      ),
    ]),
  )
  .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32(1U)))
  .with_data_sec(
    @lib.DataSec::new([
      @lib.Data::new(
        @lib.DataMode::active(
          @lib.MemIdx::new(0U),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
        ),
        Bytes::new(0),
      ),
    ]),
  )
}

///|
fn rume_test_empty_active_data_import_fixture() -> @lib.Module {
  @lib.Module::new()
  .with_type_sec(rume_test_type_sec())
  .with_import_sec(
    @lib.ImportSec::new([
      @lib.Import::new(
        @lib.Name::from_string("env"),
        @lib.Name::from_string("mem"),
        @lib.ExternType::mem(rume_test_mem_type()),
      ),
    ]),
  )
  .with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::from_string("mem"),
        @lib.ExternIdx::mem(@lib.MemIdx::new(0U)),
      ),
    ]),
  )
  .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32(1U)))
  .with_data_sec(
    @lib.DataSec::new([
      @lib.Data::new(
        @lib.DataMode::active(
          @lib.MemIdx::new(0U),
          @lib.Expr::new([@lib.Instruction::i64_const(@lib.I64(130L))]),
        ),
        Bytes::new(0),
      ),
    ]),
  )
}

///|
fn rume_test_nullref_active_elem_import_fixture() -> @lib.Module {
  @lib.Module::new()
  .with_import_sec(
    @lib.ImportSec::new([
      @lib.Import::new(
        @lib.Name::from_string("env"),
        @lib.Name::from_string("table"),
        @lib.ExternType::table(
          @lib.TableType::new(
            @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::any())),
            @lib.Limits::i64(44UL, None),
          ),
        ),
      ),
    ]),
  )
  .with_elem_sec(
    @lib.ElemSec::new([
      @lib.Elem::new(
        @lib.ElemMode::active(
          @lib.TableIdx::new(0U),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
        ),
        @lib.ElemKind::typed_exprs(
          @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::any())),
          [
            @lib.Expr::new([
              @lib.Instruction::ref_null(
                @lib.HeapType::abs(@lib.AbsHeapType::none()),
              ),
            ]),
          ],
        ),
      ),
      @lib.Elem::new(
        @lib.ElemMode::active(
          @lib.TableIdx::new(0U),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
        ),
        @lib.ElemKind::typed_exprs(
          @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::any())),
          [
            @lib.Expr::new([
              @lib.Instruction::ref_null(
                @lib.HeapType::abs(@lib.AbsHeapType::none()),
              ),
            ]),
          ],
        ),
      ),
    ]),
  )
}

///|
fn rume_test_nullfuncref_active_elem_live_table_fixture() -> @lib.Module {
  @lib.Module::new()
  .with_table_sec(
    @lib.TableSec::new([
      @lib.Table::new(
        @lib.TableType::new(
          @lib.RefType::new(
            true,
            @lib.HeapType::abs(@lib.AbsHeapType::no_func()),
          ),
          @lib.Limits::i32(21U, None),
        ),
        None,
      ),
    ]),
  )
  .with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::from_string("W"),
        @lib.ExternIdx::table(@lib.TableIdx::new(0U)),
      ),
      @lib.Export::new(
        @lib.Name::from_string(""),
        @lib.ExternIdx::table(@lib.TableIdx::new(0U)),
      ),
      @lib.Export::new(
        @lib.Name::from_string("g"),
        @lib.ExternIdx::table(@lib.TableIdx::new(0U)),
      ),
    ]),
  )
  .with_elem_sec(
    @lib.ElemSec::new([
      @lib.Elem::new(
        @lib.ElemMode::active(
          @lib.TableIdx::new(0U),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
        ),
        @lib.ElemKind::typed_exprs(
          @lib.RefType::new(
            true,
            @lib.HeapType::abs(@lib.AbsHeapType::no_func()),
          ),
          [
            @lib.Expr::new([
              @lib.Instruction::ref_null(
                @lib.HeapType::abs(@lib.AbsHeapType::no_func()),
              ),
            ]),
            @lib.Expr::new([
              @lib.Instruction::ref_null(
                @lib.HeapType::abs(@lib.AbsHeapType::no_func()),
              ),
            ]),
            @lib.Expr::new([
              @lib.Instruction::ref_null(
                @lib.HeapType::abs(@lib.AbsHeapType::no_func()),
              ),
            ]),
          ],
        ),
      ),
    ]),
  )
}

///|
fn rume_test_live_access_targets(
  mod_ : @lib.Module,
) -> (UInt, UInt, UInt) raise {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs {
        [
          @lib.Func(
            _,
            @lib.Expr(
              [
                @lib.GlobalGet(@lib.GlobalIdx(global_idx)),
                @lib.Drop,
                @lib.MemorySize(@lib.MemIdx(mem_idx)),
                @lib.Drop,
                @lib.TableSize(@lib.TableIdx(table_idx)),
                @lib.Drop,
              ]
            )
          ),
        ] => (global_idx, mem_idx, table_idx)
        _ => fail("expected rewritten live access function")
      }
    None => fail("expected code section")
  }
}

///|
fn rume_test_memarg_target(mod_ : @lib.Module) -> UInt raise {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs {
        [
          @lib.Func(
            _,
            @lib.Expr(
              [
                @lib.I32Const(_),
                @lib.I32Load(@lib.MemArg(_, Some(@lib.MemIdx(mem_idx)), _)),
                @lib.Drop,
              ]
            )
          ),
        ] => mem_idx
        _ => fail("expected rewritten memarg load function")
      }
    None => fail("expected code section")
  }
}

///|
test "run_hot_pipeline applies remove-unused-module-elements and rewrites module indices" {
  let optimized = match
    run_hot_pipeline(rume_test_rewrite_fixture(), HotPipelineOptions::new(), [
      "remove-unused-module-elements",
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected remove-unused-module-elements pipeline success, got \{err}",
      )
  }

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 1)
    None => fail("expected func section")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => assert_eq(funcs.length(), 1)
    None => fail("expected code section")
  }
  match optimized.global_sec {
    Some(@lib.GlobalSec(globals)) => assert_eq(globals.length(), 1)
    None => fail("expected global section")
  }
  match optimized.table_sec {
    Some(@lib.TableSec(tables)) => assert_eq(tables.length(), 1)
    None => fail("expected table section")
  }
  match optimized.mem_sec {
    Some(@lib.MemSec(mems)) => assert_eq(mems.length(), 1)
    None => fail("expected memory section")
  }
  let (global_idx, mem_idx, table_idx) = try! rume_test_live_access_targets(
    optimized,
  )
  assert_eq(global_idx, 0U)
  assert_eq(mem_idx, 0U)
  assert_eq(table_idx, 0U)
  match optimized.export_sec {
    Some(
      @lib.ExportSec(
        [
          @lib.Export(_, @lib.FuncExternIdx(@lib.FuncIdx(func_idx))),
          @lib.Export(_, @lib.TableExternIdx(@lib.TableIdx(table_export_idx))),
          @lib.Export(_, @lib.MemExternIdx(@lib.MemIdx(mem_export_idx))),
          @lib.Export(
            _,
            @lib.GlobalExternIdx(@lib.GlobalIdx(global_export_idx))
          ),
        ]
      )
    ) => {
      assert_eq(func_idx, 0U)
      assert_eq(table_export_idx, 0U)
      assert_eq(mem_export_idx, 0U)
      assert_eq(global_export_idx, 0U)
    }
    _ => fail("expected rewritten export section")
  }
  match optimized.start_sec {
    Some(@lib.StartSec(@lib.FuncIdx(func_idx))) => assert_eq(func_idx, 0U)
    _ => fail("expected rewritten start section")
  }
  match optimized.elem_sec {
    Some(
      @lib.ElemSec(
        [
          @lib.Elem(
            @lib.Active(@lib.TableIdx(table_idx), @lib.Expr([@lib.I32Const(_)])),
            @lib.FuncsElemKind([@lib.FuncIdx(func_idx)])
          ),
        ]
      )
    ) => {
      assert_eq(table_idx, 0U)
      assert_eq(func_idx, 0U)
    }
    _ => fail("expected rewritten element section")
  }
  match optimized.data_sec {
    Some(
      @lib.DataSec(
        [
          @lib.Data(
            @lib.Active(@lib.MemIdx(mem_idx), @lib.Expr([@lib.I32Const(_)])),
            _
          ),
        ]
      )
    ) => assert_eq(mem_idx, 0U)
    _ => fail("expected rewritten data section")
  }
  assert_eq(optimized.data_cnt_sec, Some(@lib.DataCntSec::new(@lib.U32(1U))))
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected rewritten remove-unused-module-elements module to validate, got \{err}",
      )
  }
}

///|
test "remove-unused-module-elements rewrites explicit memarg memory indices" {
  let optimized = match
    run_hot_pipeline(
      rume_test_memarg_rewrite_fixture(),
      HotPipelineOptions::new(),
      ["remove-unused-module-elements"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected memarg remove-unused-module-elements success, got \{err}")
  }

  match optimized.mem_sec {
    Some(@lib.MemSec(mems)) => assert_eq(mems.length(), 1)
    None => fail("expected memory section")
  }
  let mem_idx = try! rume_test_memarg_target(optimized)
  assert_eq(mem_idx, 0U)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected memarg remove-unused-module-elements module to validate, got \{err}",
      )
  }
}

///|
test "remove-unused-module-elements keeps active segments that initialize imported parents" {
  let optimized = match
    run_hot_pipeline(
      rume_test_import_root_fixture(),
      HotPipelineOptions::new(),
      ["remove-unused-module-elements"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected imported-parent remove-unused-module-elements success, got \{err}",
      )
  }

  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => assert_eq(funcs.length(), 1)
    None => fail("expected code section")
  }
  match optimized.elem_sec {
    Some(
      @lib.ElemSec(
        [
          @lib.Elem(
            @lib.Active(@lib.TableIdx(table_idx), @lib.Expr([@lib.I32Const(_)])),
            @lib.FuncsElemKind([@lib.FuncIdx(func_idx)])
          ),
        ]
      )
    ) => {
      assert_eq(table_idx, 0U)
      assert_eq(func_idx, 0U)
    }
    _ => fail("expected kept imported-table element segment")
  }
  match optimized.data_sec {
    Some(
      @lib.DataSec(
        [
          @lib.Data(
            @lib.Active(@lib.MemIdx(mem_idx), @lib.Expr([@lib.I32Const(_)])),
            _
          ),
        ]
      )
    ) => assert_eq(mem_idx, 0U)
    _ => fail("expected kept imported-memory data segment")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected imported-parent remove-unused-module-elements module to validate, got \{err}",
      )
  }
}

///|
test "remove-unused-module-elements drops unused imported module elements and remaps survivors" {
  let optimized = match
    run_hot_pipeline(
      rume_test_import_remap_fixture(),
      HotPipelineOptions::new(),
      ["remove-unused-module-elements"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected imported-element remove-unused-module-elements success, got \{err}",
      )
  }

  match optimized.import_sec {
    Some(
      @lib.ImportSec(
        [
          @lib.Import(_, live_table, @lib.TableExternType(_)),
          @lib.Import(_, live_mem, @lib.MemExternType(_)),
          @lib.Import(_, live_global, @lib.GlobalExternType(_)),
          @lib.Import(_, live_tag, @lib.TagExternType(_)),
        ]
      )
    ) => {
      assert_eq(live_table, @lib.Name::from_string("live_table"))
      assert_eq(live_mem, @lib.Name::from_string("live_mem"))
      assert_eq(live_global, @lib.Name::from_string("live_global"))
      assert_eq(live_tag, @lib.Name::from_string("live_tag"))
    }
    _ => fail("expected only live imported table/mem/global/tag entries")
  }

  match optimized.export_sec {
    Some(
      @lib.ExportSec(
        [
          @lib.Export(_, @lib.TableExternIdx(@lib.TableIdx(table_import_idx))),
          @lib.Export(_, @lib.TableExternIdx(@lib.TableIdx(table_defined_idx))),
          @lib.Export(_, @lib.MemExternIdx(@lib.MemIdx(mem_import_idx))),
          @lib.Export(_, @lib.MemExternIdx(@lib.MemIdx(mem_defined_idx))),
          @lib.Export(
            _,
            @lib.GlobalExternIdx(@lib.GlobalIdx(global_import_idx))
          ),
          @lib.Export(
            _,
            @lib.GlobalExternIdx(@lib.GlobalIdx(global_defined_idx))
          ),
          @lib.Export(_, @lib.TagExternIdx(@lib.TagIdx(tag_import_idx))),
          @lib.Export(_, @lib.TagExternIdx(@lib.TagIdx(tag_defined_idx))),
        ]
      )
    ) => {
      assert_eq(table_import_idx, 0U)
      assert_eq(table_defined_idx, 1U)
      assert_eq(mem_import_idx, 0U)
      assert_eq(mem_defined_idx, 1U)
      assert_eq(global_import_idx, 0U)
      assert_eq(global_defined_idx, 1U)
      assert_eq(tag_import_idx, 0U)
      assert_eq(tag_defined_idx, 1U)
    }
    _ =>
      fail("expected rewritten export indices after imported-element removal")
  }

  match optimized.name_sec {
    Some(sec) => {
      let { table_names, memory_names, global_names, tag_names, .. } = sec
      match table_names {
        Some(
          @lib.NameMap(
            [@lib.NameAssoc(0U, table_live), @lib.NameAssoc(1U, table_defined)]
          )
        ) => {
          assert_eq(table_live, @lib.Name::from_string("live_table"))
          assert_eq(table_defined, @lib.Name::from_string("defined_table"))
        }
        _ => fail("expected rewritten table names")
      }
      match memory_names {
        Some(
          @lib.NameMap(
            [@lib.NameAssoc(0U, mem_live), @lib.NameAssoc(1U, mem_defined)]
          )
        ) => {
          assert_eq(mem_live, @lib.Name::from_string("live_mem"))
          assert_eq(mem_defined, @lib.Name::from_string("defined_mem"))
        }
        _ => fail("expected rewritten memory names")
      }
      match global_names {
        Some(
          @lib.NameMap(
            [
              @lib.NameAssoc(0U, global_live),
              @lib.NameAssoc(1U, global_defined),
            ]
          )
        ) => {
          assert_eq(global_live, @lib.Name::from_string("live_global"))
          assert_eq(global_defined, @lib.Name::from_string("defined_global"))
        }
        _ => fail("expected rewritten global names")
      }
      match tag_names {
        Some(
          @lib.NameMap(
            [@lib.NameAssoc(0U, tag_live), @lib.NameAssoc(1U, tag_defined)]
          )
        ) => {
          assert_eq(tag_live, @lib.Name::from_string("live_tag"))
          assert_eq(tag_defined, @lib.Name::from_string("defined_tag"))
        }
        _ => fail("expected rewritten tag names")
      }
    }
    None => fail("expected rewritten name section")
  }

  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected imported-element remove-unused-module-elements module to validate, got \{err}",
      )
  }
}

///|
test "remove-unused-module-elements drops unused imported functions and dead function types" {
  let optimized = match
    run_hot_pipeline(
      rume_test_imported_func_remap_fixture(),
      HotPipelineOptions::new(),
      ["remove-unused-module-elements"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected imported-function remove-unused-module-elements success, got \{err}",
      )
  }

  assert_eq(optimized.import_sec, None)
  match optimized.type_sec {
    Some(
      @lib.TypeSec(
        [@lib.SingleRecType(@lib.CompTypeSubType(_, @lib.FuncCompType([], [])))]
      )
    ) => ()
    _ => fail("expected dead imported-function type to be removed")
  }
  match optimized.func_sec {
    Some(@lib.FuncSec([@lib.TypeIdx(type_idx)])) => assert_eq(type_idx, 0U)
    _ => fail("expected only the live defined function to remain")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) =>
      assert_eq(body, [@lib.Instruction::nop()])
    _ => fail("expected only the live defined function body to remain")
  }
  match optimized.export_sec {
    Some(
      @lib.ExportSec(
        [
          @lib.Export(_, @lib.FuncExternIdx(@lib.FuncIdx(main_idx))),
          @lib.Export(_, @lib.TableExternIdx(@lib.TableIdx(table_idx))),
        ]
      )
    ) => {
      assert_eq(main_idx, 0U)
      assert_eq(table_idx, 0U)
    }
    _ => fail("expected rewritten exported function and table indices")
  }
  match optimized.start_sec {
    Some(@lib.StartSec(@lib.FuncIdx(start_idx))) => assert_eq(start_idx, 0U)
    _ => fail("expected rewritten start function index")
  }
  match optimized.elem_sec {
    Some(
      @lib.ElemSec(
        [
          @lib.Elem(
            @lib.Active(@lib.TableIdx(table_idx), _),
            @lib.FuncsElemKind([@lib.FuncIdx(elem_func_idx)])
          ),
        ]
      )
    ) => {
      assert_eq(table_idx, 0U)
      assert_eq(elem_func_idx, 0U)
    }
    _ => fail("expected rewritten active elem segment function index")
  }
  match optimized.name_sec {
    Some(sec) => {
      let { func_names, .. } = sec
      match func_names {
        Some(@lib.NameMap([@lib.NameAssoc(0U, func_name)])) =>
          assert_eq(func_name, @lib.Name::from_string("main_func"))
        _ =>
          fail(
            "expected imported function names to be dropped and live name remapped",
          )
      }
    }
    None => fail("expected rewritten function names")
  }

  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected imported-function remove-unused-module-elements module to validate, got \{err}",
      )
  }
}

///|
test "remove-unused-module-elements drops empty active data on live memories" {
  let optimized = match
    run_hot_pipeline(
      rume_test_empty_active_data_fixture(),
      HotPipelineOptions::new(),
      ["remove-unused-module-elements"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected empty-active-data remove-unused-module-elements success, got \{err}",
      )
  }

  assert_eq(optimized.mem_sec, Some(@lib.MemSec::new([rume_test_mem_type()])))
  match optimized.export_sec {
    Some(
      @lib.ExportSec([@lib.Export(_, @lib.MemExternIdx(@lib.MemIdx(mem_idx)))])
    ) => assert_eq(mem_idx, 0U)
    _ => fail("expected rewritten memory export")
  }
  assert_eq(optimized.data_sec, None)
  assert_eq(optimized.data_cnt_sec, Some(@lib.DataCntSec::new(@lib.U32(0U))))
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected empty-active-data remove-unused-module-elements module to validate, got \{err}",
      )
  }
}

///|
test "remove-unused-module-elements drops empty active data on imported memories" {
  let optimized = match
    run_hot_pipeline(
      rume_test_empty_active_data_import_fixture(),
      HotPipelineOptions::new(),
      ["remove-unused-module-elements"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected imported-empty-active-data remove-unused-module-elements success, got \{err}",
      )
  }

  match optimized.import_sec {
    Some(@lib.ImportSec([@lib.Import(_, _, @lib.MemExternType(_))])) => ()
    _ => fail("expected imported memory to remain live")
  }
  match optimized.export_sec {
    Some(
      @lib.ExportSec([@lib.Export(_, @lib.MemExternIdx(@lib.MemIdx(mem_idx)))])
    ) => assert_eq(mem_idx, 0U)
    _ => fail("expected imported memory export")
  }
  assert_eq(optimized.data_sec, None)
  assert_eq(optimized.data_cnt_sec, Some(@lib.DataCntSec::new(@lib.U32(0U))))
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected imported-empty-active-data remove-unused-module-elements module to validate, got \{err}",
      )
  }
}

///|
test "remove-unused-module-elements drops no-op active nullref elem segments on imported tables" {
  let optimized = match
    run_hot_pipeline(
      rume_test_nullref_active_elem_import_fixture(),
      HotPipelineOptions::new(),
      ["remove-unused-module-elements"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected imported-nullref-active-elem remove-unused-module-elements success, got \{err}",
      )
  }

  assert_eq(optimized.import_sec, None)
  assert_eq(optimized.elem_sec, None)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected imported-nullref-active-elem remove-unused-module-elements module to validate, got \{err}",
      )
  }
}

///|
test "remove-unused-module-elements keeps nullfuncref active elem segments on live defined tables" {
  let optimized = match
    run_hot_pipeline(
      rume_test_nullfuncref_active_elem_live_table_fixture(),
      HotPipelineOptions::new(),
      ["remove-unused-module-elements"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected live-table-nullfuncref remove-unused-module-elements success, got \{err}",
      )
  }

  match optimized.elem_sec {
    Some(
      @lib.ElemSec(
        [
          @lib.Elem(
            @lib.Active(@lib.TableIdx(table_idx), @lib.Expr([@lib.I32Const(_)])),
            @lib.TypedExprsElemKind(_, exprs)
          ),
        ]
      )
    ) => {
      assert_eq(table_idx, 0U)
      assert_eq(exprs.length(), 3)
    }
    _ =>
      fail("expected active nullfuncref elem segment to remain on live table")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected live-table-nullfuncref remove-unused-module-elements module to validate, got \{err}",
      )
  }
}
