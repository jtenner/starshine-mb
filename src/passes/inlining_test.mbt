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
fn inl_test_run_named(
  text : String,
  names : Array[(UInt, String)],
  passes : Array[String],
) -> @lib.Module {
  let entries : Array[@lib.NameAssoc] = []
  for pair in names {
    let (idx, name) = pair
    entries.push(@lib.NameAssoc::new(idx, @lib.Name::from_string(name)))
  }
  let mod_ = pass_test_module_from_wat(text).with_name_sec(
    @lib.NameSec::new(func_names=Some(@lib.NameMap::new(entries))),
  )
  match run_hot_pipeline(mod_, HotPipelineOptions::new(), passes) {
    Ok(mod_) => mod_
    Err(err) => abort("expected named inlining pipeline success, got \{err}")
  }
}

///|
fn inl_test_count_func_annotation(
  mod_ : @lib.Module,
  target : UInt,
  name : String,
) -> Int {
  let mut count = 0
  match mod_.func_annotation_sec {
    Some(@lib.FuncAnnotationSec(entries)) =>
      for entry in entries {
        let @lib.FuncAnnotationAssoc(idx, annotations) = entry
        if idx == target {
          for annotation in annotations {
            if annotation.name == name {
              count += 1
            }
          }
        }
      }
    None => ()
  }
  count
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
  @debug.assert_eq(
    pass_registry_category("no-inline"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("no-full-inline"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("no-partial-inline"),
    Some(HotPassRegistryCategory::module_pass()),
  )
}

///|
test "no-inline wildcard blocks later full inlining for matching function names" {
  let source =
    #|(module
    #|  (type $t0 (func (result i32)))
    #|  (func $tiny-maybe-inline (type $t0)
    #|    i32.const 7)
    #|  (func (export "run") (result i32)
    #|    call $tiny-maybe-inline))
  let optimized = inl_test_run_named(
    source,
    [(0U, "tiny-maybe-inline"), (1U, "run")],
    ["no-inline=*maybe*", "inlining"],
  )
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected function section")
  }
  let run = optimized.pretty_print_defined_func(1U)
  assert_true(run.contains("call (Func 0)"), msg=run)
}

///|
test "no-inline wildcard matches WAT function identifiers after lowering" {
  let source =
    #|(module
    #|  (type $t0 (func (result i32)))
    #|  (func $tiny-maybe-inline (type $t0)
    #|    i32.const 7)
    #|  (func $run (export "run") (result i32)
    #|    call $tiny-maybe-inline))
  let optimized = match
    pass_test_run_pipeline(source, ["no-inline=*maybe*", "inlining"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected no-inline/inlining success, got \{err}")
  }
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected function section")
  }
}

///|
test "no-full-inline blocks full inlining but no-partial-inline does not" {
  let source =
    #|(module
    #|  (type $t0 (func (result i32)))
    #|  (func $full-maybe-inline (type $t0)
    #|    i32.const 9)
    #|  (func (export "run") (result i32)
    #|    call $full-maybe-inline))
  let no_full = inl_test_run_named(
    source,
    [(0U, "full-maybe-inline"), (1U, "run")],
    ["no-full-inline=*maybe*", "inlining"],
  )
  match no_full.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected function section")
  }
  let no_partial = inl_test_run_named(
    source,
    [(0U, "full-maybe-inline"), (1U, "run")],
    ["no-partial-inline=*maybe*", "inlining"],
  )
  match no_partial.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
}

///|
test "no-inline annotations follow surviving functions after inlining compacts helpers" {
  let source =
    #|(module
    #|  (type $t0 (func (result i32)))
    #|  (func $inline-me (type $t0)
    #|    i32.const 1)
    #|  (func $protected (type $t0)
    #|    i32.const 2)
    #|  (func $run (export "run") (result i32)
    #|    call $inline-me
    #|    drop
    #|    call $protected))
  let optimized = match
    pass_test_run_pipeline(source, [
      "no-inline=protected", "inlining", "inlining",
    ]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected repeated no-inline/inlining success, got \{err}")
  }
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected function section")
  }
  let run = optimized.pretty_print_defined_func(1U)
  assert_true(run.contains("i32.const I32(1)"), msg=run)
  assert_true(run.contains("call (Func 0)"), msg=run)
}

///|
test "inlining remaps surviving WAT function names after helper compaction" {
  let source =
    #|(module
    #|  (type $t0 (func (result i32)))
    #|  (func $inline-me (type $t0)
    #|    i32.const 1)
    #|  (func $survivor (export "survivor") (type $t0)
    #|    i32.const 2)
    #|  (func $run (export "run") (result i32)
    #|    call $inline-me))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected function section")
  }
  match optimized.name_sec {
    Some(name_sec) =>
      match name_sec.func_names {
        Some(
          @lib.NameMap(
            [
              @lib.NameAssoc(0U, @lib.Name("survivor")),
              @lib.NameAssoc(1U, @lib.Name("run")),
            ]
          )
        ) => ()
        other =>
          fail(
            "expected remapped survivor/run function names, got \{@debug.to_string(other)}",
          )
      }
    None => fail("expected remapped name section")
  }
}

///|
test "no-inline can match surviving names after prior inlining compaction" {
  let source =
    #|(module
    #|  (type $t0 (func (result i32)))
    #|  (func $inline-me (type $t0)
    #|    i32.const 1)
    #|  (func $survivor (export "survivor") (type $t0)
    #|    i32.const 2)
    #|  (func $run (export "run") (result i32)
    #|    call $inline-me))
  let marked = match
    pass_test_run_pipeline(source, ["inlining", "no-inline=survivor"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected post-inlining no-inline success, got \{err}")
  }
  @debug.assert_eq(
    inl_test_count_func_annotation(marked, 0U, "starshine.no-full-inline"),
    1,
  )
  @debug.assert_eq(
    inl_test_count_func_annotation(marked, 0U, "starshine.no-partial-inline"),
    1,
  )
}

///|
test "inlining keeps function names but drops function-scoped local names after compaction" {
  let source =
    #|(module
    #|  (type $t0 (func (result i32)))
    #|  (func $inline-me (type $t0)
    #|    i32.const 1)
    #|  (func $survivor (export "survivor") (type $t0)
    #|    i32.const 2)
    #|  (func $run (export "run") (result i32)
    #|    call $inline-me))
  let input = pass_test_module_from_wat(source).with_name_sec(
    @lib.NameSec::new(
      func_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(0U, @lib.Name::from_string("inline-me")),
          @lib.NameAssoc::new(1U, @lib.Name::from_string("survivor")),
          @lib.NameAssoc::new(2U, @lib.Name::from_string("run")),
        ]),
      ),
      local_names=Some(
        @lib.IndirectNameMap::new([
          @lib.IndirectNameAssoc::new(
            1U,
            @lib.NameMap::new([
              @lib.NameAssoc::new(0U, @lib.Name::from_string("stale-local")),
            ]),
          ),
        ]),
      ),
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["inlining"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected inlining success, got \{err}")
  }
  match optimized.name_sec {
    Some(name_sec) => {
      match name_sec.func_names {
        Some(
          @lib.NameMap(
            [
              @lib.NameAssoc(0U, @lib.Name("survivor")),
              @lib.NameAssoc(1U, @lib.Name("run")),
            ]
          )
        ) => ()
        other =>
          fail(
            "expected remapped function names, got \{@debug.to_string(other)}",
          )
      }
      match name_sec.local_names {
        None => ()
        other =>
          fail(
            "expected local names to be dropped, got \{@debug.to_string(other)}",
          )
      }
    }
    None => fail("expected name section with remapped function names")
  }
}

