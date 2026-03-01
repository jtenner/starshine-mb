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
fn make_func_type(params : Array[ValType], results : Array[ValType]) -> RecType {
  single_rec_type(comp_type_sub_type(func_comp_type(params, results)))
}

///|
fn extract_comp_type(sub_type : SubType) -> CompType {
  match sub_type {
    SubType(_, _, comp) => comp
    CompTypeSubType(comp) => comp
  }
}

///|
fn resolve_func_type(comp_types : Array[CompType], idx : TypeIdx) -> FuncType? {
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
fn count_imported_funcs(mod : Module) -> Int {
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
fn collect_func_types(mod : Module) -> Array[FuncType] {
  let comp_types : Array[CompType] = []
  match mod.type_sec {
    Some(TypeSec(rec_types)) =>
      for rec_type in rec_types {
        match rec_type {
          SingleRecType(sub_type) =>
            comp_types.push(extract_comp_type(sub_type))
          GroupRecType(sub_types) =>
            for sub_type in sub_types {
              comp_types.push(extract_comp_type(sub_type))
            }
        }
      }
    None => ()
  }
  let func_types : Array[FuncType] = []
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        let Import(_, _, ex) = import_
        match ex {
          FuncExternType(type_idx) =>
            match resolve_func_type(comp_types, type_idx) {
              Some(ft) => func_types.push(ft)
              None => func_types.push(FuncType::new([], []))
            }
          _ => ()
        }
      }
    None => ()
  }
  match mod.func_sec {
    Some(FuncSec(type_idxs)) =>
      for type_idx in type_idxs {
        match resolve_func_type(comp_types, type_idx) {
          Some(ft) => func_types.push(ft)
          None => func_types.push(FuncType::new([], []))
        }
      }
    None => ()
  }
  func_types
}

///|
fn flattened_type_count(rec_types : Array[RecType]) -> Int {
  let mut n = 0
  for rec_type in rec_types {
    match rec_type {
      SingleRecType(_) => n += 1
      GroupRecType(sub_types) => n += sub_types.length()
    }
  }
  n
}

///|
fn dead_argument_elim_trace_noop(_ : String) -> Unit {
  ()
}

///|
fn dae_trace_delta_us_to_ms(delta_us : UInt64) -> UInt64 {
  delta_us / 1000UL
}

///|
fn dae_hash_mix(seed : UInt64, value : UInt64) -> UInt64 {
  seed ^ (value + 0x9E3779B97F4A7C15UL + (seed << 6) + (seed >> 2))
}

///|
fn dae_hash_int(value : Int) -> UInt64 {
  value.reinterpret_as_uint().to_uint64()
}

///|
#cfg(target="native")
#borrow(tv)
extern "c" fn dae_native_gettimeofday(tv : Bytes, tz : UInt64) -> Int = "gettimeofday"

///|
#cfg(target="native")
fn dae_trace_read_u64_le(bytes : Bytes, start : Int) -> UInt64 {
  let mut out = 0UL
  let mut i = 0
  while i < 8 {
    out = out | (bytes[start + i].to_uint64() << (i * 8))
    i += 1
  }
  out
}

///|
#cfg(target="native")
fn dae_trace_now_us() -> UInt64 {
  let tv = Bytes::new(16)
  if dae_native_gettimeofday(tv, 0UL) != 0 {
    return @env.now() * 1000UL
  }
  let sec = dae_trace_read_u64_le(tv, 0)
  let usec = dae_trace_read_u64_le(tv, 8)
  sec * 1000000UL + usec
}

///|
#cfg(target="wasm-gc")
fn dae_trace_now_us() -> UInt64 {
  @env.now() * 1000UL
}

///|
#cfg(target="wasm")
fn dae_trace_now_us() -> UInt64 {
  @env.now() * 1000UL
}

///|
#cfg(target="js")
fn dae_trace_now_us() -> UInt64 {
  @env.now() * 1000UL
}

///|
#cfg(target="llvm")
fn dae_trace_now_us() -> UInt64 {
  @env.now() * 1000UL
}

///|
fn dae_trace_elapsed_us_since(start_us : UInt64) -> UInt64 {
  let end_us = dae_trace_now_us()
  if end_us >= start_us {
    end_us - start_us
  } else {
    0UL
  }
}

///|
fn dae_count_instr(instr : TInstr) -> Int {
  let mut total = 1
  for child in eval_children(instr) {
    total += dae_count_instr(child)
  }
  total
}

///|
fn dae_count_texpr_instrs(expr : TExpr) -> Int {
  let mut total = 0
  for instr in expr.instrs {
    total += dae_count_instr(instr)
  }
  total
}

///|
fn dae_body_fingerprint(body : TExpr) -> UInt64 {
  let mut digest = dae_hash_mix(
    0xA9B4C9D27F31E6D5UL,
    dae_hash_int(body.instrs.length()),
  )
  for instr in body.instrs {
    digest = dae_hash_mix(
      digest,
      instr.hash().reinterpret_as_uint().to_uint64(),
    )
  }
  digest
}

///|
fn is_literal_const(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TI32Const(_)
    | TInstrKind::TI64Const(_)
    | TInstrKind::TF32Const(_)
    | TInstrKind::TF64Const(_) => true
    TInstrKind::TRefNull(_) | TInstrKind::TRefFunc(_) => true
    TInstrKind::TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
      true
    _ => false
  }
}

///|
fn is_trivially_pure_arg(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TI32Const(_)
    | TInstrKind::TI64Const(_)
    | TInstrKind::TF32Const(_)
    | TInstrKind::TF64Const(_) => true
    TInstrKind::TRefNull(_) | TInstrKind::TRefFunc(_) => true
    TInstrKind::TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
      true
    TInstrKind::TLocalGet(_) | TInstrKind::TGlobalGet(_) => true
    _ => false
  }
}

///|
fn body_ends_with_explicit_return_or_unreachable(body : TExpr) -> Bool {
  if body.instrs.is_empty() {
    return true
  }
  match body.instrs[body.instrs.length() - 1].kind {
    TInstrKind::TReturn(_) | TInstrKind::TUnreachable => true
    _ => false
  }
}

///|
fn body_can_drop_result(
  body : TExpr,
  result_arity : Int,
  has_explicit_return : Bool,
) -> Bool {
  if result_arity == 0 {
    return true
  }
  if body_ends_with_explicit_return_or_unreachable(body) {
    return true
  }
  result_arity == 1 && not(has_explicit_return)
}

///|
fn mark_exports_unseen(mod : Module, has_unseen : Array[Bool]) -> Unit {
  match mod.export_sec {
    Some(ExportSec(exports)) =>
      for export_ in exports {
        let Export(_, extern_idx) = export_
        match extern_idx {
          FuncExternIdx(FuncIdx(raw)) => {
            let idx = raw.reinterpret_as_int()
            if idx >= 0 && idx < has_unseen.length() {
              has_unseen[idx] = true
            }
          }
          _ => ()
        }
      }
    None => ()
  }
}

///|
fn mark_start_unseen(mod : Module, has_unseen : Array[Bool]) -> Unit {
  match mod.start_sec {
    Some(StartSec(FuncIdx(raw))) => {
      let idx = raw.reinterpret_as_int()
      if idx >= 0 && idx < has_unseen.length() {
        has_unseen[idx] = true
      }
    }
    None => ()
  }
}

///|
fn mark_elem_unseen(mod : Module, has_unseen : Array[Bool]) -> Unit {
  match mod.elem_sec {
    Some(ElemSec(elems)) =>
      for elem in elems {
        let Elem(_, kind) = elem
        match kind {
          FuncsElemKind(funcs) =>
            for func_idx in funcs {
              let FuncIdx(raw) = func_idx
              let idx = raw.reinterpret_as_int()
              if idx >= 0 && idx < has_unseen.length() {
                has_unseen[idx] = true
              }
            }
          FuncExprsElemKind(exprs) | TypedExprsElemKind(_, exprs) =>
            for expr in exprs {
              for instr in expr.0 {
                match instr {
                  RefFunc(FuncIdx(raw)) => {
                    let idx = raw.reinterpret_as_int()
                    if idx >= 0 && idx < has_unseen.length() {
                      has_unseen[idx] = true
                    }
                  }
                  _ => ()
                }
              }
            }
        }
      }
    None => ()
  }
}

///|
priv struct DAECallSummary {
  param_types : Array[ValType]
  all_pure : Array[Bool]
  const_candidate : Array[TInstr?]
  const_valid : Array[Bool]
  type_candidate : Array[ValType?]
  type_valid : Array[Bool]
}

///|
fn DAECallSummary::new(param_types : Array[ValType]) -> DAECallSummary {
  let param_count = param_types.length()
  let const_candidate : Array[TInstr?] = Array::make(param_count, None)
  let type_candidate : Array[ValType?] = Array::make(param_count, None)
  let type_valid : Array[Bool] = Array::make(param_count, false)
  for i = 0; i < param_count; i = i + 1 {
    match param_types[i] {
      RefTypeValType(_) => type_valid[i] = true
      _ => ()
    }
  }
  {
    param_types,
    all_pure: Array::make(param_count, true),
    const_candidate,
    const_valid: Array::make(param_count, true),
    type_candidate,
    type_valid,
  }
}

///|
priv struct DAEReturnSummary {
  mut has_explicit_return : Bool
  mut failed : Bool
  tracked : Array[Bool]
  candidate : Array[ValType?]
}

///|
fn DAEReturnSummary::new(result_types : Array[ValType]) -> DAEReturnSummary {
  let tracked : Array[Bool] = Array::make(result_types.length(), false)
  for i = 0; i < result_types.length(); i = i + 1 {
    match result_types[i] {
      RefTypeValType(_) => tracked[i] = true
      _ => ()
    }
  }
  {
    has_explicit_return: false,
    failed: false,
    tracked,
    candidate: Array::make(result_types.length(), None),
  }
}

///|
priv struct DAEHotspotEntry {
  idx : Int
  elapsed_us : UInt64
}

///|
fn DAEHotspotEntry::new(idx : Int, elapsed_us : UInt64) -> DAEHotspotEntry {
  { idx, elapsed_us }
}

///|
priv struct DAERewriteTrace {
  mut instrs_visited : Int
  mut calls_rewritten : Int
  mut local_indices_rewritten : Int
  mut drops_removed : Int
  mut call_args_removed : Int
}

///|
fn DAERewriteTrace::new() -> DAERewriteTrace {
  {
    instrs_visited: 0,
    calls_rewritten: 0,
    local_indices_rewritten: 0,
    drops_removed: 0,
    call_args_removed: 0,
  }
}

