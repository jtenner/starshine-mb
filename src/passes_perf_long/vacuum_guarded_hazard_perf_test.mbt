///|
fn vacuum_guarded_hazard_perf_module(repetitions : Int) -> @lib.Module {
  let empty_func_type = @lib.TypeIdx::new(0U)
  let body : Array[@lib.Instruction] = []
  for value = 0; value < repetitions; value = value + 1 {
    body.push(@lib.Instruction::i32_const(@lib.I32(value)))
    body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(0U)))
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
        @lib.func_extern_type(empty_func_type),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([empty_func_type]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([@lib.ValType::i32()]),
        @lib.Expr::new(body),
      ),
    ]),
  )
}

///|
fn vacuum_guarded_hazard_perf_nested_module(depth : Int) -> @lib.Module {
  let empty_func_type = @lib.TypeIdx::new(0U)
  let mut body : Array[@lib.Instruction] = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ]
  for level = 0; level < depth; level = level + 1 {
    body = [
      @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(body)),
    ]
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
        @lib.func_extern_type(empty_func_type),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([empty_func_type]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([@lib.ValType::i32()]),
        @lib.Expr::new(body),
      ),
    ]),
  )
}

///|
fn vacuum_guarded_hazard_perf_count_instrs(
  instrs : Array[@lib.Instruction],
) -> (Int, Int) {
  let mut local_sets = 0
  let mut calls = 0
  for instr in instrs {
    match instr {
      @lib.LocalSet(_) => local_sets = local_sets + 1
      @lib.Call(_) => calls = calls + 1
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) => {
        let (child_sets, child_calls) = vacuum_guarded_hazard_perf_count_instrs(
          body,
        )
        local_sets = local_sets + child_sets
        calls = calls + child_calls
      }
      @lib.If(_, then_body, else_body) => {
        let (then_sets, then_calls) = vacuum_guarded_hazard_perf_count_instrs(
          then_body,
        )
        local_sets = local_sets + then_sets
        calls = calls + then_calls
        match else_body {
          Some(body) => {
            let (else_sets, else_calls) = vacuum_guarded_hazard_perf_count_instrs(
              body,
            )
            local_sets = local_sets + else_sets
            calls = calls + else_calls
          }
          None => ()
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) => {
        let (child_sets, child_calls) = vacuum_guarded_hazard_perf_count_instrs(
          body,
        )
        local_sets = local_sets + child_sets
        calls = calls + child_calls
      }
      _ => ()
    }
  }
  (local_sets, calls)
}

///|
fn vacuum_guarded_hazard_perf_counts(mod_ : @lib.Module) -> (Int, Int) {
  let body = match mod_.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) => body
    _ => abort("expected one Vacuum guarded-hazard benchmark function")
  }
  vacuum_guarded_hazard_perf_count_instrs(body)
}

///|
fn vacuum_guarded_hazard_perf_block_depth(
  instrs : Array[@lib.Instruction],
  depth : Int,
) -> Int {
  let mut maximum = depth
  for instr in instrs {
    match instr {
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) => {
        let child = vacuum_guarded_hazard_perf_block_depth(body, depth + 1)
        if child > maximum {
          maximum = child
        }
      }
      @lib.If(_, then_body, else_body) => {
        let then_depth = vacuum_guarded_hazard_perf_block_depth(
          then_body,
          depth + 1,
        )
        if then_depth > maximum {
          maximum = then_depth
        }
        match else_body {
          Some(body) => {
            let else_depth = vacuum_guarded_hazard_perf_block_depth(
              body,
              depth + 1,
            )
            if else_depth > maximum {
              maximum = else_depth
            }
          }
          None => ()
        }
      }
      _ => ()
    }
  }
  maximum
}

///|
fn vacuum_guarded_hazard_perf_module_block_depth(mod_ : @lib.Module) -> Int {
  match mod_.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) =>
      vacuum_guarded_hazard_perf_block_depth(body, 0)
    _ => abort("expected one Vacuum guarded-hazard benchmark function")
  }
}

///|
fn vacuum_guarded_hazard_perf_direct_func(fixture : @lib.Module) -> @ir.HotFunc {
  let func = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(1U))
  let ctx = @passes.HotPassContext::new(
    @ir.HotPassDescriptor::new("vacuum"),
    @ir.HotAnalysisCache::new(),
    @passes.HotPipelineVerifyPolicy::final_module_only(),
    false,
    fn(_) { () },
  )
  match @passes.hot_pass_run(ctx, func) {
    Ok(_) => func
    Err(err) => abort("expected direct Vacuum benchmark success, got \{err}")
  }
}

///|
fn vacuum_guarded_hazard_perf_assert_raw_skip(
  fixture : @lib.Module,
  expected_local_sets : Int,
  expected_calls : Int,
  expected_reason : String,
) -> @lib.Module {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = @passes.HotPerfSession::new(
    trace~,
    dump_options=@passes.HotPerfDumpOptions::new(),
  )
  let preflight = match
    @passes.run_hot_pipeline(
      fixture,
      @passes.HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
      ["vacuum"],
    ) {
    Ok(mod_) => mod_
    Err(err) => abort("expected guarded-hazard Vacuum preflight, got \{err}")
  }
  let (local_sets, calls) = vacuum_guarded_hazard_perf_counts(preflight)
  if local_sets != expected_local_sets || calls != expected_calls {
    abort(
      "expected guarded-hazard counts local_sets=\{expected_local_sets} calls=\{expected_calls}, got local_sets=\{local_sets} calls=\{calls}",
    )
  }
  let mut saw_guarded_skip = false
  let mut saw_lift = false
  for line in lines {
    if line.contains("pass[vacuum]:skip-raw reason=\{expected_reason}") {
      saw_guarded_skip = true
    }
    if line.contains("perf:timer name=lift") {
      saw_lift = true
    }
  }
  if !saw_guarded_skip || saw_lift {
    abort(
      "expected guarded-hazard raw skip without HOT lift, got skip=\{saw_guarded_skip} lift=\{saw_lift}",
    )
  }
  preflight
}

