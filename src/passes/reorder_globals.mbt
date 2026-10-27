// Licensing scope: see ../../LICENSE and this directory's LICENSE and NOTICE.
// Copyright 2023 WebAssembly Community Group participants.
// Retained historical upstream notice; current derivation remains unconfirmed.
// Conservative attribution from pinned Binaryen version_130 counterpart:
// Copyright 2022 WebAssembly Community Group participants
// Counterpart: src/passes/ReorderGlobals.cpp (5d704ad5); origin remains unconfirmed.
// Potentially incorporated Binaryen expression retains Apache-2.0 terms.
// Original Starshine contributions use the scoped MIT grant in ../../LICENSE.
// Modified for Starshine through 2026: implementation and validation use
// Starshine's representations and APIs; this is not an unchanged upstream file.
// Conservative notice retention does not establish copying or independence.

///|
pub fn reorder_globals_summary() -> String {
  "Preserve imported-global order, reorder defined globals by the public size policy, and remap numeric global indices."
}

///|
fn rg_imported_global_count(mod_ : @lib.Module) -> Int32 {
  let mut count = 0
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.GlobalExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
fn rg_global_idx_raw(idx : @lib.GlobalIdx) -> Int32 {
  let @lib.GlobalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn rg_global_idx_from_int(idx : Int32) -> @lib.GlobalIdx {
  @lib.GlobalIdx::new(idx.reinterpret_as_uint())
}

///|
fn rg_note_global_use(counts : Array[Int32], idx : @lib.GlobalIdx) -> Unit {
  let raw = rg_global_idx_raw(idx)
  if raw >= 0 && raw < counts.length() {
    counts[raw] += 1
  }
}

///|
fn rg_count_expr(expr : @lib.Expr, counts : Array[Int32]) -> Unit {
  let @lib.Expr(instrs) = expr
  rg_count_instrs(instrs, counts)
}

///|
fn rg_count_instrs(
  instrs : Array[@lib.Instruction],
  counts : Array[Int32],
) -> Unit {
  for instr in instrs {
    rg_count_instruction(instr, counts)
  }
}

///|
fn rg_count_instruction(
  instr : @lib.Instruction,
  counts : Array[Int32],
) -> Unit {
  match instr {
    @lib.Block(_, body) => rg_count_expr(body, counts)
    @lib.Loop(_, body) => rg_count_expr(body, counts)
    @lib.If(_, then_body, else_body) => {
      rg_count_instrs(then_body, counts)
      match else_body {
        Some(body) => rg_count_instrs(body, counts)
        None => ()
      }
    }
    @lib.Try(_, body, catches, _) => {
      rg_count_expr(body, counts)
      for catch_ in catches {
        match catch_ {
          @lib.LegacyCatch(_, catch_body) | @lib.LegacyCatchAll(catch_body) =>
            rg_count_expr(catch_body, counts)
        }
      }
    }
    @lib.TryTable(_, _, body) => rg_count_expr(body, counts)
    @lib.GlobalGet(idx) | @lib.GlobalSet(idx) => rg_note_global_use(counts, idx)
    _ => ()
  }
}

///|
fn rg_count_elem_kind(kind : @lib.ElemKind, counts : Array[Int32]) -> Unit {
  match kind {
    @lib.FuncExprsElemKind(exprs) | @lib.TypedExprsElemKind(_, exprs) =>
      for expr in exprs {
        rg_count_expr(expr, counts)
      }
    _ => ()
  }
}

///|
fn rg_count_elem_mode(mode : @lib.ElemMode, counts : Array[Int32]) -> Unit {
  match mode {
    @lib.Active(_, expr) => rg_count_expr(expr, counts)
    _ => ()
  }
}

///|
fn rg_count_data_mode(mode : @lib.DataMode, counts : Array[Int32]) -> Unit {
  match mode {
    @lib.Active(_, expr) => rg_count_expr(expr, counts)
    _ => ()
  }
}

///|
fn rg_count_global_traffic(
  mod_ : @lib.Module,
  total_globals : Int32,
) -> Array[Int32] {
  let counts = Array::make(total_globals, 0)
  match mod_.table_sec {
    Some(@lib.TableSec(tables)) =>
      for table in tables {
        match table {
          @lib.Table(_, Some(expr)) => rg_count_expr(expr, counts)
          _ => ()
        }
      }
    None => ()
  }
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) =>
      for global in globals {
        let @lib.Global(_, init) = global
        rg_count_expr(init, counts)
      }
    None => ()
  }
  match mod_.export_sec {
    Some(@lib.ExportSec(exports)) =>
      for export_ in exports {
        match export_ {
          @lib.Export(_, @lib.GlobalExternIdx(idx)) =>
            rg_note_global_use(counts, idx)
          _ => ()
        }
      }
    None => ()
  }
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) =>
      for elem in elems {
        let @lib.Elem(mode, kind) = elem
        rg_count_elem_mode(mode, counts)
        rg_count_elem_kind(kind, counts)
      }
    None => ()
  }
  match mod_.data_sec {
    Some(@lib.DataSec(datas)) =>
      for data in datas {
        let @lib.Data(mode, _) = data
        rg_count_data_mode(mode, counts)
      }
    None => ()
  }
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(_, body) = func
        rg_count_expr(body, counts)
      }
    None => ()
  }
  counts
}

