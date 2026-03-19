///|
using @lib {
  type ExternIdx,
  type Export,
  type ExportSec,
  type Locals,
  type Name,
  type StartSec,
  type TExpr,
  type TInstr,
  type TypeSec,
  type ValType,
}

///|
fn duplicate_func_test_type_sec() -> TypeSec {
  TypeSec::new([
    RecType::new(SubType::comp_type(CompType::func([], []))),
    RecType::new(SubType::comp_type(CompType::func([], []))),
    RecType::new(SubType::comp_type(CompType::func([], []))),
    RecType::new(SubType::comp_type(CompType::func([], [ValType::i64()]))),
  ])
}

///|
fn duplicate_func_test_call_target(
  mod : Module,
  defined_idx : Int,
) -> UInt raise Error {
  match mod.code_sec {
    Some(CodeSec(funcs)) =>
      match funcs[defined_idx] {
        TFunc(_, _, body) =>
          match body.inner()[0].kind {
            TCall(FuncIdx(target), _) => target
            _ => fail("expected first instruction to be a direct call")
          }
        _ => fail("expected typed function body")
      }
    None => fail("expected code section")
  }
}

///|
fn duplicate_func_test_ref_func_target(
  mod : Module,
  defined_idx : Int,
) -> UInt raise Error {
  match mod.code_sec {
    Some(CodeSec(funcs)) =>
      match funcs[defined_idx] {
        TFunc(_, _, body) =>
          match body.inner()[1].kind {
            TDrop(dropped) =>
              match dropped.kind {
                TRefFunc(FuncIdx(target)) => target
                _ => fail("expected dropped ref.func")
              }
            _ => fail("expected second instruction to drop ref.func")
          }
        _ => fail("expected typed function body")
      }
    None => fail("expected code section")
  }
}

///|
test "duplicate function elimination merges structural duplicates and rewrites function references" {
  let mod = Module::new()
    .with_type_sec(duplicate_func_test_type_sec())
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::from_string("env"),
          Name::from_string("imported"),
          ExternType::func(TypeIdx::new(0U)),
        ),
      ]),
    )
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0U), TypeIdx::new(1U), TypeIdx::new(2U)]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          Locals::empty(),
          TExpr::new([
            TInstr::call(FuncIdx::new(3U), []),
            TInstr::drop(TInstr::ref_func(FuncIdx::new(3U))),
          ]),
        ),
        Func::t_func([], Locals::empty(), TExpr::new([TInstr::nop()])),
        Func::t_func([], Locals::empty(), TExpr::new([TInstr::nop()])),
      ]),
    )
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::from_string("dup"), ExternIdx::func(FuncIdx::new(3U))),
      ]),
    )
    .with_start_sec(StartSec::new(FuncIdx::new(3U)))

  let (optimized, _) = run_duplicate_function_elimination(
    mod,
    PipelineGlobal::new(),
  )

  match optimized.func_sec {
    Some(FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  match optimized.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 2)
    None => fail("expected code section")
  }
  assert_eq(try! duplicate_func_test_call_target(optimized, 0), 2U)
  assert_eq(try! duplicate_func_test_ref_func_target(optimized, 0), 2U)
  match optimized.export_sec {
    Some(ExportSec([Export(_, FuncExternIdx(FuncIdx(target)))])) =>
      assert_eq(target, 2U)
    _ => fail("expected rewritten function export")
  }
  match optimized.start_sec {
    Some(StartSec(FuncIdx(target))) => assert_eq(target, 2U)
    _ => fail("expected rewritten start section")
  }
}

///|
test "duplicate function elimination iterates when deduping callees unlocks more duplicates" {
  let mod = Module::new()
    .with_type_sec(duplicate_func_test_type_sec())
    .with_func_sec(
      FuncSec::new([
        TypeIdx::new(0U),
        TypeIdx::new(1U),
        TypeIdx::new(2U),
        TypeIdx::new(1U),
        TypeIdx::new(2U),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          Locals::empty(),
          TExpr::new([TInstr::call(FuncIdx::new(1U), [])]),
        ),
        Func::t_func(
          [],
          Locals::empty(),
          TExpr::new([TInstr::call(FuncIdx::new(3U), [])]),
        ),
        Func::t_func(
          [],
          Locals::empty(),
          TExpr::new([TInstr::call(FuncIdx::new(4U), [])]),
        ),
        Func::t_func([], Locals::empty(), TExpr::new([TInstr::nop()])),
        Func::t_func([], Locals::empty(), TExpr::new([TInstr::nop()])),
      ]),
    )

  let (optimized, _) = run_duplicate_function_elimination(
    mod,
    PipelineGlobal::new(opt_level=2),
  )

  match optimized.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 3)
    None => fail("expected code section")
  }
  assert_eq(try! duplicate_func_test_call_target(optimized, 0), 1U)
  assert_eq(try! duplicate_func_test_call_target(optimized, 1), 2U)
}

///|
test "duplicate function elimination keeps same-body functions with different structural signatures" {
  let mod = Module::new()
    .with_type_sec(duplicate_func_test_type_sec())
    .with_func_sec(FuncSec::new([TypeIdx::new(1U), TypeIdx::new(3U)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], Locals::empty(), TExpr::new([TInstr::unreachable_()])),
        Func::t_func([], Locals::empty(), TExpr::new([TInstr::unreachable_()])),
      ]),
    )

  let (optimized, _) = run_duplicate_function_elimination(
    mod,
    PipelineGlobal::new(),
  )

  match optimized.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 2)
    None => fail("expected code section")
  }
}
