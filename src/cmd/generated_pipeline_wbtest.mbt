///|
fn generated_pipeline_test_type_sec() -> @lib.TypeSec {
  @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([], [@lib.ValType::i32(), @lib.ValType::i32()]),
      ),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::struct_([
          @lib.FieldType::new(
            @lib.StorageType::val_type(@lib.ValType::i32()),
            @lib.Mut::Const,
          ),
        ]),
      ),
    ),
  ])
}

///|
fn generated_pipeline_first_four(mod : Module) -> Array[PipelineEntry] {
  let (pipeline, truncated) = limit_generated_pipeline_by_max_passes(
    cmd_generated_pipeline_from_flags(
      mod,
      ["optimize"],
      OptimizeOptions::new(optimize_level=2),
    ),
    Some(4),
  )
  if !truncated {
    abort("expected first-four-pass truncation to be active")
  }
  pipeline
}

///|
fn generated_pipeline_raw_once_module() -> Module {
  Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_global_sec(
    @lib.GlobalSec::new([
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::i32(), true),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(0))]),
      ),
    ]),
  )
  .with_func_sec(
    @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(1U)]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [@lib.Instruction::return_()],
            None,
          ),
          @lib.Instruction::i32_const(@lib.I32::new(1)),
          @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
          @lib.Instruction::nop(),
        ]),
      ),
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        ]),
      ),
    ]),
  )
  .with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::from_string("run"),
        @lib.ExternIdx::func(@lib.FuncIdx::new(1U)),
      ),
    ]),
  )
}

///|
fn generated_pipeline_raw_trivial_once_module() -> Module {
  Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_global_sec(
    @lib.GlobalSec::new([
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::i32(), true),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32::new(0))]),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [@lib.Instruction::return_()],
            None,
          ),
          @lib.Instruction::i32_const(@lib.I32::new(1)),
          @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
        ]),
      ),
    ]),
  )
  .with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::from_string("run"),
        @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
      ),
    ]),
  )
}

///|
fn generated_pipeline_raw_memory_module() -> Module {
  Module::new()
  .with_mem_sec(
    @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
  )
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32::new(100)),
          @lib.Instruction::i32_const(@lib.I32::new(0)),
          @lib.Instruction::i32_const(@lib.I32::new(25)),
          @lib.Instruction::memory_init(
            @lib.DataIdx::new(0U),
            @lib.MemIdx::new(0U),
          ),
          @lib.Instruction::data_drop(@lib.DataIdx::new(0U)),
        ]),
      ),
    ]),
  )
  .with_data_sec(
    @lib.DataSec::new([
      @lib.Data::new(
        @lib.DataMode::passive(),
        b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00HELLO\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
      ),
    ]),
  )
  .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32::new(1U)))
  .with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::from_string("run"),
        @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
      ),
    ]),
  )
}

///|
fn generated_pipeline_raw_dead_branch_drop_module() -> Module {
  Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::val_type(@lib.ValType::i32()),
            @lib.Expr::new([
              @lib.Instruction::block(
                @lib.BlockType::void_(),
                @lib.Expr::new([
                  @lib.Instruction::i32_const(@lib.I32::new(1)),
                  @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                  @lib.Instruction::drop(),
                ]),
              ),
              @lib.Instruction::i32_const(@lib.I32::new(0)),
            ]),
          ),
          @lib.Instruction::drop(),
        ]),
      ),
    ]),
  )
}

///|
fn generated_pipeline_raw_remove_unused_names_module() -> Module {
  Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::void_(),
            @lib.Expr::new([
              @lib.Instruction::block(
                @lib.BlockType::void_(),
                @lib.Expr::new([@lib.Instruction::nop()]),
              ),
            ]),
          ),
        ]),
      ),
    ]),
  )
}

///|
fn generated_pipeline_dead_branch_drop_lowered(optimized : Module) -> Bool {
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.TFunc(_, _, body)])) => {
      let @lib.Expr(raw_instrs) = body.to_expr()
      match raw_instrs {
        [
          @lib.Block(
            @lib.ValTypeBlockType(@lib.NumTypeValType(@lib.I32NumType)),
            @lib.Expr(
              [
                @lib.Block(
                  @lib.VoidBlockType,
                  @lib.Expr(
                    [@lib.I32Const(@lib.I32(1)), @lib.Br(@lib.LabelIdx(1U))]
                  )
                ),
                @lib.I32Const(@lib.I32(0)),
              ]
            )
          ),
          @lib.Drop,
        ] => true
        _ => false
      }
    }
    _ => false
  }
}

