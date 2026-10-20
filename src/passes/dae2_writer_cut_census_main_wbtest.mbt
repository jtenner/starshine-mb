///|
fn dae2_writer_cut_census_run(
  census_errors : Array[Int32],
  mod_ : @lib.Module,
  closed_world : Bool,
  cleanup_module_env_builds~ : Array[Int32]? = None,
  rewrite_lifts~ : Array[Int32]? = None,
  local_graph_builds~ : Array[Int32]? = None,
  fallback_write_builds~ : Array[Int32]? = None,
  analysis_lifts~ : Array[Int32]? = None,
  perf~ : HotPerfSession? = None,
  raw_analysis~ : Bool = true,
  raw_conditionals~ : Bool = true,
  raw_rewrite~ : Bool = true,
  raw_sparse_replay~ : Bool = true,
  stack_suffix_rewrite~ : Bool = true,
) -> Result[@lib.Module, String] {
  if pass_module_has_offset_sensitive_metadata(mod_) {
    return Ok(mod_)
  }
  let prepare_start = perf_start_timer_opt(perf, "detail:dae2:prepare")
  let original = mod_
  let mod_ = match dae2_prepare_legacy_handlers(mod_) {
    Ok(prepared) => prepared
    Err(err) => return Err(err)
  }
  let context = @ir.hot_module_context_from_module(mod_)
  let imported = dae_imported_func_count(mod_)
  let indices = dae_collect_func_type_indices(mod_)
  let total_funcs = indices.length()
  let suffix_state = if raw_rewrite && stack_suffix_rewrite {
    Some(Dae2StackSuffixState::new(total_funcs, context~))
  } else {
    None
  }
  let graph = Dae2Graph::new()
  let infos : Array[Dae2Function] = []
  for index = 0; index < indices.length(); index = index + 1 {
    let @lib.FuncType(params, results) = match
      @ir.hot_module_resolve_func_type(
        context,
        @lib.FuncIdx::new(index.reinterpret_as_uint()),
      ) {
      Some(sig) => sig
      None => return Err("dae2: missing function signature")
    }
    infos.push(Dae2Function::new(graph, params, results))
  }
  let exposure = dae_collect_original_exposure(
    dae2_exposure_module(mod_),
    total_funcs,
    indices,
  )
  let private_elements = dae2_private_element_mask(
    mod_, context, exposure, closed_world,
  )
  let type_infos = dae2_prepare_type_locations(
    mod_,
    context,
    graph,
    infos,
    exposure,
    closed_world,
    private_elements~,
  )
  let boundary_count = graph.used.length()
  let intrinsic_imports = dae2_intrinsic_import_mask(context)
  perf_stop_timer_opt(perf, "detail:dae2:prepare", prepare_start)
  let analysis_start = perf_start_timer_opt(perf, "detail:dae2:analysis")
  let mut lift_us = 0UL
  let mut dependency_us = 0UL
  let mut admission_env : @validate.Env? = None
  // Keep only the dependency graph between functions. Each HOT body and its
  // CFG/local overlays die after this iteration; relift a body for mutation
  // only after the complete module-wide fixed point has been solved.
  for index = imported; index < total_funcs; index = index + 1 {
    let info = infos[index]
    let original_func = mod_.code_sec.unwrap().0[index - imported]
    let @lib.Func(_, @lib.Expr(raw_body)) = original_func
    ignore(
      dae2_collect_control_type_infos(
        raw_body,
        type_infos,
        info.control_type_infos,
        call_infos=Some(info.call_infos),
        suffix_state~,
        function_index=index,
      ),
    )
    info.call_infos_ready = true
    dae2_pin_flat_observable_params(
      graph, infos, index, raw_body, indices, type_infos, exposure,
    )
    let pinned_boundary = dae2_boundary_is_pinned(
      graph, infos, index, indices, type_infos, exposure,
    )
    // Edges within fully pinned boundaries cannot change any signature. Raw
    // call/control metadata still drives rewrite admission after solving.
    // Intrinsic calls require HOT analysis to pin their literal ref.func target.
    if pinned_boundary &&
      info.control_type_infos.all(fn(family) {
        dae2_boundary_is_pinned(
          graph, infos, family, indices, type_infos, exposure,
        )
      }) &&
      info.call_infos.all(fn(callee) {
        let intrinsic = match intrinsic_imports {
          Some(mask) => callee >= 0 && callee < mask.length() && mask[callee]
          None => false
        }
        !intrinsic &&
        dae2_boundary_is_pinned(
          graph, infos, callee, indices, type_infos, exposure,
        )
      }) {
      let env = match admission_env {
        Some(env) => env
        None => {
          let env = @ir.hot_module_context_validation_env(context)
          admission_env = Some(env)
          env
        }
      }
      match
        @validate.validate_func_body_against_functype(
          env,
          @lib.FuncType::new(info.params, info.results),
          original_func,
        ) {
        Ok(_) => continue
        Err(error) => return Err("dae2: validate function \{index}: \{error}")
      }
    }
    if raw_analysis {
      let dependency_start = perf_start_timer_opt(
        perf, "detail:dae2:analysis:dependencies",
      )
      let plan = dae2_raw_dependency_plan(
        graph,
        infos,
        index,
        type_infos,
        original_func,
        intrinsic_imports,
        module_context=Some(context),
        conditionals=raw_conditionals,
      )
      dependency_us += perf_elapsed_since_start_opt(perf, dependency_start)
      match plan {
        Some(plan) => {
          let env = match admission_env {
            Some(env) => env
            None => {
              let env = @ir.hot_module_context_validation_env(context)
              admission_env = Some(env)
              env
            }
          }
          match
            @validate.validate_func_body_against_functype(
              env,
              @lib.FuncType::new(info.params, info.results),
              original_func,
            ) {
            Ok(_) => ()
            Err(error) =>
              return Err("dae2: validate function \{index}: \{error}")
          }
          plan.commit(graph)
          info.raw_analysis = true
          info.raw_write_locations = plan.write_locations
          continue
        }
        None => ()
      }
    }
    match analysis_lifts {
      Some(count) => count[0] += 1
      None => ()
    }
    let lift_start = perf_start_timer_opt(perf, "detail:dae2:analysis:lift")
    let func = match
      dae2_lift_for_analysis(
        mod_,
        context,
        index,
        write_provenance=match suffix_state {
          Some(state) if state.admissions[index] == 1 => Some(state)
          _ => None
        },
        record_local_accesses=false,
      ) {
      Ok(func) => func
      Err(err) => return Err(err)
    }
    lift_us += perf_elapsed_since_start_opt(perf, lift_start)
    info.assign_node_locations(graph, @ir.hot_node_count(func))
    let dependency_start = perf_start_timer_opt(
      perf, "detail:dae2:analysis:dependencies",
    )
    dae2_analyze_function(
      graph,
      infos,
      index,
      type_infos,
      func,
      local_graph_builds~,
      fallback_write_builds~,
      intrinsic_imports~,
    )
    dependency_us += perf_elapsed_since_start_opt(perf, dependency_start)
  }
  perf_stop_timer_opt(perf, "detail:dae2:analysis", analysis_start)
  perf_record_timer_elapsed_opt(perf, "detail:dae2:analysis:lift", lift_us)
  perf_record_timer_elapsed_opt(
    perf, "detail:dae2:analysis:dependencies", dependency_us,
  )
  let solve_start = perf_start_timer_opt(perf, "detail:dae2:solve-and-admit")
  graph.solve()
  let mut signature_change = false
  match mod_.type_sec {
    Some(types) => dae2_preserve_type_identity(types, graph, infos, type_infos)
    None => ()
  }
  for index = 0; index < total_funcs; index = index + 1 {
    let info = infos[index]
    signature_change = signature_change ||
      dae2_signature_changes(graph, info) ||
      info.call_infos.any(fn(callee) {
        dae2_signature_changes(graph, infos[callee])
      })
  }
  perf_stop_timer_opt(perf, "detail:dae2:solve-and-admit", solve_start)
  if !signature_change {
    // Captures and legacy-handler adaptation are analysis scaffolding. When
    // no definition or call signature changes, keep the original expression
    // structure rather than making users pay for that scaffolding in output.
    return Ok(dfe_cleanup_simple_type_encoding(original))
  }
  let graph = graph.for_solved_rewrite()
  let census_source_used = graph.used.copy()
  let census_full_replay = Dae2RawReplayState::new(graph, boundary_count)
  let source_types = match mod_.type_sec {
    Some(types) => types
    None => return Ok(mod_)
  }
  let type_workspace = Dae2TypeWorkspace::new(source_types)
  let new_indices : Array[@lib.TypeIdx] = []
  let mut private_group : Dae2PrivateGroup? = None
  let bodies : Array[@lib.Func] = []
  let local_remaps : Array[Array[Int32]?] = []
  let control_types : @hashmap.HashMap[Int32, @lib.TypeIdx] = @hashmap.new()
  let rewrite_start = perf_start_timer_opt(perf, "detail:dae2:rewrite")
  let mut rewrite_lift_us = 0UL
  let mut lower_us = 0UL
  let mut raw_rewrite_state : Dae2RawReplayState? = None
  let mut stack_suffix_plan : Dae2StackSuffixPlan? = None
  for index = imported; index < total_funcs; index = index + 1 {
    let info = infos[index]
    let kept_params : Array[@lib.ValType] = []
    let removed_params : Array[@lib.ValType] = []
    for param = 0; param < info.params.length(); param = param + 1 {
      if graph.used[info.param_locations[param]] {
        kept_params.push(info.params[param])
      } else {
        removed_params.push(info.params[param])
      }
    }
    let results = if graph.used[info.result_location] {
      info.results
    } else {
      []
    }
    let original_func = mod_.code_sec.unwrap().0[index - imported]
    let @lib.Func(_, @lib.Expr(original_body)) = original_func
    let needs_rewrite = dae2_function_needs_rewrite(graph, infos, info)
    let control_rewrite = info.control_type_infos.any(fn(family) {
      family < 0 ||
      family >= infos.length() ||
      dae2_signature_changes(graph, infos[family])
    })
    let direct = if raw_rewrite && (needs_rewrite || control_rewrite) {
      // Raw replay proves retained headers keep their full original signature.
      // Changed private control families receive separate header types below.
      let flat = if info.raw_analysis {
        dae2_rewrite_raw_function(
          graph, infos, index, original_func, context, kept_params, removed_params,
        )
      } else {
        None
      }
      match flat {
        Some(_) => flat
        None if !needs_rewrite || control_rewrite => None
        None =>
          match suffix_state {
            Some(state) if state.admissions[index] == 1 => {
              let plan = match stack_suffix_plan {
                Some(plan) => plan
                None => {
                  let plan = Dae2StackSuffixPlan::new(graph, infos)
                  stack_suffix_plan = Some(plan)
                  plan
                }
              }
              dae2_rewrite_stack_suffix_function(
                plan, graph, info, index, original_func, state,
              )
            }
            _ => None
          }
      }
    } else {
      None
    }
    if !needs_rewrite && !control_rewrite {
      // Analysis already records every direct and indirect callee. With no
      // changed boundary or changed indexed control family, preserve the original body
      // without rebuilding its HOT graph and deterministic captures.
      bodies.push(original_func)
      local_remaps.push(None)
    } else if direct is Some((body, local_map)) {
      if control_rewrite {
        let @lib.Func(locals, @lib.Expr(instructions)) = body
        dae2_preserve_raw_control_types(
          instructions, context, graph, infos, type_infos, type_workspace, control_types,
        )
        bodies.push(
          @lib.Func::new(
            locals,
            @lib.Expr::new(
              dae2_original_control_types(instructions, control_types),
            ),
          ),
        )
      } else {
        bodies.push(body)
      }
      local_remaps.push(Some(local_map))
    } else {
      match rewrite_lifts {
        Some(count) => count[0] += 1
        None => ()
      }
      let rewrite_lift_start = perf_start_timer_opt(
        perf, "detail:dae2:rewrite:lift",
      )
      let func = match dae2_lift_for_rewrite(mod_, context, index, info) {
        Ok(func) => func
        Err(err) => return Err(err)
      }
      rewrite_lift_us += perf_elapsed_since_start_opt(perf, rewrite_lift_start)
      let rewrite_graph = if info.raw_analysis {
        let replay = match raw_rewrite_state {
          Some(replay) => {
            replay.reset()
            replay
          }
          None => {
            let replay = Dae2RawReplayState::new(
              graph,
              boundary_count,
              sparse=raw_sparse_replay,
            )
            raw_rewrite_state = Some(replay)
            replay
          }
        }
        census_full_replay.reset()
        info.assign_node_locations(
          census_full_replay.graph,
          @ir.hot_node_count(func),
        )
        let census_old_builds = [0]
        dae2_writer_cut_frozen_dae2_analyze_function(
          census_full_replay.graph,
          infos,
          index,
          type_infos,
          func,
          local_graph_builds=Some(census_old_builds),
          intrinsic_imports~,
        )
        if !census_full_replay.solve_function(info, infos) {
          census_errors[2] += 1
        }
        let census_expected = Array::makei(info.node_count, fn(node) {
          census_full_replay.graph.used[info.node_location_base + node]
        })
        let census_writer_nodes = match func.lifted_local_accesses {
          Some(accesses) => accesses.writes.map(fn(pair) { pair.1 })
          None => []
        }
        let census_writer_locals = match func.lifted_local_accesses {
          Some(accesses) => accesses.writes.map(fn(pair) { pair.0 })
          None => []
        }
        let census_journal_sizes = match func.lifted_local_accesses {
          Some(accesses) => {
            let captures = accesses.capture_sources.unwrap_or([])
            [
              accesses.gets.length(),
              accesses.gets.capacity(),
              accesses.writes.length(),
              accesses.writes.capacity(),
              captures.length(),
              captures.capacity(),
            ]
          }
          None => [0, 0, 0, 0, 0, 0]
        }
        let census_guard = [0]
        let census_admitted = {
          let probe_cut = dae2_writer_cut_census_prepare(
            census_guard, graph, info, func, original_func,
          )
          let production_cut = dae2_writer_cut_prepare(
            graph, info, func, original_func,
          )
          if (probe_cut is Some(_)) != (production_cut is Some(_)) {
            census_errors[3] += 1
          }
          probe_cut is Some(_)
        }
        let census_builds = [0]
        let replay_ok = dae2_writer_cut_analyze_raw_replay(
          graph,
          replay,
          infos,
          index,
          type_infos,
          func,
          original_func,
          local_graph_builds=Some(census_builds),
          fallback_write_builds~,
          intrinsic_imports~,
        )
        match local_graph_builds {
          Some(count) => count[0] += census_builds[0]
          None => ()
        }
        dae2_writer_cut_census_compare(
          census_errors,
          index,
          closed_world,
          graph,
          replay,
          infos,
          boundary_count,
          original_func,
          census_expected,
          census_writer_nodes,
          census_writer_locals,
          census_journal_sizes,
          census_admitted,
          census_guard[0],
          census_old_builds[0],
          census_builds[0],
        )
        if !replay_ok {
          // Qualification must reproduce the complete boundary fixed point.
          // Re-run the original module through HOT if a new dependency appears.
          return dae2_writer_cut_census_run(
            census_errors,
            original,
            closed_world,
            cleanup_module_env_builds~,
            rewrite_lifts~,
            local_graph_builds~,
            fallback_write_builds~,
            analysis_lifts~,
            perf~,
            raw_analysis=false,
            stack_suffix_rewrite~,
          )
        }
        replay.graph
      } else {
        graph
      }
      if @ir.hot_node_count(func) != info.node_count {
        return Err("dae2: analysis relift changed node identities")
      }
      let lower_state : HotPipelineLowerState = HotPipelineLowerState::new(
        Some(type_workspace.types),
      )
      dae2_preserve_control_types(
        func, context, rewrite_graph, infos, type_infos, lower_state, control_types,
      )
      if !needs_rewrite {
        type_workspace.adopt_lower_types(lower_state)
        let @lib.Func(locals, @lib.Expr(body)) = mod_.code_sec.unwrap().0[index -
          imported]
        bodies.push(
          @lib.Func::new(
            locals,
            @lib.Expr::new(dae2_original_control_types(body, control_types)),
          ),
        )
        local_remaps.push(None)
      } else {
        let old_arities = Array::makei(@ir.hot_node_count(func), fn(node) {
          @ir.hot_node_result_arity(func, node)
        })
        let memo = Array::make(info.node_count, -1)
        let roots = @ir.hot_root_span(func).map(fn(node) {
          let rewritten = dae2_rewrite_node(
            rewrite_graph, infos, index, func, node, memo, old_arities, lower_state,
            type_infos,
          )
          if results.is_empty() {
            dae2_discard(func, rewritten)
          } else {
            rewritten
          }
        })
        ignore(@ir.hot_root_splice(func, 0, @ir.hot_root_count(func), roots))
        @ir.hot_body_result_type_set(
          func,
          @ir.hot_type_intern_results(func, results),
        )
        run_hot_pipeline_prepare_tuple_make_lowering(func, lower_state)
        type_workspace.adopt_lower_types(lower_state)
        // Control verification includes core checks and supplies the same
        // child postorder to scope checks. Repeat core only on the error path
        // to retain the existing core-versus-control diagnostic prefix.
        match @ir.hot_verify_control(func) {
          Ok(_) => ()
          Err(err) =>
            match @ir.hot_verify_core(func) {
              Err(core_err) =>
                return Err("dae2: rewritten HOT function \{index}: \{core_err}")
              Ok(_) =>
                return Err(
                  "dae2: rewritten HOT control in function \{index}: \{err}",
                )
            }
        }
        let lower_start = perf_start_timer_opt(
          perf, "detail:dae2:rewrite:lower",
        )
        let @lib.Func(locals, @lib.Expr(body)) = @ir.hot_lower_func_unverified(
          func,
        )
        lower_us += perf_elapsed_since_start_opt(perf, lower_start)
        let local_map = Array::make(info.params.length() + locals.length(), -1)
        let mut kept = 0
        let mut removed = 0
        for param = 0; param < info.params.length(); param = param + 1 {
          if graph.used[info.param_locations[param]] {
            local_map[param] = kept
            kept += 1
          } else {
            local_map[param] = kept_params.length() +
              locals.length() +
              removed_params.length() -
              1 -
              removed
            removed += 1
          }
        }
        for local_idx = 0
            local_idx < locals.length()
            local_idx = local_idx + 1 {
          local_map[info.params.length() + local_idx] = kept_params.length() +
            local_idx
        }
        let new_locals = locals.copy()
        for slot = removed_params.length() - 1; slot >= 0; slot = slot - 1 {
          new_locals.push(removed_params[slot])
        }
        let (body, capture_map) = pass_lower_compact_captures_with_map(
          @lib.Func::new(
            new_locals,
            @lib.Expr::new(dae_rewrite_locals_instrs(body, local_map)),
          ),
          mod_.code_sec.unwrap().0[index - imported],
          kept_params,
        )
        local_remaps.push(Some(local_map.map(fn(index) { capture_map[index] })))
        bodies.push(body)
      }
    }
    let original_type_slot = dae2_type_slot(indices[index], 0)
    let type_info = infos[type_infos[original_type_slot]]
    let type_changed = type_info.param_locations.any(fn(loc) {
        !graph.used[loc]
      }) ||
      (!info.results.is_empty() && !graph.used[type_info.result_location])
    let private_element = match private_elements {
      Some(mask) => mask[index]
      None => false
    }
    if private_element &&
      (kept_params != info.params || results != info.results) {
      let group = match private_group {
        Some(group) => group
        None => {
          let group = Dae2PrivateGroup::new()
          private_group = Some(group)
          group
        }
      }
      group.slots.push(new_indices.length())
      group.signatures.push(
        @lib.SubType::comp_type(@lib.CompType::func(kept_params, results)),
      )
      // Assign the final group member index after all lowering has appended
      // its block signatures. Original module indices stay valid until then.
      new_indices.push(indices[index])
    } else if dae_function_exposure_blocks_boundary(exposure[index]) ||
      (kept_params == info.params && results == info.results && !type_changed) {
      new_indices.push(indices[index])
    } else {
      let metadata = context.subtypes[original_type_slot].metadata()
      new_indices.push(
        type_workspace.append_signature(kept_params, results, metadata),
      )
    }
  }
  perf_stop_timer_opt(perf, "detail:dae2:rewrite", rewrite_start)
  perf_record_timer_elapsed_opt(
    perf, "detail:dae2:rewrite:lift", rewrite_lift_us,
  )
  perf_record_timer_elapsed_opt(perf, "detail:dae2:rewrite:lower", lower_us)
  let finalize_start = perf_start_timer_opt(perf, "detail:dae2:finalize")
  let private_group_changed = match private_group {
    Some(group) => group.append(type_workspace, new_indices)
    None => false
  }
  let types = dae2_rewrite_type_section(
    type_workspace.types,
    graph,
    infos,
    type_infos,
  )
  // Signature rewriting can make a new private definition identical to an
  // existing function type. Resolve this only after type-family rewrites have
  // converged. Redirect newly allocated function signatures, never identities
  // already referenced by the source module. The shared canonicalizer admits
  // only single, non-subtyping function groups and compares full metadata.
  let @lib.TypeSec(rewritten_groups) = types
  let canonical_types = dfe_duplicate_simple_type_canonical_map(
    rewritten_groups,
  )
  for index = 0; index < new_indices.length(); index = index + 1 {
    if new_indices[index] is @lib.TypeIdx(raw) &&
      raw.to_int() >= context.subtypes.length() {
      new_indices[index] = dfe_rewrite_type_idx(
        new_indices[index],
        canonical_types,
      )
    }
  }
  let mut candidate = mod_
    .with_type_sec(types)
    .with_func_sec(@lib.FuncSec::new(new_indices))
    .with_code_sec(@lib.CodeSec::new(bodies))
  match rl_rewrite_name_sec(mod_.name_sec, imported, local_remaps) {
    Some(names) =>
      // Control wrappers and removed expression values can renumber labels.
      // Other index spaces retain their identities through this pass.
      candidate = candidate.with_name_sec(
        @lib.NameSec::new(
          module_name=names.module_name,
          func_names=names.func_names,
          local_names=names.local_names,
          label_names=None,
          type_names=names.type_names,
          table_names=names.table_names,
          memory_names=names.memory_names,
          global_names=names.global_names,
          elem_names=names.elem_names,
          data_names=names.data_names,
          field_names=names.field_names,
          tag_names=names.tag_names,
        ),
      )
    None => candidate = candidate.without_name_sec()
  }
  // Signature pruning can expose a statically selected adapted handler. Fold
  // only plain catches of fresh local tags with non-throwing payload producers.
  candidate = dae2_fold_known_local_throws(candidate)
  // Removed arguments can leave result wrappers around ordered producers.
  // Only flatten blocks without label-dependent control transfers.
  match cleanup_module_env_builds {
    Some(builds) => builds[0] += 1
    None => ()
  }
  // Every body is cleaned against the same finalized signature/type snapshot.
  let cleanup_env = @validate.Env::new().with_module(candidate)
  let cleanup_start = perf_start_timer_opt(perf, "detail:dae2:finalize:cleanup")
  let cleaned_bodies = candidate.code_sec.unwrap().0.map(fn(func) {
    pass_lower_cleanup_branchless_blocks(
      func,
      candidate,
      module_env=Some(cleanup_env),
      flatten_parameter_blocks=true,
    ).0
  })
  candidate = candidate.with_code_sec(@lib.CodeSec::new(cleaned_bodies))
  if private_group_changed {
    candidate = dae2_prune_private_element_source_types(candidate)
  }
  perf_stop_timer_opt(perf, "detail:dae2:finalize:cleanup", cleanup_start)
  // No mutation escapes until every definition and call site has its new
  // signature. The module dispatcher rebuilds the HOT module context/caches.
  if graph.used != census_source_used {
    census_errors[3] += 1
  }
  let finalized = dae2_finalize_candidate(candidate, perf~)
  perf_stop_timer_opt(perf, "detail:dae2:finalize", finalize_start)
  finalized
}