///|
fn rg_note_global_dep(
  deps : Array[Int32],
  seen : Array[Bool],
  idx : @lib.GlobalIdx,
  total : Int32,
) -> Unit {
  let raw = rg_global_idx_raw(idx)
  if raw >= 0 && raw < total && !seen[raw] {
    seen[raw] = true
    deps.push(raw)
  }
}

///|
fn rg_collect_expr_global_deps(
  expr : @lib.Expr,
  total_globals : Int32,
  deps : Array[Int32],
  seen : Array[Bool],
) -> Unit {
  let @lib.Expr(instrs) = expr
  rg_collect_instrs_global_deps(instrs, total_globals, deps, seen)
}

///|
fn rg_collect_instrs_global_deps(
  instrs : Array[@lib.Instruction],
  total_globals : Int32,
  deps : Array[Int32],
  seen : Array[Bool],
) -> Unit {
  for instr in instrs {
    rg_collect_instruction_global_deps(instr, total_globals, deps, seen)
  }
}

///|
fn rg_collect_instruction_global_deps(
  instr : @lib.Instruction,
  total_globals : Int32,
  deps : Array[Int32],
  seen : Array[Bool],
) -> Unit {
  match instr {
    @lib.Block(_, body) =>
      rg_collect_expr_global_deps(body, total_globals, deps, seen)
    @lib.Loop(_, body) =>
      rg_collect_expr_global_deps(body, total_globals, deps, seen)
    @lib.If(_, then_body, else_body) => {
      rg_collect_instrs_global_deps(then_body, total_globals, deps, seen)
      match else_body {
        Some(body) =>
          rg_collect_instrs_global_deps(body, total_globals, deps, seen)
        None => ()
      }
    }
    @lib.Try(_, body, catches, _) => {
      rg_collect_expr_global_deps(body, total_globals, deps, seen)
      for catch_ in catches {
        match catch_ {
          @lib.LegacyCatch(_, catch_body) | @lib.LegacyCatchAll(catch_body) =>
            rg_collect_expr_global_deps(catch_body, total_globals, deps, seen)
        }
      }
    }
    @lib.TryTable(_, _, body) =>
      rg_collect_expr_global_deps(body, total_globals, deps, seen)
    @lib.GlobalGet(idx) => rg_note_global_dep(deps, seen, idx, total_globals)
    _ => ()
  }
}

