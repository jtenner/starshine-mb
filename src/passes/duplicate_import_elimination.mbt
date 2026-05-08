///|
pub fn die_summary() -> String {
  "Collapse duplicate imported function aliases and rewrite surviving function references."
}

///|
priv struct DieSeenImport {
  func_idx : Int
  func_type : @lib.FuncType
}

///|
fn die_name_to_string(name : @lib.Name) -> String {
  let @lib.Name(text) = name
  text.to_owned()
}

///|
fn die_import_key(module_name : @lib.Name, base_name : @lib.Name) -> String {
  "\{die_name_to_string(module_name)}\u{0}\{die_name_to_string(base_name)}"
}

///|
fn die_imported_func_count(mod_ : @lib.Module) -> Int {
  let mut count = 0
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
fn die_defined_func_count(mod_ : @lib.Module) -> Int {
  match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) => type_idxs.length()
    None => 0
  }
}

///|
fn die_identity_remap(length : Int) -> Array[Int] {
  let remap : Array[Int] = []
  for idx = 0; idx < length; idx = idx + 1 {
    remap.push(idx)
  }
  remap
}

///|
fn die_rewrite_abs(raw : UInt, remap : Array[Int]) -> UInt {
  remap[raw.reinterpret_as_int()].reinterpret_as_uint()
}

///|
fn die_rewrite_func_idx(idx : @lib.FuncIdx, remap : Array[Int]) -> @lib.FuncIdx {
  let @lib.FuncIdx(raw) = idx
  @lib.FuncIdx::new(die_rewrite_abs(raw, remap))
}

///|
fn die_rewrite_instruction(
  instr : @lib.Instruction,
  remap : Array[Int],
) -> @lib.Instruction {
  match instr {
    @lib.Block(block_type, body) =>
      @lib.Instruction::block(block_type, die_rewrite_expr(body, remap))
    @lib.Loop(block_type, body) =>
      @lib.Instruction::loop_(block_type, die_rewrite_expr(body, remap))
    @lib.If(block_type, then_body, else_body) => {
      let rewritten_then : Array[@lib.Instruction] = []
      for nested in then_body {
        rewritten_then.push(die_rewrite_instruction(nested, remap))
      }
      let rewritten_else = match else_body {
        Some(body) => {
          let rewritten : Array[@lib.Instruction] = []
          for nested in body {
            rewritten.push(die_rewrite_instruction(nested, remap))
          }
          Some(rewritten)
        }
        None => None
      }
      @lib.Instruction::if_(block_type, rewritten_then, rewritten_else)
    }
    @lib.TryTable(block_type, catches, body) =>
      @lib.Instruction::try_table(
        block_type,
        catches,
        die_rewrite_expr(body, remap),
      )
    @lib.Call(func_idx) =>
      @lib.Instruction::call(die_rewrite_func_idx(func_idx, remap))
    @lib.ReturnCall(func_idx) =>
      @lib.Instruction::return_call(die_rewrite_func_idx(func_idx, remap))
    @lib.RefFunc(func_idx) =>
      @lib.Instruction::ref_func(die_rewrite_func_idx(func_idx, remap))
    _ => instr
  }
}

///|
fn die_rewrite_expr(expr : @lib.Expr, remap : Array[Int]) -> @lib.Expr {
  let @lib.Expr(instrs) = expr
  let rewritten : Array[@lib.Instruction] = []
  for instr in instrs {
    rewritten.push(die_rewrite_instruction(instr, remap))
  }
  @lib.Expr::new(rewritten)
}

///|
fn die_rewrite_elem_kind(
  kind : @lib.ElemKind,
  remap : Array[Int],
) -> @lib.ElemKind {
  match kind {
    @lib.FuncsElemKind(funcs) => {
      let rewritten : Array[@lib.FuncIdx] = []
      for func_idx in funcs {
        rewritten.push(die_rewrite_func_idx(func_idx, remap))
      }
      @lib.ElemKind::funcs(rewritten)
    }
    @lib.FuncExprsElemKind(exprs) => {
      let rewritten : Array[@lib.Expr] = []
      for expr in exprs {
        rewritten.push(die_rewrite_expr(expr, remap))
      }
      @lib.ElemKind::func_exprs(rewritten)
    }
    @lib.TypedExprsElemKind(ref_type, exprs) => {
      let rewritten : Array[@lib.Expr] = []
      for expr in exprs {
        rewritten.push(die_rewrite_expr(expr, remap))
      }
      @lib.ElemKind::typed_exprs(ref_type, rewritten)
    }
  }
}

