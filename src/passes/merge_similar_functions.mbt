///| 
/// Copyright 2023 WebAssembly Community Group participants
/// 
/// Licensed under the Apache License, Version 2.0 (the "License");
/// you may not use this file except in compliance with the License.
/// You may obtain a copy of the License at
/// 
///     http://www.apache.org/licenses/LICENSE-2.0
/// 
/// Unless required by applicable law or agreed to in writing, software
/// distributed under the License is distributed on an "AS IS" BASIS,
/// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
/// See the License for the specific language governing permissions and
/// limitations under the License.
///

///|
const MSF_MAX_SYNTHETIC_FUNCTION_PARAMS : Int = 16

///|
const MSF_HASH_MAX_INSTRS : Int = 200000

///|
const MSF_HASH_BUDGET_EXCEEDED_ERR : String = "msf_hash_budget_exceeded"

///|
fn msf_trace_noop(_ : String) -> Unit {
  ()
}

///|
fn msf_trace_now_ms() -> UInt64 {
  pass_trace_now_ms()
}

///|
fn msf_trace_elapsed_ms(start_ms : UInt64) -> UInt64 {
  pass_trace_elapsed_ms(start_ms)
}

///|
fn msf_trace_heartbeat_interval() -> Int {
  65536
}

///|
struct MSFHashState {
  mut digest : UInt64
} derive(Show)

///|
struct MSFCallSite {
  node_id : Int
  target : FuncIdx
  arg_count : Int
  is_return : Bool
} derive(Eq, Hash, Show)

///|
enum MSFSiteValue {
  ConstSite(TInstr, ValType)
  CallTargetSite(FuncIdx, TypeIdx, Bool, Int)
} derive(Eq, Hash, Show)

///|
enum MSFParamKey {
  ConstParamKey(ValType, Array[TInstr])
  CallParamKey(TypeIdx, Int, Bool, Array[FuncIdx])
} derive(Eq, Hash)

///|
enum MSFParamKind {
  LiteralParam(ValType, Array[TInstr])
  CallTargetParam(TypeIdx, Int, Bool, Array[FuncIdx])
} derive(Eq, Hash, Show)

///|
struct ParamInfo {
  kind : MSFParamKind
  uses : Array[Int]
} derive(Eq, Hash, Show)

///|
struct EquivalentClass {
  type_idx : TypeIdx
  member_def_idxs : Array[Int]
  primary_def_idx : Int
} derive(Eq, Show)

///|
struct MSFDefinedFunc {
  def_idx : Int
  abs_idx : Int
  type_idx : TypeIdx
  func_type : FuncType
  locals : Array[ValType]
  body : TExpr
  hash : UInt64
} derive(Eq, Show)

///|
struct MSFHashBucketKey {
  type_idx : TypeIdx
  local_count : Int
  hash : UInt64
} derive(Eq, Hash)

///|
fn msf_make_func_type(
  params : Array[ValType],
  results : Array[ValType],
) -> RecType {
  RecType::new(SubType::comp_type(CompType::func(params, results)))
}

///|
fn msf_extract_comp_type(sub_type : SubType) -> CompType {
  match sub_type {
    SubType(_, _, comp) => comp
    CompTypeSubType(comp) => comp
  }
}

///|
fn msf_resolve_func_type(
  comp_types : Array[CompType],
  idx : TypeIdx,
) -> FuncType? {
  let i = match idx {
    TypeIdx(n) => n
    RecIdx(n) => n
  }
  let j = i.reinterpret_as_int()
  if j < 0 || j >= comp_types.length() {
    return None
  }
  match comp_types[j] {
    FuncCompType(params, results) => Some(FuncType::new(params, results))
    _ => None
  }
}

///|
fn msf_count_imported_funcs(mod : Module) -> Int {
  let mut n = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        let Import(_, _, ex) = import_
        match ex {
          FuncExternType(_) => n += 1
          _ => ()
        }
      }
    None => ()
  }
  n
}

///|
fn msf_collect_comp_types(mod : Module) -> Array[CompType] {
  let comp_types : Array[CompType] = []
  match mod.type_sec {
    Some(TypeSec(rec_types)) =>
      for rec_type in rec_types {
        match rec_type {
          SingleRecType(sub_type) =>
            comp_types.push(msf_extract_comp_type(sub_type))
          GroupRecType(sub_types) =>
            for sub_type in sub_types {
              comp_types.push(msf_extract_comp_type(sub_type))
            }
        }
      }
    None => ()
  }
  comp_types
}

///|
fn msf_collect_func_type_indices(mod : Module) -> Array[TypeIdx] {
  let out : Array[TypeIdx] = []
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        let Import(_, _, ex) = import_
        match ex {
          FuncExternType(type_idx) => out.push(type_idx)
          _ => ()
        }
      }
    None => ()
  }
  match mod.func_sec {
    Some(FuncSec(type_idxs)) =>
      for type_idx in type_idxs {
        out.push(type_idx)
      }
    None => ()
  }
  out
}

///|
fn msf_collect_func_types(mod : Module) -> Array[FuncType] {
  let comp_types = msf_collect_comp_types(mod)
  let type_idxs = msf_collect_func_type_indices(mod)
  let out : Array[FuncType] = []
  for type_idx in type_idxs {
    match msf_resolve_func_type(comp_types, type_idx) {
      Some(ft) => out.push(ft)
      None => out.push(FuncType::new([], []))
    }
  }
  out
}

