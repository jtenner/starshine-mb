///|
fn remove_unused_test_type_sec() -> @lib.TypeSec {
  @lib.TypeSec::new([
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
  ])
}

///|
fn remove_unused_test_main_call_target(mod : Module) -> UInt raise Error {
  match mod.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.TFunc(_, _, body) =>
          match body.inner()[0].kind {
            @lib.TCall(@lib.FuncIdx(target), _) => target
            _ => fail("expected direct call in first function")
          }
        _ => fail("expected typed function")
      }
    None => fail("expected code section")
  }
}

///|
fn remove_unused_test_main_global_get_target(mod : Module) -> UInt raise Error {
  match mod.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.TFunc(_, _, body) =>
          match body.inner()[0].kind {
            @lib.TDrop(inner) =>
              match inner.kind {
                @lib.TGlobalGet(@lib.GlobalIdx(target)) => target
                _ => fail("expected global.get inside drop")
              }
            _ => fail("expected drop in first function")
          }
        _ => fail("expected typed function")
      }
    None => fail("expected code section")
  }
}

///|
fn remove_unused_test_run(mod : Module) -> Module {
  let (optimized, _) = run_remove_unused_module_elements(
    mod,
    PipelineGlobal::new(),
    PipelineFeatures::new(),
  )
  optimized
}

///|
fn remove_unused_test_i32_const(value : Int) -> @lib.TInstr {
  @lib.TInstr::i32_const(@lib.I32::new(value))
}

///|
fn remove_unused_test_funcref() -> @lib.RefType {
  @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::func()))
}

///|
test "remove unused module elements removes unreachable functions and rewrites indices and names" {
  let mod = Module::new()
    .with_type_sec(remove_unused_test_type_sec())
    .with_func_sec(
      @lib.FuncSec::new([
        @lib.TypeIdx::new(0U),
        @lib.TypeIdx::new(0U),
        @lib.TypeIdx::new(0U),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::t_func(
          [],
          @lib.Locals::empty(),
          @lib.TExpr::new([@lib.TInstr::call(@lib.FuncIdx::new(2U), [])]),
        ),
        @lib.Func::t_func(
          [],
          @lib.Locals::empty(),
          @lib.TExpr::new([@lib.TInstr::nop()]),
        ),
        @lib.Func::t_func(
          [],
          @lib.Locals::empty(),
          @lib.TExpr::new([@lib.TInstr::nop()]),
        ),
      ]),
    )
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("main"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
        ),
      ]),
    )
    .with_name_sec(
      @lib.NameSec::new(
        func_names=Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("main")),
            @lib.NameAssoc::new(1U, @lib.Name::from_string("dead")),
            @lib.NameAssoc::new(2U, @lib.Name::from_string("helper")),
          ]),
        ),
        local_names=Some(
          @lib.IndirectNameMap::new([
            @lib.IndirectNameAssoc::new(2U, @lib.NameMap::new([])),
          ]),
        ),
      ),
    )

  let optimized = remove_unused_test_run(mod)

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => assert_eq(funcs.length(), 2)
    None => fail("expected code section")
  }
  assert_eq(try! remove_unused_test_main_call_target(optimized), 1U)
  match optimized.name_sec {
    Some(name_sec) => {
      let { func_names, local_names, .. } = name_sec
      assert_eq(
        func_names,
        Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("main")),
            @lib.NameAssoc::new(1U, @lib.Name::from_string("helper")),
          ]),
        ),
      )
      assert_eq(
        local_names,
        Some(
          @lib.IndirectNameMap::new([
            @lib.IndirectNameAssoc::new(1U, @lib.NameMap::new([])),
          ]),
        ),
      )
    }
    None => fail("expected name section")
  }
}

///|
test "remove unused module elements removes rootless function call chains" {
  let mod = Module::new()
    .with_type_sec(remove_unused_test_type_sec())
    .with_func_sec(
      @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(0U)]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::t_func(
          [],
          @lib.Locals::empty(),
          @lib.TExpr::new([@lib.TInstr::call(@lib.FuncIdx::new(1U), [])]),
        ),
        @lib.Func::t_func(
          [],
          @lib.Locals::empty(),
          @lib.TExpr::new([@lib.TInstr::nop()]),
        ),
      ]),
    )

  let optimized = remove_unused_test_run(mod)

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 0)
    None => fail("expected func section")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => assert_eq(funcs.length(), 0)
    None => fail("expected code section")
  }
}

