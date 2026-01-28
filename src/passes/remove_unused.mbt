// Counts of each import type for index calculations

///|
struct ImportCounts {
  funcs : UInt
  tables : UInt
  mems : UInt
  globals : UInt
  tags : UInt
}

// All used indices discovered during analysis

///|
struct UsedIndices {
  funcs : Set[FuncIdx]
  types : Set[TypeIdx]
  tables : Set[TableIdx]
  mems : Set[MemIdx]
  globals : Set[GlobalIdx]
  elems : Set[ElemIdx]
  datas : Set[DataIdx]
  tags : Set[TagIdx]
}

///|
fn UsedIndices::new() -> UsedIndices {
  {
    funcs: Set::new(),
    types: Set::new(),
    tables: Set::new(),
    mems: Set::new(),
    globals: Set::new(),
    elems: Set::new(),
    datas: Set::new(),
    tags: Set::new(),
  }
}

// Remappings from old indices to new indices

///|
struct Remappings {
  mut funcs : Map[FuncIdx, FuncIdx]
  mut types : Map[TypeIdx, TypeIdx]
  mut tables : Map[TableIdx, TableIdx]
  mut mems : Map[MemIdx, MemIdx]
  mut globals : Map[GlobalIdx, GlobalIdx]
  mut elems : Map[ElemIdx, ElemIdx]
  mut datas : Map[DataIdx, DataIdx]
  mut tags : Map[TagIdx, TagIdx]
}

///|
fn Remappings::new() -> Remappings {
  {
    funcs: Map::new(),
    types: Map::new(),
    tables: Map::new(),
    mems: Map::new(),
    globals: Map::new(),
    elems: Map::new(),
    datas: Map::new(),
    tags: Map::new(),
  }
}

// State passed through the transformer

///|
pub struct DCEState {
  used : UsedIndices
  remap : Remappings
  imports : ImportCounts
}

// ============================================================================
// Analysis Phase
// ============================================================================

///|
fn count_imports(mod : Module) -> ImportCounts {
  let mut funcs : UInt = 0
  let mut tables : UInt = 0
  let mut mems : UInt = 0
  let mut globals : UInt = 0
  let mut tags : UInt = 0
  match mod.import_sec {
    Some(sec) =>
      for imp in sec.0 {
        match imp {
          Import(_, _, extern_type) =>
            match extern_type {
              FuncExternType(_) => funcs += 1
              TableExternType(_) => tables += 1
              MemExternType(_) => mems += 1
              GlobalExternType(_) => globals += 1
              TagExternType(_) => tags += 1
            }
        }
      }
    None => ()
  }
  { funcs, tables, mems, globals, tags }
}

///|
priv struct AnalysisContext {
  used : UsedIndices
  imports : ImportCounts
  // Worklists
  func_worklist : Array[FuncIdx]
  global_worklist : Array[GlobalIdx]
  elem_worklist : Array[ElemIdx]
  // Module sections for lookup
  mod : Module
}

///|
fn AnalysisContext::new(mod : Module) -> AnalysisContext {
  {
    used: UsedIndices::new(),
    imports: count_imports(mod),
    func_worklist: [],
    global_worklist: [],
    elem_worklist: [],
    mod,
  }
}

// Mark functions

///|
fn mark_func(ctx : AnalysisContext, idx : FuncIdx) -> Unit {
  if not(ctx.used.funcs.contains(idx)) {
    ctx.used.funcs.add(idx)
    ctx.func_worklist.push(idx)
  }
}

///|
fn mark_type(ctx : AnalysisContext, idx : TypeIdx) -> Unit {
  ctx.used.types.add(idx)
  // Types can reference other types via supertypes in GC
  // We'd need to scan the type section for this
}

///|
fn mark_table(ctx : AnalysisContext, idx : TableIdx) -> Unit {
  ctx.used.tables.add(idx)
}

///|
fn mark_mem(ctx : AnalysisContext, idx : MemIdx) -> Unit {
  ctx.used.mems.add(idx)
}

///|
fn mark_global(ctx : AnalysisContext, idx : GlobalIdx) -> Unit {
  if not(ctx.used.globals.contains(idx)) {
    ctx.used.globals.add(idx)
    ctx.global_worklist.push(idx)
  }
}

///|
fn mark_elem(ctx : AnalysisContext, idx : ElemIdx) -> Unit {
  if not(ctx.used.elems.contains(idx)) {
    ctx.used.elems.add(idx)
    ctx.elem_worklist.push(idx)
  }
}

///|
fn mark_data(ctx : AnalysisContext, idx : DataIdx) -> Unit {
  ctx.used.datas.add(idx)
}

///|
fn mark_tag(ctx : AnalysisContext, idx : TagIdx) -> Unit {
  ctx.used.tags.add(idx)
}

// Mark from block type

///|
fn mark_blocktype(ctx : AnalysisContext, bt : BlockType) -> Unit {
  match bt {
    TypeIdxBlockType(idx) => mark_type(ctx, idx)
    _ => ()
  }
}

// Mark from heap type

///|
fn mark_heaptype(ctx : AnalysisContext, ht : HeapType) -> Unit {
  match ht {
    HeapType(idx) => mark_type(ctx, idx)
    _ => ()
  }
}

// Mark from ref type

///|
fn mark_reftype(ctx : AnalysisContext, rt : RefType) -> Unit {
  match rt {
    HeapTypeRefType(_, ht) => mark_heaptype(ctx, ht)
    _ => ()
  }
}

// Mark from val type

///|
fn mark_valtype(ctx : AnalysisContext, vt : ValType) -> Unit {
  match vt {
    RefTypeValType(rt) => mark_reftype(ctx, rt)
    _ => ()
  }
}

// Analyze roots: exports, start, active segments

///|
fn analyze_roots(ctx : AnalysisContext) -> Unit {
  let mod = ctx.mod

  // Exports
  match mod.export_sec {
    Some(sec) =>
      for exp in sec.0 {
        match exp {
          Export(_, extern_idx) =>
            match extern_idx {
              FuncExternIdx(idx) => mark_func(ctx, idx)
              TableExternIdx(idx) => mark_table(ctx, idx)
              MemExternIdx(idx) => mark_mem(ctx, idx)
              GlobalExternIdx(idx) => mark_global(ctx, idx)
              TagExternIdx(idx) => mark_tag(ctx, idx)
            }
        }
      }
    None => ()
  }

  // Start function
  match mod.start_sec {
    Some(sec) => mark_func(ctx, sec.0)
    None => ()
  }

  // Active element segments (executed at instantiation)
  match mod.elem_sec {
    Some(sec) => {
      let elems = sec.0
      for i = 0; i < elems.length(); i = i + 1 {
        match elems[i] {
          Elem(Active(table_idx, _), _) => {
            mark_table(ctx, table_idx)
            mark_elem(ctx, ElemIdx::new(i.reinterpret_as_uint()))
          }
          _ => ()
        }
      }
    }
    None => ()
  }

  // Active data segments (executed at instantiation)
  match mod.data_sec {
    Some(sec) => {
      let datas = sec.0
      for i = 0; i < datas.length(); i = i + 1 {
        match datas[i] {
          Data(Active(mem_idx, _), _) => {
            mark_mem(ctx, mem_idx)
            mark_data(ctx, DataIdx::new(i.reinterpret_as_uint()))
          }
          _ => ()
        }
      }
    }
    None => ()
  }
}

// Process function worklist

///|
fn process_func_worklist(ctx : AnalysisContext) -> Unit {
  let code_sec = match ctx.mod.code_sec {
    Some(cs) => cs.0
    None => return
  }
  let func_sec = match ctx.mod.func_sec {
    Some(fs) => fs.0
    None => return
  }
  while ctx.func_worklist.length() > 0 {
    let func_idx = ctx.func_worklist.pop().unwrap()
    let FuncIdx(idx_val) = func_idx
    if idx_val >= ctx.imports.funcs {
      // Defined function
      let def_idx = (idx_val - ctx.imports.funcs).reinterpret_as_int()
      if def_idx >= 0 && def_idx < code_sec.length() {
        // Mark the function's type
        mark_type(ctx, func_sec[def_idx])

        // Scan the function body
        match code_sec[def_idx] {
          TFunc(locals, texpr) => {
            for vt in locals {
              mark_valtype(ctx, vt)
            }
            scan_texpr(ctx, texpr)
          }
          Func(locals, expr) => {
            for l in locals {
              match l {
                Locals(_, vt) => mark_valtype(ctx, vt)
              }
            }
            scan_expr(ctx, expr)
          }
        }
      }
    } else {
      // Imported function - mark its type from import section
      match ctx.mod.import_sec {
        Some(sec) => {
          let mut func_import_idx : UInt = 0
          for imp in sec.0 {
            match imp {
              Import(_, _, FuncExternType(type_idx)) => {
                if func_import_idx == idx_val {
                  mark_type(ctx, type_idx)
                  break
                }
                func_import_idx += 1
              }
              _ => ()
            }
          }
        }
        None => ()
      }
    }
  }
}

// Process global worklist

///|
fn process_global_worklist(ctx : AnalysisContext) -> Unit {
  let global_sec = match ctx.mod.global_sec {
    Some(gs) => gs.0
    None => return
  }
  while ctx.global_worklist.length() > 0 {
    let global_idx = ctx.global_worklist.pop().unwrap()
    let GlobalIdx(idx_val) = global_idx
    if idx_val >= ctx.imports.globals {
      let def_idx = (idx_val - ctx.imports.globals).reinterpret_as_int()
      if def_idx >= 0 && def_idx < global_sec.length() {
        match global_sec[def_idx] {
          Global(GlobalType(vt, _), init_expr) => {
            mark_valtype(ctx, vt)
            scan_expr(ctx, init_expr)
          }
        }
      }
    }
  }
}

