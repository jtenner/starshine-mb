///|
test "run_generated_pipeline_with_options passes PipelineFeatures to module-wide entries" {
  let mut saw_low_memory_unused = false
  let pipeline = [
    PipelineEntry::new(
      [],
      PassGroup::new(
        PassKind::module_wide(fn(mod, global, features) {
          saw_low_memory_unused = features.low_memory_unused
          (mod, global)
        }),
        ValidationKind::unchecked(),
      ),
    ),
  ]
  let options = OptimizeOptions::new(low_memory_unused=true)
  match run_generated_pipeline_with_options(Module::new(), pipeline, options) {
    Ok(_) => ()
    Err(e) => fail("expected generated pipeline execution success: \{e}")
  }
  assert_true(saw_low_memory_unused)
}
