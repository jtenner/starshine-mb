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
/// Code Pushing Pass
///
/// Pushes code "forward" as much as possible, potentially into
/// a location behind a condition, where it might not always execute.
///
/// This is the opposite of code hoisting - we move code later in execution
/// to reduce the number of times it runs when conditions are false.
///
/// For example:
///   x = expensive_op()
///   if (condition) {
///     use(x)
///   }
/// =>
///   if (condition) {
///     x = expensive_op()  // moved inside
///     use(x)
///   }

///|
/// Local variable analysis for Single First Assignment (SFA) form
/// SFA: the local has a single local.set, is not a parameter, and has no
/// local.gets before the local.set in postorder.
priv struct LocalAnalyzer {
  sfa : Array[Bool]
  num_sets : Array[Int]
  num_gets : Array[Int]
}

///|
fn LocalAnalyzer::new(num_locals : Int) -> LocalAnalyzer {
  LocalAnalyzer::{
    sfa: Array::make(num_locals, false),
    num_sets: Array::make(num_locals, 0),
    num_gets: Array::make(num_locals, 0),
  }
}

///|
fn LocalAnalyzer::is_sfa(self : LocalAnalyzer, index : LocalIdx) -> Bool {
  let i = index.0.reinterpret_as_int()
  if i >= 0 && i < self.sfa.length() {
    self.sfa[i]
  } else {
    false
  }
}

///|
fn LocalAnalyzer::get_num_gets(self : LocalAnalyzer, index : LocalIdx) -> Int {
  let i = index.0.reinterpret_as_int()
  if i >= 0 && i < self.num_gets.length() {
    self.num_gets[i]
  } else {
    0
  }
}

///|
/// Analyze a function to determine SFA properties
fn analyze_function(func : Func) -> LocalAnalyzer {
  match func {
    Func(_, _) =>
      // For non-TFunc, we can't analyze
      LocalAnalyzer::new(0)
    TFunc(params, body) => {
      let num_locals = params.length()
      let analyzer = LocalAnalyzer::new(num_locals)

      // Mark all non-parameters as potentially SFA
      for i = 0; i < num_locals; i = i + 1 {
        analyzer.sfa[i] = true
      }

      // Walk the function body to count sets and gets
      analyze_expr(body, analyzer, true)

      // Finalize: if no sets, not SFA
      for i = 0; i < num_locals; i = i + 1 {
        if analyzer.num_sets[i] == 0 {
          analyzer.sfa[i] = false
        }
      }
      analyzer
    }
  }
}

///|
/// Analyze an expression to count local gets/sets
fn analyze_expr(
  expr : TExpr,
  analyzer : LocalAnalyzer,
  before_first_set : Bool,
) -> Unit {
  for instr in expr.instrs {
    analyze_instr(instr, analyzer, before_first_set)
  }
}

///|
/// Analyze a single instruction
fn analyze_instr(
  instr : TInstr,
  analyzer : LocalAnalyzer,
  before_first_set : Bool,
) -> Unit {
  match instr.kind {
    TInstrKind::TLocalGet(idx) => {
      let i = idx.0.reinterpret_as_int()
      if i >= 0 && i < analyzer.num_gets.length() {
        // If we see a get before any set, not SFA
        if before_first_set && analyzer.num_sets[i] == 0 {
          analyzer.sfa[i] = false
        }
        analyzer.num_gets[i] += 1
      }
    }
    TInstrKind::TLocalSet(idx, value) => {
      let i = idx.0.reinterpret_as_int()
      if i >= 0 && i < analyzer.num_sets.length() {
        analyzer.num_sets[i] += 1
        // More than one set means not SFA
        if analyzer.num_sets[i] > 1 {
          analyzer.sfa[i] = false
        }
      }
      // Recurse into the value
      analyze_instr(value, analyzer, before_first_set)
    }
    TInstrKind::TLocalTee(idx, value) => {
      let i = idx.0.reinterpret_as_int()
      if i >= 0 && i < analyzer.num_sets.length() {
        analyzer.num_sets[i] += 1
        if analyzer.num_sets[i] > 1 {
          analyzer.sfa[i] = false
        }
      }
      analyze_instr(value, analyzer, before_first_set)
    }
    // Recurse into nested structures
    TInstrKind::TBlock(_, body) =>
      analyze_expr(body, analyzer, before_first_set)
    TInstrKind::TLoop(_, body) => analyze_expr(body, analyzer, before_first_set)
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      analyze_instr(cond, analyzer, before_first_set)
      analyze_expr(then_body, analyzer, before_first_set)
      match else_body {
        Some(body) => analyze_expr(body, analyzer, before_first_set)
        None => ()
      }
    }
    _ => ()
  }
}

///|
/// Simple effect tracking for an instruction or set of instructions
priv struct Effects {
  reads_locals : Set[LocalIdx]
  writes_locals : Set[LocalIdx]
  mut reads_memory : Bool
  mut writes_memory : Bool
  mut reads_globals : Bool
  mut writes_globals : Bool
  mut calls : Bool // Function calls can have arbitrary side effects
  mut branches : Bool // Control flow transfers
  mut traps : Bool // May trap (div by zero, etc.)
  mut throws : Bool // May throw an exception
}

