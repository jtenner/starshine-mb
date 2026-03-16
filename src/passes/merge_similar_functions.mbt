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
struct MSFOrderedSite {
  node_id : Int
  value : MSFSiteValue
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
priv struct MSFAnalysisArtifactCounts {
  normalized_bodies : Int
  ordered_sites : Int
  site_maps : Int
  body_sizes : Int
} derive(Eq, Show)

///|
priv struct MSFModuleAnalysis {
  import_count : Int
  type_env : Env
  func_type_idxs : Array[TypeIdx]
  defined : Array[MSFDefinedFunc]
  by_def_idx : Map[Int, MSFDefinedFunc]
  normalized_bodies : Map[Int, TExpr]
  normalized_body_failures : Map[Int, Bool]
  ordered_sites : Map[Int, Array[MSFOrderedSite]]
  call_sites : Map[Int, Array[MSFCallSite]]
  site_maps : Map[Int, Map[Int, MSFSiteValue]]
  body_sizes : Map[Int, Int]
  mut normalized_body_compute_count : Int
  mut ordered_site_compute_count : Int
  mut site_map_compute_count : Int
  mut body_size_compute_count : Int
}

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
fn msf_make_type_env(mod : Module) -> Env {
  Env::new().with_module(mod)
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
  let type_env = msf_make_type_env(mod)
  let type_idxs = msf_collect_func_type_indices(mod)
  let out : Array[FuncType] = []
  for type_idx in type_idxs {
    match type_env.resolve_functype(type_idx) {
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
  type_env : Env,
) -> FuncType? {
  type_env.resolve_functype(type_idx)
}

///|
fn msf_verify_call_target_type(
  type_idx : TypeIdx,
  expected_arg_count : Int,
  type_env : Env,
) -> Result[Unit, String] {
  let FuncType(params, _) = match
    msf_resolve_func_type_for_type_idx(type_idx, type_env) {
    Some(ft) => ft
    None => return Err("missing function type for rewritten call target")
  }
  if params.length() != expected_arg_count {
    return Err("param arity mismatch for rewritten call site")
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
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(
    self,
    _,
    instr : TInstr,
  ) {
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
  for site in msf_collect_ordered_sites(body, []) {
    match site.value {
      CallTargetSite(target, _, is_return, arg_count) =>
        out.push({ node_id: site.node_id, target, arg_count, is_return })
      _ => ()
    }
  }
  out
}

///|
fn msf_collect_ordered_sites(
  body : TExpr,
  type_idxs : Array[TypeIdx],
) -> Array[MSFOrderedSite] {
  // Site ids are assigned by a single pre-order transformer walk: the id is
  // captured before visiting children, and every site-sensitive helper in this
  // pass depends on that exact numbering contract.
  let out : Array[MSFOrderedSite] = []
  let mut next_id = 0
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      instr : TInstr,
    ) {
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
            Some(vt) => out.push({ node_id: id, value: ConstSite(instr, vt) })
            None => ()
          }
        TInstrKind::TCall(target, _) | TInstrKind::TReturnCall(target, _) => {
          let is_return = match instr.kind {
            TInstrKind::TReturnCall(_, _) => true
            _ => false
          }
          let abs_idx = msf_func_idx_to_int(target)
          if abs_idx >= 0 &&
            (abs_idx < type_idxs.length() || type_idxs.is_empty()) {
            let call_type_idx = if type_idxs.is_empty() {
              TypeIdx::new(0)
            } else {
              type_idxs[abs_idx]
            }
            match instr.kind {
              TInstrKind::TCall(_, args) =>
                out.push({
                  node_id: id,
                  value: CallTargetSite(
                    target,
                    call_type_idx,
                    is_return,
                    args.length(),
                  ),
                })
              TInstrKind::TReturnCall(_, args) =>
                out.push({
                  node_id: id,
                  value: CallTargetSite(
                    target,
                    call_type_idx,
                    is_return,
                    args.length(),
                  ),
                })
              _ => ()
            }
          }
        }
        _ => ()
      }
      from_walk(self.walk_tinstruction_default((), instr))
    },
  )
  ignore(walker.walk_texpr((), body))
  out
}

///|
fn msf_collect_sites(
  body : TExpr,
  type_idxs : Array[TypeIdx],
) -> Map[Int, MSFSiteValue] {
  let out : Map[Int, MSFSiteValue] = Map::new()
  for site in msf_collect_ordered_sites(body, type_idxs) {
    out[site.node_id] = site.value
  }
  out
}

///|
fn msf_direct_call_kind_name(is_return : Bool) -> String {
  if is_return {
    "return_call"
  } else {
    "call"
  }
}

///|
fn msf_preflight_direct_call_error(
  caller_abs_idx : Int,
  node_id : Int,
  target : FuncIdx,
  is_return : Bool,
  detail : String,
) -> String {
  "merge_similar_functions: upstream-invalid direct call in preflight: " +
  detail +
  " kind=\{msf_direct_call_kind_name(is_return)} caller_abs_idx=\{caller_abs_idx} callee_abs_idx=\{msf_func_idx_to_int(target)} node_id=\{node_id}"
}

///|
fn msf_call_target_rewrite_error(reason : String) -> String {
  "merge_similar_functions: call_target rewrite metadata mismatch: " + reason
}

///|
fn msf_build_dense_node_to_param(params : Array[ParamInfo]) -> Array[Int] {
  let mut max_node_id = -1
  for param_idx = 0; param_idx < params.length(); param_idx = param_idx + 1 {
    for use_id in params[param_idx].uses {
      if use_id > max_node_id {
        max_node_id = use_id
      }
    }
  }
  if max_node_id < 0 {
    return []
  }
  let node_to_param = Array::make(max_node_id + 1, -1)
  for param_idx = 0; param_idx < params.length(); param_idx = param_idx + 1 {
    for use_id in params[param_idx].uses {
      if use_id >= 0 {
        node_to_param[use_id] = param_idx
      }
    }
  }
  node_to_param
}

///|
fn msf_dense_node_lookup(node_to_param : Array[Int], node_id : Int) -> Int? {
  if node_id < 0 || node_id >= node_to_param.length() {
    return None
  }
  let param_idx = node_to_param[node_id]
  if param_idx < 0 {
    None
  } else {
    Some(param_idx)
  }
}

///|
fn msf_validate_call_target_rewrite_site(
  node_id : Int,
  instr : TInstr,
  type_idx : TypeIdx,
  expected_arg_count : Int,
  expects_return : Bool,
  type_env : Env,
  func_type_idxs : Array[TypeIdx],
) -> Result[Unit, String] {
  let expected_kind = msf_direct_call_kind_name(expects_return)
  let (target, actual_arg_count, actual_is_return) = match instr.kind {
    TInstrKind::TCall(target, args) => (target, args.length(), false)
    TInstrKind::TReturnCall(target, args) => (target, args.length(), true)
    _ =>
      return Err(
        msf_call_target_rewrite_error(
          "kind mismatch node_id=\{node_id} expected=\{expected_kind} actual=non_call",
        ),
      )
  }
  let actual_kind = msf_direct_call_kind_name(actual_is_return)
  if actual_is_return != expects_return {
    return Err(
      msf_call_target_rewrite_error(
        "kind mismatch node_id=\{node_id} expected=\{expected_kind} actual=\{actual_kind}",
      ),
    )
  }
  if actual_arg_count != expected_arg_count {
    return Err(
      msf_call_target_rewrite_error(
        "arg count mismatch node_id=\{node_id} kind=\{actual_kind} expected=\{expected_arg_count} actual=\{actual_arg_count}",
      ),
    )
  }
  match msf_verify_call_target_type(type_idx, expected_arg_count, type_env) {
    Ok(_) => ()
    Err(e) =>
      return Err(msf_call_target_rewrite_error("node_id=\{node_id} \{e}"))
  }
  let callee_type_idx = match
    msf_resolve_callee_type_idx(target, func_type_idxs) {
    Ok(v) => v
    Err(e) =>
      return Err(
        msf_call_target_rewrite_error(
          "callee lookup failed node_id=\{node_id} kind=\{actual_kind} \{e}",
        ),
      )
  }
  if callee_type_idx != type_idx {
    return Err(
      msf_call_target_rewrite_error(
        "callee type mismatch node_id=\{node_id} kind=\{actual_kind} expected=\{type_idx} actual=\{callee_type_idx}",
      ),
    )
  }
  Ok(())
}

///|
fn msf_preflight_direct_call_site(
  type_env : Env,
  func_type_idxs : Array[TypeIdx],
  caller_abs_idx : Int,
  node_id : Int,
  target : FuncIdx,
  arg_count : Int,
  is_return : Bool,
) -> Result[Unit, String] {
  let callee_type_idx = match
    msf_resolve_callee_type_idx(target, func_type_idxs) {
    Ok(v) => v
    Err(_) =>
      return Err(
        msf_preflight_direct_call_error(
          caller_abs_idx, node_id, target, is_return, "callee out of range",
        ),
      )
  }
  let FuncType(params, _) = match type_env.resolve_functype(callee_type_idx) {
    Some(ft) => ft
    None =>
      return Err(
        msf_preflight_direct_call_error(
          caller_abs_idx, node_id, target, is_return, "callee type does not resolve to a function type",
        ),
      )
  }
  if params.length() != arg_count {
    return Err(
      msf_preflight_direct_call_error(
        caller_abs_idx,
        node_id,
        target,
        is_return,
        "arg count mismatch expected=\{params.length()} actual=\{arg_count}",
      ),
    )
  }
  Ok(())
}

///|
fn msf_prevalidate_call_target_rewrite_metadata(
  body : TExpr,
  params : Array[ParamInfo],
  type_env : Env,
  func_type_idxs : Array[TypeIdx],
) -> Result[Unit, String] {
  let node_to_param = msf_build_dense_node_to_param(params)
  let seen_call_target_uses = Array::make(node_to_param.length(), false)
  let mut next_id = 0
  let walker : ModuleTransformer[Unit, String] = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      instr : TInstr,
    ) {
      let node_id = next_id
      next_id += 1
      match msf_dense_node_lookup(node_to_param, node_id) {
        Some(param_idx) =>
          match params[param_idx].kind {
            CallTargetParam(type_idx, expected_arg_count, expects_return, _) => {
              seen_call_target_uses[node_id] = true
              match
                msf_validate_call_target_rewrite_site(
                  node_id, instr, type_idx, expected_arg_count, expects_return, type_env,
                  func_type_idxs,
                ) {
                Ok(_) => from_walk(self.walk_tinstruction_default((), instr))
                Err(e) => return error(e)
              }
            }
            _ => from_walk(self.walk_tinstruction_default((), instr))
          }
        None => from_walk(self.walk_tinstruction_default((), instr))
      }
    },
  )
  match walker.walk_texpr((), body) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  for param in params {
    match param.kind {
      CallTargetParam(_, _, expects_return, _) =>
        for use_id in param.uses {
          if use_id < 0 ||
            use_id >= seen_call_target_uses.length() ||
            !seen_call_target_uses[use_id] {
            return Err(
              msf_call_target_rewrite_error(
                "kind mismatch node_id=\{use_id} expected=\{msf_direct_call_kind_name(expects_return)} actual=missing",
              ),
            )
          }
        }
      _ => ()
    }
  }
  Ok(())
}

