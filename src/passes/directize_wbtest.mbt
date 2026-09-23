///|
fn directize_wbtest_mixed_table_module() -> @lib.Module {
  let callee_type = @lib.TypeIdx::new(0U)
  let caller_type = @lib.TypeIdx::new(1U)
  let table_type = @lib.TableType::new(
    @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::func())),
    @lib.Limits::i32(1U, Some(1U)),
  )
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
      ),
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func([@lib.ValType::funcref()], [@lib.ValType::i32()]),
        ),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([callee_type, caller_type]))
  .with_table_sec(
    @lib.TableSec::new([
      @lib.Table::new(table_type, None),
      @lib.Table::new(table_type, None),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(7))]),
      ),
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::table_set(@lib.TableIdx::new(1U)),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::call_indirect(callee_type, @lib.TableIdx::new(1U)),
        ]),
      ),
    ]),
  )
}

///|
test "directize admission ignores nonoptimizable table calls in mixed modules" {
  let mod_ = directize_wbtest_mixed_table_module()
  let info = directize_build_info(mod_)
  assert_true(info.tables[0].can_optimize)
  assert_false(info.tables[1].can_optimize)
  let caller_body = match mod_.code_sec {
    Some(@lib.CodeSec([_, @lib.Func(_, @lib.Expr(body))])) => body
    _ => fail("expected mixed-table caller body")
  }
  assert_false(directize_instrs_have_rewrite_candidate(caller_body, info))
  assert_true(
    directize_instrs_have_rewrite_candidate(
      [
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::call_indirect(
              @lib.TypeIdx::new(0U),
              @lib.TableIdx::new(0U),
            ),
          ]),
        ),
      ],
      info,
    ),
  )
  assert_false(
    directize_instrs_have_rewrite_candidate(
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_load(
          @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0UL)),
        ),
        @lib.Instruction::call_indirect(
          @lib.TypeIdx::new(0U),
          @lib.TableIdx::new(0U),
        ),
      ],
      info,
    ),
  )
}

///|
test "directize remaps label names after synthetic select if" {
  let wat =
    #|(module
    #|  (type (func (param i32) (result i32)))
    #|  (table 2 funcref)
    #|  (func $a (type 0) (param i32) (result i32) local.get 0)
    #|  (func $b (type 0) (param i32) (result i32) local.get 0)
    #|  (elem (i32.const 0) $a $b)
    #|  (func (export "run") (param i32 i32) (result i32)
    #|    block nop end
    #|    local.get 0
    #|    i32.const 0
    #|    i32.const 1
    #|    local.get 1
    #|    select
    #|    call_indirect (type 0)
    #|    drop
    #|    block (result i32) i32.const 5 end))
  let input = pass_test_module_from_wat(wat).with_name_sec(
    @lib.NameSec::new(
      label_names=Some(
        @lib.IndirectNameMap::new([
          @lib.IndirectNameAssoc::new(
            2U,
            @lib.NameMap::new([
              @lib.NameAssoc::new(0U, @lib.Name::from_string("before")),
              @lib.NameAssoc::new(1U, @lib.Name::from_string("after")),
            ]),
          ),
        ]),
      ),
    ),
  )
  let output = directize_run_module_pass(input)
  match output.name_sec.unwrap().label_names {
    Some(
      @lib.IndirectNameMap([@lib.IndirectNameAssoc(_, @lib.NameMap(entries))])
    ) => {
      @debug.assert_eq(entries[0].0, 0U)
      @debug.assert_eq(entries[1].0, 2U)
    }
    _ => fail("expected two named labels")
  }
  assert_true(@validate.validate_module(output) is Ok(_))
}