///|
test "bench HOT lift vacuum guarded hazards repetitions=4096" (it : @bench.T) {
  let fixture = vacuum_guarded_hazard_perf_module(4096)
  let preflight = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(1U))
  assert_true(@ir.hot_node_count(preflight) > 4096)
  it.bench(fn() {
    let lifted = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(1U))
    ignore(@ir.hot_node_count(lifted))
  })
}

///|
test "bench HOT pass vacuum guarded hazards repetitions=4096" (it : @bench.T) {
  let fixture = vacuum_guarded_hazard_perf_module(4096)
  let preflight = vacuum_guarded_hazard_perf_direct_func(fixture)
  let lowered = @ir.hot_lower_func_unverified(preflight)
  let direct_module = fixture.with_code_sec(@lib.CodeSec::new([lowered]))
  let (local_sets, calls) = vacuum_guarded_hazard_perf_counts(direct_module)
  assert_true(local_sets == 4096)
  assert_true(calls == 4096)
  it.bench(fn() {
    let func = vacuum_guarded_hazard_perf_direct_func(fixture)
    ignore(@ir.hot_node_count(func))
  })
}

///|
test "bench HOT lower vacuum guarded hazards repetitions=4096" (it : @bench.T) {
  let fixture = vacuum_guarded_hazard_perf_module(4096)
  let optimized = vacuum_guarded_hazard_perf_direct_func(fixture)
  let preflight = @ir.hot_lower_func_unverified(optimized)
  let direct_module = fixture.with_code_sec(@lib.CodeSec::new([preflight]))
  let (local_sets, calls) = vacuum_guarded_hazard_perf_counts(direct_module)
  assert_true(local_sets == 4096)
  assert_true(calls == 4096)
  it.bench(fn() {
    let lowered = @ir.hot_lower_func_unverified(optimized)
    let @lib.Func(_, @lib.Expr(body)) = lowered
    ignore(body.length())
  })
}

///|
test "bench HOT lift vacuum nested guarded hazard depth=512" (it : @bench.T) {
  let fixture = vacuum_guarded_hazard_perf_nested_module(512)
  let preflight = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(1U))
  assert_true(@ir.hot_node_count(preflight) > 512)
  it.bench(fn() {
    let lifted = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(1U))
    ignore(@ir.hot_node_count(lifted))
  })
}

///|
test "bench vacuum raw nested guarded hazard depth=512" (it : @bench.T) {
  let fixture = vacuum_guarded_hazard_perf_nested_module(512)
  let preflight = vacuum_guarded_hazard_perf_assert_raw_skip(
    fixture, 1, 1, "raw-vacuum-deep-singleton-call-leaf",
  )
  assert_true(vacuum_guarded_hazard_perf_module_block_depth(preflight) == 0)
  let options = @passes.HotPipelineOptions::new(validate_final_module=false)
  it.bench(fn() {
    match @passes.run_hot_pipeline(fixture, options, ["vacuum"]) {
      Ok(mod_) => ignore(mod_.code_sec)
      Err(err) =>
        abort("expected nested guarded-hazard Vacuum benchmark, got \{err}")
    }
  })
}

///|
test "bench vacuum raw nested guarded hazard depth=1024" (it : @bench.T) {
  let fixture = vacuum_guarded_hazard_perf_nested_module(1024)
  let preflight = vacuum_guarded_hazard_perf_assert_raw_skip(
    fixture, 1, 1, "raw-vacuum-deep-singleton-call-leaf",
  )
  assert_true(vacuum_guarded_hazard_perf_module_block_depth(preflight) == 0)
  let options = @passes.HotPipelineOptions::new(validate_final_module=false)
  it.bench(fn() {
    match @passes.run_hot_pipeline(fixture, options, ["vacuum"]) {
      Ok(mod_) => ignore(mod_.code_sec)
      Err(err) =>
        abort("expected nested guarded-hazard Vacuum benchmark, got \{err}")
    }
  })
}

///|
test "bench vacuum raw guarded hazards repetitions=4096" (it : @bench.T) {
  let repetitions = 4096
  let fixture = vacuum_guarded_hazard_perf_module(repetitions)
  ignore(
    vacuum_guarded_hazard_perf_assert_raw_skip(
      fixture, repetitions, repetitions, "raw-vacuum-guarded-hazard",
    ),
  )
  let options = @passes.HotPipelineOptions::new(validate_final_module=false)
  it.bench(fn() {
    match @passes.run_hot_pipeline(fixture, options, ["vacuum"]) {
      Ok(mod_) => ignore(mod_.code_sec)
      Err(err) => abort("expected guarded-hazard Vacuum benchmark, got \{err}")
    }
  })
}
