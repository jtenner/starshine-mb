///|
// Frozen pre-packet discovery for these flat performance fixtures only.
// The production profitability methods are unchanged for their forward edges.
fn dae2_packet_adjacent_discover_reference(
  aliases : Dae2ParameterAliases,
  instrs : Array[@lib.Instruction],
) -> Unit {
  let mark = aliases.undo.length()
  let mut previous_get = -1
  for instr in instrs {
    match instr {
      @lib.LocalGet(@lib.LocalIdx(raw)) => {
        let local_id = raw.to_int()
        let source = aliases.active[local_id]
        if source >= 0 {
          aliases.reads[local_id] -= 1
          aliases.reads[source] += 1
          aliases.forwarded = true
          previous_get = source
        } else {
          previous_get = local_id
        }
        continue
      }
      _ => ()
    }
    match instr {
      @lib.LocalSet(@lib.LocalIdx(raw)) | @lib.LocalTee(@lib.LocalIdx(raw)) if aliases.writes[raw.to_int()] ==
        1 => {
        let local_id = raw.to_int()
        let source = previous_get
        let is_alias = local_id >= aliases.start &&
          source >= 0 &&
          (
            aliases.writes[source] == 0 ||
            (aliases.writes[source] == 1 && aliases.is_established(source))
          ) &&
          (
            dae2_alias_source_is_nonwidening(source, local_id) ||
            aliases.source_is_profitable(
              source,
              local_id,
              instr is @lib.LocalTee(_),
            )
          )
        if is_alias {
          aliases.active[local_id] = source
          let kind = if instr is @lib.LocalTee(_) { 1L } else { 0L }
          aliases.targets[local_id] = source.to_int64() * 2L + kind
          // Roots are flattened before this writer; alias writers do not
          // establish ordinary source definitions.
          aliases.undo.push(local_id)
        } else if aliases.reads[local_id] > 0 {
          let established = match aliases.established {
            Some(facts) => facts
            None => {
              let facts = Array::make(aliases.reads.length(), false)
              aliases.established = Some(facts)
              facts
            }
          }
          established[local_id] = true
          aliases.undo.push(-local_id - 1)
        }
      }
      _ => ()
    }
    previous_get = -1
  }
  while aliases.undo.length() > mark {
    let entry = aliases.undo.pop().unwrap()
    if entry >= 0 {
      aliases.active[entry] = -1
    } else {
      aliases.established.unwrap()[-entry - 1] = false
    }
  }
}

///|
fn dae2_packet_adjacent_probe_reference(
  body : Array[@lib.Instruction],
  writes : Array[Int32],
) -> Bool {
  for position in 1..<body.length() {
    match (body[position - 1], body[position]) {
      (
        @lib.LocalGet(@lib.LocalIdx(source)),
        @lib.LocalSet(@lib.LocalIdx(target)),
      ) if target.to_int() >= 2 &&
        writes[target.to_int()] == 1 &&
        source != target &&
        writes[source.to_int()] <= 1 => return true
      _ => ()
    }
  }
  false
}

///|
fn dae2_packet_perf_fixture(kind : Int32) -> (@lib.Module, Int32) {
  let count = if kind == 2 { 16 } else if kind == 1 { 128 } else { 32 }
  let width = if kind == 2 { 32 } else if kind == 1 { 1 } else { 2 }
  let per_packet = width + (if kind == 0 { 1 } else { 0 })
  let packets = Array::makei(count, fn(packet) {
    let base = 2 + packet * per_packet
    if kind == 1 {
      "i32.const 3 local.set \{base} local.get \{base} call $consume local.get \{base} call $consume"
    } else {
      let anchor = if kind == 0 {
        "local.get 0 local.set \{base} local.get \{base} call $consume local.get \{base} call $consume"
      } else {
        ""
      }
      let first = base + (if kind == 0 { 1 } else { 0 })
      let producers = Array::make(width - 1, "local.get 1").join(" ")
      let setters = Array::makei(width, fn(slot) { "local.set \{first + slot}" }).join(
        " ",
      )
      let consumers = Array::makei(width, fn(slot) {
        "local.get \{first + slot} call $consume local.get \{first + slot} call $consume"
      }).join(" ")
      let root = if kind == 0 { "local.get 0" } else { "local.get 1" }
      "\{anchor} \{root} \{producers} \{setters} \{consumers}"
    }
  }).join(" ")
  let locals = Array::make(count * per_packet, "i32").join(" ")
  (
    pass_test_module_from_wat(
      "(module (import \"e\" \"consume\" (func $consume (param i32))) (func (export \"run\") (param i32 i32) (local \{locals}) i32.const 1 local.set 1 i32.const 2 local.set 1 \{packets}))",
    ),
    if kind == 0 {
      count * (width - 1)
    } else {
      count * per_packet
    },
  )
}

