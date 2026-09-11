///|
pub type EffectMask = UInt

///|
pub const EFFECT_MASK_CONTROL : EffectMask = 1U

///|
pub const EFFECT_MASK_CALL : EffectMask = 2U

///|
pub const EFFECT_MASK_THROW : EffectMask = 4U

///|
pub const EFFECT_MASK_TRAP : EffectMask = 8U

///|
pub const EFFECT_MASK_LOCAL_STATE : EffectMask = 16U

///|
pub const EFFECT_MASK_GLOBAL_STATE : EffectMask = 32U

///|
pub const EFFECT_MASK_MEMORY_READ : EffectMask = 64U

///|
pub const EFFECT_MASK_MEMORY_WRITE : EffectMask = 128U

///|
pub const EFFECT_MASK_TABLE_READ : EffectMask = 256U

///|
pub const EFFECT_MASK_TABLE_WRITE : EffectMask = 512U

///|
pub const EFFECT_MASK_ATOMIC_READ : EffectMask = 1024U

///|
pub const EFFECT_MASK_ATOMIC_WRITE : EffectMask = 2048U

///|
pub const EFFECT_MASK_ACQUIRE : EffectMask = 4096U

///|
pub const EFFECT_MASK_RELEASE : EffectMask = 8192U

///|
pub const EFFECT_MASK_SEQ_CST : EffectMask = 16384U

///|
pub fn effects_atomic_order_mask(
  order : @lib.AtomicOrder,
  read~ : Bool,
  write~ : Bool,
) -> EffectMask {
  let mut mask = 0U
  if read {
    mask = mask | EFFECT_MASK_ATOMIC_READ
  }
  if write {
    mask = mask | EFFECT_MASK_ATOMIC_WRITE
  }
  match order {
    @lib.Relaxed => ()
    @lib.AcqRel => {
      if read {
        mask = mask | EFFECT_MASK_ACQUIRE
      }
      if write {
        mask = mask | EFFECT_MASK_RELEASE
      }
    }
    @lib.SeqCst => mask = mask | EFFECT_MASK_SEQ_CST
  }
  mask
}

///|
// Whether the earlier expression must stay before the later expression due
// to synchronization. Alias and trap checks remain independently required.
// The v132 relaxed load/store edge applies even across disjoint heap classes.
pub fn effects_atomic_orders_conflict(
  earlier : EffectMask,
  later : EffectMask,
  earlier_shared~ : Bool,
  later_shared~ : Bool,
) -> Bool {
  (
    (earlier & EFFECT_MASK_ATOMIC_READ) != 0U &&
    (later & EFFECT_MASK_ATOMIC_WRITE) != 0U
  ) ||
  ((earlier & EFFECT_MASK_ACQUIRE) != 0U && later_shared) ||
  ((later & EFFECT_MASK_RELEASE) != 0U && earlier_shared) ||
  ((earlier & EFFECT_MASK_SEQ_CST) != 0U && later_shared) ||
  ((later & EFFECT_MASK_SEQ_CST) != 0U && earlier_shared)
}

///|
fn effects_has(mask : EffectMask, bit : EffectMask) -> Bool {
  (mask & bit) != 0U
}

///|
fn effects_mask_for_flags(flags : UInt) -> EffectMask {
  let mut mask = 0U
  if (flags & HOT_FLAG_CONTROL) != 0U ||
    (flags & HOT_FLAG_BRANCH) != 0U ||
    (flags & HOT_FLAG_TERMINATOR) != 0U {
    mask = mask | EFFECT_MASK_CONTROL
  }
  if (flags & HOT_FLAG_CALL) != 0U {
    mask = mask | EFFECT_MASK_CALL | EFFECT_MASK_THROW
  }
  if (flags & HOT_FLAG_THROWS) != 0U ||
    (flags & HOT_FLAG_HAS_EXCEPTIONAL_SUCC) != 0U {
    mask = mask | EFFECT_MASK_THROW
  }
  if (flags & HOT_FLAG_MAY_TRAP) != 0U {
    mask = mask | EFFECT_MASK_TRAP
  }
  mask
}

