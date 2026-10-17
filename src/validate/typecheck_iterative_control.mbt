// Copyright 2026 Joshua Tenner. Original Starshine code; see ../../LICENSE.

///|
// Each suspended expression retains its own local-initialization COW owner.
// Frames borrow instruction arrays and preserve the stack aliases used by the
// existing control entry/finish helpers. EH still uses its existing dispatcher.
priv struct TcExprFrame {
  instrs : Array[Instruction]
  mut index : Int32
  mut state : TcState
  mut owner : TcInitializationOwner?
  context : Bool
}

///|
priv enum TcExprContinuation {
  BlockFrame(TcExprFrame, TcState, Array[ValType])
  LoopFrame(TcExprFrame, TcState, Array[ValType])
  IfThenFrame(
    TcExprFrame,
    TcState,
    Array[ValType],
    Array[ValType],
    Array[Instruction]
  )
  IfElseFrame(TcExprFrame, TcState, TcState, Array[ValType])
}

///|
fn tc_expr_frame(
  xs : Array[Instruction],
  st : TcState,
  context : Bool,
) -> TcExprFrame {
  { instrs: xs, index: 0, state: st, owner: None, context, }
}

///|
fn tc_expr_child(
  entry : TcState,
  params : Array[ValType],
  labels : Array[ValType],
  xs : Array[Instruction],
) -> TcExprFrame {
  tc_expr_frame(
    xs,
    TcState::{
      env: entry.env.with_label(labels),
      stack: tc_stack_from_types(params),
      reachable: entry.reachable,
      polymorphic: false,
      escape: NoTcEscape,
      reachable_escape_depths: [],
      initialized_locals: tc_fork_initialized_for_body(
        entry.initialized_locals,
        xs,
      ),
    },
    true,
  )
}

///|
// Keep ordinary diagnostics byte-for-byte. Deep control trees cannot safely use
// recursive Instruction::Show; retain the control kind, block type and exact
// instruction location, with an explicit bounded-rendering marker instead.
fn tc_expr_instruction_context(ins : Instruction) -> String {
  let pending : Array[(Instruction, Int32)] = [(ins, 0)]
  let mut nodes = 0
  let mut bounded = true
  while pending.length() > 0 {
    let (item, depth) = pending.pop().unwrap()
    nodes += 1
    if depth > 32 || nodes > 256 {
      bounded = false
      break
    }
    match item {
      Block(_, Expr(xs)) | Loop(_, Expr(xs)) => {
        if xs.length() > 256 - nodes - pending.length() {
          bounded = false
          break
        }
        for x in xs {
          pending.push((x, depth + 1))
        }
      }
      If(_, left, right) => {
        let right = right.unwrap_or([])
        if left.length() + right.length() > 256 - nodes - pending.length() {
          bounded = false
          break
        }
        for x in left {
          pending.push((x, depth + 1))
        }
        for x in right {
          pending.push((x, depth + 1))
        }
      }
      Try(_, Expr(xs), catches, _) => {
        if xs.length() > 256 - nodes - pending.length() {
          bounded = false
          break
        }
        for x in xs {
          pending.push((x, depth + 1))
        }
        for catch_ in catches {
          let child = match catch_ {
            LegacyCatch(_, Expr(child)) | LegacyCatchAll(Expr(child)) => child
          }
          if child.length() > 256 - nodes - pending.length() {
            bounded = false
            break
          }
          for x in child {
            pending.push((x, depth + 1))
          }
        }
        if !bounded {
          break
        }
      }
      TryTable(_, _, Expr(xs)) => {
        if xs.length() > 256 - nodes - pending.length() {
          bounded = false
          break
        }
        for x in xs {
          pending.push((x, depth + 1))
        }
      }
      _ => ()
    }
  }
  if bounded {
    return "\{ins}"
  }
  match ins {
    Block(bt, _) => "Block(\{bt}, <bounded control diagnostic>)"
    Loop(bt, _) => "Loop(\{bt}, <bounded control diagnostic>)"
    If(bt, _, _) => "If(\{bt}, <bounded control diagnostic>)"
    Try(bt, _, _, _) => "Try(\{bt}, <bounded control diagnostic>)"
    TryTable(bt, _, _) => "TryTable(\{bt}, <bounded control diagnostic>)"
    _ => "\{ins}"
  }
}

