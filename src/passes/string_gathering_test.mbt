///|
fn sg_test_run(text : String) -> @lib.Module {
  match pass_test_run_pipeline(text, ["string-gathering"]) {
    Ok(mod_) => mod_
    Err(err) => abort("expected string-gathering success, got \{err}")
  }
}

///|
fn sg_test_first_defined_func(mod_ : @lib.Module) -> @lib.Func {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs[0]
    None => abort("expected code section")
  }
}

///|
fn sg_test_global_count(mod_ : @lib.Module) -> Int {
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) => globals.length()
    None => 0
  }
}

///|
fn sg_test_global_init_instr(mod_ : @lib.Module, idx : Int) -> @lib.Instruction {
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) => {
      let @lib.Global(_, @lib.Expr(instrs)) = globals[idx]
      instrs[0]
    }
    None => abort("expected global section")
  }
}

///|
test "string-gathering registers as an active module pass" {
  match pass_registry_lookup("string-gathering") {
    Some(entry) => {
      @debug.assert_eq(entry.category, HotPassRegistryCategory::module_pass())
      @debug.assert_eq(entry.descriptor, None)
    }
    None => fail("expected string-gathering registry entry")
  }
}

///|
test "string-gathering is a no-op when no string constants exist" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) i32.const 7))",
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["string-gathering"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected no-op string-gathering success, got \{err}")
  }
  @debug.assert_eq(optimized, input)
}

///|
test "string-gathering hoists a function string.const to a non-null string global" {
  let optimized = sg_test_run(
    (
      #| (module
      #|   (func (result stringref)
      #|     (string.const "hello")))
      #|
    ),
  )
  @debug.assert_eq(sg_test_global_count(optimized), 1)
  @debug.assert_eq(
    sg_test_global_init_instr(optimized, 0),
    @lib.Instruction::string_const(b"hello"),
  )
  let @lib.Func(_, @lib.Expr(instrs)) = sg_test_first_defined_func(optimized)
  @debug.assert_eq(instrs, [
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
  ])
}

///|
test "string-gathering deduplicates by bytes and preserves first function-use order" {
  let optimized = sg_test_run(
    (
      #| (module
      #|   (func (result stringref stringref stringref)
      #|     (string.const "a")
      #|     (string.const "b")
      #|     (string.const "a")))
      #|
    ),
  )
  @debug.assert_eq(sg_test_global_count(optimized), 2)
  @debug.assert_eq(
    sg_test_global_init_instr(optimized, 0),
    @lib.Instruction::string_const(b"a"),
  )
  @debug.assert_eq(
    sg_test_global_init_instr(optimized, 1),
    @lib.Instruction::string_const(b"b"),
  )
  let @lib.Func(_, @lib.Expr(instrs)) = sg_test_first_defined_func(optimized)
  @debug.assert_eq(instrs, [
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::global_get(@lib.GlobalIdx::new(1U)),
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
  ])
}

///|
test "string-gathering inserts after imports and remaps existing defined globals" {
  let optimized = sg_test_run(
    (
      #| (module
      #|   (import "env" "g" (global i32))
      #|   (global (mut i32) (i32.const 0))
      #|   (func (result i32 i32 stringref)
      #|     global.get 0
      #|     global.get 1
      #|     (string.const "x")))
      #|
    ),
  )
  @debug.assert_eq(sg_test_global_count(optimized), 2)
  @debug.assert_eq(
    sg_test_global_init_instr(optimized, 0),
    @lib.Instruction::string_const(b"x"),
  )
  @debug.assert_eq(
    sg_test_global_init_instr(optimized, 1),
    @lib.Instruction::i32_const(@lib.I32(0)),
  )
  let @lib.Func(_, @lib.Expr(instrs)) = sg_test_first_defined_func(optimized)
  @debug.assert_eq(instrs, [
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::global_get(@lib.GlobalIdx::new(2U)),
    @lib.Instruction::global_get(@lib.GlobalIdx::new(1U)),
  ])
}

