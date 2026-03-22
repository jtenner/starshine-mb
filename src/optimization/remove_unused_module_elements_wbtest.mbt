///|
fn remove_unused_test_type_sec() -> @lib.TypeSec {
  @lib.TypeSec::new([
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
  ])
}

///|
fn remove_unused_test_two_type_sec() -> @lib.TypeSec {
  @lib.TypeSec::new([
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
    ),
  ])
}

///|
fn remove_unused_test_struct_type_sec_with_funcref_field() -> @lib.TypeSec {
  @lib.TypeSec::new([
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::struct_([
          @lib.FieldType::new(
            @lib.StorageType::val_type(
              @lib.ValType::ref_type(remove_unused_test_funcref()),
            ),
            @lib.Mut::const_(),
          ),
        ]),
      ),
    ),
  ])
}

///|
fn remove_unused_test_array_type_sec_with_funcref_elem() -> @lib.TypeSec {
  @lib.TypeSec::new([
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::array(
          @lib.FieldType::new(
            @lib.StorageType::val_type(
              @lib.ValType::ref_type(remove_unused_test_funcref()),
            ),
            @lib.Mut::const_(),
          ),
        ),
      ),
    ),
  ])
}

///|
fn remove_unused_test_mutable_array_type_sec_with_funcref_elem() -> @lib.TypeSec {
  @lib.TypeSec::new([
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::array(
          @lib.FieldType::new(
            @lib.StorageType::val_type(
              @lib.ValType::ref_type(remove_unused_test_funcref()),
            ),
            @lib.Mut::var_(),
          ),
        ),
      ),
    ),
  ])
}

///|
fn remove_unused_test_struct_reftype() -> @lib.RefType {
  @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U)))
}

///|
fn remove_unused_test_descriptor_struct_type_sec() -> @lib.TypeSec {
  @lib.TypeSec::new([
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    @lib.RecType::group([
      @lib.SubType::comp_type(
        @lib.CompType::struct_([]),
        metadata=@lib.TypeMetadata::new(descriptor=Some(@lib.TypeIdx::new(2U))),
      ),
      @lib.SubType::comp_type(
        @lib.CompType::struct_([]),
        metadata=@lib.TypeMetadata::new(describes=Some(@lib.TypeIdx::new(1U))),
      ),
    ]),
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
fn remove_unused_test_main_table_size_target(mod : Module) -> UInt raise Error {
  match mod.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.TFunc(_, _, body) =>
          match body.inner()[0].kind {
            @lib.TDrop(inner) =>
              match inner.kind {
                @lib.TTableSize(@lib.TableIdx(target)) => target
                _ => fail("expected table.size inside drop")
              }
            _ => fail("expected drop in first function")
          }
        _ => fail("expected typed function")
      }
    None => fail("expected code section")
  }
}

///|
fn remove_unused_test_main_memory_size_target(mod : Module) -> UInt raise Error {
  match mod.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.TFunc(_, _, body) =>
          match body.inner()[1].kind {
            @lib.TDrop(inner) =>
              match inner.kind {
                @lib.TMemorySize(@lib.MemIdx(target)) => target
                _ => fail("expected memory.size inside drop")
              }
            _ => fail("expected drop in second instruction")
          }
        _ => fail("expected typed function")
      }
    None => fail("expected code section")
  }
}

///|
fn remove_unused_test_main_throw_tag_target(mod : Module) -> UInt raise Error {
  match mod.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[0] {
        @lib.TFunc(_, _, body) =>
          match body.inner()[0].kind {
            @lib.TThrow(@lib.TagIdx(target), _) => target
            _ => fail("expected throw in first instruction")
          }
        _ => fail("expected typed function")
      }
    None => fail("expected code section")
  }
}

///|
fn remove_unused_test_func_call_target(
  mod : Module,
  func_idx : Int,
) -> UInt raise Error {
  match mod.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[func_idx] {
        @lib.TFunc(_, _, body) =>
          match body.inner()[0].kind {
            @lib.TCall(@lib.FuncIdx(target), _) => target
            _ => fail("expected direct call in function body")
          }
        _ => fail("expected typed function")
      }
    None => fail("expected code section")
  }
}

///|
fn remove_unused_test_func_body_is_unreachable(
  mod : Module,
  func_idx : Int,
) -> Bool raise Error {
  match mod.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[func_idx] {
        @lib.TFunc(_, _, body) =>
          match body.inner() {
            [first] => first.kind is @lib.TUnreachable
            _ => false
          }
        _ => fail("expected typed function")
      }
    None => fail("expected code section")
  }
}

///|
fn remove_unused_test_main_ref_global_target(mod : Module) -> UInt raise Error {
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
            @lib.TCallRef(_, _, ref_) =>
              match ref_.kind {
                @lib.TGlobalGet(@lib.GlobalIdx(target)) => target
                _ => fail("expected global.get as call_ref target")
              }
            _ => fail("expected drop(global.get) or call_ref(global.get)")
          }
        _ => fail("expected typed function")
      }
    None => fail("expected code section")
  }
}

///|
fn remove_unused_test_global_ref_func_target(
  mod : Module,
  global_idx : Int,
) -> UInt raise Error {
  match mod.global_sec {
    Some(@lib.GlobalSec(globals)) =>
      match globals[global_idx] {
        @lib.Global(_, @lib.Expr([@lib.RefFunc(@lib.FuncIdx(target))])) =>
          target
        _ => fail("expected ref.func global initializer")
      }
    None => fail("expected global section")
  }
}

///|
fn remove_unused_test_run(mod : Module) -> Module {
  remove_unused_test_run_with_features(mod, PipelineFeatures::new())
}

///|
fn remove_unused_test_run_with_features(
  mod : Module,
  features : PipelineFeatures,
) -> Module {
  let (optimized, _) = run_remove_unused_module_elements(
    mod,
    PipelineGlobal::new(),
    features,
  )
  optimized
}