///|
test "run_generated_pipeline_with_options passes PipelineFeatures to module-wide entries" {
  let mut saw_has_gc = false
  let mut saw_has_multivalue = false
  let mut saw_closed_world = false
  let mut saw_low_memory_unused = false
  let mut saw_traps_never_happen = false
  let mut saw_zero_filled_memory = false
  let pipeline = [
    PipelineEntry::new(
      [],
      PassGroup::new(
        PassKind::module_wide(fn(mod, global, features) {
          saw_has_gc = features.has_gc
          saw_has_multivalue = features.has_multivalue
          saw_closed_world = features.closed_world
          saw_low_memory_unused = features.low_memory_unused
          saw_traps_never_happen = features.traps_never_happen
          saw_zero_filled_memory = features.zero_filled_memory
          (mod, global)
        }),
        ValidationKind::unchecked(),
      ),
    ),
  ]
  let options = OptimizeOptions::new(
    low_memory_unused=true,
    closed_world=true,
    traps_never_happen=true,
    zero_filled_memory=true,
  )
  let mod = Module::new().with_type_sec(generated_pipeline_test_type_sec())
  match run_generated_pipeline_with_options(mod, pipeline, options) {
    Ok(_) => ()
    Err(e) => fail("expected generated pipeline execution success: \{e}")
  }
  assert_true(saw_has_gc)
  assert_true(saw_has_multivalue)
  assert_true(saw_closed_world)
  assert_true(saw_low_memory_unused)
  assert_true(saw_traps_never_happen)
  assert_true(saw_zero_filled_memory)
}

///|
test "run_generated_pipeline_with_options keeps gc and multivalue disabled for plain funcref modules" {
  let mut saw_has_gc = true
  let mut saw_has_multivalue = true
  let pipeline = [
    PipelineEntry::new(
      [],
      PassGroup::new(
        PassKind::module_wide(fn(mod, global, features) {
          saw_has_gc = features.has_gc
          saw_has_multivalue = features.has_multivalue
          (mod, global)
        }),
        ValidationKind::unchecked(),
      ),
    ),
  ]
  let mod = Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            @lib.RefType::new(
              true,
              @lib.HeapType::abs(@lib.AbsHeapType::func()),
            ),
            @lib.Limits::i32(1U, None),
          ),
          None,
        ),
      ]),
    )
  match
    run_generated_pipeline_with_options(mod, pipeline, OptimizeOptions::new()) {
    Ok(_) => ()
    Err(e) => fail("expected generated pipeline execution success: \{e}")
  }
  assert_true(!saw_has_gc)
  assert_true(!saw_has_multivalue)
}

///|
test "run_generated_pipeline_with_options pre-lifts raw funcs before any pipeline entry runs" {
  let mod = generated_pipeline_raw_once_module()
  let optimized = match
    run_generated_pipeline_with_options(mod, [], OptimizeOptions::new()) {
    Ok(v) => v
    Err(e) => fail("expected generated pipeline success: \{e}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.TFunc(_, _, _), @lib.TFunc(_, _, _)])) => ()
    _ => fail("expected generated pipeline to pre-lift raw funcs before passes")
  }
}

///|
test "run_generated_pipeline_with_options pre-lifts raw funcs before once reduction in the first four passes" {
  let mod = generated_pipeline_raw_once_module()
  let optimized = match
    run_generated_pipeline_with_options(
      mod,
      generated_pipeline_first_four(mod),
      OptimizeOptions::new(optimize_level=2),
    ) {
    Ok(v) => v
    Err(e) => fail("expected generated pipeline success: \{e}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.TFunc(_, _, _), @lib.TFunc(_, _, body)])) =>
      match body.inner()[1].kind {
        @lib.TNop => ()
        _ => fail("expected second once call to be removed after pre-lift")
      }
    _ => fail("expected generated pipeline to pre-lift raw funcs")
  }
}

///|
test "run_generated_pipeline_with_options pre-lifts raw funcs before memory packing in the first four passes" {
  let mod = generated_pipeline_raw_memory_module()
  let optimized = match
    run_generated_pipeline_with_options(
      mod,
      generated_pipeline_first_four(mod),
      OptimizeOptions::new(optimize_level=2),
    ) {
    Ok(v) => v
    Err(e) => fail("expected generated pipeline success: \{e}")
  }
  match optimized.data_sec {
    Some(@lib.DataSec([@lib.Data(@lib.Passive, bytes)])) =>
      assert_eq(bytes, b"HELLO")
    _ => fail("expected packed passive payload after pre-lift")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.TFunc(_, _, _)])) => ()
    _ => fail("expected generated pipeline to pre-lift raw funcs")
  }
}

///|
test "run_generated_pipeline_with_options pre-lift truncates dead raw branch-tail drops before any pass" {
  let mod = generated_pipeline_raw_dead_branch_drop_module()
  let optimized = match
    run_generated_pipeline_with_options(mod, [], OptimizeOptions::new()) {
    Ok(v) => v
    Err(e) => fail("expected generated pipeline success: \{e}")
  }
  if !generated_pipeline_dead_branch_drop_lowered(optimized) {
    fail("unexpected lowered body shape after generated pre-lift")
  }
}