///|
test "no-inline clone-survival helper copies policy markers to appended clones" {
  let source =
    #|(module
    #|  (type $t0 (func (result i32)))
    #|  (func $source-noinline (type $t0)
    #|    i32.const 7)
    #|  (func $clone-noinline (type $t0)
    #|    i32.const 7)
    #|  (func $run (export "run") (result i32)
    #|    call $clone-noinline))
  let marked_source = match
    pass_test_run_pipeline(source, ["no-inline=source-*"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected source no-inline success, got \{err}")
  }
  @debug.assert_eq(
    inl_test_count_func_annotation(
      marked_source, 0U, "starshine.no-full-inline",
    ),
    1,
  )
  @debug.assert_eq(
    inl_test_count_func_annotation(
      marked_source, 1U, "starshine.no-full-inline",
    ),
    0,
  )
  let marked_clone = no_inline_copy_policy_annotations(marked_source, 0U, 1U)
  @debug.assert_eq(
    inl_test_count_func_annotation(marked_clone, 1U, "starshine.no-full-inline"),
    1,
  )
  @debug.assert_eq(
    inl_test_count_func_annotation(
      marked_clone, 1U, "starshine.no-partial-inline",
    ),
    1,
  )
  let optimized = match
    run_hot_pipeline(marked_clone, HotPipelineOptions::new(), ["inlining"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected inlining with copied policy success, got \{err}")
  }
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 3)
    None => fail("expected function section")
  }
  let run = optimized.pretty_print_defined_func(2U)
  assert_true(run.contains("call (Func 1)"), msg=run)
}

///|
test "no-inline repeated wildcard policy deduplicates full and partial markers" {
  let source =
    #|(module
    #|  (type $t0 (func (result i32)))
    #|  (func $tiny-target (type $t0)
    #|    i32.const 5)
    #|  (func $run (export "run") (result i32)
    #|    call $tiny-target))
  let marked = match
    pass_test_run_pipeline(source, ["no-inline=tiny*", "no-inline=tiny*"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected repeated no-inline success, got \{err}")
  }
  @debug.assert_eq(
    inl_test_count_func_annotation(marked, 0U, "starshine.no-full-inline"),
    1,
  )
  @debug.assert_eq(
    inl_test_count_func_annotation(marked, 0U, "starshine.no-partial-inline"),
    1,
  )
}

///|
test "no-inline wildcard policy marks imported WAT function identifiers" {
  let source =
    #|(module
    #|  (type $t0 (func (result i32)))
    #|  (import "env" "imported" (func $imported-helper (type $t0)))
    #|  (func $run (export "run") (result i32)
    #|    call $imported-helper))
  let marked = match
    pass_test_run_pipeline(source, ["no-full-inline=*helper"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected imported no-inline success, got \{err}")
  }
  @debug.assert_eq(
    inl_test_count_func_annotation(marked, 0U, "starshine.no-full-inline"),
    1,
  )
  @debug.assert_eq(
    inl_test_count_func_annotation(marked, 0U, "starshine.no-partial-inline"),
    0,
  )
}

///|
test "no-inline no-match policy leaves annotation section absent" {
  let source =
    #|(module
    #|  (type $t0 (func (result i32)))
    #|  (func $tiny-target (type $t0)
    #|    i32.const 5)
    #|  (func $run (export "run") (result i32)
    #|    call $tiny-target))
  let marked = match pass_test_run_pipeline(source, ["no-inline=missing*"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected no-match no-inline success, got \{err}")
  }
  match marked.func_annotation_sec {
    None => ()
    Some(sec) => fail("expected no policy annotations for no-match, got \{sec}")
  }
}

///|
test "function inline hint metadata does not act as no-inline policy" {
  let source =
    #|(module
    #|  (type $t0 (func (result i32)))
    #|  (@metadata.code.inline "\\00")
    #|  (func $hinted (type $t0)
    #|    i32.const 11)
    #|  (func (export "run") (result i32)
    #|    call $hinted))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
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
test "inlining treats repeated parameter passthrough binary wrappers as shrinking trivial" {
  let source =
    #|(module
    #|  (func $add (param i32 i32) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    i32.add)
    #|  (func (export "run") (param i32 i32) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    call $add
    #|    local.get 1
    #|    local.get 0
    #|    call $add
    #|    i32.add))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("i32.add"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
}

///|
test "inlining covers repeated parameter passthrough unary wrappers via tiny eligibility" {
  let source =
    #|(module
    #|  (func $iszero (param i32) (result i32)
    #|    local.get 0
    #|    i32.eqz)
    #|  (func (export "run") (param i32 i32) (result i32)
    #|    local.get 0
    #|    call $iszero
    #|    local.get 1
    #|    call $iszero
    #|    i32.add))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("i32.eqz"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
}

///|
test "inlining treats repeated parameter passthrough select wrappers as shrinking trivial" {
  let source =
    #|(module
    #|  (func $choose (param i32 i32 i32) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    select)
    #|  (func (export "run") (param i32 i32 i32) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    call $choose
    #|    local.get 1
    #|    local.get 0
    #|    local.get 2
    #|    call $choose
    #|    i32.add))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("select"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
}

///|
test "inlining treats repeated parameter passthrough i32.store wrappers as shrinking trivial" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $store (param i32 i32)
    #|    local.get 0
    #|    local.get 1
    #|    i32.store)
    #|  (func (export "run") (param i32 i32)
    #|    local.get 0
    #|    local.get 1
    #|    call $store
    #|    local.get 0
    #|    local.get 1
    #|    call $store))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("i32.store"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
}

///|
test "inlining treats repeated parameter passthrough i64.store wrappers as shrinking trivial" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $store (param i32 i64)
    #|    local.get 0
    #|    local.get 1
    #|    i64.store)
    #|  (func (export "run") (param i32 i64)
    #|    local.get 0
    #|    local.get 1
    #|    call $store
    #|    local.get 0
    #|    local.get 1
    #|    call $store))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("i64.store"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
}

///|
test "inlining treats repeated parameter passthrough f32.store wrappers as shrinking trivial" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $store (param i32 f32)
    #|    local.get 0
    #|    local.get 1
    #|    f32.store)
    #|  (func (export "run") (param i32 f32)
    #|    local.get 0
    #|    local.get 1
    #|    call $store
    #|    local.get 0
    #|    local.get 1
    #|    call $store))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("f32.store"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
}

///|
test "inlining treats repeated parameter passthrough f64.store wrappers as shrinking trivial" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $store (param i32 f64)
    #|    local.get 0
    #|    local.get 1
    #|    f64.store)
    #|  (func (export "run") (param i32 f64)
    #|    local.get 0
    #|    local.get 1
    #|    call $store
    #|    local.get 0
    #|    local.get 1
    #|    call $store))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("f64.store"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
}

///|
test "inlining treats repeated parameter passthrough i32.store8 wrappers as shrinking trivial" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $store (param i32 i32)
    #|    local.get 0
    #|    local.get 1
    #|    i32.store8)
    #|  (func (export "run") (param i32 i32)
    #|    local.get 0
    #|    local.get 1
    #|    call $store
    #|    local.get 0
    #|    local.get 1
    #|    call $store))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("i32.store8"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
}

///|
test "inlining treats repeated parameter passthrough i32.store16 wrappers as shrinking trivial" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $store (param i32 i32)
    #|    local.get 0
    #|    local.get 1
    #|    i32.store16)
    #|  (func (export "run") (param i32 i32)
    #|    local.get 0
    #|    local.get 1
    #|    call $store
    #|    local.get 0
    #|    local.get 1
    #|    call $store))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("i32.store16"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
}

///|
test "inlining treats repeated parameter passthrough i64.store8 wrappers as shrinking trivial" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $store (param i32 i64)
    #|    local.get 0
    #|    local.get 1
    #|    i64.store8)
    #|  (func (export "run") (param i32 i64)
    #|    local.get 0
    #|    local.get 1
    #|    call $store
    #|    local.get 0
    #|    local.get 1
    #|    call $store))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("i64.store8"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
}

///|
test "inlining treats repeated parameter passthrough i64.store16 wrappers as shrinking trivial" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $store (param i32 i64)
    #|    local.get 0
    #|    local.get 1
    #|    i64.store16)
    #|  (func (export "run") (param i32 i64)
    #|    local.get 0
    #|    local.get 1
    #|    call $store
    #|    local.get 0
    #|    local.get 1
    #|    call $store))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("i64.store16"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
}