///|
fn effects_mask_for_atomic_exact(instr : Instruction?) -> EffectMask {
  match instr {
    Some(Instruction::AtomicFence(_)) =>
      // The released fence is a barrier across shared memory, structs and
      // arrays for every spelling. Match upstream's conservative SeqCst
      // summary while preserving its encoded order as an exact instruction.
      EFFECT_MASK_MEMORY_READ |
      EFFECT_MASK_MEMORY_WRITE |
      EFFECT_MASK_ATOMIC_READ |
      EFFECT_MASK_ATOMIC_WRITE |
      EFFECT_MASK_SEQ_CST
    Some(Instruction::StructWait(_, _)) =>
      EFFECT_MASK_MEMORY_READ |
      EFFECT_MASK_MEMORY_WRITE |
      EFFECT_MASK_TRAP |
      EFFECT_MASK_CONTROL |
      EFFECT_MASK_SEQ_CST |
      EFFECT_MASK_ATOMIC_READ |
      EFFECT_MASK_ATOMIC_WRITE
    Some(Instruction::WaitqueueNotify) =>
      EFFECT_MASK_MEMORY_READ |
      EFFECT_MASK_MEMORY_WRITE |
      EFFECT_MASK_TRAP |
      EFFECT_MASK_SEQ_CST |
      EFFECT_MASK_ATOMIC_READ |
      EFFECT_MASK_ATOMIC_WRITE
    Some(Instruction::MemoryAtomicNotify(_))
    | Some(Instruction::MemoryAtomicWait32(_))
    | Some(Instruction::MemoryAtomicWait64(_)) =>
      // Shared wait/notify operations mutate the address's waiter list.
      // The common summary has no module sharedness context, so retain the
      // synchronization even where a more precise unshared-memory proof could
      // classify the operation as just a trap or a constant result.
      EFFECT_MASK_MEMORY_READ |
      EFFECT_MASK_MEMORY_WRITE |
      EFFECT_MASK_TRAP |
      effects_atomic_order_mask(
        @lib.AtomicOrder::seq_cst(),
        read=true,
        write=true,
      )
    Some(Instruction::I32AtomicLoad(order, _))
    | Some(Instruction::I64AtomicLoad(order, _))
    | Some(Instruction::I32AtomicLoad8U(order, _))
    | Some(Instruction::I32AtomicLoad16U(order, _))
    | Some(Instruction::I64AtomicLoad8U(order, _))
    | Some(Instruction::I64AtomicLoad16U(order, _))
    | Some(Instruction::I64AtomicLoad32U(order, _))
    | Some(Instruction::StructAtomicGet(order, _, _))
    | Some(Instruction::StructAtomicGetS(order, _, _))
    | Some(Instruction::StructAtomicGetU(order, _, _))
    | Some(Instruction::ArrayAtomicGet(order, _))
    | Some(Instruction::ArrayAtomicGetS(order, _))
    | Some(Instruction::ArrayAtomicGetU(order, _)) =>
      EFFECT_MASK_MEMORY_READ |
      EFFECT_MASK_TRAP |
      effects_atomic_order_mask(order, read=true, write=false)
    Some(Instruction::StructAtomicSet(order, _, _))
    | Some(Instruction::ArrayAtomicSet(order, _)) =>
      EFFECT_MASK_MEMORY_WRITE |
      EFFECT_MASK_TRAP |
      effects_atomic_order_mask(order, read=false, write=true)
    Some(Instruction::I32AtomicStore(order, _))
    | Some(Instruction::I64AtomicStore(order, _))
    | Some(Instruction::I32AtomicStore8(order, _))
    | Some(Instruction::I32AtomicStore16(order, _))
    | Some(Instruction::I64AtomicStore8(order, _))
    | Some(Instruction::I64AtomicStore16(order, _))
    | Some(Instruction::I64AtomicStore32(order, _)) =>
      EFFECT_MASK_MEMORY_WRITE |
      EFFECT_MASK_TRAP |
      effects_atomic_order_mask(order, read=false, write=true)
    Some(Instruction::AtomicRmw(order, _, _))
    | Some(Instruction::AtomicCmpxchg(order, _, _))
    | Some(Instruction::StructAtomicRmw(order, _, _, _))
    | Some(Instruction::StructAtomicCmpxchg(order, _, _))
    | Some(Instruction::ArrayAtomicRmw(order, _, _))
    | Some(Instruction::ArrayAtomicCmpxchg(order, _)) =>
      EFFECT_MASK_MEMORY_READ |
      EFFECT_MASK_MEMORY_WRITE |
      EFFECT_MASK_TRAP |
      effects_atomic_order_mask(order, read=true, write=true)
    _ => EFFECT_MASK_MEMORY_READ | EFFECT_MASK_MEMORY_WRITE | EFFECT_MASK_TRAP
  }
}

