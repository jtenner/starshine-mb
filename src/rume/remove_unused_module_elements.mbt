///|
pub fn rume_summary() -> String {
  "Remove unreachable defined functions, globals, tables, memories, tags, element segments, and data segments while rewriting surviving module indices."
}

///|
pub fn rume_nonfunction_summary() -> String {
  "Remove unused non-function module elements while keeping all defined functions."
}

///|
priv enum RumeItem {
  Func(UInt)
  Global(UInt)
  Table(UInt)
  Mem(UInt)
  Tag
  Elem(UInt)
  Data(UInt)
}

///|
priv struct RumeFlatTableInfo {
  all_elems : Array[@lib.ElemIdx]
  may_overlap : Bool
  has_init : Bool
}

///|
priv struct RumeCallTableAnalysis {
  env : @validate.Env
  func_types : Array[@lib.TypeIdx]
  flat_tables : Array[RumeFlatTableInfo]
  traps_never_happen : Bool
  closed_world : Bool
  referenced_funcs : @bitset.BitSet
  call_without_effects_funcs : @bitset.BitSet
  configure_all_funcs : @bitset.BitSet
  js_called_funcs : @bitset.BitSet
  mut call_all_referenced_funcs : Bool
  called_func_types : Array[@lib.TypeIdx]
  table_call_types : Array[Array[@lib.TypeIdx]]
  runtime_modified_tables : @bitset.BitSet
  queued_tables : @bitset.BitSet
  indirect_candidate_visits : Array[Int]?
  used_types : @bitset.BitSet?
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
pub fn rume_imported_global_count(mod_ : @lib.Module) -> Int {
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
        }
      }
    None => ()
  }
  (func_imports, table_imports, mem_imports, global_imports, tag_imports)
}

///|
fn rume_elem_init_has_effect(kind : @lib.ElemKind) -> Bool {
  match kind {
    @lib.FuncsElemKind(funcs) => funcs.length() > 0
    @lib.FuncExprsElemKind(exprs) | @lib.TypedExprsElemKind(_, exprs) =>
      exprs.length() > 0
  }
}

///|
fn rume_collect_func_types(mod_ : @lib.Module) -> Array[@lib.TypeIdx] {
  let types : Array[@lib.TypeIdx] = []
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(type_idx)) =>
            types.push(type_idx)
          _ => ()
        }
      }
    None => ()
  }
  match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) =>
      for type_idx in type_idxs {
        types.push(type_idx)
      }
    None => ()
  }
  types
}

///|
fn rume_func_matches_call_type(
  env : @validate.Env,
  func_types : Array[@lib.TypeIdx],
  func_idx : @lib.FuncIdx,
  call_type : @lib.TypeIdx,
) -> Bool {
  let @lib.FuncIdx(raw) = func_idx
  let slot = raw.reinterpret_as_int()
  if slot < 0 || slot >= func_types.length() {
    return false
  }
  @validate.Match::matches(
    @lib.ExternType::func(func_types[slot]),
    @lib.ExternType::func(call_type),
    env,
  )
}

///|
fn rume_note_callable_func_from_expr(
  env : @validate.Env,
  func_types : Array[@lib.TypeIdx],
  call_type : @lib.TypeIdx,
  expr : @lib.Expr,
) -> @lib.FuncIdx? {
  match expr {
    @lib.Expr([@lib.RefFunc(func_idx)]) =>
      if rume_func_matches_call_type(env, func_types, func_idx, call_type) {
        Some(func_idx)
      } else {
        None
      }
    _ => None
  }
}

///|
fn rume_spans_overlap(
  start_a : UInt64,
  len_a : UInt64,
  start_b : UInt64,
  len_b : UInt64,
) -> Bool {
  let end_a = start_a + len_a
  let end_b = start_b + len_b
  start_a < end_b && start_b < end_a
}

