///|
type Stack[T] = Array[T]

///|
pub(all) struct LabelStack {
  values : Array[Array[ValType]]
  parents : Array[Int]
  mut head : Int
  mut len : Int
} derive(Hash, Show)

///|
pub fn LabelStack::new() -> LabelStack {
  { values: [], parents: [], head: -1, len: 0 }
}

///|
pub fn LabelStack::from_labels(labels : Array[Array[ValType]]) -> LabelStack {
  let parents : Array[Int] = []
  let mut head = -1
  for idx = 0; idx < labels.length(); idx = idx + 1 {
    parents.push(head)
    head = idx
  }
  { values: labels, parents, head, len: labels.length() }
}

///|
pub fn LabelStack::copy(stack : LabelStack) -> LabelStack {
  {
    values: stack.values,
    parents: stack.parents,
    head: stack.head,
    len: stack.len,
  }
}

///|
pub fn LabelStack::push(
  stack : LabelStack,
  label_types : Array[ValType],
) -> Unit {
  let next = stack.values.length()
  stack.values.push(label_types)
  stack.parents.push(stack.head)
  stack.head = next
  stack.len = stack.len + 1
}

///|
pub fn LabelStack::length(stack : LabelStack) -> Int {
  stack.len
}

///|
pub fn LabelStack::get(stack : LabelStack, idx : Int) -> Array[ValType]? {
  if idx < 0 || idx >= stack.len {
    return None
  }
  let mut remaining = stack.len - 1 - idx
  let mut cursor = stack.head
  while cursor >= 0 {
    if remaining == 0 {
      return Some(stack.values[cursor])
    }
    cursor = stack.parents[cursor]
    remaining = remaining - 1
  }
  None
}

///|
pub(all) struct Env {
  global_types : Array[SubType]
  rec_stack : Stack[Array[SubType]]
  funcs : Array[FuncType]
  func_type_idxs : Array[TypeIdx?]
  tables : Array[TableType]
  mems : Array[MemType]
  globals : Array[GlobalType]
  elems : Array[Elem]
  datas : Array[Data]
  tags : Array[TagType]
  locals : Locals
  labels : LabelStack
  return_type : Array[ValType]?
} derive(Hash, Show)

///|
pub fn Env::resolve_subtype(env : Env, idx : TypeIdx) -> SubType? {
  match idx {
    TypeIdx(i) => env.global_types.get(i.reinterpret_as_int())
    RecIdx(j) => {
      let n = env.rec_stack.length()
      if n == 0 {
        return None
      }
      match env.rec_stack.get(n - 1) {
        None => None
        Some(group) => group.get(j.reinterpret_as_int())
      }
    }
  }
}

///|
pub fn Env::resolve_heaptype_subtype(env : Env, ht : HeapType) -> SubType? {
  match ht {
    AbsHeapTypeHeapType(_) => None
    HeapType(ti) => env.resolve_subtype(ti)
    DefTypeHeapType(dt) => dt.project()
  }
}

///|
pub fn Env::get_label(env : Env, idx : LabelIdx) -> Array[ValType]? {
  let LabelIdx(i) = idx
  env.labels.get(i.reinterpret_as_int())
}

///|
pub fn Env::get_tag(env : Env, idx : TagIdx) -> TagType? {
  let TagIdx(i) = idx
  env.tags.get(i.reinterpret_as_int())
}

///|
pub fn Env::resolve_comptype(env : Env, idx : TypeIdx) -> CompType? {
  match env.resolve_subtype(idx) {
    None => None
    Some(st) => Some(st.get_comptype())
  }
}

///|
pub fn Env::resolve_functype(env : Env, idx : TypeIdx) -> FuncType? {
  match env.resolve_comptype(idx) {
    Some(FuncCompType(ps, rs)) => Some(FuncType::new(ps, rs))
    _ => None
  }
}

///|
pub fn Env::resolve_tag_functype(env : Env, tagidx : TagIdx) -> FuncType? {
  match env.get_tag(tagidx) {
    None => None
    Some(TagType(tidx)) => env.resolve_functype(tidx)
  }
}

