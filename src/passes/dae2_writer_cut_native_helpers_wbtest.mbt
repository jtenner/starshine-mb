///|
fn dae2_writer_cut_native_fixture(
  width : Int32,
  cold : Bool,
  captures~ : Bool = false,
) -> @lib.Module {
  let text = StringBuilder()
  text.write_string(
    "(module (import \"m\" \"effect\" (func $effect (param i32) (result i32))) ",
  )
  text.write_string("(func $h (param i64) (result i32) i32.const 10) ")
  text.write_string(
    "(func (export \"run\") (param i32) (result i32) (local i32) ",
  )
  for _ in 0..<width {
    if cold {
      text.write_string("local.get 0 drop ")
    } else {
      if captures {
        text.write_string("i32.const 3 call $effect ")
      }
      text.write_string(
        "local.get 0 if i32.const 11 local.set 1 else i32.const 12 local.set 1 end local.get 1 ",
      )
      if captures {
        text.write_string("i32.add ")
      }
      text.write_string("call $effect drop ")
    }
  }
  text.write_string(if cold { "local.get 0 " } else { "local.get 1 " })
  text.write_string("call $effect i64.extend_i32_s call $h))")
  pass_test_module_from_wat(text.to_string())
}

///|
/// Primitive checksum, no generic carrier passed to keep.
fn dae2_writer_cut_native_checksum(
  probe : Dae2WriterCutProbe,
  replay : Dae2RawReplayState,
) -> Int32 {
  let info = probe.infos[probe.index]
  let last = info.node_location_base + info.node_count - 1
  (if replay.graph.used[info.result_location] { 1 } else { 0 }) +
  (if replay.graph.used[last] { 2 } else { 0 })
}

///|
/// Baseline uses the exact frozen analyzer and old private lift wrapper with
/// source recording off, matching the prior actual production rewrite route.
fn dae2_writer_cut_native_full(
  input : @lib.Module,
  probe : Dae2WriterCutProbe,
  replay : Dae2RawReplayState,
) -> Int32 {
  replay.reset()
  let func = dae2_writer_cut_frozen_dae2_lift_for_analysis(
    input,
    probe.context,
    probe.index,
    record_local_accesses=false,
  ).unwrap()
  probe.infos[probe.index].assign_node_locations(
    replay.graph,
    @ir.hot_node_count(func),
  )
  dae2_writer_cut_frozen_dae2_analyze_function(
    replay.graph,
    probe.infos,
    probe.index,
    probe.type_infos,
    func,
  )
  if !replay.solve_function(probe.infos[probe.index], probe.infos) {
    abort("native full boundary drift")
  }
  dae2_writer_cut_native_checksum(probe, replay)
}

///|
fn dae2_writer_cut_native_candidate(
  input : @lib.Module,
  probe : Dae2WriterCutProbe,
  replay : Dae2RawReplayState,
) -> Int32 {
  replay.reset()
  let func = dae2_lift_for_rewrite(
    input,
    probe.context,
    probe.index,
    probe.infos[probe.index],
  ).unwrap()
  let original = input.code_sec.unwrap().0[probe.index -
    dae_imported_func_count(input)]
  if !dae2_writer_cut_analyze_raw_replay(
      probe.source,
      replay,
      probe.infos,
      probe.index,
      probe.type_infos,
      func,
      original,
    ) {
    abort("native candidate boundary drift")
  }
  dae2_writer_cut_native_checksum(probe, replay)
}

///|
/// Both adverse-control routes pay this identical revision-only mutation.
fn dae2_writer_cut_native_stale_full(
  input : @lib.Module,
  probe : Dae2WriterCutProbe,
  replay : Dae2RawReplayState,
) -> Int32 {
  replay.reset()
  let func = dae2_writer_cut_frozen_dae2_lift_for_analysis(
    input,
    probe.context,
    probe.index,
    record_local_accesses=false,
  ).unwrap()
  @ir.hot_revision_bump(func)
  probe.infos[probe.index].assign_node_locations(
    replay.graph,
    @ir.hot_node_count(func),
  )
  dae2_writer_cut_frozen_dae2_analyze_function(
    replay.graph,
    probe.infos,
    probe.index,
    probe.type_infos,
    func,
  )
  if !replay.solve_function(probe.infos[probe.index], probe.infos) {
    abort("native stale full drift")
  }
  dae2_writer_cut_native_checksum(probe, replay)
}

