///|
fn SSADestructor::new(param_count : Int) -> SSADestructor {
  SSADestructor::{
    value_to_local: Map::new(),
    next_local: param_count.reinterpret_as_uint(),
  }
}

///|
fn SSADestructor::get_local(self : SSADestructor, val : SSAValue) -> LocalIdx {
  match self.value_to_local.get(val) {
    Some(l) => l
    None => {
      let l = LocalIdx::new(self.next_local)
      self.next_local = self.next_local + 1
      self.value_to_local[val] = l
      l
    }
  }
}

///|
/// Check if an edge is critical (pred has multiple successors, succ has multiple predecessors)
fn is_critical_edge(cfg : SSACFG, pred : BlockId, succ : BlockId) -> Bool {
  let pred_succs = get_ssa_successors(cfg.blocks[pred].terminator)
  let succ_preds = cfg.preds.get(succ).unwrap_or([])
  pred_succs.length() > 1 && succ_preds.length() > 1
}

///|
fn get_ssa_successors(term : SSATerminator) -> Array[BlockId] {
  match term {
    Br(t) => [t]
    BrOnCast(CastOp(_, _), _, _, SSAValue(_), t, f)
    | BrOnNonNull(SSAValue(_), t, f)
    | BrOnNull(SSAValue(_), t, f)
    | BrOnCastFail(CastOp(_, _), _, _, SSAValue(_), t, f)
    | BrIf(_, t, f) => [t, f]
    BrTable(_, targets, d) => {
      let result = targets.copy()
      result.push(d)
      result
    }
    _ => []
  }
}

///|
/// Split critical edges by inserting intermediate blocks
pub fn SSACFG::split_critical_edges(self : SSACFG) -> SSACFG {
  let new_blocks : Map[BlockId, SSABlock] = Map::new()
  let new_preds : Map[BlockId, Array[BlockId]] = Map::new()
  let mut next_id = 0

  // Find max block id
  for entry in self.blocks {
    let (BlockId(id), _) = entry
    if id >= next_id {
      next_id = id + 1
    }
  }

  // Maps (pred, succ) -> new intermediate block
  let split_blocks : Map[(BlockId, BlockId), BlockId] = Map::new()

  // First pass: identify critical edges
  for entry in self.blocks {
    let (block_id, block) = entry
    let succs = get_ssa_successors(block.terminator)
    for succ in succs {
      if is_critical_edge(self, block_id, succ) {
        let new_id = BlockId(next_id)
        next_id = next_id + 1
        split_blocks[(block_id, succ)] = new_id
      }
    }
  }

  // Second pass: create new blocks and update terminators
  for entry in self.blocks {
    let (block_id, block) = entry

    // Update terminator to point to split blocks
    let new_term = match block.terminator {
      SSATerminator::Br(t) =>
        match split_blocks.get((block_id, t)) {
          Some(new_id) => SSATerminator::Br(new_id)
          None => SSATerminator::Br(t)
        }
      SSATerminator::BrIf(cond, t, f) => {
        let new_t = split_blocks.get((block_id, t)).unwrap_or(t)
        let new_f = split_blocks.get((block_id, f)).unwrap_or(f)
        SSATerminator::BrIf(cond, new_t, new_f)
      }
      SSATerminator::BrTable(cond, targets, d) => {
        let new_targets = targets.map(fn(t) {
          split_blocks.get((block_id, t)).unwrap_or(t)
        })
        let new_d = split_blocks.get((block_id, d)).unwrap_or(d)
        SSATerminator::BrTable(cond, new_targets, new_d)
      }
      other => other
    }

    // Update phi args to come from split blocks
    let new_phis = block.phis.map(fn(phi) {
      let new_args : Map[BlockId, SSAValue] = Map::new()
      for arg_entry in phi.args {
        let (pred, val) = arg_entry
        match split_blocks.get((pred, block_id)) {
          Some(split_id) => new_args[split_id] = val
          None => new_args[pred] = val
        }
      }
      PhiNode::{ local_idx: phi.local_idx, result: phi.result, args: new_args }
    })
    new_blocks[block_id] = SSABlock::{
      id: block_id,
      phis: new_phis,
      instrs: block.instrs,
      terminator: new_term,
    }
  }

  // Create the split blocks (empty, just jump to original target)
  for entry in split_blocks {
    let ((_, succ), new_id) = entry
    new_blocks[new_id] = SSABlock::{
      id: new_id,
      phis: [],
      instrs: [],
      terminator: SSATerminator::Br(succ),
    }
  }

  // Recompute predecessors
  for entry in new_blocks {
    let (_, block) = entry
    for succ in get_ssa_successors(block.terminator) {
      new_preds.get_or_init(succ, fn() { [] }).push(block.id)
    }
  }
  SSACFG::{
    entry: self.entry,
    blocks: new_blocks,
    preds: new_preds,
    param_values: self.param_values,
    next_value: self.next_value,
  }
}

