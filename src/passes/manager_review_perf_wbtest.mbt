///|
fn manager_review_reference_vacuum_preclean(
  mod_ : @lib.Module,
  func_idx : @lib.FuncIdx,
  module_state : HotPipelineModuleState,
  descriptor : @ir.HotPassDescriptor,
  options : HotPipelineOptions,
) -> HotPipelineFuncResult? {
  if descriptor.name != "vacuum" {
    return None
  }
  let original = run_hot_pipeline_original_func(mod_, func_idx)
  let @lib.Func(locals, @lib.Expr(instrs)) = original
  match run_hot_pipeline_raw_vacuum_deep_singleton_call_leaf(instrs) {
    Some(leaf) =>
      return Some({
        reason: "raw-vacuum-deep-singleton-call-leaf",
        func: run_hot_pipeline_raw_vacuum_finalize_precleaned_func(
          mod_, func_idx, module_state, options, locals, leaf,
        ),
        unchanged_original: false,
        trace_skip_raw: true,
      })
    None => ()
  }
  let has_dropped_typeidx_block = run_hot_pipeline_raw_vacuum_instrs_have_dropped_typeidx_block(
    instrs,
  )
  let has_flattenable_no_throw_exception_region = run_hot_pipeline_raw_vacuum_instrs_have_flattenable_no_throw_exception_region(
    instrs,
  )
  let has_legacy_try = run_hot_pipeline_raw_vacuum_instrs_have_legacy_try(
    instrs,
  )
  if run_hot_pipeline_raw_vacuum_has_negative_array_allocation_drop(instrs) {
    return Some({
      reason: "negative-array-allocation-vacuum-noop",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if run_hot_pipeline_raw_has_root_global_snapshot_return_hazard(instrs) {
    return Some({
      reason: "root-global-snapshot-return-vacuum-noop",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if options.optimize_level == 0 && options.shrink_level == 0 {
    let (flattened, changed) = run_hot_pipeline_raw_vacuum_flatten_unbranched_result_blocks(
      instrs, false, false,
    )
    if changed {
      let level_zero_module_ctx = if has_dropped_typeidx_block {
        Some(run_hot_pipeline_require_module_ctx(mod_, module_state, options))
      } else {
        None
      }
      let (precleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs_owned(
        flattened, level_zero_module_ctx,
      )
      return Some({
        reason: "raw-vacuum-unbranched-result-blocks",
        func: run_hot_pipeline_raw_vacuum_finalize_precleaned_func(
          mod_, func_idx, module_state, options, locals, precleaned,
        ),
        unchanged_original: false,
        trace_skip_raw: true,
      })
    }
  }
  let has_fresh_array_set = run_hot_pipeline_raw_vacuum_instrs_have_fresh_array_set_candidate(
    instrs,
  )
  let has_dropped_ref_func_struct = run_hot_pipeline_raw_vacuum_instrs_have_dropped_ref_func_struct(
    instrs,
  )
  let has_dropped_simple_struct = run_hot_pipeline_raw_vacuum_instrs_have_dropped_simple_struct(
    instrs,
  )
  let module_ctx = if run_hot_pipeline_raw_vacuum_instrs_require_type_context(
      instrs,
    ) ||
    has_fresh_array_set ||
    has_dropped_ref_func_struct ||
    has_dropped_simple_struct {
    Some(run_hot_pipeline_require_module_ctx(mod_, module_state, options))
  } else {
    None
  }
  let has_constant_result_if = [false]
  let (has_writes, has_structured_control, has_branches, _, _, instr_count) = run_hot_pipeline_instr_scan(
    instrs,
    constant_result_if=Some(has_constant_result_if),
  )
  let has_stack_effect = run_hot_pipeline_raw_vacuum_instrs_have_stack_effect_hazard(
    instrs,
  )
  let guarded_hot_hazard = has_writes && has_stack_effect
  if guarded_hot_hazard {
    let (rewritten, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
      instrs, module_ctx,
    )
    if !changed {
      return Some({
        reason: "raw-vacuum-guarded-hazard",
        func: original,
        unchanged_original: true,
        trace_skip_raw: true,
      })
    }
    let final_rewritten = if run_hot_pipeline_raw_vacuum_instrs_need_load_linked_second_preclean(
        rewritten,
      ) {
      let (rerun, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(
        rewritten, module_ctx,
      )
      rerun
    } else {
      rewritten
    }
    return Some({
      reason: "raw-vacuum-preclean",
      func: run_hot_pipeline_raw_vacuum_finalize_precleaned_func(
        mod_, func_idx, module_state, options, locals, final_rewritten,
      ),
      unchanged_original: false,
      trace_skip_raw: true,
    })
  }
  let has_dropped_local_tee = run_hot_pipeline_raw_vacuum_instrs_have_dropped_local_tee(
    instrs,
  )
  if run_hot_pipeline_raw_vacuum_has_dense_nop_debris(instrs) ||
    run_hot_pipeline_raw_vacuum_instrs_have_dropped_pure_simd_expr(instrs) ||
    run_hot_pipeline_raw_vacuum_instrs_have_dropped_simd_replace_lane_load(
      instrs,
    ) ||
    run_hot_pipeline_raw_vacuum_instrs_have_terminal_owner_branch_candidate(
      instrs,
    ) ||
    (
      has_dropped_local_tee &&
      !run_hot_pipeline_raw_vacuum_instrs_are_local_only_removable(instrs)
    ) ||
    run_hot_pipeline_raw_vacuum_instrs_have_const_nontrapping_int_divrem_drop(
      instrs,
    ) ||
    run_hot_pipeline_raw_vacuum_instrs_have_repeated_dropped_load(instrs) ||
    has_dropped_typeidx_block ||
    has_constant_result_if[0] ||
    has_flattenable_no_throw_exception_region ||
    has_legacy_try ||
    has_fresh_array_set ||
    has_dropped_ref_func_struct ||
    has_dropped_simple_struct {
    let (rewritten, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
      instrs, module_ctx,
    )
    if changed {
      let final_rewritten = if run_hot_pipeline_raw_vacuum_instrs_need_load_linked_second_preclean(
          rewritten,
        ) {
        let (rerun, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(
          rewritten, module_ctx,
        )
        rerun
      } else {
        rewritten
      }
      return Some({
        reason: "raw-vacuum-preclean",
        func: run_hot_pipeline_raw_vacuum_finalize_precleaned_func(
          mod_, func_idx, module_state, options, locals, final_rewritten,
        ),
        unchanged_original: false,
        trace_skip_raw: true,
      })
    }
  }
  let branchy_structured_writes = has_writes &&
    has_structured_control &&
    has_branches
  let branchy_structured_nop_debris = branchy_structured_writes &&
    run_hot_pipeline_raw_vacuum_count_nops_until(instrs, 1) >= 1
  let has_terminal_debris = run_hot_pipeline_raw_vacuum_instrs_have_terminal_unreachable_debris(
    instrs,
  )
  if instr_count <= 2048 &&
    !branchy_structured_nop_debris &&
    !has_terminal_debris {
    return None
  }
  let (rewritten, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    instrs, module_ctx,
  )
  if branchy_structured_nop_debris && !changed {
    return Some({
      reason: "raw-vacuum-structured-writes",
      func: original,
      unchanged_original: true,
      trace_skip_raw: true,
    })
  }
  if !changed {
    return None
  }
  let final_rewritten = if instr_count <= 2048 ||
    run_hot_pipeline_raw_vacuum_instrs_need_load_linked_second_preclean(
      rewritten,
    ) {
    let (rerun, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(
      rewritten, module_ctx,
    )
    rerun
  } else {
    rewritten
  }
  Some({
    reason: "raw-vacuum-preclean",
    func: run_hot_pipeline_raw_vacuum_finalize_precleaned_func(
      mod_, func_idx, module_state, options, locals, final_rewritten,
    ),
    unchanged_original: false,
    trace_skip_raw: true,
  })
}

///|
// Frozen performance controls from the reviewed baseline. They are used only
// by the dedicated native benchmark lane.
fn manager_review_reference_writeback(
  original_mod : @lib.Module,
  candidate_mod : @lib.Module,
  options : HotPipelineOptions,
) -> @lib.Module? {
  let imported_func_count = run_hot_pipeline_imported_func_count(original_mod)
  match (original_mod.code_sec, candidate_mod.code_sec) {
    (Some(@lib.CodeSec(original_defs)), Some(@lib.CodeSec(candidate_defs))) => {
      let changed_funcs : Array[(@lib.FuncIdx, @lib.Func)] = []
      for code_idx = 0
          code_idx < candidate_defs.length()
          code_idx = code_idx + 1 {
        if code_idx < original_defs.length() &&
          candidate_defs[code_idx] != original_defs[code_idx] {
          changed_funcs.push(
            (
              @lib.FuncIdx::new(
                (imported_func_count + code_idx).reinterpret_as_uint(),
              ),
              candidate_defs[code_idx],
            ),
          )
        }
      }
      if changed_funcs.length() == 0 {
        return Some(candidate_mod)
      }
      let invalid_funcs = match
        @validate.validate_defined_funcs_against_module(
          candidate_mod, changed_funcs,
        ) {
        Ok(errors) => errors
        Err(err) => {
          pipeline_trace_hook(
            options.trace,
            "vacuum",
            "writeback-batch-invalid",
            payload="err=\{err}",
          )
          return None
        }
      }
      if invalid_funcs.length() == 0 {
        return Some(candidate_mod)
      }
      pipeline_trace_hook(
        options.trace,
        "vacuum",
        "writeback-batch-invalid",
        payload="changed=\{changed_funcs.length()} invalid=\{invalid_funcs.length()}",
      )
      let repaired_defs = candidate_defs.copy()
      for item in invalid_funcs {
        let (func_idx, err) = item
        let @lib.FuncIdx(raw_func_idx) = func_idx
        let code_idx = raw_func_idx.reinterpret_as_int() - imported_func_count
        if code_idx < 0 ||
          code_idx >= repaired_defs.length() ||
          code_idx >= original_defs.length() {
          return None
        }
        if repaired_defs[code_idx] == original_defs[code_idx] {
          return None
        }
        repaired_defs[code_idx] = original_defs[code_idx]
        pipeline_trace_hook(
          options.trace,
          "vacuum",
          "skip-invalid-lower",
          payload="func=\{func_idx} reason=writeback-batch-validate:\{err}",
        )
      }
      Some(candidate_mod.with_code_sec(@lib.CodeSec::new(repaired_defs)))
    }
    _ => None
  }
}

///|
fn manager_review_reference_intern(
  lower_state : HotPipelineLowerState,
  results : Array[@lib.ValType],
) -> @lib.TypeIdx {
  match
    run_hot_pipeline_lower_find_block_result_type_idx(
      lower_state.next_type_sec,
      results,
    ) {
    Some(type_idx) => type_idx
    None => {
      let next_flat_idx = run_hot_pipeline_lower_type_sec_flat_count(
        lower_state.next_type_sec,
      )
      let next_rec_types : Array[@lib.RecType] = []
      match lower_state.next_type_sec {
        Some(@lib.TypeSec(rec_types)) =>
          for rec_type in rec_types {
            next_rec_types.push(rec_type)
          }
        None => ()
      }
      next_rec_types.push(
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([], results)),
        ),
      )
      lower_state.next_type_sec = Some(@lib.TypeSec::new(next_rec_types))
      lower_state.type_sec_changed = true
      @lib.TypeIdx::new(next_flat_idx.reinterpret_as_uint())
    }
  }
}

///|
fn manager_review_fixture(count : Int32, width : Int32) -> @lib.Module {
  let funcs = Array::makei(count, fn(_) {
    let body = Array::make(width, @lib.Instruction::nop())
    body.push(@lib.Instruction::i32_const(@lib.I32(7)))
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
  })
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new(Array::make(count, @lib.TypeIdx::new(0U))))
  .with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn manager_review_writeback_bench(
  it : @bench.T,
  count : Int32,
  width : Int32,
  reference : Bool,
) -> Unit {
  let input = manager_review_fixture(count, width)
  let defs = input.code_sec.unwrap().0.copy()
  defs[count - 1] = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
  let candidate = input.with_code_sec(@lib.CodeSec::new(defs))
  let options = HotPipelineOptions::new()
  let actual = run_hot_pipeline_vacuum_repair_batch_writeback(
    input, candidate, options,
  ).unwrap()
  if @binary.encode_module(actual).unwrap() !=
    @binary.encode_module(input).unwrap() {
    abort("writeback did not restore the invalid body")
  }
  manager_review_measure(it, fn() {
    it.keep(
      if reference {
        manager_review_reference_writeback(input, candidate, options)
      } else {
        run_hot_pipeline_vacuum_repair_batch_writeback(
          input, candidate, options,
        )
      },
    )
  })
}

///|
#skip("dedicated native pass manager performance lane")
test "bench manager writeback shared128 width512" (it : @bench.T) {
  manager_review_writeback_bench(it, 128, 512, false)
}

///|
#skip("dedicated native pass manager performance lane")
test "bench manager writeback shared4 width8" (it : @bench.T) {
  manager_review_writeback_bench(it, 4, 8, false)
}

///|
fn manager_review_intern_bench(
  it : @bench.T,
  count : Int32,
  width : Int32,
  reference : Bool,
) -> Unit {
  let input = manager_review_fixture(count, 1).type_sec.unwrap()
  let @lib.TypeSec(base) = input
  let types = @lib.TypeSec::new(Array::make(count, base[0]))
  let results = Array::makei(width, fn(index) {
    Array::makei(9, fn(bit) {
      if ((index >> bit) & 1) == 0 {
        @lib.ValType::i32()
      } else {
        @lib.ValType::i64()
      }
    })
  })
  manager_review_measure(it, fn() {
    let state : HotPipelineLowerState = HotPipelineLowerState::new(Some(types))
    for result in results {
      it.keep(
        if reference {
          manager_review_reference_intern(state, result)
        } else {
          run_hot_pipeline_lower_intern_block_result_type_idx(state, result)
        },
      )
    }
    for result in results {
      it.keep(
        if reference {
          manager_review_reference_intern(state, result)
        } else {
          run_hot_pipeline_lower_intern_block_result_type_idx(state, result)
        },
      )
    }
    it.keep(state.next_type_sec)
  })
  if run_hot_pipeline_lower_type_sec_flat_count(Some(types)) != count {
    abort("type interning changed the source section")
  }
}

///|
#skip("dedicated native pass manager performance lane")
test "bench manager intern types2048 results128" (it : @bench.T) {
  manager_review_intern_bench(it, 2048, 128, false)
}

///|
#skip("dedicated native pass manager performance lane")
test "bench manager intern types4 results2" (it : @bench.T) {
  manager_review_intern_bench(it, 4, 2, false)
}

///|
fn manager_review_vacuum_bench(
  it : @bench.T,
  width : Int32,
  reference : Bool,
) -> Unit {
  let body : Array[@lib.Instruction] = []
  for _ in 0..<width {
    body.push(@lib.Instruction::call(@lib.FuncIdx::new(0U)))
  }
  body.push(@lib.Instruction::i32_const(@lib.I32(7)))
  let input = manager_review_fixture(1, 0)
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::new("env"),
          @lib.Name::new("effect"),
          @lib.ExternType::func(@lib.TypeIdx::new(1U)),
        ),
      ]),
    )
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
      ]),
    )
  @validate.validate_module(input).unwrap()
  let options = HotPipelineOptions::new()
  let entry = pass_registry_lookup_cached("vacuum").unwrap()
  let actual = run_hot_pipeline_apply_hot_pass(input, entry, options).unwrap()
  if @binary.encode_module(actual).unwrap() !=
    @binary.encode_module(input).unwrap() {
    abort("cold vacuum changed effectful calls")
  }
  manager_review_measure(it, fn() {
    let descriptor = entry.descriptor.unwrap()
    let state = HotPipelineModuleState::new()
    if !reference &&
      run_hot_pipeline_raw_vacuum_preclean_flat_loop_is_unchanged(body) {
      match
        run_hot_pipeline_raw_vacuum_no_candidates(
          input,
          @lib.FuncIdx::new(1U),
          descriptor,
        ) {
        Some(result) => {
          it.keep(result)
          return
        }
        None => ()
      }
    }
    let preclean = if reference {
      manager_review_reference_vacuum_preclean(
        input,
        @lib.FuncIdx::new(1U),
        state,
        descriptor,
        options,
      )
    } else {
      run_hot_pipeline_raw_vacuum_preclean(
        input,
        @lib.FuncIdx::new(1U),
        state,
        descriptor,
        options,
      )
    }
    it.keep(preclean)
    if preclean is None {
      it.keep(
        run_hot_pipeline_raw_vacuum_no_candidates(
          input,
          @lib.FuncIdx::new(1U),
          descriptor,
        ),
      )
    }
  })
}

///|
#skip("dedicated native pass manager performance lane")
test "bench manager vacuum cold1024" (it : @bench.T) {
  manager_review_vacuum_bench(it, 1024, false)
}

///|
#skip("dedicated native pass manager performance lane")
test "bench manager vacuum cold8" (it : @bench.T) {
  manager_review_vacuum_bench(it, 8, false)
}

///|
#skip("dedicated native pass manager performance lane")
test "bench manager writeback shared128 width512 reference" (it : @bench.T) {
  manager_review_writeback_bench(it, 128, 512, true)
}

///|
#skip("dedicated native pass manager performance lane")
test "bench manager writeback shared4 width8 reference" (it : @bench.T) {
  manager_review_writeback_bench(it, 4, 8, true)
}

///|
#skip("dedicated native pass manager performance lane")
test "bench manager intern types2048 results128 reference" (it : @bench.T) {
  manager_review_intern_bench(it, 2048, 128, true)
}

///|
#skip("dedicated native pass manager performance lane")
test "bench manager intern types4 results2 reference" (it : @bench.T) {
  manager_review_intern_bench(it, 4, 2, true)
}

///|
fn manager_review_context_bench(
  it : @bench.T,
  count : Int32,
  reference : Bool,
) -> Unit {
  let input = manager_review_fixture(count, 1)
  let options = HotPipelineOptions::new()
  let code = input.code_sec.unwrap().0
  let modules = Array::makei(8, fn(wave) {
    let defs = code.copy()
    defs[wave % count] = @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(wave))]),
    )
    input.with_code_sec(@lib.CodeSec::new(defs))
  })
  let check_cache = HotPipelineModuleCache::new()
  for mod_ in modules {
    let result = run_hot_pipeline_require_module_ctx(
      mod_,
      HotPipelineModuleState::new(module_cache=Some(check_cache)),
      options,
    )
    if result != @ir.hot_module_context_from_module(mod_) {
      abort("module cache changed context")
    }
  }
  manager_review_measure(it, fn() {
    let cache = if reference {
      None
    } else {
      Some(HotPipelineModuleCache::new())
    }
    for mod_ in modules {
      it.keep(
        run_hot_pipeline_require_module_ctx(
          mod_,
          HotPipelineModuleState::new(module_cache=cache),
          options,
        ),
      )
    }
  })
}

