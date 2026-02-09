///|
priv struct I64LModuleInfo {
  old_func_types : Map[FuncIdx, FuncType]
  old_type_func_types : Map[TypeIdx, FuncType]
  i64_global_hi : Map[GlobalIdx, GlobalIdx]
  return_high_global : GlobalIdx
  default_mem_is_i64 : Bool
  needs_scratch_memory : Array[Bool]
}

///|
priv struct I64LFuncCtx {
  info : I64LModuleInfo
  low_map : Array[LocalIdx]
  high_map : Array[LocalIdx?]
  stash_local : LocalIdx
  next_local : Array[Int]
  extra_locals : Array[ValType]
  old_result_is_i64 : Bool
}

///|
fn i64l_is_i64(vt : ValType) -> Bool {
  match vt {
    NumTypeValType(I64NumType) => true
    _ => false
  }
}

///|
fn i64l_lower_valtype(vt : ValType) -> Array[ValType] {
  if i64l_is_i64(vt) {
    [ValType::i32(), ValType::i32()]
  } else {
    [vt]
  }
}

///|
fn i64l_lower_params(params : Array[ValType]) -> Array[ValType] {
  let out : Array[ValType] = []
  for vt in params {
    for lowered in i64l_lower_valtype(vt) {
      out.push(lowered)
    }
  }
  out
}

///|
fn i64l_lower_results(
  results : Array[ValType],
) -> Result[Array[ValType], String] {
  let mut has_i64 = false
  for vt in results {
    if i64l_is_i64(vt) {
      has_i64 = true
      break
    }
  }
  if !has_i64 {
    return Ok(results)
  }
  if results.length() == 1 && i64l_is_i64(results[0]) {
    return Ok([ValType::i32()])
  }
  Err("i64_to_i32_lowering: multi-value i64 results are not supported")
}

///|
fn i64l_lower_func_type(ft : FuncType) -> Result[FuncType, String] {
  let FuncType(params, results) = ft
  let lowered_results = match i64l_lower_results(results) {
    Ok(rs) => rs
    Err(e) => return Err(e)
  }
  Ok(FuncType::new(i64l_lower_params(params), lowered_results))
}

///|
fn i64l_count_imported_globals(mod : Module) -> UInt {
  let mut n : UInt = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, GlobalExternType(_)) => n += 1
          _ => ()
        }
      }
    None => ()
  }
  n
}

///|
fn i64l_count_imported_funcs(mod : Module) -> UInt {
  let mut n : UInt = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, FuncExternType(_)) => n += 1
          _ => ()
        }
      }
    None => ()
  }
  n
}

///|
fn i64l_first_memory_limits(mod : Module) -> Limits? {
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, MemExternType(MemType(limits))) => return Some(limits)
          _ => ()
        }
      }
    None => ()
  }
  match mod.mem_sec {
    Some(MemSec(mems)) =>
      match mems {
        [MemType(limits), ..] => Some(limits)
        _ => None
      }
    None => None
  }
}

///|
fn i64l_has_any_memory(mod : Module) -> Bool {
  match i64l_first_memory_limits(mod) {
    Some(_) => true
    None => false
  }
}

///|
fn i64l_default_mem_is_i64(mod : Module) -> Bool {
  match i64l_first_memory_limits(mod) {
    Some(I64Limits(_, _)) => true
    _ => false
  }
}

///|
fn i64l_ensure_scratch_memory(mod : Module, needed : Bool) -> Module {
  if !needed || i64l_has_any_memory(mod) {
    return mod
  }
  mod.with_mem_sec(MemSec::new([MemType::new(Limits::i32(1, None))]))
}

///|
fn i64l_collect_old_type_func_types(mod : Module) -> Map[TypeIdx, FuncType] {
  let out : Map[TypeIdx, FuncType] = Map::new()
  let mut next : UInt = 0
  match mod.type_sec {
    Some(TypeSec(recs)) =>
      for rec in recs {
        match rec {
          SingleRecType(st) => {
            match st.get_comptype() {
              FuncCompType(params, results) =>
                out[TypeIdx::new(next)] = FuncType::new(params, results)
              _ => ()
            }
            next += 1
          }
          GroupRecType(sts) =>
            for st in sts {
              match st.get_comptype() {
                FuncCompType(params, results) =>
                  out[TypeIdx::new(next)] = FuncType::new(params, results)
                _ => ()
              }
              next += 1
            }
        }
      }
    None => ()
  }
  out
}

///|
fn i64l_collect_old_func_types(mod : Module) -> Map[FuncIdx, FuncType] {
  let env = Env::new().with_module(mod)
  let out : Map[FuncIdx, FuncType] = Map::new()
  let imported_funcs = i64l_count_imported_funcs(mod)
  let mut idx : UInt = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, FuncExternType(_)) => {
            let fi = FuncIdx::new(idx)
            match env.get_functype_by_funcidx(fi) {
              Some(ft) => out[fi] = ft
              None => out[fi] = FuncType::new([], [])
            }
            idx += 1
          }
          _ => ()
        }
      }
    None => ()
  }
  match mod.code_sec {
    Some(CodeSec(funcs)) =>
      for i = 0; i < funcs.length(); i = i + 1 {
        let fi = FuncIdx::new(imported_funcs + i.reinterpret_as_uint())
        match env.get_functype_by_funcidx(fi) {
          Some(ft) => out[fi] = ft
          None => out[fi] = FuncType::new([], [])
        }
      }
    None => ()
  }
  out
}

///|
fn i64l_lower_type_sec(mod : Module) -> Result[Module, String] {
  match mod.type_sec {
    None => Ok(mod)
    Some(TypeSec(recs)) => {
      let new_recs : Array[RecType] = []
      for rec in recs {
        match rec {
          SingleRecType(st) => {
            let new_st = match st {
              CompTypeSubType(ct) =>
                match ct {
                  FuncCompType(params, results) =>
                    match i64l_lower_func_type(FuncType::new(params, results)) {
                      Ok(FuncType(new_params, new_results)) =>
                        SubType::comp_type(
                          CompType::func(new_params, new_results),
                        )
                      Err(e) => return Err(e)
                    }
                  _ => st
                }
              SubType(final_, supers, ct) =>
                match ct {
                  FuncCompType(params, results) =>
                    match i64l_lower_func_type(FuncType::new(params, results)) {
                      Ok(FuncType(new_params, new_results)) =>
                        SubType::new(
                          final_,
                          supers,
                          CompType::func(new_params, new_results),
                        )
                      Err(e) => return Err(e)
                    }
                  _ => st
                }
            }
            new_recs.push(RecType::new(new_st))
          }
          GroupRecType(sts) => {
            let lowered_group : Array[SubType] = []
            for st in sts {
              let new_st = match st {
                CompTypeSubType(ct) =>
                  match ct {
                    FuncCompType(params, results) =>
                      match
                        i64l_lower_func_type(FuncType::new(params, results)) {
                        Ok(FuncType(new_params, new_results)) =>
                          SubType::comp_type(
                            CompType::func(new_params, new_results),
                          )
                        Err(e) => return Err(e)
                      }
                    _ => st
                  }
                SubType(final_, supers, ct) =>
                  match ct {
                    FuncCompType(params, results) =>
                      match
                        i64l_lower_func_type(FuncType::new(params, results)) {
                        Ok(FuncType(new_params, new_results)) =>
                          SubType::new(
                            final_,
                            supers,
                            CompType::func(new_params, new_results),
                          )
                        Err(e) => return Err(e)
                      }
                    _ => st
                  }
              }
              lowered_group.push(new_st)
            }
            new_recs.push(RecType::group(lowered_group))
          }
        }
      }
      Ok(mod.with_type_sec(TypeSec::new(new_recs)))
    }
  }
}

///|
fn i64l_split_i64_literal(v : @lib.I64) -> (Int, Int) {
  let @lib.I64(raw) = v
  let u = raw.reinterpret_as_uint64()
  let low = (u & 0xFFFFFFFFL.reinterpret_as_uint64())
    .to_uint()
    .reinterpret_as_int()
  let high = (u >> 32).to_uint().reinterpret_as_int()
  (low, high)
}

///|
fn i64l_make_block_void(instrs : Array[TInstr]) -> TInstr {
  TInstr::block(BlockType::void_(), TExpr::new(instrs))
}

///|
fn i64l_make_block_i32(instrs : Array[TInstr]) -> TInstr {
  TInstr::block(BlockType::val_type(ValType::i32()), TExpr::new(instrs))
}

///|
fn i64l_min_align_4(align : @lib.U32) -> @lib.U32 {
  let @lib.U32(a) = align
  if a > 4 {
    @lib.U32(4)
  } else {
    @lib.U32(a)
  }
}

///|
fn i64l_lower_i64_load_op(op : LoadOp) -> (LoadOp, Bool)? {
  // (low_op, sign_extend_high_from_low)
  match op {
    I64LoadOp => Some((LoadOp::i32_load(), false))
    I64Load8SOp => Some((LoadOp::i32_load8s(), true))
    I64Load8UOp => Some((LoadOp::i32_load8u(), false))
    I64Load16SOp => Some((LoadOp::i32_load16s(), true))
    I64Load16UOp => Some((LoadOp::i32_load16u(), false))
    I64Load32SOp => Some((LoadOp::i32_load(), true))
    I64Load32UOp => Some((LoadOp::i32_load(), false))
    _ => None
  }
}

