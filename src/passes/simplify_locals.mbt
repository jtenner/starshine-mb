///|
pub fn simplify_locals_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new("simplify-locals", requires=[], invalidates=[
    @ir.HotAnalysis::cfg(),
    @ir.HotAnalysis::dominance(),
    @ir.HotAnalysis::liveness(),
    @ir.HotAnalysis::use_def(),
    @ir.HotAnalysis::effects(),
    @ir.HotAnalysis::loop_info(),
    @ir.HotAnalysis::ssa(),
  ])
}

///|
pub fn simplify_locals_summary() -> String {
  "Sink local.sets into later gets, lift structured block/if/loop returns when safe, canonicalize equivalent copies, and remove dead local writes."
}

///|
priv struct SimplifyLocalsEffects {
  mask : @ir.EffectMask
  local_reads : Array[Int]
  local_writes : Array[Int]
}

///|
priv struct SimplifyLocalsSinkableInfo {
  node_id : Int
  effects : SimplifyLocalsEffects
}

///|
priv struct SimplifyLocalsSinkables {
  entries : Array[SimplifyLocalsSinkableInfo?]
  active_pos : Array[Int]
  active_locals : Array[Int]
  effect_bit_counts : Array[Int]
  local_read_counts : Array[Int]
  local_write_counts : Array[Int]
  scratch_local_read_stamps : Array[Int]
  scratch_local_write_stamps : Array[Int]
  mut next_scratch_stamp : Int
}

///|
priv struct SimplifyLocalsTailSet {
  root_idx : Int
  node_id : Int
  local_id : Int
  value_id : Int
}

///|
priv struct SimplifyLocalsBranchExit {
  region_ref : @ir.HotRegionRef
  set_idx : Int
  set_id : Int
  br_id : Int
  local_id : Int
  value_id : Int
}

///|
fn simplify_locals_new_sinkables(func : @ir.HotFunc) -> SimplifyLocalsSinkables {
  {
    entries: Array::make(@ir.hot_local_count(func), None),
    active_pos: Array::make(@ir.hot_local_count(func), -1),
    active_locals: [],
    effect_bit_counts: Array::make(10, 0),
    local_read_counts: Array::make(@ir.hot_local_count(func), 0),
    local_write_counts: Array::make(@ir.hot_local_count(func), 0),
    scratch_local_read_stamps: Array::make(@ir.hot_local_count(func), 0),
    scratch_local_write_stamps: Array::make(@ir.hot_local_count(func), 0),
    next_scratch_stamp: 1,
  }
}

///|
fn simplify_locals_accumulate_effect_mask_counts(
  counts : Array[Int],
  mask : @ir.EffectMask,
  delta : Int,
) -> Unit {
  let mut bit = 1U
  let mut idx = 0
  while idx < counts.length() {
    if (mask & bit) != 0U {
      counts[idx] = counts[idx] + delta
    }
    bit = bit << 1
    idx = idx + 1
  }
}

///|
fn simplify_locals_accumulate_local_effect_counts(
  counts : Array[Int],
  effects : Array[Int],
  delta : Int,
) -> Unit {
  for local_id in effects {
    if local_id >= 0 && local_id < counts.length() {
      counts[local_id] = counts[local_id] + delta
    }
  }
}

///|
fn simplify_locals_sinkables_add_effects(
  sinkables : SimplifyLocalsSinkables,
  effects : SimplifyLocalsEffects,
) -> Unit {
  simplify_locals_accumulate_effect_mask_counts(
    sinkables.effect_bit_counts,
    effects.mask,
    1,
  )
  simplify_locals_accumulate_local_effect_counts(
    sinkables.local_read_counts,
    effects.local_reads,
    1,
  )
  simplify_locals_accumulate_local_effect_counts(
    sinkables.local_write_counts,
    effects.local_writes,
    1,
  )
}

///|
fn simplify_locals_sinkables_remove_effects(
  sinkables : SimplifyLocalsSinkables,
  effects : SimplifyLocalsEffects,
) -> Unit {
  simplify_locals_accumulate_effect_mask_counts(
    sinkables.effect_bit_counts,
    effects.mask,
    -1,
  )
  simplify_locals_accumulate_local_effect_counts(
    sinkables.local_read_counts,
    effects.local_reads,
    -1,
  )
  simplify_locals_accumulate_local_effect_counts(
    sinkables.local_write_counts,
    effects.local_writes,
    -1,
  )
}

///|
fn simplify_locals_sinkables_have_effect(
  sinkables : SimplifyLocalsSinkables,
  bit : @ir.EffectMask,
) -> Bool {
  let mut mask_bit = 1U
  let mut idx = 0
  while idx < sinkables.effect_bit_counts.length() {
    if mask_bit == bit {
      return sinkables.effect_bit_counts[idx] > 0
    }
    mask_bit = mask_bit << 1
    idx = idx + 1
  }
  false
}

///|
fn simplify_locals_sinkables_may_conflict(
  sinkables : SimplifyLocalsSinkables,
  rhs_mask : @ir.EffectMask,
  rhs_local_read : Int,
  rhs_local_write : Int,
) -> Bool {
  if sinkables.active_locals.is_empty() || rhs_mask == 0U {
    return false
  }

  if simplify_locals_effects_has(rhs_mask, @ir.EFFECT_MASK_CALL) ||
    simplify_locals_effects_has(
      rhs_mask,
      @ir.EFFECT_MASK_CONTROL | @ir.EFFECT_MASK_THROW | @ir.EFFECT_MASK_TRAP,
    ) {
    return true
  }

  if simplify_locals_effects_has(rhs_mask, @ir.EFFECT_MASK_LOCAL_STATE) {
    if rhs_local_read >= 0 &&
      rhs_local_read < sinkables.local_write_counts.length() &&
      sinkables.local_write_counts[rhs_local_read] > 0 {
      return true
    }
    if rhs_local_write >= 0 &&
      rhs_local_write < sinkables.local_read_counts.length() &&
      (
        sinkables.local_read_counts[rhs_local_write] > 0 ||
        sinkables.local_write_counts[rhs_local_write] > 0
      ) {
      return true
    }
  }

  if simplify_locals_effects_has(rhs_mask, @ir.EFFECT_MASK_GLOBAL_STATE) &&
    simplify_locals_sinkables_have_effect(
      sinkables,
      @ir.EFFECT_MASK_GLOBAL_STATE,
    ) {
    return true
  }

  let rhs_reads_memory = simplify_locals_effects_has(
    rhs_mask,
    @ir.EFFECT_MASK_MEMORY_READ,
  )
  let rhs_writes_memory = simplify_locals_effects_has(
    rhs_mask,
    @ir.EFFECT_MASK_MEMORY_WRITE,
  )
  if (
      rhs_reads_memory &&
      simplify_locals_sinkables_have_effect(
        sinkables,
        @ir.EFFECT_MASK_MEMORY_WRITE,
      )
    ) ||
    (
      rhs_writes_memory &&
      (
        simplify_locals_sinkables_have_effect(
          sinkables,
          @ir.EFFECT_MASK_MEMORY_READ,
        ) ||
        simplify_locals_sinkables_have_effect(
          sinkables,
          @ir.EFFECT_MASK_MEMORY_WRITE,
        )
      )
    ) {
    return true
  }

  let rhs_reads_table = simplify_locals_effects_has(
    rhs_mask,
    @ir.EFFECT_MASK_TABLE_READ,
  )
  let rhs_writes_table = simplify_locals_effects_has(
    rhs_mask,
    @ir.EFFECT_MASK_TABLE_WRITE,
  )
  if (
      rhs_reads_table &&
      simplify_locals_sinkables_have_effect(
        sinkables,
        @ir.EFFECT_MASK_TABLE_WRITE,
      )
    ) ||
    (
      rhs_writes_table &&
      (
        simplify_locals_sinkables_have_effect(
          sinkables,
          @ir.EFFECT_MASK_TABLE_READ,
        ) ||
        simplify_locals_sinkables_have_effect(
          sinkables,
          @ir.EFFECT_MASK_TABLE_WRITE,
        )
      )
    ) {
    return true
  }

  false
}

///|
fn simplify_locals_sinkables_get(
  sinkables : SimplifyLocalsSinkables,
  local_id : Int,
) -> SimplifyLocalsSinkableInfo? {
  if local_id < 0 || local_id >= sinkables.entries.length() {
    return None
  }
  sinkables.entries[local_id]
}

///|
fn simplify_locals_sinkables_set(
  sinkables : SimplifyLocalsSinkables,
  local_id : Int,
  info : SimplifyLocalsSinkableInfo,
) -> Unit {
  if local_id < 0 || local_id >= sinkables.entries.length() {
    return
  }
  if sinkables.active_pos[local_id] < 0 {
    sinkables.active_pos[local_id] = sinkables.active_locals.length()
    sinkables.active_locals.push(local_id)
  } else {
    match sinkables.entries[local_id] {
      Some(previous) =>
        simplify_locals_sinkables_remove_effects(sinkables, previous.effects)
      None => ()
    }
  }
  sinkables.entries[local_id] = Some(info)
  simplify_locals_sinkables_add_effects(sinkables, info.effects)
}

///|
fn simplify_locals_sinkables_clear_local(
  sinkables : SimplifyLocalsSinkables,
  local_id : Int,
) -> Unit {
  if local_id < 0 || local_id >= sinkables.entries.length() {
    return
  }
  let pos = sinkables.active_pos[local_id]
  if pos >= 0 {
    match sinkables.entries[local_id] {
      Some(info) =>
        simplify_locals_sinkables_remove_effects(sinkables, info.effects)
      None => ()
    }
    let last_local = sinkables.active_locals.pop().unwrap()
    if last_local != local_id {
      sinkables.active_locals[pos] = last_local
      sinkables.active_pos[last_local] = pos
    }
    sinkables.active_pos[local_id] = -1
  }
  sinkables.entries[local_id] = None
}

///|
fn simplify_locals_sinkables_should_bulk_clear(
  sinkables : SimplifyLocalsSinkables,
) -> Bool {
  sinkables.active_locals.length() * 4 >= sinkables.local_read_counts.length()
}

///|
fn simplify_locals_sinkables_zero_aggregate_counts(
  sinkables : SimplifyLocalsSinkables,
) -> Unit {
  for idx = 0; idx < sinkables.effect_bit_counts.length(); idx = idx + 1 {
    sinkables.effect_bit_counts[idx] = 0
  }
  for idx = 0; idx < sinkables.local_read_counts.length(); idx = idx + 1 {
    sinkables.local_read_counts[idx] = 0
    sinkables.local_write_counts[idx] = 0
  }
}

///|
fn simplify_locals_clear_sinkables(sinkables : SimplifyLocalsSinkables) -> Unit {
  if simplify_locals_sinkables_should_bulk_clear(sinkables) {
    while !sinkables.active_locals.is_empty() {
      let local_id = sinkables.active_locals.pop().unwrap()
      sinkables.entries[local_id] = None
      sinkables.active_pos[local_id] = -1
    }
    simplify_locals_sinkables_zero_aggregate_counts(sinkables)
    return
  }
  while !sinkables.active_locals.is_empty() {
    let local_id = sinkables.active_locals.pop().unwrap()
    match sinkables.entries[local_id] {
      Some(info) =>
        simplify_locals_sinkables_remove_effects(sinkables, info.effects)
      None => ()
    }
    sinkables.entries[local_id] = None
    sinkables.active_pos[local_id] = -1
  }
}

///|
fn simplify_locals_empty_effects() -> SimplifyLocalsEffects {
  { mask: 0U, local_reads: [], local_writes: [] }
}

///|
fn simplify_locals_next_scratch_stamp(
  sinkables : SimplifyLocalsSinkables,
) -> Int {
  let stamp = sinkables.next_scratch_stamp
  sinkables.next_scratch_stamp = stamp + 1
  stamp
}

///|
fn simplify_locals_record_sparse_local_effect(
  local_ids : Array[Int],
  stamps : Array[Int],
  stamp : Int,
  local_id : Int,
) -> Unit {
  if local_id < 0 || local_id >= stamps.length() {
    return
  }
  if stamps[local_id] == stamp {
    return
  }
  stamps[local_id] = stamp
  local_ids.push(local_id)
}

///|
fn simplify_locals_record_exact_local_effects(
  func : @ir.HotFunc,
  node_id : Int,
  local_reads : Array[Int],
  local_writes : Array[Int],
  read_stamps : Array[Int],
  write_stamps : Array[Int],
  stamp : Int,
) -> Unit {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet =>
      simplify_locals_record_sparse_local_effect(
        local_reads,
        read_stamps,
        stamp,
        node.imm0,
      )
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee =>
      simplify_locals_record_sparse_local_effect(
        local_writes,
        write_stamps,
        stamp,
        node.imm0,
      )
    _ => ()
  }
}

