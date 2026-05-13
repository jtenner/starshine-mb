///|
fn dae_test_func_type(mod_ : @lib.Module, def_idx : Int) -> @lib.FuncType {
  let type_idx = match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) => type_idxs[def_idx]
    None => abort("missing func section")
  }
  match (mod_.type_sec, type_idx) {
    (Some(@lib.TypeSec(rec_types)), @lib.TypeIdx(raw)) =>
      match rec_types[raw.reinterpret_as_int()] {
        @lib.SingleRecType(subtype) =>
          match subtype.get_comptype() {
            @lib.FuncCompType(params, results) =>
              @lib.FuncType::new(params, results)
            _ => abort("expected func type")
          }
        @lib.GroupRecType(_) => abort("unexpected group type")
      }
    _ => abort("missing concrete type")
  }
}

///|
fn dae_test_func_params(
  mod_ : @lib.Module,
  def_idx : Int,
) -> Array[@lib.ValType] {
  let @lib.FuncType(params, _) = dae_test_func_type(mod_, def_idx)
  params
}

///|
fn dae_test_func_results(
  mod_ : @lib.Module,
  def_idx : Int,
) -> Array[@lib.ValType] {
  let @lib.FuncType(_, results) = dae_test_func_type(mod_, def_idx)
  results
}

///|
fn dae_test_run(
  text : String,
  pass_name? : String = "dae-optimizing",
) -> @lib.Module {
  match pass_test_run_pipeline(text, [pass_name]) {
    Ok(mod_) => mod_
    Err(err) => abort("expected DAE pipeline success, got \{err}")
  }
}

///|
fn dae_test_defined_func(mod_ : @lib.Module, def_idx : Int) -> @lib.Func {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs[def_idx]
    None => abort("missing code section")
  }
}

///|
test "dae-optimizing is an active module pass under canonical and descriptive names" {
  @debug.assert_eq(
    pass_registry_category("dae-optimizing"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("dead-argument-elimination-optimizing"),
    Some(HotPassRegistryCategory::module_pass()),
  )
}

///|
test "dae-optimizing removes a private unused scalar parameter at direct calls" {
  let source =
    #|(module
    #|  (func $f (param i32 i32) (result i32)
    #|    local.get 0)
    #|  (func (export "run") (result i32)
    #|    i32.const 10
    #|    i32.const 20
    #|    call $f))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 1)
  let caller = optimized.pretty_print_defined_func(1U)
  assert_true(caller.contains("(call (Func 0))"), msg=caller)
  assert_true(caller.contains("i32.const I32(10)"), msg=caller)
  assert_false(caller.contains("i32.const I32(20)"), msg=caller)
}

///|
test "dae-optimizing preserves side effects from removed actual operands" {
  let source =
    #|(module
    #|  (global $g (mut i32) (i32.const 0))
    #|  (func $side (result i32)
    #|    i32.const 1
    #|    global.set $g
    #|    i32.const 7)
    #|  (func $f (param i32)
    #|    nop)
    #|  (func (export "run")
    #|    call $side
    #|    call $f))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 0)
  let caller = optimized.pretty_print_defined_func(2U)
  assert_true(caller.contains("(call (Func 0))"), msg=caller)
  assert_true(caller.contains("(call (Func 1))"), msg=caller)
}

///|
test "dae-optimizing drops value-producing if operands removed from calls" {
  let source =
    #|(module
    #|  (global $g (mut i32) (i32.const 0))
    #|  (func $f (param f64 f32)
    #|    nop)
    #|  (func (export "run")
    #|    i32.const 0
    #|    if (result f64)
    #|      i32.const 1
    #|      global.set $g
    #|      f64.const 19
    #|    else
    #|      i32.const 2
    #|      global.set $g
    #|      f64.const 2
    #|    end
    #|    i32.const 0
    #|    if (result f32)
    #|      i32.const 3
    #|      global.set $g
    #|      f32.const 41
    #|    else
    #|      i32.const 4
    #|      global.set $g
    #|      f32.const 51
    #|    end
    #|    call $f))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  let caller = optimized.pretty_print_defined_func(1U)
  assert_true(caller.contains("global.set"), msg=caller)
  assert_false(caller.contains("f64.const"), msg=caller)
  assert_false(caller.contains("f32.const"), msg=caller)
  assert_true(caller.contains("(call (Func 0))"), msg=caller)
}

///|
test "dae-optimizing does not rewrite exported or ref-func-escaped callees" {
  let exported_source =
    #|(module
    #|  (func $f (export "f") (param i32)
    #|    nop)
    #|  (func (export "run")
    #|    i32.const 10
    #|    call $f))
  let exported = dae_test_run(exported_source)
  @debug.assert_eq(dae_test_func_params(exported, 0).length(), 1)

  let escaped_source =
    #|(module
    #|  (table 1 funcref)
    #|  (elem declare func $f)
    #|  (func $f (param i32)
    #|    nop)
    #|  (func (export "run") (result funcref)
    #|    ref.func $f))
  let escaped = dae_test_run(escaped_source)
  @debug.assert_eq(dae_test_func_params(escaped, 0).length(), 1)
}

///|
test "dae-optimizing removes results when all direct callers drop them" {
  let source =
    #|(module
    #|  (func $f (result f64)
    #|    f64.const 42)
    #|  (func (export "run")
    #|    call $f
    #|    drop))
  let optimized = dae_test_run(source)
  let callee = optimized.pretty_print_defined_func(0U)
  let caller = optimized.pretty_print_defined_func(1U)
  assert_true(callee.contains("results: []"), msg=callee)
  assert_true(caller.contains("(call (Func 0))"), msg=caller)
  assert_false(caller.contains("drop"), msg=caller)
}

///|
test "dae-optimizing preserves uncalled no-param results like Binaryen" {
  let source =
    #|(module
    #|  (func $dead (result i64)
    #|    i64.const 1)
    #|  (func (export "run")))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_results(optimized, 0).length(), 1)
}

///|
test "dae-optimizing removes unobserved params and results from unreachable private functions" {
  let source =
    #|(module
    #|  (func $dead (param i32 f64) (result f64)
    #|    i32.const 1
    #|    drop
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    drop
    #|    i32.const 0
    #|    f64.const 42
    #|    call $dead)
    #|  (func (export "run")))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 0).length(), 0)
  let dead = optimized.pretty_print_defined_func(0U)
  assert_true(dead.contains("unreachable"), msg=dead)
  assert_false(dead.contains("f64.const"), msg=dead)
}

///|
test "dae-optimizing keeps no-param results with prior undropped dead-suffix calls" {
  let source =
    #|(module
    #|  (func (export "run") (result i64)
    #|    unreachable
    #|    call $f)
    #|  (func $f (result i64)
    #|    block
    #|      unreachable
    #|    end
    #|    call $f
    #|    drop
    #|    i64.const 1))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 1)
}

///|
test "dae-optimizing keeps undropped no-param dead self suffix results" {
  let source =
    #|(module
    #|  (func $dead (result f64)
    #|    block
    #|      unreachable
    #|    end
    #|    call $dead)
    #|  (func (export "run")))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_results(optimized, 0).length(), 1)
}

///|
test "dae-optimizing removes dropped results from no-param dead self suffixes" {
  let source =
    #|(module
    #|  (func $dead (result f64)
    #|    block
    #|      unreachable
    #|    end
    #|    call $dead
    #|    drop
    #|    f64.const 1)
    #|  (func (export "run")))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_results(optimized, 0).length(), 0)
}

///|
test "dae-optimizing keeps no-param results with later undropped callers" {
  let source =
    #|(module
    #|  (func $main (export "main") (param i32) (result f64)
    #|    block
    #|      unreachable
    #|    end
    #|    call $f2
    #|    call $main)
    #|  (func $f1 (result i32)
    #|    (local i32)
    #|    block
    #|      unreachable
    #|    end
    #|    call $f1
    #|    drop
    #|    local.get 0)
    #|  (func $f2 (result i32)
    #|    block
    #|      unreachable
    #|    end
    #|    call $f2
    #|    drop
    #|    call $f1))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 1)
  @debug.assert_eq(dae_test_func_results(optimized, 2).length(), 1)
}

///|
test "dae-optimizing keeps no-param undropped self results with dropped callers" {
  let source =
    #|(module
    #|  (func $main (export "main") (result i64)
    #|    block
    #|      unreachable
    #|    end
    #|    call $f1
    #|    drop
    #|    i64.const 817)
    #|  (func $f1 (result i64)
    #|    (local i32)
    #|    block
    #|      unreachable
    #|    end
    #|    f32.const 16
    #|    local.get 0
    #|    call $f2
    #|    drop
    #|    call $f1)
    #|  (func $f2 (param f32 i32) (result f32)
    #|    block
    #|      unreachable
    #|    end
    #|    call $f1
    #|    drop
    #|    local.get 0))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 1)
  @debug.assert_eq(dae_test_func_results(optimized, 2).length(), 0)
}

///|
test "dae-optimizing keeps results when dead self suffix has another call" {
  let source =
    #|(module
    #|  (func $side (result i64)
    #|    unreachable)
    #|  (func $dead (param i64) (result i64)
    #|    block
    #|      unreachable
    #|    end
    #|    call $side
    #|    drop
    #|    local.get 0
    #|    call $dead)
    #|  (func (export "run")))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 1)
}

///|
test "dae-optimizing prunes dropped callers ending in undropped callees" {
  let source =
    #|(module
    #|  (func $main (export "main") (param f64) (result f32)
    #|    block
    #|      unreachable
    #|    end
    #|    call $f1
    #|    drop
    #|    f32.const 63)
    #|  (func $f1 (result f64)
    #|    block
    #|      unreachable
    #|    end
    #|    f64.const 47
    #|    call $f3
    #|    drop
    #|    f64.const 80)
    #|  (func $f2 (param f64) (result f32)
    #|    block
    #|      unreachable
    #|    end
    #|    f64.const 9
    #|    call $f2
    #|    drop
    #|    f32.const 1)
    #|  (func $f3 (param f64) (result f32)
    #|    block
    #|      unreachable
    #|    end
    #|    f64.const 41
    #|    call $f2
    #|    drop
    #|    local.get 0
    #|    call $f2))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 3).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 3).length(), 0)
}

///|
test "dae-optimizing prunes callees with mixed dropped undropped callers" {
  let source =
    #|(module
    #|  (func $main (export "main") (param i64 f32) (result f32)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    local.get 1
    #|    call $f2
    #|    drop
    #|    f32.const 1)
    #|  (func $f1 (param i64 f32) (result f32)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    f32.const 33
    #|    call $f2
    #|    drop
    #|    i64.const 906
    #|    local.get 1
    #|    call $f2)
    #|  (func $f2 (param i64 f32) (result f32)
    #|    block
    #|      unreachable
    #|    end
    #|    i64.const 541
    #|    call $f3
    #|    drop
    #|    i64.const 859
    #|    i64.const 328
    #|    local.get 1
    #|    call $f1
    #|    call $main)
    #|  (func $f3 (param i64) (result f32)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    f32.const 15
    #|    call $f2
    #|    drop
    #|    i64.const 165
    #|    call $f3))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 2).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 2).length(), 0)
}

///|
test "dae-optimizing keeps originally-parameterized block self result suffixes" {
  let source =
    #|(module
    #|  (func $main (export "main") (result i32)
    #|    block
    #|      unreachable
    #|    end
    #|    call $f2
    #|    call $f1
    #|    drop
    #|    call $main)
    #|  (func $f1 (param f64 f32) (result f64)
    #|    block
    #|      unreachable
    #|    end
    #|    f64.const 88
    #|    f32.const 7
    #|    call $f1
    #|    drop
    #|    block (result f64)
    #|      local.get 0
    #|      f32.const 73
    #|      call $f1
    #|    end)
    #|  (func $f2 (result f32)
    #|    block
    #|      unreachable
    #|    end
    #|    call $main
    #|    drop
    #|    f32.const 1)
    #|  (func $f3 (result f32)
    #|    block
    #|      unreachable
    #|    end
    #|    call $f2
    #|    drop
    #|    f32.const 2))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 1)
}

///|
test "dae-optimizing keeps originally-parameterized dead self-suffix results" {
  let source =
    #|(module
    #|  (func $dead (param f32) (result i32)
    #|    block
    #|      unreachable
    #|    end
    #|    f32.const 1
    #|    call $dead
    #|    drop
    #|    local.get 0
    #|    drop
    #|    i32.const 1)
    #|  (func (export "run")))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 0).length(), 1)
}

///|
test "dae-optimizing prunes later mutual dropped result callees" {
  let source =
    #|(module
    #|  (func $main (export "main") (param i64 i64) (result i64)
    #|    block
    #|      unreachable
    #|    end
    #|    i64.const 662
    #|    i64.const 247
    #|    call $main
    #|    drop
    #|    local.get 0)
    #|  (func $f1 (param i64 i64) (result i64)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    local.get 0
    #|    call $f2
    #|    drop
    #|    local.get 0)
    #|  (func $f2 (param i64 i64) (result i64)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    local.get 0
    #|    call $f1
    #|    drop
    #|    local.get 0)
    #|  (func $f3 (param i64 i64) (result i64)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    local.get 0
    #|    call $f2
    #|    drop
    #|    local.get 0))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 1)
  @debug.assert_eq(dae_test_func_results(optimized, 2).length(), 0)
}

///|
test "dae-optimizing prunes no-param dropped self results under dead self callers" {
  let source =
    #|(module
    #|  (func $main (export "main") (param i32) (result i32)
    #|    block
    #|      unreachable
    #|    end
    #|    call $f2
    #|    drop
    #|    i32.const 49)
    #|  (func $f1 (param i32) (result i32)
    #|    block
    #|      unreachable
    #|    end
    #|    i32.const 819
    #|    call $f1
    #|    drop
    #|    call $f2)
    #|  (func $f2 (result i32)
    #|    (local i32)
    #|    block
    #|      unreachable
    #|    end
    #|    call $f2
    #|    drop
    #|    local.get 0))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_results(optimized, 2).length(), 0)
}

///|
test "dae-optimizing prunes dropped self results with dropped side callers" {
  let source =
    #|(module
    #|  (func $main (export "main") (param f64 i32)
    #|    f64.const 53
    #|    local.get 1
    #|    call $f3)
    #|  (func $f1 (param i64 i32) (result i32)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    i32.const 697
    #|    call $f1
    #|    drop
    #|    i32.const 7)
    #|  (func $f2
    #|    block
    #|      unreachable
    #|    end
    #|    i64.const 404
    #|    i32.const 1
    #|    call $f1
    #|    drop)
    #|  (func $f3 (param f64 i32)
    #|    block
    #|      unreachable
    #|    end
    #|    i64.const 432
    #|    i32.const 361
    #|    call $f1
    #|    drop))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 0)
}

///|
test "dae-optimizing keeps escaped-drop callees under dropped self callers" {
  let source =
    #|(module
    #|  (func $main (export "main") (param f64) (result i32)
    #|    local.get 0
    #|    call $main
    #|    drop
    #|    i32.const 1)
    #|  (func $side (param f64) (result i32)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    call $main
    #|    drop
    #|    i32.const 2)
    #|  (func $caller (param f64) (result i32)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    call $side
    #|    drop
    #|    i32.const 1
    #|    if (result i32)
    #|      local.get 0
    #|      call $caller
    #|    else
    #|      i32.const 834
    #|    end))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 1)
}

///|
test "dae-optimizing keeps parameterized dead self result side chains" {
  let source =
    #|(module
    #|  (func $main (export "main") (param f64 i64) (result f32)
    #|    block
    #|      unreachable
    #|    end
    #|    f32.const 24
    #|    i32.const 933
    #|    call $f1
    #|    drop
    #|    f32.const 1)
    #|  (func $f1 (param f32 i32) (result i64)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    i32.const 163
    #|    call $f1
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    call $f2)
    #|  (func $f2 (param f32 i32) (result i64)
    #|    block
    #|      unreachable
    #|    end
    #|    f64.const 56
    #|    i64.const 429
    #|    call $f3
    #|    drop
    #|    i32.const 1
    #|    if (result i64)
    #|      i64.const 876
    #|    else
    #|      local.get 0
    #|      local.get 1
    #|      call $f1
    #|    end)
    #|  (func $f3 (param f64 i64) (result f32)
    #|    block
    #|      unreachable
    #|    end
    #|    f32.const 79
    #|    i32.const 926
    #|    call $f2
    #|    drop
    #|    f64.const 55
    #|    i64.const 369
    #|    call $f3))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 3).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 3).length(), 1)
}

