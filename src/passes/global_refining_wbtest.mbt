///|
fn gr_wbtest_old_collect_heaptype_candidates(
  heap_type : @lib.HeapType,
  env : @validate.Env,
  temporary_arrays : Array[Int],
) -> Array[@lib.HeapType] {
  temporary_arrays[0] += 3
  let out : Array[@lib.HeapType] = []
  let abstract_fallbacks : Array[@lib.HeapType] = []
  let work : Array[@lib.HeapType] = [heap_type]
  while work.length() > 0 {
    let current = work.pop().unwrap()
    let prior_len = out.length()
    gr_append_unique_heaptype(out, current)
    if out.length() == prior_len {
      continue
    }
    match current {
      @lib.AbsHeapTypeHeapType(abs) =>
        gr_append_abs_heap_supertypes(abstract_fallbacks, abs)
      @lib.SharedAbsHeapTypeHeapType(_) => ()
      @lib.HeapType(type_idx) =>
        match env.resolve_subtype(type_idx) {
          Some(subtype) => {
            for super_type in subtype.super_types().rev_iter() {
              work.push(@lib.HeapType::new(super_type))
            }
            gr_append_shape_heap_supertypes(
              abstract_fallbacks,
              subtype.get_comptype(),
            )
          }
          None => ()
        }
      @lib.DefTypeHeapType(def_type) =>
        match def_type.project() {
          Some(subtype) => {
            for super_type in subtype.super_types().rev_iter() {
              work.push(@lib.HeapType::new(super_type))
            }
            gr_append_shape_heap_supertypes(
              abstract_fallbacks,
              subtype.get_comptype(),
            )
          }
          None => ()
        }
    }
  }
  for fallback in abstract_fallbacks {
    gr_append_unique_heaptype(out, fallback)
  }
  out
}

///|
fn gr_wbtest_old_typeidx_is_declared_subtype(
  source : @lib.TypeIdx,
  target : @lib.TypeIdx,
  env : @validate.Env,
  temporary_arrays : Array[Int],
) -> Bool {
  temporary_arrays[0] += 2
  let work : Array[@lib.TypeIdx] = [source]
  let visited : Array[@lib.TypeIdx] = []
  while work.length() > 0 {
    let current = work.pop().unwrap()
    if current == target {
      return true
    }
    if visited.contains(current) {
      continue
    }
    visited.push(current)
    match env.resolve_subtype(current) {
      Some(subtype) =>
        for super_type in subtype.super_types() {
          work.push(super_type)
        }
      None => ()
    }
  }
  false
}

///|
fn gr_wbtest_old_heaptype_matches_join_candidate(
  source : @lib.HeapType,
  candidate : @lib.HeapType,
  env : @validate.Env,
  temporary_arrays : Array[Int],
) -> Bool {
  match (source, candidate) {
    (@lib.HeapType(source), @lib.HeapType(candidate)) =>
      gr_wbtest_old_typeidx_is_declared_subtype(
        source, candidate, env, temporary_arrays,
      )
    _ => @validate.Match::matches(source, candidate, env)
  }
}

///|
fn gr_wbtest_old_join_heaptypes(
  left : @lib.HeapType,
  right : @lib.HeapType,
  env : @validate.Env,
  temporary_arrays : Array[Int],
) -> @lib.HeapType? {
  if gr_wbtest_old_heaptype_matches_join_candidate(
      left, right, env, temporary_arrays,
    ) {
    return Some(right)
  }
  if gr_wbtest_old_heaptype_matches_join_candidate(
      right, left, env, temporary_arrays,
    ) {
    return Some(left)
  }
  let candidates = gr_wbtest_old_collect_heaptype_candidates(
    left, env, temporary_arrays,
  )
  for candidate in candidates {
    if gr_wbtest_old_heaptype_matches_join_candidate(
        left, candidate, env, temporary_arrays,
      ) &&
      gr_wbtest_old_heaptype_matches_join_candidate(
        right, candidate, env, temporary_arrays,
      ) {
      return Some(candidate)
    }
  }
  None
}

