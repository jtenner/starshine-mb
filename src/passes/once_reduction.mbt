///|
priv struct ORBlockId(Int) derive(Eq, Hash)

///|
priv struct ORBlock {
  events : Array[Int]
  succs : Array[ORBlockId]
}

///|
priv enum OREventKind {
  GlobalSet(GlobalIdx, Bool)
  Call(FuncIdx, Int)
}

///|
priv struct ORCFG {
  entry : ORBlockId
  blocks : Map[ORBlockId, ORBlock]
  preds : Map[ORBlockId, Array[ORBlockId]]
  events : Map[Int, OREventKind]
}

///|
priv struct ORBuildState {
  mut next_block : Int
  mut next_event : Int
  blocks : Map[ORBlockId, ORBlock]
  events : Map[Int, OREventKind]
}

///|
priv struct ORScanState {
  env : Env
  read_globals : Map[GlobalIdx, Int]
}

///|
priv struct OROptInfo {
  once_globals : Map[GlobalIdx, Bool]
  once_funcs : Map[FuncIdx, GlobalIdx?]
  mut once_globals_set_in_funcs : Map[FuncIdx, Set[GlobalIdx]]
}

///|
priv struct ORRewriteState {
  nops : Set[Int]
  mut next_event : Int
}

///|
priv struct OROptimizeResult {
  func : Func
  summary : Set[GlobalIdx]
}

///|
fn ORBuildState::new() -> ORBuildState {
  { next_block: 0, next_event: 0, blocks: Map::new(), events: Map::new() }
}

///|
fn ORRewriteState::new(nops : Set[Int]) -> ORRewriteState {
  { nops, next_event: 0 }
}

///|
fn or_is_integer_type(t : ValType) -> Bool {
  match t {
    NumTypeValType(I32NumType) | NumTypeValType(I64NumType) => true
    _ => false
  }
}

///|
fn or_is_nonzero_int_const(instr : TInstr) -> Bool {
  match instr {
    TI32Const(I32(v)) => v > 0
    TI64Const(I64(v)) => v > 0L
    _ => false
  }
}

///|
fn or_is_integer_tinstr(instr : TInstr, env : Env) -> Bool {
  match lcs_infer_tinstr_type(instr, env) {
    Some(t) => or_is_integer_type(t)
    None => false
  }
}

///|
fn or_count_imported_funcs(mod : Module) -> Int {
  let mut n = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, FuncExternType(_)) => n += 1
          _ => ()
        }
      }
    None => ()
  }
  n
}

///|
fn or_count_imported_globals(mod : Module) -> Int {
  let mut n = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, GlobalExternType(_)) => n += 1
          _ => ()
        }
      }
    None => ()
  }
  n
}

///|
fn or_total_funcs(mod : Module) -> Int {
  let env = Env::new().with_module(mod)
  env.funcs.length()
}

///|
fn or_collect_exported_globals(mod : Module) -> Set[GlobalIdx] {
  let out : Set[GlobalIdx] = Set::new()
  match mod.export_sec {
    Some(ExportSec(exports)) =>
      for ex in exports {
        match ex {
          Export(_, GlobalExternIdx(idx)) => out.add(idx)
          _ => ()
        }
      }
    None => ()
  }
  out
}

///|
fn or_collect_global_types(mod : Module) -> Array[GlobalType] {
  let out : Array[GlobalType] = []
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, GlobalExternType(gt)) => out.push(gt)
          _ => ()
        }
      }
    None => ()
  }
  match mod.global_sec {
    Some(GlobalSec(globals)) =>
      for g in globals {
        match g {
          Global(gt, _) => out.push(gt)
        }
      }
    None => ()
  }
  out
}

///|
fn or_get_defined_func(mod : Module, abs_func_idx : Int) -> Func? {
  let imported = or_count_imported_funcs(mod)
  let def_idx = abs_func_idx - imported
  if def_idx < 0 {
    return None
  }
  match mod.code_sec {
    Some(CodeSec(funcs)) if def_idx < funcs.length() => Some(funcs[def_idx])
    _ => None
  }
}

///|
fn or_set_defined_func(mod : Module, def_idx : Int, func : Func) -> Module {
  let mut out_mod = mod
  match out_mod.code_sec {
    Some(CodeSec(funcs)) if def_idx >= 0 && def_idx < funcs.length() => {
      let next_funcs = funcs.copy()
      next_funcs[def_idx] = func
      out_mod = out_mod.with_code_sec(CodeSec::new(next_funcs))
      out_mod
    }
    _ => out_mod
  }
}