///|
test "dae-optimizing keeps dead-suffix-only originally-parameterized results" {
  let source =
    #|(module
    #|  (func $dead (param f64) (result f64)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0)
    #|  (func (export "run")
    #|    unreachable
    #|    f64.const 1
    #|    call $dead
    #|    drop))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 0).length(), 1)
}

///|
test "dae-optimizing removes params from dead-suffix-only unreachable callees" {
  let source =
    #|(module
    #|  (func $dead (param f64) (result f64)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0)
    #|  (func (export "run")
    #|    unreachable
    #|    f64.const 1
    #|    call $dead
    #|    drop))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
}

///|
test "dae-optimizing removes results from dead-suffix callees with side calls" {
  let source =
    #|(module
    #|  (func $side (export "run") (param i32 i64)
    #|    block
    #|      unreachable
    #|    end)
    #|  (func $dead (param f32) (result i32)
    #|    block
    #|      unreachable
    #|    end
    #|    i32.const 1
    #|    i64.const 2
    #|    call $side
    #|    i32.const 279)
    #|  (func $caller (param i32 i64)
    #|    block
    #|      unreachable
    #|    end
    #|    f32.const 1
    #|    call $dead
    #|    drop))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 0)
}

///|
test "dae-optimizing keeps results in mutual dead-suffix cycles" {
  let source =
    #|(module
    #|  (func $a (param f32) (result i32)
    #|    block
    #|      unreachable
    #|    end
    #|    i32.const 1
    #|    call $b
    #|    i32.const 2)
    #|  (func $b (param i32)
    #|    block
    #|      unreachable
    #|    end
    #|    f32.const 0
    #|    call $a
    #|    drop)
    #|  (func (export "run")))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 0).length(), 1)
}

///|
test "dae-optimizing keeps non-adjacent self-call operands in dead suffixes" {
  let source =
    #|(module
    #|  (func $root (export "run") (param f32 f32) (result f32)
    #|    block
    #|      unreachable
    #|    end
    #|    f32.const 31
    #|    f32.const 69
    #|    call $g)
    #|  (func $f (param f32 f32) (result f32)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    f32.const 19
    #|    f32.const 78
    #|    call $g
    #|    call $f
    #|    drop
    #|    local.get 0)
    #|  (func $g (param f32 f32) (result f32)
    #|    block
    #|      unreachable
    #|    end
    #|    f32.const 0
    #|    f32.const 1
    #|    call $g))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 1)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 1)
  @debug.assert_eq(dae_test_func_params(optimized, 2).length(), 0)
}

