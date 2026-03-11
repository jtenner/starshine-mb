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
fn run_trace_noop(_ : String) -> Unit {
  ()
}

///|
const RUN_BRANCH_TO_SCOPE_FOUND : String = "__remove_unused_names_branch_to_scope_found__"

///|
fn run_label_to_int(label : LabelIdx) -> Int {
  let LabelIdx(raw) = label
  raw.reinterpret_as_int()
}

///|
fn run_label_from_int(idx : Int) -> LabelIdx {
  LabelIdx::new(idx.reinterpret_as_uint())
}

///|
fn run_walk_tinstruction_with_depth(
  transformer : ModuleTransformer[Int, String],
  depth : Int,
  instr : TInstr,
) -> VisitAction[Int, TInstr, String] {
  match instr.kind {
    TInstrKind::TBlock(bt, body) => {
      let next_body = match transformer.walk_texpr(depth + 1, body) {
        Ok((out, _)) => out
        Err(e) => return error(e)
      }
      if next_body == body {
        unchanged()
      } else {
        change(depth, TInstr::block(bt, next_body))
      }
    }
    TInstrKind::TLoop(bt, body) => {
      let next_body = match transformer.walk_texpr(depth + 1, body) {
        Ok((out, _)) => out
        Err(e) => return error(e)
      }
      if next_body == body {
        unchanged()
      } else {
        change(depth, TInstr::loop_(bt, next_body))
      }
    }
    TInstrKind::TIf(bt, cond, then_body, else_body) => {
      let next_cond = match transformer.walk_tinstruction(depth, cond) {
        Ok((out, _)) => out
        Err(e) => return error(e)
      }
      let next_then = match transformer.walk_texpr(depth + 1, then_body) {
        Ok((out, _)) => out
        Err(e) => return error(e)
      }
      let next_else = match else_body {
        Some(other) =>
          match transformer.walk_texpr(depth + 1, other) {
            Ok((out, _)) => Some(out)
            Err(e) => return error(e)
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
        Ok((out, _)) => out
        Err(e) => return error(e)
      }
      let next_body = match transformer.walk_texpr(depth + 1, body) {
        Ok((out, _)) => out
        Err(e) => return error(e)
      }
      let next_instr = TInstr::try_table(bt, next_catches, next_body)
      if next_instr == instr {
        unchanged()
      } else {
        change(depth, next_instr)
      }
    }
    _ => from_walk(transformer.walk_tinstruction_default(depth, instr))
  }
}

///|
fn run_rebase_label_for_removed_scopes(
  label : LabelIdx,
  depth : Int,
  removed_scopes : Int,
) -> LabelIdx {
  if removed_scopes <= 0 {
    return label
  }
  let curr = run_label_to_int(label)
  if curr < depth {
    label
  } else if curr <= depth + removed_scopes {
    run_label_from_int(depth)
  } else {
    run_label_from_int(curr - removed_scopes)
  }
}

///|
fn run_rebase_labels_for_removed_scopes(
  body : TExpr,
  removed_scopes : Int,
) -> Result[TExpr, String] {
  if removed_scopes <= 0 {
    return Ok(body)
  }
  let pass = ModuleTransformer::new()
    .on_labelidx_evt(fn(_, depth, label) {
      let next = run_rebase_label_for_removed_scopes(
        label, depth, removed_scopes,
      )
      if next == label {
        unchanged()
      } else {
        change(depth, next)
      }
    })
    .on_tinstruction_evt(fn(self, depth, instr) {
      run_walk_tinstruction_with_depth(self, depth, instr)
    })
  match pass.walk_texpr(0, body) {
    Ok((out, _)) => Ok(out)
    Err(e) => Err(e)
  }
}

///|
fn run_peel_single_child_same_blocks(
  bt : BlockType,
  body : TExpr,
) -> (Int, TExpr) {
  let mut removed = 0
  let mut curr = body
  while true {
    match curr {
      { instrs: [{ kind: TInstrKind::TBlock(child_bt, child_body), .. }], .. } =>
        if child_bt == bt {
          removed += 1
          curr = child_body
        } else {
          break
        }
      _ => break
    }
  }
  (removed, curr)
}

///|
fn run_has_branch_to_current_scope(body : TExpr) -> Result[Bool, String] {
  let pass = ModuleTransformer::new()
    .on_labelidx_evt(fn(_, depth, label) {
      if run_label_to_int(label) == depth {
        return error(RUN_BRANCH_TO_SCOPE_FOUND)
      }
      unchanged()
    })
    .on_tinstruction_evt(fn(self, depth, instr) {
      run_walk_tinstruction_with_depth(self, depth, instr)
    })
  match pass.walk_texpr(0, body) {
    Ok(_) => Ok(false)
    Err(e) => if e == RUN_BRANCH_TO_SCOPE_FOUND { Ok(true) } else { Err(e) }
  }
}

///|
fn run_remove_unused_names_once(body : TExpr) -> Result[(TExpr, Bool), String] {
  let pass = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    let mut seed = instr
    match instr.kind {
      TInstrKind::TBlock(bt, block_body) => {
        let (removed, peeled) = run_peel_single_child_same_blocks(
          bt, block_body,
        )
        if removed > 0 {
          let rebased = match
            run_rebase_labels_for_removed_scopes(peeled, removed) {
            Ok(out) => out
            Err(e) => return error(e)
          }
          seed = TInstr::block(bt, rebased)
        }
      }
      _ => ()
    }

    let walked = match self.walk_tinstruction_default((), seed) {
      Ok((out, _)) => out
      Err(e) => return error(e)
    }

    let rewritten = match walked.kind {
      TInstrKind::TBlock(bt, block_body) => {
        let (removed, peeled) = run_peel_single_child_same_blocks(
          bt, block_body,
        )
        if removed > 0 {
          match run_rebase_labels_for_removed_scopes(peeled, removed) {
            Ok(rebased) => TInstr::block(bt, rebased)
            Err(e) => return error(e)
          }
        } else {
          walked
        }
      }
      TInstrKind::TLoop(bt, loop_body) =>
        match run_has_branch_to_current_scope(loop_body) {
          Ok(true) => walked
          Ok(false) => TInstr::block(bt, loop_body)
          Err(e) => return error(e)
        }
      _ => walked
    }

    if rewritten == instr {
      unchanged()
    } else {
      change((), rewritten)
    }
  })

  match pass.walk_texpr((), body) {
    Ok((out, _)) => Ok((out, out != body))
    Err(e) => Err(e)
  }
}

