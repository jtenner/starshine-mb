fn GVNState::new() -> GVNState {
  GVNState::{
    value_map: Map::new(),
    replacements: Map::new(),
  }
}

fn GVNState::lookup_or_add(self : GVNState, key : GVNKey, val : SSAValue) -> SSAValue {
  match self.value_map.get(key) {
    Some(existing) => {
      self.replacements[val] = existing
      existing
    }
    None => {
      self.value_map[key] = val
      val
    }
  }
}

fn GVNState::resolve(self : GVNState, val : SSAValue) -> SSAValue {
  match self.replacements.get(val) {
    Some(replacement) => self.resolve(replacement)
    None => val
  }
}

/// Extract GVN key from an operation (if it's a pure operation)
fn op_to_gvn_key(op : SSAOp, state : GVNState) -> GVNKey? {
  match op {
    SSAOp::I32Const(c) => Some(GVNKey::Const32(c.0))
    SSAOp::I64Const(c) => Some(GVNKey::Const64(c.0))
    SSAOp::F32Const(c) => Some(GVNKey::ConstF32(c.0))
    SSAOp::F64Const(c) => Some(GVNKey::ConstF64(c.0))
    SSAOp::RefNull(ht) => Some(GVNKey::RefNull(ht))
    SSAOp::RefFunc(idx) => Some(GVNKey::RefFunc(idx))
    SSAOp::Unary(op, v) => Some(GVNKey::Unary(op, state.resolve(v)))
    SSAOp::Binary(op, a, b) => {
      let ra = state.resolve(a)
      let rb = state.resolve(b)
      // Canonicalize commutative operations
      let (a_canon, b_canon) = if is_commutative(op) && ra.0 > rb.0 {
        (rb, ra)
      } else {
        (ra, rb)
      }
      Some(GVNKey::Binary(op, a_canon, b_canon))
    }
    // Note: Loads are tricky - only safe if we track memory state
    // For now, skip loads to be conservative
    SSAOp::StructGet(ty, field, v) => Some(GVNKey::StructGet(ty, field, state.resolve(v)))
    SSAOp::ArrayGet(ty, arr, idx) => 
      Some(GVNKey::ArrayGet(ty, state.resolve(arr), state.resolve(idx)))
    // Skip operations with side effects or that depend on mutable state
    _ => None
  }
}

fn is_commutative(op : BinaryOp) -> Bool {
  match op {
    I32AddOp | I32MulOp | I32AndOp | 
    I32OrOp | I32XorOp | I32EqOp | I32NeOp |
    I64AddOp | I64MulOp | I64AndOp |
    I64OrOp | I64XorOp | I64EqOp | I64NeOp |
    F32AddOp | F32MulOp | F32EqOp | F32NeOp |
    F64AddOp | F64MulOp | F64EqOp | F64NeOp => true
    _ => false
  }
}

