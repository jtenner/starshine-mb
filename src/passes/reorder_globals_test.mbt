///|
fn rg_test_func_type_sec() -> @lib.TypeSec {
  @lib.TypeSec::new([
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
  ])
}

///|
fn rg_test_i32_global(value : Int) -> @lib.Global {
  @lib.Global::new(
    @lib.GlobalType::new(@lib.ValType::i32(), false),
    @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(value))]),
  )
}

///|
fn rg_test_dependent_i32_global(dep : UInt) -> @lib.Global {
  @lib.Global::new(
    @lib.GlobalType::new(@lib.ValType::i32(), false),
    @lib.Expr::new([@lib.Instruction::global_get(@lib.GlobalIdx::new(dep))]),
  )
}

///|
fn rg_test_globals(count : Int) -> Array[@lib.Global] {
  let globals : Array[@lib.Global] = Array::new(capacity=count)
  for idx = 0; idx < count; idx = idx + 1 {
    globals.push(rg_test_i32_global(idx))
  }
  globals
}

///|
fn rg_test_body_using_global(raw : UInt, repetitions : Int) -> @lib.Expr {
  let body : Array[@lib.Instruction] = []
  for rep = 0; rep < repetitions; rep = rep + 1 {
    ignore(rep)
    body.push(@lib.Instruction::global_get(@lib.GlobalIdx::new(raw)))
    body.push(@lib.Instruction::drop())
  }
  @lib.Expr::new(body)
}

///|
fn rg_test_module(
  globals : Array[@lib.Global],
  body : @lib.Expr,
) -> @lib.Module {
  @lib.Module::new()
  .with_type_sec(rg_test_func_type_sec())
  .with_global_sec(@lib.GlobalSec::new(globals))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(@lib.Locals::empty(), body)]),
  )
}

///|
fn rg_test_global_const_value(mod_ : @lib.Module, idx : Int) -> Int raise {
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) =>
      match globals[idx] {
        @lib.Global(_, @lib.Expr([@lib.I32Const(@lib.I32(value))])) => value
        other => fail("expected const i32 global, got \{other}")
      }
    None => fail("expected global section")
  }
}

///|
fn rg_test_first_body_global_get(mod_ : @lib.Module) -> UInt raise {
  match mod_.code_sec {
    Some(
      @lib.CodeSec(
        [@lib.Func(_, @lib.Expr([@lib.GlobalGet(@lib.GlobalIdx(raw)), ..]))]
      )
    ) => raw
    other => fail("expected leading global.get, got \{@debug.to_string(other)}")
  }
}

///|
test "reorder-globals is an active module pass in the registry" {
  @debug.assert_eq(
    pass_registry_category("reorder-globals"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("reorder-globals-always"),
    Some(HotPassRegistryCategory::boundary_only()),
  )
}

///|
test "reorder-globals public pass no-ops below 128 globals" {
  let mod_ = rg_test_module(
    rg_test_globals(2),
    rg_test_body_using_global(1U, 8),
  )
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), ["reorder-globals"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected reorder-globals success, got \{err}")
  }

  @debug.assert_eq(try! rg_test_global_const_value(optimized, 0), 0)
  @debug.assert_eq(try! rg_test_global_const_value(optimized, 1), 1)
  @debug.assert_eq(try! rg_test_first_body_global_get(optimized), 1U)
}

///|
test "reorder-globals moves a hot 129th global to a one-byte index and remaps users" {
  let mod_ = rg_test_module(
    rg_test_globals(129),
    rg_test_body_using_global(128U, 4),
  )
  let optimized = reorder_globals_run_module_pass(mod_)

  @debug.assert_eq(try! rg_test_global_const_value(optimized, 0), 128)
  @debug.assert_eq(try! rg_test_first_body_global_get(optimized), 0U)
}

