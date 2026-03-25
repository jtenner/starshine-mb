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