///|
fn remove_unused_test_run_twice(mod : Module) -> Module {
  remove_unused_test_run(remove_unused_test_run(mod))
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
test "remove unused module elements keeps live call chains in untyped function bodies" {
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
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(1U))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(2U))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::nop()]),
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

  let optimized = remove_unused_test_run(mod)

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 3)
    None => fail("expected func section")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => assert_eq(funcs.length(), 3)
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
test "remove unused module elements keeps functions referenced by active elem segments on exported tables" {
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
        @lib.Export::new(
          @lib.Name::from_string("table"),
          @lib.ExternIdx::table(@lib.TableIdx::new(0U)),
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
  match optimized.export_sec {
    Some(
      @lib.ExportSec(
        [
          @lib.Export(_, @lib.FuncExternIdx(@lib.FuncIdx(func_idx))),
          @lib.Export(_, @lib.TableExternIdx(@lib.TableIdx(table_idx))),
        ]
      )
    ) => {
      assert_eq(func_idx, 0U)
      assert_eq(table_idx, 0U)
    }
    _ => fail("expected rewritten exports")
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
test "remove unused module elements keeps active elem and data segments on exported defined targets" {
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
        @lib.Export::new(
          @lib.Name::from_string("table"),
          @lib.ExternIdx::table(@lib.TableIdx::new(0U)),
        ),
        @lib.Export::new(
          @lib.Name::from_string("memory"),
          @lib.ExternIdx::mem(@lib.MemIdx::new(0U)),
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
        @lib.Export::new(
          @lib.Name::from_string("memory"),
          @lib.ExternIdx::mem(@lib.MemIdx::new(0U)),
        ),
      ]),
    )
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
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

///|
test "remove unused module elements removes unused tables and memories and rewrites indices and names" {
  let mod = Module::new()
    .with_type_sec(remove_unused_test_type_sec())
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("itab"),
          @lib.ExternType::table(
            @lib.TableType::new(
              remove_unused_test_funcref(),
              @lib.Limits::i32(1U, None),
            ),
          ),
        ),
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("imem"),
          @lib.ExternType::mem(@lib.MemType::new(@lib.Limits::i32(1U, None))),
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
            @lib.TInstr::drop(@lib.TInstr::table_size(@lib.TableIdx::new(2U))),
            @lib.TInstr::drop(@lib.TInstr::memory_size(@lib.MemIdx::new(2U))),
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
          @lib.Name::from_string("live-table"),
          @lib.ExternIdx::table(@lib.TableIdx::new(2U)),
        ),
        @lib.Export::new(
          @lib.Name::from_string("live-mem"),
          @lib.ExternIdx::mem(@lib.MemIdx::new(2U)),
        ),
      ]),
    )
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            remove_unused_test_funcref(),
            @lib.Limits::i32(1U, None),
          ),
          Some(
            @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(1U))]),
          ),
        ),
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
      @lib.MemSec::new([
        @lib.MemType::new(@lib.Limits::i32(1U, None)),
        @lib.MemType::new(@lib.Limits::i32(1U, None)),
      ]),
    )
    .with_name_sec(
      @lib.NameSec::new(
        table_names=Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("itab")),
            @lib.NameAssoc::new(1U, @lib.Name::from_string("dead-table")),
            @lib.NameAssoc::new(2U, @lib.Name::from_string("live-table")),
          ]),
        ),
        memory_names=Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("imem")),
            @lib.NameAssoc::new(1U, @lib.Name::from_string("dead-mem")),
            @lib.NameAssoc::new(2U, @lib.Name::from_string("live-mem")),
          ]),
        ),
      ),
    )

  let optimized = remove_unused_test_run(mod)

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 1)
    None => fail("expected func section")
  }
  match optimized.table_sec {
    Some(@lib.TableSec(tables)) => assert_eq(tables.length(), 1)
    None => fail("expected table section")
  }
  match optimized.mem_sec {
    Some(@lib.MemSec(mems)) => assert_eq(mems.length(), 1)
    None => fail("expected mem section")
  }
  assert_eq(try! remove_unused_test_main_table_size_target(optimized), 1U)
  assert_eq(try! remove_unused_test_main_memory_size_target(optimized), 1U)
  match optimized.export_sec {
    Some(
      @lib.ExportSec(
        [
          @lib.Export(_, @lib.FuncExternIdx(@lib.FuncIdx(func_idx))),
          @lib.Export(_, @lib.TableExternIdx(@lib.TableIdx(table_idx))),
          @lib.Export(_, @lib.MemExternIdx(@lib.MemIdx(mem_idx))),
        ]
      )
    ) => {
      assert_eq(func_idx, 0U)
      assert_eq(table_idx, 1U)
      assert_eq(mem_idx, 1U)
    }
    _ => fail("expected rewritten exports")
  }
  match optimized.name_sec {
    Some(name_sec) => {
      let { table_names, memory_names, .. } = name_sec
      assert_eq(
        table_names,
        Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("itab")),
            @lib.NameAssoc::new(1U, @lib.Name::from_string("live-table")),
          ]),
        ),
      )
      assert_eq(
        memory_names,
        Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("imem")),
            @lib.NameAssoc::new(1U, @lib.Name::from_string("live-mem")),
          ]),
        ),
      )
    }
    None => fail("expected name section")
  }
}

///|
test "remove unused module elements removes dead active elem and data segments on dead defined targets" {
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
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            remove_unused_test_funcref(),
            @lib.Limits::i32(1U, None),
          ),
          None,
        ),
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
      @lib.MemSec::new([
        @lib.MemType::new(@lib.Limits::i32(1U, None)),
        @lib.MemType::new(@lib.Limits::i32(1U, None)),
      ]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::active(
            @lib.TableIdx::new(1U),
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(0))]),
          ),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(1U)]),
        ),
      ]),
    )
    .with_data_sec(
      @lib.DataSec::new([
        @lib.Data::new(
          @lib.DataMode::active(
            @lib.MemIdx::new(1U),
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(0))]),
          ),
          b"active",
        ),
      ]),
    )

  let optimized = remove_unused_test_run(mod)

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 1)
    None => fail("expected func section")
  }
  match optimized.table_sec {
    Some(@lib.TableSec(tables)) => assert_eq(tables.length(), 0)
    None => fail("expected table section")
  }
  match optimized.mem_sec {
    Some(@lib.MemSec(mems)) => assert_eq(mems.length(), 0)
    None => fail("expected mem section")
  }
  match optimized.elem_sec {
    Some(@lib.ElemSec(elems)) => assert_eq(elems.length(), 0)
    None => fail("expected elem section")
  }
  match optimized.data_sec {
    Some(@lib.DataSec(datas)) => assert_eq(datas.length(), 0)
    None => fail("expected data section")
  }
}

///|
test "remove unused module elements keeps active elem and data segments on imported targets" {
  let mod = Module::new()
    .with_type_sec(remove_unused_test_type_sec())
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("itab"),
          @lib.ExternType::table(
            @lib.TableType::new(
              remove_unused_test_funcref(),
              @lib.Limits::i32(1U, None),
            ),
          ),
        ),
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("imem"),
          @lib.ExternType::mem(@lib.MemType::new(@lib.Limits::i32(1U, None))),
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
    .with_data_sec(
      @lib.DataSec::new([
        @lib.Data::new(
          @lib.DataMode::active(
            @lib.MemIdx::new(0U),
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(0))]),
          ),
          b"visible",
        ),
      ]),
    )

  let optimized = remove_unused_test_run(mod)

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  match optimized.elem_sec {
    Some(@lib.ElemSec([@lib.Elem(@lib.Active(@lib.TableIdx(table_idx), _), _)])) =>
      assert_eq(table_idx, 0U)
    _ => fail("expected active elem section")
  }
  match optimized.data_sec {
    Some(@lib.DataSec([@lib.Data(@lib.Active(@lib.MemIdx(mem_idx), _), bytes)])) => {
      assert_eq(mem_idx, 0U)
      assert_eq(bytes, b"visible")
    }
    _ => fail("expected active data section")
  }
}

///|
test "remove unused module elements keeps active elem segments for indirectly called tables" {
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
          @lib.TExpr::new([
            @lib.TInstr::call_indirect(
              @lib.TypeIdx::new(0U),
              @lib.TableIdx::new(0U),
              [],
              remove_unused_test_i32_const(0),
            ),
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

  let optimized = remove_unused_test_run(mod)

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  match optimized.table_sec {
    Some(@lib.TableSec(tables)) => assert_eq(tables.length(), 1)
    None => fail("expected table section")
  }
  match optimized.elem_sec {
    Some(@lib.ElemSec([@lib.Elem(@lib.Active(@lib.TableIdx(table_idx), _), _)])) =>
      assert_eq(table_idx, 0U)
    _ => fail("expected active elem section")
  }
}

///|
test "remove unused module elements does not root dead struct.new global initializers" {
  let mod = Module::new()
    .with_type_sec(remove_unused_test_struct_type_sec_with_funcref_field())
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
    .with_global_sec(
      @lib.GlobalSec::new([
        @lib.Global::new(
          @lib.GlobalType::new(
            @lib.ValType::ref_type(remove_unused_test_struct_reftype()),
            false,
          ),
          @lib.Expr::new([
            @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
            @lib.Instruction::struct_new(@lib.TypeIdx::new(1U)),
          ]),
        ),
      ]),
    )

  let optimized = remove_unused_test_run(mod)

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 1)
    None => fail("expected func section")
  }
  match optimized.global_sec {
    Some(@lib.GlobalSec(globals)) => assert_eq(globals.length(), 0)
    None => fail("expected global section")
  }
}