///|
fn or_get_once_global(body : TExpr) -> GlobalIdx? {
  match body {
    TExpr([TBlock(_, TExpr(items))]) if items.length() >= 2 =>
      match items[0] {
        TIf(_, TGlobalGet(g0), TExpr([TReturn(ret_vals)]), None) if ret_vals.length() ==
          0 =>
          match items[1] {
            TGlobalSet(g1, value) =>
              if g0 == g1 &&
                !is_unreachable_instr(value) &&
                or_is_nonzero_int_const(value) {
                Some(g0)
              } else {
                None
              }
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn or_add_read(reads : Map[GlobalIdx, Int], idx : GlobalIdx) -> Unit {
  reads[idx] = reads.get(idx).unwrap_or(0) + 1
}

///|
fn or_scan_instr(
  instr : TInstr,
  reachable : Bool,
  state : ORScanState,
  info : OROptInfo,
) -> Unit {
  if !reachable {
    return
  }
  match instr {
    TGlobalGet(idx) => or_add_read(state.read_globals, idx)
    TGlobalSet(idx, value) => {
      if info.once_globals.get(idx).unwrap_or(false) &&
        !is_unreachable_instr(value) &&
        or_is_integer_tinstr(value, state.env) &&
        !or_is_nonzero_int_const(value) {
        info.once_globals[idx] = false
      }
      for child in eval_children(instr) {
        or_scan_instr(child, true, state, info)
      }
    }
    TBlock(_, body) | TLoop(_, body) | TTryTable(_, _, body) =>
      or_scan_texpr(body, true, state, info)
    TIf(_, cond, then_body, else_body) => {
      or_scan_instr(cond, true, state, info)
      or_scan_texpr(then_body, true, state, info)
      match else_body {
        Some(other) => or_scan_texpr(other, true, state, info)
        None => ()
      }
    }
    _ =>
      for child in eval_children(instr) {
        or_scan_instr(child, true, state, info)
      }
  }
}

///|
fn or_scan_texpr(
  body : TExpr,
  reachable : Bool,
  state : ORScanState,
  info : OROptInfo,
) -> Unit {
  let mut reachable = reachable
  for instr in body.0 {
    if !reachable {
      break
    }
    or_scan_instr(instr, true, state, info)
    if is_unreachable_instr(instr) {
      reachable = false
    }
  }
}

///|
fn or_build_func_env(mod : Module, abs_func_idx : Int) -> Env {
  let base_env = Env::new().with_module(mod)
  let params = match
    base_env.get_functype_by_funcidx(
      FuncIdx::new(abs_func_idx.reinterpret_as_uint()),
    ) {
    Some(FuncType(ps, _)) => ps
    None => []
  }
  let locals = params.copy()
  match or_get_defined_func(mod, abs_func_idx) {
    Some(TFunc(extra_locals, _)) =>
      for t in extra_locals {
        locals.push(t)
      }
    _ => ()
  }
  base_env.with_locals(locals)
}

///|
fn or_scan_function(mod : Module, abs_func_idx : Int, info : OROptInfo) -> Unit {
  let func_idx = FuncIdx::new(abs_func_idx.reinterpret_as_uint())
  let func_type = match
    Env::new().with_module(mod).get_functype_by_funcidx(func_idx) {
    Some(ft) => ft
    None => {
      info.once_funcs[func_idx] = None
      return
    }
  }
  let once_global = match or_get_defined_func(mod, abs_func_idx) {
    Some(TFunc(_, body)) =>
      match func_type {
        FuncType(params, results) if params.length() == 0 &&
          results.length() == 0 => or_get_once_global(body)
        _ => None
      }
    _ => None
  }
  info.once_funcs[func_idx] = once_global
  match or_get_defined_func(mod, abs_func_idx) {
    Some(TFunc(_, body)) => {
      let state = {
        env: or_build_func_env(mod, abs_func_idx),
        read_globals: Map::new(),
      }
      or_scan_texpr(body, true, state, info)
      match once_global {
        Some(g) => {
          let count = state.read_globals.get(g).unwrap_or(0)
          if count > 0 {
            state.read_globals[g] = count - 1
          }
        }
        None => ()
      }
      for entry in state.read_globals {
        let (g, count) = entry
        if count > 0 {
          info.once_globals[g] = false
        }
      }
    }
    _ => ()
  }
}

///|
fn or_copy_global_set(src : Set[GlobalIdx]) -> Set[GlobalIdx] {
  let out : Set[GlobalIdx] = Set::new()
  for g in src {
    out.add(g)
  }
  out
}

///|
fn or_make_block(state : ORBuildState) -> ORBlockId {
  let id = ORBlockId(state.next_block)
  state.next_block += 1
  state.blocks[id] = { events: [], succs: [] }
  id
}

///|
fn or_add_edge(state : ORBuildState, from : ORBlockId, to : ORBlockId) -> Unit {
  let block = state.blocks[from]
  let succs = block.succs
  if !succs.contains(to) {
    succs.push(to)
  }
}

///|
fn or_add_event(
  state : ORBuildState,
  block : ORBlockId,
  event : OREventKind,
) -> Unit {
  let event_id = state.next_event
  state.next_event += 1
  state.events[event_id] = event
  state.blocks[block].events.push(event_id)
}

///|
fn or_record_side_effect_event(
  state : ORBuildState,
  block : ORBlockId,
  instr : TInstr,
) -> Unit {
  match instr {
    TGlobalSet(idx, value) =>
      or_add_event(
        state,
        block,
        OREventKind::GlobalSet(idx, or_is_nonzero_int_const(value)),
      )
    TCall(target, args) =>
      or_add_event(state, block, OREventKind::Call(target, args.length()))
    _ => ()
  }
}

///|
fn or_lower_texpr(
  body : TExpr,
  start : ORBlockId,
  state : ORBuildState,
) -> ORBlockId {
  let mut current = start
  for instr in body.0 {
    match instr {
      TIf(_, _, then_body, else_body) => {
        let then_block = or_make_block(state)
        let else_block = or_make_block(state)
        let merge_block = or_make_block(state)
        or_add_edge(state, current, then_block)
        or_add_edge(state, current, else_block)
        let then_end = or_lower_texpr(then_body, then_block, state)
        or_add_edge(state, then_end, merge_block)
        match else_body {
          Some(other) => {
            let else_end = or_lower_texpr(other, else_block, state)
            or_add_edge(state, else_end, merge_block)
          }
          None => or_add_edge(state, else_block, merge_block)
        }
        current = merge_block
      }
      TReturn(_) => return current
      _ => or_record_side_effect_event(state, current, instr)
    }
  }
  current
}

///|
fn or_compute_preds(
  blocks : Map[ORBlockId, ORBlock],
) -> Map[ORBlockId, Array[ORBlockId]] {
  let preds : Map[ORBlockId, Array[ORBlockId]] = Map::new()
  for entry in blocks {
    let (from, block) = entry
    for succ in block.succs {
      preds.get_or_init(succ, fn() { [] }).push(from)
    }
  }
  preds
}

///|
fn or_build_cfg(body : TExpr) -> ORCFG {
  let state = ORBuildState::new()
  let entry = or_make_block(state)
  ignore(or_lower_texpr(body, entry, state))
  {
    entry,
    blocks: state.blocks,
    preds: or_compute_preds(state.blocks),
    events: state.events,
  }
}

///|
fn or_compute_rpo(cfg : ORCFG) -> Array[ORBlockId] {
  let visited : Set[ORBlockId] = Set::new()
  let order : Array[ORBlockId] = []
  fn dfs(id : ORBlockId) -> Unit {
    if visited.contains(id) {
      return
    }
    visited.add(id)
    for succ in cfg.blocks.get(id).unwrap().succs {
      dfs(succ)
    }
    order.push(id)
  }

  dfs(cfg.entry)
  order.rev_in_place()
  order
}

///|
fn or_intersect(
  idom : Map[ORBlockId, ORBlockId?],
  a : ORBlockId,
  b : ORBlockId,
) -> ORBlockId {
  let mut x = a
  let mut y = b
  while x != y {
    let ORBlockId(ix) = x
    let ORBlockId(iy) = y
    while ix > iy {
      x = idom[x].unwrap()
      let ORBlockId(new_ix) = x
      if new_ix <= iy {
        break
      }
    }
    let ORBlockId(ix2) = x
    while iy > ix2 {
      y = idom[y].unwrap()
      let ORBlockId(new_iy) = y
      if new_iy <= ix2 {
        break
      }
    }
  }
  x
}

///|
fn or_compute_dominators(cfg : ORCFG) -> Map[ORBlockId, ORBlockId] {
  let rpo = or_compute_rpo(cfg)
  let idom : Map[ORBlockId, ORBlockId?] = Map::new()
  for entry in cfg.blocks {
    let (block_id, _) = entry
    idom[block_id] = None
  }
  idom[cfg.entry] = Some(cfg.entry)
  let mut changed = true
  while changed {
    changed = false
    for block_id in rpo {
      if block_id == cfg.entry {
        continue
      }
      let preds = cfg.preds
        .get(block_id)
        .unwrap_or([])
        .filter(p => idom[p] is Some(_))
      if preds.is_empty() {
        continue
      }
      let mut new_idom = preds[0]
      for pred in preds.op_as_view(start=1, end=preds.length()) {
        new_idom = or_intersect(idom, pred, new_idom)
      }
      if idom[block_id] != Some(new_idom) {
        idom[block_id] = Some(new_idom)
        changed = true
      }
    }
  }
  let out : Map[ORBlockId, ORBlockId] = Map::new()
  for entry in idom {
    let (block_id, dom) = entry
    match dom {
      Some(d) => out[block_id] = d
      None => ()
    }
  }
  out
}

///|
fn or_rewrite_instr(state : ORRewriteState, instr : TInstr) -> TInstr {
  match instr {
    TGlobalSet(_, _) | TCall(_, _) => {
      let event_id = state.next_event
      state.next_event += 1
      if state.nops.contains(event_id) {
        TInstr::nop()
      } else {
        instr
      }
    }
    TBlock(bt, body) => TInstr::block(bt, or_rewrite_texpr(state, body))
    TLoop(bt, body) => TInstr::loop_(bt, or_rewrite_texpr(state, body))
    TTryTable(bt, catches, body) =>
      TInstr::try_table(bt, catches, or_rewrite_texpr(state, body))
    TIf(bt, cond, then_body, else_body) =>
      TInstr::if_(
        bt,
        cond,
        or_rewrite_texpr(state, then_body),
        else_body.map(e => or_rewrite_texpr(state, e)),
      )
    _ => instr
  }
}

///|
fn or_rewrite_texpr(state : ORRewriteState, body : TExpr) -> TExpr {
  let out : Array[TInstr] = []
  for instr in body.0 {
    out.push(or_rewrite_instr(state, instr))
  }
  TExpr::new(out)
}

///|
fn or_optimize_function(
  func_idx : FuncIdx,
  func : Func,
  info : OROptInfo,
) -> OROptimizeResult {
  let original_summary = or_copy_global_set(
    info.once_globals_set_in_funcs.get(func_idx).unwrap_or(Set::new()),
  )
  match func {
    TFunc(locals, body) => {
      let cfg = or_build_cfg(body)
      let idom = or_compute_dominators(cfg)
      let rpo = or_compute_rpo(cfg)
      let end_written : Map[ORBlockId, Set[GlobalIdx]] = Map::new()
      let nops : Set[Int] = Set::new()
      for block_id in rpo {
        let current = if block_id == cfg.entry {
          Set::new()
        } else {
          match idom.get(block_id) {
            Some(dom) =>
              or_copy_global_set(end_written.get(dom).unwrap_or(Set::new()))
            None => Set::new()
          }
        }
        let block = cfg.blocks[block_id]
        for event_id in block.events {
          match cfg.events[event_id] {
            GlobalSet(g, writes_nonzero_const) =>
              if writes_nonzero_const &&
                info.once_globals.get(g).unwrap_or(false) {
                if current.contains(g) {
                  nops.add(event_id)
                } else {
                  current.add(g)
                }
              }
            Call(callee, arg_count) => {
              if arg_count == 0 {
                match info.once_funcs.get(callee).unwrap_or(None) {
                  Some(g) =>
                    if current.contains(g) {
                      nops.add(event_id)
                    } else {
                      current.add(g)
                    }
                  None => ()
                }
              }
              for
                g in info.once_globals_set_in_funcs
                .get(callee)
                .unwrap_or(Set::new()) {
                current.add(g)
              }
            }
          }
        }
        end_written[block_id] = current
      }
      let summary = or_copy_global_set(
        end_written.get(cfg.entry).unwrap_or(Set::new()),
      )
      match info.once_funcs.get(func_idx).unwrap_or(None) {
        Some(g) => summary.add(g)
        None => ()
      }
      let merged_summary = original_summary
      for g in summary {
        merged_summary.add(g)
      }
      let rewritten = if nops.is_empty() {
        Func::t_func(locals, body)
      } else {
        Func::t_func(locals, or_rewrite_texpr(ORRewriteState::new(nops), body))
      }
      { func: rewritten, summary: merged_summary }
    }
    _ => { func, summary: original_summary }
  }
}

///|
fn or_match_guard_if(instr : TInstr) -> GlobalIdx? {
  match instr {
    TIf(_, TGlobalGet(g), TExpr([TReturn(values)]), None) if values.length() ==
      0 => Some(g)
    _ => None
  }
}

///|
fn or_match_once_set(instr : TInstr, g : GlobalIdx) -> Bool {
  match instr {
    TGlobalSet(g2, value) =>
      g2 == g && !is_unreachable_instr(value) && or_is_nonzero_int_const(value)
    _ => false
  }
}

///|
fn or_cleanup_once_bodies(mod : Module, info : OROptInfo) -> Module {
  let mut mod = mod
  let removed_exit_logic : Set[FuncIdx] = Set::new()
  let imported = or_count_imported_funcs(mod)
  let defined_count = match mod.code_sec {
    Some(CodeSec(funcs)) => funcs.length()
    None => 0
  }
  for def_idx = 0; def_idx < defined_count; def_idx = def_idx + 1 {
    let abs_idx = imported + def_idx
    let curr_idx = FuncIdx::new(abs_idx.reinterpret_as_uint())
    let once_global = info.once_funcs.get(curr_idx).unwrap_or(None)
    if once_global is None {
      continue
    }
    let g = match once_global {
      Some(g) => g
      None => continue
    }
    let func = match or_get_defined_func(mod, abs_idx) {
      Some(f) => f
      None => continue
    }
    match func {
      TFunc(locals, TExpr([TBlock(bt, TExpr(items))])) =>
        if items.length() == 2 &&
          or_match_guard_if(items[0]) == Some(g) &&
          or_match_once_set(items[1], g) {
          mod = or_set_defined_func(
            mod,
            def_idx,
            Func::t_func(locals, TExpr::new([TInstr::nop()])),
          )
        } else if items.length() == 3 &&
          or_match_guard_if(items[0]) == Some(g) &&
          or_match_once_set(items[1], g) {
          match items[2] {
            TCall(callee, args) =>
              if args.length() == 0 &&
                callee != curr_idx &&
                info.once_funcs.get(callee).unwrap_or(None) is Some(_) &&
                !removed_exit_logic.contains(callee) {
                let next_items = items.copy()
                next_items[0] = TInstr::nop()
                next_items[1] = TInstr::nop()
                mod = or_set_defined_func(
                  mod,
                  def_idx,
                  Func::t_func(
                    locals,
                    TExpr::new([TInstr::block(bt, TExpr::new(next_items))]),
                  ),
                )
                removed_exit_logic.add(curr_idx)
              }
            _ => ()
          }
        }
      _ => ()
    }
  }
  mod
}

///|
fn once_reduction(mod : Module) -> Result[Module, String] {
  let mut mod = mod
  let info = {
    once_globals: Map::new(),
    once_funcs: Map::new(),
    once_globals_set_in_funcs: Map::new(),
  }
  let total_funcs = or_total_funcs(mod)
  for i = 0; i < total_funcs; i = i + 1 {
    let func_idx = FuncIdx::new(i.reinterpret_as_uint())
    info.once_funcs[func_idx] = None
    info.once_globals_set_in_funcs[func_idx] = Set::new()
  }
  let exported_globals = or_collect_exported_globals(mod)
  let global_types = or_collect_global_types(mod)
  let imported_globals = or_count_imported_globals(mod)
  for i = 0; i < global_types.length(); i = i + 1 {
    let GlobalType(val_type, mutable) = global_types[i]
    let idx = GlobalIdx::new(i.reinterpret_as_uint())
    let imported = i < imported_globals
    let exported = exported_globals.contains(idx)
    info.once_globals[idx] = mutable &&
      or_is_integer_type(val_type) &&
      !imported &&
      !exported
  }
  let imported_funcs = or_count_imported_funcs(mod)
  match mod.code_sec {
    Some(CodeSec(funcs)) =>
      for def_idx = 0; def_idx < funcs.length(); def_idx = def_idx + 1 {
        or_scan_function(mod, imported_funcs + def_idx, info)
      }
    None => return Ok(mod)
  }
  for entry in info.once_funcs {
    let (func_idx, once_global) = entry
    match once_global {
      Some(g) =>
        if !info.once_globals.get(g).unwrap_or(false) {
          info.once_funcs[func_idx] = None
        } else {
          info.once_globals_set_in_funcs[func_idx].add(g)
        }
      None => ()
    }
  }
  let mut has_once_func = false
  for entry in info.once_funcs {
    let (_, once_global) = entry
    if once_global is Some(_) {
      has_once_func = true
      break
    }
  }
  if !has_once_func {
    return Ok(mod)
  }
  let mut prev_total = -1
  while true {
    let new_sets : Map[FuncIdx, Set[GlobalIdx]] = Map::new()
    for i = 0; i < total_funcs; i = i + 1 {
      let func_idx = FuncIdx::new(i.reinterpret_as_uint())
      new_sets[func_idx] = or_copy_global_set(
        info.once_globals_set_in_funcs.get(func_idx).unwrap_or(Set::new()),
      )
    }
    let defined_count = match mod.code_sec {
      Some(CodeSec(funcs)) => funcs.length()
      None => 0
    }
    for def_idx = 0; def_idx < defined_count; def_idx = def_idx + 1 {
      let abs_idx = imported_funcs + def_idx
      let func_idx = FuncIdx::new(abs_idx.reinterpret_as_uint())
      let func = match or_get_defined_func(mod, abs_idx) {
        Some(f) => f
        None => continue
      }
      let result = or_optimize_function(func_idx, func, info)
      mod = or_set_defined_func(mod, def_idx, result.func)
      new_sets[func_idx] = result.summary
    }
    info.once_globals_set_in_funcs = new_sets
    let mut total = 0
    for entry in info.once_globals_set_in_funcs {
      let (_, set_) = entry
      total += set_.length()
    }
    if total <= prev_total {
      break
    }
    prev_total = total
  }
  Ok(or_cleanup_once_bodies(mod, info))
}

///|
fn or_type(params : Array[ValType], results : Array[ValType]) -> RecType {
  single_rec_type(comp_type_sub_type(func_comp_type(params, results)))
}

///|
fn or_run(mod : Module) -> Module raise {
  match optimize_module(mod, [ModulePass::OnceReduction]) {
    Ok(out) => out
    Err(e) => fail("unexpected once_reduction error: \{e}")
  }
}

///|
fn or_i32_global(init : Int, mut_ : Bool) -> Global {
  Global::new(
    GlobalType::new(ValType::i32(), mut_),
    Expr::new([Instruction::i32_const(I32(init))]),
  )
}

///|
fn or_once_body(g : Int, set_val : Int, payload : Array[TInstr]) -> TExpr {
  let seq : Array[TInstr] = [
    TInstr::if_(
      BlockType::void_(),
      TInstr::global_get(GlobalIdx::new(g.reinterpret_as_uint())),
      TExpr::new([TInstr::return_([])]),
      None,
    ),
    TInstr::global_set(
      GlobalIdx::new(g.reinterpret_as_uint()),
      TInstr::i32_const(I32(set_val)),
    ),
  ]
  for instr in payload {
    seq.push(instr)
  }
  TExpr::new([TInstr::block(BlockType::void_(), TExpr::new(seq))])
}

///|
test "once_reduction removes dominated redundant once call" {
  let mod = Module::new()
    .with_type_sec(TypeSec::new([or_type([], []), or_type([], [])]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_global_sec(
      GlobalSec::new([or_i32_global(0, true), or_i32_global(0, true)]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::call(FuncIdx::new(1), []),
            TInstr::nop(),
            TInstr::call(FuncIdx::new(1), []),
          ]),
        ),
        Func::t_func(
          [],
          or_once_body(0, 1, [
            TInstr::global_set(GlobalIdx::new(1), TInstr::i32_const(I32(9))),
          ]),
        ),
      ]),
    )
  let out = or_run(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TCall(_, _), TNop, TNop])), _])) => ()
    _ => fail("expected second dominated call to once func to be nopped")
  }
}

