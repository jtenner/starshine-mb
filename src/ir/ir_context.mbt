///|
pub fn IRContext::new() -> Self {
  {
    mod_: None,
    body: TExpr::new([]),
    locals: [],
    type_ctx: None,
    cfg: None,
    ssa: None,
    usedef: None,
    liveness: None,
    types: None,
    gvn: None,
    local_graph: None,
  }
}

///|
pub fn IRContext::get_mod(self : Self) -> Module? {
  self.mod_
}

///|
pub fn IRContext::set_body(self : Self, body : TExpr) -> Unit {
  self.body = body
  self.cfg_dirty()
}

///|
pub fn IRContext::set_mod(self : Self, mod_ : @lib.Module) -> Unit {
  self.mod_ = Some(mod_)
  // Module change invalidates everything
  self.cfg_dirty()
}

// --------------- Lazy getters ---------------

///|
pub fn IRContext::get_local_graph(self : Self) -> LocalGraph {
  match self.local_graph {
    Some(val) => val
    None => {
      let lg = LocalGraph::new(self.body.0)
      self.local_graph = Some(lg)
      lg
    }
  }
}

///|
pub fn IRContext::get_cfg(self : Self) -> CFG {
  match self.cfg {
    Some(val) => val
    None => {
      let cfg = CFG::build(self.body)
      self.cfg = Some(cfg)
      cfg
    }
  }
}

///|
pub fn IRContext::get_ssa(self : Self) -> SSACFG {
  match self.ssa {
    Some(val) => val
    None => {
      let cfg = self.get_cfg()
      let doms = cfg.dominators()
      let df = cfg.dominance_frontier()
      let ssa = cfg.to_ssa(doms, df, self.locals.length())
      let ssa = ssa.split_critical_edges()
      self.ssa = Some(ssa)
      ssa
    }
  }
}

///|
pub fn IRContext::get_usedef(self : Self) -> UseDefInfo {
  match self.usedef {
    Some(val) => val
    None => {
      let ssa = self.get_ssa()
      let ud = ssa.build_use_def()
      self.usedef = Some(ud)
      ud
    }
  }
}

///|
pub fn IRContext::get_liveness(self : Self) -> LivenessInfo {
  match self.liveness {
    Some(val) => val
    None => {
      let ssa = self.get_ssa()
      let li = ssa.compute_liveness()
      self.liveness = Some(li)
      li
    }
  }
}

///|
pub fn IRContext::get_types(self : Self) -> SSATypeInfo? {
  match self.types {
    Some(val) => Some(val)
    None => {
      let ssa = self.get_ssa()
      let type_ctx = match self.type_ctx {
        Some(ctx) => ctx
        None => return None
      }
      let ti = infer_ssa_types(ssa, type_ctx)
      self.types = Some(ti)
      Some(ti)
    }
  }
}

///|
pub fn IRContext::get_gvn(self : Self) -> SSACFG {
  match self.gvn {
    Some(val) => val
    None => {
      let ssa = self.get_ssa()
      let cfg = self.get_cfg()
      let doms = cfg.dominators()
      let optimized = run_gvn(ssa, doms)
      self.gvn = Some(optimized)
      optimized
    }
  }
}

// --------------- Cascading dirty flags ---------------

///|
/// Invalidates CFG and everything downstream.
pub fn IRContext::cfg_dirty(self : Self) -> Unit {
  self.cfg = None
  self.ssa_dirty()
}

///|
/// Invalidates SSA and everything that depends on it.
pub fn IRContext::ssa_dirty(self : Self) -> Unit {
  self.ssa = None
  self.usedef_dirty()
  self.liveness_dirty()
  self.types_dirty()
  self.gvn_dirty()
  self.local_graph_dirty()
}

///|
pub fn IRContext::usedef_dirty(self : Self) -> Unit {
  self.usedef = None
}

///|
pub fn IRContext::liveness_dirty(self : Self) -> Unit {
  self.liveness = None
}

///|
pub fn IRContext::types_dirty(self : Self) -> Unit {
  self.types = None
}

///|
pub fn IRContext::gvn_dirty(self : Self) -> Unit {
  self.gvn = None
}

///|
pub fn IRContext::local_graph_dirty(self : Self) -> Unit {
  self.local_graph = None
}

