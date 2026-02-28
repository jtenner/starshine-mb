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
let dfe_hash_seed = 1469598103934665603UL

///|
let dfe_hash_prime = 1099511628211UL

///|
let dfe_invalid_type_fp = 7809847782465536322UL

///|
priv struct DFEIterationTraceStats {
  quick_bucket_count : Int
  candidate_bucket_count : Int
  candidate_defs : Int
  max_candidate_bucket : Int
  fp_bucket_count : Int
  fp_collision_defs : Int
  deep_compare_count : Int
  deep_compare_matches : Int
  removed_defs : Int
  summaries_us : UInt64
  body_hash_us : UInt64
  bucket_insert_us : UInt64
  compare_us : UInt64
}

///|
priv struct DFERemapTraceStats {
  elapsed_us : UInt64
  visits : Int
  changes : Int
}

///|
priv struct DFEFinalizeTraceStats {
  active_defs : Int
  removed_defs : Int
  rebuild_us : UInt64
  remap_us : UInt64
  remap_visits : Int
  remap_changes : Int
}

///|
priv struct DFEQuickKey {
  type_fp : UInt64
  local_count : Int
  top_level_instr_count : Int
  local_types_fp : UInt64
  first_instr_fp : UInt64
  last_instr_fp : UInt64
} derive(Eq, Hash)

///|
priv struct DFEFuncSummary {
  quick_key : DFEQuickKey
  full_fp : UInt64
}

///|
fn dfe_hash_mix(seed : UInt64, value : UInt64) -> UInt64 {
  (seed ^ value) * dfe_hash_prime
}

///|
fn dfe_hash_int(value : Int) -> UInt64 {
  value.reinterpret_as_uint().to_uint64()
}

///|
fn dfe_hash_hash_result(value : Int) -> UInt64 {
  value.reinterpret_as_uint().to_uint64()
}

///|
fn dfe_hash_valtypes(types : Array[ValType]) -> UInt64 {
  let mut hash = dfe_hash_mix(dfe_hash_seed, dfe_hash_int(types.length()))
  for type_ in types {
    hash = dfe_hash_mix(hash, dfe_hash_hash_result(type_.hash()))
  }
  hash
}

///|
fn dfe_trace_noop(_ : String) -> Unit {
  ()
}

///|
fn dfe_trace_delta_us_to_ms(delta_us : UInt64) -> UInt64 {
  delta_us / 1000UL
}

///|
#cfg(target="native")
#borrow(tv)
extern "c" fn dfe_native_gettimeofday(tv : Bytes, tz : UInt64) -> Int = "gettimeofday"

