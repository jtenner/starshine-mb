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
}

///|
fn PLSUsage::new() -> PLSUsage {
  {
    signed_usages: 0,
    signed_bits: 0,
    unsigned_usages: 0,
    unsigned_bits: 0,
    total_usages: 0,
  }
}

///|
priv struct PLSCandidateLoad {
  local_idx : Int
  set_node : Int
  load_bits : Int
  current_signed : Bool
}

///|
priv struct PLSAnalysis {
  usage_by_local : Array[PLSUsage]
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
  if local_idx < 0 || local_idx >= usage_by_local.length() {
    return
  }
  let usage = usage_by_local[local_idx]
  if usage.signed_usages == 0 {
    usage.signed_bits = bits
  } else if usage.signed_bits != bits {
    usage.signed_bits = 0
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
  if local_idx < 0 || local_idx >= usage_by_local.length() {
    return
  }
  let usage = usage_by_local[local_idx]
  if usage.unsigned_usages == 0 {
    usage.unsigned_bits = bits
  } else if usage.unsigned_bits != bits {
    usage.unsigned_bits = 0
  }
  usage.unsigned_usages += 1
  usage_by_local[local_idx] = usage
}

///|
fn pls_load_info(instr : @lib.Instruction) -> (Bool, Int)? {
  match instr {
    @lib.Instruction::I32Load8S(_) => Some((true, 8))
    @lib.Instruction::I32Load8U(_) => Some((false, 8))
    @lib.Instruction::I32Load16S(_) => Some((true, 16))
    @lib.Instruction::I32Load16U(_) => Some((false, 16))
    @lib.Instruction::I64Load8S(_) => Some((true, 8))
    @lib.Instruction::I64Load8U(_) => Some((false, 8))
    @lib.Instruction::I64Load16S(_) => Some((true, 16))
    @lib.Instruction::I64Load16U(_) => Some((false, 16))
    @lib.Instruction::I64Load32S(_) => Some((true, 32))
    @lib.Instruction::I64Load32U(_) => Some((false, 32))
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
  if usage.total_usages == 0 ||
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
  for grand_site in @ir.node_use_sites(use_def, parent_id) {
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
  for grand_site in @ir.node_use_sites(use_def, parent_id) {
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
        return pls_extension_from_grandparent_zero_ext(
          func, use_def, parent_id, shift_bits,
        )
      }
      @lib.Instruction::I64Shl => {
        let shift_bits = match
          pls_i64_const_node(func, @ir.hot_child_get(func, parent_id, 1)) {
          Some(bits) => bits
          None => return None
        }
        return pls_extension_from_grandparent_zero_ext64(
          func, use_def, parent_id, shift_bits,
        )
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
fn pls_analyze_candidates(
  func : @ir.HotFunc,
  candidates : Array[PLSCandidateLoad],
  use_def : @ir.HotUseDef,
) -> PLSAnalysis {
  let usage_by_local = pls_make_usage_by_local(@ir.hot_local_count(func))
  for candidate in candidates {
    let local_idx = candidate.local_idx
    if local_idx < 0 || local_idx >= usage_by_local.length() {
      continue
    }
    for read_id in @ir.local_read_nodes(use_def, local_idx) {
      if !@ir.hot_node_is_live(func, read_id) {
        continue
      }
      for site in @ir.node_use_sites(use_def, read_id) {
        let usage = usage_by_local[local_idx]
        usage.total_usages += 1
        usage_by_local[local_idx] = usage
        match pls_extension_from_parent(func, use_def, read_id, site) {
          Some((is_signed, bits)) =>
            if is_signed {
              pls_record_signed_usage(usage_by_local, local_idx, bits)
            } else {
              pls_record_unsigned_usage(usage_by_local, local_idx, bits)
            }
          None => ()
        }
      }
    }
  }
  let mut rewritable_candidates = 0
  for candidate in candidates {
    if candidate.local_idx < 0 || candidate.local_idx >= usage_by_local.length() {
      continue
    }
    let usage = usage_by_local[candidate.local_idx]
    if pls_target_signedness(candidate, usage) != candidate.current_signed {
      rewritable_candidates += 1
    }
  }
  { usage_by_local, candidates, rewritable_candidates }
}

///|
fn pls_scan_candidate_loads(func : @ir.HotFunc) -> Array[PLSCandidateLoad] {
  let candidates : Array[PLSCandidateLoad] = []
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::LocalSet => ()
      _ => continue
    }
    let child_id = @ir.hot_child_get(func, node_id, 0)
    if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
      continue
    }
    let info = match @ir.hot_node_exact_instr(func, child_id) {
      Some(instr) => pls_load_info(instr)
      None => None
    }
    match info {
      Some((current_signed, load_bits)) =>
        candidates.push({
          local_idx: node.imm0,
          set_node: node_id,
          load_bits,
          current_signed,
        })
      None => ()
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
    if candidate.local_idx < 0 ||
      candidate.local_idx >= analysis.usage_by_local.length() {
      continue
    }
    let usage = analysis.usage_by_local[candidate.local_idx]
    let target_signed = pls_target_signedness(candidate, usage)
    if target_signed == candidate.current_signed {
      continue
    }
    let set_node = @ir.hot_node_get(func, candidate.set_node)
    match set_node.op {
      @ir.HotOp::LocalSet => ()
      _ => continue
    }
    let load_id = @ir.hot_child_get(func, candidate.set_node, 0)
    if load_id < 0 || !@ir.hot_node_is_live(func, load_id) {
      continue
    }
    let current_load = match @ir.hot_node_exact_instr(func, load_id) {
      Some(load_instr) => load_instr
      None => continue
    }
    let next_load = match
      pls_load_with_signedness(current_load, target_signed) {
      Some(instr) => instr
      None => continue
    }
    pipeline_trace_hook(
      ctx.trace,
      "pick-load-signs",
      "replace-load",
      payload="candidate(\{candidate.local_idx},\{candidate.set_node}) load_id=\{load_id} target_signed=\{target_signed}",
    )
    let next_types = @ir.hot_type_results(
      func,
      @ir.hot_node_get(func, load_id).ty,
    )
    if next_types.length() != 1 {
      pipeline_trace_hook(
        ctx.trace,
        "pick-load-signs",
        "skip-load-no-type",
        payload="load_id=\{load_id}",
      )
      continue
    }
    let next_ty = next_types[0]
    pipeline_trace_hook(
      ctx.trace,
      "pick-load-signs",
      "replace-load-build",
      payload="load_id=\{load_id} ty=\{next_ty} memarg",
    )
    let replacement = @ir.hot_build_heap(func, [next_ty], next_load, [
      @ir.hot_child_get(func, load_id, 0),
    ])
    let replacement_node = @ir.hot_node_get(func, replacement)
    @ir.hot_delete_node(func, replacement)
    pass_replace_node(ctx, func, load_id, replacement_node)
    pipeline_trace_hook(
      ctx.trace,
      "pick-load-signs",
      "replace-load-done",
      payload="load_id=\{load_id} replaced_by=\{replacement}",
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
  let candidates = pls_scan_candidate_loads(func)
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
  let use_def = pass_require_use_def(ctx, func)
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

///|
