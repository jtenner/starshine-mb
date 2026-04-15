///|
pub fn passes_perf_long_import_usage() -> Unit {
  ignore(@lib.FuncIdx::new(0U))
  ignore(@passes.HotPerfDumpOptions::new())
  ignore(@passes.HotPipelineOptions::new())
  let trace = fn(_ : String) { () }
  ignore(
    @passes.HotPerfSession::new(
      trace~,
      dump_options=@passes.HotPerfDumpOptions::new(),
    ),
  )
}