///|
pub fn Env::resolve_typeidx_subtype(env : Env, tidx : TypeIdx) -> SubType? {
  match tidx {
    TypeIdx(i) => env.global_types.get(i.reinterpret_as_int())
    RecIdx(j) => {
      let n = env.rec_stack.length()
      if n == 0 {
        return None
      }
      match env.rec_stack.get(n - 1) {
        None => None
        Some(group) => group.get(j.reinterpret_as_int())
      }
    }
  }
}

///|
pub fn Env::get_local_type(env : Env, idx : LocalIdx) -> ValType? {
  let LocalIdx(i) = idx
  env.locals.at(i.reinterpret_as_int())
}

///|
pub fn Env::get_global_type(env : Env, idx : GlobalIdx) -> GlobalType? {
  let GlobalIdx(i) = idx
  env.globals.get(i.reinterpret_as_int())
}

///|
pub fn Env::get_table_type(env : Env, idx : TableIdx) -> TableType? {
  let TableIdx(i) = idx
  env.tables.get(i.reinterpret_as_int())
}

///|
pub fn Env::with_label(env : Env, ts : Array[ValType]) -> Env {
  let ls = env.labels.copy()
  ls.push(ts)
  Env::{ ..env, labels: ls }
}

///|
pub fn Env::with_labels(env : Env, labels : Stack[Array[ValType]]) -> Env {
  Env::{ ..env, labels: LabelStack::from_labels(labels) }
}

///|
pub fn Env::with_return_type(env : Env, rt : Array[ValType]?) -> Env {
  Env::{ ..env, return_type: rt }
}

///|
pub fn Env::with_rectype(env : Env, rt : RecType) -> Env {
  let rs = env.rec_stack.copy()
  let gs = env.global_types.copy()
  match rt {
    SingleRecType(st) => {
      rs.push([st])
      gs.push(st)
    }
    GroupRecType(sts) => {
      rs.push(sts)
      for st in sts {
        gs.push(st)
      }
    }
  }
  Env::{ ..env, rec_stack: rs, global_types: gs }
}

///|
pub fn Env::append_rectype_types(env : Env, rt : RecType) -> Env {
  let gts = env.global_types.copy()
  match rt {
    SingleRecType(st) => gts.push(st)
    GroupRecType(sts) =>
      for st in sts {
        gts.push(st)
      }
  }
  Env::{ ..env, global_types: gts }
}

///|
pub fn empty_env() -> Env {
  Env::{
    global_types: [],
    rec_stack: [],
    funcs: [],
    func_type_idxs: [],
    tables: [],
    mems: [],
    globals: [],
    elems: [],
    datas: [],
    tags: [],
    locals: Locals::empty(),
    labels: LabelStack::new(),
    return_type: None,
  }
}

///|
pub fn Env::new() -> Env {
  empty_env()
}

///|
pub fn Env::get_label_types(env : Env, idx : LabelIdx) -> Array[ValType]? {
  let LabelIdx(i) = idx
  let n = env.labels.length() // Int
  let ii = n - 1 - i.reinterpret_as_int()
  if ii < 0 {
    return None
  }
  env.labels.get(ii)
}

///|
pub fn Env::get_catch_label_types(env : Env, idx : LabelIdx) -> Array[ValType]? {
  env.get_label_types(idx)
}

///|
pub fn Env::expand_blocktype(
  env : Env,
  bt : BlockType,
) -> Result[(Array[ValType], Array[ValType]), String] {
  match bt {
    VoidBlockType => Ok(([], []))
    ValTypeBlockType(vt) => Ok(([], [vt]))
    TypeIdxBlockType(tidx) =>
      match env.resolve_functype(tidx) {
        None => Err("blocktype type index is not a function type")
        Some(FuncType(params, results)) => Ok((params, results))
      }
  }
}

///|
pub fn Env::get_functype_by_funcidx(env : Env, idx : FuncIdx) -> FuncType? {
  let FuncIdx(i) = idx
  env.funcs.get(i.reinterpret_as_int())
}

///|
pub fn Env::get_functypeidx_by_funcidx(env : Env, idx : FuncIdx) -> TypeIdx? {
  let FuncIdx(i) = idx
  match env.func_type_idxs.get(i.reinterpret_as_int()) {
    Some(tidx) => tidx
    None => None
  }
}

