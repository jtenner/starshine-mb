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
priv struct FLBreakTempKey {
  label_uid : Int
  val_type : ValType
} derive(Eq, Hash)

///|
const FL_TRACE_PROGRESS_INTERVAL : Int = 2048

///|
const FL_TRACE_PROGRESS_INTERVAL_MS : UInt64 = 250UL

///|
const FL_UNSUPPORTED_BRANCH_SCAN_PROGRESS_INTERVAL : Int = 1024

///|
const FL_UNSUPPORTED_BRANCH_SCAN_PROGRESS_INTERVAL_MS : UInt64 = 250UL

///|
const FL_REWRITE_LABEL_FLOW_PROGRESS_INTERVAL : Int = 1024

///|
const FL_REWRITE_LABEL_FLOW_PROGRESS_INTERVAL_MS : UInt64 = 250UL

///|
fn fl_trace_noop(_ : String) -> Unit {
  ()
}

///|
fn fl_trace_should_log_func(ordinal : Int, trace_all_funcs : Bool) -> Bool {
  trace_all_funcs || ordinal <= 5 || ordinal % 250 == 0
}

///|
fn fl_trace_now_ms() -> UInt64 {
  pass_trace_now_ms()
}

///|
fn fl_trace_elapsed_ms(start_ms : UInt64) -> UInt64 {
  pass_trace_elapsed_ms(start_ms)
}

///|
priv struct FLFuncTraceState {
  trace : (String) -> Unit
  log_func : Bool
  ordinal : Int
  func_start_ms : UInt64
  last_progress_ms : Ref[UInt64]
  expr_visits : Ref[Int]
  instr_visits : Ref[Int]
  rewrites : Ref[Int]
}

///|
fn FLFuncTraceState::new(
  trace : (String) -> Unit,
  log_func : Bool,
  ordinal : Int,
  func_start_ms : UInt64,
) -> FLFuncTraceState {
  {
    trace,
    log_func,
    ordinal,
    func_start_ms,
    last_progress_ms: Ref::new(0UL),
    expr_visits: Ref::new(0),
    instr_visits: Ref::new(0),
    rewrites: Ref::new(0),
  }
}

///|
priv struct FLFuncState {
  mut env : Env
  locals : Array[ValType]
  break_temps : Map[FLBreakTempKey, LocalIdx]
  mut changed : Bool

  // Label identity stack: each control construct with a label gets a unique uid.
  label_uids : Array[Int]
  next_label_uid : Ref[Int]
  trace_state : FLFuncTraceState?
}

///|
fn FLFuncState::new(
  env : Env,
  locals : Array[ValType],
  trace_state? : FLFuncTraceState? = None,
) -> FLFuncState {
  {
    env,
    locals,
    break_temps: Map::new(),
    changed: false,
    label_uids: [],
    next_label_uid: Ref::new(1),
    trace_state,
  }
}

///|
fn fl_instr_kind_name(instr : TInstr) -> String {
  match instr.kind {
    TInstrKind::TBlock(_, _) => "block"
    TInstrKind::TLoop(_, _) => "loop"
    TInstrKind::TTryTable(_, _, _) => "try_table"
    TInstrKind::TIf(_, _, _, _) => "if"
    TInstrKind::TBr(_, _) => "br"
    TInstrKind::TBrIf(_, _, _) => "br_if"
    TInstrKind::TBrTable(_, _, _, _) => "br_table"
    TInstrKind::TBrOnNull(_, _, _) => "br_on_null"
    TInstrKind::TBrOnNonNull(_, _, _) => "br_on_non_null"
    TInstrKind::TBrOnCast(_, _, _, _, _, _) => "br_on_cast"
    TInstrKind::TBrOnCastFail(_, _, _, _, _, _) => "br_on_cast_fail"
    TInstrKind::TLocalSet(_, _) => "local.set"
    TInstrKind::TLocalTee(_, _) => "local.tee"
    TInstrKind::TLocalGet(_) => "local.get"
    TInstrKind::TDrop(_) => "drop"
    TInstrKind::TCall(_, _) => "call"
    TInstrKind::TCallIndirect(_, _, _, _) => "call_indirect"
    TInstrKind::TCallRef(_, _, _) => "call_ref"
    TInstrKind::TReturn(_) => "return"
    TInstrKind::TSelect(_, _, _, _) => "select"
    _ => "other"
  }
}

///|
fn fl_trace_maybe_emit_progress(
  state : FLFuncState,
  phase : String,
  detail : String,
) -> Unit {
  match state.trace_state {
    Some(ts) => {
      if !ts.log_func {
        return
      }
      let now_ms = fl_trace_now_ms()
      let expr_visits = ts.expr_visits.val
      let instr_visits = ts.instr_visits.val
      let rewrites = ts.rewrites.val
      let work_done = expr_visits + instr_visits + rewrites
      let has_emitted_progress = ts.last_progress_ms.val != 0UL
      let since_last_ms = if has_emitted_progress &&
        now_ms >= ts.last_progress_ms.val {
        now_ms - ts.last_progress_ms.val
      } else {
        0UL
      }
      let should_emit_first = !has_emitted_progress && work_done >= 32
      let should_emit_periodic = (
          expr_visits > 0 &&
          (
            (expr_visits <= 256 && expr_visits % 64 == 0) ||
            expr_visits % FL_TRACE_PROGRESS_INTERVAL == 0
          )
        ) ||
        (
          instr_visits > 0 &&
          (
            (instr_visits <= 512 && instr_visits % 128 == 0) ||
            instr_visits % FL_TRACE_PROGRESS_INTERVAL == 0
          )
        ) ||
        (rewrites > 0 && rewrites % 32 == 0)
      let should_emit_timed = since_last_ms >= FL_TRACE_PROGRESS_INTERVAL_MS
      if !(should_emit_first || should_emit_periodic || should_emit_timed) {
        return
      }
      (ts.trace)(
        "func[\{ts.ordinal}] progress phase=\{phase} elapsed_ms=\{fl_trace_elapsed_ms(ts.func_start_ms)} exprs=\{expr_visits} instrs=\{instr_visits} rewrites=\{rewrites} \{detail}",
      )
      ts.last_progress_ms.val = now_ms
    }
    None => ()
  }
}

///|
fn fl_trace_note_expr_visit(
  state : FLFuncState,
  phase : String,
  detail : String,
) -> Unit {
  match state.trace_state {
    Some(ts) => ts.expr_visits.val = ts.expr_visits.val + 1
    None => ()
  }
  fl_trace_maybe_emit_progress(state, phase, detail)
}

///|
fn fl_trace_note_instr_visit(
  state : FLFuncState,
  phase : String,
  detail : String,
) -> Unit {
  match state.trace_state {
    Some(ts) => ts.instr_visits.val = ts.instr_visits.val + 1
    None => ()
  }
  fl_trace_maybe_emit_progress(state, phase, detail)
}

///|
fn fl_trace_helper_start(
  state : FLFuncState,
  helper : String,
  detail : String,
) -> UInt64 {
  let start_ms = fl_trace_now_ms()
  match state.trace_state {
    Some(ts) =>
      if ts.log_func {
        (ts.trace)(
          "func[\{ts.ordinal}] helper=\{helper} step=start elapsed_ms=\{fl_trace_elapsed_ms(ts.func_start_ms)} \{detail}",
        )
      }
    None => ()
  }
  start_ms
}

///|
fn fl_trace_helper_done(
  state : FLFuncState,
  helper : String,
  start_ms : UInt64,
  detail : String,
) -> Unit {
  match state.trace_state {
    Some(ts) =>
      if ts.log_func {
        (ts.trace)(
          "func[\{ts.ordinal}] helper=\{helper} step=done elapsed_ms=\{fl_trace_elapsed_ms(start_ms)} total_ms=\{fl_trace_elapsed_ms(ts.func_start_ms)} \{detail}",
        )
      }
    None => ()
  }
}

///|
fn fl_trace_helper_event(
  state : FLFuncState,
  helper : String,
  step : String,
  detail : String,
) -> Unit {
  match state.trace_state {
    Some(ts) =>
      if ts.log_func {
        (ts.trace)(
          "func[\{ts.ordinal}] helper=\{helper} step=\{step} elapsed_ms=\{fl_trace_elapsed_ms(ts.func_start_ms)} \{detail}",
        )
      }
    None => ()
  }
}

///|
fn fl_trace_mark_rewrite(
  state : FLFuncState,
  helper : String,
  detail : String,
) -> Unit {
  state.changed = true
  match state.trace_state {
    Some(ts) => ts.rewrites.val = ts.rewrites.val + 1
    None => ()
  }
  fl_trace_helper_event(state, helper, "rewrite", detail)
  fl_trace_maybe_emit_progress(state, helper, detail)
}

///|
fn fl_rewrite_counter(state : FLFuncState) -> Int? {
  match state.trace_state {
    Some(ts) => Some(ts.rewrites.val)
    None => None
  }
}

///|
fn fl_rewrite_counter_changed(state : FLFuncState, before : Int?) -> Bool? {
  match before {
    Some(prev) =>
      match state.trace_state {
        Some(ts) => Some(ts.rewrites.val != prev)
        None => None
      }
    None => None
  }
}

///|
fn fl_label_depth(label : LabelIdx) -> Int {
  let LabelIdx(raw) = label
  raw.reinterpret_as_int()
}

///|
fn fl_bump_label(label : LabelIdx, delta : Int) -> LabelIdx {
  LabelIdx::new((fl_label_depth(label) + delta).reinterpret_as_uint())
}

///|
fn fl_push_label(state : FLFuncState) -> Int {
  let uid = state.next_label_uid.val
  state.next_label_uid.update(fn(i) { i + 1 })
  state.label_uids.push(uid)
  uid
}

///|
fn fl_pop_label(state : FLFuncState) -> Unit {
  if state.label_uids.length() > 0 {
    ignore(state.label_uids.pop())
  }
}

///|
fn fl_resolve_label_uid(state : FLFuncState, label : LabelIdx) -> Int? {
  let depth = fl_label_depth(label)
  let n = state.label_uids.length()
  // LabelIdx(0) refers to innermost enclosing label => last element.
  let idx = n - 1 - depth
  if idx < 0 || idx >= n {
    None
  } else {
    Some(state.label_uids[idx])
  }
}

///|
fn fl_add_temp_local(state : FLFuncState, ty : ValType) -> LocalIdx {
  let idx = LocalIdx::new(state.locals.length().reinterpret_as_uint())
  state.locals.push(ty)
  state.env = state.env.with_locals(state.locals)
  fl_trace_mark_rewrite(state, "fl_add_temp_local", "new_local=\{idx}")
  idx
}