///|
fn Effects::new() -> Effects {
  Effects::{
    reads_locals: Set::new(),
    writes_locals: Set::new(),
    reads_memory: false,
    writes_memory: false,
    reads_globals: false,
    writes_globals: false,
    calls: false,
    branches: false,
    traps: false,
    throws: false,
  }
}

///|
/// Check if these effects conflict with another set of effects
/// Two effects conflict if one writes something the other reads/writes
fn Effects::invalidates(self : Effects, other : Effects) -> Bool {
  // Check local conflicts
  for loc in self.writes_locals {
    if other.reads_locals.contains(loc) || other.writes_locals.contains(loc) {
      return true
    }
  }
  for loc in self.reads_locals {
    if other.writes_locals.contains(loc) {
      return true
    }
  }
  // Check memory conflicts
  if (self.reads_memory && other.writes_memory) ||
    (self.writes_memory && other.reads_memory) ||
    (self.writes_memory && other.writes_memory) {
    return true
  }
  // Check global conflicts
  if (self.reads_globals && other.writes_globals) ||
    (self.writes_globals && other.reads_globals) ||
    (self.writes_globals && other.writes_globals) {
    return true
  }
  // Calls can conflict with anything
  if self.calls || other.calls {
    if self.reads_memory ||
      self.writes_memory ||
      other.reads_memory ||
      other.writes_memory ||
      self.reads_globals ||
      self.writes_globals ||
      other.reads_globals ||
      other.writes_globals {
      return true
    }
  }
  false
}

///|
fn Effects::merge(self : Effects, other : Effects) -> Unit {
  for loc in other.reads_locals {
    self.reads_locals.add(loc)
  }
  for loc in other.writes_locals {
    self.writes_locals.add(loc)
  }
  self.reads_memory = self.reads_memory || other.reads_memory
  self.writes_memory = self.writes_memory || other.writes_memory
  self.reads_globals = self.reads_globals || other.reads_globals
  self.writes_globals = self.writes_globals || other.writes_globals
  self.calls = self.calls || other.calls
  self.branches = self.branches || other.branches
  self.traps = self.traps || other.traps
  self.throws = self.throws || other.throws
}

///|
/// Analyze effects of an instruction (recursively)
fn analyze_effects(instr : TInstr) -> Effects {
  let effects = Effects::new()
  analyze_effects_into(instr, effects)
  effects
}