///|
test "reorder-globals preserves initializer dependencies while moving hot dependents earlier" {
  let globals = rg_test_globals(129)
  globals[128] = rg_test_dependent_i32_global(0U)
  let mod_ = rg_test_module(globals, rg_test_body_using_global(128U, 8))
  let optimized = reorder_globals_run_module_pass(mod_)

  @debug.assert_eq(try! rg_test_global_const_value(optimized, 0), 0)
  match optimized.global_sec {
    Some(@lib.GlobalSec(globals)) =>
      match globals[1] {
        @lib.Global(_, @lib.Expr([@lib.GlobalGet(@lib.GlobalIdx(dep))])) =>
          @debug.assert_eq(dep, 0U)
        other => fail("expected dependent global at slot 1, got \{other}")
      }
    None => fail("expected global section")
  }
  @debug.assert_eq(try! rg_test_first_body_global_get(optimized), 1U)
}

///|
test "reorder-globals remaps exported global indices and global names" {
  let mod_ = rg_test_module(
      rg_test_globals(129),
      rg_test_body_using_global(128U, 4),
    )
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("hot"),
          @lib.ExternIdx::global(@lib.GlobalIdx::new(128U)),
        ),
      ]),
    )
    .with_name_sec(
      @lib.NameSec::new(
        global_names=Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(128U, @lib.Name::from_string("hot_global")),
          ]),
        ),
      ),
    )
  let optimized = reorder_globals_run_module_pass(mod_)

  match optimized.export_sec {
    Some(
      @lib.ExportSec(
        [@lib.Export(_, @lib.GlobalExternIdx(@lib.GlobalIdx(idx)))]
      )
    ) => @debug.assert_eq(idx, 0U)
    other =>
      fail("expected rewritten global export, got \{@debug.to_string(other)}")
  }
  match optimized.name_sec {
    Some(sec) =>
      match sec.global_names {
        Some(@lib.NameMap([@lib.NameAssoc(idx, _)])) =>
          @debug.assert_eq(idx, 0U)
        other =>
          fail("expected rewritten global name, got \{@debug.to_string(other)}")
      }
    None => fail("expected name section")
  }
}

///|
fn rg_test_late_tail_fixture() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (type (func))\n")
  out.write_string("  (type (func (param i32) (result i32)))\n")
  out.write_string("  (table 1 funcref)\n")
  out.write_string(
    "  (func $target (type 1) (param i32) (result i32) local.get 0)\n",
  )
  out.write_string("  (elem (i32.const 0) $target)\n")
  for idx = 0; idx < 129; idx = idx + 1 {
    out.write_string("  (global (mut i32) (i32.const \{idx}))\n")
  }
  out.write_string("  (export \"hot\" (global 128))\n")
  out.write_string("  (func $run (type 0)\n")
  for i = 0; i < 16; i = i + 1 {
    ignore(i)
    out.write_string("    global.get 128\n")
    out.write_string("    drop\n")
  }
  out.write_string("    string.const \"x\"\n")
  out.write_string("    drop\n")
  out.write_string("    i32.const 7\n")
  out.write_string("    i32.const 0\n")
  out.write_string("    call_indirect (type 1)\n")
  out.write_string("    drop)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
test "string-gathering reorder-globals directize preserve late-tail order" {
  let optimized = match
    pass_test_run_pipeline(rg_test_late_tail_fixture(), [
      "string-gathering", "reorder-globals", "directize",
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected string-gathering/reorder-globals/directize success, got \{err}",
      )
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected late-tail replay module to validate, got \{err}")
  }

  match optimized.export_sec {
    Some(
      @lib.ExportSec(
        [@lib.Export(_, @lib.GlobalExternIdx(@lib.GlobalIdx(idx)))]
      )
    ) => @debug.assert_eq(idx, 0U)
    other =>
      fail(
        "expected hot export after late-tail replay, got \{@debug.to_string(other)}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(pretty.contains("string.const"), msg=pretty)
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_false(pretty.contains("call_indirect"), msg=pretty)
}
