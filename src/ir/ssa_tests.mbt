///|
fn find_phi_for_local(block : SSABlock, local_idx : UInt) -> PhiNode? {
  for phi in block.phis {
    if phi.local_idx == LocalIdx::new(local_idx) {
      return Some(phi)
    }
  }
  None
}

///|
test "to_ssa inserts phi for branch-assigned local" {
  let expr = TExpr::new([
    TInstr::if_(
      BlockType::void_(),
      TInstr::local_get(LocalIdx::new(0)),
      TExpr::new([
        TInstr::local_set(LocalIdx::new(1), TInstr::i32_const(I32(11))),
      ]),
      Some(
        TExpr::new([
          TInstr::local_set(LocalIdx::new(1), TInstr::i32_const(I32(22))),
        ]),
      ),
    ),
    TInstr::return_([TInstr::local_get(LocalIdx::new(1))]),
  ])
  let cfg = CFG::build(expr)
  let ssa = cfg.to_ssa(cfg.dominators(), cfg.dominance_frontier(), 1)

  let entry = cfg.entry()
  let entry_succs = cfg.successors(entry)
  assert_eq(entry_succs.length(), 2)
  let then_block = entry_succs[0]
  let else_block = entry_succs[1]
  let then_succs = cfg.successors(then_block)
  let else_succs = cfg.successors(else_block)
  assert_eq(then_succs.length(), 1)
  assert_eq(else_succs.length(), 1)
  let merge = then_succs[0]
  assert_eq(else_succs[0], merge)

  let merge_block = ssa.blocks[merge]
  match find_phi_for_local(merge_block, 1U) {
    Some(phi) => {
      assert_eq(phi.args.length(), 2)
      assert_true(phi.args.contains(then_block))
      assert_true(phi.args.contains(else_block))
      match merge_block.terminator {
        Return(values) => {
          assert_eq(values.length(), 1)
          assert_eq(values[0], phi.result)
        }
        _ => fail("expected return terminator in merge block")
      }
    }
    None => fail("expected phi for local 1 in merge block")
  }
}

///|
test "to_ssa preserves parameter values in return terminator" {
  let expr = TExpr::new([
    TInstr::return_([
      TInstr::local_get(LocalIdx::new(0)),
      TInstr::local_get(LocalIdx::new(1)),
    ]),
  ])
  let cfg = CFG::build(expr)
  let ssa = cfg.to_ssa(cfg.dominators(), cfg.dominance_frontier(), 2)
  let p0 = ssa.param_values[LocalIdx::new(0)]
  let p1 = ssa.param_values[LocalIdx::new(1)]
  assert_true(p0 != p1)
  match ssa.blocks[ssa.entry].terminator {
    Return(values) => {
      assert_eq(values.length(), 2)
      assert_eq(values[0], p0)
      assert_eq(values[1], p1)
    }
    _ => fail("expected return terminator")
  }
}

///|
test "collect_instr_locals covers atomics tables arrays and call_ref" {
  let locals : Set[LocalIdx] = Set::new()
  let memarg = MemArg::new(U32(0), None, U64(0))

  collect_instr_locals(
    TInstr::memory_atomic_wait32(
      memarg,
      TInstr::local_get(LocalIdx::new(0)),
      TInstr::local_get(LocalIdx::new(1)),
      TInstr::local_get(LocalIdx::new(2)),
    ),
    locals,
  )
  collect_instr_locals(
    TInstr::table_copy(
      TableIdx::new(0U),
      TableIdx::new(1U),
      TInstr::local_get(LocalIdx::new(3)),
      TInstr::local_get(LocalIdx::new(4)),
      TInstr::local_get(LocalIdx::new(5)),
    ),
    locals,
  )
  collect_instr_locals(
    TInstr::array_copy(
      TypeIdx::new(0U),
      TypeIdx::new(1U),
      TInstr::local_get(LocalIdx::new(6)),
      TInstr::local_get(LocalIdx::new(7)),
      TInstr::local_get(LocalIdx::new(8)),
      TInstr::local_get(LocalIdx::new(9)),
      TInstr::local_get(LocalIdx::new(10)),
    ),
    locals,
  )
  collect_instr_locals(
    TInstr::call_ref(
      TypeIdx::new(0U),
      [TInstr::local_get(LocalIdx::new(11))],
      TInstr::local_get(LocalIdx::new(12)),
    ),
    locals,
  )

  for i = 0; i <= 12; i = i + 1 {
    assert_true(locals.contains(LocalIdx::new(i.reinterpret_as_uint())))
  }
}

///|
test "collect_terminator_locals covers return_call_ref operands" {
  let locals : Set[LocalIdx] = Set::new()
  collect_terminator_locals(
    Terminator::ReturnCallRef(
      TypeIdx::new(0U),
      [TInstr::local_get(LocalIdx::new(0)), TInstr::local_get(LocalIdx::new(1))],
      TInstr::local_get(LocalIdx::new(2)),
    ),
    locals,
  )
  assert_true(locals.contains(LocalIdx::new(0)))
  assert_true(locals.contains(LocalIdx::new(1)))
  assert_true(locals.contains(LocalIdx::new(2)))
}

