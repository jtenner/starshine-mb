///|
pub trait GenValid {
  gen_valid(Self, GenCtx) -> Result[Self, String]
}

///|
pub struct GenCtx {
  rnd : @quickcheck/splitmix.RandomState
  fuel : Int
  env : Env
}

///|
fn out_of_fuel(ctx : GenCtx) -> Bool {
  ctx.fuel <= 0
}

///|
pub fn gen_ctx_new(
  fuel : Int,
  rnd? : @quickcheck/splitmix.RandomState? = None,
) -> GenCtx {
  let rnd = rnd.unwrap_or(@quickcheck/splitmix.new())
  GenCtx::{ rnd, fuel, env: empty_env() }
}

///|
pub fn GenCtx::with_env(ctx : GenCtx, env : Env) -> GenCtx {
  GenCtx::{ rnd: ctx.rnd, fuel: ctx.fuel, env }
}

///|
pub fn GenCtx::with_fuel_only(ctx : GenCtx, fuel : Int) -> GenCtx {
  GenCtx::{ rnd: ctx.rnd, fuel, env: ctx.env }
}

///|
pub fn GenCtx::dec_fuel(ctx : GenCtx, n : Int) -> GenCtx {
  GenCtx::{ rnd: ctx.rnd, fuel: ctx.fuel - n, env: ctx.env }
}

///|
fn gen_value_of_type(
  ctx : GenCtx,
  st : TcState,
  vt : ValType,
) -> Result[(GenCtx, TcState, Array[Instruction]), String] {
  if out_of_fuel(ctx) {
    return Err("gen_value_of_type: out of fuel")
  }
  match vt {
    NumTypeValType(nt) =>
      match nt {
        I32NumType => {
          let ins = I32Const(I32(ctx.rnd.next_int()))
          match ins.typecheck(st) {
            Ok(st2) => Ok((ctx.dec_fuel(1), st2, [ins]))
            Err(e) => Err(e)
          }
        }
        I64NumType => {
          let ins = I64Const(I64(ctx.rnd.next_int64()))
          match ins.typecheck(st) {
            Ok(st2) => Ok((ctx.dec_fuel(1), st2, [ins]))
            Err(e) => Err(e)
          }
        }
        F32NumType => {
          let ins = F32Const(F32(ctx.rnd.next_float()))
          match ins.typecheck(st) {
            Ok(st2) => Ok((ctx.dec_fuel(1), st2, [ins]))
            Err(e) => Err(e)
          }
        }
        F64NumType => {
          let ins = F64Const(F64(ctx.rnd.next_double()))
          match ins.typecheck(st) {
            Ok(st2) => Ok((ctx.dec_fuel(1), st2, [ins]))
            Err(e) => Err(e)
          }
        }
      }
    VecTypeValType => {
      // emit a random V128Const
      let ins = V128Const(
        (ctx.rnd.next_uint() % 256).to_byte(),
        (ctx.rnd.next_uint() % 256).to_byte(),
        (ctx.rnd.next_uint() % 256).to_byte(),
        (ctx.rnd.next_uint() % 256).to_byte(),
        (ctx.rnd.next_uint() % 256).to_byte(),
        (ctx.rnd.next_uint() % 256).to_byte(),
        (ctx.rnd.next_uint() % 256).to_byte(),
        (ctx.rnd.next_uint() % 256).to_byte(),
        (ctx.rnd.next_uint() % 256).to_byte(),
        (ctx.rnd.next_uint() % 256).to_byte(),
        (ctx.rnd.next_uint() % 256).to_byte(),
        (ctx.rnd.next_uint() % 256).to_byte(),
        (ctx.rnd.next_uint() % 256).to_byte(),
        (ctx.rnd.next_uint() % 256).to_byte(),
        (ctx.rnd.next_uint() % 256).to_byte(),
        (ctx.rnd.next_uint() % 256).to_byte(),
      )
      match ins.typecheck(st) {
        Ok(st2) => Ok((ctx.dec_fuel(1), st2, [ins]))
        Err(e) => Err(e)
      }
    }
    RefTypeValType(rt) =>
      // If nullable: ref.null is easiest
      if rt.is_nullable() {
        let ht = rt.get_heap_type()
        let ins = RefNull(ht)
        match ins.typecheck(st) {
          Ok(st2) => Ok((ctx.dec_fuel(1), st2, [ins]))
          Err(e) => Err(e)
        }
      } else {
        // non-null cases we can construct
        let ht = rt.get_heap_type()
        match ht {
          HeapType(x) => gen_nonnull_ref_of_typeidx(ctx, st, x)
          AbsHeapTypeHeapType(I31AbsHeapType) => {
            // i32.const; ref.i31
            let (ctx1, st1, is1) = match gen_value_of_type(ctx, st, vt_i32()) {
              Ok(x) => x
              Err(e) => return Err(e)
            }
            let ins2 = RefI31
            match ins2.typecheck(st1) {
              Ok(st2) => {
                let out = is1.copy()
                out.push(ins2)
                Ok((ctx1.dec_fuel(1), st2, out))
              }
              Err(e) => Err(e)
            }
          }
          AbsHeapTypeHeapType(FuncAbsHeapType) => {
            // ref.func if possible
            if ctx.env.funcs.length() == 0 {
              return Err("cannot construct non-null funcref: no funcs in env")
            }
            let idx = FuncIdx(
              ctx.rnd.next_uint() % ctx.env.funcs.length().reinterpret_as_uint(),
            )
            let ins = RefFunc(idx)
            match ins.typecheck(st) {
              Ok(st2) => Ok((ctx.dec_fuel(1), st2, [ins]))
              Err(e) => Err(e)
            }
          }

          // If you want: for defined struct/array types you can use
          // struct.new_default/array.new_default when defaults exist, but that
          // requires choosing a valid TypeIdx and checking defaults. Add later.
          _ => Err("cannot construct non-null ref for this heap type yet")
        }
      }
    BotValType =>
      // shouldn't be requested as a target
      Err("gen_value_of_type: requested BotValType")
  }
}

///|
fn emit_finish_return(
  ctx : GenCtx,
  st : TcState,
  want : Array[ValType],
) -> Result[(GenCtx, TcState, Array[Instruction]), String] {
  let mut ctx = ctx
  let mut st = st
  let out : Array[Instruction] = []

  // push each wanted value (in order)
  for vt in want {
    let (ctx2, st2, insns) = match gen_value_of_type(ctx, st, vt) {
      Ok(x) => x
      Err(e) => return Err(e)
    }
    ctx = ctx2
    st = st2
    for i in insns {
      out.push(i)
    }
  }

  // now return (consumes want values)
  let ret = Return
  match ret.typecheck(st) {
    Ok(st2) => {
      out.push(ret)
      Ok((ctx.dec_fuel(1), st2, out))
    }
    Err(e) => Err(e)
  }
}

///|
pub fn gen_expr_valid(
  ctx : GenCtx,
  st0 : TcState,
  want : Array[ValType],
) -> Result[Expr, String] {
  let mut ctx = ctx
  let mut st = st0
  let insns : Array[Instruction] = []

  // keep some fuel for finishing
  while ctx.fuel > 10 {
    // Occasionally decide to finish early
    if ctx.rnd.next_uint() % 10 == 0 {
      break
    }
    let mut accepted = false

    // try multiple candidates; accept the first that typechecks
    for _ in 0..<30 {
      let cand = gen_candidate_instruction(ctx, st)
      match cand.typecheck(st) {
        Ok(st2) => {
          insns.push(cand)
          st = st2
          ctx = ctx.dec_fuel(1)
          accepted = true
          break
        }
        Err(_) => ()
      }
    }
    if !accepted {
      // If we can't find anything, stop and finish
      break
    }

    // If we became unreachable, we can stop and finish by just ending the Expr
    // BUT: your function validator expects a Return at end in many cases.
    // We'll still finish with return to be safe.
    if !st.reachable {
      break
    }
  }

  // Finish with required results + return
  let (ctx2, _st2, fin) = match emit_finish_return(ctx, st, want) {
    Ok(x) => x
    Err(e) => return Err(e)
  }
  ctx = ctx2
  for i in fin {
    insns.push(i)
  }
  Ok(Expr(insns))
}

///|
fn gen_nonnull_ref_of_typeidx(
  ctx : GenCtx,
  st : TcState,
  x : TypeIdx,
) -> Result[(GenCtx, TcState, Array[Instruction]), String] {
  // Determine if x is struct or array and defaultable
  let ct = match st.env.resolve_comptype(x) {
    None => return Err("cannot resolve comptype for typeidx")
    Some(c) => c
  }
  match ct {
    StructCompType(_) => {
      let ins = StructNewDefault(x)
      match ins.typecheck(st) {
        Ok(st2) => Ok((ctx.dec_fuel(1), st2, [ins]))
        Err(e) => Err(e)
      }
    }
    ArrayCompType(_) => {
      // Need i32 length first, then array.new_default
      let (ctx1, st1, is1) = match gen_value_of_type(ctx, st, vt_i32()) {
        Ok(x) => x
        Err(e) => return Err(e)
      }
      let ins2 = ArrayNewDefault(x)
      match ins2.typecheck(st1) {
        Ok(st2) => {
          let out = is1.copy()
          out.push(ins2)
          Ok((ctx1.dec_fuel(1), st2, out))
        }
        Err(e) => Err(e)
      }
    }
    _ => Err("typeidx is not struct or array")
  }
}