///|
fn rg_build_dependency_graph(
  globals : Array[@lib.Global],
  imported_globals : Int32,
) -> Array[Array[Int32]] {
  let total_globals = imported_globals + globals.length()
  let graph : Array[Array[Int32]] = Array(capacity=total_globals)
  for idx = 0; idx < total_globals; idx = idx + 1 {
    ignore(idx)
    graph.push([])
  }
  let seen = Array::make(total_globals, false)
  for defined_idx = 0
      defined_idx < globals.length()
      defined_idx = defined_idx + 1 {
    let @lib.Global(_, init) = globals[defined_idx]
    let dependent = imported_globals + defined_idx
    let dependencies : Array[Int32] = []
    rg_collect_expr_global_deps(init, total_globals, dependencies, seen)
    for dependency in dependencies {
      seen[dependency] = false
      if dependency != dependent {
        graph[dependency].push(dependent)
      }
    }
  }
  graph
}

///|
fn rg_candidate_is_better(
  candidate : Int32,
  best : Int32,
  custom_counts : Array[Double],
  imported_globals : Int32,
) -> Bool {
  if best < 0 {
    return true
  }
  let candidate_imported = candidate < imported_globals
  let best_imported = best < imported_globals
  if candidate_imported != best_imported {
    return candidate_imported
  }
  if candidate_imported {
    return candidate < best
  }
  custom_counts[candidate] > custom_counts[best] ||
  (custom_counts[candidate] == custom_counts[best] && candidate < best)
}

///|
fn rg_ready_heap_push(
  heap : Array[Int32],
  candidate : Int32,
  custom_counts : Array[Double],
  imported_globals : Int32,
) -> Unit {
  heap.push(candidate)
  let mut pos = heap.length() - 1
  while pos > 0 {
    let parent = (pos - 1) / 2
    if !rg_candidate_is_better(
        heap[pos],
        heap[parent],
        custom_counts,
        imported_globals,
      ) {
      break
    }
    let previous_parent = heap[parent]
    heap[parent] = heap[pos]
    heap[pos] = previous_parent
    pos = parent
  }
}

///|
fn rg_ready_heap_pop(
  heap : Array[Int32],
  custom_counts : Array[Double],
  imported_globals : Int32,
) -> Int32? {
  if heap.length() == 0 {
    return None
  }
  let best = heap[0]
  let last = heap.pop().unwrap()
  if heap.length() == 0 {
    return Some(best)
  }
  heap[0] = last
  let mut pos = 0
  while true {
    let left = pos * 2 + 1
    if left >= heap.length() {
      break
    }
    let right = left + 1
    let mut better_child = left
    if right < heap.length() &&
      rg_candidate_is_better(
        heap[right],
        heap[left],
        custom_counts,
        imported_globals,
      ) {
      better_child = right
    }
    if !rg_candidate_is_better(
        heap[better_child],
        heap[pos],
        custom_counts,
        imported_globals,
      ) {
      break
    }
    let previous = heap[pos]
    heap[pos] = heap[better_child]
    heap[better_child] = previous
    pos = better_child
  }
  Some(best)
}

///|
fn rg_candidate_order(
  deps : Array[Array[Int32]],
  custom_counts : Array[Double],
  imported_globals : Int32,
) -> Array[Int32] {
  let n = custom_counts.length()
  let indegrees = Array::make(n, 0)
  for dependency = 0; dependency < n; dependency = dependency + 1 {
    for dependent in deps[dependency] {
      indegrees[dependent] += 1
    }
  }
  let emitted = Array::make(n, false)
  let ready : Array[Int32] = Array(capacity=n)
  for candidate = 0; candidate < n; candidate = candidate + 1 {
    if indegrees[candidate] == 0 {
      rg_ready_heap_push(ready, candidate, custom_counts, imported_globals)
    }
  }
  let order : Array[Int32] = Array(capacity=n)
  while order.length() < n {
    let mut best = match
      rg_ready_heap_pop(ready, custom_counts, imported_globals) {
      Some(candidate) => candidate
      None => -1
    }
    if best < 0 {
      // Invalid cycles should not appear in validated wasm, but preserve a
      // deterministic total order if a malformed module reaches this helper.
      for candidate = 0; candidate < n; candidate = candidate + 1 {
        if !emitted[candidate] {
          best = candidate
          break
        }
      }
    }
    emitted[best] = true
    order.push(best)
    for dependent in deps[best] {
      if indegrees[dependent] > 0 {
        indegrees[dependent] -= 1
        if indegrees[dependent] == 0 && !emitted[dependent] {
          rg_ready_heap_push(ready, dependent, custom_counts, imported_globals)
        }
      }
    }
  }
  order
}