///|
priv struct DAETraceStats {
  detail_timing_enabled : Bool
  mut setup_collect_func_types_us : UInt64
  mut setup_build_local_types_us : UInt64
  mut setup_collect_global_types_us : UInt64
  mut setup_collect_direct_results_us : UInt64
  mut setup_init_arrays_us : UInt64
  mut setup_us : UInt64
  mut analysis_us : UInt64
  mut decide_us : UInt64
  mut sig_us : UInt64
  mut rewrite_us : UInt64
  mut analysis_instrs_visited : Int
  mut rewrite_instrs_visited : Int
  mut analysis_calls_seen : Int
  mut analysis_localgets_seen : Int
  mut returns_seen : Int
  mut known_type_calls_total : Int
  mut known_type_local_get_calls : Int
  mut known_type_global_get_calls : Int
  mut known_type_call_direct_calls : Int
  mut known_type_call_indirect_calls : Int
  mut known_type_ref_cast_calls : Int
  mut known_type_select_calls : Int
  mut known_type_other_calls : Int
  mut known_type_elapsed_us : UInt64
  mut resolve_functype_calls : Int
  mut match_calls_total : Int
  mut match_elapsed_us : UInt64
  mut common_supertype_calls_total : Int
  mut common_supertype_elapsed_us : UInt64
  mut removed_params_total : Int
  mut removed_const_params_total : Int
  mut removed_unused_params_total : Int
  mut result_removals_total : Int
  mut params_refined_total : Int
  mut results_refined_total : Int
  mut functions_rewritten : Int
  mut calls_rewritten : Int
  mut local_indices_rewritten : Int
  mut drops_removed_due_to_result : Int
  mut filtered_call_args_total : Int
  mut filtered_call_args_removed_total : Int
  mut prologue_inserted_funcs : Int
  mut oscillation_suspects : Int
  analysis_hotspots : Array[DAEHotspotEntry]
  rewrite_hotspots : Array[DAEHotspotEntry]
  oscillation_samples : Array[String]
}

///|
fn DAETraceStats::new(detail_timing_enabled? : Bool = false) -> DAETraceStats {
  {
    detail_timing_enabled,
    setup_collect_func_types_us: 0UL,
    setup_build_local_types_us: 0UL,
    setup_collect_global_types_us: 0UL,
    setup_collect_direct_results_us: 0UL,
    setup_init_arrays_us: 0UL,
    setup_us: 0UL,
    analysis_us: 0UL,
    decide_us: 0UL,
    sig_us: 0UL,
    rewrite_us: 0UL,
    analysis_instrs_visited: 0,
    rewrite_instrs_visited: 0,
    analysis_calls_seen: 0,
    analysis_localgets_seen: 0,
    returns_seen: 0,
    known_type_calls_total: 0,
    known_type_local_get_calls: 0,
    known_type_global_get_calls: 0,
    known_type_call_direct_calls: 0,
    known_type_call_indirect_calls: 0,
    known_type_ref_cast_calls: 0,
    known_type_select_calls: 0,
    known_type_other_calls: 0,
    known_type_elapsed_us: 0UL,
    resolve_functype_calls: 0,
    match_calls_total: 0,
    match_elapsed_us: 0UL,
    common_supertype_calls_total: 0,
    common_supertype_elapsed_us: 0UL,
    removed_params_total: 0,
    removed_const_params_total: 0,
    removed_unused_params_total: 0,
    result_removals_total: 0,
    params_refined_total: 0,
    results_refined_total: 0,
    functions_rewritten: 0,
    calls_rewritten: 0,
    local_indices_rewritten: 0,
    drops_removed_due_to_result: 0,
    filtered_call_args_total: 0,
    filtered_call_args_removed_total: 0,
    prologue_inserted_funcs: 0,
    oscillation_suspects: 0,
    analysis_hotspots: [],
    rewrite_hotspots: [],
    oscillation_samples: [],
  }
}

///|
fn dae_trace_detail_timing_enabled(stats : DAETraceStats) -> Bool {
  stats.detail_timing_enabled
}

///|
fn dae_trace_rewrite_progress_check_interval() -> Int {
  16384
}

///|
priv struct DAEOnceResult {
  mod : Module
  changed : Bool
  signature_changed : Bool
  body_changed : Bool
  appended_clones : Int
  defined_funcs : Int
  abs_funcs : Int
  flat_type_count_after : Int
  stats : DAETraceStats
}

///|
fn dae_trace_record_hotspot(
  entries : Array[DAEHotspotEntry],
  idx : Int,
  elapsed_us : UInt64,
) -> Unit {
  entries.push(DAEHotspotEntry::new(idx, elapsed_us))
}

///|
fn dae_trace_emit_hotspots(
  trace : (String) -> Unit,
  label : String,
  entries : Array[DAEHotspotEntry],
  limit : Int,
) -> Unit {
  if entries.is_empty() || limit <= 0 {
    return
  }
  let used : Array[Bool] = Array::make(entries.length(), false)
  let out : Array[String] = []
  let mut emitted = 0
  while emitted < limit && emitted < entries.length() {
    let mut best_idx = -1
    let mut best_elapsed = 0UL
    let mut i = 0
    while i < entries.length() {
      let entry = entries[i]
      if not(used[i]) && (best_idx < 0 || entry.elapsed_us > best_elapsed) {
        best_idx = i
        best_elapsed = entry.elapsed_us
      }
      i += 1
    }
    if best_idx < 0 {
      break
    }
    used[best_idx] = true
    let entry = entries[best_idx]
    out.push("\{entry.idx}:\{dae_trace_delta_us_to_ms(entry.elapsed_us)}ms")
    emitted += 1
  }
  if not(out.is_empty()) {
    trace("\{label}=\{out}")
  }
}

///|
fn single_result_type(func_type : FuncType) -> ValType? {
  match func_type {
    FuncType(_, [result]) => Some(result)
    _ => None
  }
}

///|
fn collect_direct_result_types(func_types : Array[FuncType]) -> Array[ValType?] {
  let out : Array[ValType?] = []
  for func_type in func_types {
    out.push(single_result_type(func_type))
  }
  out
}

///|
fn known_instr_type(
  instr : TInstr,
  caller_abs_idx : Int,
  local_types_by_abs : Array[Array[ValType]],
  global_types : Array[ValType],
  direct_result_types : Array[ValType?],
  env : Env,
  trace_stats : DAETraceStats,
) -> ValType? {
  trace_stats.known_type_calls_total += 1
  let track_detail_timing = dae_trace_detail_timing_enabled(trace_stats)
  let start_us = if track_detail_timing { dae_trace_now_us() } else { 0UL }
  let out = match instr.kind {
    TInstrKind::TI32Const(_) => Some(ValType::i32())
    TInstrKind::TI64Const(_) => Some(ValType::i64())
    TInstrKind::TF32Const(_) => Some(ValType::f32())
    TInstrKind::TF64Const(_) => Some(ValType::f64())
    TInstrKind::TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
      Some(ValType::v128())
    TInstrKind::TRefNull(ht) => Some(ValType::ref_type(RefType::new(true, ht)))
    TInstrKind::TRefFunc(_) =>
      Some(
        ValType::ref_type(
          RefType::new(false, HeapType::abs(AbsHeapType::func())),
        ),
      )
    TInstrKind::TLocalGet(LocalIdx(raw)) => {
      trace_stats.known_type_local_get_calls += 1
      let idx = raw.reinterpret_as_int()
      if caller_abs_idx < 0 || caller_abs_idx >= local_types_by_abs.length() {
        None
      } else {
        let locals = local_types_by_abs[caller_abs_idx]
        if idx < 0 || idx >= locals.length() {
          None
        } else {
          Some(locals[idx])
        }
      }
    }
    TInstrKind::TGlobalGet(GlobalIdx(raw)) => {
      trace_stats.known_type_global_get_calls += 1
      let idx = raw.reinterpret_as_int()
      if idx < 0 || idx >= global_types.length() {
        None
      } else {
        Some(global_types[idx])
      }
    }
    TInstrKind::TLocalTee(_, value) => {
      trace_stats.known_type_other_calls += 1
      known_instr_type(
        value, caller_abs_idx, local_types_by_abs, global_types, direct_result_types,
        env, trace_stats,
      )
    }
    TInstrKind::TRefAsNonNull(value) => {
      trace_stats.known_type_other_calls += 1
      match
        known_instr_type(
          value, caller_abs_idx, local_types_by_abs, global_types, direct_result_types,
          env, trace_stats,
        ) {
        Some(RefTypeValType(rt)) =>
          Some(ValType::ref_type(RefType::new(false, rt.get_heap_type())))
        _ => None
      }
    }
    TInstrKind::TRefCast(nullable, ht, _) => {
      trace_stats.known_type_ref_cast_calls += 1
      Some(ValType::ref_type(RefType::new(nullable, ht)))
    }
    TInstrKind::TSelect(Some(types), _, _, _) if types.length() == 1 => {
      trace_stats.known_type_select_calls += 1
      Some(types[0])
    }
    TInstrKind::TCall(FuncIdx(raw), _)
    | TInstrKind::TReturnCall(FuncIdx(raw), _) => {
      trace_stats.known_type_call_direct_calls += 1
      let idx = raw.reinterpret_as_int()
      if idx < 0 || idx >= direct_result_types.length() {
        None
      } else {
        direct_result_types[idx]
      }
    }
    TInstrKind::TCallIndirect(type_idx, _, _, _)
    | TInstrKind::TCallRef(type_idx, _, _)
    | TInstrKind::TReturnCallIndirect(type_idx, _, _, _)
    | TInstrKind::TReturnCallRef(type_idx, _, _) => {
      trace_stats.known_type_call_indirect_calls += 1
      trace_stats.resolve_functype_calls += 1
      match env.resolve_functype(type_idx) {
        Some(func_type) => single_result_type(func_type)
        None => None
      }
    }
    _ => {
      trace_stats.known_type_other_calls += 1
      None
    }
  }
  if track_detail_timing {
    trace_stats.known_type_elapsed_us += dae_trace_elapsed_us_since(start_us)
  }
  out
}

///|
fn dae_match_types(
  value : ValType,
  expected : ValType,
  env : Env,
  trace_stats : DAETraceStats,
) -> Bool {
  trace_stats.match_calls_total += 1
  let track_detail_timing = dae_trace_detail_timing_enabled(trace_stats)
  let start_us = if track_detail_timing { dae_trace_now_us() } else { 0UL }
  let out = Match::matches(value, expected, env)
  if track_detail_timing {
    trace_stats.match_elapsed_us += dae_trace_elapsed_us_since(start_us)
  }
  out
}

///|
fn note_call_summary(
  summary : DAECallSummary,
  caller_abs_idx : Int,
  args : Array[TInstr],
  local_types_by_abs : Array[Array[ValType]],
  global_types : Array[ValType],
  direct_result_types : Array[ValType?],
  env : Env,
  trace_stats : DAETraceStats,
) -> Unit {
  for p = 0; p < summary.param_types.length(); p = p + 1 {
    if p >= args.length() {
      summary.all_pure[p] = false
      summary.const_valid[p] = false
      summary.const_candidate[p] = None
      summary.type_valid[p] = false
      summary.type_candidate[p] = None
      continue
    }
    let arg = args[p]
    if summary.all_pure[p] && not(is_trivially_pure_arg(arg)) {
      summary.all_pure[p] = false
    }
    if summary.const_valid[p] {
      if is_literal_const(arg) {
        match summary.const_candidate[p] {
          None => summary.const_candidate[p] = Some(arg)
          Some(prev) =>
            if prev != arg {
              summary.const_valid[p] = false
              summary.const_candidate[p] = None
            }
        }
      } else {
        summary.const_valid[p] = false
        summary.const_candidate[p] = None
      }
    }
    if summary.type_valid[p] {
      match
        known_instr_type(
          arg, caller_abs_idx, local_types_by_abs, global_types, direct_result_types,
          env, trace_stats,
        ) {
        Some(arg_ty) if dae_match_types(
            arg_ty,
            summary.param_types[p],
            env,
            trace_stats,
          ) =>
          summary.type_candidate[p] = match summary.type_candidate[p] {
            None => Some(arg_ty)
            Some(prev) => common_supertype(prev, arg_ty, env, trace_stats)
          }
        _ => {
          summary.type_valid[p] = false
          summary.type_candidate[p] = None
        }
      }
    }
  }
}