///|
fn fl_get_break_temp(
  state : FLFuncState,
  label : LabelIdx,
  ty : ValType,
) -> LocalIdx {
  // IMPORTANT: resolve to stable label uid, not raw LabelIdx depth
  let uid = match fl_resolve_label_uid(state, label) {
    Some(u) => u
    None =>
      // Fallback: if something is malformed, still avoid crashing.
      // Use an impossible uid derived from depth (still better than conflating everything).
      // You may prefer to return an Err instead, but this keeps the signature.
      -1000000 - fl_label_depth(label)
  }
  let key = { label_uid: uid, val_type: ty }
  match state.break_temps.get(key) {
    Some(idx) => idx
    None => {
      let idx = fl_add_temp_local(state, ty)
      state.break_temps[key] = idx
      fl_trace_helper_event(
        state,
        "fl_get_break_temp",
        "allocate",
        "label_uid=\{uid} val_type=\{ty}",
      )
      idx
    }
  }
}

///|
fn fl_instr_type(instr : TInstr, env : Env) -> ValType? {
  lcs_infer_tinstr_type(instr, env)
}

///|
fn fl_lowerable_single_result_blocktype(bt : BlockType, env : Env) -> ValType? {
  match env.expand_blocktype(bt) {
    Ok((params, [vt])) if params.is_empty() => Some(vt)
    _ => None
  }
}

///|
priv enum FLPosition {
  ValuePos
  StatementPos
}

///|
fn fl_can_emit_statement_preludes(pos : FLPosition) -> Bool {
  match pos {
    StatementPos => true
    ValuePos => false
  }
}

///|
/// Atomic leaves for flattening/idempotence.
/// These should not be wrapped into temp locals repeatedly.

///|
fn fl_is_leaf_constant_or_nop(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TI32Const(_)
    | TInstrKind::TI64Const(_)
    | TInstrKind::TF32Const(_)
    | TInstrKind::TF64Const(_)
    | TInstrKind::TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | TInstrKind::TRefNull(_)
    | TInstrKind::TRefFunc(_)
    | TInstrKind::TLocalGet(_)
    | TInstrKind::TGlobalGet(_)
    | TInstrKind::TNop => true
    _ => false
  }
}

///|
/// Main flattening entry for expressions: unchanged signature.
fn fl_flatten_texpr(body : TExpr, state : FLFuncState) -> Result[TExpr, String] {
  let helper_start_ms = fl_trace_helper_start(
    state,
    "fl_flatten_texpr",
    "instrs=\{body.instrs.length()}",
  )
  fl_trace_note_expr_visit(
    state,
    "helper=fl_flatten_texpr:start",
    "instrs=\{body.instrs.length()}",
  )
  let out : Array[TInstr] = []
  for instr in body.instrs {
    let (next_instr, preludes) = match
      fl_flatten_instr(instr, state, StatementPos) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    for prelude in preludes {
      out.push(prelude)
      fl_trace_mark_rewrite(
        state,
        "fl_flatten_texpr",
        "insert_prelude kind=\{fl_instr_kind_name(prelude)}",
      )
    }
    out.push(next_instr)
  }
  fl_trace_helper_done(
    state,
    "fl_flatten_texpr",
    helper_start_ms,
    "instrs=\{body.instrs.length()} out_instrs=\{out.length()}",
  )
  Ok(TExpr::new(out))
}

///|
fn fl_flatten_non_control_children(
  instr : TInstr,
  state : FLFuncState,
) -> Result[(TInstr, Array[TInstr]), String] {
  let helper_start_ms = fl_trace_helper_start(
    state,
    "fl_flatten_non_control_children",
    "kind=\{fl_instr_kind_name(instr)}",
  )
  let children = eval_children(instr)
  if children.is_empty() {
    fl_trace_helper_done(
      state, "fl_flatten_non_control_children", helper_start_ms, "children=0 changed=false",
    )
    return Ok((instr, []))
  }
  let rebuilt_children : Array[TInstr] = []
  let preludes : Array[TInstr] = []
  let mut any_child_change = false
  for child in children {
    let rewrite_before = fl_rewrite_counter(state)
    let (next_child, child_preludes) = match
      fl_flatten_instr(child, state, ValuePos) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    if !child_preludes.is_empty() {
      return Err(
        "flatten: value-position rewrite attempted statement extraction",
      )
    }
    for p in child_preludes {
      preludes.push(p)
    }
    match fl_rewrite_counter_changed(state, rewrite_before) {
      // Use rewrite-counter deltas to detect child changes without deep structural equality.
      // Deep `next_child != child` checks are pathological on huge unchanged expression trees.
      Some(changed) => if changed { any_child_change = true }
      None =>
        // Fallback keeps correctness when no trace state is attached.
        if next_child != child {
          any_child_change = true
        }
    }
    rebuilt_children.push(next_child)
  }
  if any_child_change {
    fl_trace_mark_rewrite(
      state,
      "fl_flatten_non_control_children",
      "kind=\{fl_instr_kind_name(instr)} children=\{children.length()}",
    )
    fl_trace_helper_done(
      state,
      "fl_flatten_non_control_children",
      helper_start_ms,
      "children=\{children.length()} changed=true preludes=\{preludes.length()}",
    )
    Ok((mb_rebuild_non_control(instr, rebuilt_children), preludes))
  } else {
    fl_trace_helper_done(
      state,
      "fl_flatten_non_control_children",
      helper_start_ms,
      "children=\{children.length()} changed=false preludes=\{preludes.length()}",
    )
    Ok((instr, preludes))
  }
}

