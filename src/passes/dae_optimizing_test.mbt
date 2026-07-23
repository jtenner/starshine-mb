///|
fn dae_test_func_type(mod_ : @lib.Module, def_idx : Int) -> @lib.FuncType {
  let type_idx = match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) => type_idxs[def_idx]
    None => abort("missing func section")
  }
  match (mod_.type_sec, type_idx) {
    (Some(@lib.TypeSec(rec_types)), @lib.TypeIdx(raw)) => {
      let target = raw.reinterpret_as_int()
      let mut flattened = 0
      for rec_type in rec_types {
        match rec_type {
          @lib.SingleRecType(subtype) => {
            if flattened == target {
              return match subtype.get_comptype() {
                @lib.FuncCompType(params, results) =>
                  @lib.FuncType::new(params, results)
                _ => abort("expected func type")
              }
            }
            flattened += 1
          }
          @lib.GroupRecType(subtypes) => {
            if target >= flattened && target < flattened + subtypes.length() {
              return match subtypes[target - flattened].get_comptype() {
                @lib.FuncCompType(params, results) =>
                  @lib.FuncType::new(params, results)
                _ => abort("expected func type")
              }
            }
            flattened += subtypes.length()
          }
        }
      }
      abort("missing flattened func type")
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
fn dae_test_type_sec_func_type(
  mod_ : @lib.Module,
  type_idx : Int,
) -> @lib.FuncType {
  match mod_.type_sec {
    Some(@lib.TypeSec(rec_types)) =>
      match rec_types[type_idx] {
        @lib.SingleRecType(subtype) =>
          match subtype.get_comptype() {
            @lib.FuncCompType(params, results) =>
              @lib.FuncType::new(params, results)
            _ => abort("expected func type")
          }
        @lib.GroupRecType(_) => abort("unexpected group type")
      }
    None => abort("missing type section")
  }
}

///|
fn dae_test_run(
  text : String,
  pass_name? : String = "dae-optimizing",
) -> @lib.Module {
  if pass_name == "dead-argument-elimination" || pass_name == "dae" {
    return dae_run_module_pass(pass_test_module_from_wat(text))
  }
  match pass_test_run_pipeline(text, [pass_name]) {
    Ok(mod_) => mod_
    Err(err) => abort("expected DAE pipeline success, got \{err}")
  }
}

///|
fn dae_test_run_with_perf_trace(
  text : String,
  pass_name? : String = "dae-optimizing",
) -> (@lib.Module, Array[String]) {
  let trace : Array[String] = []
  let trace_fn = fn(line) { trace.push(line) }
  let perf = HotPerfSession::new(
    trace=trace_fn,
    dump_options=HotPerfDumpOptions::new(),
  )
  let mod_ = match
    run_hot_pipeline(
      pass_test_module_from_wat(text),
      HotPipelineOptions::new(trace=Some(trace_fn), perf=Some(perf)),
      [pass_name],
    ) {
    Ok(mod_) => mod_
    Err(err) => abort("expected perf-traced DAE success, got \{err}")
  }
  (mod_, trace)
}

///|
test "plain DAE emits canonical worklist diagnostics" {
  let source =
    #|(module
    #|  (func $target (param i32)
    #|    nop)
    #|  (func (export "run")
    #|    i32.const 7
    #|    call $target))
    #|
  let (_, trace) = dae_test_run_with_perf_trace(
    source,
    pass_name="dead-argument-elimination",
  )
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[dead-argument-elimination]:diagnostics ") &&
      line.contains("candidates_applied=1") &&
      line.contains("parameters_removed=1") &&
      line.contains("reason.candidate-applied=1")
    }),
    msg=trace.to_string(),
  )
}

///|
test "dae-optimizing emits canonical worklist diagnostics" {
  let source =
    #|(module
    #|  (func $target (param i32)
    #|    nop)
    #|  (func (export "run")
    #|    i32.const 7
    #|    call $target))
    #|
  let (_, trace) = dae_test_run_with_perf_trace(source)
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[dae-optimizing]:diagnostics ") &&
      line.contains("boundaries_analyzed=3") &&
      line.contains("candidates_produced=1") &&
      line.contains("candidates_applied=1") &&
      line.contains("parameters_removed=1") &&
      line.contains("candidate_requeues=1") &&
      line.contains("nested_functions_touched=1") &&
      line.contains("nested_passes_executed=41") &&
      line.contains("reason.candidate-produced=1") &&
      line.contains("reason.candidate-applied=1")
    }),
    msg=trace.to_string(),
  )
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
fn dae_test_instr_matches(
  instr : @lib.Instruction,
  predicate : (@lib.Instruction) -> Bool,
) -> Bool {
  if predicate(instr) {
    return true
  }
  match instr {
    @lib.Block(_, @lib.Expr(body))
    | @lib.Loop(_, @lib.Expr(body))
    | @lib.TryTable(_, _, @lib.Expr(body)) =>
      dae_test_instrs_match(body, predicate)
    @lib.If(_, then_body, Some(else_body)) =>
      dae_test_instrs_match(then_body, predicate) ||
      dae_test_instrs_match(else_body, predicate)
    @lib.If(_, then_body, None) => dae_test_instrs_match(then_body, predicate)
    _ => false
  }
}

///|
fn dae_test_instrs_match(
  instrs : Array[@lib.Instruction],
  predicate : (@lib.Instruction) -> Bool,
) -> Bool {
  instrs.any(fn(instr) { dae_test_instr_matches(instr, predicate) })
}

///|
fn dae_test_instrs_have_direct_call(
  instrs : Array[@lib.Instruction],
  target : @lib.FuncIdx,
) -> Bool {
  dae_test_instrs_match(instrs, fn(instr) {
    match instr {
      @lib.Call(idx) => idx == target
      _ => false
    }
  })
}

///|
fn dae_test_instrs_have_local_get(
  instrs : Array[@lib.Instruction],
  target : @lib.LocalIdx,
) -> Bool {
  dae_test_instrs_match(instrs, fn(instr) {
    match instr {
      @lib.LocalGet(idx) => idx == target
      _ => false
    }
  })
}

///|
fn dae_test_instrs_have_i32_const(
  instrs : Array[@lib.Instruction],
  expected : Int,
) -> Bool {
  dae_test_instrs_match(instrs, fn(instr) {
    match instr {
      @lib.I32Const(@lib.I32(value)) => value == expected
      _ => false
    }
  })
}

///|
fn dae_test_instrs_have_struct_new_default(
  instrs : Array[@lib.Instruction],
) -> Bool {
  dae_test_instrs_match(instrs, fn(instr) {
    match instr {
      @lib.StructNewDefault(_) => true
      _ => false
    }
  })
}

///|
fn dae_test_instrs_have_direct_return_call(
  instrs : Array[@lib.Instruction],
  target : @lib.FuncIdx,
) -> Bool {
  dae_test_instrs_match(instrs, fn(instr) {
    match instr {
      @lib.ReturnCall(idx) => idx == target
      _ => false
    }
  })
}

///|
fn dae_test_instrs_have_any_call(instrs : Array[@lib.Instruction]) -> Bool {
  dae_test_instrs_match(instrs, fn(instr) {
    match instr {
      @lib.Call(_)
      | @lib.CallIndirect(_, _)
      | @lib.CallRef(_)
      | @lib.ReturnCall(_)
      | @lib.ReturnCallIndirect(_, _)
      | @lib.ReturnCallRef(_) => true
      _ => false
    }
  })
}

///|
fn dae_test_instrs_have_unreachable(instrs : Array[@lib.Instruction]) -> Bool {
  dae_test_instrs_match(instrs, fn(instr) {
    match instr {
      @lib.Unreachable => true
      _ => false
    }
  })
}

///|
fn dae_test_instrs_have_i32_div_s(instrs : Array[@lib.Instruction]) -> Bool {
  dae_test_instrs_match(instrs, fn(instr) {
    match instr {
      @lib.I32DivS => true
      _ => false
    }
  })
}

///|
fn dae_test_count_substring(text : String, needle : String) -> Int {
  if needle.length() == 0 {
    return 0
  }
  let mut count = 0
  let limit = text.length() - needle.length()
  let mut idx = 0
  while idx <= limit {
    if text.sub(start=idx, end=idx + needle.length()).to_owned() == needle {
      count += 1
      idx += needle.length()
    } else {
      idx += 1
    }
  }
  count
}

///|
fn dae_test_instr_references_local(
  instr : @lib.Instruction,
  target_local : @lib.LocalIdx,
) -> Bool {
  match instr {
    @lib.LocalGet(idx) | @lib.LocalSet(idx) | @lib.LocalTee(idx) =>
      idx == target_local
    @lib.Block(_, @lib.Expr(body))
    | @lib.Loop(_, @lib.Expr(body))
    | @lib.TryTable(_, _, @lib.Expr(body)) =>
      dae_test_instrs_reference_local(body, target_local)
    @lib.If(_, then_body, Some(else_body)) =>
      dae_test_instrs_reference_local(then_body, target_local) ||
      dae_test_instrs_reference_local(else_body, target_local)
    @lib.If(_, then_body, None) =>
      dae_test_instrs_reference_local(then_body, target_local)
    _ => false
  }
}

///|
fn dae_test_instrs_reference_local(
  instrs : Array[@lib.Instruction],
  target_local : @lib.LocalIdx,
) -> Bool {
  instrs.any(fn(instr) { dae_test_instr_references_local(instr, target_local) })
}

///|
fn dae_test_count_local_set_instr(
  instr : @lib.Instruction,
  target_local : @lib.LocalIdx,
) -> Int {
  match instr {
    @lib.LocalSet(idx) if idx == target_local => 1
    @lib.Block(_, @lib.Expr(body))
    | @lib.Loop(_, @lib.Expr(body))
    | @lib.TryTable(_, _, @lib.Expr(body)) =>
      dae_test_count_local_set_instrs(body, target_local)
    @lib.If(_, then_body, Some(else_body)) =>
      dae_test_count_local_set_instrs(then_body, target_local) +
      dae_test_count_local_set_instrs(else_body, target_local)
    @lib.If(_, then_body, None) =>
      dae_test_count_local_set_instrs(then_body, target_local)
    _ => 0
  }
}

///|
fn dae_test_count_local_set_instrs(
  instrs : Array[@lib.Instruction],
  target_local : @lib.LocalIdx,
) -> Int {
  let mut count = 0
  for instr in instrs {
    count += dae_test_count_local_set_instr(instr, target_local)
  }
  count
}

///|
fn dae_test_count_select_instr(instr : @lib.Instruction) -> Int {
  match instr {
    @lib.Select(_) => 1
    @lib.Block(_, @lib.Expr(body))
    | @lib.Loop(_, @lib.Expr(body))
    | @lib.TryTable(_, _, @lib.Expr(body)) => dae_test_count_select_instrs(body)
    @lib.If(_, then_body, Some(else_body)) =>
      dae_test_count_select_instrs(then_body) +
      dae_test_count_select_instrs(else_body)
    @lib.If(_, then_body, None) => dae_test_count_select_instrs(then_body)
    _ => 0
  }
}

///|
fn dae_test_count_select_instrs(instrs : Array[@lib.Instruction]) -> Int {
  let mut count = 0
  for instr in instrs {
    count += dae_test_count_select_instr(instr)
  }
  count
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
test "plain DAE and dae-optimizing are active module passes under canonical names and aliases" {
  @debug.assert_eq(
    pass_registry_category("dead-argument-elimination"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("dae"),
    Some(HotPassRegistryCategory::module_pass()),
  )
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
test "dead-argument-elimination preserves imported tag type references while pruning types" {
  let source =
    #|(module
    #|  (type $tag_ty (func (param i32)))
    #|  (tag $e (import "8" "") (type $tag_ty))
    #|  (data "\1f\b4"))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  match optimized.type_sec {
    Some(@lib.TypeSec(rec_types)) => @debug.assert_eq(rec_types.length(), 1)
    None => fail("expected imported tag type to remain live")
  }
  match optimized.import_sec {
    Some(
      @lib.ImportSec(
        [@lib.Import(_, _, @lib.TagExternType(@lib.TagType(type_idx)))]
      )
    ) => @debug.assert_eq(type_idx, @lib.TypeIdx::new(0U))
    _ => fail("expected one imported tag after DAE")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected imported tag type repair output to validate, got \{err}")
  }
}

///|
test "dead-argument-elimination removes a private unused scalar parameter at direct calls" {
  let source =
    #|(module
    #|  (func $f (param i32 i32) (result i32)
    #|    local.get 0)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    i32.const 20
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 1)
  let @lib.Func(callee_locals, _) = dae_test_defined_func(optimized, 0)
  @debug.assert_eq(callee_locals.length(), 0)
  let @lib.Func(_, @lib.Expr(caller_body)) = dae_test_defined_func(optimized, 1)
  assert_true(
    dae_test_instrs_have_direct_call(caller_body, @lib.FuncIdx::new(0U)),
  )
  assert_true(
    dae_test_instrs_have_local_get(caller_body, @lib.LocalIdx::new(0U)),
  )
  assert_false(dae_test_instrs_have_i32_const(caller_body, 20))
}

///|
test "dae alias removes a private unused scalar parameter at direct calls" {
  let source =
    #|(module
    #|  (func $f (param i32 i32) (result i32)
    #|    local.get 0)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    i32.const 20
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dae")
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 1)
  let @lib.Func(callee_locals, _) = dae_test_defined_func(optimized, 0)
  @debug.assert_eq(callee_locals.length(), 0)
  let @lib.Func(_, @lib.Expr(caller_body)) = dae_test_defined_func(optimized, 1)
  assert_true(
    dae_test_instrs_have_direct_call(caller_body, @lib.FuncIdx::new(0U)),
  )
  assert_true(
    dae_test_instrs_have_local_get(caller_body, @lib.LocalIdx::new(0U)),
  )
  assert_false(dae_test_instrs_have_i32_const(caller_body, 20))
}

///|
test "plain dead-argument-elimination materializes uniform constant actuals" {
  let source =
    #|(module
    #|  (func $f (param i32) (result i32)
    #|    local.get 0
    #|    i32.const 1
    #|    i32.add)
    #|  (func (export "run") (result i32)
    #|    i32.const 7
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  let @lib.Func(_, @lib.Expr(caller_body)) = dae_test_defined_func(optimized, 1)
  assert_false(dae_test_instrs_have_i32_const(caller_body, 7))
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected plain DAE uniform-constant output to validate, got \{err}")
  }
}

///|
test "dae-optimizing ignores inactive conflicting uniform actuals" {
  let source =
    #|(module
    #|  (func $target (param i32) (result i32)
    #|    local.get 0)
    #|  (func (export "run") (result i32)
    #|    i32.const 7
    #|    call $target
    #|    unreachable
    #|    i32.const 8
    #|    call $target))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected active-callsite uniform output to validate, got \{err}")
  }
}

///|
#skip("manual synthetic DAE module-size threshold; the same inactive-callsite behavior has a bounded test")
test "dae-optimizing ignores inactive conflicting uniform actuals in a broad module" {
  let source = StringBuilder::new()
  source.write_string(
    (
      #|(module
      #|  (func $target (param i32) (result i32)
      #|    local.get 0)
      #|  (func (export "run") (result i32)
      #|    i32.const 7
      #|    call $target
      #|    unreachable
      #|    i32.const 8
      #|    call $target)
      #|
    ),
  )
  let mut def_idx = 2
  while def_idx < 1024 {
    source.write_string("  (func)\n")
    def_idx += 1
  }
  source.write_string(")\n")
  let optimized = dae_test_run(source.to_string())
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected broad active-callsite uniform output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination removes an overwritten incoming parameter" {
  let source =
    #|(module
    #|  (func $f (param i32) (result i32)
    #|    i32.const 10
    #|    local.set 0
    #|    local.get 0)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  let @lib.Func(callee_locals, _) = dae_test_defined_func(optimized, 0)
  @debug.assert_eq(callee_locals.length(), 1)
  let @lib.Func(_, @lib.Expr(caller_body)) = dae_test_defined_func(optimized, 1)
  assert_true(
    dae_test_instrs_have_direct_call(caller_body, @lib.FuncIdx::new(0U)),
  )
  assert_false(
    dae_test_instrs_have_local_get(caller_body, @lib.LocalIdx::new(0U)),
  )
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected overwritten-parameter DAE output to validate, got \{err}")
  }
}

///|
test "dead-argument-elimination removes params overwritten on both if arms" {
  let source =
    #|(module
    #|  (func $f (param i32 i32) (result i32)
    #|    local.get 1
    #|    if
    #|      i32.const 1
    #|      local.set 0
    #|    else
    #|      i32.const 2
    #|      local.set 0
    #|    end
    #|    local.get 0)
    #|  (func (export "run") (param i32) (result i32)
    #|    i32.const 9
    #|    local.get 0
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 1)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected both-if-arms DAE output to validate, got \{err}")
  }
}

///|
test "dead-argument-elimination keeps params read on one if arm" {
  let source =
    #|(module
    #|  (func $f (param i32 i32) (result i32)
    #|    local.get 1
    #|    if (result i32)
    #|      local.get 0
    #|    else
    #|      i32.const 2
    #|    end)
    #|  (func (export "run") (param i32 i32) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 2)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected one-if-arm-live DAE output to validate, got \{err}")
  }
}

///|
test "dead-argument-elimination keeps first-iteration loop param reads" {
  let source =
    #|(module
    #|  (func $f (param i32) (result i32)
    #|    (local i32)
    #|    loop
    #|      local.get 0
    #|      local.set 1
    #|      local.get 1
    #|      i32.eqz
    #|      br_if 0
    #|    end
    #|    local.get 1)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 1)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected loop-first-read DAE output to validate, got \{err}")
  }
}

///|
test "dead-argument-elimination fail-closes unsupported legacy try param bodies" {
  let source =
    #|(module
    #|  (tag $e)
    #|  (func $f (param i32) (result i32)
    #|    (try (result i32)
    #|      (do
    #|        local.get 0)
    #|      (catch $e
    #|        i32.const 0)))
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 1)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected legacy-try DAE output to validate, got \{err}")
  }
}

///|
test "dead-argument-elimination removes dead params despite outgoing return_call_indirect" {
  let source =
    #|(module
    #|  (type $ty (func (result i32)))
    #|  (table 1 funcref)
    #|  (func $leaf (result i32)
    #|    i32.const 7)
    #|  (elem (i32.const 0) $leaf)
    #|  (func $wrapper (param i32) (result i32)
    #|    i32.const 0
    #|    return_call_indirect (type $ty))
    #|  (func (export "run") (result i32)
    #|    i32.const 9
    #|    call $wrapper))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 1)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected return_call_indirect wrapper DAE output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination removes dead params despite outgoing return_call_ref" {
  // Inject return_call_ref because ordinary WAST may not round-trip it.
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (type $ty (func (result i32)))
      #|  (elem declare func $leaf)
      #|  (func $leaf (result i32)
      #|    i32.const 7)
      #|  (func $wrapper (param i32) (result i32)
      #|    i32.const 0)
      #|  (func (export "run") (result i32)
      #|    i32.const 9
      #|    call $wrapper))
    ),
  )
  let mod_ = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let next = funcs.copy()
      next[1] = @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
          @lib.Instruction::return_call_ref(@lib.TypeIdx::new(0U)),
        ]),
      )
      mod_.with_code_sec(@lib.CodeSec::new(next))
    }
    None => abort("expected code section")
  }
  let optimized = dae_run_module_pass(mod_)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 1)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected return_call_ref wrapper DAE output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination removes dead params on direct return_call wrappers" {
  let source =
    #|(module
    #|  (func $target (param i32) (result i32)
    #|    local.get 0)
    #|  (func $wrapper (param i32 i32) (result i32)
    #|    local.get 1
    #|    return_call $target)
    #|  (func (export "run") (param i32) (result i32)
    #|    i32.const 1
    #|    local.get 0
    #|    call $wrapper))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 1)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected direct return_call wrapper DAE output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination keeps results when wrappers contain outgoing tails" {
  let source =
    #|(module
    #|  (type $ty (func (result i32)))
    #|  (table 1 funcref)
    #|  (func $leaf (result i32)
    #|    i32.const 7)
    #|  (elem (i32.const 0) $leaf)
    #|  (func $wrapper (param i32) (result i32)
    #|    i32.const 0
    #|    return_call_indirect (type $ty))
    #|  (func (export "run")
    #|    i32.const 9
    #|    call $wrapper
    #|    drop))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 1)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dropped-result-tail negative DAE output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination removes private params beside type-only tags" {
  let source =
    #|(module
    #|  (type $shared (func (param i32)))
    #|  (tag $e (type $shared))
    #|  (func $target (type $shared)
    #|    nop)
    #|  (func (export "run")
    #|    i32.const 0
    #|    call $target))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  let @lib.FuncType(tag_params, _) = dae_test_type_sec_func_type(optimized, 0)
  @debug.assert_eq(tag_params.length(), 1)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected tag type-only DAE output to validate, got \{err}")
  }
}

///|
test "dead-argument-elimination removes private params beside unused typed tables" {
  let source =
    #|(module
    #|  (type $ty (func (param i32)))
    #|  (table 1 funcref)
    #|  (func $target (type $ty)
    #|    nop)
    #|  (func (export "run")
    #|    i32.const 0
    #|    call $target))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected unused-table DAE output to validate, got \{err}")
  }
}

///|
test "dead-argument-elimination removes private params beside unrelated call_indirect leaves" {
  let source =
    #|(module
    #|  (type $ty (func (param i32)))
    #|  (table 1 funcref)
    #|  (func $target (type $ty)
    #|    nop)
    #|  (func $indirectLeaf (type $ty)
    #|    local.get 0
    #|    drop)
    #|  (elem (i32.const 0) $indirectLeaf)
    #|  (func $indirectCaller
    #|    i32.const 0
    #|    i32.const 0
    #|    call_indirect (type $ty))
    #|  (func (export "run")
    #|    i32.const 0
    #|    call $target))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 1)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected unrelated call_indirect DAE output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination removes private params beside unrelated call_ref leaves" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (type $ty (func (param i32)))
      #|  (elem declare func $refLeaf)
      #|  (func $target (type $ty)
      #|    nop)
      #|  (func $refLeaf (type $ty)
      #|    local.get 0
      #|    drop)
      #|  (func $caller
      #|    i32.const 0
      #|    call $target)
      #|  (func (export "run")
      #|    call $caller))
    ),
  )
  let mod_ = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let next = funcs.copy()
      next[2] = @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
          @lib.Instruction::call_ref(@lib.TypeIdx::new(0U)),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        ]),
      )
      mod_.with_code_sec(@lib.CodeSec::new(next))
    }
    None => abort("expected code section")
  }
  let optimized = dae_run_module_pass(mod_)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 1)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected unrelated call_ref DAE output to validate, got \{err}")
  }
}

///|
test "dead-argument-elimination keeps params for actual ref.func exposure" {
  let source =
    #|(module
    #|  (type $ty (func (param i32)))
    #|  (elem declare func $target)
    #|  (func $target (type $ty)
    #|    local.get 0
    #|    drop)
    #|  (func $holder (result (ref null $ty))
    #|    ref.func $target)
    #|  (func (export "run")
    #|    i32.const 0
    #|    call $target
    #|    call $holder
    #|    drop))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 1)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected ref.func exposure DAE output to validate, got \{err}")
  }
}

///|
test "dead-argument-elimination uses CFG liveness across a branch target" {
  let source =
    #|(module
    #|  (func $f (param i32) (result i32)
    #|    block
    #|      i32.const 10
    #|      local.set 0
    #|      br 0
    #|      local.get 0
    #|      drop
    #|    end
    #|    local.get 0)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  let @lib.Func(callee_locals, _) = dae_test_defined_func(optimized, 0)
  @debug.assert_eq(callee_locals.length(), 1)
  let @lib.Func(_, @lib.Expr(caller_body)) = dae_test_defined_func(optimized, 1)
  assert_false(
    dae_test_instrs_have_local_get(caller_body, @lib.LocalIdx::new(0U)),
  )
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected CFG-entry-liveness DAE output to validate, got \{err}")
  }
}

///|
test "dae-optimizing uses CFG liveness across a branch target" {
  let source =
    #|(module
    #|  (func $f (param i32) (result i32)
    #|    block
    #|      i32.const 10
    #|      local.set 0
    #|      br 0
    #|      local.get 0
    #|      drop
    #|    end
    #|    local.get 0)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dae-optimizing")
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected optimizing CFG-entry-liveness output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination uses entry liveness in call-containing bodies" {
  let source =
    #|(module
    #|  (func $side (export "side"))
    #|  (func $f (param i32) (result i32)
    #|    i32.const 10
    #|    local.set 0
    #|    call $side
    #|    local.get 0)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 0)
  let @lib.Func(callee_locals, _) = dae_test_defined_func(optimized, 1)
  @debug.assert_eq(callee_locals.length(), 1)
  let @lib.Func(_, @lib.Expr(caller_body)) = dae_test_defined_func(optimized, 2)
  assert_false(
    dae_test_instrs_have_local_get(caller_body, @lib.LocalIdx::new(0U)),
  )
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected call-containing liveness DAE output to validate, got \{err}",
      )
  }
}

///|
test "dae-optimizing uses entry liveness in call-containing bodies" {
  let source =
    #|(module
    #|  (func $side (export "side"))
    #|  (func $f (param i32) (result i32)
    #|    i32.const 10
    #|    local.set 0
    #|    call $side
    #|    local.get 0)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dae-optimizing")
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 0)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected optimizing call-containing liveness output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination removes one overwritten incoming parameter from a mixed signature" {
  let source =
    #|(module
    #|  (func $f (param i32 i32) (result i32)
    #|    i32.const 10
    #|    local.set 0
    #|    local.get 0
    #|    local.get 1
    #|    i32.add)
    #|  (func (export "run") (param i32 i32) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 1)
  let @lib.Func(callee_locals, _) = dae_test_defined_func(optimized, 0)
  @debug.assert_eq(callee_locals.length(), 1)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected mixed overwritten-parameter DAE output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination ignores incoming-param reads after return" {
  let source =
    #|(module
    #|  (func $f (param i32) (result i32)
    #|    i32.const 10
    #|    return
    #|    local.get 0)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  let @lib.Func(_, @lib.Expr(caller_body)) = dae_test_defined_func(optimized, 1)
  assert_false(
    dae_test_instrs_have_local_get(caller_body, @lib.LocalIdx::new(0U)),
  )
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected post-return-read DAE output to validate, got \{err}")
  }
}

///|
test "dead-argument-elimination preserves uninhabitable dropped-call control" {
  let source =
    #|(module
    #|  (func $f (result (ref none))
    #|    unreachable)
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    drop
    #|    i32.const 1))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  @debug.assert_eq(dae_test_func_results(optimized, 0).length(), 0)
  let @lib.Func(_, @lib.Expr(caller_body)) = dae_test_defined_func(optimized, 1)
  assert_true(
    dae_test_instrs_have_direct_call(caller_body, @lib.FuncIdx::new(0U)),
  )
  assert_true(dae_test_instrs_have_unreachable(caller_body))
  assert_false(dae_test_instrs_have_i32_const(caller_body, 1))
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected uninhabitable-result DAE output to validate, got \{err}")
  }
}

///|
test "dead-argument-elimination trims unreachable tail debris from coverage-shaped functions" {
  let source =
    #|(module
    #|  (type $void (func))
    #|  (import "env" "imp" (func $imp (type $void)))
    #|  (func $main (type $void)
    #|    i32.const 0
    #|    drop
    #|    block
    #|      i32.const 1
    #|      br_table 0 0
    #|    end
    #|    block
    #|      unreachable
    #|    end
    #|    call $imp
    #|    return_call $imp)
    #|  (start $main)
    #|  (export "main" (func $main)))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let @lib.Func(_, @lib.Expr(body)) = dae_test_defined_func(optimized, 0)
  assert_true(dae_test_instrs_have_unreachable(body))
  assert_false(dae_test_instrs_have_any_call(body))
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected unreachable-tail DAE output to validate, got \{err}")
  }
}

///|
test "dead-argument-elimination removes trapping unused actuals only under traps-never-happen" {
  let source =
    #|(module
    #|  (type $struct (sub (struct (field i32))))
    #|  (func $target (param i32)
    #|    nop)
    #|  (func $caller (param (ref null $struct))
    #|    local.get 0
    #|    struct.get $struct 0
    #|    call $target))
  let ordinary = match
    pass_test_run_pipeline(source, ["dead-argument-elimination"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected ordinary DAE success, got \{err}")
  }
  let tnh = match
    pass_test_run_pipeline(
      source,
      ["dead-argument-elimination"],
      options=HotPipelineOptions::new(traps_never_happen=true),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected TNH DAE success, got \{err}")
  }
  let @lib.Func(_, @lib.Expr(ordinary_caller)) = dae_test_defined_func(
    ordinary, 1,
  )
  let @lib.Func(_, @lib.Expr(tnh_caller)) = dae_test_defined_func(tnh, 1)
  assert_true(
    dae_test_instrs_match(ordinary_caller, fn(instr) {
      instr is @lib.StructGet(_, _)
    }),
  )
  assert_false(
    dae_test_instrs_match(tnh_caller, fn(instr) {
      instr is @lib.StructGet(_, _)
    }),
  )
  @debug.assert_eq(dae_test_func_params(tnh, 0).length(), 0)
  match @validate.validate_module(tnh) {
    Ok(_) => ()
    Err(err) => fail("expected TNH DAE output to validate, got \{err}")
  }
}

///|
test "dae-optimizing removes trapping unused actuals only under traps-never-happen" {
  let source =
    #|(module
    #|  (type $struct (sub (struct (field i32))))
    #|  (func $target (param i32)
    #|    nop)
    #|  (func $caller (param (ref null $struct))
    #|    local.get 0
    #|    struct.get $struct 0
    #|    call $target))
  let ordinary = match pass_test_run_pipeline(source, ["dae-optimizing"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected ordinary DAEO success, got \{err}")
  }
  let tnh = match
    pass_test_run_pipeline(
      source,
      ["dae-optimizing"],
      options=HotPipelineOptions::new(traps_never_happen=true),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected TNH DAEO success, got \{err}")
  }
  let @lib.Func(_, @lib.Expr(ordinary_caller)) = dae_test_defined_func(
    ordinary, 1,
  )
  let @lib.Func(_, @lib.Expr(tnh_caller)) = dae_test_defined_func(tnh, 1)
  assert_true(
    dae_test_instrs_match(ordinary_caller, fn(instr) {
      instr is @lib.StructGet(_, _)
    }),
  )
  assert_false(
    dae_test_instrs_match(tnh_caller, fn(instr) {
      instr is @lib.StructGet(_, _)
    }),
  )
  @debug.assert_eq(dae_test_func_params(tnh, 0).length(), 0)
  match @validate.validate_module(tnh) {
    Ok(_) => ()
    Err(err) => fail("expected TNH DAEO output to validate, got \{err}")
  }
}

///|
test "dead-argument-elimination preserves trapping prefixes before unreachable cleanup" {
  let source =
    #|(module
    #|  (func $f (param i32)
    #|    i32.const 1
    #|    i32.const 0
    #|    i32.div_s
    #|    drop
    #|    block
    #|      unreachable
    #|    end
    #|    i32.const 9
    #|    drop)
    #|  (func (export "run")
    #|    i32.const 7
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  let @lib.Func(_, @lib.Expr(body)) = dae_test_defined_func(optimized, 0)
  assert_true(dae_test_instrs_have_i32_div_s(body))
  assert_true(dae_test_instrs_have_unreachable(body))
  assert_false(dae_test_instrs_have_i32_const(body, 9))
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected trapping-prefix DAE output to validate, got \{err}")
  }
}

///|
test "dead-argument-elimination repairs direct return_call sites when removing an unused parameter" {
  let source =
    #|(module
    #|  (func $entry (export "main") (result i32)
    #|    i32.const 31
    #|    i32.const 41
    #|    return_call $f)
    #|  (func $f (param i32 i32) (result i32)
    #|    local.get 1)
    #|  (func $other (result i32)
    #|    i32.const 32
    #|    i32.const 42
    #|    return_call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 1)
  let @lib.Func(_, @lib.Expr(entry_body)) = dae_test_defined_func(optimized, 0)
  let @lib.Func(_, @lib.Expr(other_body)) = dae_test_defined_func(optimized, 2)
  assert_true(
    dae_test_instrs_have_direct_return_call(entry_body, @lib.FuncIdx::new(1U)),
  )
  assert_true(
    dae_test_instrs_have_direct_return_call(other_body, @lib.FuncIdx::new(1U)),
  )
  assert_false(dae_test_instrs_have_i32_const(entry_body, 31))
  assert_false(dae_test_instrs_have_i32_const(other_body, 32))
  assert_true(dae_test_instrs_have_i32_const(entry_body, 41))
  assert_true(dae_test_instrs_have_i32_const(other_body, 42))
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected return_call DAE output to validate, got \{err}")
  }
}

///|
test "dead-argument-elimination narrows live GC parameters to exact owned direct allocations" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (func $f (param (ref null $base)) (result i32)
    #|    local.get 0
    #|    ref.is_null)
    #|  (func (export "run") (result i32)
    #|    struct.new_default $leaf
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_params(optimized, 0), [expected_leaf])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected DAE argument-refinement output to validate, got \{err}")
  }
}

///|
test "dead-argument-elimination narrows live GC parameters through typed block operands" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (func $f (param (ref null $base)) (result i32)
    #|    local.get 0
    #|    ref.is_null)
    #|  (func (export "run") (result i32)
    #|    (block (result (ref $leaf))
    #|      struct.new_default $leaf)
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_params(optimized, 0), [expected_leaf])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE typed-block argument-refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows live GC parameters through typeidx block operands" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub final $base (struct)))
    #|  (type $carrier (func (result (ref $leaf))))
    #|  (func $f (param (ref null $base)) (result i32)
    #|    local.get 0
    #|    ref.is_null)
    #|  (func (export "run") (result i32)
    #|    (block (type $carrier)
    #|      struct.new_default $leaf)
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_params(optimized, 0), [expected_leaf])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE typeidx-block argument-refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows live GC parameters through typeidx if operands" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub final $base (struct)))
    #|  (type $carrier (func (result (ref $leaf))))
    #|  (func $f (param (ref null $base)) (result i32)
    #|    local.get 0
    #|    ref.is_null)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    (if (type $carrier)
    #|      (then struct.new_default $leaf)
    #|      (else struct.new_default $leaf))
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_params(optimized, 0), [expected_leaf])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE typeidx-if argument-refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows live GC parameters through typeidx loop operands" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub final $base (struct)))
    #|  (type $carrier (func (result (ref $leaf))))
    #|  (func $f (param (ref null $base)) (result i32)
    #|    local.get 0
    #|    ref.is_null)
    #|  (func (export "run") (result i32)
    #|    (loop (type $carrier)
    #|      struct.new_default $leaf)
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_params(optimized, 0), [expected_leaf])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE typeidx-loop argument-refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows live GC parameters through parametric typeidx block operands" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub final $base (struct)))
    #|  (type $carrier (func (param i32) (result (ref $leaf))))
    #|  (func $f (param (ref null $base)) (result i32)
    #|    local.get 0
    #|    ref.is_null)
    #|  (func (export "run") (result i32)
    #|    i32.const 7
    #|    (block (type $carrier)
    #|      drop
    #|      struct.new_default $leaf)
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_params(optimized, 0), [expected_leaf])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE parametric typeidx-block argument-refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows live GC parameters through parametric typeidx if operands" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub final $base (struct)))
    #|  (type $carrier (func (param i32) (result (ref $leaf))))
    #|  (func $f (param (ref null $base)) (result i32)
    #|    local.get 0
    #|    ref.is_null)
    #|  (func (export "run") (param i32) (result i32)
    #|    i32.const 7
    #|    local.get 0
    #|    (if (type $carrier)
    #|      (then
    #|        drop
    #|        struct.new_default $leaf)
    #|      (else
    #|        drop
    #|        struct.new_default $leaf))
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_params(optimized, 0), [expected_leaf])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE parametric typeidx-if argument-refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows live GC parameters through parametric typeidx loop operands" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub final $base (struct)))
    #|  (type $carrier (func (param i32) (result (ref $leaf))))
    #|  (func $f (param (ref null $base)) (result i32)
    #|    local.get 0
    #|    ref.is_null)
    #|  (func (export "run") (result i32)
    #|    i32.const 7
    #|    (loop (type $carrier)
    #|      drop
    #|      struct.new_default $leaf)
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_params(optimized, 0), [expected_leaf])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE parametric typeidx-loop argument-refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows live GC parameters through multi-result typeidx block operands" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub final $base (struct)))
    #|  (type $carrier (func (result i32 (ref $leaf))))
    #|  (func $f (param (ref null $base)) (result i32)
    #|    local.get 0
    #|    ref.is_null)
    #|  (func (export "run") (result i32)
    #|    (block (type $carrier)
    #|      i32.const 9
    #|      struct.new_default $leaf)
    #|    call $f
    #|    i32.add))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_params(optimized, 0), [expected_leaf])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE multi-result typeidx-block argument-refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows live GC parameters through multi-result typeidx if operands" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub final $base (struct)))
    #|  (type $carrier (func (result i32 (ref $leaf))))
    #|  (func $f (param (ref null $base)) (result i32)
    #|    local.get 0
    #|    ref.is_null)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    (if (type $carrier)
    #|      (then
    #|        i32.const 9
    #|        struct.new_default $leaf)
    #|      (else
    #|        i32.const 11
    #|        struct.new_default $leaf))
    #|    call $f
    #|    i32.add))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_params(optimized, 0), [expected_leaf])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE multi-result typeidx-if argument-refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows live GC parameters through multi-result typeidx loop operands" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub final $base (struct)))
    #|  (type $carrier (func (result i32 (ref $leaf))))
    #|  (func $f (param (ref null $base)) (result i32)
    #|    local.get 0
    #|    ref.is_null)
    #|  (func (export "run") (result i32)
    #|    (loop (type $carrier)
    #|      i32.const 9
    #|      struct.new_default $leaf)
    #|    call $f
    #|    i32.add))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_params(optimized, 0), [expected_leaf])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE multi-result typeidx-loop argument-refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows live GC parameters through typed select operands" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub final $base (struct)))
    #|  (func $f (param (ref null $base)) (result i32)
    #|    local.get 0
    #|    ref.is_null)
    #|  (func (export "run") (param i32) (result i32)
    #|    struct.new_default $leaf
    #|    struct.new_default $leaf
    #|    local.get 0
    #|    select (result (ref $leaf))
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_params(optimized, 0), [expected_leaf])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE typed-select argument-refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows live GC parameters through typed-call select operands" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (func $make1 (result (ref $leaf1))
    #|    struct.new_default $leaf1)
    #|  (func $make2 (result (ref $leaf2))
    #|    struct.new_default $leaf2)
    #|  (func $f (param (ref null $base)) (result i32)
    #|    local.get 0
    #|    ref.is_null)
    #|  (func (export "run") (param i32) (result i32)
    #|    call $make1
    #|    call $make2
    #|    local.get 0
    #|    select (result (ref null $base))
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_params(optimized, 2), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE typed-call select-operand argument-refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows live GC parameters through effectful typed-select conditions" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub final $base (struct)))
    #|  (func $cond (result i32)
    #|    i32.const 1)
    #|  (func $f (param (ref null $base)) (result i32)
    #|    local.get 0
    #|    ref.is_null)
    #|  (func (export "run") (result i32)
    #|    struct.new_default $leaf
    #|    struct.new_default $leaf
    #|    call $cond
    #|    select (result (ref $leaf))
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_params(optimized, 1), [expected_leaf])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE effectful typed-select argument-refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows live GC parameters through branchful typed-select conditions" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (func $f (param (ref null $base)) (result i32)
    #|    local.get 0
    #|    ref.is_null)
    #|  (func (export "run") (param i32) (result i32)
    #|    struct.new_default $leaf1
    #|    struct.new_default $leaf2
    #|    local.get 0
    #|    if (result i32)
    #|      i32.const 1
    #|    else
    #|      i32.const 0
    #|    end
    #|    select (result (ref null $base))
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_params(optimized, 0), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE branchful typed-select argument-refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination preserves nullable select LUB while narrowing live GC parameters" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub final $base (struct)))
    #|  (func $f (param (ref null $base)) (result i32)
    #|    local.get 0
    #|    ref.is_null)
    #|  (func (export "run") (param i32) (result i32)
    #|    ref.null $leaf
    #|    struct.new_default $leaf
    #|    local.get 0
    #|    select (result (ref null $leaf))
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_nullable_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      true,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_params(optimized, 0), [expected_nullable_leaf])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE nullable typed-select argument-refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows nullable typed-select actuals to common LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (func $f (param (ref null $base)) (result i32)
    #|    local.get 0
    #|    ref.is_null)
    #|  (func (export "a") (param i32) (result i32)
    #|    ref.null $leaf1
    #|    struct.new_default $leaf1
    #|    local.get 0
    #|    select (result (ref null $leaf1))
    #|    call $f)
    #|  (func (export "b") (param i32) (result i32)
    #|    ref.null $leaf2
    #|    struct.new_default $leaf2
    #|    local.get 0
    #|    select (result (ref null $leaf2))
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_nullable_mid = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_params(optimized, 0), [expected_nullable_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE nullable typed-select LUB argument-refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows live GC parameters to common direct-call LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (func $f (param (ref null $base)) (result i32)
    #|    local.get 0
    #|    ref.is_null)
    #|  (func (export "a") (result i32)
    #|    struct.new_default $leaf1
    #|    call $f)
    #|  (func (export "b") (result i32)
    #|    struct.new_default $leaf2
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_params(optimized, 0), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE argument-LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dae-optimizing folds exact non-null ref.is_null and then removes the dead parameter" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (func $entry (export "main") (result i32)
    #|    struct.new_default $leaf
    #|    call $f)
    #|  (func $f (param (ref null $base)) (result i32)
    #|    local.get 0
    #|    ref.is_null)
    #|  (func $other (result i32)
    #|    struct.new_default $leaf
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dae-optimizing")
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 0)
  let @lib.Func(_, @lib.Expr(helper_body)) = dae_test_defined_func(optimized, 1)
  let @lib.Func(_, @lib.Expr(entry_body)) = dae_test_defined_func(optimized, 0)
  let @lib.Func(_, @lib.Expr(other_body)) = dae_test_defined_func(optimized, 2)
  assert_true(dae_test_instrs_have_i32_const(helper_body, 0))
  assert_false(dae_test_instrs_have_struct_new_default(entry_body))
  assert_false(dae_test_instrs_have_struct_new_default(other_body))
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dae-optimizing exact ref.is_null output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows live GC results to exact helper allocations" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (func $f (result (ref null $base))
    #|    struct.new_default $leaf)
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [expected_leaf])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected DAE return-refinement output to validate, got \{err}")
  }
}

///|
test "dead-argument-elimination narrows descriptor-bearing allocation results" {
  let source =
    #|(module
    #|  (rec
    #|    (type $box
    #|      (descriptor $box_desc)
    #|      (struct (field i32)))
    #|    (type $box_desc
    #|      (describes $box)
    #|      (struct)))
    #|  (global $desc (ref (exact $box_desc)) (struct.new $box_desc))
    #|  (func $f (result (ref null $box))
    #|    i32.const 9
    #|    global.get $desc
    #|    struct.new_desc $box)
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [expected])
  let target = optimized.pretty_print_defined_func(0U)
  assert_true(target.contains("struct.new_desc"), msg=target)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected descriptor-bearing DAE result to validate, got \{err}")
  }
}

///|
test "dead-argument-elimination narrows default descriptor allocation results" {
  let source =
    #|(module
    #|  (rec
    #|    (type $box
    #|      (descriptor $box_desc)
    #|      (struct (field i32)))
    #|    (type $box_desc
    #|      (describes $box)
    #|      (struct)))
    #|  (global $desc (ref (exact $box_desc)) (struct.new $box_desc))
    #|  (func $f (result (ref null $box))
    #|    global.get $desc
    #|    struct.new_default_desc $box)
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [expected])
  let target = optimized.pretty_print_defined_func(0U)
  assert_true(target.contains("struct.new_default_desc"), msg=target)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected default descriptor DAE result to validate, got \{err}")
  }
}

///|
test "dead-argument-elimination narrows descriptor read results" {
  let source =
    #|(module
    #|  (rec
    #|    (type $box
    #|      (descriptor $box_desc)
    #|      (struct (field i32)))
    #|    (type $box_desc
    #|      (describes $box)
    #|      (struct)))
    #|  (global $desc (ref (exact $box_desc)) (struct.new $box_desc))
    #|  (func $inspect
    #|    (param (ref (exact $box)))
    #|    (result (ref null $box_desc))
    #|    local.get 0
    #|    ref.get_desc $box)
    #|  (func (export "run") (result i32)
    #|    i32.const 9
    #|    global.get $desc
    #|    struct.new_desc $box
    #|    call $inspect
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [expected])
  let target = optimized.pretty_print_defined_func(0U)
  assert_true(target.contains("ref.get_desc"), msg=target)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected descriptor-read DAE result to validate, got \{err}")
  }
}

///|
test "dead-argument-elimination narrows descriptor cast results" {
  let source =
    #|(module
    #|  (rec
    #|    (type $box
    #|      (descriptor $box_desc)
    #|      (struct (field i32)))
    #|    (type $box_desc
    #|      (describes $box)
    #|      (struct)))
    #|  (global $desc (ref (exact $box_desc)) (struct.new $box_desc))
    #|  (func $cast
    #|    (param (ref null $box))
    #|    (param (ref (exact $box_desc)))
    #|    (result (ref null $box))
    #|    local.get 0
    #|    local.get 1
    #|    ref.cast_desc_eq $box)
    #|  (func (export "run") (result i32)
    #|    i32.const 9
    #|    global.get $desc
    #|    struct.new_desc $box
    #|    global.get $desc
    #|    call $cast
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [expected])
  let target = optimized.pretty_print_defined_func(0U)
  assert_true(target.contains("ref.cast_desc_eq"), msg=target)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected descriptor-cast DAE result to validate, got \{err}")
  }
}

///|
test "dead-argument-elimination narrows live GC results from local.get evidence" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub final $base (struct)))
    #|  (func $f (result (ref null $base))
    #|    (local $x (ref null $leaf))
    #|    struct.new_default $leaf
    #|    local.set $x
    #|    local.get $x)
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      true,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=false,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [expected_leaf])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE local.get return-refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination preserves external conversion nullability in GC results" {
  let source =
    #|(module
    #|  (type $leaf (struct))
    #|  (func $f (param (ref $leaf)) (result (ref null extern))
    #|    local.get 0
    #|    extern.convert_any)
    #|  (func (export "run") (param (ref $leaf)) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::extern_())),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [expected])
  let target = optimized.pretty_print_defined_func(0U)
  assert_true(target.contains("extern.convert_any"), msg=target)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected external-conversion DAE result refinement to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination infers explicit-return external conversion results" {
  let source =
    #|(module
    #|  (type $leaf (struct))
    #|  (func $f (param (ref $leaf)) (result (ref null extern))
    #|    local.get 0
    #|    extern.convert_any
    #|    return)
    #|  (func (export "run") (param (ref $leaf)) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::extern_())),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [expected])
  let target = optimized.pretty_print_defined_func(0U)
  assert_true(target.contains("extern.convert_any"), msg=target)
  assert_true(target.contains("return"), msg=target)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected explicit conversion DAE result to validate, got \{err}")
  }
}

///|
test "dead-argument-elimination joins nested explicit conversion value slices" {
  let source =
    #|(module
    #|  (type $leaf (struct))
    #|  (func $f
    #|    (param (ref $leaf))
    #|    (param i32)
    #|    (result (ref null extern))
    #|    local.get 1
    #|    if
    #|      local.get 0
    #|      extern.convert_any
    #|      return
    #|    end
    #|    local.get 0
    #|    extern.convert_any)
    #|  (func (export "run")
    #|    (param (ref $leaf))
    #|    (param i32)
    #|    (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::extern_())),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [expected])
  let target = optimized.pretty_print_defined_func(0U)
  assert_true(target.contains("extern.convert_any"), msg=target)
  assert_true(target.contains("return"), msg=target)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected nested explicit conversion DAE result to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination infers concatenated string GC results" {
  let source =
    #|(module
    #|  (func $f (result (ref null extern))
    #|    string.const "star"
    #|    string.const "shine"
    #|    string.concat)
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    @lib.ValType::stringref(),
  ])
  let target = optimized.pretty_print_defined_func(0U)
  assert_true(target.contains("string.concat"), msg=target)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected concatenated-string DAE result to validate, got \{err}")
  }
}

///|
test "dead-argument-elimination infers sliced string-view GC results" {
  let source =
    #|(module
    #|  (func $f (result (ref null extern))
    #|    string.const "starshine"
    #|    string.as_wtf16
    #|    i32.const 0
    #|    i32.const 4
    #|    stringview_wtf16.slice)
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    @lib.ValType::stringref(),
  ])
  let target = optimized.pretty_print_defined_func(0U)
  assert_true(target.contains("string.as_wtf16"), msg=target)
  assert_true(target.contains("stringview_wtf16.slice"), msg=target)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected sliced string-view DAE result to validate, got \{err}")
  }
}

///|
test "dead-argument-elimination infers string array constructor GC results" {
  let source =
    #|(module
    #|  (type $chars (array i16))
    #|  (func $f
    #|    (param (ref null $chars))
    #|    (result (ref null extern))
    #|    local.get 0
    #|    i32.const 0
    #|    i32.const 0
    #|    string.new_wtf16_array)
    #|  (func (export "run") (param (ref null $chars)) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    @lib.ValType::stringref(),
  ])
  let target = optimized.pretty_print_defined_func(0U)
  assert_true(target.contains("string.new_wtf16_array"), msg=target)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected string-array DAE result to validate, got \{err}")
  }
}

///|
test "dead-argument-elimination narrows branchful select-condition GC results" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (func $f (param i32) (result (ref null $base))
    #|    struct.new_default $leaf1
    #|    struct.new_default $leaf2
    #|    local.get 0
    #|    if (result i32)
    #|      i32.const 1
    #|    else
    #|      i32.const 0
    #|    end
    #|    select (result (ref null $base)))
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE branchful select-condition result-refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows live GC results in flat multi-result bodies" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub final $base (struct)))
    #|  (func $f (result i32 (ref null $base))
    #|    i32.const 7
    #|    struct.new_default $leaf)
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    ref.is_null
    #|    i32.add))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    @lib.ValType::i32(),
    expected_leaf,
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE multi-result return-refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows explicit-return GC results in flat multi-result bodies" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub final $base (struct)))
    #|  (func $f (result i32 (ref null $base))
    #|    i32.const 7
    #|    struct.new_default $leaf
    #|    return)
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    ref.is_null
    #|    i32.add))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    @lib.ValType::i32(),
    expected_leaf,
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE multi-result explicit-return refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows live GC results after droppable multi-result prefix" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub final $base (struct)))
    #|  (func $f (result i32 (ref null $base))
    #|    i64.const 99
    #|    drop
    #|    i32.const 7
    #|    struct.new_default $leaf)
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    ref.is_null
    #|    i32.add))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    @lib.ValType::i32(),
    expected_leaf,
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE prefixed multi-result refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows live GC results through multi-result if arms" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (func $f (param i32) (result i32 (ref null $base))
    #|    local.get 0
    #|    if (result i32 (ref null $base))
    #|      i32.const 7
    #|      struct.new_default $leaf1
    #|    else
    #|      i32.const 8
    #|      struct.new_default $leaf2
    #|    end)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null
    #|    i32.add))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    @lib.ValType::i32(),
    expected_mid,
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE multi-result if-arm refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows live GC results through tail single-result if operands in multi-result bodies" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (func $f (param i32) (result i32 (ref null $base))
    #|    i32.const 7
    #|    local.get 0
    #|    if (result (ref null $base))
    #|      struct.new_default $leaf1
    #|    else
    #|      struct.new_default $leaf2
    #|    end)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null
    #|    i32.add))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    @lib.ValType::i32(),
    expected_mid,
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE tail single-result if operand multi-result refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows live GC results through leading single-result if operands in multi-result bodies" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (func $f (param i32) (result (ref null $base) i32)
    #|    local.get 0
    #|    if (result (ref null $base))
    #|      struct.new_default $leaf1
    #|    else
    #|      struct.new_default $leaf2
    #|    end
    #|    i32.const 7)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    drop
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    expected_mid,
    @lib.ValType::i32(),
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE leading single-result if operand multi-result refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows explicit-return GC results through middle single-result if operands in multi-result bodies" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (func $f (param i32) (result i32 (ref null $base) i64)
    #|    i32.const 7
    #|    local.get 0
    #|    if (result (ref null $base))
    #|      struct.new_default $leaf1
    #|    else
    #|      struct.new_default $leaf2
    #|    end
    #|    i64.const 9
    #|    return)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    drop
    #|    ref.is_null
    #|    i32.add))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    @lib.ValType::i32(),
    expected_mid,
    @lib.ValType::i64(),
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE explicit-return middle single-result if operand multi-result refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows live GC results through multiple single-result if operands in multi-result bodies" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (type $leaf3 (sub $mid (struct (field i16))))
    #|  (type $leaf4 (sub $mid (struct (field i8))))
    #|  (func $f (param i32 i32) (result (ref null $base) i32 (ref null $base))
    #|    local.get 0
    #|    if (result (ref null $base))
    #|      struct.new_default $leaf1
    #|    else
    #|      struct.new_default $leaf2
    #|    end
    #|    i32.const 7
    #|    local.get 1
    #|    if (result (ref null $base))
    #|      struct.new_default $leaf3
    #|    else
    #|      struct.new_default $leaf4
    #|    end)
    #|  (func (export "run") (param i32 i32) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    call $f
    #|    ref.is_null
    #|    drop
    #|    drop
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    expected_mid,
    @lib.ValType::i32(),
    expected_mid,
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE multiple single-result if operand multi-result refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows live GC results through interleaved droppable debris before single-result if operands" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (func $f (param i32) (result i32 (ref null $base))
    #|    i32.const 7
    #|    i64.const 99
    #|    drop
    #|    local.get 0
    #|    if (result (ref null $base))
    #|      struct.new_default $leaf1
    #|    else
    #|      struct.new_default $leaf2
    #|    end)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null
    #|    i32.add))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    @lib.ValType::i32(),
    expected_mid,
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE interleaved-debris single-result if operand multi-result refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows live GC results through block-carrier multi-result if arms" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub final $base (struct)))
    #|  (func $f (param i32) (result i32 (ref null $base))
    #|    local.get 0
    #|    if (result i32 (ref null $base))
    #|      block (result i32 (ref null $base))
    #|        i32.const 7
    #|        struct.new_default $leaf
    #|      end
    #|    else
    #|      block (result i32 (ref null $base))
    #|        i32.const 8
    #|        struct.new_default $leaf
    #|      end
    #|    end)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null
    #|    i32.add))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    @lib.ValType::i32(),
    expected_leaf,
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE block-carrier multi-result if-arm refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows live GC results through nested block-carrier multi-result if arms" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub final $base (struct)))
    #|  (func $f (param i32) (result i32 (ref null $base))
    #|    local.get 0
    #|    if (result i32 (ref null $base))
    #|      block (result i32 (ref null $base))
    #|        block (result i32 (ref null $base))
    #|          i32.const 7
    #|          struct.new_default $leaf
    #|        end
    #|      end
    #|    else
    #|      block (result i32 (ref null $base))
    #|        block (result i32 (ref null $base))
    #|          i32.const 8
    #|          struct.new_default $leaf
    #|        end
    #|      end
    #|    end)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null
    #|    i32.add))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    @lib.ValType::i32(),
    expected_leaf,
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE nested block-carrier multi-result if-arm refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows explicit-return GC results through multi-result if arms" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (func $f (param i32) (result i32 (ref null $base))
    #|    local.get 0
    #|    if
    #|      i32.const 7
    #|      struct.new_default $leaf1
    #|      return
    #|    else
    #|      i32.const 8
    #|      struct.new_default $leaf2
    #|      return
    #|    end
    #|    unreachable)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null
    #|    i32.add))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    @lib.ValType::i32(),
    expected_mid,
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE multi-result explicit-return if-arm refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows explicit-return GC results through block-carrier multi-result if arms" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub final $base (struct)))
    #|  (func $f (param i32) (result i32 (ref null $base))
    #|    local.get 0
    #|    if
    #|      block (result i32 (ref null $base))
    #|        i32.const 7
    #|        struct.new_default $leaf
    #|      end
    #|      return
    #|    else
    #|      block (result i32 (ref null $base))
    #|        i32.const 8
    #|        struct.new_default $leaf
    #|      end
    #|      return
    #|    end
    #|    unreachable)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null
    #|    i32.add))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    @lib.ValType::i32(),
    expected_leaf,
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE block-carrier multi-result explicit-return if-arm refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows explicit-return GC results through nested block-carrier multi-result if arms" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub final $base (struct)))
    #|  (func $f (param i32) (result i32 (ref null $base))
    #|    local.get 0
    #|    if
    #|      block (result i32 (ref null $base))
    #|        block (result i32 (ref null $base))
    #|          i32.const 7
    #|          struct.new_default $leaf
    #|        end
    #|      end
    #|      return
    #|    else
    #|      block (result i32 (ref null $base))
    #|        block (result i32 (ref null $base))
    #|          i32.const 8
    #|          struct.new_default $leaf
    #|        end
    #|      end
    #|      return
    #|    end
    #|    unreachable)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null
    #|    i32.add))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    @lib.ValType::i32(),
    expected_leaf,
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE nested block-carrier multi-result explicit-return if-arm refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows explicit-return GC results through void-block multi-result if arms" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub final $base (struct)))
    #|  (func $f (param i32) (result i32 (ref null $base))
    #|    local.get 0
    #|    if
    #|      block
    #|        i32.const 7
    #|        struct.new_default $leaf
    #|        return
    #|      end
    #|    else
    #|      block
    #|        i32.const 8
    #|        struct.new_default $leaf
    #|        return
    #|      end
    #|    end
    #|    unreachable)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null
    #|    i32.add))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    @lib.ValType::i32(),
    expected_leaf,
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE void-block multi-result explicit-return if-arm refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows live GC results through multi-result block carriers" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (func $f (result i32 (ref null $base))
    #|    (block (result i32 (ref null $base))
    #|      i32.const 7
    #|      struct.new_default $leaf))
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    ref.is_null
    #|    i32.add))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    @lib.ValType::i32(),
    expected_leaf,
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE multi-result block-carrier refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows live GC results through nested multi-result block carriers" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (func $f (result i32 (ref null $base))
    #|    (block (result i32 (ref null $base))
    #|      (block (result i32 (ref null $base))
    #|        i32.const 7
    #|        struct.new_default $leaf)))
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    ref.is_null
    #|    i32.add))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    @lib.ValType::i32(),
    expected_leaf,
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE nested multi-result block-carrier refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows explicit-return GC results through nested multi-result block carriers" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (func $f (result i32 (ref null $base))
    #|    (block (result i32 (ref null $base))
    #|      (block (result i32 (ref null $base))
    #|        i32.const 7
    #|        struct.new_default $leaf
    #|        return)))
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    ref.is_null
    #|    i32.add))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    @lib.ValType::i32(),
    expected_leaf,
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE nested explicit-return multi-result block-carrier refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows explicit-return GC results through multi-result block carriers" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (func $f (result i32 (ref null $base))
    #|    (block (result i32 (ref null $base))
    #|      i32.const 7
    #|      struct.new_default $leaf
    #|      return))
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    ref.is_null
    #|    i32.add))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    @lib.ValType::i32(),
    expected_leaf,
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE explicit-return multi-result block-carrier refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows live GC results through typed block bodies" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (func $f (result (ref null $base))
    #|    (block (result (ref $leaf))
    #|      struct.new_default $leaf))
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [expected_leaf])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE typed-block result-refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows live GC results through typeidx block bodies" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (type $carrier (func (result (ref null $base))))
    #|  (func $f (result (ref null $base))
    #|    (block (type $carrier)
    #|      struct.new_default $leaf))
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [expected_leaf])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE typeidx-block result-refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows explicit-return GC results through typeidx block bodies" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (type $carrier (func (result (ref null $base))))
    #|  (func $f (result (ref null $base))
    #|    (block (type $carrier)
    #|      struct.new_default $leaf
    #|      return)
    #|    unreachable)
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [expected_leaf])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE typeidx-block explicit-return refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows non-tail-lane parametric typeidx block GC results" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (type $carrier (func (param i32) (result (ref null $base) i32)))
    #|  (func $f (result (ref null $base) i32)
    #|    i32.const 7
    #|    (block (type $carrier)
    #|      drop
    #|      struct.new_default $leaf
    #|      i32.const 9))
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    drop
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    expected_leaf,
    @lib.ValType::i32(),
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE non-tail-lane parametric typeidx-block refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows non-tail-lane parametric typeidx if GC results" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (type $carrier (func (param i32) (result (ref null $base) i32)))
    #|  (func $f (param i32) (result (ref null $base) i32)
    #|    i32.const 7
    #|    local.get 0
    #|    (if (type $carrier)
    #|      (then
    #|        drop
    #|        struct.new_default $leaf
    #|        i32.const 9)
    #|      (else
    #|        drop
    #|        struct.new_default $leaf
    #|        i32.const 10)))
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    drop
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    expected_leaf,
    @lib.ValType::i32(),
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE non-tail-lane parametric typeidx-if refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows non-tail-lane parametric typeidx loop GC results" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (type $carrier (func (param i32) (result (ref null $base) i32)))
    #|  (func $f (result (ref null $base) i32)
    #|    i32.const 7
    #|    (loop (type $carrier)
    #|      drop
    #|      struct.new_default $leaf
    #|      i32.const 9))
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    drop
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    expected_leaf,
    @lib.ValType::i32(),
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE non-tail-lane parametric typeidx-loop refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows non-drop parametric typeidx block GC results" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (type $carrier (func (param i32) (result (ref null $base) i32)))
    #|  (func $f (result (ref null $base) i32)
    #|    i32.const 7
    #|    (block (type $carrier)
    #|      i32.eqz
    #|      drop
    #|      struct.new_default $leaf
    #|      i32.const 9))
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    drop
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    expected_leaf,
    @lib.ValType::i32(),
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE non-drop parametric typeidx-block refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows non-drop parametric typeidx if GC results" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (type $carrier (func (param i32) (result (ref null $base) i32)))
    #|  (func $f (param i32) (result (ref null $base) i32)
    #|    i32.const 7
    #|    local.get 0
    #|    (if (type $carrier)
    #|      (then
    #|        i32.eqz
    #|        drop
    #|        struct.new_default $leaf
    #|        i32.const 9)
    #|      (else
    #|        i32.eqz
    #|        drop
    #|        struct.new_default $leaf
    #|        i32.const 10)))
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    drop
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    expected_leaf,
    @lib.ValType::i32(),
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE non-drop parametric typeidx-if refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows non-drop parametric typeidx loop GC results" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (type $carrier (func (param i32) (result (ref null $base) i32)))
    #|  (func $f (result (ref null $base) i32)
    #|    i32.const 7
    #|    (loop (type $carrier)
    #|      i32.eqz
    #|      drop
    #|      struct.new_default $leaf
    #|      i32.const 9))
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    drop
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    expected_leaf,
    @lib.ValType::i32(),
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE non-drop parametric typeidx-loop refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows effectful parametric typeidx block GC results" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (type $carrier (func (param i32) (result (ref null $base) i32)))
    #|  (func $f (result (ref null $base) i32)
    #|    i32.const 7
    #|    (block (type $carrier)
    #|      call $sink
    #|      struct.new_default $leaf
    #|      i32.const 9))
    #|  (func $sink (param i32)
    #|    local.get 0
    #|    drop)
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    drop
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    expected_leaf,
    @lib.ValType::i32(),
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE effectful parametric typeidx-block refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows effectful parametric typeidx if GC results" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (type $carrier (func (param i32) (result (ref null $base) i32)))
    #|  (func $f (param i32) (result (ref null $base) i32)
    #|    i32.const 7
    #|    local.get 0
    #|    (if (type $carrier)
    #|      (then
    #|        call $sink
    #|        struct.new_default $leaf
    #|        i32.const 9)
    #|      (else
    #|        call $sink
    #|        struct.new_default $leaf
    #|        i32.const 10)))
    #|  (func $sink (param i32)
    #|    local.get 0
    #|    drop)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    drop
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    expected_leaf,
    @lib.ValType::i32(),
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE effectful parametric typeidx-if refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows effectful parametric typeidx loop GC results" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (type $carrier (func (param i32) (result (ref null $base) i32)))
    #|  (func $f (result (ref null $base) i32)
    #|    i32.const 7
    #|    (loop (type $carrier)
    #|      call $sink
    #|      struct.new_default $leaf
    #|      i32.const 9))
    #|  (func $sink (param i32)
    #|    local.get 0
    #|    drop)
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    drop
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    expected_leaf,
    @lib.ValType::i32(),
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE effectful parametric typeidx-loop refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows trapping-load parametric typeidx block GC results" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (type $carrier (func (param i32) (result (ref null $base) i32)))
    #|  (memory 1)
    #|  (func $f (result (ref null $base) i32)
    #|    i32.const 0
    #|    (block (type $carrier)
    #|      i32.load
    #|      drop
    #|      struct.new_default $leaf
    #|      i32.const 9))
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    drop
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    expected_leaf,
    @lib.ValType::i32(),
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE trapping-load parametric typeidx-block refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows trapping-load parametric typeidx if GC results" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (type $carrier (func (param i32) (result (ref null $base) i32)))
    #|  (memory 1)
    #|  (func $f (param i32) (result (ref null $base) i32)
    #|    i32.const 0
    #|    local.get 0
    #|    (if (type $carrier)
    #|      (then
    #|        i32.load
    #|        drop
    #|        struct.new_default $leaf
    #|        i32.const 9)
    #|      (else
    #|        i32.load
    #|        drop
    #|        struct.new_default $leaf
    #|        i32.const 10)))
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    drop
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    expected_leaf,
    @lib.ValType::i32(),
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE trapping-load parametric typeidx-if refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows trapping-load parametric typeidx loop GC results" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub $base (struct)))
    #|  (type $carrier (func (param i32) (result (ref null $base) i32)))
    #|  (memory 1)
    #|  (func $f (result (ref null $base) i32)
    #|    i32.const 0
    #|    (loop (type $carrier)
    #|      i32.load
    #|      drop
    #|      struct.new_default $leaf
    #|      i32.const 9))
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    drop
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    expected_leaf,
    @lib.ValType::i32(),
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE trapping-load parametric typeidx-loop refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows fallthrough loop GC results" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub final $base (struct)))
    #|  (type $carrier (func (result (ref null $base))))
    #|  (func $typed_f (result (ref null $base))
    #|    (loop (result (ref null $base))
    #|      struct.new_default $leaf))
    #|  (func $typeidx_f (result (ref null $base))
    #|    (loop (type $carrier)
    #|      struct.new_default $leaf))
    #|  (func (export "run") (result i32)
    #|    call $typed_f
    #|    ref.is_null
    #|    call $typeidx_f
    #|    ref.is_null
    #|    i32.add))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [expected_leaf])
  @debug.assert_eq(dae_test_func_results(optimized, 1), [expected_leaf])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE fallthrough-loop result-refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows fallthrough loop multi-result GC results" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub final $base (struct)))
    #|  (type $carrier (func (result i32 (ref null $base))))
    #|  (func $f (result i32 (ref null $base))
    #|    (loop (type $carrier)
    #|      i32.const 7
    #|      struct.new_default $leaf))
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    ref.is_null
    #|    i32.add))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    @lib.ValType::i32(),
    expected_leaf,
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE multi-result fallthrough-loop refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows live GC results to common returned-value LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (func $f (param i32) (result (ref null $base))
    #|    local.get 0
    #|    if (result (ref null $base))
    #|      struct.new_default $leaf1
    #|    else
    #|      struct.new_default $leaf2
    #|    end)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE returned-value LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows select returned-value GC results to common LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (func $f (param i32) (result (ref null $base))
    #|    struct.new_default $leaf1
    #|    struct.new_default $leaf2
    #|    local.get 0
    #|    select (result (ref null $base)))
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE select returned-value LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows typed-call select returned-value GC results to common LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (func $leaf1_result (result (ref $leaf1))
    #|    struct.new_default $leaf1)
    #|  (func $leaf2_result (result (ref $leaf2))
    #|    struct.new_default $leaf2)
    #|  (func $f (param i32) (result (ref null $base))
    #|    call $leaf1_result
    #|    call $leaf2_result
    #|    local.get 0
    #|    select (result (ref null $base)))
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 2), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE typed-call select returned-value LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows call_ref select returned-value GC results to common LUB" {
  let base_type = @lib.TypeIdx::new(0U)
  let mid_type = @lib.TypeIdx::new(1U)
  let leaf1_type = @lib.TypeIdx::new(2U)
  let leaf2_type = @lib.TypeIdx::new(3U)
  let maker1_type = @lib.TypeIdx::new(4U)
  let maker2_type = @lib.TypeIdx::new(5U)
  let f_type = @lib.TypeIdx::new(6U)
  let run_type = @lib.TypeIdx::new(7U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let leaf1_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf1_type)),
  )
  let leaf2_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf2_type)),
  )
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::new(false, [], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::new(
            false,
            [mid_type],
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i32()),
                @lib.Mut::var_(),
              ),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::new(
            false,
            [mid_type],
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i64()),
                @lib.Mut::var_(),
              ),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([], [leaf1_ref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([], [leaf2_ref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [base_ref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([maker1_type, maker2_type, f_type, run_type]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U), @lib.FuncIdx::new(1U)]),
        ),
      ]),
    )
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("run"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(3U)),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::struct_new_default(leaf1_type)]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::struct_new_default(leaf2_type)]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
            @lib.Instruction::call_ref(maker1_type),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
            @lib.Instruction::call_ref(maker2_type),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::select(types=Some([base_ref])),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::call(@lib.FuncIdx::new(2U)),
            @lib.Instruction::ref_is_null(),
          ]),
        ),
      ]),
    )
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) => fail("expected call_ref select fixture to validate, got \{err}")
  }
  let optimized = dae_run_module_pass(mod_, optimize=false)
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(mid_type)),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 2), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE call_ref select returned-value LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows parameterized call_ref select returned-value GC results to common LUB" {
  let base_type = @lib.TypeIdx::new(0U)
  let mid_type = @lib.TypeIdx::new(1U)
  let leaf1_type = @lib.TypeIdx::new(2U)
  let leaf2_type = @lib.TypeIdx::new(3U)
  let maker1_type = @lib.TypeIdx::new(4U)
  let maker2_type = @lib.TypeIdx::new(5U)
  let f_type = @lib.TypeIdx::new(6U)
  let run_type = @lib.TypeIdx::new(7U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let leaf1_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf1_type)),
  )
  let leaf2_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf2_type)),
  )
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::new(false, [], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::new(
            false,
            [mid_type],
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i32()),
                @lib.Mut::var_(),
              ),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::new(
            false,
            [mid_type],
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i64()),
                @lib.Mut::var_(),
              ),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [leaf1_ref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [leaf2_ref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [base_ref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([maker1_type, maker2_type, f_type, run_type]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U), @lib.FuncIdx::new(1U)]),
        ),
      ]),
    )
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("run"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(3U)),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::struct_new_default(leaf1_type)]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::struct_new_default(leaf2_type)]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(11)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
            @lib.Instruction::call_ref(maker1_type),
            @lib.Instruction::i32_const(@lib.I32(22)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
            @lib.Instruction::call_ref(maker2_type),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::select(types=Some([base_ref])),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::call(@lib.FuncIdx::new(2U)),
            @lib.Instruction::ref_is_null(),
          ]),
        ),
      ]),
    )
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected parameterized call_ref select fixture to validate, got \{err}",
      )
  }
  let optimized = dae_run_module_pass(mod_, optimize=false)
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(mid_type)),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 2), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE parameterized call_ref select returned-value LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows call_indirect select returned-value GC results to common LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (type $maker1 (func (param i32) (result (ref $leaf1))))
    #|  (type $maker2 (func (param i32) (result (ref $leaf2))))
    #|  (func $leaf1_result (type $maker1)
    #|    struct.new_default $leaf1)
    #|  (func $leaf2_result (type $maker2)
    #|    struct.new_default $leaf2)
    #|  (table 2 funcref)
    #|  (elem (i32.const 0) $leaf1_result $leaf2_result)
    #|  (func $f (param i32) (result (ref null $base))
    #|    i32.const 11
    #|    i32.const 0
    #|    call_indirect (type $maker1)
    #|    i32.const 22
    #|    i32.const 1
    #|    call_indirect (type $maker2)
    #|    local.get 0
    #|    select (result (ref null $base)))
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 2), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE call_indirect select returned-value LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows two-parameter call_ref select returned-value GC results to common LUB" {
  let base_type = @lib.TypeIdx::new(0U)
  let mid_type = @lib.TypeIdx::new(1U)
  let leaf1_type = @lib.TypeIdx::new(2U)
  let leaf2_type = @lib.TypeIdx::new(3U)
  let maker1_type = @lib.TypeIdx::new(4U)
  let maker2_type = @lib.TypeIdx::new(5U)
  let f_type = @lib.TypeIdx::new(6U)
  let run_type = @lib.TypeIdx::new(7U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let leaf1_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf1_type)),
  )
  let leaf2_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf2_type)),
  )
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::new(false, [], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::new(
            false,
            [mid_type],
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i32()),
                @lib.Mut::var_(),
              ),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::new(
            false,
            [mid_type],
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i64()),
                @lib.Mut::var_(),
              ),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i64()], [
              leaf1_ref,
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i64()], [
              leaf2_ref,
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [base_ref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([maker1_type, maker2_type, f_type, run_type]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U), @lib.FuncIdx::new(1U)]),
        ),
      ]),
    )
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("run"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(3U)),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::struct_new_default(leaf1_type)]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::struct_new_default(leaf2_type)]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(11)),
            @lib.Instruction::i64_const(@lib.I64(12L)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
            @lib.Instruction::call_ref(maker1_type),
            @lib.Instruction::i32_const(@lib.I32(22)),
            @lib.Instruction::i64_const(@lib.I64(23L)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
            @lib.Instruction::call_ref(maker2_type),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::select(types=Some([base_ref])),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::call(@lib.FuncIdx::new(2U)),
            @lib.Instruction::ref_is_null(),
          ]),
        ),
      ]),
    )
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected two-parameter call_ref select fixture to validate, got \{err}",
      )
  }
  let optimized = dae_run_module_pass(mod_, optimize=false)
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(mid_type)),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 2), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE two-parameter call_ref select returned-value LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows two-parameter call_indirect select returned-value GC results to common LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (type $maker1 (func (param i32 i64) (result (ref $leaf1))))
    #|  (type $maker2 (func (param i32 i64) (result (ref $leaf2))))
    #|  (func $leaf1_result (type $maker1)
    #|    struct.new_default $leaf1)
    #|  (func $leaf2_result (type $maker2)
    #|    struct.new_default $leaf2)
    #|  (table 2 funcref)
    #|  (elem (i32.const 0) $leaf1_result $leaf2_result)
    #|  (func $f (param i32) (result (ref null $base))
    #|    i32.const 11
    #|    i64.const 12
    #|    i32.const 0
    #|    call_indirect (type $maker1)
    #|    i32.const 22
    #|    i64.const 23
    #|    i32.const 1
    #|    call_indirect (type $maker2)
    #|    local.get 0
    #|    select (result (ref null $base)))
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 2), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE two-parameter call_indirect select returned-value LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows three-parameter call_ref select returned-value GC results to common LUB" {
  let base_type = @lib.TypeIdx::new(0U)
  let mid_type = @lib.TypeIdx::new(1U)
  let leaf1_type = @lib.TypeIdx::new(2U)
  let leaf2_type = @lib.TypeIdx::new(3U)
  let maker1_type = @lib.TypeIdx::new(4U)
  let maker2_type = @lib.TypeIdx::new(5U)
  let f_type = @lib.TypeIdx::new(6U)
  let run_type = @lib.TypeIdx::new(7U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let leaf1_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf1_type)),
  )
  let leaf2_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf2_type)),
  )
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::new(false, [], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::new(
            false,
            [mid_type],
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i32()),
                @lib.Mut::var_(),
              ),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::new(
            false,
            [mid_type],
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i64()),
                @lib.Mut::var_(),
              ),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [@lib.ValType::i32(), @lib.ValType::i64(), @lib.ValType::i32()],
              [leaf1_ref],
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [@lib.ValType::i32(), @lib.ValType::i64(), @lib.ValType::i32()],
              [leaf2_ref],
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [base_ref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([maker1_type, maker2_type, f_type, run_type]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U), @lib.FuncIdx::new(1U)]),
        ),
      ]),
    )
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("run"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(3U)),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::struct_new_default(leaf1_type)]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::struct_new_default(leaf2_type)]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(11)),
            @lib.Instruction::i64_const(@lib.I64(12L)),
            @lib.Instruction::i32_const(@lib.I32(13)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
            @lib.Instruction::call_ref(maker1_type),
            @lib.Instruction::i32_const(@lib.I32(22)),
            @lib.Instruction::i64_const(@lib.I64(23L)),
            @lib.Instruction::i32_const(@lib.I32(24)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
            @lib.Instruction::call_ref(maker2_type),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::select(types=Some([base_ref])),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::call(@lib.FuncIdx::new(2U)),
            @lib.Instruction::ref_is_null(),
          ]),
        ),
      ]),
    )
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected three-parameter call_ref select fixture to validate, got \{err}",
      )
  }
  let optimized = dae_run_module_pass(mod_, optimize=false)
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(mid_type)),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 2), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE three-parameter call_ref select returned-value LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows three-parameter call_indirect select returned-value GC results to common LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (type $maker1 (func (param i32 i64 i32) (result (ref $leaf1))))
    #|  (type $maker2 (func (param i32 i64 i32) (result (ref $leaf2))))
    #|  (func $leaf1_result (type $maker1)
    #|    struct.new_default $leaf1)
    #|  (func $leaf2_result (type $maker2)
    #|    struct.new_default $leaf2)
    #|  (table 2 funcref)
    #|  (elem (i32.const 0) $leaf1_result $leaf2_result)
    #|  (func $f (param i32) (result (ref null $base))
    #|    i32.const 11
    #|    i64.const 12
    #|    i32.const 13
    #|    i32.const 0
    #|    call_indirect (type $maker1)
    #|    i32.const 22
    #|    i64.const 23
    #|    i32.const 24
    #|    i32.const 1
    #|    call_indirect (type $maker2)
    #|    local.get 0
    #|    select (result (ref null $base)))
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 2), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE three-parameter call_indirect select returned-value LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows four-parameter call_ref select returned-value GC results to common LUB" {
  let base_type = @lib.TypeIdx::new(0U)
  let mid_type = @lib.TypeIdx::new(1U)
  let leaf1_type = @lib.TypeIdx::new(2U)
  let leaf2_type = @lib.TypeIdx::new(3U)
  let maker1_type = @lib.TypeIdx::new(4U)
  let maker2_type = @lib.TypeIdx::new(5U)
  let f_type = @lib.TypeIdx::new(6U)
  let run_type = @lib.TypeIdx::new(7U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let leaf1_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf1_type)),
  )
  let leaf2_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf2_type)),
  )
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::new(false, [], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::new(
            false,
            [mid_type],
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i32()),
                @lib.Mut::var_(),
              ),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::new(
            false,
            [mid_type],
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i64()),
                @lib.Mut::var_(),
              ),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [
                @lib.ValType::i32(),
                @lib.ValType::i64(),
                @lib.ValType::i32(),
                @lib.ValType::i64(),
              ],
              [leaf1_ref],
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [
                @lib.ValType::i32(),
                @lib.ValType::i64(),
                @lib.ValType::i32(),
                @lib.ValType::i64(),
              ],
              [leaf2_ref],
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [base_ref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([maker1_type, maker2_type, f_type, run_type]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U), @lib.FuncIdx::new(1U)]),
        ),
      ]),
    )
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("run"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(3U)),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::struct_new_default(leaf1_type)]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::struct_new_default(leaf2_type)]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(11)),
            @lib.Instruction::i64_const(@lib.I64(12L)),
            @lib.Instruction::i32_const(@lib.I32(13)),
            @lib.Instruction::i64_const(@lib.I64(14L)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
            @lib.Instruction::call_ref(maker1_type),
            @lib.Instruction::i32_const(@lib.I32(22)),
            @lib.Instruction::i64_const(@lib.I64(23L)),
            @lib.Instruction::i32_const(@lib.I32(24)),
            @lib.Instruction::i64_const(@lib.I64(25L)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
            @lib.Instruction::call_ref(maker2_type),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::select(types=Some([base_ref])),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::call(@lib.FuncIdx::new(2U)),
            @lib.Instruction::ref_is_null(),
          ]),
        ),
      ]),
    )
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected four-parameter call_ref select fixture to validate, got \{err}",
      )
  }
  let optimized = dae_run_module_pass(mod_, optimize=false)
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(mid_type)),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 2), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE four-parameter call_ref select returned-value LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows four-parameter call_indirect select returned-value GC results to common LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (type $maker1 (func (param i32 i64 i32 i64) (result (ref $leaf1))))
    #|  (type $maker2 (func (param i32 i64 i32 i64) (result (ref $leaf2))))
    #|  (func $leaf1_result (type $maker1)
    #|    struct.new_default $leaf1)
    #|  (func $leaf2_result (type $maker2)
    #|    struct.new_default $leaf2)
    #|  (table 2 funcref)
    #|  (elem (i32.const 0) $leaf1_result $leaf2_result)
    #|  (func $f (param i32) (result (ref null $base))
    #|    i32.const 11
    #|    i64.const 12
    #|    i32.const 13
    #|    i64.const 14
    #|    i32.const 0
    #|    call_indirect (type $maker1)
    #|    i32.const 22
    #|    i64.const 23
    #|    i32.const 24
    #|    i64.const 25
    #|    i32.const 1
    #|    call_indirect (type $maker2)
    #|    local.get 0
    #|    select (result (ref null $base)))
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 2), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE four-parameter call_indirect select returned-value LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows five-parameter call_ref select returned-value GC results to common LUB" {
  let base_type = @lib.TypeIdx::new(0U)
  let mid_type = @lib.TypeIdx::new(1U)
  let leaf1_type = @lib.TypeIdx::new(2U)
  let leaf2_type = @lib.TypeIdx::new(3U)
  let maker1_type = @lib.TypeIdx::new(4U)
  let maker2_type = @lib.TypeIdx::new(5U)
  let f_type = @lib.TypeIdx::new(6U)
  let run_type = @lib.TypeIdx::new(7U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let leaf1_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf1_type)),
  )
  let leaf2_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf2_type)),
  )
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::new(false, [], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::new(
            false,
            [mid_type],
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i32()),
                @lib.Mut::var_(),
              ),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::new(
            false,
            [mid_type],
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i64()),
                @lib.Mut::var_(),
              ),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [
                @lib.ValType::i32(),
                @lib.ValType::i64(),
                @lib.ValType::i32(),
                @lib.ValType::i64(),
                @lib.ValType::i32(),
              ],
              [leaf1_ref],
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [
                @lib.ValType::i32(),
                @lib.ValType::i64(),
                @lib.ValType::i32(),
                @lib.ValType::i64(),
                @lib.ValType::i32(),
              ],
              [leaf2_ref],
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [base_ref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([maker1_type, maker2_type, f_type, run_type]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U), @lib.FuncIdx::new(1U)]),
        ),
      ]),
    )
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("run"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(3U)),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::struct_new_default(leaf1_type)]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::struct_new_default(leaf2_type)]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(11)),
            @lib.Instruction::i64_const(@lib.I64(12L)),
            @lib.Instruction::i32_const(@lib.I32(13)),
            @lib.Instruction::i64_const(@lib.I64(14L)),
            @lib.Instruction::i32_const(@lib.I32(15)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
            @lib.Instruction::call_ref(maker1_type),
            @lib.Instruction::i32_const(@lib.I32(22)),
            @lib.Instruction::i64_const(@lib.I64(23L)),
            @lib.Instruction::i32_const(@lib.I32(24)),
            @lib.Instruction::i64_const(@lib.I64(25L)),
            @lib.Instruction::i32_const(@lib.I32(26)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
            @lib.Instruction::call_ref(maker2_type),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::select(types=Some([base_ref])),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::call(@lib.FuncIdx::new(2U)),
            @lib.Instruction::ref_is_null(),
          ]),
        ),
      ]),
    )
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected five-parameter call_ref select fixture to validate, got \{err}",
      )
  }
  let optimized = dae_run_module_pass(mod_, optimize=false)
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(mid_type)),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 2), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE five-parameter call_ref select returned-value LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows five-parameter call_indirect select returned-value GC results to common LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (type $maker1 (func (param i32 i64 i32 i64 i32) (result (ref $leaf1))))
    #|  (type $maker2 (func (param i32 i64 i32 i64 i32) (result (ref $leaf2))))
    #|  (func $leaf1_result (type $maker1)
    #|    struct.new_default $leaf1)
    #|  (func $leaf2_result (type $maker2)
    #|    struct.new_default $leaf2)
    #|  (table 2 funcref)
    #|  (elem (i32.const 0) $leaf1_result $leaf2_result)
    #|  (func $f (param i32) (result (ref null $base))
    #|    i32.const 11
    #|    i64.const 12
    #|    i32.const 13
    #|    i64.const 14
    #|    i32.const 15
    #|    i32.const 0
    #|    call_indirect (type $maker1)
    #|    i32.const 22
    #|    i64.const 23
    #|    i32.const 24
    #|    i64.const 25
    #|    i32.const 26
    #|    i32.const 1
    #|    call_indirect (type $maker2)
    #|    local.get 0
    #|    select (result (ref null $base)))
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 2), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE five-parameter call_indirect select returned-value LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows six-parameter call_ref select returned-value GC results to common LUB" {
  let base_type = @lib.TypeIdx::new(0U)
  let mid_type = @lib.TypeIdx::new(1U)
  let leaf1_type = @lib.TypeIdx::new(2U)
  let leaf2_type = @lib.TypeIdx::new(3U)
  let maker1_type = @lib.TypeIdx::new(4U)
  let maker2_type = @lib.TypeIdx::new(5U)
  let f_type = @lib.TypeIdx::new(6U)
  let run_type = @lib.TypeIdx::new(7U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let leaf1_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf1_type)),
  )
  let leaf2_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf2_type)),
  )
  let six_params = [
    @lib.ValType::i32(),
    @lib.ValType::i64(),
    @lib.ValType::i32(),
    @lib.ValType::i64(),
    @lib.ValType::i32(),
    @lib.ValType::i64(),
  ]
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::new(false, [], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::new(
            false,
            [mid_type],
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i32()),
                @lib.Mut::var_(),
              ),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::new(
            false,
            [mid_type],
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i64()),
                @lib.Mut::var_(),
              ),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func(six_params, [leaf1_ref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func(six_params, [leaf2_ref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [base_ref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([maker1_type, maker2_type, f_type, run_type]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U), @lib.FuncIdx::new(1U)]),
        ),
      ]),
    )
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("run"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(3U)),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::struct_new_default(leaf1_type)]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::struct_new_default(leaf2_type)]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(11)),
            @lib.Instruction::i64_const(@lib.I64(12L)),
            @lib.Instruction::i32_const(@lib.I32(13)),
            @lib.Instruction::i64_const(@lib.I64(14L)),
            @lib.Instruction::i32_const(@lib.I32(15)),
            @lib.Instruction::i64_const(@lib.I64(16L)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
            @lib.Instruction::call_ref(maker1_type),
            @lib.Instruction::i32_const(@lib.I32(22)),
            @lib.Instruction::i64_const(@lib.I64(23L)),
            @lib.Instruction::i32_const(@lib.I32(24)),
            @lib.Instruction::i64_const(@lib.I64(25L)),
            @lib.Instruction::i32_const(@lib.I32(26)),
            @lib.Instruction::i64_const(@lib.I64(27L)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
            @lib.Instruction::call_ref(maker2_type),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::select(types=Some([base_ref])),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::call(@lib.FuncIdx::new(2U)),
            @lib.Instruction::ref_is_null(),
          ]),
        ),
      ]),
    )
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected six-parameter call_ref select fixture to validate, got \{err}",
      )
  }
  let optimized = dae_run_module_pass(mod_, optimize=false)
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(mid_type)),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 2), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE six-parameter call_ref select returned-value LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows seven-parameter call_ref select returned-value GC results to common LUB" {
  let base_type = @lib.TypeIdx::new(0U)
  let mid_type = @lib.TypeIdx::new(1U)
  let leaf1_type = @lib.TypeIdx::new(2U)
  let leaf2_type = @lib.TypeIdx::new(3U)
  let maker1_type = @lib.TypeIdx::new(4U)
  let maker2_type = @lib.TypeIdx::new(5U)
  let f_type = @lib.TypeIdx::new(6U)
  let run_type = @lib.TypeIdx::new(7U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let leaf1_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf1_type)),
  )
  let leaf2_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf2_type)),
  )
  let seven_params = [
    @lib.ValType::i32(),
    @lib.ValType::i64(),
    @lib.ValType::i32(),
    @lib.ValType::i64(),
    @lib.ValType::i32(),
    @lib.ValType::i64(),
    @lib.ValType::i32(),
  ]
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::new(false, [], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::new(
            false,
            [mid_type],
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i32()),
                @lib.Mut::var_(),
              ),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::new(
            false,
            [mid_type],
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i64()),
                @lib.Mut::var_(),
              ),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(seven_params, [leaf1_ref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(seven_params, [leaf2_ref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [base_ref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([maker1_type, maker2_type, f_type, run_type]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U), @lib.FuncIdx::new(1U)]),
        ),
      ]),
    )
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("run"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(3U)),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::struct_new_default(leaf1_type)]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::struct_new_default(leaf2_type)]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(11)),
            @lib.Instruction::i64_const(@lib.I64(12L)),
            @lib.Instruction::i32_const(@lib.I32(13)),
            @lib.Instruction::i64_const(@lib.I64(14L)),
            @lib.Instruction::i32_const(@lib.I32(15)),
            @lib.Instruction::i64_const(@lib.I64(16L)),
            @lib.Instruction::i32_const(@lib.I32(17)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
            @lib.Instruction::call_ref(maker1_type),
            @lib.Instruction::i32_const(@lib.I32(22)),
            @lib.Instruction::i64_const(@lib.I64(23L)),
            @lib.Instruction::i32_const(@lib.I32(24)),
            @lib.Instruction::i64_const(@lib.I64(25L)),
            @lib.Instruction::i32_const(@lib.I32(26)),
            @lib.Instruction::i64_const(@lib.I64(27L)),
            @lib.Instruction::i32_const(@lib.I32(28)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
            @lib.Instruction::call_ref(maker2_type),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::select(types=Some([base_ref])),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::call(@lib.FuncIdx::new(2U)),
            @lib.Instruction::ref_is_null(),
          ]),
        ),
      ]),
    )
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected seven-parameter call_ref select fixture to validate, got \{err}",
      )
  }
  let optimized = dae_run_module_pass(mod_, optimize=false)
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(mid_type)),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 2), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE seven-parameter call_ref select returned-value LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows eight-parameter call_ref select returned-value GC results to common LUB" {
  let base_type = @lib.TypeIdx::new(0U)
  let mid_type = @lib.TypeIdx::new(1U)
  let leaf1_type = @lib.TypeIdx::new(2U)
  let leaf2_type = @lib.TypeIdx::new(3U)
  let maker1_type = @lib.TypeIdx::new(4U)
  let maker2_type = @lib.TypeIdx::new(5U)
  let f_type = @lib.TypeIdx::new(6U)
  let run_type = @lib.TypeIdx::new(7U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let leaf1_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf1_type)),
  )
  let leaf2_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf2_type)),
  )
  let eight_params = [
    @lib.ValType::i32(),
    @lib.ValType::i64(),
    @lib.ValType::i32(),
    @lib.ValType::i64(),
    @lib.ValType::i32(),
    @lib.ValType::i64(),
    @lib.ValType::i32(),
    @lib.ValType::i64(),
  ]
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::new(false, [], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::new(
            false,
            [mid_type],
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i32()),
                @lib.Mut::var_(),
              ),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::new(
            false,
            [mid_type],
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i64()),
                @lib.Mut::var_(),
              ),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(eight_params, [leaf1_ref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(eight_params, [leaf2_ref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [base_ref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([maker1_type, maker2_type, f_type, run_type]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U), @lib.FuncIdx::new(1U)]),
        ),
      ]),
    )
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("run"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(3U)),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::struct_new_default(leaf1_type)]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::struct_new_default(leaf2_type)]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(11)),
            @lib.Instruction::i64_const(@lib.I64(12L)),
            @lib.Instruction::i32_const(@lib.I32(13)),
            @lib.Instruction::i64_const(@lib.I64(14L)),
            @lib.Instruction::i32_const(@lib.I32(15)),
            @lib.Instruction::i64_const(@lib.I64(16L)),
            @lib.Instruction::i32_const(@lib.I32(17)),
            @lib.Instruction::i64_const(@lib.I64(18L)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
            @lib.Instruction::call_ref(maker1_type),
            @lib.Instruction::i32_const(@lib.I32(22)),
            @lib.Instruction::i64_const(@lib.I64(23L)),
            @lib.Instruction::i32_const(@lib.I32(24)),
            @lib.Instruction::i64_const(@lib.I64(25L)),
            @lib.Instruction::i32_const(@lib.I32(26)),
            @lib.Instruction::i64_const(@lib.I64(27L)),
            @lib.Instruction::i32_const(@lib.I32(28)),
            @lib.Instruction::i64_const(@lib.I64(29L)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
            @lib.Instruction::call_ref(maker2_type),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::select(types=Some([base_ref])),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::call(@lib.FuncIdx::new(2U)),
            @lib.Instruction::ref_is_null(),
          ]),
        ),
      ]),
    )
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected eight-parameter call_ref select fixture to validate, got \{err}",
      )
  }
  let optimized = dae_run_module_pass(mod_, optimize=false)
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(mid_type)),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 2), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE eight-parameter call_ref select returned-value LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows nine-parameter call_ref select returned-value GC results to common LUB" {
  let base_type = @lib.TypeIdx::new(0U)
  let mid_type = @lib.TypeIdx::new(1U)
  let leaf1_type = @lib.TypeIdx::new(2U)
  let leaf2_type = @lib.TypeIdx::new(3U)
  let maker1_type = @lib.TypeIdx::new(4U)
  let maker2_type = @lib.TypeIdx::new(5U)
  let f_type = @lib.TypeIdx::new(6U)
  let run_type = @lib.TypeIdx::new(7U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let leaf1_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf1_type)),
  )
  let leaf2_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf2_type)),
  )
  let nine_params = [
    @lib.ValType::i32(),
    @lib.ValType::i64(),
    @lib.ValType::i32(),
    @lib.ValType::i64(),
    @lib.ValType::i32(),
    @lib.ValType::i64(),
    @lib.ValType::i32(),
    @lib.ValType::i64(),
    @lib.ValType::i32(),
  ]
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::new(false, [], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::new(
            false,
            [mid_type],
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i32()),
                @lib.Mut::var_(),
              ),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::new(
            false,
            [mid_type],
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i64()),
                @lib.Mut::var_(),
              ),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func(nine_params, [leaf1_ref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func(nine_params, [leaf2_ref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [base_ref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([maker1_type, maker2_type, f_type, run_type]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U), @lib.FuncIdx::new(1U)]),
        ),
      ]),
    )
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("run"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(3U)),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::struct_new_default(leaf1_type)]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::struct_new_default(leaf2_type)]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(11)),
            @lib.Instruction::i64_const(@lib.I64(12L)),
            @lib.Instruction::i32_const(@lib.I32(13)),
            @lib.Instruction::i64_const(@lib.I64(14L)),
            @lib.Instruction::i32_const(@lib.I32(15)),
            @lib.Instruction::i64_const(@lib.I64(16L)),
            @lib.Instruction::i32_const(@lib.I32(17)),
            @lib.Instruction::i64_const(@lib.I64(18L)),
            @lib.Instruction::i32_const(@lib.I32(19)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
            @lib.Instruction::call_ref(maker1_type),
            @lib.Instruction::i32_const(@lib.I32(22)),
            @lib.Instruction::i64_const(@lib.I64(23L)),
            @lib.Instruction::i32_const(@lib.I32(24)),
            @lib.Instruction::i64_const(@lib.I64(25L)),
            @lib.Instruction::i32_const(@lib.I32(26)),
            @lib.Instruction::i64_const(@lib.I64(27L)),
            @lib.Instruction::i32_const(@lib.I32(28)),
            @lib.Instruction::i64_const(@lib.I64(29L)),
            @lib.Instruction::i32_const(@lib.I32(30)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
            @lib.Instruction::call_ref(maker2_type),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::select(types=Some([base_ref])),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::call(@lib.FuncIdx::new(2U)),
            @lib.Instruction::ref_is_null(),
          ]),
        ),
      ]),
    )
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected nine-parameter call_ref select fixture to validate, got \{err}",
      )
  }
  let optimized = dae_run_module_pass(mod_, optimize=false)
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(mid_type)),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 2), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE nine-parameter call_ref select returned-value LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows ten-parameter call_ref select returned-value GC results to common LUB" {
  let base_type = @lib.TypeIdx::new(0U)
  let mid_type = @lib.TypeIdx::new(1U)
  let leaf1_type = @lib.TypeIdx::new(2U)
  let leaf2_type = @lib.TypeIdx::new(3U)
  let maker1_type = @lib.TypeIdx::new(4U)
  let maker2_type = @lib.TypeIdx::new(5U)
  let f_type = @lib.TypeIdx::new(6U)
  let run_type = @lib.TypeIdx::new(7U)
  let base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(base_type)),
  )
  let leaf1_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf1_type)),
  )
  let leaf2_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(leaf2_type)),
  )
  let ten_params = [
    @lib.ValType::i32(),
    @lib.ValType::i64(),
    @lib.ValType::i32(),
    @lib.ValType::i64(),
    @lib.ValType::i32(),
    @lib.ValType::i64(),
    @lib.ValType::i32(),
    @lib.ValType::i64(),
    @lib.ValType::i32(),
    @lib.ValType::i64(),
  ]
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::new(false, [], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::new(false, [base_type], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::new(
            false,
            [mid_type],
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i32()),
                @lib.Mut::var_(),
              ),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::new(
            false,
            [mid_type],
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i64()),
                @lib.Mut::var_(),
              ),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func(ten_params, [leaf1_ref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func(ten_params, [leaf2_ref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [base_ref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([maker1_type, maker2_type, f_type, run_type]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U), @lib.FuncIdx::new(1U)]),
        ),
      ]),
    )
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("run"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(3U)),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::struct_new_default(leaf1_type)]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::struct_new_default(leaf2_type)]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(11)),
            @lib.Instruction::i64_const(@lib.I64(12L)),
            @lib.Instruction::i32_const(@lib.I32(13)),
            @lib.Instruction::i64_const(@lib.I64(14L)),
            @lib.Instruction::i32_const(@lib.I32(15)),
            @lib.Instruction::i64_const(@lib.I64(16L)),
            @lib.Instruction::i32_const(@lib.I32(17)),
            @lib.Instruction::i64_const(@lib.I64(18L)),
            @lib.Instruction::i32_const(@lib.I32(19)),
            @lib.Instruction::i64_const(@lib.I64(20L)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
            @lib.Instruction::call_ref(maker1_type),
            @lib.Instruction::i32_const(@lib.I32(22)),
            @lib.Instruction::i64_const(@lib.I64(23L)),
            @lib.Instruction::i32_const(@lib.I32(24)),
            @lib.Instruction::i64_const(@lib.I64(25L)),
            @lib.Instruction::i32_const(@lib.I32(26)),
            @lib.Instruction::i64_const(@lib.I64(27L)),
            @lib.Instruction::i32_const(@lib.I32(28)),
            @lib.Instruction::i64_const(@lib.I64(29L)),
            @lib.Instruction::i32_const(@lib.I32(30)),
            @lib.Instruction::i64_const(@lib.I64(31L)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
            @lib.Instruction::call_ref(maker2_type),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::select(types=Some([base_ref])),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::call(@lib.FuncIdx::new(2U)),
            @lib.Instruction::ref_is_null(),
          ]),
        ),
      ]),
    )
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected ten-parameter call_ref select fixture to validate, got \{err}",
      )
  }
  let optimized = dae_run_module_pass(mod_, optimize=false)
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(mid_type)),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 2), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE ten-parameter call_ref select returned-value LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows nine-parameter call_indirect select returned-value GC results to common LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (type $maker1 (func (param i32 i64 i32 i64 i32 i64 i32 i64 i32) (result (ref $leaf1))))
    #|  (type $maker2 (func (param i32 i64 i32 i64 i32 i64 i32 i64 i32) (result (ref $leaf2))))
    #|  (func $leaf1_result (type $maker1)
    #|    struct.new_default $leaf1)
    #|  (func $leaf2_result (type $maker2)
    #|    struct.new_default $leaf2)
    #|  (table 2 funcref)
    #|  (elem (i32.const 0) $leaf1_result $leaf2_result)
    #|  (func $f (param i32) (result (ref null $base))
    #|    i32.const 11
    #|    i64.const 12
    #|    i32.const 13
    #|    i64.const 14
    #|    i32.const 15
    #|    i64.const 16
    #|    i32.const 17
    #|    i64.const 18
    #|    i32.const 19
    #|    i32.const 0
    #|    call_indirect (type $maker1)
    #|    i32.const 22
    #|    i64.const 23
    #|    i32.const 24
    #|    i64.const 25
    #|    i32.const 26
    #|    i64.const 27
    #|    i32.const 28
    #|    i64.const 29
    #|    i32.const 30
    #|    i32.const 1
    #|    call_indirect (type $maker2)
    #|    local.get 0
    #|    select (result (ref null $base)))
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 2), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE nine-parameter call_indirect select returned-value LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows ten-parameter call_indirect select returned-value GC results to common LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (type $maker1 (func (param i32 i64 i32 i64 i32 i64 i32 i64 i32 i64) (result (ref $leaf1))))
    #|  (type $maker2 (func (param i32 i64 i32 i64 i32 i64 i32 i64 i32 i64) (result (ref $leaf2))))
    #|  (func $leaf1_result (type $maker1)
    #|    struct.new_default $leaf1)
    #|  (func $leaf2_result (type $maker2)
    #|    struct.new_default $leaf2)
    #|  (table 2 funcref)
    #|  (elem (i32.const 0) $leaf1_result $leaf2_result)
    #|  (func $f (param i32) (result (ref null $base))
    #|    i32.const 11
    #|    i64.const 12
    #|    i32.const 13
    #|    i64.const 14
    #|    i32.const 15
    #|    i64.const 16
    #|    i32.const 17
    #|    i64.const 18
    #|    i32.const 19
    #|    i64.const 20
    #|    i32.const 0
    #|    call_indirect (type $maker1)
    #|    i32.const 22
    #|    i64.const 23
    #|    i32.const 24
    #|    i64.const 25
    #|    i32.const 26
    #|    i64.const 27
    #|    i32.const 28
    #|    i64.const 29
    #|    i32.const 30
    #|    i64.const 31
    #|    i32.const 1
    #|    call_indirect (type $maker2)
    #|    local.get 0
    #|    select (result (ref null $base)))
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 2), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE ten-parameter call_indirect select returned-value LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows six-parameter call_indirect select returned-value GC results to common LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (type $maker1 (func (param i32 i64 i32 i64 i32 i64) (result (ref $leaf1))))
    #|  (type $maker2 (func (param i32 i64 i32 i64 i32 i64) (result (ref $leaf2))))
    #|  (func $leaf1_result (type $maker1)
    #|    struct.new_default $leaf1)
    #|  (func $leaf2_result (type $maker2)
    #|    struct.new_default $leaf2)
    #|  (table 2 funcref)
    #|  (elem (i32.const 0) $leaf1_result $leaf2_result)
    #|  (func $f (param i32) (result (ref null $base))
    #|    i32.const 11
    #|    i64.const 12
    #|    i32.const 13
    #|    i64.const 14
    #|    i32.const 15
    #|    i64.const 16
    #|    i32.const 0
    #|    call_indirect (type $maker1)
    #|    i32.const 22
    #|    i64.const 23
    #|    i32.const 24
    #|    i64.const 25
    #|    i32.const 26
    #|    i64.const 27
    #|    i32.const 1
    #|    call_indirect (type $maker2)
    #|    local.get 0
    #|    select (result (ref null $base)))
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 2), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE six-parameter call_indirect select returned-value LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows seven-parameter call_indirect select returned-value GC results to common LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (type $maker1 (func (param i32 i64 i32 i64 i32 i64 i32) (result (ref $leaf1))))
    #|  (type $maker2 (func (param i32 i64 i32 i64 i32 i64 i32) (result (ref $leaf2))))
    #|  (func $leaf1_result (type $maker1)
    #|    struct.new_default $leaf1)
    #|  (func $leaf2_result (type $maker2)
    #|    struct.new_default $leaf2)
    #|  (table 2 funcref)
    #|  (elem (i32.const 0) $leaf1_result $leaf2_result)
    #|  (func $f (param i32) (result (ref null $base))
    #|    i32.const 11
    #|    i64.const 12
    #|    i32.const 13
    #|    i64.const 14
    #|    i32.const 15
    #|    i64.const 16
    #|    i32.const 17
    #|    i32.const 0
    #|    call_indirect (type $maker1)
    #|    i32.const 22
    #|    i64.const 23
    #|    i32.const 24
    #|    i64.const 25
    #|    i32.const 26
    #|    i64.const 27
    #|    i32.const 28
    #|    i32.const 1
    #|    call_indirect (type $maker2)
    #|    local.get 0
    #|    select (result (ref null $base)))
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 2), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE seven-parameter call_indirect select returned-value LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows eight-parameter call_indirect select returned-value GC results to common LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (type $maker1 (func (param i32 i64 i32 i64 i32 i64 i32 i64) (result (ref $leaf1))))
    #|  (type $maker2 (func (param i32 i64 i32 i64 i32 i64 i32 i64) (result (ref $leaf2))))
    #|  (func $leaf1_result (type $maker1)
    #|    struct.new_default $leaf1)
    #|  (func $leaf2_result (type $maker2)
    #|    struct.new_default $leaf2)
    #|  (table 2 funcref)
    #|  (elem (i32.const 0) $leaf1_result $leaf2_result)
    #|  (func $f (param i32) (result (ref null $base))
    #|    i32.const 11
    #|    i64.const 12
    #|    i32.const 13
    #|    i64.const 14
    #|    i32.const 15
    #|    i64.const 16
    #|    i32.const 17
    #|    i64.const 18
    #|    i32.const 0
    #|    call_indirect (type $maker1)
    #|    i32.const 22
    #|    i64.const 23
    #|    i32.const 24
    #|    i64.const 25
    #|    i32.const 26
    #|    i64.const 27
    #|    i32.const 28
    #|    i64.const 29
    #|    i32.const 1
    #|    call_indirect (type $maker2)
    #|    local.get 0
    #|    select (result (ref null $base)))
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 2), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE eight-parameter call_indirect select returned-value LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows explicit-return select GC results to common LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (func $f (param i32) (result (ref null $base))
    #|    struct.new_default $leaf1
    #|    struct.new_default $leaf2
    #|    local.get 0
    #|    select (result (ref null $base))
    #|    return)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE explicit-return select LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows pure-condition select GC results to common LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (func $f (result (ref null $base))
    #|    struct.new_default $leaf1
    #|    struct.new_default $leaf2
    #|    i32.const 1
    #|    i32.eqz
    #|    select (result (ref null $base)))
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE pure-condition select LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows call-condition select GC results to common LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (func $cond (param i32) (result i32)
    #|    local.get 0
    #|    i32.eqz)
    #|  (func $f (result (ref null $base))
    #|    struct.new_default $leaf1
    #|    struct.new_default $leaf2
    #|    i32.const 1
    #|    call $cond
    #|    select (result (ref null $base)))
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 1), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE call-condition select result refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows call-postop select GC results to common LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (func $cond (param i32) (result i32)
    #|    local.get 0
    #|    i32.const 1
    #|    i32.and)
    #|  (func $f (result (ref null $base))
    #|    struct.new_default $leaf1
    #|    struct.new_default $leaf2
    #|    i32.const 3
    #|    call $cond
    #|    i32.eqz
    #|    select (result (ref null $base)))
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 1), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE call-postop select result refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows memory-condition select GC results to common LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (memory 1)
    #|  (func $f (result (ref null $base))
    #|    struct.new_default $leaf1
    #|    struct.new_default $leaf2
    #|    i32.const 0
    #|    i32.load
    #|    i32.eqz
    #|    select (result (ref null $base)))
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE memory-condition select result refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows pure-condition multi-result select GC operands to common LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (func $f (result i32 (ref null $base))
    #|    i32.const 7
    #|    struct.new_default $leaf1
    #|    struct.new_default $leaf2
    #|    i32.const 1
    #|    i32.eqz
    #|    select (result (ref null $base)))
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    ref.is_null
    #|    i32.add))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    @lib.ValType::i32(),
    expected_mid,
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE pure-condition multi-result select LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows block-condition select GC results to common LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (func $f (result (ref null $base))
    #|    struct.new_default $leaf1
    #|    struct.new_default $leaf2
    #|    (block (result i32)
    #|      i32.const 1)
    #|    select (result (ref null $base)))
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE block-condition select LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows block-condition multi-result select GC operands to common LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (func $f (result i32 (ref null $base))
    #|    i32.const 7
    #|    struct.new_default $leaf1
    #|    struct.new_default $leaf2
    #|    (block (result i32)
    #|      i32.const 1)
    #|    select (result (ref null $base)))
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    ref.is_null
    #|    i32.add))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    @lib.ValType::i32(),
    expected_mid,
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE block-condition multi-result select LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows multi-result select GC operands to common LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (func $f (param i32) (result i32 (ref null $base))
    #|    i32.const 7
    #|    struct.new_default $leaf1
    #|    struct.new_default $leaf2
    #|    local.get 0
    #|    select (result (ref null $base)))
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    drop
    #|    drop
    #|    i32.const 0))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    @lib.ValType::i32(),
    expected_mid,
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE multi-result select LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows non-tail-lane multi-result select GC results to common LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (func $f (param i32) (result (ref null $base) i32)
    #|    struct.new_default $leaf1
    #|    struct.new_default $leaf2
    #|    local.get 0
    #|    select (result (ref null $base))
    #|    i32.const 9)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    drop
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    expected_mid,
    @lib.ValType::i32(),
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE non-tail-lane multi-result select refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows explicit-return multi-result select GC operands to common LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (func $f (param i32) (result i32 (ref null $base))
    #|    i32.const 7
    #|    struct.new_default $leaf1
    #|    struct.new_default $leaf2
    #|    local.get 0
    #|    select (result (ref null $base))
    #|    return)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    drop
    #|    drop
    #|    i32.const 0))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    @lib.ValType::i32(),
    expected_mid,
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE explicit-return multi-result select LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows mixed return and fallthrough GC results to common LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (func $f (param i32) (result (ref null $base))
    #|    local.get 0
    #|    if
    #|      struct.new_default $leaf1
    #|      return
    #|    end
    #|    struct.new_default $leaf2)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE mixed return/fallthrough refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows mixed multi-result return and fallthrough GC results to common LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (func $f (param i32) (result i32 (ref null $base))
    #|    local.get 0
    #|    if
    #|      i32.const 7
    #|      struct.new_default $leaf1
    #|      return
    #|    end
    #|    i32.const 8
    #|    struct.new_default $leaf2)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null
    #|    i32.add))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [
    @lib.ValType::i32(),
    expected_mid,
  ])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE mixed multi-result return/fallthrough refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows else-return and fallthrough GC results to common LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (func $f (param i32) (result (ref null $base))
    #|    local.get 0
    #|    if
    #|    else
    #|      struct.new_default $leaf1
    #|      return
    #|    end
    #|    struct.new_default $leaf2)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE else-return/fallthrough refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows explicit-return GC results to common LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (func $f (param i32) (result (ref null $base))
    #|    local.get 0
    #|    if
    #|      struct.new_default $leaf1
    #|      return
    #|    else
    #|      struct.new_default $leaf2
    #|      return
    #|    end
    #|    unreachable)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE explicit-return LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows typeidx if GC results to common LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (type $carrier (func (result (ref null $base))))
    #|  (func $f (param i32) (result (ref null $base))
    #|    local.get 0
    #|    if (type $carrier)
    #|      struct.new_default $leaf1
    #|    else
    #|      struct.new_default $leaf2
    #|    end)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE typeidx-if returned-value LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows typeidx if explicit-return GC results to common LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (type $void (func))
    #|  (func $f (param i32) (result (ref null $base))
    #|    local.get 0
    #|    if (type $void)
    #|      struct.new_default $leaf1
    #|      return
    #|    else
    #|      struct.new_default $leaf2
    #|      return
    #|    end
    #|    unreachable)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE typeidx-if explicit-return LUB refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows typed-if explicit-return GC results to common LUB" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $mid (sub $base (struct)))
    #|  (type $leaf1 (sub $mid (struct (field i32))))
    #|  (type $leaf2 (sub $mid (struct (field i64))))
    #|  (func $f (param i32) (result (ref null $base))
    #|    local.get 0
    #|    if (result (ref null $base))
    #|      struct.new_default $leaf1
    #|      return
    #|    else
    #|      struct.new_default $leaf2
    #|      return
    #|    end
    #|    unreachable)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_mid = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [expected_mid])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE typed-if explicit-return refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows loop-carried explicit-return GC results" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub final $base (struct)))
    #|  (func $f (result (ref null $base))
    #|    (loop
    #|      struct.new_default $leaf
    #|      return)
    #|    unreachable)
    #|  (func (export "run") (result i32)
    #|    call $f
    #|    ref.is_null))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [expected_leaf])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE loop explicit-return refinement output to validate, got \{err}",
      )
  }
}

///|
test "dead-argument-elimination narrows typed-control explicit-return GC results" {
  let source =
    #|(module
    #|  (type $base (sub (struct)))
    #|  (type $leaf (sub final $base (struct)))
    #|  (func $block_f (result (ref null $base))
    #|    (block (result (ref null $base))
    #|      struct.new_default $leaf
    #|      return)
    #|    unreachable)
    #|  (func $loop_f (result (ref null $base))
    #|    (loop (result (ref null $base))
    #|      struct.new_default $leaf
    #|      return)
    #|    unreachable)
    #|  (func (export "run") (result i32)
    #|    call $block_f
    #|    ref.is_null
    #|    call $loop_f
    #|    ref.is_null
    #|    i32.add))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  let expected_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0), [expected_leaf])
  @debug.assert_eq(dae_test_func_results(optimized, 1), [expected_leaf])
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected DAE typed-control explicit-return refinement output to validate, got \{err}",
      )
  }
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
  let @lib.Func(_, @lib.Expr(caller_body)) = dae_test_defined_func(optimized, 1)
  assert_true(
    dae_test_instrs_have_direct_call(caller_body, @lib.FuncIdx::new(0U)),
  )
  assert_true(
    dae_test_instrs_have_local_get(caller_body, @lib.LocalIdx::new(0U)),
  )
  assert_false(dae_test_instrs_have_i32_const(caller_body, 20))
}

///|
test "plain DAE initializes a removed written parameter from a uniform constant" {
  let source =
    #|(module
    #|  (func $f (param i32) (result i32) (local i32)
    #|    local.get 0
    #|    local.set 1
    #|    i32.const 9
    #|    local.set 0
    #|    local.get 1
    #|    local.get 0
    #|    i32.add)
    #|  (func (export "run") (result i32)
    #|    i32.const 7
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected written uniform-constant plain DAE output to validate, got \{err}",
      )
  }
}

///|
test "dae-optimizing removes unused parameters from nested result carriers" {
  let source =
    #|(module
    #|  (func $target (param i32 i32) (result i32)
    #|    (local i32 i32 i32)
    #|    block (result i32)
    #|      block (result i32)
    #|        local.get 1
    #|      end
    #|    end
    #|    local.set 2
    #|    local.get 2)
    #|  (func (export "run") (result i32)
    #|    i32.const 101
    #|    i32.const 7
    #|    call $target)
    #|  (func (result i32)
    #|    i32.const 102
    #|    i32.const 8
    #|    call $target))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 1)
  let @lib.Func(locals, _) = dae_test_defined_func(optimized, 0)
  @debug.assert_eq(locals.length(), 0)
}

///|
test "dae-optimizing initializes a removed written parameter from a uniform constant" {
  let source =
    #|(module
    #|  (func $f (param i32) (result i32) (local i32)
    #|    local.get 0
    #|    local.set 1
    #|    i32.const 9
    #|    local.set 0
    #|    local.get 1
    #|    local.get 0
    #|    i32.add)
    #|  (func (export "run") (result i32)
    #|    i32.const 7
    #|    call $f))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  let @lib.Func(locals, @lib.Expr(body)) = dae_test_defined_func(optimized, 0)
  @debug.assert_eq(locals.length(), 0)
  assert_true(dae_test_instrs_have_i32_const(body, 16))
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected written uniform-constant DAEO output to validate, got \{err}",
      )
  }
}

///|
test "dae-optimizing initializes one written uniform parameter in a mixed signature" {
  let source =
    #|(module
    #|  (func $f (param i32 i32) (result i32) (local i32)
    #|    local.get 0
    #|    local.set 2
    #|    i32.const 9
    #|    local.set 0
    #|    local.get 2
    #|    local.get 0
    #|    i32.add
    #|    local.get 1
    #|    i32.add)
    #|  (func (export "run") (param i32) (result i32)
    #|    i32.const 7
    #|    local.get 0
    #|    call $f))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 1)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected mixed written uniform-constant DAEO output to validate, got \{err}",
      )
  }
}

///|
test "dae-optimizing initializes a written parameter from a uniform immutable global" {
  let source =
    #|(module
    #|  (global $constant i32 (i32.const 7))
    #|  (func $f (param i32) (result i32) (local i32)
    #|    local.get 0
    #|    local.set 1
    #|    i32.const 9
    #|    local.set 0
    #|    local.get 1
    #|    local.get 0
    #|    i32.add)
    #|  (func (export "run") (result i32)
    #|    global.get $constant
    #|    call $f))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected written immutable-global DAEO output to validate, got \{err}",
      )
  }
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
test "dae-optimizing preserves Binaryen zero tee shape at former Func215 identity" {
  let target_def = 215
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func)\n")
  }
  out.write_string(
    (
      #|  (func (param i32 i32 i32) (result i32)
      #|    (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
      #|    i32.const 0
      #|    local.tee 15
      #|    local.set 18
      #|    local.get 18)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let @lib.Func(_, @lib.Expr(body)) = dae_test_defined_func(
    optimized, target_def,
  )
  @debug.assert_eq(body.length(), 4)
  @debug.assert_eq(body[0], @lib.Instruction::i32_const(@lib.I32(0)))
  @debug.assert_eq(
    body[1],
    @lib.Instruction::local_tee(@lib.LocalIdx::new(15U)),
  )
  @debug.assert_eq(
    body[2],
    @lib.Instruction::local_set(@lib.LocalIdx::new(18U)),
  )
  @debug.assert_eq(
    body[3],
    @lib.Instruction::local_get(@lib.LocalIdx::new(18U)),
  )
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  assert_true(target.contains("local.tee"), msg=target)
}

///|
test "dae-optimizing preserves Binaryen zero tee shape at former Func260 identity" {
  let target_def = 260
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func)\n")
  }
  out.write_string(
    (
      #|  (func (param i32 i32 i32 i32) (result i32)
      #|    (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
      #|    i32.const 0
      #|    local.tee 15
      #|    local.set 18
      #|    i32.const 0
      #|    local.tee 16
      #|    local.set 19
      #|    local.get 19)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let @lib.Func(_, @lib.Expr(body)) = dae_test_defined_func(
    optimized, target_def,
  )
  @debug.assert_eq(body.length(), 7)
  @debug.assert_eq(
    body[1],
    @lib.Instruction::local_tee(@lib.LocalIdx::new(15U)),
  )
  @debug.assert_eq(
    body[2],
    @lib.Instruction::local_set(@lib.LocalIdx::new(18U)),
  )
  @debug.assert_eq(
    body[4],
    @lib.Instruction::local_tee(@lib.LocalIdx::new(16U)),
  )
  @debug.assert_eq(
    body[5],
    @lib.Instruction::local_set(@lib.LocalIdx::new(19U)),
  )
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  assert_true(target.contains("local.tee"), msg=target)
}

///|
test "dae-optimizing rewrites unique function signatures without losing marker types" {
  let source =
    #|(module
    #|  (type $target_ty (func (param i32) (result i32)))
    #|  (type $marker_ty (func (result i32 i32)))
    #|  (func $target (type $target_ty) (param i32) (result i32)
    #|    local.get 0)
    #|  (func $marker (type $marker_ty) (result i32 i32)
    #|    i32.const 1
    #|    i32.const 2)
    #|  (func $caller (export "run") (result i32)
    #|    i32.const 0
    #|    call $target))
  let optimized = dae_test_run(source)
  let @lib.FuncType(first_params, first_results) = dae_test_func_type(
    optimized, 0,
  )
  @debug.assert_eq(first_params.length(), 0)
  @debug.assert_eq(first_results, [@lib.ValType::i32()])
  let @lib.FuncType(marker_params, marker_results) = dae_test_func_type(
    optimized, 1,
  )
  @debug.assert_eq(marker_params.length(), 0)
  @debug.assert_eq(marker_results, [@lib.ValType::i32(), @lib.ValType::i32()])
}

///|
#skip("manual public convergence replay; signature reuse is covered by direct transactional white-box tests")
test "dead-argument-elimination reuses converged simple function signatures" {
  let source =
    #|(module
    #|  (type $main_ty (func (result i32)))
    #|  (type $wide_ty (func (param i32 i32) (result i32)))
    #|  (export "main" (func $entry))
    #|  (func $entry (type $main_ty) (result i32)
    #|    i32.const 10
    #|    i32.const 20
    #|    call $wrapper)
    #|  (func $wrapper (type $wide_ty) (param i32 i32) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    call $leaf)
    #|  (func $leaf (type $wide_ty) (param i32 i32) (result i32)
    #|    local.get 0)
    #|  (func $also_wrapper (type $main_ty) (result i32)
    #|    i32.const 30
    #|    i32.const 40
    #|    call $wrapper)
    #|  (func $also_leaf (type $main_ty) (result i32)
    #|    i32.const 50
    #|    i32.const 60
    #|    call $leaf))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  match optimized.type_sec {
    Some(@lib.TypeSec(rec_types)) => @debug.assert_eq(rec_types.length(), 2)
    None =>
      fail("expected DAE output to keep the two live simple function types")
  }
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => {
      @debug.assert_eq(type_idxs[1], @lib.TypeIdx::new(1U))
      @debug.assert_eq(type_idxs[2], @lib.TypeIdx::new(1U))
    }
    None => fail("expected DAE output to keep function signatures")
  }
  let @lib.FuncType(shared_params, shared_results) = dae_test_type_sec_func_type(
    optimized, 1,
  )
  @debug.assert_eq(shared_params.length(), 1)
  @debug.assert_eq(shared_results, [@lib.ValType::i32()])
  let @lib.Func(wrapper_locals, _) = dae_test_defined_func(optimized, 1)
  let @lib.Func(leaf_locals, _) = dae_test_defined_func(optimized, 2)
  // Both removed parameters are unread after convergence. Keeping Binaryen's
  // generic replacement locals would add two default-only, unaddressable slots.
  @debug.assert_eq(wrapper_locals.length(), 0)
  @debug.assert_eq(leaf_locals.length(), 0)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected converged local projection to validate, got \{err}")
  }
}

///|
#skip("manual aggregate scheduler sweep; bounded worklist ordering and convergence remain covered")
test "plain DAE processes profitable independent boundaries beyond eight rewrites" {
  let source =
    #|(module
    #|  (func $g0 (param i32 i32) local.get 0 drop)
    #|  (func $g1 (param i32 i32) local.get 0 drop)
    #|  (func $g2 (param i32 i32) local.get 0 drop)
    #|  (func $g3 (param i32 i32) local.get 0 drop)
    #|  (func $g4 (param i32 i32) local.get 0 drop)
    #|  (func $g5 (param i32 i32) local.get 0 drop)
    #|  (func $g6 (param i32 i32) local.get 0 drop)
    #|  (func $g7 (param i32 i32) local.get 0 drop)
    #|  (func $g8 (param i32 i32) local.get 0 drop)
    #|  (func (export "run1")
    #|    i32.const 0 i32.const 10 call $g0
    #|    i32.const 1 i32.const 11 call $g1
    #|    i32.const 2 i32.const 12 call $g2
    #|    i32.const 3 i32.const 13 call $g3
    #|    i32.const 4 i32.const 14 call $g4
    #|    i32.const 5 i32.const 15 call $g5
    #|    i32.const 6 i32.const 16 call $g6
    #|    i32.const 7 i32.const 17 call $g7
    #|    i32.const 8 i32.const 18 call $g8)
    #|  (func (export "run2")
    #|    i32.const 20 i32.const 30 call $g0
    #|    i32.const 21 i32.const 31 call $g1
    #|    i32.const 22 i32.const 32 call $g2
    #|    i32.const 23 i32.const 33 call $g3
    #|    i32.const 24 i32.const 34 call $g4
    #|    i32.const 25 i32.const 35 call $g5
    #|    i32.const 26 i32.const 36 call $g6
    #|    i32.const 27 i32.const 37 call $g7
    #|    i32.const 28 i32.const 38 call $g8))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  for def_idx = 0; def_idx < 9; def_idx = def_idx + 1 {
    @debug.assert_eq(dae_test_func_params(optimized, def_idx).length(), 1)
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected fully converged plain DAE output, got \{err}")
  }
}

///|
test "dae-optimizing core converges beyond the former eight-rewrite cap" {
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
  @debug.assert_eq(dae_test_func_params(optimized, 8).length(), 0)
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
    "pass[dae-optimizing]:core-worklist iter=0 primary_def=0", "pass[dae-optimizing]:core-worklist iter=1 primary_def=1",
    "pass[dae-optimizing]:core-worklist iter=2 primary_def=2", "pass[dae-optimizing]:core-worklist iter=3 primary_def=3",
    "pass[dae-optimizing]:core-worklist iter=4 primary_def=4", "pass[dae-optimizing]:core-worklist iter=5 primary_def=5",
    "pass[dae-optimizing]:core-worklist iter=6 primary_def=6", "pass[dae-optimizing]:core-worklist iter=7 primary_def=7",
    "pass[dae-optimizing]:core-worklist iter=8 primary_def=8", "pass[dae-optimizing]:core-worklist iter=9 primary_def=9",
  ])
  @debug.assert_eq(reverse_trace, [])
}

///|
#skip("manual multi-phase scheduler replay; bounded frontier ordering remains covered by direct tests")
test "dae-optimizing converges before the reverse exact-literal wrapper lane" {
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
  @debug.assert_eq(reverse_trace, [])
  @debug.assert_eq(dae_test_func_params(optimized, 8).length(), 2)
  @debug.assert_eq(dae_test_func_params(optimized, 9).length(), 2)
  @debug.assert_eq(dae_test_func_params(optimized, 10).length(), 2)
}

///|
#skip("manual artifact-scale DAE scheduler fixture; bounded worklist behavior is covered by focused tests")
test "dae-optimizing batches low null-default candidates on broad modules" {
  let target_def = 164
  let total_defs = 4097
  let out = StringBuilder::new()
  out.write_string(
    (
      #|(module
      #|  (type $base (sub (struct)))
      #|  (type $leaf (sub final $base (struct)))
      #|  (type $variant (sub final (struct (field i32) (field (ref null $base)))))
      #|  (global $variant (ref $variant)
      #|    i32.const 0
      #|    ref.null $base
      #|    struct.new $variant)
      #|  (import "env" "use_i32" (func $use_i32 (param i32)))
      #|  (import "env" "use_ref" (func $use_ref (param (ref null $base))))
    ),
  )
  for i = 0; i < 8; i = i + 1 {
    out.write_string(
      "  (func $g\{i} (param i32 i32)\n    local.get 0\n    drop)\n",
    )
  }
  for i = 8; i < 36; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $chain-entry (param i32)
      #|    local.get 0
      #|    struct.new_default $leaf
      #|    global.get $variant
      #|    call $chain0)
      #|  (func $chain0
      #|    (param i32 (ref $base) (ref $variant))
      #|    (local (ref null $base))
      #|    local.get 2
      #|    struct.get $variant 0
      #|    i32.const 1
      #|    i32.eq
      #|    if (result (ref null $base))
      #|      local.get 2
      #|      struct.get $variant 1
      #|    else
      #|      ref.null $base
      #|    end
      #|    local.set 3
      #|    local.get 0
      #|    local.get 1
      #|    local.get 3
      #|    call $chain1)
      #|  (func $chain1
      #|    (param i32 (ref $base) (ref null $base))
      #|    (local i32)
      #|    i32.const 9
      #|    local.set 3
      #|    block
      #|      local.get 3
      #|      drop
      #|    end
      #|    local.get 0
      #|    local.get 1
      #|    local.get 2
      #|    call $chain2)
      #|  (func $wrap1 (result (ref null $base))
      #|    ref.null $leaf
      #|    ref.null $leaf
      #|    ref.null $leaf
      #|    ref.null $leaf
      #|    ref.null $leaf
      #|    ref.null $leaf
      #|    ref.null $leaf
      #|    ref.null $leaf
      #|    ref.null $leaf
      #|    ref.null $leaf
      #|    call $target)
      #|  (func $pad40)
      #|  (func $chain2
      #|    (param i32 (ref $base) (ref null $base))
      #|    local.get 2
      #|    ref.is_null
      #|    drop
      #|    local.get 0
      #|    call $use_i32
      #|    local.get 1
      #|    call $use_ref)
      #|  (func $wrap2 (result (ref null $base))
      #|    call $wrap1)
      #|  (func $wrap3 (result (ref null $base))
      #|    call $wrap2)
      #|  (func $top (result i32)
      #|    call $wrap3
      #|    ref.is_null)
    ),
  )
  for i = 45; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target
      #|    (param (ref null $leaf) (ref null $leaf) (ref null $leaf) (ref null $leaf) (ref null $leaf))
      #|    (param (ref null $leaf) (ref null $leaf) (ref null $leaf) (ref null $leaf) (ref null $leaf))
      #|    (result (ref null $base))
      #|    (local
    ),
  )
  for i = 0; i < 10; i = i + 1 {
    out.write_string("      (ref $leaf) (ref null $leaf)\n")
  }
  out.write_string("    )\n")
  for p = 0; p < 10; p = p + 1 {
    let result_local = 10 + p * 2
    let scratch_local = result_local + 1
    out.write_string(
      "    local.get \{p}\n    ref.is_null\n    if (result (ref $leaf))\n      struct.new $leaf\n    else\n      local.get \{p}\n      local.tee \{scratch_local}\n      ref.as_non_null\n    end\n    local.set \{result_local}\n",
    )
  }
  for p = 0; p < 10; p = p + 1 {
    out.write_string("    local.get \{10 + p * 2}\n")
  }
  out.write_string("    call $sink)\n")
  out.write_string(
    "  (func $sink (param (ref $leaf) (ref $leaf) (ref $leaf) (ref $leaf) (ref $leaf))\n",
  )
  out.write_string(
    "    (param (ref $leaf) (ref $leaf) (ref $leaf) (ref $leaf) (ref $leaf))\n    (result (ref null $base))\n",
  )
  for p = 0; p < 10; p = p + 1 {
    out.write_string("    local.get \{p}\n    drop\n")
  }
  out.write_string("    struct.new $leaf)\n")
  for i = target_def + 2; i + 1 < total_defs; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func (export "run") (param i32) (result i32)
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
      #|    local.get 0
      #|    call $chain-entry
      #|    call $top)
      #|)
    ),
  )
  let source = out.to_string()
  let optimized = dae_test_run(source)
  let plain = dae_test_run(source, pass_name="dead-argument-elimination")
  @debug.assert_eq(dae_test_func_params(plain, 37).length(), 3)
  @debug.assert_eq(dae_test_func_params(plain, 38).length(), 3)
  @debug.assert_eq(dae_test_func_params(plain, 41).length(), 3)
  let plain_chain0 = plain.pretty_print_defined_func(37U)
  assert_true(plain_chain0.contains("local.get (Local 2)"), msg=plain_chain0)
  assert_true(plain_chain0.contains("if"), msg=plain_chain0)
  @debug.assert_eq(dae_test_func_params(optimized, target_def).length(), 0)
  let exact_leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=true,
    ),
  )
  let chain_trace = match pass_test_capture_trace(source, ["dae-optimizing"]) {
    Ok(trace) => trace
    Err(err) => fail("expected traced broad-module DAE success, got \{err}")
  }
  assert_true(
    chain_trace.contains(
      "pass[dae-optimizing]:direct-gc-batch wave=0 first_def=37",
    ),
    msg=chain_trace.to_string(),
  )
  assert_false(
    chain_trace.any(fn(line) { line.contains("low-exact-param-chain") }),
    msg=chain_trace.to_string(),
  )
  @debug.assert_eq(dae_test_func_results(optimized, target_def), [exact_leaf])
  @debug.assert_eq(dae_test_func_results(optimized, 43), [exact_leaf])
  @debug.assert_eq(dae_test_func_results(optimized, 42), [exact_leaf])
  @debug.assert_eq(dae_test_func_results(optimized, 39), [exact_leaf])
  assert_true(
    dae_test_func_params(optimized, 37).length() == 2,
    msg=optimized.pretty_print_defined_func(37U),
  )
  @debug.assert_eq(dae_test_func_params(optimized, 37)[1], exact_leaf)
  assert_true(
    dae_test_func_params(optimized, 38).length() == 2,
    msg=optimized.pretty_print_defined_func(38U),
  )
  @debug.assert_eq(dae_test_func_params(optimized, 38)[1], exact_leaf)
  assert_true(
    dae_test_func_params(optimized, 41).length() == 2,
    msg=optimized.pretty_print_defined_func(41U),
  )
  @debug.assert_eq(dae_test_func_params(optimized, 41)[1], exact_leaf)
  let chain2 = optimized.pretty_print_defined_func(41U)
  assert_false(chain2.contains("local.set"), msg=chain2)
  let @lib.Func(target_locals, _) = dae_test_defined_func(optimized, target_def)
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  assert_true(target_locals.length() == 0, msg=target)
  assert_false(target.contains("if"), msg=target)
  assert_false(target.contains("local.get"), msg=target)
  assert_true(
    chain_trace.contains(
      "pass[dae-optimizing]:low-exact-literal-worklist iter=0 primary_def=164",
    ),
    msg=chain_trace.to_string(),
  )
  for
    expected in [
      "pass[dae-optimizing]:direct-gc-batch wave=0 first_def=37", "pass[dae-optimizing]:direct-gc-batch wave=1 first_def=164",
      "pass[dae-optimizing]:direct-gc-batch wave=2 first_def=39", "pass[dae-optimizing]:direct-gc-batch wave=3 first_def=42",
    ] {
    assert_true(chain_trace.contains(expected), msg=chain_trace.to_string())
  }
  assert_false(
    chain_trace.contains("pass[dae-optimizing]:direct-gc-batch wave=4"),
    msg=chain_trace.to_string(),
  )
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected broad-module low-candidate output to validate, got \{err}")
  }
}

///|
#skip("manual aggregate DAE boundary sweep; representative wrapper revisits remain in bounded tests")
test "dae-optimizing revisits wrapper boundaries for unread callee params" {
  for
    boundary_def in [
      128, 131, 133, 135, 142, 143, 144, 145, 146, 148, 149, 151, 152, 157, 158,
      159, 161, 162, 167, 170, 175, 176, 177, 178, 180, 181, 182, 184, 186, 187,
      188, 189, 191, 196,
    ] {
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
        "pass[dae-optimizing]:core-worklist iter=8 primary_def=\{boundary_def + 1}",
      ),
      msg=trace.to_string(),
    )
  }
}

///|
#skip("manual artifact-derived public replay; unchanged-boundary control behavior has bounded coverage")
test "dae-optimizing preserves Binaryen constant result-if without a DAE boundary change" {
  let target_def = 233
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < 8; i = i + 1 {
    out.write_string(
      "  (func $g\{i} (param i32 i32)\n    local.get 0\n    drop)\n",
    )
  }
  for i = 8; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (result i32)
      #|    i32.const 0
      #|    i32.const 0
      #|    i32.eq
      #|    if (result i32)
      #|      call $zero
      #|    else
      #|      call $one
      #|    end)
      #|  (func $one (result i32) i32.const 1)
      #|  (func $zero (result i32) i32.const 0)
      #|  (func (export "run") (result i32)
    ),
  )
  for i = 0; i < 8; i = i + 1 {
    out.write_string("    i32.const 1\n    i32.const 2\n    call $g\{i}\n")
  }
  out.write_string(
    (
      #|    call $target)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  assert_true(target.contains("(call (Func \{target_def + 2}))"), msg=target)
  assert_true(target.contains("if"), msg=target)
  assert_true(target.contains("i32.eq"), msg=target)
}

///|
#skip("manual artifact-derived public replay; touched local cleanup has bounded direct coverage")
test "dae-optimizing retargets selected Func236 temporary locals and strips Binaryen-removed debris" {
  let target_def = 236
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < 8; i = i + 1 {
    out.write_string(
      "  (func $g\{i} (param i32 i32)\n    local.get 0\n    drop)\n",
    )
  }
  for i = 8; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (param i32 i32 i32 i32) (result i32)
      #|    (local i32 i32 i32 i32 i32 i32)
      #|    nop
      #|    local.get 1
      #|    local.set 6
      #|    local.get 2
      #|    local.set 8
      #|    i32.const 0
      #|    drop
      #|    local.get 6
      #|    local.get 8
      #|    i32.add
      #|    local.set 9
      #|    local.get 9)
      #|  (func (export "run") (result i32)
    ),
  )
  for i = 0; i < 8; i = i + 1 {
    out.write_string("    i32.const 1\n    i32.const 2\n    call $g\{i}\n")
  }
  out.write_string(
    (
      #|    i32.const 1
      #|    i32.const 2
      #|    i32.const 3
      #|    i32.const 4
      #|    call $target)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  assert_false(target.contains("(local)"), msg=target)
  assert_false(target.contains("nop"), msg=target)
  assert_false(target.contains("drop"), msg=target)
  assert_false(target.contains("Local6"), msg=target)
  assert_false(target.contains("Local8"), msg=target)
  assert_false(target.contains("Local9"), msg=target)
}

///|
#skip("manual artifact-derived public replay; exported loop-carrier preservation remains covered")
test "dae-optimizing preserves exported Func256 loop carriers like Binaryen" {
  let target_def = 256
  let out = StringBuilder::new()
  out.write_string("(module\n  (type $loop (func (param i32)))\n  (memory 1)\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (export "target") (param i32 i32)
      #|    (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
      #|    i32.const 0
      #|    loop (type $loop)
      #|      local.tee 11
      #|      local.get 1
      #|      i32.load offset=8 align=1
      #|      i32.lt_s
      #|      if
      #|        local.get 1
      #|        i32.load offset=12 align=1
      #|        local.get 11
      #|        i32.const 2
      #|        i32.shl
      #|        i32.add
      #|        i32.load offset=8 align=1
      #|        local.set 12
      #|        local.get 0
      #|        call $side
      #|        local.get 12
      #|        call $side
      #|        local.get 0
      #|        local.get 12
      #|        call $effect
      #|        drop
      #|        local.get 11
      #|        i32.const 1
      #|        i32.add
      #|        br 1
      #|      else
      #|        local.get 0
      #|        call $side2
      #|        local.get 1
      #|        call $side2
      #|      end
      #|    end
      #|    i32.const 0
      #|    drop)
      #|  (func $side (param i32))
      #|  (func $side2 (param i32))
      #|  (func $effect (param i32 i32) (result i32)
      #|    i32.const 0)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  let @lib.Func(locals, @lib.Expr(body)) = dae_test_defined_func(
    optimized, target_def,
  )
  @debug.assert_eq(locals.length(), 11)
  assert_true(
    dae_test_instrs_reference_local(body, @lib.LocalIdx::new(11U)),
    msg=target,
  )
  assert_true(
    dae_test_instrs_reference_local(body, @lib.LocalIdx::new(12U)),
    msg=target,
  )
  assert_false(
    dae_test_instrs_reference_local(body, @lib.LocalIdx::new(13U)),
    msg=target,
  )
  assert_true(target.contains("i32.lt_s"), msg=target)
  assert_true(target.contains("local.tee"), msg=target)
}

///|
#skip("manual artifact-derived public replay; exported loop-carrier preservation remains covered")
test "dae-optimizing preserves exported Func298 loop carriers like Binaryen" {
  let target_def = 298
  let out = StringBuilder::new()
  out.write_string("(module\n  (memory 1)\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (export "target") (param i32 i32)
      #|    (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
      #|    i32.const 0
      #|    loop (param i32)
      #|      local.tee 11
      #|      local.get 0
      #|      i32.load offset=8 align=1
      #|      i32.lt_s
      #|      if
      #|        local.get 0
      #|        i32.load offset=12 align=1
      #|        local.get 11
      #|        i32.const 2
      #|        i32.shl
      #|        i32.add
      #|        i32.load offset=8 align=1
      #|        local.set 12
      #|        local.get 1
      #|        call $side
      #|        local.get 12
      #|        call $side
      #|        local.get 12
      #|        local.get 1
      #|        call $eq
      #|        if
      #|          local.get 1
      #|          call $side
      #|          local.get 0
      #|          call $side
      #|          i32.const 0
      #|          return
      #|        end
      #|        i32.const 0
      #|        drop
      #|        local.get 11
      #|        i32.const 1
      #|        i32.add
      #|        br 1
      #|      end
      #|    end
      #|    i32.const 0
      #|    drop
      #|    local.get 0
      #|    local.get 1
      #|    call $cleanup
      #|    drop)
      #|  (func $side (param i32))
      #|  (func $eq (param i32 i32) (result i32)
      #|    i32.const 0)
      #|  (func $cleanup (param i32 i32) (result i32)
      #|    i32.const 0)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  let @lib.Func(locals, @lib.Expr(body)) = dae_test_defined_func(
    optimized, target_def,
  )
  @debug.assert_eq(locals.length(), 11)
  assert_true(
    dae_test_instrs_reference_local(body, @lib.LocalIdx::new(11U)),
    msg=target,
  )
  assert_true(
    dae_test_instrs_reference_local(body, @lib.LocalIdx::new(12U)),
    msg=target,
  )
  assert_false(
    dae_test_instrs_reference_local(body, @lib.LocalIdx::new(13U)),
    msg=target,
  )
  assert_true(target.contains("i32.lt_s"), msg=target)
  assert_true(target.contains("local.tee"), msg=target)
}

///|
#skip("manual artifact-derived public replay; unchanged exported-control behavior remains covered")
test "dae-optimizing preserves exported Func299 inverted result-if like Binaryen" {
  let target_def = 299
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (export "target") (param i32 i32)
      #|    (local i32)
      #|    local.get 1
      #|    call $side
      #|    local.get 0
      #|    call $side
      #|    local.get 0
      #|    local.get 1
      #|    call $check
      #|    i32.eqz
      #|    if (result i32)
      #|      local.get 0
      #|      local.get 1
      #|      call $slow
      #|    else
      #|      local.get 1
      #|      call $release
      #|      local.get 0
      #|      call $release
      #|      i32.const 0
      #|    end
      #|    drop)
      #|  (func $side (param i32))
      #|  (func $check (param i32 i32) (result i32)
      #|    i32.const 1)
      #|  (func $slow (param i32 i32) (result i32)
      #|    i32.const 7)
      #|  (func $release (param i32))
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  let @lib.Func(locals, _) = dae_test_defined_func(optimized, target_def)
  @debug.assert_eq(locals.length(), 1)
  assert_true(target.contains("i32.eqz"), msg=target)
  assert_true(target.contains("(call (Func \{target_def + 1}))"), msg=target)
  assert_true(target.contains("(call (Func \{target_def + 2}))"), msg=target)
  assert_true(target.contains("(call (Func \{target_def + 3}))"), msg=target)
}

///|
#skip("manual artifact-derived cleanup replay; terminal call-argument cleanup has bounded coverage")
test "dae-optimizing inlines touched staged terminal call args" {
  let target_def = 711
  let out = StringBuilder::new()
  out.write_string("(module\n  (memory 1)\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (export "target") (param i32 i32 i32 i32) (result i32)
      #|    (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i64 i64 i64 i64 i64)
      #|    local.get 0
      #|    i32.const 0
      #|    i32.eq
      #|    if (result i32)
      #|      local.get 0
      #|      if
      #|        local.get 0
      #|        call $release
      #|      end
      #|      i32.const 10016
      #|      local.set 18
      #|      i32.const 8
      #|      call $alloc
      #|      local.tee 22
      #|      i32.const 1573120
      #|      i32.store offset=4 align=1
      #|      local.get 22
      #|      i32.const 0
      #|      i32.store offset=8 align=1
      #|      local.get 22
      #|      local.get 18
      #|      i32.store offset=12 align=1
      #|      local.get 22
      #|    else
      #|      local.get 0
      #|    end
      #|    local.set 4
      #|    local.get 1
      #|    i32.const 0
      #|    i32.eq
      #|    if (result i32)
      #|      local.get 1
      #|      if
      #|        local.get 1
      #|        call $release
      #|      end
      #|      i32.const 10016
      #|      local.set 17
      #|      i32.const 8
      #|      call $alloc
      #|      local.tee 21
      #|      i32.const 1573120
      #|      i32.store offset=4 align=1
      #|      local.get 21
      #|      i32.const 0
      #|      i32.store offset=8 align=1
      #|      local.get 21
      #|      local.get 17
      #|      i32.store offset=12 align=1
      #|      local.get 21
      #|    else
      #|      local.get 1
      #|    end
      #|    local.set 6
      #|    local.get 2
      #|    i32.const 0
      #|    i32.eq
      #|    if (result i32)
      #|      local.get 2
      #|      if
      #|        local.get 2
      #|        call $release
      #|      end
      #|      i32.const 10016
      #|      local.set 16
      #|      i32.const 8
      #|      call $alloc
      #|      local.tee 20
      #|      i32.const 1573120
      #|      i32.store offset=4 align=1
      #|      local.get 20
      #|      i32.const 0
      #|      i32.store offset=8 align=1
      #|      local.get 20
      #|      local.get 16
      #|      i32.store offset=12 align=1
      #|      local.get 20
      #|    else
      #|      local.get 2
      #|    end
      #|    local.set 8
      #|    i64.const 4294967296
      #|    i64.const 4294967296
      #|    i64.eq
      #|    if (result i32)
      #|      i32.const 0
      #|    else
      #|      i64.const 4294967296
      #|      i32.wrap_i64
      #|    end
      #|    local.set 10
      #|    i64.const 4294967296
      #|    i64.const 4294967296
      #|    i64.eq
      #|    if (result i32)
      #|      i32.const 0
      #|    else
      #|      i64.const 4294967296
      #|      i32.wrap_i64
      #|    end
      #|    local.set 11
      #|    i32.const -1
      #|    i32.const -1
      #|    i32.eq
      #|    if (result i32)
      #|      i32.const 0
      #|    else
      #|      i32.const -1
      #|    end
      #|    local.set 12
      #|    i64.const 4294967296
      #|    i64.const 4294967296
      #|    i64.eq
      #|    if (result i32)
      #|      i32.const 5
      #|    else
      #|      i64.const 4294967296
      #|      i32.wrap_i64
      #|    end
      #|    local.set 13
      #|    i32.const -1
      #|    i32.const -1
      #|    i32.eq
      #|    if (result i32)
      #|      i32.const 0
      #|    else
      #|      i32.const -1
      #|    end
      #|    local.set 14
      #|    local.get 3
      #|    call $check
      #|    i32.const 1
      #|    i32.eq
      #|    if (result i64)
      #|      local.get 3
      #|      i64.load offset=8 align=1
      #|      local.set 27
      #|      local.get 3
      #|      call $release
      #|      local.get 27
      #|    else
      #|      local.get 3
      #|      call $release
      #|      i64.const 1024
      #|    end
      #|    local.set 26
      #|    local.get 4
      #|    local.get 6
      #|    local.get 8
      #|    local.get 10
      #|    local.get 11
      #|    local.get 12
      #|    local.get 13
      #|    local.get 14
      #|    local.get 26
      #|    call $callee)
      #|  (func $callee (param i32 i32 i32 i32 i32 i32 i32 i32 i64) (result i32)
      #|    local.get 0
      #|    drop
      #|    local.get 1
      #|    drop
      #|    local.get 2
      #|    drop
      #|    local.get 3
      #|    drop
      #|    local.get 4
      #|    drop
      #|    local.get 5
      #|    drop
      #|    local.get 6
      #|    drop
      #|    local.get 7
      #|    drop
      #|    local.get 8
      #|    drop
      #|    i32.const 7)
      #|  (func $release (param i32))
      #|  (func $alloc (param i32) (result i32)
      #|    i32.const 16)
      #|  (func $check (param i32) (result i32)
      #|    i32.const 1)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  let @lib.Func(locals, @lib.Expr(body)) = dae_test_defined_func(
    optimized, target_def,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i64()]))
  for slot in [5, 6, 8, 10, 11, 12, 13, 14, 16, 17, 18, 20, 21, 22, 26, 27] {
    assert_false(
      dae_test_instrs_reference_local(
        body,
        @lib.LocalIdx::new(slot.reinterpret_as_uint()),
      ),
      msg=target,
    )
  }
  assert_false(target.contains("i64.eq"), msg=target)
  assert_false(target.contains("i32.wrap_i64"), msg=target)
  assert_false(target.contains("local.set (Local26)"), msg=target)
  assert_true(target.contains("local.tee (Local 0)"), msg=target)
  assert_true(target.contains("local.set (Local 4)"), msg=target)
  assert_true(target.contains("(call (Func \{target_def + 1}))"), msg=target)
}

///|
#skip("manual artifact-derived cleanup replay; typed local remapping has bounded direct coverage")
test "dae-optimizing remaps a touched final i64 temp to Binaryen local" {
  let target_def = 711
  let out = StringBuilder::new()
  out.write_string("(module\n  (memory 1)\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (export "target") (param i32 i32 i32 i32) (result i32)
      #|    (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i64 i64 i64 i64 i64)
      #|    local.get 0
      #|    local.get 1
      #|    local.get 2
      #|    i32.const 0
      #|    i32.const 0
      #|    i32.const 0
      #|    i32.const 5
      #|    i32.const 0
      #|    local.get 3
      #|    call $check
      #|    i32.const 1
      #|    i32.eq
      #|    if (result i64)
      #|      local.get 3
      #|      i64.load offset=8 align=1
      #|      local.set 26
      #|      local.get 3
      #|      call $release
      #|      local.get 26
      #|    else
      #|      local.get 3
      #|      call $release
      #|      i64.const 1024
      #|    end
      #|    call $callee)
      #|  (func $callee (param i32 i32 i32 i32 i32 i32 i32 i32 i64) (result i32)
      #|    local.get 8
      #|    drop
      #|    i32.const 7)
      #|  (func $release (param i32))
      #|  (func $check (param i32) (result i32)
      #|    i32.const 1)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  let @lib.Func(locals, @lib.Expr(body)) = dae_test_defined_func(
    optimized, target_def,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i64()]))
  assert_false(
    dae_test_instrs_reference_local(body, @lib.LocalIdx::new(26U)),
    msg=target,
  )
  assert_true(target.contains("local.set (Local 4)"), msg=target)
}

///|
#skip("manual artifact-derived cleanup replay; terminal call-family cleanup has bounded coverage")
test "dae-optimizing inlines a second touched staged terminal call family" {
  let target_def = 713
  let out = StringBuilder::new()
  out.write_string("(module\n  (memory 1)\n  (global $g i32 (i32.const 42))\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (export "target") (param i32 i32 i32 i32 i32 i32 i32) (result i32)
      #|    (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
      #|    local.get 0
      #|    i32.const 0
      #|    i32.eq
      #|    if (result i32)
      #|      local.get 0
      #|      if
      #|        local.get 0
      #|        call $release
      #|      end
      #|      i32.const 1000
      #|    else
      #|      local.get 0
      #|    end
      #|    local.set 7
      #|    local.get 1
      #|    i32.const 0
      #|    i32.eq
      #|    if (result i32)
      #|      local.get 1
      #|      if
      #|        local.get 1
      #|        call $release
      #|      end
      #|      i32.const 1001
      #|    else
      #|      local.get 1
      #|    end
      #|    local.set 9
      #|    local.get 2
      #|    i32.const 0
      #|    i32.eq
      #|    if (result i32)
      #|      local.get 2
      #|      if
      #|        local.get 2
      #|        call $release
      #|      end
      #|      i32.const 1002
      #|    else
      #|      local.get 2
      #|    end
      #|    local.set 11
      #|    local.get 3
      #|    i32.const 0
      #|    i32.eq
      #|    if (result i32)
      #|      local.get 3
      #|      if
      #|        local.get 3
      #|        call $release
      #|      end
      #|      i32.const 1003
      #|    else
      #|      local.get 3
      #|    end
      #|    local.set 13
      #|    local.get 4
      #|    i32.const 0
      #|    i32.eq
      #|    if (result i32)
      #|      local.get 4
      #|      if
      #|        local.get 4
      #|        call $release
      #|      end
      #|      i32.const 1004
      #|    else
      #|      local.get 4
      #|    end
      #|    local.set 15
      #|    local.get 5
      #|    i32.const 0
      #|    i32.eq
      #|    if (result i32)
      #|      local.get 5
      #|      if
      #|        local.get 5
      #|        call $release
      #|      end
      #|      i32.const 1005
      #|    else
      #|      local.get 5
      #|    end
      #|    local.set 17
      #|    local.get 6
      #|    i32.const 0
      #|    i32.eq
      #|    if (result i32)
      #|      local.get 6
      #|      if
      #|        local.get 6
      #|        call $release
      #|      end
      #|      i32.const 1006
      #|    else
      #|      local.get 6
      #|    end
      #|    local.set 19
      #|    global.get $g
      #|    i32.const 0
      #|    i32.eq
      #|    if (result i32)
      #|      global.get $g
      #|      if
      #|        global.get $g
      #|        call $release
      #|      end
      #|      i32.const 1007
      #|    else
      #|      global.get $g
      #|    end
      #|    local.set 21
      #|    i32.const 0
      #|    i32.const 0
      #|    i32.eq
      #|    if (result i32)
      #|      i32.const 0
      #|      if
      #|        i32.const 0
      #|        call $release
      #|      end
      #|      i32.const 1008
      #|    else
      #|      i32.const 0
      #|    end
      #|    local.set 23
      #|    local.get 7
      #|    local.get 9
      #|    local.get 11
      #|    local.get 13
      #|    local.get 15
      #|    local.get 17
      #|    local.get 19
      #|    local.get 21
      #|    local.get 23
      #|    call $callee)
      #|  (func $callee (param i32 i32 i32 i32 i32 i32 i32 i32 i32) (result i32)
      #|    local.get 0
      #|    drop
      #|    local.get 1
      #|    drop
      #|    local.get 2
      #|    drop
      #|    local.get 3
      #|    drop
      #|    local.get 4
      #|    drop
      #|    local.get 5
      #|    drop
      #|    local.get 6
      #|    drop
      #|    local.get 7
      #|    drop
      #|    local.get 8
      #|    drop
      #|    i32.const 7)
      #|  (func $release (param i32))
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  let @lib.Func(locals, @lib.Expr(body)) = dae_test_defined_func(
    optimized, target_def,
  )
  @debug.assert_eq(locals.length(), 0)
  for slot in [7, 9, 11, 13, 15, 17, 19, 21, 23] {
    assert_false(
      dae_test_instrs_reference_local(
        body,
        @lib.LocalIdx::new(slot.reinterpret_as_uint()),
      ),
      msg=target,
    )
  }
  assert_false(target.contains("local.set (Local7)"), msg=target)
  assert_false(target.contains("i32.eq"), msg=target)
  assert_true(target.contains("(call (Func \{target_def + 1}))"), msg=target)
}

///|
#skip("manual artifact-derived cleanup replay; suffix block cleanup remains covered by bounded tests")
test "dae-optimizing unwraps a touched suffix staging block" {
  let target_def = 713
  let out = StringBuilder::new()
  out.write_string("(module\n  (memory 1)\n  (global $g i32 (i32.const 42))\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (export "target") (param i32 i32 i32 i32 i32 i32 i32) (result i32)
      #|    (local i32 i32)
      #|    local.get 0
      #|    local.get 1
      #|    local.get 2
      #|    local.get 3
      #|    local.get 4
      #|    local.get 5
      #|    block (result i32)
      #|      local.get 6
      #|      if (result i32)
      #|        local.get 6
      #|      else
      #|        local.get 6
      #|        if
      #|          local.get 6
      #|          call $release
      #|        end
      #|        i32.const 1006
      #|      end
      #|      local.set 8
      #|      global.get $g
      #|      if (result i32)
      #|        global.get $g
      #|      else
      #|        global.get $g
      #|        if
      #|          global.get $g
      #|          call $release
      #|        end
      #|        i32.const 1007
      #|      end
      #|      local.set 7
      #|      i32.const 0
      #|      if
      #|        i32.const 0
      #|        call $release
      #|      end
      #|      local.get 8
      #|    end
      #|    local.get 7
      #|    i32.const 1008
      #|    call $callee)
      #|  (func $callee (param i32 i32 i32 i32 i32 i32 i32 i32 i32) (result i32)
      #|    local.get 6
      #|    drop
      #|    local.get 7
      #|    drop
      #|    local.get 8
      #|    drop
      #|    i32.const 7)
      #|  (func $release (param i32))
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  let @lib.Func(locals, @lib.Expr(body)) = dae_test_defined_func(
    optimized, target_def,
  )
  assert_false(locals.length() != 0, msg=target)
  assert_false(target.contains("block"), msg=target)
  assert_false(target.contains("local.set (Local7)"), msg=target)
  assert_false(target.contains("local.set (Local8)"), msg=target)
  assert_false(
    dae_test_instrs_reference_local(body, @lib.LocalIdx::new(7U)),
    msg=target,
  )
  assert_false(
    dae_test_instrs_reference_local(body, @lib.LocalIdx::new(8U)),
    msg=target,
  )
  assert_true(target.contains("global.get"), msg=target)
  assert_true(target.contains("(call (Func \{target_def + 1}))"), msg=target)
}

///|
#skip("manual artifact-derived component replay; single-caller global specialization has bounded coverage")
test "dae-optimizing specializes a single-caller global suffix component" {
  let caller_def = 813
  let callee_def = 823
  let out = StringBuilder::new()
  out.write_string("(module\n  (global $g i32 (i32.const 169472))\n")
  for i = 0; i < caller_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $caller (export "caller") (param i32 i32 i32 i32 i32 i32 i32) (result i32)
      #|    local.get 0
      #|    local.get 1
      #|    local.get 2
      #|    local.get 3
      #|    local.get 4
      #|    local.get 5
      #|    local.get 6
      #|    global.get $g
      #|    if (result i32)
      #|      global.get $g
      #|    else
      #|      global.get $g
      #|      if
      #|        global.get $g
      #|        call $release
      #|      end
      #|      i32.const 35880
      #|    end
      #|    i32.const 0
      #|    if
      #|      i32.const 0
      #|      call $release
      #|    end
      #|    i32.const 35864
      #|    call $callee)
    ),
  )
  for i = caller_def + 1; i < callee_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $callee (param i32 i32 i32 i32 i32 i32 i32 i32 i32) (result i32)
      #|    local.get 0
      #|    drop
      #|    local.get 1
      #|    drop
      #|    local.get 2
      #|    drop
      #|    local.get 3
      #|    drop
      #|    local.get 4
      #|    drop
      #|    local.get 5
      #|    drop
      #|    local.get 6
      #|    drop
      #|    local.get 7
      #|    local.get 8
      #|    i32.add)
      #|  (func $release (param i32))
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let caller = optimized.pretty_print_defined_func(
    caller_def.reinterpret_as_uint(),
  )
  let @lib.Func(locals, @lib.Expr(body)) = dae_test_defined_func(
    optimized, caller_def,
  )
  let @lib.FuncType(params, _) = dae_test_func_type(optimized, callee_def)
  @debug.assert_eq(params.length(), 7)
  assert_true(locals.length() == 0, msg=caller)
  assert_false(caller.contains("global.get"), msg=caller)
  assert_false(caller.contains("35864"), msg=caller)
  assert_false(caller.contains("block"), msg=caller)
  assert_false(
    dae_test_instrs_reference_local(body, @lib.LocalIdx::new(7U)),
    msg=caller,
  )
  assert_true(caller.contains("(call (Func \{callee_def}))"), msg=caller)
}

///|
#skip("manual artifact-scale DAE parity fixture; focused transform behavior remains in bounded tests")
test "dae-optimizing specializes selected Func326 zero actual after bounded core candidates" {
  let caller_def = 317
  let target_def = 326
  let total_defs = 1025
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < 9; i = i + 1 {
    out.write_string(
      "  (func $early\{i} (param i32) (result i32) local.get 0)\n",
    )
  }
  for i = 9; i < caller_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string("  (func $caller (export \"caller\") (result i32)\n")
  for i = 0; i < 9; i = i + 1 {
    out.write_string("    i32.const 0\n    call $early\{i}\n    drop\n")
  }
  out.write_string(
    (
      #|    i32.const 0
      #|    call $target)
    ),
  )
  for i = caller_def + 1; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string("  (func $target (param i32) (result i32) local.get 0)\n")
  for i = target_def + 1; i < total_defs; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(")")
  let optimized = dae_test_run(out.to_string())
  let caller = optimized.pretty_print_defined_func(
    caller_def.reinterpret_as_uint(),
  )
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  let @lib.FuncType(params, _) = dae_test_func_type(optimized, target_def)
  @debug.assert_eq(params.length(), 0)
  assert_true(target.contains("I32(0)"), msg=target)
  assert_false(target.contains("local.get"), msg=target)
  assert_true(caller.contains("(call (Func \{target_def}))"), msg=caller)
  assert_false(
    caller.contains("(i32.const 0)\n  (call (Func \{target_def}))"),
    msg=caller,
  )
}

///|
test "dae-optimizing materializes selected Func260 helper exact literals" {
  for target_def in [267, 268] {
    let out = StringBuilder::new()
    out.write_string("(module\n")
    for i = 0; i < 8; i = i + 1 {
      out.write_string(
        "  (func $g\{i} (param i32 i32)\n    local.get 0\n    drop)\n",
      )
    }
    for i = 8; i < target_def; i = i + 1 {
      out.write_string("  (func $pad\{i})\n")
    }
    if target_def == 268 {
      out.write_string(
        (
          #|  (func $target (param i32) (result i32)
          #|    local.get 0
          #|    i32.const 2
          #|    i32.eq
          #|    if (result i32)
          #|      i32.const 1
          #|    else
          #|      local.get 0
          #|      i32.const 3
          #|      i32.eq
          #|      if (result i32)
          #|        i32.const 1
          #|      else
          #|        local.get 0
          #|        i32.const 4
          #|        i32.eq
          #|        if (result i32)
          #|          i32.const 1
          #|        else
          #|          i32.const 0
          #|        end
          #|      end
          #|    end)
          #|  (func (export "run") (result i32)
        ),
      )
    } else {
      out.write_string(
        (
          #|  (func $target (param i32) (result i32)
          #|    local.get 0
          #|    i32.const 1
          #|    i32.eq)
          #|  (func (export "run") (result i32)
        ),
      )
    }
    for i = 0; i < 8; i = i + 1 {
      out.write_string("    i32.const 1\n    i32.const 2\n    call $g\{i}\n")
    }
    out.write_string(
      (
        #|    i32.const 0
        #|    call $target)
        #|)
      ),
    )
    let optimized = dae_test_run(out.to_string())
    @debug.assert_eq(dae_test_func_params(optimized, target_def).length(), 0)
    let target = optimized.pretty_print_defined_func(
      target_def.reinterpret_as_uint(),
    )
    assert_false(target.contains("if"), msg=target)
    let caller = optimized.pretty_print_defined_func(
      (target_def + 1).reinterpret_as_uint(),
    )
    assert_true(caller.contains("(call (Func \{target_def}))"), msg=caller)
    assert_false(caller.contains("i32.const I32(0)"), msg=caller)
  }
}

///|
test "dae-optimizing folds a changed terminal caller before default args" {
  let caller_def = 727
  let target_def = 728
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < caller_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $caller (export "run") (param i32 i32 i32 i32 i32 i32 i64 i32 i32 i32) (result i32)
      #|    local.get 0
      #|    local.get 1
      #|    local.get 2
      #|    local.get 3
      #|    i32.const -1
      #|    i32.const -1
      #|    i32.eq
      #|    if (result i32)
      #|      i32.const 0
      #|    else
      #|      i32.const -1
      #|    end
      #|    local.get 4
      #|    local.get 5
      #|    local.get 6
      #|    local.get 7
      #|    local.get 8
      #|    local.get 9
      #|    call $target)
      #|  (func $target (param i32 i32 i32 i32 i32 i32 i32 i64 i32 i32 i32) (result i32)
      #|    local.get 0
      #|    drop
      #|    local.get 1
      #|    drop
      #|    local.get 2
      #|    drop
      #|    local.get 3
      #|    drop
      #|    local.get 4
      #|    drop
      #|    local.get 5
      #|    drop
      #|    local.get 6
      #|    drop
      #|    local.get 7
      #|    drop
      #|    local.get 8
      #|    drop
      #|    local.get 9
      #|    drop
      #|    local.get 10
      #|    drop
      #|    local.get 0)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  @debug.assert_eq(dae_test_func_params(optimized, target_def).length(), 10)
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  assert_false(target.contains("drop"), msg=target)
  let caller = optimized.pretty_print_defined_func(
    caller_def.reinterpret_as_uint(),
  )
  assert_false(caller.contains("if"), msg=caller)
  assert_false(caller.contains("i32.const I32(-1)"), msg=caller)
}

///|
test "dae-optimizing lowers changed pure default wrappers to selects" {
  let caller_def = 727
  let out = StringBuilder::new()
  out.write_string("(module\n  (memory 1)\n")
  for i = 0; i < caller_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $caller (export "run") (param i64 i64 i32 i64 i32 i32 i32 i32) (result i32)
      #|    (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i64 i64 i64 i64 i64 i64)
      #|    local.get 0
      #|    i64.const 4294967296
      #|    i64.eq
      #|    if (result i32)
      #|      i32.const 0
      #|    else
      #|      local.get 0
      #|      i32.wrap_i64
      #|    end
      #|    local.get 1
      #|    i64.const 4294967296
      #|    i64.eq
      #|    if (result i32)
      #|      i32.const 0
      #|    else
      #|      local.get 1
      #|      i32.wrap_i64
      #|    end
      #|    local.get 2
      #|    i32.const 0
      #|    i32.eq
      #|    if (result i32)
      #|      local.get 2
      #|      if
      #|        local.get 2
      #|        call $release
      #|      end
      #|      call $default
      #|    else
      #|      local.get 2
      #|    end
      #|    local.get 3
      #|    i64.const 4294967296
      #|    i64.eq
      #|    if (result i32)
      #|      i32.const 5
      #|    else
      #|      local.get 3
      #|      i32.wrap_i64
      #|    end
      #|    local.get 4
      #|    i32.const -1
      #|    i32.eq
      #|    if (result i32)
      #|      i32.const 0
      #|    else
      #|      local.get 4
      #|    end
      #|    local.get 5
      #|    i32.const -1
      #|    i32.eq
      #|    if (result i32)
      #|      i32.const 0
      #|    else
      #|      local.get 5
      #|    end
      #|    local.get 6
      #|    call $check
      #|    i32.const 1
      #|    i32.eq
      #|    if (result i64)
      #|      local.get 6
      #|      i64.load offset=8 align=1
      #|      local.set 25
      #|      local.get 6
      #|      call $release
      #|      local.get 25
      #|    else
      #|      local.get 6
      #|      call $release
      #|      i64.const 1024
      #|    end
      #|    local.get 7
      #|    i32.const -1
      #|    i32.eq
      #|    if (result i32)
      #|      i32.const 0
      #|    else
      #|      local.get 7
      #|    end
      #|    call $zero
      #|    i32.const 1
      #|    call $target)
      #|  (func $target (param i32 i32 i32 i32 i32 i32 i64 i32 i32 i32) (result i32)
      #|    local.get 0
      #|    local.get 1
      #|    i32.add
      #|    local.get 2
      #|    i32.add
      #|    local.get 3
      #|    i32.add
      #|    local.get 4
      #|    i32.add
      #|    local.get 5
      #|    i32.add
      #|    local.get 6
      #|    i32.wrap_i64
      #|    i32.add
      #|    local.get 7
      #|    i32.add
      #|    local.get 8
      #|    i32.add
      #|    local.get 9
      #|    i32.add)
      #|  (func $release (param i32))
      #|  (func $default (result i32)
      #|    i32.const 100)
      #|  (func $check (param i32) (result i32)
      #|    i32.const 1)
      #|  (func $zero (result i32)
      #|    i32.const 0)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let caller = optimized.pretty_print_defined_func(
    caller_def.reinterpret_as_uint(),
  )
  let @lib.Func(locals, @lib.Expr(body)) = dae_test_defined_func(
    optimized, caller_def,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(dae_test_count_select_instrs(body), 6, msg=caller)
  assert_false(
    dae_test_instrs_reference_local(body, @lib.LocalIdx::new(25U)),
    msg=caller,
  )
  assert_true(caller.contains("local.set (Local 0)"), msg=caller)
}

///|
#skip("manual artifact-scale DAE parity fixture; focused transform behavior remains in bounded tests")
test "dae-optimizing folds selected Func1794 const-if locals before Func1795 default args" {
  let first_caller_def = 279
  let second_caller_def = 1794
  let target_def = 1795
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < first_caller_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $caller279 (export "run279") (param i32 i32 i32 i32 i32 i64 i32 i32 i32 i64 i64 i32 i32 i64) (result i32)
      #|    local.get 0
      #|    local.get 1
      #|    local.get 2
      #|    i32.const 0
      #|    i32.const 0
      #|    local.get 3
      #|    local.get 4
      #|    local.get 5
      #|    local.get 6
      #|    local.get 7
      #|    local.get 8
      #|    local.get 9
      #|    local.get 10
      #|    local.get 11
      #|    local.get 12
      #|    local.get 13
      #|    call $target)
    ),
  )
  for i = first_caller_def + 1; i < second_caller_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $caller1794 (export "run1794") (param i32 i32 i32 i32 i64 i32 i32 i32 i64 i64 i32 i32 i64) (result i32)
      #|    (local i32 i32 i32 i32 i32 i32 i32 i64 i32 i32 i32 i64 i64 i32 i32 i64)
      #|    local.get 0
      #|    local.set 13
      #|    local.get 1
      #|    local.set 14
      #|    i32.const -1
      #|    i32.const -1
      #|    i32.eq
      #|    if (result i32)
      #|      i32.const 0
      #|    else
      #|      i32.const -1
      #|    end
      #|    local.set 15
      #|    i32.const -1
      #|    i32.const -1
      #|    i32.eq
      #|    if (result i32)
      #|      i32.const 0
      #|    else
      #|      i32.const -1
      #|    end
      #|    local.set 16
      #|    i32.const -1
      #|    i32.const -1
      #|    i32.eq
      #|    if (result i32)
      #|      i32.const 0
      #|    else
      #|      i32.const -1
      #|    end
      #|    local.set 17
      #|    local.get 2
      #|    local.set 18
      #|    local.get 3
      #|    local.set 19
      #|    local.get 4
      #|    local.set 20
      #|    local.get 5
      #|    local.set 21
      #|    local.get 6
      #|    local.set 22
      #|    local.get 7
      #|    local.set 23
      #|    local.get 8
      #|    local.set 24
      #|    local.get 9
      #|    local.set 25
      #|    local.get 10
      #|    local.set 26
      #|    local.get 11
      #|    local.set 27
      #|    local.get 12
      #|    local.set 28
      #|    local.get 13
      #|    local.get 14
      #|    local.get 15
      #|    local.get 16
      #|    local.get 17
      #|    local.get 18
      #|    local.get 19
      #|    local.get 20
      #|    local.get 21
      #|    local.get 22
      #|    local.get 23
      #|    local.get 24
      #|    local.get 25
      #|    local.get 26
      #|    local.get 27
      #|    local.get 28
      #|    call $target)
      #|  (func $target (param i32 i32 i32 i32 i32 i32 i32 i64 i32 i32 i32 i64 i64 i32 i32 i64) (result i32)
      #|    local.get 0
      #|    drop
      #|    local.get 1
      #|    drop
      #|    local.get 2
      #|    drop
      #|    local.get 3
      #|    drop
      #|    local.get 4
      #|    drop
      #|    local.get 5
      #|    drop
      #|    local.get 6
      #|    drop
      #|    local.get 7
      #|    drop
      #|    local.get 8
      #|    drop
      #|    local.get 9
      #|    drop
      #|    local.get 10
      #|    drop
      #|    local.get 11
      #|    drop
      #|    local.get 12
      #|    drop
      #|    local.get 13
      #|    drop
      #|    local.get 14
      #|    drop
      #|    local.get 15
      #|    drop
      #|    local.get 0)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  @debug.assert_eq(dae_test_func_params(optimized, target_def).length(), 14)
  let first_caller = optimized.pretty_print_defined_func(
    first_caller_def.reinterpret_as_uint(),
  )
  assert_true(
    first_caller.contains("(call (Func \{target_def}))"),
    msg=first_caller,
  )
  let second_caller = optimized.pretty_print_defined_func(
    second_caller_def.reinterpret_as_uint(),
  )
  assert_false(second_caller.contains("if"), msg=second_caller)
  assert_false(second_caller.contains("i32.const I32(-1)"), msg=second_caller)
}

///|
#skip("manual large-module DAE artifact smoke; run through the dedicated fuzz/parity lane")
test "dae-optimizing removes selected Func3737 and Func3765 forwarded default argument" {
  let caller_def = 281
  let target_def = 3737
  let forwarded_def = 3765
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < caller_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $caller (export "run") (param i32 i32 i32) (result i32)
      #|    local.get 0
      #|    local.get 1
      #|    local.get 2
      #|    i32.const 1024
      #|    call $target
      #|    drop
      #|    drop
      #|    i32.const 7)
    ),
  )
  for i = caller_def + 1; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (param i32 i32 i32 i32) (result i32 i32)
      #|    local.get 0
      #|    local.get 1
      #|    local.get 2
      #|    local.get 3
      #|    call $forwarded)
    ),
  )
  for i = target_def + 1; i < forwarded_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $forwarded (param i32 i32 i32 i32) (result i32 i32)
      #|    local.get 0
      #|    drop
      #|    local.get 1
      #|    drop
      #|    local.get 2
      #|    drop
      #|    local.get 3
      #|    drop
      #|    i32.const 1
      #|    i32.const 2)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  @debug.assert_eq(dae_test_func_params(optimized, target_def).length(), 3)
  @debug.assert_eq(dae_test_func_params(optimized, forwarded_def).length(), 3)
  let caller = optimized.pretty_print_defined_func(
    caller_def.reinterpret_as_uint(),
  )
  assert_true(caller.contains("(call (Func \{target_def}))"), msg=caller)
  assert_false(caller.contains("i32.const I32(1024)"), msg=caller)
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  assert_true(target.contains("(call (Func \{forwarded_def}))"), msg=target)
  assert_false(target.contains("i32.const I32(1024)"), msg=target)
}

///|
#skip("manual artifact-scale DAE parity fixture; focused transform behavior remains in bounded tests")
test "dae-optimizing removes selected Func3737 wrapper default from folded multivalue callsite" {
  let caller_def = 281
  let target_def = 3737
  let forwarded_def = 3765
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < caller_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $caller (export "run") (param i32 i32 i32) (result i32)
      #|    (local i32 i32)
      #|    block (result i32 i32)
      #|      local.get 0
      #|      i32.const 0
      #|      local.get 2
      #|      local.set 4
      #|      local.set 3
      #|      local.tee 3
      #|      local.get 1
      #|      local.get 4
      #|      i32.const 1024
      #|      call $target
      #|    end
      #|    local.set 4
      #|    local.set 3
      #|    local.get 4
      #|    drop
      #|    local.get 3)
    ),
  )
  for i = caller_def + 1; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (param i32 i32 i32 i32) (result i32 i32)
      #|    local.get 0
      #|    local.get 1
      #|    local.get 2
      #|    local.get 3
      #|    call $forwarded
      #|    i32.const 9)
    ),
  )
  for i = target_def + 1; i < forwarded_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $forwarded (param i32 i32 i32 i32) (result i32)
      #|    local.get 0
      #|    drop
      #|    local.get 1
      #|    drop
      #|    local.get 2
      #|    drop
      #|    local.get 3
      #|    drop
      #|    i32.const 1)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  @debug.assert_eq(dae_test_func_params(optimized, target_def).length(), 3)
  @debug.assert_eq(dae_test_func_params(optimized, forwarded_def).length(), 3)
  let caller = optimized.pretty_print_defined_func(
    caller_def.reinterpret_as_uint(),
  )
  assert_true(caller.contains("(call (Func \{target_def}))"), msg=caller)
  assert_false(caller.contains("i32.const I32(1024)"), msg=caller)
}

///|
#skip("manual artifact-scale DAE parity fixture; focused transform behavior remains in bounded tests")
test "dae-optimizing removes selected Func1777 suffix default pointer" {
  let caller_def = 286
  let target_def = 1777
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (memory 1)\n")
  for i = 0; i < caller_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $caller (export "run") (param i32) (result i32)
      #|    local.get 0
      #|    i32.const 10000
      #|    call $target)
    ),
  )
  for i = caller_def + 1; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (param i32 i32) (result i32)
      #|    local.get 1
      #|    i32.load
      #|    drop
      #|    local.get 0)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  @debug.assert_eq(dae_test_func_params(optimized, target_def).length(), 1)
  let caller = optimized.pretty_print_defined_func(
    caller_def.reinterpret_as_uint(),
  )
  assert_true(caller.contains("(call (Func \{target_def}))"), msg=caller)
  assert_false(caller.contains("i32.const I32(10000)"), msg=caller)
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  assert_true(target.contains("i32.const I32(10000)"), msg=target)
}

///|
#skip("manual artifact-scale DAE parity fixture; focused transform behavior remains in bounded tests")
test "dae-optimizing compacts selected Func287 setup locals after default removal" {
  let wrap_def = 24
  let release_def = 28
  let caller_def = 287
  let make_def = 288
  let consume_def = 291
  let map_def = 4194
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (memory 1)\n")
  for i = 0; i < wrap_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $wrap (param i32 i32) (result i32)
      #|    local.get 0
      #|    local.get 1
      #|    i32.add)
    ),
  )
  for i = wrap_def + 1; i < release_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $release (param i32)
      #|    i32.const 0
      #|    local.get 0
      #|    i32.store)
    ),
  )
  for i = release_def + 1; i < caller_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $caller (export "run") (result i32)
      #|    (local i32 i32 i32 i32 i32 i32)
      #|    nop
      #|    i32.const 34264
      #|    call $make
      #|    call $map
      #|    local.tee 2
      #|    call $wrap
      #|    local.set 5
      #|    local.get 2
      #|    call $release
      #|    local.get 5
      #|    i32.const 11512
      #|    call $wrap
      #|    local.set 4
      #|    local.get 5
      #|    call $release
      #|    local.get 4
      #|    call $consume)
    ),
  )
  out.write_string(
    (
      #|  (func $make (result i32)
      #|    i32.const 7)
    ),
  )
  for i = make_def + 1; i < consume_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $consume (param i32) (result i32)
      #|    local.get 0)
    ),
  )
  for i = consume_def + 1; i < map_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $map (param i32) (result i32)
      #|    local.get 0)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let caller = optimized.pretty_print_defined_func(
    caller_def.reinterpret_as_uint(),
  )
  let @lib.Func(locals, _) = dae_test_defined_func(optimized, caller_def)
  @debug.assert_eq(locals.length(), 2)
  assert_false(caller.contains("nop"), msg=caller)
  assert_false(caller.contains("(Local 2)"), msg=caller)
  assert_false(caller.contains("(Local 4)"), msg=caller)
  assert_false(caller.contains("(Local 5)"), msg=caller)
  assert_true(caller.contains("(local.set (Local 1))"), msg=caller)
  assert_true(caller.contains("(local.tee (Local 0))"), msg=caller)
}

///|
test "dae-optimizing preserves exported Func288 switch carriers like Binaryen" {
  let caller_def = 288
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (memory 1)\n")
  for i = 0; i < caller_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    "  (func $caller (export \"run\") (result i32)\n    " +
    dae_test_many_i32_locals(118) +
    (
      #|
      #|    nop
      #|    i32.const 0
      #|    local.tee 15
      #|    i32.load offset=8 align=1
      #|    local.set 76
      #|    local.get 15
      #|    i32.load align=1
      #|    local.tee 91
      #|    drop
      #|    local.get 76
      #|    local.set 14
      #|    local.get 14)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let caller = optimized.pretty_print_defined_func(
    caller_def.reinterpret_as_uint(),
  )
  let @lib.Func(locals, _) = dae_test_defined_func(optimized, caller_def)
  @debug.assert_eq(locals.length(), 118)
  assert_true(caller.contains("nop"), msg=caller)
  assert_true(caller.contains("(Local 14)"), msg=caller)
  assert_true(caller.contains("(Local 15)"), msg=caller)
  assert_true(caller.contains("(Local 76)"), msg=caller)
  assert_true(caller.contains("(Local 91)"), msg=caller)
  assert_true(caller.contains("offset=U64(8)"), msg=caller)
}

///|
test "dae-optimizing preserves exported Func288 return wrapper like Binaryen" {
  let caller_def = 288
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < caller_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $caller (export "run") (result i32)
      #|    (local i32 i32 i32)
      #|    (block
      #|      (return
      #|        (block (result i32)
      #|          (block
      #|            br 2)
      #|          i32.const 7
      #|          br 0)))
      #|    i32.const 11)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let caller = optimized.pretty_print_defined_func(
    caller_def.reinterpret_as_uint(),
  )
  assert_true(caller.contains("(block I32"), msg=caller)
  assert_true(caller.contains("(br (Label 2))"), msg=caller)
  assert_true(caller.contains("return"), msg=caller)
}

///|
#skip("manual large-module DAE artifact smoke; run through the dedicated fuzz/parity lane")
test "dae-optimizing removes selected Func4368 zero default from Func289" {
  let caller_def = 289
  let target_def = 4368
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < caller_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $caller (export "run") (result i32)
      #|    i32.const 0
      #|    call $target)
    ),
  )
  for i = caller_def + 1; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (param i32) (result i32)
      #|    local.get 0
      #|    i32.eqz)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  @debug.assert_eq(dae_test_func_params(optimized, target_def).length(), 0)
  let caller = optimized.pretty_print_defined_func(
    caller_def.reinterpret_as_uint(),
  )
  assert_true(caller.contains("(call (Func \{target_def}))"), msg=caller)
  assert_false(caller.contains("i32.const I32(0)"), msg=caller)
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  assert_true(target.contains("i32.const I32(0)"), msg=target)
}

///|
#skip("manual large-module DAE artifact smoke; run through the dedicated fuzz/parity lane")
test "dae-optimizing removes selected Func4206 middle default before call-produced actual" {
  let first_caller_def = 285
  let second_caller_def = 1780
  let third_caller_def = 1822
  let fourth_caller_def = 1825
  let target_def = 4206
  let make_def = 4207
  let caller_defs = [
    first_caller_def, second_caller_def, third_caller_def, fourth_caller_def,
  ]
  let out = StringBuilder::new()
  out.write_string("(module\n")
  let mut next_def = 0
  for caller_def in caller_defs {
    while next_def < caller_def {
      out.write_string("  (func $pad\{next_def})\n")
      next_def += 1
    }
    out.write_string(
      "  (func $caller\{caller_def} (export \"run\{caller_def}\") (param i32 i32) (result i32)\n",
    )
    out.write_string("    local.get 0\n")
    out.write_string("    local.get 1\n")
    out.write_string("    i32.const 0\n")
    out.write_string("    i32.const 17624\n")
    out.write_string("    call $make\n")
    out.write_string("    call $target)\n")
    next_def += 1
  }
  while next_def < target_def {
    out.write_string("  (func $pad\{next_def})\n")
    next_def += 1
  }
  out.write_string(
    (
      #|  (func $target (param i32 i32 i32 i32) (result i32)
      #|    local.get 0
      #|    local.get 1
      #|    local.get 2
      #|    local.get 3
      #|    i32.add
      #|    i32.add
      #|    i32.add)
    ),
  )
  next_def += 1
  @debug.assert_eq(next_def, make_def)
  out.write_string(
    (
      #|  (func $make (param i32) (result i32)
      #|    local.get 0)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  @debug.assert_eq(dae_test_func_params(optimized, target_def).length(), 3)
  for caller_def in caller_defs {
    let caller = optimized.pretty_print_defined_func(
      caller_def.reinterpret_as_uint(),
    )
    assert_true(caller.contains("(call (Func \{target_def}))"), msg=caller)
    assert_false(caller.contains("i32.const I32(0)"), msg=caller)
  }
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  assert_false(target.contains("(Local 3)"), msg=target)
}

///|
#skip("manual artifact-derived dropped-result replay; branch-arm result removal remains covered")
test "dae-optimizing removes selected Func298 dropped result from Func280 branch arms" {
  let caller_def = 280
  let target_def = 298
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < caller_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $caller (export "run") (param i32 i32) (result i32)
      #|    local.get 0
      #|    if
      #|      local.get 0
      #|      local.get 1
      #|      call $target
      #|      drop
      #|    else
      #|      local.get 1
      #|      local.get 0
      #|      call $target
      #|      drop
      #|    end
      #|    i32.const 0)
    ),
  )
  for i = caller_def + 1; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (param i32 i32) (result i32)
      #|    local.get 0
      #|    call $side
      #|    local.get 1
      #|    call $side
      #|    local.get 0
      #|    local.get 1
      #|    i32.add)
      #|  (func $side (param i32))
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  @debug.assert_eq(dae_test_func_results(optimized, target_def).length(), 0)
  let caller = optimized.pretty_print_defined_func(
    caller_def.reinterpret_as_uint(),
  )
  assert_true(caller.contains("(call (Func \{target_def}))"), msg=caller)
  assert_false(caller.contains("drop"), msg=caller)
}

///|
#skip("manual large-module DAE trace smoke; run through the dedicated fuzz/parity lane")
test "dae-optimizing traces selected dropped-result fallback metadata" {
  let target_def = 3566
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < 8; i = i + 1 {
    out.write_string(
      "  (func $g\{i} (param i32 i32)\n    local.get 0\n    drop)\n",
    )
  }
  for i = 8; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (param i32 i32) (result i32)
      #|    local.get 0
      #|    local.get 1
      #|    i32.add)
      #|  (func (export "run")
      #|    i32.const 10
      #|    i32.const 32
      #|    call $target
      #|    drop)
      #|)
    ),
  )
  let trace = match
    pass_test_capture_trace(out.to_string(), ["dae-optimizing"]) {
    Ok(trace) => trace
    Err(err) => fail("expected traced DAE success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[dae-optimizing]:selected-dropped-result-candidate") &&
      line.contains("def=3566") &&
      line.contains("callee_abs=3566") &&
      line.contains("callers=[3567]") &&
      line.contains("direct=1") &&
      line.contains("dropped=0") &&
      line.contains("live=1") &&
      line.contains("dead_suffix=unknown") &&
      line.contains("bucket=selected-fallback") &&
      line.contains("fact_attempted=false")
    }),
    msg=trace.to_string(),
  )
}

///|
#skip("manual artifact-derived scheduler replay; dropped-result worklist behavior has bounded coverage")
test "dae-optimizing removes selected mid-prefix dropped callee results" {
  for target_def in [476, 3566, 3732, 3814, 4232, 4240, 4241, 4242] {
    let out = StringBuilder::new()
    out.write_string("(module\n")
    for i = 0; i < 8; i = i + 1 {
      out.write_string(
        "  (func $g\{i} (param i32 i32)\n    local.get 0\n    drop)\n",
      )
    }
    for i = 8; i < target_def; i = i + 1 {
      out.write_string("  (func $pad\{i})\n")
    }
    out.write_string(
      (
        #|  (func $target (param i32 i32) (result i32)
        #|    local.get 0
        #|    call $side
        #|    local.get 1
        #|    call $side
        #|    local.get 0
        #|    local.get 1
        #|    i32.add)
        #|  (func $side (param i32))
        #|  (func (export "run")
      ),
    )
    for i = 0; i < 8; i = i + 1 {
      out.write_string("    i32.const 1\n    i32.const 2\n    call $g\{i}\n")
    }
    out.write_string(
      (
        #|    i32.const 10
        #|    i32.const 32
        #|    call $target
        #|    drop)
        #|)
      ),
    )
    let source = out.to_string()
    let optimized = dae_test_run(source)
    @debug.assert_eq(dae_test_func_results(optimized, target_def).length(), 0)
    let caller = optimized.pretty_print_defined_func(
      (target_def + 2).reinterpret_as_uint(),
    )
    assert_true(caller.contains("(call (Func \{target_def}))"), msg=caller)
    assert_false(caller.contains("drop"), msg=caller)
  }
}

///|
#skip("manual artifact-scale DAE parity fixture; focused transform behavior remains in bounded tests")
test "dae-optimizing materializes high fact-discovered exact literal outside selected list" {
  let caller_def = 1490
  let target_def = 1500
  let total_defs = 1502
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < 9; i = i + 1 {
    out.write_string(
      "  (func $early\{i} (param i32) (result i32) local.get 0)\n",
    )
  }
  for i = 9; i < caller_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string("  (func $caller (export \"run\") (result i32)\n")
  for i = 0; i < 9; i = i + 1 {
    out.write_string("    i32.const 0\n    call $early\{i}\n    drop\n")
  }
  out.write_string(
    (
      #|    i32.const 41
      #|    call $target)
    ),
  )
  for i = caller_def + 1; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (param i32) (result i32)
      #|    local.get 0
      #|    i32.const 1
      #|    i32.add)
    ),
  )
  for i = target_def + 1; i < total_defs; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(")")
  let optimized = dae_test_run(out.to_string())
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  let caller = optimized.pretty_print_defined_func(
    caller_def.reinterpret_as_uint(),
  )
  let @lib.FuncType(params, _) = dae_test_func_type(optimized, target_def)
  @debug.assert_eq(params.length(), 0)
  assert_true(target.contains("I32(41)"), msg=target)
  assert_false(target.contains("local.get"), msg=target)
  assert_true(caller.contains("(call (Func \{target_def}))"), msg=caller)
  assert_false(
    caller.contains("(i32.const 41)\n  (call (Func \{target_def}))"),
    msg=caller,
  )
}

///|
#skip("manual artifact-scale DAE parity fixture; focused transform behavior remains in bounded tests")
test "dae-optimizing reaches exact literal after more than fixed core plus low revisit budget" {
  let early_count = 73
  let caller_def = 1600
  let target_def = 1610
  let total_defs = 1612
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < early_count; i = i + 1 {
    out.write_string(
      "  (func $early\{i} (param i32) (result i32) local.get 0)\n",
    )
  }
  for i = early_count; i < caller_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string("  (func $caller (export \"run\") (result i32)\n")
  for i = 0; i < early_count; i = i + 1 {
    out.write_string("    i32.const \{i}\n    call $early\{i}\n    drop\n")
  }
  out.write_string(
    (
      #|    i32.const 73
      #|    call $target)
    ),
  )
  for i = caller_def + 1; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (param i32) (result i32)
      #|    local.get 0
      #|    i32.const 1
      #|    i32.add)
    ),
  )
  for i = target_def + 1; i < total_defs; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(")")
  let optimized = dae_test_run(out.to_string())
  let @lib.FuncType(params, _) = dae_test_func_type(optimized, target_def)
  @debug.assert_eq(params.length(), 0)
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  assert_true(target.contains("I32(73)"), msg=target)
}

///|
test "dae-optimizing materializes non-adjacent local-set constant actual" {
  let target_def = 0
  let caller_def = 1
  let source =
    #|(module
    #|  (func $target (param i32) (result i32)
    #|    local.get 0
    #|    i32.const 1
    #|    i32.add)
    #|  (func $caller (export "run") (result i32) (local i32)
    #|    i32.const 77
    #|    local.set 0
    #|    local.get 0
    #|    call $target))
  let optimized = dae_test_run(source)
  let @lib.FuncType(params, _) = dae_test_func_type(optimized, target_def)
  @debug.assert_eq(params.length(), 0)
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  let caller = optimized.pretty_print_defined_func(
    caller_def.reinterpret_as_uint(),
  )
  assert_true(target.contains("I32(78)"), msg=target)
  assert_false(target.contains("local.get"), msg=target)
  assert_true(caller.contains("(call (Func \{target_def}))"), msg=caller)
  assert_false(caller.contains("local.get"), msg=caller)
}

///|
test "dae-optimizing materializes non-adjacent typed block constant carrier" {
  let target_def = 0
  let caller_def = 1
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (type $one (func (result i32)))
      #|  (func $target (param i32) (result i32)
      #|    local.get 0
      #|    i32.const 1
      #|    i32.add)
      #|  (func $caller (export "run") (result i32) (local i32)
      #|    block (type $one)
      #|      i32.const 88
      #|    end
      #|    local.set 0
      #|    local.get 0
      #|    call $target)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let @lib.FuncType(params, _) = dae_test_func_type(optimized, target_def)
  @debug.assert_eq(params.length(), 0)
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  let caller = optimized.pretty_print_defined_func(
    caller_def.reinterpret_as_uint(),
  )
  assert_true(target.contains("I32(89)"), msg=target)
  assert_false(target.contains("local.get"), msg=target)
  assert_true(caller.contains("(call (Func \{target_def}))"), msg=caller)
  assert_false(caller.contains("local.get"), msg=caller)
}

///|
test "dae-optimizing materializes non-adjacent branch-free loop constant carrier" {
  let target_def = 0
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (type $one (func (result i32)))
      #|  (func $target (param i32) (result i32)
      #|    local.get 0
      #|    i32.const 1
      #|    i32.add)
      #|  (func $caller (export "run") (result i32) (local i32)
      #|    loop (type $one)
      #|      i32.const 88
      #|    end
      #|    local.set 0
      #|    local.get 0
      #|    call $target)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let @lib.FuncType(params, _) = dae_test_func_type(optimized, target_def)
  @debug.assert_eq(params.length(), 0)
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  assert_true(target.contains("I32(89)"), msg=target)
  assert_false(target.contains("local.get"), msg=target)
}

///|
test "dae-optimizing materializes non-adjacent loop nested block constant carrier" {
  let target_def = 0
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (type $one (func (result i32)))
      #|  (func $target (param i32) (result i32)
      #|    local.get 0
      #|    i32.const 1
      #|    i32.add)
      #|  (func $caller (export "run") (result i32) (local i32)
      #|    loop (type $one)
      #|      block (type $one)
      #|        i32.const 88
      #|      end
      #|    end
      #|    local.set 0
      #|    local.get 0
      #|    call $target)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let @lib.FuncType(params, _) = dae_test_func_type(optimized, target_def)
  @debug.assert_eq(params.length(), 0)
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  assert_true(target.contains("I32(89)"), msg=target)
  assert_false(target.contains("local.get"), msg=target)
}

///|
test "dae-optimizing materializes non-adjacent loop dropped-prefix constant carrier" {
  let target_def = 0
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (type $one (func (result i32)))
      #|  (func $target (param i32) (result i32)
      #|    local.get 0
      #|    i32.const 1
      #|    i32.add)
      #|  (func $caller (export "run") (result i32) (local i32)
      #|    loop (type $one)
      #|      i32.const 7
      #|      drop
      #|      i32.const 88
      #|    end
      #|    local.set 0
      #|    local.get 0
      #|    call $target)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let @lib.FuncType(params, _) = dae_test_func_type(optimized, target_def)
  @debug.assert_eq(params.length(), 0)
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  assert_true(target.contains("I32(89)"), msg=target)
  assert_false(target.contains("local.get"), msg=target)
}

///|
test "dae uses exceptional CFG liveness for overwritten try-table parameters" {
  let source =
    #|(module
    #|  (tag $e)
    #|  (func $target (param i32)
    #|    block $caught
    #|      try_table (catch $e $caught)
    #|        i32.const 9
    #|        local.set 0
    #|        throw $e
    #|      end
    #|    end
    #|    local.get 0
    #|    drop)
    #|  (func (export "run")
    #|    i32.const 7
    #|    call $target))
  for pass_name in ["dead-argument-elimination", "dae-optimizing"] {
    let optimized = match pass_test_run_pipeline(source, [pass_name]) {
      Ok(mod_) => mod_
      Err(err) => fail("expected \{pass_name} EH liveness success, got \{err}")
    }
    @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
    match @validate.validate_module(optimized) {
      Ok(_) => ()
      Err(err) =>
        fail("expected \{pass_name} EH output to validate, got \{err}")
    }
  }
}

///|
test "dae preserves try-table parameters live before an exceptional overwrite" {
  let source =
    #|(module
    #|  (tag $e)
    #|  (func $target (param i32)
    #|    block $caught
    #|      try_table (catch $e $caught)
    #|        throw $e
    #|        i32.const 9
    #|        local.set 0
    #|      end
    #|    end
    #|    local.get 0
    #|    drop)
    #|  (func (export "run")
    #|    i32.const 7
    #|    call $target))
  for pass_name in ["dead-argument-elimination", "dae-optimizing"] {
    let optimized = match pass_test_run_pipeline(source, [pass_name]) {
      Ok(mod_) => mod_
      Err(err) => fail("expected \{pass_name} EH guard success, got \{err}")
    }
    @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 1)
    match @validate.validate_module(optimized) {
      Ok(_) => ()
      Err(err) =>
        fail("expected \{pass_name} EH guard output to validate, got \{err}")
    }
  }
}

///|
test "dae-optimizing materializes non-adjacent try-table constant carrier" {
  let target_def = 0
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (tag $e (param i32))
      #|  (func $target (param i32) (result i32)
      #|    local.get 0
      #|    i32.const 1
      #|    i32.add)
      #|  (func $caller (export "run") (result i32) (local i32)
      #|    block $exit (result i32)
      #|      try_table (result i32) (catch $e $exit)
      #|        i32.const 88
      #|      end
      #|    end
      #|    local.set 0
      #|    local.get 0
      #|    call $target)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let @lib.FuncType(params, _) = dae_test_func_type(optimized, target_def)
  @debug.assert_eq(params.length(), 0)
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  assert_true(target.contains("I32(89)"), msg=target)
  assert_false(target.contains("local.get"), msg=target)
}

///|
test "dae-optimizing materializes non-adjacent try-table dropped-prefix constant carrier" {
  let target_def = 0
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (tag $e (param i32))
      #|  (func $target (param i32) (result i32)
      #|    local.get 0
      #|    i32.const 1
      #|    i32.add)
      #|  (func $caller (export "run") (result i32) (local i32)
      #|    block $exit (result i32)
      #|      try_table (result i32) (catch $e $exit)
      #|        i32.const 7
      #|        drop
      #|        i32.const 88
      #|      end
      #|    end
      #|    local.set 0
      #|    local.get 0
      #|    call $target)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let @lib.FuncType(params, _) = dae_test_func_type(optimized, target_def)
  @debug.assert_eq(params.length(), 0)
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  assert_true(target.contains("I32(89)"), msg=target)
  assert_false(target.contains("local.get"), msg=target)
}

///|
test "dae-optimizing preserves try-table carrier with throwing prefix" {
  let target_def = 0
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (tag $e (param i32))
      #|  (func $target (param i32) (result i32)
      #|    local.get 0
      #|    i32.const 1
      #|    i32.add)
      #|  (func $caller (export "run") (result i32) (local i32)
      #|    block $exit (result i32)
      #|      try_table (result i32) (catch $e $exit)
      #|        i32.const 99
      #|        throw $e
      #|        i32.const 88
      #|      end
      #|    end
      #|    local.set 0
      #|    local.get 0
      #|    call $target)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let @lib.FuncType(params, _) = dae_test_func_type(optimized, target_def)
  @debug.assert_eq(params.length(), 1)
}

///|
test "dae-optimizing materializes non-adjacent pure dropped-prefix block carrier" {
  let target_def = 0
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (type $one (func (result i32)))
      #|  (func $target (param i32) (result i32)
      #|    local.get 0
      #|    i32.const 1
      #|    i32.add)
      #|  (func $caller (export "run") (result i32) (local i32)
      #|    block (type $one)
      #|      i32.const 7
      #|      drop
      #|      i32.const 88
      #|    end
      #|    local.set 0
      #|    local.get 0
      #|    call $target)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let @lib.FuncType(params, _) = dae_test_func_type(optimized, target_def)
  @debug.assert_eq(params.length(), 0)
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  assert_true(target.contains("I32(89)"), msg=target)
  assert_false(target.contains("local.get"), msg=target)
}

///|
test "dae-optimizing materializes non-adjacent nested dropped-prefix block carrier" {
  let target_def = 0
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (type $one (func (result i32)))
      #|  (func $target (param i32) (result i32)
      #|    local.get 0
      #|    i32.const 1
      #|    i32.add)
      #|  (func $caller (export "run") (result i32) (local i32)
      #|    block (type $one)
      #|      block (type $one)
      #|        i32.const 7
      #|      end
      #|      drop
      #|      block (type $one)
      #|        i32.const 88
      #|      end
      #|    end
      #|    local.set 0
      #|    local.get 0
      #|    call $target)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let @lib.FuncType(params, _) = dae_test_func_type(optimized, target_def)
  @debug.assert_eq(params.length(), 0)
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  assert_true(target.contains("I32(89)"), msg=target)
  assert_false(target.contains("local.get"), msg=target)
}

///|
test "dae-optimizing rejects non-adjacent multi-instruction block carrier" {
  let target_def = 0
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (type $one (func (result i32)))
      #|  (func $target (param i32) (result i32)
      #|    local.get 0
      #|    i32.const 1
      #|    i32.add)
      #|  (func $caller (export "run") (result i32) (local i32)
      #|    block (type $one)
      #|      i32.const 40
      #|      i32.const 2
      #|      i32.add
      #|    end
      #|    local.set 0
      #|    local.get 0
      #|    call $target)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let @lib.FuncType(params, _) = dae_test_func_type(optimized, target_def)
  @debug.assert_eq(params.length(), 1)
}

///|
test "dae-optimizing materializes non-adjacent equal-arm if constant carrier" {
  let target_def = 0
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (type $one (func (result i32)))
      #|  (func $target (param i32) (result i32)
      #|    local.get 0
      #|    i32.const 1
      #|    i32.add)
      #|  (func $caller (export "run") (result i32) (local i32)
      #|    i32.const 1
      #|    if (type $one)
      #|      i32.const 88
      #|    else
      #|      i32.const 88
      #|    end
      #|    local.set 0
      #|    local.get 0
      #|    call $target)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let @lib.FuncType(params, _) = dae_test_func_type(optimized, target_def)
  @debug.assert_eq(params.length(), 0)
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  assert_true(target.contains("I32(89)"), msg=target)
  assert_false(target.contains("local.get"), msg=target)
}

///|
test "dae-optimizing materializes non-adjacent equal-arm if dropped-prefix constant carrier" {
  let target_def = 0
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (type $one (func (result i32)))
      #|  (func $target (param i32) (result i32)
      #|    local.get 0
      #|    i32.const 1
      #|    i32.add)
      #|  (func $caller (export "run") (result i32) (local i32)
      #|    i32.const 1
      #|    if (type $one)
      #|      i32.const 7
      #|      drop
      #|      i32.const 88
      #|    else
      #|      i32.const 9
      #|      drop
      #|      i32.const 88
      #|    end
      #|    local.set 0
      #|    local.get 0
      #|    call $target)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let @lib.FuncType(params, _) = dae_test_func_type(optimized, target_def)
  @debug.assert_eq(params.length(), 0)
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  assert_true(target.contains("I32(89)"), msg=target)
  assert_false(target.contains("local.get"), msg=target)
}

///|
#skip("manual artifact-scale DAE definition-threshold fixture; bounded carrier behavior remains covered")
test "dae-optimizing materializes non-adjacent equal-arm if nested block carrier" {
  let target_def = 1500
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (type $one (func (result i32)))
      #|  (func $target (param i32) (result i32)
      #|    local.get 0
      #|    i32.const 1
      #|    i32.add)
      #|  (func $caller (export "run") (result i32) (local i32)
      #|    i32.const 1
      #|    if (type $one)
      #|      block (type $one)
      #|        i32.const 88
      #|      end
      #|    else
      #|      block (type $one)
      #|        i32.const 88
      #|      end
      #|    end
      #|    local.set 0
      #|    local.get 0
      #|    call $target)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let @lib.FuncType(params, _) = dae_test_func_type(optimized, target_def)
  @debug.assert_eq(params.length(), 0)
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  assert_true(target.contains("I32(88)"), msg=target)
  assert_false(target.contains("local.get"), msg=target)
}

///|
test "dae-optimizing rejects non-adjacent local-tee constant actual carrier" {
  let target_def = 0
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (param i32) (result i32)
      #|    local.get 0
      #|    i32.const 1
      #|    i32.add)
      #|  (func $caller (export "run") (result i32) (local i32)
      #|    i32.const 77
      #|    local.tee 0
      #|    drop
      #|    local.get 0
      #|    call $target)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let @lib.FuncType(params, _) = dae_test_func_type(optimized, target_def)
  @debug.assert_eq(params.length(), 1)
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  let caller = optimized.pretty_print_defined_func(1U)
  assert_true(target.contains("local.get"), msg=target)
  assert_true(caller.contains("local.tee"), msg=caller)
  assert_true(caller.contains("local.get"), msg=caller)
}

///|
test "dae-optimizing rejects non-adjacent local-set carrier with earlier read" {
  let target_def = 0
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (param i32) (result i32)
      #|    local.get 0
      #|    i32.const 1
      #|    i32.add)
      #|  (func $caller (export "run") (result i32) (local i32)
      #|    i32.const 77
      #|    local.set 0
      #|    local.get 0
      #|    drop
      #|    local.get 0
      #|    call $target)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let @lib.FuncType(params, _) = dae_test_func_type(optimized, target_def)
  @debug.assert_eq(params.length(), 1)
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  let caller = optimized.pretty_print_defined_func(1U)
  assert_true(target.contains("local.get"), msg=target)
  assert_true(caller.contains("local.get"), msg=caller)
  assert_true(caller.contains("drop"), msg=caller)
}

///|
test "dae-optimizing rejects non-adjacent local-set carrier with multiple writes" {
  let target_def = 0
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (param i32) (result i32)
      #|    local.get 0
      #|    i32.const 1
      #|    i32.add)
      #|  (func $caller (export "run") (result i32) (local i32)
      #|    i32.const 77
      #|    local.set 0
      #|    i32.const 78
      #|    local.set 0
      #|    local.get 0
      #|    call $target)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let @lib.FuncType(params, _) = dae_test_func_type(optimized, target_def)
  @debug.assert_eq(params.length(), 1)
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  let caller = optimized.pretty_print_defined_func(1U)
  assert_true(target.contains("local.get"), msg=target)
  assert_true(caller.contains("I32(78)"), msg=caller)
  assert_true(caller.contains("local.get"), msg=caller)
}

///|
test "dae-optimizing rejects non-adjacent trapping local-set carrier" {
  let target_def = 0
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (param i32) (result i32)
      #|    local.get 0
      #|    i32.const 1
      #|    i32.add)
      #|  (func $caller (export "run") (result i32) (local i32)
      #|    i32.const 1
      #|    i32.const 0
      #|    i32.div_s
      #|    local.set 0
      #|    local.get 0
      #|    call $target)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let @lib.FuncType(params, _) = dae_test_func_type(optimized, target_def)
  @debug.assert_eq(params.length(), 1)
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  let caller = optimized.pretty_print_defined_func(1U)
  assert_true(target.contains("local.get"), msg=target)
  assert_true(caller.contains("i32.div_s"), msg=caller)
  assert_true(caller.contains("local.get"), msg=caller)
}

///|
test "dae-optimizing rejects non-adjacent effectful local-set carrier" {
  let target_def = 0
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (param i32) (result i32)
      #|    local.get 0
      #|    i32.const 1
      #|    i32.add)
      #|  (func $effect (result i32)
      #|    i32.const 77)
      #|  (func $caller (export "run") (result i32) (local i32)
      #|    call $effect
      #|    local.set 0
      #|    local.get 0
      #|    call $target)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  let @lib.FuncType(params, _) = dae_test_func_type(optimized, target_def)
  @debug.assert_eq(params.length(), 1)
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  let caller = optimized.pretty_print_defined_func(2U)
  assert_true(target.contains("local.get"), msg=target)
  assert_true(caller.contains("call (Func 0)"), msg=caller)
  assert_true(caller.contains("local.get"), msg=caller)
}

///|
test "dae-optimizing rejects non-adjacent self-recursive local-set constant cycle" {
  let source =
    #|(module
    #|  (func $target (param i32) (result i32) (local i32)
    #|    local.get 0
    #|    i32.eqz
    #|    if (result i32)
    #|      i32.const 1
    #|    else
    #|      i32.const 77
    #|      local.set 0
    #|      local.get 0
    #|      call $target
    #|    end)
    #|  (func (export "run") (result i32)
    #|    i32.const 77
    #|    call $target))
  let optimized = dae_test_run(source)
  let @lib.FuncType(params, _) = dae_test_func_type(optimized, 0)
  @debug.assert_eq(params.length(), 1)
  let target = optimized.pretty_print_defined_func(0U)
  assert_true(target.contains("local.get"), msg=target)
  assert_true(target.contains("call (Func 0)"), msg=target)
}

///|
test "dae-optimizing rejects non-adjacent local carrier when callee escapes through ref.func" {
  let source =
    #|(module
    #|  (type $target_ty (func (param i32) (result i32)))
    #|  (elem declare func $target)
    #|  (func $target (type $target_ty) (param i32) (result i32)
    #|    local.get 0)
    #|  (func (export "run") (result i32) (local i32)
    #|    i32.const 77
    #|    local.set 0
    #|    local.get 0
    #|    call $target)
    #|  (func (export "escape") (result funcref)
    #|    ref.func $target))
  let optimized = dae_test_run(source)
  let @lib.FuncType(params, _) = dae_test_func_type(optimized, 0)
  @debug.assert_eq(params.length(), 1)
  let target = optimized.pretty_print_defined_func(0U)
  let caller = optimized.pretty_print_defined_func(1U)
  assert_true(target.contains("local.get"), msg=target)
  assert_true(caller.contains("local.get"), msg=caller)
}

///|
test "dae-optimizing preserves fact-discovered results with mixed dropped and live callers" {
  let source =
    #|(module
    #|  (func $dropper (export "dropper")
    #|    i32.const 7
    #|    call $target
    #|    drop)
    #|  (func $keeper (export "keeper") (result i32)
    #|    i32.const 9
    #|    call $target)
    #|  (func $target (param i32) (result i32)
    #|    local.get 0))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_results(optimized, 2).length(), 1)
  let dropper = optimized.pretty_print_defined_func(0U)
  let keeper = optimized.pretty_print_defined_func(1U)
  assert_true(dropper.contains("call"), msg=dropper)
  assert_true(dropper.contains("drop"), msg=dropper)
  assert_true(keeper.contains("call"), msg=keeper)
}

///|
#skip("manual artifact-scale DAE parity fixture; focused transform behavior remains in bounded tests")
test "dae-optimizing removes fact-discovered dropped callee result outside selected list" {
  let target_def = 512
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < 8; i = i + 1 {
    out.write_string(
      "  (func $g\{i} (param i32 i32)\n    local.get 0\n    drop)\n",
    )
  }
  for i = 8; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (param i32 i32) (result i32)
      #|    local.get 0
      #|    call $side
      #|    local.get 1
      #|    call $side
      #|    local.get 0
      #|    local.get 1
      #|    i32.add)
      #|  (func $side (param i32))
      #|  (func (export "run")
    ),
  )
  for i = 0; i < 8; i = i + 1 {
    out.write_string("    i32.const 1\n    i32.const 2\n    call $g\{i}\n")
  }
  out.write_string(
    (
      #|    i32.const 10
      #|    i32.const 32
      #|    call $target
      #|    drop)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  @debug.assert_eq(dae_test_func_results(optimized, target_def).length(), 0)
  let caller = optimized.pretty_print_defined_func(
    (target_def + 2).reinterpret_as_uint(),
  )
  assert_true(caller.contains("(call (Func \{target_def}))"), msg=caller)
  assert_false(caller.contains("drop"), msg=caller)
}

///|
#skip("manual large-module DAE scheduler smoke; covered by the dedicated fuzz/parity lane")
test "dae-optimizing reaches fallback-neighborhood dropped result through fact path" {
  for singleton_def in [298, 445, 3834, 4106, 4249, 4229, 427, 4240, 4241, 4242] {
    let high_start = 4644
    let high_count = 8
    let out = StringBuilder::new()
    out.write_string("(module\n")
    for i = 0; i < singleton_def; i = i + 1 {
      out.write_string("  (func $pad\{i})\n")
    }
    out.write_string(
      "  (func $singleton (result i32)\n    i32.const \{singleton_def})\n",
    )
    for i = singleton_def + 1; i < high_start; i = i + 1 {
      out.write_string("  (func $pad\{i})\n")
    }
    for i = 0; i < high_count; i = i + 1 {
      out.write_string("  (func $high\{i} (result i32)\n    i32.const \{i})\n")
    }
    out.write_string("  (func (export \"run\")\n")
    for i = 0; i < high_count; i = i + 1 {
      out.write_string("    call $high\{i}\n    drop\n")
    }
    out.write_string(
      (
        #|    call $singleton
        #|    drop)
        #|)
      ),
    )
    let (optimized, trace) = dae_test_run_with_perf_trace(out.to_string())
    @debug.assert_eq(
      dae_test_func_results(optimized, singleton_def).length(),
      0,
    )
    assert_false(
      trace.any(fn(line) {
        line.contains(
          "pass[dae-optimizing]:selected-dropped-result-candidate def=\{singleton_def}",
        ) ||
        line.contains(
          "pass[dae-optimizing]:selected-dropped-result primary_def=\{singleton_def}",
        )
      }),
      msg=trace.to_string(),
    )
  }
}

///|
#skip("manual artifact-scale DAE parity fixture; focused transform behavior remains in bounded tests")
test "dae-optimizing removes high fact-discovered dropped callee result outside selected list" {
  let target_def = 3000
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < 8; i = i + 1 {
    out.write_string(
      "  (func $g\{i} (param i32 i32)\n    local.get 0\n    drop)\n",
    )
  }
  for i = 8; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (param i32 i32) (result i32)
      #|    local.get 0
      #|    call $side
      #|    local.get 1
      #|    call $side
      #|    local.get 0
      #|    local.get 1
      #|    i32.add)
      #|  (func $side (param i32))
      #|  (func (export "run")
    ),
  )
  for i = 0; i < 8; i = i + 1 {
    out.write_string("    i32.const 1\n    i32.const 2\n    call $g\{i}\n")
  }
  out.write_string(
    (
      #|    i32.const 10
      #|    i32.const 32
      #|    call $target
      #|    drop)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  @debug.assert_eq(dae_test_func_results(optimized, target_def).length(), 0)
  let caller = optimized.pretty_print_defined_func(
    (target_def + 2).reinterpret_as_uint(),
  )
  assert_true(caller.contains("(call (Func \{target_def}))"), msg=caller)
  assert_false(caller.contains("drop"), msg=caller)
}

///|
#skip("manual artifact-scale DAE parity fixture; focused transform behavior remains in bounded tests")
test "dae-optimizing reaches high dropped-result callee after low candidate budget" {
  let target_def = 4500
  let low_candidates = 40
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < low_candidates; i = i + 1 {
    out.write_string("  (func $low\{i} (result i32)\n    i32.const \{i})\n")
  }
  for i = low_candidates; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (param i32 i32) (result i32)
      #|    local.get 0
      #|    call $side
      #|    local.get 1
      #|    call $side
      #|    local.get 0
      #|    local.get 1
      #|    i32.add)
      #|  (func $side (param i32))
      #|  (func (export "run")
    ),
  )
  for i = 0; i < low_candidates; i = i + 1 {
    out.write_string("    call $low\{i}\n    drop\n")
  }
  out.write_string(
    (
      #|    i32.const 10
      #|    i32.const 32
      #|    call $target
      #|    drop)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  @debug.assert_eq(dae_test_func_results(optimized, target_def).length(), 0)
  let caller = optimized.pretty_print_defined_func(
    (target_def + 2).reinterpret_as_uint(),
  )
  assert_true(caller.contains("(call (Func \{target_def}))(end)"), msg=caller)
}

///|
#skip("manual artifact-scale DAE scheduler progression; bounded scheduler unit tests retain count and ordering coverage")
test "dae-optimizing reaches two high dropped-result callees after low candidate budget" {
  let first_target_def = 4500
  let second_target_def = 4501
  let low_candidates = 40
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < low_candidates; i = i + 1 {
    out.write_string("  (func $low\{i} (result i32)\n    i32.const \{i})\n")
  }
  for i = low_candidates; i < first_target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $first_target (param i32 i32) (result i32)
      #|    local.get 0
      #|    call $side
      #|    local.get 1
      #|    call $side
      #|    local.get 0
      #|    local.get 1
      #|    i32.add)
      #|  (func $second_target (param i32 i32) (result i32)
      #|    local.get 0
      #|    call $side
      #|    local.get 1
      #|    call $side
      #|    local.get 0
      #|    local.get 1
      #|    i32.add)
      #|  (func $side (param i32))
      #|  (func (export "run")
    ),
  )
  for i = 0; i < low_candidates; i = i + 1 {
    out.write_string("    call $low\{i}\n    drop\n")
  }
  out.write_string(
    (
      #|    i32.const 10
      #|    i32.const 32
      #|    call $first_target
      #|    drop
      #|    i32.const 20
      #|    i32.const 22
      #|    call $second_target
      #|    drop)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  @debug.assert_eq(
    dae_test_func_results(optimized, first_target_def).length(),
    0,
  )
  @debug.assert_eq(
    dae_test_func_results(optimized, second_target_def).length(),
    0,
  )
  let caller = optimized.pretty_print_defined_func(
    (second_target_def + 2).reinterpret_as_uint(),
  )
  assert_true(caller.contains("(call (Func \{first_target_def}))"), msg=caller)
  assert_true(
    caller.contains("(call (Func \{second_target_def}))(end)"),
    msg=caller,
  )
}

///|
#skip("manual artifact-scale DAE scheduler progression; bounded scheduler unit tests retain count and ordering coverage")
test "dae-optimizing reaches three high dropped-result callees after low candidate budget" {
  let first_target_def = 4500
  let second_target_def = 4501
  let third_target_def = 4502
  let low_candidates = 40
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < low_candidates; i = i + 1 {
    out.write_string("  (func $low\{i} (result i32)\n    i32.const \{i})\n")
  }
  for i = low_candidates; i < first_target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $first_target (param i32 i32) (result i32)
      #|    local.get 0
      #|    call $side
      #|    local.get 1
      #|    call $side
      #|    local.get 0
      #|    local.get 1
      #|    i32.add)
      #|  (func $second_target (param i32 i32) (result i32)
      #|    local.get 0
      #|    call $side
      #|    local.get 1
      #|    call $side
      #|    local.get 0
      #|    local.get 1
      #|    i32.add)
      #|  (func $third_target (param i32 i32) (result i32)
      #|    local.get 0
      #|    call $side
      #|    local.get 1
      #|    call $side
      #|    local.get 0
      #|    local.get 1
      #|    i32.add)
      #|  (func $side (param i32))
      #|  (func (export "run")
    ),
  )
  for i = 0; i < low_candidates; i = i + 1 {
    out.write_string("    call $low\{i}\n    drop\n")
  }
  out.write_string(
    (
      #|    i32.const 10
      #|    i32.const 32
      #|    call $first_target
      #|    drop
      #|    i32.const 20
      #|    i32.const 22
      #|    call $second_target
      #|    drop
      #|    i32.const 30
      #|    i32.const 12
      #|    call $third_target
      #|    drop)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  @debug.assert_eq(
    dae_test_func_results(optimized, first_target_def).length(),
    0,
  )
  @debug.assert_eq(
    dae_test_func_results(optimized, second_target_def).length(),
    0,
  )
  @debug.assert_eq(
    dae_test_func_results(optimized, third_target_def).length(),
    0,
  )
  let caller = optimized.pretty_print_defined_func(
    (third_target_def + 2).reinterpret_as_uint(),
  )
  assert_true(caller.contains("(call (Func \{first_target_def}))"), msg=caller)
  assert_true(caller.contains("(call (Func \{second_target_def}))"), msg=caller)
  assert_true(
    caller.contains("(call (Func \{third_target_def}))(end)"),
    msg=caller,
  )
}

///|
#skip("manual artifact-scale DAE scheduler progression; bounded scheduler unit tests retain count and ordering coverage")
test "dae-optimizing reaches four high dropped-result callees after low candidate budget" {
  let first_target_def = 4500
  let second_target_def = 4501
  let third_target_def = 4502
  let fourth_target_def = 4503
  let low_candidates = 40
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < low_candidates; i = i + 1 {
    out.write_string("  (func $low\{i} (result i32)\n    i32.const \{i})\n")
  }
  for i = low_candidates; i < first_target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $first_target (param i32 i32) (result i32)
      #|    local.get 0
      #|    call $side
      #|    local.get 1
      #|    call $side
      #|    local.get 0
      #|    local.get 1
      #|    i32.add)
      #|  (func $second_target (param i32 i32) (result i32)
      #|    local.get 0
      #|    call $side
      #|    local.get 1
      #|    call $side
      #|    local.get 0
      #|    local.get 1
      #|    i32.add)
      #|  (func $third_target (param i32 i32) (result i32)
      #|    local.get 0
      #|    call $side
      #|    local.get 1
      #|    call $side
      #|    local.get 0
      #|    local.get 1
      #|    i32.add)
      #|  (func $fourth_target (param i32 i32) (result i32)
      #|    local.get 0
      #|    call $side
      #|    local.get 1
      #|    call $side
      #|    local.get 0
      #|    local.get 1
      #|    i32.add)
      #|  (func $side (param i32))
      #|  (func (export "run")
    ),
  )
  for i = 0; i < low_candidates; i = i + 1 {
    out.write_string("    call $low\{i}\n    drop\n")
  }
  out.write_string(
    (
      #|    i32.const 10
      #|    i32.const 32
      #|    call $first_target
      #|    drop
      #|    i32.const 20
      #|    i32.const 22
      #|    call $second_target
      #|    drop
      #|    i32.const 30
      #|    i32.const 12
      #|    call $third_target
      #|    drop
      #|    i32.const 40
      #|    i32.const 2
      #|    call $fourth_target
      #|    drop)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  @debug.assert_eq(
    dae_test_func_results(optimized, first_target_def).length(),
    0,
  )
  @debug.assert_eq(
    dae_test_func_results(optimized, second_target_def).length(),
    0,
  )
  @debug.assert_eq(
    dae_test_func_results(optimized, third_target_def).length(),
    0,
  )
  @debug.assert_eq(
    dae_test_func_results(optimized, fourth_target_def).length(),
    0,
  )
  let caller = optimized.pretty_print_defined_func(
    (fourth_target_def + 2).reinterpret_as_uint(),
  )
  assert_true(caller.contains("(call (Func \{first_target_def}))"), msg=caller)
  assert_true(caller.contains("(call (Func \{second_target_def}))"), msg=caller)
  assert_true(caller.contains("(call (Func \{third_target_def}))"), msg=caller)
  assert_true(
    caller.contains("(call (Func \{fourth_target_def}))(end)"),
    msg=caller,
  )
}

///|
#skip("manual artifact-scale DAE scheduler progression; bounded scheduler unit tests retain count and ordering coverage")
test "dae-optimizing reaches fourteen high dropped-result callees after low candidate budget" {
  let first_target_def = 4500
  let second_target_def = 4501
  let third_target_def = 4502
  let fourth_target_def = 4503
  let fifth_target_def = 4504
  let sixth_target_def = 4505
  let seventh_target_def = 4506
  let eighth_target_def = 4507
  let ninth_target_def = 4508
  let tenth_target_def = 4509
  let eleventh_target_def = 4510
  let twelfth_target_def = 4511
  let thirteenth_target_def = 4512
  let fourteenth_target_def = 4513
  let low_candidates = 40
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < low_candidates; i = i + 1 {
    out.write_string("  (func $low\{i} (result i32)\n    i32.const \{i})\n")
  }
  for i = low_candidates; i < first_target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  for i = 0; i < 14; i = i + 1 {
    out.write_string(
      "  (func $target\{i} (param i32 i32) (result i32)\n    local.get 0\n    call $side\n    local.get 1\n    call $side\n    local.get 0\n    local.get 1\n    i32.add)\n",
    )
  }
  out.write_string("  (func $side (param i32))\n  (func (export \"run\")\n")
  for i = 0; i < low_candidates; i = i + 1 {
    out.write_string("    call $low\{i}\n    drop\n")
  }
  for i = 0; i < 14; i = i + 1 {
    out.write_string(
      "    i32.const \{10 + i}\n    i32.const \{32 - i}\n    call $target\{i}\n    drop\n",
    )
  }
  out.write_string("  )\n)\n")
  let optimized = dae_test_run(out.to_string())
  @debug.assert_eq(
    dae_test_func_results(optimized, first_target_def).length(),
    0,
  )
  @debug.assert_eq(
    dae_test_func_results(optimized, second_target_def).length(),
    0,
  )
  @debug.assert_eq(
    dae_test_func_results(optimized, third_target_def).length(),
    0,
  )
  @debug.assert_eq(
    dae_test_func_results(optimized, fourth_target_def).length(),
    0,
  )
  @debug.assert_eq(
    dae_test_func_results(optimized, fifth_target_def).length(),
    0,
  )
  @debug.assert_eq(
    dae_test_func_results(optimized, sixth_target_def).length(),
    0,
  )
  @debug.assert_eq(
    dae_test_func_results(optimized, seventh_target_def).length(),
    0,
  )
  @debug.assert_eq(
    dae_test_func_results(optimized, eighth_target_def).length(),
    0,
  )
  @debug.assert_eq(
    dae_test_func_results(optimized, ninth_target_def).length(),
    0,
  )
  @debug.assert_eq(
    dae_test_func_results(optimized, tenth_target_def).length(),
    0,
  )
  @debug.assert_eq(
    dae_test_func_results(optimized, eleventh_target_def).length(),
    0,
  )
  @debug.assert_eq(
    dae_test_func_results(optimized, twelfth_target_def).length(),
    0,
  )
  @debug.assert_eq(
    dae_test_func_results(optimized, thirteenth_target_def).length(),
    0,
  )
  @debug.assert_eq(
    dae_test_func_results(optimized, fourteenth_target_def).length(),
    0,
  )
  let caller = optimized.pretty_print_defined_func(
    (fourteenth_target_def + 2).reinterpret_as_uint(),
  )
  assert_true(caller.contains("(call (Func \{first_target_def}))"), msg=caller)
  assert_true(caller.contains("(call (Func \{second_target_def}))"), msg=caller)
  assert_true(caller.contains("(call (Func \{third_target_def}))"), msg=caller)
  assert_true(caller.contains("(call (Func \{fourth_target_def}))"), msg=caller)
  assert_true(caller.contains("(call (Func \{fifth_target_def}))"), msg=caller)
  assert_true(caller.contains("(call (Func \{sixth_target_def}))"), msg=caller)
  assert_true(
    caller.contains("(call (Func \{seventh_target_def}))"),
    msg=caller,
  )
  assert_true(caller.contains("(call (Func \{eighth_target_def}))"), msg=caller)
  assert_true(caller.contains("(call (Func \{ninth_target_def}))"), msg=caller)
  assert_true(caller.contains("(call (Func \{tenth_target_def}))"), msg=caller)
  assert_true(
    caller.contains("(call (Func \{eleventh_target_def}))"),
    msg=caller,
  )
  assert_true(
    caller.contains("(call (Func \{twelfth_target_def}))"),
    msg=caller,
  )
  assert_true(
    caller.contains("(call (Func \{thirteenth_target_def}))"),
    msg=caller,
  )
  assert_true(
    caller.contains("(call (Func \{fourteenth_target_def}))(end)"),
    msg=caller,
  )
}

///|
#skip("manual large-module DAE scheduler smoke; run through the dedicated fuzz/parity lane")
test "dae-optimizing reaches low dropped-result callee after large descending budget" {
  let low_target_def = 600
  let high_target_start = 4644
  let high_target_count = 8
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < low_target_def; i = i + 1 {
    out.write_string("  (func $pad_low\{i})\n")
  }
  out.write_string(
    "  (func $low_target (param i32 i32) (result i32)\n    local.get 0\n    call $side\n    local.get 1\n    call $side\n    local.get 0\n    local.get 1\n    i32.add)\n",
  )
  for i = low_target_def + 1; i < high_target_start; i = i + 1 {
    out.write_string("  (func $pad_high\{i})\n")
  }
  for i = 0; i < high_target_count; i = i + 1 {
    out.write_string(
      "  (func $high_target\{i} (param i32 i32) (result i32)\n    local.get 0\n    call $side\n    local.get 1\n    call $side\n    local.get 0\n    local.get 1\n    i32.add)\n",
    )
  }
  out.write_string("  (func $side (param i32))\n  (func (export \"run\")\n")
  out.write_string(
    "    i32.const 1\n    i32.const 2\n    call $low_target\n    drop\n",
  )
  for i = 0; i < high_target_count; i = i + 1 {
    out.write_string(
      "    i32.const \{10 + i}\n    i32.const \{32 - i}\n    call $high_target\{i}\n    drop\n",
    )
  }
  out.write_string("  )\n)\n")
  let optimized = dae_test_run(out.to_string())
  @debug.assert_eq(dae_test_func_results(optimized, low_target_def).length(), 0)
  for i = 0; i < high_target_count; i = i + 1 {
    @debug.assert_eq(
      dae_test_func_results(optimized, high_target_start + i).length(),
      0,
    )
  }
}

///|
test "dae-optimizing materializes pure exact-literal callees across definition ranges" {
  for
    target_def in [
      311, 408, 428, 538, 869, 1720, 1755, 1775, 1794, 2156, 3736, 4117, 4134, 4303,
      4320,
    ] {
    let out = StringBuilder::new()
    out.write_string("(module\n")
    for i = 0; i < 8; i = i + 1 {
      out.write_string(
        "  (func $g\{i} (param i32 i32)\n    local.get 0\n    drop)\n",
      )
    }
    for i = 8; i < target_def; i = i + 1 {
      out.write_string("  (func $pad\{i})\n")
    }
    out.write_string(
      (
        #|  (func $target (param i32) (result i32)
        #|    local.get 0
        #|    i32.const 1
        #|    i32.add)
        #|  (func (export "run") (result i32)
      ),
    )
    for i = 0; i < 8; i = i + 1 {
      out.write_string("    i32.const 1\n    i32.const 2\n    call $g\{i}\n")
    }
    out.write_string(
      (
        #|    i32.const 10032
        #|    call $target)
        #|)
      ),
    )
    let optimized = dae_test_run(out.to_string())
    assert_true(
      dae_test_func_params(optimized, target_def).length() == 0,
      msg="target_def=\{target_def}",
    )
  }
}

///|
#skip("manual artifact-derived DAE definition-range fixture; bounded single-use const-local behavior remains covered")
test "dae-optimizing inlines selected Func408 single-use const local" {
  let target_def = 408
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (param i32) (result i32) (local i32)
      #|    i32.const 31480
      #|    local.set 1
      #|    local.get 0
      #|    local.get 1
      #|    call $use)
      #|  (func $use (param i32 i32) (result i32)
      #|    local.get 0
      #|    local.get 1
      #|    i32.add)
      #|  (func (export "run") (result i32)
      #|    i32.const 9
      #|    call $target)
    ),
  )
  for i = target_def + 3; i < 1030; i = i + 1 {
    out.write_string("  (func $tail\{i})\n")
  }
  out.write_string(")\n")
  let optimized = dae_test_run(out.to_string())
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  assert_true(target.contains("i32.const I32(31480)"), msg=target)
  assert_false(target.contains("local.set (Local 1)"), msg=target)
  assert_false(target.contains("local.get (Local 1)"), msg=target)
}

///|
#skip("manual artifact-derived DAE definition-range fixture; bounded pair-if cleanup remains covered")
test "dae-optimizing reshapes a touched pair-if carrier at an arbitrary definition" {
  let target_def = 709
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (param i32) (result i32 i32)
      #|    (local i32 i32 i32 i32 i32 i32 i32)
      #|    local.get 0
      #|    call $pair
      #|    local.set 7
      #|    if (result i32)
      #|      local.get 7
      #|    else
      #|      i32.const 0
      #|      local.get 7
      #|      return
      #|    end
      #|    local.set 1
      #|    nop
      #|    i32.const 1
      #|    local.get 0
      #|    local.get 1
      #|    call $use
      #|    call $wrap)
      #|  (func $pair (param i32) (result i32 i32)
      #|    local.get 0
      #|    i32.const 9)
      #|  (func $use (param i32 i32) (result i32)
      #|    local.get 1)
      #|  (func $wrap (param i32) (result i32)
      #|    local.get 0)
      #|  (func (export "run1") (result i32 i32)
      #|    i32.const 1
      #|    call $target)
      #|  (func (export "run2") (result i32 i32)
      #|    i32.const 2
      #|    call $target)
    ),
  )
  for i = target_def + 6; i < 1030; i = i + 1 {
    out.write_string("  (func $tail\{i})\n")
  }
  out.write_string(")\n")
  let optimized = dae_test_run(out.to_string())
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  assert_true(target.contains("local.tee (Local 2)"), msg=target)
  assert_true(target.contains("local.set (Local 4)"), msg=target)
  assert_false(target.contains("local.set (Local 7)"), msg=target)
  assert_false(target.contains("local.get (Local 7)"), msg=target)
}

///|
#skip("manual artifact-derived DAE definition-range fixture; bounded unchanged-boundary behavior remains covered")
test "dae-optimizing preserves Binaryen nops without a DAE boundary change" {
  let target_def = 408
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (param i32) (result i32)
      #|    nop
      #|    local.get 0
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      nop
      #|      i32.const 0
      #|    end)
      #|  (func (export "run1") (result i32)
      #|    i32.const 1
      #|    call $target)
      #|  (func (export "run2") (result i32)
      #|    i32.const 2
      #|    call $target)
    ),
  )
  for i = target_def + 3; i < 1030; i = i + 1 {
    out.write_string("  (func $tail\{i})\n")
  }
  out.write_string(")\n")
  let optimized = dae_test_run(out.to_string())
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  assert_true(target.contains("nop"), msg=target)
}

///|
test "dae-optimizing materializes uniform v128 actuals" {
  let source =
    #|(module
    #|  (func $target (param v128) (result v128)
    #|    local.get 0)
    #|  (func (export "run") (result v128)
    #|    v128.const i32x4 1 2 3 4
    #|    call $target))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  let target = optimized.pretty_print_defined_func(0U)
  assert_false(target.contains("local.get"), msg=target)
  assert_true(
    target.contains("v128.const") || target.contains("V128Const"),
    msg=target,
  )
}

///|
test "dae-optimizing materializes uniform ref.func actuals" {
  let source =
    #|(module
    #|  (func $referenced)
    #|  (elem declare func $referenced)
    #|  (func $target (param funcref) (result funcref)
    #|    local.get 0)
    #|  (func (export "run") (result funcref)
    #|    ref.func $referenced
    #|    call $target))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 0)
  let target = optimized.pretty_print_defined_func(1U)
  assert_false(target.contains("local.get"), msg=target)
  assert_true(
    target.contains("ref.func") || target.contains("RefFunc"),
    msg=target,
  )
}

///|
test "dae-optimizing materializes uniform externalized i31 actuals" {
  let source =
    #|(module
    #|  (func $target (param externref) (result externref)
    #|    local.get 0)
    #|  (func (export "run") (result externref)
    #|    i32.const 7
    #|    ref.i31
    #|    extern.convert_any
    #|    call $target
    #|    drop
    #|    i32.const 7
    #|    ref.i31
    #|    extern.convert_any
    #|    call $target))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  let target = optimized.pretty_print_defined_func(0U)
  assert_false(target.contains("local.get"), msg=target)
  assert_true(target.contains("ref.i31"), msg=target)
  assert_true(target.contains("extern.convert_any"), msg=target)
}

///|
test "dae-optimizing materializes uniform re-internalized i31 actuals" {
  let source =
    #|(module
    #|  (func $target (param anyref) (result anyref)
    #|    local.get 0)
    #|  (func (export "run") (result anyref)
    #|    i32.const 7
    #|    ref.i31
    #|    extern.convert_any
    #|    any.convert_extern
    #|    call $target
    #|    drop
    #|    i32.const 7
    #|    ref.i31
    #|    extern.convert_any
    #|    any.convert_extern
    #|    call $target))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  let target = optimized.pretty_print_defined_func(0U)
  assert_false(target.contains("local.get"), msg=target)
  assert_true(target.contains("ref.i31"), msg=target)
  assert_true(target.contains("extern.convert_any"), msg=target)
  assert_true(target.contains("any.convert_extern"), msg=target)
}

///|
test "dae-optimizing materializes uniform string.const actuals" {
  let source =
    #|(module
    #|  (func $target (param stringref) (result stringref)
    #|    local.get 0)
    #|  (func (export "run") (result stringref)
    #|    string.const "hello"
    #|    call $target
    #|    drop
    #|    string.const "hello"
    #|    call $target))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  let target = optimized.pretty_print_defined_func(0U)
  assert_false(target.contains("local.get"), msg=target)
  assert_true(target.contains("string.const"), msg=target)
}

///|
test "dae-optimizing materializes selected Func521 literal actual" {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < 504; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (param i32 i32) (result i32)
      #|    local.get 0)
      #|  (func (export "run") (param i32) (result i32)
      #|    local.get 0
      #|    i32.const 55168
      #|    call $target)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  @debug.assert_eq(dae_test_func_params(optimized, 504).length(), 1)
  let run = optimized.pretty_print_defined_func(505U)
  assert_false(run.contains("55168"), msg=run)
}

///|
test "dae-optimizing materializes mid-range literal actual and applies nested cleanup" {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < 505; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (param i32 i32) (result i32)
      #|    (local i32 i32)
      #|    local.get 0
      #|    local.tee 2
      #|    i32.const 48
      #|    i32.lt_s
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      local.get 3
      #|      i32.const 57
      #|      i32.gt_s
      #|    end
      #|    if
      #|      i32.const -1
      #|      return
      #|    end
      #|    local.get 1
      #|    drop
      #|    local.get 2)
      #|  (func (export "run") (param i32) (result i32)
      #|    local.get 0
      #|    i32.const 55168
      #|    call $target)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  @debug.assert_eq(dae_test_func_params(optimized, 505).length(), 1)
  let target = optimized.pretty_print_defined_func(505U)
  assert_false(target.contains("55168"), msg=target)
  // Binaryen v131's optimizing suffix removes the dead tee after DAE.
  assert_false(target.contains("local.tee"), msg=target)
  assert_true(target.contains("i32.lt_s"), msg=target)
  assert_false(target.contains("i32.gt_s"), msg=target)
}

///|
test "dae-optimizing inverts zero-eq value branch after selected Func505 rewrite" {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < 505; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (param i32 i32) (result i32)
      #|    (local i32)
      #|    i32.const 1
      #|    local.set 2
      #|    local.get 2
      #|    i32.const 0
      #|    i32.eq
      #|    if (result i32)
      #|      i32.const -1
      #|    else
      #|      local.get 0
      #|    end)
      #|  (func (export "run") (param i32) (result i32)
      #|    local.get 0
      #|    i32.const 55168
      #|    call $target)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  @debug.assert_eq(dae_test_func_params(optimized, 505).length(), 1)
  let target = optimized.pretty_print_defined_func(505U)
  assert_false(target.contains("55168"), msg=target)
  assert_false(target.contains("i32.eq"), msg=target)
}

///|
test "dae-optimizing removes bool-result guard carrier after selected Func505 rewrite" {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < 505; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (param i32 i32) (result i32)
      #|    local.get 0
      #|    i32.const 48
      #|    i32.lt_s
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      i32.const 0
      #|    end
      #|    if
      #|      i32.const -1
      #|      return
      #|    end
      #|    local.get 1
      #|    drop
      #|    local.get 0)
      #|  (func (export "run") (param i32) (result i32)
      #|    local.get 0
      #|    i32.const 55168
      #|    call $target)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  @debug.assert_eq(dae_test_func_params(optimized, 505).length(), 1)
  let target = optimized.pretty_print_defined_func(505U)
  assert_false(target.contains("55168"), msg=target)
  assert_false(target.contains("if I32"), msg=target)
}

///|
test "dae-optimizing materializes immutable global actuals independent of module cardinality" {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (global $g i32 (i32.const 42))\n")
  for i = 0; i < 313; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (param i32 i32 i32) (result i32)
      #|    local.get 0
      #|    local.get 1
      #|    i32.add
      #|    local.get 2
      #|    i32.add)
      #|  (func (export "run") (result i32)
      #|    i32.const 1
      #|    global.get $g
      #|    i32.const 2
      #|    call $target)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  @debug.assert_eq(dae_test_func_params(optimized, 313).length(), 0)
  let target = optimized.pretty_print_defined_func(313U)
  // Binaryen v131's optimizing suffix folds the injected immutable global.
  assert_false(target.contains("global.get"), msg=target)
  assert_true(target.contains("i32.const I32(45)"), msg=target)
}

///|
#skip("manual artifact-scale DAE parity fixture; focused transform behavior remains in bounded tests")
test "dae-optimizing materializes high immutable global actuals outside selected list" {
  let target_def = 1500
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (global $g i32 (i32.const 99))\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (param i32) (result i32)
      #|    local.get 0
      #|    i32.const 1
      #|    i32.add)
      #|  (func (export "run") (result i32)
      #|    global.get $g
      #|    call $target)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  @debug.assert_eq(dae_test_func_params(optimized, target_def).length(), 0)
  let target = optimized.pretty_print_defined_func(
    target_def.reinterpret_as_uint(),
  )
  assert_true(target.contains("global.get"), msg=target)
}

///|
#skip("manual artifact-scale DAE parity fixture; focused transform behavior remains in bounded tests")
test "dae-optimizing keeps mutable global actuals outside selected list" {
  let target_def = 1500
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (global $g (mut i32) (i32.const 99))\n")
  for i = 0; i < target_def; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (param i32) (result i32)
      #|    local.get 0
      #|    i32.const 1
      #|    i32.add)
      #|  (func (export "run") (result i32)
      #|    global.get $g
      #|    call $target)
      #|)
    ),
  )
  let optimized = dae_test_run(out.to_string())
  @debug.assert_eq(dae_test_func_params(optimized, target_def).length(), 1)
}

///|
#skip("manual artifact-scale DAE scheduler fixture; bounded exact-literal discovery remains covered")
test "dae-optimizing materializes a high exact-literal callee after the mid-prefix slices" {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for i = 0; i < 8; i = i + 1 {
    out.write_string(
      "  (func $g\{i} (param i32 i32)\n    local.get 0\n    drop)\n",
    )
  }
  for i = 8; i < 1720; i = i + 1 {
    out.write_string("  (func $pad\{i})\n")
  }
  out.write_string(
    (
      #|  (func $target (param i32) (result i32)
      #|    local.get 0
      #|    i32.const 1
      #|    i32.add)
      #|  (func (export "run") (result i32)
    ),
  )
  for i = 0; i < 8; i = i + 1 {
    out.write_string("    i32.const 1\n    i32.const 2\n    call $g\{i}\n")
  }
  out.write_string(
    (
      #|    i32.const 10032
      #|    call $target)
      #|)
    ),
  )
  let source = out.to_string()
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 1720).length(), 0)
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
#skip("manual artifact-scale DAE scheduler fixture; candidate discovery is covered by bounded tests")
test "dae-optimizing discovers a broad exact-literal candidate without a definition list" {
  let target_def = 4200
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for def_idx = 0; def_idx < target_def; def_idx = def_idx + 1 {
    out.write_string("  (func $pad\{def_idx})\n")
  }
  out.write_string(
    (
      #|  (func $target (param i32) (result i32)
      #|    local.get 0)
      #|  (func (export "run") (result i32)
      #|    i32.const 7
      #|    call $target))
    ),
  )
  let optimized = dae_test_run(out.to_string())
  @debug.assert_eq(dae_test_func_params(optimized, target_def).length(), 0)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected broad exact-literal output, got \{err}")
  }
}

///|
#skip("manual artifact-scale DAE scheduler fixture; uniform constructor behavior is covered by bounded tests")
test "dae-optimizing discovers a fully uniform multi-parameter constructor without a definition list" {
  let target_def = 4200
  let out = StringBuilder::new()
  out.write_string(
    "(module\n  (import \"env\" \"malloc\" (func $malloc (param i32) (result i32)))\n  (memory 1)\n",
  )
  for def_idx = 0; def_idx < target_def; def_idx = def_idx + 1 {
    out.write_string("  (func $pad\{def_idx})\n")
  }
  out.write_string(
    (
      #|  (func $target (param i32 i64 i64) (result i32)
      #|    (local i32)
      #|    i32.const 24
      #|    call $malloc
      #|    local.tee 3
      #|    local.get 0
      #|    i32.store
      #|    local.get 3
      #|    local.get 1
      #|    i64.store offset=8
      #|    local.get 3
      #|    local.get 2
      #|    i64.store offset=16
      #|    local.get 3)
      #|  (func (export "run") (result i32)
      #|    i32.const 7
      #|    i64.const 11
      #|    i64.const 13
      #|    call $target))
    ),
  )
  let optimized = dae_test_run(out.to_string())
  @debug.assert_eq(dae_test_func_params(optimized, target_def).length(), 0)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected valid broad multi-parameter output, got \{err}")
  }
}

///|
#skip("manual artifact-scale DAE forwarding fixture; recursive uniform flow remains covered by bounded tests")
test "dae-optimizing solves a high-definition uniform identity through a recursive forwarding component" {
  let first_flow_def = 4200
  let target_def = first_flow_def + 2
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for def_idx = 0; def_idx < first_flow_def; def_idx = def_idx + 1 {
    out.write_string("  (func $pad\{def_idx})\n")
  }
  out.write_string(
    (
      #|  (func $a (param i32) (result i32)
      #|    local.get 0
      #|    call $b)
      #|  (func $b (param i32) (result i32)
      #|    local.get 0
      #|    call $target
      #|    drop
      #|    local.get 0
      #|    call $a)
      #|  (func $target (param i32) (result i32)
      #|    local.get 0)
      #|  (func (export "run") (result i32)
      #|    i32.const 7
      #|    call $a))
    ),
  )
  let source = out.to_string()
  for pass_name in ["dead-argument-elimination", "dae-optimizing"] {
    let optimized = dae_test_run(source, pass_name~)
    assert_true(
      dae_test_func_params(optimized, target_def).length() == 0,
      msg="expected solved target parameter removal for \{pass_name}: \{optimized.pretty_print_func(@lib.FuncIdx::new(target_def.reinterpret_as_uint()))}",
    )
    match @validate.validate_module(optimized) {
      Ok(_) => ()
      Err(err) =>
        fail(
          "expected valid solved recursive uniform output for \{pass_name}, got \{err}",
        )
    }
  }
}

///|
#skip("manual aggregate scheduler replay; forwarded constants and wrapper ordering have bounded tests")
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
    trace.contains("pass[dae-optimizing]:core-worklist iter=6 primary_def=6"),
    msg=trace.to_string(),
  )
}

///|
#skip("manual aggregate scheduler replay; low forwarded-constant revisits have direct worklist coverage")
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
test "plain DAE localizes hard removed direct-call operands into typed scratch locals" {
  let source =
    #|(module
    #|  (global $g (mut i32) (i32.const 0))
    #|  (func $side (result i32)
    #|    i32.const 1
    #|    global.set $g
    #|    i32.const 7)
    #|  (func $f (param i32 i32) (result i32)
    #|    local.get 1)
    #|  (func (export "run") (result i32)
    #|    block (result i32)
    #|      call $side
    #|    end
    #|    i32.const 13
    #|    call $f)
    #|  (func $other (result i32)
    #|    block (result i32)
    #|      call $side
    #|    end
    #|    i32.const 14
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 1)
  let callee = optimized.pretty_print_defined_func(1U)
  let caller = optimized.pretty_print_defined_func(2U)
  let other = optimized.pretty_print_defined_func(3U)
  assert_true(callee.contains("[1] I32 (local)"), msg=callee)
  assert_true(caller.contains("local.set"), msg=caller)
  assert_true(other.contains("local.set"), msg=other)
  assert_false(caller.contains("drop"), msg=caller)
  assert_false(other.contains("drop"), msg=other)
  assert_true(caller.contains("(call (Func 0))"), msg=caller)
  assert_true(caller.contains("i32.const I32(13)"), msg=caller)
  assert_true(other.contains("i32.const I32(14)"), msg=other)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected localized plain DAE output to validate, got \{err}")
  }
}

///|
#skip("manual composite localization replay; public scalar localization and nullable scratch typing are covered separately")
test "plain DAE keeps a non-nullable ref stack-carried while localizing a removed operand" {
  let source =
    #|(module
    #|  (type $s (struct))
    #|  (global $g (mut i32) (i32.const 0))
    #|  (func $make (result (ref $s))
    #|    i32.const 1
    #|    global.set $g
    #|    struct.new_default $s)
    #|  (func $side (result i32)
    #|    i32.const 2
    #|    global.set $g
    #|    i32.const 7)
    #|  (func $f (param (ref $s) i32) (result i32)
    #|    local.get 0
    #|    ref.is_null)
    #|  (func (export "run") (result i32)
    #|    call $make
    #|    block (result i32)
    #|      call $side
    #|    end
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  @debug.assert_eq(dae_test_func_params(optimized, 2).length(), 1)
  let caller = optimized.pretty_print_defined_func(3U)
  assert_true(caller.contains("local.set"), msg=caller)
  assert_false(caller.contains("local.get"), msg=caller)
  assert_true(caller.contains("(call (Func 0))"), msg=caller)
  assert_true(caller.contains("(call (Func 1))"), msg=caller)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected non-nullable localized DAE output to validate, got \{err}")
  }
}

///|
test "plain DAE reuses one typed scratch local across sequential and nested localized calls" {
  let source =
    #|(module
    #|  (global $g (mut i32) (i32.const 0))
    #|  (func $side (result i32)
    #|    i32.const 1
    #|    global.set $g
    #|    i32.const 7)
    #|  (func $f (param i32 i32) (result i32)
    #|    local.get 1)
    #|  (func (export "run") (result i32)
    #|    block (result i32)
    #|      call $side
    #|    end
    #|    i32.const 13
    #|    call $f
    #|    drop
    #|    block (result i32)
    #|      block (result i32)
    #|        call $side
    #|      end
    #|      i32.const 14
    #|      call $f
    #|    end))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 1)
  let @lib.Func(locals, @lib.Expr(body)) = dae_test_defined_func(optimized, 2)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  let scratch = @lib.LocalIdx::new(0U)
  @debug.assert_eq(dae_test_count_local_set_instrs(body, scratch), 2)
  assert_false(dae_test_instrs_reference_local(body, @lib.LocalIdx::new(1U)))
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected scratch-reusing plain DAE output to validate, got \{err}")
  }
}

///|
test "plain DAE localizes hard removed return_call operands into typed scratch locals" {
  let source =
    #|(module
    #|  (global $g (mut i32) (i32.const 0))
    #|  (func $side (result i32)
    #|    i32.const 1
    #|    global.set $g
    #|    i32.const 7)
    #|  (func $entry (export "run") (result i32)
    #|    block (result i32)
    #|      call $side
    #|    end
    #|    i32.const 13
    #|    return_call $f)
    #|  (func $f (param i32 i32) (result i32)
    #|    local.get 1)
    #|  (func $other (result i32)
    #|    block (result i32)
    #|      call $side
    #|    end
    #|    i32.const 14
    #|    return_call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  @debug.assert_eq(dae_test_func_params(optimized, 2).length(), 1)
  let entry = optimized.pretty_print_defined_func(1U)
  let callee = optimized.pretty_print_defined_func(2U)
  let other = optimized.pretty_print_defined_func(3U)
  assert_true(callee.contains("[1] I32 (local)"), msg=callee)
  assert_true(entry.contains("local.set"), msg=entry)
  assert_true(other.contains("local.set"), msg=other)
  assert_false(entry.contains("drop"), msg=entry)
  assert_false(other.contains("drop"), msg=other)
  assert_true(entry.contains("return_call"), msg=entry)
  assert_true(other.contains("return_call"), msg=other)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected localized return_call DAE output to validate, got \{err}")
  }
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
test "dae-optimizing preserves results on functions that tail-call result callees" {
  let source =
    #|(module
    #|  (func $start
    #|    i32.const 0
    #|    call $g
    #|    drop)
    #|  (start $start)
    #|  (func $g (param i32) (result i32)
    #|    i32.const 1
    #|    call $g
    #|    drop
    #|    local.get 0
    #|    return_call $f)
    #|  (func $f (param i32) (result i32)
    #|    local.get 0))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 1)
  @debug.assert_eq(dae_test_func_results(optimized, 2).length(), 1)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected tail-call result-preservation DAE output to validate, got \{err}",
      )
  }
}

///|
test "dae-optimizing preserves results for return_call sites after unreachable roots" {
  let source =
    #|(module
    #|  (func $start
    #|    i32.const 0
    #|    call $f
    #|    drop)
    #|  (start $start)
    #|  (func $tail_after_unreachable (param i32) (result i32)
    #|    unreachable
    #|    local.get 0
    #|    return_call $f)
    #|  (func $f (param i32) (result i32)
    #|    local.get 0))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 1)
  @debug.assert_eq(dae_test_func_results(optimized, 2).length(), 1)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected unreachable-suffix return_call DAE output to validate, got \{err}",
      )
  }
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
test "dae-optimizing reruns DAE after unused-return cleanup exposes dead params" {
  let source =
    #|(module
    #|  (func (export "main") (result i32)
    #|    i32.const 10
    #|    i32.const 11
    #|    call $f
    #|    drop
    #|    i32.const 12)
    #|  (func $f (param i32 i32) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    i32.add)
    #|  (func (result i32)
    #|    i32.const 20
    #|    i32.const 21
    #|    call $f
    #|    drop
    #|    i32.const 22))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 0)
  let main = optimized.pretty_print_defined_func(0U)
  let helper = optimized.pretty_print_defined_func(1U)
  let other = optimized.pretty_print_defined_func(2U)
  assert_true(main.contains("(call (Func 1))"), msg=main)
  assert_false(main.contains("i32.const I32(10)"), msg=main)
  assert_false(main.contains("i32.const I32(11)"), msg=main)
  assert_false(main.contains("return"), msg=main)
  assert_true(helper.contains("nop"), msg=helper)
  assert_false(helper.contains("local.get"), msg=helper)
  assert_true(other.contains("(call (Func 1))"), msg=other)
  assert_false(other.contains("i32.const I32(20)"), msg=other)
  assert_false(other.contains("i32.const I32(21)"), msg=other)
  assert_false(other.contains("return"), msg=other)
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
test "dae-optimizing drops root-return dead suffix debris after touched rewrite" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $alloc (param i32) (result i32)
    #|    i32.const 64)
    #|  (func $f (param i32) (result i32)
    #|    (local i32)
    #|    i32.const 7
    #|    return
    #|    i32.const 8
    #|    call $alloc
    #|    local.set 1
    #|    local.get 1
    #|    i32.const 4
    #|    i32.store
    #|    local.get 1)
    #|  (func (export "run") (result i32)
    #|    i32.const 42
    #|    call $f))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 0)
  let body = optimized.pretty_print_defined_func(1U)
  assert_true(body.contains("i32.const I32(7)"), msg=body)
  assert_false(body.contains("call"), msg=body)
  assert_false(body.contains("i32.store"), msg=body)
  assert_false(body.contains("i32.const I32(8)"), msg=body)
}

///|
test "dae-optimizing ignores undropped calls in root-unreachable dead suffixes" {
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
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 2).length(), 1)
  let h = optimized.pretty_print_defined_func(2U)
  assert_true(h.contains("unreachable"), msg=h)
  assert_false(h.contains("call"), msg=h)
}

///|
test "dae-optimizing collapses dropped dead-suffix calls when removing result" {
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
  assert_true(caller.contains("unreachable"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
  assert_false(caller.contains("drop"), msg=caller)
}

///|
test "dae-optimizing repairs live-prefix dead-suffix call drops after result removal" {
  let source =
    #|(module
    #|  (func $side (param i32))
    #|  (func (export "main")
    #|    i32.const 3
    #|    call $side
    #|    block
    #|      unreachable
    #|    end
    #|    call $f
    #|    drop)
    #|  (func $f (result i32)
    #|    block
    #|      unreachable
    #|    end
    #|    i32.const 9))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_results(optimized, 2).length(), 0)
  let caller = optimized.pretty_print_defined_func(1U)
  assert_true(caller.contains("(call (Func 0))"), msg=caller)
  assert_true(caller.contains("unreachable"), msg=caller)
  assert_false(caller.contains("(call (Func 2))"), msg=caller)
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
test "dae-optimizing removes undropped no-param dead self suffix results" {
  let source =
    #|(module
    #|  (func $dead (result f64)
    #|    block
    #|      unreachable
    #|    end
    #|    call $dead)
    #|  (func (export "run")))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_results(optimized, 0).length(), 0)
  let dead = optimized.pretty_print_defined_func(0U)
  assert_true(dead.contains("unreachable"), msg=dead)
  assert_false(dead.contains("call"), msg=dead)
}

///|
test "dae-optimizing collapses unreachable self-suffix result bodies" {
  let source =
    #|(module
    #|  (func $dead (result i32)
    #|    i32.const 11
    #|    i32.const 3
    #|    i32.eq
    #|    drop
    #|    block
    #|      unreachable
    #|    end
    #|    call $side
    #|    drop
    #|    i32.const 7
    #|    drop
    #|    call $dead
    #|    drop
    #|    i32.const 1
    #|    if
    #|    else
    #|      nop
    #|    end
    #|    call $dead)
    #|  (func $side (result i32)
    #|    unreachable)
    #|  (func (export "run")))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_results(optimized, 0).length(), 0)
  let dead = optimized.pretty_print_defined_func(0U)
  assert_true(dead.contains("unreachable"), msg=dead)
  assert_false(dead.contains("i32.const"), msg=dead)
  assert_false(dead.contains("call"), msg=dead)
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
test "dae-optimizing removes no-param undropped self results with dead side callers" {
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
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 2).length(), 0)
}

///|
test "dae-optimizing removes results when dead self suffix has another call" {
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
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 0)
  let dead = optimized.pretty_print_defined_func(1U)
  assert_true(dead.contains("unreachable"), msg=dead)
  assert_false(dead.contains("call"), msg=dead)
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
#skip("manual composite result-side convergence replay; dropped/self/side-call facts have bounded coverage")
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
  @debug.assert_eq(dae_test_func_results(optimized, 2).length(), 0)
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
test "dae-optimizing keeps simple function types referenced by elem locals and ref ops" {
  let type_idx = @lib.TypeIdx::new(0U)
  let ref_type = @lib.RefType::new(true, @lib.HeapType::new(type_idx))
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::typed_exprs(ref_type, [
            @lib.Expr::new([@lib.Instruction::ref_null_type(ref_type)]),
          ]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([
            @lib.LocalRun::new(1U, @lib.ValType::ref_null_type(ref_type)),
          ]),
          @lib.Expr::new([
            @lib.Instruction::ref_null_type(ref_type),
            @lib.Instruction::drop(),
          ]),
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
test "dae-optimizing perf trace breaks down core, nested cleanup, and type pruning" {
  let (_, trace) = dae_test_run_with_perf_trace(
    (
      #|(module
      #|  (func $f (param i32 i32) (result i32)
      #|    local.get 0)
      #|  (func (export "run") (result i32)
      #|    i32.const 10
      #|    i32.const 20
      #|    call $f))
    ),
  )
  let text = trace.to_string()
  assert_true(text.contains("perf:timer name=detail:dae:core"), msg=text)
  assert_true(text.contains("perf:timer name=detail:dae:core:setup"), msg=text)
  assert_true(
    text.contains("perf:timer name=detail:dae:core:fixed-loop"),
    msg=text,
  )
  assert_true(
    text.contains("perf:timer name=detail:dae:core:selected-lanes"),
    msg=text,
  )
  assert_true(
    text.contains(
      "perf:timer name=detail:dae:core:selected-lanes:reverse-exact-literal",
    ),
    msg=text,
  )
  assert_true(
    text.contains(
      "perf:timer name=detail:dae:core:selected-lanes:low-wrapper-callees",
    ),
    msg=text,
  )
  assert_true(
    text.contains("perf:timer name=detail:dae:core:selected-lanes:early-shapes"),
    msg=text,
  )
  assert_true(
    text.contains(
      "perf:timer name=detail:dae:core:selected-lanes:dropped-results",
    ),
    msg=text,
  )
  assert_true(
    text.contains(
      "perf:timer name=detail:dae:core:selected-lanes:dropped-results:call-facts",
    ),
    msg=text,
  )
  assert_true(
    text.contains(
      "perf:timer name=detail:dae:core:selected-lanes:dropped-results:selected-defs",
    ),
    msg=text,
  )
  assert_false(
    text.contains(
      "perf:timer name=detail:dae:core:selected-lanes:dropped-results:func299-if",
    ),
    msg=text,
  )
  assert_true(
    text.contains(
      "perf:timer name=detail:dae:core:selected-lanes:literal-unread",
    ),
    msg=text,
  )
  assert_true(
    text.contains("perf:timer name=detail:dae:core:selected-lanes:late-shapes"),
    msg=text,
  )
  assert_true(
    text.contains("perf:timer name=detail:dae:core:raw-cleanup"),
    msg=text,
  )
  assert_true(
    text.contains("perf:timer name=detail:dae:core:post-raw-selected-lanes"),
    msg=text,
  )
  assert_true(
    text.contains("perf:timer name=detail:dae:nested-total"),
    msg=text,
  )
  assert_true(
    text.contains("perf:timer name=detail:dae:nested:vacuum"),
    msg=text,
  )
  assert_true(
    text.contains("perf:timer name=detail:dae:prune-unused-simple-func-types"),
    msg=text,
  )
}

///|
test "dae-optimizing nested tuple cleanup elides pure dropped multivalue spills" {
  let source =
    #|(module
    #|  (type $mv (func (result i32 i64)))
    #|  (func $f (param i32) (local i32 i64)
    #|    block (type $mv)
    #|      i32.const 7
    #|      i64.const 9
    #|    end
    #|    local.set 2
    #|    local.set 1
    #|    local.get 1
    #|    drop
    #|    local.get 2
    #|    drop)
    #|  (func (export "run")
    #|    i32.const 0
    #|    call $f))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  let target = optimized.pretty_print_defined_func(0U)
  assert_false(target.contains("block (type"), msg=target)
  assert_false(target.contains("local.set"), msg=target)
  assert_false(target.contains("local.get"), msg=target)
  assert_false(target.contains("drop"), msg=target)
}

///|
test "plain DAE keeps tuple spill cleanup out of the shared core" {
  let source =
    #|(module
    #|  (type $mv (func (result i32 i64)))
    #|  (func $f (param i32)
    #|    block (type $mv)
    #|      i32.const 7
    #|      i64.const 9
    #|    end
    #|    drop
    #|    drop)
    #|  (func (export "run")
    #|    i32.const 0
    #|    call $f))
  let optimized = dae_test_run(source, pass_name="dead-argument-elimination")
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  let target = optimized.pretty_print_defined_func(0U)
  assert_true(target.contains("(block (Type"), msg=target)
  assert_true(target.contains("drop"), msg=target)
}

///|
test "dae-optimizing nested tuple cleanup preserves effectful multivalue prefixes" {
  let source =
    #|(module
    #|  (type $mv (func (result i32 i64)))
    #|  (import "env" "effect" (func $effect))
    #|  (func $f (param i32) (local i32 i64)
    #|    block (type $mv)
    #|      call $effect
    #|      i32.const 7
    #|      i64.const 9
    #|    end
    #|    local.set 2
    #|    local.set 1
    #|    local.get 1
    #|    drop
    #|    local.get 2
    #|    drop)
    #|  (func (export "run")
    #|    i32.const 0
    #|    call $f))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  let target = optimized.pretty_print_defined_func(0U)
  assert_true(target.contains("call (Func 0)"), msg=target)
  assert_false(target.contains("(block (Type"), msg=target)
  assert_false(target.contains("local.set"), msg=target)
  assert_false(target.contains("local.get"), msg=target)
}

///|
test "dae-optimizing nested tuple cleanup preserves trapping multivalue prefixes" {
  let source =
    #|(module
    #|  (type $mv (func (result i32 i64)))
    #|  (memory 1)
    #|  (func $f (param i32) (local i32 i64)
    #|    block (type $mv)
    #|      memory.size
    #|      i32.const 16
    #|      i32.shl
    #|      i32.load
    #|      drop
    #|      i32.const 7
    #|      i64.const 9
    #|    end
    #|    local.set 2
    #|    local.set 1
    #|    local.get 1
    #|    drop
    #|    local.get 2
    #|    drop)
    #|  (func (export "run")
    #|    i32.const 0
    #|    call $f))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  let target = optimized.pretty_print_defined_func(0U)
  assert_true(target.contains("i32.load"), msg=target)
  assert_false(target.contains("(block (Type"), msg=target)
  assert_false(target.contains("local.set"), msg=target)
  assert_false(target.contains("local.get"), msg=target)
}

///|
test "dae-optimizing preserves constant zero-divisor traps through nested cleanup" {
  let source =
    #|(module
    #|  (type $mv (func (result i32 i64)))
    #|  (func $f (param i32) (local i32 i64)
    #|    block (type $mv)
    #|      i32.const 1
    #|      i32.const 0
    #|      i32.div_s
    #|      drop
    #|      i32.const 7
    #|      i64.const 9
    #|    end
    #|    local.set 2
    #|    local.set 1
    #|    local.get 1
    #|    drop
    #|    local.get 2
    #|    drop)
    #|  (func (export "run")
    #|    i32.const 0
    #|    call $f))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  let target = optimized.pretty_print_defined_func(0U)
  assert_true(target.contains("i32.div_"), msg=target)
  assert_true(target.contains("drop"), msg=target)
  assert_false(target.contains("(block (Type"), msg=target)
  assert_false(target.contains("local.set"), msg=target)
  assert_false(target.contains("local.get"), msg=target)
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
  let expected = ["pass[dae-optimizing]:nested-pass name=precompute-propagate"]
  for pass_name in inlining_nested_function_pipeline_passes(4, 4) {
    expected.push("pass[dae-optimizing]:nested-pass name=\{pass_name}")
  }
  @debug.assert_eq(nested_passes, expected)
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
test "dae-optimizing routes oversized changed boundaries through transactional cleanup" {
  let source = "(module (func $f (param i32)" +
    dae_test_many_i32_locals(129) +
    " nop) (func (export \"run\") i32.const 1 call $f))"
  let (optimized, trace) = dae_test_run_with_perf_trace(source)
  let @lib.Func(locals, _) = dae_test_defined_func(optimized, 0)
  @debug.assert_eq(locals.length(), 0)
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[dae-optimizing]:broad-changed-boundary-local-cleanup def=0 removed_locals=129 mode=direct",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "dae-optimizing runs nested cleanup for large touched sets" {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  let mut idx = 0
  while idx < 9 {
    out.write_string("  (func $f\{idx} (param i32) nop)\n")
    idx += 1
  }
  out.write_string("  (func (export \"run\")\n")
  idx = 0
  while idx < 9 {
    out.write_string("    i32.const \{idx}\n    call $f\{idx}\n")
    idx += 1
  }
  out.write_string("  ))")
  let trace = match
    pass_test_capture_trace(out.to_string(), ["dae-optimizing"]) {
    Ok(trace) => trace
    Err(err) =>
      fail("expected traced large-touched-set DAE success, got \{err}")
  }
  assert_false(
    trace.any(fn(line) { line.contains("reason=large-touched-set") }),
    msg=trace.to_string(),
  )
  assert_false(
    trace.contains(
      "pass[dae-optimizing]:nested-cleanup touched=10 prefix=precompute-propagate",
    ),
    msg=trace.to_string(),
  )
  assert_true(
    trace.contains(
      "pass[dae-optimizing]:nested-cleanup touched=9 prefix=precompute-propagate",
    ),
    msg=trace.to_string(),
  )
  assert_true(
    trace.contains("pass[dae-optimizing]:nested-pass name=precompute-propagate"),
    msg=trace.to_string(),
  )
}

///|
test "dae-optimizing traces shared Binaryen v131 nested function prelude" {
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
  let expected_prelude = [
    "pass[dae-optimizing]:nested-pass name=precompute-propagate", "pass[dae-optimizing]:nested-pass name=ssa-nomerge",
    "pass[dae-optimizing]:nested-pass name=flatten", "pass[dae-optimizing]:nested-pass name=simplify-locals-notee-nostructure",
    "pass[dae-optimizing]:nested-pass name=local-cse",
  ]
  let mut next_expected = 0
  for line in trace {
    if next_expected < expected_prelude.length() &&
      line == expected_prelude[next_expected] {
      next_expected += 1
    }
  }
  @debug.assert_eq(next_expected, expected_prelude.length())
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
#skip("manual artifact-scale DAE cleanup benchmark; touched-caller cleanup remains covered by bounded tests")
test "dae-optimizing replays cleanup on material touched callers" {
  let out = StringBuilder::new()
  let prefix =
    #|(module
    #|  (import "env" "use" (func $use (param i32)))
    #|  (func $f (param i32 i32 i32)
    #|    block $exit
    #|      local.get 1
    #|      if
    #|        br $exit
    #|      else
    #|        local.get 2
    #|        if
    #|          br $exit
    #|        end
    #|      end
    #|    end)
    #|  (func (export "run") (param i32 i32) (local i32 i32)
    #|    i32.const 0
    #|    local.set 2
    #|    local.get 2
    #|    local.set 3
    #|    local.get 3
    #|    drop
    #|
  out.write_string(prefix)
  for repeat_idx = 0; repeat_idx < 600; repeat_idx = repeat_idx + 1 {
    out.write_string("    local.get 0\n    call $use\n")
  }
  let suffix =
    #|    block $exit
    #|      local.get 0
    #|      if
    #|        br $exit
    #|      else
    #|        local.get 1
    #|        if
    #|          br $exit
    #|        end
    #|      end
    #|    end
    #|    i32.const 0
    #|    local.get 0
    #|    local.get 1
    #|    call $f)
    #|
  out.write_string(suffix)
  for dummy_idx = 0; dummy_idx < 5000; dummy_idx = dummy_idx + 1 {
    out.write_string("  (func)\n")
  }
  out.write_string(")\n")
  let (optimized, trace) = dae_test_run_with_perf_trace(out.to_string())
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  let touched = optimized.pretty_print_defined_func(0U)
  assert_false(touched.contains("(if"), msg="\{touched}\n\{trace}")
  assert_false(touched.contains("br_if"), msg="\{touched}\n\{trace}")
  assert_true(touched.contains("nop"), msg="\{touched}\n\{trace}")
  assert_true(
    trace.contains(
      "pass[dae-optimizing]:broad-changed-boundary-nested-batch pass=all-changed-vacuum accepted_defs=[0]",
    ),
    msg="\{trace}",
  )
  let caller = optimized.pretty_print_defined_func(1U)
  let caller_local_count = match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(locals, _) = funcs[1]
      locals.length()
    }
    None => -1
  }
  @debug.assert_eq(caller_local_count, 0)
  assert_false(caller.contains("(if"), msg="\{caller}\n\{trace}")
  assert_true(caller.contains("br_if"), msg="\{caller}\n\{trace}")
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
test "dae-optimizing shared nested pipeline preserves Binaryen load shape and untouched functions" {
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
  assert_true(touched.contains("i32.load8u"), msg=touched)
  assert_true(touched.contains("i32.extend8s"), msg=touched)
  assert_false(touched.contains("local.set"), msg=touched)
  assert_false(touched.contains("local.get"), msg=touched)
  assert_true(untouched.contains("i32.load8u"), msg=untouched)
  assert_true(untouched.contains("local.set"), msg=untouched)
  assert_true(untouched.contains("local.get"), msg=untouched)
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
fn dae_test_grouped_signature_rewrite_module(
  keep_old_type_live : Bool,
) -> @lib.Module {
  let target_type = @lib.TypeIdx::new(1U)
  let run_type = @lib.TypeIdx::new(2U)
  let target_ref = @lib.RefType::new(true, @lib.HeapType::new(target_type))
  let mut mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::group([
          @lib.SubType::comp_type(@lib.CompType::struct_([])),
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ]),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([target_type, run_type, run_type]))
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("run"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(1U)),
        ),
        @lib.Export::new(
          @lib.Name::from_string("run2"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(2U)),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(0U))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(8)),
            @lib.Instruction::i32_const(@lib.I32(10)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ]),
        ),
      ]),
    )
  if keep_old_type_live {
    mod_ = mod_.with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(target_ref, @lib.Limits::i32(0U, None)),
          Some(@lib.Expr::new([@lib.Instruction::ref_null_type(target_ref)])),
        ),
      ]),
    )
  }
  mod_
}

///|
test "dae-optimizing rewrites an unreferenced grouped function signature in place" {
  let target_type = @lib.TypeIdx::new(1U)
  let optimized = match
    run_hot_pipeline(
      dae_test_grouped_signature_rewrite_module(false),
      HotPipelineOptions::new(),
      ["dae-optimizing"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected grouped signature rewrite success, got \{err}")
  }
  match (optimized.type_sec, optimized.func_sec) {
    (Some(type_sec), Some(@lib.FuncSec(type_idxs))) => {
      assert_eq(type_idxs[0], target_type)
      let @lib.TypeSec(rec_types) = type_sec
      @debug.assert_eq(rec_types.length(), 2)
      match rec_types[0] {
        @lib.GroupRecType(group) =>
          match group[1].get_comptype() {
            @lib.FuncCompType(params, results) => {
              @debug.assert_eq(params, [@lib.ValType::i32()])
              @debug.assert_eq(results, [@lib.ValType::i32()])
            }
            _ => fail("expected rewritten grouped function type")
          }
        _ => fail("expected grouped type entry")
      }
    }
    _ => fail("expected rewritten type and function sections")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected grouped signature output to validate, got \{err}")
  }
}

///|
test "dae-optimizing keeps a referenced grouped function type immutable" {
  let target_type = @lib.TypeIdx::new(1U)
  let optimized = match
    run_hot_pipeline(
      dae_test_grouped_signature_rewrite_module(true),
      HotPipelineOptions::new(),
      ["dae-optimizing"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected referenced grouped signature rewrite success, got \{err}")
  }
  match (optimized.type_sec, optimized.func_sec) {
    (Some(@lib.TypeSec(rec_types)), Some(@lib.FuncSec(type_idxs))) => {
      assert_not_eq(type_idxs[0], target_type)
      @debug.assert_eq(rec_types.length(), 3)
    }
    _ => fail("expected rewritten type and function sections")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected referenced grouped signature output to validate, got \{err}",
      )
  }
}

///|
test "dae-optimizing preserves grouped function results while removing params" {
  let target_type = @lib.TypeIdx::new(1U)
  let caller_type = @lib.TypeIdx::new(3U)
  let grouped_struct = @lib.SubType::comp_type(@lib.CompType::struct_([]))
  let grouped_target = @lib.SubType::comp_type(
    @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], [
      @lib.ValType::i32(),
    ]),
  )
  let misleading_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([], [@lib.ValType::f64(), @lib.ValType::i64()]),
    ),
  )
  let caller_func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::group([grouped_struct, grouped_target]),
        misleading_type,
        caller_func_type,
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([target_type, caller_type]))
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
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), ["dae-optimizing"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected grouped-type DAE pipeline success, got \{err}")
  }
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => assert_eq(type_idxs[0], caller_type)
    None => abort("missing rewritten function section")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected grouped-type DAE output to validate, got \{err}")
  }
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

///|
fn dae_test_many_touched_cleanup_guard_module() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for helper_idx = 0; helper_idx < 10; helper_idx = helper_idx + 1 {
    out.write_string(
      "  (func $h\{helper_idx} (param i32 i32) (result i32) (local i32) local.get 1 local.set 2 local.get 2 i32.const 0 i32.add)\n",
    )
  }
  out.write_string("  (func (export \"run\") (result i32)\n")
  for helper_idx = 0; helper_idx < 10; helper_idx = helper_idx + 1 {
    out.write_string(
      "    i32.const \{helper_idx}\n    i32.const \{helper_idx + 7}\n    call $h\{helper_idx}\n",
    )
    if helper_idx < 9 {
      out.write_string("    drop\n")
    }
  }
  out.write_string("  )\n)\n")
  out.to_string()
}

///|
test "dae-optimizing cleans changed boundaries when more than eight functions are touched" {
  let optimized = dae_test_run(dae_test_many_touched_cleanup_guard_module())
  for helper_idx = 0; helper_idx < 10; helper_idx = helper_idx + 1 {
    let @lib.Func(locals, _) = dae_test_defined_func(optimized, helper_idx)
    @debug.assert_eq(locals.length(), 0)
    let helper = optimized.pretty_print_defined_func(
      helper_idx.reinterpret_as_uint(),
    )
    assert_false(helper.contains("local.set"), msg=helper)
    assert_false(helper.contains("local.tee"), msg=helper)
    if helper_idx < 9 {
      assert_false(helper.contains("drop"), msg=helper)
    }
  }
}

///|
fn dae_test_medium_module_cleanup_guard_module() -> String {
  let out = StringBuilder::new()
  out.write_string(
    "(module\n  (func $helper (param i32 i32) (result i32) (local i32) local.get 1 local.set 2 local.get 2 i32.const 0 i32.add)\n  (func (export \"run\") (result i32) i32.const 9 i32.const 7 call $helper)\n",
  )
  for dummy_idx = 0; dummy_idx < 101; dummy_idx = dummy_idx + 1 {
    out.write_string("  (func)\n")
  }
  out.write_string(")\n")
  out.to_string()
}

///|
test "dae-optimizing cleans changed boundaries in modules above the generic size guard" {
  let optimized = dae_test_run(dae_test_medium_module_cleanup_guard_module())
  let @lib.Func(locals, _) = dae_test_defined_func(optimized, 0)
  @debug.assert_eq(locals.length(), 0)
  let helper = optimized.pretty_print_defined_func(0U)
  assert_false(helper.contains("local.set"), msg=helper)
  assert_false(helper.contains("local.tee"), msg=helper)
}

///|
fn dae_test_large_locals_cleanup_guard_module() -> String {
  let out = StringBuilder::new()
  out.write_string(
    "(module\n  (func $helper (param i32 i32) (result i32) (local",
  )
  for local_idx = 0; local_idx < 129; local_idx = local_idx + 1 {
    out.write_string(" i32")
  }
  out.write_string(
    ") local.get 1 local.set 2 local.get 2 i32.const 0 i32.add)\n  (func (export \"run\") (result i32) i32.const 9 i32.const 7 call $helper)\n)\n",
  )
  out.to_string()
}

///|
test "dae-optimizing cleans changed boundaries above the generic local-count guard" {
  let optimized = dae_test_run(dae_test_large_locals_cleanup_guard_module())
  let @lib.Func(locals, _) = dae_test_defined_func(optimized, 0)
  @debug.assert_eq(locals.length(), 0)
  let helper = optimized.pretty_print_defined_func(0U)
  assert_false(helper.contains("local.set"), msg=helper)
  assert_false(helper.contains("local.tee"), msg=helper)
}

///|
test "dae-optimizing removes a redundant return exposed by local cleanup" {
  let source =
    #|(module
    #|  (func $helper (param i32 i32) (result i32) (local i32 i32 i32)
    #|    local.get 1
    #|    local.set 2
    #|    local.get 2
    #|    return
    #|    i32.const 33
    #|    local.set 3
    #|    local.get 3)
    #|  (func (export "run") (result i32)
    #|    i32.const 101
    #|    i32.const 7
    #|    call $helper)
    #|  (func (result i32)
    #|    i32.const 102
    #|    i32.const 8
    #|    call $helper))
  let optimized = dae_test_run(source)
  let helper = optimized.pretty_print_defined_func(0U)
  assert_false(helper.contains("return"), msg=helper)
  assert_true(helper.contains("local.get (Local 0)"), msg=helper)
}

///|
test "dae-optimizing removes unread GC array constructor actuals" {
  let array_type = @lib.TypeIdx::new(0U)
  let array_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(array_type)),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::array(
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i32()),
                @lib.Mut::var_(),
              ),
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([array_ref, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([
        @lib.TypeIdx::new(1U),
        @lib.TypeIdx::new(2U),
        @lib.TypeIdx::new(2U),
        @lib.TypeIdx::new(2U),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(1U))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::array_new(array_type),
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(3)),
            @lib.Instruction::array_new_default(array_type),
            @lib.Instruction::i32_const(@lib.I32(8)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(4)),
            @lib.Instruction::i32_const(@lib.I32(5)),
            @lib.Instruction::array_new_fixed(array_type, @lib.U32::new(2U)),
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["dae-optimizing"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected GC array DAEO success, got \{err}")
  }
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 1)
  for def_idx in [1U, 2U, 3U] {
    let caller = optimized.pretty_print_defined_func(def_idx)
    assert_false(caller.contains("array.new"), msg=caller)
  }
}

///|
test "dae-optimizing removes unread GC constructor actuals and prunes their dead type" {
  let source =
    #|(module
    #|  (type $box (struct (field i32)))
    #|  (func $helper (param (ref $box) i32) (result i32) local.get 1)
    #|  (func (export "run") (result i32)
    #|    i32.const 1
    #|    struct.new $box
    #|    i32.const 7
    #|    call $helper)
    #|  (func (result i32)
    #|    i32.const 2
    #|    struct.new $box
    #|    i32.const 8
    #|    call $helper))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 1)
  assert_false(optimized.pretty_print_defined_func(1U).contains("struct.new"))
  assert_false(optimized.pretty_print_defined_func(2U).contains("struct.new"))
  match optimized.type_sec {
    Some(@lib.TypeSec(types)) => @debug.assert_eq(types.length(), 2)
    None => fail("expected compacted function types")
  }
}

///|
test "dae-optimizing removes unread table actuals while preserving growth and bounds traps" {
  let source =
    #|(module
    #|  (table 1 funcref)
    #|  (func $grow-helper (param i32 i32) (result i32) local.get 1)
    #|  (func $get-helper (param funcref i32) (result i32) local.get 1)
    #|  (func (export "run") (result i32)
    #|    ref.null func
    #|    i32.const 1
    #|    table.grow 0
    #|    i32.const 7
    #|    call $grow-helper)
    #|  (func (result i32)
    #|    i32.const 0
    #|    table.get 0
    #|    i32.const 8
    #|    call $get-helper))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 0)
  let grow_caller = optimized.pretty_print_defined_func(2U)
  let get_caller = optimized.pretty_print_defined_func(3U)
  assert_true(grow_caller.contains("table.grow"), msg=grow_caller)
  assert_true(get_caller.contains("table.get"), msg=get_caller)
}

///|
test "dae-optimizing removes unread computed actuals while preserving effects and traps" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (global $g (mut i32) (i32.const 0))
    #|  (func $helper (param i32 i32) (result i32)
    #|    local.get 1)
    #|  (func (export "run") (result i32)
    #|    i32.const 1
    #|    i32.const 2
    #|    i32.add
    #|    i32.const 99
    #|    global.set $g
    #|    i32.const 7
    #|    call $helper)
    #|  (func (result i32)
    #|    i32.const 0
    #|    memory.grow
    #|    i32.const 100
    #|    global.set $g
    #|    i32.const 8
    #|    call $helper)
    #|  (func (result i32)
    #|    i32.const 0
    #|    i32.load
    #|    i32.const 101
    #|    global.set $g
    #|    i32.const 9
    #|    call $helper))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 1)
  let helper = optimized.pretty_print_defined_func(0U)
  let pure = optimized.pretty_print_defined_func(1U)
  let effectful = optimized.pretty_print_defined_func(2U)
  let trapping = optimized.pretty_print_defined_func(3U)
  assert_true(helper.contains("local.get (Local 0)"), msg=helper)
  assert_false(pure.contains("i32.add"), msg=pure)
  assert_true(pure.contains("global.set"), msg=pure)
  assert_true(effectful.contains("memory.grow"), msg=effectful)
  assert_true(effectful.contains("drop"), msg=effectful)
  assert_true(trapping.contains("i32.load"), msg=trapping)
  assert_true(trapping.contains("drop"), msg=trapping)
}

///|
test "dae-optimizing folds small-module immutable global fields and follows exposed null callees" {
  let source =
    #|(module
    #|  (type $box (struct (field i32)))
    #|  (global $g (ref $box) (struct.new $box (i32.const 0)))
    #|  (func $leaf (param (ref null $box)) (result i32)
    #|    local.get 0
    #|    ref.is_null)
    #|  (func $target (param i32 (ref $box)) (result i32)
    #|    local.get 0
    #|    drop
    #|    local.get 1
    #|    struct.get $box 0
    #|    i32.eqz
    #|    if (result (ref null $box))
    #|      ref.null $box
    #|    else
    #|      local.get 1
    #|    end
    #|    call $leaf)
    #|  (func (export "run") (result i32)
    #|    i32.const 0
    #|    global.get $g
    #|    call $target))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 0)
  let leaf = optimized.pretty_print_defined_func(0U)
  let target = optimized.pretty_print_defined_func(1U)
  assert_true(leaf.contains("i32.const I32(1)"), msg=leaf)
  assert_false(target.contains("struct.get"), msg=target)
  assert_false(target.contains("(if"), msg=target)
  match optimized.type_sec {
    Some(@lib.TypeSec(types)) => @debug.assert_eq(types.length(), 2)
    None => fail("expected retained struct and compacted function types")
  }
}

///|
fn dae_test_broad_changed_boundary_local_cleanup_module() -> String {
  let helper_count = 10
  let total_defs = 4097
  let out = StringBuilder::new()
  out.write_string("(module\n  (global $sink (mut i32) (i32.const 0))\n")
  out.write_string("  (func $target (param i32) (result i32) (local")
  for local_idx = 0; local_idx < 128; local_idx = local_idx + 1 {
    out.write_string(" i32")
  }
  out.write_string(")\n    block\n    end\n")
  for local_idx = 0; local_idx < 32; local_idx = local_idx + 1 {
    out.write_string("    i32.const ")
    out.write_string(local_idx.to_string())
    out.write_string("\n    local.set ")
    out.write_string((local_idx + 1).to_string())
    out.write_string("\n    local.get ")
    out.write_string((local_idx + 1).to_string())
    out.write_string("\n    drop\n")
  }
  out.write_string("    i32.const 7)\n")
  out.write_string("  (func $target2 (param i32) (result i32) (local")
  for local_idx = 0; local_idx < 32; local_idx = local_idx + 1 {
    out.write_string(" i32")
  }
  out.write_string(
    ")\n    local.get 0\n    global.set $sink\n    block\n    end\n",
  )
  for local_idx = 0; local_idx < 8; local_idx = local_idx + 1 {
    out.write_string("    i32.const ")
    out.write_string((local_idx + 100).to_string())
    out.write_string("\n    local.set ")
    out.write_string((local_idx + 1).to_string())
    out.write_string("\n    local.get ")
    out.write_string((local_idx + 1).to_string())
    out.write_string("\n    drop\n")
  }
  out.write_string("    i32.const 8)\n")
  for helper_idx = 0; helper_idx < helper_count; helper_idx = helper_idx + 1 {
    out.write_string("  (func $helper")
    out.write_string(helper_idx.to_string())
    out.write_string(" (param i32))\n")
  }
  out.write_string("  (func (export \"run\") (result i32)\n")
  for helper_idx = 0; helper_idx < helper_count; helper_idx = helper_idx + 1 {
    out.write_string("    i32.const ")
    out.write_string(helper_idx.to_string())
    out.write_string("\n    call $helper")
    out.write_string(helper_idx.to_string())
    out.write_string("\n")
  }
  out.write_string(
    "    i32.const 100\n    call $target2\n    drop\n    i32.const 99\n    call $target)\n",
  )
  for dummy_idx = helper_count + 3
      dummy_idx < total_defs
      dummy_idx = dummy_idx + 1 {
    out.write_string("  (func)\n")
  }
  out.write_string(")\n")
  out.to_string()
}

///|
#skip("manual artifact-scale DAE cleanup benchmark; each local-cleanup family has bounded coverage")
test "dae-optimizing cleans every broad changed-boundary local family" {
  let source = dae_test_broad_changed_boundary_local_cleanup_module()
  let plain = dae_test_run(source, pass_name="dead-argument-elimination")
  let (optimized, trace) = dae_test_run_with_perf_trace(source)
  @debug.assert_eq(dae_test_func_params(plain, 0).length(), 0)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  @debug.assert_eq(dae_test_func_params(plain, 1).length(), 1)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 1)
  @debug.assert_eq(dae_test_func_results(plain, 1).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 0)
  let @lib.Func(plain_locals, _) = dae_test_defined_func(plain, 0)
  let @lib.Func(plain_locals2, _) = dae_test_defined_func(plain, 1)
  let @lib.Func(optimized_locals, _) = dae_test_defined_func(optimized, 0)
  let @lib.Func(optimized_locals2, _) = dae_test_defined_func(optimized, 1)
  @debug.assert_eq(plain_locals.length(), 128)
  @debug.assert_eq(plain_locals2.length(), 32)
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[dae-optimizing]:broad-changed-boundary-local-cleanup def=0 removed_locals=96 mode=direct",
      )
    }),
    msg=trace.to_string(),
  )
  @debug.assert_eq(optimized_locals.length(), 0)
  @debug.assert_eq(optimized_locals2.length(), 0)
  let plain_func = plain.pretty_print_defined_func(0U)
  let optimized_func = optimized.pretty_print_defined_func(0U)
  let optimized_func2 = optimized.pretty_print_defined_func(1U)
  assert_true(plain_func.contains("local.set"), msg=plain_func)
  assert_false(optimized_func.contains("local.set"), msg=optimized_func)
  assert_false(optimized_func2.contains("local.set"), msg=optimized_func2)
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[dae-optimizing]:broad-changed-boundary-nested-batch pass=",
      ) &&
      line.contains("accepted_defs=")
    }),
    msg=trace.to_string(),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[dae-optimizing]:broad-changed-boundary-nested-cleanup def=0 accepted=true",
      )
    }),
    msg=trace.to_string(),
  )
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected broad changed-boundary cleanup output to validate: \{err}")
  }
}

///|
fn dae_test_cleanup_exposed_unread_params_module() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n  (global $sink (mut i32) (i32.const 0))\n")
  for helper_idx = 0; helper_idx < 9; helper_idx = helper_idx + 1 {
    out.write_string("  (func $helper")
    out.write_string(helper_idx.to_string())
    out.write_string(" (param i32 i32)\n    i32.const ")
    out.write_string(helper_idx.to_string())
    out.write_string("\n    global.set $sink\n    local.get 1\n    drop)\n")
  }
  out.write_string("  (func (export \"run\")\n")
  for helper_idx = 0; helper_idx < 9; helper_idx = helper_idx + 1 {
    out.write_string("    i32.const ")
    out.write_string(helper_idx.to_string())
    out.write_string("\n    i32.const 7\n    call $helper")
    out.write_string(helper_idx.to_string())
    out.write_string("\n")
  }
  out.write_string("  )\n)\n")
  out.to_string()
}

///|
test "dae-optimizing final convergence follows the producer effect frontier" {
  let source =
    #|(module
    #|  (func $target (param i32) (local i32)
    #|    nop)
    #|  (func (export "run")
    #|    i32.const 7
    #|    call $target))
    #|
  let (once, trace) = dae_test_run_with_perf_trace(source)
  @debug.assert_eq(dae_test_func_params(once, 0).length(), 0)
  let @lib.Func(locals, _) = dae_test_defined_func(once, 0)
  @debug.assert_eq(locals.length(), 0)
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[dae-optimizing]:effect-frontier ") &&
      line.contains("wave=0")
    }),
    msg=trace.to_string(),
  )
  assert_false(
    trace.any(fn(line) { line.contains("final-convergence-check") }),
    msg=trace.to_string(),
  )
}

///|
test "dae-optimizing converges cleanup-exposed unread parameters in one invocation" {
  let once = dae_test_run(dae_test_cleanup_exposed_unread_params_module())
  for helper_idx = 0; helper_idx < 9; helper_idx = helper_idx + 1 {
    @debug.assert_eq(dae_test_func_params(once, helper_idx).length(), 0)
  }
  let twice = match
    run_hot_pipeline(once, HotPipelineOptions::new(), ["dae-optimizing"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected second DAE optimizing invocation, got \{err}")
  }
  @debug.assert_eq(twice, once)
}

///|
fn dae_test_large_uniform_const_actual_module() -> String {
  let leaf_def = 5000
  let out = StringBuilder::new()
  out.write_string(
    "(module\n  (type $box (struct (field i32)))\n  (import \"env\" \"use_i32\" (func $use_i32 (param i32)))\n  (global $g (ref $box) i32.const 0 struct.new $box)\n",
  )
  for dummy_idx = 0; dummy_idx < leaf_def; dummy_idx = dummy_idx + 1 {
    out.write_string("  (func)\n")
  }
  out.write_string(
    "  (func $leaf (param (ref null $box)) (result i32)\n    local.get 0\n    ref.is_null)\n  (func $target (param i32 (ref $box)) (result i32)\n    local.get 0\n    call $use_i32\n    local.get 1\n    struct.get $box 0\n    i32.eqz\n    if (result (ref null $box))\n      ref.null $box\n    else\n      local.get 1\n    end\n    call $leaf)\n  (func $literal (param i32) (result i32)\n",
  )
  for repeat_idx = 0; repeat_idx < 128; repeat_idx = repeat_idx + 1 {
    out.write_string("    local.get 0\n    drop\n")
  }
  out.write_string(
    "    local.get 0\n    i32.const 1\n    i32.add)\n  (func $forwarded (param i32) (result i32)\n",
  )
  for repeat_idx = 0; repeat_idx < 32; repeat_idx = repeat_idx + 1 {
    out.write_string("    local.get 0\n    drop\n")
  }
  out.write_string(
    "    local.get 0\n    call $forwarded_leaf)\n  (func $forwarded_leaf (param i32) (result i32)\n    local.get 0\n    i32.eqz)\n  (func $suffix (param (ref $box) i32) (result i32)\n",
  )
  for repeat_idx = 0; repeat_idx < 32; repeat_idx = repeat_idx + 1 {
    out.write_string("    local.get 1\n    drop\n")
  }
  out.write_string(
    "    local.get 1\n    call $use_i32\n    local.get 0\n    struct.get $box 0)\n  (func (export \"run\") (result i32)\n    i32.const 7\n    call $literal\n    call $use_i32\n    i32.const 0\n    call $forwarded\n    call $use_i32\n    i32.const 0\n    struct.new $box\n    i32.const 9\n    call $use_i32\n    i32.const 0\n    call $suffix\n    call $use_i32\n    i32.const 0\n    global.get $g\n    call $target)\n)\n",
  )
  out.to_string()
}

///|
#skip("manual artifact-scale DAE scheduler fixture; uniform-constant revisits remain covered by bounded tests")
test "dae-optimizing revisits large-module uniform constant actuals" {
  let source = dae_test_large_uniform_const_actual_module()
  let plain = dae_test_run(source, pass_name="dead-argument-elimination")
  let (optimized, trace) = dae_test_run_with_perf_trace(source)
  @debug.assert_eq(dae_test_func_params(plain, 5000).length(), 1)
  assert_true(
    dae_test_func_params(optimized, 5000).length() == 0,
    msg="leaf=\{optimized.pretty_print_defined_func(5000U)} target=\{optimized.pretty_print_defined_func(5001U)} trace=\{trace}",
  )
  @debug.assert_eq(dae_test_func_params(plain, 5001).length(), 2)
  @debug.assert_eq(dae_test_func_params(optimized, 5001).length(), 0)
  @debug.assert_eq(dae_test_func_params(plain, 5002).length(), 1)
  assert_true(
    dae_test_func_params(optimized, 5002).length() == 0,
    msg="literal=\{optimized.pretty_print_defined_func(5002U)} trace=\{trace}",
  )
  @debug.assert_eq(dae_test_func_params(plain, 5003).length(), 1)
  @debug.assert_eq(dae_test_func_params(optimized, 5003).length(), 0)
  @debug.assert_eq(dae_test_func_params(plain, 5004).length(), 1)
  @debug.assert_eq(dae_test_func_params(optimized, 5004).length(), 0)
  @debug.assert_eq(dae_test_func_params(plain, 5005).length(), 2)
  @debug.assert_eq(dae_test_func_params(optimized, 5005).length(), 1)
  let suffix = optimized.pretty_print_defined_func(5005U)
  assert_false(suffix.contains("local.get (Local 1)"), msg=suffix)
  let target = optimized.pretty_print_defined_func(5001U)
  assert_false(target.contains("local.get (Local 1)"), msg=target)
  assert_false(target.contains("struct.get"), msg=target)
  assert_true(target.contains("call (Func 0)"), msg=target)
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[dae-optimizing]:large-uniform-const-revisit primary_def=5001",
      )
    }),
    msg=trace.to_string(),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[dae-optimizing]:large-uniform-const-revisit primary_def=5002",
      )
    }),
    msg=trace.to_string(),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[dae-optimizing]:large-uniform-const-revisit primary_def=5003",
      )
    }),
    msg=trace.to_string(),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[dae-optimizing]:large-uniform-const-revisit primary_def=5004",
      )
    }),
    msg=trace.to_string(),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[dae-optimizing]:large-uniform-const-revisit primary_def=5005",
      )
    }),
    msg=trace.to_string(),
  )
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected large uniform-constant revisit output to validate: \{err}")
  }
}

///|
fn dae_test_broad_exact_param_adjacent_cleanup_module() -> String {
  let root_def = 500
  let pair_first_def = 504
  let total_defs = 513
  let out = StringBuilder::new()
  out.write_string(
    "(module\n  (import \"env\" \"use_i32\" (func $use_i32 (param i32)))\n",
  )
  for candidate_idx = 0; candidate_idx < 8; candidate_idx = candidate_idx + 1 {
    out.write_string(
      "  (func $g\{candidate_idx} (param i32 i32) local.get 0 call $use_i32)\n",
    )
  }
  for dummy_idx = 8; dummy_idx < root_def; dummy_idx = dummy_idx + 1 {
    out.write_string("  (func)\n")
  }
  out.write_string("  (func $root (param i32) local.get 0 call $use_i32)\n")
  for dummy_idx = root_def + 1
      dummy_idx < pair_first_def
      dummy_idx = dummy_idx + 1 {
    out.write_string("  (func)\n")
  }
  for pair_idx = 0; pair_idx < 2; pair_idx = pair_idx + 1 {
    out.write_string("  (func $")
    out.write_string(if pair_idx == 0 { "target" } else { "wrapper" })
    out.write_string(" (param i32) (local")
    for local_idx = 0; local_idx < 128; local_idx = local_idx + 1 {
      out.write_string(" i32")
    }
    out.write_string(")\n")
    for local_idx = 0; local_idx < 16; local_idx = local_idx + 1 {
      out.write_string(
        "    i32.const \{local_idx}\n    local.set \{local_idx + 1}\n    block\n      local.get \{local_idx + 1}\n      drop\n    end\n",
      )
    }
    out.write_string(
      "    i32.const 77\n    local.set 128\n    local.get 0\n    call $use_i32\n    local.get 128\n    call $use_i32\n",
    )
    if pair_idx == 0 {
      out.write_string("    local.get 0\n    call $use_i32)\n")
    } else {
      out.write_string("    local.get 0\n    call $target)\n")
    }
  }
  out.write_string(
    (
      #|  (func (export "run") (param i32)
    ),
  )
  for candidate_idx = 0; candidate_idx < 8; candidate_idx = candidate_idx + 1 {
    out.write_string(
      "    i32.const \{candidate_idx}\n    i32.const 99\n    call $g\{candidate_idx}\n",
    )
  }
  out.write_string(
    (
      #|    i32.const 0
      #|    call $root
      #|    local.get 0
      #|    call $wrapper)
    ),
  )
  for dummy_idx = pair_first_def + 3
      dummy_idx < total_defs
      dummy_idx = dummy_idx + 1 {
    out.write_string("  (func)\n")
  }
  out.write_string(")\n")
  out.to_string()
}

///|
test "dae-optimizing sends a broad exact-param adjacent pair through the shared roster" {
  let source = dae_test_broad_exact_param_adjacent_cleanup_module()
  let plain = dae_test_run(source, pass_name="dead-argument-elimination")
  let (optimized, trace) = dae_test_run_with_perf_trace(source)
  @debug.assert_eq(dae_test_func_params(plain, 500).length(), 0)
  @debug.assert_eq(dae_test_func_params(optimized, 500).length(), 0)
  for def_idx in [504, 505] {
    let @lib.Func(plain_locals, _) = dae_test_defined_func(plain, def_idx)
    let @lib.Func(optimized_locals, _) = dae_test_defined_func(
      optimized, def_idx,
    )
    @debug.assert_eq(plain_locals.length(), 128)
    @debug.assert_eq(optimized_locals.length(), 0)
    let plain_func = plain.pretty_print_defined_func(
      def_idx.reinterpret_as_uint(),
    )
    let optimized_func = optimized.pretty_print_defined_func(
      def_idx.reinterpret_as_uint(),
    )
    assert_true(plain_func.contains("local.set"), msg=plain_func)
    assert_false(optimized_func.contains("local.set"), msg=optimized_func)
    assert_true(optimized_func.contains("I32(77)"), msg=optimized_func)
  }
  assert_true(
    trace.contains(
      "pass[dae-optimizing]:broad-exact-param-adjacent-candidates roots=1 pairs=1",
    ),
    msg=trace.to_string(),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[dae-optimizing]:broad-exact-param-adjacent root_def=500 defs=[504, 505] payoff=142",
      )
    }),
    msg=trace.to_string(),
  )
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected broad adjacent cleanup output to validate: \{err}")
  }
}

///|
fn dae_test_broad_dropped_result_payoff_chain_module() -> String {
  let out = StringBuilder::new()
  out.write_string(
    "(module\n  (import \"env\" \"use_i32\" (func $use_i32 (param i32)))\n",
  )
  out.write_string("  (func $target (result i32)\n")
  out.write_string("    (local")
  for local_idx = 0; local_idx < 128; local_idx = local_idx + 1 {
    out.write_string(" i32")
  }
  out.write_string(")\n")
  for local_id = 0; local_id < 32; local_id = local_id + 1 {
    out.write_string("    i32.const ")
    out.write_string(local_id.to_string())
    out.write_string("\n    local.set ")
    out.write_string(local_id.to_string())
    out.write_string("\n    block\n      local.get ")
    out.write_string(local_id.to_string())
    out.write_string("\n      drop\n    end\n")
  }
  out.write_string(
    "    i32.const 77\n    local.set 127\n    local.get 127\n    call $use_i32\n    local.get 31)\n",
  )
  out.write_string("  (func $wrapper (result i32) call $target)\n")
  out.write_string("  (func (export \"run\") call $wrapper drop)\n")
  for dummy_idx = 3; dummy_idx < 513; dummy_idx = dummy_idx + 1 {
    out.write_string("  (func)\n")
  }
  out.write_string(")\n")
  out.to_string()
}

///|
test "dae-optimizing shared nested roster converges payoff cleanup independent of module size" {
  let source = dae_test_broad_dropped_result_payoff_chain_module()
  let plain = dae_test_run(source, pass_name="dead-argument-elimination")
  let (optimized, trace) = dae_test_run_with_perf_trace(source)
  @debug.assert_eq(dae_test_func_results(optimized, 0).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 0)
  let @lib.Func(plain_locals, _) = dae_test_defined_func(plain, 0)
  let @lib.Func(optimized_locals, _) = dae_test_defined_func(optimized, 0)
  @debug.assert_eq(plain_locals.length(), 128)
  @debug.assert_eq(optimized_locals.length(), 0)
  let target = optimized.pretty_print_defined_func(0U)
  assert_true(target.contains("I32(77)"), msg=target)
  assert_true(target.contains("call (Func 0)"), msg=target)
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[dae-optimizing]:nested-pass name=precompute-propagate",
      )
    }),
    msg=trace.to_string(),
  )
  let mut nested_cleanup_count = 0
  for line in trace {
    if line.contains("pass[dae-optimizing]:nested-cleanup touched=") {
      nested_cleanup_count = nested_cleanup_count + 1
    }
  }
  @debug.assert_eq(nested_cleanup_count, 1)
}

///|
fn dae_test_append_broad_dropped_result_payoff_target(
  out : StringBuilder,
  name : String,
  copy_count : Int,
) -> Unit {
  out.write_string("  (func $")
  out.write_string(name)
  out.write_string(" (result i32)\n")
  out.write_string("    (local")
  for local_idx = 0; local_idx < 128; local_idx = local_idx + 1 {
    out.write_string(" i32")
  }
  out.write_string(")\n")
  for local_id = 0; local_id < copy_count; local_id = local_id + 1 {
    out.write_string("    i32.const ")
    out.write_string(local_id.to_string())
    out.write_string("\n    local.set ")
    out.write_string(local_id.to_string())
    out.write_string("\n    block\n      local.get ")
    out.write_string(local_id.to_string())
    out.write_string("\n      drop\n    end\n")
  }
  out.write_string("    local.get ")
  out.write_string((copy_count - 1).to_string())
  out.write_string(")\n")
}

///|
fn dae_test_broad_forwarded_dropped_result_chain_module() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func $leaf (result i32) i32.const 7)\n")
  out.write_string("  (func $forward (result i32) call $leaf return)\n")
  out.write_string("  (func (export \"run\") call $forward drop)\n")
  for dummy_idx = 3; dummy_idx < 1024; dummy_idx = dummy_idx + 1 {
    out.write_string("  (func)\n")
  }
  out.write_string(")\n")
  out.to_string()
}

///|
#skip("manual synthetic DAE module-size threshold; forwarded dropped-result behavior remains covered")
test "dae-optimizing removes results forwarded only into dropped results" {
  let optimized = dae_test_run(
    dae_test_broad_forwarded_dropped_result_chain_module(),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 1).length(), 0)
}

///|
fn dae_test_broad_block_dropped_result_chain_module() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func $leaf (result i32) i32.const 7)\n")
  out.write_string(
    "  (func (export \"run\") (block (result i32) call $leaf) drop)\n",
  )
  for dummy_idx = 2; dummy_idx < 1024; dummy_idx = dummy_idx + 1 {
    out.write_string("  (func)\n")
  }
  out.write_string(")\n")
  out.to_string()
}

///|
#skip("manual synthetic DAE module-size threshold; dropped-block result behavior remains covered")
test "dae-optimizing removes results produced only for dropped blocks" {
  let optimized = dae_test_run(
    dae_test_broad_block_dropped_result_chain_module(),
  )
  @debug.assert_eq(dae_test_func_results(optimized, 0).length(), 0)
}

///|
fn dae_test_broad_dropped_result_payoff_coalesce_module() -> String {
  let out = StringBuilder::new()
  out.write_string(
    "(module\n  (import \"env\" \"source_i64\" (func $source_i64 (result i64)))\n  (import \"env\" \"source_i32\" (func $source_i32 (result i32)))\n  (import \"env\" \"touch\" (func $touch))\n  (import \"env\" \"sink_i64\" (func $sink_i64 (param i64)))\n  (import \"env\" \"sink_i32\" (func $sink_i32 (param i32)))\n",
  )
  out.write_string("  (func $target (result i32)\n    (local")
  for local_idx = 0; local_idx < 129; local_idx = local_idx + 1 {
    ignore(local_idx)
    out.write_string(" i64")
  }
  for local_idx = 129; local_idx < 162; local_idx = local_idx + 1 {
    ignore(local_idx)
    out.write_string(" i32")
  }
  out.write_string(")\n")
  for local_id = 129; local_id < 161; local_id = local_id + 1 {
    out.write_string("    i32.const ")
    out.write_string(local_id.to_string())
    out.write_string("\n    local.set ")
    out.write_string(local_id.to_string())
    out.write_string("\n    block\n      local.get ")
    out.write_string(local_id.to_string())
    out.write_string("\n      drop\n    end\n")
  }
  for local_id = 0; local_id < 129; local_id = local_id + 1 {
    out.write_string("    call $source_i64\n    local.set ")
    out.write_string(local_id.to_string())
    out.write_string("\n")
  }
  out.write_string("    call $source_i32\n    local.set 161\n    call $touch\n")
  for local_id = 0; local_id < 129; local_id = local_id + 1 {
    out.write_string("    local.get ")
    out.write_string(local_id.to_string())
    out.write_string("\n    call $sink_i64\n")
  }
  out.write_string(
    "    local.get 161\n    call $sink_i32\n    local.get 161\n    call $sink_i32\n    local.get 161\n    call $sink_i32\n    i32.const 2\n    i32.const 48\n    call $slice\n    local.get 161)\n",
  )
  out.write_string(
    "  (func $slice (param i32 i32)\n    local.get 0\n    call $sink_i32\n    local.get 1\n    call $sink_i32)\n",
  )
  out.write_string("  (func $wrapper (result i32) call $target)\n")
  out.write_string("  (func (export \"run\") call $wrapper drop)\n")
  for dummy_idx = 4; dummy_idx < 8193; dummy_idx = dummy_idx + 1 {
    out.write_string("  (func)\n")
  }
  out.write_string(")\n")
  out.to_string()
}

///|
#skip("manual artifact-scale DAE cleanup benchmark; coalescing and reorder behavior have bounded tests")
test "dae-optimizing coalesces and late-reorders selected payoff locals after result removal" {
  let source = dae_test_broad_dropped_result_payoff_coalesce_module()
  let plain = dae_test_run(source, pass_name="dead-argument-elimination")
  let (optimized, trace) = dae_test_run_with_perf_trace(source)
  @debug.assert_eq(dae_test_func_results(optimized, 0).length(), 0)
  @debug.assert_eq(dae_test_func_params(plain, 1).length(), 2)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 0)
  let @lib.Func(plain_locals, _) = dae_test_defined_func(plain, 0)
  let @lib.Func(optimized_locals, _) = dae_test_defined_func(optimized, 0)
  @debug.assert_eq(plain_locals.length(), 162)
  let expected_types : Array[@lib.ValType] = [@lib.ValType::i32()]
  for local_idx = 0; local_idx < 129; local_idx = local_idx + 1 {
    ignore(local_idx)
    expected_types.push(@lib.ValType::i64())
  }
  @debug.assert_eq(optimized_locals, @lib.Locals::from_types(expected_types))
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[dae-optimizing]:payoff-final-reorder defs=[0] accepted_defs=1",
      )
    }),
    msg=trace.to_string(),
  )
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected late payoff reorder output to validate: \{err}")
  }
}

///|
fn dae_test_broad_high_normalized_literal_chain_module() -> String {
  let out = StringBuilder::new()
  out.write_string(
    "(module\n  (type $box (struct (field i64)))\n  (import \"env\" \"log\" (func $log))\n  (import \"env\" \"touch\" (func $touch (param i32) (result i32)))\n  (import \"env\" \"sink\" (func $sink (param i32)))\n  (import \"env\" \"touch_ref\" (func $touch_ref (param i32 (ref $box))))\n  (global $maybe (ref null $box) (struct.new_default $box))\n",
  )
  for dummy_idx = 0; dummy_idx < 8192; dummy_idx = dummy_idx + 1 {
    ignore(dummy_idx)
    out.write_string("  (func)\n")
  }
  out.write_string(
    "  (func $leaf (param (ref $box) i32) (result i32) (local i64)\n    local.get 0\n    struct.get $box 0\n    local.set 2\n    call $log\n    local.get 2\n    i32.wrap_i64\n    call $sink\n    call $log\n    local.get 2\n    i32.wrap_i64\n    call $sink\n    call $log\n    local.get 2\n    i32.wrap_i64\n    call $sink\n    call $log\n    local.get 2\n    i32.wrap_i64\n    call $sink\n",
  )
  for guarded_call = 0; guarded_call < 768; guarded_call = guarded_call + 1 {
    ignore(guarded_call)
    out.write_string("    local.get 1\n    if call $log end\n")
  }
  out.write_string(
    (
      #|    i32.const 7)
      #|  (func $carrier (param i32 i64 i32 i64 i32 i32) (result i32)
      #|    (local (ref $box))
      #|    global.get $maybe
      #|    ref.as_non_null
      #|    local.set 6
      #|    local.get 0
      #|    local.get 6
      #|    call $touch_ref
      #|    local.get 5
      #|    if (result i32)
      #|      local.get 0
      #|      call $touch
      #|      drop
      #|      local.get 1
      #|      drop
      #|      local.get 2
      #|      call $touch
      #|      drop
      #|      local.get 3
      #|      drop
      #|      local.get 4
      #|      call $touch
      #|    else
      #|      local.get 0
      #|    end)
      #|  (func $mid (param (ref $box) i32) (result i32)
      #|    (local
    ),
  )
  for local_idx = 0; local_idx < 65; local_idx = local_idx + 1 {
    ignore(local_idx)
    out.write_string(" i32")
  }
  out.write_string(
    (
      #|)
      #|    block (result i32)
      #|      block (result i32)
      #|        i32.const 99
      #|        call $touch
      #|        if
      #|          i32.const 71
      #|          br 1
      #|        else
      #|          i32.const 72
      #|          br 2
      #|        end
      #|        unreachable
      #|      end
      #|      local.set 65
      #|      call $log
      #|      local.get 65
      #|    end
      #|    drop
      #|    i32.const 81
      #|    local.set 3
      #|    i32.const 82
      #|    local.set 4
      #|    i32.const 83
      #|    local.set 5
      #|    local.get 3
      #|    local.set 8
      #|    local.get 4
      #|    local.set 7
      #|    local.get 5
      #|    local.set 6
      #|    local.get 8
      #|    local.set 9
      #|    local.get 7
      #|    local.set 10
      #|    local.get 6
      #|    local.set 11
      #|    local.get 9
      #|    call $sink
      #|    local.get 10
      #|    call $sink
      #|    local.get 11
      #|    call $sink
      #|    i32.const 84
      #|    call $touch
      #|    local.set 12
      #|    i32.const 85
      #|    call $touch
      #|    local.set 12
      #|    local.get 1
      #|    local.set 2
      #|    i32.const 41
      #|    drop
      #|    i32.const 42
      #|    drop
      #|    i32.const 43
      #|    drop
      #|    i32.const 44
      #|    drop
      #|    i32.const 45
      #|    drop
      #|    i32.const 46
      #|    drop
      #|    i32.const 47
      #|    drop
      #|    local.get 2
      #|    local.set 3
      #|    local.get 0
      #|    local.get 3
      #|    call $leaf
      #|    drop
      #|    local.get 2
      #|    i64.const 9
      #|    local.get 2
      #|    call $touch
      #|    i64.const 10
      #|    local.get 2
      #|    call $sink
      #|    local.get 2
      #|    call $touch
      #|    i32.const 0
      #|    call $carrier
      #|    drop
      #|    i32.const 1
      #|    i64.const 11
      #|    local.get 2
      #|    call $touch
      #|    i64.const 12
      #|    local.get 2
      #|    call $sink
      #|    local.get 2
      #|    call $touch
      #|    i32.const 0
      #|    call $carrier)
      #|  (func $normalize (param i32) (result i32)
      #|    struct.new_default $box
      #|    local.get 0
      #|    i32.const -1
      #|    i32.eq
      #|    if (result i32)
      #|      i32.const 0
      #|    else
      #|      local.get 0
      #|    end
      #|    call $mid)
      #|  (func (export "run") (result i32)
      #|    i32.const -1
      #|    call $normalize)
      #|)
    ),
  )
  out.to_string()
}

///|
#skip("manual artifact-scale DAE convergence benchmark; direct-callee convergence remains covered")
test "dae-optimizing converges a high normalized literal through direct callees" {
  let source = dae_test_broad_high_normalized_literal_chain_module()
  let plain = dae_test_run(source, pass_name="dead-argument-elimination")
  let (optimized, trace) = dae_test_run_with_perf_trace(source)
  @debug.assert_eq(dae_test_func_params(plain, 8192).length(), 2)
  assert_true(
    dae_test_func_params(optimized, 8192).length() == 1,
    msg="def=8192 trace=\{trace}",
  )
  @debug.assert_eq(dae_test_func_params(plain, 8195).length(), 1)
  assert_true(
    dae_test_func_params(optimized, 8195).length() == 0,
    msg="def=8195 trace=\{trace}",
  )
  @debug.assert_eq(dae_test_func_params(plain, 8194).length(), 2)
  assert_true(
    dae_test_func_params(optimized, 8194).length() == 1,
    msg="def=8194 trace=\{trace}",
  )
  @debug.assert_eq(dae_test_func_params(plain, 8193).length(), 6)
  assert_true(
    dae_test_func_params(optimized, 8193).length() == 1,
    msg="carrier=\{optimized.pretty_print_defined_func(8193U)} trace=\{trace}",
  )
  let leaf = optimized.pretty_print_defined_func(8192U)
  assert_true(dae_test_count_substring(leaf, "call (Func 0)") == 4, msg=leaf)
  assert_true(dae_test_count_substring(leaf, "call (Func 2)") == 4, msg=leaf)
  let @lib.Func(leaf_locals, @lib.Expr(leaf_body)) = dae_test_defined_func(
    optimized, 8192,
  )
  @debug.assert_eq(leaf_locals.length(), 1, msg=leaf)
  match leaf_body {
    [
      @lib.Call(@lib.FuncIdx(0U)),
      @lib.LocalGet(@lib.LocalIdx(0U)),
      @lib.StructGet(_, @lib.U32(0U)),
      @lib.LocalTee(_),
      @lib.I32WrapI64,
      @lib.Call(@lib.FuncIdx(2U)),
      ..,
    ] => ()
    _ =>
      fail(
        "expected immutable field read after side call: \{leaf_body} trace=\{trace}",
      )
  }
  let carrier = optimized.pretty_print_defined_func(8193U)
  assert_false(carrier.contains("If"), msg=carrier)
  assert_false(carrier.contains("Return"), msg=carrier)
  let @lib.Func(carrier_locals, _) = dae_test_defined_func(optimized, 8193)
  @debug.assert_eq(carrier_locals.length(), 0, msg=carrier)
  assert_false(carrier.contains("call (Func 1)"), msg=carrier)
  assert_true(carrier.contains("call (Func 3)"), msg=carrier)
  let @lib.Func(plain_mid_locals, _) = dae_test_defined_func(plain, 8194)
  @debug.assert_eq(plain_mid_locals.length(), 65)
  let plain_mid = plain.pretty_print_defined_func(8194U)
  assert_true(plain_mid.contains("unreachable"), msg=plain_mid)
  let mid = optimized.pretty_print_defined_func(8194U)
  let @lib.Func(mid_locals, _) = dae_test_defined_func(optimized, 8194)
  @debug.assert_eq(mid_locals.length(), 1, msg=mid)
  assert_false(mid.contains("unreachable"), msg=mid)
  assert_false(mid.contains("nop"), msg=mid)
  assert_true(dae_test_count_substring(mid, "call (Func 1)") == 7, msg=mid)
  assert_true(dae_test_count_substring(mid, "call (Func 2)") == 5, msg=mid)
  assert_true(mid.contains("I32(81)"), msg=mid)
  assert_true(mid.contains("I32(82)"), msg=mid)
  assert_true(mid.contains("I32(83)"), msg=mid)
  assert_true(mid.contains("I32(84)"), msg=mid)
  assert_true(mid.contains("I32(85)"), msg=mid)
  let normalize = optimized.pretty_print_defined_func(8195U)
  assert_false(normalize.contains("(local"), msg=normalize)
  assert_true(
    trace.any(fn(line) {
      line.contains("productive_defs=[8195, 8194, 8192, 8193]")
    }),
    msg=trace.to_string(),
  )
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected high normalized-literal chain output to validate: \{err}")
  }
}

///|
fn dae_test_two_broad_dropped_result_payoff_chains_module() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  dae_test_append_broad_dropped_result_payoff_target(out, "target0", 40)
  out.write_string("  (func $wrapper0 (result i32) call $target0)\n")
  dae_test_append_broad_dropped_result_payoff_target(out, "target1", 32)
  out.write_string("  (func $wrapper1 (result i32) call $target1)\n")
  out.write_string(
    "  (func (export \"run\") call $wrapper0 drop call $wrapper1 drop)\n",
  )
  for dummy_idx = 5; dummy_idx < 8193; dummy_idx = dummy_idx + 1 {
    out.write_string("  (func)\n")
  }
  out.write_string(")\n")
  out.to_string()
}

///|
#skip("manual artifact-scale DAE scheduler benchmark; ranked transaction behavior has bounded coverage")
test "dae-optimizing closes two ranked broad dropped-result chains in one bounded transaction" {
  let (optimized, trace) = dae_test_run_with_perf_trace(
    dae_test_two_broad_dropped_result_payoff_chains_module(),
  )
  for def_idx in [0, 1, 2, 3] {
    @debug.assert_eq(dae_test_func_results(optimized, def_idx).length(), 0)
  }
  for def_idx in [0U, 2U] {
    let target = optimized.pretty_print_defined_func(def_idx)
    assert_false(target.contains("local.set"), msg=target)
  }
  let payoff_traces = trace.filter(fn(line) {
    line.contains("pass[dae-optimizing]:payoff-dropped-result-chain")
  })
  @debug.assert_eq(payoff_traces.length(), 2)
  assert_true(
    payoff_traces[0].contains("wrapper_def=1 callee_def=0"),
    msg=payoff_traces.to_string(),
  )
  assert_true(
    payoff_traces[1].contains("wrapper_def=3 callee_def=2"),
    msg=payoff_traces.to_string(),
  )
}

///|
fn dae_test_broad_computed_carrier_cycle_module() -> String {
  let root_def = 7000
  let pair_first_def = 7004
  let total_defs = 8193
  let out = StringBuilder::new()
  out.write_string(
    "(module\n  (import \"env\" \"use_i32\" (func $use_i32 (param i32)))\n",
  )
  for candidate_idx = 0; candidate_idx < 8; candidate_idx = candidate_idx + 1 {
    out.write_string(
      "  (func $g\{candidate_idx} (param i32 i32) local.get 0 call $use_i32)\n",
    )
  }
  for dummy_idx = 8; dummy_idx < root_def; dummy_idx = dummy_idx + 1 {
    out.write_string("  (func)\n")
  }
  out.write_string("  (func $root (param i32) local.get 0 call $use_i32)\n")
  for dummy_idx = root_def + 1
      dummy_idx < pair_first_def
      dummy_idx = dummy_idx + 1 {
    out.write_string("  (func)\n")
  }
  out.write_string("  (func $a (param i32 i32) (local")
  for local_idx = 0; local_idx < 128; local_idx = local_idx + 1 {
    ignore(local_idx)
    out.write_string(" i32")
  }
  out.write_string(
    ")\n    local.get 1\n    local.get 0\n    call $helper\n    local.set 2\n    local.get 0\n    local.get 2\n    call $c)\n",
  )
  out.write_string("  (func $b (param i32 i32) (local")
  for local_idx = 0; local_idx < 128; local_idx = local_idx + 1 {
    ignore(local_idx)
    out.write_string(" i32")
  }
  out.write_string(")\n    local.get 0\n    local.get 1\n    call $a)\n")
  out.write_string(
    (
      #|  (func $c (param i32 i32)
      #|    local.get 0
      #|    local.get 1
      #|    call $b)
      #|  (func $helper (param i32 i32) (result i32)
      #|    local.get 1)
      #|  (func (export "run")
    ),
  )
  for candidate_idx = 0; candidate_idx < 8; candidate_idx = candidate_idx + 1 {
    out.write_string(
      "    i32.const \{candidate_idx}\n    i32.const 99\n    call $g\{candidate_idx}\n",
    )
  }
  out.write_string(
    (
      #|    i32.const 0
      #|    call $root
      #|    i32.const 7
      #|    i32.const 0
      #|    call $a
      #|    i32.const 7
      #|    i32.const 0
      #|    call $c)
    ),
  )
  for dummy_idx = pair_first_def + 5
      dummy_idx < total_defs
      dummy_idx = dummy_idx + 1 {
    ignore(dummy_idx)
    out.write_string("  (func)\n")
  }
  out.write_string(")\n")
  out.to_string()
}

///|
#skip("manual artifact-scale DAE cycle benchmark; unread-callee and cycle behavior remain in bounded tests")
test "dae-optimizing converges through an unread callee before a computed cycle carrier" {
  let (optimized, trace) = dae_test_run_with_perf_trace(
    dae_test_broad_computed_carrier_cycle_module(),
  )
  // The first wave removes the forwarding component; the bounded final wave
  // then proves the helper result and its last argument dead. This eliminates
  // the remaining helper boundary stack traffic without increasing module
  // size, rather than retaining Binaryen's still-live i32 -> i32 shell.
  @debug.assert_eq(dae_test_func_params(optimized, 7007).length(), 0)
  @debug.assert_eq(dae_test_func_results(optimized, 7007).length(), 0)
  for def_idx in [7004, 7005, 7006] {
    assert_true(
      dae_test_func_params(optimized, def_idx).length() == 1,
      msg=trace.to_string(),
    )
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[dae-optimizing]:forwarded-param-component-transaction defs=[7005, 7004, 7006] params=3",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "dae-optimizing removes a forwarding-only parameter component and preserves an effectful incoming producer" {
  let source =
    #|(module
    #|  (import "env" "effect" (func $effect (result i32)))
    #|  (func $a (param i32 i32)
    #|    local.get 0
    #|    call $b)
    #|  (func $b (param i32)
    #|    local.get 0
    #|    i32.const 9
    #|    call $a)
    #|  (func $bridge (param i32)
    #|    local.get 0
    #|    i32.const 9
    #|    call $a)
    #|  (func (export "run")
    #|    call $effect
    #|    call $bridge))
  let plain = dae_test_run(source, pass_name="dead-argument-elimination")
  let (optimized, trace) = dae_test_run_with_perf_trace(source)
  @debug.assert_eq(dae_test_func_params(plain, 0).length(), 1)
  @debug.assert_eq(dae_test_func_params(plain, 1).length(), 1)
  @debug.assert_eq(dae_test_func_params(plain, 2).length(), 1)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 0)
  @debug.assert_eq(dae_test_func_params(optimized, 2).length(), 0)
  let run = optimized.pretty_print_defined_func(3U)
  assert_true(run.contains("call (Func 0)"), msg=run)
  assert_true(run.contains("drop"), msg="\{run}\ntrace=\{trace}")
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[dae-optimizing]:forwarded-param-component-transaction defs=[0, 1, 2] params=3",
      )
    }),
    msg=trace.to_string(),
  )
  assert_false(
    trace.any(fn(line) {
      line.contains("pass[dae-optimizing]:post-component-cleanup")
    }),
    msg=trace.to_string(),
  )
  assert_true(
    trace.contains("pass[dae-optimizing]:nested-pass name=precompute-propagate"),
    msg=trace.to_string(),
  )
}

///|
#skip("manual aggregate cleanup replay; forwarding commits and nested cleanup are covered separately")
test "dae-optimizing replays coalesce and vacuum on changed forwarding-component functions after a large touched-set skip" {
  let source =
    #|(module
    #|  (import "env" "effect" (func $effect (result i32)))
    #|  (import "env" "use_i32" (func $use_i32 (param i32)))
    #|  (func $a (param i32 i32 i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
    #|    local.get 2
    #|    local.set 3
    #|    local.get 3
    #|    local.set 4
    #|    local.get 4
    #|    local.set 5
    #|    local.get 5
    #|    call $use_i32
    #|    local.get 0
    #|    local.get 2
    #|    call $b)
    #|  (func $b (param i32 i32)
    #|    local.get 0
    #|    i32.const 9
    #|    local.get 1
    #|    call $a)
    #|  (func $bridge (param i32 i32)
    #|    local.get 0
    #|    i32.const 9
    #|    local.get 1
    #|    call $a)
    #|  (func $d0 (param i32))
    #|  (func $d1 (param i32))
    #|  (func $d2 (param i32))
    #|  (func $d3 (param i32))
    #|  (func $d4 (param i32))
    #|  (func $d5 (param i32))
    #|  (func $d6 (param i32))
    #|  (func $d7 (param i32))
    #|  (func $d8 (param i32))
    #|  (func (export "run")
    #|    call $effect
    #|    call $effect
    #|    call $bridge
    #|    i32.const 0
    #|    call $d0
    #|    i32.const 1
    #|    call $d1
    #|    i32.const 2
    #|    call $d2
    #|    i32.const 3
    #|    call $d3
    #|    i32.const 4
    #|    call $d4
    #|    i32.const 5
    #|    call $d5
    #|    i32.const 6
    #|    call $d6
    #|    i32.const 7
    #|    call $d7
    #|    i32.const 8
    #|    call $d8))
  let plain = dae_test_run(source, pass_name="dead-argument-elimination")
  let (optimized, trace) = dae_test_run_with_perf_trace(source)
  @debug.assert_eq(dae_test_func_params(plain, 0).length(), 2)
  let @lib.Func(plain_a_locals, _) = dae_test_defined_func(plain, 0)
  assert_true(
    plain_a_locals.length() >= 16,
    msg=plain.pretty_print_defined_func(0U),
  )
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 1)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 1)
  @debug.assert_eq(dae_test_func_params(optimized, 2).length(), 1)
  let @lib.Func(a_locals, _) = dae_test_defined_func(optimized, 0)
  let optimized_a = optimized.pretty_print_defined_func(0U)
  assert_true(a_locals.length() < 16, msg=optimized_a)
  assert_false(optimized_a.contains("nop"), msg=optimized_a)
  assert_false(
    trace.any(fn(line) {
      line.contains("pass[dae-optimizing]:post-component-cleanup")
    }),
    msg=trace.to_string(),
  )
  assert_true(
    trace.contains("pass[dae-optimizing]:nested-pass name=precompute-propagate"),
    msg=trace.to_string(),
  )
}

///|
test "dae-optimizing keeps a forwarding-component parameter with one semantic use" {
  let source =
    #|(module
    #|  (import "env" "effect" (func $effect (result i32)))
    #|  (import "env" "use_i32" (func $use_i32 (param i32)))
    #|  (func $a (param i32 i32)
    #|    local.get 0
    #|    call $b)
    #|  (func $b (param i32)
    #|    local.get 0
    #|    i32.const 9
    #|    call $a)
    #|  (func $bridge (param i32)
    #|    local.get 0
    #|    call $use_i32
    #|    local.get 0
    #|    i32.const 9
    #|    call $a)
    #|  (func (export "run")
    #|    call $effect
    #|    call $bridge))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 0)
  @debug.assert_eq(dae_test_func_params(optimized, 2).length(), 1)
}

///|
test "dae-optimizing rejects a written forwarding-only parameter component" {
  let source =
    #|(module
    #|  (func $a (param i32 i32)
    #|    local.get 0
    #|    call $b
    #|    i32.const 4
    #|    local.set 0)
    #|  (func $b (param i32)
    #|    local.get 0
    #|    i32.const 9
    #|    call $a)
    #|  (func (export "run")
    #|    i32.const 7
    #|    i32.const 9
    #|    call $a))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 1)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 1)
}

///|
test "dae-optimizing rejects an exported forwarding-only parameter component" {
  let source =
    #|(module
    #|  (func $a (export "escaped") (param i32 i32)
    #|    local.get 0
    #|    call $b)
    #|  (func $b (param i32)
    #|    local.get 0
    #|    i32.const 9
    #|    call $a)
    #|  (func (export "run")))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 2)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 1)
}

///|
test "dae-optimizing rejects a ref-func-escaped forwarding-only parameter component" {
  let source =
    #|(module
    #|  (elem declare func $a)
    #|  (func $a (param i32 i32)
    #|    local.get 0
    #|    call $b)
    #|  (func $b (param i32)
    #|    local.get 0
    #|    i32.const 9
    #|    call $a)
    #|  (func (export "run")))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 2)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 1)
}

///|
test "dae-optimizing rejects a tail-call forwarding-only parameter boundary" {
  let source =
    #|(module
    #|  (func $a (param i32 i32)
    #|    local.get 0
    #|    return_call $b)
    #|  (func $b (param i32)
    #|    local.get 0
    #|    i32.const 9
    #|    call $a)
    #|  (func (export "run")
    #|    i32.const 7
    #|    i32.const 9
    #|    call $a))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 1)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 1)
}

///|
test "dae-optimizing rejects a non-exact forwarding-only operand slice" {
  let source =
    #|(module
    #|  (func $a (param i32 i32)
    #|    block (result i32)
    #|      local.get 0
    #|    end
    #|    call $b)
    #|  (func $b (param i32)
    #|    local.get 0
    #|    i32.const 9
    #|    call $a)
    #|  (func (export "run")
    #|    i32.const 7
    #|    i32.const 9
    #|    call $a))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 1)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 1)
}

///|
test "dae-optimizing removes a constant-anchored forwarded-parameter cycle transactionally" {
  let source =
    #|(module
    #|  (import "env" "use_i32" (func $use_i32 (param i32)))
    #|  (func $entry (export "run") (result i32)
    #|    i32.const 7
    #|    call $a)
    #|  (func $a (param i32) (result i32)
    #|    local.get 0
    #|    call $use_i32
    #|    local.get 0
    #|    i32.const 9
    #|    call $b)
    #|  (func $b (param i32 i32) (result i32)
    #|    local.get 0
    #|    drop
    #|    local.get 0
    #|    call $a))
  let (optimized, trace) = dae_test_run_with_perf_trace(source)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 0)
  @debug.assert_eq(dae_test_func_params(optimized, 2).length(), 0)
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[dae-optimizing]:forwarded-param-scc-transaction defs=[1, 2] params=2",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "dae-optimizing rejects a conflicting forwarded-parameter cycle transaction" {
  let source =
    #|(module
    #|  (func (export "run7") (result i32)
    #|    i32.const 7
    #|    call $a)
    #|  (func (export "run8") (result i32)
    #|    i32.const 8
    #|    i32.const 9
    #|    call $b)
    #|  (func $a (param i32) (result i32)
    #|    local.get 0
    #|    i32.const 9
    #|    call $b)
    #|  (func $b (param i32 i32) (result i32)
    #|    local.get 0
    #|    drop
    #|    local.get 0
    #|    call $a))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 2).length(), 1)
  @debug.assert_eq(dae_test_func_params(optimized, 3).length(), 1)
}

///|
test "dae-optimizing worklist preserves Binaryen's one-wave written forwarding stop" {
  let source =
    #|(module
    #|  (func (export "run") (result i32)
    #|    i32.const 7
    #|    call $a)
    #|  (func $a (param i32) (result i32)
    #|    local.get 0
    #|    i32.const 9
    #|    call $b)
    #|  (func $b (param i32 i32) (result i32)
    #|    i32.const 4
    #|    local.set 0
    #|    local.get 0
    #|    call $a))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 1)
  @debug.assert_eq(dae_test_func_params(optimized, 2).length(), 0)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected one-wave written-forwarding output, got \{err}")
  }
}

///|
test "dae-optimizing removes an exact unanchored forwarding-only cycle" {
  let source =
    #|(module
    #|  (func $a (param i32) (result i32)
    #|    local.get 0
    #|    i32.const 9
    #|    call $b)
    #|  (func $b (param i32 i32) (result i32)
    #|    local.get 0
    #|    call $a)
    #|  (func (export "run") (result i32)
    #|    i32.const 3))
  let (optimized, trace) = dae_test_run_with_perf_trace(source)
  @debug.assert_eq(dae_test_func_params(optimized, 0).length(), 0)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 0)
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[dae-optimizing]:forwarded-param-cycle-precompute defs=[0, 1]",
      )
    }),
    msg=trace.to_string(),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[dae-optimizing]:forwarded-param-component-transaction defs=[0, 1] params=2",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "dae-optimizing converges all touched forwarding-only cycles" {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for cycle_idx = 0; cycle_idx < 9; cycle_idx = cycle_idx + 1 {
    out.write_string(
      "  (func $a\{cycle_idx} (param i32 i32) local.get 0 call $b\{cycle_idx})\n",
    )
    out.write_string(
      "  (func $b\{cycle_idx} (param i32) local.get 0 i32.const 9 call $a\{cycle_idx})\n",
    )
  }
  out.write_string(")\n")
  let (optimized, trace) = dae_test_run_with_perf_trace(out.to_string())
  for def_idx = 0; def_idx < 18; def_idx = def_idx + 1 {
    @debug.assert_eq(
      dae_test_func_params(optimized, def_idx).length(),
      0,
      msg=trace.to_string(),
    )
  }
}

///|
test "dae-optimizing rejects an escaped forwarded-parameter cycle transaction" {
  let source =
    #|(module
    #|  (func $entry (export "run") (result i32)
    #|    i32.const 7
    #|    call $a)
    #|  (func $a (export "escaped") (param i32) (result i32)
    #|    local.get 0
    #|    i32.const 9
    #|    call $b)
    #|  (func $b (param i32 i32) (result i32)
    #|    local.get 0
    #|    drop
    #|    local.get 0
    #|    call $a))
  let optimized = dae_test_run(source)
  @debug.assert_eq(dae_test_func_params(optimized, 1).length(), 1)
  @debug.assert_eq(dae_test_func_params(optimized, 2).length(), 1)
}