///|
fn simplify_locals_collect_subtree_local_effects(
  func : @ir.HotFunc,
  node_id : Int,
  local_reads : Array[Int],
  local_writes : Array[Int],
  read_stamps : Array[Int],
  write_stamps : Array[Int],
  stamp : Int,
) -> Unit {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return
  }
  simplify_locals_record_exact_local_effects(
    func, node_id, local_reads, local_writes, read_stamps, write_stamps, stamp,
  )
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    let child_id = @ir.hot_child_get(func, node_id, slot)
    simplify_locals_collect_subtree_local_effects(
      func, child_id, local_reads, local_writes, read_stamps, write_stamps, stamp,
    )
  }
}

///|
fn simplify_locals_effects_mask_for_flags(flags : UInt) -> @ir.EffectMask {
  let mut mask = 0U
  if (flags & @ir.HOT_FLAG_CONTROL) != 0U ||
    (flags & @ir.HOT_FLAG_BRANCH) != 0U ||
    (flags & @ir.HOT_FLAG_TERMINATOR) != 0U {
    mask = mask | @ir.EFFECT_MASK_CONTROL
  }
  if (flags & @ir.HOT_FLAG_CALL) != 0U {
    mask = mask | @ir.EFFECT_MASK_CALL | @ir.EFFECT_MASK_THROW
  }
  if (flags & @ir.HOT_FLAG_THROWS) != 0U ||
    (flags & @ir.HOT_FLAG_HAS_EXCEPTIONAL_SUCC) != 0U {
    mask = mask | @ir.EFFECT_MASK_THROW
  }
  if (flags & @ir.HOT_FLAG_MAY_TRAP) != 0U {
    mask = mask | @ir.EFFECT_MASK_TRAP
  }
  mask
}

///|
fn simplify_locals_effects_mask_for_atomic_exact(
  instr : @lib.Instruction?,
) -> @ir.EffectMask {
  match instr {
    Some(@lib.Instruction::MemoryAtomicNotify(_)) =>
      @ir.EFFECT_MASK_MEMORY_WRITE | @ir.EFFECT_MASK_TRAP
    Some(@lib.Instruction::MemoryAtomicWait32(_))
    | Some(@lib.Instruction::MemoryAtomicWait64(_))
    | Some(@lib.Instruction::I32AtomicLoad(_))
    | Some(@lib.Instruction::I64AtomicLoad(_))
    | Some(@lib.Instruction::I32AtomicLoad8U(_))
    | Some(@lib.Instruction::I32AtomicLoad16U(_))
    | Some(@lib.Instruction::I64AtomicLoad8U(_))
    | Some(@lib.Instruction::I64AtomicLoad16U(_))
    | Some(@lib.Instruction::I64AtomicLoad32U(_)) =>
      @ir.EFFECT_MASK_MEMORY_READ | @ir.EFFECT_MASK_TRAP
    Some(@lib.Instruction::I32AtomicStore(_))
    | Some(@lib.Instruction::I64AtomicStore(_))
    | Some(@lib.Instruction::I32AtomicStore8(_))
    | Some(@lib.Instruction::I32AtomicStore16(_))
    | Some(@lib.Instruction::I64AtomicStore8(_))
    | Some(@lib.Instruction::I64AtomicStore16(_))
    | Some(@lib.Instruction::I64AtomicStore32(_)) =>
      @ir.EFFECT_MASK_MEMORY_WRITE | @ir.EFFECT_MASK_TRAP
    Some(@lib.Instruction::AtomicRmw(_, _))
    | Some(@lib.Instruction::AtomicCmpxchg(_, _)) =>
      @ir.EFFECT_MASK_MEMORY_READ |
      @ir.EFFECT_MASK_MEMORY_WRITE |
      @ir.EFFECT_MASK_TRAP
    _ =>
      @ir.EFFECT_MASK_MEMORY_READ |
      @ir.EFFECT_MASK_MEMORY_WRITE |
      @ir.EFFECT_MASK_TRAP
  }
}

///|
fn simplify_locals_effects_mask_for_heap_exact(
  instr : @lib.Instruction?,
) -> @ir.EffectMask {
  match instr {
    Some(@lib.Instruction::StructGet(_, _))
    | Some(@lib.Instruction::StructGetS(_, _))
    | Some(@lib.Instruction::StructGetU(_, _))
    | Some(@lib.Instruction::ArrayGet(_))
    | Some(@lib.Instruction::ArrayGetS(_))
    | Some(@lib.Instruction::ArrayGetU(_))
    | Some(@lib.Instruction::ArrayLen)
    | Some(@lib.Instruction::RefGetDesc(_)) =>
      @ir.EFFECT_MASK_MEMORY_READ | @ir.EFFECT_MASK_TRAP
    Some(@lib.Instruction::StructSet(_, _))
    | Some(@lib.Instruction::ArraySet(_))
    | Some(@lib.Instruction::ArrayFill(_)) =>
      @ir.EFFECT_MASK_MEMORY_WRITE | @ir.EFFECT_MASK_TRAP
    Some(@lib.Instruction::StructNew(_))
    | Some(@lib.Instruction::StructNewDefault(_))
    | Some(@lib.Instruction::StructNewDesc(_))
    | Some(@lib.Instruction::StructNewDefaultDesc(_))
    | Some(@lib.Instruction::ArrayNew(_))
    | Some(@lib.Instruction::ArrayNewDefault(_))
    | Some(@lib.Instruction::ArrayNewFixed(_, _))
    | Some(@lib.Instruction::ArrayNewData(_, _))
    | Some(@lib.Instruction::ArrayNewElem(_, _))
    | Some(@lib.Instruction::ArrayCopy(_, _))
    | Some(@lib.Instruction::ArrayInitData(_, _))
    | Some(@lib.Instruction::ArrayInitElem(_, _)) =>
      @ir.EFFECT_MASK_MEMORY_READ |
      @ir.EFFECT_MASK_MEMORY_WRITE |
      @ir.EFFECT_MASK_TRAP
    Some(@lib.Instruction::RefAsNonNull)
    | Some(@lib.Instruction::I31GetS)
    | Some(@lib.Instruction::I31GetU) => @ir.EFFECT_MASK_TRAP
    Some(@lib.Instruction::RefEq)
    | Some(@lib.Instruction::AnyConvertExtern)
    | Some(@lib.Instruction::ExternConvertAny)
    | Some(@lib.Instruction::RefI31) => 0U
    _ => @ir.EFFECT_MASK_TRAP
  }
}

///|
fn simplify_locals_effects_mask_for_exact_node(
  func : @ir.HotFunc,
  node_id : Int,
) -> @ir.EffectMask {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return 0U
  }
  let node = @ir.hot_node_get(func, node_id)
  let exact_mask = match node.op {
    @ir.HotOp::LocalGet | @ir.HotOp::LocalSet | @ir.HotOp::LocalTee =>
      @ir.EFFECT_MASK_LOCAL_STATE
    @ir.HotOp::GlobalGet | @ir.HotOp::GlobalSet => @ir.EFFECT_MASK_GLOBAL_STATE
    @ir.HotOp::Load => @ir.EFFECT_MASK_MEMORY_READ
    @ir.HotOp::Store => @ir.EFFECT_MASK_MEMORY_WRITE
    @ir.HotOp::MemorySize => @ir.EFFECT_MASK_MEMORY_READ
    @ir.HotOp::MemoryGrow =>
      @ir.EFFECT_MASK_MEMORY_READ | @ir.EFFECT_MASK_MEMORY_WRITE
    @ir.HotOp::MemoryCopy | @ir.HotOp::MemoryInit =>
      @ir.EFFECT_MASK_MEMORY_READ | @ir.EFFECT_MASK_MEMORY_WRITE
    @ir.HotOp::MemoryFill | @ir.HotOp::DataDrop => @ir.EFFECT_MASK_MEMORY_WRITE
    @ir.HotOp::TableGet | @ir.HotOp::TableSize => @ir.EFFECT_MASK_TABLE_READ
    @ir.HotOp::TableSet
    | @ir.HotOp::TableGrow
    | @ir.HotOp::TableFill
    | @ir.HotOp::ElemDrop => @ir.EFFECT_MASK_TABLE_WRITE
    @ir.HotOp::TableCopy | @ir.HotOp::TableInit =>
      @ir.EFFECT_MASK_TABLE_READ | @ir.EFFECT_MASK_TABLE_WRITE
    @ir.HotOp::Atomic =>
      simplify_locals_effects_mask_for_atomic_exact(
        @ir.hot_node_exact_instr(func, node_id),
      )
    @ir.HotOp::Heap =>
      simplify_locals_effects_mask_for_heap_exact(
        @ir.hot_node_exact_instr(func, node_id),
      )
    _ => 0U
  }
  simplify_locals_effects_mask_for_flags(node.flags) | exact_mask
}

///|
fn simplify_locals_exact_local_read_id(node : @ir.HotNode) -> Int {
  match node.op {
    @ir.HotOp::LocalGet => node.imm0
    _ => -1
  }
}

///|
fn simplify_locals_exact_local_write_id(node : @ir.HotNode) -> Int {
  match node.op {
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => node.imm0
    _ => -1
  }
}

///|
fn simplify_locals_effects_for_pending_local_set(
  func : @ir.HotFunc,
  node_id : Int,
  node : @ir.HotNode,
  sinkables : SimplifyLocalsSinkables,
) -> SimplifyLocalsEffects {
  let effects = simplify_locals_empty_effects()
  let stamp = simplify_locals_next_scratch_stamp(sinkables)
  let value_mask = if node.child_count != 0 {
    @ir.effects_for_node(func, @ir.hot_child_get(func, node_id, 0))
  } else {
    0U
  }
  if node.child_count != 0 &&
    simplify_locals_effects_has(value_mask, @ir.EFFECT_MASK_LOCAL_STATE) &&
    !simplify_locals_effects_has(
      value_mask,
      @ir.EFFECT_MASK_CALL |
      @ir.EFFECT_MASK_CONTROL |
      @ir.EFFECT_MASK_THROW |
      @ir.EFFECT_MASK_TRAP,
    ) {
    simplify_locals_collect_subtree_local_effects(
      func,
      @ir.hot_child_get(func, node_id, 0),
      effects.local_reads,
      effects.local_writes,
      sinkables.scratch_local_read_stamps,
      sinkables.scratch_local_write_stamps,
      stamp,
    )
  }
  simplify_locals_record_sparse_local_effect(
    effects.local_writes,
    sinkables.scratch_local_write_stamps,
    stamp,
    node.imm0,
  )
  { ..effects, mask: value_mask | @ir.EFFECT_MASK_LOCAL_STATE }
}

///|
fn simplify_locals_effects_has(
  mask : @ir.EffectMask,
  bit : @ir.EffectMask,
) -> Bool {
  (mask & bit) != 0U
}

///|
fn simplify_locals_effects_has_local(
  local_ids : Array[Int],
  local_id : Int,
) -> Bool {
  if local_id < 0 {
    return false
  }
  for current_id in local_ids {
    if current_id == local_id {
      return true
    }
  }
  false
}

///|
fn simplify_locals_effects_conflict_exact_local(
  lhs : SimplifyLocalsEffects,
  rhs_local_read : Int,
  rhs_local_write : Int,
) -> Bool {
  if simplify_locals_effects_has_local(lhs.local_writes, rhs_local_read) {
    return true
  }
  if simplify_locals_effects_has_local(lhs.local_reads, rhs_local_write) ||
    simplify_locals_effects_has_local(lhs.local_writes, rhs_local_write) {
    return true
  }
  false
}

///|
fn simplify_locals_effects_readonly_trap_commutable(
  mask : @ir.EffectMask,
) -> Bool {
  (
    mask &
    (
      @ir.EFFECT_MASK_CALL |
      @ir.EFFECT_MASK_CONTROL |
      @ir.EFFECT_MASK_THROW |
      @ir.EFFECT_MASK_GLOBAL_STATE |
      @ir.EFFECT_MASK_MEMORY_WRITE |
      @ir.EFFECT_MASK_TABLE_WRITE
    )
  ) ==
  0U
}