///|
fn rg_true_counts(counts : Array[Int32]) -> Array[Double] {
  let out : Array[Double] = Array(capacity=counts.length())
  for count in counts {
    out.push(count.to_double())
  }
  out
}

///|
fn rg_summed_dependent_counts(
  deps : Array[Array[Int32]],
  base : Array[Double],
  topological : Array[Int32],
) -> Array[Double] {
  let out = base.copy()
  for pos = topological.length() - 1; pos >= 0; pos = pos - 1 {
    let dependency = topological[pos]
    for dependent in deps[dependency] {
      out[dependency] += out[dependent]
    }
  }
  out
}

///|
fn rg_exponential_dependent_counts(
  deps : Array[Array[Int32]],
  base : Array[Double],
  topological : Array[Int32],
) -> Array[Double] {
  let out = base.copy()
  for pos = topological.length() - 1; pos >= 0; pos = pos - 1 {
    let dependency = topological[pos]
    for dependent in deps[dependency] {
      out[dependency] += 0.095 * out[dependent]
    }
  }
  out
}

///|
fn rg_uleb_size(raw : Int32) -> Int32 {
  let mut value = raw
  let mut size = 1
  while value >= 128 {
    value = value / 128
    size += 1
  }
  size
}

///|
fn rg_order_cost(order : Array[Int32], true_counts : Array[Double]) -> Double {
  let mut cost = 0.0
  for new_idx = 0; new_idx < order.length(); new_idx = new_idx + 1 {
    let old_idx = order[new_idx]
    cost += true_counts[old_idx] * rg_uleb_size(new_idx).to_double()
  }
  cost
}

///|
fn rg_dependency_graph_is_empty(deps : Array[Array[Int32]]) -> Bool {
  for dependents in deps {
    if dependents.length() > 0 {
      return false
    }
  }
  true
}

///|
fn rg_identity_order(length : Int32) -> Array[Int32] {
  let order : Array[Int32] = Array(capacity=length)
  for idx = 0; idx < length; idx = idx + 1 {
    order.push(idx)
  }
  order
}

///|
fn rg_sort_unconstrained_order(
  order : Array[Int32],
  custom_counts : Array[Double],
  imported_globals : Int32,
) -> Unit {
  order.sort_by(fn(lhs, rhs) {
    if rg_candidate_is_better(lhs, rhs, custom_counts, imported_globals) {
      -1
    } else if rg_candidate_is_better(rhs, lhs, custom_counts, imported_globals) {
      1
    } else {
      0
    }
  })
}

///|
fn rg_choose_order(
  deps : Array[Array[Int32]],
  true_counts : Array[Double],
  imported_globals : Int32,
) -> Array[Int32] {
  let original = rg_identity_order(true_counts.length())
  if rg_dependency_graph_is_empty(deps) {
    let greedy = original.copy()
    rg_sort_unconstrained_order(greedy, true_counts, imported_globals)
    if rg_order_cost(greedy, true_counts) < rg_order_cost(original, true_counts) {
      return greedy
    }
    return original
  }
  let candidates : Array[Array[Int32]] = []
  let topological = rg_candidate_order(
    deps,
    Array::make(true_counts.length(), 0.0),
    imported_globals,
  )
  candidates.push(topological)
  candidates.push(rg_candidate_order(deps, true_counts, imported_globals))
  candidates.push(
    rg_candidate_order(
      deps,
      rg_summed_dependent_counts(deps, true_counts, topological),
      imported_globals,
    ),
  )
  candidates.push(
    rg_candidate_order(
      deps,
      rg_exponential_dependent_counts(deps, true_counts, topological),
      imported_globals,
    ),
  )
  let mut best_idx = 0
  let mut best_cost = rg_order_cost(candidates[0], true_counts)
  for idx = 1; idx < candidates.length(); idx = idx + 1 {
    let cost = rg_order_cost(candidates[idx], true_counts)
    if cost < best_cost {
      best_cost = cost
      best_idx = idx
    }
  }
  candidates[best_idx]
}

