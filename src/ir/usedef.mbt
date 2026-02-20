///|
pub fn SSACFG::build_use_def(cfg : SSACFG) -> UseDefInfo {
  let defs : Map[SSAValue, (BlockId, SSADef)] = Map::new()
  let uses : Map[SSAValue, Array[SSAUse]] = Map::new()

  // Helper to record a use
  fn record_use(
    uses : Map[SSAValue, Array[SSAUse]],
    val : SSAValue,
    use_ : SSAUse,
  ) {
    uses.get_or_init(val, fn() { [] }).push(use_)
  }

  // Record parameter definitions
  for entry in cfg.param_values {
    let (local_idx, val) = entry
    defs[val] = (cfg.entry, SSADef::Param(local_idx))
    ignore(uses.get_or_init(val, fn() { [] }))
  }

  // Walk all blocks
  for entry in cfg.blocks {
    let (block_id, block) = entry

    // Record phi definitions and uses
    for phi in block.phis {
      defs[phi.result] = (block_id, SSADef::Phi(phi.local_idx))
      ignore(uses.get_or_init(phi.result, fn() { [] }))
      for arg_entry in phi.args {
        let (pred_id, val) = arg_entry
        record_use(uses, val, SSAUse::InPhi(block_id, phi.local_idx, pred_id))
      }
    }

    // Record instruction definitions and uses
    for i, instr in block.instrs {
      match instr {
        SSAInstr::Assign(result, op) => {
          defs[result] = (block_id, SSADef::Instr(i))
          ignore(uses.get_or_init(result, fn() { [] }))
          collect_op_uses(op, block_id, i, uses)
        }
        SSAInstr::Effect(op) => collect_op_uses(op, block_id, i, uses)
      }
    }

    // Record terminator uses
    collect_terminator_uses(block.terminator, block_id, uses)
  }
  UseDefInfo::{ defs, uses }
}

