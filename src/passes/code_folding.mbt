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
/// Code Folding Pass
///
/// Folds duplicate code together, saving space (and possibly phis in
/// the wasm VM, which can save time).
///
/// We fold tails of code where they merge and moving the code
/// to the merge point is helpful. There are two cases here:
/// (1) expressions, in which we merge to right after the expression itself:
///   * blocks: we merge the fallthrough + the breaks
///   * if-else: we merge the arms
/// (2) the function body as a whole, in which we can merge returns or
///     unreachables, putting the merged code at the end of the function body.
///
/// For example, with an if-else, we might merge this:
///   (if (condition)
///     (block A C)
///     (block B C)
///   )
/// to:
///   (if (condition)
///     (block A)
///     (block B)
///   )
///   C

///|
const WORTH_ADDING_BLOCK_TO_REMOVE_THIS_MUCH : Int = 3

///|
/// Minimum savings required before we add overhead for terminating tails
const MIN_TERMINATING_TAIL_SAVINGS : Int = 2

///|
/// Information about a "tail" - code that reaches a point that we can merge
struct Tail {
  instr : TInstr? // None if this is a fallthrough
  block_instrs : Array[TInstr] // the enclosing block of code we hope to merge at its tail
} derive(Eq)

///|
fn Tail::fallthrough(block_instrs : Array[TInstr]) -> Tail {
  Tail::{ instr: None, block_instrs }
}

///|
fn Tail::branch(instr : TInstr, block_instrs : Array[TInstr]) -> Tail {
  Tail::{ instr: Some(instr), block_instrs }
}

///|
fn Tail::is_fallthrough(self : Tail) -> Bool {
  self.instr is None
}

///|
/// State for the code folding pass
priv struct CodeFoldingState {
  mut another_pass : Bool
  break_tails : Map[LabelIdx, Array[Tail]]
  unreachable_tails : Array[Tail]
  return_tails : Array[Tail]
  unoptimizables : Set[LabelIdx]
  modifieds : Set[TInstr]
}

///|
fn CodeFoldingState::new() -> CodeFoldingState {
  CodeFoldingState::{
    another_pass: true,
    break_tails: Map::new(),
    unreachable_tails: [],
    return_tails: [],
    unoptimizables: Set::new(),
    modifieds: Set::new(),
  }
}

///|
fn CodeFoldingState::clear(self : CodeFoldingState) -> Unit {
  self.break_tails.clear()
  self.unreachable_tails.clear()
  self.return_tails.clear()
  self.unoptimizables.clear()
  self.modifieds.clear()
}

///|
/// Check if an instruction terminates control flow (unreachable or return)
fn is_terminating(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TUnreachable => true
    TInstrKind::TReturn(_) => true
    TInstrKind::TReturnCall(_, _) => true
    TInstrKind::TReturnCallIndirect(_, _, _, _) => true
    TInstrKind::TReturnCallRef(_, _, _) => true
    TInstrKind::TThrow(_, _) => true
    TInstrKind::TThrowRef(_) => true
    _ => false
  }
}

///|
/// Check if an instruction is a branch (br, br_if, br_table)
fn is_branch(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TBr(_, _) => true
    TInstrKind::TBrIf(_, _, _) => true
    TInstrKind::TBrTable(_, _, _, _) => true
    TInstrKind::TBrOnNull(_, _, _) => true
    TInstrKind::TBrOnNonNull(_, _, _) => true
    TInstrKind::TBrOnCast(_, _, _, _, _, _) => true
    TInstrKind::TBrOnCastFail(_, _, _, _, _, _) => true
    _ => false
  }
}

///|
/// Measure the size/cost of a TInstr for optimization decisions
fn measure(instr : TInstr) -> Int {
  // Simple heuristic: count 1 for each instruction node
  // This is a simplified version of Binaryen's Measurer
  let mut count = 1
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, c, i) {
    count += 1
    self.walk_tinstruction_default(c, i)
  })
  ignore(walker.walk_tinstruction((), instr))
  count
}

