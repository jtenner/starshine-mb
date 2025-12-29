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
pub fn gen_ctx_new(fuel : Int) -> GenCtx {
  GenCtx::{ rnd: @quickcheck/splitmix.new(), fuel, env: empty_env() }
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
fn gen_candidate_instruction(ctx : GenCtx, st : TcState) -> Instruction {
  let choice = (ctx.rnd.next_uint() % 10).reinterpret_as_int()
  match choice {
    0 => Nop
    1 => Drop
    2 => I32Const(I32(ctx.rnd.next_int()))
    3 => I64Const(I64(ctx.rnd.next_int64()))
    4 => F32Const(F32(ctx.rnd.next_float()))
    5 => F64Const(F64(ctx.rnd.next_double()))
    6 =>
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
    7 =>
      // local.get if possible, else nop
      if st.env.locals.length() == 0 {
        Nop
      } else {
        let i = ctx.rnd.next_uint() %
          st.env.locals.length().reinterpret_as_uint()
        LocalGet(LocalIdx(i))
      }
    8 =>
      // global.get if possible, else nop
      if st.env.globals.length() == 0 {
        Nop
      } else {
        let i = ctx.rnd.next_uint() %
          st.env.globals.length().reinterpret_as_uint()
        GlobalGet(GlobalIdx(i))
      }
    _ =>
      // i32.add as a common consumer
      I32Add
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
pub fn gen_module_valid(ctx0 : GenCtx) -> Result[(GenCtx, Module), String] {
  // 1) Generate a valid TypeSec (guaranteed GC defaultable types + some functypes)
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

  // 3) Choose a few functype TypeIdxs for FuncSec
  let choices = collect_functype_typeidxs(ctx2.env)
  if choices.length() == 0 {
    return Err("gen_module_valid: no function types available")
  }
  let func_count = (ctx2.rnd.next_uint() % 3 + 1).reinterpret_as_int() // 1..3
  let func_tidxs : Array[TypeIdx] = []
  for _ in 0..<func_count {
    let pick = (ctx2.rnd.next_uint() % choices.length().reinterpret_as_uint()).reinterpret_as_int()
    func_tidxs.push(choices[pick])
  }
  let funcsec = FuncSec(func_tidxs)

  // 4) Extend env.funcs according to FuncSec (no imports in this MVP)
  let env2 = match validate_funcsec(Some(funcsec), ctx2.env) {
    Ok(e) => e
    Err(e) => return Err(e)
  }
  let ctx3 = GenCtx::{ rnd: ctx2.rnd, fuel: ctx2.fuel, env: env2 }

  // 5) Generate function bodies for CodeSec, one per FuncSec entry
  let code_funcs : Array[Func] = []
  let FuncSec(tidxs2) = funcsec
  for tidx in tidxs2 {
    let ft = match ctx3.env.resolve_functype(tidx) {
      Some(x) => x
      None => return Err("gen_module_valid: FuncSec typeidx not a functype")
    }

    // locals decls (defaultable)
    let locals_decls = gen_locals_decls(ctx3.rnd, 3)

    // typecheck/generate under per-function env
    let env_body = env_for_func_body(ctx3.env, ft, locals_decls)
    let st0 = TcState::{ env: env_body, stack: [], reachable: true }
    let FuncType(_, results) = ft
    let expr = match gen_expr_valid(ctx3, st0, results) {
      Ok(e) => e
      Err(e) => return Err(e)
    }
    code_funcs.push(Func(locals_decls, expr))
  }
  let codesec = CodeSec(code_funcs)

  // 6) Assemble module (everything else None/empty for MVP)
  // Custom sections empty; only types + func + code
  let m = Module(
    [],
    Some(typesec),
    None,
    Some(funcsec),
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    Some(codesec),
    None,
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
  println(mod)
  println(result)
  let (m2, _) = result.unwrap()
  // assert_eq(mod, m2, msg="Modules not equal")
}
