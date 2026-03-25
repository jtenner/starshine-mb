///|
pub fn rume_summary() -> String {
  "Remove unreachable defined functions, globals, tables, memories, tags, element segments, and data segments while rewriting surviving module indices."
}

///|
priv enum RumeItem {
  Func(UInt)
  Global(UInt)
  Table(UInt)
  Mem(UInt)
  Tag(UInt)
  Elem(UInt)
  Data(UInt)
}

///|
fn rume_imported_func_count(mod_ : @lib.Module) -> Int {
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
fn rume_imported_table_count(mod_ : @lib.Module) -> Int {
  let mut count = 0
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.TableExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
fn rume_imported_mem_count(mod_ : @lib.Module) -> Int {
  let mut count = 0
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.MemExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
fn rume_imported_global_count(mod_ : @lib.Module) -> Int {
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
fn rume_imported_tag_count(mod_ : @lib.Module) -> Int {
  let mut count = 0
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.TagExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
fn rume_defined_func_count(mod_ : @lib.Module) -> Int {
  match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) => type_idxs.length()
    None => 0
  }
}

///|
fn rume_defined_table_count(mod_ : @lib.Module) -> Int {
  match mod_.table_sec {
    Some(@lib.TableSec(tables)) => tables.length()
    None => 0
  }
}

///|
fn rume_defined_mem_count(mod_ : @lib.Module) -> Int {
  match mod_.mem_sec {
    Some(@lib.MemSec(mems)) => mems.length()
    None => 0
  }
}

///|
fn rume_defined_global_count(mod_ : @lib.Module) -> Int {
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) => globals.length()
    None => 0
  }
}

///|
fn rume_defined_tag_count(mod_ : @lib.Module) -> Int {
  match mod_.tag_sec {
    Some(@lib.TagSec(tags)) => tags.length()
    None => 0
  }
}

///|
fn rume_mark_func(
  queue : Array[RumeItem],
  used_funcs : Array[Bool],
  idx : @lib.FuncIdx,
) -> Unit {
  let @lib.FuncIdx(raw) = idx
  let slot = raw.reinterpret_as_int()
  if slot < 0 || slot >= used_funcs.length() || used_funcs[slot] {
    return
  }
  used_funcs[slot] = true
  queue.push(RumeItem::Func(raw))
}

///|
fn rume_mark_global(
  queue : Array[RumeItem],
  used_globals : Array[Bool],
  idx : @lib.GlobalIdx,
) -> Unit {
  let @lib.GlobalIdx(raw) = idx
  let slot = raw.reinterpret_as_int()
  if slot < 0 || slot >= used_globals.length() || used_globals[slot] {
    return
  }
  used_globals[slot] = true
  queue.push(RumeItem::Global(raw))
}

///|
fn rume_mark_table(
  queue : Array[RumeItem],
  used_tables : Array[Bool],
  idx : @lib.TableIdx,
) -> Unit {
  let @lib.TableIdx(raw) = idx
  let slot = raw.reinterpret_as_int()
  if slot < 0 || slot >= used_tables.length() || used_tables[slot] {
    return
  }
  used_tables[slot] = true
  queue.push(RumeItem::Table(raw))
}

///|
fn rume_mark_mem(
  queue : Array[RumeItem],
  used_mems : Array[Bool],
  idx : @lib.MemIdx,
) -> Unit {
  let @lib.MemIdx(raw) = idx
  let slot = raw.reinterpret_as_int()
  if slot < 0 || slot >= used_mems.length() || used_mems[slot] {
    return
  }
  used_mems[slot] = true
  queue.push(RumeItem::Mem(raw))
}

///|
fn rume_mark_tag(
  queue : Array[RumeItem],
  used_tags : Array[Bool],
  idx : @lib.TagIdx,
) -> Unit {
  let @lib.TagIdx(raw) = idx
  let slot = raw.reinterpret_as_int()
  if slot < 0 || slot >= used_tags.length() || used_tags[slot] {
    return
  }
  used_tags[slot] = true
  queue.push(RumeItem::Tag(raw))
}

///|
fn rume_mark_elem(
  queue : Array[RumeItem],
  used_elems : Array[Bool],
  idx : @lib.ElemIdx,
) -> Unit {
  let @lib.ElemIdx(raw) = idx
  let slot = raw.reinterpret_as_int()
  if slot < 0 || slot >= used_elems.length() || used_elems[slot] {
    return
  }
  used_elems[slot] = true
  queue.push(RumeItem::Elem(raw))
}

///|
fn rume_mark_data(
  queue : Array[RumeItem],
  used_datas : Array[Bool],
  idx : @lib.DataIdx,
) -> Unit {
  let @lib.DataIdx(raw) = idx
  let slot = raw.reinterpret_as_int()
  if slot < 0 || slot >= used_datas.length() || used_datas[slot] {
    return
  }
  used_datas[slot] = true
  queue.push(RumeItem::Data(raw))
}

///|
fn rume_mark_memarg(
  queue : Array[RumeItem],
  used_mems : Array[Bool],
  memarg : @lib.MemArg,
) -> Unit {
  let @lib.MemArg(_, mem_idx, _) = memarg
  match mem_idx {
    Some(idx) => rume_mark_mem(queue, used_mems, idx)
    None => rume_mark_mem(queue, used_mems, @lib.MemIdx::new(0U))
  }
}

///|
fn rume_scan_catches(
  catches : Array[@lib.Catch],
  queue : Array[RumeItem],
  used_tags : Array[Bool],
) -> Unit {
  for catch_ in catches {
    match catch_ {
      @lib.Catch(tag_idx, _) | @lib.CatchRef(tag_idx, _) =>
        rume_mark_tag(queue, used_tags, tag_idx)
      _ => ()
    }
  }
}

///|
fn rume_scan_expr(
  expr : @lib.Expr,
  queue : Array[RumeItem],
  used_funcs : Array[Bool],
  used_globals : Array[Bool],
  used_tables : Array[Bool],
  used_mems : Array[Bool],
  used_tags : Array[Bool],
  used_elems : Array[Bool],
  used_datas : Array[Bool],
) -> Unit {
  let @lib.Expr(instrs) = expr
  for instr in instrs {
    rume_scan_instruction(
      instr, queue, used_funcs, used_globals, used_tables, used_mems, used_tags,
      used_elems, used_datas,
    )
  }
}

///|
fn rume_scan_instruction(
  instr : @lib.Instruction,
  queue : Array[RumeItem],
  used_funcs : Array[Bool],
  used_globals : Array[Bool],
  used_tables : Array[Bool],
  used_mems : Array[Bool],
  used_tags : Array[Bool],
  used_elems : Array[Bool],
  used_datas : Array[Bool],
) -> Unit {
  match instr {
    @lib.Block(_, body) | @lib.Loop(_, body) =>
      rume_scan_expr(
        body, queue, used_funcs, used_globals, used_tables, used_mems, used_tags,
        used_elems, used_datas,
      )
    @lib.If(_, then_body, else_body) => {
      for nested in then_body {
        rume_scan_instruction(
          nested, queue, used_funcs, used_globals, used_tables, used_mems, used_tags,
          used_elems, used_datas,
        )
      }
      match else_body {
        Some(body) =>
          for nested in body {
            rume_scan_instruction(
              nested, queue, used_funcs, used_globals, used_tables, used_mems, used_tags,
              used_elems, used_datas,
            )
          }
        None => ()
      }
    }
    @lib.Call(func_idx) | @lib.ReturnCall(func_idx) | @lib.RefFunc(func_idx) =>
      rume_mark_func(queue, used_funcs, func_idx)
    @lib.CallIndirect(_, table_idx) | @lib.ReturnCallIndirect(_, table_idx) =>
      rume_mark_table(queue, used_tables, table_idx)
    @lib.Throw(tag_idx) => rume_mark_tag(queue, used_tags, tag_idx)
    @lib.TryTable(_, catches, body) => {
      rume_scan_catches(catches, queue, used_tags)
      rume_scan_expr(
        body, queue, used_funcs, used_globals, used_tables, used_mems, used_tags,
        used_elems, used_datas,
      )
    }
    @lib.GlobalGet(global_idx) | @lib.GlobalSet(global_idx) =>
      rume_mark_global(queue, used_globals, global_idx)
    @lib.TableGet(table_idx)
    | @lib.TableSet(table_idx)
    | @lib.TableGrow(table_idx)
    | @lib.TableSize(table_idx)
    | @lib.TableFill(table_idx) =>
      rume_mark_table(queue, used_tables, table_idx)
    @lib.TableInit(elem_idx, table_idx) => {
      rume_mark_elem(queue, used_elems, elem_idx)
      rume_mark_table(queue, used_tables, table_idx)
    }
    @lib.ElemDrop(elem_idx) => rume_mark_elem(queue, used_elems, elem_idx)
    @lib.TableCopy(dst, src) => {
      rume_mark_table(queue, used_tables, dst)
      rume_mark_table(queue, used_tables, src)
    }
    @lib.MemorySize(mem_idx)
    | @lib.MemoryGrow(mem_idx)
    | @lib.MemoryFill(mem_idx) => rume_mark_mem(queue, used_mems, mem_idx)
    @lib.MemoryInit(data_idx, mem_idx) => {
      rume_mark_data(queue, used_datas, data_idx)
      rume_mark_mem(queue, used_mems, mem_idx)
    }
    @lib.DataDrop(data_idx) => rume_mark_data(queue, used_datas, data_idx)
    @lib.MemoryCopy(dst, src) => {
      rume_mark_mem(queue, used_mems, dst)
      rume_mark_mem(queue, used_mems, src)
    }
    @lib.ArrayNewData(_, data_idx) | @lib.ArrayInitData(_, data_idx) =>
      rume_mark_data(queue, used_datas, data_idx)
    @lib.ArrayNewElem(_, elem_idx) | @lib.ArrayInitElem(_, elem_idx) =>
      rume_mark_elem(queue, used_elems, elem_idx)
    @lib.I32Load(memarg)
    | @lib.I64Load(memarg)
    | @lib.F32Load(memarg)
    | @lib.F64Load(memarg)
    | @lib.I32Load8S(memarg)
    | @lib.I32Load8U(memarg)
    | @lib.I32Load16S(memarg)
    | @lib.I32Load16U(memarg)
    | @lib.I64Load8S(memarg)
    | @lib.I64Load8U(memarg)
    | @lib.I64Load16S(memarg)
    | @lib.I64Load16U(memarg)
    | @lib.I64Load32S(memarg)
    | @lib.I64Load32U(memarg)
    | @lib.I32Store(memarg)
    | @lib.I64Store(memarg)
    | @lib.F32Store(memarg)
    | @lib.F64Store(memarg)
    | @lib.I32Store8(memarg)
    | @lib.I32Store16(memarg)
    | @lib.I64Store8(memarg)
    | @lib.I64Store16(memarg)
    | @lib.I64Store32(memarg)
    | @lib.MemoryAtomicNotify(memarg)
    | @lib.MemoryAtomicWait32(memarg)
    | @lib.MemoryAtomicWait64(memarg)
    | @lib.I32AtomicLoad(memarg)
    | @lib.I64AtomicLoad(memarg)
    | @lib.I32AtomicLoad8U(memarg)
    | @lib.I32AtomicLoad16U(memarg)
    | @lib.I64AtomicLoad8U(memarg)
    | @lib.I64AtomicLoad16U(memarg)
    | @lib.I64AtomicLoad32U(memarg)
    | @lib.I32AtomicStore(memarg)
    | @lib.I64AtomicStore(memarg)
    | @lib.I32AtomicStore8(memarg)
    | @lib.I32AtomicStore16(memarg)
    | @lib.I64AtomicStore8(memarg)
    | @lib.I64AtomicStore16(memarg)
    | @lib.I64AtomicStore32(memarg)
    | @lib.AtomicRmw(_, memarg)
    | @lib.AtomicCmpxchg(_, memarg)
    | @lib.V128Load(memarg)
    | @lib.V128Load8x8S(memarg)
    | @lib.V128Load8x8U(memarg)
    | @lib.V128Load16x4S(memarg)
    | @lib.V128Load16x4U(memarg)
    | @lib.V128Load32x2S(memarg)
    | @lib.V128Load32x2U(memarg)
    | @lib.V128Load8Splat(memarg)
    | @lib.V128Load16Splat(memarg)
    | @lib.V128Load32Splat(memarg)
    | @lib.V128Load64Splat(memarg)
    | @lib.V128Store(memarg)
    | @lib.V128Load8Lane(memarg, _)
    | @lib.V128Load16Lane(memarg, _)
    | @lib.V128Load32Lane(memarg, _)
    | @lib.V128Load64Lane(memarg, _)
    | @lib.V128Store8Lane(memarg, _)
    | @lib.V128Store16Lane(memarg, _)
    | @lib.V128Store32Lane(memarg, _)
    | @lib.V128Store64Lane(memarg, _)
    | @lib.V128Load32Zero(memarg)
    | @lib.V128Load64Zero(memarg) => rume_mark_memarg(queue, used_mems, memarg)
    _ => ()
  }
}

///|
fn rume_process_func(
  mod_ : @lib.Module,
  abs_idx : UInt,
  func_imports : Int,
  queue : Array[RumeItem],
  used_funcs : Array[Bool],
  used_globals : Array[Bool],
  used_tables : Array[Bool],
  used_mems : Array[Bool],
  used_tags : Array[Bool],
  used_elems : Array[Bool],
  used_datas : Array[Bool],
) -> Unit {
  let def_idx = abs_idx.reinterpret_as_int() - func_imports
  if def_idx < 0 {
    return
  }
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs.get(def_idx) {
        Some(@lib.Func(_, body)) =>
          rume_scan_expr(
            body, queue, used_funcs, used_globals, used_tables, used_mems, used_tags,
            used_elems, used_datas,
          )
        None => ()
      }
    None => ()
  }
}

