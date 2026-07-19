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
fn inl_test_run_named_with_options(
  text : String,
  names : Array[(UInt, String)],
  passes : Array[String],
  options : HotPipelineOptions,
) -> @lib.Module {
  let entries : Array[@lib.NameAssoc] = []
  for pair in names {
    let (idx, name) = pair
    entries.push(@lib.NameAssoc::new(idx, @lib.Name::from_string(name)))
  }
  let mod_ = pass_test_module_from_wat(text).with_name_sec(
    @lib.NameSec::new(func_names=Some(@lib.NameMap::new(entries))),
  )
  match run_hot_pipeline(mod_, options, passes) {
    Ok(mod_) => mod_
    Err(err) => abort("expected configured inlining success, got \{err}")
  }
}

///|
fn inl_test_count_named_func(mod_ : @lib.Module, expected : String) -> Int {
  let mut count = 0
  match mod_.name_sec {
    Some(sec) =>
      match sec.func_names {
        Some(@lib.NameMap(entries)) =>
          for entry in entries {
            let @lib.NameAssoc(_, @lib.Name(name)) = entry
            if name == expected {
              count += 1
            }
          }
        None => ()
      }
    None => ()
  }
  count
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
test "inlining-optimizing folds simple inlined i32 accumulator chains before nested cleanup" {
  let source =
    #|(module
    #|  (type $t (func (param i32) (result i32)))
    #|  (func $h0 (type $t) local.get 0 i32.const 1 i32.add)
    #|  (func $h1 (type $t) local.get 0 i32.const 1 i32.add)
    #|  (func $h2 (type $t) local.get 0 i32.const 1 i32.add)
    #|  (func $h3 (type $t) local.get 0 i32.const 1 i32.add)
    #|  (func $h4 (type $t) local.get 0 i32.const 1 i32.add)
    #|  (func $main (export "main") (type $t)
    #|    (local i32)
    #|    local.get 0
    #|    local.set 1
    #|    local.get 1
    #|    call $h0
    #|    local.set 1
    #|    local.get 1
    #|    call $h1
    #|    local.set 1
    #|    local.get 1
    #|    call $h2
    #|    local.set 1
    #|    local.get 1
    #|    call $h3
    #|    local.set 1
    #|    local.get 1
    #|    call $h4
    #|    local.set 1
    #|    local.get 1))
  let optimized = inl_test_run(source)
  let main = optimized.pretty_print_defined_func(0U)
  assert_true(main.contains("i32.const I32(5)"), msg=main)
  assert_false(main.contains("call"), msg=main)
  assert_false(main.contains("local.set"), msg=main)
  assert_false(main.contains("block"), msg=main)
}

///|
test "inlining family passes are active module passes" {
  @debug.assert_eq(
    pass_registry_category("inlining-optimizing"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("inlining"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("inline-main"),
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
test "inline-main inlines the exact defined wrapper call without deleting the helper" {
  let source =
    #|(module
    #|  (func $__original_main (result i32)
    #|    i32.const 0)
    #|  (func $main (export "main") (param i32 i32) (result i32)
    #|    call $__original_main))
  let optimized = inl_test_run(source, pass_name="inline-main")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected function section")
  }
  let helper = optimized.pretty_print_defined_func(0U)
  let main = optimized.pretty_print_defined_func(1U)
  assert_true(helper.contains("i32.const I32(0)"), msg=helper)
  assert_true(main.contains("i32.const I32(0)"), msg=main)
  assert_false(main.contains("call"), msg=main)
}

///|
test "inline-main hoists a nested try_table return_call before inlining" {
  let source =
    #|(module
    #|  (func $__original_main (param i32) (result i32)
    #|    local.get 0)
    #|  (func $main (export "main") (param i32) (result i32)
    #|    try_table (result i32)
    #|      local.get 0
    #|      return_call $__original_main
    #|    end))
  let optimized = inl_test_run(source, pass_name="inline-main")
  match optimized.code_sec {
    Some(
      @lib.CodeSec(
        [
          _,
          @lib.Func(
            _,
            @lib.Expr(
              [
                @lib.Block(
                  _,
                  @lib.Expr(
                    [
                      @lib.TryTable(
                        _,
                        _,
                        @lib.Expr(
                          [@lib.LocalGet(_), @lib.LocalSet(_), @lib.Br(_)]
                        )
                      ),
                      @lib.Return,
                    ]
                  )
                ),
                @lib.Block(_, @lib.Expr([@lib.LocalGet(_)])),
                @lib.Return,
              ]
            )
          ),
        ]
      )
    ) => ()
    other =>
      fail(
        "expected inline-main to hoist the tail call out of try_table, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "inline-main leaves wrappers with multiple original-main calls unchanged" {
  let source =
    #|(module
    #|  (func $__original_main (result i32)
    #|    i32.const 0)
    #|  (func $main (export "main") (param i32 i32) (result i32)
    #|    call $__original_main
    #|    drop
    #|    call $__original_main))
  let optimized = inl_test_run(source, pass_name="inline-main")
  let main = optimized.pretty_print_defined_func(1U)
  assert_true(main.contains("call (Func 0)"), msg=main)
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
test "inlining remaps non-function names when type synthesis appends block types" {
  let source =
    #|(module
    #|  (type $callee_t (func (param i32) (result i32 i32)))
    #|  (type $run_t (func (param i32) (result i32)))
    #|  (table 1 funcref)
    #|  (memory 1)
    #|  (global i32 (i32.const 0))
    #|  (func $pair (type $callee_t)
    #|    local.get 0
    #|    i32.const 1)
    #|  (func $run (export "run") (type $run_t)
    #|    local.get 0
    #|    call $pair
    #|    i32.add))
  let input = pass_test_module_from_wat(source).with_name_sec(
    @lib.NameSec::new(
      func_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(0U, @lib.Name::from_string("pair")),
          @lib.NameAssoc::new(1U, @lib.Name::from_string("run")),
        ]),
      ),
      type_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(0U, @lib.Name::from_string("callee_t")),
          @lib.NameAssoc::new(1U, @lib.Name::from_string("run_t")),
        ]),
      ),
      table_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(0U, @lib.Name::from_string("table0")),
        ]),
      ),
      memory_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(0U, @lib.Name::from_string("memory0")),
        ]),
      ),
      global_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(0U, @lib.Name::from_string("global0")),
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
        Some(@lib.NameMap([@lib.NameAssoc(0U, @lib.Name("run"))])) => ()
        other =>
          fail(
            "expected compacted run function name, got \{@debug.to_string(other)}",
          )
      }
      match name_sec.type_names {
        Some(
          @lib.NameMap(
            [
              @lib.NameAssoc(0U, @lib.Name("callee_t")),
              @lib.NameAssoc(1U, @lib.Name("run_t")),
            ]
          )
        ) => ()
        other =>
          fail(
            "expected original type names without synthesized entry, got \{@debug.to_string(other)}",
          )
      }
      match name_sec.table_names {
        Some(@lib.NameMap([@lib.NameAssoc(0U, @lib.Name("table0"))])) => ()
        other =>
          fail("expected preserved table name, got \{@debug.to_string(other)}")
      }
      match name_sec.memory_names {
        Some(@lib.NameMap([@lib.NameAssoc(0U, @lib.Name("memory0"))])) => ()
        other =>
          fail("expected preserved memory name, got \{@debug.to_string(other)}")
      }
      match name_sec.global_names {
        Some(@lib.NameMap([@lib.NameAssoc(0U, @lib.Name("global0"))])) => ()
        other =>
          fail("expected preserved global name, got \{@debug.to_string(other)}")
      }
    }
    None => fail("expected name section after inlining")
  }
}

