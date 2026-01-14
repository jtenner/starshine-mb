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
    Some(FuncCompType(ps, rs)) => Some(FuncType(ps, rs))
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
  env.locals.get(i.reinterpret_as_int())
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
  Env::{ ..env, labels, }
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
    tables: [],
    mems: [],
    globals: [],
    elems: [],
    datas: [],
    tags: [],
    locals: [],
    labels: [],
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
pub fn Env::expand_blocktype(
  env : Env,
  bt : BlockType,
) -> Result[(Array[ValType], Array[ValType]), String] {
  match bt {
    EmptyBlockType => Ok(([], []))
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
  let funcs = env.funcs.copy()
  funcs.push(ft)
  Env::{ ..env, funcs, }
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
pub fn Env::with_locals(env : Env, locals : Array[ValType]) -> Env {
  Env::{ ..env, locals, }
}

///|
pub fn Env::with_funcs(env : Env, funcs : Array[FuncType]) -> Env {
  Env::{ ..env, funcs, }
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
pub fn Env::with_module(self : Env, m : Module) -> Env {
  let env = self

  // --- Types ---------------------------------------------------------------
  let env = match m.type_sec {
    None => env
    Some(TypeSec(recs)) => {
      let mut e = env
      for rec in recs {
        e = e.with_rectype(rec)
      }
      e
    }
  }

  // --- Imports -------------------------------------------------------------
  let env = match m.import_sec {
    None => env
    Some(ImportSec(imps)) => {
      let mut e = env
      for imp in imps {
        match imp {
          Import(_, _, exttype) =>
            match exttype {
              FuncExternType(type_idx) =>
                match e.resolve_functype(type_idx) {
                  None => ()
                  Some(ft) => e = e.push_func(ft)
                }
              TableExternType(table_ty) => e = e.push_table(table_ty)
              MemExternType(mem_ty) => e = e.push_mem(mem_ty)
              GlobalExternType(global_ty) => e = e.push_global(global_ty)
              TagExternType(tag_ty) => e = e.push_tag(tag_ty)
            }
        }
      }
      e
    }
  }

  // --- Function section ----------------------------------------------------
  let env = match m.func_sec {
    None => env
    Some(FuncSec(type_idxs)) => {
      let mut e = env
      for i in 0..<type_idxs.length() {
        let tidx = type_idxs[i]
        match e.resolve_functype(tidx) {
          None => ()
          Some(ft) => e = e.push_func(ft)
        }
      }
      e
    }
  }

  // --- Tables --------------------------------------------------------------
  let env = match m.table_sec {
    None => env
    Some(TableSec(tables)) => {
      let mut e = env
      for table in tables {
        e = e.push_table(table.0)
      }
      e
    }
  }

  // --- Memories ------------------------------------------------------------
  let env = match m.mem_sec {
    None => env
    Some(MemSec(mems)) => {
      let mut e = env
      for mem in mems {
        e = e.push_mem(mem)
      }
      e
    }
  }

  // --- Globals -------------------------------------------------------------
  let env = match m.global_sec {
    None => env
    Some(GlobalSec(globals)) => {
      let mut e = env
      for global in globals {
        e = e.push_global(global.0)
      }
      e
    }
  }

  // --- Tags ---------------------------------------------------------------
  let env = match m.tag_sec {
    None => env
    Some(TagSec(tags)) => {
      let mut e = env
      for tag in tags {
        e = e.push_tag(tag)
      }
      e
    }
  }

  // --- Elems ---------------------------------------------------------------
  let env = match m.elem_sec {
    None => env
    Some(ElemSec(elems)) => env.with_elems(elems)
  }

  // --- Data ---------------------------------------------------------------
  let env = match m.data_sec {
    None => env
    Some(DataSec(datas)) => {
      let mut e = env
      for d in datas {
        e = e.push_data(d)
      }
      e
    }
  }
  env
}
