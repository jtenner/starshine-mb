///|
test "Binaryen 133 dealign preserves the natural alignment of an atomic load" {
  let output = binaryen133_run_new_pass(
    "(module (memory 1 1 shared) (func (export \"run\") (result i32) (i32.atomic.load align=4 (i32.const 0))))",
    "dealign",
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_true(
    body.any(fn(instr) {
      instr is @lib.I32AtomicLoad(_, @lib.MemArg(@lib.U32(2U), _, _))
    }),
  )
}

///|
test "Binaryen 133 dealign preserves the natural alignment of an atomic store" {
  let output = binaryen133_run_new_pass(
    "(module (memory 1 1 shared) (func (export \"run\") (i32.atomic.store align=4 (i32.const 0) (i32.const 1))))",
    "dealign",
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_true(
    body.any(fn(instr) {
      instr is @lib.I32AtomicStore(_, @lib.MemArg(@lib.U32(2U), _, _))
    }),
  )
}

///|
test "Binaryen 133 dealign sets an ordinary load alignment to one" {
  let output = binaryen133_run_new_pass(
    "(module (memory 1) (func (export \"run\") (result i32) (i32.load align=4 (i32.const 0))))",
    "dealign",
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_true(
    body.any(fn(instr) {
      instr is @lib.I32Load(@lib.MemArg(@lib.U32(0U), _, _))
    }),
  )
}

///|
test "Binaryen 133 dealign sets an ordinary store alignment to one" {
  let output = binaryen133_run_new_pass(
    "(module (memory 1) (func (export \"run\") (i32.store align=4 (i32.const 0) (i32.const 1))))",
    "dealign",
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_true(
    body.any(fn(instr) {
      instr is @lib.I32Store(@lib.MemArg(@lib.U32(0U), _, _))
    }),
  )
}