// --------------- Additional helpers ---------------

///|
/// Lowers the (possibly GVN-optimized) SSA back to a CFG.
pub fn IRContext::lower_to_cfg(self : Self) -> CFG {
  let ssa = self.get_gvn()
  ssa.to_cfg(self.locals.length())
}

///|
/// Applies GVN, replaces the cached SSA with the optimized version,
/// and invalidates downstream analyses so they're recomputed on demand.
pub fn IRContext::apply_gvn(self : Self) -> Unit {
  let optimized = self.get_gvn()
  self.ssa = Some(optimized)
  self.gvn = None
  // Downstream analyses were computed against the old SSA
  self.usedef = None
  self.liveness = None
  self.types = None
}

///|
/// Applies SSA optimization, updates cached SSA, and invalidates downstream
/// analyses that depend on SSA contents.
pub fn IRContext::apply_ssa_optimize(self : Self) -> Unit {
  let optimized = self.get_ssa().optimize()
  self.ssa = Some(optimized)
  self.gvn = None
  self.usedef = None
  self.liveness = None
  self.types = None
}

///|
fn terminator_successors(term : Terminator) -> Array[BlockId] {
  match term {
    Br(t) => [t]
    BrIf(_, t, f)
    | BrOnNull(_, t, f)
    | BrOnNonNull(_, t, f)
    | BrOnCast(_, _, _, _, t, f)
    | BrOnCastFail(_, _, _, _, t, f) => [t, f]
    BrTable(_, targets, d) => {
      let out = targets.copy()
      out.push(d)
      out
    }
    Return(_)
    | ReturnCall(_, _)
    | ReturnCallIndirect(_, _, _, _)
    | ReturnCallRef(_, _, _)
    | ThrowRef(_)
    | Unreachable => []
  }
}

///|
fn collect_reachable(
  cfg : CFG,
  start : BlockId,
  stop : BlockId?,
  max_steps : Int,
) -> Set[BlockId] {
  let seen : Set[BlockId] = Set::new()
  let work : Array[BlockId] = [start]
  let mut steps = 0
  while work.length() > 0 && steps < max_steps {
    steps = steps + 1
    let cur = work.pop().unwrap()
    if seen.contains(cur) {
      continue
    }
    seen.add(cur)
    if stop is Some(s) && cur == s {
      continue
    }
    match cfg.blocks.get(cur) {
      Some(block) =>
        for succ in terminator_successors(block.terminator) {
          work.push(succ)
        }
      None => ()
    }
  }
  seen
}

///|
fn find_merge_block(
  cfg : CFG,
  then_block : BlockId,
  else_block : BlockId,
  stop : BlockId?,
  max_steps : Int,
) -> BlockId? {
  let then_reachable = collect_reachable(cfg, then_block, stop, max_steps)
  let else_reachable = collect_reachable(cfg, else_block, stop, max_steps)
  if stop is Some(s) && then_reachable.contains(s) && else_reachable.contains(s) {
    return Some(s)
  }
  let mut best : BlockId? = None
  for b in then_reachable {
    if else_reachable.contains(b) {
      match best {
        None => best = Some(b)
        Some(cur) if b.0 < cur.0 => best = Some(b)
        _ => ()
      }
    }
  }
  best
}

///|
fn find_merge_block_many(
  cfg : CFG,
  succs : Array[BlockId],
  stop : BlockId?,
  max_steps : Int,
) -> BlockId? {
  if succs.length() == 0 {
    return None
  }
  if succs.length() == 1 {
    return Some(succs[0])
  }
  let mut reachable_intersection : Set[BlockId]? = None
  for succ in succs {
    let reachable = collect_reachable(cfg, succ, stop, max_steps)
    match reachable_intersection {
      None => reachable_intersection = Some(reachable)
      Some(acc) => {
        let next_acc : Set[BlockId] = Set::new()
        for b in acc {
          if reachable.contains(b) {
            next_acc.add(b)
          }
        }
        reachable_intersection = Some(next_acc)
      }
    }
  }
  match reachable_intersection {
    None => None
    Some(intersection) => {
      if stop is Some(s) && intersection.contains(s) {
        return Some(s)
      }
      let mut best : BlockId? = None
      for b in intersection {
        match best {
          None => best = Some(b)
          Some(cur) if b.0 < cur.0 => best = Some(b)
          _ => ()
        }
      }
      best
    }
  }
}