///|
fn effects_mask_for_numeric_exact(instr : Instruction?) -> EffectMask {
  match instr {
    Some(Instruction::I32DivS)
    | Some(Instruction::I32DivU)
    | Some(Instruction::I32RemS)
    | Some(Instruction::I32RemU)
    | Some(Instruction::I64DivS)
    | Some(Instruction::I64DivU)
    | Some(Instruction::I64RemS)
    | Some(Instruction::I64RemU)
    | Some(Instruction::I32TruncF32S)
    | Some(Instruction::I32TruncF32U)
    | Some(Instruction::I32TruncF64S)
    | Some(Instruction::I32TruncF64U)
    | Some(Instruction::I64TruncF32S)
    | Some(Instruction::I64TruncF32U)
    | Some(Instruction::I64TruncF64S)
    | Some(Instruction::I64TruncF64U) => EFFECT_MASK_TRAP
    _ => 0U
  }
}

///|
fn effects_mask_for_heap_exact(instr : Instruction?) -> EffectMask {
  match instr {
    Some(Instruction::StructGet(_, _))
    | Some(Instruction::StructGetS(_, _))
    | Some(Instruction::StructGetU(_, _))
    | Some(Instruction::ArrayGet(_))
    | Some(Instruction::ArrayGetS(_))
    | Some(Instruction::ArrayGetU(_))
    | Some(Instruction::ArrayLoad(_, _, _))
    | Some(Instruction::ArrayLen)
    | Some(Instruction::RefGetDesc(_)) =>
      EFFECT_MASK_MEMORY_READ | EFFECT_MASK_TRAP
    Some(Instruction::StructSet(_, _))
    | Some(Instruction::ArraySet(_))
    | Some(Instruction::ArrayStore(_, _, _))
    | Some(Instruction::ArrayFill(_)) =>
      EFFECT_MASK_MEMORY_WRITE | EFFECT_MASK_TRAP
    Some(Instruction::WaitqueueNew)
    | Some(Instruction::StructNew(_))
    | Some(Instruction::ContNew(_))
    | Some(Instruction::ContBind(_, _))
    | Some(Instruction::StructNewDefault(_))
    | Some(Instruction::StructNewDesc(_))
    | Some(Instruction::StructNewDefaultDesc(_))
    | Some(Instruction::ArrayNew(_))
    | Some(Instruction::ArrayNewDefault(_))
    | Some(Instruction::ArrayNewFixed(_, _))
    | Some(Instruction::ArrayNewData(_, _))
    | Some(Instruction::ArrayNewElem(_, _))
    | Some(Instruction::ArrayCopy(_, _))
    | Some(Instruction::ArrayInitData(_, _))
    | Some(Instruction::ArrayInitElem(_, _)) =>
      EFFECT_MASK_MEMORY_READ | EFFECT_MASK_MEMORY_WRITE | EFFECT_MASK_TRAP
    Some(Instruction::RefAsNonNull)
    | Some(Instruction::I31GetS)
    | Some(Instruction::I31GetU) => EFFECT_MASK_TRAP
    Some(Instruction::RefEq)
    | Some(Instruction::AnyConvertExtern)
    | Some(Instruction::ExternConvertAny)
    | Some(Instruction::RefI31) => 0U
    _ => EFFECT_MASK_TRAP
  }
}

///|
fn effects_node_exact_instr_opt(
  func : HotFunc,
  node_id : NodeId,
) -> Instruction? {
  if hot_verify_node_exact_instr_payload(func, node_id) {
    hot_node_exact_instr(func, node_id)
  } else {
    None
  }
}

///|
fn effects_mask_for_node_exact(func : HotFunc, node_id : NodeId) -> EffectMask {
  let node = hot_node_get(func, node_id)
  match node.op {
    HotOp::LocalGet | HotOp::LocalSet | HotOp::LocalTee =>
      EFFECT_MASK_LOCAL_STATE
    HotOp::GlobalGet | HotOp::GlobalSet => EFFECT_MASK_GLOBAL_STATE
    HotOp::Load => EFFECT_MASK_MEMORY_READ
    HotOp::Store => EFFECT_MASK_MEMORY_WRITE
    HotOp::MemorySize => EFFECT_MASK_MEMORY_READ
    HotOp::MemoryGrow => EFFECT_MASK_MEMORY_READ | EFFECT_MASK_MEMORY_WRITE
    HotOp::MemoryCopy | HotOp::MemoryInit =>
      EFFECT_MASK_MEMORY_READ | EFFECT_MASK_MEMORY_WRITE
    HotOp::MemoryFill | HotOp::DataDrop => EFFECT_MASK_MEMORY_WRITE
    HotOp::TableGet | HotOp::TableSize => EFFECT_MASK_TABLE_READ
    HotOp::TableSet | HotOp::TableGrow | HotOp::TableFill | HotOp::ElemDrop =>
      EFFECT_MASK_TABLE_WRITE
    HotOp::TableCopy | HotOp::TableInit =>
      EFFECT_MASK_TABLE_READ | EFFECT_MASK_TABLE_WRITE
    HotOp::Binary | HotOp::Convert =>
      effects_mask_for_numeric_exact(
        effects_node_exact_instr_opt(func, node_id),
      )
    HotOp::Atomic =>
      effects_mask_for_atomic_exact(effects_node_exact_instr_opt(func, node_id))
    HotOp::Heap =>
      effects_mask_for_heap_exact(effects_node_exact_instr_opt(func, node_id))
    _ => 0U
  }
}