///|
/// Measure total size of an array of instructions
fn measure_all(instrs : Array[TInstr]) -> Int {
  let mut total = 0
  for instr in instrs {
    total += measure(instr)
  }
  total
}

///|
/// Get all branch targets (labels) that appear in an instruction
fn get_branch_targets(instr : TInstr) -> Set[LabelIdx] {
  let targets = Set::new()
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, i) {
    match i.kind {
      TInstrKind::TBr(label, _) => targets.add(label)
      TInstrKind::TBrIf(label, _, _) => targets.add(label)
      TInstrKind::TBrTable(labels, default, _, _) => {
        for label in labels {
          targets.add(label)
        }
        targets.add(default)
      }
      TInstrKind::TBrOnNull(label, _, _) => targets.add(label)
      TInstrKind::TBrOnNonNull(label, _, _) => targets.add(label)
      TInstrKind::TBrOnCast(label, _, _, _, _, _) => targets.add(label)
      TInstrKind::TBrOnCastFail(label, _, _, _, _, _) => targets.add(label)
      _ => ()
    }
    self.walk_tinstruction_default((), i)
  })
  ignore(walker.walk_tinstruction((), instr))
  targets
}

///|
/// Get branch targets that exit the given instruction (branch to outside)
fn get_exiting_branches(instr : TInstr) -> Set[LabelIdx] {
  // For simplicity, we collect all branch targets
  // A more sophisticated implementation would track scope
  get_branch_targets(instr)
}

///|
/// Check if we can move items out of a container
/// We can't do so if one of the items has a branch to something inside the container
fn can_move(items : Array[TInstr], container : TInstr) -> Bool {
  let all_targets = get_branch_targets(container)
  for item in items {
    let exiting = get_exiting_branches(item)
    // Check if there's any intersection
    for target in exiting.iter() {
      if all_targets.contains(target) {
        return false
      }
    }
  }
  true
}

///|
/// Get the mergeable item from a tail at a given depth
fn get_mergeable(tail : Tail, num : Int) -> TInstr? {
  if not(tail.is_fallthrough()) {
    // If there is a branch value, it is the first mergeable item
    match tail.instr {
      Some({ kind: TInstrKind::TBr(_, values), .. }) =>
        if values.length() > 0 && num == 0 {
          return Some(values[0])
        } else if values.is_empty() {
          // Skip the branch instruction at the end; it is not part of the merged tail
          let adjusted_num = num + 1
          if adjusted_num >= tail.block_instrs.length() {
            return None
          }
          return Some(
            tail.block_instrs[tail.block_instrs.length() - adjusted_num - 1],
          )
        }
      _ => ()
    }
  }
  if num >= tail.block_instrs.length() {
    return None
  }
  Some(tail.block_instrs[tail.block_instrs.length() - num - 1])
}