///|
fn fl_flatten_instr(
  instr : TInstr,
  state : FLFuncState,
  pos : FLPosition,
) -> Result[(TInstr, Array[TInstr]), String] {
  fl_trace_note_instr_visit(
    state,
    "helper=fl_flatten_instr",
    "kind=\{fl_instr_kind_name(instr)}",
  )
  if fl_is_leaf_constant_or_nop(instr) {
    return Ok((instr, []))
  }

  let mut curr = instr
  let preludes : Array[TInstr] = []

  match curr.kind {
    TInstrKind::TBlock(bt, body) => {
      // Enter label scope
      let my_uid = fl_push_label(state)

      let next_body = match fl_flatten_texpr(body, state) {
        Ok(v) => v
        Err(e) => {
          fl_pop_label(state)
          return Err(e)
        }
      }

      // If this block produces a value, lower it correctly:
      // - allocate temp
      // - rewrite all branches targeting this block (by uid) to store + branch with no values
      // - rewrite fallthrough value to store
      // - emit void block as a prelude, return local.get(temp)
      if !fl_can_emit_statement_preludes(pos) {
        curr = TInstr::block(bt, next_body)
      } else {
        match bt {
          VoidBlockType => curr = TInstr::block(bt, next_body)
          _ => {
            // block has a result type (possibly val_type or type index); we only support single ValType here
            let branch_scan = fl_scan_unsupported_targeting_branch_in_texpr(
              next_body, state, my_uid,
            )
            if branch_scan.blocked {
              curr = TInstr::block(bt, next_body)
            } else {
              match fl_lowerable_single_result_blocktype(bt, state.env) {
                Some(vt) => {
                  let temp = fl_add_temp_local(state, vt)

                  // Only run the full rewrite walk if there are actually target branches to rewrite.
                  let rewritten1 = if branch_scan.rewritable_targeting_branches >
                    0 {
                    fl_rewrite_label_value_flow_in_texpr(
                      next_body, state, my_uid, temp,
                    )
                  } else {
                    next_body
                  }

                  // Handle fallthrough result
                  let rewritten2 = fl_rewrite_fallthrough_value_to_set(
                    rewritten1,
                    temp,
                    state.env,
                  )

                  preludes.push(TInstr::block(BlockType::void_(), rewritten2))
                  curr = TInstr::local_get(temp)
                  fl_trace_mark_rewrite(
                    state, "fl_flatten_instr", "lower_result_block kind=block",
                  )
                }
                None =>
                  // unexpected, but keep structure
                  curr = TInstr::block(bt, next_body)
              }
            }
          }
        }
      }

      // Leave label scope
      fl_pop_label(state)
    }
    TInstrKind::TLoop(bt, body) => {
      let my_uid = fl_push_label(state)

      let next_body = match fl_flatten_texpr(body, state) {
        Ok(v) => v
        Err(e) => {
          fl_pop_label(state)
          return Err(e)
        }
      }

      if !fl_can_emit_statement_preludes(pos) {
        curr = TInstr::loop_(bt, next_body)
      } else {
        match bt {
          VoidBlockType => curr = TInstr::loop_(bt, next_body)
          _ => {
            let branch_scan = fl_scan_unsupported_targeting_branch_in_texpr(
              next_body, state, my_uid,
            )
            if branch_scan.blocked {
              curr = TInstr::loop_(bt, next_body)
            } else {
              match fl_lowerable_single_result_blocktype(bt, state.env) {
                Some(vt) => {
                  let temp = fl_add_temp_local(state, vt)
                  let rewritten1 = if branch_scan.rewritable_targeting_branches >
                    0 {
                    fl_rewrite_label_value_flow_in_texpr(
                      next_body, state, my_uid, temp,
                    )
                  } else {
                    next_body
                  }
                  let rewritten2 = fl_rewrite_fallthrough_value_to_set(
                    rewritten1,
                    temp,
                    state.env,
                  )

                  preludes.push(TInstr::loop_(BlockType::void_(), rewritten2))
                  curr = TInstr::local_get(temp)
                  fl_trace_mark_rewrite(
                    state, "fl_flatten_instr", "lower_result_block kind=loop",
                  )
                }
                None => curr = TInstr::loop_(bt, next_body)
              }
            }
          }
        }
      }

      fl_pop_label(state)
    }
    TInstrKind::TTryTable(bt, catches, body) => {
      let my_uid = fl_push_label(state)

      let next_body = match fl_flatten_texpr(body, state) {
        Ok(v) => v
        Err(e) => {
          fl_pop_label(state)
          return Err(e)
        }
      }

      if !fl_can_emit_statement_preludes(pos) {
        curr = TInstr::try_table(bt, catches, next_body)
      } else {
        match bt {
          VoidBlockType => curr = TInstr::try_table(bt, catches, next_body)
          _ => {
            let branch_scan = fl_scan_unsupported_targeting_branch_in_texpr(
              next_body, state, my_uid,
            )
            if branch_scan.blocked {
              curr = TInstr::try_table(bt, catches, next_body)
            } else {
              match fl_lowerable_single_result_blocktype(bt, state.env) {
                Some(vt) => {
                  let temp = fl_add_temp_local(state, vt)
                  let rewritten1 = if branch_scan.rewritable_targeting_branches >
                    0 {
                    fl_rewrite_label_value_flow_in_texpr(
                      next_body, state, my_uid, temp,
                    )
                  } else {
                    next_body
                  }
                  let rewritten2 = fl_rewrite_fallthrough_value_to_set(
                    rewritten1,
                    temp,
                    state.env,
                  )

                  preludes.push(
                    TInstr::try_table(BlockType::void_(), catches, rewritten2),
                  )
                  curr = TInstr::local_get(temp)
                  fl_trace_mark_rewrite(
                    state, "fl_flatten_instr", "lower_result_block kind=try_table",
                  )
                }
                None => curr = TInstr::try_table(bt, catches, next_body)
              }
            }
          }
        }
      }

      fl_pop_label(state)
    }
    TInstrKind::TIf(bt, cond, then_body, else_body) => {
      // Flatten condition first
      let (next_cond, cond_preludes) = match
        fl_flatten_instr(cond, state, ValuePos) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      if !cond_preludes.is_empty() {
        return Err(
          "flatten: value-position rewrite attempted statement extraction",
        )
      }
      for p in cond_preludes {
        preludes.push(p)
      }

      // Enter the if label scope for then/else bodies (br 0 targets end of if)
      let my_uid = fl_push_label(state)

      let next_then = match fl_flatten_texpr(then_body, state) {
        Ok(v) => v
        Err(e) => {
          fl_pop_label(state)
          return Err(e)
        }
      }
      let next_else = match else_body {
        Some(b) =>
          match fl_flatten_texpr(b, state) {
            Ok(v) => Some(v)
            Err(e) => {
              fl_pop_label(state)
              return Err(e)
            }
          }
        None => None
      }

      let mut rewritten_if = TInstr::if_(bt, next_cond, next_then, next_else)

      // Lower if result properly if it has a value:
      let then_branch_scan = fl_scan_unsupported_targeting_branch_in_texpr(
        next_then, state, my_uid,
      )
      let else_branch_scan = match next_else {
        Some(body) =>
          Some(
            fl_scan_unsupported_targeting_branch_in_texpr(body, state, my_uid),
          )
        None => None
      }
      let else_has_unsupported_if_target = match else_branch_scan {
        Some(scan) => scan.blocked
        None => false
      }
      let has_unsupported_if_target = then_branch_scan.blocked ||
        else_has_unsupported_if_target
      if !fl_can_emit_statement_preludes(pos) || has_unsupported_if_target {
        curr = rewritten_if
      } else {
        match fl_lowerable_single_result_blocktype(bt, state.env) {
          Some(vt) => {
            let temp = fl_add_temp_local(state, vt)
            let then1 = if then_branch_scan.rewritable_targeting_branches > 0 {
              fl_rewrite_label_value_flow_in_texpr(
                next_then, state, my_uid, temp,
              )
            } else {
              next_then
            }
            let then2 = fl_rewrite_fallthrough_value_to_set(
              then1,
              temp,
              state.env,
            )

            let else2 = match next_else {
              Some(b) => {
                let else1 = match else_branch_scan {
                  Some(scan) =>
                    if scan.rewritable_targeting_branches > 0 {
                      fl_rewrite_label_value_flow_in_texpr(
                        b, state, my_uid, temp,
                      )
                    } else {
                      b
                    }
                  _ => b
                }
                fl_rewrite_fallthrough_value_to_set(else1, temp, state.env)
              }
              None =>
                return Err(
                  "flatten: if with concrete result requires an else branch",
                )
            }

            rewritten_if = TInstr::if_(
              BlockType::void_(),
              next_cond,
              then2,
              Some(else2),
            )
            preludes.push(rewritten_if)
            curr = TInstr::local_get(temp)
            fl_trace_mark_rewrite(
              state, "fl_flatten_instr", "lower_result_block kind=if",
            )
          }
          None => curr = rewritten_if
        }
      }

      fl_pop_label(state)
    }
    _ => {
      // Non-control: flatten children
      let (rebuilt, child_preludes) = match
        fl_flatten_non_control_children(curr, state) {
        Ok(v) => v
        Err(e) => return Err(e)
      }
      curr = rebuilt
      for p in child_preludes {
        preludes.push(p)
      }

      // Branch value localization (stable label identity now)
      if fl_can_emit_statement_preludes(pos) {
        match curr.kind {
          TInstrKind::TBr(label, values) =>
            if values.length() == 1 {
              match fl_instr_type(values[0], state.env) {
                Some(vt) => {
                  let temp = fl_get_break_temp(state, label, vt)
                  preludes.push(TInstr::local_set(temp, values[0]))
                  curr = TInstr::br(label, [TInstr::local_get(temp)])
                  fl_trace_mark_rewrite(
                    state, "fl_flatten_instr", "localize_branch_value kind=br",
                  )
                }
                None => ()
              }
            }
          TInstrKind::TBrIf(label, cond, values) =>
            if values.length() == 1 {
              match fl_instr_type(values[0], state.env) {
                Some(vt) => {
                  let temp = fl_get_break_temp(state, label, vt)
                  preludes.push(TInstr::local_set(temp, values[0]))
                  curr = TInstr::br_if(label, cond, [TInstr::local_get(temp)])
                  fl_trace_mark_rewrite(
                    state, "fl_flatten_instr", "localize_branch_value kind=br_if",
                  )
                }
                None => ()
              }
            }
          TInstrKind::TBrOnNull(label, ref_, values) =>
            if values.length() == 1 {
              match fl_instr_type(values[0], state.env) {
                Some(vt) => {
                  let temp = fl_get_break_temp(state, label, vt)
                  preludes.push(TInstr::local_set(temp, values[0]))
                  curr = TInstr::br_on_null(label, ref_, [
                    TInstr::local_get(temp),
                  ])
                  fl_trace_mark_rewrite(
                    state, "fl_flatten_instr", "localize_branch_value kind=br_on_null",
                  )
                }
                None => ()
              }
            }
          TInstrKind::TBrOnNonNull(label, ref_, values) =>
            if values.length() == 1 {
              match fl_instr_type(values[0], state.env) {
                Some(vt) => {
                  let temp = fl_get_break_temp(state, label, vt)
                  preludes.push(TInstr::local_set(temp, values[0]))
                  curr = TInstr::br_on_non_null(label, ref_, [
                    TInstr::local_get(temp),
                  ])
                  fl_trace_mark_rewrite(
                    state, "fl_flatten_instr", "localize_branch_value kind=br_on_non_null",
                  )
                }
                None => ()
              }
            }
          TInstrKind::TBrOnCast(label, castop, ht1, ht2, ref_, values) =>
            if values.length() == 1 {
              match fl_instr_type(values[0], state.env) {
                Some(vt) => {
                  let temp = fl_get_break_temp(state, label, vt)
                  preludes.push(TInstr::local_set(temp, values[0]))
                  curr = TInstr::br_on_cast(
                    label,
                    castop.0,
                    ht1,
                    castop.1,
                    ht2,
                    ref_,
                    [TInstr::local_get(temp)],
                  )
                  fl_trace_mark_rewrite(
                    state, "fl_flatten_instr", "localize_branch_value kind=br_on_cast",
                  )
                }
                None => ()
              }
            }
          TInstrKind::TBrOnCastFail(label, castop, ht1, ht2, ref_, values) =>
            if values.length() == 1 {
              match fl_instr_type(values[0], state.env) {
                Some(vt) => {
                  let temp = fl_get_break_temp(state, label, vt)
                  preludes.push(TInstr::local_set(temp, values[0]))
                  curr = TInstr::br_on_cast_fail(
                    label,
                    castop.0,
                    ht1,
                    castop.1,
                    ht2,
                    ref_,
                    [TInstr::local_get(temp)],
                  )
                  fl_trace_mark_rewrite(
                    state, "fl_flatten_instr", "localize_branch_value kind=br_on_cast_fail",
                  )
                }
                None => ()
              }
            }
          _ => ()
        }
      }
    }
  }

  if !fl_can_emit_statement_preludes(pos) && !preludes.is_empty() {
    return Err("flatten: value-position rewrite attempted statement extraction")
  }

  // Preserve unreachable handling
  if is_unreachable_instr(curr) {
    if fl_can_emit_statement_preludes(pos) {
      preludes.push(curr)
      fl_trace_mark_rewrite(
        state, "fl_flatten_instr", "unreachable_lifted_to_prelude",
      )
      return Ok((TInstr::unreachable_(), preludes))
    }
    return Ok((curr, preludes))
  }

  // Final "wrap typed expr into temp" rule is statement-only.
  if !fl_can_emit_statement_preludes(pos) {
    return Ok((curr, preludes))
  }
  match fl_instr_type(curr, state.env) {
    Some(vt) =>
      if !fl_is_leaf_constant_or_nop(curr) {
        let temp = fl_add_temp_local(state, vt)
        preludes.push(TInstr::local_set(temp, curr))
        fl_trace_mark_rewrite(
          state,
          "fl_flatten_instr",
          "wrap_typed_expr_in_temp kind=\{fl_instr_kind_name(curr)}",
        )
        Ok((TInstr::local_get(temp), preludes))
      } else {
        Ok((curr, preludes))
      }
    None => Ok((curr, preludes))
  }
}

///|
fn fl_collect_param_types(mod : Module) -> Array[Array[ValType]] {
  let out : Array[Array[ValType]] = []
  let env = Env::new().with_module(mod)
  match mod.func_sec {
    Some(FuncSec(type_idxs)) =>
      for tidx in type_idxs {
        match env.resolve_functype(tidx) {
          Some(FuncType(params, _)) => out.push(params)
          None => out.push([])
        }
      }
    None => ()
  }
  out
}

///|
fn fl_defined_func_count(mod : Module) -> Int {
  match mod.code_sec {
    Some(CodeSec(funcs)) => funcs.length()
    None => 0
  }
}