///|
fn i64l_type_is_i64_block(bt : BlockType) -> Bool {
  match bt {
    ValTypeBlockType(vt) => i64l_is_i64(vt)
    _ => false
  }
}

///|
fn i64l_local_to_int(idx : LocalIdx) -> Int {
  let LocalIdx(i) = idx
  i.reinterpret_as_int()
}

///|
fn i64l_alloc_temp(ctx : I64LFuncCtx, ty : ValType) -> LocalIdx {
  let idx = ctx.next_local[0]
  ctx.next_local[0] = idx + 1
  ctx.extra_locals.push(ty)
  LocalIdx::new(idx.reinterpret_as_uint())
}

///|
fn i64l_stash_set(ctx : I64LFuncCtx, value : TInstr) -> TInstr {
  TInstr::local_set(ctx.stash_local, value)
}

///|
fn i64l_stash_get(ctx : I64LFuncCtx) -> TInstr {
  TInstr::local_get(ctx.stash_local)
}

///|
fn i64l_pack_i64(ctx : I64LFuncCtx, low : TInstr, high : TInstr) -> TInstr {
  let low_tmp = i64l_alloc_temp(ctx, ValType::i32())
  i64l_make_block_i32([
    TInstr::local_set(low_tmp, low),
    i64l_stash_set(ctx, high),
    TInstr::local_get(low_tmp),
  ])
}

///|
fn i64l_mem_zero_ptr(ctx : I64LFuncCtx) -> TInstr {
  if ctx.info.default_mem_is_i64 {
    TInstr::i64_const(I64(0L))
  } else {
    TInstr::i32_const(I32(0))
  }
}

///|
fn i64l_old_instr_is_i64(ctx : I64LFuncCtx, instr : TInstr) -> Bool {
  match instr {
    TI64Const(_) => true
    TLocalGet(idx) =>
      match ctx.high_map[i64l_local_to_int(idx)] {
        Some(_) => true
        None => false
      }
    TLocalTee(idx, _) =>
      match ctx.high_map[i64l_local_to_int(idx)] {
        Some(_) => true
        None => false
      }
    TGlobalGet(idx) =>
      match ctx.info.i64_global_hi.get(idx) {
        Some(_) => true
        None => false
      }
    TLoad(op, _, _) =>
      match op {
        I64LoadOp
        | I64Load8SOp
        | I64Load8UOp
        | I64Load16SOp
        | I64Load16UOp
        | I64Load32SOp
        | I64Load32UOp => true
        _ => false
      }
    TCall(target, _) =>
      match ctx.info.old_func_types.get(target) {
        Some(ft) => i64l_is_i64_result(ft)
        None => false
      }
    TCallIndirect(type_idx, _, _, _) | TCallRef(type_idx, _, _) =>
      match ctx.info.old_type_func_types.get(type_idx) {
        Some(ft) => i64l_is_i64_result(ft)
        None => false
      }
    TUnary(op, _) =>
      match op {
        I64ClzOp
        | I64CtzOp
        | I64PopcntOp
        | I64ExtendI32SOp
        | I64ExtendI32UOp
        | I64TruncF32SOp
        | I64TruncF32UOp
        | I64TruncF64SOp
        | I64TruncF64UOp
        | I64ReinterpretF64Op
        | I64Extend8SOp
        | I64Extend16SOp
        | I64Extend32SOp
        | I64TruncSatF32SOp
        | I64TruncSatF32UOp
        | I64TruncSatF64SOp
        | I64TruncSatF64UOp => true
        _ => false
      }
    TBinary(op, _, _) =>
      match op {
        I64AddOp
        | I64SubOp
        | I64MulOp
        | I64DivSOp
        | I64DivUOp
        | I64RemSOp
        | I64RemUOp
        | I64AndOp
        | I64OrOp
        | I64XorOp
        | I64ShlOp
        | I64ShrSOp
        | I64ShrUOp
        | I64RotlOp
        | I64RotrOp => true
        _ => false
      }
    TSelect(Some([vt]), _, _, _) => i64l_is_i64(vt)
    TSelect(None, _, if_true, _) => i64l_old_instr_is_i64(ctx, if_true)
    TBlock(bt, _) | TLoop(bt, _) | TIf(bt, _, _, _) | TTryTable(bt, _, _) =>
      i64l_type_is_i64_block(bt)
    _ => false
  }
}

///|
fn i64l_capture_i64_operand(
  ctx : I64LFuncCtx,
  lowered_low : TInstr,
) -> (Array[TInstr], LocalIdx, LocalIdx) {
  let low_tmp = i64l_alloc_temp(ctx, ValType::i32())
  let high_tmp = i64l_alloc_temp(ctx, ValType::i32())
  (
    [
      TInstr::local_set(low_tmp, lowered_low),
      TInstr::local_set(high_tmp, i64l_stash_get(ctx)),
    ],
    low_tmp,
    high_tmp,
  )
}

///|
fn i64l_lower_call_args(
  args : Array[TInstr],
  params : Array[ValType],
  ctx : I64LFuncCtx,
) -> Result[Array[TInstr], String] {
  if args.length() != params.length() {
    return Err("i64_to_i32_lowering: call arg/param length mismatch")
  }
  let out : Array[TInstr] = []
  for i = 0; i < args.length(); i = i + 1 {
    let arg = args[i]
    let param = params[i]
    if i64l_is_i64(param) {
      out.push(arg)
      out.push(i64l_stash_get(ctx))
    } else {
      out.push(arg)
    }
  }
  Ok(out)
}

///|
fn i64l_is_i64_result(ft : FuncType) -> Bool {
  let FuncType(_, results) = ft
  results.length() == 1 && i64l_is_i64(results[0])
}