///|
fn rume_process_global(
  mod_ : @lib.Module,
  abs_idx : UInt,
  global_imports : Int,
  queue : Array[RumeItem],
  used_funcs : Array[Bool],
  used_globals : Array[Bool],
  used_tables : Array[Bool],
  used_mems : Array[Bool],
  used_tags : Array[Bool],
  used_elems : Array[Bool],
  used_datas : Array[Bool],
) -> Unit {
  let def_idx = abs_idx.reinterpret_as_int() - global_imports
  if def_idx < 0 {
    return
  }
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) =>
      match globals.get(def_idx) {
        Some(@lib.Global(_, init)) =>
          rume_scan_expr(
            init, queue, used_funcs, used_globals, used_tables, used_mems, used_tags,
            used_elems, used_datas,
          )
        None => ()
      }
    None => ()
  }
}

///|
fn rume_process_table(
  mod_ : @lib.Module,
  abs_idx : UInt,
  table_imports : Int,
  queue : Array[RumeItem],
  used_funcs : Array[Bool],
  used_globals : Array[Bool],
  used_tables : Array[Bool],
  used_mems : Array[Bool],
  used_tags : Array[Bool],
  used_elems : Array[Bool],
  used_datas : Array[Bool],
) -> Unit {
  let def_idx = abs_idx.reinterpret_as_int() - table_imports
  if def_idx >= 0 {
    match mod_.table_sec {
      Some(@lib.TableSec(tables)) =>
        match tables.get(def_idx) {
          Some(@lib.Table(_, Some(init))) =>
            rume_scan_expr(
              init, queue, used_funcs, used_globals, used_tables, used_mems, used_tags,
              used_elems, used_datas,
            )
          _ => ()
        }
      None => ()
    }
  }
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) => {
      let mut elem_idx = 0
      while elem_idx < elems.length() {
        match elems[elem_idx] {
          @lib.Elem(@lib.Active(@lib.TableIdx(table_idx), _), _) =>
            if table_idx == abs_idx {
              rume_mark_elem(
                queue,
                used_elems,
                @lib.ElemIdx::new(elem_idx.reinterpret_as_uint()),
              )
            }
          _ => ()
        }
        elem_idx += 1
      }
    }
    None => ()
  }
}