///|
test "remove unused module elements does not root dead struct.new elem expressions" {
  let mod = Module::new()
    .with_type_sec(remove_unused_test_struct_type_sec_with_funcref_field())
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
          @lib.ElemMode::passive(),
          @lib.ElemKind::typed_exprs(remove_unused_test_struct_reftype(), [
            @lib.Expr::new([
              @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
              @lib.Instruction::struct_new(@lib.TypeIdx::new(1U)),
            ]),
          ]),
        ),
      ]),
    )

  let optimized = remove_unused_test_run(mod)

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 1)
    None => fail("expected func section")
  }
  match optimized.elem_sec {
    Some(@lib.ElemSec(elems)) => assert_eq(elems.length(), 0)
    None => fail("expected elem section")
  }
}

///|
test "remove unused module elements roots dead nullable descriptor global initializers" {
  let mod = Module::new()
    .with_type_sec(remove_unused_test_descriptor_struct_type_sec())
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("desc"),
          @lib.ExternType::global(
            @lib.GlobalType::new(
              @lib.ValType::ref_type(
                @lib.RefType::new(
                  true,
                  @lib.HeapType::new(@lib.TypeIdx::new(2U)),
                  exact=true,
                ),
              ),
              false,
            ),
          ),
        ),
      ]),
    )
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
          @lib.GlobalType::new(
            @lib.ValType::ref_type(
              @lib.RefType::new(
                false,
                @lib.HeapType::new(@lib.TypeIdx::new(1U)),
                exact=true,
              ),
            ),
            false,
          ),
          @lib.Expr::new([
            @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
            @lib.Instruction::struct_new_default_desc(@lib.TypeIdx::new(1U)),
          ]),
        ),
      ]),
    )

  let optimized = remove_unused_test_run(mod)

  match optimized.global_sec {
    Some(@lib.GlobalSec(globals)) => assert_eq(globals.length(), 1)
    None => fail("expected global section")
  }
}

///|
test "remove unused module elements drops dead non-null descriptor global initializers" {
  let mod = Module::new()
    .with_type_sec(remove_unused_test_descriptor_struct_type_sec())
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("desc"),
          @lib.ExternType::global(
            @lib.GlobalType::new(
              @lib.ValType::ref_type(
                @lib.RefType::new(
                  false,
                  @lib.HeapType::new(@lib.TypeIdx::new(2U)),
                  exact=true,
                ),
              ),
              false,
            ),
          ),
        ),
      ]),
    )
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
          @lib.GlobalType::new(
            @lib.ValType::ref_type(
              @lib.RefType::new(
                false,
                @lib.HeapType::new(@lib.TypeIdx::new(1U)),
                exact=true,
              ),
            ),
            false,
          ),
          @lib.Expr::new([
            @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
            @lib.Instruction::struct_new_default_desc(@lib.TypeIdx::new(1U)),
          ]),
        ),
      ]),
    )

  let optimized = remove_unused_test_run(mod)

  match optimized.global_sec {
    Some(@lib.GlobalSec(globals)) => assert_eq(globals.length(), 0)
    None => fail("expected global section")
  }
}

///|
test "remove unused module elements respects traps_never_happen for nullable descriptor globals" {
  let mod = Module::new()
    .with_type_sec(remove_unused_test_descriptor_struct_type_sec())
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("desc"),
          @lib.ExternType::global(
            @lib.GlobalType::new(
              @lib.ValType::ref_type(
                @lib.RefType::new(
                  true,
                  @lib.HeapType::new(@lib.TypeIdx::new(2U)),
                  exact=true,
                ),
              ),
              false,
            ),
          ),
        ),
      ]),
    )
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
          @lib.GlobalType::new(
            @lib.ValType::ref_type(
              @lib.RefType::new(
                false,
                @lib.HeapType::new(@lib.TypeIdx::new(1U)),
                exact=true,
              ),
            ),
            false,
          ),
          @lib.Expr::new([
            @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
            @lib.Instruction::struct_new_default_desc(@lib.TypeIdx::new(1U)),
          ]),
        ),
      ]),
    )

  let optimized = remove_unused_test_run_with_features(
    mod,
    PipelineFeatures::new(traps_never_happen=true),
  )

  match optimized.global_sec {
    Some(@lib.GlobalSec(globals)) => assert_eq(globals.length(), 0)
    None => fail("expected global section")
  }
}

///|
test "remove unused module elements keeps only matching active elem segments for non-mutated indirectly called tables" {
  let mod = Module::new()
    .with_type_sec(remove_unused_test_two_type_sec())
    .with_func_sec(
      @lib.FuncSec::new([
        @lib.TypeIdx::new(0U),
        @lib.TypeIdx::new(0U),
        @lib.TypeIdx::new(1U),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::t_func(
          [],
          @lib.Locals::empty(),
          @lib.TExpr::new([
            @lib.TInstr::call_indirect(
              @lib.TypeIdx::new(0U),
              @lib.TableIdx::new(0U),
              [],
              remove_unused_test_i32_const(0),
            ),
          ]),
        ),
        @lib.Func::t_func(
          [],
          @lib.Locals::empty(),
          @lib.TExpr::new([@lib.TInstr::nop()]),
        ),
        @lib.Func::t_func(
          [@lib.ValType::i32()],
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
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            remove_unused_test_funcref(),
            @lib.Limits::i32(2U, None),
          ),
          None,
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
        @lib.Elem::new(
          @lib.ElemMode::active(
            @lib.TableIdx::new(0U),
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(1))]),
          ),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(2U)]),
        ),
      ]),
    )

  let optimized = remove_unused_test_run(mod)

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => {
      assert_eq(type_idxs.length(), 2)
      assert_eq(type_idxs[0], @lib.TypeIdx::new(0U))
      assert_eq(type_idxs[1], @lib.TypeIdx::new(0U))
    }
    None => fail("expected func section")
  }
  match optimized.elem_sec {
    Some(
      @lib.ElemSec(
        [
          @lib.Elem(
            @lib.Active(
              @lib.TableIdx(table_idx),
              @lib.Expr([@lib.I32Const(@lib.I32(offset))])
            ),
            @lib.FuncsElemKind([@lib.FuncIdx(func_idx)])
          ),
        ]
      )
    ) => {
      assert_eq(table_idx, 0U)
      assert_eq(offset, 0)
      assert_eq(func_idx, 1U)
    }
    _ => fail("expected only the matching active elem segment")
  }
}

