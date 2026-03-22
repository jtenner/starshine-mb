///|
fn once_reduction_test_type_sec() -> @lib.TypeSec {
  @lib.TypeSec::new([
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
  ])
}

///|
fn once_reduction_test_global() -> @lib.Global {
  @lib.Global::new(
    @lib.GlobalType::new(@lib.ValType::i32(), true),
    @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
  )
}

///|
fn once_reduction_test_globals(count : Int) -> Array[@lib.Global] {
  let globals : Array[@lib.Global] = []
  for _ in 0..<count {
    globals.push(once_reduction_test_global())
  }
  globals
}

///|
fn once_reduction_test_once_body(
  global_idx : @lib.GlobalIdx,
  trailing? : Array[@lib.TInstr] = [],
) -> @lib.TExpr {
  let instrs = [
    @lib.TInstr::if_(
      @lib.BlockType::void_(),
      @lib.TInstr::global_get(global_idx),
      @lib.TExpr::new([@lib.TInstr::return_([])]),
      None,
    ),
    @lib.TInstr::global_set(global_idx, @lib.TInstr::i32_const(@lib.I32(1))),
  ]
  for instr in trailing {
    instrs.push(instr)
  }
  @lib.TExpr::new(instrs)
}

///|
fn once_reduction_test_module(
  funcs : Array[@lib.Func],
  export_global? : Bool = false,
  extra_func? : @lib.Func? = None,
  global_count? : Int = 1,
) -> Module {
  let code_funcs = funcs.copy()
  if extra_func is Some(func) {
    code_funcs.push(func)
  }
  let func_types : Array[@lib.TypeIdx] = []
  for _ in code_funcs {
    func_types.push(@lib.TypeIdx::new(0U))
  }
  let mut mod = Module::new()
    .with_type_sec(once_reduction_test_type_sec())
    .with_global_sec(
      @lib.GlobalSec::new(once_reduction_test_globals(global_count)),
    )
    .with_func_sec(@lib.FuncSec::new(func_types))
    .with_code_sec(@lib.CodeSec::new(code_funcs))
  if export_global {
    mod = mod.with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("once-global"),
          @lib.ExternIdx::global(@lib.GlobalIdx::new(0U)),
        ),
      ]),
    )
  }
  mod
}

///|
fn once_reduction_test_body(
  mod : Module,
  defined_idx : Int,
) -> @lib.TExpr raise Error {
  match mod.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[defined_idx] {
        @lib.TFunc(_, _, body) => body
        _ => fail("expected typed function body")
      }
    None => fail("expected code section")
  }
}

///|
fn once_reduction_test_annotation_sec(
  entries : Array[(UInt, Array[@lib.FuncAnnotation])],
) -> @lib.FuncAnnotationSec {
  let lowered : Array[@lib.FuncAnnotationAssoc] = []
  for entry in entries {
    let (idx, annotations) = entry
    lowered.push(@lib.FuncAnnotationAssoc::new(idx, annotations))
  }
  @lib.FuncAnnotationSec::new(lowered)
}

///|
test "once reduction matches the exact top-level once pattern" {
  let body = once_reduction_test_once_body(@lib.GlobalIdx::new(0U))
  assert_eq(
    optimization_once_reduction_match_once_global(body),
    Some(@lib.GlobalIdx::new(0U)),
  )
}

///|
test "once reduction rejects leading instructions before the guard" {
  let body = @lib.TExpr::new([
    @lib.TInstr::nop(),
    @lib.TInstr::if_(
      @lib.BlockType::void_(),
      @lib.TInstr::global_get(@lib.GlobalIdx::new(0U)),
      @lib.TExpr::new([@lib.TInstr::return_([])]),
      None,
    ),
    @lib.TInstr::global_set(
      @lib.GlobalIdx::new(0U),
      @lib.TInstr::i32_const(@lib.I32(1)),
    ),
  ])
  assert_eq(optimization_once_reduction_match_once_global(body), None)
}