///|
fn flatten_ir_pass_with_trace(
  mod : Module,
  trace? : (String) -> Unit = fl_trace_noop,
  trace_all_funcs? : Bool = false,
) -> ModuleTransformer[IRContext, String] {
  let params_start_ms = fl_trace_now_ms()
  trace("phase=flatten:collect_param_types:start")
  let param_types = fl_collect_param_types(mod)
  trace(
    "phase=flatten:collect_param_types:done elapsed_ms=\{fl_trace_elapsed_ms(params_start_ms)} funcs=\{param_types.length()}",
  )
  let next_def_idx = Ref::new(0)
  let base_env = Env::new().with_module(mod)
  trace("phase=flatten:prepare:done funcs=\{fl_defined_func_count(mod)}")
  ModuleTransformer::new().on_func_evt(fn(_, ctx, func : Func) {
    let def_idx = next_def_idx.val
    next_def_idx.update(fn(i) { i + 1 })
    let ordinal = def_idx + 1
    let log_func = fl_trace_should_log_func(ordinal, trace_all_funcs)
    let func_start_ms = fl_trace_now_ms()
    match func {
      TFunc(tfunc_params, locals, body) => {
        if log_func {
          trace(
            "func[\{ordinal}] phase=function:start params=\{tfunc_params.length()} locals=\{locals.length()} top_instrs=\{body.instrs.length()}",
          )
        }
        let trace_state = FLFuncTraceState::new(
          trace, log_func, ordinal, func_start_ms,
        )
        let params = param_types.get(def_idx).unwrap_or([])
        let all_locals = match
          FunctionLocals::from_typed_func_for_pass(params, tfunc_params, locals) {
          Ok(function_locals) => function_locals.all_locals()
          Err(e) => {
            if log_func {
              trace(
                "func[\{ordinal}] phase=locals:error elapsed_ms=\{fl_trace_elapsed_ms(func_start_ms)} \{e}",
              )
            }
            return error("flatten: malformed typed function locals: \{e}")
          }
        }
        if log_func {
          trace(
            "func[\{ordinal}] phase=locals:done elapsed_ms=\{fl_trace_elapsed_ms(func_start_ms)} all_locals=\{all_locals.length()}",
          )
        }
        let state = FLFuncState::new(
          base_env.with_locals(all_locals),
          all_locals,
          trace_state=Some(trace_state),
        )
        let flatten_start_ms = fl_trace_now_ms()
        if log_func {
          trace(
            "func[\{ordinal}] phase=flatten_body:start top_instrs=\{body.instrs.length()}",
          )
        }
        let next_body = match fl_flatten_texpr(body, state) {
          Ok(v) => v
          Err(e) => {
            if log_func {
              trace(
                "func[\{ordinal}] phase=flatten_body:error elapsed_ms=\{fl_trace_elapsed_ms(flatten_start_ms)} \{e}",
              )
            }
            return error(e)
          }
        }
        if log_func {
          trace(
            "func[\{ordinal}] phase=flatten_body:done elapsed_ms=\{fl_trace_elapsed_ms(flatten_start_ms)} top_instrs=\{body.instrs.length()}->\{next_body.instrs.length()}",
          )
        }
        let next_non_param_locals : Array[ValType] = []
        for i in params.length()..<state.locals.length() {
          next_non_param_locals.push(state.locals[i])
        }
        let next_func = Func::t_func(params, next_non_param_locals, next_body)
        if state.changed || next_non_param_locals.length() != locals.length() {
          if log_func {
            match state.trace_state {
              Some(ts) =>
                trace(
                  "func[\{ordinal}] phase=function:done elapsed_ms=\{fl_trace_elapsed_ms(func_start_ms)} changed=true top_instrs=\{body.instrs.length()}->\{next_body.instrs.length()} locals=\{locals.length()}->\{next_non_param_locals.length()} exprs=\{ts.expr_visits.val} instrs=\{ts.instr_visits.val} rewrites=\{ts.rewrites.val}",
                )
              None => ()
            }
          }
          change(ctx, next_func)
        } else {
          if log_func {
            match state.trace_state {
              Some(ts) =>
                trace(
                  "func[\{ordinal}] phase=function:done elapsed_ms=\{fl_trace_elapsed_ms(func_start_ms)} changed=false top_instrs=\{body.instrs.length()}->\{body.instrs.length()} locals=\{locals.length()} exprs=\{ts.expr_visits.val} instrs=\{ts.instr_visits.val} rewrites=\{ts.rewrites.val}",
                )
              None => ()
            }
          }
          unchanged()
        }
      }
      _ => {
        if log_func {
          trace(
            "func[\{ordinal}] phase=function:skip reason=non-typed-func elapsed_ms=\{fl_trace_elapsed_ms(func_start_ms)}",
          )
        }
        unchanged()
      }
    }
  })
}

///|
fn run_flatten_with_trace(
  mod : Module,
  trace? : (String) -> Unit = fl_trace_noop,
  trace_all_funcs? : Bool = false,
) -> Result[Module, String] {
  let pass_start_ms = fl_trace_now_ms()
  trace(
    "phase=flatten:pass:start funcs=\{fl_defined_func_count(mod)} trace_all_funcs=\{trace_all_funcs}",
  )
  let pass = flatten_ir_pass_with_trace(mod, trace~, trace_all_funcs~)
  let validate_output = match validate_module(mod) {
    Ok(_) => true
    Err(_) => false
  }
  trace(
    "phase=flatten:walk_module:start validate_output=\{validate_output} funcs=\{fl_defined_func_count(mod)}",
  )
  match pass.walk_module(IRContext::new(), mod) {
    Ok((out, _)) => {
      trace(
        "phase=flatten:walk_module:done elapsed_ms=\{fl_trace_elapsed_ms(pass_start_ms)} changed=true",
      )
      if validate_output {
        let validate_start_ms = fl_trace_now_ms()
        trace("phase=flatten:validate_output:start")
        match validate_module(out) {
          Ok(_) => {
            trace(
              "phase=flatten:validate_output:done elapsed_ms=\{fl_trace_elapsed_ms(validate_start_ms)}",
            )
            trace(
              "phase=flatten:pass:done elapsed_ms=\{fl_trace_elapsed_ms(pass_start_ms)} changed=true",
            )
            Ok(out)
          }
          Err(e) => {
            trace(
              "phase=flatten:validate_output:failed elapsed_ms=\{fl_trace_elapsed_ms(validate_start_ms)} \{e}",
            )
            Err("flatten: output module failed validation: \{e}")
          }
        }
      } else {
        trace(
          "phase=flatten:pass:done elapsed_ms=\{fl_trace_elapsed_ms(pass_start_ms)} changed=true",
        )
        Ok(out)
      }
    }
    Err(e) => {
      trace(
        "phase=flatten:walk_module:error elapsed_ms=\{fl_trace_elapsed_ms(pass_start_ms)} \{e}",
      )
      Err(e)
    }
  }
}

///|
fn run_flatten(mod : Module) -> Result[Module, String] {
  run_flatten_with_trace(mod)
}

///|
fn fl_count_local_tees(body : TExpr) -> Int {
  let count = Ref::new(0)
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      instr : TInstr,
    ) {
      match instr.kind {
        TInstrKind::TLocalTee(_, _) => count.update(fn(v) { v + 1 })
        _ => ()
      }
      from_walk(self.walk_tinstruction_default((), instr))
    },
  )
  ignore(walker.walk_texpr((), body))
  count.val
}

///|
test "flatten keeps local.tee intact in value positions" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [ValType::i32()],
        TExpr::new([
          TInstr::drop(
            TInstr::local_tee(LocalIdx::new(0), TInstr::i32_const(I32(9))),
          ),
        ]),
      ),
    ]),
  )
  let out = run_flatten(mod).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) =>
      assert_true(fl_count_local_tees(body) >= 1)
    _ => fail("expected flattened typed function")
  }
}

///|
test "flatten: nested local.tee call arguments remain valid and idempotent" {
  let callee_sig = RecType::new(
    SubType::comp_type(
      CompType::func([ValType::i32(), ValType::i32()], [ValType::i32()]),
    ),
  )
  let caller_sig = RecType::new(
    SubType::comp_type(CompType::func([], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([callee_sig, caller_sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [ValType::i32(), ValType::i32()],
          [],
          TExpr::new([
            TInstr::binary(
              BinaryOp::i32_add(),
              TInstr::local_get(LocalIdx::new(0)),
              TInstr::local_get(LocalIdx::new(1)),
            ),
          ]),
        ),
        Func::t_func(
          [],
          [ValType::i32(), ValType::i32()],
          TExpr::new([
            TInstr::call(FuncIdx::new(0), [
              TInstr::local_tee(LocalIdx::new(0), TInstr::i32_const(I32(9))),
              TInstr::local_tee(
                LocalIdx::new(1),
                TInstr::binary(
                  BinaryOp::i32_add(),
                  TInstr::i32_const(I32(1)),
                  TInstr::i32_const(I32(2)),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    )

  let once = run_flatten(mod).unwrap()
  let twice = run_flatten(once).unwrap()
  assert_eq(once, twice)

  match once.code_sec {
    Some(CodeSec([_, TFunc(_, _, body)])) =>
      assert_true(fl_count_local_tees(body) >= 2)
    _ => fail("expected flattened caller function")
  }
  match validate_module(twice) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected flatten output with nested local.tee call args to validate: \{e}",
      )
  }
}

///|
test "flatten preserves value-position if result form" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [ValType::i32(), ValType::i32()],
        TExpr::new([
          TInstr::drop(
            TInstr::if_(
              BlockType::val_type(ValType::i32()),
              TInstr::binary(
                BinaryOp::i32_eq(),
                TInstr::local_get(LocalIdx::new(0)),
                TInstr::i32_const(I32(1)),
              ),
              TExpr::new([TInstr::i32_const(I32(7))]),
              Some(TExpr::new([TInstr::i32_const(I32(8))])),
            ),
          ),
        ]),
      ),
    ]),
  )
  let out = run_flatten(mod).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, locals, { instrs, .. })])) => {
      assert_true(locals.length() >= 2)
      let mut saw_if_i32 = false
      for instr in instrs {
        match instr.kind {
          TInstrKind::TDrop(
            {
              kind: TInstrKind::TIf(
                ValTypeBlockType(NumTypeValType(I32NumType)),
                _,
                _,
                _
              ),
              ..,
            }
          ) => saw_if_i32 = true
          _ => ()
        }
      }
      assert_true(saw_if_i32)
    }
    _ => fail("expected flattened function output")
  }
}

///|
fn fl_count_br_on_family(body : TExpr) -> Int {
  let count = Ref::new(0)
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      instr : TInstr,
    ) {
      match instr.kind {
        TInstrKind::TBrOnNull(_, _, _)
        | TInstrKind::TBrOnNonNull(_, _, _)
        | TInstrKind::TBrOnCast(_, _, _, _, _, _)
        | TInstrKind::TBrOnCastFail(_, _, _, _, _, _) =>
          count.update(fn(v) { v + 1 })
        _ => ()
      }
      from_walk(self.walk_tinstruction_default((), instr))
    },
  )
  ignore(walker.walk_texpr((), body))
  count.val
}

