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
fn die_test_import_count(mod_ : @lib.Module) -> Int {
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) => imports.length()
    None => 0
  }
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
fn die_test_host_lookup_source() -> String {
  let source =
    #|(module
    #|  (import "env" "f" (func $first (result i32)))
    #|  (import "env" "f" (func $second (result i32)))
    #|  (func (export "run") (result i32)
    #|    (i32.add (call $first) (call $second))))
  source
}

///|
fn die_test_two_call_targets(mod_ : @lib.Module) -> (UInt, UInt) raise {
  match mod_.code_sec {
    Some(
      @lib.CodeSec(
        [
          @lib.Func(
            _,
            @lib.Expr(
              [
                @lib.Call(@lib.FuncIdx(first)),
                @lib.Call(@lib.FuncIdx(second)),
                @lib.I32Add,
              ]
            )
          ),
        ]
      )
    ) => (first, second)
    _ => fail("expected two imported function calls")
  }
}

///|
test "duplicate-import-elimination directly preserves repeated host lookups" {
  let input = pass_test_module_from_wat(die_test_host_lookup_source())
  let optimized = die_run_module_pass(input)
  @debug.assert_eq(optimized, input)
  @debug.assert_eq(die_test_imported_func_count(optimized), 2)
  @debug.assert_eq(try! die_test_two_call_targets(optimized), (0U, 1U))
}

///|
test "duplicate-import-elimination dispatcher preserves repeated host lookups" {
  let input = pass_test_module_from_wat(die_test_host_lookup_source())
  let optimized = try! die_test_run(die_test_host_lookup_source())
  @debug.assert_eq(optimized, input)
  @debug.assert_eq(die_test_imported_func_count(optimized), 2)
  @debug.assert_eq(try! die_test_two_call_targets(optimized), (0U, 1U))
}

///|
test "duplicate-import-elimination closed world does not assume stable bindings" {
  let input = pass_test_module_from_wat(die_test_host_lookup_source())
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(closed_world=true), [
      "duplicate-import-elimination",
    ]) {
    Ok(next) => next
    Err(err) => fail("expected closed-world default DIE success, got \{err}")
  }
  @debug.assert_eq(optimized, input)
  @debug.assert_eq(try! die_test_two_call_targets(optimized), (0U, 1U))
}

///|
test "duplicate-import-elimination stable bindings directly retains merging" {
  let optimized = die_run_module_pass_assume_stable_bindings(
    pass_test_module_from_wat(die_test_host_lookup_source()),
  )
  @debug.assert_eq(die_test_imported_func_count(optimized), 1)
  @debug.assert_eq(try! die_test_two_call_targets(optimized), (0U, 0U))
}

///|
test "duplicate-import-elimination stable bindings dispatcher retains merging" {
  let optimized = match
    pass_test_run_pipeline(die_test_host_lookup_source(), [
      "duplicate-import-elimination-assume-stable-bindings",
    ]) {
    Ok(next) => next
    Err(err) => fail("expected stable-binding DIE success, got \{err}")
  }
  @debug.assert_eq(die_test_imported_func_count(optimized), 1)
  @debug.assert_eq(try! die_test_two_call_targets(optimized), (0U, 0U))
}

///|
test "duplicate-import-elimination preserves duplicate import slots and users" {
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
  let input = pass_test_module_from_wat(source)
  let optimized = try! die_test_run(source)

  @debug.assert_eq(optimized, input)
  @debug.assert_eq(die_test_imported_func_count(optimized), 2)
  @debug.assert_eq(try! die_test_first_call_target(optimized, 0), 1U)
  @debug.assert_eq(try! die_test_ref_func_target(optimized, 0), 1U)
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
  let input = pass_test_module_from_wat(source)
  let optimized = try! die_test_run(source)

  @debug.assert_eq(optimized, input)
  @debug.assert_eq(die_test_imported_func_count(optimized), 3)
  match optimized.import_sec {
    Some(@lib.ImportSec(imports)) => @debug.assert_eq(imports.length(), 5)
    None => fail("expected imports")
  }
  @debug.assert_eq(try! die_test_first_call_target(optimized, 0), 1U)
}

///|
test "duplicate-import-elimination preserves repeated lookups across type mismatch" {
  let source =
    #|(module
    #|  (type $i (func (param i32)))
    #|  (type $v (func))
    #|  (import "env" "waka" (func $first (type $i)))
    #|  (import "env" "waka" (func $second (type $v)))
    #|  (import "env" "waka" (func $third (type $v)))
    #|)
    #|,
  let input = pass_test_module_from_wat(source)
  let optimized = try! die_test_run(source)

  @debug.assert_eq(optimized, input)
  @debug.assert_eq(die_test_imported_func_count(optimized), 3)
}

///|
test "duplicate-import-elimination preserves function references in legacy try regions" {
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
  let input = pass_test_module_from_wat(source)
  let optimized = try! die_test_run(source)
  @debug.assert_eq(optimized, input)
  @debug.assert_eq(die_test_imported_func_count(optimized), 2)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected valid duplicate-import legacy output, got \{err}")
  }
}