///|
test "inlining treats repeated parameter passthrough i64.store32 wrappers as shrinking trivial" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $store (param i32 i64)
    #|    local.get 0
    #|    local.get 1
    #|    i64.store32)
    #|  (func (export "run") (param i32 i64)
    #|    local.get 0
    #|    local.get 1
    #|    call $store
    #|    local.get 0
    #|    local.get 1
    #|    call $store))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("i64.store32"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
}

///|
test "inlining treats repeated parameter passthrough v128.store wrappers as shrinking trivial" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $store (param i32 v128)
    #|    local.get 0
    #|    local.get 1
    #|    v128.store)
    #|  (func (export "run") (param i32 v128)
    #|    local.get 0
    #|    local.get 1
    #|    call $store
    #|    local.get 0
    #|    local.get 1
    #|    call $store))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("v128.store"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
}

///|
test "inlining treats repeated parameter passthrough v128.store8_lane wrappers as shrinking trivial" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $store (param i32 v128)
    #|    local.get 0
    #|    local.get 1
    #|    v128.store8_lane 3)
    #|  (func (export "run") (param i32 v128)
    #|    local.get 0
    #|    local.get 1
    #|    call $store
    #|    local.get 0
    #|    local.get 1
    #|    call $store))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("v128.store8_lane"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
}

///|
test "inlining treats repeated parameter passthrough v128.store16_lane wrappers as shrinking trivial" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $store (param i32 v128)
    #|    local.get 0
    #|    local.get 1
    #|    v128.store16_lane 3)
    #|  (func (export "run") (param i32 v128)
    #|    local.get 0
    #|    local.get 1
    #|    call $store
    #|    local.get 0
    #|    local.get 1
    #|    call $store))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("v128.store16_lane"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
}

///|
test "inlining treats repeated parameter passthrough v128.store32_lane wrappers as shrinking trivial" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $store (param i32 v128)
    #|    local.get 0
    #|    local.get 1
    #|    v128.store32_lane 3)
    #|  (func (export "run") (param i32 v128)
    #|    local.get 0
    #|    local.get 1
    #|    call $store
    #|    local.get 0
    #|    local.get 1
    #|    call $store))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("v128.store32_lane"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
}

///|
test "inlining treats repeated parameter passthrough v128.store64_lane wrappers as shrinking trivial" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $store (param i32 v128)
    #|    local.get 0
    #|    local.get 1
    #|    v128.store64_lane 1)
    #|  (func (export "run") (param i32 v128)
    #|    local.get 0
    #|    local.get 1
    #|    call $store
    #|    local.get 0
    #|    local.get 1
    #|    call $store))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("v128.store64_lane"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
}

///|
test "inlining treats repeated parameter passthrough table.set wrappers as shrinking trivial" {
  let source =
    #|(module
    #|  (table 1 funcref)
    #|  (func $store (param i32 funcref)
    #|    local.get 0
    #|    local.get 1
    #|    table.set 0)
    #|  (func (export "run") (param i32 funcref)
    #|    local.get 0
    #|    local.get 1
    #|    call $store
    #|    local.get 0
    #|    local.get 1
    #|    call $store))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("table.set"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
}

///|
test "inlining treats repeated parameter passthrough table.grow wrappers as shrinking trivial" {
  let source =
    #|(module
    #|  (table 1 funcref)
    #|  (func $grow (param funcref i32) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    table.grow 0)
    #|  (func (export "run") (param funcref i32) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    call $grow
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    call $grow))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("table.grow"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
}

///|
test "inlining treats repeated parameter passthrough memory.fill wrappers as shrinking trivial" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $fill (param i32 i32 i32)
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    memory.fill)
    #|  (func (export "run") (param i32 i32 i32)
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    call $fill
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    call $fill))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("memory.fill"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
}

///|
test "inlining treats repeated parameter passthrough memory.copy wrappers as shrinking trivial" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $copy (param i32 i32 i32)
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    memory.copy)
    #|  (func (export "run") (param i32 i32 i32)
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    call $copy
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    call $copy))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("memory.copy"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
}

///|
test "inlining treats repeated parameter passthrough memory.init wrappers as shrinking trivial" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (data $d "hello")
    #|  (func $init (param i32 i32 i32)
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    memory.init $d)
    #|  (func (export "run") (param i32 i32 i32)
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    call $init
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    call $init))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("memory.init"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
}

///|
test "inlining treats repeated parameter passthrough table.fill wrappers as shrinking trivial" {
  let source =
    #|(module
    #|  (table 1 funcref)
    #|  (func $fill (param i32 funcref i32)
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    table.fill 0)
    #|  (func (export "run") (param i32 funcref i32)
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    call $fill
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    call $fill))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("table.fill"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
}

///|
test "inlining treats repeated parameter passthrough table.copy wrappers as shrinking trivial" {
  let source =
    #|(module
    #|  (table 10 funcref)
    #|  (func $copy (param i32 i32 i32)
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    table.copy 0 0)
    #|  (func (export "run") (param i32 i32 i32)
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    call $copy
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    call $copy))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("table.copy"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
}

///|
test "inlining treats repeated parameter passthrough table.init wrappers as shrinking trivial" {
  let source =
    #|(module
    #|  (table 10 funcref)
    #|  (elem $e func)
    #|  (func $init (param i32 i32 i32)
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    table.init 0 $e)
    #|  (func (export "run") (param i32 i32 i32)
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    call $init
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    call $init))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("table.init"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
}

///|
test "inlining uses optimize-level three for may-not-shrink repeated-param wrappers" {
  let source =
    #|(module
    #|  (func $dbl (param i32) (result i32)
    #|    local.get 0
    #|    local.get 0
    #|    i32.add)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $dbl
    #|    local.get 0
    #|    call $dbl
    #|    i32.add))
  let default_out = inl_test_run(source, pass_name="inlining")
  match default_out.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected function section")
  }
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["inlining"],
      options=HotPipelineOptions::new(optimize_level=3),
    ) {
    Ok(mod_) => mod_
    Err(err) => abort("expected inlining pipeline success, got \{err}")
  }
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let caller = optimized.pretty_print_defined_func(0U)
  assert_false(caller.contains("call"), msg=caller)

  let optimized_with_shrink = match
    pass_test_run_pipeline(
      source,
      ["inlining"],
      options=HotPipelineOptions::new(optimize_level=3, shrink_level=1),
    ) {
    Ok(mod_) => mod_
    Err(err) => abort("expected inlining pipeline success, got \{err}")
  }
  match optimized_with_shrink.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected function section")
  }
  let shrink_caller = optimized_with_shrink.pretty_print_defined_func(1U)
  assert_true(shrink_caller.contains("call"), msg=shrink_caller)
}

///|
test "inlining treats repeated direct call wrappers as shrinking trivial" {
  let source =
    #|(module
    #|  (import "env" "add" (func $add (param i32 i32) (result i32)))
    #|  (func $wrap (param i32 i32) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    call $add)
    #|  (func (export "run") (param i32 i32) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    call $wrap
    #|    local.get 1
    #|    local.get 0
    #|    call $wrap
    #|    i32.add))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("call (Func 0)"), msg=caller)
  assert_false(caller.contains("call (Func 1)"), msg=caller)
}

