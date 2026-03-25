///|
pub fn dead_code_elimination_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new(
    "dead-code-elimination",
    requires=[@ir.HotAnalysis::use_def(), @ir.HotAnalysis::effects()],
    invalidates=[
      @ir.HotAnalysis::cfg(),
      @ir.HotAnalysis::dominance(),
      @ir.HotAnalysis::liveness(),
      @ir.HotAnalysis::use_def(),
      @ir.HotAnalysis::effects(),
      @ir.HotAnalysis::loop_info(),
      @ir.HotAnalysis::ssa(),
    ],
  )
}

///|
pub fn dead_code_elimination_summary() -> String {
  "Batch 1 placeholder for detached dead-node cleanup and trivial unreachable pruning."
}