///|
fn note_return_summary(
  summary : DAEReturnSummary,
  values : Array[TInstr],
  abs_func_idx : Int,
  result_types : Array[ValType],
  local_types_by_abs : Array[Array[ValType]],
  global_types : Array[ValType],
  direct_result_types : Array[ValType?],
  env : Env,
  trace_stats : DAETraceStats,
) -> Unit {
  trace_stats.returns_seen += 1
  summary.has_explicit_return = true
  if summary.failed {
    return
  }
  if values.length() != result_types.length() {
    summary.failed = true
    return
  }
  for i = 0; i < result_types.length(); i = i + 1 {
    if not(summary.tracked[i]) {
      continue
    }
    match
      known_instr_type(
        values[i],
        abs_func_idx,
        local_types_by_abs,
        global_types,
        direct_result_types,
        env,
        trace_stats,
      ) {
      Some(vt) if dae_match_types(vt, result_types[i], env, trace_stats) =>
        summary.candidate[i] = match summary.candidate[i] {
          None => Some(vt)
          Some(prev) => common_supertype(prev, vt, env, trace_stats)
        }
      _ => {
        summary.failed = true
        return
      }
    }
    if summary.candidate[i] is None {
      summary.failed = true
      return
    }
  }
}

///|
fn analyze_function_body(
  abs_func_idx : Int,
  param_count : Int,
  result_types : Array[ValType],
  body : TExpr,
  call_summaries : Array[DAECallSummary],
  call_counts : Array[Int],
  dropped_call_counts : Array[Int],
  has_unseen_calls : Array[Bool],
  has_tail_calls : Array[Bool],
  tail_callee : Array[Bool],
  used_params : Set[Int],
  direct_callees : Set[Int],
  return_summary : DAEReturnSummary,
  local_types_by_abs : Array[Array[ValType]],
  global_types : Array[ValType],
  direct_result_types : Array[ValType?],
  env : Env,
  trace_stats : DAETraceStats,
) -> Unit {
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    trace_stats.analysis_instrs_visited += 1
    match instr.kind {
      TInstrKind::TLocalGet(LocalIdx(raw)) => {
        trace_stats.analysis_localgets_seen += 1
        let idx = raw.reinterpret_as_int()
        if idx >= 0 && idx < param_count {
          used_params.add(idx)
        }
      }
      TInstrKind::TDrop({ kind: TInstrKind::TCall(target, _), .. }) => {
        let FuncIdx(raw) = target
        let idx = raw.reinterpret_as_int()
        if idx >= 0 && idx < dropped_call_counts.length() {
          dropped_call_counts[idx] += 1
        }
      }
      TInstrKind::TCall(target, args) => {
        trace_stats.analysis_calls_seen += 1
        let FuncIdx(raw) = target
        let idx = raw.reinterpret_as_int()
        if idx >= 0 && idx < call_summaries.length() {
          direct_callees.add(idx)
          call_counts[idx] += 1
          note_call_summary(
            call_summaries[idx],
            abs_func_idx,
            args,
            local_types_by_abs,
            global_types,
            direct_result_types,
            env,
            trace_stats,
          )
        }
      }
      TInstrKind::TReturnCall(target, args) => {
        trace_stats.analysis_calls_seen += 1
        let FuncIdx(raw) = target
        let idx = raw.reinterpret_as_int()
        if idx >= 0 && idx < call_summaries.length() {
          direct_callees.add(idx)
          call_counts[idx] += 1
          note_call_summary(
            call_summaries[idx],
            abs_func_idx,
            args,
            local_types_by_abs,
            global_types,
            direct_result_types,
            env,
            trace_stats,
          )
        }
        if idx >= 0 && idx < tail_callee.length() {
          tail_callee[idx] = true
        }
        if abs_func_idx >= 0 && abs_func_idx < has_tail_calls.length() {
          has_tail_calls[abs_func_idx] = true
        }
      }
      TInstrKind::TReturnCallIndirect(_, _, _, _)
      | TInstrKind::TReturnCallRef(_, _, _) =>
        if abs_func_idx >= 0 && abs_func_idx < has_tail_calls.length() {
          has_tail_calls[abs_func_idx] = true
        }
      TInstrKind::TRefFunc(FuncIdx(raw)) => {
        let idx = raw.reinterpret_as_int()
        if idx >= 0 && idx < has_unseen_calls.length() {
          has_unseen_calls[idx] = true
        }
      }
      TInstrKind::TReturn(values) =>
        note_return_summary(
          return_summary, values, abs_func_idx, result_types, local_types_by_abs,
          global_types, direct_result_types, env, trace_stats,
        )
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
}

///|
fn collect_global_types(mod : Module) -> Array[ValType] {
  let out : Array[ValType] = []
  match mod.global_sec {
    Some(GlobalSec(globals)) =>
      for global in globals {
        let Global(GlobalType(vt, _), _) = global
        out.push(vt)
      }
    None => ()
  }
  out
}

///|
fn build_local_types_by_abs(
  func_types : Array[FuncType],
  funcs : Array[Func],
  import_func_count : Int,
) -> Array[Array[ValType]] {
  let out : Array[Array[ValType]] = []
  for abs_idx = 0; abs_idx < func_types.length(); abs_idx = abs_idx + 1 {
    let FuncType(params, _) = func_types[abs_idx]
    let locals = params.copy()
    let def_idx = abs_idx - import_func_count
    if def_idx >= 0 && def_idx < funcs.length() {
      match funcs[def_idx] {
        TFunc(extra_locals, _) =>
          for vt in extra_locals {
            locals.push(vt)
          }
        _ => ()
      }
    }
    out.push(locals)
  }
  out
}

///|
fn common_supertype(
  a : ValType,
  b : ValType,
  env : Env,
  trace_stats : DAETraceStats,
) -> ValType? {
  trace_stats.common_supertype_calls_total += 1
  let track_detail_timing = dae_trace_detail_timing_enabled(trace_stats)
  let start_us = if track_detail_timing { dae_trace_now_us() } else { 0UL }
  let out = if dae_match_types(a, b, env, trace_stats) {
    Some(b)
  } else if dae_match_types(b, a, env, trace_stats) {
    Some(a)
  } else {
    None
  }
  if track_detail_timing {
    trace_stats.common_supertype_elapsed_us += dae_trace_elapsed_us_since(
      start_us,
    )
  }
  out
}

///|
fn refine_param_types(
  old_params : Array[ValType],
  summary : DAECallSummary,
  env : Env,
  trace_stats : DAETraceStats,
) -> Array[ValType] {
  let new_params = old_params.copy()
  for p = 0; p < old_params.length(); p = p + 1 {
    match old_params[p] {
      RefTypeValType(_) if summary.type_valid[p] =>
        match summary.type_candidate[p] {
          Some(new_ty) if new_ty != old_params[p] &&
            dae_match_types(new_ty, old_params[p], env, trace_stats) =>
            new_params[p] = new_ty
          _ => ()
        }
      _ => ()
    }
  }
  new_params
}

///|
fn refine_return_types(
  old_results : Array[ValType],
  summary : DAEReturnSummary,
  env : Env,
  trace_stats : DAETraceStats,
) -> Array[ValType] {
  if old_results.is_empty() ||
    not(summary.has_explicit_return) ||
    summary.failed {
    return old_results
  }
  let new_results = old_results.copy()
  for i = 0; i < old_results.length(); i = i + 1 {
    match old_results[i] {
      RefTypeValType(_) =>
        match summary.candidate[i] {
          Some(candidate) if candidate != old_results[i] &&
            dae_match_types(candidate, old_results[i], env, trace_stats) =>
            new_results[i] = candidate
          _ => ()
        }
      _ => ()
    }
  }
  new_results
}

///|
fn build_local_plan(
  old_locals : Array[ValType],
  old_param_types : Array[ValType],
  removed_unused : Set[Int],
  removed_const : Map[Int, TInstr],
) -> (Array[ValType], Array[TInstr], Int, Array[Int?]) {
  let old_param_count = old_param_types.length()
  let param_remap : Array[Int?] = Array::make(old_param_count, None)
  let mut new_param_count = 0
  for p = 0; p < old_param_count; p = p + 1 {
    if removed_unused.contains(p) || removed_const.contains(p) {
      continue
    }
    param_remap[p] = Some(new_param_count)
    new_param_count += 1
  }
  let removed_total = old_param_count - new_param_count
  let new_locals = old_locals.copy()
  let prologue : Array[TInstr] = []
  for p = 0; p < old_param_count; p = p + 1 {
    match removed_const.get(p) {
      Some(const_val) => {
        let local_offset = new_locals.length()
        new_locals.push(old_param_types[p])
        let local_idx = new_param_count + local_offset
        param_remap[p] = Some(local_idx)
        prologue.push(
          TInstr::local_set(
            LocalIdx::new(local_idx.reinterpret_as_uint()),
            const_val,
          ),
        )
      }
      None => ()
    }
  }
  (new_locals, prologue, removed_total, param_remap)
}

///|
fn rewrite_local_index(
  idx : Int,
  old_param_count : Int,
  param_remap : Array[Int?],
  removed_total : Int,
) -> Int? {
  if idx < 0 {
    return Some(idx)
  }
  if idx < old_param_count {
    return param_remap[idx]
  }
  Some(idx - removed_total)
}

///|
fn filter_call_args(args : Array[TInstr], removed : Set[Int]) -> Array[TInstr] {
  if removed.is_empty() {
    return args
  }
  let out : Array[TInstr] = []
  for i = 0; i < args.length(); i = i + 1 {
    if not(removed.contains(i)) {
      out.push(args[i])
    }
  }
  out
}

///|
fn drop_implicit_result(body : TExpr) -> TExpr {
  if body.instrs.is_empty() {
    return body
  }
  let instrs = body.instrs.copy()
  let last = instrs[instrs.length() - 1]
  match last.kind {
    TInstrKind::TReturn(_) | TInstrKind::TUnreachable => body
    _ => {
      instrs[instrs.length() - 1] = TInstr::drop(last)
      TExpr::new(instrs)
    }
  }
}

///|
fn rewrite_body(
  body : TExpr,
  old_param_count : Int,
  param_remap : Array[Int?],
  removed_total : Int,
  remove_result : Bool,
  removed_params_by_target : Array[Set[Int]],
  result_removed_by_target : Array[Bool],
  target_remap : Array[Int],
  trace_stats : DAETraceStats,
  rewrite_trace : DAERewriteTrace,
  trace : (String) -> Unit,
  trace_progress : Bool,
  iter : Int,
  abs_func_idx : Int,
) -> TExpr {
  let rewrite_locals_enabled = old_param_count > 0 || removed_total != 0
  let rewrite_calls_enabled = removed_params_by_target.length() > 0 &&
    target_remap.length() > 0
  let rewrite_removed_results_enabled = result_removed_by_target.length() > 0
  let func_start_us = if trace_progress { dae_trace_now_us() } else { 0UL }
  let mut func_last_emit_us = func_start_us
  let mut func_next_progress_instr = dae_trace_rewrite_progress_check_interval()
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    trace_stats.rewrite_instrs_visited += 1
    rewrite_trace.instrs_visited += 1
    if trace_progress &&
      rewrite_trace.instrs_visited >= func_next_progress_instr {
      func_last_emit_us = dae_trace_maybe_emit_rewrite_func_progress(
        trace, trace_progress, iter, abs_func_idx, func_start_us, func_last_emit_us,
        rewrite_trace, trace_stats,
      )
      func_next_progress_instr = rewrite_trace.instrs_visited +
        dae_trace_rewrite_progress_check_interval()
    }
    let dropped_call_target = match instr.kind {
      TInstrKind::TDrop({ kind: TInstrKind::TCall(target, _), .. }) =>
        Some(target)
      _ => None
    }
    let (processed, child_changed) = match
      self.walk_tinstruction_default((), instr) {
      Ok(Some((_, i))) => (i, true)
      Ok(None) => (instr, false)
      Err(e) => return Err(e)
    }
    match processed.kind {
      TInstrKind::TLocalGet(LocalIdx(raw)) => {
        if not(rewrite_locals_enabled) {
          return if child_changed { change((), processed) } else { unchanged() }
        }
        let idx = raw.reinterpret_as_int()
        match
          rewrite_local_index(idx, old_param_count, param_remap, removed_total) {
          Some(new_idx) =>
            if new_idx == idx {
              if child_changed {
                change((), processed)
              } else {
                unchanged()
              }
            } else {
              trace_stats.local_indices_rewritten += 1
              rewrite_trace.local_indices_rewritten += 1
              change(
                (),
                TInstr::local_get(LocalIdx::new(new_idx.reinterpret_as_uint())),
              )
            }
          None => {
            trace_stats.local_indices_rewritten += 1
            rewrite_trace.local_indices_rewritten += 1
            change((), TInstr::unreachable_())
          }
        }
      }
      TInstrKind::TLocalSet(LocalIdx(raw), value) => {
        if not(rewrite_locals_enabled) {
          return if child_changed { change((), processed) } else { unchanged() }
        }
        let idx = raw.reinterpret_as_int()
        match
          rewrite_local_index(idx, old_param_count, param_remap, removed_total) {
          Some(new_idx) =>
            if new_idx == idx {
              if child_changed {
                change((), processed)
              } else {
                unchanged()
              }
            } else {
              trace_stats.local_indices_rewritten += 1
              rewrite_trace.local_indices_rewritten += 1
              change(
                (),
                TInstr::local_set(
                  LocalIdx::new(new_idx.reinterpret_as_uint()),
                  value,
                ),
              )
            }
          None => {
            trace_stats.local_indices_rewritten += 1
            rewrite_trace.local_indices_rewritten += 1
            change((), TInstr::drop(value))
          }
        }
      }
      TInstrKind::TLocalTee(LocalIdx(raw), value) => {
        if not(rewrite_locals_enabled) {
          return if child_changed { change((), processed) } else { unchanged() }
        }
        let idx = raw.reinterpret_as_int()
        match
          rewrite_local_index(idx, old_param_count, param_remap, removed_total) {
          Some(new_idx) =>
            if new_idx == idx {
              if child_changed {
                change((), processed)
              } else {
                unchanged()
              }
            } else {
              trace_stats.local_indices_rewritten += 1
              rewrite_trace.local_indices_rewritten += 1
              change(
                (),
                TInstr::local_tee(
                  LocalIdx::new(new_idx.reinterpret_as_uint()),
                  value,
                ),
              )
            }
          None => {
            trace_stats.local_indices_rewritten += 1
            rewrite_trace.local_indices_rewritten += 1
            change((), value)
          }
        }
      }
      TInstrKind::TCall(target, args) => {
        if not(rewrite_calls_enabled) {
          return if child_changed { change((), processed) } else { unchanged() }
        }
        let FuncIdx(raw) = target
        let idx = raw.reinterpret_as_int()
        if idx < 0 || idx >= removed_params_by_target.length() {
          return if child_changed { change((), processed) } else { unchanged() }
        }
        let remapped = target_remap[idx]
        let new_target = FuncIdx::new(remapped.reinterpret_as_uint())
        let new_args = filter_call_args(args, removed_params_by_target[idx])
        let removed_arg_count = args.length() - new_args.length()
        if new_args != args || remapped != idx {
          trace_stats.calls_rewritten += 1
          rewrite_trace.calls_rewritten += 1
          if removed_arg_count > 0 {
            trace_stats.filtered_call_args_total += 1
            trace_stats.filtered_call_args_removed_total += removed_arg_count
            rewrite_trace.call_args_removed += removed_arg_count
          }
          change((), TInstr::call(new_target, new_args))
        } else if child_changed {
          change((), processed)
        } else {
          unchanged()
        }
      }
      TInstrKind::TReturnCall(target, args) => {
        if not(rewrite_calls_enabled) {
          return if child_changed { change((), processed) } else { unchanged() }
        }
        let FuncIdx(raw) = target
        let idx = raw.reinterpret_as_int()
        if idx < 0 || idx >= removed_params_by_target.length() {
          return if child_changed { change((), processed) } else { unchanged() }
        }
        let remapped = target_remap[idx]
        let new_target = FuncIdx::new(remapped.reinterpret_as_uint())
        let new_args = filter_call_args(args, removed_params_by_target[idx])
        let removed_arg_count = args.length() - new_args.length()
        if new_args != args || remapped != idx {
          trace_stats.calls_rewritten += 1
          rewrite_trace.calls_rewritten += 1
          if removed_arg_count > 0 {
            trace_stats.filtered_call_args_total += 1
            trace_stats.filtered_call_args_removed_total += removed_arg_count
            rewrite_trace.call_args_removed += removed_arg_count
          }
          change((), TInstr::return_call(new_target, new_args))
        } else if child_changed {
          change((), processed)
        } else {
          unchanged()
        }
      }
      TInstrKind::TDrop(value) =>
        match dropped_call_target {
          Some(FuncIdx(raw)) => {
            if not(rewrite_removed_results_enabled) {
              return if child_changed {
                change((), processed)
              } else {
                unchanged()
              }
            }
            let idx = raw.reinterpret_as_int()
            if idx >= 0 &&
              idx < result_removed_by_target.length() &&
              result_removed_by_target[idx] {
              trace_stats.drops_removed_due_to_result += 1
              rewrite_trace.drops_removed += 1
              change((), value)
            } else if child_changed {
              change((), processed)
            } else {
              unchanged()
            }
          }
          None =>
            if child_changed {
              change((), processed)
            } else {
              unchanged()
            }
        }
      TInstrKind::TReturn(values) if remove_result && values.length() > 0 =>
        change((), TInstr::return_([]))
      _ => if child_changed { change((), processed) } else { unchanged() }
    }
  })
  match walker.walk_texpr((), body) {
    Ok(Some((_, new_body))) =>
      if remove_result {
        drop_implicit_result(new_body)
      } else {
        new_body
      }
    _ => if remove_result { drop_implicit_result(body) } else { body }
  }
}