///|
test "remove unused module elements keeps start-reachable functions" {
  let mod = Module::new()
    .with_type_sec(remove_unused_test_type_sec())
    .with_func_sec(
      @lib.FuncSec::new([
        @lib.TypeIdx::new(0U),
        @lib.TypeIdx::new(0U),
        @lib.TypeIdx::new(0U),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::t_func(
          [],
          @lib.Locals::empty(),
          @lib.TExpr::new([@lib.TInstr::call(@lib.FuncIdx::new(2U), [])]),
        ),
        @lib.Func::t_func(
          [],
          @lib.Locals::empty(),
          @lib.TExpr::new([@lib.TInstr::nop()]),
        ),
        @lib.Func::t_func(
          [],
          @lib.Locals::empty(),
          @lib.TExpr::new([@lib.TInstr::nop()]),
        ),
      ]),
    )
    .with_start_sec(@lib.StartSec::new(@lib.FuncIdx::new(0U)))

  let optimized = remove_unused_test_run(mod)

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  assert_eq(try! remove_unused_test_main_call_target(optimized), 1U)
  match optimized.start_sec {
    Some(@lib.StartSec(@lib.FuncIdx(idx))) => assert_eq(idx, 0U)
    _ => fail("expected start section")
  }
}

///|
test "remove unused module elements keeps functions referenced by active elem segments" {
  let mod = Module::new()
    .with_type_sec(remove_unused_test_type_sec())
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            remove_unused_test_funcref(),
            @lib.Limits::i32(1U, None),
          ),
          None,
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([
        @lib.TypeIdx::new(0U),
        @lib.TypeIdx::new(0U),
        @lib.TypeIdx::new(0U),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::t_func(
          [],
          @lib.Locals::empty(),
          @lib.TExpr::new([@lib.TInstr::nop()]),
        ),
        @lib.Func::t_func(
          [],
          @lib.Locals::empty(),
          @lib.TExpr::new([@lib.TInstr::nop()]),
        ),
        @lib.Func::t_func(
          [],
          @lib.Locals::empty(),
          @lib.TExpr::new([@lib.TInstr::nop()]),
        ),
      ]),
    )
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("main"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
        ),
      ]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::active(
            @lib.TableIdx::new(0U),
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(0))]),
          ),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(2U)]),
        ),
      ]),
    )

  let optimized = remove_unused_test_run(mod)

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  match optimized.elem_sec {
    Some(@lib.ElemSec([@lib.Elem(_, @lib.FuncsElemKind([@lib.FuncIdx(idx)]))])) =>
      assert_eq(idx, 1U)
    _ => fail("expected rewritten elem segment")
  }
}

