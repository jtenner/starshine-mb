///|
/// Run the active registry on a module for WasmGC JavaScript consumers.
pub fn optimize_module(
  module_ : @lib.Module,
  pass_names : Array[String],
  optimize_level? : Int = 2,
  shrink_level? : Int = 0,
) -> Result[@lib.Module, String] {
  @passes.run_hot_pipeline(
    module_,
    @passes.HotPipelineOptions::new(optimize_level~, shrink_level~),
    pass_names,
  )
}
