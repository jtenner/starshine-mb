///|
struct GenValidContext {
  rnd : RandomState
}

///|
fn GenValidContext::new(rnd : RandomState) -> GenValidContext {
  { rnd, }
}

///|
fn GenValidContext::random_int(self : GenValidContext, max : Int) -> Int {
  if max <= 0 {
    0
  } else {
    (self.rnd.next_int().reinterpret_as_uint() % max.reinterpret_as_uint()).reinterpret_as_int()
  }
}

///|
fn GenValidContext::random_bool(self : GenValidContext) -> Bool {
  self.random_int(2) == 0
}

///|
pub fn gen_valid_valtype(ctx : GenValidContext) -> ValType {
  match ctx.random_int(4) {
    0 => ValType::i32()
    1 => ValType::i64()
    2 => ValType::f32()
    _ => ValType::f64()
  }
}

///|
pub fn gen_valid_numtype(ctx : GenValidContext) -> NumType {
  match ctx.random_int(4) {
    0 => NumType::i32()
    1 => NumType::i64()
    2 => NumType::f32()
    _ => NumType::f64()
  }
}

///|
fn gen_const_expr(ctx : GenValidContext, vt : ValType) -> Expr {
  Expr::new([gen_const_instr(ctx, vt)])
}

///|
fn gen_const_instr(ctx : GenValidContext, vt : ValType) -> Instruction {
  match vt {
    NumTypeValType(I32NumType) =>
      Instruction::i32_const(I32(ctx.random_int(1000)))
    NumTypeValType(I64NumType) =>
      Instruction::i64_const(I64(ctx.random_int(1000).to_int64()))
    NumTypeValType(F32NumType) =>
      Instruction::f32_const(
        F32(Float::from_double(ctx.random_int(100).to_double())),
      )
    NumTypeValType(F64NumType) =>
      Instruction::f64_const(F64(ctx.random_int(100).to_double()))
    VecTypeValType =>
      Instruction::v128_const(
        b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
        b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
      )
    RefTypeValType(rt) => Instruction::ref_null(rt.get_heap_type())
    BotValType => Instruction::unreachable_()
  }
}

///|
fn gen_result_types(ctx : GenValidContext) -> Array[ValType] {
  if ctx.random_bool() {
    []
  } else {
    [gen_valid_valtype(ctx)]
  }
}

///|
fn gen_param_types(ctx : GenValidContext) -> Array[ValType] {
  let count = ctx.random_int(3)
  let params : Array[ValType] = []
  for _ in 0..<count {
    params.push(gen_valid_valtype(ctx))
  }
  params
}

///|
fn gen_local_types(ctx : GenValidContext) -> Array[ValType] {
  let count = ctx.random_int(4)
  let locals : Array[ValType] = []
  for _ in 0..<count {
    locals.push(gen_valid_valtype(ctx))
  }
  locals
}

///|
fn gen_all_local_types(
  params : Array[ValType],
  locals : Array[ValType],
) -> Array[ValType] {
  let out = params.copy()
  for local_ty in locals {
    out.push(local_ty)
  }
  out
}

///|
fn gen_matching_local_idx(
  local_types : Array[ValType],
  vt : ValType,
) -> LocalIdx? {
  for i = 0; i < local_types.length(); i = i + 1 {
    if local_types[i] == vt {
      return Some(LocalIdx::new(i.reinterpret_as_uint()))
    }
  }
  None
}

///|
fn append_value_instrs(
  out : Array[Instruction],
  ctx : GenValidContext,
  vt : ValType,
  local_types : Array[ValType],
  prefer_local? : Bool = true,
) -> Unit {
  if prefer_local {
    match gen_matching_local_idx(local_types, vt) {
      Some(idx) => {
        out.push(Instruction::local_get(idx))
        return
      }
      None => ()
    }
  }
  out.push(gen_const_instr(ctx, vt))
}

