///|
pub fn diff(rt1 : RefType, rt2 : RefType) -> Result[RefType, String] {
  let ht1 = rt1.get_heap_type()
  let ht2 = rt2.get_heap_type()
  if ht1 != ht2 {
    return Err("Heap Types differ")
  }
  if rt2.is_nullable() {
    // (ref null? ht) \ (ref null ht) = (ref ht)
    Ok(HeapTypeRefType(false, ht1))
  } else {
    // (ref null? ht) \ (ref ht) = (ref null? ht)
    Ok(HeapTypeRefType(rt1.is_nullable(), ht1))
  }
}

///|
pub trait Validate {
  validate(Self, Env) -> Result[Unit, String]
}

///|
pub trait ValidateMax {
  validate_max(Self, Env, UInt64) -> Result[Unit, String]
}

///|
pub impl Validate for NumType with validate(_, _) {
  Ok(())
}

///|
pub impl Validate for TypeIdx with validate(self, env) {
  if env.resolve_typeidx_subtype(self) is Some(_) {
    Ok(())
  } else {
    Err("No type exists for TypeIdx")
  }
}

///|
pub impl Validate for HeapType with validate(self, env) {
  match self {
    AbsHeapTypeHeapType(abs) => abs.validate(env)
    HeapType(tidx) => tidx.validate(env)
    DefTypeHeapType(dt) => dt.validate(env)
  }
}

///|
pub impl Validate for DefType with validate(self, env) {
  let DefType(rt, _) = self
  let env2 = env_with_rectype(env, rt)
  match self.project() {
    Some(st) => st.validate(env2)
    None => Err("Invalid SubType Index")
  }
}

///|
pub impl Validate for AbsHeapType with validate(_, _) {
  Ok(())
}

///|
pub impl Validate for ValType with validate(self, env) {
  match self {
    RefTypeValType(rt) => rt.validate(env)
    VecTypeValType => Ok(())
    NumTypeValType(nt) => nt.validate(env)
    BotValType => Ok(())
  }
}

///|
pub impl[T : Validate] Validate for Array[T] with validate(self, env) {
  for v in self {
    if v.validate(env) is Err(t) {
      return Err(t)
    }
  }
  Ok(())
}

///|
pub impl Validate for BlockType with validate(self, env) {
  match self {
    ValTypeBlockType(vt) => vt.validate(env)
    EmptyBlockType => Ok(())
    TypeIdxBlockType(tidx) =>
      match env.resolve_typeidx_subtype(tidx) {
        Some(st) =>
          match st.get_comptype() {
            FuncCompType(_, _) => Ok(())
            _ => Err("Expected Func Type for block type")
          }
        None => Err("Invalid TypeIdx for block type")
      }
  }
}

///|
pub impl Validate for FuncType with validate(self, env) {
  let FuncType(t0, t1) = self
  match Validate::validate(t0, env) {
    Ok(_) => Validate::validate(t1, env)
    Err(t) => Err(t)
  }
}

///|
pub impl Validate for CompType with validate(self, env) {
  match self {
    StructCompType(fts) => Validate::validate(fts, env)
    ArrayCompType(ft) => ft.validate(env)
    FuncCompType(v0, v1) =>
      match Validate::validate(v0, env) {
        Ok(_) => Validate::validate(v1, env)
        Err(t) => Err(t)
      }
  }
}

///|
pub impl Validate for RefType with validate(self, env) {
  match self {
    HeapTypeRefType(_, ht) => ht.validate(env)
    AbsHeapTypeRefType(abs) => abs.validate(env)
  }
}

///|
pub impl Validate for FieldType with validate(self, env) {
  let FieldType(st, _) = self
  st.validate(env)
}

///|
pub impl Validate for StorageType with validate(self, env) {
  match self {
    ValTypeStorageType(vt) => vt.validate(env)
    PackTypeStorageType(_) => Ok(())
  }
}

///|
pub impl Validate for RecType with validate(self, env) {
  match self {
    SingleRecType(st) => st.validate(env)
    GroupRecType(sts) => Validate::validate(sts, env)
  }
}