///|
fn rume_process_mem(
  mod_ : @lib.Module,
  abs_idx : UInt,
  queue : Array[RumeItem],
  used_mems : Array[Bool],
  used_datas : Array[Bool],
) -> Unit {
  match mod_.data_sec {
    Some(@lib.DataSec(datas)) => {
      let mut data_idx = 0
      while data_idx < datas.length() {
        match datas[data_idx] {
          @lib.Data(@lib.Active(@lib.MemIdx(mem_idx), _), _) =>
            if mem_idx == abs_idx {
              rume_mark_data(
                queue,
                used_datas,
                @lib.DataIdx::new(data_idx.reinterpret_as_uint()),
              )
            }
          _ => ()
        }
        data_idx += 1
      }
    }
    None => ()
  }
  ignore(used_mems)
}

///|
fn rume_process_elem(
  mod_ : @lib.Module,
  elem_idx : UInt,
  queue : Array[RumeItem],
  used_funcs : Array[Bool],
  used_globals : Array[Bool],
  used_tables : Array[Bool],
  used_mems : Array[Bool],
  used_tags : Array[Bool],
  used_elems : Array[Bool],
  used_datas : Array[Bool],
) -> Unit {
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) =>
      match elems.get(elem_idx.reinterpret_as_int()) {
        Some(@lib.Elem(mode, kind)) => {
          match mode {
            @lib.Active(table_idx, offset) => {
              rume_mark_table(queue, used_tables, table_idx)
              rume_scan_expr(
                offset, queue, used_funcs, used_globals, used_tables, used_mems,
                used_tags, used_elems, used_datas,
              )
            }
            _ => ()
          }
          match kind {
            @lib.FuncsElemKind(funcs) =>
              for func_idx in funcs {
                rume_mark_func(queue, used_funcs, func_idx)
              }
            @lib.FuncExprsElemKind(exprs) | @lib.TypedExprsElemKind(_, exprs) =>
              for expr in exprs {
                rume_scan_expr(
                  expr, queue, used_funcs, used_globals, used_tables, used_mems,
                  used_tags, used_elems, used_datas,
                )
              }
          }
        }
        None => ()
      }
    None => ()
  }
}

///|
fn rume_process_data(
  mod_ : @lib.Module,
  data_idx : UInt,
  queue : Array[RumeItem],
  used_funcs : Array[Bool],
  used_globals : Array[Bool],
  used_tables : Array[Bool],
  used_mems : Array[Bool],
  used_tags : Array[Bool],
  used_elems : Array[Bool],
  used_datas : Array[Bool],
) -> Unit {
  match mod_.data_sec {
    Some(@lib.DataSec(datas)) =>
      match datas.get(data_idx.reinterpret_as_int()) {
        Some(@lib.Data(@lib.Active(mem_idx, offset), _)) => {
          rume_mark_mem(queue, used_mems, mem_idx)
          rume_scan_expr(
            offset, queue, used_funcs, used_globals, used_tables, used_mems, used_tags,
            used_elems, used_datas,
          )
        }
        _ => ()
      }
    None => ()
  }
}

///|
fn rume_collect_liveness(
  mod_ : @lib.Module,
) -> (
  Array[Bool],
  Array[Bool],
  Array[Bool],
  Array[Bool],
  Array[Bool],
  Array[Bool],
  Array[Bool],
) {
  let func_imports = rume_imported_func_count(mod_)
  let table_imports = rume_imported_table_count(mod_)
  let mem_imports = rume_imported_mem_count(mod_)
  let global_imports = rume_imported_global_count(mod_)
  let tag_imports = rume_imported_tag_count(mod_)
  let used_funcs = Array::make(
    func_imports + rume_defined_func_count(mod_),
    false,
  )
  let used_tables = Array::make(
    table_imports + rume_defined_table_count(mod_),
    false,
  )
  let used_mems = Array::make(mem_imports + rume_defined_mem_count(mod_), false)
  let used_globals = Array::make(
    global_imports + rume_defined_global_count(mod_),
    false,
  )
  let used_tags = Array::make(tag_imports + rume_defined_tag_count(mod_), false)
  let used_elems = Array::make(
    match mod_.elem_sec {
      Some(@lib.ElemSec(elems)) => elems.length()
      None => 0
    },
    false,
  )
  let used_datas = Array::make(
    match mod_.data_sec {
      Some(@lib.DataSec(datas)) => datas.length()
      None => 0
    },
    false,
  )
  let queue : Array[RumeItem] = []

  match mod_.start_sec {
    Some(@lib.StartSec(func_idx)) => rume_mark_func(queue, used_funcs, func_idx)
    None => ()
  }
  match mod_.export_sec {
    Some(@lib.ExportSec(exports)) =>
      for export_ in exports {
        let @lib.Export(_, idx) = export_
        match idx {
          @lib.FuncExternIdx(func_idx) =>
            rume_mark_func(queue, used_funcs, func_idx)
          @lib.GlobalExternIdx(global_idx) =>
            rume_mark_global(queue, used_globals, global_idx)
          @lib.TableExternIdx(table_idx) =>
            rume_mark_table(queue, used_tables, table_idx)
          @lib.MemExternIdx(mem_idx) => rume_mark_mem(queue, used_mems, mem_idx)
          @lib.TagExternIdx(tag_idx) => rume_mark_tag(queue, used_tags, tag_idx)
        }
      }
    None => ()
  }
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) => {
      let mut elem_idx = 0
      while elem_idx < elems.length() {
        match elems[elem_idx] {
          @lib.Elem(@lib.Active(@lib.TableIdx(table_idx), _), _) =>
            if table_idx.reinterpret_as_int() < table_imports {
              rume_mark_elem(
                queue,
                used_elems,
                @lib.ElemIdx::new(elem_idx.reinterpret_as_uint()),
              )
            }
          _ => ()
        }
        elem_idx += 1
      }
    }
    None => ()
  }
  match mod_.data_sec {
    Some(@lib.DataSec(datas)) => {
      let mut data_idx = 0
      while data_idx < datas.length() {
        match datas[data_idx] {
          @lib.Data(@lib.Active(@lib.MemIdx(mem_idx), _), _) =>
            if mem_idx.reinterpret_as_int() < mem_imports {
              rume_mark_data(
                queue,
                used_datas,
                @lib.DataIdx::new(data_idx.reinterpret_as_uint()),
              )
            }
          _ => ()
        }
        data_idx += 1
      }
    }
    None => ()
  }

  let mut cursor = 0
  while cursor < queue.length() {
    match queue[cursor] {
      RumeItem::Func(abs_idx) =>
        rume_process_func(
          mod_, abs_idx, func_imports, queue, used_funcs, used_globals, used_tables,
          used_mems, used_tags, used_elems, used_datas,
        )
      RumeItem::Global(abs_idx) =>
        rume_process_global(
          mod_, abs_idx, global_imports, queue, used_funcs, used_globals, used_tables,
          used_mems, used_tags, used_elems, used_datas,
        )
      RumeItem::Table(abs_idx) =>
        rume_process_table(
          mod_, abs_idx, table_imports, queue, used_funcs, used_globals, used_tables,
          used_mems, used_tags, used_elems, used_datas,
        )
      RumeItem::Mem(abs_idx) =>
        rume_process_mem(mod_, abs_idx, queue, used_mems, used_datas)
      RumeItem::Tag(_) => ()
      RumeItem::Elem(elem_idx) =>
        rume_process_elem(
          mod_, elem_idx, queue, used_funcs, used_globals, used_tables, used_mems,
          used_tags, used_elems, used_datas,
        )
      RumeItem::Data(data_idx) =>
        rume_process_data(
          mod_, data_idx, queue, used_funcs, used_globals, used_tables, used_mems,
          used_tags, used_elems, used_datas,
        )
    }
    cursor += 1
  }

  (
    used_funcs, used_globals, used_tables, used_mems, used_tags, used_elems, used_datas,
  )
}

