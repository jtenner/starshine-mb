///| 
/// Copyright 2023 WebAssembly Community Group participants
/// 
/// Licensed under the Apache License, Version 2.0 (the "License");
/// you may not use this file except in compliance with the License.
/// You may obtain a copy of the License at
/// 
///     http://www.apache.org/licenses/LICENSE-2.0
/// 
/// Unless required by applicable law or agreed to in writing, software
/// distributed under the License is distributed on an "AS IS" BASIS,
/// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
/// See the License for the specific language governing permissions and
/// limitations under the License.
///

///|
fn dead_code_elimination_pass() -> ModuleTransformer[Unit] {
  let break_scan_budget = Ref::new(20_000)
  let skip_current_func = Ref::new(false)
  ModuleTransformer::new()
  .on_func_evt(fn(_, ctx, func) {
    match func {
      TFunc(locals, body) =>
        skip_current_func.val = locals.length() > 64 || body.0.length() > 256
      _ => skip_current_func.val = false
    }
    if skip_current_func.val {
      change(ctx, func)
    } else {
      unchanged()
    }
  })
  .on_texpr_evt(fn(transformer, ctx, expr) {
    if skip_current_func.val {
      unchanged()
    } else {
      dce_texpr(transformer, ctx, expr, break_scan_budget)
    }
  })
  .on_tinstruction_evt(fn(transformer, ctx, instr) {
    if skip_current_func.val {
      unchanged()
    } else {
      dce_tinstr(transformer, ctx, instr, break_scan_budget)
    }
  })
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
  break_scan_budget : Ref[Int],
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
    if dce_is_unreachable_instr(new_instr, break_scan_budget) {
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
  break_scan_budget : Ref[Int],
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
    TIf(_, cond, _, _) if dce_is_unreachable_instr(cond, break_scan_budget) =>
      cond
    TLoop(_, body) if is_single_unreachable_texpr(body) =>
      TInstr::unreachable_()
    _ => rewritten
  }

  // Non-control rewrite:
  // If an unreachable child makes this expression unreachable,
  // keep effects before the first unreachable as drops, keep the first
  // unreachable child, and remove everything after.
  if !is_control_flow_structure(rewritten) &&
    dce_is_unreachable_instr(rewritten, break_scan_budget) &&
    dce_has_unreachable_child(rewritten, break_scan_budget) {
    rewritten = dce_rewrite_non_control_unreachable(
      rewritten, break_scan_budget,
    )
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
fn dce_texpr_is_unreachable(expr : TExpr, break_scan_budget : Ref[Int]) -> Bool {
  let TExpr(instrs) = expr
  if instrs.length() > 0 &&
    dce_is_unreachable_instr(instrs[instrs.length() - 1], break_scan_budget) {
    return true
  }
  for instr in instrs {
    if dce_is_unreachable_instr(instr, break_scan_budget) {
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
fn dce_has_break_to_depth_in_texpr(
  expr : TExpr,
  depth : Int,
  break_scan_budget : Ref[Int],
) -> Bool {
  let TExpr(instrs) = expr
  for instr in instrs {
    if dce_has_break_to_depth(instr, depth, break_scan_budget) {
      return true
    }
  }
  false
}

///|
fn dce_take_break_budget(break_scan_budget : Ref[Int]) -> Bool {
  if break_scan_budget.val <= 0 {
    true
  } else {
    break_scan_budget.val = break_scan_budget.val - 1
    false
  }
}

///|
fn dce_has_break_to_depth(
  instr : TInstr,
  depth : Int,
  break_scan_budget : Ref[Int],
) -> Bool {
  // Conservatively assume a matching break when analysis budget is exhausted.
  if dce_take_break_budget(break_scan_budget) {
    return true
  }
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
      dce_has_break_to_depth_in_texpr(body, depth + 1, break_scan_budget)
    TIf(_, cond, then_body, else_body) => {
      if dce_has_break_to_depth(cond, depth, break_scan_budget) {
        return true
      }
      if dce_has_break_to_depth_in_texpr(
          then_body,
          depth + 1,
          break_scan_budget,
        ) {
        return true
      }
      match else_body {
        Some(body) =>
          dce_has_break_to_depth_in_texpr(body, depth + 1, break_scan_budget)
        None => false
      }
    }
    TTryTable(_, catches, body) => {
      for catch_ in catches {
        if catch_targets_depth(catch_, depth + 1) {
          return true
        }
      }
      dce_has_break_to_depth_in_texpr(body, depth + 1, break_scan_budget)
    }
    _ => {
      for child in eval_children(instr) {
        if dce_has_break_to_depth(child, depth, break_scan_budget) {
          return true
        }
      }
      false
    }
  }
}

///|
fn dce_has_unreachable_child(
  instr : TInstr,
  break_scan_budget : Ref[Int],
) -> Bool {
  for child in eval_children(instr) {
    if dce_is_unreachable_instr(child, break_scan_budget) {
      return true
    }
  }
  false
}

///|
fn dce_is_unreachable_instr(
  instr : TInstr,
  break_scan_budget : Ref[Int],
) -> Bool {
  // When the analysis budget is exhausted, fall back to conservative behavior.
  if dce_take_break_budget(break_scan_budget) {
    return false
  }
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
      dce_texpr_is_unreachable(body, break_scan_budget) &&
      !dce_has_break_to_depth_in_texpr(body, 0, break_scan_budget)

    // If is unreachable when condition is unreachable or both branches are.
    TIf(_, cond, then_body, else_body) => {
      if dce_is_unreachable_instr(cond, break_scan_budget) {
        return true
      }
      match else_body {
        Some(other) =>
          dce_texpr_is_unreachable(then_body, break_scan_budget) &&
          dce_texpr_is_unreachable(other, break_scan_budget)
        None => false
      }
    }

    // Loop can only fall through if the body can fall through.
    TLoop(_, body) => dce_texpr_is_unreachable(body, break_scan_budget)

    // try_table can finish normally only when its body can finish normally.
    TTryTable(_, _, body) => dce_texpr_is_unreachable(body, break_scan_budget)

    // For non-control ops, any unreachable child makes the parent unreachable.
    _ => dce_has_unreachable_child(instr, break_scan_budget)
  }
}

///|
fn dce_rewrite_non_control_unreachable(
  instr : TInstr,
  break_scan_budget : Ref[Int],
) -> TInstr {
  let children = eval_children(instr)
  let remaining : Array[TInstr] = []
  let mut after_unreachable = false
  for child in children {
    if after_unreachable {
      continue
    }
    if dce_is_unreachable_instr(child, break_scan_budget) {
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
fn has_break_to_depth_in_texpr(expr : TExpr, depth : Int) -> Bool {
  dce_has_break_to_depth_in_texpr(expr, depth, Ref::new(200_000))
}

///|
fn is_unreachable_instr(instr : TInstr) -> Bool {
  dce_is_unreachable_instr(instr, Ref::new(200_000))
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
    | TAtomicFence
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
    | TRefCast(_, _, child)
    | TRefGetDesc(child)
    | TRefTestDesc(_, _, child)
    | TRefCastDescEq(_, _, child) => [child]

    // Two operands.
    TBinary(_, left, right)
    | TRefEq(left, right)
    | TStore(_, _, left, right)
    | TMemoryAtomicNotify(_, left, right)
    | TAtomicRmw(_, _, left, right)
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
    | TMemoryAtomicWait32(_, a, b, c)
    | TMemoryAtomicWait64(_, a, b, c)
    | TAtomicCmpxchg(_, _, a, b, c)
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

///|
test "dead code elim keeps outer continuation for try_table catch escape" {
  let input = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::try_table(
          BlockType::void_(),
          [Catch::all(LabelIdx::new(1))],
          TExpr::new([TInstr::unreachable_(), TInstr::i32_const(I32(1))]),
        ),
        TInstr::i32_const(I32(9)),
      ]),
    ),
    TInstr::i32_const(I32(2)),
  ])
  let out = run_dce_on_texpr(input)
  match out.0 {
    [
      TBlock(_, TExpr([TTryTable(_, _, TExpr([TUnreachable]))])),
      TI32Const(I32(2)),
    ] => ()
    _ =>
      fail(
        "expected try_table catch targeting enclosing block to preserve outer continuation",
      )
  }
}

///|
test "dead code elim keeps enclosing block reachable for loop branch escape" {
  let input = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::loop_(
          BlockType::void_(),
          TExpr::new([
            TInstr::br(LabelIdx::new(1), []),
            TInstr::i32_const(I32(1)),
          ]),
        ),
        TInstr::i32_const(I32(9)),
      ]),
    ),
    TInstr::i32_const(I32(2)),
  ])
  let out = run_dce_on_texpr(input)
  match out.0 {
    [TBlock(_, TExpr([TLoop(_, TExpr([TBr(_, _)]))])), TI32Const(I32(2))] => ()
    _ =>
      fail(
        "expected loop branch to enclosing block to keep continuation after block reachable",
      )
  }
}
