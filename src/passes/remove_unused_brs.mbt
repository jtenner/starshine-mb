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
const RUB_TOO_COSTLY_TO_RUN_UNCONDITIONALLY : Int = 8

///|
const RUB_HAS_CANDIDATE_FOUND : String = "__remove_unused_brs_has_candidate_found__"

///|
const RUB_LABEL_REBASE_CROSSES_REMOVED_SCOPE : String = "__remove_unused_brs_label_rebase_crosses_removed_scope__"

///|
priv struct RUBWalkState {
  in_function_body : Bool
  allow_list_splicing : Bool
  zero_break_is_fallthrough : Bool
}

///|
fn rub_walk_state(
  in_function_body : Bool,
  allow_list_splicing : Bool,
  zero_break_is_fallthrough : Bool,
) -> RUBWalkState {
  { in_function_body, allow_list_splicing, zero_break_is_fallthrough }
}

///|
fn rub_walk_nested_texpr_state(
  bt : BlockType,
  zero_break_is_fallthrough : Bool,
) -> RUBWalkState {
  match bt {
    VoidBlockType => rub_walk_state(false, true, zero_break_is_fallthrough)
    _ => rub_walk_state(false, false, zero_break_is_fallthrough)
  }
}

///|
fn ModuleTransformer::rub_walk_tinstruction_result(
  self : ModuleTransformer[RUBWalkState],
  state : RUBWalkState,
  instr : TInstr,
) -> Result[TInstr, String] {
  match self.walk_tinstruction(state, instr) {
    Ok(Some((_, next_instr))) => Ok(next_instr)
    Ok(None) => Ok(instr)
    Err(e) => Err(e)
  }
}

///|
fn ModuleTransformer::rub_walk_texpr_result(
  self : ModuleTransformer[RUBWalkState],
  state : RUBWalkState,
  expr : TExpr,
) -> Result[TExpr, String] {
  match self.walk_texpr(state, expr) {
    Ok(Some((_, next_expr))) => Ok(next_expr)
    Ok(None) => Ok(expr)
    Err(e) => Err(e)
  }
}

///|
fn ModuleTransformer::rub_walk_blocktype_result(
  self : ModuleTransformer[RUBWalkState],
  state : RUBWalkState,
  bt : BlockType,
) -> Result[BlockType, String] {
  match self.walk_blocktype(state, bt) {
    Ok(Some((_, next_bt))) => Ok(next_bt)
    Ok(None) => Ok(bt)
    Err(e) => Err(e)
  }
}

///|
fn ModuleTransformer::rub_walk_catches_result(
  self : ModuleTransformer[RUBWalkState],
  state : RUBWalkState,
  catches : Array[Catch],
) -> Result[Array[Catch], String] {
  match self.walk_array(state, ModuleTransformer::walk_catch, catches) {
    Ok(Some((_, next_catches))) => Ok(next_catches)
    Ok(None) => Ok(catches)
    Err(e) => Err(e)
  }
}

///|
fn rub_label_to_int(label : LabelIdx) -> Int {
  let LabelIdx(raw) = label
  raw.reinterpret_as_int()
}

///|
fn rub_label_from_int(idx : Int) -> LabelIdx {
  LabelIdx::new(idx.reinterpret_as_uint())
}

///|
fn rub_is_label_zero(label : LabelIdx) -> Bool {
  rub_label_to_int(label) == 0
}

///|
fn rub_shift_label_at_depth(
  label : LabelIdx,
  depth : Int,
  delta : Int,
) -> Result[LabelIdx, String] {
  if delta == 0 {
    return Ok(label)
  }
  let curr = rub_label_to_int(label)
  if delta > 0 {
    if curr >= depth {
      Ok(rub_label_from_int(curr + delta))
    } else {
      Ok(label)
    }
  } else {
    let removed_scopes = -delta
    if curr < depth {
      Ok(label)
    } else if curr < depth + removed_scopes {
      Err(RUB_LABEL_REBASE_CROSSES_REMOVED_SCOPE)
    } else {
      Ok(rub_label_from_int(curr + delta))
    }
  }
}

///|
fn rub_walk_tinstruction_with_depth(
  transformer : ModuleTransformer[Int],
  depth : Int,
  instr : TInstr,
) -> TransformerResult[Int, TInstr] {
  match instr.kind {
    TInstrKind::TBlock(bt, body) => {
      let next_body = match transformer.walk_texpr(depth + 1, body) {
        Ok(Some((_, out))) => out
        Ok(None) => body
        Err(e) => return Err(e)
      }
      if next_body == body {
        unchanged()
      } else {
        change(depth, TInstr::block(bt, next_body))
      }
    }
    TInstrKind::TLoop(bt, body) => {
      let next_body = match transformer.walk_texpr(depth + 1, body) {
        Ok(Some((_, out))) => out
        Ok(None) => body
        Err(e) => return Err(e)
      }
      if next_body == body {
        unchanged()
      } else {
        change(depth, TInstr::loop_(bt, next_body))
      }
    }
    TInstrKind::TIf(bt, cond, then_body, else_body) => {
      let next_cond = match transformer.walk_tinstruction(depth, cond) {
        Ok(Some((_, out))) => out
        Ok(None) => cond
        Err(e) => return Err(e)
      }
      let next_then = match transformer.walk_texpr(depth + 1, then_body) {
        Ok(Some((_, out))) => out
        Ok(None) => then_body
        Err(e) => return Err(e)
      }
      let next_else = match else_body {
        Some(other) =>
          match transformer.walk_texpr(depth + 1, other) {
            Ok(Some((_, out))) => Some(out)
            Ok(None) => Some(other)
            Err(e) => return Err(e)
          }
        None => None
      }
      let next_instr = TInstr::if_(bt, next_cond, next_then, next_else)
      if next_instr == instr {
        unchanged()
      } else {
        change(depth, next_instr)
      }
    }
    TInstrKind::TTryTable(bt, catches, body) => {
      let next_catches = match
        transformer.walk_array(
          depth + 1,
          ModuleTransformer::walk_catch,
          catches,
        ) {
        Ok(Some((_, out))) => out
        Ok(None) => catches
        Err(e) => return Err(e)
      }
      let next_body = match transformer.walk_texpr(depth + 1, body) {
        Ok(Some((_, out))) => out
        Ok(None) => body
        Err(e) => return Err(e)
      }
      let next_instr = TInstr::try_table(bt, next_catches, next_body)
      if next_instr == instr {
        unchanged()
      } else {
        change(depth, next_instr)
      }
    }
    _ => transformer.walk_tinstruction_default(depth, instr)
  }
}

///|
fn rub_rebase_labels_in_texpr_result(
  expr : TExpr,
  delta : Int,
) -> Result[TExpr, String] {
  if delta == 0 {
    return Ok(expr)
  }
  let pass = ModuleTransformer::new()
    .on_labelidx_evt(fn(_, depth, label) {
      match rub_shift_label_at_depth(label, depth, delta) {
        Ok(next) =>
          if next == label {
            unchanged()
          } else {
            change(depth, next)
          }
        Err(e) => Err(e)
      }
    })
    .on_tinstruction_evt(fn(self, depth, instr) {
      rub_walk_tinstruction_with_depth(self, depth, instr)
    })
  match pass.walk_texpr(0, expr) {
    Ok(Some((_, out))) => Ok(out)
    Ok(None) => Ok(expr)
    Err(e) => Err(e)
  }
}