///|
fn simplify_locals_effects_ordered_before(
  lhs : SimplifyLocalsEffects,
  rhs_mask : @ir.EffectMask,
  rhs_local_read : Int,
  rhs_local_write : Int,
) -> Bool {
  if simplify_locals_effects_has(lhs.mask, @ir.EFFECT_MASK_CALL) ||
    simplify_locals_effects_has(rhs_mask, @ir.EFFECT_MASK_CALL) {
    return true
  }

  let lhs_non_linear = simplify_locals_effects_has(
    lhs.mask,
    @ir.EFFECT_MASK_CONTROL | @ir.EFFECT_MASK_THROW,
  )
  let rhs_non_linear = simplify_locals_effects_has(
    rhs_mask,
    @ir.EFFECT_MASK_CONTROL | @ir.EFFECT_MASK_THROW,
  )
  if (lhs_non_linear || rhs_non_linear) && lhs.mask != 0U && rhs_mask != 0U {
    return true
  }

  if simplify_locals_effects_has(lhs.mask, @ir.EFFECT_MASK_LOCAL_STATE) &&
    simplify_locals_effects_has(rhs_mask, @ir.EFFECT_MASK_LOCAL_STATE) &&
    simplify_locals_effects_conflict_exact_local(
      lhs, rhs_local_read, rhs_local_write,
    ) {
    return true
  }

  if simplify_locals_effects_has(lhs.mask, @ir.EFFECT_MASK_GLOBAL_STATE) &&
    simplify_locals_effects_has(rhs_mask, @ir.EFFECT_MASK_GLOBAL_STATE) {
    return true
  }

  let lhs_reads_memory = simplify_locals_effects_has(
    lhs.mask,
    @ir.EFFECT_MASK_MEMORY_READ,
  )
  let lhs_writes_memory = simplify_locals_effects_has(
    lhs.mask,
    @ir.EFFECT_MASK_MEMORY_WRITE,
  )
  let rhs_reads_memory = simplify_locals_effects_has(
    rhs_mask,
    @ir.EFFECT_MASK_MEMORY_READ,
  )
  let rhs_writes_memory = simplify_locals_effects_has(
    rhs_mask,
    @ir.EFFECT_MASK_MEMORY_WRITE,
  )
  if lhs_writes_memory && (rhs_reads_memory || rhs_writes_memory) {
    return true
  }
  if lhs_reads_memory && rhs_writes_memory {
    return true
  }

  let lhs_reads_table = simplify_locals_effects_has(
    lhs.mask,
    @ir.EFFECT_MASK_TABLE_READ,
  )
  let lhs_writes_table = simplify_locals_effects_has(
    lhs.mask,
    @ir.EFFECT_MASK_TABLE_WRITE,
  )
  let rhs_reads_table = simplify_locals_effects_has(
    rhs_mask,
    @ir.EFFECT_MASK_TABLE_READ,
  )
  let rhs_writes_table = simplify_locals_effects_has(
    rhs_mask,
    @ir.EFFECT_MASK_TABLE_WRITE,
  )
  if lhs_writes_table && (rhs_reads_table || rhs_writes_table) {
    return true
  }
  if lhs_reads_table && rhs_writes_table {
    return true
  }

  let lhs_traps = simplify_locals_effects_has(lhs.mask, @ir.EFFECT_MASK_TRAP)
  let rhs_traps = simplify_locals_effects_has(rhs_mask, @ir.EFFECT_MASK_TRAP)
  let readonly_trap_commutable = simplify_locals_effects_readonly_trap_commutable(
      lhs.mask,
    ) &&
    simplify_locals_effects_readonly_trap_commutable(rhs_mask)
  let lhs_has_non_local_effects = simplify_locals_effects_has(
    lhs.mask,
    @ir.EFFECT_MASK_CALL |
    @ir.EFFECT_MASK_CONTROL |
    @ir.EFFECT_MASK_THROW |
    @ir.EFFECT_MASK_TRAP |
    @ir.EFFECT_MASK_GLOBAL_STATE |
    @ir.EFFECT_MASK_MEMORY_READ |
    @ir.EFFECT_MASK_MEMORY_WRITE |
    @ir.EFFECT_MASK_TABLE_READ |
    @ir.EFFECT_MASK_TABLE_WRITE,
  )
  if lhs_traps && rhs_mask != 0U && !readonly_trap_commutable {
    return true
  }
  if rhs_traps && lhs_has_non_local_effects && !readonly_trap_commutable {
    return true
  }

  false
}

///|
fn simplify_locals_invalidate_sinkables(
  func : @ir.HotFunc,
  node_id : Int,
  node : @ir.HotNode,
  sinkables : SimplifyLocalsSinkables,
  skip_local? : Int = -1,
) -> Unit {
  let effects_mask = simplify_locals_effects_mask_for_exact_node(func, node_id)
  if effects_mask == 0U {
    return
  }
  let effects_local_read = simplify_locals_exact_local_read_id(node)
  let effects_local_write = simplify_locals_exact_local_write_id(node)
  let clear_all = simplify_locals_effects_has(
      effects_mask,
      @ir.EFFECT_MASK_CALL,
    ) ||
    simplify_locals_effects_has(
      effects_mask,
      @ir.EFFECT_MASK_CONTROL | @ir.EFFECT_MASK_THROW,
    )
  if clear_all && skip_local < 0 {
    simplify_locals_clear_sinkables(sinkables)
    return
  }
  if !simplify_locals_sinkables_may_conflict(
      sinkables, effects_mask, effects_local_read, effects_local_write,
    ) {
    return
  }
  let mut idx = 0
  while idx < sinkables.active_locals.length() {
    let local_id = sinkables.active_locals[idx]
    if local_id == skip_local {
      idx = idx + 1
      continue
    }
    match sinkables.entries[local_id] {
      Some(info) =>
        if !@ir.hot_node_is_live(func, info.node_id) ||
          simplify_locals_effects_ordered_before(
            info.effects,
            effects_mask,
            effects_local_read,
            effects_local_write,
          ) {
          simplify_locals_sinkables_clear_local(sinkables, local_id)
          continue
        }
      None => ()
    }
    idx = idx + 1
  }
}

///|
fn simplify_locals_make_nop(func : @ir.HotFunc) -> @ir.HotNode {
  let replacement_id = @ir.hot_build_nop(func)
  let replacement = @ir.hot_node_get(func, replacement_id)
  @ir.hot_delete_node(func, replacement_id)
  replacement
}

///|
fn simplify_locals_make_drop(func : @ir.HotFunc, value_id : Int) -> @ir.HotNode {
  let replacement_id = @ir.hot_build_drop(func, value_id)
  let replacement = @ir.hot_node_get(func, replacement_id)
  @ir.hot_delete_node(func, replacement_id)
  replacement
}

///|
fn simplify_locals_make_local_get(
  func : @ir.HotFunc,
  local_id : Int,
) -> @ir.HotNode {
  let replacement_id = @ir.hot_build_local_get(func, local_id)
  let replacement = @ir.hot_node_get(func, replacement_id)
  @ir.hot_delete_node(func, replacement_id)
  replacement
}

///|
fn simplify_locals_make_local_tee(
  func : @ir.HotFunc,
  local_id : Int,
  value_id : Int,
) -> @ir.HotNode {
  let replacement_id = @ir.hot_build_local_tee(func, local_id, value_id)
  let replacement = @ir.hot_node_get(func, replacement_id)
  @ir.hot_delete_node(func, replacement_id)
  replacement
}

///|
fn simplify_locals_make_local_set(
  func : @ir.HotFunc,
  local_id : Int,
  value_id : Int,
) -> @ir.HotNode {
  let replacement_id = @ir.hot_build_local_set(func, local_id, value_id)
  let replacement = @ir.hot_node_get(func, replacement_id)
  @ir.hot_delete_node(func, replacement_id)
  replacement
}

///|
fn simplify_locals_local_type_id(
  func : @ir.HotFunc,
  local_id : Int,
  fallback_id : Int,
) -> Int {
  match @ir.hot_local_type(func, local_id) {
    Some(local_type) =>
      @ir.hot_type_intern_block_result(
        func,
        @lib.BlockType::val_type(local_type),
      )
    None =>
      match @ir.hot_type_results(func, @ir.hot_node_type(func, fallback_id)) {
        [value_type] =>
          @ir.hot_type_intern_block_result(
            func,
            @lib.BlockType::val_type(value_type),
          )
        _ => @ir.hot_type_void(func)
      }
  }
}

///|
fn simplify_locals_local_type_is_defaultable(
  func : @ir.HotFunc,
  local_id : Int,
) -> Bool {
  match @ir.hot_local_type(func, local_id) {
    Some(@lib.RefTypeValType(ref_type)) =>
      @lib.RefType::is_defaultable(ref_type)
    Some(@lib.BotValType) => false
    Some(_) => true
    None => false
  }
}

///|
fn simplify_locals_region_last_live_non_nop_root_idx(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Int? {
  let mut idx = @ir.hot_region_root_count(func, region_ref) - 1
  while idx >= 0 {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id >= 0 && @ir.hot_node_is_live(func, node_id) {
      match @ir.hot_node_get(func, node_id).op {
        @ir.HotOp::Nop => ()
        _ => return Some(idx)
      }
    }
    idx = idx - 1
  }
  None
}

///|
fn simplify_locals_region_prev_live_non_nop_root_idx(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  before_idx : Int,
) -> Int? {
  let mut idx = before_idx - 1
  while idx >= 0 {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id >= 0 && @ir.hot_node_is_live(func, node_id) {
      match @ir.hot_node_get(func, node_id).op {
        @ir.HotOp::Nop => ()
        _ => return Some(idx)
      }
    }
    idx = idx - 1
  }
  None
}

///|
fn simplify_locals_region_next_live_non_nop_root_idx(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  after_idx : Int,
) -> Int? {
  let mut idx = after_idx + 1
  while idx < @ir.hot_region_root_count(func, region_ref) {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id >= 0 && @ir.hot_node_is_live(func, node_id) {
      match @ir.hot_node_get(func, node_id).op {
        @ir.HotOp::Nop => ()
        _ => return Some(idx)
      }
    }
    idx = idx + 1
  }
  None
}

///|
fn simplify_locals_region_tail_local_set(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> SimplifyLocalsTailSet? {
  let root_idx = match
    simplify_locals_region_last_live_non_nop_root_idx(func, region_ref) {
    Some(root_idx) => root_idx
    None => return None
  }
  let node_id = @ir.hot_region_get(func, region_ref, root_idx)
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalSet =>
      Some({
        root_idx,
        node_id,
        local_id: node.imm0,
        value_id: @ir.hot_child_get(func, node_id, 0),
      })
    _ => None
  }
}

///|
fn simplify_locals_subtree_mentions_local(
  func : @ir.HotFunc,
  node_id : Int,
  local_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet | @ir.HotOp::LocalSet | @ir.HotOp::LocalTee =>
      if node.imm0 == local_id {
        return true
      }
    _ => ()
  }
  for child_idx = 0
      child_idx < @ir.hot_child_count(func, node_id)
      child_idx = child_idx + 1 {
    if simplify_locals_subtree_mentions_local(
        func,
        @ir.hot_child_get(func, node_id, child_idx),
        local_id,
      ) {
      return true
    }
  }
  false
}

///|
fn simplify_locals_root_allows_moving_local_set_value_after(
  func : @ir.HotFunc,
  node_id : Int,
  local_id : Int,
  target_label : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return true
  }
  !simplify_locals_subtree_mentions_local(func, node_id, local_id) &&
  !simplify_locals_subtree_has_branch_to_label(func, node_id, target_label)
}

///|
fn simplify_locals_collect_block_return_candidates(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  target_label : Int,
  get_counts : Array[Int],
) -> Array[SimplifyLocalsTailSet] {
  let candidates : Array[SimplifyLocalsTailSet] = []
  let trailing_roots : Array[Int] = []
  let mut idx = @ir.hot_region_root_count(func, region_ref) - 1
  while idx >= 0 {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id >= 0 && @ir.hot_node_is_live(func, node_id) {
      let node = @ir.hot_node_get(func, node_id)
      match node.op {
        @ir.HotOp::Nop => ()
        @ir.HotOp::LocalSet => {
          let local_id = node.imm0
          let value_id = @ir.hot_child_get(func, node_id, 0)
          let mut allowed = local_id >= 0 &&
            local_id < get_counts.length() &&
            get_counts[local_id] != 0 &&
            simplify_locals_value_is_pure(func, value_id) &&
            !simplify_locals_subtree_has_branch_to_label(
              func, value_id, target_label,
            ) &&
            !simplify_locals_subtree_has_typed_control(func, value_id)
          if allowed {
            for trailing_id in trailing_roots {
              if !simplify_locals_root_allows_moving_local_set_value_after(
                  func, trailing_id, local_id, target_label,
                ) {
                allowed = false
                break
              }
            }
          }
          if allowed {
            candidates.push({ root_idx: idx, node_id, local_id, value_id })
          }
          trailing_roots.push(node_id)
        }
        _ => trailing_roots.push(node_id)
      }
    }
    idx = idx - 1
  }
  candidates
}

///|
fn simplify_locals_following_root_local_get_order(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  after_idx : Int,
) -> Array[Int] {
  let order : Array[Int] = []
  let seen = Array::make(@ir.hot_local_count(func), false)
  for idx = after_idx + 1
      idx < @ir.hot_region_root_count(func, region_ref)
      idx = idx + 1 {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Nop => ()
      @ir.HotOp::LocalGet =>
        if node.imm0 >= 0 && node.imm0 < seen.length() && !seen[node.imm0] {
          seen[node.imm0] = true
          order.push(node.imm0)
        }
      _ => ()
    }
  }
  order
}