///|
fn gen_defaultable_valtype(rnd : @quickcheck/splitmix.RandomState) -> ValType {
  match rnd.next_uint() % 6 {
    0 => NumTypeValType(I32NumType)
    1 => NumTypeValType(I64NumType)
    2 => NumTypeValType(F32NumType)
    3 => NumTypeValType(F64NumType)
    4 => VecTypeValType
    _ => {
      // nullable refs only (default is ref.null)
      let abs = match rnd.next_uint() % 6 {
        0 => AnyAbsHeapType
        1 => EqAbsHeapType
        2 => StructAbsHeapType
        3 => ArrayAbsHeapType
        4 => FuncAbsHeapType
        _ => ExternAbsHeapType
      }
      RefTypeValType(HeapTypeRefType(true, AbsHeapTypeHeapType(abs)))
    }
  }
}

///|
fn gen_defaultable_field(rnd : @quickcheck/splitmix.RandomState) -> FieldType {
  let vt = gen_defaultable_valtype(rnd)
  let st = ValTypeStorageType(vt)
  let m = if (rnd.next_uint() & 1) == 1 { Var } else { Const }
  FieldType(st, m)
}

///|
fn gen_defaultable_array_field(
  rnd : @quickcheck/splitmix.RandomState,
) -> FieldType {
  // element mutability matters for set/copy later, but not for new_default
  gen_defaultable_field(rnd)
}

///|
fn gen_defaultable_struct_rectype(
  rnd : @quickcheck/splitmix.RandomState,
) -> RecType {
  let fields : Array[FieldType] = []
  let n = (rnd.next_uint() % 4).reinterpret_as_int() + 1 // 1..4 fields
  for _ in 0..<n {
    fields.push(gen_defaultable_field(rnd))
  }
  let ct = StructCompType(fields)
  // keep simple: no supertypes, non-final or final randomly
  let is_final = (rnd.next_uint() & 1) == 1
  SingleRecType(SubType(is_final, [], ct))
}

///|
fn gen_defaultable_array_rectype(
  rnd : @quickcheck/splitmix.RandomState,
) -> RecType {
  let ft = gen_defaultable_array_field(rnd)
  let ct = ArrayCompType(ft)
  let is_final = (rnd.next_uint() & 1) == 1
  SingleRecType(SubType(is_final, [], ct))
}

///|
fn gen_small_valtype(rnd : @quickcheck/splitmix.RandomState) -> ValType {
  // allow refs too, but keep mostly defaultable for now
  gen_defaultable_valtype(rnd)
}

///|
fn gen_func_rectype(rnd : @quickcheck/splitmix.RandomState) -> RecType {
  let ps : Array[ValType] = []
  let rs : Array[ValType] = []
  let pn = (rnd.next_uint() % 3).reinterpret_as_int() // 0..2 params
  let rn = (rnd.next_uint() % 3).reinterpret_as_int() // 0..2 results
  for _ in 0..<pn {
    ps.push(gen_small_valtype(rnd))
  }
  for _ in 0..<rn {
    rs.push(gen_small_valtype(rnd))
  }
  let ct = FuncCompType(ps, rs)
  let is_final = true // functions are typically final-ish; keep true to simplify
  SingleRecType(SubType(is_final, [], ct))
}

///|
pub fn gen_typesec_valid(ctx : GenCtx) -> Result[(GenCtx, TypeSec), String] {
  let rnd = ctx.rnd

  // Decide how many guaranteed GC types
  let pattern = rnd.next_uint() % 2
  let rectypes : Array[RecType] = []
  if pattern == 0 {
    // 2 structs + 1 array
    rectypes.push(gen_defaultable_struct_rectype(rnd))
    rectypes.push(gen_defaultable_struct_rectype(rnd))
    rectypes.push(gen_defaultable_array_rectype(rnd))
  } else {
    // 1 struct + 2 arrays
    rectypes.push(gen_defaultable_struct_rectype(rnd))
    rectypes.push(gen_defaultable_array_rectype(rnd))
    rectypes.push(gen_defaultable_array_rectype(rnd))
  }

  // Add some function types too (so we can generate calls/ref.func etc)
  let extra_funcs = (rnd.next_uint() % 4).reinterpret_as_int() + 1 // 1..4
  for _ in 0..<extra_funcs {
    rectypes.push(gen_func_rectype(rnd))
  }

  // Add some more random struct/array types (still defaultable for now)
  let extra_gc = (rnd.next_uint() % 4).reinterpret_as_int() // 0..3
  for _ in 0..<extra_gc {
    if (rnd.next_uint() & 1) == 1 {
      rectypes.push(gen_defaultable_struct_rectype(rnd))
    } else {
      rectypes.push(gen_defaultable_array_rectype(rnd))
    }
  }

  // Return updated ctx (consume some fuel proportional to types)
  let ctx2 = GenCtx::{
    rnd: ctx.rnd,
    fuel: ctx.fuel - rectypes.length(),
    env: ctx.env,
  }
  Ok((ctx2, TypeSec(rectypes)))
}

///|
fn collect_functype_typeidxs(env : Env) -> Array[TypeIdx] {
  let out : Array[TypeIdx] = []
  for i in 0..<env.global_types.length() {
    let tidx = TypeIdx(i.reinterpret_as_uint())
    if env.resolve_functype(tidx) is Some(_) {
      out.push(tidx)
    }
  }
  out
}

///|
fn env_for_func_body(env : Env, ft : FuncType, decls : Array[Locals]) -> Env {
  let FuncType(params, results) = ft
  let locals_expanded = expand_locals_decls(decls)
  let locals_all = params.copy()
  for vt in locals_expanded {
    locals_all.push(vt)
  }
  let labels2 = env.labels.copy()
  labels2.push(results)
  Env::{
    global_types: env.global_types,
    rec_stack: env.rec_stack,
    funcs: env.funcs,
    tables: env.tables,
    mems: env.mems,
    globals: env.globals,
    elems: env.elems,
    datas: env.datas,
    tags: env.tags,
    locals: locals_all,
    labels: labels2,
    return_type: Some(results),
  }
}

///|
fn gen_locals_decls(
  rnd : @quickcheck/splitmix.RandomState,
  max_groups : Int,
) -> Array[Locals] {
  let decls : Array[Locals] = []
  let groups = (rnd.next_uint() % max_groups.reinterpret_as_uint() + 1).reinterpret_as_int() // 1..max_groups
  for _ in 0..<groups {
    let vt = gen_defaultable_valtype(rnd)
    let count = rnd.next_uint() % 3 + 1 // 1..3 locals of this type
    decls.push(Locals(count, vt))
  }
  decls
}

///|
fn expand_locals_decls(decls : Array[Locals]) -> Array[ValType] {
  let out : Array[ValType] = []
  for d in decls {
    let Locals(n, vt) = d
    let count = n.reinterpret_as_int()
    for _ in 0..<count {
      out.push(vt)
    }
  }
  out
}

///|
fn gen_limits_i32(
  rnd : @quickcheck/splitmix.RandomState,
  max_val : UInt,
) -> Limits {
  let min = rnd.next_uint() % (max_val + 1)
  let has_max = (rnd.next_uint() & 1) == 1
  if has_max {
    let max = min + rnd.next_uint() % (max_val - min + 1)
    I32Limits(min, Some(max))
  } else {
    I32Limits(min, None)
  }
}

///|
fn gen_tabletype(
  rnd : @quickcheck/splitmix.RandomState,
  env : Env,
) -> TableType {
  // Choose element type - prefer funcref for compatibility with elem segments
  let rt = match rnd.next_uint() % 5 {
    0 => HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType))
    1 => HeapTypeRefType(true, AbsHeapTypeHeapType(ExternAbsHeapType))
    2 => HeapTypeRefType(true, AbsHeapTypeHeapType(AnyAbsHeapType))
    3 => HeapTypeRefType(true, AbsHeapTypeHeapType(EqAbsHeapType))
    _ => HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType))
  }
  let lim = gen_limits_i32(rnd, 100)
  ignore(env) // env available for future type-index references
  TableType(rt, lim)
}

///|
fn gen_memtype(rnd : @quickcheck/splitmix.RandomState) -> MemType {
  let min = rnd.next_uint() % 4 // small memory (0-3 pages)
  let has_max = (rnd.next_uint() & 1) == 1
  let lim = if has_max {
    let max = min + rnd.next_uint() % 4
    I32Limits(min, Some(max))
  } else {
    I32Limits(min, None)
  }
  MemType(lim)
}

///|
pub fn gen_tablesec_valid(
  ctx : GenCtx,
  env : Env,
) -> Result[(GenCtx, TableSec, Env), String] {
  let rnd = ctx.rnd
  let count = (rnd.next_uint() % 3).reinterpret_as_int() + 1 // 1..3 tables
  let tables : Array[Table] = []
  let mut env = env
  for _ in 0..<count {
    let tt = gen_tabletype(rnd, env)
    // No init expr for simplicity
    tables.push(Table(tt, None))
    env = env.push_table(tt)
  }
  let ctx2 = ctx.dec_fuel(count)
  Ok((ctx2, TableSec(tables), env))
}

