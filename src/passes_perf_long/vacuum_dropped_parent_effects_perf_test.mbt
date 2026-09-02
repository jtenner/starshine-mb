///|
fn vacuum_dropped_parent_effects_perf_module(repetitions : Int) -> @lib.Module {
  let i32_func_type = @lib.TypeIdx::new(0U)
  let void_func_type = @lib.TypeIdx::new(1U)
  let body : Array[@lib.Instruction] = []
  for repetition = 0; repetition < repetitions; repetition = repetition + 1 {
    body.push(@lib.Instruction::call(@lib.FuncIdx::new(0U)))
    body.push(@lib.Instruction::call(@lib.FuncIdx::new(1U)))
    body.push(@lib.Instruction::i32_add())
    body.push(@lib.Instruction::drop())
  }
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
      ),
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_func_sec(
    @lib.FuncSec::new([i32_func_type, i32_func_type, void_func_type]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(41))]),
      ),
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(42))]),
      ),
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
    ]),
  )
}

///|
fn vacuum_candidate_free_calls_perf_module(repetitions : Int) -> @lib.Module {
  let void_func_type = @lib.TypeIdx::new(0U)
  let body : Array[@lib.Instruction] = []
  for repetition = 0; repetition < repetitions; repetition = repetition + 1 {
    body.push(@lib.Instruction::call(@lib.FuncIdx::new(0U)))
  }
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_import_sec(
    @lib.ImportSec::new([
      @lib.Import::new(
        @lib.Name::new("env"),
        @lib.Name::new("effect"),
        @lib.func_extern_type(void_func_type),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([void_func_type]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
    ]),
  )
}

///|
fn vacuum_dropped_parent_effects_perf_counts(
  instrs : Array[@lib.Instruction],
) -> (Int, Int, Int) {
  let mut calls = 0
  let mut drops = 0
  let mut adds = 0
  for instr in instrs {
    match instr {
      @lib.Call(_) => calls += 1
      @lib.Drop => drops += 1
      @lib.I32Add => adds += 1
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) => {
        let (child_calls, child_drops, child_adds) = vacuum_dropped_parent_effects_perf_counts(
          body,
        )
        calls += child_calls
        drops += child_drops
        adds += child_adds
      }
      @lib.If(_, then_body, else_body) => {
        let (then_calls, then_drops, then_adds) = vacuum_dropped_parent_effects_perf_counts(
          then_body,
        )
        calls += then_calls
        drops += then_drops
        adds += then_adds
        match else_body {
          Some(body) => {
            let (else_calls, else_drops, else_adds) = vacuum_dropped_parent_effects_perf_counts(
              body,
            )
            calls += else_calls
            drops += else_drops
            adds += else_adds
          }
          None => ()
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) => {
        let (child_calls, child_drops, child_adds) = vacuum_dropped_parent_effects_perf_counts(
          body,
        )
        calls += child_calls
        drops += child_drops
        adds += child_adds
      }
      _ => ()
    }
  }
  (calls, drops, adds)
}

///|
fn vacuum_dropped_parent_effects_perf_worker_counts(
  mod_ : @lib.Module,
) -> (Int, Int, Int) {
  match mod_.code_sec {
    Some(@lib.CodeSec([_, _, @lib.Func(_, @lib.Expr(body))])) =>
      vacuum_dropped_parent_effects_perf_counts(body)
    _ => abort("expected three-function dropped-parent Vacuum fixture")
  }
}

///|
fn vacuum_dropped_parent_effects_perf_direct_func(
  fixture : @lib.Module,
) -> @ir.HotFunc {
  let func = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(2U))
  let ctx = @passes.HotPassContext::new(
    @ir.HotPassDescriptor::new("vacuum"),
    @ir.HotAnalysisCache::new(),
    @passes.HotPipelineVerifyPolicy::final_module_only(),
    false,
    fn(_) { () },
  )
  match @passes.hot_pass_run(ctx, func) {
    Ok(_) => func
    Err(err) =>
      abort("expected direct dropped-parent Vacuum success, got \{err}")
  }
}

///|
fn vacuum_dropped_parent_effects_perf_preflight(
  fixture : @lib.Module,
  repetitions : Int,
) -> @lib.Module {
  let optimized = match
    @passes.run_hot_pipeline(fixture, @passes.HotPipelineOptions::new(), [
      "vacuum",
    ]) {
    Ok(mod_) => mod_
    Err(err) => abort("expected dropped-parent Vacuum preflight, got \{err}")
  }
  let (calls, drops, adds) = vacuum_dropped_parent_effects_perf_worker_counts(
    optimized,
  )
  if calls != repetitions * 2 || drops != repetitions * 2 || adds != 0 {
    abort(
      "expected calls=\{repetitions * 2} drops=\{repetitions * 2} adds=0, got calls=\{calls} drops=\{drops} adds=\{adds}",
    )
  }
  optimized
}

///|
fn vacuum_candidate_free_calls_perf_preflight(
  fixture : @lib.Module,
  repetitions : Int,
) -> @lib.Module {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let optimized = match
    @passes.run_hot_pipeline(
      fixture,
      @passes.HotPipelineOptions::new(trace=Some(trace)),
      ["vacuum"],
    ) {
    Ok(mod_) => mod_
    Err(err) => abort("expected candidate-free Vacuum preflight, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) => {
      let (calls, drops, adds) = vacuum_dropped_parent_effects_perf_counts(body)
      if calls != repetitions || drops != 0 || adds != 0 {
        abort(
          "expected candidate-free calls=\{repetitions}, got calls=\{calls} drops=\{drops} adds=\{adds}",
        )
      }
    }
    _ => abort("expected one candidate-free Vacuum function")
  }
  let mut saw_skip = false
  let mut saw_lift = false
  for line in lines {
    if line.contains("pass[vacuum]:skip-raw reason=no-vacuum-candidates") {
      saw_skip = true
    }
    if line.contains("perf:timer name=lift") {
      saw_lift = true
    }
  }
  if !saw_skip || saw_lift {
    abort("expected candidate-free raw skip without HOT lift")
  }
  optimized
}

///|
fn vacuum_constant_result_if_perf_module(function_count : Int) -> @lib.Module {
  let result_type = @lib.TypeIdx::new(0U)
  let funcs : Array[@lib.Func] = []
  let types : Array[@lib.TypeIdx] = []
  for func_idx = 0; func_idx < function_count; func_idx = func_idx + 1 {
    types.push(result_type)
    funcs.push(
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(func_idx % 2)),
          @lib.Instruction::if_(
            @lib.BlockType::val_type(@lib.ValType::i32()),
            [@lib.Instruction::i32_const(@lib.I32(func_idx * 2 + 1))],
            Some([@lib.Instruction::i32_const(@lib.I32(func_idx * 2 + 2))]),
          ),
        ]),
      ),
    )
  }
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new(types))
  .with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn vacuum_constant_result_if_perf_preflight(
  fixture : @lib.Module,
  function_count : Int,
) -> @lib.Module {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let optimized = match
    @passes.run_hot_pipeline(
      fixture,
      @passes.HotPipelineOptions::new(trace=Some(trace)),
      ["vacuum"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      abort("expected constant result-if Vacuum preflight, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      if funcs.length() != function_count {
        abort("expected \{function_count} constant result-if functions")
      }
      for func_idx = 0; func_idx < funcs.length(); func_idx = func_idx + 1 {
        let @lib.Func(_, @lib.Expr(body)) = funcs[func_idx]
        let expected = if func_idx % 2 == 0 {
          func_idx * 2 + 2
        } else {
          func_idx * 2 + 1
        }
        if body != [@lib.Instruction::i32_const(@lib.I32(expected))] {
          abort(
            "expected selected constant result-if arm at function \{func_idx}",
          )
        }
      }
    }
    None => abort("expected constant result-if code section")
  }
  let mut saw_skip = false
  let mut saw_lift = false
  for line in lines {
    if line.contains(
        "pass[vacuum]:skip-raw reason=raw-vacuum-preclean count=\{function_count}",
      ) {
      saw_skip = true
    }
    if line.contains("perf:timer name=lift") {
      saw_lift = true
    }
  }
  if !saw_skip || saw_lift {
    abort(
      "expected module-wide constant result-if raw preclean without HOT lift",
    )
  }
  optimized
}

