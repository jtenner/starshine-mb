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
priv struct LICMEffects {
  locals_read : Set[LocalIdx]
  locals_written : Set[LocalIdx]
  mut reads_memory : Bool
  mut writes_memory : Bool
  mut reads_globals : Bool
  mut writes_globals : Bool
  mut calls : Bool
  mut branches : Bool
  mut traps : Bool
  mut throws : Bool
}

///|
fn LICMEffects::new() -> LICMEffects {
  {
    locals_read: Set::new(),
    locals_written: Set::new(),
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
fn LICMEffects::merge(self : LICMEffects, other : LICMEffects) -> Unit {
  for idx in other.locals_read {
    self.locals_read.add(idx)
  }
  for idx in other.locals_written {
    self.locals_written.add(idx)
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
fn LICMEffects::invalidates(self : LICMEffects, other : LICMEffects) -> Bool {
  for local_idx in self.locals_written {
    if other.locals_read.contains(local_idx) ||
      other.locals_written.contains(local_idx) {
      return true
    }
  }
  for local_idx in self.locals_read {
    if other.locals_written.contains(local_idx) {
      return true
    }
  }
  if (self.reads_memory && other.writes_memory) ||
    (self.writes_memory && other.reads_memory) ||
    (self.writes_memory && other.writes_memory) {
    return true
  }
  if (self.reads_globals && other.writes_globals) ||
    (self.writes_globals && other.reads_globals) ||
    (self.writes_globals && other.writes_globals) {
    return true
  }
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
  if self.transfers_control_flow() || other.transfers_control_flow() {
    return true
  }
  if (self.traps && other.has_unremovable_side_effects()) ||
    (other.traps && self.has_unremovable_side_effects()) {
    return true
  }
  false
}

///|
fn LICMEffects::transfers_control_flow(self : LICMEffects) -> Bool {
  self.branches || self.throws
}

///|
fn LICMEffects::writes_global_state(self : LICMEffects) -> Bool {
  self.writes_memory || self.writes_globals || self.calls
}

///|
fn LICMEffects::reads_mutable_global_state(self : LICMEffects) -> Bool {
  self.reads_memory || self.reads_globals || self.calls
}

///|
fn LICMEffects::has_unremovable_side_effects(self : LICMEffects) -> Bool {
  self.writes_memory ||
  self.writes_globals ||
  self.calls ||
  self.branches ||
  self.throws ||
  self.traps ||
  self.locals_written.length() > 0
}

///|
fn licm_collect_effects(instr : TInstr) -> LICMEffects {
  let effects = LICMEffects::new()
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    match curr.kind {
      TInstrKind::TLocalGet(idx) => effects.locals_read.add(idx)
      TInstrKind::TLocalSet(idx, _) => effects.locals_written.add(idx)
      TInstrKind::TLocalTee(idx, _) => {
        effects.locals_read.add(idx)
        effects.locals_written.add(idx)
      }
      TInstrKind::TGlobalGet(_) => effects.reads_globals = true
      TInstrKind::TGlobalSet(_, _) => effects.writes_globals = true
      TInstrKind::TLoad(_, _, _) => {
        effects.reads_memory = true
        effects.traps = true
      }
      TInstrKind::TStore(_, _, _, _) => {
        effects.writes_memory = true
        effects.traps = true
      }
      TInstrKind::TMemoryGrow(_, _) => effects.writes_memory = true
      TInstrKind::TMemorySize(_) => effects.reads_memory = true
      TInstrKind::TMemoryCopy(_, _, _, _, _) => {
        effects.reads_memory = true
        effects.writes_memory = true
      }
      TInstrKind::TMemoryFill(_, _, _, _) => effects.writes_memory = true
      TInstrKind::TMemoryInit(_, _, _, _, _) => {
        effects.reads_memory = true
        effects.writes_memory = true
      }
      TInstrKind::TDataDrop(_) => effects.writes_memory = true
      TInstrKind::TTableSet(_, _, _)
      | TInstrKind::TTableGrow(_, _, _)
      | TInstrKind::TTableFill(_, _, _, _) => effects.writes_memory = true
      TInstrKind::TTableGet(_, _) | TInstrKind::TTableSize(_) =>
        effects.reads_memory = true
      TInstrKind::TTableCopy(_, _, _, _, _)
      | TInstrKind::TTableInit(_, _, _, _, _)
      | TInstrKind::TElemDrop(_) => {
        effects.reads_memory = true
        effects.writes_memory = true
      }
      TInstrKind::TCall(_, _)
      | TInstrKind::TCallIndirect(_, _, _, _)
      | TInstrKind::TCallRef(_, _, _) => effects.calls = true
      TInstrKind::TReturnCall(_, _)
      | TInstrKind::TReturnCallIndirect(_, _, _, _)
      | TInstrKind::TReturnCallRef(_, _, _) => {
        effects.calls = true
        effects.branches = true
      }
      TInstrKind::TBr(_, _)
      | TInstrKind::TBrIf(_, _, _)
      | TInstrKind::TBrTable(_, _, _, _)
      | TInstrKind::TBrOnNull(_, _, _)
      | TInstrKind::TBrOnNonNull(_, _, _)
      | TInstrKind::TBrOnCast(_, _, _, _, _, _)
      | TInstrKind::TBrOnCastFail(_, _, _, _, _, _)
      | TInstrKind::TReturn(_) => effects.branches = true
      TInstrKind::TThrow(_, _) => {
        effects.throws = true
        effects.branches = true
      }
      TInstrKind::TThrowRef(_) => {
        effects.throws = true
        effects.branches = true
      }
      TInstrKind::TUnreachable => effects.traps = true
      TInstrKind::TRefAsNonNull(_) | TInstrKind::TRefCast(_, _, _) =>
        effects.traps = true
      TInstrKind::TStructGet(_, _, _)
      | TInstrKind::TStructGetS(_, _, _)
      | TInstrKind::TStructGetU(_, _, _) => {
        effects.reads_memory = true
        effects.traps = true
      }
      TInstrKind::TStructSet(_, _, _, _) => {
        effects.writes_memory = true
        effects.traps = true
      }
      TInstrKind::TArrayNew(_, _, _)
      | TInstrKind::TArrayNewDefault(_, _)
      | TInstrKind::TArrayNewFixed(_, _)
      | TInstrKind::TArrayNewData(_, _, _, _)
      | TInstrKind::TArrayNewElem(_, _, _, _) => {
        effects.writes_memory = true
        effects.traps = true
      }
      TInstrKind::TArrayGet(_, _, _)
      | TInstrKind::TArrayGetS(_, _, _)
      | TInstrKind::TArrayGetU(_, _, _)
      | TInstrKind::TArrayLen(_) => {
        effects.reads_memory = true
        effects.traps = true
      }
      TInstrKind::TArraySet(_, _, _, _)
      | TInstrKind::TArrayFill(_, _, _, _, _)
      | TInstrKind::TArrayCopy(_, _, _, _, _, _, _)
      | TInstrKind::TArrayInitData(_, _, _, _, _, _)
      | TInstrKind::TArrayInitElem(_, _, _, _, _, _) => {
        effects.reads_memory = true
        effects.writes_memory = true
        effects.traps = true
      }
      TInstrKind::TBinary(op, _, _) =>
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
      TInstrKind::TUnary(op, _) =>
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
      _ => ()
    }
    self.walk_tinstruction_default((), curr)
  })
  ignore(walker.walk_tinstruction((), instr))
  effects
}

///|
fn licm_local_idx_to_int(idx : LocalIdx) -> Int {
  let LocalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn licm_count_set(map : Map[Int, Int], local_idx : LocalIdx) -> Unit {
  let key = licm_local_idx_to_int(local_idx)
  map[key] = map.get(key).unwrap_or(0) + 1
}

///|
fn licm_is_const_instr(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TI32Const(_)
    | TInstrKind::TI64Const(_)
    | TInstrKind::TF32Const(_)
    | TInstrKind::TF64Const(_)
    | TInstrKind::TRefNull(_)
    | TInstrKind::TRefFunc(_)
    | TInstrKind::TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
      true
    _ => false
  }
}

///|
fn licm_is_void_block_type(bt : BlockType) -> Bool {
  match bt {
    VoidBlockType => true
    _ => false
  }
}

///|
fn licm_is_none_typed(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TNop
    | TInstrKind::TDrop(_)
    | TInstrKind::TLocalSet(_, _)
    | TInstrKind::TGlobalSet(_, _)
    | TInstrKind::TStore(_, _, _, _)
    | TInstrKind::TMemoryFill(_, _, _, _)
    | TInstrKind::TMemoryCopy(_, _, _, _, _)
    | TInstrKind::TMemoryInit(_, _, _, _, _)
    | TInstrKind::TDataDrop(_)
    | TInstrKind::TTableSet(_, _, _)
    | TInstrKind::TTableFill(_, _, _, _)
    | TInstrKind::TTableCopy(_, _, _, _, _)
    | TInstrKind::TTableInit(_, _, _, _, _)
    | TInstrKind::TElemDrop(_)
    | TInstrKind::TBr(_, _)
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
    | TInstrKind::TThrowRef(_)
    | TInstrKind::TUnreachable
    | TInstrKind::TStructSet(_, _, _, _)
    | TInstrKind::TArraySet(_, _, _, _)
    | TInstrKind::TArrayFill(_, _, _, _, _)
    | TInstrKind::TArrayCopy(_, _, _, _, _, _, _)
    | TInstrKind::TArrayInitData(_, _, _, _, _, _)
    | TInstrKind::TArrayInitElem(_, _, _, _, _, _)
    | TInstrKind::TV128StoreLane(_, _, _, _, _) => true
    TInstrKind::TBlock(bt, _)
    | TInstrKind::TLoop(bt, _)
    | TInstrKind::TIf(bt, _, _, _)
    | TInstrKind::TTryTable(bt, _, _) => licm_is_void_block_type(bt)
    _ => false
  }
}

///|
fn licm_local_set_chain_final_rhs(value : TInstr) -> TInstr {
  let mut curr = value
  let mut done = false
  while !done {
    match curr.kind {
      TInstrKind::TLocalSet(_, next) => curr = next
      TInstrKind::TLocalTee(_, next) => curr = next
      _ => done = true
    }
  }
  curr
}

///|
fn licm_interesting_to_move(curr : TInstr) -> Bool {
  if !licm_is_none_typed(curr) {
    return false
  }
  match curr.kind {
    TInstrKind::TNop | TInstrKind::TBlock(_, _) | TInstrKind::TLoop(_, _) =>
      false
    TInstrKind::TLocalSet(_, value) => {
      let final_rhs = licm_local_set_chain_final_rhs(value)
      match final_rhs.kind {
        TInstrKind::TLocalGet(_) => false
        _ => !licm_is_const_instr(final_rhs)
      }
    }
    _ => true
  }
}

///|
fn licm_collect_get_ids(curr : TInstr, start_get_id : Int) -> (Array[Int], Int) {
  let ids : Array[Int] = []
  let next_get = Ref::new(start_get_id)
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr.kind {
      TInstrKind::TLocalGet(_) => {
        ids.push(next_get.val)
        next_get.update(fn(n) { n + 1 })
      }
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_tinstruction((), curr))
  (ids, next_get.val)
}

///|
fn licm_has_get_depending_on_loop_set(
  get_ids : Array[Int],
  local_graph : LocalGraph,
  loop_sets : Set[TInstr],
) -> Bool {
  for get_id in get_ids {
    let sets = local_graph.get_sets(get_id)
    for set_ in sets {
      match set_ {
        LocalSet::InitValue => ()
        LocalSet::Set(_, root) => if loop_sets.contains(root) { return true }
      }
    }
  }
  false
}

///|
priv struct LICMSetInfo {
  set_indices : Array[Int]
  local_sets : Array[TInstr]
}

///|
fn licm_collect_set_info(instr : TInstr) -> LICMSetInfo {
  let set_indices : Array[Int] = []
  let local_sets : Array[TInstr] = []
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    match curr.kind {
      TInstrKind::TLocalSet(idx, _) => {
        set_indices.push(licm_local_idx_to_int(idx))
        local_sets.push(curr)
      }
      TInstrKind::TLocalTee(idx, _) =>
        set_indices.push(licm_local_idx_to_int(idx))
      _ => ()
    }
    self.walk_tinstruction_default((), curr)
  })
  ignore(walker.walk_tinstruction((), instr))
  { set_indices, local_sets }
}

