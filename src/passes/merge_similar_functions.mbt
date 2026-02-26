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
  CallTargetSite(FuncIdx, TypeIdx, Bool)
} derive(Eq, Hash, Show)

///|
enum MSFParamKey {
  ConstParamKey(ValType, Array[TInstr])
  CallParamKey(TypeIdx, Array[FuncIdx])
} derive(Eq, Hash)

///|
enum MSFParamKind {
  LiteralParam(ValType, Array[TInstr])
  CallTargetParam(TypeIdx, Array[FuncIdx])
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
  single_rec_type(comp_type_sub_type(func_comp_type(params, results)))
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
fn msf_zero_const_like(instr : TInstr) -> TInstr {
  match instr {
    TI32Const(_) => TInstr::i32_const(I32(0))
    TI64Const(_) => TInstr::i64_const(I64(0L))
    TF32Const(_) => TInstr::f32_const(F32(0.0))
    TF64Const(_) => TInstr::f64_const(F64(0.0))
    TRefNull(ht) => TInstr::ref_null(ht)
    TRefFunc(_) => TInstr::ref_func(FuncIdx::new(0))
    TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
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
  match instr {
    TI32Const(_) => Some(ValType::i32())
    TI64Const(_) => Some(ValType::i64())
    TF32Const(_) => Some(ValType::f32())
    TF64Const(_) => Some(ValType::f64())
    TRefNull(ht) => Some(ValType::ref_type(RefType::new(true, ht)))
    TRefFunc(_) =>
      Some(
        ValType::ref_type(
          RefType::new(false, HeapType::abs(AbsHeapType::func())),
        ),
      )
    TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
      Some(ValType::v128())
    _ => None
  }
}

///|
fn msf_tag_hash(instr : TInstr) -> UInt64 {
  let tag : UInt64 = match instr {
    TI32Const(_) => 1UL
    TI64Const(_) => 2UL
    TF32Const(_) => 3UL
    TF64Const(_) => 4UL
    TRefNull(_) => 5UL
    TRefFunc(_) => 6UL
    TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) => 7UL
    TUnreachable => 8UL
    TNop => 9UL
    TLocalGet(_) => 10UL
    TGlobalGet(_) => 11UL
    TMemorySize(_) => 12UL
    TTableSize(_) => 13UL
    TUnary(_, _) => 14UL
    TDrop(_) => 15UL
    TLocalSet(_, _) => 16UL
    TLocalTee(_, _) => 17UL
    TGlobalSet(_, _) => 18UL
    TRefIsNull(_) => 19UL
    TRefAsNonNull(_) => 20UL
    TI31GetS(_) => 21UL
    TI31GetU(_) => 22UL
    TRefI31(_) => 23UL
    TArrayLen(_) => 24UL
    TAnyConvertExtern(_) => 25UL
    TExternConvertAny(_) => 26UL
    TThrowRef(_) => 27UL
    TBinary(_, _, _) => 28UL
    TRefEq(_, _) => 29UL
    TStore(_, _, _, _) => 30UL
    TLoad(_, _, _) => 31UL
    TMemoryGrow(_, _) => 32UL
    TMemoryAtomicNotify(_, _, _) => 200UL
    TMemoryAtomicWait32(_, _, _, _) => 201UL
    TMemoryAtomicWait64(_, _, _, _) => 202UL
    TAtomicFence => 203UL
    TAtomicRmw(_, _, _, _) => 204UL
    TAtomicCmpxchg(_, _, _, _, _) => 205UL
    TMemoryFill(_, _, _, _) => 33UL
    TMemoryCopy(_, _, _, _, _) => 34UL
    TMemoryInit(_, _, _, _, _) => 35UL
    TDataDrop(_) => 36UL
    TTableGet(_, _) => 37UL
    TTableSet(_, _, _) => 38UL
    TTableGrow(_, _, _) => 39UL
    TTableFill(_, _, _, _) => 40UL
    TTableCopy(_, _, _, _, _) => 41UL
    TTableInit(_, _, _, _, _) => 42UL
    TElemDrop(_) => 43UL
    TCall(_, _) => 44UL
    TCallIndirect(_, _, _, _) => 45UL
    TCallRef(_, _, _) => 46UL
    TReturnCall(_, _) => 47UL
    TReturnCallIndirect(_, _, _, _) => 48UL
    TReturnCallRef(_, _, _) => 49UL
    TBlock(_, _) => 50UL
    TLoop(_, _) => 51UL
    TIf(_, _, _, _) => 52UL
    TTryTable(_, _, _) => 53UL
    TThrow(_, _) => 54UL
    TBr(_, _) => 55UL
    TBrIf(_, _, _) => 56UL
    TBrTable(_, _, _, _) => 57UL
    TBrOnNull(_, _, _) => 58UL
    TBrOnNonNull(_, _, _) => 59UL
    TBrOnCast(_, _, _, _, _, _) => 60UL
    TBrOnCastFail(_, _, _, _, _, _) => 61UL
    TReturn(_) => 62UL
    TSelect(_, _, _, _) => 63UL
    TStructNew(_, _) => 64UL
    TStructNewDefault(_) => 65UL
    TStructGet(_, _, _) => 66UL
    TStructGetS(_, _, _) => 67UL
    TStructGetU(_, _, _) => 68UL
    TStructSet(_, _, _, _) => 69UL
    TArrayNew(_, _, _) => 70UL
    TArrayNewDefault(_, _) => 71UL
    TArrayNewFixed(_, _) => 72UL
    TArrayNewData(_, _, _, _) => 73UL
    TArrayNewElem(_, _, _, _) => 74UL
    TArrayGet(_, _, _) => 75UL
    TArrayGetS(_, _, _) => 76UL
    TArrayGetU(_, _, _) => 77UL
    TArraySet(_, _, _, _) => 78UL
    TArrayFill(_, _, _, _, _) => 79UL
    TArrayCopy(_, _, _, _, _, _, _) => 80UL
    TArrayInitData(_, _, _, _, _, _) => 81UL
    TArrayInitElem(_, _, _, _, _, _) => 82UL
    TRefTest(_, _, _) => 83UL
    TRefCast(_, _, _) => 84UL
    TRefGetDesc(_) => 85UL
    TRefTestDesc(_, _, _) => 86UL
    TRefCastDescEq(_, _, _) => 87UL
    TI8x16Splat(_) => 88UL
    TI16x8Splat(_) => 89UL
    TI32x4Splat(_) => 90UL
    TI64x2Splat(_) => 91UL
    TF32x4Splat(_) => 92UL
    TF64x2Splat(_) => 93UL
    TExtractLane(_, _, _) => 94UL
    TReplaceLane(_, _, _, _) => 95UL
    TI8x16Shuffle(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) => 96UL
    TI8x16Swizzle(_, _) => 97UL
    TI8x16RelaxedSwizzle(_, _) => 98UL
    TV128Shift(_, _, _) => 99UL
    TV128Ternary(_, _, _, _) => 100UL
    TV128LoadLane(_, _, _, _, _) => 101UL
    TV128StoreLane(_, _, _, _, _) => 102UL
  }
  tag * 11400714819323198485UL
}

///|
fn msf_mix_digest(seed : UInt64, x : UInt64) -> UInt64 {
  (seed ^ x) * 1099511628211UL
}

///|
fn msf_hash_tinstr(state : MSFHashState, instr : TInstr) -> Unit {
  state.digest = msf_mix_digest(state.digest, msf_tag_hash(instr))
}

///|
fn msf_hash_function_ignoring_consts(func : Func) -> UInt64 {
  match func {
    TFunc(_, body) => {
      let normalized = match msf_normalize_body(body) {
        Ok(x) => x
        Err(_) => body
      }
      let state = { digest: 1469598103934665603UL }
      let walker = ModuleTransformer::new().on_tinstruction_evt(fn(
        self,
        _,
        instr,
      ) {
        msf_hash_tinstr(state, instr)
        self.walk_tinstruction_default((), instr)
      })
      ignore(walker.walk_texpr((), normalized))
      state.digest
    }
    _ => 0UL
  }
}

///|
fn hash_function_ignoring_consts(func : Func) -> UInt64 {
  msf_hash_function_ignoring_consts(func)
}

///|
fn msf_normalize_body(body : TExpr) -> Result[TExpr, String] {
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    let walked = match self.walk_tinstruction_default((), instr) {
      Ok(Some((_, next))) => next
      Ok(None) => instr
      Err(e) => return Err(e)
    }
    let rewritten = match walked {
      TI32Const(_)
      | TI64Const(_)
      | TF32Const(_)
      | TF64Const(_)
      | TRefNull(_)
      | TRefFunc(_)
      | TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
        msf_zero_const_like(walked)
      TCall(_, args) => TInstr::call(FuncIdx::new(0), args)
      TReturnCall(_, args) => TInstr::return_call(FuncIdx::new(0), args)
      _ => walked
    }
    if rewritten == instr {
      unchanged()
    } else {
      change((), rewritten)
    }
  })
  match walker.walk_texpr((), body) {
    Ok(Some((_, out))) => Ok(out)
    Ok(None) => Ok(body)
    Err(e) => Err(e)
  }
}