///|
fn rume_build_abs_remap(
  imported_count : Int,
  kept_defined : Array[Bool],
) -> Array[Int] {
  let remap = Array::make(imported_count + kept_defined.length(), -1)
  let mut next_abs = 0
  while next_abs < imported_count {
    remap[next_abs] = next_abs
    next_abs += 1
  }
  let mut def_idx = 0
  while def_idx < kept_defined.length() {
    let abs_idx = imported_count + def_idx
    if kept_defined[def_idx] {
      remap[abs_idx] = next_abs
      next_abs += 1
    }
    def_idx += 1
  }
  remap
}

///|
fn rume_build_defined_remap(kept : Array[Bool]) -> Array[Int] {
  let remap = Array::make(kept.length(), -1)
  let mut next_idx = 0
  let mut idx = 0
  while idx < kept.length() {
    if kept[idx] {
      remap[idx] = next_idx
      next_idx += 1
    }
    idx += 1
  }
  remap
}

///|
fn rume_kept_defined_from_used(
  used : Array[Bool],
  imported_count : Int,
) -> Array[Bool] {
  let kept = Array::make(used.length() - imported_count, false)
  let mut idx = imported_count
  while idx < used.length() {
    kept[idx - imported_count] = used[idx]
    idx += 1
  }
  kept
}

///|
fn rume_rewrite_abs(raw : UInt, remap : Array[Int]) -> UInt {
  remap[raw.reinterpret_as_int()].reinterpret_as_uint()
}

///|
fn rume_rewrite_func_idx(
  idx : @lib.FuncIdx,
  remap : Array[Int],
) -> @lib.FuncIdx {
  let @lib.FuncIdx(raw) = idx
  @lib.FuncIdx::new(rume_rewrite_abs(raw, remap))
}

///|
fn rume_rewrite_global_idx(
  idx : @lib.GlobalIdx,
  remap : Array[Int],
) -> @lib.GlobalIdx {
  let @lib.GlobalIdx(raw) = idx
  @lib.GlobalIdx::new(rume_rewrite_abs(raw, remap))
}

///|
fn rume_rewrite_table_idx(
  idx : @lib.TableIdx,
  remap : Array[Int],
) -> @lib.TableIdx {
  let @lib.TableIdx(raw) = idx
  @lib.TableIdx::new(rume_rewrite_abs(raw, remap))
}

///|
fn rume_rewrite_mem_idx(idx : @lib.MemIdx, remap : Array[Int]) -> @lib.MemIdx {
  let @lib.MemIdx(raw) = idx
  @lib.MemIdx::new(rume_rewrite_abs(raw, remap))
}

///|
fn rume_rewrite_tag_idx(idx : @lib.TagIdx, remap : Array[Int]) -> @lib.TagIdx {
  let @lib.TagIdx(raw) = idx
  @lib.TagIdx::new(rume_rewrite_abs(raw, remap))
}

///|
fn rume_rewrite_elem_idx(
  idx : @lib.ElemIdx,
  remap : Array[Int],
) -> @lib.ElemIdx {
  let @lib.ElemIdx(raw) = idx
  @lib.ElemIdx::new(remap[raw.reinterpret_as_int()].reinterpret_as_uint())
}

///|
fn rume_rewrite_data_idx(
  idx : @lib.DataIdx,
  remap : Array[Int],
) -> @lib.DataIdx {
  let @lib.DataIdx(raw) = idx
  @lib.DataIdx::new(remap[raw.reinterpret_as_int()].reinterpret_as_uint())
}

///|
fn rume_rewrite_catch(
  catch_ : @lib.Catch,
  tag_remap : Array[Int],
) -> @lib.Catch {
  match catch_ {
    @lib.Catch(tag_idx, label_idx) =>
      @lib.Catch::new(rume_rewrite_tag_idx(tag_idx, tag_remap), label_idx)
    @lib.CatchRef(tag_idx, label_idx) =>
      @lib.Catch::ref_(rume_rewrite_tag_idx(tag_idx, tag_remap), label_idx)
    _ => catch_
  }
}

///|
fn rume_rewrite_memarg(
  memarg : @lib.MemArg,
  mem_remap : Array[Int],
) -> @lib.MemArg {
  let @lib.MemArg(align, mem_idx, offset) = memarg
  @lib.MemArg::new(
    align,
    match mem_idx {
      Some(idx) => Some(rume_rewrite_mem_idx(idx, mem_remap))
      None => None
    },
    offset,
  )
}

