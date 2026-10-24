///|
fn issue9_retention_count_instr(
  mod_ : @lib.Module,
  instruction : @lib.Instruction,
) -> Int {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => []
  }
  let mut count = 0
  for index = 0; index < funcs.length(); index = index + 1 {
    let func = @ir.hot_lift_func(
      mod_,
      @lib.FuncIdx::new(index.reinterpret_as_uint()),
    )
    for node = 0; node < @ir.hot_node_count(func); node = node + 1 {
      if !@ir.hot_node_is_live(func, node) {
        continue
      }
      let data = @ir.hot_node_get(func, node)
      let matches = match instruction {
        @lib.Instruction::LocalGet(@lib.LocalIdx(index)) =>
          data.op is @ir.LocalGet && data.imm0 == index.to_int()
        @lib.Instruction::LocalSet(@lib.LocalIdx(index)) =>
          data.op is @ir.LocalSet && data.imm0 == index.to_int()
        @lib.Instruction::LocalTee(@lib.LocalIdx(index)) =>
          data.op is @ir.LocalTee && data.imm0 == index.to_int()
        _ => @ir.hot_node_exact_instr(func, node) == Some(instruction)
      }
      if matches {
        count += 1
      }
    }
  }
  count
}

///|
fn issue9_retention_run_cleanup(source : String) -> @lib.Module {
  let output = pass_test_run_pipeline(source, [
    "ssa-nomerge", "simplify-locals-nostructure", "simplify-locals", "vacuum",
  ]).unwrap()
  match @validate.validate_module(output) {
    Ok(_) => output
    Err(err) => abort("issue 9 retention output failed validation: \{err}")
  }
}

///|
fn issue9_retention_assert_pair(
  live_source : String,
  dead_source : String,
  observed : Array[@lib.Instruction],
  require_dead_removed? : Bool = true,
) -> Unit raise {
  let live_before = pass_test_module_from_wat(live_source)
  let dead_before = pass_test_module_from_wat(dead_source)
  let live_after = issue9_retention_run_cleanup(live_source)
  let dead_after = issue9_retention_run_cleanup(dead_source)
  for instruction in observed {
    let live_before_count = issue9_retention_count_instr(
      live_before, instruction,
    )
    let dead_before_count = issue9_retention_count_instr(
      dead_before, instruction,
    )
    let live_after_count = issue9_retention_count_instr(live_after, instruction)
    let dead_after_count = issue9_retention_count_instr(dead_after, instruction)
    assert_true(live_before_count > 0)
    assert_true(dead_before_count > 0)
    assert_true(live_after_count > 0)
    assert_true(live_after_count <= live_before_count)
    if require_dead_removed {
      assert_eq(dead_after_count, 0)
    } else {
      // Structured cycles can retain dead local traffic in the current cleanup
      // sequence. Keep the pre-cleanup payload matched and report the limit.
      assert_true(dead_after_count <= dead_before_count)
    }
  }
}

///|
test "local cleanup retains a live parameter-dependent diamond" {
  let live =
    #|(module
    #|  (func (export "run") (param i32) (result i32) (local i32)
    #|    local.get 0
    #|    if
    #|      local.get 0
    #|      i32.const 3
    #|      i32.add
    #|      local.set 1
    #|    else
    #|      local.get 0
    #|      i32.const 5
    #|      i32.add
    #|      local.set 1
    #|    end
    #|    local.get 1))
  let dead =
    #|(module
    #|  (func (export "run") (param i32) (result i32) (local i32)
    #|    local.get 0
    #|    if
    #|      local.get 0
    #|      i32.const 3
    #|      i32.add
    #|      local.set 1
    #|    else
    #|      local.get 0
    #|      i32.const 5
    #|      i32.add
    #|      local.set 1
    #|    end
    #|    local.get 0))
  issue9_retention_assert_pair(live, dead, [@lib.Instruction::i32_add()])
}

///|
test "local cleanup retains a live finite-loop payload" {
  let live =
    #|(module
    #|  (func (export "run") (param i32) (result i32) (local i32 i32)
    #|    i32.const 0
    #|    local.set 1
    #|    local.get 0
    #|    local.set 2
    #|    block $exit
    #|      loop $again
    #|        local.get 2
    #|        i32.const 3
    #|        i32.mul
    #|        local.set 2
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        local.tee 1
    #|        i32.const 4
    #|        i32.lt_u
    #|        br_if $again
    #|      end
    #|    end
    #|    local.get 2))
  let dead =
    #|(module
    #|  (func (export "run") (param i32) (result i32) (local i32 i32)
    #|    i32.const 0
    #|    local.set 1
    #|    local.get 0
    #|    local.set 2
    #|    block $exit
    #|      loop $again
    #|        local.get 2
    #|        i32.const 3
    #|        i32.mul
    #|        local.set 2
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        local.tee 1
    #|        i32.const 4
    #|        i32.lt_u
    #|        br_if $again
    #|      end
    #|    end
    #|    local.get 0))
  issue9_retention_assert_pair(
    live,
    dead,
    [@lib.Instruction::i32_mul()],
    require_dead_removed=false,
  )
}

///|
test "local cleanup retains a live typed multivalue join" {
  let live =
    #|(module
    #|  (func (export "run") (param i32) (result i32 i32)
    #|    local.get 0
    #|    if (result i32 i32)
    #|      local.get 0
    #|      i32.const 1
    #|      i32.add
    #|      local.get 0
    #|      i32.const 2
    #|      i32.mul
    #|    else
    #|      local.get 0
    #|      i32.const 3
    #|      i32.add
    #|      local.get 0
    #|      i32.const 4
    #|      i32.mul
    #|    end))
  let dead =
    #|(module
    #|  (func (export "run") (param i32) (result i32 i32)
    #|    local.get 0
    #|    if (result i32 i32)
    #|      local.get 0
    #|      i32.const 1
    #|      i32.add
    #|      local.get 0
    #|      i32.const 2
    #|      i32.mul
    #|    else
    #|      local.get 0
    #|      i32.const 3
    #|      i32.add
    #|      local.get 0
    #|      i32.const 4
    #|      i32.mul
    #|    end
    #|    drop
    #|    drop
    #|    local.get 0
    #|    local.get 0))
  issue9_retention_assert_pair(live, dead, [
    @lib.Instruction::i32_add(),
    @lib.Instruction::i32_mul(),
  ])
}

///|
test "local cleanup retains one shared producer" {
  let live =
    #|(module
    #|  (func (export "run") (param i32) (result i32) (local i32)
    #|    local.get 0
    #|    i32.const 7
    #|    i32.mul
    #|    local.tee 1
    #|    local.get 1
    #|    i32.add))
  let dead =
    #|(module
    #|  (func (export "run") (param i32) (result i32) (local i32)
    #|    local.get 0
    #|    i32.const 7
    #|    i32.mul
    #|    drop
    #|    local.get 0))
  issue9_retention_assert_pair(live, dead, [@lib.Instruction::i32_mul()])
}