///|
test "once_reduction removes redundant once-global sets" {
  let mod = Module::new()
    .with_type_sec(TypeSec::new([or_type([], []), or_type([], [])]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_global_sec(GlobalSec::new([or_i32_global(0, true)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::global_set(GlobalIdx::new(0), TInstr::i32_const(I32(1))),
            TInstr::global_set(GlobalIdx::new(0), TInstr::i32_const(I32(7))),
          ]),
        ),
        Func::t_func([], or_once_body(0, 9, [TInstr::nop()])),
      ]),
    )
  let out = or_run(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TGlobalSet(_, _), TNop])), _])) => ()
    _ => fail("expected second dominated once-global set to be nopped")
  }
}

///|
test "once_reduction disqualifies zero and non-const writes" {
  let zero_write = Module::new()
    .with_type_sec(TypeSec::new([or_type([], []), or_type([], [])]))
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(1), TypeIdx::new(0)]),
    )
    .with_global_sec(GlobalSec::new([or_i32_global(0, true)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::call(FuncIdx::new(1), []),
            TInstr::call(FuncIdx::new(1), []),
          ]),
        ),
        Func::t_func([], or_once_body(0, 1, [TInstr::nop()])),
        Func::t_func(
          [],
          TExpr::new([
            TInstr::global_set(GlobalIdx::new(0), TInstr::i32_const(I32(0))),
          ]),
        ),
      ]),
    )
  let out_zero = or_run(zero_write)
  match out_zero.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TCall(_, _), TCall(_, _)])), _, _])) => ()
    _ => fail("expected no call removal when once global is written with zero")
  }
  let non_const_write = Module::new()
    .with_type_sec(
      TypeSec::new([
        or_type([], []),
        or_type([], []),
        or_type([ValType::i32()], []),
      ]),
    )
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(1), TypeIdx::new(2)]),
    )
    .with_global_sec(GlobalSec::new([or_i32_global(0, true)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::call(FuncIdx::new(1), []),
            TInstr::call(FuncIdx::new(1), []),
          ]),
        ),
        Func::t_func([], or_once_body(0, 1, [TInstr::nop()])),
        Func::t_func(
          [],
          TExpr::new([
            TInstr::global_set(
              GlobalIdx::new(0),
              TInstr::local_get(LocalIdx::new(0)),
            ),
          ]),
        ),
      ]),
    )
  let out_non_const = or_run(non_const_write)
  match out_non_const.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TCall(_, _), TCall(_, _)])), _, _])) => ()
    _ =>
      fail(
        "expected no call removal when once global has non-const integer write",
      )
  }
}

