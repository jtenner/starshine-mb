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
fn dae_test_many_i32_locals(count : Int) -> String {
  let out = StringBuilder::new()
  for i = 0; i < count; i = i + 1 {
    out.write_string(" (local i32)")
  }
  out.to_string()
}

///|
fn dae_test_many_i32_const_drops(count : Int) -> String {
  let out = StringBuilder::new()
  for i = 0; i < count; i = i + 1 {
    out.write_string("\n    i32.const 0\n    drop")
  }
  out.to_string()
}

///|
fn dae_test_call_ref_fixture() -> @lib.Module {
  let call_ref_type = @lib.TypeIdx::new(0U)
  let f_type = @lib.TypeIdx::new(1U)
  let run_type = @lib.TypeIdx::new(2U)
  let call_ref_sig = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let f_sig = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let run_sig = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([call_ref_sig, f_sig, run_sig]))
  .with_func_sec(@lib.FuncSec::new([call_ref_type, f_type, run_type]))
  .with_table_sec(
    @lib.TableSec::new([
      @lib.Table::new(
        @lib.TableType::new(
          @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::func())),
          @lib.Limits::i32(1U, Some(1U)),
        ),
        None,
      ),
    ]),
  )
  .with_elem_sec(
    @lib.ElemSec::new([
      @lib.Elem::new(
        @lib.ElemMode::active(
          @lib.TableIdx::new(0U),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
        ),
        @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
      ),
    ]),
  )
  .with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::from_string("run"),
        @lib.ExternIdx::func(@lib.FuncIdx::new(2U)),
      ),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(7))]),
      ),
      @lib.Func::new(
        @lib.Locals::from_types([
          @lib.ValType::ref_type(
            @lib.RefType::new(true, @lib.HeapType::new(call_ref_type)),
          ),
        ]),
        @lib.Expr::new([
          @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::call_ref(call_ref_type),
        ]),
      ),
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(99)),
          @lib.Instruction::call(@lib.FuncIdx::new(1U)),
        ]),
      ),
    ]),
  )
}

///|
fn dae_test_call_ref_declarative_fixture() -> @lib.Module {
  let call_ref_type = @lib.TypeIdx::new(0U)
  let f_type = @lib.TypeIdx::new(1U)
  let run_type = @lib.TypeIdx::new(2U)
  let call_ref_sig = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let f_sig = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let run_sig = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([call_ref_sig, f_sig, run_sig]))
  .with_func_sec(@lib.FuncSec::new([call_ref_type, f_type, run_type]))
  .with_table_sec(
    @lib.TableSec::new([
      @lib.Table::new(
        @lib.TableType::new(
          @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::func())),
          @lib.Limits::i32(1U, Some(1U)),
        ),
        None,
      ),
    ]),
  )
  .with_elem_sec(
    @lib.ElemSec::new([
      @lib.Elem::new(
        @lib.ElemMode::declarative(),
        @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
      ),
    ]),
  )
  .with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::from_string("run"),
        @lib.ExternIdx::func(@lib.FuncIdx::new(2U)),
      ),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(7))]),
      ),
      @lib.Func::new(
        @lib.Locals::from_types([
          @lib.ValType::ref_type(
            @lib.RefType::new(true, @lib.HeapType::new(call_ref_type)),
          ),
        ]),
        @lib.Expr::new([
          @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::call_ref(call_ref_type),
        ]),
      ),
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(99)),
          @lib.Instruction::call(@lib.FuncIdx::new(1U)),
        ]),
      ),
    ]),
  )
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
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    i32.const 20
    #|    call $f))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 1)
  let @lib.Func(callee_locals, _) = dae_test_defined_func(optimized, 0)
  @debug.assert_eq(callee_locals.length(), 0)
  let caller = optimized.pretty_print_defined_func(1U)
  assert_true(caller.contains("(call (Func 0))"), msg=caller)
  assert_true(caller.contains("local.get (Local 0)"), msg=caller)
  assert_false(caller.contains("i32.const I32(20)"), msg=caller)
}

///|
test "dae-optimizing materializes shared constant actuals into private callee params" {
  let source =
    #|(module
    #|  (func $f (param i32 i32 i32)
    #|    local.get 0
    #|    local.get 2
    #|    i32.le_s
    #|    if
    #|      local.get 0
    #|      local.get 1
    #|      i32.ge_s
    #|      if
    #|      else
    #|        unreachable
    #|      end
    #|    else
    #|      unreachable
    #|    end)
    #|  (func (export "run1")
    #|    i32.const 10
    #|    i32.const 0
    #|    i32.const 20
    #|    call $f)
    #|  (func (export "run2")
    #|    i32.const 5
    #|    i32.const 0
    #|    i32.const 6
    #|    call $f))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 2)
  let callee = optimized.pretty_print_defined_func(0U)
  let caller1 = optimized.pretty_print_defined_func(1U)
  assert_true(callee.contains("I32(0)"), msg=callee)
  assert_false(callee.contains("Local2"), msg=callee)
  assert_false(caller1.contains("i32.const I32(0)"), msg=caller1)
}

///|
test "dae-optimizing materializes shared constant actuals when sibling args use loads" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $f (param i32 i32 i32)
    #|    local.get 0
    #|    local.get 2
    #|    i32.le_s
    #|    if
    #|      local.get 0
    #|      local.get 1
    #|      i32.ge_s
    #|      if
    #|      else
    #|        unreachable
    #|      end
    #|    else
    #|      unreachable
    #|    end)
    #|  (func (export "run1")
    #|    i32.const 0
    #|    i32.load
    #|    i32.const 0
    #|    i32.const 20
    #|    call $f)
    #|  (func (export "run2")
    #|    i32.const 4
    #|    i32.load
    #|    i32.const 0
    #|    i32.const 21
    #|    call $f))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 2)
  let callee = optimized.pretty_print_defined_func(0U)
  assert_true(callee.contains("I32(0)"), msg=callee)
  assert_false(callee.contains("Local2"), msg=callee)
}

///|
test "dae-optimizing materializes shared constant actuals through typed block carriers" {
  let source =
    #|(module
    #|  (type $one (func (result i32)))
    #|  (func $f (param i32 i32 i32)
    #|    local.get 0
    #|    local.get 2
    #|    i32.le_s
    #|    if
    #|      local.get 0
    #|      local.get 1
    #|      i32.ge_s
    #|      if
    #|      else
    #|        unreachable
    #|      end
    #|    else
    #|      unreachable
    #|    end)
    #|  (func (export "run1")
    #|    block (type $one)
    #|      i32.const 10
    #|    end
    #|    i32.const 0
    #|    block (type $one)
    #|      i32.const 20
    #|    end
    #|    call $f)
    #|  (func (export "run2")
    #|    block (type $one)
    #|      i32.const 5
    #|    end
    #|    i32.const 0
    #|    block (type $one)
    #|      i32.const 21
    #|    end
    #|    call $f))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 2)
  let callee = optimized.pretty_print_defined_func(0U)
  assert_true(callee.contains("I32(0)"), msg=callee)
  assert_false(callee.contains("Local2"), msg=callee)
}