///|
fn i64l_rewrite_tinstruction(
  transformer : ModuleTransformer[I64LFuncCtx],
  ctx : I64LFuncCtx,
  instr : TInstr,
) -> TransformerResult[I64LFuncCtx, TInstr] {
  let walked = match transformer.walk_tinstruction_default(ctx, instr) {
    Ok(Some((next_ctx, next_instr))) => (next_ctx, next_instr)
    Ok(None) => (ctx, instr)
    Err(e) => return Err(e)
  }
  let (ctx, curr) = walked
  let rewritten = match curr {
    TI64Const(value) => {
      let (low, high) = i64l_split_i64_literal(value)
      i64l_pack_i64(
        ctx,
        TInstr::i32_const(I32(low)),
        TInstr::i32_const(I32(high)),
      )
    }
    TLocalGet(old_idx) => {
      let i = i64l_local_to_int(old_idx)
      let low_idx = ctx.low_map[i]
      match ctx.high_map[i] {
        Some(high_idx) =>
          i64l_make_block_i32([
            i64l_stash_set(ctx, TInstr::local_get(high_idx)),
            TInstr::local_get(low_idx),
          ])
        None =>
          if low_idx == old_idx {
            curr
          } else {
            TInstr::local_get(low_idx)
          }
      }
    }
    TLocalSet(old_idx, value) => {
      let i = i64l_local_to_int(old_idx)
      let low_idx = ctx.low_map[i]
      match ctx.high_map[i] {
        Some(high_idx) =>
          i64l_make_block_void([
            TInstr::local_set(low_idx, value),
            TInstr::local_set(high_idx, i64l_stash_get(ctx)),
          ])
        None =>
          if low_idx == old_idx {
            curr
          } else {
            TInstr::local_set(low_idx, value)
          }
      }
    }
    TLocalTee(old_idx, value) => {
      let i = i64l_local_to_int(old_idx)
      let low_idx = ctx.low_map[i]
      match ctx.high_map[i] {
        Some(high_idx) => {
          let tee_tmp = i64l_alloc_temp(ctx, ValType::i32())
          i64l_make_block_i32([
            TInstr::local_set(tee_tmp, TInstr::local_tee(low_idx, value)),
            TInstr::local_set(high_idx, i64l_stash_get(ctx)),
            TInstr::local_get(tee_tmp),
          ])
        }
        None =>
          if low_idx == old_idx {
            curr
          } else {
            TInstr::local_tee(low_idx, value)
          }
      }
    }
    TGlobalGet(idx) =>
      match ctx.info.i64_global_hi.get(idx) {
        Some(hi_idx) =>
          i64l_make_block_i32([
            i64l_stash_set(ctx, TInstr::global_get(hi_idx)),
            TInstr::global_get(idx),
          ])
        None => curr
      }
    TGlobalSet(idx, value) =>
      match ctx.info.i64_global_hi.get(idx) {
        Some(hi_idx) =>
          i64l_make_block_void([
            TInstr::global_set(idx, value),
            TInstr::global_set(hi_idx, i64l_stash_get(ctx)),
          ])
        None => curr
      }
    TCall(target, args) =>
      match ctx.info.old_func_types.get(target) {
        Some(ft) => {
          let FuncType(params, _) = ft
          let lowered_args = match i64l_lower_call_args(args, params, ctx) {
            Ok(a) => a
            Err(e) => return Err(e)
          }
          let call = TInstr::call(target, lowered_args)
          if i64l_is_i64_result(ft) {
            let low_tmp = i64l_alloc_temp(ctx, ValType::i32())
            i64l_make_block_i32([
              TInstr::local_set(low_tmp, call),
              i64l_stash_set(
                ctx,
                TInstr::global_get(ctx.info.return_high_global),
              ),
              TInstr::local_get(low_tmp),
            ])
          } else {
            call
          }
        }
        None =>
          return Err("i64_to_i32_lowering: missing function signature for call")
      }
    TCallIndirect(type_idx, table_idx, args, target) =>
      match ctx.info.old_type_func_types.get(type_idx) {
        Some(ft) => {
          let FuncType(params, _) = ft
          let lowered_args = match i64l_lower_call_args(args, params, ctx) {
            Ok(a) => a
            Err(e) => return Err(e)
          }
          let call = TInstr::call_indirect(
            type_idx, table_idx, lowered_args, target,
          )
          if i64l_is_i64_result(ft) {
            let low_tmp = i64l_alloc_temp(ctx, ValType::i32())
            i64l_make_block_i32([
              TInstr::local_set(low_tmp, call),
              i64l_stash_set(
                ctx,
                TInstr::global_get(ctx.info.return_high_global),
              ),
              TInstr::local_get(low_tmp),
            ])
          } else {
            call
          }
        }
        None =>
          return Err("i64_to_i32_lowering: missing indirect call signature")
      }
    TCallRef(type_idx, args, ref_) =>
      match ctx.info.old_type_func_types.get(type_idx) {
        Some(ft) => {
          let FuncType(params, _) = ft
          let lowered_args = match i64l_lower_call_args(args, params, ctx) {
            Ok(a) => a
            Err(e) => return Err(e)
          }
          let call = TInstr::call_ref(type_idx, lowered_args, ref_)
          if i64l_is_i64_result(ft) {
            let low_tmp = i64l_alloc_temp(ctx, ValType::i32())
            i64l_make_block_i32([
              TInstr::local_set(low_tmp, call),
              i64l_stash_set(
                ctx,
                TInstr::global_get(ctx.info.return_high_global),
              ),
              TInstr::local_get(low_tmp),
            ])
          } else {
            call
          }
        }
        None => return Err("i64_to_i32_lowering: missing call_ref signature")
      }
    TReturnCall(target, args) =>
      match ctx.info.old_func_types.get(target) {
        Some(ft) => {
          if i64l_is_i64_result(ft) {
            return Err(
              "i64_to_i32_lowering: return_call with i64 result is unsupported",
            )
          }
          let FuncType(params, _) = ft
          let lowered_args = match i64l_lower_call_args(args, params, ctx) {
            Ok(a) => a
            Err(e) => return Err(e)
          }
          TInstr::return_call(target, lowered_args)
        }
        None => return Err("i64_to_i32_lowering: missing return_call signature")
      }
    TReturnCallIndirect(type_idx, table_idx, args, target) =>
      match ctx.info.old_type_func_types.get(type_idx) {
        Some(ft) => {
          if i64l_is_i64_result(ft) {
            return Err(
              "i64_to_i32_lowering: return_call_indirect with i64 result is unsupported",
            )
          }
          let FuncType(params, _) = ft
          let lowered_args = match i64l_lower_call_args(args, params, ctx) {
            Ok(a) => a
            Err(e) => return Err(e)
          }
          TInstr::return_call_indirect(
            type_idx, table_idx, lowered_args, target,
          )
        }
        None =>
          return Err(
            "i64_to_i32_lowering: missing return_call_indirect signature",
          )
      }
    TReturnCallRef(type_idx, args, ref_) =>
      match ctx.info.old_type_func_types.get(type_idx) {
        Some(ft) => {
          if i64l_is_i64_result(ft) {
            return Err(
              "i64_to_i32_lowering: return_call_ref with i64 result is unsupported",
            )
          }
          let FuncType(params, _) = ft
          let lowered_args = match i64l_lower_call_args(args, params, ctx) {
            Ok(a) => a
            Err(e) => return Err(e)
          }
          TInstr::return_call_ref(type_idx, lowered_args, ref_)
        }
        None =>
          return Err("i64_to_i32_lowering: missing return_call_ref signature")
      }
    TLoad(op, memarg, ptr) =>
      match i64l_lower_i64_load_op(op) {
        Some((low_op, sign_high)) => {
          let MemArg(align, memidx, offset_raw) = memarg
          let @lib.U64(offset) = offset_raw
          let ptr_tmp = i64l_alloc_temp(ctx, ValType::i32())
          let low_tmp = i64l_alloc_temp(ctx, ValType::i32())
          let high_expr = match op {
            I64LoadOp =>
              TInstr::load(
                LoadOp::i32_load(),
                MemArg::new(
                  i64l_min_align_4(align),
                  memidx,
                  @lib.U64(offset + 4),
                ),
                TInstr::local_get(ptr_tmp),
              )
            _ =>
              if sign_high {
                TInstr::binary(
                  BinaryOp::i32_shr_s(),
                  TInstr::local_get(low_tmp),
                  TInstr::i32_const(I32(31)),
                )
              } else {
                TInstr::i32_const(I32(0))
              }
          }
          i64l_make_block_i32([
            TInstr::local_set(ptr_tmp, ptr),
            TInstr::local_set(
              low_tmp,
              TInstr::load(
                low_op,
                MemArg::new(i64l_min_align_4(align), memidx, @lib.U64(offset)),
                TInstr::local_get(ptr_tmp),
              ),
            ),
            i64l_stash_set(ctx, high_expr),
            TInstr::local_get(low_tmp),
          ])
        }
        None => curr
      }
    TStore(store_op, memarg, ptr, value) =>
      match store_op {
        I64StoreOp => {
          let MemArg(align, memidx, offset_raw) = memarg
          let @lib.U64(offset) = offset_raw
          let ptr_tmp = i64l_alloc_temp(ctx, ValType::i32())
          i64l_make_block_void([
            TInstr::local_set(ptr_tmp, ptr),
            TInstr::store(
              StoreOp::i32_store(),
              MemArg::new(i64l_min_align_4(align), memidx, @lib.U64(offset)),
              TInstr::local_get(ptr_tmp),
              value,
            ),
            TInstr::store(
              StoreOp::i32_store(),
              MemArg::new(i64l_min_align_4(align), memidx, @lib.U64(offset + 4)),
              TInstr::local_get(ptr_tmp),
              i64l_stash_get(ctx),
            ),
          ])
        }
        I64Store32Op => TInstr::store(StoreOp::i32_store(), memarg, ptr, value)
        I64Store16Op =>
          TInstr::store(StoreOp::i32_store16(), memarg, ptr, value)
        I64Store8Op => TInstr::store(StoreOp::i32_store8(), memarg, ptr, value)
        _ => curr
      }
    TUnary(op, value) =>
      match op {
        I64EqzOp =>
          TInstr::unary(
            UnaryOp::i32_eqz(),
            TInstr::binary(BinaryOp::i32_or(), value, i64l_stash_get(ctx)),
          )
        I64ExtendI32UOp => i64l_pack_i64(ctx, value, TInstr::i32_const(I32(0)))
        I64ExtendI32SOp => {
          let low_tmp = i64l_alloc_temp(ctx, ValType::i32())
          i64l_make_block_i32([
            TInstr::local_set(low_tmp, value),
            i64l_stash_set(
              ctx,
              TInstr::binary(
                BinaryOp::i32_shr_s(),
                TInstr::local_get(low_tmp),
                TInstr::i32_const(I32(31)),
              ),
            ),
            TInstr::local_get(low_tmp),
          ])
        }
        I32WrapI64Op => value
        I64Extend8SOp => {
          let low = TInstr::unary(UnaryOp::i32_extend8s(), value)
          i64l_pack_i64(
            ctx,
            low,
            TInstr::binary(
              BinaryOp::i32_shr_s(),
              low,
              TInstr::i32_const(I32(31)),
            ),
          )
        }
        I64Extend16SOp => {
          let low = TInstr::unary(UnaryOp::i32_extend16s(), value)
          i64l_pack_i64(
            ctx,
            low,
            TInstr::binary(
              BinaryOp::i32_shr_s(),
              low,
              TInstr::i32_const(I32(31)),
            ),
          )
        }
        I64Extend32SOp =>
          i64l_pack_i64(
            ctx,
            value,
            TInstr::binary(
              BinaryOp::i32_shr_s(),
              value,
              TInstr::i32_const(I32(31)),
            ),
          )
        I64ClzOp => {
          let low_tmp = i64l_alloc_temp(ctx, ValType::i32())
          let high_tmp = i64l_alloc_temp(ctx, ValType::i32())
          i64l_make_block_i32([
            TInstr::local_set(low_tmp, value),
            TInstr::local_set(high_tmp, i64l_stash_get(ctx)),
            TInstr::if_(
              BlockType::val_type(ValType::i32()),
              TInstr::binary(
                BinaryOp::i32_eq(),
                TInstr::local_get(high_tmp),
                TInstr::i32_const(I32(0)),
              ),
              TExpr::new([
                TInstr::binary(
                  BinaryOp::i32_add(),
                  TInstr::unary(UnaryOp::i32_clz(), TInstr::local_get(low_tmp)),
                  TInstr::i32_const(I32(32)),
                ),
              ]),
              Some(
                TExpr::new([
                  TInstr::unary(UnaryOp::i32_clz(), TInstr::local_get(high_tmp)),
                ]),
              ),
            ),
          ])
        }
        I64CtzOp =>
          return Err("i64_to_i32_lowering: unsupported i64 op i64.ctz")
        I64PopcntOp =>
          return Err("i64_to_i32_lowering: unsupported i64 op i64.popcnt")
        I64TruncF32SOp | I64TruncF32UOp | I64TruncF64SOp | I64TruncF64UOp => {
          let is_f32 = match op {
            I64TruncF32SOp | I64TruncF32UOp => true
            _ => false
          }
          let tmp_ty = if is_f32 { ValType::f32() } else { ValType::f64() }
          let f_tmp = i64l_alloc_temp(ctx, tmp_ty)
          let trunc_u = if is_f32 {
            UnaryOp::i32_trunc_f32u()
          } else {
            UnaryOp::i32_trunc_f64u()
          }
          let convert_u = if is_f32 {
            UnaryOp::f32_convert_i32u()
          } else {
            UnaryOp::f64_convert_i32u()
          }
          let abs_op = if is_f32 {
            UnaryOp::f32_abs()
          } else {
            UnaryOp::f64_abs()
          }
          let floor_op = if is_f32 {
            UnaryOp::f32_floor()
          } else {
            UnaryOp::f64_floor()
          }
          let ceil_op = if is_f32 {
            UnaryOp::f32_ceil()
          } else {
            UnaryOp::f64_ceil()
          }
          let ge_op = if is_f32 {
            BinaryOp::f32_ge()
          } else {
            BinaryOp::f64_ge()
          }
          let gt_op = if is_f32 {
            BinaryOp::f32_gt()
          } else {
            BinaryOp::f64_gt()
          }
          let min_op = if is_f32 {
            BinaryOp::f32_min()
          } else {
            BinaryOp::f64_min()
          }
          let div_op = if is_f32 {
            BinaryOp::f32_div()
          } else {
            BinaryOp::f64_div()
          }
          let sub_op = if is_f32 {
            BinaryOp::f32_sub()
          } else {
            BinaryOp::f64_sub()
          }
          let lit_zero = if is_f32 {
            TInstr::f32_const(F32(0.0))
          } else {
            TInstr::f64_const(F64(0.0))
          }
          let lit_one = if is_f32 {
            TInstr::f32_const(F32(1.0))
          } else {
            TInstr::f64_const(F64(1.0))
          }
          let u32_max = if is_f32 {
            TInstr::f32_const(F32(4294967296.0))
          } else {
            TInstr::f64_const(F64(4294967296.0))
          }
          let u32_max_minus_one = if is_f32 {
            TInstr::f32_const(F32(4294967295.0))
          } else {
            TInstr::f64_const(F64(4294967295.0))
          }
          let f_get = TInstr::local_get(f_tmp)
          let gt_zero_branch = TInstr::binary(
            min_op,
            TInstr::unary(floor_op, TInstr::binary(div_op, f_get, u32_max)),
            u32_max_minus_one,
          )
          let lt_zero_branch = TInstr::unary(
            ceil_op,
            TInstr::binary(
              div_op,
              TInstr::binary(
                sub_op,
                TInstr::local_get(f_tmp),
                TInstr::unary(
                  convert_u,
                  TInstr::unary(trunc_u, TInstr::local_get(f_tmp)),
                ),
              ),
              if is_f32 {
                TInstr::f32_const(F32(4294967296.0))
              } else {
                TInstr::f64_const(F64(4294967296.0))
              },
            ),
          )
          let high_calc = TInstr::if_(
            BlockType::val_type(ValType::i32()),
            TInstr::binary(gt_op, TInstr::local_get(f_tmp), lit_zero),
            TExpr::new([TInstr::unary(trunc_u, gt_zero_branch)]),
            Some(TExpr::new([TInstr::unary(trunc_u, lt_zero_branch)])),
          )
          let high_val = TInstr::if_(
            BlockType::val_type(ValType::i32()),
            TInstr::binary(
              ge_op,
              TInstr::unary(abs_op, TInstr::local_get(f_tmp)),
              lit_one,
            ),
            TExpr::new([high_calc]),
            Some(TExpr::new([TInstr::i32_const(I32(0))])),
          )
          i64l_make_block_i32([
            TInstr::local_set(f_tmp, value),
            i64l_stash_set(ctx, high_val),
            TInstr::unary(trunc_u, TInstr::local_get(f_tmp)),
          ])
        }
        I64ReinterpretF64Op => {
          ctx.info.needs_scratch_memory[0] = true
          let low_tmp = i64l_alloc_temp(ctx, ValType::i32())
          let high_tmp = i64l_alloc_temp(ctx, ValType::i32())
          i64l_make_block_i32([
            TInstr::store(
              StoreOp::f64_store(),
              MemArg::new(U32(8), None, U64(0)),
              i64l_mem_zero_ptr(ctx),
              value,
            ),
            TInstr::local_set(
              low_tmp,
              TInstr::load(
                LoadOp::i32_load(),
                MemArg::new(U32(4), None, U64(0)),
                i64l_mem_zero_ptr(ctx),
              ),
            ),
            TInstr::local_set(
              high_tmp,
              TInstr::load(
                LoadOp::i32_load(),
                MemArg::new(U32(4), None, U64(4)),
                i64l_mem_zero_ptr(ctx),
              ),
            ),
            i64l_stash_set(ctx, TInstr::local_get(high_tmp)),
            TInstr::local_get(low_tmp),
          ])
        }
        F64ReinterpretI64Op => {
          ctx.info.needs_scratch_memory[0] = true
          let low_tmp = i64l_alloc_temp(ctx, ValType::i32())
          let high_tmp = i64l_alloc_temp(ctx, ValType::i32())
          TInstr::block(
            BlockType::val_type(ValType::f64()),
            TExpr::new([
              TInstr::local_set(low_tmp, value),
              TInstr::local_set(high_tmp, i64l_stash_get(ctx)),
              TInstr::store(
                StoreOp::i32_store(),
                MemArg::new(U32(4), None, U64(0)),
                i64l_mem_zero_ptr(ctx),
                TInstr::local_get(low_tmp),
              ),
              TInstr::store(
                StoreOp::i32_store(),
                MemArg::new(U32(4), None, U64(4)),
                i64l_mem_zero_ptr(ctx),
                TInstr::local_get(high_tmp),
              ),
              TInstr::load(
                LoadOp::f64_load(),
                MemArg::new(U32(8), None, U64(0)),
                i64l_mem_zero_ptr(ctx),
              ),
            ]),
          )
        }
        F32ConvertI64SOp
        | F32ConvertI64UOp
        | F64ConvertI64SOp
        | F64ConvertI64UOp => {
          let high_tmp = i64l_alloc_temp(ctx, ValType::i32())
          let low_tmp = i64l_alloc_temp(ctx, ValType::i32())
          let convert_high = match op {
            F32ConvertI64SOp | F64ConvertI64SOp => UnaryOp::f64_convert_i32s()
            _ => UnaryOp::f64_convert_i32u()
          }
          let as_f64 = TInstr::binary(
            BinaryOp::f64_add(),
            TInstr::unary(
              UnaryOp::f64_convert_i32u(),
              TInstr::local_get(low_tmp),
            ),
            TInstr::binary(
              BinaryOp::f64_mul(),
              TInstr::f64_const(F64(4294967296.0)),
              TInstr::unary(convert_high, TInstr::local_get(high_tmp)),
            ),
          )
          let result = match op {
            F32ConvertI64SOp | F32ConvertI64UOp =>
              TInstr::unary(UnaryOp::f32_demote_f64(), as_f64)
            _ => as_f64
          }
          TInstr::block(
            BlockType::val_type(
              match op {
                F32ConvertI64SOp | F32ConvertI64UOp => ValType::f32()
                _ => ValType::f64()
              },
            ),
            TExpr::new([
              TInstr::local_set(low_tmp, value),
              TInstr::local_set(high_tmp, i64l_stash_get(ctx)),
              result,
            ]),
          )
        }
        I64TruncSatF32SOp
        | I64TruncSatF32UOp
        | I64TruncSatF64SOp
        | I64TruncSatF64UOp =>
          return Err("i64_to_i32_lowering: unsupported i64 op i64.trunc_sat_*")
        _ => curr
      }
    TBinary(op, left, right) =>
      match op {
        I64AddOp
        | I64SubOp
        | I64AndOp
        | I64OrOp
        | I64XorOp
        | I64ShlOp
        | I64ShrSOp
        | I64ShrUOp
        | I64EqOp
        | I64NeOp
        | I64LtUOp
        | I64LeUOp
        | I64GtUOp
        | I64GeUOp
        | I64LtSOp
        | I64LeSOp
        | I64GtSOp
        | I64GeSOp => {
          let (left_prefix, left_low, left_high) = i64l_capture_i64_operand(
            ctx, left,
          )
          let (right_prefix, right_low, right_high) = i64l_capture_i64_operand(
            ctx, right,
          )
          let prefix = left_prefix.copy()
          for i in right_prefix {
            prefix.push(i)
          }
          match op {
            I64AddOp => {
              let low_tmp = i64l_alloc_temp(ctx, ValType::i32())
              let high_tmp = i64l_alloc_temp(ctx, ValType::i32())
              let result = prefix.copy()
              result.push(
                TInstr::local_set(
                  low_tmp,
                  TInstr::binary(
                    BinaryOp::i32_add(),
                    TInstr::local_get(left_low),
                    TInstr::local_get(right_low),
                  ),
                ),
              )
              result.push(
                TInstr::local_set(
                  high_tmp,
                  TInstr::binary(
                    BinaryOp::i32_add(),
                    TInstr::local_get(left_high),
                    TInstr::local_get(right_high),
                  ),
                ),
              )
              result.push(
                TInstr::if_(
                  BlockType::void_(),
                  TInstr::binary(
                    BinaryOp::i32_lt_u(),
                    TInstr::local_get(low_tmp),
                    TInstr::local_get(right_low),
                  ),
                  TExpr::new([
                    TInstr::local_set(
                      high_tmp,
                      TInstr::binary(
                        BinaryOp::i32_add(),
                        TInstr::local_get(high_tmp),
                        TInstr::i32_const(I32(1)),
                      ),
                    ),
                  ]),
                  None,
                ),
              )
              result.push(i64l_stash_set(ctx, TInstr::local_get(high_tmp)))
              result.push(TInstr::local_get(low_tmp))
              i64l_make_block_i32(result)
            }
            I64SubOp => {
              let low_tmp = i64l_alloc_temp(ctx, ValType::i32())
              let high_tmp = i64l_alloc_temp(ctx, ValType::i32())
              let borrow_tmp = i64l_alloc_temp(ctx, ValType::i32())
              let result = prefix.copy()
              result.push(
                TInstr::local_set(
                  low_tmp,
                  TInstr::binary(
                    BinaryOp::i32_sub(),
                    TInstr::local_get(left_low),
                    TInstr::local_get(right_low),
                  ),
                ),
              )
              result.push(
                TInstr::local_set(
                  borrow_tmp,
                  TInstr::binary(
                    BinaryOp::i32_lt_u(),
                    TInstr::local_get(left_low),
                    TInstr::local_get(right_low),
                  ),
                ),
              )
              result.push(
                TInstr::local_set(
                  high_tmp,
                  TInstr::binary(
                    BinaryOp::i32_sub(),
                    TInstr::local_get(left_high),
                    TInstr::binary(
                      BinaryOp::i32_add(),
                      TInstr::local_get(right_high),
                      TInstr::local_get(borrow_tmp),
                    ),
                  ),
                ),
              )
              result.push(i64l_stash_set(ctx, TInstr::local_get(high_tmp)))
              result.push(TInstr::local_get(low_tmp))
              i64l_make_block_i32(result)
            }
            I64AndOp | I64OrOp | I64XorOp => {
              let op32 = match op {
                I64AndOp => BinaryOp::i32_and()
                I64OrOp => BinaryOp::i32_or()
                _ => BinaryOp::i32_xor()
              }
              let result = prefix.copy()
              result.push(
                i64l_stash_set(
                  ctx,
                  TInstr::binary(
                    op32,
                    TInstr::local_get(left_high),
                    TInstr::local_get(right_high),
                  ),
                ),
              )
              result.push(
                TInstr::binary(
                  op32,
                  TInstr::local_get(left_low),
                  TInstr::local_get(right_low),
                ),
              )
              i64l_make_block_i32(result)
            }
            I64ShlOp | I64ShrSOp | I64ShrUOp => {
              let shift_tmp = i64l_alloc_temp(ctx, ValType::i32())
              let high_tmp = i64l_alloc_temp(ctx, ValType::i32())
              let low_tmp = i64l_alloc_temp(ctx, ValType::i32())
              let result = prefix.copy()
              result.push(
                TInstr::local_set(
                  shift_tmp,
                  TInstr::binary(
                    BinaryOp::i32_and(),
                    TInstr::local_get(right_low),
                    TInstr::i32_const(I32(63)),
                  ),
                ),
              )
              let small_shift = TInstr::binary(
                BinaryOp::i32_and(),
                TInstr::local_get(shift_tmp),
                TInstr::i32_const(I32(31)),
              )
              let width_minus_shift = TInstr::binary(
                BinaryOp::i32_sub(),
                TInstr::i32_const(I32(32)),
                small_shift,
              )
              let large = TInstr::binary(
                BinaryOp::i32_ge_u(),
                TInstr::local_get(shift_tmp),
                TInstr::i32_const(I32(32)),
              )
              let (large_low, large_high, small_low, small_high) = match op {
                I64ShlOp =>
                  (
                    TInstr::i32_const(I32(0)),
                    TInstr::binary(
                      BinaryOp::i32_shl(),
                      TInstr::local_get(left_low),
                      small_shift,
                    ),
                    TInstr::binary(
                      BinaryOp::i32_shl(),
                      TInstr::local_get(left_low),
                      small_shift,
                    ),
                    TInstr::binary(
                      BinaryOp::i32_or(),
                      TInstr::binary(
                        BinaryOp::i32_shl(),
                        TInstr::local_get(left_high),
                        small_shift,
                      ),
                      TInstr::binary(
                        BinaryOp::i32_and(),
                        TInstr::binary(
                          BinaryOp::i32_shr_u(),
                          TInstr::local_get(left_low),
                          width_minus_shift,
                        ),
                        TInstr::binary(
                          BinaryOp::i32_sub(),
                          TInstr::binary(
                            BinaryOp::i32_shl(),
                            TInstr::i32_const(I32(1)),
                            small_shift,
                          ),
                          TInstr::i32_const(I32(1)),
                        ),
                      ),
                    ),
                  )
                I64ShrSOp =>
                  (
                    TInstr::binary(
                      BinaryOp::i32_shr_s(),
                      TInstr::local_get(left_high),
                      small_shift,
                    ),
                    TInstr::binary(
                      BinaryOp::i32_shr_s(),
                      TInstr::local_get(left_high),
                      TInstr::i32_const(I32(31)),
                    ),
                    TInstr::binary(
                      BinaryOp::i32_or(),
                      TInstr::binary(
                        BinaryOp::i32_shr_u(),
                        TInstr::local_get(left_low),
                        small_shift,
                      ),
                      TInstr::binary(
                        BinaryOp::i32_shl(),
                        TInstr::local_get(left_high),
                        width_minus_shift,
                      ),
                    ),
                    TInstr::binary(
                      BinaryOp::i32_shr_s(),
                      TInstr::local_get(left_high),
                      small_shift,
                    ),
                  )
                _ =>
                  (
                    TInstr::binary(
                      BinaryOp::i32_shr_u(),
                      TInstr::local_get(left_high),
                      small_shift,
                    ),
                    TInstr::i32_const(I32(0)),
                    TInstr::binary(
                      BinaryOp::i32_or(),
                      TInstr::binary(
                        BinaryOp::i32_shr_u(),
                        TInstr::local_get(left_low),
                        small_shift,
                      ),
                      TInstr::binary(
                        BinaryOp::i32_shl(),
                        TInstr::local_get(left_high),
                        width_minus_shift,
                      ),
                    ),
                    TInstr::binary(
                      BinaryOp::i32_shr_u(),
                      TInstr::local_get(left_high),
                      small_shift,
                    ),
                  )
              }
              result.push(
                TInstr::local_set(
                  low_tmp,
                  TInstr::select(None, large, large_low, small_low),
                ),
              )
              result.push(
                TInstr::local_set(
                  high_tmp,
                  TInstr::select(None, large, large_high, small_high),
                ),
              )
              result.push(i64l_stash_set(ctx, TInstr::local_get(high_tmp)))
              result.push(TInstr::local_get(low_tmp))
              i64l_make_block_i32(result)
            }
            I64EqOp | I64NeOp => {
              let is_eq = match op {
                I64EqOp => true
                _ => false
              }
              let cmp_low = TInstr::binary(
                if is_eq {
                  BinaryOp::i32_eq()
                } else {
                  BinaryOp::i32_ne()
                },
                TInstr::local_get(left_low),
                TInstr::local_get(right_low),
              )
              let cmp_high = TInstr::binary(
                if is_eq {
                  BinaryOp::i32_eq()
                } else {
                  BinaryOp::i32_ne()
                },
                TInstr::local_get(left_high),
                TInstr::local_get(right_high),
              )
              let comb = if is_eq {
                BinaryOp::i32_and()
              } else {
                BinaryOp::i32_or()
              }
              let result = prefix.copy()
              result.push(TInstr::binary(comb, cmp_low, cmp_high))
              i64l_make_block_i32(result)
            }
            I64LtUOp | I64LeUOp | I64GtUOp | I64GeUOp => {
              let (high_op, low_op) = match op {
                I64LtUOp => (BinaryOp::i32_lt_u(), BinaryOp::i32_lt_u())
                I64LeUOp => (BinaryOp::i32_lt_u(), BinaryOp::i32_le_u())
                I64GtUOp => (BinaryOp::i32_gt_u(), BinaryOp::i32_gt_u())
                _ => (BinaryOp::i32_gt_u(), BinaryOp::i32_ge_u())
              }
              let comp_high = TInstr::binary(
                high_op,
                TInstr::local_get(left_high),
                TInstr::local_get(right_high),
              )
              let eq_high = TInstr::binary(
                BinaryOp::i32_eq(),
                TInstr::local_get(left_high),
                TInstr::local_get(right_high),
              )
              let comp_low = TInstr::binary(
                low_op,
                TInstr::local_get(left_low),
                TInstr::local_get(right_low),
              )
              let result = prefix.copy()
              result.push(
                TInstr::binary(
                  BinaryOp::i32_or(),
                  comp_high,
                  TInstr::binary(BinaryOp::i32_and(), eq_high, comp_low),
                ),
              )
              i64l_make_block_i32(result)
            }
            _ => {
              let (high_op, low_op) = match op {
                I64LtSOp => (BinaryOp::i32_lt_s(), BinaryOp::i32_lt_u())
                I64LeSOp => (BinaryOp::i32_lt_s(), BinaryOp::i32_le_u())
                I64GtSOp => (BinaryOp::i32_gt_s(), BinaryOp::i32_gt_u())
                _ => (BinaryOp::i32_gt_s(), BinaryOp::i32_ge_u())
              }
              let comp_high = TInstr::binary(
                high_op,
                TInstr::local_get(left_high),
                TInstr::local_get(right_high),
              )
              let eq_high = TInstr::binary(
                BinaryOp::i32_eq(),
                TInstr::local_get(left_high),
                TInstr::local_get(right_high),
              )
              let comp_low = TInstr::binary(
                low_op,
                TInstr::local_get(left_low),
                TInstr::local_get(right_low),
              )
              let result = prefix.copy()
              result.push(
                TInstr::binary(
                  BinaryOp::i32_or(),
                  comp_high,
                  TInstr::binary(BinaryOp::i32_and(), eq_high, comp_low),
                ),
              )
              i64l_make_block_i32(result)
            }
          }
        }
        I64MulOp
        | I64DivSOp
        | I64DivUOp
        | I64RemSOp
        | I64RemUOp
        | I64RotlOp
        | I64RotrOp =>
          return Err(
            "i64_to_i32_lowering: unsupported i64 op unsupported i64 binary op",
          )
        _ => curr
      }
    TSelect(_, cond, if_true, if_false) => {
      let select_is_i64 = match instr {
        TSelect(Some([vt]), _, _, _) => i64l_is_i64(vt)
        TSelect(None, _, old_if_true, _) =>
          i64l_old_instr_is_i64(ctx, old_if_true)
        _ => false
      }
      if !select_is_i64 {
        curr
      } else {
        let cond_tmp = i64l_alloc_temp(ctx, ValType::i32())
        let true_low = i64l_alloc_temp(ctx, ValType::i32())
        let true_high = i64l_alloc_temp(ctx, ValType::i32())
        let false_low = i64l_alloc_temp(ctx, ValType::i32())
        let false_high = i64l_alloc_temp(ctx, ValType::i32())
        i64l_make_block_i32([
          TInstr::local_set(true_low, if_true),
          TInstr::local_set(true_high, i64l_stash_get(ctx)),
          TInstr::local_set(false_low, if_false),
          TInstr::local_set(false_high, i64l_stash_get(ctx)),
          TInstr::local_set(cond_tmp, cond),
          i64l_stash_set(
            ctx,
            TInstr::select(
              None,
              TInstr::local_get(cond_tmp),
              TInstr::local_get(true_high),
              TInstr::local_get(false_high),
            ),
          ),
          TInstr::select(
            None,
            TInstr::local_get(cond_tmp),
            TInstr::local_get(true_low),
            TInstr::local_get(false_low),
          ),
        ])
      }
    }
    TDrop(value) => TInstr::drop(value)
    TReturn(values) =>
      if !ctx.old_result_is_i64 {
        curr
      } else if values.length() == 1 {
        let low_tmp = i64l_alloc_temp(ctx, ValType::i32())
        i64l_make_block_void([
          TInstr::local_set(low_tmp, values[0]),
          TInstr::global_set(ctx.info.return_high_global, i64l_stash_get(ctx)),
          TInstr::return_([TInstr::local_get(low_tmp)]),
        ])
      } else {
        curr
      }
    TBlock(bt, _) | TLoop(bt, _) | TIf(bt, _, _, _) | TTryTable(bt, _, _) =>
      if i64l_type_is_i64_block(bt) {
        return Err(
          "i64_to_i32_lowering: block/loop/if/try with i64 result is unsupported",
        )
      } else {
        curr
      }
    _ => curr
  }
  if rewritten != curr {
    change(ctx, rewritten)
  } else if curr != instr {
    change(ctx, curr)
  } else {
    unchanged()
  }
}

