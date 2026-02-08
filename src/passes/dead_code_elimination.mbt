///|
fn dead_code_elimination_pass() -> ModuleTransformer[Unit] {
  ModuleTransformer::new()
  .on_texpr_evt(dce_texpr)
  .on_tinstruction_evt(dce_tinstr)
}

///|
fn dead_code_elimination_ir_pass(_mod : Module) -> ModuleTransformer[IRContext] {
  wrap_unit_func_pass(dead_code_elimination_pass())
}

///|
fn dce_texpr(
  transformer : ModuleTransformer[Unit],
  _ctx : Unit,
  expr : TExpr,
) -> TransformerResult[Unit, TExpr] {
  let TExpr(instrs) = expr
  let out : Array[TInstr] = []
  let mut changed = false
  let mut after_unreachable = false
  for instr in instrs {
    if after_unreachable {
      changed = true
      continue
    }
    let new_instr = match transformer.walk_tinstruction((), instr) {
      Err(e) => return Err(e)
      Ok(None) => instr
      Ok(Some((_, updated))) => updated
    }
    if new_instr != instr {
      changed = true
    }
    out.push(new_instr)
    if is_unreachable_instr(new_instr) {
      after_unreachable = true
    }
  }
  if !changed {
    unchanged()
  } else {
    change((), TExpr::new(out))
  }
}

///|
fn dce_tinstr(
  transformer : ModuleTransformer[Unit],
  _ctx : Unit,
  instr : TInstr,
) -> TransformerResult[Unit, TInstr] {
  let walked = match transformer.walk_tinstruction_default((), instr) {
    Err(e) => return Err(e)
    Ok(None) => instr
    Ok(Some((_, updated))) => updated
  }
  let mut rewritten = walked

  // Control-flow-structure rewrites that need explicit handling.
  rewritten = match rewritten {
    TBlock(_, body) if is_single_unreachable_texpr(body) =>
      TInstr::unreachable_()
    TIf(_, cond, _, _) if is_unreachable_instr(cond) => cond
    TLoop(_, body) if is_single_unreachable_texpr(body) =>
      TInstr::unreachable_()
    _ => rewritten
  }

  // Non-control rewrite:
  // If an unreachable child makes this expression unreachable,
  // keep effects before the first unreachable as drops, keep the first
  // unreachable child, and remove everything after.
  if !is_control_flow_structure(rewritten) &&
    is_unreachable_instr(rewritten) &&
    has_unreachable_child(rewritten) {
    rewritten = rewrite_non_control_unreachable(rewritten)
  }
  if rewritten == instr {
    unchanged()
  } else {
    change((), rewritten)
  }
}

///|
fn is_control_flow_structure(instr : TInstr) -> Bool {
  match instr {
    TBlock(_, _) | TLoop(_, _) | TIf(_, _, _, _) | TTryTable(_, _, _) => true
    _ => false
  }
}

///|
fn is_single_unreachable_texpr(expr : TExpr) -> Bool {
  let TExpr(instrs) = expr
  match instrs {
    [TUnreachable] => true
    _ => false
  }
}

///|
fn texpr_is_unreachable(expr : TExpr) -> Bool {
  let TExpr(instrs) = expr
  for instr in instrs {
    if is_unreachable_instr(instr) {
      return true
    }
  }
  false
}

///|
fn label_matches_depth(label : LabelIdx, depth : Int) -> Bool {
  let LabelIdx(raw) = label
  raw.reinterpret_as_int() == depth
}

///|
fn catch_targets_depth(catch_ : Catch, depth : Int) -> Bool {
  match catch_ {
    Catch(_, label)
    | CatchRef(_, label)
    | CatchAll(label)
    | CatchAllRef(label) => label_matches_depth(label, depth)
  }
}

///|
fn has_break_to_depth_in_texpr(expr : TExpr, depth : Int) -> Bool {
  let TExpr(instrs) = expr
  for instr in instrs {
    if has_break_to_depth(instr, depth) {
      return true
    }
  }
  false
}