///|
fn remove_unused_names_ir_pass(
  _mod : Module,
  trace? : (String) -> Unit = run_trace_noop,
  trace_all_funcs? : Bool = false,
  trace_budget? : Bool = true,
) -> ModuleTransformer[IRContext, String] {
  let next_def_idx = Ref::new(0)
  ModuleTransformer::new().on_func_evt(fn(_, ctx, func) {
    let def_idx = next_def_idx.val
    next_def_idx.update(fn(i) { i + 1 })
    let ordinal = def_idx + 1
    let log_func = trace_budget &&
      pass_trace_log_enabled(ordinal, trace_all_funcs)

    match func {
      TFunc(params, locals, body) =>
        match run_remove_unused_names_once(body) {
          Ok((next_body, changed)) => {
            if log_func {
              trace(
                "func[\{ordinal}] changed=\{changed} top_instrs=\{body.instrs.length()}->\{next_body.instrs.length()}",
              )
            }
            if !changed {
              unchanged()
            } else {
              change(ctx, Func::t_func(params, locals, next_body))
            }
          }
          Err(e) => error(e)
        }
      _ => unchanged()
    }
  })
}

///|
fn run_remove_unused_names(
  mod : Module,
  trace? : (String) -> Unit = run_trace_noop,
  trace_all_funcs? : Bool = false,
  trace_budget? : Bool = true,
) -> Module {
  let pass = remove_unused_names_ir_pass(
    mod,
    trace~,
    trace_all_funcs~,
    trace_budget~,
  )
  match pass.walk_module(IRContext::new(), mod) {
    Ok((out, _)) => out
    Err(e) => abort("remove_unused_names_ir_pass failed: \{e}")
  }
}