///|
pub impl Validate for SubType with validate(self, env) {
  match self {
    SubType(_, matches, ct) => {
      for m in matches {
        match m.validate(env) {
          Ok(_) if env.resolve_subtype(m) is Some(t) &&
            ct.matches(t.get_comptype(), env) => ()
          Ok(_) => return Err("Invalid subtype")
          Err(t) => return Err(t)
        }
      }
      Ok(())
    }
    CompTypeSubType(ct) => ct.validate(env)
  }
}

///|
pub impl ValidateMax for Limits with validate_max(self, _, k) {
  match self {
    I32Limits(n, m) => {
      let n = n.to_uint64()
      if n <= k &&
        (
          m is None ||
          (m is Some(m) && n <= m.to_uint64() && m.to_uint64() <= k)
        ) {
        Ok(())
      } else {
        Err("Invalid range for limits")
      }
    }
    I64Limits(n, m) =>
      if n <= k && (m is None || (m is Some(m) && n <= m && m <= k)) {
        Ok(())
      } else {
        Err("Invalid range for limits")
      }
  }
}

///|
pub impl Validate for LabelIdx with validate(self, env) {
  let LabelIdx(i) = self
  if i < env.labels.length().reinterpret_as_uint() {
    Ok(())
  } else {
    Err("Invalid LabelIdx")
  }
}

///|
pub impl Validate for TagIdx with validate(self, env) {
  let TagIdx(i) = self
  if i < env.tags.length().reinterpret_as_uint() {
    Ok(())
  } else {
    Err("Invalid TagIdx")
  }
}

///|
pub impl Validate for TagType with validate(self, env) {
  let TagType(tidx) = self
  if tidx.validate(env) is Err(t) {
    return Err(t)
  }
  match env.resolve_comptype(tidx) {
    Some(FuncCompType(params, results)) => {
      if results.length() != 0 {
        return Err("Tag type must have empty result list")
      }
      Validate::validate(params, env)
    }
    _ => Err("TagType not found or not a function type")
  }
}

///|
pub impl Validate for TagSec with validate(self, env) {
  let TagSec(t) = self
  Validate::validate(t, env)
}

///|
pub impl Validate for Catch with validate(self, env) {
  match self {
    Catch(t, l) =>
      match t.validate(env) {
        Ok(_) => l.validate(env)
        Err(t) => Err(t)
      }
    CatchRef(t, l) =>
      match t.validate(env) {
        Ok(_) => l.validate(env)
        Err(t) => Err(t)
      }
    CatchAll(l) => l.validate(env)
    CatchAllRef(l) => l.validate(env)
  }
}

///|
pub impl Validate for GlobalType with validate(self, env) {
  let GlobalType(vt, _) = self
  vt.validate(env)
}

///|
pub impl Validate for MemType with validate(self, env) {
  let MemType(lim) = self
  lim.validate_max(env, 65536)
}

///|
pub impl Validate for TableType with validate(self, env) {
  let TableType(rt, lim) = self
  match rt.validate(env) {
    Ok(_) => lim.validate_max(env, 4294967295)
    Err(t) => Err(t)
  }
}

///|
pub impl Validate for ExternType with validate(self, env) {
  match self {
    TagExternType(tt) => tt.validate(env)
    GlobalExternType(gt) => gt.validate(env)
    MemExternType(mt) => mt.validate(env)
    TableExternType(tt) => tt.validate(env)
    FuncExternType(tidx) =>
      match env.resolve_functype(tidx) {
        Some(_) => Ok(())
        None => Err("Invalid ExternType: Func extern type not found")
      }
  }
}

///|
fn is_const_instr(ins : Instruction) -> Bool {
  match ins {
    I32Const(_) => true
    I64Const(_) => true
    F32Const(_) => true
    F64Const(_) => true
    V128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) => true
    RefNull(_) => true
    RefFunc(_) => true
    GlobalGet(_) => true

    // Optional: enable later if desired/confirmed by spec subset you target
    // RefI31 => true
    _ => false
  }
}

