///|
priv struct RumeHostRootScan {
  total_funcs : Int32
  mut highest : Int32
  mut remaining : Int32
}

///|
fn RumeHostRootScan::new(
  total_funcs : Int32,
  work_limit : Int32,
) -> RumeHostRootScan {
  { total_funcs, highest: -1, remaining: work_limit, }
}

///|
fn RumeHostRootScan::consume(self : RumeHostRootScan, count : Int32) -> Bool {
  if count < 0 || count > self.remaining {
    return false
  }
  self.remaining -= count
  true
}

///|
fn RumeHostRootScan::note(self : RumeHostRootScan, idx : @lib.FuncIdx) -> Bool {
  let @lib.FuncIdx(raw) = idx
  if !self.consume(1) || raw >= self.total_funcs.to_uint() {
    return false
  }
  if raw.to_int() > self.highest {
    self.highest = raw.to_int()
  }
  true
}

///|
fn RumeHostRootScan::body(
  self : RumeHostRootScan,
  body : Array[@lib.Instruction],
  depth : Int32,
) -> Bool {
  // Check before descent. Scratch grows with depth, never with body width.
  if depth > 256 || !self.consume(1 + body.length()) {
    return false
  }
  for instr in body {
    match instr {
      @lib.RefFunc(idx) => if !self.note(idx) { return false }
      @lib.Block(_, @lib.Expr(nested))
      | @lib.Loop(_, @lib.Expr(nested))
      | @lib.TryTable(_, _, @lib.Expr(nested)) =>
        if !self.body(nested, depth + 1) {
          return false
        }
      @lib.If(_, yes, no) => {
        if !self.body(yes, depth + 1) {
          return false
        }
        match no {
          Some(nested) => if !self.body(nested, depth + 1) { return false }
          None => ()
        }
      }
      @lib.Try(_, @lib.Expr(nested), catches, _) => {
        if !self.body(nested, depth + 1) || !self.consume(catches.length()) {
          return false
        }
        for catch_ in catches {
          match catch_ {
            @lib.LegacyCatch(_, @lib.Expr(nested))
            | @lib.LegacyCatchAll(@lib.Expr(nested)) =>
              if !self.body(nested, depth + 1) {
                return false
              }
          }
        }
      }
      _ => ()
    }
  }
  true
}

///|
fn rume_host_root_prefix(
  mod_ : @lib.Module,
  selected : Array[@lib.Export],
  work_limit~ : Int32 = 8000000,
) -> Int32? {
  let imported = rume_imported_func_count(mod_)
  let defined = rume_defined_func_count(mod_)
  if imported > 100000 || defined > 100000 - imported {
    return None
  }
  let scan = RumeHostRootScan::new(imported + defined, work_limit)
  if !scan.consume(imported + defined + selected.length()) {
    return None
  }
  for @lib.Export(_, idx) in selected {
    match idx {
      @lib.FuncExternIdx(idx) => if !scan.note(idx) { return None }
      _ => ()
    }
  }
  // Scan all source references, including dead bodies and segments. Prefix-only
  // bodies can expose a later target; this avoids repeated widening scans.
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for @lib.Func(locals, @lib.Expr(body)) in funcs {
        if !scan.consume(locals.run_count()) || !scan.body(body, 0) {
          return None
        }
      }
    None => ()
  }
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) =>
      for @lib.Global(_, @lib.Expr(body)) in globals {
        if !scan.body(body, 0) {
          return None
        }
      }
    None => ()
  }
  match mod_.table_sec {
    Some(@lib.TableSec(tables)) => {
      if !scan.consume(tables.length()) {
        return None
      }
      for @lib.Table(_, init) in tables {
        match init {
          Some(@lib.Expr(body)) => if !scan.body(body, 0) { return None }
          None => ()
        }
      }
    }
    None => ()
  }
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) => {
      if !scan.consume(elems.length()) {
        return None
      }
      for @lib.Elem(mode, kind) in elems {
        match mode {
          @lib.Active(_, @lib.Expr(body)) =>
            if !scan.body(body, 0) {
              return None
            }
          _ => ()
        }
        match kind {
          @lib.FuncsElemKind(funcs) =>
            for idx in funcs {
              if !scan.note(idx) {
                return None
              }
            }
          @lib.FuncExprsElemKind(exprs) | @lib.TypedExprsElemKind(_, exprs) =>
            for @lib.Expr(body) in exprs {
              if !scan.body(body, 0) {
                return None
              }
            }
        }
      }
    }
    None => ()
  }
  match mod_.data_sec {
    Some(@lib.DataSec(data)) => {
      if !scan.consume(data.length()) {
        return None
      }
      for @lib.Data(mode, _) in data {
        match mode {
          @lib.Active(_, @lib.Expr(body)) =>
            if !scan.body(body, 0) {
              return None
            }
          _ => ()
        }
      }
    }
    None => ()
  }
  Some(scan.highest + 1)
}

///|
/// Apply an explicit application's exact export allowlist. Omitted exports are
/// outside its interface. Duplicate root names have set semantics; retained
/// export order, aliases and kinds follow the source module.
///
/// Imports, initialization and exposed function identities/numeric names remain
/// observable. Prefix retention preserves those names relative to this input.
/// Use this as the final mutating transform: later ordinary removal/merging can
/// invalidate that guarantee. Unsupported metadata or scan limits return Err.
pub fn rume_run_host_roots_module_pass(
  mod_ : @lib.Module,
  roots : Array[String],
) -> Result[@lib.Module, String] {
  if rume_has_unrewritable_metadata(mod_) ||
    rume_module_has_offset_sensitive_metadata(mod_) {
    return Err("host roots: unsupported offset-sensitive or raw name metadata")
  }
  let exports = match mod_.export_sec {
    Some(@lib.ExportSec(exports)) => exports
    None => []
  }
  if roots.length() > 100000 || exports.length() > 100000 {
    return Err("host roots: export count limit exceeded")
  }
  let requested : @hashmap.HashMap[String, Bool] = @hashmap.new()
  let mut name_work = 8000000
  for root in roots {
    if root.length() > name_work {
      return Err("host roots: name work limit exceeded")
    }
    name_work -= root.length()
    requested.set(root, false)
  }
  let selected : Array[@lib.Export] = []
  for export_ in exports {
    let @lib.Export(@lib.Name(raw), _) = export_
    if raw.length() > name_work {
      return Err("host roots: name work limit exceeded")
    }
    name_work -= raw.length()
    let name = raw.to_owned()
    if requested.get(name) is Some(_) {
      requested.set(name, true)
      selected.push(export_)
    }
  }
  for root in roots {
    if requested.get(root) != Some(true) {
      return Err("host roots: unknown export \{root}")
    }
  }
  let prefix = match rume_host_root_prefix(mod_, selected) {
    Some(prefix) => prefix
    None =>
      return Err("host roots: reference scan limit or invalid function index")
  }
  match @validate.validate_module(mod_) {
    Err(err) => return Err("host roots: invalid input: \{err}")
    Ok(_) => ()
  }
  let rooted = match mod_.export_sec {
    Some(_) => mod_.with_export_sec(@lib.ExportSec::new(selected))
    None => mod_
  }
  let output = rume_run_module_pass_with_prefix(rooted, prefix)
  match @validate.validate_module(output) {
    Ok(_) => Ok(output)
    Err(err) => Err("host roots: invalid result: \{err}")
  }
}