///|
test "string-gathering remaps exports of existing defined globals" {
  let optimized = sg_test_run(
    (
      #| (module
      #|   (import "env" "g" (global i32))
      #|   (global (mut i32) (i32.const 1))
      #|   (export "kept" (global 1))
      #|   (func (result stringref)
      #|     (string.const "x")))
      #|
    ),
  )
  match optimized.export_sec {
    Some(@lib.ExportSec(exports)) =>
      match exports[0] {
        @lib.Export(_, @lib.GlobalExternIdx(idx)) =>
          @debug.assert_eq(idx, @lib.GlobalIdx::new(2U))
        _ => fail("expected global export")
      }
    None => fail("expected export section")
  }
}

///|
test "string-gathering scans function constants before global initializers" {
  let optimized = sg_test_run(
    (
      #| (module
      #|   (global stringref (string.const "global"))
      #|   (func (result stringref stringref)
      #|     (string.const "func")
      #|     global.get 0))
      #|
    ),
  )
  @debug.assert_eq(sg_test_global_count(optimized), 3)
  @debug.assert_eq(
    sg_test_global_init_instr(optimized, 0),
    @lib.Instruction::string_const(b"func"),
  )
  @debug.assert_eq(
    sg_test_global_init_instr(optimized, 1),
    @lib.Instruction::string_const(b"global"),
  )
  @debug.assert_eq(
    sg_test_global_init_instr(optimized, 2),
    @lib.Instruction::global_get(@lib.GlobalIdx::new(1U)),
  )
  let @lib.Func(_, @lib.Expr(instrs)) = sg_test_first_defined_func(optimized)
  @debug.assert_eq(instrs, [
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::global_get(@lib.GlobalIdx::new(2U)),
  ])
}

///|
test "string-gathering rewrites nested structured function bodies" {
  let optimized = sg_test_run(
    (
      #| (module
      #|   (func (param i32) (result stringref)
      #|     local.get 0
      #|     if (result stringref)
      #|       (string.const "then")
      #|     else
      #|       block (result stringref)
      #|         (string.const "else")
      #|       end
      #|     end))
      #|
    ),
  )
  @debug.assert_eq(sg_test_global_count(optimized), 2)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("string.const"), msg=pretty)
  assert_true(pretty.contains("global.get (Global 0)"), msg=pretty)
  assert_true(pretty.contains("global.get (Global 1)"), msg=pretty)
}

///|
test "string-gathering remaps exported defined globals and structured global names" {
  let input = pass_test_module_from_wat(
      (
        #| (module
        #|   (global (mut i32) (i32.const 0))
        #|   (func (result stringref)
        #|     (string.const "x")))
        #|
      ),
    )
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("g"),
          @lib.ExternIdx::global(@lib.GlobalIdx::new(0U)),
        ),
      ]),
    )
    .with_name_sec(
      @lib.NameSec::new(
        global_names=Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("g0")),
          ]),
        ),
      ),
    )
  let optimized = string_gathering_run_module_pass(input)

  match optimized.export_sec {
    Some(
      @lib.ExportSec(
        [@lib.Export(_, @lib.GlobalExternIdx(@lib.GlobalIdx(idx)))]
      )
    ) => @debug.assert_eq(idx, 1U)
    other =>
      fail("expected rewritten global export, got \{@debug.to_string(other)}")
  }
  match optimized.name_sec {
    Some(sec) =>
      match sec.global_names {
        Some(@lib.NameMap([@lib.NameAssoc(idx, _)])) =>
          @debug.assert_eq(idx, 1U)
        other =>
          fail("expected rewritten global name, got \{@debug.to_string(other)}")
      }
    None => fail("expected name section")
  }
}

///|
test "string-gathering clears stale raw name payload when global indices change" {
  let input = pass_test_module_from_wat(
    "(module (global (mut i32) (i32.const 0)) (func (result stringref) (string.const \"x\")))",
  ).with_raw_name_sec_payload(b"raw")
  let optimized = string_gathering_run_module_pass(input)
  @debug.assert_eq(optimized.raw_name_sec_payload, None)
}