///|
fn append_texpr(dst : Array[TInstr], src : TExpr) -> Unit {
  for instr in src.0 {
    dst.push(instr)
  }
}

///|
fn lower_conditional_branch(
  cfg : CFG,
  instrs : Array[TInstr],
  cond : TInstr,
  then_block : BlockId,
  else_block : BlockId,
  stop : BlockId?,
  depth : Int,
  max_depth : Int,
) -> TExpr? {
  match find_merge_block(cfg, then_block, else_block, stop, max_depth * 2) {
    Some(merge) =>
      match
        (
          cfg_region_to_texpr(
            cfg,
            then_block,
            Some(merge),
            depth + 1,
            max_depth,
          ),
          cfg_region_to_texpr(
            cfg,
            else_block,
            Some(merge),
            depth + 1,
            max_depth,
          ),
        ) {
        (Some(then_expr), Some(else_expr)) => {
          let else_opt = if else_expr.0.length() == 0 {
            None
          } else {
            Some(else_expr)
          }
          instrs.push(
            TInstr::if_(BlockType::void_(), cond, then_expr, else_opt),
          )
          if stop is Some(s) && merge == s {
            return Some(TExpr::new(instrs))
          }
          match cfg_region_to_texpr(cfg, merge, stop, depth + 1, max_depth) {
            Some(tail) => {
              append_texpr(instrs, tail)
              Some(TExpr::new(instrs))
            }
            None => None
          }
        }
        _ => None
      }
    None =>
      match
        (
          cfg_region_to_texpr(cfg, then_block, stop, depth + 1, max_depth),
          cfg_region_to_texpr(cfg, else_block, stop, depth + 1, max_depth),
        ) {
        (Some(then_expr), Some(else_expr)) => {
          let else_opt = if else_expr.0.length() == 0 {
            None
          } else {
            Some(else_expr)
          }
          instrs.push(
            TInstr::if_(BlockType::void_(), cond, then_expr, else_opt),
          )
          Some(TExpr::new(instrs))
        }
        _ => None
      }
  }
}

///|
fn lower_br_table(
  cfg : CFG,
  instrs : Array[TInstr],
  idx : TInstr,
  targets : Array[BlockId],
  default : BlockId,
  stop : BlockId?,
  depth : Int,
  max_depth : Int,
) -> TExpr? {
  let succs = targets.copy()
  succs.push(default)
  let merge_opt = find_merge_block_many(cfg, succs, stop, max_depth * 2)
  let mut dispatch = match
    cfg_region_to_texpr(cfg, default, merge_opt, depth + 1, max_depth) {
    Some(expr) => expr
    None => return None
  }
  for i = targets.length() - 1; i >= 0; i = i - 1 {
    let then_expr = match
      cfg_region_to_texpr(cfg, targets[i], merge_opt, depth + 1, max_depth) {
      Some(expr) => expr
      None => return None
    }
    let cond = TInstr::binary(
      BinaryOp::i32_eq(),
      idx,
      TInstr::i32_const(I32(i)),
    )
    dispatch = TExpr::new([
      TInstr::if_(BlockType::void_(), cond, then_expr, Some(dispatch)),
    ])
  }
  append_texpr(instrs, dispatch)
  match merge_opt {
    Some(merge) => {
      if stop is Some(s) && merge == s {
        return Some(TExpr::new(instrs))
      }
      match cfg_region_to_texpr(cfg, merge, stop, depth + 1, max_depth) {
        Some(tail) => {
          append_texpr(instrs, tail)
          Some(TExpr::new(instrs))
        }
        None => None
      }
    }
    None => Some(TExpr::new(instrs))
  }
}

