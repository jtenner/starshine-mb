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
fn rr_apply_ir_pass(
  mod : Module,
  pass : ModuleTransformer[IRContext],
) -> Result[Module, String] {
  let ctx = IRContext::new()
  match pass.walk_module(ctx, mod) {
    Ok(Some((_, out))) => Ok(out)
    Ok(None) => Ok(mod)
    Err(e) => Err(e)
  }
}

///|
fn rr_run_re_reloop(mod : Module) -> Result[Module, String] {
  rr_apply_ir_pass(mod, re_reloop_ir_pass(mod))
}

///|
fn rr_fixture_mergeable_block_module() -> Module {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  Module::new()
  .with_type_sec(TypeSec::new([t_void]))
  .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::block(
            BlockType::void_(),
            TExpr::new([TInstr::i32_const(I32(9)), TInstr::nop()]),
          ),
        ]),
      ),
    ]),
  )
}

///|
fn rr_fixture_flattened_branch_shell_module() -> Module {
  let t_with_param = single_rec_type(
    comp_type_sub_type(func_comp_type([ValType::i32()], [])),
  )
  Module::new()
  .with_type_sec(TypeSec::new([t_with_param]))
  .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::block(
            BlockType::void_(),
            TExpr::new([
              TInstr::br_if(
                LabelIdx::new(0),
                TInstr::local_get(LocalIdx::new(0)),
                [],
              ),
              TInstr::drop(TInstr::i32_const(I32(7))),
            ]),
          ),
          TInstr::nop(),
        ]),
      ),
    ]),
  )
}

///|
fn rr_fixture_flattened_bron_block_module() -> Module {
  let t_with_ref = single_rec_type(
    comp_type_sub_type(func_comp_type([ValType::funcref()], [])),
  )
  Module::new()
  .with_type_sec(TypeSec::new([t_with_ref]))
  .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::block(
            BlockType::void_(),
            TExpr::new([
              TInstr::br_on_null(
                LabelIdx::new(0),
                TInstr::local_get(LocalIdx::new(0)),
                [],
              ),
              TInstr::drop(TInstr::i32_const(I32(21))),
            ]),
          ),
          TInstr::nop(),
        ]),
      ),
    ]),
  )
}

///|
fn rr_fixture_flattened_bron_family_module() -> Module {
  let t_with_ref = single_rec_type(
    comp_type_sub_type(func_comp_type([ValType::funcref()], [])),
  )
  let src_ht = HeapType::abs(AbsHeapType::func())
  let dst_ht = HeapType::abs(AbsHeapType::func())
  Module::new()
  .with_type_sec(TypeSec::new([t_with_ref]))
  .with_func_sec(
    FuncSec::new([
      TypeIdx::new(0),
      TypeIdx::new(0),
      TypeIdx::new(0),
      TypeIdx::new(0),
    ]),
  )
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::block(
            BlockType::void_(),
            TExpr::new([
              TInstr::br_on_null(
                LabelIdx::new(0),
                TInstr::local_get(LocalIdx::new(0)),
                [],
              ),
              TInstr::drop(TInstr::i32_const(I32(1))),
            ]),
          ),
        ]),
      ),
      Func::t_func(
        [],
        TExpr::new([
          TInstr::block(
            BlockType::void_(),
            TExpr::new([
              TInstr::br_on_non_null(
                LabelIdx::new(0),
                TInstr::local_get(LocalIdx::new(0)),
                [],
              ),
              TInstr::drop(TInstr::i32_const(I32(2))),
            ]),
          ),
        ]),
      ),
      Func::t_func(
        [],
        TExpr::new([
          TInstr::block(
            BlockType::void_(),
            TExpr::new([
              TInstr::br_on_cast(
                LabelIdx::new(0),
                true,
                src_ht,
                false,
                dst_ht,
                TInstr::local_get(LocalIdx::new(0)),
                [],
              ),
              TInstr::drop(TInstr::i32_const(I32(3))),
            ]),
          ),
        ]),
      ),
      Func::t_func(
        [],
        TExpr::new([
          TInstr::block(
            BlockType::void_(),
            TExpr::new([
              TInstr::br_on_cast_fail(
                LabelIdx::new(0),
                true,
                src_ht,
                false,
                dst_ht,
                TInstr::local_get(LocalIdx::new(0)),
                [],
              ),
              TInstr::drop(TInstr::i32_const(I32(4))),
            ]),
          ),
        ]),
      ),
    ]),
  )
}

///|
fn rr_fixture_flattened_brtable_block_module() -> Module {
  let t_with_idx = single_rec_type(
    comp_type_sub_type(func_comp_type([ValType::i32()], [])),
  )
  Module::new()
  .with_type_sec(TypeSec::new([t_with_idx]))
  .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::block(
            BlockType::void_(),
            TExpr::new([
              TInstr::br_table(
                [LabelIdx::new(0), LabelIdx::new(0)],
                LabelIdx::new(0),
                TInstr::local_get(LocalIdx::new(0)),
                [],
              ),
              TInstr::drop(TInstr::i32_const(I32(99))),
            ]),
          ),
          TInstr::nop(),
        ]),
      ),
    ]),
  )
}

///|
fn rr_fixture_branch_value_flow_module() -> Module {
  let t_with_i32s = single_rec_type(
    comp_type_sub_type(
      func_comp_type([ValType::i32(), ValType::i32()], [ValType::i32()]),
    ),
  )
  Module::new()
  .with_type_sec(TypeSec::new([t_with_i32s]))
  .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::block(
            BlockType::val_type(ValType::i32()),
            TExpr::new([
              TInstr::br_if(
                LabelIdx::new(0),
                TInstr::local_get(LocalIdx::new(0)),
                [TInstr::local_get(LocalIdx::new(1))],
              ),
              TInstr::i32_const(I32(42)),
            ]),
          ),
        ]),
      ),
    ]),
  )
}