///|
test "remove unused module elements does not let mutated indirectly called tables pin nonmatching active elem contents" {
  let mod = Module::new()
    .with_type_sec(remove_unused_test_two_type_sec())
    .with_func_sec(
      @lib.FuncSec::new([
        @lib.TypeIdx::new(0U),
        @lib.TypeIdx::new(0U),
        @lib.TypeIdx::new(1U),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::t_func(
          [],
          @lib.Locals::empty(),
          @lib.TExpr::new([
            @lib.TInstr::call_indirect(
              @lib.TypeIdx::new(0U),
              @lib.TableIdx::new(0U),
              [],
              remove_unused_test_i32_const(0),
            ),
            @lib.TInstr::table_set(
              @lib.TableIdx::new(0U),
              remove_unused_test_i32_const(0),
              @lib.TInstr::ref_null(
                @lib.HeapType::abs(@lib.AbsHeapType::func()),
              ),
            ),
          ]),
        ),
        @lib.Func::t_func(
          [],
          @lib.Locals::empty(),
          @lib.TExpr::new([@lib.TInstr::nop()]),
        ),
        @lib.Func::t_func(
          [@lib.ValType::i32()],
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
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            remove_unused_test_funcref(),
            @lib.Limits::i32(2U, None),
          ),
          None,
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
        @lib.Elem::new(
          @lib.ElemMode::active(
            @lib.TableIdx::new(0U),
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(1))]),
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
    Some(
      @lib.ElemSec(
        [
          @lib.Elem(
            @lib.Active(
              @lib.TableIdx(table_idx),
              @lib.Expr([@lib.I32Const(@lib.I32(offset))])
            ),
            @lib.FuncsElemKind([@lib.FuncIdx(func_idx)])
          ),
        ]
      )
    ) => {
      assert_eq(table_idx, 0U)
      assert_eq(offset, 0)
      assert_eq(func_idx, 1U)
    }
    _ => fail("expected only the matching active elem segment")
  }
}

///|
test "remove unused module elements promotes matching closed-world ref.func writes for mutated indirectly called tables" {
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
          @lib.TExpr::new([
            @lib.TInstr::table_set(
              @lib.TableIdx::new(0U),
              remove_unused_test_i32_const(0),
              @lib.TInstr::global_get(@lib.GlobalIdx::new(0U)),
            ),
            @lib.TInstr::call_indirect(
              @lib.TypeIdx::new(0U),
              @lib.TableIdx::new(0U),
              [],
              remove_unused_test_i32_const(0),
            ),
          ]),
        ),
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
          @lib.GlobalType::new(
            @lib.ValType::ref_type(remove_unused_test_funcref()),
            false,
          ),
          @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(1U))]),
        ),
      ]),
    )
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

  let optimized = remove_unused_test_run_with_features(
    mod,
    PipelineFeatures::new(closed_world=true),
  )

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 3)
    None => fail("expected func section")
  }
  assert_eq(try! remove_unused_test_global_ref_func_target(optimized, 0), 1U)
  assert_false(try! remove_unused_test_func_body_is_unreachable(optimized, 1))
  assert_eq(try! remove_unused_test_func_call_target(optimized, 1), 2U)
}

///|
test "remove unused module elements keeps mutated indirect-table callable fallback signature-filtered" {
  let mod = Module::new()
    .with_type_sec(remove_unused_test_two_type_sec())
    .with_func_sec(
      @lib.FuncSec::new([
        @lib.TypeIdx::new(0U),
        @lib.TypeIdx::new(1U),
        @lib.TypeIdx::new(0U),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::t_func(
          [],
          @lib.Locals::empty(),
          @lib.TExpr::new([
            @lib.TInstr::call_indirect(
              @lib.TypeIdx::new(0U),
              @lib.TableIdx::new(0U),
              [],
              remove_unused_test_i32_const(0),
            ),
            @lib.TInstr::table_set(
              @lib.TableIdx::new(0U),
              remove_unused_test_i32_const(0),
              @lib.TInstr::global_get(@lib.GlobalIdx::new(0U)),
            ),
          ]),
        ),
        @lib.Func::t_func(
          [@lib.ValType::i32()],
          @lib.Locals::empty(),
          @lib.TExpr::new([@lib.TInstr::call(@lib.FuncIdx::new(2U), [])]),
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
    .with_global_sec(
      @lib.GlobalSec::new([
        @lib.Global::new(
          @lib.GlobalType::new(
            @lib.ValType::ref_type(remove_unused_test_funcref()),
            false,
          ),
          @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(1U))]),
        ),
      ]),
    )
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

  let optimized = remove_unused_test_run_with_features(
    mod,
    PipelineFeatures::new(closed_world=true),
  )

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  assert_eq(try! remove_unused_test_global_ref_func_target(optimized, 0), 1U)
  assert_true(try! remove_unused_test_func_body_is_unreachable(optimized, 1))
}

///|
test "remove unused module elements does not let table.size root active elem contents" {
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
          @lib.TExpr::new([
            @lib.TInstr::drop(@lib.TInstr::table_size(@lib.TableIdx::new(0U))),
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

  let optimized = remove_unused_test_run(mod)

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 1)
    None => fail("expected func section")
  }
  match optimized.table_sec {
    Some(@lib.TableSec(tables)) => assert_eq(tables.length(), 1)
    None => fail("expected table section")
  }
  match optimized.elem_sec {
    Some(@lib.ElemSec(elems)) => assert_eq(elems.length(), 0)
    None => fail("expected elem section")
  }
}

///|
test "remove unused module elements does not let table.set root overwritten active elem contents" {
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
          @lib.TExpr::new([
            @lib.TInstr::table_set(
              @lib.TableIdx::new(0U),
              remove_unused_test_i32_const(0),
              @lib.TInstr::ref_null(
                @lib.HeapType::abs(@lib.AbsHeapType::func()),
              ),
            ),
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

  let optimized = remove_unused_test_run(mod)

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 1)
    None => fail("expected func section")
  }
  match optimized.table_sec {
    Some(@lib.TableSec(tables)) => assert_eq(tables.length(), 1)
    None => fail("expected table section")
  }
  match optimized.elem_sec {
    Some(@lib.ElemSec(elems)) => assert_eq(elems.length(), 0)
    None => fail("expected elem section")
  }
}

///|
test "remove unused module elements keeps source active elem contents for table.copy" {
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
          @lib.TExpr::new([
            @lib.TInstr::table_copy(
              @lib.TableIdx::new(1U),
              @lib.TableIdx::new(0U),
              remove_unused_test_i32_const(0),
              remove_unused_test_i32_const(0),
              remove_unused_test_i32_const(1),
            ),
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
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            remove_unused_test_funcref(),
            @lib.Limits::i32(1U, None),
          ),
          None,
        ),
        @lib.Table::new(
          @lib.TableType::new(
            remove_unused_test_funcref(),
            @lib.Limits::i32(1U, None),
          ),
          None,
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

  let optimized = remove_unused_test_run(mod)

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  match optimized.table_sec {
    Some(@lib.TableSec(tables)) => assert_eq(tables.length(), 2)
    None => fail("expected table section")
  }
  match optimized.elem_sec {
    Some(@lib.ElemSec([@lib.Elem(@lib.Active(@lib.TableIdx(table_idx), _), _)])) =>
      assert_eq(table_idx, 0U)
    _ => fail("expected source active elem section")
  }
}

///|
test "remove unused module elements does not let table.size root table initializer contents" {
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
          @lib.TExpr::new([
            @lib.TInstr::drop(@lib.TInstr::table_size(@lib.TableIdx::new(0U))),
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
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            remove_unused_test_funcref(),
            @lib.Limits::i32(1U, None),
          ),
          Some(
            @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(1U))]),
          ),
        ),
      ]),
    )

  let optimized = remove_unused_test_run(mod)

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 1)
    None => fail("expected func section")
  }
  match optimized.table_sec {
    Some(@lib.TableSec(tables)) => assert_eq(tables.length(), 1)
    None => fail("expected table section")
  }
}