///|
fn dae2_packet_perf_query(
  body : Array[@lib.Instruction],
  reads : Array[Int32],
  writes : Array[Int32],
  reference : Bool,
) -> Array[Int64]? {
  let admitted = if reference {
    dae2_packet_adjacent_probe_reference(body, writes)
  } else {
    dae2_has_parameter_alias(body, 2, writes)
  }
  if !admitted {
    return None
  }
  let aliases = Dae2ParameterAliases::new(2, reads.copy(), writes)
  if reference {
    dae2_packet_adjacent_discover_reference(aliases, body)
  } else {
    aliases.discover(body)
  }
  Some(aliases.targets)
}

///|
fn dae2_packet_perf_measure(
  retention : @bench.T,
  body : Array[@lib.Instruction],
  reads : Array[Int32],
  writes : Array[Int32],
  reference : Bool,
  repetitions : Int32,
) -> UInt64 {
  let start = @lib.trace_now_us()
  for _ in 0..<repetitions {
    retention.keep(dae2_packet_perf_query(body, reads, writes, reference))
  }
  @lib.trace_elapsed_us_since(start)
}

///|
fn dae2_packet_paired_samples(kind : Int32) -> Unit raise {
  let (input, expected_locals) = dae2_packet_perf_fixture(kind)
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let reads = Array::make(2 + locals.length(), 0)
  let writes = Array::make(reads.length(), 0)
  pass_lower_count_locals(body, reads, writes)
  let old = dae2_packet_perf_query(body, reads, writes, true)
  let candidate = dae2_packet_perf_query(body, reads, writes, false)
  if kind == 0 {
    let old = old.unwrap()
    let candidate = candidate.unwrap()
    assert_true(
      candidate.filter(fn(target) { target >= 0L }).length() >
      old.filter(fn(target) { target >= 0L }).length(),
    )
  } else {
    assert_eq(old, None)
    assert_eq(candidate, None)
  }
  let output = dae2_cleanup_captures(input)
  @validate.validate_module(output).unwrap()
  let @lib.Func(remaining, _) = output.code_sec.unwrap().0[0]
  assert_eq(remaining.length(), expected_locals)
  let encoded = @binary.encode_module(output).unwrap()
  assert_true(encoded.length() <= saved.length())
  if kind != 0 {
    assert_eq(encoded, saved)
  }
  let retention = @bench.Bench()
  let mut repetitions = 1
  while true {
    let old = dae2_packet_perf_measure(
      retention, body, reads, writes, true, repetitions,
    )
    let candidate = dae2_packet_perf_measure(
      retention, body, reads, writes, false, repetitions,
    )
    if (old >= 10000UL && candidate >= 10000UL) || repetitions >= 8192 {
      break
    }
    repetitions *= 2
  }
  let old_samples : Array[UInt64] = []
  let candidate_samples : Array[UInt64] = []
  for sample in 0..<7 {
    for
      reference in (if sample % 2 == 0 { [true, false] } else { [false, true] }) {
      let elapsed = dae2_packet_perf_measure(
        retention, body, reads, writes, reference, repetitions,
      )
      if reference {
        old_samples.push(elapsed)
      } else {
        candidate_samples.push(elapsed)
      }
      println(
        "DAE2 packet kind=\{kind} sample=\{sample} reference=\{reference} repetitions=\{repetitions} elapsed_us=\{elapsed}",
      )
    }
  }
  assert_eq(old_samples.length(), 7)
  assert_eq(candidate_samples.length(), 7)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  println(
    "DAE2 packet kind=\{kind} instructions=\{body.length()} locals=\{locals.length()} output_locals=\{remaining.length()} input_bytes=\{saved.length()} output_bytes=\{encoded.length()} reference_us=\{old_samples} candidate_us=\{candidate_samples}",
  )
}

///|
#skip("manual paired native-release held immutable packet discovery cost")
test "DAE2 held packet positive paired native samples" {
  dae2_packet_paired_samples(0)
}

///|
#skip("manual paired native-release no-match packet discovery cost")
test "DAE2 held packet negative paired native samples" {
  dae2_packet_paired_samples(1)
}

///|
#skip("manual paired native-release 64-instruction collision packet cost")
test "DAE2 held packet collision paired native samples" {
  dae2_packet_paired_samples(2)
}