///|
test "inlining remaps valid function-scoped local names after compaction" {
  let source =
    #|(module
    #|  (type $t0 (func (result i32)))
    #|  (func $inline-me (type $t0)
    #|    i32.const 1)
    #|  (func $survivor (export "survivor") (type $t0)
    #|    (local i32)
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
        Some(
          @lib.IndirectNameMap(
            [
              @lib.IndirectNameAssoc(
                0U,
                @lib.NameMap([@lib.NameAssoc(0U, @lib.Name("stale-local"))])
              ),
            ]
          )
        ) => ()
        other =>
          fail(
            "expected remapped valid local names, got \{@debug.to_string(other)}",
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
test "no-inline wildcard marks unnamed functions using stable internal names" {
  let source =
    #|(module
    #|  (func (result i32)
    #|    i32.const 5)
    #|  (func (export "run") (result i32)
    #|    call 0))
  let optimized = match
    pass_test_run_pipeline(source, ["no-inline=*", "inlining"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected unnamed no-inline success, got \{err}")
  }
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected function section")
  }
  let run = optimized.pretty_print_defined_func(1U)
  assert_true(run.contains("call (Func 0)"), msg=run)
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
    #|  (@metadata.code.inline "\00")
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
test "inlining honors v131 binaryen never-inline toolchain annotation" {
  let source =
    #|(module
    #|  (@binaryen.inline "\00")
    #|  (func $never (result i32)
    #|    i32.const 42)
    #|  (func (export "run") (result i32)
    #|    call $never))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected function section")
  }
  let run = optimized.pretty_print_defined_func(1U)
  assert_true(run.contains("call (Func 0)"), msg=run)
}

///|
test "inlining honors v131 binaryen always-inline toolchain annotation" {
  let source =
    #|(module
    #|  (@binaryen.inline "\7f")
    #|  (func $always (param i32) (result i32)
    #|    (local i32)
    #|    local.get 0
    #|    local.set 1
    #|    loop
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      local.set 1
    #|      local.get 1
    #|      i32.const 4
    #|      i32.lt_u
    #|      br_if 0
    #|    end
    #|    local.get 1)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $always
    #|    local.get 0
    #|    call $always
    #|    i32.add))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let run = optimized.pretty_print_defined_func(0U)
  assert_false(run.contains("call"), msg=run)
  assert_true(run.contains("loop"), msg=run)
}

///|
test "no-full-inline policy overrides v131 binaryen always-inline annotation" {
  let source =
    #|(module
    #|  (@binaryen.inline "\7f")
    #|  (func $always (result i32)
    #|    i32.const 42)
    #|  (func (export "run") (result i32)
    #|    call $always))
  let optimized = inl_test_run_named(source, [(0U, "always"), (1U, "run")], [
    "no-full-inline=always", "inlining",
  ])
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected function section")
  }
  let run = optimized.pretty_print_defined_func(1U)
  assert_true(run.contains("call (Func 0)"), msg=run)
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
test "inlining O3 admits may-grow trivial direct calls with duplicate operands" {
  let source =
    #|(module
    #|  (type $leaf-type (func (param i32 i32) (result i32)))
    #|  (import "env" "leaf" (func $leaf (type $leaf-type)))
    #|  (func $wrapper (param i32) (result i32)
    #|    local.get 0
    #|    local.get 0
    #|    call $leaf)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $wrapper
    #|    local.get 0
    #|    call $wrapper
    #|    i32.add))
  let optimized = inl_test_run_named_with_options(
    source,
    [(0U, "leaf"), (1U, "wrapper"), (2U, "run")],
    ["inlining"],
    HotPipelineOptions::new(optimize_level=3, shrink_level=0),
  )
  let run = optimized.pretty_print_defined_func(0U)
  assert_false(run.contains("call (Func 1)"), msg=run)
  assert_true(run.contains("call (Func 0)"), msg=run)
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
test "inlining optimize-level three flexible policy allows indirect tail-call bodies" {
  let source =
    #|(module
    #|  (type $t0 (func (param i32) (result i32)))
    #|  (table funcref (elem $leaf))
    #|  (func $leaf (type $t0) local.get 0)
    #|  (elem declare func $leaf)
    #|  (func $indirect-tail (param i32) (result i32)
    #|    local.get 0
    #|    i32.const 0
    #|    return_call_indirect (type $t0))
    #|  (func $ref-tail (param i32) (result i32)
    #|    local.get 0
    #|    ref.func $leaf
    #|    return_call_ref (type $t0))
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0 call $indirect-tail
    #|    local.get 0 call $indirect-tail
    #|    i32.add
    #|    local.get 0 call $ref-tail
    #|    local.get 0 call $ref-tail
    #|    i32.add
    #|    i32.add))
  let optimized = inl_test_run_named_with_options(
    source,
    [(0U, "leaf"), (1U, "indirect-tail"), (2U, "ref-tail"), (3U, "run")],
    ["inlining"],
    HotPipelineOptions::new(
      optimize_level=3,
      shrink_level=0,
      inlining_always_inline_max_size=0,
      inlining_one_caller_inline_max_size=0,
      inlining_flexible_inline_max_size=10,
    ),
  )
  let run = optimized.pretty_print_defined_func(1U)
  assert_false(run.contains("return_call"), msg=run)
  assert_true(run.contains("call_indirect"), msg=run)
  assert_true(run.contains("call_ref"), msg=run)
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
test "inlining initializes nullable reference locals but not non-nullable locals" {
  let source =
    #|(module
    #|  (func $nullable
    #|    (local funcref))
    #|  (func $non-nullable
    #|    (local (ref func)))
    #|  (func (export "run")
    #|    call $nullable
    #|    call $non-nullable))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(locals, @lib.Expr(body))])) => {
      assert_true(
        locals
        .iter()
        .any(fn(vt) {
          match vt {
            @lib.RefTypeValType(rt) => rt.is_nullable()
            _ => false
          }
        }),
      )
      assert_true(
        locals
        .iter()
        .any(fn(vt) {
          match vt {
            @lib.RefTypeValType(rt) => rt.is_non_nullable()
            _ => false
          }
        }),
      )
      let mut null_count = 0
      for instr in body {
        match instr {
          @lib.RefNull(_) => null_count += 1
          _ => ()
        }
      }
      @debug.assert_eq(null_count, 1)
    }
    other =>
      fail(
        "expected one caller with copied ref locals, got \{@debug.to_string(other)}",
      )
  }
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
test "inlining does not plan direct calls in unreachable code" {
  let source =
    #|(module
    #|  (func $tiny i32.const 1 drop)
    #|  (func (export "run")
    #|    unreachable
    #|    call $tiny))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected function section")
  }
  let run = optimized.pretty_print_defined_func(1U)
  assert_true(run.contains("unreachable"), msg=run)
  assert_true(run.contains("call (Func 0)"), msg=run)
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
test "inlining hoists a tail callsite out of try_table before copying the callee" {
  let source =
    #|(module
    #|  (func $tiny (param i32) (result i32)
    #|    local.get 0)
    #|  (func (export "run") (param i32) (result i32)
    #|    try_table (result i32)
    #|      local.get 0
    #|      return_call $tiny
    #|    end))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.code_sec {
    Some(
      @lib.CodeSec(
        [
          @lib.Func(
            _,
            @lib.Expr(
              [
                @lib.Block(
                  block_type,
                  @lib.Expr(
                    [
                      @lib.TryTable(
                        _,
                        _,
                        @lib.Expr(
                          [@lib.LocalGet(_), @lib.LocalSet(_), @lib.Br(_)]
                        )
                      ),
                      @lib.Return,
                    ]
                  )
                ),
                @lib.Block(_, @lib.Expr([@lib.LocalGet(_)])),
                @lib.Return,
              ]
            )
          ),
        ]
      )
    ) => @debug.assert_eq(block_type, @lib.BlockType::void_())
    other =>
      fail(
        "expected tail callsite hoisted after original try body, got \{@debug.to_string(other)}",
      )
  }
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
test "inlining downgrades nested return_call at non-tail callsites" {
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
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected func section")
  }
  let run = optimized.pretty_print_defined_func(0U)
  assert_true(run.contains("call (Func 0)"), msg=run)
  assert_false(run.contains("return_call"), msg=run)
  assert_true(run.contains("br"), msg=run)
}

///|
test "inlining hoists nested direct return_call out of callee try_table" {
  let source =
    #|(module
    #|  (type $t0 (func (param i32) (result i32)))
    #|  (import "env" "leaf" (func $leaf (type $t0)))
    #|  (func $tail (param i32) (result i32)
    #|    try_table (result i32)
    #|      local.get 0
    #|      return_call $leaf
    #|    end)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $tail
    #|    i32.const 1
    #|    i32.add))
  let optimized = inl_test_run(source, pass_name="inlining")
  let run = optimized.pretty_print_defined_func(0U)
  assert_false(run.contains("call (Func 1)"), msg=run)
  assert_false(run.contains("return_call"), msg=run)
  assert_true(run.contains("try_table"), msg=run)
  assert_true(run.contains("call (Func 0)"), msg=run)
  assert_true(run.contains("br"), msg=run)
}

///|
test "nested tail hoisting evaluates call operands inside the original try" {
  let source =
    #|(module
    #|  (type $producer (func (result i32)))
    #|  (type $leaf-type (func (param i32) (result i32)))
    #|  (import "env" "operand" (func $operand (type $producer)))
    #|  (import "env" "leaf" (func $leaf (type $leaf-type)))
    #|  (func $tail (result i32)
    #|    try_table (result i32)
    #|      call $operand
    #|      return_call $leaf
    #|    end)
    #|  (func (export "run") (result i32)
    #|    call $tail
    #|    i32.const 1
    #|    i32.add))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.code_sec {
    Some(
      @lib.CodeSec(
        [
          @lib.Func(
            _,
            @lib.Expr(
              [
                @lib.Block(
                  _,
                  @lib.Expr(
                    [
                      @lib.Block(
                        _,
                        @lib.Expr(
                          [
                            @lib.TryTable(
                              _,
                              _,
                              @lib.Expr(
                                [
                                  @lib.Call(@lib.FuncIdx(0U)),
                                  @lib.LocalSet(_),
                                  @lib.Br(_),
                                ]
                              )
                            ),
                            @lib.Br(_),
                          ]
                        )
                      ),
                      @lib.LocalGet(_),
                      @lib.Call(@lib.FuncIdx(1U)),
                      @lib.Br(_),
                    ]
                  )
                ),
                @lib.I32Const(_),
                @lib.I32Add,
              ]
            )
          ),
        ]
      )
    ) => ()
    other =>
      fail(
        "expected operand evaluation inside try and leaf call after it, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "inlining hoists nested return_call_indirect out of callee try_table" {
  let source =
    #|(module
    #|  (type $t0 (func (param i32) (result i32)))
    #|  (table funcref (elem $leaf))
    #|  (func $leaf (type $t0) local.get 0)
    #|  (func $tail (param i32) (result i32)
    #|    try_table (result i32)
    #|      local.get 0
    #|      i32.const 0
    #|      return_call_indirect (type $t0)
    #|    end)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0 call $tail i32.const 1 i32.add))
  let optimized = inl_test_run(source, pass_name="inlining")
  let run = optimized.pretty_print_defined_func(1U)
  assert_false(run.contains("call (Func 1)"), msg=run)
  assert_false(run.contains("return_call_indirect"), msg=run)
  assert_true(run.contains("call_indirect"), msg=run)
  assert_true(run.contains("br"), msg=run)
}

///|
test "inlining hoists nested return_call_ref out of callee try_table" {
  let source =
    #|(module
    #|  (type $t0 (func (param i32) (result i32)))
    #|  (func $leaf (type $t0) local.get 0)
    #|  (elem declare func $leaf)
    #|  (func $tail (param i32) (result i32)
    #|    try_table (result i32)
    #|      local.get 0
    #|      ref.func $leaf
    #|      return_call_ref (type $t0)
    #|    end)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0 call $tail i32.const 1 i32.add))
  let optimized = inl_test_run(source, pass_name="inlining")
  let run = optimized.pretty_print_defined_func(1U)
  assert_false(run.contains("call (Func 1)"), msg=run)
  assert_false(run.contains("return_call_ref"), msg=run)
  assert_true(run.contains("call_ref"), msg=run)
  assert_true(run.contains("br"), msg=run)
}

///|
test "inlining handles ordinary try_table callees" {
  let source =
    #|(module
    #|  (func $try-value (result i32)
    #|    try_table (result i32)
    #|      i32.const 7
    #|    end)
    #|  (func (export "run") (result i32)
    #|    call $try-value
    #|    call $try-value
    #|    i32.add))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let run = optimized.pretty_print_defined_func(0U)
  assert_true(run.contains("try_table"), msg=run)
  assert_false(run.contains("call"), msg=run)
}

///|
test "inlining keeps helpers referenced from global initializers" {
  let source =
    #|(module
    #|  (type $t0 (func (result i32)))
    #|  (global funcref (ref.func $tiny))
    #|  (func $tiny (type $t0)
    #|    i32.const 7)
    #|  (func (export "run") (result i32)
    #|    call $tiny))
  let optimized = inl_test_run(source, pass_name="inlining")
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected function section")
  }
  let run = optimized.pretty_print_defined_func(1U)
  assert_false(run.contains("call"), msg=run)
  match optimized.global_sec {
    Some(
      @lib.GlobalSec(
        [@lib.Global(_, @lib.Expr([@lib.RefFunc(@lib.FuncIdx(0U))]))]
      )
    ) => ()
    other => fail("expected global ref.func root to survive, got \{other}")
  }
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
fn inl_test_large_module_for_nested_cleanup_guard() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func $tiny (result i32) i32.const 1)\n")
  out.write_string("  (func (export \"run\") (result i32) call $tiny)\n")
  let mut idx = 0
  while idx < 81 {
    out.write_string("  (func $f")
    out.write_string(idx.to_string())
    out.write_string(" (result i32) i32.const ")
    out.write_string((idx & 1).to_string())
    out.write_string(")\n")
    idx += 1
  }
  out.write_string(")")
  out.to_string()
}

///|
test "shrinking trivial classification permits an ordered prefix of parameters" {
  let source =
    #|(module
    #|  (func $const-with-unused (param i32 i32) (result i32)
    #|    i32.const 7)
    #|  (func (export "run") (result i32)
    #|    i32.const 1
    #|    i32.const 2
    #|    call $const-with-unused
    #|    i32.const 3
    #|    i32.const 4
    #|    call $const-with-unused
    #|    i32.add))
  let optimized = inl_test_run_named_with_options(
    source,
    [(0U, "const-with-unused"), (1U, "run")],
    ["inlining"],
    HotPipelineOptions::new(
      inlining_always_inline_max_size=0,
      inlining_one_caller_inline_max_size=0,
      inlining_flexible_inline_max_size=0,
    ),
  )
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let run = optimized.pretty_print_defined_func(0U)
  assert_false(run.contains("call"), msg=run)
  assert_true(run.contains("i32.const I32(7)"), msg=run)
}

///|
test "tuned thresholds still inline all ordered-operand trivial instruction families" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $const (result i32)
    #|    i32.const 7)
    #|  (func $unary (param i32) (result i32)
    #|    local.get 0
    #|    i32.eqz)
    #|  (func $load (param i32) (result i32)
    #|    local.get 0
    #|    i32.load)
    #|  (func (export "run") (param i32) (result i32)
    #|    call $const
    #|    call $const
    #|    i32.add
    #|    local.get 0
    #|    call $unary
    #|    local.get 0
    #|    call $unary
    #|    i32.add
    #|    i32.add
    #|    local.get 0
    #|    call $load
    #|    local.get 0
    #|    call $load
    #|    i32.add
    #|    i32.add))
  let optimized = inl_test_run_named_with_options(
    source,
    [(0U, "const"), (1U, "unary"), (2U, "load"), (3U, "run")],
    ["inlining"],
    HotPipelineOptions::new(
      inlining_always_inline_max_size=0,
      inlining_one_caller_inline_max_size=0,
      inlining_flexible_inline_max_size=0,
    ),
  )
  let run = optimized.pretty_print_defined_func(0U)
  assert_false(run.contains("call"), msg=run)
  assert_true(run.contains("i32.const I32(7)"), msg=run)
  assert_true(run.contains("i32.eqz"), msg=run)
  assert_true(run.contains("i32.load"), msg=run)
}