///|
test "remove unused module elements does not let table.set root table initializer contents" {
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
          @lib.TExpr::new([
            @lib.TInstr::table_set(
              @lib.TableIdx::new(0U),
              remove_unused_test_i32_const(0),
              @lib.TInstr::ref_null(
                @lib.HeapType::abs(@lib.AbsHeapType::func()),
              ),
            ),
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
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            remove_unused_test_funcref(),
            @lib.Limits::i32(1U, None),
          ),
          Some(
            @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(1U))]),
          ),
        ),
      ]),
    )

  let optimized = remove_unused_test_run(mod)

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 1)
    None => fail("expected func section")
  }
  match optimized.table_sec {
    Some(@lib.TableSec(tables)) => assert_eq(tables.length(), 1)
    None => fail("expected table section")
  }
}

///|
test "remove unused module elements keeps table initializer contents for indirectly called tables" {
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
          @lib.TExpr::new([
            @lib.TInstr::call_indirect(
              @lib.TypeIdx::new(0U),
              @lib.TableIdx::new(0U),
              [],
              remove_unused_test_i32_const(0),
            ),
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
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            remove_unused_test_funcref(),
            @lib.Limits::i32(1U, None),
          ),
          Some(
            @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(1U))]),
          ),
        ),
      ]),
    )

  let optimized = remove_unused_test_run(mod)

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  match optimized.table_sec {
    Some(@lib.TableSec(tables)) => assert_eq(tables.length(), 1)
    None => fail("expected table section")
  }
}

///|
test "remove unused module elements keeps table initializer contents for table.copy sources" {
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
          @lib.TExpr::new([
            @lib.TInstr::table_copy(
              @lib.TableIdx::new(1U),
              @lib.TableIdx::new(0U),
              remove_unused_test_i32_const(0),
              remove_unused_test_i32_const(0),
              remove_unused_test_i32_const(1),
            ),
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
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            remove_unused_test_funcref(),
            @lib.Limits::i32(1U, None),
          ),
          Some(
            @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(1U))]),
          ),
        ),
        @lib.Table::new(
          @lib.TableType::new(
            remove_unused_test_funcref(),
            @lib.Limits::i32(1U, None),
          ),
          None,
        ),
      ]),
    )

  let optimized = remove_unused_test_run(mod)

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  match optimized.table_sec {
    Some(@lib.TableSec(tables)) => assert_eq(tables.length(), 2)
    None => fail("expected table section")
  }
}

///|
test "remove unused module elements keeps active data segments with unknown offsets because instantiation may trap" {
  let mod = Module::new()
    .with_type_sec(remove_unused_test_type_sec())
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("offset"),
          @lib.ExternType::global(
            @lib.GlobalType::new(@lib.ValType::i32(), false),
          ),
        ),
      ]),
    )
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
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_data_sec(
      @lib.DataSec::new([
        @lib.Data::new(
          @lib.DataMode::active(
            @lib.MemIdx::new(0U),
            @lib.Expr::new([
              @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
            ]),
          ),
          b"trap?",
        ),
      ]),
    )

  let optimized = remove_unused_test_run(mod)

  match optimized.mem_sec {
    Some(@lib.MemSec(mems)) => assert_eq(mems.length(), 1)
    None => fail("expected mem section")
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
            bytes
          ),
        ]
      )
    ) => {
      assert_eq(mem_idx, 0U)
      assert_eq(global_idx, 0U)
      assert_eq(bytes, b"trap?")
    }
    _ => fail("expected active data section")
  }
}

///|
test "remove unused module elements keeps active elem segments with out of bounds writes because instantiation may trap" {
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
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::active(
            @lib.TableIdx::new(0U),
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(1))]),
          ),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(1U)]),
        ),
      ]),
    )

  let optimized = remove_unused_test_run(mod)

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  match optimized.table_sec {
    Some(@lib.TableSec(tables)) => assert_eq(tables.length(), 1)
    None => fail("expected table section")
  }
  match optimized.elem_sec {
    Some(@lib.ElemSec([@lib.Elem(@lib.Active(@lib.TableIdx(table_idx), _), _)])) =>
      assert_eq(table_idx, 0U)
    _ => fail("expected active elem section")
  }
}

///|
test "remove unused module elements drops maybe-trapping active segments when traps never happen" {
  let mod = Module::new()
    .with_type_sec(remove_unused_test_type_sec())
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("offset"),
          @lib.ExternType::global(
            @lib.GlobalType::new(@lib.ValType::i32(), false),
          ),
        ),
      ]),
    )
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
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_data_sec(
      @lib.DataSec::new([
        @lib.Data::new(
          @lib.DataMode::active(
            @lib.MemIdx::new(0U),
            @lib.Expr::new([
              @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
            ]),
          ),
          b"trap?",
        ),
      ]),
    )

  let optimized = remove_unused_test_run_with_features(
    mod,
    PipelineFeatures::new(traps_never_happen=true),
  )

  match optimized.mem_sec {
    Some(@lib.MemSec(mems)) => assert_eq(mems.length(), 0)
    None => fail("expected mem section")
  }
  match optimized.data_sec {
    Some(@lib.DataSec(datas)) => assert_eq(datas.length(), 0)
    None => fail("expected data section")
  }
}

///|
test "remove unused module elements does not let dead table initializers root helper functions" {
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
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            remove_unused_test_funcref(),
            @lib.Limits::i32(1U, None),
          ),
          Some(
            @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(2U))]),
          ),
        ),
      ]),
    )

  let optimized = remove_unused_test_run(mod)

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 1)
    None => fail("expected func section")
  }
  match optimized.table_sec {
    Some(@lib.TableSec(tables)) => assert_eq(tables.length(), 0)
    None => fail("expected table section")
  }
}

///|
test "remove unused module elements shells closed-world bare ref.func targets" {
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
          @lib.TExpr::new([
            @lib.TInstr::drop(@lib.TInstr::global_get(@lib.GlobalIdx::new(0U))),
          ]),
        ),
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
          @lib.GlobalType::new(
            @lib.ValType::ref_type(remove_unused_test_funcref()),
            false,
          ),
          @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(1U))]),
        ),
      ]),
    )

  let optimized = remove_unused_test_run_with_features(
    mod,
    PipelineFeatures::new(closed_world=true),
  )

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  match optimized.global_sec {
    Some(@lib.GlobalSec(globals)) => assert_eq(globals.length(), 1)
    None => fail("expected global section")
  }
  assert_eq(try! remove_unused_test_main_ref_global_target(optimized), 0U)
  assert_eq(try! remove_unused_test_global_ref_func_target(optimized, 0), 1U)
  assert_true(try! remove_unused_test_func_body_is_unreachable(optimized, 1))
}

///|
test "remove unused module elements promotes closed-world ref.func targets used by call_ref" {
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
          @lib.TExpr::new([
            @lib.TInstr::call_ref(
              @lib.TypeIdx::new(0U),
              [],
              @lib.TInstr::global_get(@lib.GlobalIdx::new(0U)),
            ),
          ]),
        ),
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
          @lib.GlobalType::new(
            @lib.ValType::ref_type(remove_unused_test_funcref()),
            false,
          ),
          @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(1U))]),
        ),
      ]),
    )

  let optimized = remove_unused_test_run_with_features(
    mod,
    PipelineFeatures::new(closed_world=true),
  )

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 3)
    None => fail("expected func section")
  }
  assert_eq(try! remove_unused_test_main_ref_global_target(optimized), 0U)
  assert_eq(try! remove_unused_test_global_ref_func_target(optimized, 0), 1U)
  assert_false(try! remove_unused_test_func_body_is_unreachable(optimized, 1))
  assert_eq(try! remove_unused_test_func_call_target(optimized, 1), 2U)
}

