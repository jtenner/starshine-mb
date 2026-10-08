///|
fn gsi_test_closed_world_facts(input : String) -> GsiClosedWorldFacts {
  let mod_ = pass_test_module_from_wat(input)
  gsi_build_closed_world_facts(@validate.Env::new().with_module(mod_), mod_)
}

///|
fn gsi_test_closed_world_type_is_poisoned(
  facts : GsiClosedWorldFacts,
  type_idx : @lib.TypeIdx,
) -> Bool {
  let slot = gsi_type_slot(type_idx, facts.poisoned_type_slots.length())
  slot >= 0 && facts.poisoned_type_slots[slot]
}

///|
fn gsi_test_closed_world_candidate_count(
  facts : GsiClosedWorldFacts,
  type_idx : @lib.TypeIdx,
) -> Int {
  let slot = gsi_type_slot(
    type_idx,
    facts.candidate_globals_by_type_slot.length(),
  )
  if slot < 0 {
    0
  } else {
    facts.candidate_globals_by_type_slot[slot].length()
  }
}

///|
fn gsi_test_closed_world_candidate_indices(
  facts : GsiClosedWorldFacts,
  type_idx : @lib.TypeIdx,
) -> Array[Int] {
  let slot = gsi_type_slot(
    type_idx,
    facts.candidate_globals_by_type_slot.length(),
  )
  if slot < 0 {
    []
  } else {
    let out : Array[Int] = []
    for global_idx in facts.candidate_globals_by_type_slot[slot] {
      let @lib.GlobalIdx(raw) = global_idx
      out.push(raw.reinterpret_as_int())
    }
    out
  }
}

///|
test "global-struct-inference deduplicates exported roots and reuses global visit stamps" {
  let mod_ = pass_test_module_from_wat(
    (
      #| (module
      #|   (type $box (sub (struct (field i32))))
      #|   (type $reader (func (param (ref $box)) (result i32)))
      #|   (func $read (type $reader)
      #|     local.get 0
      #|     struct.get $box 0)
      #|   (global $reader (ref $reader) (ref.func $read))
      #|   (export "read-a" (func $read))
      #|   (export "read-b" (func $read))
      #|   (export "reader-a" (global $reader))
      #|   (export "reader-b" (global $reader)))
    ),
  )
  let roots = gsi_exported_origin_roots(mod_, 0, 1, 0, 1)
  @debug.assert_eq(roots.funcs, [0])
  @debug.assert_eq(roots.globals, [0])

  let visits = GsiGlobalVisitStamps::new()
  assert_true(visits.marks.is_empty())
  for generation in 0..<256 {
    ignore(generation)
    visits.begin_root()
    assert_true(visits.visit(127))
    assert_false(visits.visit(127))
  }
  @debug.assert_eq(visits.marks.length(), 128)
}

///|
test "global-struct-inference rejects mutable callback aliases before allocating visit stamps" {
  let mod_ = pass_test_module_from_wat(
    (
      #| (module
      #|   (type $reader (func (result i32)))
      #|   (func $read (type $reader) (i32.const 1))
      #|   (elem declare func $read)
      #|   (global $reader (mut (ref $reader)) (ref.func $read))
      #|   (func (export "get") (result (ref $reader))
      #|     global.get $reader))
    ),
  )
  let env = @validate.Env::new().with_module(mod_)
  let defined_globals = match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) => globals
    None => abort("expected global section")
  }
  let body = match mod_.code_sec {
    Some(@lib.CodeSec([_, @lib.Func(_, body), ..])) => body
    _ => abort("expected callback getter body")
  }
  let value_type = match defined_globals[0] {
    @lib.Global(@lib.GlobalType(value_type, _), _) => value_type
  }
  let callable_funcs : Array[@lib.FuncIdx] = []
  let visits = GsiGlobalVisitStamps::new()
  visits.begin_root()
  gsi_collect_returned_ref_funcs(
    env,
    body,
    [value_type],
    callable_funcs,
    defined_globals,
    0,
    visits,
  )
  assert_true(callable_funcs.is_empty())
  assert_true(visits.marks.is_empty())
}

///|
test "global-struct-inference closed-world facts include immutable top-level global candidates" {
  let input =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $a (ref $box) (struct.new $box (i32.const 1)))
    #|   (global $b (ref null $box) (struct.new_default $box)))
    #|
  let facts = gsi_test_closed_world_facts(input)
  assert_false(
    gsi_test_closed_world_type_is_poisoned(facts, @lib.TypeIdx::new(0U)),
  )
  @debug.assert_eq(
    gsi_test_closed_world_candidate_count(facts, @lib.TypeIdx::new(0U)),
    2,
  )
}

///|
test "global-struct-inference closed-world facts exclude unsafe global origins" {
  let mutable_global =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $g (mut (ref $box)) (struct.new $box (i32.const 1))))
    #|
  @debug.assert_eq(
    gsi_test_closed_world_candidate_count(
      gsi_test_closed_world_facts(mutable_global),
      @lib.TypeIdx::new(0U),
    ),
    0,
  )

  let broad_global =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $g anyref (struct.new $box (i32.const 1))))
    #|
  @debug.assert_eq(
    gsi_test_closed_world_candidate_count(
      gsi_test_closed_world_facts(broad_global),
      @lib.TypeIdx::new(0U),
    ),
    0,
  )
}

