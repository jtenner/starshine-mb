///|
fn string_gathering_test_type_sec() -> @lib.TypeSec {
  @lib.TypeSec::new([
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
  ])
}

///|
fn string_gathering_test_global(
  bytes : Bytes,
  mutable? : Bool = false,
) -> @lib.Global {
  @lib.Global::new(
    @lib.GlobalType::new(@lib.ValType::stringref(), mutable),
    @lib.Expr::new([@lib.Instruction::string_const(bytes)]),
  )
}

///|
test "string gathering reuses existing immutable globals in typed function bodies" {
  let mod = Module::new()
    .with_type_sec(string_gathering_test_type_sec())
    .with_global_sec(
      @lib.GlobalSec::new([string_gathering_test_global(b"hello")]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::t_func(
          [],
          @lib.Locals::empty(),
          @lib.TExpr::new([
            @lib.TInstr::drop(@lib.TInstr::string_const(b"hello")),
            @lib.TInstr::drop(@lib.TInstr::string_const(b"bye")),
          ]),
        ),
      ]),
    )

  let (optimized, _) = run_string_gathering(
    mod,
    PipelineGlobal::new(opt_level=2),
    PipelineFeatures::new(has_strings=true),
  )

  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.TFunc(_, _, body)])) => {
      match body.inner()[0].kind {
        @lib.TDrop(child) =>
          match child.kind {
            @lib.TGlobalGet(@lib.GlobalIdx(global_idx)) =>
              assert_eq(global_idx, 0U)
            _ => fail("expected first drop child to become global.get")
          }
        _ => fail("expected first typed instruction to stay a drop")
      }
      match body.inner()[1].kind {
        @lib.TDrop(child) =>
          match child.kind {
            @lib.TStringConst(bytes) => assert_eq(bytes, b"bye")
            _ => fail("expected second drop child to stay string.const")
          }
        _ => fail("expected second typed instruction to stay a drop")
      }
    }
    _ => fail("expected one typed function body")
  }
}

///|
test "string gathering reuses existing immutable globals in raw function bodies" {
  let mod = Module::new()
    .with_type_sec(string_gathering_test_type_sec())
    .with_global_sec(
      @lib.GlobalSec::new([string_gathering_test_global(b"hello")]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::string_const(b"hello"),
            @lib.Instruction::drop(),
            @lib.Instruction::string_const(b"bye"),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )

  let (optimized, _) = run_string_gathering(
    mod,
    PipelineGlobal::new(opt_level=2),
    PipelineFeatures::new(has_strings=true),
  )

  match optimized.code_sec {
    Some(
      @lib.CodeSec(
        [
          @lib.Func(
            _,
            @lib.Expr(
              [
                @lib.GlobalGet(@lib.GlobalIdx(global_idx)),
                @lib.Drop,
                @lib.StringConst(bytes),
                @lib.Drop,
              ]
            )
          ),
        ]
      )
    ) => {
      assert_eq(global_idx, 0U)
      assert_eq(bytes, b"bye")
    }
    _ => fail("expected one raw function body")
  }
}

///|
test "string gathering ignores imported string globals for reuse" {
  let mod = Module::new()
    .with_type_sec(string_gathering_test_type_sec())
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("hello"),
          @lib.ExternType::global(
            @lib.GlobalType::new(@lib.ValType::stringref(), false),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::string_const(b"hello"),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )

  let (optimized, _) = run_string_gathering(
    mod,
    PipelineGlobal::new(opt_level=2),
    PipelineFeatures::new(has_strings=true),
  )

  match optimized.code_sec {
    Some(
      @lib.CodeSec(
        [@lib.Func(_, @lib.Expr([@lib.StringConst(bytes), @lib.Drop]))]
      )
    ) => assert_eq(bytes, b"hello")
    _ => fail("expected one raw function body")
  }
}
