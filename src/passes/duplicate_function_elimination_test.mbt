///|
fn dfe_test_type_sec() -> @lib.TypeSec {
  @lib.TypeSec::new([
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
    ),
  ])
}

///|
fn dfe_test_call_target(mod_ : @lib.Module, defined_idx : Int) -> UInt raise {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[defined_idx] {
        @lib.Func(_, @lib.Expr([@lib.Call(@lib.FuncIdx(target)), ..])) => target
        _ => fail("expected first instruction to be call")
      }
    None => fail("expected code section")
  }
}

///|
fn dfe_test_ref_func_target(
  mod_ : @lib.Module,
  defined_idx : Int,
) -> UInt raise {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[defined_idx] {
        @lib.Func(
          _,
          @lib.Expr([_, @lib.Drop, @lib.RefFunc(@lib.FuncIdx(target)), ..])
        ) => target
        @lib.Func(
          _,
          @lib.Expr([_, @lib.RefFunc(@lib.FuncIdx(target)), @lib.Drop, ..])
        ) => target
        _ => fail("expected dropped ref.func sequence")
      }
    None => fail("expected code section")
  }
}

///|
fn dfe_test_block_type(mod_ : @lib.Module, defined_idx : Int) -> UInt raise {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[defined_idx] {
        @lib.Func(
          _,
          @lib.Expr(
            [@lib.Block(@lib.TypeIdxBlockType(@lib.TypeIdx(block_type)), _), ..]
          )
        ) => block_type
        _ => fail("expected leading typed block")
      }
    None => fail("expected code section")
  }
}

///|
test "run_hot_pipeline applies duplicate-function-elimination and rewrites function references" {
  let input = @lib.Module::new()
    .with_type_sec(dfe_test_type_sec())
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("imported"),
          @lib.ExternType::func(@lib.TypeIdx::new(0U)),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([
        @lib.TypeIdx::new(0U),
        @lib.TypeIdx::new(1U),
        @lib.TypeIdx::new(2U),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(3U)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(3U)),
            @lib.Instruction::drop(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([@lib.Instruction::nop()]),
        ),
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([@lib.Instruction::nop()]),
        ),
      ]),
    )
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("dup"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(3U)),
        ),
      ]),
    )
    .with_start_sec(@lib.StartSec::new(@lib.FuncIdx::new(3U)))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::passive(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(3U)]),
        ),
      ]),
    )

  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), [
      "duplicate-function-elimination",
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected duplicate-function-elimination pipeline success, got \{err}",
      )
  }

  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => assert_eq(funcs.length(), 2)
    None => fail("expected code section")
  }
  assert_eq(try! dfe_test_call_target(optimized, 0), 2U)
  assert_eq(try! dfe_test_ref_func_target(optimized, 0), 2U)
  match optimized.export_sec {
    Some(
      @lib.ExportSec([@lib.Export(_, @lib.FuncExternIdx(@lib.FuncIdx(target)))])
    ) => assert_eq(target, 2U)
    _ => fail("expected rewritten function export")
  }
  match optimized.start_sec {
    Some(@lib.StartSec(@lib.FuncIdx(target))) => assert_eq(target, 2U)
    _ => fail("expected rewritten start section")
  }
  match optimized.elem_sec {
    Some(
      @lib.ElemSec([@lib.Elem(_, @lib.FuncsElemKind([@lib.FuncIdx(target)]))])
    ) => assert_eq(target, 2U)
    _ => fail("expected rewritten elem section")
  }
}

///|
test "duplicate-function-elimination is single-pass when callee dedup unlocks more duplicates" {
  let input = @lib.Module::new()
    .with_type_sec(dfe_test_type_sec())
    .with_func_sec(
      @lib.FuncSec::new([
        @lib.TypeIdx::new(0U),
        @lib.TypeIdx::new(1U),
        @lib.TypeIdx::new(2U),
        @lib.TypeIdx::new(1U),
        @lib.TypeIdx::new(2U),
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
          @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(3U))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(4U))]),
        ),
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([@lib.Instruction::nop()]),
        ),
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([@lib.Instruction::nop()]),
        ),
      ]),
    )

  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), [
      "duplicate-function-elimination",
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected duplicate-function-elimination pipeline success, got \{err}",
      )
  }

  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => assert_eq(funcs.length(), 4)
    None => fail("expected code section")
  }
  assert_eq(try! dfe_test_call_target(optimized, 0), 1U)
  assert_eq(try! dfe_test_call_target(optimized, 1), 3U)
  assert_eq(try! dfe_test_call_target(optimized, 2), 3U)
}

///|
test "duplicate-function-elimination canonicalizes duplicate simple type indices after merging" {
  let block_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([block_type, block_type, func_type, func_type]),
    )
    .with_func_sec(
      @lib.FuncSec::new([@lib.TypeIdx::new(3U), @lib.TypeIdx::new(2U)]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
              @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(7))]),
            ),
            @lib.Instruction::drop(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
              @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(7))]),
            ),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )

  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), [
      "duplicate-function-elimination",
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected duplicate-function-elimination pipeline success, got \{err}",
      )
  }

  match optimized.type_sec {
    Some(@lib.TypeSec(types)) => assert_eq(types.length(), 2)
    None => fail("expected type section")
  }
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => {
      assert_eq(type_idxs.length(), 1)
      assert_eq(type_idxs[0], @lib.TypeIdx::new(1U))
    }
    None => fail("expected func section")
  }
  assert_eq(try! dfe_test_block_type(optimized, 0), 0U)
}

