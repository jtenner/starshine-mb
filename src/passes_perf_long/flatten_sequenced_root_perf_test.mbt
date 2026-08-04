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
fn flatten_perf_local_dependency_module(
  local_count : Int,
  candidate_count : Int,
  spread_writes : Bool,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module (func (param i32)")
  for local_id = 1; local_id < local_count; local_id = local_id + 1 {
    out.write_string(" (local i32)")
  }
  out.write_string("\n")
  for candidate = 0; candidate < candidate_count; candidate = candidate + 1 {
    let local_id = if spread_writes {
      1 + candidate % (local_count - 1)
    } else {
      1 + candidate % 8
    }
    out.write_string(" (drop (i32.add (local.get ")
    out.write_string(local_id.to_string())
    out.write_string(") (local.tee ")
    out.write_string(local_id.to_string())
    out.write_string(" (i32.add (i32.const ")
    out.write_string(candidate.to_string())
    out.write_string(") (i32.const 1)))))\n")
  }
  out.write_string("))")
  out.to_string()
}

///|
#skip("manual native-release reusable local-write dependency scratch benchmark")
test "flatten long perf lane measures local dependency scratch" {
  for spread_writes in [false, true] {
    let input = flatten_perf_local_dependency_module(4096, 2048, spread_writes)
    for sample = 0; sample < 15; sample = sample + 1 {
      let start = @lib.trace_now_us()
      match @passes.pass_test_run_pipeline(input, ["flatten"]) {
        Ok(_) => ()
        Err(err) =>
          fail(
            "expected flatten local dependency benchmark success, got \{err}",
          )
      }
      println(
        "sample=\{sample} us=\{@lib.trace_elapsed_us_since(start)} locals=4096 candidates=2048 spread=\{spread_writes}",
      )
    }
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

///|
fn flatten_perf_candidate_binary(
  func : @ir.HotFunc,
  instr : @lib.Instruction,
  left : Int,
  right : Int,
) -> Int {
  let node = @ir.hot_build_binary(func, @lib.ValType::i32(), left, right)
  @ir.hot_node_exact_instr_set(func, node, instr)
  node
}

///|
fn flatten_perf_candidate_argument(func : @ir.HotFunc, family : Int) -> Int {
  let mul0 = flatten_perf_candidate_binary(
    func,
    @lib.Instruction::i32_mul(),
    @ir.hot_build_const_i32(func, @lib.I32(9)),
    @ir.hot_build_const_i32(func, @lib.I32(10)),
  )
  if family == 0 {
    return flatten_perf_candidate_binary(
      func,
      @lib.Instruction::i32_add(),
      mul0,
      @ir.hot_build_const_i32(func, @lib.I32(11)),
    )
  }
  let mul1 = flatten_perf_candidate_binary(
    func,
    @lib.Instruction::i32_mul(),
    @ir.hot_build_const_i32(func, @lib.I32(11)),
    @ir.hot_build_const_i32(func, @lib.I32(12)),
  )
  let pair = flatten_perf_candidate_binary(
    func,
    if family == 1 {
      @lib.Instruction::i32_sub()
    } else {
      @lib.Instruction::i32_add()
    },
    mul0,
    mul1,
  )
  if family == 1 {
    pair
  } else {
    flatten_perf_candidate_binary(
      func,
      @lib.Instruction::i32_add(),
      pair,
      @ir.hot_build_const_i32(func, @lib.I32(13)),
    )
  }
}

///|
fn flatten_perf_candidate_func(family : Int) -> @ir.HotFunc {
  let func = @ir.HotFunc::new()
  let i32_type = @lib.ValType::i32()
  @ir.hot_body_result_type_set(func, @ir.hot_type_intern_value(func, i32_type))
  let fallback = @ir.hot_build_const_i32(func, @lib.I32(1))
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(i32_type),
    [fallback],
    catch_body=Some([@ir.hot_build_const_i32(func, @lib.I32(27))]),
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let table = @ir.hot_build_br_table(
    func,
    [label_id],
    label_id,
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    values=[@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let argument = flatten_perf_candidate_argument(func, family)
  let call = @ir.hot_build_call(func, 99, [], [argument])
  let dead_end = @ir.hot_build_unreachable(func)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, try_id), [
    table, call, dead_end,
  ])
  @ir.hot_delete_node(func, fallback)
  @ir.hot_root_append(func, @ir.hot_build_return(func, [try_id]))
  func
}

///|
fn flatten_perf_candidate_batch() -> Array[@ir.HotFunc] {
  let funcs : Array[@ir.HotFunc] = []
  for index = 0; index < 120; index = index + 1 {
    funcs.push(flatten_perf_candidate_func(index / 40))
  }
  funcs
}

///|
#skip("manual native-release historical 120-function candidate-dense benchmark")
test "flatten long perf lane remeasures the historical candidate-dense contract" {
  let batches : Array[Array[@ir.HotFunc]] = []
  for batch_idx = 0; batch_idx < 25; batch_idx = batch_idx + 1 {
    batches.push(flatten_perf_candidate_batch())
  }
  for sample = 0; sample < batches.length(); sample = sample + 1 {
    let start = @lib.trace_now_us()
    for func in batches[sample] {
      let ctx = @passes.HotPassContext::new(
        @passes.flatten_descriptor(),
        @ir.HotAnalysisCache::new(),
        @passes.HotPipelineVerifyPolicy::after_each_pass(),
        false,
        fn(_) { () },
      )
      ignore(@passes.flatten_run(ctx, func))
    }
    let elapsed = @lib.trace_elapsed_us_since(start)
    if sample >= 5 {
      println(
        "sample=\{sample - 5} us=\{elapsed} functions=120 families=40,40,40",
      )
    }
  }
}
