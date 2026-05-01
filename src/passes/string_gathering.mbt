///|
pub fn string_gathering_summary() -> String {
  "Hoist wasm string constants into shared immutable string globals and rewrite uses to global.get."
}

///|
priv struct SgStringSet {
  strings : Array[Bytes]
}

///|
fn SgStringSet::new() -> SgStringSet {
  { strings: [] }
}

///|
fn sg_string_index(set : SgStringSet, bytes : Bytes) -> Int? {
  for idx = 0; idx < set.strings.length(); idx = idx + 1 {
    if set.strings[idx] == bytes {
      return Some(idx)
    }
  }
  None
}

///|
fn sg_intern_string(set : SgStringSet, bytes : Bytes) -> Int {
  match sg_string_index(set, bytes) {
    Some(idx) => idx
    None => {
      let idx = set.strings.length()
      set.strings.push(bytes)
      idx
    }
  }
}

///|
fn sg_collect_instr(instr : @lib.Instruction, set : SgStringSet) -> Unit {
  match instr {
    @lib.StringConst(bytes) => ignore(sg_intern_string(set, bytes))
    @lib.Block(_, body) | @lib.Loop(_, body) => sg_collect_expr(body, set)
    @lib.If(_, then_body, else_body) => {
      sg_collect_instrs(then_body, set)
      match else_body {
        Some(body) => sg_collect_instrs(body, set)
        None => ()
      }
    }
    @lib.TryTable(_, _, body) => sg_collect_expr(body, set)
    _ => ()
  }
}

///|
fn sg_collect_instrs(
  instrs : Array[@lib.Instruction],
  set : SgStringSet,
) -> Unit {
  for instr in instrs {
    sg_collect_instr(instr, set)
  }
}

///|
fn sg_collect_expr(expr : @lib.Expr, set : SgStringSet) -> Unit {
  let @lib.Expr(instrs) = expr
  sg_collect_instrs(instrs, set)
}

///|
fn sg_collect_table_sec(table_sec : @lib.TableSec?, set : SgStringSet) -> Unit {
  match table_sec {
    Some(@lib.TableSec(tables)) =>
      for table in tables {
        match table {
          @lib.Table(_, Some(init)) => sg_collect_expr(init, set)
          _ => ()
        }
      }
    None => ()
  }
}

///|
fn sg_collect_code_sec(code_sec : @lib.CodeSec?, set : SgStringSet) -> Unit {
  match code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(_, body) = func
        sg_collect_expr(body, set)
      }
    None => ()
  }
}

///|
fn sg_collect_global_sec(
  global_sec : @lib.GlobalSec?,
  set : SgStringSet,
) -> Unit {
  match global_sec {
    Some(@lib.GlobalSec(globals)) =>
      for global in globals {
        let @lib.Global(_, init) = global
        sg_collect_expr(init, set)
      }
    None => ()
  }
}

///|
fn sg_collect_elem_mode(mode : @lib.ElemMode, set : SgStringSet) -> Unit {
  match mode {
    @lib.Active(_, expr) => sg_collect_expr(expr, set)
    _ => ()
  }
}

///|
fn sg_collect_elem_kind(kind : @lib.ElemKind, set : SgStringSet) -> Unit {
  match kind {
    @lib.FuncExprsElemKind(exprs) | @lib.TypedExprsElemKind(_, exprs) =>
      for expr in exprs {
        sg_collect_expr(expr, set)
      }
    _ => ()
  }
}

///|
fn sg_collect_elem_sec(elem_sec : @lib.ElemSec?, set : SgStringSet) -> Unit {
  match elem_sec {
    Some(@lib.ElemSec(elems)) =>
      for elem in elems {
        let @lib.Elem(mode, kind) = elem
        sg_collect_elem_mode(mode, set)
        sg_collect_elem_kind(kind, set)
      }
    None => ()
  }
}

