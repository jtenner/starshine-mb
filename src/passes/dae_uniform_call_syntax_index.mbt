///|
/// One non-mutating uniform-value query owns this state. No caller may retain
/// it across a callback, commit, or candidate-discovery return. Only syntax is
/// cached; candidate values and visited-context decisions remain uncached.
priv struct DaeUniformSyntaxQuery {
  source : @lib.Module
  type_indices : Array[@lib.TypeIdx]
  boundary_facts : DaeCallBoundaryFacts
  indexed : Bool
  syntax_visits : Array[Int32]?
  // Untimed probe: constructions, caller misses, caller hits, stored calls.
  syntax_stats : Array[Int32]?
  targets : @hashmap.HashMap[Int32, Bool]?
  callers : @hashmap.HashMap[Int32, DaeUniformSyntaxCaller]
}

///|
#valtype
priv struct DaeUniformSyntaxCall {
  scope : Array[@lib.Instruction]
  call_idx : Int32
  entry_stack_values : Int32
  preceding_tag : @lib.TagIdx?
}

///|
priv struct DaeUniformSyntaxCaller {
  body : Array[@lib.Instruction]
  entry_stack_values : Int32
  calls : @hashmap.HashMap[Int32, Array[DaeUniformSyntaxCall]]
  initial_tag_entries : Array[Int32]?
  mut first_tag : @lib.TagIdx?
  mut complete : Bool
}

///|
fn DaeUniformSyntaxQuery::new(
  source : @lib.Module,
  type_indices : Array[@lib.TypeIdx],
  boundary_facts : DaeCallBoundaryFacts,
  indexed : Bool,
  syntax_visits~ : Array[Int32]? = None,
  syntax_stats~ : Array[Int32]? = None,
  targets~ : @hashmap.HashMap[Int32, Bool]? = None,
) -> DaeUniformSyntaxQuery {
  match syntax_stats {
    Some(stats) if stats.length() == 4 => stats[0] += 1
    _ => ()
  }
  {
    source,
    type_indices,
    boundary_facts,
    indexed,
    syntax_visits,
    syntax_stats,
    targets,
    callers: @hashmap.new(),
  }
}

///|
fn dae_uniform_syntax_query_matches(
  query : DaeUniformSyntaxQuery,
  source : @lib.Module,
  type_indices : Array[@lib.TypeIdx],
  boundary_facts : DaeCallBoundaryFacts,
) -> Bool {
  query.indexed &&
  physical_equal(query.source, source) &&
  physical_equal(query.type_indices, type_indices) &&
  physical_equal(query.boundary_facts, boundary_facts)
}