///|
pub fn Env::get_elem(env : Env, i : ElemIdx) -> Elem? {
  let ElemIdx(i) = i
  env.elems.get(i.reinterpret_as_int())
}

///|
pub fn Env::get_memtype(env : Env, idx : MemIdx) -> MemType? {
  let MemIdx(i) = idx
  env.mems.get(i.reinterpret_as_int())
}

///|
pub fn Env::has_func(env : Env, idx : FuncIdx) -> Bool {
  let FuncIdx(i) = idx
  i < env.funcs.length().reinterpret_as_uint()
}

///|
pub fn Env::resolve_struct_fields(
  env : Env,
  x : TypeIdx,
) -> Result[Array[FieldType], String] {
  match env.resolve_comptype(x) {
    None => Err("unknown type index")
    Some(ct) =>
      match ct {
        StructCompType(fs) => Ok(fs)
        _ => Err("type is not a struct")
      }
  }
}

///|
pub fn Env::resolve_struct_subtype(
  env : Env,
  x : TypeIdx,
) -> Result[SubType, String] {
  match env.resolve_subtype(x) {
    None => Err("unknown type index")
    Some(st) =>
      match st.get_comptype() {
        StructCompType(_) => Ok(st)
        _ => Err("type is not a struct")
      }
  }
}

///|
pub fn Env::resolve_struct_descriptor_type(
  env : Env,
  x : TypeIdx,
) -> Result[TypeIdx?, String] {
  match env.resolve_struct_subtype(x) {
    Ok(st) => Ok(st.descriptor_type())
    Err(e) => Err(e)
  }
}

///|
pub fn Env::resolve_descriptor_target_ref_type(
  env : Env,
  nullable : Bool,
  ht : HeapType,
) -> Result[RefType, String] {
  let rt = RefType::new(nullable, ht)
  match Validate::validate(rt, env) {
    Ok(_) => Ok(rt)
    Err(t) => Err("invalid descriptor target reftype: " + t)
  }
}

///|
pub fn Env::descriptor_result_type(
  env : Env,
  inspected : TypeIdx,
  operand : RefType?,
) -> Result[ValType, String] {
  let descriptor_type = match env.resolve_struct_descriptor_type(inspected) {
    Ok(Some(ti)) => ti
    Ok(None) => return Err("type without descriptor")
    Err(e) => return Err(e)
  }
  let expected = RefType::new(true, HeapType::new(inspected))
  let expected_exact = RefType::new(true, HeapType::new(inspected), exact=true)
  let exact = match operand {
    None => true
    Some(rt_in) => {
      if !Match::matches(rt_in, expected, env) &&
        !Match::matches(rt_in, expected_exact, env) {
        return Err("ref.get_desc target does not match operand type")
      }
      Match::matches(rt_in, expected_exact, env)
    }
  }
  Ok(
    ValType::ref_type(
      RefType::new(false, HeapType::new(descriptor_type), exact~),
    ),
  )
}

///|
pub fn Env::has_data(env : Env, idx : DataIdx) -> Bool {
  let DataIdx(i) = idx
  i < env.datas.length().reinterpret_as_uint()
}

///|
pub fn Env::resolve_array_field(
  env : Env,
  x : TypeIdx,
) -> Result[FieldType, String] {
  match env.resolve_comptype(x) {
    None => Err("unknown type index")
    Some(ct) =>
      match ct {
        ArrayCompType(ft) => Ok(ft)
        _ => Err("type is not an array")
      }
  }
}

///|
pub fn Env::push_tag(env : Env, t : TagType) -> Env {
  let tags = env.tags.copy()
  tags.push(t)
  Env::{ ..env, tags, }
}

///|
pub fn Env::push_global(env : Env, gt : GlobalType) -> Env {
  let globals = env.globals.copy()
  globals.push(gt)
  Env::{ ..env, globals, }
}

///|
pub fn Env::push_func(env : Env, ft : FuncType) -> Env {
  env.push_func_with_typeidx(ft, None)
}

///|
pub fn Env::push_func_with_typeidx(
  env : Env,
  ft : FuncType,
  type_idx : TypeIdx?,
) -> Env {
  let funcs = env.funcs.copy()
  let func_type_idxs = env.func_type_idxs.copy()
  funcs.push(ft)
  func_type_idxs.push(type_idx)
  Env::{ ..env, funcs, func_type_idxs }
}