///|
fn rr_fixture_brtable_side_effect_index_module() -> Module {
  let t_i32 = single_rec_type(
    comp_type_sub_type(func_comp_type([], [ValType::i32()])),
  )
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  Module::new()
  .with_type_sec(TypeSec::new([t_i32, t_void]))
  .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
  .with_code_sec(
    CodeSec::new([
      Func::t_func([], TExpr::new([TInstr::i32_const(I32(1))])),
      Func::t_func(
        [],
        TExpr::new([
          TInstr::block(
            BlockType::void_(),
            TExpr::new([
              TInstr::br_table(
                [LabelIdx::new(0), LabelIdx::new(0)],
                LabelIdx::new(0),
                TInstr::call(FuncIdx::new(0), []),
                [],
              ),
              TInstr::drop(TInstr::i32_const(I32(44))),
            ]),
          ),
          TInstr::nop(),
        ]),
      ),
    ]),
  )
}

///|
fn rr_fixture_non_special_target_merge_module() -> Module {
  let t_with_conds = single_rec_type(
    comp_type_sub_type(func_comp_type([ValType::i32(), ValType::i32()], [])),
  )
  Module::new()
  .with_type_sec(TypeSec::new([t_with_conds]))
  .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::block(
            BlockType::void_(),
            TExpr::new([
              TInstr::block(
                BlockType::void_(),
                TExpr::new([
                  TInstr::br_if(
                    LabelIdx::new(1),
                    TInstr::local_get(LocalIdx::new(0)),
                    [],
                  ),
                  TInstr::br_if(
                    LabelIdx::new(0),
                    TInstr::local_get(LocalIdx::new(1)),
                    [],
                  ),
                  TInstr::drop(TInstr::i32_const(I32(5))),
                ]),
              ),
              TInstr::nop(),
            ]),
          ),
          TInstr::nop(),
        ]),
      ),
    ]),
  )
}

///|
fn rr_fixture_loop_backedge_module() -> Module {
  let t_with_cond = single_rec_type(
    comp_type_sub_type(func_comp_type([ValType::i32()], [])),
  )
  Module::new()
  .with_type_sec(TypeSec::new([t_with_cond]))
  .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::block(
            BlockType::void_(),
            TExpr::new([
              TInstr::loop_(
                BlockType::void_(),
                TExpr::new([
                  TInstr::br_if(
                    LabelIdx::new(1),
                    TInstr::local_get(LocalIdx::new(0)),
                    [],
                  ),
                  TInstr::br(LabelIdx::new(0), []),
                ]),
              ),
            ]),
          ),
          TInstr::nop(),
        ]),
      ),
    ]),
  )
}

///|
fn rr_fixture_non_flat_if_module() -> Module {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  Module::new()
  .with_type_sec(TypeSec::new([t_void]))
  .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::if_(
            BlockType::void_(),
            TInstr::block(
              BlockType::val_type(ValType::i32()),
              TExpr::new([TInstr::i32_const(I32(1))]),
            ),
            TExpr::new([TInstr::nop()]),
            None,
          ),
        ]),
      ),
    ]),
  )
}

///|
fn rr_fixture_try_table_module() -> Module {
  let t_void = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  Module::new()
  .with_type_sec(TypeSec::new([t_void]))
  .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::try_table(BlockType::void_(), [], TExpr::new([TInstr::nop()])),
        ]),
      ),
    ]),
  )
}

///|
fn rr_expect_error_contains(
  result : Result[Module, String],
  needle : String,
) -> Unit {
  match result {
    Ok(_) => abort("expected re_reloop to fail with: \{needle}")
    Err(e) =>
      if !e.contains(needle) {
        abort("expected error containing '\{needle}', got: \{e}")
      }
  }
}

///|
fn rr_texpr_contains(body : TExpr, pred : (TInstr) -> Bool) -> Bool {
  for instr in body.0 {
    if rr_tinstr_contains(instr, pred) {
      return true
    }
  }
  false
}

///|
fn rr_tinstr_contains(instr : TInstr, pred : (TInstr) -> Bool) -> Bool {
  if pred(instr) {
    return true
  }
  for child in rr_eval_children(instr) {
    if rr_tinstr_contains(child, pred) {
      return true
    }
  }
  match instr {
    TBlock(_, body) | TLoop(_, body) | TTryTable(_, _, body) =>
      rr_texpr_contains(body, pred)
    TIf(_, cond, then_body, else_body) => {
      if rr_tinstr_contains(cond, pred) || rr_texpr_contains(then_body, pred) {
        return true
      }
      match else_body {
        Some(other) => rr_texpr_contains(other, pred)
        None => false
      }
    }
    _ => false
  }
}

///|
fn rr_texpr_count(body : TExpr, pred : (TInstr) -> Bool) -> Int {
  let mut total = 0
  for instr in body.0 {
    total = total + rr_tinstr_count(instr, pred)
  }
  total
}

///|
fn rr_tinstr_count(instr : TInstr, pred : (TInstr) -> Bool) -> Int {
  let mut total = if pred(instr) { 1 } else { 0 }
  for child in rr_eval_children(instr) {
    total = total + rr_tinstr_count(child, pred)
  }
  match instr {
    TBlock(_, body) | TLoop(_, body) | TTryTable(_, _, body) =>
      total + rr_texpr_count(body, pred)
    TIf(_, cond, then_body, else_body) => {
      total = total +
        rr_tinstr_count(cond, pred) +
        rr_texpr_count(then_body, pred)
      match else_body {
        Some(other) => total + rr_texpr_count(other, pred)
        None => total
      }
    }
    _ => total
  }
}

///|
test "re_reloop rewrites mergeable block shells" {
  let mod = rr_fixture_mergeable_block_module()
  let out = match rr_run_re_reloop(mod) {
    Ok(next) => next
    Err(e) => fail("re_reloop should succeed on mergeable block fixture: \{e}")
  }
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TDrop(TI32Const(I32(v))), TNop]))])) =>
      assert_eq(v, 9)
    _ => fail("expected re_reloop to collapse wrapper block into plain body")
  }
}

