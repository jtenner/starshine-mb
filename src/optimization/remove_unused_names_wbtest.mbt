///|
fn remove_unused_names_test_module(instrs : Array[@lib.TInstr]) -> Module {
  Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::t_func([], @lib.Locals::empty(), @lib.TExpr::new(instrs)),
    ]),
  )
}

///|
fn remove_unused_names_test_run(mod : Module) -> Module {
  let (optimized, _) = run_remove_unused_names(mod, PipelineScratch::new())
  match @validate.validate_module(optimized) {
    Ok(_) => optimized
    Err(err) =>
      abort(
        "expected RemoveUnusedNames fixture to validate: \{@validate.validation_error_message(err)}",
      )
  }
}

///|
fn remove_unused_names_test_body(
  instrs : Array[@lib.TInstr],
) -> Array[@lib.TInstr] {
  let optimized = remove_unused_names_test_run(
    remove_unused_names_test_module(instrs),
  )
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.TFunc(_, _, body)])) => body.inner()
    _ => abort("expected optimized single typed function body")
  }
}

///|
test "remove unused names pipeline dispatch uses dedicated runner shell" {
  let pipeline : Array[PipelineEntry] = []
  add_pass_to_pipeline(pipeline, OptimizePass::RemoveUnusedNames)
  let mod = remove_unused_names_test_module([@lib.TInstr::nop()])
  match pipeline {
    [{ group: PassGroup(FuncLocalGroup([runner]), _), .. }] => {
      let (_, scratch) = runner(mod, PipelineScratch::new())
      assert_eq(scratch.funcs_visited, 1)
    }
    _ => fail("expected remove unused names func-local pipeline entry")
  }
}

///|
test "remove unused names skips walk when no candidates exist" {
  let body = remove_unused_names_test_body([
    @lib.TInstr::drop(@lib.TInstr::i32_const(@lib.I32::new(1))),
  ])
  assert_eq(body, [@lib.TInstr::drop(@lib.TInstr::i32_const(@lib.I32::new(1)))])
}

///|
test "remove unused names merges single-child same-typed nested blocks" {
  let body = remove_unused_names_test_body([
    @lib.TInstr::block(
      @lib.BlockType::void_(),
      @lib.TExpr::new([
        @lib.TInstr::block(
          @lib.BlockType::void_(),
          @lib.TExpr::new([@lib.TInstr::nop()]),
        ),
      ]),
    ),
  ])
  match body {
    [instr] =>
      match instr.kind {
        @lib.TBlock(@lib.VoidBlockType, child_body) =>
          match child_body.inner() {
            [child] =>
              match child.kind {
                @lib.TNop => ()
                _ => fail("expected merged child nop")
              }
            _ => fail("expected single merged child")
          }
        _ => fail("expected outer block to merge into child block")
      }
    _ => fail("expected single rewritten outer block")
  }
}

///|
test "remove unused names retargets branch depth when merging nested blocks" {
  let body = remove_unused_names_test_body([
    @lib.TInstr::block(
      @lib.BlockType::void_(),
      @lib.TExpr::new([
        @lib.TInstr::block(
          @lib.BlockType::void_(),
          @lib.TExpr::new([
            @lib.TInstr::block(
              @lib.BlockType::void_(),
              @lib.TExpr::new([@lib.TInstr::br(@lib.LabelIdx::new(2U), [])]),
            ),
          ]),
        ),
      ]),
    ),
  ])
  match body {
    [instr] =>
      match instr.kind {
        @lib.TBlock(@lib.VoidBlockType, child_body) =>
          match child_body.inner() {
            [child] =>
              match child.kind {
                @lib.TBr(@lib.LabelIdx(next), []) => assert_eq(next, 0U)
                _ => fail("expected rebased branch inside merged block")
              }
            _ => fail("expected single rebased child")
          }
        _ =>
          fail(
            "expected branch depth to be decremented after removing one block scope",
          )
      }
    _ => fail("expected single rewritten outer block")
  }
}

