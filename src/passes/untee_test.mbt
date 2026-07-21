///|
fn untee_test_run(text : String) -> @lib.Module {
  match pass_test_run_pipeline(text, ["untee"]) {
    Ok(mod_) => mod_
    Err(err) => abort("expected untee pipeline success, got \{err}")
  }
}

///|
fn untee_test_first_body(mod_ : @lib.Module) -> Array[@lib.Instruction] {
  match mod_.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body)), ..])) => body
    _ => abort("expected at least one function body")
  }
}

///|
test "untee rewrites root local tee to set plus get" {
  let input =
    #| (module
    #|   (func (result i32) (local i32)
    #|     i32.const 7
    #|     local.tee 0))
  let optimized = untee_test_run(input)

  match untee_test_first_body(optimized) {
    [
      @lib.I32Const(_),
      @lib.LocalSet(@lib.LocalIdx(0U)),
      @lib.LocalGet(@lib.LocalIdx(0U)),
    ] => ()
    other => fail("expected tee expansion, got \{other}")
  }
}

///|
test "untee rewrites nested tees inside out" {
  let input =
    #| (module
    #|   (func (result i32) (local i32 i32)
    #|     i32.const 7
    #|     local.tee 0
    #|     local.tee 1))
  let optimized = untee_test_run(input)

  match untee_test_first_body(optimized) {
    [
      @lib.I32Const(_),
      @lib.LocalSet(@lib.LocalIdx(0U)),
      @lib.LocalGet(@lib.LocalIdx(0U)),
      @lib.LocalSet(@lib.LocalIdx(1U)),
      @lib.LocalGet(@lib.LocalIdx(1U)),
    ] => ()
    other => fail("expected nested tee expansion, got \{other}")
  }
}

///|
test "untee deletes tee whose direct input is unreachable" {
  let input =
    #| (module
    #|   (func (result i32) (local i32)
    #|     unreachable
    #|     local.tee 0))
  let optimized = untee_test_run(input)

  match untee_test_first_body(optimized) {
    [@lib.Unreachable] => ()
    other => fail("expected unreachable tee deletion, got \{other}")
  }
}

///|
test "untee rewrites legacy try protected and catch bodies" {
  let try_ = @lib.Instruction::try_(
    @lib.BlockType::void_(),
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
    ]),
    [
      @lib.LegacyCatch::tagged(
        @lib.TagIdx::new(0U),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(2)),
          @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
          @lib.Instruction::drop(),
        ]),
      ),
      @lib.LegacyCatch::all(
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(3)),
          @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
          @lib.Instruction::drop(),
        ]),
      ),
    ],
  )
  let input = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([@lib.ValType::i32()]),
        @lib.Expr::new([try_]),
      ),
    ]),
  )
  match untee_test_first_body(untee_run_module_pass(input)) {
    [
      @lib.Try(
        _,
        @lib.Expr(
          [@lib.I32Const(_), @lib.LocalSet(_), @lib.LocalGet(_), @lib.Drop]
        ),
        [
          @lib.LegacyCatch(
            _,
            @lib.Expr(
              [@lib.I32Const(_), @lib.LocalSet(_), @lib.LocalGet(_), @lib.Drop]
            )
          ),
          @lib.LegacyCatchAll(
            @lib.Expr(
              [@lib.I32Const(_), @lib.LocalSet(_), @lib.LocalGet(_), @lib.Drop]
            )
          ),
        ],
        None
      ),
    ] => ()
    other => fail("expected legacy tee expansion in every region, got \{other}")
  }
}

///|
test "untee recurses into structured bodies" {
  let input =
    #| (module
    #|   (func (param i32) (result i32) (local i32)
    #|     local.get 0
    #|     if (result i32)
    #|       i32.const 1
    #|       local.tee 1
    #|     else
    #|       i32.const 2
    #|       local.tee 1
    #|     end))
  let optimized = untee_test_run(input)

  match untee_test_first_body(optimized) {
    [
      @lib.LocalGet(@lib.LocalIdx(0U)),
      @lib.If(
        _,
        [
          @lib.I32Const(_),
          @lib.LocalSet(@lib.LocalIdx(1U)),
          @lib.LocalGet(@lib.LocalIdx(1U)),
        ],
        Some(
          [
            @lib.I32Const(_),
            @lib.LocalSet(@lib.LocalIdx(1U)),
            @lib.LocalGet(@lib.LocalIdx(1U)),
          ]
        )
      ),
    ] => ()
    other => fail("expected recursive tee expansion, got \{other}")
  }
}