///|
pub fn Env::push_mem(env : Env, mt : MemType) -> Env {
  let mems = env.mems.copy()
  mems.push(mt)
  Env::{ ..env, mems, }
}

///|
pub fn Env::push_table(env : Env, tt : TableType) -> Env {
  let tables = env.tables.copy()
  tables.push(tt)
  Env::{ ..env, tables, }
}

///|
pub fn Env::with_locals(env : Env, locals : Locals) -> Env {
  Env::{ ..env, locals, }
}

///|
pub fn Env::with_funcs(env : Env, funcs : Array[FuncType]) -> Env {
  let func_type_idxs : Array[TypeIdx?] = []
  for _ in funcs {
    func_type_idxs.push(None)
  }
  Env::{ ..env, funcs, func_type_idxs }
}

///|
pub fn Env::with_funcs_and_type_idxs(
  env : Env,
  funcs : Array[FuncType],
  func_type_idxs : Array[TypeIdx?],
) -> Env {
  Env::{ ..env, funcs, func_type_idxs }
}

///|
pub fn Env::with_types(env : Env, global_types : Array[SubType]) -> Env {
  Env::{ ..env, global_types, }
}

///|
pub fn Env::with_tables(env : Env, tables : Array[TableType]) -> Env {
  Env::{ ..env, tables, }
}

///|
pub fn Env::with_globals(env : Env, globals : Array[GlobalType]) -> Env {
  Env::{ ..env, globals, }
}

///|
pub fn Env::with_mems(env : Env, mems : Array[MemType]) -> Env {
  Env::{ ..env, mems, }
}

///|
pub fn Env::with_tags(env : Env, tags : Array[TagType]) -> Env {
  Env::{ ..env, tags, }
}

///|
pub fn Env::push_data(env : Env, d : Data) -> Env {
  let datas = env.datas.copy()
  datas.push(d)
  Env::{ ..env, datas, }
}

///|
pub fn Env::with_datas(env : Env, datas : Array[Data]) -> Env {
  Env::{ ..env, datas, }
}

///|
pub fn Env::push_elem(env : Env, e : Elem) -> Env {
  let elems = env.elems.copy()
  elems.push(e)
  Env::{ ..env, elems, }
}

///|
pub fn Env::with_elems(env : Env, elems : Array[Elem]) -> Env {
  Env::{ ..env, elems, }
}

///|
fn env_collect_module_types(
  base_global_types : Array[SubType],
  base_rec_stack : Stack[Array[SubType]],
  m : Module,
) -> (Array[SubType], Stack[Array[SubType]]) {
  let global_types = base_global_types.copy()
  let rec_stack = base_rec_stack.copy()
  match m.type_sec {
    None => ()
    Some(TypeSec(recs)) =>
      for rec in recs {
        match rec {
          SingleRecType(st) => {
            rec_stack.push([st])
            global_types.push(st)
          }
          GroupRecType(sts) => {
            rec_stack.push(sts)
            for st in sts {
              global_types.push(st)
            }
          }
        }
      }
  }
  (global_types, rec_stack)
}

///|
fn env_collect_module_imported_members(
  env : Env,
  m : Module,
  funcs : Array[FuncType],
  func_type_idxs : Array[TypeIdx?],
  tables : Array[TableType],
  mems : Array[MemType],
  globals : Array[GlobalType],
  tags : Array[TagType],
) -> Unit {
  match m.import_sec {
    None => ()
    Some(ImportSec(imps)) =>
      for imp in imps {
        match imp {
          Import(_, _, exttype) =>
            match exttype {
              FuncExternType(type_idx) =>
                match env.resolve_functype(type_idx) {
                  None => ()
                  Some(ft) => {
                    funcs.push(ft)
                    func_type_idxs.push(Some(type_idx))
                  }
                }
              TableExternType(table_ty) => tables.push(table_ty)
              MemExternType(mem_ty) => mems.push(mem_ty)
              GlobalExternType(global_ty) => globals.push(global_ty)
              TagExternType(tag_ty) => tags.push(tag_ty)
            }
        }
      }
  }
}