///|
fn append_void_stmt(
  out : Array[Instruction],
  ctx : GenValidContext,
  local_types : Array[ValType],
  globals : Array[GlobalType],
) -> Unit {
  match ctx.random_int(6) {
    0 => out.push(Instruction::nop())
    1 => {
      let vt = gen_valid_valtype(ctx)
      append_value_instrs(out, ctx, vt, local_types, prefer_local=false)
      out.push(Instruction::drop())
    }
    2 =>
      if local_types.is_empty() {
        out.push(Instruction::nop())
      } else {
        let idx = ctx.random_int(local_types.length())
        let vt = local_types[idx]
        append_value_instrs(out, ctx, vt, local_types, prefer_local=false)
        out.push(
          Instruction::local_set(LocalIdx::new(idx.reinterpret_as_uint())),
        )
      }
    3 =>
      if local_types.is_empty() {
        out.push(Instruction::nop())
      } else {
        let idx = ctx.random_int(local_types.length())
        let vt = local_types[idx]
        append_value_instrs(out, ctx, vt, local_types, prefer_local=false)
        out.push(
          Instruction::local_tee(LocalIdx::new(idx.reinterpret_as_uint())),
        )
        out.push(Instruction::drop())
      }
    4 => {
      out.push(
        Instruction::i32_const(I32(if ctx.random_bool() { 1 } else { 0 })),
      )
      out.push(
        Instruction::if_(
          BlockType::void_(),
          [Instruction::nop()],
          Some([Instruction::nop()]),
        ),
      )
    }
    _ =>
      if globals.is_empty() {
        out.push(
          Instruction::block(
            BlockType::void_(),
            Expr::new([Instruction::nop()]),
          ),
        )
      } else {
        let idx = ctx.random_int(globals.length())
        out.push(
          Instruction::global_get(GlobalIdx::new(idx.reinterpret_as_uint())),
        )
        out.push(Instruction::drop())
      }
  }
}

///|
pub fn gen_valid_tfunc(
  ctx : GenValidContext,
  accepts : Array[ValType],
  returns : Array[ValType],
) -> Func {
  let locals = gen_local_types(ctx)
  let all_local_types = gen_all_local_types(accepts, locals)
  let body_instrs : Array[Instruction] = []
  let stmt_count = 1 + ctx.random_int(5)
  for _ in 0..<stmt_count {
    append_void_stmt(body_instrs, ctx, all_local_types, [])
  }
  for ret in returns {
    append_value_instrs(body_instrs, ctx, ret, all_local_types)
  }
  Func::new(Locals::from_types(locals), Expr::new(body_instrs))
}

///|
pub fn gen_valid_module(rnd : RandomState) -> Module {
  let ctx = GenValidContext::new(rnd)
  let type_defs : Array[RecType] = []
  let func_type_idxs : Array[TypeIdx] = []
  let funcs : Array[Func] = []
  let globals : Array[Global] = []
  let global_count = ctx.random_int(3)
  for _ in 0..<global_count {
    let vt = gen_valid_valtype(ctx)
    globals.push(
      Global::new(GlobalType::new(vt, false), gen_const_expr(ctx, vt)),
    )
  }
  let func_count = 1 + ctx.random_int(4)
  for i = 0; i < func_count; i = i + 1 {
    let params = gen_param_types(ctx)
    let results = gen_result_types(ctx)
    type_defs.push(
      RecType::new(SubType::comp_type(CompType::func(params, results))),
    )
    func_type_idxs.push(TypeIdx::new(i.reinterpret_as_uint()))
    let local_types = gen_local_types(ctx)
    let all_local_types = gen_all_local_types(params, local_types)
    let body_instrs : Array[Instruction] = []
    let stmt_count = 1 + ctx.random_int(6)
    for _ in 0..<stmt_count {
      append_void_stmt(
        body_instrs,
        ctx,
        all_local_types,
        globals.map(fn(g) {
          let Global(gt, _) = g
          gt
        }),
      )
    }
    for ret in results {
      append_value_instrs(body_instrs, ctx, ret, all_local_types)
    }
    funcs.push(
      Func::new(Locals::from_types(local_types), Expr::new(body_instrs)),
    )
  }
  let mod = Module::new()
    .with_type_sec(TypeSec::new(type_defs))
    .with_func_sec(FuncSec::new(func_type_idxs))
    .with_code_sec(CodeSec::new(funcs))
  let mod = if globals.is_empty() {
    mod
  } else {
    mod.with_global_sec(GlobalSec::new(globals))
  }
  mod.with_export_sec(
    ExportSec::new([
      Export::new(Name::new("main"), ExternIdx::func(FuncIdx::new(0))),
    ]),
  )
}