///|
fn rume_build_flat_table_infos(
  table_count : Int,
  mod_ : @lib.Module,
) -> Array[RumeFlatTableInfo] {
  let infos : Array[RumeFlatTableInfo] = []
  let mut table_idx = 0
  while table_idx < table_count {
    infos.push({ all_elems: [], may_overlap: false, has_init: false, })
    table_idx += 1
  }
  let table_imports = rume_imported_table_count(mod_)
  match mod_.table_sec {
    Some(@lib.TableSec(tables)) => {
      let mut def_idx = 0
      while def_idx < tables.length() {
        let abs = table_imports + def_idx
        if abs < infos.length() {
          match tables[def_idx] {
            @lib.Table(_, Some(_)) => {
              let prev = infos[abs]
              infos[abs] = {
                all_elems: prev.all_elems,
                may_overlap: prev.may_overlap,
                has_init: true,
              }
            }
            _ => ()
          }
        }
        def_idx += 1
      }
    }
    None => ()
  }
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) => {
      let mut elem_idx = 0
      while elem_idx < elems.length() {
        match elems[elem_idx] {
          @lib.Elem(@lib.Active(@lib.TableIdx(raw_table), _), kind) => {
            let table_slot = raw_table.reinterpret_as_int()
            if table_slot >= 0 &&
              table_slot < infos.length() &&
              rume_elem_init_has_effect(kind) {
              infos[table_slot].all_elems.push(
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
  let mut slot = 0
  while slot < infos.length() {
    let elems = infos[slot].all_elems
    if elems.length() > 1 {
      let mut may_overlap = false
      let spans : Array[(UInt64, UInt64)] = []
      for elem_idx in elems {
        match mod_.elem_sec {
          Some(@lib.ElemSec(all)) => {
            let @lib.ElemIdx(raw) = elem_idx
            match all.get(raw.reinterpret_as_int()) {
              Some(@lib.Elem(@lib.Active(_, offset), kind)) =>
                match rume_const_offset_u64(offset) {
                  None => may_overlap = true
                  Some(start) => {
                    let len = rume_elem_kind_len(kind)
                    for span in spans {
                      let (other_start, other_len) = span
                      if rume_spans_overlap(start, len, other_start, other_len) {
                        may_overlap = true
                      }
                    }
                    spans.push((start, len))
                  }
                }
              _ => ()
            }
          }
          None => ()
        }
      }
      let prev = infos[slot]
      infos[slot] = {
        all_elems: prev.all_elems,
        may_overlap,
        has_init: prev.has_init,
      }
    }
    slot += 1
  }
  infos
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
fn rume_record_declaring_elem_func(
  func_to_elems : Array[Array[@lib.ElemIdx]],
  elem_idx : @lib.ElemIdx,
  func_idx : @lib.FuncIdx,
) -> Unit {
  let @lib.FuncIdx(raw_idx) = func_idx
  let slot = raw_idx.reinterpret_as_int()
  if slot >= 0 && slot < func_to_elems.length() {
    func_to_elems[slot].push(elem_idx)
  }
}

///|
fn rume_record_declaring_elem_instr(
  instr : @lib.Instruction,
  elem_idx : @lib.ElemIdx,
  func_to_elems : Array[Array[@lib.ElemIdx]],
) -> Unit {
  match instr {
    @lib.Block(_, body) | @lib.Loop(_, body) =>
      rume_record_declaring_elem_expr(body, elem_idx, func_to_elems)
    @lib.If(_, then_body, else_body) => {
      for nested in then_body {
        rume_record_declaring_elem_instr(nested, elem_idx, func_to_elems)
      }
      match else_body {
        Some(body) =>
          for nested in body {
            rume_record_declaring_elem_instr(nested, elem_idx, func_to_elems)
          }
        None => ()
      }
    }
    @lib.Try(_, body, catches, _) => {
      rume_record_declaring_elem_expr(body, elem_idx, func_to_elems)
      for catch_ in catches {
        match catch_ {
          @lib.LegacyCatch(_, catch_body) | @lib.LegacyCatchAll(catch_body) =>
            rume_record_declaring_elem_expr(catch_body, elem_idx, func_to_elems)
        }
      }
    }
    @lib.TryTable(_, _, body) =>
      rume_record_declaring_elem_expr(body, elem_idx, func_to_elems)
    @lib.RefFunc(func_idx) =>
      rume_record_declaring_elem_func(func_to_elems, elem_idx, func_idx)
    _ => ()
  }
}

///|
fn rume_record_declaring_elem_expr(
  expr : @lib.Expr,
  elem_idx : @lib.ElemIdx,
  func_to_elems : Array[Array[@lib.ElemIdx]],
) -> Unit {
  let @lib.Expr(instrs) = expr
  for instr in instrs {
    rume_record_declaring_elem_instr(instr, elem_idx, func_to_elems)
  }
}

///|
fn rume_record_declaring_elem_kind(
  kind : @lib.ElemKind,
  elem_idx : @lib.ElemIdx,
  func_to_elems : Array[Array[@lib.ElemIdx]],
) -> Unit {
  match kind {
    @lib.FuncsElemKind(funcs) =>
      for func_idx in funcs {
        rume_record_declaring_elem_func(func_to_elems, elem_idx, func_idx)
      }
    @lib.FuncExprsElemKind(exprs) | @lib.TypedExprsElemKind(_, exprs) =>
      for expr in exprs {
        rume_record_declaring_elem_expr(expr, elem_idx, func_to_elems)
      }
  }
}

///|
fn rume_build_func_to_declaring_elem_map(
  func_count : Int,
  mod_ : @lib.Module,
) -> Array[Array[@lib.ElemIdx]] {
  let func_to_elems : Array[Array[@lib.ElemIdx]] = []
  let mut func_idx = 0
  while func_idx < func_count {
    func_to_elems.push([])
    func_idx += 1
  }
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) => {
      let mut elem_idx = 0
      while elem_idx < elems.length() {
        let @lib.Elem(_, kind) = elems[elem_idx]
        rume_record_declaring_elem_kind(
          kind,
          @lib.ElemIdx::new(elem_idx.reinterpret_as_uint()),
          func_to_elems,
        )
        elem_idx += 1
      }
    }
    None => ()
  }
  func_to_elems
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
fn rume_mark_declaring_elem(
  used_elems : @bitset.BitSet,
  decl_only_elems : @bitset.BitSet,
  idx : @lib.ElemIdx,
) -> Unit {
  let @lib.ElemIdx(raw) = idx
  let slot = raw.reinterpret_as_int()
  if slot >= 0 && slot < used_elems.length() {
    used_elems[slot] = true
    decl_only_elems[slot] = true
  }
}

///|
fn rume_special_imported_funcs(
  mod_ : @lib.Module,
  func_count : Int,
  module_name : String,
  base_name : String,
) -> @bitset.BitSet {
  let matches = @bitset.BitSet::new(func_count)
  let mut func_idx = 0
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(module_, name, @lib.FuncExternType(_)) => {
            let @lib.Name(module_text) = module_
            let @lib.Name(name_text) = name
            if module_text == module_name && name_text == base_name {
              matches[func_idx] = true
            }
            func_idx += 1
          }
          _ => ()
        }
      }
    None => ()
  }
  matches
}

///|
fn rume_js_called_funcs(mod_ : @lib.Module, func_count : Int) -> @bitset.BitSet {
  let matches = @bitset.BitSet::new(func_count)
  match mod_.func_annotation_sec {
    Some(@lib.FuncAnnotationSec(entries)) =>
      for entry in entries {
        let @lib.FuncAnnotationAssoc(annotation_idx, annotations) = entry
        let slot = annotation_idx.reinterpret_as_int()
        if slot >= 0 && slot < matches.length() {
          for annotation in annotations {
            if annotation.name == "binaryen.js.called" {
              matches[slot] = true
            }
          }
        }
      }
    None => ()
  }
  matches
}

///|
fn rume_func_bitset_contains(
  funcs : @bitset.BitSet,
  idx : @lib.FuncIdx,
) -> Bool {
  let @lib.FuncIdx(raw_idx) = idx
  let slot = raw_idx.reinterpret_as_int()
  slot >= 0 && slot < funcs.length() && funcs[slot]
}

///|
fn rume_type_idx_array_contains(
  types : Array[@lib.TypeIdx],
  target : @lib.TypeIdx,
) -> Bool {
  for type_idx in types {
    if type_idx == target {
      return true
    }
  }
  false
}

///|
fn rume_func_matches_any_call_type(
  analysis : RumeCallTableAnalysis,
  idx : @lib.FuncIdx,
) -> Bool {
  for call_type in analysis.called_func_types {
    if rume_func_matches_call_type(
        analysis.env,
        analysis.func_types,
        idx,
        call_type,
      ) {
      return true
    }
  }
  false
}

///|
fn rume_use_all_referenced_funcs(
  analysis : RumeCallTableAnalysis,
  queue : Array[RumeItem],
  used_funcs : @bitset.BitSet,
) -> Unit {
  analysis.call_all_referenced_funcs = true
  let mut slot = 0
  while slot < analysis.referenced_funcs.length() {
    if analysis.referenced_funcs[slot] {
      rume_mark_func(
        queue,
        used_funcs,
        @lib.FuncIdx::new(slot.reinterpret_as_uint()),
      )
    }
    slot += 1
  }
}

///|
fn rume_use_call_ref_type(
  analysis : RumeCallTableAnalysis,
  queue : Array[RumeItem],
  used_funcs : @bitset.BitSet,
  call_type : @lib.TypeIdx,
) -> Unit {
  if !rume_type_idx_array_contains(analysis.called_func_types, call_type) {
    analysis.called_func_types.push(call_type)
  }
  let mut slot = 0
  while slot < analysis.referenced_funcs.length() {
    if analysis.referenced_funcs[slot] &&
      rume_func_matches_call_type(
        analysis.env,
        analysis.func_types,
        @lib.FuncIdx::new(slot.reinterpret_as_uint()),
        call_type,
      ) {
      rume_mark_func(
        queue,
        used_funcs,
        @lib.FuncIdx::new(slot.reinterpret_as_uint()),
      )
    }
    slot += 1
  }
}

///|
fn rume_cont_func_type(
  analysis : RumeCallTableAnalysis,
  cont_type : @lib.TypeIdx,
) -> @lib.TypeIdx? {
  match analysis.env.resolve_comptype(cont_type) {
    Some(@lib.ContCompType(func_type)) => Some(func_type)
    _ => None
  }
}

///|
fn rume_val_type_func_type(val_type : @lib.ValType) -> @lib.TypeIdx? {
  match val_type {
    @lib.RefTypeValType(@lib.HeapTypeRefType(_, _, @lib.HeapType(type_idx))) =>
      Some(type_idx)
    _ => None
  }
}

///|
fn rume_call_ref_type_from_operand(
  mod_ : @lib.Module,
  previous : @lib.Instruction?,
  func_locals : @lib.FunctionLocals?,
) -> @lib.TypeIdx? {
  match previous {
    Some(@lib.LocalGet(local_idx)) =>
      match func_locals {
        Some(locals) =>
          match locals.local_type(local_idx) {
            Some(val_type) => rume_val_type_func_type(val_type)
            None => None
          }
        None => None
      }
    Some(@lib.GlobalGet(global_idx)) =>
      match rume_lookup_global_type(mod_, global_idx) {
        Some(@lib.GlobalType(val_type, _)) => rume_val_type_func_type(val_type)
        None => None
      }
    Some(@lib.RefNull(ref_type)) =>
      rume_val_type_func_type(@lib.ValType::ref_type(ref_type))
    _ => None
  }
}

///|
fn rume_note_ref_func_liveness(
  analysis : RumeCallTableAnalysis,
  queue : Array[RumeItem],
  used_funcs : @bitset.BitSet,
  idx : @lib.FuncIdx,
) -> Unit {
  if !analysis.closed_world ||
    analysis.call_all_referenced_funcs ||
    rume_func_bitset_contains(analysis.js_called_funcs, idx) ||
    rume_func_matches_any_call_type(analysis, idx) {
    rume_mark_func(queue, used_funcs, idx)
  } else {
    rume_reference_func(used_funcs, analysis.referenced_funcs, idx)
  }
}

///|
fn rume_mark_ref_func(
  mod_ : @lib.Module,
  analysis : RumeCallTableAnalysis,
  queue : Array[RumeItem],
  used_funcs : @bitset.BitSet,
  used_elems : @bitset.BitSet,
  decl_only_elems : @bitset.BitSet,
  func_to_declaring_elems : Array[Array[@lib.ElemIdx]],
  idx : @lib.FuncIdx,
) -> Unit {
  rume_note_ref_func_liveness(analysis, queue, used_funcs, idx)
  let @lib.FuncIdx(raw) = idx
  let slot = raw.reinterpret_as_int()
  if slot >= 0 && slot < func_to_declaring_elems.length() {
    for elem_idx in func_to_declaring_elems[slot] {
      rume_mark_declaring_elem(used_elems, decl_only_elems, elem_idx)
      rume_note_declaring_expr_ref_func_siblings(
        mod_, analysis, queue, used_funcs, elem_idx, idx,
      )
    }
  }
}

///|
fn rume_mark_defined_funcs(
  queue : Array[RumeItem],
  used_funcs : @bitset.BitSet,
  func_imports : Int,
) -> Unit {
  let mut idx = func_imports
  while idx < used_funcs.length() {
    rume_mark_func(
      queue,
      used_funcs,
      @lib.FuncIdx::new(idx.reinterpret_as_uint()),
    )
    idx += 1
  }
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
  queued_tables : @bitset.BitSet,
  idx : @lib.TableIdx,
) -> Unit {
  let @lib.TableIdx(raw) = idx
  let slot = raw.reinterpret_as_int()
  if slot < 0 || slot >= used_tables.length() {
    return
  }
  used_tables[slot] = true
  if queued_tables[slot] {
    return
  }
  queued_tables[slot] = true
  queue.push(RumeItem::Table(raw))
}

///|
fn rume_keep_table(used_tables : @bitset.BitSet, idx : @lib.TableIdx) -> Unit {
  let @lib.TableIdx(raw) = idx
  let slot = raw.reinterpret_as_int()
  if slot >= 0 && slot < used_tables.length() {
    used_tables[slot] = true
  }
}

///|
fn rume_reference_func(
  used_funcs : @bitset.BitSet,
  referenced_funcs : @bitset.BitSet,
  idx : @lib.FuncIdx,
) -> Unit {
  let @lib.FuncIdx(raw) = idx
  let slot = raw.reinterpret_as_int()
  if slot < 0 || slot >= referenced_funcs.length() || used_funcs[slot] {
    return
  }
  referenced_funcs[slot] = true
}

///|
fn rume_scan_ref_func_liveness_instr(
  instr : @lib.Instruction,
  analysis : RumeCallTableAnalysis,
  queue : Array[RumeItem],
  used_funcs : @bitset.BitSet,
  strong : Bool,
) -> Unit {
  match instr {
    @lib.Block(_, body) | @lib.Loop(_, body) =>
      rume_scan_ref_func_liveness_expr(
        body, analysis, queue, used_funcs, strong,
      )
    @lib.If(_, then_body, else_body) => {
      for nested in then_body {
        rume_scan_ref_func_liveness_instr(
          nested, analysis, queue, used_funcs, strong,
        )
      }
      match else_body {
        Some(body) =>
          for nested in body {
            rume_scan_ref_func_liveness_instr(
              nested, analysis, queue, used_funcs, strong,
            )
          }
        None => ()
      }
    }
    @lib.Try(_, body, catches, _) => {
      rume_scan_ref_func_liveness_expr(
        body, analysis, queue, used_funcs, strong,
      )
      for catch_ in catches {
        let catch_body = match catch_ {
          @lib.LegacyCatch(_, catch_body) | @lib.LegacyCatchAll(catch_body) =>
            catch_body
        }
        rume_scan_ref_func_liveness_expr(
          catch_body, analysis, queue, used_funcs, strong,
        )
      }
    }
    @lib.TryTable(_, _, body) =>
      rume_scan_ref_func_liveness_expr(
        body, analysis, queue, used_funcs, strong,
      )
    @lib.RefFunc(func_idx) =>
      if strong {
        rume_mark_func(queue, used_funcs, func_idx)
      } else {
        rume_reference_func(used_funcs, analysis.referenced_funcs, func_idx)
      }
    _ => ()
  }
}

///|
fn rume_scan_ref_func_liveness_expr(
  expr : @lib.Expr,
  analysis : RumeCallTableAnalysis,
  queue : Array[RumeItem],
  used_funcs : @bitset.BitSet,
  strong : Bool,
) -> Unit {
  let @lib.Expr(instrs) = expr
  for instr in instrs {
    rume_scan_ref_func_liveness_instr(
      instr, analysis, queue, used_funcs, strong,
    )
  }
}

///|
fn rume_instr_contains_ref_func(
  instr : @lib.Instruction,
  target : @lib.FuncIdx,
) -> Bool {
  match instr {
    @lib.Block(_, body) | @lib.Loop(_, body) =>
      rume_expr_contains_ref_func(body, target)
    @lib.If(_, then_body, else_body) => {
      for nested in then_body {
        if rume_instr_contains_ref_func(nested, target) {
          return true
        }
      }
      match else_body {
        Some(body) =>
          for nested in body {
            if rume_instr_contains_ref_func(nested, target) {
              return true
            }
          }
        None => ()
      }
      false
    }
    @lib.Try(_, body, catches, _) => {
      if rume_expr_contains_ref_func(body, target) {
        return true
      }
      for catch_ in catches {
        let catch_body = match catch_ {
          @lib.LegacyCatch(_, catch_body) | @lib.LegacyCatchAll(catch_body) =>
            catch_body
        }
        if rume_expr_contains_ref_func(catch_body, target) {
          return true
        }
      }
      false
    }
    @lib.TryTable(_, _, body) => rume_expr_contains_ref_func(body, target)
    @lib.RefFunc(func_idx) => func_idx == target
    _ => false
  }
}

///|
fn rume_expr_contains_ref_func(expr : @lib.Expr, target : @lib.FuncIdx) -> Bool {
  let @lib.Expr(instrs) = expr
  for instr in instrs {
    if rume_instr_contains_ref_func(instr, target) {
      return true
    }
  }
  false
}

///|
fn rume_note_declaring_expr_ref_func_siblings(
  mod_ : @lib.Module,
  analysis : RumeCallTableAnalysis,
  queue : Array[RumeItem],
  used_funcs : @bitset.BitSet,
  elem_idx : @lib.ElemIdx,
  target : @lib.FuncIdx,
) -> Unit {
  let @lib.ElemIdx(raw) = elem_idx
  let slot = raw.reinterpret_as_int()
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) =>
      match elems.get(slot) {
        Some(@lib.Elem(_, kind)) =>
          match kind {
            @lib.FuncsElemKind(_) => ()
            @lib.FuncExprsElemKind(exprs) | @lib.TypedExprsElemKind(_, exprs) =>
              for expr in exprs {
                if rume_expr_contains_ref_func(expr, target) {
                  rume_scan_ref_func_liveness_expr(
                    expr, analysis, queue, used_funcs, false,
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
fn rume_reference_elem_payload(
  mod_ : @lib.Module,
  analysis : RumeCallTableAnalysis,
  used_funcs : @bitset.BitSet,
  used_elems : @bitset.BitSet,
  queue : Array[RumeItem],
  used_globals : @bitset.BitSet,
  elem_idx : @lib.ElemIdx,
) -> Unit {
  let @lib.ElemIdx(raw) = elem_idx
  let slot = raw.reinterpret_as_int()
  if slot < 0 || slot >= used_elems.length() {
    return
  }
  let already_kept = used_elems[slot]
  used_elems[slot] = true
  if already_kept {
    return
  }
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) =>
      match elems.get(slot) {
        Some(@lib.Elem(mode, kind)) => {
          match mode {
            @lib.Active(_, offset) =>
              match offset {
                @lib.Expr(instrs) =>
                  for instr in instrs {
                    match instr {
                      @lib.GlobalGet(global_idx) | @lib.GlobalSet(global_idx) =>
                        rume_mark_global(queue, used_globals, global_idx)
                      _ => ()
                    }
                  }
              }
            _ => ()
          }
          match kind {
            @lib.FuncsElemKind(funcs) =>
              for func_idx in funcs {
                rume_reference_func(
                  used_funcs,
                  analysis.referenced_funcs,
                  func_idx,
                )
              }
            @lib.FuncExprsElemKind(exprs) | @lib.TypedExprsElemKind(_, exprs) =>
              for expr in exprs {
                rume_scan_ref_func_liveness_expr(
                  expr, analysis, queue, used_funcs, false,
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
fn rume_reference_table_init(
  mod_ : @lib.Module,
  analysis : RumeCallTableAnalysis,
  table_imports : Int,
  queue : Array[RumeItem],
  used_funcs : @bitset.BitSet,
  idx : @lib.TableIdx,
) -> Unit {
  let @lib.TableIdx(raw) = idx
  let def_idx = raw.reinterpret_as_int() - table_imports
  if def_idx < 0 {
    return
  }
  match mod_.table_sec {
    Some(@lib.TableSec(tables)) =>
      match tables.get(def_idx) {
        Some(@lib.Table(_, Some(init))) =>
          rume_scan_ref_func_liveness_expr(
            init, analysis, queue, used_funcs, false,
          )
        _ => ()
      }
    None => ()
  }
}

///|
fn rume_note_table_call_type(
  analysis : RumeCallTableAnalysis,
  table_idx : @lib.TableIdx,
  call_type : @lib.TypeIdx,
) -> Bool {
  let @lib.TableIdx(raw_table) = table_idx
  let slot = raw_table.reinterpret_as_int()
  if slot < 0 || slot >= analysis.table_call_types.length() {
    return false
  }
  if rume_type_idx_array_contains(analysis.table_call_types[slot], call_type) {
    return false
  }
  analysis.table_call_types[slot].push(call_type)
  true
}

///|
fn rume_note_table_runtime_modification(
  analysis : RumeCallTableAnalysis,
  queue : Array[RumeItem],
  used_funcs : @bitset.BitSet,
  table_idx : @lib.TableIdx,
) -> Unit {
  if !analysis.closed_world {
    return
  }
  let @lib.TableIdx(raw_table) = table_idx
  let slot = raw_table.reinterpret_as_int()
  if slot < 0 || slot >= analysis.runtime_modified_tables.length() {
    return
  }
  analysis.runtime_modified_tables[slot] = true
  for call_type in analysis.table_call_types[slot] {
    rume_use_call_ref_type(analysis, queue, used_funcs, call_type)
  }
}

///|
fn rume_use_indirect_call(
  mod_ : @lib.Module,
  analysis : RumeCallTableAnalysis,
  table_imports : Int,
  queue : Array[RumeItem],
  used_funcs : @bitset.BitSet,
  used_globals : @bitset.BitSet,
  used_tables : @bitset.BitSet,
  used_elems : @bitset.BitSet,
  call_type : @lib.TypeIdx,
  table_idx : @lib.TableIdx,
) -> Unit {
  rume_keep_table(used_tables, table_idx)
  if !rume_note_table_call_type(analysis, table_idx, call_type) {
    return
  }
  let @lib.TableIdx(runtime_raw_table) = table_idx
  let runtime_table_slot = runtime_raw_table.reinterpret_as_int()
  if analysis.closed_world &&
    runtime_table_slot >= 0 &&
    runtime_table_slot < analysis.runtime_modified_tables.length() &&
    analysis.runtime_modified_tables[runtime_table_slot] {
    rume_use_call_ref_type(analysis, queue, used_funcs, call_type)
  }
  rume_reference_table_init(
    mod_, analysis, table_imports, queue, used_funcs, table_idx,
  )
  let @lib.TableIdx(raw_table) = table_idx
  let table_slot = raw_table.reinterpret_as_int()
  if table_slot < 0 || table_slot >= analysis.flat_tables.length() {
    return
  }
  let info = analysis.flat_tables[table_slot]
  match mod_.table_sec {
    Some(@lib.TableSec(tables)) => {
      let def_idx = table_slot - table_imports
      if def_idx >= 0 {
        match tables.get(def_idx) {
          Some(@lib.Table(_, Some(init))) =>
            match
              rume_note_callable_func_from_expr(
                analysis.env,
                analysis.func_types,
                call_type,
                init,
              ) {
              Some(func_idx) => rume_mark_func(queue, used_funcs, func_idx)
              None => ()
            }
          _ => ()
        }
      }
    }
    None => ()
  }
  for elem_idx in info.all_elems {
    let @lib.ElemIdx(raw_elem) = elem_idx
    match mod_.elem_sec {
      Some(@lib.ElemSec(elems)) =>
        match elems.get(raw_elem.reinterpret_as_int()) {
          Some(@lib.Elem(_, kind)) => {
            let mut matches_call = false
            match kind {
              @lib.FuncsElemKind(funcs) =>
                for func_idx in funcs {
                  match analysis.indirect_candidate_visits {
                    Some(visits) => visits[0] += 1
                    None => ()
                  }
                  if rume_func_matches_call_type(
                      analysis.env,
                      analysis.func_types,
                      func_idx,
                      call_type,
                    ) {
                    matches_call = true
                    rume_mark_func(queue, used_funcs, func_idx)
                  }
                }
              @lib.FuncExprsElemKind(exprs)
              | @lib.TypedExprsElemKind(_, exprs) =>
                for expr in exprs {
                  match analysis.indirect_candidate_visits {
                    Some(visits) => visits[0] += 1
                    None => ()
                  }
                  match
                    rume_note_callable_func_from_expr(
                      analysis.env,
                      analysis.func_types,
                      call_type,
                      expr,
                    ) {
                    Some(func_idx) => {
                      matches_call = true
                      rume_mark_func(queue, used_funcs, func_idx)
                    }
                    None => ()
                  }
                }
            }
            if matches_call {
              rume_reference_elem_payload(
                mod_, analysis, used_funcs, used_elems, queue, used_globals, elem_idx,
              )
            }
          }
          None => ()
        }
      None => ()
    }
  }
  if !analysis.traps_never_happen && (info.has_init || info.may_overlap) {
    for elem_idx in info.all_elems {
      rume_reference_elem_payload(
        mod_, analysis, used_funcs, used_elems, queue, used_globals, elem_idx,
      )
    }
  }
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
  queue.push(RumeItem::Tag)
}

///|
fn rume_mark_elem(
  queue : Array[RumeItem],
  used_elems : @bitset.BitSet,
  decl_only_elems : @bitset.BitSet,
  idx : @lib.ElemIdx,
) -> Unit {
  let @lib.ElemIdx(raw) = idx
  let slot = raw.reinterpret_as_int()
  if slot < 0 || slot >= used_elems.length() {
    return
  }
  let was_declaration_only = decl_only_elems[slot]
  if used_elems[slot] && !was_declaration_only {
    return
  }
  used_elems[slot] = true
  decl_only_elems[slot] = false
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
fn rume_scan_resume_handlers(
  handlers : Array[@lib.ResumeHandler],
  queue : Array[RumeItem],
  used_tags : @bitset.BitSet,
) -> Unit {
  for handler in handlers {
    let tag_idx = match handler {
      @lib.ResumeOnLabel(tag_idx, _) | @lib.ResumeOnSwitch(tag_idx) => tag_idx
    }
    rume_mark_tag(queue, used_tags, tag_idx)
  }
}

///|
fn rume_mark_elem_funcs(
  mod_ : @lib.Module,
  analysis : RumeCallTableAnalysis,
  elem_idx : @lib.ElemIdx,
  queue : Array[RumeItem],
  used_funcs : @bitset.BitSet,
) -> Unit {
  let @lib.ElemIdx(raw_idx) = elem_idx
  let slot = raw_idx.reinterpret_as_int()
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) =>
      match elems.get(slot) {
        Some(@lib.Elem(_, kind)) =>
          match kind {
            @lib.FuncsElemKind(funcs) =>
              for func_idx in funcs {
                rume_mark_func(queue, used_funcs, func_idx)
              }
            @lib.FuncExprsElemKind(exprs) | @lib.TypedExprsElemKind(_, exprs) =>
              for expr in exprs {
                rume_scan_ref_func_liveness_expr(
                  expr, analysis, queue, used_funcs, true,
                )
              }
          }
        None => ()
      }
    None => ()
  }
}

///|
fn rume_direct_call_signature(
  analysis : RumeCallTableAnalysis,
  func_idx : @lib.FuncIdx,
) -> @lib.FuncType? {
  analysis.env.get_functype_by_funcidx(func_idx)
}

///|
fn rume_single_result_block_operand_count(
  analysis : RumeCallTableAnalysis,
  block_type : @lib.BlockType,
  condition_count : Int,
) -> Int? {
  match block_type {
    @lib.VoidBlockType => None
    @lib.ValTypeBlockType(_) => Some(condition_count)
    @lib.TypeIdxBlockType(type_idx) =>
      match analysis.env.resolve_functype(type_idx) {
        Some(@lib.FuncType(params, results)) if results.length() == 1 =>
          Some(params.length() + condition_count)
        _ => None
      }
  }
}

///|
fn rume_single_result_operand_count(
  analysis : RumeCallTableAnalysis,
  instr : @lib.Instruction,
) -> Int? {
  match instr {
    @lib.I32Const(_)
    | @lib.I64Const(_)
    | @lib.F32Const(_)
    | @lib.F64Const(_)
    | @lib.V128Const(_)
    | @lib.RefNull(_)
    | @lib.RefFunc(_)
    | @lib.StringConst(_)
    | @lib.LocalGet(_)
    | @lib.GlobalGet(_)
    | @lib.MemorySize(_)
    | @lib.TableSize(_)
    | @lib.StructNewDefault(_) => Some(0)
    @lib.I32Eqz
    | @lib.I64Eqz
    | @lib.RefIsNull
    | @lib.RefAsNonNull
    | @lib.RefGetDesc(_)
    | @lib.RefCast(_, _, _)
    | @lib.RefTest(_, _, _)
    | @lib.RefTestDesc(_, _)
    | @lib.AnyConvertExtern
    | @lib.ExternConvertAny
    | @lib.RefI31
    | @lib.I31GetS
    | @lib.I31GetU
    | @lib.I32Clz
    | @lib.I32Ctz
    | @lib.I32Popcnt
    | @lib.I64Clz
    | @lib.I64Ctz
    | @lib.I64Popcnt
    | @lib.F32Abs
    | @lib.F32Neg
    | @lib.F32Ceil
    | @lib.F32Floor
    | @lib.F32Trunc
    | @lib.F32Nearest
    | @lib.F32Sqrt
    | @lib.F64Abs
    | @lib.F64Neg
    | @lib.F64Ceil
    | @lib.F64Floor
    | @lib.F64Trunc
    | @lib.F64Nearest
    | @lib.F64Sqrt
    | @lib.I32WrapI64
    | @lib.I32TruncF32S
    | @lib.I32TruncF32U
    | @lib.I32TruncF64S
    | @lib.I32TruncF64U
    | @lib.I64ExtendI32S
    | @lib.I64ExtendI32U
    | @lib.I64TruncF32S
    | @lib.I64TruncF32U
    | @lib.I64TruncF64S
    | @lib.I64TruncF64U
    | @lib.F32ConvertI32S
    | @lib.F32ConvertI32U
    | @lib.F32ConvertI64S
    | @lib.F32ConvertI64U
    | @lib.F32DemoteF64
    | @lib.F64ConvertI32S
    | @lib.F64ConvertI32U
    | @lib.F64ConvertI64S
    | @lib.F64ConvertI64U
    | @lib.F64PromoteF32
    | @lib.I32ReinterpretF32
    | @lib.I64ReinterpretF64
    | @lib.F32ReinterpretI32
    | @lib.F64ReinterpretI64
    | @lib.I32Extend8S
    | @lib.I32Extend16S
    | @lib.I64Extend8S
    | @lib.I64Extend16S
    | @lib.I64Extend32S
    | @lib.I32TruncSatF32S
    | @lib.I32TruncSatF32U
    | @lib.I32TruncSatF64S
    | @lib.I32TruncSatF64U
    | @lib.I64TruncSatF32S
    | @lib.I64TruncSatF32U
    | @lib.I64TruncSatF64S
    | @lib.I64TruncSatF64U
    | @lib.I32Load(_)
    | @lib.I64Load(_)
    | @lib.F32Load(_)
    | @lib.F64Load(_)
    | @lib.I32Load8S(_)
    | @lib.I32Load8U(_)
    | @lib.I32Load16S(_)
    | @lib.I32Load16U(_)
    | @lib.I64Load8S(_)
    | @lib.I64Load8U(_)
    | @lib.I64Load16S(_)
    | @lib.I64Load16U(_)
    | @lib.I64Load32S(_)
    | @lib.I64Load32U(_)
    | @lib.StructGet(_, _)
    | @lib.StructGetS(_, _)
    | @lib.StructGetU(_, _)
    | @lib.ArrayLen
    | @lib.LocalTee(_)
    | @lib.MemoryGrow(_)
    | @lib.TableGet(_) => Some(1)
    @lib.I32Eq
    | @lib.I32Ne
    | @lib.I32LtS
    | @lib.I32LtU
    | @lib.I32GtS
    | @lib.I32GtU
    | @lib.I32LeS
    | @lib.I32LeU
    | @lib.I32GeS
    | @lib.I32GeU
    | @lib.I64Eq
    | @lib.I64Ne
    | @lib.I64LtS
    | @lib.I64LtU
    | @lib.I64GtS
    | @lib.I64GtU
    | @lib.I64LeS
    | @lib.I64LeU
    | @lib.I64GeS
    | @lib.I64GeU
    | @lib.F32Eq
    | @lib.F32Ne
    | @lib.F32Lt
    | @lib.F32Gt
    | @lib.F32Le
    | @lib.F32Ge
    | @lib.F64Eq
    | @lib.F64Ne
    | @lib.F64Lt
    | @lib.F64Gt
    | @lib.F64Le
    | @lib.F64Ge
    | @lib.I32Add
    | @lib.I32Sub
    | @lib.I32Mul
    | @lib.I32DivS
    | @lib.I32DivU
    | @lib.I32RemS
    | @lib.I32RemU
    | @lib.I32And
    | @lib.I32Or
    | @lib.I32Xor
    | @lib.I32Shl
    | @lib.I32ShrS
    | @lib.I32ShrU
    | @lib.I32Rotl
    | @lib.I32Rotr
    | @lib.I64Add
    | @lib.I64Sub
    | @lib.I64Mul
    | @lib.I64DivS
    | @lib.I64DivU
    | @lib.I64RemS
    | @lib.I64RemU
    | @lib.I64And
    | @lib.I64Or
    | @lib.I64Xor
    | @lib.I64Shl
    | @lib.I64ShrS
    | @lib.I64ShrU
    | @lib.I64Rotl
    | @lib.I64Rotr
    | @lib.F32Add
    | @lib.F32Sub
    | @lib.F32Mul
    | @lib.F32Div
    | @lib.F32Min
    | @lib.F32Max
    | @lib.F32Copysign
    | @lib.F64Add
    | @lib.F64Sub
    | @lib.F64Mul
    | @lib.F64Div
    | @lib.F64Min
    | @lib.F64Max
    | @lib.F64Copysign
    | @lib.RefEq
    | @lib.ArrayGet(_)
    | @lib.ArrayGetS(_)
    | @lib.ArrayGetU(_)
    | @lib.RefCastDescEq(_, _, _)
    | @lib.TableGrow(_) => Some(2)
    @lib.Select(_) => Some(3)
    @lib.ArrayNew(_) => Some(2)
    @lib.ArrayNewDefault(_) => Some(1)
    @lib.ArrayNewFixed(_, @lib.U32(raw_len)) => {
      let count = raw_len.reinterpret_as_int()
      if count < 0 {
        None
      } else {
        Some(count)
      }
    }
    @lib.ArrayNewData(_, _) | @lib.ArrayNewElem(_, _) => Some(2)
    @lib.Call(func_idx) =>
      match rume_direct_call_signature(analysis, func_idx) {
        Some(@lib.FuncType(params, results)) if results.length() == 1 =>
          Some(params.length())
        _ => None
      }
    @lib.CallIndirect(type_idx, _) | @lib.CallRef(type_idx) =>
      match analysis.env.resolve_functype(type_idx) {
        Some(@lib.FuncType(params, results)) if results.length() == 1 =>
          Some(params.length() + 1)
        _ => None
      }
    @lib.Block(block_type, _)
    | @lib.Loop(block_type, _)
    | @lib.Try(block_type, _, _, _)
    | @lib.TryTable(block_type, _, _) =>
      rume_single_result_block_operand_count(analysis, block_type, 0)
    @lib.If(block_type, _, _) =>
      rume_single_result_block_operand_count(analysis, block_type, 1)
    _ => None
  }
}

///|
fn rume_single_value_expr_start(
  analysis : RumeCallTableAnalysis,
  instrs : Array[@lib.Instruction],
  end_inclusive : Int,
) -> Int {
  let mut needed = 1
  let mut idx = end_inclusive
  while idx >= 0 {
    let operands = match
      rume_single_result_operand_count(analysis, instrs[idx]) {
      Some(count) => count
      None => return -1
    }
    needed -= 1
    if needed < 0 {
      return -1
    }
    needed += operands
    if needed == 0 {
      return idx
    }
    idx -= 1
  }
  -1
}

///|
fn rume_elem_is_exact_ref_func_payload(
  mod_ : @lib.Module,
  elem_idx : @lib.ElemIdx,
  expected_size : Int,
) -> Bool {
  if expected_size < 0 {
    return false
  }
  let @lib.ElemIdx(raw_idx) = elem_idx
  let slot = raw_idx.reinterpret_as_int()
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) =>
      match elems.get(slot) {
        Some(@lib.Elem(_, @lib.FuncsElemKind(funcs))) =>
          funcs.length() == expected_size
        Some(@lib.Elem(_, @lib.FuncExprsElemKind(exprs)))
        | Some(@lib.Elem(_, @lib.TypedExprsElemKind(_, exprs))) => {
          if exprs.length() != expected_size {
            return false
          }
          for expr in exprs {
            if !(expr is @lib.Expr([@lib.RefFunc(_)])) {
              return false
            }
          }
          true
        }
        None => false
      }
    None => false
  }
}

///|
fn rume_configure_all_elem_operand(
  mod_ : @lib.Module,
  analysis : RumeCallTableAnalysis,
  instrs : Array[@lib.Instruction],
  call_index : Int,
  func_idx : @lib.FuncIdx,
) -> @lib.ElemIdx? {
  let param_count = match rume_direct_call_signature(analysis, func_idx) {
    Some(@lib.FuncType(params, _)) => params.length()
    None => return None
  }
  if param_count < 2 || call_index <= 0 {
    return None
  }
  let mut target_end = call_index - 1
  let mut later_operand = param_count - 1
  while later_operand > 1 {
    let start = rume_single_value_expr_start(analysis, instrs, target_end)
    if start < 0 {
      return None
    }
    target_end = start - 1
    later_operand -= 1
  }
  if target_end < 0 {
    return None
  }
  let target_start = rume_single_value_expr_start(analysis, instrs, target_end)
  if target_start < 0 {
    return None
  }
  let elem_idx = match instrs[target_end] {
    @lib.ArrayNewElem(_, elem_idx) => elem_idx
    _ => return None
  }
  let size_end = target_end - 1
  let size_start = rume_single_value_expr_start(analysis, instrs, size_end)
  if size_start != size_end {
    return None
  }
  let size = match instrs[size_end] {
    @lib.I32Const(@lib.I32(value)) => value
    _ => return None
  }
  let offset_end = size_start - 1
  let offset_start = rume_single_value_expr_start(analysis, instrs, offset_end)
  if offset_start != offset_end || offset_start != target_start {
    return None
  }
  match instrs[offset_end] {
    @lib.I32Const(@lib.I32(0)) => ()
    _ => return None
  }
  if rume_elem_is_exact_ref_func_payload(mod_, elem_idx, size) {
    Some(elem_idx)
  } else {
    None
  }
}

///|
fn rume_process_direct_call(
  func_idx : @lib.FuncIdx,
  mod_ : @lib.Module,
  analysis : RumeCallTableAnalysis,
  queue : Array[RumeItem],
  used_funcs : @bitset.BitSet,
  previous : @lib.Instruction?,
  func_locals : @lib.FunctionLocals?,
  instrs : Array[@lib.Instruction],
  call_index : Int,
) -> Unit {
  rume_mark_func(queue, used_funcs, func_idx)
  if analysis.closed_world &&
    rume_func_bitset_contains(analysis.call_without_effects_funcs, func_idx) {
    match previous {
      Some(@lib.RefFunc(target)) => rume_mark_func(queue, used_funcs, target)
      _ =>
        match rume_call_ref_type_from_operand(mod_, previous, func_locals) {
          Some(call_type) =>
            rume_use_call_ref_type(analysis, queue, used_funcs, call_type)
          None => rume_use_all_referenced_funcs(analysis, queue, used_funcs)
        }
    }
  }
  if rume_func_bitset_contains(analysis.configure_all_funcs, func_idx) {
    match
      rume_configure_all_elem_operand(
        mod_, analysis, instrs, call_index, func_idx,
      ) {
      Some(elem_idx) =>
        rume_mark_elem_funcs(mod_, analysis, elem_idx, queue, used_funcs)
      None => ()
    }
  }
}

///|
fn rume_scan_expr(
  expr : @lib.Expr,
  mod_ : @lib.Module,
  analysis : RumeCallTableAnalysis,
  table_imports : Int,
  queue : Array[RumeItem],
  used_funcs : @bitset.BitSet,
  used_globals : @bitset.BitSet,
  used_tables : @bitset.BitSet,
  used_mems : @bitset.BitSet,
  used_tags : @bitset.BitSet,
  used_elems : @bitset.BitSet,
  used_datas : @bitset.BitSet,
  decl_only_elems : @bitset.BitSet,
  func_to_declaring_elems : Array[Array[@lib.ElemIdx]],
  func_locals? : @lib.FunctionLocals? = None,
) -> Unit {
  let @lib.Expr(instrs) = expr
  let mut previous : @lib.Instruction? = None
  let mut instr_index = 0
  for instr in instrs {
    rume_scan_instruction(
      instr, mod_, analysis, table_imports, queue, used_funcs, used_globals, used_tables,
      used_mems, used_tags, used_elems, used_datas, decl_only_elems, func_to_declaring_elems,
      previous, func_locals, instrs, instr_index,
    )
    previous = Some(instr)
    instr_index += 1
  }
}

///|
fn rume_scan_instruction(
  instr : @lib.Instruction,
  mod_ : @lib.Module,
  analysis : RumeCallTableAnalysis,
  table_imports : Int,
  queue : Array[RumeItem],
  used_funcs : @bitset.BitSet,
  used_globals : @bitset.BitSet,
  used_tables : @bitset.BitSet,
  used_mems : @bitset.BitSet,
  used_tags : @bitset.BitSet,
  used_elems : @bitset.BitSet,
  used_datas : @bitset.BitSet,
  decl_only_elems : @bitset.BitSet,
  func_to_declaring_elems : Array[Array[@lib.ElemIdx]],
  previous : @lib.Instruction?,
  func_locals : @lib.FunctionLocals?,
  direct_call_instrs : Array[@lib.Instruction],
  direct_call_index : Int,
) -> Unit {
  match analysis.used_types {
    Some(used_types) => rume_mark_instruction_direct_types(used_types, instr)
    None => ()
  }
  match instr {
    @lib.Block(_, body) | @lib.Loop(_, body) =>
      rume_scan_expr(
        body,
        mod_,
        analysis,
        table_imports,
        queue,
        used_funcs,
        used_globals,
        used_tables,
        used_mems,
        used_tags,
        used_elems,
        used_datas,
        decl_only_elems,
        func_to_declaring_elems,
        func_locals~,
      )
    @lib.If(_, then_body, else_body) => {
      rume_scan_expr(
        @lib.Expr::new(then_body),
        mod_,
        analysis,
        table_imports,
        queue,
        used_funcs,
        used_globals,
        used_tables,
        used_mems,
        used_tags,
        used_elems,
        used_datas,
        decl_only_elems,
        func_to_declaring_elems,
        func_locals~,
      )
      match else_body {
        Some(body) =>
          rume_scan_expr(
            @lib.Expr::new(body),
            mod_,
            analysis,
            table_imports,
            queue,
            used_funcs,
            used_globals,
            used_tables,
            used_mems,
            used_tags,
            used_elems,
            used_datas,
            decl_only_elems,
            func_to_declaring_elems,
            func_locals~,
          )
        None => ()
      }
    }
    @lib.Call(func_idx) | @lib.ReturnCall(func_idx) =>
      rume_process_direct_call(
        func_idx, mod_, analysis, queue, used_funcs, previous, func_locals, direct_call_instrs,
        direct_call_index,
      )
    @lib.RefFunc(func_idx) =>
      rume_mark_ref_func(
        mod_, analysis, queue, used_funcs, used_elems, decl_only_elems, func_to_declaring_elems,
        func_idx,
      )
    @lib.CallRef(call_type) | @lib.ReturnCallRef(call_type) =>
      if analysis.closed_world {
        rume_use_call_ref_type(analysis, queue, used_funcs, call_type)
      }
    @lib.ContNew(cont_type) =>
      if analysis.closed_world {
        match rume_cont_func_type(analysis, cont_type) {
          Some(func_type) =>
            rume_use_call_ref_type(analysis, queue, used_funcs, func_type)
          None => ()
        }
      }
    @lib.CallIndirect(call_type, table_idx)
    | @lib.ReturnCallIndirect(call_type, table_idx) =>
      rume_use_indirect_call(
        mod_, analysis, table_imports, queue, used_funcs, used_globals, used_tables,
        used_elems, call_type, table_idx,
      )
    @lib.Throw(tag_idx) | @lib.Suspend(tag_idx) =>
      rume_mark_tag(queue, used_tags, tag_idx)
    @lib.Resume(_, handlers) | @lib.ResumeThrowRef(_, handlers) =>
      rume_scan_resume_handlers(handlers, queue, used_tags)
    @lib.ResumeThrow(_, tag_idx, handlers) => {
      rume_mark_tag(queue, used_tags, tag_idx)
      rume_scan_resume_handlers(handlers, queue, used_tags)
    }
    @lib.StackSwitch(_, tag_idx) => rume_mark_tag(queue, used_tags, tag_idx)
    @lib.Try(_, body, catches, _) => {
      rume_scan_expr(
        body,
        mod_,
        analysis,
        table_imports,
        queue,
        used_funcs,
        used_globals,
        used_tables,
        used_mems,
        used_tags,
        used_elems,
        used_datas,
        decl_only_elems,
        func_to_declaring_elems,
        func_locals~,
      )
      for catch_ in catches {
        let catch_body = match catch_ {
          @lib.LegacyCatch(tag_idx, catch_body) => {
            rume_mark_tag(queue, used_tags, tag_idx)
            catch_body
          }
          @lib.LegacyCatchAll(catch_body) => catch_body
        }
        rume_scan_expr(
          catch_body,
          mod_,
          analysis,
          table_imports,
          queue,
          used_funcs,
          used_globals,
          used_tables,
          used_mems,
          used_tags,
          used_elems,
          used_datas,
          decl_only_elems,
          func_to_declaring_elems,
          func_locals~,
        )
      }
    }
    @lib.TryTable(_, catches, body) => {
      rume_scan_catches(catches, queue, used_tags)
      rume_scan_expr(
        body,
        mod_,
        analysis,
        table_imports,
        queue,
        used_funcs,
        used_globals,
        used_tables,
        used_mems,
        used_tags,
        used_elems,
        used_datas,
        decl_only_elems,
        func_to_declaring_elems,
        func_locals~,
      )
    }
    @lib.GlobalGet(global_idx) | @lib.GlobalSet(global_idx) =>
      rume_mark_global(queue, used_globals, global_idx)
    @lib.TableGet(table_idx) | @lib.TableSize(table_idx) =>
      rume_mark_table(queue, used_tables, analysis.queued_tables, table_idx)
    @lib.TableSet(table_idx)
    | @lib.TableGrow(table_idx)
    | @lib.TableFill(table_idx) => {
      rume_mark_table(queue, used_tables, analysis.queued_tables, table_idx)
      rume_note_table_runtime_modification(
        analysis, queue, used_funcs, table_idx,
      )
    }
    @lib.TableInit(elem_idx, table_idx) => {
      rume_mark_elem(queue, used_elems, decl_only_elems, elem_idx)
      rume_mark_table(queue, used_tables, analysis.queued_tables, table_idx)
      rume_note_table_runtime_modification(
        analysis, queue, used_funcs, table_idx,
      )
    }
    @lib.ElemDrop(elem_idx) =>
      rume_mark_elem(queue, used_elems, decl_only_elems, elem_idx)
    @lib.TableCopy(dst, src) => {
      rume_mark_table(queue, used_tables, analysis.queued_tables, dst)
      rume_mark_table(queue, used_tables, analysis.queued_tables, src)
      rume_note_table_runtime_modification(analysis, queue, used_funcs, dst)
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
      if analysis.closed_world {
        rume_reference_elem_payload(
          mod_, analysis, used_funcs, used_elems, queue, used_globals, elem_idx,
        )
      } else {
        rume_mark_elem(queue, used_elems, decl_only_elems, elem_idx)
      }
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
    | @lib.I32AtomicLoad(_, memarg)
    | @lib.I64AtomicLoad(_, memarg)
    | @lib.I32AtomicLoad8U(_, memarg)
    | @lib.I32AtomicLoad16U(_, memarg)
    | @lib.I64AtomicLoad8U(_, memarg)
    | @lib.I64AtomicLoad16U(_, memarg)
    | @lib.I64AtomicLoad32U(_, memarg)
    | @lib.I32AtomicStore(_, memarg)
    | @lib.I64AtomicStore(_, memarg)
    | @lib.I32AtomicStore8(_, memarg)
    | @lib.I32AtomicStore16(_, memarg)
    | @lib.I64AtomicStore8(_, memarg)
    | @lib.I64AtomicStore16(_, memarg)
    | @lib.I64AtomicStore32(_, memarg)
    | @lib.AtomicRmw(_, _, memarg)
    | @lib.AtomicCmpxchg(_, _, memarg)
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
fn rume_function_locals(
  analysis : RumeCallTableAnalysis,
  abs_idx : UInt,
  body_locals : @lib.Locals,
) -> @lib.FunctionLocals? {
  let slot = abs_idx.reinterpret_as_int()
  if slot < 0 || slot >= analysis.func_types.length() {
    return None
  }
  match analysis.env.resolve_comptype(analysis.func_types[slot]) {
    Some(@lib.FuncCompType(params, _)) =>
      Some(@lib.FunctionLocals::new(params, body_locals))
    _ => None
  }
}

///|
fn rume_process_func(
  mod_ : @lib.Module,
  analysis : RumeCallTableAnalysis,
  abs_idx : UInt,
  func_imports : Int,
  table_imports : Int,
  queue : Array[RumeItem],
  used_funcs : @bitset.BitSet,
  used_globals : @bitset.BitSet,
  used_tables : @bitset.BitSet,
  used_mems : @bitset.BitSet,
  used_tags : @bitset.BitSet,
  used_elems : @bitset.BitSet,
  used_datas : @bitset.BitSet,
  decl_only_elems : @bitset.BitSet,
  func_to_declaring_elems : Array[Array[@lib.ElemIdx]],
) -> Unit {
  let def_idx = abs_idx.reinterpret_as_int() - func_imports
  if def_idx < 0 {
    return
  }
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs.get(def_idx) {
        Some(@lib.Func(body_locals, body)) => {
          match analysis.used_types {
            Some(used_types) =>
              for local_run in body_locals.runs() {
                rume_mark_val_type(used_types, local_run.val_type())
              }
            None => ()
          }
          rume_scan_expr(
            body,
            mod_,
            analysis,
            table_imports,
            queue,
            used_funcs,
            used_globals,
            used_tables,
            used_mems,
            used_tags,
            used_elems,
            used_datas,
            decl_only_elems,
            func_to_declaring_elems,
            func_locals=rume_function_locals(analysis, abs_idx, body_locals),
          )
        }
        None => ()
      }
    None => ()
  }
}

///|
fn rume_process_global(
  mod_ : @lib.Module,
  analysis : RumeCallTableAnalysis,
  abs_idx : UInt,
  global_imports : Int,
  table_imports : Int,
  queue : Array[RumeItem],
  used_funcs : @bitset.BitSet,
  used_globals : @bitset.BitSet,
  used_tables : @bitset.BitSet,
  used_mems : @bitset.BitSet,
  used_tags : @bitset.BitSet,
  used_elems : @bitset.BitSet,
  used_datas : @bitset.BitSet,
  decl_only_elems : @bitset.BitSet,
  func_to_declaring_elems : Array[Array[@lib.ElemIdx]],
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
            init, mod_, analysis, table_imports, queue, used_funcs, used_globals,
            used_tables, used_mems, used_tags, used_elems, used_datas, decl_only_elems,
            func_to_declaring_elems,
          )
        None => ()
      }
    None => ()
  }
}

///|
fn rume_process_table(
  mod_ : @lib.Module,
  analysis : RumeCallTableAnalysis,
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
  decl_only_elems : @bitset.BitSet,
  func_to_declaring_elems : Array[Array[@lib.ElemIdx]],
  table_to_elems : Array[Array[@lib.ElemIdx]],
) -> Unit {
  let def_idx = abs_idx.reinterpret_as_int() - table_imports
  if def_idx >= 0 {
    match mod_.table_sec {
      Some(@lib.TableSec(tables)) =>
        match tables.get(def_idx) {
          Some(@lib.Table(_, Some(init))) =>
            rume_scan_expr(
              init, mod_, analysis, table_imports, queue, used_funcs, used_globals,
              used_tables, used_mems, used_tags, used_elems, used_datas, decl_only_elems,
              func_to_declaring_elems,
            )
          _ => ()
        }
      None => ()
    }
  }
  let slot = abs_idx.reinterpret_as_int()
  for elem_idx in table_to_elems[slot] {
    rume_mark_elem(queue, used_elems, decl_only_elems, elem_idx)
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
  analysis : RumeCallTableAnalysis,
  elem_idx : UInt,
  table_imports : Int,
  queue : Array[RumeItem],
  used_funcs : @bitset.BitSet,
  used_globals : @bitset.BitSet,
  used_tables : @bitset.BitSet,
  used_mems : @bitset.BitSet,
  used_tags : @bitset.BitSet,
  used_elems : @bitset.BitSet,
  used_datas : @bitset.BitSet,
  decl_only_elems : @bitset.BitSet,
  func_to_declaring_elems : Array[Array[@lib.ElemIdx]],
) -> Unit {
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) =>
      match elems.get(elem_idx.reinterpret_as_int()) {
        Some(@lib.Elem(mode, kind)) => {
          match mode {
            @lib.Active(table_idx, offset) => {
              rume_mark_table(
                queue,
                used_tables,
                analysis.queued_tables,
                table_idx,
              )
              rume_scan_expr(
                offset, mod_, analysis, table_imports, queue, used_funcs, used_globals,
                used_tables, used_mems, used_tags, used_elems, used_datas, decl_only_elems,
                func_to_declaring_elems,
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
                  expr, mod_, analysis, table_imports, queue, used_funcs, used_globals,
                  used_tables, used_mems, used_tags, used_elems, used_datas, decl_only_elems,
                  func_to_declaring_elems,
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
  analysis : RumeCallTableAnalysis,
  data_idx : UInt,
  table_imports : Int,
  queue : Array[RumeItem],
  used_funcs : @bitset.BitSet,
  used_globals : @bitset.BitSet,
  used_tables : @bitset.BitSet,
  used_mems : @bitset.BitSet,
  used_tags : @bitset.BitSet,
  used_elems : @bitset.BitSet,
  used_datas : @bitset.BitSet,
  decl_only_elems : @bitset.BitSet,
  func_to_declaring_elems : Array[Array[@lib.ElemIdx]],
) -> Unit {
  match mod_.data_sec {
    Some(@lib.DataSec(datas)) =>
      match datas.get(data_idx.reinterpret_as_int()) {
        Some(@lib.Data(@lib.Active(mem_idx, offset), _)) => {
          rume_mark_mem(queue, used_mems, mem_idx)
          rume_scan_expr(
            offset, mod_, analysis, table_imports, queue, used_funcs, used_globals,
            used_tables, used_mems, used_tags, used_elems, used_datas, decl_only_elems,
            func_to_declaring_elems,
          )
        }
        _ => ()
      }
    None => ()
  }
}

///|
fn rume_const_offset_u64(offset : @lib.Expr) -> UInt64? {
  match offset {
    @lib.Expr([@lib.I32Const(@lib.I32(value))]) =>
      Some(value.reinterpret_as_uint().to_uint64())
    @lib.Expr([@lib.I64Const(@lib.I64(value))]) =>
      Some(value.reinterpret_as_uint64())
    _ => None
  }
}

///|
fn rume_elem_kind_len(kind : @lib.ElemKind) -> UInt64 {
  match kind {
    @lib.FuncsElemKind(funcs) => funcs.length().to_uint64()
    @lib.FuncExprsElemKind(exprs) | @lib.TypedExprsElemKind(_, exprs) =>
      exprs.length().to_uint64()
  }
}

///|
fn rume_table_type_min(table_type : @lib.TableType) -> UInt64 {
  let @lib.TableType(_, limits) = table_type
  match limits {
    @lib.I32Limits(min, _) => min.to_uint64()
    @lib.I64Limits(min, _) => min
  }
}

///|
fn rume_mem_type_min_bytes(mem_type : @lib.MemType) -> UInt64 {
  let @lib.MemType(limits, _) = mem_type
  match limits {
    @lib.I32Limits(min, _) => min.to_uint64() << 16
    @lib.I64Limits(min, _) => min << 16
  }
}

///|
fn rume_lookup_table_type(
  mod_ : @lib.Module,
  idx : @lib.TableIdx,
) -> @lib.TableType? {
  let @lib.TableIdx(raw_idx) = idx
  let slot = raw_idx.reinterpret_as_int()
  let mut cursor = 0
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.TableExternType(table_type)) => {
            if cursor == slot {
              return Some(table_type)
            }
            cursor += 1
          }
          _ => ()
        }
      }
    None => ()
  }
  let def_idx = slot - cursor
  if def_idx < 0 {
    return None
  }
  match mod_.table_sec {
    Some(@lib.TableSec(tables)) =>
      match tables.get(def_idx) {
        Some(@lib.Table(table_type, _)) => Some(table_type)
        None => None
      }
    None => None
  }
}

///|
fn rume_lookup_mem_type(mod_ : @lib.Module, idx : @lib.MemIdx) -> @lib.MemType? {
  let @lib.MemIdx(raw_idx) = idx
  let slot = raw_idx.reinterpret_as_int()
  let mut cursor = 0
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.MemExternType(mem_type)) => {
            if cursor == slot {
              return Some(mem_type)
            }
            cursor += 1
          }
          _ => ()
        }
      }
    None => ()
  }
  let def_idx = slot - cursor
  if def_idx < 0 {
    return None
  }
  match mod_.mem_sec {
    Some(@lib.MemSec(mems)) =>
      match mems.get(def_idx) {
        Some(mem_type) => Some(mem_type)
        None => None
      }
    None => None
  }
}

///|
fn rume_range_exceeds_min(offset : UInt64, len : UInt64, min : UInt64) -> Bool {
  offset > min || offset + len > min
}

///|
fn rume_nonfunction_active_elem_requires_root(
  mod_ : @lib.Module,
  table_idx : @lib.TableIdx,
  offset : @lib.Expr,
  kind : @lib.ElemKind,
) -> Bool {
  match rume_const_offset_u64(offset) {
    None => true
    Some(offset_value) =>
      match rume_lookup_table_type(mod_, table_idx) {
        Some(table_type) =>
          rume_range_exceeds_min(
            offset_value,
            rume_elem_kind_len(kind),
            rume_table_type_min(table_type),
          )
        None => true
      }
  }
}

///|
fn rume_nonfunction_active_data_requires_root(
  mod_ : @lib.Module,
  mem_idx : @lib.MemIdx,
  offset : @lib.Expr,
  bytes : Bytes,
) -> Bool {
  match rume_const_offset_u64(offset) {
    None => true
    Some(offset_value) =>
      match rume_lookup_mem_type(mod_, mem_idx) {
        Some(mem_type) =>
          // Root only when instantiation may trap (non-const offset or OOB
          // range). Nonempty in-bounds active data on an otherwise-unused
          // defined memory is a no-op for Binaryen and is dropped. Starshine
          // uses a full u64 byte size here; Binaryen truncates
          // `initial << pageSizeLog2` to `Index`, which can false-positive on
          // huge memory64 minima.
          rume_range_exceeds_min(
            offset_value,
            bytes.length().to_uint64(),
            rume_mem_type_min_bytes(mem_type),
          )
        None => true
      }
  }
}

///|
fn rume_ref_type_is_nullable(ref_type : @lib.RefType) -> Bool {
  match ref_type {
    @lib.HeapTypeRefType(nullable, _, _) => nullable
    @lib.AbsHeapTypeRefType(_) => true
  }
}

///|
fn rume_lookup_global_type(
  mod_ : @lib.Module,
  idx : @lib.GlobalIdx,
) -> @lib.GlobalType? {
  let @lib.GlobalIdx(raw_idx) = idx
  let slot = raw_idx.reinterpret_as_int()
  let mut cursor = 0
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.GlobalExternType(global_type)) => {
            if cursor == slot {
              return Some(global_type)
            }
            cursor += 1
          }
          _ => ()
        }
      }
    None => ()
  }
  let def_idx = slot - cursor
  if def_idx < 0 {
    return None
  }
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) =>
      match globals.get(def_idx) {
        Some(@lib.Global(global_type, _)) => Some(global_type)
        None => None
      }
    None => None
  }
}