///|
fn sg_collect_data_sec(data_sec : @lib.DataSec?, set : SgStringSet) -> Unit {
  match data_sec {
    Some(@lib.DataSec(datas)) =>
      for data in datas {
        let @lib.Data(mode, _) = data
        match mode {
          @lib.Active(_, expr) => sg_collect_expr(expr, set)
          _ => ()
        }
      }
    None => ()
  }
}

///|
fn sg_collect_strings(mod_ : @lib.Module) -> SgStringSet {
  let set = SgStringSet::new()
  // Binaryen's StringGathering visits function bodies before module-level
  // constant expressions, then inserts gathered globals before existing defined
  // globals. Keep that order for normalized-WAT parity.
  sg_collect_code_sec(mod_.code_sec, set)
  sg_collect_table_sec(mod_.table_sec, set)
  sg_collect_global_sec(mod_.global_sec, set)
  sg_collect_elem_sec(mod_.elem_sec, set)
  sg_collect_data_sec(mod_.data_sec, set)
  set
}

///|
fn sg_imported_global_count(mod_ : @lib.Module) -> Int {
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
fn sg_global_idx_raw(idx : @lib.GlobalIdx) -> Int {
  let @lib.GlobalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn sg_global_idx(raw : Int) -> @lib.GlobalIdx {
  @lib.GlobalIdx::new(raw.reinterpret_as_uint())
}

///|
fn sg_remap_existing_global_idx(
  idx : @lib.GlobalIdx,
  imported_globals : Int,
  inserted_globals : Int,
) -> @lib.GlobalIdx {
  let raw = sg_global_idx_raw(idx)
  if raw >= imported_globals {
    sg_global_idx(raw + inserted_globals)
  } else {
    idx
  }
}

///|
fn sg_string_global_idx(
  set : SgStringSet,
  bytes : Bytes,
  imported_globals : Int,
) -> @lib.GlobalIdx {
  let idx = match sg_string_index(set, bytes) {
    Some(idx) => idx
    None => abort("string-gathering rewrite saw uncollected string constant")
  }
  sg_global_idx(imported_globals + idx)
}

///|
fn sg_rewrite_instr(
  instr : @lib.Instruction,
  set : SgStringSet,
  imported_globals : Int,
) -> @lib.Instruction {
  match instr {
    @lib.StringConst(bytes) =>
      @lib.Instruction::global_get(
        sg_string_global_idx(set, bytes, imported_globals),
      )
    @lib.GlobalGet(idx) =>
      @lib.Instruction::global_get(
        sg_remap_existing_global_idx(
          idx,
          imported_globals,
          set.strings.length(),
        ),
      )
    @lib.GlobalSet(idx) =>
      @lib.Instruction::global_set(
        sg_remap_existing_global_idx(
          idx,
          imported_globals,
          set.strings.length(),
        ),
      )
    @lib.Block(block_type, body) =>
      @lib.Instruction::block(
        block_type,
        sg_rewrite_expr(body, set, imported_globals),
      )
    @lib.Loop(block_type, body) =>
      @lib.Instruction::loop_(
        block_type,
        sg_rewrite_expr(body, set, imported_globals),
      )
    @lib.If(block_type, then_body, else_body) => {
      let next_then = sg_rewrite_instrs(then_body, set, imported_globals)
      let next_else = match else_body {
        Some(body) => Some(sg_rewrite_instrs(body, set, imported_globals))
        None => None
      }
      @lib.Instruction::if_(block_type, next_then, next_else)
    }
    @lib.TryTable(block_type, catches, body) =>
      @lib.Instruction::try_table(
        block_type,
        catches,
        sg_rewrite_expr(body, set, imported_globals),
      )
    _ => instr
  }
}

///|
fn sg_rewrite_instrs(
  instrs : Array[@lib.Instruction],
  set : SgStringSet,
  imported_globals : Int,
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    out.push(sg_rewrite_instr(instr, set, imported_globals))
  }
  out
}

///|
fn sg_rewrite_expr(
  expr : @lib.Expr,
  set : SgStringSet,
  imported_globals : Int,
) -> @lib.Expr {
  let @lib.Expr(instrs) = expr
  @lib.Expr::new(sg_rewrite_instrs(instrs, set, imported_globals))
}

///|
fn sg_rewrite_table_sec(
  table_sec : @lib.TableSec?,
  set : SgStringSet,
  imported_globals : Int,
) -> @lib.TableSec? {
  match table_sec {
    Some(@lib.TableSec(tables)) => {
      let out : Array[@lib.Table] = []
      for table in tables {
        match table {
          @lib.Table(table_type, Some(init)) =>
            out.push(
              @lib.Table::new(
                table_type,
                Some(sg_rewrite_expr(init, set, imported_globals)),
              ),
            )
          @lib.Table(_, _) => out.push(table)
        }
      }
      Some(@lib.TableSec::new(out))
    }
    None => None
  }
}

///|
fn sg_rewrite_global_sec(
  global_sec : @lib.GlobalSec?,
  set : SgStringSet,
  imported_globals : Int,
) -> @lib.GlobalSec {
  let out : Array[@lib.Global] = []
  let string_global_type = @lib.GlobalType::new(
    @lib.ValType::stringref(),
    false,
  )
  for bytes in set.strings {
    out.push(
      @lib.Global::new(
        string_global_type,
        @lib.Expr::new([@lib.Instruction::string_const(bytes)]),
      ),
    )
  }
  match global_sec {
    Some(@lib.GlobalSec(globals)) =>
      for global in globals {
        let @lib.Global(global_type, init) = global
        out.push(
          @lib.Global::new(
            global_type,
            sg_rewrite_expr(init, set, imported_globals),
          ),
        )
      }
    None => ()
  }
  @lib.GlobalSec::new(out)
}

///|
fn sg_rewrite_export_sec(
  export_sec : @lib.ExportSec?,
  imported_globals : Int,
  inserted_globals : Int,
) -> @lib.ExportSec? {
  match export_sec {
    Some(@lib.ExportSec(exports)) => {
      let out : Array[@lib.Export] = []
      for export_ in exports {
        match export_ {
          @lib.Export(name, @lib.GlobalExternIdx(idx)) =>
            out.push(
              @lib.Export::new(
                name,
                @lib.ExternIdx::global(
                  sg_remap_existing_global_idx(
                    idx, imported_globals, inserted_globals,
                  ),
                ),
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
fn sg_rewrite_elem_mode(
  mode : @lib.ElemMode,
  set : SgStringSet,
  imported_globals : Int,
) -> @lib.ElemMode {
  match mode {
    @lib.Active(table_idx, expr) =>
      @lib.ElemMode::active(
        table_idx,
        sg_rewrite_expr(expr, set, imported_globals),
      )
    _ => mode
  }
}

///|
fn sg_rewrite_elem_kind(
  kind : @lib.ElemKind,
  set : SgStringSet,
  imported_globals : Int,
) -> @lib.ElemKind {
  match kind {
    @lib.FuncExprsElemKind(exprs) => {
      let out : Array[@lib.Expr] = []
      for expr in exprs {
        out.push(sg_rewrite_expr(expr, set, imported_globals))
      }
      @lib.ElemKind::func_exprs(out)
    }
    @lib.TypedExprsElemKind(ref_type, exprs) => {
      let out : Array[@lib.Expr] = []
      for expr in exprs {
        out.push(sg_rewrite_expr(expr, set, imported_globals))
      }
      @lib.ElemKind::typed_exprs(ref_type, out)
    }
    _ => kind
  }
}

///|
fn sg_rewrite_elem_sec(
  elem_sec : @lib.ElemSec?,
  set : SgStringSet,
  imported_globals : Int,
) -> @lib.ElemSec? {
  match elem_sec {
    Some(@lib.ElemSec(elems)) => {
      let out : Array[@lib.Elem] = []
      for elem in elems {
        let @lib.Elem(mode, kind) = elem
        out.push(
          @lib.Elem::new(
            sg_rewrite_elem_mode(mode, set, imported_globals),
            sg_rewrite_elem_kind(kind, set, imported_globals),
          ),
        )
      }
      Some(@lib.ElemSec::new(out))
    }
    None => None
  }
}

///|
fn sg_rewrite_data_sec(
  data_sec : @lib.DataSec?,
  set : SgStringSet,
  imported_globals : Int,
) -> @lib.DataSec? {
  match data_sec {
    Some(@lib.DataSec(datas)) => {
      let out : Array[@lib.Data] = []
      for data in datas {
        let @lib.Data(mode, bytes) = data
        let next_mode = match mode {
          @lib.Active(mem_idx, expr) =>
            @lib.DataMode::active(
              mem_idx,
              sg_rewrite_expr(expr, set, imported_globals),
            )
          _ => mode
        }
        out.push(@lib.Data::new(next_mode, bytes))
      }
      Some(@lib.DataSec::new(out))
    }
    None => None
  }
}

///|
fn sg_rewrite_global_name_map(
  names : @lib.NameMap?,
  imported_globals : Int,
  inserted_globals : Int,
) -> @lib.NameMap? {
  match names {
    Some(@lib.NameMap(entries)) => {
      let out : Array[@lib.NameAssoc] = []
      for entry in entries {
        let @lib.NameAssoc(idx, name) = entry
        let raw = idx.reinterpret_as_int()
        if raw >= imported_globals {
          out.push(
            @lib.NameAssoc::new(
              (raw + inserted_globals).reinterpret_as_uint(),
              name,
            ),
          )
        } else {
          out.push(entry)
        }
      }
      Some(@lib.NameMap::new(out))
    }
    None => None
  }
}

///|
fn sg_rewrite_name_sec(
  name_sec : @lib.NameSec?,
  imported_globals : Int,
  inserted_globals : Int,
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
          global_names=sg_rewrite_global_name_map(
            sec.global_names,
            imported_globals,
            inserted_globals,
          ),
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
fn sg_rewrite_code_sec(
  code_sec : @lib.CodeSec?,
  set : SgStringSet,
  imported_globals : Int,
) -> @lib.CodeSec? {
  match code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let out : Array[@lib.Func] = []
      for func in funcs {
        let @lib.Func(locals, body) = func
        out.push(
          @lib.Func::new(locals, sg_rewrite_expr(body, set, imported_globals)),
        )
      }
      Some(@lib.CodeSec::new(out))
    }
    None => None
  }
}

///|
pub fn string_gathering_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  let set = sg_collect_strings(mod_)
  if set.strings.is_empty() {
    return mod_
  }
  let imported_globals = sg_imported_global_count(mod_)
  let inserted_globals = set.strings.length()
  @lib.Module::new(
    custom_secs=mod_.custom_secs,
    type_sec=mod_.type_sec,
    import_sec=mod_.import_sec,
    func_annotation_sec=mod_.func_annotation_sec,
    func_sec=mod_.func_sec,
    table_sec=sg_rewrite_table_sec(mod_.table_sec, set, imported_globals),
    mem_sec=mod_.mem_sec,
    tag_sec=mod_.tag_sec,
    stringrefs_sec=mod_.stringrefs_sec,
    global_sec=Some(
      sg_rewrite_global_sec(mod_.global_sec, set, imported_globals),
    ),
    export_sec=sg_rewrite_export_sec(
      mod_.export_sec,
      imported_globals,
      inserted_globals,
    ),
    start_sec=mod_.start_sec,
    elem_sec=sg_rewrite_elem_sec(mod_.elem_sec, set, imported_globals),
    data_cnt_sec=mod_.data_cnt_sec,
    code_sec=sg_rewrite_code_sec(mod_.code_sec, set, imported_globals),
    data_sec=sg_rewrite_data_sec(mod_.data_sec, set, imported_globals),
    name_sec=sg_rewrite_name_sec(
      mod_.name_sec,
      imported_globals,
      inserted_globals,
    ),
    raw_name_sec_payload=None,
  )
}