///|
fn fl_find_try_table_result_blocktype(body : TExpr) -> BlockType? {
  let found = Ref::new(None)
  let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      instr : TInstr,
    ) {
      match instr.kind {
        TInstrKind::TTryTable(bt, _, _) =>
          match found.val {
            None => found.update(fn(_) { Some(bt) })
            Some(_) => ()
          }
        _ => ()
      }
      from_walk(self.walk_tinstruction_default((), instr))
    },
  )
  ignore(walker.walk_texpr((), body))
  found.val
}

///|
/// Helper: rewrite fallthrough value (if the last instr produces a value) into
/// `local.set(temp, last)` so the surrounding construct can become void.
/// This is *necessary but not sufficient* for correctness; branch rewrites handle the rest.

///|
fn fl_rewrite_fallthrough_value_to_set(
  body : TExpr,
  temp : LocalIdx,
  env : Env,
) -> TExpr {
  let { instrs: items, .. } = body
  if items.length() == 0 {
    return body
  }
  let out = items.copy()
  let last_i = out.length() - 1
  let last = out[last_i]
  match fl_instr_type(last, env) {
    Some(_) => out[last_i] = TInstr::local_set(temp, last)
    None => ()
  }
  TExpr::new(out)
}

///|
/// Rewrite any branch-like instruction that targets `target_uid` and carries exactly
/// one value so that it stores into `temp` and branches with no values.
/// This removes value flow through label parameters after we lower the label to void.
///
/// NOTE: This rewrite is structural and uses the *current* label stack to resolve LabelIdx.
/// That’s why it’s a separate walk that pushes/pops label uids as it descends.

///|
priv struct FLRewriteLabelFlowScanState {
  start_ms : UInt64
  visited_exprs : Ref[Int]
  visited_instrs : Ref[Int]
  max_depth : Ref[Int]
  next_progress_at : Ref[Int]
  last_progress_ms : Ref[UInt64]
}

///|
fn FLRewriteLabelFlowScanState::new(
  start_ms : UInt64,
) -> FLRewriteLabelFlowScanState {
  {
    start_ms,
    visited_exprs: Ref::new(0),
    visited_instrs: Ref::new(0),
    max_depth: Ref::new(0),
    next_progress_at: Ref::new(FL_REWRITE_LABEL_FLOW_PROGRESS_INTERVAL),
    last_progress_ms: Ref::new(start_ms),
  }
}

///|
fn fl_note_rewrite_label_flow_expr_visit(
  scan_state : FLRewriteLabelFlowScanState,
  depth : Int,
) -> Unit {
  scan_state.visited_exprs.val = scan_state.visited_exprs.val + 1
  if depth > scan_state.max_depth.val {
    scan_state.max_depth.val = depth
  }
}

///|
fn fl_note_rewrite_label_flow_instr_visit(
  state : FLFuncState,
  scan_state : FLRewriteLabelFlowScanState,
  target_uid : Int,
  depth : Int,
  instr : TInstr,
) -> Unit {
  scan_state.visited_instrs.val = scan_state.visited_instrs.val + 1
  if depth > scan_state.max_depth.val {
    scan_state.max_depth.val = depth
  }
  match state.trace_state {
    Some(ts) =>
      if ts.log_func {
        let now_ms = fl_trace_now_ms()
        let should_log_count = scan_state.visited_instrs.val >=
          scan_state.next_progress_at.val
        let should_log_time = now_ms >=
          scan_state.last_progress_ms.val +
          FL_REWRITE_LABEL_FLOW_PROGRESS_INTERVAL_MS
        if should_log_count || should_log_time {
          fl_trace_helper_event(
            state,
            "fl_rewrite_label_value_flow_in_texpr",
            "progress",
            "scan_ms=\{fl_trace_elapsed_ms(scan_state.start_ms)} visited_exprs=\{scan_state.visited_exprs.val} visited_instrs=\{scan_state.visited_instrs.val} max_depth=\{scan_state.max_depth.val} depth=\{depth} kind=\{fl_instr_kind_name(instr)} target_uid=\{target_uid}",
          )
          if should_log_count {
            scan_state.next_progress_at.val = scan_state.next_progress_at.val +
              FL_REWRITE_LABEL_FLOW_PROGRESS_INTERVAL
          }
          scan_state.last_progress_ms.val = now_ms
        }
      }
    None => ()
  }
}

///|
fn fl_rewrite_label_value_flow_in_instr_scan(
  instr : TInstr,
  state : FLFuncState,
  target_uid : Int,
  temp : LocalIdx,
  scan_state : FLRewriteLabelFlowScanState,
  depth : Int,
) -> TInstr {
  fl_note_rewrite_label_flow_instr_visit(
    state, scan_state, target_uid, depth, instr,
  )
  // Push labels for control constructs before walking into their bodies, so
  // LabelIdx resolution is correct inside.
  match instr.kind {
    TInstrKind::TBlock(bt, body) => {
      let _uid = fl_push_label(state)
      let next_body = fl_rewrite_label_value_flow_in_texpr_scan(
        body,
        state,
        target_uid,
        temp,
        scan_state,
        depth + 1,
      )
      fl_pop_label(state)
      TInstr::block(bt, next_body)
    }
    TInstrKind::TLoop(bt, body) => {
      let _uid = fl_push_label(state)
      let next_body = fl_rewrite_label_value_flow_in_texpr_scan(
        body,
        state,
        target_uid,
        temp,
        scan_state,
        depth + 1,
      )
      fl_pop_label(state)
      TInstr::loop_(bt, next_body)
    }
    TInstrKind::TTryTable(bt, catches, body) => {
      let _uid = fl_push_label(state)
      let next_body = fl_rewrite_label_value_flow_in_texpr_scan(
        body,
        state,
        target_uid,
        temp,
        scan_state,
        depth + 1,
      )
      fl_pop_label(state)
      TInstr::try_table(bt, catches, next_body)
    }
    TInstrKind::TIf(bt, cond, then_body, else_body) => {
      let next_cond = fl_rewrite_label_value_flow_in_instr_scan(
        cond,
        state,
        target_uid,
        temp,
        scan_state,
        depth + 1,
      )
      let _uid = fl_push_label(state)
      let next_then = fl_rewrite_label_value_flow_in_texpr_scan(
        then_body,
        state,
        target_uid,
        temp,
        scan_state,
        depth + 1,
      )
      let next_else = match else_body {
        Some(b) =>
          Some(
            fl_rewrite_label_value_flow_in_texpr_scan(
              b,
              state,
              target_uid,
              temp,
              scan_state,
              depth + 1,
            ),
          )
        None => None
      }
      fl_pop_label(state)
      TInstr::if_(bt, next_cond, next_then, next_else)
    }
    _ => {
      // First, recursively rewrite children in non-control instructions.
      // (Control instructions are handled above.)
      let children = eval_children(instr)
      if !children.is_empty() {
        let rebuilt : Array[TInstr] = []
        for child in children {
          rebuilt.push(
            fl_rewrite_label_value_flow_in_instr_scan(
              child,
              state,
              target_uid,
              temp,
              scan_state,
              depth + 1,
            ),
          )
        }
        let instr2 = mb_rebuild_non_control(instr, rebuilt)

        // Now rewrite branch-like forms at this node.
        fl_rewrite_branch_node(instr2, state, target_uid, temp)
      } else {
        fl_rewrite_branch_node(instr, state, target_uid, temp)
      }
    }
  }
}

///|
fn fl_rewrite_label_value_flow_in_texpr_scan(
  body : TExpr,
  state : FLFuncState,
  target_uid : Int,
  temp : LocalIdx,
  scan_state : FLRewriteLabelFlowScanState,
  depth : Int,
) -> TExpr {
  fl_note_rewrite_label_flow_expr_visit(scan_state, depth)
  let out : Array[TInstr] = []
  for instr in body.instrs {
    out.push(
      fl_rewrite_label_value_flow_in_instr_scan(
        instr,
        state,
        target_uid,
        temp,
        scan_state,
        depth + 1,
      ),
    )
  }
  TExpr::new(out)
}

///|
fn fl_rewrite_label_value_flow_in_texpr(
  body : TExpr,
  state : FLFuncState,
  target_uid : Int,
  temp : LocalIdx,
) -> TExpr {
  let helper_start_ms = fl_trace_helper_start(
    state,
    "fl_rewrite_label_value_flow_in_texpr",
    "instrs=\{body.instrs.length()} target_uid=\{target_uid}",
  )
  let scan_state = FLRewriteLabelFlowScanState::new(helper_start_ms)
  let out = fl_rewrite_label_value_flow_in_texpr_scan(
    body, state, target_uid, temp, scan_state, 0,
  )
  fl_trace_helper_done(
    state,
    "fl_rewrite_label_value_flow_in_texpr",
    helper_start_ms,
    "instrs=\{body.instrs.length()} out_instrs=\{out.instrs.length()} target_uid=\{target_uid} visited_exprs=\{scan_state.visited_exprs.val} visited_instrs=\{scan_state.visited_instrs.val} max_depth=\{scan_state.max_depth.val}",
  )
  out
}

///|
fn fl_label_targets_uid(
  state : FLFuncState,
  label : LabelIdx,
  target_uid : Int,
) -> Bool {
  match fl_resolve_label_uid(state, label) {
    Some(uid) => uid == target_uid
    None => false
  }
}

///|
fn fl_br_table_targets_uid(
  state : FLFuncState,
  labels : Array[LabelIdx],
  default_label : LabelIdx,
  target_uid : Int,
) -> Bool {
  if fl_label_targets_uid(state, default_label, target_uid) {
    return true
  }
  for label in labels {
    if fl_label_targets_uid(state, label, target_uid) {
      return true
    }
  }
  false
}

///|
priv struct FLUnsupportedBranchScanState {
  start_ms : UInt64
  visited_exprs : Ref[Int]
  visited_instrs : Ref[Int]
  max_depth : Ref[Int]
  rewritable_targeting_branches : Ref[Int]
  next_progress_at : Ref[Int]
  last_progress_ms : Ref[UInt64]
}

///|
fn FLUnsupportedBranchScanState::new(
  start_ms : UInt64,
) -> FLUnsupportedBranchScanState {
  {
    start_ms,
    visited_exprs: Ref::new(0),
    visited_instrs: Ref::new(0),
    max_depth: Ref::new(0),
    rewritable_targeting_branches: Ref::new(0),
    next_progress_at: Ref::new(FL_UNSUPPORTED_BRANCH_SCAN_PROGRESS_INTERVAL),
    last_progress_ms: Ref::new(start_ms),
  }
}