///|
test "to_ssa threads phi values through atomic table array and call_ref families" {
  let memarg = MemArg::new(U32(0), None, U64(0))
  let b0 = BlockId(0)
  let b1 = BlockId(1)
  let b2 = BlockId(2)
  let b3 = BlockId(3)

  let blocks : Map[BlockId, BasicBlock] = {}
  blocks[b0] = BasicBlock::{
    id: b0,
    instrs: [],
    terminator: Terminator::BrIf(TInstr::local_get(LocalIdx::new(0)), b1, b2),
  }
  blocks[b1] = BasicBlock::{
    id: b1,
    instrs: [
      TInstr::local_set(LocalIdx::new(1), TInstr::i32_const(I32(16))),
      TInstr::local_set(LocalIdx::new(3), TInstr::ref_func(FuncIdx::new(0U))),
    ],
    terminator: Terminator::Br(b3),
  }
  blocks[b2] = BasicBlock::{
    id: b2,
    instrs: [
      TInstr::local_set(LocalIdx::new(1), TInstr::i32_const(I32(32))),
      TInstr::local_set(LocalIdx::new(3), TInstr::ref_func(FuncIdx::new(1U))),
    ],
    terminator: Terminator::Br(b3),
  }
  blocks[b3] = BasicBlock::{
    id: b3,
    instrs: [
      TInstr::local_set(
        LocalIdx::new(5),
        TInstr::memory_atomic_notify(
          memarg,
          TInstr::local_get(LocalIdx::new(1)),
          TInstr::local_get(LocalIdx::new(2)),
        ),
      ),
      TInstr::table_set(
        TableIdx::new(0U),
        TInstr::local_get(LocalIdx::new(1)),
        TInstr::local_get(LocalIdx::new(3)),
      ),
      TInstr::array_set(
        TypeIdx::new(0U),
        TInstr::local_get(LocalIdx::new(4)),
        TInstr::local_get(LocalIdx::new(1)),
        TInstr::local_get(LocalIdx::new(1)),
      ),
      TInstr::local_set(
        LocalIdx::new(6),
        TInstr::call_ref(
          TypeIdx::new(0U),
          [TInstr::local_get(LocalIdx::new(1))],
          TInstr::local_get(LocalIdx::new(3)),
        ),
      ),
    ],
    terminator: Terminator::ReturnCallRef(
      TypeIdx::new(0U),
      [TInstr::local_get(LocalIdx::new(5)), TInstr::local_get(LocalIdx::new(6))],
      TInstr::local_get(LocalIdx::new(3)),
    ),
  }

  let preds : Map[BlockId, Array[BlockId]] = {}
  preds[b0] = []
  preds[b1] = [b0]
  preds[b2] = [b0]
  preds[b3] = [b1, b2]

  let cfg = CFG::{ entry: b0, blocks, preds }
  let ssa = cfg.to_ssa(cfg.dominators(), cfg.dominance_frontier(), 5)
  let then_block = b1
  let else_block = b2
  let merge = b3
  let merge_block = ssa.blocks[merge]

  let idx_phi = match find_phi_for_local(merge_block, 1U) {
    Some(phi) => {
      assert_true(phi.args.contains(then_block))
      assert_true(phi.args.contains(else_block))
      phi
    }
    None => fail("expected phi for local 1")
  }
  let func_phi = match find_phi_for_local(merge_block, 3U) {
    Some(phi) => {
      assert_true(phi.args.contains(then_block))
      assert_true(phi.args.contains(else_block))
      phi
    }
    None => fail("expected phi for local 3")
  }

  let mut saw_atomic = false
  let mut saw_table = false
  let mut saw_array = false
  let mut saw_call_ref = false
  for instr in merge_block.instrs {
    match instr {
      Assign(_, SSAOp::MemoryAtomicNotify(_, addr, _)) => {
        assert_eq(addr, idx_phi.result)
        saw_atomic = true
      }
      Effect(SSAOp::TableSet(_, idx, value)) => {
        assert_eq(idx, idx_phi.result)
        assert_eq(value, func_phi.result)
        saw_table = true
      }
      Effect(SSAOp::ArraySet(_, _, idx, value)) => {
        assert_eq(idx, idx_phi.result)
        assert_eq(value, idx_phi.result)
        saw_array = true
      }
      Assign(_, SSAOp::CallRef(_, args, func)) => {
        assert_eq(args.length(), 1)
        assert_eq(args[0], idx_phi.result)
        assert_eq(func, func_phi.result)
        saw_call_ref = true
      }
      _ => ()
    }
  }
  assert_true(saw_atomic)
  assert_true(saw_table)
  assert_true(saw_array)
  assert_true(saw_call_ref)

  match merge_block.terminator {
    ReturnCallRef(_, _, func) => assert_eq(func, func_phi.result)
    _ => fail("expected return_call_ref terminator")
  }
}