///|
fn dae2_writer_cut_native_stale_candidate(
  input : @lib.Module,
  probe : Dae2WriterCutProbe,
  replay : Dae2RawReplayState,
) -> Int32 {
  replay.reset()
  let func = dae2_lift_for_rewrite(
    input,
    probe.context,
    probe.index,
    probe.infos[probe.index],
  ).unwrap()
  @ir.hot_revision_bump(func)
  let original = input.code_sec.unwrap().0[probe.index -
    dae_imported_func_count(input)]
  if !dae2_writer_cut_analyze_raw_replay(
      probe.source,
      replay,
      probe.infos,
      probe.index,
      probe.type_infos,
      func,
      original,
    ) {
    abort("native stale candidate drift")
  }
  dae2_writer_cut_native_checksum(probe, replay)
}

///|
/// Separate function so validation modules are out of scope before clocks.
fn dae2_writer_cut_native_output_check(input : @lib.Module) -> Unit raise {
  @validate.validate_module(input).unwrap()
  let actual = dae2_run_module_pass(
    input,
    false,
    raw_rewrite=false,
    stack_suffix_rewrite=false,
  ).unwrap()
  let expected = dae2_writer_cut_frozen_dae2_run_module_pass(
    input,
    false,
    raw_rewrite=false,
    stack_suffix_rewrite=false,
  ).unwrap()
  @validate.validate_module(actual).unwrap()
  @validate.validate_module(expected).unwrap()
  dae2_writer_cut_census_bytes_equal(
    @binary.encode_module(actual).unwrap(),
    @binary.encode_module(expected).unwrap(),
    "native preclock exact output",
  )
  let @lib.Func(_, @lib.Expr(before)) = input.code_sec.unwrap().0[input.code_sec.unwrap().0.length() -
    1]
  let @lib.Func(_, @lib.Expr(after)) = actual.code_sec.unwrap().0[actual.code_sec.unwrap().0.length() -
    1]
  assert_eq(
    dae2_writer_cut_effect_count(before),
    dae2_writer_cut_effect_count(after),
  )
}

///|
/// Untimed real guard/CFG checks. No recorder reaches a native kernel.
fn dae2_writer_cut_native_admission_check(
  input : @lib.Module,
  probe : Dae2WriterCutProbe,
  kind : Int32,
) -> Unit raise {
  let info = probe.infos[probe.index]
  let original = input.code_sec.unwrap().0[probe.index -
    dae_imported_func_count(input)]
  let expected = Dae2RawReplayState::new(probe.source, probe.boundary_count)
  let old_func = dae2_writer_cut_frozen_dae2_lift_for_analysis(
    input,
    probe.context,
    probe.index,
    record_local_accesses=false,
  ).unwrap()
  if kind == 2 {
    @ir.hot_revision_bump(old_func)
  }
  info.assign_node_locations(expected.graph, @ir.hot_node_count(old_func))
  let old_builds = [0]
  dae2_writer_cut_frozen_dae2_analyze_function(
    expected.graph,
    probe.infos,
    probe.index,
    probe.type_infos,
    old_func,
    local_graph_builds=Some(old_builds),
  )
  assert_true(expected.solve_function(info, probe.infos))
  let actual = Dae2RawReplayState::new(probe.source, probe.boundary_count)
  let func = dae2_lift_for_rewrite(input, probe.context, probe.index, info).unwrap()
  if kind == 2 {
    @ir.hot_revision_bump(func)
  }
  let admitted = {
    let cut = dae2_writer_cut_prepare(probe.source, info, func, original)
    cut is Some(_)
  }
  let builds = [0]
  assert_true(
    dae2_writer_cut_analyze_raw_replay(
      probe.source,
      actual,
      probe.infos,
      probe.index,
      probe.type_infos,
      func,
      original,
      local_graph_builds=Some(builds),
    ),
  )
  for node in 0..<info.node_count {
    assert_eq(
      actual.graph.used[info.node_location_base + node],
      expected.graph.used[info.node_location_base + node],
    )
  }
  for location in 0..<probe.boundary_count {
    assert_eq(actual.graph.used[location], probe.source.used[location])
  }
  assert_true(func.lifted_local_accesses is None)
  assert_eq(admitted, kind == 1 || kind == 3 || kind == 4)
  assert_eq(old_builds[0], if kind == 0 || kind == 4 { 0 } else { 1 })
  assert_eq(builds[0], if kind == 2 || kind == 5 { 1 } else { 0 })
}