// Process element worklist

///|
fn process_elem_worklist(ctx : AnalysisContext) -> Unit {
  let elem_sec = match ctx.mod.elem_sec {
    Some(es) => es.0
    None => return
  }
  while ctx.elem_worklist.length() > 0 {
    let elem_idx = ctx.elem_worklist.pop().unwrap()
    let ElemIdx(idx_val) = elem_idx
    let idx = idx_val.reinterpret_as_int()
    if idx >= 0 && idx < elem_sec.length() {
      match elem_sec[idx] {
        Elem(mode, kind) => {
          // Scan offset expression for active segments
          match mode {
            Active(_, offset_expr) => scan_expr(ctx, offset_expr)
            _ => ()
          }

          // Mark referenced functions
          match kind {
            FuncsElemKind(funcs) =>
              for f in funcs {
                mark_func(ctx, f)
              }
            FuncExprsElemKind(exprs) =>
              for expr in exprs {
                scan_expr(ctx, expr)
              }
            TypedExprsElemKind(rt, exprs) => {
              mark_reftype(ctx, rt)
              for expr in exprs {
                scan_expr(ctx, expr)
              }
            }
          }
        }
      }
    }
  }
}

// Main analysis loop

///|
fn analyze(ctx : AnalysisContext) -> Unit {
  analyze_roots(ctx)

  // Process all worklists until empty
  // Need to iterate because processing one can add to others
  while ctx.func_worklist.length() > 0 ||
        ctx.global_worklist.length() > 0 ||
        ctx.elem_worklist.length() > 0 {
    process_func_worklist(ctx)
    process_global_worklist(ctx)
    process_elem_worklist(ctx)
  }

  // Mark types used by tables
  match ctx.mod.table_sec {
    Some(sec) =>
      for i = 0; i < sec.0.length(); i = i + 1 {
        let table_idx = TableIdx::new(
          ctx.imports.tables + i.reinterpret_as_uint(),
        )
        if ctx.used.tables.contains(table_idx) {
          match sec.0[i] {
            Table(TableType(rt, _), _) => mark_reftype(ctx, rt)
          }
        }
      }
    None => ()
  }

  // Mark types used by tags
  match ctx.mod.tag_sec {
    Some(sec) =>
      for i = 0; i < sec.0.length(); i = i + 1 {
        let tag_idx = TagIdx::new(ctx.imports.tags + i.reinterpret_as_uint())
        if ctx.used.tags.contains(tag_idx) {
          match sec.0[i] {
            TagType(type_idx) => mark_type(ctx, type_idx)
          }
        }
      }
    None => ()
  }

  // Mark types from type section (handle rec types and supertypes)
  analyze_type_dependencies(ctx)
}

///|
fn analyze_type_dependencies(ctx : AnalysisContext) -> Unit {
  match ctx.mod.type_sec {
    Some(sec) => {
      // Iterate until no new types are added
      let mut changed = true
      while changed {
        changed = false
        let types = sec.0
        for i = 0; i < types.length(); i = i + 1 {
          let type_idx = TypeIdx::new(i.reinterpret_as_uint())
          if ctx.used.types.contains(type_idx) {
            match types[i] {
              SingleRecType(st) =>
                match st {
                  SubType(_, supers, comp_type) => {
                    for super_idx in supers {
                      if not(ctx.used.types.contains(super_idx)) {
                        ctx.used.types.add(super_idx)
                        changed = true
                      }
                    }
                    // Mark types in comp_type
                    scan_comptype_for_types(ctx, comp_type)
                  }
                  CompTypeSubType(ct) => scan_comptype_for_types(ctx, ct)
                }
              GroupRecType(sts) =>
                for st in sts {
                  match st {
                    SubType(_, supers, comp_type) => {
                      for super_idx in supers {
                        if not(ctx.used.types.contains(super_idx)) {
                          ctx.used.types.add(super_idx)
                          changed = true
                        }
                      }
                      scan_comptype_for_types(ctx, comp_type)
                    }
                    CompTypeSubType(ct) => scan_comptype_for_types(ctx, ct)
                  }
                }
            }
          }
        }
      }
    }
    None => ()
  }
}

///|
fn scan_comptype_for_types(ctx : AnalysisContext, ct : CompType) -> Unit {
  match ct {
    FuncCompType(params, results) => {
      for vt in params {
        mark_valtype(ctx, vt)
      }
      for vt in results {
        mark_valtype(ctx, vt)
      }
    }
    StructCompType(fields) =>
      for field in fields {
        match field {
          FieldType(ValTypeStorageType(vt), _) => mark_valtype(ctx, vt)
          _ => ()
        }
      }
    ArrayCompType(ft) => {
      let FieldType(storage, _) = ft
      match storage {
        ValTypeStorageType(vt) => mark_valtype(ctx, vt)
        _ => ()
      }
    }
  }
}

// ============================================================================
// Instruction Scanning
// ============================================================================

///|
fn scan_texpr(ctx : AnalysisContext, texpr : TExpr) -> Unit {
  for instr in texpr.0 {
    scan_tinstr(ctx, instr)
  }
}

