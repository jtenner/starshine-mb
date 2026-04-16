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
fn rume_imported_counts(mod_ : @lib.Module) -> (Int, Int, Int, Int, Int) {
  let mut func_imports = 0
  let mut table_imports = 0
  let mut mem_imports = 0
  let mut global_imports = 0
  let mut tag_imports = 0
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(_)) => func_imports += 1
          @lib.Import(_, _, @lib.TableExternType(_)) => table_imports += 1
          @lib.Import(_, _, @lib.MemExternType(_)) => mem_imports += 1
          @lib.Import(_, _, @lib.GlobalExternType(_)) => global_imports += 1
          @lib.Import(_, _, @lib.TagExternType(_)) => tag_imports += 1
          _ => ()
        }
      }
    None => ()
  }
  (func_imports, table_imports, mem_imports, global_imports, tag_imports)
}

///|
fn rume_expr_is_ref_null(expr : @lib.Expr) -> Bool {
  match expr {
    @lib.Expr([@lib.RefNull(_)]) => true
    _ => false
  }
}

///|
fn rume_elem_init_has_effect(kind : @lib.ElemKind) -> Bool {
  match kind {
    @lib.FuncsElemKind(funcs) => funcs.length() > 0
    @lib.FuncExprsElemKind(exprs) | @lib.TypedExprsElemKind(_, exprs) => {
      if exprs.length() == 0 {
        return false
      }
      for expr in exprs {
        if !rume_expr_is_ref_null(expr) {
          return true
        }
      }
      false
    }
  }
}

///|
fn rume_build_table_to_elem_map(
  table_count : Int,
  mod_ : @lib.Module,
) -> Array[Array[@lib.ElemIdx]] {
  let table_to_elems : Array[Array[@lib.ElemIdx]] = []
  let mut table_idx = 0
  while table_idx < table_count {
    table_to_elems.push([])
    table_idx += 1
  }
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) => {
      let mut elem_idx = 0
      while elem_idx < elems.length() {
        match elems[elem_idx] {
          @lib.Elem(@lib.Active(@lib.TableIdx(table_idx), _), _) => {
            let table_slot = table_idx.reinterpret_as_int()
            if table_slot >= 0 && table_slot < table_to_elems.length() {
              table_to_elems[table_slot].push(
                @lib.ElemIdx::new(elem_idx.reinterpret_as_uint()),
              )
            }
          }
          _ => ()
        }
        elem_idx += 1
      }
    }
    None => ()
  }
  table_to_elems
}

///|
fn rume_build_mem_to_data_map(
  mem_count : Int,
  mod_ : @lib.Module,
) -> Array[Array[@lib.DataIdx]] {
  let mem_to_datas : Array[Array[@lib.DataIdx]] = []
  let mut mem_idx = 0
  while mem_idx < mem_count {
    mem_to_datas.push([])
    mem_idx += 1
  }
  match mod_.data_sec {
    Some(@lib.DataSec(datas)) => {
      let mut data_idx = 0
      while data_idx < datas.length() {
        match datas[data_idx] {
          @lib.Data(@lib.Active(@lib.MemIdx(mem_idx), _), bytes) => {
            let mem_slot = mem_idx.reinterpret_as_int()
            if bytes.length() > 0 &&
              mem_slot >= 0 &&
              mem_slot < mem_to_datas.length() {
              mem_to_datas[mem_slot].push(
                @lib.DataIdx::new(data_idx.reinterpret_as_uint()),
              )
            }
          }
          _ => ()
        }
        data_idx += 1
      }
    }
    None => ()
  }
  mem_to_datas
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
fn rume_lookup_defined_func(
  mod_ : @lib.Module,
  idx : @lib.FuncIdx,
) -> @lib.Func? {
  let @lib.FuncIdx(raw_idx) = idx
  let def_idx = raw_idx.reinterpret_as_int() - rume_imported_func_count(mod_)
  if def_idx < 0 {
    return None
  }
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs.get(def_idx)
    None => None
  }
}

///|
fn rume_func_body_is_single_nop(func_ : @lib.Func) -> Bool {
  match func_ {
    @lib.Func(_, @lib.Expr([@lib.Nop])) => true
    _ => false
  }
}

///|
fn rume_has_binaryen_noop_start_sec(mod_ : @lib.Module) -> Bool {
  match mod_.start_sec {
    Some(@lib.StartSec(func_idx)) =>
      match rume_lookup_defined_func(mod_, func_idx) {
        Some(func_) => rume_func_body_is_single_nop(func_)
        None => false
      }
    None => false
  }
}

///|
fn rume_mark_func(
  queue : Array[RumeItem],
  used_funcs : @bitset.BitSet,
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
  used_globals : @bitset.BitSet,
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
  used_tables : @bitset.BitSet,
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
  used_mems : @bitset.BitSet,
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
  used_tags : @bitset.BitSet,
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
  used_elems : @bitset.BitSet,
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
  used_datas : @bitset.BitSet,
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
  used_mems : @bitset.BitSet,
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
  used_tags : @bitset.BitSet,
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
  used_funcs : @bitset.BitSet,
  used_globals : @bitset.BitSet,
  used_tables : @bitset.BitSet,
  used_mems : @bitset.BitSet,
  used_tags : @bitset.BitSet,
  used_elems : @bitset.BitSet,
  used_datas : @bitset.BitSet,
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
  used_funcs : @bitset.BitSet,
  used_globals : @bitset.BitSet,
  used_tables : @bitset.BitSet,
  used_mems : @bitset.BitSet,
  used_tags : @bitset.BitSet,
  used_elems : @bitset.BitSet,
  used_datas : @bitset.BitSet,
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
  used_funcs : @bitset.BitSet,
  used_globals : @bitset.BitSet,
  used_tables : @bitset.BitSet,
  used_mems : @bitset.BitSet,
  used_tags : @bitset.BitSet,
  used_elems : @bitset.BitSet,
  used_datas : @bitset.BitSet,
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
  used_funcs : @bitset.BitSet,
  used_globals : @bitset.BitSet,
  used_tables : @bitset.BitSet,
  used_mems : @bitset.BitSet,
  used_tags : @bitset.BitSet,
  used_elems : @bitset.BitSet,
  used_datas : @bitset.BitSet,
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
  used_funcs : @bitset.BitSet,
  used_globals : @bitset.BitSet,
  used_tables : @bitset.BitSet,
  used_mems : @bitset.BitSet,
  used_tags : @bitset.BitSet,
  used_elems : @bitset.BitSet,
  used_datas : @bitset.BitSet,
  table_to_elems : Array[Array[@lib.ElemIdx]],
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
  let slot = abs_idx.reinterpret_as_int()
  for elem_idx in table_to_elems[slot] {
    rume_mark_elem(queue, used_elems, elem_idx)
  }
}