///|
fn vacuum_unreachable_arm_perf_module(repetitions : Int) -> @lib.Module {
  let result_type = @lib.TypeIdx::new(0U)
  let void_type = @lib.TypeIdx::new(1U)
  let body : Array[@lib.Instruction] = []
  for repetition = 0; repetition < repetitions; repetition = repetition + 1 {
    body.push(@lib.Instruction::call(@lib.FuncIdx::new(0U)))
    body.push(
      @lib.Instruction::if_(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        [@lib.Instruction::unreachable_()],
        Some([@lib.Instruction::call(@lib.FuncIdx::new(1U))]),
      ),
    )
    body.push(@lib.Instruction::drop())
  }
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
      ),
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([result_type, result_type, void_type]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
      ),
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(7))]),
      ),
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
    ]),
  )
}

///|
fn vacuum_unreachable_arm_perf_preflight(
  fixture : @lib.Module,
  repetitions : Int,
) -> @lib.Module {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let optimized = match
    @passes.run_hot_pipeline(
      fixture,
      @passes.HotPipelineOptions::new(trace=Some(trace)),
      ["vacuum"],
    ) {
    Ok(mod_) => mod_
    Err(err) => abort("expected unreachable-arm Vacuum preflight, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([_, _, @lib.Func(_, @lib.Expr(body))])) => {
      if body.length() != repetitions * 2 {
        abort("expected two lowered roots per unreachable-arm repetition")
      }
      for repetition = 0; repetition < repetitions; repetition = repetition + 1 {
        match (body[repetition * 2], body[repetition * 2 + 1]) {
          (
            @lib.Call(@lib.FuncIdx(0U)),
            @lib.If(
              @lib.VoidBlockType,
              [@lib.Unreachable],
              Some([@lib.Call(@lib.FuncIdx(1U)), @lib.Drop])
            ),
          ) => ()
          _ => abort("expected exact unreachable-arm rewrite at \{repetition}")
        }
      }
    }
    _ => abort("expected one unreachable-arm worker")
  }
  let mut saw_skip = false
  let mut saw_lift = false
  for line in lines {
    if line.contains("pass[vacuum]:skip-raw reason=raw-vacuum-preclean count=1") {
      saw_skip = true
    }
    if line.contains("perf:timer name=lift") {
      saw_lift = true
    }
  }
  if !saw_skip || saw_lift {
    abort("expected unreachable-arm raw preclean without HOT lift")
  }
  optimized
}

