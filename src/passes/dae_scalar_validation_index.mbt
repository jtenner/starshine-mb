///|
/// Dependencies belong to one checked source in one callback-free core run.
priv struct DaeScalarSyntaxIndex {
  imported : Int32
  rows : Array[Array[Int32]]
  users : Array[Array[Int32]]
  declared : Array[Bool]
  seen : Array[Int32]
  selected : Array[Bool]
}

///|
fn dae_scalar_mark_declaration(
  declared : Array[Bool],
  target : @lib.FuncIdx,
) -> Unit {
  let idx = target.0.reinterpret_as_int()
  if idx >= 0 && idx < declared.length() {
    declared[idx] = true
  }
}

///|
fn dae_scalar_mark_expr_declarations(
  instrs : Array[@lib.Instruction],
  declared : Array[Bool],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.RefFunc(target) => dae_scalar_mark_declaration(declared, target)
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        dae_scalar_mark_expr_declarations(body, declared)
      @lib.If(_, left, right) => {
        dae_scalar_mark_expr_declarations(left, declared)
        match right {
          Some(body) => dae_scalar_mark_expr_declarations(body, declared)
          None => ()
        }
      }
      @lib.Try(_, @lib.Expr(body), catches, _) => {
        dae_scalar_mark_expr_declarations(body, declared)
        for catch_ in catches {
          let expr = match catch_ {
            @lib.LegacyCatch(_, expr) | @lib.LegacyCatchAll(expr) => expr
          }
          dae_scalar_mark_expr_declarations(expr.0, declared)
        }
      }
      _ => ()
    }
  }
}

///|
/// Match the generic validator's declaration sources, excluding start.
fn dae_scalar_declared_funcs(
  source : @lib.Module,
  total : Int32,
) -> Array[Bool] {
  let declared = Array::make(total, false)
  match source.export_sec {
    Some(@lib.ExportSec(exports)) =>
      for export_ in exports {
        match export_ {
          @lib.Export(_, @lib.FuncExternIdx(target)) =>
            dae_scalar_mark_declaration(declared, target)
          _ => ()
        }
      }
    None => ()
  }
  match source.global_sec {
    Some(@lib.GlobalSec(globals)) =>
      for global in globals {
        let @lib.Global(_, expr) = global
        dae_scalar_mark_expr_declarations(expr.0, declared)
      }
    None => ()
  }
  match source.table_sec {
    Some(@lib.TableSec(tables)) =>
      for table in tables {
        let @lib.Table(_, init) = table
        match init {
          Some(expr) => dae_scalar_mark_expr_declarations(expr.0, declared)
          None => ()
        }
      }
    None => ()
  }
  match source.elem_sec {
    Some(@lib.ElemSec(elems)) =>
      for elem in elems {
        let @lib.Elem(_, kind) = elem
        match kind {
          @lib.FuncsElemKind(targets) =>
            for target in targets {
              dae_scalar_mark_declaration(declared, target)
            }
          @lib.FuncExprsElemKind(exprs) | @lib.TypedExprsElemKind(_, exprs) =>
            for expr in exprs {
              dae_scalar_mark_expr_declarations(expr.0, declared)
            }
        }
      }
    None => ()
  }
  declared
}

///|
/// Visit every scope, including inactive suffixes and all legacy catches.
fn dae_scalar_scan_dependencies(
  instrs : Array[@lib.Instruction],
  index : DaeScalarSyntaxIndex,
  has_data_count : Bool,
  out : Array[Int32],
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Call(target) | @lib.ReturnCall(target) | @lib.RefFunc(target) => {
        let abs = target.0.reinterpret_as_int()
        if abs < 0 || abs >= index.declared.length() {
          return false
        }
        match instr {
          @lib.RefFunc(_) if !index.declared[abs] => return false
          _ => ()
        }
        let def = abs - index.imported
        if def >= 0 && index.seen[def] == 0 {
          index.seen[def] = 1
          out.push(def)
        }
      }
      @lib.MemoryInit(_, _) | @lib.DataDrop(_) if !has_data_count =>
        return false
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if !dae_scalar_scan_dependencies(body, index, has_data_count, out) {
          return false
        }
      @lib.If(_, left, right) => {
        if !dae_scalar_scan_dependencies(left, index, has_data_count, out) {
          return false
        }
        match right {
          Some(body) =>
            if !dae_scalar_scan_dependencies(body, index, has_data_count, out) {
              return false
            }
          None => ()
        }
      }
      @lib.Try(_, @lib.Expr(body), catches, _) => {
        if !dae_scalar_scan_dependencies(body, index, has_data_count, out) {
          return false
        }
        for catch_ in catches {
          let expr = match catch_ {
            @lib.LegacyCatch(_, expr) | @lib.LegacyCatchAll(expr) => expr
          }
          if !dae_scalar_scan_dependencies(expr.0, index, has_data_count, out) {
            return false
          }
        }
      }
      _ => ()
    }
  }
  true
}