///|
fn rume_process_mem(
  abs_idx : UInt,
  queue : Array[RumeItem],
  used_datas : @bitset.BitSet,
  mem_to_datas : Array[Array[@lib.DataIdx]],
) -> Unit {
  let slot = abs_idx.reinterpret_as_int()
  for data_idx in mem_to_datas[slot] {
    rume_mark_data(queue, used_datas, data_idx)
  }
}

///|
fn rume_process_elem(
  mod_ : @lib.Module,
  elem_idx : UInt,
  queue : Array[RumeItem],
  used_funcs : @bitset.BitSet,
  used_globals : @bitset.BitSet,
  used_tables : @bitset.BitSet,
  used_mems : @bitset.BitSet,
  used_tags : @bitset.BitSet,
  used_elems : @bitset.BitSet,
  used_datas : @bitset.BitSet,
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
  used_funcs : @bitset.BitSet,
  used_globals : @bitset.BitSet,
  used_tables : @bitset.BitSet,
  used_mems : @bitset.BitSet,
  used_tags : @bitset.BitSet,
  used_elems : @bitset.BitSet,
  used_datas : @bitset.BitSet,
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
fn rume_mark_imported_parent_segments(
  mod_ : @lib.Module,
  table_imports : Int,
  mem_imports : Int,
  queue : Array[RumeItem],
  used_elems : @bitset.BitSet,
  used_datas : @bitset.BitSet,
) -> Unit {
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) => {
      let mut elem_idx = 0
      while elem_idx < elems.length() {
        match elems[elem_idx] {
          @lib.Elem(@lib.Active(@lib.TableIdx(table_idx), _), kind) =>
            if table_idx.reinterpret_as_int() < table_imports &&
              rume_elem_init_has_effect(kind) {
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
          @lib.Data(@lib.Active(@lib.MemIdx(mem_idx), _), bytes) =>
            if bytes.length() > 0 && mem_idx.reinterpret_as_int() < mem_imports {
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
}

///|
fn rume_collect_liveness_with_import_parent_policy(
  mod_ : @lib.Module,
  keep_import_parent_segments : Bool,
) -> (
  @bitset.BitSet,
  @bitset.BitSet,
  @bitset.BitSet,
  @bitset.BitSet,
  @bitset.BitSet,
  @bitset.BitSet,
  @bitset.BitSet,
) {
  let (func_imports, table_imports, mem_imports, global_imports, tag_imports) = rume_imported_counts(
    mod_,
  )
  let used_funcs = @bitset.BitSet::new(
    func_imports + rume_defined_func_count(mod_),
  )
  let used_tables = @bitset.BitSet::new(
    table_imports + rume_defined_table_count(mod_),
  )
  let used_mems = @bitset.BitSet::new(
    mem_imports + rume_defined_mem_count(mod_),
  )
  let used_globals = @bitset.BitSet::new(
    global_imports + rume_defined_global_count(mod_),
  )
  let used_tags = @bitset.BitSet::new(
    tag_imports + rume_defined_tag_count(mod_),
  )
  let used_elems = @bitset.BitSet::new(
    match mod_.elem_sec {
      Some(@lib.ElemSec(elems)) => elems.length()
      None => 0
    },
  )
  let used_datas = @bitset.BitSet::new(
    match mod_.data_sec {
      Some(@lib.DataSec(datas)) => datas.length()
      None => 0
    },
  )
  let table_to_elems = rume_build_table_to_elem_map(used_tables.length(), mod_)
  let mem_to_datas = rume_build_mem_to_data_map(used_mems.length(), mod_)
  let queue : Array[RumeItem] = []
  let drop_noop_start_sec = rume_has_binaryen_noop_start_sec(mod_)

  if !drop_noop_start_sec {
    match mod_.start_sec {
      Some(@lib.StartSec(func_idx)) =>
        rume_mark_func(queue, used_funcs, func_idx)
      None => ()
    }
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
  if keep_import_parent_segments {
    rume_mark_imported_parent_segments(
      mod_, table_imports, mem_imports, queue, used_elems, used_datas,
    )
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
          used_mems, used_tags, used_elems, used_datas, table_to_elems,
        )
      RumeItem::Mem(abs_idx) =>
        rume_process_mem(abs_idx, queue, used_datas, mem_to_datas)
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
fn rume_collect_liveness(
  mod_ : @lib.Module,
) -> (
  @bitset.BitSet,
  @bitset.BitSet,
  @bitset.BitSet,
  @bitset.BitSet,
  @bitset.BitSet,
  @bitset.BitSet,
  @bitset.BitSet,
) {
  rume_collect_liveness_with_import_parent_policy(mod_, true)
}

///|
fn rume_build_used_remap(used : @bitset.BitSet) -> Array[Int] {
  let remap = Array::make(used.length(), -1)
  let mut next_idx = 0
  let mut idx = 0
  while idx < used.length() {
    if used[idx] {
      remap[idx] = next_idx
      next_idx += 1
    }
    idx += 1
  }
  remap
}

///|
fn rume_build_defined_remap(kept : @bitset.BitSet) -> Array[Int] {
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
fn rume_remap_is_identity(remap : Array[Int]) -> Bool {
  let mut idx = 0
  while idx < remap.length() {
    if remap[idx] != idx {
      return false
    }
    idx += 1
  }
  true
}

///|
fn rume_all_true(flags : @bitset.BitSet) -> Bool {
  let mut idx = 0
  while idx < flags.length() {
    if !flags[idx] {
      return false
    }
    idx += 1
  }
  true
}

///|
fn rume_kept_defined_from_used(
  used : @bitset.BitSet,
  imported_count : Int,
) -> @bitset.BitSet {
  let kept = @bitset.BitSet::new(used.length() - imported_count)
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
fn rume_sort_name_assocs(entries : Array[@lib.NameAssoc]) -> Unit {
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
fn rume_sort_indirect_name_assocs(
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
        rume_sort_name_assocs(rewritten)
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
        rume_sort_indirect_name_assocs(rewritten)
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
fn rume_mark_type_idx(used_types : @bitset.BitSet, idx : @lib.TypeIdx) -> Unit {
  match idx {
    @lib.TypeIdx(raw) => {
      let slot = raw.reinterpret_as_int()
      if slot >= 0 && slot < used_types.length() {
        used_types[slot] = true
      }
    }
    @lib.RecIdx(_) => ()
  }
}

///|
fn rume_mark_heap_type(
  used_types : @bitset.BitSet,
  heap_type : @lib.HeapType,
) -> Unit {
  match heap_type {
    @lib.AbsHeapTypeHeapType(_) => ()
    @lib.HeapType(type_idx) => rume_mark_type_idx(used_types, type_idx)
    @lib.DefTypeHeapType(@lib.DefType(rec_type, _)) =>
      rume_mark_rec_type_types(used_types, rec_type)
  }
}

///|
fn rume_mark_ref_type(
  used_types : @bitset.BitSet,
  ref_type : @lib.RefType,
) -> Unit {
  match ref_type {
    @lib.HeapTypeRefType(_, _, heap_type) =>
      rume_mark_heap_type(used_types, heap_type)
    @lib.AbsHeapTypeRefType(_) => ()
  }
}

///|
fn rume_mark_val_type(
  used_types : @bitset.BitSet,
  val_type : @lib.ValType,
) -> Unit {
  match val_type {
    @lib.RefTypeValType(ref_type) => rume_mark_ref_type(used_types, ref_type)
    _ => ()
  }
}

///|
fn rume_mark_storage_type(
  used_types : @bitset.BitSet,
  storage_type : @lib.StorageType,
) -> Unit {
  match storage_type {
    @lib.ValTypeStorageType(val_type) =>
      rume_mark_val_type(used_types, val_type)
    @lib.PackTypeStorageType(_) => ()
  }
}

///|
fn rume_mark_field_type(
  used_types : @bitset.BitSet,
  field_type : @lib.FieldType,
) -> Unit {
  let @lib.FieldType(storage_type, _) = field_type
  rume_mark_storage_type(used_types, storage_type)
}

///|
fn rume_mark_block_type(
  used_types : @bitset.BitSet,
  block_type : @lib.BlockType,
) -> Unit {
  match block_type {
    @lib.VoidBlockType => ()
    @lib.ValTypeBlockType(val_type) => rume_mark_val_type(used_types, val_type)
    @lib.TypeIdxBlockType(type_idx) => rume_mark_type_idx(used_types, type_idx)
  }
}

///|
fn rume_mark_type_metadata(
  used_types : @bitset.BitSet,
  metadata : @lib.TypeMetadata,
) -> Unit {
  let { describes, descriptor } = metadata
  match describes {
    Some(type_idx) => rume_mark_type_idx(used_types, type_idx)
    None => ()
  }
  match descriptor {
    Some(type_idx) => rume_mark_type_idx(used_types, type_idx)
    None => ()
  }
}

///|
fn rume_mark_comp_type(
  used_types : @bitset.BitSet,
  comp_type : @lib.CompType,
) -> Unit {
  match comp_type {
    @lib.ArrayCompType(field_type) =>
      rume_mark_field_type(used_types, field_type)
    @lib.StructCompType(field_types) =>
      for field_type in field_types {
        rume_mark_field_type(used_types, field_type)
      }
    @lib.FuncCompType(params, results) => {
      for param in params {
        rume_mark_val_type(used_types, param)
      }
      for result in results {
        rume_mark_val_type(used_types, result)
      }
    }
  }
}

///|
fn rume_mark_sub_type_types(
  used_types : @bitset.BitSet,
  subtype : @lib.SubType,
) -> Unit {
  match subtype {
    @lib.SubType(_, supers, metadata, comp_type) => {
      for super_type in supers {
        rume_mark_type_idx(used_types, super_type)
      }
      rume_mark_type_metadata(used_types, metadata)
      rume_mark_comp_type(used_types, comp_type)
    }
    @lib.CompTypeSubType(metadata, comp_type) => {
      rume_mark_type_metadata(used_types, metadata)
      rume_mark_comp_type(used_types, comp_type)
    }
  }
}

///|
fn rume_mark_rec_type_types(
  used_types : @bitset.BitSet,
  rec_type : @lib.RecType,
) -> Unit {
  match rec_type {
    @lib.SingleRecType(subtype) => rume_mark_sub_type_types(used_types, subtype)
    @lib.GroupRecType(subtypes) =>
      for subtype in subtypes {
        rume_mark_sub_type_types(used_types, subtype)
      }
  }
}

///|
fn rume_rec_type_mentions_type_idxs(rec_type : @lib.RecType) -> Bool {
  match rec_type {
    @lib.SingleRecType(subtype) => rume_sub_type_mentions_type_idxs(subtype)
    @lib.GroupRecType(subtypes) => {
      for subtype in subtypes {
        if rume_sub_type_mentions_type_idxs(subtype) {
          return true
        }
      }
      false
    }
  }
}

///|
fn rume_sub_type_mentions_type_idxs(subtype : @lib.SubType) -> Bool {
  match subtype {
    @lib.SubType(_, supers, metadata, comp_type) =>
      supers.length() > 0 ||
      rume_type_metadata_mentions_type_idxs(metadata) ||
      rume_comp_type_mentions_type_idxs(comp_type)
    @lib.CompTypeSubType(metadata, comp_type) =>
      rume_type_metadata_mentions_type_idxs(metadata) ||
      rume_comp_type_mentions_type_idxs(comp_type)
  }
}

///|
fn rume_type_metadata_mentions_type_idxs(metadata : @lib.TypeMetadata) -> Bool {
  let { describes, descriptor } = metadata
  describes is Some(_) || descriptor is Some(_)
}

///|
fn rume_comp_type_mentions_type_idxs(comp_type : @lib.CompType) -> Bool {
  match comp_type {
    @lib.ArrayCompType(field_type) =>
      rume_field_type_mentions_type_idxs(field_type)
    @lib.StructCompType(field_types) => {
      for field_type in field_types {
        if rume_field_type_mentions_type_idxs(field_type) {
          return true
        }
      }
      false
    }
    @lib.FuncCompType(params, results) =>
      rume_val_types_mention_type_idxs(params) ||
      rume_val_types_mention_type_idxs(results)
  }
}

///|
fn rume_field_type_mentions_type_idxs(field_type : @lib.FieldType) -> Bool {
  let @lib.FieldType(storage_type, _) = field_type
  rume_storage_type_mentions_type_idxs(storage_type)
}

///|
fn rume_storage_type_mentions_type_idxs(
  storage_type : @lib.StorageType,
) -> Bool {
  match storage_type {
    @lib.ValTypeStorageType(val_type) =>
      rume_val_type_mentions_type_idxs(val_type)
    @lib.PackTypeStorageType(_) => false
  }
}

///|
fn rume_val_types_mention_type_idxs(val_types : Array[@lib.ValType]) -> Bool {
  for val_type in val_types {
    if rume_val_type_mentions_type_idxs(val_type) {
      return true
    }
  }
  false
}

///|
fn rume_val_type_mentions_type_idxs(val_type : @lib.ValType) -> Bool {
  match val_type {
    @lib.RefTypeValType(ref_type) => rume_ref_type_mentions_type_idxs(ref_type)
    _ => false
  }
}

///|
fn rume_ref_type_mentions_type_idxs(ref_type : @lib.RefType) -> Bool {
  match ref_type {
    @lib.HeapTypeRefType(_, _, heap_type) =>
      rume_heap_type_mentions_type_idxs(heap_type)
    @lib.AbsHeapTypeRefType(_) => false
  }
}

///|
fn rume_heap_type_mentions_type_idxs(heap_type : @lib.HeapType) -> Bool {
  match heap_type {
    @lib.AbsHeapTypeHeapType(_) => false
    @lib.HeapType(_) => true
    @lib.DefTypeHeapType(@lib.DefType(rec_type, _)) =>
      rume_rec_type_mentions_type_idxs(rec_type)
  }
}

///|
fn rume_mark_type_instrs(
  used_types : @bitset.BitSet,
  instrs : Array[@lib.Instruction],
) -> Unit {
  for instr in instrs {
    rume_mark_instruction_types(used_types, instr)
  }
}

///|
fn rume_mark_expr_types(used_types : @bitset.BitSet, expr : @lib.Expr) -> Unit {
  let @lib.Expr(instrs) = expr
  rume_mark_type_instrs(used_types, instrs)
}

///|
fn rume_mark_instruction_types(
  used_types : @bitset.BitSet,
  instr : @lib.Instruction,
) -> Unit {
  match instr {
    @lib.Block(block_type, expr) | @lib.Loop(block_type, expr) => {
      rume_mark_block_type(used_types, block_type)
      rume_mark_expr_types(used_types, expr)
    }
    @lib.If(block_type, then_body, else_body) => {
      rume_mark_block_type(used_types, block_type)
      rume_mark_type_instrs(used_types, then_body)
      match else_body {
        Some(body) => rume_mark_type_instrs(used_types, body)
        None => ()
      }
    }
    @lib.CallIndirect(type_idx, _)
    | @lib.ReturnCallIndirect(type_idx, _)
    | @lib.CallRef(type_idx)
    | @lib.ReturnCallRef(type_idx)
    | @lib.StructNew(type_idx)
    | @lib.StructNewDefault(type_idx)
    | @lib.StructNewDesc(type_idx)
    | @lib.StructNewDefaultDesc(type_idx)
    | @lib.StructGet(type_idx, _)
    | @lib.StructGetS(type_idx, _)
    | @lib.StructGetU(type_idx, _)
    | @lib.StructSet(type_idx, _)
    | @lib.ArrayNew(type_idx)
    | @lib.ArrayNewDefault(type_idx)
    | @lib.ArrayNewFixed(type_idx, _)
    | @lib.ArrayNewData(type_idx, _)
    | @lib.ArrayNewElem(type_idx, _)
    | @lib.ArrayGet(type_idx)
    | @lib.ArrayGetS(type_idx)
    | @lib.ArrayGetU(type_idx)
    | @lib.ArraySet(type_idx)
    | @lib.ArrayFill(type_idx)
    | @lib.ArrayInitData(type_idx, _)
    | @lib.ArrayInitElem(type_idx, _)
    | @lib.RefGetDesc(type_idx) => rume_mark_type_idx(used_types, type_idx)
    @lib.ArrayCopy(src_type, dst_type) => {
      rume_mark_type_idx(used_types, src_type)
      rume_mark_type_idx(used_types, dst_type)
    }
    @lib.Select(Some(types)) =>
      for val_type in types {
        rume_mark_val_type(used_types, val_type)
      }
    @lib.TryTable(block_type, _, body) => {
      rume_mark_block_type(used_types, block_type)
      rume_mark_expr_types(used_types, body)
    }
    @lib.RefNull(ref_type) => rume_mark_ref_type(used_types, ref_type)
    @lib.RefTest(_, heap_type)
    | @lib.RefCast(_, heap_type)
    | @lib.RefTestDesc(_, heap_type)
    | @lib.RefCastDescEq(_, heap_type) =>
      rume_mark_heap_type(used_types, heap_type)
    @lib.BrOnCast(_, _, source, target)
    | @lib.BrOnCastFail(_, _, source, target) => {
      rume_mark_heap_type(used_types, source)
      rume_mark_heap_type(used_types, target)
    }
    _ => ()
  }
}

///|
fn rume_collect_used_type_flags(mod_ : @lib.Module) -> @bitset.BitSet? {
  match mod_.type_sec {
    Some(@lib.TypeSec(rec_types)) => {
      for rec_type in rec_types {
        if rume_rec_type_mentions_type_idxs(rec_type) {
          return None
        }
      }
      let used_types = @bitset.BitSet::new(rec_types.length())
      match mod_.import_sec {
        Some(@lib.ImportSec(imports)) =>
          for import_ in imports {
            let @lib.Import(_, _, extern_type) = import_
            match extern_type {
              @lib.FuncExternType(type_idx) =>
                rume_mark_type_idx(used_types, type_idx)
              @lib.TableExternType(@lib.TableType(ref_type, _)) =>
                rume_mark_ref_type(used_types, ref_type)
              @lib.MemExternType(_) => ()
              @lib.GlobalExternType(@lib.GlobalType(val_type, _)) =>
                rume_mark_val_type(used_types, val_type)
              @lib.TagExternType(@lib.TagType(type_idx)) =>
                rume_mark_type_idx(used_types, type_idx)
            }
          }
        None => ()
      }
      match mod_.func_sec {
        Some(@lib.FuncSec(type_idxs)) =>
          for type_idx in type_idxs {
            rume_mark_type_idx(used_types, type_idx)
          }
        None => ()
      }
      match mod_.table_sec {
        Some(@lib.TableSec(tables)) =>
          for table in tables {
            let @lib.Table(@lib.TableType(ref_type, _), init) = table
            rume_mark_ref_type(used_types, ref_type)
            match init {
              Some(expr) => rume_mark_expr_types(used_types, expr)
              None => ()
            }
          }
        None => ()
      }
      match mod_.tag_sec {
        Some(@lib.TagSec(tags)) =>
          for tag in tags {
            let @lib.TagType(type_idx) = tag
            rume_mark_type_idx(used_types, type_idx)
          }
        None => ()
      }
      match mod_.global_sec {
        Some(@lib.GlobalSec(globals)) =>
          for global in globals {
            let @lib.Global(@lib.GlobalType(val_type, _), init) = global
            rume_mark_val_type(used_types, val_type)
            rume_mark_expr_types(used_types, init)
          }
        None => ()
      }
      match mod_.elem_sec {
        Some(@lib.ElemSec(elems)) =>
          for elem in elems {
            let @lib.Elem(mode, kind) = elem
            match mode {
              @lib.Active(_, expr) => rume_mark_expr_types(used_types, expr)
              _ => ()
            }
            match kind {
              @lib.FuncsElemKind(_) => ()
              @lib.FuncExprsElemKind(exprs) =>
                for expr in exprs {
                  rume_mark_expr_types(used_types, expr)
                }
              @lib.TypedExprsElemKind(ref_type, exprs) => {
                rume_mark_ref_type(used_types, ref_type)
                for expr in exprs {
                  rume_mark_expr_types(used_types, expr)
                }
              }
            }
          }
        None => ()
      }
      match mod_.data_sec {
        Some(@lib.DataSec(datas)) =>
          for data in datas {
            let @lib.Data(mode, _) = data
            match mode {
              @lib.Active(_, expr) => rume_mark_expr_types(used_types, expr)
              @lib.Passive => ()
            }
          }
        None => ()
      }
      match mod_.code_sec {
        Some(@lib.CodeSec(funcs)) =>
          for func in funcs {
            let @lib.Func(locals, body) = func
            for local_run in locals.runs() {
              rume_mark_val_type(used_types, local_run.val_type())
            }
            rume_mark_expr_types(used_types, body)
          }
        None => ()
      }
      Some(used_types)
    }
    None => None
  }
}

///|
fn rume_build_type_remap(used_types : @bitset.BitSet) -> Map[UInt, UInt] {
  let remap : Map[UInt, UInt] = {}
  let mut next_idx = 0
  let mut idx = 0
  while idx < used_types.length() {
    if used_types[idx] {
      remap.set(idx.reinterpret_as_uint(), next_idx.reinterpret_as_uint())
      next_idx += 1
    }
    idx += 1
  }
  remap
}

///|
fn rume_rebuild_type_sec(
  type_sec : @lib.TypeSec,
  used_types : @bitset.BitSet,
) -> @lib.TypeSec? {
  let @lib.TypeSec(rec_types) = type_sec
  let next : Array[@lib.RecType] = []
  let mut idx = 0
  while idx < rec_types.length() {
    if used_types[idx] {
      next.push(rec_types[idx])
    }
    idx += 1
  }
  if next.is_empty() {
    None
  } else {
    Some(@lib.TypeSec::new(next))
  }
}

///|
fn rume_set_type_sec(
  mod_ : @lib.Module,
  type_sec : @lib.TypeSec?,
) -> @lib.Module {
  @lib.Module::new(
    custom_secs=mod_.custom_secs,
    type_sec~,
    import_sec=mod_.import_sec,
    func_annotation_sec=mod_.func_annotation_sec,
    func_sec=mod_.func_sec,
    table_sec=mod_.table_sec,
    mem_sec=mod_.mem_sec,
    tag_sec=mod_.tag_sec,
    stringrefs_sec=mod_.stringrefs_sec,
    global_sec=mod_.global_sec,
    export_sec=mod_.export_sec,
    start_sec=mod_.start_sec,
    elem_sec=mod_.elem_sec,
    data_cnt_sec=mod_.data_cnt_sec,
    code_sec=mod_.code_sec,
    data_sec=mod_.data_sec,
    name_sec=mod_.name_sec,
  )
}

///|
fn rume_compact_type_sec(mod_ : @lib.Module) -> @lib.Module {
  let used_types = match rume_collect_used_type_flags(mod_) {
    Some(flags) => flags
    None => return mod_
  }
  if rume_all_true(used_types) {
    return mod_
  }
  let type_remap = rume_build_type_remap(used_types)
  let rewritten = dfe_rewrite_module_type_idxs(mod_, type_remap)
  match mod_.type_sec {
    Some(type_sec) =>
      rume_set_type_sec(rewritten, rume_rebuild_type_sec(type_sec, used_types))
    None => rewritten
  }
}

///|
fn rume_apply_module_rewrite(
  mod_ : @lib.Module,
  used_funcs : @bitset.BitSet,
  used_globals : @bitset.BitSet,
  used_tables : @bitset.BitSet,
  used_mems : @bitset.BitSet,
  used_tags : @bitset.BitSet,
  used_elems : @bitset.BitSet,
  used_datas : @bitset.BitSet,
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
  let func_remap = rume_build_used_remap(used_funcs)
  let global_remap = rume_build_used_remap(used_globals)
  let table_remap = rume_build_used_remap(used_tables)
  let mem_remap = rume_build_used_remap(used_mems)
  let tag_remap = rume_build_used_remap(used_tags)
  let elem_remap = rume_build_defined_remap(used_elems)
  let data_remap = rume_build_defined_remap(used_datas)
  let func_remap_is_identity = rume_remap_is_identity(func_remap)
  let global_remap_is_identity = rume_remap_is_identity(global_remap)
  let table_remap_is_identity = rume_remap_is_identity(table_remap)
  let mem_remap_is_identity = rume_remap_is_identity(mem_remap)
  let tag_remap_is_identity = rume_remap_is_identity(tag_remap)
  let elem_remap_is_identity = rume_remap_is_identity(elem_remap)
  let data_remap_is_identity = rume_remap_is_identity(data_remap)
  let code_body_rewrite_needed = !(func_remap_is_identity &&
    global_remap_is_identity &&
    table_remap_is_identity &&
    mem_remap_is_identity &&
    tag_remap_is_identity &&
    elem_remap_is_identity &&
    data_remap_is_identity)
  let drop_noop_start_sec = rume_has_binaryen_noop_start_sec(mod_)
  if !drop_noop_start_sec &&
    !code_body_rewrite_needed &&
    rume_all_true(kept_funcs) &&
    rume_all_true(kept_globals) &&
    rume_all_true(kept_tables) &&
    rume_all_true(kept_mems) &&
    rume_all_true(kept_tags) &&
    rume_all_true(used_elems) &&
    rume_all_true(used_datas) {
    return mod_
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

  let next_start_sec = if drop_noop_start_sec {
    None
  } else {
    match mod_.start_sec {
      Some(@lib.StartSec(func_idx)) =>
        Some(@lib.StartSec::new(rume_rewrite_func_idx(func_idx, func_remap)))
      None => None
    }
  }

  let next_import_sec = match mod_.import_sec {
    Some(@lib.ImportSec(imports)) => {
      let next : Array[@lib.Import] = []
      let mut func_idx = 0
      let mut table_idx = 0
      let mut mem_idx = 0
      let mut global_idx = 0
      let mut tag_idx = 0
      for import_ in imports {
        let keep = match import_ {
          @lib.Import(_, _, @lib.FuncExternType(_)) => {
            let keep = used_funcs[func_idx]
            func_idx += 1
            keep
          }
          @lib.Import(_, _, @lib.TableExternType(_)) => {
            let keep = used_tables[table_idx]
            table_idx += 1
            keep
          }
          @lib.Import(_, _, @lib.MemExternType(_)) => {
            let keep = used_mems[mem_idx]
            mem_idx += 1
            keep
          }
          @lib.Import(_, _, @lib.GlobalExternType(_)) => {
            let keep = used_globals[global_idx]
            global_idx += 1
            keep
          }
          @lib.Import(_, _, @lib.TagExternType(_)) => {
            let keep = used_tags[tag_idx]
            tag_idx += 1
            keep
          }
        }
        if keep {
          next.push(import_)
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

  let (next_func_sec, next_code_sec) = if !code_body_rewrite_needed &&
    rume_all_true(kept_funcs) {
    (mod_.func_sec, mod_.code_sec)
  } else {
    match (mod_.func_sec, mod_.code_sec) {
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

  rume_compact_type_sec(
    @lib.Module::new(
      custom_secs=mod_.custom_secs,
      type_sec=mod_.type_sec,
      import_sec=next_import_sec,
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
    ),
  )
}

///|
fn rume_name_to_string(name : @lib.Name) -> String {
  let @lib.Name(text) = name
  text.to_string()
}

///|
fn rume_lookup_func_export_name(
  mod_ : @lib.Module,
  idx : @lib.FuncIdx,
) -> String? {
  match mod_.export_sec {
    Some(@lib.ExportSec(exports)) =>
      for export_ in exports {
        let @lib.Export(name, extern_idx) = export_
        match extern_idx {
          @lib.FuncExternIdx(func_idx) if func_idx == idx =>
            return Some(rume_name_to_string(name))
          _ => ()
        }
      }
    None => ()
  }
  None
}

///|
fn rume_lookup_func_name(mod_ : @lib.Module, idx : @lib.FuncIdx) -> String? {
  let @lib.FuncIdx(raw_idx) = idx
  match mod_.name_sec {
    Some(name_sec) =>
      match name_sec.func_names {
        Some(@lib.NameMap(entries)) =>
          for entry in entries {
            let @lib.NameAssoc(name_idx, name) = entry
            if name_idx == raw_idx {
              return Some(rume_name_to_string(name))
            }
          }
        None => ()
      }
    None => ()
  }
  None
}

///|
fn rume_has_string(strings : Array[String], target : String) -> Bool {
  for value in strings {
    if value == target {
      return true
    }
  }
  false
}

///|
fn rume_unique_export_name(used : Array[String], base : String) -> String {
  let stem = if base.length() == 0 { "func" } else { base }
  if !rume_has_string(used, stem) {
    return stem
  }
  let mut suffix = 1
  while rume_has_string(used, "\{stem}_\{suffix}") {
    suffix += 1
  }
  "\{stem}_\{suffix}"
}

///|
fn rume_export_name_for_root(mod_ : @lib.Module, idx : @lib.FuncIdx) -> String {
  let @lib.FuncIdx(raw_idx) = idx
  let base = match rume_lookup_func_export_name(mod_, idx) {
    Some(name) => name
    None =>
      match rume_lookup_func_name(mod_, idx) {
        Some(name) => name
        None => "func_\{raw_idx}"
      }
  }
  base
}

///|
fn rume_build_extract_export_sec(
  mod_ : @lib.Module,
  roots : Array[@lib.FuncIdx],
) -> @lib.ExportSec {
  let exports : Array[@lib.Export] = []
  let used_names : Array[String] = []
  for root in roots {
    let export_name = rume_unique_export_name(
      used_names,
      rume_export_name_for_root(mod_, root),
    )
    used_names.push(export_name)
    exports.push(
      @lib.Export::new(@lib.Name::new(export_name), @lib.ExternIdx::func(root)),
    )
  }
  @lib.ExportSec::new(exports)
}

///|
fn rume_root_module_for_extract(
  mod_ : @lib.Module,
  roots : Array[@lib.FuncIdx],
) -> @lib.Module {
  @lib.Module::new(
    custom_secs=mod_.custom_secs,
    type_sec=mod_.type_sec,
    import_sec=mod_.import_sec,
    func_annotation_sec=mod_.func_annotation_sec,
    func_sec=mod_.func_sec,
    table_sec=mod_.table_sec,
    mem_sec=mod_.mem_sec,
    tag_sec=mod_.tag_sec,
    stringrefs_sec=mod_.stringrefs_sec,
    global_sec=mod_.global_sec,
    export_sec=Some(rume_build_extract_export_sec(mod_, roots)),
    start_sec=None,
    elem_sec=mod_.elem_sec,
    data_cnt_sec=mod_.data_cnt_sec,
    code_sec=mod_.code_sec,
    data_sec=mod_.data_sec,
    name_sec=mod_.name_sec,
  )
}

///|
fn rume_identity_remap(length : Int) -> Array[Int] {
  let remap = Array::make(length, 0)
  let mut idx = 0
  while idx < length {
    remap[idx] = idx
    idx += 1
  }
  remap
}

///|
fn rume_build_extract_defined_order(
  mod_ : @lib.Module,
  kept_defined : @bitset.BitSet,
  func_imports : Int,
) -> Array[Int] {
  let order : Array[Int] = []
  let seen = @bitset.BitSet::new(kept_defined.length())
  match mod_.export_sec {
    Some(@lib.ExportSec(exports)) =>
      for export_ in exports {
        let @lib.Export(_, extern_idx) = export_
        match extern_idx {
          @lib.FuncExternIdx(@lib.FuncIdx(raw_idx)) => {
            let def_idx = raw_idx.reinterpret_as_int() - func_imports
            if def_idx >= 0 &&
              def_idx < kept_defined.length() &&
              kept_defined[def_idx] &&
              !seen[def_idx] {
              seen[def_idx] = true
              order.push(def_idx)
            }
          }
          _ => ()
        }
      }
    None => ()
  }
  let mut def_idx = 0
  while def_idx < kept_defined.length() {
    if kept_defined[def_idx] && !seen[def_idx] {
      order.push(def_idx)
    }
    def_idx += 1
  }
  order
}

///|
fn rume_build_extract_func_remap(
  used_funcs : @bitset.BitSet,
  func_imports : Int,
  ordered_defined : Array[Int],
) -> Array[Int] {
  let remap = Array::make(used_funcs.length(), -1)
  let mut next_idx = 0
  let mut import_idx = 0
  while import_idx < func_imports {
    if used_funcs[import_idx] {
      remap[import_idx] = next_idx
      next_idx += 1
    }
    import_idx += 1
  }
  for def_idx in ordered_defined {
    let abs_idx = func_imports + def_idx
    if abs_idx >= 0 && abs_idx < used_funcs.length() && used_funcs[abs_idx] {
      remap[abs_idx] = next_idx
      next_idx += 1
    }
  }
  remap
}

///|
fn rume_rewrite_functions_only(
  mod_ : @lib.Module,
  used_funcs : @bitset.BitSet,
) -> @lib.Module {
  let func_imports = rume_imported_func_count(mod_)
  let kept_defined = rume_kept_defined_from_used(used_funcs, func_imports)
  let ordered_defined = rume_build_extract_defined_order(
    mod_, kept_defined, func_imports,
  )
  let func_remap = rume_build_extract_func_remap(
    used_funcs, func_imports, ordered_defined,
  )
  if rume_remap_is_identity(func_remap) {
    return mod_
  }

  let global_remap = rume_identity_remap(
    rume_imported_global_count(mod_) + rume_defined_global_count(mod_),
  )
  let table_remap = rume_identity_remap(
    rume_imported_table_count(mod_) + rume_defined_table_count(mod_),
  )
  let mem_remap = rume_identity_remap(
    rume_imported_mem_count(mod_) + rume_defined_mem_count(mod_),
  )
  let tag_remap = rume_identity_remap(
    rume_imported_tag_count(mod_) + rume_defined_tag_count(mod_),
  )
  let elem_remap = rume_identity_remap(
    match mod_.elem_sec {
      Some(@lib.ElemSec(elems)) => elems.length()
      None => 0
    },
  )
  let data_remap = rume_identity_remap(
    match mod_.data_sec {
      Some(@lib.DataSec(datas)) => datas.length()
      None => 0
    },
  )

  let next_import_sec = match mod_.import_sec {
    Some(@lib.ImportSec(imports)) => {
      let next : Array[@lib.Import] = []
      let mut func_idx = 0
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(_)) => {
            if used_funcs[func_idx] {
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

  let (next_func_sec, next_code_sec) = match (mod_.func_sec, mod_.code_sec) {
    (Some(@lib.FuncSec(type_idxs)), Some(@lib.CodeSec(funcs))) => {
      let next_type_idxs : Array[@lib.TypeIdx] = []
      let next_funcs : Array[@lib.Func] = []
      for def_idx in ordered_defined {
        match (type_idxs.get(def_idx), funcs.get(def_idx)) {
          (Some(type_idx), Some(@lib.Func(locals, body))) => {
            next_type_idxs.push(type_idx)
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
          _ => ()
        }
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
      for global in globals {
        let @lib.Global(global_type, init) = global
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
      for table in tables {
        let @lib.Table(table_type, init) = table
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
      if next.is_empty() {
        None
      } else {
        Some(@lib.TableSec::new(next))
      }
    }
    None => None
  }

  let next_export_sec = match mod_.export_sec {
    Some(@lib.ExportSec(exports)) => {
      let next : Array[@lib.Export] = []
      for export_ in exports {
        let @lib.Export(name, extern_idx) = export_
        next.push(
          @lib.Export::new(
            name,
            match extern_idx {
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
      if next.is_empty() {
        None
      } else {
        Some(@lib.ExportSec::new(next))
      }
    }
    None => None
  }

  let next_start_sec = match mod_.start_sec {
    Some(@lib.StartSec(func_idx)) =>
      Some(@lib.StartSec::new(rume_rewrite_func_idx(func_idx, func_remap)))
    None => None
  }

  let next_elem_sec = match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) => {
      let next : Array[@lib.Elem] = []
      for elem in elems {
        let @lib.Elem(mode, kind) = elem
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
      for data in datas {
        let @lib.Data(mode, bytes) = data
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
      if next.is_empty() {
        None
      } else {
        Some(@lib.DataSec::new(next))
      }
    }
    None => None
  }

  @lib.Module::new(
    custom_secs=mod_.custom_secs,
    type_sec=mod_.type_sec,
    import_sec=next_import_sec,
    func_annotation_sec=rume_rewrite_func_annotation_sec(
      mod_.func_annotation_sec,
      func_remap,
    ),
    func_sec=next_func_sec,
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
fn rume_normalize_extract_roots(
  mod_ : @lib.Module,
  roots : Array[@lib.FuncIdx],
) -> Result[Array[@lib.FuncIdx], String] {
  let total_funcs = rume_imported_func_count(mod_) +
    rume_defined_func_count(mod_)
  let seen = @bitset.BitSet::new(total_funcs)
  let normalized : Array[@lib.FuncIdx] = []
  for root in roots {
    let @lib.FuncIdx(raw_idx) = root
    let slot = raw_idx.reinterpret_as_int()
    if slot < 0 || slot >= total_funcs {
      return Err(
        "function index \{raw_idx} is out of range for module with \{total_funcs} functions",
      )
    }
    if !seen[slot] {
      seen[slot] = true
      normalized.push(root)
    }
  }
  if normalized.is_empty() {
    Err("function list is empty")
  } else {
    Ok(normalized)
  }
}

///|
pub fn rume_extract_functions(
  mod_ : @lib.Module,
  roots : Array[@lib.FuncIdx],
) -> Result[@lib.Module, String] {
  let normalized_roots = match rume_normalize_extract_roots(mod_, roots) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let rooted = rume_root_module_for_extract(mod_, normalized_roots)
  let (
    used_funcs,
    used_globals,
    used_tables,
    used_mems,
    used_tags,
    used_elems,
    used_datas,
  ) = rume_collect_liveness_with_import_parent_policy(rooted, false)
  let minimized = rume_apply_module_rewrite(
    rooted, used_funcs, used_globals, used_tables, used_mems, used_tags, used_elems,
    used_datas,
  )
  let (final_used_funcs, _, _, _, _, _, _) = rume_collect_liveness_with_import_parent_policy(
    minimized, false,
  )
  Ok(rume_rewrite_functions_only(minimized, final_used_funcs))
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
