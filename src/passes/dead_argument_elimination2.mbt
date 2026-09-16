///|
// Binaryen 132 DAE2: parameter and whole-result liveness share a least fixed
// point. All locations start unused. Observable uses seed a backwards worklist;
// a forwarding cycle does not become live merely because it contains a cycle.
priv struct Dae2Graph {
  edges : Array[Array[Int]]
  used : Array[Bool]
  work : Array[Int]
}

///|
fn Dae2Graph::new() -> Dae2Graph {
  { edges: [], used: [], work: [], }
}

///|
fn Dae2Graph::location(self : Dae2Graph) -> Int {
  let id = self.used.length()
  self.edges.push([])
  self.used.push(false)
  id
}

///|
fn Dae2Graph::edge(self : Dae2Graph, consumer : Int, source : Int) -> Unit {
  if consumer >= 0 && source >= 0 {
    self.edges[consumer].push(source)
  }
}

///|
fn Dae2Graph::observe(self : Dae2Graph, location : Int) -> Unit {
  if location >= 0 && !self.used[location] {
    self.used[location] = true
    self.work.push(location)
  }
}

///|
fn Dae2Graph::solve(self : Dae2Graph) -> Unit {
  // Each location enters the queue once, so convergence is bounded by the
  // graph size, including recursive call and result dependencies.
  for cursor = 0; cursor < self.work.length(); cursor = cursor + 1 {
    for source in self.edges[self.work[cursor]] {
      self.observe(source)
    }
  }
}

///|
priv struct Dae2Function {
  params : Array[@lib.ValType]
  results : Array[@lib.ValType]
  param_locations : Array[Int]
  result_location : Int
  node_locations : Array[Int]
  call_infos : Array[Int]
}

///|
fn dae2_node_location(info : Dae2Function, node : Int) -> Int {
  if node >= 0 && node < info.node_locations.length() {
    info.node_locations[node]
  } else {
    -1
  }
}

///|
fn dae2_observe_branch_target(
  graph : Dae2Graph,
  info : Dae2Function,
  func : @ir.HotFunc,
  target : @ir.LabelId,
) -> Unit {
  if target == @ir.HOT_IMPLICIT_FUNCTION_LABEL {
    graph.observe(info.result_location)
    return
  }
  if !@ir.hot_label_is_live(func, target) {
    abort("DAE2 branch target is not a live ordinary label")
  }
  graph.observe(dae2_node_location(info, @ir.hot_label_get(func, target).owner))
}

///|
fn dae2_removable_node(func : @ir.HotFunc, node : Int) -> Bool {
  let op = @ir.hot_node_get(func, node).op
  // Local writes require DAE2's reaching-definition liveness proof. They
  // are not generally discardable when another pass proves a value constant.
  op is @ir.LocalSet ||
  op is @ir.LocalTee ||
  pass_can_discard_unused_value(func, node)
}

///|
fn dae2_region_sources(
  graph : Dae2Graph,
  info : Dae2Function,
  func : @ir.HotFunc,
  consumer : Int,
  roots : Array[Int],
) -> Unit {
  for root in roots {
    if root >= 0 && @ir.hot_node_result_arity(func, root) > 0 {
      graph.edge(consumer, dae2_node_location(info, root))
    }
  }
}