///|
test "re_reloop output is validator-clean and idempotent" {
  let mod = rr_fixture_mergeable_block_module()
  let once = match rr_run_re_reloop(mod) {
    Ok(next) => next
    Err(e) => fail("re_reloop first run should succeed: \{e}")
  }
  let twice = match rr_run_re_reloop(mod) {
    Ok(next) => next
    Err(e) => fail("re_reloop second run should succeed: \{e}")
  }
  assert_eq(once, twice)
  match validate_module(once) {
    Ok(_) => ()
    Err(e) => fail("re_reloop output should validate: \{e}")
  }
}

///|
test "re_reloop reconstructs flattened branch shells via cfg relayout" {
  let mod = rr_fixture_flattened_branch_shell_module()
  let rerelooped = match rr_run_re_reloop(mod) {
    Ok(next) => next
    Err(e) => fail("re_reloop should succeed: \{e}")
  }
  let merged = match rr_apply_ir_pass(mod, merge_blocks_ir_pass(mod)) {
    Ok(next) => next
    Err(e) => fail("merge_blocks fixture run should succeed: \{e}")
  }
  assert_false(rerelooped == merged)
  match rerelooped.code_sec {
    Some(CodeSec([TFunc(_, body)])) => {
      assert_true(
        rr_texpr_contains(body, fn(instr) {
          match instr {
            TIf(_, _, _, _) => true
            _ => false
          }
        }),
      )
      assert_false(
        rr_texpr_contains(body, fn(instr) {
          match instr {
            TBrIf(_, _, _) => true
            _ => false
          }
        }),
      )
    }
    _ => fail("expected rerelooped typed function body")
  }
  match validate_module(rerelooped) {
    Ok(_) => ()
    Err(e) => fail("re_reloop cfg reconstruction output should validate: \{e}")
  }
}

///|
test "re_reloop reconstructs flattened br_on_null shell via cfg relayout" {
  let mod = rr_fixture_flattened_bron_block_module()
  let rerelooped = match rr_run_re_reloop(mod) {
    Ok(next) => next
    Err(e) => fail("re_reloop should succeed on br_on fixture: \{e}")
  }
  match rerelooped.code_sec {
    Some(CodeSec([TFunc(_, body)])) => {
      assert_true(
        rr_texpr_contains(body, fn(instr) {
          match instr {
            TIf(_, _, _, _) => true
            _ => false
          }
        }),
      )
      assert_eq(
        rr_texpr_count(body, fn(instr) {
          match instr {
            TBrOnNull(_, _, _) => true
            _ => false
          }
        }),
        0,
      )
    }
    _ => fail("expected rerelooped br_on fixture body")
  }
  match validate_module(rerelooped) {
    Ok(_) => ()
    Err(e) =>
      fail("re_reloop br_on reconstruction output should validate: \{e}")
  }
}

///|
test "re_reloop reconstructs flattened br_on family shells via cfg relayout" {
  let mod = rr_fixture_flattened_bron_family_module()
  let rerelooped = match rr_run_re_reloop(mod) {
    Ok(next) => next
    Err(e) => fail("re_reloop should succeed on br_on family fixture: \{e}")
  }
  match rerelooped.code_sec {
    Some(CodeSec(funcs)) => {
      let if_count = Ref::new(0)
      for func in funcs {
        match func {
          TFunc(_, body) =>
            if_count.update(fn(v) {
              v +
              rr_texpr_count(body, fn(instr) {
                match instr {
                  TIf(_, _, _, _) => true
                  _ => false
                }
              })
            })
          _ => ()
        }
      }
      assert_eq(if_count.val, 4)
      let bron_count = Ref::new(0)
      for func in funcs {
        match func {
          TFunc(_, body) =>
            bron_count.update(fn(v) {
              v +
              rr_texpr_count(body, fn(instr) {
                match instr {
                  TBrOnNull(_, _, _)
                  | TBrOnNonNull(_, _, _)
                  | TBrOnCast(_, _, _, _, _, _)
                  | TBrOnCastFail(_, _, _, _, _, _) => true
                  _ => false
                }
              })
            })
          _ => ()
        }
      }
      assert_eq(bron_count.val, 0)
    }
    _ => fail("expected rerelooped br_on family fixture bodies")
  }
  match validate_module(rerelooped) {
    Ok(_) => ()
    Err(e) =>
      fail("re_reloop br_on family reconstruction output should validate: \{e}")
  }
}

///|
test "re_reloop reconstructs flattened br_table shell via cfg relayout" {
  let mod = rr_fixture_flattened_brtable_block_module()
  let rerelooped = match rr_run_re_reloop(mod) {
    Ok(next) => next
    Err(e) => fail("re_reloop should succeed on br_table fixture: \{e}")
  }
  match rerelooped.code_sec {
    Some(CodeSec([TFunc(_, body)])) => {
      assert_true(
        rr_texpr_contains(body, fn(instr) {
          match instr {
            TIf(_, _, _, _) => true
            _ => false
          }
        }),
      )
      assert_eq(
        rr_texpr_count(body, fn(instr) {
          match instr {
            TBrTable(_, _, _, _) => true
            _ => false
          }
        }),
        0,
      )
    }
    _ => fail("expected rerelooped br_table fixture body")
  }
  match validate_module(rerelooped) {
    Ok(_) => ()
    Err(e) =>
      fail("re_reloop br_table reconstruction output should validate: \{e}")
  }
}

///|
test "re_reloop preserves single-evaluation semantics for side-effectful br_table index" {
  let mod = rr_fixture_brtable_side_effect_index_module()
  let rerelooped = match rr_run_re_reloop(mod) {
    Ok(next) => next
    Err(e) =>
      fail("re_reloop should succeed on side-effectful br_table fixture: \{e}")
  }
  match rerelooped.code_sec {
    Some(CodeSec([_, TFunc(_, body)])) =>
      assert_eq(
        rr_texpr_count(body, fn(instr) {
          match instr {
            TCall(FuncIdx(idx), _) => idx == 0
            _ => false
          }
        }),
        1,
      )
    _ => fail("expected rerelooped side-effectful br_table fixture body")
  }
  match validate_module(rerelooped) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "re_reloop side-effectful br_table reconstruction output should validate: \{e}",
      )
  }
}

