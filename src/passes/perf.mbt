///|
fn hot_perf_trace_noop(_ : String) -> Unit {
  ()
}

///|
pub struct HotPerfCounters {
  node_allocs : Int
  child_span_allocs : Int
  side_table_allocs : Int
  region_splices : Int
  cfg_builds : Int
  dataflow_builds : Int
  traversal_visits : Int
} derive(Eq, Show, Debug)

///|
pub fn HotPerfCounters::new(
  node_allocs? : Int = 0,
  child_span_allocs? : Int = 0,
  side_table_allocs? : Int = 0,
  region_splices? : Int = 0,
  cfg_builds? : Int = 0,
  dataflow_builds? : Int = 0,
  traversal_visits? : Int = 0,
) -> HotPerfCounters {
  {
    node_allocs,
    child_span_allocs,
    side_table_allocs,
    region_splices,
    cfg_builds,
    dataflow_builds,
    traversal_visits,
  }
}

///|
pub struct HotPerfDumpOptions {
  hot_func : Bool
  cfg : Bool
} derive(Eq, Show, Debug)

///|
pub fn HotPerfDumpOptions::new(
  hot_func? : Bool = false,
  cfg? : Bool = false,
) -> HotPerfDumpOptions {
  { hot_func, cfg }
}

///|
pub struct HotPerfHotSnapshot {
  node_count : Int
  child_span_count : Int
  side_table_count : Int
} derive(Eq, Show, Debug)

///|
pub fn HotPerfHotSnapshot::empty() -> HotPerfHotSnapshot {
  { node_count: 0, child_span_count: 0, side_table_count: 0 }
}

///|
pub struct HotPerfSession {
  enabled : Bool
  trace : (String) -> Unit
  trace_timings : Bool
  trace_checkpoints : Bool
  trace_counters : Bool
  dump_options : HotPerfDumpOptions
  mut counters : HotPerfCounters
  timer_totals : Array[(String, UInt64)]
}

///|
pub fn HotPerfSession::new(
  enabled? : Bool = true,
  trace? : (String) -> Unit = hot_perf_trace_noop,
  trace_timings? : Bool = true,
  trace_checkpoints? : Bool = true,
  trace_counters? : Bool = true,
  dump_options? : HotPerfDumpOptions = HotPerfDumpOptions::new(),
) -> HotPerfSession {
  {
    enabled,
    trace,
    trace_timings,
    trace_checkpoints,
    trace_counters,
    dump_options,
    counters: HotPerfCounters::new(),
    timer_totals: [],
  }
}

///|
fn perf_positive_delta(after : Int, before : Int) -> Int {
  if after > before {
    after - before
  } else {
    0
  }
}

///|
fn perf_side_table_count(func : @ir.HotFunc) -> Int {
  func.consts.length() +
  func.memargs.length() +
  func.branch_tables.length() +
  func.catches.length() +
  func.call_sigs.length() +
  func.instr_payloads.length()
}

///|
fn perf_timer_total_commit(
  session : HotPerfSession,
  name : String,
  elapsed_us : UInt64,
) -> UInt64 {
  let mut i = 0
  while i < session.timer_totals.length() {
    if session.timer_totals[i].0 == name {
      let total = session.timer_totals[i].1 + elapsed_us
      session.timer_totals[i] = (name, total)
      return total
    }
    i += 1
  }
  session.timer_totals.push((name, elapsed_us))
  elapsed_us
}

///|
fn perf_cfg_option_block(block_id : Int?) -> String {
  match block_id {
    Some(value) => value.to_string()
    None => "-"
  }
}

///|
pub fn perf_snapshot_hot_func(func : @ir.HotFunc) -> HotPerfHotSnapshot {
  {
    node_count: @ir.hot_node_count(func),
    child_span_count: @ir.hot_child_storage_count(func),
    side_table_count: perf_side_table_count(func),
  }
}

///|
pub fn perf_counters(session : HotPerfSession) -> HotPerfCounters {
  session.counters
}

///|
pub fn perf_start_timer(session : HotPerfSession, name : String) -> UInt64 {
  let _ = name
  if !session.enabled || !session.trace_timings {
    return 0UL
  }
  @lib.trace_now_us()
}

///|
pub fn perf_stop_timer(
  session : HotPerfSession,
  name : String,
  start_us : UInt64,
) -> Unit {
  if !session.enabled || !session.trace_timings {
    return
  }
  let elapsed_us = @lib.trace_elapsed_us_since(start_us)
  let total_us = perf_timer_total_commit(session, name, elapsed_us)
  (session.trace)(
    "perf:timer name=\{name} elapsed_us=\{elapsed_us} total_us=\{total_us}",
  )
}