///|
fn msf_collect_call_sites(body : TExpr) -> Array[MSFCallSite] {
  let out : Array[MSFCallSite] = []
  let mut next_id = 0
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    let id = next_id
    next_id += 1
    match instr {
      TCall(target, args) =>
        out.push({
          node_id: id,
          target,
          arg_count: args.length(),
          is_return: false,
        })
      TReturnCall(target, args) =>
        out.push({
          node_id: id,
          target,
          arg_count: args.length(),
          is_return: true,
        })
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
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
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    let id = next_id
    next_id += 1
    match instr {
      TI32Const(_)
      | TI64Const(_)
      | TF32Const(_)
      | TF64Const(_)
      | TRefNull(_)
      | TRefFunc(_)
      | TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
        match msf_const_type(instr) {
          Some(vt) => out[id] = ConstSite(instr, vt)
          None => ()
        }
      TCall(target, _) | TReturnCall(target, _) => {
        let is_return = match instr {
          TReturnCall(_, _) => true
          _ => false
        }
        let abs_idx = msf_func_idx_to_int(target)
        if abs_idx >= 0 && abs_idx < type_idxs.length() {
          out[id] = CallTargetSite(target, type_idxs[abs_idx], is_return)
        }
      }
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
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
    match funcs[def_idx] {
      TFunc(locals, body) =>
        out.push({
          def_idx,
          abs_idx,
          type_idx: func_type_idxs[abs_idx],
          func_type: func_types[abs_idx],
          locals: locals.copy(),
          body,
          hash: hash_function_ignoring_consts(funcs[def_idx]),
        })
      _ => ()
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
fn collect_equivalent_classes(mod : Module) -> Array[EquivalentClass] {
  let import_count = msf_count_imported_funcs(mod)
  let func_types = msf_collect_func_types(mod)
  let func_type_idxs = msf_collect_func_type_indices(mod)
  let defined = msf_collect_defined_funcs(
    mod, func_types, func_type_idxs, import_count,
  )
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
    let sorted_members = msf_sort_class_members(members, import_count)
    let partitions : Array[Array[Int]] = []
    for def_idx in sorted_members {
      let candidate = by_def_idx.get(def_idx).unwrap()
      let mut placed = false
      for part in partitions {
        let rep_idx = part[0]
        let rep = by_def_idx.get(rep_idx).unwrap()
        if are_in_equivalent_class(candidate, rep, mod) {
          part.push(def_idx)
          placed = true
          break
        }
      }
      if !placed {
        partitions.push([def_idx])
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
fn derive_params(clazz : EquivalentClass, mod : Module) -> Array[ParamInfo]? {
  let CodeSec(funcs) = match mod.code_sec {
    Some(sec) => sec
    None => return None
  }
  let import_count = msf_count_imported_funcs(mod)
  let func_type_idxs = msf_collect_func_type_indices(mod)
  let mut primary_body : TExpr? = None
  let mut primary_param_count = 0
  for i = 0; i < clazz.member_def_idxs.length(); i = i + 1 {
    let def_idx = clazz.member_def_idxs[i]
    if def_idx < 0 || def_idx >= funcs.length() {
      return None
    }
    let abs_idx = import_count + def_idx
    if abs_idx < 0 || abs_idx >= func_type_idxs.length() {
      return None
    }
    match funcs[def_idx] {
      TFunc(_, body) =>
        if def_idx == clazz.primary_def_idx {
          primary_body = Some(body)
          let FuncType(params, _) = match
            msf_collect_func_types(mod).get(abs_idx) {
            Some(ft) => ft
            None => return None
          }
          primary_param_count = params.length()
        }
      _ => return None
    }
  }
  let primary_body = match primary_body {
    Some(x) => x
    None => return None
  }
  let site_maps : Array[Map[Int, MSFSiteValue]] = []
  for def_idx in clazz.member_def_idxs {
    match funcs[def_idx] {
      TFunc(_, body) => site_maps.push(msf_collect_sites(body, func_type_idxs))
      _ => return None
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
                return None
              }
              values.push(v)
            }
            _ => return None
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
      CallTargetSite(_, type_idx, is_return) => {
        ignore(is_return)
        let values : Array[FuncIdx] = []
        for sites in site_maps {
          match sites.get(node_id) {
            Some(CallTargetSite(target, site_type_idx, _)) => {
              if site_type_idx != type_idx {
                return None
              }
              values.push(target)
            }
            _ => return None
          }
        }
        if msf_same_all_targets(values) {
          continue
        }
        let key = CallParamKey(type_idx, values)
        match key_to_idx.get(key) {
          Some(idx) => params[idx].uses.push(node_id)
          None => {
            let idx = params.length()
            key_to_idx[key] = idx
            params.push({
              kind: CallTargetParam(type_idx, values),
              uses: [node_id],
            })
          }
        }
      }
    }
  }
  if primary_param_count + params.length() > MSF_MAX_SYNTHETIC_FUNCTION_PARAMS {
    return None
  }
  Some(params)
}

///|
fn msf_measure_body(body : TExpr) -> Int {
  let mut n = 0
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    n += 1
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  n
}

///|
fn has_merge_benefit(
  clazz : EquivalentClass,
  mod : Module,
  params : Array[ParamInfo],
) -> Bool {
  let CodeSec(funcs) = match mod.code_sec {
    Some(sec) => sec
    None => return false
  }
  if clazz.member_def_idxs.length() < 2 {
    return false
  }
  let import_count = msf_count_imported_funcs(mod)
  let func_types = msf_collect_func_types(mod)
  let primary_def = clazz.primary_def_idx
  if primary_def < 0 || primary_def >= funcs.length() {
    return false
  }
  let primary_abs = import_count + primary_def
  if primary_abs < 0 || primary_abs >= func_types.length() {
    return false
  }
  let FuncType(primary_params, _) = func_types[primary_abs]
  let primary_body = match funcs[primary_def] {
    TFunc(_, body) => body
    _ => return false
  }
  let removed = (clazz.member_def_idxs.length() - 1) *
    msf_measure_body(primary_body)
  let added_per_thunk = 1 + primary_params.length() + params.length()
  let added = (clazz.member_def_idxs.length() - 1) * added_per_thunk +
    params.length()
  removed > added
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
) -> Result[TExpr, String] {
  let node_to_param : Map[Int, Int] = Map::new()
  for param_idx = 0; param_idx < params.length(); param_idx = param_idx + 1 {
    for use_id in params[param_idx].uses {
      node_to_param[use_id] = param_idx
    }
  }
  let mut next_id = 0
  let shift = params.length()
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    let node_id = next_id
    next_id += 1
    let walked = match self.walk_tinstruction_default((), instr) {
      Ok(Some((_, next))) => next
      Ok(None) => instr
      Err(e) => return Err(e)
    }
    let shifted = match walked {
      TLocalGet(idx) => {
        let raw = msf_local_idx_to_int(idx)
        if raw >= primary_param_count {
          TInstr::local_get(msf_local_idx_from_int(raw + shift))
        } else {
          walked
        }
      }
      TLocalSet(idx, value) => {
        let raw = msf_local_idx_to_int(idx)
        if raw >= primary_param_count {
          TInstr::local_set(msf_local_idx_from_int(raw + shift), value)
        } else {
          walked
        }
      }
      TLocalTee(idx, value) => {
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
          (TI32Const(_), LiteralParam(_, _))
          | (TI64Const(_), LiteralParam(_, _))
          | (TF32Const(_), LiteralParam(_, _))
          | (TF64Const(_), LiteralParam(_, _))
          | (TRefNull(_), LiteralParam(_, _))
          | (TRefFunc(_), LiteralParam(_, _))
          | (
            TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _),
            LiteralParam(_, _),
          ) => TInstr::local_get(replacement_local)
          (TCall(_, args), CallTargetParam(type_idx, _)) => {
            let casted = TInstr::ref_cast(
              true,
              HeapType::new(type_idx),
              TInstr::local_get(replacement_local),
            )
            TInstr::call_ref(type_idx, args, casted)
          }
          (TReturnCall(_, args), CallTargetParam(type_idx, _)) => {
            let casted = TInstr::ref_cast(
              true,
              HeapType::new(type_idx),
              TInstr::local_get(replacement_local),
            )
            TInstr::return_call_ref(type_idx, args, casted)
          }
          _ => shifted
        }
      }
      None => shifted
    }
    if replaced == instr {
      unchanged()
    } else {
      change((), replaced)
    }
  })
  match walker.walk_texpr((), body) {
    Ok(Some((_, out))) => Ok(out)
    Ok(None) => Ok(body)
    Err(e) => Err(e)
  }
}

///|
fn msf_collect_param_types(params : Array[ParamInfo]) -> Array[ValType] {
  let out : Array[ValType] = []
  for param in params {
    match param.kind {
      LiteralParam(vt, _) => out.push(vt)
      CallTargetParam(_, _) => out.push(ValType::funcref())
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
fn create_shared(
  clazz : EquivalentClass,
  mod : Module,
  params : Array[ParamInfo],
) -> Result[(Module, FuncIdx), String] {
  let funcs = match mod.code_sec {
    Some(CodeSec(items)) => items.copy()
    None => return Err("merge_similar_functions: missing code section")
  }
  let type_idxs = match mod.func_sec {
    Some(FuncSec(items)) => items.copy()
    None => return Err("merge_similar_functions: missing func section")
  }
  let import_count = msf_count_imported_funcs(mod)
  let func_types = msf_collect_func_types(mod)
  let primary_def = clazz.primary_def_idx
  if primary_def < 0 || primary_def >= funcs.length() {
    return Err("merge_similar_functions: primary function out of range")
  }
  let primary_abs = import_count + primary_def
  if primary_abs < 0 || primary_abs >= func_types.length() {
    return Err("merge_similar_functions: primary abs function out of range")
  }
  let (primary_locals, primary_body) = match funcs[primary_def] {
    TFunc(locals, body) => (locals.copy(), body)
    _ => return Err("merge_similar_functions: primary function is not TFunc")
  }
  let FuncType(primary_params, primary_results) = func_types[primary_abs]
  let rewritten_body = match
    msf_rewrite_shared_body(primary_body, primary_params.length(), params) {
    Ok(x) => x
    Err(e) => return Err(e)
  }
  let added_param_types = msf_collect_param_types(params)
  let shared_param_types = primary_params.copy()
  for vt in added_param_types {
    shared_param_types.push(vt)
  }
  let (with_type, shared_type_idx) = msf_append_func_type(
    mod, shared_param_types, primary_results,
  )
  let next_type_idxs = type_idxs
  let next_funcs = funcs
  next_type_idxs.push(shared_type_idx)
  let shared_func = Func::t_func(primary_locals, rewritten_body)
  next_funcs.push(shared_func)
  let next_mod = with_type
    .with_func_sec(FuncSec::new(next_type_idxs))
    .with_code_sec(CodeSec::new(next_funcs))
  let shared_abs = import_count + (next_funcs.length() - 1)
  Ok((next_mod, msf_func_idx_from_int(shared_abs)))
}

///|
fn msf_param_value_for_member(param : ParamInfo, member_idx : Int) -> TInstr? {
  match param.kind {
    LiteralParam(_, values) => values.get(member_idx)
    CallTargetParam(_, targets) =>
      match targets.get(member_idx) {
        Some(target) => Some(TInstr::ref_func(target))
        None => None
      }
  }
}

///|
fn replace_with_thunk(
  target : Func,
  shared : FuncIdx,
  params : Array[ParamInfo],
  values_for_target : Array[TInstr],
) -> Func {
  match target {
    TFunc(_, _) => {
      let param_count = values_for_target.length() - params.length()
      let args : Array[TInstr] = []
      for i = 0; i < param_count; i = i + 1 {
        args.push(values_for_target[i])
      }
      for i = 0; i < params.length(); i = i + 1 {
        args.push(values_for_target[param_count + i])
      }
      let body = TExpr::new([TInstr::return_call(shared, args)])
      Func::t_func([], body)
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
) -> Result[Module, String] {
  let import_count = msf_count_imported_funcs(mod)
  let func_types = msf_collect_func_types(mod)
  let primary_abs = import_count + clazz.primary_def_idx
  if primary_abs < 0 || primary_abs >= func_types.length() {
    return Ok(mod)
  }
  let FuncType(primary_params, _) = func_types[primary_abs]
  let (mod, shared_idx) = match create_shared(clazz, mod, params) {
    Ok(v) => v
    Err(e) => return Err(e)
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
  }
  Ok(mod.with_code_sec(CodeSec::new(next_funcs)))
}

///|
fn run(mod : Module) -> Result[Module, String] {
  let classes = collect_equivalent_classes(mod)
  if classes.is_empty() {
    return Ok(mod)
  }
  let mut mod = mod
  for clazz in classes {
    let params = match derive_params(clazz, mod) {
      Some(p) => p
      None => continue
    }
    if params.is_empty() {
      continue
    }
    let func_types = msf_collect_func_types(mod)
    let import_count = msf_count_imported_funcs(mod)
    let primary_abs = import_count + clazz.primary_def_idx
    if primary_abs < 0 || primary_abs >= func_types.length() {
      continue
    }
    let FuncType(primary_params, _) = func_types[primary_abs]
    if primary_params.length() + params.length() >
      MSF_MAX_SYNTHETIC_FUNCTION_PARAMS {
      continue
    }
    if !has_merge_benefit(clazz, mod, params) {
      continue
    }
    mod = match msf_apply_class(mod, clazz, params) {
      Ok(next) => next
      Err(e) => return Err(e)
    }
  }
  Ok(mod)
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
    TFunc(locals, { instrs: [TReturnCall(FuncIdx(raw), args)], .. }) =>
      locals.length() == 0 &&
      raw.reinterpret_as_int() == target_abs &&
      args.length() == arg_count
    _ => false
  }
}

///|
test "merge similar functions basic const merging creates shared + thunks" {
  let t = msf_i32_func_type()
  let f0 = Func::t_func([], msf_binary_body(42, 10))
  let f1 = Func::t_func([], msf_binary_body(43, 10))
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
        TFunc(_, body) => {
          let mut saw_param_get = false
          let walker = ModuleTransformer::new().on_tinstruction_evt(fn(
            self,
            _,
            instr,
          ) {
            match instr {
              TLocalGet(LocalIdx(raw)) if raw.reinterpret_as_int() == 1 =>
                saw_param_get = true
              _ => ()
            }
            self.walk_tinstruction_default((), instr)
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
        TFunc(_, { instrs: body, .. }) => {
          let mut local_get_count = 0
          for instr in body {
            let walker = ModuleTransformer::new().on_tinstruction_evt(fn(
              self,
              _,
              curr,
            ) {
              match curr {
                TLocalGet(LocalIdx(raw)) if raw.reinterpret_as_int() == 1 =>
                  local_get_count += 1
                _ => ()
              }
              self.walk_tinstruction_default((), curr)
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
  let f0 = Func::t_func([], msf_binary_body(10, 20))
  let f1 = Func::t_func([], msf_binary_body(11, 21))
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
  let out = msf_run(mod)
  let shared_abs = msf_shared_abs_index(out)
  match out.code_sec {
    Some(CodeSec(funcs)) => {
      assert_true(msf_is_forwarder(funcs[2], shared_abs, 2))
      assert_true(msf_is_forwarder(funcs[3], shared_abs, 2))
      match funcs[shared_abs - msf_count_imported_funcs(out)] {
        TFunc(_, { instrs: body, .. }) => {
          let mut saw_call_ref = false
          let mut seen_type_idx = -1
          let mut saw_casted_local = false
          let walker = ModuleTransformer::new().on_tinstruction_evt(fn(
            self,
            _,
            instr,
          ) {
            match instr {
              TCallRef(TypeIdx(raw), _, ref_) => {
                saw_call_ref = true
                seen_type_idx = raw.reinterpret_as_int()
                match ref_ {
                  TRefCast(
                    true,
                    HeapType(TypeIdx(cast_raw)),
                    TLocalGet(LocalIdx(local_raw))
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
            self.walk_tinstruction_default((), instr)
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
test "merge similar functions rejects const type mismatch" {
  let t = msf_void_func_type()
  let f0 = Func::t_func(
    [],
    TExpr::new([TInstr::drop(TInstr::i32_const(I32(1)))]),
  )
  let f1 = Func::t_func(
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
  let callee_i32 = Func::t_func([], TExpr::new([TInstr::i32_const(I32(1))]))
  let callee_i64 = Func::t_func([], TExpr::new([TInstr::i64_const(I64(1L))]))
  let wrap_a = Func::t_func(
    [],
    TExpr::new([TInstr::drop(TInstr::call(FuncIdx::new(0), []))]),
  )
  let wrap_b = Func::t_func(
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
    [ValType::i32()],
    TExpr::new([TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(1)))]),
  )
  let f1 = Func::t_func([], TExpr::new([TInstr::nop()]))
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
  let tiny0 = Func::t_func([], TExpr::new([TInstr::i32_const(I32(1))]))
  let tiny1 = Func::t_func([], TExpr::new([TInstr::i32_const(I32(2))]))
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
  let big0 = Func::t_func([], msf_binary_body(100, 7))
  let big1 = Func::t_func([], msf_binary_body(101, 7))
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
  let f0 = Func::t_func([], TExpr::new(body_a_instrs))
  let f1 = Func::t_func([], TExpr::new(body_b_instrs))
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
  let a0 = Func::t_func([], msf_binary_body(10, 1))
  let a1 = Func::t_func([], msf_binary_body(11, 1))
  let b0 = Func::t_func([], msf_binary_body(20, 2))
  let b1 = Func::t_func([], msf_binary_body(21, 2))
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
        TFunc(_, body) => {
          let mut saw_shifted_set = false
          let mut saw_shifted_get = false
          let walker = ModuleTransformer::new().on_tinstruction_evt(fn(
            self,
            _,
            instr,
          ) {
            match instr {
              TLocalSet(LocalIdx(raw), _) if raw.reinterpret_as_int() == 2 =>
                saw_shifted_set = true
              TLocalGet(LocalIdx(raw)) if raw.reinterpret_as_int() == 2 =>
                saw_shifted_get = true
              _ => ()
            }
            self.walk_tinstruction_default((), instr)
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
