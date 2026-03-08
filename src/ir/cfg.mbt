///|
fn CFGBuilder::new() -> Self {
  CFGBuilder::{ next_block: 0, blocks: Map::new() }
}

///|
fn CFGBuilder::block(self : CFGBuilder) -> BlockId {
  let id = BlockId(self.next_block)
  self.next_block = self.next_block + 1
  id
}

///|
fn CFGBuilder::emit_block(
  self : CFGBuilder,
  id : BlockId,
  instrs : Array[TInstr],
  terminator : Terminator,
) -> Unit {
  self.blocks[id] = BasicBlock::{ id, instrs, terminator }
}

///|
fn compute_predecessors(
  blocks : Map[BlockId, BasicBlock],
) -> Map[BlockId, Array[BlockId]] {
  let preds : Map[BlockId, Array[BlockId]] = Map::new()
  for b in blocks {
    let (id, block) = b
    match block.terminator {
      Br(target) => preds.get_or_init(target, fn() { [] }).push(id)
      BrIf(_, t, f)
      | BrOnNull(_, t, f)
      | BrOnNonNull(_, t, f)
      | BrOnCast(_, _, _, _, t, f)
      | BrOnCastFail(_, _, _, _, t, f) => {
        preds.get_or_init(t, fn() { [] }).push(id)
        preds.get_or_init(f, fn() { [] }).push(id)
      }
      BrTable(_, targets, default) => {
        for t in targets {
          preds.get_or_init(t, fn() { [] }).push(id)
        }
        preds.get_or_init(default, fn() { [] }).push(id)
      }
      // No successors
      Return(_)
      | ReturnCall(_, _)
      | ReturnCallIndirect(_, _, _, _)
      | ReturnCallRef(_, _, _)
      | ThrowRef(_)
      | Unreachable => ()
    }
  }
  preds
}

///|
fn lower_if(
  cond : TInstr,
  then_expr : TExpr,
  else_expr : TExpr?,
  ctx : BlockContext,
  builder : CFGBuilder,
) -> BlockContext {
  let then_block = builder.block()
  let else_block = builder.block()
  let merge_block = builder.block()

  // Close current block
  builder.emit_block(
    ctx.id,
    ctx.instrs,
    Terminator::BrIf(cond, then_block, else_block),
  )

  // THEN branch
  let then_ctx = lower_expr(
    then_expr,
    BlockContext::{ id: then_block, instrs: [] },
    builder,
  )
  builder.emit_block(then_ctx.id, then_ctx.instrs, Terminator::Br(merge_block))

  // ELSE branch
  if else_expr is Some(e) {
    let else_ctx = lower_expr(
      e,
      BlockContext::{ id: else_block, instrs: [] },
      builder,
    )
    builder.emit_block(
      else_ctx.id,
      else_ctx.instrs,
      Terminator::Br(merge_block),
    )
  } else {
    builder.emit_block(else_block, [], Terminator::Br(merge_block))
  }

  // New current block
  BlockContext::{ id: merge_block, instrs: [] }
}

///|
fn lower_expr(
  expr : TExpr,
  ctx : BlockContext,
  builder : CFGBuilder,
) -> BlockContext {
  let mut ctx = ctx
  for instr in expr.instrs {
    match instr.kind {
      TInstrKind::TIf(_, cond, then_e, else_e) =>
        ctx = lower_if(cond, then_e, else_e, ctx, builder)
      TInstrKind::TReturn(args) => {
        builder.emit_block(ctx.id, ctx.instrs, Return(args))
        return ctx
      }
      _ => ctx.instrs.push(instr)
    }
  }
  ctx
}

///|
fn build_dom_tree(idom : Map[BlockId, BlockId]) -> Map[BlockId, Array[BlockId]] {
  let tree = Map::new()
  for b in idom {
    let (b, p) = b
    if b != p {
      tree.get_or_init(p, () => []).push(b)
    }
  }
  tree
}

///|
fn intersect(
  idom : Map[BlockId, BlockId?],
  a : BlockId,
  b : BlockId,
) -> BlockId {
  let mut x = a
  let mut y = b
  while x != y {
    while x.0 > y.0 {
      x = idom[x].unwrap()
    }
    while y.0 > x.0 {
      y = idom[y].unwrap()
    }
  }
  x
}

///|
fn compute_rpo(cfg : CFG) -> Array[BlockId] {
  let visited = Set::new()
  let order = Array::new()
  fn dfs(id) {
    if visited.contains(id) {
      return
    }
    visited.add(id)
    for succ in cfg.successors(id) {
      dfs(succ)
    }
    order.push(id)
  }

  dfs(cfg.entry())
  order.rev_in_place()
  order
}