///|
fn rg_order_is_identity(order : Array[Int32]) -> Bool {
  for idx = 0; idx < order.length(); idx = idx + 1 {
    if order[idx] != idx {
      return false
    }
  }
  true
}

///|
fn rg_old_abs_to_new_abs(order : Array[Int32]) -> Array[Int32] {
  let remap = Array::make(order.length(), 0)
  for new_idx = 0; new_idx < order.length(); new_idx = new_idx + 1 {
    remap[order[new_idx]] = new_idx
  }
  remap
}

///|
fn rg_rewrite_global_idx(
  idx : @lib.GlobalIdx,
  remap : Array[Int32],
) -> @lib.GlobalIdx {
  let raw = rg_global_idx_raw(idx)
  if raw >= 0 && raw < remap.length() {
    rg_global_idx_from_int(remap[raw])
  } else {
    idx
  }
}

///|
fn rg_rewrite_expr(expr : @lib.Expr, remap : Array[Int32]) -> @lib.Expr {
  let @lib.Expr(original) = expr
  let instrs = original.copy()
  rg_rewrite_instrs_in_place(instrs, remap)
  @lib.Expr::new(instrs)
}

///|
fn rg_rewrite_instrs_in_place(
  instrs : Array[@lib.Instruction],
  remap : Array[Int32],
) -> Unit {
  for idx = 0; idx < instrs.length(); idx = idx + 1 {
    match instrs[idx] {
      @lib.Block(block_type, body) =>
        instrs[idx] = @lib.Instruction::block(
          block_type,
          rg_rewrite_expr(body, remap),
        )
      @lib.Loop(block_type, body) =>
        instrs[idx] = @lib.Instruction::loop_(
          block_type,
          rg_rewrite_expr(body, remap),
        )
      @lib.If(block_type, then_body, else_body) => {
        let then_body = then_body.copy()
        rg_rewrite_instrs_in_place(then_body, remap)
        let rewritten_else = match else_body {
          Some(body) => {
            let body = body.copy()
            rg_rewrite_instrs_in_place(body, remap)
            Some(body)
          }
          None => None
        }
        instrs[idx] = @lib.Instruction::if_(
          block_type, then_body, rewritten_else,
        )
      }
      @lib.Try(block_type, body, catches, delegate) => {
        let rewritten_catches : Array[@lib.LegacyCatch] = []
        for catch_ in catches {
          match catch_ {
            @lib.LegacyCatch(tag_idx, catch_body) =>
              rewritten_catches.push(
                @lib.LegacyCatch::tagged(
                  tag_idx,
                  rg_rewrite_expr(catch_body, remap),
                ),
              )
            @lib.LegacyCatchAll(catch_body) =>
              rewritten_catches.push(
                @lib.LegacyCatch::all(rg_rewrite_expr(catch_body, remap)),
              )
          }
        }
        instrs[idx] = @lib.Instruction::try_(
          block_type,
          rg_rewrite_expr(body, remap),
          rewritten_catches,
          delegate~,
        )
      }
      @lib.TryTable(block_type, catches, body) =>
        instrs[idx] = @lib.Instruction::try_table(
          block_type,
          catches,
          rg_rewrite_expr(body, remap),
        )
      @lib.GlobalGet(global_idx) =>
        instrs[idx] = @lib.Instruction::global_get(
          rg_rewrite_global_idx(global_idx, remap),
        )
      @lib.GlobalSet(global_idx) =>
        instrs[idx] = @lib.Instruction::global_set(
          rg_rewrite_global_idx(global_idx, remap),
        )
      _ => ()
    }
  }
}