///|
test "inlining optimize-level three flexible policy rejects loops and surviving calls" {
  let loop_source =
    #|(module
    #|  (func $loopwrap (param i32) (result i32)
    #|    (loop
    #|      local.get 0
    #|      drop)
    #|    local.get 0)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $loopwrap
    #|    local.get 0
    #|    call $loopwrap
    #|    i32.add))
  let loop_out = match
    pass_test_run_pipeline(
      loop_source,
      ["inlining"],
      options=HotPipelineOptions::new(optimize_level=3),
    ) {
    Ok(mod_) => mod_
    Err(err) => abort("expected inlining pipeline success, got \{err}")
  }
  match loop_out.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected function section")
  }
  let loop_caller = loop_out.pretty_print_defined_func(1U)
  assert_true(loop_caller.contains("call"), msg=loop_caller)

  let call_source =
    #|(module
    #|  (import "env" "imp" (func $imp (param i32) (result i32)))
    #|  (func $callwrap (param i32) (result i32)
    #|    local.get 0
    #|    call $imp
    #|    i32.const 1
    #|    i32.add)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $callwrap
    #|    local.get 0
    #|    call $callwrap
    #|    i32.add))
  let call_out = match
    pass_test_run_pipeline(
      call_source,
      ["inlining"],
      options=HotPipelineOptions::new(optimize_level=3),
    ) {
    Ok(mod_) => mod_
    Err(err) => abort("expected inlining pipeline success, got \{err}")
  }
  match call_out.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected function section")
  }
  let call_caller = call_out.pretty_print_defined_func(1U)
  assert_true(call_caller.contains("call"), msg=call_caller)
}

///|
test "inlining optimize-level three flexible policy allows call_indirect bodies" {
  let source =
    #|(module
    #|  (type $unary (func (param i32) (result i32)))
    #|  (import "env" "imp" (func $imp (type $unary)))
    #|  (table 1 funcref)
    #|  (elem (i32.const 0) $imp)
    #|  (func $indwrap (param i32) (result i32)
    #|    local.get 0
    #|    i32.const 0
    #|    call_indirect (type $unary)
    #|    i32.const 1
    #|    i32.add)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $indwrap
    #|    local.get 0
    #|    call $indwrap
    #|    i32.add))
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["inlining"],
      options=HotPipelineOptions::new(optimize_level=3),
    ) {
    Ok(mod_) => mod_
    Err(err) => abort("expected inlining pipeline success, got \{err}")
  }
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("call_indirect"), msg=caller)
  assert_false(caller.contains("call (Func"), msg=caller)
}

///|
test "inlining treats repeated parameter passthrough i32x4.add wrappers as shrinking trivial" {
  let source =
    #|(module
    #|  (func $add (param v128 v128) (result v128)
    #|    local.get 0
    #|    local.get 1
    #|    i32x4.add)
    #|  (func (export "run") (param v128 v128) (result v128)
    #|    local.get 0
    #|    local.get 1
    #|    call $add
    #|    local.get 0
    #|    local.get 1
    #|    call $add
    #|    i32x4.add))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("i32x4.add"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
}

///|
test "inlining treats broader SIMD two-parameter wrappers as shrinking trivial" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $sat (param v128 v128) (result v128)
    #|    local.get 0
    #|    local.get 1
    #|    i8x16.add_sat_s)
    #|  (func $cmp (param v128 v128) (result v128)
    #|    local.get 0
    #|    local.get 1
    #|    i32x4.eq)
    #|  (func $shift (param v128 i32) (result v128)
    #|    local.get 0
    #|    local.get 1
    #|    i64x2.shr_s)
    #|  (func $replace (param v128 i32) (result v128)
    #|    local.get 0
    #|    local.get 1
    #|    i8x16.replace_lane 0)
    #|  (func (export "sat") (param v128 v128) (result v128)
    #|    local.get 0
    #|    local.get 1
    #|    call $sat
    #|    local.get 0
    #|    local.get 1
    #|    call $sat
    #|    i8x16.add)
    #|  (func (export "cmp") (param v128 v128) (result v128)
    #|    local.get 0
    #|    local.get 1
    #|    call $cmp
    #|    local.get 0
    #|    local.get 1
    #|    call $cmp
    #|    i8x16.add)
    #|  (func (export "shift") (param v128 i32) (result v128)
    #|    local.get 0
    #|    local.get 1
    #|    call $shift
    #|    local.get 0
    #|    local.get 1
    #|    call $shift
    #|    i8x16.add)
    #|  (func (export "replace") (param v128 i32) (result v128)
    #|    local.get 0
    #|    local.get 1
    #|    call $replace
    #|    local.get 0
    #|    local.get 1
    #|    call $replace
    #|    i8x16.add))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 4)
    None => fail("expected function section")
  }
  for i in 0..<4 {
    let caller = optimized.pretty_print_defined_func(i.reinterpret_as_uint())
    assert_false(caller.contains("call"), msg=caller)
  }
}

///|
test "inlining treats SIMD ternary wrappers as shrinking trivial" {
  let source =
    #|(module
    #|  (func $madd (param v128 v128 v128) (result v128)
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    f32x4.relaxed_madd)
    #|  (func (export "run") (param v128 v128 v128)
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    call $madd
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    call $madd
    #|    drop))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("f32x4.relaxed_madd"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
}

///|
test "inlining zero-initializes appended defaultable callee locals in plain mode" {
  let source =
    #|(module
    #|  (func $id-with-dead-local (param i32) (result i32)
    #|    (local f32)
    #|    local.get 0)
    #|  (func (export "run") (param i32) (result i32)
    #|    (local f64)
    #|    local.get 0
    #|    call $id-with-dead-local))
  let optimized = inl_test_run(source, pass_name="inlining")
  let caller = optimized.pretty_print_defined_func(0U)
  assert_true(caller.contains("F64 (local)"), msg=caller)
  assert_true(caller.contains("F32 (local)"), msg=caller)
  assert_true(caller.contains("f32.const F32(0)"), msg=caller)
  assert_false(caller.contains("call"), msg=caller)
}

///|
test "inlining keeps untouched private dead-body helpers intact in plain mode" {
  let source =
    #|(module
    #|  (func $tiny (result i32)
    #|    i32.const 1)
    #|  (func $keep (result i32)
    #|    block
    #|      unreachable
    #|    end
    #|    i32.const 2
    #|    drop
    #|    i32.const 3)
    #|  (func (export "run") (result i32)
    #|    call $tiny))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  let keep = optimized.pretty_print_defined_func(0U)
  let run = optimized.pretty_print_defined_func(1U)
  assert_true(keep.contains("i32.const I32(3)"), msg=keep)
  assert_false(keep.contains("call"), msg=keep)
  assert_true(run.contains("i32.const I32(1)"), msg=run)
  assert_false(run.contains("call"), msg=run)
}

///|
test "inlining plain prunes dead unreachable value block without calls" {
  let source =
    #|(module
    #|  (func (export "run") (param f32)
    #|    (local v128 f64)
    #|    i32.const 1216634752
    #|    i32.popcnt
    #|    block
    #|      loop (result i64)
    #|        block (result v128)
    #|          unreachable
    #|          unreachable
    #|        end
    #|        unreachable
    #|      end
    #|      unreachable
    #|    end
    #|    unreachable))
  let optimized = inl_test_run(source, pass_name="inlining")
  let run = optimized.pretty_print_defined_func(0U)
  assert_false(run.contains("V128BlockType"), msg=run)
  assert_false(run.contains("dropunreachable"), msg=run)
  assert_true(run.contains("unreachable"), msg=run)
}

///|
test "inlining plain removes dead inlined nonroot helper in mixed-result cycle" {
  let source =
    #|(module
    #|  (type $f64 (func (result f64)))
    #|  (type $i64 (func (result i64)))
    #|  (func $main (export "main") (type $f64)
    #|    block unreachable end
    #|    call $f3
    #|    drop
    #|    i32.const 1
    #|    if (result f64)
    #|      f64.const 10
    #|    else
    #|      call $main
    #|    end)
    #|  (func $f1 (type $i64)
    #|    block unreachable end
    #|    call $f3
    #|    drop
    #|    i64.const 0)
    #|  (func $f2 (type $i64)
    #|    block unreachable end
    #|    call $f1
    #|    drop
    #|    i64.const 757)
    #|  (func $f3 (type $f64)
    #|    block unreachable end
    #|    call $f2
    #|    drop
    #|    f64.const 0))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  let main = optimized.pretty_print_defined_func(0U)
  let helper = optimized.pretty_print_defined_func(1U)
  assert_true(main.contains("results: [F64]"), msg=main)
  assert_true(helper.contains("results: [F64]"), msg=helper)
  assert_false(helper.contains("results: [I64]"), msg=helper)
}