///|
test "remove unused module elements does not promote unread struct field funcref payloads from unrelated call_ref" {
  let mod = Module::new()
    .with_type_sec(remove_unused_test_struct_type_sec_with_funcref_field())
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
          @lib.TExpr::new([
            @lib.TInstr::drop(
              @lib.TInstr::struct_new(@lib.TypeIdx::new(1U), [
                @lib.TInstr::global_get(@lib.GlobalIdx::new(0U)),
              ]),
            ),
            @lib.TInstr::call_ref(
              @lib.TypeIdx::new(0U),
              [],
              @lib.TInstr::global_get(@lib.GlobalIdx::new(1U)),
            ),
          ]),
        ),
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
          @lib.GlobalType::new(
            @lib.ValType::ref_type(remove_unused_test_funcref()),
            false,
          ),
          @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(1U))]),
        ),
        @lib.Global::new(
          @lib.GlobalType::new(
            @lib.ValType::ref_type(remove_unused_test_funcref()),
            false,
          ),
          @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(2U))]),
        ),
      ]),
    )

  let optimized = remove_unused_test_run_with_features(
    mod,
    PipelineFeatures::new(has_gc=true, closed_world=true),
  )

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 3)
    None => fail("expected func section")
  }
  match optimized.global_sec {
    Some(@lib.GlobalSec(globals)) => assert_eq(globals.length(), 2)
    None => fail("expected global section")
  }
  assert_eq(try! remove_unused_test_global_ref_func_target(optimized, 0), 1U)
  assert_eq(try! remove_unused_test_global_ref_func_target(optimized, 1), 2U)
  assert_true(try! remove_unused_test_func_body_is_unreachable(optimized, 1))
  assert_false(try! remove_unused_test_func_body_is_unreachable(optimized, 2))
}

///|
test "remove unused module elements promotes struct field funcref payloads once read" {
  let mod = Module::new()
    .with_type_sec(remove_unused_test_struct_type_sec_with_funcref_field())
    .with_func_sec(
      @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(0U)]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::t_func(
          [],
          @lib.Locals::empty(),
          @lib.TExpr::new([
            @lib.TInstr::call_ref(
              @lib.TypeIdx::new(0U),
              [],
              @lib.TInstr::struct_get(
                @lib.TypeIdx::new(1U),
                0,
                @lib.TInstr::struct_new(@lib.TypeIdx::new(1U), [
                  @lib.TInstr::global_get(@lib.GlobalIdx::new(0U)),
                ]),
              ),
            ),
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
    .with_global_sec(
      @lib.GlobalSec::new([
        @lib.Global::new(
          @lib.GlobalType::new(
            @lib.ValType::ref_type(remove_unused_test_funcref()),
            false,
          ),
          @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(1U))]),
        ),
      ]),
    )

  let optimized = remove_unused_test_run_with_features(
    mod,
    PipelineFeatures::new(has_gc=true, closed_world=true),
  )

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  assert_false(try! remove_unused_test_func_body_is_unreachable(optimized, 1))
}

///|
test "remove unused module elements does not promote unread array.new_fixed funcref payloads from unrelated call_ref" {
  let mod = Module::new()
    .with_type_sec(remove_unused_test_array_type_sec_with_funcref_elem())
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
          @lib.TExpr::new([
            @lib.TInstr::drop(
              @lib.TInstr::array_new_fixed(@lib.TypeIdx::new(1U), [
                @lib.TInstr::global_get(@lib.GlobalIdx::new(0U)),
              ]),
            ),
            @lib.TInstr::call_ref(
              @lib.TypeIdx::new(0U),
              [],
              @lib.TInstr::global_get(@lib.GlobalIdx::new(1U)),
            ),
          ]),
        ),
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
          @lib.GlobalType::new(
            @lib.ValType::ref_type(remove_unused_test_funcref()),
            false,
          ),
          @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(1U))]),
        ),
        @lib.Global::new(
          @lib.GlobalType::new(
            @lib.ValType::ref_type(remove_unused_test_funcref()),
            false,
          ),
          @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(2U))]),
        ),
      ]),
    )

  let optimized = remove_unused_test_run_with_features(
    mod,
    PipelineFeatures::new(has_gc=true, closed_world=true),
  )

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 3)
    None => fail("expected func section")
  }
  assert_eq(try! remove_unused_test_global_ref_func_target(optimized, 0), 1U)
  assert_eq(try! remove_unused_test_global_ref_func_target(optimized, 1), 2U)
  assert_true(try! remove_unused_test_func_body_is_unreachable(optimized, 1))
  assert_false(try! remove_unused_test_func_body_is_unreachable(optimized, 2))
}

///|
test "remove unused module elements promotes array.new_fixed funcref payloads once read" {
  let mod = Module::new()
    .with_type_sec(remove_unused_test_array_type_sec_with_funcref_elem())
    .with_func_sec(
      @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(0U)]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::t_func(
          [],
          @lib.Locals::empty(),
          @lib.TExpr::new([
            @lib.TInstr::call_ref(
              @lib.TypeIdx::new(0U),
              [],
              @lib.TInstr::array_get(
                @lib.TypeIdx::new(1U),
                @lib.TInstr::array_new_fixed(@lib.TypeIdx::new(1U), [
                  @lib.TInstr::global_get(@lib.GlobalIdx::new(0U)),
                ]),
                remove_unused_test_i32_const(0),
              ),
            ),
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
    .with_global_sec(
      @lib.GlobalSec::new([
        @lib.Global::new(
          @lib.GlobalType::new(
            @lib.ValType::ref_type(remove_unused_test_funcref()),
            false,
          ),
          @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(1U))]),
        ),
      ]),
    )

  let optimized = remove_unused_test_run_with_features(
    mod,
    PipelineFeatures::new(has_gc=true, closed_world=true),
  )

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  assert_false(try! remove_unused_test_func_body_is_unreachable(optimized, 1))
}

///|
test "remove unused module elements does not promote unread array.new_elem funcref payloads from unrelated call_ref" {
  let mod = Module::new()
    .with_type_sec(remove_unused_test_array_type_sec_with_funcref_elem())
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
          @lib.TExpr::new([
            @lib.TInstr::drop(
              @lib.TInstr::array_new_elem(
                @lib.TypeIdx::new(1U),
                @lib.ElemIdx::new(0U),
                remove_unused_test_i32_const(0),
                remove_unused_test_i32_const(1),
              ),
            ),
            @lib.TInstr::call_ref(
              @lib.TypeIdx::new(0U),
              [],
              @lib.TInstr::global_get(@lib.GlobalIdx::new(0U)),
            ),
          ]),
        ),
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
          @lib.GlobalType::new(
            @lib.ValType::ref_type(remove_unused_test_funcref()),
            false,
          ),
          @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(2U))]),
        ),
      ]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::passive(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(1U)]),
        ),
      ]),
    )

  let optimized = remove_unused_test_run_with_features(
    mod,
    PipelineFeatures::new(has_gc=true, closed_world=true),
  )

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 3)
    None => fail("expected func section")
  }
  match optimized.elem_sec {
    Some(
      @lib.ElemSec(
        [@lib.Elem(@lib.Passive, @lib.FuncsElemKind([@lib.FuncIdx(idx)]))]
      )
    ) => assert_eq(idx, 1U)
    _ => fail("expected retained passive elem section")
  }
  assert_eq(try! remove_unused_test_global_ref_func_target(optimized, 0), 2U)
  assert_true(try! remove_unused_test_func_body_is_unreachable(optimized, 1))
  assert_false(try! remove_unused_test_func_body_is_unreachable(optimized, 2))
}

