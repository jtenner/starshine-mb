///|
fn inl_test_run(
  text : String,
  pass_name? : String = "inlining-optimizing",
) -> @lib.Module {
  match pass_test_run_pipeline(text, [pass_name]) {
    Ok(mod_) => mod_
    Err(err) => abort("expected inlining pipeline success, got \{err}")
  }
}

///|
test "inlining-optimizing is an active module pass under canonical and plain names" {
  @debug.assert_eq(
    pass_registry_category("inlining-optimizing"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("inlining"),
    Some(HotPassRegistryCategory::module_pass()),
  )
}

///|
test "inlining-optimizing inlines tiny no-param callees and removes dead helpers" {
  let source =
    #|(module
    #|  (func $tiny (result i32)
    #|    i32.const 7)
    #|  (func (export "run") (result i32)
    #|    call $tiny))
  let optimized = inl_test_run(source)
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("i32.const I32(7)"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected func section")
  }
}

///|
test "inlining-optimizing stores call operands into remapped callee params" {
  let source =
    #|(module
    #|  (func $add1 (param i32) (result i32)
    #|    local.get 0
    #|    i32.const 1
    #|    i32.add)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $add1))
  let optimized = inl_test_run(source, pass_name="inlining")
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("local.set"), msg=caller)
  assert_true(caller.contains("i32.add"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
}

///|
test "inlining-optimizing can inline exported tiny helpers without deleting them" {
  let source =
    #|(module
    #|  (func $tiny (export "tiny") (result i32)
    #|    i32.const 11)
    #|  (func (export "run") (result i32)
    #|    call $tiny))
  let optimized = inl_test_run(source)
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  let caller = optimized.pretty_print_defined_func(1U)
  assert_true(caller.contains("i32.const I32(11)"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
}

///|
test "inlining inlines tiny return_call callees" {
  let source =
    #|(module
    #|  (func $tiny (result i32)
    #|    i32.const 7)
    #|  (func (export "run") (result i32)
    #|    return_call $tiny))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected func section")
  }
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("i32.const I32(7)"), msg=caller)
  assert_false(caller.contains("return_call"), msg=caller)
}

///|
test "inlining-optimizing skips self-recursive calls" {
  let source =
    #|(module
    #|  (func $loop (export "run") (result i32)
    #|    call $loop))
  let optimized = inl_test_run(source)
  let func = optimized.pretty_print_defined_func(0U)
  assert_true(func.contains("call"), msg=func)
}

///|
test "inlining iterates after same-wave inline-into and inline-from races" {
  let source =
    #|(module
    #|  (func $leaf (result i32)
    #|    i32.const 5)
    #|  (func $mid (export "mid") (result i32)
    #|    call $leaf)
    #|  (func (export "run") (result i32)
    #|    call $mid))
  let optimized = inl_test_run(source, pass_name="inlining")
  let mid = optimized.pretty_print_defined_func(0U)
  let run = optimized.pretty_print_defined_func(1U)
  assert_false(mid.contains("call"), msg=mid)
  assert_false(run.contains("call"), msg=run)
}

///|
test "inlining-optimizing removes unreachable private cycles reached only from dead suffixes" {
  let source =
    #|(module
    #|  (func $run (export "run")
    #|    block unreachable end
    #|    call $b)
    #|  (func $b
    #|    block unreachable end
    #|    call $c)
    #|  (func $c
    #|    block unreachable end
    #|    call $b))
  let optimized = inl_test_run(source)
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected func section")
  }
}

///|
test "inlining-optimizing removes self-looping unreachable private cycles" {
  let source =
    #|(module
    #|  (func $run (export "run") (param i32) (result f64)
    #|    block unreachable end
    #|    local.get 0
    #|    call $b)
    #|  (func $a (param i32) (result f64)
    #|    block unreachable end
    #|    local.get 0
    #|    call $b
    #|    drop
    #|    local.get 0
    #|    call $run)
    #|  (func $b (param i32) (result f64)
    #|    block unreachable end
    #|    local.get 0
    #|    call $a
    #|    drop
    #|    local.get 0
    #|    call $b))
  let optimized = inl_test_run(source)
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected func section")
  }
}