///|
fn die_sort_name_assocs(entries : Array[@lib.NameAssoc]) -> Unit {
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
fn die_sort_indirect_name_assocs(
  entries : Array[@lib.IndirectNameAssoc],
) -> Unit {
  let mut i = 1
  while i < entries.length() {
    let current = entries[i]
    let @lib.IndirectNameAssoc(current_idx, _) = current
    let mut j = i
    while j > 0 {
      let @lib.IndirectNameAssoc(prev_idx, _) = entries[j - 1]
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
fn die_rewrite_func_name_map(
  names : @lib.NameMap?,
  remap : Array[Int],
  removed_funcs : Array[Bool],
) -> @lib.NameMap? {
  match names {
    Some(@lib.NameMap(entries)) => {
      let rewritten : Array[@lib.NameAssoc] = []
      for entry in entries {
        let @lib.NameAssoc(idx, name) = entry
        let slot = idx.reinterpret_as_int()
        if slot >= 0 && slot < remap.length() && !removed_funcs[slot] {
          rewritten.push(
            @lib.NameAssoc::new(remap[slot].reinterpret_as_uint(), name),
          )
        }
      }
      if rewritten.is_empty() {
        None
      } else {
        die_sort_name_assocs(rewritten)
        Some(@lib.NameMap::new(rewritten))
      }
    }
    None => None
  }
}

///|
fn die_rewrite_func_indirect_name_map(
  names : @lib.IndirectNameMap?,
  remap : Array[Int],
  removed_funcs : Array[Bool],
) -> @lib.IndirectNameMap? {
  match names {
    Some(@lib.IndirectNameMap(entries)) => {
      let rewritten : Array[@lib.IndirectNameAssoc] = []
      for entry in entries {
        let @lib.IndirectNameAssoc(idx, inner) = entry
        let slot = idx.reinterpret_as_int()
        if slot >= 0 && slot < remap.length() && !removed_funcs[slot] {
          rewritten.push(
            @lib.IndirectNameAssoc::new(
              remap[slot].reinterpret_as_uint(),
              inner,
            ),
          )
        }
      }
      if rewritten.is_empty() {
        None
      } else {
        die_sort_indirect_name_assocs(rewritten)
        Some(@lib.IndirectNameMap::new(rewritten))
      }
    }
    None => None
  }
}

///|
fn die_rewrite_name_sec(
  name_sec : @lib.NameSec?,
  remap : Array[Int],
  removed_funcs : Array[Bool],
) -> @lib.NameSec? {
  match name_sec {
    Some(sec) => {
      let next = @lib.NameSec::new(
        module_name=sec.module_name,
        func_names=die_rewrite_func_name_map(
          sec.func_names,
          remap,
          removed_funcs,
        ),
        local_names=die_rewrite_func_indirect_name_map(
          sec.local_names,
          remap,
          removed_funcs,
        ),
        label_names=die_rewrite_func_indirect_name_map(
          sec.label_names,
          remap,
          removed_funcs,
        ),
        type_names=sec.type_names,
        table_names=sec.table_names,
        memory_names=sec.memory_names,
        global_names=sec.global_names,
        elem_names=sec.elem_names,
        data_names=sec.data_names,
        field_names=sec.field_names,
        tag_names=sec.tag_names,
      )
      if next.module_name is None &&
        next.func_names is None &&
        next.local_names is None &&
        next.label_names is None &&
        next.type_names is None &&
        next.table_names is None &&
        next.memory_names is None &&
        next.global_names is None &&
        next.elem_names is None &&
        next.data_names is None &&
        next.field_names is None &&
        next.tag_names is None {
        None
      } else {
        Some(next)
      }
    }
    None => None
  }
}

///|
fn die_rewrite_func_annotation_sec(
  sec : @lib.FuncAnnotationSec?,
  remap : Array[Int],
  removed_funcs : Array[Bool],
) -> @lib.FuncAnnotationSec? {
  match sec {
    Some(@lib.FuncAnnotationSec(entries)) => {
      let rewritten : Array[@lib.FuncAnnotationAssoc] = []
      for entry in entries {
        let @lib.FuncAnnotationAssoc(idx, annotations) = entry
        let slot = idx.reinterpret_as_int()
        if slot >= 0 && slot < remap.length() && !removed_funcs[slot] {
          rewritten.push(
            @lib.FuncAnnotationAssoc::new(
              remap[slot].reinterpret_as_uint(),
              annotations,
            ),
          )
        }
      }
      if rewritten.is_empty() {
        None
      } else {
        Some(@lib.FuncAnnotationSec::new(rewritten))
      }
    }
    None => None
  }
}

///|
fn die_plan_remap(
  mod_ : @lib.Module,
) -> (Array[Int], Array[Bool], Array[Bool], Bool) {
  let import_func_count = die_imported_func_count(mod_)
  let defined_func_count = die_defined_func_count(mod_)
  let total_func_count = import_func_count + defined_func_count
  let remap = die_identity_remap(total_func_count)
  let removed_funcs : Array[Bool] = []
  let mut init_idx = 0
  while init_idx < total_func_count {
    removed_funcs.push(false)
    init_idx += 1
  }
  let duplicate_import_funcs : Array[Bool] = []
  let canonical_import_func : Array[Int] = []
  let mut import_init_idx = 0
  while import_init_idx < import_func_count {
    duplicate_import_funcs.push(false)
    canonical_import_func.push(-1)
    import_init_idx += 1
  }
  let seen : @hashmap.HashMap[String, DieSeenImport] = @hashmap.new(
    capacity=import_func_count * 2 + 1,
  )
  let ctx = @ir.hot_module_context_from_module(mod_)
  let mut func_idx = 0
  let mut changed = false
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(module_name, base_name, @lib.FuncExternType(type_idx)) => {
            let key = die_import_key(module_name, base_name)
            match @ir.hot_module_resolve_type_func_type(ctx, type_idx) {
              Some(func_type) =>
                match seen.get(key) {
                  Some(prev) =>
                    if prev.func_type == func_type {
                      duplicate_import_funcs[func_idx] = true
                      canonical_import_func[func_idx] = prev.func_idx
                      removed_funcs[func_idx] = true
                      changed = true
                    }
                  None => seen.set(key, { func_idx, func_type })
                }
              None => ()
            }
            func_idx += 1
          }
          _ => ()
        }
      }
    None => ()
  }
  if !changed {
    return (remap, removed_funcs, duplicate_import_funcs, false)
  }

  let mut next_func = 0
  for old_func = 0; old_func < import_func_count; old_func = old_func + 1 {
    if duplicate_import_funcs[old_func] {
      remap[old_func] = remap[canonical_import_func[old_func]]
    } else {
      remap[old_func] = next_func
      next_func += 1
    }
  }
  for def_idx = 0; def_idx < defined_func_count; def_idx = def_idx + 1 {
    remap[import_func_count + def_idx] = next_func + def_idx
  }
  (remap, removed_funcs, duplicate_import_funcs, true)
}

///|
pub fn die_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  let (func_remap, removed_funcs, duplicate_import_funcs, changed) = die_plan_remap(
    mod_,
  )
  if !changed {
    return mod_
  }

  let next_import_sec = match mod_.import_sec {
    Some(@lib.ImportSec(imports)) => {
      let next : Array[@lib.Import] = []
      let mut func_idx = 0
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(_)) => {
            if !duplicate_import_funcs[func_idx] {
              next.push(import_)
            }
            func_idx += 1
          }
          _ => next.push(import_)
        }
      }
      if next.is_empty() {
        None
      } else {
        Some(@lib.ImportSec::new(next))
      }
    }
    None => None
  }

  let next_export_sec = match mod_.export_sec {
    Some(@lib.ExportSec(exports)) => {
      let next : Array[@lib.Export] = []
      for export_ in exports {
        let @lib.Export(name, idx) = export_
        next.push(
          @lib.Export::new(
            name,
            match idx {
              @lib.FuncExternIdx(func_idx) =>
                @lib.ExternIdx::func(die_rewrite_func_idx(func_idx, func_remap))
              _ => idx
            },
          ),
        )
      }
      Some(@lib.ExportSec::new(next))
    }
    None => None
  }

  let next_start_sec = match mod_.start_sec {
    Some(@lib.StartSec(func_idx)) =>
      Some(@lib.StartSec::new(die_rewrite_func_idx(func_idx, func_remap)))
    None => None
  }

  let next_code_sec = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let next : Array[@lib.Func] = []
      for func_ in funcs {
        let @lib.Func(locals, body) = func_
        next.push(@lib.Func::new(locals, die_rewrite_expr(body, func_remap)))
      }
      Some(@lib.CodeSec::new(next))
    }
    None => None
  }

  let next_global_sec = match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) => {
      let next : Array[@lib.Global] = []
      for global in globals {
        let @lib.Global(global_type, init) = global
        next.push(
          @lib.Global::new(global_type, die_rewrite_expr(init, func_remap)),
        )
      }
      Some(@lib.GlobalSec::new(next))
    }
    None => None
  }

  let next_table_sec = match mod_.table_sec {
    Some(@lib.TableSec(tables)) => {
      let next : Array[@lib.Table] = []
      for table in tables {
        let @lib.Table(table_type, init) = table
        next.push(
          @lib.Table::new(
            table_type,
            match init {
              Some(expr) => Some(die_rewrite_expr(expr, func_remap))
              None => None
            },
          ),
        )
      }
      Some(@lib.TableSec::new(next))
    }
    None => None
  }

  let next_elem_sec = match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) => {
      let next : Array[@lib.Elem] = []
      for elem in elems {
        let @lib.Elem(mode, kind) = elem
        let rewritten_mode = match mode {
          @lib.Active(table_idx, offset) =>
            @lib.ElemMode::active(
              table_idx,
              die_rewrite_expr(offset, func_remap),
            )
          _ => mode
        }
        next.push(
          @lib.Elem::new(
            rewritten_mode,
            die_rewrite_elem_kind(kind, func_remap),
          ),
        )
      }
      Some(@lib.ElemSec::new(next))
    }
    None => None
  }

  let next_data_sec = match mod_.data_sec {
    Some(@lib.DataSec(datas)) => {
      let next : Array[@lib.Data] = []
      for data in datas {
        let @lib.Data(mode, bytes) = data
        let rewritten_mode = match mode {
          @lib.Active(mem_idx, offset) =>
            @lib.DataMode::active(mem_idx, die_rewrite_expr(offset, func_remap))
          @lib.Passive => mode
        }
        next.push(@lib.Data::new(rewritten_mode, bytes))
      }
      Some(@lib.DataSec::new(next))
    }
    None => None
  }

  @lib.Module::new(
    custom_secs=mod_.custom_secs,
    type_sec=mod_.type_sec,
    import_sec=next_import_sec,
    func_annotation_sec=die_rewrite_func_annotation_sec(
      mod_.func_annotation_sec,
      func_remap,
      removed_funcs,
    ),
    func_sec=mod_.func_sec,
    table_sec=next_table_sec,
    mem_sec=mod_.mem_sec,
    tag_sec=mod_.tag_sec,
    stringrefs_sec=mod_.stringrefs_sec,
    global_sec=next_global_sec,
    export_sec=next_export_sec,
    start_sec=next_start_sec,
    elem_sec=next_elem_sec,
    data_cnt_sec=mod_.data_cnt_sec,
    code_sec=next_code_sec,
    data_sec=next_data_sec,
    name_sec=die_rewrite_name_sec(mod_.name_sec, func_remap, removed_funcs),
    raw_name_sec_payload=mod_.raw_name_sec_payload,
  )
}