///|
/// Pull explicit module-defined function bodies/types after imports so function/type
/// indices line up across both imported and locally defined members.
fn env_collect_module_defined_funcs(
  env : Env,
  m : Module,
  funcs : Array[FuncType],
  func_type_idxs : Array[TypeIdx?],
) -> Unit {
  match m.func_sec {
    None => ()
    Some(FuncSec(type_idxs)) =>
      for tidx in type_idxs {
        match env.resolve_functype(tidx) {
          None => ()
          Some(ft) => {
            funcs.push(ft)
            func_type_idxs.push(Some(tidx))
          }
        }
      }
  }
}

///|
/// Copy existing arrays and append module-defined entries; this keeps parent
/// module scopes available while extending the current environment snapshot.
fn env_collect_module_tables(
  base_tables : Array[TableType],
  m : Module,
) -> Array[TableType] {
  let tables = base_tables.copy()
  match m.table_sec {
    None => ()
    Some(TableSec(entries)) =>
      for table in entries {
        tables.push(table.0)
      }
  }
  tables
}

///|
/// Append defined memories in declaration order; this function mirrors the exact
/// source order expected by typed indices during validation.
fn env_collect_module_mems(
  base_mems : Array[MemType],
  m : Module,
) -> Array[MemType] {
  let mems = base_mems.copy()
  match m.mem_sec {
    None => ()
    Some(MemSec(entries)) =>
      for mem in entries {
        mems.push(mem)
      }
  }
  mems
}

///|
/// Copy base globals and append local definitions so type lookups can resolve both
/// imported and later-defined entries via stable index offsets.
fn env_collect_module_globals(
  base_globals : Array[GlobalType],
  m : Module,
) -> Array[GlobalType] {
  let globals = base_globals.copy()
  match m.global_sec {
    None => ()
    Some(GlobalSec(entries)) =>
      for global in entries {
        globals.push(global.0)
      }
  }
  globals
}

///|
/// Capture all declared tags in order, preserving declaration indices for tag type
/// checks and tag-based control-flow constructs.
fn env_collect_module_tags(
  base_tags : Array[TagType],
  m : Module,
) -> Array[TagType] {
  let tags = base_tags.copy()
  match m.tag_sec {
    None => ()
    Some(TagSec(entries)) =>
      for tag in entries {
        tags.push(tag)
      }
  }
  tags
}

///|
/// Preserve existing element segment table entries from a prior environment and
/// append new module-local sections only when present.
fn env_collect_module_datas(
  base_datas : Array[Data],
  m : Module,
) -> Array[Data] {
  let datas = base_datas.copy()
  match m.data_sec {
    None => ()
    Some(DataSec(entries)) =>
      for data in entries {
        datas.push(data)
      }
  }
  datas
}

///|
/// Build a validation environment by layering imported definitions plus
/// module-local declarations on top of the existing environment snapshot, then
/// normalizing elem/data payloads from the current module.
pub fn Env::with_module(self : Env, m : Module) -> Env {
  let (global_types, rec_stack) = env_collect_module_types(
    self.global_types,
    self.rec_stack,
    m,
  )
  let type_env = Env::{ ..self, global_types, rec_stack }

  let funcs = self.funcs.copy()
  let func_type_idxs = self.func_type_idxs.copy()
  let tables = self.tables.copy()
  let mems = self.mems.copy()
  let globals = self.globals.copy()
  let tags = self.tags.copy()

  env_collect_module_imported_members(
    type_env, m, funcs, func_type_idxs, tables, mems, globals, tags,
  )
  env_collect_module_defined_funcs(type_env, m, funcs, func_type_idxs)

  let tables = env_collect_module_tables(tables, m)
  let mems = env_collect_module_mems(mems, m)
  let globals = env_collect_module_globals(globals, m)
  let tags = env_collect_module_tags(tags, m)
  let elems = match m.elem_sec {
    None => self.elems
    Some(ElemSec(elems)) => elems
  }
  let datas = env_collect_module_datas(self.datas, m)

  Env::{
    ..type_env,
    funcs,
    func_type_idxs,
    tables,
    mems,
    globals,
    elems,
    datas,
    tags,
  }
}
