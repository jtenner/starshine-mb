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
        skip_current_func.val = locals.length() > 64 ||
          body.instrs.length() > 256
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
  let { instrs, .. } = expr
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
  rewritten = match rewritten.kind {
    TInstrKind::TBlock(_, body) if is_single_unreachable_texpr(body) =>
      TInstr::unreachable_()
    TInstrKind::TIf(_, cond, _, _) if dce_is_unreachable_instr(
        cond, break_scan_budget,
      ) => cond
    TInstrKind::TLoop(_, body) if is_single_unreachable_texpr(body) =>
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
  match instr.kind {
    TInstrKind::TBlock(_, _)
    | TInstrKind::TLoop(_, _)
    | TInstrKind::TIf(_, _, _, _)
    | TInstrKind::TTryTable(_, _, _) => true
    _ => false
  }
}

///|
fn is_single_unreachable_texpr(expr : TExpr) -> Bool {
  let { instrs, .. } = expr
  match instrs {
    [{ kind: TInstrKind::TUnreachable, .. }] => true
    _ => false
  }
}

///|
fn dce_texpr_is_unreachable(expr : TExpr, break_scan_budget : Ref[Int]) -> Bool {
  let { instrs, .. } = expr
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
  let { instrs, .. } = expr
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
  match instr.kind {
    TInstrKind::TBr(label, _) => label_matches_depth(label, depth)
    TInstrKind::TBrIf(label, _, _) => label_matches_depth(label, depth)
    TInstrKind::TBrTable(labels, default, _, _) => {
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
    TInstrKind::TBrOnNull(label, _, _)
    | TInstrKind::TBrOnNonNull(label, _, _)
    | TInstrKind::TBrOnCast(label, _, _, _, _, _)
    | TInstrKind::TBrOnCastFail(label, _, _, _, _, _) =>
      label_matches_depth(label, depth)
    TInstrKind::TBlock(_, body) | TInstrKind::TLoop(_, body) =>
      dce_has_break_to_depth_in_texpr(body, depth + 1, break_scan_budget)
    TInstrKind::TIf(_, cond, then_body, else_body) => {
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
    TInstrKind::TTryTable(_, catches, body) => {
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
  match instr.kind {
    TInstrKind::TUnreachable => true

    // Always transfer control away from the current continuation.
    TInstrKind::TBr(_, _)
    | TInstrKind::TBrTable(_, _, _, _)
    | TInstrKind::TReturn(_)
    | TInstrKind::TReturnCall(_, _)
    | TInstrKind::TReturnCallIndirect(_, _, _, _)
    | TInstrKind::TReturnCallRef(_, _, _)
    | TInstrKind::TThrow(_, _)
    | TInstrKind::TThrowRef(_) => true

    // Block is unreachable only when its body is unreachable and there are
    // no breaks to the block itself.
    TInstrKind::TBlock(_, body) =>
      dce_texpr_is_unreachable(body, break_scan_budget) &&
      !dce_has_break_to_depth_in_texpr(body, 0, break_scan_budget)

    // If is unreachable when condition is unreachable or both branches are.
    TInstrKind::TIf(_, cond, then_body, else_body) => {
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
    TInstrKind::TLoop(_, body) =>
      dce_texpr_is_unreachable(body, break_scan_budget)

    // try_table can finish normally only when its body can finish normally.
    TInstrKind::TTryTable(_, _, body) =>
      dce_texpr_is_unreachable(body, break_scan_budget)

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
  match instr.kind {
    // Zero-operand instructions.
    TInstrKind::TI32Const(_)
    | TInstrKind::TI64Const(_)
    | TInstrKind::TF32Const(_)
    | TInstrKind::TF64Const(_)
    | TInstrKind::TRefNull(_)
    | TInstrKind::TRefFunc(_)
    | TInstrKind::TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | TInstrKind::TUnreachable
    | TInstrKind::TNop
    | TInstrKind::TLocalGet(_)
    | TInstrKind::TGlobalGet(_)
    | TInstrKind::TMemorySize(_)
    | TInstrKind::TAtomicFence
    | TInstrKind::TTableSize(_)
    | TInstrKind::TDataDrop(_)
    | TInstrKind::TElemDrop(_)
    | TInstrKind::TStructNewDefault(_) => []

    // Unary operands.
    TInstrKind::TUnary(_, child)
    | TInstrKind::TDrop(child)
    | TInstrKind::TLocalSet(_, child)
    | TInstrKind::TLocalTee(_, child)
    | TInstrKind::TGlobalSet(_, child)
    | TInstrKind::TRefIsNull(child)
    | TInstrKind::TRefAsNonNull(child)
    | TInstrKind::TI31GetS(child)
    | TInstrKind::TI31GetU(child)
    | TInstrKind::TRefI31(child)
    | TInstrKind::TArrayLen(child)
    | TInstrKind::TAnyConvertExtern(child)
    | TInstrKind::TExternConvertAny(child)
    | TInstrKind::TThrowRef(child)
    | TInstrKind::TMemoryGrow(_, child)
    | TInstrKind::TTableGet(_, child)
    | TInstrKind::TLoad(_, _, child)
    | TInstrKind::TArrayNewDefault(_, child)
    | TInstrKind::TStructGet(_, _, child)
    | TInstrKind::TStructGetS(_, _, child)
    | TInstrKind::TStructGetU(_, _, child)
    | TInstrKind::TI8x16Splat(child)
    | TInstrKind::TI16x8Splat(child)
    | TInstrKind::TI32x4Splat(child)
    | TInstrKind::TI64x2Splat(child)
    | TInstrKind::TF32x4Splat(child)
    | TInstrKind::TF64x2Splat(child)
    | TInstrKind::TExtractLane(_, _, child)
    | TInstrKind::TRefTest(_, _, child)
    | TInstrKind::TRefCast(_, _, child)
    | TInstrKind::TRefGetDesc(child)
    | TInstrKind::TRefTestDesc(_, _, child)
    | TInstrKind::TRefCastDescEq(_, _, child) => [child]

    // Two operands.
    TInstrKind::TBinary(_, left, right)
    | TInstrKind::TRefEq(left, right)
    | TInstrKind::TStore(_, _, left, right)
    | TInstrKind::TMemoryAtomicNotify(_, left, right)
    | TInstrKind::TAtomicRmw(_, _, left, right)
    | TInstrKind::TTableSet(_, left, right)
    | TInstrKind::TTableGrow(_, left, right)
    | TInstrKind::TStructSet(_, _, left, right)
    | TInstrKind::TArrayNew(_, left, right)
    | TInstrKind::TArrayNewData(_, _, left, right)
    | TInstrKind::TArrayNewElem(_, _, left, right)
    | TInstrKind::TArrayGet(_, left, right)
    | TInstrKind::TArrayGetS(_, left, right)
    | TInstrKind::TArrayGetU(_, left, right)
    | TInstrKind::TReplaceLane(_, _, left, right)
    | TInstrKind::TI8x16Swizzle(left, right)
    | TInstrKind::TI8x16RelaxedSwizzle(left, right)
    | TInstrKind::TV128Shift(_, left, right)
    | TInstrKind::TV128LoadLane(_, _, _, left, right)
    | TInstrKind::TV128StoreLane(_, _, _, left, right) => [left, right]

    // Three operands.
    TInstrKind::TMemoryFill(_, a, b, c)
    | TInstrKind::TMemoryCopy(_, _, a, b, c)
    | TInstrKind::TMemoryInit(_, _, a, b, c)
    | TInstrKind::TMemoryAtomicWait32(_, a, b, c)
    | TInstrKind::TMemoryAtomicWait64(_, a, b, c)
    | TInstrKind::TAtomicCmpxchg(_, _, a, b, c)
    | TInstrKind::TTableFill(_, a, b, c)
    | TInstrKind::TTableCopy(_, _, a, b, c)
    | TInstrKind::TTableInit(_, _, a, b, c)
    | TInstrKind::TSelect(_, c, a, b)
    | TInstrKind::TV128Ternary(_, a, b, c) => [a, b, c]

    // Variable-length operands.
    TInstrKind::TCall(_, args)
    | TInstrKind::TReturnCall(_, args)
    | TInstrKind::TThrow(_, args)
    | TInstrKind::TBr(_, args)
    | TInstrKind::TReturn(args)
    | TInstrKind::TStructNew(_, args)
    | TInstrKind::TArrayNewFixed(_, args) => args.copy()
    TInstrKind::TCallIndirect(_, _, args, index)
    | TInstrKind::TReturnCallIndirect(_, _, args, index) => {
      let out = args.copy()
      out.push(index)
      out
    }
    TInstrKind::TCallRef(_, args, ref_)
    | TInstrKind::TReturnCallRef(_, args, ref_) => {
      let out = args.copy()
      out.push(ref_)
      out
    }
    TInstrKind::TBrIf(_, cond, values) => {
      let out = values.copy()
      out.push(cond)
      out
    }
    TInstrKind::TBrTable(_, _, index, values) => {
      let out = values.copy()
      out.push(index)
      out
    }
    TInstrKind::TBrOnNull(_, ref_, values)
    | TInstrKind::TBrOnNonNull(_, ref_, values)
    | TInstrKind::TBrOnCast(_, _, _, _, ref_, values)
    | TInstrKind::TBrOnCastFail(_, _, _, _, ref_, values) => {
      let out = values.copy()
      out.push(ref_)
      out
    }
    TInstrKind::TArraySet(_, a, b, c) => [a, b, c]
    TInstrKind::TArrayFill(_, a, b, c, d) => [a, b, c, d]
    TInstrKind::TArrayCopy(_, _, a, b, c, d, e) => [a, b, c, d, e]
    TInstrKind::TArrayInitData(_, _, a, b, c, d) => [a, b, c, d]
    TInstrKind::TArrayInitElem(_, _, a, b, c, d) => [a, b, c, d]
    TInstrKind::TI8x16Shuffle(
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      left,
      right
    ) => [left, right]

    // Control-flow structures are handled directly by control-flow logic.
    TInstrKind::TBlock(_, _)
    | TInstrKind::TLoop(_, _)
    | TInstrKind::TIf(_, _, _, _)
    | TInstrKind::TTryTable(_, _, _) => []
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
  match out.instrs {
    [
      {
        kind: TInstrKind::TBlock(
          VoidBlockType,
          {
            instrs: [
              {
                kind: TInstrKind::TDrop(
                  { kind: TInstrKind::TI32Const(I32(1)), .. }
                ),
                ..,
              },
              { kind: TInstrKind::TUnreachable, .. },
            ],
            ..,
          }
        ),
        ..,
      },
    ] => ()
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
  match out.instrs {
    [
      {
        kind: TInstrKind::TBlock(
          _,
          {
            instrs: [
              { kind: TInstrKind::TI32Const(I32(0)), .. },
              { kind: TInstrKind::TUnreachable, .. },
            ],
            ..,
          }
        ),
        ..,
      },
    ] => ()
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
  match out.instrs {
    [{ kind: TInstrKind::TUnreachable, .. }] => ()
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
  match out.instrs {
    [{ kind: TInstrKind::TUnreachable, .. }] => ()
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
  match out.instrs {
    [
      {
        kind: TInstrKind::TBlock(
          _,
          { instrs: [{ kind: TInstrKind::TBr(_, _), .. }], .. }
        ),
        ..,
      },
      { kind: TInstrKind::TI32Const(I32(2)), .. },
    ] => ()
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
  match out.instrs {
    [
      {
        kind: TInstrKind::TTryTable(
          _,
          _,
          { instrs: [{ kind: TInstrKind::TUnreachable, .. }], .. }
        ),
        ..,
      },
    ] => ()
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
  match out.instrs {
    [
      {
        kind: TInstrKind::TBlock(
          _,
          {
            instrs: [
              {
                kind: TInstrKind::TTryTable(
                  _,
                  _,
                  { instrs: [{ kind: TInstrKind::TUnreachable, .. }], .. }
                ),
                ..,
              },
            ],
            ..,
          }
        ),
        ..,
      },
      { kind: TInstrKind::TI32Const(I32(2)), .. },
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
  match out.instrs {
    [
      {
        kind: TInstrKind::TBlock(
          _,
          {
            instrs: [
              {
                kind: TInstrKind::TLoop(
                  _,
                  { instrs: [{ kind: TInstrKind::TBr(_, _), .. }], .. }
                ),
                ..,
              },
            ],
            ..,
          }
        ),
        ..,
      },
      { kind: TInstrKind::TI32Const(I32(2)), .. },
    ] => ()
    _ =>
      fail(
        "expected loop branch to enclosing block to keep continuation after block reachable",
      )
  }
}
