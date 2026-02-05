

/// Collect all values used in an SSAOp
fn collect_op_values(op : SSAOp, out : Set[SSAValue]) -> Unit {
  match op {
    SSAOp::Copy(v) => { out.add(v) }
    SSAOp::Unary(_, v) => { out.add(v) }
    SSAOp::Binary(_, a, b) => { out.add(a); out.add(b) }
    SSAOp::Select(_, a, b, c) => { out.add(a); out.add(b); out.add(c) }
    SSAOp::GlobalSet(_, v) => { out.add(v) }
    SSAOp::Load(_, _, addr) => { out.add(addr) }
    SSAOp::Store(_, _, addr, val) => { out.add(addr); out.add(val) }
    SSAOp::MemoryGrow(_, v) => { out.add(v) }
    SSAOp::MemoryFill(_, d, v, l) => { out.add(d); out.add(v); out.add(l) }
    SSAOp::MemoryCopy(_, _, d, s, l) => { out.add(d); out.add(s); out.add(l) }
    SSAOp::MemoryInit(_, _, d, s, l) => { out.add(d); out.add(s); out.add(l) }
    SSAOp::TableGet(_, i) => { out.add(i) }
    SSAOp::TableSet(_, i, v) => { out.add(i); out.add(v) }
    SSAOp::TableGrow(_, v, n) => { out.add(v); out.add(n) }
    SSAOp::TableFill(_, i, v, n) => { out.add(i); out.add(v); out.add(n) }
    SSAOp::TableCopy(_, _, d, s, n) => { out.add(d); out.add(s); out.add(n) }
    SSAOp::TableInit(_, _, d, s, n) => { out.add(d); out.add(s); out.add(n) }
    SSAOp::Call(_, args) => { for a in args { out.add(a) } }
    SSAOp::CallIndirect(_, _, args, idx) => { 
      for a in args { out.add(a) }
      out.add(idx)
    }
    SSAOp::CallRef(_, args, func) => {
      for a in args { out.add(a) }
      out.add(func)
    }
    SSAOp::RefIsNull(v) | SSAOp::RefAsNonNull(v) | SSAOp::RefI31(v) |
    SSAOp::I31GetS(v) | SSAOp::I31GetU(v) | SSAOp::RefTest(_, _, v) |
    SSAOp::RefCast(_, _, v) | SSAOp::AnyConvertExtern(v) | SSAOp::ExternConvertAny(v) => {
      out.add(v)
    }
    SSAOp::RefEq(a, b) => { out.add(a); out.add(b) }
    SSAOp::StructNew(_, args) => { for a in args { out.add(a) } }
    SSAOp::StructGet(_, _, v) | SSAOp::StructGetS(_, _, v) | SSAOp::StructGetU(_, _, v) => {
      out.add(v)
    }
    SSAOp::StructSet(_, _, o, v) => { out.add(o); out.add(v) }
    SSAOp::ArrayNew(_, v, l) => { out.add(v); out.add(l) }
    SSAOp::ArrayNewDefault(_, l) => { out.add(l) }
    SSAOp::ArrayNewFixed(_, args) => { for a in args { out.add(a) } }
    SSAOp::ArrayNewData(_, _, o, l) | SSAOp::ArrayNewElem(_, _, o, l) => {
      out.add(o); out.add(l)
    }
    SSAOp::ArrayGet(_, a, i) | SSAOp::ArrayGetS(_, a, i) | SSAOp::ArrayGetU(_, a, i) => {
      out.add(a); out.add(i)
    }
    SSAOp::ArraySet(_, a, i, v) => { out.add(a); out.add(i); out.add(v) }
    SSAOp::ArrayLen(v) => { out.add(v) }
    SSAOp::ArrayFill(_, a, o, v, l) => { out.add(a); out.add(o); out.add(v); out.add(l) }
    SSAOp::ArrayCopy(_, _, d, doff, s, soff, l) => {
      out.add(d); out.add(doff); out.add(s); out.add(soff); out.add(l)
    }
    SSAOp::ArrayInitData(_, _, a, ao, do_, l) | SSAOp::ArrayInitElem(_, _, a, ao, do_, l) => {
      out.add(a); out.add(ao); out.add(do_); out.add(l)
    }
    SSAOp::Splat(_, v) => { out.add(v) }
    SSAOp::ExtractLane(_, _, v) => { out.add(v) }
    SSAOp::ReplaceLane(_, _, vec, val) => { out.add(vec); out.add(val) }
    SSAOp::Shuffle(_, a, b) | SSAOp::Swizzle(a, b) => { out.add(a); out.add(b) }
    SSAOp::V128Shift(_, v, s) => { out.add(v); out.add(s) }
    SSAOp::V128Ternary(_, a, b, c) => { out.add(a); out.add(b); out.add(c) }
    SSAOp::V128LoadLane(_, _, _, addr, vec) | SSAOp::V128StoreLane(_, _, _, addr, vec) => {
      out.add(addr); out.add(vec)
    }
    SSAOp::Throw(_, args) => { for a in args { out.add(a) } }
    // No uses
    SSAOp::I32Const(_) | SSAOp::I64Const(_) | SSAOp::F32Const(_) | SSAOp::F64Const(_) |
    SSAOp::V128Const(_) | SSAOp::RefNull(_) | SSAOp::RefFunc(_) | SSAOp::GlobalGet(_) |
    SSAOp::MemorySize(_) | SSAOp::TableSize(_) | SSAOp::DataDrop(_) | SSAOp::ElemDrop(_) |
    SSAOp::StructNewDefault(_) => ()
  }
}