///|
fn msf_preflight_direct_calls(
  mod : Module,
  trace? : (String) -> Unit = msf_trace_noop,
  trace_all_funcs? : Bool = false,
) -> Result[Unit, String] {
  let preflight_start_ms = msf_trace_now_ms()
  if trace_all_funcs {
    trace("phase=preflight_direct_calls:start")
  }
  let import_count = msf_count_imported_funcs(mod)
  let type_env = msf_make_type_env(mod)
  let func_type_idxs = msf_collect_func_type_indices(mod)
  match mod.code_sec {
    Some(CodeSec(funcs)) =>
      for def_idx = 0; def_idx < funcs.length(); def_idx = def_idx + 1 {
        let caller_abs_idx = import_count + def_idx
        match funcs[def_idx] {
          TFunc(_, _, body) => {
            let mut next_id = 0
            let walker : ModuleTransformer[Unit, String] = ModuleTransformer::new().on_tinstruction_evt(fn(
                self,
                _,
                instr : TInstr,
              ) {
                let node_id = next_id
                next_id += 1
                match instr.kind {
                  TInstrKind::TCall(target, args) =>
                    match
                      msf_preflight_direct_call_site(
                        type_env,
                        func_type_idxs,
                        caller_abs_idx,
                        node_id,
                        target,
                        args.length(),
                        false,
                      ) {
                      Ok(_) =>
                        from_walk(self.walk_tinstruction_default((), instr))
                      Err(e) => return error(e)
                    }
                  TInstrKind::TReturnCall(target, args) =>
                    match
                      msf_preflight_direct_call_site(
                        type_env,
                        func_type_idxs,
                        caller_abs_idx,
                        node_id,
                        target,
                        args.length(),
                        true,
                      ) {
                      Ok(_) =>
                        from_walk(self.walk_tinstruction_default((), instr))
                      Err(e) => return error(e)
                    }
                  _ => from_walk(self.walk_tinstruction_default((), instr))
                }
              },
            )
            match walker.walk_texpr((), body) {
              Ok(_) => ()
              Err(e) => {
                if trace_all_funcs {
                  trace(
                    "phase=preflight_direct_calls:error elapsed_ms=\{msf_trace_elapsed_ms(preflight_start_ms)} \{e}",
                  )
                }
                return Err(e)
              }
            }
          }
          _ => ()
        }
      }
    None => ()
  }
  if trace_all_funcs {
    trace(
      "phase=preflight_direct_calls:done elapsed_ms=\{msf_trace_elapsed_ms(preflight_start_ms)}",
    )
  }
  Ok(())
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
fn msf_make_module_analysis(
  mod : Module,
  trace? : (String) -> Unit = msf_trace_noop,
  trace_all_funcs? : Bool = false,
) -> MSFModuleAnalysis {
  let import_count = msf_count_imported_funcs(mod)
  let type_env = msf_make_type_env(mod)
  let func_type_idxs = msf_collect_func_type_indices(mod)
  let func_types = msf_collect_func_types(mod)
  let defined = msf_collect_defined_funcs(
    mod,
    func_types,
    func_type_idxs,
    import_count,
    trace~,
    trace_all_funcs~,
  )
  let by_def_idx : Map[Int, MSFDefinedFunc] = Map::new()
  for func in defined {
    by_def_idx[func.def_idx] = func
  }
  {
    import_count,
    type_env,
    func_type_idxs,
    defined,
    by_def_idx,
    normalized_bodies: Map::new(),
    normalized_body_failures: Map::new(),
    ordered_sites: Map::new(),
    call_sites: Map::new(),
    site_maps: Map::new(),
    body_sizes: Map::new(),
    normalized_body_compute_count: 0,
    ordered_site_compute_count: 0,
    site_map_compute_count: 0,
    body_size_compute_count: 0,
  }
}

///|
fn msf_analysis_artifact_counts(
  analysis : MSFModuleAnalysis,
) -> MSFAnalysisArtifactCounts {
  {
    normalized_bodies: analysis.normalized_body_compute_count,
    ordered_sites: analysis.ordered_site_compute_count,
    site_maps: analysis.site_map_compute_count,
    body_sizes: analysis.body_size_compute_count,
  }
}

///|
fn msf_get_cached_defined_func(
  analysis : MSFModuleAnalysis,
  def_idx : Int,
) -> MSFDefinedFunc? {
  analysis.by_def_idx.get(def_idx)
}

///|
fn msf_get_normalized_body(
  analysis : MSFModuleAnalysis,
  func : MSFDefinedFunc,
) -> TExpr? {
  if analysis.normalized_body_failures.get(func.def_idx) == Some(true) {
    return None
  }
  match analysis.normalized_bodies.get(func.def_idx) {
    Some(body) => Some(body)
    None => {
      analysis.normalized_body_compute_count += 1
      match msf_normalize_body(func.body) {
        Ok(body) => {
          analysis.normalized_bodies[func.def_idx] = body
          Some(body)
        }
        Err(_) => {
          analysis.normalized_body_failures[func.def_idx] = true
          None
        }
      }
    }
  }
}

///|
fn msf_cache_site_artifacts(
  analysis : MSFModuleAnalysis,
  func : MSFDefinedFunc,
) -> Unit {
  match analysis.ordered_sites.get(func.def_idx) {
    Some(_) => ()
    None => {
      analysis.ordered_site_compute_count += 1
      let ordered = msf_collect_ordered_sites(
        func.body,
        analysis.func_type_idxs,
      )
      let calls : Array[MSFCallSite] = []
      for site in ordered {
        match site.value {
          CallTargetSite(target, _, is_return, arg_count) =>
            calls.push({ node_id: site.node_id, target, arg_count, is_return })
          _ => ()
        }
      }
      analysis.ordered_sites[func.def_idx] = ordered
      analysis.call_sites[func.def_idx] = calls
    }
  }
}

///|
fn msf_get_ordered_sites(
  analysis : MSFModuleAnalysis,
  func : MSFDefinedFunc,
) -> Array[MSFOrderedSite] {
  msf_cache_site_artifacts(analysis, func)
  analysis.ordered_sites.get(func.def_idx).unwrap_or([])
}

///|
fn msf_get_call_sites(
  analysis : MSFModuleAnalysis,
  func : MSFDefinedFunc,
) -> Array[MSFCallSite] {
  msf_cache_site_artifacts(analysis, func)
  analysis.call_sites.get(func.def_idx).unwrap_or([])
}

///|
fn msf_get_site_map(
  analysis : MSFModuleAnalysis,
  func : MSFDefinedFunc,
) -> Map[Int, MSFSiteValue] {
  match analysis.site_maps.get(func.def_idx) {
    Some(site_map) => site_map
    None => {
      let site_map : Map[Int, MSFSiteValue] = Map::new()
      for site in msf_get_ordered_sites(analysis, func) {
        site_map[site.node_id] = site.value
      }
      analysis.site_maps[func.def_idx] = site_map
      analysis.site_map_compute_count += 1
      site_map
    }
  }
}

///|
fn msf_get_body_size(
  analysis : MSFModuleAnalysis,
  func : MSFDefinedFunc,
) -> Int {
  match analysis.body_sizes.get(func.def_idx) {
    Some(size) => size
    None => {
      analysis.body_size_compute_count += 1
      let size = msf_measure_body(func.body)
      analysis.body_sizes[func.def_idx] = size
      size
    }
  }
}

///|
fn msf_same_callee_type(
  lhs_target : FuncIdx,
  rhs_target : FuncIdx,
  func_type_idxs : Array[TypeIdx],
  type_env : Env,
) -> Bool {
  let lhs_abs = msf_func_idx_to_int(lhs_target)
  let rhs_abs = msf_func_idx_to_int(rhs_target)
  if lhs_abs < 0 || rhs_abs < 0 {
    return false
  }
  if lhs_abs >= func_type_idxs.length() || rhs_abs >= func_type_idxs.length() {
    return false
  }
  let lhs_type_idx = func_type_idxs[lhs_abs]
  let rhs_type_idx = func_type_idxs[rhs_abs]
  if lhs_type_idx != rhs_type_idx {
    return false
  }
  match
    (
      type_env.resolve_functype(lhs_type_idx),
      type_env.resolve_functype(rhs_type_idx),
    ) {
    (Some(lhs_ft), Some(rhs_ft)) => lhs_ft == rhs_ft
    _ => false
  }
}

///|
fn are_in_equivalent_class(
  lhs : MSFDefinedFunc,
  rhs : MSFDefinedFunc,
  analysis : MSFModuleAnalysis,
) -> Bool {
  if lhs.type_idx != rhs.type_idx {
    return false
  }
  if lhs.locals.length() != rhs.locals.length() {
    return false
  }
  let lhs_norm = match msf_get_normalized_body(analysis, lhs) {
    Some(x) => x
    None => return false
  }
  let rhs_norm = match msf_get_normalized_body(analysis, rhs) {
    Some(x) => x
    None => return false
  }
  if lhs_norm != rhs_norm {
    return false
  }
  let lhs_calls = msf_get_call_sites(analysis, lhs)
  let rhs_calls = msf_get_call_sites(analysis, rhs)
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
    if !msf_same_callee_type(
        lc.target,
        rc.target,
        analysis.func_type_idxs,
        analysis.type_env,
      ) {
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
fn msf_collect_equivalent_classes_from_analysis(
  analysis : MSFModuleAnalysis,
  trace? : (String) -> Unit = msf_trace_noop,
  trace_all_funcs? : Bool = false,
) -> Array[EquivalentClass] {
  let collect_start_ms = msf_trace_now_ms()
  let import_count = analysis.import_count
  let defined = analysis.defined
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
        if are_in_equivalent_class(candidate, rep, analysis) {
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
  analysis : MSFModuleAnalysis,
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
  let scan_members_start_ms = msf_trace_now_ms()
  if trace_all_funcs {
    trace("func[\{ordinal}] phase=derive_params_internal:scan_members:start")
  }
  let mut primary_param_count = 0
  let mut primary_func : MSFDefinedFunc? = None
  for i = 0; i < clazz.member_def_idxs.length(); i = i + 1 {
    let def_idx = clazz.member_def_idxs[i]
    match msf_get_cached_defined_func(analysis, def_idx) {
      Some(func) =>
        if def_idx == clazz.primary_def_idx {
          primary_func = Some(func)
          let FuncType(params, _) = func.func_type
          primary_param_count = params.length()
        }
      None => {
        if trace_all_funcs {
          trace(
            "func[\{ordinal}] phase=derive_params_internal:scan_members:error reason=member_out_of_range def_idx=\{def_idx} elapsed_ms=\{msf_trace_elapsed_ms(scan_members_start_ms)}",
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
  let primary_func = match primary_func {
    Some(func) => func
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
    match msf_get_cached_defined_func(analysis, def_idx) {
      Some(func) => site_maps.push(msf_get_site_map(analysis, func))
      None => {
        if trace_all_funcs {
          trace(
            "func[\{ordinal}] phase=derive_params_internal:collect_sites:error reason=member_out_of_range def_idx=\{def_idx} elapsed_ms=\{msf_trace_elapsed_ms(collect_sites_start_ms)}",
          )
        }
        return None
      }
    }
  }
  let primary_ordered_sites = msf_get_ordered_sites(analysis, primary_func)
  if trace_all_funcs {
    trace(
      "func[\{ordinal}] phase=derive_params_internal:collect_sites:done elapsed_ms=\{msf_trace_elapsed_ms(collect_sites_start_ms)} primary_site_count=\{primary_ordered_sites.length()}",
    )
  }
  let build_params_start_ms = msf_trace_now_ms()
  if trace_all_funcs {
    trace("func[\{ordinal}] phase=derive_params_internal:build_params:start")
  }
  let params : Array[ParamInfo] = []
  let key_to_idx : Map[MSFParamKey, Int] = Map::new()
  for site in primary_ordered_sites {
    let node_id = site.node_id
    let primary_site = site.value
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
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      instr : TInstr,
    ) {
      n += 1
      from_walk(self.walk_tinstruction_default((), instr))
    },
  )
  ignore(walker.walk_texpr((), body))
  n
}

///|
fn has_merge_benefit(
  clazz : EquivalentClass,
  analysis : MSFModuleAnalysis,
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
  if clazz.member_def_idxs.length() < 2 {
    if trace_all_funcs {
      trace(
        "func[\{ordinal}] phase=benefit_internal:done elapsed_ms=\{msf_trace_elapsed_ms(benefit_start_ms)} beneficial=false reason=single_member",
      )
    }
    return false
  }
  let primary_def = clazz.primary_def_idx
  let primary_func = match msf_get_cached_defined_func(analysis, primary_def) {
    Some(func) => func
    None => {
      if trace_all_funcs {
        trace(
          "func[\{ordinal}] phase=benefit_internal:error reason=primary_out_of_range def_idx=\{primary_def} elapsed_ms=\{msf_trace_elapsed_ms(benefit_start_ms)}",
        )
      }
      return false
    }
  }
  let FuncType(primary_params, _) = primary_func.func_type
  let measure_start_ms = msf_trace_now_ms()
  if trace_all_funcs {
    trace("func[\{ordinal}] phase=benefit_internal:measure:start")
  }
  let primary_body_size = msf_get_body_size(analysis, primary_func)
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
fn msf_count_param_uses(params : Array[ParamInfo]) -> Int {
  let mut n = 0
  for param in params {
    n += param.uses.length()
  }
  n
}

///|
fn msf_rewrite_shared_body(
  body : TExpr,
  primary_param_count : Int,
  params : Array[ParamInfo],
  type_env : Env,
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
  let node_to_param = msf_build_dense_node_to_param(params)
  if trace_all_funcs {
    trace(
      "func[\{ordinal}] phase=shared_rewrite:build_map:done elapsed_ms=\{msf_trace_elapsed_ms(map_start_ms)} mapped_nodes=\{msf_count_param_uses(params)} dense_slots=\{node_to_param.length()}",
    )
  }
  let mut next_id = 0
  let shift = params.length()
  if trace_all_funcs {
    trace("func[\{ordinal}] phase=shared_rewrite:walk:start shift=\{shift}")
  }
  let walk_start_ms = msf_trace_now_ms()
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(
    self,
    _,
    instr : TInstr,
  ) {
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
    let replaced = match msf_dense_node_lookup(node_to_param, node_id) {
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
            ignore(target)
            ignore(args)
            match
              msf_validate_call_target_rewrite_site(
                node_id, shifted, type_idx, expected_arg_count, expects_return, type_env,
                func_type_idxs,
              ) {
              Ok(_) => ()
              Err(e) => return error(e)
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
            ignore(target)
            ignore(args)
            match
              msf_validate_call_target_rewrite_site(
                node_id, shifted, type_idx, expected_arg_count, expects_return, type_env,
                func_type_idxs,
              ) {
              Ok(_) => ()
              Err(e) => return error(e)
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
              "merge_similar_functions: call_target rewrite metadata mismatch: kind mismatch",
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
  let next_type_idx = TypeIdx::new(
    msf_make_type_env(mod).global_types.length().reinterpret_as_uint(),
  )
  let recs = match mod.type_sec {
    Some(TypeSec(items)) => items.copy()
    None => []
  }
  recs.push(msf_make_func_type(params, results))
  (mod.with_type_sec(TypeSec::new(recs)), next_type_idx)
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
  let type_env = msf_make_type_env(mod)
  let func_type_idxs = msf_collect_func_type_indices(mod)
  match
    msf_prevalidate_call_target_rewrite_metadata(
      primary_body, params, type_env, func_type_idxs,
    ) {
    Ok(_) => ()
    Err(e) => {
      if trace_all_funcs {
        trace(
          "func[\{ordinal}] phase=create_shared:rewrite_body:error elapsed_ms=\{msf_trace_elapsed_ms(create_start_ms)} \{e}",
        )
      }
      return Err(msf_attach_rewrite_debug_dump(mod, clazz, params, e))
    }
  }
  let rewritten_body = match
    msf_rewrite_shared_body(
      primary_body,
      primary_params.length(),
      params,
      type_env,
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
      let body = TExpr::new([TInstr::return_([TInstr::call(shared, args)])])
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
  let supports_typed_ref_lowering = msf_module_has_typed_ref_lowering_evidence(
    mod,
  )
  trace("start defined=\{defined_funcs}")
  match msf_preflight_direct_calls(mod, trace~, trace_all_funcs~) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  let analysis = msf_make_module_analysis(mod, trace~, trace_all_funcs~)
  let classes = msf_collect_equivalent_classes_from_analysis(
    analysis,
    trace~,
    trace_all_funcs~,
  )
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
      derive_params(clazz, analysis, trace~, trace_all_funcs~, ordinal~) {
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
    let mut has_call_target_param = false
    for param in params {
      match param.kind {
        CallTargetParam(_, _, _, _) => {
          has_call_target_param = true
          break
        }
        _ => ()
      }
    }
    if has_call_target_param && !supports_typed_ref_lowering {
      if trace_all_funcs {
        trace(
          "func[\{ordinal}] done elapsed_ms=\{msf_trace_elapsed_ms(class_start_ms)} merged=false reason=typed_ref_lowering_unsupported",
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
      analysis,
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
        instrs: [
          {
            kind: TInstrKind::TReturn(
              [{ kind: TInstrKind::TCall(FuncIdx(raw), args), .. }]
            ),
            ..,
          },
        ],
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
fn msf_has_tail_call(body : TExpr) -> Bool {
  let mut found = false
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      instr : TInstr,
    ) {
      match instr.kind {
        TInstrKind::TReturnCall(_, _)
        | TInstrKind::TReturnCallIndirect(_, _, _, _)
        | TInstrKind::TReturnCallRef(_, _, _) => found = true
        _ => ()
      }
      from_walk(self.walk_tinstruction_default((), instr))
    },
  )
  ignore(walker.walk_texpr((), body))
  found
}

///|
fn msf_module_has_typed_ref_lowering_evidence(mod : Module) -> Bool {
  match mod.code_sec {
    Some(CodeSec(funcs)) => {
      let mut found = false
      for func in funcs {
        match func {
          TFunc(_, _, body) => {
            let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
                self,
                _,
                instr : TInstr,
              ) {
                match instr.kind {
                  TInstrKind::TCallRef(_, _, _)
                  | TInstrKind::TReturnCallRef(_, _, _) => found = true
                  TInstrKind::TRefCast(_, HeapType(TypeIdx(_)), _)
                  | TInstrKind::TRefCastDescEq(_, HeapType(TypeIdx(_)), _) =>
                    found = true
                  _ => ()
                }
                from_walk(self.walk_tinstruction_default((), instr))
              },
            )
            ignore(walker.walk_texpr((), body))
            if found {
              return true
            }
          }
          _ => ()
        }
      }
      false
    }
    None => false
  }
}

///|
fn msf_contains_call_ref(body : TExpr) -> Bool {
  let mut found = false
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      instr : TInstr,
    ) {
      match instr.kind {
        TInstrKind::TCallRef(_, _, _) | TInstrKind::TReturnCallRef(_, _, _) =>
          found = true
        _ => ()
      }
      from_walk(self.walk_tinstruction_default((), instr))
    },
  )
  ignore(walker.walk_texpr((), body))
  found
}

///|
fn msf_typed_ref_seed_func(
  callee_type_idx : TypeIdx,
  seed_type : RecType,
) -> (RecType, Func) {
  (
    seed_type,
    Func::t_func(
      [ValType::funcref()],
      [],
      TExpr::new([
        TInstr::drop(
          TInstr::ref_cast(
            true,
            HeapType::new(callee_type_idx),
            TInstr::local_get(LocalIdx::new(0)),
          ),
        ),
        TInstr::return_([]),
      ]),
    ),
  )
}

///|
test "merge similar functions preflight rejects upstream-invalid direct call arity" {
  let t_callee = msf_make_func_type([ValType::i32()], [ValType::i32()])
  let t_wrap = msf_make_func_type([], [ValType::i32()])
  let callee = Func::t_func(
    [ValType::i32()],
    [ValType::i32()],
    TExpr::new([TInstr::local_get(LocalIdx::new(0))]),
  )
  let invalid_wrap = Func::t_func(
    [],
    [ValType::i32()],
    TExpr::new([TInstr::call(FuncIdx::new(0), [])]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_callee, t_wrap]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(CodeSec::new([callee, invalid_wrap]))
  match merge_similar_functions(mod) {
    Ok(_) => fail("expected preflight to reject upstream-invalid direct call")
    Err(e) => {
      assert_true(e.contains("upstream-invalid direct call in preflight"))
      assert_true(e.contains("expected=1 actual=0"))
      assert_true(e.contains("kind=call"))
    }
  }
}

///|
test "merge similar functions preflight rejects upstream-invalid return_call arity" {
  let t_callee = msf_make_func_type([ValType::i32()], [ValType::i32()])
  let t_wrap = msf_make_func_type([], [ValType::i32()])
  let callee = Func::t_func(
    [ValType::i32()],
    [ValType::i32()],
    TExpr::new([TInstr::local_get(LocalIdx::new(0))]),
  )
  let invalid_wrap = Func::t_func(
    [],
    [ValType::i32()],
    TExpr::new([TInstr::return_call(FuncIdx::new(0), [])]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_callee, t_wrap]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(CodeSec::new([callee, invalid_wrap]))
  match merge_similar_functions(mod) {
    Ok(_) =>
      fail("expected preflight to reject upstream-invalid direct return_call")
    Err(e) => {
      assert_true(e.contains("upstream-invalid direct call in preflight"))
      assert_true(e.contains("expected=1 actual=0"))
      assert_true(e.contains("kind=return_call"))
    }
  }
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
      match funcs[0] {
        TFunc(_, _, body) => assert_false(msf_has_tail_call(body))
        _ => fail("expected typed forwarder")
      }
      match funcs[1] {
        TFunc(_, _, body) => assert_false(msf_has_tail_call(body))
        _ => fail("expected typed forwarder")
      }
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
            },
          )
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
              },
            )
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
  let seed_type = msf_make_func_type([ValType::funcref()], [])
  let (_, typed_ref_seed) = msf_typed_ref_seed_func(TypeIdx::new(0), seed_type)
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
    .with_type_sec(TypeSec::new([t_callee, t_wrap, seed_type]))
    .with_func_sec(
      FuncSec::new([
        TypeIdx::new(0),
        TypeIdx::new(0),
        TypeIdx::new(1),
        TypeIdx::new(1),
        TypeIdx::new(2),
      ]),
    )
    .with_code_sec(
      CodeSec::new([callee_a, callee_b, wrap_a, wrap_b, typed_ref_seed]),
    )
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
      match funcs[2] {
        TFunc(_, _, body) => assert_false(msf_has_tail_call(body))
        _ => fail("expected typed thunk")
      }
      match funcs[3] {
        TFunc(_, _, body) => assert_false(msf_has_tail_call(body))
        _ => fail("expected typed thunk")
      }
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
            },
          )
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
      msf_make_type_env(
        Module::new().with_type_sec(
          TypeSec::new([
            msf_make_func_type([ValType::i32(), ValType::i32()], [
              ValType::i32(),
            ]),
          ]),
        ),
      ),
      [TypeIdx::new(0)],
    ) {
    Ok(_) =>
      fail(
        "expected msf_rewrite_shared_body to reject mismatched call-target arity",
      )
    Err(e) =>
      assert_true(
        e.contains("call_target rewrite metadata mismatch: arg count mismatch"),
      )
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
      assert_true(
        e.contains("call_target rewrite metadata mismatch: arg count mismatch"),
      )
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
      msf_make_type_env(
        Module::new().with_type_sec(
          TypeSec::new([msf_make_func_type([ValType::i32()], [ValType::i32()])]),
        ),
      ),
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
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      instr : TInstr,
    ) {
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
    },
  )
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
      msf_make_type_env(
        Module::new().with_type_sec(
          TypeSec::new([
            msf_make_func_type([], [ValType::i32()]),
            msf_make_func_type([ValType::i32()], [ValType::i32()]),
          ]),
        ),
      ),
      [TypeIdx::new(1), TypeIdx::new(0)],
    ) {
    Ok(out) => out
    Err(e) =>
      fail(
        "expected msf_rewrite_shared_body to accept arity based on the callee type idx: \{e}",
      )
  }
  let mut saw_call_ref = false
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      instr : TInstr,
    ) {
      match instr.kind {
        TInstrKind::TCallRef(TypeIdx(raw), args, _) =>
          if raw.reinterpret_as_int() == 1 && args.length() == 1 {
            saw_call_ref = true
          }
        _ => ()
      }
      from_walk(self.walk_tinstruction_default((), instr))
    },
  )
  ignore(walker.walk_texpr((), rewritten))
  assert_true(saw_call_ref)
}

///|
test "merge similar functions reports call kind mismatch details" {
  let body = TExpr::new([
    TInstr::return_call(FuncIdx::new(0), [TInstr::local_get(LocalIdx::new(0))]),
  ])
  let sites = msf_collect_sites(body, [TypeIdx::new(0)])
  let mut call_node = -1
  for entry in sites {
    let (node_id, site) = entry
    match site {
      CallTargetSite(_, _, true, _) => call_node = node_id
      _ => ()
    }
  }
  assert_true(call_node >= 0)
  let params : Array[ParamInfo] = [
    {
      kind: CallTargetParam(TypeIdx::new(0), 1, false, [
        FuncIdx::new(0),
        FuncIdx::new(1),
      ]),
      uses: [call_node],
    },
  ]
  match
    msf_rewrite_shared_body(
      body,
      1,
      params,
      msf_make_type_env(
        Module::new().with_type_sec(
          TypeSec::new([msf_make_func_type([ValType::i32()], [ValType::i32()])]),
        ),
      ),
      [TypeIdx::new(0)],
    ) {
    Ok(_) =>
      fail("expected msf_rewrite_shared_body to reject call kind mismatch")
    Err(e) => {
      assert_true(
        e.contains("call_target rewrite metadata mismatch: kind mismatch"),
      )
      assert_true(e.contains("expected=call"))
      assert_true(e.contains("actual=return_call"))
      assert_true(e.contains("node_id="))
    }
  }
}

///|
test "merge similar functions reports callee type mismatch details" {
  let body = TExpr::new([
    TInstr::call(FuncIdx::new(0), [TInstr::local_get(LocalIdx::new(0))]),
  ])
  let sites = msf_collect_sites(body, [TypeIdx::new(0), TypeIdx::new(1)])
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
  match
    msf_rewrite_shared_body(
      body,
      1,
      params,
      msf_make_type_env(
        Module::new().with_type_sec(
          TypeSec::new([
            msf_make_func_type([ValType::i32()], [ValType::i32()]),
            msf_make_func_type([ValType::i32()], [ValType::i32()]),
          ]),
        ),
      ),
      [TypeIdx::new(0), TypeIdx::new(1)],
    ) {
    Ok(_) =>
      fail("expected msf_rewrite_shared_body to reject callee type mismatch")
    Err(e) => {
      assert_true(
        e.contains(
          "call_target rewrite metadata mismatch: callee type mismatch",
        ),
      )
      assert_true(e.contains("expected=(Type 1)"))
      assert_true(e.contains("actual=(Type 0)"))
      assert_true(e.contains("node_id="))
    }
  }
}

///|
test "merge similar functions dense node lookup preserves sparse param uses" {
  let params : Array[ParamInfo] = [
    {
      kind: LiteralParam(ValType::i32(), [
        TInstr::i32_const(I32(1)),
        TInstr::i32_const(I32(2)),
      ]),
      uses: [2, 5],
    },
    {
      kind: CallTargetParam(TypeIdx::new(0), 1, false, [
        FuncIdx::new(0),
        FuncIdx::new(1),
      ]),
      uses: [9],
    },
  ]
  let node_to_param = msf_build_dense_node_to_param(params)
  assert_eq(node_to_param.length(), 10)
  assert_eq(msf_dense_node_lookup(node_to_param, -1), None)
  assert_eq(msf_dense_node_lookup(node_to_param, 0), None)
  assert_eq(msf_dense_node_lookup(node_to_param, 2), Some(0))
  assert_eq(msf_dense_node_lookup(node_to_param, 5), Some(0))
  assert_eq(msf_dense_node_lookup(node_to_param, 9), Some(1))
  assert_eq(msf_dense_node_lookup(node_to_param, 10), None)
}

///|
test "merge similar functions ordered sites stay stable across reruns" {
  let body = TExpr::new([
    TInstr::drop(TInstr::i32_const(I32(1))),
    TInstr::call(FuncIdx::new(0), [TInstr::i32_const(I32(2))]),
    TInstr::return_call(FuncIdx::new(1), [TInstr::i32_const(I32(3))]),
  ])
  let sites0 = msf_collect_ordered_sites(body, [
    TypeIdx::new(0),
    TypeIdx::new(0),
  ])
  let sites1 = msf_collect_ordered_sites(body, [
    TypeIdx::new(0),
    TypeIdx::new(0),
  ])
  assert_eq(sites0, sites1)
  let ids : Array[Int] = []
  let kinds : Array[String] = []
  for site in sites0 {
    ids.push(site.node_id)
    match site.value {
      ConstSite(_, _) => kinds.push("const")
      CallTargetSite(_, _, is_return, _) =>
        kinds.push(if is_return { "return_call" } else { "call" })
    }
  }
  assert_eq(ids, [1, 2, 3, 4, 5])
  assert_eq(kinds, ["const", "call", "const", "return_call", "const"])
}

///|
test "merge similar functions call-site ids reuse ordered site numbering" {
  let body = TExpr::new([
    TInstr::drop(TInstr::i32_const(I32(1))),
    TInstr::call(FuncIdx::new(0), [TInstr::i32_const(I32(2))]),
    TInstr::return_call(FuncIdx::new(1), [TInstr::i32_const(I32(3))]),
  ])
  let ordered = msf_collect_ordered_sites(body, [
    TypeIdx::new(0),
    TypeIdx::new(0),
  ])
  let calls = msf_collect_call_sites(body)
  let expected : Array[MSFCallSite] = []
  for site in ordered {
    match site.value {
      CallTargetSite(target, _, is_return, arg_count) =>
        expected.push({ node_id: site.node_id, target, arg_count, is_return })
      _ => ()
    }
  }
  assert_eq(calls, expected)
}

///|
test "merge similar functions analysis cache reuses per-function artifacts" {
  let t = msf_i32_func_type()
  let funcs = [
    Func::t_func([ValType::i32()], [ValType::i32()], msf_binary_body(3, 9)),
    Func::t_func([ValType::i32()], [ValType::i32()], msf_binary_body(5, 9)),
    Func::t_func([ValType::i32()], [ValType::i32()], msf_binary_body(7, 9)),
    Func::t_func([ValType::i32()], [ValType::i32()], msf_binary_body(11, 9)),
  ]
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
    .with_code_sec(CodeSec::new(funcs))
  let analysis = msf_make_module_analysis(mod)
  let classes = msf_collect_equivalent_classes_from_analysis(analysis)
  assert_eq(classes.length(), 1)
  assert_eq(msf_analysis_artifact_counts(analysis), {
    normalized_bodies: 4,
    ordered_sites: 4,
    site_maps: 0,
    body_sizes: 0,
  })
  let clazz = classes[0]
  let params0 = derive_params(clazz, analysis).unwrap()
  let params1 = derive_params(clazz, analysis).unwrap()
  assert_eq(params0, params1)
  assert_eq(params0.length(), 1)
  assert_eq(msf_analysis_artifact_counts(analysis), {
    normalized_bodies: 4,
    ordered_sites: 4,
    site_maps: 4,
    body_sizes: 0,
  })
  assert_true(has_merge_benefit(clazz, analysis, params0))
  assert_true(has_merge_benefit(clazz, analysis, params1))
  assert_eq(msf_analysis_artifact_counts(analysis), {
    normalized_bodies: 4,
    ordered_sites: 4,
    site_maps: 4,
    body_sizes: 1,
  })
}

///|
test "merge similar functions appends shared type index after flattened rec groups" {
  let grouped_types = RecType::group([
    SubType::comp_type(CompType::func([], [])),
    SubType::comp_type(CompType::struct_([])),
  ])
  let mod = Module::new().with_type_sec(TypeSec::new([grouped_types]))
  let (with_type, shared_type_idx) = msf_append_func_type(
    mod,
    [ValType::i32()],
    [ValType::i64()],
  )
  assert_eq(shared_type_idx, TypeIdx::new(2))
  let env = Env::new().with_module(with_type)
  match env.resolve_functype(shared_type_idx) {
    Some(FuncType(params, results)) => {
      assert_eq(params, [ValType::i32()])
      assert_eq(results, [ValType::i64()])
    }
    _ => fail("expected appended shared function type to resolve")
  }
}

///|
test "merge similar functions stays valid when shared type follows rec groups" {
  let grouped_types = RecType::group([
    SubType::comp_type(CompType::func([], [])),
    SubType::comp_type(CompType::struct_([])),
  ])
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
    .with_type_sec(TypeSec::new([grouped_types, t_callee, t_wrap]))
    .with_func_sec(
      FuncSec::new([
        TypeIdx::new(2),
        TypeIdx::new(2),
        TypeIdx::new(3),
        TypeIdx::new(3),
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
test "merge similar functions accepts safe call-target arity" {
  let t_callee = msf_make_func_type([ValType::i32()], [ValType::i32()])
  let t_wrap = msf_make_func_type([], [ValType::i32()])
  let seed_type = msf_make_func_type([ValType::funcref()], [])
  let (_, typed_ref_seed) = msf_typed_ref_seed_func(TypeIdx::new(0), seed_type)
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
    .with_type_sec(TypeSec::new([t_callee, t_wrap, seed_type]))
    .with_func_sec(
      FuncSec::new([
        TypeIdx::new(0),
        TypeIdx::new(0),
        TypeIdx::new(1),
        TypeIdx::new(1),
        TypeIdx::new(2),
      ]),
    )
    .with_code_sec(
      CodeSec::new([callee_a, callee_b, wrap_a, wrap_b, typed_ref_seed]),
    )
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
test "merge similar functions skips call-target merge without typed ref evidence" {
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
  let out = msf_run(mod)
  assert_eq(validate_module(out), Ok(()))
  match out.code_sec {
    Some(CodeSec(funcs)) => {
      assert_eq(funcs.length(), 4)
      match funcs[2] {
        TFunc(_, _, body) => assert_false(msf_contains_call_ref(body))
        _ => fail("expected wrapper function")
      }
      match funcs[3] {
        TFunc(_, _, body) => assert_false(msf_contains_call_ref(body))
        _ => fail("expected wrapper function")
      }
    }
    _ => fail("expected code section")
  }
}

///|
test "merge similar functions declares synthesized ref.func call targets" {
  let t_callee = msf_make_func_type([ValType::i32()], [ValType::i32()])
  let t_wrap = msf_make_func_type([], [])
  let seed_type = msf_make_func_type([ValType::funcref()], [])
  let (_, typed_ref_seed) = msf_typed_ref_seed_func(TypeIdx::new(0), seed_type)
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
    .with_type_sec(TypeSec::new([t_callee, t_wrap, seed_type]))
    .with_func_sec(
      FuncSec::new([
        TypeIdx::new(0),
        TypeIdx::new(0),
        TypeIdx::new(1),
        TypeIdx::new(1),
        TypeIdx::new(2),
      ]),
    )
    .with_code_sec(
      CodeSec::new([callee_a, callee_b, wrap_a, wrap_b, typed_ref_seed]),
    )
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
            },
          )
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