///|
fn effects_accumulate_node_cached(
  func : HotFunc,
  node_id : NodeId,
  node_masks : Array[EffectMask],
  ready : @bitset.BitSet,
) -> EffectMask {
  if ready[node_id] {
    return node_masks[node_id]
  }
  let mut mask = effects_mask_for_flags(hot_node_flags(func, node_id))
  mask = mask | effects_mask_for_node_exact(func, node_id)
  for slot = 0; slot < hot_child_count(func, node_id); slot = slot + 1 {
    let child_id = hot_child_get(func, node_id, slot)
    if child_id == HOT_NONE_NODE || !hot_node_is_live(func, child_id) {
      continue
    }
    mask = mask |
      effects_accumulate_node_cached(func, child_id, node_masks, ready)
  }
  node_masks[node_id] = mask
  ready[node_id] = true
  mask
}

///|
fn effects_build_node_masks(func : HotFunc) -> Array[EffectMask] {
  let node_masks = Array::make(hot_node_count(func), 0U)
  let ready = @bitset.BitSet::new(hot_node_count(func))
  for node_id = 0; node_id < hot_node_count(func); node_id = node_id + 1 {
    if !hot_node_is_live(func, node_id) {
      continue
    }
    ignore(effects_accumulate_node_cached(func, node_id, node_masks, ready))
  }
  node_masks
}

///|
pub fn effects_for_node(func : HotFunc, node_id : NodeId) -> EffectMask {
  effects_accumulate_node_cached(
    func,
    node_id,
    Array::make(hot_node_count(func), 0U),
    @bitset.BitSet::new(hot_node_count(func)),
  )
}

///|
fn effects_for_block_with_node_masks(
  cfg : HotCfg,
  block_id : BlockId,
  node_masks : Array[EffectMask],
) -> EffectMask {
  let mut mask = 0U
  for node_id in cfg_block_get(cfg, block_id).nodes {
    mask = mask | node_masks[node_id]
  }
  mask
}

///|
pub fn effects_for_block(
  func : HotFunc,
  cfg : HotCfg,
  block_id : BlockId,
) -> EffectMask {
  effects_for_block_with_node_masks(
    cfg,
    block_id,
    effects_build_node_masks(func),
  )
}

///|
fn effects_for_region_with_node_masks(
  func : HotFunc,
  region_ref : HotRegionRef,
  node_masks : Array[EffectMask],
) -> EffectMask {
  let mut mask = 0U
  for slot = 0; slot < hot_region_root_count(func, region_ref); slot = slot + 1 {
    let node_id = hot_region_get(func, region_ref, slot)
    if node_id == HOT_NONE_NODE || !hot_node_is_live(func, node_id) {
      continue
    }
    mask = mask | node_masks[node_id]
  }
  mask
}

///|
pub fn effects_for_region(
  func : HotFunc,
  region_ref : HotRegionRef,
) -> EffectMask {
  effects_for_region_with_node_masks(
    func,
    region_ref,
    effects_build_node_masks(func),
  )
}

///|
pub fn effects_is_pure(mask : EffectMask) -> Bool {
  mask == 0U
}

///|
pub fn effects_may_throw(mask : EffectMask) -> Bool {
  effects_has(mask, EFFECT_MASK_THROW)
}

///|
pub fn effects_reads_memory(mask : EffectMask) -> Bool {
  effects_has(mask, EFFECT_MASK_MEMORY_READ)
}

///|
pub fn effects_writes_memory(mask : EffectMask) -> Bool {
  effects_has(mask, EFFECT_MASK_MEMORY_WRITE)
}