///|
/// Optimize expression tails (for blocks and if-else)
fn optimize_expression_tails(
  state : CodeFoldingState,
  tails : Array[Tail],
  curr : TInstr,
) -> TInstr? {
  if tails.length() < 2 {
    return None
  }

  // Check if anything is untoward
  for tail in tails {
    match tail.instr {
      Some(i) if state.modifieds.contains(i) => return None
      _ => ()
    }
  }

  // Find mergeable items
  let mergeable : Array[TInstr] = []
  let mut saved = 0
  let mut num = 0
  while true {
    match get_mergeable(tails[0], num) {
      None => break
      Some(item) => {
        // Check if all tails have matching items
        let mut all_match = true
        for i = 1; i < tails.length(); i = i + 1 {
          match get_mergeable(tails[i], num) {
            None => {
              all_match = false
              break
            }
            Some(other) =>
              if item != other {
                all_match = false
                break
              }
          }
        }
        if not(all_match) {
          break
        }

        // Check if we can move it
        if not(can_move([item], curr)) {
          break
        }

        // We found another one we can merge
        mergeable.push(item)
        saved += measure(item)
        num += 1
      }
    }
  }
  if saved == 0 {
    return None
  }

  // Check if it's worth it
  if saved < WORTH_ADDING_BLOCK_TO_REMOVE_THIS_MUCH {
    // See if we get rid of a block
    let mut will_empty_block = false
    for tail in tails {
      if mergeable.length() >= tail.block_instrs.length() - 1 {
        will_empty_block = true
        break
      }
    }
    if not(will_empty_block) {
      return None
    }
  }

  // Do the optimization - remove merged items from each tail
  state.another_pass = true
  let merge_count = mergeable.length()

  // Remove items from each tail's block
  for tail in tails {
    let block = tail.block_instrs
    // How many to remove from this block
    let to_remove = merge_count
    // Remove from the end
    let mut removed = 0
    while removed < to_remove && block.length() > 0 {
      ignore(block.pop())
      removed += 1
    }
    // Mark the tail's branch instruction as modified if present
    match tail.instr {
      Some(i) => state.modifieds.add(i)
      None => ()
    }
  }

  // Return the merged items in correct order (they were collected in reverse)
  // The caller will need to append these after the current instruction
  Some(mergeable[0]) // Return first merged item as indicator of change
}

///|
/// Optimize terminating tails (returns/unreachables) at function body level
/// This moves common code before return/unreachable instructions to the end of function
fn optimize_terminating_tails(
  state : CodeFoldingState,
  tails : Array[Tail],
  func_body : Array[TInstr],
) -> Array[TInstr]? {
  if tails.length() < 2 {
    return None
  }

  // Check if anything is modified
  for tail in tails {
    match tail.instr {
      Some(i) if state.modifieds.contains(i) => return None
      _ => ()
    }
  }

  // Find mergeable items from the tails
  let mergeable : Array[TInstr] = []
  let mut saved = 0
  let mut num = 0
  while true {
    match get_mergeable(tails[0], num) {
      None => break
      Some(item) => {
        // Check if all tails have matching items
        let mut all_match = true
        for i = 1; i < tails.length(); i = i + 1 {
          match get_mergeable(tails[i], num) {
            None => {
              all_match = false
              break
            }
            Some(other) =>
              if item != other {
                all_match = false
                break
              }
          }
        }
        if not(all_match) {
          break
        }

        // We found another one we can merge
        mergeable.push(item)
        saved += measure(item)
        num += 1
      }
    }
  }
  if saved < MIN_TERMINATING_TAIL_SAVINGS {
    return None
  }

  // Do the optimization
  state.another_pass = true
  let merge_count = mergeable.length()

  // Remove merged items from each tail
  for tail in tails {
    let block = tail.block_instrs
    let mut removed = 0
    while removed < merge_count && block.length() > 0 {
      ignore(block.pop())
      removed += 1
    }
    match tail.instr {
      Some(i) => state.modifieds.add(i)
      None => ()
    }
  }

  // Build new function body with merged items at the end
  // The merged items should go before a final return/unreachable
  let result : Array[TInstr] = []
  for instr in func_body {
    result.push(instr)
  }
  // Add merged items in reverse order (they were collected from end to start)
  let mut j = merge_count - 1
  while j >= 0 {
    result.push(mergeable[j])
    j -= 1
  }
  Some(result)
}

