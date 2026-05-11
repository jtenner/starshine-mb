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
    #|  (func $f (param f64 f32)
    #|    nop)
    #|  (func (export "run")
    #|    i32.const 0
    #|    if (result f64)
    #|      f64.const 19
    #|    else
    #|      f64.const 2
    #|    end
    #|    i32.const 0
    #|    if (result f32)
    #|      f32.const 41
    #|    else
    #|      f32.const 51
    #|    end
    #|    call $f))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  let caller = optimized.pretty_print_defined_func(1U)
  assert_true(caller.contains("if"), msg=caller)
  assert_true(caller.contains("drop"), msg=caller)
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
