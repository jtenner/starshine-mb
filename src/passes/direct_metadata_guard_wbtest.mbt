///|
fn direct_metadata_guard_add_offset_metadata(mod_ : @lib.Module) -> @lib.Module {
  mod_.with_custom_secs([
    @lib.CustomSec::new(
      @lib.Name::from_string("metadata.code.direct-entrypoint-test"),
      b"opaque-code-offsets",
    ),
  ])
}

///|
fn direct_metadata_guard_assert_mutates_then_stops(
  input : @lib.Module,
  run : (@lib.Module) -> @lib.Module,
) -> Unit raise {
  assert_true(run(input) != input)
  let guarded = direct_metadata_guard_add_offset_metadata(input)
  @debug.assert_eq(run(guarded), guarded)
}

///|
test "offset metadata detector guards object relocation and external debug families" {
  for
    section_name in [
      "reloc.DATA", "linking", "sourceMappingURL", "external_debug_info",
    ] {
    let module_ = @lib.Module::new(custom_secs=[
      @lib.CustomSec::new(
        @lib.Name::from_string(section_name),
        b"opaque-object-metadata",
      ),
    ])
    assert_true(pass_module_has_offset_sensitive_metadata(module_))
    assert_true(oi_local_group_has_offset_metadata(module_))
  }
}

///|
test "local branch-hint spelling is not offset-bearing code metadata" {
  let annotations = @lib.FuncAnnotationSec::new([
    @lib.FuncAnnotationAssoc::new(0U, [
      @lib.FuncAnnotation::new("metadata.code.branch_hint", args=["\"\\01\""]),
    ]),
  ])
  let module_ = pass_test_module_from_wat(
    "(module (func (result i32) nop i32.const 7))",
  ).with_func_annotation_sec(annotations)
  assert_false(pass_module_has_offset_sensitive_metadata(module_))
  assert_false(oi_local_group_has_offset_metadata(module_))
  let optimized = run_hot_pipeline(module_, HotPipelineOptions::new(), [
    "vacuum",
  ]).unwrap()
  assert_true(optimized != module_)
}

///|
test "direct avoid-reinterprets and untee preserve offset metadata" {
  let avoid_input = pass_test_module_from_wat(
    "(module (memory 1) (func (param i32) (result i32) local.get 0 f32.load i32.reinterpret_f32))",
  )
  direct_metadata_guard_assert_mutates_then_stops(
    avoid_input, avoid_reinterprets_run_module_pass,
  )

  let untee_input = pass_test_module_from_wat(
    "(module (func (result i32) (local i32) i32.const 7 local.tee 0))",
  )
  direct_metadata_guard_assert_mutates_then_stops(
    untee_input, untee_run_module_pass,
  )
}

///|
test "direct local rewrites preserve offset metadata" {
  let coalesce_input = pass_test_module_from_wat(
    (
      #| (module
      #|   (func (result i32) (local i32 i32)
      #|     i32.const 11
      #|     local.set 0
      #|     local.get 0
      #|     drop
      #|     i32.const 22
      #|     local.set 1
      #|     local.get 1))
      #|
    ),
  )
  direct_metadata_guard_assert_mutates_then_stops(
    coalesce_input, coalesce_locals_run_module_pass,
  )

  let cse_input = pass_test_module_from_wat(
    (
      #| (module
      #|   (func (param i32 i32)
      #|     local.get 0 local.get 1 i32.add drop
      #|     local.get 0 local.get 1 i32.add drop))
      #|
    ),
  )
  direct_metadata_guard_assert_mutates_then_stops(
    cse_input, local_cse_run_module_pass,
  )

  let subtype_input = pass_test_module_from_wat(
    "(module (func (result i32) i32.const 42 return i32.const 99 drop))",
  )
  direct_metadata_guard_assert_mutates_then_stops(
    subtype_input, local_subtyping_run_module_pass,
  )

  let reorder_input = pass_test_module_from_wat(
    (
      #| (module
      #|   (type (func (param i32)))
      #|   (func (type 0) (param i32))
      #|   (func (type 0) (param i32) (local i32 i32)
      #|     i32.const 10 local.set 1
      #|     local.get 1 call 0
      #|     i32.const 20 local.set 2
      #|     local.get 2 drop
      #|     local.get 2 call 0))
      #|
    ),
  )
  direct_metadata_guard_assert_mutates_then_stops(
    reorder_input, reorder_locals_run_module_pass,
  )
}

///|
test "direct memory packing and once reduction preserve offset metadata" {
  let packing_input = pass_test_module_from_wat(
    "(module (memory 1) (data (i32.const 0) \"\\00\\00\\00\\00\\00\\00\\00\\00\\00ABC\"))",
  )
  direct_metadata_guard_assert_mutates_then_stops(packing_input, fn(
    mod_ : @lib.Module,
  ) {
    memory_packing_run_module_pass(mod_)
  })

  let once_input = pass_test_module_from_wat(
    (
      #| (module
      #|   (global $g (mut i32) (i32.const 0))
      #|   (func $once
      #|     global.get $g
      #|     if return end
      #|     i32.const 1
      #|     global.set $g)
      #|   (func (export "run")
      #|     call $once
      #|     call $once))
      #|
    ),
  )
  direct_metadata_guard_assert_mutates_then_stops(
    once_input, once_reduction_run_module_pass,
  )
}