///|
/// Collect tails from a block's instructions
fn collect_block_tails(
  state : CodeFoldingState,
  instrs : Array[TInstr],
) -> Unit {
  for i = 0; i < instrs.length(); i = i + 1 {
    let instr = instrs[i]
    match instr.kind {
      // Unconditional branch at end of block
      TInstrKind::TBr(label, _) if i == instrs.length() - 1 => {
        let tails = state.break_tails.get(label).unwrap_or([])
        tails.push(Tail::branch(instr, instrs))
        state.break_tails.set(label, tails)
      }

      // Conditional branches are not optimizable
      TInstrKind::TBrIf(label, _, _) => state.unoptimizables.add(label)
      TInstrKind::TBrTable(labels, default, _, _) => {
        for label in labels {
          state.unoptimizables.add(label)
        }
        state.unoptimizables.add(default)
      }
      TInstrKind::TBrOnNull(label, _, _) => state.unoptimizables.add(label)
      TInstrKind::TBrOnNonNull(label, _, _) => state.unoptimizables.add(label)
      TInstrKind::TBrOnCast(label, _, _, _, _, _) =>
        state.unoptimizables.add(label)
      TInstrKind::TBrOnCastFail(label, _, _, _, _, _) =>
        state.unoptimizables.add(label)

      // Unreachable at end of block
      TInstrKind::TUnreachable if i == instrs.length() - 1 =>
        state.unreachable_tails.push(Tail::branch(instr, instrs))

      // Return at end of block
      TInstrKind::TReturn(_) if i == instrs.length() - 1 =>
        state.return_tails.push(Tail::branch(instr, instrs))

      // Return calls
      TInstrKind::TReturnCall(_, _) if i == instrs.length() - 1 =>
        state.return_tails.push(Tail::branch(instr, instrs))
      TInstrKind::TReturnCallIndirect(_, _, _, _) if i == instrs.length() - 1 =>
        state.return_tails.push(Tail::branch(instr, instrs))
      TInstrKind::TReturnCallRef(_, _, _) if i == instrs.length() - 1 =>
        state.return_tails.push(Tail::branch(instr, instrs))

      // Recursively process nested blocks
      TInstrKind::TBlock(_, body) => collect_block_tails(state, body.instrs)
      TInstrKind::TLoop(_, body) => collect_block_tails(state, body.instrs)
      TInstrKind::TIf(_, _, then_body, else_body) => {
        collect_block_tails(state, then_body.instrs)
        match else_body {
          Some(body) => collect_block_tails(state, body.instrs)
          None => ()
        }
      }
      TInstrKind::TTryTable(_, _, body) =>
        collect_block_tails(state, body.instrs)
      _ => ()
    }
  }
}

///|
/// Process a block instruction for code folding
fn process_block(
  state : CodeFoldingState,
  label : LabelIdx,
  instrs : Array[TInstr],
) -> TInstr? {
  if instrs.is_empty() {
    return None
  }
  if state.unoptimizables.contains(label) {
    return None
  }
  match state.break_tails.get(label) {
    None => None
    Some(tails) => {
      // Check if the end of the block can be reached
      let mut include_fallthrough = true
      for instr in instrs {
        match instr.kind {
          TInstrKind::TUnreachable => {
            include_fallthrough = false
            break
          }
          _ => ()
        }
      }
      let all_tails = if include_fallthrough {
        let result = tails.copy()
        result.push(Tail::fallthrough(instrs))
        result
      } else {
        tails
      }

      // Try to optimize
      optimize_expression_tails(
        state,
        all_tails,
        TInstr::block(BlockType::void_(), TExpr::new(instrs)),
      )
    }
  }
}

///|
/// Process an if instruction for code folding
fn process_if(
  state : CodeFoldingState,
  cond : TInstr,
  then_body : TExpr,
  else_body : TExpr?,
) -> TInstr? {
  match else_body {
    None => None
    Some(else_expr) => {
      // Both arms must be present
      let tails = [
        Tail::fallthrough(then_body.instrs),
        Tail::fallthrough(else_expr.instrs),
      ]
      optimize_expression_tails(
        state,
        tails,
        TInstr::if_(BlockType::void_(), cond, then_body, Some(else_expr)),
      )
    }
  }
}

