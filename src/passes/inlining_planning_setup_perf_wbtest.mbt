///|
fn inl_build_function_infos_reference(
  mod_ : @lib.Module,
  optimize_level? : Int = 0,
  shrink_level? : Int = 0,
  always_inline_max_size? : Int = 2,
  one_caller_inline_max_size? : Int = -1,
  flexible_inline_max_size? : Int = 20,
  max_combined_binary_size? : Int = 400 * 1024,
  allow_functions_with_loops? : Bool = false,
  trivial_mode_cache? : Array[(Bool, Bool)?]? = None,
  classification_counts? : Array[Int]? = None,
  body_measure_cache? : InlBodyMeasureCache? = None,
) -> Array[InlFunctionInfo] {
  let imports = inl_imported_func_count(mod_)
  let total = imports + inl_defined_func_count(mod_)
  let refs = Array::make(total, 0)
  let used = Array::make(total, false)
  inl_mark_global_uses(mod_, used)
  let direct_targets_by_func : Array[Array[Int]] = []
  for _ in 0..<imports {
    direct_targets_by_func.push([])
  }
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(_, @lib.Expr(body)) = func
        let direct_targets : Array[Int] = []
        inl_scan_refs(body, refs, used, direct_targets=Some(direct_targets))
        direct_targets_by_func.push(direct_targets)
      }
    None => ()
  }
  let types = inl_collect_func_type_indices(mod_)
  let (no_full_inline, _) = no_inline_policy_flags(mod_)
  let partial_wrappers = inl_partial_wrapper_flags(mod_, total)
  let toolchain_inline_hints = inl_toolchain_inline_hints(mod_, total)
  let infos : Array[InlFunctionInfo] = []
  let module_ctx = @ir.hot_module_context_from_module(mod_)
  let mut abs = 0
  while abs < total {
    let (
      params,
      results,
      size,
      has_calls,
      has_loops,
      _,
      has_return_call,
      trivial_shrinks,
      trivial_may_not_shrink,
    ) = if abs < imports {
      match
        @ir.hot_module_resolve_func_type(
          module_ctx,
          @lib.FuncIdx::new(abs.reinterpret_as_uint()),
        ) {
        Some(@lib.FuncType(params, results)) =>
          (params, results, 1000000, true, false, false, true, false, false)
        None => ([], [], 1000000, true, false, false, true, false, false)
      }
    } else {
      let def_idx = abs - imports
      let func = match mod_.code_sec {
        Some(@lib.CodeSec(funcs)) => funcs[def_idx]
        None => abort("missing code section for inlining info")
      }
      let @lib.Func(_, @lib.Expr(body)) = func
      let (calls, loops, tries, tails, measured_size) = match
        body_measure_cache {
        Some(cache) => cache.measure(abs, body)
        None => inl_measure_body(body)
      }
      match
        @ir.hot_module_resolve_func_type(
          module_ctx,
          @lib.FuncIdx::new(abs.reinterpret_as_uint()),
        ) {
        Some(@lib.FuncType(params, results)) => {
          let partial_wrapper = abs >= 0 &&
            abs < partial_wrappers.length() &&
            partial_wrappers[abs]
          let no_full_policy = abs >= 0 &&
            abs < no_full_inline.length() &&
            no_full_inline[abs] &&
            !partial_wrapper
          let toolchain_inline_hint = if abs >= 0 &&
            abs < toolchain_inline_hints.length() {
            toolchain_inline_hints[abs]
          } else {
            InlToolchainInlineHint::DefaultInline
          }
          let one_caller_size_ok = one_caller_inline_max_size < 0 ||
            measured_size <= one_caller_inline_max_size
          let hint_requires_classification = match toolchain_inline_hint {
            DefaultInline =>
              measured_size > always_inline_max_size &&
              !(refs[abs] == 1 && !used[abs] && one_caller_size_ok)
            NeverInline => false
            AlwaysInline => false
          }
          let classification_required = !partial_wrapper &&
            !no_full_policy &&
            hint_requires_classification
          let (trivial_shrinks, trivial_may_not_shrink) = if !classification_required {
            (false, false)
          } else {
            let cached_modes : (Bool, Bool)? = match trivial_mode_cache {
              Some(cache) =>
                if abs >= 0 && abs < cache.length() {
                  cache[abs]
                } else {
                  None
                }
              None => None
            }
            match cached_modes {
              Some(modes) => modes
              None => {
                let raw_trivial_shrinks = inl_body_is_shrinking_trivial(
                  body,
                  params.length(),
                  mod_~,
                  func_type_indices=types,
                )
                let modes = if raw_trivial_shrinks {
                  match classification_counts {
                    Some(counts) => counts[0] += 1
                    None => ()
                  }
                  (true, false)
                } else {
                  match
                    inl_flat_trivial_instruction_modes(
                      body,
                      params.length(),
                      mod_,
                      types,
                    ) {
                    Some(modes) => {
                      match classification_counts {
                        Some(counts) => counts[1] += 1
                        None => ()
                      }
                      modes
                    }
                    None => {
                      match classification_counts {
                        Some(counts) => counts[2] += 1
                        None => ()
                      }
                      inl_hot_trivial_instruction_modes(
                        mod_, abs, module_ctx, measured_size,
                      )
                    }
                  }
                }
                match trivial_mode_cache {
                  Some(cache) =>
                    if abs >= 0 && abs < cache.length() {
                      cache[abs] = Some(modes)
                    }
                  None => ()
                }
                modes
              }
            }
          }
          (
            params, results, measured_size, calls, loops, tries, tails, trivial_shrinks,
            trivial_may_not_shrink,
          )
        }
        None => ([], [], 1000000, true, false, true, true, false, false)
      }
    }
    let func_type_idx = if abs >= 0 && abs < types.length() {
      Some(types[abs])
    } else {
      None
    }
    let type_idx = if results.length() <= 1 {
      None
    } else if params.length() == 0 {
      func_type_idx
    } else {
      inl_find_zero_param_result_type(mod_, results)
    }
    let block_type_ok = inl_result_block_type(results, type_idx) is Some(_)
    let partial_wrapper = abs >= 0 &&
      abs < partial_wrappers.length() &&
      partial_wrappers[abs]
    let no_full_policy = abs >= 0 &&
      abs < no_full_inline.length() &&
      no_full_inline[abs] &&
      !partial_wrapper
    let toolchain_inline_hint = if abs >= 0 &&
      abs < toolchain_inline_hints.length() {
      toolchain_inline_hints[abs]
    } else {
      InlToolchainInlineHint::DefaultInline
    }
    let speed_focused = optimize_level >= 3 && shrink_level == 0
    let one_caller_size_ok = one_caller_inline_max_size < 0 ||
      size <= one_caller_inline_max_size
    let profitable = if partial_wrapper {
      true
    } else {
      match toolchain_inline_hint {
        NeverInline => false
        AlwaysInline => true
        DefaultInline =>
          if size <= always_inline_max_size {
            true
          } else if refs[abs] == 1 && !used[abs] && one_caller_size_ok {
            true
          } else if trivial_shrinks {
            true
          } else if size > flexible_inline_max_size || !speed_focused {
            false
          } else if trivial_may_not_shrink {
            true
          } else {
            !has_calls && (!has_loops || allow_functions_with_loops)
          }
      }
    }
    let inlineable = abs >= imports &&
      !no_full_policy &&
      block_type_ok &&
      profitable
    ignore(has_return_call)
    infos.push({
      params,
      results,
      type_idx,
      size,
      max_combined_binary_size,
      direct_targets: if abs >= 0 && abs < direct_targets_by_func.length() {
        direct_targets_by_func[abs]
      } else {
        []
      },
      inlineable,
    })
    abs += 1
  }
  infos
}

