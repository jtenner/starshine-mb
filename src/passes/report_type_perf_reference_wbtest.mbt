///|
/// Pre-review control, used only by the paired performance lane.
fn review_reference_precompute_cleanup_unused_gc_types(
  original : @lib.Module,
  mod_ : @lib.Module,
) -> @lib.Module {
  if !precompute_type_cleanup_supported(mod_) {
    return mod_
  }
  let old_code = match original.code_sec {
    Some(code) => @binary.encode_module(@lib.Module::new().with_code_sec(code))
    None => return mod_
  }
  let new_code = match mod_.code_sec {
    Some(code) => @binary.encode_module(@lib.Module::new().with_code_sec(code))
    None => return mod_
  }
  match (old_code, new_code) {
    (Ok(old_bytes), Ok(new_bytes)) if old_bytes != new_bytes => ()
    _ => return mod_
  }
  let pruned = dfe_prune_unused_simple_types(mod_)
  match (@binary.encode_module(mod_), @binary.encode_module(pruned)) {
    (Ok(before), Ok(after)) if after.length() < before.length() =>
      if @validate.validate_module(pruned) is Ok(_) {
        return pruned
      }
    _ => ()
  }
  mod_
}

///|
/// Pre-review control, used only by the paired performance lane.
fn review_reference_gsi_merge_equivalent_struct_type_facts(
  env : @validate.Env,
  poisoned_type_slots : Array[Bool],
  candidates_by_type_slot : Array[Array[@lib.GlobalIdx]],
) -> Unit {
  let type_count = poisoned_type_slots.length()
  for lhs = 0; lhs < type_count; lhs = lhs + 1 {
    if env.resolve_struct_fields(gsi_type_idx_from_slot(lhs)) is Err(_) {
      continue
    }
    for rhs = lhs + 1; rhs < type_count; rhs = rhs + 1 {
      if !poisoned_type_slots[lhs] &&
        !poisoned_type_slots[rhs] &&
        candidates_by_type_slot[lhs].is_empty() &&
        candidates_by_type_slot[rhs].is_empty() {
        continue
      }
      if env.resolve_struct_fields(gsi_type_idx_from_slot(rhs)) is Err(_) {
        continue
      }
      let lhs_type = @lib.ValType::ref_type(
        @lib.RefType::new(
          false,
          @lib.HeapType::new(gsi_type_idx_from_slot(lhs)),
        ),
      )
      let rhs_type = @lib.ValType::ref_type(
        @lib.RefType::new(
          false,
          @lib.HeapType::new(gsi_type_idx_from_slot(rhs)),
        ),
      )
      if !@validate.Match::matches(lhs_type, rhs_type, env) ||
        !@validate.Match::matches(rhs_type, lhs_type, env) {
        continue
      }
      let poisoned = poisoned_type_slots[lhs] || poisoned_type_slots[rhs]
      poisoned_type_slots[lhs] = poisoned
      poisoned_type_slots[rhs] = poisoned
      let lhs_candidates = candidates_by_type_slot[lhs].copy()
      let rhs_candidates = candidates_by_type_slot[rhs].copy()
      for candidate in rhs_candidates {
        if !gsi_candidate_list_contains(candidates_by_type_slot[lhs], candidate) {
          candidates_by_type_slot[lhs].push(candidate)
        }
      }
      for candidate in lhs_candidates {
        if !gsi_candidate_list_contains(candidates_by_type_slot[rhs], candidate) {
          candidates_by_type_slot[rhs].push(candidate)
        }
      }
    }
  }
}