///|
fn analyze_effects_into(instr : TInstr, effects : Effects) -> Unit {
  match instr.kind {
    // Local operations
    TInstrKind::TLocalGet(idx) => effects.reads_locals.add(idx)
    TInstrKind::TLocalSet(idx, value) => {
      effects.writes_locals.add(idx)
      analyze_effects_into(value, effects)
    }
    TInstrKind::TLocalTee(idx, value) => {
      effects.reads_locals.add(idx)
      effects.writes_locals.add(idx)
      analyze_effects_into(value, effects)
    }

    // Global operations
    TInstrKind::TGlobalGet(_) => effects.reads_globals = true
    TInstrKind::TGlobalSet(_, value) => {
      effects.writes_globals = true
      analyze_effects_into(value, effects)
    }

    // Memory operations
    TInstrKind::TLoad(_, _, ptr) => {
      effects.reads_memory = true
      analyze_effects_into(ptr, effects)
    }
    TInstrKind::TStore(_, _, ptr, value) => {
      effects.writes_memory = true
      analyze_effects_into(ptr, effects)
      analyze_effects_into(value, effects)
    }
    TInstrKind::TMemoryGrow(_, value) => {
      effects.writes_memory = true
      analyze_effects_into(value, effects)
    }
    TInstrKind::TMemorySize(_) => effects.reads_memory = true
    TInstrKind::TMemoryCopy(_, _, dst, src, len) => {
      effects.reads_memory = true
      effects.writes_memory = true
      analyze_effects_into(dst, effects)
      analyze_effects_into(src, effects)
      analyze_effects_into(len, effects)
    }
    TInstrKind::TMemoryFill(_, dst, val, len) => {
      effects.writes_memory = true
      analyze_effects_into(dst, effects)
      analyze_effects_into(val, effects)
      analyze_effects_into(len, effects)
    }

    // Calls - have arbitrary side effects
    TInstrKind::TCall(_, args) => {
      effects.calls = true
      for i = 0; i < args.length(); i = i + 1 {
        analyze_effects_into(args[i], effects)
      }
    }
    TInstrKind::TCallIndirect(_, _, args, table_idx) => {
      effects.calls = true
      for i = 0; i < args.length(); i = i + 1 {
        analyze_effects_into(args[i], effects)
      }
      analyze_effects_into(table_idx, effects)
    }
    TInstrKind::TCallRef(_, args, funcref) => {
      effects.calls = true
      for i = 0; i < args.length(); i = i + 1 {
        analyze_effects_into(args[i], effects)
      }
      analyze_effects_into(funcref, effects)
    }
    TInstrKind::TReturnCall(_, args) => {
      effects.calls = true
      effects.branches = true
      for i = 0; i < args.length(); i = i + 1 {
        analyze_effects_into(args[i], effects)
      }
    }
    TInstrKind::TReturnCallIndirect(_, _, args, table_idx) => {
      effects.calls = true
      effects.branches = true
      for i = 0; i < args.length(); i = i + 1 {
        analyze_effects_into(args[i], effects)
      }
      analyze_effects_into(table_idx, effects)
    }
    TInstrKind::TReturnCallRef(_, args, funcref) => {
      effects.calls = true
      effects.branches = true
      for i = 0; i < args.length(); i = i + 1 {
        analyze_effects_into(args[i], effects)
      }
      analyze_effects_into(funcref, effects)
    }

    // Control flow
    TInstrKind::TBr(_, args) => {
      effects.branches = true
      for arg in args {
        analyze_effects_into(arg, effects)
      }
    }
    TInstrKind::TBrIf(_, cond, args) => {
      effects.branches = true
      analyze_effects_into(cond, effects)
      for arg in args {
        analyze_effects_into(arg, effects)
      }
    }
    TInstrKind::TBrTable(_, _, index, args) => {
      effects.branches = true
      analyze_effects_into(index, effects)
      for arg in args {
        analyze_effects_into(arg, effects)
      }
    }
    TInstrKind::TReturn(args) => {
      effects.branches = true
      for arg in args {
        analyze_effects_into(arg, effects)
      }
    }

    // Trapping operations
    TInstrKind::TUnreachable => effects.traps = true

    // Exception handling
    TInstrKind::TThrow(_, args) => {
      effects.throws = true
      for arg in args {
        analyze_effects_into(arg, effects)
      }
    }
    TInstrKind::TThrowRef(value) => {
      effects.throws = true
      analyze_effects_into(value, effects)
    }

    // Nested structures - analyze their contents
    TInstrKind::TBlock(_, body) => analyze_effects_expr(body, effects)
    TInstrKind::TLoop(_, body) => analyze_effects_expr(body, effects)
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      analyze_effects_into(cond, effects)
      analyze_effects_expr(then_body, effects)
      match else_body {
        Some(body) => analyze_effects_expr(body, effects)
        None => ()
      }
    }
    TInstrKind::TTryTable(_, _, body) => analyze_effects_expr(body, effects)

    // Binary operations - check for trapping
    TInstrKind::TBinary(op, lhs, rhs) => {
      // Division and remainder can trap
      match op {
        I32DivSOp
        | I32DivUOp
        | I32RemSOp
        | I32RemUOp
        | I64DivSOp
        | I64DivUOp
        | I64RemSOp
        | I64RemUOp => effects.traps = true
        _ => ()
      }
      analyze_effects_into(lhs, effects)
      analyze_effects_into(rhs, effects)
    }

    // Unary operations - check for trapping conversions
    TInstrKind::TUnary(op, operand) => {
      match op {
        I32TruncF32SOp
        | I32TruncF32UOp
        | I32TruncF64SOp
        | I32TruncF64UOp
        | I64TruncF32SOp
        | I64TruncF32UOp
        | I64TruncF64SOp
        | I64TruncF64UOp => effects.traps = true
        _ => ()
      }
      analyze_effects_into(operand, effects)
    }

    // Select
    TInstrKind::TSelect(_, cond, if_true, if_false) => {
      analyze_effects_into(cond, effects)
      analyze_effects_into(if_true, effects)
      analyze_effects_into(if_false, effects)
    }

    // Drop
    TInstrKind::TDrop(value) => analyze_effects_into(value, effects)

    // Pure instructions (no side effects beyond their children)
    TInstrKind::TNop
    | TInstrKind::TI32Const(_)
    | TInstrKind::TI64Const(_)
    | TInstrKind::TF32Const(_)
    | TInstrKind::TF64Const(_)
    | TInstrKind::TV128Const(_)
    | TInstrKind::TRefNull(_)
    | TInstrKind::TRefFunc(_) => ()

    // Default: assume no additional effects beyond children
    _ => ()
  }
}

///|
fn analyze_effects_expr(expr : TExpr, effects : Effects) -> Unit {
  for instr in expr.instrs {
    analyze_effects_into(instr, effects)
  }
}

///|
/// Check if an instruction is a push point (conditional control flow)
fn is_push_point(instr : TInstr) -> Bool {
  // Look through drops
  let target = match instr.kind {
    TInstrKind::TDrop(value) => value
    _ => instr
  }
  match target.kind {
    TInstrKind::TIf(_, _, _, _) => true
    TInstrKind::TBrIf(_, _, _) => true
    TInstrKind::TBrOnNull(_, _, _) => true
    TInstrKind::TBrOnNonNull(_, _, _) => true
    TInstrKind::TBrOnCast(_, _, _, _, _, _) => true
    TInstrKind::TBrOnCastFail(_, _, _, _, _, _) => true
    _ => false
  }
}