///|
test "inlining tuning bounds control always one-caller and flexible decisions" {
  let one_caller =
    #|(module
    #|  (func $add1 (param i32) (result i32)
    #|    local.get 0 i32.const 1 i32.add)
    #|  (func $run (export "run") (param i32) (result i32)
    #|    local.get 0 call $add1))
  let bounded_one = inl_test_run_named_with_options(
    one_caller,
    [(0U, "add1"), (1U, "run")],
    ["inlining"],
    HotPipelineOptions::new(inlining_one_caller_inline_max_size=2),
  )
  assert_true(
    bounded_one.pretty_print_defined_func(1U).contains("call (Func 0)"),
  )

  let two_callers =
    #|(module
    #|  (func $add1 (param i32) (result i32)
    #|    local.get 0 i32.const 1 i32.add)
    #|  (func $left (export "left") (param i32) (result i32)
    #|    local.get 0 call $add1)
    #|  (func $right (export "right") (param i32) (result i32)
    #|    local.get 0 call $add1))
  let flexible_blocked = inl_test_run_named_with_options(
    two_callers,
    [(0U, "add1"), (1U, "left"), (2U, "right")],
    ["inlining"],
    HotPipelineOptions::new(
      optimize_level=3,
      inlining_always_inline_max_size=0,
      inlining_flexible_inline_max_size=2,
    ),
  )
  assert_true(
    flexible_blocked.pretty_print_defined_func(1U).contains("call (Func 0)"),
  )
  let flexible_allowed = inl_test_run_named_with_options(
    two_callers,
    [(0U, "add1"), (1U, "left"), (2U, "right")],
    ["inlining"],
    HotPipelineOptions::new(
      optimize_level=3,
      inlining_always_inline_max_size=0,
      inlining_flexible_inline_max_size=3,
    ),
  )
  assert_false(
    flexible_allowed.pretty_print_defined_func(0U).contains("call (Func 0)"),
  )
}