///|
test "dae-optimizing materializes shared constant actuals through loop-carried ambient args" {
  let source =
    #|(module
    #|  (type $loop1 (func (param i32) (result i32)))
    #|  (func $check (param i32 i32 i32) (result i32)
    #|    local.get 0
    #|    local.get 2
    #|    i32.le_s
    #|    if
    #|      local.get 0
    #|      local.get 1
    #|      i32.ge_s
    #|      if
    #|      else
    #|        unreachable
    #|      end
    #|    else
    #|      unreachable
    #|    end
    #|    i32.const 0)
    #|  (func (export "run1") (result i32) (local i32 i32)
    #|    i32.const 10
    #|    loop (type $loop1)
    #|      local.tee 0
    #|      local.tee 1
    #|      i32.const 0
    #|      i32.const 20
    #|      call $check
    #|      drop
    #|      i32.const 0
    #|    end)
    #|  (func (export "run2") (result i32) (local i32 i32)
    #|    i32.const 5
    #|    loop (type $loop1)
    #|      local.tee 0
    #|      local.tee 1
    #|      i32.const 0
    #|      i32.const 21
    #|      call $check
    #|      drop
    #|      i32.const 0
    #|    end))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 2)
  let callee = optimized.pretty_print_defined_func(0U)
  assert_true(callee.contains("I32(0)"), msg=callee)
  assert_false(callee.contains("Local2"), msg=callee)
}

///|
test "dae-optimizing rewrites every direct call when a caller hits the same callee twice" {
  let source =
    #|(module
    #|  (func $check (param i32 i32 i32) (result i32)
    #|    local.get 0
    #|    local.get 2
    #|    i32.le_s
    #|    if
    #|      local.get 0
    #|      local.get 1
    #|      i32.ge_s
    #|      if
    #|      else
    #|        unreachable
    #|      end
    #|    else
    #|      unreachable
    #|    end
    #|    i32.const 0)
    #|  (func (export "run1")
    #|    i32.const 10
    #|    i32.const 0
    #|    i32.const 20
    #|    call $check
    #|    drop
    #|    i32.const 11
    #|    i32.const 0
    #|    i32.const 21
    #|    call $check
    #|    drop)
    #|  (func (export "run2")
    #|    i32.const 5
    #|    i32.const 0
    #|    i32.const 22
    #|    call $check
    #|    drop
    #|    i32.const 6
    #|    i32.const 0
    #|    i32.const 23
    #|    call $check
    #|    drop))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 2)
  let callee = optimized.pretty_print_defined_func(0U)
  assert_true(callee.contains("I32(0)"), msg=callee)
  assert_false(callee.contains("Local2"), msg=callee)
  assert_true(callee.contains("i32.lt_s"), msg=callee)
  assert_false(callee.contains("i32.eqz"), msg=callee)
  assert_false(callee.contains("i32.ge_s"), msg=callee)
}

///|
test "dae-optimizing can recover a later exact-literal candidate after the eight core iterations" {
  let source =
    #|(module
    #|  (func $g0 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $g1 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $g2 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $g3 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $g4 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $g5 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $g6 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $g7 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $g8 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $check (param i32 i32 i32)
    #|    local.get 0
    #|    local.get 2
    #|    i32.le_s
    #|    if
    #|      local.get 0
    #|      local.get 1
    #|      i32.ge_s
    #|      if
    #|      else
    #|        unreachable
    #|      end
    #|    else
    #|      unreachable
    #|    end)
    #|  (func (export "run1")
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g0
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g1
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g2
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g3
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g4
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g5
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g6
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g7
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g8
    #|    i32.const 10
    #|    i32.const 0
    #|    i32.const 20
    #|    call $check)
    #|  (func (export "run2")
    #|    i32.const 5
    #|    i32.const 0
    #|    i32.const 21
    #|    call $check))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  @debug.assert_eq(dae_test_func_params(optimized, 7).length(), 0)
  @debug.assert_eq(dae_test_func_params(optimized, 8).length(), 2)
  @debug.assert_eq(dae_test_func_params(optimized, 9).length(), 2)
  let trace = match pass_test_capture_trace(source, ["dae-optimizing"]) {
    Ok(trace) => trace
    Err(err) => fail("expected traced DAE success, got \{err}")
  }
  let core_trace : Array[String] = []
  let reverse_trace : Array[String] = []
  for line in trace {
    if line.contains("pass[dae-optimizing]:core") {
      core_trace.push(line)
    }
    if line.contains("pass[dae-optimizing]:reverse-exact-literal") {
      reverse_trace.push(line)
    }
  }
  @debug.assert_eq(core_trace, [
    "pass[dae-optimizing]:core iter=0 primary_def=0", "pass[dae-optimizing]:core iter=1 primary_def=1",
    "pass[dae-optimizing]:core iter=2 primary_def=2", "pass[dae-optimizing]:core iter=3 primary_def=3",
    "pass[dae-optimizing]:core iter=4 primary_def=4", "pass[dae-optimizing]:core iter=5 primary_def=5",
    "pass[dae-optimizing]:core iter=6 primary_def=6", "pass[dae-optimizing]:core iter=7 primary_def=7",
  ])
  @debug.assert_eq(reverse_trace, [
    "pass[dae-optimizing]:reverse-exact-literal iter=0 primary_def=9",
  ])
}

///|
test "dae-optimizing can chase a later exact-literal forwarding-wrapper chain" {
  let source =
    #|(module
    #|  (func $g0 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $g1 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $g2 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $g3 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $g4 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $g5 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $g6 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $g7 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $check (param i32 i32 i32) (result i32)
    #|    local.get 0
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2)
    #|  (func $wrap2 (param i32 i32 i32) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    call $check)
    #|  (func $wrap1 (param i32 i32 i32) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    call $wrap2)
    #|  (func (export "run1")
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g0
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g1
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g2
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g3
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g4
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g5
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g6
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g7
    #|    i32.const 10
    #|    i32.const 0
    #|    i32.const 20
    #|    call $wrap1
    #|    drop)
    #|  (func (export "run2")
    #|    i32.const 5
    #|    i32.const 0
    #|    i32.const 21
    #|    call $wrap1
    #|    drop))
  let optimized = dae_test_run(source)
  let trace = match pass_test_capture_trace(source, ["dae-optimizing"]) {
    Ok(trace) => trace
    Err(err) => fail("expected traced DAE success, got \{err}")
  }
  let reverse_trace : Array[String] = []
  for line in trace {
    if line.contains("pass[dae-optimizing]:reverse-exact-literal") {
      reverse_trace.push(line)
    }
  }
  @debug.assert_eq(reverse_trace, [
    "pass[dae-optimizing]:reverse-exact-literal iter=0 primary_def=10", "pass[dae-optimizing]:reverse-exact-literal iter=1 primary_def=9",
    "pass[dae-optimizing]:reverse-exact-literal iter=2 primary_def=8",
  ])
  @debug.assert_eq(dae_test_func_params(optimized, 8).length(), 2)
  @debug.assert_eq(dae_test_func_params(optimized, 9).length(), 2)
  @debug.assert_eq(dae_test_func_params(optimized, 10).length(), 2)
}

