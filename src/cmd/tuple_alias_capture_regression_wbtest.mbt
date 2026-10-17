///|
// This executor covers the integer and structured-control instructions in the
// fixtures below. Unsupported instructions fail, and a fuel bound catches a
// changed loop exit. All result blocks are branch-free; loop branches carry no
// values, so no result-block stack unwind is needed.
fn tuple_alias_cmd_execute(func : @lib.Func) -> Int32 raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = func
  let locals = Array::make(body_locals.length(), 0)
  let stack : Array[Int32] = []
  let mut fuel = 1000
  fn execute(instrs : Array[@lib.Instruction]) -> Int32? raise {
    for instr in instrs {
      fuel -= 1
      assert_true(fuel >= 0, msg="tuple alias fixture exceeded its fuel bound")
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
        @lib.I32Eqz => stack.push(if stack.pop().unwrap() == 0 { 1 } else { 0 })
        @lib.I32Add | @lib.I32Eq | @lib.I32LtS => {
          let rhs = stack.pop().unwrap()
          let lhs = stack.pop().unwrap()
          stack.push(
            match instr {
              @lib.I32Add => lhs + rhs
              @lib.I32Eq => if lhs == rhs { 1 } else { 0 }
              _ => if lhs < rhs { 1 } else { 0 }
            },
          )
        }
        @lib.Block(_, @lib.Expr(nested)) =>
          @debug.assert_eq(execute(nested), None)
        @lib.Loop(block_type, @lib.Expr(nested)) => {
          assert_true(block_type is @lib.VoidBlockType)
          let base = stack.length()
          let mut again = true
          while again {
            match execute(nested) {
              Some(0) => @debug.assert_eq(stack.length(), base)
              Some(depth) => return Some(depth - 1)
              None => again = false
            }
          }
        }
        @lib.If(block_type, then_body, else_body) => {
          assert_true(block_type is @lib.VoidBlockType)
          let condition = stack.pop().unwrap()
          @debug.assert_eq(
            execute(if condition != 0 { then_body } else { else_body.or([]) }),
            None,
          )
        }
        @lib.BrIf(@lib.LabelIdx(depth)) =>
          if stack.pop().unwrap() != 0 {
            return Some(depth.to_int())
          }
        _ => fail("unsupported tuple alias fixture instruction: \{instr}")
      }
    }
    None
  }
  @debug.assert_eq(execute(body), None)
  @debug.assert_eq(stack.length(), 1)
  stack[0]
}

///|
test "tuple-optimization command preserves captured loop values in encoded output" {
  for trailing in [false, true] {
    let copy = if trailing {
      "block (result i32) local.get $saved_a " +
      "local.get $saved_b local.set $out_b end local.set $out_a "
    } else {
      "block (result i32) local.get $saved_b local.set $out_b " +
      "local.get $saved_a end local.set $out_a "
    }
    let source = "(module (type $pair (func (result i32 i32))) " +
      "(func (export \"run\") (result i32) " +
      "(local $a i32) (local $b i32) " +
      "(local $saved_a i32) (local $saved_b i32) " +
      "(local $out_a i32) (local $out_b i32) (local $iteration i32) " +
      "loop $again block (type $pair) " +
      "local.get $iteration i32.const 11 i32.add " +
      "local.get $iteration i32.const 100 i32.add end " +
      "local.set $b local.set $a local.get $iteration i32.eqz if " +
      "local.get $a local.set $saved_a local.get $b local.set $saved_b end " +
      copy +
      "local.get $iteration i32.const 1 i32.add local.tee $iteration " +
      "i32.const 2 i32.lt_s br_if $again end " +
      "local.get $out_a local.get $out_b i32.add))"
    let original = @passes.pass_test_module_from_wat(source)
    ignore(@validate.validate_module(original).unwrap())
    @debug.assert_eq(
      tuple_alias_cmd_execute(original.code_sec.unwrap().0[0]),
      111,
    )
    let wasm = encode_module_bytes(original)
    let writes : Array[(String, Bytes)] = []
    let io = CmdIO::new(
      list_candidates=fn() { ["tuple-alias.wasm"] },
      file_exists=fn(path) { path == "tuple-alias.wasm" },
      read_file=fn(path) {
        if path == "tuple-alias.wasm" {
          Ok(wasm)
        } else {
          Err("missing tuple alias fixture")
        }
      },
      write_file=fn(path, bytes) {
        writes.push((path, bytes))
        Ok(())
      },
    )
    let summary = run_cmd_with_adapter(
      ["--tuple-optimization", "--out", "out.wasm", "tuple-alias.wasm"],
      io,
    ).unwrap()
    @debug.assert_eq(summary.resolved_passes, ["tuple-optimization"])
    @debug.assert_eq(writes.length(), 1)
    @debug.assert_eq(writes[0].0, "out.wasm")
    let output = decode_module_bytes(writes[0].1)
    ignore(@validate.validate_module(output).unwrap())
    @debug.assert_eq(
      tuple_alias_cmd_execute(output.code_sec.unwrap().0[0]),
      111,
    )
  }
}