///|
fn i64l_rewrite_one_func(
  func_idx : FuncIdx,
  func : Func,
  info : I64LModuleInfo,
) -> Result[Func, String] {
  let old_ft = match info.old_func_types.get(func_idx) {
    Some(ft) => ft
    None => FuncType::new([], [])
  }
  let FuncType(old_params, old_results) = old_ft
  let old_result_is_i64 = old_results.length() == 1 &&
    i64l_is_i64(old_results[0])
  match func {
    Func(_, _) => Ok(func)
    TFunc(locals, body) => {
      let low_map : Array[LocalIdx] = []
      let high_map : Array[LocalIdx?] = []
      let mut next_abs = 0
      for vt in old_params {
        low_map.push(LocalIdx::new(next_abs.reinterpret_as_uint()))
        if i64l_is_i64(vt) {
          high_map.push(
            Some(LocalIdx::new((next_abs + 1).reinterpret_as_uint())),
          )
          next_abs += 2
        } else {
          high_map.push(None)
          next_abs += 1
        }
      }
      let new_locals_base : Array[ValType] = []
      for vt in locals {
        low_map.push(LocalIdx::new(next_abs.reinterpret_as_uint()))
        if i64l_is_i64(vt) {
          high_map.push(
            Some(LocalIdx::new((next_abs + 1).reinterpret_as_uint())),
          )
          new_locals_base.push(ValType::i32())
          new_locals_base.push(ValType::i32())
          next_abs += 2
        } else {
          high_map.push(None)
          new_locals_base.push(vt)
          next_abs += 1
        }
      }
      let extra_locals : Array[ValType] = []
      let next_local = [next_abs]
      let stash_local = LocalIdx::new(next_abs.reinterpret_as_uint())
      extra_locals.push(ValType::i32())
      next_local[0] = next_abs + 1
      let ctx : I64LFuncCtx = {
        info,
        low_map,
        high_map,
        stash_local,
        next_local,
        extra_locals,
        old_result_is_i64,
      }
      let pass = ModuleTransformer::new().on_tinstruction_evt(
        i64l_rewrite_tinstruction,
      )
      let rewritten_body = match pass.walk_texpr(ctx, body) {
        Ok(Some((_, next_body))) => next_body
        Ok(None) => body
        Err(e) => return Err(e)
      }
      let needs_implicit_return_wrap = if old_result_is_i64 {
        let TExpr(old_instrs) = body
        !old_instrs.is_empty() &&
        i64l_old_instr_is_i64(ctx, old_instrs[old_instrs.length() - 1])
      } else {
        false
      }
      let final_body = if needs_implicit_return_wrap {
        let TExpr(instrs) = rewritten_body
        if instrs.is_empty() {
          rewritten_body
        } else {
          let prefix : Array[TInstr] = []
          for i = 0; i < instrs.length() - 1; i = i + 1 {
            prefix.push(instrs[i])
          }
          let last = instrs[instrs.length() - 1]
          let tmp = LocalIdx::new(next_local[0].reinterpret_as_uint())
          extra_locals.push(ValType::i32())
          next_local[0] = next_local[0] + 1
          prefix.push(
            i64l_make_block_i32([
              TInstr::local_set(tmp, last),
              TInstr::global_set(
                info.return_high_global,
                TInstr::local_get(stash_local),
              ),
              TInstr::local_get(tmp),
            ]),
          )
          TExpr::new(prefix)
        }
      } else {
        rewritten_body
      }
      let final_locals = new_locals_base.copy()
      for ty in extra_locals {
        final_locals.push(ty)
      }
      Ok(Func::t_func(final_locals, final_body))
    }
  }
}

