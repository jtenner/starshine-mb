///|
fn rume_branch_hint_annotation_fixture() -> @lib.Module {
  rume_perf_direct_type_root_fixture(2, 2)
  .with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::from_string("live"),
        @lib.ExternIdx::func(@lib.FuncIdx::new(1U)),
      ),
    ]),
  )
  .with_func_annotation_sec(
    @lib.FuncAnnotationSec::new([
      @lib.FuncAnnotationAssoc::new(0U, [
        @lib.FuncAnnotation::new("metadata.code.branch_hint", args=["dead"]),
      ]),
      @lib.FuncAnnotationAssoc::new(1U, [
        @lib.FuncAnnotation::new("metadata.code.branch_hint", args=["\"\\01\""]),
        @lib.FuncAnnotation::new("keep.annotation", args=["live"]),
      ]),
    ]),
  )
}

///|
test "RUME remaps structured branch-hint annotations with surviving functions" {
  let optimized = rume_run_module_pass(rume_branch_hint_annotation_fixture())
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => @debug.assert_eq(funcs.length(), 1)
    None => fail("expected the exported function to survive")
  }
  @debug.assert_eq(
    optimized.export_sec,
    Some(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("live"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
        ),
      ]),
    ),
  )
  @debug.assert_eq(
    optimized.func_annotation_sec,
    Some(
      @lib.FuncAnnotationSec::new([
        @lib.FuncAnnotationAssoc::new(0U, [
          @lib.FuncAnnotation::new("metadata.code.branch_hint", args=[
            "\"\\01\"",
          ]),
          @lib.FuncAnnotation::new("keep.annotation", args=["live"]),
        ]),
      ]),
    ),
  )
}

///|
test "RUME preserves raw branch hints and debug offsets despite structured annotations" {
  // These opaque custom sections cannot be remapped like FuncAnnotationSec.
  for section_name in ["metadata.code.branch_hint", ".debug_info"] {
    let input = rume_branch_hint_annotation_fixture().with_custom_secs([
      @lib.CustomSec::new(
        @lib.Name::from_string(section_name),
        b"opaque-code-offsets",
      ),
    ])
    @debug.assert_eq(rume_run_module_pass(input), input)
  }
}