///|
test "combined-size admission uses the iteration-start caller size per callsite" {
  let source =
    #|(module
    #|  (func $tiny (result i32)
    #|    i32.const 1)
    #|  (func (export "run") (result i32)
    #|    call $tiny
    #|    call $tiny
    #|    i32.add))
  let optimized = inl_test_run_named_with_options(
    source,
    [(0U, "tiny"), (1U, "run")],
    ["inlining"],
    HotPipelineOptions::new(inlining_max_combined_binary_size=11),
  )
  let run = optimized.pretty_print_defined_func(0U)
  assert_false(run.contains("call"), msg=run)
}

///|
test "inlining loop and combined-size tuning matches Binaryen policy" {
  let loop_source =
    #|(module
    #|  (func $looping (param i32) (result i32)
    #|    loop
    #|      nop
    #|    end
    #|    local.get 0 i32.const 1 i32.add)
    #|  (func $left (export "left") (param i32) (result i32)
    #|    local.get 0 call $looping)
    #|  (func $right (export "right") (param i32) (result i32)
    #|    local.get 0 call $looping))
  let loops_blocked = inl_test_run_named_with_options(
    loop_source,
    [(0U, "looping"), (1U, "left"), (2U, "right")],
    ["inlining"],
    HotPipelineOptions::new(optimize_level=3),
  )
  assert_true(
    loops_blocked.pretty_print_defined_func(1U).contains("call (Func 0)"),
  )
  let loops_allowed = inl_test_run_named_with_options(
    loop_source,
    [(0U, "looping"), (1U, "left"), (2U, "right")],
    ["inlining"],
    HotPipelineOptions::new(
      optimize_level=3,
      inlining_allow_functions_with_loops=true,
    ),
  )
  assert_false(
    loops_allowed.pretty_print_defined_func(0U).contains("call (Func 0)"),
  )

  let tiny =
    #|(module
    #|  (func $tiny (result i32) i32.const 1)
    #|  (func $run (export "run") (result i32) call $tiny))
  let size_blocked = inl_test_run_named_with_options(
    tiny,
    [(0U, "tiny"), (1U, "run")],
    ["inlining"],
    HotPipelineOptions::new(inlining_max_combined_binary_size=5),
  )
  assert_true(
    size_blocked.pretty_print_defined_func(1U).contains("call (Func 0)"),
  )
}

