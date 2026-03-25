///|
pub fn pass_test_module_from_wat(text : String) -> @lib.Module {
  let mod_ = match
    @wast.wast_to_binary_module(text, filename="passes-test.wat") {
    Ok(mod_) => mod_
    Err(err) => abort("unexpected test fixture parse failure: \{err}")
  }
  match @validate.validate_module(mod_) {
    Ok(_) => mod_
    Err(err) => abort("unexpected invalid pass test fixture: \{err}")
  }
}

///|
pub fn pass_test_lift_first_func(text : String) -> @ir.HotFunc {
  let func = @ir.hot_lift_func(
    pass_test_module_from_wat(text),
    @lib.FuncIdx::new(0U),
  )
  match
    pipeline_verify_checkpoint(
      HotPipelineVerifyPolicy::after_each_pass(),
      "verify lifted test fixture",
      HotPipelineVerifyTarget::HotFuncTarget(func),
    ) {
    Ok(_) => func
    Err(err) =>
      abort("unexpected lifted test fixture verification failure: \{err}")
  }
}

///|
pub fn pass_test_run_pipeline(
  text : String,
  requested_passes : Array[String],
  options? : HotPipelineOptions = HotPipelineOptions::new(),
) -> Result[@lib.Module, String] {
  run_hot_pipeline(pass_test_module_from_wat(text), options, requested_passes)
}
