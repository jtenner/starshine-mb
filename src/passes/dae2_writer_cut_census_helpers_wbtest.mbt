///|
fn dae2_writer_cut_census_source_count(body : Array[@lib.Instruction]) -> Int32 {
  let mut count = 0
  for instr in body {
    count += 1
    match instr {
      @lib.Block(_, @lib.Expr(child))
      | @lib.Loop(_, @lib.Expr(child))
      | @lib.TryTable(_, _, @lib.Expr(child)) =>
        count += dae2_writer_cut_census_source_count(child)
      @lib.If(_, yes, no) => {
        count += dae2_writer_cut_census_source_count(yes)
        match no {
          Some(child) => count += dae2_writer_cut_census_source_count(child)
          None => ()
        }
      }
      @lib.Try(_, @lib.Expr(child), catches, _) => {
        count += dae2_writer_cut_census_source_count(child)
        for catch_ in catches {
          match catch_ {
            @lib.LegacyCatch(_, @lib.Expr(child))
            | @lib.LegacyCatchAll(@lib.Expr(child)) =>
              count += dae2_writer_cut_census_source_count(child)
          }
        }
      }
      _ => ()
    }
  }
  count
}

///|
fn dae2_writer_cut_census_compare(
  errors : Array[Int32],
  index : Int32,
  closed_world : Bool,
  source : Dae2Graph,
  actual : Dae2RawReplayState,
  infos : Array[Dae2Function],
  boundary_count : Int32,
  original : @lib.Func,
  expected : Array[Bool],
  writer_nodes : Array[Int32],
  writer_locals : Array[Int32],
  journal_sizes : Array[Int32],
  admitted : Bool,
  guard_reason : Int32,
  old_builds : Int32,
  new_builds : Int32,
) -> Unit {
  let info = infos[index]
  let old_bits = StringBuilder::new()
  let new_bits = StringBuilder::new()
  for node in 0..<expected.length() {
    let used = actual.graph.used[info.node_location_base + node]
    old_bits.write_string(if expected[node] { "1" } else { "0" })
    new_bits.write_string(if used { "1" } else { "0" })
    if used != expected[node] {
      errors[0] += 1
    }
  }
  let raw_writes = info.raw_write_locations.unwrap_or([])
  if raw_writes.length() != writer_nodes.length() ||
    writer_nodes.length() != writer_locals.length() {
    errors[3] += 1
  }
  let writes = StringBuilder::new()
  for slot in 0..<raw_writes.length() {
    let (local, location) = raw_writes[slot]
    if slot >= writer_nodes.length() || slot >= writer_locals.length() {
      continue
    }
    if local != writer_locals[slot] {
      errors[3] += 1
    }
    let node = writer_nodes[slot]
    let raw_used = source.used[location]
    let old_used = node >= 0 && node < expected.length() && expected[node]
    let new_used = node >= 0 &&
      node < info.node_count &&
      actual.graph.used[info.node_location_base + node]
    if raw_used != old_used || old_used != new_used {
      errors[1] += 1
    }
    writes.write_string("\{slot}:\{local}:\{writer_locals[slot]}:\{node}:")
    writes.write_string(if raw_used { "1" } else { "0" })
    writes.write_string(if old_used { "1" } else { "0" })
    writes.write_string(if new_used { "1" } else { "0" })
    writes.write_string(",")
  }
  // Covers all function/type parameters and results, including unrelated bits.
  for location in 0..<boundary_count {
    if actual.graph.used[location] != source.used[location] {
      errors[2] += 1
    }
  }
  let @lib.Func(_, @lib.Expr(body)) = original
  let source_count = dae2_writer_cut_census_source_count(body)
  println(
    "writer-cut-node-census function=\{index} closed=\{closed_world} source=\{source_count} nodes=\{expected.length()} admitted=\{admitted} guard=\{guard_reason} old_cfg=\{old_builds} new_cfg=\{new_builds} journal_gets=\{journal_sizes[0]} journal_get_capacity=\{journal_sizes[1]} journal_writes=\{journal_sizes[2]} journal_write_capacity=\{journal_sizes[3]} capture_pairs=\{journal_sizes[4]} capture_capacity=\{journal_sizes[5]} old_bits=\{old_bits.to_string()} new_bits=\{new_bits.to_string()} writers=\{writes.to_string()}",
  )
}

///|
fn dae2_writer_cut_census_setting(name : String) -> String raise {
  match @env.get_env_var(name) {
    Some(value) if !value.is_empty() => value
    _ => fail("Set \{name} for this manual census")
  }
}

///|
/// Full byte equality; failure messages never render a module or byte array.
fn dae2_writer_cut_census_bytes_equal(
  actual : Bytes,
  expected : Bytes,
  label : String,
) -> Unit raise {
  if actual != expected {
    let mut index = 0
    while index < actual.length() &&
          index < expected.length() &&
          actual[index] == expected[index] {
      index += 1
    }
    fail(
      "\{label}: byte mismatch at\{index}; actual_size=\{actual.length()} expected_size=\{expected.length()}",
    )
  }
}

///|
/// Function boundaries keep only encoded bytes alive between entire routes.
fn dae2_writer_cut_census_actual_bytes(
  errors : Array[Int32],
  input : @lib.Module,
  closed_world : Bool,
  raw_analysis : Bool,
  analysis : Array[Int32],
  rewrites : Array[Int32],
) -> Bytes {
  let output = dae2_writer_cut_census_run(
    errors,
    input,
    closed_world,
    raw_analysis~,
    analysis_lifts=Some(analysis),
    rewrite_lifts=Some(rewrites),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  @binary.encode_module(output).unwrap()
}

///|
fn dae2_writer_cut_census_reference_bytes(
  input : @lib.Module,
  closed_world : Bool,
  raw_analysis : Bool,
) -> Bytes {
  let output = dae2_writer_cut_frozen_dae2_run_module_pass(
    input,
    closed_world,
    raw_analysis~,
  ).unwrap()
  @validate.validate_module(output).unwrap()
  @binary.encode_module(output).unwrap()
}

///|
fn dae2_writer_cut_census_direct_bytes(
  input : @lib.Module,
  closed_world : Bool,
  raw_analysis : Bool,
) -> Bytes {
  let output = dae2_run_module_pass(input, closed_world, raw_analysis~).unwrap()
  @validate.validate_module(output).unwrap()
  @binary.encode_module(output).unwrap()
}
