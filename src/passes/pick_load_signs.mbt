///|
pub fn pick_load_signs_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new(
    "pick-load-signs",
    requires=[@ir.HotAnalysis::use_def()],
    invalidates=[
      @ir.HotAnalysis::cfg(),
      @ir.HotAnalysis::dominance(),
      @ir.HotAnalysis::liveness(),
      @ir.HotAnalysis::use_def(),
      @ir.HotAnalysis::effects(),
      @ir.HotAnalysis::loop_info(),
      @ir.HotAnalysis::ssa(),
    ],
  )
}

///|
pub fn pick_load_signs_summary() -> String {
  "Pick narrower signed/unsigned load opcodes based on local use extension evidence."
}

///|
priv struct PLSUsage {
  mut signed_usages : Int
  mut signed_bits : Int
  mut unsigned_usages : Int
  mut unsigned_bits : Int
  mut total_usages : Int
  mut invalid : Bool
}

///|
fn PLSUsage::new() -> PLSUsage {
  {
    signed_usages: 0,
    signed_bits: 0,
    unsigned_usages: 0,
    unsigned_bits: 0,
    total_usages: 0,
    invalid: false,
  }
}

///|
priv struct PLSCandidateLoad {
  local_idx : Int
  set_node : Int
  load_id : Int
  load_addr_id : Int
  load_bits : Int
  load_is_i64 : Bool
  current_signed : Bool
  target_signed : Bool
}

///|
priv struct PLSShiftExtCacheEntry {
  computed : Bool
  has_result : Bool
  is_signed : Bool
  bits : Int
}

///|
priv struct PLSAnalysis {
  candidates : Array[PLSCandidateLoad]
  rewritable_candidates : Int
}

///|
fn pls_make_usage_by_local(num_locals : Int) -> Array[PLSUsage] {
  let usage_by_local : Array[PLSUsage] = []
  for _ in 0..<num_locals {
    usage_by_local.push(PLSUsage::new())
  }
  usage_by_local
}

///|
fn pls_record_signed_usage(
  usage_by_local : Array[PLSUsage],
  local_idx : Int,
  bits : Int,
) -> Unit {
  let usage = usage_by_local[local_idx]
  if usage.invalid {
    return
  }
  if usage.signed_usages == 0 {
    usage.signed_bits = bits
  } else if usage.signed_bits != bits {
    usage.invalid = true
    usage_by_local[local_idx] = usage
    return
  }
  usage.signed_usages += 1
  usage_by_local[local_idx] = usage
}

///|
fn pls_record_unsigned_usage(
  usage_by_local : Array[PLSUsage],
  local_idx : Int,
  bits : Int,
) -> Unit {
  let usage = usage_by_local[local_idx]
  if usage.invalid {
    return
  }
  if usage.unsigned_usages == 0 {
    usage.unsigned_bits = bits
  } else if usage.unsigned_bits != bits {
    usage.invalid = true
    usage_by_local[local_idx] = usage
    return
  }
  usage.unsigned_usages += 1
  usage_by_local[local_idx] = usage
}

///|
fn pls_load_info(instr : @lib.Instruction) -> (Bool, Int, Bool)? {
  match instr {
    @lib.Instruction::I32Load8S(_) => Some((true, 8, false))
    @lib.Instruction::I32Load8U(_) => Some((false, 8, false))
    @lib.Instruction::I32Load16S(_) => Some((true, 16, false))
    @lib.Instruction::I32Load16U(_) => Some((false, 16, false))
    @lib.Instruction::I64Load8S(_) => Some((true, 8, true))
    @lib.Instruction::I64Load8U(_) => Some((false, 8, true))
    @lib.Instruction::I64Load16S(_) => Some((true, 16, true))
    @lib.Instruction::I64Load16U(_) => Some((false, 16, true))
    @lib.Instruction::I64Load32S(_) => Some((true, 32, true))
    @lib.Instruction::I64Load32U(_) => Some((false, 32, true))
    _ => None
  }
}