///|
/// Main code folding pass
fn code_folding_pass() -> ModuleTransformer[CodeFoldingState] {
  ModuleTransformer::new()
  .on_tinstruction_evt(fn(self, state, instr) {
    // Process blocks and ifs for tail merging
    match instr.kind {
      TInstrKind::TBlock(bt, body) =>
        // First recurse into children
        match self.walk_tinstruction_default(state, instr) {
          Ok(Some((new_state, new_instr))) =>
            match new_instr.kind {
              TInstrKind::TBlock(_, new_body) =>
                // Try to optimize the block's tails
                match
                  process_block(new_state, LabelIdx::new(0), new_body.instrs) {
                  Some(_) =>
                    // Block was modified
                    change(new_state, TInstr::block(bt, new_body))
                  None => change(new_state, new_instr)
                }
              _ => change(new_state, new_instr)
            }
          Ok(None) =>
            // Try to optimize unchanged block
            match process_block(state, LabelIdx::new(0), body.instrs) {
              Some(_) => change(state, instr)
              None => unchanged()
            }
          Err(e) => Err(e)
        }
      TInstrKind::TIf(bt, cond, then_body, else_body) =>
        // First recurse into children
        match self.walk_tinstruction_default(state, instr) {
          Ok(Some((new_state, new_instr))) =>
            match new_instr.kind {
              TInstrKind::TIf(_, new_cond, new_then, new_else) =>
                // Try to optimize the if's tails
                match process_if(new_state, new_cond, new_then, new_else) {
                  Some(_) =>
                    // If was modified
                    change(
                      new_state,
                      TInstr::if_(bt, new_cond, new_then, new_else),
                    )
                  None => change(new_state, new_instr)
                }
              _ => change(new_state, new_instr)
            }
          Ok(None) =>
            // Try to optimize unchanged if
            match process_if(state, cond, then_body, else_body) {
              Some(_) => change(state, instr)
              None => unchanged()
            }
          Err(e) => Err(e)
        }
      _ => self.walk_tinstruction_default(state, instr)
    }
  })
  .on_func_evt(fn(self, state, func) {
    match func {
      Func(_) => unchanged()
      TFunc(locals, body) => {
        // Run multiple passes until no more changes
        let mut current_func = func
        let mut current_locals = locals
        let mut current_body = body
        state.another_pass = true
        while state.another_pass {
          state.another_pass = false
          state.clear()

          // Collect tails from function body
          collect_block_tails(state, current_body.instrs)

          // Try terminating tail optimization (returns/unreachables)
          match
            optimize_terminating_tails(
              state,
              state.return_tails.copy(),
              current_body.instrs,
            ) {
            Some(new_body_instrs) => {
              current_body = TExpr::new(new_body_instrs)
              current_func = Func::t_func(current_locals, current_body)
            }
            None =>
              // Try unreachable tails
              match
                optimize_terminating_tails(
                  state,
                  state.unreachable_tails.copy(),
                  current_body.instrs,
                ) {
                Some(new_body_instrs) => {
                  current_body = TExpr::new(new_body_instrs)
                  current_func = Func::t_func(current_locals, current_body)
                }
                None => ()
              }
          }

          // Process the function with collected information
          match self.walk_func_default(state, current_func) {
            Ok(Some((new_state, new_func))) => {
              state.another_pass = new_state.another_pass
              current_func = new_func
              match current_func {
                TFunc(l, b) => {
                  current_locals = l
                  current_body = b
                }
                _ => ()
              }
            }
            Ok(None) => ()
            Err(e) => return Err(e)
          }
        }
        if current_func == func {
          unchanged()
        } else {
          change(state, current_func)
        }
      }
    }
  })
}

///|
fn code_folding_ir_pass(_mod : Module) -> ModuleTransformer[IRContext] {
  let pass = code_folding_pass()
  ModuleTransformer::new().on_func_evt(fn(_, ctx : IRContext, func : Func) {
    match pass.walk_func(CodeFoldingState::new(), func) {
      Ok(Some((_, new_func))) => change(ctx, new_func)
      Ok(None) => unchanged()
      Err(e) => Err(e)
    }
  })
}

