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
test "run_generated_pipeline_with_options passes PipelineFeatures to module-wide entries" {
  let mut saw_has_gc = false
  let mut saw_has_multivalue = false
  let mut saw_closed_world = false
  let mut saw_low_memory_unused = false
  let mut saw_traps_never_happen = false
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
