///|
fn dae_test_func_params(
  mod_ : @lib.Module,
  def_idx : Int,
) -> Array[@lib.ValType] {
  let type_idx = match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) => type_idxs[def_idx]
    None => abort("missing func section")
  }
  match (mod_.type_sec, type_idx) {
    (Some(@lib.TypeSec(rec_types)), @lib.TypeIdx(raw)) =>
      match rec_types[raw.reinterpret_as_int()] {
        @lib.SingleRecType(subtype) =>
          match subtype.get_comptype() {
            @lib.FuncCompType(params, _) => params
            _ => abort("expected func type")
          }
        @lib.GroupRecType(_) => abort("unexpected group type")
      }
    _ => abort("missing concrete type")
  }
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