///|
fn i64l_rewrite_globals(
  mod : Module,
) -> Result[(Module, Map[GlobalIdx, GlobalIdx], GlobalIdx), String] {
  let imported_globals = i64l_count_imported_globals(mod)
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, GlobalExternType(GlobalType(vt, _))) =>
            if i64l_is_i64(vt) {
              return Err(
                "i64_to_i32_lowering: imported i64 globals are unsupported",
              )
            }
          _ => ()
        }
      }
    None => ()
  }
  let globals = match mod.global_sec {
    Some(GlobalSec(gs)) => gs
    None => []
  }
  let i64_global_abs : Array[GlobalIdx] = []
  for i = 0; i < globals.length(); i = i + 1 {
    let Global(GlobalType(vt, _), _) = globals[i]
    if i64l_is_i64(vt) {
      i64_global_abs.push(
        GlobalIdx::new(imported_globals + i.reinterpret_as_uint()),
      )
    }
  }
  let hi_map : Map[GlobalIdx, GlobalIdx] = Map::new()
  let first_hi = imported_globals + globals.length().reinterpret_as_uint()
  for i = 0; i < i64_global_abs.length(); i = i + 1 {
    hi_map[i64_global_abs[i]] = GlobalIdx::new(
      first_hi + i.reinterpret_as_uint(),
    )
  }
  let new_globals : Array[Global] = []
  let hi_globals : Array[Global] = []
  for i = 0; i < globals.length(); i = i + 1 {
    let abs_idx = GlobalIdx::new(imported_globals + i.reinterpret_as_uint())
    let Global(GlobalType(vt, is_mut), init) = globals[i]
    if !i64l_is_i64(vt) {
      new_globals.push(globals[i])
      continue
    }
    let root = match to_texpr(init, Env::new().with_module(mod)) {
      Ok(TExpr([x])) => x
      _ => return Err("i64_to_i32_lowering: unsupported i64 global init")
    }
    let (low_init, hi_init) = match root {
      TI64Const(v) => {
        let (low, hi) = i64l_split_i64_literal(v)
        (
          TExpr::new([TInstr::i32_const(I32(low))]).to_expr(),
          TExpr::new([TInstr::i32_const(I32(hi))]).to_expr(),
        )
      }
      TGlobalGet(from_idx) =>
        match hi_map.get(from_idx) {
          Some(from_hi_idx) =>
            (
              TExpr::new([TInstr::global_get(from_idx)]).to_expr(),
              TExpr::new([TInstr::global_get(from_hi_idx)]).to_expr(),
            )
          None =>
            return Err(
              "i64_to_i32_lowering: unsupported i64 global.get init source",
            )
        }
      _ => return Err("i64_to_i32_lowering: unsupported i64 global init root")
    }
    new_globals.push(
      Global::new(GlobalType::new(ValType::i32(), is_mut), low_init),
    )
    hi_globals.push(
      Global::new(GlobalType::new(ValType::i32(), is_mut), hi_init),
    )
    ignore(abs_idx)
  }
  for g in hi_globals {
    new_globals.push(g)
  }
  let return_high_idx = GlobalIdx::new(
    imported_globals + new_globals.length().reinterpret_as_uint(),
  )
  new_globals.push(
    Global::new(
      GlobalType::new(ValType::i32(), true),
      TExpr::new([TInstr::i32_const(I32(0))]).to_expr(),
    ),
  )
  Ok(
    (mod.with_global_sec(GlobalSec::new(new_globals)), hi_map, return_high_idx),
  )
}