///|
fn dae2_writer_cut_native_bench(
  it : @bench.T,
  width : Int32,
  kind : Int32,
  candidate : Bool,
) -> Unit raise {
  let input = if kind == 4 {
    dae2_writer_cut_cold_fixture(1, width)
  } else if kind == 5 {
    dae2_writer_cut_cold_fixture(3, width)
  } else {
    dae2_writer_cut_native_fixture(width, kind == 0, captures=kind >= 2)
  }
  let saved = @binary.encode_module(input).unwrap()
  dae2_writer_cut_native_output_check(input)
  let probe = dae2_writer_cut_probe_setup(input, false)
  dae2_writer_cut_native_admission_check(input, probe, kind)
  let old = Dae2RawReplayState::new(probe.source, probe.boundary_count)
  let next = Dae2RawReplayState::new(probe.source, probe.boundary_count)
  let before = if kind == 2 {
    dae2_writer_cut_native_stale_full(input, probe, old)
  } else {
    dae2_writer_cut_native_full(input, probe, old)
  }
  let after = if kind == 2 {
    dae2_writer_cut_native_stale_candidate(input, probe, next)
  } else {
    dae2_writer_cut_native_candidate(input, probe, next)
  }
  assert_eq(before, after)
  let info = probe.infos[probe.index]
  for node in 0..<info.node_count {
    assert_eq(
      next.graph.used[info.node_location_base + node],
      old.graph.used[info.node_location_base + node],
    )
  }
  for location in 0..<probe.boundary_count {
    assert_eq(next.graph.used[location], probe.source.used[location])
    assert_eq(next.graph.used[location], old.graph.used[location])
  }
  {
    let mapped = dae2_writer_cut_test_lift(input, probe.context, probe.index)
    let writes = @ir.hot_lift_local_accesses(mapped).writes
    let raw_writes = info.raw_write_locations.unwrap_or([])
    assert_eq(writes.length(), raw_writes.length())
    for slot in 0..<writes.length() {
      let (local, node) = writes[slot]
      let (raw_local, location) = raw_writes[slot]
      assert_eq(local, raw_local)
      if node >= 0 {
        assert_eq(
          old.graph.used[info.node_location_base + node],
          probe.source.used[location],
        )
        assert_eq(
          next.graph.used[info.node_location_base + node],
          probe.source.used[location],
        )
      } else {
        assert_false(probe.source.used[location])
      }
    }
  }
  // Four direct closures: route and guard mode are selected before clocks.
  // Timed work includes lift/journal construction, qualification, full HOT
  // checks, replay reset, dependency construction and solve; no recorder.
  if kind == 2 {
    if candidate {
      it.bench(fn() {
        it.keep(dae2_writer_cut_native_stale_candidate(input, probe, next))
      })
    } else {
      it.bench(fn() {
        it.keep(dae2_writer_cut_native_stale_full(input, probe, old))
      })
    }
  } else if candidate {
    it.bench(fn() {
      it.keep(dae2_writer_cut_native_candidate(input, probe, next))
    })
  } else {
    it.bench(fn() { it.keep(dae2_writer_cut_native_full(input, probe, old)) })
  }
  dae2_writer_cut_census_bytes_equal(
    @binary.encode_module(input).unwrap(),
    saved,
    "native source ownership",
  )
}
