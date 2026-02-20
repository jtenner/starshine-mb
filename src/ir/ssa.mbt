///|
fn SSABuilder::new() -> SSABuilder {
  { next_value: 0, stacks: Map::new(), pushed_per_block: [] }
}

///|
fn SSABuilder::fresh(self : SSABuilder) -> SSAValue {
  let v = SSAValue(self.next_value)
  self.next_value += 1
  v
}

///|
fn SSABuilder::push_def(
  self : SSABuilder,
  l : LocalIdx,
  value : SSAValue,
) -> Unit {
  self.stacks.get_or_init(l, fn() { [] }).push(value)
  self.pushed_per_block.push((l, value))
}

///|
fn SSABuilder::current_value(self : SSABuilder, l : LocalIdx) -> SSAValue? {
  match self.stacks.get(l) {
    Some(stack) if stack.length() > 0 => Some(stack[stack.length() - 1])
    _ => None
  }
}

///|
fn SSABuilder::save_checkpoint(self : SSABuilder) -> Int {
  self.pushed_per_block.length()
}

///|
fn SSABuilder::restore_checkpoint(self : SSABuilder, checkpoint : Int) -> Unit {
  while self.pushed_per_block.length() > checkpoint {
    let (l, _) = self.pushed_per_block.pop().unwrap()
    let _ = self.stacks[l].pop()
  }
}

// ============================================
// Local Collection
// ============================================

///|
fn collect_all_locals(cfg : CFG) -> Set[LocalIdx] {
  let locals : Set[LocalIdx] = Set::new()
  for entry in cfg.blocks {
    let (_, block) = entry
    for instr in block.instrs {
      collect_instr_locals(instr, locals)
    }
    collect_terminator_locals(block.terminator, locals)
  }
  locals
}