///|
test "run_generated_pipeline_with_options dead code elimination drops dead raw branch-tail drops" {
  let mod = generated_pipeline_raw_dead_branch_drop_module()
  let pipeline = cmd_generated_pipeline_from_flags(
    mod,
    ["dead-code-elimination"],
    OptimizeOptions::new(),
  )
  let optimized = match
    run_generated_pipeline_with_options(mod, pipeline, OptimizeOptions::new()) {
    Ok(v) => v
    Err(e) => fail("expected generated DCE pipeline success: \{e}")
  }
  if !generated_pipeline_dead_branch_drop_lowered(optimized) {
    fail("unexpected lowered body shape after DCE")
  }
}

///|
test "run_generated_pipeline_with_options remove unused names rewrites generated-path candidates" {
  let mod = generated_pipeline_raw_remove_unused_names_module()
  let pipeline = cmd_generated_pipeline_from_flags(
    mod,
    ["remove-unused-names"],
    OptimizeOptions::new(),
  )
  let optimized = match
    run_generated_pipeline_with_options(mod, pipeline, OptimizeOptions::new()) {
    Ok(v) => v
    Err(e) =>
      fail("expected generated remove unused names pipeline success: \{e}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.TFunc(_, _, body)])) =>
      match body.inner() {
        [instr] =>
          match instr.kind {
            @lib.TBlock(@lib.VoidBlockType, child_body) =>
              match child_body.inner() {
                [child] =>
                  match child.kind {
                    @lib.TNop => ()
                    _ =>
                      fail(
                        "expected generated remove unused names to keep a peeled nop body",
                      )
                  }
                _ => fail("expected single peeled child")
              }
            _ => fail("expected generated remove unused names to peel blocks")
          }
        _ => fail("expected single rewritten block")
      }
    _ => fail("expected generated pipeline to pre-lift and optimize raw funcs")
  }
}

///|
test "run_generated_pipeline_with_options keeps Starshine's smaller trivial once body in the first four passes" {
  let mod = generated_pipeline_raw_trivial_once_module()
  let optimized = match
    run_generated_pipeline_with_options(
      mod,
      generated_pipeline_first_four(mod),
      OptimizeOptions::new(optimize_level=2),
    ) {
    Ok(v) => v
    Err(e) => fail("expected generated pipeline success: \{e}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.TFunc(_, _, body)])) =>
      match body.inner() {
        [instr] =>
          match instr.kind {
            @lib.TNop => ()
            _ => fail("expected trivial once body to collapse to nop")
          }
        _ => fail("expected trivial once body to contain one instruction")
      }
    _ => fail("expected generated pipeline to pre-lift raw funcs")
  }
}

///|
test "cmd_generated_pipeline_from_flags expands default optimize pipeline with module-derived gc and multivalue features" {
  let pipeline = cmd_generated_pipeline_from_flags(
    Module::new().with_type_sec(generated_pipeline_test_type_sec()),
    ["optimize"],
    OptimizeOptions::new(optimize_level=3, closed_world=true),
  )
  let passes : Array[OptimizePass] = []
  for entry in pipeline {
    for pass in entry.passes {
      passes.push(pass)
    }
  }
  assert_true(passes.contains(OptimizePass::TypeRefining))
  assert_true(passes.contains(OptimizePass::TupleOptimization))
}

///|
test "cmd_generated_pipeline_from_flags includes explicit no-dwarf prepasses on the generated path" {
  let pipeline = cmd_generated_pipeline_from_flags(
    Module::new(),
    [
      "duplicate-function-elimination", "remove-unused-module-elements", "memory-packing",
      "once-reduction", "dead-code-elimination", "remove-unused-names",
    ],
    OptimizeOptions::new(optimize_level=2),
  )
  let passes : Array[OptimizePass] = []
  for entry in pipeline {
    for pass in entry.passes {
      passes.push(pass)
    }
  }
  assert_eq(passes, [
    OptimizePass::DuplicateFunctionElimination,
    OptimizePass::RemoveUnusedModuleElements,
    OptimizePass::MemoryPacking,
    OptimizePass::OnceReduction,
    OptimizePass::DeadCodeElimination,
    OptimizePass::RemoveUnusedNames,
  ])
}

///|
test "run_generated_pipeline_with_options passes string features to module-wide entries" {
  let mut saw_has_strings = false
  let pipeline = [
    PipelineEntry::new(
      [],
      PassGroup::new(
        PassKind::module_wide(fn(mod, global, features) {
          saw_has_strings = features.has_strings
          (mod, global)
        }),
        ValidationKind::unchecked(),
      ),
    ),
  ]
  let mod = Module::new().with_global_sec(
    @lib.GlobalSec::new([
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::stringref(), false),
        @lib.Expr::new([
          @lib.Instruction::ref_null(
            @lib.HeapType::abs(@lib.AbsHeapType::string_()),
          ),
        ]),
      ),
    ]),
  )
  match
    run_generated_pipeline_with_options(mod, pipeline, OptimizeOptions::new()) {
    Ok(_) => ()
    Err(e) =>
      fail("expected generated pipeline string feature fixture success: \{e}")
  }
  assert_true(saw_has_strings)
}