///|
fn rewrite_locals_and_returns(
  body : TExpr,
  old_param_count : Int,
  param_remap : Array[Int?],
  removed_total : Int,
  remove_result : Bool,
) -> TExpr {
  let no_removed_params : Array[Set[Int]] = []
  let no_removed_results : Array[Bool] = []
  let no_target_remap : Array[Int] = []
  rewrite_body(
    body,
    old_param_count,
    param_remap,
    removed_total,
    remove_result,
    no_removed_params,
    no_removed_results,
    no_target_remap,
    DAETraceStats::new(),
    DAERewriteTrace::new(),
    dead_argument_elim_trace_noop,
    false,
    -1,
    -1,
  )
}

///|
fn make_adapter_thunk(
  target_abs_idx : Int,
  old_params : Array[ValType],
  old_results : Array[ValType],
  removed_unused : Set[Int],
  removed_const : Map[Int, TInstr],
  remove_result : Bool,
) -> Func {
  let call_args : Array[TInstr] = []
  for p = 0; p < old_params.length(); p = p + 1 {
    if removed_unused.contains(p) {
      continue
    }
    match removed_const.get(p) {
      Some(v) => call_args.push(v)
      None =>
        call_args.push(
          TInstr::local_get(LocalIdx::new(p.reinterpret_as_uint())),
        )
    }
  }
  let target = FuncIdx::new(target_abs_idx.reinterpret_as_uint())
  let body = if remove_result {
    TExpr::new([TInstr::call(target, call_args), TInstr::return_([])])
  } else if old_results.length() == 0 {
    TExpr::new([TInstr::call(target, call_args), TInstr::return_([])])
  } else {
    TExpr::new([TInstr::return_([TInstr::call(target, call_args)])])
  }
  Func::t_func([], body)
}

///|
fn dae_trace_emit_iteration(
  trace : (String) -> Unit,
  iter : Int,
  elapsed_us : UInt64,
  result : DAEOnceResult,
) -> Unit {
  let stats = result.stats
  trace(
    "iter=\{iter} changed=\{result.changed} elapsed_ms=\{dae_trace_delta_us_to_ms(elapsed_us)} setup_ms=\{dae_trace_delta_us_to_ms(stats.setup_us)} analysis_ms=\{dae_trace_delta_us_to_ms(stats.analysis_us)} decide_ms=\{dae_trace_delta_us_to_ms(stats.decide_us)} sig_ms=\{dae_trace_delta_us_to_ms(stats.sig_us)} rewrite_ms=\{dae_trace_delta_us_to_ms(stats.rewrite_us)} signature_changed=\{result.signature_changed} body_changed=\{result.body_changed}",
  )
  trace(
    "iter=\{iter} funcs=\{result.defined_funcs} abs_funcs=\{result.abs_funcs} flat_types=\{result.flat_type_count_after} clones=\{result.appended_clones} removed_params=\{stats.removed_params_total} const=\{stats.removed_const_params_total} unused=\{stats.removed_unused_params_total} result_removed=\{stats.result_removals_total} param_refined=\{stats.params_refined_total} result_refined=\{stats.results_refined_total}",
  )
  trace(
    "iter=\{iter} analysis_instrs=\{stats.analysis_instrs_visited} rewrite_instrs=\{stats.rewrite_instrs_visited} analysis_calls=\{stats.analysis_calls_seen} analysis_localgets=\{stats.analysis_localgets_seen} returns=\{stats.returns_seen} known_type_calls=\{stats.known_type_calls_total} resolve_functype_calls=\{stats.resolve_functype_calls} match_calls=\{stats.match_calls_total} common_supertype_calls=\{stats.common_supertype_calls_total}",
  )
  trace(
    "iter=\{iter} rewrite_funcs=\{stats.functions_rewritten} calls_rewritten=\{stats.calls_rewritten} locals_rewritten=\{stats.local_indices_rewritten} drops_removed=\{stats.drops_removed_due_to_result} filtered_calls=\{stats.filtered_call_args_total} filtered_args_removed=\{stats.filtered_call_args_removed_total} prologues=\{stats.prologue_inserted_funcs} oscillation_suspects=\{stats.oscillation_suspects}",
  )
}