///|
test "inlining plain unreachable mutual-recursion inline keeps exact appended local count" {
  let source =
    #|(module
    #|  (func $run (export "run") (param i32 f64)
    #|    (local i64)
    #|    block
    #|      unreachable
    #|    end
    #|    i32.const 1
    #|    f64.const 2
    #|    call $helper)
    #|  (func $helper (param i32 f64)
    #|    (local f32 i32 i64 i32)
    #|    local.get 0
    #|    local.get 1
    #|    call $run))
  let optimized = inl_test_run(source, pass_name="inlining")
  let run = optimized.pretty_print_defined_func(0U)
  assert_true(run.contains("[2] I64 (local)"), msg=run)
  assert_true(run.contains("[3] I32 (local)"), msg=run)
  assert_true(run.contains("[4] F64 (local)"), msg=run)
  assert_true(run.contains("[5] F32 (local)"), msg=run)
  assert_true(run.contains("[6] I32 (local)"), msg=run)
  assert_true(run.contains("[7] I64 (local)"), msg=run)
  assert_true(run.contains("[8] I32 (local)"), msg=run)
  assert_false(run.contains("[9]"), msg=run)
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
test "inlining inlines no-param multi-result callees using type-indexed wrapper blocks" {
  let source =
    #|(module
    #|  (type $pair_t (func (result i32 i32)))
    #|  (func $pair (type $pair_t)
    #|    i32.const 4
    #|    i32.const 5)
    #|  (func (export "run") (result i32)
    #|    call $pair
    #|    i32.add))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected func section")
  }
  let run = optimized.pretty_print_defined_func(0U)
  assert_true(run.contains("i32.const I32(4)"), msg=run)
  assert_true(run.contains("i32.const I32(5)"), msg=run)
  assert_false(run.contains("call"), msg=run)
}

///|
test "inlining reuses existing zero-param multi-result block types for parameterized callees" {
  let source =
    #|(module
    #|  (type $pair_t (func (param i32) (result i32 i32)))
    #|  (type $block_t (func (result i32 i32)))
    #|  (import "env" "pair-type" (func $pair_type (type $block_t)))
    #|  (func $pair (type $pair_t)
    #|    local.get 0
    #|    i32.const 1)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $pair
    #|    i32.add))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected func section")
  }
  let run = optimized.pretty_print_defined_func(0U)
  assert_true(run.contains("local.set"), msg=run)
  assert_true(run.contains("i32.const I32(1)"), msg=run)
  assert_false(run.contains("call"), msg=run)
}

///|
test "inlining synthesizes zero-param multi-result block types when absent" {
  let source =
    #|(module
    #|  (type $pair_t (func (param i32) (result i32 i32)))
    #|  (func $pair (type $pair_t)
    #|    local.get 0
    #|    i32.const 1)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $pair
    #|    i32.add))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected func section")
  }
  match optimized.type_sec {
    Some(@lib.TypeSec(types)) => @debug.assert_eq(types.length(), 3)
    None => fail("expected synthesized type section")
  }
  let run = optimized.pretty_print_defined_func(0U)
  assert_true(run.contains("local.set"), msg=run)
  assert_true(run.contains("i32.const I32(1)"), msg=run)
  assert_false(run.contains("call"), msg=run)
}

///|
test "inlining preserves nested return_call_indirect when the callsite is tail" {
  let source =
    #|(module
    #|  (type $t0 (func (param i32) (result i32)))
    #|  (table funcref (elem $leaf))
    #|  (func $leaf (type $t0)
    #|    local.get 0)
    #|  (func $tail (param i32) (result i32)
    #|    local.get 0
    #|    i32.const 0
    #|    return_call_indirect (type $t0))
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    return_call $tail))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  let run = optimized.pretty_print_defined_func(1U)
  assert_true(run.contains("return_call_indirect"), msg=run)
  assert_false(run.contains("return_call (Func 1)"), msg=run)
}

///|
test "inlining preserves nested return_call_ref when the callsite is tail" {
  let source =
    #|(module
    #|  (type $t0 (func (param i32) (result i32)))
    #|  (func $leaf (type $t0)
    #|    local.get 0)
    #|  (elem declare func $leaf)
    #|  (func $tail (param i32) (result i32)
    #|    local.get 0
    #|    ref.func $leaf
    #|    return_call_ref (type $t0))
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    return_call $tail))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  let run = optimized.pretty_print_defined_func(1U)
  assert_true(run.contains("return_call_ref"), msg=run)
  assert_false(run.contains("return_call (Func 1)"), msg=run)
}

///|
test "inlining preserves return_call in try_table callsite" {
  let source =
    #|(module
    #|  (func $tiny (result i32)
    #|    i32.const 7)
    #|  (func (export "run") (result i32)
    #|    try_table (result i32)
    #|      return_call $tiny
    #|    end))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected func section")
  }
  let run = optimized.pretty_print_defined_func(0U)
  assert_true(run.contains("try_table"), msg=run)
  assert_true(run.contains("i32.const I32(7)"), msg=run)
  assert_false(run.contains("return_call"), msg=run)
}

///|
test "inlining preserves nested return_call when the callsite is tail" {
  let source =
    #|(module
    #|  (type $t0 (func (param i32) (result i32)))
    #|  (import "env" "leaf" (func $leaf (type $t0)))
    #|  (func $tail (param i32) (result i32)
    #|    local.get 0
    #|    return_call $leaf)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    return_call $tail))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected func section")
  }
  let run = optimized.pretty_print_defined_func(0U)
  assert_true(run.contains("return_call (Func 0)"), msg=run)
  assert_false(run.contains("return_call (Func 1)"), msg=run)
}

///|
test "inlining leaves nested return_call callees alone at non-tail callsites" {
  let source =
    #|(module
    #|  (type $t0 (func (param i32) (result i32)))
    #|  (import "env" "leaf" (func $leaf (type $t0)))
    #|  (func $tail (param i32) (result i32)
    #|    local.get 0
    #|    return_call $leaf)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $tail
    #|    i32.const 1
    #|    i32.add))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  let run = optimized.pretty_print_defined_func(1U)
  assert_true(run.contains("call (Func 1)"), msg=run)
}

///|
test "inlining caps repeated recursive work per caller" {
  let source =
    #|(module
    #|  (func $a (export "A") (param i32) (result i32)
    #|    local.get 0
    #|    call $b)
    #|  (func $b (export "B") (param i32) (result i32)
    #|    local.get 0
    #|    call $b)
    #|  (func $d0)
    #|  (func $d1)
    #|  (func $d2)
    #|  (func $d3)
    #|  (func $d4)
    #|  (func $d5)
    #|  (func $d6)
    #|  (func $d7))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(locals, _) = funcs[0]
      @debug.assert_eq(locals.length(), 5)
    }
    None => fail("expected code section")
  }
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
test "inlining-optimizing retains root-signature member in mixed private cycle behind self-loop root" {
  let source =
    #|(module
    #|  (type $root (func (result i32)))
    #|  (type $mid (func (param i64) (result i32)))
    #|  (type $other (func (param i64) (result i64)))
    #|  (func $run (export "main") (type $root)
    #|    block unreachable end
    #|    i64.const 0
    #|    call $mid
    #|    drop
    #|    call $a
    #|    drop
    #|    call $run)
    #|  (func $a (type $root)
    #|    block unreachable end
    #|    i64.const 0
    #|    call $other
    #|    drop
    #|    i32.const 1)
    #|  (func $mid (type $mid)
    #|    block unreachable end
    #|    call $a
    #|    drop
    #|    i32.const 2)
    #|  (func $other (type $other)
    #|    block unreachable end
    #|    local.get 0
    #|    call $mid
    #|    drop
    #|    i64.const 3))
  let optimized = inl_test_run(source)
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  let helper = optimized.pretty_print_defined_func(1U)
  assert_true(helper.contains("results: [I32]"), msg=helper)
}