///|
fn cfg_region_to_texpr(
  cfg : CFG,
  block_id : BlockId,
  stop : BlockId?,
  depth : Int,
  max_depth : Int,
) -> TExpr? {
  if depth > max_depth {
    return None
  }
  if stop is Some(s) && block_id == s {
    return Some(TExpr::new([]))
  }
  let block = match cfg.blocks.get(block_id) {
    Some(b) => b
    None => return None
  }
  let instrs = block.instrs.copy()
  match block.terminator {
    Br(target) => {
      if stop is Some(s) && target == s {
        return Some(TExpr::new(instrs))
      }
      match cfg_region_to_texpr(cfg, target, stop, depth + 1, max_depth) {
        Some(tail) => {
          append_texpr(instrs, tail)
          Some(TExpr::new(instrs))
        }
        None => None
      }
    }
    BrIf(cond, then_block, else_block) =>
      lower_conditional_branch(
        cfg, instrs, cond, then_block, else_block, stop, depth, max_depth,
      )
    BrOnNull(v, null_block, nonnull_block) =>
      lower_conditional_branch(
        cfg,
        instrs,
        TInstr::ref_is_null(v),
        null_block,
        nonnull_block,
        stop,
        depth,
        max_depth,
      )
    BrOnNonNull(v, nonnull_block, null_block) =>
      lower_conditional_branch(
        cfg,
        instrs,
        TInstr::ref_is_null(v),
        null_block,
        nonnull_block,
        stop,
        depth,
        max_depth,
      )
    BrOnCast(op, _src_ht, dst_ht, v, success, fail) => {
      let cond = TInstr::ref_test(op.1, dst_ht, v)
      lower_conditional_branch(
        cfg, instrs, cond, success, fail, stop, depth, max_depth,
      )
    }
    BrOnCastFail(op, _src_ht, dst_ht, v, fail, success) => {
      let test_ok = TInstr::ref_test(op.1, dst_ht, v)
      let cond_fail = TInstr::unary(UnaryOp::i32_eqz(), test_ok)
      lower_conditional_branch(
        cfg, instrs, cond_fail, fail, success, stop, depth, max_depth,
      )
    }
    BrTable(idx, targets, default) =>
      lower_br_table(cfg, instrs, idx, targets, default, stop, depth, max_depth)
    Return(vals) => {
      instrs.push(TInstr::return_(vals))
      Some(TExpr::new(instrs))
    }
    ReturnCall(func, args) => {
      instrs.push(TInstr::return_call(func, args))
      Some(TExpr::new(instrs))
    }
    ReturnCallIndirect(ty, table, args, idx) => {
      instrs.push(TInstr::return_call_indirect(ty, table, args, idx))
      Some(TExpr::new(instrs))
    }
    ReturnCallRef(ty, args, func) => {
      instrs.push(TInstr::return_call_ref(ty, args, func))
      Some(TExpr::new(instrs))
    }
    ThrowRef(v) => {
      instrs.push(TInstr::throw_ref(v))
      Some(TExpr::new(instrs))
    }
    Unreachable => {
      instrs.push(TInstr::unreachable_())
      Some(TExpr::new(instrs))
    }
  }
}

///|
fn cfg_to_texpr(cfg : CFG) -> TExpr? {
  let max_depth = cfg.blocks.length() * 4 + 16
  cfg_region_to_texpr(cfg, cfg.entry, None, 0, max_depth)
}

///|
/// Runs SSA optimization and materializes a TExpr when the optimized CFG can be
/// represented by the supported structured CFG subset.
pub fn IRContext::optimize_body_with_ssa(self : Self) -> TExpr? {
  self.apply_ssa_optimize()
  let ssa = self.get_ssa()
  let cfg = ssa.to_cfg(self.locals.length())
  cfg_to_texpr(cfg)
}

///|
/// Validates the current CFG, returning an error string on failure.
pub fn IRContext::validate(self : Self) -> Result[Unit, String] {
  self.get_cfg().validate()
}

///|
pub fn IRContext::set_locals(self : Self, locals : Array[ValType]) -> Unit {
  self.locals = locals
  self.ssa_dirty()
}

///|
fn extract_comp_type(sub_type : SubType) -> CompType {
  match sub_type {
    SubType(_, _, comp) => comp
    CompTypeSubType(comp) => comp
  }
}

///|
fn resolve_func_type(comp_types : Array[CompType], idx : TypeIdx) -> FuncType {
  let i = match idx {
    TypeIdx(n) => n
    RecIdx(n) => n
  }
  match comp_types[i.reinterpret_as_int()] {
    FuncCompType(params, results) => FuncType::new(params, results)
    _ => abort("Expected func type at type index")
  }
}