///|
test "re_reloop reconstructs flattened shells with non-special outer-target branches" {
  let mod = rr_fixture_non_special_target_merge_module()
  let rerelooped = match rr_run_re_reloop(mod) {
    Ok(next) => next
    Err(e) =>
      fail("re_reloop should succeed on non-special target fixture: \{e}")
  }
  match rerelooped.code_sec {
    Some(CodeSec([TFunc(_, body)])) => {
      assert_true(
        rr_texpr_contains(body, fn(instr) {
          match instr {
            TIf(_, _, _, _) => true
            _ => false
          }
        }),
      )
      assert_eq(
        rr_texpr_count(body, fn(instr) {
          match instr {
            TBrIf(_, _, _) => true
            _ => false
          }
        }),
        0,
      )
    }
    _ => fail("expected rerelooped non-special target fixture body")
  }
  match validate_module(rerelooped) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "re_reloop non-special target reconstruction output should validate: \{e}",
      )
  }
}

///|
test "re_reloop preserves branch-value flows while reconstructing if form" {
  let mod = rr_fixture_branch_value_flow_module()
  let rerelooped = match rr_run_re_reloop(mod) {
    Ok(next) => next
    Err(e) => fail("re_reloop should succeed on branch-value fixture: \{e}")
  }
  match rerelooped.code_sec {
    Some(CodeSec([TFunc(_, body)])) => {
      assert_eq(
        rr_texpr_count(body, fn(instr) {
          match instr {
            TBrIf(_, _, _) => true
            _ => false
          }
        }),
        0,
      )
      assert_true(
        rr_texpr_contains(body, fn(instr) {
          match instr {
            TBr(LabelIdx(depth), [TLocalGet(LocalIdx(i))]) =>
              depth == 0 && i == 1U
            _ => false
          }
        }),
      )
    }
    _ => fail("expected rerelooped branch-value fixture body")
  }
  match validate_module(rerelooped) {
    Ok(_) => ()
    Err(e) =>
      fail("re_reloop branch-value reconstruction output should validate: \{e}")
  }
}

///|
test "re_reloop reconstructs flattened loop backedge branch shells" {
  let mod = rr_fixture_loop_backedge_module()
  let rerelooped = match rr_run_re_reloop(mod) {
    Ok(next) => next
    Err(e) => fail("re_reloop should succeed on loop fixture: \{e}")
  }
  match rerelooped.code_sec {
    Some(CodeSec([TFunc(_, body)])) => {
      assert_true(
        rr_texpr_contains(body, fn(instr) {
          match instr {
            TLoop(_, loop_body) =>
              rr_texpr_contains(loop_body, fn(inner) {
                match inner {
                  TIf(_, _, _, _) => true
                  _ => false
                }
              })
            _ => false
          }
        }),
      )
      assert_eq(
        rr_texpr_count(body, fn(instr) {
          match instr {
            TBrIf(_, _, _) => true
            _ => false
          }
        }),
        0,
      )
    }
    _ => fail("expected rerelooped loop fixture body")
  }
  match validate_module(rerelooped) {
    Ok(_) => ()
    Err(e) => fail("re_reloop loop reconstruction output should validate: \{e}")
  }
}

///|
test "re_reloop cfg reconstruction output is idempotent" {
  let mod = rr_fixture_flattened_branch_shell_module()
  let once = match rr_run_re_reloop(mod) {
    Ok(next) => next
    Err(e) => fail("re_reloop first run should succeed: \{e}")
  }
  let twice = match rr_run_re_reloop(once) {
    Ok(next) => next
    Err(e) => fail("re_reloop second run should succeed: \{e}")
  }
  assert_eq(once, twice)
  match validate_module(once) {
    Ok(_) => ()
    Err(e) => fail("re_reloop cfg reconstruction output should validate: \{e}")
  }
}

///|
test "re_reloop rejects non-flat control-flow trees" {
  let mod = rr_fixture_non_flat_if_module()
  rr_expect_error_contains(
    rr_run_re_reloop(mod),
    "re_reloop requires flattened control flow",
  )
}

///|
test "re_reloop rejects exception handling instructions" {
  let mod = rr_fixture_try_table_module()
  rr_expect_error_contains(
    rr_run_re_reloop(mod),
    "re_reloop does not support EH instructions yet",
  )
}

///|
test "merge_blocks can still run on non-flat fixture where re_reloop rejects" {
  let mod = rr_fixture_non_flat_if_module()
  let rereloop = rr_run_re_reloop(mod)
  rr_expect_error_contains(
    rereloop, "re_reloop requires flattened control flow",
  )
  match rr_apply_ir_pass(mod, merge_blocks_ir_pass(mod)) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "merge_blocks should still run on non-flat fixture even when re_reloop rejects: \{e}",
      )
  }
}

///|
fn rr_is_control_flow(instr : TInstr) -> Bool {
  match instr {
    TBlock(_, _)
    | TLoop(_, _)
    | TIf(_, _, _, _)
    | TTryTable(_, _, _)
    | TBr(_, _)
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
    | TThrowRef(_)
    | TUnreachable => true
    _ => false
  }
}