///|
fn rume_descriptor_operand_may_be_null(
  mod_ : @lib.Module,
  previous : @lib.Instruction?,
) -> Bool {
  match previous {
    Some(@lib.RefNull(_)) => true
    Some(@lib.GlobalGet(global_idx)) =>
      match rume_lookup_global_type(mod_, global_idx) {
        Some(@lib.GlobalType(@lib.RefTypeValType(ref_type), _)) =>
          rume_ref_type_is_nullable(ref_type)
        _ => true
      }
    Some(@lib.StructNew(_))
    | Some(@lib.StructNewDefault(_))
    | Some(@lib.StructNewDesc(_))
    | Some(@lib.StructNewDefaultDesc(_)) => false
    _ => true
  }
}

///|
fn rume_instrs_may_trap_descriptor(
  mod_ : @lib.Module,
  instrs : Array[@lib.Instruction],
) -> Bool {
  let mut previous : @lib.Instruction? = None
  for instr in instrs {
    match instr {
      @lib.StructNewDesc(_) | @lib.StructNewDefaultDesc(_) =>
        if rume_descriptor_operand_may_be_null(mod_, previous) {
          return true
        }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if rume_instrs_may_trap_descriptor(mod_, body) {
          return true
        }
      @lib.Try(_, @lib.Expr(body), catches, _) => {
        if rume_instrs_may_trap_descriptor(mod_, body) {
          return true
        }
        for catch_ in catches {
          let @lib.Expr(catch_body) = match catch_ {
            @lib.LegacyCatch(_, catch_body) | @lib.LegacyCatchAll(catch_body) =>
              catch_body
          }
          if rume_instrs_may_trap_descriptor(mod_, catch_body) {
            return true
          }
        }
      }
      @lib.If(_, then_body, else_body) => {
        if rume_instrs_may_trap_descriptor(mod_, then_body) {
          return true
        }
        match else_body {
          Some(body) =>
            if rume_instrs_may_trap_descriptor(mod_, body) {
              return true
            }
          None => ()
        }
      }
      _ => ()
    }
    previous = Some(instr)
  }
  false
}