///|
fn scan_tinstr(ctx : AnalysisContext, instr : TInstr) -> Unit {
  match instr {
    // Function references
    TCall(idx, args) | TReturnCall(idx, args) => {
      mark_func(ctx, idx)
      for a in args {
        scan_tinstr(ctx, a)
      }
    }
    TRefFunc(idx) => mark_func(ctx, idx)

    // Type references
    TCallIndirect(type_idx, table_idx, args, idx_instr) => {
      mark_type(ctx, type_idx)
      mark_table(ctx, table_idx)
      for a in args {
        scan_tinstr(ctx, a)
      }
      scan_tinstr(ctx, idx_instr)
    }
    TReturnCallIndirect(type_idx, table_idx, args, idx_instr) => {
      mark_type(ctx, type_idx)
      mark_table(ctx, table_idx)
      for a in args {
        scan_tinstr(ctx, a)
      }
      scan_tinstr(ctx, idx_instr)
    }
    TCallRef(type_idx, args, rf) => {
      mark_type(ctx, type_idx)
      for a in args {
        scan_tinstr(ctx, a)
      }
      scan_tinstr(ctx, rf)
    }
    TReturnCallRef(type_idx, args, rf) => {
      mark_type(ctx, type_idx)
      for a in args {
        scan_tinstr(ctx, a)
      }
      scan_tinstr(ctx, rf)
    }

    // Control flow
    TBlock(bt, expr) => {
      mark_blocktype(ctx, bt)
      scan_texpr(ctx, expr)
    }
    TLoop(bt, expr) => {
      mark_blocktype(ctx, bt)
      scan_texpr(ctx, expr)
    }
    TIf(bt, cond, then_branch, else_branch) => {
      mark_blocktype(ctx, bt)
      scan_tinstr(ctx, cond)
      scan_texpr(ctx, then_branch)
      match else_branch {
        Some(e) => scan_texpr(ctx, e)
        None => ()
      }
    }
    TTryTable(bt, catches, expr) => {
      mark_blocktype(ctx, bt)
      for c in catches {
        match c {
          Catch(tag_idx, _) | CatchRef(tag_idx, _) => mark_tag(ctx, tag_idx)
          CatchAll(_) | CatchAllRef(_) => ()
        }
      }
      scan_texpr(ctx, expr)
    }

    // Tags
    TThrow(tag_idx, args) => {
      mark_tag(ctx, tag_idx)
      for a in args {
        scan_tinstr(ctx, a)
      }
    }
    TThrowRef(arg) => scan_tinstr(ctx, arg)

    // Globals
    TGlobalGet(idx) => mark_global(ctx, idx)
    TGlobalSet(idx, arg) => {
      mark_global(ctx, idx)
      scan_tinstr(ctx, arg)
    }

    // Tables
    TTableGet(idx, arg) => {
      mark_table(ctx, idx)
      scan_tinstr(ctx, arg)
    }
    TTableSet(idx, a, b) => {
      mark_table(ctx, idx)
      scan_tinstr(ctx, a)
      scan_tinstr(ctx, b)
    }
    TTableGrow(idx, a, b) => {
      mark_table(ctx, idx)
      scan_tinstr(ctx, a)
      scan_tinstr(ctx, b)
    }
    TTableSize(idx) => mark_table(ctx, idx)
    TTableFill(idx, a, b, c) => {
      mark_table(ctx, idx)
      scan_tinstr(ctx, a)
      scan_tinstr(ctx, b)
      scan_tinstr(ctx, c)
    }
    TTableCopy(idx1, idx2, a, b, c) => {
      mark_table(ctx, idx1)
      mark_table(ctx, idx2)
      scan_tinstr(ctx, a)
      scan_tinstr(ctx, b)
      scan_tinstr(ctx, c)
    }
    TTableInit(elem_idx, table_idx, a, b, c) => {
      mark_elem(ctx, elem_idx)
      mark_table(ctx, table_idx)
      scan_tinstr(ctx, a)
      scan_tinstr(ctx, b)
      scan_tinstr(ctx, c)
    }
    TElemDrop(idx) => mark_elem(ctx, idx)

    // Memory
    TMemorySize(idx) => mark_mem(ctx, idx)
    TMemoryGrow(idx, arg) => {
      mark_mem(ctx, idx)
      scan_tinstr(ctx, arg)
    }
    TMemoryFill(idx, dst, val, len) => {
      mark_mem(ctx, idx)
      scan_tinstr(ctx, dst)
      scan_tinstr(ctx, val)
      scan_tinstr(ctx, len)
    }
    TMemoryCopy(idx1, idx2, dst, src, len) => {
      mark_mem(ctx, idx1)
      mark_mem(ctx, idx2)
      scan_tinstr(ctx, dst)
      scan_tinstr(ctx, src)
      scan_tinstr(ctx, len)
    }
    TMemoryInit(data_idx, mem_idx, dst, src, len) => {
      mark_data(ctx, data_idx)
      mark_mem(ctx, mem_idx)
      scan_tinstr(ctx, dst)
      scan_tinstr(ctx, src)
      scan_tinstr(ctx, len)
    }
    TDataDrop(idx) => mark_data(ctx, idx)

    // Load/Store (use memory 0 implicitly via memarg)
    TLoad(_, memarg, idx) => {
      if memarg.1 is Some(idx) {
        mark_mem(ctx, idx)
      } else {
        mark_mem(ctx, MemIdx::new(0))
      }
      scan_tinstr(ctx, idx)
    }
    TStore(_, memarg, idx, val) => {
      if memarg.1 is Some(idx) {
        mark_mem(ctx, idx)
      } else {
        mark_mem(ctx, MemIdx::new(0))
      }
      scan_tinstr(ctx, idx)
      scan_tinstr(ctx, val)
    }

    // GC types
    TStructNew(type_idx, args) => {
      mark_type(ctx, type_idx)
      for a in args {
        scan_tinstr(ctx, a)
      }
    }
    TStructNewDefault(type_idx) => mark_type(ctx, type_idx)
    TStructGet(type_idx, _, arg)
    | TStructGetS(type_idx, _, arg)
    | TStructGetU(type_idx, _, arg) => {
      mark_type(ctx, type_idx)
      scan_tinstr(ctx, arg)
    }
    TStructSet(type_idx, _, a, b) => {
      mark_type(ctx, type_idx)
      scan_tinstr(ctx, a)
      scan_tinstr(ctx, b)
    }
    TArrayNew(type_idx, len, init) => {
      mark_type(ctx, type_idx)
      scan_tinstr(ctx, len)
      scan_tinstr(ctx, init)
    }
    TArrayNewDefault(type_idx, len) => {
      mark_type(ctx, type_idx)
      scan_tinstr(ctx, len)
    }
    TArrayNewFixed(type_idx, args) => {
      mark_type(ctx, type_idx)
      for a in args {
        scan_tinstr(ctx, a)
      }
    }
    TArrayNewData(type_idx, data_idx, a, b) => {
      mark_type(ctx, type_idx)
      mark_data(ctx, data_idx)
      scan_tinstr(ctx, a)
      scan_tinstr(ctx, b)
    }
    TArrayNewElem(type_idx, elem_idx, a, b) => {
      mark_type(ctx, type_idx)
      mark_elem(ctx, elem_idx)
      scan_tinstr(ctx, a)
      scan_tinstr(ctx, b)
    }
    TArrayGet(type_idx, arr, idx)
    | TArrayGetS(type_idx, arr, idx)
    | TArrayGetU(type_idx, arr, idx) => {
      mark_type(ctx, type_idx)
      scan_tinstr(ctx, arr)
      scan_tinstr(ctx, idx)
    }
    TArraySet(type_idx, arr, idx, val) => {
      mark_type(ctx, type_idx)
      scan_tinstr(ctx, arr)
      scan_tinstr(ctx, idx)
      scan_tinstr(ctx, val)
    }
    TArrayLen(arr) => scan_tinstr(ctx, arr)
    TArrayFill(type_idx, a, b, c, d) => {
      mark_type(ctx, type_idx)
      scan_tinstr(ctx, a)
      scan_tinstr(ctx, b)
      scan_tinstr(ctx, c)
      scan_tinstr(ctx, d)
    }
    TArrayCopy(type_idx1, type_idx2, a, b, c, d, e) => {
      mark_type(ctx, type_idx1)
      mark_type(ctx, type_idx2)
      scan_tinstr(ctx, a)
      scan_tinstr(ctx, b)
      scan_tinstr(ctx, c)
      scan_tinstr(ctx, d)
      scan_tinstr(ctx, e)
    }
    TArrayInitData(type_idx, data_idx, a, b, c, d) => {
      mark_type(ctx, type_idx)
      mark_data(ctx, data_idx)
      scan_tinstr(ctx, a)
      scan_tinstr(ctx, b)
      scan_tinstr(ctx, c)
      scan_tinstr(ctx, d)
    }
    TArrayInitElem(type_idx, elem_idx, a, b, c, d) => {
      mark_type(ctx, type_idx)
      mark_elem(ctx, elem_idx)
      scan_tinstr(ctx, a)
      scan_tinstr(ctx, b)
      scan_tinstr(ctx, c)
      scan_tinstr(ctx, d)
    }

    // Ref types
    TRefNull(ht) => mark_heaptype(ctx, ht)
    TRefCast(_, ht, arg) | TRefTest(_, ht, arg) => {
      mark_heaptype(ctx, ht)
      scan_tinstr(ctx, arg)
    }
    TBrOnCast(_, _, ht1, ht2, arg, args)
    | TBrOnCastFail(_, _, ht1, ht2, arg, args) => {
      mark_heaptype(ctx, ht1)
      mark_heaptype(ctx, ht2)
      scan_tinstr(ctx, arg)
      for a in args {
        scan_tinstr(ctx, a)
      }
    }

    // Select with types
    TSelect(types, cond, a, b) => {
      match types {
        Some(vts) =>
          for vt in vts {
            mark_valtype(ctx, vt)
          }
        None => ()
      }
      scan_tinstr(ctx, cond)
      scan_tinstr(ctx, a)
      scan_tinstr(ctx, b)
    }

    // Recurse into children for remaining cases
    _ => scan_tinstr_children(ctx, instr)
  }
}

///|
fn scan_tinstr_children(ctx : AnalysisContext, instr : TInstr) -> Unit {
  match instr {
    TLocalSet(_, arg) | TLocalTee(_, arg) => scan_tinstr(ctx, arg)
    TUnary(_, arg)
    | TDrop(arg)
    | TRefIsNull(arg)
    | TRefAsNonNull(arg)
    | TAnyConvertExtern(arg)
    | TExternConvertAny(arg)
    | TI31GetS(arg)
    | TI31GetU(arg)
    | TRefI31(arg) => scan_tinstr(ctx, arg)
    TBinary(_, a, b) | TRefEq(a, b) => {
      scan_tinstr(ctx, a)
      scan_tinstr(ctx, b)
    }
    TBr(_, args) | TReturn(args) =>
      for a in args {
        scan_tinstr(ctx, a)
      }
    TBrIf(_, cond, args) => {
      scan_tinstr(ctx, cond)
      for a in args {
        scan_tinstr(ctx, a)
      }
    }
    TBrTable(_, _, cond, args) => {
      scan_tinstr(ctx, cond)
      for a in args {
        scan_tinstr(ctx, a)
      }
    }
    TBrOnNull(_, arg, args) | TBrOnNonNull(_, arg, args) => {
      scan_tinstr(ctx, arg)
      for a in args {
        scan_tinstr(ctx, a)
      }
    }
    TV128LoadLane(_, _, _, vec, addr) | TV128StoreLane(_, _, _, vec, addr) => {
      scan_tinstr(ctx, vec)
      scan_tinstr(ctx, addr)
    }
    TV128Shift(_, a, b) => {
      scan_tinstr(ctx, a)
      scan_tinstr(ctx, b)
    }
    TV128Ternary(_, a, b, c) => {
      scan_tinstr(ctx, a)
      scan_tinstr(ctx, b)
      scan_tinstr(ctx, c)
    }
    TI8x16Shuffle(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, a, b)
    | TI8x16Swizzle(a, b)
    | TI8x16RelaxedSwizzle(a, b) => {
      scan_tinstr(ctx, a)
      scan_tinstr(ctx, b)
    }
    TI8x16Splat(a)
    | TI16x8Splat(a)
    | TI32x4Splat(a)
    | TI64x2Splat(a)
    | TF32x4Splat(a)
    | TF64x2Splat(a) => scan_tinstr(ctx, a)
    TExtractLane(_, _, a) => scan_tinstr(ctx, a)
    TReplaceLane(_, _, vec, val) => {
      scan_tinstr(ctx, vec)
      scan_tinstr(ctx, val)
    }
    _ => () // Constants, nop, unreachable, local_get, etc.
  }
}

///|
fn scan_expr(ctx : AnalysisContext, expr : Expr) -> Unit {
  for instr in expr.0 {
    scan_instr(ctx, instr)
  }
}