///|
fn rub_rebase_labels_in_tinstruction_result(
  instr : TInstr,
  delta : Int,
) -> Result[TInstr, String] {
  if delta == 0 {
    return Ok(instr)
  }
  let pass = ModuleTransformer::new()
    .on_labelidx_evt(fn(_, depth, label) {
      match rub_shift_label_at_depth(label, depth, delta) {
        Ok(next) =>
          if next == label {
            unchanged()
          } else {
            change(depth, next)
          }
        Err(e) => Err(e)
      }
    })
    .on_tinstruction_evt(fn(self, depth, curr) {
      rub_walk_tinstruction_with_depth(self, depth, curr)
    })
  match pass.walk_tinstruction(0, instr) {
    Ok(Some((_, out))) => Ok(out)
    Ok(None) => Ok(instr)
    Err(e) => Err(e)
  }
}

///|
fn rub_try_rebase_labels_in_texpr(expr : TExpr, delta : Int) -> TExpr? {
  match rub_rebase_labels_in_texpr_result(expr, delta) {
    Ok(out) => Some(out)
    Err(e) =>
      if e == RUB_LABEL_REBASE_CROSSES_REMOVED_SCOPE {
        None
      } else {
        abort("unexpected remove_unused_brs texpr label rebase failure: \{e}")
      }
  }
}

///|
fn rub_try_rebase_labels_in_tinstruction(
  instr : TInstr,
  delta : Int,
) -> TInstr? {
  match rub_rebase_labels_in_tinstruction_result(instr, delta) {
    Ok(out) => Some(out)
    Err(e) =>
      if e == RUB_LABEL_REBASE_CROSSES_REMOVED_SCOPE {
        None
      } else {
        abort(
          "unexpected remove_unused_brs tinstruction label rebase failure: \{e}",
        )
      }
  }
}

///|
fn rub_rebase_labels_in_texpr(expr : TExpr, delta : Int) -> TExpr {
  match rub_rebase_labels_in_texpr_result(expr, delta) {
    Ok(out) => out
    Err(e) => abort("remove_unused_brs label rebase failed: \{e}")
  }
}

///|
fn rub_rebase_labels_in_tinstruction(instr : TInstr, delta : Int) -> TInstr {
  match rub_rebase_labels_in_tinstruction_result(instr, delta) {
    Ok(out) => out
    Err(e) => abort("remove_unused_brs label rebase failed: \{e}")
  }
}

///|
fn rub_zero_i32() -> TInstr {
  TInstr::i32_const(I32(0))
}

///|
fn rub_one_i32() -> TInstr {
  TInstr::i32_const(I32(1))
}

///|
fn rub_is_const_i32(instr : TInstr) -> Int? {
  match instr.kind {
    TInstrKind::TI32Const(I32(v)) => Some(v)
    _ => None
  }
}

///|
fn rub_has_side_effects(instr : TInstr) -> Bool {
  lcs_collect_effects(instr).has_unremovable_side_effects()
}

///|
fn rub_is_single_tinstr(expr : TExpr) -> TInstr? {
  match expr.instrs {
    [single] => Some(single)
    _ => None
  }
}

///|
fn rub_instr_has_branch(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TBr(_, _)
    | TInstrKind::TBrIf(_, _, _)
    | TInstrKind::TBrTable(_, _, _, _)
    | TInstrKind::TBrOnNull(_, _, _)
    | TInstrKind::TBrOnNonNull(_, _, _)
    | TInstrKind::TBrOnCast(_, _, _, _, _, _)
    | TInstrKind::TBrOnCastFail(_, _, _, _, _, _)
    | TInstrKind::TReturn(_)
    | TInstrKind::TReturnCall(_, _)
    | TInstrKind::TReturnCallIndirect(_, _, _, _)
    | TInstrKind::TReturnCallRef(_, _, _)
    | TInstrKind::TThrow(_, _)
    | TInstrKind::TThrowRef(_) => true
    TInstrKind::TBlock(_, body)
    | TInstrKind::TLoop(_, body)
    | TInstrKind::TTryTable(_, _, body) => rub_texpr_has_branch(body)
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      if rub_instr_has_branch(cond) || rub_texpr_has_branch(then_body) {
        return true
      }
      match else_body {
        Some(other) => rub_texpr_has_branch(other)
        None => false
      }
    }
    _ => {
      for child in eval_children(instr) {
        if rub_instr_has_branch(child) {
          return true
        }
      }
      false
    }
  }
}

///|
fn rub_texpr_has_branch(expr : TExpr) -> Bool {
  for instr in expr.instrs {
    if rub_instr_has_branch(instr) {
      return true
    }
  }
  false
}

///|
fn rub_instr_cost(instr : TInstr) -> Int {
  match instr.kind {
    TInstrKind::TI32Const(_)
    | TInstrKind::TI64Const(_)
    | TInstrKind::TF32Const(_)
    | TInstrKind::TF64Const(_)
    | TInstrKind::TRefNull(_)
    | TInstrKind::TRefFunc(_)
    | TInstrKind::TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | TInstrKind::TLocalGet(_)
    | TInstrKind::TNop => 0
    TInstrKind::TThrow(_, _) | TInstrKind::TThrowRef(_) =>
      RUB_TOO_COSTLY_TO_RUN_UNCONDITIONALLY
    TInstrKind::TRefCast(_, _, _) =>
      RUB_TOO_COSTLY_TO_RUN_UNCONDITIONALLY / 2 + 1
    _ => {
      let mut total = 1
      for child in eval_children(instr) {
        total += rub_instr_cost(child)
      }
      total
    }
  }
}

///|
fn rub_too_costly_to_run_unconditionally(
  options : OptimizeOptions,
  cost : Int,
) -> Bool {
  if options.shrink_level == 0 {
    cost > RUB_TOO_COSTLY_TO_RUN_UNCONDITIONALLY / 2
  } else if options.shrink_level == 1 {
    cost >= RUB_TOO_COSTLY_TO_RUN_UNCONDITIONALLY
  } else {
    false
  }
}

///|
fn rub_too_costly_expr(options : OptimizeOptions, instr : TInstr) -> Bool {
  if options.shrink_level >= 2 {
    return false
  }
  rub_too_costly_to_run_unconditionally(options, rub_instr_cost(instr))
}

///|
fn rub_too_costly_pair(
  options : OptimizeOptions,
  one : TInstr,
  two : TInstr,
) -> Bool {
  if options.shrink_level >= 2 {
    return false
  }
  let cost = Int::max(rub_instr_cost(one), rub_instr_cost(two))
  rub_too_costly_to_run_unconditionally(options, cost)
}

///|
fn rub_instr_list_effects(instrs : Array[TInstr]) -> LCSEffects {
  lcs_collect_effects(TInstr::block(BlockType::void_(), TExpr::new(instrs)))
}

///|
fn rub_values_cost(instrs : Array[TInstr]) -> Int {
  let mut total = 0
  for instr in instrs {
    total += rub_instr_cost(instr)
  }
  total
}

