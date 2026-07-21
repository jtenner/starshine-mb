///|
fn legacy_eh_test_try(
  body : Array[@lib.Instruction],
  tagged : Array[@lib.Instruction],
  all : Array[@lib.Instruction],
) -> @lib.Instruction {
  @lib.Instruction::try_(
    @lib.BlockType::void_(),
    @lib.Expr::new(body),
    [
      @lib.LegacyCatch::tagged(@lib.TagIdx::new(0U), @lib.Expr::new(tagged)),
      @lib.LegacyCatch::all(@lib.Expr::new(all)),
    ],
    delegate=Some(@lib.LabelIdx::new(2U)),
  )
}

///|
fn legacy_eh_test_module() -> @lib.Module {
  @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          legacy_eh_test_try(
            [@lib.Instruction::nop()],
            [@lib.Instruction::nop()],
            [@lib.Instruction::nop()],
          ),
        ]),
      ),
    ]),
  )
}

///|
test "legacy EH audit: shared structured walker rewrites protected and catch bodies" {
  let instr = legacy_eh_test_try(
    [@lib.Instruction::nop()],
    [@lib.Instruction::nop()],
    [@lib.Instruction::nop()],
  )
  let rewrite = fn(instrs : Array[@lib.Instruction]) {
    let out : Array[@lib.Instruction] = []
    for _ in instrs {
      out.push(@lib.Instruction::unreachable_())
    }
    (out, true)
  }
  let (rewritten, changed) = pass_rewrite_structured_instr(instr, rewrite)
  assert_true(changed)
  match rewritten {
    @lib.Try(
      @lib.VoidBlockType,
      @lib.Expr([@lib.Unreachable]),
      [
        @lib.LegacyCatch(_, @lib.Expr([@lib.Unreachable])),
        @lib.LegacyCatchAll(@lib.Expr([@lib.Unreachable])),
      ],
      Some(@lib.LabelIdx(2U))
    ) => ()
    other => fail("expected all legacy try regions rewritten, got \{other}")
  }
}

///|
test "legacy EH audit: TryTable-only module passes fail closed before partial analysis" {
  let mod_ = legacy_eh_test_module()
  assert_true(pass_module_has_legacy_try(mod_))
  @debug.assert_eq(coalesce_locals_run_module_pass(mod_), mod_)
  @debug.assert_eq(dfe_run_module_pass(mod_), mod_)
  @debug.assert_eq(global_refining_run_module_pass(mod_), mod_)
  @debug.assert_eq(global_struct_inference_run_module_pass(mod_, false), mod_)
  @debug.assert_eq(inlining_run_module_pass(mod_), mod_)
  @debug.assert_eq(inline_main_run_module_pass(mod_), mod_)
  @debug.assert_eq(local_subtyping_run_module_pass(mod_), mod_)
  @debug.assert_eq(memory_packing_run_module_pass(mod_), mod_)
  @debug.assert_eq(string_gathering_run_module_pass(mod_), mod_)
  let sgo = sgo_run_core(mod_, fn(_) { () })
  @debug.assert_eq(sgo.mod_out, mod_)
  @debug.assert_eq(sgo.touched, [false])
}

///|
test "legacy EH audit: reorder-locals scans and rewrites protected and catch bodies" {
  let instr = legacy_eh_test_try(
    [@lib.Instruction::local_get(@lib.LocalIdx::new(0U))],
    [@lib.Instruction::local_set(@lib.LocalIdx::new(1U))],
    [@lib.Instruction::local_tee(@lib.LocalIdx::new(0U))],
  )
  let state = RLScanState::new(2, 0)
  rl_scan_instruction(instr, state)
  @debug.assert_eq(state.counts, [2, 1])
  let instrs = [instr]
  rl_rewrite_instrs_in_place(instrs, [1, 0])
  match instrs[0] {
    @lib.Try(
      _,
      @lib.Expr([@lib.LocalGet(@lib.LocalIdx(1U))]),
      [
        @lib.LegacyCatch(_, @lib.Expr([@lib.LocalSet(@lib.LocalIdx(0U))])),
        @lib.LegacyCatchAll(@lib.Expr([@lib.LocalTee(@lib.LocalIdx(1U))])),
      ],
      Some(@lib.LabelIdx(2U))
    ) => ()
    other => fail("expected legacy local indices rewritten, got \{other}")
  }
}