///|
test "once_reduction disqualifies extra reads and exported/imported globals" {
  let extra_read = Module::new()
    .with_type_sec(
      TypeSec::new([or_type([], []), or_type([], []), or_type([], [])]),
    )
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(1), TypeIdx::new(2)]),
    )
    .with_global_sec(GlobalSec::new([or_i32_global(0, true)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::call(FuncIdx::new(1), []),
            TInstr::call(FuncIdx::new(1), []),
          ]),
        ),
        Func::t_func([], or_once_body(0, 1, [TInstr::nop()])),
        Func::t_func(
          [],
          TExpr::new([TInstr::drop(TInstr::global_get(GlobalIdx::new(0)))]),
        ),
      ]),
    )
  let out_extra_read = or_run(extra_read)
  match out_extra_read.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TCall(_, _), TCall(_, _)])), _, _])) => ()
    _ => fail("expected no call removal when once global is read outside guard")
  }
  let exported_global = Module::new()
    .with_type_sec(TypeSec::new([or_type([], []), or_type([], [])]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_global_sec(GlobalSec::new([or_i32_global(0, true)]))
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("g"), ExternIdx::global(GlobalIdx::new(0))),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::call(FuncIdx::new(1), []),
            TInstr::call(FuncIdx::new(1), []),
          ]),
        ),
        Func::t_func([], or_once_body(0, 1, [TInstr::nop()])),
      ]),
    )
  let out_exported = or_run(exported_global)
  match out_exported.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TCall(_, _), TCall(_, _)])), _])) => ()
    _ => fail("expected no call removal for exported once global")
  }
  let imported_global = Module::new()
    .with_type_sec(TypeSec::new([or_type([], []), or_type([], [])]))
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("g"),
          ExternType::global(GlobalType::new(ValType::i32(), true)),
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::call(FuncIdx::new(1), []),
            TInstr::call(FuncIdx::new(1), []),
          ]),
        ),
        Func::t_func([], or_once_body(0, 1, [TInstr::nop()])),
      ]),
    )
  let out_imported = or_run(imported_global)
  match out_imported.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TCall(_, _), TCall(_, _)])), _])) => ()
    _ => fail("expected no call removal for imported once global")
  }
}