/// Collect all values used in a terminator
fn collect_terminator_values(term : SSATerminator, out : Set[SSAValue]) -> Unit {
  match term {
    SSATerminator::Br(_) | SSATerminator::Unreachable => ()
    SSATerminator::BrIf(cond, _, _) => { out.add(cond) }
    SSATerminator::BrTable(cond, _, _) => { out.add(cond) }
    SSATerminator::BrOnNull(v, _, _) | SSATerminator::BrOnNonNull(v, _, _) => { out.add(v) }
    SSATerminator::BrOnCast(_, _, _, v, _, _) | SSATerminator::BrOnCastFail(_, _, _, v, _, _) => {
      out.add(v)
    }
    SSATerminator::Return(vals) => { for v in vals { out.add(v) } }
    SSATerminator::ReturnCall(_, args) => { for a in args { out.add(a) } }
    SSATerminator::ReturnCallIndirect(_, _, args, idx) => {
      for a in args { out.add(a) }
      out.add(idx)
    }
    SSATerminator::ReturnCallRef(_, args, func) => {
      for a in args { out.add(a) }
      out.add(func)
    }
    SSATerminator::ThrowRef(v) => { out.add(v) }
  }
}

/// Compute use and def sets for a block
fn compute_block_use_def(
  block : SSABlock,
) -> (Set[SSAValue], Set[SSAValue]) {
  let uses : Set[SSAValue] = Set::new()
  let defs : Set[SSAValue] = Set::new()
  
  // Phi definitions
  for phi in block.phis {
    defs.add(phi.result)
  }
  
  // Instructions (process in order to get upward-exposed uses)
  for instr in block.instrs {
    match instr {
      SSAInstr::Assign(result, op) => {
        // Collect uses that aren't already defined in this block
        let op_uses : Set[SSAValue] = Set::new()
        collect_op_values(op, op_uses)
        for v in op_uses {
          if !defs.contains(v) {
            uses.add(v)
          }
        }
        defs.add(result)
      }
      SSAInstr::Effect(op) => {
        let op_uses : Set[SSAValue] = Set::new()
        collect_op_values(op, op_uses)
        for v in op_uses {
          if !defs.contains(v) {
            uses.add(v)
          }
        }
      }
    }
  }
  
  // Terminator uses
  let term_uses : Set[SSAValue] = Set::new()
  collect_terminator_values(block.terminator, term_uses)
  for v in term_uses {
    if !defs.contains(v) {
      uses.add(v)
    }
  }
  
  (uses, defs)
}

/// Get successors of an SSA block
fn get_block_successors(term : SSATerminator) -> Array[BlockId] {
  match term {
    SSATerminator::Br(t) => [t]
    SSATerminator::BrIf(_, t, f) => [t, f]
    SSATerminator::BrTable(_, targets, def) => {
      let result = targets.copy()
      result.push(def)
      result
    }
    SSATerminator::BrOnNull(_, t, f) | SSATerminator::BrOnNonNull(_, t, f) |
    SSATerminator::BrOnCast(_, _, _, _, t, f) | SSATerminator::BrOnCastFail(_, _, _, _, t, f) => {
      [t, f]
    }
    SSATerminator::Return(_) | SSATerminator::ReturnCall(_, _) |
    SSATerminator::ReturnCallIndirect(_, _, _, _) | SSATerminator::ReturnCallRef(_, _, _) |
    SSATerminator::ThrowRef(_) | SSATerminator::Unreachable => []
  }
}