///|
fn rr_eval_children(instr : TInstr) -> Array[TInstr] {
  match instr {
    TI32Const(_)
    | TI64Const(_)
    | TF32Const(_)
    | TF64Const(_)
    | TRefNull(_)
    | TRefFunc(_)
    | TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | TUnreachable
    | TNop
    | TLocalGet(_)
    | TGlobalGet(_)
    | TMemorySize(_)
    | TAtomicFence
    | TTableSize(_)
    | TDataDrop(_)
    | TElemDrop(_)
    | TStructNewDefault(_) => []
    TUnary(_, child)
    | TDrop(child)
    | TLocalSet(_, child)
    | TLocalTee(_, child)
    | TGlobalSet(_, child)
    | TRefIsNull(child)
    | TRefAsNonNull(child)
    | TI31GetS(child)
    | TI31GetU(child)
    | TRefI31(child)
    | TArrayLen(child)
    | TAnyConvertExtern(child)
    | TExternConvertAny(child)
    | TThrowRef(child)
    | TMemoryGrow(_, child)
    | TTableGet(_, child)
    | TLoad(_, _, child)
    | TArrayNewDefault(_, child)
    | TStructGet(_, _, child)
    | TStructGetS(_, _, child)
    | TStructGetU(_, _, child)
    | TI8x16Splat(child)
    | TI16x8Splat(child)
    | TI32x4Splat(child)
    | TI64x2Splat(child)
    | TF32x4Splat(child)
    | TF64x2Splat(child)
    | TExtractLane(_, _, child)
    | TRefTest(_, _, child)
    | TRefCast(_, _, child)
    | TRefGetDesc(child)
    | TRefTestDesc(_, _, child)
    | TRefCastDescEq(_, _, child) => [child]
    TBinary(_, left, right)
    | TRefEq(left, right)
    | TStore(_, _, left, right)
    | TMemoryAtomicNotify(_, left, right)
    | TAtomicRmw(_, _, left, right)
    | TTableSet(_, left, right)
    | TTableGrow(_, left, right)
    | TStructSet(_, _, left, right)
    | TArrayNew(_, left, right)
    | TArrayNewData(_, _, left, right)
    | TArrayNewElem(_, _, left, right)
    | TArrayGet(_, left, right)
    | TArrayGetS(_, left, right)
    | TArrayGetU(_, left, right)
    | TReplaceLane(_, _, left, right)
    | TI8x16Swizzle(left, right)
    | TI8x16RelaxedSwizzle(left, right)
    | TV128Shift(_, left, right)
    | TV128LoadLane(_, _, _, left, right)
    | TV128StoreLane(_, _, _, left, right) => [left, right]
    TMemoryFill(_, a, b, c)
    | TMemoryCopy(_, _, a, b, c)
    | TMemoryInit(_, _, a, b, c)
    | TMemoryAtomicWait32(_, a, b, c)
    | TMemoryAtomicWait64(_, a, b, c)
    | TAtomicCmpxchg(_, _, a, b, c)
    | TTableFill(_, a, b, c)
    | TTableCopy(_, _, a, b, c)
    | TTableInit(_, _, a, b, c)
    | TSelect(_, c, a, b)
    | TV128Ternary(_, a, b, c) => [a, b, c]
    TCall(_, args)
    | TReturnCall(_, args)
    | TThrow(_, args)
    | TBr(_, args)
    | TReturn(args)
    | TStructNew(_, args)
    | TArrayNewFixed(_, args) => args.copy()
    TCallIndirect(_, _, args, index) | TReturnCallIndirect(_, _, args, index) => {
      let out = args.copy()
      out.push(index)
      out
    }
    TCallRef(_, args, ref_) | TReturnCallRef(_, args, ref_) => {
      let out = args.copy()
      out.push(ref_)
      out
    }
    TBrIf(_, cond, values) => {
      let out = values.copy()
      out.push(cond)
      out
    }
    TBrTable(_, _, index, values) => {
      let out = values.copy()
      out.push(index)
      out
    }
    TBrOnNull(_, ref_, values)
    | TBrOnNonNull(_, ref_, values)
    | TBrOnCast(_, _, _, _, ref_, values)
    | TBrOnCastFail(_, _, _, _, ref_, values) => {
      let out = values.copy()
      out.push(ref_)
      out
    }
    TArraySet(_, a, b, c) => [a, b, c]
    TArrayFill(_, a, b, c, d) => [a, b, c, d]
    TArrayCopy(_, _, a, b, c, d, e) => [a, b, c, d, e]
    TArrayInitData(_, _, a, b, c, d) => [a, b, c, d]
    TArrayInitElem(_, _, a, b, c, d) => [a, b, c, d]
    TI8x16Shuffle(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, left, right) =>
      [left, right]
    TBlock(_, _) | TLoop(_, _) | TIf(_, _, _, _) | TTryTable(_, _, _) => []
  }
}

///|
fn rr_contains_nested_control(instr : TInstr) -> Bool {
  for child in rr_eval_children(instr) {
    if rr_is_control_flow(child) || rr_contains_nested_control(child) {
      return true
    }
  }
  match instr {
    TBlock(_, body) | TLoop(_, body) | TTryTable(_, _, body) =>
      for item in body.0 {
        if rr_contains_nested_control(item) {
          return true
        }
      }
    TIf(_, cond, then_body, else_body) => {
      if rr_is_control_flow(cond) || rr_contains_nested_control(cond) {
        return true
      }
      for item in then_body.0 {
        if rr_contains_nested_control(item) {
          return true
        }
      }
      match else_body {
        Some(other) =>
          for item in other.0 {
            if rr_contains_nested_control(item) {
              return true
            }
          }
        None => ()
      }
    }
    _ => ()
  }
  false
}

///|
fn rr_validate_function_body_flat_and_supported(
  body : TExpr,
) -> Result[Unit, String] {
  for instr in body.0 {
    match instr {
      TTryTable(_, _, _) | TThrow(_, _) | TThrowRef(_) =>
        return Err("re_reloop does not support EH instructions yet")
      _ => ()
    }
    if rr_contains_nested_control(instr) {
      return Err(
        "re_reloop requires flattened control flow; run flatten before re_reloop",
      )
    }
  }
  Ok(())
}