///|
fn msf_local_idx_to_int(idx : LocalIdx) -> Int {
  let LocalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn msf_local_idx_from_int(i : Int) -> LocalIdx {
  LocalIdx::new(i.reinterpret_as_uint())
}

///|
fn msf_func_idx_to_int(idx : FuncIdx) -> Int {
  let FuncIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn msf_func_idx_from_int(i : Int) -> FuncIdx {
  FuncIdx::new(i.reinterpret_as_uint())
}

///|
fn msf_resolve_callee_type_idx(
  target : FuncIdx,
  func_type_idxs : Array[TypeIdx],
) -> Result[TypeIdx, String] {
  let abs_idx = msf_func_idx_to_int(target)
  if abs_idx < 0 || abs_idx >= func_type_idxs.length() {
    return Err(
      "merge_similar_functions: call target out of range for function type lookup",
    )
  }
  Ok(func_type_idxs[abs_idx])
}

///|
fn msf_resolve_func_type_for_type_idx(
  type_idx : TypeIdx,
  func_type_idxs : Array[TypeIdx],
  func_types : Array[FuncType],
) -> FuncType? {
  let limit = if func_type_idxs.length() < func_types.length() {
    func_type_idxs.length()
  } else {
    func_types.length()
  }
  for i = 0; i < limit; i = i + 1 {
    if func_type_idxs[i] == type_idx {
      return Some(func_types[i])
    }
  }
  None
}

///|
fn msf_verify_call_target_type(
  type_idx : TypeIdx,
  expected_arg_count : Int,
  func_types : Array[FuncType],
  func_type_idxs : Array[TypeIdx],
) -> Result[Unit, String] {
  let FuncType(params, _) = match
    msf_resolve_func_type_for_type_idx(type_idx, func_type_idxs, func_types) {
    Some(ft) => ft
    None =>
      return Err(
        "merge_similar_functions: missing function type for rewritten call target",
      )
  }
  if params.length() != expected_arg_count {
    return Err(
      "merge_similar_functions: call target param arity mismatch for rewritten call site",
    )
  }
  Ok(())
}

///|
fn msf_zero_const_like(instr : TInstr) -> TInstr {
  match instr.kind {
    TInstrKind::TI32Const(_) => TInstr::i32_const(I32(0))
    TInstrKind::TI64Const(_) => TInstr::i64_const(I64(0L))
    TInstrKind::TF32Const(_) => TInstr::f32_const(F32(0.0))
    TInstrKind::TF64Const(_) => TInstr::f64_const(F64(0.0))
    TInstrKind::TRefNull(ht) => TInstr::ref_null(ht)
    TInstrKind::TRefFunc(_) => TInstr::ref_func(FuncIdx::new(0))
    TInstrKind::TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
      TInstr::v128_const(
        (0).to_byte(),
        (0).to_byte(),
        (0).to_byte(),
        (0).to_byte(),
        (0).to_byte(),
        (0).to_byte(),
        (0).to_byte(),
        (0).to_byte(),
        (0).to_byte(),
        (0).to_byte(),
        (0).to_byte(),
        (0).to_byte(),
        (0).to_byte(),
        (0).to_byte(),
        (0).to_byte(),
        (0).to_byte(),
      )
    _ => instr
  }
}

///|
fn msf_const_type(instr : TInstr) -> ValType? {
  match instr.kind {
    TInstrKind::TI32Const(_) => Some(ValType::i32())
    TInstrKind::TI64Const(_) => Some(ValType::i64())
    TInstrKind::TF32Const(_) => Some(ValType::f32())
    TInstrKind::TF64Const(_) => Some(ValType::f64())
    TInstrKind::TRefNull(ht) => Some(ValType::ref_type(RefType::new(true, ht)))
    TInstrKind::TRefFunc(_) =>
      Some(
        ValType::ref_type(
          RefType::new(false, HeapType::abs(AbsHeapType::func())),
        ),
      )
    TInstrKind::TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
      Some(ValType::v128())
    _ => None
  }
}

///|
fn msf_tag_hash(instr : TInstr) -> UInt64 {
  let tag : UInt64 = match instr.kind {
    TInstrKind::TI32Const(_) => 1UL
    TInstrKind::TI64Const(_) => 2UL
    TInstrKind::TF32Const(_) => 3UL
    TInstrKind::TF64Const(_) => 4UL
    TInstrKind::TRefNull(_) => 5UL
    TInstrKind::TRefFunc(_) => 6UL
    TInstrKind::TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
      7UL
    TInstrKind::TUnreachable => 8UL
    TInstrKind::TNop => 9UL
    TInstrKind::TLocalGet(_) => 10UL
    TInstrKind::TGlobalGet(_) => 11UL
    TInstrKind::TMemorySize(_) => 12UL
    TInstrKind::TTableSize(_) => 13UL
    TInstrKind::TUnary(_, _) => 14UL
    TInstrKind::TDrop(_) => 15UL
    TInstrKind::TLocalSet(_, _) => 16UL
    TInstrKind::TLocalTee(_, _) => 17UL
    TInstrKind::TGlobalSet(_, _) => 18UL
    TInstrKind::TRefIsNull(_) => 19UL
    TInstrKind::TRefAsNonNull(_) => 20UL
    TInstrKind::TI31GetS(_) => 21UL
    TInstrKind::TI31GetU(_) => 22UL
    TInstrKind::TRefI31(_) => 23UL
    TInstrKind::TArrayLen(_) => 24UL
    TInstrKind::TAnyConvertExtern(_) => 25UL
    TInstrKind::TExternConvertAny(_) => 26UL
    TInstrKind::TThrowRef(_) => 27UL
    TInstrKind::TBinary(_, _, _) => 28UL
    TInstrKind::TRefEq(_, _) => 29UL
    TInstrKind::TStore(_, _, _, _) => 30UL
    TInstrKind::TLoad(_, _, _) => 31UL
    TInstrKind::TMemoryGrow(_, _) => 32UL
    TInstrKind::TMemoryAtomicNotify(_, _, _) => 200UL
    TInstrKind::TMemoryAtomicWait32(_, _, _, _) => 201UL
    TInstrKind::TMemoryAtomicWait64(_, _, _, _) => 202UL
    TInstrKind::TAtomicFence => 203UL
    TInstrKind::TAtomicRmw(_, _, _, _) => 204UL
    TInstrKind::TAtomicCmpxchg(_, _, _, _, _) => 205UL
    TInstrKind::TMemoryFill(_, _, _, _) => 33UL
    TInstrKind::TMemoryCopy(_, _, _, _, _) => 34UL
    TInstrKind::TMemoryInit(_, _, _, _, _) => 35UL
    TInstrKind::TDataDrop(_) => 36UL
    TInstrKind::TTableGet(_, _) => 37UL
    TInstrKind::TTableSet(_, _, _) => 38UL
    TInstrKind::TTableGrow(_, _, _) => 39UL
    TInstrKind::TTableFill(_, _, _, _) => 40UL
    TInstrKind::TTableCopy(_, _, _, _, _) => 41UL
    TInstrKind::TTableInit(_, _, _, _, _) => 42UL
    TInstrKind::TElemDrop(_) => 43UL
    TInstrKind::TCall(_, _) => 44UL
    TInstrKind::TCallIndirect(_, _, _, _) => 45UL
    TInstrKind::TCallRef(_, _, _) => 46UL
    TInstrKind::TReturnCall(_, _) => 47UL
    TInstrKind::TReturnCallIndirect(_, _, _, _) => 48UL
    TInstrKind::TReturnCallRef(_, _, _) => 49UL
    TInstrKind::TBlock(_, _) => 50UL
    TInstrKind::TLoop(_, _) => 51UL
    TInstrKind::TIf(_, _, _, _) => 52UL
    TInstrKind::TTryTable(_, _, _) => 53UL
    TInstrKind::TThrow(_, _) => 54UL
    TInstrKind::TBr(_, _) => 55UL
    TInstrKind::TBrIf(_, _, _) => 56UL
    TInstrKind::TBrTable(_, _, _, _) => 57UL
    TInstrKind::TBrOnNull(_, _, _) => 58UL
    TInstrKind::TBrOnNonNull(_, _, _) => 59UL
    TInstrKind::TBrOnCast(_, _, _, _, _, _) => 60UL
    TInstrKind::TBrOnCastFail(_, _, _, _, _, _) => 61UL
    TInstrKind::TReturn(_) => 62UL
    TInstrKind::TSelect(_, _, _, _) => 63UL
    TInstrKind::TStructNew(_, _) => 64UL
    TInstrKind::TStructNewDefault(_) => 65UL
    TInstrKind::TStructGet(_, _, _) => 66UL
    TInstrKind::TStructGetS(_, _, _) => 67UL
    TInstrKind::TStructGetU(_, _, _) => 68UL
    TInstrKind::TStructSet(_, _, _, _) => 69UL
    TInstrKind::TArrayNew(_, _, _) => 70UL
    TInstrKind::TArrayNewDefault(_, _) => 71UL
    TInstrKind::TArrayNewFixed(_, _) => 72UL
    TInstrKind::TArrayNewData(_, _, _, _) => 73UL
    TInstrKind::TArrayNewElem(_, _, _, _) => 74UL
    TInstrKind::TArrayGet(_, _, _) => 75UL
    TInstrKind::TArrayGetS(_, _, _) => 76UL
    TInstrKind::TArrayGetU(_, _, _) => 77UL
    TInstrKind::TArraySet(_, _, _, _) => 78UL
    TInstrKind::TArrayFill(_, _, _, _, _) => 79UL
    TInstrKind::TArrayCopy(_, _, _, _, _, _, _) => 80UL
    TInstrKind::TArrayInitData(_, _, _, _, _, _) => 81UL
    TInstrKind::TArrayInitElem(_, _, _, _, _, _) => 82UL
    TInstrKind::TRefTest(_, _, _) => 83UL
    TInstrKind::TRefCast(_, _, _) => 84UL
    TInstrKind::TRefGetDesc(_) => 85UL
    TInstrKind::TRefTestDesc(_, _, _) => 86UL
    TInstrKind::TRefCastDescEq(_, _, _) => 87UL
    TInstrKind::TI8x16Splat(_) => 88UL
    TInstrKind::TI16x8Splat(_) => 89UL
    TInstrKind::TI32x4Splat(_) => 90UL
    TInstrKind::TI64x2Splat(_) => 91UL
    TInstrKind::TF32x4Splat(_) => 92UL
    TInstrKind::TF64x2Splat(_) => 93UL
    TInstrKind::TExtractLane(_, _, _) => 94UL
    TInstrKind::TReplaceLane(_, _, _, _) => 95UL
    TInstrKind::TI8x16Shuffle(
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _
    ) => 96UL
    TInstrKind::TI8x16Swizzle(_, _) => 97UL
    TInstrKind::TI8x16RelaxedSwizzle(_, _) => 98UL
    TInstrKind::TV128Shift(_, _, _) => 99UL
    TInstrKind::TV128Ternary(_, _, _, _) => 100UL
    TInstrKind::TV128LoadLane(_, _, _, _, _) => 101UL
    TInstrKind::TV128StoreLane(_, _, _, _, _) => 102UL
  }
  tag * 11400714819323198485UL
}

///|
fn msf_mix_digest(seed : UInt64, x : UInt64) -> UInt64 {
  (seed ^ x) * 1099511628211UL
}

///|
fn msf_hash_fallback(abs_idx : Int, body : TExpr) -> UInt64 {
  if abs_idx >= 0 {
    msf_mix_digest(
      1469598103934665603UL,
      abs_idx.reinterpret_as_uint().to_uint64(),
    )
  } else {
    msf_mix_digest(
      1469598103934665603UL,
      body.instrs.length().reinterpret_as_uint().to_uint64(),
    )
  }
}

///|
fn msf_hash_shallow_ignoring_consts(instr : TInstr) -> UInt64 {
  let canonicalized = match instr.kind {
    TInstrKind::TCall(_, args) => TInstr::call(FuncIdx::new(0), args)
    TInstrKind::TReturnCall(_, args) =>
      TInstr::return_call(FuncIdx::new(0), args)
    _ => msf_zero_const_like(instr)
  }
  msf_mix_digest(
    msf_tag_hash(canonicalized),
    oi_instr_shallow_hash(canonicalized),
  )
}

///|
fn msf_hash_tinstr(state : MSFHashState, instr : TInstr) -> Unit {
  state.digest = msf_mix_digest(
    state.digest,
    msf_hash_shallow_ignoring_consts(instr),
  )
}

///|
fn msf_hash_function_ignoring_consts(
  func : Func,
  trace? : (String) -> Unit = msf_trace_noop,
  trace_all_funcs? : Bool = false,
  ordinal? : Int = 0,
  abs_idx? : Int = -1,
) -> UInt64 {
  let hash_start_ms = msf_trace_now_ms()
  match func {
    TFunc(_, _, body) => {
      let state = { digest: 1469598103934665603UL }
      let mut hashed_instrs = 0
      let walk_start_ms = msf_trace_now_ms()
      if trace_all_funcs {
        trace(
          "func[\{ordinal}] phase=hash:budget:start abs_idx=\{abs_idx} limit=\{MSF_HASH_MAX_INSTRS}",
        )
        trace("func[\{ordinal}] phase=hash:walk:start abs_idx=\{abs_idx}")
      }
      let walker = ModuleTransformer::new().on_tinstruction_evt(fn(
        self,
        _,
        instr : TInstr,
      ) {
        hashed_instrs += 1
        if hashed_instrs > MSF_HASH_MAX_INSTRS {
          return error(MSF_HASH_BUDGET_EXCEEDED_ERR)
        }
        if trace_all_funcs &&
          hashed_instrs % msf_trace_heartbeat_interval() == 0 {
          trace(
            "func[\{ordinal}] phase=hash:walk:progress abs_idx=\{abs_idx} instrs=\{hashed_instrs} elapsed_ms=\{msf_trace_elapsed_ms(walk_start_ms)}",
          )
        }
        msf_hash_tinstr(state, instr)
        from_walk(self.walk_tinstruction_default((), instr))
      })
      match walker.walk_texpr((), body) {
        Ok(_) => {
          if trace_all_funcs {
            trace(
              "func[\{ordinal}] phase=hash:budget:done abs_idx=\{abs_idx} elapsed_ms=\{msf_trace_elapsed_ms(walk_start_ms)} instrs=\{hashed_instrs} exceeded=false",
            )
            trace(
              "func[\{ordinal}] phase=hash:walk:done abs_idx=\{abs_idx} elapsed_ms=\{msf_trace_elapsed_ms(walk_start_ms)} instrs=\{hashed_instrs}",
            )
            trace(
              "func[\{ordinal}] phase=hash:done abs_idx=\{abs_idx} elapsed_ms=\{msf_trace_elapsed_ms(hash_start_ms)} hash=\{state.digest}",
            )
          }
          state.digest
        }
        Err(e) =>
          if e == MSF_HASH_BUDGET_EXCEEDED_ERR {
            let fallback_hash = msf_hash_fallback(abs_idx, body)
            if trace_all_funcs {
              trace(
                "func[\{ordinal}] phase=hash:budget:done abs_idx=\{abs_idx} elapsed_ms=\{msf_trace_elapsed_ms(walk_start_ms)} instrs=\{hashed_instrs} exceeded=true",
              )
              trace(
                "func[\{ordinal}] phase=hash:done abs_idx=\{abs_idx} elapsed_ms=\{msf_trace_elapsed_ms(hash_start_ms)} skipped=true reason=instr_budget limit=\{MSF_HASH_MAX_INSTRS} instrs=\{hashed_instrs} hash=\{fallback_hash}",
              )
            }
            fallback_hash
          } else {
            if trace_all_funcs {
              trace(
                "func[\{ordinal}] phase=hash:budget:error abs_idx=\{abs_idx} elapsed_ms=\{msf_trace_elapsed_ms(walk_start_ms)} \{e}",
              )
            }
            0UL
          }
      }
    }
    _ => {
      if trace_all_funcs {
        trace(
          "func[\{ordinal}] phase=hash:skip abs_idx=\{abs_idx} reason=non_typed_func elapsed_ms=\{msf_trace_elapsed_ms(hash_start_ms)}",
        )
      }
      0UL
    }
  }
}

///|
fn hash_function_ignoring_consts(
  func : Func,
  trace? : (String) -> Unit = msf_trace_noop,
  trace_all_funcs? : Bool = false,
  ordinal? : Int = 0,
  abs_idx? : Int = -1,
) -> UInt64 {
  msf_hash_function_ignoring_consts(
    func,
    trace~,
    trace_all_funcs~,
    ordinal~,
    abs_idx~,
  )
}

///|
fn msf_normalize_body(
  body : TExpr,
  trace? : (String) -> Unit = msf_trace_noop,
  trace_all_funcs? : Bool = false,
  ordinal? : Int = 0,
) -> Result[TExpr, String] {
  let normalize_start_ms = msf_trace_now_ms()
  let mut visited_instrs = 0
  if trace_all_funcs {
    trace(
      "func[\{ordinal}] phase=hash:normalize_internal:start top_instrs=\{body.instrs.length()}",
    )
  }
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr : TInstr) {
    visited_instrs += 1
    if trace_all_funcs && visited_instrs % msf_trace_heartbeat_interval() == 0 {
      trace(
        "func[\{ordinal}] phase=hash:normalize_internal:progress instrs=\{visited_instrs} elapsed_ms=\{msf_trace_elapsed_ms(normalize_start_ms)}",
      )
    }
    let walked = match self.walk_tinstruction_default((), instr) {
      Ok((next, _)) => next
      Err(e) => return error(e)
    }
    let rewritten = match walked.kind {
      TInstrKind::TI32Const(_)
      | TInstrKind::TI64Const(_)
      | TInstrKind::TF32Const(_)
      | TInstrKind::TF64Const(_)
      | TInstrKind::TRefNull(_)
      | TInstrKind::TRefFunc(_)
      | TInstrKind::TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
        msf_zero_const_like(walked)
      TInstrKind::TCall(_, args) => TInstr::call(FuncIdx::new(0), args)
      TInstrKind::TReturnCall(_, args) =>
        TInstr::return_call(FuncIdx::new(0), args)
      _ => walked
    }
    // We already walked children manually; returning unchanged() would trigger a
    // second default walk and skew node-id-based bookkeeping.
    change((), rewritten)
  })
  match walker.walk_texpr((), body) {
    Ok((out, _)) => {
      if trace_all_funcs {
        trace(
          "func[\{ordinal}] phase=hash:normalize_internal:done elapsed_ms=\{msf_trace_elapsed_ms(normalize_start_ms)} instrs=\{visited_instrs} changed=\{out != body}",
        )
      }
      Ok(out)
    }
    Err(e) => {
      if trace_all_funcs {
        trace(
          "func[\{ordinal}] phase=hash:normalize_internal:error elapsed_ms=\{msf_trace_elapsed_ms(normalize_start_ms)} instrs=\{visited_instrs} \{e}",
        )
      }
      Err(e)
    }
  }
}

///|
fn msf_collect_call_sites(body : TExpr) -> Array[MSFCallSite] {
  let out : Array[MSFCallSite] = []
  let mut next_id = 0
let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr : TInstr) {
    let id = next_id
    next_id += 1
    match instr.kind {
      TInstrKind::TCall(target, args) =>
        out.push({
          node_id: id,
          target,
          arg_count: args.length(),
          is_return: false,
        })
      TInstrKind::TReturnCall(target, args) =>
        out.push({
          node_id: id,
          target,
          arg_count: args.length(),
          is_return: true,
        })
      _ => ()
    }
    from_walk(self.walk_tinstruction_default((), instr))
  })
  ignore(walker.walk_texpr((), body))
  out
}