///|
fn rg_rewrite_table_sec(
  table_sec : @lib.TableSec?,
  remap : Array[Int32],
) -> @lib.TableSec? {
  match table_sec {
    Some(@lib.TableSec(tables)) => {
      let out : Array[@lib.Table] = Array(capacity=tables.length())
      for table in tables {
        match table {
          @lib.Table(table_type, Some(expr)) =>
            out.push(
              @lib.Table::new(table_type, Some(rg_rewrite_expr(expr, remap))),
            )
          @lib.Table(table_type, None) =>
            out.push(@lib.Table::new(table_type, None))
        }
      }
      Some(@lib.TableSec::new(out))
    }
    None => None
  }
}

///|
fn rg_rewrite_globals(
  globals : Array[@lib.Global],
  order : Array[Int32],
  imported_globals : Int32,
  remap : Array[Int32],
) -> Array[@lib.Global] {
  let out : Array[@lib.Global] = Array(capacity=globals.length())
  for old_abs in order {
    if old_abs >= imported_globals {
      let old_defined = old_abs - imported_globals
      let @lib.Global(global_type, init) = globals[old_defined]
      out.push(@lib.Global::new(global_type, rg_rewrite_expr(init, remap)))
    }
  }
  out
}

///|
fn rg_rewrite_export_sec(
  export_sec : @lib.ExportSec?,
  remap : Array[Int32],
) -> @lib.ExportSec? {
  match export_sec {
    Some(@lib.ExportSec(exports)) => {
      let out : Array[@lib.Export] = Array(capacity=exports.length())
      for export_ in exports {
        match export_ {
          @lib.Export(name, @lib.GlobalExternIdx(idx)) =>
            out.push(
              @lib.Export::new(
                name,
                @lib.ExternIdx::global(rg_rewrite_global_idx(idx, remap)),
              ),
            )
          _ => out.push(export_)
        }
      }
      Some(@lib.ExportSec::new(out))
    }
    None => None
  }
}

///|
fn rg_rewrite_elem_mode(
  mode : @lib.ElemMode,
  remap : Array[Int32],
) -> @lib.ElemMode {
  match mode {
    @lib.Active(table_idx, expr) =>
      @lib.ElemMode::active(table_idx, rg_rewrite_expr(expr, remap))
    _ => mode
  }
}

///|
fn rg_rewrite_elem_kind(
  kind : @lib.ElemKind,
  remap : Array[Int32],
) -> @lib.ElemKind {
  match kind {
    @lib.FuncExprsElemKind(exprs) => {
      let out : Array[@lib.Expr] = Array(capacity=exprs.length())
      for expr in exprs {
        out.push(rg_rewrite_expr(expr, remap))
      }
      @lib.ElemKind::func_exprs(out)
    }
    @lib.TypedExprsElemKind(ref_type, exprs) => {
      let out : Array[@lib.Expr] = Array(capacity=exprs.length())
      for expr in exprs {
        out.push(rg_rewrite_expr(expr, remap))
      }
      @lib.ElemKind::typed_exprs(ref_type, out)
    }
    _ => kind
  }
}

///|
fn rg_rewrite_elem_sec(
  elem_sec : @lib.ElemSec?,
  remap : Array[Int32],
) -> @lib.ElemSec? {
  match elem_sec {
    Some(@lib.ElemSec(elems)) => {
      let out : Array[@lib.Elem] = Array(capacity=elems.length())
      for elem in elems {
        let @lib.Elem(mode, kind) = elem
        out.push(
          @lib.Elem::new(
            rg_rewrite_elem_mode(mode, remap),
            rg_rewrite_elem_kind(kind, remap),
          ),
        )
      }
      Some(@lib.ElemSec::new(out))
    }
    None => None
  }
}