///|
fn rr_validate_module_preconditions(mod : Module) -> Result[Unit, String] {
  match mod.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        match func {
          TFunc(_, body) =>
            match rr_validate_function_body_flat_and_supported(body) {
              Ok(_) => ()
              Err(e) => return Err(e)
            }
          _ => ()
        }
      }
    None => ()
  }
  Ok(())
}

///|
priv struct RRBlockId(Int) derive(Eq, Hash)

///|
priv enum RRJumpTarget {
  Internal(RRBlockId)
  External(LabelIdx)
}

///|
priv enum RRTerminator {
  RRBr(RRJumpTarget, Array[TInstr], Bool)
  RRBrIf(TInstr, RRJumpTarget, RRBlockId, Array[TInstr])
  RRBrTable(TInstr, Array[RRJumpTarget], RRJumpTarget, Array[TInstr])
  RRUnreachable
}

///|
priv struct RRBasicBlock {
  instrs : Array[TInstr]
  terminator : RRTerminator
}

///|
priv struct RRCFG {
  entry : RRBlockId
  blocks : Map[RRBlockId, RRBasicBlock]
}

///|
priv enum RRFlowMode {
  BlockFlow
  LoopFlow
}

///|
priv struct RRReconstructState {
  stop : RRBlockId
  break_label : LabelIdx
  continue_target : RRBlockId?
  continue_label : LabelIdx?
}

///|
fn rr_append_texpr(dst : Array[TInstr], src : TExpr) -> Unit {
  for instr in src.0 {
    dst.push(instr)
  }
}

///|
fn rr_internal_target_label(
  target : RRBlockId,
  state : RRReconstructState,
) -> LabelIdx? {
  if target == state.stop {
    return Some(state.break_label)
  }
  match (state.continue_target, state.continue_label) {
    (Some(loop_entry), Some(label)) if target == loop_entry => Some(label)
    _ => None
  }
}

///|
fn rr_target_label(
  target : RRJumpTarget,
  state : RRReconstructState,
) -> LabelIdx? {
  match target {
    Internal(block_id) => rr_internal_target_label(block_id, state)
    External(label) => Some(label)
  }
}

///|
fn rr_dup_safe_expr(expr : TInstr) -> Bool {
  match expr {
    TI32Const(_)
    | TI64Const(_)
    | TF32Const(_)
    | TF64Const(_)
    | TLocalGet(_)
    | TGlobalGet(_)
    | TRefNull(_)
    | TRefFunc(_)
    | TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) => true
    TUnary(_, child)
    | TRefIsNull(child)
    | TRefAsNonNull(child)
    | TI31GetS(child)
    | TI31GetU(child)
    | TRefI31(child)
    | TAnyConvertExtern(child)
    | TExternConvertAny(child) => rr_dup_safe_expr(child)
    TBinary(_, left, right) | TRefEq(left, right) =>
      rr_dup_safe_expr(left) && rr_dup_safe_expr(right)
    _ => false
  }
}

///|
fn rr_target_to_label(
  target : RRJumpTarget,
  state : RRReconstructState,
) -> LabelIdx? {
  rr_target_label(target, state)
}

///|
fn rr_try_emit_direct_br_table(
  instrs : Array[TInstr],
  index : TInstr,
  targets : Array[RRJumpTarget],
  default_target : RRJumpTarget,
  values : Array[TInstr],
  state : RRReconstructState,
) -> Bool {
  let labels : Array[LabelIdx] = []
  for target in targets {
    match rr_target_to_label(target, state) {
      Some(label) => labels.push(label)
      None => return false
    }
  }
  let default_label = match rr_target_to_label(default_target, state) {
    Some(label) => label
    None => return false
  }
  instrs.push(TInstr::br_table(labels, default_label, index, values))
  true
}

///|
fn rr_cfg_target_to_texpr(
  cfg : RRCFG,
  target : RRJumpTarget,
  branch_values : Array[TInstr],
  state : RRReconstructState,
  depth : Int,
  max_depth : Int,
) -> TExpr? {
  match target {
    External(label) => Some(TExpr::new([TInstr::br(label, branch_values)]))
    Internal(block_id) =>
      match rr_internal_target_label(block_id, state) {
        Some(label) => Some(TExpr::new([TInstr::br(label, branch_values)]))
        None =>
          rr_cfg_region_to_texpr(cfg, block_id, state, depth + 1, max_depth)
      }
  }
}