///|
fn pls_load_with_signedness(
  instr : @lib.Instruction,
  signed : Bool,
) -> @lib.Instruction? {
  match instr {
    @lib.Instruction::I32Load8S(memarg) =>
      Some(
        if signed {
          @lib.Instruction::i32_load8s(memarg)
        } else {
          @lib.Instruction::i32_load8u(memarg)
        },
      )
    @lib.Instruction::I32Load8U(memarg) =>
      Some(
        if signed {
          @lib.Instruction::i32_load8s(memarg)
        } else {
          @lib.Instruction::i32_load8u(memarg)
        },
      )
    @lib.Instruction::I32Load16S(memarg) =>
      Some(
        if signed {
          @lib.Instruction::i32_load16s(memarg)
        } else {
          @lib.Instruction::i32_load16u(memarg)
        },
      )
    @lib.Instruction::I32Load16U(memarg) =>
      Some(
        if signed {
          @lib.Instruction::i32_load16s(memarg)
        } else {
          @lib.Instruction::i32_load16u(memarg)
        },
      )
    @lib.Instruction::I64Load8S(memarg) =>
      Some(
        if signed {
          @lib.Instruction::i64_load8s(memarg)
        } else {
          @lib.Instruction::i64_load8u(memarg)
        },
      )
    @lib.Instruction::I64Load8U(memarg) =>
      Some(
        if signed {
          @lib.Instruction::i64_load8s(memarg)
        } else {
          @lib.Instruction::i64_load8u(memarg)
        },
      )
    @lib.Instruction::I64Load16S(memarg) =>
      Some(
        if signed {
          @lib.Instruction::i64_load16s(memarg)
        } else {
          @lib.Instruction::i64_load16u(memarg)
        },
      )
    @lib.Instruction::I64Load16U(memarg) =>
      Some(
        if signed {
          @lib.Instruction::i64_load16s(memarg)
        } else {
          @lib.Instruction::i64_load16u(memarg)
        },
      )
    @lib.Instruction::I64Load32S(memarg) =>
      Some(
        if signed {
          @lib.Instruction::i64_load32s(memarg)
        } else {
          @lib.Instruction::i64_load32u(memarg)
        },
      )
    @lib.Instruction::I64Load32U(memarg) =>
      Some(
        if signed {
          @lib.Instruction::i64_load32s(memarg)
        } else {
          @lib.Instruction::i64_load32u(memarg)
        },
      )
    _ => None
  }
}

///|
fn pls_i32_const_node(func : @ir.HotFunc, node_id : Int) -> @lib.I32? {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Const =>
      match @ir.hot_const_get(func, node.imm0) {
        @ir.HotConstPayload::I32Const(value) => Some(value)
        _ => None
      }
    _ => None
  }
}

///|
fn pls_i64_const_node(func : @ir.HotFunc, node_id : Int) -> @lib.I64? {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Const =>
      match @ir.hot_const_get(func, node.imm0) {
        @ir.HotConstPayload::I64Const(value) => Some(value)
        _ => None
      }
    _ => None
  }
}

///|
fn pls_const_i32_eq(
  func : @ir.HotFunc,
  node_id : Int,
  expected : @lib.I32,
) -> Bool {
  match pls_i32_const_node(func, node_id) {
    Some(bits) => bits == expected
    None => false
  }
}

///|
fn pls_const_i64_eq(
  func : @ir.HotFunc,
  node_id : Int,
  expected : @lib.I64,
) -> Bool {
  match pls_i64_const_node(func, node_id) {
    Some(bits) => bits == expected
    None => false
  }
}

///|
fn pls_i32_low_mask_bits(mask : @lib.I32) -> Int? {
  let @lib.I32(value) = mask
  let mut bits = 0
  let mut value_u = value.reinterpret_as_uint()
  while bits < 32 && (value_u & 1U) == 1U {
    bits += 1
    value_u = value_u >> 1
  }
  if bits > 0 && value_u == 0U {
    Some(bits)
  } else {
    None
  }
}

///|
fn pls_i64_low_mask_bits(mask : @lib.I64) -> Int? {
  let @lib.I64(value) = mask
  let mut bits = 0
  let mut value_u = value.reinterpret_as_uint64()
  while bits < 64 && (value_u & 1UL) == 1UL {
    bits += 1
    value_u = value_u >> 1
  }
  if bits > 0 && value_u == 0UL {
    Some(bits)
  } else {
    None
  }
}

///|
fn pls_i32_shift_ext_bits(shift : @lib.I32) -> Int {
  let @lib.I32(value) = shift
  let effective = value.reinterpret_as_uint() & 31U
  32 - effective.reinterpret_as_int()
}

///|
fn pls_i64_shift_ext_bits(shift : @lib.I64) -> Int {
  let @lib.I64(value) = shift
  let effective = value.reinterpret_as_uint64() & 63UL
  64 - effective.to_int()
}

///|
fn pls_is_child_use_slot(kind : @ir.HotUseSlotKind) -> Bool {
  match kind {
    @ir.HotUseSlotKind::ChildUseSlot => true
    _ => false
  }
}