///|
test "duplicate-import-elimination preserves raw names without function remap" {
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

  @debug.assert_eq(optimized, input)
  @debug.assert_eq(die_test_imported_func_count(optimized), 2)
  @debug.assert_eq(
    optimized.raw_name_sec_payload,
    Some(b"stale-function-index-name-payload"),
  )
  assert_true(optimized.name_sec is Some(_))
}

///|
test "duplicate-import-elimination preserves function annotation ownership" {
  let source =
    #|(module
    #|  (type $v (func))
    #|  (import "env" "f" (func $first (type $v)))
    #|  (import "env" "f" (func $duplicate (type $v)))
    #|  (func $caller))
  let input = pass_test_module_from_wat(source).with_func_annotation_sec(
    @lib.FuncAnnotationSec::new([
      @lib.FuncAnnotationAssoc::new(0U, [
        @lib.FuncAnnotation::new("binaryen.idempotent"),
      ]),
      @lib.FuncAnnotationAssoc::new(1U, [
        @lib.FuncAnnotation::new("binaryen.removable.if.unused"),
      ]),
      @lib.FuncAnnotationAssoc::new(2U, [
        @lib.FuncAnnotation::new("binaryen.js.called"),
      ]),
    ]),
  )
  let optimized = die_run_module_pass(input)
  @debug.assert_eq(optimized, input)
}

///|
test "duplicate-import-elimination preserves by default and merges trusted v131 families" {
  let profile_names = [
    "duplicate-import-elimination-functions", "duplicate-import-elimination-identity",
    "duplicate-import-elimination-module-code", "duplicate-import-elimination-legacy-eh",
    "duplicate-import-elimination-nonfunction",
  ]
  for index = 0; index < profile_names.length(); index = index + 1 {
    let profile_name = profile_names[index]
    let profile = match @validate.gen_valid_profile_by_name(profile_name) {
      Ok(value) => value
      Err(err) => fail(err)
    }
    let variants = if profile_name == "duplicate-import-elimination-legacy-eh" ||
      profile_name == "duplicate-import-elimination-identity" {
      5
    } else {
      1
    }
    for variant = 0; variant < variants; variant = variant + 1 {
      let generated = match
        @validate.gen_valid_module_result_from_seed(
          variant.to_uint64(),
          @validate.GenValidConfig::for_profile(profile),
        ) {
        Ok(value) => value
        Err(failure) => fail(failure.validation_error_message)
      }
      let encoded = match @binary.encode_module(generated.wasm_module) {
        Ok(bytes) => bytes
        Err(err) => fail("profile \{profile_name} failed to encode: \{err}")
      }
      let decoded = match @binary.decode_module(encoded) {
        Ok(mod_) => mod_
        Err(err) => fail("profile \{profile_name} failed to decode: \{err}")
      }
      let before_funcs = die_test_imported_func_count(decoded)
      let before_imports = die_test_import_count(decoded)
      let optimized = die_run_module_pass(decoded)
      match @validate.validate_module(optimized) {
        Ok(_) => ()
        Err(err) =>
          fail(
            "profile \{profile_name} variant \{variant} produced invalid wasm: \{@validate.validation_error_message(err)}",
          )
      }
      @debug.assert_eq(die_test_imported_func_count(optimized), before_funcs)
      @debug.assert_eq(die_test_import_count(optimized), before_imports)
      @debug.assert_eq(optimized, decoded)
      @debug.assert_eq(die_run_module_pass(optimized), optimized)

      let trusted = die_run_module_pass_assume_stable_bindings(decoded)
      match @validate.validate_module(trusted) {
        Ok(_) => ()
        Err(err) =>
          fail(
            "trusted profile \{profile_name} variant \{variant} produced invalid wasm: \{@validate.validation_error_message(err)}",
          )
      }
      if profile_name == "duplicate-import-elimination-nonfunction" {
        @debug.assert_eq(trusted, decoded)
      } else {
        assert_true(
          die_test_imported_func_count(trusted) < before_funcs,
          msg="trusted profile \{profile_name} variant \{variant} did not remove a duplicate function import",
        )
        assert_true(trusted != decoded)
      }
      @debug.assert_eq(
        die_run_module_pass_assume_stable_bindings(trusted),
        trusted,
      )
    }
  }
}

///|
test "duplicate-import-elimination preserves single function import and duplicate globals" {
  let source =
    #|(module
    #| (import "env" "f" (func $f))
    #| (import "env" "g" (global i32))
    #| (import "env" "g" (global i32))
    #| (elem declare func $f)
    #| (export "f" (func $f))
    #| (func call $f ref.func $f drop global.get 1 drop))
  let original = pass_test_module_from_wat(source)
  let optimized = die_test_run(source)
  assert_true(optimized == original)
  assert_eq(die_test_import_count(optimized), 3)
  assert_eq(die_test_first_call_target(optimized, 0), 0U)
  assert_eq(die_test_ref_func_target(optimized, 0), 0U)
}