///|
fn dae2_analyze_function(
  graph : Dae2Graph,
  infos : Array[Dae2Function],
  index : Int,
  type_infos : Array[Int],
  func : @ir.HotFunc,
) -> Unit {
  let info = infos[index]
  let cfg = @ir.cfg_build(func)
  let locals = @ir.local_graph_build_full_flow(func, cfg)
  let writes : Array[Array[Int]] = Array::makei(@ir.hot_local_count(func), fn(
    _,
  ) {
    []
  })
  for node = 0; node < info.node_locations.length(); node = node + 1 {
    let data = @ir.hot_node_get(func, node)
    if data.op is @ir.LocalSet || data.op is @ir.LocalTee {
      writes[data.imm0].push(node)
    }
  }
  for node = 0; node < info.node_locations.length(); node = node + 1 {
    if !@ir.hot_node_is_live(func, node) {
      continue
    }
    let value = info.node_locations[node]
    let data = @ir.hot_node_get(func, node)
    let children = @ir.hot_child_span(func, node)
    match data.op {
      @ir.LocalGet => {
        let sources = @ir.local_graph_reaching_sources_for_get(locals, node)
        // A get inside control not represented by LocalGraph has no recorded
        // sources. That is unknown, not proof that its entry value is unused.
        if sources.is_empty() {
          if data.imm0 < info.params.length() {
            graph.edge(value, info.param_locations[data.imm0])
          }
          for write in writes[data.imm0] {
            graph.edge(value, dae2_node_location(info, write))
          }
        }
        for source in sources {
          match source {
            @ir.EntrySource(local_idx) if local_idx < info.params.length() =>
              graph.edge(value, info.param_locations[local_idx])
            @ir.SetSource(write) =>
              graph.edge(value, dae2_node_location(info, write))
            _ => ()
          }
        }
      }
      @ir.Call
      | @ir.ReturnCall
      | @ir.CallIndirect
      | @ir.CallRef
      | @ir.ReturnCallIndirect
      | @ir.ReturnCallRef => {
        let callee = dae2_call_info(infos, type_infos, func, node)
        let indirect = !(data.op is @ir.Call || data.op is @ir.ReturnCall)
        for arg = 0; arg < callee.params.length(); arg = arg + 1 {
          graph.edge(
            callee.param_locations[arg],
            dae2_node_location(info, children[arg]),
          )
        }
        if indirect {
          graph.observe(
            dae2_node_location(info, children[children.length() - 1]),
          )
        }
        if data.op is @ir.ReturnCall ||
          data.op is @ir.ReturnCallIndirect ||
          data.op is @ir.ReturnCallRef {
          graph.edge(info.result_location, callee.result_location)
          graph.edge(callee.result_location, info.result_location)
        } else {
          graph.edge(value, callee.result_location)
        }
      }
      @ir.Return =>
        for child in children {
          graph.edge(info.result_location, dae2_node_location(info, child))
        }
      @ir.Drop => ()
      @ir.Block | @ir.Loop =>
        dae2_region_sources(graph, info, func, value, children)
      @ir.If => {
        graph.observe(dae2_node_location(info, children[0]))
        for arm = 1; arm < children.length(); arm = arm + 1 {
          graph.edge(value, dae2_node_location(info, children[arm]))
        }
      }
      @ir.TryTable => {
        for child in children {
          graph.observe(dae2_node_location(info, child))
        }
        for arm in @ir.hot_catch_info_get(func, data.imm1).catches {
          let label = match arm {
            @ir.HotCatchArm::CatchArm(_, label)
            | @ir.HotCatchArm::CatchRefArm(_, label)
            | @ir.HotCatchArm::CatchAllArm(label)
            | @ir.HotCatchArm::CatchAllRefArm(label) => label
          }
          dae2_observe_branch_target(graph, info, func, label)
        }
      }
      @ir.Continuation => {
        for child in children {
          graph.observe(dae2_node_location(info, child))
        }
        for label in @ir.hot_continuation_targets(func, node) {
          dae2_observe_branch_target(graph, info, func, label)
        }
      }
      @ir.Br
      | @ir.BrIf
      | @ir.BrTable
      | @ir.BrOnNull
      | @ir.BrOnNonNull
      | @ir.BrOnCast
      | @ir.BrOnCastFail => {
        for child in children {
          graph.observe(dae2_node_location(info, child))
        }
        // Branch payload types stay fixed. A result-bearing target therefore
        // keeps its fallthrough value as well as its incoming branch values.
        for label in @ir.hot_branch_table_targets_for_node(func, node) {
          dae2_observe_branch_target(graph, info, func, label)
        }
        match @ir.hot_branch_target(func, node) {
          Some(label) => dae2_observe_branch_target(graph, info, func, label)
          None => ()
        }
      }
      _ =>
        for child in children {
          let source = dae2_node_location(info, child)
          if dae2_removable_node(func, node) {
            graph.edge(value, source)
          } else {
            graph.observe(source)
          }
        }
    }
  }
  dae2_region_sources(
    graph,
    info,
    func,
    info.result_location,
    @ir.hot_root_span(func),
  )
}

///|
fn dae2_discard(func : @ir.HotFunc, node : Int) -> Int {
  if @ir.hot_node_result_arity(func, node) > 0 {
    @ir.hot_build_drop(func, node)
  } else {
    node
  }
}

///|
fn dae2_void_sequence(func : @ir.HotFunc, nodes : Array[Int]) -> Int {
  let kept = nodes.filter(fn(id) { !(@ir.hot_node_get(func, id).op is @ir.Nop) })
  match kept {
    [] => @ir.hot_build_nop(func)
    [node] => node
    _ => @ir.hot_build_block(func, @lib.BlockType::void_(), kept)
  }
}