///|
fn pls_target_signedness(
  candidate : PLSCandidateLoad,
  usage : PLSUsage,
) -> Bool {
  if usage.invalid ||
    usage.total_usages == 0 ||
    usage.signed_usages + usage.unsigned_usages != usage.total_usages ||
    (usage.signed_usages != 0 && usage.signed_bits != candidate.load_bits) ||
    (usage.unsigned_usages != 0 && usage.unsigned_bits != candidate.load_bits) {
    candidate.current_signed
  } else if usage.signed_usages * 2 >= usage.unsigned_usages {
    true
  } else {
    false
  }
}

///|
fn pls_extension_from_grandparent_zero_ext(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  parent_id : Int,
  shift_bits : @lib.I32,
) -> (Bool, Int)? {
  for grand_site in @ir.node_use_sites_borrowed(use_def, parent_id) {
    if !pls_is_child_use_slot(grand_site.kind) || grand_site.slot != 0 {
      continue
    }
    let grand_id = grand_site.user
    let grand_instr = match @ir.hot_node_exact_instr(func, grand_id) {
      Some(i) => i
      None => continue
    }
    let grand_rhs = @ir.hot_child_get(func, grand_id, 1)
    if !pls_const_i32_eq(func, grand_rhs, shift_bits) {
      continue
    }
    match grand_instr {
      @lib.Instruction::I32ShrU(_) =>
        return Some((false, pls_i32_shift_ext_bits(shift_bits)))
      @lib.Instruction::I32ShrS(_) =>
        return Some((true, pls_i32_shift_ext_bits(shift_bits)))
      _ => ()
    }
  }
  None
}

///|
fn pls_extension_from_grandparent_zero_ext64(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  parent_id : Int,
  shift_bits : @lib.I64,
) -> (Bool, Int)? {
  for grand_site in @ir.node_use_sites_borrowed(use_def, parent_id) {
    if !pls_is_child_use_slot(grand_site.kind) || grand_site.slot != 0 {
      continue
    }
    let grand_id = grand_site.user
    let grand_instr = match @ir.hot_node_exact_instr(func, grand_id) {
      Some(i) => i
      None => continue
    }
    let grand_rhs = @ir.hot_child_get(func, grand_id, 1)
    if !pls_const_i64_eq(func, grand_rhs, shift_bits) {
      continue
    }
    match grand_instr {
      @lib.Instruction::I64ShrU(_) =>
        return Some((false, pls_i64_shift_ext_bits(shift_bits)))
      @lib.Instruction::I64ShrS(_) =>
        return Some((true, pls_i64_shift_ext_bits(shift_bits)))
      _ => ()
    }
  }
  None
}

///|
fn pls_extension_from_parent(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  _read_node_id : Int,
  site : @ir.HotUseSite,
  shift_ext_cache : Array[PLSShiftExtCacheEntry],
) -> (Bool, Int)? {
  if !pls_is_child_use_slot(site.kind) {
    return None
  }
  let parent_id = site.user
  let parent_instr = match @ir.hot_node_exact_instr(func, parent_id) {
    Some(i) => i
    None => return None
  }
  if site.slot == 0 {
    match parent_instr {
      @lib.Instruction::I32Extend8S => return Some((true, 8))
      @lib.Instruction::I32Extend16S => return Some((true, 16))
      @lib.Instruction::I64Extend8S => return Some((true, 8))
      @lib.Instruction::I64Extend16S => return Some((true, 16))
      @lib.Instruction::I64Extend32S => return Some((true, 32))
      @lib.Instruction::I64ExtendI32S => return Some((true, 32))
      @lib.Instruction::I64ExtendI32U => return Some((false, 32))
      @lib.Instruction::I32Shl => {
        let shift_bits = match
          pls_i32_const_node(func, @ir.hot_child_get(func, parent_id, 1)) {
          Some(bits) => bits
          None => return None
        }
        let cache = shift_ext_cache[parent_id]
        if !cache.computed {
          match
            pls_extension_from_grandparent_zero_ext(
              func, use_def, parent_id, shift_bits,
            ) {
            Some((is_signed, bits)) =>
              shift_ext_cache[parent_id] = {
                computed: true,
                has_result: true,
                is_signed,
                bits,
              }
            None =>
              shift_ext_cache[parent_id] = {
                computed: true,
                has_result: false,
                is_signed: false,
                bits: 0,
              }
          }
        }
        let updated_cache = shift_ext_cache[parent_id]
        if updated_cache.has_result {
          return Some((updated_cache.is_signed, updated_cache.bits))
        }
        return None
      }
      @lib.Instruction::I64Shl => {
        let shift_bits = match
          pls_i64_const_node(func, @ir.hot_child_get(func, parent_id, 1)) {
          Some(bits) => bits
          None => return None
        }
        let cache = shift_ext_cache[parent_id]
        if !cache.computed {
          match
            pls_extension_from_grandparent_zero_ext64(
              func, use_def, parent_id, shift_bits,
            ) {
            Some((is_signed, bits)) =>
              shift_ext_cache[parent_id] = {
                computed: true,
                has_result: true,
                is_signed,
                bits,
              }
            None =>
              shift_ext_cache[parent_id] = {
                computed: true,
                has_result: false,
                is_signed: false,
                bits: 0,
              }
          }
        }
        let updated_cache = shift_ext_cache[parent_id]
        if updated_cache.has_result {
          return Some((updated_cache.is_signed, updated_cache.bits))
        }
        return None
      }
      _ => ()
    }
  }
  match parent_instr {
    @lib.Instruction::I32And => {
      let sibling_id = if site.slot == 0 {
        @ir.hot_child_get(func, parent_id, 1)
      } else if site.slot == 1 {
        @ir.hot_child_get(func, parent_id, 0)
      } else {
        return None
      }
      let mask = match pls_i32_const_node(func, sibling_id) {
        Some(v) => v
        None => return None
      }
      match pls_i32_low_mask_bits(mask) {
        Some(bits) => Some((false, bits))
        None => None
      }
    }
    @lib.Instruction::I64And => {
      let sibling_id = if site.slot == 0 {
        @ir.hot_child_get(func, parent_id, 1)
      } else if site.slot == 1 {
        @ir.hot_child_get(func, parent_id, 0)
      } else {
        return None
      }
      let mask = match pls_i64_const_node(func, sibling_id) {
        Some(v) => v
        None => return None
      }
      match pls_i64_low_mask_bits(mask) {
        Some(bits) => Some((false, bits))
        None => None
      }
    }
    _ => None
  }
}