///|
test "once_reduction disqualifies non-canonical guard pattern" {
  let bad_once = Module::new()
    .with_type_sec(TypeSec::new([or_type([], []), or_type([], [])]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_global_sec(GlobalSec::new([or_i32_global(0, true)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::call(FuncIdx::new(1), []),
            TInstr::call(FuncIdx::new(1), []),
          ]),
        ),
        Func::t_func(
          [],
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::if_(
                  BlockType::void_(),
                  TInstr::global_get(GlobalIdx::new(0)),
                  TExpr::new([TInstr::return_([])]),
                  Some(TExpr::new([TInstr::nop()])),
                ),
                TInstr::global_set(GlobalIdx::new(0), TInstr::i32_const(I32(1))),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let out = or_run(bad_once)
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TCall(_, _), TCall(_, _)])), _])) => ()
    _ => fail("expected no call removal when guard pattern is not canonical")
  }
}

///|
test "once_reduction propagates once summaries to fixed point" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([or_type([], []), or_type([], []), or_type([], [])]),
    )
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(1), TypeIdx::new(2)]),
    )
    .with_global_sec(GlobalSec::new([or_i32_global(0, true)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::call(FuncIdx::new(1), []),
            TInstr::call(FuncIdx::new(2), []),
          ]),
        ),
        Func::t_func([], TExpr::new([TInstr::call(FuncIdx::new(2), [])])),
        Func::t_func([], or_once_body(0, 1, [TInstr::nop()])),
      ]),
    )
  let out = or_run(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TCall(_, _), TNop])), _, _])) => ()
    _ =>
      fail(
        "expected fixed-point propagation to remove dominated call through callee summary",
      )
  }
}