///|
fn collect_instr_locals(instr : TInstr, locals : Set[LocalIdx]) -> Unit {
  match instr {
    TLocalGet(l) => locals.add(l)
    TLocalSet(l, inner) => {
      locals.add(l)
      collect_instr_locals(inner, locals)
    }
    TLocalTee(l, inner) => {
      locals.add(l)
      collect_instr_locals(inner, locals)
    }

    // Recurse into all nested instructions
    TUnary(_, a) => collect_instr_locals(a, locals)
    TBinary(_, a, b) => {
      collect_instr_locals(a, locals)
      collect_instr_locals(b, locals)
    }
    TDrop(a) => collect_instr_locals(a, locals)
    TGlobalSet(_, a) => collect_instr_locals(a, locals)
    TRefIsNull(a) => collect_instr_locals(a, locals)
    TRefAsNonNull(a) => collect_instr_locals(a, locals)
    TRefEq(a, b) => {
      collect_instr_locals(a, locals)
      collect_instr_locals(b, locals)
    }
    TI31GetS(a) | TI31GetU(a) => collect_instr_locals(a, locals)
    TRefI31(a) => collect_instr_locals(a, locals)
    TArrayLen(a) => collect_instr_locals(a, locals)
    TAnyConvertExtern(a) | TExternConvertAny(a) =>
      collect_instr_locals(a, locals)
    TThrowRef(a) => collect_instr_locals(a, locals)
    TStore(_, _, addr, val) => {
      collect_instr_locals(addr, locals)
      collect_instr_locals(val, locals)
    }
    TLoad(_, _, addr) => collect_instr_locals(addr, locals)
    TMemoryGrow(_, a) => collect_instr_locals(a, locals)
    TMemoryAtomicNotify(_, addr, count) => {
      collect_instr_locals(addr, locals)
      collect_instr_locals(count, locals)
    }
    TMemoryAtomicWait32(_, addr, expected, timeout) => {
      collect_instr_locals(addr, locals)
      collect_instr_locals(expected, locals)
      collect_instr_locals(timeout, locals)
    }
    TMemoryAtomicWait64(_, addr, expected, timeout) => {
      collect_instr_locals(addr, locals)
      collect_instr_locals(expected, locals)
      collect_instr_locals(timeout, locals)
    }
    TAtomicRmw(_, _, addr, value) => {
      collect_instr_locals(addr, locals)
      collect_instr_locals(value, locals)
    }
    TAtomicCmpxchg(_, _, addr, expected, replacement) => {
      collect_instr_locals(addr, locals)
      collect_instr_locals(expected, locals)
      collect_instr_locals(replacement, locals)
    }
    TMemoryFill(_, a, b, c) => {
      collect_instr_locals(a, locals)
      collect_instr_locals(b, locals)
      collect_instr_locals(c, locals)
    }
    TMemoryCopy(_, _, a, b, c) => {
      collect_instr_locals(a, locals)
      collect_instr_locals(b, locals)
      collect_instr_locals(c, locals)
    }
    TMemoryInit(_, _, a, b, c) => {
      collect_instr_locals(a, locals)
      collect_instr_locals(b, locals)
      collect_instr_locals(c, locals)
    }
    TTableGet(_, a) => collect_instr_locals(a, locals)
    TTableSet(_, a, b) => {
      collect_instr_locals(a, locals)
      collect_instr_locals(b, locals)
    }
    TTableGrow(_, a, b) => {
      collect_instr_locals(a, locals)
      collect_instr_locals(b, locals)
    }
    TTableFill(_, a, b, c) => {
      collect_instr_locals(a, locals)
      collect_instr_locals(b, locals)
      collect_instr_locals(c, locals)
    }
    TTableCopy(_, _, a, b, c) => {
      collect_instr_locals(a, locals)
      collect_instr_locals(b, locals)
      collect_instr_locals(c, locals)
    }
    TTableInit(_, _, a, b, c) => {
      collect_instr_locals(a, locals)
      collect_instr_locals(b, locals)
      collect_instr_locals(c, locals)
    }
    TCall(_, args) =>
      for a in args {
        collect_instr_locals(a, locals)
      }
    TCallIndirect(_, _, args, idx) => {
      for a in args {
        collect_instr_locals(a, locals)
      }
      collect_instr_locals(idx, locals)
    }
    TCallRef(_, args, func) => {
      for a in args {
        collect_instr_locals(a, locals)
      }
      collect_instr_locals(func, locals)
    }
    TReturnCall(_, args) =>
      for a in args {
        collect_instr_locals(a, locals)
      }
    TReturnCallIndirect(_, _, args, idx) => {
      for a in args {
        collect_instr_locals(a, locals)
      }
      collect_instr_locals(idx, locals)
    }
    TReturnCallRef(_, args, func) => {
      for a in args {
        collect_instr_locals(a, locals)
      }
      collect_instr_locals(func, locals)
    }
    TStructNew(_, args) =>
      for a in args {
        collect_instr_locals(a, locals)
      }
    TStructGet(_, _, a) | TStructGetS(_, _, a) | TStructGetU(_, _, a) =>
      collect_instr_locals(a, locals)
    TStructSet(_, _, a, b) => {
      collect_instr_locals(a, locals)
      collect_instr_locals(b, locals)
    }
    TArrayNew(_, a, b) => {
      collect_instr_locals(a, locals)
      collect_instr_locals(b, locals)
    }
    TArrayNewDefault(_, a) => collect_instr_locals(a, locals)
    TArrayNewFixed(_, args) =>
      for a in args {
        collect_instr_locals(a, locals)
      }
    TArrayNewData(_, _, a, b) | TArrayNewElem(_, _, a, b) => {
      collect_instr_locals(a, locals)
      collect_instr_locals(b, locals)
    }
    TArrayGet(_, a, b) | TArrayGetS(_, a, b) | TArrayGetU(_, a, b) => {
      collect_instr_locals(a, locals)
      collect_instr_locals(b, locals)
    }
    TArraySet(_, a, b, c) => {
      collect_instr_locals(a, locals)
      collect_instr_locals(b, locals)
      collect_instr_locals(c, locals)
    }
    TArrayFill(_, a, b, c, d) => {
      collect_instr_locals(a, locals)
      collect_instr_locals(b, locals)
      collect_instr_locals(c, locals)
      collect_instr_locals(d, locals)
    }
    TArrayCopy(_, _, a, b, c, d, e) => {
      collect_instr_locals(a, locals)
      collect_instr_locals(b, locals)
      collect_instr_locals(c, locals)
      collect_instr_locals(d, locals)
      collect_instr_locals(e, locals)
    }
    TArrayInitData(_, _, a, b, c, d) | TArrayInitElem(_, _, a, b, c, d) => {
      collect_instr_locals(a, locals)
      collect_instr_locals(b, locals)
      collect_instr_locals(c, locals)
      collect_instr_locals(d, locals)
    }
    TRefGetDesc(a)
    | TRefTest(_, _, a)
    | TRefCast(_, _, a)
    | TRefTestDesc(_, _, a)
    | TRefCastDescEq(_, _, a) => collect_instr_locals(a, locals)
    TSelect(_, a, b, c) => {
      collect_instr_locals(a, locals)
      collect_instr_locals(b, locals)
      collect_instr_locals(c, locals)
    }
    TThrow(_, args) =>
      for a in args {
        collect_instr_locals(a, locals)
      }
    TBlock(_, expr) | TLoop(_, expr) =>
      for i in expr.0 {
        collect_instr_locals(i, locals)
      }
    TIf(_, cond, then_e, else_e) => {
      collect_instr_locals(cond, locals)
      for i in then_e.0 {
        collect_instr_locals(i, locals)
      }
      if else_e is Some(e) {
        for i in e.0 {
          collect_instr_locals(i, locals)
        }
      }
    }
    TTryTable(_, _, expr) =>
      for i in expr.0 {
        collect_instr_locals(i, locals)
      }
    TBr(_, args) =>
      for a in args {
        collect_instr_locals(a, locals)
      }
    TBrIf(_, cond, args) => {
      collect_instr_locals(cond, locals)
      for a in args {
        collect_instr_locals(a, locals)
      }
    }
    TBrTable(_, _, cond, args) => {
      collect_instr_locals(cond, locals)
      for a in args {
        collect_instr_locals(a, locals)
      }
    }
    TBrOnNull(_, a, args) | TBrOnNonNull(_, a, args) => {
      collect_instr_locals(a, locals)
      for arg in args {
        collect_instr_locals(arg, locals)
      }
    }
    TBrOnCast(_, _, _, _, a, args) | TBrOnCastFail(_, _, _, _, a, args) => {
      collect_instr_locals(a, locals)
      for arg in args {
        collect_instr_locals(arg, locals)
      }
    }
    TReturn(args) =>
      for a in args {
        collect_instr_locals(a, locals)
      }
    TI8x16Splat(a)
    | TI16x8Splat(a)
    | TI32x4Splat(a)
    | TI64x2Splat(a)
    | TF32x4Splat(a)
    | TF64x2Splat(a) => collect_instr_locals(a, locals)
    TExtractLane(_, _, a) => collect_instr_locals(a, locals)
    TReplaceLane(_, _, a, b) => {
      collect_instr_locals(a, locals)
      collect_instr_locals(b, locals)
    }
    TI8x16Shuffle(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, a, b) => {
      collect_instr_locals(a, locals)
      collect_instr_locals(b, locals)
    }
    TI8x16Swizzle(a, b) | TI8x16RelaxedSwizzle(a, b) => {
      collect_instr_locals(a, locals)
      collect_instr_locals(b, locals)
    }
    TV128Shift(_, a, b) => {
      collect_instr_locals(a, locals)
      collect_instr_locals(b, locals)
    }
    TV128Ternary(_, a, b, c) => {
      collect_instr_locals(a, locals)
      collect_instr_locals(b, locals)
      collect_instr_locals(c, locals)
    }
    TV128LoadLane(_, _, _, a, b) | TV128StoreLane(_, _, _, a, b) => {
      collect_instr_locals(a, locals)
      collect_instr_locals(b, locals)
    }

    // Instructions with no nested locals
    TI32Const(_)
    | TI64Const(_)
    | TF32Const(_)
    | TF64Const(_)
    | TRefNull(_)
    | TRefFunc(_)
    | TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | TUnreachable
    | TNop
    | TGlobalGet(_)
    | TMemorySize(_)
    | TAtomicFence
    | TTableSize(_)
    | TDataDrop(_)
    | TElemDrop(_)
    | TStructNewDefault(_) => ()
  }
}

///|
fn collect_terminator_locals(term : Terminator, locals : Set[LocalIdx]) -> Unit {
  match term {
    Br(_) | Unreachable => ()
    BrIf(cond, _, _) => collect_instr_locals(cond, locals)
    BrTable(cond, _, _) => collect_instr_locals(cond, locals)
    Return(values) =>
      for v in values {
        collect_instr_locals(v, locals)
      }
    ReturnCallRef(_, values, value) => {
      for v in values {
        collect_instr_locals(v, locals)
      }
      collect_instr_locals(value, locals)
    }
    ReturnCallIndirect(_, _, values, value) => {
      for v in values {
        collect_instr_locals(v, locals)
      }
      collect_instr_locals(value, locals)
    }
    ReturnCall(_, values) =>
      for v in values {
        collect_instr_locals(v, locals)
      }
    BrOnCastFail(_, _, _, value, _, _) => collect_instr_locals(value, locals)
    BrOnCast(_, _, _, value, BlockId(_), BlockId(_)) =>
      collect_instr_locals(value, locals)
    BrOnNonNull(value, _, _) => collect_instr_locals(value, locals)
    BrOnNull(value, _, _) => collect_instr_locals(value, locals)
    ThrowRef(value) => collect_instr_locals(value, locals)
  }
}

