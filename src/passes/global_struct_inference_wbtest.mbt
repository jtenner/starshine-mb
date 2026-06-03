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