///|
fn licm_collect_loop_sets_and_counts(
  body : TExpr,
) -> (Set[TInstr], Map[Int, Int]) {
  let loop_sets : Set[TInstr] = Set::new()
  let num_sets_for_index : Map[Int, Int] = Map::new()
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr.kind {
      TInstrKind::TLocalSet(idx, _) => {
        loop_sets.add(instr)
        licm_count_set(num_sets_for_index, idx)
      }
      TInstrKind::TLocalTee(idx, _) => licm_count_set(num_sets_for_index, idx)
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  (loop_sets, num_sets_for_index)
}

///|
fn licm_visit_loop(
  loop_instr : TInstr,
  loop_body_start_get_id : Int,
  local_graph : LocalGraph,
) -> TInstr {
  match loop_instr.kind {
    TInstrKind::TLoop(loop_type, loop_body) => {
      let moved_code : Array[TInstr] = []
      let effects_so_far = LICMEffects::new()
      let loop_effects = licm_collect_effects(loop_instr)
      let (loop_sets, num_sets_for_index) = licm_collect_loop_sets_and_counts(
        loop_body,
      )
      fn scan_entrance(
        body : TExpr,
        start_get_id : Int,
      ) -> (TExpr, Int, Bool, Bool) {
        let items = body.instrs.copy()
        let mut changed = false
        let mut next_get_id = start_get_id
        for i = 0; i < items.length(); i = i + 1 {
          match items[i] {
            { kind: TInstrKind::TBlock(bt, child_body), .. } => {
              let (next_body, next_get, stop, child_changed) = scan_entrance(
                child_body, next_get_id,
              )
              next_get_id = next_get
              if child_changed {
                changed = true
                items[i] = TInstr::block(bt, next_body)
              }
              if stop {
                return (TExpr::new(items), next_get_id, true, changed)
              }
            }
            curr => {
              let curr_effects = licm_collect_effects(curr)
              let (curr_get_ids, next_get) = licm_collect_get_ids(
                curr, next_get_id,
              )
              next_get_id = next_get
              if curr_effects.transfers_control_flow() {
                return (TExpr::new(items), next_get_id, true, changed)
              }
              if licm_interesting_to_move(curr) {
                let mut unsafe_to_move = curr_effects.writes_global_state() ||
                  effects_so_far.invalidates(curr_effects) ||
                  (
                    curr_effects.reads_mutable_global_state() &&
                    loop_effects.writes_global_state()
                  ) ||
                  curr_effects.throws ||
                  loop_effects.throws
                if !unsafe_to_move && curr_effects.locals_read.length() > 0 {
                  unsafe_to_move = licm_has_get_depending_on_loop_set(
                    curr_get_ids, local_graph, loop_sets,
                  )
                }
                if !unsafe_to_move {
                  let set_info = licm_collect_set_info(curr)
                  for idx in set_info.set_indices {
                    num_sets_for_index[idx] = num_sets_for_index
                      .get(idx)
                      .unwrap_or(0) -
                      1
                  }
                  let mut interferes = false
                  for idx in set_info.set_indices {
                    if num_sets_for_index.get(idx).unwrap_or(0) > 0 {
                      interferes = true
                      break
                    }
                  }
                  if interferes {
                    for idx in set_info.set_indices {
                      num_sets_for_index[idx] = num_sets_for_index
                        .get(idx)
                        .unwrap_or(0) +
                        1
                    }
                  } else {
                    moved_code.push(curr)
                    items[i] = TInstr::nop()
                    changed = true
                    for set_ in set_info.local_sets {
                      loop_sets.remove(set_)
                    }
                    continue
                  }
                }
              }
              effects_so_far.merge(curr_effects)
            }
          }
        }
        (TExpr::new(items), next_get_id, false, changed)
      }

      let (next_loop_body, _, _, body_changed) = scan_entrance(
        loop_body, loop_body_start_get_id,
      )
      if moved_code.is_empty() {
        if body_changed {
          TInstr::loop_(loop_type, next_loop_body)
        } else {
          loop_instr
        }
      } else {
        let preheader_items = moved_code.copy()
        preheader_items.push(TInstr::loop_(loop_type, next_loop_body))
        TInstr::block(loop_type, TExpr::new(preheader_items))
      }
    }
    _ => loop_instr
  }
}

///|
fn licm_collect_loop_entry_get_ids(body : TExpr) -> Array[Int] {
  let ids : Array[Int] = []
  let next_get_id = Ref::new(0)
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr.kind {
      TInstrKind::TLoop(_, _) => ids.push(next_get_id.val)
      TInstrKind::TLocalGet(_) => next_get_id.update(fn(n) { n + 1 })
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  ids
}

///|
fn licm_run_on_body(body : TExpr) -> (TExpr, Bool) {
  let mut curr_body = body
  let mut changed_any = false

  // Hoisting only moves expressions outward; rounds ensure nested-loop
  // opportunities can bubble to outer loops deterministically.
  let mut rounds = 0
  while rounds < 64 {
    let local_graph = LocalGraph::new(curr_body.instrs)
    let loop_entry_get_ids = licm_collect_loop_entry_get_ids(curr_body)
    let loop_visit = Ref::new(0)
    let licm_pass = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      instr,
    ) {
      match instr.kind {
        TInstrKind::TLoop(_, _) => {
          let loop_index = loop_visit.val
          loop_visit.update(fn(n) { n + 1 })
          let walked = match self.walk_tinstruction_default((), instr) {
            Ok(Some((_, updated))) => updated
            Ok(None) => instr
            Err(e) => return Err(e)
          }
          if loop_index >= loop_entry_get_ids.length() {
            if walked == instr {
              unchanged()
            } else {
              change((), walked)
            }
          } else {
            let rewritten = licm_visit_loop(
              walked,
              loop_entry_get_ids[loop_index],
              local_graph,
            )
            if rewritten == instr {
              unchanged()
            } else {
              change((), rewritten)
            }
          }
        }
        _ => self.walk_tinstruction_default((), instr)
      }
    })
    let next_body = match licm_pass.walk_texpr((), curr_body) {
      Ok(Some((_, updated))) => updated
      Ok(None) => curr_body
      Err(_) => curr_body
    }
    if next_body == curr_body {
      break
    }
    changed_any = true
    curr_body = next_body
    rounds += 1
  }
  (curr_body, changed_any)
}