///|
fn dae_scalar_dependency_row(
  func : @lib.Func,
  index : DaeScalarSyntaxIndex,
  has_data_count : Bool,
) -> Array[Int32]? {
  let @lib.Func(_, @lib.Expr(body)) = func
  let out : Array[Int32] = []
  let ok = dae_scalar_scan_dependencies(body, index, has_data_count, out)
  for target in out {
    index.seen[target] = 0
  }
  if ok {
    Some(out)
  } else {
    None
  }
}

///|
/// Empty buckets may be shared. Never push into a shared empty bucket.
fn dae_scalar_add_user(
  index : DaeScalarSyntaxIndex,
  target : Int32,
  caller : Int32,
) -> Unit {
  let users = index.users[target]
  if users.is_empty() {
    index.users[target] = [caller]
  } else {
    users.push(caller)
  }
}

///|
fn dae_scalar_remove_user(
  index : DaeScalarSyntaxIndex,
  target : Int32,
  caller : Int32,
  work~ : DaeScalarValidationWork? = None,
) -> Unit {
  let users = index.users[target]
  for slot in 0..<users.length() {
    if users[slot] == caller {
      // This slot is the final equality comparison actually executed.
      match work {
        Some(counts) => {
          counts.reverse_comparisons += slot + 1
          counts.removed_dependencies += 1
        }
        None => ()
      }
      let last = users.pop().unwrap()
      if slot < users.length() {
        users[slot] = last
      }
      return
    }
  }
}

///|
/// Update only edge differences; unchanged edges need no reverse-bucket scan.
fn dae_scalar_replace_dependency_row(
  index : DaeScalarSyntaxIndex,
  caller : Int32,
  next : Array[Int32],
  work~ : DaeScalarValidationWork? = None,
) -> Unit {
  let old = index.rows[caller]
  for target in old {
    index.seen[target] = 1
  }
  for target in next {
    index.seen[target] += 2
  }
  for target in old {
    if index.seen[target] == 1 {
      dae_scalar_remove_user(index, target, caller, work~)
    }
  }
  for target in next {
    if index.seen[target] == 2 {
      dae_scalar_add_user(index, target, caller)
    }
  }
  for target in old {
    index.seen[target] = 0
  }
  for target in next {
    index.seen[target] = 0
  }
  index.rows[caller] = next
}

///|
/// Called lazily after a second candidate passes the module/type envelope.
fn dae_scalar_syntax_index(source : @lib.Module) -> DaeScalarSyntaxIndex? {
  let funcs = source.code_sec.unwrap().0
  let defined = funcs.length()
  let imported = dae_imported_func_count(source)
  let index = {
    imported,
    rows: Array::make(defined, []),
    users: Array::make(defined, []),
    declared: dae_scalar_declared_funcs(source, imported + defined),
    seen: Array::make(defined, 0),
    selected: Array::make(defined, false),
  }
  for caller in 0..<defined {
    let row = match
      dae_scalar_dependency_row(
        funcs[caller],
        index,
        source.data_cnt_sec is Some(_),
      ) {
      Some(row) => row
      None => return None
    }
    index.rows[caller] = row
    for target in row {
      dae_scalar_add_user(index, target, caller)
    }
  }
  Some(index)
}