///|
fn simplify_locals_find_branch_exit_set_for_local(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  br_idx : Int,
  target_label : Int,
  local_id : Int,
) -> SimplifyLocalsBranchExit? {
  let br_id = @ir.hot_region_get(func, region_ref, br_idx)
  let mut idx = br_idx - 1
  while idx >= 0 {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
      idx = idx - 1
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Nop => ()
      @ir.HotOp::LocalSet if node.imm0 == local_id => {
        let value_id = @ir.hot_child_get(func, node_id, 0)
        if !simplify_locals_value_is_pure(func, value_id) ||
          simplify_locals_subtree_has_branch_to_label(
            func, value_id, target_label,
          ) ||
          simplify_locals_subtree_has_typed_control(func, value_id) {
          return None
        }
        return Some({
          region_ref,
          set_idx: idx,
          set_id: node_id,
          br_id,
          local_id,
          value_id,
        })
      }
      _ =>
        if !simplify_locals_root_allows_moving_local_set_value_after(
            func, node_id, local_id, target_label,
          ) {
          return None
        }
    }
    idx = idx - 1
  }
  None
}

///|
fn simplify_locals_node_is_nonfallthrough_exit(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Unreachable
    | @ir.HotOp::Br
    | @ir.HotOp::BrTable
    | @ir.HotOp::Return
    | @ir.HotOp::Throw
    | @ir.HotOp::Rethrow
    | @ir.HotOp::ThrowRef
    | @ir.HotOp::Delegate => true
    _ => false
  }
}

///|
fn simplify_locals_region_is_unreachableish(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  match simplify_locals_region_last_live_non_nop_root_idx(func, region_ref) {
    Some(root_idx) =>
      simplify_locals_node_is_nonfallthrough_exit(
        func,
        @ir.hot_region_get(func, region_ref, root_idx),
      )
    None => false
  }
}

///|
fn simplify_locals_control_has_typed_branch_payload(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  @ir.hot_label_branch_arity(func, @ir.hot_control_node_label(func, node_id)) !=
  0
}

///|
fn simplify_locals_node_targets_label(
  func : @ir.HotFunc,
  node_id : Int,
  label_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::BrTable =>
      if @ir.hot_branch_table_default_target(func, node.imm0) == label_id {
        true
      } else {
        let targets = @ir.hot_branch_table_targets_for_node(func, node_id)
        for target in targets {
          if target == label_id {
            return true
          }
        }
        false
      }
    _ => @ir.hot_branch_target(func, node_id) == Some(label_id)
  }
}

///|
fn simplify_locals_value_can_clone_node(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  node_id < 0 ||
  !@ir.hot_node_is_live(func, node_id) ||
  !@ir.hot_node_kind_is_control(func, node_id)
}

///|
fn simplify_locals_value_can_move_one_use(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if simplify_locals_value_can_clone_node(func, node_id) {
    return true
  }
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return true
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::If => ()
    _ => return false
  }
  if @ir.hot_node_result_arity(func, node_id) != 1 {
    return false
  }
  if @ir.hot_child_count(func, node_id) <= 0 {
    return false
  }
  let cond_id = @ir.hot_child_get(func, node_id, 0)
  cond_id < 0 ||
  !@ir.hot_node_is_live(func, cond_id) ||
  (
    !@ir.hot_node_kind_is_control(func, cond_id) &&
    @ir.hot_node_result_arity(func, cond_id) == 1
  )
}

///|
fn simplify_locals_value_can_tee(func : @ir.HotFunc, node_id : Int) -> Bool {
  node_id < 0 ||
  !@ir.hot_node_is_live(func, node_id) ||
  @ir.hot_node_result_arity(func, node_id) == 1
}

///|
fn simplify_locals_try_consume_following_local_get(
  func : @ir.HotFunc,
  parent_region : @ir.HotRegionRef,
  root_idx : Int,
  local_id : Int,
  detached : Array[Int],
) -> Bool {
  let next_idx = match
    simplify_locals_region_next_live_non_nop_root_idx(
      func, parent_region, root_idx,
    ) {
    Some(next_idx) => next_idx
    None => return false
  }
  let next_id = @ir.hot_region_get(func, parent_region, next_idx)
  if next_id < 0 || !@ir.hot_node_is_live(func, next_id) {
    return false
  }
  let next = @ir.hot_node_get(func, next_id)
  match next.op {
    @ir.HotOp::LocalGet if next.imm0 == local_id => {
      let removed = @ir.hot_region_splice(func, parent_region, next_idx, 1, [])
      for removed_id in removed {
        detached.push(removed_id)
      }
      true
    }
    _ => false
  }
}

///|
fn simplify_locals_try_inline_local_get_child(
  func : @ir.HotFunc,
  node_id : Int,
  local_id : Int,
  replacement_id : Int,
  detached : Array[Int],
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    let child_id = @ir.hot_child_get(func, node_id, slot)
    if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
      continue
    }
    let child = @ir.hot_node_get(func, child_id)
    match child.op {
      @ir.HotOp::LocalGet if child.imm0 == local_id => {
        @ir.hot_child_set(func, node_id, slot, replacement_id)
        detached.push(child_id)
        return true
      }
      _ =>
        if simplify_locals_try_inline_local_get_child(
            func, child_id, local_id, replacement_id, detached,
          ) {
          return true
        }
    }
  }
  false
}

///|
fn simplify_locals_try_inline_following_local_get(
  func : @ir.HotFunc,
  parent_region : @ir.HotRegionRef,
  root_idx : Int,
  local_id : Int,
  replacement_id : Int,
  detached : Array[Int],
) -> Bool {
  let next_idx = match
    simplify_locals_region_next_live_non_nop_root_idx(
      func, parent_region, root_idx,
    ) {
    Some(next_idx) => next_idx
    None => return false
  }
  simplify_locals_try_inline_local_get_child(
    func,
    @ir.hot_region_get(func, parent_region, next_idx),
    local_id,
    replacement_id,
    detached,
  )
}

///|
fn simplify_locals_count_local_gets(func : @ir.HotFunc) -> Array[Int] {
  let counts = Array::make(@ir.hot_local_count(func), 0)
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::LocalGet =>
        if node.imm0 >= 0 && node.imm0 < counts.length() {
          counts[node.imm0] = counts[node.imm0] + 1
        }
      _ => ()
    }
  }
  counts
}

///|
fn simplify_locals_value_is_pure(func : @ir.HotFunc, node_id : Int) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return true
  }
  let node = @ir.hot_node_get(func, node_id)
  let op_is_pure = match node.op {
    @ir.HotOp::Nop
    | @ir.HotOp::Const
    | @ir.HotOp::LocalGet
    | @ir.HotOp::GlobalGet
    | @ir.HotOp::Drop
    | @ir.HotOp::Select
    | @ir.HotOp::RefNull
    | @ir.HotOp::RefIsNull
    | @ir.HotOp::RefFunc
    | @ir.HotOp::RefTest
    | @ir.HotOp::RefTestDesc
    | @ir.HotOp::Unary
    | @ir.HotOp::Binary
    | @ir.HotOp::Compare
    | @ir.HotOp::TupleMake
    | @ir.HotOp::TupleExtract
    | @ir.HotOp::StringOp
    | @ir.HotOp::MemorySize
    | @ir.HotOp::TableSize
    | @ir.HotOp::Simd => true
    _ => false
  }
  if !op_is_pure {
    return false
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    let child_id = @ir.hot_child_get(func, node_id, slot)
    if child_id >= 0 &&
      @ir.hot_node_is_live(func, child_id) &&
      !simplify_locals_value_is_pure(func, child_id) {
      return false
    }
  }
  true
}

///|
fn simplify_locals_mark_reachable(
  func : @ir.HotFunc,
  node_id : Int,
  reachable : Array[Bool],
) -> Unit {
  if node_id < 0 ||
    node_id >= reachable.length() ||
    !@ir.hot_node_is_live(func, node_id) ||
    reachable[node_id] {
    return
  }
  reachable[node_id] = true
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    simplify_locals_mark_reachable(
      func,
      @ir.hot_child_get(func, node_id, slot),
      reachable,
    )
  }
}

///|
fn simplify_locals_build_reachable_nodes(func : @ir.HotFunc) -> Array[Bool] {
  let reachable = Array::make(@ir.hot_node_count(func), false)
  for root_idx = 0; root_idx < @ir.hot_root_count(func); root_idx = root_idx + 1 {
    simplify_locals_mark_reachable(
      func,
      @ir.hot_root_get(func, root_idx),
      reachable,
    )
  }
  reachable
}

///|
fn simplify_locals_build_label_owner_nodes(func : @ir.HotFunc) -> Array[Bool] {
  let label_owners = Array::make(@ir.hot_node_count(func), false)
  for label_id = 0; label_id < func.labels.length(); label_id = label_id + 1 {
    let owner = @ir.hot_label_owner(func, label_id)
    if owner >= 0 &&
      owner < label_owners.length() &&
      @ir.hot_node_is_live(func, owner) {
      label_owners[owner] = true
    }
  }
  label_owners
}

///|
priv struct SimplifyLocalsDetachedControlOwner {
  replacement_id : Int
  detached_id : Int
}

///|
fn simplify_locals_rehome_detached_control_owners(
  func : @ir.HotFunc,
  owners : Array[SimplifyLocalsDetachedControlOwner],
) -> Unit {
  for owner in owners {
    if owner.replacement_id < 0 ||
      !@ir.hot_node_is_live(func, owner.replacement_id) {
      continue
    }
    if owner.detached_id < 0 || !@ir.hot_node_is_live(func, owner.detached_id) {
      continue
    }
    let detached = @ir.hot_node_get(func, owner.detached_id)
    let label_id = match detached.op {
      @ir.HotOp::Block
      | @ir.HotOp::Loop
      | @ir.HotOp::If
      | @ir.HotOp::Try
      | @ir.HotOp::TryTable =>
        @ir.hot_control_node_label(func, owner.detached_id)
      _ => continue
    }
    @ir.hot_label_owner_set(func, label_id, owner.replacement_id)
  }
}

///|
fn simplify_locals_delete_detached_nodes(
  func : @ir.HotFunc,
  node_ids : Array[Int],
) -> Unit {
  if node_ids.is_empty() {
    return
  }
  let reachable = simplify_locals_build_reachable_nodes(func)
  let label_owners = simplify_locals_build_label_owner_nodes(func)
  let seen = Array::make(@ir.hot_node_count(func), false)
  for node_id in node_ids {
    if node_id < 0 || node_id >= reachable.length() || seen[node_id] {
      continue
    }
    seen[node_id] = true
    if !@ir.hot_node_is_live(func, node_id) ||
      reachable[node_id] ||
      label_owners[node_id] {
      continue
    }
    @ir.hot_delete_detached_node(func, node_id)
  }
}

///|
fn simplify_locals_record_local_set(
  func : @ir.HotFunc,
  node_id : Int,
  node : @ir.HotNode,
  sinkables : SimplifyLocalsSinkables,
  first_cycle : Bool,
  get_counts : Array[Int],
) -> Bool {
  let local_id = node.imm0
  let mut changed = false
  match simplify_locals_sinkables_get(sinkables, local_id) {
    Some(previous_info) =>
      if @ir.hot_node_is_live(func, previous_info.node_id) {
        let previous_node = @ir.hot_node_get(func, previous_info.node_id)
        match previous_node.op {
          @ir.HotOp::LocalSet => {
            let previous_value_id = @ir.hot_child_get(
              func,
              previous_info.node_id,
              0,
            )
            @ir.hot_replace_node(
              func,
              previous_info.node_id,
              simplify_locals_make_drop(func, previous_value_id),
            )
            changed = true
          }
          _ => ()
        }
      }
    None => ()
  }
  simplify_locals_sinkables_clear_local(sinkables, local_id)
  if first_cycle && get_counts[local_id] > 1 {
    return changed
  }
  simplify_locals_sinkables_set(sinkables, local_id, {
    node_id,
    effects: simplify_locals_effects_for_pending_local_set(
      func, node_id, node, sinkables,
    ),
  })
  changed
}

///|
fn simplify_locals_scan_region(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  sinkables : SimplifyLocalsSinkables,
  first_cycle : Bool,
  get_counts : Array[Int],
  detached : Array[Int],
) -> Bool {
  let mut changed = false
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    if simplify_locals_scan_node(
        func, node_id, sinkables, first_cycle, get_counts, detached,
      ) {
      changed = true
    }
  }
  changed
}