///|
test "partial analysis chooses full inline when the outlined remainder is profitable" {
  let source =
    #|(module
    #|  (func $guarded (param i32)
    #|    local.get 0
    #|    if
    #|      return
    #|    end
    #|    nop)
    #|  (func (export "run") (param i32)
    #|    local.get 0
    #|    call $guarded
    #|    local.get 0
    #|    call $guarded))
  let optimized = inl_test_run_named_with_options(
    source,
    [(0U, "guarded"), (1U, "run")],
    ["inlining"],
    HotPipelineOptions::new(
      optimize_level=3,
      shrink_level=0,
      inlining_always_inline_max_size=0,
      inlining_one_caller_inline_max_size=0,
      inlining_flexible_inline_max_size=3,
      inlining_partial_inlining_ifs=1,
    ),
  )
  match optimized.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 1)
    None => fail("expected function section")
  }
  let run = optimized.pretty_print_defined_func(0U)
  assert_false(run.contains("call"), msg=run)
  assert_true(run.contains("nop"), msg=run)
  assert_false(run.contains("byn-split"), msg=run)
}

///|
test "inlining partially splits a leading return guard when enabled" {
  let source =
    #|(module
    #|  (func $maybe (param i32)
    #|    local.get 0
    #|    if
    #|      return
    #|    end
    #|    i32.const 1 drop i32.const 2 drop i32.const 3 drop
    #|    i32.const 4 drop i32.const 5 drop i32.const 6 drop
    #|    i32.const 7 drop i32.const 8 drop i32.const 9 drop
    #|    i32.const 10 drop i32.const 11 drop i32.const 12 drop)
    #|  (func $left (export "left") (param i32)
    #|    local.get 0
    #|    call $maybe)
    #|  (func $right (export "right") (param i32)
    #|    local.get 0
    #|    call $maybe))
  let optimized = inl_test_run_named_with_options(
    source,
    [(0U, "maybe"), (1U, "left"), (2U, "right")],
    ["no-full-inline=maybe", "inlining"],
    HotPipelineOptions::new(optimize_level=3, inlining_partial_inlining_ifs=4),
  )
  let left = optimized.pretty_print_defined_func(1U)
  assert_true(left.contains("i32.eqz"), msg=left)
  assert_true(left.contains("call (Func"), msg=left)
  assert_false(left.contains("call (Func 0)"), msg=left)
  assert_eq(
    inl_test_count_named_func(optimized, "byn-split-outlined-A$maybe"),
    1,
  )
}

