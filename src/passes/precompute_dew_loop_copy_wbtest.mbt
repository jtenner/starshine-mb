///|
fn precompute_dew_loop_copy_module() -> @lib.Module {
  pass_test_module_from_wat(
    (
      #|(module (func (export "run") (result i32) (local i32 i32 i32)
      #| i32.const 5 local.set 0
      #|    i32.const 3
      #|    i32.const 0
      #|    local.set 2
      #|    local.set 1
      #|    block ;; label = @1
      #|      loop ;; label = @2
      #|        block ;; label = @3
      #|          i32.const 1
      #|          if ;; label = @4
      #|            local.get 1
      #|            local.set 0
      #|            local.get 0
      #|            i32.const 0
      #|            i32.gt_s
      #|            if (result i32) ;; label = @5
      #|              local.get 0
      #|              i32.const 1
      #|              i32.sub
      #|              local.set 1
      #|              br 3 (;@2;)
      #|            else
      #|              i32.const 0
      #|            end
      #|            drop
      #|            i32.const 0
      #|            if (result i32) ;; label = @5
      #|              i32.const 1
      #|            else
      #|              i32.const 9
      #|              local.set 2
      #|              br 4 (;@1;)
      #|            end
      #|            drop
      #|            i32.const 0
      #|            local.set 2
      #|            br 3 (;@1;)
      #|            br 1 (;@3;)
      #|          end
      #|          unreachable
      #|        end
      #|        unreachable
      #|      end
      #|      unreachable
      #|    end
      #|    local.get 2
      #|))
    ),
  )
}

///|
fn precompute_dew_loop_copy_execute(func : @lib.Func) -> Int raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = func
  let locals = Array::make(body_locals.length(), 0)
  let stack : Array[Int] = []
  let mut fuel = 500
  fn execute(instrs : Array[@lib.Instruction]) -> Int? raise {
    for instr in instrs {
      fuel -= 1
      assert_true(fuel >= 0, msg="loop did not exit within 500 instructions")
      match instr {
        @lib.Nop => ()
        @lib.Drop => ignore(stack.pop().unwrap())
        @lib.I32Const(@lib.I32(value)) => stack.push(value)
        @lib.LocalGet(@lib.LocalIdx(index)) =>
          stack.push(locals[index.to_int()])
        @lib.LocalSet(@lib.LocalIdx(index)) =>
          locals[index.to_int()] = stack.pop().unwrap()
        @lib.LocalTee(@lib.LocalIdx(index)) =>
          locals[index.to_int()] = stack[stack.length() - 1]
        @lib.I32Sub | @lib.I32GtS => {
          let rhs = stack.pop().unwrap()
          let lhs = stack.pop().unwrap()
          stack.push(
            match instr {
              @lib.I32Sub => lhs - rhs
              _ => if lhs > rhs { 1 } else { 0 }
            },
          )
        }
        @lib.Br(@lib.LabelIdx(depth)) => return Some(depth.to_int())
        @lib.Block(block_type, @lib.Expr(nested)) => {
          let base = stack.length()
          match execute(nested) {
            Some(depth) if depth > 0 => return Some(depth - 1)
            Some(_) => {
              assert_true(block_type is @lib.VoidBlockType)
              while stack.length() > base {
                ignore(stack.pop())
              }
            }
            None => ()
          }
        }
        @lib.Loop(block_type, @lib.Expr(nested)) => {
          assert_true(block_type is @lib.VoidBlockType)
          let base = stack.length()
          let mut again = true
          while again {
            match execute(nested) {
              Some(0) =>
                while stack.length() > base {
                  ignore(stack.pop())
                }
              Some(depth) => return Some(depth - 1)
              None => again = false
            }
          }
        }
        @lib.If(block_type, then_body, else_body) => {
          let condition = stack.pop().unwrap()
          let base = stack.length()
          let nested = if condition != 0 { then_body } else { else_body.or([]) }
          match execute(nested) {
            Some(depth) if depth > 0 => return Some(depth - 1)
            Some(_) => {
              assert_true(block_type is @lib.VoidBlockType)
              while stack.length() > base {
                ignore(stack.pop())
              }
            }
            None => ()
          }
        }
        _ => fail("unexpected loop-copy instruction: \{instr}")
      }
    }
    None
  }
  @debug.assert_eq(execute(body), None)
  @debug.assert_eq(stack.length(), 1)
  stack[0]
}

///|
test "precompute-propagate retains the changing loop counter through a local copy" {
  let template = precompute_dew_loop_copy_module()
  let @lib.Func(body_locals, @lib.Expr(body)) = template.code_sec.unwrap().0[0]
  for stale in [-1, 0, 5] {
    for counter in [0, 1, 3, 7] {
      let variant = body.copy()
      variant[0] = @lib.Instruction::i32_const(@lib.I32(stale))
      variant[2] = @lib.Instruction::i32_const(@lib.I32(counter))
      let input = template.with_code_sec(
        @lib.CodeSec::new([@lib.Func::new(body_locals, @lib.Expr::new(variant))]),
      )
      ignore(@validate.validate_module(input).unwrap())
      @debug.assert_eq(
        precompute_dew_loop_copy_execute(input.code_sec.unwrap().0[0]),
        9,
      )
      let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
        "precompute-propagate",
      ]).unwrap()
      ignore(@validate.validate_module(output).unwrap())
      @debug.assert_eq(
        precompute_dew_loop_copy_execute(output.code_sec.unwrap().0[0]),
        9,
      )
      assert_true(
        output.code_sec != input.code_sec,
        msg="constant conditions must still fold",
      )
    }
  }
}

///|
test "precompute loop copy reaching writes include the body copy" {
  let func = @ir.hot_lift_func(
    precompute_dew_loop_copy_module(),
    @lib.FuncIdx::new(0U),
  )
  let cfg = @ir.cfg_build(func, expand_operand_control=true)
  let graph = @ir.local_graph_build(func, cfg)
  let mut writes = 0
  let mut gets = 0
  let mut copy = -1
  for id = 0; id < @ir.hot_node_count(func); id = id + 1 {
    if !@ir.hot_node_is_live(func, id) {
      continue
    }
    let node = @ir.hot_node_get(func, id)
    if node.op is @ir.HotOp::LocalSet && node.imm0 == 0 {
      writes += 1
      let child = @ir.hot_child_get(func, id, 0)
      if @ir.hot_node_get(func, child).op is @ir.HotOp::LocalGet {
        copy = id
      }
    }
  }
  assert_true(copy >= 0)
  @debug.assert_eq(writes, 2)
  for id = 0; id < @ir.hot_node_count(func); id = id + 1 {
    if !@ir.hot_node_is_live(func, id) {
      continue
    }
    let node = @ir.hot_node_get(func, id)
    if node.op is @ir.HotOp::LocalGet && node.imm0 == 0 {
      gets += 1
      let sources = @ir.local_graph_reaching_sources_for_get(graph, id)
      @debug.assert_eq(sources.length(), 1)
      assert_true(
        sources[0] is @ir.HotLocalGraphSource::SetSource(write) && write == copy,
        msg="loop read must reach the current body copy",
      )
    }
  }
  @debug.assert_eq(gets, 2)
}