///|
/// Convert SSA back to CFG with explicit locals
pub fn SSACFG::to_cfg(self : SSACFG, param_count : Int) -> CFG {
  let destructor = SSADestructor::new(param_count)
  let blocks : Map[BlockId, BasicBlock] = Map::new()

  // First pass: assign locals to all SSA values
  for entry in self.param_values {
    let (local_idx, val) = entry
    destructor.value_to_local[val] = local_idx
  }

  // Assign locals to all defined values
  for entry in self.blocks {
    let (_, block) = entry
    for phi in block.phis {
      let _ = destructor.get_local(phi.result)
    }
    for instr in block.instrs {
      if instr is SSAInstr::Assign(result, _) {
        ignore(destructor.get_local(result))
      }
    }
  }

  // Second pass: convert blocks
  for entry in self.blocks {
    let (block_id, block) = entry
    let instrs : Array[TInstr] = []

    // Phi nodes become copies at the START of the block
    // (Actually, copies need to go at END of predecessors - handle below)

    // Convert instructions
    for instr in block.instrs {
      match instr {
        SSAInstr::Assign(result, op) => {
          let l = destructor.get_local(result)
          let tinstr = convert_ssa_op_to_tinstr(op, destructor)
          instrs.push(TInstr::local_set(l, tinstr))
        }
        SSAInstr::Effect(op) => {
          let tinstr = convert_ssa_op_to_tinstr(op, destructor)
          instrs.push(tinstr)
        }
      }
    }

    // Convert terminator
    let terminator = convert_ssa_terminator(block.terminator, destructor)
    blocks[block_id] = BasicBlock::{ id: block_id, instrs, terminator }
  }

  // Third pass: insert phi copies at end of predecessor blocks
  for entry in self.blocks {
    let (_, block) = entry
    for phi in block.phis {
      let dest_local = destructor.get_local(phi.result)
      for arg_entry in phi.args {
        let (pred_id, val) = arg_entry
        let src_local = destructor.get_local(val)
        let copy_instr = TInstr::local_set(
          dest_local,
          TInstr::local_get(src_local),
        )
        // Insert before terminator
        blocks[pred_id].instrs.push(copy_instr)
      }
    }
  }
  let preds = compute_predecessors(blocks)
  CFG::{ entry: self.entry, blocks, preds }
}