///|
/// Check if an instruction is a pushable local.set
/// Returns the local index and value if pushable, None otherwise
fn is_pushable(
  instr : TInstr,
  analyzer : LocalAnalyzer,
  num_gets_so_far : Array[Int],
) -> (LocalIdx, TInstr)? {
  match instr.kind {
    TInstrKind::TLocalSet(idx, value) => {
      let i = idx.0.reinterpret_as_int()
      // Must be SFA and no gets have been seen yet (all gets are after this point)
      if i >= 0 &&
        i < analyzer.sfa.length() &&
        analyzer.is_sfa(idx) &&
        num_gets_so_far[i] == 0 {
        // Check if the value has unremovable side effects
        let effects = analyze_effects(value)
        // We can push if there are no side effects that would be problematic
        // Traps are ok since we're moving to execute less often
        if not(effects.calls) &&
          not(effects.throws) &&
          not(effects.writes_memory) &&
          not(effects.writes_globals) {
          return Some((idx, value))
        }
      }
      None
    }
    _ => None
  }
}

///|
/// State for tracking gets during the walk
priv struct PushingState {
  analyzer : LocalAnalyzer
  num_gets_so_far : Array[Int]
  mut changed : Bool
}

///|
/// Update gets counter when encountering a local.get
fn count_local_get(state : PushingState, idx : LocalIdx) -> Unit {
  let i = idx.0.reinterpret_as_int()
  if i >= 0 && i < state.num_gets_so_far.length() {
    state.num_gets_so_far[i] += 1
  }
}

///|
/// Count local.gets in an instruction (recursively)
fn count_gets_in_instr(state : PushingState, instr : TInstr) -> Unit {
  match instr.kind {
    TInstrKind::TLocalGet(idx) => count_local_get(state, idx)
    TInstrKind::TLocalSet(_, value) => count_gets_in_instr(state, value)
    TInstrKind::TLocalTee(idx, value) => {
      count_local_get(state, idx)
      count_gets_in_instr(state, value)
    }
    TInstrKind::TBlock(_, body) => count_gets_in_expr(state, body)
    TInstrKind::TLoop(_, body) => count_gets_in_expr(state, body)
    TInstrKind::TIf(_, cond, then_body, else_body) => {
      count_gets_in_instr(state, cond)
      count_gets_in_expr(state, then_body)
      match else_body {
        Some(body) => count_gets_in_expr(state, body)
        None => ()
      }
    }
    _ => {
      // Use a walker to find all local.gets
      let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, i) {
        match i.kind {
          TInstrKind::TLocalGet(idx) => count_local_get(state, idx)
          _ => ()
        }
        self.walk_tinstruction_default((), i)
      })
      ignore(walker.walk_tinstruction((), instr))
    }
  }
}

///|
fn count_gets_in_expr(state : PushingState, expr : TExpr) -> Unit {
  for instr in expr.instrs {
    count_gets_in_instr(state, instr)
  }
}

///|
/// Optimize a segment of code by pushing local.sets past the push point
/// Returns the new index to continue from
fn optimize_segment(
  list : Array[TInstr],
  first_pushable : Int,
  push_point : Int,
  state : PushingState,
) -> Int {
  // Collect effects of the push point
  let cumulative_effects = analyze_effects(list[push_point])

  // Find what we can push (working backwards from push point)
  let to_push : Array[Int] = []
  let mut i = push_point - 1
  while i >= first_pushable {
    match is_pushable(list[i], state.analyzer, state.num_gets_so_far) {
      Some((_, _)) => {
        let effects = analyze_effects(list[i])
        if not(cumulative_effects.invalidates(effects)) {
          // Can push this!
          to_push.push(i)
        } else {
          // Can't push, add to cumulative effects
          cumulative_effects.merge(effects)
        }
      }
      None =>
        // Not pushable, add effects
        cumulative_effects.merge(analyze_effects(list[i]))
    }
    i -= 1
  }
  if to_push.is_empty() {
    return push_point + 1
  }

  // Perform the push: remove items and reinsert after push point
  state.changed = true

  // Sort indices in descending order (we'll remove from back to front)
  to_push.rev_in_place()

  // Collect the instructions to push
  let pushed_instrs : Array[TInstr] = []
  for idx in to_push {
    pushed_instrs.push(list[idx])
  }

  // Replace pushed instructions with nops (we'll compact later)
  for idx in to_push {
    list[idx] = TInstr::nop()
  }

  // Insert pushed instructions after push point
  // We need to splice them in
  let new_list : Array[TInstr] = []
  for j = 0; j <= push_point; j = j + 1 {
    new_list.push(list[j])
  }
  // Add pushed instructions (in original order)
  pushed_instrs.rev_in_place()
  for instr in pushed_instrs {
    new_list.push(instr)
  }
  for j = push_point + 1; j < list.length(); j = j + 1 {
    new_list.push(list[j])
  }

  // Update the list in place
  list.clear()
  for instr in new_list {
    list.push(instr)
  }

  // Remove the nops
  compact_nops(list)

  // Return position after push point minus the number we pushed
  push_point - to_push.length() + 1
}