///|
fn validate_const_expr(
  env : Env,
  expr : Expr,
  want : ValType,
) -> Result[Unit, String] {
  let Expr(instrs) = expr

  // syntactic const restriction
  for ins in instrs {
    if !is_const_instr(ins) {
      return Err("initializer expression is not constant")
    }
  }

  // typecheck it under an empty stack/locals/labels context
  // (but with access to env globals, funcs, etc)
  let env_tc = Env::{
    global_types: env.global_types,
    rec_stack: env.rec_stack,
    funcs: env.funcs,
    tables: env.tables,
    mems: env.mems,
    globals: env.globals,
    elems: env.elems,
    datas: env.datas,
    tags: env.tags,
    locals: [],
    labels: [],
    return_type: None,
  }
  let st0 = TcState::{ env: env_tc, stack: [], reachable: true }
  let st1 = match expr.typecheck(st0) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  if !st1.reachable {
    return Err("const expr is unreachable")
  }
  if st1.stack.length() != 1 {
    return Err("const expr must leave exactly one value on the stack")
  }
  let actual = st1.stack[0]
  if actual.matches(want, env_tc) {
    Ok(())
  } else {
    Err("const expr result type mismatch")
  }
}

///|
fn validate_global(env : Env, g : Global) -> Result[GlobalType, String] {
  let Global(gt, init) = g
  if gt.validate(env) is Err(t) {
    return Err(t) // checks vt validity
  }
  let GlobalType(vt, _mut) = gt
  match validate_const_expr(env, init, vt) {
    Ok(_) => Ok(gt)
    Err(t) => Err(t)
  }
}

///|
pub fn validate_globalsec(
  globalsec : GlobalSec?,
  env0 : Env,
) -> Result[Env, String] {
  match globalsec {
    None => Ok(env0)
    Some(GlobalSec(gs)) => {
      let mut env = env0
      let out = env.globals.copy()
      for g in gs {
        // Validate under env that includes *previous* globals only
        let gt = match validate_global(env, g) {
          Ok(gt) => gt
          Err(t) => return Err(t)
        }

        // Extend global index space
        out.push(gt)
        env = Env::{
          global_types: env.global_types,
          rec_stack: env.rec_stack,
          funcs: env.funcs,
          tables: env.tables,
          mems: env.mems,
          globals: out,
          elems: env.elems,
          datas: env.datas,
          tags: env.tags,
          locals: env.locals,
          labels: env.labels,
          return_type: env.return_type,
        }
      }
      Ok(env)
    }
  }
}

///|
pub fn validate_tagsec(tagsec : TagSec?, env0 : Env) -> Result[Env, String] {
  match tagsec {
    None => Ok(env0)
    Some(TagSec(tags)) => {
      let mut env = env0
      let out = env.tags.copy()
      for t in tags {
        // validate tag type under current env
        if t.validate(env) is Err(t) {
          return Err(t)
        }

        // extend tag index space incrementally
        out.push(t)
        env = Env::{
          global_types: env.global_types,
          rec_stack: env.rec_stack,
          funcs: env.funcs,
          tables: env.tables,
          mems: env.mems,
          globals: env.globals,
          elems: env.elems,
          datas: env.datas,
          tags: out,
          locals: env.locals,
          labels: env.labels,
          return_type: env.return_type,
        }
      }
      Ok(env)
    }
  }
}

///|
pub fn validate_memsec(memsec : MemSec?, env0 : Env) -> Result[Env, String] {
  match memsec {
    None => Ok(env0)
    Some(MemSec(ms)) => {
      let mut env = env0
      for mt in ms {
        match mt.validate(env) {
          Ok(_) => ()
          Err(e) => return Err(e)
        }
        env = env.push_mem(mt)
      }
      Ok(env)
    }
  }
}

///|
fn validate_table(env : Env, t : Table) -> Result[TableType, String] {
  let Table(tt, init_opt) = t
  match tt.validate(env) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  let TableType(rt, _lim) = tt
  match init_opt {
    None => Ok(tt)
    Some(init) => {
      // init expr must be const and produce value type rt
      let want = RefTypeValType(rt)
      match validate_const_expr(env, init, want) {
        Ok(_) => Ok(tt)
        Err(e) => Err(e)
      }
    }
  }
}

///|
pub fn validate_tablesec(
  tablesec : TableSec?,
  env0 : Env,
) -> Result[Env, String] {
  match tablesec {
    None => Ok(env0)
    Some(TableSec(ts)) => {
      let mut env = env0
      for t in ts {
        let tt = match validate_table(env, t) {
          Ok(x) => x
          Err(e) => return Err(e)
        }
        env = env.push_table(tt)
      }
      Ok(env)
    }
  }
}