///|
fn run_single_func(mod : Module) -> Func {
  match mod.code_sec {
    Some(CodeSec([func])) => func
    _ => abort("expected exactly one function")
  }
}

///|
test "remove_unused_names merges single-child same-typed nested blocks" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([TInstr::i32_const(I32(7))]),
        ),
      ]),
    ),
  ])
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([], [], body)]),
  )
  let out = run_remove_unused_names(mod)
  match run_single_func(out) {
    TFunc(
      [],
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
    _ => fail("expected outer block to merge into child block")
  }
}

///|
test "remove_unused_names retargets branch depth when merging nested blocks" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::block(
          BlockType::void_(),
          TExpr::new([
            TInstr::block(
              BlockType::void_(),
              TExpr::new([TInstr::br(LabelIdx::new(2), [])]),
            ),
          ]),
        ),
      ]),
    ),
  ])
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([], [], body)]),
  )
  let out = run_remove_unused_names(mod)
  match run_single_func(out) {
    TFunc(
      [],
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              { instrs: [{ kind: TInstrKind::TBr(LabelIdx(next), _), .. }], .. }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => assert_eq(next.reinterpret_as_int(), 0)
    _ =>
      fail(
        "expected branch depth to be decremented after removing one block scope",
      )
  }
}

///|
test "remove_unused_names preserves typed branch target arity after nested block merge" {
  let body = TExpr::new([
    TInstr::drop(
      TInstr::block(
        BlockType::val_type(ValType::i32()),
        TExpr::new([
          TInstr::block(
            BlockType::val_type(ValType::i32()),
            TExpr::new([
              TInstr::block(
                BlockType::val_type(ValType::i32()),
                TExpr::new([
                  TInstr::br(LabelIdx::new(2), [TInstr::i32_const(I32(5))]),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ),
  ])
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([], [], body)]),
  )
  let out = run_remove_unused_names(mod)
  match run_single_func(out) {
    TFunc(
      [],
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
                          LabelIdx(next),
                          [{ kind: TInstrKind::TI32Const(I32(5)), .. }]
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
        ],
        ..,
      }
    ) => assert_eq(next.reinterpret_as_int(), 0)
    _ => fail("expected typed branch depth to be retargeted to merged parent")
  }
}

///|
test "remove_unused_names rewrites loop to block when no continue branch remains" {
  let body = TExpr::new([
    TInstr::loop_(BlockType::void_(), TExpr::new([TInstr::i32_const(I32(3))])),
  ])
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([], [], body)]),
  )
  let out = run_remove_unused_names(mod)
  match run_single_func(out) {
    TFunc(
      [],
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              { instrs: [{ kind: TInstrKind::TI32Const(I32(3)), .. }], .. }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ => fail("expected loop with no continue target to become block")
  }
}

///|
test "remove_unused_names keeps loop when body branches to loop label" {
  let body = TExpr::new([
    TInstr::loop_(
      BlockType::void_(),
      TExpr::new([TInstr::br(LabelIdx::new(0), [])]),
    ),
  ])
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([], [], body)]),
  )
  let out = run_remove_unused_names(mod)
  match run_single_func(out) {
    TFunc(_, _, { instrs: [{ kind: TInstrKind::TLoop(_, _), .. }], .. }) => ()
    _ => fail("expected loop with br 0 to remain a loop")
  }
}

///|
test "remove_unused_names rewrites non-void loop to block when no continue branch remains" {
  let body = TExpr::new([
    TInstr::loop_(
      BlockType::val_type(ValType::i32()),
      TExpr::new([TInstr::i32_const(I32(9))]),
    ),
  ])
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([], [], body)]),
  )
  let out = run_remove_unused_names(mod)
  match run_single_func(out) {
    TFunc(
      [],
      _,
      {
        instrs: [
          {
            kind: TInstrKind::TBlock(
              _,
              { instrs: [{ kind: TInstrKind::TI32Const(I32(9)), .. }], .. }
            ),
            ..,
          },
        ],
        ..,
      }
    ) => ()
    _ =>
      fail("expected non-void loop without continue branches to become block")
  }
}