///|
#cfg(target="native")
fn dfe_trace_read_u64_le(bytes : Bytes, start : Int) -> UInt64 {
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
fn dfe_trace_now_us() -> UInt64 {
  let tv = Bytes::new(16)
  if dfe_native_gettimeofday(tv, 0UL) != 0 {
    return @env.now() * 1000UL
  }
  let sec = dfe_trace_read_u64_le(tv, 0)
  let usec = dfe_trace_read_u64_le(tv, 8)
  sec * 1000000UL + usec
}

///|
#cfg(target="wasm-gc")
fn dfe_trace_now_us() -> UInt64 {
  @env.now() * 1000UL
}

///|
#cfg(target="wasm")
fn dfe_trace_now_us() -> UInt64 {
  @env.now() * 1000UL
}

///|
#cfg(target="js")
fn dfe_trace_now_us() -> UInt64 {
  @env.now() * 1000UL
}

///|
#cfg(target="llvm")
fn dfe_trace_now_us() -> UInt64 {
  @env.now() * 1000UL
}

///|
fn dfe_trace_elapsed_us_since(start_us : UInt64) -> UInt64 {
  let end_us = dfe_trace_now_us()
  if end_us >= start_us {
    end_us - start_us
  } else {
    0UL
  }
}

///|
fn dfe_imported_func_count(mod : Module) -> Int {
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
fn dfe_extract_comp_type(sub_type : SubType) -> CompType {
  match sub_type {
    SubType(_, _, comp) => comp
    CompTypeSubType(comp) => comp
  }
}

///|
fn dfe_collect_comp_types(mod : Module) -> Array[CompType] {
  let comp_types : Array[CompType] = []
  match mod.type_sec {
    Some(TypeSec(rec_types)) =>
      for rec_type in rec_types {
        match rec_type {
          SingleRecType(sub_type) =>
            comp_types.push(dfe_extract_comp_type(sub_type))
          GroupRecType(sub_types) =>
            for sub_type in sub_types {
              comp_types.push(dfe_extract_comp_type(sub_type))
            }
        }
      }
    None => ()
  }
  comp_types
}

///|
fn dfe_resolve_comp_type(
  comp_types : Array[CompType],
  idx : TypeIdx,
) -> CompType? {
  let raw = match idx {
    TypeIdx(n) => n
    RecIdx(n) => n
  }
  let comp_type_count = comp_types.length().reinterpret_as_uint()
  if raw >= comp_type_count {
    None
  } else {
    Some(comp_types[raw.reinterpret_as_int()])
  }
}

///|
fn dfe_collect_comp_type_fps(comp_types : Array[CompType]) -> Array[UInt64] {
  let out : Array[UInt64] = []
  for comp_type in comp_types {
    out.push(dfe_hash_hash_result(comp_type.hash()))
  }
  out
}

///|
fn dfe_type_fp(comp_type_fps : Array[UInt64], idx : TypeIdx) -> UInt64 {
  let raw = match idx {
    TypeIdx(n) => n
    RecIdx(n) => n
  }
  let comp_type_count = comp_type_fps.length().reinterpret_as_uint()
  if raw >= comp_type_count {
    dfe_invalid_type_fp
  } else {
    comp_type_fps[raw.reinterpret_as_int()]
  }
}

///|
fn dfe_empty_iteration_trace_stats() -> DFEIterationTraceStats {
  {
    quick_bucket_count: 0,
    candidate_bucket_count: 0,
    candidate_defs: 0,
    max_candidate_bucket: 0,
    fp_bucket_count: 0,
    fp_collision_defs: 0,
    deep_compare_count: 0,
    deep_compare_matches: 0,
    removed_defs: 0,
    summaries_us: 0UL,
    body_hash_us: 0UL,
    bucket_insert_us: 0UL,
    compare_us: 0UL,
  }
}

///|
fn dfe_same_func_type(
  comp_types : Array[CompType],
  left : TypeIdx,
  right : TypeIdx,
) -> Bool {
  match
    (
      dfe_resolve_comp_type(comp_types, left),
      dfe_resolve_comp_type(comp_types, right),
    ) {
    (Some(left_comp_type), Some(right_comp_type)) =>
      left_comp_type == right_comp_type
    (None, None) => true
    _ => false
  }
}

///|
fn dfe_limit_for_options(
  defined_func_count : Int,
  options : OptimizeOptions,
) -> Int {
  if options.optimize_level >= 3 || options.shrink_level >= 1 {
    // Duplicate chains can require multiple rounds, but an uncapped limit is
    // too costly on very large modules.
    if defined_func_count > 64 {
      64
    } else {
      defined_func_count
    }
  } else if options.optimize_level >= 2 {
    10
  } else {
    1
  }
}

///|
fn dfe_should_early_stop(
  active_defined_count : Int,
  removed_defs : Int,
  options : OptimizeOptions,
) -> Bool {
  if removed_defs <= 0 {
    return false
  }
  if active_defined_count < 4096 {
    return false
  }
  if options.optimize_level < 3 && options.shrink_level < 1 {
    return false
  }
  if removed_defs < 32 {
    return true
  }
  removed_defs * 1000 < active_defined_count
}

///|
fn dfe_func_idx_from_abs(abs_idx : Int) -> FuncIdx {
  func_idx(abs_idx.reinterpret_as_uint())
}

///|
fn dfe_identity_abs_map(total_funcs : Int) -> Array[Int] {
  let out : Array[Int] = []
  for i = 0; i < total_funcs; i = i + 1 {
    out.push(i)
  }
  out
}

///|
fn dfe_resolve_canonical_abs(
  canonical_abs_of_abs : Array[Int],
  abs_idx : Int,
) -> Int {
  if abs_idx < 0 || abs_idx >= canonical_abs_of_abs.length() {
    return abs_idx
  }
  let mut root = abs_idx
  while true {
    let parent = canonical_abs_of_abs[root]
    if parent == root {
      break
    }
    root = parent
  }
  let mut curr = abs_idx
  while true {
    let parent = canonical_abs_of_abs[curr]
    canonical_abs_of_abs[curr] = root
    if parent == curr || parent == root {
      break
    }
    curr = parent
  }
  root
}

///|
fn dfe_count_active_defined_funcs(
  canonical_abs_of_abs : Array[Int],
  imported_func_count : Int,
  defined_func_count : Int,
) -> Int {
  let mut n = 0
  for def_idx = 0; def_idx < defined_func_count; def_idx = def_idx + 1 {
    let abs_idx = imported_func_count + def_idx
    if dfe_resolve_canonical_abs(canonical_abs_of_abs, abs_idx) == abs_idx {
      n += 1
    }
  }
  n
}

///|
fn dfe_canonical_func_idx_abs(
  canonical_abs_of_abs : Array[Int],
  idx : FuncIdx,
) -> Int {
  let FuncIdx(raw) = idx
  let abs_idx = raw.reinterpret_as_int()
  dfe_resolve_canonical_abs(canonical_abs_of_abs, abs_idx)
}

///|
fn dfe_instr_shallow_hash_under_map(
  canonical_abs_of_abs : Array[Int],
  instr : TInstr,
) -> UInt64 {
  match instr.kind {
    TInstrKind::TRefFunc(idx) =>
      dfe_hash_mix(
        oi_instr_shallow_tag_hash(instr),
        dfe_hash_int(dfe_canonical_func_idx_abs(canonical_abs_of_abs, idx)),
      )
    TInstrKind::TCall(func_idx, args)
    | TInstrKind::TReturnCall(func_idx, args) => {
      let mut digest = oi_instr_shallow_tag_hash(instr)
      digest = dfe_hash_mix(
        digest,
        dfe_hash_int(dfe_canonical_func_idx_abs(canonical_abs_of_abs, func_idx)),
      )
      dfe_hash_mix(digest, args.length().to_uint64())
    }
    _ => oi_instr_shallow_hash(instr)
  }
}

///|
fn dfe_hash_tinstr_under_map(
  canonical_abs_of_abs : Array[Int],
  instr : TInstr,
) -> UInt64 {
  let mut digest = dfe_instr_shallow_hash_under_map(canonical_abs_of_abs, instr)
  match instr.kind {
    TInstrKind::TBlock(_, body) | TInstrKind::TLoop(_, body) =>
      digest = dfe_hash_mix(
        digest,
        dfe_hash_texpr_under_map(canonical_abs_of_abs, body),
      )
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      digest = dfe_hash_mix(
        digest,
        dfe_hash_tinstr_under_map(canonical_abs_of_abs, cond),
      )
      digest = dfe_hash_mix(
        digest,
        dfe_hash_texpr_under_map(canonical_abs_of_abs, then_body),
      )
      match else_body {
        Some(body) =>
          digest = dfe_hash_mix(
            digest,
            dfe_hash_texpr_under_map(canonical_abs_of_abs, body),
          )
        None => ()
      }
    }
    TInstrKind::TTryTable(_, _, body) =>
      digest = dfe_hash_mix(
        digest,
        dfe_hash_texpr_under_map(canonical_abs_of_abs, body),
      )
    _ =>
      oi_for_each_non_control_child(instr, fn(child) {
        digest = dfe_hash_mix(
          digest,
          dfe_hash_tinstr_under_map(canonical_abs_of_abs, child),
        )
      })
  }
  digest
}

///|
fn dfe_hash_texpr_under_map(
  canonical_abs_of_abs : Array[Int],
  expr : TExpr,
) -> UInt64 {
  let mut digest = dfe_hash_mix(
    dfe_hash_seed,
    dfe_hash_int(expr.instrs.length()),
  )
  for instr in expr.instrs {
    digest = dfe_hash_mix(
      digest,
      dfe_hash_tinstr_under_map(canonical_abs_of_abs, instr),
    )
  }
  digest
}

///|
fn dfe_hash_func_under_map(
  canonical_abs_of_abs : Array[Int],
  type_fp : UInt64,
  func : Func,
) -> DFEFuncSummary {
  match func {
    TFunc(locals, body) => {
      let instrs = body.instrs
      let top_level_instr_count = instrs.length()
      let local_types_fp = dfe_hash_valtypes(locals)
      let first_instr_fp = if instrs.is_empty() {
        0UL
      } else {
        dfe_instr_shallow_hash_under_map(canonical_abs_of_abs, instrs[0])
      }
      let last_instr_fp = if instrs.is_empty() {
        0UL
      } else {
        dfe_instr_shallow_hash_under_map(
          canonical_abs_of_abs,
          instrs[top_level_instr_count - 1],
        )
      }
      let mut body_fp = dfe_hash_mix(
        local_types_fp,
        dfe_hash_int(locals.length()),
      )
      body_fp = dfe_hash_mix(body_fp, dfe_hash_int(top_level_instr_count))
      body_fp = dfe_hash_mix(
        body_fp,
        dfe_hash_texpr_under_map(canonical_abs_of_abs, body),
      )
      {
        quick_key: {
          type_fp,
          local_count: locals.length(),
          top_level_instr_count,
          local_types_fp,
          first_instr_fp,
          last_instr_fp,
        },
        full_fp: dfe_hash_mix(type_fp, body_fp),
      }
    }
    _ => {
      let body_fp = dfe_hash_mix(
        dfe_hash_seed,
        dfe_hash_hash_result(func.hash()),
      )
      {
        quick_key: {
          type_fp,
          local_count: -1,
          top_level_instr_count: -1,
          local_types_fp: 0UL,
          first_instr_fp: 0UL,
          last_instr_fp: 0UL,
        },
        full_fp: dfe_hash_mix(type_fp, body_fp),
      }
    }
  }
}

///|
fn dfe_dummy_children(n : Int) -> Array[TInstr] {
  let out : Array[TInstr] = []
  while out.length() < n {
    out.push(TInstr::nop())
  }
  out
}

///|
fn dfe_non_control_shallow_equal_under_map(
  canonical_abs_of_abs : Array[Int],
  left : TInstr,
  right : TInstr,
) -> Bool {
  match (left.kind, right.kind) {
    (TInstrKind::TRefFunc(left_idx), TInstrKind::TRefFunc(right_idx)) =>
      dfe_canonical_func_idx_abs(canonical_abs_of_abs, left_idx) ==
      dfe_canonical_func_idx_abs(canonical_abs_of_abs, right_idx)
    (
      TInstrKind::TCall(left_idx, left_args),
      TInstrKind::TCall(right_idx, right_args),
    )
    | (
      TInstrKind::TReturnCall(left_idx, left_args),
      TInstrKind::TReturnCall(right_idx, right_args),
    ) =>
      dfe_canonical_func_idx_abs(canonical_abs_of_abs, left_idx) ==
      dfe_canonical_func_idx_abs(canonical_abs_of_abs, right_idx) &&
      left_args.length() == right_args.length()
    _ => {
      let left_children = eval_children(left)
      let right_children = eval_children(right)
      if left_children.length() != right_children.length() {
        return false
      }
      let dummy = dfe_dummy_children(left_children.length())
      oi_rebuild_non_control(left, dummy) ==
      oi_rebuild_non_control(right, dummy)
    }
  }
}

///|
fn dfe_tinstr_equal_under_map(
  canonical_abs_of_abs : Array[Int],
  left : TInstr,
  right : TInstr,
) -> Bool {
  match (left.kind, right.kind) {
    (
      TInstrKind::TBlock(left_bt, left_body),
      TInstrKind::TBlock(right_bt, right_body),
    )
    | (
      TInstrKind::TLoop(left_bt, left_body),
      TInstrKind::TLoop(right_bt, right_body),
    ) =>
      left_bt == right_bt &&
      dfe_texpr_equal_under_map(canonical_abs_of_abs, left_body, right_body)
    (
      TInstrKind::TIf(left_bt, left_cond, left_then, left_else),
      TInstrKind::TIf(right_bt, right_cond, right_then, right_else),
    ) =>
      left_bt == right_bt &&
      dfe_tinstr_equal_under_map(canonical_abs_of_abs, left_cond, right_cond) &&
      dfe_texpr_equal_under_map(canonical_abs_of_abs, left_then, right_then) &&
      (match (left_else, right_else) {
        (Some(left_body), Some(right_body)) =>
          dfe_texpr_equal_under_map(canonical_abs_of_abs, left_body, right_body)
        (None, None) => true
        _ => false
      })
    (
      TInstrKind::TTryTable(left_bt, left_catches, left_body),
      TInstrKind::TTryTable(right_bt, right_catches, right_body),
    ) =>
      left_bt == right_bt &&
      left_catches == right_catches &&
      dfe_texpr_equal_under_map(canonical_abs_of_abs, left_body, right_body)
    _ => {
      if !dfe_non_control_shallow_equal_under_map(
          canonical_abs_of_abs, left, right,
        ) {
        return false
      }
      let left_children = eval_children(left)
      let right_children = eval_children(right)
      if left_children.length() != right_children.length() {
        return false
      }
      for i = 0; i < left_children.length(); i = i + 1 {
        if !dfe_tinstr_equal_under_map(
            canonical_abs_of_abs,
            left_children[i],
            right_children[i],
          ) {
          return false
        }
      }
      true
    }
  }
}

///|
fn dfe_texpr_equal_under_map(
  canonical_abs_of_abs : Array[Int],
  left : TExpr,
  right : TExpr,
) -> Bool {
  if left.instrs.length() != right.instrs.length() {
    return false
  }
  for i = 0; i < left.instrs.length(); i = i + 1 {
    if !dfe_tinstr_equal_under_map(
        canonical_abs_of_abs,
        left.instrs[i],
        right.instrs[i],
      ) {
      return false
    }
  }
  true
}

///|
fn dfe_func_equal_under_map(
  canonical_abs_of_abs : Array[Int],
  left : Func,
  right : Func,
) -> Bool {
  match (left, right) {
    (TFunc(left_locals, left_body), TFunc(right_locals, right_body)) =>
      left_locals == right_locals &&
      dfe_texpr_equal_under_map(canonical_abs_of_abs, left_body, right_body)
    _ => left == right
  }
}

///|
fn dfe_remap_func_indices(
  mod : Module,
  final_abs_map : Array[Int],
) -> Result[(Module, DFERemapTraceStats), String] {
  let final_abs_count = final_abs_map.length()
  let mut has_remap = false
  for old_abs = 0; old_abs < final_abs_count; old_abs = old_abs + 1 {
    if final_abs_map[old_abs] != old_abs {
      has_remap = true
      break
    }
  }
  if !has_remap {
    return Ok((mod, { elapsed_us: 0UL, visits: 0, changes: 0 }))
  }
  let final_abs_count_u = final_abs_count.reinterpret_as_uint()
  let visits = Ref::new(0)
  let changes = Ref::new(0)
  let remap_start_us = dfe_trace_now_us()
  let transformer = ModuleTransformer::new().on_funcidx_evt(fn(_, _, idx) {
    visits.val += 1
    let FuncIdx(raw) = idx
    if raw >= final_abs_count_u {
      return unchanged()
    }
    let abs_idx = raw.reinterpret_as_int()
    let new_abs = final_abs_map[abs_idx]
    if new_abs < 0 || new_abs == abs_idx {
      unchanged()
    } else {
      changes.val += 1
      change((), dfe_func_idx_from_abs(new_abs))
    }
  })
  match transformer.walk_module((), mod) {
    Ok(Some((_, new_mod))) =>
      Ok(
        (
          new_mod,
          {
            elapsed_us: dfe_trace_elapsed_us_since(remap_start_us),
            visits: visits.val,
            changes: changes.val,
          },
        ),
      )
    Ok(None) =>
      Ok(
        (
          mod,
          {
            elapsed_us: dfe_trace_elapsed_us_since(remap_start_us),
            visits: visits.val,
            changes: changes.val,
          },
        ),
      )
    Err(e) => Err(e)
  }
}

///|
fn dfe_run_iteration(
  imported_func_count : Int,
  comp_types : Array[CompType],
  comp_type_fps : Array[UInt64],
  type_idxs : Array[TypeIdx],
  funcs : Array[Func],
  canonical_abs_of_abs : Array[Int],
) -> Result[(Bool, DFEIterationTraceStats), String] {
  let empty_stats = dfe_empty_iteration_trace_stats()
  let func_count = funcs.length()
  let defs_by_quick_key : Map[DFEQuickKey, Ref[Array[Int]]] = Map::new()
  let full_fp_by_def : Array[UInt64] = []
  let summarize_start_us = dfe_trace_now_us()
  let mut body_hash_us = 0UL
  let mut bucket_insert_us = 0UL
  for def_idx = 0; def_idx < func_count; def_idx = def_idx + 1 {
    full_fp_by_def.push(0UL)
    let abs_idx = imported_func_count + def_idx
    if dfe_resolve_canonical_abs(canonical_abs_of_abs, abs_idx) != abs_idx {
      continue
    }
    let body_hash_start_us = dfe_trace_now_us()
    let summary = dfe_hash_func_under_map(
      canonical_abs_of_abs,
      dfe_type_fp(comp_type_fps, type_idxs[def_idx]),
      funcs[def_idx],
    )
    body_hash_us = body_hash_us + dfe_trace_elapsed_us_since(body_hash_start_us)
    full_fp_by_def[def_idx] = summary.full_fp
    let quick_key = summary.quick_key
    let bucket_insert_start_us = dfe_trace_now_us()
    match defs_by_quick_key.get(quick_key) {
      Some(existing) => existing.val.push(def_idx)
      None => defs_by_quick_key[quick_key] = Ref::new([def_idx])
    }
    bucket_insert_us = bucket_insert_us +
      dfe_trace_elapsed_us_since(bucket_insert_start_us)
  }
  let summaries_us = dfe_trace_elapsed_us_since(summarize_start_us)
  let mut any_replacement = false
  let mut quick_bucket_count = 0
  let mut candidate_bucket_count = 0
  let mut candidate_defs = 0
  let mut max_candidate_bucket = 0
  let mut fp_bucket_count = 0
  let mut fp_collision_defs = 0
  let mut deep_compare_count = 0
  let mut deep_compare_matches = 0
  let replacements_abs : Array[Int] = []
  let canonical_replacements_abs : Array[Int] = []
  let compare_start_us = dfe_trace_now_us()
  for entry in defs_by_quick_key {
    quick_bucket_count += 1
    let (_, candidate_defs_ref) = entry
    let candidate_def_idxs = candidate_defs_ref.val
    let bucket_len = candidate_def_idxs.length()
    if bucket_len <= 1 {
      continue
    }
    candidate_bucket_count += 1
    candidate_defs += bucket_len
    if bucket_len > max_candidate_bucket {
      max_candidate_bucket = bucket_len
    }
    let canonical_by_fp : Map[UInt64, Ref[Array[Int]]] = Map::new()
    for def_idx in candidate_def_idxs {
      let full_fp = full_fp_by_def[def_idx]
      match canonical_by_fp.get(full_fp) {
        Some(bucket) => {
          fp_collision_defs += 1
          let mut matched = false
          for canonical_def_idx in bucket.val {
            deep_compare_count += 1
            if dfe_same_func_type(
                comp_types,
                type_idxs[canonical_def_idx],
                type_idxs[def_idx],
              ) &&
              dfe_func_equal_under_map(
                canonical_abs_of_abs,
                funcs[canonical_def_idx],
                funcs[def_idx],
              ) {
              deep_compare_matches += 1
              let old_abs = imported_func_count + def_idx
              let canonical_abs = imported_func_count + canonical_def_idx
              replacements_abs.push(old_abs)
              canonical_replacements_abs.push(canonical_abs)
              any_replacement = true
              matched = true
              break
            }
          }
          if !matched {
            bucket.val.push(def_idx)
          }
        }
        None => {
          fp_bucket_count += 1
          canonical_by_fp[full_fp] = Ref::new([def_idx])
        }
      }
    }
  }
  let compare_us = dfe_trace_elapsed_us_since(compare_start_us)
  if !any_replacement {
    return Ok(
      (
        false,
        {
          ..empty_stats,
          quick_bucket_count,
          candidate_bucket_count,
          candidate_defs,
          max_candidate_bucket,
          fp_bucket_count,
          fp_collision_defs,
          deep_compare_count,
          deep_compare_matches,
          summaries_us,
          body_hash_us,
          bucket_insert_us,
          compare_us,
        },
      ),
    )
  }
  for i = 0; i < replacements_abs.length(); i = i + 1 {
    let old_abs = replacements_abs[i]
    let canonical_abs = dfe_resolve_canonical_abs(
      canonical_abs_of_abs,
      canonical_replacements_abs[i],
    )
    canonical_abs_of_abs[old_abs] = canonical_abs
  }
  Ok(
    (
      true,
      {
        quick_bucket_count,
        candidate_bucket_count,
        candidate_defs,
        max_candidate_bucket,
        fp_bucket_count,
        fp_collision_defs,
        deep_compare_count,
        deep_compare_matches,
        removed_defs: replacements_abs.length(),
        summaries_us,
        body_hash_us,
        bucket_insert_us,
        compare_us,
      },
    ),
  )
}

///|
fn dfe_finalize_module(
  mod : Module,
  imported_func_count : Int,
  type_idxs : Array[TypeIdx],
  funcs : Array[Func],
  canonical_abs_of_abs : Array[Int],
) -> Result[(Module, DFEFinalizeTraceStats), String] {
  let func_count = funcs.length()
  let rebuild_start_us = dfe_trace_now_us()
  let total_funcs = imported_func_count + func_count
  let old_abs_to_new_abs = dfe_identity_abs_map(imported_func_count)
  let new_type_idxs : Array[TypeIdx] = []
  let new_funcs : Array[Func] = []
  let mut next_def_abs = imported_func_count
  for def_idx = 0; def_idx < func_count; def_idx = def_idx + 1 {
    let abs_idx = imported_func_count + def_idx
    if dfe_resolve_canonical_abs(canonical_abs_of_abs, abs_idx) == abs_idx {
      old_abs_to_new_abs.push(next_def_abs)
      new_type_idxs.push(type_idxs[def_idx])
      new_funcs.push(funcs[def_idx])
      next_def_abs += 1
    } else {
      old_abs_to_new_abs.push(-1)
    }
  }
  let final_abs_map : Array[Int] = []
  for old_abs = 0; old_abs < total_funcs; old_abs = old_abs + 1 {
    let canonical_abs = dfe_resolve_canonical_abs(canonical_abs_of_abs, old_abs)
    if canonical_abs < 0 || canonical_abs >= old_abs_to_new_abs.length() {
      return Err(
        "duplicate_function_elimination: invalid canonical function index",
      )
    }
    let canonical_new_abs = old_abs_to_new_abs[canonical_abs]
    if canonical_new_abs < 0 {
      return Err("duplicate_function_elimination: canonical function removed")
    }
    final_abs_map.push(canonical_new_abs)
  }
  let rebuild_us = dfe_trace_elapsed_us_since(rebuild_start_us)
  let new_mod = mod
    .with_func_sec(FuncSec::new(new_type_idxs))
    .with_code_sec(CodeSec::new(new_funcs))
  match dfe_remap_func_indices(new_mod, final_abs_map) {
    Ok((out, remap_stats)) =>
      Ok(
        (
          out,
          {
            active_defs: new_funcs.length(),
            removed_defs: func_count - new_funcs.length(),
            rebuild_us,
            remap_us: remap_stats.elapsed_us,
            remap_visits: remap_stats.visits,
            remap_changes: remap_stats.changes,
          },
        ),
      )
    Err(e) => Err(e)
  }
}

///|
fn duplicate_function_elimination(
  mod : Module,
  options : OptimizeOptions,
  trace? : (String) -> Unit = dfe_trace_noop,
) -> Result[Module, String] {
  let imported_func_count = dfe_imported_func_count(mod)
  let type_idxs = match mod.func_sec {
    Some(FuncSec(items)) => items
    None => return Ok(mod)
  }
  let funcs = match mod.code_sec {
    Some(CodeSec(items)) => items
    None => return Ok(mod)
  }
  if type_idxs.length() != funcs.length() {
    return Err(
      "duplicate_function_elimination: func_sec/code_sec length mismatch",
    )
  }
  let comp_types = dfe_collect_comp_types(mod)
  let comp_type_fps = dfe_collect_comp_type_fps(comp_types)
  let defined_func_count = funcs.length()
  let mut limit = dfe_limit_for_options(defined_func_count, options)
  let canonical_abs_of_abs = dfe_identity_abs_map(
    imported_func_count + defined_func_count,
  )
  trace(
    "start imported=\{imported_func_count} defined=\{defined_func_count} comp_types=\{comp_types.length()} limit=\{limit} opt=\{options.optimize_level} shrink=\{options.shrink_level}",
  )
  let pass_start_us = dfe_trace_now_us()
  let mut iteration = 0
  while limit > 0 {
    iteration += 1
    limit -= 1
    let iter_defined_count = dfe_count_active_defined_funcs(
      canonical_abs_of_abs, imported_func_count, defined_func_count,
    )
    trace(
      "iter[\{iteration}] start active_defined=\{iter_defined_count} remaining_limit=\{limit}",
    )
    let iteration_start_us = dfe_trace_now_us()
    match
      dfe_run_iteration(
        imported_func_count, comp_types, comp_type_fps, type_idxs, funcs, canonical_abs_of_abs,
      ) {
      Err(e) => {
        trace(
          "iter[\{iteration}] error elapsed_ms=\{dfe_trace_delta_us_to_ms(dfe_trace_elapsed_us_since(iteration_start_us))} \{e}",
        )
        return Err(e)
      }
      Ok((changed, stats)) => {
        let elapsed_us = dfe_trace_elapsed_us_since(iteration_start_us)
        let next_defined_count = iter_defined_count - stats.removed_defs
        trace(
          "iter[\{iteration}] done elapsed_ms=\{dfe_trace_delta_us_to_ms(elapsed_us)} elapsed_us=\{elapsed_us} changed=\{changed} removed=\{stats.removed_defs} active_defined=\{iter_defined_count}->\{next_defined_count} quick_buckets=\{stats.quick_bucket_count} candidate_buckets=\{stats.candidate_bucket_count} candidate_defs=\{stats.candidate_defs} max_bucket=\{stats.max_candidate_bucket} fp_buckets=\{stats.fp_bucket_count} fp_collisions=\{stats.fp_collision_defs} deep_compares=\{stats.deep_compare_count} deep_matches=\{stats.deep_compare_matches} summaries_us=\{stats.summaries_us} body_hash_us=\{stats.body_hash_us} bucket_insert_us=\{stats.bucket_insert_us} compare_us=\{stats.compare_us}",
        )
        if !changed {
          trace("stop:fixed_point iter=\{iteration}")
          break
        }
        if dfe_should_early_stop(
            iter_defined_count,
            stats.removed_defs,
            options,
          ) {
          trace(
            "stop:early_yield iter=\{iteration} removed=\{stats.removed_defs} active_defined=\{iter_defined_count}",
          )
          break
        }
      }
    }
  }
  let final_active_defs = dfe_count_active_defined_funcs(
    canonical_abs_of_abs, imported_func_count, defined_func_count,
  )
  trace(
    "finalize start active_defined=\{final_active_defs} removed=\{defined_func_count - final_active_defs}",
  )
  let (final_mod, finalize_stats) = match
    dfe_finalize_module(
      mod, imported_func_count, type_idxs, funcs, canonical_abs_of_abs,
    ) {
    Ok(out) => out
    Err(e) => return Err(e)
  }
  trace(
    "finalize done active_defined=\{finalize_stats.active_defs} removed=\{finalize_stats.removed_defs} rebuild_us=\{finalize_stats.rebuild_us} remap_us=\{finalize_stats.remap_us} remap_visits=\{finalize_stats.remap_visits} remap_changes=\{finalize_stats.remap_changes}",
  )
  trace(
    "done elapsed_ms=\{dfe_trace_delta_us_to_ms(dfe_trace_elapsed_us_since(pass_start_us))}",
  )
  Ok(final_mod)
}

///|
test "duplicate function elimination removes duplicate function bodies" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let root = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(1), []),
      TInstr::call(FuncIdx::new(2), []),
    ]),
  )
  let dup_a = Func::t_func([], TExpr::new([TInstr::nop()]))
  let dup_b = Func::t_func([], TExpr::new([TInstr::nop()]))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(0), TypeIdx::new(0)]),
    )
    .with_code_sec(CodeSec::new([root, dup_a, dup_b]))
  let optimized = match
    duplicate_function_elimination(mod, OptimizeOptions::new()) {
    Ok(m) => m
    Err(e) => fail("unexpected duplicate_function_elimination error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 2)
    None => fail("expected code section")
  }
  match optimized.func_sec {
    Some(FuncSec(type_idxs)) => assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, { instrs, .. }), _])) => {
      let mut seen = 0
      for instr in instrs {
        match instr.kind {
          TInstrKind::TCall(FuncIdx(raw), []) => {
            assert_eq(raw.reinterpret_as_int(), 1)
            seen += 1
          }
          _ => ()
        }
      }
      assert_eq(seen, 2)
    }
    _ => fail("expected remapped root function calls")
  }
}