///|
test "inlining partially splits multiple leading guards with Pattern B" {
  let source =
    #|(module
    #|  (func $maybe (param i32 i32)
    #|    local.get 0
    #|    if
    #|      i32.const 1 drop i32.const 2 drop i32.const 3 drop
    #|      i32.const 4 drop i32.const 5 drop i32.const 6 drop
    #|    end
    #|    local.get 1
    #|    if
    #|      i32.const 7 drop i32.const 8 drop i32.const 9 drop
    #|      i32.const 10 drop i32.const 11 drop i32.const 12 drop
    #|    end)
    #|  (func $left (export "left") (param i32 i32)
    #|    local.get 0 local.get 1 call $maybe)
    #|  (func $right (export "right") (param i32 i32)
    #|    local.get 0 local.get 1 call $maybe))
  let optimized = inl_test_run_named_with_options(
    source,
    [(0U, "maybe"), (1U, "left"), (2U, "right")],
    ["no-full-inline=maybe", "inlining"],
    HotPipelineOptions::new(optimize_level=3, inlining_partial_inlining_ifs=4),
  )
  let left = optimized.pretty_print_defined_func(1U)
  assert_true(left.contains("if (Void)"), msg=left)
  assert_true(left.contains("call (Func"), msg=left)
  assert_eq(
    inl_test_count_named_func(optimized, "byn-split-outlined-B$maybe"),
    1,
  )
  assert_eq(
    inl_test_count_named_func(optimized, "byn-split-outlined-B$maybe$1"),
    1,
  )
}