/// Compute liveness using iterative dataflow analysis
pub fn compute_liveness(cfg : SSACFG) -> LivenessInfo {
  let live_in : Map[BlockId, Set[SSAValue]] = Map::new()
  let live_out : Map[BlockId, Set[SSAValue]] = Map::new()
  
  // Precompute use/def sets for each block
  let block_uses : Map[BlockId, Set[SSAValue]] = Map::new()
  let block_defs : Map[BlockId, Set[SSAValue]] = Map::new()
  
  for entry in cfg.blocks {
    let (id, block) = entry
    let (uses, defs) = compute_block_use_def(block)
    block_uses[id] = uses
    block_defs[id] = defs
    live_in[id] = Set::new()
    live_out[id] = Set::new()
  }
  
  // Add phi uses to predecessor's live_out
  // (handled specially - phi args are live at end of corresponding predecessor)
  let phi_uses : Map[BlockId, Map[BlockId, Set[SSAValue]]] = Map::new()
  for entry in cfg.blocks {
    let (id, block) = entry
    for phi in block.phis {
      for arg_entry in phi.args {
        let (pred, val) = arg_entry
        phi_uses.get_or_init(id, fn() { Map::new() })
          .get_or_init(pred, fn() { Set::new() })
          .add(val)
      }
    }
  }
  
  // Iterative dataflow
  let mut changed = true
  while changed {
    changed = false
    
    // Process all blocks (could use reverse postorder for efficiency)
    for entry in cfg.blocks {
      let (id, block) = entry
      
      // live_out[B] = union of live_in[S] for all successors S
      //             + phi uses from B in successors
      let new_out : Set[SSAValue] = Set::new()
      
      let succs = get_block_successors(block.terminator)
      for succ in succs {
        // Add successor's live_in
        match live_in.get(succ) {
          Some(succ_in) => {
            for v in succ_in {
              new_out.add(v)
            }
          }
          None => ()
        }
        
        // Add phi arguments that come from this block
        match phi_uses.get(succ) {
          Some(pred_map) => {
            match pred_map.get(id) {
              Some(vals) => {
                for v in vals {
                  new_out.add(v)
                }
              }
              None => ()
            }
          }
          None => ()
        }
      }
      
      // Check if live_out changed
      let old_out = live_out[id]
      if new_out.length() != old_out.length() {
        live_out[id] = new_out
        changed = true
      } else {
        for v in new_out {
          if !old_out.contains(v) {
            live_out[id] = new_out
            changed = true
            break
          }
        }
      }
      
      // live_in[B] = use[B] + (live_out[B] - def[B])
      let new_in : Set[SSAValue] = Set::new()
      
      // Add uses
      match block_uses.get(id) {
        Some(uses) => {
          for v in uses {
            new_in.add(v)
          }
        }
        None => ()
      }
      
      // Add live_out - def
      let defs = block_defs.get(id).unwrap_or(Set::new())
      for v in live_out[id] {
        if !defs.contains(v) {
          new_in.add(v)
        }
      }
      
      // Check if live_in changed
      let old_in = live_in[id]
      if new_in.length() != old_in.length() {
        live_in[id] = new_in
        changed = true
      } else {
        for v in new_in {
          if !old_in.contains(v) {
            live_in[id] = new_in
            changed = true
            break
          }
        }
      }
    }
  }
  
  LivenessInfo::{ live_in, live_out }
}

/// Check if a value is live at the entry of a block
pub fn LivenessInfo::is_live_in(self : LivenessInfo, block : BlockId, val : SSAValue) -> Bool {
  self.live_in.get(block).map(fn(s) { s.contains(val) }).unwrap_or(false)
}

/// Check if a value is live at the exit of a block
pub fn LivenessInfo::is_live_out(self : LivenessInfo, block : BlockId, val : SSAValue) -> Bool {
  self.live_out.get(block).map(fn(s) { s.contains(val) }).unwrap_or(false)
}

/// Get all values live at block entry
pub fn LivenessInfo::get_live_in(self : LivenessInfo, block : BlockId) -> Set[SSAValue] {
  self.live_in.get(block).unwrap_or(Set::new())
}

/// Get all values live at block exit
pub fn LivenessInfo::get_live_out(self : LivenessInfo, block : BlockId) -> Set[SSAValue] {
  self.live_out.get(block).unwrap_or(Set::new())
}