///|
fn simplify_locals_scan_node(
  func : @ir.HotFunc,
  node_id : Int,
  sinkables : SimplifyLocalsSinkables,
  first_cycle : Bool,
  get_counts : Array[Int],
  detached : Array[Int],
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let mut changed = false
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Block => {
      if simplify_locals_scan_region(
          func,
          @ir.hot_region_body_ref(func, node_id),
          sinkables,
          first_cycle,
          get_counts,
          detached,
        ) {
        changed = true
      }
      let body_ref = @ir.hot_region_body_ref(func, node_id)
      let keep_sinkables = @ir.hot_node_result_arity(func, node_id) == 0 &&
        simplify_locals_region_last_live_non_nop_root_idx(func, body_ref)
        is None
      if !keep_sinkables {
        simplify_locals_clear_sinkables(sinkables)
      }
      return changed
    }
    @ir.HotOp::Loop => {
      let loop_sinkables = simplify_locals_new_sinkables(func)
      if simplify_locals_scan_region(
          func,
          @ir.hot_region_body_ref(func, node_id),
          loop_sinkables,
          first_cycle,
          get_counts,
          detached,
        ) {
        changed = true
      }
      simplify_locals_clear_sinkables(sinkables)
      return changed
    }
    @ir.HotOp::If => {
      let condition_id = @ir.hot_child_get(func, node_id, 0)
      if simplify_locals_scan_node(
          func, condition_id, sinkables, first_cycle, get_counts, detached,
        ) {
        changed = true
      }
      simplify_locals_clear_sinkables(sinkables)
      let then_sinkables = simplify_locals_new_sinkables(func)
      if simplify_locals_scan_region(
          func,
          @ir.hot_region_then_ref(func, node_id),
          then_sinkables,
          first_cycle,
          get_counts,
          detached,
        ) {
        changed = true
      }
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) => {
          let else_sinkables = simplify_locals_new_sinkables(func)
          if simplify_locals_scan_region(
              func, else_ref, else_sinkables, first_cycle, get_counts, detached,
            ) {
            changed = true
          }
        }
        None => ()
      }
      simplify_locals_clear_sinkables(sinkables)
      return changed
    }
    @ir.HotOp::Try => {
      let body_sinkables = simplify_locals_new_sinkables(func)
      if simplify_locals_scan_region(
          func,
          @ir.hot_region_body_ref(func, node_id),
          body_sinkables,
          first_cycle,
          get_counts,
          detached,
        ) {
        changed = true
      }
      match @ir.hot_region_catch_ref(func, node_id) {
        Some(catch_ref) => {
          let catch_sinkables = simplify_locals_new_sinkables(func)
          if simplify_locals_scan_region(
              func, catch_ref, catch_sinkables, first_cycle, get_counts, detached,
            ) {
            changed = true
          }
        }
        None => ()
      }
      simplify_locals_clear_sinkables(sinkables)
      return changed
    }
    @ir.HotOp::TryTable => {
      let body_sinkables = simplify_locals_new_sinkables(func)
      if simplify_locals_scan_region(
          func,
          @ir.hot_region_body_ref(func, node_id),
          body_sinkables,
          first_cycle,
          get_counts,
          detached,
        ) {
        changed = true
      }
      let catch_sinkables = simplify_locals_new_sinkables(func)
      if simplify_locals_scan_region(
          func,
          @ir.hot_region_catch_list_ref(func, node_id),
          catch_sinkables,
          first_cycle,
          get_counts,
          detached,
        ) {
        changed = true
      }
      simplify_locals_clear_sinkables(sinkables)
      return changed
    }
    _ =>
      for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
        let child_id = @ir.hot_child_get(func, node_id, slot)
        let scan_child_id = match node.op {
          @ir.HotOp::Drop if slot == 0 &&
            child_id >= 0 &&
            @ir.hot_node_is_live(func, child_id) =>
            match @ir.hot_node_get(func, child_id).op {
              @ir.HotOp::LocalTee => @ir.hot_child_get(func, child_id, 0)
              _ => child_id
            }
          _ => child_id
        }
        if scan_child_id < 0 || !@ir.hot_node_is_live(func, scan_child_id) {
          continue
        }
        if simplify_locals_scan_node(
            func, scan_child_id, sinkables, first_cycle, get_counts, detached,
          ) {
          changed = true
        }
      }
  }

  let mut current = @ir.hot_node_get(func, node_id)
  match current.op {
    @ir.HotOp::LocalGet => {
      let local_id = current.imm0
      match simplify_locals_sinkables_get(sinkables, local_id) {
        Some(info) =>
          if @ir.hot_node_is_live(func, info.node_id) {
            let pending_node = @ir.hot_node_get(func, info.node_id)
            match pending_node.op {
              @ir.HotOp::LocalSet => {
                let value_id = @ir.hot_child_get(func, info.node_id, 0)
                let one_use = first_cycle || get_counts[local_id] == 1
                if one_use &&
                  simplify_locals_value_can_move_one_use(func, value_id) {
                  @ir.hot_replace_node(
                    func,
                    node_id,
                    @ir.hot_node_get(func, value_id),
                  )
                  detached.push(value_id)
                } else if !one_use &&
                  simplify_locals_value_can_tee(func, value_id) {
                  @ir.hot_replace_node(
                    func,
                    node_id,
                    simplify_locals_make_local_tee(func, local_id, value_id),
                  )
                } else {
                  simplify_locals_sinkables_clear_local(sinkables, local_id)
                  simplify_locals_invalidate_sinkables(
                    func, node_id, current, sinkables,
                  )
                  return changed
                }
                @ir.hot_replace_node(
                  func,
                  info.node_id,
                  simplify_locals_make_nop(func),
                )
                simplify_locals_sinkables_clear_local(sinkables, local_id)
                changed = true
              }
              _ => simplify_locals_sinkables_clear_local(sinkables, local_id)
            }
          } else {
            simplify_locals_sinkables_clear_local(sinkables, local_id)
          }
        None => ()
      }
      simplify_locals_invalidate_sinkables(func, node_id, current, sinkables)
      return changed
    }
    _ => ()
  }

  match current.op {
    @ir.HotOp::Drop => {
      let child_id = @ir.hot_child_get(func, node_id, 0)
      if child_id >= 0 && @ir.hot_node_is_live(func, child_id) {
        let child = @ir.hot_node_get(func, child_id)
        match child.op {
          @ir.HotOp::LocalTee => {
            let value_id = @ir.hot_child_get(func, child_id, 0)
            @ir.hot_replace_node(
              func,
              node_id,
              simplify_locals_make_local_set(func, child.imm0, value_id),
            )
            detached.push(child_id)
            changed = true
          }
          _ => ()
        }
      }
    }
    _ => ()
  }

  current = @ir.hot_node_get(func, node_id)
  match current.op {
    @ir.HotOp::LocalSet => {
      simplify_locals_invalidate_sinkables(
        func,
        node_id,
        current,
        sinkables,
        skip_local=current.imm0,
      )
      if simplify_locals_record_local_set(
          func, node_id, current, sinkables, first_cycle, get_counts,
        ) {
        changed = true
      }
      changed
    }
    _ => {
      simplify_locals_invalidate_sinkables(func, node_id, current, sinkables)
      changed
    }
  }
}

///|
fn simplify_locals_collect_block_branch_exits(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  target_label : Int,
  local_id : Int,
  exits : Array[SimplifyLocalsBranchExit],
) -> Bool {
  let last_idx = simplify_locals_region_last_live_non_nop_root_idx(
    func, region_ref,
  )
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    if simplify_locals_node_targets_label(func, node_id, target_label) {
      let node = @ir.hot_node_get(func, node_id)
      match node.op {
        @ir.HotOp::Br => {
          if node.child_count != 0 || last_idx != Some(idx) {
            return false
          }
          match
            simplify_locals_find_branch_exit_set_for_local(
              func, region_ref, idx, target_label, local_id,
            ) {
            Some(exit) => exits.push(exit)
            None => return false
          }
        }
        _ => return false
      }
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    if !@ir.hot_node_kind_is_control(func, node_id) {
      if simplify_locals_subtree_has_branch_to_label(
          func, node_id, target_label,
        ) {
        return false
      }
      continue
    }
    match node.op {
      @ir.HotOp::Block | @ir.HotOp::Loop => {
        let body_ref = @ir.hot_region_body_ref(func, node_id)
        match node.op {
          @ir.HotOp::Loop => {
            let input_count = @ir.hot_label_branch_arity(
              func,
              @ir.hot_control_node_label(func, node_id),
            )
            for child_idx = 0
                child_idx < input_count
                child_idx = child_idx + 1 {
              if simplify_locals_subtree_has_branch_to_label(
                  func,
                  @ir.hot_child_get(func, node_id, child_idx),
                  target_label,
                ) {
                return false
              }
            }
          }
          _ => ()
        }
        if simplify_locals_control_has_typed_branch_payload(func, node_id) &&
          simplify_locals_region_has_branch_to_label(
            func, body_ref, target_label,
          ) {
          return false
        }
        if !simplify_locals_collect_block_branch_exits(
            func, body_ref, target_label, local_id, exits,
          ) {
          return false
        }
      }
      @ir.HotOp::If => {
        if simplify_locals_subtree_has_branch_to_label(
            func,
            @ir.hot_child_get(func, node_id, 0),
            target_label,
          ) {
          return false
        }
        let then_ref = @ir.hot_region_then_ref(func, node_id)
        if simplify_locals_control_has_typed_branch_payload(func, node_id) &&
          simplify_locals_region_has_branch_to_label(
            func, then_ref, target_label,
          ) {
          return false
        }
        if !simplify_locals_collect_block_branch_exits(
            func, then_ref, target_label, local_id, exits,
          ) {
          return false
        }
        match @ir.hot_region_else_ref(func, node_id) {
          Some(else_ref) => {
            if simplify_locals_control_has_typed_branch_payload(func, node_id) &&
              simplify_locals_region_has_branch_to_label(
                func, else_ref, target_label,
              ) {
              return false
            }
            if !simplify_locals_collect_block_branch_exits(
                func, else_ref, target_label, local_id, exits,
              ) {
              return false
            }
          }
          None => ()
        }
      }
      @ir.HotOp::Try => {
        let body_ref = @ir.hot_region_body_ref(func, node_id)
        if simplify_locals_control_has_typed_branch_payload(func, node_id) &&
          simplify_locals_region_has_branch_to_label(
            func, body_ref, target_label,
          ) {
          return false
        }
        if !simplify_locals_collect_block_branch_exits(
            func, body_ref, target_label, local_id, exits,
          ) {
          return false
        }
        match @ir.hot_region_catch_ref(func, node_id) {
          Some(catch_ref) => {
            if simplify_locals_control_has_typed_branch_payload(func, node_id) &&
              simplify_locals_region_has_branch_to_label(
                func, catch_ref, target_label,
              ) {
              return false
            }
            if !simplify_locals_collect_block_branch_exits(
                func, catch_ref, target_label, local_id, exits,
              ) {
              return false
            }
          }
          None => ()
        }
      }
      @ir.HotOp::TryTable => {
        let body_ref = @ir.hot_region_body_ref(func, node_id)
        let catch_list_ref = @ir.hot_region_catch_list_ref(func, node_id)
        if simplify_locals_control_has_typed_branch_payload(func, node_id) &&
          (
            simplify_locals_region_has_branch_to_label(
              func, body_ref, target_label,
            ) ||
            simplify_locals_region_has_branch_to_label(
              func, catch_list_ref, target_label,
            )
          ) {
          return false
        }
        if !simplify_locals_collect_block_branch_exits(
            func, body_ref, target_label, local_id, exits,
          ) ||
          !simplify_locals_collect_block_branch_exits(
            func, catch_list_ref, target_label, local_id, exits,
          ) {
          return false
        }
      }
      _ => ()
    }
  }
  true
}

///|
fn simplify_locals_try_apply_block_return_candidate(
  func : @ir.HotFunc,
  node_id : Int,
  label_id : Int,
  candidate : SimplifyLocalsTailSet,
  detached : Array[Int],
) -> Bool {
  let body_ref = @ir.hot_region_body_ref(func, node_id)
  let exits : Array[SimplifyLocalsBranchExit] = []
  if !simplify_locals_collect_block_branch_exits(
      func,
      body_ref,
      label_id,
      candidate.local_id,
      exits,
    ) ||
    exits.is_empty() {
    return false
  }
  let last_live_idx = simplify_locals_region_last_live_non_nop_root_idx(
    func, body_ref,
  )
  if last_live_idx == Some(candidate.root_idx) {
    ignore(
      @ir.hot_region_set(func, body_ref, candidate.root_idx, candidate.value_id),
    )
  } else {
    ignore(
      @ir.hot_region_set(
        func,
        body_ref,
        candidate.root_idx,
        @ir.hot_build_nop(func),
      ),
    )
    @ir.hot_region_insert(
      func,
      body_ref,
      match last_live_idx {
        Some(last_idx) => last_idx + 1
        None => @ir.hot_region_root_count(func, body_ref)
      },
      [candidate.value_id],
    )
  }
  detached.push(candidate.node_id)
  for exit in exits {
    ignore(
      @ir.hot_region_set(
        func,
        exit.region_ref,
        exit.set_idx,
        @ir.hot_build_nop(func),
      ),
    )
    ignore(@ir.hot_replace_child_span(func, exit.br_id, [exit.value_id]))
    detached.push(exit.set_id)
  }
  @ir.hot_control_result_type_set(
    func,
    node_id,
    simplify_locals_local_type_id(func, candidate.local_id, candidate.value_id),
  )
  true
}

