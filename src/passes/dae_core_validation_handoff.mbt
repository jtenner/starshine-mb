///|
priv struct DaeNoCallbackTrace {
  callback : (String) -> Unit
}

///|
fn hot_pipeline_dae_no_callback_trace(
  options : HotPipelineOptions,
) -> DaeNoCallbackTrace? {
  match options.dae_default_no_callback_trace {
    Some(proof) if options.perf is None &&
      physical_equal(options.trace, proof.callback) => Some(proof)
    _ => None
  }
}

///|
fn dae_process_core_precomputed_signature_with_report(
  original : DaeOriginalBoundarySnapshot,
  current : @lib.Module,
  touched : Array[Bool],
  changed : Bool,
  graph : DaeCurrentBoundaryGraph,
  item : DaeWorkItem,
  candidate : DaePassResult,
  effects : DaeCommitEffects,
  trace : (String) -> Unit,
  no_callback : DaeNoCallbackTrace?,
  checked_report : Array[(@lib.Module, @lib.Module)],
  rewrite_validation_counts~ : Array[Int32]? = None,
) -> DaeWorkOutcome {
  // The certificate refers to the constructor's private no-op value. Replacing
  // the public callback in a package-internal options copy invalidates it.
  let checked_candidate = match no_callback {
    Some(proof) if physical_equal(trace, proof.callback) =>
      checked_report.get(0)
    _ => None
  }
  dae_process_precomputed_signature_work_item(
    original,
    current,
    touched,
    changed,
    graph,
    item,
    candidate,
    effects,
    checked_candidate~,
    rewrite_validation_counts~,
  )
}