///|
test "legacy EH audit: reorder-globals counts and rewrites protected and catch bodies" {
  let instr = legacy_eh_test_try(
    [@lib.Instruction::global_get(@lib.GlobalIdx::new(0U))],
    [@lib.Instruction::global_set(@lib.GlobalIdx::new(1U))],
    [@lib.Instruction::global_get(@lib.GlobalIdx::new(0U))],
  )
  let counts = [0, 0]
  rg_count_instruction(instr, counts)
  @debug.assert_eq(counts, [2, 1])
  let instrs = [instr]
  rg_rewrite_instrs_in_place(instrs, [1, 0])
  match instrs[0] {
    @lib.Try(
      _,
      @lib.Expr([@lib.GlobalGet(@lib.GlobalIdx(1U))]),
      [
        @lib.LegacyCatch(_, @lib.Expr([@lib.GlobalSet(@lib.GlobalIdx(0U))])),
        @lib.LegacyCatchAll(@lib.Expr([@lib.GlobalGet(@lib.GlobalIdx(1U))])),
      ],
      Some(@lib.LabelIdx(2U))
    ) => ()
    other => fail("expected legacy global indices rewritten, got \{other}")
  }
}

///|
test "legacy EH audit: duplicate-import-elimination rewrites function references in every region" {
  let instr = legacy_eh_test_try(
    [@lib.Instruction::call(@lib.FuncIdx::new(0U))],
    [@lib.Instruction::return_call(@lib.FuncIdx::new(1U))],
    [@lib.Instruction::ref_func(@lib.FuncIdx::new(0U))],
  )
  match die_rewrite_instruction(instr, [1, 0]) {
    @lib.Try(
      _,
      @lib.Expr([@lib.Call(@lib.FuncIdx(1U))]),
      [
        @lib.LegacyCatch(_, @lib.Expr([@lib.ReturnCall(@lib.FuncIdx(0U))])),
        @lib.LegacyCatchAll(@lib.Expr([@lib.RefFunc(@lib.FuncIdx(1U))])),
      ],
      Some(@lib.LabelIdx(2U))
    ) => ()
    other => fail("expected legacy function indices rewritten, got \{other}")
  }
}

///|
test "legacy EH audit: remove-unused-module-elements rewrites protected and catch references" {
  let instr = legacy_eh_test_try(
    [
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
      @lib.Instruction::elem_drop(@lib.ElemIdx::new(0U)),
    ],
    [
      @lib.Instruction::table_get(@lib.TableIdx::new(0U)),
      @lib.Instruction::drop(),
    ],
    [
      @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::data_drop(@lib.DataIdx::new(0U)),
    ],
  )
  match
    rume_rewrite_instruction(
      instr,
      [1, 0],
      [1, 0],
      [1, 0],
      [1, 0],
      [1, 0],
      [1, 0],
      [1, 0],
    ) {
    @lib.Try(
      _,
      @lib.Expr(
        [
          @lib.Call(@lib.FuncIdx(1U)),
          @lib.GlobalGet(@lib.GlobalIdx(1U)),
          @lib.ElemDrop(@lib.ElemIdx(1U)),
        ]
      ),
      [
        @lib.LegacyCatch(
          @lib.TagIdx(1U),
          @lib.Expr([@lib.TableGet(@lib.TableIdx(1U)), @lib.Drop])
        ),
        @lib.LegacyCatchAll(
          @lib.Expr(
            [
              @lib.MemorySize(@lib.MemIdx(1U)),
              @lib.Drop,
              @lib.DataDrop(@lib.DataIdx(1U)),
            ]
          )
        ),
      ],
      Some(@lib.LabelIdx(2U))
    ) => ()
    other => fail("expected all legacy module indices rewritten, got \{other}")
  }
}

///|
test "legacy EH audit: directize sees table mutation growth and indirect calls in every region" {
  let instr = legacy_eh_test_try(
    [@lib.Instruction::table_set(@lib.TableIdx::new(0U))],
    [@lib.Instruction::table_grow(@lib.TableIdx::new(1U))],
    [
      @lib.Instruction::call_indirect(
        @lib.TypeIdx::new(0U),
        @lib.TableIdx::new(0U),
      ),
    ],
  )
  let mutated = [false, false]
  let grown = [false, false]
  directize_mark_runtime_table_instr(mutated, grown, instr)
  @debug.assert_eq(mutated, [true, false])
  @debug.assert_eq(grown, [false, true])
  assert_true(directize_instrs_have_indirect_call([instr]))
}

///|
test "legacy EH audit: once-reduction scans reads writes and calls in every region" {
  let instr = legacy_eh_test_try(
    [@lib.Instruction::global_get(@lib.GlobalIdx::new(0U))],
    [
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
    ],
    [@lib.Instruction::call(@lib.FuncIdx::new(0U))],
  )
  let reads = [0]
  let slots = [0]
  assert_true(or_scan_instrs([instr], reads, slots))
  @debug.assert_eq(reads, [1])
  @debug.assert_eq(slots, [-1])
}

///|
test "legacy EH audit: raw merge-locals fails closed on protected and catch control" {
  let instr = legacy_eh_test_try(
    [@lib.Instruction::local_get(@lib.LocalIdx::new(0U))],
    [@lib.Instruction::local_set(@lib.LocalIdx::new(1U))],
    [@lib.Instruction::local_get(@lib.LocalIdx::new(1U))],
  )
  assert_false(merge_locals_raw_is_straight_line([instr]))
}