///|
fn rg_rewrite_data_sec(
  data_sec : @lib.DataSec?,
  remap : Array[Int32],
) -> @lib.DataSec? {
  match data_sec {
    Some(@lib.DataSec(datas)) => {
      let out : Array[@lib.Data] = Array(capacity=datas.length())
      for data in datas {
        match data {
          @lib.Data(@lib.Active(mem_idx, expr), bytes) =>
            out.push(
              @lib.Data::new(
                @lib.DataMode::active(mem_idx, rg_rewrite_expr(expr, remap)),
                bytes,
              ),
            )
          @lib.Data(@lib.Passive, _) => out.push(data)
        }
      }
      Some(@lib.DataSec::new(out))
    }
    None => None
  }
}

///|
fn rg_rewrite_code_sec(
  code_sec : @lib.CodeSec?,
  remap : Array[Int32],
) -> @lib.CodeSec? {
  match code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let out : Array[@lib.Func] = Array(capacity=funcs.length())
      for func in funcs {
        let @lib.Func(locals, body) = func
        out.push(@lib.Func::new(locals, rg_rewrite_expr(body, remap)))
      }
      Some(@lib.CodeSec::new(out))
    }
    None => None
  }
}

///|
fn rg_sort_name_assocs_stable(entries : Array[@lib.NameAssoc]) -> Unit {
  let ordered : Array[(Int32, @lib.NameAssoc)] = []
  for idx = 0; idx < entries.length(); idx = idx + 1 {
    ordered.push((idx, entries[idx]))
  }
  ordered.sort_by(fn(left, right) {
    let @lib.NameAssoc(left_idx, _) = left.1
    let @lib.NameAssoc(right_idx, _) = right.1
    if left_idx < right_idx {
      -1
    } else if left_idx > right_idx {
      1
    } else {
      left.0 - right.0
    }
  })
  for idx = 0; idx < entries.length(); idx = idx + 1 {
    entries[idx] = ordered[idx].1
  }
}

///|
fn rg_rewrite_global_name_map(
  names : @lib.NameMap?,
  remap : Array[Int32],
) -> @lib.NameMap? {
  match names {
    Some(@lib.NameMap(entries)) => {
      let out : Array[@lib.NameAssoc] = Array(capacity=entries.length())
      for entry in entries {
        let @lib.NameAssoc(idx, name) = entry
        let raw = idx.reinterpret_as_int()
        if raw >= 0 && raw < remap.length() {
          out.push(@lib.NameAssoc::new(remap[raw].reinterpret_as_uint(), name))
        } else {
          out.push(entry)
        }
      }
      rg_sort_name_assocs_stable(out)
      Some(@lib.NameMap::new(out))
    }
    None => None
  }
}

///|
fn rg_rewrite_name_sec(
  name_sec : @lib.NameSec?,
  remap : Array[Int32],
) -> @lib.NameSec? {
  match name_sec {
    Some(sec) =>
      Some(
        @lib.NameSec::new(
          module_name=sec.module_name,
          func_names=sec.func_names,
          local_names=sec.local_names,
          label_names=sec.label_names,
          type_names=sec.type_names,
          table_names=sec.table_names,
          memory_names=sec.memory_names,
          global_names=rg_rewrite_global_name_map(sec.global_names, remap),
          elem_names=sec.elem_names,
          data_names=sec.data_names,
          field_names=sec.field_names,
          tag_names=sec.tag_names,
        ),
      )
    None => None
  }
}

///|

///|
fn rg_index_width(index : Int32) -> Int32 {
  if index < 128 {
    1
  } else if index < 16384 {
    2
  } else if index < 2097152 {
    3
  } else if index < 268435456 {
    4
  } else {
    5
  }
}

///|
// Every affected payload has the same length when each observed global index
// keeps the same LEB width. Function/section framing then also stays unchanged.
fn rg_equivalent_observed_widths(
  remap : Array[Int32],
  previous : Array[Int32],
  counts : Array[Int32],
) -> Bool {
  for index, count in counts {
    if count > 0 &&
      rg_index_width(remap[index]) != rg_index_width(previous[index]) {
      return false
    }
  }
  true
}