///|
fn scan_instr(ctx : AnalysisContext, instr : Instruction) -> Unit {
  match instr {
    Call(idx) | ReturnCall(idx) | RefFunc(idx) => mark_func(ctx, idx)
    CallIndirect(type_idx, table_idx)
    | ReturnCallIndirect(type_idx, table_idx) => {
      mark_type(ctx, type_idx)
      mark_table(ctx, table_idx)
    }
    CallRef(type_idx) | ReturnCallRef(type_idx) => mark_type(ctx, type_idx)
    Block(bt, expr) | Loop(bt, expr) => {
      mark_blocktype(ctx, bt)
      scan_expr(ctx, expr)
    }
    If(bt, then_instrs, else_instrs) => {
      mark_blocktype(ctx, bt)
      for i in then_instrs {
        scan_instr(ctx, i)
      }
      match else_instrs {
        Some(instrs) =>
          for i in instrs {
            scan_instr(ctx, i)
          }
        None => ()
      }
    }
    TryTable(bt, catches, expr) => {
      mark_blocktype(ctx, bt)
      for c in catches {
        match c {
          Catch(tag_idx, _) | CatchRef(tag_idx, _) => mark_tag(ctx, tag_idx)
          _ => ()
        }
      }
      scan_expr(ctx, expr)
    }
    Throw(tag_idx) => mark_tag(ctx, tag_idx)
    GlobalGet(idx) | GlobalSet(idx) => mark_global(ctx, idx)
    TableGet(idx)
    | TableSet(idx)
    | TableGrow(idx)
    | TableSize(idx)
    | TableFill(idx) => mark_table(ctx, idx)
    TableCopy(idx1, idx2) => {
      mark_table(ctx, idx1)
      mark_table(ctx, idx2)
    }
    TableInit(elem_idx, table_idx) => {
      mark_elem(ctx, elem_idx)
      mark_table(ctx, table_idx)
    }
    ElemDrop(idx) => mark_elem(ctx, idx)
    MemorySize(idx) | MemoryGrow(idx) | MemoryFill(idx) => mark_mem(ctx, idx)
    MemoryCopy(idx1, idx2) => {
      mark_mem(ctx, idx1)
      mark_mem(ctx, idx2)
    }
    MemoryInit(data_idx, mem_idx) => {
      mark_data(ctx, data_idx)
      mark_mem(ctx, mem_idx)
    }
    DataDrop(idx) => mark_data(ctx, idx)
    StructNew(type_idx) | StructNewDefault(type_idx) => mark_type(ctx, type_idx)
    StructGet(type_idx, _)
    | StructGetS(type_idx, _)
    | StructGetU(type_idx, _)
    | StructSet(type_idx, _) => mark_type(ctx, type_idx)
    ArrayNew(type_idx)
    | ArrayNewDefault(type_idx)
    | ArrayNewFixed(type_idx, _)
    | ArrayGet(type_idx)
    | ArrayGetS(type_idx)
    | ArrayGetU(type_idx)
    | ArraySet(type_idx)
    | ArrayFill(type_idx) => mark_type(ctx, type_idx)
    ArrayNewData(type_idx, data_idx) | ArrayInitData(type_idx, data_idx) => {
      mark_type(ctx, type_idx)
      mark_data(ctx, data_idx)
    }
    ArrayNewElem(type_idx, elem_idx) | ArrayInitElem(type_idx, elem_idx) => {
      mark_type(ctx, type_idx)
      mark_elem(ctx, elem_idx)
    }
    ArrayCopy(type_idx1, type_idx2) => {
      mark_type(ctx, type_idx1)
      mark_type(ctx, type_idx2)
    }
    RefNull(ht) => mark_heaptype(ctx, ht)
    RefCast(_, ht) | RefTest(_, ht) => mark_heaptype(ctx, ht)
    BrOnCast(_, _, ht1, ht2) | BrOnCastFail(_, _, ht1, ht2) => {
      mark_heaptype(ctx, ht1)
      mark_heaptype(ctx, ht2)
    }
    Select(types) =>
      match types {
        Some(vts) =>
          for vt in vts {
            mark_valtype(ctx, vt)
          }
        None => ()
      }
    I32Load(ma)
    | I64Load(ma)
    | F32Load(ma)
    | F64Load(ma)
    | I32Load8S(ma)
    | I32Load8U(ma)
    | I32Load16S(ma)
    | I32Load16U(ma)
    | I64Load8S(ma)
    | I64Load8U(ma)
    | I64Load16S(ma)
    | I64Load16U(ma)
    | I64Load32S(ma)
    | I64Load32U(ma)
    | I32Store(ma)
    | I64Store(ma)
    | F32Store(ma)
    | F64Store(ma)
    | I32Store8(ma)
    | I32Store16(ma)
    | I64Store8(ma)
    | I64Store16(ma)
    | I64Store32(ma)
    | V128Load(ma)
    | V128Load8x8S(ma)
    | V128Load8x8U(ma)
    | V128Load16x4S(ma)
    | V128Load16x4U(ma)
    | V128Load32x2S(ma)
    | V128Load32x2U(ma)
    | V128Load8Splat(ma)
    | V128Load16Splat(ma)
    | V128Load32Splat(ma)
    | V128Load64Splat(ma)
    | V128Store(ma)
    | V128Load8Lane(ma, _)
    | V128Load16Lane(ma, _)
    | V128Load32Lane(ma, _)
    | V128Load64Lane(ma, _)
    | V128Store8Lane(ma, _)
    | V128Store16Lane(ma, _)
    | V128Store32Lane(ma, _)
    | V128Store64Lane(ma, _)
    | V128Load32Zero(ma)
    | V128Load64Zero(ma) => if ma.1 is Some(idx) { mark_mem(ctx, idx) }
    _ => ()
  }
}

// ============================================================================
// Build Remappings
// ============================================================================
// Helper to build a sorted remapping (can fail if extract fails)

///|
fn[T : Hash + Eq] build_map(
  used_set : Set[T],
  import_count : UInt,
  extract : (T) -> Result[UInt, String],
  construct : (UInt) -> T,
) -> Result[Map[T, T], String] {
  let map : Map[T, T] = Map::new()
  let imports : Array[(T, UInt)] = []
  let defined : Array[(T, UInt)] = []
  for idx in used_set {
    let v = match extract(idx) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    if v >= import_count {
      defined.push((idx, v))
    } else {
      imports.push((idx, v))
    }
  }
  imports.sort_by(fn(a, b) { a.1.compare(b.1) })
  defined.sort_by(fn(a, b) { a.1.compare(b.1) })
  let mut next : UInt = 0
  for pair in imports {
    map.set(pair.0, construct(next))
    next += 1
  }
  for pair in defined {
    map.set(pair.0, construct(next))
    next += 1
  }
  Ok(map)
}

///|
fn build_remappings(
  used : UsedIndices,
  imports : ImportCounts,
) -> Result[Remappings, String] {
  let remap = Remappings::new()

  // Build each remapping
  remap.funcs = match
    build_map(
      used.funcs,
      imports.funcs,
      fn(idx) {
        let FuncIdx(v) = idx
        Ok(v)
      },
      FuncIdx::new,
    ) {
    Ok(m) => m
    Err(e) => return Err(e)
  }
  remap.tables = match
    build_map(
      used.tables,
      imports.tables,
      fn(idx) {
        let TableIdx(v) = idx
        Ok(v)
      },
      TableIdx::new,
    ) {
    Ok(m) => m
    Err(e) => return Err(e)
  }
  remap.mems = match
    build_map(
      used.mems,
      imports.mems,
      fn(idx) {
        let MemIdx(v) = idx
        Ok(v)
      },
      MemIdx::new,
    ) {
    Ok(m) => m
    Err(e) => return Err(e)
  }
  remap.globals = match
    build_map(
      used.globals,
      imports.globals,
      fn(idx) {
        let GlobalIdx(v) = idx
        Ok(v)
      },
      GlobalIdx::new,
    ) {
    Ok(m) => m
    Err(e) => return Err(e)
  }
  remap.tags = match
    build_map(
      used.tags,
      imports.tags,
      fn(idx) {
        let TagIdx(v) = idx
        Ok(v)
      },
      TagIdx::new,
    ) {
    Ok(m) => m
    Err(e) => return Err(e)
  }

  // Types, elems, datas have no imports
  remap.types = match
    build_map(
      used.types,
      0,
      fn(idx) {
        match idx {
          TypeIdx(v) => Ok(v)
          RecIdx(_) =>
            Err(
              "unexpected RecIdx in type remapping (RecIdx is only used during validation)",
            )
        }
      },
      TypeIdx::new,
    ) {
    Ok(m) => m
    Err(e) => return Err(e)
  }
  remap.elems = match
    build_map(
      used.elems,
      0,
      fn(idx) {
        let ElemIdx(v) = idx
        Ok(v)
      },
      ElemIdx::new,
    ) {
    Ok(m) => m
    Err(e) => return Err(e)
  }
  remap.datas = match
    build_map(
      used.datas,
      0,
      fn(idx) {
        let DataIdx(v) = idx
        Ok(v)
      },
      DataIdx::new,
    ) {
    Ok(m) => m
    Err(e) => return Err(e)
  }
  Ok(remap)
}

// ============================================================================
// Transformation Phase using ModuleTransformer
// ============================================================================

