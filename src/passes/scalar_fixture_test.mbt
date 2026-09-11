///|
// Independent, bounded stack evaluation for integer-only local-lifetime
// regressions. Unsupported fixture instructions fail instead of being ignored.
enum ScalarFixtureFlow {
  Next
  Branch(Int)
  Returned
}

///|
fn scalar_fixture_run(
  func : @lib.Func,
  args : Array[Int64],
  globals? : Array[Int64] = [],
  call_params? : Array[Int] = [],
  call? : ((UInt, Array[Int64]) -> Array[Int64])? = None,
  load? : ((Int64) -> Int64)? = None,
  array_new? : ((Int64, Int64) -> Int64)? = None,
) -> Array[Int64] raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = func
  let locals = args.copy()
  for _ in 0..<body_locals.length() {
    locals.push(0L)
  }
  let stack : Array[Int64] = []
  let mut steps = 0
  fn arity(bt : @lib.BlockType) -> Int raise {
    match bt {
      @lib.VoidBlockType => 0
      @lib.ValTypeBlockType(_) => 1
      _ => fail("scalar fixture requires a direct block result type")
    }
  }
  fn finish(base : Int, result_count : Int) -> Unit raise {
    if stack.length() < base + result_count {
      fail("scalar fixture stack underflow")
    }
    let results : Array[Int64] = []
    for i = stack.length() - result_count; i < stack.length(); i = i + 1 {
      results.push(stack[i])
    }
    while stack.length() > base {
      ignore(stack.pop())
    }
    for value in results {
      stack.push(value)
    }
  }
  fn execute(body : Array[@lib.Instruction]) -> ScalarFixtureFlow raise {
    for instr in body {
      steps += 1
      if steps > 10000 {
        fail("scalar fixture execution budget exceeded")
      }
      match instr {
        @lib.Nop => ()
        @lib.GlobalGet(@lib.GlobalIdx(index)) =>
          stack.push(globals[index.to_int()])
        @lib.GlobalSet(@lib.GlobalIdx(index)) =>
          globals[index.to_int()] = stack.pop().unwrap()
        @lib.F32Const(@lib.F32(value)) =>
          stack.push(value.reinterpret_as_int().to_int64())
        @lib.F32Nearest => {
          let value = stack[stack.length() - 1].to_int().reinterpret_as_float()
          if value != value.trunc() {
            fail("fixture nearest supports integral inputs only")
          }
        }
        @lib.F32Eq => {
          let rhs = stack.pop().unwrap().to_int().reinterpret_as_float()
          let lhs = stack.pop().unwrap().to_int().reinterpret_as_float()
          stack.push(if lhs == rhs { 1L } else { 0L })
        }
        @lib.I32ReinterpretF32 => () // float values are stored as their bits
        @lib.I64ExtendI32U =>
          stack.push(
            stack.pop().unwrap().to_int().reinterpret_as_uint().to_int64(),
          )
        // This fixture uses splats only, so both i64 vector lanes are equal.
        @lib.I16x8Splat => {
          let lane = stack.pop().unwrap() & 0xffffL
          stack.push(lane | (lane << 16) | (lane << 32) | (lane << 48))
        }
        @lib.I64x2AllTrue =>
          stack.push(if stack.pop().unwrap() == 0L { 0L } else { 1L })
        @lib.I32Xor | @lib.I64Xor => {
          let rhs = stack.pop().unwrap()
          let lhs = stack.pop().unwrap()
          stack.push(
            if instr is @lib.I32Xor {
              (lhs.to_int() ^ rhs.to_int()).to_int64()
            } else {
              lhs ^ rhs
            },
          )
        }
        @lib.I32Const(@lib.I32(value)) => stack.push(value.to_int64())
        @lib.I64Const(@lib.I64(value)) => stack.push(value)
        @lib.LocalGet(@lib.LocalIdx(index)) =>
          stack.push(locals[index.to_int()])
        @lib.LocalSet(@lib.LocalIdx(index)) =>
          locals[index.to_int()] = stack.pop().unwrap()
        @lib.LocalTee(@lib.LocalIdx(index)) =>
          locals[index.to_int()] = stack[stack.length() - 1]
        @lib.Call(@lib.FuncIdx(index)) => {
          let slot = index.to_int()
          if slot >= call_params.length() {
            fail("missing scalar fixture callee")
          }
          let count = call_params[slot]
          let values = Array::make(count, 0L)
          for i = count - 1; i >= 0; i = i - 1 {
            values[i] = stack.pop().unwrap()
          }
          let results = match call {
            Some(invoke) => invoke(index, values)
            None => fail("missing scalar fixture call handler")
          }
          for value in results {
            stack.push(value)
          }
        }
        @lib.ArrayNew(_) => {
          let length = stack.pop().unwrap()
          let initial = stack.pop().unwrap()
          let reference = match array_new {
            Some(allocate) => allocate(initial, length)
            None => fail("missing scalar fixture allocation observer")
          }
          stack.push(reference)
        }
        @lib.Select(_) => {
          let condition = stack.pop().unwrap()
          let no = stack.pop().unwrap()
          let yes = stack.pop().unwrap()
          stack.push(if condition != 0L { yes } else { no })
        }
        @lib.I32Load(@lib.MemArg(_, _, @lib.U64(offset))) => {
          let address = stack.pop().unwrap().to_uint64() + offset
          let value = match load {
            Some(read) => read(address.reinterpret_as_int64())
            None => fail("missing scalar fixture memory")
          }
          stack.push(value.to_int().to_int64())
        }
        @lib.Drop => ignore(stack.pop().unwrap())
        @lib.I32Eqz | @lib.I64Eqz =>
          stack.push(if stack.pop().unwrap() == 0L { 1L } else { 0L })
        @lib.I32Add
        | @lib.I32Sub
        | @lib.I32Mul
        | @lib.I64Add
        | @lib.I64Sub
        | @lib.I64Mul
        | @lib.I32Eq
        | @lib.I32Ne
        | @lib.I32LtS
        | @lib.I32GtS
        | @lib.I32LeS
        | @lib.I32GeS => {
          let rhs = stack.pop().unwrap()
          let lhs = stack.pop().unwrap()
          let value = match instr {
            @lib.I32Add => (lhs.to_int() + rhs.to_int()).to_int64()
            @lib.I32Sub => (lhs.to_int() - rhs.to_int()).to_int64()
            @lib.I32Mul => (lhs.to_int() * rhs.to_int()).to_int64()
            @lib.I64Add => lhs + rhs
            @lib.I64Sub => lhs - rhs
            @lib.I64Mul => lhs * rhs
            @lib.I32Eq => if lhs == rhs { 1L } else { 0L }
            @lib.I32Ne => if lhs != rhs { 1L } else { 0L }
            @lib.I32LtS => if lhs < rhs { 1L } else { 0L }
            @lib.I32GtS => if lhs > rhs { 1L } else { 0L }
            @lib.I32LeS => if lhs <= rhs { 1L } else { 0L }
            @lib.I32GeS => if lhs >= rhs { 1L } else { 0L }
            _ => fail("unhandled scalar binary instruction")
          }
          stack.push(value)
        }
        @lib.Block(bt, @lib.Expr(nested)) | @lib.Loop(bt, @lib.Expr(nested)) => {
          let base = stack.length()
          let loop_ = instr is @lib.Loop(_, _)
          let mut repeat = true
          while repeat {
            repeat = false
            match execute(nested) {
              Returned => return Returned
              Branch(depth) if depth > 0 => return Branch(depth - 1)
              Branch(_) if loop_ => {
                finish(base, 0)
                repeat = true
              }
              _ => finish(base, arity(bt))
            }
          }
        }
        @lib.If(bt, yes, no) => {
          let take_yes = stack.pop().unwrap() != 0L
          let base = stack.length()
          let selected = if take_yes { yes } else { no.unwrap_or([]) }
          match execute(selected) {
            Returned => return Returned
            Branch(depth) if depth > 0 => return Branch(depth - 1)
            _ => finish(base, arity(bt))
          }
        }
        @lib.Br(@lib.LabelIdx(depth)) => return Branch(depth.to_int())
        @lib.BrIf(@lib.LabelIdx(depth)) =>
          if stack.pop().unwrap() != 0L {
            return Branch(depth.to_int())
          }
        @lib.Return => return Returned
        _ => fail("unsupported scalar fixture instruction: \{instr}")
      }
    }
    Next
  }
  ignore(execute(body))
  stack
}