///|
fn rume_rewrite_instruction(
  instr : @lib.Instruction,
  func_remap : Array[Int],
  global_remap : Array[Int],
  table_remap : Array[Int],
  mem_remap : Array[Int],
  tag_remap : Array[Int],
  elem_remap : Array[Int],
  data_remap : Array[Int],
) -> @lib.Instruction {
  match instr {
    @lib.Block(block_type, body) =>
      @lib.Instruction::block(
        block_type,
        rume_rewrite_expr(
          body, func_remap, global_remap, table_remap, mem_remap, tag_remap, elem_remap,
          data_remap,
        ),
      )
    @lib.Loop(block_type, body) =>
      @lib.Instruction::loop_(
        block_type,
        rume_rewrite_expr(
          body, func_remap, global_remap, table_remap, mem_remap, tag_remap, elem_remap,
          data_remap,
        ),
      )
    @lib.If(block_type, then_body, else_body) => {
      let rewritten_then : Array[@lib.Instruction] = []
      for nested in then_body {
        rewritten_then.push(
          rume_rewrite_instruction(
            nested, func_remap, global_remap, table_remap, mem_remap, tag_remap,
            elem_remap, data_remap,
          ),
        )
      }
      let rewritten_else = match else_body {
        Some(body) => {
          let rewritten : Array[@lib.Instruction] = []
          for nested in body {
            rewritten.push(
              rume_rewrite_instruction(
                nested, func_remap, global_remap, table_remap, mem_remap, tag_remap,
                elem_remap, data_remap,
              ),
            )
          }
          Some(rewritten)
        }
        None => None
      }
      @lib.Instruction::if_(block_type, rewritten_then, rewritten_else)
    }
    @lib.Call(func_idx) =>
      @lib.Instruction::call(rume_rewrite_func_idx(func_idx, func_remap))
    @lib.CallIndirect(type_idx, table_idx) =>
      @lib.Instruction::call_indirect(
        type_idx,
        rume_rewrite_table_idx(table_idx, table_remap),
      )
    @lib.ReturnCall(func_idx) =>
      @lib.Instruction::return_call(rume_rewrite_func_idx(func_idx, func_remap))
    @lib.ReturnCallIndirect(type_idx, table_idx) =>
      @lib.Instruction::return_call_indirect(
        type_idx,
        rume_rewrite_table_idx(table_idx, table_remap),
      )
    @lib.Throw(tag_idx) =>
      @lib.Instruction::throw_(rume_rewrite_tag_idx(tag_idx, tag_remap))
    @lib.TryTable(block_type, catches, body) => {
      let rewritten_catches : Array[@lib.Catch] = []
      for catch_ in catches {
        rewritten_catches.push(rume_rewrite_catch(catch_, tag_remap))
      }
      @lib.Instruction::try_table(
        block_type,
        rewritten_catches,
        rume_rewrite_expr(
          body, func_remap, global_remap, table_remap, mem_remap, tag_remap, elem_remap,
          data_remap,
        ),
      )
    }
    @lib.GlobalGet(global_idx) =>
      @lib.Instruction::global_get(
        rume_rewrite_global_idx(global_idx, global_remap),
      )
    @lib.GlobalSet(global_idx) =>
      @lib.Instruction::global_set(
        rume_rewrite_global_idx(global_idx, global_remap),
      )
    @lib.TableGet(table_idx) =>
      @lib.Instruction::table_get(
        rume_rewrite_table_idx(table_idx, table_remap),
      )
    @lib.TableSet(table_idx) =>
      @lib.Instruction::table_set(
        rume_rewrite_table_idx(table_idx, table_remap),
      )
    @lib.I32Load(memarg) =>
      @lib.Instruction::i32_load(rume_rewrite_memarg(memarg, mem_remap))
    @lib.I64Load(memarg) =>
      @lib.Instruction::i64_load(rume_rewrite_memarg(memarg, mem_remap))
    @lib.F32Load(memarg) =>
      @lib.Instruction::f32_load(rume_rewrite_memarg(memarg, mem_remap))
    @lib.F64Load(memarg) =>
      @lib.Instruction::f64_load(rume_rewrite_memarg(memarg, mem_remap))
    @lib.I32Load8S(memarg) =>
      @lib.Instruction::i32_load8s(rume_rewrite_memarg(memarg, mem_remap))
    @lib.I32Load8U(memarg) =>
      @lib.Instruction::i32_load8u(rume_rewrite_memarg(memarg, mem_remap))
    @lib.I32Load16S(memarg) =>
      @lib.Instruction::i32_load16s(rume_rewrite_memarg(memarg, mem_remap))
    @lib.I32Load16U(memarg) =>
      @lib.Instruction::i32_load16u(rume_rewrite_memarg(memarg, mem_remap))
    @lib.I64Load8S(memarg) =>
      @lib.Instruction::i64_load8s(rume_rewrite_memarg(memarg, mem_remap))
    @lib.I64Load8U(memarg) =>
      @lib.Instruction::i64_load8u(rume_rewrite_memarg(memarg, mem_remap))
    @lib.I64Load16S(memarg) =>
      @lib.Instruction::i64_load16s(rume_rewrite_memarg(memarg, mem_remap))
    @lib.I64Load16U(memarg) =>
      @lib.Instruction::i64_load16u(rume_rewrite_memarg(memarg, mem_remap))
    @lib.I64Load32S(memarg) =>
      @lib.Instruction::i64_load32s(rume_rewrite_memarg(memarg, mem_remap))
    @lib.I64Load32U(memarg) =>
      @lib.Instruction::i64_load32u(rume_rewrite_memarg(memarg, mem_remap))
    @lib.I32Store(memarg) =>
      @lib.Instruction::i32_store(rume_rewrite_memarg(memarg, mem_remap))
    @lib.I64Store(memarg) =>
      @lib.Instruction::i64_store(rume_rewrite_memarg(memarg, mem_remap))
    @lib.F32Store(memarg) =>
      @lib.Instruction::f32_store(rume_rewrite_memarg(memarg, mem_remap))
    @lib.F64Store(memarg) =>
      @lib.Instruction::f64_store(rume_rewrite_memarg(memarg, mem_remap))
    @lib.I32Store8(memarg) =>
      @lib.Instruction::i32_store8(rume_rewrite_memarg(memarg, mem_remap))
    @lib.I32Store16(memarg) =>
      @lib.Instruction::i32_store16(rume_rewrite_memarg(memarg, mem_remap))
    @lib.I64Store8(memarg) =>
      @lib.Instruction::i64_store8(rume_rewrite_memarg(memarg, mem_remap))
    @lib.I64Store16(memarg) =>
      @lib.Instruction::i64_store16(rume_rewrite_memarg(memarg, mem_remap))
    @lib.I64Store32(memarg) =>
      @lib.Instruction::i64_store32(rume_rewrite_memarg(memarg, mem_remap))
    @lib.MemorySize(mem_idx) =>
      @lib.Instruction::memory_size(rume_rewrite_mem_idx(mem_idx, mem_remap))
    @lib.MemoryGrow(mem_idx) =>
      @lib.Instruction::memory_grow(rume_rewrite_mem_idx(mem_idx, mem_remap))
    @lib.MemoryAtomicNotify(memarg) =>
      @lib.Instruction::memory_atomic_notify(
        rume_rewrite_memarg(memarg, mem_remap),
      )
    @lib.MemoryAtomicWait32(memarg) =>
      @lib.Instruction::memory_atomic_wait32(
        rume_rewrite_memarg(memarg, mem_remap),
      )
    @lib.MemoryAtomicWait64(memarg) =>
      @lib.Instruction::memory_atomic_wait64(
        rume_rewrite_memarg(memarg, mem_remap),
      )
    @lib.I32AtomicLoad(memarg) =>
      @lib.Instruction::i32_atomic_load(rume_rewrite_memarg(memarg, mem_remap))
    @lib.I64AtomicLoad(memarg) =>
      @lib.Instruction::i64_atomic_load(rume_rewrite_memarg(memarg, mem_remap))
    @lib.I32AtomicLoad8U(memarg) =>
      @lib.Instruction::i32_atomic_load8_u(
        rume_rewrite_memarg(memarg, mem_remap),
      )
    @lib.I32AtomicLoad16U(memarg) =>
      @lib.Instruction::i32_atomic_load16_u(
        rume_rewrite_memarg(memarg, mem_remap),
      )
    @lib.I64AtomicLoad8U(memarg) =>
      @lib.Instruction::i64_atomic_load8_u(
        rume_rewrite_memarg(memarg, mem_remap),
      )
    @lib.I64AtomicLoad16U(memarg) =>
      @lib.Instruction::i64_atomic_load16_u(
        rume_rewrite_memarg(memarg, mem_remap),
      )
    @lib.I64AtomicLoad32U(memarg) =>
      @lib.Instruction::i64_atomic_load32_u(
        rume_rewrite_memarg(memarg, mem_remap),
      )
    @lib.I32AtomicStore(memarg) =>
      @lib.Instruction::i32_atomic_store(rume_rewrite_memarg(memarg, mem_remap))
    @lib.I64AtomicStore(memarg) =>
      @lib.Instruction::i64_atomic_store(rume_rewrite_memarg(memarg, mem_remap))
    @lib.I32AtomicStore8(memarg) =>
      @lib.Instruction::i32_atomic_store8(
        rume_rewrite_memarg(memarg, mem_remap),
      )
    @lib.I32AtomicStore16(memarg) =>
      @lib.Instruction::i32_atomic_store16(
        rume_rewrite_memarg(memarg, mem_remap),
      )
    @lib.I64AtomicStore8(memarg) =>
      @lib.Instruction::i64_atomic_store8(
        rume_rewrite_memarg(memarg, mem_remap),
      )
    @lib.I64AtomicStore16(memarg) =>
      @lib.Instruction::i64_atomic_store16(
        rume_rewrite_memarg(memarg, mem_remap),
      )
    @lib.I64AtomicStore32(memarg) =>
      @lib.Instruction::i64_atomic_store32(
        rume_rewrite_memarg(memarg, mem_remap),
      )
    @lib.AtomicRmw(op, memarg) =>
      @lib.Instruction::atomic_rmw(op, rume_rewrite_memarg(memarg, mem_remap))
    @lib.AtomicCmpxchg(op, memarg) =>
      @lib.Instruction::atomic_cmpxchg(
        op,
        rume_rewrite_memarg(memarg, mem_remap),
      )
    @lib.RefFunc(func_idx) =>
      @lib.Instruction::ref_func(rume_rewrite_func_idx(func_idx, func_remap))
    @lib.ArrayNewData(type_idx, data_idx) =>
      @lib.Instruction::array_new_data(
        type_idx,
        rume_rewrite_data_idx(data_idx, data_remap),
      )
    @lib.ArrayNewElem(type_idx, elem_idx) =>
      @lib.Instruction::array_new_elem(
        type_idx,
        rume_rewrite_elem_idx(elem_idx, elem_remap),
      )
    @lib.ArrayInitData(type_idx, data_idx) =>
      @lib.Instruction::array_init_data(
        type_idx,
        rume_rewrite_data_idx(data_idx, data_remap),
      )
    @lib.ArrayInitElem(type_idx, elem_idx) =>
      @lib.Instruction::array_init_elem(
        type_idx,
        rume_rewrite_elem_idx(elem_idx, elem_remap),
      )
    @lib.MemoryInit(data_idx, mem_idx) =>
      @lib.Instruction::memory_init(
        rume_rewrite_data_idx(data_idx, data_remap),
        rume_rewrite_mem_idx(mem_idx, mem_remap),
      )
    @lib.DataDrop(data_idx) =>
      @lib.Instruction::data_drop(rume_rewrite_data_idx(data_idx, data_remap))
    @lib.MemoryCopy(dst, src) =>
      @lib.Instruction::memory_copy(
        rume_rewrite_mem_idx(dst, mem_remap),
        rume_rewrite_mem_idx(src, mem_remap),
      )
    @lib.MemoryFill(mem_idx) =>
      @lib.Instruction::memory_fill(rume_rewrite_mem_idx(mem_idx, mem_remap))
    @lib.TableInit(elem_idx, table_idx) =>
      @lib.Instruction::table_init(
        rume_rewrite_elem_idx(elem_idx, elem_remap),
        rume_rewrite_table_idx(table_idx, table_remap),
      )
    @lib.ElemDrop(elem_idx) =>
      @lib.Instruction::elem_drop(rume_rewrite_elem_idx(elem_idx, elem_remap))
    @lib.TableCopy(dst, src) =>
      @lib.Instruction::table_copy(
        rume_rewrite_table_idx(dst, table_remap),
        rume_rewrite_table_idx(src, table_remap),
      )
    @lib.TableGrow(table_idx) =>
      @lib.Instruction::table_grow(
        rume_rewrite_table_idx(table_idx, table_remap),
      )
    @lib.TableSize(table_idx) =>
      @lib.Instruction::table_size(
        rume_rewrite_table_idx(table_idx, table_remap),
      )
    @lib.TableFill(table_idx) =>
      @lib.Instruction::table_fill(
        rume_rewrite_table_idx(table_idx, table_remap),
      )
    @lib.V128Load(memarg) =>
      @lib.Instruction::v128_load(rume_rewrite_memarg(memarg, mem_remap))
    @lib.V128Load8x8S(memarg) =>
      @lib.Instruction::v128_load8x8s(rume_rewrite_memarg(memarg, mem_remap))
    @lib.V128Load8x8U(memarg) =>
      @lib.Instruction::v128_load8x8u(rume_rewrite_memarg(memarg, mem_remap))
    @lib.V128Load16x4S(memarg) =>
      @lib.Instruction::v128_load16x4s(rume_rewrite_memarg(memarg, mem_remap))
    @lib.V128Load16x4U(memarg) =>
      @lib.Instruction::v128_load16x4u(rume_rewrite_memarg(memarg, mem_remap))
    @lib.V128Load32x2S(memarg) =>
      @lib.Instruction::v128_load32x2s(rume_rewrite_memarg(memarg, mem_remap))
    @lib.V128Load32x2U(memarg) =>
      @lib.Instruction::v128_load32x2u(rume_rewrite_memarg(memarg, mem_remap))
    @lib.V128Load8Splat(memarg) =>
      @lib.Instruction::v128_load8_splat(rume_rewrite_memarg(memarg, mem_remap))
    @lib.V128Load16Splat(memarg) =>
      @lib.Instruction::v128_load16_splat(
        rume_rewrite_memarg(memarg, mem_remap),
      )
    @lib.V128Load32Splat(memarg) =>
      @lib.Instruction::v128_load32_splat(
        rume_rewrite_memarg(memarg, mem_remap),
      )
    @lib.V128Load64Splat(memarg) =>
      @lib.Instruction::v128_load64_splat(
        rume_rewrite_memarg(memarg, mem_remap),
      )
    @lib.V128Store(memarg) =>
      @lib.Instruction::v128_store(rume_rewrite_memarg(memarg, mem_remap))
    @lib.V128Load8Lane(memarg, lane_idx) =>
      @lib.Instruction::v128_load8_lane(
        rume_rewrite_memarg(memarg, mem_remap),
        lane_idx,
      )
    @lib.V128Load16Lane(memarg, lane_idx) =>
      @lib.Instruction::v128_load16_lane(
        rume_rewrite_memarg(memarg, mem_remap),
        lane_idx,
      )
    @lib.V128Load32Lane(memarg, lane_idx) =>
      @lib.Instruction::v128_load32_lane(
        rume_rewrite_memarg(memarg, mem_remap),
        lane_idx,
      )
    @lib.V128Load64Lane(memarg, lane_idx) =>
      @lib.Instruction::v128_load64_lane(
        rume_rewrite_memarg(memarg, mem_remap),
        lane_idx,
      )
    @lib.V128Store8Lane(memarg, lane_idx) =>
      @lib.Instruction::v128_store8_lane(
        rume_rewrite_memarg(memarg, mem_remap),
        lane_idx,
      )
    @lib.V128Store16Lane(memarg, lane_idx) =>
      @lib.Instruction::v128_store16_lane(
        rume_rewrite_memarg(memarg, mem_remap),
        lane_idx,
      )
    @lib.V128Store32Lane(memarg, lane_idx) =>
      @lib.Instruction::v128_store32_lane(
        rume_rewrite_memarg(memarg, mem_remap),
        lane_idx,
      )
    @lib.V128Store64Lane(memarg, lane_idx) =>
      @lib.Instruction::v128_store64_lane(
        rume_rewrite_memarg(memarg, mem_remap),
        lane_idx,
      )
    @lib.V128Load32Zero(memarg) =>
      @lib.Instruction::v128_load32_zero(rume_rewrite_memarg(memarg, mem_remap))
    @lib.V128Load64Zero(memarg) =>
      @lib.Instruction::v128_load64_zero(rume_rewrite_memarg(memarg, mem_remap))
    _ => instr
  }
}