///|
test "once_reduction honors dominance across branches" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([or_type([ValType::i32()], []), or_type([], [])]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_global_sec(GlobalSec::new([or_i32_global(0, true)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(0)),
              TExpr::new([TInstr::call(FuncIdx::new(1), [])]),
              Some(TExpr::new([TInstr::nop()])),
            ),
            TInstr::call(FuncIdx::new(1), []),
          ]),
        ),
        Func::t_func([], or_once_body(0, 1, [TInstr::nop()])),
      ]),
    )
  let out = or_run(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TIf(_, _, _, _), TCall(_, _)])), _])) => ()
    _ =>
      fail(
        "expected post-merge call to remain when prior call does not dominate",
      )
  }
}

///|
test "once_reduction keeps block-nested call semantics aligned with canonical cfg" {
  let mod = Module::new()
    .with_type_sec(TypeSec::new([or_type([], []), or_type([], [])]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_global_sec(GlobalSec::new([or_i32_global(0, true)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([TInstr::call(FuncIdx::new(1), [])]),
            ),
            TInstr::call(FuncIdx::new(1), []),
          ]),
        ),
        Func::t_func([], or_once_body(0, 1, [TInstr::nop()])),
      ]),
    )
  let out = or_run(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TBlock(_, _), TCall(_, _)])), _])) => ()
    _ =>
      fail(
        "expected second call to remain; nested block call is not split in canonical cfg lowering",
      )
  }
}