///|
fn expand_locals(decls : Array[Locals]) -> Result[Array[ValType], String] {
  let out : Array[ValType] = []
  for d in decls {
    let Locals(n, vt) = d
    let count = n.reinterpret_as_int()
    if count < 0 {
      return Err("locals: negative count")
    }
    for _ in 0..<count {
      out.push(vt)
    }
  }
  Ok(out)
}

///|
fn validate_locals_decls(
  env : Env,
  decls : Array[Locals],
) -> Result[Unit, String] {
  for d in decls {
    let Locals(n, vt) = d
    if vt.validate(env) is Err(e) {
      return Err(e)
    }
    let count = n.reinterpret_as_int()
    if count < 0 {
      return Err("locals: negative count")
    }
    if !has_default(vt) {
      return Err("locals: type has no default value")
    }
  }
  Ok(())
}

///|
fn validate_func_body_against_functype(
  env : Env,
  ft : FuncType,
  f : Func,
) -> Result[Unit, String] {
  let FuncType(params, results) = ft
  let Func(local_decls, body) = f

  // locals declarations valid
  if validate_locals_decls(env, local_decls) is Err(e) {
    return Err(e)
  }

  // locals vector = params ++ expanded locals
  let locals_extra = match expand_locals(local_decls) {
    Ok(xs) => xs
    Err(e) => return Err(e)
  }
  let all_locals = params.copy()
  for vt in locals_extra {
    all_locals.push(vt)
  }

  // extend context:
  // - locals
  // - labels appended by results (function label)
  // - return appended by results
  let env1 = env
    .with_locals(all_locals)
    .with_labels(
      {
        let ls = env.labels.copy()
        ls.push(results)
        ls
      },
    )
    .with_return_type(Some(results))
  let st0 = TcState::{ env: env1, stack: [], reachable: true }
  let st1 = match body.typecheck(st0) {
    Ok(s) => s
    Err(e) => return Err(e)
  }

  // enforce results at end if reachable
  if st1.reachable {
    let st2 = match st1.pop_types(results) {
      Ok(s) => s
      Err(e) => return Err(e)
    }
    if st2.stack.length() != 0 {
      return Err("function body leaves extra values on stack")
    }
  }
  Ok(())
}

///|
pub fn validate_codesec(
  codesec : CodeSec?,
  funcsec : FuncSec?,
  env : Env,
) -> Result[Unit, String] {
  match (codesec, funcsec) {
    (None, None) => Ok(())
    (Some(CodeSec(_)), None) => Err("codesec present without funcsec")
    (None, Some(FuncSec(ts))) =>
      if ts.length() == 0 {
        Ok(())
      } else {
        Err("funcsec present without codesec")
      }
    (Some(CodeSec(bodies)), Some(FuncSec(type_idxs))) => {
      if bodies.length() != type_idxs.length() {
        return Err("codesec length does not match funcsec length")
      }
      let n_defined = bodies.length()
      let n_total = env.funcs.length()
      let n_imported = n_total - n_defined
      if n_imported < 0 {
        return Err("internal: negative imported func count")
      }
      for i in 0..<bodies.length() {
        let ft = match env.funcs.get(n_imported + i) {
          Some(x) => x
          None => return Err("internal: missing functype for code body")
        }
        if validate_func_body_against_functype(env, ft, bodies[i]) is Err(e) {
          return Err(e)
        }
      }
      Ok(())
    }
  }
}

///|
pub fn validate_funcsec(funcsec : FuncSec?, env0 : Env) -> Result[Env, String] {
  match funcsec {
    None => Ok(env0)
    Some(FuncSec(type_idxs)) => {
      let mut env = env0
      for tidx in type_idxs {
        // Each TypeIdx must resolve to a function type
        let ft = match env.resolve_functype(tidx) {
          Some(x) => x
          None => return Err("funcsec: typeidx does not resolve to functype")
        }
        env = env.push_func(ft)
      }
      Ok(env)
    }
  }
}