///|
fn msf_collect_sites(
  body : TExpr,
  type_idxs : Array[TypeIdx],
) -> Map[Int, MSFSiteValue] {
  let out : Map[Int, MSFSiteValue] = Map::new()
  let mut next_id = 0
let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr : TInstr) {
    let id = next_id
    next_id += 1
    match instr.kind {
      TInstrKind::TI32Const(_)
      | TInstrKind::TI64Const(_)
      | TInstrKind::TF32Const(_)
      | TInstrKind::TF64Const(_)
      | TInstrKind::TRefNull(_)
      | TInstrKind::TRefFunc(_)
      | TInstrKind::TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
        match msf_const_type(instr) {
          Some(vt) => out[id] = ConstSite(instr, vt)
          None => ()
        }
      TInstrKind::TCall(target, _) | TInstrKind::TReturnCall(target, _) => {
        let is_return = match instr.kind {
          TInstrKind::TReturnCall(_, _) => true
          _ => false
        }
        let abs_idx = msf_func_idx_to_int(target)
        if abs_idx >= 0 && abs_idx < type_idxs.length() {
          match instr.kind {
            TInstrKind::TCall(_, args) =>
              out[id] = CallTargetSite(
                target,
                type_idxs[abs_idx],
                is_return,
                args.length(),
              )
            TInstrKind::TReturnCall(_, args) =>
              out[id] = CallTargetSite(
                target,
                type_idxs[abs_idx],
                is_return,
                args.length(),
              )
            _ => ()
          }
        }
      }
      _ => ()
    }
    from_walk(self.walk_tinstruction_default((), instr))
  })
  ignore(walker.walk_texpr((), body))
  out
}

///|
fn msf_collect_defined_funcs(
  mod : Module,
  func_types : Array[FuncType],
  func_type_idxs : Array[TypeIdx],
  import_count : Int,
  trace? : (String) -> Unit = msf_trace_noop,
  trace_all_funcs? : Bool = false,
) -> Array[MSFDefinedFunc] {
  let funcs = match mod.code_sec {
    Some(CodeSec(items)) => items
    None => return []
  }
  let out : Array[MSFDefinedFunc] = []
  for def_idx = 0; def_idx < funcs.length(); def_idx = def_idx + 1 {
    let abs_idx = import_count + def_idx
    if abs_idx < 0 ||
      abs_idx >= func_types.length() ||
      abs_idx >= func_type_idxs.length() {
      continue
    }
    let ordinal = def_idx + 1
    match funcs[def_idx] {
      TFunc(_, locals, body) => {
        let hash_start_ms = msf_trace_now_ms()
        if trace_all_funcs {
          trace(
            "func[\{ordinal}] phase=hash:start abs_idx=\{abs_idx} locals=\{locals.length()} top_instrs=\{body.instrs.length()}",
          )
        }
        let hash = hash_function_ignoring_consts(
          funcs[def_idx],
          trace~,
          trace_all_funcs~,
          ordinal~,
          abs_idx~,
        )
        if trace_all_funcs {
          trace(
            "func[\{ordinal}] phase=hash:done abs_idx=\{abs_idx} elapsed_ms=\{msf_trace_elapsed_ms(hash_start_ms)} hash=\{hash}",
          )
        }
        out.push({
          def_idx,
          abs_idx,
          type_idx: func_type_idxs[abs_idx],
          func_type: func_types[abs_idx],
          locals: locals.copy(),
          body,
          hash,
        })
      }
      _ =>
        if trace_all_funcs {
          trace(
            "func[\{ordinal}] phase=hash:skip abs_idx=\{abs_idx} reason=non_typed_func",
          )
        }
    }
  }
  out
}

///|
fn msf_same_callee_type(
  lhs_target : FuncIdx,
  rhs_target : FuncIdx,
  func_type_idxs : Array[TypeIdx],
  func_types : Array[FuncType],
) -> Bool {
  let lhs_abs = msf_func_idx_to_int(lhs_target)
  let rhs_abs = msf_func_idx_to_int(rhs_target)
  if lhs_abs < 0 || rhs_abs < 0 {
    return false
  }
  if lhs_abs >= func_type_idxs.length() || rhs_abs >= func_type_idxs.length() {
    return false
  }
  if lhs_abs >= func_types.length() || rhs_abs >= func_types.length() {
    return false
  }
  func_type_idxs[lhs_abs] == func_type_idxs[rhs_abs] &&
  func_types[lhs_abs] == func_types[rhs_abs]
}

///|
fn are_in_equivalent_class(
  lhs : MSFDefinedFunc,
  rhs : MSFDefinedFunc,
  mod : Module,
) -> Bool {
  if lhs.type_idx != rhs.type_idx {
    return false
  }
  if lhs.locals.length() != rhs.locals.length() {
    return false
  }
  let func_type_idxs = msf_collect_func_type_indices(mod)
  let func_types = msf_collect_func_types(mod)
  let lhs_norm = match msf_normalize_body(lhs.body) {
    Ok(x) => x
    Err(_) => return false
  }
  let rhs_norm = match msf_normalize_body(rhs.body) {
    Ok(x) => x
    Err(_) => return false
  }
  if lhs_norm != rhs_norm {
    return false
  }
  let lhs_calls = msf_collect_call_sites(lhs.body)
  let rhs_calls = msf_collect_call_sites(rhs.body)
  if lhs_calls.length() != rhs_calls.length() {
    return false
  }
  for i = 0; i < lhs_calls.length(); i = i + 1 {
    let lc = lhs_calls[i]
    let rc = rhs_calls[i]
    if lc.node_id != rc.node_id ||
      lc.arg_count != rc.arg_count ||
      lc.is_return != rc.is_return {
      return false
    }
    if !msf_same_callee_type(lc.target, rc.target, func_type_idxs, func_types) {
      return false
    }
  }
  true
}

///|
fn msf_sort_class_members(
  members : Array[Int],
  import_count : Int,
) -> Array[Int] {
  let out = members.copy()
  out.sort_by(fn(a, b) {
    let aa = a + import_count
    let bb = b + import_count
    if aa < bb {
      -1
    } else if aa > bb {
      1
    } else {
      0
    }
  })
  out
}

///|
fn collect_equivalent_classes(
  mod : Module,
  trace? : (String) -> Unit = msf_trace_noop,
  trace_all_funcs? : Bool = false,
) -> Array[EquivalentClass] {
  let collect_start_ms = msf_trace_now_ms()
  let import_count = msf_count_imported_funcs(mod)
  let func_types = msf_collect_func_types(mod)
  let func_type_idxs = msf_collect_func_type_indices(mod)
  let defined = msf_collect_defined_funcs(
    mod,
    func_types,
    func_type_idxs,
    import_count,
    trace~,
    trace_all_funcs~,
  )
  if trace_all_funcs {
    trace("phase=collect_classes:start defined=\{defined.length()}")
  }
  let buckets : Map[MSFHashBucketKey, Array[Int]] = Map::new()
  for func in defined {
    let key = {
      type_idx: func.type_idx,
      local_count: func.locals.length(),
      hash: func.hash,
    }
    let items = buckets.get(key).unwrap_or([])
    let next = items.copy()
    next.push(func.def_idx)
    buckets[key] = next
  }
  let by_def_idx : Map[Int, MSFDefinedFunc] = Map::new()
  for func in defined {
    by_def_idx[func.def_idx] = func
  }
  let classes : Array[EquivalentClass] = []
  for entry in buckets {
    let (key, members) = entry
    if members.length() < 2 {
      continue
    }
    let bucket_start_ms = msf_trace_now_ms()
    if trace_all_funcs {
      trace(
        "phase=collect_classes:bucket:start size=\{members.length()} hash=\{key.hash} local_count=\{key.local_count}",
      )
    }
    let sorted_members = msf_sort_class_members(members, import_count)
    let partitions : Array[Array[Int]] = []
    for def_idx in sorted_members {
      let candidate = by_def_idx.get(def_idx).unwrap()
      let ordinal = def_idx + 1
      let partition_start_ms = msf_trace_now_ms()
      let mut comparisons = 0
      let mut compare_elapsed_ms = 0UL
      if trace_all_funcs {
        trace(
          "func[\{ordinal}] phase=partition:start bucket_size=\{sorted_members.length()} partitions=\{partitions.length()}",
        )
      }
      let mut placed = false
      for part in partitions {
        let rep_idx = part[0]
        let rep = by_def_idx.get(rep_idx).unwrap()
        comparisons += 1
        let compare_start_ms = msf_trace_now_ms()
        if are_in_equivalent_class(candidate, rep, mod) {
          compare_elapsed_ms += msf_trace_elapsed_ms(compare_start_ms)
          part.push(def_idx)
          placed = true
          break
        }
        compare_elapsed_ms += msf_trace_elapsed_ms(compare_start_ms)
      }
      if !placed {
        partitions.push([def_idx])
      }
      if trace_all_funcs {
        trace(
          "func[\{ordinal}] phase=partition:done elapsed_ms=\{msf_trace_elapsed_ms(partition_start_ms)} placed=\{placed} comparisons=\{comparisons} compare_elapsed_ms=\{compare_elapsed_ms}",
        )
      }
    }
    for part in partitions {
      if part.length() < 2 {
        continue
      }
      let sorted_part = msf_sort_class_members(part, import_count)
      classes.push({
        type_idx: key.type_idx,
        member_def_idxs: sorted_part,
        primary_def_idx: sorted_part[0],
      })
    }
    if trace_all_funcs {
      trace(
        "phase=collect_classes:bucket:done size=\{members.length()} partitions=\{partitions.length()} elapsed_ms=\{msf_trace_elapsed_ms(bucket_start_ms)}",
      )
    }
  }
  classes.sort_by(fn(a, b) {
    let aa = a.primary_def_idx + import_count
    let bb = b.primary_def_idx + import_count
    if aa < bb {
      -1
    } else if aa > bb {
      1
    } else {
      0
    }
  })
  if trace_all_funcs {
    trace(
      "phase=collect_classes:done classes=\{classes.length()} elapsed_ms=\{msf_trace_elapsed_ms(collect_start_ms)}",
    )
  }
  classes
}

///|
fn msf_same_all_consts(values : Array[TInstr]) -> Bool {
  if values.length() <= 1 {
    return true
  }
  let first = values[0]
  for i = 1; i < values.length(); i = i + 1 {
    if values[i] != first {
      return false
    }
  }
  true
}

///|
fn msf_same_all_targets(values : Array[FuncIdx]) -> Bool {
  if values.length() <= 1 {
    return true
  }
  let first = values[0]
  for i = 1; i < values.length(); i = i + 1 {
    if values[i] != first {
      return false
    }
  }
  true
}