///|
fn inl_allocate_reusable_scratch_local_reference(
  local_type : @lib.ValType,
  pool_types : Array[@lib.ValType],
  pool_used : Array[Bool],
  next_locals : @lib.Locals,
  absolute_pool_base : Int,
) -> Int {
  for slot = 0; slot < pool_types.length(); slot = slot + 1 {
    if !pool_used[slot] && pool_types[slot] == local_type {
      pool_used[slot] = true
      return absolute_pool_base + slot
    }
  }
  let slot = pool_types.length()
  pool_types.push(local_type)
  pool_used.push(true)
  next_locals.append_types([local_type])
  absolute_pool_base + slot
}

///|
fn inl_planning_setup_bench(
  it : @bench.T,
  count : Int,
  reference : Bool,
) -> Unit {
  let seed = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) local.get 0 i32.const 1 i32.add))",
  )
  let mod_ = seed
    .with_func_sec(
      @lib.FuncSec::new(Array::make(count, seed.func_sec.unwrap().0[0])),
    )
    .with_code_sec(
      @lib.CodeSec::new(Array::make(count, seed.code_sec.unwrap().0[0])),
    )
  @validate.validate_module(mod_).unwrap()
  let expected = inl_build_function_infos_reference(mod_)
  let actual = inl_build_function_infos(mod_)
  if expected.length() != actual.length() {
    abort("inlining planner changed function count")
  }
  for index = 0; index < expected.length(); index = index + 1 {
    let old = expected[index]
    let next = actual[index]
    if old.params != next.params ||
      old.results != next.results ||
      old.type_idx != next.type_idx ||
      old.size != next.size ||
      old.max_combined_binary_size != next.max_combined_binary_size ||
      old.direct_targets != next.direct_targets ||
      old.inlineable != next.inlineable {
      abort("inlining planner changed function facts")
    }
  }
  it.bench(fn() {
    it.keep(
      if reference {
        inl_build_function_infos_reference(mod_)
      } else {
        inl_build_function_infos(mod_)
      },
    )
  })
}