///|
fn loop_invariant_code_motion_pass() -> ModuleTransformer[Unit] {
  ModuleTransformer::new().on_func_evt(fn(_, _, func) {
    match func {
      TFunc(locals, body) => {
        let (next_body, changed) = licm_run_on_body(body)
        if changed {
          change((), Func::t_func(locals, next_body))
        } else {
          unchanged()
        }
      }
      _ => unchanged()
    }
  })
}

///|
fn loop_invariant_code_motion_ir_pass(
  _mod : Module,
) -> ModuleTransformer[IRContext] {
  wrap_unit_func_pass(loop_invariant_code_motion_pass())
}

///|
fn licm_optimize(mod : Module) -> Module {
  optimize_module(mod, [ModulePass::LoopInvariantCodeMotion]).unwrap()
}

///|
fn licm_single_func_mod(locals : Array[ValType], body : TExpr) -> Module {
  Module::new().with_code_sec(CodeSec::new([Func::t_func(locals, body)]))
}

///|
test "licm hoists basic none-typed local.set from loop entrance" {
  let body = TExpr::new([
    TInstr::loop_(
      BlockType::void_(),
      TExpr::new([
        TInstr::local_set(
          LocalIdx::new(1),
          TInstr::binary(
            BinaryOp::i32_add(),
            TInstr::local_get(LocalIdx::new(0)),
            TInstr::i32_const(I32(1)),
          ),
        ),
        TInstr::nop(),
      ]),
    ),
  ])
  let mod = licm_single_func_mod([ValType::i32(), ValType::i32()], body)
  let optimized = licm_optimize(mod)
  match optimized.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                { kind: TInstrKind::TBlock(_, { instrs: items, .. }), .. },
              ],
              ..,
            }
          ),
        ]
      )
    ) =>
      match items {
        [
          { kind: TInstrKind::TLocalSet(_, _), .. },
          {
            kind: TInstrKind::TLoop(
              _,
              {
                instrs: [
                  { kind: TInstrKind::TNop, .. },
                  { kind: TInstrKind::TNop, .. },
                ],
                ..,
              }
            ),
            ..,
          },
        ] => ()
        _ => fail("expected preheader local.set and nopped original")
      }
    _ => fail("expected block-wrapped loop after LICM")
  }
}