///|
fn dae_trace_emit_iteration_details(
  trace : (String) -> Unit,
  iter : Int,
  result : DAEOnceResult,
) -> Unit {
  let stats = result.stats
  trace(
    "iter=\{iter} setup_detail_ms collect_func_types=\{dae_trace_delta_us_to_ms(stats.setup_collect_func_types_us)} build_local_types=\{dae_trace_delta_us_to_ms(stats.setup_build_local_types_us)} collect_globals=\{dae_trace_delta_us_to_ms(stats.setup_collect_global_types_us)} collect_direct_results=\{dae_trace_delta_us_to_ms(stats.setup_collect_direct_results_us)} init_arrays=\{dae_trace_delta_us_to_ms(stats.setup_init_arrays_us)} known_type_ms=\{dae_trace_delta_us_to_ms(stats.known_type_elapsed_us)} match_ms=\{dae_trace_delta_us_to_ms(stats.match_elapsed_us)} common_supertype_ms=\{dae_trace_delta_us_to_ms(stats.common_supertype_elapsed_us)} known_type_local_get=\{stats.known_type_local_get_calls} known_type_global_get=\{stats.known_type_global_get_calls} known_type_call_direct=\{stats.known_type_call_direct_calls} known_type_call_indirect=\{stats.known_type_call_indirect_calls} known_type_ref_cast=\{stats.known_type_ref_cast_calls} known_type_select=\{stats.known_type_select_calls} known_type_other=\{stats.known_type_other_calls}",
  )
  dae_trace_emit_hotspots(
    trace,
    "iter=\{iter} slow_analysis_funcs",
    stats.analysis_hotspots,
    10,
  )
  dae_trace_emit_hotspots(
    trace,
    "iter=\{iter} slow_rewrite_funcs",
    stats.rewrite_hotspots,
    10,
  )
  for sample in stats.oscillation_samples {
    trace("iter=\{iter} oscillation=\{sample}")
  }
}

///|
fn dae_trace_emit_phase_start(
  trace : (String) -> Unit,
  enabled : Bool,
  iter : Int,
  phase : String,
  total : Int,
) -> UInt64 {
  if not(enabled) {
    return 0UL
  }
  let start_us = dae_trace_now_us()
  trace("iter=\{iter} phase=\{phase}:start total=\{total}")
  start_us
}

///|
fn dae_trace_maybe_emit_phase_progress(
  trace : (String) -> Unit,
  enabled : Bool,
  iter : Int,
  phase : String,
  phase_start_us : UInt64,
  last_emit_us : UInt64,
  current : Int,
  total : Int,
  stats : DAETraceStats,
) -> UInt64 {
  if not(enabled) {
    return last_emit_us
  }
  let now_us = dae_trace_now_us()
  let since_last_emit_us = if now_us >= last_emit_us {
    now_us - last_emit_us
  } else {
    0UL
  }
  let phase_elapsed_us = if now_us >= phase_start_us {
    now_us - phase_start_us
  } else {
    0UL
  }
  if current < total && since_last_emit_us < 1000000UL {
    return last_emit_us
  }
  trace(
    "iter=\{iter} phase=\{phase} progress=\{current}/\{total} phase_ms=\{dae_trace_delta_us_to_ms(phase_elapsed_us)} analysis_instrs=\{stats.analysis_instrs_visited} rewrite_instrs=\{stats.rewrite_instrs_visited} known_type_calls=\{stats.known_type_calls_total} match_calls=\{stats.match_calls_total}",
  )
  now_us
}

///|
fn dae_trace_emit_phase_done(
  trace : (String) -> Unit,
  enabled : Bool,
  iter : Int,
  phase : String,
  phase_start_us : UInt64,
  total : Int,
  stats : DAETraceStats,
) -> Unit {
  if not(enabled) {
    return
  }
  trace(
    "iter=\{iter} phase=\{phase}:done total=\{total} elapsed_ms=\{dae_trace_delta_us_to_ms(dae_trace_elapsed_us_since(phase_start_us))} analysis_instrs=\{stats.analysis_instrs_visited} rewrite_instrs=\{stats.rewrite_instrs_visited} known_type_calls=\{stats.known_type_calls_total} match_calls=\{stats.match_calls_total}",
  )
}

///|
fn dae_trace_maybe_emit_rewrite_func_progress(
  trace : (String) -> Unit,
  enabled : Bool,
  iter : Int,
  abs_func_idx : Int,
  func_start_us : UInt64,
  last_emit_us : UInt64,
  rewrite_trace : DAERewriteTrace,
  stats : DAETraceStats,
) -> UInt64 {
  if not(enabled) {
    return last_emit_us
  }
  let now_us = dae_trace_now_us()
  let since_last_emit_us = if now_us >= last_emit_us {
    now_us - last_emit_us
  } else {
    0UL
  }
  if since_last_emit_us < 1000000UL {
    return last_emit_us
  }
  let func_elapsed_us = if now_us >= func_start_us {
    now_us - func_start_us
  } else {
    0UL
  }
  trace(
    "iter=\{iter} phase=rewrite func=\{abs_func_idx} func_ms=\{dae_trace_delta_us_to_ms(func_elapsed_us)} func_instrs=\{rewrite_trace.instrs_visited} func_calls_rewritten=\{rewrite_trace.calls_rewritten} func_locals_rewritten=\{rewrite_trace.local_indices_rewritten} func_drops_removed=\{rewrite_trace.drops_removed} total_rewrite_instrs=\{stats.rewrite_instrs_visited}",
  )
  now_us
}

///|
fn function_needs_call_rewrite(
  direct_callees : Set[Int],
  removed_params_by_target : Array[Set[Int]],
  result_removed_by_target : Array[Bool],
  target_remap : Array[Int],
) -> Bool {
  for callee in direct_callees.iter() {
    if not(removed_params_by_target[callee].is_empty()) {
      return true
    }
    if callee < result_removed_by_target.length() &&
      result_removed_by_target[callee] {
      return true
    }
    if callee < target_remap.length() && target_remap[callee] != callee {
      return true
    }
  }
  false
}