// Collect blocks where a local is defined

///|
fn collect_def_blocks(cfg : CFG, l : LocalIdx) -> Set[BlockId] {
  let defs : Set[BlockId] = Set::new()
  for entry in cfg.blocks {
    let (id, block) = entry
    for instr in block.instrs {
      if instr_defines_local(instr, l) {
        defs.add(id)
        break
      }
    }
  }
  defs
}

///|
fn instr_defines_local(instr : TInstr, target : LocalIdx) -> Bool {
  match instr {
    TLocalSet(l, _) | TLocalTee(l, _) if l == target => true
    TLocalSet(_, inner) | TLocalTee(_, inner) =>
      instr_defines_local(inner, target)

    // Recurse
    TUnary(_, a) => instr_defines_local(a, target)
    TBinary(_, a, b) =>
      instr_defines_local(a, target) || instr_defines_local(b, target)
    TDrop(a) => instr_defines_local(a, target)
    TSelect(_, a, b, c) =>
      instr_defines_local(a, target) ||
      instr_defines_local(b, target) ||
      instr_defines_local(c, target)
    // ... extend for other cases as needed
    _ => false
  }
}

// ============================================
// Phi Node Placement
// ============================================

///|
fn place_phi_nodes(
  cfg : CFG,
  df : Map[BlockId, Set[BlockId]],
) -> Map[BlockId, Set[LocalIdx]] {
  let phi_placements : Map[BlockId, Set[LocalIdx]] = Map::new()

  // Initialize empty sets
  for entry in cfg.blocks {
    let (id, _) = entry
    phi_placements[id] = Set::new()
  }
  let all_locals = collect_all_locals(cfg)
  for l in all_locals {
    let def_blocks = collect_def_blocks(cfg, l)

    // Worklist algorithm
    let worklist : Array[BlockId] = []
    for b in def_blocks {
      worklist.push(b)
    }
    let has_phi : Set[BlockId] = Set::new()
    let processed : Set[BlockId] = Set::new()
    while worklist.length() > 0 {
      let b = worklist.pop().unwrap()
      if processed.contains(b) {
        continue
      }
      processed.add(b)

      // Add phi at each block in dominance frontier
      match df.get(b) {
        Some(frontier) =>
          for d in frontier {
            if !has_phi.contains(d) {
              phi_placements[d].add(l)
              has_phi.add(d)
              worklist.push(d)
            }
          }
        None => ()
      }
    }
  }
  phi_placements
}

// ============================================
// Instruction Renaming
// ============================================