///|
fn convert_ssa_op_to_tinstr(op : SSAOp, d : SSADestructor) -> TInstr {
  fn get(d : SSADestructor, v : SSAValue) -> TInstr {
    TInstr::local_get(d.get_local(v))
  }

  fn get_args(d : SSADestructor, args : Array[SSAValue]) -> Array[TInstr] {
    args.map(fn(v) { get(d, v) })
  }

  match op {
    SSAOp::Copy(v) => get(d, v)
    SSAOp::I32Const(c) => TInstr::i32_const(c)
    SSAOp::I64Const(c) => TInstr::i64_const(c)
    SSAOp::F32Const(c) => TInstr::f32_const(c)
    SSAOp::F64Const(c) => TInstr::f64_const(c)
    SSAOp::V128Const(bytes) =>
      TInstr::v128_const(
        bytes.unsafe_get(0),
        bytes.unsafe_get(1),
        bytes.unsafe_get(2),
        bytes.unsafe_get(3),
        bytes.unsafe_get(4),
        bytes.unsafe_get(5),
        bytes.unsafe_get(6),
        bytes.unsafe_get(7),
        bytes.unsafe_get(8),
        bytes.unsafe_get(9),
        bytes.unsafe_get(10),
        bytes.unsafe_get(11),
        bytes.unsafe_get(12),
        bytes.unsafe_get(13),
        bytes.unsafe_get(14),
        bytes.unsafe_get(15),
      )
    SSAOp::RefNull(ht) => TInstr::ref_null(ht)
    SSAOp::RefFunc(idx) => TInstr::ref_func(idx)
    SSAOp::Unary(op, a) => TInstr::unary(op, get(d, a))
    SSAOp::Binary(op, a, b) => TInstr::binary(op, get(d, a), get(d, b))
    SSAOp::Select(tys, a, b, c) =>
      TInstr::select(tys, get(d, a), get(d, b), get(d, c))
    SSAOp::GlobalGet(idx) => TInstr::global_get(idx)
    SSAOp::GlobalSet(idx, v) => TInstr::global_set(idx, get(d, v))
    SSAOp::Load(op, memarg, addr) => TInstr::load(op, memarg, get(d, addr))
    SSAOp::Store(op, memarg, addr, val) =>
      TInstr::store(op, memarg, get(d, addr), get(d, val))
    SSAOp::MemorySize(idx) => TInstr::memory_size(idx)
    SSAOp::MemoryGrow(idx, v) => TInstr::memory_grow(idx, get(d, v))
    SSAOp::MemoryFill(idx, dest, val, len) =>
      TInstr::memory_fill(idx, get(d, dest), get(d, val), get(d, len))
    SSAOp::MemoryCopy(dst, src, d_, s, l) =>
      TInstr::memory_copy(dst, src, get(d, d_), get(d, s), get(d, l))
    SSAOp::MemoryInit(data, mem, dest, src, len) =>
      TInstr::memory_init(data, mem, get(d, dest), get(d, src), get(d, len))
    SSAOp::DataDrop(idx) => TInstr::data_drop(idx)
    SSAOp::TableSize(idx) => TInstr::table_size(idx)
    SSAOp::TableGet(idx, i) => TInstr::table_get(idx, get(d, i))
    SSAOp::TableSet(idx, i, v) => TInstr::table_set(idx, get(d, i), get(d, v))
    SSAOp::TableGrow(idx, v, n) => TInstr::table_grow(idx, get(d, v), get(d, n))
    SSAOp::TableFill(idx, i, v, n) =>
      TInstr::table_fill(idx, get(d, i), get(d, v), get(d, n))
    SSAOp::TableCopy(dst, src, d_, s, n) =>
      TInstr::table_copy(dst, src, get(d, d_), get(d, s), get(d, n))
    SSAOp::TableInit(elem, table, dest, src, n) =>
      TInstr::table_init(elem, table, get(d, dest), get(d, src), get(d, n))
    SSAOp::ElemDrop(idx) => TInstr::elem_drop(idx)
    SSAOp::Call(func, args) => TInstr::call(func, get_args(d, args))
    SSAOp::CallIndirect(ty, table, args, idx) =>
      TInstr::call_indirect(ty, table, get_args(d, args), get(d, idx))
    SSAOp::CallRef(ty, args, func) =>
      TInstr::call_ref(ty, get_args(d, args), get(d, func))
    SSAOp::RefIsNull(v) => TInstr::ref_is_null(get(d, v))
    SSAOp::RefEq(a, b) => TInstr::ref_eq(get(d, a), get(d, b))
    SSAOp::RefAsNonNull(v) => TInstr::ref_as_non_null(get(d, v))
    SSAOp::RefI31(v) => TInstr::ref_i31(get(d, v))
    SSAOp::I31GetS(v) => TInstr::i31_get_s(get(d, v))
    SSAOp::I31GetU(v) => TInstr::i31_get_u(get(d, v))
    SSAOp::RefTest(nullable, ht, v) => TInstr::ref_test(nullable, ht, get(d, v))
    SSAOp::RefCast(nullable, ht, v) => TInstr::ref_cast(nullable, ht, get(d, v))
    SSAOp::AnyConvertExtern(v) => TInstr::any_convert_extern(get(d, v))
    SSAOp::ExternConvertAny(v) => TInstr::extern_convert_any(get(d, v))
    SSAOp::StructNew(ty, args) => TInstr::struct_new(ty, get_args(d, args))
    SSAOp::StructNewDefault(ty) => TInstr::struct_new_default(ty)
    SSAOp::StructGet(ty, field, v) => TInstr::struct_get(ty, field, get(d, v))
    SSAOp::StructGetS(ty, field, v) =>
      TInstr::struct_get_s(ty, field, get(d, v))
    SSAOp::StructGetU(ty, field, v) =>
      TInstr::struct_get_u(ty, field, get(d, v))
    SSAOp::StructSet(ty, field, obj, val) =>
      TInstr::struct_set(ty, field, get(d, obj), get(d, val))
    SSAOp::ArrayNew(ty, val, len) =>
      TInstr::array_new(ty, get(d, val), get(d, len))
    SSAOp::ArrayNewDefault(ty, len) =>
      TInstr::array_new_default(ty, get(d, len))
    SSAOp::ArrayNewFixed(ty, args) =>
      TInstr::array_new_fixed(ty, get_args(d, args))
    SSAOp::ArrayNewData(ty, data, off, len) =>
      TInstr::array_new_data(ty, data, get(d, off), get(d, len))
    SSAOp::ArrayNewElem(ty, elem, off, len) =>
      TInstr::array_new_elem(ty, elem, get(d, off), get(d, len))
    SSAOp::ArrayGet(ty, arr, idx) =>
      TInstr::array_get(ty, get(d, arr), get(d, idx))
    SSAOp::ArrayGetS(ty, arr, idx) =>
      TInstr::array_get_s(ty, get(d, arr), get(d, idx))
    SSAOp::ArrayGetU(ty, arr, idx) =>
      TInstr::array_get_u(ty, get(d, arr), get(d, idx))
    SSAOp::ArraySet(ty, arr, idx, val) =>
      TInstr::array_set(ty, get(d, arr), get(d, idx), get(d, val))
    SSAOp::ArrayLen(v) => TInstr::array_len(get(d, v))
    SSAOp::ArrayFill(ty, arr, off, val, len) =>
      TInstr::array_fill(ty, get(d, arr), get(d, off), get(d, val), get(d, len))
    SSAOp::ArrayCopy(dst_ty, src_ty, dst, d_off, src, s_off, len) =>
      TInstr::array_copy(
        dst_ty,
        src_ty,
        get(d, dst),
        get(d, d_off),
        get(d, src),
        get(d, s_off),
        get(d, len),
      )
    SSAOp::ArrayInitData(ty, data, arr, a_off, d_off, len) =>
      TInstr::array_init_data(
        ty,
        data,
        get(d, arr),
        get(d, a_off),
        get(d, d_off),
        get(d, len),
      )
    SSAOp::ArrayInitElem(ty, elem, arr, a_off, e_off, len) =>
      TInstr::array_init_elem(
        ty,
        elem,
        get(d, arr),
        get(d, a_off),
        get(d, e_off),
        get(d, len),
      )
    SSAOp::Throw(tag, args) => TInstr::throw_(tag, get_args(d, args))
    SSAOp::Splat(splat_op, v) =>
      match splat_op {
        SplatOp::I8x16Splat => TInstr::i8x16_splat(get(d, v))
        SplatOp::I16x8Splat => TInstr::i16x8_splat(get(d, v))
        SplatOp::I32x4Splat => TInstr::i32x4_splat(get(d, v))
        SplatOp::I64x2Splat => TInstr::i64x2_splat(get(d, v))
        SplatOp::F32x4Splat => TInstr::f32x4_splat(get(d, v))
        SplatOp::F64x2Splat => TInstr::f64x2_splat(get(d, v))
      }
    SSAOp::ExtractLane(op, lane, v) => TInstr::extract_lane(op, lane, get(d, v))
    SSAOp::ReplaceLane(op, lane, vec, val) =>
      TInstr::replace_lane(op, lane, get(d, vec), get(d, val))
    SSAOp::Shuffle(lanes, a, b) =>
      TInstr::i8x16_shuffle(
        lanes[0],
        lanes[1],
        lanes[2],
        lanes[3],
        lanes[4],
        lanes[5],
        lanes[6],
        lanes[7],
        lanes[8],
        lanes[9],
        lanes[10],
        lanes[11],
        lanes[12],
        lanes[13],
        lanes[14],
        lanes[15],
        get(d, a),
        get(d, b),
      )
    SSAOp::Swizzle(a, b) => TInstr::i8x16_swizzle(get(d, a), get(d, b))
    SSAOp::V128Shift(op, v, s) => TInstr::v128_shift(op, get(d, v), get(d, s))
    SSAOp::V128Ternary(op, a, b, c) =>
      TInstr::v128_ternary(op, get(d, a), get(d, b), get(d, c))
    SSAOp::V128LoadLane(op, memarg, lane, addr, vec) =>
      TInstr::v128_load_lane(op, memarg, lane, get(d, addr), get(d, vec))
    SSAOp::V128StoreLane(op, memarg, lane, addr, vec) =>
      TInstr::v128_store_lane(op, memarg, lane, get(d, addr), get(d, vec))
  }
}