///|
test "dae-optimizing finishes dead-suffix parameter cycles after callers vanish" {
  let source =
    #|(module
    #|  (func $main (export "main") (param i64 f32)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    local.get 1
    #|    call $c)
    #|  (func $a (param i64 f32)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    f32.const 1
    #|    call $b)
    #|  (func $b (param i64 f32)
    #|    block
    #|      unreachable
    #|    end
    #|    i64.const 2
    #|    local.get 1
    #|    call $c)
    #|  (func $c (param i64 f32)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    local.get 1
    #|    call $a))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 0)
  @debug.assert_eq(dae_test_func_params(optimized, 2).length(), 0)
  @debug.assert_eq(dae_test_func_params(optimized, 3).length(), 0)
}

///|
test "dae-optimizing preserves private result callees in dropped suffix chains" {
  let source =
    #|(module
    #|  (func $main (export "main") (param i32) (result i64)
    #|    block
    #|      unreachable
    #|    end
    #|    i32.const 1
    #|    call $f2
    #|    drop
    #|    i64.const 0)
    #|  (func $f1 (param i32) (result i64)
    #|    block
    #|      unreachable
    #|    end
    #|    i32.const 2
    #|    call $main
    #|    drop
    #|    i64.const 16)
    #|  (func $f2 (param i32) (result i64)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    call $f3
    #|    drop
    #|    i64.const 17)
    #|  (func $f3 (param i32) (result i64)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    call $f1
    #|    drop
    #|    i64.const 18))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 1)
  @debug.assert_eq(dae_test_func_results(optimized, 2).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 3).length(), 1)
}

///|
test "dae-optimizing preserves results across dropped result side callees" {
  let source =
    #|(module
    #|  (func $main (export "main") (param i64 i64) (result f32)
    #|    block
    #|      unreachable
    #|    end
    #|    i64.const 1
    #|    i64.const 2
    #|    call $f3)
    #|  (func $f1 (param i64 i64) (result f32)
    #|    block
    #|      unreachable
    #|    end
    #|    i64.const 3
    #|    local.get 0
    #|    call $f3
    #|    drop
    #|    f32.const 1)
    #|  (func $f2 (param i32 f64)
    #|    block
    #|      unreachable
    #|    end
    #|    i64.const 4
    #|    i64.const 5
    #|    call $f1
    #|    drop)
    #|  (func $f3 (param i64 i64) (result f32)
    #|    block
    #|      unreachable
    #|    end
    #|    i32.const 68
    #|    f64.const 5
    #|    call $f2
    #|    f32.const 3))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 1)
  @debug.assert_eq(dae_test_func_params(optimized, 2).length(), 0)
  @debug.assert_eq(dae_test_func_params(optimized, 3).length(), 0)
}

///|
test "dae-optimizing preserves escaped-result operand side chains" {
  let source =
    #|(module
    #|  (func $main (export "main") (param i64) (result i64)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    call $main
    #|    call $f2
    #|    drop
    #|    local.get 0)
    #|  (func $f1 (param i64) (result i64)
    #|    block
    #|      unreachable
    #|    end
    #|    i64.const 1)
    #|  (func $f2 (param i64) (result i64)
    #|    block
    #|      unreachable
    #|    end
    #|    call $f3
    #|    drop
    #|    i64.const 643)
    #|  (func $f3 (result i64)
    #|    block
    #|      unreachable
    #|    end
    #|    i64.const 42
    #|    call $f1
    #|    drop
    #|    i64.const 653))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 2).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 2).length(), 1)
  @debug.assert_eq(dae_test_func_params(optimized, 3).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 3).length(), 1)
}

///|
test "dae-optimizing prunes dropped self results reached from no-param callers" {
  let source =
    #|(module
    #|  (func $main (export "main") (result i64)
    #|    block
    #|      unreachable
    #|    end
    #|    call $f2
    #|    drop
    #|    call $main)
    #|  (func $f1 (param f64) (result i64)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    call $f1
    #|    drop
    #|    i64.const 745)
    #|  (func $f2 (result i64)
    #|    block
    #|      unreachable
    #|    end
    #|    f64.const 1
    #|    call $f1
    #|    drop
    #|    i64.const 420))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 0)
}

///|
test "dae-optimizing preserves result callees under undropped self callers" {
  let source =
    #|(module
    #|  (func $main (export "main") (param f64) (result i64)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    call $f2
    #|    drop
    #|    f64.const 84
    #|    call $f2)
    #|  (func $f1 (param f64) (result i64)
    #|    block
    #|      unreachable
    #|    end
    #|    f64.const 85
    #|    call $main
    #|    drop
    #|    i64.const 829)
    #|  (func $f2 (param f64) (result i64)
    #|    block
    #|      unreachable
    #|    end
    #|    f64.const 70
    #|    call $f1
    #|    drop
    #|    f64.const 8
    #|    call $f2))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 1)
  @debug.assert_eq(dae_test_func_params(optimized, 2).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 2).length(), 1)
}

///|
test "dae-optimizing preserves self-result operand chains" {
  let source =
    #|(module
    #|  (func $main (export "main") (param i64 f64) (result i32)
    #|    block
    #|      unreachable
    #|    end
    #|    f64.const 53
    #|    i64.const 367
    #|    call $f2
    #|    local.get 1
    #|    call $f1)
    #|  (func $f1 (param i64 f64) (result i32)
    #|    block
    #|      unreachable
    #|    end
    #|    i32.const 659)
    #|  (func $f2 (param f64 i64) (result i64)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    f64.const 49
    #|    local.get 1
    #|    call $f2
    #|    call $f2
    #|    drop
    #|    local.get 1)
    #|  (func $f3 (param i64 f64) (result i32)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    f64.const 32
    #|    call $f1))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 2).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 2).length(), 1)
}

///|
test "dae-optimizing preserves undropped self results reached from no-param dropped callers" {
  let source =
    #|(module
    #|  (func $main (export "main") (result f64)
    #|    block
    #|      unreachable
    #|    end
    #|    call $f2
    #|    drop
    #|    call $f2)
    #|  (func $f1 (param f64 i64) (result f32)
    #|    block
    #|      unreachable
    #|    end
    #|    call $f3
    #|    drop
    #|    f64.const 25
    #|    local.get 1
    #|    call $f1)
    #|  (func $f2 (result f64)
    #|    block
    #|      unreachable
    #|    end
    #|    call $main
    #|    i64.const 34
    #|    call $f1
    #|    drop
    #|    f64.const 4)
    #|  (func $f3 (result f64)
    #|    block
    #|      unreachable
    #|    end
    #|    call $main
    #|    drop
    #|    f64.const 4))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 1)
}

///|
test "dae-optimizing prunes result callees reached only from no-param self callers" {
  let source =
    #|(module
    #|  (func $main (export "main") (result i32)
    #|    block
    #|      unreachable
    #|    end
    #|    i64.const 450
    #|    i64.const 682
    #|    call $f3
    #|    drop
    #|    i32.const 0)
    #|  (func $f1 (param i64 i64) (result f64)
    #|    block
    #|      unreachable
    #|    end
    #|    call $f2
    #|    drop
    #|    f64.const 1)
    #|  (func $f2 (result i32)
    #|    block
    #|      unreachable
    #|    end
    #|    i64.const 208
    #|    i64.const 9
    #|    call $f1
    #|    drop
    #|    call $f2)
    #|  (func $f3 (param i64 i64) (result f64)
    #|    block
    #|      unreachable
    #|    end
    #|    i64.const 954
    #|    local.get 0
    #|    call $f3
    #|    drop
    #|    f64.const 42))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 0)
}

///|
test "dae-optimizing preserves no-param side callees under param-operand self results" {
  let source =
    #|(module
    #|  (func $main (export "main") (result f64)
    #|    block
    #|      unreachable
    #|    end
    #|    call $f2
    #|    drop
    #|    call $f2)
    #|  (func $f1 (param f64 i64) (result f32)
    #|    block
    #|      unreachable
    #|    end
    #|    call $f3
    #|    drop
    #|    f64.const 25
    #|    local.get 1
    #|    call $f1)
    #|  (func $f2 (result f64)
    #|    block
    #|      unreachable
    #|    end
    #|    call $main
    #|    i64.const 34
    #|    call $f1
    #|    drop
    #|    f64.const 4)
    #|  (func $f3 (result f64)
    #|    block
    #|      unreachable
    #|    end
    #|    call $main
    #|    drop
    #|    f64.const 4))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_results(optimized, 3).length(), 1)
}

///|
test "dae-optimizing prunes no-param results with escaped dropped callers" {
  let source =
    #|(module
    #|  (func $main (export "main")
    #|    block
    #|      unreachable
    #|    end
    #|    call $f1
    #|    drop)
    #|  (func $f1 (result i64)
    #|    (local i32 i64 f32)
    #|    block
    #|      unreachable
    #|    end
    #|    call $f2
    #|    drop
    #|    local.get 1)
    #|  (func $f2 (result i64)
    #|    (local i32 i32)
    #|    block
    #|      unreachable
    #|    end
    #|    call $f1
    #|    drop
    #|    call $f1))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 0)
}

///|
test "dae-optimizing prunes parameters in mutual self-result suffixes" {
  let source =
    #|(module
    #|  (func $main (export "main") (param i64) (result i64)
    #|    block
    #|      unreachable
    #|    end
    #|    f64.const 1
    #|    call $f1
    #|    drop
    #|    i64.const 0)
    #|  (func $f1 (param f64) (result i32)
    #|    block
    #|      unreachable
    #|    end
    #|    f64.const 51
    #|    call $f2
    #|    drop
    #|    local.get 0
    #|    call $f1)
    #|  (func $f2 (param f64) (result i32)
    #|    block
    #|      unreachable
    #|    end
    #|    f64.const 62
    #|    call $f1
    #|    drop
    #|    f64.const 53
    #|    call $f2))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 0)
  @debug.assert_eq(dae_test_func_params(optimized, 2).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 2).length(), 1)
}

