///|
fn dead_code_elimination_test_module(instrs : Array[@lib.TInstr]) -> Module {
  Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_mem_sec(
    @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::t_func([], @lib.Locals::empty(), @lib.TExpr::new(instrs)),
    ]),
  )
}

///|
fn dead_code_elimination_test_result_module(
  results : Array[@lib.ValType],
  instrs : Array[@lib.TInstr],
) -> Module {
  Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([], results)),
      ),
    ]),
  )
  .with_mem_sec(
    @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::t_func([], @lib.Locals::empty(), @lib.TExpr::new(instrs)),
    ]),
  )
}

///|
fn dead_code_elimination_test_run(mod : Module) -> Module {
  let (optimized, _) = run_dead_code_elimination(mod, PipelineScratch::new())
  match @validate.validate_module(optimized) {
    Ok(_) => optimized
    Err(err) =>
      abort(
        "expected optimized DCE fixture to validate: \{@validate.validation_error_message(err)}",
      )
  }
}

///|
fn dead_code_elimination_test_body(
  instrs : Array[@lib.TInstr],
) -> Array[@lib.TInstr] {
  let optimized = dead_code_elimination_test_run(
    dead_code_elimination_test_module(instrs),
  )
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.TFunc(_, _, body)])) => body.inner()
    _ => abort("expected optimized single typed function body")
  }
}

///|
fn dead_code_elimination_test_result_body(
  results : Array[@lib.ValType],
  instrs : Array[@lib.TInstr],
) -> Array[@lib.TInstr] {
  let optimized = dead_code_elimination_test_run(
    dead_code_elimination_test_result_module(results, instrs),
  )
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.TFunc(_, _, body)])) => body.inner()
    _ => abort("expected optimized single typed function body")
  }
}

///|
fn dead_code_elimination_test_call_body(
  instr : @lib.TInstr,
) -> Array[@lib.TInstr] {
  let mod = Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], []),
          ),
        ),
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_func_sec(
      @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(1U)]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::t_func(
          [@lib.ValType::i32(), @lib.ValType::i32()],
          @lib.Locals::empty(),
          @lib.TExpr::new([@lib.TInstr::nop()]),
        ),
        @lib.Func::t_func([], @lib.Locals::empty(), @lib.TExpr::new([instr])),
      ]),
    )
  let optimized = dead_code_elimination_test_run(mod)
  match optimized.code_sec {
    Some(@lib.CodeSec([_, @lib.TFunc(_, _, body)])) => body.inner()
    _ => abort("expected optimized typed caller body")
  }
}

///|
test "dead code elimination pipeline dispatch uses dedicated runner shell" {
  let pipeline : Array[PipelineEntry] = []
  add_pass_to_pipeline(pipeline, OptimizePass::DeadCodeElimination)
  let mod = dead_code_elimination_test_module([@lib.TInstr::nop()])
  match pipeline {
    [{ group: PassGroup(FuncLocalGroup([runner]), _), .. }] => {
      let (_, scratch) = runner(mod, PipelineScratch::new())
      assert_eq(scratch.funcs_visited, 1)
      assert_eq(scratch.funcs_changed, 0)
      assert_false(scratch.changed)
    }
    _ => fail("expected dead code elimination func-local pipeline entry")
  }
}

///|
test "run_dead_code_elimination shell preserves empty typed function bodies" {
  let mod = dead_code_elimination_test_module([])
  let (optimized, scratch) = run_dead_code_elimination(
    mod,
    PipelineScratch::new(),
  )
  assert_eq(optimized, mod)
  assert_eq(scratch.funcs_visited, 1)
  assert_eq(scratch.funcs_changed, 0)
  assert_false(scratch.changed)
}

///|
test "dead code elimination preserves prefix effects before an unreachable binary operand" {
  let body = dead_code_elimination_test_body([
    @lib.TInstr::drop(
      @lib.TInstr::binary(
        @lib.BinaryOp::i32_add(),
        @lib.TInstr::i32_const(@lib.I32::new(1)),
        @lib.TInstr::unreachable_(),
      ),
    ),
  ])
  assert_eq(body, [
    @lib.TInstr::block(
      @lib.BlockType::void_(),
      @lib.TExpr::new([
        @lib.TInstr::drop(@lib.TInstr::i32_const(@lib.I32::new(1))),
        @lib.TInstr::unreachable_(),
      ]),
    ),
  ])
}

///|
test "dead code elimination preserves store address effects before an unreachable value" {
  let body = dead_code_elimination_test_body([
    @lib.TInstr::store(
      @lib.StoreOp::i32_store(),
      @lib.MemArg::new(@lib.U32::new(0U), None, @lib.U64::new(0UL)),
      @lib.TInstr::i32_const(@lib.I32::new(8)),
      @lib.TInstr::unreachable_(),
    ),
  ])
  assert_eq(body, [
    @lib.TInstr::block(
      @lib.BlockType::void_(),
      @lib.TExpr::new([
        @lib.TInstr::drop(@lib.TInstr::i32_const(@lib.I32::new(8))),
        @lib.TInstr::unreachable_(),
      ]),
    ),
  ])
}

