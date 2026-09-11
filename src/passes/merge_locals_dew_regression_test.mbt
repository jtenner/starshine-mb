///|
fn merge_locals_dew_seven_exit(
  body : Array[@lib.Instruction],
) -> @lib.LabelIdx? {
  for idx = 0; idx + 2 < body.length(); idx = idx + 1 {
    match (body[idx], body[idx + 1], body[idx + 2]) {
      (@lib.I32Const(@lib.I32(7)), @lib.LocalSet(_), @lib.Br(target)) =>
        return Some(target)
      _ => ()
    }
  }
  for instr in body {
    let regions = match instr {
      @lib.Block(_, @lib.Expr(roots)) | @lib.Loop(_, @lib.Expr(roots)) =>
        [roots]
      @lib.If(_, then_, Some(else_)) => [then_, else_]
      @lib.If(_, then_, None) => [then_]
      _ => []
    }
    for roots in regions {
      match merge_locals_dew_seven_exit(roots) {
        Some(target) => return Some(target)
        None => ()
      }
    }
  }
  None
}

///|
test "merge-locals keeps nested branch targets inside a new value wrapper" {
  let input = pass_test_module_from_wat(
    (
      #|(module (func (export "run") (param i32) (result i32) (local i32 i32 i32)
      #| block $out
      #|  local.get 0 if
      #|   block $mid
      #|    local.get 0 if
      #|     block $in
      #|      local.get 0 if
      #|       local.get 0 if i32.const 7 local.set 1 br $in end
      #|      end
      #|      i32.const 1 if i32.const 8 local.set 1 br $in end
      #|      unreachable
      #|     end
      #|     local.get 1 local.set 2 br $mid
      #|    end
      #|    i32.const 1 if i32.const 9 local.set 2 br $mid end
      #|    unreachable
      #|   end
      #|   local.get 2 local.set 3 br $out
      #|  end
      #|  i32.const 1 if i32.const 10 local.set 3 br $out end
      #|  unreachable
      #| end local.get 3))
    ),
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "merge-locals",
  ]).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  // The branch exits its block through two if labels, even when an ancestor
  // gains a value wrapper. It must not skip the copy of 7 into the next local.
  @debug.assert_eq(
    merge_locals_dew_seven_exit(body),
    Some(@lib.LabelIdx::new(2U)),
  )
  assert_true(output.code_sec != input.code_sec)
  ignore(@validate.validate_module(output).unwrap())
}
