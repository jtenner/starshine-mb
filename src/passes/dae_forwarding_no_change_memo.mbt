///| One effect frontier owns this memo. Only negative forwarding outcomes can

///|
/// be stored; every commit must discard them before any follow-up work.
priv struct DaeForwardingNoChangeMemo {
  entries : @hashmap.HashMap[Int32, Array[Int32]]
  mut context : DaeForwardingNoChangeContext?
}

///|
priv struct DaeForwardingNoChangeContext {
  original : DaeOriginalBoundarySnapshot
  source : @lib.Module
  snapshot : DaeModuleBoundarySnapshot
  dependencies : DaeBoundaryDependencyGraph
  touched : Array[Bool]
  changed : Bool
  module_epoch : Int32
  call_epoch : Int32
  type_epoch : Int32
  function_epochs : Array[(Int32, Int32)]
}

///|
fn DaeForwardingNoChangeMemo::new() -> DaeForwardingNoChangeMemo {
  { entries: @hashmap.new(), context: None, }
}

///|
fn DaeForwardingNoChangeMemo::invalidate(
  self : DaeForwardingNoChangeMemo,
) -> Unit {
  self.entries.clear()
  self.context = None
}

///|
fn dae_forwarding_no_change_context_matches(
  context : DaeForwardingNoChangeContext,
  original : DaeOriginalBoundarySnapshot,
  current : @lib.Module,
  touched : Array[Bool],
  changed : Bool,
  graph : DaeCurrentBoundaryGraph,
  dependencies : DaeBoundaryDependencyGraph,
) -> Bool {
  if !physical_equal(context.original, original) ||
    !physical_equal(context.source, current) ||
    !physical_equal(context.snapshot, graph.snapshot) ||
    !physical_equal(context.dependencies, dependencies) ||
    context.touched != touched ||
    context.changed != changed ||
    context.module_epoch != graph.module_epoch ||
    context.call_epoch != graph.call_epoch ||
    context.type_epoch != graph.type_epoch ||
    context.function_epochs.length() != graph.function_epochs.length() {
    return false
  }
  for def_idx in 0..<graph.function_epochs.length() {
    let epochs = graph.function_epochs[def_idx]
    if context.function_epochs[def_idx] !=
      (epochs.signature_epoch, epochs.body_epoch) {
      return false
    }
  }
  true
}

///|
fn dae_process_forwarding_work_item_with_memo(
  original : DaeOriginalBoundarySnapshot,
  current : @lib.Module,
  touched : Array[Bool],
  changed : Bool,
  graph : DaeCurrentBoundaryGraph,
  dependencies : DaeBoundaryDependencyGraph,
  item : DaeWorkItem,
  diagnostics : DaeDiagnostics,
  memo : DaeForwardingNoChangeMemo,
  analysis_attempts~ : Array[Int32]? = None,
) -> DaeWorkOutcome {
  // Forwarding currently reads the complete component and frontier context;
  // it does not read uniform-value options. Nondefault items use the full path
  // so a future option extension cannot silently reuse an older proof.
  let cacheable = item.family == DaeForwardingWork &&
    item.component_id >= 0 &&
    !item.component_members.is_empty() &&
    item.uniform_values.is_empty() &&
    !item.allow_immutable_global_get &&
    !item.allow_immediate_i32_suffix_fallback &&
    physical_equal(graph.mod_, current) &&
    dae_work_item_epoch_is_current(graph, item)
  if cacheable {
    let context_current = match memo.context {
      Some(context) =>
        dae_forwarding_no_change_context_matches(
          context, original, current, touched, changed, graph, dependencies,
        )
      None => false
    }
    if !context_current {
      memo.invalidate()
      memo.context = Some({
        original,
        source: current,
        snapshot: graph.snapshot,
        dependencies,
        touched: touched.copy(),
        changed,
        module_epoch: graph.module_epoch,
        call_epoch: graph.call_epoch,
        type_epoch: graph.type_epoch,
        function_epochs: graph.function_epochs.map(fn(epochs) {
          (epochs.signature_epoch, epochs.body_epoch)
        }),
      })
    }
    match memo.entries.get(item.component_id) {
      Some(members) if members == item.component_members => {
        // Each target still owns its queue item and diagnostics. A negative
        // proof supplies no candidate, primary definition, or reused counters.
        diagnostics.boundaries_analyzed += 1
        dae_diagnostics_record_reason(diagnostics, DaeNoStrictImprovement)
        return DaeWorkNoChange(DaeNoStrictImprovement)
      }
      _ => ()
    }
  }
  match analysis_attempts {
    Some(count) if !count.is_empty() => count[0] += 1
    _ => ()
  }
  let outcome = dae_process_work_item(
    original, current, touched, changed, graph, dependencies, item, diagnostics,
  )
  match outcome {
    DaeWorkNoChange(DaeNoStrictImprovement) if cacheable =>
      match memo.context {
        Some(context) if dae_forwarding_no_change_context_matches(
            context, original, current, touched, changed, graph, dependencies,
          ) =>
          memo.entries.set(item.component_id, item.component_members.copy())
        _ => ()
      }
    // Every caller uses this rule, including direct tests and successful
    // fallback transactions, before any later work can query the memo.
    DaeWorkCommitted(_) => memo.invalidate()
    _ => ()
  }
  outcome
}