///|
test "remove unused module elements promotes array.new_elem funcref payloads once read" {
  let mod = Module::new()
    .with_type_sec(remove_unused_test_array_type_sec_with_funcref_elem())
    .with_func_sec(
      @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(0U)]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::t_func(
          [],
          @lib.Locals::empty(),
          @lib.TExpr::new([
            @lib.TInstr::call_ref(
              @lib.TypeIdx::new(0U),
              [],
              @lib.TInstr::array_get(
                @lib.TypeIdx::new(1U),
                @lib.TInstr::array_new_elem(
                  @lib.TypeIdx::new(1U),
                  @lib.ElemIdx::new(0U),
                  remove_unused_test_i32_const(0),
                  remove_unused_test_i32_const(1),
                ),
                remove_unused_test_i32_const(0),
              ),
            ),
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
      ]),
    )

  let optimized = remove_unused_test_run_with_features(
    mod,
    PipelineFeatures::new(has_gc=true, closed_world=true),
  )

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  match optimized.elem_sec {
    Some(
      @lib.ElemSec(
        [@lib.Elem(@lib.Passive, @lib.FuncsElemKind([@lib.FuncIdx(idx)]))]
      )
    ) => assert_eq(idx, 1U)
    _ => fail("expected retained passive elem section")
  }
  assert_false(try! remove_unused_test_func_body_is_unreachable(optimized, 1))
}

///|
test "remove unused module elements does not promote unread array.set funcref payloads from unrelated call_ref" {
  let mod = Module::new()
    .with_type_sec(
      remove_unused_test_mutable_array_type_sec_with_funcref_elem(),
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
          @lib.TExpr::new([
            @lib.TInstr::array_set(
              @lib.TypeIdx::new(1U),
              @lib.TInstr::array_new_default(
                @lib.TypeIdx::new(1U),
                remove_unused_test_i32_const(1),
              ),
              remove_unused_test_i32_const(0),
              @lib.TInstr::global_get(@lib.GlobalIdx::new(0U)),
            ),
            @lib.TInstr::call_ref(
              @lib.TypeIdx::new(0U),
              [],
              @lib.TInstr::global_get(@lib.GlobalIdx::new(1U)),
            ),
          ]),
        ),
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
          @lib.GlobalType::new(
            @lib.ValType::ref_type(remove_unused_test_funcref()),
            false,
          ),
          @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(1U))]),
        ),
        @lib.Global::new(
          @lib.GlobalType::new(
            @lib.ValType::ref_type(remove_unused_test_funcref()),
            false,
          ),
          @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(2U))]),
        ),
      ]),
    )

  let optimized = remove_unused_test_run_with_features(
    mod,
    PipelineFeatures::new(has_gc=true, closed_world=true),
  )

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 3)
    None => fail("expected func section")
  }
  assert_eq(try! remove_unused_test_global_ref_func_target(optimized, 0), 1U)
  assert_eq(try! remove_unused_test_global_ref_func_target(optimized, 1), 2U)
  assert_true(try! remove_unused_test_func_body_is_unreachable(optimized, 1))
  assert_false(try! remove_unused_test_func_body_is_unreachable(optimized, 2))
}

///|
test "remove unused module elements promotes array.set funcref payloads once read" {
  let mod = Module::new()
    .with_type_sec(
      remove_unused_test_mutable_array_type_sec_with_funcref_elem(),
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
            @lib.TInstr::array_set(
              @lib.TypeIdx::new(1U),
              @lib.TInstr::array_new_default(
                @lib.TypeIdx::new(1U),
                remove_unused_test_i32_const(1),
              ),
              remove_unused_test_i32_const(0),
              @lib.TInstr::global_get(@lib.GlobalIdx::new(0U)),
            ),
            @lib.TInstr::call_ref(
              @lib.TypeIdx::new(0U),
              [],
              @lib.TInstr::array_get(
                @lib.TypeIdx::new(1U),
                @lib.TInstr::array_new_default(
                  @lib.TypeIdx::new(1U),
                  remove_unused_test_i32_const(1),
                ),
                remove_unused_test_i32_const(0),
              ),
            ),
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
    .with_global_sec(
      @lib.GlobalSec::new([
        @lib.Global::new(
          @lib.GlobalType::new(
            @lib.ValType::ref_type(remove_unused_test_funcref()),
            false,
          ),
          @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(1U))]),
        ),
      ]),
    )

  let optimized = remove_unused_test_run_with_features(
    mod,
    PipelineFeatures::new(has_gc=true, closed_world=true),
  )

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  assert_false(try! remove_unused_test_func_body_is_unreachable(optimized, 1))
}

///|
test "remove unused module elements does not promote unread array.init_elem funcref payloads from unrelated call_ref" {
  let mod = Module::new()
    .with_type_sec(
      remove_unused_test_mutable_array_type_sec_with_funcref_elem(),
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
          @lib.TExpr::new([
            @lib.TInstr::array_init_elem(
              @lib.TypeIdx::new(1U),
              @lib.ElemIdx::new(0U),
              @lib.TInstr::array_new_default(
                @lib.TypeIdx::new(1U),
                remove_unused_test_i32_const(1),
              ),
              remove_unused_test_i32_const(0),
              remove_unused_test_i32_const(0),
              remove_unused_test_i32_const(1),
            ),
            @lib.TInstr::call_ref(
              @lib.TypeIdx::new(0U),
              [],
              @lib.TInstr::global_get(@lib.GlobalIdx::new(0U)),
            ),
          ]),
        ),
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
          @lib.GlobalType::new(
            @lib.ValType::ref_type(remove_unused_test_funcref()),
            false,
          ),
          @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(2U))]),
        ),
      ]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::passive(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(1U)]),
        ),
      ]),
    )

  let optimized = remove_unused_test_run_with_features(
    mod,
    PipelineFeatures::new(has_gc=true, closed_world=true),
  )

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 3)
    None => fail("expected func section")
  }
  match optimized.elem_sec {
    Some(
      @lib.ElemSec(
        [@lib.Elem(@lib.Passive, @lib.FuncsElemKind([@lib.FuncIdx(idx)]))]
      )
    ) => assert_eq(idx, 1U)
    _ => fail("expected retained passive elem section")
  }
  assert_eq(try! remove_unused_test_global_ref_func_target(optimized, 0), 2U)
  assert_true(try! remove_unused_test_func_body_is_unreachable(optimized, 1))
  assert_false(try! remove_unused_test_func_body_is_unreachable(optimized, 2))
}

