///|
// Continuation text grammar is an older WAST boundary. Build its core type and
// instructions directly, as the dedicated GenValid continuation profile does.
fn continuation_cleanup_test_run(
  source : String,
  bodies : Array[Array[@lib.Instruction]],
  pass : String,
) -> @lib.Module raise {
  let input = match @wast.wast_to_binary_module(source) {
    Ok(input) => input
    Err(err) => fail(err)
  }
  let types = input.type_sec.unwrap().0.copy()
  types[1] = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::cont(@lib.TypeIdx::new(0U))),
  )
  let input = input
    .with_type_sec(@lib.TypeSec::new(types))
    .with_code_sec(
      @lib.CodeSec::new(
        bodies.map(fn(body) {
          @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
        }),
      ),
    )
  @validate.validate_module(input).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [pass]).unwrap()
  @validate.validate_module(output).unwrap()
  output
}

///|
test "vacuum removes unused nonnull continuation allocation and preserves its producer" {
  for pass in ["vacuum", "dae2-optimizing"] {
    let source =
      #|(module
      #| (type $sig (func)) (type $cont (func))
      #| (import "env" "producer" (func $producer (result (ref $sig))))
      #| (func (export "run") unreachable))
    let output = continuation_cleanup_test_run(
      source,
      [
        [
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          @lib.Instruction::cont_new(@lib.TypeIdx::new(1U)),
          @lib.Instruction::drop(),
        ],
      ],
      pass,
    )
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    assert_false(body.any(fn(instr) { instr is @lib.ContNew(_) }))
    @debug.assert_eq(
      body.filter(fn(instr) { instr is @lib.Call(_) }).length(),
      1,
    )
    assert_true(body.contains(@lib.Instruction::call(@lib.FuncIdx::new(0U))))
  }
}

///|
test "vacuum retains nullable continuation allocation traps and consuming binds" {
  for pass in ["vacuum", "dae2-optimizing"] {
    let source =
      #|(module
      #| (type $sig (func)) (type $cont (func))
      #| (func (export "allocate") (param (ref null $sig))
      #|  unreachable)
      #| (func (export "bind") (param (ref $cont)) unreachable))
    let output = continuation_cleanup_test_run(
      source,
      [
        [
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::cont_new(@lib.TypeIdx::new(1U)),
          @lib.Instruction::drop(),
        ],
        [
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::cont_bind(
            @lib.TypeIdx::new(1U),
            @lib.TypeIdx::new(1U),
          ),
          @lib.Instruction::drop(),
        ],
      ],
      pass,
    )
    let @lib.Func(_, @lib.Expr(allocation)) = output.code_sec.unwrap().0[0]
    let @lib.Func(_, @lib.Expr(binding)) = output.code_sec.unwrap().0[1]
    assert_true(allocation.any(fn(instr) { instr is @lib.ContNew(_) }))
    assert_true(binding.any(fn(instr) { instr is @lib.ContBind(_, _) }))
  }
}

///|
test "vacuum removes unused continuation with a declared function reference" {
  let source =
    #|(module (type $sig (func)) (type $cont (func))
    #| (func $target (type $sig)) (elem declare func $target)
    #| (func (export "run") unreachable))
  let output = continuation_cleanup_test_run(
    source,
    [
      [],
      [
        @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
        @lib.Instruction::cont_new(@lib.TypeIdx::new(1U)),
        @lib.Instruction::drop(),
      ],
    ],
    "vacuum",
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  assert_false(
    body.any(fn(instr) { instr is @lib.ContNew(_) || instr is @lib.RefFunc(_) }),
  )
}