///|
test "global-refining nominal ancestry reuses pass-scoped traversal scratch" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (type $base (sub (struct)))
      #|  (type $left (sub $base (struct)))
      #|  (type $right (sub $base (struct)))
      #|  (type $left_leaf (sub $left (struct)))
      #|  (type $right_leaf (sub $right (struct))))
      #|,
    ),
  )
  let env = @validate.Env::new().with_module(input)
  let scratch = GrNominalAncestryScratch::new(env)
  let initial_allocations = scratch.stats.temporary_arrays_allocated
  for iteration = 0; iteration < 64; iteration = iteration + 1 {
    assert_true(
      gr_typeidx_is_declared_subtype(
        @lib.TypeIdx::new(3U),
        @lib.TypeIdx::new(0U),
        env,
        scratch,
      ),
    )
    assert_false(
      gr_typeidx_is_declared_subtype(
        @lib.TypeIdx::new(3U),
        @lib.TypeIdx::new(2U),
        env,
        scratch,
      ),
    )
    @debug.assert_eq(
      gr_join_heaptypes(
        @lib.HeapType::new(@lib.TypeIdx::new(3U)),
        @lib.HeapType::new(@lib.TypeIdx::new(4U)),
        env,
        scratch,
      ),
      Some(@lib.HeapType::new(@lib.TypeIdx::new(0U))),
    )
  }
  @debug.assert_eq(
    scratch.stats.temporary_arrays_allocated,
    initial_allocations,
  )
  @debug.assert_eq(scratch.stats.candidate_collections, 64)
  @debug.assert_eq(scratch.stats.declared_ancestor_collections, 64)
  @debug.assert_eq(scratch.stats.declared_subtype_queries, 64 * 4)
  assert_true(scratch.stats.visited_type_nodes > 0)
}

///|
#skip("manual 5000-type GlobalRefining nominal ancestry benchmark")
test "global-refining nominal ancestry perf lane measures branching joins" {
  let type_count = 5000
  let types : Array[@lib.SubType] = []
  for idx = 0; idx < type_count; idx = idx + 1 {
    let supers : Array[@lib.TypeIdx] = if idx == 0 {
      []
    } else {
      [@lib.TypeIdx::new(((idx - 1) / 2).reinterpret_as_uint())]
    }
    types.push(@lib.SubType::new(false, supers, @lib.CompType::struct_([])))
  }
  let env = @validate.Env::new().with_types(types)
  let old_temporary_arrays = [0]
  let old_samples : Array[UInt64] = []
  for sample = 0; sample < 7; sample = sample + 1 {
    let start = @lib.trace_now_us()
    for query = type_count / 2; query < type_count; query = query + 1 {
      let other = type_count - 1 - (query - type_count / 2)
      ignore(
        gr_wbtest_old_join_heaptypes(
          @lib.HeapType::new(@lib.TypeIdx::new(query.reinterpret_as_uint())),
          @lib.HeapType::new(@lib.TypeIdx::new(other.reinterpret_as_uint())),
          env,
          old_temporary_arrays,
        ),
      )
    }
    old_samples.push(@lib.trace_elapsed_us_since(start))
  }
  let scratch = GrNominalAncestryScratch::new(env)
  let samples : Array[UInt64] = []
  for sample = 0; sample < 7; sample = sample + 1 {
    let start = @lib.trace_now_us()
    for query = type_count / 2; query < type_count; query = query + 1 {
      let other = type_count - 1 - (query - type_count / 2)
      ignore(
        gr_join_heaptypes(
          @lib.HeapType::new(@lib.TypeIdx::new(query.reinterpret_as_uint())),
          @lib.HeapType::new(@lib.TypeIdx::new(other.reinterpret_as_uint())),
          env,
          scratch,
        ),
      )
    }
    samples.push(@lib.trace_elapsed_us_since(start))
  }
  println(
    "global_refining nominal_types=\{type_count} joins_per_sample=\{type_count / 2} old_samples=\{old_samples} samples=\{samples} old_temporary_arrays=\{old_temporary_arrays[0]} subtype_queries=\{scratch.stats.declared_subtype_queries} ancestor_collections=\{scratch.stats.declared_ancestor_collections} visited_nodes=\{scratch.stats.visited_type_nodes} candidate_collections=\{scratch.stats.candidate_collections} candidate_nodes=\{scratch.stats.candidate_nodes_visited} temporary_arrays=\{scratch.stats.temporary_arrays_allocated}",
  )
  @debug.assert_eq(scratch.stats.temporary_arrays_allocated, 6)
  assert_true(scratch.stats.candidate_collections > 0)
}
