///|
test "raw scratch keeps repeated nested writes with their escaping read" {
  for parameter in [false, true] {
    for write in ["local.set", "local.tee"] {
      let discard = if write == "local.tee" { "drop" } else { "" }
      let signature = if parameter {
        "(param i32) (result i32) (local i32)"
      } else {
        "(result i32) (local i32 i32)"
      }
      let params = if parameter { [@lib.ValType::i32()] } else { [] }
      let input = pass_test_module_from_wat(
        "(module (memory 1) (func " +
        signature +
        " i32.const 1 local.set 0 i32.const 2 local.set 1 block i32.const 0 i32.load " +
        write +
        " 0 " +
        discard +
        " end i32.const 4 i32.load local.tee 1 drop local.get 0))",
      )
      let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
      let extra : Array[@lib.ValType] = []
      let rewritten = run_hot_pipeline_raw_freshen_param_scratch_writes_with_aliases(
        body,
        body,
        params,
        locals,
        extra,
        [None, None],
        @bitset.BitSet::new(2),
      )
      let target = match rewritten.last() {
        Some(@lib.LocalGet(target)) => target
        _ => abort("expected escaping local read")
      }
      assert_eq(p00_scratch_write_count(rewritten, target), 2)
      assert_true(
        !extra.is_empty(),
        msg="independent root writes still freshen",
      )
      let output = @lib.Func::new(
        @lib.Locals::from_types(
          Array::makei(locals.length(), fn(i) { locals.get(i) }) + extra,
        ),
        @lib.Expr::new(rewritten),
      )
      @validate.validate_module(
        input.with_code_sec(@lib.CodeSec::new([output])),
      ).unwrap()
    }
  }
}

///|
test "raw scratch preserves a loop carrier read by a legacy catch" {
  let input = pass_test_module_from_wat(
    "(module (memory 1) (tag $t) (func (result i32) (local $x i32) (local $i i32) (local $sum i32) (local.set $x (i32.const 1)) (loop $l (try (do (throw $t)) (catch_all (local.set $sum (i32.add (local.get $sum) (local.get $x))))) (drop (local.tee $x (i32.load (i32.const 0)))) (local.set $i (i32.add (local.get $i) (i32.const 1))) (br_if $l (i32.lt_u (local.get $i) (i32.const 2)))) (local.get $sum)))",
  )
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let extra : Array[@lib.ValType] = []
  let rewritten = run_hot_pipeline_raw_freshen_param_scratch_writes(
    body,
    [],
    locals,
    extra,
  )
  assert_eq(p00_scratch_write_count(rewritten, @lib.LocalIdx::new(0U)), 2)
  @validate.validate_module(
    input.with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types(
            Array::makei(locals.length(), fn(i) { locals.get(i) }) + extra,
          ),
          @lib.Expr::new(rewritten),
        ),
      ]),
    ),
  ).unwrap()
}

///|
test "raw scratch keeps a root load visible to a legacy catch" {
  let input = pass_test_module_from_wat(
    "(module (memory 1) (tag $t) (func (result i32) (local $x i32) (local.set $x (i32.load (i32.const 0))) (try (result i32) (do (throw $t)) (catch_all (local.get $x)))))",
  )
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let extra : Array[@lib.ValType] = []
  let rewritten = run_hot_pipeline_raw_freshen_param_scratch_writes(
    body,
    [],
    locals,
    extra,
  )
  assert_eq(p00_scratch_write_count(rewritten, @lib.LocalIdx::new(0U)), 1)
  @validate.validate_module(
    input.with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types(
            Array::makei(locals.length(), fn(i) { locals.get(i) }) + extra,
          ),
          @lib.Expr::new(rewritten),
        ),
      ]),
    ),
  ).unwrap()
}

///|
test "raw scratch keeps both-arm parameter writes visible after the if" {
  for wrapped in [false, true] {
    let open = if wrapped { "(block (result i32) " } else { "" }
    let close = if wrapped { ")" } else { "" }
    let input = pass_test_module_from_wat(
      "(module (memory 1) (func (param $p i32) (param $x i32) (result i32) (local.set $x (i32.const 1)) " +
      open +
      "(if (local.get $p) (then (drop (local.tee $x (i32.load (i32.const 0))))) (else (drop (local.tee $x (i32.load (i32.const 4)))))) (local.get $x)" +
      close +
      "))",
    )
    let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    let extra : Array[@lib.ValType] = []
    let params = [@lib.ValType::i32(), @lib.ValType::i32()]
    let rewritten = run_hot_pipeline_raw_freshen_param_scratch_writes(
      body, params, locals, extra,
    )
    assert_eq(p00_scratch_write_count(rewritten, @lib.LocalIdx::new(1U)), 3)
  }
}