///|
test "once_reduction handles unreachable tails safely" {
  let mod = Module::new()
    .with_type_sec(TypeSec::new([or_type([], []), or_type([], [])]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_global_sec(GlobalSec::new([or_i32_global(0, true)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([TInstr::unreachable_(), TInstr::call(FuncIdx::new(1), [])]),
        ),
        Func::t_func([], or_once_body(0, 1, [TInstr::nop()])),
      ]),
    )
  let out = or_run(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TUnreachable, _])), _])) => ()
    _ => fail("expected pass to ignore unreachable tail calls without crashing")
  }
}

///|
test "once_reduction cleanup removes no-payload boilerplate" {
  let mod = Module::new()
    .with_type_sec(TypeSec::new([or_type([], [])]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_global_sec(GlobalSec::new([or_i32_global(0, true)]))
    .with_code_sec(CodeSec::new([Func::t_func([], or_once_body(0, 1, []))]))
  let out = or_run(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TNop]))])) => ()
    _ => fail("expected cleanup to turn guard+set-only once func into nop body")
  }
}

///|
test "once_reduction cleanup removes boilerplate for single once-call payload" {
  let mod = Module::new()
    .with_type_sec(TypeSec::new([or_type([], []), or_type([], [])]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_global_sec(
      GlobalSec::new([or_i32_global(0, true), or_i32_global(0, true)]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          or_once_body(0, 1, [TInstr::call(FuncIdx::new(1), [])]),
        ),
        Func::t_func([], or_once_body(1, 1, [TInstr::nop()])),
      ]),
    )
  let out = or_run(mod)
  match out.code_sec {
    Some(
      CodeSec(
        [TFunc(_, TExpr([TBlock(_, TExpr([TNop, TNop, TCall(_, _)]))])), _]
      )
    ) => ()
    _ =>
      fail(
        "expected once-call-only payload cleanup to remove first two once instructions",
      )
  }
}