///|
pub fn i64_to_i32_lowering(mod : Module) -> Result[Module, String] {
  let old_func_types = i64l_collect_old_func_types(mod)
  let old_type_func_types = i64l_collect_old_type_func_types(mod)
  let mod = match i64l_lower_type_sec(mod) {
    Ok(next_mod) => next_mod
    Err(e) => return Err(e)
  }
  let (mod, hi_map, return_hi) = match i64l_rewrite_globals(mod) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let needs_scratch_memory = [false]
  let info : I64LModuleInfo = {
    old_func_types,
    old_type_func_types,
    i64_global_hi: hi_map,
    return_high_global: return_hi,
    default_mem_is_i64: i64l_default_mem_is_i64(mod),
    needs_scratch_memory,
  }
  let lowered = match mod.code_sec {
    Some(CodeSec(funcs)) => {
      let imported_funcs = i64l_count_imported_funcs(mod)
      let new_funcs : Array[Func] = []
      for i = 0; i < funcs.length(); i = i + 1 {
        let abs_idx = FuncIdx::new(imported_funcs + i.reinterpret_as_uint())
        match i64l_rewrite_one_func(abs_idx, funcs[i], info) {
          Ok(f) => new_funcs.push(f)
          Err(e) => return Err(e)
        }
      }
      mod.with_code_sec(CodeSec::new(new_funcs))
    }
    None => mod
  }
  Ok(i64l_ensure_scratch_memory(lowered, info.needs_scratch_memory[0]))
}