///|
test "once reduction candidate analysis accepts the exact monotonic once shape" {
  let mod = once_reduction_test_module([
    @lib.Func::t_func(
      [],
      @lib.Locals::empty(),
      once_reduction_test_once_body(@lib.GlobalIdx::new(0U)),
    ),
  ])

  let analysis = optimization_once_reduction_analyze_candidates(mod)

  assert_true(analysis.once_globals[0])
  assert_eq(analysis.once_func_globals[0], Some(GlobalIdx::new(0U)))
}

///|
test "once reduction candidate analysis rejects extra reads of the once global" {
  let mod = once_reduction_test_module([
    @lib.Func::t_func(
      [],
      @lib.Locals::empty(),
      once_reduction_test_once_body(@lib.GlobalIdx::new(0U), trailing=[
        @lib.TInstr::drop(@lib.TInstr::global_get(@lib.GlobalIdx::new(0U))),
      ]),
    ),
  ])

  let analysis = optimization_once_reduction_analyze_candidates(mod)

  assert_true(!analysis.once_globals[0])
  assert_eq(analysis.once_func_globals[0], None)
}

///|
test "once reduction candidate analysis rejects exported once globals" {
  let mod = once_reduction_test_module(
    [
      @lib.Func::t_func(
        [],
        @lib.Locals::empty(),
        once_reduction_test_once_body(@lib.GlobalIdx::new(0U)),
      ),
    ],
    export_global=true,
  )

  let analysis = optimization_once_reduction_analyze_candidates(mod)

  assert_true(!analysis.once_globals[0])
  assert_eq(analysis.once_func_globals[0], None)
}

///|
test "once reduction candidate analysis rejects globals written back to zero" {
  let mod = once_reduction_test_module(
    [
      @lib.Func::t_func(
        [],
        @lib.Locals::empty(),
        once_reduction_test_once_body(@lib.GlobalIdx::new(0U)),
      ),
    ],
    extra_func=Some(
      @lib.Func::t_func(
        [],
        @lib.Locals::empty(),
        @lib.TExpr::new([
          @lib.TInstr::global_set(
            @lib.GlobalIdx::new(0U),
            @lib.TInstr::i32_const(@lib.I32(0)),
          ),
        ]),
      ),
    ),
  )

  let analysis = optimization_once_reduction_analyze_candidates(mod)

  assert_true(!analysis.once_globals[0])
  assert_eq(analysis.once_func_globals[0], None)
}

///|
test "once reduction removes dominated duplicate direct calls" {
  let mod = once_reduction_test_module([
    @lib.Func::t_func(
      [],
      @lib.Locals::empty(),
      once_reduction_test_once_body(@lib.GlobalIdx::new(0U)),
    ),
    @lib.Func::t_func(
      [],
      @lib.Locals::empty(),
      @lib.TExpr::new([
        @lib.TInstr::call(@lib.FuncIdx::new(0U), []),
        @lib.TInstr::call(@lib.FuncIdx::new(0U), []),
      ]),
    ),
  ])

  let (optimized, _) = run_once_reduction(
    mod,
    PipelineGlobal::new(),
    PipelineFeatures::new(),
  )

  let body = try! once_reduction_test_body(optimized, 1)
  match body.inner()[0].kind {
    @lib.TCall(@lib.FuncIdx(target), args) => {
      assert_eq(target, 0U)
      assert_eq(args.length(), 0)
    }
    _ => fail("expected first caller instruction to remain a direct call")
  }
  match body.inner()[1].kind {
    @lib.TNop => ()
    _ => fail("expected second caller instruction to become nop")
  }
}