///|
fn dae2_rewrite_node(
  graph : Dae2Graph,
  infos : Array[Dae2Function],
  index : Int,
  func : @ir.HotFunc,
  node : Int,
  memo : Array[Int],
  old_arities : Array[Int],
  lower_state : HotPipelineLowerState,
  type_infos : Array[Int],
) -> Int {
  if node < 0 {
    return node
  }
  if memo[node] >= 0 {
    // A lifted stack producer may be referenced once per result lane. Once
    // its result disappears, those references must not repeat its effects.
    if old_arities[node] > 0 && @ir.hot_node_result_arity(func, memo[node]) == 0 {
      return @ir.hot_build_nop(func)
    }
    return memo[node]
  }
  let info = infos[index]
  let data = @ir.hot_node_get(func, node)
  let used = graph.used[info.node_locations[node]]
  let removable = dae2_removable_node(func, node)
  let old_children = @ir.hot_child_span(func, node)
  let children = old_children.map(fn(child) {
    dae2_rewrite_node(
      graph, infos, index, func, child, memo, old_arities, lower_state, type_infos,
    )
  })
  let replacement = match data.op {
    @ir.Call
    | @ir.ReturnCall
    | @ir.CallIndirect
    | @ir.CallRef
    | @ir.ReturnCallIndirect
    | @ir.ReturnCallRef => {
      let callee = dae2_call_info(infos, type_infos, func, node)
      let indirect = !(data.op is @ir.Call || data.op is @ir.ReturnCall)
      let tail = data.op is @ir.ReturnCall ||
        data.op is @ir.ReturnCallIndirect ||
        data.op is @ir.ReturnCallRef
      let args : Array[Int] = []
      let prefix : Array[Int] = []
      let removed = callee.param_locations.any(fn(loc) { !graph.used[loc] })
      let mut arg = 0
      while arg < callee.params.length() {
        let producer = old_children[arg]
        let mut end = arg + 1
        while end < callee.params.length() && old_children[end] == producer {
          end += 1
        }
        if removed &&
          end - arg > 1 &&
          @ir.hot_node_result_arity(func, children[arg]) > 1 {
          // The stack supplies tuple lanes in order, but consumes them from
          // the top. Capture all lanes before selecting kept arguments.
          let slots = Array::make(end - arg, -1)
          for lane = end - 1; lane >= arg; lane = lane - 1 {
            let scratch = @ir.hot_append_body_local(func, callee.params[lane])
            slots[lane - arg] = scratch
            prefix.push(@ir.hot_build_local_set(func, scratch, children[lane]))
          }
          for lane = arg; lane < end; lane = lane + 1 {
            if graph.used[callee.param_locations[lane]] {
              args.push(@ir.hot_build_local_get(func, slots[lane - arg]))
            }
          }
          arg = end
          continue
        }
        if graph.used[callee.param_locations[arg]] {
          if removed {
            // Localize kept arguments so removed arguments retain their
            // position relative to every kept argument's observable effects.
            let scratch_type = match
              @ir.hot_type_results(func, @ir.hot_node_type(func, children[arg])) {
              [value_type] => value_type
              _ => callee.params[arg]
            }
            let scratch = @ir.hot_append_body_local(func, scratch_type)
            prefix.push(@ir.hot_build_local_set(func, scratch, children[arg]))
            args.push(@ir.hot_build_local_get(func, scratch))
          } else {
            args.push(children[arg])
          }
        } else {
          prefix.push(dae2_discard(func, children[arg]))
        }
        arg += 1
      }
      if indirect {
        args.push(children[children.length() - 1])
      }
      if !tail && !graph.used[callee.result_location] {
        @ir.hot_replace_node(
          func,
          node,
          @ir.hot_make_simple_node(
            data.op,
            @ir.hot_type_void(func),
            data.flags,
            data.imm0,
            data.imm1,
            [],
          ),
        )
      }
      ignore(@ir.hot_replace_child_span(func, node, args))
      let call = if !used && !tail { dae2_discard(func, node) } else { node }
      let prefix = prefix.filter(fn(id) {
        !(@ir.hot_node_get(func, id).op is @ir.Nop)
      })
      if prefix.is_empty() {
        call
      } else {
        prefix.push(call)
        let result_types = @ir.hot_type_results(
          func,
          @ir.hot_node_type(func, call),
        )
        if result_types.is_empty() {
          dae2_void_sequence(func, prefix)
        } else {
          // Intern a resolved signature to retain multi-value calls.
          let block_type = match result_types {
            [value_type] => @lib.BlockType::val_type(value_type)
            _ =>
              @lib.BlockType::type_idx(
                run_hot_pipeline_lower_intern_block_result_type_idx(
                  lower_state, result_types,
                ),
              )
          }
          @ir.hot_build_resolved_block(
            func,
            block_type,
            [],
            result_types,
            prefix,
          )
        }
      }
    }
    @ir.Return =>
      if graph.used[info.result_location] {
        ignore(@ir.hot_replace_child_span(func, node, children))
        node
      } else {
        let parts = children.map(fn(child) { dae2_discard(func, child) })
        ignore(@ir.hot_replace_child_span(func, node, []))
        parts.push(node)
        dae2_void_sequence(func, parts)
      }
    @ir.Block | @ir.Loop | @ir.If => {
      if !used {
        @ir.hot_control_result_type_set(func, node, @ir.hot_type_void(func))
      }
      let next = if data.op is @ir.If || used {
        children
      } else {
        children.map(fn(child) { dae2_discard(func, child) })
      }
      ignore(@ir.hot_replace_child_span(func, node, next))
      node
    }
    @ir.Drop =>
      dae2_void_sequence(
        func,
        children.map(fn(child) { dae2_discard(func, child) }),
      )
    _ if removable && !used =>
      dae2_void_sequence(
        func,
        children.map(fn(child) { dae2_discard(func, child) }),
      )
    _ => {
      ignore(@ir.hot_replace_child_span(func, node, children))
      if used {
        node
      } else {
        dae2_discard(func, node)
      }
    }
  }
  memo[node] = replacement
  replacement
}