///|
fn reorder_globals_run_module_pass_with_threshold(
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
  // Reordering string initializers can also reorder an implicit string pool.
  // Keep the full comparator for that independent index space.
  let stable_string_pool = globals.all(fn(global_) {
    let @lib.Global(_, @lib.Expr(instrs)) = global_
    !instrs.any(fn(instr) { instr is @lib.StringConst(_) })
  })
  let measured_widths : Array[Array[Int32]] = []
  if mod_.raw_name_sec_payload is None && stable_string_pool {
    measured_widths.push(rg_identity_order(total_globals))
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
    if !enforce_public_threshold {
      return rg_apply_order(mod_, globals, order, imported_globals)
    }
    let widths = rg_old_abs_to_new_abs(order)
    if !stable_string_pool ||
      !measured_widths.any(fn(previous) {
        rg_equivalent_observed_widths(widths, previous, weighted)
      }) {
      let greedy = rg_apply_order(mod_, globals, order, imported_globals)
      match @binary.encoded_module_sizes(baseline, greedy) {
        Ok((before, after)) if after < before => best = greedy
        _ => ()
      }
      if stable_string_pool {
        measured_widths.push(widths)
      }
      comparisons_left -= 1
    }
  }
  // Try one traffic-ranked swap per index-width boundary. Names participate
  // in the ranking and complete module framing participates in the decision.
  // This is bounded (four boundaries for wasm u32), not an all-pairs search.
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
    if stable_string_pool &&
      measured_widths.any(fn(previous) {
        rg_equivalent_observed_widths(remap, previous, weighted)
      }) {
      continue
    }
    if stable_string_pool {
      measured_widths.push(remap)
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
    let named_widths = rg_old_abs_to_new_abs(named_order)
    if named_order != order &&
      !rg_order_is_identity(named_order) &&
      (
        !stable_string_pool ||
        !measured_widths.any(fn(previous) {
          rg_equivalent_observed_widths(named_widths, previous, weighted)
        })
      ) {
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
fn rg_apply_order(
  mod_ : @lib.Module,
  globals : Array[@lib.Global],
  order : Array[Int32],
  imported_globals : Int32,
) -> @lib.Module {
  let remap = rg_old_abs_to_new_abs(order)
  let mut out = mod_
  if globals.length() > 0 {
    out = out.with_global_sec(
      @lib.GlobalSec::new(
        rg_rewrite_globals(globals, order, imported_globals, remap),
      ),
    )
  }
  match rg_rewrite_table_sec(mod_.table_sec, remap) {
    Some(sec) => out = out.with_table_sec(sec)
    None => ()
  }
  match rg_rewrite_export_sec(mod_.export_sec, remap) {
    Some(sec) => out = out.with_export_sec(sec)
    None => ()
  }
  match rg_rewrite_elem_sec(mod_.elem_sec, remap) {
    Some(sec) => out = out.with_elem_sec(sec)
    None => ()
  }
  match rg_rewrite_data_sec(mod_.data_sec, remap) {
    Some(sec) => out = out.with_data_sec(sec)
    None => ()
  }
  match rg_rewrite_code_sec(mod_.code_sec, remap) {
    Some(sec) => out = out.with_code_sec(sec)
    None => ()
  }
  match rg_rewrite_name_sec(mod_.name_sec, remap) {
    Some(sec) => out = out.with_name_sec(sec)
    None =>
      match mod_.raw_name_sec_payload {
        Some(_) => out = out.without_name_sec()
        None => ()
      }
  }
  out
}

///|
pub fn reorder_globals_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  reorder_globals_run_module_pass_with_threshold(mod_, true)
}

///|
pub fn reorder_globals_run_module_pass_always(
  mod_ : @lib.Module,
) -> @lib.Module {
  reorder_globals_run_module_pass_with_threshold(mod_, false)
}