///|
#skip("dedicated native pass manager performance lane")
test "bench manager context functions512 waves8 reference" (it : @bench.T) {
  manager_review_context_bench(it, 512, true)
}

///|
#skip("dedicated native pass manager performance lane")
test "bench manager context functions512 waves8 cached" (it : @bench.T) {
  manager_review_context_bench(it, 512, false)
}

///|
#skip("dedicated native pass manager performance lane")
test "bench manager context functions4 waves8 reference" (it : @bench.T) {
  manager_review_context_bench(it, 4, true)
}

///|
#skip("dedicated native pass manager performance lane")
test "bench manager context functions4 waves8 cached" (it : @bench.T) {
  manager_review_context_bench(it, 4, false)
}

///|
// Fixed work gives an external malloc/RSS probe equal iteration counts. The
// benchmark path retains the standard adaptive timing controls.
fn manager_review_measure(it : @bench.T, work : () -> Unit) -> Unit {
  if @env.get_env_var("STARSHINE_MANAGER_PERF_FIXED") == Some("1") {
    for _ in 0..<64 {
      work()
    }
  } else {
    it.bench(work)
  }
}

///|
fn manager_review_vacuum_admission_bench(
  it : @bench.T,
  width : Int32,
  reference : Bool,
) -> Unit {
  let body = Array::make(
    width,
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::drop(),
      ]),
    ),
  )
  body.push(
    @lib.Instruction::block(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      @lib.Expr::new([]),
    ),
  )
  body.push(@lib.Instruction::drop())
  body.push(@lib.Instruction::drop())
  let expected = VacuumPrecleanAdmissionFacts::new(body)
  if !expected.dropped_typeidx_block || !expected.needs_type_context {
    abort("incorrect vacuum admission fixture")
  }
  manager_review_measure(it, fn() {
    let facts = if reference {
      let facts = VacuumPrecleanAdmissionFacts::new([])
      facts.dropped_typeidx_block = run_hot_pipeline_raw_vacuum_instrs_have_dropped_typeidx_block(
        body,
      )
      facts.flattenable_exception = run_hot_pipeline_raw_vacuum_instrs_have_flattenable_no_throw_exception_region(
        body,
      )
      facts.legacy_try = run_hot_pipeline_raw_vacuum_instrs_have_legacy_try(
        body,
      )
      facts.fresh_array_set = run_hot_pipeline_raw_vacuum_instrs_have_fresh_array_set_candidate(
        body,
      )
      facts.dropped_simple_struct = run_hot_pipeline_raw_vacuum_instrs_have_dropped_simple_struct(
        body,
      )
      facts.needs_type_context = run_hot_pipeline_raw_vacuum_instrs_require_type_context(
        body,
      )
      it.keep(
        run_hot_pipeline_raw_vacuum_instrs_have_dropped_ref_func_struct(body),
      )
      facts
    } else {
      VacuumPrecleanAdmissionFacts::new(body)
    }
    it.keep(facts)
  })
}

///|
#skip("dedicated native pass manager performance lane")
test "bench manager vacuum admission width128 reference" (it : @bench.T) {
  manager_review_vacuum_admission_bench(it, 128, true)
}

///|
#skip("dedicated native pass manager performance lane")
test "bench manager vacuum admission width128 combined" (it : @bench.T) {
  manager_review_vacuum_admission_bench(it, 128, false)
}

///|
#skip("dedicated native pass manager performance lane")
test "bench manager vacuum admission width4 reference" (it : @bench.T) {
  manager_review_vacuum_admission_bench(it, 4, true)
}

///|
#skip("dedicated native pass manager performance lane")
test "bench manager vacuum admission width4 combined" (it : @bench.T) {
  manager_review_vacuum_admission_bench(it, 4, false)
}

///|
#skip("dedicated native pass manager performance lane")
test "bench manager vacuum cold1024 reference" (it : @bench.T) {
  manager_review_vacuum_bench(it, 1024, true)
}

///|
#skip("dedicated native pass manager performance lane")
test "bench manager vacuum cold8 reference" (it : @bench.T) {
  manager_review_vacuum_bench(it, 8, true)
}