///|
test "dae-optimizing preserves results with void dead-suffix side calls" {
  let source =
    #|(module
    #|  (func $main (export "main") (param f32 f32)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    local.get 1
    #|    call $f1
    #|    drop)
    #|  (func $f1 (param f32 f32)
    #|    (local f64 i64 i32)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 4
    #|    local.get 2
    #|    call $f3
    #|    drop)
    #|  (func $f2 (param f32 f32)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    f32.const 17
    #|    call $f2)
    #|  (func $f3 (param i32 f64) (result i32)
    #|    block
    #|      unreachable
    #|    end
    #|    f32.const 56
    #|    f32.const 55
    #|    call $f2
    #|    i32.const 637))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 3).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 3).length(), 1)
}

///|
test "dae-optimizing prunes private result callees in mixed self chains" {
  let source =
    #|(module
    #|  (func $main (export "main")
    #|    block
    #|      unreachable
    #|    end)
    #|  (func $f1 (param f64 i32) (result i32)
    #|    block
    #|      unreachable
    #|    end
    #|    f64.const 79
    #|    i32.const 588
    #|    call $f3
    #|    drop
    #|    i32.const 86)
    #|  (func $f2 (result i64)
    #|    block
    #|      unreachable
    #|    end
    #|    f64.const 14
    #|    i32.const 1
    #|    call $f1
    #|    drop
    #|    i64.const 224)
    #|  (func $f3 (param f64 i32) (result i32)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    local.get 0
    #|    local.get 1
    #|    call $f1
    #|    call $f1
    #|    drop
    #|    f64.const 7
    #|    local.get 1
    #|    call $f1))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 3).length(), 1)
}

///|
test "dae-optimizing preserves parameterized dropped self results with dropped callers" {
  let source =
    #|(module
    #|  (func $main (export "main") (param i32 f64)
    #|    block
    #|      unreachable
    #|    end
    #|    f32.const 1
    #|    f64.const 73
    #|    call $f2
    #|    drop)
    #|  (func $f1 (param f32 f64) (result i32)
    #|    (local i32)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 2)
    #|  (func $f2 (param f32 f64) (result i32)
    #|    (local i32)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    f64.const 54
    #|    call $f3
    #|    drop
    #|    local.get 2)
    #|  (func $f3 (param f32 f64) (result i32)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    f64.const 16
    #|    call $f3
    #|    drop
    #|    i32.const 229))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 3).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 3).length(), 1)
}

///|
test "dae-optimizing preserves private escaped-result suffix results" {
  let source =
    #|(module
    #|  (func $main (export "main") (param f64 f64) (result f64)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0)
    #|  (func $f1 (param i32)
    #|    (local f64)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 1
    #|    f64.const 38
    #|    call $f3
    #|    drop)
    #|  (func $f2 (param f64 f64) (result f64)
    #|    (local i32)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 2
    #|    call $f1
    #|    local.get 0)
    #|  (func $f3 (param f64 f64) (result f64)
    #|    (local i64 i64 i64 i32)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 5
    #|    call $f1
    #|    local.get 0
    #|    local.get 0
    #|    call $main))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 3).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 3).length(), 1)
}

///|
test "dae-optimizing preserves private escaped-result operand callees" {
  let source =
    #|(module
    #|  (func $main (export "main") (result f32)
    #|    block
    #|      unreachable
    #|    end
    #|    i32.const 482
    #|    f32.const 45
    #|    call $f2
    #|    drop
    #|    f32.const 0)
    #|  (func $f1 (result f32)
    #|    (local i32)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    call $main
    #|    call $f2
    #|    drop
    #|    f32.const 1)
    #|  (func $f2 (param i32 f32) (result f32)
    #|    block
    #|      unreachable
    #|    end
    #|    call $main
    #|    drop
    #|    f32.const 97)
    #|  (func $f3 (result f32)
    #|    block
    #|      unreachable
    #|    end
    #|    call $f3
    #|    drop
    #|    f32.const 3))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_results(optimized, 2).length(), 1)
  @debug.assert_eq(dae_test_func_results(optimized, 3).length(), 0)
}

///|
test "dae-optimizing prunes escaped-result side callees under active result callers" {
  let source =
    #|(module
    #|  (func $main (export "main") (param f32 f64) (result f64)
    #|    block
    #|      unreachable
    #|    end
    #|    f32.const 27
    #|    local.get 1
    #|    call $main
    #|    drop
    #|    f32.const 92
    #|    local.get 1
    #|    call $f2)
    #|  (func $f1 (param f32 f64) (result f64)
    #|    block
    #|      unreachable
    #|    end
    #|    f32.const 4
    #|    f64.const 67
    #|    call $main
    #|    drop
    #|    f64.const 28)
    #|  (func $f2 (param f32 f64) (result f64)
    #|    block
    #|      unreachable
    #|    end
    #|    f32.const 19
    #|    f32.const 67
    #|    local.get 1
    #|    call $f1
    #|    call $main
    #|    drop
    #|    local.get 1)
    #|  (func $f3 (param i32)
    #|    (local f32)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 1
    #|    f64.const 57
    #|    call $f1
    #|    drop))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 2).length(), 1)
}

///|
test "dae-optimizing prunes side-call result cycles reached by dropped callers" {
  let source =
    #|(module
    #|  (func $main (export "main")
    #|    block
    #|      unreachable
    #|    end
    #|    call $f1
    #|    drop)
    #|  (func $f1 (result i32)
    #|    (local i32)
    #|    block
    #|      unreachable
    #|    end
    #|    f64.const 61
    #|    f32.const 38
    #|    call $f3
    #|    drop
    #|    local.get 0)
    #|  (func $f2 (param f64 f32) (result i32)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    local.get 1
    #|    call $f3
    #|    drop
    #|    f64.const 17
    #|    f32.const 58
    #|    call $f2)
    #|  (func $f3 (param f64 f32) (result i32)
    #|    (local i32)
    #|    block
    #|      unreachable
    #|    end
    #|    call $f1
    #|    drop
    #|    local.get 2))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_results(optimized, 2).length(), 1)
  @debug.assert_eq(dae_test_func_results(optimized, 3).length(), 0)
}

///|
test "dae-optimizing prunes inactive private result-side callers" {
  let source =
    #|(module
    #|  (func $f1 (result f32)
    #|    block
    #|      unreachable
    #|    end
    #|    i32.const 1
    #|    f64.const 2
    #|    call $f3
    #|    drop
    #|    f32.const 1)
    #|  (func $f2 (param i32 f64) (result f32)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    local.get 1
    #|    call $f2
    #|    drop
    #|    f32.const 2)
    #|  (func $f3 (param i32 f64) (result f32)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    local.get 1
    #|    call $f2
    #|    drop
    #|    f32.const 3)
    #|  (func (export "run")))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 1)
  @debug.assert_eq(dae_test_func_results(optimized, 2).length(), 0)
}

///|
test "dae-optimizing preserves self-suffix results reached from later undropped callers" {
  let source =
    #|(module
    #|  (func $f1 (param i64) (result i32)
    #|    (local i32)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    call $f1
    #|    drop
    #|    local.get 1)
    #|  (func $f2 (param i64) (result i32)
    #|    block
    #|      unreachable
    #|    end
    #|    i64.const 782
    #|    call $f1)
    #|  (func (export "run")))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 0).length(), 1)
}

///|
test "dae-optimizing removes dropped self-suffix results reached only from uncalled later callers" {
  let source =
    #|(module
    #|  (func $f1 (param f64) (result i32)
    #|    block
    #|      unreachable
    #|    end
    #|    f64.const 2
    #|    call $f1
    #|    drop
    #|    i32.const 1)
    #|  (func $f2 (param f32 i32)
    #|    block
    #|      unreachable
    #|    end
    #|    f64.const 3
    #|    call $f1
    #|    drop)
    #|  (func (export "run")))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 0).length(), 0)
}

///|
test "dae-optimizing prunes private result side callees reached from dead suffix callers" {
  let source =
    #|(module
    #|  (func $main (export "main") (param f64) (result f64)
    #|    block
    #|      unreachable
    #|    end
    #|    f64.const 0)
    #|  (func $f1 (param f64) (result f64)
    #|    block
    #|      unreachable
    #|    end
    #|    f64.const 53
    #|    call $main
    #|    drop
    #|    f64.const 87)
    #|  (func $f2 (param f64) (result f64)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    call $f1
    #|    drop
    #|    local.get 0))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 0)
}

///|
test "dae-optimizing preserves private mixed self-suffix results" {
  let source =
    #|(module
    #|  (func $main (export "main") (param i32) (result f32)
    #|    block
    #|      unreachable
    #|    end
    #|    i32.const 1
    #|    call $f1)
    #|  (func $f1 (param i32) (result f32)
    #|    block
    #|      unreachable
    #|    end
    #|    i32.const 2
    #|    call $f2
    #|    drop
    #|    f32.const 1)
    #|  (func $f2 (param i32) (result f32)
    #|    block
    #|      unreachable
    #|    end
    #|    local.get 0
    #|    call $f2
    #|    drop
    #|    local.get 0
    #|    call $f2))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 1)
  @debug.assert_eq(dae_test_func_params(optimized, 2).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 2).length(), 1)
}