///|
pub fn gen_memsec_valid(
  ctx : GenCtx,
  env : Env,
) -> Result[(GenCtx, MemSec, Env), String] {
  let rnd = ctx.rnd
  // MVP allows only 1 memory; keep simple
  let count = 1
  let mems : Array[MemType] = []
  let mut env = env
  for _ in 0..<count {
    let mt = gen_memtype(rnd)
    mems.push(mt)
    env = env.push_mem(mt)
  }
  let ctx2 = ctx.dec_fuel(count)
  Ok((ctx2, MemSec(mems), env))
}

///|
pub fn gen_datasec_valid(
  ctx : GenCtx,
  env : Env,
) -> Result[(GenCtx, DataSec, Env), String] {
  let rnd = ctx.rnd
  let count = (rnd.next_uint() % 3).reinterpret_as_int() // 0..2 data segments
  let datas : Array[Data] = []
  let mut env = env
  for _ in 0..<count {
    let has_mem = env.mems.length() > 0
    let is_active = has_mem && (rnd.next_uint() & 1) == 1
    let mode = if is_active {
      let mem_idx = rnd.next_uint() % env.mems.length().reinterpret_as_uint()
      // Get address type from memory limits
      let MemType(lim) = match env.get_memtype(MemIdx(mem_idx)) {
        Some(mt) => mt
        None => return Err("gen_datasec_valid: invalid mem index")
      }
      // Generate const offset expression with correct address type
      let offset_expr = match lim {
        I32Limits(_, _) => {
          let offset_val = (rnd.next_uint() % 256).reinterpret_as_int()
          Expr([I32Const(I32(offset_val))])
        }
        I64Limits(_, _) => {
          let offset_val = (rnd.next_uint64() % 256UL).reinterpret_as_int64()
          Expr([I64Const(I64(offset_val))])
        }
      }
      DataMode::Active(MemIdx(mem_idx), offset_expr)
    } else {
      Passive
    }

    // Generate some random bytes
    let byte_count = (rnd.next_uint() % 32).reinterpret_as_int()
    let bytes = []
    for i in 0..<byte_count {
      bytes.push((rnd.next_uint() % 256).to_byte())
    }
    let d = Data(mode, Bytes::from_array(bytes))
    datas.push(d)
    env = env.push_data(d)
  }
  let ctx2 = ctx.dec_fuel(count)
  Ok((ctx2, DataSec(datas), env))
}

///|
fn gen_elem_kind_funcs(
  rnd : @quickcheck/splitmix.RandomState,
  env : Env,
) -> ElemKind {
  let elem_count = (rnd.next_uint() % 5).reinterpret_as_int()
  let func_indices : Array[FuncIdx] = []
  if env.funcs.length() > 0 {
    for _ in 0..<elem_count {
      let fidx = rnd.next_uint() % env.funcs.length().reinterpret_as_uint()
      func_indices.push(FuncIdx(fidx))
    }
  }
  FuncsElemKind(func_indices)
}

///|
fn gen_elem_kind_func_exprs(
  rnd : @quickcheck/splitmix.RandomState,
  env : Env,
) -> ElemKind {
  let elem_count = (rnd.next_uint() % 5).reinterpret_as_int()
  let exprs : Array[Expr] = []
  for _ in 0..<elem_count {
    if env.funcs.length() > 0 && (rnd.next_uint() & 1) == 1 {
      let fidx = rnd.next_uint() % env.funcs.length().reinterpret_as_uint()
      exprs.push(Expr([RefFunc(FuncIdx(fidx))]))
    } else {
      // ref.null func
      exprs.push(Expr([RefNull(AbsHeapTypeHeapType(FuncAbsHeapType))]))
    }
  }
  FuncExprsElemKind(exprs)
}

///|
fn gen_elem_kind_typed_exprs(
  rnd : @quickcheck/splitmix.RandomState,
  env : Env,
  rt : RefType,
) -> ElemKind {
  let elem_count = (rnd.next_uint() % 5).reinterpret_as_int()
  let exprs : Array[Expr] = []
  let ht = rt.get_heap_type()
  for _ in 0..<elem_count {
    // For nullable refs, we can always use ref.null
    if rt.is_nullable() {
      exprs.push(Expr([RefNull(ht)]))
    } else {
      // Non-null: need ref.func for func types
      match ht {
        AbsHeapTypeHeapType(FuncAbsHeapType) =>
          if env.funcs.length() > 0 {
            let fidx = rnd.next_uint() %
              env.funcs.length().reinterpret_as_uint()
            exprs.push(Expr([RefFunc(FuncIdx(fidx))]))
          }
        _ =>
          // For other non-null types, skip (harder to generate)
          ()
      }
    }
  }
  TypedExprsElemKind(rt, exprs)
}

///|
fn find_compatible_table_for_funcref(env : Env) -> TableIdx? {
  for i in 0..<env.tables.length() {
    let tt = env.tables[i]
    let TableType(rt, _) = tt
    // funcref is compatible with funcref tables
    let funcref = HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType))
    if Match::matches(funcref, rt, env) {
      return Some(TableIdx(i.reinterpret_as_uint()))
    }
  }
  None
}

///|
pub fn gen_elemsec_valid(
  ctx : GenCtx,
  env : Env,
) -> Result[(GenCtx, ElemSec, Env), String] {
  let rnd = ctx.rnd
  let count = (rnd.next_uint() % 3).reinterpret_as_int() // 0..2 elem segments
  let elems : Array[Elem] = []
  let mut env = env
  for _ in 0..<count {
    // Choose mode
    let mode_choice = rnd.next_uint() % 4
    let (mode, use_funcref) = if mode_choice == 0 {
      (ElemMode::Passive, true)
    } else if mode_choice == 1 {
      (Declarative, true)
    } else {
      // Try Active mode
      match find_compatible_table_for_funcref(env) {
        Some(tab_idx) => {
          let TableType(_, lim) = env.tables[tab_idx.0.reinterpret_as_int()]
          let offset_val = (rnd.next_uint() % 10).reinterpret_as_int()
          let offset_expr = match lim {
            I32Limits(_, _) => Expr([I32Const(I32(offset_val))])
            I64Limits(_, _) => Expr([I64Const(I64(offset_val.to_int64()))])
          }
          (Active(tab_idx, offset_expr), true)
        }
        None => (Passive, true)
      }
    }

    // Generate element kind (funcref-based for compatibility)
    let kind = if use_funcref {
      match rnd.next_uint() % 3 {
        0 => gen_elem_kind_funcs(rnd, env)
        1 => gen_elem_kind_func_exprs(rnd, env)
        _ => {
          let rt = HeapTypeRefType(true, AbsHeapTypeHeapType(FuncAbsHeapType))
          gen_elem_kind_typed_exprs(rnd, env, rt)
        }
      }
    } else {
      gen_elem_kind_funcs(rnd, env)
    }
    let elem = Elem(mode, kind)
    elems.push(elem)
    // Update env with new elem
    let elems_arr = env.elems.copy()
    elems_arr.push(elem)
    env = Env::{
      global_types: env.global_types,
      rec_stack: env.rec_stack,
      funcs: env.funcs,
      tables: env.tables,
      mems: env.mems,
      globals: env.globals,
      elems: elems_arr,
      datas: env.datas,
      tags: env.tags,
      locals: env.locals,
      labels: env.labels,
      return_type: env.return_type,
    }
  }
  let ctx2 = ctx.dec_fuel(count)
  Ok((ctx2, ElemSec(elems), env))
}

///|
fn gen_globaltype(rnd : @quickcheck/splitmix.RandomState) -> GlobalType {
  let vt = gen_defaultable_valtype(rnd)
  let m = (rnd.next_uint() & 1) == 1
  GlobalType(vt, m)
}

///|
fn collect_tag_functype_typeidxs(env : Env) -> Array[TypeIdx] {
  let out : Array[TypeIdx] = []
  for i in 0..<env.global_types.length() {
    let tidx = TypeIdx(i.reinterpret_as_uint())
    match env.resolve_functype(tidx) {
      Some(FuncType(_, results)) if results.length() == 0 => out.push(tidx)
      _ => ()
    }
  }
  out
}

///|
fn gen_tagtype(rnd : @quickcheck/splitmix.RandomState, env : Env) -> TagType? {
  // Tags reference a function type (for exception parameters)
  let func_tidxs = collect_tag_functype_typeidxs(env)
  if func_tidxs.length() == 0 {
    return None
  }
  let pick = (rnd.next_uint() % func_tidxs.length().reinterpret_as_uint()).reinterpret_as_int()
  Some(TagType(func_tidxs[pick]))
}