/// Apply GVN replacements to an SSAOp, returning the rewritten op
fn apply_gvn_to_op(op : SSAOp, state : GVNState) -> SSAOp {
  fn r(v : SSAValue) -> SSAValue {
    state.resolve(v)
  }
  
  fn r_args(args : Array[SSAValue]) -> Array[SSAValue] {
    args.map(fn(v) { r(v) })
  }
  
  match op {
    SSAOp::Copy(v) => SSAOp::Copy(r(v))
    SSAOp::I32Const(_) | SSAOp::I64Const(_) | SSAOp::F32Const(_) | 
    SSAOp::F64Const(_) | SSAOp::V128Const(_) | SSAOp::RefNull(_) | 
    SSAOp::RefFunc(_) | SSAOp::GlobalGet(_) | SSAOp::MemorySize(_) | 
    SSAOp::TableSize(_) | SSAOp::DataDrop(_) | SSAOp::ElemDrop(_) |
    SSAOp::StructNewDefault(_) => op
    
    SSAOp::Unary(unop, v) => SSAOp::Unary(unop, r(v))
    SSAOp::Binary(binop, a, b) => SSAOp::Binary(binop, r(a), r(b))
    SSAOp::Select(tys, a, b, c) => SSAOp::Select(tys, r(a), r(b), r(c))
    
    SSAOp::GlobalSet(idx, v) => SSAOp::GlobalSet(idx, r(v))
    SSAOp::Load(lop, memarg, addr) => SSAOp::Load(lop, memarg, r(addr))
    SSAOp::Store(sop, memarg, addr, val) => SSAOp::Store(sop, memarg, r(addr), r(val))
    SSAOp::MemoryGrow(idx, v) => SSAOp::MemoryGrow(idx, r(v))
    SSAOp::MemoryFill(idx, d, v, l) => SSAOp::MemoryFill(idx, r(d), r(v), r(l))
    SSAOp::MemoryCopy(di, si, d, s, l) => SSAOp::MemoryCopy(di, si, r(d), r(s), r(l))
    SSAOp::MemoryInit(data, mem, d, s, l) => SSAOp::MemoryInit(data, mem, r(d), r(s), r(l))
    
    SSAOp::TableGet(idx, i) => SSAOp::TableGet(idx, r(i))
    SSAOp::TableSet(idx, i, v) => SSAOp::TableSet(idx, r(i), r(v))
    SSAOp::TableGrow(idx, v, n) => SSAOp::TableGrow(idx, r(v), r(n))
    SSAOp::TableFill(idx, i, v, n) => SSAOp::TableFill(idx, r(i), r(v), r(n))
    SSAOp::TableCopy(di, si, d, s, n) => SSAOp::TableCopy(di, si, r(d), r(s), r(n))
    SSAOp::TableInit(elem, table, d, s, n) => SSAOp::TableInit(elem, table, r(d), r(s), r(n))
    
    SSAOp::Call(func, args) => SSAOp::Call(func, r_args(args))
    SSAOp::CallIndirect(ty, table, args, idx) => 
      SSAOp::CallIndirect(ty, table, r_args(args), r(idx))
    SSAOp::CallRef(ty, args, func) => SSAOp::CallRef(ty, r_args(args), r(func))
    
    SSAOp::RefIsNull(v) => SSAOp::RefIsNull(r(v))
    SSAOp::RefEq(a, b) => SSAOp::RefEq(r(a), r(b))
    SSAOp::RefAsNonNull(v) => SSAOp::RefAsNonNull(r(v))
    SSAOp::RefI31(v) => SSAOp::RefI31(r(v))
    SSAOp::I31GetS(v) => SSAOp::I31GetS(r(v))
    SSAOp::I31GetU(v) => SSAOp::I31GetU(r(v))
    SSAOp::RefTest(nullable, ht, v) => SSAOp::RefTest(nullable, ht, r(v))
    SSAOp::RefCast(nullable, ht, v) => SSAOp::RefCast(nullable, ht, r(v))
    SSAOp::AnyConvertExtern(v) => SSAOp::AnyConvertExtern(r(v))
    SSAOp::ExternConvertAny(v) => SSAOp::ExternConvertAny(r(v))
    
    SSAOp::StructNew(ty, args) => SSAOp::StructNew(ty, r_args(args))
    SSAOp::StructGet(ty, field, v) => SSAOp::StructGet(ty, field, r(v))
    SSAOp::StructGetS(ty, field, v) => SSAOp::StructGetS(ty, field, r(v))
    SSAOp::StructGetU(ty, field, v) => SSAOp::StructGetU(ty, field, r(v))
    SSAOp::StructSet(ty, field, o, v) => SSAOp::StructSet(ty, field, r(o), r(v))
    
    SSAOp::ArrayNew(ty, v, l) => SSAOp::ArrayNew(ty, r(v), r(l))
    SSAOp::ArrayNewDefault(ty, l) => SSAOp::ArrayNewDefault(ty, r(l))
    SSAOp::ArrayNewFixed(ty, args) => SSAOp::ArrayNewFixed(ty, r_args(args))
    SSAOp::ArrayNewData(ty, data, o, l) => SSAOp::ArrayNewData(ty, data, r(o), r(l))
    SSAOp::ArrayNewElem(ty, elem, o, l) => SSAOp::ArrayNewElem(ty, elem, r(o), r(l))
    SSAOp::ArrayGet(ty, arr, idx) => SSAOp::ArrayGet(ty, r(arr), r(idx))
    SSAOp::ArrayGetS(ty, arr, idx) => SSAOp::ArrayGetS(ty, r(arr), r(idx))
    SSAOp::ArrayGetU(ty, arr, idx) => SSAOp::ArrayGetU(ty, r(arr), r(idx))
    SSAOp::ArraySet(ty, arr, idx, v) => SSAOp::ArraySet(ty, r(arr), r(idx), r(v))
    SSAOp::ArrayLen(v) => SSAOp::ArrayLen(r(v))
    SSAOp::ArrayFill(ty, arr, o, v, l) => SSAOp::ArrayFill(ty, r(arr), r(o), r(v), r(l))
    SSAOp::ArrayCopy(dty, sty, d, doff, s, soff, l) => 
      SSAOp::ArrayCopy(dty, sty, r(d), r(doff), r(s), r(soff), r(l))
    SSAOp::ArrayInitData(ty, data, arr, ao, do_, l) =>
      SSAOp::ArrayInitData(ty, data, r(arr), r(ao), r(do_), r(l))
    SSAOp::ArrayInitElem(ty, elem, arr, ao, eo, l) =>
      SSAOp::ArrayInitElem(ty, elem, r(arr), r(ao), r(eo), r(l))
    
    SSAOp::Splat(sop, v) => SSAOp::Splat(sop, r(v))
    SSAOp::ExtractLane(eop, lane, v) => SSAOp::ExtractLane(eop, lane, r(v))
    SSAOp::ReplaceLane(rop, lane, vec, val) => SSAOp::ReplaceLane(rop, lane, r(vec), r(val))
    SSAOp::Shuffle(lanes, a, b) => SSAOp::Shuffle(lanes, r(a), r(b))
    SSAOp::Swizzle(a, b) => SSAOp::Swizzle(r(a), r(b))
    SSAOp::V128Shift(sop, v, s) => SSAOp::V128Shift(sop, r(v), r(s))
    SSAOp::V128Ternary(top, a, b, c) => SSAOp::V128Ternary(top, r(a), r(b), r(c))
    SSAOp::V128LoadLane(lop, memarg, lane, addr, vec) =>
      SSAOp::V128LoadLane(lop, memarg, lane, r(addr), r(vec))
    SSAOp::V128StoreLane(sop, memarg, lane, addr, vec) =>
      SSAOp::V128StoreLane(sop, memarg, lane, r(addr), r(vec))
    
    SSAOp::Throw(tag, args) => SSAOp::Throw(tag, r_args(args))
  }
}