///|
fn rr_cfg_region_to_texpr(
  cfg : RRCFG,
  block_id : RRBlockId,
  state : RRReconstructState,
  depth : Int,
  max_depth : Int,
) -> TExpr? {
  if depth > max_depth {
    return None
  }
  if block_id == state.stop {
    return Some(TExpr::new([]))
  }
  let block = match cfg.blocks.get(block_id) {
    Some(b) => b
    None => return None
  }
  let instrs = block.instrs.copy()
  match block.terminator {
    RRBr(target, values, explicit) =>
      match rr_target_label(target, state) {
        Some(label) => {
          if explicit {
            instrs.push(TInstr::br(label, values))
          }
          return Some(TExpr::new(instrs))
        }
        None =>
          match target {
            Internal(next_block) =>
              match
                rr_cfg_region_to_texpr(
                  cfg,
                  next_block,
                  state,
                  depth + 1,
                  max_depth,
                ) {
                Some(tail) => {
                  rr_append_texpr(instrs, tail)
                  return Some(TExpr::new(instrs))
                }
                None => return None
              }
            External(_) => return None
          }
      }
    RRBrIf(cond, then_block, else_block, values) => {
      if values.length() != 0 {
        match then_block {
          Internal(block_id) =>
            if rr_internal_target_label(block_id, state) is None {
              return None
            }
          _ => ()
        }
      }
      let then_is_direct_branch = match then_block {
        External(_) => true
        Internal(block_id) =>
          rr_internal_target_label(block_id, state) is Some(_)
      }
      if then_is_direct_branch {
        let then_expr = match
          rr_cfg_target_to_texpr(
            cfg,
            then_block,
            values,
            state,
            depth + 1,
            max_depth,
          ) {
          Some(expr) => expr
          None => return None
        }
        let else_tail = match
          rr_cfg_region_to_texpr(cfg, else_block, state, depth + 1, max_depth) {
          Some(expr) => expr
          None => return None
        }
        instrs.push(TInstr::if_(BlockType::void_(), cond, then_expr, None))
        rr_append_texpr(instrs, else_tail)
        return Some(TExpr::new(instrs))
      }
      let then_expr = match
        rr_cfg_target_to_texpr(
          cfg,
          then_block,
          values,
          state,
          depth + 1,
          max_depth,
        ) {
        Some(expr) => expr
        None => return None
      }
      let else_tail = match
        rr_cfg_region_to_texpr(cfg, else_block, state, depth + 1, max_depth) {
        Some(expr) => expr
        None => return None
      }
      let else_opt = if else_tail.0.length() == 0 {
        None
      } else {
        Some(else_tail)
      }
      instrs.push(TInstr::if_(BlockType::void_(), cond, then_expr, else_opt))
      return Some(TExpr::new(instrs))
    }
    RRBrTable(index, targets, default_target, values) => {
      if !rr_dup_safe_expr(index) {
        if rr_try_emit_direct_br_table(
            instrs, index, targets, default_target, values, state,
          ) {
          return Some(TExpr::new(instrs))
        }
        return None
      }
      let dispatch = match
        rr_cfg_target_to_texpr(
          cfg,
          default_target,
          values,
          state,
          depth + 1,
          max_depth,
        ) {
        Some(expr) => expr
        None => return None
      }
      let mut dispatch = dispatch
      for i = targets.length() - 1; i >= 0; i = i - 1 {
        let then_expr = match
          rr_cfg_target_to_texpr(
            cfg,
            targets[i],
            values,
            state,
            depth + 1,
            max_depth,
          ) {
          Some(expr) => expr
          None => return None
        }
        let cond = TInstr::binary(
          BinaryOp::i32_eq(),
          index,
          TInstr::i32_const(I32(i)),
        )
        dispatch = TExpr::new([
          TInstr::if_(BlockType::void_(), cond, then_expr, Some(dispatch)),
        ])
      }
      rr_append_texpr(instrs, dispatch)
      return Some(TExpr::new(instrs))
    }
    RRUnreachable => {
      instrs.push(TInstr::unreachable_())
      return Some(TExpr::new(instrs))
    }
  }
}

///|
fn rr_label_to_target(
  mode : RRFlowMode,
  label : LabelIdx,
  entry : RRBlockId,
  exit : RRBlockId,
) -> RRJumpTarget {
  match (mode, label) {
    (BlockFlow, LabelIdx(depth)) =>
      if depth == 0 {
        Internal(exit)
      } else {
        External(label)
      }
    (LoopFlow, LabelIdx(depth)) =>
      if depth == 0 {
        Internal(entry)
      } else if depth == 1 {
        Internal(exit)
      } else {
        External(label)
      }
  }
}

///|
fn rr_try_build_flat_cfg(
  body : TExpr,
  mode : RRFlowMode,
) -> (RRCFG, RRBlockId)? {
  let mut next_id = 0
  fn fresh() -> RRBlockId {
    let id = RRBlockId(next_id)
    next_id = next_id + 1
    id
  }
  let entry = fresh()
  let exit = fresh()
  let blocks : Map[RRBlockId, RRBasicBlock] = {}
  let mut current = entry
  let mut current_instrs : Array[TInstr] = []
  let mut saw_control = false
  let mut terminated = false

  for instr in body.0 {
    match instr {
      TBr(label, values) => {
        let target = rr_label_to_target(mode, label, entry, exit)
        blocks[current] = {
          instrs: current_instrs,
          terminator: RRBr(target, values, true),
        }
        saw_control = true
        terminated = true
      }
      TBrIf(label, cond, values) => {
        let target = rr_label_to_target(mode, label, entry, exit)
        let fallthrough = fresh()
        blocks[current] = {
          instrs: current_instrs,
          terminator: RRBrIf(cond, target, fallthrough, values),
        }
        current = fallthrough
        current_instrs = []
        saw_control = true
      }
      TBrOnNull(label, ref_, values) => {
        let target = rr_label_to_target(mode, label, entry, exit)
        let fallthrough = fresh()
        blocks[current] = {
          instrs: current_instrs,
          terminator: RRBrIf(
            TInstr::ref_is_null(ref_),
            target,
            fallthrough,
            values,
          ),
        }
        current = fallthrough
        current_instrs = []
        saw_control = true
      }
      TBrOnNonNull(label, ref_, values) => {
        let target = rr_label_to_target(mode, label, entry, exit)
        let fallthrough = fresh()
        blocks[current] = {
          instrs: current_instrs,
          terminator: RRBrIf(
            TInstr::unary(UnaryOp::i32_eqz(), TInstr::ref_is_null(ref_)),
            target,
            fallthrough,
            values,
          ),
        }
        current = fallthrough
        current_instrs = []
        saw_control = true
      }
      TBrOnCast(label, op, _src_ht, dst_ht, ref_, values) => {
        let target = rr_label_to_target(mode, label, entry, exit)
        let fallthrough = fresh()
        blocks[current] = {
          instrs: current_instrs,
          terminator: RRBrIf(
            TInstr::ref_test(op.1, dst_ht, ref_),
            target,
            fallthrough,
            values,
          ),
        }
        current = fallthrough
        current_instrs = []
        saw_control = true
      }
      TBrOnCastFail(label, op, _src_ht, dst_ht, ref_, values) => {
        let target = rr_label_to_target(mode, label, entry, exit)
        let fallthrough = fresh()
        blocks[current] = {
          instrs: current_instrs,
          terminator: RRBrIf(
            TInstr::unary(
              UnaryOp::i32_eqz(),
              TInstr::ref_test(op.1, dst_ht, ref_),
            ),
            target,
            fallthrough,
            values,
          ),
        }
        current = fallthrough
        current_instrs = []
        saw_control = true
      }
      TBrTable(labels, default_label, index, values) => {
        let mapped_targets : Array[RRJumpTarget] = []
        for label in labels {
          mapped_targets.push(rr_label_to_target(mode, label, entry, exit))
        }
        let mapped_default = rr_label_to_target(
          mode, default_label, entry, exit,
        )
        blocks[current] = {
          instrs: current_instrs,
          terminator: RRBrTable(index, mapped_targets, mapped_default, values),
        }
        saw_control = true
        terminated = true
      }
      TBlock(_, _) | TLoop(_, _) | TIf(_, _, _, _) | TTryTable(_, _, _) =>
        return None
      TReturn(_)
      | TReturnCall(_, _)
      | TReturnCallIndirect(_, _, _, _)
      | TReturnCallRef(_, _, _)
      | TThrow(_, _)
      | TThrowRef(_)
      | TUnreachable => return None
      _ => current_instrs.push(instr)
    }
    if terminated {
      break
    }
  }

  if !terminated {
    blocks[current] = {
      instrs: current_instrs,
      terminator: RRBr(Internal(exit), [], false),
    }
  }
  blocks[exit] = RRBasicBlock::{ instrs: [], terminator: RRUnreachable }
  if !saw_control {
    return None
  }

  Some((RRCFG::{ entry, blocks }, exit))
}