///|
fn collect_op_uses(
  op : SSAOp,
  block_id : BlockId,
  instr_idx : Int,
  uses : Map[SSAValue, Array[SSAUse]],
) -> Unit {
  let use_ = SSAUse::InInstr(block_id, instr_idx)
  fn record(
    uses : Map[SSAValue, Array[SSAUse]],
    val : SSAValue,
    use_ : SSAUse,
  ) {
    uses.get_or_init(val, fn() { [] }).push(use_)
  }

  match op {
    SSAOp::Copy(v) => record(uses, v, use_)
    SSAOp::Unary(_, v) => record(uses, v, use_)
    SSAOp::Binary(_, a, b) => {
      record(uses, a, use_)
      record(uses, b, use_)
    }
    SSAOp::Select(_, a, b, c) => {
      record(uses, a, use_)
      record(uses, b, use_)
      record(uses, c, use_)
    }
    SSAOp::Call(_, args) =>
      for a in args {
        record(uses, a, use_)
      }
    SSAOp::CallIndirect(_, _, args, idx) => {
      for a in args {
        record(uses, a, use_)
      }
      record(uses, idx, use_)
    }
    SSAOp::CallRef(_, args, func) => {
      for a in args {
        record(uses, a, use_)
      }
      record(uses, func, use_)
    }
    SSAOp::GlobalSet(_, v) => record(uses, v, use_)
    SSAOp::Load(_, _, addr) => record(uses, addr, use_)
    SSAOp::Store(_, _, addr, val) => {
      record(uses, addr, use_)
      record(uses, val, use_)
    }
    SSAOp::MemoryGrow(_, v) => record(uses, v, use_)
    SSAOp::MemoryAtomicNotify(_, addr, count) => {
      record(uses, addr, use_)
      record(uses, count, use_)
    }
    SSAOp::MemoryAtomicWait32(_, addr, expected, timeout)
    | SSAOp::MemoryAtomicWait64(_, addr, expected, timeout) => {
      record(uses, addr, use_)
      record(uses, expected, use_)
      record(uses, timeout, use_)
    }
    SSAOp::AtomicRmw(_, _, addr, val) => {
      record(uses, addr, use_)
      record(uses, val, use_)
    }
    SSAOp::AtomicCmpxchg(_, _, addr, expected, replacement) => {
      record(uses, addr, use_)
      record(uses, expected, use_)
      record(uses, replacement, use_)
    }
    SSAOp::MemoryFill(_, d, v, l) => {
      record(uses, d, use_)
      record(uses, v, use_)
      record(uses, l, use_)
    }
    SSAOp::MemoryCopy(_, _, d, s, l) => {
      record(uses, d, use_)
      record(uses, s, use_)
      record(uses, l, use_)
    }
    SSAOp::MemoryInit(_, _, d, s, l) => {
      record(uses, d, use_)
      record(uses, s, use_)
      record(uses, l, use_)
    }
    SSAOp::TableGet(_, i) => record(uses, i, use_)
    SSAOp::TableSet(_, i, v) => {
      record(uses, i, use_)
      record(uses, v, use_)
    }
    SSAOp::TableGrow(_, v, n) => {
      record(uses, v, use_)
      record(uses, n, use_)
    }
    SSAOp::TableFill(_, i, v, n) => {
      record(uses, i, use_)
      record(uses, v, use_)
      record(uses, n, use_)
    }
    SSAOp::TableCopy(_, _, d, s, n) => {
      record(uses, d, use_)
      record(uses, s, use_)
      record(uses, n, use_)
    }
    SSAOp::TableInit(_, _, d, s, n) => {
      record(uses, d, use_)
      record(uses, s, use_)
      record(uses, n, use_)
    }
    SSAOp::RefIsNull(v)
    | SSAOp::RefAsNonNull(v)
    | SSAOp::RefI31(v)
    | SSAOp::I31GetS(v)
    | SSAOp::I31GetU(v)
    | SSAOp::RefTest(_, _, v)
    | SSAOp::RefCast(_, _, v)
    | SSAOp::AnyConvertExtern(v)
    | SSAOp::ExternConvertAny(v) => record(uses, v, use_)
    SSAOp::RefEq(a, b) => {
      record(uses, a, use_)
      record(uses, b, use_)
    }
    SSAOp::StructNew(_, args) =>
      for a in args {
        record(uses, a, use_)
      }
    SSAOp::StructGet(_, _, v)
    | SSAOp::StructGetS(_, _, v)
    | SSAOp::StructGetU(_, _, v) => record(uses, v, use_)
    SSAOp::StructSet(_, _, o, v) => {
      record(uses, o, use_)
      record(uses, v, use_)
    }
    SSAOp::ArrayNew(_, v, l) => {
      record(uses, v, use_)
      record(uses, l, use_)
    }
    SSAOp::ArrayNewDefault(_, l) => record(uses, l, use_)
    SSAOp::ArrayNewFixed(_, args) =>
      for a in args {
        record(uses, a, use_)
      }
    SSAOp::ArrayNewData(_, _, o, l) | SSAOp::ArrayNewElem(_, _, o, l) => {
      record(uses, o, use_)
      record(uses, l, use_)
    }
    SSAOp::ArrayGet(_, a, i)
    | SSAOp::ArrayGetS(_, a, i)
    | SSAOp::ArrayGetU(_, a, i) => {
      record(uses, a, use_)
      record(uses, i, use_)
    }
    SSAOp::ArraySet(_, a, i, v) => {
      record(uses, a, use_)
      record(uses, i, use_)
      record(uses, v, use_)
    }
    SSAOp::ArrayLen(v) => record(uses, v, use_)
    SSAOp::ArrayFill(_, a, o, v, l) => {
      record(uses, a, use_)
      record(uses, o, use_)
      record(uses, v, use_)
      record(uses, l, use_)
    }
    SSAOp::ArrayCopy(_, _, d, d_off, s, s_off, l) => {
      record(uses, d, use_)
      record(uses, d_off, use_)
      record(uses, s, use_)
      record(uses, s_off, use_)
      record(uses, l, use_)
    }
    SSAOp::ArrayInitData(_, _, a, ao, d_off, l)
    | SSAOp::ArrayInitElem(_, _, a, ao, d_off, l) => {
      record(uses, a, use_)
      record(uses, ao, use_)
      record(uses, d_off, use_)
      record(uses, l, use_)
    }
    SSAOp::Splat(_, v) => record(uses, v, use_)
    SSAOp::ExtractLane(_, _, v) => record(uses, v, use_)
    SSAOp::ReplaceLane(_, _, vec, val) => {
      record(uses, vec, use_)
      record(uses, val, use_)
    }
    SSAOp::Shuffle(_, a, b) | SSAOp::Swizzle(a, b) => {
      record(uses, a, use_)
      record(uses, b, use_)
    }
    SSAOp::V128Shift(_, v, s) => {
      record(uses, v, use_)
      record(uses, s, use_)
    }
    SSAOp::V128Ternary(_, a, b, c) => {
      record(uses, a, use_)
      record(uses, b, use_)
      record(uses, c, use_)
    }
    SSAOp::V128LoadLane(_, _, _, addr, vec) => {
      record(uses, addr, use_)
      record(uses, vec, use_)
    }
    SSAOp::V128StoreLane(_, _, _, addr, vec) => {
      record(uses, addr, use_)
      record(uses, vec, use_)
    }
    SSAOp::Throw(_, args) =>
      for a in args {
        record(uses, a, use_)
      }
    // No uses
    SSAOp::I32Const(_)
    | SSAOp::I64Const(_)
    | SSAOp::F32Const(_)
    | SSAOp::F64Const(_)
    | SSAOp::V128Const(_)
    | SSAOp::RefNull(_)
    | SSAOp::RefFunc(_)
    | SSAOp::GlobalGet(_)
    | SSAOp::MemorySize(_)
    | SSAOp::AtomicFence
    | SSAOp::TableSize(_)
    | SSAOp::DataDrop(_)
    | SSAOp::ElemDrop(_)
    | SSAOp::StructNewDefault(_) => ()
  }
}