///|
fn rub_branch_values_are_hoistable(
  if_condition : TInstr,
  values : Array[TInstr],
  options : OptimizeOptions,
) -> Bool {
  if values.length() == 0 {
    return true
  }
  let value_effects = rub_instr_list_effects(values)
  if value_effects.has_unremovable_side_effects() {
    return false
  }
  if lcs_collect_effects(if_condition).invalidates(value_effects) {
    return false
  }
  !rub_too_costly_to_run_unconditionally(options, rub_values_cost(values))
}

///|
fn rub_can_turn_if_into_br_if(
  if_condition : TInstr,
  br_values : Array[TInstr],
  options : OptimizeOptions,
) -> Bool {
  if is_unreachable_instr(if_condition) {
    return false
  }
  rub_branch_values_are_hoistable(if_condition, br_values, options)
}

///|
fn rub_fold_condition_to_bool(instr : TInstr) -> Bool? {
  match rub_is_const_i32(instr) {
    Some(v) => Some(v != 0)
    None =>
      match instr.kind {
        TInstrKind::TUnary(I32EqzOp, inner) =>
          match rub_is_const_i32(inner) {
            Some(v) => Some(v == 0)
            None => None
          }
        _ => None
      }
  }
}

///|
fn rub_default_only_switch(default_ : LabelIdx, cond : TInstr) -> TInstr {
  let next_cond = rub_rebase_labels_in_tinstruction(cond, 1)
  let next_default = match rub_shift_label_at_depth(default_, 0, 1) {
    Ok(next_default) => next_default
    Err(e) => abort("remove_unused_brs default-only switch rebase failed: \{e}")
  }
  TInstr::block(
    BlockType::void_(),
    TExpr::new([TInstr::drop(next_cond), TInstr::br(next_default, [])]),
  )
}

///|
fn rub_single_target_switch(
  target : LabelIdx,
  default_ : LabelIdx,
  cond : TInstr,
) -> TInstr {
  let next_target = match rub_shift_label_at_depth(target, 0, 1) {
    Ok(next_target) => next_target
    Err(e) =>
      abort("remove_unused_brs single-target switch rebase failed: \{e}")
  }
  let next_default = match rub_shift_label_at_depth(default_, 0, 1) {
    Ok(next_default) => next_default
    Err(e) =>
      abort("remove_unused_brs single-target switch rebase failed: \{e}")
  }
  TInstr::if_(
    BlockType::void_(),
    cond,
    TExpr::new([TInstr::br(next_default, [])]),
    Some(TExpr::new([TInstr::br(next_target, [])])),
  )
}

///|
fn rub_optimize_br_table(instr : TInstr) -> (TInstr, Bool) {
  match instr.kind {
    TInstrKind::TBrTable(targets, default_, cond, values) => {
      let mut changed = false
      let mut targets = targets.copy()
      while targets.length() > 0 && targets[targets.length() - 1] == default_ {
        ignore(targets.pop())
        changed = true
      }
      let mut removable = 0
      while removable < targets.length() && targets[removable] == default_ {
        removable += 1
      }
      let mut cond = cond
      if removable > 0 {
        let shifted : Array[LabelIdx] = []
        for i in removable..<targets.length() {
          shifted.push(targets[i])
        }
        targets = shifted
        cond = TInstr::binary(
          BinaryOp::i32_sub(),
          cond,
          TInstr::i32_const(I32(removable)),
        )
        changed = true
      }

      if values.length() > 0 {
        let out = TInstr::br_table(targets, default_, cond, values)
        return (out, changed)
      }

      let unique : Set[LabelIdx] = Set::new()
      unique.add(default_)
      for target in targets {
        unique.add(target)
      }
      if unique.length() == 1 {
        return (rub_default_only_switch(default_, cond), true)
      }

      if targets.length() == 0 {
        return (rub_default_only_switch(default_, cond), true)
      }
      if targets.length() == 1 {
        return (rub_single_target_switch(targets[0], default_, cond), true)
      }
      (TInstr::br_table(targets, default_, cond, values), changed)
    }
    _ => (instr, false)
  }
}

///|
fn rub_optimize_if(instr : TInstr, options : OptimizeOptions) -> (TInstr, Bool) {
  match instr.kind {
    TInstrKind::TIf(bt, condition, then_body, else_body) =>
      match else_body {
        Some(_) => (instr, false)
        None =>
          match rub_is_single_tinstr(then_body) {
            Some(single_then) =>
              match rub_try_rebase_labels_in_tinstruction(single_then, -1) {
                Some({ kind: TInstrKind::TBr(label, values), .. }) =>
                  if rub_can_turn_if_into_br_if(condition, values, options) {
                    (TInstr::br_if(label, condition, values), true)
                  } else {
                    (instr, false)
                  }
                Some({ kind: TInstrKind::TBrIf(label, inner_cond, values), .. }) => {
                  if values.length() != 0 ||
                    rub_has_side_effects(inner_cond) ||
                    rub_too_costly_pair(options, inner_cond, rub_zero_i32()) {
                    return (instr, false)
                  }
                  let next_cond = TInstr::select(
                    None,
                    inner_cond,
                    condition,
                    rub_zero_i32(),
                  )
                  (TInstr::br_if(label, next_cond, []), true)
                }
                Some(
                  {
                    kind: TInstrKind::TIf(
                      child_bt,
                      child_cond,
                      child_then,
                      None
                    ),
                    ..,
                  }
                ) => {
                  if child_bt != bt {
                    return (instr, false)
                  }
                  if rub_has_side_effects(child_cond) ||
                    rub_too_costly_expr(options, child_cond) {
                    return (instr, false)
                  }
                  let next_cond = TInstr::select(
                    None,
                    child_cond,
                    condition,
                    rub_zero_i32(),
                  )
                  (TInstr::if_(bt, next_cond, child_then, None), true)
                }
                Some(_) => (instr, false)
                None => (instr, false)
              }
            None => (instr, false)
          }
      }
    _ => (instr, false)
  }
}

///|
fn rub_optimize_br_if(instr : TInstr) -> (TInstr, Bool) {
  match instr.kind {
    TInstrKind::TBrIf(label, cond, values) =>
      match rub_fold_condition_to_bool(cond) {
        Some(true) => (TInstr::br(label, values), true)
        Some(false) =>
          match values {
            [] => (TInstr::drop(cond), true)
            [single] => {
              let next_single = rub_rebase_labels_in_tinstruction(single, 1)
              let next_cond = rub_rebase_labels_in_tinstruction(cond, 1)
              (
                TInstr::block(
                  BlockType::void_(),
                  TExpr::new([
                    TInstr::drop(next_single),
                    TInstr::drop(next_cond),
                  ]),
                ),
                true,
              )
            }
            _ => (instr, false)
          }
        None => (instr, false)
      }
    _ => (instr, false)
  }
}

///|
fn rub_remove_trailing_nops(instrs : Array[TInstr]) -> Bool {
  let mut changed = false
  while instrs.length() > 0 {
    match instrs[instrs.length() - 1].kind {
      TInstrKind::TNop => {
        ignore(instrs.pop())
        changed = true
      }
      _ => return changed
    }
  }
  changed
}