///|
fn derive_params(
  clazz : EquivalentClass,
  mod : Module,
  trace? : (String) -> Unit = msf_trace_noop,
  trace_all_funcs? : Bool = false,
  ordinal? : Int = 0,
) -> Array[ParamInfo]? {
  let derive_start_ms = msf_trace_now_ms()
  if trace_all_funcs {
    trace(
      "func[\{ordinal}] phase=derive_params_internal:start members=\{clazz.member_def_idxs.length()}",
    )
  }
  let CodeSec(funcs) = match mod.code_sec {
    Some(sec) => sec
    None => {
      if trace_all_funcs {
        trace(
          "func[\{ordinal}] phase=derive_params_internal:error reason=missing_code_sec elapsed_ms=\{msf_trace_elapsed_ms(derive_start_ms)}",
        )
      }
      return None
    }
  }
  let import_count = msf_count_imported_funcs(mod)
  let func_type_idxs = msf_collect_func_type_indices(mod)
  let func_types = msf_collect_func_types(mod)
  let scan_members_start_ms = msf_trace_now_ms()
  if trace_all_funcs {
    trace("func[\{ordinal}] phase=derive_params_internal:scan_members:start")
  }
  let mut primary_body : TExpr? = None
  let mut primary_param_count = 0
  for i = 0; i < clazz.member_def_idxs.length(); i = i + 1 {
    let def_idx = clazz.member_def_idxs[i]
    if def_idx < 0 || def_idx >= funcs.length() {
      if trace_all_funcs {
        trace(
          "func[\{ordinal}] phase=derive_params_internal:scan_members:error reason=member_out_of_range def_idx=\{def_idx} elapsed_ms=\{msf_trace_elapsed_ms(scan_members_start_ms)}",
        )
      }
      return None
    }
    let abs_idx = import_count + def_idx
    if abs_idx < 0 || abs_idx >= func_type_idxs.length() {
      if trace_all_funcs {
        trace(
          "func[\{ordinal}] phase=derive_params_internal:scan_members:error reason=abs_idx_out_of_range abs_idx=\{abs_idx} elapsed_ms=\{msf_trace_elapsed_ms(scan_members_start_ms)}",
        )
      }
      return None
    }
    match funcs[def_idx] {
      TFunc(_, _, body) =>
        if def_idx == clazz.primary_def_idx {
          primary_body = Some(body)
          let FuncType(params, _) = match func_types.get(abs_idx) {
            Some(ft) => ft
            None => {
              if trace_all_funcs {
                trace(
                  "func[\{ordinal}] phase=derive_params_internal:scan_members:error reason=missing_func_type abs_idx=\{abs_idx} elapsed_ms=\{msf_trace_elapsed_ms(scan_members_start_ms)}",
                )
              }
              return None
            }
          }
          primary_param_count = params.length()
        }
      _ => {
        if trace_all_funcs {
          trace(
            "func[\{ordinal}] phase=derive_params_internal:scan_members:error reason=non_typed_member def_idx=\{def_idx} elapsed_ms=\{msf_trace_elapsed_ms(scan_members_start_ms)}",
          )
        }
        return None
      }
    }
  }
  if trace_all_funcs {
    trace(
      "func[\{ordinal}] phase=derive_params_internal:scan_members:done elapsed_ms=\{msf_trace_elapsed_ms(scan_members_start_ms)}",
    )
  }
  let primary_body = match primary_body {
    Some(x) => x
    None => {
      if trace_all_funcs {
        trace(
          "func[\{ordinal}] phase=derive_params_internal:error reason=missing_primary elapsed_ms=\{msf_trace_elapsed_ms(derive_start_ms)}",
        )
      }
      return None
    }
  }
  let collect_sites_start_ms = msf_trace_now_ms()
  if trace_all_funcs {
    trace("func[\{ordinal}] phase=derive_params_internal:collect_sites:start")
  }
  let site_maps : Array[Map[Int, MSFSiteValue]] = []
  for def_idx in clazz.member_def_idxs {
    match funcs[def_idx] {
      TFunc(_, _, body) =>
        site_maps.push(msf_collect_sites(body, func_type_idxs))
      _ => {
        if trace_all_funcs {
          trace(
            "func[\{ordinal}] phase=derive_params_internal:collect_sites:error reason=non_typed_member def_idx=\{def_idx} elapsed_ms=\{msf_trace_elapsed_ms(collect_sites_start_ms)}",
          )
        }
        return None
      }
    }
  }
  let primary_sites = msf_collect_sites(primary_body, func_type_idxs)
  let ordered_site_ids : Array[Int] = []
  for entry in primary_sites {
    let (node_id, _) = entry
    ordered_site_ids.push(node_id)
  }
  ordered_site_ids.sort_by(fn(a, b) {
    if a < b {
      -1
    } else if a > b {
      1
    } else {
      0
    }
  })
  if trace_all_funcs {
    trace(
      "func[\{ordinal}] phase=derive_params_internal:collect_sites:done elapsed_ms=\{msf_trace_elapsed_ms(collect_sites_start_ms)} primary_site_count=\{ordered_site_ids.length()}",
    )
  }
  let build_params_start_ms = msf_trace_now_ms()
  if trace_all_funcs {
    trace("func[\{ordinal}] phase=derive_params_internal:build_params:start")
  }
  let params : Array[ParamInfo] = []
  let key_to_idx : Map[MSFParamKey, Int] = Map::new()
  for node_id in ordered_site_ids {
    let primary_site = match primary_sites.get(node_id) {
      Some(v) => v
      None => continue
    }
    match primary_site {
      ConstSite(_, vt) => {
        let values : Array[TInstr] = []
        for sites in site_maps {
          match sites.get(node_id) {
            Some(ConstSite(v, site_vt)) => {
              if site_vt != vt {
                if trace_all_funcs {
                  trace(
                    "func[\{ordinal}] phase=derive_params_internal:build_params:error reason=const_type_mismatch node=\{node_id} elapsed_ms=\{msf_trace_elapsed_ms(build_params_start_ms)}",
                  )
                }
                return None
              }
              values.push(v)
            }
            _ => {
              if trace_all_funcs {
                trace(
                  "func[\{ordinal}] phase=derive_params_internal:build_params:error reason=const_site_mismatch node=\{node_id} elapsed_ms=\{msf_trace_elapsed_ms(build_params_start_ms)}",
                )
              }
              return None
            }
          }
        }
        if msf_same_all_consts(values) {
          continue
        }
        let key = ConstParamKey(vt, values)
        match key_to_idx.get(key) {
          Some(idx) => params[idx].uses.push(node_id)
          None => {
            let idx = params.length()
            key_to_idx[key] = idx
            params.push({ kind: LiteralParam(vt, values), uses: [node_id] })
          }
        }
      }
      CallTargetSite(_, type_idx, is_return, arg_count) => {
        let values : Array[FuncIdx] = []
        for sites in site_maps {
          match sites.get(node_id) {
            Some(
              CallTargetSite(
                target,
                site_type_idx,
                site_is_return,
                site_arg_count
              )
            ) => {
              if site_type_idx != type_idx {
                if trace_all_funcs {
                  trace(
                    "func[\{ordinal}] phase=derive_params_internal:build_params:error reason=call_type_mismatch node=\{node_id} elapsed_ms=\{msf_trace_elapsed_ms(build_params_start_ms)}",
                  )
                }
                return None
              }
              if site_is_return != is_return {
                if trace_all_funcs {
                  trace(
                    "func[\{ordinal}] phase=derive_params_internal:build_params:error reason=call_kind_mismatch node=\{node_id} elapsed_ms=\{msf_trace_elapsed_ms(build_params_start_ms)}",
                  )
                }
                return None
              }
              if site_arg_count != arg_count {
                if trace_all_funcs {
                  trace(
                    "func[\{ordinal}] phase=derive_params_internal:build_params:error reason=call_arg_count_mismatch node=\{node_id} elapsed_ms=\{msf_trace_elapsed_ms(build_params_start_ms)}",
                  )
                }
                return None
              }
              values.push(target)
            }
            _ => {
              if trace_all_funcs {
                trace(
                  "func[\{ordinal}] phase=derive_params_internal:build_params:error reason=call_site_mismatch node=\{node_id} elapsed_ms=\{msf_trace_elapsed_ms(build_params_start_ms)}",
                )
              }
              return None
            }
          }
        }
        if msf_same_all_targets(values) {
          continue
        }
        let key = CallParamKey(type_idx, arg_count, is_return, values)
        match key_to_idx.get(key) {
          Some(idx) => params[idx].uses.push(node_id)
          None => {
            let idx = params.length()
            key_to_idx[key] = idx
            params.push({
              kind: CallTargetParam(type_idx, arg_count, is_return, values),
              uses: [node_id],
            })
          }
        }
      }
    }
  }
  if primary_param_count + params.length() > MSF_MAX_SYNTHETIC_FUNCTION_PARAMS {
    if trace_all_funcs {
      trace(
        "func[\{ordinal}] phase=derive_params_internal:build_params:done elapsed_ms=\{msf_trace_elapsed_ms(build_params_start_ms)} params=\{params.length()} skipped=true reason=synthetic_param_limit total=\{primary_param_count + params.length()} limit=\{MSF_MAX_SYNTHETIC_FUNCTION_PARAMS}",
      )
    }
    return None
  }
  if trace_all_funcs {
    trace(
      "func[\{ordinal}] phase=derive_params_internal:build_params:done elapsed_ms=\{msf_trace_elapsed_ms(build_params_start_ms)} params=\{params.length()}",
    )
    trace(
      "func[\{ordinal}] phase=derive_params_internal:done elapsed_ms=\{msf_trace_elapsed_ms(derive_start_ms)}",
    )
  }
  Some(params)
}

///|
fn msf_measure_body(body : TExpr) -> Int {
  let mut n = 0
let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr : TInstr) {
    n += 1
    from_walk(self.walk_tinstruction_default((), instr))
  })
  ignore(walker.walk_texpr((), body))
  n
}

///|
fn has_merge_benefit(
  clazz : EquivalentClass,
  mod : Module,
  params : Array[ParamInfo],
  trace? : (String) -> Unit = msf_trace_noop,
  trace_all_funcs? : Bool = false,
  ordinal? : Int = 0,
) -> Bool {
  let benefit_start_ms = msf_trace_now_ms()
  if trace_all_funcs {
    trace(
      "func[\{ordinal}] phase=benefit_internal:start members=\{clazz.member_def_idxs.length()} params=\{params.length()}",
    )
  }
  let CodeSec(funcs) = match mod.code_sec {
    Some(sec) => sec
    None => {
      if trace_all_funcs {
        trace(
          "func[\{ordinal}] phase=benefit_internal:error reason=missing_code_sec elapsed_ms=\{msf_trace_elapsed_ms(benefit_start_ms)}",
        )
      }
      return false
    }
  }
  if clazz.member_def_idxs.length() < 2 {
    if trace_all_funcs {
      trace(
        "func[\{ordinal}] phase=benefit_internal:done elapsed_ms=\{msf_trace_elapsed_ms(benefit_start_ms)} beneficial=false reason=single_member",
      )
    }
    return false
  }
  let import_count = msf_count_imported_funcs(mod)
  let func_types = msf_collect_func_types(mod)
  let primary_def = clazz.primary_def_idx
  if primary_def < 0 || primary_def >= funcs.length() {
    if trace_all_funcs {
      trace(
        "func[\{ordinal}] phase=benefit_internal:error reason=primary_out_of_range def_idx=\{primary_def} elapsed_ms=\{msf_trace_elapsed_ms(benefit_start_ms)}",
      )
    }
    return false
  }
  let primary_abs = import_count + primary_def
  if primary_abs < 0 || primary_abs >= func_types.length() {
    if trace_all_funcs {
      trace(
        "func[\{ordinal}] phase=benefit_internal:error reason=primary_abs_out_of_range abs_idx=\{primary_abs} elapsed_ms=\{msf_trace_elapsed_ms(benefit_start_ms)}",
      )
    }
    return false
  }
  let FuncType(primary_params, _) = func_types[primary_abs]
  let primary_body = match funcs[primary_def] {
    TFunc(_, _, body) => body
    _ => {
      if trace_all_funcs {
        trace(
          "func[\{ordinal}] phase=benefit_internal:error reason=primary_non_typed elapsed_ms=\{msf_trace_elapsed_ms(benefit_start_ms)}",
        )
      }
      return false
    }
  }
  let measure_start_ms = msf_trace_now_ms()
  if trace_all_funcs {
    trace("func[\{ordinal}] phase=benefit_internal:measure:start")
  }
  let primary_body_size = msf_measure_body(primary_body)
  if trace_all_funcs {
    trace(
      "func[\{ordinal}] phase=benefit_internal:measure:done elapsed_ms=\{msf_trace_elapsed_ms(measure_start_ms)} body_instrs=\{primary_body_size}",
    )
  }
  let removed = (clazz.member_def_idxs.length() - 1) * primary_body_size
  let added_per_thunk = 1 + primary_params.length() + params.length()
  let added = (clazz.member_def_idxs.length() - 1) * added_per_thunk +
    params.length()
  let beneficial = removed > added
  if trace_all_funcs {
    trace(
      "func[\{ordinal}] phase=benefit_internal:done elapsed_ms=\{msf_trace_elapsed_ms(benefit_start_ms)} removed=\{removed} added=\{added} beneficial=\{beneficial}",
    )
  }
  beneficial
}

///|
fn msf_param_local_index(
  primary_param_count : Int,
  param_idx : Int,
) -> LocalIdx {
  msf_local_idx_from_int(primary_param_count + param_idx)
}