///|
fn rume_expr_may_trap_descriptor(mod_ : @lib.Module, expr : @lib.Expr) -> Bool {
  let @lib.Expr(instrs) = expr
  rume_instrs_may_trap_descriptor(mod_, instrs)
}

///|
fn rume_mark_trapping_initializers(
  mod_ : @lib.Module,
  queue : Array[RumeItem],
  used_globals : @bitset.BitSet,
  used_elems : @bitset.BitSet,
  decl_only_elems : @bitset.BitSet,
) -> Unit {
  let global_imports = rume_imported_global_count(mod_)
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) => {
      let mut idx = 0
      while idx < globals.length() {
        let @lib.Global(_, init) = globals[idx]
        if rume_expr_may_trap_descriptor(mod_, init) {
          rume_mark_global(
            queue,
            used_globals,
            @lib.GlobalIdx::new((global_imports + idx).reinterpret_as_uint()),
          )
        }
        idx += 1
      }
    }
    None => ()
  }
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) => {
      let mut elem_idx = 0
      while elem_idx < elems.length() {
        let @lib.Elem(_, kind) = elems[elem_idx]
        let mut may_trap = false
        match kind {
          @lib.FuncsElemKind(_) => ()
          @lib.FuncExprsElemKind(exprs) | @lib.TypedExprsElemKind(_, exprs) =>
            for expr in exprs {
              if rume_expr_may_trap_descriptor(mod_, expr) {
                may_trap = true
              }
            }
        }
        if may_trap {
          rume_mark_elem(
            queue,
            used_elems,
            decl_only_elems,
            @lib.ElemIdx::new(elem_idx.reinterpret_as_uint()),
          )
        }
        elem_idx += 1
      }
    }
    None => ()
  }
}