///|
test "i64_to_i32_lowering lowers i64 globals and global.get/global.set" {
  let mod = Module::new()
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::i64(), true),
          Expr::new([Instruction::i64_const(I64(0x1122334455667788L))]),
        ),
      ]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::global_set(
              GlobalIdx::new(0),
              TInstr::global_get(GlobalIdx::new(0)),
            ),
          ]),
        ),
      ]),
    )
  let lowered = match i64_to_i32_lowering(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected i64_to_i32_lowering error: \{e}")
  }
  match lowered.global_sec {
    Some(GlobalSec(globals)) => {
      assert_eq(globals.length(), 3)
      match globals[0] {
        Global(GlobalType(vt, is_mut), _) => {
          assert_true(is_mut)
          assert_eq(vt, ValType::i32())
        }
      }
      match globals[1] {
        Global(GlobalType(vt, is_mut), _) => {
          assert_true(is_mut)
          assert_eq(vt, ValType::i32())
        }
      }
    }
    _ => fail("expected global section")
  }
  match lowered.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TBlock(_, TExpr(instrs))]))])) => {
      assert_eq(instrs.length(), 2)
      match instrs[0] {
        TGlobalSet(GlobalIdx(i), _) => assert_eq(i.reinterpret_as_int(), 0)
        _ => fail("expected low global.set")
      }
      match instrs[1] {
        TGlobalSet(GlobalIdx(i), _) => assert_eq(i.reinterpret_as_int(), 1)
        _ => fail("expected high global.set")
      }
    }
    _ => fail("expected lowered global.set pair")
  }
}

///|
test "i64_to_i32_lowering lowers local i64 get/set and i64.add" {
  let ty = single_rec_type(
    comp_type_sub_type(func_comp_type([ValType::i64()], [ValType::i64()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([ty]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i64()],
          TExpr::new([
            TInstr::local_set(
              LocalIdx::new(1),
              TInstr::binary(
                BinaryOp::i64_add(),
                TInstr::local_get(LocalIdx::new(0)),
                TInstr::i64_const(I64(5L)),
              ),
            ),
            TInstr::local_get(LocalIdx::new(1)),
          ]),
        ),
      ]),
    )
  let lowered = match i64_to_i32_lowering(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected i64_to_i32_lowering error: \{e}")
  }
  match lowered.type_sec {
    Some(
      TypeSec([SingleRecType(CompTypeSubType(FuncCompType(params, results)))])
    ) => {
      assert_eq(params, [ValType::i32(), ValType::i32()])
      assert_eq(results, [ValType::i32()])
    }
    _ => fail("expected lowered function type")
  }
  match lowered.code_sec {
    Some(CodeSec([TFunc(locals, _)])) => {
      // original local i64 split + stash + temps
      assert_true(locals.length() >= 3)
      assert_eq(locals[0], ValType::i32())
      assert_eq(locals[1], ValType::i32())
    }
    _ => fail("expected lowered function")
  }
}

