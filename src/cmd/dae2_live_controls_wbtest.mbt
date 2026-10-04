///|
test "DAE2 live controls preserve effectful arms while pruning dead arguments" {
  let input = @wast.wast_to_binary_module(
    (
      #|(module
      #| (import "host" "f" (func (param i32) (result i32)))
      #| (global (export "state") (mut i32) (i32.const 0))
      #| (func $callee (param i32 i64) (result i32)
      #|  block (result i32)
      #|   loop (result i32)
      #|    local.get 0 if (result i32)
      #|     i32.const 17 global.set 0 local.get 0 call 0
      #|    else
      #|     i32.const 19 global.set 0 i32.const 23 call 0
      #|    end
      #|   end
      #|  end)
      #| (func (export "run") (param i32) (result i32)
      #|  local.get 0 i64.const 99 call $callee))
    ),
  ).unwrap()
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  for pass in ["dae2", "dae2-optimizing"] {
    let output = optimize_module_with_pass_flags(
      input,
      [pass],
      OptimizeOptions::new(),
    ).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(
      @validate.Env::new()
      .with_module(output)
      .get_functype_by_funcidx(@lib.FuncIdx::new(1U)),
      Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
    )
    assert_eq(output.import_sec, input.import_sec)
    assert_eq(output.global_sec, input.global_sec)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
