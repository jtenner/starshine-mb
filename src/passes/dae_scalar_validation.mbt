///|
priv struct DaeScalarValidationChain {
  no_callback : DaeNoCallbackTrace?
  mut checked_source : @lib.Module?
  mut syntax_index : DaeScalarSyntaxIndex?
  mut numeric_result_source : Bool
}

///|
priv struct DaeScalarValidationWork {
  mut full_gates : Int32
  mut full_bodies : Int32
  mut partial_bodies : Int32
  mut offered : Int32
  mut matched_sources : Int32
  mut envelope_matches : Int32
  mut index_builds : Int32
  mut partial_gates : Int32
  mut full_errors : Int32
  mut removed_dependencies : Int32
  mut reverse_comparisons : Int32
}

///|
fn DaeScalarValidationWork::new() -> DaeScalarValidationWork {
  {
    full_gates: 0,
    full_bodies: 0,
    partial_bodies: 0,
    offered: 0,
    matched_sources: 0,
    envelope_matches: 0,
    index_builds: 0,
    partial_gates: 0,
    full_errors: 0,
    removed_dependencies: 0,
    reverse_comparisons: 0,
  }
}

///|
fn dae_scalar_validation_chain_new(
  trace : (String) -> Unit,
  perf : HotPerfSession?,
  no_callback : DaeNoCallbackTrace?,
) -> DaeScalarValidationChain {
  let no_callback = match no_callback {
    Some(proof) if perf is None && physical_equal(trace, proof.callback) =>
      Some(proof)
    _ => None
  }
  {
    no_callback,
    checked_source: None,
    syntax_index: None,
    numeric_result_source: false,
  }
}

///|
fn dae_scalar_validation_barrier(chain : DaeScalarValidationChain) -> Unit {
  chain.checked_source = None
  chain.numeric_result_source = false
  chain.syntax_index = None
}

///|
fn dae_scalar_validation_check_candidate(
  chain : DaeScalarValidationChain,
  source : @lib.Module,
  candidate : @lib.Module,
  work~ : DaeScalarValidationWork? = None,
  allow_numeric_result_removal~ : Bool = false,
) -> Result[Unit, @validate.ValidationError] {
  match work {
    Some(counts) => counts.offered += 1
    None => ()
  }
  if dae_scalar_validation_try_partial(
      chain,
      source,
      candidate,
      work~,
      allow_numeric_result_removal~,
    ) {
    match work {
      Some(counts) => counts.partial_gates += 1
      None => ()
    }
    return Ok(())
  }
  // Drop the old index before the full gate to limit peak live memory.
  dae_scalar_validation_barrier(chain)
  // Every uncertainty and partial error uses the original whole-module gate.
  let result = match work {
    None => @validate.validate_module(candidate)
    Some(counts) => {
      counts.full_gates += 1
      // Count the real full-validator body entries, including early failure.
      // The private recorder has no access to the module or user callbacks.
      @validate.validate_module_with_trace(
        candidate,
        fn(line) {
          if line.has_prefix("func[") && line.contains("] start locals=") {
            counts.full_bodies += 1
          }
        },
        trace_all_funcs=true,
      )
    }
  }
  match result {
    Ok(_) => {
      // A full success begins a new source lifetime. Never keep old rows.
      chain.syntax_index = None
      chain.checked_source = match chain.no_callback {
        Some(_) => Some(candidate)
        None => None
      }
      chain.numeric_result_source = allow_numeric_result_removal &&
        chain.checked_source is Some(_)
      Ok(())
    }
    Err(error) => {
      match work {
        Some(counts) => counts.full_errors += 1
        None => ()
      }
      dae_scalar_validation_barrier(chain)
      Err(error)
    }
  }
}

///|
/// The first tier admits only numeric/vector removal and literal materialization.
fn dae_scalar_numeric_literal(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.I32Const(_)
    | @lib.I64Const(_)
    | @lib.F32Const(_)
    | @lib.F64Const(_)
    | @lib.V128Const(_) => true
    _ => false
  }
}

///|
/// Check before a non-numeric builder can run; RefFunc is deliberately excluded.
fn dae_scalar_numeric_materialization(
  values : Array[@lib.Instruction?],
) -> Bool {
  let mut any = false
  for value in values {
    match value {
      Some(value) => {
        if !dae_scalar_numeric_literal(value) {
          return false
        }
        any = true
      }
      None => ()
    }
  }
  any
}

