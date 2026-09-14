///|
// Bounded independent evaluator for the scalar/GC instructions in these fixtures.
// Reference zero is null; positive references index distinct fresh objects.
fn fourth_audit_heap_eval(
  module_ : @lib.Module,
  args : Array[Int],
  field_count? : Int = 1,
  globals? : Array[Int] = [],
) -> Array[Int] raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = module_.code_sec.unwrap().0[0]
  let locals = args.copy()
  for _ in 0..<body_locals.length() {
    locals.push(0)
  }
  let stack : Array[Int] = []
  let heap : Array[Array[Int]] = [[]]
  fn object(ref_ : Int) -> Array[Int] raise {
    if ref_ <= 0 || ref_ >= heap.length() {
      fail("fixture null reference trap")
    }
    heap[ref_]
  }
  fn allocate(count : Int) -> Unit {
    let fields = Array::make(count, 0)
    for i = count - 1; i >= 0; i = i - 1 {
      fields[i] = stack.pop().unwrap()
    }
    heap.push(fields)
    stack.push(heap.length() - 1)
  }
  let mut steps = 0
  fn execute(instrs : Array[@lib.Instruction]) -> Unit raise {
    for instr in instrs {
      steps += 1
      if steps > 1000 {
        fail("fixture step budget")
      }
      match instr {
        @lib.Nop => ()
        @lib.I32Const(@lib.I32(v)) => stack.push(v)
        @lib.RefNull(_) => stack.push(0)
        @lib.LocalGet(@lib.LocalIdx(i)) => stack.push(locals[i.to_int()])
        @lib.LocalSet(@lib.LocalIdx(i)) =>
          locals[i.to_int()] = stack.pop().unwrap()
        @lib.LocalTee(@lib.LocalIdx(i)) =>
          locals[i.to_int()] = stack[stack.length() - 1]
        @lib.GlobalGet(@lib.GlobalIdx(i)) => stack.push(globals[i.to_int()])
        @lib.GlobalSet(@lib.GlobalIdx(i)) =>
          globals[i.to_int()] = stack.pop().unwrap()
        @lib.Drop => ignore(stack.pop().unwrap())
        @lib.StructNew(_) => allocate(field_count)
        @lib.StructNewDefault(_) => {
          heap.push(Array::make(field_count, 0))
          stack.push(heap.length() - 1)
        }
        @lib.StructGet(_, @lib.U32(i)) => {
          let ref_ = stack.pop().unwrap()
          stack.push(object(ref_)[i.to_int()])
        }
        @lib.StructSet(_, @lib.U32(i)) => {
          let value = stack.pop().unwrap()
          object(stack.pop().unwrap())[i.to_int()] = value
        }
        @lib.ArrayNewFixed(_, @lib.U32(n)) => allocate(n.to_int())
        @lib.ArrayNew(_) => {
          let n = stack.pop().unwrap()
          let value = stack.pop().unwrap()
          heap.push(Array::make(n, value))
          stack.push(heap.length() - 1)
        }
        @lib.ArrayGet(_) => {
          let index = stack.pop().unwrap()
          stack.push(object(stack.pop().unwrap())[index])
        }
        @lib.ArraySet(_) => {
          let value = stack.pop().unwrap()
          let index = stack.pop().unwrap()
          object(stack.pop().unwrap())[index] = value
        }
        @lib.RefAsNonNull => ignore(object(stack[stack.length() - 1]))
        @lib.Block(_, @lib.Expr(nested)) => execute(nested)
        @lib.If(_, yes, no) => {
          let cond = stack.pop().unwrap()
          execute(if cond != 0 { yes } else { no.unwrap_or([]) })
        }
        _ => fail("unsupported GC fixture instruction: \{instr}")
      }
    }
  }
  execute(body)
  stack
}