///|
pub impl Validate for DataMode with validate(self, env) {
  match self {
    Passive => Ok(())
    Active(memidx, offset_expr) => {
      // memory must exist
      let MemType(lim) = match env.get_memtype(memidx) {
        None => return Err("data.active: invalid memory index")
        Some(mt) => mt
      }

      // address type at depends on limits (i32 or i64)
      let at = lim.addr_valtype()

      // expr : at const
      validate_const_expr(env, offset_expr, at)
    }
  }
}

///|
pub impl Validate for Data with validate(self, env) {
  let Data(mode, _) = self
  mode.validate(env)
}

///|
pub fn validate_datasec(datasec : DataSec?, env0 : Env) -> Result[Env, String] {
  match datasec {
    None => Ok(env0)
    Some(DataSec(ds)) => {
      let mut env = env0
      for d in ds {
        // validate under env that includes previous data segments
        if d.validate(env) is Err(e) {
          return Err(e)
        }
        env = env.push_data(d)
      }
      Ok(env)
    }
  }
}

///|
fn validate_elem_mode(
  env : Env,
  mode : ElemMode,
  rt : RefType,
) -> Result[Unit, String] {
  match mode {
    Passive => Ok(())
    Declarative => Ok(())
    Active(tidx, offset_expr) => {
      // table must exist
      let TableType(rt_table, lim) = match env.get_table_type(tidx) {
        None => return Err("elem.active: invalid table index")
        Some(tt) => tt
      }

      // require rt ≤ rt_table
      // If your Match::matches works on RefType, use that.
      // Otherwise use ValType wrapper.
      let ok = Match::matches(RefTypeValType(rt), RefTypeValType(rt_table), env)
      if !ok {
        return Err("elem.active: elem type does not match table element type")
      }

      // offset expr : at const
      let at = lim.addr_valtype()
      validate_const_expr(env, offset_expr, at)
    }
  }
}

///|
pub impl Validate for ElemKind with validate(self, env) {
  match self {
    // elemtype is funcref; initializers are function indices
    FuncsElemKind(fs) => {
      for f in fs {
        if !env.has_func(f) {
          return Err("elem.funcs: invalid function index")
        }
      }
      Ok(())
    }

    // legacy element expressions: elemtype is funcref; each expr must be const funcref
    FuncExprsElemKind(exprs) => {
      let want = funcref_valtype()
      for e in exprs {
        if validate_const_expr(env, e, want) is Err(t) {
          return Err(t)
        }
      }
      Ok(())
    }

    // typed element expressions: elemtype is provided; each expr must be const of that type
    TypedExprsElemKind(rt, exprs) => {
      if rt.validate(env) is Err(t) {
        return Err(t)
      }
      let want = RefTypeValType(rt)
      for e in exprs {
        if validate_const_expr(env, e, want) is Err(t) {
          return Err(t)
        }
      }
      Ok(())
    }
  }
}

///|
pub impl Validate for Elem with validate(self, env) {
  let Elem(mode, kind) = self

  // kind validity (incl. elemtype and init exprs)
  if kind.validate(env) is Err(t) {
    return Err(t)
  }

  // derive elemtype from kind and validate it
  let rt = elem_reftype(self)
  if rt.validate(env) is Err(t) {
    return Err(t)
  }

  // mode validity depends on elemtype
  validate_elem_mode(env, mode, rt)
}

///|
pub fn validate_elemsec(elemsec : ElemSec?, env0 : Env) -> Result[Env, String] {
  match elemsec {
    None => Ok(env0)
    Some(ElemSec(es)) => {
      let mut env = env0
      for e in es {
        if e.validate(env) is Err(t) {
          return Err(t)
        }
        let elems = env.elems.copy()
        elems.push(e)
        env = Env::{
          global_types: env.global_types,
          rec_stack: env.rec_stack,
          funcs: env.funcs,
          tables: env.tables,
          mems: env.mems,
          globals: env.globals,
          elems,
          datas: env.datas,
          tags: env.tags,
          locals: env.locals,
          labels: env.labels,
          return_type: env.return_type,
        }
      }
      Ok(env)
    }
  }
}

///|
pub impl Validate for Import with validate(self, env) {
  let Import(_, _, xt) = self
  xt.validate(env)
}

