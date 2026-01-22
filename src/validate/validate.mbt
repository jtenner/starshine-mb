///|
pub fn diff(rt1 : RefType, rt2 : RefType) -> Result[RefType, String] {
  let ht1 = rt1.get_heap_type()
  let n1 = rt1.is_nullable()
  let n2 = rt2.is_nullable()

  // Result nullability: nullable only if rt1 was nullable AND rt2 was not
  let null_out = n1 && not(n2)
  Ok(RefType::new(null_out, ht1))
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
    AbsHeapTypeHeapType(abs) => Validate::validate(abs, env)
    HeapType(tidx) => Validate::validate(tidx, env)
    DefTypeHeapType(dt) => Validate::validate(dt, env)
  }
}

///|
pub impl Validate for DefType with validate(self, env) {
  let DefType(rt, _) = self
  let env2 = env_with_rectype(env, rt)
  match self.project() {
    Some(st) => Validate::validate(st, env2)
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
    RefTypeValType(rt) => Validate::validate(rt, env)
    VecTypeValType => Ok(())
    NumTypeValType(nt) => Validate::validate(nt, env)
    BotValType => Ok(())
  }
}

///|
pub impl[T : Validate] Validate for Array[T] with validate(self, env) {
  for v in self {
    if Validate::validate(v, env) is Err(t) {
      return Err(t)
    }
  }
  Ok(())
}

///|
pub impl Validate for BlockType with validate(self, env) {
  match self {
    ValTypeBlockType(vt) => Validate::validate(vt, env)
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
    ArrayCompType(ft) => Validate::validate(ft, env)
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
    HeapTypeRefType(_, ht) => Validate::validate(ht, env)
    AbsHeapTypeRefType(abs) => Validate::validate(abs, env)
  }
}

///|
pub impl Validate for FieldType with validate(self, env) {
  let FieldType(st, _) = self
  Validate::validate(st, env)
}

///|
pub impl Validate for StorageType with validate(self, env) {
  match self {
    ValTypeStorageType(vt) => Validate::validate(vt, env)
    PackTypeStorageType(_) => Ok(())
  }
}

///|
pub impl Validate for RecType with validate(self, env) {
  match self {
    SingleRecType(st) => Validate::validate(st, env)
    GroupRecType(sts) => Validate::validate(sts, env)
  }
}