///|
test "inlining-optimizing retains root-signature member in void private cycle behind self-loop root" {
  let source =
    #|(module
    #|  (type $root (func (result f64)))
    #|  (type $void (func (param i32 i32)))
    #|  (func $run (export "main") (type $root)
    #|    block unreachable end
    #|    call $run
    #|    drop
    #|    i32.const 0
    #|    i32.const 0
    #|    call $b
    #|    f64.const 0)
    #|  (func $c (type $void)
    #|    block unreachable end
    #|    i32.const 0
    #|    i32.const 0
    #|    call $b)
    #|  (func $a (type $root)
    #|    block unreachable end
    #|    i32.const 0
    #|    i32.const 0
    #|    call $c
    #|    f64.const 1)
    #|  (func $b (type $void)
    #|    block unreachable end
    #|    call $a
    #|    drop))
  let optimized = inl_test_run(source)
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  let helper = optimized.pretty_print_defined_func(1U)
  assert_true(helper.contains("results: [F64]"), msg=helper)
}

///|
test "inlining-optimizing retains helper signature in self-loop root cycle with same-signature peer" {
  let source =
    #|(module
    #|  (type $root (func (param i64) (result f64)))
    #|  (type $helper (func (param f64 f32) (result f64)))
    #|  (func $run (export "main") (type $root)
    #|    block unreachable end
    #|    local.get 0
    #|    call $run
    #|    drop
    #|    f64.const 0
    #|    f32.const 0
    #|    call $helper)
    #|  (func $peer (type $helper)
    #|    block unreachable end
    #|    local.get 0
    #|    local.get 1
    #|    call $helper)
    #|  (func $helper (type $helper)
    #|    block unreachable end
    #|    local.get 0
    #|    local.get 1
    #|    call $peer
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    call $helper
    #|    drop
    #|    i64.const 0
    #|    call $shadow
    #|    drop
    #|    f64.const 0)
    #|  (func $shadow (type $root)
    #|    block unreachable end
    #|    f64.const 0
    #|    f32.const 0
    #|    call $helper
    #|    drop
    #|    f64.const 1
    #|    f32.const 1
    #|    call $peer
    #|    drop
    #|    local.get 0
    #|    call $run))
  let optimized = inl_test_run(source)
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  let helper = optimized.pretty_print_defined_func(1U)
  assert_true(helper.contains("params: [F64, F32]"), msg=helper)
  assert_true(helper.contains("results: [F64]"), msg=helper)
}

///|
test "inlining-optimizing drops private one-way self-loop chain behind duplicate root calls" {
  let source =
    #|(module
    #|  (type $root (func (param i32) (result f32)))
    #|  (func $run (export "main") (type $root)
    #|    block unreachable end
    #|    local.get 0
    #|    call $helper
    #|    drop
    #|    local.get 0
    #|    call $helper)
    #|  (func $helper (type $root)
    #|    block unreachable end
    #|    local.get 0
    #|    call $loop
    #|    drop
    #|    f32.const 1)
    #|  (func $shadow (type $root)
    #|    block unreachable end
    #|    local.get 0
    #|    call $loop
    #|    drop
    #|    f32.const 2)
    #|  (func $loop (type $root)
    #|    block unreachable end
    #|    local.get 0
    #|    call $loop
    #|    drop
    #|    local.get 0
    #|    call $shadow))
  let optimized = inl_test_run(source)
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected func section")
  }
}

///|
test "inlining-optimizing retains self-loop helper signature in root dead-suffix cycle" {
  let source =
    #|(module
    #|  (type $root (func (param f64 f64) (result f32)))
    #|  (type $helper (func (param i64) (result f64)))
    #|  (func $run (export "main") (type $root)
    #|    block unreachable end
    #|    i64.const 0
    #|    call $helper
    #|    drop
    #|    f32.const 0)
    #|  (func $helper (type $helper)
    #|    block unreachable end
    #|    f64.const 0
    #|    f64.const 0
    #|    call $shadow
    #|    drop
    #|    local.get 0
    #|    call $helper)
    #|  (func $orphan (type $helper)
    #|    block unreachable end
    #|    local.get 0
    #|    call $helper
    #|    drop
    #|    f64.const 1)
    #|  (func $shadow (type $root)
    #|    block unreachable end
    #|    f64.const 0
    #|    f64.const 0
    #|    call $run
    #|    drop
    #|    f64.const 0
    #|    f64.const 0
    #|    call $run))
  let optimized = inl_test_run(source)
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  let helper = optimized.pretty_print_defined_func(1U)
  assert_true(helper.contains("params: [I64]"), msg=helper)
  assert_true(helper.contains("results: [F64]"), msg=helper)
  assert_false(helper.contains("call"), msg=helper)
}

///|
test "inlining-optimizing retains same-signature root cycle helper with orphan dead suffix chain" {
  let source =
    #|(module
    #|  (type $root (func (param i64 f32) (result i64)))
    #|  (func $run (export "main") (type $root)
    #|    block unreachable end
    #|    local.get 0
    #|    local.get 1
    #|    call $helper
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    call $helper)
    #|  (func $orphan_a (type $root)
    #|    block unreachable end
    #|    local.get 0
    #|    local.get 1
    #|    call $orphan_b
    #|    drop
    #|    i64.const 1)
    #|  (func $orphan_b (type $root)
    #|    block unreachable end
    #|    local.get 0
    #|    local.get 1
    #|    call $helper
    #|    drop
    #|    i64.const 2)
    #|  (func $helper (type $root)
    #|    block unreachable end
    #|    local.get 0
    #|    local.get 1
    #|    call $run
    #|    drop
    #|    i64.const 3))
  let optimized = inl_test_run(source)
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 3)
    None => fail("expected func section")
  }
  let run = optimized.pretty_print_defined_func(0U)
  let exact = optimized.pretty_print_defined_func(1U)
  let helper = optimized.pretty_print_defined_func(2U)
  assert_true(run.contains("call"), msg=run)
  assert_false(exact.contains("call"), msg=exact)
  assert_true(helper.contains("call"), msg=helper)
}

///|
test "inlining-optimizing trims four-function same-signature dead-suffix chain to two representatives" {
  let source =
    #|(module
    #|  (type $root (func (result f32)))
    #|  (func $run (export "main") (type $root)
    #|    block unreachable end
    #|    call $c)
    #|  (func $a (type $root)
    #|    block unreachable end
    #|    call $run
    #|    drop
    #|    call $a)
    #|  (func $b (type $root)
    #|    block unreachable end
    #|    call $a)
    #|  (func $c (type $root)
    #|    block unreachable end
    #|    call $b))
  let optimized = inl_test_run(source)
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
}

///|
test "inlining-optimizing retains helper-cycle representative behind self-loop root" {
  let source =
    #|(module
    #|  (type $root (func (param f32) (result i64)))
    #|  (type $helper (func (param f64)))
    #|  (func $run (export "main") (type $root)
    #|    block unreachable end
    #|    f64.const 0
    #|    call $c
    #|    local.get 0
    #|    call $run)
    #|  (func $a (type $helper)
    #|    block unreachable end
    #|    f64.const 0
    #|    call $b)
    #|  (func $b (type $helper)
    #|    block unreachable end
    #|    f64.const 0
    #|    call $c)
    #|  (func $c (type $helper)
    #|    block unreachable end
    #|    f64.const 0
    #|    call $a))
  let optimized = inl_test_run(source)
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
  let helper = optimized.pretty_print_defined_func(1U)
  assert_true(helper.contains("params: [F64]"), msg=helper)
  assert_true(helper.contains("unreachable"), msg=helper)
}