///|
fn has_break_to_depth(instr : TInstr, depth : Int) -> Bool {
  match instr {
    TBr(label, _) => label_matches_depth(label, depth)
    TBrIf(label, _, _) => label_matches_depth(label, depth)
    TBrTable(labels, default, _, _) => {
      if label_matches_depth(default, depth) {
        return true
      }
      for label in labels {
        if label_matches_depth(label, depth) {
          return true
        }
      }
      false
    }
    TBrOnNull(label, _, _)
    | TBrOnNonNull(label, _, _)
    | TBrOnCast(label, _, _, _, _, _)
    | TBrOnCastFail(label, _, _, _, _, _) => label_matches_depth(label, depth)
    TBlock(_, body) | TLoop(_, body) =>
      has_break_to_depth_in_texpr(body, depth + 1)
    TIf(_, cond, then_body, else_body) => {
      if has_break_to_depth(cond, depth) {
        return true
      }
      if has_break_to_depth_in_texpr(then_body, depth + 1) {
        return true
      }
      match else_body {
        Some(body) => has_break_to_depth_in_texpr(body, depth + 1)
        None => false
      }
    }
    TTryTable(_, catches, body) => {
      for catch_ in catches {
        if catch_targets_depth(catch_, depth + 1) {
          return true
        }
      }
      has_break_to_depth_in_texpr(body, depth + 1)
    }
    _ => {
      for child in eval_children(instr) {
        if has_break_to_depth(child, depth) {
          return true
        }
      }
      false
    }
  }
}

///|
fn has_unreachable_child(instr : TInstr) -> Bool {
  for child in eval_children(instr) {
    if is_unreachable_instr(child) {
      return true
    }
  }
  false
}

///|
fn is_unreachable_instr(instr : TInstr) -> Bool {
  match instr {
    TUnreachable => true

    // Always transfer control away from the current continuation.
    TBr(_, _)
    | TBrTable(_, _, _, _)
    | TReturn(_)
    | TReturnCall(_, _)
    | TReturnCallIndirect(_, _, _, _)
    | TReturnCallRef(_, _, _)
    | TThrow(_, _)
    | TThrowRef(_) => true

    // Block is unreachable only when its body is unreachable and there are
    // no breaks to the block itself.
    TBlock(_, body) =>
      texpr_is_unreachable(body) && !has_break_to_depth_in_texpr(body, 0)

    // If is unreachable when condition is unreachable or both branches are.
    TIf(_, cond, then_body, else_body) => {
      if is_unreachable_instr(cond) {
        return true
      }
      match else_body {
        Some(other) =>
          texpr_is_unreachable(then_body) && texpr_is_unreachable(other)
        None => false
      }
    }

    // Loop can only fall through if the body can fall through.
    TLoop(_, body) => texpr_is_unreachable(body)

    // try_table can finish normally only when its body can finish normally.
    TTryTable(_, _, body) => texpr_is_unreachable(body)

    // For non-control ops, any unreachable child makes the parent unreachable.
    _ => has_unreachable_child(instr)
  }
}

///|
fn rewrite_non_control_unreachable(instr : TInstr) -> TInstr {
  let children = eval_children(instr)
  let remaining : Array[TInstr] = []
  let mut after_unreachable = false
  for child in children {
    if after_unreachable {
      continue
    }
    if is_unreachable_instr(child) {
      remaining.push(child)
      after_unreachable = true
    } else {
      remaining.push(TInstr::drop(child))
    }
  }
  match remaining {
    [single] => single
    _ => TInstr::block(BlockType::void_(), TExpr::new(remaining))
  }
}