///|
fn convert_ssa_terminator(
  term : SSATerminator,
  d : SSADestructor,
) -> Terminator {
  fn get(v : SSAValue) -> TInstr {
    TInstr::local_get(d.get_local(v))
  }

  fn get_all(vals : Array[SSAValue]) -> Array[TInstr] {
    vals.map(fn(v) { get(v) })
  }

  match term {
    Br(target) => Terminator::Br(target)
    Unreachable => Terminator::Unreachable
    BrIf(cond, t, f) => Terminator::BrIf(get(cond), t, f)
    BrTable(cond, targets, def) => Terminator::BrTable(get(cond), targets, def)
    BrOnNull(val, t, f) => Terminator::BrOnNull(get(val), t, f)
    BrOnNonNull(val, t, f) => Terminator::BrOnNonNull(get(val), t, f)
    BrOnCast(op, ht1, ht2, val, t, f) =>
      Terminator::BrOnCast(op, ht1, ht2, get(val), t, f)
    BrOnCastFail(op, ht1, ht2, val, t, f) =>
      Terminator::BrOnCastFail(op, ht1, ht2, get(val), t, f)
    Return(vals) => Terminator::Return(get_all(vals))
    ReturnCall(func, args) => Terminator::ReturnCall(func, get_all(args))
    ReturnCallIndirect(ty, table, args, idx) =>
      Terminator::ReturnCallIndirect(ty, table, get_all(args), get(idx))
    ReturnCallRef(ty, args, func) =>
      Terminator::ReturnCallRef(ty, get_all(args), get(func))
    ThrowRef(val) => Terminator::ThrowRef(get(val))
  }
}