///|
priv struct FLUnsupportedBranchScanSummary {
  blocked : Bool
  rewritable_targeting_branches : Int
}

///|
fn fl_note_unsupported_branch_scan_expr_visit(
  scan_state : FLUnsupportedBranchScanState,
  depth : Int,
) -> Unit {
  scan_state.visited_exprs.val = scan_state.visited_exprs.val + 1
  if depth > scan_state.max_depth.val {
    scan_state.max_depth.val = depth
  }
}

///|
fn fl_note_unsupported_branch_scan_instr_visit(
  state : FLFuncState,
  scan_state : FLUnsupportedBranchScanState,
  target_uid : Int,
  depth : Int,
  instr : TInstr,
) -> Unit {
  scan_state.visited_instrs.val = scan_state.visited_instrs.val + 1
  if depth > scan_state.max_depth.val {
    scan_state.max_depth.val = depth
  }
  match state.trace_state {
    Some(ts) =>
      if ts.log_func {
        let now_ms = fl_trace_now_ms()
        let should_log_count = scan_state.visited_instrs.val >=
          scan_state.next_progress_at.val
        let should_log_time = now_ms >=
          scan_state.last_progress_ms.val +
          FL_UNSUPPORTED_BRANCH_SCAN_PROGRESS_INTERVAL_MS
        if should_log_count || should_log_time {
          fl_trace_helper_event(
            state,
            "fl_has_unsupported_targeting_branch_in_texpr",
            "progress",
            "scan_ms=\{fl_trace_elapsed_ms(scan_state.start_ms)} visited_exprs=\{scan_state.visited_exprs.val} visited_instrs=\{scan_state.visited_instrs.val} max_depth=\{scan_state.max_depth.val} depth=\{depth} kind=\{fl_instr_kind_name(instr)} target_uid=\{target_uid}",
          )
          if should_log_count {
            scan_state.next_progress_at.val = scan_state.next_progress_at.val +
              FL_UNSUPPORTED_BRANCH_SCAN_PROGRESS_INTERVAL
          }
          scan_state.last_progress_ms.val = now_ms
        }
      }
    None => ()
  }
}

///|
fn fl_has_unsupported_targeting_branch_in_instr_scan(
  instr : TInstr,
  state : FLFuncState,
  target_uid : Int,
  scan_state : FLUnsupportedBranchScanState,
  depth : Int,
) -> Bool {
  fl_note_unsupported_branch_scan_instr_visit(
    state, scan_state, target_uid, depth, instr,
  )
  match instr.kind {
    TInstrKind::TBlock(_, body) => {
      let _uid = fl_push_label(state)
      let blocked = fl_has_unsupported_targeting_branch_in_texpr_scan(
        body,
        state,
        target_uid,
        scan_state,
        depth + 1,
      )
      fl_pop_label(state)
      blocked
    }
    TInstrKind::TLoop(_, body) => {
      let _uid = fl_push_label(state)
      let blocked = fl_has_unsupported_targeting_branch_in_texpr_scan(
        body,
        state,
        target_uid,
        scan_state,
        depth + 1,
      )
      fl_pop_label(state)
      blocked
    }
    TInstrKind::TTryTable(_, _, body) => {
      let _uid = fl_push_label(state)
      let blocked = fl_has_unsupported_targeting_branch_in_texpr_scan(
        body,
        state,
        target_uid,
        scan_state,
        depth + 1,
      )
      fl_pop_label(state)
      blocked
    }
    TInstrKind::TIf(_, _, then_body, else_body) => {
      let _uid = fl_push_label(state)
      let then_blocked = fl_has_unsupported_targeting_branch_in_texpr_scan(
        then_body,
        state,
        target_uid,
        scan_state,
        depth + 1,
      )
      let else_blocked = match else_body {
        Some(body) =>
          fl_has_unsupported_targeting_branch_in_texpr_scan(
            body,
            state,
            target_uid,
            scan_state,
            depth + 1,
          )
        None => false
      }
      fl_pop_label(state)
      then_blocked || else_blocked
    }
    TInstrKind::TBr(label, values) =>
      if fl_label_targets_uid(state, label, target_uid) {
        if values.length() != 1 {
          true
        } else {
          scan_state.rewritable_targeting_branches.val = scan_state.rewritable_targeting_branches.val +
            1
          false
        }
      } else {
        false
      }
    TInstrKind::TBrIf(label, _, values) =>
      if fl_label_targets_uid(state, label, target_uid) {
        if values.length() != 1 {
          true
        } else {
          scan_state.rewritable_targeting_branches.val = scan_state.rewritable_targeting_branches.val +
            1
          false
        }
      } else {
        false
      }
    TInstrKind::TBrOnNull(label, _, values) =>
      if fl_label_targets_uid(state, label, target_uid) {
        if values.length() != 1 ||
          fl_branch_fallthrough_type(instr, state.env) == None {
          true
        } else {
          scan_state.rewritable_targeting_branches.val = scan_state.rewritable_targeting_branches.val +
            1
          false
        }
      } else {
        false
      }
    TInstrKind::TBrOnNonNull(label, _, values) =>
      if fl_label_targets_uid(state, label, target_uid) {
        if values.length() != 1 {
          true
        } else {
          scan_state.rewritable_targeting_branches.val = scan_state.rewritable_targeting_branches.val +
            1
          false
        }
      } else {
        false
      }
    TInstrKind::TBrOnCast(label, _, _, _, _, values) =>
      if fl_label_targets_uid(state, label, target_uid) {
        if values.length() != 1 ||
          fl_branch_fallthrough_type(instr, state.env) == None {
          true
        } else {
          scan_state.rewritable_targeting_branches.val = scan_state.rewritable_targeting_branches.val +
            1
          false
        }
      } else {
        false
      }
    TInstrKind::TBrOnCastFail(label, _, _, _, _, values) =>
      if fl_label_targets_uid(state, label, target_uid) {
        if values.length() != 1 ||
          fl_branch_fallthrough_type(instr, state.env) == None {
          true
        } else {
          scan_state.rewritable_targeting_branches.val = scan_state.rewritable_targeting_branches.val +
            1
          false
        }
      } else {
        false
      }
    TInstrKind::TBrTable(labels, default_label, _, _) =>
      fl_br_table_targets_uid(state, labels, default_label, target_uid)
    _ => {
      let children = eval_children(instr)
      for child in children {
        if fl_has_unsupported_targeting_branch_in_instr_scan(
            child,
            state,
            target_uid,
            scan_state,
            depth + 1,
          ) {
          return true
        }
      }
      false
    }
  }
}

///|
fn fl_has_unsupported_targeting_branch_in_texpr_scan(
  body : TExpr,
  state : FLFuncState,
  target_uid : Int,
  scan_state : FLUnsupportedBranchScanState,
  depth : Int,
) -> Bool {
  fl_note_unsupported_branch_scan_expr_visit(scan_state, depth)
  for instr in body.instrs {
    if fl_has_unsupported_targeting_branch_in_instr_scan(
        instr,
        state,
        target_uid,
        scan_state,
        depth + 1,
      ) {
      return true
    }
  }
  false
}

///|
fn fl_scan_unsupported_targeting_branch_in_texpr(
  body : TExpr,
  state : FLFuncState,
  target_uid : Int,
) -> FLUnsupportedBranchScanSummary {
  let helper_start_ms = fl_trace_helper_start(
    state,
    "fl_has_unsupported_targeting_branch_in_texpr",
    "instrs=\{body.instrs.length()} target_uid=\{target_uid}",
  )
  let scan_state = FLUnsupportedBranchScanState::new(helper_start_ms)
  let blocked = fl_has_unsupported_targeting_branch_in_texpr_scan(
    body, state, target_uid, scan_state, 0,
  )
  fl_trace_helper_done(
    state,
    "fl_has_unsupported_targeting_branch_in_texpr",
    helper_start_ms,
    "blocked=\{blocked} target_uid=\{target_uid} rewritable_targeting_branches=\{scan_state.rewritable_targeting_branches.val} visited_exprs=\{scan_state.visited_exprs.val} visited_instrs=\{scan_state.visited_instrs.val} max_depth=\{scan_state.max_depth.val}",
  )
  {
    blocked,
    rewritable_targeting_branches: scan_state.rewritable_targeting_branches.val,
  }
}

///|
fn fl_branch_fallthrough_type(instr : TInstr, env : Env) -> ValType? {
  match instr.kind {
    TInstrKind::TBrIf(_, _, [value]) => fl_instr_type(value, env)
    TInstrKind::TBrOnNull(_, ref_, _) =>
      match fl_instr_type(ref_, env) {
        Some(RefTypeValType(rt)) =>
          Some(ValType::ref_type(RefType::new(false, rt.get_heap_type())))
        _ => None
      }
    TInstrKind::TBrOnCast(_, castop, ht1, ht2, _, _) => {
      let CastOp(nullable1, nullable2) = castop
      match
        @validate.diff(
          RefType::new(nullable1, ht1),
          RefType::new(nullable2, ht2),
        ) {
        Ok(rt) => Some(ValType::ref_type(rt))
        Err(_) => None
      }
    }
    TInstrKind::TBrOnCastFail(_, castop, _, ht2, _, _) => {
      let CastOp(_, nullable2) = castop
      Some(ValType::ref_type(RefType::new(nullable2, ht2)))
    }
    _ => None
  }
}

///|
/// Rewrite a single branch-like node if it targets `target_uid` and has exactly one value.
///
/// IMPORTANT: the sequencing wrapper introduces a new innermost label, so rewritten
/// branches must target `label + 1` to preserve the original control destination.