///|
pub fn gen_importsec_valid(
  ctx : GenCtx,
  env : Env,
) -> Result[(GenCtx, ImportSec?, Env), String] {
  let rnd = ctx.rnd

  // Decide whether to have imports at all
  if rnd.next_uint() % 3 == 0 {
    return Ok((ctx, None, env))
  }
  let imports : Array[Import] = []
  let mut env = env
  let mut func_idx = 0
  let mut table_idx = 0
  let mut mem_idx = 0
  let mut global_idx = 0
  let mut tag_idx = 0

  // Generate 1-4 imports
  let count = (rnd.next_uint() % 4).reinterpret_as_int() + 1
  for i in 0..<count {
    let mod_names = ["env", "wasi", "host"]
    let mod_pick = (rnd.next_uint() % mod_names.length().reinterpret_as_uint()).reinterpret_as_int()
    let mod_name = mod_names[mod_pick]

    // Choose import type
    let import_type = rnd.next_uint() % 5
    let (name, desc) = match import_type {
      0 => {
        // Import a function
        let func_tidxs = collect_functype_typeidxs(env)
        if func_tidxs.length() > 0 {
          let pick = (rnd.next_uint() %
          func_tidxs.length().reinterpret_as_uint()).reinterpret_as_int()
          let tidx = func_tidxs[pick]
          let name = "func_" + func_idx.to_string()
          func_idx = func_idx + 1
          // Update env with imported function
          let ft = match env.resolve_functype(tidx) {
            Some(f) => f
            None => continue
          }
          env = env.push_func(ft)
          (name, FuncExternType(tidx))
        } else {
          continue
        }
      }
      1 => {
        // Import a table
        let tt = gen_tabletype(rnd, env)
        let name = "table_" + table_idx.to_string()
        table_idx = table_idx + 1
        env = env.push_table(tt)
        (name, TableExternType(tt))
      }
      2 =>
        // Import a memory (only if we don't have one yet - MVP limit)
        if env.mems.length() == 0 {
          let mt = gen_memtype(rnd)
          let name = "memory_" + mem_idx.to_string()
          mem_idx = mem_idx + 1
          env = env.push_mem(mt)
          (name, MemExternType(mt))
        } else {
          continue
        }
      3 => {
        // Import a global
        let gt = gen_globaltype(rnd)
        let name = "global_" + global_idx.to_string()
        global_idx = global_idx + 1
        env = env.push_global(gt)
        (name, GlobalExternType(gt))
      }
      _ =>
        // Import a tag
        match gen_tagtype(rnd, env) {
          Some(tt) => {
            let name = "tag_" + tag_idx.to_string()
            tag_idx = tag_idx + 1
            env = env.push_tag(tt)
            (name, TagExternType(tt))
          }
          None => continue
        }
    }
    imports.push(
      Import(Name(mod_name.to_string_view()), Name(name.to_string_view()), desc),
    )
  }
  let ctx2 = ctx.dec_fuel(imports.length())
  if imports.length() > 0 {
    Ok((ctx2, Some(ImportSec(imports)), env))
  } else {
    Ok((ctx2, None, env))
  }
}

///|
fn gen_const_expr_for_valtype(
  rnd : @quickcheck/splitmix.RandomState,
  vt : ValType,
  env : Env,
) -> Expr {
  match vt {
    NumTypeValType(I32NumType) => Expr([I32Const(I32(rnd.next_int()))])
    NumTypeValType(I64NumType) => Expr([I64Const(I64(rnd.next_int64()))])
    NumTypeValType(F32NumType) => Expr([F32Const(F32(rnd.next_float()))])
    NumTypeValType(F64NumType) => Expr([F64Const(F64(rnd.next_double()))])
    VecTypeValType =>
      Expr([
        V128Const(
          (rnd.next_uint() % 256).to_byte(),
          (rnd.next_uint() % 256).to_byte(),
          (rnd.next_uint() % 256).to_byte(),
          (rnd.next_uint() % 256).to_byte(),
          (rnd.next_uint() % 256).to_byte(),
          (rnd.next_uint() % 256).to_byte(),
          (rnd.next_uint() % 256).to_byte(),
          (rnd.next_uint() % 256).to_byte(),
          (rnd.next_uint() % 256).to_byte(),
          (rnd.next_uint() % 256).to_byte(),
          (rnd.next_uint() % 256).to_byte(),
          (rnd.next_uint() % 256).to_byte(),
          (rnd.next_uint() % 256).to_byte(),
          (rnd.next_uint() % 256).to_byte(),
          (rnd.next_uint() % 256).to_byte(),
          (rnd.next_uint() % 256).to_byte(),
        ),
      ])
    RefTypeValType(rt) =>
      if rt.is_nullable() {
        Expr([RefNull(rt.get_heap_type())])
      } else {
        // For non-null refs, try ref.func if it's a func type
        let ht = rt.get_heap_type()
        match ht {
          AbsHeapTypeHeapType(FuncAbsHeapType) =>
            if env.funcs.length() > 0 {
              let fidx = rnd.next_uint() %
                env.funcs.length().reinterpret_as_uint()
              Expr([RefFunc(FuncIdx(fidx))])
            } else {
              // Fallback to null (will fail validation for non-null, but safer)
              Expr([RefNull(ht)])
            }
          _ => Expr([RefNull(ht)])
        }
      }
    BotValType => Expr([Unreachable])
  }
}

///|
pub fn gen_globalsec_valid(
  ctx : GenCtx,
  env : Env,
) -> Result[(GenCtx, GlobalSec?, Env), String] {
  let rnd = ctx.rnd

  // Decide whether to have globals
  if rnd.next_uint() % 3 == 0 {
    return Ok((ctx, None, env))
  }
  let globals : Array[Global] = []
  let mut env = env

  // Generate 1-4 globals
  let count = (rnd.next_uint() % 4).reinterpret_as_int() + 1
  for _ in 0..<count {
    let gt = gen_globaltype(rnd)
    let GlobalType(vt, _) = gt
    let init_expr = gen_const_expr_for_valtype(rnd, vt, env)
    globals.push(Global(gt, init_expr))
    env = env.push_global(gt)
  }
  let ctx2 = ctx.dec_fuel(count)
  Ok((ctx2, Some(GlobalSec(globals)), env))
}

///|
pub fn gen_tagsec_valid(
  ctx : GenCtx,
  env : Env,
) -> Result[(GenCtx, TagSec?, Env), String] {
  let rnd = ctx.rnd

  // Tags are less common, lower probability
  if rnd.next_uint() % 4 != 0 {
    return Ok((ctx, None, env))
  }
  let tags : Array[TagType] = []
  let mut env = env

  // Generate 1-2 tags
  let count = (rnd.next_uint() % 2).reinterpret_as_int() + 1
  for _ in 0..<count {
    match gen_tagtype(rnd, env) {
      Some(tt) => {
        tags.push(tt)
        env = env.push_tag(tt)
      }
      None => break
    }
  }
  let ctx2 = ctx.dec_fuel(tags.length())
  if tags.length() > 0 {
    Ok((ctx2, Some(TagSec(tags)), env))
  } else {
    Ok((ctx2, None, env))
  }
}

///|
pub fn gen_exportsec_valid(
  ctx : GenCtx,
  env : Env,
) -> Result[(GenCtx, ExportSec?), String] {
  let rnd = ctx.rnd
  let exports : Array[Export] = []

  // Helper to generate unique name
  fn make_unique_name(base : String, idx : Int) -> String {
    let name = base + "_" + idx.to_string()
    // Simple uniqueness - in practice collision is rare with index suffix
    name
  }

  // Export some functions
  if env.funcs.length() > 0 {
    let func_export_count = (rnd.next_uint() %
    (env.funcs.length().reinterpret_as_uint() + 1)).reinterpret_as_int()
    for i in 0..<func_export_count {
      if rnd.next_uint() % 2 == 0 {
        let name = make_unique_name("func", i)
        let fidx = rnd.next_uint() % env.funcs.length().reinterpret_as_uint()
        exports.push(
          Export(Name(name.to_string_view()), FuncExternIdx(FuncIdx(fidx))),
        )
      }
    }
  }

  // Export some tables
  if env.tables.length() > 0 && rnd.next_uint() % 3 == 0 {
    let name = make_unique_name("table", 0)
    let tidx = rnd.next_uint() % env.tables.length().reinterpret_as_uint()
    exports.push(
      Export(Name(name.to_string_view()), TableExternIdx(TableIdx(tidx))),
    )
  }

  // Export memory (common for WASI compatibility)
  if env.mems.length() > 0 && rnd.next_uint() % 2 == 0 {
    let name = "memory"
    exports.push(Export(Name(name.to_string_view()), MemExternIdx(MemIdx(0))))
  }

  // Export some globals
  if env.globals.length() > 0 && rnd.next_uint() % 3 == 0 {
    for i in 0..<env.globals.length() {
      if rnd.next_uint() % 3 == 0 {
        let name = make_unique_name("global", i)
        exports.push(
          Export(
            Name(name.to_string_view()),
            GlobalExternIdx(GlobalIdx(i.reinterpret_as_uint())),
          ),
        )
      }
    }
  }

  // Export some tags
  if env.tags.length() > 0 && rnd.next_uint() % 4 == 0 {
    let name = make_unique_name("tag", 0)
    let tidx = rnd.next_uint() % env.tags.length().reinterpret_as_uint()
    exports.push(
      Export(Name(name.to_string_view()), TagExternIdx(TagIdx(tidx))),
    )
  }
  let ctx2 = ctx.dec_fuel(exports.length())
  if exports.length() > 0 {
    Ok((ctx2, Some(ExportSec(exports))))
  } else {
    Ok((ctx2, None))
  }
}

///|
fn find_start_func_candidate(env : Env) -> FuncIdx? {
  // Start function must have type [] -> []
  for i in 0..<env.funcs.length() {
    let ft = env.funcs[i]
    let FuncType(params, results) = ft
    if params.length() == 0 && results.length() == 0 {
      return Some(FuncIdx(i.reinterpret_as_uint()))
    }
  }
  None
}

