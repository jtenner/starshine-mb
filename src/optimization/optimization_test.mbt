///|
test "pipeline global defaults are stable" {
  let global = PipelineGlobal::new()
  assert_eq(global.opt_level, 0)
  assert_eq(global.shrink_level, 0)
  assert_eq(global.validate, false)
  assert_eq(global.trace, TraceLevel::silent())
  assert_eq(global.max_iterations, 1)
}

///|
test "pipeline scratch defaults are empty" {
  let scratch = PipelineScratch::new()
  assert_eq(scratch.changed, false)
  assert_eq(scratch.func_idx, None)
  assert_eq(scratch.funcs_visited, 0)
  assert_eq(scratch.funcs_changed, 0)
  assert_eq(scratch.module_shape_changed, false)
  assert_eq(scratch.call_graph_dirty, false)
  assert_eq(scratch.locals_dirty, false)
}

///|
test "pass kinds accept starter function shapes" {
  let early : EarlyPassFn = fn(mod, global) { (mod, global) }
  let module_wide : ModuleWidePassFn = fn(mod, global) { (mod, global) }
  let func_local : FuncLocalPassFn = fn(mod, scratch) { (mod, scratch) }
  let kinds = [
    PassKind::early(early),
    PassKind::func_local_group([func_local]),
    PassKind::module_wide(module_wide),
  ]
  match kinds[0] {
    Early(_) => ()
    _ => fail("expected early pass kind")
  }
  match kinds[1] {
    FuncLocalGroup(funcs) => assert_eq(funcs.length(), 1)
    _ => fail("expected func-local pass kind")
  }
  match kinds[2] {
    ModuleWide(_) => ()
    _ => fail("expected module-wide pass kind")
  }
}

///|
test "pass group pairs a kind with a validation level" {
  let group = PassGroup::new(
    PassKind::module_wide(fn(mod, global) { (mod, global) }),
    ValidationKind::full(),
  )
  assert_eq(group.validation_kind(), ValidationKind::full())
  match group.kind() {
    ModuleWide(_) => ()
    _ => fail("expected module-wide group")
  }
}

///|
test "binaryen pass inventory includes representative entries" {
  let passes = all_binaryen_passes()
  assert_eq(passes.length(), 120)
  assert_eq(passes[0], BinaryenPass::AbstractTypeRefining)
  assert_true(passes.contains(BinaryenPass::Asyncify))
  assert_true(passes.contains(BinaryenPass::DWARF))
  assert_true(passes.contains(BinaryenPass::DataFlowOpts))
  assert_true(passes.contains(BinaryenPass::TrapMode))
  assert_true(passes.contains(BinaryenPass::Vacuum))
  assert_eq(passes[passes.length() - 1], BinaryenPass::Vacuum)
}

///|
test "add pass to pipeline groups adjacent function passes" {
  let pipeline : Array[PipelineEntry] = []
  add_pass_to_pipeline(pipeline, OptimizePass::DeadCodeElimination)
  add_pass_to_pipeline(pipeline, OptimizePass::RemoveUnusedNames)
  add_pass_to_pipeline(pipeline, OptimizePass::Directize)

  assert_eq(pipeline.length(), 2)
  assert_eq(pipeline[0].passes, [
    OptimizePass::DeadCodeElimination,
    OptimizePass::RemoveUnusedNames,
  ])
  match pipeline[0].group.kind() {
    FuncLocalGroup(funcs) => assert_eq(funcs.length(), 2)
    _ => fail("expected first pipeline entry to be a function group")
  }
  assert_eq(pipeline[1].passes, [OptimizePass::Directize])
  match pipeline[1].group.kind() {
    ModuleWide(_) => ()
    _ => fail("expected directize to start a new module-wide group")
  }
}

///|
test "default optimize pipeline groups function passes between global stages" {
  let pipeline = default_optimize_pipeline(
    PipelineGlobal::new(opt_level=2, validate=true),
  )

  assert_eq(pipeline[0].passes, [OptimizePass::DuplicateFunctionElimination])
  assert_eq(pipeline[1].passes, [OptimizePass::RemoveUnusedModuleElements])
  assert_eq(pipeline[2].passes, [OptimizePass::MemoryPacking])
  assert_eq(pipeline[3].passes, [OptimizePass::OnceReduction])
  assert_true(pipeline[4].passes.contains(OptimizePass::DeadCodeElimination))
  assert_true(pipeline[4].passes.contains(OptimizePass::Vacuum))
  assert_true(
    pipeline[4].passes.contains(OptimizePass::RedundantSetElimination),
  )
  assert_eq(pipeline[4].group.validation_kind(), ValidationKind::full())
  match pipeline[4].group.kind() {
    FuncLocalGroup(funcs) =>
      assert_eq(funcs.length(), pipeline[4].passes.length())
    _ => fail("expected grouped function pipeline stage")
  }
  assert_eq(pipeline[pipeline.length() - 1].passes, [OptimizePass::Directize])
}

///|
test "default optimize pipeline includes closed-world gc prepasses when enabled" {
  let pipeline = default_optimize_pipeline(
    PipelineGlobal::new(opt_level=3),
    features=PipelineFeatures::new(has_gc=true, closed_world=true),
  )

  let gc_prepasses = [
    OptimizePass::TypeRefining,
    OptimizePass::SignaturePruning,
    OptimizePass::SignatureRefining,
    OptimizePass::GlobalRefining,
    OptimizePass::GlobalTypeOptimization,
    OptimizePass::RemoveUnusedModuleElements,
    OptimizePass::RemoveUnusedTypes,
    OptimizePass::ConstantFieldPropagationRefTest,
    OptimizePass::GlobalStructInference,
    OptimizePass::AbstractTypeRefining,
    OptimizePass::Unsubtyping,
  ]
  for pass in gc_prepasses {
    let mut found = false
    for group in pipeline {
      if group.passes.contains(pass) {
        found = true
      }
    }
    assert_true(found)
  }
}