///|
test "direct global struct inference variants preserve offset metadata" {
  let inference_input = pass_test_module_from_wat(
    "(module (func (drop (unreachable)) (unreachable)))",
  )
  direct_metadata_guard_assert_mutates_then_stops(inference_input, fn(
    mod_ : @lib.Module,
  ) {
    global_struct_inference_run_module_pass(mod_, false)
  })

  direct_metadata_guard_assert_mutates_then_stops(inference_input, fn(
    mod_ : @lib.Module,
  ) {
    global_struct_inference_desc_cast_run_module_pass(mod_, true)
  })
}

///|
test "direct RUME guards all object relocation metadata" {
  let base = pass_test_module_from_wat(
    "(module (func) (func (export \"live\")))",
  )
  assert_true(rume_run_module_pass(base) != base)
  for section_name in ["reloc.DATA", "linking"] {
    let guarded = base.with_custom_secs([
      @lib.CustomSec::new(
        @lib.Name::from_string(section_name),
        b"opaque-object-offsets",
      ),
    ])
    @debug.assert_eq(rume_run_module_pass(guarded), guarded)
    @debug.assert_eq(rume_run_nonfunction_module_pass(guarded), guarded)
  }
}

///|
test "direct strip-debug remains allowed with offset metadata" {
  let input = direct_metadata_guard_add_offset_metadata(
    pass_test_module_from_wat("(module (func))").with_raw_name_sec_payload(
      b"opaque-name-section",
    ),
  )
  let output = strip_debug_run_module_pass(input)
  @debug.assert_eq(output.custom_secs, input.custom_secs)
  @debug.assert_eq(output.code_sec, input.code_sec)
  @debug.assert_eq(output.raw_name_sec_payload, None)
  let dispatched = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "strip-debug",
  ]).unwrap()
  @debug.assert_eq(dispatched.custom_secs, input.custom_secs)
  @debug.assert_eq(dispatched.code_sec, input.code_sec)
  @debug.assert_eq(dispatched.raw_name_sec_payload, None)
}

///|
test "direct compiler-fact application preserves unrelated offset metadata" {
  let facts = @representation.CompilerFactCustomSection::new(
    @representation.OptimizationFactsSec::new(),
  )
  let base = pass_test_module_from_wat("(module (func))").with_compiler_fact_custom_section(
    facts,
  )
  let applied = apply_compiler_facts(
    base,
    CompilerFactUsePolicy::trust_assertions(),
  ).unwrap()
  assert_true(applied.module_ != base)
  let guarded = direct_metadata_guard_add_offset_metadata(base)
  @debug.assert_eq(
    apply_compiler_facts(guarded, CompilerFactUsePolicy::trust_assertions()).unwrap().module_,
    guarded,
  )
  let hints_only = apply_compiler_facts(
    guarded,
    CompilerFactUsePolicy::hints_only(),
  ).unwrap()
  @debug.assert_eq(hints_only.module_, guarded)
  @debug.assert_eq(hints_only.stats.fact_sections_seen, 1)
}

///|
test "direct O4z transforms preserve offset metadata" {
  let canonical_base = pass_test_module_from_wat(
    "(module (func (result i32) i32.const 42 return))",
  )
  assert_true(
    o4z_canonicalize_final_size_candidate(canonical_base) != canonical_base,
  )
  let canonical_guarded = direct_metadata_guard_add_offset_metadata(
    canonical_base,
  )
  @debug.assert_eq(
    o4z_canonicalize_final_size_candidate(canonical_guarded),
    canonical_guarded,
  )
  @debug.assert_eq(
    o4z_canonicalize_final_size_candidate_with_changed(canonical_guarded),
    (canonical_guarded, false),
  )
  @debug.assert_eq(
    o4z_canonicalize_final_size_store_carries(canonical_guarded),
    canonical_guarded,
  )
  @debug.assert_eq(
    o4z_canonicalize_final_size_ifs_stateful_candidate(canonical_guarded),
    canonical_guarded,
  )
  @debug.assert_eq(
    o4z_prune_final_size_unreferenced_globals(canonical_guarded),
    canonical_guarded,
  )

  let outline_base = pass_test_module_from_wat(
    (
      #| (module
      #|   (func (result i64)
      #|     nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|     i64.const 42)
      #|   (func (result i64)
      #|     nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop nop
      #|     i64.const 43))
      #|
    ),
  )
  assert_true(o4z_outline_similar_size_functions(outline_base) != outline_base)
  let outline_guarded = direct_metadata_guard_add_offset_metadata(outline_base)
  @debug.assert_eq(
    o4z_outline_similar_size_functions(outline_guarded),
    outline_guarded,
  )
  @debug.assert_eq(
    o4z_restore_optimized_primes_variadic_pack_funcs(
      outline_base, outline_guarded,
    ),
    outline_guarded,
  )
}

///|
test "O4z branch hints do not bypass other offset metadata guards" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) i32.const 42 return))",
  ).with_custom_secs([
    @lib.CustomSec::new(
      @lib.Name::from_string("metadata.code.branch_hint"),
      b"hint",
    ),
    @lib.CustomSec::new(
      @lib.Name::from_string("reloc.CODE"),
      b"opaque-offsets",
    ),
  ])
  @debug.assert_eq(o4z_canonicalize_final_size_candidate(input), input)
  @debug.assert_eq(
    o4z_canonicalize_final_size_candidate_with_changed(input),
    (input, false),
  )
}