///|
fn run_dead_argument_elim_once(
  mod : Module,
  trace : (String) -> Unit,
  iter : Int,
  trace_progress : Bool,
) -> DAEOnceResult {
  let stats = DAETraceStats::new(detail_timing_enabled=trace_progress)
  let funcs = match mod.code_sec {
    Some(CodeSec(funcs)) => funcs
    None =>
      return {
        mod,
        changed: false,
        signature_changed: false,
        body_changed: false,
        appended_clones: 0,
        defined_funcs: 0,
        abs_funcs: 0,
        flat_type_count_after: 0,
        stats,
      }
  }
  let func_sec = match mod.func_sec {
    Some(FuncSec(type_idxs)) => type_idxs
    None =>
      return {
        mod,
        changed: false,
        signature_changed: false,
        body_changed: false,
        appended_clones: 0,
        defined_funcs: funcs.length(),
        abs_funcs: 0,
        flat_type_count_after: 0,
        stats,
      }
  }
  if funcs.is_empty() {
    return {
      mod,
      changed: false,
      signature_changed: false,
      body_changed: false,
      appended_clones: 0,
      defined_funcs: 0,
      abs_funcs: 0,
      flat_type_count_after: 0,
      stats,
    }
  }
  let setup_start_us = dae_trace_now_us()
  let collect_func_types_start_us = dae_trace_now_us()
  let func_types = collect_func_types(mod)
  stats.setup_collect_func_types_us += dae_trace_elapsed_us_since(
    collect_func_types_start_us,
  )
  let total_func_count = func_types.length()
  if total_func_count == 0 {
    stats.setup_us += dae_trace_elapsed_us_since(setup_start_us)
    return {
      mod,
      changed: false,
      signature_changed: false,
      body_changed: false,
      appended_clones: 0,
      defined_funcs: funcs.length(),
      abs_funcs: 0,
      flat_type_count_after: 0,
      stats,
    }
  }
  let import_func_count = count_imported_funcs(mod)
  let env = Env::new().with_module(mod)
  let build_local_types_start_us = dae_trace_now_us()
  let local_types_by_abs = build_local_types_by_abs(
    func_types, funcs, import_func_count,
  )
  stats.setup_build_local_types_us += dae_trace_elapsed_us_since(
    build_local_types_start_us,
  )
  let collect_globals_start_us = dae_trace_now_us()
  let global_types = collect_global_types(mod)
  stats.setup_collect_global_types_us += dae_trace_elapsed_us_since(
    collect_globals_start_us,
  )
  let collect_direct_results_start_us = dae_trace_now_us()
  let direct_result_types = collect_direct_result_types(func_types)
  stats.setup_collect_direct_results_us += dae_trace_elapsed_us_since(
    collect_direct_results_start_us,
  )
  let init_arrays_start_us = dae_trace_now_us()
  let call_summaries : Array[DAECallSummary] = []
  for abs_idx = 0; abs_idx < total_func_count; abs_idx = abs_idx + 1 {
    let FuncType(params, _) = func_types[abs_idx]
    call_summaries.push(DAECallSummary::new(params))
  }
  let call_counts : Array[Int] = Array::make(total_func_count, 0)
  let dropped_call_counts : Array[Int] = Array::make(total_func_count, 0)
  let has_unseen_calls : Array[Bool] = Array::make(total_func_count, false)
  let has_tail_calls : Array[Bool] = Array::make(total_func_count, false)
  let tail_callee : Array[Bool] = Array::make(total_func_count, false)
  mark_exports_unseen(mod, has_unseen_calls)
  mark_start_unseen(mod, has_unseen_calls)
  mark_elem_unseen(mod, has_unseen_calls)
  stats.setup_init_arrays_us += dae_trace_elapsed_us_since(init_arrays_start_us)
  stats.setup_us += dae_trace_elapsed_us_since(setup_start_us)
  let used_params_by_defined : Array[Set[Int]] = []
  let direct_callees_by_defined : Array[Set[Int]] = []
  let return_summaries : Array[DAEReturnSummary] = []
  let body_can_remove_result : Array[Bool] = []
  let analysis_start_us = dae_trace_now_us()
  let analysis_phase_start_us = dae_trace_emit_phase_start(
    trace,
    trace_progress,
    iter,
    "analysis",
    funcs.length(),
  )
  let mut analysis_last_emit_us = analysis_phase_start_us
  for i = 0; i < funcs.length(); i = i + 1 {
    let func_analysis_start_us = if trace_progress {
      dae_trace_now_us()
    } else {
      0UL
    }
    let abs_idx = import_func_count + i
    let used_params : Set[Int] = Set::new()
    let direct_callees : Set[Int] = Set::new()
    used_params_by_defined.push(used_params)
    direct_callees_by_defined.push(direct_callees)
    match funcs[i] {
      TFunc(_, body) => {
        let FuncType(params, results) = if abs_idx >= 0 &&
          abs_idx < total_func_count {
          func_types[abs_idx]
        } else {
          FuncType::new([], [])
        }
        let return_summary = DAEReturnSummary::new(results)
        return_summaries.push(return_summary)
        if abs_idx >= 0 && abs_idx < total_func_count {
          analyze_function_body(
            abs_idx,
            params.length(),
            results,
            body,
            call_summaries,
            call_counts,
            dropped_call_counts,
            has_unseen_calls,
            has_tail_calls,
            tail_callee,
            used_params,
            direct_callees,
            return_summary,
            local_types_by_abs,
            global_types,
            direct_result_types,
            env,
            stats,
          )
        }
        body_can_remove_result.push(
          body_can_drop_result(
            body,
            results.length(),
            return_summary.has_explicit_return,
          ),
        )
      }
      _ => {
        return_summaries.push(DAEReturnSummary::new([]))
        body_can_remove_result.push(false)
      }
    }
    if trace_progress {
      dae_trace_record_hotspot(
        stats.analysis_hotspots,
        abs_idx,
        dae_trace_elapsed_us_since(func_analysis_start_us),
      )
    }
    analysis_last_emit_us = dae_trace_maybe_emit_phase_progress(
      trace,
      trace_progress,
      iter,
      "analysis",
      analysis_phase_start_us,
      analysis_last_emit_us,
      i + 1,
      funcs.length(),
      stats,
    )
  }
  stats.analysis_us += dae_trace_elapsed_us_since(analysis_start_us)
  dae_trace_emit_phase_done(
    trace,
    trace_progress,
    iter,
    "analysis",
    analysis_phase_start_us,
    funcs.length(),
    stats,
  )
  let removed_unused_by_defined : Array[Set[Int]] = []
  let removed_const_by_defined : Array[Map[Int, TInstr]] = []
  let result_removed_by_defined : Array[Bool] = []
  let refined_params_by_defined : Array[Array[ValType]] = []
  let refined_results_by_defined : Array[Array[ValType]] = []
  let removed_params_by_target : Array[Set[Int]] = []
  for i = 0; i < total_func_count; i = i + 1 {
    ignore(i)
    removed_params_by_target.push(Set::new())
  }
  let result_removed_by_target : Array[Bool] = Array::make(
    total_func_count, false,
  )
  let decide_start_us = dae_trace_now_us()
  let decide_phase_start_us = dae_trace_emit_phase_start(
    trace,
    trace_progress,
    iter,
    "decide",
    funcs.length(),
  )
  let mut decide_last_emit_us = decide_phase_start_us
  for i = 0; i < funcs.length(); i = i + 1 {
    let abs_idx = import_func_count + i
    let removed_unused : Set[Int] = Set::new()
    let removed_const : Map[Int, TInstr] = Map::new()
    let mut remove_result = false
    let mut refined_params : Array[ValType] = []
    let mut refined_results : Array[ValType] = []
    if abs_idx >= 0 && abs_idx < total_func_count {
      let FuncType(params, results) = func_types[abs_idx]
      let call_summary = call_summaries[abs_idx]
      let used_params = used_params_by_defined[i]
      refined_params = if has_unseen_calls[abs_idx] {
        params.copy()
      } else {
        refine_param_types(params, call_summary, env, stats)
      }
      refined_results = if has_tail_calls[abs_idx] {
        results.copy()
      } else {
        refine_return_types(results, return_summaries[i], env, stats)
      }
      for p = 0; p < params.length(); p = p + 1 {
        if p < refined_params.length() && refined_params[p] != params[p] {
          stats.params_refined_total += 1
        }
      }
      for r = 0; r < results.length(); r = r + 1 {
        if r < refined_results.length() && refined_results[r] != results[r] {
          stats.results_refined_total += 1
        }
      }
      if call_counts[abs_idx] > 0 {
        for p = 0; p < refined_params.length(); p = p + 1 {
          if not(call_summary.all_pure[p]) {
            continue
          }
          if not(has_unseen_calls[abs_idx]) {
            match call_summary.const_candidate[p] {
              Some(c) if call_summary.const_valid[p] => {
                removed_const.set(p, c)
                stats.removed_const_params_total += 1
              }
              _ =>
                if not(used_params.contains(p)) {
                  removed_unused.add(p)
                  stats.removed_unused_params_total += 1
                }
            }
          } else if not(used_params.contains(p)) {
            removed_unused.add(p)
            stats.removed_unused_params_total += 1
          }
        }
      }
      let removed_all : Set[Int] = Set::new()
      for p = 0; p < refined_params.length(); p = p + 1 {
        if removed_unused.contains(p) || removed_const.contains(p) {
          removed_all.add(p)
          stats.removed_params_total += 1
        }
      }
      removed_params_by_target[abs_idx] = removed_all
      if not(has_unseen_calls[abs_idx]) &&
        not(has_tail_calls[abs_idx]) &&
        not(tail_callee[abs_idx]) &&
        results.length() > 0 &&
        call_counts[abs_idx] > 0 &&
        call_counts[abs_idx] == dropped_call_counts[abs_idx] &&
        body_can_remove_result[i] {
        remove_result = true
        result_removed_by_target[abs_idx] = true
        stats.result_removals_total += 1
      }
    } else {
      refined_params = []
      refined_results = []
    }
    removed_unused_by_defined.push(removed_unused)
    removed_const_by_defined.push(removed_const)
    result_removed_by_defined.push(remove_result)
    refined_params_by_defined.push(refined_params)
    refined_results_by_defined.push(refined_results)
    decide_last_emit_us = dae_trace_maybe_emit_phase_progress(
      trace,
      trace_progress,
      iter,
      "decide",
      decide_phase_start_us,
      decide_last_emit_us,
      i + 1,
      funcs.length(),
      stats,
    )
  }
  stats.decide_us += dae_trace_elapsed_us_since(decide_start_us)
  dae_trace_emit_phase_done(
    trace,
    trace_progress,
    iter,
    "decide",
    decide_phase_start_us,
    funcs.length(),
    stats,
  )
  let type_recs = match mod.type_sec {
    Some(TypeSec(rs)) => rs.copy()
    None => []
  }
  let func_type_idxs = func_sec.copy()
  let mut flat_type_count = flattened_type_count(type_recs)
  let mut signature_changed = false
  let has_signature_change_by_defined : Array[Bool] = Array::make(
    funcs.length(),
    false,
  )
  let adapted_by_defined : Array[Bool] = Array::make(funcs.length(), false)
  let cloned_new_type_idx_by_defined : Array[TypeIdx?] = Array::make(
    funcs.length(),
    None,
  )
  let target_remap : Array[Int] = []
  for i = 0; i < total_func_count; i = i + 1 {
    target_remap.push(i)
  }
  let old_total_func_count = total_func_count
  let mut appended_clones = 0
  let sig_start_us = dae_trace_now_us()
  let sig_phase_start_us = dae_trace_emit_phase_start(
    trace,
    trace_progress,
    iter,
    "signature",
    funcs.length(),
  )
  let mut sig_last_emit_us = sig_phase_start_us
  for i = 0; i < funcs.length() && i < func_type_idxs.length(); i = i + 1 {
    let abs_idx = import_func_count + i
    if abs_idx < 0 || abs_idx >= total_func_count {
      sig_last_emit_us = dae_trace_maybe_emit_phase_progress(
        trace,
        trace_progress,
        iter,
        "signature",
        sig_phase_start_us,
        sig_last_emit_us,
        i + 1,
        funcs.length(),
        stats,
      )
      continue
    }
    let removed = removed_params_by_target[abs_idx]
    let remove_result = result_removed_by_target[abs_idx]
    let FuncType(old_params, old_results) = func_types[abs_idx]
    let refined_params = refined_params_by_defined[i]
    let refined_results = refined_results_by_defined[i]
    let params_refined = refined_params != old_params
    let results_refined = refined_results != old_results
    let has_elimination = not(removed.is_empty()) || remove_result
    if removed.is_empty() &&
      not(remove_result) &&
      not(params_refined) &&
      not(results_refined) {
      sig_last_emit_us = dae_trace_maybe_emit_phase_progress(
        trace,
        trace_progress,
        iter,
        "signature",
        sig_phase_start_us,
        sig_last_emit_us,
        i + 1,
        funcs.length(),
        stats,
      )
      continue
    }
    if has_unseen_calls[abs_idx] && not(has_elimination) {
      sig_last_emit_us = dae_trace_maybe_emit_phase_progress(
        trace,
        trace_progress,
        iter,
        "signature",
        sig_phase_start_us,
        sig_last_emit_us,
        i + 1,
        funcs.length(),
        stats,
      )
      continue
    }
    if has_unseen_calls[abs_idx] && old_results.length() > 1 {
      removed_params_by_target[abs_idx].clear()
      result_removed_by_target[abs_idx] = false
      removed_unused_by_defined[i].clear()
      removed_const_by_defined[i].clear()
      result_removed_by_defined[i] = false
      refined_params_by_defined[i] = old_params.copy()
      refined_results_by_defined[i] = old_results.copy()
      sig_last_emit_us = dae_trace_maybe_emit_phase_progress(
        trace,
        trace_progress,
        iter,
        "signature",
        sig_phase_start_us,
        sig_last_emit_us,
        i + 1,
        funcs.length(),
        stats,
      )
      continue
    }
    has_signature_change_by_defined[i] = true
    let new_params : Array[ValType] = []
    for p = 0; p < refined_params.length(); p = p + 1 {
      if not(removed.contains(p)) {
        new_params.push(refined_params[p])
      }
    }
    let new_results = if remove_result { [] } else { refined_results.copy() }
    type_recs.push(make_func_type(new_params, new_results))
    let new_type_idx = TypeIdx::new(flat_type_count.reinterpret_as_uint())
    flat_type_count += 1
    if has_unseen_calls[abs_idx] {
      adapted_by_defined[i] = true
      cloned_new_type_idx_by_defined[i] = Some(new_type_idx)
      let new_abs_idx = old_total_func_count + appended_clones
      target_remap[abs_idx] = new_abs_idx
      appended_clones += 1
    } else {
      func_type_idxs[i] = new_type_idx
    }
    signature_changed = true
    sig_last_emit_us = dae_trace_maybe_emit_phase_progress(
      trace,
      trace_progress,
      iter,
      "signature",
      sig_phase_start_us,
      sig_last_emit_us,
      i + 1,
      funcs.length(),
      stats,
    )
  }
  if appended_clones > 0 {
    for i = 0; i < funcs.length(); i = i + 1 {
      if not(adapted_by_defined[i]) {
        continue
      }
      match cloned_new_type_idx_by_defined[i] {
        Some(type_idx) => func_type_idxs.push(type_idx)
        None => ()
      }
    }
  }
  stats.sig_us += dae_trace_elapsed_us_since(sig_start_us)
  dae_trace_emit_phase_done(
    trace,
    trace_progress,
    iter,
    "signature",
    sig_phase_start_us,
    funcs.length(),
    stats,
  )
  let mut out_mod = mod
  if signature_changed {
    out_mod = out_mod
      .with_type_sec(TypeSec::new(type_recs))
      .with_func_sec(FuncSec::new(func_type_idxs))
  }
  let new_funcs : Array[Func] = []
  let appended_clones_funcs : Array[Func] = []
  let mut body_changed = false
  let rewrite_start_us = dae_trace_now_us()
  let rewrite_phase_start_us = dae_trace_emit_phase_start(
    trace,
    trace_progress,
    iter,
    "rewrite",
    funcs.length(),
  )
  let mut rewrite_last_emit_us = rewrite_phase_start_us
  for i = 0; i < funcs.length(); i = i + 1 {
    let func_rewrite_start_us = if trace_progress {
      dae_trace_now_us()
    } else {
      0UL
    }
    let abs_idx = import_func_count + i
    match funcs[i] {
      TFunc(locals, body) if abs_idx >= 0 && abs_idx < total_func_count => {
        let FuncType(old_params, _) = func_types[abs_idx]
        let removed_unused = removed_unused_by_defined[i]
        let removed_const = removed_const_by_defined[i]
        let remove_result = result_removed_by_defined[i]
        let rewrite_trace = DAERewriteTrace::new()
        let (new_locals, prologue, removed_total, param_remap) = build_local_plan(
          locals, old_params, removed_unused, removed_const,
        )
        let needs_local_rewrite = removed_total != 0 || remove_result
        let needs_call_rewrite = function_needs_call_rewrite(
          direct_callees_by_defined[i],
          removed_params_by_target,
          result_removed_by_target,
          target_remap,
        )
        if not(prologue.is_empty()) {
          stats.prologue_inserted_funcs += 1
        }
        let body1 = if needs_local_rewrite || needs_call_rewrite {
          rewrite_body(
            body,
            old_params.length(),
            param_remap,
            removed_total,
            remove_result,
            removed_params_by_target,
            result_removed_by_target,
            target_remap,
            stats,
            rewrite_trace,
            trace,
            trace_progress,
            iter,
            abs_idx,
          )
        } else {
          body
        }
        let final_body = if prologue.is_empty() {
          body1
        } else {
          TExpr::new([..prologue, ..body1.instrs])
        }
        let new_func = Func::t_func(new_locals, final_body)
        let mut emitted_func_changed = false
        if adapted_by_defined[i] {
          let FuncType(old_params, old_results) = func_types[abs_idx]
          let thunk = make_adapter_thunk(
            target_remap[abs_idx],
            old_params,
            old_results,
            removed_unused,
            removed_const,
            remove_result,
          )
          if thunk != funcs[i] {
            body_changed = true
            emitted_func_changed = true
          }
          new_funcs.push(thunk)
          appended_clones_funcs.push(new_func)
        } else {
          new_funcs.push(new_func)
          emitted_func_changed = new_func != funcs[i]
        }
        if emitted_func_changed {
          stats.functions_rewritten += 1
        }
        let old_instr_count = dae_count_texpr_instrs(body)
        let new_instr_count = dae_count_texpr_instrs(final_body)
        if not(adapted_by_defined[i]) &&
          new_func != funcs[i] &&
          dae_body_fingerprint(body) == dae_body_fingerprint(final_body) {
          stats.oscillation_suspects += 1
          if stats.oscillation_samples.length() < 5 {
            stats.oscillation_samples.push(
              "func=\{abs_idx} old_instrs=\{old_instr_count} new_instrs=\{new_instr_count} old_locals=\{locals.length()} new_locals=\{new_locals.length()} prologue=\{not(prologue.is_empty())} removed_unused=\{removed_unused_by_defined[i].is_empty() == false} removed_const=\{removed_const_by_defined[i].is_empty() == false} rewrite_instrs=\{rewrite_trace.instrs_visited} calls_rewritten=\{rewrite_trace.calls_rewritten} locals_rewritten=\{rewrite_trace.local_indices_rewritten} drops_removed=\{rewrite_trace.drops_removed} call_args_removed=\{rewrite_trace.call_args_removed}",
            )
          }
        }
        if new_func != funcs[i] || has_signature_change_by_defined[i] {
          body_changed = true
        }
        if trace_progress {
          dae_trace_record_hotspot(
            stats.rewrite_hotspots,
            abs_idx,
            dae_trace_elapsed_us_since(func_rewrite_start_us),
          )
        }
        rewrite_last_emit_us = dae_trace_maybe_emit_phase_progress(
          trace,
          trace_progress,
          iter,
          "rewrite",
          rewrite_phase_start_us,
          rewrite_last_emit_us,
          i + 1,
          funcs.length(),
          stats,
        )
      }
      TFunc(_, body) => {
        let rewrite_trace = DAERewriteTrace::new()
        let rewritten = if function_needs_call_rewrite(
            direct_callees_by_defined[i],
            removed_params_by_target,
            result_removed_by_target,
            target_remap,
          ) {
          rewrite_body(
            body,
            0,
            [],
            0,
            false,
            removed_params_by_target,
            result_removed_by_target,
            target_remap,
            stats,
            rewrite_trace,
            trace,
            trace_progress,
            iter,
            abs_idx,
          )
        } else {
          body
        }
        if rewritten != body {
          body_changed = true
          stats.functions_rewritten += 1
          match funcs[i] {
            TFunc(ls, _) => new_funcs.push(Func::t_func(ls, rewritten))
            _ => new_funcs.push(funcs[i])
          }
        } else {
          new_funcs.push(funcs[i])
        }
        if trace_progress {
          dae_trace_record_hotspot(
            stats.rewrite_hotspots,
            abs_idx,
            dae_trace_elapsed_us_since(func_rewrite_start_us),
          )
        }
        rewrite_last_emit_us = dae_trace_maybe_emit_phase_progress(
          trace,
          trace_progress,
          iter,
          "rewrite",
          rewrite_phase_start_us,
          rewrite_last_emit_us,
          i + 1,
          funcs.length(),
          stats,
        )
      }
      _ => {
        new_funcs.push(funcs[i])
        if trace_progress {
          dae_trace_record_hotspot(
            stats.rewrite_hotspots,
            abs_idx,
            dae_trace_elapsed_us_since(func_rewrite_start_us),
          )
        }
        rewrite_last_emit_us = dae_trace_maybe_emit_phase_progress(
          trace,
          trace_progress,
          iter,
          "rewrite",
          rewrite_phase_start_us,
          rewrite_last_emit_us,
          i + 1,
          funcs.length(),
          stats,
        )
      }
    }
  }
  for clone in appended_clones_funcs {
    new_funcs.push(clone)
  }
  stats.rewrite_us += dae_trace_elapsed_us_since(rewrite_start_us)
  dae_trace_emit_phase_done(
    trace,
    trace_progress,
    iter,
    "rewrite",
    rewrite_phase_start_us,
    funcs.length(),
    stats,
  )
  if not(signature_changed) && not(body_changed) {
    return {
      mod,
      changed: false,
      signature_changed,
      body_changed,
      appended_clones,
      defined_funcs: funcs.length(),
      abs_funcs: total_func_count,
      flat_type_count_after: flat_type_count,
      stats,
    }
  }
  {
    mod: out_mod.with_code_sec(CodeSec::new(new_funcs)),
    changed: true,
    signature_changed,
    body_changed,
    appended_clones,
    defined_funcs: funcs.length(),
    abs_funcs: total_func_count,
    flat_type_count_after: flat_type_count,
    stats,
  }
}