///|
/// Remove TInstrKind::TNop instructions from a list
fn compact_nops(list : Array[TInstr]) -> Unit {
  let new_list : Array[TInstr] = []
  for instr in list {
    match instr.kind {
      TInstrKind::TNop => continue
      _ => new_list.push(instr)
    }
  }
  list.clear()
  for instr in new_list {
    list.push(instr)
  }
}

///|
/// Try to push code into if arms
fn optimize_into_if(
  list : Array[TInstr],
  first_pushable : Int,
  push_point : Int,
  state : PushingState,
) -> Unit {
  // Check if push point is an if
  let iff = match list[push_point].kind {
    TInstrKind::TIf(bt, cond, then_body, else_body) =>
      (bt, cond, then_body, else_body)
    _ => return
  }
  let (bt, cond, then_body, else_body_opt) = iff

  // Effects of the condition (must push past this)
  let cumulative_effects = analyze_effects(cond)

  // Effects of each arm
  let if_true_effects = analyze_effects_for_expr(then_body)
  let if_false_effects = match else_body_opt {
    Some(body) => analyze_effects_for_expr(body)
    None => Effects::new()
  }

  // Effects after the if
  let post_if_effects = Effects::new()
  for j = push_point + 1; j < list.length(); j = j + 1 {
    post_if_effects.merge(analyze_effects(list[j]))
  }

  // Work backwards from push point
  let mut i = push_point - 1
  while i >= first_pushable {
    match is_pushable(list[i], state.analyzer, state.num_gets_so_far) {
      Some((idx, value)) => {
        let effects = analyze_effects(list[i])
        if cumulative_effects.invalidates(effects) {
          // Can't move past condition
          cumulative_effects.merge(effects)
          i -= 1
          continue
        }

        // Try to push into if-true arm
        let pushed = try_push_into_arm(
          list, i, idx, value, then_body, else_body_opt, if_true_effects, if_false_effects,
          post_if_effects, state, bt, cond, push_point, true,
        )
        if pushed {
          // Update cumulative effects with what we just pushed
          if_true_effects.merge(effects)
          i -= 1
          continue
        }

        // Try to push into if-false arm
        match else_body_opt {
          Some(else_body) => {
            let pushed2 = try_push_into_arm(
              list,
              i,
              idx,
              value,
              else_body,
              Some(then_body),
              if_false_effects,
              if_true_effects,
              post_if_effects,
              state,
              bt,
              cond,
              push_point,
              false,
            )
            if pushed2 {
              if_false_effects.merge(effects)
              i -= 1
              continue
            }
          }
          None => ()
        }

        // Couldn't push, add to cumulative
        cumulative_effects.merge(effects)
      }
      None => cumulative_effects.merge(analyze_effects(list[i]))
    }
    i -= 1
  }
}

///|
fn analyze_effects_for_expr(expr : TExpr) -> Effects {
  let effects = Effects::new()
  analyze_effects_expr(expr, effects)
  effects
}

///|
/// Try to push a local.set into one arm of an if
fn try_push_into_arm(
  list : Array[TInstr],
  set_idx : Int,
  local_idx : LocalIdx,
  _value : TInstr,
  arm : TExpr,
  other_arm : TExpr?,
  arm_effects : Effects,
  other_arm_effects : Effects,
  post_if_effects : Effects,
  state : PushingState,
  bt : BlockType,
  cond : TInstr,
  push_point : Int,
  is_then : Bool,
) -> Bool {
  // The arm must read this local
  if not(arm_effects.reads_locals.contains(local_idx)) {
    return false
  }
  // The other arm must not read this local
  if other_arm_effects.reads_locals.contains(local_idx) {
    return false
  }
  // If the local is read after the if, the other arm must be unreachable
  if post_if_effects.reads_locals.contains(local_idx) {
    match other_arm {
      Some(other) => {
        // Check if other arm is unreachable
        let other_instrs = other.instrs
        if other_instrs.is_empty() {
          return false
        }
        let last = other_instrs[other_instrs.length() - 1]
        match last.kind {
          TInstrKind::TUnreachable
          | TInstrKind::TReturn(_)
          | TInstrKind::TBr(_, _) => ()
          _ => return false
        }
      }
      None => return false
    }
  }

  // We can push! Insert at the beginning of the arm
  state.changed = true
  let set_instr = list[set_idx]
  list[set_idx] = TInstr::nop()

  // Create new arm with the instruction prepended
  let new_arm_instrs : Array[TInstr] = [set_instr]
  for instr in arm.instrs {
    new_arm_instrs.push(instr)
  }
  let new_arm = TExpr::new(new_arm_instrs)

  // Rebuild the if
  let (new_then, new_else) = if is_then {
    (new_arm, other_arm)
  } else {
    let orig_then = match list[push_point].kind {
      TInstrKind::TIf(_, _, t, _) => t
      _ => arm // fallback
    }
    (orig_then, Some(new_arm))
  }
  list[push_point] = TInstr::if_(bt, cond, new_then, new_else)
  compact_nops(list)
  true
}