///|
test "licm stops scanning after control-transfer instruction" {
  let body = TExpr::new([
    TInstr::loop_(
      BlockType::void_(),
      TExpr::new([
        TInstr::local_set(
          LocalIdx::new(1),
          TInstr::binary(
            BinaryOp::i32_add(),
            TInstr::local_get(LocalIdx::new(0)),
            TInstr::i32_const(I32(1)),
          ),
        ),
        TInstr::br_if(LabelIdx::new(0), TInstr::i32_const(I32(1)), []),
        TInstr::local_set(
          LocalIdx::new(2),
          TInstr::binary(
            BinaryOp::i32_add(),
            TInstr::local_get(LocalIdx::new(0)),
            TInstr::i32_const(I32(2)),
          ),
        ),
      ]),
    ),
  ])
  let mod = licm_single_func_mod(
    [ValType::i32(), ValType::i32(), ValType::i32()],
    body,
  )
  let optimized = licm_optimize(mod)
  match optimized.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                { kind: TInstrKind::TBlock(_, { instrs: items, .. }), .. },
              ],
              ..,
            }
          ),
        ]
      )
    ) =>
      match items {
        [
          { kind: TInstrKind::TLocalSet(LocalIdx(i), _), .. },
          {
            kind: TInstrKind::TLoop(
              _,
              {
                instrs: [
                  { kind: TInstrKind::TNop, .. },
                  { kind: TInstrKind::TBrIf(_, _, _), .. },
                  { kind: TInstrKind::TLocalSet(LocalIdx(j), _), .. },
                ],
                ..,
              }
            ),
            ..,
          },
        ] => {
          assert_eq(i.reinterpret_as_int(), 1)
          assert_eq(j.reinterpret_as_int(), 2)
        }
        _ => fail("expected only first entrance expression hoisted")
      }
    _ => fail("expected transformed loop")
  }
}