///|
fn rub_remove_trailing_flow_break(instrs : Array[TInstr]) -> Bool {
  if instrs.length() == 0 {
    return false
  }
  let idx = instrs.length() - 1
  match instrs[idx].kind {
    TInstrKind::TBr(label, values) => {
      if !rub_is_label_zero(label) {
        return false
      }
      match values {
        [] => {
          ignore(instrs.pop())
          true
        }
        [single] => {
          instrs[idx] = single
          true
        }
        _ => false
      }
    }
    _ => false
  }
}

///|
fn rub_remove_trailing_return(instrs : Array[TInstr]) -> Bool {
  if instrs.length() == 0 {
    return false
  }
  let idx = instrs.length() - 1
  match instrs[idx].kind {
    TInstrKind::TReturn(values) =>
      match values {
        [] => {
          ignore(instrs.pop())
          true
        }
        [single] => {
          instrs[idx] = single
          true
        }
        _ => false
      }
    _ => false
  }
}

///|
fn rub_optimize_adjacent_breaks(
  instrs : Array[TInstr],
  options : OptimizeOptions,
) -> Bool {
  let mut changed = false
  let mut i = 0
  while i + 1 < instrs.length() {
    match instrs[i].kind {
      TInstrKind::TBrIf(label1, cond1, values1) =>
        if values1.length() == 0 {
          match instrs[i + 1].kind {
            TInstrKind::TBr(label2, values2) =>
              if label1 == label2 && values2.length() == 0 {
                instrs[i] = TInstr::drop(cond1)
                changed = true
              }
            TInstrKind::TBrIf(label2, cond2, values2) =>
              if label1 == label2 &&
                values2.length() == 0 &&
                options.shrink_level > 0 &&
                !rub_has_side_effects(cond2) {
                instrs[i] = TInstr::br_if(
                  label1,
                  TInstr::binary(BinaryOp::i32_or(), cond1, cond2),
                  [],
                )
                instrs[i + 1] = TInstr::nop()
                changed = true
              }
            _ => ()
          }
        }
      _ => ()
    }
    i += 1
  }
  changed
}

///|
fn rub_optimize_if_else_block_tail(
  instrs : Array[TInstr],
  options : OptimizeOptions,
  allow_list_splicing : Bool,
) -> Bool {
  if !allow_list_splicing {
    return false
  }
  let mut changed = false
  let mut i = 0
  while i < instrs.length() {
    match instrs[i].kind {
      TInstrKind::TIf(VoidBlockType, cond, then_body, Some(else_body)) => {
        let mut applied = false
        match rub_is_single_tinstr(then_body) {
          Some(single_then) =>
            match
              (
                rub_try_rebase_labels_in_tinstruction(single_then, -1),
                rub_try_rebase_labels_in_texpr(else_body, -1),
              ) {
              (
                Some({ kind: TInstrKind::TBr(label, values), .. }),
                Some(next_else_body),
              ) if !rub_texpr_has_branch(else_body) &&
                rub_can_turn_if_into_br_if(cond, values, options) => {
                instrs[i] = TInstr::br_if(label, cond, values)
                let next : Array[TInstr] = []
                for j in 0..<instrs.length() {
                  next.push(instrs[j])
                  if j == i {
                    for item in next_else_body.instrs {
                      next.push(item)
                    }
                  }
                }
                instrs.clear()
                for item in next {
                  instrs.push(item)
                }
                changed = true
                i += next_else_body.instrs.length()
                applied = true
              }
              _ => ()
            }
          None => ()
        }
        if !applied {
          match rub_is_single_tinstr(else_body) {
            Some(single_else) =>
              match
                (
                  rub_try_rebase_labels_in_tinstruction(single_else, -1),
                  rub_try_rebase_labels_in_texpr(then_body, -1),
                ) {
                (
                  Some({ kind: TInstrKind::TBr(label, values), .. }),
                  Some(next_then_body),
                ) if !rub_texpr_has_branch(then_body) &&
                  rub_can_turn_if_into_br_if(cond, values, options) => {
                  instrs[i] = TInstr::br_if(
                    label,
                    TInstr::unary(UnaryOp::i32_eqz(), cond),
                    values,
                  )
                  let next : Array[TInstr] = []
                  for j in 0..<instrs.length() {
                    next.push(instrs[j])
                    if j == i {
                      for item in next_then_body.instrs {
                        next.push(item)
                      }
                    }
                  }
                  instrs.clear()
                  for item in next {
                    instrs.push(item)
                  }
                  changed = true
                  i += next_then_body.instrs.length()
                  applied = true
                }
                _ => ()
              }
            None => ()
          }
        }
      }
      _ => ()
    }
    i += 1
  }
  changed
}

///|
fn rub_optimize_redundant_dropped_br_if_tail(instrs : Array[TInstr]) -> Bool {
  if instrs.length() < 2 {
    return false
  }
  let second_last_i = instrs.length() - 2
  let last_i = instrs.length() - 1
  match instrs[second_last_i].kind {
    TInstrKind::TDrop({ kind: TInstrKind::TBrIf(label, cond, [value]), .. }) =>
      if rub_is_label_zero(label) && value == instrs[last_i] {
        let value_effects = lcs_collect_effects(value)
        if value_effects.has_unremovable_side_effects() {
          return false
        }
        let cond_effects = lcs_collect_effects(cond)
        if cond_effects.invalidates(value_effects) {
          return false
        }
        instrs[second_last_i] = TInstr::drop(cond)
        true
      } else {
        false
      }
    _ => false
  }
}

///|
fn rub_optimize_entry_restructure_if(
  instrs : Array[TInstr],
  allow_list_splicing : Bool,
) -> Bool {
  if !allow_list_splicing {
    return false
  }
  if instrs.length() < 2 {
    return false
  }
  match instrs[0].kind {
    TInstrKind::TDrop({ kind: TInstrKind::TBrIf(label, cond, []), .. }) => {
      if !rub_is_label_zero(label) {
        return false
      }
      let tail : Array[TInstr] = []
      for i in 1..<instrs.length() {
        tail.push(instrs[i])
      }
      let tail_expr = TExpr::new(tail)
      if has_break_to_depth_in_texpr(tail_expr, 0) ||
        rub_texpr_has_branch(tail_expr) {
        return false
      }
      instrs.clear()
      instrs.push(
        TInstr::if_(
          BlockType::void_(),
          TInstr::unary(UnaryOp::i32_eqz(), cond),
          rub_rebase_labels_in_texpr(tail_expr, 1),
          None,
        ),
      )
      true
    }
    _ => false
  }
}