///|
pub fn gen_startsec_valid(
  ctx : GenCtx,
  env : Env,
) -> Result[(GenCtx, StartSec?), String] {
  let rnd = ctx.rnd

  // Only generate start function ~25% of the time
  if rnd.next_uint() % 4 != 0 {
    return Ok((ctx, None))
  }
  match find_start_func_candidate(env) {
    Some(fidx) => {
      let ctx2 = ctx.dec_fuel(1)
      Ok((ctx2, Some(StartSec(fidx))))
    }
    None => Ok((ctx, None))
  }
}

///|
fn collect_struct_typeidxs(env : Env) -> Array[TypeIdx] {
  let out : Array[TypeIdx] = []
  for i in 0..<env.global_types.length() {
    let tidx = TypeIdx(i.reinterpret_as_uint())
    match env.resolve_comptype(tidx) {
      Some(StructCompType(_)) => out.push(tidx)
      _ => ()
    }
  }
  out
}

///|
fn collect_array_typeidxs(env : Env) -> Array[TypeIdx] {
  let out : Array[TypeIdx] = []
  for i in 0..<env.global_types.length() {
    let tidx = TypeIdx(i.reinterpret_as_uint())
    match env.resolve_comptype(tidx) {
      Some(ArrayCompType(_)) => out.push(tidx)
      _ => ()
    }
  }
  out
}

///|
fn get_struct_field_count(env : Env, tidx : TypeIdx) -> Int {
  match env.resolve_comptype(tidx) {
    Some(StructCompType(fields)) => fields.length()
    _ => 0
  }
}

///|
fn get_struct_field_mutability(env : Env, tidx : TypeIdx, fidx : Int) -> Mut? {
  match env.resolve_comptype(tidx) {
    Some(StructCompType(fields)) =>
      if fidx < fields.length() {
        let FieldType(_, m) = fields[fidx]
        Some(m)
      } else {
        None
      }
    _ => None
  }
}

///|
fn get_array_elem_mutability(env : Env, tidx : TypeIdx) -> Mut? {
  match env.resolve_comptype(tidx) {
    Some(ArrayCompType(FieldType(_, m))) => Some(m)
    _ => None
  }
}

///|
fn is_packed_storage_type(st : StorageType) -> Bool {
  st is PackTypeStorageType(_)
}

///|
fn get_struct_field_storage_type(
  env : Env,
  tidx : TypeIdx,
  fidx : Int,
) -> StorageType? {
  match env.resolve_comptype(tidx) {
    Some(StructCompType(fields)) =>
      if fidx < fields.length() {
        let FieldType(st, _) = fields[fidx]
        Some(st)
      } else {
        None
      }
    _ => None
  }
}

///|
fn get_array_storage_type(env : Env, tidx : TypeIdx) -> StorageType? {
  match env.resolve_comptype(tidx) {
    Some(ArrayCompType(FieldType(st, _))) => Some(st)
    _ => None
  }
}

///|
fn gen_struct_instruction(
  rnd : @quickcheck/splitmix.RandomState,
  env : Env,
) -> Instruction? {
  let struct_idxs = collect_struct_typeidxs(env)
  if struct_idxs.length() == 0 {
    return None
  }
  let tidx_pick = (rnd.next_uint() % struct_idxs.length().reinterpret_as_uint()).reinterpret_as_int()
  let tidx = struct_idxs[tidx_pick]
  let field_count = get_struct_field_count(env, tidx)
  if field_count == 0 {
    return Some(StructNewDefault(tidx))
  }
  let fidx = (rnd.next_uint() % field_count.reinterpret_as_uint()).reinterpret_as_int()
  let field_idx = U32(fidx.reinterpret_as_uint())
  let choice = rnd.next_uint() % 6
  match choice {
    0 => Some(StructNewDefault(tidx))
    1 => Some(StructNew(tidx))
    2 =>
      // struct.get - check if packed
      match get_struct_field_storage_type(env, tidx, fidx) {
        Some(st) =>
          if is_packed_storage_type(st) {
            // Use signed or unsigned variant
            if (rnd.next_uint() & 1) == 1 {
              Some(StructGetS(tidx, field_idx))
            } else {
              Some(StructGetU(tidx, field_idx))
            }
          } else {
            Some(StructGet(tidx, field_idx))
          }
        None => Some(StructGet(tidx, field_idx))
      }
    3 =>
      // struct.get_s for packed fields
      match get_struct_field_storage_type(env, tidx, fidx) {
        Some(st) =>
          if is_packed_storage_type(st) {
            Some(StructGetS(tidx, field_idx))
          } else {
            Some(StructGet(tidx, field_idx))
          }
        None => Some(StructGet(tidx, field_idx))
      }
    4 =>
      // struct.set - only if mutable
      match get_struct_field_mutability(env, tidx, fidx) {
        Some(Var) => Some(StructSet(tidx, field_idx))
        _ => Some(StructNewDefault(tidx))
      }
    _ => Some(StructNewDefault(tidx))
  }
}

///|
fn gen_array_instruction(
  rnd : @quickcheck/splitmix.RandomState,
  env : Env,
) -> Instruction? {
  let array_idxs = collect_array_typeidxs(env)
  if array_idxs.length() == 0 {
    return None
  }
  let tidx_pick = (rnd.next_uint() % array_idxs.length().reinterpret_as_uint()).reinterpret_as_int()
  let tidx = array_idxs[tidx_pick]
  let choice = rnd.next_uint() % 10
  match choice {
    0 => Some(ArrayNewDefault(tidx))
    1 => Some(ArrayNew(tidx))
    2 => {
      let n = (rnd.next_uint() % 5).reinterpret_as_int()
      Some(ArrayNewFixed(tidx, U32(n.reinterpret_as_uint())))
    }
    3 =>
      // array.get - check if packed
      match get_array_storage_type(env, tidx) {
        Some(st) =>
          if is_packed_storage_type(st) {
            if (rnd.next_uint() & 1) == 1 {
              Some(ArrayGetS(tidx))
            } else {
              Some(ArrayGetU(tidx))
            }
          } else {
            Some(ArrayGet(tidx))
          }
        None => Some(ArrayGet(tidx))
      }
    4 =>
      // array.get_s for packed
      match get_array_storage_type(env, tidx) {
        Some(st) =>
          if is_packed_storage_type(st) {
            Some(ArrayGetS(tidx))
          } else {
            Some(ArrayGet(tidx))
          }
        None => Some(ArrayGet(tidx))
      }
    5 =>
      // array.set - only if mutable
      match get_array_elem_mutability(env, tidx) {
        Some(Var) => Some(ArraySet(tidx))
        _ => Some(ArrayNewDefault(tidx))
      }
    6 => Some(ArrayLen)
    7 =>
      // array.fill - only if mutable
      match get_array_elem_mutability(env, tidx) {
        Some(Var) => Some(ArrayFill(tidx))
        _ => Some(ArrayLen)
      }
    8 => {
      // array.copy - need two compatible array types, both mutable dest
      let dest_tidx = tidx
      match get_array_elem_mutability(env, dest_tidx) {
        Some(Var) => {
          // Find a compatible source array
          for src_tidx in array_idxs {
            // For simplicity, use same type
            if src_tidx == dest_tidx {
              return Some(ArrayCopy(dest_tidx, src_tidx))
            }
          }
          Some(ArrayLen)
        }
        _ => Some(ArrayLen)
      }
    }
    _ => Some(ArrayNewDefault(tidx))
  }
}

///|
fn gen_tag_instruction(
  rnd : @quickcheck/splitmix.RandomState,
  env : Env,
) -> Instruction? {
  if env.tags.length() == 0 {
    return None
  }
  let tag_pick = (rnd.next_uint() % env.tags.length().reinterpret_as_uint()).reinterpret_as_int()
  let tag_idx = TagIdx(tag_pick.reinterpret_as_uint())

  // throw is the main instruction we can generate simply
  Some(Throw(tag_idx))
}

///|
fn gen_ref_instruction(
  rnd : @quickcheck/splitmix.RandomState,
  env : Env,
) -> Instruction? {
  let choice = rnd.next_uint() % 10
  match choice {
    0 => {
      // ref.null with random heap type
      let abs = match rnd.next_uint() % 8 {
        0 => AnyAbsHeapType
        1 => EqAbsHeapType
        2 => I31AbsHeapType
        3 => StructAbsHeapType
        4 => ArrayAbsHeapType
        5 => FuncAbsHeapType
        6 => ExternAbsHeapType
        _ => NoneAbsHeapType
      }
      Some(RefNull(AbsHeapTypeHeapType(abs)))
    }
    1 => Some(RefIsNull)
    2 => Some(RefAsNonNull)
    3 => Some(RefEq)
    4 => Some(RefI31)
    5 => Some(I31GetS)
    6 => Some(I31GetU)
    7 => {
      // ref.test with a type
      let struct_idxs = collect_struct_typeidxs(env)
      if struct_idxs.length() > 0 {
        let pick = (rnd.next_uint() % struct_idxs.length().reinterpret_as_uint()).reinterpret_as_int()
        Some(RefTest(false, HeapType(struct_idxs[pick])))
      } else {
        Some(RefIsNull)
      }
    }
    8 => {
      // ref.cast with a type
      let struct_idxs = collect_struct_typeidxs(env)
      if struct_idxs.length() > 0 {
        let pick = (rnd.next_uint() % struct_idxs.length().reinterpret_as_uint()).reinterpret_as_int()
        let nullable = (rnd.next_uint() & 1) == 1
        Some(RefCast(nullable, HeapType(struct_idxs[pick])))
      } else {
        Some(RefIsNull)
      }
    }
    _ =>
      // ref.func if we have functions
      if env.funcs.length() > 0 {
        let fidx = rnd.next_uint() % env.funcs.length().reinterpret_as_uint()
        Some(RefFunc(FuncIdx(fidx)))
      } else {
        Some(RefIsNull)
      }
  }
}