///|
test "dae-optimizing revisits wrapper boundaries for unread callee params" {
  for boundary_def in [128, 131, 133] {
    let out = StringBuilder::new()
    out.write_string("(module\n")
    for i = 0; i < 8; i = i + 1 {
      out.write_string(
        "  (func $g\{i} (param i32 i32)\n    local.get 0\n    drop)\n",
      )
    }
    for i = 8; i < boundary_def; i = i + 1 {
      out.write_string("  (func $pad\{i})\n")
    }
    out.write_string(
      (
        #|  (func $wrap (export "wrap") (param i32 i32 i32 i32) (result i32)
        #|    local.get 1
        #|    local.get 2
        #|    local.get 3
        #|    call $target)
        #|  (func $target (param i32 i32 i32) (result i32)
        #|    local.get 0
        #|    local.get 1
        #|    i32.add)
        #|  (func (export "run")
      ),
    )
    for i = 0; i < 8; i = i + 1 {
      out.write_string("    i32.const 1\n    i32.const 2\n    call $g\{i}\n")
    }
    out.write_string("  )\n)")
    let source = out.to_string()
    let optimized = dae_test_run(source)
    @debug.assert_eq(
      dae_test_func_params(optimized, boundary_def + 1).length(),
      2,
    )
    let trace = match pass_test_capture_trace(source, ["dae-optimizing"]) {
      Ok(trace) => trace
      Err(err) => fail("expected traced DAE success, got \{err}")
    }
    assert_true(
      trace.contains(
        "pass[dae-optimizing]:boundary-wrapper-callee-core wrapper_def=\{boundary_def} primary_def=\{boundary_def + 1}",
      ),
      msg=trace.to_string(),
    )
  }
}

///|
test "dae-optimizing folds add-zero address drift after removing a const memory.copy offset param" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $copy (param i32 i32 i32) (result i32)
    #|    i32.const 8
    #|    local.get 0
    #|    i32.add
    #|    local.get 1
    #|    i32.add
    #|    i32.const 16
    #|    local.get 0
    #|    i32.add
    #|    local.get 1
    #|    i32.add
    #|    local.get 2
    #|    memory.copy
    #|    local.get 0)
    #|  (func $a (param i32 i32) (result i32)
    #|    local.get 0
    #|    i32.const 0
    #|    local.get 1
    #|    call $copy)
    #|  (func $b (param i32 i32) (result i32)
    #|    local.get 0
    #|    i32.const 0
    #|    local.get 1
    #|    call $copy)
    #|  (func (export "run") (result i32)
    #|    i32.const 32
    #|    i32.const 4
    #|    call $a
    #|    drop
    #|    i32.const 64
    #|    i32.const 8
    #|    call $b))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 2)
  let callee = optimized.pretty_print_defined_func(0U)
  assert_false(callee.contains("i32.add(i32.const I32(0))"), msg=callee)
  assert_false(callee.contains("(i32.const I32(0))i32.add"), msg=callee)
}

///|
test "dae-optimizing materializes forwarded const actuals before a reverse-starved wrapper chain" {
  let source =
    #|(module
    #|  (func $g0 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $g1 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $g2 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $g3 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $g4 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $g5 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $check (param i32 i32 i32) (result i32)
    #|    local.get 0
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2)
    #|  (func $wrap2 (param i32 i32 i32) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    call $check)
    #|  (func $wrap1 (param i32 i32 i32) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    call $wrap2)
    #|  (func $h0 (param i32 i32 i32) (result i32)
    #|    local.get 0
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2)
    #|  (func $h1 (param i32 i32 i32) (result i32)
    #|    local.get 0
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2)
    #|  (func $h2 (param i32 i32 i32) (result i32)
    #|    local.get 0
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2)
    #|  (func $h3 (param i32 i32 i32) (result i32)
    #|    local.get 0
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2)
    #|  (func $h4 (param i32 i32 i32) (result i32)
    #|    local.get 0
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2)
    #|  (func $h5 (param i32 i32 i32) (result i32)
    #|    local.get 0
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2)
    #|  (func $h6 (param i32 i32 i32) (result i32)
    #|    local.get 0
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2)
    #|  (func $h7 (param i32 i32 i32) (result i32)
    #|    local.get 0
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2)
    #|  (func $h8 (param i32 i32 i32) (result i32)
    #|    local.get 0
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2)
    #|  (func (export "run1")
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g0
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g1
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g2
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g3
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g4
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g5
    #|    i32.const 10
    #|    i32.const 0
    #|    i32.const 20
    #|    call $wrap1
    #|    drop
    #|    i32.const 30
    #|    i32.const 0
    #|    i32.const 40
    #|    call $h0
    #|    drop
    #|    i32.const 31
    #|    i32.const 0
    #|    i32.const 41
    #|    call $h1
    #|    drop
    #|    i32.const 32
    #|    i32.const 0
    #|    i32.const 42
    #|    call $h2
    #|    drop
    #|    i32.const 33
    #|    i32.const 0
    #|    i32.const 43
    #|    call $h3
    #|    drop
    #|    i32.const 34
    #|    i32.const 0
    #|    i32.const 44
    #|    call $h4
    #|    drop
    #|    i32.const 35
    #|    i32.const 0
    #|    i32.const 45
    #|    call $h5
    #|    drop
    #|    i32.const 36
    #|    i32.const 0
    #|    i32.const 46
    #|    call $h6
    #|    drop
    #|    i32.const 37
    #|    i32.const 0
    #|    i32.const 47
    #|    call $h7
    #|    drop
    #|    i32.const 38
    #|    i32.const 0
    #|    i32.const 48
    #|    call $h8
    #|    drop)
    #|  (func (export "run2")
    #|    i32.const 5
    #|    i32.const 0
    #|    i32.const 21
    #|    call $wrap1
    #|    drop
    #|    i32.const 50
    #|    i32.const 0
    #|    i32.const 60
    #|    call $h0
    #|    drop
    #|    i32.const 51
    #|    i32.const 0
    #|    i32.const 61
    #|    call $h1
    #|    drop
    #|    i32.const 52
    #|    i32.const 0
    #|    i32.const 62
    #|    call $h2
    #|    drop
    #|    i32.const 53
    #|    i32.const 0
    #|    i32.const 63
    #|    call $h3
    #|    drop
    #|    i32.const 54
    #|    i32.const 0
    #|    i32.const 64
    #|    call $h4
    #|    drop
    #|    i32.const 55
    #|    i32.const 0
    #|    i32.const 65
    #|    call $h5
    #|    drop
    #|    i32.const 56
    #|    i32.const 0
    #|    i32.const 66
    #|    call $h6
    #|    drop
    #|    i32.const 57
    #|    i32.const 0
    #|    i32.const 67
    #|    call $h7
    #|    drop
    #|    i32.const 58
    #|    i32.const 0
    #|    i32.const 68
    #|    call $h8
    #|    drop))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 6).length(), 2)
  let trace = match pass_test_capture_trace(source, ["dae-optimizing"]) {
    Ok(trace) => trace
    Err(err) => fail("expected traced DAE success, got \{err}")
  }
  assert_true(
    trace.contains("pass[dae-optimizing]:core iter=6 primary_def=6"),
    msg=trace.to_string(),
  )
}