///|
/// Match the retained visitor's depth-first order and control admission. A
/// failed child stops construction at its exact position. Earlier calls remain
/// in the index and must run before the trailing failure is returned.
fn dae_uniform_syntax_collect_calls(
  query : DaeUniformSyntaxQuery,
  instrs : Array[@lib.Instruction],
  entry_stack_values : Int32,
  caller : DaeUniformSyntaxCaller,
  tag_entries : Array[Int32],
) -> Bool {
  for idx in 0..<instrs.length() {
    match query.syntax_visits {
      Some(visits) => visits[0] += 1
      None => ()
    }
    match instrs[idx] {
      @lib.Call(func_idx) | @lib.ReturnCall(func_idx) => {
        let callee_abs = dae_func_idx_slot(func_idx)
        if !dae_uniform_syntax_target_admitted(query, callee_abs) {
          continue
        }
        let entries = match caller.calls.get(callee_abs) {
          Some(entries) => entries
          None => {
            let entries = []
            caller.calls.set(callee_abs, entries)
            entries
          }
        }
        match query.syntax_stats {
          Some(stats) if stats.length() == 4 => stats[3] += 1
          _ => ()
        }
        entries.push({
          scope: instrs,
          call_idx: idx,
          entry_stack_values,
          preceding_tag: caller.first_tag,
        })
      }
      @lib.Try(block_type, @lib.Expr(body), catches, _) => {
        let entry = match
          dae_control_entry_stack_values(block_type, query.source) {
          Some(entry) => entry
          None => return false
        }
        if !dae_uniform_syntax_collect_calls(
            query, body, entry, caller, tag_entries,
          ) {
          return false
        }
        for catch_ in catches {
          match catch_ {
            @lib.LegacyCatch(tag, _) if caller.first_tag is None =>
              caller.first_tag = Some(tag)
            _ => ()
          }
          let entry = match
            dae_legacy_catch_entry_stack_values(
              catch_,
              query.source,
              tag_entries,
            ) {
            Some(entry) => entry
            None => return false
          }
          let @lib.Expr(body) = match catch_ {
            @lib.LegacyCatch(_, body) | @lib.LegacyCatchAll(body) => body
          }
          if !dae_uniform_syntax_collect_calls(
              query, body, entry, caller, tag_entries,
            ) {
            return false
          }
        }
      }
      @lib.Block(_, @lib.Expr(_))
      | @lib.Loop(_, @lib.Expr(_))
      | @lib.TryTable(_, _, @lib.Expr(_))
      | @lib.If(_, _, _) => {
        let children = match
          dae_nested_control_children_evidence(instrs[idx], query.source) {
          Some(children) => children
          None => return false
        }
        if !dae_uniform_syntax_collect_calls(
            query,
            children.primary_body,
            children.entry_stack_values,
            caller,
            tag_entries,
          ) {
          return false
        }
        match children.secondary_body {
          Some(body) =>
            if !dae_uniform_syntax_collect_calls(
                query,
                body,
                children.entry_stack_values,
                caller,
                tag_entries,
              ) {
              return false
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  true
}

///|
fn dae_uniform_syntax_initial_tags_match(
  initial : Array[Int32]?,
  actual : Array[Int32],
) -> Bool {
  match initial {
    Some(entries) => entries == actual
    None => actual.is_empty()
  }
}

///|
/// Typed-catch admission initializes the shared cache only on its first empty
/// read. Replay that write before the first matching call after the catch, or
/// after all earlier calls if control admission is the failure barrier.
fn dae_uniform_syntax_replay_tag_initialization(
  mod_ : @lib.Module,
  preceding_tag : @lib.TagIdx?,
  entries : Array[Int32],
) -> Unit {
  match preceding_tag {
    Some(tag) if entries.is_empty() => {
      let _ = dae_legacy_tag_payload_count(mod_, tag, entries)
    }
    _ => ()
  }
}

///|
fn dae_collect_uniform_const_actuals_indexed(
  query : DaeUniformSyntaxQuery,
  instrs : Array[@lib.Instruction],
  callee_abs : Int32,
  param_types : Array[@lib.ValType],
  entry_stack_values : Int32,
  caller_abs : Int32,
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
  boundary_facts : DaeCallBoundaryFacts,
  visited : Array[Bool],
  seen : Array[Bool],
  invalid : Array[Bool],
  candidates : Array[@lib.Instruction?],
  active_params : Array[Bool],
  allow_immutable_global_get : Bool,
  uniform_resolution_cache : DaeUniformResolutionCache?,
  tag_entries : Array[Int32],
) -> Bool {
  let caller = match query.callers.get(caller_abs) {
    Some(caller) if physical_equal(caller.body, instrs) &&
      caller.entry_stack_values == entry_stack_values &&
      dae_uniform_syntax_initial_tags_match(
        caller.initial_tag_entries,
        tag_entries,
      ) => {
      match query.syntax_stats {
        Some(stats) if stats.length() == 4 => stats[2] += 1
        _ => ()
      }
      caller
    }
    _ => {
      match query.syntax_stats {
        Some(stats) if stats.length() == 4 => stats[1] += 1
        _ => ()
      }
      let caller : DaeUniformSyntaxCaller = {
        body: instrs,
        entry_stack_values,
        calls: @hashmap.new(),
        initial_tag_entries: if tag_entries.is_empty() {
          None
        } else {
          Some(tag_entries.copy())
        },
        first_tag: None,
        complete: false,
      }
      // Indexing may inspect a later catch before an earlier operand proof
      // fails. The caller's observable cache must not be written eagerly.
      let private_tags = tag_entries.copy()
      caller.complete = dae_uniform_syntax_collect_calls(
        query, instrs, entry_stack_values, caller, private_tags,
      )
      query.callers.set(caller_abs, caller)
      caller
    }
  }
  match caller.calls.get(callee_abs) {
    Some(calls) =>
      for call in calls {
        dae_uniform_syntax_replay_tag_initialization(
          mod_,
          call.preceding_tag,
          tag_entries,
        )
        // Keep the original source scope and offset for stack recovery and
        // local carriers. This executes the retained semantic visitor once.
        if !dae_collect_uniform_const_actuals_instrs(
            call.scope,
            callee_abs,
            param_types,
            call.entry_stack_values,
            caller_abs,
            mod_,
            func_type_indices,
            boundary_facts,
            visited,
            seen,
            invalid,
            candidates,
            allow_immutable_global_get~,
            collect_params=Some(active_params),
            uniform_resolution_cache~,
            syntax_query=Some(query),
            legacy_tag_entries=Some(tag_entries),
            single_call_idx=Some(call.call_idx),
          ) {
          return false
        }
      }
    None => ()
  }
  dae_uniform_syntax_replay_tag_initialization(
    mod_,
    caller.first_tag,
    tag_entries,
  )
  caller.complete
}

///|
fn dae_uniform_syntax_query_values(
  query : DaeUniformSyntaxQuery,
  graph : DaeCurrentBoundaryGraph,
  callee_abs : Int32,
  param_count : Int32,
  allow_immutable_global_get~ : Bool = false,
  collect_params~ : Array[Bool]? = None,
) -> Array[@lib.Instruction?]? {
  dae_collect_uniform_const_actuals_from_boundary_facts(
    graph.mod_,
    callee_abs,
    param_count,
    graph.snapshot.type_indices,
    graph.snapshot.boundary_facts,
    allow_immutable_global_get~,
    collect_params~,
    syntax_query=Some(query),
  )
}
