///|
pub fn reorder_globals_summary() -> String {
  "Reorder imported and defined globals by Binaryen's public size policy and remap numeric global indices."
}

///|
fn rg_imported_global_count(mod_ : @lib.Module) -> Int {
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
fn rg_global_idx_raw(idx : @lib.GlobalIdx) -> Int {
  let @lib.GlobalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn rg_global_idx_from_int(idx : Int) -> @lib.GlobalIdx {
  @lib.GlobalIdx::new(idx.reinterpret_as_uint())
}

///|
fn rg_note_global_use(counts : Array[Int], idx : @lib.GlobalIdx) -> Unit {
  let raw = rg_global_idx_raw(idx)
  if raw >= 0 && raw < counts.length() {
    counts[raw] += 1
  }
}

///|
fn rg_count_expr(expr : @lib.Expr, counts : Array[Int]) -> Unit {
  let @lib.Expr(instrs) = expr
  rg_count_instrs(instrs, counts)
}

///|
fn rg_count_instrs(
  instrs : Array[@lib.Instruction],
  counts : Array[Int],
) -> Unit {
  for instr in instrs {
    rg_count_instruction(instr, counts)
  }
}

///|
fn rg_count_instruction(instr : @lib.Instruction, counts : Array[Int]) -> Unit {
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
fn rg_count_elem_kind(kind : @lib.ElemKind, counts : Array[Int]) -> Unit {
  match kind {
    @lib.FuncExprsElemKind(exprs) | @lib.TypedExprsElemKind(_, exprs) =>
      for expr in exprs {
        rg_count_expr(expr, counts)
      }
    _ => ()
  }
}

///|
fn rg_count_elem_mode(mode : @lib.ElemMode, counts : Array[Int]) -> Unit {
  match mode {
    @lib.Active(_, expr) => rg_count_expr(expr, counts)
    _ => ()
  }
}

///|
fn rg_count_data_mode(mode : @lib.DataMode, counts : Array[Int]) -> Unit {
  match mode {
    @lib.Active(_, expr) => rg_count_expr(expr, counts)
    _ => ()
  }
}

///|
fn rg_count_global_traffic(
  mod_ : @lib.Module,
  total_globals : Int,
) -> Array[Int] {
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
  deps : Array[Int],
  idx : @lib.GlobalIdx,
  total : Int,
) -> Unit {
  let raw = rg_global_idx_raw(idx)
  if raw >= 0 && raw < total && !deps.contains(raw) {
    deps.push(raw)
  }
}

///|
fn rg_collect_expr_global_deps(
  expr : @lib.Expr,
  total_globals : Int,
  deps : Array[Int],
) -> Unit {
  let @lib.Expr(instrs) = expr
  rg_collect_instrs_global_deps(instrs, total_globals, deps)
}

///|
fn rg_collect_instrs_global_deps(
  instrs : Array[@lib.Instruction],
  total_globals : Int,
  deps : Array[Int],
) -> Unit {
  for instr in instrs {
    rg_collect_instruction_global_deps(instr, total_globals, deps)
  }
}

///|
fn rg_collect_instruction_global_deps(
  instr : @lib.Instruction,
  total_globals : Int,
  deps : Array[Int],
) -> Unit {
  match instr {
    @lib.Block(_, body) =>
      rg_collect_expr_global_deps(body, total_globals, deps)
    @lib.Loop(_, body) => rg_collect_expr_global_deps(body, total_globals, deps)
    @lib.If(_, then_body, else_body) => {
      rg_collect_instrs_global_deps(then_body, total_globals, deps)
      match else_body {
        Some(body) => rg_collect_instrs_global_deps(body, total_globals, deps)
        None => ()
      }
    }
    @lib.Try(_, body, catches, _) => {
      rg_collect_expr_global_deps(body, total_globals, deps)
      for catch_ in catches {
        match catch_ {
          @lib.LegacyCatch(_, catch_body) | @lib.LegacyCatchAll(catch_body) =>
            rg_collect_expr_global_deps(catch_body, total_globals, deps)
        }
      }
    }
    @lib.TryTable(_, _, body) =>
      rg_collect_expr_global_deps(body, total_globals, deps)
    @lib.GlobalGet(idx) => rg_note_global_dep(deps, idx, total_globals)
    _ => ()
  }
}

///|
fn rg_build_dependency_graph(
  globals : Array[@lib.Global],
  imported_globals : Int,
) -> Array[Array[Int]] {
  let total_globals = imported_globals + globals.length()
  let graph : Array[Array[Int]] = Array::new(capacity=total_globals)
  for idx = 0; idx < total_globals; idx = idx + 1 {
    ignore(idx)
    graph.push([])
  }
  for defined_idx = 0
      defined_idx < globals.length()
      defined_idx = defined_idx + 1 {
    let @lib.Global(_, init) = globals[defined_idx]
    let dependent = imported_globals + defined_idx
    let dependencies : Array[Int] = []
    rg_collect_expr_global_deps(init, total_globals, dependencies)
    for dependency in dependencies {
      if dependency != dependent {
        graph[dependency].push(dependent)
      }
    }
  }
  graph
}

///|
fn rg_candidate_is_better(
  candidate : Int,
  best : Int,
  custom_counts : Array[Double],
  imported_globals : Int,
) -> Bool {
  if best < 0 {
    return true
  }
  let candidate_imported = candidate < imported_globals
  let best_imported = best < imported_globals
  if candidate_imported != best_imported {
    return candidate_imported
  }
  custom_counts[candidate] > custom_counts[best] ||
  (custom_counts[candidate] == custom_counts[best] && candidate < best)
}

///|
fn rg_candidate_order(
  deps : Array[Array[Int]],
  custom_counts : Array[Double],
  imported_globals : Int,
) -> Array[Int] {
  let n = custom_counts.length()
  let indegrees = Array::make(n, 0)
  for dependency = 0; dependency < n; dependency = dependency + 1 {
    for dependent in deps[dependency] {
      indegrees[dependent] += 1
    }
  }
  let emitted = Array::make(n, false)
  let order : Array[Int] = Array::new(capacity=n)
  while order.length() < n {
    let mut best = -1
    for candidate = 0; candidate < n; candidate = candidate + 1 {
      if !emitted[candidate] &&
        indegrees[candidate] == 0 &&
        rg_candidate_is_better(candidate, best, custom_counts, imported_globals) {
        best = candidate
      }
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
      }
    }
  }
  order
}

///|
fn rg_true_counts(counts : Array[Int]) -> Array[Double] {
  let out : Array[Double] = Array::new(capacity=counts.length())
  for count in counts {
    out.push(count.to_double())
  }
  out
}

///|
fn rg_summed_dependent_counts(
  deps : Array[Array[Int]],
  base : Array[Double],
  imported_globals : Int,
) -> Array[Double] {
  let out = base.copy()
  let topological = rg_candidate_order(
    deps,
    Array::make(base.length(), 0.0),
    imported_globals,
  )
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
  deps : Array[Array[Int]],
  base : Array[Double],
  imported_globals : Int,
) -> Array[Double] {
  let out = base.copy()
  let topological = rg_candidate_order(
    deps,
    Array::make(base.length(), 0.0),
    imported_globals,
  )
  for pos = topological.length() - 1; pos >= 0; pos = pos - 1 {
    let dependency = topological[pos]
    for dependent in deps[dependency] {
      out[dependency] += 0.095 * out[dependent]
    }
  }
  out
}

///|
fn rg_uleb_size(raw : Int) -> Int {
  let mut value = raw
  let mut size = 1
  while value >= 128 {
    value = value / 128
    size += 1
  }
  size
}

///|
fn rg_order_cost(order : Array[Int], true_counts : Array[Double]) -> Double {
  let mut cost = 0.0
  for new_idx = 0; new_idx < order.length(); new_idx = new_idx + 1 {
    let old_idx = order[new_idx]
    cost += true_counts[old_idx] * rg_uleb_size(new_idx).to_double()
  }
  cost
}

///|
fn rg_choose_order(
  deps : Array[Array[Int]],
  true_counts : Array[Double],
  imported_globals : Int,
) -> Array[Int] {
  let candidates : Array[Array[Int]] = []
  candidates.push(
    rg_candidate_order(
      deps,
      Array::make(true_counts.length(), 0.0),
      imported_globals,
    ),
  )
  candidates.push(rg_candidate_order(deps, true_counts, imported_globals))
  candidates.push(
    rg_candidate_order(
      deps,
      rg_summed_dependent_counts(deps, true_counts, imported_globals),
      imported_globals,
    ),
  )
  candidates.push(
    rg_candidate_order(
      deps,
      rg_exponential_dependent_counts(deps, true_counts, imported_globals),
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
fn rg_order_is_identity(order : Array[Int]) -> Bool {
  for idx = 0; idx < order.length(); idx = idx + 1 {
    if order[idx] != idx {
      return false
    }
  }
  true
}

///|
fn rg_old_abs_to_new_abs(order : Array[Int]) -> Array[Int] {
  let remap = Array::make(order.length(), 0)
  for new_idx = 0; new_idx < order.length(); new_idx = new_idx + 1 {
    remap[order[new_idx]] = new_idx
  }
  remap
}

///|
fn rg_rewrite_global_idx(
  idx : @lib.GlobalIdx,
  remap : Array[Int],
) -> @lib.GlobalIdx {
  let raw = rg_global_idx_raw(idx)
  if raw >= 0 && raw < remap.length() {
    rg_global_idx_from_int(remap[raw])
  } else {
    idx
  }
}

///|
fn rg_rewrite_expr(expr : @lib.Expr, remap : Array[Int]) -> @lib.Expr {
  let @lib.Expr(instrs) = expr
  rg_rewrite_instrs_in_place(instrs, remap)
  @lib.Expr::new(instrs)
}

///|
fn rg_rewrite_instrs_in_place(
  instrs : Array[@lib.Instruction],
  remap : Array[Int],
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
        rg_rewrite_instrs_in_place(then_body, remap)
        let rewritten_else = match else_body {
          Some(body) => {
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
  remap : Array[Int],
) -> @lib.TableSec? {
  match table_sec {
    Some(@lib.TableSec(tables)) => {
      let out : Array[@lib.Table] = Array::new(capacity=tables.length())
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
fn rg_rewrite_import_sec(
  import_sec : @lib.ImportSec?,
  order : Array[Int],
  imported_globals : Int,
) -> @lib.ImportSec? {
  match import_sec {
    Some(@lib.ImportSec(imports)) => {
      let global_imports : Array[@lib.Import] = Array::new(
        capacity=imported_globals,
      )
      for import_ in imports {
        if import_ is @lib.Import(_, _, @lib.GlobalExternType(_)) {
          global_imports.push(import_)
        }
      }
      let reordered : Array[@lib.Import] = Array::new(capacity=imported_globals)
      for old_global in order {
        if old_global < imported_globals {
          reordered.push(global_imports[old_global])
        }
      }
      let out : Array[@lib.Import] = Array::new(capacity=imports.length())
      let mut next_global = 0
      for import_ in imports {
        if import_ is @lib.Import(_, _, @lib.GlobalExternType(_)) {
          out.push(reordered[next_global])
          next_global += 1
        } else {
          out.push(import_)
        }
      }
      Some(@lib.ImportSec::new(out))
    }
    None => None
  }
}

///|
fn rg_rewrite_globals(
  globals : Array[@lib.Global],
  order : Array[Int],
  imported_globals : Int,
  remap : Array[Int],
) -> Array[@lib.Global] {
  let out : Array[@lib.Global] = Array::new(capacity=globals.length())
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
  remap : Array[Int],
) -> @lib.ExportSec? {
  match export_sec {
    Some(@lib.ExportSec(exports)) => {
      let out : Array[@lib.Export] = Array::new(capacity=exports.length())
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
  remap : Array[Int],
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
  remap : Array[Int],
) -> @lib.ElemKind {
  match kind {
    @lib.FuncExprsElemKind(exprs) => {
      let out : Array[@lib.Expr] = Array::new(capacity=exprs.length())
      for expr in exprs {
        out.push(rg_rewrite_expr(expr, remap))
      }
      @lib.ElemKind::func_exprs(out)
    }
    @lib.TypedExprsElemKind(ref_type, exprs) => {
      let out : Array[@lib.Expr] = Array::new(capacity=exprs.length())
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
  remap : Array[Int],
) -> @lib.ElemSec? {
  match elem_sec {
    Some(@lib.ElemSec(elems)) => {
      let out : Array[@lib.Elem] = Array::new(capacity=elems.length())
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
  remap : Array[Int],
) -> @lib.DataSec? {
  match data_sec {
    Some(@lib.DataSec(datas)) => {
      let out : Array[@lib.Data] = Array::new(capacity=datas.length())
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
  remap : Array[Int],
) -> @lib.CodeSec? {
  match code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let out : Array[@lib.Func] = Array::new(capacity=funcs.length())
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
fn rg_sort_name_assocs(entries : Array[@lib.NameAssoc]) -> Unit {
  let mut i = 1
  while i < entries.length() {
    let current = entries[i]
    let @lib.NameAssoc(current_idx, _) = current
    let mut j = i
    while j > 0 {
      let @lib.NameAssoc(prev_idx, _) = entries[j - 1]
      if prev_idx <= current_idx {
        break
      }
      entries[j] = entries[j - 1]
      j -= 1
    }
    entries[j] = current
    i += 1
  }
}

///|
fn rg_rewrite_global_name_map(
  names : @lib.NameMap?,
  remap : Array[Int],
) -> @lib.NameMap? {
  match names {
    Some(@lib.NameMap(entries)) => {
      let out : Array[@lib.NameAssoc] = Array::new(capacity=entries.length())
      for entry in entries {
        let @lib.NameAssoc(idx, name) = entry
        let raw = idx.reinterpret_as_int()
        if raw >= 0 && raw < remap.length() {
          out.push(@lib.NameAssoc::new(remap[raw].reinterpret_as_uint(), name))
        } else {
          out.push(entry)
        }
      }
      rg_sort_name_assocs(out)
      Some(@lib.NameMap::new(out))
    }
    None => None
  }
}

///|
fn rg_rewrite_name_sec(
  name_sec : @lib.NameSec?,
  remap : Array[Int],
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
fn reorder_globals_run_module_pass_with_threshold(
  mod_ : @lib.Module,
  enforce_public_threshold : Bool,
) -> @lib.Module {
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
  if rg_order_is_identity(order) {
    return mod_
  }
  let remap = rg_old_abs_to_new_abs(order)
  let mut out = mod_
  match rg_rewrite_import_sec(mod_.import_sec, order, imported_globals) {
    Some(sec) => out = out.with_import_sec(sec)
    None => ()
  }
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