///|
fn rume_mark_nonfunction_active_offset_segments(
  mod_ : @lib.Module,
  queue : Array[RumeItem],
  used_elems : @bitset.BitSet,
  used_datas : @bitset.BitSet,
  decl_only_elems : @bitset.BitSet,
) -> Unit {
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) => {
      let mut elem_idx = 0
      while elem_idx < elems.length() {
        match elems[elem_idx] {
          @lib.Elem(@lib.Active(table_idx, offset), kind) =>
            if rume_nonfunction_active_elem_requires_root(
                mod_, table_idx, offset, kind,
              ) {
              rume_mark_elem(
                queue,
                used_elems,
                decl_only_elems,
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
          @lib.Data(@lib.Active(mem_idx, offset), bytes) =>
            if rume_nonfunction_active_data_requires_root(
                mod_, mem_idx, offset, bytes,
              ) {
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
fn rume_mark_imported_parent_segments(
  mod_ : @lib.Module,
  table_imports : Int,
  mem_imports : Int,
  queue : Array[RumeItem],
  used_elems : @bitset.BitSet,
  used_datas : @bitset.BitSet,
  decl_only_elems : @bitset.BitSet,
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
                decl_only_elems,
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
fn rume_finish_used_type_flags(
  mod_ : @lib.Module,
  partial_used_types : @bitset.BitSet?,
  used_funcs : @bitset.BitSet,
  referenced_funcs : @bitset.BitSet,
  used_globals : @bitset.BitSet,
  used_tables : @bitset.BitSet,
  used_tags : @bitset.BitSet,
  used_elems : @bitset.BitSet,
  used_datas : @bitset.BitSet,
) -> @bitset.BitSet? {
  let used_types = match partial_used_types {
    Some(flags) => flags
    None => return None
  }
  let func_types = rume_collect_func_types(mod_)
  let mut slot = 0
  while slot < used_funcs.length() {
    if used_funcs[slot] ||
      (slot < referenced_funcs.length() && referenced_funcs[slot]) {
      match func_types.get(slot) {
        Some(type_idx) => rume_mark_type_idx(used_types, type_idx)
        None => ()
      }
    }
    slot += 1
  }
  slot = 0
  while slot < used_tables.length() {
    if used_tables[slot] {
      match
        rume_lookup_table_type(
          mod_,
          @lib.TableIdx::new(slot.reinterpret_as_uint()),
        ) {
        Some(@lib.TableType(ref_type, _)) =>
          rume_mark_ref_type(used_types, ref_type)
        None => ()
      }
    }
    slot += 1
  }
  slot = 0
  while slot < used_globals.length() {
    if used_globals[slot] {
      match
        rume_lookup_global_type(
          mod_,
          @lib.GlobalIdx::new(slot.reinterpret_as_uint()),
        ) {
        Some(@lib.GlobalType(val_type, _)) =>
          rume_mark_val_type(used_types, val_type)
        None => ()
      }
    }
    slot += 1
  }
  let mut tag_slot = 0
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.TagExternType(@lib.TagType(type_idx))) => {
            if tag_slot < used_tags.length() && used_tags[tag_slot] {
              rume_mark_type_idx(used_types, type_idx)
            }
            tag_slot += 1
          }
          _ => ()
        }
      }
    None => ()
  }
  match mod_.tag_sec {
    Some(@lib.TagSec(tags)) =>
      for tag in tags {
        if tag_slot < used_tags.length() && used_tags[tag_slot] {
          let @lib.TagType(type_idx) = tag
          rume_mark_type_idx(used_types, type_idx)
        }
        tag_slot += 1
      }
    None => ()
  }
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) => {
      let mut elem_idx = 0
      while elem_idx < elems.length() {
        if elem_idx < used_elems.length() && used_elems[elem_idx] {
          let @lib.Elem(mode, kind) = elems[elem_idx]
          match mode {
            @lib.Active(_, offset) => rume_mark_expr_types(used_types, offset)
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
        elem_idx += 1
      }
    }
    None => ()
  }
  match mod_.data_sec {
    Some(@lib.DataSec(datas)) => {
      let mut data_idx = 0
      while data_idx < datas.length() {
        if data_idx < used_datas.length() && used_datas[data_idx] {
          match datas[data_idx] {
            @lib.Data(@lib.Active(_, offset), _) =>
              rume_mark_expr_types(used_types, offset)
            _ => ()
          }
        }
        data_idx += 1
      }
    }
    None => ()
  }
  match mod_.type_sec {
    Some(@lib.TypeSec(rec_types)) =>
      rume_close_type_dependencies(used_types, rec_types)
    None => ()
  }
  Some(used_types)
}

///|
fn rume_collect_liveness_with_import_parent_policy(
  mod_ : @lib.Module,
  keep_import_parent_segments : Bool,
  keep_all_funcs? : Bool = false,
  traps_never_happen? : Bool = false,
  closed_world? : Bool = false,
  indirect_candidate_visits? : Array[Int]? = None,
) -> (
  @bitset.BitSet,
  @bitset.BitSet,
  @bitset.BitSet,
  @bitset.BitSet,
  @bitset.BitSet,
  @bitset.BitSet,
  @bitset.BitSet,
  @bitset.BitSet,
  @bitset.BitSet,
  @bitset.BitSet?,
) {
  let (func_imports, table_imports, mem_imports, global_imports, tag_imports) = rume_imported_counts(
    mod_,
  )
  let used_funcs = @bitset.BitSet::new(
    func_imports + rume_defined_func_count(mod_),
  )
  let referenced_funcs = @bitset.BitSet::new(used_funcs.length())
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
  let decl_only_elems = @bitset.BitSet::new(used_elems.length())
  let table_to_elems = rume_build_table_to_elem_map(used_tables.length(), mod_)
  let mem_to_datas = rume_build_mem_to_data_map(used_mems.length(), mod_)
  let func_to_declaring_elems = rume_build_func_to_declaring_elem_map(
    used_funcs.length(),
    mod_,
  )
  let table_call_types : Array[Array[@lib.TypeIdx]] = []
  let mut table_type_slot = 0
  while table_type_slot < used_tables.length() {
    table_call_types.push([])
    table_type_slot += 1
  }
  let analysis : RumeCallTableAnalysis = {
    env: @validate.Env::new().with_module(mod_),
    func_types: rume_collect_func_types(mod_),
    flat_tables: rume_build_flat_table_infos(used_tables.length(), mod_),
    traps_never_happen,
    closed_world,
    referenced_funcs,
    call_without_effects_funcs: rume_special_imported_funcs(
      mod_,
      used_funcs.length(),
      "binaryen-intrinsics",
      "call.without.effects",
    ),
    configure_all_funcs: rume_special_imported_funcs(
      mod_,
      used_funcs.length(),
      "wasm:js-prototypes",
      "configureAll",
    ),
    js_called_funcs: rume_js_called_funcs(mod_, used_funcs.length()),
    call_all_referenced_funcs: false,
    called_func_types: [],
    table_call_types,
    runtime_modified_tables: @bitset.BitSet::new(used_tables.length()),
    queued_tables: @bitset.BitSet::new(used_tables.length()),
    indirect_candidate_visits,
    used_types: rume_new_used_type_flags(mod_),
  }
  let queue : Array[RumeItem] = []
  let drop_noop_start_sec = rume_has_binaryen_noop_start_sec(mod_)

  if keep_all_funcs {
    rume_mark_defined_funcs(queue, used_funcs, func_imports)
  }
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
            rume_mark_table(
              queue,
              used_tables,
              analysis.queued_tables,
              table_idx,
            )
          @lib.MemExternIdx(mem_idx) => rume_mark_mem(queue, used_mems, mem_idx)
          @lib.TagExternIdx(tag_idx) => rume_mark_tag(queue, used_tags, tag_idx)
        }
      }
    None => ()
  }
  if keep_import_parent_segments {
    rume_mark_imported_parent_segments(
      mod_, table_imports, mem_imports, queue, used_elems, used_datas, decl_only_elems,
    )
  }
  rume_mark_nonfunction_active_offset_segments(
    mod_, queue, used_elems, used_datas, decl_only_elems,
  )
  if !traps_never_happen {
    rume_mark_trapping_initializers(
      mod_, queue, used_globals, used_elems, decl_only_elems,
    )
  }

  let mut cursor = 0
  while cursor < queue.length() {
    match queue[cursor] {
      RumeItem::Func(abs_idx) =>
        rume_process_func(
          mod_, analysis, abs_idx, func_imports, table_imports, queue, used_funcs,
          used_globals, used_tables, used_mems, used_tags, used_elems, used_datas,
          decl_only_elems, func_to_declaring_elems,
        )
      RumeItem::Global(abs_idx) =>
        rume_process_global(
          mod_, analysis, abs_idx, global_imports, table_imports, queue, used_funcs,
          used_globals, used_tables, used_mems, used_tags, used_elems, used_datas,
          decl_only_elems, func_to_declaring_elems,
        )
      RumeItem::Table(abs_idx) =>
        rume_process_table(
          mod_, analysis, abs_idx, table_imports, queue, used_funcs, used_globals,
          used_tables, used_mems, used_tags, used_elems, used_datas, decl_only_elems,
          func_to_declaring_elems, table_to_elems,
        )
      RumeItem::Mem(abs_idx) =>
        rume_process_mem(abs_idx, queue, used_datas, mem_to_datas)
      RumeItem::Tag => ()
      RumeItem::Elem(elem_idx) =>
        rume_process_elem(
          mod_, analysis, elem_idx, table_imports, queue, used_funcs, used_globals,
          used_tables, used_mems, used_tags, used_elems, used_datas, decl_only_elems,
          func_to_declaring_elems,
        )
      RumeItem::Data(data_idx) =>
        rume_process_data(
          mod_, analysis, data_idx, table_imports, queue, used_funcs, used_globals,
          used_tables, used_mems, used_tags, used_elems, used_datas, decl_only_elems,
          func_to_declaring_elems,
        )
    }
    cursor += 1
  }

  (
    used_funcs,
    analysis.referenced_funcs,
    used_globals,
    used_tables,
    used_mems,
    used_tags,
    used_elems,
    used_datas,
    decl_only_elems,
    analysis.used_types,
  )
}

