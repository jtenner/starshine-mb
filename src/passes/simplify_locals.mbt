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
pub fn simplify_locals_nostructure_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new("simplify-locals-nostructure", requires=[], invalidates=[
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
fn simplify_locals_nostructure_alias_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new("simplify-locals-no-structure", requires=[], invalidates=[
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
pub fn simplify_locals_notee_nostructure_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new("simplify-locals-notee-nostructure", requires=[], invalidates=[
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
pub fn simplify_locals_nostructure_summary() -> String {
  "Run the no-structure SimplifyLocals variant: sink local traffic and dead writes without synthesizing block/if/loop result rewrites."
}

///|
pub fn simplify_locals_notee_nostructure_summary() -> String {
  "Run Binaryen's size-biased no-tee/no-structure SimplifyLocals spelling: sink local traffic and dead writes without fresh tees or structure-result rewrites."
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
  value_id : Int
}

///|
priv struct SimplifyLocalsStackedForwarderTail {
  payload_if : Int
  rewrite_region : @ir.HotRegionRef
  rewrite_idx : Int
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
fn simplify_locals_collect_region_local_effects(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  local_reads : Array[Int],
  local_writes : Array[Int],
  read_stamps : Array[Int],
  write_stamps : Array[Int],
  stamp : Int,
) -> Unit {
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    simplify_locals_collect_subtree_local_effects(
      func,
      @ir.hot_region_get(func, region_ref, idx),
      local_reads,
      local_writes,
      read_stamps,
      write_stamps,
      stamp,
    )
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
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::If => {
      simplify_locals_collect_subtree_local_effects(
        func,
        @ir.hot_child_get(func, node_id, 0),
        local_reads,
        local_writes,
        read_stamps,
        write_stamps,
        stamp,
      )
      simplify_locals_collect_region_local_effects(
        func,
        @ir.hot_region_then_ref(func, node_id),
        local_reads,
        local_writes,
        read_stamps,
        write_stamps,
        stamp,
      )
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) =>
          simplify_locals_collect_region_local_effects(
            func, else_ref, local_reads, local_writes, read_stamps, write_stamps,
            stamp,
          )
        None => ()
      }
      return
    }
    @ir.HotOp::Try => {
      simplify_locals_collect_region_local_effects(
        func,
        @ir.hot_region_body_ref(func, node_id),
        local_reads,
        local_writes,
        read_stamps,
        write_stamps,
        stamp,
      )
      match @ir.hot_region_catch_ref(func, node_id) {
        Some(catch_ref) =>
          simplify_locals_collect_region_local_effects(
            func, catch_ref, local_reads, local_writes, read_stamps, write_stamps,
            stamp,
          )
        None => ()
      }
      return
    }
    @ir.HotOp::TryTable => {
      simplify_locals_collect_region_local_effects(
        func,
        @ir.hot_region_body_ref(func, node_id),
        local_reads,
        local_writes,
        read_stamps,
        write_stamps,
        stamp,
      )
      simplify_locals_collect_region_local_effects(
        func,
        @ir.hot_region_catch_list_ref(func, node_id),
        local_reads,
        local_writes,
        read_stamps,
        write_stamps,
        stamp,
      )
      return
    }
    _ => ()
  }
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
    | Some(@lib.Instruction::I64AtomicLoad32U(_))
    | Some(@lib.Instruction::StructAtomicGet(_, _, _))
    | Some(@lib.Instruction::StructAtomicGetS(_, _, _))
    | Some(@lib.Instruction::StructAtomicGetU(_, _, _)) =>
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
    simplify_locals_effects_has(value_mask, @ir.EFFECT_MASK_LOCAL_STATE) {
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
fn simplify_locals_effects_local_state_only(mask : @ir.EffectMask) -> Bool {
  (
    mask &
    (
      @ir.EFFECT_MASK_CALL |
      @ir.EFFECT_MASK_CONTROL |
      @ir.EFFECT_MASK_THROW |
      @ir.EFFECT_MASK_TRAP |
      @ir.EFFECT_MASK_GLOBAL_STATE |
      @ir.EFFECT_MASK_MEMORY_READ |
      @ir.EFFECT_MASK_MEMORY_WRITE |
      @ir.EFFECT_MASK_TABLE_READ |
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
  let lhs_has_call = simplify_locals_effects_has(lhs.mask, @ir.EFFECT_MASK_CALL)
  let rhs_has_call = simplify_locals_effects_has(rhs_mask, @ir.EFFECT_MASK_CALL)
  if lhs_has_call || rhs_has_call {
    let local_state_conflict = simplify_locals_effects_has(
        lhs.mask,
        @ir.EFFECT_MASK_LOCAL_STATE,
      ) &&
      simplify_locals_effects_has(rhs_mask, @ir.EFFECT_MASK_LOCAL_STATE) &&
      simplify_locals_effects_conflict_exact_local(
        lhs, rhs_local_read, rhs_local_write,
      )
    if lhs_has_call &&
      !rhs_has_call &&
      simplify_locals_effects_local_state_only(rhs_mask) &&
      !local_state_conflict {
      ()
    } else if rhs_has_call &&
      !lhs_has_call &&
      simplify_locals_effects_local_state_only(lhs.mask) &&
      !local_state_conflict {
      ()
    } else {
      return true
    }
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
fn simplify_locals_build_one_armed_if_then_body(
  func : @ir.HotFunc,
  then_ref : @ir.HotRegionRef,
  tail_root_idx : Int,
  value_id : Int,
) -> Array[Int] {
  let then_body : Array[Int] = []
  for idx = 0; idx < @ir.hot_region_root_count(func, then_ref); idx = idx + 1 {
    if idx == tail_root_idx {
      then_body.push(@ir.hot_build_nop(func))
      continue
    }
    let root_id = @ir.hot_region_get(func, then_ref, idx)
    if root_id < 0 || !@ir.hot_node_is_live(func, root_id) {
      continue
    }
    then_body.push(root_id)
  }
  then_body.push(value_id)
  then_body
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
fn SimplifyLocalsStackedForwarderTail::new(
  payload_if : Int,
  rewrite_region : @ir.HotRegionRef,
  rewrite_idx : Int,
) -> SimplifyLocalsStackedForwarderTail {
  { payload_if, rewrite_region, rewrite_idx }
}

///|
fn simplify_locals_branch_payload_count(
  func : @ir.HotFunc,
  node_id : Int,
) -> Int {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Br | @ir.HotOp::Delegate => node.child_count
    @ir.HotOp::BrIf
    | @ir.HotOp::BrTable
    | @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail =>
      if node.child_count == 0 {
        0
      } else {
        node.child_count - 1
      }
    _ => 0
  }
}

///|
fn simplify_locals_build_i32_eqz(func : @ir.HotFunc, operand : Int) -> Int {
  @ir.hot_build_select(
    func,
    @lib.ValType::i32(),
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    operand,
  )
}

///|
fn simplify_locals_try_extract_stacked_forwarder_tail(
  func : @ir.HotFunc,
  candidate_node : Int,
  rewrite_region : @ir.HotRegionRef,
  rewrite_idx : Int,
) -> SimplifyLocalsStackedForwarderTail? {
  if candidate_node < 0 ||
    !@ir.hot_node_is_live(func, candidate_node) ||
    @ir.hot_node_result_arity(func, candidate_node) == 0 {
    return None
  }
  match @ir.hot_node_get(func, candidate_node).op {
    @ir.HotOp::If =>
      Some(
        SimplifyLocalsStackedForwarderTail::new(
          candidate_node, rewrite_region, rewrite_idx,
        ),
      )
    @ir.HotOp::Block => {
      let wrapper_body = @ir.hot_region_body_ref(func, candidate_node)
      let wrapper_root_count = @ir.hot_region_root_count(func, wrapper_body)
      if wrapper_root_count == 0 || wrapper_root_count > 2 {
        return None
      }
      let wrapper_prefix = @ir.hot_region_get(func, wrapper_body, 0)
      if wrapper_prefix < 0 || !@ir.hot_node_is_live(func, wrapper_prefix) {
        return None
      }
      match @ir.hot_node_get(func, wrapper_prefix).op {
        @ir.HotOp::Block => ()
        _ => return None
      }
      let wrapper_prefix_body = @ir.hot_region_body_ref(func, wrapper_prefix)
      let wrapper_prefix_root_count = @ir.hot_region_root_count(
        func, wrapper_prefix_body,
      )
      if wrapper_prefix_root_count < 2 {
        return None
      }
      let wrapper_br_idx = wrapper_prefix_root_count - 1
      let wrapper_br = @ir.hot_region_get(
        func, wrapper_prefix_body, wrapper_br_idx,
      )
      if wrapper_br < 0 ||
        !@ir.hot_node_is_live(func, wrapper_br) ||
        @ir.hot_branch_target(func, wrapper_br) !=
        Some(@ir.hot_control_node_label(func, candidate_node)) ||
        simplify_locals_branch_payload_count(func, wrapper_br) != 0 {
        return None
      }
      match @ir.hot_node_get(func, wrapper_br).op {
        @ir.HotOp::Br => ()
        _ => return None
      }
      simplify_locals_try_extract_stacked_forwarder_tail(
        func,
        @ir.hot_region_get(func, wrapper_prefix_body, wrapper_br_idx - 1),
        wrapper_prefix_body,
        wrapper_br_idx,
      )
    }
    _ => None
  }
}

///|
fn simplify_locals_try_rewrite_split_local_set_wrapper_forwarder(
  func : @ir.HotFunc,
  node_id : Int,
  detached : Array[Int],
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => ()
    _ => return false
  }
  if @ir.hot_child_count(func, node_id) == 0 {
    return false
  }
  let value_id = @ir.hot_child_get(func, node_id, 0)
  if value_id < 0 ||
    !@ir.hot_node_is_live(func, value_id) ||
    @ir.hot_node_result_arity(func, value_id) == 0 {
    return false
  }
  match @ir.hot_node_get(func, value_id).op {
    @ir.HotOp::Block => ()
    _ => return false
  }

  let outer_body = @ir.hot_region_body_ref(func, value_id)
  let outer_root_count = @ir.hot_region_root_count(func, outer_body)
  if outer_root_count == 0 {
    return false
  }
  let outer_wrapper = @ir.hot_region_get(func, outer_body, 0)
  if outer_wrapper < 0 || !@ir.hot_node_is_live(func, outer_wrapper) {
    return false
  }
  match @ir.hot_node_get(func, outer_wrapper).op {
    @ir.HotOp::Block => ()
    _ => return false
  }
  let outer_wrapper_body = @ir.hot_region_body_ref(func, outer_wrapper)
  let outer_wrapper_root_count = @ir.hot_region_root_count(
    func, outer_wrapper_body,
  )
  if outer_wrapper_root_count == 0 {
    return false
  }

  let mut payload_block = -1
  let mut outer_br = -1
  if outer_wrapper_root_count == 1 {
    outer_br = @ir.hot_region_get(func, outer_wrapper_body, 0)
    if outer_br < 0 || !@ir.hot_node_is_live(func, outer_br) {
      return false
    }
    match @ir.hot_node_get(func, outer_br).op {
      @ir.HotOp::Br => ()
      _ => return false
    }
    if @ir.hot_branch_target(func, outer_br) !=
      Some(@ir.hot_control_node_label(func, value_id)) ||
      simplify_locals_branch_payload_count(func, outer_br) != 1 {
      return false
    }
    payload_block = @ir.hot_child_get(func, outer_br, 0)
  } else {
    payload_block = @ir.hot_region_get(
      func,
      outer_wrapper_body,
      outer_wrapper_root_count - 2,
    )
    outer_br = @ir.hot_region_get(
      func,
      outer_wrapper_body,
      outer_wrapper_root_count - 1,
    )
    if payload_block < 0 ||
      outer_br < 0 ||
      !@ir.hot_node_is_live(func, payload_block) ||
      !@ir.hot_node_is_live(func, outer_br) ||
      @ir.hot_branch_target(func, outer_br) !=
      Some(@ir.hot_control_node_label(func, value_id)) ||
      simplify_locals_branch_payload_count(func, outer_br) != 0 {
      return false
    }
    match @ir.hot_node_get(func, outer_br).op {
      @ir.HotOp::Br => ()
      _ => return false
    }
  }
  if payload_block < 0 ||
    !@ir.hot_node_is_live(func, payload_block) ||
    @ir.hot_node_result_arity(func, payload_block) == 0 {
    return false
  }
  match @ir.hot_node_get(func, payload_block).op {
    @ir.HotOp::Block => ()
    _ => return false
  }

  let payload_body = @ir.hot_region_body_ref(func, payload_block)
  let payload_root_count = @ir.hot_region_root_count(func, payload_body)
  if payload_root_count == 0 || payload_root_count > 2 {
    return false
  }
  let payload_forwarder = @ir.hot_region_get(func, payload_body, 0)
  if payload_forwarder < 0 || !@ir.hot_node_is_live(func, payload_forwarder) {
    return false
  }
  match @ir.hot_node_get(func, payload_forwarder).op {
    @ir.HotOp::Block => ()
    _ => return false
  }
  let payload_forwarder_body = @ir.hot_region_body_ref(func, payload_forwarder)
  let payload_forwarder_root_count = @ir.hot_region_root_count(
    func, payload_forwarder_body,
  )
  if payload_forwarder_root_count == 1 {
    let direct_br = @ir.hot_region_get(func, payload_forwarder_body, 0)
    if direct_br >= 0 && @ir.hot_node_is_live(func, direct_br) {
      match @ir.hot_node_get(func, direct_br).op {
        @ir.HotOp::Br =>
          if simplify_locals_branch_payload_count(func, direct_br) == 1 {
            let direct_if = @ir.hot_child_get(func, direct_br, 0)
            if direct_if >= 0 &&
              @ir.hot_node_is_live(func, direct_if) &&
              @ir.hot_node_result_arity(func, direct_if) == 1 {
              match @ir.hot_node_get(func, direct_if).op {
                @ir.HotOp::If => {
                  let then_region = @ir.hot_region_then_ref(func, direct_if)
                  let else_region = match
                    @ir.hot_region_else_ref(func, direct_if) {
                    Some(else_region) => else_region
                    None => return false
                  }
                  let if_label = @ir.hot_control_node_label(func, direct_if)
                  let direct_target = match
                    @ir.hot_branch_target(func, direct_br) {
                    Some(target) => target
                    None => return false
                  }
                  let try_build = fn(
                    branch_ref : @ir.HotRegionRef,
                    body_ref : @ir.HotRegionRef,
                    negate_condition : Bool,
                  ) -> Bool {
                    if @ir.hot_region_root_count(func, branch_ref) != 1 ||
                      @ir.hot_region_root_count(func, body_ref) == 0 {
                      return false
                    }
                    let branch_root = @ir.hot_region_get(func, branch_ref, 0)
                    if branch_root < 0 ||
                      !@ir.hot_node_is_live(func, branch_root) {
                      return false
                    }
                    let branch_node = @ir.hot_node_get(func, branch_root)
                    match branch_node.op {
                      @ir.HotOp::Br if branch_node.child_count == 0 => ()
                      _ => return false
                    }
                    if branch_node.imm0 == if_label {
                      return false
                    }
                    let body_tail_idx = @ir.hot_region_root_count(
                        func, body_ref,
                      ) -
                      1
                    let body_payload = @ir.hot_region_get(
                      func, body_ref, body_tail_idx,
                    )
                    if body_payload < 0 ||
                      !@ir.hot_node_is_live(func, body_payload) ||
                      @ir.hot_node_result_arity(func, body_payload) != 1 {
                      return false
                    }
                    let body_prefix : Array[Int] = []
                    for root_idx = 0
                        root_idx < body_tail_idx
                        root_idx = root_idx + 1 {
                      let root_id = @ir.hot_region_get(func, body_ref, root_idx)
                      if @ir.cfg_terminator_edge_kinds(
                          @ir.hot_node_get(func, root_id).op,
                        ).length() >
                        0 {
                        return false
                      }
                      body_prefix.push(root_id)
                    }
                    let guard_condition = if negate_condition {
                      simplify_locals_build_i32_eqz(
                        func,
                        @ir.hot_child_get(func, direct_if, 0),
                      )
                    } else {
                      @ir.hot_child_get(func, direct_if, 0)
                    }
                    let replacement = [
                        @ir.hot_build_br_if(
                          func,
                          branch_node.imm0,
                          guard_condition,
                        ),
                      ] +
                      body_prefix +
                      [
                        @ir.hot_build_br(func, direct_target, values=[
                          body_payload,
                        ]),
                        @ir.hot_build_unreachable(func),
                      ]
                    for
                      removed_id in @ir.hot_region_splice(
                        func, payload_forwarder_body, 0, 1, replacement,
                      ) {
                      detached.push(removed_id)
                    }
                    return true
                  }
                  if try_build(else_region, then_region, true) ||
                    try_build(then_region, else_region, false) {
                    return true
                  }
                }
                _ => ()
              }
            }
          }
        _ => ()
      }
    }
  }
  if payload_forwarder_root_count < 2 {
    return false
  }
  let match_ = match
    simplify_locals_try_extract_stacked_forwarder_tail(
      func,
      @ir.hot_region_get(
        func,
        payload_forwarder_body,
        payload_forwarder_root_count - 2,
      ),
      payload_forwarder_body,
      payload_forwarder_root_count - 1,
    ) {
    Some(match_) => match_
    None => return false
  }
  let inner_br = @ir.hot_region_get(
    func,
    match_.rewrite_region,
    match_.rewrite_idx,
  )
  if inner_br < 0 ||
    !@ir.hot_node_is_live(func, inner_br) ||
    @ir.hot_branch_target(func, inner_br) !=
    Some(@ir.hot_control_node_label(func, payload_block)) {
    return false
  }
  match @ir.hot_node_get(func, inner_br).op {
    @ir.HotOp::Br => ()
    _ => return false
  }

  let node_roots : Array[Int] = []
  for root_idx = 0; root_idx < payload_root_count; root_idx = root_idx + 1 {
    node_roots.push(@ir.hot_region_get(func, payload_body, root_idx))
  }
  for root_idx = 1; root_idx < outer_root_count; root_idx = root_idx + 1 {
    node_roots.push(@ir.hot_region_get(func, outer_body, root_idx))
  }

  @ir.hot_control_result_type_set(
    func,
    match_.payload_if,
    @ir.hot_type_void(func),
  )
  let outer_br_replacement = @ir.hot_build_br(
    func,
    @ir.hot_control_node_label(func, payload_block),
  )
  @ir.hot_replace_node(
    func,
    outer_br,
    @ir.hot_node_get(func, outer_br_replacement),
  )
  let inner_br_replacement = @ir.hot_build_br(
    func,
    @ir.hot_control_node_label(func, value_id),
  )
  @ir.hot_replace_node(
    func,
    inner_br,
    @ir.hot_node_get(func, inner_br_replacement),
  )

  let wrapper_roots : Array[Int] = []
  let wrapper_prefix_count = if outer_wrapper_root_count == 1 {
    0
  } else {
    outer_wrapper_root_count - 2
  }
  for root_idx = 0; root_idx < wrapper_prefix_count; root_idx = root_idx + 1 {
    wrapper_roots.push(@ir.hot_region_get(func, outer_wrapper_body, root_idx))
  }
  wrapper_roots.push(value_id)
  wrapper_roots.push(outer_br)
  @ir.hot_region_replace_body(func, outer_wrapper_body, wrapper_roots)
  @ir.hot_region_replace_body(
    func,
    @ir.hot_region_body_ref(func, value_id),
    node_roots,
  )
  @ir.hot_region_replace_body(
    func,
    @ir.hot_region_body_ref(func, payload_block),
    [outer_wrapper],
  )
  @ir.hot_child_set(func, node_id, 0, payload_block)
  for
    removed_id in @ir.hot_region_splice(
      func,
      match_.rewrite_region,
      match_.rewrite_idx,
      1,
      [@ir.hot_build_unreachable(func)],
    ) {
    detached.push(removed_id)
  }
  true
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
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return true
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Load => false
    _ => !@ir.hot_node_kind_is_control(func, node_id)
  }
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
fn simplify_locals_try_inline_leading_local_get_child(
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
      @ir.HotOp::Nop => continue
      @ir.HotOp::LocalGet if child.imm0 == local_id => {
        @ir.hot_child_set(func, node_id, slot, replacement_id)
        detached.push(child_id)
        return true
      }
      _ =>
        return simplify_locals_try_inline_leading_local_get_child(
          func, child_id, local_id, replacement_id, detached,
        )
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
  let next_id = @ir.hot_region_get(func, parent_region, next_idx)
  if simplify_locals_value_is_child_inline_safe(func, replacement_id) {
    return simplify_locals_try_inline_local_get_child(
      func, next_id, local_id, replacement_id, detached,
    )
  }
  simplify_locals_try_inline_leading_local_get_child(
    func, next_id, local_id, replacement_id, detached,
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
fn simplify_locals_value_is_child_inline_safe(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return true
  }
  if simplify_locals_value_is_pure(func, node_id) {
    return true
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Block => {
      let body_ref = @ir.hot_region_body_ref(func, node_id)
      for idx = 0
          idx < @ir.hot_region_root_count(func, body_ref)
          idx = idx + 1 {
        if !simplify_locals_value_is_child_inline_safe(
            func,
            @ir.hot_region_get(func, body_ref, idx),
          ) {
          return false
        }
      }
      true
    }
    @ir.HotOp::If => {
      if !simplify_locals_value_is_child_inline_safe(
          func,
          @ir.hot_child_get(func, node_id, 0),
        ) {
        return false
      }
      let then_ref = @ir.hot_region_then_ref(func, node_id)
      for idx = 0
          idx < @ir.hot_region_root_count(func, then_ref)
          idx = idx + 1 {
        if !simplify_locals_value_is_child_inline_safe(
            func,
            @ir.hot_region_get(func, then_ref, idx),
          ) {
          return false
        }
      }
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) =>
          for idx = 0
              idx < @ir.hot_region_root_count(func, else_ref)
              idx = idx + 1 {
            if !simplify_locals_value_is_child_inline_safe(
                func,
                @ir.hot_region_get(func, else_ref, idx),
              ) {
              return false
            }
          }
        None => ()
      }
      true
    }
    _ => false
  }
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
  allow_tee : Bool,
) -> Bool {
  let mut changed = false
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    if simplify_locals_scan_node(
        func,
        node_id,
        sinkables,
        first_cycle,
        get_counts,
        detached,
        allow_tee,
        Some(region_ref),
        idx,
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
  allow_tee : Bool,
  parent_region : @ir.HotRegionRef?,
  root_idx : Int,
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
          allow_tee,
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
          allow_tee,
        ) {
        changed = true
      }
      simplify_locals_clear_sinkables(sinkables)
      return changed
    }
    @ir.HotOp::If => {
      let condition_id = @ir.hot_child_get(func, node_id, 0)
      if simplify_locals_scan_node(
          func,
          condition_id,
          sinkables,
          first_cycle,
          get_counts,
          detached,
          allow_tee,
          None,
          -1,
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
          allow_tee,
        ) {
        changed = true
      }
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) => {
          let else_sinkables = simplify_locals_new_sinkables(func)
          if simplify_locals_scan_region(
              func, else_ref, else_sinkables, first_cycle, get_counts, detached,
              allow_tee,
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
          allow_tee,
        ) {
        changed = true
      }
      match @ir.hot_region_catch_ref(func, node_id) {
        Some(catch_ref) => {
          let catch_sinkables = simplify_locals_new_sinkables(func)
          if simplify_locals_scan_region(
              func, catch_ref, catch_sinkables, first_cycle, get_counts, detached,
              allow_tee,
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
          allow_tee,
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
          allow_tee,
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
            func,
            scan_child_id,
            sinkables,
            first_cycle,
            get_counts,
            detached,
            allow_tee,
            None,
            -1,
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
                } else if allow_tee &&
                  !one_use &&
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
            let preserves_control_owner = if value_id >= 0 &&
              @ir.hot_node_is_live(func, value_id) {
              match @ir.hot_node_get(func, value_id).op {
                @ir.HotOp::Block
                | @ir.HotOp::Loop
                | @ir.HotOp::If
                | @ir.HotOp::Try
                | @ir.HotOp::TryTable => true
                _ => false
              }
            } else {
              false
            }
            if !preserves_control_owner {
              @ir.hot_replace_node(
                func,
                node_id,
                simplify_locals_make_local_set(func, child.imm0, value_id),
              )
              detached.push(child_id)
              changed = true
            }
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
      let value_id = @ir.hot_child_get(func, node_id, 0)
      if root_idx >= 0 &&
        get_counts[current.imm0] == 1 &&
        simplify_locals_value_is_child_inline_safe(func, value_id) {
        match parent_region {
          Some(parent_region) =>
            if simplify_locals_try_inline_following_local_get(
                func,
                parent_region,
                root_idx,
                current.imm0,
                value_id,
                detached,
              ) {
              simplify_locals_invalidate_sinkables(
                func,
                node_id,
                current,
                sinkables,
                skip_local=current.imm0,
              )
              simplify_locals_sinkables_clear_local(sinkables, current.imm0)
              @ir.hot_replace_node(
                func,
                node_id,
                simplify_locals_make_nop(func),
              )
              return true
            }
          None => ()
        }
      }
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
        !simplify_locals_local_type_is_defaultable(func, then_tail.local_id) {
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
      let replacement_then = simplify_locals_build_one_armed_if_then_body(
        func,
        then_ref,
        then_tail.root_idx,
        then_tail.value_id,
      )
      let replacement_if = @ir.hot_build_if(
        func,
        result_block_type,
        @ir.hot_child_get(func, node_id, 0),
        replacement_then,
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
  ignore(
    @ir.hot_region_set(func, then_ref, then_tail.root_idx, then_tail.value_id),
  )
  detached.push(then_tail.node_id)
  let result_block_type = match @ir.hot_local_type(func, then_tail.local_id) {
    Some(local_type) => @lib.BlockType::val_type(local_type)
    None => return false
  }
  let replacement_then = simplify_locals_build_one_armed_if_then_body(
    func,
    then_ref,
    then_tail.root_idx,
    then_tail.value_id,
  )
  let replacement_if = @ir.hot_build_if(
    func,
    result_block_type,
    @ir.hot_child_get(func, child_id, 0),
    replacement_then,
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
    if simplify_locals_try_rewrite_split_local_set_wrapper_forwarder(
        func, node_id, detached,
      ) {
      return true
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
  tee_defined_locals : Array[Bool],
) -> Bool {
  let mut changed = false
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    if simplify_locals_scan_equivalent_node(
        env, func, node_id, equivalences, get_counts, tee_defined_locals, false,
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
  tee_defined_locals : Array[Bool],
  protect_tee_defined_locals : Bool,
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
      if protect_tee_defined_locals &&
        local_id >= 0 &&
        local_id < tee_defined_locals.length() &&
        tee_defined_locals[local_id] &&
        best != local_id {
        return false
      }
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
  tee_defined_locals : Array[Bool],
  protect_tee_defined_locals : Bool,
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
          tee_defined_locals,
        ) {
        changed = true
      }
      return changed
    }
    @ir.HotOp::If => {
      let condition_id = @ir.hot_child_get(func, node_id, 0)
      if simplify_locals_scan_equivalent_node(
          env, func, condition_id, equivalences, get_counts, tee_defined_locals,
          false,
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
          tee_defined_locals,
        ) {
        changed = true
      }
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) => {
          let else_equivalences = simplify_locals_clone_equivalences(
            equivalences,
          )
          if simplify_locals_scan_equivalent_region(
              env, func, else_ref, else_equivalences, get_counts, tee_defined_locals,
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
          tee_defined_locals,
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
          tee_defined_locals,
        ) {
        changed = true
      }
      match @ir.hot_region_catch_ref(func, node_id) {
        Some(catch_ref) => {
          let catch_equivalences = simplify_locals_new_equivalences(func)
          if simplify_locals_scan_equivalent_region(
              env, func, catch_ref, catch_equivalences, get_counts, tee_defined_locals,
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
          tee_defined_locals,
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
          tee_defined_locals,
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
            env,
            func,
            child_id,
            equivalences,
            get_counts,
            tee_defined_locals,
            @ir.hot_node_kind_is_call(func, node_id),
          ) {
          changed = true
        }
      }
  }
  if simplify_locals_scan_equivalent_current(
      env, func, node_id, equivalences, get_counts, tee_defined_locals, protect_tee_defined_locals,
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
  allow_tee : Bool,
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
    allow_tee,
  )
  perf_stop_timer_opt(
    ctx.perf,
    "detail:simplify-locals:scan-root-region",
    scan_start_us,
  )
  changed
}

///|
fn simplify_locals_collect_equivalent_tee_defined_locals(
  func : @ir.HotFunc,
) -> Array[Bool] {
  let tee_defined = Array::make(@ir.hot_local_count(func), false)
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::LocalTee => {
        let value_id = @ir.hot_child_get(func, node_id, 0)
        match simplify_locals_equivalent_local_get_value(func, value_id) {
          Some(_) =>
            if node.imm0 >= 0 && node.imm0 < tee_defined.length() {
              tee_defined[node.imm0] = true
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  tee_defined
}

///|
fn simplify_locals_run_equivalent_cleanup(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> Bool {
  let env = simplify_locals_type_env(ctx)
  let tee_defined_locals = simplify_locals_collect_equivalent_tee_defined_locals(
    func,
  )
  simplify_locals_scan_equivalent_region(
    env,
    func,
    @ir.HotRegionRef::root(),
    simplify_locals_new_equivalences(func),
    simplify_locals_count_local_gets(func),
    tee_defined_locals,
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
fn simplify_locals_fold_dead_set_copy_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  get_counts : Array[Int],
  detached : Array[Int],
) -> Bool {
  let mut changed = false
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Block | @ir.HotOp::Loop =>
        changed = simplify_locals_fold_dead_set_copy_region(
            ctx,
            func,
            @ir.hot_region_body_ref(func, node_id),
            get_counts,
            detached,
          ) ||
          changed
      @ir.HotOp::If => {
        changed = simplify_locals_fold_dead_set_copy_region(
            ctx,
            func,
            @ir.hot_region_then_ref(func, node_id),
            get_counts,
            detached,
          ) ||
          changed
        match @ir.hot_region_else_ref(func, node_id) {
          Some(else_ref) =>
            changed = simplify_locals_fold_dead_set_copy_region(
                ctx, func, else_ref, get_counts, detached,
              ) ||
              changed
          None => ()
        }
      }
      @ir.HotOp::Try => {
        changed = simplify_locals_fold_dead_set_copy_region(
            ctx,
            func,
            @ir.hot_region_body_ref(func, node_id),
            get_counts,
            detached,
          ) ||
          changed
        match @ir.hot_region_catch_ref(func, node_id) {
          Some(catch_ref) =>
            changed = simplify_locals_fold_dead_set_copy_region(
                ctx, func, catch_ref, get_counts, detached,
              ) ||
              changed
          None => ()
        }
      }
      @ir.HotOp::TryTable => {
        changed = simplify_locals_fold_dead_set_copy_region(
            ctx,
            func,
            @ir.hot_region_body_ref(func, node_id),
            get_counts,
            detached,
          ) ||
          changed
        changed = simplify_locals_fold_dead_set_copy_region(
            ctx,
            func,
            @ir.hot_region_catch_list_ref(func, node_id),
            get_counts,
            detached,
          ) ||
          changed
      }
      _ => ()
    }
  }
  let mut idx = 0
  while idx + 3 < @ir.hot_region_root_count(func, region_ref) {
    let value_id = @ir.hot_region_get(func, region_ref, idx)
    let spill_set_id = @ir.hot_region_get(func, region_ref, idx + 1)
    let mut reload_idx = idx + 2
    while reload_idx < @ir.hot_region_root_count(func, region_ref) {
      let maybe_nop_id = @ir.hot_region_get(func, region_ref, reload_idx)
      if maybe_nop_id < 0 || !@ir.hot_node_is_live(func, maybe_nop_id) {
        break
      }
      match @ir.hot_node_get(func, maybe_nop_id).op {
        @ir.HotOp::Nop => reload_idx += 1
        _ => break
      }
    }
    let target_idx = reload_idx + 1
    if target_idx >= @ir.hot_region_root_count(func, region_ref) {
      idx += 1
      continue
    }
    let reload_id = @ir.hot_region_get(func, region_ref, reload_idx)
    let target_set_id = @ir.hot_region_get(func, region_ref, target_idx)
    if value_id >= 0 &&
      spill_set_id >= 0 &&
      reload_id >= 0 &&
      target_set_id >= 0 &&
      @ir.hot_node_is_live(func, value_id) &&
      @ir.hot_node_is_live(func, spill_set_id) &&
      @ir.hot_node_is_live(func, reload_id) &&
      @ir.hot_node_is_live(func, target_set_id) {
      let spill_set = @ir.hot_node_get(func, spill_set_id)
      let reload = @ir.hot_node_get(func, reload_id)
      let target_set = @ir.hot_node_get(func, target_set_id)
      match (spill_set.op, reload.op, target_set.op) {
        (@ir.HotOp::LocalSet, @ir.HotOp::LocalGet, @ir.HotOp::LocalSet) => {
          let scratch = spill_set.imm0
          if @ir.hot_node_result_arity(func, value_id) == 1 &&
            spill_set.child_count == 0 &&
            reload.child_count == 0 &&
            target_set.child_count == 0 &&
            scratch >= 0 &&
            scratch < get_counts.length() &&
            scratch != target_set.imm0 &&
            reload.imm0 == scratch &&
            get_counts[scratch] == 1 {
            let replacement_set = @ir.hot_build_local_set(
              func,
              target_set.imm0,
              value_id,
            )
            let removed = @ir.hot_region_splice(
              func,
              region_ref,
              idx,
              target_idx - idx + 1,
              [replacement_set],
            )
            for removed_id in removed {
              if removed_id != value_id {
                detached.push(removed_id)
              }
            }
            changed = true
            idx += 1
            continue
          }
        }
        _ => ()
      }
    }
    idx += 1
  }
  idx = 0
  while idx + 1 < @ir.hot_region_root_count(func, region_ref) {
    let first_id = @ir.hot_region_get(func, region_ref, idx)
    let mut second_idx = idx + 1
    while second_idx < @ir.hot_region_root_count(func, region_ref) {
      let maybe_nop_id = @ir.hot_region_get(func, region_ref, second_idx)
      if maybe_nop_id < 0 || !@ir.hot_node_is_live(func, maybe_nop_id) {
        break
      }
      match @ir.hot_node_get(func, maybe_nop_id).op {
        @ir.HotOp::Nop => second_idx += 1
        _ => break
      }
    }
    if second_idx >= @ir.hot_region_root_count(func, region_ref) {
      idx += 1
      continue
    }
    let second_id = @ir.hot_region_get(func, region_ref, second_idx)
    if first_id < 0 ||
      second_id < 0 ||
      !@ir.hot_node_is_live(func, first_id) ||
      !@ir.hot_node_is_live(func, second_id) {
      idx += 1
      continue
    }
    let first = @ir.hot_node_get(func, first_id)
    let second = @ir.hot_node_get(func, second_id)
    match first.op {
      @ir.HotOp::LocalSet => ()
      _ => {
        idx += 1
        continue
      }
    }
    match second.op {
      @ir.HotOp::LocalSet => ()
      _ => {
        idx += 1
        continue
      }
    }
    if first.child_count != 1 || second.child_count != 1 {
      idx += 1
      continue
    }
    let scratch = first.imm0
    if scratch < 0 ||
      scratch >= get_counts.length() ||
      scratch == second.imm0 ||
      get_counts[scratch] != 1 {
      idx += 1
      continue
    }
    let get_id = @ir.hot_child_get(func, second_id, 0)
    if get_id < 0 || !@ir.hot_node_is_live(func, get_id) {
      idx += 1
      continue
    }
    let get_node = @ir.hot_node_get(func, get_id)
    match get_node.op {
      @ir.HotOp::LocalGet => ()
      _ => {
        idx += 1
        continue
      }
    }
    if get_node.imm0 != scratch {
      idx += 1
      continue
    }
    if pass_node_use_count(ctx, func, get_id) != 1 {
      idx += 1
      continue
    }
    @ir.hot_replace_node(
      func,
      first_id,
      simplify_locals_make_local_set(
        func,
        second.imm0,
        @ir.hot_child_get(func, first_id, 0),
      ),
    )
    @ir.hot_replace_node(func, second_id, simplify_locals_make_nop(func))
    detached.push(get_id)
    changed = true
    idx = second_idx + 1
  }
  changed
}

///|
fn simplify_locals_mark_one_armed_if_tail_sets(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  preserved : Array[Bool],
) -> Unit {
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::If => {
        let then_ref = @ir.hot_region_then_ref(func, node_id)
        match @ir.hot_region_else_ref(func, node_id) {
          None =>
            match simplify_locals_region_tail_local_set(func, then_ref) {
              Some(tail) =>
                if tail.node_id >= 0 && tail.node_id < preserved.length() {
                  preserved[tail.node_id] = true
                }
              None => ()
            }
          Some(else_ref) =>
            simplify_locals_mark_one_armed_if_tail_sets(
              func, else_ref, preserved,
            )
        }
        simplify_locals_mark_one_armed_if_tail_sets(func, then_ref, preserved)
      }
      @ir.HotOp::Block | @ir.HotOp::Loop =>
        simplify_locals_mark_one_armed_if_tail_sets(
          func,
          @ir.hot_region_body_ref(func, node_id),
          preserved,
        )
      @ir.HotOp::Try => {
        simplify_locals_mark_one_armed_if_tail_sets(
          func,
          @ir.hot_region_body_ref(func, node_id),
          preserved,
        )
        match @ir.hot_region_catch_ref(func, node_id) {
          Some(catch_ref) =>
            simplify_locals_mark_one_armed_if_tail_sets(
              func, catch_ref, preserved,
            )
          None => ()
        }
      }
      @ir.HotOp::TryTable => {
        simplify_locals_mark_one_armed_if_tail_sets(
          func,
          @ir.hot_region_body_ref(func, node_id),
          preserved,
        )
        simplify_locals_mark_one_armed_if_tail_sets(
          func,
          @ir.hot_region_catch_list_ref(func, node_id),
          preserved,
        )
      }
      _ => ()
    }
  }
}

///|
fn simplify_locals_one_armed_if_tail_sets(func : @ir.HotFunc) -> Array[Bool] {
  let preserved = Array::make(@ir.hot_node_count(func), false)
  simplify_locals_mark_one_armed_if_tail_sets(
    func,
    @ir.HotRegionRef::root(),
    preserved,
  )
  preserved
}

///|
fn simplify_locals_run_dead_cleanup(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  detached : Array[Int],
  rehomed_owners : Array[SimplifyLocalsDetachedControlOwner],
) -> Bool {
  let get_counts = simplify_locals_count_local_gets(func)
  let one_armed_if_tail_sets = simplify_locals_one_armed_if_tail_sets(func)
  let mut changed = simplify_locals_fold_dead_set_copy_region(
    ctx,
    func,
    @ir.HotRegionRef::root(),
    get_counts,
    detached,
  )
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
        if node_id >= 0 &&
          node_id < one_armed_if_tail_sets.length() &&
          one_armed_if_tail_sets[node_id] {
          continue
        }
        if value_id >= 0 && @ir.hot_node_is_live(func, value_id) {
          match @ir.hot_node_get(func, value_id).op {
            @ir.HotOp::If => continue
            _ => ()
          }
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
        if value_id >= 0 &&
          @ir.hot_node_is_live(func, value_id) &&
          @ir.hot_node_kind_is_control(func, value_id) {
          rehomed_owners.push({ replacement_id: node_id, detached_id: value_id })
          @ir.hot_replace_node(func, node_id, @ir.hot_node_get(func, value_id))
          detached.push(value_id)
          changed = true
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
fn simplify_locals_run_with_options(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  allow_structure_rewrites : Bool,
  allow_tee : Bool,
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
      ctx, func, first_cycle, main_detached, allow_tee,
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
    let cleanup_rehomed_owners : Array[SimplifyLocalsDetachedControlOwner] = []
    let cleanup_changed = simplify_locals_run_dead_cleanup(
      ctx, func, cleanup_detached, cleanup_rehomed_owners,
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
    simplify_locals_rehome_detached_control_owners(func, cleanup_rehomed_owners)
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

    if allow_structure_rewrites {
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
    let late_cleanup_rehomed_owners : Array[SimplifyLocalsDetachedControlOwner] = []
    let late_cleanup_changed = simplify_locals_run_dead_cleanup(
      ctx, func, late_cleanup_detached, late_cleanup_rehomed_owners,
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
    simplify_locals_rehome_detached_control_owners(
      func, late_cleanup_rehomed_owners,
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

///|
fn simplify_locals_is_region_child_slot(op : @ir.HotOp, slot : Int) -> Bool {
  for info in @ir.hot_control_region_slot_info(op) {
    if info.slot == slot {
      return true
    }
  }
  false
}

///|
fn simplify_locals_node_has_stack_effect_hazard(
  func : @ir.HotFunc,
  node_id : @ir.NodeId,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Call
    | @ir.HotOp::CallIndirect
    | @ir.HotOp::CallRef
    | @ir.HotOp::MemoryCopy
    | @ir.HotOp::MemoryFill => return true
    _ => ()
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    if simplify_locals_is_region_child_slot(node.op, slot) {
      continue
    }
    if simplify_locals_node_has_stack_effect_hazard(
        func,
        @ir.hot_child_get(func, node_id, slot),
      ) {
      return true
    }
  }
  false
}

///|
fn simplify_locals_should_skip_root_local_set_stack_hazard(
  func : @ir.HotFunc,
) -> Bool {
  let root_ref = @ir.HotRegionRef::root()
  if @ir.hot_region_root_count(func, root_ref) <= 1 {
    return false
  }
  let mut has_local_set = false
  let mut has_stack_effect = false
  for idx = 0; idx < @ir.hot_region_root_count(func, root_ref); idx = idx + 1 {
    let root_id = @ir.hot_region_get(func, root_ref, idx)
    if root_id < 0 || !@ir.hot_node_is_live(func, root_id) {
      continue
    }
    match @ir.hot_node_get(func, root_id).op {
      @ir.HotOp::LocalSet => has_local_set = true
      _ => ()
    }
    if simplify_locals_node_has_stack_effect_hazard(func, root_id) {
      has_stack_effect = true
    }
  }
  has_local_set && has_stack_effect
}

///|
fn simplify_locals_run(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> HotPassResult {
  simplify_locals_run_with_options(ctx, func, true, true)
}

///|
fn simplify_locals_has_local_tee(func : @ir.HotFunc) -> Bool {
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::LocalTee => return true
      _ => ()
    }
  }
  false
}

///|
fn simplify_locals_nostructure_run(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> HotPassResult {
  // No-structure sinking currently lacks a precise barrier model for values
  // loaded through locals defined by local.tee later in the same stack region.
  if simplify_locals_has_local_tee(func) {
    return HotPassResult::unchanged()
  }
  if simplify_locals_should_skip_root_local_set_stack_hazard(func) {
    pipeline_trace_hook(
      ctx.trace,
      ctx.descriptor.name,
      "skip-hot",
      payload="reason=root-local-set-stack-hazard-noop",
    )
    return HotPassResult::unchanged()
  }
  simplify_locals_run_with_options(ctx, func, false, true)
}

///|
fn simplify_locals_notee_nostructure_run(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> HotPassResult {
  simplify_locals_run_with_options(ctx, func, false, false)
}