///|
test "dae-optimizing revisits low forwarded-const candidates after the reverse-starved core budget" {
  let source =
    #|(module
    #|  (func $g0 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $g1 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $g2 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $g3 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $g4 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $g5 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $g6 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $g7 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $g8 (param i32 i32)
    #|    local.get 0
    #|    drop)
    #|  (func $check (param i32 i32 i32) (result i32)
    #|    local.get 0
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2)
    #|  (func $wrap2 (param i32 i32 i32) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    call $check)
    #|  (func $wrap1 (param i32 i32 i32) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    call $wrap2)
    #|  (func $h0 (param i32 i32 i32) (result i32)
    #|    local.get 0
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2)
    #|  (func $h1 (param i32 i32 i32) (result i32)
    #|    local.get 0
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2)
    #|  (func $h2 (param i32 i32 i32) (result i32)
    #|    local.get 0
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2)
    #|  (func $h3 (param i32 i32 i32) (result i32)
    #|    local.get 0
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2)
    #|  (func $h4 (param i32 i32 i32) (result i32)
    #|    local.get 0
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2)
    #|  (func $h5 (param i32 i32 i32) (result i32)
    #|    local.get 0
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2)
    #|  (func $h6 (param i32 i32 i32) (result i32)
    #|    local.get 0
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2)
    #|  (func $h7 (param i32 i32 i32) (result i32)
    #|    local.get 0
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2)
    #|  (func $h8 (param i32 i32 i32) (result i32)
    #|    local.get 0
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2)
    #|  (func (export "run1")
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g0
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g1
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g2
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g3
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g4
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g5
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g6
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g7
    #|    i32.const 1
    #|    i32.const 2
    #|    call $g8
    #|    i32.const 10
    #|    i32.const 0
    #|    i32.const 20
    #|    call $wrap1
    #|    drop
    #|    i32.const 30
    #|    i32.const 0
    #|    i32.const 40
    #|    call $h0
    #|    drop
    #|    i32.const 31
    #|    i32.const 0
    #|    i32.const 41
    #|    call $h1
    #|    drop
    #|    i32.const 32
    #|    i32.const 0
    #|    i32.const 42
    #|    call $h2
    #|    drop
    #|    i32.const 33
    #|    i32.const 0
    #|    i32.const 43
    #|    call $h3
    #|    drop
    #|    i32.const 34
    #|    i32.const 0
    #|    i32.const 44
    #|    call $h4
    #|    drop
    #|    i32.const 35
    #|    i32.const 0
    #|    i32.const 45
    #|    call $h5
    #|    drop
    #|    i32.const 36
    #|    i32.const 0
    #|    i32.const 46
    #|    call $h6
    #|    drop
    #|    i32.const 37
    #|    i32.const 0
    #|    i32.const 47
    #|    call $h7
    #|    drop
    #|    i32.const 38
    #|    i32.const 0
    #|    i32.const 48
    #|    call $h8
    #|    drop)
    #|  (func (export "run2")
    #|    i32.const 5
    #|    i32.const 0
    #|    i32.const 21
    #|    call $wrap1
    #|    drop
    #|    i32.const 50
    #|    i32.const 0
    #|    i32.const 60
    #|    call $h0
    #|    drop
    #|    i32.const 51
    #|    i32.const 0
    #|    i32.const 61
    #|    call $h1
    #|    drop
    #|    i32.const 52
    #|    i32.const 0
    #|    i32.const 62
    #|    call $h2
    #|    drop
    #|    i32.const 53
    #|    i32.const 0
    #|    i32.const 63
    #|    call $h3
    #|    drop
    #|    i32.const 54
    #|    i32.const 0
    #|    i32.const 64
    #|    call $h4
    #|    drop
    #|    i32.const 55
    #|    i32.const 0
    #|    i32.const 65
    #|    call $h5
    #|    drop
    #|    i32.const 56
    #|    i32.const 0
    #|    i32.const 66
    #|    call $h6
    #|    drop
    #|    i32.const 57
    #|    i32.const 0
    #|    i32.const 67
    #|    call $h7
    #|    drop
    #|    i32.const 58
    #|    i32.const 0
    #|    i32.const 68
    #|    call $h8
    #|    drop))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 9).length(), 2)
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
test "dae-optimizing removes dropped large dead-prefix result bodies like Binaryen" {
  let out = StringBuilder::new()
  out.write_string(
    (
      #|(module
      #|  (func (export "main")
      #|    call $f
      #|    drop)
      #|  (func $f (result f64)
    ),
  )
  out.write_string(dae_test_many_i32_const_drops(70))
  out.write_string(
    (
      #|
      #|    block
      #|      unreachable
      #|    end
      #|    f64.const 1))
    ),
  )
  let optimized = dae_test_run(out.to_string())
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 0)
  let body = optimized.pretty_print_defined_func(1U)
  assert_true(body.contains("unreachable"), msg=body)
  assert_false(body.contains("i32.const"), msg=body)
}

///|
test "dae-optimizing preserves results with undropped dead-suffix callers" {
  let source =
    #|(module
    #|  (func (export "main")
    #|    block
    #|      unreachable
    #|    end
    #|    call $f
    #|    drop)
    #|  (func $f (result i64)
    #|    block
    #|      unreachable
    #|    end
    #|    i64.const 1)
    #|  (func $h (result i64)
    #|    block
    #|      unreachable
    #|    end
    #|    call $f))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 1)
  @debug.assert_eq(dae_test_func_results(optimized, 2).length(), 1)
}