///|
fn rume_collect_liveness(
  mod_ : @lib.Module,
  traps_never_happen? : Bool = false,
  closed_world? : Bool = false,
) -> (
  @bitset.BitSet,
  @bitset.BitSet,
  @bitset.BitSet,
  @bitset.BitSet,
  @bitset.BitSet,
  @bitset.BitSet,
  @bitset.BitSet,
  @bitset.BitSet,
  @bitset.BitSet,
  @bitset.BitSet?,
) {
  rume_collect_liveness_with_import_parent_policy(
    mod_,
    true,
    traps_never_happen~,
    closed_world~,
  )
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
fn rume_merge_func_keep_set(
  used_funcs : @bitset.BitSet,
  referenced_funcs : @bitset.BitSet,
) -> @bitset.BitSet {
  let kept = @bitset.BitSet::new(used_funcs.length())
  let mut idx = 0
  while idx < used_funcs.length() {
    kept[idx] = used_funcs[idx] ||
      (idx < referenced_funcs.length() && referenced_funcs[idx])
    idx += 1
  }
  kept
}

///|
fn rume_func_needs_unreachable_body(
  used_funcs : @bitset.BitSet,
  referenced_funcs : @bitset.BitSet,
  abs_idx : Int,
) -> Bool {
  abs_idx >= 0 &&
  abs_idx < referenced_funcs.length() &&
  referenced_funcs[abs_idx] &&
  (abs_idx >= used_funcs.length() || !used_funcs[abs_idx])
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
fn rume_rewrite_resume_handlers(
  handlers : Array[@lib.ResumeHandler],
  tag_remap : Array[Int],
) -> Array[@lib.ResumeHandler] {
  let rewritten : Array[@lib.ResumeHandler] = []
  for handler in handlers {
    rewritten.push(
      match handler {
        @lib.ResumeOnLabel(tag_idx, label_idx) =>
          @lib.ResumeHandler::on_label(
            rume_rewrite_tag_idx(tag_idx, tag_remap),
            label_idx,
          )
        @lib.ResumeOnSwitch(tag_idx) =>
          @lib.ResumeHandler::on_switch(
            rume_rewrite_tag_idx(tag_idx, tag_remap),
          )
      },
    )
  }
  rewritten
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
pub fn rume_rewrite_instruction(
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
    @lib.Suspend(tag_idx) =>
      @lib.Instruction::suspend(rume_rewrite_tag_idx(tag_idx, tag_remap))
    @lib.Resume(type_idx, handlers) =>
      @lib.Instruction::resume_(
        type_idx,
        rume_rewrite_resume_handlers(handlers, tag_remap),
      )
    @lib.ResumeThrow(type_idx, tag_idx, handlers) =>
      @lib.Instruction::resume_throw(
        type_idx,
        rume_rewrite_tag_idx(tag_idx, tag_remap),
        rume_rewrite_resume_handlers(handlers, tag_remap),
      )
    @lib.ResumeThrowRef(type_idx, handlers) =>
      @lib.Instruction::resume_throw_ref(
        type_idx,
        rume_rewrite_resume_handlers(handlers, tag_remap),
      )
    @lib.StackSwitch(type_idx, tag_idx) =>
      @lib.Instruction::stack_switch(
        type_idx,
        rume_rewrite_tag_idx(tag_idx, tag_remap),
      )
    @lib.Try(block_type, body, catches, delegate) => {
      let rewritten_catches : Array[@lib.LegacyCatch] = []
      for catch_ in catches {
        match catch_ {
          @lib.LegacyCatch(tag_idx, catch_body) =>
            rewritten_catches.push(
              @lib.LegacyCatch::tagged(
                rume_rewrite_tag_idx(tag_idx, tag_remap),
                rume_rewrite_expr(
                  catch_body, func_remap, global_remap, table_remap, mem_remap, tag_remap,
                  elem_remap, data_remap,
                ),
              ),
            )
          @lib.LegacyCatchAll(catch_body) =>
            rewritten_catches.push(
              @lib.LegacyCatch::all(
                rume_rewrite_expr(
                  catch_body, func_remap, global_remap, table_remap, mem_remap, tag_remap,
                  elem_remap, data_remap,
                ),
              ),
            )
        }
      }
      @lib.Instruction::try_(
        block_type,
        rume_rewrite_expr(
          body, func_remap, global_remap, table_remap, mem_remap, tag_remap, elem_remap,
          data_remap,
        ),
        rewritten_catches,
        delegate~,
      )
    }
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
    @lib.I32AtomicLoad(order, memarg) =>
      @lib.Instruction::i32_atomic_load(
        rume_rewrite_memarg(memarg, mem_remap),
        order~,
      )
    @lib.I64AtomicLoad(order, memarg) =>
      @lib.Instruction::i64_atomic_load(
        rume_rewrite_memarg(memarg, mem_remap),
        order~,
      )
    @lib.I32AtomicLoad8U(order, memarg) =>
      @lib.Instruction::i32_atomic_load8_u(
        rume_rewrite_memarg(memarg, mem_remap),
        order~,
      )
    @lib.I32AtomicLoad16U(order, memarg) =>
      @lib.Instruction::i32_atomic_load16_u(
        rume_rewrite_memarg(memarg, mem_remap),
        order~,
      )
    @lib.I64AtomicLoad8U(order, memarg) =>
      @lib.Instruction::i64_atomic_load8_u(
        rume_rewrite_memarg(memarg, mem_remap),
        order~,
      )
    @lib.I64AtomicLoad16U(order, memarg) =>
      @lib.Instruction::i64_atomic_load16_u(
        rume_rewrite_memarg(memarg, mem_remap),
        order~,
      )
    @lib.I64AtomicLoad32U(order, memarg) =>
      @lib.Instruction::i64_atomic_load32_u(
        rume_rewrite_memarg(memarg, mem_remap),
        order~,
      )
    @lib.I32AtomicStore(order, memarg) =>
      @lib.Instruction::i32_atomic_store(
        rume_rewrite_memarg(memarg, mem_remap),
        order~,
      )
    @lib.I64AtomicStore(order, memarg) =>
      @lib.Instruction::i64_atomic_store(
        rume_rewrite_memarg(memarg, mem_remap),
        order~,
      )
    @lib.I32AtomicStore8(order, memarg) =>
      @lib.Instruction::i32_atomic_store8(
        rume_rewrite_memarg(memarg, mem_remap),
        order~,
      )
    @lib.I32AtomicStore16(order, memarg) =>
      @lib.Instruction::i32_atomic_store16(
        rume_rewrite_memarg(memarg, mem_remap),
        order~,
      )
    @lib.I64AtomicStore8(order, memarg) =>
      @lib.Instruction::i64_atomic_store8(
        rume_rewrite_memarg(memarg, mem_remap),
        order~,
      )
    @lib.I64AtomicStore16(order, memarg) =>
      @lib.Instruction::i64_atomic_store16(
        rume_rewrite_memarg(memarg, mem_remap),
        order~,
      )
    @lib.I64AtomicStore32(order, memarg) =>
      @lib.Instruction::i64_atomic_store32(
        rume_rewrite_memarg(memarg, mem_remap),
        order~,
      )
    @lib.AtomicRmw(order, op, memarg) =>
      @lib.Instruction::atomic_rmw(
        op,
        rume_rewrite_memarg(memarg, mem_remap),
        order~,
      )
    @lib.AtomicCmpxchg(order, op, memarg) =>
      @lib.Instruction::atomic_cmpxchg(
        op,
        rume_rewrite_memarg(memarg, mem_remap),
        order~,
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
fn rume_func_idx_is_mapped(idx : @lib.FuncIdx, func_remap : Array[Int]) -> Bool {
  let @lib.FuncIdx(raw) = idx
  let slot = raw.reinterpret_as_int()
  slot >= 0 && slot < func_remap.length() && func_remap[slot] >= 0
}

///|
fn rume_decl_only_instr_has_dropped_func(
  instr : @lib.Instruction,
  func_remap : Array[Int],
) -> Bool {
  match instr {
    @lib.Block(_, body) | @lib.Loop(_, body) =>
      rume_decl_only_expr_has_dropped_func(body, func_remap)
    @lib.If(_, then_body, else_body) => {
      for nested in then_body {
        if rume_decl_only_instr_has_dropped_func(nested, func_remap) {
          return true
        }
      }
      match else_body {
        Some(body) =>
          for nested in body {
            if rume_decl_only_instr_has_dropped_func(nested, func_remap) {
              return true
            }
          }
        None => ()
      }
      false
    }
    @lib.Try(_, body, catches, _) => {
      if rume_decl_only_expr_has_dropped_func(body, func_remap) {
        return true
      }
      for catch_ in catches {
        let catch_body = match catch_ {
          @lib.LegacyCatch(_, catch_body) | @lib.LegacyCatchAll(catch_body) =>
            catch_body
        }
        if rume_decl_only_expr_has_dropped_func(catch_body, func_remap) {
          return true
        }
      }
      false
    }
    @lib.TryTable(_, _, body) =>
      rume_decl_only_expr_has_dropped_func(body, func_remap)
    @lib.RefFunc(func_idx) => !rume_func_idx_is_mapped(func_idx, func_remap)
    _ => false
  }
}

///|
fn rume_decl_only_expr_has_dropped_func(
  expr : @lib.Expr,
  func_remap : Array[Int],
) -> Bool {
  let @lib.Expr(instrs) = expr
  for instr in instrs {
    if rume_decl_only_instr_has_dropped_func(instr, func_remap) {
      return true
    }
  }
  false
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
  declaration_only : Bool,
) -> @lib.ElemKind {
  match kind {
    @lib.FuncsElemKind(funcs) => {
      let rewritten : Array[@lib.FuncIdx] = []
      for func_idx in funcs {
        if !declaration_only || rume_func_idx_is_mapped(func_idx, func_remap) {
          rewritten.push(rume_rewrite_func_idx(func_idx, func_remap))
        }
      }
      @lib.ElemKind::funcs(rewritten)
    }
    @lib.FuncExprsElemKind(exprs) => {
      let rewritten : Array[@lib.Expr] = []
      for expr in exprs {
        if declaration_only &&
          rume_decl_only_expr_has_dropped_func(expr, func_remap) {
          continue
        }
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
        if declaration_only &&
          rume_decl_only_expr_has_dropped_func(expr, func_remap) {
          continue
        }
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
    @lib.AbsHeapTypeHeapType(_) | @lib.SharedAbsHeapTypeHeapType(_) => ()
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
  let { describes, descriptor, .. } = metadata
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
    @lib.ContCompType(func_type) => rume_mark_type_idx(used_types, func_type)
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
  let { describes, descriptor, .. } = metadata
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
    @lib.ContCompType(func_type) =>
      match func_type {
        @lib.TypeIdx(_) => true
        @lib.RecIdx(_) => false
      }
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
    @lib.AbsHeapTypeHeapType(_) | @lib.SharedAbsHeapTypeHeapType(_) => false
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
fn rume_mark_instruction_direct_types(
  used_types : @bitset.BitSet,
  instr : @lib.Instruction,
) -> Unit {
  match instr {
    @lib.Block(block_type, _)
    | @lib.Loop(block_type, _)
    | @lib.If(block_type, _, _) => rume_mark_block_type(used_types, block_type)
    @lib.CallIndirect(type_idx, _)
    | @lib.ReturnCallIndirect(type_idx, _)
    | @lib.CallRef(type_idx)
    | @lib.ReturnCallRef(type_idx)
    | @lib.ContNew(type_idx)
    | @lib.Resume(type_idx, _)
    | @lib.ResumeThrow(type_idx, _, _)
    | @lib.ResumeThrowRef(type_idx, _)
    | @lib.StackSwitch(type_idx, _)
    | @lib.StructNew(type_idx)
    | @lib.StructNewDefault(type_idx)
    | @lib.StructNewDesc(type_idx)
    | @lib.StructNewDefaultDesc(type_idx)
    | @lib.StructGet(type_idx, _)
    | @lib.StructGetS(type_idx, _)
    | @lib.StructGetU(type_idx, _)
    | @lib.StructAtomicGet(_, type_idx, _)
    | @lib.StructAtomicGetS(_, type_idx, _)
    | @lib.StructAtomicGetU(_, type_idx, _)
    | @lib.StructAtomicRmw(_, _, type_idx, _)
    | @lib.StructAtomicCmpxchg(_, type_idx, _)
    | @lib.StructSet(type_idx, _)
    | @lib.ArrayNew(type_idx)
    | @lib.ArrayNewDefault(type_idx)
    | @lib.ArrayNewFixed(type_idx, _)
    | @lib.ArrayNewData(type_idx, _)
    | @lib.ArrayNewElem(type_idx, _)
    | @lib.ArrayGet(type_idx)
    | @lib.ArrayGetS(type_idx)
    | @lib.ArrayGetU(type_idx)
    | @lib.ArrayAtomicGet(_, type_idx)
    | @lib.ArrayAtomicGetS(_, type_idx)
    | @lib.ArrayAtomicGetU(_, type_idx)
    | @lib.ArraySet(type_idx)
    | @lib.ArrayAtomicRmw(_, _, type_idx)
    | @lib.ArrayAtomicCmpxchg(_, type_idx)
    | @lib.ArrayLoad(_, type_idx)
    | @lib.ArrayStore(_, type_idx)
    | @lib.ArrayFill(type_idx)
    | @lib.ArrayInitData(type_idx, _)
    | @lib.ArrayInitElem(type_idx, _)
    | @lib.RefGetDesc(type_idx) => rume_mark_type_idx(used_types, type_idx)
    @lib.ContBind(src_type, dst_type) | @lib.ArrayCopy(src_type, dst_type) => {
      rume_mark_type_idx(used_types, src_type)
      rume_mark_type_idx(used_types, dst_type)
    }
    @lib.Select(Some(types)) =>
      for val_type in types {
        rume_mark_val_type(used_types, val_type)
      }
    @lib.Try(block_type, _, _, _) | @lib.TryTable(block_type, _, _) =>
      rume_mark_block_type(used_types, block_type)
    @lib.RefNull(ref_type) => rume_mark_ref_type(used_types, ref_type)
    @lib.RefTest(_, _, heap_type)
    | @lib.RefCast(_, _, heap_type)
    | @lib.RefTestDesc(_, heap_type)
    | @lib.RefCastDescEq(_, _, heap_type) =>
      rume_mark_heap_type(used_types, heap_type)
    @lib.BrOnCast(_, _, source, target)
    | @lib.BrOnCastFail(_, _, source, target) => {
      rume_mark_heap_type(used_types, source)
      rume_mark_heap_type(used_types, target)
    }
    @lib.BrOnCastDescEq(_, source, target)
    | @lib.BrOnCastDescEqFail(_, source, target) => {
      rume_mark_ref_type(used_types, source)
      rume_mark_ref_type(used_types, target)
    }
    _ => ()
  }
}

///|
fn rume_mark_instruction_types(
  used_types : @bitset.BitSet,
  instr : @lib.Instruction,
) -> Unit {
  rume_mark_instruction_direct_types(used_types, instr)
  match instr {
    @lib.Block(_, body) | @lib.Loop(_, body) =>
      rume_mark_expr_types(used_types, body)
    @lib.If(_, then_body, else_body) => {
      rume_mark_type_instrs(used_types, then_body)
      match else_body {
        Some(body) => rume_mark_type_instrs(used_types, body)
        None => ()
      }
    }
    @lib.Try(_, body, catches, _) => {
      rume_mark_expr_types(used_types, body)
      for catch_ in catches {
        match catch_ {
          @lib.LegacyCatch(_, catch_body) | @lib.LegacyCatchAll(catch_body) =>
            rume_mark_expr_types(used_types, catch_body)
        }
      }
    }
    @lib.TryTable(_, _, body) => rume_mark_expr_types(used_types, body)
    _ => ()
  }
}

///|
fn rume_new_used_type_flags(mod_ : @lib.Module) -> @bitset.BitSet? {
  match mod_.type_sec {
    Some(@lib.TypeSec(rec_types)) => {
      for rec_type in rec_types {
        match rec_type {
          @lib.GroupRecType(subtypes) =>
            if subtypes.length() != 1 {
              return None
            }
          _ => ()
        }
      }
      Some(@bitset.BitSet::new(rec_types.length()))
    }
    None => None
  }
}

///|
fn rume_queue_type_dependency(
  used_types : @bitset.BitSet,
  queued_types : @bitset.BitSet,
  queue : Array[Int],
  type_idx : @lib.TypeIdx,
) -> Unit {
  match type_idx {
    @lib.TypeIdx(raw) => {
      let slot = raw.reinterpret_as_int()
      if slot >= 0 && slot < used_types.length() && !queued_types[slot] {
        used_types[slot] = true
        queued_types[slot] = true
        queue.push(slot)
      }
    }
    @lib.RecIdx(_) => ()
  }
}

///|
fn rume_queue_heap_type_dependencies(
  used_types : @bitset.BitSet,
  queued_types : @bitset.BitSet,
  queue : Array[Int],
  heap_type : @lib.HeapType,
) -> Unit {
  match heap_type {
    @lib.AbsHeapTypeHeapType(_) | @lib.SharedAbsHeapTypeHeapType(_) => ()
    @lib.HeapType(type_idx) =>
      rume_queue_type_dependency(used_types, queued_types, queue, type_idx)
    @lib.DefTypeHeapType(@lib.DefType(rec_type, _)) =>
      rume_queue_rec_type_dependencies(
        used_types, queued_types, queue, rec_type,
      )
  }
}

///|
fn rume_queue_ref_type_dependencies(
  used_types : @bitset.BitSet,
  queued_types : @bitset.BitSet,
  queue : Array[Int],
  ref_type : @lib.RefType,
) -> Unit {
  match ref_type {
    @lib.HeapTypeRefType(_, _, heap_type) =>
      rume_queue_heap_type_dependencies(
        used_types, queued_types, queue, heap_type,
      )
    @lib.AbsHeapTypeRefType(_) => ()
  }
}

///|
fn rume_queue_val_type_dependencies(
  used_types : @bitset.BitSet,
  queued_types : @bitset.BitSet,
  queue : Array[Int],
  val_type : @lib.ValType,
) -> Unit {
  match val_type {
    @lib.RefTypeValType(ref_type) =>
      rume_queue_ref_type_dependencies(
        used_types, queued_types, queue, ref_type,
      )
    _ => ()
  }
}

///|
fn rume_queue_storage_type_dependencies(
  used_types : @bitset.BitSet,
  queued_types : @bitset.BitSet,
  queue : Array[Int],
  storage_type : @lib.StorageType,
) -> Unit {
  match storage_type {
    @lib.ValTypeStorageType(val_type) =>
      rume_queue_val_type_dependencies(
        used_types, queued_types, queue, val_type,
      )
    @lib.PackTypeStorageType(_) => ()
  }
}

///|
fn rume_queue_field_type_dependencies(
  used_types : @bitset.BitSet,
  queued_types : @bitset.BitSet,
  queue : Array[Int],
  field_type : @lib.FieldType,
) -> Unit {
  let @lib.FieldType(storage_type, _) = field_type
  rume_queue_storage_type_dependencies(
    used_types, queued_types, queue, storage_type,
  )
}

///|
fn rume_queue_metadata_dependencies(
  used_types : @bitset.BitSet,
  queued_types : @bitset.BitSet,
  queue : Array[Int],
  metadata : @lib.TypeMetadata,
) -> Unit {
  let { describes, descriptor, .. } = metadata
  match describes {
    Some(type_idx) =>
      rume_queue_type_dependency(used_types, queued_types, queue, type_idx)
    None => ()
  }
  match descriptor {
    Some(type_idx) =>
      rume_queue_type_dependency(used_types, queued_types, queue, type_idx)
    None => ()
  }
}

///|
fn rume_queue_comp_type_dependencies(
  used_types : @bitset.BitSet,
  queued_types : @bitset.BitSet,
  queue : Array[Int],
  comp_type : @lib.CompType,
) -> Unit {
  match comp_type {
    @lib.ArrayCompType(field_type) =>
      rume_queue_field_type_dependencies(
        used_types, queued_types, queue, field_type,
      )
    @lib.StructCompType(field_types) =>
      for field_type in field_types {
        rume_queue_field_type_dependencies(
          used_types, queued_types, queue, field_type,
        )
      }
    @lib.FuncCompType(params, results) => {
      for param in params {
        rume_queue_val_type_dependencies(used_types, queued_types, queue, param)
      }
      for result in results {
        rume_queue_val_type_dependencies(
          used_types, queued_types, queue, result,
        )
      }
    }
    @lib.ContCompType(type_idx) =>
      rume_queue_type_dependency(used_types, queued_types, queue, type_idx)
  }
}

///|
fn rume_queue_sub_type_dependencies(
  used_types : @bitset.BitSet,
  queued_types : @bitset.BitSet,
  queue : Array[Int],
  subtype : @lib.SubType,
) -> Unit {
  match subtype {
    @lib.SubType(_, supers, metadata, comp_type) => {
      for super_type in supers {
        rume_queue_type_dependency(used_types, queued_types, queue, super_type)
      }
      rume_queue_metadata_dependencies(
        used_types, queued_types, queue, metadata,
      )
      rume_queue_comp_type_dependencies(
        used_types, queued_types, queue, comp_type,
      )
    }
    @lib.CompTypeSubType(metadata, comp_type) => {
      rume_queue_metadata_dependencies(
        used_types, queued_types, queue, metadata,
      )
      rume_queue_comp_type_dependencies(
        used_types, queued_types, queue, comp_type,
      )
    }
  }
}

///|
fn rume_queue_rec_type_dependencies(
  used_types : @bitset.BitSet,
  queued_types : @bitset.BitSet,
  queue : Array[Int],
  rec_type : @lib.RecType,
) -> Unit {
  match rec_type {
    @lib.SingleRecType(subtype) =>
      rume_queue_sub_type_dependencies(used_types, queued_types, queue, subtype)
    @lib.GroupRecType(subtypes) =>
      for subtype in subtypes {
        rume_queue_sub_type_dependencies(
          used_types, queued_types, queue, subtype,
        )
      }
  }
}

///|
fn rume_close_type_dependencies(
  used_types : @bitset.BitSet,
  rec_types : Array[@lib.RecType],
  dependency_type_visits? : Array[Int]? = None,
) -> Unit {
  let queued_types = @bitset.BitSet::new(used_types.length())
  let queue : Array[Int] = []
  let mut type_idx = 0
  while type_idx < used_types.length() {
    if used_types[type_idx] {
      queued_types[type_idx] = true
      queue.push(type_idx)
    }
    type_idx += 1
  }
  let mut cursor = 0
  while cursor < queue.length() {
    let live_type_idx = queue[cursor]
    match dependency_type_visits {
      Some(visits) => visits[0] += 1
      None => ()
    }
    rume_queue_rec_type_dependencies(
      used_types,
      queued_types,
      queue,
      rec_types[live_type_idx],
    )
    cursor += 1
  }
}

///|
fn rume_collect_used_type_flags(mod_ : @lib.Module) -> @bitset.BitSet? {
  match mod_.type_sec {
    Some(@lib.TypeSec(rec_types)) => {
      for rec_type in rec_types {
        match rec_type {
          @lib.GroupRecType(subtypes) =>
            if subtypes.length() != 1 {
              return None
            }
          _ => ()
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
      rume_close_type_dependencies(used_types, rec_types)
      Some(used_types)
    }
    None => None
  }
}

///|
fn rume_build_type_remap(used_types : @bitset.BitSet) -> Map[UInt, UInt] {
  let remap : Map[UInt, UInt] = Map([])
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
fn rume_direct_func_roots_cover_all_types(mod_ : @lib.Module) -> Bool {
  let rec_types = match mod_.type_sec {
    Some(@lib.TypeSec(rec_types)) => rec_types
    None => return true
  }
  let type_count = rec_types.length()
  if type_count == 0 {
    return true
  }
  let used_types = @bitset.BitSet::new(type_count)
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(type_idx)) =>
            rume_mark_type_idx(used_types, type_idx)
          _ => ()
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
  rume_close_type_dependencies(used_types, rec_types)
  rume_all_true(used_types)
}

///|
fn rume_compact_type_sec(
  mod_ : @lib.Module,
  precomputed_used_types? : @bitset.BitSet? = None,
) -> @lib.Module {
  let used_types = match precomputed_used_types {
    Some(flags) => flags
    None => {
      if rume_direct_func_roots_cover_all_types(mod_) {
        return mod_
      }
      match rume_collect_used_type_flags(mod_) {
        Some(flags) => flags
        None => return mod_
      }
    }
  }
  if rume_all_true(used_types) {
    return mod_
  }
  let type_remap = rume_build_type_remap(used_types)
  let rewritten = dfe_rewrite_module_type_idxs(mod_, type_remap)
  // Rebuild from the rewritten types. The original types still use old indices.
  match rewritten.type_sec {
    Some(type_sec) =>
      rume_set_type_sec(rewritten, rume_rebuild_type_sec(type_sec, used_types))
    None => rewritten
  }
}

///|
fn rume_decl_only_elem_parent_is_dropped(
  mode : @lib.ElemMode,
  table_remap : Array[Int],
) -> Bool {
  match mode {
    @lib.Active(@lib.TableIdx(raw_idx), _) => {
      let slot = raw_idx.reinterpret_as_int()
      slot < 0 || slot >= table_remap.length() || table_remap[slot] < 0
    }
    _ => false
  }
}

///|
fn rume_apply_module_rewrite(
  mod_ : @lib.Module,
  used_funcs : @bitset.BitSet,
  referenced_funcs : @bitset.BitSet,
  used_globals : @bitset.BitSet,
  used_tables : @bitset.BitSet,
  used_mems : @bitset.BitSet,
  used_tags : @bitset.BitSet,
  used_elems : @bitset.BitSet,
  used_datas : @bitset.BitSet,
  decl_only_elems : @bitset.BitSet,
  used_types : @bitset.BitSet?,
) -> @lib.Module {
  let func_imports = rume_imported_func_count(mod_)
  let global_imports = rume_imported_global_count(mod_)
  let table_imports = rume_imported_table_count(mod_)
  let mem_imports = rume_imported_mem_count(mod_)
  let tag_imports = rume_imported_tag_count(mod_)
  let keep_funcs = rume_merge_func_keep_set(used_funcs, referenced_funcs)
  let kept_funcs = rume_kept_defined_from_used(keep_funcs, func_imports)
  let kept_globals = rume_kept_defined_from_used(used_globals, global_imports)
  let kept_tables = rume_kept_defined_from_used(used_tables, table_imports)
  let kept_mems = rume_kept_defined_from_used(used_mems, mem_imports)
  let kept_tags = rume_kept_defined_from_used(used_tags, tag_imports)
  let func_remap = rume_build_used_remap(keep_funcs)
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
  let mut has_reference_only_func = false
  let mut ref_idx = 0
  while ref_idx < referenced_funcs.length() {
    if rume_func_needs_unreachable_body(used_funcs, referenced_funcs, ref_idx) {
      has_reference_only_func = true
    }
    ref_idx += 1
  }
  let code_body_rewrite_needed = !(func_remap_is_identity &&
    global_remap_is_identity &&
    table_remap_is_identity &&
    mem_remap_is_identity &&
    tag_remap_is_identity &&
    elem_remap_is_identity &&
    data_remap_is_identity) ||
    has_reference_only_func
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
    return rume_compact_type_sec(mod_, precomputed_used_types=used_types)
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
            let keep = keep_funcs[func_idx]
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
            let abs_idx = func_imports + idx
            let next_body = if rume_func_needs_unreachable_body(
                used_funcs, referenced_funcs, abs_idx,
              ) {
              @lib.Expr::new([@lib.Instruction::unreachable_()])
            } else {
              let @lib.Func(_, body) = funcs[idx]
              rume_rewrite_expr(
                body, func_remap, global_remap, table_remap, mem_remap, tag_remap,
                elem_remap, data_remap,
              )
            }
            let @lib.Func(locals, _) = funcs[idx]
            next_funcs.push(@lib.Func::new(locals, next_body))
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
              if decl_only_elems[idx] &&
                rume_decl_only_elem_parent_is_dropped(mode, table_remap) {
                @lib.ElemMode::declarative()
              } else {
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
                }
              },
              rume_rewrite_elem_kind(
                kind,
                func_remap,
                global_remap,
                table_remap,
                mem_remap,
                tag_remap,
                elem_remap,
                data_remap,
                decl_only_elems[idx],
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
    precomputed_used_types=used_types,
  )
}

///|
fn rume_name_to_string(name : @lib.Name) -> String {
  let @lib.Name(text) = name
  text.to_owned()
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
              kind,
              func_remap,
              global_remap,
              table_remap,
              mem_remap,
              tag_remap,
              elem_remap,
              data_remap,
              mode == @lib.ElemMode::declarative(),
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
    referenced_funcs,
    used_globals,
    used_tables,
    used_mems,
    used_tags,
    used_elems,
    used_datas,
    decl_only_elems,
    partial_used_types,
  ) = rume_collect_liveness_with_import_parent_policy(rooted, false)
  let used_types = rume_finish_used_type_flags(
    rooted, partial_used_types, used_funcs, referenced_funcs, used_globals, used_tables,
    used_tags, used_elems, used_datas,
  )
  let minimized = rume_apply_module_rewrite(
    rooted, used_funcs, referenced_funcs, used_globals, used_tables, used_mems, used_tags,
    used_elems, used_datas, decl_only_elems, used_types,
  )
  let (final_used_funcs, _, _, _, _, _, _, _, _, _) = rume_collect_liveness_with_import_parent_policy(
    minimized, false,
  )
  Ok(rume_rewrite_functions_only(minimized, final_used_funcs))
}

///|
pub fn rume_run_module_pass(
  mod_ : @lib.Module,
  traps_never_happen? : Bool = false,
  closed_world? : Bool = false,
) -> @lib.Module {
  let (
    used_funcs,
    referenced_funcs,
    used_globals,
    used_tables,
    used_mems,
    used_tags,
    used_elems,
    used_datas,
    decl_only_elems,
    partial_used_types,
  ) = rume_collect_liveness(mod_, traps_never_happen~, closed_world~)
  rume_prune_nonfunction_empty_const_active_elems(mod_, used_elems)
  let used_types = rume_finish_used_type_flags(
    mod_, partial_used_types, used_funcs, referenced_funcs, used_globals, used_tables,
    used_tags, used_elems, used_datas,
  )
  rume_apply_module_rewrite(
    mod_, used_funcs, referenced_funcs, used_globals, used_tables, used_mems, used_tags,
    used_elems, used_datas, decl_only_elems, used_types,
  )
}

///|
fn rume_prune_nonfunction_empty_const_active_elems(
  mod_ : @lib.Module,
  used_elems : @bitset.BitSet,
) -> Unit {
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) => {
      let mut idx = 0
      while idx < elems.length() {
        match elems[idx] {
          @lib.Elem(@lib.Active(table_idx, offset), kind) =>
            if !rume_nonfunction_active_elem_requires_root(
                mod_, table_idx, offset, kind,
              ) &&
              !rume_elem_init_has_effect(kind) {
              used_elems[idx] = false
            }
          _ => ()
        }
        idx += 1
      }
    }
    None => ()
  }
}

///|
pub fn rume_run_nonfunction_module_pass(
  mod_ : @lib.Module,
  traps_never_happen? : Bool = false,
  closed_world? : Bool = false,
) -> @lib.Module {
  let (
    used_funcs,
    referenced_funcs,
    used_globals,
    used_tables,
    used_mems,
    used_tags,
    used_elems,
    used_datas,
    decl_only_elems,
    partial_used_types,
  ) = rume_collect_liveness_with_import_parent_policy(
    mod_,
    true,
    keep_all_funcs=true,
    traps_never_happen~,
    closed_world~,
  )
  rume_prune_nonfunction_empty_const_active_elems(mod_, used_elems)
  let used_types = rume_finish_used_type_flags(
    mod_, partial_used_types, used_funcs, referenced_funcs, used_globals, used_tables,
    used_tags, used_elems, used_datas,
  )
  rume_apply_module_rewrite(
    mod_, used_funcs, referenced_funcs, used_globals, used_tables, used_mems, used_tags,
    used_elems, used_datas, decl_only_elems, used_types,
  )
}