///|
pub fn CFG::build(expr : TExpr) -> CFG {
  let builder = CFGBuilder::new()
  let entry = builder.block()
  let entry_ctx = BlockContext::{ id: entry, instrs: [] }
  let final_ctx = lower_expr(expr, entry_ctx, builder)

  // Ensure final block is terminated
  if !builder.blocks.contains(final_ctx.id) {
    builder.emit_block(final_ctx.id, final_ctx.instrs, Terminator::Unreachable)
  }
  let preds = compute_predecessors(builder.blocks)
  CFG::{ entry, blocks: builder.blocks, preds }
}

///|
pub fn CFG::successors(self : CFG, id : BlockId) -> Array[BlockId] {
  match self.blocks.get(id) {
    Some({ terminator: Br(t), .. }) => [t]
    Some({ terminator: BrIf(_, t, f), .. }) => [t, f]
    Some({ terminator: BrTable(_, targets, d), .. }) => {
      let result = targets.copy()
      result.push(d)
      result
    }
    _ => []
  }
}

///|
pub fn CFG::predecessors(self : CFG, id : BlockId) -> Array[BlockId] {
  self.preds.get(id).unwrap_or([])
}

///|
pub fn CFG::block(self : CFG, id : BlockId) -> BasicBlock? {
  self.blocks.get(id)
}

///|
pub fn CFG::entry(self : CFG) -> BlockId {
  self.entry
}

///|
pub fn CFG::dominators(self : CFG) -> Map[BlockId, BlockId] {
  // 1. Compute traversal order
  let rpo = compute_rpo(self)

  // 2. Initialize idoms
  let idom = Map::new()
  for b in self.blocks.keys() {
    idom[b] = None
  }
  idom[self.entry()] = Some(self.entry())

  // 3. Iteratively compute idoms
  let mut changed = true
  while changed {
    changed = false
    for b in rpo {
      if b == self.entry() {
        continue
      }
      let preds = self.predecessors(b).filter(p => idom[p] is Some(_))
      if preds.is_empty() {
        continue
      }
      let mut new_idom = preds[0]
      for p in preds.op_as_view(start=1, end=preds.length()) {
        new_idom = intersect(idom, p, new_idom)
      }
      if idom[b] != Some(new_idom) {
        idom[b] = Some(new_idom)
        changed = true
      }
    }
  }

  // 4. Finalize result (unwrap)
  let result = Map::new()
  for b in idom {
    let (b, d) = b
    if d is Some(x) {
      result[b] = x
    }
  }
  result
}

///|
pub fn CFG::dominates(self : CFG, a : BlockId, b : BlockId) -> Bool {
  if a == b {
    return true
  }
  let idom = self.dominators()
  let mut cur = b
  while cur != self.entry() {
    cur = idom[cur]
    if cur == a {
      return true
    }
  }
  false
}

///|
pub fn CFG::strict_dominates(self : CFG, a : BlockId, b : BlockId) -> Bool {
  a != b && self.dominates(a, b)
}

///|
pub fn CFG::validate(self : CFG) -> Result[Unit, String] {
  for b in self.blocks {
    let (id, _) = b
    // Entry has no predecessors
    if id == self.entry && self.predecessors(id).length() != 0 {
      return Err("entry block has predecessors")
    }

    // Terminator successors must exist
    for succ in self.successors(id) {
      if !self.blocks.contains(succ) {
        return Err("block has invalid successor")
      }
    }
  }
  Ok(())
}

///|
pub fn CFG::dominance_frontier(self : CFG) -> Map[BlockId, Set[BlockId]] {
  let idom = self.dominators()
  let dom_tree = build_dom_tree(idom)

  // Initialize DF sets
  let df = Map::new()
  for b in self.blocks {
    let (b, _) = b
    df[b] = Set::new()
  }

  // Step 1: local DF
  for b in self.blocks {
    let (b, _) = b
    for s in self.successors(b) {
      if idom[s] != b {
        df[b].add(s)
      }
    }
  }

  // Step 2: up the dominator tree
  fn dfs(
    b : BlockId,
    cfg : CFG,
    dom_tree : Map[BlockId, Array[BlockId]],
    idom : Map[BlockId, BlockId],
    df : Map[BlockId, Set[BlockId]],
  ) -> Unit {
    for c in dom_tree.get(b).unwrap_or([]) {
      dfs(c, cfg, dom_tree, idom, df)
      for w in df[c] {
        if idom[w] != b {
          df[b].add(w)
        }
      }
    }
  }

  dfs(self.entry(), self, dom_tree, idom, df)
  df
}