///|
/// Process a block of instructions for code pushing
fn push_code_in_block(list : Array[TInstr], state : PushingState) -> Unit {
  if list.length() < 2 {
    return
  }

  // Find optimization segments
  let nothing : Int = -1
  let mut i = 0
  let mut first_pushable = nothing
  while i < list.length() {
    // Check if this is pushable
    if first_pushable == nothing {
      match is_pushable(list[i], state.analyzer, state.num_gets_so_far) {
        Some(_) => first_pushable = i
        None => ()
      }
    }

    // Check if this is a push point
    if first_pushable != nothing && is_push_point(list[i]) {
      // Optimize into if first (doesn't move push point)
      optimize_into_if(list, first_pushable, i, state)
      // Then optimize segment (may move things past push point)
      if i < list.length() - 1 {
        i = optimize_segment(list, first_pushable, i, state)
      }
      first_pushable = nothing
      continue
    }

    // Count local.gets for tracking
    count_gets_in_instr(state, list[i])
    i += 1
  }
}

///|
/// Main code pushing pass
fn code_pushing_pass() -> ModuleTransformer[Unit] {
  ModuleTransformer::new().on_func_evt(fn(_self, _state, func) {
    match func {
      Func(_, _) => unchanged()
      TFunc(params, body) => {
        let num_locals = params.length()
        if num_locals == 0 {
          return unchanged()
        }

        // Analyze the function
        let analyzer = analyze_function(func)

        // Create pushing state
        let push_state = PushingState::{
          analyzer,
          num_gets_so_far: Array::make(num_locals, 0),
          changed: false,
        }

        // Process the function body
        let body_instrs = body.instrs.copy()
        push_code_in_block(body_instrs, push_state)

        // Also process nested blocks
        process_nested_blocks(body_instrs, push_state)
        if push_state.changed {
          Ok(Some(((), Func::t_func(params, TExpr::new(body_instrs)))))
        } else {
          unchanged()
        }
      }
    }
  })
}

///|
fn code_pushing_ir_pass(_mod : Module) -> ModuleTransformer[IRContext] {
  wrap_unit_func_pass(code_pushing_pass())
}

///|
/// Recursively process nested blocks
fn process_nested_blocks(instrs : Array[TInstr], state : PushingState) -> Unit {
  for i = 0; i < instrs.length(); i = i + 1 {
    match instrs[i].kind {
      TInstrKind::TBlock(bt, body) => {
        let body_instrs = body.instrs.copy()
        push_code_in_block(body_instrs, state)
        process_nested_blocks(body_instrs, state)
        if state.changed {
          instrs[i] = TInstr::block(bt, TExpr::new(body_instrs))
        }
      }
      TInstrKind::TLoop(bt, body) => {
        let body_instrs = body.instrs.copy()
        push_code_in_block(body_instrs, state)
        process_nested_blocks(body_instrs, state)
        if state.changed {
          instrs[i] = TInstr::loop_(bt, TExpr::new(body_instrs))
        }
      }
      TInstrKind::TIf(bt, cond, then_body, else_body) => {
        let then_instrs = then_body.instrs.copy()
        push_code_in_block(then_instrs, state)
        process_nested_blocks(then_instrs, state)
        let new_else = match else_body {
          Some(eb) => {
            let else_instrs = eb.instrs.copy()
            push_code_in_block(else_instrs, state)
            process_nested_blocks(else_instrs, state)
            Some(TExpr::new(else_instrs))
          }
          None => None
        }
        if state.changed {
          instrs[i] = TInstr::if_(bt, cond, TExpr::new(then_instrs), new_else)
        }
      }
      _ => ()
    }
  }
}

///|
test "LocalAnalyzer creation" {
  let analyzer = LocalAnalyzer::new(5)
  assert_eq(analyzer.sfa.length(), 5)
  assert_eq(analyzer.num_sets.length(), 5)
  assert_eq(analyzer.num_gets.length(), 5)
}

///|
test "LocalAnalyzer is_sfa bounds check" {
  let analyzer = LocalAnalyzer::new(3)
  // Out of bounds index returns false
  assert_false(analyzer.is_sfa(LocalIdx::new(5)))
  assert_false(analyzer.is_sfa(LocalIdx::new(100)))
}

///|
test "LocalAnalyzer get_num_gets bounds check" {
  let analyzer = LocalAnalyzer::new(3)
  // Out of bounds index returns 0
  assert_eq(analyzer.get_num_gets(LocalIdx::new(5)), 0)
  assert_eq(analyzer.get_num_gets(LocalIdx::new(100)), 0)
}

///|
test "analyze_function with empty TFunc" {
  let f = Func::t_func([], TExpr::new([]))
  let analyzer = analyze_function(f)
  assert_eq(analyzer.sfa.length(), 0)
}

///|
test "analyze_function with single local.set" {
  // (local.set 0 (i32.const 42))
  let body = TExpr::new([
    TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(42))),
  ])
  let f = Func::t_func([ValType::i32()], body)
  let analyzer = analyze_function(f)
  assert_eq(analyzer.num_sets[0], 1)
  assert_true(analyzer.sfa[0])
}