/// Apply GVN replacements to a terminator
fn apply_gvn_to_terminator(term : SSATerminator, state : GVNState) -> SSATerminator {
  fn r(v : SSAValue) -> SSAValue {
    state.resolve(v)
  }
  
  fn r_args(args : Array[SSAValue]) -> Array[SSAValue] {
    args.map(fn(v) { r(v) })
  }
  
  match term {
    SSATerminator::Br(_) | SSATerminator::Unreachable => term
    SSATerminator::BrIf(cond, t, f) => SSATerminator::BrIf(r(cond), t, f)
    SSATerminator::BrTable(cond, targets, def) => SSATerminator::BrTable(r(cond), targets, def)
    SSATerminator::BrOnNull(v, null_t, nonnull_t) => 
      SSATerminator::BrOnNull(r(v), null_t, nonnull_t)
    SSATerminator::BrOnNonNull(v, nonnull_t, null_t) =>
      SSATerminator::BrOnNonNull(r(v), nonnull_t, null_t)
    SSATerminator::BrOnCast(cop, ht1, ht2, v, succ, fail) =>
      SSATerminator::BrOnCast(cop, ht1, ht2, r(v), succ, fail)
    SSATerminator::BrOnCastFail(cop, ht1, ht2, v, succ, fail) =>
      SSATerminator::BrOnCastFail(cop, ht1, ht2, r(v), succ, fail)
    SSATerminator::Return(vals) => SSATerminator::Return(r_args(vals))
    SSATerminator::ReturnCall(func, args) => SSATerminator::ReturnCall(func, r_args(args))
    SSATerminator::ReturnCallIndirect(ty, table, args, idx) =>
      SSATerminator::ReturnCallIndirect(ty, table, r_args(args), r(idx))
    SSATerminator::ReturnCallRef(ty, args, func) =>
      SSATerminator::ReturnCallRef(ty, r_args(args), r(func))
    SSATerminator::ThrowRef(v) => SSATerminator::ThrowRef(r(v))
  }
}