///|
/// Convert a TInstr to SSA, returning the SSAValue it produces (if any)
fn rename_instr(
  instr : TInstr,
  builder : SSABuilder,
  out : Array[SSAInstr],
) -> SSAValue? {
  match instr {
    // Local access
    TLocalGet(l) => builder.current_value(l)
    TLocalSet(l, inner) => {
      match rename_instr(inner, builder, out) {
        Some(v) => {
          let new_val = builder.fresh()
          out.push(SSAInstr::Assign(new_val, SSAOp::Copy(v)))
          builder.push_def(l, new_val)
        }
        None => ()
      }
      None
    }
    TLocalTee(l, inner) =>
      match rename_instr(inner, builder, out) {
        Some(v) => {
          let new_val = builder.fresh()
          out.push(SSAInstr::Assign(new_val, SSAOp::Copy(v)))
          builder.push_def(l, new_val)
          Some(new_val)
        }
        None => None
      }

    // Constants
    TI32Const(c) => {
      let v = builder.fresh()
      out.push(SSAInstr::Assign(v, SSAOp::I32Const(c)))
      Some(v)
    }
    TI64Const(c) => {
      let v = builder.fresh()
      out.push(SSAInstr::Assign(v, SSAOp::I64Const(c)))
      Some(v)
    }
    TF32Const(c) => {
      let v = builder.fresh()
      out.push(SSAInstr::Assign(v, SSAOp::F32Const(c)))
      Some(v)
    }
    TF64Const(c) => {
      let v = builder.fresh()
      out.push(SSAInstr::Assign(v, SSAOp::F64Const(c)))
      Some(v)
    }
    TRefNull(ht) => {
      let v = builder.fresh()
      out.push(SSAInstr::Assign(v, SSAOp::RefNull(ht)))
      Some(v)
    }
    TRefFunc(idx) => {
      let v = builder.fresh()
      out.push(SSAInstr::Assign(v, SSAOp::RefFunc(idx)))
      Some(v)
    }
    TV128Const(
      b0,
      b1,
      b2,
      b3,
      b4,
      b5,
      b6,
      b7,
      b8,
      b9,
      b10,
      b11,
      b12,
      b13,
      b14,
      b15
    ) => {
      let v = builder.fresh()
      let bytes = Bytes::from_array([
        b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15,
      ])
      out.push(SSAInstr::Assign(v, SSAOp::V128Const(bytes)))
      Some(v)
    }

    // Unary/Binary
    TUnary(op, a) =>
      match rename_instr(a, builder, out) {
        Some(av) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::Unary(op, av)))
          Some(v)
        }
        None => None
      }
    TBinary(op, a, b) => {
      let av = rename_instr(a, builder, out)
      let bv = rename_instr(b, builder, out)
      match (av, bv) {
        (Some(a), Some(b)) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::Binary(op, a, b)))
          Some(v)
        }
        _ => None
      }
    }

    // Drop
    TDrop(a) => {
      let _ = rename_instr(a, builder, out)
      None
    }

    // Globals
    TGlobalGet(idx) => {
      let v = builder.fresh()
      out.push(SSAInstr::Assign(v, SSAOp::GlobalGet(idx)))
      Some(v)
    }
    TGlobalSet(idx, a) => {
      match rename_instr(a, builder, out) {
        Some(av) => out.push(SSAInstr::Effect(SSAOp::GlobalSet(idx, av)))
        None => ()
      }
      None
    }

    // Memory
    TMemorySize(idx) => {
      let v = builder.fresh()
      out.push(SSAInstr::Assign(v, SSAOp::MemorySize(idx)))
      Some(v)
    }
    TMemoryGrow(idx, a) =>
      match rename_instr(a, builder, out) {
        Some(av) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::MemoryGrow(idx, av)))
          Some(v)
        }
        None => None
      }
    TMemoryAtomicNotify(memarg, addr, count) => {
      let addr_v = rename_instr(addr, builder, out)
      let count_v = rename_instr(count, builder, out)
      match (addr_v, count_v) {
        (Some(a), Some(c)) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::MemoryAtomicNotify(memarg, a, c)))
          Some(v)
        }
        _ => None
      }
    }
    TMemoryAtomicWait32(memarg, addr, expected, timeout) => {
      let addr_v = rename_instr(addr, builder, out)
      let expected_v = rename_instr(expected, builder, out)
      let timeout_v = rename_instr(timeout, builder, out)
      match (addr_v, expected_v, timeout_v) {
        (Some(a), Some(e), Some(t)) => {
          let v = builder.fresh()
          out.push(
            SSAInstr::Assign(v, SSAOp::MemoryAtomicWait32(memarg, a, e, t)),
          )
          Some(v)
        }
        _ => None
      }
    }
    TMemoryAtomicWait64(memarg, addr, expected, timeout) => {
      let addr_v = rename_instr(addr, builder, out)
      let expected_v = rename_instr(expected, builder, out)
      let timeout_v = rename_instr(timeout, builder, out)
      match (addr_v, expected_v, timeout_v) {
        (Some(a), Some(e), Some(t)) => {
          let v = builder.fresh()
          out.push(
            SSAInstr::Assign(v, SSAOp::MemoryAtomicWait64(memarg, a, e, t)),
          )
          Some(v)
        }
        _ => None
      }
    }
    TAtomicFence => {
      out.push(SSAInstr::Effect(SSAOp::AtomicFence))
      None
    }
    TAtomicRmw(op, memarg, addr, value) => {
      let addr_v = rename_instr(addr, builder, out)
      let value_v = rename_instr(value, builder, out)
      match (addr_v, value_v) {
        (Some(a), Some(vv)) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::AtomicRmw(op, memarg, a, vv)))
          Some(v)
        }
        _ => None
      }
    }
    TAtomicCmpxchg(op, memarg, addr, expected, replacement) => {
      let addr_v = rename_instr(addr, builder, out)
      let expected_v = rename_instr(expected, builder, out)
      let replacement_v = rename_instr(replacement, builder, out)
      match (addr_v, expected_v, replacement_v) {
        (Some(a), Some(e), Some(r)) => {
          let v = builder.fresh()
          out.push(
            SSAInstr::Assign(v, SSAOp::AtomicCmpxchg(op, memarg, a, e, r)),
          )
          Some(v)
        }
        _ => None
      }
    }
    TLoad(op, memarg, addr) =>
      match rename_instr(addr, builder, out) {
        Some(av) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::Load(op, memarg, av)))
          Some(v)
        }
        None => None
      }
    TStore(op, memarg, addr, val) => {
      let addr_v = rename_instr(addr, builder, out)
      let val_v = rename_instr(val, builder, out)
      match (addr_v, val_v) {
        (Some(a), Some(v)) =>
          out.push(SSAInstr::Effect(SSAOp::Store(op, memarg, a, v)))
        _ => ()
      }
      None
    }
    TMemoryFill(idx, dest, val, len) => {
      let dest_v = rename_instr(dest, builder, out)
      let val_v = rename_instr(val, builder, out)
      let len_v = rename_instr(len, builder, out)
      match (dest_v, val_v, len_v) {
        (Some(d), Some(v), Some(l)) =>
          out.push(SSAInstr::Effect(SSAOp::MemoryFill(idx, d, v, l)))
        _ => ()
      }
      None
    }
    TMemoryCopy(dst_idx, src_idx, dest, src, len) => {
      let dest_v = rename_instr(dest, builder, out)
      let src_v = rename_instr(src, builder, out)
      let len_v = rename_instr(len, builder, out)
      match (dest_v, src_v, len_v) {
        (Some(d), Some(s), Some(l)) =>
          out.push(
            SSAInstr::Effect(SSAOp::MemoryCopy(dst_idx, src_idx, d, s, l)),
          )
        _ => ()
      }
      None
    }
    TMemoryInit(data, mem, dest, src, len) => {
      let dest_v = rename_instr(dest, builder, out)
      let src_v = rename_instr(src, builder, out)
      let len_v = rename_instr(len, builder, out)
      match (dest_v, src_v, len_v) {
        (Some(d), Some(s), Some(l)) =>
          out.push(SSAInstr::Effect(SSAOp::MemoryInit(data, mem, d, s, l)))
        _ => ()
      }
      None
    }
    TDataDrop(idx) => {
      out.push(SSAInstr::Effect(SSAOp::DataDrop(idx)))
      None
    }

    // Tables
    TTableSize(idx) => {
      let v = builder.fresh()
      out.push(SSAInstr::Assign(v, SSAOp::TableSize(idx)))
      Some(v)
    }
    TTableGet(idx, i) =>
      match rename_instr(i, builder, out) {
        Some(iv) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::TableGet(idx, iv)))
          Some(v)
        }
        None => None
      }
    TTableSet(idx, i, val) => {
      let iv = rename_instr(i, builder, out)
      let vv = rename_instr(val, builder, out)
      match (iv, vv) {
        (Some(i), Some(v)) =>
          out.push(SSAInstr::Effect(SSAOp::TableSet(idx, i, v)))
        _ => ()
      }
      None
    }
    TTableGrow(idx, val, n) => {
      let vv = rename_instr(val, builder, out)
      let nv = rename_instr(n, builder, out)
      match (vv, nv) {
        (Some(v), Some(n)) => {
          let r = builder.fresh()
          out.push(SSAInstr::Assign(r, SSAOp::TableGrow(idx, v, n)))
          Some(r)
        }
        _ => None
      }
    }
    TTableFill(idx, i, val, n) => {
      let iv = rename_instr(i, builder, out)
      let vv = rename_instr(val, builder, out)
      let nv = rename_instr(n, builder, out)
      match (iv, vv, nv) {
        (Some(i), Some(v), Some(n)) =>
          out.push(SSAInstr::Effect(SSAOp::TableFill(idx, i, v, n)))
        _ => ()
      }
      None
    }
    TTableCopy(dst, src, d, s, n) => {
      let dv = rename_instr(d, builder, out)
      let sv = rename_instr(s, builder, out)
      let nv = rename_instr(n, builder, out)
      match (dv, sv, nv) {
        (Some(d), Some(s), Some(n)) =>
          out.push(SSAInstr::Effect(SSAOp::TableCopy(dst, src, d, s, n)))
        _ => ()
      }
      None
    }
    TTableInit(elem, table, d, s, n) => {
      let dv = rename_instr(d, builder, out)
      let sv = rename_instr(s, builder, out)
      let nv = rename_instr(n, builder, out)
      match (dv, sv, nv) {
        (Some(d), Some(s), Some(n)) =>
          out.push(SSAInstr::Effect(SSAOp::TableInit(elem, table, d, s, n)))
        _ => ()
      }
      None
    }
    TElemDrop(idx) => {
      out.push(SSAInstr::Effect(SSAOp::ElemDrop(idx)))
      None
    }

    // Calls
    TCall(func, args) => {
      let ssa_args = rename_args(args, builder, out)
      let v = builder.fresh()
      out.push(SSAInstr::Assign(v, SSAOp::Call(func, ssa_args)))
      Some(v)
    }
    TCallIndirect(ty, table, args, idx) => {
      let ssa_args = rename_args(args, builder, out)
      match rename_instr(idx, builder, out) {
        Some(iv) => {
          let v = builder.fresh()
          out.push(
            SSAInstr::Assign(v, SSAOp::CallIndirect(ty, table, ssa_args, iv)),
          )
          Some(v)
        }
        None => None
      }
    }
    TCallRef(ty, args, func) => {
      let ssa_args = rename_args(args, builder, out)
      match rename_instr(func, builder, out) {
        Some(fv) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::CallRef(ty, ssa_args, fv)))
          Some(v)
        }
        None => None
      }
    }

    // References
    TRefIsNull(a) =>
      match rename_instr(a, builder, out) {
        Some(av) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::RefIsNull(av)))
          Some(v)
        }
        None => None
      }
    TRefEq(a, b) => {
      let av = rename_instr(a, builder, out)
      let bv = rename_instr(b, builder, out)
      match (av, bv) {
        (Some(a), Some(b)) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::RefEq(a, b)))
          Some(v)
        }
        _ => None
      }
    }
    TRefAsNonNull(a) =>
      match rename_instr(a, builder, out) {
        Some(av) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::RefAsNonNull(av)))
          Some(v)
        }
        None => None
      }
    TRefI31(a) =>
      match rename_instr(a, builder, out) {
        Some(av) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::RefI31(av)))
          Some(v)
        }
        None => None
      }
    TI31GetS(a) =>
      match rename_instr(a, builder, out) {
        Some(av) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::I31GetS(av)))
          Some(v)
        }
        None => None
      }
    TI31GetU(a) =>
      match rename_instr(a, builder, out) {
        Some(av) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::I31GetU(av)))
          Some(v)
        }
        None => None
      }
    TRefTest(nullable, ht, a) =>
      match rename_instr(a, builder, out) {
        Some(av) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::RefTest(nullable, ht, av)))
          Some(v)
        }
        None => None
      }
    TRefCast(nullable, ht, a) =>
      match rename_instr(a, builder, out) {
        Some(av) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::RefCast(nullable, ht, av)))
          Some(v)
        }
        None => None
      }
    TRefGetDesc(a) =>
      match rename_instr(a, builder, out) {
        Some(_) => None
        None => None
      }
    TRefTestDesc(_, _, a) =>
      match rename_instr(a, builder, out) {
        Some(_) => None
        None => None
      }
    TRefCastDescEq(_, _, a) =>
      match rename_instr(a, builder, out) {
        Some(_) => None
        None => None
      }
    TAnyConvertExtern(a) =>
      match rename_instr(a, builder, out) {
        Some(av) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::AnyConvertExtern(av)))
          Some(v)
        }
        None => None
      }
    TExternConvertAny(a) =>
      match rename_instr(a, builder, out) {
        Some(av) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::ExternConvertAny(av)))
          Some(v)
        }
        None => None
      }

    // Structs
    TStructNew(ty, args) => {
      let ssa_args = rename_args(args, builder, out)
      let v = builder.fresh()
      out.push(SSAInstr::Assign(v, SSAOp::StructNew(ty, ssa_args)))
      Some(v)
    }
    TStructNewDefault(ty) => {
      let v = builder.fresh()
      out.push(SSAInstr::Assign(v, SSAOp::StructNewDefault(ty)))
      Some(v)
    }
    TStructGet(ty, field, a) =>
      match rename_instr(a, builder, out) {
        Some(av) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::StructGet(ty, field, av)))
          Some(v)
        }
        None => None
      }
    TStructGetS(ty, field, a) =>
      match rename_instr(a, builder, out) {
        Some(av) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::StructGetS(ty, field, av)))
          Some(v)
        }
        None => None
      }
    TStructGetU(ty, field, a) =>
      match rename_instr(a, builder, out) {
        Some(av) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::StructGetU(ty, field, av)))
          Some(v)
        }
        None => None
      }
    TStructSet(ty, field, obj, val) => {
      let ov = rename_instr(obj, builder, out)
      let vv = rename_instr(val, builder, out)
      match (ov, vv) {
        (Some(o), Some(v)) =>
          out.push(SSAInstr::Effect(SSAOp::StructSet(ty, field, o, v)))
        _ => ()
      }
      None
    }

    // Arrays
    TArrayNew(ty, val, len) => {
      let vv = rename_instr(val, builder, out)
      let lv = rename_instr(len, builder, out)
      match (vv, lv) {
        (Some(v), Some(l)) => {
          let r = builder.fresh()
          out.push(SSAInstr::Assign(r, SSAOp::ArrayNew(ty, v, l)))
          Some(r)
        }
        _ => None
      }
    }
    TArrayNewDefault(ty, len) =>
      match rename_instr(len, builder, out) {
        Some(lv) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::ArrayNewDefault(ty, lv)))
          Some(v)
        }
        None => None
      }
    TArrayNewFixed(ty, args) => {
      let ssa_args = rename_args(args, builder, out)
      let v = builder.fresh()
      out.push(SSAInstr::Assign(v, SSAOp::ArrayNewFixed(ty, ssa_args)))
      Some(v)
    }
    TArrayNewData(ty, data, offset, len) => {
      let ov = rename_instr(offset, builder, out)
      let lv = rename_instr(len, builder, out)
      match (ov, lv) {
        (Some(o), Some(l)) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::ArrayNewData(ty, data, o, l)))
          Some(v)
        }
        _ => None
      }
    }
    TArrayNewElem(ty, elem, offset, len) => {
      let ov = rename_instr(offset, builder, out)
      let lv = rename_instr(len, builder, out)
      match (ov, lv) {
        (Some(o), Some(l)) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::ArrayNewElem(ty, elem, o, l)))
          Some(v)
        }
        _ => None
      }
    }
    TArrayGet(ty, arr, idx) => {
      let av = rename_instr(arr, builder, out)
      let iv = rename_instr(idx, builder, out)
      match (av, iv) {
        (Some(a), Some(i)) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::ArrayGet(ty, a, i)))
          Some(v)
        }
        _ => None
      }
    }
    TArrayGetS(ty, arr, idx) => {
      let av = rename_instr(arr, builder, out)
      let iv = rename_instr(idx, builder, out)
      match (av, iv) {
        (Some(a), Some(i)) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::ArrayGetS(ty, a, i)))
          Some(v)
        }
        _ => None
      }
    }
    TArrayGetU(ty, arr, idx) => {
      let av = rename_instr(arr, builder, out)
      let iv = rename_instr(idx, builder, out)
      match (av, iv) {
        (Some(a), Some(i)) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::ArrayGetU(ty, a, i)))
          Some(v)
        }
        _ => None
      }
    }
    TArraySet(ty, arr, idx, val) => {
      let av = rename_instr(arr, builder, out)
      let iv = rename_instr(idx, builder, out)
      let vv = rename_instr(val, builder, out)
      match (av, iv, vv) {
        (Some(a), Some(i), Some(v)) =>
          out.push(SSAInstr::Effect(SSAOp::ArraySet(ty, a, i, v)))
        _ => ()
      }
      None
    }
    TArrayLen(arr) =>
      match rename_instr(arr, builder, out) {
        Some(av) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::ArrayLen(av)))
          Some(v)
        }
        None => None
      }
    TArrayFill(ty, arr, offset, val, len) => {
      let av = rename_instr(arr, builder, out)
      let ov = rename_instr(offset, builder, out)
      let vv = rename_instr(val, builder, out)
      let lv = rename_instr(len, builder, out)
      match (av, ov, vv, lv) {
        (Some(a), Some(o), Some(v), Some(l)) =>
          out.push(SSAInstr::Effect(SSAOp::ArrayFill(ty, a, o, v, l)))
        _ => ()
      }
      None
    }
    TArrayCopy(dst_ty, src_ty, dst, dst_off, src, src_off, len) => {
      let dv = rename_instr(dst, builder, out)
      let dov = rename_instr(dst_off, builder, out)
      let sv = rename_instr(src, builder, out)
      let sov = rename_instr(src_off, builder, out)
      let lv = rename_instr(len, builder, out)
      match (dv, dov, sv, sov, lv) {
        (Some(d), Some(d_off), Some(s), Some(s_off), Some(l)) =>
          out.push(
            SSAInstr::Effect(
              SSAOp::ArrayCopy(dst_ty, src_ty, d, d_off, s, s_off, l),
            ),
          )
        _ => ()
      }
      None
    }
    TArrayInitData(ty, data, arr, arr_off, data_off, len) => {
      let av = rename_instr(arr, builder, out)
      let aov = rename_instr(arr_off, builder, out)
      let dov = rename_instr(data_off, builder, out)
      let lv = rename_instr(len, builder, out)
      match (av, aov, dov, lv) {
        (Some(a), Some(ao), Some(d_off), Some(l)) =>
          out.push(
            SSAInstr::Effect(SSAOp::ArrayInitData(ty, data, a, ao, d_off, l)),
          )
        _ => ()
      }
      None
    }
    TArrayInitElem(ty, elem, arr, arr_off, elem_off, len) => {
      let av = rename_instr(arr, builder, out)
      let aov = rename_instr(arr_off, builder, out)
      let eov = rename_instr(elem_off, builder, out)
      let lv = rename_instr(len, builder, out)
      match (av, aov, eov, lv) {
        (Some(a), Some(ao), Some(e_off), Some(l)) =>
          out.push(
            SSAInstr::Effect(SSAOp::ArrayInitElem(ty, elem, a, ao, e_off, l)),
          )
        _ => ()
      }
      None
    }

    // Select
    TSelect(types, a, b, cond) => {
      let av = rename_instr(a, builder, out)
      let bv = rename_instr(b, builder, out)
      let cv = rename_instr(cond, builder, out)
      match (av, bv, cv) {
        (Some(a), Some(b), Some(c)) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::Select(types, a, b, c)))
          Some(v)
        }
        _ => None
      }
    }

    // SIMD Splats
    TI8x16Splat(a) =>
      match rename_instr(a, builder, out) {
        Some(av) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::Splat(SplatOp::I8x16Splat, av)))
          Some(v)
        }
        None => None
      }
    TI16x8Splat(a) =>
      match rename_instr(a, builder, out) {
        Some(av) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::Splat(SplatOp::I16x8Splat, av)))
          Some(v)
        }
        None => None
      }
    TI32x4Splat(a) =>
      match rename_instr(a, builder, out) {
        Some(av) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::Splat(SplatOp::I32x4Splat, av)))
          Some(v)
        }
        None => None
      }
    TI64x2Splat(a) =>
      match rename_instr(a, builder, out) {
        Some(av) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::Splat(SplatOp::I64x2Splat, av)))
          Some(v)
        }
        None => None
      }
    TF32x4Splat(a) =>
      match rename_instr(a, builder, out) {
        Some(av) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::Splat(SplatOp::F32x4Splat, av)))
          Some(v)
        }
        None => None
      }
    TF64x2Splat(a) =>
      match rename_instr(a, builder, out) {
        Some(av) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::Splat(SplatOp::F64x2Splat, av)))
          Some(v)
        }
        None => None
      }
    TExtractLane(op, lane, a) =>
      match rename_instr(a, builder, out) {
        Some(av) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::ExtractLane(op, lane, av)))
          Some(v)
        }
        None => None
      }
    TReplaceLane(op, lane, vec, val) => {
      let vv = rename_instr(vec, builder, out)
      let valv = rename_instr(val, builder, out)
      match (vv, valv) {
        (Some(v), Some(val)) => {
          let r = builder.fresh()
          out.push(SSAInstr::Assign(r, SSAOp::ReplaceLane(op, lane, v, val)))
          Some(r)
        }
        _ => None
      }
    }
    TI8x16Shuffle(
      l0,
      l1,
      l2,
      l3,
      l4,
      l5,
      l6,
      l7,
      l8,
      l9,
      l10,
      l11,
      l12,
      l13,
      l14,
      l15,
      a,
      b
    ) => {
      let av = rename_instr(a, builder, out)
      let bv = rename_instr(b, builder, out)
      match (av, bv) {
        (Some(a), Some(b)) => {
          let v = builder.fresh()
          let lanes = [
            l0, l1, l2, l3, l4, l5, l6, l7, l8, l9, l10, l11, l12, l13, l14, l15,
          ]
          out.push(SSAInstr::Assign(v, SSAOp::Shuffle(lanes, a, b)))
          Some(v)
        }
        _ => None
      }
    }
    TI8x16Swizzle(a, b) | TI8x16RelaxedSwizzle(a, b) => {
      let av = rename_instr(a, builder, out)
      let bv = rename_instr(b, builder, out)
      match (av, bv) {
        (Some(a), Some(b)) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::Swizzle(a, b)))
          Some(v)
        }
        _ => None
      }
    }
    TV128Shift(op, vec, shift) => {
      let vv = rename_instr(vec, builder, out)
      let sv = rename_instr(shift, builder, out)
      match (vv, sv) {
        (Some(v), Some(s)) => {
          let r = builder.fresh()
          out.push(SSAInstr::Assign(r, SSAOp::V128Shift(op, v, s)))
          Some(r)
        }
        _ => None
      }
    }
    TV128Ternary(op, a, b, c) => {
      let av = rename_instr(a, builder, out)
      let bv = rename_instr(b, builder, out)
      let cv = rename_instr(c, builder, out)
      match (av, bv, cv) {
        (Some(a), Some(b), Some(c)) => {
          let v = builder.fresh()
          out.push(SSAInstr::Assign(v, SSAOp::V128Ternary(op, a, b, c)))
          Some(v)
        }
        _ => None
      }
    }
    TV128LoadLane(op, memarg, lane, addr, vec) => {
      let av = rename_instr(addr, builder, out)
      let vv = rename_instr(vec, builder, out)
      match (av, vv) {
        (Some(a), Some(v)) => {
          let r = builder.fresh()
          out.push(
            SSAInstr::Assign(r, SSAOp::V128LoadLane(op, memarg, lane, a, v)),
          )
          Some(r)
        }
        _ => None
      }
    }
    TV128StoreLane(op, memarg, lane, addr, vec) => {
      let av = rename_instr(addr, builder, out)
      let vv = rename_instr(vec, builder, out)
      match (av, vv) {
        (Some(a), Some(v)) =>
          out.push(
            SSAInstr::Effect(SSAOp::V128StoreLane(op, memarg, lane, a, v)),
          )
        _ => ()
      }
      None
    }

    // Exceptions
    TThrow(tag, args) => {
      let ssa_args = rename_args(args, builder, out)
      out.push(SSAInstr::Effect(SSAOp::Throw(tag, ssa_args)))
      None
    }
    TThrowRef(_) => None // Handled at terminator level

    // Simple instructions
    TUnreachable => None
    TNop => None

    // Control flow - these shouldn't appear in basic block instructions
    // as they should have been converted to terminators
    TBlock(_, _) | TLoop(_, _) | TIf(_, _, _, _) | TTryTable(_, _, _) => None
    TBr(_, _) | TBrIf(_, _, _) | TBrTable(_, _, _, _) => None
    TBrOnNull(_, _, _) | TBrOnNonNull(_, _, _) => None
    TBrOnCast(_, _, _, _, _, _) | TBrOnCastFail(_, _, _, _, _, _) => None
    TReturn(_) => None
    TReturnCall(_, _)
    | TReturnCallIndirect(_, _, _, _)
    | TReturnCallRef(_, _, _) => None
  }
}