///|
fn simplify_locals_region_has_branch_to_label(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  target_label : Int,
) -> Bool {
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    if simplify_locals_node_targets_label(func, node_id, target_label) {
      return true
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Block | @ir.HotOp::Loop =>
        if simplify_locals_region_has_branch_to_label(
            func,
            @ir.hot_region_body_ref(func, node_id),
            target_label,
          ) {
          return true
        }
      @ir.HotOp::If => {
        if simplify_locals_region_has_branch_to_label(
            func,
            @ir.hot_region_then_ref(func, node_id),
            target_label,
          ) {
          return true
        }
        match @ir.hot_region_else_ref(func, node_id) {
          Some(else_ref) =>
            if simplify_locals_region_has_branch_to_label(
                func, else_ref, target_label,
              ) {
              return true
            }
          None => ()
        }
      }
      @ir.HotOp::Try => {
        if simplify_locals_region_has_branch_to_label(
            func,
            @ir.hot_region_body_ref(func, node_id),
            target_label,
          ) {
          return true
        }
        match @ir.hot_region_catch_ref(func, node_id) {
          Some(catch_ref) =>
            if simplify_locals_region_has_branch_to_label(
                func, catch_ref, target_label,
              ) {
              return true
            }
          None => ()
        }
      }
      @ir.HotOp::TryTable =>
        if simplify_locals_region_has_branch_to_label(
            func,
            @ir.hot_region_body_ref(func, node_id),
            target_label,
          ) ||
          simplify_locals_region_has_branch_to_label(
            func,
            @ir.hot_region_catch_list_ref(func, node_id),
            target_label,
          ) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn simplify_locals_subtree_has_branch_to_label(
  func : @ir.HotFunc,
  node_id : Int,
  target_label : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  if simplify_locals_node_targets_label(func, node_id, target_label) {
    return true
  }
  for child_idx = 0
      child_idx < @ir.hot_child_count(func, node_id)
      child_idx = child_idx + 1 {
    if simplify_locals_subtree_has_branch_to_label(
        func,
        @ir.hot_child_get(func, node_id, child_idx),
        target_label,
      ) {
      return true
    }
  }
  false
}

///|
fn simplify_locals_subtree_has_typed_control(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  if @ir.hot_node_kind_is_control(func, node_id) &&
    @ir.hot_node_result_arity(func, node_id) != 0 {
    return true
  }
  for child_idx = 0
      child_idx < @ir.hot_child_count(func, node_id)
      child_idx = child_idx + 1 {
    if simplify_locals_subtree_has_typed_control(
        func,
        @ir.hot_child_get(func, node_id, child_idx),
      ) {
      return true
    }
  }
  false
}

///|
fn simplify_locals_try_rewrite_block_return(
  func : @ir.HotFunc,
  parent_region : @ir.HotRegionRef,
  root_idx : Int,
  node_id : Int,
  get_counts : Array[Int],
  detached : Array[Int],
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Block => ()
    _ => return false
  }
  if @ir.hot_node_result_arity(func, node_id) != 0 {
    return false
  }
  let body_ref = @ir.hot_region_body_ref(func, node_id)
  let label_id = @ir.hot_control_node_label(func, node_id)
  let candidates = simplify_locals_collect_block_return_candidates(
    func, body_ref, label_id, get_counts,
  )
  if candidates.is_empty() {
    return false
  }
  let preferred_locals = simplify_locals_following_root_local_get_order(
    func, parent_region, root_idx,
  )
  for preferred_local in preferred_locals {
    for candidate in candidates {
      if candidate.local_id != preferred_local {
        continue
      }
      if simplify_locals_try_apply_block_return_candidate(
          func, node_id, label_id, candidate, detached,
        ) {
        if get_counts[candidate.local_id] == 1 &&
          (
            simplify_locals_try_consume_following_local_get(
              func,
              parent_region,
              root_idx,
              candidate.local_id,
              detached,
            ) ||
            simplify_locals_try_inline_following_local_get(
              func,
              parent_region,
              root_idx,
              candidate.local_id,
              node_id,
              detached,
            )
          ) {
          return true
        }
        ignore(
          @ir.hot_region_set(
            func,
            parent_region,
            root_idx,
            @ir.hot_build_local_set(func, candidate.local_id, node_id),
          ),
        )
        return true
      }
    }
  }
  let mut candidate_idx = candidates.length() - 1
  while candidate_idx >= 0 {
    let candidate = candidates[candidate_idx]
    if simplify_locals_try_apply_block_return_candidate(
        func, node_id, label_id, candidate, detached,
      ) {
      if get_counts[candidate.local_id] == 1 &&
        (
          simplify_locals_try_consume_following_local_get(
            func,
            parent_region,
            root_idx,
            candidate.local_id,
            detached,
          ) ||
          simplify_locals_try_inline_following_local_get(
            func,
            parent_region,
            root_idx,
            candidate.local_id,
            node_id,
            detached,
          )
        ) {
        return true
      }
      ignore(
        @ir.hot_region_set(
          func,
          parent_region,
          root_idx,
          @ir.hot_build_local_set(func, candidate.local_id, node_id),
        ),
      )
      return true
    }
    candidate_idx = candidate_idx - 1
  }
  false
}

///|
fn simplify_locals_try_rewrite_if_return(
  func : @ir.HotFunc,
  parent_region : @ir.HotRegionRef,
  root_idx : Int,
  node_id : Int,
  get_counts : Array[Int],
  detached : Array[Int],
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::If => ()
    _ => return false
  }
  if @ir.hot_node_result_arity(func, node_id) != 0 {
    return false
  }
  let then_ref = @ir.hot_region_then_ref(func, node_id)
  let then_tail = simplify_locals_region_tail_local_set(func, then_ref)
  let then_unreachable = simplify_locals_region_is_unreachableish(
    func, then_ref,
  )
  match @ir.hot_region_else_ref(func, node_id) {
    Some(else_ref) => {
      let else_tail = simplify_locals_region_tail_local_set(func, else_ref)
      let else_unreachable = simplify_locals_region_is_unreachableish(
        func, else_ref,
      )
      let chosen_local = if then_unreachable {
        match else_tail {
          Some(tail) => tail.local_id
          None => return false
        }
      } else if else_unreachable {
        match then_tail {
          Some(tail) => tail.local_id
          None => return false
        }
      } else {
        match (then_tail, else_tail) {
          (Some(then_tail), Some(else_tail)) if then_tail.local_id ==
            else_tail.local_id => then_tail.local_id
          _ => return false
        }
      }
      if chosen_local < 0 ||
        chosen_local >= get_counts.length() ||
        get_counts[chosen_local] == 0 {
        return false
      }
      let fallback_value = if then_unreachable {
        else_tail.unwrap().value_id
      } else {
        then_tail.unwrap().value_id
      }
      if (
          !then_unreachable &&
          simplify_locals_subtree_has_typed_control(
            func,
            then_tail.unwrap().value_id,
          )
        ) ||
        (
          !else_unreachable &&
          simplify_locals_subtree_has_typed_control(
            func,
            else_tail.unwrap().value_id,
          )
        ) {
        return false
      }
      if !then_unreachable {
        let tail = then_tail.unwrap()
        ignore(@ir.hot_region_set(func, then_ref, tail.root_idx, tail.value_id))
        detached.push(tail.node_id)
      }
      if !else_unreachable {
        let tail = else_tail.unwrap()
        ignore(@ir.hot_region_set(func, else_ref, tail.root_idx, tail.value_id))
        detached.push(tail.node_id)
      }
      @ir.hot_control_result_type_set(
        func,
        node_id,
        simplify_locals_local_type_id(func, chosen_local, fallback_value),
      )
      if get_counts[chosen_local] == 1 &&
        simplify_locals_try_consume_following_local_get(
          func, parent_region, root_idx, chosen_local, detached,
        ) {
        return true
      }
      ignore(
        @ir.hot_region_set(
          func,
          parent_region,
          root_idx,
          @ir.hot_build_local_set(func, chosen_local, node_id),
        ),
      )
      true
    }
    None => {
      let then_tail = match then_tail {
        Some(then_tail) => then_tail
        None => return false
      }
      if then_tail.local_id < 0 ||
        then_tail.local_id >= get_counts.length() ||
        get_counts[then_tail.local_id] == 0 ||
        !simplify_locals_local_type_is_defaultable(func, then_tail.local_id) {
        return false
      }
      if simplify_locals_subtree_has_typed_control(func, then_tail.value_id) {
        return false
      }
      ignore(
        @ir.hot_region_set(
          func,
          then_ref,
          then_tail.root_idx,
          then_tail.value_id,
        ),
      )
      detached.push(then_tail.node_id)
      let result_block_type = match
        @ir.hot_local_type(func, then_tail.local_id) {
        Some(local_type) => @lib.BlockType::val_type(local_type)
        None => return false
      }
      let replacement_if = @ir.hot_build_if(
        func,
        result_block_type,
        @ir.hot_child_get(func, node_id, 0),
        [then_tail.value_id],
        else_body=Some([@ir.hot_build_local_get(func, then_tail.local_id)]),
      )
      @ir.hot_region_replace_body(func, then_ref, [])
      @ir.hot_control_demote_if_to_block(func, node_id, [])
      if get_counts[then_tail.local_id] == 1 &&
        simplify_locals_try_consume_following_local_get(
          func,
          parent_region,
          root_idx,
          then_tail.local_id,
          detached,
        ) {
        ignore(
          @ir.hot_region_set(func, parent_region, root_idx, replacement_if),
        )
        return true
      }
      ignore(
        @ir.hot_region_set(
          func,
          parent_region,
          root_idx,
          @ir.hot_build_local_set(func, then_tail.local_id, replacement_if),
        ),
      )
      true
    }
  }
}

///|
fn simplify_locals_try_rewrite_loop_return(
  func : @ir.HotFunc,
  parent_region : @ir.HotRegionRef,
  root_idx : Int,
  node_id : Int,
  get_counts : Array[Int],
  detached : Array[Int],
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Loop => ()
    _ => return false
  }
  let body_ref = @ir.hot_region_body_ref(func, node_id)
  let tail = match simplify_locals_region_tail_local_set(func, body_ref) {
    Some(tail) => tail
    None => return false
  }
  if tail.local_id < 0 ||
    tail.local_id >= get_counts.length() ||
    get_counts[tail.local_id] == 0 {
    return false
  }
  if simplify_locals_region_has_branch_to_label(
      func,
      body_ref,
      @ir.hot_control_node_label(func, node_id),
    ) {
    return false
  }
  let next_idx = match
    simplify_locals_region_next_live_non_nop_root_idx(
      func, parent_region, root_idx,
    ) {
    Some(next_idx) => next_idx
    None => return false
  }
  let next_id = @ir.hot_region_get(func, parent_region, next_idx)
  if next_id < 0 || !@ir.hot_node_is_live(func, next_id) {
    return false
  }
  let next = @ir.hot_node_get(func, next_id)
  match next.op {
    @ir.HotOp::LocalGet => if next.imm0 != tail.local_id { return false }
    _ => return false
  }
  ignore(
    @ir.hot_region_set(func, body_ref, tail.root_idx, @ir.hot_build_nop(func)),
  )
  detached.push(tail.node_id)
  let replacement_id = if get_counts[tail.local_id] == 1 {
    tail.value_id
  } else if simplify_locals_value_can_tee(func, tail.value_id) {
    @ir.hot_build_local_tee(func, tail.local_id, tail.value_id)
  } else {
    return false
  }
  ignore(@ir.hot_region_set(func, parent_region, next_idx, replacement_id))
  detached.push(next_id)
  true
}