///|
fn run_dead_argument_elim_with_trace(
  mod : Module,
  trace : (String) -> Unit,
  trace_all_funcs? : Bool = false,
) -> Module {
  let mut curr = mod
  let max_iters = match mod.code_sec {
    Some(CodeSec(funcs)) => funcs.length() + 8
    None => 1
  }
  let run_start_us = dae_trace_now_us()
  let mut iter_count = 0
  for iter = 0; iter < max_iters; iter = iter + 1 {
    iter_count = iter + 1
    let iter_start_us = dae_trace_now_us()
    let result = run_dead_argument_elim_once(curr, trace, iter, trace_all_funcs)
    let iter_elapsed_us = dae_trace_elapsed_us_since(iter_start_us)
    dae_trace_emit_iteration(trace, iter, iter_elapsed_us, result)
    if trace_all_funcs {
      dae_trace_emit_iteration_details(trace, iter, result)
    }
    if not(result.changed) {
      trace(
        "done converged=true iterations=\{iter_count} elapsed_ms=\{dae_trace_delta_us_to_ms(dae_trace_elapsed_us_since(run_start_us))}",
      )
      return result.mod
    }
    curr = result.mod
  }
  trace(
    "done converged=false iterations=\{iter_count} elapsed_ms=\{dae_trace_delta_us_to_ms(dae_trace_elapsed_us_since(run_start_us))}",
  )
  curr
}

///|
fn run_dead_argument_elim(mod : Module) -> Module {
  run_dead_argument_elim_with_trace(mod, dead_argument_elim_trace_noop)
}

///|
test "dead argument elimination removes unused params from signatures" {
  // f0() -> i32: call f1(i32.const 9)
  // f1(i32) -> i32: parameter unused, returns const
  let caller = Func::t_func(
    [],
    TExpr::new([TInstr::call(FuncIdx::new(1), [TInstr::i32_const(I32(9))])]),
  )
  let callee = Func::t_func([], TExpr::new([TInstr::i32_const(I32(7))]))
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        make_func_type([ValType::i32()], [ValType::i32()]),
        make_func_type([], [ValType::i32()]),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1), TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([caller, callee]))
  let optimized = run_dead_argument_elim(mod)
  match optimized.code_sec {
    Some(
      CodeSec(
        [
          TFunc(_, { instrs: [{ kind: TInstrKind::TCall(_, args), .. }], .. }),
          _,
        ]
      )
    ) => assert_eq(args.length(), 0)
    _ => fail("expected rewritten call argument list")
  }
  match optimized.func_sec {
    Some(FuncSec(type_idxs)) =>
      // callee got a fresh, appended type index
      assert_eq(type_idxs[1], TypeIdx::new(2))
    None => fail("expected func section")
  }
}

///|
test "dead argument elimination removes constant params and seeds entry local" {
  // f0() -> i32: call f1(i32.const 42)
  // f1(i32) -> i32: returns local.get 0
  let caller = Func::t_func(
    [],
    TExpr::new([TInstr::call(FuncIdx::new(1), [TInstr::i32_const(I32(42))])]),
  )
  let callee = Func::t_func(
    [],
    TExpr::new([TInstr::local_get(LocalIdx::new(0))]),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        make_func_type([ValType::i32()], [ValType::i32()]),
        make_func_type([], [ValType::i32()]),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1), TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([caller, callee]))
  let optimized = run_dead_argument_elim(mod)
  match optimized.code_sec {
    Some(CodeSec([_, TFunc(_, { instrs, .. })])) => {
      assert_true(instrs.length() >= 2)
      assert_eq(
        instrs[0],
        TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(42))),
      )
    }
    _ => fail("expected seeded callee entry")
  }
  match optimized.code_sec {
    Some(
      CodeSec(
        [
          TFunc(_, { instrs: [{ kind: TInstrKind::TCall(_, args), .. }], .. }),
          _,
        ]
      )
    ) => assert_eq(args.length(), 0)
    _ => fail("expected rewritten caller args")
  }
}

