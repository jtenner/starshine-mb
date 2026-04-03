///|
fn rl_test_first_defined_func(mod_ : @lib.Module) -> @lib.Func {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs.get(0) {
        Some(func) => func
        None => abort("expected first defined function")
      }
    None => abort("expected code section")
  }
}

///|
fn rl_test_name_sec_fixture() -> @lib.Module {
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
      ),
    ),
  ])
  @lib.Module::new()
  .with_type_sec(type_sec)
  .with_import_sec(
    @lib.ImportSec::new([
      @lib.Import::new(
        @lib.Name::from_string("env"),
        @lib.Name::from_string("imp"),
        @lib.ExternType::func(@lib.TypeIdx::new(0U)),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i64()]),
        @lib.Expr::new([
          @lib.Instruction::i64_const(@lib.I64(9L)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::drop(),
          @lib.Instruction::i32_const(@lib.I32(7)),
        ]),
      ),
    ]),
  )
  .with_name_sec(
    @lib.NameSec::new(
      local_names=Some(
        @lib.IndirectNameMap::new([
          @lib.IndirectNameAssoc::new(
            0U,
            @lib.NameMap::new([
              @lib.NameAssoc::new(0U, @lib.Name::from_string("imp_param")),
            ]),
          ),
          @lib.IndirectNameAssoc::new(
            1U,
            @lib.NameMap::new([
              @lib.NameAssoc::new(0U, @lib.Name::from_string("param")),
              @lib.NameAssoc::new(1U, @lib.Name::from_string("unused_local")),
              @lib.NameAssoc::new(2U, @lib.Name::from_string("written_local")),
            ]),
          ),
        ]),
      ),
    ),
  )
  .with_raw_name_sec_payload(b"raw")
}

///|
fn rl_test_nested_fixture() -> @lib.Module {
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
    ),
  ])
  @lib.Module::new()
  .with_type_sec(type_sec)
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([
          @lib.ValType::i32(),
          @lib.ValType::i64(),
          @lib.ValType::i32(),
        ]),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::void_(),
            @lib.Expr::new([
              @lib.Instruction::loop_(
                @lib.BlockType::void_(),
                @lib.Expr::new([
                  @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                  @lib.Instruction::drop(),
                  @lib.Instruction::i32_const(@lib.I32(1)),
                  @lib.Instruction::if_(
                    @lib.BlockType::void_(),
                    [
                      @lib.Instruction::i32_const(@lib.I32(7)),
                      @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
                      @lib.Instruction::try_table(
                        @lib.BlockType::void_(),
                        [],
                        @lib.Expr::new([
                          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                          @lib.Instruction::drop(),
                        ]),
                      ),
                    ],
                    Some([
                      @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                      @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
                      @lib.Instruction::drop(),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ]),
  )
}

///|
fn rl_test_multi_defined_fixture() -> @lib.Module {
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
      ),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::i64(), @lib.ValType::i32()], []),
      ),
    ),
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
  ])
  @lib.Module::new()
  .with_type_sec(type_sec)
  .with_import_sec(
    @lib.ImportSec::new([
      @lib.Import::new(
        @lib.Name::from_string("env"),
        @lib.Name::from_string("imp"),
        @lib.ExternType::func(@lib.TypeIdx::new(0U)),
      ),
    ]),
  )
  .with_func_sec(
    @lib.FuncSec::new([@lib.TypeIdx::new(1U), @lib.TypeIdx::new(2U)]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i64()]),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::drop(),
          @lib.Instruction::i64_const(@lib.I64(9L)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
        ]),
      ),
      @lib.Func::new(
        @lib.Locals::from_types([@lib.ValType::i64(), @lib.ValType::i32()]),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(5)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::drop(),
        ]),
      ),
    ]),
  )
  .with_name_sec(
    @lib.NameSec::new(
      local_names=Some(
        @lib.IndirectNameMap::new([
          @lib.IndirectNameAssoc::new(
            1U,
            @lib.NameMap::new([
              @lib.NameAssoc::new(0U, @lib.Name::from_string("lhs")),
              @lib.NameAssoc::new(1U, @lib.Name::from_string("rhs")),
              @lib.NameAssoc::new(2U, @lib.Name::from_string("unused")),
              @lib.NameAssoc::new(3U, @lib.Name::from_string("written")),
            ]),
          ),
          @lib.IndirectNameAssoc::new(
            2U,
            @lib.NameMap::new([
              @lib.NameAssoc::new(0U, @lib.Name::from_string("a")),
              @lib.NameAssoc::new(1U, @lib.Name::from_string("b")),
            ]),
          ),
        ]),
      ),
    ),
  )
  .with_raw_name_sec_payload(b"raw")
}