/// Apply GVN replacements to phi node arguments
fn apply_gvn_to_phi(phi : PhiNode, state : GVNState) -> PhiNode {
  let new_args : Map[BlockId, SSAValue] = Map::new()
  for entry in phi.args {
    let (pred, val) = entry
    new_args[pred] = state.resolve(val)
  }
  PhiNode::{
    local_idx: phi.local_idx,
    result: phi.result,
    args: new_args,
  }
}

/// Check if an operation has side effects (and thus can't be eliminated)
fn has_side_effects(op : SSAOp) -> Bool {
  match op {
    // Pure operations - no side effects
    SSAOp::I32Const(_) | SSAOp::I64Const(_) | SSAOp::F32Const(_) | SSAOp::F64Const(_) |
    SSAOp::V128Const(_) | SSAOp::RefNull(_) | SSAOp::RefFunc(_) | SSAOp::Copy(_) |
    SSAOp::Unary(_, _) | SSAOp::Binary(_, _, _) | SSAOp::Select(_, _, _, _) |
    SSAOp::RefIsNull(_) | SSAOp::RefEq(_, _) | SSAOp::RefI31(_) |
    SSAOp::I31GetS(_) | SSAOp::I31GetU(_) | SSAOp::RefTest(_, _, _) |
    SSAOp::AnyConvertExtern(_) | SSAOp::ExternConvertAny(_) |
    SSAOp::Splat(_, _) | SSAOp::ExtractLane(_, _, _) | SSAOp::ReplaceLane(_, _, _, _) |
    SSAOp::Shuffle(_, _, _) | SSAOp::Swizzle(_, _) | SSAOp::V128Shift(_, _, _) |
    SSAOp::V128Ternary(_, _, _, _) => false
    
    // Reads from global state - pure but depend on mutable state
    SSAOp::GlobalGet(_) | SSAOp::MemorySize(_) | SSAOp::TableSize(_) => false
    
    // These can trap, so conservatively treat as having effects
    SSAOp::RefAsNonNull(_) | SSAOp::RefCast(_, _, _) => true
    
    // Memory/table reads can trap on out-of-bounds
    SSAOp::Load(_, _, _) | SSAOp::TableGet(_, _) |
    SSAOp::StructGet(_, _, _) | SSAOp::StructGetS(_, _, _) | SSAOp::StructGetU(_, _, _) |
    SSAOp::ArrayGet(_, _, _) | SSAOp::ArrayGetS(_, _, _) | SSAOp::ArrayGetU(_, _, _) |
    SSAOp::ArrayLen(_) | SSAOp::V128LoadLane(_, _, _, _, _) => true
    
    // All writes have side effects
    SSAOp::GlobalSet(_, _) | SSAOp::Store(_, _, _, _) |
    SSAOp::MemoryGrow(_, _) | SSAOp::MemoryFill(_, _, _, _) |
    SSAOp::MemoryCopy(_, _, _, _, _) | SSAOp::MemoryInit(_, _, _, _, _) |
    SSAOp::DataDrop(_) | SSAOp::TableSet(_, _, _) | SSAOp::TableGrow(_, _, _) |
    SSAOp::TableFill(_, _, _, _) | SSAOp::TableCopy(_, _, _, _, _) |
    SSAOp::TableInit(_, _, _, _, _) | SSAOp::ElemDrop(_) |
    SSAOp::StructSet(_, _, _, _) | SSAOp::ArraySet(_, _, _, _) |
    SSAOp::ArrayFill(_, _, _, _, _) | SSAOp::ArrayCopy(_, _, _, _, _, _, _) |
    SSAOp::ArrayInitData(_, _, _, _, _, _) | SSAOp::ArrayInitElem(_, _, _, _, _, _) |
    SSAOp::V128StoreLane(_, _, _, _, _) => true
    
    // Calls always have potential side effects
    SSAOp::Call(_, _) | SSAOp::CallIndirect(_, _, _, _) | SSAOp::CallRef(_, _, _) => true
    
    // Allocations have effects (even if pure from a value perspective)
    SSAOp::StructNew(_, _) | SSAOp::StructNewDefault(_) |
    SSAOp::ArrayNew(_, _, _) | SSAOp::ArrayNewDefault(_, _) |
    SSAOp::ArrayNewFixed(_, _) | SSAOp::ArrayNewData(_, _, _, _) |
    SSAOp::ArrayNewElem(_, _, _, _) => true
    
    // Exceptions
    SSAOp::Throw(_, _) => true
  }
}