///|
test "raw scratch freshens earlier parameter writes before a canonical arm overwrite" {
  for branch in [false, true] {
    let exit = if branch { "(br_if $if (local.get $p))" } else { "" }
    let input = pass_test_module_from_wat(
      "(module (memory 1) (func (param $p i32) (param $x i32) (result i32) (local.set $x (i32.const 1)) (if $if (local.get $p) (then (drop (local.tee $x (i32.load (i32.const 0)))) " +
      exit +
      " (drop (local.tee $x (i32.load (i32.const 4))))) (else (drop (local.tee $x (i32.load (i32.const 8)))))) (local.get $x)))",
    )
    let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    let extra : Array[@lib.ValType] = []
    let rewritten = run_hot_pipeline_raw_freshen_param_scratch_writes(
      body,
      [@lib.ValType::i32(), @lib.ValType::i32()],
      locals,
      extra,
    )
    assert_eq(extra.length(), if branch { 1 } else { 2 })
    assert_eq(
      p00_scratch_write_count(rewritten, @lib.LocalIdx::new(1U)),
      if branch {
        4
      } else {
        3
      },
    )
    @validate.validate_module(
      input.with_code_sec(
        @lib.CodeSec::new([
          @lib.Func::new(
            @lib.Locals::from_types(extra),
            @lib.Expr::new(rewritten),
          ),
        ]),
      ),
    ).unwrap()
  }
}

///|
test "raw scratch keeps an appended local write visible after a block" {
  let input = pass_test_module_from_wat(
    "(module (memory 1) (func (result i32) (local i32 i32) (local.set 1 (i32.const 1)) (block (local.set 1 (i32.load (i32.const 0)))) (local.get 1)))",
  )
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let locals = @lib.Locals::from_types([@lib.ValType::i32()])
  let extra = [@lib.ValType::i32()]
  let rewritten = run_hot_pipeline_raw_freshen_param_scratch_writes(
    body,
    [],
    locals,
    extra,
  )
  assert_eq(p00_scratch_write_count(rewritten, @lib.LocalIdx::new(1U)), 2)
  @validate.validate_module(
    input.with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()] + extra),
          @lib.Expr::new(rewritten),
        ),
      ]),
    ),
  ).unwrap()
}

///|
test "raw scratch preserves an appended loop carrier" {
  let input = pass_test_module_from_wat(
    "(module (memory 1) (func (result i32) (local $sum i32) (local $x i32) (local $i i32) (local.set $x (i32.const 1)) (loop $l (local.set $sum (i32.add (local.get $sum) (local.get $x))) (local.set $x (i32.load (i32.const 0))) (local.set $i (i32.add (local.get $i) (i32.const 1))) (br_if $l (i32.lt_u (local.get $i) (i32.const 2)))) (local.get $sum)))",
  )
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let locals = @lib.Locals::from_types([@lib.ValType::i32()])
  let extra = [@lib.ValType::i32(), @lib.ValType::i32()]
  let rewritten = run_hot_pipeline_raw_freshen_param_scratch_writes(
    body,
    [],
    locals,
    extra,
  )
  assert_eq(p00_scratch_write_count(rewritten, @lib.LocalIdx::new(1U)), 2)
  @validate.validate_module(
    input.with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()] + extra),
          @lib.Expr::new(rewritten),
        ),
      ]),
    ),
  ).unwrap()
}

///|
fn p00_scratch_write_count(
  body : Array[@lib.Instruction],
  target : @lib.LocalIdx,
) -> Int {
  let mut count = 0
  for instr in body {
    match instr {
      @lib.LocalSet(local) | @lib.LocalTee(local) =>
        if local == target {
          count += 1
        }
      @lib.Block(_, @lib.Expr(nested)) | @lib.Loop(_, @lib.Expr(nested)) =>
        count += p00_scratch_write_count(nested, target)
      @lib.Try(_, @lib.Expr(body), catches, _) => {
        count += p00_scratch_write_count(body, target)
        for arm in catches {
          let @lib.Expr(body) = match arm {
            @lib.LegacyCatch(_, body) | @lib.LegacyCatchAll(body) => body
          }
          count += p00_scratch_write_count(body, target)
        }
      }
      @lib.If(_, then_body, else_body) => {
        count += p00_scratch_write_count(then_body, target)
        if else_body is Some(body) {
          count += p00_scratch_write_count(body, target)
        }
      }
      _ => ()
    }
  }
  count
}