///|
pub fn validate_importsec(
  importsec : ImportSec?,
  env0 : Env,
) -> Result[Env, String] {
  match importsec {
    None => Ok(env0)
    Some(ImportSec(imps)) => {
      let mut env = env0
      for imp in imps {
        if imp.validate(env) is Err(e) {
          return Err(e)
        }
        let Import(_, _, et) = imp
        match et {
          FuncExternType(tidx) => {
            let ft = match env.resolve_functype(tidx) {
              Some(x) => x
              None => return Err("import func: type index is not a functype")
            }
            env = env.push_func(ft)
          }
          TableExternType(tt) => env = env.push_table(tt)
          MemExternType(mt) => env = env.push_mem(mt)
          GlobalExternType(gt) => env = env.push_global(gt)
          TagExternType(tt) => env = env.push_tag(tt)
        }
      }
      Ok(env)
    }
  }
}

///|
pub fn validate_startsec(
  startsec : StartSec?,
  env : Env,
) -> Result[Unit, String] {
  match startsec {
    None => Ok(())
    Some(StartSec(fidx)) => {
      let FuncType(params, results) = match env.get_functype_by_funcidx(fidx) {
        None => return Err("start: invalid function index")
        Some(ft) => ft
      }
      if params.length() != 0 {
        return Err("start function must have empty parameter list")
      }
      if results.length() != 0 {
        return Err("start function must have empty result list")
      }
      Ok(())
    }
  }
}

///|
pub impl Validate for FuncIdx with validate(self, env) {
  if env.has_func(self) {
    Ok(())
  } else {
    Err("invalid func index")
  }
}

///|
pub impl Validate for TableIdx with validate(self, env) {
  match env.get_table_type(self) {
    Some(_) => Ok(())
    None => Err("invalid table index")
  }
}

///|
pub impl Validate for MemIdx with validate(self, env) {
  let MemIdx(i) = self
  match env.get_memtype(i) {
    Some(_) => Ok(())
    None => Err("invalid mem index")
  }
}

///|
pub impl Validate for GlobalIdx with validate(self, env) {
  let GlobalIdx(i) = self
  match env.get_global_type(i) {
    Some(_) => Ok(())
    None => Err("invalid global index")
  }
}

///|
pub impl Validate for ExternIdx with validate(self, env) {
  match self {
    FuncExternIdx(i) => i.validate(env)
    TableExternIdx(i) => i.validate(env)
    MemExternIdx(i) => i.validate(env)
    GlobalExternIdx(i) => i.validate(env)
    TagExternIdx(i) => i.validate(env)
  }
}

///|
pub impl Validate for Export with validate(self, env) {
  let Export(_, exi) = self
  exi.validate(env)
}

///|
pub fn validate_exportsec(
  exportsec : ExportSec?,
  env : Env,
) -> Result[Unit, String] {
  match exportsec {
    None => Ok(())
    Some(ExportSec(es)) => Validate::validate(es, env)
  }
}

///|
/// Validates the type section incrementally and extends env.global_types.
pub fn validate_typesec(typesec : TypeSec?, env0 : Env) -> Result[Env, String] {
  match typesec {
    None => Ok(env0)
    Some(TypeSec(rts)) => {
      let mut env = env0
      for rt in rts {
        env = match validate_rectype_and_extend(env, rt) {
          Ok(e) => e
          Err(t) => return Err(t)
        }
      }
      Ok(env)
    }
  }
}

///|
fn validate_rectype_and_extend(env : Env, rt : RecType) -> Result[Env, String] {
  // Validate rectype under recursive context (for RecIdx references)
  let env_rec = env_with_rectype(env, rt)

  // Validate rectype itself under env_rec
  if rt.validate(env_rec) is Err(e) {
    return Err(e)
  }

  // If ok, append its defined subtypes to env.global_types
  Ok(env.append_rectype_types(rt))
}

///|
pub fn validate_datacnt(
  datacnt_opt : DataCntSec?,
  datasec_opt : DataSec?,
) -> Result[Unit, String] {
  match datacnt_opt {
    None => Ok(())
    Some(DataCntSec(U32(n))) => {
      let actual : UInt = match datasec_opt {
        None => return Err("datacount section present but no data section")
        Some(DataSec(ds)) => ds.length().reinterpret_as_uint()
      }
      if n == actual {
        Ok(())
      } else {
        Err("datacount does not match number of data segments")
      }
    }
  }
}