///|
fn rub_optimize_instr_list(
  instrs : Array[TInstr],
  options : OptimizeOptions,
  in_function_body : Bool,
  allow_list_splicing : Bool,
  zero_break_is_fallthrough : Bool,
) -> Bool {
  let mut changed = false
  if rub_remove_trailing_nops(instrs) {
    changed = true
  }
  if zero_break_is_fallthrough && rub_remove_trailing_flow_break(instrs) {
    changed = true
  }
  if in_function_body && rub_remove_trailing_return(instrs) {
    changed = true
  }
  if rub_optimize_if_else_block_tail(instrs, options, allow_list_splicing) {
    changed = true
  }
  if rub_optimize_adjacent_breaks(instrs, options) {
    changed = true
  }
  if zero_break_is_fallthrough &&
    rub_optimize_redundant_dropped_br_if_tail(instrs) {
    changed = true
  }
  if zero_break_is_fallthrough &&
    rub_optimize_entry_restructure_if(instrs, allow_list_splicing) {
    changed = true
  }
  if rub_remove_trailing_nops(instrs) {
    changed = true
  }
  if zero_break_is_fallthrough && rub_remove_trailing_flow_break(instrs) {
    changed = true
  }
  if in_function_body && rub_remove_trailing_return(instrs) {
    changed = true
  }
  changed
}

///|
fn rub_has_candidate_instr(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TNop
    | TInstrKind::TBr(_, _)
    | TInstrKind::TBrIf(_, _, _)
    | TInstrKind::TBrTable(_, _, _, _)
    | TInstrKind::TIf(_, _, _, _)
    | TInstrKind::TReturn(_)
    | TInstrKind::TDrop({ kind: TInstrKind::TBrIf(_, _, _), .. }) => true
    _ => false
  }
}

///|
fn rub_has_candidate_in_body(body : TExpr) -> Result[Bool, String] {
  let pass = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    if rub_has_candidate_instr(instr) {
      return Err(RUB_HAS_CANDIDATE_FOUND)
    }
    self.walk_tinstruction_default(false, instr)
  })
  match pass.walk_texpr(false, body) {
    Ok(_) => Ok(false)
    Err(e) => if e == RUB_HAS_CANDIDATE_FOUND { Ok(true) } else { Err(e) }
  }
}

///|
fn remove_unused_brs_pass(
  options : OptimizeOptions,
) -> ModuleTransformer[RUBWalkState] {
  ModuleTransformer::new()
  .on_func_evt(fn(self, state, func) {
    match func {
      TFunc(locals, body) => {
        let new_body = match
          self.walk_texpr(rub_walk_state(true, false, true), body) {
          Ok(Some((_, walked))) => walked
          Ok(None) => body
          Err(e) => return Err(e)
        }
        if new_body != body {
          change(state, Func::t_func(locals, new_body))
        } else {
          unchanged()
        }
      }
      _ => unchanged()
    }
  })
  .on_texpr_evt(fn(self, state, expr) {
    let out : Array[TInstr] = []
    let mut changed = false
    for instr in expr.instrs {
      let next_instr = match self.walk_tinstruction(state, instr) {
        Ok(Some((_, walked))) => walked
        Ok(None) => instr
        Err(e) => return Err(e)
      }
      if next_instr != instr {
        changed = true
      }
      out.push(next_instr)
    }
    if rub_optimize_instr_list(
        out,
        options,
        state.in_function_body,
        state.allow_list_splicing,
        state.zero_break_is_fallthrough,
      ) {
      changed = true
    }
    if changed {
      change(state, TExpr::new(out))
    } else {
      // We already walked children; return the original node to avoid a second default walk.
      change(state, expr)
    }
  })
  .on_tinstruction_evt(fn(self, state, instr) {
    let walked = match instr.kind {
      TInstrKind::TBlock(bt, body) => {
        let next_bt = match self.rub_walk_blocktype_result(state, bt) {
          Ok(next_bt) => next_bt
          Err(e) => return Err(e)
        }
        let next_body = match
          self.rub_walk_texpr_result(
            rub_walk_nested_texpr_state(next_bt, true),
            body,
          ) {
          Ok(next_body) => next_body
          Err(e) => return Err(e)
        }
        if next_bt == bt && next_body == body {
          instr
        } else {
          TInstr::block(next_bt, next_body)
        }
      }
      TInstrKind::TLoop(bt, body) => {
        let next_bt = match self.rub_walk_blocktype_result(state, bt) {
          Ok(next_bt) => next_bt
          Err(e) => return Err(e)
        }
        let next_body = match
          self.rub_walk_texpr_result(
            rub_walk_nested_texpr_state(next_bt, false),
            body,
          ) {
          Ok(next_body) => next_body
          Err(e) => return Err(e)
        }
        if next_bt == bt && next_body == body {
          instr
        } else {
          TInstr::loop_(next_bt, next_body)
        }
      }
      TInstrKind::TIf(bt, cond, then_body, else_body) => {
        let next_bt = match self.rub_walk_blocktype_result(state, bt) {
          Ok(next_bt) => next_bt
          Err(e) => return Err(e)
        }
        let next_cond = match self.rub_walk_tinstruction_result(state, cond) {
          Ok(next_cond) => next_cond
          Err(e) => return Err(e)
        }
        let branch_state = rub_walk_nested_texpr_state(next_bt, true)
        let next_then = match
          self.rub_walk_texpr_result(branch_state, then_body) {
          Ok(next_then) => next_then
          Err(e) => return Err(e)
        }
        let next_else = match else_body {
          Some(other) =>
            match self.rub_walk_texpr_result(branch_state, other) {
              Ok(next_other) => Some(next_other)
              Err(e) => return Err(e)
            }
          None => None
        }
        if next_bt == bt &&
          next_cond == cond &&
          next_then == then_body &&
          next_else == else_body {
          instr
        } else {
          TInstr::if_(next_bt, next_cond, next_then, next_else)
        }
      }
      TInstrKind::TTryTable(bt, catches, body) => {
        let next_bt = match self.rub_walk_blocktype_result(state, bt) {
          Ok(next_bt) => next_bt
          Err(e) => return Err(e)
        }
        let next_catches = match self.rub_walk_catches_result(state, catches) {
          Ok(next_catches) => next_catches
          Err(e) => return Err(e)
        }
        let next_body = match
          self.rub_walk_texpr_result(
            rub_walk_nested_texpr_state(next_bt, true),
            body,
          ) {
          Ok(next_body) => next_body
          Err(e) => return Err(e)
        }
        if next_bt == bt && next_catches == catches && next_body == body {
          instr
        } else {
          TInstr::try_table(next_bt, next_catches, next_body)
        }
      }
      _ =>
        match self.walk_tinstruction_default(state, instr) {
          Ok(Some((_, updated))) => updated
          Ok(None) => instr
          Err(e) => return Err(e)
        }
    }
    let (after_if, changed_if) = rub_optimize_if(walked, options)
    let (after_br_table, changed_switch) = rub_optimize_br_table(after_if)
    let (after_br_if, changed_br_if) = rub_optimize_br_if(after_br_table)
    if changed_if || changed_switch || changed_br_if || after_br_if != instr {
      change(state, after_br_if)
    } else {
      // Children were already traversed above; avoid default re-traversal.
      change(state, instr)
    }
  })
}

///|
fn rub_optimize_func_fixpoint(
  func : Func,
  options : OptimizeOptions,
) -> Result[Func, String] {
  match func {
    TFunc(_, body) =>
      match rub_has_candidate_in_body(body) {
        Ok(false) => Ok(func)
        Ok(true) => {
          let mut curr = func
          let mut rounds = 0
          while rounds < 16 {
            rounds += 1
            let pass = remove_unused_brs_pass(options)
            match pass.walk_func(rub_walk_state(false, false, true), curr) {
              Ok(Some((_, next_func))) => {
                if next_func == curr {
                  break
                }
                curr = next_func
              }
              Ok(None) => break
              Err(e) => return Err(e)
            }
          }
          Ok(curr)
        }
        Err(e) => Err(e)
      }
    _ => Ok(func)
  }
}

