///|
fn strip_debug_test_fixture() -> @lib.Module {
  @lib.Module::new(
    custom_secs=[
      @lib.CustomSec::new(
        @lib.Name::from_string("producers"),
        b"producer-metadata",
      ),
      @lib.CustomSec::new(@lib.Name::from_string("profile"), b"keep-me"),
    ],
    type_sec=Some(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    ),
    func_sec=Some(@lib.FuncSec::new([@lib.TypeIdx::new(0U)])),
    export_sec=Some(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("run"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
        ),
      ]),
    ),
    code_sec=Some(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    ),
  )
  .with_name_sec(
    @lib.NameSec::new(
      module_name=Some(@lib.Name::from_string("fixture")),
      func_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(0U, @lib.Name::from_string("run")),
        ]),
      ),
    ),
  )
  .with_raw_name_sec_payload(b"raw-name")
}

///|
fn input_custom_secs() -> Array[@lib.CustomSec] {
  [
    @lib.CustomSec::new(
      @lib.Name::from_string("producers"),
      b"producer-metadata",
    ),
    @lib.CustomSec::new(@lib.Name::from_string("profile"), b"keep-me"),
  ]
}

///|
test "strip-debug registers as a module pass" {
  @debug.assert_eq(
    pass_registry_category("strip-debug"),
    Some(HotPassRegistryCategory::module_pass()),
  )
}

///|
test "strip-debug drops names but preserves non-name custom sections and semantics" {
  let optimized = match
    run_hot_pipeline(strip_debug_test_fixture(), HotPipelineOptions::new(), [
      "strip-debug",
    ]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected strip-debug pipeline success, got \{err}")
  }

  @debug.assert_eq(optimized.custom_secs, input_custom_secs())
  @debug.assert_eq(optimized.name_sec, None)
  @debug.assert_eq(optimized.raw_name_sec_payload, None)
  assert_true(optimized.type_sec is Some(_))
  assert_true(optimized.func_sec is Some(_))
  assert_true(optimized.export_sec is Some(_))
  assert_true(optimized.code_sec is Some(_))
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected strip-debug output to validate, got \{err}")
  }
}

///|
test "strip-debug leaves modules without debug custom sections unchanged" {
  let input = @lib.Module::new(
    type_sec=Some(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    ),
    func_sec=Some(@lib.FuncSec::new([@lib.TypeIdx::new(0U)])),
    code_sec=Some(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["strip-debug"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected strip-debug no-op success, got \{err}")
  }
  @debug.assert_eq(optimized, input)
}