///|
fn rename_args(
  args : Array[TInstr],
  builder : SSABuilder,
  out : Array[SSAInstr],
) -> Array[SSAValue] {
  let result : Array[SSAValue] = []
  for arg in args {
    match rename_instr(arg, builder, out) {
      Some(v) => result.push(v)
      None => ()
    }
  }
  result
}

///|
fn rename_terminator(
  term : Terminator,
  builder : SSABuilder,
  out : Array[SSAInstr],
) -> SSATerminator {
  match term {
    Br(target) => SSATerminator::Br(target)
    Unreachable => SSATerminator::Unreachable
    BrIf(cond, t, f) =>
      match rename_instr(cond, builder, out) {
        Some(cv) => SSATerminator::BrIf(cv, t, f)
        None => SSATerminator::Unreachable
      }
    BrTable(cond, targets, default) =>
      match rename_instr(cond, builder, out) {
        Some(cv) => SSATerminator::BrTable(cv, targets, default)
        None => SSATerminator::Unreachable
      }
    BrOnNull(val, t, f) =>
      match rename_instr(val, builder, out) {
        Some(v) => SSATerminator::BrOnNull(v, t, f)
        None => SSATerminator::Unreachable
      }
    BrOnNonNull(val, t, f) =>
      match rename_instr(val, builder, out) {
        Some(v) => SSATerminator::BrOnNonNull(v, t, f)
        None => SSATerminator::Unreachable
      }
    BrOnCast(op, ht1, ht2, val, t, f) =>
      match rename_instr(val, builder, out) {
        Some(v) => SSATerminator::BrOnCast(op, ht1, ht2, v, t, f)
        None => SSATerminator::Unreachable
      }
    BrOnCastFail(op, ht1, ht2, val, t, f) =>
      match rename_instr(val, builder, out) {
        Some(v) => SSATerminator::BrOnCastFail(op, ht1, ht2, v, t, f)
        None => SSATerminator::Unreachable
      }
    Return(values) => {
      let ssa_values = rename_args(values, builder, out)
      SSATerminator::Return(ssa_values)
    }
    ReturnCall(func, args) => {
      let ssa_args = rename_args(args, builder, out)
      SSATerminator::ReturnCall(func, ssa_args)
    }
    ReturnCallIndirect(ty, table, args, idx) => {
      let ssa_args = rename_args(args, builder, out)
      match rename_instr(idx, builder, out) {
        Some(i) => SSATerminator::ReturnCallIndirect(ty, table, ssa_args, i)
        None => SSATerminator::Unreachable
      }
    }
    ReturnCallRef(ty, args, func) => {
      let ssa_args = rename_args(args, builder, out)
      match rename_instr(func, builder, out) {
        Some(f) => SSATerminator::ReturnCallRef(ty, ssa_args, f)
        None => SSATerminator::Unreachable
      }
    }
    ThrowRef(val) =>
      match rename_instr(val, builder, out) {
        Some(v) => SSATerminator::ThrowRef(v)
        None => SSATerminator::Unreachable
      }
  }
}