///|
pub fn TypeContext::from_module(
  mod_ : Module,
  locals : Array[ValType],
) -> TypeContext {
  // 1. Flatten type section into CompTypes indexed by type index
  let comp_types : Array[CompType] = []
  match mod_.type_sec {
    Some(TypeSec(rec_types)) =>
      for rec_type in rec_types {
        match rec_type {
          SingleRecType(sub_type) =>
            comp_types.push(extract_comp_type(sub_type))
          GroupRecType(sub_types) =>
            for sub_type in sub_types {
              comp_types.push(extract_comp_type(sub_type))
            }
        }
      }
    None => ()
  }

  // 2. Collect from imports first (imports precede locals in index space)
  let func_types : Array[FuncType] = []
  let global_types : Array[GlobalType] = []
  let table_types : Array[TableType] = []
  let tag_types : Array[TagType] = []
  match mod_.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        let Import(_, _, extern_type) = import_
        match extern_type {
          FuncExternType(type_idx) =>
            func_types.push(resolve_func_type(comp_types, type_idx))
          TableExternType(tt) => table_types.push(tt)
          GlobalExternType(gt) => global_types.push(gt)
          TagExternType(tt) => tag_types.push(tt)
          MemExternType(_) => ()
        }
      }
    None => ()
  }

  // 3. Local function types (func_sec maps func index -> type index)
  match mod_.func_sec {
    Some(FuncSec(type_idxs)) =>
      for type_idx in type_idxs {
        func_types.push(resolve_func_type(comp_types, type_idx))
      }
    None => ()
  }

  // 4. Local globals
  match mod_.global_sec {
    Some(GlobalSec(globals)) =>
      for global in globals {
        let Global(gt, _) = global
        global_types.push(gt)
      }
    None => ()
  }

  // 5. Local tables
  match mod_.table_sec {
    Some(TableSec(tables)) =>
      for table in tables {
        let Table(tt, _) = table
        table_types.push(tt)
      }
    None => ()
  }

  // 6. Local tags
  match mod_.tag_sec {
    Some(TagSec(tags)) =>
      for tag in tags {
        tag_types.push(tag)
      }
    None => ()
  }

  // 7. Extract struct and array types from the flattened type section
  let struct_types : Array[Array[FieldType]] = []
  let array_types : Array[FieldType] = []
  for comp_type in comp_types {
    match comp_type {
      StructCompType(fields) => struct_types.push(fields)
      ArrayCompType(field) => array_types.push(field)
      FuncCompType(_, _) => ()
    }
  }
  {
    func_types,
    global_types,
    table_types,
    struct_types,
    array_types,
    tag_types,
    local_types: locals,
  }
}

///|
pub fn IRContext::get_type_ctx(self : Self) -> Result[TypeContext, String] {
  match self.type_ctx {
    Some(ctx) => Ok(ctx)
    None => {
      let mod_ = match self.get_mod() {
        None => return Err("No module set")
        Some(m) => m
      }
      let ctx = TypeContext::from_module(mod_, self.locals)
      self.type_ctx = Some(ctx)
      Ok(ctx)
    }
  }
}

///|
fn count_if_nodes(expr : TExpr) -> Int {
  let mut out = 0
  for instr in expr.0 {
    match instr {
      TIf(_, _, then_e, else_e) => {
        out = out + 1
        out = out + count_if_nodes(then_e)
        if else_e is Some(e) {
          out = out + count_if_nodes(e)
        }
      }
      _ => ()
    }
  }
  out
}

///|
fn extract_return_i32(expr : TExpr) -> Int? {
  for instr in expr.0 {
    match instr {
      TReturn([TI32Const(I32(v))]) => return Some(v)
      _ => ()
    }
  }
  None
}

///|
fn collect_return_i32s(expr : TExpr, out : Set[Int]) -> Unit {
  for instr in expr.0 {
    match instr {
      TIf(_, _, then_e, else_e) => {
        collect_return_i32s(then_e, out)
        if else_e is Some(e) {
          collect_return_i32s(e, out)
        }
      }
      TReturn([TI32Const(I32(v))]) => out.add(v)
      _ => ()
    }
  }
}