///|
test "inlining-optimizing keeps uncalled unreachable helpers with duplicate signatures" {
  let source =
    #|(module
    #|  (type $a (func (result i32)))
    #|  (type $b (func (result i32)))
    #|  (func $tiny (type $a)
    #|    i32.const 1)
    #|  (func $dead_a (type $a)
    #|    unreachable)
    #|  (func $dead_b (type $b)
    #|    unreachable)
    #|  (func (export "run") (type $a)
    #|    call $tiny))
  let optimized = inl_test_run(source)
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 3)
    None => fail("expected func section")
  }
}

///|
test "inlining-optimizing keeps non-inlined unreachable duplicate of exported signature" {
  let source =
    #|(module
    #|  (func $tiny (result i32)
    #|    i32.const 1)
    #|  (func $dead_same (result i32)
    #|    unreachable)
    #|  (func $dead_other (param i64)
    #|    unreachable)
    #|  (func (export "run") (result i32)
    #|    call $tiny))
  let optimized = inl_test_run(source)
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 3)
    None => fail("expected func section")
  }
}

///|
test "inlining-optimizing collapses pure terminal-unreachable roots after cleanup" {
  let source =
    #|(module
    #|  (func $tiny (result i32)
    #|    i32.const 1)
    #|  (func (export "run") (result i64)
    #|    i32.const 0
    #|    i32.eqz
    #|    drop
    #|    (block
    #|      (br_table 0 0 (i32.const 1)))
    #|    unreachable)
    #|  (func (export "touch") (result i32)
    #|    call $tiny))
  let optimized = inl_test_run(source)
  let run = optimized.pretty_print_defined_func(0U)
  @debug.assert_eq(run.contains("drop"), false, msg=run)
  assert_true(run.contains("unreachable"), msg=run)
}

///|
test "inlining-optimizing trims duplicate exact-unreachable helper behind used self-loop signature" {
  let source =
    #|(module
    #|  (func $tiny (result i32)
    #|    i32.const 1)
    #|  (func $run (export "run") (result i32)
    #|    call $tiny
    #|    drop
    #|    block unreachable end
    #|    call $a)
    #|  (func $a (result i32)
    #|    block unreachable end
    #|    call $b
    #|    drop
    #|    call $run)
    #|  (func $b (result i32)
    #|    block unreachable end
    #|    call $a)
    #|  (func $self (result i32)
    #|    block unreachable end
    #|    call $self))
  let optimized = inl_test_run(source)
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 3)
    None => fail("expected func section")
  }
  let run = optimized.pretty_print_defined_func(0U)
  let helper = optimized.pretty_print_defined_func(1U)
  let self = optimized.pretty_print_defined_func(2U)
  assert_true(run.contains("unreachable"), msg=run)
  assert_true(helper.contains("unreachable"), msg=helper)
  assert_true(self.contains("call"), msg=self)
}

///|
test "inlining-optimizing retains the result helper reached through a void root cycle" {
  let source =
    #|(module
    #|  (type $root (func (result i64)))
    #|  (type $void (func))
    #|  (type $helper (func (result f32)))
    #|  (func $tiny (result i64)
    #|    i64.const 1)
    #|  (func $run (export "run") (type $root)
    #|    call $tiny
    #|    drop
    #|    block unreachable end
    #|    call $void)
    #|  (func $void (type $void)
    #|    block unreachable end
    #|    call $helper
    #|    drop)
    #|  (func $helper (type $helper)
    #|    block unreachable end
    #|    call $run
    #|    drop
    #|    f32.const 0)
    #|  (func $shadow (type $root)
    #|    block unreachable end
    #|    call $run
    #|    drop
    #|    call $helper
    #|    drop
    #|    call $run))
  let optimized = inl_test_run(source)
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 3)
    None => fail("expected func section")
  }
  let helper = optimized.pretty_print_defined_func(1U)
  assert_true(helper.contains("results: [F32]"), msg=helper)
  assert_true(helper.contains("unreachable"), msg=helper)
}