///|
fn gen_numeric_instruction(
  rnd : @quickcheck/splitmix.RandomState,
) -> Instruction {
  let choice = rnd.next_uint() % 40
  match choice {
    // i32 operations
    0 => I32Add
    1 => I32Sub
    2 => I32Mul
    3 => I32DivS
    4 => I32DivU
    5 => I32RemS
    6 => I32RemU
    7 => I32And
    8 => I32Or
    9 => I32Xor
    10 => I32Shl
    11 => I32ShrS
    12 => I32ShrU
    13 => I32Eqz
    14 => I32Eq
    15 => I32Ne
    16 => I32LtS
    17 => I32LtU
    18 => I32GtS
    19 => I32GtU
    // i64 operations
    20 => I64Add
    21 => I64Sub
    22 => I64Mul
    23 => I64Eqz
    24 => I64Eq
    25 => I64Ne
    // f32 operations
    26 => F32Add
    27 => F32Sub
    28 => F32Mul
    29 => F32Div
    30 => F32Eq
    31 => F32Ne
    // f64 operations
    32 => F64Add
    33 => F64Sub
    34 => F64Mul
    35 => F64Div
    // conversions
    36 => I32WrapI64
    37 => I64ExtendI32S
    38 => I64ExtendI32U
    _ => I32Const(I32(rnd.next_int()))
  }
}

///|

///|
fn gen_memory_instruction(
  rnd : @quickcheck/splitmix.RandomState,
  env : Env,
) -> Instruction? {
  if env.mems.length() == 0 {
    return None
  }
  let mem_idx_val = rnd.next_uint() % env.mems.length().reinterpret_as_uint()
  let mem_idx = MemIdx(mem_idx_val)

  // Generate alignment (must be power of 2, encoded as log2)
  // For i32 load/store: max align is 2 (4 bytes)
  // For i64 load/store: max align is 3 (8 bytes)
  // For i8 load/store: max align is 0 (1 byte)
  fn make_memarg(
    rnd : @quickcheck/splitmix.RandomState,
    max_align : UInt,
    env : Env,
    mem_idx : MemIdx,
  ) -> MemArg {
    let align = rnd.next_uint() % (max_align + 1)
    let offset = rnd.next_uint64() % 256 // small offset
    let mem_idx_opt = if env.mems.length() == 1 { None } else { Some(mem_idx) }
    MemArg(U32(align), mem_idx_opt, U64(offset))
  }

  let choice = rnd.next_uint() % 16
  match choice {
    0 => Some(I32Load(make_memarg(rnd, 2, env, mem_idx)))
    1 => Some(I64Load(make_memarg(rnd, 3, env, mem_idx)))
    2 => Some(F32Load(make_memarg(rnd, 2, env, mem_idx)))
    3 => Some(F64Load(make_memarg(rnd, 3, env, mem_idx)))
    4 => Some(I32Load8S(make_memarg(rnd, 0, env, mem_idx)))
    5 => Some(I32Load8U(make_memarg(rnd, 0, env, mem_idx)))
    6 => Some(I32Load16S(make_memarg(rnd, 1, env, mem_idx)))
    7 => Some(I32Load16U(make_memarg(rnd, 1, env, mem_idx)))
    8 => Some(I32Store(make_memarg(rnd, 2, env, mem_idx)))
    9 => Some(I64Store(make_memarg(rnd, 3, env, mem_idx)))
    10 => Some(F32Store(make_memarg(rnd, 2, env, mem_idx)))
    11 => Some(F64Store(make_memarg(rnd, 3, env, mem_idx)))
    12 => Some(I32Store8(make_memarg(rnd, 0, env, mem_idx)))
    13 => Some(I32Store16(make_memarg(rnd, 1, env, mem_idx)))
    14 => Some(MemorySize(mem_idx))
    _ => Some(MemoryGrow(mem_idx))
  }
}

///|
fn gen_local_instruction(
  rnd : @quickcheck/splitmix.RandomState,
  env : Env,
) -> Instruction? {
  if env.locals.length() == 0 {
    return None
  }
  let idx = rnd.next_uint() % env.locals.length().reinterpret_as_uint()
  let local_idx = LocalIdx(idx)
  match rnd.next_uint() % 3 {
    0 => Some(LocalGet(local_idx))
    1 => Some(LocalSet(local_idx))
    _ => Some(LocalTee(local_idx))
  }
}

///|
fn gen_global_instruction(
  rnd : @quickcheck/splitmix.RandomState,
  env : Env,
) -> Instruction? {
  if env.globals.length() == 0 {
    return None
  }
  let idx = rnd.next_uint() % env.globals.length().reinterpret_as_uint()
  let global_idx = GlobalIdx(idx)

  // Check mutability for global.set
  let gt = env.globals[idx.reinterpret_as_int()]
  let GlobalType(_, is_mut) = gt
  if is_mut && (rnd.next_uint() & 1) == 1 {
    Some(GlobalSet(global_idx))
  } else {
    Some(GlobalGet(global_idx))
  }
}

///|
fn gen_call_instruction(
  rnd : @quickcheck/splitmix.RandomState,
  env : Env,
) -> Instruction? {
  if env.funcs.length() == 0 {
    return None
  }
  let fidx = rnd.next_uint() % env.funcs.length().reinterpret_as_uint()
  match rnd.next_uint() % 2 {
    0 => Some(Call(FuncIdx(fidx)))
    _ =>
      // call_indirect needs a table with funcref
      if env.tables.length() > 0 {
        // Find a funcref table
        for i in 0..<env.tables.length() {
          let TableType(rt, _) = env.tables[i]
          let funcref = HeapTypeRefType(
            true,
            AbsHeapTypeHeapType(FuncAbsHeapType),
          )
          if Match::matches(funcref, rt, env) {
            // Need to find the function type index
            let func_tidxs = collect_functype_typeidxs(env)
            if func_tidxs.length() > 0 {
              let tidx_pick = (rnd.next_uint() %
              func_tidxs.length().reinterpret_as_uint()).reinterpret_as_int()
              return Some(
                CallIndirect(
                  func_tidxs[tidx_pick],
                  TableIdx(i.reinterpret_as_uint()),
                ),
              )
            }
          }
        }
        Some(Call(FuncIdx(fidx)))
      } else {
        Some(Call(FuncIdx(fidx)))
      }
  }
}

///|
fn gen_table_instruction(
  rnd : @quickcheck/splitmix.RandomState,
  env : Env,
) -> Instruction? {
  if env.tables.length() == 0 {
    return None
  }
  let tidx = rnd.next_uint() % env.tables.length().reinterpret_as_uint()
  let table_idx = TableIdx(tidx)
  match rnd.next_uint() % 4 {
    0 => Some(TableGet(table_idx))
    1 => Some(TableSet(table_idx))
    2 => Some(TableSize(table_idx))
    _ => Some(TableGrow(table_idx))
  }
}

///|
fn gen_candidate_instruction(ctx : GenCtx, st : TcState) -> Instruction {
  // Weighted selection to ensure variety
  let choice = (ctx.rnd.next_uint() % 100).reinterpret_as_int()
  match choice {
    // Constants (10%)
    0 | 1 => I32Const(I32(ctx.rnd.next_int()))
    2 | 3 => I64Const(I64(ctx.rnd.next_int64()))
    4 => F32Const(F32(ctx.rnd.next_float()))
    5 => F64Const(F64(ctx.rnd.next_double()))
    6 | 7 | 8 | 9 =>
      V128Const(
        (ctx.rnd.next_uint() % 256).to_byte(),
        (ctx.rnd.next_uint() % 256).to_byte(),
        (ctx.rnd.next_uint() % 256).to_byte(),
        (ctx.rnd.next_uint() % 256).to_byte(),
        (ctx.rnd.next_uint() % 256).to_byte(),
        (ctx.rnd.next_uint() % 256).to_byte(),
        (ctx.rnd.next_uint() % 256).to_byte(),
        (ctx.rnd.next_uint() % 256).to_byte(),
        (ctx.rnd.next_uint() % 256).to_byte(),
        (ctx.rnd.next_uint() % 256).to_byte(),
        (ctx.rnd.next_uint() % 256).to_byte(),
        (ctx.rnd.next_uint() % 256).to_byte(),
        (ctx.rnd.next_uint() % 256).to_byte(),
        (ctx.rnd.next_uint() % 256).to_byte(),
        (ctx.rnd.next_uint() % 256).to_byte(),
        (ctx.rnd.next_uint() % 256).to_byte(),
      )

    // Struct operations (15%)
    10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 | 21 | 22 | 23 | 24 =>
      match gen_struct_instruction(ctx.rnd, st.env) {
        Some(ins) => ins
        None => I32Const(I32(ctx.rnd.next_int()))
      }

    // Array operations (15%)
    25 | 26 | 27 | 28 | 29 | 30 | 31 | 32 | 33 | 34 | 35 | 36 | 37 | 38 | 39 =>
      match gen_array_instruction(ctx.rnd, st.env) {
        Some(ins) => ins
        None => I32Const(I32(ctx.rnd.next_int()))
      }

    // Tag/exception operations (5%)
    40 | 41 | 42 | 43 | 44 =>
      match gen_tag_instruction(ctx.rnd, st.env) {
        Some(ins) => ins
        None => Nop
      }

    // Reference operations (10%)
    45 | 46 | 47 | 48 | 49 | 50 | 51 | 52 | 53 | 54 =>
      match gen_ref_instruction(ctx.rnd, st.env) {
        Some(ins) => ins
        None => Nop
      }

    // Numeric operations (20%)
    55
    | 56
    | 57
    | 58
    | 59
    | 60
    | 61
    | 62
    | 63
    | 64
    | 65
    | 66
    | 67
    | 68
    | 69
    | 70
    | 71
    | 72
    | 73
    | 74 => gen_numeric_instruction(ctx.rnd)

    // Local operations (8%)
    75 | 76 | 77 | 78 | 79 | 80 | 81 | 82 =>
      match gen_local_instruction(ctx.rnd, st.env) {
        Some(ins) => ins
        None => Nop
      }

    // Global operations (5%)
    83 | 84 | 85 | 86 | 87 =>
      match gen_global_instruction(ctx.rnd, st.env) {
        Some(ins) => ins
        None => Nop
      }

    // Memory operations (5%)
    88 | 89 | 90 | 91 | 92 =>
      match gen_memory_instruction(ctx.rnd, st.env) {
        Some(ins) => ins
        None => Nop
      }

    // Call operations (5%)
    93 | 94 | 95 | 96 | 97 =>
      match gen_call_instruction(ctx.rnd, st.env) {
        Some(ins) => ins
        None => Nop
      }

    // Table operations (3%)
    98 | 99 =>
      match gen_table_instruction(ctx.rnd, st.env) {
        Some(ins) => ins
        None => Nop
      }

    // Misc
    _ =>
      match ctx.rnd.next_uint() % 3 {
        0 => Nop
        1 => Drop
        _ => Select(None)
      }
  }
}