///|
test "dead code elimination preserves select value effects before an unreachable condition" {
  let body = dead_code_elimination_test_body([
    @lib.TInstr::drop(
      @lib.TInstr::select(
        None,
        @lib.TInstr::unreachable_(),
        @lib.TInstr::i32_const(@lib.I32::new(10)),
        @lib.TInstr::i32_const(@lib.I32::new(20)),
      ),
    ),
  ])
  assert_eq(body, [
    @lib.TInstr::block(
      @lib.BlockType::void_(),
      @lib.TExpr::new([
        @lib.TInstr::drop(@lib.TInstr::i32_const(@lib.I32::new(10))),
        @lib.TInstr::drop(@lib.TInstr::i32_const(@lib.I32::new(20))),
        @lib.TInstr::unreachable_(),
      ]),
    ),
  ])
}

///|
test "dead code elimination preserves earlier direct call arguments before an unreachable one" {
  let body = dead_code_elimination_test_call_body(
    @lib.TInstr::call(@lib.FuncIdx::new(0U), [
      @lib.TInstr::i32_const(@lib.I32::new(1)),
      @lib.TInstr::unreachable_(),
    ]),
  )
  assert_eq(body, [
    @lib.TInstr::block(
      @lib.BlockType::void_(),
      @lib.TExpr::new([
        @lib.TInstr::drop(@lib.TInstr::i32_const(@lib.I32::new(1))),
        @lib.TInstr::unreachable_(),
      ]),
    ),
  ])
}

///|
test "dead code elimination truncates typed function bodies after return" {
  let body = dead_code_elimination_test_body([
    @lib.TInstr::return_([]),
    @lib.TInstr::nop(),
  ])
  assert_eq(body, [@lib.TInstr::return_([])])
}

///|
test "dead code elimination truncates nested block tails after br without dropping outer code" {
  let body = dead_code_elimination_test_body([
    @lib.TInstr::block(
      @lib.BlockType::void_(),
      @lib.TExpr::new([
        @lib.TInstr::br(@lib.LabelIdx::new(0U), []),
        @lib.TInstr::nop(),
      ]),
    ),
    @lib.TInstr::nop(),
  ])
  assert_eq(body, [
    @lib.TInstr::block(
      @lib.BlockType::void_(),
      @lib.TExpr::new([@lib.TInstr::br(@lib.LabelIdx::new(0U), [])]),
    ),
    @lib.TInstr::nop(),
  ])
}

///|
test "dead code elimination truncates code after a rewritten unreachable block" {
  let body = dead_code_elimination_test_body([
    @lib.TInstr::drop(
      @lib.TInstr::binary(
        @lib.BinaryOp::i32_add(),
        @lib.TInstr::i32_const(@lib.I32::new(1)),
        @lib.TInstr::unreachable_(),
      ),
    ),
    @lib.TInstr::nop(),
  ])
  assert_eq(body, [
    @lib.TInstr::block(
      @lib.BlockType::void_(),
      @lib.TExpr::new([
        @lib.TInstr::drop(@lib.TInstr::i32_const(@lib.I32::new(1))),
        @lib.TInstr::unreachable_(),
      ]),
    ),
  ])
}

///|
test "dead code elimination collapses trivial unreachable blocks" {
  let body = dead_code_elimination_test_body([
    @lib.TInstr::block(
      @lib.BlockType::void_(),
      @lib.TExpr::new([@lib.TInstr::unreachable_(), @lib.TInstr::nop()]),
    ),
  ])
  assert_eq(body, [@lib.TInstr::unreachable_()])
}

///|
test "dead code elimination retags concrete blocks when no live breaks remain" {
  let body = dead_code_elimination_test_body([
    @lib.TInstr::drop(
      @lib.TInstr::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.TExpr::new([
          @lib.TInstr::drop(@lib.TInstr::i32_const(@lib.I32::new(1))),
          @lib.TInstr::unreachable_(),
        ]),
      ),
    ),
  ])
  assert_eq(body, [
    @lib.TInstr::block(
      @lib.BlockType::void_(),
      @lib.TExpr::new([
        @lib.TInstr::drop(@lib.TInstr::i32_const(@lib.I32::new(1))),
        @lib.TInstr::unreachable_(),
      ]),
    ),
  ])
}