///|
fn fl_rewrite_branch_node(
  instr : TInstr,
  state : FLFuncState,
  target_uid : Int,
  temp : LocalIdx,
) -> TInstr {
  match instr.kind {
    TInstrKind::TBr(label, values) =>
      if values.length() == 1 {
        match fl_resolve_label_uid(state, label) {
          Some(uid) if uid == target_uid => {
            let bumped = fl_bump_label(label, 1)
            fl_trace_helper_event(
              state,
              "fl_rewrite_branch_node",
              "rewrite",
              "kind=br label=\{label} target_uid=\{target_uid}",
            )
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::local_set(temp, values[0]),
                TInstr::br(bumped, []),
              ]),
            )
          }
          _ => instr
        }
      } else {
        instr
      }
    TInstrKind::TBrIf(label, cond, values) =>
      if values.length() == 1 {
        match fl_resolve_label_uid(state, label) {
          Some(uid) if uid == target_uid => {
            let bumped = fl_bump_label(label, 1)
            match fl_instr_type(values[0], state.env) {
              Some(vt) => {
                fl_trace_helper_event(
                  state,
                  "fl_rewrite_branch_node",
                  "rewrite",
                  "kind=br_if label=\{label} target_uid=\{target_uid}",
                )
                TInstr::block(
                  BlockType::val_type(vt),
                  TExpr::new([
                    TInstr::local_set(temp, values[0]),
                    TInstr::br_if(bumped, cond, []),
                    TInstr::local_get(temp),
                  ]),
                )
              }
              None => instr
            }
          }
          _ => instr
        }
      } else {
        instr
      }
    TInstrKind::TBrOnNull(label, ref_, values) =>
      if values.length() == 1 {
        match fl_resolve_label_uid(state, label) {
          Some(uid) if uid == target_uid => {
            let bumped = fl_bump_label(label, 1)
            match fl_branch_fallthrough_type(instr, state.env) {
              Some(vt) => {
                fl_trace_helper_event(
                  state,
                  "fl_rewrite_branch_node",
                  "rewrite",
                  "kind=br_on_null label=\{label} target_uid=\{target_uid}",
                )
                TInstr::block(
                  BlockType::val_type(vt),
                  TExpr::new([
                    TInstr::local_set(temp, values[0]),
                    TInstr::br_on_null(bumped, ref_, []),
                  ]),
                )
              }
              None => instr
            }
          }
          _ => instr
        }
      } else {
        instr
      }
    TInstrKind::TBrOnNonNull(label, ref_, values) =>
      if values.length() == 1 {
        match fl_resolve_label_uid(state, label) {
          Some(uid) if uid == target_uid => {
            let bumped = fl_bump_label(label, 1)
            fl_trace_helper_event(
              state,
              "fl_rewrite_branch_node",
              "rewrite",
              "kind=br_on_non_null label=\{label} target_uid=\{target_uid}",
            )
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::local_set(temp, values[0]),
                TInstr::br_on_non_null(bumped, ref_, []),
              ]),
            )
          }
          _ => instr
        }
      } else {
        instr
      }
    TInstrKind::TBrOnCast(label, castop, ht1, ht2, ref_, values) =>
      if values.length() == 1 {
        match fl_resolve_label_uid(state, label) {
          Some(uid) if uid == target_uid => {
            let bumped = fl_bump_label(label, 1)
            match fl_branch_fallthrough_type(instr, state.env) {
              Some(vt) => {
                fl_trace_helper_event(
                  state,
                  "fl_rewrite_branch_node",
                  "rewrite",
                  "kind=br_on_cast label=\{label} target_uid=\{target_uid}",
                )
                TInstr::block(
                  BlockType::val_type(vt),
                  TExpr::new([
                    TInstr::local_set(temp, values[0]),
                    TInstr::br_on_cast(
                      bumped,
                      castop.0,
                      ht1,
                      castop.1,
                      ht2,
                      ref_,
                      [],
                    ),
                  ]),
                )
              }
              None => instr
            }
          }
          _ => instr
        }
      } else {
        instr
      }
    TInstrKind::TBrOnCastFail(label, castop, ht1, ht2, ref_, values) =>
      if values.length() == 1 {
        match fl_resolve_label_uid(state, label) {
          Some(uid) if uid == target_uid => {
            let bumped = fl_bump_label(label, 1)
            match fl_branch_fallthrough_type(instr, state.env) {
              Some(vt) => {
                fl_trace_helper_event(
                  state,
                  "fl_rewrite_branch_node",
                  "rewrite",
                  "kind=br_on_cast_fail label=\{label} target_uid=\{target_uid}",
                )
                TInstr::block(
                  BlockType::val_type(vt),
                  TExpr::new([
                    TInstr::local_set(temp, values[0]),
                    TInstr::br_on_cast_fail(
                      bumped,
                      castop.0,
                      ht1,
                      castop.1,
                      ht2,
                      ref_,
                      [],
                    ),
                  ]),
                )
              }
              None => instr
            }
          }
          _ => instr
        }
      } else {
        instr
      }
    _ => instr
  }
}

///|
test "flatten supports br_on family instructions and keeps them present" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [ValType::funcref()],
        TExpr::new([
          TInstr::drop(
            TInstr::br_on_null(
              LabelIdx::new(0),
              TInstr::local_get(LocalIdx::new(0)),
              [],
            ),
          ),
          TInstr::drop(
            TInstr::br_on_non_null(
              LabelIdx::new(0),
              TInstr::local_get(LocalIdx::new(0)),
              [],
            ),
          ),
          TInstr::drop(
            TInstr::br_on_cast(
              LabelIdx::new(0),
              true,
              HeapType::abs(AbsHeapType::func()),
              false,
              HeapType::abs(AbsHeapType::func()),
              TInstr::local_get(LocalIdx::new(0)),
              [],
            ),
          ),
          TInstr::drop(
            TInstr::br_on_cast_fail(
              LabelIdx::new(0),
              true,
              HeapType::abs(AbsHeapType::func()),
              false,
              HeapType::abs(AbsHeapType::func()),
              TInstr::local_get(LocalIdx::new(0)),
              [],
            ),
          ),
        ]),
      ),
    ]),
  )
  let out = run_flatten(mod).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) =>
      assert_eq(fl_count_br_on_family(body), 4)
    _ => fail("expected flattened function with br_on family instructions")
  }
}

///|
test "flatten keeps br_on value flow in value position" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [ValType::funcref()],
        TExpr::new([
          TInstr::drop(
            TInstr::br_on_null(
              LabelIdx::new(0),
              TInstr::local_get(LocalIdx::new(0)),
              [TInstr::i32_const(I32(17))],
            ),
          ),
        ]),
      ),
    ]),
  )
  let out = run_flatten(mod).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) => {
      let saw_const_value = Ref::new(false)
      let saw_set_of_const = Ref::new(false)
      let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
          self,
          _,
          instr : TInstr,
        ) {
          match instr.kind {
            TInstrKind::TBrOnNull(
              _,
              _,
              [{ kind: TInstrKind::TI32Const(I32(v)), .. }]
            ) if v == 17 => saw_const_value.update(fn(_) { true })
            TInstrKind::TLocalSet(
              _,
              { kind: TInstrKind::TI32Const(I32(v)), .. }
            ) if v == 17 => saw_set_of_const.update(fn(_) { true })
            _ => ()
          }
          from_walk(self.walk_tinstruction_default((), instr))
        },
      )
      ignore(walker.walk_texpr((), body))
      assert_true(saw_const_value.val)
      assert_true(!saw_set_of_const.val)
    }
    _ => fail("expected flattened br_on_null output")
  }
}

///|
test "flatten preserves carried values for br_on variants in value position" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [ValType::funcref()],
        TExpr::new([
          TInstr::drop(
            TInstr::br_on_null(
              LabelIdx::new(0),
              TInstr::local_get(LocalIdx::new(0)),
              [TInstr::i32_const(I32(1))],
            ),
          ),
          TInstr::drop(
            TInstr::br_on_non_null(
              LabelIdx::new(0),
              TInstr::local_get(LocalIdx::new(0)),
              [TInstr::i32_const(I32(2))],
            ),
          ),
          TInstr::drop(
            TInstr::br_on_cast(
              LabelIdx::new(0),
              true,
              HeapType::abs(AbsHeapType::func()),
              false,
              HeapType::abs(AbsHeapType::func()),
              TInstr::local_get(LocalIdx::new(0)),
              [TInstr::i32_const(I32(3))],
            ),
          ),
          TInstr::drop(
            TInstr::br_on_cast_fail(
              LabelIdx::new(0),
              true,
              HeapType::abs(AbsHeapType::func()),
              false,
              HeapType::abs(AbsHeapType::func()),
              TInstr::local_get(LocalIdx::new(0)),
              [TInstr::i32_const(I32(4))],
            ),
          ),
        ]),
      ),
    ]),
  )
  let out = run_flatten(mod).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) => {
      let carried_const_count = Ref::new(0)
      let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
          self,
          _,
          instr : TInstr,
        ) {
          match instr.kind {
            TInstrKind::TBrOnNull(
              _,
              _,
              [{ kind: TInstrKind::TI32Const(I32(_)), .. }]
            )
            | TInstrKind::TBrOnNonNull(
              _,
              _,
              [{ kind: TInstrKind::TI32Const(I32(_)), .. }]
            )
            | TInstrKind::TBrOnCast(
              _,
              _,
              _,
              _,
              _,
              [{ kind: TInstrKind::TI32Const(I32(_)), .. }]
            )
            | TInstrKind::TBrOnCastFail(
              _,
              _,
              _,
              _,
              _,
              [{ kind: TInstrKind::TI32Const(I32(_)), .. }]
            ) => carried_const_count.update(fn(v) { v + 1 })
            _ => ()
          }
          from_walk(self.walk_tinstruction_default((), instr))
        },
      )
      ignore(walker.walk_texpr((), body))
      assert_eq(carried_const_count.val, 4)
    }
    _ => fail("expected flattened br_on family output")
  }
}

///|
test "flatten preserves try_table value result in value position" {
  let mod = Module::new().with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        [],
        TExpr::new([
          TInstr::drop(
            TInstr::try_table(
              BlockType::val_type(ValType::i32()),
              [Catch::all(LabelIdx::new(0))],
              TExpr::new([TInstr::i32_const(I32(12))]),
            ),
          ),
        ]),
      ),
    ]),
  )
  let out = run_flatten(mod).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) =>
      match fl_find_try_table_result_blocktype(body) {
        Some(ValTypeBlockType(NumTypeValType(I32NumType))) => ()
        Some(_) => fail("expected flattened try_table to keep i32 blocktype")
        None => fail("expected try_table to remain present after flatten")
      }
    _ => fail("expected flattened try_table output")
  }
}

///|
test "flatten output with br_on_null and try_table remains valid and idempotent" {
  let target_sig = RecType::new(SubType::comp_type(CompType::func([], [])))
  let nullable_target_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let main_sig = RecType::new(
    SubType::comp_type(CompType::func([nullable_target_ref], [])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([target_sig, main_sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [nullable_target_ref],
          [],
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::drop(
                  TInstr::br_on_null(
                    LabelIdx::new(0),
                    TInstr::local_get(LocalIdx::new(0)),
                    [],
                  ),
                ),
              ]),
            ),
            TInstr::drop(
              TInstr::try_table(
                BlockType::val_type(ValType::i32()),
                [],
                TExpr::new([TInstr::i32_const(I32(12))]),
              ),
            ),
          ]),
        ),
      ]),
    )
  let once = run_flatten(mod).unwrap()
  let twice = run_flatten(once).unwrap()
  assert_eq(once, twice)
  match validate_module(once) {
    Ok(_) => ()
    Err(e) =>
      fail("expected flattened br_on_null + try_table module to validate: \{e}")
  }
}

