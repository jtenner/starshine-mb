///|
test "single leaf cleanup command preserves floating payload and input ownership" {
  let input = @wast.wast_to_binary_module(
    "(module (func (export \"run\") (result f64) (local f64) block (result f64) f64.const nan:0x8000000000001 local.set 0 local.get 0 end))",
  ).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  for pass_name in ["simplify-locals", "dae2-optimizing"] {
    let output = optimize_module_with_pass_flags(
      input,
      [pass_name],
      OptimizeOptions::new(),
    ).unwrap()
    @validate.validate_module(output).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    let bits : Array[UInt64] = []
    single_leaf_command_float_bits(body, bits)
    assert_eq(bits, [0x7ff8000000000001UL])
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
fn single_leaf_command_float_bits(
  body : Array[@lib.Instruction],
  bits : Array[UInt64],
) -> Unit {
  for instr in body {
    match instr {
      @lib.F64Const(@lib.F64(value)) => bits.push(value.reinterpret_as_uint64())
      @lib.Block(_, @lib.Expr(next))
      | @lib.Loop(_, @lib.Expr(next))
      | @lib.TryTable(_, _, @lib.Expr(next)) =>
        single_leaf_command_float_bits(next, bits)
      @lib.If(_, yes, no) => {
        single_leaf_command_float_bits(yes, bits)
        match no {
          Some(next) => single_leaf_command_float_bits(next, bits)
          None => ()
        }
      }
      _ => ()
    }
  }
}