///|
test "remove unused names preserves typed branch payloads when rebasing" {
  let body = remove_unused_names_test_body([
    @lib.TInstr::drop(
      @lib.TInstr::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.TExpr::new([
          @lib.TInstr::block(
            @lib.BlockType::val_type(@lib.ValType::i32()),
            @lib.TExpr::new([
              @lib.TInstr::block(
                @lib.BlockType::val_type(@lib.ValType::i32()),
                @lib.TExpr::new([
                  @lib.TInstr::br(@lib.LabelIdx::new(2U), [
                    @lib.TInstr::i32_const(@lib.I32::new(5)),
                  ]),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ),
  ])
  match body {
    [instr] =>
      match instr.kind {
        @lib.TDrop(child) =>
          match child.kind {
            @lib.TBlock(
              @lib.ValTypeBlockType(@lib.NumTypeValType(@lib.I32NumType)),
              branch_body
            ) =>
              match branch_body.inner() {
                [branch] =>
                  match branch.kind {
                    @lib.TBr(@lib.LabelIdx(next), [payload]) => {
                      assert_eq(next, 0U)
                      match payload.kind {
                        @lib.TI32Const(@lib.I32(5)) => ()
                        _ => fail("expected typed branch payload const")
                      }
                    }
                    _ => fail("expected rebased branch payload")
                  }
                _ => fail("expected single rebased branch")
              }
            _ => fail("expected i32 block under drop")
          }
        _ => fail("expected drop around value block")
      }
    _ => fail("expected single rewritten drop")
  }
}

///|
test "remove unused names skips merge when nested control still targets a removed scope" {
  let mod = remove_unused_names_test_module([
    @lib.TInstr::block(
      @lib.BlockType::void_(),
      @lib.TExpr::new([
        @lib.TInstr::block(
          @lib.BlockType::void_(),
          @lib.TExpr::new([
            @lib.TInstr::if_(
              @lib.BlockType::void_(),
              @lib.TInstr::i32_const(@lib.I32::new(0)),
              @lib.TExpr::new([@lib.TInstr::nop()]),
              Some(
                @lib.TExpr::new([@lib.TInstr::br(@lib.LabelIdx::new(1U), [])]),
              ),
            ),
          ]),
        ),
      ]),
    ),
  ])
  let (optimized, _) = run_remove_unused_names(mod, PipelineScratch::new())
  assert_eq(optimized, mod)
}

///|
test "remove unused names rewrites loop to block when no continue branch remains" {
  let body = remove_unused_names_test_body([
    @lib.TInstr::loop_(
      @lib.BlockType::void_(),
      @lib.TExpr::new([@lib.TInstr::nop()]),
    ),
  ])
  match body {
    [instr] =>
      match instr.kind {
        @lib.TBlock(@lib.VoidBlockType, child_body) =>
          match child_body.inner() {
            [child] =>
              match child.kind {
                @lib.TNop => ()
                _ => fail("expected loop body to stay intact inside block")
              }
            _ => fail("expected single child in demoted block")
          }
        _ => fail("expected loop with no continue to become block")
      }
    _ => fail("expected single demoted block")
  }
}

///|
test "remove unused names keeps loop when body branches to loop label" {
  let body = remove_unused_names_test_body([
    @lib.TInstr::loop_(
      @lib.BlockType::void_(),
      @lib.TExpr::new([@lib.TInstr::br(@lib.LabelIdx::new(0U), [])]),
    ),
  ])
  match body {
    [instr] =>
      match instr.kind {
        @lib.TLoop(@lib.VoidBlockType, _) => ()
        _ => fail("expected loop with br 0 to remain a loop")
      }
    _ => fail("expected single loop")
  }
}

///|
test "remove unused names rewrites value loop to block when no continue branch remains" {
  let body = remove_unused_names_test_body([
    @lib.TInstr::drop(
      @lib.TInstr::loop_(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.TExpr::new([@lib.TInstr::i32_const(@lib.I32::new(9))]),
      ),
    ),
  ])
  match body {
    [instr] =>
      match instr.kind {
        @lib.TDrop(child) =>
          match child.kind {
            @lib.TBlock(
              @lib.ValTypeBlockType(@lib.NumTypeValType(@lib.I32NumType)),
              child_body
            ) =>
              match child_body.inner() {
                [value] =>
                  match value.kind {
                    @lib.TI32Const(@lib.I32(9)) => ()
                    _ => fail("expected value loop payload inside block")
                  }
                _ => fail("expected single value child in demoted block")
              }
            _ => fail("expected value loop to demote to value block")
          }
        _ => fail("expected drop around demoted value loop")
      }
    _ => fail("expected single drop")
  }
}

///|
test "remove unused names keeps scratch unchanged when fixture body is untouched" {
  let mod = remove_unused_names_test_module([@lib.TInstr::nop()])
  let (_, scratch) = run_remove_unused_names(mod, PipelineScratch::new())
  assert_eq(scratch.funcs_changed, 0)
}