///|
test "inlining-optimizing retains one private cycle helper behind self-looping root" {
  let source =
    #|(module
    #|  (type $root (func (result i64)))
    #|  (type $helper (func (param i32) (result i32)))
    #|  (func $run (export "main") (type $root)
    #|    block unreachable end
    #|    i32.const 0
    #|    call $b2
    #|    drop
    #|    call $run)
    #|  (func $b1 (type $helper)
    #|    block unreachable end
    #|    local.get 0
    #|    call $b2
    #|    drop
    #|    local.get 0)
    #|  (func $b2 (type $helper)
    #|    block unreachable end
    #|    call $a2
    #|    drop
    #|    local.get 0)
    #|  (func $a2 (type $root)
    #|    block unreachable end
    #|    i32.const 0
    #|    call $b1
    #|    drop
    #|    i64.const 0))
  let optimized = inl_test_run(source)
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  let run = optimized.pretty_print_defined_func(0U)
  let helper = optimized.pretty_print_defined_func(1U)
  assert_true(run.contains("unreachable"), msg=run)
  assert_true(helper.contains("params: [I32]"), msg=helper)
  assert_true(helper.contains("results: [I32]"), msg=helper)
  assert_true(helper.contains("unreachable"), msg=helper)
}

///|
test "inlining-optimizing final-trims root-signature duplicate from private self-loop SCC" {
  let source =
    #|(module
    #|  (type $root (func (param i64 f32) (result f64)))
    #|  (type $void (func))
    #|  (func $run (export "main") (type $root)
    #|    block unreachable end
    #|    local.get 0
    #|    local.get 1
    #|    call $c)
    #|  (func $b (type $void)
    #|    block unreachable end
    #|    i64.const 0
    #|    f32.const 0
    #|    call $a
    #|    drop)
    #|  (func $a (type $root)
    #|    block unreachable end
    #|    local.get 0
    #|    local.get 1
    #|    call $run
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    call $a)
    #|  (func $c (type $root)
    #|    block unreachable end
    #|    call $b
    #|    f64.const 0))
  let optimized = inl_test_run(source)
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
}

///|
test "inlining-optimizing final-trims shadowed non-root self-loop helper" {
  let source =
    #|(module
    #|  (type $root (func (param f32 i64) (result f64)))
    #|  (type $helper (func (param i32) (result f32)))
    #|  (func $run (export "main") (type $root)
    #|    block unreachable end
    #|    i32.const 0
    #|    call $b2
    #|    drop
    #|    f64.const 0)
    #|  (func $b1 (type $helper)
    #|    block unreachable end
    #|    i32.const 0
    #|    call $b1
    #|    f32.const 0
    #|    i64.const 0
    #|    call $run
    #|    drop)
    #|  (func $b2 (type $helper)
    #|    block unreachable end
    #|    local.get 0
    #|    call $b1
    #|    drop
    #|    f32.const 0)
    #|  (func $shadow (type $root)
    #|    block unreachable end
    #|    i32.const 0
    #|    call $b1
    #|    drop
    #|    f64.const 0))
  let optimized = inl_test_run(source)
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
}

///|
test "inlining-optimizing emits nested cleanup trace for touched functions" {
  let source =
    #|(module
    #|  (func $tiny (result i32)
    #|    i32.const 1)
    #|  (func (export "run") (result i32)
    #|    call $tiny))
  let trace = match pass_test_capture_trace(source, ["inlining-optimizing"]) {
    Ok(trace) => trace
    Err(err) => fail("expected traced inlining success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[inlining-optimizing]:nested-cleanup")
    }),
    msg=trace.to_string(),
  )
}