///|
test "duplicate function elimination limit respects optimize level" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let a1 = Func::t_func([], TExpr::new([TInstr::call(FuncIdx::new(2), [])]))
  let a2 = Func::t_func([], TExpr::new([TInstr::call(FuncIdx::new(3), [])]))
  let b1 = Func::t_func([], TExpr::new([TInstr::nop()]))
  let b2 = Func::t_func([], TExpr::new([TInstr::nop()]))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(
      FuncSec::new([
        TypeIdx::new(0),
        TypeIdx::new(0),
        TypeIdx::new(0),
        TypeIdx::new(0),
      ]),
    )
    .with_code_sec(CodeSec::new([a1, a2, b1, b2]))
  let low = OptimizeOptions::new(optimize_level=0, shrink_level=0)
  let low_optimized = match duplicate_function_elimination(mod, low) {
    Ok(m) => m
    Err(e) => fail("unexpected duplicate_function_elimination error: \{e}")
  }
  match low_optimized.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 3)
    None => fail("expected code section")
  }
  let high = OptimizeOptions::new(optimize_level=2, shrink_level=0)
  let high_optimized = match duplicate_function_elimination(mod, high) {
    Ok(m) => m
    Err(e) => fail("unexpected duplicate_function_elimination error: \{e}")
  }
  match high_optimized.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 2)
    None => fail("expected code section")
  }
}

