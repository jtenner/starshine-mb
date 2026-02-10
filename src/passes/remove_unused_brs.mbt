///|
const RUB_TOO_COSTLY_TO_RUN_UNCONDITIONALLY : Int = 8

///|
fn rub_label_to_int(label : LabelIdx) -> Int {
  let LabelIdx(raw) = label
  raw.reinterpret_as_int()
}

///|
fn rub_is_label_zero(label : LabelIdx) -> Bool {
  rub_label_to_int(label) == 0
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
  match instr {
    TI32Const(I32(v)) => Some(v)
    _ => None
  }
}

///|
fn rub_has_side_effects(instr : TInstr) -> Bool {
  lcs_collect_effects(instr).has_unremovable_side_effects()
}

///|
fn rub_is_single_tinstr(expr : TExpr) -> TInstr? {
  match expr.0 {
    [single] => Some(single)
    _ => None
  }
}

///|
fn rub_instr_has_branch(instr : TInstr) -> Bool {
  match instr {
    TBr(_, _)
    | TBrIf(_, _, _)
    | TBrTable(_, _, _, _)
    | TBrOnNull(_, _, _)
    | TBrOnNonNull(_, _, _)
    | TBrOnCast(_, _, _, _, _, _)
    | TBrOnCastFail(_, _, _, _, _, _)
    | TReturn(_)
    | TReturnCall(_, _)
    | TReturnCallIndirect(_, _, _, _)
    | TReturnCallRef(_, _, _)
    | TThrow(_, _)
    | TThrowRef(_) => true
    TBlock(_, body) | TLoop(_, body) | TTryTable(_, _, body) =>
      rub_texpr_has_branch(body)
    TIf(_, cond, then_body, else_body) => {
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
  for instr in expr.0 {
    if rub_instr_has_branch(instr) {
      return true
    }
  }
  false
}

///|
fn rub_instr_cost(instr : TInstr) -> Int {
  match instr {
    TI32Const(_)
    | TI64Const(_)
    | TF32Const(_)
    | TF64Const(_)
    | TRefNull(_)
    | TRefFunc(_)
    | TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | TLocalGet(_)
    | TNop => 0
    TThrow(_, _) | TThrowRef(_) => RUB_TOO_COSTLY_TO_RUN_UNCONDITIONALLY
    TRefCast(_, _, _) => RUB_TOO_COSTLY_TO_RUN_UNCONDITIONALLY / 2 + 1
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
fn rub_can_turn_if_into_br_if(
  if_condition : TInstr,
  br_value : TInstr?,
) -> Bool {
  if is_unreachable_instr(if_condition) {
    return false
  }
  match br_value {
    Some(v) => {
      let value_effects = lcs_collect_effects(v)
      if value_effects.has_unremovable_side_effects() {
        return false
      }
      !lcs_collect_effects(if_condition).invalidates(value_effects)
    }
    None => true
  }
}

///|
fn rub_fold_condition_to_bool(instr : TInstr) -> Bool? {
  match rub_is_const_i32(instr) {
    Some(v) => Some(v != 0)
    None =>
      match instr {
        TUnary(I32EqzOp, inner) =>
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
  TInstr::block(
    BlockType::void_(),
    TExpr::new([TInstr::drop(cond), TInstr::br(default_, [])]),
  )
}

///|
fn rub_single_target_switch(
  target : LabelIdx,
  default_ : LabelIdx,
  cond : TInstr,
) -> TInstr {
  TInstr::if_(
    BlockType::void_(),
    cond,
    TExpr::new([TInstr::br(default_, [])]),
    Some(TExpr::new([TInstr::br(target, [])])),
  )
}

///|
fn rub_optimize_br_table(instr : TInstr) -> (TInstr, Bool) {
  match instr {
    TBrTable(targets, default_, cond, values) => {
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
  match instr {
    TIf(bt, condition, then_body, else_body) =>
      match else_body {
        Some(_) => (instr, false)
        None =>
          match rub_is_single_tinstr(then_body) {
            Some(TBr(label, values)) => {
              let br_value = if values.length() == 1 {
                Some(values[0])
              } else {
                None
              }
              if rub_can_turn_if_into_br_if(condition, br_value) {
                (TInstr::br_if(label, condition, values), true)
              } else {
                (instr, false)
              }
            }
            Some(TBrIf(label, inner_cond, values)) => {
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
            Some(TIf(_, child_cond, child_then, None)) => {
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
            _ => (instr, false)
          }
      }
    _ => (instr, false)
  }
}

///|
fn rub_optimize_br_if(instr : TInstr) -> (TInstr, Bool) {
  match instr {
    TBrIf(label, cond, values) =>
      match rub_fold_condition_to_bool(cond) {
        Some(true) => (TInstr::br(label, values), true)
        Some(false) =>
          if values.length() == 0 {
            (TInstr::drop(cond), true)
          } else if values.length() == 1 {
            (
              TInstr::block(
                BlockType::void_(),
                TExpr::new([TInstr::drop(values[0]), TInstr::drop(cond)]),
              ),
              true,
            )
          } else {
            (instr, false)
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
    match instrs[instrs.length() - 1] {
      TNop => {
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
  match instrs[idx] {
    TBr(label, values) => {
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
  match instrs[idx] {
    TReturn(values) =>
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
    match instrs[i] {
      TBrIf(label1, cond1, values1) =>
        if values1.length() == 0 {
          match instrs[i + 1] {
            TBr(label2, values2) =>
              if label1 == label2 && values2.length() == 0 {
                instrs[i] = TInstr::drop(cond1)
                changed = true
              }
            TBrIf(label2, cond2, values2) =>
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
fn rub_optimize_if_else_block_tail(instrs : Array[TInstr]) -> Bool {
  let mut changed = false
  let mut i = 0
  while i < instrs.length() {
    match instrs[i] {
      TIf(_, cond, then_body, Some(else_body)) => {
        let mut applied = false
        match rub_is_single_tinstr(then_body) {
          Some(TBr(label, values)) =>
            if !rub_texpr_has_branch(else_body) &&
              rub_can_turn_if_into_br_if(
                cond,
                if values.length() == 1 {
                  Some(values[0])
                } else {
                  None
                },
              ) {
              instrs[i] = TInstr::br_if(label, cond, values)
              let next : Array[TInstr] = []
              for j in 0..<instrs.length() {
                next.push(instrs[j])
                if j == i {
                  for item in else_body.0 {
                    next.push(item)
                  }
                }
              }
              instrs.clear()
              for item in next {
                instrs.push(item)
              }
              changed = true
              i += else_body.0.length()
              applied = true
            }
          _ => ()
        }
        if !applied {
          match rub_is_single_tinstr(else_body) {
            Some(TBr(label, values)) =>
              if !rub_texpr_has_branch(then_body) &&
                rub_can_turn_if_into_br_if(
                  cond,
                  if values.length() == 1 {
                    Some(values[0])
                  } else {
                    None
                  },
                ) {
                instrs[i] = TInstr::br_if(
                  label,
                  TInstr::unary(UnaryOp::i32_eqz(), cond),
                  values,
                )
                let next : Array[TInstr] = []
                for j in 0..<instrs.length() {
                  next.push(instrs[j])
                  if j == i {
                    for item in then_body.0 {
                      next.push(item)
                    }
                  }
                }
                instrs.clear()
                for item in next {
                  instrs.push(item)
                }
                changed = true
                i += then_body.0.length()
                applied = true
              }
            _ => ()
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
  match instrs[second_last_i] {
    TDrop(TBrIf(label, cond, [value])) =>
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
fn rub_optimize_entry_restructure_if(instrs : Array[TInstr]) -> Bool {
  if instrs.length() < 2 {
    return false
  }
  match instrs[0] {
    TDrop(TBrIf(label, cond, [])) => {
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
          tail_expr,
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
) -> Bool {
  let mut changed = false
  if rub_remove_trailing_nops(instrs) {
    changed = true
  }
  if rub_remove_trailing_flow_break(instrs) {
    changed = true
  }
  if in_function_body && rub_remove_trailing_return(instrs) {
    changed = true
  }
  if rub_optimize_if_else_block_tail(instrs) {
    changed = true
  }
  if rub_optimize_adjacent_breaks(instrs, options) {
    changed = true
  }
  if rub_optimize_redundant_dropped_br_if_tail(instrs) {
    changed = true
  }
  if rub_optimize_entry_restructure_if(instrs) {
    changed = true
  }
  if rub_remove_trailing_nops(instrs) {
    changed = true
  }
  if rub_remove_trailing_flow_break(instrs) {
    changed = true
  }
  if in_function_body && rub_remove_trailing_return(instrs) {
    changed = true
  }
  changed
}

///|
fn remove_unused_brs_pass(options : OptimizeOptions) -> ModuleTransformer[Bool] {
  ModuleTransformer::new()
  .on_func_evt(fn(self, _, func) {
    match func {
      TFunc(locals, body) => {
        let new_body = match self.walk_texpr(true, body) {
          Ok(Some((_, walked))) => walked
          Ok(None) => body
          Err(e) => return Err(e)
        }
        if new_body != body {
          change(false, Func::t_func(locals, new_body))
        } else {
          unchanged()
        }
      }
      _ => unchanged()
    }
  })
  .on_texpr_evt(fn(self, in_function_body, expr) {
    let out : Array[TInstr] = []
    let mut changed = false
    for instr in expr.0 {
      let next_instr = match self.walk_tinstruction(false, instr) {
        Ok(Some((_, walked))) => walked
        Ok(None) => instr
        Err(e) => return Err(e)
      }
      if next_instr != instr {
        changed = true
      }
      out.push(next_instr)
    }
    if rub_optimize_instr_list(out, options, in_function_body) {
      changed = true
    }
    if changed {
      change(in_function_body, TExpr::new(out))
    } else {
      unchanged()
    }
  })
  .on_tinstruction_evt(fn(self, _, instr) {
    let walked = match self.walk_tinstruction_default(false, instr) {
      Ok(Some((_, updated))) => updated
      Ok(None) => instr
      Err(e) => return Err(e)
    }
    let (after_if, changed_if) = rub_optimize_if(walked, options)
    let (after_br_table, changed_switch) = rub_optimize_br_table(after_if)
    let (after_br_if, changed_br_if) = rub_optimize_br_if(after_br_table)
    if changed_if || changed_switch || changed_br_if || after_br_if != instr {
      change(false, after_br_if)
    } else {
      unchanged()
    }
  })
}

///|
pub fn remove_unused_brs(
  mod : Module,
  options? : OptimizeOptions = OptimizeOptions::new(),
) -> Result[Module, String] {
  let mut curr = mod
  let mut rounds = 0
  while rounds < 16 {
    rounds += 1
    let pass = remove_unused_brs_pass(options)
    match pass.walk_module(false, curr) {
      Ok(Some((_, next_mod))) => {
        if next_mod == curr {
          break
        }
        curr = next_mod
      }
      Ok(None) => break
      Err(e) => return Err(e)
    }
  }
  Ok(curr)
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
test "remove_unused_brs removes trailing br 0 in block" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([TInstr::i32_const(I32(1)), TInstr::br(LabelIdx::new(0), [])]),
    ),
  ])
  let mod = Module::new().with_code_sec(CodeSec::new([Func::t_func([], body)]))
  let out = rub_run(mod)
  match rub_single_func(out) {
    TFunc(_, TExpr([TBlock(_, TExpr([TI32Const(I32(1))]))])) => ()
    _ => fail("expected trailing br 0 to be removed")
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
  let mod = Module::new().with_code_sec(CodeSec::new([Func::t_func([], body)]))
  let out = rub_run(mod)
  match rub_single_func(out) {
    TFunc(_, TExpr([TBlock(_, TExpr([TI32Const(I32(7))]))])) => ()
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
  let mod = Module::new().with_code_sec(CodeSec::new([Func::t_func([], body)]))
  let out = rub_run(mod)
  match rub_single_func(out) {
    TFunc(_, TExpr([TBlock(_, TExpr([TI32Const(I32(1))]))])) => ()
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
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([ValType::i32()], body)]),
  )
  let out = rub_run(mod)
  match rub_single_func(out) {
    TFunc(_, TExpr([TBlock(_, TExpr([TBrIf(label, TLocalGet(_), [])]))])) =>
      assert_eq(label, LabelIdx::new(1))
    _ => fail("expected if( cond ) br to become br_if")
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
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([ValType::i32(), ValType::i32()], body)]),
  )
  let out = rub_run(mod)
  match rub_single_func(out) {
    TFunc(
      _,
      TExpr(
        [
          TBlock(
            _,
            TExpr(
              [
                TBrIf(
                  _,
                  TSelect(_, TLocalGet(_), TLocalGet(_), TI32Const(I32(0))),
                  []
                ),
              ]
            )
          ),
        ]
      )
    ) => ()
    _ =>
      fail(
        "expected nested one-armed if to fold into select-based br_if condition",
      )
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
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([ValType::i32()], body)]),
  )
  let out = rub_run(mod)
  match rub_single_func(out) {
    TFunc(_, TExpr([TBlock(_, TExpr([TBrIf(label, TLocalGet(_), [])]))])) =>
      assert_eq(label, LabelIdx::new(1))
    _ => fail("expected trailing-default br_table to simplify to br_if")
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
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([ValType::i32()], body)]),
  )
  let out = rub_run(mod)
  match rub_single_func(out) {
    TFunc(_, TExpr([TBlock(_, TExpr([TBlock(_, TExpr(items))]))])) =>
      match items {
        [TDrop(_)] | [TDrop(_), TBr(_, _)] => ()
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
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([ValType::i32()], body)]),
  )
  let out = rub_run(mod)
  match rub_single_func(out) {
    TFunc(_, TExpr([TBlock(_, TExpr(items))])) =>
      match items {
        [TIf(_, _, _, _)] | [TDrop(_)] | [TBlock(_, _)] => ()
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
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([ValType::i32()], body)]),
  )
  let out = rub_run(mod)
  match rub_single_func(out) {
    TFunc(_, TExpr([TBlock(_, TExpr([TBrIf(label, TLocalGet(_), [])]))])) =>
      assert_eq(label, LabelIdx::new(0))
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
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([ValType::i32(), ValType::i32()], body)]),
  )
  let out = rub_run(mod, options=OptimizeOptions::new(shrink_level=1))
  match rub_single_func(out) {
    TFunc(_, TExpr([TBrIf(_, TBinary(I32OrOp, _, _), [])])) => ()
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
  let mod = Module::new().with_code_sec(CodeSec::new([Func::t_func([], body)]))
  let out = rub_run(mod)
  match rub_single_func(out) {
    TFunc(_, TExpr([TBlock(_, TExpr([TBr(label, []), TI32Const(I32(2))]))])) =>
      assert_eq(label, LabelIdx::new(0))
    _ => fail("expected br_if true to become br")
  }
}

///|
test "remove_unused_brs folds br_if with constant false condition" {
  let body = TExpr::new([TInstr::br_if(LabelIdx::new(0), rub_zero_i32(), [])])
  let mod = Module::new().with_code_sec(CodeSec::new([Func::t_func([], body)]))
  let out = rub_run(mod)
  match rub_single_func(out) {
    TFunc(_, TExpr([TDrop(TI32Const(I32(0)))])) => ()
    _ => fail("expected br_if false to become drop(condition)")
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
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([ValType::i32()], body)]),
  )
  let out = rub_run(mod)
  match rub_single_func(out) {
    TFunc(
      _,
      TExpr([TBlock(_, TExpr([TDrop(TLocalGet(_)), TI32Const(I32(9))]))])
    ) => ()
    _ => fail("expected dropped br_if tail-value pattern to be optimized")
  }
}

///|
test "remove_unused_brs removes trailing return with no value in function body" {
  let body = TExpr::new([TInstr::i32_const(I32(1)), TInstr::return_([])])
  let mod = Module::new().with_code_sec(CodeSec::new([Func::t_func([], body)]))
  let out = rub_run(mod)
  match rub_single_func(out) {
    TFunc(_, TExpr([TI32Const(I32(1))])) => ()
    _ => fail("expected trailing return to be removed")
  }
}

///|
test "remove_unused_brs forwards trailing return value in function body" {
  let body = TExpr::new([TInstr::return_([TInstr::i32_const(I32(77))])])
  let mod = Module::new().with_code_sec(CodeSec::new([Func::t_func([], body)]))
  let out = rub_run(mod)
  match rub_single_func(out) {
    TFunc(_, TExpr([TI32Const(I32(77))])) => ()
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