///|
test "inlining Pattern B treats trapping result arms as terminal exits" {
  let source =
    #|(module
    #|  (func $guarded (param i32) (result i32)
    #|    local.get 0
    #|    if
    #|      unreachable
    #|    end
    #|    local.get 0)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    call $guarded
    #|    local.get 0
    #|    call $guarded
    #|    i32.add))
  let optimized = inl_test_run_named_with_options(
    source,
    [(0U, "guarded"), (1U, "run")],
    ["no-full-inline=guarded", "inlining"],
    HotPipelineOptions::new(
      optimize_level=3,
      shrink_level=0,
      inlining_always_inline_max_size=0,
      inlining_one_caller_inline_max_size=0,
      inlining_flexible_inline_max_size=0,
      inlining_partial_inlining_ifs=1,
    ),
  )
  assert_true(
    inl_test_count_named_func(optimized, "byn-split-outlined-B$guarded") == 1,
  )
  let run = optimized.pretty_print_defined_func(0U)
  assert_false(run.contains("call (Func 0)"), msg=run)
  assert_true(run.contains("call (Func 1)"), msg=run)
}

///|
test "inlining Pattern B returns outlined values before a simple final item" {
  let source =
    #|(module
    #|  (func $choose (param i32) (result i32)
    #|    local.get 0
    #|    if
    #|      i32.const 1 drop i32.const 2 drop i32.const 3 drop
    #|      i32.const 4 drop i32.const 5 drop i32.const 6 drop
    #|      i32.const 7
    #|      return
    #|    end
    #|    local.get 0)
    #|  (func $left (export "left") (param i32) (result i32)
    #|    local.get 0 call $choose)
    #|  (func $right (export "right") (param i32) (result i32)
    #|    local.get 0 call $choose))
  let optimized = inl_test_run_named_with_options(
    source,
    [(0U, "choose"), (1U, "left"), (2U, "right")],
    ["no-full-inline=choose", "inlining"],
    HotPipelineOptions::new(optimize_level=3, inlining_partial_inlining_ifs=4),
  )
  let left = optimized.pretty_print_defined_func(1U)
  assert_true(left.contains("br (Label 1)"), msg=left)
  assert_false(left.contains("call (Func 0)"), msg=left)
  assert_eq(
    inl_test_count_named_func(optimized, "byn-split-outlined-B$choose"),
    1,
  )
}

