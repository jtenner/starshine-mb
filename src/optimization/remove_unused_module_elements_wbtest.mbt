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
fn remove_unused_test_run(mod : Module) -> Module {
  let (optimized, _) = run_remove_unused_module_elements(
    mod,
    PipelineGlobal::new(),
    PipelineFeatures::new(),
  )
  optimized
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
test "remove unused module elements keeps functions referenced by elem segments" {
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
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
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