///|
fn fl_mk_valid_one_func_module(
  params : Array[ValType],
  results : Array[ValType],
  locals : Array[ValType],
  body : TExpr,
) -> Module {
  // Create a single rec type containing a single func type.
  // This matches the style you already use in the last test.
  let sig = RecType::new(SubType::comp_type(CompType::func(params, results)))

  Module::new()
  .with_type_sec(TypeSec::new([sig]))
  .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  .with_code_sec(CodeSec::new([Func::t_func(params, locals, body)]))
}

///|
test "flatten: block result produced by br value remains valid" {
  let mod = fl_mk_valid_one_func_module(
    [], // params
    [], // results
    [], // locals
    TExpr::new([
      TInstr::drop(
        TInstr::block(
          BlockType::val_type(ValType::i32()),
          TExpr::new([
            TInstr::br(LabelIdx::new(0), [TInstr::i32_const(I32(7))]),
            TInstr::i32_const(I32(0)), // unreachable
          ]),
        ),
      ),
    ]),
  )

  let out = run_flatten(mod).unwrap()
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected flatten to preserve validity for block result via br; got validation error: \{e}",
      )
  }
}

///|
test "flatten: nested block br value remains valid" {
  let mod = fl_mk_valid_one_func_module(
    [],
    [],
    [],
    TExpr::new([
      TInstr::drop(
        TInstr::block(
          BlockType::val_type(ValType::i32()),
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::br(LabelIdx::new(1), [TInstr::i32_const(I32(42))]),
              ]),
            ),
            TInstr::i32_const(I32(0)), // unreachable
          ]),
        ),
      ),
    ]),
  )

  let out = run_flatten(mod).unwrap()
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected flatten to preserve validity for nested br-to-outer-block-with-value; got: \{e}",
      )
  }
}

///|
test "flatten: idempotent on atomic local.get" {
  let mod = fl_mk_valid_one_func_module(
    [ValType::i32()], // params
    [], // results
    [], // locals
    TExpr::new([TInstr::drop(TInstr::local_get(LocalIdx::new(0)))]),
  )

  let once = run_flatten(mod).unwrap()
  let twice = run_flatten(once).unwrap()
  assert_eq(once, twice)

  match validate_module(twice) {
    Ok(_) => ()
    Err(e) => fail("expected flattened module to validate: \{e}")
  }
}

///|
test "flatten: result block with br inside if remains valid" {
  let mod = fl_mk_valid_one_func_module(
    [ValType::i32()], // params
    [],
    [],
    TExpr::new([
      TInstr::drop(
        TInstr::block(
          BlockType::val_type(ValType::i32()),
          TExpr::new([
            TInstr::if_(
              BlockType::void_(),
              TInstr::local_get(LocalIdx::new(0)),
              TExpr::new([
                TInstr::br(LabelIdx::new(1), [TInstr::i32_const(I32(9))]),
              ]),
              Some(TExpr::new([TInstr::nop()])),
            ),
            TInstr::i32_const(I32(0)),
          ]),
        ),
      ),
    ]),
  )

  let out = run_flatten(mod).unwrap()
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected flatten to preserve validity for br-with-value inside if to outer result block; got: \{e}",
      )
  }
}

///|
test "flatten: dropped br_if targeting result block remains valid" {
  let mod = fl_mk_valid_one_func_module(
    [ValType::i32()],
    [],
    [],
    TExpr::new([
      TInstr::drop(
        TInstr::block(
          BlockType::val_type(ValType::i32()),
          TExpr::new([
            TInstr::drop(
              TInstr::br_if(
                LabelIdx::new(0),
                TInstr::local_get(LocalIdx::new(0)),
                [TInstr::i32_const(I32(7))],
              ),
            ),
            TInstr::i32_const(I32(0)),
          ]),
        ),
      ),
    ]),
  )

  let out = run_flatten(mod).unwrap()
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected flatten to preserve validity for dropped br_if targeting a result block; got: \{e}",
      )
  }
}

///|
test "flatten: br_on_null targeting result block remains valid" {
  let target_sig = RecType::new(SubType::comp_type(CompType::func([], [])))
  let nullable_target_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let main_sig = RecType::new(
    SubType::comp_type(CompType::func([nullable_target_ref], [ValType::i32()])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([target_sig, main_sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [nullable_target_ref],
          [],
          TExpr::new([
            TInstr::block(
              BlockType::val_type(ValType::i32()),
              TExpr::new([
                TInstr::drop(
                  TInstr::br_on_null(
                    LabelIdx::new(0),
                    TInstr::local_get(LocalIdx::new(0)),
                    [TInstr::i32_const(I32(7))],
                  ),
                ),
                TInstr::i32_const(I32(0)),
              ]),
            ),
          ]),
        ),
      ]),
    )

  let out = run_flatten(mod).unwrap()
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected flatten to preserve validity for br_on_null targeting a result block; got: \{e}",
      )
  }
}

///|
test "flatten: br_table value targeting result block remains valid" {
  let mod = fl_mk_valid_one_func_module(
    [],
    [],
    [],
    TExpr::new([
      TInstr::drop(
        TInstr::block(
          BlockType::val_type(ValType::i32()),
          TExpr::new([
            TInstr::br_table([], LabelIdx::new(0), TInstr::i32_const(I32(0)), [
              TInstr::i32_const(I32(7)),
            ]),
            TInstr::i32_const(I32(0)),
          ]),
        ),
      ),
    ]),
  )

  let out = run_flatten(mod).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, _, body)])) => {
      let saw_value_block = Ref::new(false)
      let walker : ModuleTransformer[Unit, Unit] = ModuleTransformer::new().on_tinstruction_evt(fn(
          self,
          _,
          instr : TInstr,
        ) {
          match instr.kind {
            TInstrKind::TBlock(ValTypeBlockType(NumTypeValType(I32NumType)), _) =>
              saw_value_block.update(fn(_) { true })
            _ => ()
          }
          from_walk(self.walk_tinstruction_default((), instr))
        },
      )
      ignore(walker.walk_texpr((), body))
      assert_true(saw_value_block.val)
    }
    _ => fail("expected flattened function output")
  }
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected flatten to preserve validity for br_table targeting a result block; got: \{e}",
      )
  }
}

///|
test "flatten: br_on_non_null targeting ref result block remains valid" {
  let target_sig = RecType::new(SubType::comp_type(CompType::func([], [])))
  let nullable_target_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let non_null_target_ref = ValType::ref_type(
    RefType::new(false, HeapType::new(TypeIdx::new(0))),
  )
  let main_sig = RecType::new(
    SubType::comp_type(CompType::func([nullable_target_ref], [])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([target_sig, main_sig]))
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [nullable_target_ref],
          [],
          TExpr::new([
            TInstr::drop(
              TInstr::block(
                BlockType::val_type(non_null_target_ref),
                TExpr::new([
                  TInstr::br_on_non_null(
                    LabelIdx::new(0),
                    TInstr::local_get(LocalIdx::new(0)),
                    [],
                  ),
                  TInstr::unreachable_(),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    )

  let out = run_flatten(mod).unwrap()
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected flatten to preserve validity for br_on_non_null targeting a ref result block; got: \{e}",
      )
  }
}

///|
test "flatten trace includes helper scan counters in done log" {
  let mod = fl_mk_valid_one_func_module(
    [],
    [ValType::i32()],
    [],
    TExpr::new([
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::drop(TInstr::i32_const(I32(1))),
          TInstr::drop(TInstr::i32_const(I32(2))),
          TInstr::i32_const(I32(0)),
        ]),
      ),
    ]),
  )
  let trace_logs : Array[String] = []
  match
    run_flatten_with_trace(
      mod,
      trace=fn(msg) { trace_logs.push(msg) },
      trace_all_funcs=true,
    ) {
    Ok(_) => ()
    Err(e) => fail("unexpected flatten trace error: \{e}")
  }
  let saw_done_with_scan_counts = trace_logs.any(fn(msg) {
    msg.contains(
      "helper=fl_has_unsupported_targeting_branch_in_texpr step=done",
    ) &&
    msg.contains("visited_exprs=") &&
    msg.contains("visited_instrs=") &&
    msg.contains("max_depth=")
  })
  assert_true(saw_done_with_scan_counts)
}

///|
test "flatten trace includes rewrite helper scan counters in done log" {
  let mod = fl_mk_valid_one_func_module(
    [],
    [ValType::i32()],
    [],
    TExpr::new([
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::drop(TInstr::i32_const(I32(1))),
          TInstr::br(LabelIdx::new(0), [TInstr::i32_const(I32(2))]),
          TInstr::drop(TInstr::i32_const(I32(2))),
          TInstr::i32_const(I32(0)),
        ]),
      ),
    ]),
  )
  let trace_logs : Array[String] = []
  match
    run_flatten_with_trace(
      mod,
      trace=fn(msg) { trace_logs.push(msg) },
      trace_all_funcs=true,
    ) {
    Ok(_) => ()
    Err(e) => fail("unexpected flatten trace error: \{e}")
  }
  let saw_done_with_scan_counts = trace_logs.any(fn(msg) {
    msg.contains("helper=fl_rewrite_label_value_flow_in_texpr step=done") &&
    msg.contains("visited_exprs=") &&
    msg.contains("visited_instrs=") &&
    msg.contains("max_depth=")
  })
  assert_true(saw_done_with_scan_counts)
}

///|
test "flatten skips rewrite helper when result label has no targeting branch values" {
  let mod = fl_mk_valid_one_func_module(
    [],
    [ValType::i32()],
    [],
    TExpr::new([
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::drop(TInstr::i32_const(I32(1))),
          TInstr::i32_const(I32(0)),
        ]),
      ),
    ]),
  )
  let trace_logs : Array[String] = []
  match
    run_flatten_with_trace(
      mod,
      trace=fn(msg) { trace_logs.push(msg) },
      trace_all_funcs=true,
    ) {
    Ok(_) => ()
    Err(e) => fail("unexpected flatten trace error: \{e}")
  }
  let saw_rewrite_helper_start = trace_logs.any(fn(msg) {
    msg.contains("helper=fl_rewrite_label_value_flow_in_texpr step=start")
  })
  assert_false(saw_rewrite_helper_start)
}