///|
fn rr_try_reconstruct_flat_block_cfg(body : TExpr) -> TExpr? {
  match rr_try_build_flat_cfg(body, BlockFlow) {
    Some((cfg, stop)) => {
      let max_depth = cfg.blocks.length() * 4 + 16
      let state : RRReconstructState = {
        stop,
        break_label: LabelIdx::new(0),
        continue_target: None,
        continue_label: None,
      }
      rr_cfg_region_to_texpr(cfg, cfg.entry, state, 0, max_depth)
    }
    None => None
  }
}

///|
fn rr_try_reconstruct_flat_loop_cfg(body : TExpr) -> TExpr? {
  match rr_try_build_flat_cfg(body, LoopFlow) {
    Some((cfg, stop)) => {
      let max_depth = cfg.blocks.length() * 4 + 16
      let state : RRReconstructState = {
        stop,
        break_label: LabelIdx::new(1),
        continue_target: Some(cfg.entry),
        continue_label: Some(LabelIdx::new(0)),
      }
      rr_cfg_region_to_texpr(cfg, cfg.entry, state, 0, max_depth)
    }
    None => None
  }
}

///|
fn rr_reconstruct_tinstr(instr : TInstr) -> Result[TInstr, String] {
  match instr {
    TBlock(bt, body) => {
      let next_body = match rr_reconstruct_texpr(body) {
        Ok(next) => next
        Err(e) => return Err(e)
      }
      match rr_try_reconstruct_flat_block_cfg(next_body) {
        Some(rebuilt) => Ok(TInstr::block(bt, rebuilt))
        None => Ok(TInstr::block(bt, next_body))
      }
    }
    TLoop(bt, body) => {
      let next_body = match rr_reconstruct_texpr(body) {
        Ok(next) => next
        Err(e) => return Err(e)
      }
      match rr_try_reconstruct_flat_loop_cfg(next_body) {
        Some(rebuilt) => Ok(TInstr::loop_(bt, rebuilt))
        None => Ok(TInstr::loop_(bt, next_body))
      }
    }
    TIf(bt, cond, then_body, else_body) => {
      let next_then = match rr_reconstruct_texpr(then_body) {
        Ok(next) => next
        Err(e) => return Err(e)
      }
      let next_else = match else_body {
        Some(other) =>
          match rr_reconstruct_texpr(other) {
            Ok(next) => Some(next)
            Err(e) => return Err(e)
          }
        None => None
      }
      Ok(TInstr::if_(bt, cond, next_then, next_else))
    }
    _ => Ok(instr)
  }
}

///|
fn rr_reconstruct_texpr(body : TExpr) -> Result[TExpr, String] {
  let out : Array[TInstr] = []
  for instr in body.0 {
    let next_instr = match rr_reconstruct_tinstr(instr) {
      Ok(next) => next
      Err(e) => return Err(e)
    }
    out.push(next_instr)
  }
  Ok(TExpr::new(out))
}

///|
fn rr_reconstruct_module_cfg(mod : Module) -> Result[Module, String] {
  match mod.code_sec {
    Some(CodeSec(funcs)) => {
      let next_funcs : Array[Func] = []
      let mut changed = false
      for func in funcs {
        match func {
          TFunc(locals, body) =>
            match rr_reconstruct_texpr(body) {
              Ok(next_body) => {
                if next_body != body {
                  changed = true
                }
                next_funcs.push(Func::t_func(locals, next_body))
              }
              Err(e) => return Err(e)
            }
          _ => next_funcs.push(func)
        }
      }
      if changed {
        Ok(mod.with_code_sec(CodeSec::new(next_funcs)))
      } else {
        Ok(mod)
      }
    }
    None => Ok(mod)
  }
}

///|
fn run_re_reloop(mod : Module) -> Result[Module, String] {
  match rr_validate_module_preconditions(mod) {
    Ok(_) =>
      match rr_reconstruct_module_cfg(mod) {
        Ok(rebuilt) => rr_apply_ir_pass(rebuilt, merge_blocks_ir_pass(rebuilt))
        Err(e) => Err(e)
      }
    Err(e) => Err(e)
  }
}

///|
fn re_reloop_ir_pass(_mod : Module) -> ModuleTransformer[IRContext] {
  ModuleTransformer::new().on_module_evt(fn(_, ctx : IRContext, mod : Module) {
    match run_re_reloop(mod) {
      Ok(next_mod) =>
        if next_mod == mod {
          unchanged()
        } else {
          change(ctx, next_mod)
        }
      Err(e) => Err(e)
    }
  })
}