///|
test "i64_to_i32_lowering lowers i64 return through high-bits global" {
  let ty = single_rec_type(
    comp_type_sub_type(func_comp_type([], [ValType::i64()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([ty]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([Func::t_func([], TExpr::new([TInstr::i64_const(I64(9L))]))]),
    )
  let lowered = match i64_to_i32_lowering(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected i64_to_i32_lowering error: \{e}")
  }
  match lowered.type_sec {
    Some(TypeSec([SingleRecType(CompTypeSubType(FuncCompType(_, results)))])) =>
      assert_eq(results, [ValType::i32()])
    _ => fail("expected lowered return type")
  }
  match lowered.global_sec {
    Some(GlobalSec(globals)) => {
      assert_true(globals.length() >= 1)
      match globals[globals.length() - 1] {
        Global(GlobalType(vt, is_mut), _) => {
          assert_true(is_mut)
          assert_eq(vt, ValType::i32())
        }
      }
    }
    _ => fail("expected return-high global")
  }
}

///|
test "i64_to_i32_lowering lowers call i64 args and results" {
  let t_callee = single_rec_type(
    comp_type_sub_type(func_comp_type([ValType::i64()], [ValType::i64()])),
  )
  let t_caller = single_rec_type(
    comp_type_sub_type(func_comp_type([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_callee, t_caller]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i64()],
          TExpr::new([TInstr::local_get(LocalIdx::new(0))]),
        ),
        Func::t_func(
          [],
          TExpr::new([
            TInstr::call(FuncIdx::new(0), [TInstr::i64_const(I64(7L))]),
          ]),
        ),
      ]),
    )
  let lowered = match i64_to_i32_lowering(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected i64_to_i32_lowering error: \{e}")
  }
  match lowered.type_sec {
    Some(TypeSec(recs)) =>
      match recs[0] {
        SingleRecType(CompTypeSubType(FuncCompType(params, results))) => {
          assert_eq(params, [ValType::i32(), ValType::i32()])
          assert_eq(results, [ValType::i32()])
        }
        _ => fail("expected lowered callee type")
      }
    _ => fail("expected type section")
  }
  match lowered.code_sec {
    Some(CodeSec([_, TFunc(_, TExpr([TBlock(_, TExpr(instrs))]))])) => {
      let mut saw_call = false
      for instr in instrs {
        match instr {
          TLocalSet(_, TCall(FuncIdx(i), args)) => {
            assert_eq(i.reinterpret_as_int(), 0)
            assert_eq(args.length(), 2)
            saw_call = true
          }
          _ => ()
        }
      }
      assert_true(saw_call)
    }
    _ => fail("expected lowered call sequence")
  }
}

///|
test "i64_to_i32_lowering lowers i64 load and store" {
  let body = TExpr::new([
    TInstr::store(
      StoreOp::i64_store(),
      MemArg::new(U32(8), None, U64(0)),
      TInstr::i32_const(I32(0)),
      TInstr::i64_const(I64(42L)),
    ),
    TInstr::load(
      LoadOp::i64_load(),
      MemArg::new(U32(8), None, U64(0)),
      TInstr::i32_const(I32(0)),
    ),
  ])
  let mod = Module::new().with_code_sec(CodeSec::new([Func::t_func([], body)]))
  let lowered = match i64_to_i32_lowering(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected i64_to_i32_lowering error: \{e}")
  }
  match lowered.code_sec {
    Some(CodeSec([TFunc(_, TExpr(instrs))])) => {
      assert_true(instrs.length() == 2)
      match instrs[0] {
        TBlock(_, TExpr(seq)) => {
          let mut stores = 0
          for s in seq {
            match s {
              TStore(I32StoreOp, _, _, _) => stores += 1
              _ => ()
            }
          }
          assert_eq(stores, 2)
        }
        _ => fail("expected lowered i64.store block")
      }
      match instrs[1] {
        TBlock(_, TExpr(_)) => ()
        _ => fail("expected lowered i64.load block")
      }
    }
    _ => fail("expected lowered load/store function")
  }
}

///|
test "i64_to_i32_lowering lowers typed i64 select" {
  let body = TExpr::new([
    TInstr::select(
      Some([ValType::i64()]),
      TInstr::i32_const(I32(1)),
      TInstr::i64_const(I64(10L)),
      TInstr::i64_const(I64(20L)),
    ),
  ])
  let mod = Module::new().with_code_sec(CodeSec::new([Func::t_func([], body)]))
  let lowered = match i64_to_i32_lowering(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected i64_to_i32_lowering error: \{e}")
  }
  match lowered.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TBlock(_, TExpr(seq))]))])) => {
      let mut saw_stash = false
      let mut saw_select = false
      for instr in seq {
        match instr {
          TLocalSet(_, TSelect(_, _, _, _)) => saw_select = true
          TLocalSet(_, TLocalGet(_)) => saw_stash = true
          _ => ()
        }
      }
      assert_true(saw_select)
      assert_true(saw_stash)
    }
    _ => fail("expected lowered i64 select block")
  }
}

///|
test "i64_to_i32_lowering lowers untyped i64 select" {
  let body = TExpr::new([
    TInstr::select(
      None,
      TInstr::i32_const(I32(1)),
      TInstr::i64_const(I64(10L)),
      TInstr::i64_const(I64(20L)),
    ),
  ])
  let mod = Module::new().with_code_sec(CodeSec::new([Func::t_func([], body)]))
  let lowered = match i64_to_i32_lowering(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected i64_to_i32_lowering error: \{e}")
  }
  match lowered.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TBlock(_, _)]))])) => ()
    _ => fail("expected untyped i64 select to lower to block form")
  }
}

///|
test "i64_to_i32_lowering lowers i64 trunc and convert ops" {
  let body = TExpr::new([
    TInstr::drop(
      TInstr::unary(UnaryOp::i64_trunc_f64u(), TInstr::f64_const(F64(5.5))),
    ),
    TInstr::drop(
      TInstr::unary(UnaryOp::f32_convert_i64u(), TInstr::i64_const(I64(9L))),
    ),
    TInstr::drop(
      TInstr::unary(UnaryOp::f64_convert_i64s(), TInstr::i64_const(I64(-3L))),
    ),
  ])
  let mod = Module::new().with_code_sec(CodeSec::new([Func::t_func([], body)]))
  let lowered = match i64_to_i32_lowering(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected i64_to_i32_lowering error: \{e}")
  }
  let shown = "\{lowered}"
  assert_false(shown.contains("I64TruncF64UOp"))
  assert_false(shown.contains("F32ConvertI64UOp"))
  assert_false(shown.contains("F64ConvertI64SOp"))
}

///|
test "i64_to_i32_lowering lowers reinterpret ops and adds memory if needed" {
  let body = TExpr::new([
    TInstr::drop(
      TInstr::unary(
        UnaryOp::i64_reinterpret_f64(),
        TInstr::f64_const(F64(1.25)),
      ),
    ),
    TInstr::drop(
      TInstr::unary(UnaryOp::f64_reinterpret_i64(), TInstr::i64_const(I64(77L))),
    ),
  ])
  let mod = Module::new().with_code_sec(CodeSec::new([Func::t_func([], body)]))
  let lowered = match i64_to_i32_lowering(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected i64_to_i32_lowering error: \{e}")
  }
  match lowered.mem_sec {
    Some(MemSec(mems)) => assert_true(mems.length() >= 1)
    None => fail("expected memory section for reinterpret scratch lowering")
  }
  let shown = "\{lowered}"
  assert_false(shown.contains("I64ReinterpretF64Op"))
  assert_false(shown.contains("F64ReinterpretI64Op"))
}

///|
test "i64_to_i32_lowering lowers call_ref i64 args and results" {
  let t_callee = single_rec_type(
    comp_type_sub_type(func_comp_type([ValType::i64()], [ValType::i64()])),
  )
  let t_caller = single_rec_type(
    comp_type_sub_type(func_comp_type([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_callee, t_caller]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i64()],
          TExpr::new([TInstr::local_get(LocalIdx::new(0))]),
        ),
        Func::t_func(
          [],
          TExpr::new([
            TInstr::call_ref(
              TypeIdx::new(0),
              [TInstr::i64_const(I64(7L))],
              TInstr::ref_func(FuncIdx::new(0)),
            ),
          ]),
        ),
      ]),
    )
  let lowered = match i64_to_i32_lowering(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected i64_to_i32_lowering error: \{e}")
  }
  match lowered.code_sec {
    Some(CodeSec([_, TFunc(_, TExpr([TBlock(_, TExpr(instrs))]))])) => {
      let mut saw_call_ref = false
      for instr in instrs {
        match instr {
          TLocalSet(_, TCallRef(TypeIdx(i), args, _)) => {
            assert_eq(i.reinterpret_as_int(), 0)
            assert_eq(args.length(), 2)
            saw_call_ref = true
          }
          _ => ()
        }
      }
      assert_true(saw_call_ref)
    }
    _ => fail("expected lowered call_ref sequence")
  }
}

///|
test "i64_to_i32_lowering preserves explicit i64 return without extra tail wrap" {
  let ty = single_rec_type(
    comp_type_sub_type(func_comp_type([], [ValType::i64()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([ty]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([TInstr::return_([TInstr::i64_const(I64(1L))])]),
        ),
      ]),
    )
  let lowered = match i64_to_i32_lowering(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected i64_to_i32_lowering error: \{e}")
  }
  match lowered.code_sec {
    Some(CodeSec([TFunc(_, TExpr(instrs))])) => assert_eq(instrs.length(), 1)
    _ => fail("expected lowered function")
  }
}

///|
test "i64_to_i32_lowering rejects imported i64 globals" {
  let mod = Module::new().with_import_sec(
    ImportSec::new([
      Import::new(
        Name::new("m"),
        Name::new("g"),
        ExternType::global(GlobalType::new(ValType::i64(), false)),
      ),
    ]),
  )
  match i64_to_i32_lowering(mod) {
    Ok(_) => fail("expected lowering to reject imported i64 globals")
    Err(e) => assert_true(e.contains("imported i64 globals are unsupported"))
  }
}

///|
test "i64_to_i32_lowering rejects unsupported i64 trunc_sat" {
  let body = TExpr::new([
    TInstr::unary(UnaryOp::i64_trunc_sat_f64u(), TInstr::f64_const(F64(1.0))),
  ])
  let mod = Module::new().with_code_sec(CodeSec::new([Func::t_func([], body)]))
  match i64_to_i32_lowering(mod) {
    Ok(_) => fail("expected unsupported i64.trunc_sat to fail")
    Err(e) => assert_true(e.contains("i64.trunc_sat"))
  }
}

///|
test "i64_to_i32_lowering rejects unsupported i64 mul" {
  let body = TExpr::new([
    TInstr::binary(
      BinaryOp::i64_mul(),
      TInstr::i64_const(I64(2L)),
      TInstr::i64_const(I64(3L)),
    ),
  ])
  let mod = Module::new().with_code_sec(CodeSec::new([Func::t_func([], body)]))
  match i64_to_i32_lowering(mod) {
    Ok(_) => fail("expected unsupported i64.mul to fail")
    Err(e) => assert_true(e.contains("unsupported i64 binary op"))
  }
}