// ============================================
// Block Renaming (DFS traversal)
// ============================================

///|
fn rename_block(
  cfg : CFG,
  block_id : BlockId,
  builder : SSABuilder,
  phi_placements : Map[BlockId, Set[LocalIdx]],
  dom_children : Map[BlockId, Array[BlockId]],
  ssa_blocks : Map[BlockId, SSABlock],
) -> Unit {
  let checkpoint = builder.save_checkpoint()
  let block = cfg.blocks[block_id]

  // Create phi nodes for this block
  let phis : Array[PhiNode] = []
  match phi_placements.get(block_id) {
    Some(locals) =>
      for l in locals {
        let result = builder.fresh()
        let phi = PhiNode::{ local_idx: l, result, args: Map::new() }
        phis.push(phi)
        builder.push_def(l, result)
      }
    None => ()
  }

  // Rename instructions
  let instrs : Array[SSAInstr] = []
  for instr in block.instrs {
    let _ = rename_instr(instr, builder, instrs)
  }

  // Rename terminator
  let terminator = rename_terminator(block.terminator, builder, instrs)

  // Create SSA block
  let ssa_block = SSABlock::{ id: block_id, phis, instrs, terminator }
  ssa_blocks[block_id] = ssa_block

  // Fill in phi arguments for successors
  let successors = get_successors(block.terminator)
  for succ in successors {
    match phi_placements.get(succ) {
      Some(locals) =>
        for l in locals {
          match builder.current_value(l) {
            Some(val) =>
              // Find the phi node in successor and add argument
              match ssa_blocks.get(succ) {
                Some(succ_block) =>
                  for phi in succ_block.phis {
                    if phi.local_idx == l {
                      phi.args[block_id] = val
                    }
                  }
                None => () // Successor not yet processed, will be filled later
              }
            None => ()
          }
        }
      None => ()
    }
  }

  // Recurse to dominator tree children
  match dom_children.get(block_id) {
    Some(children) =>
      for child in children {
        rename_block(
          cfg, child, builder, phi_placements, dom_children, ssa_blocks,
        )
      }
    None => ()
  }

  // Restore builder state
  builder.restore_checkpoint(checkpoint)
}