///|
test "dead code elimination keeps concrete blocks with live incoming br_if values" {
  let body = dead_code_elimination_test_body([
    @lib.TInstr::drop(
      @lib.TInstr::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.TExpr::new([
          @lib.TInstr::br_if(
            @lib.LabelIdx::new(0U),
            @lib.TInstr::i32_const(@lib.I32::new(1)),
            [@lib.TInstr::i32_const(@lib.I32::new(7))],
          ),
          @lib.TInstr::unreachable_(),
        ]),
      ),
    ),
  ])
  assert_eq(body, [
    @lib.TInstr::drop(
      @lib.TInstr::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.TExpr::new([
          @lib.TInstr::br_if(
            @lib.LabelIdx::new(0U),
            @lib.TInstr::i32_const(@lib.I32::new(1)),
            [@lib.TInstr::i32_const(@lib.I32::new(7))],
          ),
          @lib.TInstr::unreachable_(),
        ]),
      ),
    ),
  ])
}

///|
test "dead code elimination replaces ifs whose condition is unreachable" {
  let body = dead_code_elimination_test_body([
    @lib.TInstr::drop(
      @lib.TInstr::if_(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.TInstr::unreachable_(),
        @lib.TExpr::new([@lib.TInstr::i32_const(@lib.I32::new(1))]),
        Some(@lib.TExpr::new([@lib.TInstr::i32_const(@lib.I32::new(2))])),
      ),
    ),
  ])
  assert_eq(body, [@lib.TInstr::unreachable_()])
}

///|
test "dead code elimination retags ifs when both arms are unreachable" {
  let body = dead_code_elimination_test_body([
    @lib.TInstr::drop(
      @lib.TInstr::if_(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.TInstr::i32_const(@lib.I32::new(1)),
        @lib.TExpr::new([@lib.TInstr::unreachable_()]),
        Some(@lib.TExpr::new([@lib.TInstr::unreachable_()])),
      ),
    ),
  ])
  assert_eq(body, [
    @lib.TInstr::if_(
      @lib.BlockType::void_(),
      @lib.TInstr::i32_const(@lib.I32::new(1)),
      @lib.TExpr::new([@lib.TInstr::unreachable_()]),
      Some(@lib.TExpr::new([@lib.TInstr::unreachable_()])),
    ),
  ])
}

///|
test "dead code elimination replaces loops whose body is literal unreachable" {
  let body = dead_code_elimination_test_body([
    @lib.TInstr::loop_(
      @lib.BlockType::void_(),
      @lib.TExpr::new([@lib.TInstr::unreachable_()]),
    ),
  ])
  assert_eq(body, [@lib.TInstr::unreachable_()])
}

///|
test "dead code elimination leaves branch-back loops alone" {
  let body = dead_code_elimination_test_body([
    @lib.TInstr::loop_(
      @lib.BlockType::void_(),
      @lib.TExpr::new([@lib.TInstr::br(@lib.LabelIdx::new(0U), [])]),
    ),
    @lib.TInstr::nop(),
  ])
  assert_eq(body, [
    @lib.TInstr::loop_(
      @lib.BlockType::void_(),
      @lib.TExpr::new([@lib.TInstr::br(@lib.LabelIdx::new(0U), [])]),
    ),
    @lib.TInstr::nop(),
  ])
}

///|
test "dead code elimination retags try_table when its body is unreachable" {
  let body = dead_code_elimination_test_body([
    @lib.TInstr::drop(
      @lib.TInstr::try_table(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        [],
        @lib.TExpr::new([@lib.TInstr::unreachable_()]),
      ),
    ),
  ])
  assert_eq(body, [
    @lib.TInstr::try_table(
      @lib.BlockType::void_(),
      [],
      @lib.TExpr::new([@lib.TInstr::unreachable_()]),
    ),
  ])
}

///|
test "dead code elimination replaces br when its branch value is unreachable" {
  let body = dead_code_elimination_test_body([
    @lib.TInstr::drop(
      @lib.TInstr::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.TExpr::new([
          @lib.TInstr::br(@lib.LabelIdx::new(0U), [@lib.TInstr::unreachable_()]),
          @lib.TInstr::i32_const(@lib.I32::new(1)),
        ]),
      ),
    ),
  ])
  assert_eq(body, [@lib.TInstr::unreachable_()])
}

///|
test "dead code elimination replaces br_if when its condition is unreachable" {
  let body = dead_code_elimination_test_body([
    @lib.TInstr::block(
      @lib.BlockType::void_(),
      @lib.TExpr::new([
        @lib.TInstr::br_if(
          @lib.LabelIdx::new(0U),
          @lib.TInstr::unreachable_(),
          [],
        ),
        @lib.TInstr::nop(),
      ]),
    ),
    @lib.TInstr::nop(),
  ])
  assert_eq(body, [@lib.TInstr::unreachable_()])
}