///|
/// Pre-review control, used only by the paired performance lane.
fn review_reference_precompute_known_heap_value_from_global(
  module_ctx : @ir.HotModuleContext,
  global_idx : @lib.GlobalIdx,
  depth : Int32,
) -> PrecomputeKnownHeapValue? {
  if depth > 32 || !precompute_global_is_immutable(module_ctx, global_idx) {
    return None
  }
  let instrs = match
    @ir.hot_module_resolve_global_init(module_ctx, global_idx) {
    Some(@lib.Expr(instrs)) => instrs
    None => return None
  }
  let stack : Array[PrecomputeKnownHeapValue] = []
  for instr in instrs {
    match instr {
      @lib.I32Const(_)
      | @lib.I64Const(_)
      | @lib.F32Const(_)
      | @lib.F64Const(_)
      | @lib.RefNull(_)
      | @lib.RefFunc(_)
      | @lib.StringConst(_) => stack.push(KnownEmit(instr))
      @lib.GlobalGet(global_alias) =>
        match
          review_reference_precompute_known_heap_value_from_global(
            module_ctx,
            global_alias,
            depth + 1,
          ) {
          Some(value) => stack.push(value)
          None => return None
        }
      @lib.StructNew(type_idx) => {
        let fields = match
          @ir.hot_module_resolve_struct_fields(module_ctx, type_idx) {
          Some(fields) => fields
          None => return None
        }
        let values = match
          precompute_known_heap_pop_values(stack, fields.length()) {
          Some(values) => values
          None => return None
        }
        stack.push(KnownStructFields(type_idx, values))
      }
      @lib.StructNewDefault(type_idx) =>
        stack.push(KnownStructDefault(type_idx))
      @lib.ArrayNewFixed(type_idx, @lib.U32(length)) => {
        if !precompute_fresh_array_length_is_interpretable(length) {
          return None
        }
        let values = match
          precompute_known_heap_pop_values(stack, length.reinterpret_as_int()) {
          Some(values) => values
          None => return None
        }
        stack.push(KnownArrayFixed(type_idx, values))
      }
      @lib.ArrayNew(type_idx) => {
        let operands = match precompute_known_heap_pop_values(stack, 2) {
          Some(operands) => operands
          None => return None
        }
        let length = match operands[1] {
          KnownEmit(@lib.I32Const(@lib.I32(length))) if length >= 0 &&
            precompute_fresh_array_length_is_interpretable(
              length.reinterpret_as_uint(),
            ) => length.reinterpret_as_uint()
          _ => return None
        }
        stack.push(KnownArrayFill(type_idx, [operands[0]], length))
      }
      @lib.ArrayNewDefault(type_idx) => {
        let operands = match precompute_known_heap_pop_values(stack, 1) {
          Some(operands) => operands
          None => return None
        }
        let length = match operands[0] {
          KnownEmit(@lib.I32Const(@lib.I32(length))) if length >= 0 &&
            precompute_fresh_array_length_is_interpretable(
              length.reinterpret_as_uint(),
            ) => length.reinterpret_as_uint()
          _ => return None
        }
        stack.push(KnownArrayDefault(type_idx, length))
      }
      _ => return None
    }
  }
  if stack.length() == 1 {
    Some(stack[0])
  } else {
    None
  }
}

///|
/// Pre-review per-comparison environment control.
fn review_reference_oc_heap_identical(
  module_ctx : @ir.HotModuleContext,
  source : @lib.HeapType,
  target : @lib.HeapType,
) -> Bool {
  if source == target {
    return true
  }
  match (source, target) {
    (@lib.HeapType(_), @lib.HeapType(_)) => {
      let base = @validate.Env::new().with_types(module_ctx.subtypes)
      let env = @validate.Env::{ ..base, rec_stack: module_ctx.type_groups, }
      @validate.Match::matches(
        @lib.RefType::new(false, source, exact=true),
        @lib.RefType::new(false, target, exact=true),
        env,
      )
    }
    _ => false
  }
}