///|
fn get_successors(term : Terminator) -> Array[BlockId] {
  match term {
    Br(target) => [target]
    BrIf(_, t, f)
    | BrOnNull(_, t, f)
    | BrOnNonNull(_, t, f)
    | BrOnCast(_, _, _, _, t, f)
    | BrOnCastFail(_, _, _, _, t, f) => [t, f]
    BrTable(_, targets, default) => {
      let result = targets.copy()
      result.push(default)
      result
    }
    Return(_)
    | ReturnCall(_, _)
    | ReturnCallIndirect(_, _, _, _)
    | ReturnCallRef(_, _, _)
    | ThrowRef(_)
    | Unreachable => []
  }
}

// ============================================
// Second Pass: Fill phi arguments
// ============================================

///|
fn fill_phi_args(
  cfg : CFG,
  ssa_blocks : Map[BlockId, SSABlock],
  phi_placements : Map[BlockId, Set[LocalIdx]],
  builder : SSABuilder,
  dom_children : Map[BlockId, Array[BlockId]],
  block_id : BlockId,
) -> Unit {
  let checkpoint = builder.save_checkpoint()

  // Re-establish definitions for this block
  match ssa_blocks.get(block_id) {
    Some(ssa_block) =>
      // Push phi results
      for phi in ssa_block.phis {
        builder.push_def(phi.local_idx, phi.result)
      }

    // Walk through instructions to rebuild local state
    // (SSA values from Assign instructions that came from local.set/tee)
    // This is a simplified approach - in practice you'd track this during rename
    None => ()
  }

  // Fill phi args for successors
  let block = cfg.blocks[block_id]
  let successors = get_successors(block.terminator)
  for succ in successors {
    match ssa_blocks.get(succ) {
      Some(succ_block) =>
        for phi in succ_block.phis {
          if !phi.args.contains(block_id) {
            match builder.current_value(phi.local_idx) {
              Some(val) => phi.args[block_id] = val
              None => ()
            }
          }
        }
      None => ()
    }
  }

  // Recurse
  match dom_children.get(block_id) {
    Some(children) =>
      for child in children {
        fill_phi_args(
          cfg, ssa_blocks, phi_placements, builder, dom_children, child,
        )
      }
    None => ()
  }
  builder.restore_checkpoint(checkpoint)
}