///|
fn pls_shift_ext_cache_make_empty(size : Int) -> Array[PLSShiftExtCacheEntry] {
  let out : Array[PLSShiftExtCacheEntry] = []
  for _ in 0..<size {
    out.push({ computed: false, has_result: false, is_signed: false, bits: 0 })
  }
  out
}

///|
fn pls_analyze_candidates(
  func : @ir.HotFunc,
  candidates : Array[PLSCandidateLoad],
  use_def : @ir.HotUseDef,
) -> PLSAnalysis {
  let usage_by_local = pls_make_usage_by_local(@ir.hot_local_count(func))
  let seen_local : Array[Bool] = []
  let local_work_list : Array[Int] = []
  for _ in 0..<usage_by_local.length() {
    seen_local.push(false)
  }
  let shift_ext_cache = pls_shift_ext_cache_make_empty(@ir.hot_node_count(func))
  for candidate in candidates {
    let local_idx = candidate.local_idx
    if local_idx < 0 || local_idx >= usage_by_local.length() {
      continue
    }
    if seen_local[local_idx] {
      continue
    }
    seen_local[local_idx] = true
    local_work_list.push(local_idx)
  }
  for local_idx in local_work_list {
    for read_id in @ir.local_read_nodes_borrowed(use_def, local_idx) {
      if usage_by_local[local_idx].invalid {
        break
      }
      if !@ir.hot_node_is_live(func, read_id) {
        continue
      }
      for site in @ir.node_use_sites_borrowed(use_def, read_id) {
        let usage = usage_by_local[local_idx]
        if usage.invalid {
          break
        }
        usage.total_usages += 1
        usage_by_local[local_idx] = usage
        match
          pls_extension_from_parent(
            func, use_def, read_id, site, shift_ext_cache,
          ) {
          Some((is_signed, bits)) =>
            if is_signed {
              pls_record_signed_usage(usage_by_local, local_idx, bits)
            } else {
              pls_record_unsigned_usage(usage_by_local, local_idx, bits)
            }
          None => {
            let usage = usage_by_local[local_idx]
            usage.invalid = true
            usage_by_local[local_idx] = usage
          }
        }
      }
    }
  }
  let mut rewritable_candidates = 0
  for idx in 0..<candidates.length() {
    let candidate = candidates[idx]
    let usage = usage_by_local[candidate.local_idx]
    let target_signed = pls_target_signedness(candidate, usage)
    if target_signed != candidate.current_signed {
      rewritable_candidates += 1
    }
    candidates[idx] = {
      local_idx: candidate.local_idx,
      set_node: candidate.set_node,
      load_id: candidate.load_id,
      load_addr_id: candidate.load_addr_id,
      load_bits: candidate.load_bits,
      load_is_i64: candidate.load_is_i64,
      current_signed: candidate.current_signed,
      target_signed,
    }
  }
  { candidates, rewritable_candidates }
}