///|
fn collect_terminator_uses(
  term : SSATerminator,
  block_id : BlockId,
  uses : Map[SSAValue, Array[SSAUse]],
) -> Unit {
  let use_ = SSAUse::InTerminator(block_id)
  fn record(
    uses : Map[SSAValue, Array[SSAUse]],
    val : SSAValue,
    use_ : SSAUse,
  ) {
    uses.get_or_init(val, fn() { [] }).push(use_)
  }

  match term {
    Br(_) | Unreachable => ()
    BrIf(cond, _, _) | BrTable(cond, _, _) => record(uses, cond, use_)
    BrOnNull(val, _, _) | BrOnNonNull(val, _, _) => record(uses, val, use_)
    BrOnCast(_, _, _, val, _, _) | BrOnCastFail(_, _, _, val, _, _) =>
      record(uses, val, use_)
    Return(vals) | ReturnCall(_, vals) =>
      for v in vals {
        record(uses, v, use_)
      }
    ReturnCallIndirect(_, _, args, idx) => {
      for v in args {
        record(uses, v, use_)
      }
      record(uses, idx, use_)
    }
    ReturnCallRef(_, args, func) => {
      for v in args {
        record(uses, v, use_)
      }
      record(uses, func, use_)
    }
    ThrowRef(val) => record(uses, val, use_)
  }
}

///|
pub fn UseDefInfo::get_def(
  self : UseDefInfo,
  val : SSAValue,
) -> (BlockId, SSADef)? {
  self.defs.get(val)
}

///|
pub fn UseDefInfo::get_uses(self : UseDefInfo, val : SSAValue) -> Array[SSAUse] {
  self.uses.get(val).unwrap_or([])
}

///|
pub fn UseDefInfo::is_dead(self : UseDefInfo, val : SSAValue) -> Bool {
  self.uses.get(val).map(fn(arr) { arr.is_empty() }).unwrap_or(true)
}