///|
fn remove_unused_brs(
  mod : Module,
  options? : OptimizeOptions = OptimizeOptions::new(),
) -> Result[Module, String] {
  let pass = ModuleTransformer::new().on_func_evt(fn(_, state, func) {
    match rub_optimize_func_fixpoint(func, options) {
      Ok(next_func) =>
        if next_func == func {
          unchanged()
        } else {
          change(state, next_func)
        }
      Err(e) => Err(e)
    }
  })
  match pass.walk_module(rub_walk_state(false, false, true), mod) {
    Ok(Some((_, out))) => Ok(out)
    Ok(None) => Ok(mod)
    Err(e) => Err(e)
  }
}

///|
fn rub_run(
  mod : Module,
  options? : OptimizeOptions = OptimizeOptions::new(),
) -> Module {
  match remove_unused_brs(mod, options~) {
    Ok(next_mod) => next_mod
    Err(e) => abort("remove_unused_brs failed: \{e}")
  }
}

///|
fn rub_single_func(mod : Module) -> Func {
  match mod.code_sec {
    Some(CodeSec([func])) => func
    _ => abort("expected exactly one function")
  }
}

///|
fn rub_single_typed_func_module(
  params : Array[ValType],
  results : Array[ValType],
  body : TExpr,
  locals? : Array[ValType] = [],
) -> Module {
  Module::new()
  .with_type_sec(
    TypeSec::new([
      single_rec_type(comp_type_sub_type(func_comp_type(params, results))),
    ]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  .with_code_sec(CodeSec::new([Func::t_func(locals, body)]))
}

///|
fn rub_single_void_func_module(
  params : Array[ValType],
  body : TExpr,
  locals? : Array[ValType] = [],
) -> Module {
  rub_single_typed_func_module(params, [], body, locals~)
}

///|
fn rub_assert_valid_module(mod : Module) -> Unit {
  match validate_module(mod) {
    Ok(_) => ()
    Err(e) => abort("expected module to validate: \{e}")
  }
}

///|
test "remove_unused_brs removes trailing br 0 in block" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([TInstr::i32_const(I32(1)), TInstr::br(LabelIdx::new(0), [])]),
    ),
  ])
  let mod = rub_single_void_func_module([], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              { instrs: [{ kind: TInstrKind::TI32Const(I32(1)), .. }], .. }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected trailing br 0 to be removed")
  }
}

///|
test "remove_unused_brs keeps trailing br 0 in loop bodies" {
  let body = TExpr::new([
    TInstr::loop_(
      BlockType::void_(),
      TExpr::new([TInstr::br(LabelIdx::new(0), [])]),
    ),
  ])
  let mod = rub_single_void_func_module([], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TLoop(
              _,
              { instrs: [{ kind: TInstrKind::TBr(label, []), .. }], .. }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => assert_eq(label, LabelIdx::new(0))
    _ => fail("expected loop-tail br 0 to remain intact")
  }
}

///|
test "remove_unused_brs forwards trailing br value in block" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::val_type(ValType::i32()),
      TExpr::new([TInstr::br(LabelIdx::new(0), [TInstr::i32_const(I32(7))])]),
    ),
  ])
  let mod = rub_single_typed_func_module([], [ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              { instrs: [{ kind: TInstrKind::TI32Const(I32(7)), .. }], .. }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected trailing br value to be forwarded")
  }
}

///|
test "remove_unused_brs trims trailing nops from block body" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([TInstr::i32_const(I32(1)), TInstr::nop(), TInstr::nop()]),
    ),
  ])
  let mod = rub_single_void_func_module([], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              { instrs: [{ kind: TInstrKind::TI32Const(I32(1)), .. }], .. }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected trailing nops to be trimmed")
  }
}

///|
test "remove_unused_brs turns one-armed if with break into br_if" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::if_(
          BlockType::void_(),
          TInstr::local_get(LocalIdx::new(0)),
          TExpr::new([TInstr::br(LabelIdx::new(1), [])]),
          None,
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TBrIf(
                      label,
                      { kind: TInstrKind::TLocalGet(_), .. },
                      []
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => assert_eq(label, LabelIdx::new(0))
    _ => fail("expected if( cond ) br to become br_if")
  }
}

///|
test "remove_unused_brs rejects one-armed if rewrite when break targets removed if scope" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::if_(
          BlockType::void_(),
          TInstr::local_get(LocalIdx::new(0)),
          TExpr::new([TInstr::br(LabelIdx::new(0), [])]),
          None,
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              { instrs: [{ kind: TInstrKind::TIf(_, _, _, None), .. }], .. }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected br 0 in one-armed if to remain structured")
  }
}

///|
test "remove_unused_brs combines nested one-armed if conditions" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::if_(
          BlockType::void_(),
          TInstr::local_get(LocalIdx::new(0)),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(1)),
              TExpr::new([TInstr::br(LabelIdx::new(1), [])]),
              None,
            ),
          ]),
          None,
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32(), ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TIf(
                      _,
                      { kind: TInstrKind::TLocalGet(_), .. },
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TBrIf(
                              label,
                              { kind: TInstrKind::TLocalGet(_), .. },
                              []
                            ),
                            ..,
                          },
                        ],
                        ..,
                      },
                      None
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => assert_eq(label, LabelIdx::new(0))
    _ =>
      fail(
        "expected nested one-armed if to keep a valid rebased inner br_if when the outer-scope branch cannot be hoisted",
      )
  }
}

///|
test "remove_unused_brs rebases nested if body branches when hoisting" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::if_(
          BlockType::void_(),
          TInstr::local_get(LocalIdx::new(0)),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(1)),
              TExpr::new([TInstr::br(LabelIdx::new(2), [])]),
              None,
            ),
          ]),
          None,
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32(), ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TBrIf(
                      label,
                      {
                        kind: TInstrKind::TSelect(
                          _,
                          { kind: TInstrKind::TLocalGet(_), .. },
                          { kind: TInstrKind::TLocalGet(_), .. },
                          { kind: TInstrKind::TI32Const(I32(0)), .. }
                        ),
                        ..,
                      },
                      []
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => assert_eq(label, LabelIdx::new(0))
    _ => fail("expected nested-if hoist to rebase the inner branch target")
  }
}

///|
test "remove_unused_brs trims trailing br_table defaults and simplifies" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::br_table(
          [LabelIdx::new(0), LabelIdx::new(1), LabelIdx::new(1)],
          LabelIdx::new(1),
          TInstr::local_get(LocalIdx::new(0)),
          [],
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TIf(
                      _,
                      { kind: TInstrKind::TLocalGet(_), .. },
                      {
                        instrs: [{ kind: TInstrKind::TBr(then_label, []), .. }],
                        ..,
                      },
                      Some(
                        {
                          instrs: [
                            { kind: TInstrKind::TBr(else_label, []), .. },
                          ],
                          ..,
                        }
                      )
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => {
      assert_eq(then_label, LabelIdx::new(2))
      assert_eq(else_label, LabelIdx::new(1))
    }
    _ =>
      fail(
        "expected trailing-default br_table to simplify to rebased if branches",
      )
  }
}

