///|
test "optimizer threshold report reads resolved MoonBit option values" {
  let options = OptimizeOptions::new(
    inlining=InliningOptions::new(
      always_inline_max_size=3,
      one_caller_inline_max_size=17,
      flexible_inline_max_size=29,
      max_combined_binary_size=8192,
      partial_inlining_ifs=4,
    ),
    monomorphize_min_benefit=7,
    low_memory_bound=2048UL,
  )
  let report = cmd_optimizer_threshold_report_json(options)
  assert_true(
    report.contains("\"schema\":\"starshine.optimizer-threshold-registry.v1\""),
  )
  assert_true(
    report.contains("\"name\":\"always-inline-max-function-size\",\"value\":3"),
  )
  assert_true(
    report.contains(
      "\"name\":\"one-caller-inline-max-function-size\",\"value\":17",
    ),
  )
  assert_true(
    report.contains(
      "\"name\":\"flexible-inline-max-function-size\",\"value\":29",
    ),
  )
  assert_true(
    report.contains(
      "\"name\":\"inline-max-combined-binary-size\",\"value\":8192",
    ),
  )
  assert_true(report.contains("\"name\":\"partial-inlining-ifs\",\"value\":4"))
  assert_true(
    report.contains("\"name\":\"monomorphize-min-benefit\",\"value\":7"),
  )
  assert_true(report.contains("\"name\":\"low-memory-bound\",\"value\":2048"))
}

///|
test "optimizer pass queue report uses module-aware scheduler expansion" {
  let report = match
    cmd_optimizer_pass_queue_report_json(
      Module::new(),
      OptimizeOptions::new(optimize_level=4, shrink_level=4),
      ["optimize"],
    ) {
    Ok(text) => text
    Err(err) => fail("expected queue report, got \{err}")
  }
  assert_true(
    report.contains("\"schema\":\"starshine.optimizer-expanded-pass-queue.v1\""),
  )
  assert_true(report.contains("\"requested\":[\"optimize\"]"))
  assert_true(
    report.contains("\"ordinal\":0,\"name\":\"duplicate-function-elimination\""),
  )
  assert_true(report.contains("\"name\":\"vacuum\""))
  assert_false(report.contains("\"name\":\"heap-store-optimization\""))
}

///|
test "optimizer threshold report flag writes resolved JSON without an input" {
  let writes : Array[String] = []
  let io = CmdIO::new(write_stdout=fn(bytes) {
    writes.push(bytes_to_string_lossy(bytes))
    Ok(())
  })
  match
    run_cmd_with_adapter(
      [
        "--emit-optimizer-thresholds-json", "--always-inline-max-function-size",
        "6",
      ],
      io,
    ) {
    Ok(_) => ()
    Err(err) => fail("expected threshold report command, got \{err}")
  }
  @debug.assert_eq(writes.length(), 1)
  assert_true(
    writes[0].contains(
      "\"name\":\"always-inline-max-function-size\",\"value\":6",
    ),
  )
}

///|
test "optimizer expanded queue report flag writes module-aware boundaries" {
  let mod_ = Module::new()
  let wasm = match encode_module(mod_) {
    Ok(bytes) => bytes
    Err(err) => fail("expected empty module encoding, got \{err}")
  }
  let writes : Array[String] = []
  let io = CmdIO::new(
    read_file=fn(path) {
      if path == "input.wasm" {
        Ok(wasm)
      } else {
        Err("missing")
      }
    },
    write_stdout=fn(bytes) {
      writes.push(bytes_to_string_lossy(bytes))
      Ok(())
    },
  )
  match
    run_cmd_with_adapter(
      ["--emit-expanded-pass-queue-json", "-O4z", "--optimize", "input.wasm"],
      io,
    ) {
    Ok(_) => ()
    Err(err) => fail("expected queue report command, got \{err}")
  }
  @debug.assert_eq(writes.length(), 1)
  assert_true(
    writes[0].contains(
      "\"schema\":\"starshine.optimizer-expanded-pass-queue.v1\"",
    ),
  )
  assert_true(
    writes[0].contains(
      "\"ordinal\":0,\"name\":\"duplicate-function-elimination\"",
    ),
  )
}

///|
test "optimizer runtime interface report flag writes decoded module JSON" {
  let mod_ = Module::new()
  let wasm = match encode_module(mod_) {
    Ok(bytes) => bytes
    Err(err) => fail("expected empty module encoding, got \{err}")
  }
  let writes : Array[String] = []
  let io = CmdIO::new(
    read_file=fn(path) {
      if path == "input.wasm" {
        Ok(wasm)
      } else {
        Err("missing")
      }
    },
    write_stdout=fn(bytes) {
      writes.push(bytes_to_string_lossy(bytes))
      Ok(())
    },
  )
  match
    run_cmd_with_adapter(["--emit-runtime-interface-json", "input.wasm"], io) {
    Ok(_) => ()
    Err(err) => fail("expected runtime interface report command, got \{err}")
  }
  @debug.assert_eq(writes.length(), 1)
  assert_true(
    writes[0].contains(
      "\"schema\":\"starshine.optimizer-runtime-interface.v1\"",
    ),
  )
}

///|
test "optimizer runtime interface report is derived from decoded module sections" {
  let wat =
    #|(module
    #|  (type $unary (func (param i32) (result i64)))
    #|  (import "env" "call" (func $call (type $unary)))
    #|  (import "env" "memory" (memory 1 2))
    #|  (global $g (mut i32) (i32.const 0))
    #|  (func $run (type $unary) (param i32) (result i64)
    #|    (call $call (local.get 0)))
    #|  (func $start
    #|    (drop (call $call (i32.const 0))))
    #|  (export "run" (func $run))
    #|  (export "memory-alias" (memory 0))
    #|  (export "counter" (global $g))
    #|  (start $start))
    #|
  let mod_ = match
    @wast.wast_to_binary_module(wat, filename="optimizer-runtime-report.wat") {
    Ok(value) => value
    Err(err) => fail("expected runtime report fixture, got \{err}")
  }
  let report = cmd_optimizer_runtime_interface_report_json(mod_)
  assert_true(
    report.contains("\"schema\":\"starshine.optimizer-runtime-interface.v1\""),
  )
  assert_true(
    report.contains(
      "\"module\":\"env\",\"field\":\"call\",\"kind\":\"function\"",
    ),
  )
  assert_true(report.contains("\"params\":[\"i32\"],\"results\":[\"i64\"]"))
  assert_true(
    report.contains(
      "\"module\":\"env\",\"field\":\"memory\",\"kind\":\"memory\"",
    ),
  )
  assert_true(
    report.contains("\"name\":\"run\",\"kind\":\"function\",\"index\":1"),
  )
  assert_true(
    report.contains("\"name\":\"memory-alias\",\"kind\":\"memory\",\"index\":0"),
  )
  assert_true(
    report.contains("\"name\":\"counter\",\"kind\":\"global\",\"index\":0"),
  )
  assert_true(report.contains("\"hasStart\":true"))
}