///|
test "dae-optimizing cleans unobservable prefix before unreachable after result removal" {
  let source =
    #|(module
    #|  (func $f (result f64)
    #|    i32.const 1
    #|    drop
    #|    block
    #|      i32.const 0
    #|      br_table 0 0
    #|    end
    #|    block
    #|      unreachable
    #|    end
    #|    f64.const 42)
    #|  (func (export "run")
    #|    call $f
    #|    drop))
  let optimized = dae_test_run(source)
  let callee = optimized.pretty_print_defined_func(0U)
  assert_true(callee.contains("results: []"), msg=callee)
  assert_true(callee.contains("unreachable"), msg=callee)
  assert_false(callee.contains("br_table"), msg=callee)
}

///|
test "dae-optimizing keeps self-recursive dropped results while pruning dead params" {
  let source =
    #|(module
    #|  (func $f (param f32) (result i32)
    #|    f32.const 1
    #|    call $f
    #|    drop
    #|    unreachable)
    #|  (func (export "run") (result i32)
    #|    unreachable))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  let recursive = optimized.pretty_print_defined_func(0U)
  assert_true(recursive.contains("results: [I32]"), msg=recursive)
}

///|
test "dae-optimizing prunes unused simple function types like Binaryen" {
  let source =
    #|(module
    #|  (type $unused (func (param f64)))
    #|  (type $kept (func))
    #|  (func (export "run") (type $kept)))
  let optimized = dae_test_run(source)
  match optimized.type_sec {
    Some(@lib.TypeSec(types)) => @debug.assert_eq(types.length(), 1)
    None => fail("expected type section")
  }
}