///|
test "global-struct-inference closed-world facts poison function-local allocations" {
  let input =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $g (ref $box) (struct.new $box (i32.const 1)))
    #|   (func
    #|     i32.const 2
    #|     struct.new $box
    #|     drop))
    #|
  let facts = gsi_test_closed_world_facts(input)
  assert_true(
    gsi_test_closed_world_type_is_poisoned(facts, @lib.TypeIdx::new(0U)),
  )
  @debug.assert_eq(
    gsi_test_closed_world_candidate_count(facts, @lib.TypeIdx::new(0U)),
    0,
  )
}

///|
test "global-struct-inference closed-world facts poison nested global allocations only" {
  let input =
    #| (module
    #|   (type $inner (sub (struct (field i32))))
    #|   (type $outer (sub (struct (field (ref $inner)))))
    #|   (global $outer_g (ref $outer)
    #|     (struct.new $outer
    #|       (struct.new $inner
    #|         (i32.const 9)))))
    #|
  let facts = gsi_test_closed_world_facts(input)
  assert_true(
    gsi_test_closed_world_type_is_poisoned(facts, @lib.TypeIdx::new(0U)),
  )
  assert_false(
    gsi_test_closed_world_type_is_poisoned(facts, @lib.TypeIdx::new(1U)),
  )
  @debug.assert_eq(
    gsi_test_closed_world_candidate_count(facts, @lib.TypeIdx::new(0U)),
    0,
  )
  @debug.assert_eq(
    gsi_test_closed_world_candidate_count(facts, @lib.TypeIdx::new(1U)),
    1,
  )
}

///|
test "global-struct-inference closed-world facts propagate poisoned child types to parents" {
  let input =
    #| (module
    #|   (type $parent (sub (struct (field i32))))
    #|   (type $child (sub $parent (struct (field i32))))
    #|   (global $parent_g (ref $parent) (struct.new $parent (i32.const 1)))
    #|   (global $child_g (ref $child) (struct.new $child (i32.const 2)))
    #|   (func
    #|     i32.const 3
    #|     struct.new $child
    #|     drop))
    #|
  let facts = gsi_test_closed_world_facts(input)
  assert_true(
    gsi_test_closed_world_type_is_poisoned(facts, @lib.TypeIdx::new(0U)),
  )
  assert_true(
    gsi_test_closed_world_type_is_poisoned(facts, @lib.TypeIdx::new(1U)),
  )
  @debug.assert_eq(
    gsi_test_closed_world_candidate_count(facts, @lib.TypeIdx::new(0U)),
    0,
  )
  @debug.assert_eq(
    gsi_test_closed_world_candidate_count(facts, @lib.TypeIdx::new(1U)),
    0,
  )

  let no_globals =
    #| (module
    #|   (type $parent (sub (struct (field i32))))
    #|   (type $child (sub $parent (struct (field i32))))
    #|   (func
    #|     i32.const 3
    #|     struct.new $child
    #|     drop))
    #|
  let no_global_facts = gsi_test_closed_world_facts(no_globals)
  assert_true(
    gsi_test_closed_world_type_is_poisoned(
      no_global_facts,
      @lib.TypeIdx::new(0U),
    ),
  )
  assert_true(
    gsi_test_closed_world_type_is_poisoned(
      no_global_facts,
      @lib.TypeIdx::new(1U),
    ),
  )
}

///|
test "global-struct-inference closed-world facts propagate child candidates to parents" {
  let input =
    #| (module
    #|   (type $parent (sub (struct (field i32))))
    #|   (type $child (sub $parent (struct (field i32))))
    #|   (global $parent_g (ref $parent) (struct.new $parent (i32.const 1)))
    #|   (global $child_g (ref $child) (struct.new $child (i32.const 2))))
    #|
  let facts = gsi_test_closed_world_facts(input)
  @debug.assert_eq(
    gsi_test_closed_world_candidate_indices(facts, @lib.TypeIdx::new(0U)),
    [0, 1],
  )
  @debug.assert_eq(
    gsi_test_closed_world_candidate_indices(facts, @lib.TypeIdx::new(1U)),
    [1],
  )
}

///|
test "global-struct-inference closed-world facts keep propagated candidate order deterministic" {
  let input =
    #| (module
    #|   (type $parent (sub (struct (field i32))))
    #|   (type $child (sub $parent (struct (field i32))))
    #|   (global $child_g (ref $child) (struct.new $child (i32.const 2)))
    #|   (global $parent_g (ref $parent) (struct.new $parent (i32.const 1))))
    #|
  let facts = gsi_test_closed_world_facts(input)
  @debug.assert_eq(
    gsi_test_closed_world_candidate_indices(facts, @lib.TypeIdx::new(0U)),
    [0, 1],
  )
  @debug.assert_eq(
    gsi_test_closed_world_candidate_indices(facts, @lib.TypeIdx::new(1U)),
    [0],
  )
}