// ============================================
// Main SSA Construction
// ============================================

///|
pub fn CFG::to_ssa(
  self : CFG,
  dom : Map[BlockId, BlockId],
  df : Map[BlockId, Set[BlockId]],
  param_count : Int,
) -> SSACFG {
  let builder = SSABuilder::new()

  // Initialize SSA values for function parameters
  let param_values : Map[LocalIdx, SSAValue] = Map::new()
  for i = 0; i < param_count; i = i + 1 {
    let l = LocalIdx::new(i.reinterpret_as_uint())
    let val = builder.fresh()
    param_values[l] = val
    builder.push_def(l, val)
  }

  // Place phi nodes
  let phi_placements = place_phi_nodes(self, df)

  // Build dominator tree (children map)
  let dom_children : Map[BlockId, Array[BlockId]] = Map::new()
  for entry in self.blocks {
    let (id, _) = entry
    dom_children[id] = []
  }
  for entry in dom {
    let (child, parent) = entry
    if child != parent { // Skip entry block
      match dom_children.get(parent) {
        Some(children) => children.push(child)
        None => dom_children[parent] = [child]
      }
    }
  }

  // Rename variables via DFS
  let ssa_blocks : Map[BlockId, SSABlock] = Map::new()
  rename_block(
    self,
    self.entry,
    builder,
    phi_placements,
    dom_children,
    ssa_blocks,
  )

  // Second pass to fill any remaining phi arguments
  let builder2 = SSABuilder::new()
  for i = 0; i < param_count; i = i + 1 {
    let l = LocalIdx::new(i.reinterpret_as_uint())
    match param_values.get(l) {
      Some(val) => builder2.push_def(l, val)
      None => ()
    }
  }
  fill_phi_args(
    self,
    ssa_blocks,
    phi_placements,
    builder2,
    dom_children,
    self.entry,
  )
  SSACFG::{
    entry: self.entry,
    blocks: ssa_blocks,
    preds: self.preds,
    param_values,
    next_value: builder.next_value,
  }
}