///|
test "code_folding_pass can be created" {
  let pass = code_folding_pass()
  let state = CodeFoldingState::{
    ..CodeFoldingState::new(),
    another_pass: false,
  }

  // Simple test: pass through a function
  let func = Func::t_func([], TExpr::new([TInstr::i32_const(I32(42))]))
  match pass.walk_func(state, func) {
    Ok(_) => () // Pass completes without error
    Err(e) => fail("Unexpected error: " + e)
  }
}

///|
test "measure counts instructions" {
  let simple = TInstr::i32_const(I32(42))
  assert_true(measure(simple) >= 1)
  let binary = TInstr::binary(
    BinaryOp::i32_add(),
    TInstr::i32_const(I32(1)),
    TInstr::i32_const(I32(2)),
  )
  assert_true(measure(binary) > measure(simple))
}

///|
test "get_branch_targets finds branches" {
  let br = TInstr::br(LabelIdx::new(0), [])
  let targets = get_branch_targets(br)
  assert_true(targets.contains(LabelIdx::new(0)))
  let no_br = TInstr::i32_const(I32(42))
  let no_targets = get_branch_targets(no_br)
  assert_true(no_targets.is_empty())
}

///|
/// Helper to run the code folding pass on a function
fn run_fold(f : Func) -> Func raise {
  let pass = code_folding_pass()
  let state = CodeFoldingState::{
    ..CodeFoldingState::new(),
    another_pass: false,
  }
  match pass.walk_func(state, f) {
    Ok(Some((_, new_f))) => return new_f
    Ok(None) => ()
    Err(e) => assert_true(false, msg=e)
  }
  f
}

///|
test "simple function unchanged" {
  let f = Func::t_func([], TExpr::new([TInstr::i32_const(I32(42))]))
  let f2 = run_fold(f)
  match f2 {
    TFunc(_, { instrs, .. }) => assert_eq(instrs.length(), 1)
    _ => fail("expected TFunc")
  }
}

///|
test "collect_block_tails finds return tails" {
  let state = CodeFoldingState::{
    ..CodeFoldingState::new(),
    another_pass: false,
  }
  let instrs = [
    TInstr::i32_const(I32(1)),
    TInstr::i32_const(I32(2)),
    TInstr::return_([TInstr::i32_const(I32(3))]),
  ]
  collect_block_tails(state, instrs)
  assert_eq(state.return_tails.length(), 1)
}

///|
test "collect_block_tails finds unreachable tails" {
  let state = CodeFoldingState::{
    ..CodeFoldingState::new(),
    another_pass: false,
  }
  let instrs = [TInstr::i32_const(I32(1)), TInstr::unreachable_()]
  collect_block_tails(state, instrs)
  assert_eq(state.unreachable_tails.length(), 1)
}

///|
test "collect_block_tails marks br_if as unoptimizable" {
  let state = CodeFoldingState::{
    ..CodeFoldingState::new(),
    another_pass: false,
  }
  let instrs : Array[TInstr] = [
    TInstr::br_if(LabelIdx::new(0), TInstr::i32_const(I32(1)), []),
  ]
  collect_block_tails(state, instrs)
  assert_true(state.unoptimizables.contains(LabelIdx::new(0)))
}

///|
test "collect_block_tails recurses into blocks" {
  let state = CodeFoldingState::{
    ..CodeFoldingState::new(),
    another_pass: false,
  }
  let inner : Array[TInstr] = [TInstr::return_([TInstr::i32_const(I32(42))])]
  let instrs : Array[TInstr] = [
    TInstr::block(BlockType::void_(), TExpr::new(inner)),
  ]
  collect_block_tails(state, instrs)
  assert_eq(state.return_tails.length(), 1)
}

///|
test "tail is_fallthrough works" {
  let ft = Tail::fallthrough([TInstr::i32_const(I32(1))])
  assert_true(ft.is_fallthrough())
  let br = Tail::branch(TInstr::br(LabelIdx::new(0), []), [])
  assert_true(not(br.is_fallthrough()))
}