///|
test "once reduction removes duplicate calls to annotated idempotent functions" {
  let mod = once_reduction_test_module(
    [
      @lib.Func::t_func(
        [],
        @lib.Locals::empty(),
        @lib.TExpr::new([@lib.TInstr::nop()]),
      ),
      @lib.Func::t_func(
        [],
        @lib.Locals::empty(),
        @lib.TExpr::new([
          @lib.TInstr::call(@lib.FuncIdx::new(0U), []),
          @lib.TInstr::call(@lib.FuncIdx::new(0U), []),
        ]),
      ),
    ],
    global_count=0,
  ).with_func_annotation_sec(
    once_reduction_test_annotation_sec([
      (0U, [@lib.FuncAnnotation::new("binaryen.idempotent")]),
    ]),
  )

  let (optimized, _) = run_once_reduction(
    mod,
    PipelineGlobal::new(),
    PipelineFeatures::new(),
  )

  let body = try! once_reduction_test_body(optimized, 1)
  match body.inner()[0].kind {
    @lib.TCall(@lib.FuncIdx(target), args) => {
      assert_eq(target, 0U)
      assert_eq(args.length(), 0)
    }
    _ => fail("expected first idempotent call to remain")
  }
  match body.inner()[1].kind {
    @lib.TNop => ()
    _ => fail("expected second idempotent call to become nop")
  }
}

///|
test "once reduction propagates once facts through direct non-once callees" {
  let mod = once_reduction_test_module([
    @lib.Func::t_func(
      [],
      @lib.Locals::empty(),
      once_reduction_test_once_body(@lib.GlobalIdx::new(0U)),
    ),
    @lib.Func::t_func(
      [],
      @lib.Locals::empty(),
      @lib.TExpr::new([@lib.TInstr::call(@lib.FuncIdx::new(0U), [])]),
    ),
    @lib.Func::t_func(
      [],
      @lib.Locals::empty(),
      @lib.TExpr::new([
        @lib.TInstr::call(@lib.FuncIdx::new(1U), []),
        @lib.TInstr::call(@lib.FuncIdx::new(0U), []),
      ]),
    ),
  ])

  let (optimized, _) = run_once_reduction(
    mod,
    PipelineGlobal::new(),
    PipelineFeatures::new(),
  )

  let body = try! once_reduction_test_body(optimized, 2)
  match body.inner()[0].kind {
    @lib.TCall(@lib.FuncIdx(target), args) => {
      assert_eq(target, 1U)
      assert_eq(args.length(), 0)
    }
    _ => fail("expected helper call to remain")
  }
  match body.inner()[1].kind {
    @lib.TNop => ()
    _ => fail("expected trailing once call to become nop")
  }
}

///|
test "once reduction collapses trivial once bodies to nop" {
  let mod = once_reduction_test_module([
    @lib.Func::t_func(
      [],
      @lib.Locals::empty(),
      once_reduction_test_once_body(@lib.GlobalIdx::new(0U)),
    ),
  ])

  let (optimized, _) = run_once_reduction(
    mod,
    PipelineGlobal::new(),
    PipelineFeatures::new(),
  )

  let body = try! once_reduction_test_body(optimized, 0)
  match body.inner() {
    [instr] =>
      match instr.kind {
        @lib.TNop => ()
        _ => fail("expected trivial once body to collapse to a single nop")
      }
    _ => fail("expected trivial once body to contain one instruction")
  }
}

///|
test "once reduction removes wrapper guard logic when payload is a single once call" {
  let mod = once_reduction_test_module(
    [
      @lib.Func::t_func(
        [],
        @lib.Locals::empty(),
        once_reduction_test_once_body(@lib.GlobalIdx::new(0U), trailing=[
          @lib.TInstr::call(@lib.FuncIdx::new(1U), []),
        ]),
      ),
      @lib.Func::t_func(
        [],
        @lib.Locals::empty(),
        once_reduction_test_once_body(@lib.GlobalIdx::new(1U)),
      ),
    ],
    global_count=2,
  )

  let (optimized, _) = run_once_reduction(
    mod,
    PipelineGlobal::new(),
    PipelineFeatures::new(),
  )

  let body = try! once_reduction_test_body(optimized, 0)
  assert_eq(body.inner().length(), 3)
  match body.inner()[0].kind {
    @lib.TNop => ()
    _ => fail("expected wrapper guard to be removed")
  }
  match body.inner()[1].kind {
    @lib.TNop => ()
    _ => fail("expected wrapper set to be removed")
  }
  match body.inner()[2].kind {
    @lib.TCall(@lib.FuncIdx(target), args) => {
      assert_eq(target, 1U)
      assert_eq(args.length(), 0)
    }
    _ => fail("expected payload call to remain")
  }
}