///|
test "licm does not hoist when get depends on loop local.set" {
  let body = TExpr::new([
    TInstr::loop_(
      BlockType::void_(),
      TExpr::new([
        TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(3))),
        TInstr::local_set(
          LocalIdx::new(1),
          TInstr::binary(
            BinaryOp::i32_add(),
            TInstr::local_get(LocalIdx::new(0)),
            TInstr::i32_const(I32(1)),
          ),
        ),
      ]),
    ),
  ])
  let mod = licm_single_func_mod([ValType::i32(), ValType::i32()], body)
  let optimized = licm_optimize(mod)
  assert_eq(optimized, mod)
}

///|
test "licm does not hoist global-state writers" {
  let body = TExpr::new([
    TInstr::loop_(
      BlockType::void_(),
      TExpr::new([
        TInstr::global_set(GlobalIdx::new(0), TInstr::i32_const(I32(1))),
      ]),
    ),
  ])
  let mod = licm_single_func_mod([], body)
  let optimized = licm_optimize(mod)
  assert_eq(optimized, mod)
}

///|
test "licm respects effectsSoFar invalidation" {
  let memarg = MemArg::new(0, None, 0)
  let body = TExpr::new([
    TInstr::loop_(
      BlockType::void_(),
      TExpr::new([
        TInstr::store(
          StoreOp::i32_store(),
          memarg,
          TInstr::i32_const(I32(0)),
          TInstr::i32_const(I32(7)),
        ),
        TInstr::local_set(
          LocalIdx::new(0),
          TInstr::load(LoadOp::i32_load(), memarg, TInstr::i32_const(I32(0))),
        ),
      ]),
    ),
  ])
  let mod = licm_single_func_mod([ValType::i32()], body)
  let optimized = licm_optimize(mod)
  assert_eq(optimized, mod)
}

