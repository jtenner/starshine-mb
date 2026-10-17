///| The exact source was retained immediately before this call. Only the

///|
/// audited result constructor can keep its no-callback validation lifetime.
fn dae_numeric_result_validation_retain_report(
  chain : DaeScalarValidationChain?,
  result : DaePassResult,
  report : DaeCoreResultApplication,
) -> Unit {
  match chain {
    Some(chain) if chain.no_callback is Some(_) &&
      chain.numeric_result_source &&
      result.changed &&
      report.applied &&
      report.changed &&
      report.primary_def == result.primary_def &&
      physical_equal(report.mod_out, result.mod_out) &&
      dae_work_family_for_commit_effects(report.effects, report.primary_def) ==
      DaeDroppedResultWork =>
      match chain.checked_source {
        Some(checked) if physical_equal(checked, result.mod_out) => return
        _ => ()
      }
    _ => ()
  }
  // Scalar, GC, cleanup, failed, wrapped and callback-bearing reports keep
  // the old barrier. Neither report effects nor physical fields mint a proof.
  dae_scalar_validation_barrier_opt(chain)
}