///|
test "remove unused module elements promotes array.init_elem funcref payloads once read" {
  let mod = Module::new()
    .with_type_sec(
      remove_unused_test_mutable_array_type_sec_with_funcref_elem(),
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
            @lib.TInstr::array_init_elem(
              @lib.TypeIdx::new(1U),
              @lib.ElemIdx::new(0U),
              @lib.TInstr::array_new_default(
                @lib.TypeIdx::new(1U),
                remove_unused_test_i32_const(1),
              ),
              remove_unused_test_i32_const(0),
              remove_unused_test_i32_const(0),
              remove_unused_test_i32_const(1),
            ),
            @lib.TInstr::call_ref(
              @lib.TypeIdx::new(0U),
              [],
              @lib.TInstr::array_get(
                @lib.TypeIdx::new(1U),
                @lib.TInstr::array_new_elem(
                  @lib.TypeIdx::new(1U),
                  @lib.ElemIdx::new(0U),
                  remove_unused_test_i32_const(0),
                  remove_unused_test_i32_const(1),
                ),
                remove_unused_test_i32_const(0),
              ),
            ),
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
      ]),
    )

  let optimized = remove_unused_test_run_with_features(
    mod,
    PipelineFeatures::new(has_gc=true, closed_world=true),
  )

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  match optimized.elem_sec {
    Some(
      @lib.ElemSec(
        [@lib.Elem(@lib.Passive, @lib.FuncsElemKind([@lib.FuncIdx(idx)]))]
      )
    ) => assert_eq(idx, 1U)
    _ => fail("expected retained passive elem section")
  }
  assert_false(try! remove_unused_test_func_body_is_unreachable(optimized, 1))
}

///|
test "remove unused module elements keeps open-world bare ref.func targets fully live" {
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
          @lib.TExpr::new([
            @lib.TInstr::drop(@lib.TInstr::global_get(@lib.GlobalIdx::new(0U))),
          ]),
        ),
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
          @lib.GlobalType::new(
            @lib.ValType::ref_type(remove_unused_test_funcref()),
            false,
          ),
          @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(1U))]),
        ),
      ]),
    )

  let optimized = remove_unused_test_run(mod)

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 3)
    None => fail("expected func section")
  }
  assert_eq(try! remove_unused_test_main_ref_global_target(optimized), 0U)
  assert_eq(try! remove_unused_test_global_ref_func_target(optimized, 0), 1U)
  assert_false(try! remove_unused_test_func_body_is_unreachable(optimized, 1))
  assert_eq(try! remove_unused_test_func_call_target(optimized, 1), 2U)
}

///|
test "remove unused module elements is idempotent across mixed module-element compaction" {
  let mod = Module::new()
    .with_type_sec(remove_unused_test_type_sec())
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("ig"),
          @lib.ExternType::global(
            @lib.GlobalType::new(@lib.ValType::i32(), false),
          ),
        ),
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("it"),
          @lib.ExternType::table(
            @lib.TableType::new(
              remove_unused_test_funcref(),
              @lib.Limits::i32(1U, None),
            ),
          ),
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
          @lib.TExpr::new([
            @lib.TInstr::drop(@lib.TInstr::global_get(@lib.GlobalIdx::new(2U))),
            @lib.TInstr::drop(@lib.TInstr::table_size(@lib.TableIdx::new(1U))),
          ]),
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
    .with_global_sec(
      @lib.GlobalSec::new([
        @lib.Global::new(
          @lib.GlobalType::new(@lib.ValType::i32(), false),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(7))]),
        ),
        @lib.Global::new(
          @lib.GlobalType::new(@lib.ValType::i32(), false),
          @lib.Expr::new([@lib.Instruction::global_get(@lib.GlobalIdx::new(0U))]),
        ),
      ]),
    )
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            remove_unused_test_funcref(),
            @lib.Limits::i32(1U, None),
          ),
          Some(
            @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(2U))]),
          ),
        ),
      ]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::passive(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
        ),
      ]),
    )
    .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32::new(1U)))
    .with_data_sec(
      @lib.DataSec::new([@lib.Data::new(@lib.DataMode::passive(), b"dead")]),
    )

  let once = remove_unused_test_run(mod)
  let twice = remove_unused_test_run_twice(mod)

  assert_eq(once, twice)
}

///|
test "remove unused module elements removes unused tags and rewrites tag indices and names" {
  let mod = Module::new()
    .with_type_sec(remove_unused_test_type_sec())
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("itag"),
          @lib.ExternType::tag(@lib.TagType::new(@lib.TypeIdx::new(0U))),
        ),
      ]),
    )
    .with_tag_sec(
      @lib.TagSec::new([
        @lib.TagType::new(@lib.TypeIdx::new(0U)),
        @lib.TagType::new(@lib.TypeIdx::new(0U)),
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
          @lib.TExpr::new([@lib.TInstr::throw_(@lib.TagIdx::new(2U), [])]),
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
          @lib.Name::from_string("live-tag"),
          @lib.ExternIdx::tag(@lib.TagIdx::new(2U)),
        ),
      ]),
    )
    .with_name_sec(
      @lib.NameSec::new(
        tag_names=Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("itag")),
            @lib.NameAssoc::new(1U, @lib.Name::from_string("dead-tag")),
            @lib.NameAssoc::new(2U, @lib.Name::from_string("live-tag")),
          ]),
        ),
      ),
    )

  let optimized = remove_unused_test_run(mod)

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 1)
    None => fail("expected func section")
  }
  match optimized.tag_sec {
    Some(@lib.TagSec(tags)) => assert_eq(tags.length(), 1)
    None => fail("expected tag section")
  }
  assert_eq(try! remove_unused_test_main_throw_tag_target(optimized), 1U)
  match optimized.export_sec {
    Some(
      @lib.ExportSec(
        [
          @lib.Export(_, @lib.FuncExternIdx(@lib.FuncIdx(func_idx))),
          @lib.Export(_, @lib.TagExternIdx(@lib.TagIdx(tag_idx))),
        ]
      )
    ) => {
      assert_eq(func_idx, 0U)
      assert_eq(tag_idx, 1U)
    }
    _ => fail("expected rewritten exports")
  }
  match optimized.name_sec {
    Some(name_sec) => {
      let { tag_names, .. } = name_sec
      assert_eq(
        tag_names,
        Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("itag")),
            @lib.NameAssoc::new(1U, @lib.Name::from_string("live-tag")),
          ]),
        ),
      )
    }
    None => fail("expected name section")
  }
}

///|
test "remove unused module elements keeps tags referenced by live catches" {
  let mod = Module::new()
    .with_type_sec(remove_unused_test_type_sec())
    .with_tag_sec(
      @lib.TagSec::new([
        @lib.TagType::new(@lib.TypeIdx::new(0U)),
        @lib.TagType::new(@lib.TypeIdx::new(0U)),
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
            @lib.TInstr::try_table(
              @lib.BlockType::void_(),
              [@lib.Catch::new(@lib.TagIdx::new(1U), @lib.LabelIdx::new(0U))],
              @lib.TExpr::new([@lib.TInstr::nop()]),
            ),
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

  let optimized = remove_unused_test_run(mod)

  match optimized.tag_sec {
    Some(@lib.TagSec(tags)) => assert_eq(tags.length(), 1)
    None => fail("expected tag section")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.TFunc(_, _, body), ..])) =>
      match body.inner()[0].kind {
        @lib.TTryTable(
          _,
          [@lib.Catch(@lib.TagIdx(tag_idx), @lib.LabelIdx(label_idx))],
          _
        ) => {
          assert_eq(tag_idx, 0U)
          assert_eq(label_idx, 0U)
        }
        _ => fail("expected try_table catch")
      }
    _ => fail("expected code section")
  }
}