///|
test "dae-optimizing repairs dropped dead-suffix calls when removing result" {
  let source =
    #|(module
    #|  (func (export "main")
    #|    block
    #|      unreachable
    #|    end
    #|    call $f
    #|    drop)
    #|  (func $f (result f64)
    #|    block
    #|      unreachable
    #|    end
    #|    f64.const 1))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 0)
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("(call (Func 1))"), msg=caller)
  assert_false(caller.contains("drop"), msg=caller)
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
test "dae-optimizing keeps simple function types referenced by table and global refs" {
  let type_idx = @lib.TypeIdx::new(0U)
  let ref_type = @lib.RefType::new(true, @lib.HeapType::new(type_idx))
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(ref_type, @lib.Limits::i32(0U, None)),
          Some(@lib.Expr::new([@lib.Instruction::ref_null_type(ref_type)])),
        ),
      ]),
    )
    .with_global_sec(
      @lib.GlobalSec::new([
        @lib.Global::new(
          @lib.GlobalType::new(@lib.ValType::ref_null_type(ref_type), false),
          @lib.Expr::new([@lib.Instruction::ref_null_type(ref_type)]),
        ),
      ]),
    )
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) => fail("expected input module to validate, got \{err}")
  }
  let optimized = dae_run_module_pass(mod_)
  match optimized.type_sec {
    Some(@lib.TypeSec(types)) => @debug.assert_eq(types.length(), 1)
    None => fail("expected type section")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected DAE output to validate, got \{err}")
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
test "dae-optimizing traces the guarded nested cleanup pass order" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $f (param i32 i32) (result i32)
    #|    local.get 0
    #|    local.set 1
    #|    local.get 0)
    #|  (func (export "run") (result i32)
    #|    i32.const 10
    #|    i32.const 20
    #|    call $f))
  let trace = match pass_test_capture_trace(source, ["dae-optimizing"]) {
    Ok(trace) => trace
    Err(err) => fail("expected traced DAE success, got \{err}")
  }
  let nested_passes : Array[String] = []
  for line in trace {
    if line.contains("pass[dae-optimizing]:nested-pass") {
      nested_passes.push(line)
    }
  }
  @debug.assert_eq(nested_passes, [
    "pass[dae-optimizing]:nested-pass name=precompute-propagate-prefix", "pass[dae-optimizing]:nested-pass name=dead-code-elimination",
    "pass[dae-optimizing]:nested-pass name=optimize-instructions", "pass[dae-optimizing]:nested-pass name=local-cse",
    "pass[dae-optimizing]:nested-pass name=pick-load-signs", "pass[dae-optimizing]:nested-pass name=heap-store-optimization",
    "pass[dae-optimizing]:nested-pass name=heap2local", "pass[dae-optimizing]:nested-pass name=optimize-casts",
    "pass[dae-optimizing]:nested-pass name=code-pushing", "pass[dae-optimizing]:nested-pass name=simplify-locals",
    "pass[dae-optimizing]:nested-pass name=code-folding", "pass[dae-optimizing]:nested-pass name=precompute",
    "pass[dae-optimizing]:nested-pass name=merge-blocks", "pass[dae-optimizing]:nested-pass name=remove-unused-brs",
    "pass[dae-optimizing]:nested-pass name=remove-unused-names", "pass[dae-optimizing]:nested-pass name=merge-blocks",
    "pass[dae-optimizing]:nested-pass name=coalesce-locals", "pass[dae-optimizing]:nested-pass name=reorder-locals",
    "pass[dae-optimizing]:nested-pass name=vacuum",
  ])
}

///|
test "dae-optimizing nested precompute-propagate prefix only rewrites touched functions" {
  let source =
    #|(module
    #|  (global $g (mut i32) (i32.const 0))
    #|  (func $f (param i32 i32) (result i32) (local i32)
    #|    local.get 0
    #|    if
    #|      i32.const 1
    #|      global.set $g
    #|    end
    #|    local.get 2
    #|    i32.const 1
    #|    i32.add)
    #|  (func (export "run") (result i32)
    #|    i32.const 10
    #|    i32.const 20
    #|    call $f)
    #|  (func (export "untouched") (param i32) (result i32) (local i32)
    #|    local.get 0
    #|    if
    #|      i32.const 1
    #|      global.set $g
    #|    end
    #|    local.get 1
    #|    i32.const 1
    #|    i32.add))
  let optimized = match pass_test_run_pipeline(source, ["dae-optimizing"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected DAE precompute-propagate prefix pipeline success, got \{err}",
      )
  }
  let touched = optimized.pretty_print_defined_func(0U)
  let untouched = optimized.pretty_print_defined_func(2U)
  assert_true(touched.contains("I32(1)"), msg=touched)
  assert_false(touched.contains("i32.add"), msg=touched)
  assert_true(untouched.contains("i32.add"), msg=untouched)
}