///|
test "remove unused module elements removes unused passive elem and data segments and rewrites indices and counts" {
  let mod = Module::new()
    .with_type_sec(remove_unused_test_type_sec())
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            remove_unused_test_funcref(),
            @lib.Limits::i32(1U, None),
          ),
          None,
        ),
      ]),
    )
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_func_sec(
      @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(0U)]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::t_func(
          [],
          @lib.Locals::empty(),
          @lib.TExpr::new([
            @lib.TInstr::table_init(
              @lib.ElemIdx::new(1U),
              @lib.TableIdx::new(0U),
              remove_unused_test_i32_const(0),
              remove_unused_test_i32_const(0),
              remove_unused_test_i32_const(1),
            ),
            @lib.TInstr::elem_drop(@lib.ElemIdx::new(1U)),
            @lib.TInstr::memory_init(
              @lib.DataIdx::new(1U),
              @lib.MemIdx::new(0U),
              remove_unused_test_i32_const(0),
              remove_unused_test_i32_const(0),
              remove_unused_test_i32_const(3),
            ),
            @lib.TInstr::data_drop(@lib.DataIdx::new(1U)),
          ]),
        ),
        @lib.Func::t_func(
          [],
          @lib.Locals::empty(),
          @lib.TExpr::new([@lib.TInstr::nop()]),
        ),
      ]),
    )
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("main"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
        ),
      ]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::passive(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(1U)]),
        ),
        @lib.Elem::new(
          @lib.ElemMode::passive(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
        ),
      ]),
    )
    .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32::new(2U)))
    .with_data_sec(
      @lib.DataSec::new([
        @lib.Data::new(@lib.DataMode::passive(), b"dead"),
        @lib.Data::new(@lib.DataMode::passive(), b"live"),
      ]),
    )
    .with_name_sec(
      @lib.NameSec::new(
        elem_names=Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("dead-elem")),
            @lib.NameAssoc::new(1U, @lib.Name::from_string("live-elem")),
          ]),
        ),
        data_names=Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("dead-data")),
            @lib.NameAssoc::new(1U, @lib.Name::from_string("live-data")),
          ]),
        ),
      ),
    )

  let optimized = remove_unused_test_run(mod)

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 1)
    None => fail("expected func section")
  }
  match optimized.elem_sec {
    Some(
      @lib.ElemSec(
        [@lib.Elem(@lib.Passive, @lib.FuncsElemKind([@lib.FuncIdx(idx)]))]
      )
    ) => assert_eq(idx, 0U)
    _ => fail("expected compacted elem section")
  }
  match optimized.data_sec {
    Some(@lib.DataSec([@lib.Data(@lib.Passive, bytes)])) =>
      assert_eq(bytes, b"live")
    _ => fail("expected compacted data section")
  }
  match optimized.data_cnt_sec {
    Some(@lib.DataCntSec(@lib.U32(count))) => assert_eq(count, 1U)
    _ => fail("expected rewritten data count")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.TFunc(_, _, body) => {
          let instructions = body.inner()
          match instructions[0].kind {
            @lib.TTableInit(
              @lib.ElemIdx(elem_idx),
              @lib.TableIdx(table_idx),
              _,
              _,
              _
            ) => {
              assert_eq(elem_idx, 0U)
              assert_eq(table_idx, 0U)
            }
            _ => fail("expected table.init")
          }
          match instructions[1].kind {
            @lib.TElemDrop(@lib.ElemIdx(elem_idx)) => assert_eq(elem_idx, 0U)
            _ => fail("expected elem.drop")
          }
          match instructions[2].kind {
            @lib.TMemoryInit(
              @lib.DataIdx(data_idx),
              @lib.MemIdx(mem_idx),
              _,
              _,
              _
            ) => {
              assert_eq(data_idx, 0U)
              assert_eq(mem_idx, 0U)
            }
            _ => fail("expected memory.init")
          }
          match instructions[3].kind {
            @lib.TDataDrop(@lib.DataIdx(data_idx)) => assert_eq(data_idx, 0U)
            _ => fail("expected data.drop")
          }
        }
        _ => fail("expected typed function")
      }
    None => fail("expected code section")
  }
  match optimized.name_sec {
    Some(name_sec) => {
      let { elem_names, data_names, .. } = name_sec
      assert_eq(
        elem_names,
        Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("live-elem")),
          ]),
        ),
      )
      assert_eq(
        data_names,
        Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("live-data")),
          ]),
        ),
      )
    }
    None => fail("expected name section")
  }
}

///|
test "remove unused module elements keeps active elem and data segments conservatively" {
  let mod = Module::new()
    .with_type_sec(remove_unused_test_type_sec())
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            remove_unused_test_funcref(),
            @lib.Limits::i32(1U, None),
          ),
          None,
        ),
      ]),
    )
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_func_sec(
      @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(0U)]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::t_func(
          [],
          @lib.Locals::empty(),
          @lib.TExpr::new([@lib.TInstr::nop()]),
        ),
        @lib.Func::t_func(
          [],
          @lib.Locals::empty(),
          @lib.TExpr::new([@lib.TInstr::nop()]),
        ),
      ]),
    )
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("main"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
        ),
      ]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::active(
            @lib.TableIdx::new(0U),
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(0))]),
          ),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(1U)]),
        ),
      ]),
    )
    .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32::new(1U)))
    .with_data_sec(
      @lib.DataSec::new([
        @lib.Data::new(
          @lib.DataMode::active(
            @lib.MemIdx::new(0U),
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(0))]),
          ),
          b"active",
        ),
      ]),
    )

  let optimized = remove_unused_test_run(mod)

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  match optimized.elem_sec {
    Some(@lib.ElemSec(elems)) => assert_eq(elems.length(), 1)
    None => fail("expected elem section")
  }
  match optimized.data_sec {
    Some(@lib.DataSec(datas)) => assert_eq(datas.length(), 1)
    None => fail("expected data section")
  }
  match optimized.data_cnt_sec {
    Some(@lib.DataCntSec(@lib.U32(count))) => assert_eq(count, 1U)
    _ => fail("expected data count")
  }
}

