///|
test "DAE2 entry-write proof bounds shared DAG work and retains cross-write reads" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()]),
  )
  let read = @ir.hot_build_local_get(func, 0)
  @ir.hot_root_append(func, @ir.hot_build_drop(func, read))
  let write = @ir.hot_build_local_set(
    func,
    0,
    @ir.hot_build_const_i32(func, @lib.I32(11)),
  )
  @ir.hot_root_append(func, write)
  let mut shared = read
  for _ in 0..<12 {
    shared = @ir.hot_build_binary(func, @lib.ValType::i32(), shared, shared)
  }
  @ir.hot_root_append(func, shared)
  let count = @ir.hot_node_count(func)
  let revision = @ir.hot_revision_current(func)
  let visits = [0]
  let sources = dae2_entry_read_sources(func, visits=Some(visits)).unwrap()
  assert_eq(sources[read], -3)
  assert_eq(@ir.hot_node_count(func), count)
  assert_eq(@ir.hot_revision_current(func), revision)
  assert_true(
    visits[0] <= count * 4,
    msg="shared DAG expanded beyond its node/edge work bound",
  )
}

///|
test "DAE2 entry-write proof visits shared DAGs once across unrelated root writes" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=Array::make(33, @lib.ValType::i32())),
  )
  let read = @ir.hot_build_local_get(func, 0)
  let write = @ir.hot_build_local_set(
    func,
    0,
    @ir.hot_build_const_i32(func, @lib.I32(11)),
  )
  @ir.hot_root_append(func, write)
  let mut shared = read
  for _ in 0..<64 {
    shared = @ir.hot_build_binary(func, @lib.ValType::i32(), shared, shared)
  }
  for local in 1..<33 {
    @ir.hot_root_append(func, @ir.hot_build_drop(func, shared))
    @ir.hot_root_append(
      func,
      @ir.hot_build_local_set(
        func,
        local,
        @ir.hot_build_const_i32(func, @lib.I32(local)),
      ),
    )
  }
  let count = @ir.hot_node_count(func)
  let revision = @ir.hot_revision_current(func)
  let visits = [0]
  let sources = dae2_entry_read_sources(func, visits=Some(visits)).unwrap()
  assert_eq(sources[read], write)
  assert_eq(@ir.hot_node_count(func), count)
  assert_eq(@ir.hot_revision_current(func), revision)
  assert_true(
    visits[0] <= count * 4,
    msg="unrelated writes multiplied shared-DAG traversal work",
  )
}

///|
test "DAE2 single-write source proof preserves sources without interval scratch" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()]),
  )
  let read = @ir.hot_build_local_get(func, 0)
  let write = @ir.hot_build_local_set(
    func,
    0,
    @ir.hot_build_const_i32(func, @lib.I32(11)),
  )
  @ir.hot_root_append(func, write)
  @ir.hot_root_append(
    func,
    @ir.hot_build_binary(func, @lib.ValType::i32(), read, read),
  )
  let revision = @ir.hot_revision_current(func)
  let intervals = [0]
  let sources = dae2_entry_read_sources(func, interval_builds=Some(intervals)).unwrap()
  assert_eq(sources[read], write)
  assert_eq(intervals[0], 0)
  assert_eq(@ir.hot_revision_current(func), revision)
}

///|
test "DAE2 source proof requires full flow for intentionally unsupported repeated write roots" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()]),
  )
  let write = @ir.hot_build_local_set(
    func,
    0,
    @ir.hot_build_const_i32(func, @lib.I32(11)),
  )
  @ir.hot_root_append(func, write)
  @ir.hot_root_append(func, write)
  assert_true(dae2_entry_read_sources(func) is None)
}

///|
test "DAE2 entry-write sources agree with full flow before and after an unconditional write" {
  for
    body in [
      "local.get 0 drop local.get 1 local.set 0 local.get 0", "local.get 0 local.get 1 i32.add local.set 0 block (result i32) local.get 0 end",
      "local.get 1 local.set 0 loop (result i32) local.get 0 end", "local.get 0 local.set 2 local.get 2 local.get 1 i32.add",
    ] {
    let input = pass_test_module_from_wat(
      "(module (func (param i32 i32) (result i32) (local i32) \{body}))",
    )
    let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
    let before = @ir.hot_lower_func(func)
    let revision = @ir.hot_revision_current(func)
    let sources = dae2_entry_read_sources(func).unwrap()
    let flow = @ir.local_graph_build_full_flow(func, @ir.cfg_build(func))
    let mut compared = 0
    for node in 0..<@ir.hot_node_count(func) {
      let data = @ir.hot_node_get(func, node)
      if data.op is @ir.LocalGet && sources[node] >= -1 {
        let reaching = @ir.local_graph_reaching_sources_for_get(flow, node)
        if !reaching.is_empty() {
          assert_eq(reaching.length(), 1)
          match reaching[0] {
            @ir.EntrySource(local) => {
              assert_eq(sources[node], -1)
              assert_eq(local, data.imm0)
            }
            @ir.SetSource(write) => assert_eq(sources[node], write)
          }
          compared += 1
        }
      }
    }
    assert_true(compared > 0)
    assert_eq(@ir.hot_revision_current(func), revision)
    assert_eq(@ir.hot_lower_func(func), before)
  }
}

///|
test "DAE2 entry-write sources keep shared reads and detached reads unknown" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()]),
  )
  let shared = @ir.hot_build_local_get(func, 0)
  let detached = @ir.hot_build_local_get(func, 0)
  let write = @ir.hot_build_local_set(
    func,
    0,
    @ir.hot_build_const_i32(func, @lib.I32(11)),
  )
  @ir.hot_root_append(func, @ir.hot_build_drop(func, shared))
  @ir.hot_root_append(func, write)
  @ir.hot_root_append(func, @ir.hot_build_drop(func, shared))
  let sources = dae2_entry_read_sources(func).unwrap()
  assert_eq(sources[shared], -3)
  // The intentionally detached read has no root-order proof.
  assert_eq(sources[detached], -2)
}

///|
test "DAE2 entry-write sources reject writes shared below conditional roots" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()]),
  )
  let write = @ir.hot_build_local_set(
    func,
    0,
    @ir.hot_build_const_i32(func, @lib.I32(11)),
  )
  @ir.hot_root_append(func, write)
  @ir.hot_root_append(
    func,
    @ir.hot_build_block(func, @lib.BlockType::void_(), [write]),
  )
  assert_true(dae2_entry_read_sources(func) is None)
}