///|
pub fn remove_unused(mod : Module) -> Result[Module, String] {
  // Phase 1: Analysis
  let ctx = AnalysisContext::new(mod)
  analyze(ctx)

  // Check if everything is used
  let total_funcs = ctx.imports.funcs +
    (match mod.code_sec {
      Some(cs) => cs.0.length().reinterpret_as_uint()
      None => 0
    })
  let total_types = match mod.type_sec {
    Some(ts) => ts.0.length().reinterpret_as_uint()
    None => 0
  }
  let total_tables = ctx.imports.tables +
    (match mod.table_sec {
      Some(ts) => ts.0.length().reinterpret_as_uint()
      None => 0
    })
  let total_mems = ctx.imports.mems +
    (match mod.mem_sec {
      Some(ms) => ms.0.length().reinterpret_as_uint()
      None => 0
    })
  let total_globals = ctx.imports.globals +
    (match mod.global_sec {
      Some(gs) => gs.0.length().reinterpret_as_uint()
      None => 0
    })
  let total_elems = match mod.elem_sec {
    Some(es) => es.0.length().reinterpret_as_uint()
    None => 0
  }
  let total_datas = match mod.data_sec {
    Some(ds) => ds.0.length().reinterpret_as_uint()
    None => 0
  }
  let total_tags = ctx.imports.tags +
    (match mod.tag_sec {
      Some(ts) => ts.0.length().reinterpret_as_uint()
      None => 0
    })
  if ctx.used.funcs.length().reinterpret_as_uint() == total_funcs &&
    ctx.used.types.length().reinterpret_as_uint() == total_types &&
    ctx.used.tables.length().reinterpret_as_uint() == total_tables &&
    ctx.used.mems.length().reinterpret_as_uint() == total_mems &&
    ctx.used.globals.length().reinterpret_as_uint() == total_globals &&
    ctx.used.elems.length().reinterpret_as_uint() == total_elems &&
    ctx.used.datas.length().reinterpret_as_uint() == total_datas &&
    ctx.used.tags.length().reinterpret_as_uint() == total_tags {
    // Nothing to remove
    return Ok(mod)
  }

  // Phase 2: Build remappings
  let remap = match build_remappings(ctx.used, ctx.imports) {
    Ok(m) => m
    Err(e) => return Err(e)
  }
  let state : DCEState = { used: ctx.used, remap, imports: ctx.imports }

  // Phase 3: Transform using ModuleTransformer
  let transformer = ModuleTransformer::new()
    // Remap all index types
    .on_funcidx_evt(fn(
      _t : ModuleTransformer[DCEState],
      s : DCEState,
      idx : FuncIdx,
    ) {
      match s.remap.funcs.get(idx) {
        Some(new_idx) => change(s, new_idx)
        None => unchanged()
      }
    })
    .on_typeidx_evt(fn(_t, s : DCEState, idx : TypeIdx) {
      match s.remap.types.get(idx) {
        Some(new_idx) => change(s, new_idx)
        None => unchanged()
      }
    })
    .on_tableidx_evt(fn(_t, s : DCEState, idx : TableIdx) {
      match s.remap.tables.get(idx) {
        Some(new_idx) => change(s, new_idx)
        None => unchanged()
      }
    })
    .on_memidx_evt(fn(_t, s : DCEState, idx : MemIdx) {
      match s.remap.mems.get(idx) {
        Some(new_idx) => change(s, new_idx)
        None => unchanged()
      }
    })
    .on_globalidx_evt(fn(_t, s : DCEState, idx : GlobalIdx) {
      match s.remap.globals.get(idx) {
        Some(new_idx) => change(s, new_idx)
        None => unchanged()
      }
    })
    .on_elemidx_evt(fn(_t, s : DCEState, idx : ElemIdx) {
      match s.remap.elems.get(idx) {
        Some(new_idx) => change(s, new_idx)
        None => unchanged()
      }
    })
    .on_dataidx_evt(fn(_t, s : DCEState, idx : DataIdx) {
      match s.remap.datas.get(idx) {
        Some(new_idx) => change(s, new_idx)
        None => unchanged()
      }
    })
    .on_tagidx_evt(fn(_t, s : DCEState, idx : TagIdx) {
      match s.remap.tags.get(idx) {
        Some(new_idx) => change(s, new_idx)
        None => unchanged()
      }
    })
    // Also remap heap types that reference type indices
    .on_heaptype_evt(fn(_t, s : DCEState, ht : HeapType) {
      match ht {
        HeapType(idx) =>
          match s.remap.types.get(idx) {
            Some(new_idx) => change(s, HeapType::new(new_idx))
            None => unchanged()
          }
        _ => unchanged()
      }
    })
    // Filter import section
    .on_importsec_evt(fn(
      _t : ModuleTransformer[DCEState],
      s : DCEState,
      imp_sec : ImportSec,
    ) {
      let new_imports = []
      let mut func_idx : UInt = 0
      let mut table_idx : UInt = 0
      let mut mem_idx : UInt = 0
      let mut global_idx : UInt = 0
      let mut tag_idx : UInt = 0
      for imp in imp_sec.0 {
        match imp {
          Import(mod_name, name, extern_type) => {
            let keep = match extern_type {
              FuncExternType(_) => {
                let idx = FuncIdx::new(func_idx)
                func_idx += 1
                s.used.funcs.contains(idx)
              }
              TableExternType(_) => {
                let idx = TableIdx::new(table_idx)
                table_idx += 1
                s.used.tables.contains(idx)
              }
              MemExternType(_) => {
                let idx = MemIdx::new(mem_idx)
                mem_idx += 1
                s.used.mems.contains(idx)
              }
              GlobalExternType(_) => {
                let idx = GlobalIdx::new(global_idx)
                global_idx += 1
                s.used.globals.contains(idx)
              }
              TagExternType(_) => {
                let idx = TagIdx::new(tag_idx)
                tag_idx += 1
                s.used.tags.contains(idx)
              }
            }
            if keep {
              // Transform the import to remap type indices
              let new_extern = match extern_type {
                FuncExternType(type_idx) =>
                  match s.remap.types.get(type_idx) {
                    Some(new_type_idx) => ExternType::func(new_type_idx)
                    None => extern_type
                  }
                _ => extern_type // Other extern types don't need remapping here
              }
              new_imports.push(Import::new(mod_name, name, new_extern))
            }
          }
        }
      }
      change(s, ImportSec::new(new_imports))
    })
    // Filter type section
    .on_typesec_evt(fn(
      _t : ModuleTransformer[DCEState],
      s : DCEState,
      type_sec : TypeSec,
    ) {
      let new_types = []
      let types = type_sec.0
      for i = 0; i < types.length(); i = i + 1 {
        let type_idx = TypeIdx::new(i.reinterpret_as_uint())
        if s.used.types.contains(type_idx) {
          // Transform recursively to remap type references
          let rec_type = types[i]
          // Let the transformer handle the inner remapping
          new_types.push(rec_type)
        }
      }
      change(s, TypeSec::new(new_types))
    })
    // Filter func section (type indices for defined functions)
    .on_funcsec_evt(fn(
      _t : ModuleTransformer[DCEState],
      s : DCEState,
      func_sec : FuncSec,
    ) {
      let new_types = []
      let types = func_sec.0
      for i = 0; i < types.length(); i = i + 1 {
        let func_idx = FuncIdx::new(s.imports.funcs + i.reinterpret_as_uint())
        if s.used.funcs.contains(func_idx) {
          let type_idx = types[i]
          match s.remap.types.get(type_idx) {
            Some(new_type_idx) => new_types.push(new_type_idx)
            None => new_types.push(type_idx)
          }
        }
      }
      change(s, FuncSec::new(new_types))
    })
    // Filter code section
    .on_codesec_evt(fn(
      _t : ModuleTransformer[DCEState],
      s : DCEState,
      code_sec : CodeSec,
    ) {
      let new_funcs = []
      let funcs = code_sec.0
      for i = 0; i < funcs.length(); i = i + 1 {
        let func_idx = FuncIdx::new(s.imports.funcs + i.reinterpret_as_uint())
        if s.used.funcs.contains(func_idx) {
          new_funcs.push(funcs[i])
        }
      }
      change(s, CodeSec::new(new_funcs))
    })
    // Filter table section
    .on_tablesec_evt(fn(
      _t : ModuleTransformer[DCEState],
      s : DCEState,
      table_sec : TableSec,
    ) {
      let new_tables = []
      let tables = table_sec.0
      for i = 0; i < tables.length(); i = i + 1 {
        let table_idx = TableIdx::new(
          s.imports.tables + i.reinterpret_as_uint(),
        )
        if s.used.tables.contains(table_idx) {
          new_tables.push(tables[i])
        }
      }
      change(s, TableSec::new(new_tables))
    })
    // Filter memory section
    .on_memsec_evt(fn(
      _t : ModuleTransformer[DCEState],
      s : DCEState,
      mem_sec : MemSec,
    ) {
      let new_mems = []
      let mems = mem_sec.0
      for i = 0; i < mems.length(); i = i + 1 {
        let mem_idx = MemIdx::new(s.imports.mems + i.reinterpret_as_uint())
        if s.used.mems.contains(mem_idx) {
          new_mems.push(mems[i])
        }
      }
      change(s, MemSec::new(new_mems))
    })
    // Filter global section
    .on_globalsec_evt(fn(
      _t : ModuleTransformer[DCEState],
      s : DCEState,
      global_sec : GlobalSec,
    ) {
      let new_globals = []
      let globals = global_sec.0
      for i = 0; i < globals.length(); i = i + 1 {
        let global_idx = GlobalIdx::new(
          s.imports.globals + i.reinterpret_as_uint(),
        )
        if s.used.globals.contains(global_idx) {
          new_globals.push(globals[i])
        }
      }
      change(s, GlobalSec::new(new_globals))
    })
    // Filter tag section
    .on_tagsec_evt(fn(
      _t : ModuleTransformer[DCEState],
      s : DCEState,
      tag_sec : TagSec,
    ) {
      let new_tags = []
      let tags = tag_sec.0
      for i = 0; i < tags.length(); i = i + 1 {
        let tag_idx = TagIdx::new(s.imports.tags + i.reinterpret_as_uint())
        if s.used.tags.contains(tag_idx) {
          new_tags.push(tags[i])
        }
      }
      change(s, TagSec::new(new_tags))
    })
    // Filter element section
    .on_elemsec_evt(fn(
      _t : ModuleTransformer[DCEState],
      s : DCEState,
      elem_sec : ElemSec,
    ) {
      let new_elems = []
      let elems = elem_sec.0
      for i = 0; i < elems.length(); i = i + 1 {
        let elem_idx = ElemIdx::new(i.reinterpret_as_uint())
        if s.used.elems.contains(elem_idx) {
          new_elems.push(elems[i])
        }
      }
      change(s, ElemSec::new(new_elems))
    })
    // Filter data section
    .on_datasec_evt(fn(
      _t : ModuleTransformer[DCEState],
      s : DCEState,
      data_sec : DataSec,
    ) {
      let new_datas = []
      let datas = data_sec.0
      for i = 0; i < datas.length(); i = i + 1 {
        let data_idx = DataIdx::new(i.reinterpret_as_uint())
        if s.used.datas.contains(data_idx) {
          new_datas.push(datas[i])
        }
      }
      change(s, DataSec::new(new_datas))
    })
    // Update data count section
    .on_datacntsec_evt(fn(_t : ModuleTransformer[DCEState], s : DCEState, _) {
      let count = s.used.datas.length().reinterpret_as_uint()
      change(s, DataCntSec::new(count))
    })
    // Filter exports to only include used items
    .on_exportsec_evt(fn(
      _t : ModuleTransformer[DCEState],
      s : DCEState,
      export_sec : ExportSec,
    ) {
      let new_exports = []
      for exp in export_sec.0 {
        match exp {
          Export(name, extern_idx) => {
            let (keep, new_extern_idx) = match extern_idx {
              FuncExternIdx(idx) =>
                if s.used.funcs.contains(idx) {
                  match s.remap.funcs.get(idx) {
                    Some(new_idx) => (true, ExternIdx::func(new_idx))
                    None => (true, extern_idx)
                  }
                } else {
                  (false, extern_idx)
                }
              TableExternIdx(idx) =>
                if s.used.tables.contains(idx) {
                  match s.remap.tables.get(idx) {
                    Some(new_idx) => (true, ExternIdx::table(new_idx))
                    None => (true, extern_idx)
                  }
                } else {
                  (false, extern_idx)
                }
              MemExternIdx(idx) =>
                if s.used.mems.contains(idx) {
                  match s.remap.mems.get(idx) {
                    Some(new_idx) => (true, ExternIdx::mem(new_idx))
                    None => (true, extern_idx)
                  }
                } else {
                  (false, extern_idx)
                }
              GlobalExternIdx(idx) =>
                if s.used.globals.contains(idx) {
                  match s.remap.globals.get(idx) {
                    Some(new_idx) => (true, ExternIdx::global(new_idx))
                    None => (true, extern_idx)
                  }
                } else {
                  (false, extern_idx)
                }
              TagExternIdx(idx) =>
                if s.used.tags.contains(idx) {
                  match s.remap.tags.get(idx) {
                    Some(new_idx) => (true, ExternIdx::tag(new_idx))
                    None => (true, extern_idx)
                  }
                } else {
                  (false, extern_idx)
                }
            }
            if keep {
              new_exports.push(Export::new(name, new_extern_idx))
            }
          }
        }
      }
      change(s, ExportSec::new(new_exports))
    })
    // Update start section
    .on_startsec_evt(fn(
      _t : ModuleTransformer[DCEState],
      s : DCEState,
      start_sec : StartSec,
    ) {
      let func_idx = start_sec.0
      match s.remap.funcs.get(func_idx) {
        Some(new_idx) => change(s, StartSec::new(new_idx))
        None => unchanged()
      }
    })
  transformer
  .walk_module(state, mod)
  .map(fn(pair : (DCEState, Module)?) {
    match pair {
      Some((_, mod)) => mod
      None => mod
    }
  })
}