///|
/// The actual plan actions must agree with the audited numeric producer.
fn dae_scalar_numeric_plan(plan : DaeRewritePlan) -> Bool {
  let mut any = false
  for action in plan.parameter_actions {
    match action {
      DaeKeepParameter => ()
      DaeMaterializeConstantParameter(value) => {
        if !dae_scalar_numeric_literal(value) {
          return false
        }
        any = true
      }
      _ => return false
    }
  }
  any &&
  plan.result_actions.all(fn(action) { action == DaeKeepResult }) &&
  !plan.effects.caller_drop_removed.any(fn(value) { value })
}

///|
/// All fields are checked independently of producer touch/effect masks.
fn dae_scalar_validation_envelope(
  source : @lib.Module,
  candidate : @lib.Module,
) -> Bool {
  if source.name_sec is Some(_) ||
    candidate.name_sec is Some(_) ||
    source.raw_name_sec_payload is Some(_) ||
    candidate.raw_name_sec_payload is Some(_) ||
    source.compiler_fact_custom_section is Some(_) ||
    candidate.compiler_fact_custom_section is Some(_) {
    return false
  }
  if !physical_equal(source.custom_secs, candidate.custom_secs) ||
    !physical_equal(source.import_sec, candidate.import_sec) ||
    !physical_equal(source.func_annotation_sec, candidate.func_annotation_sec) ||
    !physical_equal(source.table_sec, candidate.table_sec) ||
    !physical_equal(source.mem_sec, candidate.mem_sec) ||
    !physical_equal(source.tag_sec, candidate.tag_sec) ||
    !physical_equal(source.stringrefs_sec, candidate.stringrefs_sec) ||
    !physical_equal(source.global_sec, candidate.global_sec) ||
    !physical_equal(source.export_sec, candidate.export_sec) ||
    !physical_equal(source.start_sec, candidate.start_sec) ||
    !physical_equal(source.elem_sec, candidate.elem_sec) ||
    !physical_equal(source.data_cnt_sec, candidate.data_cnt_sec) ||
    !physical_equal(source.data_sec, candidate.data_sec) {
    return false
  }
  for custom in source.custom_secs {
    let @lib.CustomSec(@lib.Name(name), _) = custom
    if name == "name" || name == "compiler.facts" {
      return false
    }
  }
  match
    (
      source.type_sec,
      candidate.type_sec,
      source.func_sec,
      candidate.func_sec,
      source.code_sec,
      candidate.code_sec,
    ) {
    (
      Some(@lib.TypeSec(old_types)),
      Some(@lib.TypeSec(new_types)),
      Some(@lib.FuncSec(old_funcs)),
      Some(@lib.FuncSec(new_funcs)),
      Some(@lib.CodeSec(old_bodies)),
      Some(@lib.CodeSec(new_bodies)),
    ) =>
      physical_equal(old_types, new_types) &&
      old_funcs.length() == new_funcs.length() &&
      old_funcs.length() == old_bodies.length() &&
      old_bodies.length() == new_bodies.length()
    _ => false
  }
}

///|
/// Reused types may remove numeric parameters or one audited numeric result.
fn dae_scalar_numeric_signature_change(
  old : @lib.FuncType,
  next : @lib.FuncType,
) -> Bool {
  let @lib.FuncType(old_params, old_results) = old
  let @lib.FuncType(next_params, next_results) = next
  let numeric = fn(value) {
    match value {
      @lib.NumTypeValType(_) | @lib.VecTypeValType => true
      _ => false
    }
  }
  if !old_params.all(numeric) ||
    !old_results.all(numeric) ||
    !next_params.all(numeric) ||
    old_results != next_results ||
    next_params.length() >= old_params.length() {
    return false
  }
  let mut next_idx = 0
  for old_param in old_params {
    if next_idx < next_params.length() && old_param == next_params[next_idx] {
      next_idx += 1
    }
  }
  next_idx == next_params.length()
}

///| Only success bypasses the complete gate. The existing environment builder

