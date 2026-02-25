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
fn remove_unused_names_ir_pass(_mod : Module) -> ModuleTransformer[IRContext] {
  ModuleTransformer::new().on_func_evt(fn(_, ctx, func) {
    match func {
      TFunc(locals, body) =>
        match run_remove_unused_names_once(body) {
          Ok((next_body, _changed)) =>
            if next_body == body {
              unchanged()
            } else {
              change(ctx, Func::t_func(locals, next_body))
            }
          Err(e) => Err(e)
        }
      _ => unchanged()
    }
  })
}

///|
fn run_remove_unused_names(mod : Module) -> Module {
  let pass = remove_unused_names_ir_pass(mod)
  match pass.walk_module(IRContext::new(), mod) {
    Ok(Some((_, out))) => out
    Ok(None) => mod
    Err(e) => abort("remove_unused_names_ir_pass failed: \{e}")
  }
}

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
fn run_adjust_label_for_removed_scope(
  label : LabelIdx,
  depth : Int,
) -> LabelIdx {
  let curr = run_label_to_int(label)
  if curr > depth {
    run_label_from_int(curr - 1)
  } else {
    label
  }
}

///|
fn run_walk_tinstruction_with_depth(
  transformer : ModuleTransformer[Int],
  depth : Int,
  instr : TInstr,
) -> TransformerResult[Int, TInstr] {
  match instr {
    TBlock(bt, body) => {
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
    TLoop(bt, body) => {
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
    TIf(bt, cond, then_body, else_body) => {
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
    TTryTable(bt, catches, body) => {
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
fn run_shift_labels_for_removed_scope(body : TExpr) -> Result[TExpr, String] {
  let pass = ModuleTransformer::new()
    .on_labelidx_evt(fn(_, depth, label) {
      let next = run_adjust_label_for_removed_scope(label, depth)
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
    Ok(Some((_, out))) => Ok(out)
    Ok(None) => Ok(body)
    Err(e) => Err(e)
  }
}

///|
fn run_has_branch_to_current_scope(body : TExpr) -> Bool {
  let mut has_branch = false
  let pass = ModuleTransformer::new()
    .on_labelidx_evt(fn(_, depth, label) {
      if run_label_to_int(label) == depth {
        has_branch = true
      }
      unchanged()
    })
    .on_tinstruction_evt(fn(self, depth, instr) {
      run_walk_tinstruction_with_depth(self, depth, instr)
    })
  ignore(pass.walk_texpr(0, body))
  has_branch
}

///|
fn run_remove_unused_names_once(body : TExpr) -> Result[(TExpr, Bool), String] {
  let mut changed = false
  let pass = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    let walked = match self.walk_tinstruction_default((), instr) {
      Ok(Some((_, out))) => out
      Ok(None) => instr
      Err(e) => return Err(e)
    }
    let rewritten = match walked {
      TBlock(bt, TExpr(items)) =>
        match items {
          [TBlock(child_bt, child_body)] =>
            if child_bt == bt {
              let shifted = match
                run_shift_labels_for_removed_scope(child_body) {
                Ok(out) => out
                Err(e) => return Err(e)
              }
              changed = true
              TInstr::block(child_bt, shifted)
            } else {
              walked
            }
          _ => walked
        }
      TLoop(bt, loop_body) =>
        if bt == BlockType::void_() &&
          !run_has_branch_to_current_scope(loop_body) {
          changed = true
          TInstr::block(bt, loop_body)
        } else {
          walked
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
    Ok(Some((_, out))) => Ok((out, changed))
    Ok(None) => Ok((body, changed))
    Err(e) => Err(e)
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
  let mod = Module::new().with_code_sec(CodeSec::new([Func::t_func([], body)]))
  let out = run_remove_unused_names(mod)
  match run_single_func(out) {
    TFunc(_, TExpr([TBlock(_, TExpr([TI32Const(I32(7))]))])) => ()
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
  let mod = Module::new().with_code_sec(CodeSec::new([Func::t_func([], body)]))
  let out = run_remove_unused_names(mod)
  match run_single_func(out) {
    TFunc(_, TExpr([TBlock(_, TExpr([TBr(LabelIdx(next), _)]))])) =>
      assert_eq(next.reinterpret_as_int(), 0)
    _ =>
      fail(
        "expected branch depth to be decremented after removing one block scope",
      )
  }
}

///|
test "remove_unused_names rewrites loop to block when no continue branch remains" {
  let body = TExpr::new([
    TInstr::loop_(BlockType::void_(), TExpr::new([TInstr::i32_const(I32(3))])),
  ])
  let mod = Module::new().with_code_sec(CodeSec::new([Func::t_func([], body)]))
  let out = run_remove_unused_names(mod)
  match run_single_func(out) {
    TFunc(_, TExpr([TBlock(_, TExpr([TI32Const(I32(3))]))])) => ()
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
  let mod = Module::new().with_code_sec(CodeSec::new([Func::t_func([], body)]))
  let out = run_remove_unused_names(mod)
  match run_single_func(out) {
    TFunc(_, TExpr([TLoop(_, _)])) => ()
    _ => fail("expected loop with br 0 to remain a loop")
  }
}