///|
test "duplicate-function-elimination keeps annotated duplicates distinct" {
  let input = @lib.Module::new()
    .with_type_sec(dfe_test_type_sec())
    .with_func_sec(
      @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(1U)]),
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
    .with_func_annotation_sec(
      @lib.FuncAnnotationSec::new([
        @lib.FuncAnnotationAssoc::new(0U, [
          @lib.FuncAnnotation::new("binaryen.idempotent"),
        ]),
      ]),
    )

  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), [
      "duplicate-function-elimination",
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected duplicate-function-elimination pipeline success, got \{err}",
      )
  }

  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => assert_eq(funcs.length(), 2)
    None => fail("expected code section")
  }
}

///|
test "duplicate-function-elimination canonicalizes compactable function element expressions even without duplicates" {
  let table_type = @lib.TableType::new(
    @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::func())),
    @lib.Limits::i32(1U, Some(1U)),
  )
  let input = @lib.Module::new()
    .with_type_sec(dfe_test_type_sec())
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::nop()]),
        ),
      ]),
    )
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(table_type, None),
        @lib.Table::new(table_type, None),
      ]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::active(
            @lib.TableIdx::new(1U),
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
          ),
          @lib.ElemKind::func_exprs([
            @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(0U))]),
          ]),
        ),
      ]),
    )

  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), [
      "duplicate-function-elimination",
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected duplicate-function-elimination pipeline success, got \{err}",
      )
  }

  match optimized.elem_sec {
    Some(
      @lib.ElemSec(
        [
          @lib.Elem(
            @lib.Active(@lib.TableIdx(table_idx), @lib.Expr([@lib.I32Const(_)])),
            @lib.FuncsElemKind([@lib.FuncIdx(target)])
          ),
        ]
      )
    ) => {
      assert_eq(table_idx, 1U)
      assert_eq(target, 0U)
    }
    _ => fail("expected compact canonical elem segment")
  }
}

///|
test "duplicate-function-elimination rewrites function name and annotation maps to canonical survivors" {
  let input = @lib.Module::new()
    .with_type_sec(dfe_test_type_sec())
    .with_func_sec(
      @lib.FuncSec::new([
        @lib.TypeIdx::new(0U),
        @lib.TypeIdx::new(1U),
        @lib.TypeIdx::new(2U),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(2U))]),
        ),
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([@lib.Instruction::nop()]),
        ),
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([@lib.Instruction::nop()]),
        ),
      ]),
    )
    .with_name_sec(
      @lib.NameSec::new(
        func_names=Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("left")),
            @lib.NameAssoc::new(1U, @lib.Name::from_string("middle")),
            @lib.NameAssoc::new(2U, @lib.Name::from_string("right")),
          ]),
        ),
        local_names=Some(
          @lib.IndirectNameMap::new([
            @lib.IndirectNameAssoc::new(
              1U,
              @lib.NameMap::new([
                @lib.NameAssoc::new(0U, @lib.Name::from_string("mid_local")),
              ]),
            ),
            @lib.IndirectNameAssoc::new(
              2U,
              @lib.NameMap::new([
                @lib.NameAssoc::new(0U, @lib.Name::from_string("right_local")),
              ]),
            ),
          ]),
        ),
      ),
    )
    .with_func_annotation_sec(
      @lib.FuncAnnotationSec::new([
        @lib.FuncAnnotationAssoc::new(1U, [
          @lib.FuncAnnotation::new("binaryen.idempotent"),
        ]),
        @lib.FuncAnnotationAssoc::new(2U, [
          @lib.FuncAnnotation::new("binaryen.idempotent"),
        ]),
      ]),
    )

  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), [
      "duplicate-function-elimination",
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected duplicate-function-elimination pipeline success, got \{err}",
      )
  }

  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => assert_eq(funcs.length(), 2)
    None => fail("expected code section")
  }
  match optimized.name_sec {
    Some(name_sec) => {
      let { func_names, local_names, .. } = name_sec
      assert_eq(
        func_names,
        Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("left")),
            @lib.NameAssoc::new(1U, @lib.Name::from_string("middle")),
          ]),
        ),
      )
      assert_eq(
        local_names,
        Some(
          @lib.IndirectNameMap::new([
            @lib.IndirectNameAssoc::new(
              1U,
              @lib.NameMap::new([
                @lib.NameAssoc::new(0U, @lib.Name::from_string("mid_local")),
              ]),
            ),
          ]),
        ),
      )
    }
    None => fail("expected rewritten name section")
  }
  match optimized.func_annotation_sec {
    Some(@lib.FuncAnnotationSec(entries)) =>
      assert_eq(entries, [
        @lib.FuncAnnotationAssoc::new(1U, [
          @lib.FuncAnnotation::new("binaryen.idempotent"),
        ]),
      ])
    None => fail("expected rewritten func annotation section")
  }
}