///|
fn eval_children(instr : TInstr) -> Array[TInstr] {
  match instr {
    // Zero-operand instructions.
    TI32Const(_)
    | TI64Const(_)
    | TF32Const(_)
    | TF64Const(_)
    | TRefNull(_)
    | TRefFunc(_)
    | TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | TUnreachable
    | TNop
    | TLocalGet(_)
    | TGlobalGet(_)
    | TMemorySize(_)
    | TTableSize(_)
    | TDataDrop(_)
    | TElemDrop(_)
    | TStructNewDefault(_) => []

    // Unary operands.
    TUnary(_, child)
    | TDrop(child)
    | TLocalSet(_, child)
    | TLocalTee(_, child)
    | TGlobalSet(_, child)
    | TRefIsNull(child)
    | TRefAsNonNull(child)
    | TI31GetS(child)
    | TI31GetU(child)
    | TRefI31(child)
    | TArrayLen(child)
    | TAnyConvertExtern(child)
    | TExternConvertAny(child)
    | TThrowRef(child)
    | TMemoryGrow(_, child)
    | TTableGet(_, child)
    | TLoad(_, _, child)
    | TArrayNewDefault(_, child)
    | TStructGet(_, _, child)
    | TStructGetS(_, _, child)
    | TStructGetU(_, _, child)
    | TI8x16Splat(child)
    | TI16x8Splat(child)
    | TI32x4Splat(child)
    | TI64x2Splat(child)
    | TF32x4Splat(child)
    | TF64x2Splat(child)
    | TExtractLane(_, _, child)
    | TRefTest(_, _, child)
    | TRefCast(_, _, child) => [child]

    // Two operands.
    TBinary(_, left, right)
    | TRefEq(left, right)
    | TStore(_, _, left, right)
    | TTableSet(_, left, right)
    | TTableGrow(_, left, right)
    | TStructSet(_, _, left, right)
    | TArrayNew(_, left, right)
    | TArrayNewData(_, _, left, right)
    | TArrayNewElem(_, _, left, right)
    | TArrayGet(_, left, right)
    | TArrayGetS(_, left, right)
    | TArrayGetU(_, left, right)
    | TReplaceLane(_, _, left, right)
    | TI8x16Swizzle(left, right)
    | TI8x16RelaxedSwizzle(left, right)
    | TV128Shift(_, left, right)
    | TV128LoadLane(_, _, _, left, right)
    | TV128StoreLane(_, _, _, left, right) => [left, right]

    // Three operands.
    TMemoryFill(_, a, b, c)
    | TMemoryCopy(_, _, a, b, c)
    | TMemoryInit(_, _, a, b, c)
    | TTableFill(_, a, b, c)
    | TTableCopy(_, _, a, b, c)
    | TTableInit(_, _, a, b, c)
    | TSelect(_, c, a, b)
    | TV128Ternary(_, a, b, c) => [a, b, c]

    // Variable-length operands.
    TCall(_, args)
    | TReturnCall(_, args)
    | TThrow(_, args)
    | TBr(_, args)
    | TReturn(args)
    | TStructNew(_, args)
    | TArrayNewFixed(_, args) => args.copy()
    TCallIndirect(_, _, args, index) | TReturnCallIndirect(_, _, args, index) => {
      let out = args.copy()
      out.push(index)
      out
    }
    TCallRef(_, args, ref_) | TReturnCallRef(_, args, ref_) => {
      let out = args.copy()
      out.push(ref_)
      out
    }
    TBrIf(_, cond, values) => {
      let out = values.copy()
      out.push(cond)
      out
    }
    TBrTable(_, _, index, values) => {
      let out = values.copy()
      out.push(index)
      out
    }
    TBrOnNull(_, ref_, values)
    | TBrOnNonNull(_, ref_, values)
    | TBrOnCast(_, _, _, _, ref_, values)
    | TBrOnCastFail(_, _, _, _, ref_, values) => {
      let out = values.copy()
      out.push(ref_)
      out
    }
    TArraySet(_, a, b, c) => [a, b, c]
    TArrayFill(_, a, b, c, d) => [a, b, c, d]
    TArrayCopy(_, _, a, b, c, d, e) => [a, b, c, d, e]
    TArrayInitData(_, _, a, b, c, d) => [a, b, c, d]
    TArrayInitElem(_, _, a, b, c, d) => [a, b, c, d]
    TI8x16Shuffle(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, left, right) =>
      [left, right]

    // Control-flow structures are handled directly by control-flow logic.
    TBlock(_, _) | TLoop(_, _) | TIf(_, _, _, _) | TTryTable(_, _, _) => []
  }
}