///|
fn inl_scratch_cursor_bench(
  it : @bench.T,
  count : Int,
  mixed : Bool,
  reference : Bool,
) -> Unit {
  let types = Array::makei(count, fn(index) {
    if mixed && index % 2 == 0 {
      @lib.ValType::i64()
    } else {
      @lib.ValType::i32()
    }
  })
  let used = Array::make(count, false)
  let next = [0]
  let locals = @lib.Locals::empty()
  let run = fn(old) {
    for slot = 0; slot < used.length(); slot = slot + 1 {
      used[slot] = false
    }
    next[0] = 0
    for index = 0; index < count; index = index + 1 {
      let slot = if old {
        inl_allocate_reusable_scratch_local_reference(
          types[index],
          types,
          used,
          locals,
          3,
        )
      } else {
        inl_allocate_reusable_scratch_local(
          types[index],
          types,
          used,
          locals,
          3,
          first_unused=Some(next),
        )
      }
      if slot != index + 3 {
        abort("scratch cursor changed first compatible slot")
      }
    }
  }
  run(true)
  run(false)
  if locals.length() != 0 {
    abort("scratch cursor allocated extra locals")
  }
  it.bench(fn() {
    run(reference)
    it.keep(used)
  })
}

///|
test "bench inlining planning count=16 reference" (it : @bench.T) {
  inl_planning_setup_bench(it, 16, true)
}

///|
test "bench inlining planning count=16 lazy" (it : @bench.T) {
  inl_planning_setup_bench(it, 16, false)
}

///|
test "bench inlining scratch count=16 uniform reference" (it : @bench.T) {
  inl_scratch_cursor_bench(it, 16, false, true)
}

///|
test "bench inlining scratch count=16 uniform cursor" (it : @bench.T) {
  inl_scratch_cursor_bench(it, 16, false, false)
}

///|
test "bench inlining scratch count=16 mixed reference" (it : @bench.T) {
  inl_scratch_cursor_bench(it, 16, true, true)
}

///|
test "bench inlining scratch count=16 mixed cursor" (it : @bench.T) {
  inl_scratch_cursor_bench(it, 16, true, false)
}

///|
test "bench inlining planning count=128 reference" (it : @bench.T) {
  inl_planning_setup_bench(it, 128, true)
}

///|
test "bench inlining planning count=128 lazy" (it : @bench.T) {
  inl_planning_setup_bench(it, 128, false)
}

///|
test "bench inlining scratch count=128 uniform reference" (it : @bench.T) {
  inl_scratch_cursor_bench(it, 128, false, true)
}

///|
test "bench inlining scratch count=128 uniform cursor" (it : @bench.T) {
  inl_scratch_cursor_bench(it, 128, false, false)
}

///|
test "bench inlining scratch count=128 mixed reference" (it : @bench.T) {
  inl_scratch_cursor_bench(it, 128, true, true)
}

///|
test "bench inlining scratch count=128 mixed cursor" (it : @bench.T) {
  inl_scratch_cursor_bench(it, 128, true, false)
}

///|
test "bench inlining planning count=1024 reference" (it : @bench.T) {
  inl_planning_setup_bench(it, 1024, true)
}

///|
test "bench inlining planning count=1024 lazy" (it : @bench.T) {
  inl_planning_setup_bench(it, 1024, false)
}

///|
test "bench inlining scratch count=1024 uniform reference" (it : @bench.T) {
  inl_scratch_cursor_bench(it, 1024, false, true)
}

///|
test "bench inlining scratch count=1024 uniform cursor" (it : @bench.T) {
  inl_scratch_cursor_bench(it, 1024, false, false)
}

///|
test "bench inlining scratch count=1024 mixed reference" (it : @bench.T) {
  inl_scratch_cursor_bench(it, 1024, true, true)
}

///|
test "bench inlining scratch count=1024 mixed cursor" (it : @bench.T) {
  inl_scratch_cursor_bench(it, 1024, true, false)
}
