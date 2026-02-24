///|
type Stack[T] = Array[T]

///|
pub(all) struct Env {
  global_types : Array[SubType]
  rec_stack : Stack[Array[SubType]]
  funcs : Array[FuncType]
  tables : Array[TableType]
  mems : Array[MemType]
  globals : Array[GlobalType]
  elems : Array[Elem]
  datas : Array[Data]
  tags : Array[TagType]
  locals : Array[ValType]
  labels : Stack[Array[ValType]]
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
pub fn Env::descriptor_result_type(_env : Env) -> ValType {
  ValType::i32()
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

///|
/// Convert flat Expr to tree-based TExpr
pub fn to_texpr(expr : Expr, env : Env) -> Result[TExpr, String] {
  let stack : Array[TInstr] = []
  for instr in expr.0 {
    match instr_to_tinstr(instr, stack, env) {
      Ok(_) => ()
      Err(t) => return Err(t)
    }
  }
  Ok(TExpr::new(stack))
}

///|
fn pop(stack : Array[TInstr]) -> Result[TInstr, String] {
  match stack.pop() {
    Some(v) => Ok(v)
    None => Err("Stack underflow during tree conversion")
  }
}

///|
fn pop_n(stack : Array[TInstr], n : Int) -> Result[Array[TInstr], String] {
  if stack.length() < n {
    return Err(
      "Stack underflow: need \{n} values but only \{stack.length()} available",
    )
  }
  let result : Array[TInstr] = Array::make(n, TInstr::nop())
  // Pop in reverse order, then we have them in correct order
  for i = n - 1; i >= 0; i = i - 1 {
    result[i] = stack.pop().unwrap()
  }
  Ok(result)
}

///|
fn tinstr_result_arity(instr : TInstr, env : Env) -> Int {
  match instr {
    TCall(func_idx, _) =>
      match env.get_functype_by_funcidx(func_idx) {
        Some(FuncType(_, results)) => results.length()
        None => 0
      }
    TCallIndirect(type_idx, _, _, _) | TCallRef(type_idx, _, _) =>
      match env.resolve_functype(type_idx) {
        Some(FuncType(_, results)) => results.length()
        None => 0
      }
    TBlock(bt, _) | TLoop(bt, _) | TIf(bt, _, _, _) | TTryTable(bt, _, _) =>
      match env.expand_blocktype(bt) {
        Ok((_, results)) => results.length()
        Err(_) => 0
      }
    _ => 0
  }
}

///|
fn pop_return_values(
  stack : Array[TInstr],
  arity : Int,
  env : Env,
) -> Result[Array[TInstr], String] {
  if stack.length() >= arity {
    return pop_n(stack, arity)
  }
  if arity > 1 && stack.length() == 1 {
    if tinstr_result_arity(stack[0], env) == arity {
      return Ok([stack.pop().unwrap()])
    }
  }
  Err(
    "Stack underflow: need \{arity} values but only \{stack.length()} available",
  )
}

///|
fn block_type_inputs(bt : BlockType, env : Env) -> Int {
  match bt {
    VoidBlockType => 0
    ValTypeBlockType(_) => 0
    TypeIdxBlockType(idx) =>
      match env.resolve_functype(idx) {
        Some(FuncType(params, _)) => params.length()
        None => 0
      }
  }
}

///|
fn instr_to_tinstr(
  instr : Instruction,
  stack : Array[TInstr],
  env : Env,
) -> Result[Unit, String] {
  match instr {
    // === Constants ===
    I32Const(v) => stack.push(TInstr::i32_const(v))
    I64Const(v) => stack.push(TInstr::i64_const(v))
    F32Const(v) => stack.push(TInstr::f32_const(v))
    F64Const(v) => stack.push(TInstr::f64_const(v))
    RefNull(ht) => stack.push(TInstr::ref_null(ht))
    RefFunc(idx) => stack.push(TInstr::ref_func(idx))
    V128Const(
      b0,
      b1,
      b2,
      b3,
      b4,
      b5,
      b6,
      b7,
      b8,
      b9,
      b10,
      b11,
      b12,
      b13,
      b14,
      b15
    ) =>
      stack.push(
        TInstr::v128_const(
          b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15,
        ),
      )

    // === Nullary ===
    Unreachable => stack.push(TInstr::unreachable_())
    Nop => stack.push(TInstr::nop())
    LocalGet(idx) => stack.push(TInstr::local_get(idx))
    GlobalGet(idx) => stack.push(TInstr::global_get(idx))
    MemorySize(idx) => stack.push(TInstr::memory_size(idx))
    TableSize(idx) => stack.push(TInstr::table_size(idx))

    // === Unary numeric ===
    I32Eqz => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32_eqz(), op))
    }
    I64Eqz => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i64_eqz(), op))
    }
    I32Clz => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32_clz(), op))
    }
    I32Ctz => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32_ctz(), op))
    }
    I32Popcnt => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32_popcnt(), op))
    }
    I64Clz => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i64_clz(), op))
    }
    I64Ctz => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i64_ctz(), op))
    }
    I64Popcnt => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i64_popcnt(), op))
    }
    F32Abs => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f32_abs(), op))
    }
    F32Neg => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f32_neg(), op))
    }
    F32Ceil => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f32_ceil(), op))
    }
    F32Floor => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f32_floor(), op))
    }
    F32Trunc => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f32_trunc(), op))
    }
    F32Nearest => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f32_nearest(), op))
    }
    F32Sqrt => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f32_sqrt(), op))
    }
    F64Abs => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f64_abs(), op))
    }
    F64Neg => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f64_neg(), op))
    }
    F64Ceil => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f64_ceil(), op))
    }
    F64Floor => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f64_floor(), op))
    }
    F64Trunc => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f64_trunc(), op))
    }
    F64Nearest => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f64_nearest(), op))
    }
    F64Sqrt => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f64_sqrt(), op))
    }

    // === Conversions ===
    I32WrapI64 => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32_wrap_i64(), op))
    }
    I32TruncF32S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32_trunc_f32s(), op))
    }
    I32TruncF32U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32_trunc_f32u(), op))
    }
    I32TruncF64S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32_trunc_f64s(), op))
    }
    I32TruncF64U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32_trunc_f64u(), op))
    }
    I64ExtendI32S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i64_extend_i32s(), op))
    }
    I64ExtendI32U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i64_extend_i32u(), op))
    }
    I64TruncF32S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i64_trunc_f32s(), op))
    }
    I64TruncF32U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i64_trunc_f32u(), op))
    }
    I64TruncF64S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i64_trunc_f64s(), op))
    }
    I64TruncF64U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i64_trunc_f64u(), op))
    }
    F32ConvertI32S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f32_convert_i32s(), op))
    }
    F32ConvertI32U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f32_convert_i32u(), op))
    }
    F32ConvertI64S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f32_convert_i64s(), op))
    }
    F32ConvertI64U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f32_convert_i64u(), op))
    }
    F32DemoteF64 => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f32_demote_f64(), op))
    }
    F64ConvertI32S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f64_convert_i32s(), op))
    }
    F64ConvertI32U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f64_convert_i32u(), op))
    }
    F64ConvertI64S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f64_convert_i64s(), op))
    }
    F64ConvertI64U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f64_convert_i64u(), op))
    }
    F64PromoteF32 => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f64_promote_f32(), op))
    }
    I32ReinterpretF32 => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32_reinterpret_f32(), op))
    }
    I64ReinterpretF64 => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i64_reinterpret_f64(), op))
    }
    F32ReinterpretI32 => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f32_reinterpret_i32(), op))
    }
    F64ReinterpretI64 => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f64_reinterpret_i64(), op))
    }
    I32Extend8S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32_extend8s(), op))
    }
    I32Extend16S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32_extend16s(), op))
    }
    I64Extend8S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i64_extend8s(), op))
    }
    I64Extend16S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i64_extend16s(), op))
    }
    I64Extend32S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i64_extend32s(), op))
    }
    I32TruncSatF32S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32_trunc_sat_f32s(), op))
    }
    I32TruncSatF32U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32_trunc_sat_f32u(), op))
    }
    I32TruncSatF64S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32_trunc_sat_f64s(), op))
    }
    I32TruncSatF64U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32_trunc_sat_f64u(), op))
    }
    I64TruncSatF32S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i64_trunc_sat_f32s(), op))
    }
    I64TruncSatF32U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i64_trunc_sat_f32u(), op))
    }
    I64TruncSatF64S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i64_trunc_sat_f64s(), op))
    }
    I64TruncSatF64U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i64_trunc_sat_f64u(), op))
    }

    // === Binary numeric ===
    I32Eq => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32_eq(), lhs, rhs))
    }
    I32Ne => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32_ne(), lhs, rhs))
    }
    I32LtS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32_lt_s(), lhs, rhs))
    }
    I32LtU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32_lt_u(), lhs, rhs))
    }
    I32GtS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32_gt_s(), lhs, rhs))
    }
    I32GtU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32_gt_u(), lhs, rhs))
    }
    I32LeS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32_le_s(), lhs, rhs))
    }
    I32LeU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32_le_u(), lhs, rhs))
    }
    I32GeS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32_ge_s(), lhs, rhs))
    }
    I32GeU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32_ge_u(), lhs, rhs))
    }
    I64Eq => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64_eq(), lhs, rhs))
    }
    I64Ne => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64_ne(), lhs, rhs))
    }
    I64LtS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64_lt_s(), lhs, rhs))
    }
    I64LtU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64_lt_u(), lhs, rhs))
    }
    I64GtS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64_gt_s(), lhs, rhs))
    }
    I64GtU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64_gt_u(), lhs, rhs))
    }
    I64LeS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64_le_s(), lhs, rhs))
    }
    I64LeU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64_le_u(), lhs, rhs))
    }
    I64GeS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64_ge_s(), lhs, rhs))
    }
    I64GeU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64_ge_u(), lhs, rhs))
    }
    F32Eq => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f32_eq(), lhs, rhs))
    }
    F32Ne => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f32_ne(), lhs, rhs))
    }
    F32Lt => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f32_lt(), lhs, rhs))
    }
    F32Gt => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f32_gt(), lhs, rhs))
    }
    F32Le => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f32_le(), lhs, rhs))
    }
    F32Ge => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f32_ge(), lhs, rhs))
    }
    F64Eq => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f64_eq(), lhs, rhs))
    }
    F64Ne => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f64_ne(), lhs, rhs))
    }
    F64Lt => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f64_lt(), lhs, rhs))
    }
    F64Gt => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f64_gt(), lhs, rhs))
    }
    F64Le => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f64_le(), lhs, rhs))
    }
    F64Ge => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f64_ge(), lhs, rhs))
    }
    I32Add => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32_add(), lhs, rhs))
    }
    I32Sub => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32_sub(), lhs, rhs))
    }
    I32Mul => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32_mul(), lhs, rhs))
    }
    I32DivS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32_div_s(), lhs, rhs))
    }
    I32DivU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32_div_u(), lhs, rhs))
    }
    I32RemS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32_rem_s(), lhs, rhs))
    }
    I32RemU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32_rem_u(), lhs, rhs))
    }
    I32And => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32_and(), lhs, rhs))
    }
    I32Or => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32_or(), lhs, rhs))
    }
    I32Xor => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32_xor(), lhs, rhs))
    }
    I32Shl => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32_shl(), lhs, rhs))
    }
    I32ShrS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32_shr_s(), lhs, rhs))
    }
    I32ShrU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32_shr_u(), lhs, rhs))
    }
    I32Rotl => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32_rotl(), lhs, rhs))
    }
    I32Rotr => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32_rotr(), lhs, rhs))
    }
    I64Add => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64_add(), lhs, rhs))
    }
    I64Sub => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64_sub(), lhs, rhs))
    }
    I64Mul => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64_mul(), lhs, rhs))
    }
    I64DivS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64_div_s(), lhs, rhs))
    }
    I64DivU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64_div_u(), lhs, rhs))
    }
    I64RemS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64_rem_s(), lhs, rhs))
    }
    I64RemU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64_rem_u(), lhs, rhs))
    }
    I64And => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64_and(), lhs, rhs))
    }
    I64Or => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64_or(), lhs, rhs))
    }
    I64Xor => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64_xor(), lhs, rhs))
    }
    I64Shl => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64_shl(), lhs, rhs))
    }
    I64ShrS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64_shr_s(), lhs, rhs))
    }
    I64ShrU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64_shr_u(), lhs, rhs))
    }
    I64Rotl => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64_rotl(), lhs, rhs))
    }
    I64Rotr => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64_rotr(), lhs, rhs))
    }
    F32Add => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f32_add(), lhs, rhs))
    }
    F32Sub => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f32_sub(), lhs, rhs))
    }
    F32Mul => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f32_mul(), lhs, rhs))
    }
    F32Div => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f32_div(), lhs, rhs))
    }
    F32Min => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f32_min(), lhs, rhs))
    }
    F32Max => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f32_max(), lhs, rhs))
    }
    F32Copysign => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f32_copysign(), lhs, rhs))
    }
    F64Add => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f64_add(), lhs, rhs))
    }
    F64Sub => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f64_sub(), lhs, rhs))
    }
    F64Mul => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f64_mul(), lhs, rhs))
    }
    F64Div => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f64_div(), lhs, rhs))
    }
    F64Min => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f64_min(), lhs, rhs))
    }
    F64Max => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f64_max(), lhs, rhs))
    }
    F64Copysign => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f64_copysign(), lhs, rhs))
    }

    // === Other unary ===
    Drop => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::drop(op))
    }
    LocalSet(idx) => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::local_set(idx, op))
    }
    LocalTee(idx) => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::local_tee(idx, op))
    }
    GlobalSet(idx) => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::global_set(idx, op))
    }
    RefIsNull => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::ref_is_null(op))
    }
    RefAsNonNull => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::ref_as_non_null(op))
    }
    RefEq => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::ref_eq(lhs, rhs))
    }
    RefI31 => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::ref_i31(op))
    }
    I31GetS => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::i31_get_s(op))
    }
    I31GetU => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::i31_get_u(op))
    }
    ArrayLen => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::array_len(op))
    }
    AnyConvertExtern => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::any_convert_extern(op))
    }
    ExternConvertAny => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::extern_convert_any(op))
    }
    ThrowRef => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::throw_ref(op))
    }

    // === Loads ===
    I32Load(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::i32_load(), memarg, addr))
    }
    I64Load(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::i64_load(), memarg, addr))
    }
    F32Load(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::f32_load(), memarg, addr))
    }
    F64Load(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::f64_load(), memarg, addr))
    }
    I32Load8S(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::i32_load8s(), memarg, addr))
    }
    I32Load8U(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::i32_load8u(), memarg, addr))
    }
    I32Load16S(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::i32_load16s(), memarg, addr))
    }
    I32Load16U(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::i32_load16u(), memarg, addr))
    }
    I64Load8S(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::i64_load8s(), memarg, addr))
    }
    I64Load8U(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::i64_load8u(), memarg, addr))
    }
    I64Load16S(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::i64_load16s(), memarg, addr))
    }
    I64Load16U(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::i64_load16u(), memarg, addr))
    }
    I64Load32S(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::i64_load32s(), memarg, addr))
    }
    I64Load32U(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::i64_load32u(), memarg, addr))
    }
    I32AtomicLoad(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::i32_atomic_load(), memarg, addr))
    }
    I64AtomicLoad(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::i64_atomic_load(), memarg, addr))
    }
    I32AtomicLoad8U(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::i32_atomic_load8_u(), memarg, addr))
    }
    I32AtomicLoad16U(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::i32_atomic_load16_u(), memarg, addr))
    }
    I64AtomicLoad8U(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::i64_atomic_load8_u(), memarg, addr))
    }
    I64AtomicLoad16U(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::i64_atomic_load16_u(), memarg, addr))
    }
    I64AtomicLoad32U(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::i64_atomic_load32_u(), memarg, addr))
    }

    // === Stores ===
    I32Store(memarg) => {
      let value = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::store(StoreOp::i32_store(), memarg, addr, value))
    }
    I64Store(memarg) => {
      let value = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::store(StoreOp::i64_store(), memarg, addr, value))
    }
    F32Store(memarg) => {
      let value = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::store(StoreOp::f32_store(), memarg, addr, value))
    }
    F64Store(memarg) => {
      let value = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::store(StoreOp::f64_store(), memarg, addr, value))
    }
    I32Store8(memarg) => {
      let value = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::store(StoreOp::i32_store8(), memarg, addr, value))
    }
    I32Store16(memarg) => {
      let value = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::store(StoreOp::i32_store16(), memarg, addr, value))
    }
    I64Store8(memarg) => {
      let value = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::store(StoreOp::i64_store8(), memarg, addr, value))
    }
    I64Store16(memarg) => {
      let value = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::store(StoreOp::i64_store16(), memarg, addr, value))
    }
    I64Store32(memarg) => {
      let value = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::store(StoreOp::i64_store32(), memarg, addr, value))
    }
    I32AtomicStore(memarg) => {
      let value = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::store(StoreOp::i32_atomic_store(), memarg, addr, value),
      )
    }
    I64AtomicStore(memarg) => {
      let value = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::store(StoreOp::i64_atomic_store(), memarg, addr, value),
      )
    }
    I32AtomicStore8(memarg) => {
      let value = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::store(StoreOp::i32_atomic_store8(), memarg, addr, value),
      )
    }
    I32AtomicStore16(memarg) => {
      let value = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::store(StoreOp::i32_atomic_store16(), memarg, addr, value),
      )
    }
    I64AtomicStore8(memarg) => {
      let value = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::store(StoreOp::i64_atomic_store8(), memarg, addr, value),
      )
    }
    I64AtomicStore16(memarg) => {
      let value = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::store(StoreOp::i64_atomic_store16(), memarg, addr, value),
      )
    }
    I64AtomicStore32(memarg) => {
      let value = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::store(StoreOp::i64_atomic_store32(), memarg, addr, value),
      )
    }

    // === Memory operations ===
    MemoryGrow(idx) => {
      let pages = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::memory_grow(idx, pages))
    }
    MemoryFill(idx) => {
      let len = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let dest = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::memory_fill(idx, dest, val, len))
    }
    MemoryCopy(dst, src) => {
      let len = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let src_addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let dst_addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::memory_copy(dst, src, dst_addr, src_addr, len))
    }
    MemoryInit(data_idx, mem_idx) => {
      let len = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let src = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let dst = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::memory_init(data_idx, mem_idx, dst, src, len))
    }
    DataDrop(idx) => stack.push(TInstr::data_drop(idx))
    MemoryAtomicNotify(memarg) => {
      let count = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::memory_atomic_notify(memarg, addr, count))
    }
    MemoryAtomicWait32(memarg) => {
      let timeout = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let expected = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::memory_atomic_wait32(memarg, addr, expected, timeout))
    }
    MemoryAtomicWait64(memarg) => {
      let timeout = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let expected = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::memory_atomic_wait64(memarg, addr, expected, timeout))
    }
    AtomicFence => stack.push(TInstr::atomic_fence())
    AtomicRmw(op, memarg) => {
      let value = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::atomic_rmw(op, memarg, addr, value))
    }
    AtomicCmpxchg(op, memarg) => {
      let replacement = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let expected = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::atomic_cmpxchg(op, memarg, addr, expected, replacement),
      )
    }

    // === Table operations ===
    TableGet(idx) => {
      let i = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::table_get(idx, i))
    }
    TableSet(idx) => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let i = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::table_set(idx, i, val))
    }
    TableGrow(idx) => {
      let n = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::table_grow(idx, val, n))
    }
    TableFill(idx) => {
      let n = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let i = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::table_fill(idx, i, val, n))
    }
    TableCopy(dst, src) => {
      let n = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let s = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let d = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::table_copy(dst, src, d, s, n))
    }
    TableInit(elem_idx, table_idx) => {
      let n = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let s = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let d = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::table_init(elem_idx, table_idx, d, s, n))
    }
    ElemDrop(idx) => stack.push(TInstr::elem_drop(idx))

    // === Select ===
    Select(types) => {
      let cond = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let val2 = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let val1 = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::select(types, cond, val1, val2))
    }

    // === Control flow ===
    Block(bt, body) => {
      let n_inputs = block_type_inputs(bt, env)
      let inputs = match pop_n(stack, n_inputs) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      // Create a new stack with inputs for the block body
      let body_stack : Array[TInstr] = []
      for input in inputs {
        body_stack.push(input)
      }
      for instr in body.0 {
        match instr_to_tinstr(instr, body_stack, env) {
          Ok(_) => ()
          Err(t) => return Err(t)
        }
      }
      stack.push(TInstr::block(bt, TExpr::new(body_stack)))
    }
    Loop(bt, body) => {
      let n_inputs = block_type_inputs(bt, env)
      let inputs = match pop_n(stack, n_inputs) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let body_stack = []
      for input in inputs {
        body_stack.push(input)
      }
      for instr in body.0 {
        match instr_to_tinstr(instr, body_stack, env) {
          Ok(_) => ()
          Err(t) => return Err(t)
        }
      }
      stack.push(TInstr::loop_(bt, TExpr::new(body_stack)))
    }
    If(bt, then_branch, else_branch) => {
      let cond = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let n_inputs = block_type_inputs(bt, env)
      let inputs = match pop_n(stack, n_inputs) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let then_stack : Array[TInstr] = []
      for input in inputs {
        then_stack.push(input)
      }
      for instr in then_branch {
        match instr_to_tinstr(instr, then_stack, env) {
          Ok(_) => ()
          Err(t) => return Err(t)
        }
      }
      let else_texpr : TExpr? = match else_branch {
        Some(else_instrs) => {
          let else_stack : Array[TInstr] = []
          for input in inputs {
            else_stack.push(input)
          }
          for instr in else_instrs {
            match instr_to_tinstr(instr, else_stack, env) {
              Ok(_) => ()
              Err(t) => return Err(t)
            }
          }
          Some(TExpr::new(else_stack))
        }
        None => None
      }
      stack.push(TInstr::if_(bt, cond, TExpr::new(then_stack), else_texpr))
    }
    TryTable(bt, catches, body) => {
      let n_inputs = block_type_inputs(bt, env)
      let inputs = match pop_n(stack, n_inputs) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let body_stack = []
      for input in inputs {
        body_stack.push(input)
      }
      for instr in body.0 {
        match instr_to_tinstr(instr, body_stack, env) {
          Ok(_) => ()
          Err(t) => return Err(t)
        }
      }
      stack.push(TInstr::try_table(bt, catches, TExpr::new(body_stack)))
    }
    Throw(tag_idx) => {
      let n_args = match env.resolve_tag_functype(tag_idx) {
        Some(FuncType(params, _)) => params.length()
        None => 0
      }
      let args = match pop_n(stack, n_args) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::throw_(tag_idx, args))
    }

    // === Branches ===
    Br(label) => {
      // Get the arity from label
      let arity = match env.get_label(label) {
        Some(types) => types.length()
        None => 0
      }
      let values = match pop_n(stack, arity) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::br(label, values))
    }
    BrIf(label) => {
      let cond = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let arity = match env.get_label(label) {
        Some(types) => types.length()
        None => 0
      }
      let values = match pop_n(stack, arity) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::br_if(label, cond, values))
    }
    BrTable(labels, default) => {
      let idx = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let arity = match env.get_label(default) {
        Some(types) => types.length()
        None => 0
      }
      let values = match pop_n(stack, arity) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::br_table(labels, default, idx, values))
    }
    BrOnNull(label) => {
      let ref_ = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let arity = match env.get_label(label) {
        Some(types) => types.length()
        None => 0
      }
      let values = match pop_n(stack, arity) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::br_on_null(label, ref_, values))
    }
    BrOnNonNull(label) => {
      let ref_ = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let arity = match env.get_label(label) {
        Some(types) => types.length()
        None => 0
      }
      let values = match pop_n(stack, arity) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::br_on_non_null(label, ref_, values))
    }
    BrOnCast(label, castop, ht1, ht2) => {
      let ref_ = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let arity = match env.get_label(label) {
        Some(types) => types.length()
        None => 0
      }
      let values = match pop_n(stack, arity) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::br_on_cast(label, castop.0, ht1, castop.1, ht2, ref_, values),
      )
    }
    BrOnCastFail(label, castop, ht1, ht2) => {
      let ref_ = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let arity = match env.get_label(label) {
        Some(types) => types.length()
        None => 0
      }
      let values = match pop_n(stack, arity) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::br_on_cast_fail(
          label,
          castop.0,
          ht1,
          castop.1,
          ht2,
          ref_,
          values,
        ),
      )
    }
    Return => {
      let arity = match env.return_type {
        Some(types) => types.length()
        None => 0
      }
      let values = match pop_return_values(stack, arity, env) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::return_(values))
    }

    // === Calls ===
    Call(func_idx) => {
      let n_args = match env.funcs.get(func_idx.0.reinterpret_as_int()) {
        Some(FuncType(params, _)) => params.length()
        None => 0
      }
      let args = match pop_n(stack, n_args) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::call(func_idx, args))
    }
    CallIndirect(type_idx, table_idx) => {
      let idx = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let n_args = match env.resolve_functype(type_idx) {
        Some(FuncType(params, _)) => params.length()
        None => 0
      }
      let args = match pop_n(stack, n_args) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::call_indirect(type_idx, table_idx, args, idx))
    }
    CallRef(type_idx) => {
      let ref_ = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let n_args = match env.resolve_functype(type_idx) {
        Some(FuncType(params, _)) => params.length()
        None => 0
      }
      let args = match pop_n(stack, n_args) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::call_ref(type_idx, args, ref_))
    }
    ReturnCall(func_idx) => {
      let n_args = match env.funcs.get(func_idx.0.reinterpret_as_int()) {
        Some(FuncType(params, _)) => params.length()
        None => 0
      }
      let args = match pop_n(stack, n_args) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::return_call(func_idx, args))
    }
    ReturnCallIndirect(type_idx, table_idx) => {
      let idx = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let n_args = match env.resolve_functype(type_idx) {
        Some(FuncType(params, _)) => params.length()
        None => 0
      }
      let args = match pop_n(stack, n_args) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::return_call_indirect(type_idx, table_idx, args, idx))
    }
    ReturnCallRef(type_idx) => {
      let ref_ = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let n_args = match env.resolve_functype(type_idx) {
        Some(FuncType(params, _)) => params.length()
        None => 0
      }
      let args = match pop_n(stack, n_args) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::return_call_ref(type_idx, args, ref_))
    }

    // === GC: Structs ===
    StructNew(type_idx) => {
      let n_fields = match env.resolve_comptype(type_idx) {
        Some(StructCompType(fields)) => fields.length()
        _ => 0
      }
      let fields = match pop_n(stack, n_fields) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::struct_new(type_idx, fields))
    }
    StructNewDefault(type_idx) =>
      stack.push(TInstr::struct_new_default(type_idx))
    StructGet(type_idx, field_idx) => {
      let struct_ref = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::struct_get(type_idx, field_idx, struct_ref))
    }
    StructGetS(type_idx, field_idx) => {
      let struct_ref = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::struct_get_s(type_idx, field_idx, struct_ref))
    }
    StructGetU(type_idx, field_idx) => {
      let struct_ref = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::struct_get_u(type_idx, field_idx, struct_ref))
    }
    StructSet(type_idx, field_idx) => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let struct_ref = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::struct_set(type_idx, field_idx, struct_ref, val))
    }

    // === GC: Arrays ===
    ArrayNew(type_idx) => {
      let len = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let init = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::array_new(type_idx, init, len))
    }
    ArrayNewDefault(type_idx) => {
      let len = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::array_new_default(type_idx, len))
    }
    ArrayNewFixed(type_idx, n) => {
      let elems = match pop_n(stack, n.0.reinterpret_as_int()) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::array_new_fixed(type_idx, elems))
    }
    ArrayNewData(type_idx, data_idx) => {
      let len = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let offset = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::array_new_data(type_idx, data_idx, offset, len))
    }
    ArrayNewElem(type_idx, elem_idx) => {
      let len = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let offset = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::array_new_elem(type_idx, elem_idx, offset, len))
    }
    ArrayGet(type_idx) => {
      let idx = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let arr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::array_get(type_idx, arr, idx))
    }
    ArrayGetS(type_idx) => {
      let idx = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let arr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::array_get_s(type_idx, arr, idx))
    }
    ArrayGetU(type_idx) => {
      let idx = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let arr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::array_get_u(type_idx, arr, idx))
    }
    ArraySet(type_idx) => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let idx = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let arr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::array_set(type_idx, arr, idx, val))
    }
    ArrayFill(type_idx) => {
      let len = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let offset = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let arr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::array_fill(type_idx, arr, offset, val, len))
    }
    ArrayCopy(dst_type, src_type) => {
      let len = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let src_offset = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let src = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let dst_offset = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let dst = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::array_copy(
          dst_type, src_type, dst, dst_offset, src, src_offset, len,
        ),
      )
    }
    ArrayInitData(type_idx, data_idx) => {
      let len = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let src = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let dst = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let arr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::array_init_data(type_idx, data_idx, arr, dst, src, len),
      )
    }
    ArrayInitElem(type_idx, elem_idx) => {
      let len = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let src = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let dst = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let arr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::array_init_elem(type_idx, elem_idx, arr, dst, src, len),
      )
    }

    // === GC: Casts ===
    RefGetDesc => {
      let ref_ = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::ref_get_desc(ref_))
    }
    RefTest(nullable, ht) => {
      let ref_ = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::ref_test(nullable, ht, ref_))
    }
    RefCast(nullable, ht) => {
      let ref_ = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::ref_cast(nullable, ht, ref_))
    }
    RefTestDesc(nullable, ht) => {
      let ref_ = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::ref_test_desc(nullable, ht, ref_))
    }
    RefCastDescEq(nullable, ht) => {
      let ref_ = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::ref_cast_desc_eq(nullable, ht, ref_))
    }

    // === SIMD ===
    V128Load(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::v128_load(), memarg, addr))
    }
    V128Load8x8S(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::v128_load8x8s(), memarg, addr))
    }
    V128Load8x8U(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::v128_load8x8u(), memarg, addr))
    }
    V128Load16x4S(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::v128_load16x4s(), memarg, addr))
    }
    V128Load16x4U(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::v128_load16x4u(), memarg, addr))
    }
    V128Load32x2S(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::v128_load32x2s(), memarg, addr))
    }
    V128Load32x2U(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::v128_load32x2u(), memarg, addr))
    }
    V128Load8Splat(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::v128_load8_splat(), memarg, addr))
    }
    V128Load16Splat(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::v128_load16_splat(), memarg, addr))
    }
    V128Load32Splat(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::v128_load32_splat(), memarg, addr))
    }
    V128Load64Splat(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::v128_load64_splat(), memarg, addr))
    }
    V128Load32Zero(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::v128_load32_zero(), memarg, addr))
    }
    V128Load64Zero(memarg) => {
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::load(LoadOp::v128_load64_zero(), memarg, addr))
    }
    V128Store(memarg) => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::store(StoreOp::v128_store(), memarg, addr, val))
    }
    V128Load8Lane(memarg, lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::v128_load_lane(
          V128LoadLaneOp::v128_load8_lane(),
          memarg,
          lane,
          addr,
          vec,
        ),
      )
    }
    V128Load16Lane(memarg, lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::v128_load_lane(
          V128LoadLaneOp::v128_load16_lane(),
          memarg,
          lane,
          addr,
          vec,
        ),
      )
    }
    V128Load32Lane(memarg, lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::v128_load_lane(
          V128LoadLaneOp::v128_load32_lane(),
          memarg,
          lane,
          addr,
          vec,
        ),
      )
    }
    V128Load64Lane(memarg, lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::v128_load_lane(
          V128LoadLaneOp::v128_load64_lane(),
          memarg,
          lane,
          addr,
          vec,
        ),
      )
    }
    V128Store8Lane(memarg, lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::v128_store_lane(
          V128StoreLaneOp::v128_store8_lane(),
          memarg,
          lane,
          addr,
          vec,
        ),
      )
    }
    V128Store16Lane(memarg, lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::v128_store_lane(
          V128StoreLaneOp::v128_store16_lane(),
          memarg,
          lane,
          addr,
          vec,
        ),
      )
    }
    V128Store32Lane(memarg, lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::v128_store_lane(
          V128StoreLaneOp::v128_store32_lane(),
          memarg,
          lane,
          addr,
          vec,
        ),
      )
    }
    V128Store64Lane(memarg, lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let addr = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::v128_store_lane(
          V128StoreLaneOp::v128_store64_lane(),
          memarg,
          lane,
          addr,
          vec,
        ),
      )
    }

    // === SIMD: Splat ===
    I8x16Splat => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::i8x16_splat(val))
    }
    I16x8Splat => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::i16x8_splat(val))
    }
    I32x4Splat => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::i32x4_splat(val))
    }
    I64x2Splat => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::i64x2_splat(val))
    }
    F32x4Splat => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::f32x4_splat(val))
    }
    F64x2Splat => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::f64x2_splat(val))
    }

    // === SIMD: Extract lane ===
    I8x16ExtractLaneS(lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::extract_lane(ExtractLaneOp::i8x16_extract_lane_s(), lane, vec),
      )
    }
    I8x16ExtractLaneU(lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::extract_lane(ExtractLaneOp::i8x16_extract_lane_u(), lane, vec),
      )
    }
    I16x8ExtractLaneS(lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::extract_lane(ExtractLaneOp::i16x8_extract_lane_s(), lane, vec),
      )
    }
    I16x8ExtractLaneU(lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::extract_lane(ExtractLaneOp::i16x8_extract_lane_u(), lane, vec),
      )
    }
    I32x4ExtractLane(lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::extract_lane(ExtractLaneOp::i32x4_extract_lane(), lane, vec),
      )
    }
    I64x2ExtractLane(lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::extract_lane(ExtractLaneOp::i64x2_extract_lane(), lane, vec),
      )
    }
    F32x4ExtractLane(lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::extract_lane(ExtractLaneOp::f32x4_extract_lane(), lane, vec),
      )
    }
    F64x2ExtractLane(lane) => {
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::extract_lane(ExtractLaneOp::f64x2_extract_lane(), lane, vec),
      )
    }

    // === SIMD: Replace lane ===
    I8x16ReplaceLane(lane) => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::replace_lane(
          ReplaceLaneOp::i8x16_replace_lane(),
          lane,
          vec,
          val,
        ),
      )
    }
    I16x8ReplaceLane(lane) => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::replace_lane(
          ReplaceLaneOp::i16x8_replace_lane(),
          lane,
          vec,
          val,
        ),
      )
    }
    I32x4ReplaceLane(lane) => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::replace_lane(
          ReplaceLaneOp::i32x4_replace_lane(),
          lane,
          vec,
          val,
        ),
      )
    }
    I64x2ReplaceLane(lane) => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::replace_lane(
          ReplaceLaneOp::i64x2_replace_lane(),
          lane,
          vec,
          val,
        ),
      )
    }
    F32x4ReplaceLane(lane) => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::replace_lane(
          ReplaceLaneOp::f32x4_replace_lane(),
          lane,
          vec,
          val,
        ),
      )
    }
    F64x2ReplaceLane(lane) => {
      let val = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::replace_lane(
          ReplaceLaneOp::f64x2_replace_lane(),
          lane,
          vec,
          val,
        ),
      )
    }

    // === SIMD: Shuffle/Swizzle ===
    I8x16Shuffle(
      l0,
      l1,
      l2,
      l3,
      l4,
      l5,
      l6,
      l7,
      l8,
      l9,
      l10,
      l11,
      l12,
      l13,
      l14,
      l15
    ) => {
      let v2 = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let v1 = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::i8x16_shuffle(
          l0, l1, l2, l3, l4, l5, l6, l7, l8, l9, l10, l11, l12, l13, l14, l15, v1,
          v2,
        ),
      )
    }
    I8x16Swizzle => {
      let indices = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::i8x16_swizzle(vec, indices))
    }
    I8x16RelaxedSwizzle => {
      let indices = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::i8x16_relaxed_swizzle(vec, indices))
    }

    // === SIMD: Unary v128 -> v128 ===
    V128Not => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::v128_not(), op))
    }
    I8x16Abs => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i8x16_abs(), op))
    }
    I8x16Neg => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i8x16_neg(), op))
    }
    I8x16Popcnt => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i8x16_popcnt(), op))
    }
    I16x8Abs => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i16x8_abs(), op))
    }
    // === SIMD: Unary v128 -> v128 (continued) ===
    I16x8Neg => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i16x8_neg(), op))
    }
    I32x4Abs => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32x4_abs(), op))
    }
    I32x4Neg => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32x4_neg(), op))
    }
    I64x2Abs => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i64x2_abs(), op))
    }
    I64x2Neg => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i64x2_neg(), op))
    }
    F32x4Abs => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f32x4_abs(), op))
    }
    F32x4Neg => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f32x4_neg(), op))
    }
    F32x4Sqrt => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f32x4_sqrt(), op))
    }
    F32x4Ceil => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f32x4_ceil(), op))
    }
    F32x4Floor => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f32x4_floor(), op))
    }
    F32x4Trunc => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f32x4_trunc(), op))
    }
    F32x4Nearest => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f32x4_nearest(), op))
    }
    F64x2Abs => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f64x2_abs(), op))
    }
    F64x2Neg => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f64x2_neg(), op))
    }
    F64x2Sqrt => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f64x2_sqrt(), op))
    }
    F64x2Ceil => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f64x2_ceil(), op))
    }
    F64x2Floor => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f64x2_floor(), op))
    }
    F64x2Trunc => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f64x2_trunc(), op))
    }
    F64x2Nearest => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f64x2_nearest(), op))
    }

    // === SIMD: v128 -> i32 (bitmask/alltrue) ===
    V128AnyTrue => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::v128_any_true(), op))
    }
    I8x16AllTrue => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i8x16_all_true(), op))
    }
    I8x16Bitmask => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i8x16_bitmask(), op))
    }
    I16x8AllTrue => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i16x8_all_true(), op))
    }
    I16x8Bitmask => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i16x8_bitmask(), op))
    }
    I32x4AllTrue => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32x4_all_true(), op))
    }
    I32x4Bitmask => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32x4_bitmask(), op))
    }
    I64x2AllTrue => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i64x2_all_true(), op))
    }
    I64x2Bitmask => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i64x2_bitmask(), op))
    }

    // === SIMD: Extend (v128 -> v128) ===
    I16x8ExtendLowI8x16S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i16x8_extend_low_i8x16s(), op))
    }
    I16x8ExtendHighI8x16S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i16x8_extend_high_i8x16s(), op))
    }
    I16x8ExtendLowI8x16U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i16x8_extend_low_i8x16u(), op))
    }
    I16x8ExtendHighI8x16U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i16x8_extend_high_i8x16u(), op))
    }
    I32x4ExtendLowI16x8S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32x4_extend_low_i16x8s(), op))
    }
    I32x4ExtendHighI16x8S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32x4_extend_high_i16x8s(), op))
    }
    I32x4ExtendLowI16x8U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32x4_extend_low_i16x8u(), op))
    }
    I32x4ExtendHighI16x8U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32x4_extend_high_i16x8u(), op))
    }
    I64x2ExtendLowI32x4S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i64x2_extend_low_i32x4s(), op))
    }
    I64x2ExtendHighI32x4S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i64x2_extend_high_i32x4s(), op))
    }
    I64x2ExtendLowI32x4U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i64x2_extend_low_i32x4u(), op))
    }
    I64x2ExtendHighI32x4U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i64x2_extend_high_i32x4u(), op))
    }

    // === SIMD: Pairwise add (v128 -> v128) ===
    I16x8ExtaddPairwiseI8x16S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i16x8_extadd_pairwise_i8x16s(), op))
    }
    I16x8ExtaddPairwiseI8x16U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i16x8_extadd_pairwise_i8x16u(), op))
    }
    I32x4ExtaddPairwiseI16x8S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32x4_extadd_pairwise_i16x8s(), op))
    }
    I32x4ExtaddPairwiseI16x8U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32x4_extadd_pairwise_i16x8u(), op))
    }

    // === SIMD: Conversion (v128 -> v128) ===
    F32x4DemoteF64x2Zero => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f32x4_demote_f64x2_zero(), op))
    }
    F64x2PromoteLowF32x4 => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f64x2_promote_low_f32x4(), op))
    }
    I32x4TruncSatF32x4S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32x4_trunc_sat_f32x4s(), op))
    }
    I32x4TruncSatF32x4U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32x4_trunc_sat_f32x4u(), op))
    }
    F32x4ConvertI32x4S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f32x4_convert_i32x4s(), op))
    }
    F32x4ConvertI32x4U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f32x4_convert_i32x4u(), op))
    }
    I32x4TruncSatF64x2SZero => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32x4_trunc_sat_f64x2s_zero(), op))
    }
    I32x4TruncSatF64x2UZero => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32x4_trunc_sat_f64x2u_zero(), op))
    }
    F64x2ConvertLowI32x4S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f64x2_convert_low_i32x4s(), op))
    }
    F64x2ConvertLowI32x4U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::f64x2_convert_low_i32x4u(), op))
    }

    // === SIMD: Relaxed truncation (v128 -> v128) ===
    I32x4RelaxedTruncF32x4S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32x4_relaxed_trunc_f32x4s(), op))
    }
    I32x4RelaxedTruncF32x4U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32x4_relaxed_trunc_f32x4u(), op))
    }
    I32x4RelaxedTruncZeroF64x2S => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32x4_relaxed_trunc_zero_f64x2s(), op))
    }
    I32x4RelaxedTruncZeroF64x2U => {
      let op = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::unary(UnaryOp::i32x4_relaxed_trunc_zero_f64x2u(), op))
    }

    // === SIMD: Binary bitwise (v128, v128 -> v128) ===
    V128And => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::v128_and(), lhs, rhs))
    }
    V128Andnot => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::v128_andnot(), lhs, rhs))
    }
    V128Or => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::v128_or(), lhs, rhs))
    }
    V128Xor => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::v128_xor(), lhs, rhs))
    }

    // === SIMD: i8x16 comparisons ===
    I8x16Eq => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i8x16_eq(), lhs, rhs))
    }
    I8x16Ne => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i8x16_ne(), lhs, rhs))
    }
    I8x16LtS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i8x16_lt_s(), lhs, rhs))
    }
    I8x16LtU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i8x16_lt_u(), lhs, rhs))
    }
    I8x16GtS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i8x16_gt_s(), lhs, rhs))
    }
    I8x16GtU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i8x16_gt_u(), lhs, rhs))
    }
    I8x16LeS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i8x16_le_s(), lhs, rhs))
    }
    I8x16LeU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i8x16_le_u(), lhs, rhs))
    }
    I8x16GeS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i8x16_ge_s(), lhs, rhs))
    }
    I8x16GeU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i8x16_ge_u(), lhs, rhs))
    }

    // === SIMD: i16x8 comparisons ===
    I16x8Eq => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i16x8_eq(), lhs, rhs))
    }
    I16x8Ne => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i16x8_ne(), lhs, rhs))
    }
    I16x8LtS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i16x8_lt_s(), lhs, rhs))
    }
    I16x8LtU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i16x8_lt_u(), lhs, rhs))
    }
    I16x8GtS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i16x8_gt_s(), lhs, rhs))
    }
    I16x8GtU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i16x8_gt_u(), lhs, rhs))
    }
    I16x8LeS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i16x8_le_s(), lhs, rhs))
    }
    I16x8LeU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i16x8_le_u(), lhs, rhs))
    }
    I16x8GeS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i16x8_ge_s(), lhs, rhs))
    }
    I16x8GeU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i16x8_ge_u(), lhs, rhs))
    }

    // === SIMD: i32x4 comparisons ===
    I32x4Eq => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32x4_eq(), lhs, rhs))
    }
    I32x4Ne => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32x4_ne(), lhs, rhs))
    }
    I32x4LtS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32x4_lt_s(), lhs, rhs))
    }
    I32x4LtU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32x4_lt_u(), lhs, rhs))
    }
    I32x4GtS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32x4_gt_s(), lhs, rhs))
    }
    I32x4GtU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32x4_gt_u(), lhs, rhs))
    }
    I32x4LeS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32x4_le_s(), lhs, rhs))
    }
    I32x4LeU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32x4_le_u(), lhs, rhs))
    }
    I32x4GeS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32x4_ge_s(), lhs, rhs))
    }
    I32x4GeU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32x4_ge_u(), lhs, rhs))
    }

    // === SIMD: i64x2 comparisons ===
    I64x2Eq => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64x2_eq(), lhs, rhs))
    }
    I64x2Ne => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64x2_ne(), lhs, rhs))
    }
    I64x2LtS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64x2_lt_s(), lhs, rhs))
    }
    I64x2GtS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64x2_gt_s(), lhs, rhs))
    }
    I64x2LeS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64x2_le_s(), lhs, rhs))
    }
    I64x2GeS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64x2_ge_s(), lhs, rhs))
    }

    // === SIMD: f32x4 comparisons ===
    F32x4Eq => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f32x4_eq(), lhs, rhs))
    }
    F32x4Ne => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f32x4_ne(), lhs, rhs))
    }
    F32x4Lt => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f32x4_lt(), lhs, rhs))
    }
    F32x4Gt => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f32x4_gt(), lhs, rhs))
    }
    F32x4Le => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f32x4_le(), lhs, rhs))
    }
    F32x4Ge => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f32x4_ge(), lhs, rhs))
    }

    // === SIMD: f64x2 comparisons ===
    F64x2Eq => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f64x2_eq(), lhs, rhs))
    }
    F64x2Ne => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f64x2_ne(), lhs, rhs))
    }
    F64x2Lt => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f64x2_lt(), lhs, rhs))
    }
    F64x2Gt => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f64x2_gt(), lhs, rhs))
    }
    F64x2Le => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f64x2_le(), lhs, rhs))
    }
    F64x2Ge => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f64x2_ge(), lhs, rhs))
    }

    // === SIMD: i8x16 arithmetic ===
    I8x16Add => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i8x16_add(), lhs, rhs))
    }
    I8x16AddSatS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i8x16_add_sat_s(), lhs, rhs))
    }
    I8x16AddSatU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i8x16_add_sat_u(), lhs, rhs))
    }
    I8x16Sub => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i8x16_sub(), lhs, rhs))
    }
    I8x16SubSatS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i8x16_sub_sat_s(), lhs, rhs))
    }
    I8x16SubSatU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i8x16_sub_sat_u(), lhs, rhs))
    }
    I8x16MinS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i8x16_min_s(), lhs, rhs))
    }
    I8x16MinU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i8x16_min_u(), lhs, rhs))
    }
    I8x16MaxS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i8x16_max_s(), lhs, rhs))
    }
    I8x16MaxU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i8x16_max_u(), lhs, rhs))
    }
    I8x16AvgrU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i8x16_avgr_u(), lhs, rhs))
    }
    I8x16NarrowI16x8S => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i8x16_narrow_i16x8s(), lhs, rhs))
    }
    I8x16NarrowI16x8U => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i8x16_narrow_i16x8u(), lhs, rhs))
    }

    // === SIMD: i16x8 arithmetic ===
    I16x8Add => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i16x8_add(), lhs, rhs))
    }
    I16x8AddSatS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i16x8_add_sat_s(), lhs, rhs))
    }
    I16x8AddSatU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i16x8_add_sat_u(), lhs, rhs))
    }
    I16x8Sub => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i16x8_sub(), lhs, rhs))
    }
    I16x8SubSatS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i16x8_sub_sat_s(), lhs, rhs))
    }
    I16x8SubSatU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i16x8_sub_sat_u(), lhs, rhs))
    }
    I16x8Mul => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i16x8_mul(), lhs, rhs))
    }
    I16x8MinS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i16x8_min_s(), lhs, rhs))
    }
    I16x8MinU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i16x8_min_u(), lhs, rhs))
    }
    I16x8MaxS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i16x8_max_s(), lhs, rhs))
    }
    I16x8MaxU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i16x8_max_u(), lhs, rhs))
    }
    I16x8AvgrU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i16x8_avgr_u(), lhs, rhs))
    }
    I16x8Q15mulrSatS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i16x8q15mulr_sat_s(), lhs, rhs))
    }
    I16x8NarrowI32x4S => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i16x8_narrow_i32x4s(), lhs, rhs))
    }
    I16x8NarrowI32x4U => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i16x8_narrow_i32x4u(), lhs, rhs))
    }
    I16x8ExtmulLowI8x16S => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i16x8_extmul_low_i8x16s(), lhs, rhs))
    }
    I16x8ExtmulHighI8x16S => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i16x8_extmul_high_i8x16s(), lhs, rhs))
    }
    I16x8ExtmulLowI8x16U => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i16x8_extmul_low_i8x16u(), lhs, rhs))
    }
    I16x8ExtmulHighI8x16U => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i16x8_extmul_high_i8x16u(), lhs, rhs))
    }

    // === SIMD: i32x4 arithmetic ===
    I32x4Add => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32x4_add(), lhs, rhs))
    }
    I32x4Sub => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32x4_sub(), lhs, rhs))
    }
    I32x4Mul => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32x4_mul(), lhs, rhs))
    }
    I32x4MinS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32x4_min_s(), lhs, rhs))
    }
    I32x4MinU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32x4_min_u(), lhs, rhs))
    }
    I32x4MaxS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32x4_max_s(), lhs, rhs))
    }
    I32x4MaxU => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32x4_max_u(), lhs, rhs))
    }
    I32x4DotI16x8S => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32x4_dot_i16x8s(), lhs, rhs))
    }
    I32x4ExtmulLowI16x8S => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32x4_extmul_low_i16x8s(), lhs, rhs))
    }
    I32x4ExtmulHighI16x8S => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32x4_extmul_high_i16x8s(), lhs, rhs))
    }
    I32x4ExtmulLowI16x8U => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32x4_extmul_low_i16x8u(), lhs, rhs))
    }
    I32x4ExtmulHighI16x8U => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i32x4_extmul_high_i16x8u(), lhs, rhs))
    }

    // === SIMD: i64x2 arithmetic ===
    I64x2Add => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64x2_add(), lhs, rhs))
    }
    I64x2Sub => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64x2_sub(), lhs, rhs))
    }
    I64x2Mul => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64x2_mul(), lhs, rhs))
    }
    I64x2ExtmulLowI32x4S => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64x2_extmul_low_i32x4s(), lhs, rhs))
    }
    I64x2ExtmulHighI32x4S => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64x2_extmul_high_i32x4s(), lhs, rhs))
    }
    I64x2ExtmulLowI32x4U => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64x2_extmul_low_i32x4u(), lhs, rhs))
    }
    I64x2ExtmulHighI32x4U => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i64x2_extmul_high_i32x4u(), lhs, rhs))
    }

    // === SIMD: f32x4 arithmetic ===
    F32x4Add => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f32x4_add(), lhs, rhs))
    }
    F32x4Sub => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f32x4_sub(), lhs, rhs))
    }
    F32x4Mul => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f32x4_mul(), lhs, rhs))
    }
    F32x4Div => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f32x4_div(), lhs, rhs))
    }
    F32x4Min => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f32x4_min(), lhs, rhs))
    }
    F32x4Max => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f32x4_max(), lhs, rhs))
    }
    F32x4Pmin => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f32x4_pmin(), lhs, rhs))
    }
    F32x4Pmax => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f32x4_pmax(), lhs, rhs))
    }

    // === SIMD: f64x2 arithmetic ===
    F64x2Add => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f64x2_add(), lhs, rhs))
    }
    F64x2Sub => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f64x2_sub(), lhs, rhs))
    }
    F64x2Mul => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f64x2_mul(), lhs, rhs))
    }
    F64x2Div => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f64x2_div(), lhs, rhs))
    }
    F64x2Min => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f64x2_min(), lhs, rhs))
    }
    F64x2Max => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f64x2_max(), lhs, rhs))
    }
    F64x2Pmin => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f64x2_pmin(), lhs, rhs))
    }
    F64x2Pmax => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f64x2_pmax(), lhs, rhs))
    }

    // === SIMD: Relaxed binary ===
    F32x4RelaxedMin => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f32x4_relaxed_min(), lhs, rhs))
    }
    F32x4RelaxedMax => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f32x4_relaxed_max(), lhs, rhs))
    }
    F64x2RelaxedMin => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f64x2_relaxed_min(), lhs, rhs))
    }
    F64x2RelaxedMax => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::f64x2_relaxed_max(), lhs, rhs))
    }
    I16x8RelaxedQ15mulrS => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::binary(BinaryOp::i16x8_relaxed_q15mulr_s(), lhs, rhs))
    }
    I16x8RelaxedDotI8x16I7x16S => {
      let rhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let lhs = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::binary(BinaryOp::i16x8_relaxed_dot_i8x16i7x16s(), lhs, rhs),
      )
    }

    // === SIMD: Shift (v128, i32 -> v128) ===
    I8x16Shl => {
      let shift = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::v128_shift(V128ShiftOp::i8x16_shl(), vec, shift))
    }
    I8x16ShrS => {
      let shift = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::v128_shift(V128ShiftOp::i8x16_shr_s(), vec, shift))
    }
    I8x16ShrU => {
      let shift = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::v128_shift(V128ShiftOp::i8x16_shr_u(), vec, shift))
    }
    I16x8Shl => {
      let shift = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::v128_shift(V128ShiftOp::i16x8_shl(), vec, shift))
    }
    I16x8ShrS => {
      let shift = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::v128_shift(V128ShiftOp::i16x8_shr_s(), vec, shift))
    }
    I16x8ShrU => {
      let shift = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::v128_shift(V128ShiftOp::i16x8_shr_u(), vec, shift))
    }
    I32x4Shl => {
      let shift = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::v128_shift(V128ShiftOp::i32x4_shl(), vec, shift))
    }
    I32x4ShrS => {
      let shift = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::v128_shift(V128ShiftOp::i32x4_shr_s(), vec, shift))
    }
    I32x4ShrU => {
      let shift = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::v128_shift(V128ShiftOp::i32x4_shr_u(), vec, shift))
    }
    I64x2Shl => {
      let shift = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::v128_shift(V128ShiftOp::i64x2_shl(), vec, shift))
    }
    I64x2ShrS => {
      let shift = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::v128_shift(V128ShiftOp::i64x2_shr_s(), vec, shift))
    }
    I64x2ShrU => {
      let shift = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let vec = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(TInstr::v128_shift(V128ShiftOp::i64x2_shr_u(), vec, shift))
    }

    // === SIMD: Ternary (v128, v128, v128 -> v128) ===
    V128Bitselect => {
      let c = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let v2 = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let v1 = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::v128_ternary(V128TernaryOp::v128_bitselect(), v1, v2, c),
      )
    }
    I8x16RelaxedLaneselect => {
      let c = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let v2 = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let v1 = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::v128_ternary(
          V128TernaryOp::i8x16_relaxed_laneselect(),
          v1,
          v2,
          c,
        ),
      )
    }
    I16x8RelaxedLaneselect => {
      let c = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let v2 = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let v1 = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::v128_ternary(
          V128TernaryOp::i16x8_relaxed_laneselect(),
          v1,
          v2,
          c,
        ),
      )
    }
    I32x4RelaxedLaneselect => {
      let c = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let v2 = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let v1 = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::v128_ternary(
          V128TernaryOp::i32x4_relaxed_laneselect(),
          v1,
          v2,
          c,
        ),
      )
    }
    I64x2RelaxedLaneselect => {
      let c = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let v2 = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let v1 = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::v128_ternary(
          V128TernaryOp::i64x2_relaxed_laneselect(),
          v1,
          v2,
          c,
        ),
      )
    }
    F32x4RelaxedMadd => {
      let c = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let b = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let a = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::v128_ternary(V128TernaryOp::f32x4_relaxed_madd(), a, b, c),
      )
    }
    F32x4RelaxedNmadd => {
      let c = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let b = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let a = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::v128_ternary(V128TernaryOp::f32x4_relaxed_nmadd(), a, b, c),
      )
    }
    F64x2RelaxedMadd => {
      let c = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let b = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let a = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::v128_ternary(V128TernaryOp::f64x2_relaxed_madd(), a, b, c),
      )
    }
    F64x2RelaxedNmadd => {
      let c = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let b = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let a = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::v128_ternary(V128TernaryOp::f64x2_relaxed_nmadd(), a, b, c),
      )
    }
    I32x4RelaxedDotI8x16I7x16AddS => {
      let c = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let b = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      let a = match pop(stack) {
        Ok(t) => t
        Err(t) => return Err(t)
      }
      stack.push(
        TInstr::v128_ternary(
          V128TernaryOp::i32x4_relaxed_dot_i8x16i7x16_add_s(),
          a,
          b,
          c,
        ),
      )
    }
  }
  Ok(())
}