///|
fn pls_scan_candidate_loads(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
) -> Array[PLSCandidateLoad] {
  let candidates : Array[PLSCandidateLoad] = []
  for local_idx in 0..<@ir.hot_local_count(func) {
    for node_id in @ir.local_write_nodes_borrowed(use_def, local_idx) {
      let node = @ir.hot_node_get(func, node_id)
      match node.op {
        @ir.HotOp::LocalSet => ()
        _ => continue
      }
      let child_id = @ir.hot_child_get(func, node_id, 0)
      if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
        continue
      }
      let child_node = @ir.hot_node_get(func, child_id)
      match child_node.op {
        @ir.HotOp::Load => ()
        _ => continue
      }
      let current_load = match @ir.hot_node_exact_instr(func, child_id) {
        Some(v) => v
        None => continue
      }
      let load_addr_id = @ir.hot_child_get(func, child_id, 0)
      if load_addr_id < 0 || !@ir.hot_node_is_live(func, load_addr_id) {
        continue
      }
      match pls_load_info(current_load) {
        Some((current_signed, load_bits, load_is_i64)) =>
          candidates.push({
            local_idx,
            set_node: node_id,
            load_id: child_id,
            load_addr_id,
            load_bits,
            load_is_i64,
            current_signed,
            target_signed: false,
          })
        None => ()
      }
    }
  }
  candidates
}

///|
fn pls_rewrite_candidates(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  analysis : PLSAnalysis,
) -> Bool {
  let mut changed = false
  for candidate in analysis.candidates {
    if candidate.target_signed == candidate.current_signed {
      continue
    }
    if !@ir.hot_node_is_live(func, candidate.load_id) {
      continue
    }
    let current_load = match @ir.hot_node_exact_instr(func, candidate.load_id) {
      Some(v) => v
      None => continue
    }
    let next_load = match
      pls_load_with_signedness(current_load, candidate.target_signed) {
      Some(instr) => instr
      None => continue
    }
    pipeline_trace_hook(
      ctx.trace,
      "pick-load-signs",
      "replace-load",
      payload="candidate(\{candidate.local_idx},\{candidate.set_node}) load_id=\{candidate.load_id} target_signed=\{candidate.target_signed}",
    )
    let next_ty = if candidate.load_is_i64 {
      @lib.ValType::i64()
    } else {
      @lib.ValType::i32()
    }
    pipeline_trace_hook(
      ctx.trace,
      "pick-load-signs",
      "replace-load-build",
      payload="load_id=\{candidate.load_id} ty=\{next_ty} memarg",
    )
    let replacement = @ir.hot_build_heap(func, [next_ty], next_load, [
      candidate.load_addr_id,
    ])
    let replacement_node = @ir.hot_node_get(func, replacement)
    @ir.hot_delete_node(func, replacement)
    pass_replace_node(ctx, func, candidate.load_id, replacement_node)
    pipeline_trace_hook(
      ctx.trace,
      "pick-load-signs",
      "replace-load-done",
      payload="load_id=\{candidate.load_id} replaced_by=\{replacement}",
    )
    changed = true
  }
  changed
}

///|
fn pick_load_signs_run(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> HotPassResult {
  let use_def = pass_require_use_def(ctx, func)
  let candidates = pls_scan_candidate_loads(func, use_def)
  pipeline_trace_hook(
    ctx.trace,
    "pick-load-signs",
    "scan-candidates",
    payload="count=\{candidates.length()}",
  )
  if candidates.length() == 0 {
    pipeline_trace_hook(ctx.trace, "pick-load-signs", "scan-none")
    return HotPassResult::unchanged()
  }
  let analysis = pls_analyze_candidates(func, candidates, use_def)
  pipeline_trace_hook(
    ctx.trace,
    "pick-load-signs",
    "analyzed",
    payload="rewritable=\{analysis.rewritable_candidates}",
  )
  if analysis.rewritable_candidates == 0 {
    pipeline_trace_hook(ctx.trace, "pick-load-signs", "no-rewrites")
    return HotPassResult::unchanged()
  }
  if pls_rewrite_candidates(ctx, func, analysis) {
    pipeline_trace_hook(ctx.trace, "pick-load-signs", "rewrite-changed")
    HotPassResult::changed()
  } else {
    pipeline_trace_hook(ctx.trace, "pick-load-signs", "rewrite-no-changes")
    HotPassResult::unchanged()
  }
}