///|
test "bench HOT lift vacuum dropped binary parents repetitions=4096" (
  it : @bench.T,
) {
  let fixture = vacuum_dropped_parent_effects_perf_module(4096)
  let preflight = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(2U))
  assert_true(@ir.hot_node_count(preflight) >= 16384)
  it.bench(fn() {
    let lifted = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(2U))
    ignore(@ir.hot_node_count(lifted))
  })
}

///|
test "bench HOT pass vacuum dropped binary parents repetitions=4096" (
  it : @bench.T,
) {
  let fixture = vacuum_dropped_parent_effects_perf_module(4096)
  let preflight = vacuum_dropped_parent_effects_perf_direct_func(fixture)
  let lowered = @ir.hot_lower_func_unverified(preflight)
  let @lib.Func(_, @lib.Expr(body)) = lowered
  let (calls, drops, adds) = vacuum_dropped_parent_effects_perf_counts(body)
  assert_true(calls == 8192 && drops == 8192 && adds == 0)
  it.bench(fn() {
    let func = vacuum_dropped_parent_effects_perf_direct_func(fixture)
    ignore(@ir.hot_node_count(func))
  })
}

///|
test "bench HOT lower vacuum dropped binary parents repetitions=4096" (
  it : @bench.T,
) {
  let fixture = vacuum_dropped_parent_effects_perf_module(4096)
  let optimized = vacuum_dropped_parent_effects_perf_direct_func(fixture)
  let preflight = @ir.hot_lower_func_unverified(optimized)
  let @lib.Func(_, @lib.Expr(preflight_body)) = preflight
  ignore(preflight_body.length())
  it.bench(fn() {
    let lowered = @ir.hot_lower_func_unverified(optimized)
    let @lib.Func(_, @lib.Expr(body)) = lowered
    ignore(body.length())
  })
}

///|
test "bench vacuum dropped binary parents repetitions=4096" (it : @bench.T) {
  let repetitions = 4096
  let fixture = vacuum_dropped_parent_effects_perf_module(repetitions)
  ignore(vacuum_dropped_parent_effects_perf_preflight(fixture, repetitions))
  let options = @passes.HotPipelineOptions::new(validate_final_module=false)
  it.bench(fn() {
    match @passes.run_hot_pipeline(fixture, options, ["vacuum"]) {
      Ok(mod_) => ignore(mod_.code_sec)
      Err(err) => abort("expected dropped-parent Vacuum benchmark, got \{err}")
    }
  })
}

///|
test "bench vacuum raw candidate-free calls repetitions=4096" (it : @bench.T) {
  let repetitions = 4096
  let fixture = vacuum_candidate_free_calls_perf_module(repetitions)
  ignore(vacuum_candidate_free_calls_perf_preflight(fixture, repetitions))
  let options = @passes.HotPipelineOptions::new(validate_final_module=false)
  it.bench(fn() {
    match @passes.run_hot_pipeline(fixture, options, ["vacuum"]) {
      Ok(mod_) => ignore(mod_.code_sec)
      Err(err) => abort("expected candidate-free Vacuum benchmark, got \{err}")
    }
  })
}

///|
test "bench vacuum raw constant result if functions=2048" (it : @bench.T) {
  let function_count = 2048
  let fixture = vacuum_constant_result_if_perf_module(function_count)
  ignore(vacuum_constant_result_if_perf_preflight(fixture, function_count))
  let options = @passes.HotPipelineOptions::new(validate_final_module=false)
  it.bench(fn() {
    match @passes.run_hot_pipeline(fixture, options, ["vacuum"]) {
      Ok(mod_) => ignore(mod_.code_sec)
      Err(err) =>
        abort("expected constant result-if Vacuum benchmark, got \{err}")
    }
  })
}

///|
test "bench vacuum raw unreachable result-if arms repetitions=2048" (
  it : @bench.T,
) {
  let repetitions = 2048
  let fixture = vacuum_unreachable_arm_perf_module(repetitions)
  ignore(vacuum_unreachable_arm_perf_preflight(fixture, repetitions))
  let options = @passes.HotPipelineOptions::new(validate_final_module=false)
  it.bench(fn() {
    match @passes.run_hot_pipeline(fixture, options, ["vacuum"]) {
      Ok(mod_) => ignore(mod_.code_sec)
      Err(err) => abort("expected unreachable-arm Vacuum benchmark, got \{err}")
    }
  })
}