///|
fn msf_rewrite_shared_body(
  body : TExpr,
  primary_param_count : Int,
  params : Array[ParamInfo],
  func_types : Array[FuncType],
  func_type_idxs : Array[TypeIdx],
  trace? : (String) -> Unit = msf_trace_noop,
  trace_all_funcs? : Bool = false,
  ordinal? : Int = 0,
) -> Result[TExpr, String] {
  let rewrite_start_ms = msf_trace_now_ms()
  if trace_all_funcs {
    trace(
      "func[\{ordinal}] phase=shared_rewrite:start top_instrs=\{body.instrs.length()} params=\{params.length()}",
    )
  }
  let map_start_ms = msf_trace_now_ms()
  let node_to_param : Map[Int, Int] = Map::new()
  for param_idx = 0; param_idx < params.length(); param_idx = param_idx + 1 {
    for use_id in params[param_idx].uses {
      node_to_param[use_id] = param_idx
    }
  }
  if trace_all_funcs {
    trace(
      "func[\{ordinal}] phase=shared_rewrite:build_map:done elapsed_ms=\{msf_trace_elapsed_ms(map_start_ms)} mapped_nodes=\{node_to_param.length()}",
    )
  }
  let mut next_id = 0
  let shift = params.length()
  if trace_all_funcs {
    trace("func[\{ordinal}] phase=shared_rewrite:walk:start shift=\{shift}")
  }
  let walk_start_ms = msf_trace_now_ms()
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr : TInstr) {
    let node_id = next_id
    next_id += 1
    let walked = match self.walk_tinstruction_default((), instr) {
      Ok((next, _)) => next
      Err(e) => return error(e)
    }
    let shifted = match walked.kind {
      TInstrKind::TLocalGet(idx) => {
        let raw = msf_local_idx_to_int(idx)
        if raw >= primary_param_count {
          TInstr::local_get(msf_local_idx_from_int(raw + shift))
        } else {
          walked
        }
      }
      TInstrKind::TLocalSet(idx, value) => {
        let raw = msf_local_idx_to_int(idx)
        if raw >= primary_param_count {
          TInstr::local_set(msf_local_idx_from_int(raw + shift), value)
        } else {
          walked
        }
      }
      TInstrKind::TLocalTee(idx, value) => {
        let raw = msf_local_idx_to_int(idx)
        if raw >= primary_param_count {
          TInstr::local_tee(msf_local_idx_from_int(raw + shift), value)
        } else {
          walked
        }
      }
      _ => walked
    }
    let replaced = match node_to_param.get(node_id) {
      Some(param_idx) => {
        let replacement_local = msf_param_local_index(
          primary_param_count, param_idx,
        )
        match (shifted, params[param_idx].kind) {
          ({ kind: TInstrKind::TI32Const(_), .. }, LiteralParam(_, _))
          | ({ kind: TInstrKind::TI64Const(_), .. }, LiteralParam(_, _))
          | ({ kind: TInstrKind::TF32Const(_), .. }, LiteralParam(_, _))
          | ({ kind: TInstrKind::TF64Const(_), .. }, LiteralParam(_, _))
          | ({ kind: TInstrKind::TRefNull(_), .. }, LiteralParam(_, _))
          | ({ kind: TInstrKind::TRefFunc(_), .. }, LiteralParam(_, _))
          | (
            {
              kind: TInstrKind::TV128Const(
                _,
                _,
                _,
                _,
                _,
                _,
                _,
                _,
                _,
                _,
                _,
                _,
                _,
                _,
                _,
                _
              ),
              ..,
            },
            LiteralParam(_, _),
          ) => TInstr::local_get(replacement_local)
          (
            { kind: TInstrKind::TCall(target, args), .. },
            CallTargetParam(type_idx, expected_arg_count, expects_return, _),
          ) => {
            if expects_return {
              return error(
                "merge_similar_functions: call_target rewrite expected return_call but saw call",
              )
            }
            if args.length() != expected_arg_count {
              return error(
                "merge_similar_functions: call_target rewrite arg count mismatch",
              )
            }
            match
              msf_verify_call_target_type(
                type_idx, expected_arg_count, func_types, func_type_idxs,
              ) {
              Ok(_) => ()
              Err(e) => return error(e)
            }
            let callee_type_idx = match
              msf_resolve_callee_type_idx(target, func_type_idxs) {
              Ok(v) => v
              Err(e) => return error(e)
            }
            if callee_type_idx != type_idx {
              return error(
                "merge_similar_functions: call_target rewrite callee type mismatch",
              )
            }
            let casted = TInstr::ref_cast(
              true,
              HeapType::new(type_idx),
              TInstr::local_get(replacement_local),
            )
            TInstr::call_ref(type_idx, args, casted)
          }
          (
            { kind: TInstrKind::TReturnCall(target, args), .. },
            CallTargetParam(type_idx, expected_arg_count, expects_return, _),
          ) => {
            if !expects_return {
              return error(
                "merge_similar_functions: call_target rewrite expected call but saw return_call",
              )
            }
            if args.length() != expected_arg_count {
              return error(
                "merge_similar_functions: call_target rewrite arg count mismatch",
              )
            }
            match
              msf_verify_call_target_type(
                type_idx, expected_arg_count, func_types, func_type_idxs,
              ) {
              Ok(_) => ()
              Err(e) => return error(e)
            }
            let callee_type_idx = match
              msf_resolve_callee_type_idx(target, func_type_idxs) {
              Ok(v) => v
              Err(e) => return error(e)
            }
            if callee_type_idx != type_idx {
              return error(
                "merge_similar_functions: call_target rewrite callee type mismatch",
              )
            }
            let casted = TInstr::ref_cast(
              true,
              HeapType::new(type_idx),
              TInstr::local_get(replacement_local),
            )
            TInstr::return_call_ref(type_idx, args, casted)
          }
          _ =>
            return error(
              "merge_similar_functions: call_target rewrite kind mismatch",
            )
        }
      }
      None => shifted
    }
    // Keep this callback single-walk: children were already visited via the
    // explicit walk above.
    change((), replaced)
  })
  match walker.walk_texpr((), body) {
    Ok((out, _)) => {
      if trace_all_funcs {
        trace(
          "func[\{ordinal}] phase=shared_rewrite:walk:done elapsed_ms=\{msf_trace_elapsed_ms(walk_start_ms)} changed=\{out != body}",
        )
        trace(
          "func[\{ordinal}] phase=shared_rewrite:done elapsed_ms=\{msf_trace_elapsed_ms(rewrite_start_ms)} changed=\{out != body}",
        )
      }
      Ok(out)
    }
    Err(e) => {
      if trace_all_funcs {
        trace(
          "func[\{ordinal}] phase=shared_rewrite:walk:error elapsed_ms=\{msf_trace_elapsed_ms(walk_start_ms)} \{e}",
        )
      }
      Err(e)
    }
  }
}

///|
fn msf_collect_param_types(params : Array[ParamInfo]) -> Array[ValType] {
  let out : Array[ValType] = []
  for param in params {
    match param.kind {
      LiteralParam(vt, _) => out.push(vt)
      CallTargetParam(_, _, _, _) => out.push(ValType::funcref())
    }
  }
  out
}

///|
fn msf_append_func_type(
  mod : Module,
  params : Array[ValType],
  results : Array[ValType],
) -> (Module, TypeIdx) {
  let recs = match mod.type_sec {
    Some(TypeSec(items)) => items.copy()
    None => []
  }
  recs.push(msf_make_func_type(params, results))
  let new_idx = TypeIdx::new((recs.length() - 1).reinterpret_as_uint())
  (mod.with_type_sec(TypeSec::new(recs)), new_idx)
}

///|
fn msf_first_secondary_member(clazz : EquivalentClass) -> Int? {
  for def_idx in clazz.member_def_idxs {
    if def_idx != clazz.primary_def_idx {
      return Some(def_idx)
    }
  }
  None
}

///|
fn msf_attach_rewrite_debug_dump(
  mod : Module,
  clazz : EquivalentClass,
  params : Array[ParamInfo],
  err : String,
) -> String {
  let import_count = msf_count_imported_funcs(mod)
  let primary_abs = import_count + clazz.primary_def_idx
  let primary_idx = msf_func_idx_from_int(primary_abs)
  let primary_text = mod.pretty_print_func(primary_idx)
  let details = "merge_similar_functions debug context:\n" +
    "primary_def_idx=\{clazz.primary_def_idx} primary_abs_idx=\{primary_abs} member_count=\{clazz.member_def_idxs.length()} param_count=\{params.length()}\n" +
    "params=\{params}\n"
  match msf_first_secondary_member(clazz) {
    Some(secondary_def) => {
      let secondary_abs = import_count + secondary_def
      let secondary_idx = msf_func_idx_from_int(secondary_abs)
      let secondary_text = mod.pretty_print_func(secondary_idx)
      err +
      "\n\n" +
      details +
      "\nOffending function diff merge_similar_functions (primary -> secondary):\n" +
      render_line_diff(primary_text, secondary_text)
    }
    None =>
      err +
      "\n\n" +
      details +
      "\nOffending function merge_similar_functions (primary):\n" +
      primary_text
  }
}

///|
fn create_shared(
  clazz : EquivalentClass,
  mod : Module,
  params : Array[ParamInfo],
  trace? : (String) -> Unit = msf_trace_noop,
  trace_all_funcs? : Bool = false,
  ordinal? : Int = 0,
) -> Result[(Module, FuncIdx), String] {
  let create_start_ms = msf_trace_now_ms()
  if trace_all_funcs {
    trace(
      "func[\{ordinal}] phase=create_shared:start members=\{clazz.member_def_idxs.length()} params=\{params.length()}",
    )
  }
  let funcs = match mod.code_sec {
    Some(CodeSec(items)) => items.copy()
    None => {
      if trace_all_funcs {
        trace(
          "func[\{ordinal}] phase=create_shared:error reason=missing_code_sec elapsed_ms=\{msf_trace_elapsed_ms(create_start_ms)}",
        )
      }
      return Err("merge_similar_functions: missing code section")
    }
  }
  let type_idxs = match mod.func_sec {
    Some(FuncSec(items)) => items.copy()
    None => {
      if trace_all_funcs {
        trace(
          "func[\{ordinal}] phase=create_shared:error reason=missing_func_sec elapsed_ms=\{msf_trace_elapsed_ms(create_start_ms)}",
        )
      }
      return Err("merge_similar_functions: missing func section")
    }
  }
  let import_count = msf_count_imported_funcs(mod)
  let func_types = msf_collect_func_types(mod)
  let primary_def = clazz.primary_def_idx
  if primary_def < 0 || primary_def >= funcs.length() {
    if trace_all_funcs {
      trace(
        "func[\{ordinal}] phase=create_shared:error reason=primary_out_of_range def_idx=\{primary_def} elapsed_ms=\{msf_trace_elapsed_ms(create_start_ms)}",
      )
    }
    return Err("merge_similar_functions: primary function out of range")
  }
  let primary_abs = import_count + primary_def
  if primary_abs < 0 || primary_abs >= func_types.length() {
    if trace_all_funcs {
      trace(
        "func[\{ordinal}] phase=create_shared:error reason=primary_abs_out_of_range abs_idx=\{primary_abs} elapsed_ms=\{msf_trace_elapsed_ms(create_start_ms)}",
      )
    }
    return Err("merge_similar_functions: primary abs function out of range")
  }
  let (primary_locals, primary_body) = match funcs[primary_def] {
    TFunc(_, locals, body) => (locals.copy(), body)
    _ => {
      if trace_all_funcs {
        trace(
          "func[\{ordinal}] phase=create_shared:error reason=primary_non_typed elapsed_ms=\{msf_trace_elapsed_ms(create_start_ms)}",
        )
      }
      return Err("merge_similar_functions: primary function is not TFunc")
    }
  }
  let FuncType(primary_params, primary_results) = func_types[primary_abs]
  if trace_all_funcs {
    trace(
      "func[\{ordinal}] phase=create_shared:rewrite_body:start top_instrs=\{primary_body.instrs.length()}",
    )
  }
  let func_type_idxs = msf_collect_func_type_indices(mod)
  let rewritten_body = match
    msf_rewrite_shared_body(
      primary_body,
      primary_params.length(),
      params,
      func_types,
      func_type_idxs,
      trace~,
      trace_all_funcs~,
      ordinal~,
    ) {
    Ok(x) => x
    Err(e) => {
      if trace_all_funcs {
        trace(
          "func[\{ordinal}] phase=create_shared:rewrite_body:error elapsed_ms=\{msf_trace_elapsed_ms(create_start_ms)} \{e}",
        )
      }
      return Err(msf_attach_rewrite_debug_dump(mod, clazz, params, e))
    }
  }
  if trace_all_funcs {
    trace(
      "func[\{ordinal}] phase=create_shared:rewrite_body:done elapsed_ms=\{msf_trace_elapsed_ms(create_start_ms)}",
    )
  }
  let added_param_types = msf_collect_param_types(params)
  let shared_param_types = primary_params.copy()
  for vt in added_param_types {
    shared_param_types.push(vt)
  }
  let append_type_start_ms = msf_trace_now_ms()
  if trace_all_funcs {
    trace(
      "func[\{ordinal}] phase=create_shared:append_type:start shared_params=\{shared_param_types.length()} results=\{primary_results.length()}",
    )
  }
  let (with_type, shared_type_idx) = msf_append_func_type(
    mod, shared_param_types, primary_results,
  )
  if trace_all_funcs {
    trace(
      "func[\{ordinal}] phase=create_shared:append_type:done elapsed_ms=\{msf_trace_elapsed_ms(append_type_start_ms)} type_idx=\{shared_type_idx}",
    )
  }
  let append_func_start_ms = msf_trace_now_ms()
  if trace_all_funcs {
    trace("func[\{ordinal}] phase=create_shared:append_func:start")
  }
  let next_type_idxs = type_idxs
  let next_funcs = funcs
  next_type_idxs.push(shared_type_idx)
  let shared_func = Func::t_func(
    shared_param_types, primary_locals, rewritten_body,
  )
  next_funcs.push(shared_func)
  let next_mod = with_type
    .with_func_sec(FuncSec::new(next_type_idxs))
    .with_code_sec(CodeSec::new(next_funcs))
  let shared_abs = import_count + (next_funcs.length() - 1)
  if trace_all_funcs {
    trace(
      "func[\{ordinal}] phase=create_shared:append_func:done elapsed_ms=\{msf_trace_elapsed_ms(append_func_start_ms)} shared_abs=\{shared_abs}",
    )
    trace(
      "func[\{ordinal}] phase=create_shared:done elapsed_ms=\{msf_trace_elapsed_ms(create_start_ms)} shared_abs=\{shared_abs}",
    )
  }
  Ok((next_mod, msf_func_idx_from_int(shared_abs)))
}

///|
fn msf_param_value_for_member(param : ParamInfo, member_idx : Int) -> TInstr? {
  match param.kind {
    LiteralParam(_, values) => values.get(member_idx)
    CallTargetParam(_, _, _, targets) =>
      match targets.get(member_idx) {
        Some(target) => Some(TInstr::ref_func(target))
        None => None
      }
  }
}

///|
fn msf_has_func_idx(items : Array[FuncIdx], value : FuncIdx) -> Bool {
  for item in items {
    if item == value {
      return true
    }
  }
  false
}