///|
test "once_reduction cleanup is cycle-safe" {
  let mod = Module::new()
    .with_type_sec(TypeSec::new([or_type([], []), or_type([], [])]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_global_sec(
      GlobalSec::new([or_i32_global(0, true), or_i32_global(0, true)]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          or_once_body(0, 1, [TInstr::call(FuncIdx::new(1), [])]),
        ),
        Func::t_func(
          [],
          or_once_body(1, 1, [TInstr::call(FuncIdx::new(0), [])]),
        ),
      ]),
    )
  let out = or_run(mod)
  match out.code_sec {
    Some(
      CodeSec(
        [
          TFunc(_, TExpr([TBlock(_, TExpr(a_items))])),
          TFunc(_, TExpr([TBlock(_, TExpr(b_items))])),
        ]
      )
    ) => {
      let a_removed = a_items.length() >= 2 &&
        a_items[0] is TNop &&
        a_items[1] is TNop
      let b_removed = b_items.length() >= 2 &&
        b_items[0] is TNop &&
        b_items[1] is TNop
      assert_true(!(a_removed && b_removed))
    }
    _ => fail("expected two once funcs with block bodies")
  }
}

///|
test "once_reduction is deterministic across runs" {
  let mod = Module::new()
    .with_type_sec(TypeSec::new([or_type([], []), or_type([], [])]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_global_sec(GlobalSec::new([or_i32_global(0, true)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::call(FuncIdx::new(1), []),
            TInstr::call(FuncIdx::new(1), []),
          ]),
        ),
        Func::t_func([], or_once_body(0, 1, [TInstr::nop()])),
      ]),
    )
  let once = or_run(mod)
  let twice = or_run(once)
  assert_eq(once, twice)
}
