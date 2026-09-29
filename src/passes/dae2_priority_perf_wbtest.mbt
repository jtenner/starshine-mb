///|
fn dae2_priority_graph_bench(
  it : @bench.T,
  bodies : Int,
  nodes : Int,
  bulk : Bool,
) -> Unit {
  it.bench(fn() {
    let graph = Dae2Graph::new()
    let mut checksum = 0
    for _ in 0..<bodies {
      if bulk {
        checksum += graph.locations(nodes)
      } else {
        let first = graph.location()
        for _ in 1..<nodes {
          ignore(graph.location())
        }
        checksum += first
      }
    }
    it.keep((checksum, graph.used.length(), graph.first_edge, graph.last_edge))
  })
}

///|
fn dae2_priority_fixture(pairs : Int, reads : Int, pinned : Int) -> @lib.Module {
  let wat = ["(module (global $g (mut i32) (i32.const 0))"]
  for index in 0..<pairs {
    wat.push(
      "(func $h\{index} (param i32 i32 i32) (result i32) local.get 1 i32.const 1 i32.add local.set 1 local.get 1",
    )
    for _ in 1..<reads {
      wat.push("local.get 1 i32.add")
    }
    wat.push(")")
    wat.push(
      "(func (export \"run\{index}\") (param i32) (result i32) i32.const 9 local.get 0 i32.const 8 call $h\{index})",
    )
  }
  for index in 0..<pinned {
    wat.push(
      "(func (export \"keep\{index}\") (param i32) (result i32) local.get 0 global.set $g local.get 0",
    )
    for _ in 1..<reads {
      wat.push("local.get 0 i32.add")
    }
    wat.push(")")
  }
  wat.push(")")
  pass_test_module_from_wat(wat.join(" "))
}

///|
fn dae2_priority_pipeline_bench(
  it : @bench.T,
  pairs : Int,
  reads : Int,
  pinned : Int,
  optimizing : Bool,
) -> Unit {
  let input = dae2_priority_fixture(pairs, reads, pinned)
  let saved = @binary.encode_module(input).unwrap()
  let pass = if optimizing { "dae2-optimizing" } else { "dae2" }
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [pass]).unwrap()
  @validate.validate_module(output).unwrap()
  let context = @ir.hot_module_context_from_module(output)
  for index in 0..<pairs {
    if @ir.hot_module_resolve_func_type(
        context,
        @lib.FuncIdx::new((index * 2).to_uint()),
      ) !=
      Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])) {
      abort(
        "entry-write benchmark lost its live input or retained dead arguments",
      )
    }
    let @lib.Func(_, @lib.Expr(caller)) = output.code_sec.unwrap().0[index * 2 +
      1]
    if caller !=
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::call(@lib.FuncIdx::new((index * 2).to_uint())),
      ] {
      abort("entry-write benchmark changed retained caller arguments")
    }
  }
  for index in (pairs * 2)..<(pairs * 2 + pinned) {
    if output.code_sec.unwrap().0[index] != input.code_sec.unwrap().0[index] {
      abort("pinned-body benchmark changed an unrelated body")
    }
  }
  it.bench(fn() {
    it.keep(run_hot_pipeline(input, HotPipelineOptions::new(), [pass]))
  })
  if @binary.encode_module(input).unwrap() != saved {
    abort("DAE2 priority benchmark mutated its input")
  }
}

///|
test "bench DAE2 graph scalar bodies=1 nodes=4096" (it : @bench.T) {
  dae2_priority_graph_bench(it, 1, 4096, false)
}

///|
test "bench DAE2 graph bulk bodies=1 nodes=4096" (it : @bench.T) {
  dae2_priority_graph_bench(it, 1, 4096, true)
}

///|
test "bench DAE2 graph scalar bodies=1024 nodes=8" (it : @bench.T) {
  dae2_priority_graph_bench(it, 1024, 8, false)
}

///|
test "bench DAE2 graph bulk bodies=1024 nodes=8" (it : @bench.T) {
  dae2_priority_graph_bench(it, 1024, 8, true)
}

///|
test "bench DAE2 entry writes pairs=1 reads=1" (it : @bench.T) {
  dae2_priority_pipeline_bench(it, 1, 1, 0, false)
}

///|
test "bench DAE2 optimizing entry writes pairs=1 reads=1" (it : @bench.T) {
  dae2_priority_pipeline_bench(it, 1, 1, 0, true)
}

///|
test "bench DAE2 entry writes pairs=32 reads=128" (it : @bench.T) {
  dae2_priority_pipeline_bench(it, 32, 128, 0, false)
}

///|
test "bench DAE2 optimizing entry writes pairs=32 reads=128" (it : @bench.T) {
  dae2_priority_pipeline_bench(it, 32, 128, 0, true)
}

///|
test "bench DAE2 pinned siblings pairs=1 reads=128 pinned=128" (it : @bench.T) {
  dae2_priority_pipeline_bench(it, 1, 128, 128, false)
}

///|
test "bench DAE2 optimizing pinned siblings pairs=1 reads=128 pinned=128" (
  it : @bench.T,
) {
  dae2_priority_pipeline_bench(it, 1, 128, 128, true)
}