///|
test "remove_unused_brs rebases default-only br_table wrapper labels" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([
            TInstr::br_table(
              [],
              LabelIdx::new(1),
              TInstr::local_get(LocalIdx::new(0)),
              [],
            ),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TBlock(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TBlock(
                              _,
                              {
                                instrs: [
                                  { kind: TInstrKind::TDrop(_), .. },
                                  { kind: TInstrKind::TBr(label, []), .. },
                                ],
                                ..,
                              }
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => assert_eq(label, LabelIdx::new(2))
    _ =>
      fail(
        "expected default-only br_table wrapper to rebase outer branch depth",
      )
  }
}

///|
test "remove_unused_brs rewrites default-only br_table to drop+br" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::br_table(
          [],
          LabelIdx::new(0),
          TInstr::local_get(LocalIdx::new(0)),
          [],
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  { kind: TInstrKind::TBlock(_, { instrs: items, .. }), .. },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) =>
      match items {
        [{ kind: TInstrKind::TDrop(_), .. }]
        | [
          { kind: TInstrKind::TDrop(_), .. },
          { kind: TInstrKind::TBr(_, _), .. },
        ] => ()
        _ =>
          fail(
            "expected default-only br_table to rewrite to drop(cond) with optional br",
          )
      }
    _ =>
      fail(
        "expected default-only br_table to rewrite to nested block(drop(cond), br?)",
      )
  }
}

///|
test "remove_unused_brs rebases single-target br_table branch labels" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([
            TInstr::br_table(
              [LabelIdx::new(1)],
              LabelIdx::new(0),
              TInstr::local_get(LocalIdx::new(0)),
              [],
            ),
          ]),
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TBlock(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TIf(
                              _,
                              _,
                              {
                                instrs: [
                                  { kind: TInstrKind::TBr(then_label, []), .. },
                                ],
                                ..,
                              },
                              Some(
                                {
                                  instrs: [
                                    {
                                      kind: TInstrKind::TBr(else_label, []),
                                      ..,
                                    },
                                  ],
                                  ..,
                                }
                              )
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => {
      assert_eq(then_label, LabelIdx::new(1))
      assert_eq(else_label, LabelIdx::new(2))
    }
    _ =>
      fail(
        "expected single-target br_table rewrite to rebase both branch labels",
      )
  }
}

///|
test "remove_unused_brs rewrites single-target br_table to if+brs" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::br_table(
          [LabelIdx::new(0)],
          LabelIdx::new(0),
          TInstr::local_get(LocalIdx::new(0)),
          [],
        ),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      {
        instrs: [{ kind: TInstrKind::TBlock(_, { instrs: items, .. }), .. }],
        ..,
      }
    ) =>
      match items {
        [{ kind: TInstrKind::TIf(_, _, _, _), .. }]
        | [{ kind: TInstrKind::TDrop(_), .. }]
        | [{ kind: TInstrKind::TBlock(_, _), .. }] => ()
        _ => fail("expected single-target br_table to be simplified")
      }
    _ => fail("expected single-target br_table to become if")
  }
}

///|
test "remove_unused_brs merges br_if followed by br to same target" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::br_if(LabelIdx::new(0), TInstr::local_get(LocalIdx::new(0)), []),
        TInstr::br(LabelIdx::new(0), []),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TBrIf(
                      label,
                      { kind: TInstrKind::TLocalGet(_), .. },
                      []
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => assert_eq(label, LabelIdx::new(0))
    _ =>
      fail("expected br_if + br to same target to simplify to a single br_if")
  }
}

///|
test "remove_unused_brs merges adjacent br_ifs in shrink mode" {
  let body = TExpr::new([
    TInstr::br_if(LabelIdx::new(0), TInstr::local_get(LocalIdx::new(0)), []),
    TInstr::br_if(LabelIdx::new(0), TInstr::local_get(LocalIdx::new(1)), []),
  ])
  let mod = rub_single_void_func_module([ValType::i32(), ValType::i32()], body)
  let out = rub_run(mod, options=OptimizeOptions::new(shrink_level=1))
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBrIf(
              _,
              { kind: TInstrKind::TBinary(I32OrOp, _, _), .. },
              []
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected adjacent br_ifs to merge in shrink mode")
  }
}

///|
test "remove_unused_brs folds br_if with constant true condition" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::br_if(LabelIdx::new(0), rub_one_i32(), []),
        TInstr::i32_const(I32(2)),
      ]),
    ),
  ])
  let mod = rub_single_void_func_module([], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  { kind: TInstrKind::TBr(label, []), .. },
                  { kind: TInstrKind::TI32Const(I32(2)), .. },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => assert_eq(label, LabelIdx::new(0))
    _ => fail("expected br_if true to become br")
  }
}

///|
test "remove_unused_brs folds br_if with constant false condition" {
  let body = TExpr::new([TInstr::br_if(LabelIdx::new(0), rub_zero_i32(), [])])
  let mod = rub_single_void_func_module([], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TDrop({ kind: TInstrKind::TI32Const(I32(0)), .. }),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected br_if false to become drop(condition)")
  }
}

///|
test "remove_unused_brs folds br_if false with value into drops" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::br_if(LabelIdx::new(0), rub_zero_i32(), [
          TInstr::i32_const(I32(7)),
        ]),
      ]),
    ),
  ])
  let mod = rub_single_typed_func_module([], [], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TBlock(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TDrop(
                              { kind: TInstrKind::TI32Const(I32(7)), .. }
                            ),
                            ..,
                          },
                          {
                            kind: TInstrKind::TDrop(
                              { kind: TInstrKind::TI32Const(I32(0)), .. }
                            ),
                            ..,
                          },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected br_if(false, value) to become drops in a void block")
  }
}