///|
test "analyze_function with multiple sets not SFA" {
  // (local.set 0 (i32.const 1))
  // (local.set 0 (i32.const 2))
  let body = TExpr::new([
    TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(1))),
    TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(2))),
  ])
  let f = Func::t_func([ValType::i32()], body)
  let analyzer = analyze_function(f)
  assert_eq(analyzer.num_sets[0], 2)
  assert_false(analyzer.sfa[0])
}

///|
test "analyze_function with get before set not SFA" {
  // (local.get 0)
  // (local.set 0 (i32.const 42))
  let body = TExpr::new([
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(42))),
  ])
  let f = Func::t_func([ValType::i32()], body)
  let analyzer = analyze_function(f)
  assert_false(analyzer.sfa[0])
}

///|
test "analyze_function counts gets correctly" {
  // (local.set 0 (i32.const 42))
  // (local.get 0)
  // (local.get 0)
  let body = TExpr::new([
    TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(42))),
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::local_get(LocalIdx::new(0)),
  ])
  let f = Func::t_func([ValType::i32()], body)
  let analyzer = analyze_function(f)
  assert_eq(analyzer.num_gets[0], 2)
  assert_true(analyzer.sfa[0])
}

///|
test "analyze_function with local.tee" {
  // (local.tee 0 (i32.const 42))
  let body = TExpr::new([
    TInstr::local_tee(LocalIdx::new(0), TInstr::i32_const(I32(42))),
  ])
  let f = Func::t_func([ValType::i32()], body)
  let analyzer = analyze_function(f)
  assert_eq(analyzer.num_sets[0], 1)
}

///|
test "analyze_function with nested block" {
  // (block
  //   (local.set 0 (i32.const 42))
  // )
  let inner = TExpr::new([
    TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(42))),
  ])
  let body = TExpr::new([TInstr::block(BlockType::void_(), inner)])
  let f = Func::t_func([ValType::i32()], body)
  let analyzer = analyze_function(f)
  assert_eq(analyzer.num_sets[0], 1)
  assert_true(analyzer.sfa[0])
}

///|
test "analyze_function with if-else" {
  // (if (i32.const 1)
  //   (local.set 0 (i32.const 42))
  //   (local.set 0 (i32.const 99))
  // )
  let then_body = TExpr::new([
    TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(42))),
  ])
  let else_body = TExpr::new([
    TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(99))),
  ])
  let body = TExpr::new([
    TInstr::if_(
      BlockType::void_(),
      TInstr::i32_const(I32(1)),
      then_body,
      Some(else_body),
    ),
  ])
  let f = Func::t_func([ValType::i32()], body)
  let analyzer = analyze_function(f)
  assert_eq(analyzer.num_sets[0], 2)
  assert_false(analyzer.sfa[0])
}

///|
test "code_pushing_pass creates valid transformer" {
  let pass = code_pushing_pass()
  assert_true(pass.on_func is Some(_))
}

///|
test "code_pushing_pass leaves empty function unchanged" {
  let pass = code_pushing_pass()
  let f = Func::t_func([], TExpr::new([]))
  match pass.on_func {
    Some(handler) =>
      match handler(pass, (), f) {
        Ok(None) => ()
        _ => fail("expected unchanged (Ok(None))")
      }
    None => fail("expected handler")
  }
}

// ============================================================
// Effects Analysis Tests
// ============================================================

///|
test "Effects::new creates empty effects" {
  let effects = Effects::new()
  assert_false(effects.reads_memory)
  assert_false(effects.writes_memory)
  assert_false(effects.calls)
  assert_false(effects.traps)
  assert_true(effects.reads_locals.is_empty())
  assert_true(effects.writes_locals.is_empty())
}

///|
test "analyze_effects detects local.get" {
  let instr = TInstr::local_get(LocalIdx::new(0))
  let effects = analyze_effects(instr)
  assert_true(effects.reads_locals.contains(LocalIdx::new(0)))
  assert_false(effects.writes_locals.contains(LocalIdx::new(0)))
}

///|
test "analyze_effects detects local.set" {
  let instr = TInstr::local_set(LocalIdx::new(1), TInstr::i32_const(I32(42)))
  let effects = analyze_effects(instr)
  assert_true(effects.writes_locals.contains(LocalIdx::new(1)))
}

///|
test "analyze_effects detects memory read" {
  let instr = TInstr::load(
    LoadOp::i32_load(),
    MemArg::new(0, None, 0),
    TInstr::i32_const(I32(0)),
  )
  let effects = analyze_effects(instr)
  assert_true(effects.reads_memory)
  assert_false(effects.writes_memory)
}

///|
test "analyze_effects detects memory write" {
  let instr = TInstr::store(
    StoreOp::i32_store(),
    MemArg::new(0, None, 0),
    TInstr::i32_const(I32(0)),
    TInstr::i32_const(I32(42)),
  )
  let effects = analyze_effects(instr)
  assert_true(effects.writes_memory)
}