///|
fn run_dce_on_texpr(expr : TExpr) -> TExpr {
  let pass = dead_code_elimination_pass()
  match pass.walk_texpr((), expr) {
    Ok(Some((_, out))) => out
    _ => expr
  }
}

///|
test "dead code elim rewrites non-control unreachable operands" {
  let input = TExpr::new([
    TInstr::binary(
      BinaryOp::i32_add(),
      TInstr::i32_const(I32(1)),
      TInstr::unreachable_(),
    ),
  ])
  let out = run_dce_on_texpr(input)
  match out.0 {
    [TBlock(VoidBlockType, TExpr([TDrop(TI32Const(I32(1))), TUnreachable]))] =>
      ()
    _ => fail("expected add to rewrite to block(drop(const), unreachable)")
  }
}

///|
test "dead code elim truncates block tails after unreachable" {
  let input = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::i32_const(I32(0)),
        TInstr::unreachable_(),
        TInstr::i32_const(I32(1)),
      ]),
    ),
  ])
  let out = run_dce_on_texpr(input)
  match out.0 {
    [TBlock(_, TExpr([TI32Const(I32(0)), TUnreachable]))] => ()
    _ => fail("expected block tail after unreachable to be removed")
  }
}

///|
test "dead code elim simplifies if when condition is unreachable" {
  let input = TExpr::new([
    TInstr::if_(
      BlockType::void_(),
      TInstr::unreachable_(),
      TExpr::new([TInstr::i32_const(I32(1))]),
      Some(TExpr::new([TInstr::i32_const(I32(2))])),
    ),
    TInstr::i32_const(I32(3)),
  ])
  let out = run_dce_on_texpr(input)
  match out.0 {
    [TUnreachable] => ()
    _ => fail("expected if(cond=unreachable) to become unreachable")
  }
}

///|
test "dead code elim simplifies loop with unreachable body" {
  let input = TExpr::new([
    TInstr::loop_(
      BlockType::void_(),
      TExpr::new([TInstr::unreachable_(), TInstr::i32_const(I32(1))]),
    ),
    TInstr::i32_const(I32(2)),
  ])
  let out = run_dce_on_texpr(input)
  match out.0 {
    [TUnreachable] => ()
    _ => fail("expected loop(unreachable) to become unreachable")
  }
}

///|
test "dead code elim keeps outer continuation when block has break" {
  let input = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([TInstr::br(LabelIdx::new(0), []), TInstr::i32_const(I32(1))]),
    ),
    TInstr::i32_const(I32(2)),
  ])
  let out = run_dce_on_texpr(input)
  match out.0 {
    [TBlock(_, TExpr([TBr(_, _)])), TI32Const(I32(2))] => ()
    _ => fail("expected block with br 0 to preserve outer continuation")
  }
}

///|
test "dead code elim propagates unreachable through try_table" {
  let input = TExpr::new([
    TInstr::try_table(
      BlockType::void_(),
      [],
      TExpr::new([TInstr::unreachable_(), TInstr::i32_const(I32(1))]),
    ),
    TInstr::i32_const(I32(2)),
  ])
  let out = run_dce_on_texpr(input)
  match out.0 {
    [TTryTable(_, _, TExpr([TUnreachable]))] => ()
    _ => fail("expected try_table(unreachable body) to make continuation dead")
  }
}