///|
test "once reduction keeps one side guarded in a two-function once loop" {
  let mod = once_reduction_test_module(
    [
      @lib.Func::t_func(
        [],
        @lib.Locals::empty(),
        once_reduction_test_once_body(@lib.GlobalIdx::new(0U), trailing=[
          @lib.TInstr::call(@lib.FuncIdx::new(1U), []),
        ]),
      ),
      @lib.Func::t_func(
        [],
        @lib.Locals::empty(),
        once_reduction_test_once_body(@lib.GlobalIdx::new(1U), trailing=[
          @lib.TInstr::call(@lib.FuncIdx::new(0U), []),
        ]),
      ),
    ],
    global_count=2,
  )

  let (optimized, _) = run_once_reduction(
    mod,
    PipelineGlobal::new(),
    PipelineFeatures::new(),
  )

  let first = try! once_reduction_test_body(optimized, 0)
  match first.inner()[0].kind {
    @lib.TNop => ()
    _ => fail("expected first loop participant to drop its guard")
  }

  let second = try! once_reduction_test_body(optimized, 1)
  match second.inner()[0].kind {
    @lib.TIf(_, _, _, _) => ()
    _ => fail("expected second loop participant to keep its guard")
  }
}

///|
test "once reduction removes redundant once-global sets after a known write" {
  let mod = once_reduction_test_module([
    @lib.Func::t_func(
      [],
      @lib.Locals::empty(),
      once_reduction_test_once_body(@lib.GlobalIdx::new(0U)),
    ),
    @lib.Func::t_func(
      [],
      @lib.Locals::empty(),
      @lib.TExpr::new([
        @lib.TInstr::call(@lib.FuncIdx::new(0U), []),
        @lib.TInstr::global_set(
          @lib.GlobalIdx::new(0U),
          @lib.TInstr::i32_const(@lib.I32(42)),
        ),
      ]),
    ),
  ])

  let (optimized, _) = run_once_reduction(
    mod,
    PipelineGlobal::new(),
    PipelineFeatures::new(),
  )

  let body = try! once_reduction_test_body(optimized, 1)
  match body.inner()[1].kind {
    @lib.TNop => ()
    _ => fail("expected redundant once-global set to become nop")
  }
}

///|
test "once reduction keeps calls after one-arm conditionals when they are not proven redundant" {
  let mod = once_reduction_test_module([
    @lib.Func::t_func(
      [],
      @lib.Locals::empty(),
      once_reduction_test_once_body(@lib.GlobalIdx::new(0U)),
    ),
    @lib.Func::t_func(
      [],
      @lib.Locals::empty(),
      @lib.TExpr::new([
        @lib.TInstr::if_(
          @lib.BlockType::void_(),
          @lib.TInstr::i32_const(@lib.I32(1)),
          @lib.TExpr::new([@lib.TInstr::call(@lib.FuncIdx::new(0U), [])]),
          None,
        ),
        @lib.TInstr::call(@lib.FuncIdx::new(0U), []),
      ]),
    ),
  ])

  let (optimized, _) = run_once_reduction(
    mod,
    PipelineGlobal::new(),
    PipelineFeatures::new(),
  )

  let body = try! once_reduction_test_body(optimized, 1)
  match body.inner()[1].kind {
    @lib.TCall(@lib.FuncIdx(target), args) => {
      assert_eq(target, 0U)
      assert_eq(args.length(), 0)
    }
    _ => fail("expected post-if call to remain")
  }
}