///|
fn simplify_locals_try_rewrite_nested_one_armed_if_child(
  func : @ir.HotFunc,
  parent_id : Int,
  slot : Int,
  child_id : Int,
  get_counts : Array[Int],
  detached : Array[Int],
) -> Bool {
  if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
    return false
  }
  let child = @ir.hot_node_get(func, child_id)
  match child.op {
    @ir.HotOp::If => ()
    _ => return false
  }
  if @ir.hot_node_result_arity(func, child_id) != 0 {
    return false
  }
  match @ir.hot_region_else_ref(func, child_id) {
    Some(_) => return false
    None => ()
  }
  let then_ref = @ir.hot_region_then_ref(func, child_id)
  let then_tail = match simplify_locals_region_tail_local_set(func, then_ref) {
    Some(then_tail) => then_tail
    None => return false
  }
  if then_tail.local_id < 0 ||
    then_tail.local_id >= get_counts.length() ||
    get_counts[then_tail.local_id] == 0 ||
    !simplify_locals_local_type_is_defaultable(func, then_tail.local_id) {
    return false
  }
  if simplify_locals_subtree_has_typed_control(func, then_tail.value_id) {
    return false
  }
  ignore(
    @ir.hot_region_set(func, then_ref, then_tail.root_idx, then_tail.value_id),
  )
  detached.push(then_tail.node_id)
  let result_block_type = match @ir.hot_local_type(func, then_tail.local_id) {
    Some(local_type) => @lib.BlockType::val_type(local_type)
    None => return false
  }
  let replacement_if = @ir.hot_build_if(
    func,
    result_block_type,
    @ir.hot_child_get(func, child_id, 0),
    [then_tail.value_id],
    else_body=Some([@ir.hot_build_local_get(func, then_tail.local_id)]),
  )
  @ir.hot_region_replace_body(func, then_ref, [])
  @ir.hot_control_demote_if_to_block(func, child_id, [])
  @ir.hot_child_set(
    func,
    parent_id,
    slot,
    @ir.hot_build_local_set(func, then_tail.local_id, replacement_if),
  )
  detached.push(child_id)
  true
}

///|
fn simplify_locals_try_rewrite_nested_one_armed_if_children(
  func : @ir.HotFunc,
  node_id : Int,
  get_counts : Array[Int],
  detached : Array[Int],
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    let child_id = @ir.hot_child_get(func, node_id, slot)
    if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
      continue
    }
    if simplify_locals_try_rewrite_nested_one_armed_if_children(
        func, child_id, get_counts, detached,
      ) ||
      simplify_locals_try_rewrite_nested_one_armed_if_child(
        func, node_id, slot, child_id, get_counts, detached,
      ) {
      return true
    }
  }
  false
}

///|
fn simplify_locals_try_structure_rewrite_region(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  get_counts : Array[Int],
  detached : Array[Int],
) -> Bool {
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    if simplify_locals_try_rewrite_nested_one_armed_if_children(
        func, node_id, get_counts, detached,
      ) {
      return true
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Block =>
        if simplify_locals_try_structure_rewrite_region(
            func,
            @ir.hot_region_body_ref(func, node_id),
            get_counts,
            detached,
          ) ||
          simplify_locals_try_rewrite_block_return(
            func, region_ref, idx, node_id, get_counts, detached,
          ) {
          return true
        }
      @ir.HotOp::If => {
        if simplify_locals_try_structure_rewrite_region(
            func,
            @ir.hot_region_then_ref(func, node_id),
            get_counts,
            detached,
          ) {
          return true
        }
        match @ir.hot_region_else_ref(func, node_id) {
          Some(else_ref) =>
            if simplify_locals_try_structure_rewrite_region(
                func, else_ref, get_counts, detached,
              ) {
              return true
            }
          None => ()
        }
        if simplify_locals_try_rewrite_if_return(
            func, region_ref, idx, node_id, get_counts, detached,
          ) {
          return true
        }
      }
      @ir.HotOp::Loop =>
        if simplify_locals_try_structure_rewrite_region(
            func,
            @ir.hot_region_body_ref(func, node_id),
            get_counts,
            detached,
          ) ||
          simplify_locals_try_rewrite_loop_return(
            func, region_ref, idx, node_id, get_counts, detached,
          ) {
          return true
        }
      @ir.HotOp::Try => {
        if simplify_locals_try_structure_rewrite_region(
            func,
            @ir.hot_region_body_ref(func, node_id),
            get_counts,
            detached,
          ) {
          return true
        }
        match @ir.hot_region_catch_ref(func, node_id) {
          Some(catch_ref) =>
            if simplify_locals_try_structure_rewrite_region(
                func, catch_ref, get_counts, detached,
              ) {
              return true
            }
          None => ()
        }
      }
      @ir.HotOp::TryTable =>
        if simplify_locals_try_structure_rewrite_region(
            func,
            @ir.hot_region_body_ref(func, node_id),
            get_counts,
            detached,
          ) ||
          simplify_locals_try_structure_rewrite_region(
            func,
            @ir.hot_region_catch_list_ref(func, node_id),
            get_counts,
            detached,
          ) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn simplify_locals_run_structure_rewrites(
  func : @ir.HotFunc,
  detached : Array[Int],
) -> Bool {
  simplify_locals_try_structure_rewrite_region(
    func,
    @ir.HotRegionRef::root(),
    simplify_locals_count_local_gets(func),
    detached,
  )
}

///|
priv struct SimplifyLocalsEquivalentState {
  rep_of_local : Array[Int]
  members_of_rep : Array[Array[Int]]
}

///|
fn simplify_locals_new_equivalences(
  func : @ir.HotFunc,
) -> SimplifyLocalsEquivalentState {
  let rep_of_local = Array::make(@ir.hot_local_count(func), 0)
  let members_of_rep : Array[Array[Int]] = []
  for local_id = 0
      local_id < @ir.hot_local_count(func)
      local_id = local_id + 1 {
    rep_of_local[local_id] = local_id
    members_of_rep.push([local_id])
  }
  { rep_of_local, members_of_rep }
}

///|
fn simplify_locals_clone_equivalences(
  equivalences : SimplifyLocalsEquivalentState,
) -> SimplifyLocalsEquivalentState {
  let cloned_members : Array[Array[Int]] = []
  for members in equivalences.members_of_rep {
    cloned_members.push(members.copy())
  }
  {
    rep_of_local: equivalences.rep_of_local.copy(),
    members_of_rep: cloned_members,
  }
}

///|
fn simplify_locals_clear_equivalences(
  equivalences : SimplifyLocalsEquivalentState,
) -> Unit {
  for local_id = 0
      local_id < equivalences.rep_of_local.length()
      local_id = local_id + 1 {
    equivalences.rep_of_local[local_id] = local_id
    equivalences.members_of_rep[local_id] = [local_id]
  }
}

///|
fn simplify_locals_reset_equivalent_local(
  equivalences : SimplifyLocalsEquivalentState,
  local_id : Int,
) -> Unit {
  if local_id < 0 || local_id >= equivalences.rep_of_local.length() {
    return
  }
  let rep = equivalences.rep_of_local[local_id]
  if rep < 0 || rep >= equivalences.members_of_rep.length() {
    equivalences.rep_of_local[local_id] = local_id
    equivalences.members_of_rep[local_id] = [local_id]
    return
  }
  let remaining : Array[Int] = []
  for member_id in equivalences.members_of_rep[rep] {
    if member_id != local_id {
      remaining.push(member_id)
    }
  }
  if rep == local_id && !remaining.is_empty() {
    let new_rep = remaining[0]
    equivalences.members_of_rep[new_rep] = remaining
    for member_id in remaining {
      equivalences.rep_of_local[member_id] = new_rep
    }
  } else if rep != local_id {
    equivalences.members_of_rep[rep] = remaining
  }
  equivalences.rep_of_local[local_id] = local_id
  equivalences.members_of_rep[local_id] = [local_id]
}

///|
fn simplify_locals_equivalent_check(
  equivalences : SimplifyLocalsEquivalentState,
  lhs : Int,
  rhs : Int,
) -> Bool {
  lhs >= 0 &&
  rhs >= 0 &&
  lhs < equivalences.rep_of_local.length() &&
  rhs < equivalences.rep_of_local.length() &&
  equivalences.rep_of_local[lhs] == equivalences.rep_of_local[rhs]
}

///|
fn simplify_locals_add_equivalence(
  equivalences : SimplifyLocalsEquivalentState,
  local_id : Int,
  other_local : Int,
) -> Unit {
  if local_id < 0 ||
    other_local < 0 ||
    local_id >= equivalences.rep_of_local.length() ||
    other_local >= equivalences.rep_of_local.length() ||
    local_id == other_local {
    return
  }
  let other_rep = equivalences.rep_of_local[other_local]
  if other_rep < 0 ||
    other_rep >= equivalences.members_of_rep.length() ||
    equivalences.rep_of_local[local_id] == other_rep {
    return
  }
  simplify_locals_reset_equivalent_local(equivalences, local_id)
  equivalences.rep_of_local[local_id] = other_rep
  equivalences.members_of_rep[other_rep].push(local_id)
}

///|
fn simplify_locals_equivalent_local_get_value(
  func : @ir.HotFunc,
  node_id : Int,
) -> Int? {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet => Some(node.imm0)
    _ => None
  }
}

///|
fn simplify_locals_type_env(ctx : HotPassContext) -> @validate.Env? {
  match ctx.module_ctx {
    Some(module_ctx) =>
      Some(@validate.Env::new().with_types(module_ctx.subtypes))
    None => None
  }
}

///|
fn simplify_locals_local_type_is_subtype(
  env : @validate.Env?,
  func : @ir.HotFunc,
  lhs : Int,
  rhs : Int,
) -> Bool {
  let lhs_type = match @ir.hot_local_type(func, lhs) {
    Some(lhs_type) => lhs_type
    None => return false
  }
  let rhs_type = match @ir.hot_local_type(func, rhs) {
    Some(rhs_type) => rhs_type
    None => return false
  }
  if lhs_type == rhs_type {
    return true
  }
  match env {
    Some(env) => @validate.Match::matches(lhs_type, rhs_type, env)
    None => false
  }
}

///|
fn simplify_locals_get_count_ignoring_current(
  get_counts : Array[Int],
  current_local : Int,
  local_id : Int,
) -> Int {
  let count = get_counts[local_id]
  if local_id == current_local && count > 0 {
    count - 1
  } else {
    count
  }
}

///|
fn simplify_locals_pick_best_equivalent_local(
  env : @validate.Env?,
  func : @ir.HotFunc,
  equivalences : SimplifyLocalsEquivalentState,
  get_counts : Array[Int],
  local_id : Int,
) -> Int {
  if local_id < 0 || local_id >= equivalences.rep_of_local.length() {
    return local_id
  }
  let mut best = local_id
  let rep = equivalences.rep_of_local[local_id]
  if rep < 0 || rep >= equivalences.members_of_rep.length() {
    return best
  }
  for candidate in equivalences.members_of_rep[rep] {
    if candidate == best ||
      !simplify_locals_local_type_is_subtype(env, func, candidate, best) {
      continue
    }
    let candidate_type = @ir.hot_local_type(func, candidate)
    let best_type = @ir.hot_local_type(func, best)
    let candidate_has_more_gets = simplify_locals_get_count_ignoring_current(
        get_counts, local_id, candidate,
      ) >
      simplify_locals_get_count_ignoring_current(get_counts, local_id, best)
    if candidate_type != best_type || candidate_has_more_gets {
      best = candidate
    }
  }
  best
}

///|
fn simplify_locals_scan_equivalent_region(
  env : @validate.Env?,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  equivalences : SimplifyLocalsEquivalentState,
  get_counts : Array[Int],
) -> Bool {
  let mut changed = false
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    if simplify_locals_scan_equivalent_node(
        env, func, node_id, equivalences, get_counts,
      ) {
      changed = true
    }
  }
  changed
}

///|
fn simplify_locals_scan_equivalent_current(
  env : @validate.Env?,
  func : @ir.HotFunc,
  node_id : Int,
  equivalences : SimplifyLocalsEquivalentState,
  get_counts : Array[Int],
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => {
      let local_id = node.imm0
      let value_id = @ir.hot_child_get(func, node_id, 0)
      match simplify_locals_equivalent_local_get_value(func, value_id) {
        Some(value_local) =>
          if simplify_locals_equivalent_check(
              equivalences, local_id, value_local,
            ) {
            false
          } else {
            simplify_locals_reset_equivalent_local(equivalences, local_id)
            simplify_locals_add_equivalence(equivalences, local_id, value_local)
            false
          }
        None => {
          simplify_locals_reset_equivalent_local(equivalences, local_id)
          false
        }
      }
    }
    @ir.HotOp::LocalGet => {
      let local_id = node.imm0
      let best = simplify_locals_pick_best_equivalent_local(
        env, func, equivalences, get_counts, local_id,
      )
      if best == local_id ||
        !simplify_locals_local_type_is_subtype(env, func, best, local_id) {
        return false
      }
      let best_type = @ir.hot_local_type(func, best)
      let old_type = @ir.hot_local_type(func, local_id)
      let has_more_gets = simplify_locals_get_count_ignoring_current(
          get_counts, local_id, best,
        ) >
        simplify_locals_get_count_ignoring_current(
          get_counts, local_id, local_id,
        )
      if !has_more_gets && best_type == old_type {
        return false
      }
      @ir.hot_replace_node(
        func,
        node_id,
        simplify_locals_make_local_get(func, best),
      )
      if best >= 0 && best < get_counts.length() {
        get_counts[best] = get_counts[best] + 1
      }
      if local_id >= 0 &&
        local_id < get_counts.length() &&
        get_counts[local_id] > 0 {
        get_counts[local_id] = get_counts[local_id] - 1
      }
      true
    }
    _ => false
  }
}