///|
test "licm blocks read-hoist when loop writes mutable global state" {
  let memarg = MemArg::new(0, None, 0)
  let body = TExpr::new([
    TInstr::loop_(
      BlockType::void_(),
      TExpr::new([
        TInstr::local_set(
          LocalIdx::new(0),
          TInstr::load(LoadOp::i32_load(), memarg, TInstr::i32_const(I32(0))),
        ),
        TInstr::store(
          StoreOp::i32_store(),
          memarg,
          TInstr::i32_const(I32(0)),
          TInstr::i32_const(I32(1)),
        ),
      ]),
    ),
  ])
  let mod = licm_single_func_mod([ValType::i32()], body)
  let optimized = licm_optimize(mod)
  assert_eq(optimized, mod)
}

///|
test "licm local-set interference blocks hoisting when same index has other sets" {
  let body = TExpr::new([
    TInstr::loop_(
      BlockType::void_(),
      TExpr::new([
        TInstr::local_set(
          LocalIdx::new(0),
          TInstr::binary(
            BinaryOp::i32_add(),
            TInstr::local_get(LocalIdx::new(1)),
            TInstr::i32_const(I32(1)),
          ),
        ),
        TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(9))),
      ]),
    ),
  ])
  let mod = licm_single_func_mod([ValType::i32(), ValType::i32()], body)
  let optimized = licm_optimize(mod)
  assert_eq(optimized, mod)
}