///|
/// Validates exports including name uniqueness requirement.
fn validate_exportsec_unique(
  exportsec : ExportSec?,
  env : Env,
) -> Result[Unit, String] {
  match exportsec {
    None => Ok(())
    Some(ExportSec(es)) => {
      // First validate all exports
      if Validate::validate(es, env) is Err(t) {
        return Err(t)
      }
      // Check for duplicate export names
      let names : Array[Name] = []
      for e in es {
        let Export(name, _) = e
        for existing in names {
          if existing == name {
            return Err("duplicate export name: " + name.0.to_string())
          }
        }
        names.push(name)
      }
      Ok(())
    }
  }
}

///|
/// Validates a whole module from an empty context, building its Env incrementally.
pub fn validate_module(m : Module) -> Result[Unit, String] {
  let Module(
    _customs,
    typesec_opt,
    importsec_opt,
    funcsec_opt,
    tablesec_opt,
    memsec_opt,
    tagsec_opt,
    globalsec_opt,
    exportsec_opt,
    startsec_opt,
    elemsec_opt,
    datacntsec_opt,
    codesec_opt,
    datasec_opt,
  ) = m

  // Start from empty env (module validation does not take an external env)
  let mut env = empty_env()

  // (1) Types: defines global type index space
  env = match validate_typesec(typesec_opt, env) {
    Ok(e) => e
    Err(t) => return Err(t)
  }

  // (2) Imports: extend funcs/tables/mems/globals/tags index spaces
  env = match validate_importsec(importsec_opt, env) {
    Ok(e) => e
    Err(t) => return Err(t)
  }

  // (3) Function declarations (defined funcs): extend env.funcs
  env = match validate_funcsec(funcsec_opt, env) {
    Ok(e) => e
    Err(t) => return Err(t)
  }

  // (4) Tables / Memories / Tags / Globals: extend their index spaces
  env = match validate_tablesec(tablesec_opt, env) {
    Ok(e) => e
    Err(t) => return Err(t)
  }
  env = match validate_memsec(memsec_opt, env) {
    Ok(e) => e
    Err(t) => return Err(t)
  }
  env = match validate_tagsec(tagsec_opt, env) {
    Ok(e) => e
    Err(t) => return Err(t)
  }
  env = match validate_globalsec(globalsec_opt, env) {
    Ok(e) => e
    Err(t) => return Err(t)
  }

  // (5) Elements / Data: extend elems/datas (needed by instructions)
  env = match validate_elemsec(elemsec_opt, env) {
    Ok(e) => e
    Err(t) => return Err(t)
  }
  env = match validate_datasec(datasec_opt, env) {
    Ok(e) => e
    Err(t) => return Err(t)
  }

  // (6) DataCount section cross-check
  match validate_datacnt(datacntsec_opt, datasec_opt) {
    Ok(_) => ()
    Err(t) => return Err(t)
  }

  // (7) Start function validation
  match validate_startsec(startsec_opt, env) {
    Ok(_) => ()
    Err(t) => return Err(t)
  }

  // (8) Exports: validate indices and check name uniqueness
  match validate_exportsec_unique(exportsec_opt, env) {
    Ok(_) => ()
    Err(t) => return Err(t)
  }

  // (9) Code: typecheck each function body against env.funcs
  match validate_codesec(codesec_opt, funcsec_opt, env) {
    Ok(_) => ()
    Err(t) => return Err(t)
  }

  Ok(())
}

test "Fuzz Modules" {
  let rnd = @quickcheck/splitmix.new()
  loop 100000 {
    0 => break ()
    n => {
      let ctx = gen_ctx_new(1000, rnd = Some(rnd))
      let mod = gen_module_valid_full(ctx)

      if mod is Err(t) {
        assert_true(false, msg=t)
      }
      let (_, mod) = mod.unwrap()
      let result = validate_module(mod)

      if result is Err(t) {
        assert_true(false, msg=t)
      }
      
      continue n - 1
    }
  }
}