///|
fn simplify_locals_scan_equivalent_node(
  env : @validate.Env?,
  func : @ir.HotFunc,
  node_id : Int,
  equivalences : SimplifyLocalsEquivalentState,
  get_counts : Array[Int],
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let mut changed = false
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Block => {
      if simplify_locals_scan_equivalent_region(
          env,
          func,
          @ir.hot_region_body_ref(func, node_id),
          equivalences,
          get_counts,
        ) {
        changed = true
      }
      return changed
    }
    @ir.HotOp::If => {
      let condition_id = @ir.hot_child_get(func, node_id, 0)
      if simplify_locals_scan_equivalent_node(
          env, func, condition_id, equivalences, get_counts,
        ) {
        changed = true
      }
      let then_equivalences = simplify_locals_clone_equivalences(equivalences)
      if simplify_locals_scan_equivalent_region(
          env,
          func,
          @ir.hot_region_then_ref(func, node_id),
          then_equivalences,
          get_counts,
        ) {
        changed = true
      }
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) => {
          let else_equivalences = simplify_locals_clone_equivalences(
            equivalences,
          )
          if simplify_locals_scan_equivalent_region(
              env, func, else_ref, else_equivalences, get_counts,
            ) {
            changed = true
          }
        }
        None => ()
      }
      simplify_locals_clear_equivalences(equivalences)
      return changed
    }
    @ir.HotOp::Loop => {
      let loop_equivalences = simplify_locals_new_equivalences(func)
      if simplify_locals_scan_equivalent_region(
          env,
          func,
          @ir.hot_region_body_ref(func, node_id),
          loop_equivalences,
          get_counts,
        ) {
        changed = true
      }
      simplify_locals_clear_equivalences(equivalences)
      return changed
    }
    @ir.HotOp::Try => {
      let body_equivalences = simplify_locals_new_equivalences(func)
      if simplify_locals_scan_equivalent_region(
          env,
          func,
          @ir.hot_region_body_ref(func, node_id),
          body_equivalences,
          get_counts,
        ) {
        changed = true
      }
      match @ir.hot_region_catch_ref(func, node_id) {
        Some(catch_ref) => {
          let catch_equivalences = simplify_locals_new_equivalences(func)
          if simplify_locals_scan_equivalent_region(
              env, func, catch_ref, catch_equivalences, get_counts,
            ) {
            changed = true
          }
        }
        None => ()
      }
      simplify_locals_clear_equivalences(equivalences)
      return changed
    }
    @ir.HotOp::TryTable => {
      let body_equivalences = simplify_locals_new_equivalences(func)
      if simplify_locals_scan_equivalent_region(
          env,
          func,
          @ir.hot_region_body_ref(func, node_id),
          body_equivalences,
          get_counts,
        ) {
        changed = true
      }
      let catch_equivalences = simplify_locals_new_equivalences(func)
      if simplify_locals_scan_equivalent_region(
          env,
          func,
          @ir.hot_region_catch_list_ref(func, node_id),
          catch_equivalences,
          get_counts,
        ) {
        changed = true
      }
      simplify_locals_clear_equivalences(equivalences)
      return changed
    }
    _ =>
      for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
        let child_id = @ir.hot_child_get(func, node_id, slot)
        if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
          continue
        }
        if simplify_locals_scan_equivalent_node(
            env, func, child_id, equivalences, get_counts,
          ) {
          changed = true
        }
      }
  }
  if simplify_locals_scan_equivalent_current(
      env, func, node_id, equivalences, get_counts,
    ) {
    changed = true
  }
  changed
}

///|
fn simplify_locals_run_main_cycle(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  first_cycle : Bool,
  detached : Array[Int],
) -> Bool {
  let sinkables = simplify_locals_new_sinkables(func)
  let count_gets_start_us = perf_start_timer_opt(
    ctx.perf,
    "detail:simplify-locals:count-local-gets",
  )
  let get_counts = simplify_locals_count_local_gets(func)
  perf_stop_timer_opt(
    ctx.perf,
    "detail:simplify-locals:count-local-gets",
    count_gets_start_us,
  )
  let scan_start_us = perf_start_timer_opt(
    ctx.perf,
    "detail:simplify-locals:scan-root-region",
  )
  let changed = simplify_locals_scan_region(
    func,
    @ir.HotRegionRef::root(),
    sinkables,
    first_cycle,
    get_counts,
    detached,
  )
  perf_stop_timer_opt(
    ctx.perf,
    "detail:simplify-locals:scan-root-region",
    scan_start_us,
  )
  changed
}

///|
fn simplify_locals_run_equivalent_cleanup(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> Bool {
  let env = simplify_locals_type_env(ctx)
  simplify_locals_scan_equivalent_region(
    env,
    func,
    @ir.HotRegionRef::root(),
    simplify_locals_new_equivalences(func),
    simplify_locals_count_local_gets(func),
  )
}

///|
fn simplify_locals_equivalent_candidate_count(
  func : @ir.HotFunc,
  stop_after? : Int = -1,
) -> Int {
  let mut count = 0
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => {
        if @ir.hot_child_count(func, node_id) == 0 {
          continue
        }
        let value_id = @ir.hot_child_get(func, node_id, 0)
        if value_id >= 0 && @ir.hot_node_is_live(func, value_id) {
          match @ir.hot_node_get(func, value_id).op {
            @ir.HotOp::LocalGet => {
              count = count + 1
              if stop_after >= 0 && count > stop_after {
                return count
              }
            }
            _ => ()
          }
        }
      }
      _ => ()
    }
  }
  count
}

///|
fn simplify_locals_run_dead_cleanup(
  func : @ir.HotFunc,
  detached : Array[Int],
) -> Bool {
  let get_counts = simplify_locals_count_local_gets(func)
  let mut changed = false
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::LocalSet => {
        let value_id = @ir.hot_child_get(func, node_id, 0)
        if value_id >= 0 && @ir.hot_node_is_live(func, value_id) {
          let value = @ir.hot_node_get(func, value_id)
          match value.op {
            @ir.HotOp::LocalTee if value.imm0 == node.imm0 => {
              @ir.hot_replace_node(
                func,
                node_id,
                simplify_locals_make_local_set(
                  func,
                  node.imm0,
                  @ir.hot_child_get(func, value_id, 0),
                ),
              )
              detached.push(value_id)
              changed = true
              continue
            }
            @ir.HotOp::LocalGet if value.imm0 == node.imm0 => {
              @ir.hot_replace_node(
                func,
                node_id,
                simplify_locals_make_nop(func),
              )
              detached.push(value_id)
              changed = true
              continue
            }
            _ => ()
          }
        }
        if get_counts[node.imm0] != 0 {
          continue
        }
        if simplify_locals_value_is_pure(func, value_id) {
          @ir.hot_replace_node(func, node_id, simplify_locals_make_nop(func))
          detached.push(value_id)
        } else {
          @ir.hot_replace_node(
            func,
            node_id,
            simplify_locals_make_drop(func, value_id),
          )
        }
        changed = true
      }
      @ir.HotOp::LocalTee => {
        let value_id = @ir.hot_child_get(func, node_id, 0)
        if value_id >= 0 && @ir.hot_node_is_live(func, value_id) {
          let value = @ir.hot_node_get(func, value_id)
          match value.op {
            @ir.HotOp::LocalGet if value.imm0 == node.imm0 => {
              @ir.hot_replace_node(
                func,
                node_id,
                @ir.hot_node_get(func, value_id),
              )
              detached.push(value_id)
              changed = true
              continue
            }
            _ => ()
          }
        }
        if get_counts[node.imm0] != 0 {
          continue
        }
        if simplify_locals_value_can_clone_node(func, value_id) {
          @ir.hot_replace_node(func, node_id, @ir.hot_node_get(func, value_id))
          detached.push(value_id)
          changed = true
        }
      }
      _ => ()
    }
  }
  changed
}

///|
fn simplify_locals_run(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> HotPassResult {
  let mut first_cycle = true
  let mut changed = false
  while true {
    let main_cycle_start_us = perf_start_timer_opt(
      ctx.perf,
      "detail:simplify-locals:main-cycle",
    )
    let main_detached : Array[Int] = []
    let main_changed = simplify_locals_run_main_cycle(
      ctx, func, first_cycle, main_detached,
    )
    perf_stop_timer_opt(
      ctx.perf,
      "detail:simplify-locals:main-cycle",
      main_cycle_start_us,
    )
    let main_delete_start_us = perf_start_timer_opt(
      ctx.perf,
      "detail:simplify-locals:delete-main-detached",
    )
    simplify_locals_delete_detached_nodes(func, main_detached)
    perf_stop_timer_opt(
      ctx.perf,
      "detail:simplify-locals:delete-main-detached",
      main_delete_start_us,
    )

    let cleanup_start_us = perf_start_timer_opt(
      ctx.perf,
      "detail:simplify-locals:dead-cleanup",
    )
    let cleanup_detached : Array[Int] = []
    let cleanup_changed = simplify_locals_run_dead_cleanup(
      func, cleanup_detached,
    )
    perf_stop_timer_opt(
      ctx.perf,
      "detail:simplify-locals:dead-cleanup",
      cleanup_start_us,
    )
    let cleanup_delete_start_us = perf_start_timer_opt(
      ctx.perf,
      "detail:simplify-locals:delete-dead-detached",
    )
    simplify_locals_delete_detached_nodes(func, cleanup_detached)
    perf_stop_timer_opt(
      ctx.perf,
      "detail:simplify-locals:delete-dead-detached",
      cleanup_delete_start_us,
    )

    if main_changed || cleanup_changed {
      changed = true
    }
    if first_cycle {
      first_cycle = false
      continue
    }
    if main_changed || cleanup_changed {
      continue
    }

    let structure_start_us = perf_start_timer_opt(
      ctx.perf,
      "detail:simplify-locals:structure",
    )
    let structure_detached : Array[Int] = []
    let structure_changed = simplify_locals_run_structure_rewrites(
      func, structure_detached,
    )
    perf_stop_timer_opt(
      ctx.perf,
      "detail:simplify-locals:structure",
      structure_start_us,
    )
    let structure_delete_start_us = perf_start_timer_opt(
      ctx.perf,
      "detail:simplify-locals:delete-structure-detached",
    )
    simplify_locals_delete_detached_nodes(func, structure_detached)
    perf_stop_timer_opt(
      ctx.perf,
      "detail:simplify-locals:delete-structure-detached",
      structure_delete_start_us,
    )

    if structure_changed {
      changed = true
      continue
    }

    let local_count = @ir.hot_local_count(func)
    if local_count >= 96 {
      break
    }
    let sparse_equivalent_limit = if local_count >= 56 {
      local_count / 6
    } else {
      -1
    }
    let equivalent_candidate_count = simplify_locals_equivalent_candidate_count(
      func,
      stop_after=sparse_equivalent_limit,
    )
    if equivalent_candidate_count == 0 ||
      (
        sparse_equivalent_limit >= 0 &&
        equivalent_candidate_count <= sparse_equivalent_limit
      ) {
      break
    }

    let equivalent_start_us = perf_start_timer_opt(
      ctx.perf,
      "detail:simplify-locals:equivalent-cleanup",
    )
    let late_changed = simplify_locals_run_equivalent_cleanup(ctx, func)
    perf_stop_timer_opt(
      ctx.perf,
      "detail:simplify-locals:equivalent-cleanup",
      equivalent_start_us,
    )
    let late_cleanup_start_us = perf_start_timer_opt(
      ctx.perf,
      "detail:simplify-locals:late-dead-cleanup",
    )
    let late_cleanup_detached : Array[Int] = []
    let late_cleanup_changed = simplify_locals_run_dead_cleanup(
      func, late_cleanup_detached,
    )
    perf_stop_timer_opt(
      ctx.perf,
      "detail:simplify-locals:late-dead-cleanup",
      late_cleanup_start_us,
    )
    let late_delete_start_us = perf_start_timer_opt(
      ctx.perf,
      "detail:simplify-locals:delete-late-detached",
    )
    simplify_locals_delete_detached_nodes(func, late_cleanup_detached)
    perf_stop_timer_opt(
      ctx.perf,
      "detail:simplify-locals:delete-late-detached",
      late_delete_start_us,
    )

    if late_changed || late_cleanup_changed {
      changed = true
      continue
    }
    break
  }
  if !changed {
    return HotPassResult::unchanged()
  }
  pass_mark_mutated(ctx, func)
  HotPassResult::changed()
}