///|
test "remove unused module elements removes unused globals and rewrites global indices and names" {
  let mod = Module::new()
    .with_type_sec(remove_unused_test_type_sec())
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("seed"),
          @lib.ExternType::global(
            @lib.GlobalType::new(@lib.ValType::i32(), false),
          ),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(0U)]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::t_func(
          [],
          @lib.Locals::empty(),
          @lib.TExpr::new([
            @lib.TInstr::drop(@lib.TInstr::global_get(@lib.GlobalIdx::new(2U))),
          ]),
        ),
        @lib.Func::t_func(
          [],
          @lib.Locals::empty(),
          @lib.TExpr::new([@lib.TInstr::nop()]),
        ),
      ]),
    )
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("main"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
        ),
        @lib.Export::new(
          @lib.Name::from_string("live-global"),
          @lib.ExternIdx::global(@lib.GlobalIdx::new(2U)),
        ),
      ]),
    )
    .with_global_sec(
      @lib.GlobalSec::new([
        @lib.Global::new(
          @lib.GlobalType::new(
            @lib.ValType::ref_type(remove_unused_test_funcref()),
            false,
          ),
          @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(1U))]),
        ),
        @lib.Global::new(
          @lib.GlobalType::new(@lib.ValType::i32(), false),
          @lib.Expr::new([@lib.Instruction::global_get(@lib.GlobalIdx::new(0U))]),
        ),
      ]),
    )
    .with_name_sec(
      @lib.NameSec::new(
        global_names=Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("seed")),
            @lib.NameAssoc::new(1U, @lib.Name::from_string("dead-global")),
            @lib.NameAssoc::new(2U, @lib.Name::from_string("live-global")),
          ]),
        ),
      ),
    )

  let optimized = remove_unused_test_run(mod)

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 1)
    None => fail("expected func section")
  }
  match optimized.global_sec {
    Some(@lib.GlobalSec(globals)) => assert_eq(globals.length(), 1)
    None => fail("expected global section")
  }
  assert_eq(try! remove_unused_test_main_global_get_target(optimized), 1U)
  match optimized.export_sec {
    Some(
      @lib.ExportSec(
        [
          @lib.Export(_, @lib.FuncExternIdx(@lib.FuncIdx(func_idx))),
          @lib.Export(_, @lib.GlobalExternIdx(@lib.GlobalIdx(global_idx))),
        ]
      )
    ) => {
      assert_eq(func_idx, 0U)
      assert_eq(global_idx, 1U)
    }
    _ => fail("expected rewritten exports")
  }
  match optimized.name_sec {
    Some(name_sec) => {
      let { global_names, .. } = name_sec
      assert_eq(
        global_names,
        Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("seed")),
            @lib.NameAssoc::new(1U, @lib.Name::from_string("live-global")),
          ]),
        ),
      )
    }
    None => fail("expected name section")
  }
}

///|
test "remove unused module elements keeps globals referenced by active data offsets" {
  let mod = Module::new()
    .with_type_sec(remove_unused_test_type_sec())
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::t_func(
          [],
          @lib.Locals::empty(),
          @lib.TExpr::new([@lib.TInstr::nop()]),
        ),
      ]),
    )
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("main"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
        ),
      ]),
    )
    .with_global_sec(
      @lib.GlobalSec::new([
        @lib.Global::new(
          @lib.GlobalType::new(@lib.ValType::i32(), false),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(1))]),
        ),
        @lib.Global::new(
          @lib.GlobalType::new(@lib.ValType::i32(), false),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(0))]),
        ),
      ]),
    )
    .with_data_sec(
      @lib.DataSec::new([
        @lib.Data::new(
          @lib.DataMode::active(
            @lib.MemIdx::new(0U),
            @lib.Expr::new([
              @lib.Instruction::global_get(@lib.GlobalIdx::new(1U)),
            ]),
          ),
          b"active",
        ),
      ]),
    )

  let optimized = remove_unused_test_run(mod)

  match optimized.global_sec {
    Some(@lib.GlobalSec(globals)) => assert_eq(globals.length(), 1)
    None => fail("expected global section")
  }
  match optimized.data_sec {
    Some(
      @lib.DataSec(
        [
          @lib.Data(
            @lib.Active(
              @lib.MemIdx(mem_idx),
              @lib.Expr([@lib.GlobalGet(@lib.GlobalIdx(global_idx))])
            ),
            _
          ),
        ]
      )
    ) => {
      assert_eq(mem_idx, 0U)
      assert_eq(global_idx, 0U)
    }
    _ => fail("expected rewritten active data offset")
  }
}