///|
/// Pre-review raw admission scan control.
fn review_reference_precompute_run_raw_func(
  func : @lib.Func,
  module_ctx : @ir.HotModuleContext?,
) -> (@lib.Func, Bool, String)? {
  let @lib.Func(locals, @lib.Expr(instrs)) = func
  if precompute_raw_root_nop_cleanup_candidate(instrs) {
    return None
  }
  let (rewritten, initial_changed) = precompute_raw_rewrite_instrs(
    instrs, module_ctx,
  )
  let changed = precompute_raw_trim_redundant_root_nops(rewritten) ||
    initial_changed
  if precompute_raw_instrs_are_nop_trees(rewritten) && rewritten.length() > 1 {
    return Some(
      (
        @lib.Func::new(locals, @lib.Expr::new([@lib.Instruction::nop()])),
        true,
        "raw-all-nop-collapse",
      ),
    )
  }
  if precompute_raw_instrs_have_hot_only_candidate(rewritten, module_ctx) {
    return None
  }
  let retains_raw_control_flow = changed &&
    precompute_raw_instrs_have_label_relative_branch(instrs)
  if precompute_raw_root_nop_cleanup_candidate(rewritten) {
    return None
  }
  if (
      precompute_raw_instrs_have_drop_needing_hot(rewritten) ||
      precompute_raw_instrs_have_const_control_candidate(rewritten)
    ) &&
    !retains_raw_control_flow {
    return None
  }
  Some(
    (
      if changed {
        @lib.Func::new(locals, @lib.Expr::new(rewritten))
      } else {
        func
      },
      changed,
      if retains_raw_control_flow {
        "raw-control-flow-folds"
      } else if changed {
        "raw-scalar-folds"
      } else {
        "no-precompute-candidates"
      },
    ),
  )
}

///|
/// Pre-review repeated size-comparison control.
fn review_reference_reorder_globals_run_module_pass_with_threshold(
  mod_ : @lib.Module,
  enforce_public_threshold : Bool,
) -> @lib.Module {
  if pass_module_has_offset_sensitive_metadata(mod_) {
    return mod_
  }
  let globals = match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) => globals
    None => []
  }
  let imported_globals = rg_imported_global_count(mod_)
  let total_globals = imported_globals + globals.length()
  if total_globals <= 1 || (enforce_public_threshold && total_globals < 128) {
    return mod_
  }
  let counts = rg_count_global_traffic(mod_, total_globals)
  let true_counts = rg_true_counts(counts)
  let deps = rg_build_dependency_graph(globals, imported_globals)
  let order = rg_choose_order(deps, true_counts, imported_globals)
  let identity = rg_order_is_identity(order)
  if identity {
    // Traffic can be zero while a name above a LEB boundary still costs more.
    // Keep the old always-mode rule and the unnamed no-op path allocation-free.
    if !enforce_public_threshold {
      return mod_
    }
    match mod_.name_sec {
      Some(sec) =>
        match sec.global_names {
          Some(@lib.NameMap(names)) if !names.is_empty() => ()
          _ => return mod_
        }
      None => return mod_
    }
  }
  let mut best = mod_
  let baseline = if enforce_public_threshold &&
    mod_.compiler_fact_custom_section is Some(_) {
    mod_.without_compiler_fact_custom_section()
  } else {
    mod_
  }
  let mut comparisons_left = 4
  if !identity {
    let greedy = rg_apply_order(mod_, globals, order, imported_globals)
    if !enforce_public_threshold {
      return greedy
    }
    match @binary.encoded_module_sizes(baseline, greedy) {
      Ok((before, after)) if after < before => best = greedy
      _ => ()
    }
    comparisons_left -= 1
  }
  // Try one traffic-ranked swap per index-width boundary. Names participate
  // in the ranking and complete module framing participates in the decision.
  // This is bounded (four boundaries for wasm u32), not an all-pairs search.
  let weighted = counts
  let mut has_name_traffic = false
  match mod_.name_sec {
    Some(sec) =>
      match sec.global_names {
        Some(@lib.NameMap(names)) =>
          for entry in names {
            let @lib.NameAssoc(index, _) = entry
            let index = index.reinterpret_as_int()
            if index >= 0 && index < weighted.length() {
              weighted[index] += 1
              has_name_traffic = true
            }
          }
        None => ()
      }
    None => ()
  }
  for boundary in [128, 16384, 2097152, 268435456] {
    if comparisons_left == 0 {
      break
    }
    if boundary <= imported_globals || boundary >= total_globals {
      continue
    }
    let mut low = imported_globals
    for index in imported_globals..<boundary {
      if weighted[index] < weighted[low] {
        low = index
      }
    }
    let mut high = boundary
    for index in boundary..<total_globals {
      if weighted[index] > weighted[high] {
        high = index
      }
    }
    if weighted[high] <= weighted[low] {
      continue
    }
    let swap = rg_identity_order(total_globals)
    swap[low] = high
    swap[high] = low
    if swap == order {
      continue
    }
    let remap = rg_old_abs_to_new_abs(swap)
    let mut legal = true
    for dependency in 0..<deps.length() {
      for dependent in deps[dependency] {
        if remap[dependency] >= remap[dependent] {
          legal = false
        }
      }
    }
    if !legal {
      continue
    }
    let candidate = rg_apply_order(mod_, globals, swap, imported_globals)
    comparisons_left -= 1
    let comparison = if physical_equal(best, mod_) { baseline } else { best }
    match @binary.encoded_module_sizes(comparison, candidate) {
      Ok((before, after)) if after < before => best = candidate
      _ => ()
    }
  }
  // A single swap cannot combine independent name-only wins. Reuse the
  // dependency-constrained search once with names included, after the old
  // candidates so ties keep their output. Limit this extra search to the
  // first width boundary, within the same four-comparison budget.
  if has_name_traffic && total_globals <= 16384 && comparisons_left > 0 {
    let named_order = rg_choose_order(
      deps,
      rg_true_counts(weighted),
      imported_globals,
    )
    if named_order != order && !rg_order_is_identity(named_order) {
      let candidate = rg_apply_order(
        mod_, globals, named_order, imported_globals,
      )
      let comparison = if physical_equal(best, mod_) { baseline } else { best }
      match @binary.encoded_module_sizes(comparison, candidate) {
        Ok((before, after)) if after < before => best = candidate
        _ => ()
      }
    }
  }
  best
}

