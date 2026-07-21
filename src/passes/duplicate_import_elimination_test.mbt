///|
fn die_test_imported_func_count(mod_ : @lib.Module) -> Int {
  let mut count = 0
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
fn die_test_first_call_target(
  mod_ : @lib.Module,
  defined_idx : Int,
) -> UInt raise {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[defined_idx] {
        @lib.Func(_, @lib.Expr([@lib.Call(@lib.FuncIdx(target)), ..])) => target
        _ => fail("expected leading call")
      }
    None => fail("expected code section")
  }
}

///|
fn die_test_ref_func_target(
  mod_ : @lib.Module,
  defined_idx : Int,
) -> UInt raise {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[defined_idx] {
        @lib.Func(_, @lib.Expr([@lib.RefFunc(@lib.FuncIdx(target)), ..])) =>
          target
        @lib.Func(_, @lib.Expr([_, @lib.RefFunc(@lib.FuncIdx(target)), ..])) =>
          target
        _ => fail("expected ref.func")
      }
    None => fail("expected code section")
  }
}

///|
fn die_test_run(text : String) -> @lib.Module raise {
  match pass_test_run_pipeline(text, ["duplicate-import-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected duplicate-import-elimination success, got \{err}")
  }
}

///|
test "duplicate-import-elimination collapses duplicate imported functions and rewrites users" {
  let source =
    #|(module
    #|  (type $v (func))
    #|  (import "env" "waka" (func $foo (type $v)))
    #|  (import "env" "waka" (func $bar (type $v)))
    #|  (table 2 2 funcref)
    #|  (elem (i32.const 0) $foo $bar)
    #|  (export "entry" (func $bar))
    #|  (start $bar)
    #|  (func $caller
    #|    (call $bar)
    #|    (drop (ref.func $bar))
    #|  )
    #|)
    #|,
  let optimized = try! die_test_run(source)

  @debug.assert_eq(die_test_imported_func_count(optimized), 1)
  @debug.assert_eq(try! die_test_first_call_target(optimized, 0), 0U)
  @debug.assert_eq(try! die_test_ref_func_target(optimized, 0), 0U)
  match optimized.export_sec {
    Some(
      @lib.ExportSec([@lib.Export(_, @lib.FuncExternIdx(@lib.FuncIdx(target)))])
    ) => @debug.assert_eq(target, 0U)
    _ => fail("expected rewritten function export")
  }
  match optimized.start_sec {
    Some(@lib.StartSec(@lib.FuncIdx(target))) => @debug.assert_eq(target, 0U)
    _ => fail("expected rewritten start")
  }
  match optimized.elem_sec {
    Some(
      @lib.ElemSec(
        [@lib.Elem(_, @lib.FuncsElemKind([@lib.FuncIdx(a), @lib.FuncIdx(b)]))]
      )
    ) => {
      @debug.assert_eq(a, 0U)
      @debug.assert_eq(b, 0U)
    }
    _ => fail("expected rewritten function element segment")
  }
}

///|
test "duplicate-import-elimination preserves non-function and different-signature imports" {
  let source =
    #|(module
    #|  (type $v (func))
    #|  (type $i (func (param i32)))
    #|  (import "env" "waka" (func $foo (type $v)))
    #|  (import "env" "waka" (func $bar (type $v)))
    #|  (import "env" "waka" (func $wrong (type $i)))
    #|  (import "env" "g" (global $g i32))
    #|  (import "env" "g" (global $h i32))
    #|  (func $caller (param i32)
    #|    (call $bar)
    #|    (local.get 0)
    #|    (call $wrong)
    #|    (drop (global.get $h))
    #|  )
    #|)
    #|,
  let optimized = try! die_test_run(source)

  @debug.assert_eq(die_test_imported_func_count(optimized), 2)
  match optimized.import_sec {
    Some(@lib.ImportSec(imports)) => @debug.assert_eq(imports.length(), 4)
    None => fail("expected imports")
  }
  @debug.assert_eq(try! die_test_first_call_target(optimized, 0), 0U)
}

///|
test "duplicate-import-elimination resets the bucket representative after a type mismatch" {
  let source =
    #|(module
    #|  (type $i (func (param i32)))
    #|  (type $v (func))
    #|  (import "env" "waka" (func $first (type $i)))
    #|  (import "env" "waka" (func $second (type $v)))
    #|  (import "env" "waka" (func $third (type $v)))
    #|)
    #|,
  let optimized = try! die_test_run(source)

  @debug.assert_eq(die_test_imported_func_count(optimized), 2)
}

///|
test "duplicate-import-elimination remaps function references in legacy try regions" {
  let source =
    #|(module
    #|  (type $v (func))
    #|  (import "env" "f" (func $first (type $v)))
    #|  (import "env" "f" (func $duplicate (type $v)))
    #|  (tag $e)
    #|  (func (export "root")
    #|    (try
    #|      (do
    #|        call $duplicate)
    #|      (catch $e
    #|        call $duplicate))))
  let optimized = try! die_test_run(source)
  @debug.assert_eq(die_test_imported_func_count(optimized), 1)
  match optimized.code_sec {
    Some(
      @lib.CodeSec(
        [
          @lib.Func(
            _,
            @lib.Expr(
              [
                @lib.Try(
                  _,
                  @lib.Expr([@lib.Call(@lib.FuncIdx(0U))]),
                  [
                    @lib.LegacyCatch(
                      _,
                      @lib.Expr([@lib.Call(@lib.FuncIdx(0U))])
                    ),
                  ],
                  None
                ),
              ]
            )
          ),
        ]
      )
    ) => ()
    other => fail("expected remapped legacy try references, got \{other}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected valid duplicate-import legacy output, got \{err}")
  }
}

///|
test "duplicate-import-elimination clears stale raw names after function remap" {
  let source =
    #|(module
    #|  (type $v (func))
    #|  (import "env" "f" (func $first (type $v)))
    #|  (import "env" "f" (func $duplicate (type $v)))
    #|  (func $caller
    #|    call $duplicate))
    #|
  let input = pass_test_module_from_wat(source).with_raw_name_sec_payload(
    b"stale-function-index-name-payload",
  )
  assert_true(input.name_sec is Some(_))
  assert_true(input.raw_name_sec_payload is Some(_))

  let optimized = die_run_module_pass(input)

  @debug.assert_eq(die_test_imported_func_count(optimized), 1)
  @debug.assert_eq(optimized.raw_name_sec_payload, None)
  assert_true(optimized.name_sec is Some(_))
}