/// Invalidates GVN entries that might be affected by a side-effecting operation
fn invalidate_for_side_effects(op : SSAOp, state : GVNState) -> Unit {
  match op {
    // Memory writes invalidate all loads
    SSAOp::Store(_, _, _, _) | SSAOp::MemoryFill(_, _, _, _) |
    SSAOp::MemoryCopy(_, _, _, _, _) | SSAOp::MemoryInit(_, _, _, _, _) => {
      // Remove all Load keys from value_map
      let keys_to_remove : Array[GVNKey] = []
      for entry in state.value_map {
        let (key, _) = entry
        if key is GVNKey::Load(_, _, _) {
          keys_to_remove.push(key)
        }
      }
      for key in keys_to_remove {
        state.value_map.remove(key)
      }
    }
    
    // Struct writes invalidate struct reads of same type/field
    SSAOp::StructSet(ty, field, _, _) => {
      let keys_to_remove : Array[GVNKey] = []
      for entry in state.value_map {
        let (key, _) = entry
        if key is GVNKey::StructGet(t, f, _) && t == ty && f == field {
          keys_to_remove.push(key)
        }
      }
      for key in keys_to_remove {
        state.value_map.remove(key)
      }
    }
    
    // Array writes invalidate array reads of same type
    SSAOp::ArraySet(ty, _, _, _) | SSAOp::ArrayFill(ty, _, _, _, _) |
    SSAOp::ArrayCopy(ty, _, _, _, _, _, _) |
    SSAOp::ArrayInitData(ty, _, _, _, _, _) | SSAOp::ArrayInitElem(ty, _, _, _, _, _) => {
      let keys_to_remove : Array[GVNKey] = []
      for entry in state.value_map {
        let (key, _) = entry
        if key is GVNKey::ArrayGet(t, _, _) && t == ty {
          keys_to_remove.push(key)
        }
      }
      for key in keys_to_remove {
        state.value_map.remove(key)
      }
    }
    
    // Global writes invalidate that global's reads
    SSAOp::GlobalSet(idx, _) => {
      state.value_map.remove(GVNKey::GlobalGet(idx))
    }
    
    // Calls can do anything - be conservative
    SSAOp::Call(_, _) | SSAOp::CallIndirect(_, _, _, _) | SSAOp::CallRef(_, _, _) => {
      // Invalidate all non-constant entries
      let keys_to_remove : Array[GVNKey] = []
      for entry in state.value_map {
        let (key, _) = entry
        match key {
          GVNKey::Const32(_) | GVNKey::Const64(_) | GVNKey::ConstF32(_) |
          GVNKey::ConstF64(_) | GVNKey::RefNull(_) | GVNKey::RefFunc(_) => ()
          _ => keys_to_remove.push(key)
        }
      }
      for key in keys_to_remove {
        state.value_map.remove(key)
      }
    }
    
    _ => ()
  }
}