///|
fn tc_expr_wrap_error(frame : TcExprFrame, reason : String) -> String {
  if !frame.context {
    return reason
  }
  let ins = tc_expr_instruction_context(frame.instrs[frame.index])
  "instruction[\{frame.index}] \{ins}: \{reason}; stack=\{frame.state.stack}"
}

///|
fn tc_expr_error(
  frame : TcExprFrame,
  pending : Array[TcExprContinuation],
  reason : String,
) -> TcResult {
  let mut error = tc_expr_wrap_error(frame, reason)
  while pending.length() > 0 {
    let parent = match pending.pop().unwrap() {
      BlockFrame(p, _, _)
      | LoopFrame(p, _, _)
      | IfThenFrame(p, _, _, _, _)
      | IfElseFrame(p, _, _, _) => p
    }
    error = tc_expr_wrap_error(parent, error)
  }
  Err(error)
}

///|
fn tc_iterative_expr(expr : Expr, state : TcState, context : Bool) -> TcResult {
  let mut frame = tc_expr_frame(expr.0, state, context)
  let pending : Array[TcExprContinuation] = []
  while true {
    if frame.index == frame.instrs.length() {
      if pending.is_empty() {
        return Ok(frame.state)
      }
      let child = frame.state
      let continuation = pending.pop().unwrap()
      let (parent, finished) = match continuation {
        BlockFrame(parent, entry, results) =>
          (parent, tc_state_finish_block(parent.state, entry, child, results))
        LoopFrame(parent, entry, results) =>
          (parent, tc_state_finish_loop(parent.state, entry, child, results))
        IfThenFrame(parent, entry, params, results, right) => {
          // Check else instructions before normalizing either arm's end stack,
          // matching the existing if error precedence and entry-mask ownership.
          pending.push(IfElseFrame(parent, entry, child, results))
          frame = tc_expr_child(entry, params, results, right)
          continue
        }
        IfElseFrame(parent, entry, left, results) =>
          (
            parent,
            tc_state_finish_if(parent.state, entry, left, child, results),
          )
      }
      match finished {
        Err(error) => return tc_expr_error(parent, pending, error)
        Ok(out) => {
          parent.state = out
          parent.index += 1
          frame = parent
          continue
        }
      }
    }
    let ins = frame.instrs[frame.index]
    match ins {
      Block(bt, Expr(xs)) | Loop(bt, Expr(xs)) | If(bt, xs, _) => {
        let (params, results) = match frame.state.env.expand_blocktype(bt) {
          Err(error) => return tc_expr_error(frame, pending, error)
          Ok(x) => x
        }
        let condition = match ins {
          If(_, _, _) => frame.state.pop_expect(ValType::i32())
          _ => Ok(frame.state)
        }
        let entry = match condition {
          Err(error) => return tc_expr_error(frame, pending, error)
          Ok(st) =>
            match st.pop_types(params) {
              Err(error) => return tc_expr_error(frame, pending, error)
              Ok(entry) => entry
            }
        }
        let labels = match ins {
          Loop(_, _) => params
          _ => results
        }
        let child = tc_expr_child(entry, params, labels, xs)
        pending.push(
          match ins {
            Block(_, _) => BlockFrame(frame, entry, results)
            Loop(_, _) => LoopFrame(frame, entry, results)
            If(_, _, right) =>
              IfThenFrame(frame, entry, params, results, right.unwrap_or([]))
            _ => abort("control frame invariant")
          },
        )
        frame = child
        continue
      }
      _ => ()
    }
    let checked = match ins {
      LocalGet(idx) =>
        match typecheck_local_get_error(frame.state, idx) {
          None => {
            frame.index += 1
            continue
          }
          Some(error) => Err(error)
        }
      LocalSet(idx) | LocalTee(idx) => {
        let LocalIdx(raw) = idx
        let local_id = raw.reinterpret_as_int()
        if frame.owner is None &&
          local_id >= 0 &&
          local_id < frame.state.initialized_locals.length() &&
          !frame.state.initialized_locals[local_id] {
          frame.owner = Some(TcInitializationOwner::new())
        }
        let initialization_owner = frame.owner
        match ins {
          LocalSet(_) =>
            typecheck_local_set(frame.state, idx, initialization_owner~)
          _ => typecheck_local_tee(frame.state, idx, initialization_owner~)
        }
      }
      _ => Typecheck::typecheck(ins, frame.state)
    }
    match checked {
      Ok(out) => {
        frame.state = out
        frame.index += 1
      }
      Err(error) => return tc_expr_error(frame, pending, error)
    }
  } nobreak {
    abort("expression traversal invariant")
  }
}
