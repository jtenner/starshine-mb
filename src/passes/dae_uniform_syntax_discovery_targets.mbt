///|
#valtype
priv struct DaeUniformSyntaxDiscoveryTarget {
  def_idx : Int32
  callee_abs : Int32
  param_count : Int32
  local_use : DaeLocalUse
}

///|
/// Syntax-only admission for one fixed-module discovery query. A recursive
/// uniform query follows a direct-caller edge, so include every ancestor.
/// Do not prune at an escape, tail call or cycle: this is a conservative set.
fn dae_uniform_syntax_discovery_target_closure(
  targets : Array[DaeUniformSyntaxDiscoveryTarget],
  facts : DaeCallBoundaryFacts,
  imported : Int32,
  defined : Int32,
) -> @hashmap.HashMap[Int32, Bool] {
  let admitted : @hashmap.HashMap[Int32, Bool] = @hashmap.new()
  let pending : Array[Int32] = []
  for target in targets {
    if !admitted.contains(target.callee_abs) {
      admitted.set(target.callee_abs, true)
      pending.push(target.callee_abs)
    }
  }
  let mut next = 0
  while next < pending.length() {
    let callee_abs = pending[next]
    next += 1
    for def_idx in dae_call_boundary_direct_callers(facts, callee_abs) {
      if def_idx >= 0 && def_idx < defined {
        let caller_abs = imported + def_idx
        if !admitted.contains(caller_abs) {
          admitted.set(caller_abs, true)
          pending.push(caller_abs)
        }
      }
    }
  }
  admitted
}

///|
fn dae_uniform_syntax_target_admitted(
  query : DaeUniformSyntaxQuery,
  callee_abs : Int32,
) -> Bool {
  match query.targets {
    Some(targets) => targets.contains(callee_abs)
    None => true
  }
}

///|
/// Count raw syntax only, saturating before unbounded child traversal. This
/// does not resolve control types, catch payloads or semantic candidates.
fn dae_uniform_syntax_bounded_nodes(
  instrs : Array[@lib.Instruction],
  limit : Int32,
) -> Int32 {
  if limit <= 0 {
    return 0
  }
  if instrs.length() >= limit {
    return limit
  }
  let mut nodes = instrs.length()
  for instr in instrs {
    match instr {
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        nodes += dae_uniform_syntax_bounded_nodes(body, limit - nodes)
      @lib.If(_, then_body, else_body) => {
        nodes += dae_uniform_syntax_bounded_nodes(then_body, limit - nodes)
        match else_body {
          Some(body) =>
            nodes += dae_uniform_syntax_bounded_nodes(body, limit - nodes)
          None => ()
        }
      }
      @lib.Try(_, @lib.Expr(body), catches, _) => {
        nodes += dae_uniform_syntax_bounded_nodes(body, limit - nodes)
        for catch_ in catches {
          if nodes >= limit {
            break
          }
          // Empty catch rows still cost traversal; include them in the cap.
          nodes += 1
          let @lib.Expr(body) = match catch_ {
            @lib.LegacyCatch(_, body) | @lib.LegacyCatchAll(body) => body
          }
          nodes += dae_uniform_syntax_bounded_nodes(body, limit - nodes)
        }
      }
      _ => continue
    }
    if nodes >= limit {
      return limit
    }
  }
  nodes
}

///|
/// Targets are emitted in numeric definition order by this pure discovery.
/// Defer an ancestor to its own existing iteration only when its hint tier
/// is at least as permissive. This borrows the target array and allocates
/// no visited set, map, candidate cache, or snapshot.
fn dae_uniform_syntax_ancestor_has_target_owner(
  targets : Array[DaeUniformSyntaxDiscoveryTarget],
  def_idx : Int32,
  wide_readonly : Bool,
) -> Bool {
  let mut low = 0
  let mut high = targets.length()
  while low < high {
    let middle = low + (high - low) / 2
    let middle_def = targets[middle].def_idx
    if middle_def < def_idx {
      low = middle + 1
    } else if middle_def > def_idx {
      high = middle
    } else {
      if !wide_readonly {
        return true
      }
      let target = targets[middle]
      let mut read_only_count = 0
      if target.param_count >= 32 {
        for p in 0..<target.param_count {
          if target.local_use.gets[p] && !target.local_use.writes[p] {
            read_only_count += 1
            if read_only_count >= 32 {
              return true
            }
          }
        }
      }
      return false
    }
  }
  false
}

///|
/// Return remaining caller visits; -1 retains shared admission. Flat scopes
/// use their borrowed length first. Only shorter scopes need a bounded raw
/// control-size hint. No candidate, catch, operand or visited state is cached.
fn dae_uniform_syntax_caller_work_hint(
  targets : Array[DaeUniformSyntaxDiscoveryTarget],
  callee_abs : Int32,
  wide_readonly : Bool,
  funcs : Array[@lib.Func],
  facts : DaeCallBoundaryFacts,
  imported : Int32,
  budget : Int32,
  depth : Int32,
) -> Int32 {
  if budget <= 0 || depth >= 8 {
    // Uncertain/deep graphs retain the previous shared route.
    return -1
  }
  let mut remaining = budget
  for caller_def in dae_call_boundary_direct_callers(facts, callee_abs) {
    if remaining <= 0 || caller_def < 0 || caller_def >= funcs.length() {
      return -1
    }
    remaining -= 1
    let caller_abs = imported + caller_def
    let forwards = dae_call_boundary_allows_forwarding(facts, caller_abs)
    // Raw51 baseline: pairs128 wins; pairs16/32/64 do not. A separate
    // high-readonly tier covers the modest width32 forwarding win; widths
    // 2/4/8/16 do not win. These are candidate gates, not optimal cutoffs.
    let node_limit = if wide_readonly && forwards { 64 } else { 256 }
    let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
    if body.length() >= node_limit ||
      dae_uniform_syntax_bounded_nodes(body, node_limit) >= node_limit {
      return -1
    }
    // Semantic forwarding rejects escaped/tail sources before any upstream
    // syntax query. An ineligible private forwarder must still be followed.
    if forwards &&
      !dae_uniform_syntax_ancestor_has_target_owner(
        targets, caller_def, wide_readonly,
      ) {
      remaining = dae_uniform_syntax_caller_work_hint(
        targets,
        caller_abs,
        wide_readonly,
        funcs,
        facts,
        imported,
        remaining,
        depth + 1,
      )
      if remaining < 0 {
        return -1
      }
    }
  }
  remaining
}

///|
fn dae_uniform_syntax_shared_work_admitted(
  targets : Array[DaeUniformSyntaxDiscoveryTarget],
  funcs : Array[@lib.Func],
  facts : DaeCallBoundaryFacts,
  imported : Int32,
) -> Bool {
  if targets.length() < 2 {
    return false
  }
  let mut remaining = 32
  for target in targets {
    let mut read_only_count = 0
    if target.param_count >= 32 {
      for p in 0..<target.param_count {
        if target.local_use.gets[p] && !target.local_use.writes[p] {
          read_only_count += 1
          if read_only_count >= 32 {
            break
          }
        }
      }
    }
    remaining = dae_uniform_syntax_caller_work_hint(
      targets,
      target.callee_abs,
      read_only_count >= 32,
      funcs,
      facts,
      imported,
      remaining,
      0,
    )
    if remaining <= 0 {
      return true
    }
  }
  false
}