///|
test "reorder-locals handles multiple defined functions with distinct param arities" {
  let optimized = match
    run_hot_pipeline(
      rl_test_multi_defined_fixture(),
      HotPipelineOptions::new(),
      ["reorder-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected reorder-locals multi-defined fixture success, got \{err}")
  }
  assert_eq(optimized.raw_name_sec_payload, None)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(first_locals, @lib.Expr(first_instrs)) = funcs[0]
      assert_eq(first_locals, @lib.Locals::from_types([@lib.ValType::i64()]))
      assert_eq(
        first_instrs[3],
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
      )
      let @lib.Func(second_locals, @lib.Expr(second_instrs)) = funcs[1]
      assert_eq(
        second_locals,
        @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i64()]),
      )
      assert_eq(
        second_instrs[1],
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      )
      assert_eq(
        second_instrs[2],
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      )
    }
    None => fail("expected rewritten code section")
  }
  match optimized.name_sec {
    Some(name_sec) =>
      match name_sec.local_names {
        Some(@lib.IndirectNameMap(entries)) => {
          assert_eq(entries.length(), 2)
          assert_eq(
            entries[0],
            @lib.IndirectNameAssoc::new(
              1U,
              @lib.NameMap::new([
                @lib.NameAssoc::new(0U, @lib.Name::from_string("lhs")),
                @lib.NameAssoc::new(1U, @lib.Name::from_string("rhs")),
                @lib.NameAssoc::new(2U, @lib.Name::from_string("written")),
              ]),
            ),
          )
          assert_eq(
            entries[1],
            @lib.IndirectNameAssoc::new(
              2U,
              @lib.NameMap::new([
                @lib.NameAssoc::new(0U, @lib.Name::from_string("b")),
                @lib.NameAssoc::new(1U, @lib.Name::from_string("a")),
              ]),
            ),
          )
        }
        None => fail("expected rewritten local names")
      }
    None => fail("expected name section")
  }
}

///|
test "reorder-locals is a no-op when a function has only params" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32 i64) (result i32) local.get 0))",
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["reorder-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected reorder-locals params-only success, got \{err}")
  }
  assert_eq(optimized, input)
}

///|
test "run_hot_pipeline applies reorder-locals by Binaryen access count and first-use order" {
  let input =
    #| (module
    #|   (func (param i32) (result i32) (local i32 i64 i32 i64)
    #|     i64.const 11
    #|     local.set 2
    #|     i32.const 22
    #|     local.set 3
    #|     local.get 3
    #|     drop
    #|     local.get 1))
    #|
  let optimized = match pass_test_run_pipeline(input, ["reorder-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected reorder-locals pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = rl_test_first_defined_func(
    optimized,
  )
  assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i64(),
      @lib.ValType::i32(),
    ]),
  )
  assert_eq(instrs.length(), 7)
  assert_eq(instrs[1], @lib.Instruction::local_set(@lib.LocalIdx::new(2U)))
  assert_eq(instrs[3], @lib.Instruction::local_set(@lib.LocalIdx::new(1U)))
  assert_eq(instrs[4], @lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
  assert_eq(instrs[6], @lib.Instruction::local_get(@lib.LocalIdx::new(3U)))
}