///|
fn msf_collect_synthesized_ref_func_targets(
  params : Array[ParamInfo],
) -> Array[FuncIdx] {
  let out : Array[FuncIdx] = []
  for param in params {
    match param.kind {
      CallTargetParam(_, _, _, targets) =>
        for target in targets {
          if !msf_has_func_idx(out, target) {
            out.push(target)
          }
        }
      LiteralParam(_, values) =>
        for value in values {
          match value.kind {
            TInstrKind::TRefFunc(target) =>
              if !msf_has_func_idx(out, target) {
                out.push(target)
              }
            _ => ()
          }
        }
    }
  }
  out
}

///|
fn msf_append_ref_func_declaration_segment(
  mod : Module,
  targets : Array[FuncIdx],
) -> Module {
  if targets.is_empty() {
    return mod
  }
  let elems = match mod.elem_sec {
    Some(ElemSec(items)) => items.copy()
    None => []
  }
  elems.push(Elem::new(ElemMode::declarative(), ElemKind::funcs(targets)))
  mod.with_elem_sec(ElemSec::new(elems))
}

///|
fn replace_with_thunk(
  target : Func,
  shared : FuncIdx,
  params : Array[ParamInfo],
  values_for_target : Array[TInstr],
) -> Func {
  match target {
    TFunc(target_params, _, _) => {
      let param_count = values_for_target.length() - params.length()
      let args : Array[TInstr] = []
      for i = 0; i < param_count; i = i + 1 {
        args.push(values_for_target[i])
      }
      for i = 0; i < params.length(); i = i + 1 {
        args.push(values_for_target[param_count + i])
      }
      let body = TExpr::new([TInstr::return_call(shared, args)])
      Func::t_func(target_params, [], body)
    }
    _ => target
  }
}

///|
fn msf_build_thunk_values(
  param_count : Int,
  params : Array[ParamInfo],
  member_idx : Int,
) -> Array[TInstr]? {
  let out : Array[TInstr] = []
  for i = 0; i < param_count; i = i + 1 {
    out.push(TInstr::local_get(msf_local_idx_from_int(i)))
  }
  for param in params {
    match msf_param_value_for_member(param, member_idx) {
      Some(v) => out.push(v)
      None => return None
    }
  }
  Some(out)
}

///|
fn msf_apply_class(
  mod : Module,
  clazz : EquivalentClass,
  params : Array[ParamInfo],
  trace? : (String) -> Unit = msf_trace_noop,
  trace_all_funcs? : Bool = false,
) -> Result[Module, String] {
  let primary_ordinal = clazz.primary_def_idx + 1
  let import_count = msf_count_imported_funcs(mod)
  let func_types = msf_collect_func_types(mod)
  let declared_targets = msf_collect_synthesized_ref_func_targets(params)
  let primary_abs = import_count + clazz.primary_def_idx
  if primary_abs < 0 || primary_abs >= func_types.length() {
    return Ok(mod)
  }
  let FuncType(primary_params, _) = func_types[primary_abs]
  let create_shared_start_ms = msf_trace_now_ms()
  if trace_all_funcs {
    trace(
      "func[\{primary_ordinal}] phase=apply:create_shared:start params=\{params.length()}",
    )
  }
  let (mod, shared_idx) = match
    create_shared(
      clazz,
      mod,
      params,
      trace~,
      trace_all_funcs~,
      ordinal=primary_ordinal,
    ) {
    Ok(v) => v
    Err(e) => {
      if trace_all_funcs {
        trace(
          "func[\{primary_ordinal}] phase=apply:create_shared:error elapsed_ms=\{msf_trace_elapsed_ms(create_shared_start_ms)} \{e}",
        )
      }
      return Err(e)
    }
  }
  if trace_all_funcs {
    trace(
      "func[\{primary_ordinal}] phase=apply:create_shared:done elapsed_ms=\{msf_trace_elapsed_ms(create_shared_start_ms)} shared_idx=\{shared_idx}",
    )
  }
  let next_funcs = match mod.code_sec {
    Some(CodeSec(items)) => items.copy()
    None => return Ok(mod)
  }
  for member_idx = 0
      member_idx < clazz.member_def_idxs.length()
      member_idx = member_idx + 1 {
    let def_idx = clazz.member_def_idxs[member_idx]
    if def_idx < 0 || def_idx >= next_funcs.length() {
      return Err("merge_similar_functions: class member out of range")
    }
    let ordinal = def_idx + 1
    let member_start_ms = msf_trace_now_ms()
    if trace_all_funcs {
      trace(
        "func[\{ordinal}] phase=thunk_rewrite:start class_primary=\{clazz.primary_def_idx + 1} member=\{member_idx + 1}/\{clazz.member_def_idxs.length()}",
      )
    }
    let values = match
      msf_build_thunk_values(primary_params.length(), params, member_idx) {
      Some(v) => v
      None => return Err("merge_similar_functions: missing thunk values")
    }
    let thunk = replace_with_thunk(
      next_funcs[def_idx],
      shared_idx,
      params,
      values,
    )
    next_funcs[def_idx] = thunk
    if trace_all_funcs {
      trace(
        "func[\{ordinal}] phase=thunk_rewrite:done elapsed_ms=\{msf_trace_elapsed_ms(member_start_ms)} arg_count=\{values.length()}",
      )
    }
  }
  Ok(
    msf_append_ref_func_declaration_segment(
      mod.with_code_sec(CodeSec::new(next_funcs)),
      declared_targets,
    ),
  )
}

///|
fn run(
  mod : Module,
  trace? : (String) -> Unit = msf_trace_noop,
  trace_all_funcs? : Bool = false,
) -> Result[Module, String] {
  let run_start_ms = msf_trace_now_ms()
  let defined_funcs = match mod.code_sec {
    Some(CodeSec(funcs)) => funcs.length()
    None => 0
  }
  trace("start defined=\{defined_funcs}")
  let classes = collect_equivalent_classes(mod, trace~, trace_all_funcs~)
  trace(
    "phase=collect_classes summary classes=\{classes.length()} elapsed_ms=\{msf_trace_elapsed_ms(run_start_ms)}",
  )
  if classes.is_empty() {
    trace(
      "done classes=0 merged=0 elapsed_ms=\{msf_trace_elapsed_ms(run_start_ms)}",
    )
    return Ok(mod)
  }
  let mut mod = mod
  let mut merged_classes = 0
  for clazz in classes {
    let ordinal = clazz.primary_def_idx + 1
    let class_start_ms = msf_trace_now_ms()
    if trace_all_funcs {
      trace(
        "func[\{ordinal}] start members=\{clazz.member_def_idxs.length()} primary=\{clazz.primary_def_idx + 1}",
      )
    }
    let derive_start_ms = msf_trace_now_ms()
    if trace_all_funcs {
      trace(
        "func[\{ordinal}] phase=derive_params:start members=\{clazz.member_def_idxs.length()}",
      )
    }
    let params = match
      derive_params(clazz, mod, trace~, trace_all_funcs~, ordinal~) {
      Some(p) => p
      None => {
        if trace_all_funcs {
          trace(
            "func[\{ordinal}] phase=derive_params:done elapsed_ms=\{msf_trace_elapsed_ms(derive_start_ms)} params=0 skipped=true reason=derive_failed",
          )
          trace(
            "func[\{ordinal}] done elapsed_ms=\{msf_trace_elapsed_ms(class_start_ms)} merged=false reason=derive_failed",
          )
        }
        continue
      }
    }
    if trace_all_funcs {
      trace(
        "func[\{ordinal}] phase=derive_params:done elapsed_ms=\{msf_trace_elapsed_ms(derive_start_ms)} params=\{params.length()}",
      )
    }
    if params.is_empty() {
      if trace_all_funcs {
        trace(
          "func[\{ordinal}] done elapsed_ms=\{msf_trace_elapsed_ms(class_start_ms)} merged=false reason=no_differences",
        )
      }
      continue
    }
    let func_types = msf_collect_func_types(mod)
    let import_count = msf_count_imported_funcs(mod)
    let primary_abs = import_count + clazz.primary_def_idx
    if primary_abs < 0 || primary_abs >= func_types.length() {
      if trace_all_funcs {
        trace(
          "func[\{ordinal}] done elapsed_ms=\{msf_trace_elapsed_ms(class_start_ms)} merged=false reason=primary_out_of_range",
        )
      }
      continue
    }
    let FuncType(primary_params, _) = func_types[primary_abs]
    if primary_params.length() + params.length() >
      MSF_MAX_SYNTHETIC_FUNCTION_PARAMS {
      if trace_all_funcs {
        trace(
          "func[\{ordinal}] done elapsed_ms=\{msf_trace_elapsed_ms(class_start_ms)} merged=false reason=synthetic_param_limit params=\{primary_params.length() + params.length()} limit=\{MSF_MAX_SYNTHETIC_FUNCTION_PARAMS}",
        )
      }
      continue
    }
    let benefit_start_ms = msf_trace_now_ms()
    if trace_all_funcs {
      trace(
        "func[\{ordinal}] phase=benefit:start params=\{params.length()} members=\{clazz.member_def_idxs.length()}",
      )
    }
    let has_benefit = has_merge_benefit(
      clazz,
      mod,
      params,
      trace~,
      trace_all_funcs~,
      ordinal~,
    )
    if trace_all_funcs {
      trace(
        "func[\{ordinal}] phase=benefit:done elapsed_ms=\{msf_trace_elapsed_ms(benefit_start_ms)} beneficial=\{has_benefit}",
      )
    }
    if !has_benefit {
      if trace_all_funcs {
        trace(
          "func[\{ordinal}] done elapsed_ms=\{msf_trace_elapsed_ms(class_start_ms)} merged=false reason=no_benefit",
        )
      }
      continue
    }
    let apply_start_ms = msf_trace_now_ms()
    if trace_all_funcs {
      trace(
        "func[\{ordinal}] phase=apply:start params=\{params.length()} members=\{clazz.member_def_idxs.length()}",
      )
    }
    mod = match msf_apply_class(mod, clazz, params, trace~, trace_all_funcs~) {
      Ok(next) => next
      Err(e) => return Err(e)
    }
    merged_classes += 1
    if trace_all_funcs {
      trace(
        "func[\{ordinal}] phase=apply:done elapsed_ms=\{msf_trace_elapsed_ms(apply_start_ms)}",
      )
      trace(
        "func[\{ordinal}] done elapsed_ms=\{msf_trace_elapsed_ms(class_start_ms)} merged=true",
      )
    }
  }
  trace(
    "done classes=\{classes.length()} merged=\{merged_classes} elapsed_ms=\{msf_trace_elapsed_ms(run_start_ms)}",
  )
  Ok(mod)
}

///|
fn merge_similar_functions_with_trace(
  mod : Module,
  trace : (String) -> Unit,
  trace_all_funcs? : Bool = false,
) -> Result[Module, String] {
  run(mod, trace~, trace_all_funcs~)
}

///|
fn merge_similar_functions(mod : Module) -> Result[Module, String] {
  run(mod)
}

///|
fn msf_run(mod : Module) -> Module {
  match merge_similar_functions(mod) {
    Ok(out) => out
    Err(_) => mod
  }
}

///|
fn msf_i32_func_type() -> RecType {
  msf_make_func_type([ValType::i32()], [ValType::i32()])
}

///|
fn msf_void_func_type() -> RecType {
  msf_make_func_type([], [])
}

///|
fn msf_binary_body(c0 : Int, c1 : Int) -> TExpr {
  TExpr::new([
    TInstr::return_([
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::binary(
          BinaryOp::i32_mul(),
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::i32_const(I32(c0)),
        ),
        TInstr::binary(
          BinaryOp::i32_add(),
          TInstr::i32_const(I32(c1)),
          TInstr::i32_const(I32(7)),
        ),
      ),
    ]),
  ])
}

///|
fn msf_shared_abs_index(mod : Module) -> Int {
  let funcs = match mod.code_sec {
    Some(CodeSec(items)) => items
    None => return -1
  }
  let import_count = msf_count_imported_funcs(mod)
  import_count + funcs.length() - 1
}

///|
fn msf_is_forwarder(func : Func, target_abs : Int, arg_count : Int) -> Bool {
  match func {
    TFunc(
      _,
      locals,
      {
        instrs: [{ kind: TInstrKind::TReturnCall(FuncIdx(raw), args), .. }],
        ..,
      }
    ) =>
      locals.length() == 0 &&
      raw.reinterpret_as_int() == target_abs &&
      args.length() == arg_count
    _ => false
  }
}

///|
test "merge similar functions hash trace avoids normalize internal walk" {
  let func = Func::t_func(
    [],
    [],
    TExpr::new([TInstr::drop(TInstr::i32_const(I32(7)))]),
  )
  let trace_logs : Array[String] = []
  ignore(
    hash_function_ignoring_consts(
      func,
      trace=fn(msg) { trace_logs.push(msg) },
      trace_all_funcs=true,
      ordinal=1,
      abs_idx=0,
    ),
  )
  let mut saw_normalize_internal = false
  for msg in trace_logs {
    if msg.contains("phase=hash:normalize_internal:start") {
      saw_normalize_internal = true
    }
  }
  assert_false(saw_normalize_internal)
}