///|
test "dead code elimination replaces br_table when its index is unreachable" {
  let body = dead_code_elimination_test_body([
    @lib.TInstr::block(
      @lib.BlockType::void_(),
      @lib.TExpr::new([
        @lib.TInstr::br_table(
          [],
          @lib.LabelIdx::new(0U),
          @lib.TInstr::unreachable_(),
          [],
        ),
        @lib.TInstr::nop(),
      ]),
    ),
    @lib.TInstr::nop(),
  ])
  assert_eq(body, [@lib.TInstr::unreachable_()])
}

///|
test "dead code elimination drops stale outer block value after dead nested br_if" {
  let body = dead_code_elimination_test_body([
    @lib.TInstr::drop(
      @lib.TInstr::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.TExpr::new([
          @lib.TInstr::block(
            @lib.BlockType::void_(),
            @lib.TExpr::new([
              @lib.TInstr::br_if(
                @lib.LabelIdx::new(1U),
                @lib.TInstr::unreachable_(),
                [@lib.TInstr::i32_const(@lib.I32::new(7))],
              ),
            ]),
          ),
          @lib.TInstr::unreachable_(),
        ]),
      ),
    ),
  ])
  assert_eq(body, [
    @lib.TInstr::block(
      @lib.BlockType::void_(),
      @lib.TExpr::new([
        @lib.TInstr::block(
          @lib.BlockType::void_(),
          @lib.TExpr::new([
            @lib.TInstr::drop(@lib.TInstr::i32_const(@lib.I32::new(7))),
            @lib.TInstr::unreachable_(),
          ]),
        ),
      ]),
    ),
  ])
}

///|
test "dead code elimination replaces br_on_non_null when its ref is unreachable" {
  let body = dead_code_elimination_test_result_body(
    [
      @lib.ValType::ref_type(
        @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::func())),
      ),
    ],
    [
      @lib.TInstr::block(
        @lib.BlockType::val_type(
          @lib.ValType::ref_type(
            @lib.RefType::new(
              false,
              @lib.HeapType::abs(@lib.AbsHeapType::func()),
            ),
          ),
        ),
        @lib.TExpr::new([
          @lib.TInstr::br_on_non_null(
            @lib.LabelIdx::new(0U),
            @lib.TInstr::unreachable_(),
            [],
          ),
        ]),
      ),
    ],
  )
  assert_eq(body, [@lib.TInstr::unreachable_()])
}

///|
test "dead code elimination replaces br_on_cast_fail when its ref is unreachable" {
  let body = dead_code_elimination_test_result_body(
    [@lib.ValType::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::func()))],
    [
      @lib.TInstr::block(
        @lib.BlockType::val_type(
          @lib.ValType::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::func())),
        ),
        @lib.TExpr::new([
          @lib.TInstr::br_on_cast_fail(
            @lib.LabelIdx::new(0U),
            true,
            @lib.HeapType::abs(@lib.AbsHeapType::func()),
            false,
            @lib.HeapType::abs(@lib.AbsHeapType::func()),
            @lib.TInstr::unreachable_(),
            [],
          ),
        ]),
      ),
    ],
  )
  assert_eq(body, [@lib.TInstr::unreachable_()])
}

///|
test "dead code elimination replaces ref_cast when its operand is unreachable" {
  let body = dead_code_elimination_test_result_body(
    [@lib.ValType::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::func()))],
    [
      @lib.TInstr::block(
        @lib.BlockType::val_type(
          @lib.ValType::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::func())),
        ),
        @lib.TExpr::new([
          @lib.TInstr::ref_cast(
            true,
            @lib.HeapType::abs(@lib.AbsHeapType::func()),
            @lib.TInstr::unreachable_(),
          ),
        ]),
      ),
    ],
  )
  assert_eq(body, [@lib.TInstr::unreachable_()])
}

///|
test "dead code elimination replaces ref_test_desc when its operand is unreachable" {
  let body = dead_code_elimination_test_body([
    @lib.TInstr::drop(
      @lib.TInstr::ref_test_desc(
        true,
        @lib.HeapType::abs(@lib.AbsHeapType::eq()),
        @lib.TInstr::unreachable_(),
      ),
    ),
  ])
  assert_eq(body, [@lib.TInstr::unreachable_()])
}

///|
test "dead code elimination replaces ref_cast_desc_eq when its operand is unreachable" {
  let body = dead_code_elimination_test_result_body(
    [@lib.ValType::eqref_null()],
    [
      @lib.TInstr::block(
        @lib.BlockType::val_type(@lib.ValType::eqref_null()),
        @lib.TExpr::new([
          @lib.TInstr::ref_cast_desc_eq(
            true,
            @lib.HeapType::abs(@lib.AbsHeapType::eq()),
            @lib.TInstr::unreachable_(),
          ),
        ]),
      ),
    ],
  )
  assert_eq(body, [@lib.TInstr::unreachable_()])
}