///|
fn dae2_run_module_pass(
  mod_ : @lib.Module,
  closed_world : Bool,
) -> Result[@lib.Module, String] {
  let original = mod_
  let mod_ = match dae2_prepare_legacy_handlers(mod_) {
    Ok(prepared) => prepared
    Err(err) => return Err(err)
  }
  let context = @ir.hot_module_context_from_module(mod_)
  let imported = dae_imported_func_count(mod_)
  let indices = dae_collect_func_type_indices(mod_)
  let total_funcs = indices.length()
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
    let param_locations = params.map(fn(_) { graph.location() })
    let result_location = graph.location()
    infos.push({
      params,
      results,
      param_locations,
      result_location,
      node_locations: [],
      call_infos: [],
    })
  }
  let exposure = dae_collect_original_exposure(
    dae2_exposure_module(mod_),
    total_funcs,
    indices,
  )
  let type_infos = dae2_prepare_type_locations(
    mod_, context, graph, infos, exposure, closed_world,
  )
  // Keep only the dependency graph between functions. Each HOT body and its
  // CFG/local overlays die after this iteration; relift a body for mutation
  // only after the complete module-wide fixed point has been solved.
  for index = imported; index < total_funcs; index = index + 1 {
    let func = match dae2_lift_for_analysis(mod_, context, index) {
      Ok(func) => func
      Err(err) => return Err(err)
    }
    let info = infos[index]
    for _ in 0..<@ir.hot_node_count(func) {
      info.node_locations.push(graph.location())
    }
    dae2_pin_intrinsic_targets(context, graph, infos, func)
    for node = 0; node < @ir.hot_node_count(func); node = node + 1 {
      match @ir.hot_node_get(func, node).op {
        @ir.Call
        | @ir.ReturnCall
        | @ir.CallIndirect
        | @ir.ReturnCallIndirect
        | @ir.CallRef
        | @ir.ReturnCallRef =>
          info.call_infos.push(dae2_call_info_index(type_infos, func, node))
        _ => ()
      }
    }
    dae2_analyze_function(graph, infos, index, type_infos, func)
  }
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
  if !signature_change {
    // Captures and legacy-handler adaptation are analysis scaffolding. When
    // no definition or call signature changes, keep the original expression
    // structure rather than making users pay for that scaffolding in output.
    return Ok(dfe_cleanup_simple_type_encoding(original))
  }
  let mut types = match mod_.type_sec {
    Some(types) => types
    None => return Ok(mod_)
  }
  let new_indices : Array[@lib.TypeIdx] = []
  let bodies : Array[@lib.Func] = []
  let local_remaps : Array[Array[Int]?] = []
  let control_types : @hashmap.HashMap[Int, @lib.TypeIdx] = @hashmap.new()
  for index = imported; index < total_funcs; index = index + 1 {
    let info = infos[index]
    let func = match dae2_lift_for_analysis(mod_, context, index) {
      Ok(func) => func
      Err(err) => return Err(err)
    }
    if @ir.hot_node_count(func) != info.node_locations.length() {
      return Err("dae2: analysis relift changed node identities")
    }
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
    let lower_state : HotPipelineLowerState = {
      next_type_sec: Some(types),
      type_sec_changed: false,
    }
    dae2_preserve_control_types(
      func, context, graph, infos, type_infos, lower_state, control_types,
    )
    if !dae2_function_needs_rewrite(graph, infos, type_infos, info, func) {
      match lower_state.next_type_sec {
        Some(next) => types = next
        None => ()
      }
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
      let memo = Array::make(info.node_locations.length(), -1)
      let roots = @ir.hot_root_span(func).map(fn(node) {
        let rewritten = dae2_rewrite_node(
          graph, infos, index, func, node, memo, old_arities, lower_state, type_infos,
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
      match lower_state.next_type_sec {
        Some(next) => types = next
        None => ()
      }
      match @ir.hot_verify_core(func) {
        Ok(_) => ()
        Err(err) => return Err("dae2: rewritten HOT function \{index}: \{err}")
      }
      match @ir.hot_verify_control(func) {
        Ok(_) => ()
        Err(err) =>
          return Err("dae2: rewritten HOT control in function \{index}: \{err}")
      }
      let @lib.Func(locals, @lib.Expr(body)) = @ir.hot_lower_func_unverified(
        func,
      )
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
      for local_idx = 0; local_idx < locals.length(); local_idx = local_idx + 1 {
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
    let original_type_slot = dae2_type_slot(indices[index], 0)
    let type_info = infos[type_infos[original_type_slot]]
    let type_changed = type_info.param_locations.any(fn(loc) {
        !graph.used[loc]
      }) ||
      (!info.results.is_empty() && !graph.used[type_info.result_location])
    if dae_function_exposure_blocks_boundary(exposure[index]) ||
      (kept_params == info.params && results == info.results && !type_changed) {
      new_indices.push(indices[index])
    } else {
      let metadata = context.subtypes[original_type_slot].metadata()
      let @lib.TypeSec(groups) = types
      let next_groups = groups.copy()
      new_indices.push(
        @lib.TypeIdx::new(
          dae_type_sec_flattened_length(types).reinterpret_as_uint(),
        ),
      )
      next_groups.push(
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(kept_params, results),
            metadata~,
          ),
        ),
      )
      types = @lib.TypeSec::new(next_groups)
    }
  }
  types = dae2_rewrite_type_section(types, graph, infos, type_infos)
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
  let cleaned_bodies = candidate.code_sec.unwrap().0.map(fn(func) {
    pass_lower_cleanup_branchless_blocks(func, candidate).0
  })
  candidate = candidate.with_code_sec(@lib.CodeSec::new(cleaned_bodies))
  // No mutation escapes until every definition and call site has its new
  // signature. The module dispatcher rebuilds the HOT module context/caches.
  match @validate.validate_module(candidate) {
    Ok(_) =>
      Ok(
        dfe_cleanup_simple_type_encoding(
          dae_prune_unused_simple_func_types(candidate, preserve_names=true),
        ),
      )
    Err(err) => Err("dae2: invalid rewritten module: \{err}")
  }
}

///|
fn dae2_signature_changes(graph : Dae2Graph, info : Dae2Function) -> Bool {
  info.param_locations.any(fn(location) { !graph.used[location] }) ||
  (!info.results.is_empty() && !graph.used[info.result_location])
}

///|
fn dae2_lift_for_analysis(
  mod_ : @lib.Module,
  context : @ir.HotModuleContext,
  index : Int,
) -> Result[@ir.HotFunc, String] {
  match
    @ir.hot_lift_func_with_context_result(
      mod_,
      @lib.FuncIdx::new(index.reinterpret_as_uint()),
      context,
      capture_stack_locals=true,
      materialize_multi_values=true,
    ) {
    Ok(func) => {
      // Use the same deterministic capture preparation in both phases.
      ignore(@ir.hot_repair_ordered_catch_payloads(func))
      Ok(func)
    }
    Err(err) => Err("dae2: lift function \{index}: \{err}")
  }
}