///|
test "get_mergeable returns items from end" {
  let instrs = [
    TInstr::i32_const(I32(1)),
    TInstr::i32_const(I32(2)),
    TInstr::i32_const(I32(3)),
  ]
  let tail = Tail::fallthrough(instrs)

  // First item should be the last instruction
  match get_mergeable(tail, 0) {
    Some({ kind: TInstrKind::TI32Const(I32(3)), .. }) => ()
    _ => fail("expected i32.const 3")
  }

  // Second item should be second-to-last
  match get_mergeable(tail, 1) {
    Some({ kind: TInstrKind::TI32Const(I32(2)), .. }) => ()
    _ => fail("expected i32.const 2")
  }

  // Out of bounds
  match get_mergeable(tail, 10) {
    None => ()
    _ => fail("expected None for out of bounds")
  }
}

///|
test "is_terminating detects terminators" {
  assert_true(is_terminating(TInstr::unreachable_()))
  assert_true(is_terminating(TInstr::return_([])))
  assert_true(is_terminating(TInstr::return_call(FuncIdx::new(0), [])))
  assert_true(not(is_terminating(TInstr::i32_const(I32(42)))))
  assert_true(not(is_terminating(TInstr::nop())))
}

///|
test "is_branch detects branches" {
  assert_true(is_branch(TInstr::br(LabelIdx::new(0), [])))
  assert_true(
    is_branch(TInstr::br_if(LabelIdx::new(0), TInstr::i32_const(I32(1)), [])),
  )
  assert_true(not(is_branch(TInstr::i32_const(I32(42)))))
  assert_true(not(is_branch(TInstr::unreachable_())))
}

///|
test "measure_all sums instruction costs" {
  let instrs = [
    TInstr::i32_const(I32(1)),
    TInstr::i32_const(I32(2)),
    TInstr::i32_const(I32(3)),
  ]
  let total = measure_all(instrs)
  assert_true(total >= 3)
}

///|
test "can_move allows simple instructions" {
  let items = [TInstr::i32_const(I32(42))]
  let container = TInstr::block(BlockType::void_(), TExpr::new([TInstr::nop()]))
  assert_true(can_move(items, container))
}

// ============================================================
// Advanced Code Folding Tests
// ============================================================

///|
test "code folding: if-else with identical tails" {
  // Test:
  //   (if (condition)
  //     (block A C)
  //     (block B C)
  //   )
  // Should potentially fold C out
  let c_instr = TInstr::i32_const(I32(999)) // Common tail
  let then_body = TExpr::new([
    TInstr::i32_const(I32(1)), // A
    c_instr,
  ])
  let else_body = TExpr::new([
    TInstr::i32_const(I32(2)), // B
    TInstr::i32_const(I32(999)), // Same C (must be equal value)
  ])
  let if_instr = TInstr::if_(
    BlockType::void_(),
    TInstr::i32_const(I32(0)),
    then_body,
    Some(else_body),
  )
  let f = Func::t_func([], TExpr::new([if_instr]))
  let f2 = run_fold(f)
  // The pass should run without error
  match f2 {
    TFunc(_, { instrs: _, .. }) => ()
    _ => fail("expected TFunc")
  }
}

///|
test "code folding: nested blocks" {
  // Nested block structure
  let inner = TExpr::new([TInstr::i32_const(I32(1)), TInstr::i32_const(I32(2))])
  let outer = TExpr::new([TInstr::block(BlockType::void_(), inner)])
  let f = Func::t_func([], outer)
  let f2 = run_fold(f)
  match f2 {
    TFunc(_, _) => ()
    _ => fail("expected TFunc")
  }
}

///|
test "code folding: loop body" {
  let loop_body = TExpr::new([
    TInstr::i32_const(I32(1)),
    TInstr::br(LabelIdx::new(0), []),
  ])
  let loop_instr = TInstr::loop_(BlockType::void_(), loop_body)
  let f = Func::t_func([], TExpr::new([loop_instr]))
  let f2 = run_fold(f)
  match f2 {
    TFunc(_, _) => ()
    _ => fail("expected TFunc")
  }
}