///|
/// Pre-review exact raw-dispatch control for the original-body feature scan.
fn review_reference_raw_precompute_dispatch(
  mod_ : @lib.Module,
  func_idx : @lib.FuncIdx,
  module_state : HotPipelineModuleState,
  descriptor : @ir.HotPassDescriptor,
  options : HotPipelineOptions,
  instruction_scans~ : Array[Int32]? = None,
) -> HotPipelineFuncResult? {
  let propagating = descriptor.name == "precompute-propagate"
  if descriptor.name != "precompute" && !propagating {
    return None
  }
  let original = run_hot_pipeline_original_func(
    mod_,
    func_idx,
    module_state=Some(module_state),
  )
  let o4z_precompute_gate = options.optimize_level >= 4 &&
    options.shrink_level >= 1
  let @lib.Func(locals, @lib.Expr(body)) = original
  if run_hot_pipeline_raw_has_root_global_snapshot_write_prefix(body) {
    return Some({
      reason: "root-global-snapshot-write-prefix-\{descriptor.name}-noop",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if propagating &&
    run_hot_pipeline_raw_precompute_has_tee_backed_dynamic_global_write(body) {
    return Some({
      reason: "tee-backed-dynamic-global-write-precompute-propagate-noop",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if run_hot_pipeline_raw_precompute_has_stack_carried_overwritten_local(body) {
    return Some({
      reason: "stack-carried-overwritten-local-\{descriptor.name}-noop",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if propagating &&
    run_hot_pipeline_raw_precompute_has_multi_read_arithmetic_local(body) {
    return Some({
      reason: "multi-read-arithmetic-local-precompute-propagate-noop",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if propagating && run_hot_pipeline_raw_has_load_before_same_local_call(body) {
    return Some({
      reason: "load-before-release-precompute-propagate-noop",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if propagating &&
    run_hot_pipeline_raw_precompute_has_indexed_load_alias_release(body) {
    return Some({
      reason: "indexed-load-alias-release-precompute-propagate-noop",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if propagating &&
    run_hot_pipeline_raw_precompute_has_call_result_across_memory_store(body) {
    return Some({
      reason: "call-result-memory-store-precompute-propagate-noop",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if propagating &&
    run_hot_pipeline_raw_simplify_locals_has_call_bulk_memory_effect_mesh(body) &&
    run_hot_pipeline_raw_precompute_has_call_result_local_reload(body) {
    return Some({
      reason: "call-result-memory-copy-precompute-propagate-noop",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if propagating &&
    run_hot_pipeline_raw_remove_unused_brs_has_comparison_flag_if_hazard(body) {
    return Some({
      reason: "comparison-flag-if-precompute-propagate-noop",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if propagating &&
    run_hot_pipeline_raw_precompute_has_nested_empty_block_shell(body) {
    return Some({
      reason: "nested-empty-block-label-owner-precompute-propagate-noop",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if propagating && locals.length() >= 128 {
    let shape = RawRemoveUnusedBrsShape::new()
    run_hot_pipeline_raw_remove_unused_brs_scan_shape(body, shape)
    if shape.br_count + shape.br_if_count + shape.br_table_count >= 16 {
      return Some({
        reason: "large-branch-local-label-owner-precompute-propagate-noop",
        func: original,
        unchanged_original: true,
        trace_skip_raw: true,
      })
    }
  }
  if propagating {
    let module_ctx = run_hot_pipeline_require_module_ctx(
      mod_, module_state, options,
    )
    let params = run_hot_pipeline_required_func_params(module_ctx, func_idx)
    if run_hot_pipeline_raw_instrs_have_memory_access(body) &&
      run_hot_pipeline_raw_has_parameter_read_before_later_write(
        body,
        params.length(),
      ) {
      return Some({
        reason: "parameter-read-before-write-precompute-propagate-noop",
        func: original,
        unchanged_original: true,
        trace_skip_raw: true,
      })
    }
  }
  if propagating &&
    run_hot_pipeline_raw_simplify_locals_has_call_result_structured_lifetime(
      body,
    ) {
    return Some({
      reason: "call-result-structured-lifetime-precompute-propagate-noop",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if propagating && run_hot_pipeline_raw_has_alias_call_structured_release(body) {
    return Some({
      reason: "call-argument-structured-release-precompute-propagate-noop",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if propagating && run_hot_pipeline_raw_has_call_argument_direct_release(body) {
    return Some({
      reason: "call-argument-direct-release-precompute-propagate-noop",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if propagating {
    let module_ctx = run_hot_pipeline_require_module_ctx(
      mod_, module_state, options,
    )
    if run_hot_pipeline_raw_has_dropped_call_result_effect_order(
        body, module_ctx,
      ) {
      return Some({
        reason: "dropped-call-result-effect-order-precompute-propagate-noop",
        func: original,
        unchanged_original: true,
        trace_skip_raw: true,
      })
    }
    if run_hot_pipeline_tuple_has_effect_bracketed_multivalue_call(
        body, module_ctx,
      ) {
      return Some({
        reason: "effect-bracketed-multivalue-call-precompute-propagate-noop",
        func: original,
        unchanged_original: true,
        trace_skip_raw: true,
      })
    }
  }
  if propagating &&
    run_hot_pipeline_raw_simplify_locals_has_call_local_tee_lifetime(body) {
    return Some({
      reason: "call-local-tee-lifetime-precompute-propagate-noop",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if propagating &&
    run_hot_pipeline_raw_precompute_has_call_result_release_stack_carrier(body) {
    return Some({
      reason: "call-result-release-stack-carrier-precompute-propagate-noop",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if propagating &&
    run_hot_pipeline_raw_precompute_has_call_result_local_reload(body) {
    return Some({
      reason: "call-result-local-reload-precompute-propagate-noop",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if propagating &&
    run_hot_pipeline_raw_has_single_argument_distinct_call_lifetime(body) {
    return Some({
      reason: "single-argument-distinct-call-lifetime-precompute-propagate-noop",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  let stats = OptimizeInstructionsLoweredStats::new()
  if propagating || locals.length() > 64 {
    match instruction_scans {
      Some(count) => count[0] += 1
      None => ()
    }
    run_hot_pipeline_optimize_instructions_collect_stats_body(body, stats)
  }
  if propagating && precompute_raw_instrs_have_legacy_try(body) {
    let module_ctx = Some(
      run_hot_pipeline_require_module_ctx(mod_, module_state, options),
    )
    match precompute_run_raw_func(original, module_ctx) {
      Some((rewritten, changed, _)) =>
        return Some({
          reason: if changed {
            "raw-legacy-try-precompute-propagate"
          } else {
            "legacy-try-precompute-propagate-noop"
          },
          func: rewritten,
          unchanged_original: !changed,
          trace_skip_raw: true,
        })
      None =>
        return Some({
          reason: "legacy-try-precompute-propagate-noop",
          func: original,
          unchanged_original: true,
          trace_skip_raw: true,
        })
    }
  }
  if propagating && precompute_raw_instrs_have_stack_switching(body) {
    let module_ctx = Some(
      run_hot_pipeline_require_module_ctx(mod_, module_state, options),
    )
    match precompute_run_raw_func(original, module_ctx) {
      Some((rewritten, changed, _)) =>
        return Some({
          reason: if changed {
            "raw-stack-switching-precompute-propagate"
          } else {
            "stack-switching-precompute-propagate-noop"
          },
          func: rewritten,
          unchanged_original: !changed,
          trace_skip_raw: true,
        })
      None =>
        return Some({
          reason: "stack-switching-precompute-propagate-noop",
          func: original,
          unchanged_original: true,
          trace_skip_raw: true,
        })
    }
  }
  if precompute_raw_instrs_have_atomic_fence(body) {
    let module_ctx = if propagating ||
      precompute_raw_func_has_global_get(original) {
      Some(run_hot_pipeline_require_module_ctx(mod_, module_state, options))
    } else {
      None
    }
    match precompute_run_raw_around_atomic_fence(original, module_ctx) {
      Some((rewritten, changed)) =>
        return Some({
          reason: if changed {
            "raw-precompute-around-atomic-fence"
          } else if propagating {
            "atomic-fence-precompute-propagate-noop"
          } else {
            "atomic-fence-precompute-noop"
          },
          func: rewritten,
          unchanged_original: !changed,
          trace_skip_raw: true,
        })
      None => ()
    }
  }
  if propagating {
    let module_ctx = run_hot_pipeline_require_module_ctx(
      mod_, module_state, options,
    )
    let params = run_hot_pipeline_required_func_params(module_ctx, func_idx)
    match
      precompute_propagate_run_raw_unreachable_suffix(
        original,
        params,
        Some(module_ctx),
      ) {
      Some((rewritten, changed)) =>
        return Some({
          reason: if changed {
            "raw-unreachable-suffix-precompute-propagate"
          } else {
            "unreachable-suffix-precompute-propagate-noop"
          },
          func: rewritten,
          unchanged_original: !changed,
          trace_skip_raw: true,
        })
      None => ()
    }
  }
  if propagating &&
    stats.instrs > 50 &&
    precompute_raw_instrs_have_memory_grow(body) {
    let module_ctx = run_hot_pipeline_require_module_ctx(
      mod_, module_state, options,
    )
    let params = run_hot_pipeline_required_func_params(module_ctx, func_idx)
    match
      precompute_propagate_run_raw_straight_line_func(
        original,
        params,
        Some(module_ctx),
      ) {
      Some((rewritten, changed)) if changed =>
        return Some({
          reason: "raw-structured-local-constant-propagation",
          func: rewritten,
          unchanged_original: false,
          trace_skip_raw: true,
        })
      _ => ()
    }
  }
  if run_hot_pipeline_dce_raw_has_load_call_set_hazard(body) {
    if propagating {
      let module_ctx = run_hot_pipeline_require_module_ctx(
        mod_, module_state, options,
      )
      let params = run_hot_pipeline_required_func_params(module_ctx, func_idx)
      match
        precompute_propagate_run_raw_straight_line_func(
          original,
          params,
          Some(module_ctx),
        ) {
        Some((rewritten, changed)) if changed =>
          return Some({
            reason: "raw-local-constant-propagation",
            func: rewritten,
            unchanged_original: false,
            trace_skip_raw: true,
          })
        _ => ()
      }
    }
    return Some({
      reason: if o4z_precompute_gate {
        "o4z-precompute-noop"
      } else if propagating {
        "load-call-set-precompute-propagate-noop"
      } else {
        "load-call-set-precompute-noop"
      },
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if locals.length() > 64 && stats.instrs > 500 {
    if propagating {
      let module_ctx = run_hot_pipeline_require_module_ctx(
        mod_, module_state, options,
      )
      let params = run_hot_pipeline_required_func_params(module_ctx, func_idx)
      match
        precompute_propagate_run_raw_straight_line_func(
          original,
          params,
          Some(module_ctx),
        ) {
        Some((rewritten, changed)) if changed =>
          return Some({
            reason: "raw-large-local-constant-propagation",
            func: rewritten,
            unchanged_original: false,
            trace_skip_raw: true,
          })
        _ => ()
      }
    }
    return Some({
      reason: if o4z_precompute_gate {
        "o4z-precompute-noop"
      } else if propagating {
        "large-lowered-precompute-propagate-noop"
      } else {
        "large-lowered-precompute-noop"
      },
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if run_hot_pipeline_raw_can_skip_simd_parser_br_table_stack_hazard(
      locals, body,
    ) {
    return Some({
      reason: if o4z_precompute_gate {
        "o4z-precompute-noop"
      } else if propagating {
        "simd-parser-br-table-stack-hazard-precompute-propagate-noop"
      } else {
        "simd-parser-br-table-stack-hazard-precompute-noop"
      },
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if propagating {
    if run_hot_pipeline_raw_precompute_const_simd_reduction_count(body) >= 4 ||
      run_hot_pipeline_raw_precompute_additive_local_update_count(body) >= 4 {
      let module_ctx = run_hot_pipeline_require_module_ctx(
        mod_, module_state, options,
      )
      let params = run_hot_pipeline_required_func_params(module_ctx, func_idx)
      match
        precompute_propagate_run_raw_straight_line_func(
          original,
          params,
          Some(module_ctx),
        ) {
        Some((rewritten, true)) =>
          return Some({
            reason: "raw-constant-simd-reduction-precompute-propagate",
            func: rewritten,
            unchanged_original: false,
            trace_skip_raw: true,
          })
        _ => ()
      }
      match precompute_run_raw_func(original, Some(module_ctx)) {
        Some((rewritten, true, _)) =>
          return Some({
            reason: "raw-constant-simd-reduction-precompute-propagate",
            func: rewritten,
            unchanged_original: false,
            trace_skip_raw: true,
          })
        _ => ()
      }
    }
    if !precompute_raw_func_has_local_traffic(original) {
      let module_ctx = Some(
        run_hot_pipeline_require_module_ctx(mod_, module_state, options),
      )
      match precompute_run_raw_func(original, module_ctx) {
        Some((rewritten, true, reason)) =>
          return Some({
            reason,
            func: rewritten,
            unchanged_original: false,
            trace_skip_raw: true,
          })
        _ => ()
      }
    }
    return None
  }
  if precompute_raw_instrs_have_partial_heap_select(body) {
    return None
  }
  let module_ctx = Some(
    run_hot_pipeline_require_module_ctx(mod_, module_state, options),
  )
  match precompute_run_raw_func(original, module_ctx) {
    Some((rewritten, changed, reason)) =>
      if o4z_precompute_gate {
        if changed &&
          (reason == "raw-scalar-folds" || reason == "raw-control-flow-folds") {
          Some({
            reason,
            func: rewritten,
            unchanged_original: false,
            trace_skip_raw: true,
          })
        } else {
          Some({
            reason: "o4z-precompute-noop",
            func: original,
            unchanged_original: true,
            trace_skip_raw: true,
          })
        }
      } else {
        Some({
          reason,
          func: rewritten,
          unchanged_original: !changed,
          trace_skip_raw: true,
        })
      }
    None =>
      if o4z_precompute_gate {
        Some({
          reason: "o4z-precompute-noop",
          func: original,
          unchanged_original: true,
          trace_skip_raw: true,
        })
      } else {
        None
      }
  }
}

///|
/// Coarse-class control before the active-reference shape key.
fn review_coarse_gsi_merge_equivalent_struct_type_facts(
  env : @validate.Env,
  poisoned_type_slots : Array[Bool],
  candidates_by_type_slot : Array[Array[@lib.GlobalIdx]],
) -> Unit {
  if !poisoned_type_slots.any(fn(value) { value }) &&
    candidates_by_type_slot.all(fn(values) { values.is_empty() }) {
    return
  }
  let buckets : @hashmap.HashMap[Int32, Array[Array[Int32]]] = @hashmap.new()
  let active_arities : @hashmap.HashMap[Int32, Bool] = @hashmap.new()
  // Only active classes can contribute facts. Do not compare unrelated
  // inactive types with each other in a coarse concrete-reference bucket.
  for phase in 0..<2 {
    for slot in 0..<poisoned_type_slots.length() {
      let active = poisoned_type_slots[slot] ||
        !candidates_by_type_slot[slot].is_empty()
      if active != (phase == 0) {
        continue
      }
      let fields = match
        env.resolve_struct_fields(gsi_type_idx_from_slot(slot)) {
        Ok(fields) => fields
        Err(_) => continue
      }
      if active {
        active_arities.set(fields.length(), true)
      } else if !active_arities.contains(fields.length()) {
        continue
      }
      // Concrete reference indices can name structurally equivalent recursive
      // types. Keep them in the same coarse bucket and let Match prove equality.
      let mut key = fields.length()
      for field in fields {
        let @lib.FieldType(storage, mutability) = field
        let storage_key = match storage {
          @lib.ValTypeStorageType(@lib.RefTypeValType(_)) => 101
          _ => storage.hash()
        }
        key = (key * 31 + storage_key) * 31 + mutability.hash()
      }
      let groups = match buckets.get(key) {
        Some(groups) => groups
        None => {
          if !active {
            continue
          }
          let groups : Array[Array[Int32]] = []
          buckets.set(key, groups)
          groups
        }
      }
      let value_type = @lib.ValType::ref_type(
        @lib.RefType::new(
          false,
          @lib.HeapType::new(gsi_type_idx_from_slot(slot)),
        ),
      )
      let mut found = false
      for group in groups {
        let representative = @lib.ValType::ref_type(
          @lib.RefType::new(
            false,
            @lib.HeapType::new(gsi_type_idx_from_slot(group[0])),
          ),
        )
        if @validate.Match::matches(value_type, representative, env) &&
          @validate.Match::matches(representative, value_type, env) {
          group.push(slot)
          found = true
          break
        }
      }
      if !found && active {
        groups.push([slot])
      }
    }
  }
  for groups in buckets.values() {
    for group in groups {
      if group.length() <= 1 {
        continue
      }
      let mut poisoned = false
      let merged : Array[@lib.GlobalIdx] = []
      let seen : @hashmap.HashMap[@lib.GlobalIdx, Bool] = @hashmap.new()
      for slot in group {
        poisoned = poisoned || poisoned_type_slots[slot]
        for candidate in candidates_by_type_slot[slot] {
          if !seen.contains(candidate) {
            seen.set(candidate, true)
            merged.push(candidate)
          }
        }
      }
      for slot in group {
        poisoned_type_slots[slot] = poisoned
        candidates_by_type_slot[slot] = merged.copy()
      }
    }
  }
}