///|
test "dae-optimizing traces oversized touched-function nested cleanup skip" {
  let source = "(module (func $f (param i32)" +
    dae_test_many_i32_locals(129) +
    " nop) (func (export \"run\") i32.const 1 call $f))"
  let trace = match pass_test_capture_trace(source, ["dae-optimizing"]) {
    Ok(trace) => trace
    Err(err) => fail("expected traced oversized DAE success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[dae-optimizing]:nested-cleanup-skip reason=large-touched-function touched=2",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "dae-optimizing traces nested local-cse before simplify-locals" {
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
    #|  (func (export "run") (param i32 i32 i32)
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    call $f))
  let trace = match pass_test_capture_trace(source, ["dae-optimizing"]) {
    Ok(trace) => trace
    Err(err) => fail("expected traced DAE success, got \{err}")
  }
  let mut local_cse_idx = -1
  let mut simplify_locals_idx = -1
  for idx = 0; idx < trace.length(); idx = idx + 1 {
    if local_cse_idx < 0 && trace[idx].contains("pass[local-cse]:start") {
      local_cse_idx = idx
    }
    if simplify_locals_idx < 0 &&
      trace[idx].contains("pass[simplify-locals]:start") {
      simplify_locals_idx = idx
    }
  }
  assert_true(local_cse_idx >= 0, msg=trace.to_string())
  assert_true(simplify_locals_idx > local_cse_idx, msg=trace.to_string())
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
    #|  (func (export "run") (param i32 i32 i32)
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
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
  @debug.assert_eq(touched_locals, @lib.Locals::empty())
  @debug.assert_eq(untouched_locals, @lib.Locals::empty())
  assert_true(
    touched_instrs.contains(@lib.Instruction::local_tee(@lib.LocalIdx::new(0U))),
    msg=optimized.pretty_print_defined_func(0U),
  )
  assert_false(
    untouched_instrs.contains(
      @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
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
test "dae-optimizing nested precompute only rewrites touched functions" {
  let source =
    #|(module
    #|  (global i32 (i32.const 271828))
    #|  (func $f (param i32) (result i32)
    #|    global.get 0)
    #|  (func (export "run") (result i32)
    #|    i32.const 10
    #|    call $f)
    #|  (func (export "untouched") (result i32)
    #|    global.get 0))
  let optimized = match pass_test_run_pipeline(source, ["dae-optimizing"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected DAE precompute pipeline success, got \{err}")
  }
  let touched = optimized.pretty_print_defined_func(0U)
  let untouched = optimized.pretty_print_defined_func(2U)
  assert_false(touched.contains("global.get"), msg=touched)
  assert_true(touched.contains("I32(271828)"), msg=touched)
  assert_true(untouched.contains("global.get"), msg=untouched)
}

///|
test "dae-optimizing nested code-pushing only rewrites touched functions" {
  let source =
    #|(module
    #|  (import "env" "use" (func $use (param i32)))
    #|  (memory 1)
    #|  (func $f (param i32 i32 i32) (local i32 i32)
    #|    local.get 0
    #|    local.set 3
    #|    local.get 3
    #|    local.set 4
    #|    local.get 1
    #|    if
    #|      i32.const 0
    #|      i32.const 1
    #|      i32.store
    #|    end
    #|    local.get 4
    #|    call $use)
    #|  (func (export "run")
    #|    i32.const 10
    #|    i32.const 20
    #|    i32.const 30
    #|    call $f)
    #|  (func (export "untouched") (param i32 i32) (local i32 i32)
    #|    local.get 0
    #|    local.set 2
    #|    local.get 2
    #|    local.set 3
    #|    local.get 1
    #|    if
    #|      i32.const 0
    #|      i32.const 1
    #|      i32.store
    #|    end
    #|    local.get 3
    #|    call $use))
  let optimized = match pass_test_run_pipeline(source, ["dae-optimizing"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected DAE code-pushing pipeline success, got \{err}")
  }
  let touched = optimized.pretty_print_defined_func(0U)
  let untouched = optimized.pretty_print_defined_func(2U)
  assert_false(touched.contains("local.set"), msg=touched)
  assert_true(touched.contains("(call (Func 0))"), msg=touched)
  assert_true(untouched.contains("local.set"), msg=untouched)
}

///|
test "dae-optimizing nested pick-load-signs only rewrites touched functions" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $f (param i32) (result i32) (local $x i32)
    #|    i32.const 0
    #|    i32.load8_u
    #|    local.set $x
    #|    local.get $x
    #|    i32.extend8_s)
    #|  (func (export "run") (result i32)
    #|    i32.const 10
    #|    call $f)
    #|  (func (export "untouched") (result i32) (local $x i32)
    #|    i32.const 0
    #|    i32.load8_u
    #|    local.set $x
    #|    local.get $x
    #|    i32.extend8_s))
  let optimized = match pass_test_run_pipeline(source, ["dae-optimizing"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected DAE pick-load-signs pipeline success, got \{err}")
  }
  let touched = optimized.pretty_print_defined_func(0U)
  let untouched = optimized.pretty_print_defined_func(2U)
  assert_true(touched.contains("i32.load8s"), msg=touched)
  assert_false(touched.contains("i32.load8u"), msg=touched)
  assert_true(untouched.contains("i32.load8u"), msg=untouched)
}

///|
test "dae-optimizing nested heap-store-optimization only rewrites touched functions" {
  let pair = @lib.TypeIdx::new(0U)
  let sink_type = @lib.TypeIdx::new(1U)
  let callee_type = @lib.TypeIdx::new(2U)
  let run_type = @lib.TypeIdx::new(3U)
  let untouched_type = @lib.TypeIdx::new(4U)
  let pair_ref = @lib.ValType::ref_null(@lib.HeapType::new(pair))
  let pair_struct = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_([
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ]),
    ),
  )
  let sink_func = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([pair_ref], [])),
  )
  let callee_func = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let nullary_i32 = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let local0 = @lib.LocalIdx::new(0U)
  let local1 = @lib.LocalIdx::new(1U)
  let make_body = fn(ref_local : @lib.LocalIdx) {
    [
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_const(@lib.I32(4)),
      @lib.Instruction::struct_new(pair),
      @lib.Instruction::local_tee(ref_local),
      @lib.Instruction::i32_const(@lib.I32(9)),
      @lib.Instruction::struct_set(pair, @lib.U32(0U)),
      @lib.Instruction::local_get(ref_local),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::local_get(ref_local),
      @lib.Instruction::struct_get(pair, @lib.U32(0U)),
    ]
  }
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        pair_struct, sink_func, callee_func, nullary_i32, nullary_i32,
      ]),
    )
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("sink"),
          @lib.ExternType::func(sink_type),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([callee_type, run_type, untouched_type]))
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("run"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(2U)),
        ),
        @lib.Export::new(
          @lib.Name::from_string("untouched"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(3U)),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([pair_ref]),
          @lib.Expr::new(make_body(local1)),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(99)),
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([pair_ref]),
          @lib.Expr::new(make_body(local0)),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), ["dae-optimizing"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected DAE heap-store-optimization pipeline success, got \{err}")
  }
  let touched = optimized.pretty_print_defined_func(0U)
  let untouched = optimized.pretty_print_defined_func(2U)
  assert_true(touched.contains("struct.new"), msg=touched)
  assert_false(touched.contains("struct.set"), msg=touched)
  assert_true(untouched.contains("struct.set"), msg=untouched)
}

///|
test "dae-optimizing nested heap2local only rewrites touched functions" {
  let source =
    #|(module
    #|  (type $pair (sub (struct (field (mut i32)) (field (mut i32)))))
    #|  (func $f (param i32) (result i32) (local $ref (ref null $pair))
    #|    (struct.get $pair 0
    #|      (local.tee $ref
    #|        (struct.new_default $pair))))
    #|  (func (export "run") (result i32)
    #|    i32.const 99
    #|    call $f)
    #|  (func (export "untouched") (result i32) (local $ref (ref null $pair))
    #|    (struct.get $pair 0
    #|      (local.tee $ref
    #|        (struct.new_default $pair)))))
  let optimized = match pass_test_run_pipeline(source, ["dae-optimizing"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected DAE heap2local pipeline success, got \{err}")
  }
  let touched = optimized.pretty_print_defined_func(0U)
  let untouched = optimized.pretty_print_defined_func(2U)
  assert_false(touched.contains("struct.new_default"), msg=touched)
  assert_false(touched.contains("struct.get"), msg=touched)
  assert_true(untouched.contains("struct.new_default"), msg=untouched)
}

///|
test "dae-optimizing nested reorder-locals only trims touched functions" {
  let source =
    #|(module
    #|  (func $f (param i32) (result i32) (local i32 i64)
    #|    i32.const 7)
    #|  (func (export "run") (result i32)
    #|    i32.const 99
    #|    call $f)
    #|  (func (export "untouched") (result i32) (local i32 i64)
    #|    i32.const 7))
  let optimized = match pass_test_run_pipeline(source, ["dae-optimizing"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected DAE reorder-locals pipeline success, got \{err}")
  }
  let @lib.Func(touched_locals, _) = dae_test_defined_func(optimized, 0)
  let @lib.Func(untouched_locals, _) = dae_test_defined_func(optimized, 2)
  @debug.assert_eq(touched_locals, @lib.Locals::empty())
  @debug.assert_eq(
    untouched_locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i64()]),
  )
}