///|
test "no-partial-inline suppresses the enabled partial splitter" {
  let source =
    #|(module
    #|  (func $maybe (param i32)
    #|    local.get 0
    #|    if
    #|      return
    #|    end
    #|    i32.const 1 drop i32.const 2 drop i32.const 3 drop
    #|    i32.const 4 drop i32.const 5 drop i32.const 6 drop
    #|    i32.const 7 drop i32.const 8 drop i32.const 9 drop
    #|    i32.const 10 drop i32.const 11 drop i32.const 12 drop)
    #|  (func $left (export "left") (param i32)
    #|    local.get 0
    #|    call $maybe)
    #|  (func $right (export "right") (param i32)
    #|    local.get 0
    #|    call $maybe))
  let optimized = inl_test_run_named_with_options(
    source,
    [(0U, "maybe"), (1U, "left"), (2U, "right")],
    ["no-partial-inline=maybe", "inlining"],
    HotPipelineOptions::new(optimize_level=3, inlining_partial_inlining_ifs=4),
  )
  let left = optimized.pretty_print_defined_func(1U)
  assert_true(left.contains("call (Func 0)"), msg=left)
  assert_eq(
    inl_test_count_named_func(optimized, "byn-split-outlined-A$maybe"),
    0,
  )
}

///|
test "inlining-optimizing runs touched nested cleanup on large modules" {
  let source = inl_test_large_module_for_nested_cleanup_guard()
  let trace = match pass_test_capture_trace(source, ["inlining-optimizing"]) {
    Ok(trace) => trace
    Err(err) => fail("expected traced large inlining success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[inlining-optimizing]:nested-cleanup")
    }),
    msg=trace.to_string(),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[inlining-optimizing]:nested-pass name=")
    }),
    msg=trace.to_string(),
  )
}

///|
test "inlining-optimizing runs nested cleanup when untouched tail calls survive" {
  let source =
    #|(module
    #|  (type $t0 (func (result i32)))
    #|  (import "env" "tail" (func $tail (type $t0)))
    #|  (func $tiny (result i32)
    #|    i32.const 1)
    #|  (func (export "run") (result i32)
    #|    call $tiny
    #|    drop
    #|    return_call $tail))
  let trace = match pass_test_capture_trace(source, ["inlining-optimizing"]) {
    Ok(trace) => trace
    Err(err) => fail("expected traced tail-call inlining success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[inlining-optimizing]:nested-pass name=precompute-propagate",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "inlining nested pipeline matches Binaryen v131 default function order" {
  @debug.assert_eq(inlining_nested_function_pipeline_passes(4, 4), [
    "ssa-nomerge", "flatten", "simplify-locals-notee-nostructure", "local-cse", "dead-code-elimination",
    "remove-unused-names", "remove-unused-brs", "remove-unused-names", "optimize-instructions",
    "heap-store-optimization", "pick-load-signs", "precompute-propagate", "code-pushing",
    "tuple-optimization", "simplify-locals-nostructure", "vacuum", "reorder-locals",
    "remove-unused-brs", "heap2local", "merge-locals", "optimize-casts", "local-subtyping",
    "coalesce-locals", "local-cse", "simplify-locals", "vacuum", "reorder-locals",
    "coalesce-locals", "reorder-locals", "vacuum", "code-folding", "merge-blocks",
    "remove-unused-brs", "remove-unused-names", "merge-blocks", "precompute-propagate",
    "optimize-instructions", "heap-store-optimization", "redundant-set-elimination",
    "vacuum",
  ])
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
