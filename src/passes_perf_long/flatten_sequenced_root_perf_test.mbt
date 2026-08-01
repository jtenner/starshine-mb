///|
fn flatten_perf_payload_branch_suffix_module(
  function_count : Int,
  branches_per_function : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for function_idx = 0
      function_idx < function_count
      function_idx = function_idx + 1 {
    out.write_string("  (func\n")
    for branch_idx = 0
        branch_idx < branches_per_function
        branch_idx = branch_idx + 1 {
      out.write_string("    (drop (block (result i32) (i32.const ")
      out.write_string((function_idx + branch_idx).to_string())
      out.write_string(") (i32.const 0) br_table 0 0")
      if branch_idx % 2 == 0 {
        out.write_string(" unreachable))\n")
      } else {
        out.write_string(" (i32.const 1) i32.eqz drop))\n")
      }
    }
    out.write_string("  )\n")
  }
  out.write_string(")\n")
  out.to_string()
}

///|
#skip("manual native-release payload-branch dead-suffix benchmark")
test "flatten long perf lane measures effective-terminal suffix routing" {
  let input = flatten_perf_payload_branch_suffix_module(120, 8)
  for sample = 0; sample < 15; sample = sample + 1 {
    let start = @lib.trace_now_us()
    match @passes.pass_test_run_pipeline(input, ["flatten"]) {
      Ok(_) => ()
      Err(err) => fail("expected flatten suffix benchmark success, got \{err}")
    }
    println(
      "sample=\{sample} us=\{@lib.trace_elapsed_us_since(start)} functions=120 branches=960",
    )
  }
}

///|
fn flatten_perf_nested_no_fallthrough_module(
  function_count : Int,
  regions_per_function : Int,
  dead_roots_per_region : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  for function_idx = 0
      function_idx < function_count
      function_idx = function_idx + 1 {
    out.write_string("  (func\n")
    for region_idx = 0
        region_idx < regions_per_function
        region_idx = region_idx + 1 {
      let value = function_idx + region_idx
      out.write_string("    (drop (block (result i32)\n")
      out.write_string("      (drop (block (result i32) (i32.const ")
      out.write_string(value.to_string())
      out.write_string(") br 0")
      for dead_idx = 0
          dead_idx < dead_roots_per_region
          dead_idx = dead_idx + 1 {
        out.write_string(" (i32.const ")
        out.write_string((value + dead_idx + 1).to_string())
        out.write_string(") drop")
      }
      out.write_string(" (i32.const 0)))\n")
      out.write_string("      (i32.const ")
      out.write_string(value.to_string())
      out.write_string(")))\n")
    }
    out.write_string("  )\n")
  }
  out.write_string(")\n")
  out.to_string()
}

///|
#skip("manual native-release nested no-fallthrough summary benchmark")
test "flatten long perf lane measures candidate-dense region summaries" {
  let input = flatten_perf_nested_no_fallthrough_module(24, 32, 64)
  for sample = 0; sample < 15; sample = sample + 1 {
    let start = @lib.trace_now_us()
    match @passes.pass_test_run_pipeline(input, ["flatten"]) {
      Ok(_) => ()
      Err(err) =>
        fail("expected flatten region-summary benchmark success, got \{err}")
    }
    println(
      "sample=\{sample} us=\{@lib.trace_elapsed_us_since(start)} functions=24 regions=768 dead_roots=49152",
    )
  }
}

///|
#skip("manual native-release sequenced-root lookup benchmark")
test "flatten long perf lane measures sequenced-root pair lookup" {
  for candidate_count in [256, 512] {
    let holders : Array[Int] = []
    let nodes : Array[Int] = []
    for candidate = 0; candidate < candidate_count; candidate = candidate + 1 {
      holders.push(candidate / 8)
      nodes.push(candidate * 2 + 1)
    }
    for sample = 0; sample < 15; sample = sample + 1 {
      let start = @lib.trace_now_us()
      let mut found = 0
      for query = 0; query < 1048576; query = query + 1 {
        let wanted = query % candidate_count
        for idx = 0; idx < nodes.length(); idx = idx + 1 {
          if holders[idx] == holders[wanted] && nodes[idx] == nodes[wanted] {
            found = found + 1
            break
          }
        }
      }
      assert_true(
        found == 1048576,
        msg="expected every sequenced-root pair lookup to resolve, got \{found}",
      )
      println(
        "pairs=\{candidate_count} sample=\{sample} us=\{@lib.trace_elapsed_us_since(start)} found=\{found}",
      )
    }
  }
}