///|
test "dead argument elimination removes dropped return values from signatures" {
  // f0() -> none: drop(call f1()) ; return
  // f1() -> i32: return i32.const 7
  let caller = Func::t_func(
    [],
    TExpr::new([
      TInstr::drop(TInstr::call(FuncIdx::new(1), [])),
      TInstr::return_([]),
    ]),
  )
  let callee = Func::t_func(
    [],
    TExpr::new([TInstr::return_([TInstr::i32_const(I32(7))])]),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        make_func_type([], [ValType::i32()]),
        make_func_type([], []),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1), TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([caller, callee]))
  let optimized = run_dead_argument_elim(mod)
  match optimized.code_sec {
    Some(
      CodeSec(
        [TFunc(_, { instrs: instrs0, .. }), TFunc(_, { instrs: instrs1, .. })]
      )
    ) => {
      assert_true(instrs0[0].kind is TInstrKind::TCall(_, []))
      assert_eq(instrs1[0], TInstr::return_([]))
    }
    _ => fail("expected rewritten drop/callee return")
  }
  match optimized.func_sec {
    Some(FuncSec(type_idxs)) =>
      // callee got a fresh () -> () type.
      assert_eq(type_idxs[1], TypeIdx::new(2))
    None => fail("expected func section")
  }
}

///|
test "dead argument elimination handles exported callee via adapter thunk" {
  // f0 directly calls exported f1(i32) where the parameter is unused.
  let caller = Func::t_func(
    [],
    TExpr::new([TInstr::call(FuncIdx::new(1), [TInstr::i32_const(I32(9))])]),
  )
  let exported_callee = Func::t_func(
    [],
    TExpr::new([TInstr::i32_const(I32(7))]),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        make_func_type([ValType::i32()], [ValType::i32()]),
        make_func_type([], [ValType::i32()]),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1), TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([caller, exported_callee]))
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("f1"), ExternIdx::func(FuncIdx::new(1))),
      ]),
    )
  let optimized = run_dead_argument_elim(mod)
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, { instrs: instrs0, .. }), _, _])) => {
      let mut found = false
      for instr in instrs0 {
        match instr.kind {
          TInstrKind::TCall(FuncIdx(2), args) => {
            found = true
            assert_eq(args.length(), 0)
          }
          _ => ()
        }
      }
      assert_true(found)
    }
    _ => fail("expected clone for exported function")
  }
}

///|
test "dead argument elimination handles table-reachable callee via adapter thunk" {
  // f1 appears in table elems, so it is unseen/indirectly reachable.
  let caller = Func::t_func(
    [],
    TExpr::new([TInstr::call(FuncIdx::new(1), [TInstr::i32_const(I32(9))])]),
  )
  let table_callee = Func::t_func([], TExpr::new([TInstr::i32_const(I32(7))]))
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        make_func_type([ValType::i32()], [ValType::i32()]),
        make_func_type([], [ValType::i32()]),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1), TypeIdx::new(0)]))
    .with_table_sec(
      TableSec::new([
        Table::new(
          TableType::new(
            RefType::new(true, HeapType::abs(AbsHeapType::func())),
            Limits::i32(1, Some(1)),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      ElemSec::new([
        Elem::new(
          ElemMode::active(
            table_idx(0),
            Expr::new([Instruction::i32_const(I32(0))]),
          ),
          ElemKind::funcs([func_idx(1)]),
        ),
      ]),
    )
    .with_code_sec(CodeSec::new([caller, table_callee]))
  let optimized = run_dead_argument_elim(mod)
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, { instrs: instrs0, .. }), _, _])) => {
      let mut found = false
      for instr in instrs0 {
        match instr.kind {
          TInstrKind::TCall(FuncIdx(2), args) => {
            found = true
            assert_eq(args.length(), 0)
          }
          _ => ()
        }
      }
      assert_true(found)
    }
    _ => fail("expected clone for table-reachable function")
  }
}

///|
test "dead argument elimination refines parameter reference types" {
  // f0((ref func)) -> i32: call f1(local.get 0)
  // f1((ref null func)) -> i32, and uses the param
  let caller = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(1), [TInstr::local_get(LocalIdx::new(0))]),
    ]),
  )
  let callee = Func::t_func(
    [],
    TExpr::new([
      TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
      TInstr::i32_const(I32(7)),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        make_func_type(
          [
            ValType::ref_type(
              RefType::new(false, HeapType::abs(AbsHeapType::func())),
            ),
          ],
          [ValType::i32()],
        ),
        make_func_type(
          [
            ValType::ref_type(
              RefType::new(true, HeapType::abs(AbsHeapType::func())),
            ),
          ],
          [ValType::i32()],
        ),
        make_func_type([], [ValType::i32()]),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(CodeSec::new([caller, callee]))
  let optimized = run_dead_argument_elim(mod)
  let all_types = collect_func_types(optimized)
  let FuncType(params, _) = all_types[1]
  assert_eq(
    params[0],
    ValType::ref_type(RefType::new(false, HeapType::abs(AbsHeapType::func()))),
  )
}

///|
test "dead argument elimination refines return reference types" {
  // f0((ref func)) -> (ref null func): call f1(local.get 0)
  // f1((ref func)) -> (ref null func): returns local.get 0, so result can refine to non-null.
  let caller = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(1), [TInstr::local_get(LocalIdx::new(0))]),
    ]),
  )
  let callee = Func::t_func(
    [],
    TExpr::new([TInstr::return_([TInstr::local_get(LocalIdx::new(0))])]),
  )
  let non_null_funcref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::func())),
  )
  let nullable_funcref = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        make_func_type([non_null_funcref], [nullable_funcref]),
        make_func_type([non_null_funcref], [nullable_funcref]),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(CodeSec::new([caller, callee]))
  let optimized = run_dead_argument_elim(mod)
  let all_types = collect_func_types(optimized)
  let FuncType(_, callee_results) = all_types[1]
  assert_eq(
    callee_results[0],
    ValType::ref_type(RefType::new(false, HeapType::abs(AbsHeapType::func()))),
  )
}

///|
test "dead argument elimination iterates to convergence through call chains" {
  let caller = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(1), [TInstr::global_get(GlobalIdx::new(0))]),
    ]),
  )
  let middle = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(2), [TInstr::local_get(LocalIdx::new(0))]),
    ]),
  )
  let callee = Func::t_func([], TExpr::new([TInstr::i32_const(I32(7))]))
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        make_func_type([ValType::i32()], [ValType::i32()]),
        make_func_type([ValType::i32()], [ValType::i32()]),
        make_func_type([], [ValType::i32()]),
      ]),
    )
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(1), TypeIdx::new(0)]),
    )
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::i32(), false),
          TExpr::new([TInstr::i32_const(I32(9))]).to_expr(),
        ),
      ]),
    )
    .with_code_sec(CodeSec::new([caller, middle, callee]))
  let optimized = run_dead_argument_elim(mod)
  match optimized.code_sec {
    Some(
      CodeSec(
        [
          TFunc(_, { instrs: caller_instrs, .. }),
          TFunc(_, { instrs: middle_instrs, .. }),
          _,
        ]
      )
    ) => {
      let mut saw_caller_call = false
      for instr in caller_instrs {
        match instr.kind {
          TInstrKind::TCall(_, args) => {
            saw_caller_call = true
            assert_eq(args.length(), 0)
          }
          _ => ()
        }
      }
      let mut saw_middle_call = false
      for instr in middle_instrs {
        match instr.kind {
          TInstrKind::TCall(_, args) => {
            saw_middle_call = true
            assert_eq(args.length(), 0)
          }
          _ => ()
        }
      }
      assert_true(saw_caller_call)
      assert_true(saw_middle_call)
    }
    _ => fail("expected both call sites to be rewritten after convergence")
  }
}

///|
test "dead argument elimination removes params from tail-called callees" {
  let caller = Func::t_func(
    [],
    TExpr::new([
      TInstr::return_call(FuncIdx::new(1), [TInstr::i32_const(I32(9))]),
    ]),
  )
  let callee = Func::t_func([], TExpr::new([TInstr::i32_const(I32(7))]))
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        make_func_type([], [ValType::i32()]),
        make_func_type([ValType::i32()], [ValType::i32()]),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(CodeSec::new([caller, callee]))
  let optimized = run_dead_argument_elim(mod)
  match optimized.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            { instrs: [{ kind: TInstrKind::TReturnCall(_, args), .. }], .. }
          ),
          _,
        ]
      )
    ) => assert_eq(args.length(), 0)
    _ => fail("expected return_call arguments to be pruned")
  }
}

///|
test "dead argument elimination removes dropped implicit return values" {
  let caller = Func::t_func(
    [],
    TExpr::new([
      TInstr::drop(TInstr::call(FuncIdx::new(1), [])),
      TInstr::return_([]),
    ]),
  )
  let callee = Func::t_func([], TExpr::new([TInstr::i32_const(I32(7))]))
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        make_func_type([], []),
        make_func_type([], [ValType::i32()]),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(CodeSec::new([caller, callee]))
  let optimized = run_dead_argument_elim(mod)
  match optimized.code_sec {
    Some(
      CodeSec(
        [
          TFunc(_, { instrs: caller_instrs, .. }),
          TFunc(_, { instrs: callee_instrs, .. }),
        ]
      )
    ) => {
      assert_true(caller_instrs[0].kind is TInstrKind::TCall(_, []))
      assert_eq(callee_instrs.length(), 1)
      assert_eq(callee_instrs[0], TInstr::drop(TInstr::i32_const(I32(7))))
    }
    _ => fail("expected implicit result to be dropped in callee body")
  }
}

///|
test "dead argument elimination skips rewrite walk for unaffected large functions" {
  let huge_instrs : Array[TInstr] = []
  for i = 0; i < 256; i = i + 1 {
    huge_instrs.push(TInstr::drop(TInstr::i32_const(I32(7))))
  }
  let huge = Func::t_func([], TExpr::new(huge_instrs))
  let caller = Func::t_func(
    [],
    TExpr::new([TInstr::call(FuncIdx::new(2), [TInstr::i32_const(I32(9))])]),
  )
  let callee = Func::t_func([], TExpr::new([TInstr::i32_const(I32(7))]))
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        make_func_type([], []),
        make_func_type([ValType::i32()], [ValType::i32()]),
        make_func_type([], [ValType::i32()]),
      ]),
    )
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(2), TypeIdx::new(1)]),
    )
    .with_code_sec(CodeSec::new([huge, caller, callee]))
  let result = run_dead_argument_elim_once(
    mod, dead_argument_elim_trace_noop, 0, false,
  )
  assert_true(result.changed)
  assert_true(result.stats.rewrite_instrs_visited < 32)
}

///|
test "dead argument elimination skips detailed timers when trace is disabled" {
  let caller = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(1), [TInstr::local_get(LocalIdx::new(0))]),
    ]),
  )
  let callee = Func::t_func(
    [],
    TExpr::new([
      TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
      TInstr::i32_const(I32(7)),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        make_func_type(
          [
            ValType::ref_type(
              RefType::new(false, HeapType::abs(AbsHeapType::func())),
            ),
          ],
          [ValType::i32()],
        ),
        make_func_type(
          [
            ValType::ref_type(
              RefType::new(true, HeapType::abs(AbsHeapType::func())),
            ),
          ],
          [ValType::i32()],
        ),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(CodeSec::new([caller, callee]))
  let result = run_dead_argument_elim_once(
    mod, dead_argument_elim_trace_noop, 0, false,
  )
  assert_true(result.stats.known_type_calls_total > 0)
  assert_true(result.stats.match_calls_total > 0)
  assert_eq(result.stats.known_type_elapsed_us, 0UL)
  assert_eq(result.stats.match_elapsed_us, 0UL)
  assert_eq(result.stats.common_supertype_elapsed_us, 0UL)
}