///|
test "dae-optimizing nested coalesce-locals only cleans touched functions" {
  let source =
    #|(module
    #|  (func $f (param i32) (result i32) (local i32 i32)
    #|    i32.const 11
    #|    local.set 1
    #|    local.get 1
    #|    drop
    #|    i32.const 22
    #|    local.set 2
    #|    local.get 2)
    #|  (func (export "run") (result i32)
    #|    i32.const 99
    #|    call $f)
    #|  (func (export "untouched") (result i32) (local i32 i32)
    #|    i32.const 11
    #|    local.set 0
    #|    local.get 0
    #|    drop
    #|    i32.const 22
    #|    local.set 1
    #|    local.get 1))
  let optimized = match pass_test_run_pipeline(source, ["dae-optimizing"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected DAE coalesce-locals pipeline success, got \{err}")
  }
  let @lib.Func(touched_locals, _) = dae_test_defined_func(optimized, 0)
  let @lib.Func(untouched_locals, _) = dae_test_defined_func(optimized, 2)
  @debug.assert_eq(touched_locals, @lib.Locals::empty())
  @debug.assert_eq(
    untouched_locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
}

///|
test "dae-optimizing nested optimize-casts only rewrites touched functions" {
  let callee_type = @lib.TypeIdx::new(0U)
  let run_type = @lib.TypeIdx::new(1U)
  let func_heap = @lib.HeapType::abs(@lib.AbsHeapType::func())
  let func_ref = @lib.ValType::ref_type(@lib.RefType::new(false, func_heap))
  let callee_func = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [func_ref]),
    ),
  )
  let run_func = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [func_ref])),
  )
  let cast_body = [
    @lib.Instruction::ref_null(func_heap),
    @lib.Instruction::ref_as_non_null(),
    @lib.Instruction::ref_cast(false, func_heap),
  ]
  let mod_ = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([callee_func, run_func]))
    .with_func_sec(@lib.FuncSec::new([callee_type, run_type, run_type]))
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("run"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(1U)),
        ),
        @lib.Export::new(
          @lib.Name::from_string("untouched"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(2U)),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(cast_body)),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(99)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ]),
        ),
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(cast_body)),
      ]),
    )
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), ["dae-optimizing"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected DAE optimize-casts pipeline success, got \{err}")
  }
  @debug.assert_eq(dae_test_func_params(optimized, 0), [])
  let touched = optimized.pretty_print_defined_func(0U)
  let untouched = optimized.pretty_print_defined_func(2U)
  assert_false(touched.contains("ref.cast"), msg=touched)
  assert_true(untouched.contains("ref.cast"), msg=untouched)
}

///|
test "dae-optimizing nested cleanup stays valid on touched ref locals" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $child (sub $base (struct)))
    #|  (func $f (param i32) (result (ref null $child))
    #|    (local (ref null $base) (ref null $child))
    #|    ref.null $child
    #|    local.set 1
    #|    local.get 1
    #|    drop
    #|    ref.null $child
    #|    local.set 2
    #|    local.get 2)
    #|  (func (export "run") (result (ref null $child))
    #|    i32.const 99
    #|    call $f))
  let optimized = match pass_test_run_pipeline(source, ["dae-optimizing"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected DAE ref-local pipeline success, got \{err}")
  }
  @debug.assert_eq(dae_test_func_params(optimized, 0), [])
  let run = optimized.pretty_print_defined_func(1U)
  assert_false(run.contains("i32.const I32(99)"), msg=run)
}

///|
test "dae-optimizing nested cleanup stays valid on touched optimize-casts ref locals" {
  let box = @lib.TypeIdx::new(0U)
  let callee_type = @lib.TypeIdx::new(1U)
  let run_type = @lib.TypeIdx::new(2U)
  let struct_type = @lib.RecType::new(
    @lib.SubType::new(
      false,
      [],
      @lib.CompType::struct_([
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ]),
    ),
  )
  let callee_func = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let run_func = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let temp = @lib.LocalIdx::new(1U)
  let mod_ = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([struct_type, callee_func, run_func]))
    .with_func_sec(@lib.FuncSec::new([callee_type, run_type]))
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("run"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(1U)),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::anyref()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(11)),
            @lib.Instruction::i32_const(@lib.I32(22)),
            @lib.Instruction::struct_new(box),
            @lib.Instruction::local_tee(temp),
            @lib.Instruction::ref_cast(false, @lib.HeapType::new(box)),
            @lib.Instruction::struct_get(box, @lib.U32(0U)),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(99)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), ["dae-optimizing"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected DAE optimize-casts ref-local pipeline success, got \{err}")
  }
  @debug.assert_eq(dae_test_func_params(optimized, 0), [])
}