/// Process a single block for GVN
fn gvn_block(
  block : SSABlock,
  state : GVNState,
) -> SSABlock {
  let new_instrs : Array[SSAInstr] = []
  
  for instr in block.instrs {
    match instr {
      SSAInstr::Assign(result, op) => {
        // First apply existing replacements to the op
        let resolved_op = apply_gvn_to_op(op, state)
        
        // Try to find an existing value number for this expression
        match op_to_gvn_key(resolved_op, state) {
          Some(key) => {
            // Look up or add to value numbering
            let canonical = state.lookup_or_add(key, result)
            if canonical == result {
              // This is a new expression, emit it
              new_instrs.push(SSAInstr::Assign(result, resolved_op))
            }
            // If canonical != result, we found a duplicate - don't emit,
            // future uses of result will be replaced with canonical
          }
          None => {
            // Not a pure expression we can value-number
            // Check for side effects that invalidate cached values
            if has_side_effects(resolved_op) {
              invalidate_for_side_effects(resolved_op, state)
            }
            new_instrs.push(SSAInstr::Assign(result, resolved_op))
          }
        }
      }
      SSAInstr::Effect(op) => {
        let resolved_op = apply_gvn_to_op(op, state)
        if has_side_effects(resolved_op) {
          invalidate_for_side_effects(resolved_op, state)
        }
        new_instrs.push(SSAInstr::Effect(resolved_op))
      }
    }
  }
  
  // Apply replacements to phis
  let new_phis = block.phis.map(fn(phi) { apply_gvn_to_phi(phi, state) })
  
  // Apply replacements to terminator
  let new_term = apply_gvn_to_terminator(block.terminator, state)
  
  SSABlock::{
    id: block.id,
    phis: new_phis,
    instrs: new_instrs,
    terminator: new_term,
  }
}

/// Build dominator tree children map
fn build_dom_children(
  cfg : SSACFG,
  idom : Map[BlockId, BlockId],
) -> Map[BlockId, Array[BlockId]] {
  let children : Map[BlockId, Array[BlockId]] = Map::new()
  
  // Initialize empty arrays for all blocks
  for entry in cfg.blocks {
    let (id, _) = entry
    children[id] = []
  }
  
  // Build parent -> children mapping
  for entry in idom {
    let (child, parent) = entry
    if child != parent {  // Skip self-loops (entry block)
      children.get_or_init(parent, fn() { [] }).push(child)
    }
  }
  
  children
}

/// Run GVN on the entire CFG using dominator tree traversal
pub fn run_gvn(cfg : SSACFG, idom : Map[BlockId, BlockId]) -> SSACFG {
  let dom_children = build_dom_children(cfg, idom)
  let state = GVNState::new()
  let new_blocks : Map[BlockId, SSABlock] = Map::new()
  
  // Process blocks in dominator tree order (DFS)
  fn process_block(
    block_id : BlockId,
    cfg : SSACFG,
    dom_children : Map[BlockId, Array[BlockId]],
    state : GVNState,
    new_blocks : Map[BlockId, SSABlock],
  ) -> Unit {
    match cfg.blocks.get(block_id) {
      Some(block) => {
        // Save state before processing this subtree
        let saved_map : Map[GVNKey, SSAValue] = Map::new()
        for entry in state.value_map {
          let (k, v) = entry
          saved_map[k] = v
        }
        let saved_replacements : Map[SSAValue, SSAValue] = Map::new()
        for entry in state.replacements {
          let (k, v) = entry
          saved_replacements[k] = v
        }
        
        // Process this block
        let new_block = gvn_block(block, state)
        new_blocks[block_id] = new_block
        
        // Process dominated children
        match dom_children.get(block_id) {
          Some(children) => {
            for child in children {
              process_block(child, cfg, dom_children, state, new_blocks)
            }
          }
          None => ()
        }
        
        // Restore state (values added by this block shouldn't be visible to siblings)
        state.value_map.clear()
        for entry in saved_map {
          let (k, v) = entry
          state.value_map[k] = v
        }
        // Keep replacements - they're global
      }
      None => ()
    }
  }
  
  process_block(cfg.entry, cfg, dom_children, state, new_blocks)
  
  SSACFG::{
    entry: cfg.entry,
    blocks: new_blocks,
    preds: cfg.preds,
    param_values: cfg.param_values,
    next_value: cfg.next_value,
  }
}