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
    Some(Instruction::MemoryAtomicNotify(_)) =>
      EFFECT_MASK_MEMORY_WRITE | EFFECT_MASK_TRAP
    Some(Instruction::MemoryAtomicWait32(_))
    | Some(Instruction::MemoryAtomicWait64(_))
    | Some(Instruction::I32AtomicLoad(_))
    | Some(Instruction::I64AtomicLoad(_))
    | Some(Instruction::I32AtomicLoad8U(_))
    | Some(Instruction::I32AtomicLoad16U(_))
    | Some(Instruction::I64AtomicLoad8U(_))
    | Some(Instruction::I64AtomicLoad16U(_))
    | Some(Instruction::I64AtomicLoad32U(_)) =>
      EFFECT_MASK_MEMORY_READ | EFFECT_MASK_TRAP
    Some(Instruction::I32AtomicStore(_))
    | Some(Instruction::I64AtomicStore(_))
    | Some(Instruction::I32AtomicStore8(_))
    | Some(Instruction::I32AtomicStore16(_))
    | Some(Instruction::I64AtomicStore8(_))
    | Some(Instruction::I64AtomicStore16(_))
    | Some(Instruction::I64AtomicStore32(_)) =>
      EFFECT_MASK_MEMORY_WRITE | EFFECT_MASK_TRAP
    Some(Instruction::AtomicRmw(_, _))
    | Some(Instruction::AtomicCmpxchg(_, _)) =>
      EFFECT_MASK_MEMORY_READ | EFFECT_MASK_MEMORY_WRITE | EFFECT_MASK_TRAP
    _ => EFFECT_MASK_MEMORY_READ | EFFECT_MASK_MEMORY_WRITE | EFFECT_MASK_TRAP
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
    | Some(Instruction::ArrayLen)
    | Some(Instruction::RefGetDesc(_)) =>
      EFFECT_MASK_MEMORY_READ | EFFECT_MASK_TRAP
    Some(Instruction::StructSet(_, _))
    | Some(Instruction::ArraySet(_))
    | Some(Instruction::ArrayFill(_)) =>
      EFFECT_MASK_MEMORY_WRITE | EFFECT_MASK_TRAP
    Some(Instruction::StructNew(_))
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
    HotOp::Atomic =>
      effects_mask_for_atomic_exact(hot_node_exact_instr(func, node_id))
    HotOp::Heap =>
      effects_mask_for_heap_exact(hot_node_exact_instr(func, node_id))
    _ => 0U
  }
}

///|
fn effects_accumulate_node_cached(
  func : HotFunc,
  node_id : NodeId,
  node_masks : Array[EffectMask],
  ready : Array[Bool],
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
  let ready = Array::make(hot_node_count(func), false)
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
    Array::make(hot_node_count(func), false),
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
