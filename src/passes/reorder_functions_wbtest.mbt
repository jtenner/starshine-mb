///|
fn rf_test_module() -> @lib.Module {
  let parts = [
    "(module (type $void (func)) (type $value (func (result i32)))",
    "(import \"env\" \"a\" (func $a (type $void)))",
    "(import \"env\" \"b\" (func $b (type $void)))",
    "(table 1 funcref) (global funcref (ref.func $hot))",
  ]
  for i = 0; i < 126; i = i + 1 {
    parts.push("(func $unused\{i} (type $void))")
  }
  parts.push("(func $run (type $void)")
  for _i = 0; _i < 32; _i = _i + 1 {
    parts.push("call $hot drop")
  }
  parts.append([
    ")", "(func $hot (type $value) i32.const 42)",
    "(export \"run\" (func $run)) (export \"hot\" (func $hot))",
    "(elem (i32.const 0) func $hot) (start $a))",
  ])
  pass_test_module_from_wat(parts.join("\n"))
}

///|
test "reorder-functions reduces exact encoded cost and preserves imports and references" {
  let before = rf_test_module()
  let after = match
    run_hot_pipeline(before, HotPipelineOptions::new(), ["reorder-functions"]) {
    Ok(mod_) => mod_
    Err(error) => fail("reorder-functions must run: \{error}")
  }
  @debug.assert_eq(after.import_sec, before.import_sec)
  @debug.assert_eq(after.start_sec, before.start_sec)
  @debug.assert_eq(@validate.validate_module(after), Ok(()))
  match @binary.encoded_module_sizes(before, after) {
    Ok((old_size, new_size)) => @debug.assert_eq(new_size < old_size, true)
    Err(error) => fail("exact size failed: \{error}")
  }
  let hot = match after.export_sec {
    Some(@lib.ExportSec(exports)) => match exports[1] {
      @lib.Export(_, @lib.FuncExternIdx(@lib.FuncIdx(idx))) => idx
      _ => fail("missing hot function export")
    }
    None => fail("missing exports")
  }
  @debug.assert_eq(hot < 128U, true)
  match after.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      @debug.assert_eq(funcs.length(), 128)
      @debug.assert_eq(
        funcs[hot.to_int() - 2],
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(42)),
        ])),
      )
      match after.func_sec {
        Some(@lib.FuncSec(types)) =>
          @debug.assert_eq(types[hot.to_int() - 2], @lib.TypeIdx::new(1U))
        None => fail("missing function signatures")
      }
      let driver = match after.export_sec {
        Some(@lib.ExportSec(exports)) => match exports[0] {
          @lib.Export(_, @lib.FuncExternIdx(@lib.FuncIdx(idx))) => idx
          _ => fail("missing driver")
        }
        None => fail("missing driver export")
      }
      let @lib.Func(_, @lib.Expr(body)) = funcs[driver.to_int() - 2]
      @debug.assert_eq(body[0], @lib.Instruction::call(@lib.FuncIdx::new(hot)))
    }
    None => fail("missing code")
  }
  match after.elem_sec {
    Some(@lib.ElemSec([@lib.Elem(_, @lib.FuncsElemKind([idx]))])) =>
      @debug.assert_eq(idx, @lib.FuncIdx::new(hot))
    _ => fail("missing function element")
  }
  match after.global_sec {
    Some(@lib.GlobalSec([@lib.Global(_, @lib.Expr([@lib.RefFunc(idx)]))])) =>
      @debug.assert_eq(idx, @lib.FuncIdx::new(hot))
    _ => fail("missing global function reference")
  }
}

///|
test "reorder-functions preserves order when all function indices have the same width" {
  let before = pass_test_module_from_wat(
    "(module (func $a (result i32) i32.const 1) (func $b (export \"run\") (result i32) call $a))",
  )
  let after = match
    run_hot_pipeline(before, HotPipelineOptions::new(), ["reorder-functions"]) {
    Ok(mod_) => mod_
    Err(error) => fail("reorder-functions must run: \{error}")
  }
  @debug.assert_eq(after, before)
}