///|
/// rechecks all pre-code sections against the new function contexts.
fn dae_scalar_validation_try_partial(
  chain : DaeScalarValidationChain,
  source : @lib.Module,
  candidate : @lib.Module,
  work~ : DaeScalarValidationWork? = None,
  allow_numeric_result_removal~ : Bool = false,
) -> Bool {
  // Keep the original scalar and new result-constructor lifetimes separate.
  if chain.numeric_result_source != allow_numeric_result_removal {
    return false
  }
  match (chain.no_callback, chain.checked_source) {
    (Some(_), Some(checked)) if physical_equal(checked, source) => ()
    _ => return false
  }
  match work {
    Some(counts) => counts.matched_sources += 1
    None => ()
  }
  if !dae_scalar_validation_envelope(source, candidate) {
    return false
  }
  match work {
    Some(counts) => counts.envelope_matches += 1
    None => ()
  }
  let old_types = source.func_sec.unwrap().0
  let next_types = candidate.func_sec.unwrap().0
  let old_funcs = source.code_sec.unwrap().0
  let next_funcs = candidate.code_sec.unwrap().0
  let defined = old_funcs.length()
  let imported = dae_imported_func_count(source)
  let changed_contexts : Array[Int32] = []
  for def_idx in 0..<defined {
    if old_types[def_idx] != next_types[def_idx] {
      let old = match
        dae_type_sec_func_type(source.type_sec.unwrap(), old_types[def_idx]) {
        Some(ft) => ft
        None => return false
      }
      let next = match
        dae_type_sec_func_type(candidate.type_sec.unwrap(), next_types[def_idx]) {
        Some(ft) => ft
        None => return false
      }
      if !dae_scalar_numeric_signature_change(old, next) &&
        !(allow_numeric_result_removal &&
        dae_numeric_result_signature_change(old, next)) {
        return false
      }
      match source.start_sec {
        Some(@lib.StartSec(target)) if target.0.reinterpret_as_int() ==
          imported + def_idx => return false
        _ => ()
      }
      changed_contexts.push(def_idx)
    }
  }
  if changed_contexts.is_empty() {
    return false
  }
  let index = match chain.syntax_index {
    Some(index) => index
    None => {
      match work {
        Some(counts) => counts.index_builds += 1
        None => ()
      }
      match dae_scalar_syntax_index(source) {
        Some(index) => {
          chain.syntax_index = Some(index)
          index
        }
        None => return false
      }
    }
  }
  for def_idx in 0..<defined {
    index.selected[def_idx] = false
  }
  for def_idx in changed_contexts {
    index.selected[def_idx] = true
    for caller in index.users[def_idx] {
      index.selected[caller] = true
    }
  }
  let changed_rows : Array[(Int32, Array[Int32])] = []
  for def_idx in 0..<defined {
    if !physical_equal(old_funcs[def_idx], next_funcs[def_idx]) {
      let row = match
        dae_scalar_dependency_row(
          next_funcs[def_idx],
          index,
          candidate.data_cnt_sec is Some(_),
        ) {
        Some(row) => row
        None => return false
      }
      changed_rows.push((def_idx, row))
      index.selected[def_idx] = true
    }
  }
  let selected : Array[(@lib.FuncIdx, @lib.Func)] = []
  for def_idx in 0..<defined {
    if index.selected[def_idx] {
      selected.push(
        (
          @lib.FuncIdx::new((index.imported + def_idx).reinterpret_as_uint()),
          next_funcs[def_idx],
        ),
      )
    }
  }
  match @validate.validate_defined_funcs_against_module(candidate, selected) {
    Err(_) => return false
    Ok(errors) => {
      // The helper checks every selected body after its environment succeeds.
      match work {
        Some(counts) => counts.partial_bodies += selected.length()
        None => ()
      }
      if !errors.is_empty() {
        return false
      }
    }
  }
  for (caller, row) in changed_rows {
    dae_scalar_replace_dependency_row(index, caller, row, work~)
  }
  chain.checked_source = Some(candidate)
  chain.numeric_result_source = allow_numeric_result_removal
  true
}

///|
/// Optional scopes never survive a producer outside the audited COW path.
fn dae_scalar_validation_barrier_opt(chain : DaeScalarValidationChain?) -> Unit {
  match chain {
    Some(chain) => dae_scalar_validation_barrier(chain)
    None => ()
  }
}

///|
/// An outer no-op normalization may preserve the exact checked candidate.
fn dae_scalar_validation_retain_exact(
  chain : DaeScalarValidationChain?,
  source : @lib.Module,
) -> Unit {
  match chain {
    Some(chain) =>
      match chain.checked_source {
        Some(checked) if physical_equal(checked, source) => ()
        _ => dae_scalar_validation_barrier(chain)
      }
    None => ()
  }
}
