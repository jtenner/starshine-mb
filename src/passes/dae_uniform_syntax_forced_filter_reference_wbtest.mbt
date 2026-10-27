///|
fn dae_s11_forced_filtered_discovery(
  mod_ : @lib.Module,
  call_facts : DaeCurrentCallFacts,
  max_def_exclusive : Int32,
  allow_immutable_global_get~ : Bool = false,
  syntax_visits~ : Array[Int32]? = None,
  syntax_stats~ : Array[Int32]? = None,
) -> Array[Int32] {
  let candidates : Array[Int32] = []
  let imported = dae_imported_func_count(mod_)
  let boundary_facts = dae_call_boundary_facts_from_current(call_facts)
  let type_indices = dae_collect_func_type_indices(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return candidates
  }
  let limit = if max_def_exclusive >= 0 && max_def_exclusive < funcs.length() {
    max_def_exclusive
  } else {
    funcs.length()
  }
  let targets : Array[DaeUniformSyntaxDiscoveryTarget] = []
  for def_idx in 0..<limit {
    let callee_abs = imported + def_idx
    let boundary_candidate = match
      dae_call_boundary_candidate(boundary_facts, callee_abs, def_idx~) {
      Some(candidate) => candidate
      None => continue
    }
    if !boundary_candidate.owned ||
      boundary_candidate.has_self_direct_caller ||
      !boundary_candidate.allows_nonself_direct_rewrite {
      continue
    }
    let func_type = match
      dae_resolve_func_type(mod_, type_indices, callee_abs) {
      Some(ft) => ft
      None => continue
    }
    let @lib.FuncType(params, _) = func_type
    if params.is_empty() {
      continue
    }
    let @lib.Func(locals, _) = funcs[def_idx]
    let local_use = dae_local_use_for_callee(
      funcs[def_idx],
      params.length() + locals.length(),
      callee_abs,
      params.length(),
    )
    let mut has_dead_param = false
    let mut has_read_only_param = false
    for p in 0..<params.length() {
      if !local_use.gets[p] {
        has_dead_param = true
      } else if !local_use.writes[p] {
        has_read_only_param = true
      }
    }
    if !has_dead_param && has_read_only_param {
      targets.push({
        def_idx,
        callee_abs,
        param_count: params.length(),
        local_use,
      })
    }
  }
  // Test/benchmark-only forced owner; current filtering and semantic helpers.
  let syntax_query = Some(
    DaeUniformSyntaxQuery::new(
      mod_,
      type_indices,
      boundary_facts,
      true,
      syntax_visits~,
      syntax_stats~,
      targets=Some(
        dae_uniform_syntax_discovery_target_closure(
          targets,
          boundary_facts,
          imported,
          funcs.length(),
        ),
      ),
    ),
  )
  for target in targets {
    let uniform_const_params = dae_collect_uniform_const_actuals_from_boundary_facts(
      mod_,
      target.callee_abs,
      target.param_count,
      type_indices,
      boundary_facts,
      allow_immutable_global_get~,
      syntax_query~,
    )
    let mut any_const = false
    for p in 0..<target.param_count {
      if !target.local_use.writes[p] {
        match uniform_const_params {
          Some(values) =>
            match values[p] {
              Some(_) => any_const = true
              None => ()
            }
          None => ()
        }
      }
    }
    if any_const {
      candidates.push(target.def_idx)
    }
  }
  candidates
}

///|
fn dae_s11_multi_query_input(width : Int32, nested : Bool) -> @lib.Module {
  let wat = StringBuilder()
  wat.write_string("(module ")
  for name in ["a", "b"] {
    wat.write_string("(func $")
    wat.write_string(name)
    wat.write_string(" (param ")
    for _ in 0..<width {
      wat.write_string("i32 ")
    }
    wat.write_string(") (result i32) local.get 0 ")
    for p in 1..<width {
      wat.write_string("local.get ")
      wat.write_string(p.to_string())
      wat.write_string(" i32.add ")
    }
    wat.write_string(") ")
  }
  wat.write_string("(func $forward (param ")
  for _ in 0..<width {
    wat.write_string("i32 ")
  }
  wat.write_string(") (result i32) ")
  for name in ["a", "b"] {
    for p in 0..<width {
      wat.write_string("local.get ")
      wat.write_string(p.to_string())
      wat.write_string(" ")
    }
    wat.write_string("call $")
    wat.write_string(name)
    if name == "a" {
      wat.write_string(" drop ")
    }
  }
  wat.write_string(") (func (export \"run\") (result i32) ")
  if nested {
    wat.write_string("block (result i32) ")
  }
  for _ in 0..<width {
    wat.write_string("i32.const 7 ")
  }
  wat.write_string("call $forward ")
  if nested {
    wat.write_string("end ")
  }
  wat.write_string("))")
  pass_test_module_from_wat(wat.to_string()).with_custom_secs([
    @lib.CustomSec::new(@lib.Name::new("syntax.work.keep"), b"unchanged"),
  ])
}

///|
fn dae_s11_admission_query(
  input : @lib.Module,
  facts : DaeCurrentCallFacts,
  mode : Int32,
) -> Array[Int32] {
  match mode {
    0 =>
      dae_collect_exact_literal_candidate_defs_with_facts(
        input,
        facts,
        -1,
        indexed_syntax=false,
      )
    1 => dae_s11_forced_filtered_discovery(input, facts, -1)
    _ => dae_collect_exact_literal_candidate_defs_with_facts(input, facts, -1)
  }
}