///|
test "duplicate function elimination uses shrink level for multi-iteration" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let a1 = Func::t_func([], TExpr::new([TInstr::call(FuncIdx::new(2), [])]))
  let a2 = Func::t_func([], TExpr::new([TInstr::call(FuncIdx::new(3), [])]))
  let b1 = Func::t_func([], TExpr::new([TInstr::nop()]))
  let b2 = Func::t_func([], TExpr::new([TInstr::nop()]))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(
      FuncSec::new([
        TypeIdx::new(0),
        TypeIdx::new(0),
        TypeIdx::new(0),
        TypeIdx::new(0),
      ]),
    )
    .with_code_sec(CodeSec::new([a1, a2, b1, b2]))
  let options = OptimizeOptions::new(optimize_level=0, shrink_level=1)
  let optimized = match duplicate_function_elimination(mod, options) {
    Ok(m) => m
    Err(e) => fail("unexpected duplicate_function_elimination error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 2)
    None => fail("expected code section")
  }
}

///|
test "duplicate function elimination does not merge equal bodies with different types" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let t_i32_void = single_rec_type(
    comp_type_sub_type(func_comp_type([ValType::i32()], [])),
  )
  let root = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(1), []),
      TInstr::call(FuncIdx::new(2), [TInstr::i32_const(I32(7))]),
    ]),
  )
  let f_void = Func::t_func([], TExpr::new([TInstr::nop()]))
  let f_i32_void = Func::t_func([], TExpr::new([TInstr::nop()]))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void, t_i32_void]))
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(0), TypeIdx::new(1)]),
    )
    .with_code_sec(CodeSec::new([root, f_void, f_i32_void]))
  let optimized = match
    duplicate_function_elimination(mod, OptimizeOptions::new()) {
    Ok(m) => m
    Err(e) => fail("unexpected duplicate_function_elimination error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 3)
    None => fail("expected code section")
  }
}