///|
test "dae-optimizing nested cleanup stays valid on touched tee-driven ref locals" {
  let source =
    #|(module
    #|  (type $box (sub (struct)))
    #|  (func $f (param i32) (local anyref)
    #|    struct.new_default $box
    #|    local.tee 1
    #|    drop)
    #|  (func (export "run")
    #|    i32.const 99
    #|    call $f))
  let optimized = match pass_test_run_pipeline(source, ["dae-optimizing"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected DAE tee-driven ref-local pipeline success, got \{err}")
  }
  @debug.assert_eq(dae_test_func_params(optimized, 0), [])
}

///|
test "dae-optimizing nested cleanup stays valid on touched ref.as_non_null local gets" {
  let source =
    #|(module
    #|  (type $box (sub (struct)))
    #|  (func $f (param i32) (result (ref null $box)) (local (ref null $box))
    #|    ref.null $box
    #|    local.set 1
    #|    local.get 1
    #|    ref.as_non_null
    #|    drop
    #|    local.get 1)
    #|  (func (export "run") (result (ref null $box))
    #|    i32.const 99
    #|    call $f))
  let optimized = match pass_test_run_pipeline(source, ["dae-optimizing"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected DAE ref.as_non_null pipeline success, got \{err}")
  }
  @debug.assert_eq(dae_test_func_params(optimized, 0), [])
}

///|
test "dae-optimizing nested cleanup stays valid on loop-carried ref locals" {
  let source =
    #|(module
    #|  (type $box (sub (struct)))
    #|  (func $f (param i32) (result (ref null $box)) (local (ref null $box))
    #|    loop $l
    #|      ref.null $box
    #|      local.set 1
    #|      i32.const 0
    #|      br_if $l
    #|    end
    #|    local.get 1)
    #|  (func (export "run") (result (ref null $box))
    #|    i32.const 99
    #|    call $f))
  let optimized = match pass_test_run_pipeline(source, ["dae-optimizing"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected DAE loop ref-local pipeline success, got \{err}")
  }
  @debug.assert_eq(dae_test_func_params(optimized, 0), [])
}

///|
test "dae-optimizing nested cleanup stays valid on block-wrapped try_table ref locals" {
  let source =
    #|(module
    #|  (type $box (sub (struct)))
    #|  (func $f (param i32) (result (ref null $box)) (local (ref null $box))
    #|    block
    #|      try_table (catch_all 0)
    #|        ref.null $box
    #|        local.set 1
    #|      end
    #|    end
    #|    local.get 1)
    #|  (func (export "run") (result (ref null $box))
    #|    i32.const 99
    #|    call $f))
  let optimized = match pass_test_run_pipeline(source, ["dae-optimizing"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected DAE block-wrapped try_table pipeline success, got \{err}")
  }
  @debug.assert_eq(dae_test_func_params(optimized, 0), [])
}

///|
test "dae-optimizing core output stays valid on touched call_ref ref locals" {
  let optimized = dae_run_module_pass(
    dae_test_call_ref_fixture(),
    optimize=false,
  )
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected non-optimizing DAE call_ref fixture to validate, got \{err}",
      )
  }
  @debug.assert_eq(dae_test_func_params(optimized, 1), [])
}

///|
test "dae-optimizing nested cleanup stays valid on touched call_ref ref locals" {
  let optimized = match
    run_hot_pipeline(dae_test_call_ref_fixture(), HotPipelineOptions::new(), [
      "dae-optimizing",
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected optimizing DAE call_ref fixture to validate, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected optimizing DAE call_ref fixture to validate, got \{err}")
  }
  @debug.assert_eq(dae_test_func_params(optimized, 1), [])
}

///|
test "dae-optimizing plus local-subtyping stays valid on touched ref.as_non_null local gets" {
  let source =
    #|(module
    #|  (type $box (sub (struct)))
    #|  (func $f (param i32) (result (ref null $box)) (local (ref null $box))
    #|    ref.null $box
    #|    local.set 1
    #|    local.get 1
    #|    ref.as_non_null
    #|    drop
    #|    local.get 1)
    #|  (func (export "run") (result (ref null $box))
    #|    i32.const 99
    #|    call $f))
  let optimized = match
    pass_test_run_pipeline(source, ["dae-optimizing", "local-subtyping"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected DAE plus local-subtyping ref.as_non_null success, got \{err}",
      )
  }
  @debug.assert_eq(dae_test_func_params(optimized, 0), [])
}

///|
test "dae-optimizing plus local-subtyping stays valid on loop-carried ref locals" {
  let source =
    #|(module
    #|  (type $box (sub (struct)))
    #|  (func $f (param i32) (result (ref null $box)) (local (ref null $box))
    #|    loop $l
    #|      ref.null $box
    #|      local.set 1
    #|      i32.const 0
    #|      br_if $l
    #|    end
    #|    local.get 1)
    #|  (func (export "run") (result (ref null $box))
    #|    i32.const 99
    #|    call $f))
  let optimized = match
    pass_test_run_pipeline(source, ["dae-optimizing", "local-subtyping"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected DAE plus local-subtyping loop ref-local success, got \{err}",
      )
  }
  @debug.assert_eq(dae_test_func_params(optimized, 0), [])
}

///|
test "dae-optimizing plus local-subtyping stays valid on block-wrapped try_table ref locals" {
  let source =
    #|(module
    #|  (type $box (sub (struct)))
    #|  (func $f (param i32) (result (ref null $box)) (local (ref null $box))
    #|    block
    #|      try_table (catch_all 0)
    #|        ref.null $box
    #|        local.set 1
    #|      end
    #|    end
    #|    local.get 1)
    #|  (func (export "run") (result (ref null $box))
    #|    i32.const 99
    #|    call $f))
  let optimized = match
    pass_test_run_pipeline(source, ["dae-optimizing", "local-subtyping"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected DAE plus local-subtyping block-wrapped try_table success, got \{err}",
      )
  }
  @debug.assert_eq(dae_test_func_params(optimized, 0), [])
}

///|
test "dae-optimizing plus local-subtyping stays valid on dominated sibling-join ref locals" {
  let source =
    #|(module
    #|  (type $box (sub (struct)))
    #|  (func $f (param i32) (result (ref null $box)) (local (ref null $box))
    #|    i32.const 0
    #|    if
    #|      struct.new_default $box
    #|      local.set 1
    #|    else
    #|      struct.new_default $box
    #|      local.set 1
    #|    end
    #|    local.get 1)
    #|  (func (export "run") (result (ref null $box))
    #|    i32.const 99
    #|    call $f))
  let optimized = match
    pass_test_run_pipeline(source, ["dae-optimizing", "local-subtyping"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected DAE plus local-subtyping dominated sibling-join success, got \{err}",
      )
  }
  @debug.assert_eq(dae_test_func_params(optimized, 0), [])
}

///|
test "dae-optimizing plus local-subtyping stays valid on undominated sibling-join ref locals" {
  let source =
    #|(module
    #|  (type $box (sub (struct)))
    #|  (func $f (param i32) (result (ref null $box)) (local (ref null $box))
    #|    local.get 1
    #|    drop
    #|    i32.const 0
    #|    if
    #|      struct.new_default $box
    #|      local.set 1
    #|    else
    #|      struct.new_default $box
    #|      local.set 1
    #|    end
    #|    local.get 1)
    #|  (func (export "run") (result (ref null $box))
    #|    i32.const 99
    #|    call $f))
  let optimized = match
    pass_test_run_pipeline(source, ["dae-optimizing", "local-subtyping"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected DAE plus local-subtyping undominated sibling-join success, got \{err}",
      )
  }
  @debug.assert_eq(dae_test_func_params(optimized, 0), [])
}

///|
test "dae-optimizing plus local-subtyping stays valid on touched call_ref ref locals" {
  let optimized = match
    run_hot_pipeline(dae_test_call_ref_fixture(), HotPipelineOptions::new(), [
      "dae-optimizing", "local-subtyping",
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected DAE plus local-subtyping call_ref fixture to validate, got \{err}",
      )
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE plus local-subtyping call_ref output to validate, got \{err}",
      )
  }
  @debug.assert_eq(dae_test_func_params(optimized, 1), [])
}

///|
test "dae-optimizing nested cleanup stays valid on declarative call_ref ref locals" {
  let optimized = match
    run_hot_pipeline(
      dae_test_call_ref_declarative_fixture(),
      HotPipelineOptions::new(),
      ["dae-optimizing"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected declarative call_ref DAE output to validate, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected declarative call_ref DAE output to validate, got \{err}")
  }
  @debug.assert_eq(dae_test_func_params(optimized, 1), [])
}

///|
test "dae-optimizing plus local-subtyping stays valid on declarative call_ref ref locals" {
  let optimized = match
    run_hot_pipeline(
      dae_test_call_ref_declarative_fixture(),
      HotPipelineOptions::new(),
      ["dae-optimizing", "local-subtyping"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected DAE plus local-subtyping declarative call_ref fixture success, got \{err}",
      )
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE plus local-subtyping declarative call_ref output to validate, got \{err}",
      )
  }
  @debug.assert_eq(dae_test_func_params(optimized, 1), [])
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