///|
test "cfg_to_texpr lowers BrTable into nested if dispatch" {
  let entry = BlockId(0)
  let case0 = BlockId(1)
  let case1 = BlockId(2)
  let default = BlockId(3)
  let blocks : Map[BlockId, BasicBlock] = {}
  blocks[entry] = {
    id: entry,
    instrs: [],
    terminator: BrTable(
      TInstr::local_get(LocalIdx::new(0)),
      [case0, case1],
      default,
    ),
  }
  blocks[case0] = {
    id: case0,
    instrs: [],
    terminator: Return([TInstr::i32_const(I32(10))]),
  }
  blocks[case1] = {
    id: case1,
    instrs: [],
    terminator: Return([TInstr::i32_const(I32(11))]),
  }
  blocks[default] = {
    id: default,
    instrs: [],
    terminator: Return([TInstr::i32_const(I32(99))]),
  }
  let cfg : CFG = { entry, blocks, preds: {} }
  match cfg_to_texpr(cfg) {
    Some(expr) => {
      assert_eq(count_if_nodes(expr), 2)
      let seen : Set[Int] = Set::new()
      collect_return_i32s(expr, seen)
      assert_true(seen.contains(10))
      assert_true(seen.contains(11))
      assert_true(seen.contains(99))
    }
    None => fail("Expected BrTable lowering to succeed")
  }
}

///|
test "cfg_to_texpr lowers BrOnNonNull with null in then branch" {
  let entry = BlockId(0)
  let nonnull = BlockId(1)
  let null_ = BlockId(2)
  let ref_val = TInstr::local_get(LocalIdx::new(0))
  let blocks : Map[BlockId, BasicBlock] = {}
  blocks[entry] = {
    id: entry,
    instrs: [],
    terminator: BrOnNonNull(ref_val, nonnull, null_),
  }
  blocks[nonnull] = {
    id: nonnull,
    instrs: [],
    terminator: Return([TInstr::i32_const(I32(7))]),
  }
  blocks[null_] = {
    id: null_,
    instrs: [],
    terminator: Return([TInstr::i32_const(I32(3))]),
  }
  let cfg : CFG = { entry, blocks, preds: {} }
  match cfg_to_texpr(cfg) {
    Some(TExpr(instrs)) =>
      match instrs {
        [TIf(_, cond, then_e, Some(else_e))] => {
          assert_eq(cond, TInstr::ref_is_null(ref_val))
          assert_eq(extract_return_i32(then_e), Some(3))
          assert_eq(extract_return_i32(else_e), Some(7))
        }
        _ => fail("Expected a single lowered if expression")
      }
    None => fail("Expected BrOnNonNull lowering to succeed")
  }
}

///|
test "cfg_to_texpr lowers BrOnCastFail with i32.eqz(ref.test)" {
  let entry = BlockId(0)
  let fail_block = BlockId(1)
  let success_block = BlockId(2)
  let ref_val = TInstr::local_get(LocalIdx::new(0))
  let dst_ht = HeapType::abs(AbsHeapType::eq())
  let castop = CastOp::new(true, false)
  let blocks : Map[BlockId, BasicBlock] = {}
  blocks[entry] = {
    id: entry,
    instrs: [],
    terminator: BrOnCastFail(
      castop,
      HeapType::abs(AbsHeapType::any()),
      dst_ht,
      ref_val,
      fail_block,
      success_block,
    ),
  }
  blocks[fail_block] = {
    id: fail_block,
    instrs: [],
    terminator: Return([TInstr::i32_const(I32(5))]),
  }
  blocks[success_block] = {
    id: success_block,
    instrs: [],
    terminator: Return([TInstr::i32_const(I32(8))]),
  }
  let cfg : CFG = { entry, blocks, preds: {} }
  match cfg_to_texpr(cfg) {
    Some(TExpr(instrs)) =>
      match instrs {
        [TIf(_, cond, then_e, Some(else_e))] => {
          assert_eq(
            cond,
            TInstr::unary(
              UnaryOp::i32_eqz(),
              TInstr::ref_test(false, dst_ht, ref_val),
            ),
          )
          assert_eq(extract_return_i32(then_e), Some(5))
          assert_eq(extract_return_i32(else_e), Some(8))
        }
        _ => fail("Expected a single lowered if expression")
      }
    None => fail("Expected BrOnCastFail lowering to succeed")
  }
}