///|
fn rume_rewrite_expr(
  expr : @lib.Expr,
  func_remap : Array[Int],
  global_remap : Array[Int],
  table_remap : Array[Int],
  mem_remap : Array[Int],
  tag_remap : Array[Int],
  elem_remap : Array[Int],
  data_remap : Array[Int],
) -> @lib.Expr {
  let @lib.Expr(instrs) = expr
  let rewritten : Array[@lib.Instruction] = Array::new(capacity=instrs.length())
  for instr in instrs {
    rewritten.push(
      rume_rewrite_instruction(
        instr, func_remap, global_remap, table_remap, mem_remap, tag_remap, elem_remap,
        data_remap,
      ),
    )
  }
  @lib.Expr::new(rewritten)
}

///|
fn rume_rewrite_elem_kind(
  kind : @lib.ElemKind,
  func_remap : Array[Int],
  global_remap : Array[Int],
  table_remap : Array[Int],
  mem_remap : Array[Int],
  tag_remap : Array[Int],
  elem_remap : Array[Int],
  data_remap : Array[Int],
) -> @lib.ElemKind {
  match kind {
    @lib.FuncsElemKind(funcs) => {
      let rewritten : Array[@lib.FuncIdx] = []
      for func_idx in funcs {
        rewritten.push(rume_rewrite_func_idx(func_idx, func_remap))
      }
      @lib.ElemKind::funcs(rewritten)
    }
    @lib.FuncExprsElemKind(exprs) => {
      let rewritten : Array[@lib.Expr] = []
      for expr in exprs {
        rewritten.push(
          rume_rewrite_expr(
            expr, func_remap, global_remap, table_remap, mem_remap, tag_remap, elem_remap,
            data_remap,
          ),
        )
      }
      @lib.ElemKind::func_exprs(rewritten)
    }
    @lib.TypedExprsElemKind(ref_type, exprs) => {
      let rewritten : Array[@lib.Expr] = []
      for expr in exprs {
        rewritten.push(
          rume_rewrite_expr(
            expr, func_remap, global_remap, table_remap, mem_remap, tag_remap, elem_remap,
            data_remap,
          ),
        )
      }
      @lib.ElemKind::typed_exprs(ref_type, rewritten)
    }
  }
}