///|
test "merge similar functions basic const merging creates shared + thunks" {
  let t = msf_i32_func_type()
  let f0 = Func::t_func([ValType::i32()], [], msf_binary_body(42, 10))
  let f1 = Func::t_func([ValType::i32()], [], msf_binary_body(43, 10))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([f0, f1]))
  let out = msf_run(mod)
  let shared_abs = msf_shared_abs_index(out)
  match out.code_sec {
    Some(CodeSec(funcs)) => {
      assert_eq(funcs.length(), 3)
      assert_true(msf_is_forwarder(funcs[0], shared_abs, 2))
      assert_true(msf_is_forwarder(funcs[1], shared_abs, 2))
      match funcs[2] {
        TFunc(_, _, body) => {
          let mut saw_param_get = false
let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
            self,
            _,
            instr : TInstr,
          ) {
            match instr.kind {
              TInstrKind::TLocalGet(LocalIdx(raw)) if raw.reinterpret_as_int() ==
                1 => saw_param_get = true
              _ => ()
            }
            from_walk(self.walk_tinstruction_default((), instr))
          })
          ignore(walker.walk_texpr((), body))
          assert_true(saw_param_get)
        }
        _ => fail("expected shared function")
      }
    }
    _ => fail("expected code section")
  }
  assert_eq(validate_module(out), Ok(()))
}

///|
test "merge similar functions reuses parameter across repeated diff vector" {
  let t = msf_i32_func_type()
  let f0 = Func::t_func(
    [ValType::i32()],
    [],
    TExpr::new([
      TInstr::return_([
        TInstr::binary(
          BinaryOp::i32_add(),
          TInstr::i32_const(I32(42)),
          TInstr::binary(
            BinaryOp::i32_add(),
            TInstr::i32_const(I32(42)),
            TInstr::i32_const(I32(5)),
          ),
        ),
      ]),
    ]),
  )
  let f1 = Func::t_func(
    [ValType::i32()],
    [],
    TExpr::new([
      TInstr::return_([
        TInstr::binary(
          BinaryOp::i32_add(),
          TInstr::i32_const(I32(43)),
          TInstr::binary(
            BinaryOp::i32_add(),
            TInstr::i32_const(I32(43)),
            TInstr::i32_const(I32(5)),
          ),
        ),
      ]),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([f0, f1]))
  let out = msf_run(mod)
  let shared_abs = msf_shared_abs_index(out)
  match out.code_sec {
    Some(CodeSec(funcs)) => {
      assert_true(msf_is_forwarder(funcs[0], shared_abs, 2))
      assert_true(msf_is_forwarder(funcs[1], shared_abs, 2))
      match funcs[2] {
        TFunc(_, _, { instrs: body, .. }) => {
          let mut local_get_count = 0
          for instr in body {
let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
              self,
              _,
              curr : TInstr,
            ) {
              match curr.kind {
                TInstrKind::TLocalGet(LocalIdx(raw)) if raw.reinterpret_as_int() ==
                  1 => local_get_count += 1
                _ => ()
              }
              from_walk(self.walk_tinstruction_default((), curr))
            })
            ignore(walker.walk_tinstruction((), instr))
          }
          assert_eq(local_get_count, 2)
        }
        _ => fail("expected shared function")
      }
    }
    _ => fail("expected code section")
  }
}

///|
test "merge similar functions creates multiple params for independent differences" {
  let t = msf_i32_func_type()
  let f0 = Func::t_func([ValType::i32()], [], msf_binary_body(10, 20))
  let f1 = Func::t_func([ValType::i32()], [], msf_binary_body(11, 21))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([f0, f1]))
  let out = msf_run(mod)
  let shared_abs = msf_shared_abs_index(out)
  match out.code_sec {
    Some(CodeSec(funcs)) => {
      assert_true(msf_is_forwarder(funcs[0], shared_abs, 3))
      assert_true(msf_is_forwarder(funcs[1], shared_abs, 3))
    }
    _ => fail("expected code section")
  }
}

///|
test "merge similar functions parameterizes call target using call_ref" {
  let t_callee = msf_i32_func_type()
  let t_wrap = msf_i32_func_type()
  let callee_a = Func::t_func(
    [ValType::i32()],
    [],
    TExpr::new([
      TInstr::return_([
        TInstr::binary(
          BinaryOp::i32_add(),
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::i32_const(I32(1)),
        ),
      ]),
    ]),
  )
  let callee_b = Func::t_func(
    [ValType::i32()],
    [],
    TExpr::new([
      TInstr::return_([
        TInstr::binary(
          BinaryOp::i32_add(),
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::i32_const(I32(2)),
        ),
      ]),
    ]),
  )
  let wrap_a = Func::t_func(
    [ValType::i32()],
    [],
    TExpr::new([
      TInstr::return_([
        TInstr::binary(
          BinaryOp::i32_add(),
          TInstr::call(FuncIdx::new(0), [TInstr::local_get(LocalIdx::new(0))]),
          TInstr::i32_const(I32(9)),
        ),
      ]),
    ]),
  )
  let wrap_b = Func::t_func(
    [ValType::i32()],
    [],
    TExpr::new([
      TInstr::return_([
        TInstr::binary(
          BinaryOp::i32_add(),
          TInstr::call(FuncIdx::new(1), [TInstr::local_get(LocalIdx::new(0))]),
          TInstr::i32_const(I32(9)),
        ),
      ]),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_callee, t_wrap]))
    .with_func_sec(
      FuncSec::new([
        TypeIdx::new(0),
        TypeIdx::new(0),
        TypeIdx::new(1),
        TypeIdx::new(1),
      ]),
    )
    .with_code_sec(CodeSec::new([callee_a, callee_b, wrap_a, wrap_b]))
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("callee_a"), ExternIdx::func(FuncIdx::new(0))),
        Export::new(Name::new("callee_b"), ExternIdx::func(FuncIdx::new(1))),
      ]),
    )
  let out = msf_run(mod)
  let shared_abs = msf_shared_abs_index(out)
  match out.code_sec {
    Some(CodeSec(funcs)) => {
      assert_true(msf_is_forwarder(funcs[2], shared_abs, 2))
      assert_true(msf_is_forwarder(funcs[3], shared_abs, 2))
      match funcs[shared_abs - msf_count_imported_funcs(out)] {
        TFunc(_, _, { instrs: body, .. }) => {
          let mut saw_call_ref = false
          let mut seen_type_idx = -1
          let mut saw_casted_local = false
let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
            self,
            _,
            instr : TInstr,
          ) {
            match instr.kind {
              TInstrKind::TCallRef(TypeIdx(raw), _, ref_) => {
                saw_call_ref = true
                seen_type_idx = raw.reinterpret_as_int()
                match ref_.kind {
                  TInstrKind::TRefCast(
                    true,
                    HeapType(TypeIdx(cast_raw)),
                    { kind: TInstrKind::TLocalGet(LocalIdx(local_raw)), .. }
                  ) =>
                    if cast_raw.reinterpret_as_int() == 0 &&
                      local_raw.reinterpret_as_int() == 1 {
                      saw_casted_local = true
                    }
                  _ => ()
                }
              }
              _ => ()
            }
            from_walk(self.walk_tinstruction_default((), instr))
          })
          ignore(walker.walk_texpr((), TExpr::new(body)))
          assert_true(saw_call_ref)
          assert_eq(seen_type_idx, 0)
          assert_true(saw_casted_local)
        }
        _ => fail("expected shared function")
      }
    }
    _ => fail("expected code section")
  }
  assert_eq(validate_module(out), Ok(()))
}

///|
test "merge similar functions protects call target params with mismatched arity" {
  let body = TExpr::new([
    TInstr::call(FuncIdx::new(0), [
      TInstr::i32_const(I32(2)),
      TInstr::i32_const(I32(3)),
    ]),
  ])
  let sites = msf_collect_sites(body, [TypeIdx::new(0)])
  let mut mismatch_call_node = -1
  for entry in sites {
    let (node_id, site) = entry
    match site {
      CallTargetSite(_) => mismatch_call_node = node_id
      _ => ()
    }
  }
  assert_true(mismatch_call_node >= 0)
  let params : Array[ParamInfo] = [
    {
      kind: CallTargetParam(TypeIdx::new(0), 1, false, [
        FuncIdx::new(0),
        FuncIdx::new(1),
      ]),
      uses: [mismatch_call_node],
    },
  ]
  match
    msf_rewrite_shared_body(
      body,
      0,
      params,
      [FuncType::new([ValType::i32(), ValType::i32()], [ValType::i32()])],
      [TypeIdx::new(0)],
    ) {
    Ok(_) =>
      fail(
        "expected msf_rewrite_shared_body to reject mismatched call-target arity",
      )
    Err(e) => assert_true(e.contains("call_target rewrite arg count mismatch"))
  }
}

///|
test "merge similar functions rewrite validation errors include function diff dump" {
  let t = msf_make_func_type([ValType::i32()], [ValType::i32()])
  let f0_body = TExpr::new([
    TInstr::call(FuncIdx::new(0), [TInstr::local_get(LocalIdx::new(0))]),
  ])
  let f0 = Func::t_func([ValType::i32()], [ValType::i32()], f0_body)
  let f1 = Func::t_func(
    [ValType::i32()],
    [ValType::i32()],
    TExpr::new([
      TInstr::call(FuncIdx::new(1), [TInstr::local_get(LocalIdx::new(0))]),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([f0, f1]))
  let call_sites = msf_collect_sites(f0_body, [TypeIdx::new(0), TypeIdx::new(0)])
  let mut call_node = -1
  for entry in call_sites {
    let (node_id, site) = entry
    match site {
      CallTargetSite(_, _, false, _) => call_node = node_id
      _ => ()
    }
  }
  assert_true(call_node >= 0)
  let clazz = {
    type_idx: TypeIdx::new(0),
    member_def_idxs: [0, 1],
    primary_def_idx: 0,
  }
  let params : Array[ParamInfo] = [
    {
      kind: CallTargetParam(TypeIdx::new(0), 2, false, [
        FuncIdx::new(0),
        FuncIdx::new(1),
      ]),
      uses: [call_node],
    },
  ]
  match create_shared(clazz, mod, params) {
    Ok(_) => fail("expected create_shared to fail rewrite validation")
    Err(e) => {
      assert_true(e.contains("call_target rewrite arg count mismatch"))
      assert_true(
        e.contains(
          "Offending function diff merge_similar_functions (primary -> secondary)",
        ),
      )
      assert_true(e.contains("merge_similar_functions debug context"))
    }
  }
}

///|
test "merge similar functions rewrites call target params with unchanged ancestors" {
  let body = TExpr::new([
    TInstr::drop(
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(7)),
      ),
    ),
    TInstr::call(FuncIdx::new(0), [TInstr::local_get(LocalIdx::new(0))]),
    TInstr::return_call(FuncIdx::new(1), [TInstr::local_get(LocalIdx::new(0))]),
  ])
  let sites = msf_collect_sites(body, [TypeIdx::new(0), TypeIdx::new(0)])
  let mut call_node = -1
  let mut return_call_node = -1
  for entry in sites {
    let (node_id, site) = entry
    match site {
      CallTargetSite(_, _, is_return, _) =>
        if is_return {
          return_call_node = node_id
        } else {
          call_node = node_id
        }
      _ => ()
    }
  }
  assert_true(call_node >= 0)
  assert_true(return_call_node >= 0)
  let params : Array[ParamInfo] = [
    {
      kind: CallTargetParam(TypeIdx::new(0), 1, false, [
        FuncIdx::new(0),
        FuncIdx::new(1),
      ]),
      uses: [call_node],
    },
    {
      kind: CallTargetParam(TypeIdx::new(0), 1, true, [
        FuncIdx::new(1),
        FuncIdx::new(0),
      ]),
      uses: [return_call_node],
    },
  ]
  let rewritten = match
    msf_rewrite_shared_body(
      body,
      1,
      params,
      [FuncType::new([ValType::i32()], [ValType::i32()])],
      [TypeIdx::new(0), TypeIdx::new(0)],
    ) {
    Ok(out) => out
    Err(e) =>
      fail(
        "expected msf_rewrite_shared_body to rewrite call targets without kind mismatch: \{e}",
      )
  }
  let mut saw_call_ref = false
  let mut saw_return_call_ref = false
  let mut saw_call_casted_local = false
  let mut saw_return_call_casted_local = false
let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr : TInstr) {
    match instr.kind {
      TInstrKind::TCallRef(TypeIdx(raw), args, ref_) => {
        if raw.reinterpret_as_int() == 0 && args.length() == 1 {
          saw_call_ref = true
        }
        match ref_.kind {
          TInstrKind::TRefCast(
            true,
            HeapType(TypeIdx(cast_raw)),
            { kind: TInstrKind::TLocalGet(LocalIdx(local_raw)), .. }
          ) =>
            if cast_raw.reinterpret_as_int() == 0 &&
              local_raw.reinterpret_as_int() == 1 {
              saw_call_casted_local = true
            }
          _ => ()
        }
      }
      TInstrKind::TReturnCallRef(TypeIdx(raw), args, ref_) => {
        if raw.reinterpret_as_int() == 0 && args.length() == 1 {
          saw_return_call_ref = true
        }
        match ref_.kind {
          TInstrKind::TRefCast(
            true,
            HeapType(TypeIdx(cast_raw)),
            { kind: TInstrKind::TLocalGet(LocalIdx(local_raw)), .. }
          ) =>
            if cast_raw.reinterpret_as_int() == 0 &&
              local_raw.reinterpret_as_int() == 2 {
              saw_return_call_casted_local = true
            }
          _ => ()
        }
      }
      _ => ()
    }
    from_walk(self.walk_tinstruction_default((), instr))
  })
  ignore(walker.walk_texpr((), rewritten))
  assert_true(saw_call_ref)
  assert_true(saw_return_call_ref)
  assert_true(saw_call_casted_local)
  assert_true(saw_return_call_casted_local)
}