///|
test "inlining-optimizing prunes dead unreachable value blocks even without inlining" {
  let source =
    #|(module
    #|  (func (export "run")
    #|    i32.const 1
    #|    drop
    #|    loop (result i64)
    #|      block (result v128)
    #|        unreachable
    #|        unreachable
    #|      end
    #|      unreachable
    #|    end
    #|    drop
    #|    unreachable))
  let optimized = inl_test_run(source)
  let run = optimized.pretty_print_defined_func(0U)
  assert_false(run.contains("V128BlockType"), msg=run)
  assert_true(run.contains("unreachable"), msg=run)
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

///|
test "inlining-optimizing nested scheduler starts with precompute-propagate prefix" {
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
  let mut cleanup_idx = -1
  let mut prefix_idx = -1
  let mut idx = 0
  for line in trace {
    if cleanup_idx < 0 &&
      line.contains("pass[inlining-optimizing]:nested-cleanup") {
      cleanup_idx = idx
    }
    if prefix_idx < 0 &&
      line.contains(
        "pass[inlining-optimizing]:nested-pass name=precompute-propagate-prefix",
      ) {
      prefix_idx = idx
    }
    idx += 1
  }
  assert_true(cleanup_idx >= 0, msg=trace.to_string())
  assert_true(prefix_idx > cleanup_idx, msg=trace.to_string())
}

///|
test "inlining-optimizing nested scheduler does not launch whole-module cleanup batch" {
  let source =
    #|(module
    #|  (func $tiny (result i32)
    #|    i32.const 1)
    #|  (func $idle (result i32)
    #|    (local i32)
    #|    local.get 0
    #|    i32.eqz)
    #|  (func (export "run") (result i32)
    #|    call $tiny))
  let trace = match pass_test_capture_trace(source, ["inlining-optimizing"]) {
    Ok(trace) => trace
    Err(err) => fail("expected traced inlining success, got \{err}")
  }
  assert_false(
    trace.any(fn(line) { line.contains("pipeline:start requested=29") }),
    msg=trace.to_string(),
  )
}

///|
test "inlining-optimizing nested scheduler gates default function prelude by options" {
  let source =
    #|(module
    #|  (func $tiny (result i32)
    #|    i32.const 1)
    #|  (func (export "run") (result i32)
    #|    call $tiny))
  let default_trace = match
    pass_test_capture_trace(source, ["inlining-optimizing"]) {
    Ok(trace) => trace
    Err(err) => fail("expected traced default inlining success, got \{err}")
  }
  let mut prefix_idx = -1
  let mut first_after_prefix = ""
  let mut idx = 0
  for line in default_trace {
    if line ==
      "pass[inlining-optimizing]:nested-pass name=precompute-propagate-prefix" {
      prefix_idx = idx
    } else if prefix_idx >= 0 &&
      first_after_prefix == "" &&
      line.contains("pass[inlining-optimizing]:nested-pass name=") {
      first_after_prefix = line
    }
    idx += 1
  }
  assert_true(prefix_idx >= 0, msg=default_trace.to_string())
  @debug.assert_eq(
    first_after_prefix, "pass[inlining-optimizing]:nested-pass name=dead-code-elimination",
  )
  let default_option_gated = [
    "ssa-nomerge", "pick-load-signs", "code-pushing", "heap2local", "merge-locals",
    "optimize-casts", "local-subtyping", "local-cse", "code-folding", "redundant-set-elimination",
  ]
  for pass_name in default_option_gated {
    assert_false(
      default_trace.any(fn(line) {
        line == "pass[inlining-optimizing]:nested-pass name=\{pass_name}"
      }),
      msg="unexpected default nested pass \{pass_name}: \{default_trace}",
    )
  }
  let o3_trace : Array[String] = []
  match
    run_hot_pipeline(
      pass_test_module_from_wat(source),
      HotPipelineOptions::new(
        optimize_level=3,
        trace=Some(fn(line) { o3_trace.push(line) }),
      ),
      ["inlining-optimizing"],
    ) {
    Ok(_) => ()
    Err(err) => fail("expected traced O3 inlining success, got \{err}")
  }
  assert_true(
    o3_trace.any(fn(line) {
      line == "pass[inlining-optimizing]:nested-pass name=ssa-nomerge"
    }),
    msg=o3_trace.to_string(),
  )
}

///|
test "inlining-optimizing nested scheduler replays early second remove-unused-names" {
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
  let mut dce_idx = -1
  let mut first_run_idx = -1
  let mut rub_idx = -1
  let mut second_run_idx = -1
  let mut first_vacuum_idx = -1
  let mut idx = 0
  for line in trace {
    if dce_idx < 0 &&
      line == "pass[inlining-optimizing]:nested-pass name=dead-code-elimination" {
      dce_idx = idx
    } else if dce_idx >= 0 &&
      first_run_idx < 0 &&
      line == "pass[inlining-optimizing]:nested-pass name=remove-unused-names" {
      first_run_idx = idx
    } else if first_run_idx >= 0 &&
      rub_idx < 0 &&
      line == "pass[inlining-optimizing]:nested-pass name=remove-unused-brs" {
      rub_idx = idx
    } else if rub_idx >= 0 &&
      second_run_idx < 0 &&
      line == "pass[inlining-optimizing]:nested-pass name=remove-unused-names" {
      second_run_idx = idx
    } else if rub_idx >= 0 &&
      first_vacuum_idx < 0 &&
      line == "pass[inlining-optimizing]:nested-pass name=vacuum" {
      first_vacuum_idx = idx
    }
    idx += 1
  }
  assert_true(dce_idx >= 0, msg=trace.to_string())
  assert_true(first_run_idx > dce_idx, msg=trace.to_string())
  assert_true(rub_idx > first_run_idx, msg=trace.to_string())
  assert_true(second_run_idx > rub_idx, msg=trace.to_string())
  assert_true(first_vacuum_idx > second_run_idx, msg=trace.to_string())
}

///|
test "inlining-optimizing nested scheduler replays O3 merge-locals slot" {
  let source =
    #|(module
    #|  (func $tiny (result i32)
    #|    i32.const 1)
    #|  (func (export "run") (result i32)
    #|    call $tiny))
  let trace : Array[String] = []
  match
    run_hot_pipeline(
      pass_test_module_from_wat(source),
      HotPipelineOptions::new(
        optimize_level=3,
        trace=Some(fn(line) { trace.push(line) }),
      ),
      ["inlining-optimizing"],
    ) {
    Ok(_) => ()
    Err(err) => fail("expected traced inlining success, got \{err}")
  }
  let mut heap2local_idx = -1
  let mut merge_idx = -1
  let mut casts_idx = -1
  let mut idx = 0
  for line in trace {
    if line == "pass[inlining-optimizing]:nested-pass name=heap2local" {
      heap2local_idx = idx
    } else if heap2local_idx >= 0 &&
      line == "pass[inlining-optimizing]:nested-pass name=merge-locals" {
      merge_idx = idx
    } else if merge_idx >= 0 &&
      line == "pass[inlining-optimizing]:nested-pass name=optimize-casts" {
      casts_idx = idx
    }
    idx += 1
  }
  assert_true(heap2local_idx >= 0, msg=trace.to_string())
  assert_true(merge_idx > heap2local_idx, msg=trace.to_string())
  assert_true(casts_idx > merge_idx, msg=trace.to_string())
}

///|
test "inlining-optimizing nested scheduler replays local reorder slot" {
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
  let mut seen_slns = false
  let mut vacuum_idx = -1
  let mut reorder_idx = -1
  let mut rub_idx = -1
  let mut idx = 0
  for line in trace {
    if line.contains(
        "pass[inlining-optimizing]:nested-pass name=simplify-locals-nostructure",
      ) {
      seen_slns = true
    } else if seen_slns &&
      vacuum_idx < 0 &&
      line.contains("pass[inlining-optimizing]:nested-pass name=vacuum") {
      vacuum_idx = idx
    } else if vacuum_idx >= 0 &&
      reorder_idx < 0 &&
      line.contains("pass[inlining-optimizing]:nested-pass name=reorder-locals") {
      reorder_idx = idx
    } else if reorder_idx >= 0 &&
      rub_idx < 0 &&
      line.contains(
        "pass[inlining-optimizing]:nested-pass name=remove-unused-brs",
      ) {
      rub_idx = idx
    }
    idx += 1
  }
  assert_true(vacuum_idx >= 0, msg=trace.to_string())
  assert_true(reorder_idx > vacuum_idx, msg=trace.to_string())
  assert_true(rub_idx > reorder_idx, msg=trace.to_string())
}

///|
test "inlining-optimizing nested scheduler replays code-folding before merge-blocks" {
  let source =
    #|(module
    #|  (func $tiny (result i32)
    #|    i32.const 1)
    #|  (func (export "run") (result i32)
    #|    call $tiny))
  let trace : Array[String] = []
  match
    run_hot_pipeline(
      pass_test_module_from_wat(source),
      HotPipelineOptions::new(
        optimize_level=3,
        trace=Some(fn(line) { trace.push(line) }),
      ),
      ["inlining-optimizing"],
    ) {
    Ok(_) => ()
    Err(err) => fail("expected traced O3 inlining success, got \{err}")
  }
  let mut simplify_idx = -1
  let mut folding_idx = -1
  let mut merge_idx = -1
  let mut idx = 0
  for line in trace {
    if simplify_idx < 0 &&
      line == "pass[inlining-optimizing]:nested-pass name=simplify-locals" {
      simplify_idx = idx
    } else if simplify_idx >= 0 &&
      folding_idx < 0 &&
      line == "pass[inlining-optimizing]:nested-pass name=code-folding" {
      folding_idx = idx
    } else if folding_idx >= 0 &&
      merge_idx < 0 &&
      line == "pass[inlining-optimizing]:nested-pass name=merge-blocks" {
      merge_idx = idx
    }
    idx += 1
  }
  assert_true(simplify_idx >= 0, msg=trace.to_string())
  assert_true(folding_idx > simplify_idx, msg=trace.to_string())
  assert_true(merge_idx > folding_idx, msg=trace.to_string())
}

///|
test "inlining-optimizing nested scheduler replays late local cleanup before code-folding" {
  let source =
    #|(module
    #|  (func $tiny (result i32)
    #|    i32.const 1)
    #|  (func (export "run") (result i32)
    #|    call $tiny))
  let trace : Array[String] = []
  match
    run_hot_pipeline(
      pass_test_module_from_wat(source),
      HotPipelineOptions::new(
        optimize_level=3,
        trace=Some(fn(line) { trace.push(line) }),
      ),
      ["inlining-optimizing"],
    ) {
    Ok(_) => ()
    Err(err) => fail("expected traced O3 inlining success, got \{err}")
  }
  let mut simplify_idx = -1
  let mut first_vacuum_idx = -1
  let mut first_reorder_idx = -1
  let mut coalesce_idx = -1
  let mut second_reorder_idx = -1
  let mut second_vacuum_idx = -1
  let mut folding_idx = -1
  let mut idx = 0
  for line in trace {
    if simplify_idx < 0 &&
      line == "pass[inlining-optimizing]:nested-pass name=simplify-locals" {
      simplify_idx = idx
    } else if simplify_idx >= 0 &&
      first_vacuum_idx < 0 &&
      line == "pass[inlining-optimizing]:nested-pass name=vacuum" {
      first_vacuum_idx = idx
    } else if first_vacuum_idx >= 0 &&
      first_reorder_idx < 0 &&
      line == "pass[inlining-optimizing]:nested-pass name=reorder-locals" {
      first_reorder_idx = idx
    } else if first_reorder_idx >= 0 &&
      coalesce_idx < 0 &&
      line == "pass[inlining-optimizing]:nested-pass name=coalesce-locals" {
      coalesce_idx = idx
    } else if coalesce_idx >= 0 &&
      second_reorder_idx < 0 &&
      line == "pass[inlining-optimizing]:nested-pass name=reorder-locals" {
      second_reorder_idx = idx
    } else if second_reorder_idx >= 0 &&
      second_vacuum_idx < 0 &&
      line == "pass[inlining-optimizing]:nested-pass name=vacuum" {
      second_vacuum_idx = idx
    } else if second_vacuum_idx >= 0 &&
      folding_idx < 0 &&
      line == "pass[inlining-optimizing]:nested-pass name=code-folding" {
      folding_idx = idx
    }
    idx += 1
  }
  assert_true(first_vacuum_idx > simplify_idx, msg=trace.to_string())
  assert_true(first_reorder_idx > first_vacuum_idx, msg=trace.to_string())
  assert_true(coalesce_idx > first_reorder_idx, msg=trace.to_string())
  assert_true(second_reorder_idx > coalesce_idx, msg=trace.to_string())
  assert_true(second_vacuum_idx > second_reorder_idx, msg=trace.to_string())
  assert_true(folding_idx > second_vacuum_idx, msg=trace.to_string())
}

///|
test "inlining-optimizing nested scheduler ends with final vacuum" {
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
  let mut last_hso_idx = -1
  let mut last_vacuum_idx = -1
  let mut last_nested_idx = -1
  let mut idx = 0
  for line in trace {
    if line.contains("pass[inlining-optimizing]:nested-pass name=") {
      last_nested_idx = idx
    }
    if line ==
      "pass[inlining-optimizing]:nested-pass name=heap-store-optimization" {
      last_hso_idx = idx
    } else if line == "pass[inlining-optimizing]:nested-pass name=vacuum" {
      last_vacuum_idx = idx
    }
    idx += 1
  }
  assert_true(last_hso_idx >= 0, msg=trace.to_string())
  assert_true(last_vacuum_idx > last_hso_idx, msg=trace.to_string())
  assert_true(last_nested_idx == last_vacuum_idx, msg=trace.to_string())
}

///|
test "inlining-optimizing nested scheduler replays O2 redundant-set-elimination tail" {
  let source =
    #|(module
    #|  (func $tiny (result i32)
    #|    i32.const 1)
    #|  (func (export "run") (result i32)
    #|    call $tiny))
  let trace : Array[String] = []
  match
    run_hot_pipeline(
      pass_test_module_from_wat(source),
      HotPipelineOptions::new(
        optimize_level=2,
        trace=Some(fn(line) { trace.push(line) }),
      ),
      ["inlining-optimizing"],
    ) {
    Ok(_) => ()
    Err(err) => fail("expected traced inlining success, got \{err}")
  }
  let mut hso_idx = -1
  let mut rse_idx = -1
  let mut final_vacuum_idx = -1
  let mut last_nested_idx = -1
  let mut idx = 0
  for line in trace {
    if line.contains("pass[inlining-optimizing]:nested-pass name=") {
      last_nested_idx = idx
    }
    if line ==
      "pass[inlining-optimizing]:nested-pass name=heap-store-optimization" {
      hso_idx = idx
    } else if line ==
      "pass[inlining-optimizing]:nested-pass name=redundant-set-elimination" {
      rse_idx = idx
    } else if line == "pass[inlining-optimizing]:nested-pass name=vacuum" {
      final_vacuum_idx = idx
    }
    idx += 1
  }
  assert_true(hso_idx >= 0, msg=trace.to_string())
  assert_true(rse_idx > hso_idx, msg=trace.to_string())
  assert_true(final_vacuum_idx > rse_idx, msg=trace.to_string())
  assert_true(last_nested_idx == final_vacuum_idx, msg=trace.to_string())
}

///|
test "inlining-optimizing nested prefix propagates default locals only in touched callers" {
  let source =
    #|(module
    #|  (type $t0 (func (result i32)))
    #|  (func $tiny (type $t0)
    #|    i32.const 1)
    #|  (func $idle (type $t0)
    #|    (local i32)
    #|    local.get 0
    #|    i32.eqz)
    #|  (func $run (export "run") (type $t0)
    #|    (local i32)
    #|    call $tiny
    #|    drop
    #|    local.get 0
    #|    i32.eqz))
  let optimized = inl_test_run(source)
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected function section")
  }
  let idle = optimized.pretty_print_defined_func(0U)
  assert_true(idle.contains("local.get (Local 0)"), msg=idle)
  let run = optimized.pretty_print_defined_func(1U)
  assert_true(run.contains("i32.const I32(1)"), msg=run)
  assert_false(run.contains("local.get"), msg=run)
}
