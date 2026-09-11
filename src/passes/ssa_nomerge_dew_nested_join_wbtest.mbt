///|
fn ssa_dew_nested_join_module() -> @lib.Module {
  @wast.wast_to_binary_module(
    (
      #|(module
      #| (func (export "run") (param i32 i32) (result i32) (local i32)
      #|  block
      #|   local.get 0
      #|   if
      #|    block
      #|     local.get 1
      #|     if i32.const 42 local.set 2 br 1 end
      #|     i32.const 1
      #|     if i32.const 41 local.set 2 br 1 end
      #|     unreachable
      #|    end
      #|    br 1
      #|   end
      #|   i32.const 1
      #|   if i32.const 9 local.set 2 br 1 end
      #|   unreachable
      #|  end
      #|  local.get 2))
    ),
  ).unwrap()
}

///|
fn ssa_dew_nested_join_execute(
  func : @lib.Func,
  params : Array[Int],
) -> Int raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = func
  let locals = Array::make(params.length() + body_locals.length(), 0)
  for index, value in params {
    locals[index] = value
  }
  let stack : Array[Int] = []
  fn execute(instrs : Array[@lib.Instruction]) -> Int? raise {
    for instr in instrs {
      match instr {
        @lib.Nop => ()
        @lib.I32Const(@lib.I32(value)) => stack.push(value)
        @lib.LocalGet(@lib.LocalIdx(idx)) =>
          stack.push(locals[idx.reinterpret_as_int()])
        @lib.LocalSet(@lib.LocalIdx(idx)) =>
          locals[idx.reinterpret_as_int()] = stack.pop().unwrap()
        @lib.LocalTee(@lib.LocalIdx(idx)) =>
          locals[idx.reinterpret_as_int()] = stack[stack.length() - 1]
        @lib.Br(@lib.LabelIdx(depth)) => return Some(depth.reinterpret_as_int())
        @lib.Block(_, @lib.Expr(nested)) =>
          match execute(nested) {
            Some(depth) if depth > 0 => return Some(depth - 1)
            _ => ()
          }
        @lib.If(_, then_body, else_body) => {
          let nested = if stack.pop().unwrap() != 0 {
            then_body
          } else {
            else_body.or([])
          }
          match execute(nested) {
            Some(depth) if depth > 0 => return Some(depth - 1)
            _ => ()
          }
        }
        _ => fail("unexpected nested-join instruction: \{instr}")
      }
    }
    None
  }
  @debug.assert_eq(execute(body), None)
  @debug.assert_eq(stack.length(), 1)
  stack[0]
}

///|
test "ssa-nomerge local graph keeps all nested branch join sources" {
  let input = ssa_dew_nested_join_module()
  let hot = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let graph = @ir.local_graph_build(hot, @ir.cfg_build(hot))
  let roots = @ir.hot_root_span(hot)
  let get = roots[roots.length() - 1]
  assert_true(@ir.hot_node_get(hot, get).op is @ir.HotOp::LocalGet)
  let sources = @ir.local_graph_reaching_sources_for_get(graph, get)
  @debug.assert_eq(sources.length(), 3)
  for source in sources {
    assert_true(source is @ir.HotLocalGraphSource::SetSource(_))
  }
}

///|
test "ssa-nomerge preserves values across nested branch joins" {
  let input = ssa_dew_nested_join_module()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "ssa-nomerge",
  ]).unwrap()
  ignore(@validate.validate_module(output).unwrap())
  for module_ in [input, output] {
    let func = module_.code_sec.unwrap().0[0]
    @debug.assert_eq(ssa_dew_nested_join_execute(func, [1, 1]), 42)
    @debug.assert_eq(ssa_dew_nested_join_execute(func, [1, 0]), 41)
    @debug.assert_eq(ssa_dew_nested_join_execute(func, [0, 0]), 9)
  }
}

///|
fn ssa_dew_assert_raw_live_inputs(
  source : String,
  expected : Array[Bool],
) -> Unit raise {
  let input = @wast.wast_to_binary_module(source).unwrap()
  ignore(@validate.validate_module(input).unwrap())
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let live = ssa_nomerge_raw_live_before(
    body,
    0,
    @bitset.BitSet::new(expected.length()),
    [],
  )
  for index, needed in expected {
    @debug.assert_eq(live[index], needed)
  }
}

///|
test "ssa-nomerge raw liveness keeps conditional entry values" {
  ssa_dew_assert_raw_live_inputs(
    (
      #|(module (func (param i32 i32)
      #| local.get 0 if i32.const 9 local.set 1 end
      #| local.get 1 drop))
    ),
    [true, true],
  )
  ssa_dew_assert_raw_live_inputs(
    (
      #|(module (func (param i32 i32)
      #| local.get 0
      #| if i32.const 9 local.set 1 else i32.const 7 local.set 1 end
      #| local.get 1 drop))
    ),
    [true, false],
  )
}

///|
test "ssa-nomerge raw liveness excludes writes after an exiting branch" {
  ssa_dew_assert_raw_live_inputs(
    (
      #|(module (func (param i32)
      #| block br 0 i32.const 9 local.set 0 end
      #| local.get 0 drop))
    ),
    [true],
  )
}

///|
test "ssa-nomerge raw liveness joins every branch table target" {
  ssa_dew_assert_raw_live_inputs(
    (
      #|(module (func (param i32 i32 i32)
      #| block
      #|   block local.get 0 br_table 0 1 end
      #|   local.get 1 drop
      #|   return
      #| end
      #| local.get 2 drop))
    ),
    [true, true, true],
  )
}

///|
test "ssa-nomerge raw liveness reaches a loop fixed point" {
  ssa_dew_assert_raw_live_inputs(
    (
      #|(module (func (param i32 i32 i32)
      #| loop
      #|   local.get 1 if br 0 end
      #|   local.get 2 local.set 1
      #|   local.get 0 br_if 0
      #| end))
    ),
    [true, true, true],
  )
}

///|
test "ssa-nomerge branch copy cleanup follows the rewritten copy destination" {
  let input = @wast.wast_to_binary_module(
    (
      #|(module (func (result i32) (local i32 i32 i32)
      #| block
      #|   i32.const 42 local.set 0
      #|   local.get 0 local.set 1
      #|   local.get 1 local.set 2
      #|   br 0
      #| end
      #| local.get 2))
    ),
  ).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let (rewritten, changed) = run_hot_pipeline_raw_ssa_nomerge_redirect_branch_alias_suffix(
    body,
  )
  assert_true(changed)
  let output = @lib.Func::new(locals, @lib.Expr::new(rewritten))
  @debug.assert_eq(
    ssa_dew_nested_join_execute(input.code_sec.unwrap().0[0], []),
    42,
  )
  @debug.assert_eq(ssa_dew_nested_join_execute(output, []), 42)
}