// ============================================================================
// Test Helpers
// ============================================================================

///|
/// Creates a simple function type: [] -> []
fn make_void_func_type() -> RecType {
  RecType::new(SubType::comp_type(CompType::func([], [])))
}

///|
/// Creates a function type: [i32] -> [i32]
fn make_i32_to_i32_func_type() -> RecType {
  RecType::new(
    SubType::comp_type(CompType::func([ValType::i32()], [ValType::i32()])),
  )
}

///|
/// Creates a simple function body that just returns
fn make_empty_func_body() -> Func {
  Func::t_func([], TExpr::new([TInstr::return_([])]))
}

// ============================================================================
// Basic Tests
// ============================================================================

///|
test "empty module unchanged" {
  let mod = Module::new()
  let result = remove_unused(mod)
  match result {
    Ok(new_mod) => {
      // Empty module should be unchanged
      assert_true(new_mod.type_sec is None)
      assert_true(new_mod.func_sec is None)
      assert_true(new_mod.code_sec is None)
    }
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "single exported function kept" {
  // Module with one function that is exported
  let type_sec = TypeSec::new([make_void_func_type()])
  let func_sec = FuncSec::new([TypeIdx::new(0)])
  let code_sec = CodeSec::new([make_empty_func_body()])
  let export_sec = ExportSec::new([
    Export::new(Name::new("main"), ExternIdx::func(FuncIdx::new(0))),
  ])
  let mod = Module::new()
    .with_type_sec(type_sec)
    .with_func_sec(func_sec)
    .with_code_sec(code_sec)
    .with_export_sec(export_sec)
  let result = remove_unused(mod)
  match result {
    Ok(new_mod) => {
      // Function and type should be kept
      assert_true(new_mod.type_sec is Some(_))
      assert_true(new_mod.func_sec is Some(_))
      assert_true(new_mod.code_sec is Some(_))
      assert_eq(new_mod.type_sec.unwrap().0.length(), 1)
      assert_eq(new_mod.func_sec.unwrap().0.length(), 1)
      assert_eq(new_mod.code_sec.unwrap().0.length(), 1)
    }
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "unused function removed" {
  // Module with two functions, only one exported
  let type_sec = TypeSec::new([make_void_func_type()])
  let func_sec = FuncSec::new([TypeIdx::new(0), TypeIdx::new(0)])
  let code_sec = CodeSec::new([make_empty_func_body(), make_empty_func_body()])
  let export_sec = ExportSec::new([
    Export::new(Name::new("main"), ExternIdx::func(FuncIdx::new(0))),
  ])
  let mod = Module::new()
    .with_type_sec(type_sec)
    .with_func_sec(func_sec)
    .with_code_sec(code_sec)
    .with_export_sec(export_sec)
  let result = remove_unused(mod)
  match result {
    Ok(new_mod) => {
      // Only one function should remain
      assert_eq(new_mod.func_sec.unwrap().0.length(), 1)
      assert_eq(new_mod.code_sec.unwrap().0.length(), 1)
    }
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "unused type removed" {
  // Module with two types, only one used
  let type_sec = TypeSec::new([
    make_void_func_type(),
    make_i32_to_i32_func_type(), // unused
  ])
  let func_sec = FuncSec::new([TypeIdx::new(0)])
  let code_sec = CodeSec::new([make_empty_func_body()])
  let export_sec = ExportSec::new([
    Export::new(Name::new("main"), ExternIdx::func(FuncIdx::new(0))),
  ])
  let mod = Module::new()
    .with_type_sec(type_sec)
    .with_func_sec(func_sec)
    .with_code_sec(code_sec)
    .with_export_sec(export_sec)
  let result = remove_unused(mod)
  match result {
    Ok(new_mod) =>
      // Only one type should remain
      assert_eq(new_mod.type_sec.unwrap().0.length(), 1)
    Err(e) => fail("unexpected error: \{e}")
  }
}

// ============================================================================
// Index Remapping Tests
// ============================================================================

///|
test "function index remapped after removal" {
  // func 0: unused
  // func 1: exported -> should become func 0
  let type_sec = TypeSec::new([make_void_func_type()])
  let func_sec = FuncSec::new([TypeIdx::new(0), TypeIdx::new(0)])
  let code_sec = CodeSec::new([make_empty_func_body(), make_empty_func_body()])
  let export_sec = ExportSec::new([
    Export::new(Name::new("main"), ExternIdx::func(FuncIdx::new(1))),
  ])
  let mod = Module::new()
    .with_type_sec(type_sec)
    .with_func_sec(func_sec)
    .with_code_sec(code_sec)
    .with_export_sec(export_sec)
  let result = remove_unused(mod)
  match result {
    Ok(new_mod) => {
      // Export should now reference func 0
      let exports = new_mod.export_sec.unwrap().0
      match exports[0] {
        Export(_, FuncExternIdx(idx)) => {
          let FuncIdx(v) = idx
          assert_eq(v, 0)
        }
        _ => fail("expected function export")
      }
    }
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "type index remapped in function after type removal" {
  // type 0: unused
  // type 1: used by func -> should become type 0
  let type_sec = TypeSec::new([
    make_i32_to_i32_func_type(), // unused
    make_void_func_type(), // used
  ])
  let func_sec = FuncSec::new([TypeIdx::new(1)])
  let code_sec = CodeSec::new([make_empty_func_body()])
  let export_sec = ExportSec::new([
    Export::new(Name::new("main"), ExternIdx::func(FuncIdx::new(0))),
  ])
  let mod = Module::new()
    .with_type_sec(type_sec)
    .with_func_sec(func_sec)
    .with_code_sec(code_sec)
    .with_export_sec(export_sec)
  let result = remove_unused(mod)
  match result {
    Ok(new_mod) => {
      // Type count should be 1
      assert_eq(new_mod.type_sec.unwrap().0.length(), 1)
      // Func should reference type 0
      match new_mod.func_sec.unwrap().0[0] {
        TypeIdx(v) => assert_eq(v, 0)
        _ => fail("expected type index, not recursive idx")
      }
    }
    Err(e) => fail("unexpected error: \{e}")
  }
}

// ============================================================================
// Transitive Reachability Tests
// ============================================================================

///|
test "called function kept transitively" {
  // func 0: exported, calls func 1
  // func 1: called by func 0 -> should be kept
  let type_sec = TypeSec::new([make_void_func_type()])
  let func_sec = FuncSec::new([TypeIdx::new(0), TypeIdx::new(0)])
  let func0_body = Func::t_func(
    [],
    TExpr::new([TInstr::call(FuncIdx::new(1), []), TInstr::return_([])]),
  )
  let func1_body = make_empty_func_body()
  let code_sec = CodeSec::new([func0_body, func1_body])
  let export_sec = ExportSec::new([
    Export::new(Name::new("main"), ExternIdx::func(FuncIdx::new(0))),
  ])
  let mod = Module::new()
    .with_type_sec(type_sec)
    .with_func_sec(func_sec)
    .with_code_sec(code_sec)
    .with_export_sec(export_sec)
  let result = remove_unused(mod)
  match result {
    Ok(new_mod) => {
      // Both functions should be kept
      assert_eq(new_mod.func_sec.unwrap().0.length(), 2)
      assert_eq(new_mod.code_sec.unwrap().0.length(), 2)
    }
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "referenced global kept" {
  // func 0: exported, references global 0
  // global 0: should be kept
  let type_sec = TypeSec::new([make_void_func_type()])
  let func_sec = FuncSec::new([TypeIdx::new(0)])
  let global_sec = GlobalSec::new([
    Global::new(
      GlobalType::new(ValType::i32(), false),
      Expr::new([Instruction::i32_const(42)]),
    ),
  ])
  let func_body = Func::t_func(
    [],
    TExpr::new([
      TInstr::drop(TInstr::global_get(GlobalIdx::new(0))),
      TInstr::return_([]),
    ]),
  )
  let code_sec = CodeSec::new([func_body])
  let export_sec = ExportSec::new([
    Export::new(Name::new("main"), ExternIdx::func(FuncIdx::new(0))),
  ])
  let mod = Module::new()
    .with_type_sec(type_sec)
    .with_func_sec(func_sec)
    .with_global_sec(global_sec)
    .with_export_sec(export_sec)
    .with_code_sec(code_sec)
  let result = remove_unused(mod)
  match result {
    Ok(new_mod) => {
      // Global should be kept
      assert_true(new_mod.global_sec is Some(_))
      assert_eq(new_mod.global_sec.unwrap().0.length(), 1)
    }
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "unused global removed" {
  let type_sec = TypeSec::new([make_void_func_type()])
  let func_sec = FuncSec::new([TypeIdx::new(0)])
  let global_sec = GlobalSec::new([
    Global::new(
      GlobalType::new(ValType::i32(), false),
      Expr::new([Instruction::i32_const(42)]),
    ),
  ])
  let code_sec = CodeSec::new([make_empty_func_body()])
  let export_sec = ExportSec::new([
    Export::new(Name::new("main"), ExternIdx::func(FuncIdx::new(0))),
  ])
  let mod = Module::new()
    .with_type_sec(type_sec)
    .with_func_sec(func_sec)
    .with_global_sec(global_sec)
    .with_export_sec(export_sec)
    .with_code_sec(code_sec)
  let result = remove_unused(mod)
  match result {
    Ok(new_mod) =>
      // Global should be removed (empty section or None)
      match new_mod.global_sec {
        Some(sec) => assert_eq(sec.0.length(), 0)
        None => () // Also acceptable
      }
    Err(e) => fail("unexpected error: \{e}")
  }
}

// ============================================================================
// Start Function Tests
// ============================================================================

///|
test "start function kept" {
  let type_sec = TypeSec::new([make_void_func_type()])
  let func_sec = FuncSec::new([TypeIdx::new(0)])
  let code_sec = CodeSec::new([make_empty_func_body()])
  let start_sec = StartSec::new(FuncIdx::new(0))
  let mod = Module::new()
    .with_type_sec(type_sec)
    .with_func_sec(func_sec)
    .with_code_sec(code_sec)
    .with_start_sec(start_sec)
  let result = remove_unused(mod)
  match result {
    Ok(new_mod) => {
      // Function should be kept due to start section
      assert_eq(new_mod.func_sec.unwrap().0.length(), 1)
      assert_true(new_mod.start_sec is Some(_))
    }
    Err(e) => fail("unexpected error: \{e}")
  }
}

// ============================================================================
// Active Segment Tests
// ============================================================================

///|
test "active element segment keeps table and functions" {
  let type_sec = TypeSec::new([make_void_func_type()])
  let func_sec = FuncSec::new([TypeIdx::new(0)])
  let code_sec = CodeSec::new([make_empty_func_body()])
  let table_sec = TableSec::new([
    Table::new(
      TableType::new(
        RefType::new(true, HeapType::abs(AbsHeapType::func())),
        Limits::i32(1, Some(1)),
      ),
      None,
    ),
  ])
  let elem_sec = ElemSec::new([
    Elem::new(
      ElemMode::active(TableIdx::new(0), Expr::new([Instruction::i32_const(0)])),
      ElemKind::funcs([FuncIdx::new(0)]),
    ),
  ])
  let mod = Module::new()
    .with_type_sec(type_sec)
    .with_func_sec(func_sec)
    .with_code_sec(code_sec)
    .with_table_sec(table_sec)
    .with_elem_sec(elem_sec)
  let result = remove_unused(mod)
  match result {
    Ok(new_mod) => {
      // Table, elem, and function should all be kept
      assert_true(new_mod.table_sec is Some(_))
      assert_true(new_mod.elem_sec is Some(_))
      assert_eq(new_mod.func_sec.unwrap().0.length(), 1)
    }
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "active data segment keeps memory" {
  let type_sec = TypeSec::new([make_void_func_type()])
  let func_sec = FuncSec::new([TypeIdx::new(0)])
  let code_sec = CodeSec::new([make_empty_func_body()])
  let mem_sec = MemSec::new([MemType::new(Limits::i32(1, Some(1)))])
  let data_sec = DataSec::new([
    Data::new(
      DataMode::active(MemIdx::new(0), Expr::new([Instruction::i32_const(0)])),
      b"hello",
    ),
  ])
  let export_sec = ExportSec::new([
    Export::new(Name::new("main"), ExternIdx::func(FuncIdx::new(0))),
  ])
  let data_cnt_sec = DataCntSec::new(1)
  let mod = Module::new()
    .with_type_sec(type_sec)
    .with_func_sec(func_sec)
    .with_code_sec(code_sec)
    .with_mem_sec(mem_sec)
    .with_data_sec(data_sec)
    .with_data_cnt_sec(data_cnt_sec)
    .with_export_sec(export_sec)
  let result = remove_unused(mod)
  match result {
    Ok(new_mod) => {
      // Memory and data should be kept
      assert_true(new_mod.mem_sec is Some(_))
      assert_true(new_mod.data_sec is Some(_))
    }
    Err(e) => fail("unexpected error: \{e}")
  }
}

// ============================================================================
// Import Tests
// ============================================================================

///|
test "used imported function kept" {
  let type_sec = TypeSec::new([make_void_func_type()])
  let import_sec = ImportSec::new([
    Import::new(
      Name::new("env"),
      Name::new("log"),
      ExternType::func(TypeIdx::new(0)),
    ),
  ])
  let func_sec = FuncSec::new([TypeIdx::new(0)])

  // Defined func calls imported func
  let func_body = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(0), []), // call imported func
      TInstr::return_([]),
    ]),
  )
  let code_sec = CodeSec::new([func_body])
  let export_sec = ExportSec::new([
    Export::new(Name::new("main"), ExternIdx::func(FuncIdx::new(1))), // export defined func
  ])
  let mod = Module::new()
    .with_type_sec(type_sec)
    .with_import_sec(import_sec)
    .with_func_sec(func_sec)
    .with_code_sec(code_sec)
    .with_export_sec(export_sec)
  let result = remove_unused(mod)
  match result {
    Ok(new_mod) => {
      // Import should be kept
      assert_true(new_mod.import_sec is Some(_))
      assert_eq(new_mod.import_sec.unwrap().0.length(), 1)
    }
    Err(e) => fail("unexpected error: \{e}")
  }
}

///|
test "unused imported function removed" {
  let type_sec = TypeSec::new([make_void_func_type()])
  let import_sec = ImportSec::new([
    Import::new(
      Name::new("env"),
      Name::new("unused"),
      ExternType::func(TypeIdx::new(0)),
    ),
  ])
  let func_sec = FuncSec::new([TypeIdx::new(0)])
  let code_sec = CodeSec::new([make_empty_func_body()])
  let export_sec = ExportSec::new([
    Export::new(Name::new("main"), ExternIdx::func(FuncIdx::new(1))), // export defined func (index 1 because import is index 0)
  ])
  let mod = Module::new()
    .with_type_sec(type_sec)
    .with_import_sec(import_sec)
    .with_func_sec(func_sec)
    .with_code_sec(code_sec)
    .with_export_sec(export_sec)
  let result = remove_unused(mod)
  match result {
    Ok(new_mod) => {
      // Import should be removed
      match new_mod.import_sec {
        Some(sec) => assert_eq(sec.0.length(), 0)
        None => () // Also acceptable
      }
      // Export index should be remapped to 0
      let exports = new_mod.export_sec.unwrap().0
      match exports[0] {
        Export(_, FuncExternIdx(idx)) => {
          let FuncIdx(v) = idx
          assert_eq(v, 0)
        }
        _ => fail("expected function export")
      }
    }
    Err(e) => fail("unexpected error: \{e}")
  }
}

// ============================================================================
// Memory Instruction Tests
// ============================================================================

///|
test "memory kept when used by load instruction" {
  let type_sec = TypeSec::new([
    RecType::new(SubType::comp_type(CompType::func([], [ValType::i32()]))),
  ])
  let func_sec = FuncSec::new([TypeIdx::new(0)])
  let mem_sec = MemSec::new([MemType::new(Limits::i32(1, None))])
  let func_body = Func::t_func(
    [],
    TExpr::new([
      TInstr::return_([
        TInstr::load(
          LoadOp::i32_load(),
          MemArg::new(0, None, 0),
          TInstr::i32_const(I32(0)),
        ),
      ]),
    ]),
  )
  let code_sec = CodeSec::new([func_body])
  let export_sec = ExportSec::new([
    Export::new(Name::new("main"), ExternIdx::func(FuncIdx::new(0))),
  ])
  let mod = Module::new()
    .with_type_sec(type_sec)
    .with_func_sec(func_sec)
    .with_mem_sec(mem_sec)
    .with_code_sec(code_sec)
    .with_export_sec(export_sec)
  let result = remove_unused(mod)
  match result {
    Ok(new_mod) => {
      assert_true(new_mod.mem_sec is Some(_))
      assert_eq(new_mod.mem_sec.unwrap().0.length(), 1)
    }
    Err(e) => fail("unexpected error: \{e}")
  }
}

// ============================================================================
// GC Type Tests
// ============================================================================

///|
test "struct type kept when used" {
  let struct_type = RecType::new(
    SubType::comp_type(
      CompType::struct_([
        FieldType::new(StorageType::val_type(ValType::i32()), Const),
      ]),
    ),
  )
  let func_type = RecType::new(
    SubType::comp_type(
      CompType::func([], [
        ValType::ref_type(RefType::new(true, HeapType::new(TypeIdx::new(0)))),
      ]),
    ),
  )
  let type_sec = TypeSec::new([struct_type, func_type])
  let func_sec = FuncSec::new([TypeIdx::new(1)])
  let func_body = Func::t_func(
    [],
    TExpr::new([
      TInstr::return_([
        TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(42)]),
      ]),
    ]),
  )
  let code_sec = CodeSec::new([func_body])
  let export_sec = ExportSec::new([
    Export::new(Name::new("make_struct"), ExternIdx::func(FuncIdx::new(0))),
  ])
  let mod = Module::new()
    .with_type_sec(type_sec)
    .with_func_sec(func_sec)
    .with_code_sec(code_sec)
    .with_export_sec(export_sec)
  let result = remove_unused(mod)
  match result {
    Ok(new_mod) =>
      // Both types should be kept
      assert_eq(new_mod.type_sec.unwrap().0.length(), 2)
    Err(e) => fail("unexpected error: \{e}")
  }
}

// ============================================================================
// Call Indirect Tests
// ============================================================================

///|
test "call_indirect keeps type and table" {
  let type_sec = TypeSec::new([make_void_func_type()])
  let func_sec = FuncSec::new([TypeIdx::new(0)])
  let table_sec = TableSec::new([
    Table::new(
      TableType::new(
        RefType::new(true, HeapType::abs(AbsHeapType::func())),
        Limits::i32(1, None),
      ),
      None,
    ),
  ])
  let func_body = Func::t_func(
    [],
    TExpr::new([
      TInstr::call_indirect(
        TypeIdx::new(0),
        TableIdx::new(0),
        [],
        TInstr::i32_const(0),
      ),
      TInstr::return_([]),
    ]),
  )
  let code_sec = CodeSec::new([func_body])
  let export_sec = ExportSec::new([
    Export::new(Name::new("main"), ExternIdx::func(FuncIdx::new(0))),
  ])
  let mod = Module::new()
    .with_type_sec(type_sec)
    .with_func_sec(func_sec)
    .with_table_sec(table_sec)
    .with_code_sec(code_sec)
    .with_export_sec(export_sec)
  let result = remove_unused(mod)
  match result {
    Ok(new_mod) => {
      assert_true(new_mod.table_sec is Some(_))
      assert_eq(new_mod.table_sec.unwrap().0.length(), 1)
    }
    Err(e) => fail("unexpected error: \{e}")
  }
}

// ============================================================================
// Tag Tests (Exception Handling)
// ============================================================================

///|
test "tag kept when used in throw" {
  let func_type = make_void_func_type()
  let type_sec = TypeSec::new([func_type])
  let func_sec = FuncSec::new([TypeIdx::new(0)])
  let tag_sec = TagSec::new([TagType::new(TypeIdx::new(0))])
  let func_body = Func::t_func(
    [],
    TExpr::new([TInstr::throw_(TagIdx::new(0), [])]),
  )
  let code_sec = CodeSec::new([func_body])
  let export_sec = ExportSec::new([
    Export::new(Name::new("main"), ExternIdx::func(FuncIdx::new(0))),
  ])
  let mod = Module::new()
    .with_type_sec(type_sec)
    .with_func_sec(func_sec)
    .with_code_sec(code_sec)
    .with_export_sec(export_sec)
    .with_tag_sec(tag_sec)
  let result = remove_unused(mod)
  match result {
    Ok(new_mod) => {
      assert_true(new_mod.tag_sec is Some(_))
      assert_eq(new_mod.tag_sec.unwrap().0.length(), 1)
    }
    Err(e) => fail("unexpected error: \{e}")
  }
}

// ============================================================================
// Complex Remapping Tests
// ============================================================================

///|
test "multiple removals with complex remapping" {
  // Setup:
  // type 0: unused
  // type 1: used by func 0 -> remaps to type 0
  // type 2: unused  
  // type 3: used by func 2 -> remaps to type 1
  // func 0: unused
  // func 1: exported -> remaps to func 0
  // func 2: called by func 1 -> remaps to func 1

  let type_sec = TypeSec::new([
    make_i32_to_i32_func_type(), // 0: unused
    make_void_func_type(), // 1: used
    make_i32_to_i32_func_type(), // 2: unused
    make_void_func_type(), // 3: used
  ])
  let func_sec = FuncSec::new([
    TypeIdx::new(1), // func 0: uses type 1
    TypeIdx::new(1), // func 1: uses type 1
    TypeIdx::new(3), // func 2: uses type 3
  ])
  let func0_body = make_empty_func_body() // unused
  let func1_body = Func::t_func(
    [],
    TExpr::new([ // calls func 2
      TInstr::call(FuncIdx::new(2), []),
      TInstr::return_([]),
    ]),
  )
  let func2_body = make_empty_func_body()
  let code_sec = CodeSec::new([func0_body, func1_body, func2_body])
  let export_sec = ExportSec::new([
    Export::new(Name::new("main"), ExternIdx::func(FuncIdx::new(1))),
  ])
  let mod = Module::new()
    .with_type_sec(type_sec)
    .with_func_sec(func_sec)
    .with_code_sec(code_sec)
    .with_export_sec(export_sec)
  let result = remove_unused(mod)
  match result {
    Ok(new_mod) => {
      // Should have 2 types (type 1 and 3 -> remapped to 0 and 1)
      assert_eq(new_mod.type_sec.unwrap().0.length(), 2)

      // Should have 2 funcs (func 1 and 2 -> remapped to 0 and 1)
      assert_eq(new_mod.func_sec.unwrap().0.length(), 2)

      // Export should reference func 0
      let exports = new_mod.export_sec.unwrap().0
      match exports[0] {
        Export(_, FuncExternIdx(idx)) => {
          let FuncIdx(v) = idx
          assert_eq(v, 0)
        }
        _ => fail("expected function export")
      }
    }
    Err(e) => fail("unexpected error: \{e}")
  }
}

// ============================================================================
// Data Count Section Tests
// ============================================================================

///|
test "data count section updated correctly" {
  let type_sec = TypeSec::new([make_void_func_type()])
  let func_sec = FuncSec::new([TypeIdx::new(0)])
  let mem_sec = MemSec::new([MemType::new(Limits::i32(1, None))])

  // Create 3 data segments, only 1 is active
  let data_sec = DataSec::new([
    Data::new(DataMode::passive(), b"unused1"),
    Data::new(
      DataMode::active(MemIdx::new(0), Expr::new([Instruction::i32_const(0)])),
      b"used",
    ),
    Data::new(DataMode::passive(), b"unused2"),
  ])
  let code_sec = CodeSec::new([make_empty_func_body()])
  let export_sec = ExportSec::new([
    Export::new(Name::new("main"), ExternIdx::func(FuncIdx::new(0))),
  ])
  let data_cnt_sec = DataCntSec::new(3)
  let mod = Module::new()
    .with_type_sec(type_sec)
    .with_func_sec(func_sec)
    .with_mem_sec(mem_sec)
    .with_code_sec(code_sec)
    .with_export_sec(export_sec)
    .with_data_sec(data_sec)
    .with_data_cnt_sec(data_cnt_sec)
  let result = remove_unused(mod)
  match result {
    Ok(new_mod) => {
      // Only 1 data segment should remain
      assert_eq(new_mod.data_sec.unwrap().0.length(), 1)
      // Data count should be updated
      assert_eq(new_mod.data_cnt_sec.unwrap().0, 1)
    }
    Err(e) => fail("unexpected error: \{e}")
  }
}