///|
test "licm rejects local.set copy and const-chain patterns" {
  let body = TExpr::new([
    TInstr::loop_(
      BlockType::void_(),
      TExpr::new([
        TInstr::local_set(LocalIdx::new(0), TInstr::local_get(LocalIdx::new(1))),
        TInstr::local_set(
          LocalIdx::new(2),
          TInstr::local_set(LocalIdx::new(3), TInstr::i32_const(I32(42))),
        ),
      ]),
    ),
  ])
  let mod = licm_single_func_mod(
    [ValType::i32(), ValType::i32(), ValType::i32(), ValType::i32()],
    body,
  )
  let optimized = licm_optimize(mod)
  assert_eq(optimized, mod)
}

///|
test "licm hoists nested-loop invariant outward in one run" {
  let inner = TInstr::loop_(
    BlockType::void_(),
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(1),
        TInstr::binary(
          BinaryOp::i32_add(),
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::i32_const(I32(1)),
        ),
      ),
      TInstr::nop(),
    ]),
  )
  let outer = TInstr::loop_(BlockType::void_(), TExpr::new([inner]))
  let mod = licm_single_func_mod(
    [ValType::i32(), ValType::i32()],
    TExpr::new([outer]),
  )
  let optimized = licm_optimize(mod)
  match optimized.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                { kind: TInstrKind::TBlock(_, { instrs: items, .. }), .. },
              ],
              ..,
            }
          ),
        ]
      )
    ) =>
      match items {
        [
          { kind: TInstrKind::TLocalSet(_, _), .. },
          { kind: TInstrKind::TLoop(_, _), .. },
        ] => ()
        _ => fail("expected nested hoist to reach outer preheader")
      }
    _ => fail("expected block preheader around outer loop")
  }
}

///|
test "licm is conservative when loop may throw" {
  let body = TExpr::new([
    TInstr::loop_(
      BlockType::void_(),
      TExpr::new([
        TInstr::local_set(
          LocalIdx::new(0),
          TInstr::binary(
            BinaryOp::i32_add(),
            TInstr::local_get(LocalIdx::new(1)),
            TInstr::i32_const(I32(1)),
          ),
        ),
        TInstr::throw_ref(
          TInstr::ref_null(HeapType::abs(AbsHeapType::extern_())),
        ),
      ]),
    ),
  ])
  let mod = licm_single_func_mod([ValType::i32(), ValType::i32()], body)
  let optimized = licm_optimize(mod)
  assert_eq(optimized, mod)
}

///|
test "licm handles nested blocks/unreachable without crashing" {
  let body = TExpr::new([
    TInstr::loop_(
      BlockType::void_(),
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([
            TInstr::local_set(
              LocalIdx::new(0),
              TInstr::binary(
                BinaryOp::i32_add(),
                TInstr::local_get(LocalIdx::new(1)),
                TInstr::i32_const(I32(1)),
              ),
            ),
          ]),
        ),
        TInstr::unreachable_(),
      ]),
    ),
  ])
  let mod = licm_single_func_mod([ValType::i32(), ValType::i32()], body)
  let optimized = licm_optimize(mod)
  match optimized.code_sec {
    Some(CodeSec(_)) => ()
    _ => fail("expected module with code section")
  }
}

///|
test "licm is idempotent on second run" {
  let body = TExpr::new([
    TInstr::loop_(
      BlockType::void_(),
      TExpr::new([
        TInstr::local_set(
          LocalIdx::new(1),
          TInstr::binary(
            BinaryOp::i32_add(),
            TInstr::local_get(LocalIdx::new(0)),
            TInstr::i32_const(I32(1)),
          ),
        ),
      ]),
    ),
  ])
  let mod = licm_single_func_mod([ValType::i32(), ValType::i32()], body)
  let once = licm_optimize(mod)
  let twice = licm_optimize(once)
  assert_eq(once, twice)
}