///|
test "duplicate function elimination merges duplicates across equivalent type defs" {
  let t0 = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let t1 = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let root = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(1), []),
      TInstr::call(FuncIdx::new(2), []),
    ]),
  )
  let dup_a = Func::t_func([], TExpr::new([TInstr::nop()]))
  let dup_b = Func::t_func([], TExpr::new([TInstr::nop()]))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t0, t1]))
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(0), TypeIdx::new(1)]),
    )
    .with_code_sec(CodeSec::new([root, dup_a, dup_b]))
  let optimized = match
    duplicate_function_elimination(mod, OptimizeOptions::new()) {
    Ok(m) => m
    Err(e) => fail("unexpected duplicate_function_elimination error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 2)
    None => fail("expected code section")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, { instrs, .. }), _])) => {
      let mut seen = 0
      for instr in instrs {
        match instr.kind {
          TInstrKind::TCall(FuncIdx(raw), []) => {
            assert_eq(raw.reinterpret_as_int(), 1)
            seen += 1
          }
          _ => ()
        }
      }
      assert_eq(seen, 2)
    }
    _ => fail("expected remapped root function calls")
  }
}

///|
test "duplicate function elimination remaps start export and ref.func uses" {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let root = Func::t_func(
    [],
    TExpr::new([
      TInstr::drop(TInstr::ref_func(FuncIdx::new(2))),
      TInstr::call(FuncIdx::new(2), []),
    ]),
  )
  let dup_a = Func::t_func([], TExpr::new([TInstr::nop()]))
  let dup_b = Func::t_func([], TExpr::new([TInstr::nop()]))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([t_void]))
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0), TypeIdx::new(0), TypeIdx::new(0)]),
    )
    .with_code_sec(CodeSec::new([root, dup_a, dup_b]))
    .with_start_sec(StartSec::new(FuncIdx::new(2)))
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("f"), ExternIdx::func(FuncIdx::new(2))),
      ]),
    )
  let optimized = match
    duplicate_function_elimination(mod, OptimizeOptions::new()) {
    Ok(m) => m
    Err(e) => fail("unexpected duplicate_function_elimination error: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec(funcs)) => assert_eq(funcs.length(), 2)
    None => fail("expected code section")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, { instrs, .. }), _])) => {
      assert_eq(instrs.length(), 2)
      match instrs[0].kind {
        TInstrKind::TDrop({ kind: TInstrKind::TRefFunc(FuncIdx(i)), .. }) =>
          assert_eq(i, 1U)
        _ => fail("expected ref.func use to remap to canonical duplicate")
      }
      match instrs[1].kind {
        TInstrKind::TCall(FuncIdx(i), []) => assert_eq(i, 1U)
        _ => fail("expected call to remap to canonical duplicate")
      }
    }
    _ => fail("expected remapped root function")
  }
  match optimized.start_sec {
    Some(StartSec(FuncIdx(i))) => assert_eq(i, 1U)
    None => fail("expected start section")
  }
  match optimized.export_sec {
    Some(ExportSec([Export(_, FuncExternIdx(FuncIdx(i)))])) => assert_eq(i, 1U)
    _ => fail("expected exported function index to be remapped")
  }
}