///|
fn gen_try_table_robust(
  ctx : GenCtx,
  st : TcState,
) -> Result[(GenCtx, TcState, Array[Instruction]), String] {
  if st.env.tags.length() == 0 {
    return Err("no tags for try_table")
  }
  let rnd = ctx.rnd

  // Choose strategy
  let strategy = rnd.next_uint() % 4
  match strategy {
    0 => gen_try_catch_all(ctx, st, rnd)
    1 => gen_try_catch_all_ref(ctx, st, rnd)
    2 => gen_try_catch(ctx, st, rnd)
    3 => gen_try_catch_ref(ctx, st, rnd)
    _ => gen_try_catch_all(ctx, st, rnd)
  }
}

///|
fn gen_try_catch_all(
  ctx : GenCtx,
  st : TcState,
  rnd : @quickcheck/splitmix.RandomState,
) -> Result[(GenCtx, TcState, Array[Instruction]), String] {
  // Structure: block (result) { try_table { catch_all 0; <body> } }
  // catch_all branches with empty values, outer block has empty result

  let try_body = gen_simple_try_body(rnd, st.env)
  let catch_clause = CatchAll(LabelIdx(0))
  let try_table = TryTable(EmptyBlockType, [catch_clause], try_body)
  let block_ins = Block(EmptyBlockType, [try_table])
  match block_ins.typecheck(st) {
    Ok(st2) => Ok((ctx.dec_fuel(3), st2, [block_ins]))
    Err(e) => Err(e)
  }
}

///|
fn gen_try_catch_all_ref(
  ctx : GenCtx,
  st : TcState,
  rnd : @quickcheck/splitmix.RandomState,
) -> Result[(GenCtx, TcState, Array[Instruction]), String] {
  // catch_all_ref branches with [exnref]
  // After try_table completes normally, we need to produce an exnref
  // Since we can't easily produce a non-null exnref, use nullable

  let exnref_nullable = RefTypeValType(
    HeapTypeRefType(true, AbsHeapTypeHeapType(ExnAbsHeapType)),
  )
  let outer_bt = ValTypeBlockType(exnref_nullable)
  let try_body = gen_simple_try_body(rnd, st.env)
  let catch_clause = CatchAllRef(LabelIdx(0))
  let try_table = TryTable(EmptyBlockType, [catch_clause], try_body)

  // After try_table, produce null exnref for fallthrough
  let fallthrough = RefNull(AbsHeapTypeHeapType(ExnAbsHeapType))
  let block_ins = Block(outer_bt, [try_table, fallthrough])
  match block_ins.typecheck(st) {
    Ok(st2) => Ok((ctx.dec_fuel(4), st2, [block_ins]))
    Err(e) => Err(e)
  }
}

///|
fn gen_try_catch(
  ctx : GenCtx,
  st : TcState,
  rnd : @quickcheck/splitmix.RandomState,
) -> Result[(GenCtx, TcState, Array[Instruction]), String] {
  // catch tag L branches with tag's payload types
  // Outer block result = payload types

  let tag_idx = TagIdx(
    rnd.next_uint() % st.env.tags.length().reinterpret_as_uint(),
  )
  let payload = tag_payload_types(st.env, tag_idx)

  // Build block type - only support empty or single-value for simplicity
  let outer_bt = match payload.length() {
    0 => EmptyBlockType
    1 => ValTypeBlockType(payload[0])
    _ => return Err("multi-value catch payload not supported yet")
  }

  // Generate fallthrough values for when try completes normally
  let fallthrough = match gen_fallthrough_values(rnd, payload) {
    Ok(ins) => ins
    Err(e) => return Err(e)
  }
  let try_body = gen_simple_try_body(rnd, st.env)
  let catch_clause = Catch(tag_idx, LabelIdx(0))
  let try_table = TryTable(EmptyBlockType, [catch_clause], try_body)
  let block_body : Array[Instruction] = [try_table]
  for ins in fallthrough {
    block_body.push(ins)
  }
  let block_ins = Block(outer_bt, block_body)
  match block_ins.typecheck(st) {
    Ok(st2) => Ok((ctx.dec_fuel(4 + fallthrough.length()), st2, [block_ins]))
    Err(e) => Err(e)
  }
}

///|
fn gen_try_catch_ref(
  ctx : GenCtx,
  st : TcState,
  rnd : @quickcheck/splitmix.RandomState,
) -> Result[(GenCtx, TcState, Array[Instruction]), String] {
  // catch_ref tag L branches with payload + exnref
  // For simplicity, only handle tags with empty payload

  let tag_idx = TagIdx(
    rnd.next_uint() % st.env.tags.length().reinterpret_as_uint(),
  )
  let payload = tag_payload_types(st.env, tag_idx)

  // Only support empty payload for catch_ref (result is just exnref)
  if payload.length() != 0 {
    // Fall back to catch_all
    return gen_try_catch_all(ctx, st, rnd)
  }

  // catch_ref with empty payload produces non-null exnref
  // We use nullable outer block since fallthrough can only produce ref.null
  // (non-null exnref from catch is subtype of nullable)
  let exnref_nullable = RefTypeValType(
    HeapTypeRefType(true, AbsHeapTypeHeapType(ExnAbsHeapType)),
  )
  let outer_bt = ValTypeBlockType(exnref_nullable)
  let try_body = gen_simple_try_body(rnd, st.env)
  let catch_clause = CatchRef(tag_idx, LabelIdx(0))
  let try_table = TryTable(EmptyBlockType, [catch_clause], try_body)

  // Fallthrough: produce null exnref
  let fallthrough = RefNull(AbsHeapTypeHeapType(ExnAbsHeapType))
  let block_ins = Block(outer_bt, [try_table, fallthrough])
  match block_ins.typecheck(st) {
    Ok(st2) => Ok((ctx.dec_fuel(4), st2, [block_ins]))
    Err(e) => Err(e)
  }
}

///|
fn gen_simple_try_body(
  rnd : @quickcheck/splitmix.RandomState,
  env : Env,
) -> Array[Instruction] {
  let body : Array[Instruction] = []

  // Sometimes just nop
  if rnd.next_uint() % 3 == 0 {
    body.push(Nop)
    return body
  }

  // Sometimes throw
  if env.tags.length() > 0 && rnd.next_uint() % 2 == 0 {
    let tag_idx = TagIdx(
      rnd.next_uint() % env.tags.length().reinterpret_as_uint(),
    )
    let payload = tag_payload_types(env, tag_idx)

    // Push values for throw payload
    for p in payload {
      match p {
        NumTypeValType(I32NumType) => body.push(I32Const(I32(rnd.next_int())))
        NumTypeValType(I64NumType) => body.push(I64Const(I64(rnd.next_int64())))
        NumTypeValType(F32NumType) => body.push(F32Const(F32(rnd.next_float())))
        NumTypeValType(F64NumType) =>
          body.push(F64Const(F64(rnd.next_double())))
        VecTypeValType =>
          body.push(
            V128Const(
              0b0, 0b0, 0b0, 0b0, 0b0, 0b0, 0b0, 0b0, 0b0, 0b0, 0b0, 0b0, 0b0, 0b0,
              0b0, 0b0,
            ),
          )
        RefTypeValType(rt) =>
          if rt.is_nullable() {
            body.push(RefNull(rt.get_heap_type()))
          } else {
            // Can't easily produce non-null ref, skip throw
            body.push(Nop)
            return body
          }
        BotValType => ()
      }
    }
    body.push(Throw(tag_idx))
  } else {
    body.push(Nop)
  }
  body
}