///|
pub impl Validate for SubType with validate(self, env) {
  match self {
    SubType(_, matches, ct) => {
      for m in matches {
        match Validate::validate(m, env) {
          Ok(_) if env.resolve_subtype(m) is Some(t) &&
            Match::matches(ct, t.get_comptype(), env) => ()
          Ok(_) => return Err("Invalid subtype")
          Err(t) => return Err(t)
        }
      }
      Ok(())
    }
    CompTypeSubType(ct) => Validate::validate(ct, env)
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
  if Validate::validate(tidx, env) is Err(t) {
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
      match Validate::validate(t, env) {
        Ok(_) => Validate::validate(l, env)
        Err(t) => Err(t)
      }
    CatchRef(t, l) =>
      match Validate::validate(t, env) {
        Ok(_) => Validate::validate(l, env)
        Err(t) => Err(t)
      }
    CatchAll(l) => Validate::validate(l, env)
    CatchAllRef(l) => Validate::validate(l, env)
  }
}

///|
pub impl Validate for GlobalType with validate(self, env) {
  let GlobalType(vt, _) = self
  Validate::validate(vt, env)
}

///|
pub impl Validate for MemType with validate(self, env) {
  let MemType(lim) = self
  ValidateMax::validate_max(lim, env, 65536)
}

///|
pub impl Validate for TableType with validate(self, env) {
  let TableType(rt, lim) = self
  match Validate::validate(rt, env) {
    Ok(_) => ValidateMax::validate_max(lim, env, 4294967295)
    Err(t) => Err(t)
  }
}

///|
pub impl Validate for ExternType with validate(self, env) {
  match self {
    TagExternType(tt) => Validate::validate(tt, env)
    GlobalExternType(gt) => Validate::validate(gt, env)
    MemExternType(mt) => Validate::validate(mt, env)
    TableExternType(tt) => Validate::validate(tt, env)
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
  let env_tc = Env::{ ..env, locals: [], labels: [], return_type: None }
  let st0 = TcState::{ env: env_tc, stack: [], reachable: true }
  let st1 = match Typecheck::typecheck(expr, st0) {
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
  if Match::matches(actual, want, env_tc) {
    Ok(())
  } else {
    Err("const expr result type mismatch")
  }
}

///|
fn validate_global(env : Env, g : Global) -> Result[GlobalType, String] {
  let Global(gt, init) = g
  if Validate::validate(gt, env) is Err(t) {
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
        env = env.with_globals(out)
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
        if Validate::validate(t, env) is Err(t) {
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
        match Validate::validate(mt, env) {
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
  match Validate::validate(tt, env) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  let TableType(rt, _lim) = tt
  match init_opt {
    None => Ok(tt)
    Some(init) => {
      // init expr must be const and produce value type rt
      let want = ValType::ref_type(rt)
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
fn validate_locals_decls(
  env : Env,
  decls : Array[Locals],
) -> Result[Unit, String] {
  for d in decls {
    let Locals(n, vt) = d
    if Validate::validate(vt, env) is Err(e) {
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
  match f {
    Func(local_decls, body) => {
      // Validate local declarations
      if validate_locals_decls(env, local_decls) is Err(e) {
        return Err(e)
      }

      // Expand locals vector = params ++ expanded locals
      let locals_extra = match expand_locals(local_decls) {
        Ok(xs) => xs
        Err(e) => return Err(e)
      }
      let all_locals = params.copy()
      for vt in locals_extra {
        all_locals.push(vt)
      }

      // Extend context:
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
      let st1 = match Typecheck::typecheck(body, st0) {
        Ok(s) => s
        Err(e) => return Err(e)
      }

      // Enforce results at end if reachable
      if st1.reachable {
        if st1.stack.length() != results.length() {
          return Err("function body leaves extra values on stack")
        }
        // Check types match
        for i in 0..<results.length() {
          if !Match::matches(st1.stack[i], results[i], env1) {
            return Err("function body result type mismatch")
          }
        }
      }
      Ok(())
    }
    TFunc(local_vals, texpr) => {
      // TFunc(Array[ValType], TExpr) - local_vals contains the full local signature (params + extra locals)
      // Wait, does it contain params?
      // Given FuncType has params, and TFunc is the definition.
      // If TFunc matches the structure of Func (replacing Array[Locals] with Array[ValType]),
      // then local_vals are the EXTRA locals.
      // But TFunc is usually "fully typed". Let's assume local_vals = extra_locals flattened.

      let all_locals = params.copy()
      for vt in local_vals {
        all_locals.push(vt)
      }
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
      let st1 = match Typecheck::typecheck(texpr, st0) {
        Ok(s) => s
        Err(e) => return Err(e)
      }
      if st1.reachable {
        if st1.stack.length() != results.length() {
          return Err("typed function body leaves extra values on stack")
        }
        for i in 0..<results.length() {
          if !Match::matches(st1.stack[i], results[i], env1) {
            return Err("typed function body result type mismatch")
          }
        }
      }
      Ok(())
    }
  }
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
  Validate::validate(mode, env)
}

///|
pub fn validate_datasec(datasec : DataSec?, env0 : Env) -> Result[Env, String] {
  match datasec {
    None => Ok(env0)
    Some(DataSec(ds)) => {
      let mut env = env0
      for d in ds {
        // validate under env that includes previous data segments
        if Validate::validate(d, env) is Err(e) {
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
      let ok = Match::matches(
        ValType::ref_type(rt),
        ValType::ref_type(rt_table),
        env,
      )
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
      let want = ValType::funcref()
      for e in exprs {
        if validate_const_expr(env, e, want) is Err(t) {
          return Err(t)
        }
      }
      Ok(())
    }

    // typed element expressions: elemtype is provided; each expr must be const of that type
    TypedExprsElemKind(rt, exprs) => {
      if Validate::validate(rt, env) is Err(t) {
        return Err(t)
      }
      let want = ValType::ref_type(rt)
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
  if Validate::validate(kind, env) is Err(t) {
    return Err(t)
  }

  // derive elemtype from kind and validate it
  let rt = Elem::reftype(self)
  if Validate::validate(rt, env) is Err(t) {
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
        if Validate::validate(e, env) is Err(t) {
          return Err(t)
        }
        let elems = env.elems.copy()
        elems.push(e)
        env = env.with_elems(elems)
      }
      Ok(env)
    }
  }
}

///|
pub impl Validate for Import with validate(self, env) {
  let Import(_, _, xt) = self
  Validate::validate(xt, env)
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
        if Validate::validate(imp, env) is Err(e) {
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
  match env.get_memtype(MemIdx::new(i)) {
    Some(_) => Ok(())
    None => Err("invalid mem index")
  }
}

///|
pub impl Validate for GlobalIdx with validate(self, env) {
  let GlobalIdx(i) = self
  match env.get_global_type(GlobalIdx::new(i)) {
    Some(_) => Ok(())
    None => Err("invalid global index")
  }
}

///|
pub impl Validate for ExternIdx with validate(self, env) {
  match self {
    FuncExternIdx(i) => Validate::validate(i, env)
    TableExternIdx(i) => Validate::validate(i, env)
    MemExternIdx(i) => Validate::validate(i, env)
    GlobalExternIdx(i) => Validate::validate(i, env)
    TagExternIdx(i) => Validate::validate(i, env)
  }
}

///|
pub impl Validate for Export with validate(self, env) {
  let Export(_, exi) = self
  Validate::validate(exi, env)
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
  if Validate::validate(rt, env_rec) is Err(e) {
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
  let {
    type_sec: typesec_opt,
    import_sec: importsec_opt,
    func_sec: funcsec_opt,
    table_sec: tablesec_opt,
    mem_sec: memsec_opt,
    tag_sec: tagsec_opt,
    global_sec: globalsec_opt,
    export_sec: exportsec_opt,
    start_sec: startsec_opt,
    elem_sec: elemsec_opt,
    data_cnt_sec: datacntsec_opt,
    code_sec: codesec_opt,
    data_sec: datasec_opt,
    ..,
  } = m

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

///|

test "Fuzz Modules" {
  let rnd = @quickcheck/splitmix.new()
  loop 100000 {
    0 => break ()
    n => {
      let mod = gen_valid_module(rnd)
      let result = validate_module(mod)
      
      if result is Err(t) {
        assert_true(false, msg=t)
      }
      continue n - 1
    }
  }
}

// ============ NumType Tests ============

///|
test "NumType validates successfully" {
  let env = empty_env()
  assert_eq(Validate::validate(NumType::f32(), env), Ok(()))
  assert_eq(Validate::validate(NumType::f64(), env), Ok(()))
  assert_eq(Validate::validate(NumType::i32(), env), Ok(()))
  assert_eq(Validate::validate(NumType::i64(), env), Ok(()))
}

// ============ AbsHeapType Tests ============

///|
test "AbsHeapType validates successfully" {
  let env = empty_env()
  assert_eq(Validate::validate(AbsHeapType::exn(), env), Ok(()))
  assert_eq(Validate::validate(AbsHeapType::array(), env), Ok(()))
  assert_eq(Validate::validate(AbsHeapType::struct_(), env), Ok(()))
  assert_eq(Validate::validate(AbsHeapType::i31(), env), Ok(()))
  assert_eq(Validate::validate(AbsHeapType::eq(), env), Ok(()))
  assert_eq(Validate::validate(AbsHeapType::any(), env), Ok(()))
  assert_eq(Validate::validate(AbsHeapType::extern_(), env), Ok(()))
  assert_eq(Validate::validate(AbsHeapType::func(), env), Ok(()))
  assert_eq(Validate::validate(AbsHeapType::none(), env), Ok(()))
  assert_eq(Validate::validate(AbsHeapType::no_extern(), env), Ok(()))
  assert_eq(Validate::validate(AbsHeapType::no_func(), env), Ok(()))
  assert_eq(Validate::validate(AbsHeapType::no_exn(), env), Ok(()))
}

// ============ HeapType Tests ============

///|
test "HeapType with AbsHeapType validates" {
  let env = empty_env()
  let ht = HeapType::abs(AbsHeapType::func())
  assert_eq(Validate::validate(ht, env), Ok(()))
}

///|
test "HeapType with invalid TypeIdx fails" {
  let env = empty_env()
  let ht = HeapType::new(TypeIdx::new(0))
  assert_eq(Validate::validate(ht, env), Err("No type exists for TypeIdx"))
}

///|
test "HeapType with valid TypeIdx succeeds" {
  let st = SubType::comp_type(CompType::func([], []))
  let env = empty_env().with_types([st])
  let ht = HeapType::new(TypeIdx::new(0))
  assert_eq(Validate::validate(ht, env), Ok(()))
}

// ============ ValType Tests ============

///|
test "ValType NumType validates" {
  let env = empty_env()
  let vt = ValType::i32()
  assert_eq(Validate::validate(vt, env), Ok(()))
}

///|
test "ValType VecType validates" {
  let env = empty_env()
  let t = ValType::v128()
  assert_eq(Validate::validate(t, env), Ok(()))
}

///|
test "ValType BotType validates" {
  let env = empty_env()
  let t = ValType::bottom()
  assert_eq(Validate::validate(t, env), Ok(()))
}

///|
test "ValType RefType with AbsHeapType validates" {
  let env = empty_env()
  let rt = RefType::abs(AbsHeapType::func())
  let vt = ValType::ref_type(rt)
  assert_eq(Validate::validate(vt, env), Ok(()))
}

// ============ RefType Tests ============

///|
test "RefType HeapTypeRefType with valid AbsHeapType validates" {
  let env = empty_env()
  let rt = RefType::new(true, HeapType::abs(AbsHeapType::any()))
  assert_eq(Validate::validate(rt, env), Ok(()))
}

///|
test "RefType HeapTypeRefType nullable and non-nullable validate" {
  let env = empty_env()
  let rt_null = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let rt_non_null = RefType::new(false, HeapType::abs(AbsHeapType::func()))
  assert_eq(Validate::validate(rt_null, env), Ok(()))
  assert_eq(Validate::validate(rt_non_null, env), Ok(()))
}

// ============ TypeIdx Tests ============

///|
test "TypeIdx validates when type exists" {
  let st = SubType::comp_type(CompType::func([], []))
  let env = empty_env().with_types([st])
  let tidx = TypeIdx::new(0)
  assert_eq(Validate::validate(tidx, env), Ok(()))
}

///|
test "TypeIdx fails when type does not exist" {
  let env = empty_env()
  let tidx = TypeIdx::new(0)
  assert_eq(Validate::validate(tidx, env), Err("No type exists for TypeIdx"))
}

///|
test "TypeIdx fails with out of bounds index" {
  let st = SubType::comp_type(CompType::func([], []))
  let env = empty_env().with_types([st])
  let tidx = TypeIdx::new(5)
  assert_eq(Validate::validate(tidx, env), Err("No type exists for TypeIdx"))
}

// ============ LabelIdx Tests ============

///|
test "LabelIdx validates when label exists" {
  let env = empty_env().with_labels([[]])
  let lidx = LabelIdx::new(0)
  assert_eq(Validate::validate(lidx, env), Ok(()))
}

///|
test "LabelIdx fails when label does not exist" {
  let env = empty_env()
  let lidx = LabelIdx::new(0)
  assert_eq(Validate::validate(lidx, env), Err("Invalid LabelIdx"))
}

///|
test "LabelIdx fails with out of bounds index" {
  let env = empty_env().with_labels([[]])
  let lidx = LabelIdx::new(5)
  assert_eq(Validate::validate(lidx, env), Err("Invalid LabelIdx"))
}

// ============ TagIdx Tests ============

///|
test "TagIdx validates when tag exists" {
  let st = SubType::comp_type(CompType::func([], []))
  let env = empty_env()
    .with_types([st])
    .with_tags([TagType::new(TypeIdx::new(0))])
  let tidx = TagIdx::new(0)
  assert_eq(Validate::validate(tidx, env), Ok(()))
}

///|
test "TagIdx fails when tag does not exist" {
  let env = empty_env()
  let tidx = TagIdx::new(0)
  assert_eq(Validate::validate(tidx, env), Err("Invalid TagIdx"))
}

// ============ FuncIdx Tests ============

///|
test "FuncIdx validates when func exists" {
  let env = empty_env().with_funcs([FuncType::new([], [])])
  let fidx = FuncIdx::new(0)
  assert_eq(Validate::validate(fidx, env), Ok(()))
}

///|
test "FuncIdx fails when func does not exist" {
  let env = empty_env()
  let fidx = FuncIdx::new(0)
  assert_eq(Validate::validate(fidx, env), Err("invalid func index"))
}

// ============ TableIdx Tests ============

///|
test "TableIdx validates when table exists" {
  let rt = RefType::abs(AbsHeapType::func())
  let tt = TableType::new(rt, Limits::i32(0, None))
  let env = empty_env().with_tables([tt])
  let tidx = TableIdx::new(0)
  assert_eq(Validate::validate(tidx, env), Ok(()))
}

///|
test "TableIdx fails when table does not exist" {
  let env = empty_env()
  let tidx = TableIdx::new(0)
  assert_eq(Validate::validate(tidx, env), Err("invalid table index"))
}

// ============ MemIdx Tests ============

///|
test "MemIdx validates when memory exists" {
  let mt = MemType::new(Limits::i32(0, None))
  let env = empty_env().with_mems([mt])
  let midx = MemIdx::new(0)
  assert_eq(Validate::validate(midx, env), Ok(()))
}

///|
test "MemIdx fails when memory does not exist" {
  let env = empty_env()
  let midx = MemIdx::new(0)
  assert_eq(Validate::validate(midx, env), Err("invalid mem index"))
}

// ============ GlobalIdx Tests ============

///|
test "GlobalIdx validates when global exists" {
  let gt = GlobalType::new(ValType::i32(), false)
  let env = empty_env().with_globals([gt])
  let gidx = GlobalIdx::new(0)
  assert_eq(Validate::validate(gidx, env), Ok(()))
}

///|
test "GlobalIdx fails when global does not exist" {
  let env = empty_env()
  let gidx = GlobalIdx::new(0)
  assert_eq(Validate::validate(gidx, env), Err("invalid global index"))
}

// ============ Limits Tests (ValidateMax) ============

///|
test "I32Limits validates within max" {
  let env = empty_env()
  let lim = Limits::i32(10, Some(100))
  assert_eq(ValidateMax::validate_max(lim, env, 1000), Ok(()))
}

///|
test "I32Limits validates with no upper bound" {
  let env = empty_env()
  let lim = Limits::i32(10, None)
  assert_eq(ValidateMax::validate_max(lim, env, 1000), Ok(()))
}

///|
test "I32Limits fails when n exceeds k" {
  let env = empty_env()
  let lim = Limits::i32(2000, None)
  assert_eq(
    ValidateMax::validate_max(lim, env, 1000),
    Err("Invalid range for limits"),
  )
}

///|
test "I32Limits fails when m exceeds k" {
  let env = empty_env()
  let lim = Limits::i32(10, Some(2000))
  assert_eq(
    ValidateMax::validate_max(lim, env, 1000),
    Err("Invalid range for limits"),
  )
}

///|
test "I32Limits fails when n exceeds m" {
  let env = empty_env()
  let lim = Limits::i32(100, Some(10))
  assert_eq(
    ValidateMax::validate_max(lim, env, 1000),
    Err("Invalid range for limits"),
  )
}

///|
test "I64Limits validates within max" {
  let env = empty_env()
  let lim = Limits::i64(10, Some(100))
  assert_eq(ValidateMax::validate_max(lim, env, 1000), Ok(()))
}

// ============ MemType Tests ============

///|
test "MemType validates with valid limits" {
  let env = empty_env()
  let mt = MemType::new(Limits::i32(0, Some(100)))
  assert_eq(Validate::validate(mt, env), Ok(()))
}

///|
test "MemType fails when limits exceed 65536" {
  let env = empty_env()
  let mt = MemType::new(Limits::i32(0, Some(100000)))
  assert_eq(Validate::validate(mt, env), Err("Invalid range for limits"))
}

// ============ TableType Tests ============

///|
test "TableType validates with valid ref type and limits" {
  let env = empty_env()
  let rt = RefType::abs(AbsHeapType::func())
  let tt = TableType::new(rt, Limits::i32(0, Some(100)))
  assert_eq(Validate::validate(tt, env), Ok(()))
}

// ============ GlobalType Tests ============

///|
test "GlobalType validates with NumType" {
  let env = empty_env()
  let gt = GlobalType::new(ValType::i32(), false)
  assert_eq(Validate::validate(gt, env), Ok(()))
}

///|
test "GlobalType validates mutable" {
  let env = empty_env()
  let gt = GlobalType::new(ValType::i64(), true)
  assert_eq(Validate::validate(gt, env), Ok(()))
}

// ============ StorageType Tests ============

///|
test "StorageType ValType validates" {
  let env = empty_env()
  let st = StorageType::val_type(ValType::i32())
  assert_eq(Validate::validate(st, env), Ok(()))
}

///|
test "StorageType PackType validates" {
  let env = empty_env()
  let st = StorageType::pack_type(PackType::i8())
  assert_eq(Validate::validate(st, env), Ok(()))
}

// ============ FieldType Tests ============

///|
test "FieldType validates" {
  let env = empty_env()
  let ft = FieldType::new(StorageType::val_type(ValType::i32()), Const)
  assert_eq(Validate::validate(ft, env), Ok(()))
}

// ============ FuncType Tests ============

///|
test "FuncType with empty params and results validates" {
  let env = empty_env()
  let ft = FuncType::new([], [])
  assert_eq(Validate::validate(ft, env), Ok(()))
}

///|
test "FuncType with params and results validates" {
  let env = empty_env()
  let ft = FuncType::new([ValType::i32()], [ValType::i64()])
  assert_eq(Validate::validate(ft, env), Ok(()))
}

// ============ CompType Tests ============

///|
test "CompType FuncCompType validates" {
  let env = empty_env()
  let ct = SubType::comp_type(CompType::func([], []))
  assert_eq(Validate::validate(ct, env), Ok(()))
}

///|
test "CompType ArrayCompType validates" {
  let env = empty_env()
  let ft = FieldType::new(StorageType::val_type(ValType::i32()), Const)
  let ct = SubType::comp_type(CompType::array(ft))
  assert_eq(Validate::validate(ct, env), Ok(()))
}

///|
test "CompType StructCompType validates" {
  let env = empty_env()
  let ft = FieldType::new(StorageType::val_type(ValType::i32()), Const)
  let ct = SubType::comp_type(CompType::struct_([ft]))
  assert_eq(Validate::validate(ct, env), Ok(()))
}

///|
test "CompType StructCompType empty validates" {
  let env = empty_env()
  let ct = SubType::comp_type(CompType::struct_([]))
  assert_eq(Validate::validate(ct, env), Ok(()))
}

// ============ SubType Tests ============

///|
test "SubType CompTypeSubType validates" {
  let env = empty_env()
  let st = SubType::comp_type(CompType::func([], []))
  assert_eq(Validate::validate(st, env), Ok(()))
}

// ============ RecType Tests ============

///|
test "RecType SingleRecType validates" {
  let env = empty_env()
  let st = SubType::comp_type(CompType::func([], []))
  let rt = RecType::new(st)
  assert_eq(Validate::validate(rt, env), Ok(()))
}

///|
test "RecType GroupRecType validates" {
  let env = empty_env()
  let st1 = SubType::comp_type(CompType::func([], []))
  let st2 = SubType::comp_type(
    CompType::array(
      FieldType::new(StorageType::val_type(ValType::i32()), Const),
    ),
  )
  let rt = RecType::group([st1, st2])
  assert_eq(Validate::validate(rt, env), Ok(()))
}

// ============ Array[T] Validate Tests ============

///|
test "Array of ValType validates" {
  let env = empty_env()
  let arr : Array[ValType] = [ValType::i32(), ValType::i64()]
  assert_eq(Validate::validate(arr, env), Ok(()))
}

///|
test "Empty array validates" {
  let env = empty_env()
  let arr : Array[ValType] = []
  assert_eq(Validate::validate(arr, env), Ok(()))
}

// ============ BlockType Tests ============

///|
test "BlockType EmptyBlockType validates" {
  let env = empty_env()
  assert_eq(Validate::validate(@lib.EmptyBlockType, env), Ok(()))
}

///|
test "BlockType ValTypeBlockType validates" {
  let env = empty_env()
  let bt = @lib.ValTypeBlockType(ValType::i32())
  assert_eq(Validate::validate(bt, env), Ok(()))
}

///|
test "BlockType TypeIdxBlockType with valid func type validates" {
  let st = SubType::comp_type(CompType::func([], []))
  let env = empty_env().with_types([st])
  let bt = BlockType::type_idx(TypeIdx::new(0))
  assert_eq(Validate::validate(bt, env), Ok(()))
}

///|
test "BlockType TypeIdxBlockType with invalid index fails" {
  let env = empty_env()
  let bt = BlockType::type_idx(TypeIdx::new(0))
  assert_eq(Validate::validate(bt, env), Err("Invalid TypeIdx for block type"))
}

///|
test "BlockType TypeIdxBlockType with non-func type fails" {
  let st = SubType::comp_type(
    CompType::array(
      FieldType::new(StorageType::val_type(ValType::i32()), Const),
    ),
  )
  let env = empty_env().with_types([st])
  let bt = BlockType::type_idx(TypeIdx::new(0))
  assert_eq(
    Validate::validate(bt, env),
    Err("Expected Func Type for block type"),
  )
}

// ============ ExternType Tests ============

///|
test "ExternType GlobalExternType validates" {
  let env = empty_env()
  let gt = GlobalType::new(ValType::i32(), false)
  let et = ExternType::global(gt)
  assert_eq(Validate::validate(et, env), Ok(()))
}

///|
test "ExternType MemExternType validates" {
  let env = empty_env()
  let mt = MemType::new(Limits::i32(0, Some(10)))
  let et = ExternType::mem(mt)
  assert_eq(Validate::validate(et, env), Ok(()))
}

///|
test "ExternType TableExternType validates" {
  let env = empty_env()
  let rt = RefType::abs(AbsHeapType::func())
  let tt = TableType::new(rt, Limits::i32(0, Some(100)))
  let et = ExternType::table(tt)
  assert_eq(Validate::validate(et, env), Ok(()))
}

///|
test "ExternType FuncExternType validates when func type exists" {
  let st = SubType::comp_type(CompType::func([], []))
  let env = empty_env().with_types([st])
  let et = ExternType::func(TypeIdx::new(0))
  assert_eq(Validate::validate(et, env), Ok(()))
}

///|
test "ExternType FuncExternType fails when func type missing" {
  let env = empty_env()
  let et = ExternType::func(TypeIdx::new(0))
  assert_eq(
    Validate::validate(et, env),
    Err("Invalid ExternType: Func extern type not found"),
  )
}

// ============ ExternIdx Tests ============

///|
test "ExternIdx FuncExternIdx validates" {
  let env = empty_env().with_funcs([FuncType::new([], [])])
  let ei = ExternIdx::func(FuncIdx::new(0))
  assert_eq(Validate::validate(ei, env), Ok(()))
}

///|
test "ExternIdx TableExternIdx validates" {
  let rt = RefType::abs(AbsHeapType::func())
  let tt = TableType::new(rt, Limits::i32(0, None))
  let env = empty_env().with_tables([tt])
  let ei = ExternIdx::table(TableIdx::new(0))
  assert_eq(Validate::validate(ei, env), Ok(()))
}

///|
test "ExternIdx MemExternIdx validates" {
  let mt = MemType::new(Limits::i32(0, None))
  let env = empty_env().with_mems([mt])
  let ei = ExternIdx::mem(MemIdx::new(0))
  assert_eq(Validate::validate(ei, env), Ok(()))
}

///|
test "ExternIdx GlobalExternIdx validates" {
  let gt = GlobalType::new(ValType::i32(), false)
  let env = empty_env().with_globals([gt])
  let ei = ExternIdx::global(GlobalIdx::new(0))
  assert_eq(Validate::validate(ei, env), Ok(()))
}

// ============ Export Tests ============

///|
test "Export with valid FuncExternIdx validates" {
  let env = empty_env().with_funcs([FuncType::new([], [])])
  let exp = Export::new(Name::new("test"), ExternIdx::func(FuncIdx::new(0)))
  assert_eq(Validate::validate(exp, env), Ok(()))
}

///|
test "Export with invalid index fails" {
  let env = empty_env()
  let exp = Export::new(Name::new("test"), ExternIdx::func(FuncIdx::new(0)))
  assert_eq(Validate::validate(exp, env), Err("invalid func index"))
}

// ============ Import Tests ============

///|
test "Import with valid GlobalExternType validates" {
  let env = empty_env()
  let gt = GlobalType::new(ValType::i32(), false)
  let imp = Import::new(
    Name::new("mod"),
    Name::new("name"),
    ExternType::global(gt),
  )
  assert_eq(Validate::validate(imp, env), Ok(()))
}

// ============ DataMode Tests ============

///|
test "DataMode Passive validates" {
  let env = empty_env()
  assert_eq(Validate::validate(DataMode::passive(), env), Ok(()))
}

// ============ Data Tests ============

///|
test "Data with Passive mode validates" {
  let env = empty_env()
  let d = Data::new(DataMode::passive(), b"hello")
  assert_eq(Validate::validate(d, env), Ok(()))
}

// ============ Catch Tests ============

///|
test "Catch CatchAll validates with valid label" {
  let env = empty_env().with_labels([[]])
  let c = Catch::all(LabelIdx::new(0))
  assert_eq(Validate::validate(c, env), Ok(()))
}

///|
test "Catch CatchAllRef validates with valid label" {
  let env = empty_env().with_labels([[]])
  let c = Catch::all_ref(LabelIdx::new(0))
  assert_eq(Validate::validate(c, env), Ok(()))
}

///|
test "Catch CatchAll fails with invalid label" {
  let env = empty_env()
  let c = Catch::all(LabelIdx::new(0))
  assert_eq(Validate::validate(c, env), Err("Invalid LabelIdx"))
}