///|
test "merge similar functions validates call-target arity by callee type idx" {
  let body = TExpr::new([
    TInstr::call(FuncIdx::new(0), [TInstr::local_get(LocalIdx::new(0))]),
  ])
  let sites = msf_collect_sites(body, [TypeIdx::new(1), TypeIdx::new(0)])
  let mut call_node = -1
  for entry in sites {
    let (node_id, site) = entry
    match site {
      CallTargetSite(_, _, false, _) => call_node = node_id
      _ => ()
    }
  }
  assert_true(call_node >= 0)
  let params : Array[ParamInfo] = [
    {
      kind: CallTargetParam(TypeIdx::new(1), 1, false, [
        FuncIdx::new(0),
        FuncIdx::new(1),
      ]),
      uses: [call_node],
    },
  ]
  let rewritten = match
    msf_rewrite_shared_body(
      body,
      1,
      params,
      [
        FuncType::new([ValType::i32()], [ValType::i32()]),
        FuncType::new([], [ValType::i32()]),
      ],
      [TypeIdx::new(1), TypeIdx::new(0)],
    ) {
    Ok(out) => out
    Err(e) =>
      fail(
        "expected msf_rewrite_shared_body to accept arity based on the callee type idx: \{e}",
      )
  }
  let mut saw_call_ref = false
let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr : TInstr) {
    match instr.kind {
      TInstrKind::TCallRef(TypeIdx(raw), args, _) =>
        if raw.reinterpret_as_int() == 1 && args.length() == 1 {
          saw_call_ref = true
        }
      _ => ()
    }
    from_walk(self.walk_tinstruction_default((), instr))
  })
  ignore(walker.walk_texpr((), rewritten))
  assert_true(saw_call_ref)
}

///|
test "merge similar functions accepts safe call-target arity" {
  let t_callee = msf_make_func_type([ValType::i32()], [ValType::i32()])
  let t_wrap = msf_make_func_type([], [ValType::i32()])
  let callee_a = Func::t_func(
    [ValType::i32()],
    [ValType::i32()],
    TExpr::new([TInstr::local_get(LocalIdx::new(0))]),
  )
  let callee_b = Func::t_func(
    [ValType::i32()],
    [ValType::i32()],
    TExpr::new([TInstr::local_get(LocalIdx::new(0))]),
  )
  let wrap_a = Func::t_func(
    [],
    [ValType::i32()],
    TExpr::new([
      TInstr::drop(TInstr::i32_const(I32(0))),
      TInstr::return_([
        TInstr::call(FuncIdx::new(0), [TInstr::i32_const(I32(1))]),
      ]),
    ]),
  )
  let wrap_b = Func::t_func(
    [],
    [ValType::i32()],
    TExpr::new([
      TInstr::drop(TInstr::i32_const(I32(0))),
      TInstr::return_([
        TInstr::call(FuncIdx::new(1), [TInstr::i32_const(I32(1))]),
      ]),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_callee, t_wrap]))
    .with_func_sec(
      FuncSec::new([
        TypeIdx::new(0),
        TypeIdx::new(0),
        TypeIdx::new(1),
        TypeIdx::new(1),
      ]),
    )
    .with_code_sec(CodeSec::new([callee_a, callee_b, wrap_a, wrap_b]))
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("callee_a"), ExternIdx::func(FuncIdx::new(0))),
        Export::new(Name::new("callee_b"), ExternIdx::func(FuncIdx::new(1))),
      ]),
    )
  let out = msf_run(mod)
  assert_eq(validate_module(out), Ok(()))
}

///|
test "merge similar functions declares synthesized ref.func call targets" {
  let t_callee = msf_make_func_type([ValType::i32()], [ValType::i32()])
  let t_wrap = msf_make_func_type([], [])
  let callee_a = Func::t_func(
    [ValType::i32()],
    [],
    TExpr::new([TInstr::return_([TInstr::local_get(LocalIdx::new(0))])]),
  )
  let callee_b = Func::t_func(
    [ValType::i32()],
    [],
    TExpr::new([
      TInstr::return_([
        TInstr::binary(
          BinaryOp::i32_add(),
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::i32_const(I32(1)),
        ),
      ]),
    ]),
  )
  let wrap_a = Func::t_func(
    [],
    [],
    TExpr::new([
      TInstr::drop(TInstr::call(FuncIdx::new(0), [TInstr::i32_const(I32(1))])),
      TInstr::return_([]),
    ]),
  )
  let wrap_b = Func::t_func(
    [],
    [],
    TExpr::new([
      TInstr::drop(TInstr::call(FuncIdx::new(1), [TInstr::i32_const(I32(1))])),
      TInstr::return_([]),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_callee, t_wrap]))
    .with_func_sec(
      FuncSec::new([
        TypeIdx::new(0),
        TypeIdx::new(0),
        TypeIdx::new(1),
        TypeIdx::new(1),
      ]),
    )
    .with_code_sec(CodeSec::new([callee_a, callee_b, wrap_a, wrap_b]))
  let out = msf_run(mod)
  assert_eq(validate_module(out), Ok(()))
}

///|
test "merge similar functions rejects const type mismatch" {
  let t = msf_void_func_type()
  let f0 = Func::t_func(
    [],
    [],
    TExpr::new([TInstr::drop(TInstr::i32_const(I32(1)))]),
  )
  let f1 = Func::t_func(
    [],
    [],
    TExpr::new([TInstr::drop(TInstr::i64_const(I64(1L)))]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([f0, f1]))
  let out = msf_run(mod)
  match out.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 2)
    _ => fail("expected code section")
  }
}

///|
test "merge similar functions rejects call target type mismatch" {
  let t_i32 = msf_make_func_type([], [ValType::i32()])
  let t_i64 = msf_make_func_type([], [ValType::i64()])
  let t_void = msf_void_func_type()
  let callee_i32 = Func::t_func([], [], TExpr::new([TInstr::i32_const(I32(1))]))
  let callee_i64 = Func::t_func(
    [],
    [],
    TExpr::new([TInstr::i64_const(I64(1L))]),
  )
  let wrap_a = Func::t_func(
    [],
    [],
    TExpr::new([TInstr::drop(TInstr::call(FuncIdx::new(0), []))]),
  )
  let wrap_b = Func::t_func(
    [],
    [],
    TExpr::new([TInstr::drop(TInstr::call(FuncIdx::new(1), []))]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_i32, t_i64, t_void]))
    .with_func_sec(
      FuncSec::new([
        TypeIdx::new(0),
        TypeIdx::new(1),
        TypeIdx::new(2),
        TypeIdx::new(2),
      ]),
    )
    .with_code_sec(CodeSec::new([callee_i32, callee_i64, wrap_a, wrap_b]))
  let out = msf_run(mod)
  match out.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 4)
    _ => fail("expected code section")
  }
}

///|
test "merge similar functions rejects locals mismatch" {
  let t = msf_void_func_type()
  let f0 = Func::t_func(
    [],
    [ValType::i32()],
    TExpr::new([TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(1)))]),
  )
  let f1 = Func::t_func([], [], TExpr::new([TInstr::nop()]))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([f0, f1]))
  let out = msf_run(mod)
  match out.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 2)
    _ => fail("expected code section")
  }
}

///|
test "merge similar functions profitability gate keeps tiny but merges larger" {
  let t = msf_void_func_type()
  let tiny0 = Func::t_func([], [], TExpr::new([TInstr::i32_const(I32(1))]))
  let tiny1 = Func::t_func([], [], TExpr::new([TInstr::i32_const(I32(2))]))
  let mod_tiny = Module::new()
    .with_type_sec(TypeSec::new([t]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([tiny0, tiny1]))
  let out_tiny = msf_run(mod_tiny)
  match out_tiny.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 2)
    _ => fail("expected code section")
  }
  let t2 = msf_i32_func_type()
  let big0 = Func::t_func([ValType::i32()], [], msf_binary_body(100, 7))
  let big1 = Func::t_func([ValType::i32()], [], msf_binary_body(101, 7))
  let mod_big = Module::new()
    .with_type_sec(TypeSec::new([t2]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([big0, big1]))
  let out_big = msf_run(mod_big)
  match out_big.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 3)
    _ => fail("expected code section")
  }
}

///|
test "merge similar functions enforces synthetic param limit" {
  let t = msf_void_func_type()
  let body_a_instrs : Array[TInstr] = []
  let body_b_instrs : Array[TInstr] = []
  for i = 0; i < 20; i = i + 1 {
    body_a_instrs.push(TInstr::drop(TInstr::i32_const(I32(i))))
    body_b_instrs.push(TInstr::drop(TInstr::i32_const(I32(i + 1))))
  }
  let f0 = Func::t_func([], [], TExpr::new(body_a_instrs))
  let f1 = Func::t_func([], [], TExpr::new(body_b_instrs))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([f0, f1]))
  let out = msf_run(mod)
  match out.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 2)
    _ => fail("expected code section")
  }
}

///|
test "merge similar functions is deterministic with multiple classes" {
  let t = msf_i32_func_type()
  let a0 = Func::t_func([ValType::i32()], [], msf_binary_body(10, 1))
  let a1 = Func::t_func([ValType::i32()], [], msf_binary_body(11, 1))
  let b0 = Func::t_func([ValType::i32()], [], msf_binary_body(20, 2))
  let b1 = Func::t_func([ValType::i32()], [], msf_binary_body(21, 2))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t]))
    .with_func_sec(
      FuncSec::new([
        TypeIdx::new(0),
        TypeIdx::new(0),
        TypeIdx::new(0),
        TypeIdx::new(0),
      ]),
    )
    .with_code_sec(CodeSec::new([a0, a1, b0, b1]))
  let out1 = msf_run(mod)
  let out2 = msf_run(mod)
  assert_eq(out1, out2)
  match out1.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 5)
    _ => fail("expected code section")
  }
}

///|
test "merge similar functions shifts var local indices in shared function" {
  let t = msf_i32_func_type()
  let f0 = Func::t_func(
    [ValType::i32()],
    [ValType::i32()],
    TExpr::new([
      TInstr::local_set(LocalIdx::new(1), TInstr::i32_const(I32(42))),
      TInstr::return_([
        TInstr::binary(
          BinaryOp::i32_add(),
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::local_get(LocalIdx::new(1)),
        ),
      ]),
    ]),
  )
  let f1 = Func::t_func(
    [ValType::i32()],
    [ValType::i32()],
    TExpr::new([
      TInstr::local_set(LocalIdx::new(1), TInstr::i32_const(I32(43))),
      TInstr::return_([
        TInstr::binary(
          BinaryOp::i32_add(),
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::local_get(LocalIdx::new(1)),
        ),
      ]),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([f0, f1]))
  let out = msf_run(mod)
  let shared_abs = msf_shared_abs_index(out)
  match out.code_sec {
    Some(CodeSec(funcs)) =>
      match funcs[shared_abs - msf_count_imported_funcs(out)] {
        TFunc(_, _, body) => {
          let mut saw_shifted_set = false
          let mut saw_shifted_get = false
let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
            self,
            _,
            instr : TInstr,
          ) {
            match instr.kind {
              TInstrKind::TLocalSet(LocalIdx(raw), _) if raw.reinterpret_as_int() ==
                2 => saw_shifted_set = true
              TInstrKind::TLocalGet(LocalIdx(raw)) if raw.reinterpret_as_int() ==
                2 => saw_shifted_get = true
              _ => ()
            }
            from_walk(self.walk_tinstruction_default((), instr))
          })
          ignore(walker.walk_texpr((), body))
          assert_true(saw_shifted_set)
          assert_true(saw_shifted_get)
        }
        _ => fail("expected shared function")
      }
    _ => fail("expected code section")
  }
  assert_eq(validate_module(out), Ok(()))
}