///|
fn rume_rewrite_name_map(
  names : @lib.NameMap?,
  remap : Array[Int],
) -> @lib.NameMap? {
  match names {
    Some(@lib.NameMap(entries)) => {
      let rewritten : Array[@lib.NameAssoc] = []
      for entry in entries {
        let @lib.NameAssoc(idx, name) = entry
        let slot = idx.reinterpret_as_int()
        if slot >= 0 && slot < remap.length() && remap[slot] >= 0 {
          rewritten.push(
            @lib.NameAssoc::new(remap[slot].reinterpret_as_uint(), name),
          )
        }
      }
      if rewritten.is_empty() {
        None
      } else {
        Some(@lib.NameMap::new(rewritten))
      }
    }
    None => None
  }
}

///|
fn rume_rewrite_indirect_name_map(
  names : @lib.IndirectNameMap?,
  remap : Array[Int],
) -> @lib.IndirectNameMap? {
  match names {
    Some(@lib.IndirectNameMap(entries)) => {
      let rewritten : Array[@lib.IndirectNameAssoc] = []
      for entry in entries {
        let @lib.IndirectNameAssoc(idx, inner) = entry
        let slot = idx.reinterpret_as_int()
        if slot >= 0 && slot < remap.length() && remap[slot] >= 0 {
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
        Some(@lib.IndirectNameMap::new(rewritten))
      }
    }
    None => None
  }
}

///|
fn rume_rewrite_name_sec(
  name_sec : @lib.NameSec?,
  func_remap : Array[Int],
  table_remap : Array[Int],
  mem_remap : Array[Int],
  global_remap : Array[Int],
  elem_remap : Array[Int],
  data_remap : Array[Int],
  tag_remap : Array[Int],
) -> @lib.NameSec? {
  match name_sec {
    Some(sec) => {
      let {
        module_name,
        func_names,
        local_names,
        label_names,
        type_names,
        table_names,
        memory_names,
        global_names,
        elem_names,
        data_names,
        field_names,
        tag_names,
      } = sec
      let next = @lib.NameSec::new(
        module_name~,
        func_names=rume_rewrite_name_map(func_names, func_remap),
        local_names=rume_rewrite_indirect_name_map(local_names, func_remap),
        label_names=rume_rewrite_indirect_name_map(label_names, func_remap),
        type_names~,
        table_names=rume_rewrite_name_map(table_names, table_remap),
        memory_names=rume_rewrite_name_map(memory_names, mem_remap),
        global_names=rume_rewrite_name_map(global_names, global_remap),
        elem_names=rume_rewrite_name_map(elem_names, elem_remap),
        data_names=rume_rewrite_name_map(data_names, data_remap),
        field_names~,
        tag_names=rume_rewrite_name_map(tag_names, tag_remap),
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
fn rume_rewrite_func_annotation_sec(
  sec : @lib.FuncAnnotationSec?,
  func_remap : Array[Int],
) -> @lib.FuncAnnotationSec? {
  match sec {
    Some(@lib.FuncAnnotationSec(entries)) => {
      let rewritten : Array[@lib.FuncAnnotationAssoc] = []
      for entry in entries {
        let @lib.FuncAnnotationAssoc(idx, annotations) = entry
        let slot = idx.reinterpret_as_int()
        if slot >= 0 && slot < func_remap.length() && func_remap[slot] >= 0 {
          rewritten.push(
            @lib.FuncAnnotationAssoc::new(
              func_remap[slot].reinterpret_as_uint(),
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
fn rume_apply_module_rewrite(
  mod_ : @lib.Module,
  used_funcs : Array[Bool],
  used_globals : Array[Bool],
  used_tables : Array[Bool],
  used_mems : Array[Bool],
  used_tags : Array[Bool],
  used_elems : Array[Bool],
  used_datas : Array[Bool],
) -> @lib.Module {
  let func_imports = rume_imported_func_count(mod_)
  let global_imports = rume_imported_global_count(mod_)
  let table_imports = rume_imported_table_count(mod_)
  let mem_imports = rume_imported_mem_count(mod_)
  let tag_imports = rume_imported_tag_count(mod_)
  let kept_funcs = rume_kept_defined_from_used(used_funcs, func_imports)
  let kept_globals = rume_kept_defined_from_used(used_globals, global_imports)
  let kept_tables = rume_kept_defined_from_used(used_tables, table_imports)
  let kept_mems = rume_kept_defined_from_used(used_mems, mem_imports)
  let kept_tags = rume_kept_defined_from_used(used_tags, tag_imports)
  let func_remap = rume_build_abs_remap(func_imports, kept_funcs)
  let global_remap = rume_build_abs_remap(global_imports, kept_globals)
  let table_remap = rume_build_abs_remap(table_imports, kept_tables)
  let mem_remap = rume_build_abs_remap(mem_imports, kept_mems)
  let tag_remap = rume_build_abs_remap(tag_imports, kept_tags)
  let elem_remap = rume_build_defined_remap(used_elems)
  let data_remap = rume_build_defined_remap(used_datas)
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
                @lib.ExternIdx::func(
                  rume_rewrite_func_idx(func_idx, func_remap),
                )
              @lib.GlobalExternIdx(global_idx) =>
                @lib.ExternIdx::global(
                  rume_rewrite_global_idx(global_idx, global_remap),
                )
              @lib.TableExternIdx(table_idx) =>
                @lib.ExternIdx::table(
                  rume_rewrite_table_idx(table_idx, table_remap),
                )
              @lib.MemExternIdx(mem_idx) =>
                @lib.ExternIdx::mem(rume_rewrite_mem_idx(mem_idx, mem_remap))
              @lib.TagExternIdx(tag_idx) =>
                @lib.ExternIdx::tag(rume_rewrite_tag_idx(tag_idx, tag_remap))
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
      Some(@lib.StartSec::new(rume_rewrite_func_idx(func_idx, func_remap)))
    None => None
  }

  let (next_func_sec, next_code_sec) = match (mod_.func_sec, mod_.code_sec) {
    (Some(@lib.FuncSec(type_idxs)), Some(@lib.CodeSec(funcs))) => {
      let next_type_idxs : Array[@lib.TypeIdx] = []
      let next_funcs : Array[@lib.Func] = []
      let mut idx = 0
      while idx < type_idxs.length() && idx < funcs.length() {
        if kept_funcs[idx] {
          next_type_idxs.push(type_idxs[idx])
          let @lib.Func(locals, body) = funcs[idx]
          next_funcs.push(
            @lib.Func::new(
              locals,
              rume_rewrite_expr(
                body, func_remap, global_remap, table_remap, mem_remap, tag_remap,
                elem_remap, data_remap,
              ),
            ),
          )
        }
        idx += 1
      }
      if next_type_idxs.is_empty() {
        (None, None)
      } else {
        (
          Some(@lib.FuncSec::new(next_type_idxs)),
          Some(@lib.CodeSec::new(next_funcs)),
        )
      }
    }
    _ => (None, None)
  }

  let next_global_sec = match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) => {
      let next : Array[@lib.Global] = []
      let mut idx = 0
      while idx < globals.length() {
        if kept_globals[idx] {
          let @lib.Global(global_type, init) = globals[idx]
          next.push(
            @lib.Global::new(
              global_type,
              rume_rewrite_expr(
                init, func_remap, global_remap, table_remap, mem_remap, tag_remap,
                elem_remap, data_remap,
              ),
            ),
          )
        }
        idx += 1
      }
      if next.is_empty() {
        None
      } else {
        Some(@lib.GlobalSec::new(next))
      }
    }
    None => None
  }

  let next_table_sec = match mod_.table_sec {
    Some(@lib.TableSec(tables)) => {
      let next : Array[@lib.Table] = []
      let mut idx = 0
      while idx < tables.length() {
        if kept_tables[idx] {
          let @lib.Table(table_type, init) = tables[idx]
          next.push(
            @lib.Table::new(
              table_type,
              match init {
                Some(expr) =>
                  Some(
                    rume_rewrite_expr(
                      expr, func_remap, global_remap, table_remap, mem_remap, tag_remap,
                      elem_remap, data_remap,
                    ),
                  )
                None => None
              },
            ),
          )
        }
        idx += 1
      }
      if next.is_empty() {
        None
      } else {
        Some(@lib.TableSec::new(next))
      }
    }
    None => None
  }

  let next_mem_sec = match mod_.mem_sec {
    Some(@lib.MemSec(mems)) => {
      let next : Array[@lib.MemType] = []
      let mut idx = 0
      while idx < mems.length() {
        if kept_mems[idx] {
          next.push(mems[idx])
        }
        idx += 1
      }
      if next.is_empty() {
        None
      } else {
        Some(@lib.MemSec::new(next))
      }
    }
    None => None
  }

  let next_tag_sec = match mod_.tag_sec {
    Some(@lib.TagSec(tags)) => {
      let next : Array[@lib.TagType] = []
      let mut idx = 0
      while idx < tags.length() {
        if kept_tags[idx] {
          next.push(tags[idx])
        }
        idx += 1
      }
      if next.is_empty() {
        None
      } else {
        Some(@lib.TagSec::new(next))
      }
    }
    None => None
  }

  let next_elem_sec = match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) => {
      let next : Array[@lib.Elem] = []
      let mut idx = 0
      while idx < elems.length() {
        if used_elems[idx] {
          let @lib.Elem(mode, kind) = elems[idx]
          next.push(
            @lib.Elem::new(
              match mode {
                @lib.Active(table_idx, expr) =>
                  @lib.ElemMode::active(
                    rume_rewrite_table_idx(table_idx, table_remap),
                    rume_rewrite_expr(
                      expr, func_remap, global_remap, table_remap, mem_remap, tag_remap,
                      elem_remap, data_remap,
                    ),
                  )
                _ => mode
              },
              rume_rewrite_elem_kind(
                kind, func_remap, global_remap, table_remap, mem_remap, tag_remap,
                elem_remap, data_remap,
              ),
            ),
          )
        }
        idx += 1
      }
      if next.is_empty() {
        None
      } else {
        Some(@lib.ElemSec::new(next))
      }
    }
    None => None
  }

  let next_data_sec = match mod_.data_sec {
    Some(@lib.DataSec(datas)) => {
      let next : Array[@lib.Data] = []
      let mut idx = 0
      while idx < datas.length() {
        if used_datas[idx] {
          let @lib.Data(mode, bytes) = datas[idx]
          next.push(
            @lib.Data::new(
              match mode {
                @lib.Active(mem_idx, expr) =>
                  @lib.DataMode::active(
                    rume_rewrite_mem_idx(mem_idx, mem_remap),
                    rume_rewrite_expr(
                      expr, func_remap, global_remap, table_remap, mem_remap, tag_remap,
                      elem_remap, data_remap,
                    ),
                  )
                @lib.Passive => mode
              },
              bytes,
            ),
          )
        }
        idx += 1
      }
      if next.is_empty() {
        None
      } else {
        Some(@lib.DataSec::new(next))
      }
    }
    None => None
  }

  let next_data_cnt_sec = match (mod_.data_cnt_sec, next_data_sec) {
    (Some(_), Some(@lib.DataSec(datas))) =>
      Some(@lib.DataCntSec::new(@lib.U32(datas.length().reinterpret_as_uint())))
    (Some(_), None) => Some(@lib.DataCntSec::new(@lib.U32(0U)))
    (None, _) => None
  }

  @lib.Module::new(
    custom_secs=mod_.custom_secs,
    type_sec=mod_.type_sec,
    import_sec=mod_.import_sec,
    func_annotation_sec=rume_rewrite_func_annotation_sec(
      mod_.func_annotation_sec,
      func_remap,
    ),
    func_sec=next_func_sec,
    table_sec=next_table_sec,
    mem_sec=next_mem_sec,
    tag_sec=next_tag_sec,
    stringrefs_sec=mod_.stringrefs_sec,
    global_sec=next_global_sec,
    export_sec=next_export_sec,
    start_sec=next_start_sec,
    elem_sec=next_elem_sec,
    data_cnt_sec=next_data_cnt_sec,
    code_sec=next_code_sec,
    data_sec=next_data_sec,
    name_sec=rume_rewrite_name_sec(
      mod_.name_sec,
      func_remap,
      table_remap,
      mem_remap,
      global_remap,
      elem_remap,
      data_remap,
      tag_remap,
    ),
  )
}

///|
pub fn rume_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  let (
    used_funcs,
    used_globals,
    used_tables,
    used_mems,
    used_tags,
    used_elems,
    used_datas,
  ) = rume_collect_liveness(mod_)
  rume_apply_module_rewrite(
    mod_, used_funcs, used_globals, used_tables, used_mems, used_tags, used_elems,
    used_datas,
  )
}