///|
test "code folding: multiple returns" {
  // Function with multiple return points
  let if_instr = TInstr::if_(
    BlockType::void_(),
    TInstr::i32_const(I32(0)),
    TExpr::new([TInstr::return_([TInstr::i32_const(I32(1))])]),
    Some(TExpr::new([TInstr::return_([TInstr::i32_const(I32(2))])])),
  )
  let f = Func::t_func([], TExpr::new([if_instr]))
  let f2 = run_fold(f)
  match f2 {
    TFunc(_, _) => ()
    _ => fail("expected TFunc")
  }
}

///|
test "code folding: empty function unchanged" {
  let f = Func::t_func([], TExpr::new([]))
  let f2 = run_fold(f)
  match f2 {
    TFunc(_, { instrs, .. }) => assert_eq(instrs.length(), 0)
    _ => fail("expected TFunc")
  }
}

///|
test "code folding: single instruction unchanged" {
  let f = Func::t_func([], TExpr::new([TInstr::nop()]))
  let f2 = run_fold(f)
  match f2 {
    TFunc(_, { instrs, .. }) => {
      assert_eq(instrs.length(), 1)
      assert_true(instrs[0].kind is TInstrKind::TNop)
    }
    _ => fail("expected TFunc")
  }
}

///|
test "code folding: br_table marks all targets unoptimizable" {
  let state = CodeFoldingState::{
    ..CodeFoldingState::new(),
    another_pass: false,
  }
  let br_table = TInstr::br_table(
    [LabelIdx::new(0), LabelIdx::new(1)],
    LabelIdx::new(2),
    TInstr::i32_const(I32(0)),
    [],
  )
  let instrs : Array[TInstr] = [br_table]
  collect_block_tails(state, instrs)
  assert_true(state.unoptimizables.contains(LabelIdx::new(0)))
  assert_true(state.unoptimizables.contains(LabelIdx::new(1)))
  assert_true(state.unoptimizables.contains(LabelIdx::new(2)))
}

///|
test "code folding: complex nested structure" {
  // Create a complex nested structure
  let inner_if = TInstr::if_(
    BlockType::void_(),
    TInstr::local_get(LocalIdx::new(0)),
    TExpr::new([TInstr::i32_const(I32(1))]),
    Some(TExpr::new([TInstr::i32_const(I32(2))])),
  )
  let block = TInstr::block(BlockType::void_(), TExpr::new([inner_if]))
  let outer_if = TInstr::if_(
    BlockType::void_(),
    TInstr::local_get(LocalIdx::new(1)),
    TExpr::new([block]),
    Some(TExpr::new([TInstr::i32_const(I32(3))])),
  )
  let f = Func::t_func([ValType::i32(), ValType::i32()], TExpr::new([outer_if]))
  let f2 = run_fold(f)
  match f2 {
    TFunc(locals, _) => assert_eq(locals.length(), 2)
    _ => fail("expected TFunc")
  }
}

///|
test "get_branch_targets finds br_table targets" {
  let br_table = TInstr::br_table(
    [LabelIdx::new(0), LabelIdx::new(1), LabelIdx::new(2)],
    LabelIdx::new(3),
    TInstr::i32_const(I32(0)),
    [],
  )
  let targets = get_branch_targets(br_table)
  assert_true(targets.contains(LabelIdx::new(0)))
  assert_true(targets.contains(LabelIdx::new(1)))
  assert_true(targets.contains(LabelIdx::new(2)))
  assert_true(targets.contains(LabelIdx::new(3)))
}

///|
test "get_branch_targets finds nested branches" {
  let inner_br = TInstr::br(LabelIdx::new(1), [])
  let block = TInstr::block(
    BlockType::void_(),
    TExpr::new([inner_br, TInstr::br(LabelIdx::new(0), [])]),
  )
  let targets = get_branch_targets(block)
  assert_true(targets.contains(LabelIdx::new(0)))
  assert_true(targets.contains(LabelIdx::new(1)))
}