///|
test "reorder-locals keeps write-only locals and drops only zero-access body locals" {
  let input =
    #| (module
    #|   (func (result i32) (local i32 i64)
    #|     i64.const 11
    #|     local.set 1
    #|     i32.const 7))
    #|
  let optimized = match pass_test_run_pipeline(input, ["reorder-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected reorder-locals pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = rl_test_first_defined_func(
    optimized,
  )
  assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i64()]))
  assert_eq(instrs[1], @lib.Instruction::local_set(@lib.LocalIdx::new(0U)))
}

///|
test "reorder-locals drops unused trailing locals without rewriting stable live indices" {
  let input =
    #| (module
    #|   (func (result i32) (local i32 i64)
    #|     i32.const 5
    #|     local.set 0
    #|     local.get 0))
    #|
  let optimized = match pass_test_run_pipeline(input, ["reorder-locals"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected reorder-locals trailing-local trim success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = rl_test_first_defined_func(
    optimized,
  )
  assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  assert_eq(instrs[1], @lib.Instruction::local_set(@lib.LocalIdx::new(0U)))
  assert_eq(instrs[2], @lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
}

///|
test "reorder-locals counts local.tee as an access" {
  let input =
    #| (module
    #|   (func (result i32) (local i32 i64)
    #|     i32.const 5
    #|     local.tee 0
    #|     drop
    #|     i32.const 7))
    #|
  let optimized = match pass_test_run_pipeline(input, ["reorder-locals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected reorder-locals pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = rl_test_first_defined_func(
    optimized,
  )
  assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  assert_eq(instrs[1], @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)))
}

///|
test "reorder-locals rewrites nested block loop if and try_table local indices" {
  let optimized = match
    run_hot_pipeline(rl_test_nested_fixture(), HotPipelineOptions::new(), [
      "reorder-locals",
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected reorder-locals nested rewrite success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = rl_test_first_defined_func(
    optimized,
  )
  assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i64(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  assert_eq(instrs.length(), 1)
  match instrs[0] {
    @lib.Block(_, @lib.Expr(block_instrs)) => {
      assert_eq(block_instrs.length(), 1)
      match block_instrs[0] {
        @lib.Loop(_, @lib.Expr(loop_instrs)) => {
          assert_eq(
            loop_instrs[0],
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          )
          assert_eq(loop_instrs[1], @lib.Instruction::drop())
          assert_eq(loop_instrs[2], @lib.Instruction::i32_const(@lib.I32(1)))
          match loop_instrs[3] {
            @lib.If(_, then_body, Some(else_body)) => {
              assert_eq(
                then_body[1],
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              )
              match then_body[2] {
                @lib.TryTable(_, [], @lib.Expr(try_body)) =>
                  assert_eq(try_body, [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                    @lib.Instruction::drop(),
                  ])
                _ => fail("expected rewritten try_table in then body")
              }
              assert_eq(else_body, [
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
                @lib.Instruction::drop(),
              ])
            }
            _ => fail("expected rewritten nested if")
          }
        }
        _ => fail("expected rewritten nested loop")
      }
    }
    _ => fail("expected rewritten outer block")
  }
}

///|
test "reorder-locals rewrites local names for changed defined functions and clears raw payload" {
  let optimized = match
    run_hot_pipeline(rl_test_name_sec_fixture(), HotPipelineOptions::new(), [
      "reorder-locals",
    ]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected reorder-locals name rewrite success, got \{err}")
  }
  assert_eq(optimized.raw_name_sec_payload, None)
  let @lib.Func(locals, @lib.Expr(instrs)) = rl_test_first_defined_func(
    optimized,
  )
  assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i64()]))
  assert_eq(instrs[1], @lib.Instruction::local_set(@lib.LocalIdx::new(1U)))
  match optimized.name_sec {
    Some(name_sec) =>
      match name_sec.local_names {
        Some(@lib.IndirectNameMap(entries)) => {
          assert_eq(entries.length(), 2)
          assert_eq(
            entries[0],
            @lib.IndirectNameAssoc::new(
              0U,
              @lib.NameMap::new([
                @lib.NameAssoc::new(0U, @lib.Name::from_string("imp_param")),
              ]),
            ),
          )
          assert_eq(
            entries[1],
            @lib.IndirectNameAssoc::new(
              1U,
              @lib.NameMap::new([
                @lib.NameAssoc::new(0U, @lib.Name::from_string("param")),
                @lib.NameAssoc::new(1U, @lib.Name::from_string("written_local")),
              ]),
            ),
          )
        }
        None => fail("expected rewritten local names")
      }
    None => fail("expected name section")
  }
}

///|
test "reorder-locals sorts a Binaryen-materialized carrier fixture by access count and first use" {
  let input =
    #| (module
    #|   (type (func (param i32 i32) (result i32 i32 i32)))
    #|   (type (func (param i32 i32 i32) (result i32)))
    #|   (type (func (param i32) (result i32)))
    #|   (import "env" "triple" (func (type 0)))
    #|   (import "env" "combine" (func (type 1)))
    #|   (func (type 2) (param i32) (result i32)
    #|     (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
    #|     i32.const 10000
    #|     local.set 1
    #|     local.get 0
    #|     local.get 1
    #|     call 0
    #|     local.set 17
    #|     local.set 16
    #|     local.tee 15
    #|     local.set 19
    #|     local.get 16
    #|     local.set 18
    #|     local.get 17
    #|     local.set 2
    #|     local.get 18
    #|     local.set 3
    #|     local.get 19
    #|     local.tee 4
    #|     local.set 5
    #|     local.get 3
    #|     local.set 6
    #|     local.get 2
    #|     local.set 7
    #|     local.get 6
    #|     local.set 8
    #|     local.get 5
    #|     local.tee 9
    #|     local.set 10
    #|     local.get 8
    #|     local.set 11
    #|     local.get 7
    #|     local.set 12
    #|     local.get 11
    #|     local.set 13
    #|     local.get 10
    #|     local.tee 14
    #|     local.get 13
    #|     local.get 12
    #|     call 1))
    #|
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["reorder-locals"],
      options=HotPipelineOptions::new(
        verify_policy=HotPipelineVerifyPolicy::after_each_pass(),
      ),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected reorder-locals Binaryen-materialized carrier fixture success, got \{err}",
      )
  }
  let expected =
    #| (module
    #|   (type (func (param i32 i32) (result i32 i32 i32)))
    #|   (type (func (param i32 i32 i32) (result i32)))
    #|   (type (func (param i32) (result i32)))
    #|   (import "env" "triple" (func (type 0)))
    #|   (import "env" "combine" (func (type 1)))
    #|   (func (type 2) (param i32) (result i32)
    #|     (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
    #|     i32.const 10000
    #|     local.set 1
    #|     local.get 0
    #|     local.get 1
    #|     call 0
    #|     local.set 2
    #|     local.set 3
    #|     local.tee 16
    #|     local.set 4
    #|     local.get 3
    #|     local.set 5
    #|     local.get 2
    #|     local.set 6
    #|     local.get 5
    #|     local.set 7
    #|     local.get 4
    #|     local.tee 17
    #|     local.set 8
    #|     local.get 7
    #|     local.set 9
    #|     local.get 6
    #|     local.set 10
    #|     local.get 9
    #|     local.set 11
    #|     local.get 8
    #|     local.tee 18
    #|     local.set 12
    #|     local.get 11
    #|     local.set 13
    #|     local.get 10
    #|     local.set 14
    #|     local.get 13
    #|     local.set 15
    #|     local.get 12
    #|     local.tee 19
    #|     local.get 15
    #|     local.get 14
    #|     call 1)
    #| )
    #|
  assert_eq(optimized, pass_test_module_from_wat(expected))
}