///|
test "dae-optimizing emits nested cleanup trace for touched functions" {
  let source =
    #|(module
    #|  (func $f (param i32)
    #|    nop)
    #|  (func (export "run")
    #|    i32.const 1
    #|    call $f))
  let trace = match pass_test_capture_trace(source, ["dae-optimizing"]) {
    Ok(trace) => trace
    Err(err) => fail("expected traced DAE success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) { line.contains("pass[dae-optimizing]:nested-cleanup") }),
    msg=trace.to_string(),
  )
}

///|
test "dae-optimizing nested cleanup only rewrites touched functions" {
  let source =
    #|(module
    #|  (func $f (param i32 i32) (result i32)
    #|    local.get 0
    #|    local.set 1
    #|    local.get 0)
    #|  (func (export "run") (result i32)
    #|    i32.const 10
    #|    i32.const 20
    #|    call $f)
    #|  (func (export "untouched") (local i32)
    #|    i32.const 9
    #|    local.set 0))
  let optimized = dae_test_run(source)
  let touched_callee = optimized.pretty_print_defined_func(0U)
  let untouched = optimized.pretty_print_defined_func(2U)
  assert_false(touched_callee.contains("local.set"), msg=touched_callee)
  assert_true(untouched.contains("local.set"), msg=untouched)
}

///|
test "dae-optimizing nested local-cse only rewrites touched functions" {
  let source =
    #|(module
    #|  (import "env" "use" (func $use (param i32 i32)))
    #|  (func $f (param i32 i32 i32)
    #|    local.get 0
    #|    local.get 1
    #|    i32.add
    #|    local.get 0
    #|    local.get 1
    #|    i32.add
    #|    call $use)
    #|  (func (export "run")
    #|    i32.const 10
    #|    i32.const 20
    #|    i32.const 30
    #|    call $f)
    #|  (func (export "untouched") (param i32 i32)
    #|    local.get 0
    #|    local.get 1
    #|    i32.add
    #|    local.get 0
    #|    local.get 1
    #|    i32.add
    #|    call $use))
  let optimized = match pass_test_run_pipeline(source, ["dae-optimizing"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected DAE local-cse pipeline success, got \{err}")
  }
  let @lib.Func(touched_locals, @lib.Expr(touched_instrs)) = dae_test_defined_func(
    optimized, 0,
  )
  let @lib.Func(untouched_locals, @lib.Expr(untouched_instrs)) = dae_test_defined_func(
    optimized, 2,
  )
  @debug.assert_eq(
    touched_locals,
    @lib.Locals::from_types([@lib.ValType::i32()]),
  )
  @debug.assert_eq(untouched_locals, @lib.Locals::empty())
  assert_true(
    touched_instrs.contains(@lib.Instruction::local_tee(@lib.LocalIdx::new(2U))),
    msg=optimized.pretty_print_defined_func(0U),
  )
  assert_false(
    untouched_instrs.contains(
      @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
    ),
    msg=optimized.pretty_print_defined_func(2U),
  )
}

///|
test "dae-optimizing nested merge-blocks only rewrites touched functions" {
  let source =
    #|(module
    #|  (import "env" "use" (func $use))
    #|  (func $f (param i32)
    #|    block
    #|      block
    #|        call $use
    #|      end
    #|    end)
    #|  (func (export "run")
    #|    i32.const 10
    #|    call $f)
    #|  (func (export "untouched")
    #|    block
    #|      block
    #|        call $use
    #|      end
    #|    end))
  let optimized = match pass_test_run_pipeline(source, ["dae-optimizing"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected DAE merge-blocks pipeline success, got \{err}")
  }
  let touched = optimized.pretty_print_defined_func(0U)
  let untouched = optimized.pretty_print_defined_func(2U)
  assert_false(touched.contains("(block"), msg=touched)
  assert_true(untouched.contains("(block"), msg=untouched)
}

///|
test "dae-optimizing nested remove-unused-brs only rewrites touched functions" {
  let source =
    #|(module
    #|  (func $f (param i32) (result i32)
    #|    block (result i32)
    #|      i32.const 7
    #|      br 0
    #|    end)
    #|  (func (export "run") (result i32)
    #|    i32.const 10
    #|    call $f)
    #|  (func (export "untouched") (result i32)
    #|    block (result i32)
    #|      i32.const 7
    #|      br 0
    #|    end))
  let optimized = match pass_test_run_pipeline(source, ["dae-optimizing"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected DAE remove-unused-brs pipeline success, got \{err}")
  }
  let touched = optimized.pretty_print_defined_func(0U)
  let untouched = optimized.pretty_print_defined_func(2U)
  assert_false(touched.contains("(br"), msg=touched)
  assert_true(untouched.contains("(br"), msg=untouched)
}

///|
test "dae-optimizing nested remove-unused-names only rewrites touched functions" {
  let source =
    #|(module
    #|  (import "env" "use" (func $use))
    #|  (func $f (param i32)
    #|    loop
    #|      call $use
    #|    end)
    #|  (func (export "run")
    #|    i32.const 10
    #|    call $f)
    #|  (func (export "untouched")
    #|    loop
    #|      call $use
    #|    end))
  let optimized = match pass_test_run_pipeline(source, ["dae-optimizing"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected DAE remove-unused-names pipeline success, got \{err}")
  }
  let touched = optimized.pretty_print_defined_func(0U)
  let untouched = optimized.pretty_print_defined_func(2U)
  assert_false(touched.contains("(loop"), msg=touched)
  assert_true(untouched.contains("(loop"), msg=untouched)
}

///|
test "dae-optimizing nested second merge-blocks only rewrites touched functions" {
  let source =
    #|(module
    #|  (import "env" "use" (func $use))
    #|  (func $f (param i32)
    #|    loop
    #|      call $use
    #|    end)
    #|  (func (export "run")
    #|    i32.const 10
    #|    call $f)
    #|  (func (export "untouched")
    #|    loop
    #|      call $use
    #|    end))
  let optimized = match pass_test_run_pipeline(source, ["dae-optimizing"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected DAE second merge-blocks pipeline success, got \{err}")
  }
  let touched = optimized.pretty_print_defined_func(0U)
  let untouched = optimized.pretty_print_defined_func(2U)
  assert_false(touched.contains("(loop"), msg=touched)
  assert_false(touched.contains("(block"), msg=touched)
  assert_true(untouched.contains("(loop"), msg=untouched)
}

///|
test "dae-optimizing nested optimize-instructions only rewrites touched functions" {
  let source =
    #|(module
    #|  (func $f (param i32) (result i32)
    #|    i32.const 249384
    #|    i32.const 15
    #|    i32.add)
    #|  (func (export "run") (result i32)
    #|    i32.const 10
    #|    call $f)
    #|  (func (export "untouched") (result i32)
    #|    i32.const 249384
    #|    i32.const 15
    #|    i32.add))
  let optimized = match pass_test_run_pipeline(source, ["dae-optimizing"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected DAE optimize-instructions pipeline success, got \{err}")
  }
  let touched = optimized.pretty_print_defined_func(0U)
  let untouched = optimized.pretty_print_defined_func(2U)
  assert_false(touched.contains("i32.add"), msg=touched)
  assert_true(touched.contains("I32(249399)"), msg=touched)
  assert_true(untouched.contains("i32.add"), msg=untouched)
}

///|
test "dae-optimizing nested code-folding only rewrites touched functions" {
  let source =
    #|(module
    #|  (import "env" "use" (func $use (param i32)))
    #|  (func $f (param i32 i32)
    #|    local.get 0
    #|    if
    #|      i32.const 7
    #|      call $use
    #|      i32.const 8
    #|      call $use
    #|    else
    #|      i32.const 7
    #|      call $use
    #|      i32.const 8
    #|      call $use
    #|    end)
    #|  (func (export "run")
    #|    i32.const 10
    #|    i32.const 20
    #|    call $f)
    #|  (func (export "untouched") (param i32)
    #|    local.get 0
    #|    if
    #|      i32.const 7
    #|      call $use
    #|      i32.const 8
    #|      call $use
    #|    else
    #|      i32.const 7
    #|      call $use
    #|      i32.const 8
    #|      call $use
    #|    end))
  let optimized = match pass_test_run_pipeline(source, ["dae-optimizing"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected DAE code-folding pipeline success, got \{err}")
  }
  let touched = optimized.pretty_print_defined_func(0U)
  let untouched = optimized.pretty_print_defined_func(2U)
  assert_false(touched.contains("(if"), msg=touched)
  assert_true(untouched.contains("(if"), msg=untouched)
}

///|
fn dae_test_bytes_from_ints(values : Array[Int]) -> Bytes {
  let out = @buffer.new(size_hint=values.length())
  for value in values {
    out.write_byte(value.to_byte())
  }
  out.to_bytes()
}

///|
fn dae_test_decode_wasm_bytes(values : Array[Int]) -> @lib.Module {
  match @binary.decode_module(dae_test_bytes_from_ints(values)) {
    Ok(mod_) => mod_
    Err(err) => abort("expected DAE wasm fixture decode success, got \{err}")
  }
}

///|
test "dae-optimizing preserves case 000690 escaped self-call operand param" {
  let input = dae_test_decode_wasm_bytes([
    0, 97, 115, 109, 1, 0, 0, 0, 0, 27, 10, 102, 122, 103, 46, 99, 117, 115, 116,
    111, 109, 118, 97, 108, 105, 100, 45, 102, 122, 103, 45, 99, 117, 115, 116, 111,
    109, 1, 7, 1, 96, 2, 124, 127, 1, 124, 3, 5, 4, 0, 0, 0, 0, 7, 8, 1, 4, 109,
    97, 105, 110, 0, 0, 10, 245, 27, 4, 245, 6, 3, 2, 127, 1, 126, 1, 127, 65, 0,
    69, 26, 65, 11, 65, 3, 70, 26, 65, 11, 65, 3, 71, 26, 65, 11, 65, 3, 72, 26,
    65, 11, 65, 3, 73, 26, 65, 11, 65, 3, 74, 26, 65, 11, 65, 3, 75, 26, 65, 11,
    65, 3, 76, 26, 65, 11, 65, 3, 77, 26, 65, 11, 65, 3, 78, 26, 65, 11, 65, 3, 79,
    26, 65, 212, 0, 65, 3, 109, 26, 65, 212, 0, 65, 3, 110, 26, 65, 212, 0, 65, 3,
    111, 26, 65, 212, 0, 65, 3, 112, 26, 65, 212, 0, 65, 3, 116, 26, 65, 212, 0,
    65, 3, 117, 26, 65, 212, 0, 65, 3, 118, 26, 65, 212, 0, 65, 3, 119, 26, 65, 212,
    0, 65, 3, 120, 26, 66, 0, 80, 26, 66, 227, 0, 66, 5, 81, 26, 66, 227, 0, 66,
    5, 82, 26, 66, 227, 0, 66, 5, 83, 26, 66, 227, 0, 66, 5, 84, 26, 66, 227, 0,
    66, 5, 85, 26, 66, 227, 0, 66, 5, 86, 26, 66, 227, 0, 66, 5, 87, 26, 66, 227,
    0, 66, 5, 88, 26, 66, 227, 0, 66, 5, 89, 26, 66, 227, 0, 66, 5, 90, 26, 66, 227,
    0, 66, 5, 127, 26, 66, 227, 0, 66, 5, 128, 26, 66, 227, 0, 66, 5, 129, 26, 66,
    227, 0, 66, 5, 130, 26, 66, 227, 0, 66, 5, 134, 26, 66, 227, 0, 66, 5, 135, 26,
    66, 227, 0, 66, 5, 136, 26, 66, 227, 0, 66, 5, 137, 26, 66, 227, 0, 66, 5, 138,
    26, 67, 0, 0, 20, 65, 141, 26, 67, 0, 0, 20, 65, 142, 26, 67, 0, 0, 20, 65, 143,
    26, 67, 0, 0, 20, 65, 144, 26, 67, 0, 0, 20, 65, 145, 26, 67, 0, 0, 20, 65, 67,
    0, 0, 32, 64, 150, 26, 67, 0, 0, 20, 65, 67, 0, 0, 32, 64, 151, 26, 67, 0, 0,
    20, 65, 67, 0, 0, 32, 64, 152, 26, 67, 0, 0, 20, 65, 67, 0, 0, 32, 64, 91, 26,
    67, 0, 0, 20, 65, 67, 0, 0, 32, 64, 92, 26, 67, 0, 0, 20, 65, 67, 0, 0, 32, 64,
    93, 26, 67, 0, 0, 20, 65, 67, 0, 0, 32, 64, 94, 26, 67, 0, 0, 20, 65, 67, 0,
    0, 32, 64, 95, 26, 67, 0, 0, 20, 65, 67, 0, 0, 32, 64, 96, 26, 68, 0, 0, 0, 0,
    0, 192, 48, 64, 155, 26, 68, 0, 0, 0, 0, 0, 192, 48, 64, 156, 26, 68, 0, 0, 0,
    0, 0, 192, 48, 64, 157, 26, 68, 0, 0, 0, 0, 0, 192, 48, 64, 158, 26, 68, 0, 0,
    0, 0, 0, 192, 48, 64, 159, 26, 68, 0, 0, 0, 0, 0, 192, 48, 64, 68, 0, 0, 0, 0,
    0, 0, 18, 64, 164, 26, 68, 0, 0, 0, 0, 0, 192, 48, 64, 68, 0, 0, 0, 0, 0, 0,
    18, 64, 165, 26, 68, 0, 0, 0, 0, 0, 192, 48, 64, 68, 0, 0, 0, 0, 0, 0, 18, 64,
    166, 26, 68, 0, 0, 0, 0, 0, 192, 48, 64, 68, 0, 0, 0, 0, 0, 0, 18, 64, 97, 26,
    68, 0, 0, 0, 0, 0, 192, 48, 64, 68, 0, 0, 0, 0, 0, 0, 18, 64, 98, 26, 68, 0,
    0, 0, 0, 0, 192, 48, 64, 68, 0, 0, 0, 0, 0, 0, 18, 64, 99, 26, 68, 0, 0, 0, 0,
    0, 192, 48, 64, 68, 0, 0, 0, 0, 0, 0, 18, 64, 100, 26, 68, 0, 0, 0, 0, 0, 192,
    48, 64, 68, 0, 0, 0, 0, 0, 0, 18, 64, 101, 26, 68, 0, 0, 0, 0, 0, 192, 48, 64,
    68, 0, 0, 0, 0, 0, 0, 18, 64, 102, 26, 67, 0, 0, 64, 65, 169, 26, 68, 0, 0, 0,
    0, 0, 0, 40, 64, 171, 26, 65, 12, 173, 26, 67, 0, 0, 64, 65, 175, 26, 68, 0,
    0, 0, 0, 0, 0, 40, 64, 177, 26, 65, 12, 179, 26, 66, 12, 181, 26, 65, 12, 184,
    26, 66, 12, 186, 26, 65, 255, 0, 192, 26, 65, 255, 255, 1, 193, 26, 66, 255,
    0, 194, 26, 66, 255, 255, 1, 195, 26, 66, 255, 255, 255, 255, 7, 196, 26, 67,
    0, 0, 64, 65, 252, 0, 26, 67, 0, 0, 64, 65, 252, 1, 26, 68, 0, 0, 0, 0, 0, 0,
    40, 64, 252, 2, 26, 68, 0, 0, 0, 0, 0, 0, 40, 64, 252, 3, 26, 67, 0, 0, 64, 65,
    252, 4, 26, 67, 0, 0, 64, 65, 252, 5, 26, 68, 0, 0, 0, 0, 0, 0, 40, 64, 252,
    6, 26, 68, 0, 0, 0, 0, 0, 0, 40, 64, 252, 7, 26, 2, 64, 65, 1, 14, 1, 0, 0, 11,
    2, 64, 0, 11, 65, 7, 34, 1, 26, 65, 11, 65, 150, 0, 65, 1, 28, 1, 127, 26, 32,
    0, 65, 231, 4, 16, 3, 32, 1, 16, 0, 26, 2, 64, 65, 0, 13, 0, 11, 3, 64, 65, 1,
    13, 0, 11, 65, 0, 4, 64, 2, 64, 12, 0, 11, 5, 1, 11, 32, 0, 11, 251, 6, 1, 1,
    125, 65, 0, 69, 26, 65, 11, 65, 3, 70, 26, 65, 11, 65, 3, 71, 26, 65, 11, 65,
    3, 72, 26, 65, 11, 65, 3, 73, 26, 65, 11, 65, 3, 74, 26, 65, 11, 65, 3, 75, 26,
    65, 11, 65, 3, 76, 26, 65, 11, 65, 3, 77, 26, 65, 11, 65, 3, 78, 26, 65, 11,
    65, 3, 79, 26, 65, 212, 0, 65, 3, 109, 26, 65, 212, 0, 65, 3, 110, 26, 65, 212,
    0, 65, 3, 111, 26, 65, 212, 0, 65, 3, 112, 26, 65, 212, 0, 65, 3, 116, 26, 65,
    212, 0, 65, 3, 117, 26, 65, 212, 0, 65, 3, 118, 26, 65, 212, 0, 65, 3, 119, 26,
    65, 212, 0, 65, 3, 120, 26, 66, 0, 80, 26, 66, 227, 0, 66, 5, 81, 26, 66, 227,
    0, 66, 5, 82, 26, 66, 227, 0, 66, 5, 83, 26, 66, 227, 0, 66, 5, 84, 26, 66, 227,
    0, 66, 5, 85, 26, 66, 227, 0, 66, 5, 86, 26, 66, 227, 0, 66, 5, 87, 26, 66, 227,
    0, 66, 5, 88, 26, 66, 227, 0, 66, 5, 89, 26, 66, 227, 0, 66, 5, 90, 26, 66, 227,
    0, 66, 5, 127, 26, 66, 227, 0, 66, 5, 128, 26, 66, 227, 0, 66, 5, 129, 26, 66,
    227, 0, 66, 5, 130, 26, 66, 227, 0, 66, 5, 134, 26, 66, 227, 0, 66, 5, 135, 26,
    66, 227, 0, 66, 5, 136, 26, 66, 227, 0, 66, 5, 137, 26, 66, 227, 0, 66, 5, 138,
    26, 67, 0, 0, 20, 65, 141, 26, 67, 0, 0, 20, 65, 142, 26, 67, 0, 0, 20, 65, 143,
    26, 67, 0, 0, 20, 65, 144, 26, 67, 0, 0, 20, 65, 145, 26, 67, 0, 0, 20, 65, 67,
    0, 0, 32, 64, 150, 26, 67, 0, 0, 20, 65, 67, 0, 0, 32, 64, 151, 26, 67, 0, 0,
    20, 65, 67, 0, 0, 32, 64, 152, 26, 67, 0, 0, 20, 65, 67, 0, 0, 32, 64, 91, 26,
    67, 0, 0, 20, 65, 67, 0, 0, 32, 64, 92, 26, 67, 0, 0, 20, 65, 67, 0, 0, 32, 64,
    93, 26, 67, 0, 0, 20, 65, 67, 0, 0, 32, 64, 94, 26, 67, 0, 0, 20, 65, 67, 0,
    0, 32, 64, 95, 26, 67, 0, 0, 20, 65, 67, 0, 0, 32, 64, 96, 26, 68, 0, 0, 0, 0,
    0, 192, 48, 64, 155, 26, 68, 0, 0, 0, 0, 0, 192, 48, 64, 156, 26, 68, 0, 0, 0,
    0, 0, 192, 48, 64, 157, 26, 68, 0, 0, 0, 0, 0, 192, 48, 64, 158, 26, 68, 0, 0,
    0, 0, 0, 192, 48, 64, 159, 26, 68, 0, 0, 0, 0, 0, 192, 48, 64, 68, 0, 0, 0, 0,
    0, 0, 18, 64, 164, 26, 68, 0, 0, 0, 0, 0, 192, 48, 64, 68, 0, 0, 0, 0, 0, 0,
    18, 64, 165, 26, 68, 0, 0, 0, 0, 0, 192, 48, 64, 68, 0, 0, 0, 0, 0, 0, 18, 64,
    166, 26, 68, 0, 0, 0, 0, 0, 192, 48, 64, 68, 0, 0, 0, 0, 0, 0, 18, 64, 97, 26,
    68, 0, 0, 0, 0, 0, 192, 48, 64, 68, 0, 0, 0, 0, 0, 0, 18, 64, 98, 26, 68, 0,
    0, 0, 0, 0, 192, 48, 64, 68, 0, 0, 0, 0, 0, 0, 18, 64, 99, 26, 68, 0, 0, 0, 0,
    0, 192, 48, 64, 68, 0, 0, 0, 0, 0, 0, 18, 64, 100, 26, 68, 0, 0, 0, 0, 0, 192,
    48, 64, 68, 0, 0, 0, 0, 0, 0, 18, 64, 101, 26, 68, 0, 0, 0, 0, 0, 192, 48, 64,
    68, 0, 0, 0, 0, 0, 0, 18, 64, 102, 26, 67, 0, 0, 64, 65, 169, 26, 68, 0, 0, 0,
    0, 0, 0, 40, 64, 171, 26, 65, 12, 173, 26, 67, 0, 0, 64, 65, 175, 26, 68, 0,
    0, 0, 0, 0, 0, 40, 64, 177, 26, 65, 12, 179, 26, 66, 12, 181, 26, 65, 12, 184,
    26, 66, 12, 186, 26, 65, 255, 0, 192, 26, 65, 255, 255, 1, 193, 26, 66, 255,
    0, 194, 26, 66, 255, 255, 1, 195, 26, 66, 255, 255, 255, 255, 7, 196, 26, 67,
    0, 0, 64, 65, 252, 0, 26, 67, 0, 0, 64, 65, 252, 1, 26, 68, 0, 0, 0, 0, 0, 0,
    40, 64, 252, 2, 26, 68, 0, 0, 0, 0, 0, 0, 40, 64, 252, 3, 26, 67, 0, 0, 64, 65,
    252, 4, 26, 67, 0, 0, 64, 65, 252, 5, 26, 68, 0, 0, 0, 0, 0, 0, 40, 64, 252,
    6, 26, 68, 0, 0, 0, 0, 0, 0, 40, 64, 252, 7, 26, 2, 64, 65, 1, 14, 1, 0, 0, 11,
    2, 64, 0, 11, 65, 7, 34, 1, 26, 65, 11, 65, 150, 0, 65, 1, 28, 1, 127, 26, 68,
    0, 0, 0, 0, 0, 0, 16, 64, 32, 1, 16, 2, 26, 2, 64, 65, 1, 13, 0, 11, 3, 64, 65,
    0, 13, 0, 11, 65, 0, 4, 64, 2, 64, 12, 0, 11, 5, 1, 11, 32, 0, 32, 1, 16, 0,
    32, 1, 16, 1, 11, 136, 7, 4, 1, 126, 2, 124, 1, 126, 1, 124, 65, 0, 69, 26, 65,
    11, 65, 3, 70, 26, 65, 11, 65, 3, 71, 26, 65, 11, 65, 3, 72, 26, 65, 11, 65,
    3, 73, 26, 65, 11, 65, 3, 74, 26, 65, 11, 65, 3, 75, 26, 65, 11, 65, 3, 76, 26,
    65, 11, 65, 3, 77, 26, 65, 11, 65, 3, 78, 26, 65, 11, 65, 3, 79, 26, 65, 212,
    0, 65, 3, 109, 26, 65, 212, 0, 65, 3, 110, 26, 65, 212, 0, 65, 3, 111, 26, 65,
    212, 0, 65, 3, 112, 26, 65, 212, 0, 65, 3, 116, 26, 65, 212, 0, 65, 3, 117, 26,
    65, 212, 0, 65, 3, 118, 26, 65, 212, 0, 65, 3, 119, 26, 65, 212, 0, 65, 3, 120,
    26, 66, 0, 80, 26, 66, 227, 0, 66, 5, 81, 26, 66, 227, 0, 66, 5, 82, 26, 66,
    227, 0, 66, 5, 83, 26, 66, 227, 0, 66, 5, 84, 26, 66, 227, 0, 66, 5, 85, 26,
    66, 227, 0, 66, 5, 86, 26, 66, 227, 0, 66, 5, 87, 26, 66, 227, 0, 66, 5, 88,
    26, 66, 227, 0, 66, 5, 89, 26, 66, 227, 0, 66, 5, 90, 26, 66, 227, 0, 66, 5,
    127, 26, 66, 227, 0, 66, 5, 128, 26, 66, 227, 0, 66, 5, 129, 26, 66, 227, 0,
    66, 5, 130, 26, 66, 227, 0, 66, 5, 134, 26, 66, 227, 0, 66, 5, 135, 26, 66, 227,
    0, 66, 5, 136, 26, 66, 227, 0, 66, 5, 137, 26, 66, 227, 0, 66, 5, 138, 26, 67,
    0, 0, 20, 65, 141, 26, 67, 0, 0, 20, 65, 142, 26, 67, 0, 0, 20, 65, 143, 26,
    67, 0, 0, 20, 65, 144, 26, 67, 0, 0, 20, 65, 145, 26, 67, 0, 0, 20, 65, 67, 0,
    0, 32, 64, 150, 26, 67, 0, 0, 20, 65, 67, 0, 0, 32, 64, 151, 26, 67, 0, 0, 20,
    65, 67, 0, 0, 32, 64, 152, 26, 67, 0, 0, 20, 65, 67, 0, 0, 32, 64, 91, 26, 67,
    0, 0, 20, 65, 67, 0, 0, 32, 64, 92, 26, 67, 0, 0, 20, 65, 67, 0, 0, 32, 64, 93,
    26, 67, 0, 0, 20, 65, 67, 0, 0, 32, 64, 94, 26, 67, 0, 0, 20, 65, 67, 0, 0, 32,
    64, 95, 26, 67, 0, 0, 20, 65, 67, 0, 0, 32, 64, 96, 26, 68, 0, 0, 0, 0, 0, 192,
    48, 64, 155, 26, 68, 0, 0, 0, 0, 0, 192, 48, 64, 156, 26, 68, 0, 0, 0, 0, 0,
    192, 48, 64, 157, 26, 68, 0, 0, 0, 0, 0, 192, 48, 64, 158, 26, 68, 0, 0, 0, 0,
    0, 192, 48, 64, 159, 26, 68, 0, 0, 0, 0, 0, 192, 48, 64, 68, 0, 0, 0, 0, 0, 0,
    18, 64, 164, 26, 68, 0, 0, 0, 0, 0, 192, 48, 64, 68, 0, 0, 0, 0, 0, 0, 18, 64,
    165, 26, 68, 0, 0, 0, 0, 0, 192, 48, 64, 68, 0, 0, 0, 0, 0, 0, 18, 64, 166, 26,
    68, 0, 0, 0, 0, 0, 192, 48, 64, 68, 0, 0, 0, 0, 0, 0, 18, 64, 97, 26, 68, 0,
    0, 0, 0, 0, 192, 48, 64, 68, 0, 0, 0, 0, 0, 0, 18, 64, 98, 26, 68, 0, 0, 0, 0,
    0, 192, 48, 64, 68, 0, 0, 0, 0, 0, 0, 18, 64, 99, 26, 68, 0, 0, 0, 0, 0, 192,
    48, 64, 68, 0, 0, 0, 0, 0, 0, 18, 64, 100, 26, 68, 0, 0, 0, 0, 0, 192, 48, 64,
    68, 0, 0, 0, 0, 0, 0, 18, 64, 101, 26, 68, 0, 0, 0, 0, 0, 192, 48, 64, 68, 0,
    0, 0, 0, 0, 0, 18, 64, 102, 26, 67, 0, 0, 64, 65, 169, 26, 68, 0, 0, 0, 0, 0,
    0, 40, 64, 171, 26, 65, 12, 173, 26, 67, 0, 0, 64, 65, 175, 26, 68, 0, 0, 0,
    0, 0, 0, 40, 64, 177, 26, 65, 12, 179, 26, 66, 12, 181, 26, 65, 12, 184, 26,
    66, 12, 186, 26, 65, 255, 0, 192, 26, 65, 255, 255, 1, 193, 26, 66, 255, 0, 194,
    26, 66, 255, 255, 1, 195, 26, 66, 255, 255, 255, 255, 7, 196, 26, 67, 0, 0, 64,
    65, 252, 0, 26, 67, 0, 0, 64, 65, 252, 1, 26, 68, 0, 0, 0, 0, 0, 0, 40, 64, 252,
    2, 26, 68, 0, 0, 0, 0, 0, 0, 40, 64, 252, 3, 26, 67, 0, 0, 64, 65, 252, 4, 26,
    67, 0, 0, 64, 65, 252, 5, 26, 68, 0, 0, 0, 0, 0, 0, 40, 64, 252, 6, 26, 68, 0,
    0, 0, 0, 0, 0, 40, 64, 252, 7, 26, 2, 64, 65, 1, 14, 1, 0, 0, 11, 2, 64, 0, 11,
    65, 7, 34, 1, 26, 65, 11, 65, 150, 0, 65, 1, 28, 1, 127, 26, 65, 1, 4, 124, 68,
    0, 0, 0, 0, 0, 0, 58, 64, 5, 68, 0, 0, 0, 0, 0, 0, 79, 64, 11, 32, 1, 16, 0,
    26, 2, 64, 65, 0, 13, 0, 11, 3, 64, 65, 0, 13, 0, 11, 65, 0, 4, 64, 2, 64, 12,
    0, 11, 5, 1, 11, 32, 0, 11, 244, 6, 3, 1, 125, 2, 127, 1, 125, 65, 0, 69, 26,
    65, 11, 65, 3, 70, 26, 65, 11, 65, 3, 71, 26, 65, 11, 65, 3, 72, 26, 65, 11,
    65, 3, 73, 26, 65, 11, 65, 3, 74, 26, 65, 11, 65, 3, 75, 26, 65, 11, 65, 3, 76,
    26, 65, 11, 65, 3, 77, 26, 65, 11, 65, 3, 78, 26, 65, 11, 65, 3, 79, 26, 65,
    212, 0, 65, 3, 109, 26, 65, 212, 0, 65, 3, 110, 26, 65, 212, 0, 65, 3, 111, 26,
    65, 212, 0, 65, 3, 112, 26, 65, 212, 0, 65, 3, 116, 26, 65, 212, 0, 65, 3, 117,
    26, 65, 212, 0, 65, 3, 118, 26, 65, 212, 0, 65, 3, 119, 26, 65, 212, 0, 65, 3,
    120, 26, 66, 0, 80, 26, 66, 227, 0, 66, 5, 81, 26, 66, 227, 0, 66, 5, 82, 26,
    66, 227, 0, 66, 5, 83, 26, 66, 227, 0, 66, 5, 84, 26, 66, 227, 0, 66, 5, 85,
    26, 66, 227, 0, 66, 5, 86, 26, 66, 227, 0, 66, 5, 87, 26, 66, 227, 0, 66, 5,
    88, 26, 66, 227, 0, 66, 5, 89, 26, 66, 227, 0, 66, 5, 90, 26, 66, 227, 0, 66,
    5, 127, 26, 66, 227, 0, 66, 5, 128, 26, 66, 227, 0, 66, 5, 129, 26, 66, 227,
    0, 66, 5, 130, 26, 66, 227, 0, 66, 5, 134, 26, 66, 227, 0, 66, 5, 135, 26, 66,
    227, 0, 66, 5, 136, 26, 66, 227, 0, 66, 5, 137, 26, 66, 227, 0, 66, 5, 138, 26,
    67, 0, 0, 20, 65, 141, 26, 67, 0, 0, 20, 65, 142, 26, 67, 0, 0, 20, 65, 143,
    26, 67, 0, 0, 20, 65, 144, 26, 67, 0, 0, 20, 65, 145, 26, 67, 0, 0, 20, 65, 67,
    0, 0, 32, 64, 150, 26, 67, 0, 0, 20, 65, 67, 0, 0, 32, 64, 151, 26, 67, 0, 0,
    20, 65, 67, 0, 0, 32, 64, 152, 26, 67, 0, 0, 20, 65, 67, 0, 0, 32, 64, 91, 26,
    67, 0, 0, 20, 65, 67, 0, 0, 32, 64, 92, 26, 67, 0, 0, 20, 65, 67, 0, 0, 32, 64,
    93, 26, 67, 0, 0, 20, 65, 67, 0, 0, 32, 64, 94, 26, 67, 0, 0, 20, 65, 67, 0,
    0, 32, 64, 95, 26, 67, 0, 0, 20, 65, 67, 0, 0, 32, 64, 96, 26, 68, 0, 0, 0, 0,
    0, 192, 48, 64, 155, 26, 68, 0, 0, 0, 0, 0, 192, 48, 64, 156, 26, 68, 0, 0, 0,
    0, 0, 192, 48, 64, 157, 26, 68, 0, 0, 0, 0, 0, 192, 48, 64, 158, 26, 68, 0, 0,
    0, 0, 0, 192, 48, 64, 159, 26, 68, 0, 0, 0, 0, 0, 192, 48, 64, 68, 0, 0, 0, 0,
    0, 0, 18, 64, 164, 26, 68, 0, 0, 0, 0, 0, 192, 48, 64, 68, 0, 0, 0, 0, 0, 0,
    18, 64, 165, 26, 68, 0, 0, 0, 0, 0, 192, 48, 64, 68, 0, 0, 0, 0, 0, 0, 18, 64,
    166, 26, 68, 0, 0, 0, 0, 0, 192, 48, 64, 68, 0, 0, 0, 0, 0, 0, 18, 64, 97, 26,
    68, 0, 0, 0, 0, 0, 192, 48, 64, 68, 0, 0, 0, 0, 0, 0, 18, 64, 98, 26, 68, 0,
    0, 0, 0, 0, 192, 48, 64, 68, 0, 0, 0, 0, 0, 0, 18, 64, 99, 26, 68, 0, 0, 0, 0,
    0, 192, 48, 64, 68, 0, 0, 0, 0, 0, 0, 18, 64, 100, 26, 68, 0, 0, 0, 0, 0, 192,
    48, 64, 68, 0, 0, 0, 0, 0, 0, 18, 64, 101, 26, 68, 0, 0, 0, 0, 0, 192, 48, 64,
    68, 0, 0, 0, 0, 0, 0, 18, 64, 102, 26, 67, 0, 0, 64, 65, 169, 26, 68, 0, 0, 0,
    0, 0, 0, 40, 64, 171, 26, 65, 12, 173, 26, 67, 0, 0, 64, 65, 175, 26, 68, 0,
    0, 0, 0, 0, 0, 40, 64, 177, 26, 65, 12, 179, 26, 66, 12, 181, 26, 65, 12, 184,
    26, 66, 12, 186, 26, 65, 255, 0, 192, 26, 65, 255, 255, 1, 193, 26, 66, 255,
    0, 194, 26, 66, 255, 255, 1, 195, 26, 66, 255, 255, 255, 255, 7, 196, 26, 67,
    0, 0, 64, 65, 252, 0, 26, 67, 0, 0, 64, 65, 252, 1, 26, 68, 0, 0, 0, 0, 0, 0,
    40, 64, 252, 2, 26, 68, 0, 0, 0, 0, 0, 0, 40, 64, 252, 3, 26, 67, 0, 0, 64, 65,
    252, 4, 26, 67, 0, 0, 64, 65, 252, 5, 26, 68, 0, 0, 0, 0, 0, 0, 40, 64, 252,
    6, 26, 68, 0, 0, 0, 0, 0, 0, 40, 64, 252, 7, 26, 2, 64, 65, 1, 14, 1, 0, 0, 11,
    2, 64, 0, 11, 65, 7, 34, 1, 26, 65, 11, 65, 150, 0, 65, 1, 28, 1, 127, 26, 32,
    0, 32, 1, 16, 3, 32, 1, 16, 0, 26, 2, 64, 65, 1, 13, 0, 11, 3, 64, 65, 0, 13,
    0, 11, 65, 0, 4, 64, 2, 64, 12, 0, 11, 5, 1, 11, 32, 0, 11, 0, 46, 4, 110, 97,
    109, 101, 0, 11, 10, 102, 122, 103, 95, 109, 111, 100, 117, 108, 101, 1, 12,
    1, 0, 9, 102, 122, 103, 95, 102, 117, 110, 99, 48, 4, 12, 1, 0, 9, 102, 122,
    103, 95, 116, 121, 112, 101, 48,
  ])
  let optimized = dae_run_module_pass(input, optimize=true)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 1)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 1)
  @debug.assert_eq(dae_test_func_params(optimized, 2).length(), 0)
  @debug.assert_eq(dae_test_func_params(optimized, 3).length(), 0)
}