///|
test "analyze_effects detects call" {
  let instr = TInstr::call(FuncIdx::new(0), [TInstr::i32_const(I32(42))])
  let effects = analyze_effects(instr)
  assert_true(effects.calls)
}

///|
test "analyze_effects detects global read/write" {
  let get_instr = TInstr::global_get(GlobalIdx::new(0))
  let get_effects = analyze_effects(get_instr)
  assert_true(get_effects.reads_globals)
  let set_instr = TInstr::global_set(
    GlobalIdx::new(0),
    TInstr::i32_const(I32(1)),
  )
  let set_effects = analyze_effects(set_instr)
  assert_true(set_effects.writes_globals)
}

///|
test "analyze_effects detects division trap" {
  let instr = TInstr::binary(
    BinaryOp::i32_div_s(),
    TInstr::i32_const(I32(10)),
    TInstr::i32_const(I32(2)),
  )
  let effects = analyze_effects(instr)
  assert_true(effects.traps)
}

///|
test "Effects::invalidates detects local conflicts" {
  let e1 = Effects::new()
  e1.writes_locals.add(LocalIdx::new(0))
  let e2 = Effects::new()
  e2.reads_locals.add(LocalIdx::new(0))
  assert_true(e1.invalidates(e2))
  assert_true(e2.invalidates(e1))
}

///|
test "Effects::invalidates detects memory conflicts" {
  let e1 = Effects::new()
  e1.writes_memory = true
  let e2 = Effects::new()
  e2.reads_memory = true
  assert_true(e1.invalidates(e2))
}

///|
test "Effects::invalidates allows non-conflicting effects" {
  let e1 = Effects::new()
  e1.reads_locals.add(LocalIdx::new(0))
  let e2 = Effects::new()
  e2.reads_locals.add(LocalIdx::new(1))
  assert_false(e1.invalidates(e2))
}

///|
test "Effects::merge combines effects" {
  let e1 = Effects::new()
  e1.reads_locals.add(LocalIdx::new(0))
  e1.reads_memory = true
  let e2 = Effects::new()
  e2.writes_locals.add(LocalIdx::new(1))
  e2.calls = true
  e1.merge(e2)
  assert_true(e1.reads_locals.contains(LocalIdx::new(0)))
  assert_true(e1.writes_locals.contains(LocalIdx::new(1)))
  assert_true(e1.reads_memory)
  assert_true(e1.calls)
}

// ============================================================
// Push Point Detection Tests
// ============================================================

///|
test "is_push_point detects if" {
  let instr = TInstr::if_(
    BlockType::void_(),
    TInstr::i32_const(I32(1)),
    TExpr::new([TInstr::nop()]),
    None,
  )
  assert_true(is_push_point(instr))
}

///|
test "is_push_point detects br_if" {
  let instr = TInstr::br_if(LabelIdx::new(0), TInstr::i32_const(I32(1)), [])
  assert_true(is_push_point(instr))
}

///|
test "is_push_point rejects unconditional br" {
  let instr = TInstr::br(LabelIdx::new(0), [])
  assert_false(is_push_point(instr))
}

///|
test "is_push_point rejects block" {
  let instr = TInstr::block(BlockType::void_(), TExpr::new([TInstr::nop()]))
  assert_false(is_push_point(instr))
}

// ============================================================
// Pushable Detection Tests
// ============================================================

///|
test "is_pushable identifies simple SFA local.set" {
  // Create a function with a single SFA local.set
  let body = TExpr::new([
    TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(42))),
    TInstr::local_get(LocalIdx::new(0)),
  ])
  let f = Func::t_func([ValType::i32()], body)
  let analyzer = analyze_function(f)
  let num_gets_so_far = Array::make(1, 0)
  let set_instr = TInstr::local_set(
    LocalIdx::new(0),
    TInstr::i32_const(I32(42)),
  )
  match is_pushable(set_instr, analyzer, num_gets_so_far) {
    Some((idx, _)) => assert_eq(idx, LocalIdx::new(0))
    None => fail("expected pushable")
  }
}

///|
test "is_pushable rejects non-SFA local.set" {
  // Create a function with multiple sets
  let body = TExpr::new([
    TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(1))),
    TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(2))),
    TInstr::local_get(LocalIdx::new(0)),
  ])
  let f = Func::t_func([ValType::i32()], body)
  let analyzer = analyze_function(f)
  let num_gets_so_far = Array::make(1, 0)
  let set_instr = TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(1)))
  assert_true(is_pushable(set_instr, analyzer, num_gets_so_far) is None)
}

///|
test "is_pushable rejects local.set with call" {
  let body = TExpr::new([
    TInstr::local_set(LocalIdx::new(0), TInstr::call(FuncIdx::new(0), [])),
    TInstr::local_get(LocalIdx::new(0)),
  ])
  let f = Func::t_func([ValType::i32()], body)
  let analyzer = analyze_function(f)
  let num_gets_so_far = Array::make(1, 0)
  let set_instr = TInstr::local_set(
    LocalIdx::new(0),
    TInstr::call(FuncIdx::new(0), []),
  )
  assert_true(is_pushable(set_instr, analyzer, num_gets_so_far) is None)
}
