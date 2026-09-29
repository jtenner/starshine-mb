///|
fn dae_multivalue_prefix_copied_reference(
  instr : @lib.Instruction,
  types : @lib.TypeSec?,
) -> (Int, Array[@lib.Instruction])? {
  let (block_type, body) = match instr {
    @lib.Block(block_type, @lib.Expr(body)) => (block_type, body)
    _ => return None
  }
  let count = match dae_block_type_zero_param_result_count(block_type, types) {
    Some(count) if count > 1 => count
    _ => return None
  }
  let mut remaining = body.length()
  let mut values = 0
  while remaining > 0 && values < count {
    let candidate : Array[@lib.Instruction] = []
    for index in 0..<remaining {
      candidate.push(body[index])
    }
    remaining = match
      dae_find_droppable_pure_stack_expr_start(candidate, types) {
      Some(start) => start
      None => return None
    }
    values += 1
  }
  if values != count {
    return None
  }
  let prefix : Array[@lib.Instruction] = []
  for index in 0..<remaining {
    if dae_instr_has_branch(body[index]) {
      return None
    }
    prefix.push(body[index])
  }
  Some((count, prefix))
}

///|
fn dae_multivalue_prefix_bench(
  it : @bench.T,
  results : Int,
  width : Int,
  borrow : Bool,
) -> Unit {
  let result_types = Array::make(results, "i32").join(" ")
  let values : Array[String] = []
  for _ in 0..<results {
    values.push("i32.const 7")
    for _ in 1..<width {
      values.push("i32.const 11 i32.add")
    }
  }
  let drops = Array::make(results, "drop").join(" ")
  let input = pass_test_module_from_wat(
    "(module (type $pack (func (result \{result_types}))) (import \"m\" \"value\" (func $v (result i32))) (func block (type $pack) call $v drop \{values.join(" ")} end \{drops}))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let block = body[0]
  let expected = Some(
    (
      results,
      [@lib.Instruction::call(@lib.FuncIdx::new(0U)), @lib.Instruction::drop()],
    ),
  )
  if dae_multivalue_prefix_copied_reference(block, input.type_sec) != expected ||
    dae_instr_dropped_pure_multivalue_block_prefix(block, input.type_sec) !=
    expected {
    abort("multi-result proof lost the observable prefix")
  }
  let action = if borrow {
    dae_instr_dropped_pure_multivalue_block_prefix
  } else {
    dae_multivalue_prefix_copied_reference
  }
  it.bench(fn() { it.keep(action(block, input.type_sec)) })
  if @binary.encode_module(input).unwrap() != saved {
    abort("multi-result proof mutated its input")
  }
}

///|
test "bench DAE multi-result prefixes results=2 width=1 copied" (it : @bench.T) {
  dae_multivalue_prefix_bench(it, 2, 1, false)
}

///|
test "bench DAE multi-result prefixes results=2 width=1 borrowed" (
  it : @bench.T,
) {
  dae_multivalue_prefix_bench(it, 2, 1, true)
}

///|
test "bench DAE multi-result prefixes results=16 width=128 copied" (
  it : @bench.T,
) {
  dae_multivalue_prefix_bench(it, 16, 128, false)
}

///|
test "bench DAE multi-result prefixes results=16 width=128 borrowed" (
  it : @bench.T,
) {
  dae_multivalue_prefix_bench(it, 16, 128, true)
}
