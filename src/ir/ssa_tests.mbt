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