///|
fn gen_fallthrough_values(
  rnd : @quickcheck/splitmix.RandomState,
  types : Array[ValType],
) -> Result[Array[Instruction], String] {
  let out : Array[Instruction] = []
  for vt in types {
    match vt {
      NumTypeValType(I32NumType) => out.push(I32Const(I32(rnd.next_int())))
      NumTypeValType(I64NumType) => out.push(I64Const(I64(rnd.next_int64())))
      NumTypeValType(F32NumType) => out.push(F32Const(F32(rnd.next_float())))
      NumTypeValType(F64NumType) => out.push(F64Const(F64(rnd.next_double())))
      VecTypeValType =>
        out.push(
          V128Const(
            0b0, 0b0, 0b0, 0b0, 0b0, 0b0, 0b0, 0b0, 0b0, 0b0, 0b0, 0b0, 0b0, 0b0,
            0b0, 0b0,
          ),
        )
      RefTypeValType(rt) =>
        if rt.is_nullable() {
          out.push(RefNull(rt.get_heap_type()))
        } else {
          return Err("cannot produce non-null ref for fallthrough")
        }
      BotValType => return Err("cannot produce bot value")
    }
  }
  Ok(out)
}

///|
fn tag_payload_types(env : Env, tag : TagIdx) -> Array[ValType] {
  let TagType(tidx) = env.tags[tag.0.reinterpret_as_int()]
  match env.resolve_functype(tidx) {
    Some(FuncType(params, _)) => params
    None => []
  }
}

///|
pub fn gen_expr_valid_with_blocks(
  ctx : GenCtx,
  st0 : TcState,
  want : Array[ValType],
) -> Result[Expr, String] {
  let mut ctx = ctx
  let mut st = st0
  let insns : Array[Instruction] = []

  // Keep some fuel for finishing
  while ctx.fuel > 15 {
    // Occasionally decide to finish early
    if ctx.rnd.next_uint() % 10 == 0 {
      break
    }

    // Occasionally try to generate a try_table block
    if ctx.rnd.next_uint() % 20 == 0 && st.env.tags.length() > 0 {
      match gen_try_table_robust(ctx, st) {
        Ok((ctx2, st2, block_insns)) => {
          for ins in block_insns {
            insns.push(ins)
          }
          ctx = ctx2
          st = st2
          continue
        }
        Err(_) => ()
      }
    }
    let mut accepted = false

    // Try multiple candidates; accept the first that typechecks
    for _ in 0..<50 {
      let cand = gen_candidate_instruction(ctx, st)
      match cand.typecheck(st) {
        Ok(st2) => {
          insns.push(cand)
          st = st2
          ctx = ctx.dec_fuel(1)
          accepted = true
          break
        }
        Err(_) => ()
      }
    }
    if not(accepted) {
      break
    }
    if not(st.reachable) {
      break
    }
  }

  // Finish with required results + return
  let (ctx2, _st2, fin) = match emit_finish_return(ctx, st, want) {
    Ok(x) => x
    Err(e) => return Err(e)
  }
  ctx = ctx2
  for i in fin {
    insns.push(i)
  }
  Ok(Expr(insns))
}

///|
pub fn gen_module_valid_full(ctx0 : GenCtx) -> Result[(GenCtx, Module), String] {
  // 1) Generate TypeSec
  let (ctx1, typesec) = match gen_typesec_valid(ctx0) {
    Ok(x) => x
    Err(e) => return Err(e)
  }

  // 2) Build env with typesec
  let env1 = match validate_typesec(Some(typesec), empty_env()) {
    Ok(e) => e
    Err(e) => return Err(e)
  }
  let ctx2 = GenCtx::{ rnd: ctx1.rnd, fuel: ctx1.fuel, env: env1 }

  // 3) Generate ImportSec (before FuncSec - imports come first)
  let (ctx3, importsec, env2) = match gen_importsec_valid(ctx2, ctx2.env) {
    Ok(x) => x
    Err(e) => return Err(e)
  }
  let ctx3 = GenCtx::{ rnd: ctx3.rnd, fuel: ctx3.fuel, env: env2 }

  // 4) Choose functype TypeIdxs for FuncSec
  let choices = collect_functype_typeidxs(ctx3.env)
  if choices.length() == 0 {
    return Err("gen_module_valid: no function types available")
  }
  let func_count = (ctx3.rnd.next_uint() % 3 + 1).reinterpret_as_int()
  let func_tidxs : Array[TypeIdx] = []
  for _ in 0..<func_count {
    let pick = (ctx3.rnd.next_uint() % choices.length().reinterpret_as_uint()).reinterpret_as_int()
    func_tidxs.push(choices[pick])
  }
  let funcsec = FuncSec(func_tidxs)

  // 5) Extend env.funcs
  let env3 = match validate_funcsec(Some(funcsec), ctx3.env) {
    Ok(e) => e
    Err(e) => return Err(e)
  }
  let ctx4 = GenCtx::{ rnd: ctx3.rnd, fuel: ctx3.fuel, env: env3 }

  // 6) Generate TableSec
  let (ctx5, tablesec, env4) = match gen_tablesec_valid(ctx4, ctx4.env) {
    Ok(x) => x
    Err(e) => return Err(e)
  }
  let ctx5 = GenCtx::{ rnd: ctx5.rnd, fuel: ctx5.fuel, env: env4 }

  // 7) Generate MemSec
  let (ctx6, memsec, env5) = match gen_memsec_valid(ctx5, ctx5.env) {
    Ok(x) => x
    Err(e) => return Err(e)
  }
  let ctx6 = GenCtx::{ rnd: ctx6.rnd, fuel: ctx6.fuel, env: env5 }

  // 8) Generate TagSec
  let (ctx7, tagsec, env6) = match gen_tagsec_valid(ctx6, ctx6.env) {
    Ok(x) => x
    Err(e) => return Err(e)
  }
  let ctx7 = GenCtx::{ rnd: ctx7.rnd, fuel: ctx7.fuel, env: env6 }

  // 9) Generate GlobalSec
  let (ctx8, globalsec, env7) = match gen_globalsec_valid(ctx7, ctx7.env) {
    Ok(x) => x
    Err(e) => return Err(e)
  }
  let ctx8 = GenCtx::{ rnd: ctx8.rnd, fuel: ctx8.fuel, env: env7 }

  // 10) Generate ExportSec
  let (ctx9, exportsec) = match gen_exportsec_valid(ctx8, ctx8.env) {
    Ok(x) => x
    Err(e) => return Err(e)
  }

  // 11) Generate StartSec
  let (ctx10, startsec) = match gen_startsec_valid(ctx9, ctx8.env) {
    Ok(x) => x
    Err(e) => return Err(e)
  }

  // 12) Generate ElemSec
  let (ctx11, elemsec, env8) = match gen_elemsec_valid(ctx10, ctx8.env) {
    Ok(x) => x
    Err(e) => return Err(e)
  }
  let ctx11 = GenCtx::{ rnd: ctx11.rnd, fuel: ctx11.fuel, env: env8 }

  // 13) Generate DataSec
  let (ctx12, datasec, env9) = match gen_datasec_valid(ctx11, ctx11.env) {
    Ok(x) => x
    Err(e) => return Err(e)
  }
  let ctx12 = GenCtx::{ rnd: ctx12.rnd, fuel: ctx12.fuel, env: env9 }

  // 14) Generate DataCntSec
  let DataSec(data_arr) = datasec
  let datacntsec = DataCntSec(U32(data_arr.length().reinterpret_as_uint()))

  // 15) Generate function bodies for CodeSec
  let code_funcs : Array[Func] = []
  let FuncSec(tidxs2) = funcsec
  for tidx in tidxs2 {
    let ft = match ctx12.env.resolve_functype(tidx) {
      Some(x) => x
      None => return Err("gen_module_valid: FuncSec typeidx not a functype")
    }
    let locals_decls = gen_locals_decls(ctx12.rnd, 3)
    let env_body = env_for_func_body(ctx12.env, ft, locals_decls)
    let st0 = TcState::{ env: env_body, stack: [], reachable: true }
    let FuncType(_, results) = ft
    // Use the new expression generator with blocks
    let expr = match gen_expr_valid_with_blocks(ctx12, st0, results) {
      Ok(e) => e
      Err(e) => return Err(e)
    }
    code_funcs.push(Func(locals_decls, expr))
  }
  let codesec = CodeSec(code_funcs)

  // 16) Assemble module
  let m = Module(
    [], // customs
    Some(typesec),
    importsec,
    Some(funcsec),
    Some(tablesec),
    Some(memsec),
    tagsec,
    globalsec,
    exportsec,
    startsec,
    Some(elemsec),
    Some(datacntsec),
    Some(codesec),
    Some(datasec),
  )
  Ok((ctx3, m))
}

///|
test "Sanity check" {
  let ctx = gen_ctx_new(1000)
  let (_, mod) = gen_module_valid(ctx).unwrap()
  validate_module(mod).unwrap()
  let encoded = @buffer.new()
  mod.encode(encoded).unwrap()
  let result = Module::decode(encoded.to_bytes(), 0)
  let _ = result.unwrap()
  // assert_eq(mod, m2, msg="Modules not equal")
}