///|
pub fn perf_count_node_alloc(
  session : HotPerfSession,
  count? : Int = 1,
) -> Unit {
  if !session.enabled || count <= 0 {
    return
  }
  session.counters = {
    ..session.counters,
    node_allocs: session.counters.node_allocs + count,
  }
}

///|
pub fn perf_count_child_span_alloc(
  session : HotPerfSession,
  count? : Int = 1,
) -> Unit {
  if !session.enabled || count <= 0 {
    return
  }
  session.counters = {
    ..session.counters,
    child_span_allocs: session.counters.child_span_allocs + count,
  }
}

///|
pub fn perf_count_side_table_alloc(
  session : HotPerfSession,
  count? : Int = 1,
) -> Unit {
  if !session.enabled || count <= 0 {
    return
  }
  session.counters = {
    ..session.counters,
    side_table_allocs: session.counters.side_table_allocs + count,
  }
}

///|
pub fn perf_count_region_splice(
  session : HotPerfSession,
  count? : Int = 1,
) -> Unit {
  if !session.enabled || count <= 0 {
    return
  }
  session.counters = {
    ..session.counters,
    region_splices: session.counters.region_splices + count,
  }
}

///|
pub fn perf_count_cfg_build(session : HotPerfSession, count? : Int = 1) -> Unit {
  if !session.enabled || count <= 0 {
    return
  }
  session.counters = {
    ..session.counters,
    cfg_builds: session.counters.cfg_builds + count,
  }
}

///|
pub fn perf_count_dataflow_build(
  session : HotPerfSession,
  name : String,
  count? : Int = 1,
) -> Unit {
  let _ = name
  if !session.enabled || count <= 0 {
    return
  }
  session.counters = {
    ..session.counters,
    dataflow_builds: session.counters.dataflow_builds + count,
  }
}

///|
pub fn perf_count_traversal_visit(
  session : HotPerfSession,
  count? : Int = 1,
) -> Unit {
  if !session.enabled || count <= 0 {
    return
  }
  session.counters = {
    ..session.counters,
    traversal_visits: session.counters.traversal_visits + count,
  }
}

///|
pub fn perf_count_hot_alloc_delta(
  session : HotPerfSession,
  before : HotPerfHotSnapshot,
  after : HotPerfHotSnapshot,
) -> Unit {
  perf_count_node_alloc(
    session,
    count=perf_positive_delta(after.node_count, before.node_count),
  )
  perf_count_child_span_alloc(
    session,
    count=perf_positive_delta(after.child_span_count, before.child_span_count),
  )
  perf_count_side_table_alloc(
    session,
    count=perf_positive_delta(after.side_table_count, before.side_table_count),
  )
}

///|
pub fn perf_dump_hot_func(
  session : HotPerfSession,
  func : @ir.HotFunc,
  label : String,
) -> Unit {
  if !session.enabled || !session.dump_options.hot_func {
    return
  }
  (session.trace)(
    "perf:dump hot-func label=\{label} \{@ir.hot_debug_dump_core(func)}",
  )
}

///|
pub fn perf_dump_cfg(
  session : HotPerfSession,
  cfg : @ir.HotCfg,
  label : String,
) -> Unit {
  if !session.enabled || !session.dump_options.cfg {
    return
  }
  (session.trace)(
    "perf:dump cfg label=\{label} entry=\{@ir.cfg_entry_block(cfg)} exit=\{@ir.cfg_exit_block(cfg)} exceptional=\{perf_cfg_option_block(@ir.cfg_exceptional_exit_block(cfg))} blocks=\{@ir.cfg_block_count(cfg)}",
  )
}

///|
pub fn perf_validation_checkpoint(
  session : HotPerfSession,
  name : String,
) -> Unit {
  if !session.enabled || !session.trace_checkpoints {
    return
  }
  (session.trace)("perf:checkpoint name=\{name}")
}

///|
pub fn perf_emit_counters(session : HotPerfSession, label : String) -> Unit {
  if !session.enabled || !session.trace_counters {
    return
  }
  let counters = session.counters
  (session.trace)(
    "perf:counters label=\{label} node_allocs=\{counters.node_allocs} child_span_allocs=\{counters.child_span_allocs} side_table_allocs=\{counters.side_table_allocs} region_splices=\{counters.region_splices} cfg_builds=\{counters.cfg_builds} dataflow_builds=\{counters.dataflow_builds} traversal_visits=\{counters.traversal_visits}",
  )
}