///|
test "remove_unused_brs rebases branch labels inside folded br_if false values" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::val_type(ValType::i32()),
      TExpr::new([
        TInstr::br_if(LabelIdx::new(0), rub_zero_i32(), [
          TInstr::block(
            BlockType::val_type(ValType::i32()),
            TExpr::new([
              TInstr::br(LabelIdx::new(1), [TInstr::i32_const(I32(7))]),
            ]),
          ),
        ]),
        TInstr::i32_const(I32(5)),
      ]),
    ),
  ])
  let mod = rub_single_typed_func_module([], [ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              ValTypeBlockType(_),
              {
                instrs: [
                  {
                    kind: TInstrKind::TBlock(
                      _,
                      {
                        instrs: [
                          {
                            kind: TInstrKind::TDrop(
                              {
                                kind: TInstrKind::TBlock(
                                  _,
                                  {
                                    instrs: [
                                      {
                                        kind: TInstrKind::TBr(
                                          label,
                                          [
                                            {
                                              kind: TInstrKind::TI32Const(
                                                I32(7)
                                              ),
                                              ..,
                                            },
                                          ]
                                        ),
                                        ..,
                                      },
                                    ],
                                    ..,
                                  }
                                ),
                                ..,
                              }
                            ),
                            ..,
                          },
                          { kind: TInstrKind::TDrop(_), .. },
                        ],
                        ..,
                      }
                    ),
                    ..,
                  },
                  { kind: TInstrKind::TI32Const(I32(5)), .. },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => assert_eq(label, LabelIdx::new(2))
    _ =>
      fail(
        "expected folded br_if(false, [value]) wrapper to rebase labels inside the value subtree",
      )
  }
}

///|
test "remove_unused_brs removes redundant dropped br_if tail value copy" {
  let value = TInstr::i32_const(I32(9))
  let body = TExpr::new([
    TInstr::block(
      BlockType::val_type(ValType::i32()),
      TExpr::new([
        TInstr::drop(
          TInstr::br_if(LabelIdx::new(0), TInstr::local_get(LocalIdx::new(0)), [
            value,
          ]),
        ),
        value,
      ]),
    ),
  ])
  let mod = rub_single_typed_func_module(
    [ValType::i32()],
    [ValType::i32()],
    body,
  )
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TDrop(
                      { kind: TInstrKind::TLocalGet(_), .. }
                    ),
                    ..,
                  },
                  { kind: TInstrKind::TI32Const(I32(9)), .. },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected dropped br_if tail-value pattern to be optimized")
  }
}

///|
test "remove_unused_brs keeps redundant dropped br_if tail pattern in loops" {
  let value = TInstr::i32_const(I32(9))
  let body = TExpr::new([
    TInstr::loop_(
      BlockType::val_type(ValType::i32()),
      TExpr::new([
        TInstr::drop(
          TInstr::br_if(LabelIdx::new(0), TInstr::local_get(LocalIdx::new(0)), [
            value,
          ]),
        ),
        value,
      ]),
    ),
  ])
  let mod = rub_single_typed_func_module(
    [ValType::i32()],
    [ValType::i32()],
    body,
  )
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TLoop(
              _,
              {
                instrs: [
                  {
                    kind: TInstrKind::TDrop(
                      { kind: TInstrKind::TBrIf(label, _, [_]), .. }
                    ),
                    ..,
                  },
                  { kind: TInstrKind::TI32Const(I32(9)), .. },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => assert_eq(label, LabelIdx::new(0))
    _ => fail("expected loop-tail dropped br_if pattern to remain structured")
  }
}

///|
test "remove_unused_brs removes trailing return with no value in function body" {
  let body = TExpr::new([
    TInstr::drop(TInstr::i32_const(I32(1))),
    TInstr::return_([]),
  ])
  let mod = rub_single_void_func_module([], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TDrop({ kind: TInstrKind::TI32Const(I32(1)), .. }),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected trailing return to be removed")
  }
}

///|
test "remove_unused_brs forwards trailing return value in function body" {
  let body = TExpr::new([TInstr::return_([TInstr::i32_const(I32(77))])])
  let mod = rub_single_typed_func_module([], [ValType::i32()], body)
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(_, { instrs: [{ kind: TInstrKind::TI32Const(I32(77)), .. }], .. }) =>
      ()
    _ => fail("expected trailing return value to be forwarded")
  }
}

///|
test "remove_unused_brs is idempotent" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::if_(
          BlockType::void_(),
          TInstr::local_get(LocalIdx::new(0)),
          TExpr::new([TInstr::br(LabelIdx::new(1), [])]),
          None,
        ),
        TInstr::nop(),
      ]),
    ),
  ])
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([ValType::i32()], body)]),
  )
  let once = rub_run(mod)
  let twice = rub_run(once)
  assert_eq(once, twice)
}

///|
test "remove_unused_brs does not splice value-typed if with else br" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::val_type(ValType::i32()),
      TExpr::new([
        TInstr::if_(
          BlockType::val_type(ValType::i32()),
          TInstr::local_get(LocalIdx::new(0)),
          TExpr::new([TInstr::i32_const(I32(1))]),
          Some(
            TExpr::new([
              TInstr::br(LabelIdx::new(0), [TInstr::i32_const(I32(2))]),
            ]),
          ),
        ),
      ]),
    ),
  ])
  let mod = rub_single_typed_func_module(
    [ValType::i32()],
    [ValType::i32()],
    body,
  )
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              ValTypeBlockType(_),
              {
                instrs: [
                  {
                    kind: TInstrKind::TIf(ValTypeBlockType(_), _, _, Some(_)),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected value-typed if with else br to remain structured")
  }
}

///|
test "remove_unused_brs does not splice void if in value-typed block body" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::val_type(ValType::i32()),
      TExpr::new([
        TInstr::if_(
          BlockType::void_(),
          TInstr::local_get(LocalIdx::new(0)),
          TExpr::new([TInstr::nop()]),
          Some(
            TExpr::new([
              TInstr::br(LabelIdx::new(0), [TInstr::i32_const(I32(2))]),
            ]),
          ),
        ),
        TInstr::i32_const(I32(1)),
      ]),
    ),
  ])
  let mod = rub_single_typed_func_module(
    [ValType::i32()],
    [ValType::i32()],
    body,
  )
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              ValTypeBlockType(_),
              {
                instrs: [
                  { kind: TInstrKind::TIf(VoidBlockType, _, _, Some(_)), .. },
                  { kind: TInstrKind::TI32Const(I32(1)), .. },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected void if in value-typed block body to remain structured")
  }
}

///|
test "remove_unused_brs does not splice value-typed if with then br" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::val_type(ValType::i32()),
      TExpr::new([
        TInstr::if_(
          BlockType::val_type(ValType::i32()),
          TInstr::local_get(LocalIdx::new(0)),
          TExpr::new([TInstr::br(LabelIdx::new(0), [TInstr::i32_const(I32(1))])]),
          Some(TExpr::new([TInstr::i32_const(I32(2))])),
        ),
      ]),
    ),
  ])
  let mod = rub_single_typed_func_module(
    [ValType::i32()],
    [ValType::i32()],
    body,
  )
  let out = rub_run(mod)
  rub_assert_valid_module(out)
  match rub_single_func(out) {
    TFunc(
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              ValTypeBlockType(_),
              {
                instrs: [
                  {
                    kind: TInstrKind::TIf(ValTypeBlockType(_), _, _, Some(_)),
                    ..,
                  },
                ],
                ..,
              }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected value-typed if with then br to remain structured")
  }
}

///|
test "remove_unused_brs is idempotent for value-typed if with else br" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::val_type(ValType::i32()),
      TExpr::new([
        TInstr::if_(
          BlockType::val_type(ValType::i32()),
          TInstr::local_get(LocalIdx::new(0)),
          TExpr::new([TInstr::i32_const(I32(1))]),
          Some(
            TExpr::new([
              TInstr::br(LabelIdx::new(0), [TInstr::i32_const(I32(2))]),
            ]),
          ),
        ),
      ]),
    ),
  ])
  let mod = rub_single_typed_func_module(
    [ValType::i32()],
    [ValType::i32()],
    body,
  )
  let once = rub_run(mod)
  let twice = rub_run(once)
  rub_assert_valid_module(twice)
  assert_eq(once, twice)
}
